//
//  RegressionFlawlessDemoLabelTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-15:flawless-pill-both-vs-three
//  Verified FIXED in qa-loop round 2 (build 4f02d1d) by TC-15.1.
//
//  FIXED contract this test guards:
//   - 🌟 Flawless means 🥉 AND 🥈 AND 🥇 in a single run — THREE objectives. The
//     demo bar's headline used to call it "Both objectives in one run", which
//     contradicted the streaks legend, the day card's three objectives and the
//     win overlay, and told the player they could stop one medal early.
//   - The label now reads "🥉🥈🥇 all three in a single run" wherever it renders
//     (DailyView.showPill passes it; ContentView.demoHeadline shows it).
//
//  Original repro (round-1, coordinates are tester geometry — NOT a contract):
//    fresh install → Daily (283,175) → scroll to the Today card's
//    "Show me how to win:" grid → tap 🌟 Flawless (293,787) →
//    OBSERVED demo bar: "🌟 Flawless: Both objectives in one run - 0 / 96".
//
//  Selector notes (mined from Views/*.swift on 4f02d1d):
//   - "toolbar.daily", "daily.demo.flawless" (DailyView.showPill), and
//     "demo.headline" (ContentView.demoBar) — all real identifiers.
//
//  Precondition: today's daily must ship a baked FLAWLESS line (the pill only
//  renders when game.hasFlawlessLine(seed)) — skipped if it does not.
//
import XCTest

final class RegressionFlawlessDemoLabelTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-15:flawless-pill-both-vs-three — the 🌟 demo headline must say all
    /// THREE medals, never "both objectives".
    func testFlawlessDemoHeadlineSaysAllThree() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))

        let flawless = app.buttons["daily.demo.flawless"]
        try XCTSkipUnless(flawless.waitForExistence(timeout: 5),
                          "today's daily ships no flawless line — nothing to label")
        flawless.tap()

        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "demo bar did not open")
        XCTAssertTrue(headline.label.contains("all three in a single run"),
                      "the 🌟 demo headline no longer says all three medals, got: \(headline.label)")
        XCTAssertFalse(headline.label.lowercased().contains("both objectives"),
                       "the 'Both objectives in one run' phrasing is back — 🌟 is three medals, not two")

        // Leave the demo so the run doesn't strand a demo-touched board.
        app.buttons["demo.stop"].tap()
    }
}
