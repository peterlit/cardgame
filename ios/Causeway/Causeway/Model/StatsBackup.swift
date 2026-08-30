import Foundation

/// A portable, platform-agnostic snapshot of the player's stats — the daily-challenge record map
/// and the solved-deals map — so they can back up, restore, or move stats between devices without
/// iCloud. Plain JSON; keys are stringified ints (mirrors how the stores persist to UserDefaults).
///
/// The two maps are NOT equally portable, which is what `version` 2 exists to record:
///   * `wins` is keyed by deal number, and a deal number means the same thing forever — the
///     shuffle is a pure function of the seed. It restores anywhere, always.
///   * `daily` is keyed by DAY INDEX, and a day index only names a challenge together with the
///     pool that was baked at the time. The Aug-30 recut re-picked every day under the flawless
///     gate, so a pre-recut record for "day 12" now credits a completely different deal's Gold.
///     `DailyStore.load()` already drops a pre-v3 local store for exactly this reason; before
///     these stamps, importing a pre-recut backup walked straight past that wipe and fabricated
///     medals for challenges that were never played (bug/WF-11:legacy-backup-defeats-daily-v3-wipe).
///
/// So every export now stamps the daily-store generation and the calendar epoch it was taken
/// under, and the importer refuses a `daily` map it cannot prove was earned on THIS calendar.
/// Stamp-less files (version 1, everything written before this change) are exactly the ambiguous
/// case — `TierResult` gained `flawless`/`onTime` in the same commit and both decodeIfPresent to
/// false, so shape alone cannot tell a legacy file from a current one — and they take the degraded
/// path: wins imported, daily dropped, with the reason said out loud.
struct StatsBackup: Codable {
    var format = "causeway-stats"
    /// 1 = no generation stamps (pre-Aug-30 exports). 2 = the three stamps below are present.
    var version = 2
    var exportedAt: String
    /// `DailyStore.version` at export time — the generation the `daily` records were earned under.
    var dailyVersion: Int?
    /// The calendar epoch (`EPOCH_DAYS`) day indices were counted from at export time.
    var poolEpoch: Int?
    /// How many days the exporting build's pool held (recorded for diagnosis; not a gate — a later
    /// build may legitimately extend the same calendar).
    var poolDays: Int?
    var daily: [String: TierResult]
    var wins: [String: WinRecord]

    enum CodingKeys: String, CodingKey {
        case format, version, exportedAt, dailyVersion, poolEpoch, poolDays, daily, wins
    }

    static func make(daily: [Int: TierResult], wins: [Int: WinRecord]) -> StatsBackup {
        StatsBackup(exportedAt: ISO8601DateFormatter().string(from: Date()),
                    dailyVersion: DailyStore.version,
                    poolEpoch: EPOCH_DAYS,
                    poolDays: DailyData.pool.count,
                    daily: Dictionary(uniqueKeysWithValues: daily.map { (String($0.key), $0.value) }),
                    wins: Dictionary(uniqueKeysWithValues: wins.map { (String($0.key), $0.value) }))
    }

    /// Were this file's `daily` records earned on the SAME challenge calendar this build ships?
    /// A missing stamp is a NO, not a maybe: an unstamped file predates the recut gate, and the
    /// whole point of the gate is that an unprovable day map credits medals that were never played.
    var dailyRecordsMatchThisPool: Bool {
        dailyVersion == DailyStore.version && poolEpoch == EPOCH_DAYS
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

extension StatsBackup {
    /// Tolerant decode: a file written by ANY build must still yield whatever it does carry, so
    /// every key is optional here and `format` (checked by `decode`) is the only real gate. The
    /// stamps decode to nil on an older file, which `dailyRecordsMatchThisPool` reads as "cannot
    /// prove it" — never as "close enough".
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? ""
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try c.decodeIfPresent(String.self, forKey: .exportedAt) ?? ""
        dailyVersion = try c.decodeIfPresent(Int.self, forKey: .dailyVersion)
        poolEpoch = try c.decodeIfPresent(Int.self, forKey: .poolEpoch)
        poolDays = try c.decodeIfPresent(Int.self, forKey: .poolDays)
        daily = try c.decodeIfPresent([String: TierResult].self, forKey: .daily) ?? [:]
        wins = try c.decodeIfPresent([String: WinRecord].self, forKey: .wins) ?? [:]
    }
}
