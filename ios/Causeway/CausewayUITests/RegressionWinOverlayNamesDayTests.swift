//
//  RegressionWinOverlayNamesDayTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-14:win-overlay-omits-the-day (minor, TC-14.6)
//  Verified FIXED in qa-loop 2026-09-09 round 1 (build 1a63ce2); first fixed on
//  4f02d1d (archived ledger 20260909-085142-4f02d1d) and unguarded until now — the
//  fixture route (QAFixtures.swift) is what makes it testable.
//
//  FIXED contract these tests guard (ContentView.winDayLabel / winDailyText):
//   - When the attempt just scored is NOT today's challenge — a ⏰-grace win for
//     yesterday, or a plain past-day replay — the overlay's daily line is prefixed
//     with the day it credited ("Aug 14: …"). Without it "On time — 1-day same-day
//     streak" on a day that is not today read as "today is done".
//   - Today's own win stays UNPREFIXED (winDayLabel's guard).
//   - The ⏰ clause rides only on an on-time win: a past-day replay carries none.
//
//  Original repro (round-1 tester):
//   make_save.mjs --day 13 --tier flawless --challengeDay 13 --startDay 13 injected;
//   launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15; tap Finish; read the overlay →
//   'Aug 14: 🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak.'
//   compare: same-day win (pin 2026-08-14) → no prefix; past-day replay (pin
//   2026-08-15, day 12 --startDay 14) → 'Aug 13:' prefix and no ⏰ clause.
//
//  Selector notes: the win overlay has NO identifier (still open as
//  bug/Main:scored-surfaces-addressable-only-by-copy) — the daily line is found by
//  its exact text, which is the contract under test anyway. The "Ready to finish"
//  prompt and its "Finish" button are queried by label (SwiftUI .alert).
//
import XCTest

final class RegressionWinOverlayNamesDayTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-14:win-overlay-omits-the-day — a ⏰-grace payout for YESTERDAY must name the day.
    func testGraceWinForYesterdayIsPrefixedWithTheDay() throws {
        let app = QA.launch(today: "2026-08-15", game: QA.day13Flawless)   // Aug 14's deal, begun Aug 14
        QA.finishFromPrompt(app)

        let expected = "Aug 14: 🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak."
        XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5),
                      "the overlay's daily line lost its 'Aug 14:' prefix (or its ⏰ clause) — on screen: \(overlayTexts(app))")
        // UNGROUPED digits: the overlay goes through DealFormat.seed like the board pill
        // (bug/WF-4:win-overlay-seed-grouped, fixed 42b5f7e). "Deal #720,307" would be that bug back.
        XCTAssertTrue(dealLine(app).hasPrefix("Deal #720307 · 79 moves · "),
                      "the overlay's deal line is not 'Deal #720307 · 79 moves · M:SS' (ungrouped, the fixture's deal / move count): \(dealLine(app))")
    }

    /// ux/WF-14:win-overlay-omits-the-day — a past-day REPLAY names the day and carries no ⏰.
    func testPastDayReplayIsPrefixedWithTheDayAndHasNoOnTimeClause() throws {
        let app = QA.launch(today: "2026-08-15", game: QA.day12FlawlessStart14)   // Aug 13's deal, begun Aug 15
        QA.finishFromPrompt(app)

        let expected = "Aug 13: 🌟 Flawless! 🥉🥈🥇 all in a single run."
        XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5),
                      "a past-day replay must read exactly 'Aug 13: 🌟 Flawless! …' with NO ⏰ clause — on screen: \(overlayTexts(app))")
    }

    /// ux/WF-14:win-overlay-omits-the-day — today's own win must stay UNPREFIXED.
    func testTodaysOwnWinHasNoDayPrefix() throws {
        let app = QA.launch(today: "2026-08-14", game: QA.day13Flawless)   // day 13 IS today
        QA.finishFromPrompt(app)

        let expected = "🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak."
        XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 5),
                      "today's win must not be prefixed with its own day — on screen: \(overlayTexts(app))")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Aug 14:")).count, 0,
                       "winDayLabel's today-guard is gone: the overlay prefixed today's own win")
    }

    // MARK: - helpers

    private func overlayTexts(_ app: XCUIApplication) -> String {
        app.staticTexts.allElementsBoundByIndex.map { $0.label }
            .filter { $0.contains("Flawless") || $0.contains("Daily challenge") || $0.hasPrefix("Aug ") }
            .joined(separator: " | ")
    }

    private func dealLine(_ app: XCUIApplication) -> String {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Deal #")).allElementsBoundByIndex
            .map { $0.label }.first { $0.contains("moves") } ?? "<no deal line>"
    }
}
