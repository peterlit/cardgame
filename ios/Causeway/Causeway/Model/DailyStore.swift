import Foundation
import Combine

/// Persists the per-day challenge record map (`dayIndex -> TierResult`), versioned, in
/// UserDefaults — the native equivalent of the web `causeway.daily` store. Tiers are
/// OR-accumulated across attempts via `mergeTiers`, so a tier once earned is never lost.
final class DailyStore: ObservableObject {
    @Published private(set) var days: [Int: TierResult] = [:]

    private let key = "causeway.daily"
    /// v2 = the August-2026 recut. The whole calendar was regenerated — new epoch, new seeds, new
    /// objectives — so a v1 record's day index names a completely different challenge. Keeping it
    /// would credit a Gold that was never played. A v1 store is therefore dropped, once.
    private let version = 2

    init() { load() }

    /// Fold a graded attempt into the day's standing (OR-accumulate) and persist.
    func record(day: Int, result: TierResult) {
        days[day] = mergeTiers(days[day], result)
        save()
    }

    /// Merge imported records (from a stats backup) into the store, OR-accumulating tiers and
    /// keeping best moves/time — never downgrades a locally-earned tier. Returns days newly added.
    @discardableResult
    func merge(_ incoming: [Int: TierResult]) -> Int {
        let before = days.count
        for (day, res) in incoming { days[day] = mergeTiers(days[day], res) }
        save()
        return days.count - before
    }

    // MARK: persistence

    private struct Persisted: Codable {
        var version: Int
        var days: [String: TierResult]
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        guard let decoded = try? JSONDecoder().decode(Persisted.self, from: data) else {
            // Don't silently discard history we can't read: stash the raw blob so the next
            // save() can't overwrite it, leaving a chance to recover it later.
            UserDefaults.standard.set(data, forKey: key + ".unreadable")
            return
        }
        guard decoded.version == version else {
            // Pre-recut history: stash the raw blob (so nothing is destroyed outright) and start
            // clean. See the `version` note above.
            UserDefaults.standard.set(data, forKey: key + ".v\(decoded.version)")
            return
        }
        // uniquingKeysWith so distinct string keys mapping to the same Int can't trap on launch.
        days = Dictionary(decoded.days.compactMap { k, v in Int(k).map { ($0, v) } },
                          uniquingKeysWith: { a, _ in a })
    }

    private func save() {
        let stringly = Dictionary(uniqueKeysWithValues: days.map { (String($0.key), $0.value) })
        let payload = Persisted(version: version, days: stringly)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
