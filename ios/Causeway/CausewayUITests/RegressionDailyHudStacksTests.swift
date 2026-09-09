//
//  RegressionDailyHudStacksTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-5:daily-hud-truncates-objectives (major)
//  Fixed on 5447237 (archived ledger 20260822-125736-f949d82); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (DailyView.dailyHUD — ViewThatFits):
//   - In portrait the three objective chips cannot fit one untruncated line, so the HUD
//     STACKS them (one chip per row) with fully wrapped labels; in landscape they sit on
//     one line. Before the fix portrait forced all three onto one ~402 pt line and cut
//     Silver/Gold to "Win in 103 moves or…", so a player chasing Gold could not read
//     what Gold requires while playing.
//
//  How truncation is detected: XCUITest reads the FULL label of a truncated Text, so
//  "no ellipsis" cannot be asserted directly. The fix's observable is the layout branch:
//  the three medal marks ("🥉·" "🥈·" "🥇·", separate static texts in DailyView.objChip)
//  sit on three different rows in portrait and on ONE row in landscape, and each label
//  stays inside the window. A regression to the single-line portrait branch collapses
//  the marks onto one row — exactly what this test fails on.
//
//  Original repro (round-1/3 testers): Daily → Play (Today) → read the dark objectives
//   capsule under the toolbar in portrait: '🥈 · Win in 103 moves or…'.
//
//  Selector notes: "toolbar.daily", "daily.play", "toolbar.deal"; HUD chips have no
//  identifier (bug/Main:scored-surfaces-addressable-only-by-copy) — the mark texts are
//  matched exactly and the label texts by today's derived objectives (Aug 15: Silver
//  "Never move more than 2 cards in a single move", Gold "Take at least 10 of every suit
//  from the King end" — derive_daily.py 2026-08-15).
//
import XCTest

final class RegressionDailyHudStacksTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// ux/WF-5:daily-hud-truncates-objectives — chips stack in portrait, one-line in landscape.
    func testObjectiveChipsStackInPortraitAndLineUpInLandscape() throws {
        let app = QA.launch(autoplay: false)
        QA.openDaily(app)
        app.buttons["daily.play"].tap()
        let dealPill = app.buttons["toolbar.deal"]
        XCTAssertTrue(QA.wait(5) { dealPill.label.hasPrefix("Deal #608530") }, "today's challenge did not load: \(dealPill.label)")

        let bronze = app.staticTexts["hud.chip.bronze"], silver = app.staticTexts["hud.chip.silver"], gold = app.staticTexts["hud.chip.gold"]
        XCTAssertTrue(gold.waitForExistence(timeout: 5), "no Gold chip mark on the HUD")
        XCTAssertEqual([bronze.label, silver.label, gold.label], ["🥉·", "🥈·", "🥇·"], "the HUD chip marks are not all live")
        for (tier, label) in [("bronze", "Clear the deal"), ("silver", "Never move more than 2 cards in a single move"), ("gold", "Take at least 10 of every suit from the King end")] {
            XCTAssertEqual(app.staticTexts["hud.chip.\(tier).label"].label, label, "HUD chip label wrong for \(tier)")
        }

        // Portrait: three rows.
        XCTAssertGreaterThan(silver.frame.minY, bronze.frame.maxY - 2, "portrait: Silver is not below Bronze — the chips are one-lined again")
        XCTAssertGreaterThan(gold.frame.minY, silver.frame.maxY - 2, "portrait: Gold is not below Silver — the chips are one-lined again")
        let window = app.windows.firstMatch
        for tier in ["silver", "gold"] {
            let text = app.staticTexts["hud.chip.\(tier).label"]
            XCTAssertLessThanOrEqual(text.frame.maxX, window.frame.maxX + 0.5, "portrait: '\(text.label)' runs off the window")
        }

        // Landscape: one row.
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "rotation to landscape never took effect")
        XCTAssertTrue(QA.wait(3) { abs(gold.frame.midY - bronze.frame.midY) < 3 && abs(silver.frame.midY - bronze.frame.midY) < 3 },
                      "landscape: the chips did not line up on one row (y \(bronze.frame.midY) / \(silver.frame.midY) / \(gold.frame.midY))")
    }
}
