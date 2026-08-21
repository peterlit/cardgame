// Tests for the shared Daily-Challenges logic (tests/daily.mjs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  dayIndexFor, dailyChallenge, evaluate, evaluateChallenge, mergeTiers, streaks, OBJECTIVES,
} from './daily.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const norm = s => s.replace(/\s+/g, ' ').trim();

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

/* ---------- GOLDEN MASTER: frozen (dayIndex, fixed-pool) -> (silverId, goldId) ---------- */
// Pins the objective-selection outcome for a FIXED inline pool. It depends on the ordering/contents
// of SILVER_UNIVERSAL/SILVER_CERTIFIED/GOLD *and* the rng seed formula in daily.mjs. If anyone
// reorders or mid-array-inserts into those FROZEN arrays, or changes the seed formula, a pinned
// day's pick shifts and this test fails — catching a silent retroactive reshuffle of history.
const FROZEN_POOL = {
  version: 1, minSeed: 10000, seeds: [
    { seed: 10001, par: 80,  supports: ['no-cells', 'aces-first', 'kings-first', 'cells-le-2'] },
    { seed: 10002, par: 90,  supports: ['suits-top-down', 'down-openers-20'] },
    { seed: 10003, par: 100, supports: ['no-cells', 'suit-sprint', 'jacks-down-first', 'cells-le-1', 'down-openers-20'] },
  ],
};
const GOLDEN_PICKS = [
  { day: 0, seed: 10001, silverId: 'moves',           goldId: 'no-cells' },
  { day: 1, seed: 10002, silverId: 'no-undo',         goldId: 'suits-top-down' },
  { day: 2, seed: 10003, silverId: 'down-openers-20', goldId: 'no-cells' },
];

test('golden master: frozen days map to frozen (seed, silverId, goldId) picks', () => {
  for (const g of GOLDEN_PICKS) {
    const c = dailyChallenge(g.day, FROZEN_POOL);
    assert.equal(c.seed, g.seed, `day ${g.day} seed`);
    assert.equal(c.silver.id, g.silverId, `day ${g.day} silver`);
    assert.equal(c.gold.id, g.goldId, `day ${g.day} gold`);
  }
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
  assert.deepEqual(r, { bronze: false, silver: false, gold: false, flawless: false });
});

/* ---------- per-attempt grading + OR-accumulation across attempts ---------- */
test('mergeTiers OR-accumulates tiers and keeps best moves/time across attempts', () => {
  // Silver earned on one attempt, Gold on a different one -> the day holds both.
  const silverAttempt = { bronze: true, silver: true, gold: false, moves: 95, elapsed: 200 };
  const goldAttempt   = { bronze: true, silver: false, gold: true, moves: 110, elapsed: 150 };
  const day = mergeTiers(mergeTiers(undefined, silverAttempt), goldAttempt);
  assert.deepEqual(day, { bronze: true, silver: true, gold: true, flawless: false, moves: 95, elapsed: 150 });
});

test('end-to-end: mergeTiers folds real evaluateChallenge results (OR tiers, best moves/time)', () => {
  const challenge = dailyChallenge(0, POOL);   // silver 'moves' (N=96), gold 'no-cells'
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
  assert.deepEqual(day, { bronze: true, silver: true, gold: true, flawless: true, moves: 90, elapsed: 150 });
  // A subsequent lost attempt must not clobber the recorded best moves/time.
  const held = mergeTiers(day, evaluateChallenge(challenge, base({ won: false, moves: 5, elapsed: 5 })));
  assert.deepEqual(held, { bronze: true, silver: true, gold: true, flawless: true, moves: 90, elapsed: 150 });
});

test('mergeTiers never loses a tier already earned on a later worse attempt', () => {
  const prev = { bronze: true, silver: true, gold: true, moves: 80, elapsed: 100 };
  const worse = { bronze: true, silver: false, gold: false, moves: 200, elapsed: 300 };
  const merged = mergeTiers(prev, worse);
  assert.deepEqual(merged, { bronze: true, silver: true, gold: true, flawless: false, moves: 80, elapsed: 100 });
});

/* ---------- flawless (all three tiers in one attempt) ---------- */
test('evaluateChallenge marks flawless only when a single attempt earns all three', () => {
  const ch = dailyChallenge(0, POOL);   // silver 'moves' N=96, gold 'no-cells'
  const all = evaluateChallenge(ch, base({ won: true, moves: 90, cellUses: 0 }));   // silver + gold in one run
  assert.equal(all.flawless, true);
  const partial = evaluateChallenge(ch, base({ won: true, moves: 90, cellUses: 1 }));   // gold fails (used a cell)
  assert.equal(partial.flawless, false);
});

