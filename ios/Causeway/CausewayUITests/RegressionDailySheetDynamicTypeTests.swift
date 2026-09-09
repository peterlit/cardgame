//
//  RegressionDailySheetDynamicTypeTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-5:daily-sheet-ignores-dynamic-type   (TC-5.1, minor)
//  Verified FIXED in qa-loop round 2 (build 9ab79f1).
//
//  FIXED contract this test guards (Views/DailyView.swift `f(_:)` → Theme.scaled):
//   - Every piece of the Daily sheet's own text follows Dynamic Type. Before the fix
//     the streak cards ('day streak', '1 total', 'best 1' at 9–11 pt), the legend and
//     the objective rows were pixel-identical at Accessibility XXXL while the SF-Symbol
//     tier checks in the same rows grew 17 → 53 pt. At accessibility sizes the streak
//     grid also drops 3 → 2 → 1 column so the scaled captions never truncate.
//
//  Original repro (round 1, QADriver):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15; tapid toolbar.daily; labels any
//    (streak card 118×103, 'day streak' 48×11, objective row text 200×28);
//    xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large;
//    labels any → same text frames; only #checkmark.circle.fill grew 17×17 → 53×53.
//
//  The size is injected per launch through UIKit's standard
//  `-UIPreferredContentSizeCategoryName` argument — never `simctl ui content_size`,
//  which would leave a shared simulator at AX5 for every other test. Selector notes:
//  daily.streak.<key> (keys: play / ontime / silver / gold / flawless) and
//  daily.tier.<tier> are real identifiers.
//
import XCTest

final class RegressionDailySheetDynamicTypeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-5:daily-sheet-ignores-dynamic-type — the streak cards and the objective
    /// rows grow at Accessibility XXXL, and the streak grid collapses to one column.
    func testDailySheetTextGrowsAtAccessibilityXXXL() throws {
        // --- baseline: the default size --------------------------------------------
        let base = QA.launch()
        QA.openDaily(base)
        let basePlay = base.descendants(matching: .any)["daily.streak.play"]
        let baseOnTime = base.descendants(matching: .any)["daily.streak.ontime"]
        XCTAssertTrue(basePlay.waitForExistence(timeout: 5), "no daily.streak.play card")
        let baseCardH = basePlay.frame.height
        let baseRowH = base.descendants(matching: .any)["daily.tier.silver"].frame.height
        XCTAssertGreaterThan(baseOnTime.frame.minX, basePlay.frame.minX + 20,
                             "precondition: at the default size the streak cards sit side by side")
        XCTAssertGreaterThan(baseCardH, 0)
        XCTAssertGreaterThan(baseRowH, 0)
        base.terminate()

        // --- Accessibility XXXL -------------------------------------------------------
        let big = QA.app()
        big.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .portrait
        big.launch()
        XCTAssertTrue(big.buttons["toolbar.deal"].waitForExistence(timeout: 10), "the board never appeared at AX5")
        QA.openDaily(big)
        let bigPlay = big.descendants(matching: .any)["daily.streak.play"]
        let bigOnTime = big.descendants(matching: .any)["daily.streak.ontime"]
        XCTAssertTrue(bigPlay.waitForExistence(timeout: 5), "no daily.streak.play card at AX5")

        XCTAssertGreaterThan(bigPlay.frame.height, baseCardH * 1.6,
                             "the streak card did not grow at AX5 (\(baseCardH) → \(bigPlay.frame.height) pt): its captions are fixed-size again")
        XCTAssertEqual(bigOnTime.frame.minX, bigPlay.frame.minX, accuracy: 1,
                       "the streak grid did not drop to one column at AX5 (ontime at x=\(bigOnTime.frame.minX), play at x=\(bigPlay.frame.minX))")
        let bigRow = big.descendants(matching: .any)["daily.tier.silver"]
        XCTAssertTrue(bigRow.exists, "no daily.tier.silver row at AX5")
        XCTAssertGreaterThan(bigRow.frame.height, baseRowH * 1.6,
                             "the objective row did not grow at AX5 (\(baseRowH) → \(bigRow.frame.height) pt): 53-pt checks beside 12-pt text again")
    }
}
