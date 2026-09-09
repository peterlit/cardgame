//
//  RegressionDealEntryRangeTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-9:deal-entry-out-of-range-silent
//  Verified FIXED in qa-loop round 2 (build 4f02d1d) by TC-9.3.
//
//  FIXED contract this test guards:
//   - Wins ▸ "Play a deal": typing a number outside 1–1,000,000 leaves Play
//     disabled AND says why, in a red line under the field
//     (WinsView.entryProblem → "Deal numbers run 1–1,000,000.").
//   - An EMPTY field stays quiet: Play is legitimately disabled and nothing is
//     wrong yet, so no error line (`guard !typed.isEmpty` in entryProblem).
//   - The bound is REJECTED, never silently clamped: an out-of-range entry can
//     not be played at all (Game.deal's old clamp dealt a different board).
//
//  Original repro (round-1, coordinates are tester geometry — NOT a contract):
//    launch → tap Wins (338,172) → tap the "Play a deal" field (164,186) →
//    type 2000000 → OBSERVED: field reads 2000000, Play is disabled, no error
//    text, and the placeholder that carried the only statement of the legal
//    range has been replaced by the typed text — nothing on screen names the
//    bound.
//
//  Selector notes (mined from Views/WinsView.swift on 4f02d1d):
//   - error line:  "wins.dealentry.problem" (accessibilityIdentifier, real)
//   - toolbar:     "toolbar.wins" (ContentView.toolbar / landscapeRail)
//   - field / Play:  "wins.dealentry.field" / "wins.dealentry.play" (landed 836434d;
//     before that they were matched by placeholder and by the label "Play").
//
import XCTest

final class RegressionDealEntryRangeTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-9:deal-entry-out-of-range-silent — an out-of-range deal number must
    /// say why Play is dead, and an empty field must stay quiet.
    func testOutOfRangeDealNumberExplainsWhyPlayIsDisabled() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.wins"].waitForExistence(timeout: 5))
        app.buttons["toolbar.wins"].tap()
        XCTAssertTrue(app.navigationBars["Deals won"].waitForExistence(timeout: 5),
                      "Wins sheet did not open")

        let field = app.textFields["wins.dealentry.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "'Play a deal' field not found")

        let problem = app.staticTexts["wins.dealentry.problem"]
        let play = app.buttons["wins.dealentry.play"]

        // --- empty field: quiet, and Play legitimately disabled ---------------
        XCTAssertFalse(problem.exists,
                       "an empty field must not show an error — nothing has been typed yet")
        XCTAssertFalse(play.isEnabled, "Play must be disabled with nothing entered")

        // --- out of range: Play still dead, but the reason is on screen -------
        field.tap()
        field.typeText("2000000")
        XCTAssertTrue(problem.waitForExistence(timeout: 3),
                      "out-of-range entry left Play disabled with no explanation — the round-1 bug is back")
        XCTAssertTrue(problem.label.contains("1–1,000,000"),
                      "the error must name the legal range, got: \(problem.label)")
        XCTAssertFalse(play.isEnabled,
                       "an out-of-range deal must be REJECTED, never clamped into a different deal")

        // --- back in range: the error clears and Play comes alive -------------
        // Delete the 7 typed digits rather than assuming a Select All menu.
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        field.typeText("777")
        XCTAssertFalse(problem.exists, "a legal deal number must clear the error line")
        XCTAssertTrue(play.isEnabled, "a legal deal number must enable Play")
    }
}
