// Tests for the shared Daily-Challenges logic (tests/daily.mjs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  dayIndexFor, dailyChallenge, evaluate, evaluateChallenge, mergeTiers, streaks,
  OBJECTIVES, gradeOf, labelOf, isOnTime, objViolated, objSecured, mergeRuns, RUN_LOG_MAX,
} from './daily.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const norm = s => s.replace(/\s+/g, ' ').trim();

// A tiny fake pool in the shipped shape: each day names its own two objectives.
const POOL = {
  version: 3, epoch: '2026-08-01', minSeed: 500001, maxSeed: 1000000,
  days: [
    { seed: 500123, par: 80, silver: { id: 'cells-le', param: { N: 2 } }, gold: { id: 'split-at', param: { R: 9 } } },
    { seed: 900456, par: 90, silver: { id: 'moves', param: { N: 99 } }, gold: { id: 'ends-first', param: { up: 2, down: 12 } } },
    // day 2 pairs a universal Silver with a counter-based Gold, so the grading tests below can
    // drive both tiers straight from the plain telemetry counters.
    { seed: 777777, par: 80, silver: { id: 'moves', param: { N: 96 } }, gold: { id: 'cells-le', param: { N: 0 } } },
  ],
};

const f = (suit, rank, end, moveIdx) => ({ suit, rank, end, moveIdx });
const base = over => ({ won: true, moves: 50, elapsed: 60, cellUses: 0, undos: 0, usedAutoplay: false, usedAutoFinish: false, maxRunMoved: 0, foundationOrder: [], ...over });
const ev = (id, param, t) => evaluate({ id, param }, t);
// A complete, legal foundation stream: every suit takes A..split from the up end and K..split+1
// from the down end, ups first then downs. `order` may reshuffle the events.
const fullStream = (split = [7, 7, 7, 7]) => {
  const out = [];
  let i = 0;
  for (let s = 0; s < 4; s++) for (let r = 1; r <= split[s]; r++) out.push(f(s, r, 'up', ++i));
  for (let s = 0; s < 4; s++) for (let r = 13; r > split[s]; r--) out.push(f(s, r, 'down', ++i));
  return out;
};

/* ---------- calendar ---------- */
test('day index: the launch epoch is 2026-08-01 = day 0, and days advance by one', () => {
  assert.equal(dayIndexFor(2026, 8, 1), 0);
  assert.equal(dayIndexFor(2026, 8, 2), 1);
  assert.equal(dayIndexFor(2026, 8, 31), 30);
  assert.equal(dayIndexFor(2026, 9, 1), 31);
  assert.equal(dayIndexFor(2026, 7, 31), -1);
});

/* ---------- the day -> challenge lookup ---------- */
test('dailyChallenge reads the day straight out of the pool, with labels resolved', () => {
  const c = dailyChallenge(0, POOL);
  assert.equal(c.seed, 500123);
  assert.equal(c.par, 80);
  assert.equal(c.silver.id, 'cells-le');
  assert.deepEqual(c.silver.param, { N: 2 });
  assert.equal(c.silver.label, 'Win using free cells at most twice');
  assert.equal(c.gold.label, 'Split every suit exactly at the Nine — A-9 up, 10-K down');
  assert.equal(c.gold.grade, 'gold');
  assert.equal(c.silver.grade, 'silver');
});

test('dailyChallenge is nil outside the seeded month (no challenge before or after)', () => {
  assert.equal(dailyChallenge(-1, POOL), null);
  assert.equal(dailyChallenge(3, POOL), null);
  assert.equal(dailyChallenge(400, POOL), null);
});

test('a day is stable: the same index always yields the same seed and objectives', () => {
  assert.deepEqual(dailyChallenge(1, POOL), dailyChallenge(1, POOL));
});

/* ---------- grades and labels are functions of the PARAMETER ---------- */
test('a family grades and labels itself from its parameter', () => {
  assert.equal(gradeOf('cells-le', { N: 0 }), 'gold');      // never touching a cell is a Gold
  assert.equal(gradeOf('cells-le', { N: 2 }), 'silver');
  assert.equal(gradeOf('end-bias', { end: 'up', min: 13 }), 'gold');
  assert.equal(gradeOf('end-bias', { end: 'up', min: 8 }), 'silver');
  assert.equal(gradeOf('suit-balance', { N: 3 }), 'gold');
  assert.equal(gradeOf('suit-balance', { N: 5 }), 'silver');

  assert.equal(labelOf('cells-le', { N: 0 }), 'Win without ever using a free cell');
  assert.equal(labelOf('cells-le', { N: 1 }), 'Win using free cells at most once');
  assert.equal(labelOf('cells-le', { N: 3 }), 'Win using free cells at most 3 times');
  assert.equal(labelOf('max-run', { N: 1 }), 'Move one card at a time — never move a run');
  assert.equal(labelOf('max-run', { N: 3 }), 'Never move more than 3 cards in a single move');
  assert.equal(labelOf('ends-first', { up: 1, down: 14 }), 'Send all four Aces home before any other card');
  assert.equal(labelOf('ends-first', { up: 0, down: 13 }), 'Send all four Kings home before any other card');
  assert.equal(labelOf('ends-first', { up: 2, down: 12 }),
    'Send all four Aces and Twos, plus all four Kings and Queens home before any other card');
  assert.equal(labelOf('ends-first', { up: 3, down: 14 }), 'Send all four Aces, Twos and Threes home before any other card');
  assert.equal(labelOf('end-bias', { end: 'down', min: 13 }), 'Win using only the King-end foundations — every suit K down to A');
  assert.equal(labelOf('end-bias', { end: 'up', min: 9 }), 'Take at least 9 of every suit from the Ace end');
  assert.equal(labelOf('rank-rush', { rank: 6, N: 18 }), 'Get all four Sixes home within your first 18 moves');
  assert.equal(labelOf('before-ace', { rank: 12 }), 'Get every Queen onto the King-end foundation before any Ace goes home');
});

