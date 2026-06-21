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
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: WinRecord].self, from: data)
        else { return }
        wins = Dictionary(uniqueKeysWithValues: decoded.compactMap { k, v in
            Int(k).map { ($0, v) }
        })
    }

    private func save() {
        let stringly = Dictionary(uniqueKeysWithValues: wins.map { (String($0.key), $0.value) })
        if let data = try? JSONEncoder().encode(stringly) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum DealFormat {
    static func rangeLabel(_ r: ClosedRange<Int>) -> String {
        r.lowerBound == r.upperBound ? "\(r.lowerBound)" : "\(r.lowerBound)–\(r.upperBound)"
    }
    static func time(_ secs: Int) -> String {
        String(format: "%d:%02d", secs / 60, secs % 60)
    }
}
