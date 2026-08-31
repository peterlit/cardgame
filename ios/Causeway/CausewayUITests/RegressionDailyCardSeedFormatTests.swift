//
//  RegressionDailyCardSeedFormatTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/WF-13:daily-card-seed-grouped
//  Verified FIXED in qa-loop round 2 (build 4f02d1d) by TC-13.1.
//
//  FIXED contract this test guards:
//   - A deal number is an IDENTIFIER, not a quantity: every surface prints it
//     ungrouped. The Daily day-card printed "Deal #691,039" (SwiftUI interpolates
//     Int through LocalizedStringKey and groups the digits) while the board pill
//     and every Wins surface printed "Deal #691039", so the same deal read as two
//     different deals. The card now goes through DealFormat.seed.
//
//  Original repro (round-1, coordinates are tester geometry — NOT a contract):
//    launch → Daily (270,172) → swipe to the calendar → tap Aug 1 (358,472) →
//    scroll the day card into view → card reads "Deal #691,039"; the board pill
//    and the Wins chips read "691039".
//
//  Selector notes (mined from Views/*.swift on 4f02d1d):
//   - "toolbar.deal" (real identifier; label "Deal #<seed>" + " ✓" when won)
//   - the day card's deal label is plain Text with no identifier — matched by
//     its "Deal #" prefix. Follow-up filed in
//     .qa-loop/fragments/round-2-regression.json.
//
import XCTest

final class RegressionDailyCardSeedFormatTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/WF-13:daily-card-seed-grouped — every "Deal #" on the Daily sheet must
    /// print the seed ungrouped, exactly as the board pill identifies it.
    func testDailyCardPrintsTheDealNumberUngrouped() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))

        let labels = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Deal #"))
            .allElementsBoundByIndex
            .map(\.label)
        XCTAssertFalse(labels.isEmpty, "no 'Deal #' label on the Daily sheet")

        for label in labels {
            let digits = label.dropFirst("Deal #".count)
            XCTAssertTrue(digits.allSatisfy(\.isNumber),
                          "the Daily card is formatting the deal number as a quantity again: '\(label)' — the board pill prints it ungrouped")
        }
    }
}