test('every objective in the catalogue produces a label and a grade for a plausible parameter', () => {
  const sample = { N: 2, R: 7, rank: 13, min: 9, up: 1, down: 13, end: 'up' };
  for (const id of Object.keys(OBJECTIVES)) {
    const label = labelOf(id, sample);
    assert.ok(label && label !== id, `${id} has no label`);
    assert.ok(['silver', 'gold'].includes(gradeOf(id, sample)), `${id} has no grade`);
  }
});

/* ---------- objective checkers vs telemetry fixtures ---------- */
test('cells-le / max-run / big-move read their counters against the parameter', () => {
  assert.equal(ev('cells-le', { N: 0 }, base({ cellUses: 0 })), true);
  assert.equal(ev('cells-le', { N: 0 }, base({ cellUses: 1 })), false);
  assert.equal(ev('cells-le', { N: 3 }, base({ cellUses: 3 })), true);
  assert.equal(ev('cells-le', { N: 3 }, base({ cellUses: 4 })), false);
  assert.equal(ev('max-run', { N: 1 }, base({ maxRunMoved: 1 })), true);
  assert.equal(ev('max-run', { N: 1 }, base({ maxRunMoved: 2 })), false);
  assert.equal(ev('max-run', { N: 3 }, base({ maxRunMoved: 3 })), true);
  assert.equal(ev('big-move', { N: 5 }, base({ maxRunMoved: 5 })), true);
  assert.equal(ev('big-move', { N: 6 }, base({ maxRunMoved: 5 })), false);
  assert.equal(ev('big-move', { N: 5 }, base({ maxRunMoved: 9 })), true);
  // a missing maxRunMoved (an older saved attempt) reads as zero, not as a pass
  assert.equal(ev('big-move', { N: 5 }, base({ maxRunMoved: undefined })), false);
  assert.equal(ev('max-run', { N: 1 }, base({ maxRunMoved: undefined })), true);
});

test('split-at passes only at exactly its split point', () => {
  assert.equal(ev('split-at', { R: 7 }, base({ foundationOrder: fullStream([7, 7, 7, 7]) })), true);
  assert.equal(ev('split-at', { R: 9 }, base({ foundationOrder: fullStream([9, 9, 9, 9]) })), true);
  assert.equal(ev('split-at', { R: 9 }, base({ foundationOrder: fullStream([9, 9, 9, 8]) })), false);
  assert.equal(ev('split-at', { R: 7 }, base({ foundationOrder: fullStream([9, 9, 9, 9]) })), false);
});

test('end-bias counts how much of every suit came from the named end', () => {
  const t = base({ foundationOrder: fullStream([3, 3, 4, 3]) });   // 3-4 up, 9-10 down per suit
  assert.equal(ev('end-bias', { end: 'down', min: 9 }, t), true);
  assert.equal(ev('end-bias', { end: 'down', min: 10 }, t), false);   // one suit only took 9 down
  assert.equal(ev('end-bias', { end: 'up', min: 3 }, t), true);
  assert.equal(ev('end-bias', { end: 'up', min: 4 }, t), false);
  // min = 13 is the one-end game
  assert.equal(ev('end-bias', { end: 'up', min: 13 }, base({ foundationOrder: fullStream([13, 13, 13, 13]) })), true);
  assert.equal(ev('end-bias', { end: 'down', min: 13 }, base({ foundationOrder: fullStream([0, 0, 0, 0]) })), true);
  assert.equal(ev('end-bias', { end: 'down', min: 13 }, base({ foundationOrder: fullStream([1, 0, 0, 0]) })), false);
});

/* ---------- the live HUD hints (objViolated / objSecured) ---------- */
// A mid-game stream: every suit has taken K down to `low[s]` from the King end, `hi[s]` up from the
// Ace end, and the deal is NOT won. Returns the telemetry plus the live up/down foundation ranks the
// board would show (up = highest rank home, 0 = empty; down = lowest rank home, 14 = empty).
const midGame = (low, hi = [0, 0, 0, 0]) => {
  const fo = [];
  let i = 0;
  for (let s = 0; s < 4; s++) for (let r = 1; r <= hi[s]; r++) fo.push(f(s, r, 'up', ++i));
  for (let s = 0; s < 4; s++) for (let r = 13; r >= low[s]; r--) fo.push(f(s, r, 'down', ++i));
  return { t: base({ won: false, foundationOrder: fo }), up: hi.slice(), down: low.map(r => (r > 13 ? 14 : r)) };
};
const secured = (obj, g) => objSecured(obj, g.up, g.down, g.t);

