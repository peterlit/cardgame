//
//  RegressionFlawlessDemoHeadlineObjectivesTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-15:flawless-demo-headline-omits-objectives   (TC-15.1, minor)
//  Verified FIXED in qa-loop round 2 (app 42b5f7e).
//
//  FIXED contract this test guards (Views/DailyView.swift flawlessDemoLabel,
//  Views/ContentView.swift demoHeadline):
//   - The 🌟 demo headline names the tier definition PLUS the day's two objectives,
//     "(🥈 <silver>; 🥇 <gold>)", so a ~100-move Flawless demo no longer runs with
//     nothing on screen naming the constraints it is honouring — the 🥈 / 🥇 demos
//     already spelled theirs out. Parentheses + semicolon on purpose (several objective
//     labels embed an em dash of their own).
//
//  Original repro (round 1, QADriver):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15; tapid toolbar.daily;
//    tapid daily.demo.flawless → find demo.headline ==
//      '🌟 Flawless: 🥉🥈🥇 all three in a single run · 0 / 98'   (no objectives)
//    while daily.demo.silver read '🥈 Silver: Never move more than 2 cards in a single
//    move · 0 / 100'.
//
//  THE CLOCK IS PINNED to 2026-08-15 (Aug 15: 🥈 max-run 2, 🥇 ten of every suit from
//  the King end, flawless line 98 moves, silver line 100). The board is a fresh 0-move
//  deal, so the demo pills never raise the discard confirm. Selector notes:
//  daily.demo.<tier> / demo.headline / demo.stop are real identifiers.
//
import XCTest

final class RegressionFlawlessDemoHeadlineObjectivesTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-15:flawless-demo-headline-omits-objectives — the 🌟 headline spells out
    /// both objectives, exactly, and the 🥈 headline is unchanged.
    func testFlawlessDemoHeadlineNamesBothObjectives() throws {
        let app = QA.launch()
        QA.openDaily(app)
        let flawless = app.buttons["daily.demo.flawless"]
        XCTAssertTrue(flawless.waitForExistence(timeout: 5),
                      "the pinned Aug 15 ships no 🌟 demo pill — the day lost its flawless line")
        flawless.tap()

        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the demo bar did not open")
        let expected = "🌟 Flawless: 🥉🥈🥇 all three in a single run "
            + "(🥈 Never move more than 2 cards in a single move; 🥇 Take at least 10 of every suit from the King end)"
            + " · 0 / 98"
        XCTAssertTrue(QA.wait(3) { headline.label == expected },
                      "the 🌟 demo headline no longer names the day's objectives — expected\n\(expected)\ngot\n\(headline.label)")
        app.buttons["demo.stop"].tap()

        // The paired contract: the 🥈 demo still names its own objective the same way.
        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        QA.openDaily(app)
        app.buttons["daily.demo.silver"].tap()
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the 🥈 demo bar did not open")
        XCTAssertTrue(QA.wait(3) { headline.label == "🥈 Silver: Never move more than 2 cards in a single move · 0 / 100" },
                      "the 🥈 demo headline changed: \(headline.label)")
        app.buttons["demo.stop"].tap()
    }
}
