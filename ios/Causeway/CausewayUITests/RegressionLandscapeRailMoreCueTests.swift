//
//  RegressionLandscapeRailMoreCueTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-12:rail-hides-howtoplay   (TC-12.2, major)
//  Verified FIXED in qa-loop round 2 (build 9ab79f1).
//
//  FIXED contract this test guards (Views/ContentView.swift, landscapeRail / railCue):
//   - With the daily HUD and a live Finish pill the landscape rail holds 10 pills in a
//     207 pt viewport, so Daily / Wins / How to play start below the fold. The "⌄ more"
//     cue under the viewport is a REAL rail-width control (toolbar.rail.more, label
//     "More controls"): one tap scrolls the rail to its end and makes the hidden pills
//     hittable, and the cue flips to "Back to the top of the controls". Before the fix
//     it was a 25×12 pt glyph with allowsHitTesting(false): tapping or swiping it did
//     nothing, and the three pills looked simply absent.
//
//  Original repro (round 1, raw points kept for the record):
//    inject make_save --day 14 --tier silver; launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15;
//    tap 127 497 (Not yet); rotate landscapeLeft; find toolbar.howtoplay → hittable=false
//    (frame 68,388,118,26); tap 126 336 (the '⌄ more' cue) → rail unchanged;
//    swipe 110 335 110 200 (from the cue) → rail unchanged.
//    Round 2: tapid toolbar.rail.more → rail scrolls to the end; toolbar.howtoplay
//    hittable=true; tapid toolbar.howtoplay → the How to play sheet opens.
//
//  Selector notes: toolbar.rail.more / toolbar.howtoplay / toolbar.finish are real
//  identifiers (ContentView.railCue / landscapeRail); the sheet is found by its
//  navigation title "How to play" (Views/Extras.swift).
//
import XCTest

final class RegressionLandscapeRailMoreCueTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// ux/WF-12:rail-hides-howtoplay — the overflow cue is a working control that
    /// reveals How to play in one tap.
    func testRailMoreCueIsARealControlThatRevealsHowToPlay() throws {
        // Aug 15's own challenge parked at move 78: daily HUD + a live Finish pill = 10 pills.
        let app = QA.launch(game: QA.day14Silver)
        let prompt = app.alerts["Ready to finish"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10),
                      "fixture precondition: the restore must raise 'Ready to finish'")
        prompt.buttons["Not yet"].tap()
        XCTAssertTrue(QA.waitGone(prompt, timeout: 3))
        XCTAssertTrue(app.buttons["toolbar.finish"].waitForExistence(timeout: 5),
                      "fixture precondition: the Finish pill must be live (that is the 10th pill)")

        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height },
                      "rotation to landscape never took effect")

        let cue = app.buttons["toolbar.rail.more"]
        XCTAssertTrue(cue.waitForExistence(timeout: 5),
                      "the rail has no overflow cue (toolbar.rail.more) — the hidden pills are invisible again")
        XCTAssertTrue(cue.isHittable, "the '⌄ more' cue is not hittable — allowsHitTesting(false) is back")
        XCTAssertEqual(cue.label, "More controls",
                       "the cue must announce itself as 'More controls' while the rail is at its top, got '\(cue.label)'")
        XCTAssertGreaterThan(cue.frame.width, 60,
                             "the cue shrank back to a glyph-sized target (\(cue.frame.width) pt wide)")

        let howToPlay = app.buttons["toolbar.howtoplay"]
        XCTAssertTrue(howToPlay.exists, "the rail lost its How to play pill entirely")
        XCTAssertFalse(howToPlay.isHittable,
                       "precondition: How to play must START below the fold (else the cue has nothing to prove): \(howToPlay.frame)")

        cue.tap()
        XCTAssertTrue(QA.wait(5) { howToPlay.isHittable },
                      "tapping the cue did not scroll the rail — How to play is still unreachable in one tap")
        XCTAssertTrue(QA.wait(3) { cue.label == "Back to the top of the controls" },
                      "the cue did not flip to its 'top' state after scrolling to the end: '\(cue.label)'")

        howToPlay.tap()
        XCTAssertTrue(app.navigationBars["How to play"].waitForExistence(timeout: 5),
                      "How to play did not open from the revealed pill")
    }
}
