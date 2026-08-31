// BEHAVIOURAL guard on the shipped web copies in index.html (not a string pin).
//
// `objViolated` is the live HUD's fail-fast hint: it decides when a tier's chip goes ✗, and — far
// more expensively — it is the predicate BOTH auto-play refusals are computed from
// (autoSendWouldBreakTier, autoFinishTierCost). It had already rotted once: all three copies sat on
// a pre-parameterised id set ('aces-first', 'split-even', 'cells-le-1'), none of which the pool can
// emit any more, so every objective fell through to `default: false` and nothing ever went ✗. The
// suite did not notice for months, because the only objViolated assertions in it exercised
// tests/daily.mjs — the canonical copy nobody ships.
//
// So: lift the shipped web copy out of index.html and run the same table against it and against the
// canonical one. Every family gets a violated case AND a still-live case, so a body neutered to
// `return false` (or to `return true`) fails here. tests/daily.mjs's own behaviour is pinned by
// daily.test.mjs; this file's job is only "the shipped copy agrees, family for family".
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { objViolated as canonViolated, objSecured as canonSecured, OBJECTIVES } from './daily.mjs';
import { loadWeb, blankTelem, extractDecl } from './web-extract.mjs';

const web = loadWeb();


// The extraction itself is load-bearing: every assertion in this file means "the SHIPPED code does
// this" only if extractDecl really returned the shipped declaration. It used to accept an indented
// match, so a nested local of the same name could be lifted instead of the top-level one the page
// calls — and the tests would go green on the decoy. Anchored at column 0 now, with ambiguity fatal.
test('extractDecl lifts the top-level declaration, never an indented decoy, and refuses ambiguity', () => {
  const shipped = `function objViolated(obj, t){ return true; }\n`;
  const decoy = `  const objViolated = (obj, t) => false;\n`;
  assert.match(extractDecl('objViolated', decoy + shipped), /return true/,
    'extractDecl picked an INDENTED declaration over the top-level one — the behavioural tests below would be running code the page never calls');
  assert.match(extractDecl('objViolated', shipped + decoy), /return true/);
  assert.throws(() => extractDecl('objViolated', decoy),
    /no top-level \(column-0\) declaration/,
    'extractDecl accepted a nested-only declaration as if it were shipped code');
  assert.throws(() => extractDecl('objViolated', shipped + shipped),
    /declared 2 times at top level/,
    'two flush-left declarations of one name must be an error, not a silent pick of the first');
  assert.throws(() => extractDecl('noSuchShippedFunction'), /noSuchShippedFunction/);
});

// One foundation event stream from a compact "suit rank end" spec; moveIdx is 1-based play order.
const fo = (...evs) => evs.map(([suit, rank, end], i) => ({ suit, rank, end, moveIdx: i + 1 }));
// Every card of `suit` from the ace end, up to and including `n`.
const upRun = (suit, n, from = 1) => Array.from({ length: n }, (_, i) => [suit, from + i, 'up']);
const downRun = (suit, n, from = 13) => Array.from({ length: n }, (_, i) => [suit, from - i, 'down']);
const t = (over = {}) => blankTelem({ won: false, moves: 10, elapsed: 0, ...over });

