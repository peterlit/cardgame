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
//  Selector notes (mined from Views/*.swift on 6ee255b): the app exposes NO
//  accessibilityIdentifier anywhere; cards are CardView/ZStack layers with no
//  stable per-card labels, so the 13-drag build-up below uses the DEVICE-POINT
//  coordinates verified in TC-2.6 — valid ONLY on an iPhone 17 Pro-class
//  simulator in portrait. Text-label queries are used everywhere one exists:
//   - "Deal #<seed>" pill, alert "Play a deal" / "Play", "Undo" (ContentView)
//   - header stats "Moves" label + value Text (ContentView.stat), read positionally.
//  A missing-identifier finding was filed (.qa-loop/fragments/round-1-regression.json).
//
//  Deal pinning: uses the Deal # alert with seed 10004 (the deal TC-2.6's drag
//  script was verified against). Entering it by number does NOT touch the daily
//  path, so nothing here depends on today's date-derived daily seed.
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
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait   // contract is portrait-only
        app.launch()

        // --- pin deal #10004 via the Deal # alert (TC-7.1 entry path) ------------
        let dealPill = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Deal #")).firstMatch
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
        XCTAssertTrue(waitForStat(app, "Moves", equals: "0", timeout: 5),
                      "fresh deal #10004 should start at Moves 0")

        // --- grow column 0 to 16 cards: TC-2.6's verified drag script ------------
        // Device points, iPhone 17 Pro portrait. Column centres x = 28, 77, 126,
        // 175, 224, 272, 321, 370; free cell 1 at (274,296); the bottom card of an
        // N-card column sits at y = 462 + 30·(N−1) pre-shrink.
        let script: [(from: (CGFloat, CGFloat), to: (CGFloat, CGFloat), what: String)] = [
            ((321, 612), (28, 600),  "10♥ c6→c0 (col0=8)"),
            ((370, 612), (274, 296), "4♥ c7→free cell 1"),
            ((370, 582), (28, 600),  "9♠ c7→c0 (9)"),
            ((321, 582), (77, 600),  "J♦ c6→c1"),
            ((321, 552), (370, 560), "Q♥ c6→c7 onto K♣"),
            ((321, 522), (28, 600),  "8♥ c6→c0 (10)"),
            ((272, 612), (28, 600),  "7♣ c5→c0 (11)"),
            ((126, 642), (28, 600),  "6♥ c2→c0 (12)"),
            ((175, 642), (321, 470), "8♠ c3→c6 onto 9♥"),
            ((175, 612), (28, 600),  "5♠ c3→c0 (13)"),
            ((274, 296), (28, 600),  "4♥ cell→c0 (14)"),
            ((175, 582), (28, 600),  "3♣ c3→c0 (15)"),
            ((126, 612), (28, 600),  "2♦ c2→c0 (16)"),
        ]
        for (i, step) in script.enumerated() {
            let before = movesCount(app)
            boardPoint(app, step.from.0, step.from.1)
                .press(forDuration: 0.05,
                       thenDragTo: boardPoint(app, step.to.0, step.to.1))
            // Each scripted drag is a legal move and must count. Autoplay (on by
            // default) may add safe foundation sends on top, so assert "increased",
            // not an exact total. A non-increase means the script desynced (wrong
            // simulator geometry?) — fail loudly at the exact step.
            XCTAssertTrue(waitForMovesAbove(app, before, timeout: 3),
                          "drag \(i + 1) did not register: \(step.what)")
        }

        // --- THE core regression: the 16-card column's bottom card is on-screen
        // and hit-testable. Post-shrink (TC-2.6 step 3) col 0 is centred at
        // x ≈ 36 and its bottom card at y ≈ 800 — comfortably above the home
        // indicator. If the bug returns (card clipped off the bottom edge or
        // swallowing taps), this tap hits nothing and Moves does not change.
        let beforeTap = movesCount(app)
        boardPoint(app, 36, 800).tap()   // smart-move: parks the 2♦ in a free cell
        XCTAssertTrue(waitForMovesAbove(app, beforeTap, timeout: 3),
                      "bottom card of the 16-card column is not hittable — clipped off-screen again?")

        // --- monotone-within-deal sanity (TC-2.6 leg d): Undo restores the tall
        // column without error. (Card-size monotonicity itself is not measurable
        // without accessibility identifiers/frames on cards — see the filed
        // missing-identifier finding.)
        XCTAssertTrue(app.buttons["Undo"].isEnabled)
        let beforeUndo = movesCount(app)
        app.buttons["Undo"].tap()
        XCTAssertTrue(waitForMovesBelow(app, beforeUndo, timeout: 3),
                      "Undo after the bottom-card tap should step the move count back")
    }

    // MARK: - helpers

    /// Reads a ContentView header stat: stat(label, value) renders two stacked
    /// Texts, so the value is the staticText immediately AFTER the label in the
    /// accessibility tree. Positional because the app has no identifiers.
    private func statValue(after label: String, in app: XCUIApplication) -> String? {
        let all = app.staticTexts.allElementsBoundByIndex
        for (i, el) in all.enumerated() where el.label == label && i + 1 < all.count {
            return all[i + 1].label
        }
        return nil
    }

    private func movesCount(_ app: XCUIApplication) -> Int {
        Int(statValue(after: "Moves", in: app) ?? "") ?? -1
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

    private func waitForStat(_ app: XCUIApplication, _ label: String,
                             equals value: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if statValue(after: label, in: app) == value { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        return statValue(after: label, in: app) == value
    }

    /// An absolute point in the app window, in device points (matches the
    /// coordinates recorded in .qa-loop/TESTCASES.md for iPhone 17 Pro portrait).
    private func boardPoint(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }
}