// The bug this pins: Aug 29's Silver is end-bias{down, 9}. A player holding 4-K in all four down
// foundations (10 from the King end) had already banked it, but the 🥈 chip stayed `·` to the last
// move because end-bias fell through objSecured's default. The count from an end never shrinks, so
// it IS securable the moment every suit reaches `min`.
test('end-bias is secured as soon as every suit holds `min` from the named end', () => {
  const obj = { id: 'end-bias', param: { end: 'down', min: 9 } };
  assert.equal(secured(obj, midGame([4, 4, 4, 4])), true);    // 10 down per suit — Aug 29's case
  assert.equal(secured(obj, midGame([5, 5, 5, 5])), true);    // exactly 9 down per suit
  assert.equal(secured(obj, midGame([6, 6, 6, 6])), false);   // 8 down — one suit short of the bar
  assert.equal(secured(obj, midGame([4, 4, 4, 6])), false);   // three suits there, the fourth isn't
  assert.equal(secured(obj, midGame([14, 14, 14, 14])), false);   // untouched board
  // ...and the Ace-end variant reads the other pile.
  const upObj = { id: 'end-bias', param: { end: 'up', min: 9 } };
  assert.equal(secured(upObj, midGame([14, 14, 14, 14], [9, 9, 9, 9])), true);
  assert.equal(secured(upObj, midGame([14, 14, 14, 14], [9, 8, 9, 9])), false);
});

test('a secured end-bias is one the win-time checker really does award', () => {
  const obj = { id: 'end-bias', param: { end: 'down', min: 9 } };
  assert.equal(secured(obj, midGame([4, 4, 4, 4])), true);
  // Finish that same line — the rest of every suit comes up — and the authoritative checker agrees.
  assert.equal(ev('end-bias', obj.param, base({ foundationOrder: fullStream([3, 3, 3, 3]) })), true);
});

test('end-bias goes ✗ once the other end has taken too much, and is never both ✗ and ✓', () => {
  const obj = { id: 'end-bias', param: { end: 'down', min: 9 } };
  // min 9 from the King end caps the Ace end at 4; a fifth card up makes the tier impossible.
  const blown = midGame([14, 14, 14, 14], [5, 0, 0, 0]);
  assert.equal(objViolated(obj, blown.t), true);
  assert.equal(secured(obj, blown), false);
  const fine = midGame([14, 14, 14, 14], [4, 4, 4, 4]);
  assert.equal(objViolated(obj, fine.t), false);
  assert.equal(secured(obj, fine), false);   // still live: nothing from the King end yet
});

test('split-at stays unsecured mid-game — a later send can still break an exact split', () => {
  // The neighbouring family end-bias is now secured early; split-at must NOT be, since its check is
  // an equality the player can still overshoot.
  const g = midGame([8, 8, 8, 8], [7, 7, 7, 7]);   // every suit already sitting on the R = 7 split
  assert.equal(objViolated({ id: 'split-at', param: { R: 7 } }, g.t), false);
  assert.equal(secured({ id: 'split-at', param: { R: 7 } }, g), false);
});

test('ends-first: the required cards come home first, and nothing else may jump the queue', () => {
  const p = { up: 2, down: 13 };
  const prefix = [];
  let i = 0;
  for (let s = 0; s < 4; s++) prefix.push(f(s, 1, 'up', ++i));
  for (let s = 0; s < 4; s++) prefix.push(f(s, 2, 'up', ++i));
  for (let s = 0; s < 4; s++) prefix.push(f(s, 13, 'down', ++i));
  assert.equal(ev('ends-first', p, base({ foundationOrder: [...prefix, f(0, 3, 'up', 99)] })), true);
  // a 3 before the prefix is complete fails
  const jumped = [...prefix.slice(0, 7), f(0, 3, 'up', 8), ...prefix.slice(7)];
  assert.equal(ev('ends-first', p, base({ foundationOrder: jumped })), false);
  // Aces-only is the same family with no King-end requirement
  assert.equal(ev('ends-first', { up: 1, down: 14 },
    base({ foundationOrder: [f(0, 1, 'up', 1), f(1, 1, 'up', 2), f(2, 1, 'up', 3), f(3, 1, 'up', 4), f(0, 2, 'up', 5)] })), true);
  assert.equal(ev('ends-first', { up: 1, down: 14 },
    base({ foundationOrder: [f(0, 1, 'up', 1), f(0, 2, 'up', 2), f(1, 1, 'up', 3)] })), false);
});

test('before-ace: every card of that rank is down before ANY Ace goes up', () => {
  const good = base({ foundationOrder: [f(0, 12, 'down', 1), f(1, 12, 'down', 2), f(2, 12, 'down', 3), f(3, 12, 'down', 4), f(0, 1, 'up', 5)] });
  const bad = base({ foundationOrder: [f(0, 12, 'down', 1), f(0, 1, 'up', 2)] });
  assert.equal(ev('before-ace', { rank: 12 }, good), true);
  assert.equal(ev('before-ace', { rank: 12 }, bad), false);
});

