import Foundation
import Combine

/// Persists the per-day challenge record map (`dayIndex -> TierResult`), versioned, in
/// UserDefaults — the native equivalent of the web `causeway.daily` store. Tiers are
/// OR-accumulated across attempts via `mergeTiers`, so a tier once earned is never lost.
final class DailyStore: ObservableObject {
    @Published private(set) var days: [Int: TierResult] = [:]

    private let key = "causeway.daily"
    private let version = 1

    init() { load() }

    /// Fold a graded attempt into the day's standing (OR-accumulate) and persist.
    func record(day: Int, result: TierResult) {
        days[day] = mergeTiers(days[day], result)
        save()
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
