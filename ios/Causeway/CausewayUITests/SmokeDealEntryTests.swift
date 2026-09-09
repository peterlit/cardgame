//
//  SmokeDealEntryTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversions of the [smoke] cases in .qa-loop/TESTCASES.md
//  (qa-loop 2026-09-09, round 1):
//    TC-7.1 Open, type, play an exact deal (+ the won ✓ suffix)
//    TC-7.5 Replacing a LIVE game asks first, from both routes, and survives a double-tap
//           (regression guard for bug/WF-7:deal-confirm-swallowed-by-double-tap —
//           ContentView.requestDealFromDismissal still hops the confirm 0.1 s off the
//           runloop; this is what proves the second tap never leaks through)
//
//  Determinism: wins seeded through the launch-argument route (QAFixtures.swift); the live
//  game is deal #500001's A♦ tap with Auto-play pinned OFF.
//
//  Selector notes: "toolbar.deal", "toolbar.wins", "stat.moves", "card.D1"; the Deal #
//  alert and the confirm are SwiftUI .alert (title/buttons); the Wins field/Play carry no
//  identifiers (bug/Main:scored-surfaces-addressable-only-by-copy).
//
import XCTest

final class SmokeDealEntryTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-7.1 — open + type + Play loads the exact deal at Moves 0 with no alert left; a
    /// won deal's pill carries a trailing ✓.
    func testTC7_1_TypeAndPlayAnExactDeal() throws {
        let app = QA.launch(wins: #"{"539885":{"moves":90,"secs":120,"date":808012800}}"#)
        let dealPill = app.buttons["toolbar.deal"], moves = app.staticTexts["stat.moves"]

        QA.dealSeed(app, 500001)
        XCTAssertTrue(QA.wait(5) { dealPill.label == "Deal #500001" }, "deal pill is '\(dealPill.label)', expected 'Deal #500001'")
        XCTAssertEqual(moves.label, "0")
        XCTAssertFalse(app.alerts.firstMatch.exists, "an alert was left on screen after Play")

        QA.dealSeed(app, 539885)
        XCTAssertTrue(QA.wait(5) { dealPill.label == "Deal #539885 ✓" }, "a won deal's pill must carry ' ✓', got '\(dealPill.label)'")
        XCTAssertEqual(moves.label, "0")
    }

    /// TC-7.5 — a double-tap on Play (Deal # alert) and on the Wins Play leaves the
    /// confirmation on screen and INTACT, with the live deal and move count untouched.
    func testTC7_5_DoubleTapOnPlayLeavesTheConfirmIntact() throws {
        let app = QA.launch(autoplay: false)
        let dealPill = app.buttons["toolbar.deal"], moves = app.staticTexts["stat.moves"]
        QA.dealSeed(app, 500001)
        XCTAssertTrue(QA.wait(5) { dealPill.label == "Deal #500001" })
        XCTAssertEqual(QA.tapCard(app, "card.D1"), "1", "could not make the board live (A♦ tap)")
        let confirm = app.alerts["Discard the game in progress?"]

        // Route A — the Deal # alert's Play, double-tapped.
        dealPill.tap()
        let entry = app.alerts["Play a deal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        let field = entry.textFields.firstMatch
        field.tap()
        let prefilled = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prefilled.count))
        field.typeText("500002")
        let entryPlayY = entry.buttons["Play"].frame.midY   // measured BEFORE the alert dismisses
        entry.buttons["Play"].doubleTap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(confirm.exists, "route A: no confirmation after a double-tap on Play (swallowed, dismissed, or never raised)")
        XCTAssertTrue(confirm.buttons["Keep playing"].exists && confirm.buttons["Play that deal"].exists, "route A: confirm buttons wrong")
        XCTAssertEqual(dealPill.label, "Deal #500001", "route A: the second tap leaked through and re-dealt")
        XCTAssertEqual(moves.label, "1", "route A: the live game was touched")
        XCTAssertGreaterThan(abs(confirm.buttons["Play that deal"].frame.midY - entryPlayY), 60,
                             "route A: the confirm's action sits where the finger just was")
        confirm.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(confirm, timeout: 3))

        // Route B — the Wins screen's Play, double-tapped.
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5))
        let winsField = app.textFields.firstMatch
        winsField.tap()
        winsField.typeText("500003")
        let winsPlayY = app.buttons["Play"].frame.midY
        app.buttons["Play"].doubleTap()
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(confirm.exists, "route B: no confirmation after a double-tap on the Wins Play")
        XCTAssertEqual(moves.label, "1", "route B: the live game was touched")
        XCTAssertGreaterThan(abs(confirm.buttons["Play that deal"].frame.midY - winsPlayY), 60,
                             "route B: the confirm's action sits where the finger just was")
        confirm.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(confirm, timeout: 3))
        XCTAssertTrue(dealPill.waitForExistence(timeout: 3))
        XCTAssertEqual(dealPill.label, "Deal #500001", "route B: the second tap leaked through and re-dealt")
        XCTAssertEqual(moves.label, "1")
    }
}
