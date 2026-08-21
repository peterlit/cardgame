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
// Per-suit counts of how many ranks arrived from each end. The suit's SPLIT POINT is u[suit]:
// with 13 cards per suit, u + d === 13 on a win, so u alone determines where the halves met.
const upDown = t => { const u = [0, 0, 0, 0], d = [0, 0, 0, 0]; for (const e of t.foundationOrder) { if (e.end === 'up') u[e.suit]++; else d[e.suit]++; } return { u, d }; };
const splitEven = t => t.won && upDown(t).u.every(x => x === 7);                 // A1: every suit A-7 up / 8-K down
const downHeavy = t => t.won && upDown(t).u.every(x => x <= 5);                  // A2: >= 8 of every suit from the King end
const noDownFoundation = t => t.won && upDown(t).d.every(x => x === 0);          // B3: only up foundations used
const noUpFoundation = t => t.won && upDown(t).u.every(x => x === 0);            // B4: only down foundations used
// maxRunMoved defaults to 0 when absent (an older saved attempt): 0 means no multi-card move
// happened, which is exactly right for both checks below.
const noSupermoves = t => t.won && (t.maxRunMoved ?? 0) <= 1;                    // F1
const oneBigMove = t => t.won && (t.maxRunMoved ?? 0) >= 5;                      // F2
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
  'down-heavy':      { grade: 'silver', certified: true, label: () => 'Take at least 8 of every suit from the King end',                                                 check: downHeavy },
  'no-supermoves':   { grade: 'silver', certified: true, label: () => 'Move one card at a time — never move a run',                                                      check: noSupermoves },
  'split-even':      { grade: 'gold',   certified: true, label: () => 'Split every suit exactly down the middle — A-7 up, 8-K down',                                     check: splitEven },
  'no-down-foundation': { grade: 'gold', certified: true, label: () => 'Win without ever using a down foundation',                                                       check: noDownFoundation },
  'no-up-foundation':{ grade: 'gold',   certified: true, label: () => 'Win without ever using an up foundation — every suit K down to A',                                check: noUpFoundation },
  'one-big-move':    { grade: 'gold',   certified: true, label: () => 'Move a run of 5 or more cards in a single move',                                                  check: oneBigMove },
};

// FROZEN — APPEND-ONLY, NEVER REORDER. dailyChallenge() indexes these three arrays with a per-day
// RNG, so any reorder or mid-array insertion retroactively reshuffles which objective every PAST
// day picked (frozen history). New objectives may only be *appended*. The golden-master test in
// tests/daily.test.mjs pins several days and fails if this invariant is broken.
const SILVER_UNIVERSAL = ['moves', 'no-undo'];
const SILVER_CERTIFIED = ['cells-le-1', 'cells-le-2', 'down-openers-20', 'down-heavy', 'no-supermoves'];
const GOLD = ['no-cells', 'aces-first', 'kings-first', 'jacks-down-first', 'suits-top-down', 'suit-sprint', 'split-even', 'no-down-foundation', 'no-up-foundation', 'one-big-move'];

function makeObjective(id, rec) {
  const o = OBJECTIVES[id];
  const param = o.param ? o.param(rec) : {};
  return { id, grade: o.grade, param, label: o.label(param) };
}

// Deterministic + stable: day D always maps to pool.seeds[D] (append-only pool never shifts a past
// day), and a per-day RNG picks the Silver/Gold objective from what that seed is certified to
// support. Returns null if D is out of the pool's current range (challenge not available yet).
export function dailyChallenge(dayIndex, pool) {
  // Day >= 0 indexes the frozen, append-only calendar. Day < 0 indexes `preSeeds` — the pre-epoch
  // PLAYTEST SANDBOX (docs/daily-objectives-proposal.md §8), which is explicitly mutable: rewriting
  // it can never disturb a day >= 0, because those indices, seeds and RNG draws are untouched.
  const rec = dayIndex >= 0 ? pool.seeds[dayIndex] : (pool.preSeeds || [])[-dayIndex - 1];
  if (!rec) return null;
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
//
// The result is directly mergeable: on a WIN it also echoes this attempt's { moves, elapsed } so
// mergeTiers can keep best-of. A LOST attempt omits moves/elapsed entirely — a loss has no "best
// time" to record, and omitting lets mergeTiers's `?? Infinity` preserve the prior best rather than
// clobbering it with a losing run's metrics.
export function evaluateChallenge(challenge, telemetry) {
  const bronze = !!telemetry.won;
  const silver = bronze && evaluate(challenge.silver, telemetry);
  const gold = bronze && evaluate(challenge.gold, telemetry);
  // `flawless` = all three tiers in THIS single attempt (harder than banking them across retries).
  const result = { bronze, silver, gold, flawless: !!(bronze && silver && gold) };
  if (bronze) { result.moves = telemetry.moves; result.elapsed = telemetry.elapsed; }
  return result;
}

// Accumulate a day's tiers across attempts: each tier is best-of (OR), and we keep the best moves
// and time seen (lowest). `prev` may be undefined (first attempt of the day). `attempt` is an
// evaluateChallenge() result (or a prior mergeTiers result); attempts that omit moves/elapsed (e.g.
// a lost game) are treated as Infinity so they never displace a prior best. This encodes the design
// rule that Bronze/Silver/Gold are earned independently and never lost by a later attempt.
export function mergeTiers(prev, attempt) {
  const p = prev || { bronze: false, silver: false, gold: false, flawless: false, moves: Infinity, elapsed: Infinity };
  return {
    bronze: !!p.bronze || !!attempt.bronze,
    silver: !!p.silver || !!attempt.silver,
    gold: !!p.gold || !!attempt.gold,
    flawless: !!p.flawless || !!attempt.flawless,   // sticky once any single attempt aces all three
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
    return { current: cur, best, total: days.length };   // total = all days ever holding the tier
  };
  return { play: tierRun('bronze'), silver: tierRun('silver'), gold: tierRun('gold'), flawless: tierRun('flawless') };
}
