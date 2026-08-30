// Regression guard for the baked "Show me how to win" data (data/daily-solutions.json).
// build-solutions.mjs validates every line at BUILD time; this re-runs that validation as a CI test
// so a stale/corrupt/hand-edited solutions file — or a rules/checker change that silently invalidates
// a line — can't ship. For every seed and tier we replay the token line from the raw deal and assert
// it WINS, and for Silver/Gold that it also SATISFIES that day's objective checker.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { applyMove, isWon } from '../tools/solver/rules.mjs';
import { dealState } from '../tools/solver/solve.mjs';
import { dailyChallenge, evaluate, OBJECTIVES } from './daily.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const pool = JSON.parse(readFileSync(join(REPO, 'data/daily-pool.json'), 'utf8'));
const sol = JSON.parse(readFileSync(join(REPO, 'data/daily-solutions.json'), 'utf8'));

// Parse a compact token back into the solver move descriptor (mirror of build-solutions.mjs).
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

// Replay a line from the raw deal, reconstructing the telemetry the app's checkers read.
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

test('daily-solutions.json is a well-formed v3 per-tier file covering every seeded day', () => {
  assert.equal(sol.version, 3, 'solutions schema version should be 3 (per-tier + flawless)');
  for (const rec of pool.days) {
    const e = sol.solutions[String(rec.seed)];
    assert.ok(e && typeof e.bronze === 'string' && e.bronze.length, `seed ${rec.seed} missing bronze line`);
    assert.ok(typeof e.flawless === 'string' && e.flawless.length,
              `seed ${rec.seed} missing the flawless line — every day is certified, so one must exist`);
  }
});

// 🌟 "How to win flawless": the baked line is the day's flawless CERTIFICATE, so replaying it must
// win and satisfy BOTH objectives at once. This is the cheap CI form of certifyFlawless.
test('every flawless line wins and earns all three tiers in that single run', () => {
  pool.days.forEach((rec, i) => {
    const ch = dailyChallenge(i, pool);
    const t = replay(rec.seed, sol.solutions[String(rec.seed)].flawless);
    assert.ok(t.won, `seed ${rec.seed} flawless line does not win`);
    assert.ok(evaluate(ch.silver, t), `seed ${rec.seed} flawless line fails Silver (${ch.silver.id})`);
    assert.ok(evaluate(ch.gold, t), `seed ${rec.seed} flawless line fails Gold (${ch.gold.id})`);
  });
});

test('every baked line WINS its deal, and Silver/Gold lines satisfy their objective', () => {
  let goldChecked = 0, silverChecked = 0;
  pool.days.forEach((rec, i) => {
    const seed = rec.seed;
    const e = sol.solutions[String(seed)];
    const ch = dailyChallenge(i, pool);   // the pool names this day's two objectives
    assert.ok(ch, `seed ${seed} has no challenge`);

    const br = replay(seed, e.bronze);
    assert.ok(br.won, `seed ${seed} bronze line does not win`);

    // Every seed MUST bake a gold line — an absent one must not slip through green.
    assert.ok(e.gold, `seed ${seed} missing gold line`);
    {
      const t = replay(seed, e.gold);
      assert.ok(t.won, `seed ${seed} gold line does not win`);
      assert.ok(evaluate(ch.gold, t), `seed ${seed} gold line fails objective ${ch.gold.id}`);
      goldChecked++;
    }
    if (e.silver) {
      const t = replay(seed, e.silver);
      assert.ok(t.won, `seed ${seed} silver line does not win`);
      assert.ok(evaluate(ch.silver, t), `seed ${seed} silver line fails objective ${ch.silver.id}`);
      silverChecked++;
    }
  });
  // Exact expectations, so an absent line can't hide behind a loose lower bound:
  // every seed bakes a gold line, and a silver line iff that day's silver is a distinct
  // baked (certified) objective — i.e. its id is one of the certified-silver ids.
  assert.equal(goldChecked, pool.days.length, `expected a gold line for every seed`);
  // A universal Silver (win in N moves / no undo) is already satisfied by the bronze line, so it
  // bakes none of its own; every other family constrains the search and must bake one.
  const expectedSilver = pool.days.filter((_, i) =>
    !OBJECTIVES[dailyChallenge(i, pool).silver.id].universal
  ).length;
  assert.equal(silverChecked, expectedSilver, `expected ${expectedSilver} certified-silver lines`);
});

test('the pool is two seeded months drawn from the daily seed range', () => {
  assert.equal(pool.version, 4, 'pool schema version should be 4 (flawless-certified, two months)');
  assert.equal(pool.epoch, '2026-08-01');
  assert.equal(pool.days.length, 61, 'August + September 2026 are seeded in full and nothing else is');
  for (const d of pool.days) {
    assert.ok(d.seed >= pool.minSeed && d.seed <= pool.maxSeed, `seed ${d.seed} outside the daily range`);
    assert.ok(d.seed <= 1000000, `seed ${d.seed} exceeds the app's deal-number ceiling`);
  }
  const seeds = new Set(pool.days.map(d => d.seed));
  assert.equal(seeds.size, pool.days.length, 'a seed is used on more than one day');
});
