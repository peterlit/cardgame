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
//   - The gold Play button NAMES the day it will start ("Play Aug 3"): at the
//     calendar scroll position the day-card header that identifies the selection
//     is above the fold, so a mis-tapped 44x33 pt cell used to start the wrong
//     day's deal with nothing on screen to catch it.
//   - The calendar legend names the ⏰ same-day corner pip — five marker types
//     are drawn in the grid and the legend named four, and the unnamed one is a
//     bare gold dot the same size and colour as the gold TIER dot.
//
//  Original repro (round-1, coordinates are tester geometry — NOT a contract):
//    cold launch → Daily (290,175) → swipe (200,700)→(200,300) → tap Aug 3
//    (94,515) → tap Aug 31 (94,691): nothing changes at all — no tint, no
//    message, and the day card still shows Aug 3.  Read the row right of
//    "August 2026": the ⏰ pip is not in the legend.
//
//  Selector notes (mined from Views/DailyView.swift on 4f02d1d):
//   - "toolbar.daily", "daily.play", "daily.lockednote" — real identifiers.
//   - CALENDAR CELLS HAVE NO IDENTIFIER. They carry .accessibilityLabel only —
//     dayLabel(idx) ("Aug 3"), or "<day>, locked until that date" when locked —
//     applied to a ZStack that is not marked as one accessibility element, so
//     the query below is the brittle part of this file. Follow-up recommending
//     "daily.cal.<dayIndex>" (+ .accessibilityElement(children: .combine)) filed
//     in .qa-loop/fragments/round-2-regression.json.
//   - The legend row is plain Text; queried by its verbatim "⏰ Same-day".
//
import XCTest

final class RegressionDailyCalendarTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-13:future-day-tap-no-feedback — a locked (future, in-pool) cell must
    /// answer the tap with a dated explanation instead of swallowing it.
    func testTappingALockedFutureDayExplainsWhy() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openDailyCalendar(app)

        // Locked cells announce themselves — no date arithmetic needed.
        let locked = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label ENDSWITH %@", "locked until that date"))
            .firstMatch
        try XCTSkipUnless(locked.waitForExistence(timeout: 5),
                          "no future in-pool day on screen (calendar past the end of the pool?)")

        XCTAssertFalse(app.staticTexts["daily.lockednote"].exists,
                       "the locked note must appear in ANSWER to a tap, not stand permanently")
        locked.tap()

        let note = app.staticTexts["daily.lockednote"]
        XCTAssertTrue(note.waitForExistence(timeout: 3),
                      "a tap on a future day was swallowed with zero feedback — the round-1 bug is back")
        XCTAssertTrue(note.label.contains("unlocks on the day itself"),
                      "the note must say WHY the day cannot be opened, got: \(note.label)")
    }

    /// ux/WF-13:selected-day-invisible-at-play — the Play button must name the
    /// day it will start whenever that day is not today.
    func testPlayButtonNamesTheSelectedDay() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // Yesterday, in the app's own "MMM d" wording (Daily.dayLabel). Must be
        // inside the pool, which starts on 2026-08-01.
        let cal = Calendar(identifier: .gregorian)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: Date()),
              let epoch = cal.date(from: DateComponents(year: 2026, month: 8, day: 1)),
              cal.startOfDay(for: yesterday) >= cal.startOfDay(for: epoch) else {
            throw XCTSkip("yesterday is before the daily pool's first day — no past day to select")
        }
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        let dayName = fmt.string(from: yesterday)

        openDailyCalendar(app)
        let play = app.buttons["daily.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5), "the Daily Play button is missing")

        // Calendar cells are 40 pt tall; the day-card header and any "Unlocks …"
        // text carry the same wording, so pick the shortest matching element.
        let candidates = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", dayName))
            .allElementsBoundByIndex
            .filter { $0.frame.height > 0 }
            .sorted { $0.frame.height < $1.frame.height }
        try XCTSkipUnless(!candidates.isEmpty, "no calendar cell for \(dayName) on screen")
        candidates[0].tap()

        XCTAssertTrue(play.label.contains(dayName),
                      "the Play button does not name the selected day (\(dayName)) — with the card header above the fold nothing says which day Play starts. Got: \(play.label)")
    }

    /// ux/WF-14:calendar-pip-unlabelled — the ⏰ same-day corner pip must be named
    /// in the calendar legend.
    func testCalendarLegendNamesTheSameDayPip() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openDailyCalendar(app)

        XCTAssertTrue(app.staticTexts["⏰ Same-day"].waitForExistence(timeout: 5),
                      "the calendar legend no longer names the ⏰ corner pip — it is a bare gold dot, indistinguishable from the gold tier dot")
        XCTAssertTrue(app.staticTexts["🌟 Flawless"].exists,
                      "the legend lost its 🌟 entry — the whole legend row may have moved")
    }

    // MARK: - helpers

    /// Open the Daily sheet and scroll down to the month grid.
    private func openDailyCalendar(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))
        // The calendar sits below the streak cards and the day card.
        for _ in 0..<3 where !app.staticTexts["⏰ Same-day"].exists {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }
}
