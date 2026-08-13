// Build (or grow) the baked "Show me how to win" solutions for the daily pool. OFFLINE tool.
//
//   node tools/solver/build-solutions.mjs [--pool path] [--out path] [--budget N]
//
// For every seed in the certified daily pool, finds the shortest UNCONSTRAINED winning line
// (the same reference par search that certified the seed) and records the full, replayable move
// list — including the auto-safe sends — as a compact token string. The app resets the deal and
// animates this line for "Show me how to win".
//
// APPEND-ONLY, like the pool: existing solution entries are preserved and never recomputed, so a
// solution a past day may already have shown can't change under players. Keyed by seed.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { solve, objective, dealState, moveToken } from './solve.mjs';
import { deal } from '../../tests/engine.mjs';
import { applyMove, isWon } from './rules.mjs';

const SOLUTIONS_VERSION = 1;

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] != null ? process.argv[i + 1] : def;
}

// Human-readable but compact: one "seed": "tokens" entry per line.
function serialize(sol) {
  const rows = Object.keys(sol.solutions).map(Number).sort((a, b) => a - b)
    .map(s => `    "${s}": ${JSON.stringify(sol.solutions[s])}`).join(',\n');
  return `{\n  "version": ${sol.version},\n  "solutions": {\n${rows}\n  }\n}\n`;
}

// Re-simulate a token solution from the raw deal and confirm it wins — a solution we can't verify
// is worse than none, so we refuse to record it.
function verify(seed, tokens) {
  let s = dealState(seed);
  for (const tok of tokens.split(' ')) {
    const f = tok.split(',');
    let m;
    switch (f[0]) {
      case 'F': m = { k: 'F', from: { col: +f[1] }, end: +f[2] ? 'down' : 'up' }; break;
      case 'G': m = { k: 'F', from: { cell: +f[1] }, end: +f[2] ? 'down' : 'up' }; break;
      case 'T': m = { k: 'T', src: +f[1], idx: +f[2], dst: +f[3] }; break;
      case 'C': m = { k: 'C', src: +f[1] }; break;
      case 'X': m = { k: 'X', cell: +f[1], dst: +f[2] }; break;
      default: throw new Error('bad token ' + tok);
    }
    s = applyMove(s, m);
  }
  return isWon(s);
}

const poolPath = arg('pool', 'data/daily-pool.json');
const out = arg('out', 'data/daily-solutions.json');
const budget = Number(arg('budget', 300000));

const pool = JSON.parse(readFileSync(poolPath, 'utf8'));
let sol = { version: SOLUTIONS_VERSION, solutions: {} };
try { sol = JSON.parse(readFileSync(out, 'utf8')); } catch { /* fresh */ }

console.log(`pool ${pool.seeds.length} seeds; have ${Object.keys(sol.solutions).length} solutions; budget ${budget}`);
let added = 0, failed = 0;
for (const rec of pool.seeds) {
  const seed = rec.seed;
  if (sol.solutions[String(seed)]) continue;                       // append-only: keep existing
  const r = solve(dealState(seed), objective('unconstrained'), { budget, withPath: true });
  if (r.solved !== true || !r.moves) { console.log(`! ${seed} unsolved (solved=${r.solved})`); failed++; continue; }
  const tokens = r.moves.map(moveToken).join(' ');
  if (!verify(seed, tokens)) { console.log(`! ${seed} solution failed verification`); failed++; continue; }
  sol.solutions[String(seed)] = tokens;
  added++;
  if (added % 25 === 0) process.stdout.write(`  …${added} solved\n`);
}

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, serialize(sol));
console.log(`done: +${added} solutions (failed ${failed}), total ${Object.keys(sol.solutions).length} -> ${out}`);
