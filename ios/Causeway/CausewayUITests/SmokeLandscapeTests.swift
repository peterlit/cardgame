//
//  SmokeLandscapeTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversion of the [smoke] case in .qa-loop/TESTCASES.md
//  (qa-loop 2026-09-09, round 1):
//    TC-12.1 Rotate to landscape: the board reflows and stays complete
//
//  What is asserted (device-independent form of the case's 874x402 / x=68 / 118-pt
//  numbers): after rotation the window is wider than tall; all NINE toolbar.* pills are
//  present in ONE left rail (same centre x, same width, ~26 pt tall, portrait order top to
//  bottom); header + Moves/Time/Won still visible; both group labels present; 52 card.*
//  elements; nothing — pill, label or card — outside the window frame.
//
//  Selector notes: the seven rail ids (ContentView.landscapeRail reuses the portrait deck's
//  ids), "stat.moves"/"stat.time"/"stat.won", "card.<S><rank>", the two group labels.
//
import XCTest

final class SmokeLandscapeTests: XCTestCase {

    // A2 (2026-09-13): the rail's pills in rail order. Deal # is a header chip in both
    // orientations; Wins / How to play are behind More.
    private let rail = ["toolbar.newgame", "toolbar.undo", "toolbar.replay", "toolbar.daily",
                        "toolbar.autoplay", "toolbar.autofinish", "toolbar.more"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// TC-12.1 — landscape keeps every control, label and card on screen in one left rail.
    func testTC12_1_LandscapeReflowsIntoARailAndStaysComplete() throws {
        let app = QA.launch()
        for id in rail { XCTAssertTrue(app.buttons[id].exists, "portrait precondition: missing \(id)") }
        XCTAssertEqual(QA.cards(app).count, 52, "portrait precondition: 52 card elements")

        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "rotation to landscape never took effect")
        XCTAssertTrue(QA.wait(5) { app.buttons["toolbar.more"].exists && app.buttons["toolbar.more"].frame.midX < window.frame.width / 4 },
                      "the toolbar did not reflow into a LEFT rail")

        let pills = rail.map { app.buttons[$0] }
        for (id, pill) in zip(rail, pills) {
            XCTAssertTrue(pill.exists, "landscape rail is missing \(id)")
            XCTAssertTrue(window.frame.contains(pill.frame), "\(id) is clipped off the window: \(pill.frame)")
        }
        let x = pills[0].frame.midX, w = pills[0].frame.width
        for (id, pill) in zip(rail, pills) {
            XCTAssertLessThan(abs(pill.frame.midX - x), 1.5, "\(id) is not in the rail column (x \(pill.frame.midX) vs \(x))")
            XCTAssertLessThan(abs(pill.frame.width - w), 1.5, "\(id) is not rail-width (\(pill.frame.width) vs \(w))")
            XCTAssertTrue((22...32).contains(pill.frame.height), "\(id) is \(pill.frame.height) pt tall, expected ~26")
        }
        XCTAssertGreaterThan(w, 90, "rail pills are unexpectedly narrow (\(w) pt)")
        for i in 1..<pills.count {
            XCTAssertGreaterThan(pills[i].frame.minY, pills[i - 1].frame.minY, "rail order is wrong at \(rail[i])")
        }

        XCTAssertTrue(app.staticTexts["Causeway"].exists, "the header title is gone in landscape")
        for id in ["stat.moves", "stat.time", "stat.won"] {
            XCTAssertTrue(app.staticTexts[id].exists && window.frame.contains(app.staticTexts[id].frame), "\(id) missing or clipped in landscape")
        }
        for label in ["FOUNDATIONS · A↑ / K↓", "FREE CELLS"] {
            XCTAssertTrue(app.staticTexts[label].exists && window.frame.contains(app.staticTexts[label].frame), "'\(label)' missing or clipped in landscape")
        }
        let cards = QA.cards(app)
        XCTAssertEqual(cards.count, 52, "landscape lost cards (\(cards.count) card elements)")
        let clipped = cards.filter { !window.frame.contains($0.frame) }
        XCTAssertTrue(clipped.isEmpty, "cards clipped off the landscape window: \(clipped.map { $0.identifier })")
        XCTAssertEqual(Set(cards.map { Int(($0.frame.midX / 10).rounded()) }).count >= 8, true, "cards do not span 8 columns")
    }
}