test('suit-top-first is the PER-SUIT version: this suit\'s card down before this suit\'s Ace', () => {
  const good = base({ foundationOrder: [f(0, 13, 'down', 1), f(0, 1, 'up', 2), f(1, 13, 'down', 3), f(1, 1, 'up', 4)] });
  const bad = base({ foundationOrder: [f(0, 13, 'down', 1), f(1, 1, 'up', 2)] });   // hearts' Ace, hearts' King still out
  assert.equal(ev('suit-top-first', { rank: 13 }, good), true);
  assert.equal(ev('suit-top-first', { rank: 13 }, bad), false);
  // the same stream fails a deeper requirement (Jack down, not just King)
  assert.equal(ev('suit-top-first', { rank: 11 }, good), false);
});

test('suit-sprint: finish one suit before a second is started', () => {
  const seq = [];
  for (let r = 1; r <= 13; r++) seq.push(f(0, r, 'up', r));   // whole spade suit first
  seq.push(f(1, 1, 'up', 14));                                // then start hearts
  assert.equal(ev('suit-sprint', {}, base({ foundationOrder: seq })), true);
  assert.equal(ev('suit-sprint', {}, base({ foundationOrder: [f(0, 1, 'up', 1), f(1, 1, 'up', 2)] })), false);
});

test('rank-rush: all four of the rank home, from either end, inside the deadline', () => {
  const stream = [f(0, 13, 'down', 3), f(1, 13, 'down', 7), f(2, 13, 'down', 11), f(3, 13, 'down', 16), f(0, 12, 'down', 20)];
  assert.equal(ev('rank-rush', { rank: 13, N: 16 }, base({ foundationOrder: stream })), true);
  assert.equal(ev('rank-rush', { rank: 13, N: 15 }, base({ foundationOrder: stream })), false);
  // only three of the four arrive -> never satisfied
  assert.equal(ev('rank-rush', { rank: 13, N: 40 }, base({ foundationOrder: stream.slice(0, 3) })), false);
  // either end counts: an Ace-end rush
  const aces = [f(0, 1, 'up', 2), f(1, 1, 'up', 4), f(2, 1, 'up', 5), f(3, 1, 'up', 9)];
  assert.equal(ev('rank-rush', { rank: 1, N: 9 }, base({ foundationOrder: aces })), true);
});

test('suit-balance: no suit may run more than N ahead at any point', () => {
  const even = [];
  let i = 0;
  for (let r = 1; r <= 4; r++) for (let s = 0; s < 4; s++) even.push(f(s, r, 'up', ++i));   // round-robin
  assert.equal(ev('suit-balance', { N: 1 }, base({ foundationOrder: even })), true);
  const greedy = [];
  i = 0;
  for (let r = 1; r <= 6; r++) greedy.push(f(0, r, 'up', ++i));                             // one suit races ahead
  assert.equal(ev('suit-balance', { N: 5 }, base({ foundationOrder: greedy })), false);
  assert.equal(ev('suit-balance', { N: 6 }, base({ foundationOrder: greedy })), true);
});

test('the universal families read the plain counters', () => {
  assert.equal(ev('moves', { N: 120 }, base({ moves: 120 })), true);
  assert.equal(ev('moves', { N: 120 }, base({ moves: 121 })), false);
  assert.equal(ev('no-undo', {}, base({ undos: 0 })), true);
  assert.equal(ev('no-undo', {}, base({ undos: 1 })), false);
});

test('nothing passes without the win', () => {
  const lost = over => base({ won: false, ...over });
  assert.equal(ev('cells-le', { N: 3 }, lost({ cellUses: 0 })), false);
  assert.equal(ev('split-at', { R: 7 }, lost({ foundationOrder: fullStream() })), false);
  assert.equal(ev('rank-rush', { rank: 13, N: 40 }, lost({ foundationOrder: [f(0, 13, 'down', 1), f(1, 13, 'down', 2), f(2, 13, 'down', 3), f(3, 13, 'down', 4)] })), false);
  assert.equal(ev('suit-sprint', {}, lost({ foundationOrder: [] })), false);
});

test('a lost game earns no tier', () => {
  const challenge = dailyChallenge(0, POOL);
  const r = evaluateChallenge(challenge, base({ won: false }));
  assert.deepEqual(r, { bronze: false, silver: false, gold: false, flawless: false, onTime: false });
});

/* ---------- per-attempt grading + OR-accumulation across attempts ---------- */
test('mergeTiers OR-accumulates tiers and keeps best moves/time across attempts', () => {
  // Silver earned on one attempt, Gold on a different one -> the day holds both.
  const silverAttempt = { bronze: true, silver: true, gold: false, moves: 95, elapsed: 200 };
  const goldAttempt   = { bronze: true, silver: false, gold: true, moves: 110, elapsed: 150 };
  const day = mergeTiers(mergeTiers(undefined, silverAttempt), goldAttempt);
  assert.deepEqual(day, { bronze: true, silver: true, gold: true, flawless: false, onTime: false, moves: 95, elapsed: 150, runs: [] });
});

