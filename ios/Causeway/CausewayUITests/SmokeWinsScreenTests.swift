//
//  SmokeWinsScreenTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversions of the [smoke] cases in .qa-loop/TESTCASES.md
//  (qa-loop 2026-09-09, round 1):
//    TC-9.1 Wins empty state
//    TC-9.4 Playing from Wins over a live game asks first (both routes)
//
//  Determinism: the wins store is seeded through the launch-argument route
//  (QAFixtures.swift) — empty for TC-9.1, exactly {500001} for TC-9.4 — and the live game
//  is deal #500001's A♦ tap (Auto-play pinned OFF), so "Your 1 move" is exact.
//
//  Selector notes: "toolbar.wins", "toolbar.deal", "stat.moves"; the Wins "Play a deal"
//  TextField and its Play button, the range chip and the deal rows have NO identifiers
//  (bug/Main:scored-surfaces-addressable-only-by-copy) — the field is the sheet's only
//  text field, the chip is a text labelled with the range ("500001") and the row a button
//  whose label begins "Deal #500001". The confirm is SwiftUI .alert (title/buttons).
//
import XCTest

final class SmokeWinsScreenTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-9.1 — "Deals won", an empty Play a deal row with Play disabled, the empty-state
    /// line, and Done back to the board.
    func testTC9_1_WinsEmptyState() throws {
        let app = QA.launch()
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5), "the Wins sheet did not open")
        XCTAssertTrue(app.staticTexts["Play a deal"].exists, "the Play a deal row is missing")
        let field = app.textFields["wins.dealentry.field"]
        XCTAssertTrue(field.exists, "the deal-entry field is missing")
        XCTAssertEqual((field.value as? String) ?? "", "Number 1–1,000,000", "the empty field should show its range placeholder, got '\(field.value ?? "")'")
        let play = app.buttons["wins.dealentry.play"]
        XCTAssertTrue(play.exists, "the Play button is missing")
        XCTAssertFalse(play.isEnabled, "Play must be disabled while the field is empty")
        XCTAssertTrue(app.staticTexts["No wins yet — go solve one!"].exists, "the empty-state line is missing")
        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["Deals won"], timeout: 3), "Done did not dismiss the sheet")
        XCTAssertTrue(app.buttons["toolbar.deal"].isHittable)
    }

    /// TC-9.4 — both Wins routes (typed deal, range ▸ row) confirm over a live game; Keep
    /// playing preserves it exactly, Play that deal loads the chosen deal at Moves 0.
    func testTC9_4_PlayingFromWinsOverALiveGameAsksFirst() throws {
        let app = QA.launch(wins: #"{"500001":{"moves":90,"secs":120,"date":808012800}}"#, autoplay: false)
        QA.dealSeed(app, 700001)
        let dealPill = app.buttons["toolbar.deal"], moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #700001") })
        XCTAssertTrue(QA.makeOneMove(app), "could not make a move on deal #700001")
        let liveMoves = moves.label
        let confirmTitle = "Discard the game in progress?"
        let body = "Your \(liveMoves) move\(liveMoves == "1" ? "" : "s") and your time will be discarded. This game is not a challenge, so there is no way back to it."

        // (a) typed deal → Play
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5))
        let field = app.textFields["wins.dealentry.field"]
        field.tap()
        field.typeText("500001")
        app.buttons["wins.dealentry.play"].tap()
        let confirm = app.alerts[confirmTitle]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Wins ▸ Play replaced a live game with no confirmation")
        XCTAssertTrue(QA.alert(confirm, contains: body), "confirm body wrong, got: \(QA.alertText(confirm))")
        XCTAssertTrue(confirm.buttons["Play that deal"].exists, "the confirm must carry the Play that deal verb")
        confirm.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(confirm, timeout: 3))
        XCTAssertTrue(dealPill.waitForExistence(timeout: 3))
        XCTAssertTrue(dealPill.label.hasPrefix("Deal #700001"), "Keep playing must return to the live deal")
        XCTAssertEqual(moves.label, liveMoves, "Keep playing must preserve Moves exactly")

        // (b) range chip → row → Play that deal
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5))
        let chip = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "500001")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 3), "no range chip for the seeded win")
        chip.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Deal #500001")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the range detail did not list Deal #500001")
        row.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Wins ▸ row replaced a live game with no confirmation")
        // bug/WF-7:deal-confirm-swallowed-by-double-tap (fixed 42b5f7e): a confirm raised from a
        // dismissing sheet/alert presents its destructive action DISARMED for 0.5 s so a trailing
        // tap under the finger hits an inert button. Tapping inside that window leaves the alert
        // up (seen once in the round-2 whole-target run), so wait for it to arm — and a button
        // that never arms is a wedged flow, which this wait also catches.
        let playThatDeal = confirm.buttons["Play that deal"]
        let armed = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: playThatDeal)
        wait(for: [armed], timeout: 3)
        playThatDeal.tap()
        XCTAssertTrue(QA.waitGone(confirm, timeout: 3), "Play that deal was tapped while armed but the confirm stayed up")
        XCTAssertTrue(QA.wait(5) { dealPill.label == "Deal #500001 ✓" }, "Play that deal did not load #500001 (with its ✓): \(dealPill.label)")
        XCTAssertEqual(moves.label, "0", "the chosen deal must start at Moves 0")
    }
}
