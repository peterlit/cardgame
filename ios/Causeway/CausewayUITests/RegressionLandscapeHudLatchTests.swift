//
//  RegressionLandscapeHudLatchTests.swift
//  CausewayUITests
//
//  Regression tripwires for two review-loop findings on the round-1 fix (1fa9402) that made the
//  landscape board subtract the HUD / demo bar's MEASURED height:
//    ux/ContentView.swift:hud-height-rescales-landscape-board   (major)
//    ux/ContentView.swift:hud-reserve-clamp-has-no-fallback     (minor)
//
//  FIXED contract these tests guard (Views/ContentView.swift hudBarLatchH, landscapeBarCap):
//   - The bar's measured height reaches cardW only through a per-deal, per-geometry MAXIMUM
//     latch — the landscape twin of latchedBoardH / shrinkLatchCount. Unlatched, the demo bar's
//     one-row ⇄ stacked flip (Pause adds " (paused)" and two pills; Resume takes them away)
//     rescaled all 52 cards up AND down on every flip — the pulse
//     ux/WF-12:landscape-board-rescales-every-move was fixed for the tableau's own height.
//   - The reserve is capped at what the board can give above its 150 pt floor; a taller bar
//     (🌟 Flawless headline or a catch-up day's 4-row HUD at Accessibility XXXL) is bounded and
//     scrolls inside the cap instead of pushing the rail's bottom pill and the header off-screen.
//
//  Observable: at XXXL (non-accessibility) the 🥇 Gold headline + Pause/Stop fits one row while
//  playing, and the headline + Prev/Next/Resume/Stop stacks when paused (the bar is measurably
//  taller paused). Card widths, captured once paused, are IDENTICAL while playing again, when
//  paused again and after Prev steps. At AX5, in the two tallest configurations, the rail's bottom
//  (its "more" cue or last pill), the header and Stop / the HUD stay inside the window.
//
//  Selector notes: card.<S><rank>, demo.headline, demo.start (Start/Pause/Resume), demo.next,
//  demo.prev, demo.stop, hud.day, hud.chip.gold.label, toolbar.rail.more, toolbar.howtoplay,
//  stat.moves, board.hudbar.scroll (the capped bar's ScrollView). Dynamic Type via the
//  `-UIPreferredContentSizeCategoryName` launch argument (per-launch).
//
import XCTest

final class RegressionLandscapeHudLatchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(size: String, today: String = QA.pinnedToday, game: String? = nil) -> XCUIApplication {
        let app = QA.app(today: today, game: game, autoplay: false)
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.deal"].waitForExistence(timeout: 10), "the board never appeared at \(size)")
        return app
    }

    private func rotateToLandscape(_ app: XCUIApplication) {
        let window = app.windows.firstMatch
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "rotation to landscape never took effect")
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))   // let the rotation animation settle
    }

    private func openDemo(_ app: XCUIApplication, tier: String) -> XCUIElement {
        QA.openDaily(app)
        let pill = app.buttons["daily.demo.\(tier)"]
        for _ in 0..<8 where !pill.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(pill.isHittable, "no daily.demo.\(tier) pill (never became hittable)")
        pill.tap()
        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the \(tier) demo bar did not open")
        return headline
    }

    /// Demo bar height: headline top to the lowest pill bottom, plus the bar's 8 pt vertical padding.
    private func barHeight(_ app: XCUIApplication, headline: XCUIElement) -> CGFloat {
        let h = headline.frame
        let pills = ["demo.prev", "demo.next", "demo.start", "demo.stop"].map { app.buttons[$0] }.filter { $0.exists }
        let bottom = max(h.maxY, pills.map { $0.frame.maxY }.max() ?? 0)
        return bottom + 8 - (h.minY - 8)
    }

    // MARK: - the latch

    /// hud-height-rescales-landscape-board: Pause / Resume / Pause / Prev flip the demo bar's
    /// height; the cards, sized once the bar has been at its tallest, never change.
    func testDemoBarHeightFlipsInLandscapeDoNotRescaleTheBoard() throws {
        let app = launch(size: "UICTContentSizeCategoryXXXL")
        let headline = openDemo(app, tier: "gold")
        rotateToLandscape(app)
        let start = app.buttons["demo.start"]
        XCTAssertEqual(start.label, "Start", "precondition: the demo opens ready")

        // Start, let a few moves play, Pause: the paused bar (Prev · Next · Resume · Stop and
        // " (paused)") is the deal's tallest state, and the latch records it here.
        start.tap()
        XCTAssertTrue(QA.wait(5) { !headline.label.contains("· 0 /") }, "Start did not run the line: \(headline.label)")
        start.tap()                                                        // Pause
        XCTAssertTrue(QA.wait(3) { headline.label.hasSuffix("(paused)") }, "Pause did not pause: \(headline.label)")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        let pausedBar = barHeight(app, headline: headline)
        let latched = try sizes(app)
        XCTAssertEqual(latched.count, 52, "expected all 52 cards on screen, got \(latched.count)")
        let width = latched.values.first!.width
        assertUniform(latched, width: width, state: "paused (reference)")

        // Resume: the bar drops back to one row while the line plays — the board must not grow.
        start.tap()                                                        // Resume
        XCTAssertTrue(QA.wait(3) { headline.label.hasSuffix("…") }, "Resume did not resume: \(headline.label)")
        let playingBar = barHeight(app, headline: headline)
        let playing = try sizes(app)
        start.tap()                                                        // Pause again
        XCTAssertTrue(QA.wait(3) { headline.label.hasSuffix("(paused)") }, "second Pause did not pause: \(headline.label)")
        XCTAssertGreaterThan(pausedBar, playingBar + 8,
                             "precondition: the paused bar (\(pausedBar) pt) must be taller than the playing bar (\(playingBar) pt) — the wrap flip this test relies on did not happen at XXXL")
        assertUniform(playing, width: width, state: "while playing (bar one row again)", inFlight: 3)

        // Paused again (bar tall again) and Prev steps (the move counter and the board change,
        // the bar does not): still identical. Prev, not Next: stepping FORWARD can grow a column
        // past the deal's tallest, which is the tableau's own latch (shrinkLatchCount) shrinking
        // the board once — measured at move 9 of this line, unrelated to the bar.
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        assertUniform(try sizes(app), width: width, state: "paused again")
        let prev = app.buttons["demo.prev"]
        XCTAssertTrue(prev.waitForExistence(timeout: 3), "no Prev pill while paused mid-line")
        for _ in 0..<3 { prev.tap(); RunLoop.current.run(until: Date().addingTimeInterval(0.6)) }
        XCTAssertTrue(headline.label.hasSuffix("(paused)"), "Prev left the paused state: \(headline.label)")
        assertUniform(try sizes(app), width: width, state: "after three Prev steps")

        app.buttons["demo.stop"].tap()
    }

    // MARK: - the cap

    /// hud-reserve-clamp-has-no-fallback: the 🌟 Flawless demo bar at AX5 in landscape is taller
    /// than the board can give; it is capped and scrolls, the rail and header stay on screen and
    /// Stop is reachable.
    func testFlawlessDemoBarAtAX5LandscapeIsCappedAndTheRailStaysOnScreen() throws {
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL")
        let headline = openDemo(app, tier: "flawless")
        XCTAssertTrue(headline.label.hasPrefix("🌟 Flawless:"), "precondition: the long 🌟 headline, got '\(headline.label)'")
        rotateToLandscape(app)
        assertBoardChromeOnScreen(app, state: "🌟 demo, AX5 landscape")

        // The bar is over the cap here: it must be the scrolling kind, and Stop must be reachable
        // inside it (below the fold of the capped bar, one swipe away).
        let scroll = app.scrollViews["board.hudbar.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 3),
                      "the 🌟 bar at AX5 did not fall back to the capped ScrollView — the board is overflowing again")
        let window = app.windows.firstMatch
        XCTAssertLessThanOrEqual(scroll.frame.height, window.frame.height - 150 - 72,
                                 "the capped bar (\(scroll.frame.height) pt) leaves the board less than its 150 pt floor")
        let stop = app.buttons["demo.stop"]
        if !stop.isHittable { scroll.swipeUp() }
        XCTAssertTrue(QA.wait(3) { stop.isHittable }, "Stop is not reachable inside the capped 🌟 bar")
        XCTAssertLessThanOrEqual(stop.frame.maxY, scroll.frame.maxY + 0.5, "Stop is drawn below the capped bar")
        stop.tap()
        XCTAssertTrue(QA.waitGone(headline, timeout: 3), "Stop did not end the demo")
    }

    /// hud-reserve-clamp-has-no-fallback: a catch-up day's HUD (hud.day + three chips) at AX5
    /// in landscape — the tallest HUD — keeps the rail's bottom and the header on screen.
    func testCatchUpDayHudAtAX5LandscapeKeepsTheRailOnScreen() throws {
        // Aug 14's challenge, Play tapped on Aug 14 and never moved, viewed on Aug 15: the HUD
        // names the day (hud.day) above its three objective chips.
        let app = launch(size: "UICTContentSizeCategoryAccessibilityXXXL", today: "2026-08-15", game: QA.zeroMoveDay13)
        let day = app.staticTexts["hud.day"]
        XCTAssertTrue(day.waitForExistence(timeout: 5), "fixture precondition: the HUD must name the catch-up day")
        XCTAssertEqual(day.label, "Aug 14")
        rotateToLandscape(app)
        assertBoardChromeOnScreen(app, state: "catch-up HUD, AX5 landscape")
        XCTAssertTrue(QA.wait(3) { day.exists && day.isHittable }, "landscape AX5: hud.day is not on screen")
        // This HUD is over the cap too, so it must be the SCROLLING kind — otherwise this test
        // passes identically with the cap fallback deleted and covers nothing of it
        // (tests/RegressionLandscapeHudLatchTests.swift:catchup-case-never-asserts-the-cap).
        let scroll = app.scrollViews["board.hudbar.scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 3),
                      "the catch-up HUD at AX5 landscape did not fall back to the capped ScrollView")
        XCTAssertTrue(day.frame.minY >= scroll.frame.minY - 0.5 && day.frame.maxY <= scroll.frame.maxY + 0.5,
                      "hud.day (\(day.frame)) is drawn outside the capped bar (\(scroll.frame))")
    }

    // MARK: - helpers

    /// The rail's bottom (its "more" cue when it overflows, else its last pill) and the header's
    /// Moves stat are inside the window.
    private func assertBoardChromeOnScreen(_ app: XCUIApplication, state: String) {
        let window = app.windows.firstMatch
        let cue = app.buttons["toolbar.rail.more"], last = app.buttons["toolbar.howtoplay"]
        XCTAssertTrue(QA.wait(3) { cue.exists || last.exists }, "\(state): neither the rail cue nor its last pill is on screen")
        let railBottom = cue.exists ? cue : last
        XCTAssertLessThanOrEqual(railBottom.frame.maxY, window.frame.maxY + 0.5,
                                 "\(state): the rail's bottom (\(railBottom.identifier), maxY \(railBottom.frame.maxY)) is pushed off the \(window.frame.height) pt window")
        XCTAssertTrue(railBottom.isHittable, "\(state): the rail's bottom (\(railBottom.identifier)) is not hittable")
        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(moves.exists, "\(state): the header's Moves stat is gone")
        XCTAssertGreaterThanOrEqual(moves.frame.minY, window.frame.minY - 0.5,
                                    "\(state): the header (Moves at minY \(moves.frame.minY)) is pushed off the top of the window")
    }

    /// identifier → frame size for every card.* element, from ONE accessibility snapshot: the
    /// line is playing during one capture, and per-element frame reads raced a card that moved
    /// between the query and the read ("No matches found for Element at index 47").
    private func sizes(_ app: XCUIApplication) throws -> [String: CGSize] {
        var out: [String: CGSize] = [:]
        func walk(_ node: XCUIElementSnapshot) {
            if node.identifier.hasPrefix("card.") { out[node.identifier] = node.frame.size }
            for child in node.children { walk(child) }
        }
        walk(try app.snapshot())
        return out
    }

    /// Every card must be `width` wide (±0.5 pt): one deviating card means the board rescaled.
    /// While the line is PLAYING a card or two is always mid-flight (the demo animates a move
    /// every 0.24 s; a flying card measured 111×125 at rest size 40), so that capture tolerates
    /// `inFlight` deviants — a rescale moves all 52, which still trips it.
    private func assertUniform(_ sizes: [String: CGSize], width: CGFloat, state: String, inFlight: Int = 0) {
        let off = sizes.filter { abs($0.value.width - width) > 0.5 }
        XCTAssertTrue(off.count <= inFlight,
                      "card size changed \(state): expected every card \(width) pt wide, but \(off.count) differ, e.g. "
                      + off.prefix(3).map { "\($0.key)=\($0.value.width)×\($0.value.height)" }.joined(separator: ", ")
                      + " — the landscape board rescaled with the bar")
    }
}
