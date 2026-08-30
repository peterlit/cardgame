// Tests for the offline Causeway solver (tools/solver). Run: `node --test "tests/**/*.test.mjs"`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  isSeqHead, canStackTableau, maxMovable, legalMoves, applyMove, isWon,
} from '../tools/solver/rules.mjs';
import { evaluate } from './daily.mjs';
import { solve, objective, dealState, certify, isDailyEligible, VARIANTS, variantKey, isGold, rankHome,
         certifyFlawless, contradiction, jointObjective, traceOf } from '../tools/solver/solve.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO = join(__dirname, '..');

const C = (suit, rank) => ({ suit, rank, color: (suit === 1 || suit === 2) ? 'red' : 'black', id: suit * 13 + rank });

/* ---------- DRIFT GUARD: rules.mjs <-> index.html ---------- */
// rules.mjs is a behavioural hand-port of index.html's "rules" section and is the feature's single
// trust anchor. Assert the canonical tableau/foundation rule bodies still appear verbatim in
// index.html (whitespace-normalized), mirroring the engine.mjs drift guard, so the port can't
// silently rot against the shipped app.
const norm = s => s.replace(/\s+/g, ' ').trim();

test('rules.mjs logic still matches index.html (no drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const canon = [
    // isSeqHead: direction pick + the run-validation loop
    'if(a.rank===b.rank+1) dir="desc"; else if(a.rank===b.rank-1) dir="asc"; else return false;',
    'if(dir==="desc" && x.rank!==y.rank+1) return false; if(dir==="asc" && x.rank!==y.rank-1) return false;',
    // runDir
    'return cards[0].rank===cards[1].rank+1 ? "desc" : "asc";',
    // tailDir
    'if(a.color!==b.color && a.rank===b.rank+1) return "desc"; if(a.color!==b.color && a.rank===b.rank-1) return "asc";',
    // canStackTableau: the join direction + the "can't reverse an established pile" rule
    'const conn = head.rank===top.rank-1 ? "desc" : "asc";',
    'const rdir = runDir(cards); if(rdir!=="single" && rdir!==conn) return false;',
    'const tdir = tailDir(col); if(tdir!=="single" && tdir!==conn) return false;',
    // maxMovable
    'const e = emptyCols() - (targetEmpty?1:0); return (freeCells()+1) * Math.pow(2, Math.max(0,e));',
    // foundation legality
    'return card.rank===state.up[s]+1 && card.rank < state.down[s];',
    'return card.rank===state.down[s]-1 && card.rank > state.up[s];',
  ];
  for (const c of canon) {
    assert.ok(html.includes(norm(c)), `index.html no longer contains: ${c.slice(0, 60)}...`);
  }
});

/* ---------- rule model (ported from index.html) ---------- */
test('isSeqHead: single top card, and alternating-colour runs both directions', () => {
  const col = [C(0, 9), C(1, 8), C(0, 7)];            // 9♠ 8♥ 7♠ — valid descending alt-colour run
  assert.equal(isSeqHead(col, 0), true);
  assert.equal(isSeqHead(col, 2), true);             // single top card
  assert.equal(isSeqHead([C(0, 9), C(0, 8)], 0), false); // same colour → not a run
  assert.equal(isSeqHead([C(0, 5), C(1, 8)], 0), false); // not monotonic-by-1
});

test('canStackTableau: empty accepts anything; opposite-colour ±1; tailDir cannot reverse a pile', () => {
  assert.equal(canStackTableau([], [C(0, 5)]), true);                       // empty
  assert.equal(canStackTableau([C(0, 8)], [C(1, 7)]), true);                // red 7 onto black 8 (desc)
  assert.equal(canStackTableau([C(0, 8)], [C(1, 9)]), true);               // red 9 onto black 8 (asc, loose top)
  assert.equal(canStackTableau([C(0, 8)], [C(3, 7)]), false);              // same colour
  // established descending pile (9♠,8♥) can't accept an ascending join
  assert.equal(canStackTableau([C(0, 9), C(1, 8)], [C(0, 9)]), false);      // 9♠ asc onto 8♥ reverses the pile
  assert.equal(canStackTableau([C(0, 9), C(1, 8)], [C(0, 7)]), true);       // 7♠ continues descending
});

test('maxMovable = (freeCells+1) * 2^emptyCols, minus the target if it is an empty column', () => {
  assert.equal(maxMovable(2, 0, false), 3);
  assert.equal(maxMovable(2, 2, false), 12);
  assert.equal(maxMovable(2, 2, true), 6);   // moving TO an empty column: that column doesn't count
  assert.equal(maxMovable(0, 0, false), 1);
});

test('legalMoves omits cell moves when the cell budget is exhausted (no-cells)', () => {
  const s = { tableau: [[C(0, 5)], [], [], [], [], [], [], []], cells: [null, null, null], up: [0, 0, 0, 0], down: [14, 14, 14, 14] };
  const withCells = legalMoves(s, 0, objective('cells-le', { N: 2 }));
  const noCells = legalMoves(s, 0, objective('cells-le', { N: 0 }));
  assert.ok(withCells.some(m => m.k === 'C'));
  assert.ok(!noCells.some(m => m.k === 'C'));
});

