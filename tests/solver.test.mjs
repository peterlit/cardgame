// Tests for the offline Causeway solver (tools/solver). Run: `node --test "tests/**/*.test.mjs"`.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  isSeqHead, canStackTableau, maxMovable, legalMoves, applyMove, isWon,
} from '../tools/solver/rules.mjs';
import { solve, objective, dealState, certify, isDailyEligible, CERTIFIED } from '../tools/solver/solve.mjs';

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
  const withCells = legalMoves(s, 0, objective('cells-le-2'));
  const noCells = legalMoves(s, 0, objective('no-cells'));
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
test('a real deal above 10,000 is winnable with a sane par', () => {
  const r = solve(dealState(10002), objective('unconstrained'), { budget: 300000 });
  assert.equal(r.solved, true);
  assert.ok(r.par > 52 && r.par < 200, `par ${r.par}`);   // >= 52 foundation moves, plus maneuvering
});

test('constraint solves obey the constraint by construction (no-cells uses zero cells)', () => {
  // If no-cells is solvable for a seed, the search literally never emits a cell move, so a win is a
  // cells-free win. Assert it solves for a seed known to support it.
  const r = solve(dealState(10002), objective('no-cells'), { budget: 300000 });
  assert.equal(r.solved, true);
});

test('isDailyEligible requires a Gold-grade objective; CERTIFIED has no vacuous entries', () => {
  assert.equal(isDailyEligible(null), false);
  assert.equal(isDailyEligible({ winnable: true, supports: ['cells-le-2'] }), false);       // silver-only
  assert.equal(isDailyEligible({ winnable: true, supports: ['aces-first'] }), true);
  assert.ok(!CERTIFIED.includes('empty-column'));   // dropped: winning empties every column
});
