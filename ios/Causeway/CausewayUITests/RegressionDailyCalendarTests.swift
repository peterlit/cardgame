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
//   - SKIP POLICY: a skip in this file may only be keyed on the CALENDAR
//     DATE — which days this month's grid can possibly draw. It may NEVER be
//     keyed on a locator the fix introduces (e.g. "locked until that date"):
//     such a tripwire goes GREEN-BY-SKIP the moment the fix is deleted
//     (tests/RegressionDailyCalendarTests.swift:skip-instead-of-fail).
//
import XCTest

final class RegressionDailyCalendarTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-13:future-day-tap-no-feedback — a locked (future, in-pool) cell must
    /// answer the tap with a dated explanation instead of swallowing it.
    func testTappingALockedFutureDayExplainsWhy() throws {

        // The precondition is decided by the DATE, never by the fix's own locator. This used to
        // skip when no element was labelled "…locked until that date" — the label the fix adds —
        // so deleting the fix turned the test green-by-skip. The grid draws the current month
        // only, so a future cell exists exactly when today is not the last day of the month.
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: now),
              cal.component(.month, from: tomorrow) == cal.component(.month, from: now) else {
            throw XCTSkip("today is the last day of the month — the grid shows this month only, so it holds no future cell")
        }
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"    // Daily.dayLabel's wording
        let dayName = fmt.string(from: tomorrow)

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openDailyCalendar(app)

        _ = app.staticTexts["⏰ Same-day"].waitForExistence(timeout: 5)   // let the grid render

        // Tomorrow's cell. A SEEDED future day is labelled "<day>, locked until that date"; a day
        // past the end of the pool keeps the plain "<day>". Either way the tap must be answered,
        // so match both and assert — a missing cell is a failure, not a skip. The day card carries
        // the same wording, so take the shortest match (cells are 40 pt tall).
        let cells = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR label BEGINSWITH %@", dayName, dayName + ","))
            .allElementsBoundByIndex
            .filter { $0.frame.height > 0 }
            .sorted { $0.frame.height < $1.frame.height }
        XCTAssertFalse(cells.isEmpty,
                       "no calendar cell for \(dayName) — the month grid, or the accessibility labels on its cells, is gone")

        XCTAssertFalse(app.staticTexts["daily.lockednote"].exists,
                       "the locked note must appear in ANSWER to a tap, not stand permanently")
        cells[0].tap()

        let note = app.staticTexts["daily.lockednote"]
        XCTAssertTrue(note.waitForExistence(timeout: 3),
                      "a tap on a future day was swallowed with zero feedback — the round-1 bug is back")
        XCTAssertTrue(note.label.contains("unlocks on the day itself") || note.label.contains("No challenge on"),
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
        // Yesterday is in THIS month's grid unless today is the 1st — again a date decision, so a
        // calendar that lost its cells (or their labels) fails here instead of skipping.
        if cal.component(.day, from: Date()) == 1 {
            try XCTSkipIf(candidates.isEmpty, "today is the 1st — yesterday belongs to last month, which the grid does not draw")
        }
        XCTAssertFalse(candidates.isEmpty,
                       "no calendar cell for \(dayName) — the month grid, or the accessibility labels on its cells, is gone")
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
        // The calendar sits below the streak cards and the day card. Scroll until the legend is
        // HITTABLE, not merely present: an off-screen element still reports `exists`, so the old
        // `.exists` loop stopped after zero swipes with the grid still below the fold — and the
        // grid is a LazyVGrid, which materialises no cells (not even its weekday header) until it
        // is on screen. Every "no calendar cell for <day>" failure this class has produced came
        // from that, not from the grid being broken.
        for _ in 0..<6 where !app.staticTexts["⏰ Same-day"].isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
    }
}