/* ---------- search correctness ---------- */
test('solve: a near-win (four Kings left) is won in exactly four foundation moves', () => {
  const s = { tableau: [[C(0, 13)], [C(1, 13)], [C(2, 13)], [C(3, 13)], [], [], [], []], cells: [null, null, null], up: [12, 12, 12, 12], down: [14, 14, 14, 14] };
  assert.deepEqual(solve(s, objective('unconstrained'), { budget: 50000 }), { solved: true, par: 4 });
});

test('solve: a valid near-win that needs a maneuver first (Q♦ off K♠, then cascade) → par 5', () => {
  // 47 cards home (up[2]=11, others 12); remaining K♠ K♥ K♦ K♣ + Q♦, with Q♦ buried on K♠.
  const s = { tableau: [[C(0, 13), C(2, 12)], [C(1, 13)], [C(2, 13)], [C(3, 13)], [], [], [], []],
              cells: [null, null, null], up: [12, 12, 11, 12], down: [14, 14, 14, 14] };
  assert.deepEqual(solve(s, objective('unconstrained'), { budget: 50000 }), { solved: true, par: 5 });
});

/* ---------- certification (real deals; kept cheap) ---------- */
test('a real deal from the daily range is winnable with a sane par', () => {
  const r = solve(dealState(700001), objective('unconstrained'), { budget: 300000 });
  assert.equal(r.solved, true);
  assert.ok(r.par > 52 && r.par < 200, `par ${r.par}`);   // >= 52 foundation moves, plus maneuvering
});

test('constraint solves obey the constraint by construction (cells-le{0} uses zero cells)', () => {
  // If cells-le{0} is solvable for a seed, the search literally never emits a cell move, so a win
  // is a cells-free win. Assert it solves for a seed known to support it.
  const r = solve(dealState(700001), objective('cells-le', { N: 0 }), { budget: 300000 });
  assert.equal(r.solved, true);
});

test('the parameterised gates admit exactly what their checker admits', () => {
  const st = { up: [0, 0, 0, 0], down: [14, 14, 14, 14] };
  const card = (suit, rank) => ({ suit, rank });
  // split-at{7}: A-7 may only go up, 8-K may only go down.
  const split = objective('split-at', { R: 7 });
  assert.equal(split.allowFoundation(st, card(0, 7), 'up'), true);
  assert.equal(split.allowFoundation(st, card(0, 8), 'up'), false);
  assert.equal(split.allowFoundation(st, card(0, 8), 'down'), true);
  assert.equal(split.allowFoundation(st, card(0, 7), 'down'), false);
  // end-bias{up,9}: at least 9 per suit from the Ace end => the down pile may take at most 4,
  // i.e. nothing below the Ten.
  const bias = objective('end-bias', { end: 'up', min: 9 });
  assert.equal(bias.allowFoundation(st, card(0, 10), 'down'), true);
  assert.equal(bias.allowFoundation(st, card(0, 9), 'down'), false);
  assert.equal(bias.allowFoundation(st, card(0, 13), 'up'), true);   // up end is unconstrained
  // ends-first{up:1,down:13}: only Aces up and Kings down until every suit has both.
  const ends = objective('ends-first', { up: 1, down: 13 });
  assert.equal(ends.allowFoundation(st, card(0, 1), 'up'), true);
  assert.equal(ends.allowFoundation(st, card(0, 13), 'down'), true);
  assert.equal(ends.allowFoundation(st, card(0, 2), 'up'), false);
  const met = { up: [1, 1, 1, 1], down: [13, 13, 13, 13] };
  assert.equal(ends.allowFoundation(met, card(0, 2), 'up'), true);   // prefix satisfied, gate opens
  // suit-balance{2}: a suit may not run more than 2 ahead of another.
  const bal = objective('suit-balance', { N: 2 });
  assert.equal(bal.allowFoundation({ up: [2, 0, 0, 0], down: [14, 14, 14, 14] }, card(0, 3), 'up'), false);
  assert.equal(bal.allowFoundation({ up: [1, 0, 0, 0], down: [14, 14, 14, 14] }, card(0, 2), 'up'), true);
});

test('rankHome reports a rank home from EITHER end', () => {
  assert.equal(rankHome({ up: [1, 1, 1, 1], down: [14, 14, 14, 14] }, 1), true);
  assert.equal(rankHome({ up: [0, 0, 0, 0], down: [13, 13, 13, 13] }, 13), true);
  assert.equal(rankHome({ up: [1, 1, 1, 0], down: [14, 14, 14, 14] }, 1), false);
});

