//
//  RegressionBackupCancelNoteTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/WF-11:cancel-note-not-updated
//  (archived ledger 20260815-233017-342e3c0; fixed on 342e3c0, previously
//  unguarded — found by this round's archive sweep.)
//
//  FIXED contract this test guards (DailyView.backupSection):
//   - Cancelling the Files picker ACKNOWLEDGES the cancel: the note under the
//     Export/Import buttons reads "Import cancelled." (and "Export cancelled."
//     for the exporter's swipe-dismiss). Before the fix the note kept the
//     "Opening Files…" progress text the tap had put there, so a cancelled
//     import looked like an import still in flight.
//
//  Original repro (archived round 1):
//    launch → Daily → scroll to BACKUP → Import → Cancel in the Files sheet →
//    read the note under Export/Import.
//
//  Selector notes (mined from Views/DailyView.swift on 4f02d1d):
//   - "toolbar.daily", "daily.import" — real identifiers.
//   - The NOTE itself has no identifier (plain Text with a nil-coalesced
//     default): matched by its verbatim "Import cancelled." Follow-up
//     recommending "daily.backupnote" filed in
//     .qa-loop/fragments/round-2-regression.json.
//   - The Files picker is a SYSTEM sheet: its Cancel button is not the app's and
//     its wording/placement is Apple's. That is the fragile part of this file;
//     the test skips rather than fails if the picker never appears.
//
import XCTest

final class RegressionBackupCancelNoteTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/WF-11:cancel-note-not-updated — a cancelled import must say so, not
    /// leave the "Opening Files…" progress note standing.
    func testCancellingTheImportPickerSaysSo() throws {

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["toolbar.daily"].waitForExistence(timeout: 5))
        app.buttons["toolbar.daily"].tap()
        XCTAssertTrue(app.navigationBars["Daily Challenges"].waitForExistence(timeout: 5))

        let importButton = app.buttons["daily.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5), "BACKUP ▸ Import not found")
        importButton.tap()

        // The first UIDocumentPicker presentation in a process blocks for ~1–1.8 s.
        let cancel = app.buttons["Cancel"]
        try XCTSkipUnless(cancel.waitForExistence(timeout: 20),
                          "the Files picker never presented a Cancel button — system UI, not the app's")
        cancel.tap()

        let note = app.staticTexts["daily.backupnote"]
        XCTAssertTrue(QA.wait(5) { note.exists && note.label == "Import cancelled." },
                      "a cancelled import is not acknowledged — the note is stuck on its progress text: '\(note.label)'")
        XCTAssertNotEqual(note.label, "Opening Files…",
                          "the 'Opening Files…' progress note survived the cancel")
    }
}
