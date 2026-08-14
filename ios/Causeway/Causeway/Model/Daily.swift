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
let EPOCH_DAYS = daysFromCivil(2026, 8, 12)   // launch epoch = day 0
func dayIndexFor(_ y: Int, _ m: Int, _ d: Int) -> Int { daysFromCivil(y, m, d) - EPOCH_DAYS }

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
    var foundationOrder: [FoundationEvent] = []

    // Decode defensively so a future schema bump can't fail to restore an in-progress attempt.
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cellUses = try c.decodeIfPresent(Int.self, forKey: .cellUses) ?? 0
        undos = try c.decodeIfPresent(Int.self, forKey: .undos) ?? 0
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
}

// MARK: - Objective catalogue (checkers evaluate an Attempt)
// Ported verbatim from tests/daily.mjs OBJECTIVES; each mirrors the solver's certification gate.

private func acesFirst(_ t: Attempt) -> Bool {
    var a = 0
    for e in t.foundationOrder { if a >= 4 { break }; if e.rank == 1 { a += 1 } else { return false } }
    return t.won && a == 4
}
private func kingsFirst(_ t: Attempt) -> Bool {
    var k = 0
    for e in t.foundationOrder {
        if e.rank == 13 && e.end == "down" { k += 1 }
        else if e.rank == 1 && e.end == "up" && k < 4 { return false }
    }
    return t.won
}
private func jacksDownFirst(_ t: Attempt) -> Bool {
    var j = 0
    for e in t.foundationOrder {
        if e.rank == 11 && e.end == "down" { j += 1 }
        else if e.rank == 1 && e.end == "up" && j < 4 { return false }
    }
    return t.won
}
private func suitsTopDown(_ t: Attempt) -> Bool {
    var kd = [false, false, false, false]
    for e in t.foundationOrder {
        if e.rank == 13 && e.end == "down" { kd[e.suit] = true }
        else if e.rank == 1 && e.end == "up" && !kd[e.suit] { return false }
    }
    return t.won
}
private func suitSprint(_ t: Attempt) -> Bool {
    var home = [0, 0, 0, 0], started = [false, false, false, false]
    for e in t.foundationOrder {
        let S = e.suit
        if !started[S] {
            for T in 0..<4 where T != S && started[T] && home[T] < 13 { return false }
            started[S] = true
        }
        home[S] += 1
    }
    return t.won
}
private func downOpeners20(_ t: Attempt) -> Bool {
    var k = 0, opened: Int? = nil
    for e in t.foundationOrder where e.rank == 13 && e.end == "down" {
        k += 1
        if k == 4 { opened = e.moveIdx; break }
    }
    return t.won && opened != nil && opened! <= 20
}

/// The authoritative pass/fail for an objective id (mirrors OBJECTIVES[id].check).
func objectiveCheck(_ id: String, _ t: Attempt, param: Int) -> Bool {
    switch id {
    case "moves":            return t.won && t.moves <= param
    case "no-undo":          return t.won && t.undos == 0
    case "cells-le-1":       return t.won && t.cellUses <= 1
    case "cells-le-2":       return t.won && t.cellUses <= 2
    case "down-openers-20":  return downOpeners20(t)
    case "no-cells":         return t.won && t.cellUses == 0
    case "aces-first":       return acesFirst(t)
    case "kings-first":      return kingsFirst(t)
    case "jacks-down-first": return jacksDownFirst(t)
    case "suits-top-down":   return suitsTopDown(t)
    case "suit-sprint":      return suitSprint(t)
    default:                 return false
    }
}

enum Grade: String { case silver, gold }

struct Objective: Equatable {
    let id: String
    let grade: Grade
    let param: Int      // N for 'moves'; unused (0) otherwise
    let label: String
}

// FROZEN — APPEND-ONLY, NEVER REORDER (the per-day RNG indexes these). See daily.mjs.
private let SILVER_UNIVERSAL = ["moves", "no-undo"]
private let SILVER_CERTIFIED = ["cells-le-1", "cells-le-2", "down-openers-20"]
private let GOLD = ["no-cells", "aces-first", "kings-first", "jacks-down-first", "suits-top-down", "suit-sprint"]

private func gradeFor(_ id: String) -> Grade { GOLD.contains(id) ? .gold : .silver }

