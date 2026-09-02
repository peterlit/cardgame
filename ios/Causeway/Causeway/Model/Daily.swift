import Foundation

// Daily-Challenges logic — a Swift mirror of the canonical, Node-tested core in tests/daily.mjs
// (and the drift-guarded inline copy in index.html). A given date yields the same challenge and
// the same pass/fail as web, because the generator, the objective checkers, and the streak math
// are ported line-for-line. Mulberry32 is reused from Cards.swift so the per-day RNG matches.
//
// See docs/daily-challenges.md.

// MARK: - Calendar (day index = integer days since the launch epoch)

/// Floor division / modulo — Swift `/` and `%` truncate toward zero, but the JS reference
/// (tests/daily.mjs) wraps these subexpressions in `Math.floor`. They only diverge for negative
/// numerators (pre-year-1 dates), unreachable with today's year >= 2026 inputs, but we match
/// `Math.floor` semantics for ALL inputs so the port stays correct against the reference.
private func floorDiv(_ a: Int, _ b: Int) -> Int {
    let q = a / b, r = a % b
    return (r != 0 && (r < 0) != (b < 0)) ? q - 1 : q
}
func floorMod(_ a: Int, _ b: Int) -> Int {
    let r = a % b
    return (r != 0 && (r < 0) != (b < 0)) ? r + b : r
}

/// Proleptic-Gregorian days-from-civil (Howard Hinnant's algorithm) — identical to daily.mjs.
func daysFromCivil(_ y0: Int, _ m: Int, _ d: Int) -> Int {
    let y = y0 - (m <= 2 ? 1 : 0)
    let era = floorDiv(y >= 0 ? y : y - 399, 400)
    let yoe = y - era * 400
    let doy = floorDiv(153 * (m + (m > 2 ? -3 : 9)) + 2, 5) + d - 1
    let doe = yoe * 365 + floorDiv(yoe, 4) - floorDiv(yoe, 100) + doy
    return era * 146097 + doe - 719468
}
let EPOCH_DAYS = daysFromCivil(2026, 8, 1)    // launch epoch = day 0 = 2026-08-01
func dayIndexFor(_ y: Int, _ m: Int, _ d: Int) -> Int { daysFromCivil(y, m, d) - EPOCH_DAYS }

/// "Aug 12" for a day index (day 0 = the 2026-08-01 launch epoch). Shared by the Daily sheet's day
/// card and the board HUD's catch-up-day badge so the board can name WHICH day is in progress
/// (ux/WF-5:board-hud-omits-challenge-day).
func dayLabel(_ idx: Int) -> String {
    var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 1
    let cal = Calendar(identifier: .gregorian)
    guard let base = cal.date(from: c), let d = cal.date(byAdding: .day, value: idx, to: base) else { return "" }
    let f = DateFormatter(); f.dateFormat = "MMM d"
    return f.string(from: d)
}

/// Civil (year, month, day) of a day index, epoch day 0 = 2026-08-01. The inverse of dayIndexFor,
/// and the mirror of index.html's `civilOf`; the Daily sheet's calendar uses it to decide which
/// months the seeded pool spans.
func civilOf(_ idx: Int) -> (year: Int, month: Int, day: Int) {
    var c = DateComponents(); c.year = 2026; c.month = 8; c.day = 1
    let cal = Calendar(identifier: .gregorian)
    guard let base = cal.date(from: c), let d = cal.date(byAdding: .day, value: idx, to: base)
    else { return (2026, 8, 1) }
    let p = cal.dateComponents([.year, .month, .day], from: d)
    return (p.year ?? 2026, p.month ?? 8, p.day ?? 1)
}

/// Today's day index in the player's local calendar (matches web's `new Date()` local reading).
func todayIndex() -> Int {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    return dayIndexFor(c.year ?? 2026, c.month ?? 1, c.day ?? 1)
}

// MARK: - Telemetry (what a single attempt reports; the checkers read this)

/// One foundation send, in play order. `end` is "up" or "down".
struct FoundationEvent: Codable, Equatable {
    let suit: Int
    let rank: Int
    let end: String
    let moveIdx: Int
}

