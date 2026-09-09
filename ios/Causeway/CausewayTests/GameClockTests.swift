import XCTest
@testable import Causeway

/// R9 (skeptical review): elapsed time is a MEASUREMENT, not a count of timer deliveries. The old
/// clock did `elapsed += 1` per delivery, so a stalled main thread undercounted — the review's
/// probe recorded 1 second for 2.26 blocked seconds.
///
/// Closeout (wall-clock-upper-bounds-can-flake): these tests used to Thread.sleep for real wall
/// time and assert loose bounds, which spent ~5.7s per run and went red under 0.7s of scheduler
/// overshoot on a loaded Mac. They now advance an injected `now` by hand: the run loop of a
/// synchronous test still delivers ZERO timer ticks (so a delivery-counting clock would read 0
/// and fail), but the measurement is exact, instant, and cannot be descheduled into a failure.
final class GameClockTests: XCTestCase {

    /// Hand-advanced wall clock injected into every clock under test.
    private var fakeNow = Date(timeIntervalSinceReferenceDate: 0)

    private func makeClock() -> GameClock {
        let clock = GameClock()
        clock.now = { self.fakeNow }
        return clock
    }

    func testZeroTimerDeliveriesStillMeasuresWallTime() {
        let clock = makeClock()
        clock.start()
        fakeNow += 2.3   // wall time passes; the unserviced run loop delivers no timer ticks
        clock.stop()
        XCTAssertEqual(clock.elapsed, 2,
            "2.3 wall-clock seconds with zero timer deliveries must record as exactly 2 — delivery-counting reads 0")
    }

    func testSetSeedsTheMeasurementAcrossRestore() {
        let clock = makeClock()
        clock.set(41)
        XCTAssertEqual(clock.elapsed, 41)
        clock.start()
        fakeNow += 1.5
        clock.stop()
        XCTAssertEqual(clock.elapsed, 42, "restored seconds + the new stretch must add")
    }

    func testBackgroundPauseFreezesAndResumeContinues() {
        let clock = makeClock()
        clock.start()
        fakeNow += 1.5
        clock.pauseForBackground()
        let atPause = clock.elapsed
        XCTAssertEqual(atPause, 1)
        XCTAssertFalse(clock.isRunning)
        fakeNow += 3600   // an hour "backgrounded" — must not count
        XCTAssertEqual(clock.elapsed, atPause, "background time is not play time")
        clock.resumeFromBackground()
        XCTAssertTrue(clock.isRunning)
        fakeNow += 1.5
        clock.stop()
        XCTAssertEqual(clock.elapsed, atPause + 1,
            "resume must continue the measurement exactly where the pause froze it")
    }

    func testResumeDoesNotRestartAClockTheGameStopped() {
        let clock = makeClock()
        clock.start()
        clock.stop()                    // a win/reset stopped it — not backgrounding
        clock.resumeFromBackground()
        XCTAssertFalse(clock.isRunning,
            "coming foreground must not restart a clock the game itself stopped")
    }

    func testResetZeroesEverything() {
        let clock = makeClock()
        clock.set(30)
        clock.start()
        clock.reset()
        XCTAssertEqual(clock.elapsed, 0)
        XCTAssertFalse(clock.isRunning)
    }
}
