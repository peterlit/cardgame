//
//  RegressionGraceForfeitConfirmTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-14:replay-forfeits-grace-silently (major, TC-14.7)
//  Verified FIXED in qa-loop 2026-09-09 round 1 (build 1a63ce2).
//
//  FIXED contract this test guards (Game.hasLiveGame, ContentView.resetConfirm*,
//  DailyView.confirm*):
//   - A ZERO-move ⏰ grace (a challenge whose Play was tapped on its own day and never
//     moved, viewed the next day) is a live game: all FOUR board-replacing controls —
//     the Daily card's Play, a "Show me how to win" pill, the board's Replay and its
//     New game — confirm before destroying it. Before the fix `hasLiveGame` was
//     `moveCount > 0`, so a 0-move grace was thrown away with no dialog.
//   - The dialogs say what is unrecoverable (the ⏰ same-day award) and SUPPRESS the
//     "your 0 moves and your time will be discarded" clause (nothing was played).
//   - Accepting the dialog really does forfeit the grace: the day card falls back to
//     "⏰ Same-day is earned on the day itself".
//   - Casual regression direction: on the resulting untouched casual board Replay and
//     New game are still one tap (no dialog).
//
//  Original repro (round-1 tester, coordinates are tester geometry — NOT a contract):
//   zero_move_save.mjs --day 13 injected; launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15
//   (stat.moves 0, hud.day 'Aug 14') → daily.play → alert; daily.demo.bronze → alert;
//   toolbar.replay → alert; toolbar.newgame → alert (4/4) → accept New game → re-open
//   daily.cal.13 → '⏰ Same-day is earned on the day itself'.
//
//  Selector notes (mined from Views/*.swift on 1a63ce2):
//   - "stat.moves", "hud.day", "toolbar.replay", "toolbar.newgame", "toolbar.daily"
//   - "daily.cal.13" (Aug 14), "daily.play", "daily.demo.bronze"
//   - the alerts have NO identifiers (SwiftUI .alert): queried by title and button
//     labels, and the bodies are asserted on purpose — the copy IS the fix.
//   - the ⏰ line on the day card has no identifier: matched by its exact text.
//
import XCTest

final class RegressionGraceForfeitConfirmTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-14:replay-forfeits-grace-silently — all four board-replacing controls must
    /// confirm on a zero-move grace, without the "your 0 moves" clause, and accepting
    /// must really forfeit the grace.
    func testAllFourBoardReplacingControlsConfirmOnAZeroMoveGrace() throws {
        // Aug 14's challenge, Play tapped on Aug 14, never moved, viewed on Aug 15 = live grace.
        let app = QA.launch(today: "2026-08-15", game: QA.zeroMoveDay13)

        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0", "fixture precondition: the grace board must be at 0 moves")
        XCTAssertEqual(app.staticTexts["hud.day"].label, "Aug 14",
                       "fixture precondition: the HUD must name Aug 14 (the grace day)")

        let keepPlaying = "Keep playing"

        // --- leg 1: the Daily card's Play -----------------------------------------
        QA.selectCalendarDay(app, 13)
        app.buttons["daily.play"].tap()
        let dailyAlert = app.alerts["End your daily attempt?"]
        XCTAssertTrue(dailyAlert.waitForExistence(timeout: 3),
                      "Daily ▸ Play re-dealt over a zero-move grace with NO dialog — the round-1 bug is back")
        XCTAssertTrue(QA.alert(dailyAlert, contains: "Starting this challenge re-deals the board. You began Aug 14's challenge on the day itself"),
                      "the Play dialog must name the grace it forfeits, got: \(QA.alertText(dailyAlert))")
        XCTAssertTrue(QA.alert(dailyAlert, contains: "Aug 14 can never earn ⏰ Same-day again"),
                      "the Play dialog must say the loss is unrecoverable, got: \(QA.alertText(dailyAlert))")
        XCTAssertFalse(QA.alert(dailyAlert, contains: "0 moves"),
                       "the zero-move suppression is gone — 'your 0 moves' is back: \(QA.alertText(dailyAlert))")
        XCTAssertTrue(dailyAlert.buttons["Start over"].exists, "the Play dialog must carry the Start over verb")
        dailyAlert.buttons[keepPlaying].tap()
        XCTAssertTrue(app.staticTexts["⏰ Resume your attempt today and it still counts"].waitForExistence(timeout: 3),
                      "Keep playing must leave the grace intact (the day card's ⏰ line changed)")

        // --- leg 2: a "Show me how to win" pill -----------------------------------
        app.buttons["daily.demo.bronze"].tap()
        XCTAssertTrue(dailyAlert.waitForExistence(timeout: 3),
                      "a demo pill re-dealt over a zero-move grace with NO dialog")
        XCTAssertTrue(QA.alert(dailyAlert, contains: "Watching a demo re-deals the board. You began Aug 14's challenge"),
                      "the demo dialog must lead with its cause, got: \(QA.alertText(dailyAlert))")
        XCTAssertFalse(QA.alert(dailyAlert, contains: "0 moves"))
        XCTAssertTrue(dailyAlert.buttons["Show demo"].exists, "the demo dialog must carry the Show demo verb")
        dailyAlert.buttons[keepPlaying].tap()
        XCTAssertTrue(QA.waitGone(dailyAlert, timeout: 3))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["toolbar.replay"].waitForExistence(timeout: 5))

        // --- leg 3: the board's Replay ---------------------------------------------
        let graceAlert = app.alerts["Give up ⏰ Same-day for Aug 14?"]
        app.buttons["toolbar.replay"].tap()
        XCTAssertTrue(graceAlert.waitForExistence(timeout: 3),
                      "Replay re-dealt over a zero-move grace with NO dialog — the round-1 bug is back")
        XCTAssertTrue(QA.alert(graceAlert, contains: "You began Aug 14's challenge on the day itself, so finishing it today still earns ⏰ Same-day."),
                      "the Replay dialog must explain the live grace, got: \(QA.alertText(graceAlert))")
        XCTAssertFalse(QA.alert(graceAlert, contains: "0 moves"),
                       "the zero-move suppression is gone on the board dialog: \(QA.alertText(graceAlert))")
        XCTAssertTrue(graceAlert.buttons["Replay"].exists, "the Replay dialog must carry the Replay verb")
        graceAlert.buttons[keepPlaying].tap()
        XCTAssertTrue(QA.waitGone(graceAlert, timeout: 3))
        XCTAssertEqual(moves.label, "0")
        XCTAssertEqual(app.staticTexts["hud.day"].label, "Aug 14", "Keep playing must not re-deal")

        // --- leg 4: New game, ACCEPTED — the grace must really be gone ------------
        app.buttons["toolbar.newgame"].tap()
        XCTAssertTrue(graceAlert.waitForExistence(timeout: 3),
                      "New game re-dealt over a zero-move grace with NO dialog")
        XCTAssertTrue(graceAlert.buttons["New game"].exists, "the New game dialog must carry its own verb")
        graceAlert.buttons["New game"].tap()
        XCTAssertTrue(QA.waitGone(graceAlert, timeout: 3))
        XCTAssertTrue(QA.waitGone(app.staticTexts["hud.day"], timeout: 3),
                      "accepting New game must leave the challenge (the HUD is still up)")

        QA.selectCalendarDay(app, 13)
        XCTAssertTrue(app.staticTexts["⏰ Same-day is earned on the day itself"].waitForExistence(timeout: 3),
                      "after forfeiting, Aug 14's card must fall back to the past-day ⏰ line")
        XCTAssertFalse(app.staticTexts["⏰ Resume your attempt today and it still counts"].exists,
                       "the grace line survived a forfeit — the model still thinks the attempt is live")
        app.buttons["Done"].tap()

        // --- TC-14.8 regression direction: the casual 0-move board stays one tap ---
        XCTAssertTrue(app.buttons["toolbar.replay"].waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "0")
        app.buttons["toolbar.replay"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2),
                       "an untouched casual board must NOT confirm Replay (hasLiveGame over-triggers)")
        app.buttons["toolbar.newgame"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2),
                       "an untouched casual board must NOT confirm New game (hasLiveGame over-triggers)")
    }
}
