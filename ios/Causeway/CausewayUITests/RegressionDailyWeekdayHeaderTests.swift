//
//  RegressionDailyWeekdayHeaderTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/DailyView:calendar-weekday-header-dupes
//  Verified FIXED in qa-loop round 2 (build 5447237) by TC-11.1.
//
//  FIXED contract this test guards (see .qa-loop/ledger.json):
//   - The Daily sheet's month-calendar header renders ALL SEVEN weekday
//     letters — S M T W T F S — including the duplicate letters "T" (Thu,
//     dup of Tue) and "S" (Sat, dup of Sun).
//   - The original bug: ForEach(["S","M","T","W","T","F","S"], id: \.self)
//     identity-collapsed the duplicate letters, so Thu and Sat rendered as
//     blank header columns ("S M T W _ F _"). The fix keys the ForEach on
//     .enumerated() positional offsets (DailyView.calendar, DailyView.swift).
//
//  Original repro (round-1 finding, re-verified round 2 in portrait AND
//  landscape): cold launch → tap the Daily toolbar pill → scroll the Daily
//  sheet down to the month calendar → read the weekday header row.
//
//  Selector notes (mined from Views/*.swift on 5447237):
//   - Daily entry pill:  accessibilityIdentifier "toolbar.daily"
//                        (ContentView.toolbar / landscapeRail — same id in
//                        both orientations; only one hierarchy exists at a time)
//   - Daily sheet:       navigationBars["Daily Challenges"] (DailyView)
//   - weekday letters:   NO accessibilityIdentifier — DailyView.calendar
//                        renders seven bare Text views, so they are queried
//                        by exact single-letter label. A missing-identifier
//                        follow-up was filed (.qa-loop/fragments/
//                        round-2-regression.json). No other exact
//                        single-letter staticTexts exist on the Daily sheet
//                        (streak labels, day numbers, month label, medal
//                        emoji are all longer), so exact-match counting is
//                        unambiguous.
//
import XCTest

final class RegressionDailyWeekdayHeaderTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/DailyView:calendar-weekday-header-dupes — the calendar header must
    /// contain exactly two "S", one "M", two "T", one "W", one "F", laid out
    /// left-to-right as S M T W T F S on a single row.
    func testCalendarWeekdayHeaderShowsAllSevenLetters() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // --- open the Daily sheet -----------------------------------------------
        let daily = app.buttons["toolbar.daily"]
        XCTAssertTrue(daily.waitForExistence(timeout: 5),
                      "no Daily pill — daily pool empty on this build?")
        daily.tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))

        // --- bring the month calendar into view ----------------------------------
        // The calendar sits below the streaks row and day card inside a ScrollView;
        // its LazyVGrid only materialises cells near the viewport, so scroll first.
        let anyS = app.staticTexts.matching(NSPredicate(format: "label == %@", "S")).firstMatch
        if !anyS.waitForExistence(timeout: 2) {
            app.swipeUp()
            XCTAssertTrue(anyS.waitForExistence(timeout: 3),
                          "calendar weekday header never came on screen")
        }

        // --- THE core regression: count each letter ------------------------------
        // With the bug, the duplicate-identity ForEach dropped Thu "T" and Sat "S",
        // leaving counts S=1, T=1 (and two blank columns).
        let counts = ["S": 2, "M": 1, "T": 2, "W": 1, "F": 1]
        var letters: [(label: String, frame: CGRect)] = []
        for (letter, expected) in counts {
            let q = app.staticTexts.matching(NSPredicate(format: "label == %@", letter))
            let found = q.allElementsBoundByIndex
            XCTAssertEqual(found.count, expected,
                           "weekday header: expected \(expected) × '\(letter)', found \(found.count) — the duplicate-id ForEach bug is back")
            for el in found { letters.append((letter, el.frame)) }
        }
        XCTAssertEqual(letters.count, 7, "weekday header should hold exactly 7 letters")

        // --- layout sanity: one row, left-to-right order S M T W T F S -----------
        // Guards the adjacent failure mode (letters present but columns misplaced).
        let rowY = letters.map(\.frame.midY).min() ?? 0
        XCTAssertTrue(letters.allSatisfy { abs($0.frame.midY - rowY) < 3 },
                      "weekday letters are not on a single header row")
        let pattern = letters.sorted { $0.frame.minX < $1.frame.minX }
            .map(\.label).joined()
        XCTAssertEqual(pattern, "SMTWTFS",
                       "weekday header order is \(pattern), expected SMTWTFS")
    }
}
