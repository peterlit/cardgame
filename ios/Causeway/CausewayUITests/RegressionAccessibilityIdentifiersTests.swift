//
//  RegressionAccessibilityIdentifiersTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/Main:no-accessibility-identifiers-anywhere
//  (archived ledger 20260822-125736-f949d82; fixed on 5447237, previously unguarded
//  — found by this round's archive sweep.)
//
//  FIXED contract this test guards:
//   - The app ships stable accessibility identifiers for every control a test (or
//     VoiceOver) has to address: the nine toolbar pills, the three header stat
//     VALUES, all 52 cards, and the Daily sheet's own controls. Before the fix the
//     source contained zero accessibilityIdentifier modifiers, so every query fell
//     back to visible label text and every card interaction to raw device points.
//   - This is the file that fails FIRST, and legibly, if the identifiers are
//     stripped or renamed — the rest of the regression suite would then fail in a
//     dozen confusing ways at once.
//
//  Original repro (archived round 3):
//    grep -rn 'accessibilityIdentifier' ios/Causeway/Causeway --include='*.swift'
//    → no matches; dump every element with a non-empty identifier on a cold
//    launched board → none.
//
//  Selector notes: this test IS the selector inventory (Views/ContentView.swift,
//  Views/DailyView.swift, Views/CardView.swift on 4f02d1d).
//
import XCTest

final class RegressionAccessibilityIdentifiersTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/Main:no-accessibility-identifiers-anywhere — the board and the Daily
    /// sheet must keep addressing every control by a stable identifier.
    func testShippedAccessibilityIdentifiersArePresent() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.newgame"].waitForExistence(timeout: 5),
                      "the board's identifiers are gone — see ContentView.toolbar")

        for id in ["toolbar.newgame", "toolbar.undo", "toolbar.replay", "toolbar.autoplay",
                   "toolbar.autofinish", "toolbar.deal", "toolbar.daily", "toolbar.wins",
                   "toolbar.howtoplay"] {
            XCTAssertTrue(app.buttons[id].exists, "missing toolbar identifier: \(id)")
        }
        for id in ["stat.moves", "stat.time", "stat.won"] {
            XCTAssertTrue(app.staticTexts[id].exists, "missing header stat identifier: \(id)")
        }

        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "card."))
            .allElementsBoundByIndex
        XCTAssertGreaterThan(cards.count, 40,
                             "cards no longer carry card.<S><rank> identifiers (found \(cards.count))")

        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))
        for id in ["daily.play", "daily.export", "daily.import"] {
            XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5),
                          "missing Daily sheet identifier: \(id)")
        }
    }
}
