//
//  RegressionRailCueFlipsAtEndTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-12:rail-more-hint-inert   (TC-12.2, major)
//  Verified FIXED in qa-loop round 3 (build de5e5d0).
//
//  FIXED contract this test guards (Views/ContentView.swift landscapeRail / railCue /
//  RailEndTracker):
//   - The rail's overflow cue is a two-way toggle. At the END of the rail it reads
//     "⌃ top" (label "Back to the top of the controls") and a tap returns the rail to
//     its top with New game hittable again; at the top it reads "⌄ more" ("More
//     controls"). The end state is read from the scroll geometry, so a finger swipe
//     INSIDE the rail viewport flips the cue too. On 9ab79f1 the cue worked on the way
//     down only: at the end the label stayed "More controls", the chevron kept pointing
//     down and a second tap was a silent no-op while New game / Undo / Replay sat
//     off-screen (hittable=false) — the only on-screen affordance pointed the wrong way.
//
//  Original repro (round 2, QADriver; raw points are tester geometry, not a contract):
//    make_save --day 14 --tier silver | inject; launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15;
//    tap 'Not yet'; rotate landscapeLeft;
//    tapid toolbar.rail.more -> rail scrolls to end (toolbar.howtoplay 68,278 hittable=true;
//      toolbar.newgame 68,-13 hittable=false)
//    find toolbar.rail.more -> label STILL 'More controls'; 'more' with a down chevron
//    tapid toolbar.rail.more again -> nothing moves (toolbar.newgame still 68,-13)
//    swipe 127 316 127 380 (down, on the cue) -> rail back to top, toolbar.newgame 68,97
//    swipe 127 316 127 250 (up, on the cue) -> back to the end; cue text still 'more'
//    Round 3: both paths (cue tap, swipe inside the viewport) flip the cue and the
//    second tap returns the rail to the top with New game / Undo hittable.
//
//  Selector notes: toolbar.rail.more (label "More controls" / "Back to the top of the
//  controls"), toolbar.newgame, toolbar.undo, toolbar.autoplay, toolbar.howtoplay and
//  toolbar.finish are real identifiers (ContentView.landscapeRail). The device is iOS 26,
//  so the iOS 18+ onScrollGeometryChange branch is what the swipe leg exercises; the
//  iOS 17 RailOffsetKey fallback is not reachable here.
//
import XCTest

final class RegressionRailCueFlipsAtEndTests: XCTestCase {

    private let atTop = "More controls"
    private let atEnd = "Back to the top of the controls"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// ux/WF-12:rail-more-hint-inert — the cue flips at the end of the rail, a second
    /// tap returns to the top, and a swipe inside the viewport flips it too.
    func testRailCueFlipsToTopAtEndAndSecondTapReturnsToTop() throws {
        // Aug 15's own challenge parked at move 78: daily HUD + a live Finish pill = the
        // 8-pill rail (A2; 10 before) that overflows the landscape viewport (same fixture as
        // RegressionLandscapeRailMoreCueTests).
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
        let newGame = app.buttons["toolbar.newgame"]
        let undo = app.buttons["toolbar.undo"]
        let howToPlay = app.buttons["toolbar.finish"]   // A2: the rail's last pill (How to play is behind More)
        XCTAssertTrue(cue.waitForExistence(timeout: 5), "the rail has no overflow cue (toolbar.rail.more)")
        XCTAssertEqual(cue.label, atTop, "precondition: the cue starts in its 'more' state")
        XCTAssertTrue(newGame.isHittable, "precondition: New game is on screen at the top of the rail")
        XCTAssertFalse(howToPlay.isHittable, "precondition: How to play starts below the fold")

        // --- tap 1: to the end. The cue must FLIP, not merely scroll. -----------------
        cue.tap()
        XCTAssertTrue(QA.wait(5) { howToPlay.isHittable }, "the first tap did not scroll the rail to its end")
        XCTAssertTrue(QA.wait(3) { !newGame.isHittable },
                      "New game should be off-screen at the end of the rail (else the rail does not overflow)")
        XCTAssertTrue(QA.wait(3) { cue.label == atEnd },
                      "at the end of the rail the cue still says '\(cue.label)' — the '⌃ top' state is gone again")
        XCTAssertTrue(app.staticTexts["top"].exists && !app.staticTexts["more"].exists,
                      "the cue's visible text did not flip to 'top' at the end of the rail")

        // --- tap 2: back to the top. On 9ab79f1 this was a silent no-op. ---------------
        cue.tap()
        XCTAssertTrue(QA.wait(5) { newGame.isHittable },
                      "the second tap on the cue did not bring New game back — the cue is one-way again")
        XCTAssertTrue(undo.isHittable, "Undo must be reachable again after the second tap")
        XCTAssertTrue(QA.wait(3) { cue.label == atTop },
                      "back at the top the cue must read 'More controls' again, got '\(cue.label)'")
        XCTAssertTrue(QA.wait(3) { !howToPlay.isHittable },
                      "How to play should be below the fold again after returning to the top")

        // --- a finger swipe INSIDE the viewport flips the cue too (geometry-driven). ----
        // Drag from a rail pill upward: the rail's ScrollView owns swipes that start inside
        // the viewport, so this is the "swipe 127 300 127 150" path of the repro.
        let autoplay = app.buttons["toolbar.autoplay"]
        XCTAssertTrue(autoplay.exists)
        let from = autoplay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 0, dy: -220)))
        XCTAssertTrue(QA.wait(5) { howToPlay.isHittable }, "the in-viewport swipe did not scroll the rail")
        XCTAssertTrue(QA.wait(3) { cue.label == atEnd },
                      "after swiping to the end the cue still says '\(cue.label)' — the end state is not read from the scroll geometry")

        let howFrom = howToPlay.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        howFrom.press(forDuration: 0.05, thenDragTo: howFrom.withOffset(CGVector(dx: 0, dy: 220)))
        XCTAssertTrue(QA.wait(5) { newGame.isHittable }, "the downward swipe did not return the rail to its top")
        XCTAssertTrue(QA.wait(3) { cue.label == atTop },
                      "after swiping back to the top the cue still says '\(cue.label)'")
    }
}
