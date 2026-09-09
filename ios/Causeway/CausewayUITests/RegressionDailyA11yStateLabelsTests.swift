//
//  RegressionDailyA11yStateLabelsTests.swift
//  CausewayUITests
//
//  Regression tripwires for:
//    ux/WF-13:calendar-cells-no-state-in-a11y-label   (TC-13.2, minor)
//    ux/WF-13:day-card-tier-state-unlabelled          (TC-13.6, minor)
//  Both verified FIXED in qa-loop round 2 (build 9ab79f1).
//
//  FIXED contracts these tests guard (Views/DailyView.swift):
//   - calCellLabel: every calendar cell says in words what it DRAWS — "today",
//     "selected", "locked until that date", "earned Bronze, Silver", "Flawless, all
//     three medals in one run", "cleared on the day", "not yet cleared" — joined
//     with ", " after the date. Before the fix every unlocked cell was a bare date
//     while locked cells alone announced their state.
//   - tierRow: the state indicator announces "earned" / "missed" / "not attempted"
//     (and "not yet available" for a future day) instead of the SF Symbol defaults
//     ("Selected" for earned, "circle" for both missed and never-attempted), and the
//     row (daily.tier.<tier>) carries the state as its value ("earned" / "open").
//
//  Original repros (round 1, QADriver):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15; tapid toolbar.daily; swipe up;
//    tapid daily.cal.2 → find daily.cal.2 = 'Aug 3' (selected: not announced);
//    find daily.cal.14 = 'Aug 15' (today: not announced);
//    find daily.cal.15 = 'Aug 16, locked until that date' (the asymmetry).
//    tapid daily.cal.3 (Aug 4, never played) → labels images = 3× '#circle circle';
//    solve Aug 6 bronze-only → tapid daily.cal.5 → '#checkmark.circle.fill Selected'
//    + 2× '#circle circle' (rendered RED = missed, labelled like never-attempted).
//
//  THE CLOCK IS PINNED to 2026-08-15 and the daily store is SEEDED through the
//  launch arguments (QAFixtures): the solved days are records, not play-throughs.
//  Selector notes: daily.cal.<idx> / daily.tier.<tier> are real identifiers.
//
import XCTest

final class RegressionDailyA11yStateLabelsTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Aug 6 (index 5) banked 🥉🥈 in one run; Aug 14 (index 13) was flawless AND cleared on
    /// its own day. Everything else in the pool is untouched.
    private let seededDaily = #"{"version":3,"days":{"5":{"bronze":true,"silver":true,"gold":false,"flawless":false,"onTime":false,"moves":97,"elapsed":100,"runs":[{"moves":97,"elapsed":100}]},"13":{"bronze":true,"silver":true,"gold":true,"flawless":true,"onTime":true,"moves":79,"elapsed":95,"runs":[{"moves":79,"elapsed":95}]}}}"#

    /// Aug 6 (index 5) cleared bronze-only: Silver and Gold were attempted and MISSED.
    private let bronzeOnlyDaily = #"{"version":3,"days":{"5":{"bronze":true,"silver":false,"gold":false,"flawless":false,"onTime":false,"moves":97,"elapsed":100,"runs":[{"moves":97,"elapsed":100}]}}}"#

    /// ux/WF-13:calendar-cells-no-state-in-a11y-label — today, selection, lock, earned
    /// tiers, flawless and same-day are all spoken, and selection follows the tap.
    func testCalendarCellsAnnounceTheirState() throws {
        let app = QA.launch(daily: seededDaily)
        QA.openDaily(app)

        QA.scrollToCalendarCell(app, 2).tap()   // select Aug 3
        let cell = { (i: Int) in app.buttons["daily.cal.\(i)"] }
        XCTAssertTrue(QA.wait(3) { cell(2).label == "Aug 3, selected, not yet cleared" },
                      "the selected cell does not announce 'selected' — got '\(cell(2).label)'")
        XCTAssertEqual(cell(14).label, "Aug 15, today, not yet cleared",
                       "today's cell does not announce 'today' (or lost its clear state)")
        XCTAssertEqual(cell(15).label, "Aug 16, locked until that date",
                       "the locked phrase RegressionDailyCalendarTests keys on must stay byte-identical")
        XCTAssertEqual(cell(0).label, "Aug 1, not yet cleared",
                       "an unlocked, never-cleared cell must say so, not read as a bare date")
        XCTAssertEqual(cell(5).label, "Aug 6, earned Bronze, Silver",
                       "a cleared day must name the tiers it earned")
        XCTAssertEqual(cell(13).label, "Aug 14, Flawless, all three medals in one run, cleared on the day",
                       "a flawless, same-day clear must announce both")

        // Selection is dynamic: it moves with the tap and leaves the previous cell.
        cell(5).tap()
        XCTAssertTrue(QA.wait(3) { cell(5).label == "Aug 6, selected, earned Bronze, Silver" },
                      "selecting Aug 6 did not add 'selected' to its label — got '\(cell(5).label)'")
        XCTAssertEqual(cell(2).label, "Aug 3, not yet cleared",
                       "Aug 3 kept 'selected' after the selection moved to Aug 6")
    }

    /// ux/WF-13:day-card-tier-state-unlabelled — the tier indicator says earned / missed /
    /// not attempted, never the symbol's default "Selected" / "circle".
    func testDayCardTierIndicatorsAnnounceEarnedMissedNotAttempted() throws {
        let app = QA.launch(daily: bronzeOnlyDaily)

        // Aug 4 (index 3): never played → three neutral rings, all "not attempted".
        QA.selectCalendarDay(app, 3)
        for tier in ["bronze", "silver", "gold"] {
            XCTAssertEqual(tierState(app, tier), "not attempted",
                           "\(tier) on a never-played day must announce 'not attempted'")
            XCTAssertEqual(tierValue(app, tier), "open", "\(tier) row value on a never-played day")
        }

        // Aug 6 (index 5): bronze banked, silver + gold attempted and missed.
        QA.scrollToCalendarCell(app, 5).tap()
        XCTAssertTrue(QA.wait(3) { self.tierValue(app, "bronze") == "earned" },
                      "the Bronze row did not become 'earned' after selecting the cleared day")
        XCTAssertEqual(tierState(app, "bronze"), "earned",
                       "an earned tier must announce 'earned' (the symbol default was 'Selected')")
        XCTAssertEqual(tierState(app, "silver"), "missed",
                       "a missed tier must announce 'missed' — the red ring was labelled like a grey one")
        XCTAssertEqual(tierState(app, "gold"), "missed",
                       "a missed tier must announce 'missed' — the red ring was labelled like a grey one")
        XCTAssertEqual(tierValue(app, "silver"), "open")
    }

    // MARK: - helpers

    private func tierRow(_ app: XCUIApplication, _ tier: String) -> XCUIElement {
        app.descendants(matching: .any)["daily.tier.\(tier)"]
    }

    /// The state the row's indicator announces (its accessibility label).
    private func tierState(_ app: XCUIApplication, _ tier: String) -> String {
        let row = tierRow(app, tier)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "no daily.tier.\(tier) row on the day card")
        let states = ["earned", "missed", "not attempted", "not yet available", "Selected", "circle"]
        let mark = row.descendants(matching: .any)
            .matching(NSPredicate(format: "label IN %@", states)).firstMatch
        return mark.exists ? mark.label : "<no state indicator in daily.tier.\(tier)>"
    }

    private func tierValue(_ app: XCUIApplication, _ tier: String) -> String {
        (tierRow(app, tier).value as? String) ?? "<no value>"
    }
}