/// The accumulating per-attempt telemetry the app maintains during play (persisted across reload).
/// won/moves/elapsed are supplied at evaluation time (see `Attempt`).
struct Telemetry: Codable, Equatable {
    var cellUses = 0
    var undos = 0
    /// Largest tableau run relocated in a single move (F1/F2). 0 = no multi-card move yet.
    var maxRunMoved = 0
    var foundationOrder: [FoundationEvent] = []

    // Decode defensively so a future schema bump can't fail to restore an in-progress attempt.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cellUses = try c.decodeIfPresent(Int.self, forKey: .cellUses) ?? 0
        undos = try c.decodeIfPresent(Int.self, forKey: .undos) ?? 0
        maxRunMoved = try c.decodeIfPresent(Int.self, forKey: .maxRunMoved) ?? 0
        foundationOrder = try c.decodeIfPresent([FoundationEvent].self, forKey: .foundationOrder) ?? []
    }
}

/// The full input a checker evaluates: the telemetry plus this attempt's outcome/metrics.
struct Attempt {
    var won: Bool
    var moves: Int
    var elapsed: Int
    var cellUses: Int
    var undos: Int
    var foundationOrder: [FoundationEvent]
    var maxRunMoved: Int = 0
}

// MARK: - Objective catalogue (checkers evaluate an Attempt)
// Ported verbatim from tests/daily.mjs OBJECTIVES; each mirrors the solver's certification gate.
// EVERY objective is a FAMILY with a parameter, so one id yields many visibly different challenges.

/// One objective's parameters. Each family reads only the fields it needs, and the baked pool
/// carries exactly those keys (a missing key decodes to nil).
struct ObjParam: Decodable, Equatable {
    var N: Int? = nil        // moves cap / cell budget / run size / balance gap / rush deadline
    var R: Int? = nil        // split point
    var rank: Int? = nil     // which rank the family is about
    var min: Int? = nil      // end-bias: at least `min` of every suit from `end`
    var up: Int? = nil       // ends-first: how deep from the Ace end (0 = no Ace-end requirement)
    var down: Int? = nil     // ends-first: how deep from the King end (14 = no King-end requirement)
    var end: String? = nil   // "up" | "down"
}

/// Per-suit counts of ranks arriving from each end. u[suit] IS that suit's split point.
private func upDown(_ t: Attempt) -> (u: [Int], d: [Int]) {
    var u = [0, 0, 0, 0], d = [0, 0, 0, 0]
    for e in t.foundationOrder { if e.end == "up" { u[e.suit] += 1 } else { d[e.suit] += 1 } }
    return (u, d)
}
/// Widest gap between any two suits' home counts, folded over the foundation stream in play order.
private func maxSpread(_ t: Attempt) -> Int {
    var home = [0, 0, 0, 0], worst = 0
    for e in t.foundationOrder {
        home[e.suit] += 1
        worst = Swift.max(worst, (home.max() ?? 0) - (home.min() ?? 0))
    }
    return worst
}
/// STRICT prefix: nothing else goes home until every suit holds A..up and K..down.
private func endsFirstOK(_ t: Attempt, _ p: ObjParam) -> Bool {
    let upN = p.up ?? 0, downN = p.down ?? 14
    var u = [0, 0, 0, 0], d = [14, 14, 14, 14]
    func met() -> Bool { u.allSatisfy { $0 >= upN } && d.allSatisfy { $0 <= downN } }
    for e in t.foundationOrder {
        if met() { break }
        let required = e.end == "up" ? e.rank <= upN : e.rank >= downN
        if !required { return false }
        if e.end == "up" { u[e.suit] = e.rank } else { d[e.suit] = e.rank }
    }
    return true
}
/// LOOSE prefix: every <rank> reaches the King-end foundation before any Ace goes home.
private func beforeAceOK(_ t: Attempt, _ p: ObjParam) -> Bool {
    let r = p.rank ?? 13
    var n = 0
    for e in t.foundationOrder {
        if e.rank == r && e.end == "down" { n += 1 }
        else if e.rank == 1 && e.end == "up" && n < 4 { return false }
    }
    return true
}
/// Per-suit version: each suit's <rank> comes down before that same suit's Ace goes up.
private func suitTopFirstOK(_ t: Attempt, _ p: ObjParam) -> Bool {
    let r = p.rank ?? 13
    var down = [false, false, false, false]
    for e in t.foundationOrder {
        if e.rank == r && e.end == "down" { down[e.suit] = true }
        else if e.rank == 1 && e.end == "up" && !down[e.suit] { return false }
    }
    return true
}
private func suitSprintOK(_ t: Attempt) -> Bool {
    var home = [0, 0, 0, 0], started = [false, false, false, false]
    for e in t.foundationOrder {
        let S = e.suit
        if !started[S] {
            for T in 0..<4 where T != S && started[T] && home[T] < 13 { return false }
            started[S] = true
        }
        home[S] += 1
    }
    return true
}
/// The move index at which the fourth card of `rank` reached a foundation (nil = not yet).
private func rushCompleted(_ t: Attempt, _ rank: Int) -> Int? {
    var seen = [false, false, false, false], n = 0
    for e in t.foundationOrder where e.rank == rank && !seen[e.suit] {
        seen[e.suit] = true
        n += 1
        if n == 4 { return e.moveIdx }
    }
    return nil
}

