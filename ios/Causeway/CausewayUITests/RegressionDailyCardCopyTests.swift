//
//  RegressionDailyCardCopyTests.swift
//  CausewayUITests
//
//  Regression tripwires for:
//    ux/WF-15:day-card-banked-tiers-read-as-flawless     (TC-15.6, minor)
//    ux/WF-5:par-has-no-legend                            (TC-5.4,  minor)
//    ux/WF-7:live-game-confirm-challenge-two-senses       (TC-7.6,  minor)
//  All verified FIXED in qa-loop round 2 (build 9ab79f1 / app 42b5f7e).
//
//  FIXED contracts these tests guard (Views/DailyView.swift):
//   - A day whose 🥉🥈🥇 were banked across SEPARATE runs carries
//     "🌟 Not yet Flawless — these medals came from separate runs; earn 🥉🥈🥇 in one
//     run." (daily.flawless.pending) under its three checks, and no 🌟 Flawless badge;
//     a genuinely flawless day carries the badge (daily.card.flawless) and no note.
//     Display only — the checks stay cumulative.
//   - The streak legend ends with "Par = the shortest winning line the solver
//     certified for that deal." — the clears line ("… · par 86") had a bare number
//     that nothing in the app defined.
//   - The Daily sheet's discard confirm over a casual game ends "The game you're in
//     is a casual deal, so there is no way back to it." — it used to say "This game
//     is not a challenge" one sentence after "Starting this challenge re-deals the
//     board": the same word in two senses at the moment of an irreversible action.
//
//  Original repros (round 1, QADriver):
//    inject day 12 silver then day 12 gold (two runs); launch CAUSEWAY_TODAY_OVERRIDE=
//    2026-08-13; Finish twice; tapid toolbar.daily → three #checkmark.circle.fill,
//    streak card '🌟 Flawless 0 / 0 total / best 0', NO badge and NO explanation.
//    inject day 2 gold + bronze; Finish; tapid toolbar.daily; swipe up ×2; tapid
//    daily.cal.2 → daily.clears 'Cleared 2× · fewest 96 moves · fastest 1:41 · par 86';
//    'par' appears nowhere else on the sheet or in How to play.
//    launch; tapid toolbar.autoplay (Off); drag 273 612 275 295 (Moves 1); tapid
//    toolbar.daily; tapid daily.play; alert body '… This game is not a challenge …'.
//
//  THE CLOCK IS PINNED to 2026-08-15; solved days are SEEDED daily-store records.
//  Selector notes: daily.flawless.pending / daily.card.flawless / daily.tier.<tier> /
//  daily.clears / daily.play / daily.cal.<idx> are real identifiers. The legend
//  paragraph has none — matched by CONTAINS on its par sentence.
//
import XCTest

final class RegressionDailyCardCopyTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Aug 13 (index 12): 🥉🥈🥇 all banked, but never in one run. Aug 14 (index 13): flawless.
    private let bankedDaily = #"{"version":3,"days":{"12":{"bronze":true,"silver":true,"gold":true,"flawless":false,"onTime":false,"moves":103,"elapsed":120,"runs":[{"moves":103,"elapsed":120},{"moves":110,"elapsed":131}]},"13":{"bronze":true,"silver":true,"gold":true,"flawless":true,"onTime":true,"moves":79,"elapsed":95,"runs":[{"moves":79,"elapsed":95}]}}}"#

    /// Aug 3 (index 2): one bronze-only clear, 96 moves in 1:41 (par 86).
    private let parDaily = #"{"version":3,"days":{"2":{"bronze":true,"silver":false,"gold":false,"flawless":false,"onTime":false,"moves":96,"elapsed":101,"runs":[{"moves":96,"elapsed":101}]}}}"#

    /// ux/WF-15:day-card-banked-tiers-read-as-flawless — three banked checks say
    /// "Not yet Flawless"; a flawless day says 🌟 and nothing else.
    func testBankedTiersSayNotYetFlawlessAndAFlawlessDayDoesNot() throws {
        let app = QA.launch(daily: bankedDaily)
        QA.selectCalendarDay(app, 12)

        for tier in ["bronze", "silver", "gold"] {
            let row = app.descendants(matching: .any)["daily.tier.\(tier)"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "no daily.tier.\(tier) row")
            XCTAssertEqual(row.value as? String, "earned", "precondition: \(tier) is banked on Aug 13")
        }
        let pending = app.staticTexts["daily.flawless.pending"]
        XCTAssertTrue(pending.waitForExistence(timeout: 3),
                      "three banked checks with no 🌟 carry no explanation — a novice reads them as Flawless again")
        XCTAssertEqual(pending.label,
                       "🌟 Not yet Flawless — these medals came from separate runs; earn 🥉🥈🥇 in one run.",
                       "the 'Not yet Flawless' line changed")
        XCTAssertFalse(app.staticTexts["daily.card.flawless"].exists,
                       "Aug 13 shows the 🌟 Flawless badge although its medals came from separate runs")

        // Contrast: the genuinely flawless Aug 14 — badge on, note gone.
        QA.scrollToCalendarCell(app, 13).tap()
        let badge = app.staticTexts["daily.card.flawless"]
        XCTAssertTrue(badge.waitForExistence(timeout: 3), "the flawless day lost its 🌟 Flawless badge")
        XCTAssertEqual(badge.label, "🌟 Flawless")
        XCTAssertTrue(QA.waitGone(pending, timeout: 3),
                      "the 'Not yet Flawless' note is still shown on a day that IS flawless")
    }

    /// ux/WF-5:par-has-no-legend — the clears line's "par N" is defined by the legend
    /// on the same sheet.
    func testLegendDefinesTheParTheClearsLineQuotes() throws {
        let app = QA.launch(daily: parDaily)
        QA.selectCalendarDay(app, 2)

        let clears = app.staticTexts["daily.clears"]
        XCTAssertTrue(clears.waitForExistence(timeout: 5), "no daily.clears line on the solved day's card")
        XCTAssertEqual(clears.label, "Cleared · fewest 96 moves · fastest 1:41 · par 86",
                       "the clears line changed shape (it must still quote 'par 86' for Aug 3)")

        let sentence = "Par = the shortest winning line the solver certified for that deal."
        let legend = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", sentence))
        XCTAssertEqual(legend.count, 1,
                       "the sheet no longer defines par (expected exactly one legend containing '\(sentence)', found \(legend.count))")
        XCTAssertTrue(legend.firstMatch.label.hasPrefix("A streak counts consecutive days holding that medal."),
                      "the par sentence moved out of the streak legend: \(legend.firstMatch.label)")
    }

    /// ux/WF-7:live-game-confirm-challenge-two-senses — the sheet's discard confirm over
    /// a casual game names the current game as "a casual deal", and uses "challenge" once.
    func testDiscardConfirmOverACasualGameUsesChallengeInOneSense() throws {
        let app = QA.launch(autoplay: false)   // Auto-play Off keeps the move count at exactly 1
        QA.dealSeed(app, 500001)
        XCTAssertTrue(QA.wait(5) { app.buttons["toolbar.deal"].label.hasPrefix("Deal #500001") })
        XCTAssertEqual(QA.tapCard(app, "card.D1"), "1", "could not make the casual board live (A♦ tap)")

        QA.openDaily(app)
        app.buttons["daily.play"].tap()
        let confirm = app.alerts["Discard the game in progress?"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3),
                      "starting a challenge over a live casual game must ask first")
        let expected = "Starting this challenge re-deals the board, so your 1 move and your time will be discarded. "
            + "The game you're in is a casual deal, so there is no way back to it."
        XCTAssertTrue(QA.alert(confirm, contains: expected),
                      "the confirm body changed — expected\n\(expected)\ngot\n\(QA.alertText(confirm))")
        XCTAssertFalse(QA.alert(confirm, contains: "not a challenge"),
                       "'This game is not a challenge' is back — 'challenge' in two senses, one sentence apart")

        confirm.buttons["Keep playing"].tap()
        XCTAssertTrue(QA.waitGone(confirm, timeout: 3))
        XCTAssertTrue(app.navigationBars["Daily Challenges"].exists, "Keep playing must leave the sheet open")
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "1", "Keep playing must leave the board untouched")
    }
}
