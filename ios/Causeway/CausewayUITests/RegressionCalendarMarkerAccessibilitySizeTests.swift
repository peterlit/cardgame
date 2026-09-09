//
//  RegressionCalendarMarkerAccessibilitySizeTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-5:calendar-marker-clips-at-accessibility-size   (TC-5.1, minor)
//  Verified FIXED in qa-loop round 3 (build de5e5d0).
//
//  FIXED contract this test guards (Views/DailyView.swift calCell, markerH):
//   - The marker slot under a calendar date (🌟 flawless star, 🔒 lock, tier dots) grows
//     with Dynamic Type at accessibility sizes and the cell grows to hold it. Before the
//     fix the slot was a fixed 6 pt while the glyphs scaled (11 pt → ~28 pt star, 8 pt →
//     ~21 pt lock), so at Accessibility XXXL the star drew over its own date digits and
//     hung a row-gap below the cell into the next row, and every lock spilled out of its
//     chip. Measured: the cell was 49×54 at AX5 on 9ab79f1 and 49×92 on de5e5d0 (49×40
//     at the default size on both — ordinary sizes are untouched).
//
//  Original repro (round 2, QADriver):
//    make_save --day 13 --tier flawless | inject; launch CAUSEWAY_TODAY_OVERRIDE=2026-08-14;
//    Finish; close the win overlay; tapid toolbar.daily; swipe 200 700 200 200 (baseline:
//    the star sits inside the cell under '14');
//    xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large;
//    5x swipe 200 700 200 250 -> labels any daily.cal.13 -> the star overlaps the date and
//    the row below; daily.cal.15 and later show the padlock outside the chip.
//
//  How it is asserted: the cell combines its children into ONE accessibility element
//  (daily.cal.<idx>), so the glyph itself cannot be measured — but the cell's frame can.
//  A slot that scales makes the AX5 cell at least ~2.3× its default height (92 vs 40); the
//  fixed 6 pt slot left it at 1.35× (54 vs 40). The tripwire is the ratio, on a 🌟 cell,
//  a 🔒 cell and a marker-less cell alike (the slot is the same height in every cell).
//  The size is injected per launch through UIKit's `-UIPreferredContentSizeCategoryName`
//  argument, never `simctl ui content_size` (which would leave the shared simulator at
//  AX5 for every other test). The daily store is seeded with a flawless Aug 14 (index 13)
//  so the star exists without playing the cascade; with the clock pinned to Aug 15,
//  Aug 15 (14) is today with no marker and Aug 16 (15) is always the locked day.
//
import XCTest

final class RegressionCalendarMarkerAccessibilitySizeTests: XCTestCase {

    /// Aug 14 (index 13) flawless: the 🌟 cell. Same record RegressionDailyA11yStateLabelsTests seeds.
    private let flawlessDaily = #"{"version":3,"days":{"13":{"bronze":true,"silver":true,"gold":true,"flawless":true,"onTime":true,"moves":79,"elapsed":95,"runs":[{"moves":79,"elapsed":95}]}}}"#

    private let starCell = 13, todayCell = 14, lockCell = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-5:calendar-marker-clips-at-accessibility-size — at Accessibility XXXL the
    /// calendar cell grows to hold its scaled marker instead of letting it overflow.
    func testCalendarCellsGrowToHoldScaledMarkersAtAccessibilityXXXL() throws {
        // --- baseline: default size ------------------------------------------------------
        let base = QA.launch(daily: flawlessDaily)
        QA.openDaily(base)
        let baseStar = scrollTo(base, starCell)
        XCTAssertTrue(baseStar.label.contains("Flawless"),
                      "fixture precondition: Aug 14 must be the flawless (🌟) cell, got '\(baseStar.label)'")
        let baseH = baseStar.frame.height
        XCTAssertGreaterThan(baseH, 30, "the default-size cell is implausibly short (\(baseH) pt)")
        XCTAssertLessThan(baseH, 60, "the default-size cell grew (\(baseH) pt) — ordinary sizes must be untouched")
        let baseLock = base.buttons["daily.cal.\(lockCell)"]
        XCTAssertTrue(baseLock.label.contains("locked until that date"),
                      "fixture precondition: Aug 16 must be the locked (🔒) cell, got '\(baseLock.label)'")
        base.terminate()

        // --- Accessibility XXXL ------------------------------------------------------------
        let big = QA.app(daily: flawlessDaily)
        big.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .portrait
        big.launch()
        XCTAssertTrue(big.buttons["toolbar.deal"].waitForExistence(timeout: 10), "the board never appeared at AX5")
        QA.openDaily(big)
        let star = scrollTo(big, starCell)
        let today = big.buttons["daily.cal.\(todayCell)"]
        let lock = big.buttons["daily.cal.\(lockCell)"]
        XCTAssertTrue(today.exists && lock.exists, "the AX5 calendar lost its today / locked cells")

        let starH = star.frame.height, lockH = lock.frame.height, todayH = today.frame.height
        XCTAssertGreaterThan(starH, baseH * 1.8,
                             "the 🌟 cell did not grow to hold its scaled star at AX5 (\(baseH) → \(starH) pt): the 6-pt marker slot is back and the star overlaps its date")
        XCTAssertGreaterThan(lockH, baseH * 1.8,
                             "the 🔒 cell did not grow to hold its scaled lock at AX5 (\(baseH) → \(lockH) pt)")
        XCTAssertEqual(todayH, starH, accuracy: 1.5,
                       "a marker-less cell (\(todayH) pt) and the 🌟 cell (\(starH) pt) differ at AX5 — the slot is no longer uniform, so dates jitter between neighbours")
        XCTAssertEqual(lockH, starH, accuracy: 1.5,
                       "the 🔒 cell (\(lockH) pt) and the 🌟 cell (\(starH) pt) differ at AX5")
    }

    // MARK: - helpers

    /// QA.scrollToCalendarCell with a longer leash: at AX5 the one-column streak grid and the
    /// scaled legend push the calendar several screens down.
    private func scrollTo(_ app: XCUIApplication, _ idx: Int) -> XCUIElement {
        let cell = app.buttons["daily.cal.\(idx)"]
        for _ in 0..<24 where !cell.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(cell.isHittable, "calendar cell daily.cal.\(idx) never became hittable")
        return cell
    }
}
