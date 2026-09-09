//
//  RegressionExportProgressNoteTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-11:export-picker-no-progress-indicator (minor)
//  Fixed on 5447237 (archived ledger 20260822-125736-f949d82); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (DailyView's BACKUP section):
//   - Tapping Export (or Import) acknowledges the tap at once: the note line under the
//     two buttons flips to "Opening Files…" before the Files sheet slides up (which on a
//     cold launch takes ~1.6–1.8 s with nothing else on screen changing).
//
//  Original repro (round-1 tester): cold launch → Daily → scroll to BACKUP → tap Export →
//   press highlight for ~0.4 s, then a byte-for-byte frozen screen for ~1.2 s, then the
//   Files sheet — no spinner, no acknowledgement.
//
//  Selector notes: "toolbar.daily", "daily.export"; the note is a plain Text with no
//  identifier (bug/Main:scored-surfaces-addressable-only-by-copy) matched by its exact
//  copy. The system Files sheet that follows is dismissed by its Cancel button if one
//  is reachable; the assertion is made BEFORE that and does not depend on it.
//
import XCTest

final class RegressionExportProgressNoteTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-11:export-picker-no-progress-indicator — Export must acknowledge the tap
    /// with "Opening Files…" before the Files sheet appears.
    func testExportAcknowledgesTheTapWithAnOpeningFilesNote() throws {
        let app = QA.launch()
        QA.openDaily(app)

        let export = app.buttons["daily.export"]
        for _ in 0..<8 where !export.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(export.isHittable, "the BACKUP section's Export button never came on screen")
        XCTAssertNotEqual(app.staticTexts["daily.backupnote"].label, "Opening Files…", "the note must not stand before the tap")

        export.tap()
        XCTAssertTrue(QA.wait(3) { app.staticTexts["daily.backupnote"].label == "Opening Files…" },
                      "Export gave no acknowledgement — the note never flipped to 'Opening Files…' (the round-1 freeze is back)")

        // Tidy up: dismiss the Files sheet if it exposes a Cancel we can reach (best effort).
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 8), cancel.isHittable { cancel.tap() }
    }
}
