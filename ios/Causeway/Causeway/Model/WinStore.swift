import Foundation
import Combine

struct WinRecord: Codable, Equatable {
    var moves: Int
    var secs: Int
    var date: Date
}

/// Persists solved deals (keeping the best score per deal) and exposes them as
/// compressed contiguous ranges — the native equivalent of the web Wins screen.
final class WinStore: ObservableObject {
    @Published private(set) var wins: [Int: WinRecord] = [:]

    private let key = "causeway.wins"

    init() { load() }

    var count: Int { wins.count }

    func isWon(_ seed: Int) -> Bool { wins[seed] != nil }

    /// Record a win, keeping the best moves/time if the deal was solved before.
    func record(seed: Int, moves: Int, secs: Int) {
        if let prev = wins[seed] {
            wins[seed] = WinRecord(moves: min(prev.moves, moves),
                                   secs: min(prev.secs, secs),
                                   date: Date())
        } else {
            wins[seed] = WinRecord(moves: moves, secs: secs, date: Date())
        }
        save()
    }

    /// Merge imported wins (from a stats backup), keeping the best (fewest moves / least time)
    /// per deal — never loses a locally-solved deal. Returns deals newly added.
    @discardableResult
    func merge(_ incoming: [Int: WinRecord]) -> Int {
        let before = wins.count
        for (seed, rec) in incoming {
            if let prev = wins[seed] {
                wins[seed] = WinRecord(moves: min(prev.moves, rec.moves),
                                       secs: min(prev.secs, rec.secs),
                                       date: max(prev.date, rec.date))
            } else {
                wins[seed] = rec
            }
        }
        save()
        return wins.count - before
    }

    /// Contiguous [start, end] runs of solved deal numbers, ascending.
    func ranges() -> [ClosedRange<Int>] {
        let nums = wins.keys.sorted()
        var out: [ClosedRange<Int>] = []
        var i = 0
        while i < nums.count {
            let a = nums[i]
            var b = nums[i]
            while i + 1 < nums.count, nums[i + 1] == b + 1 { b = nums[i + 1]; i += 1 }
            out.append(a...b)
            i += 1
        }
        return out
    }

    func records(in range: ClosedRange<Int>) -> [(seed: Int, rec: WinRecord)] {
        range.compactMap { seed in wins[seed].map { (seed, $0) } }
    }

    // MARK: persistence (UserDefaults — survives relaunch; safe if unavailable)

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode([String: WinRecord].self, from: data) else {
            // Don't silently discard unreadable history: stash the raw blob so the next
            // save() can't overwrite it, leaving a chance to recover it later.
            UserDefaults.standard.set(data, forKey: key + ".unreadable")
            return
        }
        // uniquingKeysWith (not uniqueKeysWithValues) so distinct JSON keys that map to
        // the same Int (e.g. "1" and "01") merge instead of trapping — a launch crash-loop.
        wins = Dictionary(decoded.compactMap { k, v in Int(k).map { ($0, v) } },
                          uniquingKeysWith: { a, b in a.secs <= b.secs ? a : b })
    }

    private func save() {
        let stringly = Dictionary(uniqueKeysWithValues: wins.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(stringly) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum DealFormat {
    /// Human range for the two deal-number entry fields. It quotes `maxValidSeed` (what the engine
    /// can actually deal), NOT `maxSeed` (the random-deal ceiling) — the old "1–1,000,000" hint was
    /// unenforced AND wrong, since daily/sandbox deals run far above it (bug/WF-7).
    static let seedRangeHint = "1–\(Game.maxValidSeed.formatted(.number.grouping(.automatic)))"

    /// A deal number as the app IDENTIFIES it — ungrouped, matching the board pill and the Wins
    /// range chips. (`Text("Deal #\(seed)")` interpolates through LocalizedStringKey and groups the
    /// digits, so the same deal read as "561325499" in the title and "561,325,499" in the row.)
    static func seed(_ s: Int) -> String { String(s) }

    static func rangeLabel(_ r: ClosedRange<Int>) -> String {
        r.lowerBound == r.upperBound ? "\(r.lowerBound)" : "\(r.lowerBound)–\(r.upperBound)"
    }
    static func time(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