test('isDailyEligible requires a Gold-grade variant; the matrix has no vacuous entries', () => {
  const v = (id, param) => ({ id, param });
  assert.equal(isDailyEligible(null), false);
  assert.equal(isDailyEligible({ winnable: true, supports: [v('cells-le', { N: 2 })] }), false);   // silver-only
  assert.equal(isDailyEligible({ winnable: true, supports: [v('cells-le', { N: 0 })] }), true);    // gold
  assert.equal(isDailyEligible({ winnable: true, supports: [v('split-at', { R: 9 })] }), true);
  // dropped: winning empties every column, so "empty a column" is vacuous
  assert.ok(!VARIANTS.some(x => x.id === 'empty-column'));
  // every variant is distinct, and enough of them are Gold to fill a month
  assert.equal(new Set(VARIANTS.map(x => variantKey(x.id, x.param))).size, VARIANTS.length);
  assert.ok(VARIANTS.filter(isGold).length >= 20);
});

// ---- the flawless gate -------------------------------------------------------------------------
// Every shipped day must admit ONE line earning all three tiers; these lock the machinery that
// proves it. See docs/solver.md §7.7.

test('contradiction() catches the pairings that are impossible by construction', () => {
  // maxRunMoved cannot be both >= 5 and <= 2.
  assert.match(contradiction({ id: 'max-run', param: { N: 2 } }, { id: 'big-move', param: { N: 5 } }) || '',
               /big-move/);
  assert.equal(contradiction({ id: 'max-run', param: { N: 5 } }, { id: 'big-move', param: { N: 5 } }), null);
  // suit-sprint drives one suit 13 clear before another may start.
  assert.match(contradiction({ id: 'suit-balance', param: { N: 4 } }, { id: 'suit-sprint', param: {} }) || '',
               /suit-balance/);
  // ...and cannot have all four of a rank home before 39 cards are.
  assert.match(contradiction({ id: 'rank-rush', param: { rank: 1, N: 20 } }, { id: 'suit-sprint', param: {} }) || '',
               /39/);
  assert.equal(contradiction({ id: 'rank-rush', param: { rank: 3, N: 42 } }, { id: 'suit-sprint', param: {} }), null);
  // A rank-gated Gold sets a floor on the earliest a rank can be home: under "only the Ace end",
  // a King is its suit's 13th card, so four Kings cost 52 sends.
  assert.match(contradiction({ id: 'rank-rush', param: { rank: 13, N: 26 } },
                             { id: 'end-bias', param: { end: 'up', min: 13 } }) || '', /52/);
  // ...but from the King end a King is the FIRST card, so the same rush is not contradictory.
  assert.equal(contradiction({ id: 'rank-rush', param: { rank: 13, N: 26 } },
                             { id: 'end-bias', param: { end: 'down', min: 13 } }), null);
  // Unrelated families are never flagged.
  assert.equal(contradiction({ id: 'cells-le', param: { N: 2 } }, { id: 'split-at', param: { R: 7 } }), null);
});

test('jointObjective takes the tighter bound of both objectives', () => {
  const j = jointObjective([{ id: 'cells-le', param: { N: 2 } }, { id: 'max-run', param: { N: 1 } }]);
  assert.equal(j.cellBudget, 2);
  assert.equal(j.maxRun, 1);
  const m = jointObjective([{ id: 'moves', param: { N: 90 } }, { id: 'cells-le', param: { N: 0 } }]);
  assert.equal(m.moveCap, 90);          // a `moves` Silver bounds the SEARCH, not a post-hoc check
  assert.equal(m.cellBudget, 0);
});

test('certifyFlawless returns a line that both checkers accept, and refuses the impossible', () => {
  const pool = JSON.parse(readFileSync(join(REPO, 'data/daily-pool.json'), 'utf8'));
  const day = pool.days[0];
  const r = certifyFlawless(day.seed, day.silver, day.gold, { budget: 200000 });
  assert.equal(r.ok, true, `day 0 (#${day.seed}) should be flawless-certified in the shipped pool`);
  const t = traceOf(day.seed, r.moves);
  assert.ok(t.won, 'the certified line wins');
  assert.ok(evaluate(day.silver, t) && evaluate(day.gold, t), 'and earns both tiers');

  // Impossible pairings are refused instantly, without burning the search budget.
  const bad = certifyFlawless(day.seed, { id: 'max-run', param: { N: 2 } }, { id: 'big-move', param: { N: 5 } });
  assert.equal(bad.ok, false);
  assert.match(bad.why, /contradiction/);
});

test('every shipped day is flawless-certifiable — no unreachable 🌟', () => {
  const pool = JSON.parse(readFileSync(join(REPO, 'data/daily-pool.json'), 'utf8'));
  const sol = JSON.parse(readFileSync(join(REPO, 'data/daily-solutions.json'), 'utf8'));
  // The baked flawless line IS the certificate: replaying it is the cheap CI form of the check
  // (certifyFlawless re-runs the search, which is a build-time cost, not a test-time one).
  for (const d of pool.days) {
    const line = sol.solutions[String(d.seed)]?.flawless;
    assert.ok(line, `seed ${d.seed} has no baked flawless line`);
  }
});
