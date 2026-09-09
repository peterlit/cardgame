import XCTest
@testable import Causeway

/// security/DailyView.swift:export-filename-locale — the backup name is collision-free only if its
/// shape is pinned: a formatter left on the device locale follows a non-Gregorian region calendar,
/// non-Latin digits, and (12-hour regions) rewrites "HH" to 12-hour, so 01:30:05 and 13:30:05
/// could share a name and reopen the destructive Replace path (bug/WF-11).
final class ExportFilenameTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int, _ s: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi, second: s))!
    }

    func testFormatterIsPinnedToPosixGregorian() {
        let f = DailyView.exportFormatter(timeZone: utc)
        XCTAssertEqual(f.locale.identifier, "en_US_POSIX", "fixed-format DateFormatter must not follow the device locale (QA1480)")
        XCTAssertEqual(f.calendar.identifier, .gregorian, "the year must not follow a Buddhist/Japanese region calendar")
        XCTAssertEqual(f.timeZone, utc, "the zone passed in must be the one used (production passes .current)")
        XCTAssertEqual(f.dateFormat, "yyyy-MM-dd-HHmmss")
    }

    func testNameIsLatin24HourDownToTheSecond() {
        let pm = date(2026, 9, 9, 13, 30, 5), am = date(2026, 9, 9, 1, 30, 5)
        XCTAssertEqual(DailyView.exportFilename(at: pm, timeZone: utc), "Causeway-Stats-2026-09-09-133005")
        XCTAssertEqual(DailyView.exportFilename(at: am, timeZone: utc), "Causeway-Stats-2026-09-09-013005")
        XCTAssertNotEqual(DailyView.exportFilename(at: am, timeZone: utc), DailyView.exportFilename(at: pm, timeZone: utc),
                          "an AM and a PM export twelve hours apart must never share a name")
    }

    func testNameFollowsTheGivenZone() {
        let t = date(2026, 9, 9, 23, 59, 59)
        XCTAssertEqual(DailyView.exportFilename(at: t, timeZone: TimeZone(identifier: "Asia/Tokyo")!),
                       "Causeway-Stats-2026-09-10-085959")
    }
}
