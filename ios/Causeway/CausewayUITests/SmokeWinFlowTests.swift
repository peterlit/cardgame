//
//  SmokeWinFlowTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversions of the [smoke] cases in .qa-loop/TESTCASES.md that need an
//  INJECTED save (qa-loop 2026-09-09, round 1) — reachable now through the launch-argument
//  route documented in QAFixtures.swift:
//    TC-4.1  Auto-finish "Ask" prompts on restore, then completes to the win overlay
//    TC-14.3 / TC-15.3  Winning TODAY mints ⏰ / 🌟 on the overlay, the streak cards and
//            the day card (one flawless run lights every surface in agreement)
//    TC-5.4  The clears line: counts, INDEPENDENT minima, and par
//
//  Determinism: every number below is the harness's prediction for the fixture
//  (make_save.mjs prints "finish → won … finalMoves=N") and derive_daily.py's par:
//    day 14 silver   → 97 moves, 🥉🥈, deal #608530 (par 87)
//    day 13 flawless → 79 moves, 🌟, deal #720307 (par 78)
//    day 2 bronze    → 96 moves, 🥉 only, deal #539885 (par 86)
//  Deal numbers on the overlay are UNGROUPED (DealFormat.seed; bug/WF-4:win-overlay-seed-grouped,
//  fixed 42b5f7e) — a grouped "Deal #608,530" on the overlay is that bug back.
//  Time readouts are NOT asserted exactly (the cascade's wall time varies): TC-5.4 seeds
//  the prior run as 200 moves in 0:30 so "fewest" (96, run 2) and "fastest" (0:30, run 1)
//  provably come from DIFFERENT runs, and both are exact.
//
//  NOT converted from TC-14.3/15.3: the calendar cell's 🌟 marker and the date baseline
//  jitter — the cell's accessibility label is just "Aug 14" (children combined) and the
//  marker is pixel-only, so there is no non-pixel handle; the streak cards, day card and
//  clears line are asserted instead.
//
//  Selector notes: "stat.won", "toolbar.deal", "toolbar.daily", "daily.cal.<idx>",
//  "daily.clears" (TWO elements share it on a multi-run day — matched by identifier, not
//  `find`); overlay / streak-card / day-card texts are copy-matched (no identifiers:
//  bug/Main:scored-surfaces-addressable-only-by-copy).
//
import XCTest

