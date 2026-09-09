//
//  SmokeDailySheetTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversions of the [smoke] cases in .qa-loop/TESTCASES.md
//  (qa-loop 2026-09-09, round 1):
//    TC-5.1  Open Daily and read objectives + the five streak cards
//    TC-13.1 Find a past day in the calendar and read ITS OWN objectives
//    TC-13.4 Play a past day; the board HUD carries THAT day's objectives (+ live-game confirm)
//    TC-13.5 A constraint violation is ALLOWED, shows instantly, and Undo rolls it back
//    TC-15.1 The 🌟 pill is on Today, and its demo is watchable
//
//  Determinism: clock pinned to 2026-08-15 (day 14) with EMPTY daily/wins stores, so the
//  sheet is a fresh install's. Expected copy cross-checked with derive_daily.py:
//    Aug 15 (today, idx 14): deal #608530 · Silver "Never move more than 2 cards in a single
//      move" · Gold "Take at least 10 of every suit from the King end" · flawless line 98
//    Aug 3  (idx 2):  deal #539885 · "Never move more than 3 cards in a single move" ·
//      "Finish one whole suit before any other suit is started"
//    Aug 4  (idx 3):  deal #625648 · "Never let one suit get more than 4 cards ahead of
//      another" · "Win without ever using a free cell" (cells-le 0 — one cell use = ✗)
//  TC-13.5's violation is made by TAPPING 3♦ (card.D3, column 0's bottom card on #625648):
//  it has no foundation or tableau target, so smart-move parks it in a free cell (Controls:
//  "…otherwise onto another card, an empty column, or a free cell"). A drag toward the
//  cells is the fallback if the tap does not park it.
//
//  Selector notes: "toolbar.daily", "daily.play", "daily.demo.<tier>", "daily.cal.<idx>",
//  "daily.clears", "hud.day", "demo.headline" / "demo.next" / "demo.start" / "demo.stop",
//  "toolbar.finish", "toolbar.undo", "stat.moves". Streak cards expose ONLY an
//  accessibility label ("Play: current streak 0 days, 0 days total, best 0 days"); HUD
//  chips render as "🥇·"/"🥇✗" mark texts + label texts (no identifiers on either —
//  bug/Main:scored-surfaces-addressable-only-by-copy).
//
import XCTest

