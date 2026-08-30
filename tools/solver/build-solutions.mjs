// Build (or grow) the baked "Show me how to win" solutions for the daily pool. OFFLINE tool.
//
//   node tools/solver/build-solutions.mjs [--pool path] [--out path] [--budget N] [--stripe W/N]
//
// `--stripe W/N` builds only days where `dayIndex % N === W`, writing to its own `--out`. Four
// stripes into four files, then `--merge a.json b.json ...`, turns a ~90-minute serial batch into a
// ~25-minute parallel one; the solver is single-threaded and CPU-bound.
//
// For every seed in the certified daily pool we bake up to THREE replayable winning lines — one per
// tier — so the app can demonstrate not just clearing the deal but achieving that day's Silver and
// Gold objectives:
//   bronze  : the shortest UNCONSTRAINED win (clear the deal).
//   flawless: ONE line that wins and satisfies BOTH objectives — what the 🌟 tier asks for.
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
import { solve, objective, dealState, moveToken, certifyFlawless, variantKey } from './solve.mjs';
import { applyMove, isWon } from './rules.mjs';
import { dailyChallenge, evaluate, OBJECTIVES } from '../../tests/daily.mjs';

const SOLUTIONS_VERSION = 3;   // v3: adds `flawless` — ONE line that earns all three tiers at once
                               // (v2 was per-tier { bronze, silver?, gold? }; v1 a bronze string)
// A `universal` Silver (win in N moves / no undo) is already satisfied by the bronze line, so it
// gets no line of its own; every other family constrains the search and earns a distinct one.
const needsOwnLine = id => !OBJECTIVES[id].universal;

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
  let cellUses = 0, moves = 0, maxRunMoved = 0;
  for (const tok of tokens.split(' ')) {
    const f = tok.split(',');
    moves++;
    if (f[0] === 'F') { const col = s.tableau[+f[1]]; const c = col[col.length - 1]; foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
    else if (f[0] === 'G') { const c = s.cells[+f[1]]; foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
    else if (f[0] === 'C') { cellUses++; }
    // largest tableau run relocated — the telemetry the no-supermoves / one-big-move checkers read
    else if (f[0] === 'T') { maxRunMoved = Math.max(maxRunMoved, s.tableau[+f[1]].length - (+f[2])); }
    s = applyMove(s, parseToken(tok));
  }
  return { won: isWon(s), moves, elapsed: 0, cellUses, undos: 0, foundationOrder, maxRunMoved };
}

// Solve seed under one (objective, param) pair and return the winning line as tokens, or null if
// unsolved in budget.
function lineFor(seed, objId, param, budget) {
  const r = solve(dealState(seed), objective(objId, param), { budget, withPath: true });
  return (r.solved === true && r.moves) ? r.moves.map(moveToken).join(' ') : null;
}

const poolPath = arg('pool', 'data/daily-pool.json');
const out = arg('out', 'data/daily-solutions.json');
const budget = Number(arg('budget', 300000));
// The month builder already certified a flawless line per day and cached it; re-use it rather than
// re-searching, and fall back to a fresh search when the cache is cold.
const fcache = new Map();
try {
  for (const line of readFileSync(arg('flawless-cache', '.cache/flawless-certs.jsonl'), 'utf8').split('\n'))
    if (line.trim()) { const r = JSON.parse(line); if (r.ok && r.line) fcache.set(r.k, r.line); }
} catch { /* no cache — every flawless line gets searched below */ }

// --merge: fold several stripe outputs into one file and exit.
const mergeIdx = process.argv.indexOf('--merge');
if (mergeIdx >= 0) {
  const merged = { version: SOLUTIONS_VERSION, solutions: {} };
  const rest = process.argv.slice(mergeIdx + 1);
  const end = rest.findIndex(a => a.startsWith('--'));
  for (const f of (end >= 0 ? rest.slice(0, end) : rest)) {
    const part = JSON.parse(readFileSync(f, 'utf8'));
    Object.assign(merged.solutions, part.solutions);
  }
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, serialize(merged));
  console.log(`merged ${Object.keys(merged.solutions).length} seeds -> ${out}`);
  process.exit(0);
}