// [label, objective, attempt, expected objViolated]
// Two rows per family: the tier is dead, and the tier is still open on a comparable position.
const CASES = [
  ['moves: budget blown',        { id: 'moves', param: { N: 60 } }, t({ moves: 61 }), true],
  ['moves: budget intact',       { id: 'moves', param: { N: 60 } }, t({ moves: 60 }), false],
  ['no-undo: undid one',         { id: 'no-undo', param: {} }, t({ undos: 1 }), true],
  ['no-undo: never undid',       { id: 'no-undo', param: {} }, t({ undos: 0 }), false],
  ['cells-le: cell budget gone', { id: 'cells-le', param: { N: 2 } }, t({ cellUses: 3 }), true],
  ['cells-le: cell budget left', { id: 'cells-le', param: { N: 2 } }, t({ cellUses: 2 }), false],
  ['max-run: moved a pair',      { id: 'max-run', param: { N: 1 } }, t({ maxRunMoved: 2 }), true],
  ['max-run: singles only',      { id: 'max-run', param: { N: 1 } }, t({ maxRunMoved: 1 }), false],
  // Positive goal: still reachable from any position, so never violated. Only a `return true`
  // mutation is observable here, and that one matters — it would black out the 🥇 chip all game.
  ['big-move: never impossible', { id: 'big-move', param: { N: 5 } }, t({ maxRunMoved: 0 }), false],
  ['split-at: one too far up',   { id: 'split-at', param: { R: 7 } }, t({ foundationOrder: fo(...upRun(0, 8)) }), true],
  ['split-at: exactly at R',     { id: 'split-at', param: { R: 7 } }, t({ foundationOrder: fo(...upRun(0, 7)) }), false],
  ['split-at: one too far down', { id: 'split-at', param: { R: 7 } }, t({ foundationOrder: fo(...downRun(2, 7)) }), true],
  ['end-bias up: 4 came down',   { id: 'end-bias', param: { end: 'up', min: 10 } }, t({ foundationOrder: fo(...downRun(1, 4)) }), true],
  ['end-bias up: 3 came down',   { id: 'end-bias', param: { end: 'up', min: 10 } }, t({ foundationOrder: fo(...downRun(1, 3)) }), false],
  ['end-bias down: 4 went up',   { id: 'end-bias', param: { end: 'down', min: 10 } }, t({ foundationOrder: fo(...upRun(3, 4)) }), true],
  ['end-bias down: 3 went up',   { id: 'end-bias', param: { end: 'down', min: 10 } }, t({ foundationOrder: fo(...upRun(3, 3)) }), false],
  ['ends-first: a Two jumped in',  { id: 'ends-first', param: { up: 1, down: 14 } },
    t({ foundationOrder: fo([0, 1, 'up'], [1, 2, 'up']) }), true],
  ['ends-first: aces still first', { id: 'ends-first', param: { up: 1, down: 14 } },
    t({ foundationOrder: fo([0, 1, 'up'], [1, 1, 'up']) }), false],
  ['before-ace: an ace beat the kings', { id: 'before-ace', param: { rank: 13 } },
    t({ foundationOrder: fo([0, 13, 'down'], [1, 1, 'up']) }), true],
  ['before-ace: all kings down first',  { id: 'before-ace', param: { rank: 13 } },
    t({ foundationOrder: fo([0, 13, 'down'], [1, 13, 'down'], [2, 13, 'down'], [3, 13, 'down'], [1, 1, 'up']) }), false],
  ['suit-top-first: own ace beat own king', { id: 'suit-top-first', param: { rank: 13 } },
    t({ foundationOrder: fo([1, 13, 'down'], [0, 1, 'up']) }), true],
  ['suit-top-first: own king came first',   { id: 'suit-top-first', param: { rank: 13 } },
    t({ foundationOrder: fo([0, 13, 'down'], [0, 1, 'up']) }), false],
  ['suit-sprint: second suit started early', { id: 'suit-sprint', param: {} },
    t({ foundationOrder: fo([0, 1, 'up'], [1, 1, 'up']) }), true],
  ['suit-sprint: one suit finished first',   { id: 'suit-sprint', param: {} },
    t({ foundationOrder: fo(...upRun(0, 13), [1, 1, 'up']) }), false],
  ['rank-rush: fourth ace arrived late', { id: 'rank-rush', param: { rank: 1, N: 3 } },
    t({ foundationOrder: fo([0, 1, 'up'], [1, 1, 'up'], [2, 1, 'up'], [3, 1, 'up']) }), true],
  ['rank-rush: all four inside the deadline', { id: 'rank-rush', param: { rank: 1, N: 4 } },
    t({ foundationOrder: fo([0, 1, 'up'], [1, 1, 'up'], [2, 1, 'up'], [3, 1, 'up']) }), false],
  ['rank-rush: deadline blown, cards still out', { id: 'rank-rush', param: { rank: 1, N: 4 } },
    t({ moves: 5, foundationOrder: fo([0, 1, 'up'], [1, 1, 'up']) }), true],
  ['suit-balance: one suit ran away', { id: 'suit-balance', param: { N: 3 } },
    t({ foundationOrder: fo(...upRun(0, 4)) }), true],
  ['suit-balance: still inside the spread', { id: 'suit-balance', param: { N: 3 } },
    t({ foundationOrder: fo(...upRun(0, 3)) }), false],
];

test('index.html objViolated: the SHIPPED web copy answers every family correctly', () => {
  for (const [label, obj, att, expected] of CASES) {
    assert.equal(web.objViolated(obj, att), expected,
      `index.html objViolated is wrong for ${label} (${obj.id}) — the live ✗ hint and BOTH auto-play refusals read this`);
  }
});

test('index.html objViolated agrees with the canonical tests/daily.mjs copy on every case', () => {
  for (const [label, obj, att] of CASES) {
    assert.equal(web.objViolated(obj, att), canonViolated(obj, att),
      `web↔canonical objViolated drift on ${label} (${obj.id})`);
  }
});

// The rot this file exists to catch was structural, not arithmetic: the switch was keyed on ids the
// pool cannot emit, so EVERY objective fell through to `default: false`. A table can only cover the
// families someone remembered to add, so pin the coverage itself against the objective registry.
test('every objective family the pool can emit is covered by a violated AND a live case', () => {
  const seen = new Map();
  for (const [, obj, , expected] of CASES) {
    const s = seen.get(obj.id) || new Set();
    s.add(expected); seen.set(obj.id, s);
  }
  for (const id of Object.keys(OBJECTIVES)) {
    assert.ok(seen.has(id), `objective family '${id}' has no objViolated case — add one (this is the exact gap that let the checker rot)`);
    // 'big-move' is a positive goal: it is never violated, by design.
    if (id === 'big-move') { assert.deepEqual([...seen.get(id)], [false]); continue; }
    assert.equal(seen.get(id).size, 2,
      `objective family '${id}' is only tested in one direction — a constant rewrite of its case would survive`);
  }
});

// objSecured already has a text pin for end-bias (ios-parity); give the shipped web copy the same
// behavioural treatment while we have it loaded, since objSecured calls objViolated first.
test('index.html objSecured: end-bias secures from live board state, and a violated tier never secures', () => {
  const obj = { id: 'end-bias', param: { end: 'up', min: 10 } };
  const up = [10, 10, 11, 13], down = [14, 14, 14, 14];
  const clean = t({ foundationOrder: fo(...upRun(0, 10)) });
  assert.equal(web.objSecured(obj, up, down, clean), true, 'web objSecured stopped securing a banked end-bias');
  assert.equal(canonSecured(obj, up, down, clean), true);
  const blown = t({ foundationOrder: fo(...downRun(1, 4)) });
  assert.equal(web.objSecured(obj, up, down, blown), false,
    'web objSecured secures a tier objViolated already killed — objViolated is no longer its first gate');
});
