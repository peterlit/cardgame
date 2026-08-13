// Build (or grow) the baked "Show me how to win" solutions for the daily pool. OFFLINE tool.
//
//   node tools/solver/build-solutions.mjs [--pool path] [--out path] [--budget N]
//
// For every seed in the certified daily pool we bake up to THREE replayable winning lines — one per
// tier — so the app can demonstrate not just clearing the deal but achieving that day's Silver and
// Gold objectives:
//   bronze : the shortest UNCONSTRAINED win (clear the deal).
//   gold   : a win that OBEYS the day's Gold objective (always a certified/constraining objective).
//   silver : a win that OBEYS the day's Silver objective — but only when that objective is a
//            *certified* (constraining) one (free-cell limits / down-openers). A "universal" Silver
//            (win in N moves / no undo) is already satisfied by the bronze line, so it's omitted and
//            the app falls back to bronze.
//
// Each tier's Silver/Gold line is not just re-simulated to a win but re-checked against the actual
// objective checker (tests/daily.mjs) — a line we can't prove earns the tier is dropped. The day's
// objective is keyed by the seed's POOL INDEX (dailyChallenge(index, pool)), which is frozen by the
// append-only pool, so a seed's Silver/Gold lines are stable.
//
// Keyed by seed; entries are `{ bronze, silver?, gold? }`. Regenerated fresh on a schema bump.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { solve, objective, dealState, moveToken } from './solve.mjs';
import { applyMove, isWon } from './rules.mjs';
import { dailyChallenge, evaluate } from '../../tests/daily.mjs';

const SOLUTIONS_VERSION = 2;   // v2: per-tier { bronze, silver?, gold? } (v1 was a bronze string)
const CERTIFIED_SILVER = new Set(['cells-le-1', 'cells-le-2', 'down-openers-20']);

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] != null ? process.argv[i + 1] : def;
}

// Human-readable but compact: one "seed": {tiers} entry per line.
function serialize(sol) {
  const rows = Object.keys(sol.solutions).map(Number).sort((a, b) => a - b)
    .map(s => `    "${s}": ${JSON.stringify(sol.solutions[s])}`).join(',\n');
  return `{\n  "version": ${sol.version},\n  "solutions": {\n${rows}\n  }\n}\n`;
}

function parseToken(tok) {
  const f = tok.split(',');
  switch (f[0]) {
    case 'F': return { k: 'F', from: { col: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'G': return { k: 'F', from: { cell: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'T': return { k: 'T', src: +f[1], idx: +f[2], dst: +f[3] };
    case 'C': return { k: 'C', src: +f[1] };
    case 'X': return { k: 'X', cell: +f[1], dst: +f[2] };
    default: throw new Error('bad token ' + tok);
  }
}

// Re-simulate a token line from the raw deal, reconstructing the telemetry the app's objective
// checkers read (foundation stream, cell-park count, move count). undos is always 0 (a demo never
// undoes). moveIdx = 1-based token position, matching the app's per-move recordHomed cursor.
function replay(seed, tokens) {
  let s = dealState(seed);
  const foundationOrder = [];
  let cellUses = 0, moves = 0;
  for (const tok of tokens.split(' ')) {
    const f = tok.split(',');
    moves++;
    if (f[0] === 'F') { const col = s.tableau[+f[1]]; const c = col[col.length - 1]; foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
    else if (f[0] === 'G') { const c = s.cells[+f[1]]; foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
    else if (f[0] === 'C') { cellUses++; }
    s = applyMove(s, parseToken(tok));
  }
  return { won: isWon(s), moves, elapsed: 0, cellUses, undos: 0, foundationOrder };
}

// Solve seed under `objId` and return the winning line as tokens, or null if unsolved in budget.
function lineFor(seed, objId, budget) {
  const r = solve(dealState(seed), objective(objId), { budget, withPath: true });
  return (r.solved === true && r.moves) ? r.moves.map(moveToken).join(' ') : null;
}

const poolPath = arg('pool', 'data/daily-pool.json');
const out = arg('out', 'data/daily-solutions.json');
const budget = Number(arg('budget', 300000));

const pool = JSON.parse(readFileSync(poolPath, 'utf8'));
let sol = { version: SOLUTIONS_VERSION, solutions: {} };
try { const prev = JSON.parse(readFileSync(out, 'utf8')); if (prev.version === SOLUTIONS_VERSION) sol = prev; } catch { /* fresh */ }

console.log(`pool ${pool.seeds.length} seeds; have ${Object.keys(sol.solutions).length}; budget ${budget}`);
let added = 0, goldOk = 0, silverOk = 0, warn = 0;
for (let i = 0; i < pool.seeds.length; i++) {
  const seed = pool.seeds[i].seed;
  if (sol.solutions[String(seed)] && sol.solutions[String(seed)].bronze) continue;   // resume-friendly
  const ch = dailyChallenge(i, pool);
  if (!ch) { console.log(`! ${seed} no challenge`); warn++; continue; }

  const bronze = lineFor(seed, 'unconstrained', budget);
  if (!bronze || !replay(seed, bronze).won) { console.log(`! ${seed} bronze unsolved`); warn++; continue; }
  const entry = { bronze };

  // Gold — always a certified objective; must win AND satisfy the checker.
  const goldTokens = lineFor(seed, ch.gold.id, budget);
  if (goldTokens) {
    const t = replay(seed, goldTokens);
    if (t.won && evaluate(ch.gold, t)) { entry.gold = goldTokens; goldOk++; }
    else { console.log(`! ${seed} gold(${ch.gold.id}) line failed objective check`); warn++; }
  } else { console.log(`! ${seed} gold(${ch.gold.id}) unsolved`); warn++; }

  // Silver — only certified (constraining) objectives get a distinct line; universals fall back to bronze.
  if (CERTIFIED_SILVER.has(ch.silver.id)) {
    const silverTokens = lineFor(seed, ch.silver.id, budget);
    if (silverTokens) {
      const t = replay(seed, silverTokens);
      if (t.won && evaluate(ch.silver, t)) { entry.silver = silverTokens; silverOk++; }
      else { console.log(`! ${seed} silver(${ch.silver.id}) line failed objective check`); warn++; }
    } else { console.log(`! ${seed} silver(${ch.silver.id}) unsolved`); warn++; }
  }

  sol.solutions[String(seed)] = entry;
  added++;
  if (added % 25 === 0) process.stdout.write(`  …${added} (gold ${goldOk}, silver ${silverOk})\n`);
}

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, serialize(sol));
console.log(`done: +${added} (gold ${goldOk}, silver ${silverOk}, warnings ${warn}), total ${Object.keys(sol.solutions).length} -> ${out}`);
