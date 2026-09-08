import XCTest
@testable import Causeway

/// R9 (skeptical review): elapsed time is a MEASUREMENT, not a count of timer deliveries. The old
/// clock did `elapsed += 1` per delivery, so a stalled main thread undercounted — the review's
/// probe recorded 1 second for 2.26 blocked seconds. These tests block the run loop on purpose:
/// no timer fires, and the measurement must be right anyway.
final class GameClockTests: XCTestCase {

    func testBlockedRunLoopStillMeasuresWallTime() {
        let clock = GameClock()
        clock.start()
        Thread.sleep(forTimeInterval: 2.3)   // no run loop service — zero timer deliveries
        clock.stop()
        XCTAssertGreaterThanOrEqual(clock.elapsed, 2,
            "2.3 blocked seconds must record as at least 2 — delivery-counting recorded 1")
        XCTAssertLessThanOrEqual(clock.elapsed, 3, "and not wildly more")
    }

    func testSetSeedsTheMeasurementAcrossRestore() {
        let clock = GameClock()
        clock.set(41)
        XCTAssertEqual(clock.elapsed, 41)
        clock.start()
        Thread.sleep(forTimeInterval: 1.1)
        clock.stop()
        XCTAssertGreaterThanOrEqual(clock.elapsed, 42, "restored seconds + the new stretch must add")
    }

    func testBackgroundPauseFreezesAndResumeContinues() {
        let clock = GameClock()
        clock.start()
        Thread.sleep(forTimeInterval: 1.1)
        clock.pauseForBackground()
        let atPause = clock.elapsed
        XCTAssertFalse(clock.isRunning)
        Thread.sleep(forTimeInterval: 1.2)   // "backgrounded" — must not count
        XCTAssertEqual(clock.elapsed, atPause, "background time is not play time")
        clock.resumeFromBackground()
        XCTAssertTrue(clock.isRunning)
        clock.stop()
        XCTAssertLessThanOrEqual(clock.elapsed, atPause + 1,
            "the paused stretch leaked into the measurement")
    }

    func testResumeDoesNotRestartAClockTheGameStopped() {
        let clock = GameClock()
        clock.start()
        clock.stop()                    // a win/reset stopped it — not backgrounding
        clock.resumeFromBackground()
        XCTAssertFalse(clock.isRunning,
            "coming foreground must not restart a clock the game itself stopped")
    }

    func testResetZeroesEverything() {
        let clock = GameClock()
        clock.set(30)
        clock.start()
        clock.reset()
        XCTAssertEqual(clock.elapsed, 0)
        XCTAssertFalse(clock.isRunning)
    }
}
