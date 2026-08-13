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
import { dailyChallenge, evaluate } from './daily.mjs';

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

test('daily-solutions.json is a well-formed v2 per-tier file covering every pool seed', () => {
  assert.equal(sol.version, 2, 'solutions schema version should be 2 (per-tier)');
  for (const rec of pool.seeds) {
    const e = sol.solutions[String(rec.seed)];
    assert.ok(e && typeof e.bronze === 'string' && e.bronze.length, `seed ${rec.seed} missing bronze line`);
  }
});

test('every baked line WINS its deal, and Silver/Gold lines satisfy their objective', () => {
  let goldChecked = 0, silverChecked = 0;
  pool.seeds.forEach((rec, i) => {
    const seed = rec.seed;
    const e = sol.solutions[String(seed)];
    const ch = dailyChallenge(i, pool);   // objectives keyed by pool index (frozen)
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
  assert.equal(goldChecked, pool.seeds.length, `expected a gold line for every seed`);
  const expectedSilver = pool.seeds.filter((_, i) =>
    ['cells-le-1', 'cells-le-2', 'down-openers-20'].includes(dailyChallenge(i, pool).silver.id)
  ).length;
  assert.equal(silverChecked, expectedSilver, `expected ${expectedSilver} certified-silver lines`);
});
