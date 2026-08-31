//
//  RegressionDemoExitRebindsDayTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-6:demo-exit-drops-challenge-binding
//  Verified FIXED in qa-loop round 2 (build 4f02d1d) by TC-6.4. fix_risk: metric-integrity.
//
//  FIXED contract this test guards (Game.endDemo):
//   - Leaving a demo that was opened from a PLAYABLE day's card (Stop mid-line
//     or Done at the end) re-binds THAT day's challenge — the board comes back
//     with the daily objectives HUD, so "try it yourself" banks a tier.
//   - It re-binds as a BRAND-NEW attempt: endDemo routes through
//     playChallenge → deal(), which zeroes the board, clock, move count and
//     telemetry, so none of the demo's own moves can ever be inherited.
//
//  Why this matters more than it looks: before the fix every demo exit landed
//  the player on a CASUAL deal of the day's seed. The banner invites a real
//  attempt, the attempt was unscored, and nothing on screen said so — a silent
//  metric-integrity hole (a whole solved day banking no medal).
//
//  Original repro (round-1/round-2, coordinates are tester geometry — NOT a contract):
//    cold launch → Daily (280,175) → tap the "🥉 Clear" how-to-win pill (115,747)
//    → Next (236,263) → Stop (357,263)  [same via Start → line completes → Done]
//    → OBSERVED: fresh deal #551879, Moves 0, Undo disabled, and the three-line
//    objectives HUD is GONE — casual play on the daily seed.
//
//  Selector notes (mined from Views/*.swift on 4f02d1d):
//   - "toolbar.daily" / "toolbar.deal" / "toolbar.undo" / "stat.moves"
//   - "daily.demo.bronze" (DailyView.showPill — renders "🥉 Clear")
//   - "demo.next" / "demo.stop" (ContentView.demoBar)
//   - the daily HUD chips have NO identifier: presence is probed by the bronze
//     chip's verbatim label "Clear the deal" (DailyView.chips). `hud.day` only
//     renders for a day that is NOT today, so it cannot serve here. Follow-up
//     (recommend "hud.objectives") filed in
//     .qa-loop/fragments/round-2-regression.json.
//
//  Precondition: today's daily must have a baked bronze solution (the "🥉 Clear"
//  pill only renders when game.hasSolution(seed)) — skipped if it does not.
//
import XCTest

final class RegressionDemoExitRebindsDayTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-6:demo-exit-drops-challenge-binding — Stop must land on the day's
    /// SCORED challenge, fresh, not on a casual deal of its seed.
    func testDemoStopLandsOnTheScoredChallengeNotACasualDeal() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))

        let clear = app.buttons["daily.demo.bronze"]
        try XCTSkipUnless(clear.waitForExistence(timeout: 5),
                          "today's daily has no baked bronze solution — no demo to leave")
        clear.tap()

        // Mid-demo: step the app's own line so the board is demo-touched.
        XCTAssertTrue(app.buttons["demo.next"].waitForExistence(timeout: 5),
                      "demo bar did not open")
        let dealPill = app.buttons["toolbar.deal"]
        let demoSeed = dealPill.label
        app.buttons["demo.next"].tap()
        app.buttons["demo.next"].tap()

        // --- leave the demo ----------------------------------------------------
        app.buttons["demo.stop"].tap()

        // --- THE regression: the day must still be bound -----------------------
        let bronzeChip = app.staticTexts["Clear the deal"]
        XCTAssertTrue(bronzeChip.waitForExistence(timeout: 5),
                      "no daily objectives HUD after leaving the demo — the exit dropped the challenge binding (round-1 bug is back)")
        XCTAssertEqual(dealPill.label, demoSeed, "the exit must stay on the day's own deal")

        // --- ...and it must be a FRESH attempt, never the demo's position ------
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "0",
                       "the re-bound attempt must start at move 0 — the demo's moves may never be inherited")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled,
                       "a fresh attempt must have an empty undo history")
    }
}
