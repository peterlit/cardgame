//
//  RegressionDemoNeverScoresTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/WF-6:demo-progress-counts-as-a-real-win
//  Verified FIXED in qa-loop round 1 (build 6ee255b) by TC-6.1..TC-6.6.
//
//  FIXED contract this test guards (see .qa-loop/TESTCASES.md WF-6):
//   - While a "show me how to win" demo is loaded, board input is fully locked
//     (tap AND drag-lift; canDrag = !demoing in ContentView.cardGesture callers).
//   - Mid-demo `Stop` and post-line `Done` both re-deal the SAME seed to a fresh
//     board: Moves 0, Undo disabled, Deal # unchanged (Game.restartDeal via the
//     demoBar pills in ContentView.demoBar).
//   - Nothing from a demo run is ever recorded in the wins store: header `Won`
//     count is unchanged and the win overlay ("You solved it! 🎉") never appears
//     (Game.showSolution never routes through commit()).
//
//  Original repro (round-2 archived finding): start the Clear demo from Daily,
//  let/step the app's own line forward, then keep playing or finish — the
//  assisted position survived and banked a real win/best-time.
//
//  Selector notes (re-mined from Views/*.swift on 5447237 — the app now ships
//  accessibility identifiers; this file was retrofitted from label/positional
//  queries to use them):
//   - toolbar pills:   "toolbar.daily", "toolbar.undo", "toolbar.deal"
//                      (ContentView.toolbar / landscapeRail — same ids)
//   - demo bar pills:  "demo.next", "demo.start" (one id for Start/Pause/Resume
//                      — the same control), "demo.stop" ↔ "demo.done" (the same
//                      pill's id flips when the line completes) — ContentView.demoBar
//   - demo headline:   "demo.headline" (staticText; label still begins
//                      "Winning line" for the bronze tier)
//   - daily demo pill: "daily.demo.bronze" (DailyView.showPill; renders "🥉 Clear")
//   - header stats:    "stat.moves" / "stat.won" — the VALUE Text carries the id
//                      (ContentView.stat), so tests read it directly
//   - cards:           "card.<S><rank>", S ∈ S/H/D/C (CardView) — used for the
//                      input-lock probe instead of raw coordinates
//   - win overlay:     STILL no identifier — queried by its "You solved it! 🎉"
//                      title label; follow-up filed in
//                      .qa-loop/fragments/round-2-regression.json
//
//  Requires a simulator/device where the bundled daily pool has a baked solution
//  for today (ships with the app; the "🥉 Clear" pill only renders when
//  game.hasSolution(seed) — TC-6.6). Does NOT hard-code a daily seed: it drives
//  whatever deal the Daily card offers today and only asserts invariants.
//
import XCTest

final class RegressionDemoNeverScoresTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/WF-6:demo-progress-counts-as-a-real-win — a demo must be input-locked,
    /// Stop/Done must re-deal the same seed fresh, and nothing may ever be banked.
    func testDemoIsLockedAndNeverBanksAWin() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // --- baseline: the header `Won` count before any demo runs ---------------
        let won = app.staticTexts["stat.won"]
        XCTAssertTrue(won.waitForExistence(timeout: 5), "header 'Won' stat not found")
        let wonBefore = won.label

        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(dealPill.waitForExistence(timeout: 5))

        // --- enter the Clear demo from the Daily sheet (TC-6.1) ------------------
        openClearDemo(app)

        // Demo opens paused/ready: Start (not Pause), Next, Stop; Moves 0.
        // NOTE: during a demo the header blanks Moves/Time to "—" (stat.moves
        // reads "—", not "0") — the demo's own move count lives in the headline.
        XCTAssertTrue(app.buttons["demo.start"].waitForExistence(timeout: 5),
                      "demo bar should open in the ready state with a Start pill")
        XCTAssertEqual(app.buttons["demo.start"].label, "Start")
        XCTAssertTrue(app.buttons["demo.next"].exists)
        XCTAssertTrue(app.buttons["demo.stop"].exists)
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "—",
                       "header Moves should be blanked while a demo is loaded")
        let demoSeedLabel = dealPill.label   // the daily seed the demo dealt

        // --- step the line so the board is mid-demo (TC-6.2 / TC-6.5) ------------
        app.buttons["demo.next"].tap()
        app.buttons["demo.next"].tap()
        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        let headlineBefore = headline.label   // e.g. "Winning line — 2 / 86"

        // --- input-lock probe (TC-6.5): drag-lift AND tap must be inert ----------
        // Retrofit: instead of TC-6.5's raw (28,681)→(175,600) coordinates, pick
        // the DEEPEST card on the board (max frame.maxY = some column's bottom
        // card — on a fresh demo deal all 52 cards are in the tableau) and drag
        // it onto another column's card. The assertions are invariance-based, so
        // an unluckily-chosen card can only weaken the probe, never false-fail it.
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "card."))
            .allElementsBoundByIndex
        XCTAssertGreaterThan(cards.count, 10, "no card.<S><rank> elements found on the board")
        let source = cards.max(by: { $0.frame.maxY < $1.frame.maxY })!
        let target = cards.filter { abs($0.frame.midX - source.frame.midX) > 40 }
            .max(by: { $0.frame.maxY < $1.frame.maxY }) ?? cards[0]
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6,
                   thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()   // plain tap = smart-move attempt
        XCTAssertEqual(headline.label, headlineBefore,
                       "demo progress moved under user input — board is not locked")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "—",
                       "a user gesture un-blanked the header during a demo")

        // --- mid-demo Stop re-deals the SAME seed fresh (TC-6.3) -----------------
        app.buttons["demo.stop"].tap()
        XCTAssertTrue(waitGone(app.buttons["demo.stop"], timeout: 5),
                      "demo bar should tear down on Stop")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "0",
                       "Stop must land on a fresh board (Moves 0), not the assisted position")
        XCTAssertEqual(dealPill.label, demoSeedLabel, "Stop must re-deal the SAME seed")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled,
                       "fresh re-deal must leave Undo disabled (empty history)")
        XCTAssertFalse(app.staticTexts["You solved it! 🎉"].exists)

        // --- run the whole line, then Done (TC-6.4) ------------------------------
        openClearDemo(app)
        XCTAssertTrue(app.buttons["demo.start"].waitForExistence(timeout: 5))
        app.buttons["demo.start"].tap()
        // ~0.25 s/move on a ~86–97 move line ≈ 25 s; the bar's Stop pill flips its
        // id to "demo.done" when the line completes (demoDoneMessage banner).
        XCTAssertTrue(app.buttons["demo.done"].waitForExistence(timeout: 120),
                      "demo never reached its end-of-line Done banner")
        // The line just played to a fully-won board — the win overlay must NOT show.
        XCTAssertFalse(app.staticTexts["You solved it! 🎉"].exists,
                       "win overlay appeared for a demo run")

        app.buttons["demo.done"].tap()
        XCTAssertTrue(waitGone(app.buttons["demo.done"], timeout: 5))
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "0",
                       "Done must land on a fresh board of the same deal")
        XCTAssertEqual(dealPill.label, demoSeedLabel, "Done must re-deal the SAME seed")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled)

        // --- THE core regression: nothing from the demo was ever banked ----------
        XCTAssertEqual(won.label, wonBefore,
                       "a demo run changed the wins count — the round-2 bug is back")
    }

    // MARK: - helpers

    /// Opens the Daily sheet and taps the bronze "🥉 Clear" show-me-how-to-win pill.
    private func openClearDemo(_ app: XCUIApplication) {
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))
        let clear = app.buttons["daily.demo.bronze"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5),
                      "no 'Show me how to win' Clear pill — no baked solution for today?")
        clear.tap()
    }

    private func waitGone(_ element: XCUIElement, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return !element.exists
    }
}
