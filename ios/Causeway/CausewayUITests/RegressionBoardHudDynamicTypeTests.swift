//
//  RegressionBoardHudDynamicTypeTests.swift
//  CausewayUITests
//
//  Regression tripwire for: a11y/DailyView.swift:dynamic-type-stops-at-the-sheet (minor)
//
//  FIXED contract this test guards (DailyHUD.objChip, ContentView.demoHeadlineText — Theme.scaled):
//   - The in-game objective chips and the demo bar's headline follow Dynamic Type, as the
//     Daily sheet already did (ux/WF-5:daily-sheet-ignores-dynamic-type). Before the fix they
//     were hard 10 / 11 / 12.5 pt: a low-vision player could read what Gold requires on the
//     sheet and then not on the board, the only place it shows during the attempt that scores it.
//   - Landscape: the board's height budget subtracts the bar's MEASURED height (was a fixed
//     50 pt estimate), so the scaled, stacked HUD does not push the rail's bottom off-screen.
//
//  Observable: the Gold chip label / demo headline is more than 1.6× taller at Accessibility
//  XXXL than at the default size (mirrors RegressionDailySheetDynamicTypeTests); in landscape the
//  rail's bottom edge (its "more" cue when it overflows, else its last pill) stays inside the window.
//
//  Selector notes: "hud.chip.gold.label", "demo.headline", "daily.play", "daily.demo.bronze",
//  "toolbar.rail.more", "toolbar.howtoplay". Dynamic Type is set with the
//  `-UIPreferredContentSizeCategoryName` launch argument (per-launch; never simctl ui content_size).
//
import XCTest

final class RegressionBoardHudDynamicTypeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    private func launchAX5() -> XCUIApplication {
        let big = QA.app(autoplay: false)
        big.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        XCUIDevice.shared.orientation = .portrait
        big.launch()
        XCTAssertTrue(big.buttons["toolbar.deal"].waitForExistence(timeout: 10), "the board never appeared at AX5")
        return big
    }

    private func playToday(_ app: XCUIApplication) {
        QA.openDaily(app)
        app.buttons["daily.play"].tap()
        let gold = app.staticTexts["hud.chip.gold.label"]
        XCTAssertTrue(gold.waitForExistence(timeout: 5), "no Gold chip label on the HUD")
        XCTAssertEqual(gold.label, "Take at least 10 of every suit from the King end")
    }

    /// The HUD chips scale; in landscape the measured bar keeps the rail on-screen.
    func testHudChipsFollowDynamicTypeAndLandscapeRailStaysOnScreen() throws {
        let base = QA.launch(autoplay: false)
        playToday(base)
        let baseH = base.staticTexts["hud.chip.gold.label"].frame.height
        XCTAssertGreaterThan(baseH, 0)
        base.terminate()

        let big = launchAX5()
        playToday(big)
        let gold = big.staticTexts["hud.chip.gold.label"]
        XCTAssertGreaterThan(gold.frame.height, baseH * 1.6,
                             "the Gold chip label did not grow at AX5 (\(baseH) → \(gold.frame.height) pt): the HUD is fixed-size again")
        let window = big.windows.firstMatch
        XCTAssertLessThanOrEqual(gold.frame.maxX, window.frame.maxX + 0.5, "portrait AX5: the Gold label runs off the window")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "rotation to landscape never took effect")
        XCTAssertTrue(QA.wait(3) { gold.exists && gold.frame.height > baseH * 1.6 }, "landscape AX5: the Gold chip label lost its size")
        let cue = big.buttons["toolbar.rail.more"], last = big.buttons["toolbar.howtoplay"]
        XCTAssertTrue(QA.wait(3) { cue.exists || last.exists }, "landscape AX5: neither the rail cue nor its last pill is on screen")
        let railBottom = cue.exists ? cue : last
        XCTAssertLessThanOrEqual(railBottom.frame.maxY, window.frame.maxY + 0.5,
                                 "landscape AX5: the rail's bottom (\(railBottom.identifier)) is pushed off the window by the scaled HUD — the board budget is not subtracting the bar's real height")
        XCTAssertGreaterThan(railBottom.frame.minY, gold.frame.maxY - 0.5,
                             "landscape AX5: the rail overlaps the HUD")
    }

    /// The demo bar's headline scales.
    func testDemoHeadlineFollowsDynamicType() throws {
        let base = QA.launch()
        QA.openDaily(base)
        let clear = base.buttons["daily.demo.bronze"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "no 🥉 Clear pill — no baked line for the pinned today?")
        clear.tap()
        let baseHeadline = base.staticTexts["demo.headline"]
        XCTAssertTrue(baseHeadline.waitForExistence(timeout: 5), "the demo bar did not open")
        let baseH = baseHeadline.frame.height
        XCTAssertGreaterThan(baseH, 0)
        base.terminate()

        let big = launchAX5()
        QA.openDaily(big)
        // At AX5 the sheet is several screens tall and the day card's demo pills sit below the
        // fold: scroll toward the pill (the fixtures' pattern), never toward a landmark.
        let bigClear = big.buttons["daily.demo.bronze"]
        for _ in 0..<8 where !bigClear.isHittable {
            big.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(bigClear.isHittable, "no 🥉 Clear pill at AX5 (never became hittable)")
        bigClear.tap()
        let headline = big.staticTexts["demo.headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the demo bar did not open at AX5")
        XCTAssertGreaterThan(headline.frame.height, baseH * 1.6,
                             "the demo headline did not grow at AX5 (\(baseH) → \(headline.frame.height) pt): it is fixed-size again")
        XCTAssertLessThanOrEqual(headline.frame.maxX, big.windows.firstMatch.frame.maxX + 0.5, "AX5: the headline runs off the window")
    }
}
