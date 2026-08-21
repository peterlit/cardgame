//
//  RegressionPortraitTallColumnTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/Main:portrait-tall-column-clipped-offscreen
//  Verified FIXED in qa-loop round 1 (build 6ee255b) by TC-2.6.
//
//  FIXED contract this test guards (see .qa-loop/TESTCASES.md TC-2.6):
//   - A growing portrait column first compresses ITS OWN fan (ContentView.column);
//     when the tallest column can't fit at the legibility floor, the WHOLE board
//     shrinks ONCE to a uniform smaller card size (ContentView.portraitFitCardW +
//     shrinkLatchCount), monotone within a deal.
//   - THE core regression: the bottom card of a 15+/16-card column is always fully
//     on-screen and hit-testable. The original bug clipped it off the bottom edge
//     where it could neither be seen nor tapped.
//
//  Original repro: build one tall column in portrait; at 13–15 cards the bottom
//  cards ran off-screen (the tableau deliberately never scrolls).
//
//  Selector notes (re-mined from Views/*.swift on 5447237 — the app now ships
//  accessibility identifiers; this file was retrofitted from the raw-coordinate
//  drag script to card-identifier queries):
//   - cards:         "card.<S><rank>", S ∈ S/H/D/C, rank 1–13, e.g. "card.H10"
//                    = 10♥ (CardView; .accessibilityElement(children: .ignore),
//                    so cards match .any/.otherElements, not .buttons)
//   - toolbar pills: "toolbar.deal", "toolbar.undo" (ContentView.toolbar)
//   - header stats:  "stat.moves" — the VALUE Text carries the id (ContentView.stat)
//   - alert:         "Play a deal" / "Play" — system alert, label queries
//   - free cells:    STILL no identifier on empty SlotView slots (and none on
//                    the empty tableau strip), so two drop TARGETS below keep
//                    the TC-2.6 device-point coordinates (iPhone 17 Pro
//                    portrait) as fallbacks; follow-up filed in
//                    .qa-loop/fragments/round-2-regression.json.
//
//  Deal pinning: uses the Deal # alert with seed 10004 (the deal TC-2.6's drag
//  script was verified against — card→column mapping below is from that deal's
//  verified layout). Entering it by number does NOT touch the daily path, so
//  nothing here depends on today's date-derived daily seed.
//
import XCTest

final class RegressionPortraitTallColumnTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/Main:portrait-tall-column-clipped-offscreen — grow col 0 of deal #10004
    /// to 16 cards; the bottom card must remain on-screen and hittable (board
    /// shrinks uniformly instead of clipping).
    func testTallPortraitColumnBottomCardStaysHittable() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait   // contract is portrait-only
        app.launch()

        // --- pin deal #10004 via the Deal # alert (TC-7.1 entry path) ------------
        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(dealPill.waitForExistence(timeout: 5))
        dealPill.tap()
        XCTAssertTrue(app.alerts["Play a deal"].waitForExistence(timeout: 5))
        let field = app.alerts["Play a deal"].textFields.firstMatch
        field.tap()
        // The field opens pre-filled with the current seed — clear it first.
        let existing = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue,
                              count: existing.count + 2))
        field.typeText("10004")
        app.alerts["Play a deal"].buttons["Play"].tap()
        XCTAssertTrue(waitForStat(app, equals: "0", timeout: 5),
                      "fresh deal #10004 should start at Moves 0")

        // --- grow column 0 to 16 cards: TC-2.6's verified move list --------------
        // Sources are card identifiers (frames re-resolved per step, so the mid-
        // script board shrink can't desync the drags). Targets are the exposed
        // bottom card being stacked onto, except two coordinate fallbacks
        // (free cell 1 and column 1's strip — no identifiers; device points,
        // iPhone 17 Pro portrait: cell 1 at (274,296), column centres x = 28,
        // 77, 126, 175, 224, 272, 321, 370).
        let script: [(from: String, to: Target, what: String)] = [
            ("card.H10", .card("card.C11"),   "10♥ c6→c0 onto J♣ (col0=8)"),
            ("card.H4",  .point(274, 296),    "4♥ c7→free cell 1"),
            ("card.S9",  .card("card.H10"),   "9♠ c7→c0 (9)"),
            ("card.D11", .point(77, 600),     "J♦ c6→c1"),
            ("card.H12", .card("card.C13"),   "Q♥ c6→c7 onto K♣"),
            ("card.H8",  .card("card.S9"),    "8♥ c6→c0 (10)"),
            ("card.C7",  .card("card.H8"),    "7♣ c5→c0 (11)"),
            ("card.H6",  .card("card.C7"),    "6♥ c2→c0 (12)"),
            ("card.S8",  .card("card.H9"),    "8♠ c3→c6 onto 9♥"),
            ("card.S5",  .card("card.H6"),    "5♠ c3→c0 (13)"),
            ("card.H4",  .card("card.S5"),    "4♥ cell→c0 (14)"),
            ("card.C3",  .card("card.H4"),    "3♣ c3→c0 (15)"),
            ("card.D2",  .card("card.C3"),    "2♦ c2→c0 (16)"),
        ]
        for (i, step) in script.enumerated() {
            let source = card(app, step.from)
            XCTAssertTrue(source.waitForExistence(timeout: 3),
                          "drag \(i + 1): source \(step.from) not on the board (\(step.what))")
            let before = movesCount(app)
            source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: targetCoord(app, step.to))
            // Each scripted drag is a legal move and must count. Autoplay (on by
            // default) may add safe foundation sends on top, so assert "increased",
            // not an exact total. A non-increase means the script desynced — fail
            // loudly at the exact step.
            XCTAssertTrue(waitForMovesAbove(app, before, timeout: 3),
                          "drag \(i + 1) did not register: \(step.what)")
        }

        // --- THE core regression: the 16-card column's bottom card (2♦) is fully
        // on-screen and hit-testable. If the bug returns (card clipped off the
        // bottom edge or swallowing taps), the frame check and/or the smart-move
        // tap below fails.
        let bottomCard = card(app, "card.D2")
        XCTAssertTrue(bottomCard.exists, "2♦ vanished from the board")
        let window = app.windows.firstMatch
        XCTAssertLessThanOrEqual(bottomCard.frame.maxY, window.frame.maxY,
                                 "bottom card of the 16-card column extends past the screen edge — clipped again?")
        XCTAssertTrue(bottomCard.isHittable,
                      "bottom card of the 16-card column is not hittable")
        let beforeTap = movesCount(app)
        bottomCard.tap()   // smart-move: parks the 2♦ in a free cell
        XCTAssertTrue(waitForMovesAbove(app, beforeTap, timeout: 3),
                      "tapping the 16-card column's bottom card did nothing — clipped/untappable again?")

        // --- monotone-within-deal sanity (TC-2.6 leg d): Undo restores the tall
        // column without error, and the 2♦ lands back at the same spot (uniform
        // shrunk card size persisted — no size flip-flop on undo).
        let parkedFrame = card(app, "card.D2").frame
        XCTAssertTrue(app.buttons["toolbar.undo"].isEnabled)
        let beforeUndo = movesCount(app)
        app.buttons["toolbar.undo"].tap()
        XCTAssertTrue(waitForMovesBelow(app, beforeUndo, timeout: 3),
                      "Undo after the bottom-card tap should step the move count back")
        let restored = card(app, "card.D2").frame
        XCTAssertNotEqual(restored, parkedFrame, "Undo did not move the 2♦ back")
        XCTAssertEqual(restored.width, parkedFrame.width, accuracy: 1.0,
                       "card size changed across Undo — shrink latch is not monotone within the deal")
    }

    // MARK: - helpers

    private enum Target {
        case card(String)            // accessibility identifier of the card to stack onto
        case point(CGFloat, CGFloat) // device points (iPhone 17 Pro portrait) — no identifier exists
    }

    /// A card element by its "card.<S><rank>" identifier. Cards are flattened
    /// accessibility elements (not buttons), so query across all element types.
    private func card(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func targetCoord(_ app: XCUIApplication, _ target: Target) -> XCUICoordinate {
        switch target {
        case .card(let id):
            return card(app, id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        case .point(let x, let y):
            return app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: x, dy: y))
        }
    }

    private func movesCount(_ app: XCUIApplication) -> Int {
        Int(app.staticTexts["stat.moves"].label) ?? -1
    }

    private func waitForMovesAbove(_ app: XCUIApplication, _ n: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if movesCount(app) > n { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return movesCount(app) > n
    }

    private func waitForMovesBelow(_ app: XCUIApplication, _ n: Int, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let m = movesCount(app)
            if m >= 0 && m < n { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        let m = movesCount(app)
        return m >= 0 && m < n
    }

    private func waitForStat(_ app: XCUIApplication, equals value: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts["stat.moves"].label == value { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return app.staticTexts["stat.moves"].label == value
    }
}
