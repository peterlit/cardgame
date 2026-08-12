// Tests for the shared Daily-Challenges logic (tests/daily.mjs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  dayIndexFor, dailyChallenge, evaluate, evaluateChallenge, streaks, OBJECTIVES,
} from './daily.mjs';

// a tiny fake pool: two seeds with different support sets
const POOL = {
  version: 1, minSeed: 10000, seeds: [
    { seed: 10001, par: 80, supports: ['no-cells', 'aces-first', 'kings-first', 'cells-le-2'] },
    { seed: 10002, par: 90, supports: ['suits-top-down', 'down-openers-20'] },
  ],
};

const f = (suit, rank, end, moveIdx) => ({ suit, rank, end, moveIdx });

/* ---------- calendar ---------- */
test('day index: launch epoch is 0 and days advance by one', () => {
  assert.equal(dayIndexFor(2026, 8, 12), 0);
  assert.equal(dayIndexFor(2026, 8, 13), 1);
  assert.equal(dayIndexFor(2026, 9, 11), 30);
  assert.equal(dayIndexFor(2026, 8, 11), -1);   // before launch
});

/* ---------- generator: deterministic, stable, in-range ---------- */
test('dailyChallenge is deterministic and maps day D to pool.seeds[D]', () => {
  const a = dailyChallenge(0, POOL), b = dailyChallenge(0, POOL);
  assert.deepEqual(a, b);
  assert.equal(a.seed, 10001);
  assert.equal(dailyChallenge(1, POOL).seed, 10002);
  assert.equal(dailyChallenge(2, POOL), null);    // out of range (not available yet)
});

test('generator only offers objectives the seed is certified to support', () => {
  const c0 = dailyChallenge(0, POOL);
  assert.ok(['no-cells', 'aces-first', 'kings-first'].includes(c0.gold.id));   // gold in supports
  const c1 = dailyChallenge(1, POOL);
  assert.equal(c1.gold.id, 'suits-top-down');    // the only gold this seed supports
});

test('appending to the pool never shifts a past day (frozen history)', () => {
  const before = dailyChallenge(0, POOL);
  const grown = { ...POOL, seeds: [...POOL.seeds, { seed: 10099, par: 70, supports: ['no-cells'] }] };
  assert.deepEqual(dailyChallenge(0, grown), before);
});

test('the move-cap objective derives N from par', () => {
  const p = OBJECTIVES['moves'].param({ par: 100 });
  assert.equal(p.N, 120);
  assert.equal(OBJECTIVES['moves'].check({ won: true, moves: 120 }, p), true);
  assert.equal(OBJECTIVES['moves'].check({ won: true, moves: 121 }, p), false);
});

/* ---------- objective checkers vs telemetry fixtures ---------- */
const base = over => ({ won: true, moves: 50, elapsed: 60, cellUses: 0, undos: 0, usedAutoplay: false, usedAutoFinish: false, foundationOrder: [], ...over });

test('aces-first passes only when the first four foundation cards are the Aces', () => {
  const good = base({ foundationOrder: [f(0, 1, 'up', 1), f(1, 1, 'up', 2), f(2, 1, 'up', 3), f(3, 1, 'up', 4), f(0, 2, 'up', 5)] });
  const bad = base({ foundationOrder: [f(0, 1, 'up', 1), f(0, 2, 'up', 2), f(1, 1, 'up', 3)] });   // a 2 before all aces
  assert.equal(evaluate({ id: 'aces-first', param: {} }, good), true);
  assert.equal(evaluate({ id: 'aces-first', param: {} }, bad), false);
});

test('kings-first: no Ace up before all four Kings are down', () => {
  const good = base({ foundationOrder: [f(0, 13, 'down', 1), f(1, 13, 'down', 2), f(2, 13, 'down', 3), f(3, 13, 'down', 4), f(0, 1, 'up', 5)] });
  const bad = base({ foundationOrder: [f(0, 13, 'down', 1), f(0, 1, 'up', 2)] });
  assert.equal(evaluate({ id: 'kings-first', param: {} }, good), true);
  assert.equal(evaluate({ id: 'kings-first', param: {} }, bad), false);
});

test('suits-top-down: each suit\'s King down before its Ace up', () => {
  const good = base({ foundationOrder: [f(0, 13, 'down', 1), f(0, 1, 'up', 2), f(1, 13, 'down', 3), f(1, 1, 'up', 4)] });
  const bad = base({ foundationOrder: [f(0, 1, 'up', 1)] });   // ace up, king not down
  assert.equal(evaluate({ id: 'suits-top-down', param: {} }, good), true);
  assert.equal(evaluate({ id: 'suits-top-down', param: {} }, bad), false);
});

test('suit-sprint: finish one suit before a second is started', () => {
  const seq = [];
  for (let r = 1; r <= 13; r++) seq.push(f(0, r, 'up', r));   // whole spade suit first
  seq.push(f(1, 1, 'up', 14));                                // then start hearts
  const good = base({ foundationOrder: seq });
  const bad = base({ foundationOrder: [f(0, 1, 'up', 1), f(1, 1, 'up', 2)] });   // second suit before first done
  assert.equal(evaluate({ id: 'suit-sprint', param: {} }, good), true);
  assert.equal(evaluate({ id: 'suit-sprint', param: {} }, bad), false);
});

test('resource checkers: no-cells, cells-le-2, no-undo, down-openers-20', () => {
  assert.equal(evaluate({ id: 'no-cells', param: {} }, base({ cellUses: 0 })), true);
  assert.equal(evaluate({ id: 'no-cells', param: {} }, base({ cellUses: 1 })), false);
  assert.equal(evaluate({ id: 'cells-le-2', param: {} }, base({ cellUses: 2 })), true);
  assert.equal(evaluate({ id: 'cells-le-2', param: {} }, base({ cellUses: 3 })), false);
  assert.equal(evaluate({ id: 'no-undo', param: {} }, base({ undos: 0 })), true);
  assert.equal(evaluate({ id: 'no-undo', param: {} }, base({ undos: 1 })), false);
  const opened = base({ foundationOrder: [f(0, 13, 'down', 5), f(1, 13, 'down', 9), f(2, 13, 'down', 12), f(3, 13, 'down', 18)] });
  assert.equal(evaluate({ id: 'down-openers-20', param: {} }, opened), true);
  const late = base({ foundationOrder: [f(0, 13, 'down', 5), f(1, 13, 'down', 9), f(2, 13, 'down', 12), f(3, 13, 'down', 25)] });
  assert.equal(evaluate({ id: 'down-openers-20', param: {} }, late), false);
});

test('a lost game earns no tier', () => {
  const challenge = dailyChallenge(0, POOL);
  const r = evaluateChallenge(challenge, base({ won: false }));
  assert.deepEqual(r, { bronze: false, silver: false, gold: false });
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
  assert.equal(s.silver.best, 2);     // days 5-6 (and 3 alone)
  const s6 = streaks(rec, 6);
  assert.equal(s6.play.current, 4);   // 3-6 all bronze, ends at today=6
  assert.equal(s6.gold.current, 0);   // day 6 gold false
});

test('streaks count a day completed yesterday (today not yet played)', () => {
  const rec = { 8: { bronze: true, silver: false, gold: false } };
  assert.equal(streaks(rec, 9).play.current, 1);   // yesterday done, today pending -> streak alive
});