/// The authoritative pass/fail for an objective id (mirrors OBJECTIVES[id].check).
func objectiveCheck(_ id: String, _ t: Attempt, param p: ObjParam) -> Bool {
    switch id {
    case "moves":          return t.won && t.moves <= (p.N ?? 0)
    case "no-undo":        return t.won && t.undos == 0
    case "cells-le":       return t.won && t.cellUses <= (p.N ?? 0)
    case "max-run":        return t.won && t.maxRunMoved <= (p.N ?? 1)
    case "big-move":       return t.won && t.maxRunMoved >= (p.N ?? 5)
    case "split-at":       return t.won && upDown(t).u.allSatisfy { $0 == (p.R ?? 7) }
    case "end-bias":
        guard t.won else { return false }
        let x = upDown(t)
        return (p.end == "up" ? x.u : x.d).allSatisfy { $0 >= (p.min ?? 0) }
    case "ends-first":     return t.won && endsFirstOK(t, p)
    case "before-ace":     return t.won && beforeAceOK(t, p)
    case "suit-top-first": return t.won && suitTopFirstOK(t, p)
    case "suit-sprint":    return t.won && suitSprintOK(t)
    case "rank-rush":
        guard t.won, let at = rushCompleted(t, p.rank ?? 1) else { return false }
        return at <= (p.N ?? 0)
    case "suit-balance":   return t.won && maxSpread(t) <= (p.N ?? 13)
    default:               return false
    }
}

enum Grade: String { case silver, gold }

struct Objective: Equatable {
    let id: String
    let grade: Grade
    let param: ObjParam
    let label: String
}

/// One day's objective as the baked pool states it.
struct ObjSpec: Decodable, Equatable {
    let id: String
    let param: ObjParam
}