test('flawless is NOT earned by banking silver and gold across two attempts', () => {
  const ch = dailyChallenge(0, POOL);
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
test('negative day indices resolve to preSeeds, and never disturb days >= 0', () => {
  const seedsOnly = { seeds: [
    { seed: 10001, par: 100, supports: ['no-cells', 'cells-le-1'] },
    { seed: 10002, par: 100, supports: ['kings-first'] },
  ] };
  const withPre = { ...seedsOnly, preSeeds: [
    { seed: 555001, par: 90, supports: ['aces-first', 'cells-le-2'] },
    { seed: 555002, par: 90, supports: ['suits-top-down'] },
  ] };
  // days >= 0 are byte-identical whether or not a sandbox exists — the whole safety claim
  for (let d = 0; d < seedsOnly.seeds.length; d++) {
    assert.deepEqual(dailyChallenge(d, withPre), dailyChallenge(d, seedsOnly));
  }
  // preSeeds[i] backs day -(i+1)
  assert.equal(dailyChallenge(-1, withPre).seed, 555001);
  assert.equal(dailyChallenge(-2, withPre).seed, 555002);
  // out of sandbox range, and no sandbox at all, both yield null
  assert.equal(dailyChallenge(-3, withPre), null);
  assert.equal(dailyChallenge(-1, seedsOnly), null);
  // a sandbox day is a real challenge: objectives drawn from that seed's supports
  const c = dailyChallenge(-1, withPre);
  assert.ok(['aces-first', 'cells-le-2'].includes(c.gold.id) || c.gold.id === 'aces-first');
  assert.ok(c.silver.id && c.gold.id);
});

/* ---------- DRIFT GUARD: the web app inlines this logic; assert it hasn't diverged ---------- */
// The daily logic is inlined into index.html (file:// can't import modules). Pin distinctive bodies
// so an edit to one copy without the other trips CI — mirrors the engine/rules drift guards.
test('daily logic is inlined verbatim in index.html (no drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const canon = [
    'const acesFirst=t=>{let a=0;for(const e of t.foundationOrder){if(a>=4)break;if(e.rank===1)a++;else return false;}return t.won&&a===4;};',
    'const kingsFirst=t=>{let k=0;for(const e of t.foundationOrder){if(e.rank===13&&e.end==="down")k++;else if(e.rank===1&&e.end==="up"&&k<4)return false;}return t.won;};',
    'const jacksDownFirst=t=>{let j=0;for(const e of t.foundationOrder){if(e.rank===11&&e.end==="down")j++;else if(e.rank===1&&e.end==="up"&&j<4)return false;}return t.won;};',
    'const suitsTopDown=t=>{const kd=[false,false,false,false];for(const e of t.foundationOrder){if(e.rank===13&&e.end==="down")kd[e.suit]=true;else if(e.rank===1&&e.end==="up"&&!kd[e.suit])return false;}return t.won;};',
    'const suitSprint=t=>{const home=[0,0,0,0],started=[false,false,false,false];for(const e of t.foundationOrder){const S=e.suit;if(!started[S]){for(let T=0;T<4;T++)if(T!==S&&started[T]&&home[T]<13)return false;started[S]=true;}home[S]++;}return t.won;};',
    'const downOpeners20=t=>{let k=0,opened=null;for(const e of t.foundationOrder){if(e.rank===13&&e.end==="down"){k++;if(k===4){opened=e.moveIdx;break;}}}return t.won&&opened!=null&&opened<=20;};',
    'const rng=mulberry32((0x9e3779b9^(dayIndex+1))>>>0);',
    'const silverPool=SILVER_UNIVERSAL.concat(SILVER_CERTIFIED.filter(id=>rec.supports.includes(id)));',
    'const goldPool=GOLD.filter(id=>rec.supports.includes(id));',
    'const silverId=silverPool[Math.floor(rng()*silverPool.length)];',
    'const EPOCH_DAYS=daysFromCivil(2026,8,12);',
    'const dayIndexFor=(y,m,d)=>daysFromCivil(y,m,d)-EPOCH_DAYS;',
    'const result={bronze,silver,gold,flawless:!!(bronze&&silver&&gold)};',
    'moves:Math.min(p.moves??Infinity,attempt.moves??Infinity)',
    'flawless:!!p.flawless||!!attempt.flawless',
    'while(i!=null&&has(i,tier)){cur++;i--;}',
    "return{play:tierRun('bronze'),silver:tierRun('silver'),gold:tierRun('gold'),flawless:tierRun('flawless')};",
  ];
  for (const c of canon) assert.ok(html.includes(norm(c)), `index.html daily logic drifted / missing: ${c.slice(0, 55)}...`);
});
