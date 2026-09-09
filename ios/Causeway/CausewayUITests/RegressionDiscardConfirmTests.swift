//
//  RegressionDiscardConfirmTests.swift
//  CausewayUITests
//
//  Regression tripwires for:
//    ux/WF-3:board-reset-pills-no-confirm            (TC-3.1)
//    ux/WF-7:deal-play-discards-live-game-no-confirm (TC-7.5)
//  Both verified FIXED in qa-loop round 2 (build 4f02d1d).
//
//  FIXED contract these tests guard (ContentView.requestReset / PendingReset):
//   - New game, Replay and the Deal # alert's Play all route through ONE
//     confirmation before replacing a live board, and "Keep playing" leaves the
//     game exactly as it was.
//   - The confirm is gated on `game.hasLiveGame`: an untouched board is still
//     exactly one tap to New game. (Guarding only the destructive half is the
//     point — a blanket dialog would be a different defect.)
//
//  Original repro (round-1, coordinates are tester geometry — NOT a contract):
//   WF-3: cold launch → Daily (279,175) → Play (200,682) → tap A♥ (224,696) and
//         9♠ (370,696) → Moves 2 → tap New game (51,135) → NO dialog: a random
//         deal replaces the daily attempt, HUD gone, Undo greyed.
//   WF-7: launch → tap a card → Moves 1 → tap the Deal # pill (194,175) →
//         Select All → type 1000000 → tap Play (274,528) → OBSERVED: no
//         confirmation of any kind; the live game is simply gone.
//
//  Selector notes (mined from Views/ContentView.swift on 4f02d1d):
//   - "toolbar.newgame" / "toolbar.replay" / "toolbar.deal" / "toolbar.undo"
//   - "stat.moves" — the VALUE Text carries the id
//   - "card.<S><rank>" (CardView) — used to make a live game instead of raw taps
//   - the ALERTS have no identifiers (SwiftUI .alert): queried by their title
//     and button labels, which are asserted verbatim on purpose — the copy IS
//     the fix (it names what is lost, and whether it can be replayed).
//
import XCTest

final class RegressionDiscardConfirmTests: XCTestCase {

    private let confirmTitle = "Discard the game in progress?"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-3:board-reset-pills-no-confirm — New game and Replay must confirm
    /// before throwing a live game away, and only then.
    func testBoardResetPillsConfirmOnlyWhenAGameIsLive() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))

        // --- untouched board: New game is still ONE tap ------------------------
        let dealPill = app.buttons["toolbar.deal"]
        let seedBefore = dealPill.label
        app.buttons["toolbar.newgame"].tap()
        XCTAssertFalse(app.alerts[confirmTitle].waitForExistence(timeout: 2),
                       "an untouched board must not ask — the confirm is gated on hasLiveGame")
        XCTAssertNotEqual(dealPill.label, seedBefore, "New game did not deal a new board")

        // --- make it live ------------------------------------------------------
        XCTAssertTrue(makeOneMove(app), "could not reach Moves > 0 — no card tap moved anything")

        // --- New game now asks, and Keep playing preserves the game ------------
        let liveSeed = dealPill.label
        let liveMoves = moves.label
        app.buttons["toolbar.newgame"].tap()
        let alert = app.alerts[confirmTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                      "New game destroyed a live game with no confirmation — the round-1 bug is back")
        XCTAssertTrue(alert.buttons["New game"].exists, "the destructive action must carry its own verb")
        alert.buttons["Keep playing"].tap()
        XCTAssertEqual(dealPill.label, liveSeed, "Keep playing must not re-deal")
        XCTAssertEqual(moves.label, liveMoves, "Keep playing must not touch the board")

        // --- Replay asks too, with ITS verb ------------------------------------
        app.buttons["toolbar.replay"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3),
                      "Replay destroyed a live game with no confirmation")
        XCTAssertTrue(alert.buttons["Replay"].exists, "the Replay confirm must carry the Replay verb")
        alert.buttons["Replay"].tap()
        XCTAssertEqual(dealPill.label, liveSeed, "Replay must restart the SAME deal")
        XCTAssertEqual(moves.label, "0", "Replay must return to move 0")
    }

    /// ux/WF-7:deal-play-discards-live-game-no-confirm — the Deal # alert's Play
    /// must route through the same confirmation the board pills use.
    func testDealNumberPlayConfirmsBeforeDiscardingALiveGame() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5))
        XCTAssertTrue(makeOneMove(app), "could not reach Moves > 0 — no card tap moved anything")

        let dealPill = app.buttons["toolbar.deal"]
        let liveSeed = dealPill.label
        let liveMoves = moves.label

        dealPill.tap()
        let entry = app.alerts["Play a deal"]
        XCTAssertTrue(entry.waitForExistence(timeout: 3), "the Deal # alert did not open")
        // The field is PRE-FILLED with the current deal — clear it and type a
        // different one, so Play really is a board-replacing action.
        let field = entry.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let prefilled = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prefilled.count))
        field.typeText("10003")
        entry.buttons["Play"].tap()

        // The confirmation is raised one runloop turn later (raising it from
        // inside the dismissing alert's own action swallows it).
        let confirm = app.alerts[confirmTitle]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5),
                      "Deal ▸ Play re-dealt over a live game with no confirmation — the round-1 bug is back")
        let destructive = confirm.buttons["Play that deal"]
        XCTAssertTrue(destructive.exists, "the confirm must carry the deal-entry verb")
        // bug/WF-7:deal-confirm-swallowed-by-double-tap — the destructive action is presented
        // DISARMED for 0.5 s (a trailing tap under the finger must hit an inert button) and must
        // then arm on its own; a confirm whose only destructive action never enables would be a
        // wedged flow, not a fix.
        let armed = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: destructive)
        wait(for: [armed], timeout: 3)
        confirm.buttons["Keep playing"].tap()
        XCTAssertEqual(dealPill.label, liveSeed, "Keep playing must leave the live deal alone")
        XCTAssertEqual(moves.label, liveMoves, "Keep playing must leave the move count alone")
    }

    // MARK: - helpers

    /// Tap tableau cards (bottom-most first — those are the run heads a tap can
    /// smart-move) until the header move count leaves 0. Returns whether the
    /// board became live. Deliberately card-id driven, not coordinate driven.
    private func makeOneMove(_ app: XCUIApplication) -> Bool {
        let moves = app.staticTexts["stat.moves"]
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "card."))
            .allElementsBoundByIndex
            .sorted { $0.frame.maxY > $1.frame.maxY }
        for card in cards.prefix(16) {
            guard card.isHittable else { continue }
            card.tap()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            if moves.label != "0" && moves.label != "—" { return true }
        }
        return false
    }
}
