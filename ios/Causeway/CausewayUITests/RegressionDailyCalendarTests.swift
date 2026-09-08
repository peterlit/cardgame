//
//  RegressionDailyCalendarTests.swift
//  CausewayUITests
//
//  Regression tripwires for:
//    ux/WF-13:future-day-tap-no-feedback     (TC-13.2)
//    ux/WF-13:selected-day-invisible-at-play (TC-13.1)
//    ux/WF-14:calendar-pip-unlabelled        (TC-14.2)
//  All verified FIXED in qa-loop round 2 (build 4f02d1d).
//
//  FIXED contracts these tests guard (Views/DailyView.swift):
//   - A tap on a cell that cannot be opened is ANSWERED: the cell tints and a
//     dated note appears under the grid ("daily.lockednote"), instead of the tap
//     being swallowed exactly like a broken calendar. Future in-pool cells also
//     carry a standing 🔒 so "not yet" is legible without tapping at all.
//   - The gold Play button NAMES the day it will start ("Play Aug 14"): at the
//     calendar scroll position the day-card header that identifies the selection
//     is above the fold, so a mis-tapped 44x33 pt cell used to start the wrong
//     day's deal with nothing on screen to catch it.
//   - The calendar legend names the ⏰ same-day corner pip — five marker types
//     are drawn in the grid and the legend named four, and the unnamed one is a
//     bare gold dot the same size and colour as the gold TIER dot.
//
//  THE CLOCK IS PINNED. Every test launches with CAUSEWAY_TODAY_OVERRIDE
//  2026-08-15 (mid-pool), so "yesterday" is always the seeded Aug 14 and
//  "tomorrow" is always the seeded, locked Aug 16. This class used to read the
//  real calendar: it skipped on month boundaries, went red when September
//  arrived (skeptical-review R10), and would have hard-failed for good once the
//  pool ended (BACKLOG's pool-end time bomb). A date-dependent test against a
//  finite fixture pool is a time bomb by construction — never key these on
//  Date() again.
//
//  Cells are located by their STABLE identifier "daily.cal.<dayIndex>"
//  (Aug 14 = index 13, Aug 16 = index 15; day 0 = 2026-08-01). The old helper
//  scrolled until the legend was HITTABLE, which is a layout accident: on some
//  days the legend cleared the fold while the LazyVGrid below it had
//  materialised nothing, so zero swipes "succeeded" into an empty grid. Scroll
//  toward the cell you actually need.
//
import XCTest

final class RegressionDailyCalendarTests: XCTestCase {

    private let augustToday = "2026-08-15"   // pinned clock: day index 14

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchPinned() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["CAUSEWAY_TODAY_OVERRIDE"] = augustToday
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        return app
    }

    /// ux/WF-13:future-day-tap-no-feedback — a locked (future, in-pool) cell must
    /// answer the tap with a dated explanation instead of swallowing it.
    /// With the clock pinned to Aug 15, tomorrow is ALWAYS the seeded, locked Aug 16 —
    /// this exercises the in-pool locked path forever, not just until the pool ends.
    func testTappingALockedFutureDayExplainsWhy() throws {
        let app = launchPinned()
        let cell = openDailyCalendar(app, toCell: 15)   // Aug 16
        XCTAssertTrue(cell.label.contains("locked until that date"),
                      "the seeded future cell lost its locked wording — got: \(cell.label)")

        XCTAssertFalse(app.staticTexts["daily.lockednote"].exists,
                       "the locked note must appear in ANSWER to a tap, not stand permanently")
        cell.tap()

        let note = app.staticTexts["daily.lockednote"]
        XCTAssertTrue(note.waitForExistence(timeout: 3),
                      "a tap on a future day was swallowed with zero feedback — the round-1 bug is back")
        XCTAssertTrue(note.label.contains("unlocks on the day itself"),
                      "the note must say WHY the day cannot be opened, got: \(note.label)")
    }

    /// ux/WF-13:selected-day-invisible-at-play — the Play button must name the
    /// day it will start whenever that day is not today. Yesterday = Aug 14, always.
    func testPlayButtonNamesTheSelectedDay() throws {
        let app = launchPinned()
        let cell = openDailyCalendar(app, toCell: 13)   // Aug 14

        let play = app.buttons["daily.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "the Daily Play button is missing")
        cell.tap()

        XCTAssertTrue(play.label.contains("Aug 14"),
                      "the Play button does not name the selected day (Aug 14) — with the card header above the fold nothing says which day Play starts. Got: \(play.label)")
    }

    /// ux/WF-14:calendar-pip-unlabelled — the ⏰ same-day corner pip must be named
    /// in the calendar legend.
    func testCalendarLegendNamesTheSameDayPip() throws {
        let app = launchPinned()
        _ = openDailyCalendar(app, toCell: 14)   // today's cell — the legend sits by the grid

        XCTAssertTrue(app.staticTexts["⏰ Same-day"].waitForExistence(timeout: 5),
                      "the calendar legend no longer names the ⏰ corner pip — it is a bare gold dot, indistinguishable from the gold tier dot")
        XCTAssertTrue(app.staticTexts["🌟 Flawless"].exists,
                      "the legend lost its 🌟 entry — the whole legend row may have moved")
    }

    // MARK: - helpers

    /// Open the Daily sheet and scroll until the REQUESTED cell is hittable, returning it.
    /// Scrolls toward the actual target: "some landmark is hittable" proved nothing about the
    /// LazyVGrid, which materialises no cells until it is truly on screen — the legend could be
    /// tappable while the grid below it was still empty (skeptical-review R10).
    private func openDailyCalendar(_ app: XCUIApplication, toCell idx: Int) -> XCUIElement {
        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))
        let cell = app.buttons["daily.cal.\(idx)"]
        for _ in 0..<8 where !cell.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(cell.isHittable,
                      "calendar cell daily.cal.\(idx) never became hittable — the grid did not materialise (or the identifier is gone)")
        return cell
    }
}