private let RANK_NAME = ["", "Ace", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King"]
private let RANK_SHORT = ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
private func rankName(_ r: Int) -> String { (1...13).contains(r) ? RANK_NAME[r] : "\(r)" }
private func rankShort(_ r: Int) -> String { (1...13).contains(r) ? RANK_SHORT[r] : "\(r)" }
private func rankPlural(_ r: Int) -> String { r == 6 ? "Sixes" : rankName(r) + "s" }
/// "Aces", "Aces and Twos", "Aces, Twos and Threes" — the same joiner the web copy uses.
private func rankList(_ rs: [Int]) -> String {
    rs.enumerated().reduce("") { acc, e in
        acc + (e.offset == 0 ? "" : e.offset == rs.count - 1 ? " and " : ", ") + rankPlural(e.element)
    }
}

private func gradeFor(_ id: String, _ p: ObjParam) -> Grade {
    switch id {
    case "cells-le":     return (p.N ?? 0) == 0 ? .gold : .silver
    case "end-bias":     return (p.min ?? 0) >= 10 ? .gold : .silver
    case "suit-balance": return (p.N ?? 13) <= 3 ? .gold : .silver
    case "big-move", "split-at", "ends-first", "before-ace", "suit-top-first", "suit-sprint": return .gold
    default:             return .silver
    }
}

private func labelFor(_ id: String, _ p: ObjParam) -> String {
    switch id {
    case "moves":   return "Win in \(p.N ?? 0) moves or fewer"
    case "no-undo": return "Win without using undo"
    case "cells-le":
        let n = p.N ?? 0
        if n == 0 { return "Win without ever using a free cell" }
        return "Win using free cells at most \(n == 1 ? "once" : n == 2 ? "twice" : "\(n) times")"
    case "max-run":
        let n = p.N ?? 1
        return n == 1 ? "Move one card at a time — never move a run" : "Never move more than \(n) cards in a single move"
    case "big-move": return "Move a run of \(p.N ?? 5) or more cards in a single move"
    case "split-at":
        let r = p.R ?? 7
        return "Split every suit exactly at the \(rankName(r)) — A-\(rankShort(r)) up, \(rankShort(r + 1))-K down"
    case "end-bias":
        let m = p.min ?? 0
        if m == 13 {
            return p.end == "up" ? "Win using only the Ace-end foundations — every suit A up to K"
                                 : "Win using only the King-end foundations — every suit K down to A"
        }
        return "Take at least \(m) of every suit from the \(p.end == "up" ? "Ace" : "King") end"
    case "ends-first":
        let upN = p.up ?? 0, downN = p.down ?? 14
        var parts: [String] = []
        if upN > 0 { parts.append("all four " + rankList(Array(1...upN))) }
        if downN < 14 { parts.append("all four " + rankList(Array((downN...13).reversed()))) }
        return "Send \(parts.joined(separator: ", plus ")) home before any other card"
    case "before-ace":     return "Get every \(rankName(p.rank ?? 13)) onto the King-end foundation before any Ace goes home"
    case "suit-top-first": return "For every suit, send its \(rankName(p.rank ?? 13)) home from the King end before its Ace"
    case "suit-sprint":    return "Finish one whole suit before any other suit is started"
    case "rank-rush":      return "Get all four \(rankPlural(p.rank ?? 1)) home within your first \(p.N ?? 0) moves"
    case "suit-balance":   return "Never let one suit get more than \(p.N ?? 13) cards ahead of another"
    default:               return id
    }
}

func makeObjective(_ spec: ObjSpec) -> Objective {
    Objective(id: spec.id, grade: gradeFor(spec.id, spec.param), param: spec.param, label: labelFor(spec.id, spec.param))
}

// MARK: - The date -> challenge lookup

struct Challenge: Equatable {
    let dayIndex: Int
    let seed: Int
    let par: Int
    let silver: Objective
    let gold: Objective
}

/// Day D reads pool[D] directly: the offline generator (tools/solver/build-month.mjs) chose that
/// day's seed AND its two objectives deliberately, maximising variety across the seeded month, so
/// there is no runtime RNG here. Returns nil outside the seeded range (no challenge that day).
func dailyChallenge(_ dayIndex: Int, _ pool: [PoolDay]) -> Challenge? {
    guard dayIndex >= 0, dayIndex < pool.count else { return nil }
    let rec = pool[dayIndex]
    return Challenge(dayIndex: dayIndex, seed: rec.seed, par: rec.par,
                     silver: makeObjective(rec.silver), gold: makeObjective(rec.gold))
}

// MARK: - Grading, accumulation, streaks

/// One clear of a day's deal: what it cost. Every win logs one (the day's `moves`/`elapsed` stay
/// the best-of), so a solved day can show the attempts behind its best, not just the best.
struct RunLog: Codable, Equatable {
    var moves: Int
    var elapsed: Int
}

/// How many clears one day keeps, oldest trimmed first. The day's BEST moves/time live in
/// `moves`/`elapsed` and are never trimmed, so the cap only ever costs a heavy replayer the middle
/// of their own history. Mirrors RUN_LOG_MAX in tests/daily.mjs.
let runLogMax = 20

/// Concatenate two run logs in play order, drop exact duplicates, keep the most recent `runLogMax`.
/// A run is identified by its (moves, elapsed) pair because the record stores no timestamp — and
/// `mergeTiers` is the same door a re-imported stats backup comes through, so re-importing your own
/// file must not inflate the log. The cost is that two distinct clears with the same move count AND
/// the same whole second collapse into one; the log is a keepsake, not a ledger.
func mergeRuns(_ a: [RunLog], _ b: [RunLog]) -> [RunLog] {
    var out: [RunLog] = [], seen = Set<String>()
    for r in a + b {
        let k = "\(r.moves):\(r.elapsed)"
        if seen.contains(k) { continue }
        seen.insert(k)
        out.append(r)
    }
    return out.count > runLogMax ? Array(out.suffix(runLogMax)) : out
}

/// A day's standing (also the shape of one graded attempt). moves/elapsed are nil on a loss.
struct TierResult: Codable, Equatable {
    var bronze = false
    var silver = false
    var gold = false
    var flawless = false
    /// ⏰ cleared on the challenge's own date. Orthogonal to the tiers: it records WHEN, not how well.
    var onTime = false
    var moves: Int? = nil
    var elapsed: Int? = nil
    /// Every clear of this day, oldest first (a loss logs none). See `mergeRuns`.
    var runs: [RunLog] = []

    init(bronze: Bool = false, silver: Bool = false, gold: Bool = false, flawless: Bool = false,
         onTime: Bool = false, moves: Int? = nil, elapsed: Int? = nil, runs: [RunLog] = []) {
        self.bronze = bronze; self.silver = silver; self.gold = gold; self.flawless = flawless
        self.onTime = onTime
        self.moves = moves; self.elapsed = elapsed; self.runs = runs
    }
    // Tolerate old/partial records (e.g. a pre-Flawless day map) — decode missing keys as defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bronze = try c.decodeIfPresent(Bool.self, forKey: .bronze) ?? false
        silver = try c.decodeIfPresent(Bool.self, forKey: .silver) ?? false
        gold = try c.decodeIfPresent(Bool.self, forKey: .gold) ?? false
        flawless = try c.decodeIfPresent(Bool.self, forKey: .flawless) ?? false
        onTime = try c.decodeIfPresent(Bool.self, forKey: .onTime) ?? false
        moves = try c.decodeIfPresent(Int.self, forKey: .moves)
        elapsed = try c.decodeIfPresent(Int.self, forKey: .elapsed)
        runs = try c.decodeIfPresent([RunLog].self, forKey: .runs) ?? []   // pre-log records: no history, just their banked best
    }
}

