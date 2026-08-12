// Shared Daily-Challenges logic: the deterministic date->challenge generator, the objective
// checkers (evaluated from per-attempt telemetry), and streak computation. This is the canonical,
// Node-tested source; the web app inlines an identical copy (drift-guarded) and iOS mirrors it in
// Swift, so a given date yields the same challenge and the same pass/fail on every platform.
//
// See docs/daily-challenges.md.
import { mulberry32 } from './engine.mjs';

// ---- calendar: a day index (integer days since the launch epoch) is the stable challenge key ----
// Proleptic-Gregorian days-from-civil (Howard Hinnant's algorithm).
export function daysFromCivil(y, m, d) {
  y -= m <= 2 ? 1 : 0;
  const era = Math.floor((y >= 0 ? y : y - 399) / 400);
  const yoe = y - era * 400;
  const doy = Math.floor((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1;
  const doe = yoe * 365 + Math.floor(yoe / 4) - Math.floor(yoe / 100) + doy;
  return era * 146097 + doe - 719468;
}
export const EPOCH_DAYS = daysFromCivil(2026, 8, 12);   // launch epoch = day 0
export function dayIndexFor(y, m, d) { return daysFromCivil(y, m, d) - EPOCH_DAYS; }

// ---- objective catalogue (checkers evaluate a telemetry record) ----
// telemetry = { won, moves, elapsed, cellUses, undos, usedAutoplay, usedAutoFinish,
//               foundationOrder: [{ suit, rank, end:'up'|'down', moveIdx }] }  (in play order)
//
// TRUSTED-TELEMETRY CONTRACT. The checkers below treat the telemetry as ground truth; they do NOT
// re-simulate the deal. The APP is responsible for emitting a complete, correctly-ordered
// foundationOrder (every foundation send, in play order) and honest counters (cellUses, undos, ...).
// This is a local, single-player, offline game with no server: the only "adversary" is a user
// editing their own storage, which only cheats themselves — so full re-simulation would be
// over-engineering. Checkers are kept deterministic and cheap, and are written to mirror EXACTLY
// the solver's certification gates (tools/solver/solve.mjs) so that "certified => a passing line
// exists" and "checker passes => a valid line" stay in agreement.
const acesFirst = t => { let a = 0; for (const e of t.foundationOrder) { if (a >= 4) break; if (e.rank === 1) a++; else return false; } return t.won && a === 4; };
const kingsFirst = t => { let k = 0; for (const e of t.foundationOrder) { if (e.rank === 13 && e.end === 'down') k++; else if (e.rank === 1 && e.end === 'up' && k < 4) return false; } return t.won; };
const jacksDownFirst = t => { let j = 0; for (const e of t.foundationOrder) { if (e.rank === 11 && e.end === 'down') j++; else if (e.rank === 1 && e.end === 'up' && j < 4) return false; } return t.won; };
const suitsTopDown = t => { const kd = [false, false, false, false]; for (const e of t.foundationOrder) { if (e.rank === 13 && e.end === 'down') kd[e.suit] = true; else if (e.rank === 1 && e.end === 'up' && !kd[e.suit]) return false; } return t.won; };
const suitSprint = t => { const home = [0, 0, 0, 0], started = [false, false, false, false]; for (const e of t.foundationOrder) { const S = e.suit; if (!started[S]) { for (let T = 0; T < 4; T++) if (T !== S && started[T] && home[T] < 13) return false; started[S] = true; } home[S]++; } return t.won; };
const downOpeners20 = t => { let k = 0, opened = null; for (const e of t.foundationOrder) { if (e.rank === 13 && e.end === 'down') { k++; if (k === 4) { opened = e.moveIdx; break; } } } return t.won && opened != null && opened <= 20; };

export const OBJECTIVES = {
  'moves':           { grade: 'silver', universal: true, param: rec => ({ N: Math.round(rec.par * 1.2) }), label: p => `Win in ${p.N} moves or fewer`,               check: (t, p) => t.won && t.moves <= p.N },
  'no-undo':         { grade: 'silver', universal: true, label: () => 'Win without using undo',                                                                        check: t => t.won && t.undos === 0 },
  'cells-le-1':      { grade: 'silver', certified: true, label: () => 'Win using a free cell at most once',                                                             check: t => t.won && t.cellUses <= 1 },
  'cells-le-2':      { grade: 'silver', certified: true, label: () => 'Win using free cells at most twice',                                                             check: t => t.won && t.cellUses <= 2 },
  'down-openers-20': { grade: 'silver', certified: true, label: () => 'Open all four down-foundations within your first 20 moves',                                      check: downOpeners20 },
  'no-cells':        { grade: 'gold',   certified: true, label: () => 'Win without ever using a free cell',                                                             check: t => t.won && t.cellUses === 0 },
  'aces-first':      { grade: 'gold',   certified: true, label: () => 'Send all four Aces home before any other card',                                                  check: acesFirst },
  'kings-first':     { grade: 'gold',   certified: true, label: () => 'Send all four Kings to the down-foundation before any Ace',                                      check: kingsFirst },
  'jacks-down-first':{ grade: 'gold',   certified: true, label: () => 'Get every Jack onto the down-foundation before any Ace',                                         check: jacksDownFirst },
  'suits-top-down':  { grade: 'gold',   certified: true, label: () => 'For every suit, send its King home before its Ace',                                              check: suitsTopDown },
  'suit-sprint':     { grade: 'gold',   certified: true, label: () => 'Finish one whole suit before any other suit is started',                                         check: suitSprint },
};

// FROZEN — APPEND-ONLY, NEVER REORDER. dailyChallenge() indexes these three arrays with a per-day
// RNG, so any reorder or mid-array insertion retroactively reshuffles which objective every PAST
// day picked (frozen history). New objectives may only be *appended*. The golden-master test in
// tests/daily.test.mjs pins several days and fails if this invariant is broken.
const SILVER_UNIVERSAL = ['moves', 'no-undo'];
const SILVER_CERTIFIED = ['cells-le-1', 'cells-le-2', 'down-openers-20'];
const GOLD = ['no-cells', 'aces-first', 'kings-first', 'jacks-down-first', 'suits-top-down', 'suit-sprint'];

function makeObjective(id, rec) {
  const o = OBJECTIVES[id];
  const param = o.param ? o.param(rec) : {};
  return { id, grade: o.grade, param, label: o.label(param) };
}

// Deterministic + stable: day D always maps to pool.seeds[D] (append-only pool never shifts a past
// day), and a per-day RNG picks the Silver/Gold objective from what that seed is certified to
// support. Returns null if D is out of the pool's current range (challenge not available yet).
export function dailyChallenge(dayIndex, pool) {
  if (dayIndex < 0 || dayIndex >= pool.seeds.length) return null;
  const rec = pool.seeds[dayIndex];
  // FROZEN rng seed formula — changing it retroactively reshuffles every past day's Silver/Gold
  // pick. Golden-mastered in tests/daily.test.mjs. Never alter without a history migration.
  const rng = mulberry32((0x9e3779b9 ^ (dayIndex + 1)) >>> 0);
  const silverPool = SILVER_UNIVERSAL.concat(SILVER_CERTIFIED.filter(id => rec.supports.includes(id)));
  const goldPool = GOLD.filter(id => rec.supports.includes(id));
  const silverId = silverPool[Math.floor(rng() * silverPool.length)];
  const goldId = goldPool[Math.floor(rng() * goldPool.length)];
  return { dayIndex, seed: rec.seed, par: rec.par, silver: makeObjective(silverId, rec), gold: makeObjective(goldId, rec) };
}

export function evaluate(objective, telemetry) { return OBJECTIVES[objective.id].check(telemetry, objective.param); }

// Grade ONE attempt. Bronze = won; Silver/Gold = won AND that tier's objective satisfied on this
// attempt. Silver and Gold are independent per-attempt results — a Gold attempt need NOT also be
// Silver, and vice versa. The day's standing is the OR-accumulation of attempts (see mergeTiers):
// with free retries, earning Silver on one attempt and Gold on another still awards both for the
// day. Callers must therefore fold each attempt into the day's record via mergeTiers, not overwrite.
export function evaluateChallenge(challenge, telemetry) {
  const bronze = !!telemetry.won;
  return {
    bronze,
    silver: bronze && evaluate(challenge.silver, telemetry),
    gold: bronze && evaluate(challenge.gold, telemetry),
  };
}

// Accumulate a day's tiers across attempts: each tier is best-of (OR), and we keep the best moves
// and time seen (lowest). `prev` may be undefined (first attempt of the day). This encodes the
// design rule that Bronze/Silver/Gold are earned independently and never lost by a later attempt.
export function mergeTiers(prev, attempt) {
  const p = prev || { bronze: false, silver: false, gold: false, moves: Infinity, elapsed: Infinity };
  return {
    bronze: !!p.bronze || !!attempt.bronze,
    silver: !!p.silver || !!attempt.silver,
    gold: !!p.gold || !!attempt.gold,
    moves: Math.min(p.moves ?? Infinity, attempt.moves ?? Infinity),
    elapsed: Math.min(p.elapsed ?? Infinity, attempt.elapsed ?? Infinity),
  };
}

// Streaks derived from the per-day record map { dayIndex: {bronze,silver,gold} }. Catch-up-friendly:
// a streak is the longest run of consecutive day indices all holding the tier, whenever completed.
export function streaks(records, todayIndex) {
  const has = (i, tier) => records[i] && records[i][tier];
  const played = i => !!records[i];
  const tierRun = tier => {
    const days = Object.keys(records).map(Number).filter(i => has(i, tier)).sort((a, b) => a - b);
    let best = 0, run = 0, prev = null;
    for (const d of days) { run = (prev != null && d === prev + 1) ? run + 1 : 1; best = Math.max(best, run); prev = d; }
    // Anchor on today if it was played at all (a played-but-missed today breaks that tier's streak);
    // only fall back to yesterday when today is entirely unplayed.
    let i = played(todayIndex) ? todayIndex : (played(todayIndex - 1) ? todayIndex - 1 : null);
    let cur = 0;
    while (i != null && has(i, tier)) { cur++; i--; }
    return { current: cur, best };
  };
  return { play: tierRun('bronze'), silver: tierRun('silver'), gold: tierRun('gold') };
}
