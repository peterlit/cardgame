//
//  RegressionDailySheetConfirmsDemoTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-6:demo-discards-daily-attempt-without-warning (major)
//  Fixed on 5447237 (archived ledger 20260822-125736-f949d82); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (DailyView.confirm* / pending):
//   - A "Show me how to win" pill tapped while a daily attempt is in progress raises
//     "End your daily attempt?" (Keep playing / Show demo), whose body names the cause
//     ("Watching a demo re-deals the board") and the cost ("your N move(s) and your time
//     will be discarded"). Keep playing preserves the attempt exactly; Show demo proceeds
//     to the demo bar on a re-dealt board.
//
//  Original repro (round-1 tester, coordinates are tester geometry — NOT a contract):
//   Daily → Play (deal #10,005) → two card taps → Moves 2 → Daily → 🥉 Clear pill →
//   board silently at Moves 0, Undo disabled, demo bar replacing the HUD.
//
//  Selector notes: "toolbar.daily", "daily.play", "daily.demo.bronze", "stat.moves",
//  "toolbar.deal", "demo.start"; the alert is SwiftUI .alert (title/button labels).
//  Auto-play is pinned OFF so the move count is exactly the taps this test makes.
//
import XCTest

final class RegressionDailySheetConfirmsDemoTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-6:demo-discards-daily-attempt-without-warning — a demo pill must confirm over
    /// a live daily attempt, and Keep playing must preserve it.
    func testDemoPillConfirmsBeforeEndingALiveDailyAttempt() throws {
        let app = QA.launch(autoplay: false)

        // Start today's challenge (untouched casual board → no confirm here).
        QA.openDaily(app)
        app.buttons["daily.play"].tap()
        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #608530") }, "today's challenge (deal #608530) did not load: \(dealPill.label)")
        XCTAssertTrue(QA.makeOneMove(app), "could not make a move on the daily board")
        let moves = app.staticTexts["stat.moves"]
        let liveMoves = moves.label

        QA.openDaily(app)
        app.buttons["daily.demo.bronze"].tap()
        let alert = app.alerts["End your daily attempt?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                      "a demo pill re-dealt over a live daily attempt with NO confirmation — the round-1 bug is back")
        XCTAssertTrue(QA.alert(alert, contains: "Watching a demo re-deals the board, so your \(liveMoves) move"),
                      "the dialog must name the cause and the cost, got: \(QA.alertText(alert))")
        XCTAssertTrue(QA.alert(alert, contains: "You can replay the challenge afterwards."),
                      "the daily-specific promise is missing, got: \(QA.alertText(alert))")
        XCTAssertTrue(alert.buttons["Show demo"].exists, "the dialog must carry the Show demo verb")
        alert.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(alert, timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["Daily Challenges"], timeout: 3))
        XCTAssertEqual(moves.label, liveMoves, "Keep playing must leave the attempt exactly as it was")
        XCTAssertTrue(app.buttons["toolbar.undo"].isEnabled, "Keep playing must keep the undo history")
        XCTAssertFalse(app.buttons["demo.start"].exists, "Keep playing must not open the demo bar")

        // Show demo proceeds, by design, to the demo on a re-dealt board.
        QA.openDaily(app)
        app.buttons["daily.demo.bronze"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Show demo"].tap()
        XCTAssertTrue(app.buttons["demo.start"].waitForExistence(timeout: 5), "Show demo did not open the demo bar")
        XCTAssertEqual(moves.label, "—", "the demo must blank the header (the attempt is gone)")
    }
}