func evaluate(_ objective: Objective, _ t: Attempt) -> Bool {
    objectiveCheck(objective.id, t, param: objective.param)
}

/// ⏰ Same-day: was this win earned on the challenge's own date? Day indices come from the device's
/// LOCAL calendar — there is no server to ask, and a personal streak needs no anti-cheat. The grace
/// clause is deliberate: an attempt begun before midnight that lands just after it still counts,
/// but a game resumed days later does not.
func isOnTime(challengeDay: Int?, winDay: Int, attemptStartDay: Int?) -> Bool {
    guard let day = challengeDay else { return false }
    if winDay == day { return true }
    return attemptStartDay == day && winDay == day + 1
}

/// Grade ONE attempt. Bronze = won; Silver/Gold = won AND that tier's objective met this attempt.
/// `flawless` = all three in THIS single attempt (harder than banking them across retries).
/// `onTime` is orthogonal: a bare Bronze earned on the day counts, a Flawless replay does not.
func evaluateChallenge(_ challenge: Challenge, _ t: Attempt, onTime: Bool = false) -> TierResult {
    let bronze = t.won
    let silver = bronze && evaluate(challenge.silver, t)
    let gold = bronze && evaluate(challenge.gold, t)
    var result = TierResult(bronze: bronze, silver: silver, gold: gold, flawless: bronze && silver && gold,
                            onTime: bronze && onTime)
    // A win also logs itself as ONE run; moves/elapsed stay the day's best-of.
    if bronze {
        result.moves = t.moves
        result.elapsed = t.elapsed
        result.runs = [RunLog(moves: t.moves, elapsed: t.elapsed)]
    }
    return result
}

