//
//  RegressionAutoFinishCycleTests.swift
//  CausewayUITests
//
//  Regression tripwire for: ux/WF-8:autofinish-cycle-through-on-ends-game (minor)
//  Fixed on 5447237 (archived ledger 20260822-125736-f949d82); unguarded until this
//  round's archive sweep.
//
//  FIXED contract this test guards (AutoFinishMode.next):
//   - The Auto-finish pill cycles Ask → Off → On → Ask. Before the fix it cycled
//     Ask → On → Off, so on a finishable board the only route from the default "Ask"
//     to "Off" passed through "On" — and that single tap instantly cascaded the whole
//     board and recorded the win. Ask → Off must be ONE tap that plays zero cards.
//
//  Original repro (round-1 tester): deal #10169, play the 28-move bronze prefix until
//   finishable, 'Ready to finish' → Not yet, tap 'Auto-finish: Ask' ONCE → the pill
//   read 'Auto-finish: On' and the app cascaded all 42 remaining cards home.
//
//  Selector notes: "toolbar.autofinish" (label "Auto-finish: <Ask|Off|On>",
//  ContentView.toolbar). The cycle ORDER is the whole fix, so the label sequence is
//  asserted verbatim on an untouched board (where a wrong order is harmless to observe).
//
import XCTest

final class RegressionAutoFinishCycleTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// ux/WF-8:autofinish-cycle-through-on-ends-game — Ask → Off → On → Ask, in that order.
    func testAutoFinishPillCyclesAskOffOnAsk() throws {
        let app = QA.launch(autofinish: "ask")

        let pill = app.buttons["toolbar.autofinish"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5), "no toolbar.autofinish pill")
        XCTAssertEqual(pill.label, "Auto-finish: Ask", "precondition: the default mode is Ask")

        pill.tap()
        XCTAssertTrue(QA.wait(2) { pill.label == "Auto-finish: Off" },
                      "one tap from Ask must reach Off (got '\(pill.label)') — the Ask→On→Off cycle-through is back")
        pill.tap()
        XCTAssertTrue(QA.wait(2) { pill.label == "Auto-finish: On" },
                      "Off must be followed by On (got '\(pill.label)')")
        pill.tap()
        XCTAssertTrue(QA.wait(2) { pill.label == "Auto-finish: Ask" },
                      "On must wrap back to Ask (got '\(pill.label)')")
    }
}
