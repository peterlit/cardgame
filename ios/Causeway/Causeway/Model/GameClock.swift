import Foundation
import Combine

/// The elapsed-seconds clock, isolated into its own ObservableObject so its 1 Hz tick
/// invalidates ONLY the time label — not the whole board.
///
/// Previously `elapsed` was `@Published` on `Game`, so every tick re-rendered all of
/// `ContentView`, including `SummerBackground` (whose `.blur()` layers re-rasterize each
/// time) and the 52 cards' `matchedGeometryEffect`. Over minutes that grew unbounded and
/// the OS killed the app for memory. Keeping the clock separate — and NOT forwarding its
/// `objectWillChange` into `Game` — means an idle game does zero board re-renders.
final class GameClock: ObservableObject {
    @Published private(set) var elapsed = 0
    private var timer: Timer?

    var isRunning: Bool { timer != nil }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }
    func stop() { timer?.invalidate(); timer = nil }
    func reset() { stop(); elapsed = 0 }
    func set(_ value: Int) { elapsed = value }

    deinit { timer?.invalidate() }
}