private func minOpt(_ a: Int?, _ b: Int?) -> Int? {
    switch (a, b) {
    case let (x?, y?): return Swift.min(x, y)
    case let (x?, nil): return x
    case let (nil, y?): return y
    default: return nil
    }
}

/// Accumulate a day's tiers across attempts: each tier is best-of (OR, sticky), keeping the lowest
/// moves/time seen. A tier once earned is never lost by a later worse attempt.
func mergeTiers(_ prev: TierResult?, _ attempt: TierResult) -> TierResult {
    let p = prev ?? TierResult()
    return TierResult(
        bronze: p.bronze || attempt.bronze,
        silver: p.silver || attempt.silver,
        gold: p.gold || attempt.gold,
        flawless: p.flawless || attempt.flawless,   // sticky once any single attempt aces all three
        onTime: p.onTime || attempt.onTime,         // sticky once the day was cleared on its own date
        moves: minOpt(p.moves, attempt.moves),
        elapsed: minOpt(p.elapsed, attempt.elapsed),
        runs: mergeRuns(p.runs, attempt.runs))   // every clear, oldest first (a loss contributes none)
}

struct StreakRun: Equatable { let current: Int; let best: Int; let total: Int }
struct Streaks: Equatable { let play, onTime, silver, gold, flawless: StreakRun }

/// Streaks derived from the per-day record map. Catch-up-friendly: a streak is the longest run of
/// consecutive day indices all holding the tier. Current run anchors on today if today was played
/// at all (a played-but-missed today breaks it), else falls back to yesterday.
func streaks(_ records: [Int: TierResult], _ todayIndex: Int) -> Streaks {
    func tierRun(_ has: (TierResult) -> Bool) -> StreakRun {
        let days = records.keys.filter { has(records[$0]!) }.sorted()
        var best = 0, run = 0
        var prev: Int? = nil
        for d in days {
            run = (prev != nil && d == prev! + 1) ? run + 1 : 1
            best = max(best, run)
            prev = d
        }
        var i: Int? = records[todayIndex] != nil ? todayIndex
                    : (records[todayIndex - 1] != nil ? todayIndex - 1 : nil)
        var cur = 0
        while let ii = i, let r = records[ii], has(r) { cur += 1; i = ii - 1 }
        return StreakRun(current: cur, best: best, total: days.count)   // total = all days ever holding the tier
    }
    return Streaks(play: tierRun { $0.bronze }, onTime: tierRun { $0.onTime },
                   silver: tierRun { $0.silver },
                   gold: tierRun { $0.gold }, flawless: tierRun { $0.flawless })
}

// MARK: - Live HUD hint: has this objective already been made IMPOSSIBLE? (UI-only; authoritative
// scoring uses the checkers above at win.) Mirrors each checker's violation branch.

func objViolated(_ obj: Objective, _ t: Attempt) -> Bool {
    let p = obj.param
    switch obj.id {
    case "moves":    return t.moves > (p.N ?? 0)
    case "no-undo":  return t.undos > 0
    case "cells-le": return t.cellUses > (p.N ?? 0)
    case "max-run":  return t.maxRunMoved > (p.N ?? 1)
    case "big-move": return false                        // positive goal — always still reachable
    case "split-at":
        let r = p.R ?? 7, x = upDown(t)
        return x.u.contains { $0 > r } || x.d.contains { $0 > 13 - r }
    case "end-bias":
        // Needing `min` of every suit from one end caps the OTHER pile at 13 - min.
        let m = p.min ?? 0, x = upDown(t)
        return (p.end == "up" ? x.d : x.u).contains { $0 > 13 - m }
    case "ends-first":     return !endsFirstOK(t, p)
    case "before-ace":     return !beforeAceOK(t, p)
    case "suit-top-first": return !suitTopFirstOK(t, p)
    case "suit-sprint":    return !suitSprintOK(t)
    case "rank-rush":
        let n = p.N ?? 0
        if let at = rushCompleted(t, p.rank ?? 1) { return at > n }
        return t.moves > n                               // deadline blown with cards still out
    case "suit-balance":   return maxSpread(t) > (p.N ?? 13)
    default:               return false
    }
}

