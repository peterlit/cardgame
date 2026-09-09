//
//  RegressionDemoHeaderAndBannerTests.swift
//  CausewayUITests
//
//  Regression tripwires for (both fixed on 5447237 / 342e3c0, archived ledgers
//  20260822-125736-f949d82 / 20260815-233017-342e3c0; unguarded until this sweep):
//    ux/WF-6:demo-moves-counter-in-player-header (minor)
//    ux/WF-6:demo-done-leaves-empty-board        (minor)
//
//  FIXED contracts these tests guard (ContentView.header, Game.endDemo / demoDoneMessage):
//   - While a demo line is loaded — ready, stepped, auto-running, paused, AND on its
//     completion banner — the header's Moves and Time read "—" (the count is the app's,
//     not the player's, against a stopped clock). Won keeps its real value. After Stop /
//     Done the header returns to Moves 0 / Time 0:00.
//   - The completion banner reads "That's a winning line — tap Done to try it yourself."
//     and Done re-deals the SAME seed to a full, fresh tableau — not an inert solved board.
//
//  Original repros (round-1/3 testers): Daily → 🥉 Clear → Start → line to 86/86 → header
//   read 'Moves 86, Time 0:00' as if the user had played a perfect zero-second game; Done
//   left an empty, unplayable board.
//
//  Selector notes (Views/ContentView.swift, Views/DailyView.swift on 1a63ce2):
//   "toolbar.daily", "daily.demo.bronze", "demo.headline", "demo.next", "demo.start"
//   (one id for Start/Pause/Resume), "demo.stop" ↔ "demo.done" (same pill, id flips at
//   line end), "stat.moves" / "stat.time" / "stat.won" (the VALUE carries the id),
//   "toolbar.deal", "card.<S><rank>".
//
import XCTest

final class RegressionDemoHeaderAndBannerTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-6:demo-moves-counter-in-player-header — Moves/Time blank in every demo state.
    func testHeaderBlanksMovesAndTimeThroughoutADemo() throws {
        let app = QA.launch()
        let moves = app.staticTexts["stat.moves"], time = app.staticTexts["stat.time"], won = app.staticTexts["stat.won"]
        XCTAssertTrue(won.waitForExistence(timeout: 5))
        let wonBefore = won.label

        openClearDemo(app)
        XCTAssertTrue(app.buttons["demo.start"].waitForExistence(timeout: 5), "the demo bar did not open")
        XCTAssertEqual(app.buttons["demo.start"].label, "Start", "the demo must open paused/ready")
        assertBlank(moves, time, state: "ready")

        app.buttons["demo.next"].tap(); app.buttons["demo.next"].tap(); app.buttons["demo.next"].tap()
        XCTAssertTrue(QA.wait(3) { app.staticTexts["demo.headline"].label.contains("3 /") },
                      "Next did not step the line: \(app.staticTexts["demo.headline"].label)")
        assertBlank(moves, time, state: "stepped 3")

        app.buttons["demo.start"].tap()                       // Start → auto-run
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        assertBlank(moves, time, state: "auto-running")
        app.buttons["demo.start"].tap()                       // Pause
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        assertBlank(moves, time, state: "paused")
        XCTAssertEqual(won.label, wonBefore, "Won must keep its real value during a demo")

        app.buttons["demo.stop"].tap()
        XCTAssertTrue(QA.waitGone(app.buttons["demo.stop"], timeout: 5))
        XCTAssertTrue(QA.wait(3) { moves.label == "0" }, "after Stop the header must return to Moves 0, got \(moves.label)")
        XCTAssertEqual(time.label, "0:00", "after Stop the header must return to Time 0:00")
    }

    /// ux/WF-6:demo-done-leaves-empty-board — the banner's copy, and Done re-deals a full board.
    func testCompletionBannerAndDoneRedealTheSameSeedFresh() throws {
        let app = QA.launch()
        let dealPill = app.buttons["toolbar.deal"]
        openClearDemo(app)
        XCTAssertTrue(app.buttons["demo.start"].waitForExistence(timeout: 5), "the demo bar did not open")
        let demoSeed = dealPill.label

        app.buttons["demo.start"].tap()
        XCTAssertTrue(app.buttons["demo.done"].waitForExistence(timeout: 120), "the line never reached its Done banner")
        XCTAssertEqual(app.staticTexts["demo.headline"].label, "That's a winning line — tap Done to try it yourself.",
                       "the completion banner copy changed")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "—", "the banner state must still blank Moves")
        XCTAssertEqual(app.staticTexts["stat.time"].label, "—", "the banner state must still blank Time")

        app.buttons["demo.done"].tap()
        XCTAssertTrue(QA.waitGone(app.buttons["demo.done"], timeout: 5), "Done did not tear the demo bar down")
        XCTAssertTrue(QA.wait(3) { app.staticTexts["stat.moves"].label == "0" }, "Done must land on Moves 0")
        XCTAssertEqual(dealPill.label, demoSeed, "Done must re-deal the SAME seed")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled, "a fresh re-deal leaves Undo disabled")
        // A full tableau, not the inert solved board: all 52 cards are back on the table.
        XCTAssertTrue(QA.wait(3) { QA.cards(app).count > 40 },
                      "Done left an emptied board (\(QA.cards(app).count) card elements) — the inert solved board is back")
        XCTAssertFalse(app.staticTexts["You solved it! 🎉"].exists)
    }

    // MARK: - helpers

    private func openClearDemo(_ app: XCUIApplication) {
        QA.openDaily(app)
        let clear = app.buttons["daily.demo.bronze"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "no 🥉 Clear pill — no baked line for the pinned today?")
        clear.tap()
    }

    private func assertBlank(_ moves: XCUIElement, _ time: XCUIElement, state: String) {
        XCTAssertEqual(moves.label, "—", "header Moves must read '—' while the demo is \(state), got '\(moves.label)'")
        XCTAssertEqual(time.label, "—", "header Time must read '—' while the demo is \(state), got '\(time.label)'")
    }
}
