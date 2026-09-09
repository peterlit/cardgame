//
//  RegressionAutoFinishTierGuardTests.swift
//  CausewayUITests
//
//  Regression tripwires for (all fixed on 4f02d1d, archived ledger 20260909-085142-4f02d1d,
//  unguarded until the fixture route in QAFixtures.swift made them testable):
//    bug/WF-4:autofinish-cascade-can-deny-gold      (major)
//    bug/WF-4:autoplay-denies-daily-gold            (major)
//    ux/WF-8:autoplay-toggle-mutates-scored-game    (minor)
//
//  FIXED contracts these tests guard (Game.maybeAutoFinish / autoFinishTierCost /
//  isSafeAutoplay / autoplayOn.didSet, ContentView.requestFinish):
//   - The "Ready to finish" prompt is never offered, and Auto-finish never auto-runs, at a
//     position where the cascade would win but COST a tier the attempt can still earn. The
//     manual Finish pill is still offered there, and tapping it names the price first:
//     "Finish now and miss 🥇 Gold?" (Finish anyway / Keep playing).
//   - Auto-play's safe-send looks ahead on a scored board: it refuses a send that would kill
//     a live tier (day 29's 8♠ to the DOWN foundation used to flip Gold to ✗ with no player
//     input). The refused board stays playable and still wins flawless.
//   - Toggling the Auto-play pill changes the SETTING only — it never plays cards on the spot.
//
//  Original repros (round-1/2 testers, coordinates are tester geometry — NOT a contract):
//   WF-4 cascade: make_save with its picker relaxed to `a.won` --day 21 --tier flawless
//     --challengeDay 21 --startDay 29 → 'stop at move 64/87; finish → gold=false finalMoves=83';
//     relaunch → the app itself raised 'Ready to finish'; Finish → overlay 🥉🥈 only.
//   WF-4 autoplay: make_save --day 29 --tier flawless injected; launch (Auto-play: On) →
//     'Ready to finish' → Not yet (127,497) → Moves 92 → 94 with no user move, Gold chip ✗.
//   WF-8 toggle: day-29 save, Auto-play: Off → tap the Auto-play pill (337,135) once → the
//     label flips to On AND the board plays itself (Moves 92 → 94).
//
//  Selector notes (mined from Views/ContentView.swift, Views/DailyView.swift on 1a63ce2):
//   - "toolbar.finish" (only rendered when the board is finishable), "toolbar.autoplay"
//     (label "Auto-play: On"/"Auto-play: Off"), "stat.moves", "hud.day"
//   - HUD objective chips have NO identifier (bug/Main:scored-surfaces-addressable-only-by-copy):
//     the mark text renders as ONE static text "🥇·" / "🥇✓" / "🥇✗" (DailyView.objChip), so
//     the Gold state is read from those exact labels.
//   - alerts are SwiftUI .alert: queried by title / button label.
//
import XCTest

final class RegressionAutoFinishTierGuardTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/WF-4:autofinish-cascade-can-deny-gold — at the first cascade-winnable position
    /// of a line where the cascade would lose Gold, no prompt may fire; the manual Finish
    /// pill stays and names its price.
    func testCascadeIsNotOfferedWhereItWouldCostATier() throws {
        // Aug 22's challenge (day 21), begun Aug 30 (day 29 = today): a plain past-day replay.
        let app = QA.launch(today: "2026-08-30", game: QA.day21FirstWinnable, autoplay: false)

        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertEqual(moves.label, "64", "fixture precondition: the board must restore at move 64")
        XCTAssertEqual(app.staticTexts["hud.day"].label, "Aug 22")

        XCTAssertFalse(app.alerts["Ready to finish"].waitForExistence(timeout: 3),
                       "'Ready to finish' was offered at a position where the cascade loses Gold — the round-1 bug is back")

        let finish = app.buttons["toolbar.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3),
                      "the manual Finish pill must still be OFFERED (the guard withholds the prompt, not the affordance)")
        finish.tap()

        let cost = app.alerts["Finish now and miss 🥇 Gold?"]
        XCTAssertTrue(cost.waitForExistence(timeout: 3),
                      "Finish ran (or asked nothing) instead of naming the tier it would cost — alerts on screen: \(app.alerts.allElementsBoundByIndex.map { $0.label })")
        XCTAssertTrue(QA.alert(cost, contains: "Sending every remaining card home from here puts them on the foundations in an order this day's objective doesn't allow."),
                      "the cost dialog must explain WHY, got: \(QA.alertText(cost))")
        XCTAssertTrue(cost.buttons["Finish anyway"].exists, "the cost dialog must carry the Finish anyway verb")
        cost.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(cost, timeout: 3))
        XCTAssertEqual(moves.label, "64", "Keep playing must not cascade")
        XCTAssertFalse(QA.winOverlay(app).exists, "Keep playing must not finish the game")
    }

    /// bug/WF-4:autoplay-denies-daily-gold — Auto-play must refuse the send that would kill
    /// Gold at day 29's certified-flawless position, and the deal must still finish flawless.
    func testAutoplayRefusesASendThatWouldDenyGold() throws {
        let app = QA.launch(today: "2026-08-30", game: QA.day29Flawless, autoplay: true)   // day 29 IS today

        let prompt = app.alerts["Ready to finish"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "fixture precondition: the restore must raise 'Ready to finish'")
        prompt.buttons["Not yet"].tap()
        XCTAssertTrue(QA.waitGone(prompt, timeout: 3))

        // Give the resumed safe-autoplay chain time to act (the harmless 6♠ send still happens).
        RunLoop.current.run(until: Date().addingTimeInterval(2.5))

        XCTAssertNotEqual(app.staticTexts["hud.chip.gold"].label, "🥇✗",
                       "Auto-play killed Gold with no player input (the 8♠ went DOWN) — the round-1 bug is back")
        XCTAssertTrue(["🥇·", "🥇✓"].contains(app.staticTexts["hud.chip.gold"].label),
                      "the Gold chip is neither live nor secured — HUD chips on screen: \(marks(app))")
        let moves = Int(app.staticTexts["stat.moves"].label) ?? -1
        XCTAssertTrue((92...93).contains(moves),
                      "expected Moves 92 (no send) or 93 (the harmless 6♠ send), got \(moves) — auto-play made a scored decision")

        // The refused board is still finishable AND still wins flawless.
        let finish = app.buttons["toolbar.finish"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3), "the board must remain finishable after the refusal")
        finish.tap()
        XCTAssertTrue(QA.winOverlay(app).waitForExistence(timeout: 40),
                      "Finish did not reach the win overlay — the refusal left the board stuck (or a cost dialog blocked it: \(app.alerts.allElementsBoundByIndex.map { $0.label }))")
        XCTAssertTrue(QA.wait(5) { app.staticTexts["win.dailyline"].label == "🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak." },
                      "the deal did not finish flawless from the refused position")
    }

    /// ux/WF-8:autoplay-toggle-mutates-scored-game — flipping Auto-play On must not play a card.
    func testAutoplayToggleDoesNotPlayCardsOnTheSpot() throws {
        let app = QA.launch(today: "2026-08-30", game: QA.day29Flawless, autoplay: false)

        let prompt = app.alerts["Ready to finish"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "fixture precondition: the restore must raise 'Ready to finish'")
        prompt.buttons["Not yet"].tap()
        XCTAssertTrue(QA.waitGone(prompt, timeout: 3))

        let moves = app.staticTexts["stat.moves"]
        XCTAssertEqual(moves.label, "92", "fixture precondition: Moves 92 with Auto-play Off")
        let pill = app.buttons["toolbar.autoplay"]
        XCTAssertEqual(pill.label, "Auto-play: Off", "fixture precondition: the setting must start Off")

        pill.tap()
        XCTAssertTrue(QA.wait(3) { pill.label == "Auto-play: On" }, "the pill did not flip to On")
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        XCTAssertEqual(moves.label, "92",
                       "turning Auto-play On played cards on the spot (Moves left 92) — the round-1 bug is back")
        XCTAssertNotEqual(app.staticTexts["hud.chip.gold"].label, "🥇✗", "the toggle cost the Gold tier")
    }

    // MARK: - helpers

    private func marks(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND NOT identifier ENDSWITH %@", "hud.chip.", ".label"))
            .allElementsBoundByIndex.map { $0.label }.joined(separator: " ")
    }
}
