//
//  RegressionPluralGrammarTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-11:singular-plural-grammar (minor)
//  Fixed on 342e3c0 (archived ledger 20260815-233017-342e3c0); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (WinsView's count line):
//   - "1 deal solved · 1 range" inflects for exactly one; "2 deals solved · 2 ranges"
//     still pluralises, so the fix is not a blanket singularisation. (The other reported
//     site, DailyView.importStats' note after a Files import, needs the system document
//     picker and is NOT covered here — see the summary.)
//
//  Original repro (round-1 tester): a backup holding exactly 1 day + 1 deal → Import →
//   the note and the Wins count line read "1 deals" / "1 ranges".
//
//  Selector notes: "toolbar.wins"; the count line is a plain Text (no identifier,
//  bug/Main:scored-surfaces-addressable-only-by-copy) matched by its exact copy.
//  Wins are seeded through the launch-argument route (QAFixtures.swift): WinRecord is
//  {moves, secs, date} with `date` as seconds since 2001 (JSONEncoder's default).
//
import XCTest

final class RegressionPluralGrammarTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-11:singular-plural-grammar — one win reads singular, two non-adjacent wins plural.
    func testWinsCountLineInflectsForOneAndForMany() throws {
        let oneWin = #"{"500001":{"moves":90,"secs":120,"date":808012800}}"#
        var app = QA.launch(wins: oneWin)
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5), "the Wins sheet did not open")
        XCTAssertTrue(app.staticTexts["1 deal solved · 1 range"].waitForExistence(timeout: 3),
                      "the singular count line is wrong — on screen: \(countLines(app))")
        XCTAssertFalse(app.staticTexts["1 deals solved · 1 ranges"].exists, "the round-1 '1 deals · 1 ranges' is back")
        app.terminate()

        let twoWins = #"{"500001":{"moves":90,"secs":120,"date":808012800},"700001":{"moves":95,"secs":130,"date":808012800}}"#
        app = QA.launch(wins: twoWins)
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 deals solved · 2 ranges"].waitForExistence(timeout: 3),
                      "the plural count line is wrong (blanket singularisation?) — on screen: \(countLines(app))")
    }

    private func countLines(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "solved")).allElementsBoundByIndex
            .map { $0.label }.joined(separator: " | ")
    }
}
