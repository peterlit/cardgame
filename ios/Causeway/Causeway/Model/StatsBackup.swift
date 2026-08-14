import Foundation

/// A portable, platform-agnostic snapshot of the player's stats — the daily-challenge record map
/// and the solved-deals map — so they can back up, restore, or move stats between devices without
/// iCloud. Plain JSON; keys are stringified ints (mirrors how the stores persist to UserDefaults).
struct StatsBackup: Codable {
    var format = "causeway-stats"
    var version = 1
    var exportedAt: String
    var daily: [String: TierResult]
    var wins: [String: WinRecord]

    static func make(daily: [Int: TierResult], wins: [Int: WinRecord]) -> StatsBackup {
        StatsBackup(exportedAt: ISO8601DateFormatter().string(from: Date()),
                    daily: Dictionary(uniqueKeysWithValues: daily.map { (String($0.key), $0.value) }),
                    wins: Dictionary(uniqueKeysWithValues: wins.map { (String($0.key), $0.value) }))
    }

    func encoded() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? enc.encode(self)) ?? Data()
    }

    /// Decode a backup, tolerating anything that isn't ours (returns nil rather than throwing).
    static func decode(_ data: Data) -> StatsBackup? {
        guard let b = try? JSONDecoder().decode(StatsBackup.self, from: data),
              b.format == "causeway-stats" else { return nil }
        return b
    }

    /// Int-keyed daily map (skips any non-int keys; merges dupes keeping the first).
    var dailyInts: [Int: TierResult] {
        Dictionary(daily.compactMap { k, v in Int(k).map { ($0, v) } }, uniquingKeysWith: { a, _ in a })
    }
    /// Int-keyed wins map (skips non-int keys; on a dupe keeps the faster time).
    var winsInts: [Int: WinRecord] {
        Dictionary(wins.compactMap { k, v in Int(k).map { ($0, v) } },
                   uniquingKeysWith: { a, b in a.secs <= b.secs ? a : b })
    }
}