final class SmokeDailySheetTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-5.1 — a fresh install's Daily sheet: five zeroed streak cards, the explainer,
    /// Today's card with derived objectives, the ⏰ invitation, plain "Play", four demo
    /// pills, and NO clears line.
    func testTC5_1_FreshDailySheetReadsCorrectly() throws {
        let app = QA.launch()
        QA.openDaily(app)

        for card in ["Play", "Same-day", "Silver", "Gold", "Flawless"] {
            let label = "\(card): current streak 0 days, 0 days total, best 0 days"
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch.waitForExistence(timeout: 3),
                          "streak card missing or not zeroed: '\(label)'")
        }
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "A streak counts consecutive days holding that medal.")).count > 0,
                      "the streak explainer is gone")
        XCTAssertTrue(app.staticTexts["Today"].exists, "the day card is not headed Today")
        XCTAssertTrue(app.staticTexts["Deal #608530"].exists, "Today's card does not show the pinned deal #608530 (ungrouped)")
        for text in ["Clear the deal", "Never move more than 2 cards in a single move", "Take at least 10 of every suit from the King end"] {
            XCTAssertTrue(app.staticTexts[text].exists, "Today's objective missing: \(text)")
        }
        XCTAssertTrue(app.staticTexts["⏰ Win today to start a same-day streak"].exists, "the ⏰ invitation line is wrong")
        XCTAssertEqual(app.buttons["daily.play"].label, "Play", "Today's Play must be the plain verb")
        XCTAssertTrue(app.staticTexts["Show me how to win:"].exists)
        for tier in ["bronze", "silver", "gold", "flawless"] {
            XCTAssertTrue(app.buttons["daily.demo.\(tier)"].exists, "demo pill missing: daily.demo.\(tier)")
        }
        XCTAssertFalse(app.staticTexts["daily.clears"].exists, "an unsolved day must show no clears line")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "par ")).count, 0, "no par may be shown on an unsolved day")

        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["Daily Challenges"], timeout: 3), "Done did not dismiss the sheet")
    }

    /// TC-13.1 — Aug 3's card shows Aug 3's objectives, "Play Aug 3", and no trace of Today.
    func testTC13_1_PastDayCardShowsItsOwnObjectives() throws {
        let app = QA.launch()
        QA.selectCalendarDay(app, 2)

        XCTAssertTrue(app.staticTexts["Aug 3"].waitForExistence(timeout: 3), "the card is not headed Aug 3")
        XCTAssertTrue(app.staticTexts["Deal #539885"].exists, "Aug 3's deal is not #539885")
        for text in ["Clear the deal", "Never move more than 3 cards in a single move", "Finish one whole suit before any other suit is started"] {
            XCTAssertTrue(app.staticTexts[text].exists, "Aug 3 objective missing: \(text)")
        }
        XCTAssertTrue(app.staticTexts["⏰ Same-day is earned on the day itself"].exists, "the past-day ⏰ line is wrong")
        XCTAssertEqual(app.buttons["daily.play"].label, "Play Aug 3", "Play must name the selected day")
        for tier in ["bronze", "silver", "gold", "flawless"] {
            XCTAssertTrue(app.buttons["daily.demo.\(tier)"].exists, "demo pill missing: daily.demo.\(tier)")
        }
        // The headline bug this workflow exists for: Today's card leaking into a past day.
        XCTAssertFalse(app.staticTexts["Deal #608530"].exists, "Today's deal leaked into Aug 3's card")
        XCTAssertFalse(app.staticTexts["Never move more than 2 cards in a single move"].exists, "Today's Silver leaked into Aug 3's card")
        XCTAssertFalse(app.staticTexts["Take at least 10 of every suit from the King end"].exists, "Today's Gold leaked into Aug 3's card")
        XCTAssertFalse(app.staticTexts["daily.clears"].exists, "Aug 3 is unsolved on a fresh install — no clears line")
    }

    /// TC-13.4 — playing Aug 4 deals #625648 with the HUD naming Aug 4 and ITS chips;
    /// replacing a live casual game asks first (Keep playing / Start over).
    func testTC13_4_PlayingAPastDayCarriesItsObjectivesOnTheHud() throws {
        let app = QA.launch(autoplay: false)
        // A live casual game first (the "also assert").
        QA.dealSeed(app, 500001)
        XCTAssertTrue(QA.wait(5) { app.buttons["toolbar.deal"].label.hasPrefix("Deal #500001") })
        let moves = app.staticTexts["stat.moves"]
        XCTAssertEqual(QA.tapCard(app, "card.D1"), "1", "could not make the casual board live (A♦ tap)")

        QA.selectCalendarDay(app, 3)
        app.buttons["daily.play"].tap()
        let confirm = app.alerts["Discard the game in progress?"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "starting a challenge over a live casual game must ask first")
        XCTAssertTrue(confirm.buttons["Keep playing"].exists && confirm.buttons["Start over"].exists,
                      "expected Keep playing / Start over, got \(confirm.buttons.allElementsBoundByIndex.map { $0.label })")
        confirm.buttons["Start over"].tap()

        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #625648") }, "Aug 4's deal did not load: \(dealPill.label)")
        XCTAssertEqual(moves.label, "0")
        XCTAssertTrue(app.staticTexts["hud.day"].waitForExistence(timeout: 3), "the HUD does not name the day")
        XCTAssertEqual(app.staticTexts["hud.day"].label, "Aug 4")
        for text in ["Clear the deal", "Never let one suit get more than 4 cards ahead of another", "Win without ever using a free cell"] {
            XCTAssertTrue(app.staticTexts[text].exists, "Aug 4 HUD chip missing: \(text)")
        }
        for mark in ["🥉·", "🥈·", "🥇·"] {
            XCTAssertTrue(app.staticTexts[mark].exists, "HUD mark missing or not live: \(mark)")
        }
        XCTAssertFalse(app.staticTexts["Take at least 10 of every suit from the King end"].exists, "Today's objectives leaked onto Aug 4's HUD")
    }

    /// TC-13.5 — a cell use on Aug 4 (Gold: no free cells) is allowed, flips 🥇 to ✗ at once,
    /// and Undo rolls it back to ·.
    func testTC13_5_ConstraintViolationShowsInstantlyAndUndoRollsItBack() throws {
        let app = QA.launch(autoplay: false)
        QA.selectCalendarDay(app, 3)
        app.buttons["daily.play"].tap()
        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #625648") }, "Aug 4's deal did not load: \(dealPill.label)")
        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(app.staticTexts["🥇·"].waitForExistence(timeout: 3), "Gold must start live (·)")

        let three = app.descendants(matching: .any)["card.D3"]
        XCTAssertTrue(three.waitForExistence(timeout: 3), "3♦ is not on the board — deal #625648 layout changed?")
        let tableauTop = QA.cards(app).map { $0.frame.minY }.min() ?? 0
        if QA.tapCard(app, "card.D3") != "1" {
            // Fallback: drag it into the first free cell (right under the FREE CELLS heading).
            let cellsLabel = app.staticTexts["FREE CELLS"]
            let cardW = three.frame.width
            let target = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: cellsLabel.frame.maxX - 2.5 * cardW - 8, dy: cellsLabel.frame.maxY + 4 + three.frame.height / 2))
            three.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.6, thenDragTo: target)
        }
        XCTAssertTrue(QA.wait(3) { moves.label == "1" }, "the cell move was refused or not counted (Moves \(moves.label))")
        XCTAssertFalse(app.alerts.firstMatch.exists, "a constraint violation must never be refused with a dialog")
        XCTAssertLessThan(three.frame.maxY, tableauTop, "3♦ did not leave the tableau for a free cell")
        XCTAssertTrue(QA.wait(2) { app.staticTexts["🥇✗"].exists }, "the Gold chip did not flip to ✗ on the cell use")
        XCTAssertTrue(app.staticTexts["🥉·"].exists && app.staticTexts["🥈·"].exists, "Bronze/Silver must stay live")
        XCTAssertTrue(app.staticTexts["Win without ever using a free cell"].exists, "the Gold label must not change with its mark")

        app.buttons["toolbar.undo"].tap()
        XCTAssertTrue(QA.wait(3) { moves.label == "0" }, "Undo did not roll the move back")
        XCTAssertTrue(QA.wait(2) { app.staticTexts["🥇·"].exists }, "Undo did not roll the Gold chip back to · (deliberate telemetry rollback)")
        XCTAssertFalse(app.staticTexts["🥇✗"].exists)
    }

    /// TC-15.1 — the 🌟 pill sits with the other three on Today; its demo opens paused,
    /// steps with Next, and Stop tears it down without a Finish pill.
    func testTC15_1_FlawlessPillIsOnTodayAndItsDemoIsWatchable() throws {
        let app = QA.launch()
        QA.openDaily(app)

        let expected = [("bronze", "🥉 Clear"), ("silver", "🥈 Silver"), ("gold", "🥇 Gold"), ("flawless", "🌟 Flawless")]
        for (tier, label) in expected {
            let pill = app.buttons["daily.demo.\(tier)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 3), "demo pill missing: daily.demo.\(tier)")
            XCTAssertEqual(pill.label, label, "demo pill daily.demo.\(tier) is labelled '\(pill.label)'")
        }
        app.buttons["daily.demo.flawless"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["Daily Challenges"], timeout: 5), "the sheet did not dismiss")

        let headline = app.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "no demo headline")
        // The 🌟 headline names the day's 🥈/🥇 objectives in parentheses (DailyView.flawlessDemoLabel,
        // ux/WF-15 round-1 fix): day 14 is max-run 2 / end-bias down 10 (data/daily-pool.json).
        XCTAssertTrue(headline.label.hasPrefix("🌟 Flawless: 🥉🥈🥇 all three in a single run (🥈 Never move more than 2 cards in a single move; 🥇 Take at least 10 of every suit from the King end) · 0 / "),
                      "unexpected flawless headline: \(headline.label)")
        XCTAssertEqual(app.buttons["demo.start"].label, "Start", "the demo must open paused (Start, not Pause)")
        XCTAssertTrue(app.buttons["demo.next"].exists && app.buttons["demo.stop"].exists)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(headline.label.contains(" · 0 / "), "the demo auto-ran while paused: \(headline.label)")

        app.buttons["demo.next"].tap()
        XCTAssertTrue(QA.wait(3) { headline.label.contains(" · 1 / ") }, "Next did not advance to 1 / N: \(headline.label)")

        app.buttons["demo.stop"].tap()
        XCTAssertTrue(QA.waitGone(headline, timeout: 5), "Stop did not remove the demo bar")
        XCTAssertFalse(app.buttons["demo.start"].exists && app.buttons["demo.next"].exists, "demo pills survived Stop")
        XCTAssertFalse(app.buttons["toolbar.finish"].exists, "Stop must leave NO Finish pill (it re-deals)")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "0")
    }
}
