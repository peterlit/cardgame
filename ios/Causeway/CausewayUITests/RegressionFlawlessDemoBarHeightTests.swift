//
//  RegressionFlawlessDemoBarHeightTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-15:flawless-demo-banner-eats-quarter-screen   (TC-15.1, minor)
//  Verified FIXED in qa-loop round 3 (build de5e5d0).
//
//  FIXED contract this test guards (Views/ContentView.swift demoBar — ViewThatFits):
//   - When the demo headline no longer fits on one line beside its pills, it takes the
//     FULL bar width above a trailing pill row. Before the fix the pills kept their row
//     in a plain HStack and the headline was squeezed into whatever was left: the 🌟
//     headline (which names all three objectives since round 1) wrapped 16 lines in a
//     95 pt column, and paused mid-line on Aug 14 the bar stood 224 pt tall — 26% of the
//     874 pt screen — while the same day's 🥇 bar was 89 pt. On de5e5d0 the headline is
//     366 pt wide (3 lines, 59 pt) in every demo state and the bar is 108 pt.
//
//  Original repro (round 2, QADriver):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-14; tapid toolbar.daily; tapid daily.demo.flawless
//      -> find demo.headline frame 18,250,166,104 (3 pills)
//    tapid demo.start; sleep 8; tapid demo.start (Pause)
//      -> find demo.headline frame 18,250,95,224 — 95 pt wide column, banner y 250-474
//    Round 3: frame 18,250,366,59 before Start and unchanged when paused; bar 108 pt.
//
//  The clock is pinned to 2026-08-14 (index 13), the day the finding measured. The paused
//  mid-line state is reached the repro's way — Start, a short run, Pause — because Next
//  alone never marks the line started and its headline carries no "(paused)" suffix (the
//  4-pill paused set is Prev · Next · Resume · Stop either way). Selector notes:
//  daily.demo.flawless, demo.headline, demo.next, demo.prev, demo.start, demo.stop are
//  real identifiers; widths are asserted relative to the window, heights as bounds.
//
import XCTest

final class RegressionFlawlessDemoBarHeightTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-15:flawless-demo-banner-eats-quarter-screen — the 🌟 headline keeps the full
    /// bar width and the bar stays a fraction of its former height, before Start and
    /// paused mid-line.
    func testFlawlessDemoHeadlineKeepsFullWidthAndTheBarStaysShort() throws {
        let app = QA.launch(today: "2026-08-14")
        let window = app.windows.firstMatch
        let width = window.frame.width
        QA.openDaily(app)
        let flawless = app.buttons["daily.demo.flawless"]
        XCTAssertTrue(flawless.waitForExistence(timeout: 5), "the pinned Aug 14 ships no 🌟 demo pill")
        flawless.tap()

        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the demo bar did not open")
        XCTAssertTrue(headline.label.hasPrefix("🌟 Flawless:") && headline.label.contains("(🥈"),
                      "precondition: the 🌟 headline must be the long objectives-bearing one, got '\(headline.label)'")
        assertBar(app, headline: headline, width: width, state: "before Start")

        // Paused mid-line, the repro's path: Start, let it run a moment, Pause. (Next alone
        // steps the line without marking it started, so its headline carries no "(paused)".)
        let start = app.buttons["demo.start"]
        XCTAssertEqual(start.label, "Start", "precondition: the demo opens ready")
        start.tap()
        XCTAssertTrue(QA.wait(5) { !headline.label.contains("· 0 /") }, "Start did not run the line: \(headline.label)")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        start.tap()                                                        // Pause
        XCTAssertTrue(QA.wait(3) { headline.label.hasSuffix("(paused)") },
                      "Pause did not leave the line in its paused state: \(headline.label)")
        XCTAssertTrue(app.buttons["demo.prev"].exists && app.buttons["demo.start"].exists,
                      "the paused pill set (Prev / Resume) is missing")
        assertBar(app, headline: headline, width: width, state: "paused mid-line")

        app.buttons["demo.stop"].tap()
    }

    // MARK: - helpers

    private func assertBar(_ app: XCUIApplication, headline: XCUIElement, width: CGFloat, state: String) {
        let h = headline.frame
        XCTAssertGreaterThan(h.width, width * 0.75,
                             "\(state): the 🌟 headline is squeezed into a \(h.width) pt column of a \(width) pt window — the pills took its row again")
        XCTAssertLessThan(h.height, 90,
                          "\(state): the 🌟 headline wraps to \(h.height) pt tall — a narrow column again")
        // The bar spans headline top to the lowest pill bottom, plus its 8 pt vertical padding.
        let pills = ["demo.prev", "demo.next", "demo.start", "demo.stop"].map { app.buttons[$0] }.filter { $0.exists }
        XCTAssertFalse(pills.isEmpty, "\(state): no demo pills found")
        let bottom = max(h.maxY, pills.map { $0.frame.maxY }.max() ?? 0)
        let barH = bottom + 8 - (h.minY - 8)
        XCTAssertLessThan(barH, 150,
                          "\(state): the demo bar is \(barH) pt tall (was 224 pt on 9ab79f1, 108 pt fixed)")
        for pill in pills {
            XCTAssertTrue(pill.isHittable, "\(state): \(pill.identifier) lost hittability in the stacked bar")
            XCTAssertGreaterThanOrEqual(pill.frame.minY, h.minY - 1,
                                        "\(state): \(pill.identifier) sits above the headline")
        }
    }
}
