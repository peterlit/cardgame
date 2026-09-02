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

// ---- the shipped reset gate, RUN: hasLiveGame + graceLiveNow together ----
// bug/Game.swift:grace-forfeited-without-confirm-at-zero-moves — the gate was a bare `moveCount>0`,
// so a challenge OPENED yesterday and not yet moved in (both platforms persist that attempt) was
// thrown away by `New game` / `Replay` / the deal modal with no dialog, and day D's ⏰ Same-day —
// the one loss no replay can undo — was gone for good. String pins cannot see a wrong predicate;
// this runs it.
const liveGate = g => new Function(`
  "use strict";
  let moveCount = ${g.moveCount}, demoing = ${!!g.demoing};
  let challengeDay = ${JSON.stringify(g.challengeDay ?? null)};
  let challengeStartDay = ${JSON.stringify(g.challengeStartDay ?? null)};
  const isWon = () => ${!!g.won};
  const todayIndex = () => ${g.today};
  ${extractDecl('graceLiveNow')}
  ${extractDecl('hasLiveGame')}
  return hasLiveGame();`)();

test('index.html hasLiveGame: a zero-move attempt still carrying a live ⏰ grace is NOT free to discard', () => {
  // opened day 5 on day 5, playing on day 6, no moves yet: ⏰ is still winnable today and a
  // re-deal spends it forever → must confirm.
  assert.equal(liveGate({ moveCount: 0, challengeDay: 5, challengeStartDay: 5, today: 6 }), true,
    'a zero-move attempt begun yesterday forfeits its ⏰ Same-day with no confirmation');
  // ...and the one-tap cases stay one tap.
  assert.equal(liveGate({ moveCount: 0, challengeDay: null, challengeStartDay: null, today: 6 }), false,
    'an untouched casual board grew a pointless confirmation');
  assert.equal(liveGate({ moveCount: 0, challengeDay: 6, challengeStartDay: 6, today: 6 }), false,
    "today's untouched challenge grew a confirmation — there is no grace to lose on the day itself");
  assert.equal(liveGate({ moveCount: 0, challengeDay: 5, challengeStartDay: 5, today: 7 }), false,
    'the grace window is D+1 only — a two-day-old attempt has no ⏰ left to protect');
  assert.equal(liveGate({ moveCount: 3, challengeDay: null, challengeStartDay: null, today: 6 }), true,
    'a played casual board is no longer guarded');
  assert.equal(liveGate({ moveCount: 3, challengeDay: 5, challengeStartDay: 5, today: 6, won: true }), false,
    'a WON board still asks — the win is already banked');
  assert.equal(liveGate({ moveCount: 3, challengeDay: 5, challengeStartDay: 5, today: 6, demoing: true }), false,
    'a demo line still asks — those moves are the app\'s, not the player\'s');
});

// ---- the deal number entry REFUSES what it cannot deal (parity/index.html:deal-entry-clamps-silently) ----
// It used to clamp: typing 5000000 dealt #1000000, a different board from the one asked for, with
// no message, while iOS (ContentView.enteredSeed) refused and named the range.
const parseDealNumber = new Function(`
  "use strict";
  ${extractDecl('DEAL_MIN')}
  ${extractDecl('parseDealNumber')}
  return parseDealNumber;`)();

test('index.html parseDealNumber: out-of-range entries are refused, never clamped to another board', () => {
  assert.equal(parseDealNumber('5000000'), null, 'an above-range deal number is still clamped to a DIFFERENT board');
  assert.equal(parseDealNumber('0'), null, 'a below-range deal number is still clamped to a DIFFERENT board');
  assert.equal(parseDealNumber('-4'), null);
  assert.equal(parseDealNumber(''), null);
  assert.equal(parseDealNumber('  '), null);
  assert.equal(parseDealNumber('abc'), null);
  assert.equal(parseDealNumber('1'), 1, 'the range ends are playable');
  assert.equal(parseDealNumber('1000000'), 1000000, 'the range ends are playable');
  assert.equal(parseDealNumber(' 42 '), 42);
  assert.equal(parseDealNumber('42.7'), 42, 'a fractional entry floors to a playable deal, as it always has');
});

// ---- the daily calendar's month window ----
// The grid used to be drawn from `new Date()` alone, with no control to leave the current month:
// on 2026-09-01 every August day — including an attempt still inside its ⏰ grace — became
// unreachable, and the seeded pool's first month could not be played at all. The month is now
// state (`calY`/`calM`), stepped by clampCalMonth, and the arrows are disabled at the pool's ends.
// These run the SHIPPED helpers, so deleting the clamp or widening it past the pool fails here.
const AUG = 2026 * 12 + 7, SEP = 2026 * 12 + 8, OCT = 2026 * 12 + 9;

test('index.html civilOf: day 0 is 2026-08-01 and the index walks the civil calendar', () => {
  const web = loadWeb();
  assert.deepEqual([web.civilOf(0).y, web.civilOf(0).m, web.civilOf(0).d], [2026, 8, 1]);
  assert.deepEqual([web.civilOf(30).y, web.civilOf(30).m, web.civilOf(30).d], [2026, 8, 31]);
  assert.deepEqual([web.civilOf(31).y, web.civilOf(31).m, web.civilOf(31).d], [2026, 9, 1],
    'the month must roll at the month boundary, or the grid draws the wrong month');
  assert.deepEqual([web.civilOf(60).y, web.civilOf(60).m, web.civilOf(60).d], [2026, 9, 30]);
  assert.equal(web.monthNo(2026, 8), AUG);
  assert.equal(web.monthNo(2026, 9), SEP);
});

test('index.html calMonthRange spans exactly the seeded pool, so no month of dead cells is reachable', () => {
  const web = loadWeb();
  web.set({ dailyPool: new Array(61).fill({}) });     // the shipped pool: 2026-08-01..2026-09-30
  assert.deepEqual(web.calMonthRange(), { min: AUG, max: SEP });
  web.set({ dailyPool: new Array(31).fill({}) });     // a one-month pool collapses to one month
  assert.deepEqual(web.calMonthRange(), { min: AUG, max: AUG });
});

test('index.html clampCalMonth: September can still reach August, and neither end runs off the pool', () => {
  const web = loadWeb();
  web.set({ dailyPool: new Array(61).fill({}) });
  assert.equal(web.clampCalMonth(SEP - 1), AUG,
    'stepping back from the current month must reach the previous one — this is the bug that stranded August');
  assert.equal(web.clampCalMonth(AUG - 1), AUG, 'stepping back from the first seeded month stays put');
  assert.equal(web.clampCalMonth(SEP + 1), SEP, 'stepping forward from the last seeded month stays put');
  assert.equal(web.clampCalMonth(OCT), SEP);
  assert.equal(web.clampCalMonth(AUG), AUG);
});