final class SmokeWinFlowTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-4.1 — the restored silver save prompts, Finish cascades to the overlay with the
    /// predicted numbers, Won becomes 1 and the deal pill gains its ✓.
    func testTC4_1_AutoFinishAskPromptsOnRestoreThenCompletesToTheOverlay() throws {
        let app = QA.launch(today: "2026-08-15", game: QA.day14Silver)
        QA.finishFromPrompt(app)   // asserts the prompt title/body and the "You solved it! 🎉" overlay

        let deal = app.staticTexts["win.dealline"]
        XCTAssertTrue(deal.waitForExistence(timeout: 3) && deal.label.hasPrefix("Deal #608530 · 97 moves · "),
                      "overlay deal line is not 'Deal #608530 · 97 moves · M:SS' (ungrouped) — texts: \(texts(app))")
        XCTAssertEqual(app.staticTexts["win.dailyline"].label, "Daily challenge: 🥉 🥈 earned. ⏰ On time — 1-day same-day streak.",
                       "overlay daily line is wrong — texts: \(texts(app))")
        for (id, label) in [("win.play", "Play deal #608531"), ("win.random", "Random"), ("win.close", "Close")] {
            XCTAssertTrue(app.buttons[id].exists, "overlay button missing: \(id)")
            XCTAssertEqual(app.buttons[id].label, label, "overlay button \(id) is mislabelled")
        }
        XCTAssertEqual(app.staticTexts["stat.won"].label, "1", "the header Won count did not become 1")
        XCTAssertEqual(app.buttons["toolbar.deal"].label, "Deal #608530 ✓", "the deal pill did not gain its won ✓")
    }

    /// TC-14.3 + TC-15.3 — a flawless win TODAY: unprefixed overlay line, every streak card
    /// at 1/1/1, the day card headed Today 🌟 Flawless with "⏰ Cleared on the day" and a
    /// clears line carrying par.
    func testTC14_3_WinningTodayMintsOnTimeAndFlawlessOnEverySurface() throws {
        let app = QA.launch(today: "2026-08-14", game: QA.day13Flawless)   // day 13 IS today
        QA.finishFromPrompt(app)

        let deal2 = app.staticTexts["win.dealline"]
        XCTAssertTrue(deal2.waitForExistence(timeout: 3) && deal2.label.hasPrefix("Deal #720307 · 79 moves · "),
                      "overlay deal line is not 'Deal #720307 · 79 moves · M:SS' (ungrouped) — texts: \(texts(app))")
        XCTAssertEqual(app.staticTexts["win.dailyline"].label, "🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak.",
                       "overlay flawless/on-time line wrong — texts: \(texts(app))")
        app.buttons["win.close"].tap()
        XCTAssertTrue(QA.waitGone(QA.winOverlay(app), timeout: 3))

        QA.openDaily(app)
        for card in ["Play", "Same-day", "Silver", "Gold", "Flawless"] {
            let label = "\(card): current streak 1 days, 1 days total, best 1 days"
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch.waitForExistence(timeout: 3),
                          "streak card not minted: '\(label)' — cards: \(streakCards(app))")
        }
        XCTAssertTrue(app.staticTexts["Today"].exists, "the day card is not headed Today")
        XCTAssertTrue(app.staticTexts["🌟 Flawless"].exists, "the day card lost its 🌟 Flawless badge")
        XCTAssertTrue(app.staticTexts["⏰ Cleared on the day"].exists, "the ⏰ line did not switch to 'Cleared on the day'")
        let clears = app.staticTexts["daily.clears"]
        XCTAssertTrue(clears.exists, "no daily.clears line after a clear")
        XCTAssertTrue(clears.label.hasPrefix("Cleared · fewest 79 moves · fastest ") && clears.label.hasSuffix(" · par 78"),
                      "clears line wrong: \(clears.label)")
    }

    /// TC-5.4 — after a second, worse run the clears line counts 2×, reports INDEPENDENT
    /// minima, keeps par, lists both runs — and the banked Gold is still ticked.
    func testTC5_4_ClearsLineCountsIndependentMinimaAndPar() throws {
        // Run 1 (seeded): Aug 3 cleared once with 🥉🥈🥇 in 200 moves / 0:30.
        let priorDaily = #"{"version":3,"days":{"2":{"bronze":true,"silver":true,"gold":true,"flawless":false,"onTime":false,"moves":200,"elapsed":30,"runs":[{"moves":200,"elapsed":30}]}}}"#
        let app = QA.launch(today: "2026-08-15", game: QA.day2Bronze, daily: priorDaily)
        QA.finishFromPrompt(app)   // run 2: 96 moves, bronze only, a past-day replay
        let daily2 = app.staticTexts["win.dailyline"]
        XCTAssertTrue(daily2.waitForExistence(timeout: 3) && daily2.label == "Aug 3: Daily challenge: 🥉 earned.",
                      "run 2 should score bronze only for Aug 3 — texts: \(texts(app))")
        app.buttons["win.close"].tap()
        XCTAssertTrue(QA.waitGone(QA.winOverlay(app), timeout: 3))

        QA.selectCalendarDay(app, 2)
        let lines = app.staticTexts.matching(identifier: "daily.clears").allElementsBoundByIndex.map { $0.label }
        XCTAssertEqual(lines.count, 2, "expected TWO daily.clears elements on a two-run day, got \(lines)")
        XCTAssertTrue(lines.contains("Cleared 2× · fewest 96 moves · fastest 0:30 · par 86"),
                      "count / independent minima / par line wrong: \(lines)")
        XCTAssertTrue(lines.contains("Moves each run: 200 · 96"), "per-run list wrong: \(lines)")
        // A banked medal is never un-earned by a later, worse run: the seeded Gold still shows.
        XCTAssertTrue(app.staticTexts["Aug 3"].exists)
        XCTAssertGreaterThanOrEqual(app.images.matching(NSPredicate(format: "label == %@ OR identifier == %@", "checkmark.circle.fill", "checkmark.circle.fill")).count, 3,
                                    "expected three ticked tier rows (Gold banked in run 1 must survive run 2) — images: \(app.images.allElementsBoundByIndex.map { $0.label })")
    }

    // MARK: - helpers

    private func texts(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map { $0.label }.filter { $0.contains("Deal #") || $0.contains("earned") || $0.contains("Flawless") }.joined(separator: " | ")
    }

    private func streakCards(_ app: XCUIApplication) -> String {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "current streak")).allElementsBoundByIndex.map { $0.label }.joined(separator: " | ")
    }
}
