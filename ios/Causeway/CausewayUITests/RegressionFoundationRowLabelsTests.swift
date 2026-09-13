//
//  RegressionFoundationRowLabelsTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-1:foundation-rows-unlabelled (minor)
//  Fixed on 369c365 (archived ledger 20260830-155810-a937162); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (ContentView.groupLabel, SlotView.startGlyph,
//  Extras.swift RulesView "Goal"):
//   - The foundations heading names the two rows' directions: "FOUNDATIONS · A↑ / K↓"
//     (it was a bare "FOUNDATIONS" over two visually identical rows).
//   - How to play's Goal section says WHICH screen row is which: "On the board the TOP
//     foundation row is the up pile and the row beneath it is the down pile".
//   - Every EMPTY slot carries a faint A / K start glyph — that glyph is
//     accessibilityHidden by design, so this test cannot see it; the heading and the
//     rules clause are the two addressable halves of the fix.
//
//  Original repro (round-1 tester): fresh install → 'How to play' names an up pile and
//   a down pile but never says which row is which → drag A♠ to the LOWER spade slot:
//   silent snap-back, no message, no hint that the row was the wrong end.
//
//  Selector notes: "toolbar.howtoplay"; the labels are plain Text (no identifiers) and
//  are asserted by their exact copy — the copy is the fix.
//
import XCTest

final class RegressionFoundationRowLabelsTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-1:foundation-rows-unlabelled — the board and the rules must both say
    /// which foundation row builds from the Ace and which from the King.
    func testFoundationRowsAreNamedOnTheBoardAndInTheRules() throws {
        let app = QA.launch()

        XCTAssertTrue(app.staticTexts["FOUNDATIONS · A↑ / K↓"].waitForExistence(timeout: 5),
                      "the foundations heading no longer names the row directions — labels on screen: \(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "FOUNDATIONS")).allElementsBoundByIndex.map { $0.label })")
        XCTAssertTrue(app.staticTexts["FREE CELLS"].exists, "the FREE CELLS heading is gone (upper area restructured?)")

        QA.openHowToPlay(app)
        XCTAssertTrue(app.navigationBars["How to play"].waitForExistence(timeout: 5), "the rules sheet did not open")
        let clause = "On the board the TOP foundation row is the up pile and the row beneath it is the down pile"
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", clause)).firstMatch.waitForExistence(timeout: 5),
                      "How to play's Goal no longer says which screen row is which")
        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["How to play"], timeout: 3))
    }
}