const [stripeW, stripeN] = (arg('stripe', '0/1')).split('/').map(Number);
const pool = JSON.parse(readFileSync(poolPath, 'utf8'));
let sol = { version: SOLUTIONS_VERSION, solutions: {} };
try { const prev = JSON.parse(readFileSync(out, 'utf8')); if (prev.version === SOLUTIONS_VERSION) sol = prev; } catch { /* fresh */ }

console.log(`pool ${pool.days.length} days; have ${Object.keys(sol.solutions).length}; budget ${budget}`);
let added = 0, goldOk = 0, silverOk = 0, flawOk = 0, warn = 0;
for (let i = 0; i < pool.days.length; i++) {
  if (i % stripeN !== stripeW) continue;
  const seed = pool.days[i].seed;
  if (sol.solutions[String(seed)] && sol.solutions[String(seed)].bronze) continue;   // resume-friendly
  const ch = dailyChallenge(i, pool);
  if (!ch) { console.log(`! ${seed} no challenge`); warn++; continue; }

  const bronze = lineFor(seed, 'unconstrained', {}, budget);
  if (!bronze || !replay(seed, bronze).won) { console.log(`! ${seed} bronze unsolved`); warn++; continue; }
  const entry = { bronze };

  // Gold — always a certified objective; must win AND satisfy the checker.
  const goldTokens = lineFor(seed, ch.gold.id, ch.gold.param, budget);
  if (goldTokens) {
    const t = replay(seed, goldTokens);
    if (t.won && evaluate(ch.gold, t)) { entry.gold = goldTokens; goldOk++; }
    else { console.log(`! ${seed} gold(${ch.gold.id}) line failed objective check`); warn++; }
  } else { console.log(`! ${seed} gold(${ch.gold.id}) unsolved`); warn++; }

  // Silver — only certified (constraining) objectives get a distinct line; universals fall back to bronze.
  if (needsOwnLine(ch.silver.id)) {
    const silverTokens = lineFor(seed, ch.silver.id, ch.silver.param, budget);
    if (silverTokens) {
      const t = replay(seed, silverTokens);
      if (t.won && evaluate(ch.silver, t)) { entry.silver = silverTokens; silverOk++; }
      else { console.log(`! ${seed} silver(${ch.silver.id}) line failed objective check`); warn++; }
    } else { console.log(`! ${seed} silver(${ch.silver.id}) unsolved`); warn++; }
  }

  // Flawless — ONE line that wins and satisfies BOTH objectives, so "How to win flawless" can
  // demonstrate the thing the 🌟 tier actually asks for. Every day in a v4 pool is certified, so a
  // missing line here is a build bug, not an expected gap: it is reported, loudly.
  const fk = `${seed}|${variantKey(ch.silver.id, ch.silver.param)}|${variantKey(ch.gold.id, ch.gold.param)}`;
  let flawTokens = fcache.get(fk) || null;
  if (!flawTokens) {
    const r = certifyFlawless(seed, ch.silver, ch.gold, { budget });
    if (r.ok) flawTokens = r.moves.map(moveToken).join(' ');
  }
  if (flawTokens) {
    const t = replay(seed, flawTokens);
    if (t.won && evaluate(ch.silver, t) && evaluate(ch.gold, t)) { entry.flawless = flawTokens; flawOk++; }
    else { console.log(`! ${seed} flawless line failed the checkers`); warn++; }
  } else { console.log(`! ${seed} flawless unsolved (${ch.silver.id} + ${ch.gold.id})`); warn++; }

  sol.solutions[String(seed)] = entry;
  added++;
  if (added % 25 === 0) process.stdout.write(`  …${added} (gold ${goldOk}, silver ${silverOk}, flawless ${flawOk})\n`);
}

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, serialize(sol));
console.log(`done: +${added} (gold ${goldOk}, silver ${silverOk}, flawless ${flawOk}, warnings ${warn}), total ${Object.keys(sol.solutions).length} -> ${out}`);
