//
//  RegressionLandscapeDealAlertTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-12:deal-alert-actions-hidden-in-landscape (major)
//  Fixed on 5447237 (archived ledger 20260822-125736-f949d82); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (ContentView's "Play a deal" alert):
//   - The alert has exactly TWO actions, Cancel and Play, laid out side by side, so in
//     landscape — where the auto-raised number pad eats ~170 pt of a 402 pt height —
//     both are visible without scrolling. Before the fix a third action ("Random")
//     stacked the buttons vertically and pushed Random/Cancel below the visible alert
//     behind the keypad, leaving destructive Play as the only visible exit.
//
//  Original repro (round-1 tester, coordinates are tester geometry — NOT a contract):
//   launch fresh → rotate landscape → tap the 'Deal #…' rail pill (127,232) → the alert
//   showed 'Play' as the only visible button; tapping outside did not dismiss it.
//
//  Selector notes: "toolbar.deal" (the same id in the landscape rail); the alert is
//  SwiftUI .alert, queried by its title "Play a deal" and button labels.
//
import XCTest

final class RegressionLandscapeDealAlertTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// ux/WF-12:deal-alert-actions-hidden-in-landscape — Cancel must be visible and
    /// hittable next to Play in landscape, with no third action.
    func testLandscapeDealAlertShowsCancelBesidePlay() throws {
        let app = QA.launch()

        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "rotation to landscape never took effect")

        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(dealPill.waitForExistence(timeout: 5), "no toolbar.deal pill in the landscape rail")
        let seedBefore = dealPill.label
        dealPill.tap()

        let alert = app.alerts["Play a deal"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3), "the Deal # alert did not open")
        XCTAssertTrue(alert.textFields.firstMatch.waitForExistence(timeout: 3), "the alert lost its number field")

        let cancel = alert.buttons["Cancel"]
        let play = alert.buttons["Play"]
        XCTAssertTrue(play.exists, "the alert lost its Play action")
        XCTAssertTrue(cancel.exists, "the alert lost its Cancel action")
        XCTAssertTrue(cancel.isHittable,
                      "Cancel is on the alert but NOT hittable in landscape — it is hidden behind the keypad again")
        XCTAssertTrue(play.isHittable, "Play is not hittable in landscape")
        XCTAssertEqual(alert.buttons.count, 2,
                       "the alert must carry exactly Cancel + Play (a third action stacks them vertically and hides the exits): \(alert.buttons.allElementsBoundByIndex.map { $0.label })")
        // Side by side, not stacked: both actions share a row inside the visible window.
        XCTAssertLessThan(abs(cancel.frame.midY - play.frame.midY), 4,
                          "Cancel and Play are not on one row (Cancel y \(cancel.frame.midY), Play y \(play.frame.midY))")
        XCTAssertTrue(window.frame.contains(cancel.frame), "Cancel lies outside the visible window")

        cancel.tap()
        XCTAssertTrue(QA.waitGone(alert, timeout: 3), "Cancel did not dismiss the alert")
        XCTAssertEqual(dealPill.label, seedBefore, "Cancel must not change the deal")
    }
}