private func labelFor(_ id: String, _ param: Int) -> String {
    switch id {
    case "moves":            return "Win in \(param) moves or fewer"
    case "no-undo":          return "Win without using undo"
    case "cells-le-1":       return "Win using a free cell at most once"
    case "cells-le-2":       return "Win using free cells at most twice"
    case "down-openers-20":  return "Open all four down-foundations within your first 20 moves"
    case "no-cells":         return "Win without ever using a free cell"
    case "aces-first":       return "Send all four Aces home before any other card"
    case "kings-first":      return "Send all four Kings to the down-foundation before any Ace"
    case "jacks-down-first": return "Get every Jack onto the down-foundation before any Ace"
    case "suits-top-down":   return "For every suit, send its King home before its Ace"
    case "suit-sprint":      return "Finish one whole suit before any other suit is started"
    default:                 return id
    }
}

private func makeObjective(_ id: String, par: Int) -> Objective {
    let param = id == "moves" ? Int((Double(par) * 1.2).rounded()) : 0
    return Objective(id: id, grade: gradeFor(id), param: param, label: labelFor(id, param))
}

// MARK: - The deterministic date -> challenge generator

struct Challenge: Equatable {
    let dayIndex: Int
    let seed: Int
    let par: Int
    let silver: Objective
    let gold: Objective
}

/// Day D always maps to pool[D] (append-only ⇒ frozen history); a per-day RNG picks the
/// Silver/Gold objective from what that seed is certified to support. Returns nil if D is out of
/// the pool's current range. FROZEN rng-seed formula — never alter without a history migration.
func dailyChallenge(_ dayIndex: Int, _ pool: [PoolSeed]) -> Challenge? {
    guard dayIndex >= 0, dayIndex < pool.count else { return nil }
    let rec = pool[dayIndex]
    var rng = Mulberry32(UInt32(truncatingIfNeeded: 0x9e37_79b9 ^ (dayIndex + 1)))
    let silverPool = SILVER_UNIVERSAL + SILVER_CERTIFIED.filter { rec.supports.contains($0) }
    let goldPool = GOLD.filter { rec.supports.contains($0) }
    // Web yields `undefined` (misrenders) on an empty pool; Swift would hard-crash on the subscript.
    // Treat "no objective available" as no challenge — the nil callers already handle for out-of-range.
    guard !silverPool.isEmpty, !goldPool.isEmpty else { return nil }
    let silverId = silverPool[rng.int(silverPool.count)]   // rng() call #1 (order matters — matches web)
    let goldId = goldPool[rng.int(goldPool.count)]         // rng() call #2
    return Challenge(dayIndex: dayIndex, seed: rec.seed, par: rec.par,
                     silver: makeObjective(silverId, par: rec.par),
                     gold: makeObjective(goldId, par: rec.par))
}

// MARK: - Grading, accumulation, streaks

/// A day's standing (also the shape of one graded attempt). moves/elapsed are nil on a loss.
struct TierResult: Codable, Equatable {
    var bronze = false
    var silver = false
    var gold = false
    var flawless = false
    var moves: Int? = nil
    var elapsed: Int? = nil

    init(bronze: Bool = false, silver: Bool = false, gold: Bool = false, flawless: Bool = false,
         moves: Int? = nil, elapsed: Int? = nil) {
        self.bronze = bronze; self.silver = silver; self.gold = gold; self.flawless = flawless
        self.moves = moves; self.elapsed = elapsed
    }
    // Tolerate old/partial records (e.g. a pre-Flawless day map) — decode missing keys as defaults.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bronze = try c.decodeIfPresent(Bool.self, forKey: .bronze) ?? false
        silver = try c.decodeIfPresent(Bool.self, forKey: .silver) ?? false
        gold = try c.decodeIfPresent(Bool.self, forKey: .gold) ?? false
        flawless = try c.decodeIfPresent(Bool.self, forKey: .flawless) ?? false
        moves = try c.decodeIfPresent(Int.self, forKey: .moves)
        elapsed = try c.decodeIfPresent(Int.self, forKey: .elapsed)
    }
}

func evaluate(_ objective: Objective, _ t: Attempt) -> Bool {
    objectiveCheck(objective.id, t, param: objective.param)
}

/// Grade ONE attempt. Bronze = won; Silver/Gold = won AND that tier's objective met this attempt.
/// `flawless` = all three in THIS single attempt (harder than banking them across retries).
func evaluateChallenge(_ challenge: Challenge, _ t: Attempt) -> TierResult {
    let bronze = t.won
    let silver = bronze && evaluate(challenge.silver, t)
    let gold = bronze && evaluate(challenge.gold, t)
    var result = TierResult(bronze: bronze, silver: silver, gold: gold, flawless: bronze && silver && gold)
    if bronze { result.moves = t.moves; result.elapsed = t.elapsed }
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
        moves: minOpt(p.moves, attempt.moves),
        elapsed: minOpt(p.elapsed, attempt.elapsed))
}

