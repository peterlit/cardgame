//
//  RegressionExportFilenameUniqueTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    bug/WF-11:export-replace-destroys-existing-backup   (TC-11.1, major)
//  Verified FIXED in qa-loop round 2 (build 9ab79f1 / app 42b5f7e).
//
//  FIXED contract this test guards (Views/DailyView.swift, exportFilename):
//   - The suggested backup name is `Causeway-Stats-yyyy-MM-dd-HHmmss` — down to the
//     second — so two exports on the same day never collide, the system
//     "Replace Existing Items?" alert is never offered, and its Replace path (which
//     moved the old backup to .Trash, wrote NOTHING, and wedged the exporter until it
//     was swiped away — zero backups left) is unreachable by default.
//
//  Original repro (round 1, raw points kept for the record):
//    launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15 → tapid toolbar.daily → swipe up ×2 →
//    tapid daily.export → tap 352 109 (Save) → 'Stats exported.' →
//    tapid daily.export → tap 352 109 (Save) → 'Replace Existing Items?' →
//    tap 201 461 (Replace) → spinner; Save/Cancel dead for 40+ s; the old
//    Causeway-Stats-2026-09-09.json in the provider's .Trash, no new file →
//    force-dismiss → note reads 'Export cancelled.'
//
//  Selector notes: daily.export / daily.backupnote are real identifiers. The exporter
//  is Files.app UI (UIDocumentPicker) and is addressed by its "Save" label; the
//  suggested name is read by VALUE / label, prefix-matched on "Causeway-Stats-".
//  exportFilename stamps Date() — the CAUSEWAY_TODAY_OVERRIDE clock does not reach
//  it — so the test pins the SHAPE of the name (a six-digit time suffix), not a date.
//
import XCTest

final class RegressionExportFilenameUniqueTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// bug/WF-11:export-replace-destroys-existing-backup — the suggested name carries a
    /// time-of-day suffix, and a second export in the same session gets a DIFFERENT name
    /// and never meets "Replace Existing Items?".
    func testExportFilenameCarriesSecondsSoTwoExportsNeverCollide() throws {
        let app = QA.launch()
        QA.openDaily(app)
        let export = app.buttons["daily.export"]
        for _ in 0..<8 where !export.isHittable {
            app.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(export.isHittable, "BACKUP ▸ Export never came on screen")
        let note = app.staticTexts["daily.backupnote"]

        // --- first export: the suggested name has a HHmmss suffix ---------------------
        export.tap()
        // The first UIDocumentPicker presentation in a process blocks for ~1–2 s.
        let save = app.buttons["Save"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 20),
                      "the Files exporter never presented a Save button — system UI, not the app's")
        let first = suggestedName(app)
        let shape = try NSRegularExpression(pattern: "^Causeway-Stats-\\d{4}-\\d{2}-\\d{2}-\\d{6}(\\.json)?$")
        XCTAssertNotNil(shape.firstMatch(in: first, range: NSRange(first.startIndex..., in: first)),
                        "the suggested backup name is not Causeway-Stats-yyyy-MM-dd-HHmmss — a date-only name collides on the day's second export and offers the destructive Replace path: '\(first)'")
        save.tap()
        XCTAssertTrue(QA.wait(20) { note.label == "Stats exported." },
                      "the first export did not report 'Stats exported.' — note reads: \(note.label)")

        // --- second export, same session: a NEW name, no Replace alert -----------------
        export.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 20), "the exporter did not present a second time")
        let second = suggestedName(app)
        XCTAssertNotEqual(second, first,
                          "the second export suggested the SAME name (\(second)) — the date-only filename is back")
        save.tap()
        XCTAssertFalse(app.alerts["Replace Existing Items?"].waitForExistence(timeout: 3),
                       "the second export hit 'Replace Existing Items?' — its Replace path destroys the first backup")
        XCTAssertTrue(QA.wait(20) { note.label == "Stats exported." },
                      "the second export did not report 'Stats exported.' — note reads: \(note.label)")
    }

    // MARK: - helpers

    /// The exporter's Save-as name: the value of its text field, else any label that
    /// begins with the app's prefix (the picker renders it as a row on some iOS builds).
    private func suggestedName(_ app: XCUIApplication) -> String {
        var found = ""
        _ = QA.wait(10) {
            if let v = app.textFields.allElementsBoundByIndex
                .compactMap({ $0.value as? String }).first(where: { $0.hasPrefix("Causeway-Stats-") }) {
                found = v; return true
            }
            let byLabel = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", "Causeway-Stats-", "Causeway-Stats-"))
                .firstMatch
            if byLabel.exists {
                found = (byLabel.value as? String).flatMap { $0.hasPrefix("Causeway-Stats-") ? $0 : nil } ?? byLabel.label
                return true
            }
            return false
        }
        return found.isEmpty ? "<no Causeway-Stats- name found in the exporter>" : found
    }
}