test('end-to-end: mergeTiers folds real evaluateChallenge results (OR tiers, best moves/time)', () => {
  const challenge = dailyChallenge(2, POOL);   // silver moves{N:96}, gold cells-le{N:0}
  // A: wins silver (few moves, no-cells fails via a cell use), slower.
  const telemetryA = base({ won: true, moves: 90, elapsed: 240, cellUses: 1 });
  // B: wins gold (no cells), more moves, faster.
  const telemetryB = base({ won: true, moves: 96, elapsed: 150, cellUses: 0 });
  const rA = evaluateChallenge(challenge, telemetryA);
  const rB = evaluateChallenge(challenge, telemetryB);
  assert.equal(rA.silver, true);  assert.equal(rA.gold, false);
  assert.equal(rB.silver, true);  assert.equal(rB.gold, true);
  const day = mergeTiers(mergeTiers(undefined, rA), rB);
  // OR of tiers, and best (min) of each metric across the two attempts.
  assert.deepEqual(day, { bronze: true, silver: true, gold: true, flawless: true, onTime: false, moves: 90, elapsed: 150,
    runs: [{ moves: 90, elapsed: 240 }, { moves: 96, elapsed: 150 }] });   // both clears logged, in play order
  // A subsequent lost attempt must not clobber the recorded best moves/time.
  const held = mergeTiers(day, evaluateChallenge(challenge, base({ won: false, moves: 5, elapsed: 5 })));
  assert.deepEqual(held, { bronze: true, silver: true, gold: true, flawless: true, onTime: false, moves: 90, elapsed: 150,
    runs: [{ moves: 90, elapsed: 240 }, { moves: 96, elapsed: 150 }] });   // ...and a loss logs no run
});

/* ---------- the per-day run log (every clear, not just the best one) ---------- */
test('every win logs one run; the day keeps them all, oldest first', () => {
  const ch = dailyChallenge(2, POOL);   // silver moves{N:96}, gold cells-le{N:0}
  const win = (moves, elapsed) => evaluateChallenge(ch, base({ won: true, moves, elapsed }));
  assert.deepEqual(win(118, 400).runs, [{ moves: 118, elapsed: 400 }]);
  const day = [win(118, 400), win(102, 330), win(96, 290)].reduce((acc, r) => mergeTiers(acc, r), undefined);
  assert.deepEqual(day.runs, [{ moves: 118, elapsed: 400 }, { moves: 102, elapsed: 330 }, { moves: 96, elapsed: 290 }]);
  // The best-of fields still summarise the log (and are what the day card leads with).
  assert.equal(day.moves, 96);
  assert.equal(day.elapsed, 290);
  assert.equal(day.runs.length, 3);
  // A loss adds nothing to the log.
  assert.deepEqual(mergeTiers(day, evaluateChallenge(ch, base({ won: false, moves: 7, elapsed: 7 }))).runs, day.runs);
});

test('the run log survives a re-imported backup without inflating (dedupe by moves+elapsed)', () => {
  const day = mergeRuns([], [{ moves: 118, elapsed: 400 }, { moves: 96, elapsed: 290 }]);
  assert.deepEqual(mergeRuns(day, day), day, 'importing the same records twice doubled the log');
  // ...but a genuinely different clear is still appended.
  assert.deepEqual(mergeRuns(day, [{ moves: 96, elapsed: 288 }]),
    [{ moves: 118, elapsed: 400 }, { moves: 96, elapsed: 290 }, { moves: 96, elapsed: 288 }]);
});

test(`the run log keeps the most recent ${RUN_LOG_MAX} clears and drops nothing else`, () => {
  const many = Array.from({ length: RUN_LOG_MAX + 5 }, (_, i) => ({ moves: 100 + i, elapsed: 200 + i }));
  const log = many.reduce((acc, r) => mergeRuns(acc, [r]), []);
  assert.equal(log.length, RUN_LOG_MAX);
  assert.deepEqual(log[0], many[5]);                       // the five oldest were trimmed...
  assert.deepEqual(log[log.length - 1], many[many.length - 1]);
  // ...and the day's BEST is unaffected by the trim, because mergeTiers keeps it separately.
  const day = many.reduce((acc, r) => mergeTiers(acc, { bronze: true, moves: r.moves, elapsed: r.elapsed, runs: [r] }), undefined);
  assert.equal(day.moves, 100);
  assert.equal(day.elapsed, 200);
  assert.equal(day.runs.length, RUN_LOG_MAX);
});

test('mergeRuns ignores junk rows rather than logging holes', () => {
  assert.deepEqual(mergeRuns([null, { moves: null, elapsed: 5 }], [{ moves: 90, elapsed: 100 }]),
    [{ moves: 90, elapsed: 100 }]);
  assert.deepEqual(mergeRuns(undefined, undefined), []);
});

test('mergeTiers never loses a tier already earned on a later worse attempt', () => {
  const prev = { bronze: true, silver: true, gold: true, moves: 80, elapsed: 100 };
  const worse = { bronze: true, silver: false, gold: false, moves: 200, elapsed: 300 };
  const merged = mergeTiers(prev, worse);
  assert.deepEqual(merged, { bronze: true, silver: true, gold: true, flawless: false, onTime: false, moves: 80, elapsed: 100, runs: [] });
});

/* ---------- flawless (all three tiers in one attempt) ---------- */
test('evaluateChallenge marks flawless only when a single attempt earns all three', () => {
  const ch = dailyChallenge(2, POOL);   // silver moves{N:96}, gold cells-le{N:0}
  const all = evaluateChallenge(ch, base({ won: true, moves: 90, cellUses: 0 }));   // silver + gold in one run
  assert.equal(all.flawless, true);
  const partial = evaluateChallenge(ch, base({ won: true, moves: 90, cellUses: 1 }));   // gold fails (used a cell)
  assert.equal(partial.flawless, false);
});