/// Is `obj` already LOCKED IN — guaranteed to be earned on ANY completion (so the player is "on
/// track" just by clearing the deal)? Achievement objectives only; the move/undo/free-cell budgets
/// can still be blown, so they're never secured until the deal is done. UI-only hint (mirrors the
/// web objSecured). `up`/`down` are the live foundation ranks.
///
/// Every case here reads live board state, so Undo un-secures a check exactly as it rewinds the
/// board — including `big-move`, whose `maxRunMoved` Game.undo() restores from the move snapshot.
/// That field must stay two-way: `max-run` reads the same counter, and a one-way version would make
/// an undone 2-card move permanently fail it. The authoritative checker reads the same rolled-back
/// value at win, so the chip always predicts the grade it will actually award.
func objSecured(_ obj: Objective, _ t: Attempt, up: [Int], down: [Int]) -> Bool {
    if objViolated(obj, t) { return false }
    let p = obj.param
    switch obj.id {
    case "ends-first":
        let upN = p.up ?? 0, downN = p.down ?? 14
        return up.allSatisfy { $0 >= upN } && down.allSatisfy { $0 <= downN }
    case "before-ace", "suit-top-first":
        let r = p.rank ?? 13
        return down.allSatisfy { $0 <= r }
    case "suit-sprint":
        return (0..<4).filter { down[$0] == up[$0] + 1 }.count >= 3   // only one suit left to start
    case "rank-rush":
        let r = p.rank ?? 1
        return (0..<4).allSatisfy { up[$0] >= r || down[$0] <= r }    // all four already home
    // A suit's count from one end only ever grows, so once every suit holds `min` from the named
    // end the tier is locked in whatever happens next — unlike `split-at`, whose exact split a
    // later send can still break. `up[s]` IS that suit's Ace-end count; its King-end count is
    // 14 - down[s]. (Left unsecured, a 🥈 the player had already banked mid-game — e.g. K..4 down
    // in every suit against `min: 9` — showed `·` on the HUD until the win awarded it anyway.)
    case "end-bias":
        let m = p.min ?? 0
        return p.end == "up" ? up.allSatisfy { $0 >= m } : down.allSatisfy { 14 - $0 >= m }
    case "big-move":
        return t.maxRunMoved >= (p.N ?? 5)
    default:
        return false   // budgets and split points — not securable until the win
    }
}

// MARK: - Pool (baked JSON, loaded from the app bundle)

/// One seeded day: the deal plus the two objectives the offline generator picked for it.
struct PoolDay: Decodable, Equatable {
    let seed: Int
    let par: Int
    let silver: ObjSpec
    let gold: ObjSpec
}
private struct PoolFile: Decodable { let days: [PoolDay] }

/// The baked winning lines for one seed, one per tier. `silver` is present only when the day's
/// Silver is a certified (constraining) objective; a universal Silver falls back to `bronze`.
/// `flawless` is the single line that satisfies BOTH objectives — what the 🌟 tier asks for; it is
/// optional only so an older (v2) solutions file still decodes.
struct TierSolutions: Decodable, Equatable {
    let bronze: String
    let silver: String?
    let gold: String?
    let flawless: String?
}
private struct SolutionsFile: Decodable { let solutions: [String: TierSolutions] }

enum DailyData {
    /// The bundled pool file, decoded once (nil if missing/unreadable — Daily is then disabled).
    private static let file: PoolFile? = {
        guard let url = Bundle.main.url(forResource: "daily-pool", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(PoolFile.self, from: data)
    }()

    /// The seeded calendar: day D is `pool[D]`, day 0 = the epoch (2026-08-01). Days past the end
    /// of this array simply have no challenge.
    static let pool: [PoolDay] = file?.days ?? []

    /// Baked "Show me how to win" lines per seed (bronze/silver/gold). Empty if the resource is
    /// missing — the feature just doesn't offer itself for those seeds.
    static let solutions: [Int: TierSolutions] = {
        guard let url = Bundle.main.url(forResource: "daily-solutions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SolutionsFile.self, from: data) else { return [:] }
        return Dictionary(file.solutions.compactMap { k, v in Int(k).map { ($0, v) } },
                          uniquingKeysWith: { a, _ in a })
    }()
}
