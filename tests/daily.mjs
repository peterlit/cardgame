// Shared Daily-Challenges logic: the deterministic date->challenge lookup, the objective
// catalogue (checkers evaluated from per-attempt telemetry), and streak computation. This is the
// canonical, Node-tested source; the web app inlines an identical copy (drift-guarded) and iOS
// mirrors it in Swift, so a given date yields the same challenge and the same pass/fail on every
// platform.
//
// See docs/daily-challenges.md.

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
export const EPOCH_DAYS = daysFromCivil(2026, 8, 1);   // launch epoch = day 0 = 2026-08-01
export function dayIndexFor(y, m, d) { return daysFromCivil(y, m, d) - EPOCH_DAYS; }

// ---- rank naming (labels are generated from parameters, so this is shared by every family) ----
const RANK_NAME = [null, 'Ace', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Jack', 'Queen', 'King'];
const RANK_SHORT = [null, 'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
export function rankName(r) { return RANK_NAME[r]; }
export function rankShort(r) { return RANK_SHORT[r]; }
export function rankPlural(r) { return r === 6 ? 'Sixes' : RANK_NAME[r] + 's'; }

// ---- objective catalogue (checkers evaluate a telemetry record) ----
// telemetry = { won, moves, elapsed, cellUses, undos, usedAutoplay, usedAutoFinish, maxRunMoved,
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
//
// EVERY objective is a FAMILY with a parameter object. The generator (tools/solver/build-month.mjs)
// picks both the id and the parameter per day, so one id yields many visibly different challenges.

// Per-suit counts of how many ranks arrived from each end. With 13 cards per suit u + d === 13 on
// a win, so u alone determines where that suit's two halves met (its "split point").
const upDown = t => {
  const u = [0, 0, 0, 0], d = [0, 0, 0, 0];
  for (const e of t.foundationOrder) { if (e.end === 'up') u[e.suit]++; else d[e.suit]++; }
  return { u, d };
};
// Cards home per suit, folded over foundationOrder in play order.
const foldHome = (t, step) => {
  const home = [0, 0, 0, 0];
  for (const e of t.foundationOrder) { home[e.suit]++; if (step(e, home) === false) return false; }
  return true;
};

// STRICT prefix: nothing else goes home until every suit holds A..up on the up pile and K..down on
// the down pile. up === 0 means "no Ace-end requirement"; down === 14 means "no King-end one".
const endsFirst = (t, p) => {
  const u = [0, 0, 0, 0], d = [14, 14, 14, 14];
  const met = () => u.every(x => x >= p.up) && d.every(x => x <= p.down);
  for (const e of t.foundationOrder) {
    if (met()) break;
    const required = e.end === 'up' ? e.rank <= p.up : e.rank >= p.down;
    if (!required) return false;
    if (e.end === 'up') u[e.suit] = e.rank; else d[e.suit] = e.rank;
  }
  return t.won;
};
// LOOSE prefix: every <rank> reaches the King-end foundation before any Ace goes home.
const beforeAce = (t, p) => {
  let n = 0;
  for (const e of t.foundationOrder) {
    if (e.rank === p.rank && e.end === 'down') n++;
    else if (e.rank === 1 && e.end === 'up' && n < 4) return false;
  }
  return t.won;
};
// Per-suit version: each suit's <rank> comes down before that same suit's Ace goes up.
const suitTopFirst = (t, p) => {
  const down = [false, false, false, false];
  for (const e of t.foundationOrder) {
    if (e.rank === p.rank && e.end === 'down') down[e.suit] = true;
    else if (e.rank === 1 && e.end === 'up' && !down[e.suit]) return false;
  }
  return t.won;
};
const suitSprint = t => {
  const home = [0, 0, 0, 0], started = [false, false, false, false];
  for (const e of t.foundationOrder) {
    const S = e.suit;
    if (!started[S]) { for (let T = 0; T < 4; T++) if (T !== S && started[T] && home[T] < 13) return false; started[S] = true; }
    home[S]++;
  }
  return t.won;
};
// All four cards of one rank home (from either end) within N moves.
const rankRush = (t, p) => {
  const seen = [false, false, false, false];
  let n = 0;
  for (const e of t.foundationOrder) {
    if (e.rank !== p.rank || seen[e.suit]) continue;
    seen[e.suit] = true;
    if (++n === 4) return t.won && e.moveIdx <= p.N;
  }
  return false;
};
// No suit may ever run more than N cards ahead of another.
const suitBalance = (t, p) => t.won && foldHome(t, (_e, home) => Math.max(...home) - Math.min(...home) <= p.N);

export const OBJECTIVES = {
  // --- universal: any winnable deal supports these, so they need no certification -------------
  'moves':   { grade: 'silver', universal: true, label: p => `Win in ${p.N} moves or fewer`,          check: (t, p) => t.won && t.moves <= p.N },
  'no-undo': { grade: 'silver', universal: true, label: () => 'Win without using undo',              check: t => t.won && t.undos === 0 },

  // --- resource discipline --------------------------------------------------------------------
  'cells-le': {
    grade: p => (p.N === 0 ? 'gold' : 'silver'),
    label: p => (p.N === 0 ? 'Win without ever using a free cell'
                           : `Win using free cells at most ${p.N === 1 ? 'once' : p.N === 2 ? 'twice' : p.N + ' times'}`),
    check: (t, p) => t.won && t.cellUses <= p.N,
  },

  // --- move shape ------------------------------------------------------------------------------
  'max-run': {
    grade: 'silver',
    label: p => (p.N === 1 ? 'Move one card at a time — never move a run'
                           : `Never move more than ${p.N} cards in a single move`),
    check: (t, p) => t.won && (t.maxRunMoved ?? 0) <= p.N,
  },
  'big-move': {
    grade: 'gold',
    label: p => `Move a run of ${p.N} or more cards in a single move`,
    check: (t, p) => t.won && (t.maxRunMoved ?? 0) >= p.N,
  },

  // --- split point: where each suit's two halves meet ------------------------------------------
  'split-at': {
    grade: 'gold',
    label: p => `Split every suit exactly at the ${rankName(p.R)} — A-${rankShort(p.R)} up, ${rankShort(p.R + 1)}-K down`,
    check: (t, p) => t.won && upDown(t).u.every(x => x === p.R),
  },
  'end-bias': {
    grade: p => (p.min >= 10 ? 'gold' : 'silver'),
    label: p => (p.min === 13
      ? (p.end === 'up' ? 'Win using only the Ace-end foundations — every suit A up to K'
                        : 'Win using only the King-end foundations — every suit K down to A')
      : `Take at least ${p.min} of every suit from the ${p.end === 'up' ? 'Ace' : 'King'} end`),
    check: (t, p) => {
      if (!t.won) return false;
      const { u, d } = upDown(t);
      return (p.end === 'up' ? u : d).every(x => x >= p.min);
    },
  },

  // --- ordering ---------------------------------------------------------------------------------
  'ends-first': {
    grade: 'gold',
    label: p => {
      const list = rs => rs.map(rankPlural).reduce((a, x, i) => a + (i === 0 ? '' : i === rs.length - 1 ? ' and ' : ', ') + x, '');
      const parts = [];
      if (p.up > 0) parts.push(`all four ${list(Array.from({ length: p.up }, (_, i) => i + 1))}`);
      if (p.down < 14) parts.push(`all four ${list(Array.from({ length: 14 - p.down }, (_, i) => 13 - i))}`);
      return `Send ${parts.join(', plus ')} home before any other card`;
    },
    check: endsFirst,
  },
  'before-ace': {
    grade: 'gold',
    label: p => `Get every ${rankName(p.rank)} onto the King-end foundation before any Ace goes home`,
    check: beforeAce,
  },
  'suit-top-first': {
    grade: 'gold',
    label: p => `For every suit, send its ${rankName(p.rank)} home from the King end before its Ace`,
    check: suitTopFirst,
  },
  'suit-sprint': {
    grade: 'gold',
    label: () => 'Finish one whole suit before any other suit is started',
    check: suitSprint,
  },

  // --- tempo -------------------------------------------------------------------------------------
  'rank-rush': {
    grade: 'silver',
    label: p => `Get all four ${rankPlural(p.rank)} home within your first ${p.N} moves`,
    check: rankRush,
  },
  'suit-balance': {
    grade: p => (p.N <= 3 ? 'gold' : 'silver'),
    label: p => `Never let one suit get more than ${p.N} cards ahead of another`,
    check: suitBalance,
  },
};

// ---- the live HUD hints (UI-only; the checkers above stay authoritative at the win) ----------
// The board chip answers two questions about an attempt IN PROGRESS: is this tier already
// impossible (✗), and is it already guaranteed (✓)? Both are mirrored in index.html and
// ios/.../Daily.swift; this is the canonical, tested copy the drift guards pin them to.

// Has this objective already been made IMPOSSIBLE (fail-fast)? Mirrors each checker's violation
// branch, family for family, with the SAME parameters the checkers read.
export function objViolated(obj, t) {
  const p = obj.param || {}, fo = t.foundationOrder;
  const won = { ...t, won: true };   // the order-only half of each checker: they end with `return t.won`
  switch (obj.id) {
    case 'moves':          return t.moves > p.N;
    case 'no-undo':        return t.undos > 0;
    case 'cells-le':       return t.cellUses > p.N;
    case 'max-run':        return (t.maxRunMoved ?? 0) > p.N;
    case 'big-move':       return false;                       // positive goal — always still reachable
    case 'split-at':       { const { u, d } = upDown(t); return u.some(x => x > p.R) || d.some(x => x > 13 - p.R); }
    // Needing `min` of every suit from one end caps the OTHER pile at 13 - min.
    case 'end-bias':       { const { u, d } = upDown(t); return (p.end === 'up' ? d : u).some(x => x > 13 - p.min); }
    case 'ends-first':     return !endsFirst(won, p);
    case 'before-ace':     return !beforeAce(won, p);
    case 'suit-top-first': return !suitTopFirst(won, p);
    case 'suit-sprint':    return !suitSprint(won);
    case 'rank-rush':      { const seen = [false, false, false, false]; let n = 0;
                             for (const e of fo) { if (e.rank !== p.rank || seen[e.suit]) continue; seen[e.suit] = true;
                               if (++n === 4) return e.moveIdx > p.N; }
                             return t.moves > p.N; }           // deadline blown with cards still out
    case 'suit-balance':   return !suitBalance(won, p);
    default:               return false;
  }
}

// Is this objective already LOCKED IN — guaranteed to be earned on ANY completion (so the player is
// "on track" just by clearing the deal)? Achievement objectives only; the move/undo/free-cell
// budgets can still be blown, so they are never secured until the deal is actually done.
// `up[s]` is that suit's highest rank home from the Ace end (0 = empty) and so IS its Ace-end count;
// `down[s]` is its lowest rank home from the King end (14 = empty), so its King-end count is
// 14 - down[s]. Both are live board state, so Undo un-secures a check exactly as it rewinds.
export function objSecured(obj, up, down, t) {
  if (objViolated(obj, t)) return false;
  const p = obj.param || {};
  switch (obj.id) {
    case 'ends-first':     return up.every(u => u >= p.up) && down.every(d => d <= p.down);
    case 'before-ace':
    case 'suit-top-first': return down.every(d => d <= p.rank);
    case 'suit-sprint':    return [0, 1, 2, 3].filter(s => down[s] === up[s] + 1).length >= 3;  // only one suit left to start
    case 'rank-rush':      return [0, 1, 2, 3].every(s => up[s] >= p.rank || down[s] <= p.rank); // all four already home
    // A suit's count from one end only ever grows, so once every suit holds `min` from the named
    // end the tier is locked in whatever happens next — unlike split-at, whose exact split a later
    // send can still break.
    case 'end-bias':       { const m = p.min; return p.end === 'up' ? up.every(u => u >= m) : down.every(d => 14 - d >= m); }
    // Secured relative to the CURRENT line (undo rewinds telem.maxRunMoved, like every case above);
    // the win-time checker reads the same field, so the chip always predicts the grade.
    case 'big-move':       return (t.maxRunMoved ?? 0) >= p.N;
    default: return false;   // budgets and split points — not securable until the win
  }
}

// A challenge's grade may depend on its parameter (e.g. cells-le{0} is Gold, cells-le{2} Silver).
export function gradeOf(id, param) {
  const g = OBJECTIVES[id].grade;
  return typeof g === 'function' ? g(param) : g;
}
export function labelOf(id, param) { return OBJECTIVES[id].label(param || {}); }
export function makeObjective(spec) {
  const param = spec.param || {};
  return { id: spec.id, grade: gradeOf(spec.id, param), param, label: labelOf(spec.id, param) };
}

// Day D reads pool.days[D] directly: the generator (tools/solver/build-month.mjs) chose that day's
// seed AND its two objectives deliberately, maximising variety across the seeded month, so there is
// no runtime RNG here. Returns null outside the seeded range (no challenge that day).
export function dailyChallenge(dayIndex, pool) {
  const rec = dayIndex >= 0 ? (pool.days || [])[dayIndex] : null;
  if (!rec) return null;
  return { dayIndex, seed: rec.seed, par: rec.par, silver: makeObjective(rec.silver), gold: makeObjective(rec.gold) };
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
export function evaluateChallenge(challenge, telemetry, onTime = false) {
  const bronze = !!telemetry.won;
  const silver = bronze && evaluate(challenge.silver, telemetry);
  const gold = bronze && evaluate(challenge.gold, telemetry);
  // `flawless` = all three tiers in THIS single attempt (harder than banking them across retries).
  // `onTime` is orthogonal to all of them: it records WHEN, not how well — a bare Bronze earned on
  // the day counts, and a Flawless replay of a past day does not.
  const result = { bronze, silver, gold, flawless: !!(bronze && silver && gold), onTime: bronze && !!onTime };
  // A win also logs itself as ONE run. `moves`/`elapsed` above stay the day's best-of; `runs` is the
  // per-clear history behind that best (see mergeRuns).
  if (bronze) {
    result.moves = telemetry.moves;
    result.elapsed = telemetry.elapsed;
    result.runs = [{ moves: telemetry.moves, elapsed: telemetry.elapsed }];
  }
  return result;
}

// ---- the per-day run log: what every clear of that day's deal cost ----------------------------
// How many clears a day keeps, oldest trimmed first. The day's BEST moves/time live in
// `moves`/`elapsed` and are never trimmed, so the cap only ever costs a heavy replayer the middle
// of their own history.
export const RUN_LOG_MAX = 20;

// Concatenate two run logs in play order, drop exact duplicates, keep the most recent RUN_LOG_MAX.
// A run is identified by its (moves, elapsed) pair because the record stores no timestamp — and
// mergeTiers is the same door a re-imported stats backup comes through, so re-importing your own
// file must not inflate the log. The cost is that two genuinely distinct clears that took the same
// number of moves AND the same whole second collapse into one; the log is a keepsake, not a ledger.
export function mergeRuns(a = [], b = []) {
  const out = [], seen = new Set();
  for (const r of [...a, ...b]) {
    if (r == null || r.moves == null) continue;
    const k = `${r.moves}:${r.elapsed}`;
    if (seen.has(k)) continue;
    seen.add(k);
    out.push({ moves: r.moves, elapsed: r.elapsed });
  }
  return out.slice(-RUN_LOG_MAX);
}

// Accumulate a day's tiers across attempts: each tier is best-of (OR), and we keep the best moves
// and time seen (lowest). `prev` may be undefined (first attempt of the day). `attempt` is an
// evaluateChallenge() result (or a prior mergeTiers result); attempts that omit moves/elapsed (e.g.
// a lost game) are treated as Infinity so they never displace a prior best. This encodes the design
// rule that Bronze/Silver/Gold are earned independently and never lost by a later attempt.
export function mergeTiers(prev, attempt) {
  const p = prev || { bronze: false, silver: false, gold: false, flawless: false, onTime: false, moves: Infinity, elapsed: Infinity };
  return {
    bronze: !!p.bronze || !!attempt.bronze,
    silver: !!p.silver || !!attempt.silver,
    gold: !!p.gold || !!attempt.gold,
    flawless: !!p.flawless || !!attempt.flawless,   // sticky once any single attempt aces all three
    onTime: !!p.onTime || !!attempt.onTime,         // sticky once the day was cleared on its own date
    moves: Math.min(p.moves ?? Infinity, attempt.moves ?? Infinity),
    elapsed: Math.min(p.elapsed ?? Infinity, attempt.elapsed ?? Infinity),
    runs: mergeRuns(p.runs, attempt.runs),   // every clear, oldest first (a loss contributes none)
  };
}

// ⏰ Same-day: was this win earned on the challenge's own date? `winDay` and `attemptStartDay` are
// day indices (same basis as `challengeDay`), taken from the device's LOCAL calendar date — there is
// no server to ask, and a personal streak needs no anti-cheat (see docs/daily-challenges.md §2).
// The grace clause is the anti-frustration rule for the player who starts late in the evening. It is
// DAY-GRANULAR, because no clock time is stored: an attempt begun on day D counts if it is won any
// time on D+1 — not only just after midnight. That is deliberately generous (the tight version would
// need a start TIMESTAMP, which §2 rules out); a game resumed two or more days later never counts,
// and a Replay re-stamps the start day to today, so the window cannot be chained past D+1.
export function isOnTime({ challengeDay, winDay, attemptStartDay }) {
  if (challengeDay == null || winDay == null) return false;
  if (winDay === challengeDay) return true;
  return attemptStartDay === challengeDay && winDay === challengeDay + 1;
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
  return { play: tierRun('bronze'), silver: tierRun('silver'), gold: tierRun('gold'),
           flawless: tierRun('flawless'), onTime: tierRun('onTime') };
}