test('flawless is NOT earned by banking silver and gold across two attempts', () => {
  const ch = dailyChallenge(2, POOL);
  const silverOnly = evaluateChallenge(ch, base({ won: true, moves: 90, cellUses: 1 }));   // silver, not gold
  const goldOnly   = evaluateChallenge(ch, base({ won: true, moves: 200, cellUses: 0 }));  // gold, not silver
  const day = mergeTiers(mergeTiers(undefined, silverOnly), goldOnly);
  assert.equal(day.silver, true); assert.equal(day.gold, true);   // both banked
  assert.equal(day.flawless, false);                              // but never in one run
});

test('streaks: a flawless run extends the flawless streak', () => {
  const rec = {
    3: { bronze: true, silver: true, gold: true, flawless: true },
    4: { bronze: true, silver: true, gold: true, flawless: false },   // three-starred across attempts
    5: { bronze: true, silver: true, gold: true, flawless: true },
    6: { bronze: true, silver: true, gold: true, flawless: true },    // today
  };
  const s = streaks(rec, 6);
  assert.equal(s.flawless.current, 2);   // days 5-6 (gap: day 4 not flawless)
  assert.equal(s.flawless.best, 2);
  assert.equal(s.gold.current, 4);       // gold still counts all four
});

/* ---------- streaks ---------- */
test('streaks: current run ending at today, plus longest ever, per tier', () => {
  const rec = {
    3: { bronze: true, silver: true, gold: false },
    4: { bronze: true, silver: false, gold: false },
    5: { bronze: true, silver: true, gold: true },
    6: { bronze: true, silver: true, gold: false },
    // gap at 7
    9: { bronze: true, silver: false, gold: false },   // today
  };
  const s = streaks(rec, 9);
  assert.equal(s.play.current, 1);    // only day 9 ends the run (gap at 7,8)
  assert.equal(s.play.best, 4);       // days 3-6
  assert.equal(s.play.total, 5);      // total (lifetime) days with bronze: 3,4,5,6,9
  assert.equal(s.silver.total, 3);    // 3,5,6
  assert.equal(s.gold.total, 1);      // 5 only — non-consecutive totals differ from streaks
  assert.equal(s.silver.best, 2);     // days 5-6 (and 3 alone)
  const s6 = streaks(rec, 6);
  assert.equal(s6.play.current, 4);   // 3-6 all bronze, ends at today=6
  assert.equal(s6.gold.current, 0);   // day 6 gold false
});

test('streaks count a day completed yesterday (today not yet played)', () => {
  const rec = { 8: { bronze: true, silver: false, gold: false } };
  assert.equal(streaks(rec, 9).play.current, 1);   // yesterday done, today pending -> streak alive
});

/* ---------- pre-epoch playtest sandbox (negative day indices) ---------- */

/* ---------- DRIFT GUARD: the web app inlines this logic; assert it hasn't diverged ---------- */
// The daily logic is inlined into index.html (file:// can't import modules). Pin distinctive bodies
// so an edit to one copy without the other trips CI — mirrors the engine/rules drift guards.
test('daily logic is inlined verbatim in index.html (no drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const canon = [
    'const EPOCH_DAYS=daysFromCivil(2026,8,1);',
    'const upDown=t=>{const u=[0,0,0,0],d=[0,0,0,0];for(const e of t.foundationOrder){if(e.end==="up")u[e.suit]++;else d[e.suit]++;}return{u,d};};',
    'const endsFirst=(t,p)=>{const u=[0,0,0,0],d=[14,14,14,14];const met=()=>u.every(x=>x>=p.up)&&d.every(x=>x<=p.down);',
    'const beforeAce=(t,p)=>{let n=0;for(const e of t.foundationOrder){if(e.rank===p.rank&&e.end==="down")n++;else if(e.rank===1&&e.end==="up"&&n<4)return false;}return t.won;};',
    'const suitTopFirst=(t,p)=>{const down=[false,false,false,false];for(const e of t.foundationOrder){if(e.rank===p.rank&&e.end==="down")down[e.suit]=true;else if(e.rank===1&&e.end==="up"&&!down[e.suit])return false;}return t.won;};',
    'const rankRush=(t,p)=>{const seen=[false,false,false,false];let n=0;for(const e of t.foundationOrder){if(e.rank!==p.rank||seen[e.suit])continue;seen[e.suit]=true;if(++n===4)return t.won&&e.moveIdx<=p.N;}return false;};',
    'const suitBalance=(t,p)=>t.won&&foldHome(t,(_e,home)=>Math.max(...home)-Math.min(...home)<=p.N);',
    "'cells-le':{grade:p=>p.N===0?'gold':'silver',",
    "'split-at':{grade:'gold',label:p=>`Split every suit exactly at the ${rankName(p.R)} — A-${rankShort(p.R)} up, ${rankShort(p.R+1)}-K down`,",
    "check:(t,p)=>{if(!t.won)return false;const{u,d}=upDown(t);return (p.end==='up'?u:d).every(x=>x>=p.min);}},",
    'function gradeOf(id,param){const g=OBJECTIVES[id].grade;return typeof g==="function"?g(param):g;}'.replace(/"/g, "'"),
    'return{dayIndex,seed:rec.seed,par:rec.par,silver:makeObjective(rec.silver),gold:makeObjective(rec.gold)};',
    'const result={bronze,silver,gold,flawless:!!(bronze&&silver&&gold),onTime:bronze&&!!onTime};',
    'flawless:!!p.flawless||!!attempt.flawless,onTime:!!p.onTime||!!attempt.onTime,',
    'if(winDay===challengeDay) return true;',
    'return attemptStartDay===challengeDay&&winDay===challengeDay+1;',
    'let i=played(todayIndex)?todayIndex:(played(todayIndex-1)?todayIndex-1:null); let cur=0;',
  ];
  for (const c of canon) assert.ok(html.includes(norm(c)), `index.html daily logic drifted / missing: ${c.slice(0, 55)}...`);
});

