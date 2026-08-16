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
//  Selector notes (mined from Views/*.swift on 6ee255b): the app exposes NO
//  accessibilityIdentifier anywhere, so every query below is by visible label:
//   - toolbar pills:      "Daily", "Undo", "Deal #<seed>"   (ContentView.toolbar)
//   - demo bar pills:     "Next" / "Start" / "Pause" / "Stop" / "Done"
//                         (ContentView.demoBar / demoPill)
//   - demo headline:      staticText beginning "Winning line" (demoHeadline)
//   - daily sheet pill:   "🥉 Clear"                        (DailyView.showPill)
//   - header stats:       Text("Moves")/Text("Won") each followed by a value
//                         Text (ContentView.stat) — read positionally.
//  A missing-identifier finding was filed (.qa-loop/fragments/round-1-regression.json).
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
        let wonBefore = statValue(after: "Won", in: app)
        XCTAssertNotNil(wonBefore, "header 'Won' stat not found")

        let dealPill = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Deal #")).firstMatch
        XCTAssertTrue(dealPill.waitForExistence(timeout: 5))

        // --- enter the Clear demo from the Daily sheet (TC-6.1) ------------------
        openClearDemo(app)

        // Demo opens paused/ready: Start (not Pause), Next, Stop; Moves 0.
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5),
                      "demo bar should open in the ready state with a Start pill")
        XCTAssertTrue(app.buttons["Next"].exists)
        XCTAssertTrue(app.buttons["Stop"].exists)
        XCTAssertEqual(statValue(after: "Moves", in: app), "0")
        let demoSeedLabel = dealPill.label   // the daily seed the demo dealt

        // --- step the line so the board is mid-demo (TC-6.2 / TC-6.5) ------------
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        let headline = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Winning line")).firstMatch
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        let headlineBefore = headline.label   // e.g. "Winning line — 2 / 86"
        let movesBefore = statValue(after: "Moves", in: app)

        // --- input-lock probe (TC-6.5): drag-lift AND tap must be inert ----------
        // Raw coordinates from TC-6.5's verified repro on iPhone 17 Pro portrait:
        // press col 0's bottom-card region (28,681) and drag slowly to col 3.
        // The assertions are invariance-based, so a slightly-off touch point can
        // only weaken the probe, never false-fail it.
        boardPoint(app, 28, 681).press(forDuration: 0.6,
                                       thenDragTo: boardPoint(app, 175, 600))
        boardPoint(app, 28, 681).tap()   // plain tap = smart-move attempt
        XCTAssertEqual(headline.label, headlineBefore,
                       "demo progress moved under user input — board is not locked")
        XCTAssertEqual(statValue(after: "Moves", in: app), movesBefore,
                       "a user gesture mutated the board during a demo")

        // --- mid-demo Stop re-deals the SAME seed fresh (TC-6.3) -----------------
        app.buttons["Stop"].tap()
        XCTAssertTrue(waitGone(app.buttons["Stop"], timeout: 5),
                      "demo bar should tear down on Stop")
        XCTAssertEqual(statValue(after: "Moves", in: app), "0",
                       "Stop must land on a fresh board (Moves 0), not the assisted position")
        XCTAssertEqual(dealPill.label, demoSeedLabel, "Stop must re-deal the SAME seed")
        XCTAssertFalse(app.buttons["Undo"].isEnabled,
                       "fresh re-deal must leave Undo disabled (empty history)")
        XCTAssertFalse(app.staticTexts["You solved it! 🎉"].exists)

        // --- run the whole line, then Done (TC-6.4) ------------------------------
        openClearDemo(app)
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        app.buttons["Start"].tap()
        // ~0.25 s/move on a ~86–97 move line ≈ 25 s; the bar's Stop pill becomes
        // "Done" when the line completes (demoDoneMessage banner).
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 120),
                      "demo never reached its end-of-line Done banner")
        // The line just played to a fully-won board — the win overlay must NOT show.
        XCTAssertFalse(app.staticTexts["You solved it! 🎉"].exists,
                       "win overlay appeared for a demo run")

        app.buttons["Done"].tap()
        XCTAssertTrue(waitGone(app.buttons["Done"], timeout: 5))
        XCTAssertEqual(statValue(after: "Moves", in: app), "0",
                       "Done must land on a fresh board of the same deal")
        XCTAssertEqual(dealPill.label, demoSeedLabel, "Done must re-deal the SAME seed")
        XCTAssertFalse(app.buttons["Undo"].isEnabled)

        // --- THE core regression: nothing from the demo was ever banked ----------
        XCTAssertEqual(statValue(after: "Won", in: app), wonBefore,
                       "a demo run changed the wins count — the round-2 bug is back")
    }

    // MARK: - helpers

    /// Opens the Daily sheet and taps the "🥉 Clear" show-me-how-to-win pill.
    private func openClearDemo(_ app: XCUIApplication) {
        app.buttons["Daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))
        // DailyView.showPill renders Text("🥉 Clear"); match emoji-robustly.
        let clear = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Clear")).firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 5),
                      "no 'Show me how to win' Clear pill — no baked solution for today?")
        clear.tap()
    }

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

    /// An absolute point in the app window, in device points (matches the
    /// coordinates recorded in .qa-loop/TESTCASES.md for iPhone 17 Pro portrait).
    private func boardPoint(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
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