struct StreakRun: Equatable { let current: Int; let best: Int }
struct Streaks: Equatable { let play, silver, gold, flawless: StreakRun }

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
        return StreakRun(current: cur, best: best)
    }
    return Streaks(play: tierRun { $0.bronze }, silver: tierRun { $0.silver },
                   gold: tierRun { $0.gold }, flawless: tierRun { $0.flawless })
}

// MARK: - Live HUD hint: has this objective already been made IMPOSSIBLE? (UI-only; authoritative
// scoring uses the checkers above at win.) Mirrors each checker's violation branch.

func objViolated(_ obj: Objective, _ t: Attempt) -> Bool {
    let fo = t.foundationOrder
    switch obj.id {
    case "moves":    return t.moves > obj.param
    case "no-undo":  return t.undos > 0
    case "cells-le-1": return t.cellUses > 1
    case "cells-le-2": return t.cellUses > 2
    case "no-cells":   return t.cellUses > 0
    case "aces-first":
        var a = 0
        for e in fo { if a >= 4 { break }; if e.rank == 1 { a += 1 } else { return true } }
        return false
    case "kings-first":
        var k = 0
        for e in fo {
            if e.rank == 13 && e.end == "down" { k += 1 }
            else if e.rank == 1 && e.end == "up" && k < 4 { return true }
        }
        return false
    case "jacks-down-first":
        var j = 0
        for e in fo {
            if e.rank == 11 && e.end == "down" { j += 1 }
            else if e.rank == 1 && e.end == "up" && j < 4 { return true }
        }
        return false
    case "suits-top-down":
        var kd = [false, false, false, false]
        for e in fo {
            if e.rank == 13 && e.end == "down" { kd[e.suit] = true }
            else if e.rank == 1 && e.end == "up" && !kd[e.suit] { return true }
        }
        return false
    case "suit-sprint":
        var home = [0, 0, 0, 0], st = [false, false, false, false]
        for e in fo {
            let S = e.suit
            if !st[S] {
                for T in 0..<4 where T != S && st[T] && home[T] < 13 { return true }
                st[S] = true
            }
            home[S] += 1
        }
        return false
    case "down-openers-20":
        var k = 0
        for e in fo where e.rank == 13 && e.end == "down" {
            k += 1
            if k == 4 { return e.moveIdx > 20 }
        }
        return t.moves > 20
    default:
        return false
    }
}

/// Is `obj` already LOCKED IN — guaranteed to be earned on ANY completion (so the player is "on
/// track" just by clearing the deal)? Achievement objectives only; the move/undo/free-cell budgets
/// can still be blown, so they're never secured until the deal is done. UI-only hint (mirrors the
/// web objSecured). `up`/`down` are the live foundation ranks.
func objSecured(_ obj: Objective, _ t: Attempt, up: [Int], down: [Int]) -> Bool {
    if objViolated(obj, t) { return false }
    switch obj.id {
    case "aces-first":       return up.allSatisfy { $0 >= 1 }       // all four Aces home first
    case "kings-first":      return down.allSatisfy { $0 <= 13 }    // all four Kings down before any Ace
    case "suits-top-down":   return down.allSatisfy { $0 <= 13 }    // every suit's King down
    case "jacks-down-first": return down.allSatisfy { $0 <= 11 }    // all four Jacks down
    case "down-openers-20":  return down.allSatisfy { $0 <= 13 }    // all four down-foundations opened
    case "suit-sprint":      return (0..<4).filter { down[$0] == up[$0] + 1 }.count >= 3  // ≥3 suits home (only one left; no interleave possible)
    default:                 return false   // move/undo/cell budgets — not securable until win
    }
}

// MARK: - Pool (baked JSON, loaded from the app bundle)

struct PoolSeed: Decodable, Equatable {
    let seed: Int
    let par: Int
    let supports: [String]
}
private struct PoolFile: Decodable { let seeds: [PoolSeed] }

/// The baked winning lines for one seed, one per tier. `silver` is present only when the day's
/// Silver is a certified (constraining) objective; a universal Silver falls back to `bronze`.
struct TierSolutions: Decodable, Equatable {
    let bronze: String
    let silver: String?
    let gold: String?
}
private struct SolutionsFile: Decodable { let solutions: [String: TierSolutions] }

enum DailyData {
    /// The certified seed pool, or [] if the resource is missing/unreadable (Daily then disabled).
    static let pool: [PoolSeed] = {
        guard let url = Bundle.main.url(forResource: "daily-pool", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PoolFile.self, from: data) else { return [] }
        return file.seeds
    }()

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