// The canon above pins the ⏰ DECISION (isOnTime's body, the result/merge literals) but not the
// WIRING that feeds it. Without this test the whole web same-day feature can be deleted — stop
// recording challengeStartDay, or pass a constant `false` into evaluateChallenge — and every test
// stays green while ⏰ is never awarded again (no badge, no streak, no calendar pip). Each snippet
// below is one link in that chain: start-day stamped on play, preserved across save/restore and
// re-stamped on restart, read at win time, and forwarded as evaluateChallenge's third argument.
test('web ⏰ same-day wiring is intact (start day recorded, carried, and fed to evaluateChallenge)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const wiring = [
    // playChallenge: a fresh attempt stamps TODAY as its start day (not the challenge's day).
    'challengeDay=day; challengeStartDay=todayIndex(); saveGame();',
    // in-progress save/restore: the grace survives a reload; a save written before ⏰ shipped has NO
    // start day and must stay null (never `?? challengeDay`), so a resumed attempt can never be
    // credited for a date it cannot prove. The null here is the guard, not an oversight.
    'challengeDay, challengeStartDay, telem',
    'challengeStartDay = (typeof g.challengeStartDay==="number") ? g.challengeStartDay : null;',
    // restartDeal: a retry is a NEW attempt — its eligibility is judged from today, unconditionally
    // (iOS Game.restartDeal does the same; a null-preserving branch here was a parity divergence).
    'if(day!=null){ challengeDay=day; challengeStartDay=todayIndex(); saveGame(); render(); }',
    // recordChallengeResult: compute onTime from the recorded start day...
    'const onTime=isOnTime({challengeDay,winDay:todayIndex(),attemptStartDay:challengeStartDay});',
    // ...and actually forward it as evaluateChallenge's third argument (the tail of that call).
    'maxRunMoved:telem.maxRunMoved},onTime);',
    // the award surfaces: win-overlay badge + same-day streak, and the calendar pip. The overlay
    // pin reaches the STREAK NUMBER's source, not just the flag: a bare 'w.daily.onTime ?' stays
    // green while the number is frozen at a constant (mutation-verified — that mutant survived).
    'w.daily.onTime ?',
    '${streaks(dailyStore.days, todayIndex()).onTime.current}-day same-day streak.',
    "rec&&rec.onTime?'<i class=\"dot-ontime\"></i>':''",
    // the day card's ⏰ line, all four branches: earned, today's invitation, the LIVE next-day grace
    // (yesterday's attempt still in progress — pinned with its condition so it cannot be constant-
    // folded), and the past-day explainer. Each was deletable green before this pin.
    '`<div class="dontime earned">⏰ Cleared on the day</div>`',
    'const graceLive = challengeDay===day && challengeStartDay===day && ti===day+1;',
    '`<div class="dontime">⏰ Resume your attempt today and it still counts</div>`',
    '`<div class="dontime muted">⏰ Same-day is earned on the day itself</div>`',
    // ...and the streak that badge and the Daily strip both read: the accessor must actually run
    // tierRun over the 'onTime' flag (a zeroed stub would leave ⏰ permanently reading 0), and the
    // strip must still carry an ⏰ column.
    "flawless:tierRun('flawless'),onTime:tierRun('onTime')};",
    "['⏰','Same-day',s.onTime],",
  ];
  for (const c of wiring) assert.ok(html.includes(norm(c)), `index.html ⏰ same-day wiring drifted / missing: ${c.slice(0, 60)}...`);
  // A constant would satisfy a substring pin trivially; the value must come from isOnTime().
  assert.ok(!/const\s+onTime\s*=\s*(true|false)\b/.test(html), 'index.html: onTime is hard-coded, not computed by isOnTime()');
});

