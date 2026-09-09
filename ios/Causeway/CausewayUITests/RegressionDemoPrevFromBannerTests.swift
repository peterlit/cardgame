//
//  RegressionDemoPrevFromBannerTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-6:demo-has-no-step-back   (TC-6.2, minor)
//  Verified FIXED in qa-loop round 3 (build de5e5d0) — the round-2 residual (no Prev on
//  the completion banner) is closed; the mid-line Prev landed in round 2.
//
//  FIXED contract this test guards (Views/ContentView.swift demoPills, Game.demoCanStepBack /
//  demoStepBack):
//   - The demo bar offers a "Prev" pill (demo.prev) while paused mid-line AND on the
//     completion banner. From the banner ("That's a winning line — tap Done to try it
//     yourself.", pills Prev + Done) one tap re-enters the PAUSED demo at N-1 with the
//     full paused pill set (Prev · Next · Resume · Stop); Next brings the banner back.
//     Prev is a re-simulation, never an Undo: the header stays "—" and Undo stays
//     disabled. Before the fix the banner showed Done alone, so re-watching the line's
//     last move cost five taps (Done, Daily, the pill, Start, a timed Pause).
//
//  Original repro (round 2/3, QADriver):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15; tapid toolbar.daily; tapid daily.demo.bronze
//    tapid demo.next x3 -> demo.prev appears; tapid demo.prev x3 -> 0, Prev disappears
//    let the line run to 100/100 -> headline "That's a winning line — tap Done to try it
//      yourself.", labels buttons shows ONLY demo.done; find demo.prev -> exists=false  (residual)
//    Round 3: banner = demo.prev + demo.done; tapid demo.prev -> 'Winning line · 99 / 100
//      (paused)', Prev/Next/Resume/Stop, Undo disabled; tapid demo.next -> banner restored.
//
//  Selector notes: daily.demo.bronze, demo.headline, demo.next, demo.prev, demo.start (one
//  id for Start/Pause/Resume), demo.stop ↔ demo.done (same pill, id flips at line end),
//  toolbar.undo, stat.moves are real identifiers. The line length is read from the
//  headline ("Winning line · 0 / N"), not hard-coded.
//
import XCTest

final class RegressionDemoPrevFromBannerTests: XCTestCase {

    private let bannerCopy = "That's a winning line — tap Done to try it yourself."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-6:demo-has-no-step-back — Prev is offered mid-line and from the completion
    /// banner, and from the banner it re-enters the paused demo at N-1.
    func testPrevIsOfferedMidLineAndFromTheCompletionBanner() throws {
        let app = QA.launch()
        QA.openDaily(app)
        let clear = app.buttons["daily.demo.bronze"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "no 🥉 Clear pill on the pinned Aug 15")
        clear.tap()

        let headline = app.staticTexts["demo.headline"]
        let prev = app.buttons["demo.prev"], next = app.buttons["demo.next"]
        let start = app.buttons["demo.start"], done = app.buttons["demo.done"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the demo bar did not open")
        // "Winning line · 0 / N" — N is the line length.
        let parts = headline.label.components(separatedBy: " / ")
        let total = Int(parts.last?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
        XCTAssertGreaterThan(total, 10, "could not read the line length from '\(headline.label)'")
        XCTAssertFalse(prev.exists, "Prev must not be offered at move 0 — nothing to step back to")

        // --- mid-line: Next x3, then Prev x3 back to 0 (the round-2 half of the contract) ----
        for _ in 0..<3 { next.tap() }
        XCTAssertTrue(QA.wait(3) { headline.label.contains(" 3 / \(total)") },
                      "Next did not step the line to 3: \(headline.label)")
        XCTAssertTrue(prev.exists, "Prev is missing while paused mid-line at 3 / \(total)")
        prev.tap()
        XCTAssertTrue(QA.wait(3) { headline.label.contains(" 2 / \(total)") },
                      "Prev did not step back to 2: \(headline.label)")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled, "Prev must not touch history — Undo stays disabled")

        // --- run the line to its banner ------------------------------------------------------
        start.tap()                                                   // Resume → auto-run
        XCTAssertTrue(done.waitForExistence(timeout: 120), "the line never reached its Done banner")
        XCTAssertEqual(headline.label, bannerCopy, "the completion banner copy changed")
        XCTAssertTrue(prev.waitForExistence(timeout: 3),
                      "the completion banner offers Done alone — Prev is gone from the banner again (the round-2 residual)")
        XCTAssertTrue(prev.isHittable, "banner Prev is not hittable")
        XCTAssertFalse(next.exists, "the banner must not show Next")

        // --- Prev from the banner re-enters the PAUSED demo at N-1 ---------------------------
        prev.tap()
        XCTAssertTrue(QA.wait(3) { headline.label == "Winning line · \(total - 1) / \(total) (paused)" },
                      "Prev from the banner did not re-enter the paused demo at \(total - 1) / \(total): '\(headline.label)'")
        XCTAssertTrue(next.exists, "the paused pill set after banner-Prev lacks Next")
        XCTAssertEqual(start.label, "Resume", "the paused pill set after banner-Prev must offer Resume, got '\(start.label)'")
        XCTAssertTrue(app.buttons["demo.stop"].exists, "the paused pill set after banner-Prev lacks Stop")
        XCTAssertFalse(done.exists, "Done must leave with the banner")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled, "re-entering the demo must not enable Undo")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "—", "the re-entered demo must still blank Moves")

        // --- Next restores the banner; Done still lands on a fresh board ----------------------
        next.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Next from \(total - 1) did not bring the banner back")
        XCTAssertEqual(headline.label, bannerCopy)
        XCTAssertTrue(prev.exists, "the restored banner lost its Prev")
        done.tap()
        XCTAssertTrue(QA.waitGone(done, timeout: 5), "Done did not tear the demo bar down")
        XCTAssertTrue(QA.wait(3) { app.staticTexts["stat.moves"].label == "0" }, "Done must land on Moves 0")
    }
}
