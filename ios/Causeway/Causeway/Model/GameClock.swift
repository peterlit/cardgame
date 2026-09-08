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
///
/// MEASUREMENT vs DISPLAY (skeptical-review R9): the timer exists only to refresh the label.
/// Elapsed time itself is wall-clock — `banked` seconds from finished stretches plus the age of
/// `runStart`. The old `elapsed += 1` per delivery undercounted whenever the run loop stalled
/// (2.26 s blocked → 1 recorded second), which made recorded bests depend on scheduling, not play.
/// Background time still does NOT count: ContentView pauses the clock when the scene leaves
/// .active and resumes it on return, preserving the shipped "sheets tick, background doesn't"
/// policy — now as an explicit decision instead of a Timer-suspension accident.
final class GameClock: ObservableObject {
    @Published private(set) var elapsed = 0
    private var timer: Timer?
    /// Wall anchor of the running stretch (nil while stopped).
    private var runStart: Date?
    /// Seconds accumulated by stretches already ended.
    private var banked = 0
    /// True only between pauseForBackground() and resumeFromBackground(): a clock the PLAYER's
    /// game stopped (win, reset) must not restart just because the app came foreground.
    private var pausedInBackground = false

    var isRunning: Bool { runStart != nil }

    func start() {
        guard runStart == nil else { return }
        runStart = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.publish()
        }
    }
    func stop() {
        banked = current
        runStart = nil
        pausedInBackground = false
        timer?.invalidate(); timer = nil
        publish()
    }
    func reset() {
        runStart = nil; pausedInBackground = false
        timer?.invalidate(); timer = nil
        banked = 0
        publish()
    }
    func set(_ value: Int) {
        banked = value
        if runStart != nil { runStart = Date() }
        publish()
    }

    /// Scene left .active: freeze the measurement (background time is not play time).
    func pauseForBackground() {
        guard runStart != nil else { return }
        stop()
        pausedInBackground = true
    }
    /// Scene returned to .active: resume only a stretch that backgrounding itself paused.
    func resumeFromBackground() {
        guard pausedInBackground else { return }
        pausedInBackground = false
        start()
    }

    private var current: Int { banked + (runStart.map { max(0, Int(Date().timeIntervalSince($0))) } ?? 0) }
    private func publish() {
        let c = current
        if c != elapsed { elapsed = c }
    }

    deinit { timer?.invalidate() }
}