// The calendar was rebuilt for Aug+Sep 2026 under the flawless gate; a stored record from before it
// names a different challenge, so both platforms must drop a pre-v3 store rather than credit tiers
// never earned.
test('both platforms gate the daily store on version 3 (the rebuild nukes older history)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  assert.ok(html.includes(norm('if(g&&g.days&&g.version===3) return g;')), 'web daily store is not v3-gated');
  assert.ok(html.includes(norm('return {version:3, days:{}};')), 'web daily store does not reset to v3');
  const swift = norm(readFileSync(join(REPO, 'ios/Causeway/Causeway/Model/DailyStore.swift'), 'utf8'));
  assert.ok(swift.includes(norm('private let version = 3')), 'iOS daily store is not v3');
  assert.ok(swift.includes(norm('guard decoded.version == version else {')), 'iOS daily store does not drop older versions');
  // The same generation number, exposed for the stats-backup stamp. The local wipe above is only
  // half the guard: the import path is the other door into the day map, and it was wide open
  // (bug/WF-11:legacy-backup-defeats-daily-v3-wipe). These two literals must not drift apart.
  assert.ok(swift.includes(norm('static let version = 3')), 'iOS daily store no longer exposes its generation for the backup stamp');
  const backup = norm(readFileSync(join(REPO, 'ios/Causeway/Causeway/Model/StatsBackup.swift'), 'utf8'));
  assert.ok(backup.includes(norm('dailyVersion: DailyStore.version')), 'stats backups no longer stamp the daily-store generation');
  assert.ok(backup.includes(norm('poolEpoch: EPOCH_DAYS')), 'stats backups no longer stamp the calendar epoch');
  assert.ok(backup.includes(norm('dailyVersion == DailyStore.version && poolEpoch == EPOCH_DAYS')),
    'the backup importer no longer checks the pool generation of a daily map');
  // A missing stamp must read as NO. An `?? DailyStore.version`-style default anywhere here would
  // re-open the door for every pre-stamp file, which is exactly the legacy case that broke.
  assert.ok(!/dailyVersion\s*=\s*try\s*c\.decodeIfPresent\(Int\.self,\s*forKey:\s*\.dailyVersion\)\s*\?\?/.test(backup),
    'a missing pool-generation stamp is being defaulted instead of refused');
  const view = norm(readFileSync(join(REPO, 'ios/Causeway/Causeway/Views/DailyView.swift'), 'utf8'));
  assert.ok(view.includes(norm('let poolMatches = backup.dailyRecordsMatchThisPool')),
    'the import path no longer gates the daily map on the pool generation');
  assert.ok(view.includes(norm('let validDaily = !poolMatches ? [:] : backup.dailyInts')),
    'an unprovable daily map is no longer dropped at import');
  assert.ok(view.includes('of challenge history from an older'),
    'the import no longer TELLS the player its daily history was from an older calendar');
});

// ---- ⏰ same-day recognition --------------------------------------------------------------------
// Orthogonal to the tiers: it records WHEN a day was cleared, not how well. See §12 of
// docs/daily-challenges.md.

test('isOnTime: the day itself counts, a later replay does not', () => {
  assert.equal(isOnTime({ challengeDay: 40, winDay: 40, attemptStartDay: 40 }), true);
  assert.equal(isOnTime({ challengeDay: 40, winDay: 41, attemptStartDay: 41 }), false);  // replayed next day
  // An unknown start day (a pre-⏰ save restored with null) forfeits the grace rather than guessing.
  assert.equal(isOnTime({ challengeDay: 40, winDay: 41, attemptStartDay: null }), false);
  assert.equal(isOnTime({ challengeDay: 40, winDay: 40, attemptStartDay: null }), true);   // won on the day itself
  assert.equal(isOnTime({ challengeDay: 40, winDay: 55, attemptStartDay: 55 }), false);  // catch-up much later
  assert.equal(isOnTime({ challengeDay: null, winDay: 40, attemptStartDay: 40 }), false); // casual play
});

test('isOnTime: an attempt begun before midnight still counts when it lands after', () => {
  assert.equal(isOnTime({ challengeDay: 40, winDay: 41, attemptStartDay: 40 }), true);
  // ...but a game merely RESUMED days later does not get the grace.
  assert.equal(isOnTime({ challengeDay: 40, winDay: 43, attemptStartDay: 40 }), false);
});

test('evaluateChallenge records onTime only on a win, and mergeTiers makes it sticky', () => {
  const ch = { silver: { id: 'no-undo', param: {} }, gold: { id: 'cells-le', param: { N: 0 } } };
  const lost = evaluateChallenge(ch, { won: false, moves: 40, undos: 0, cellUses: 0, foundationOrder: [] }, true);
  assert.equal(lost.onTime, false, 'a loss on the day earns nothing');

  const won = evaluateChallenge(ch, { won: true, moves: 90, elapsed: 300, undos: 0, cellUses: 0, foundationOrder: [] }, true);
  assert.equal(won.onTime, true);
  assert.equal(won.bronze && won.silver && won.gold && won.flawless, true);

  // A later catch-up attempt on another day never clears the badge, and never sets it either.
  const later = evaluateChallenge(ch, { won: true, moves: 80, elapsed: 200, undos: 0, cellUses: 0, foundationOrder: [] }, false);
  assert.equal(mergeTiers(won, later).onTime, true);
  assert.equal(mergeTiers(undefined, later).onTime, false);
});

test('streaks: the same-day run is strict — a catch-up day never repairs it', () => {
  // Days 3-5 cleared on their own dates; day 6 cleared late; day 7 (today) on time.
  const records = {
    3: { bronze: true, onTime: true },
    4: { bronze: true, onTime: true },
    5: { bronze: true, onTime: true },
    6: { bronze: true, onTime: false },
    7: { bronze: true, onTime: true },
  };
  const s = streaks(records, 7);
  assert.equal(s.play.current, 5, 'the play streak counts the catch-up day');
  assert.equal(s.onTime.current, 1, 'the same-day streak restarted at today');
  assert.equal(s.onTime.best, 3);
  assert.equal(s.onTime.total, 4);
});
