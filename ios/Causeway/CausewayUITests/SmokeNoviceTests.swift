//
//  SmokeNoviceTests.swift
//  CausewayUITests
//
//  Durable XCUITest conversions of the [smoke] cases in .qa-loop/TESTCASES.md that a
//  tester used to re-run by hand every round (qa-loop 2026-09-09, round 1):
//    TC-1.1  Discover objective + controls, make one legal move
//    TC-2.1  Tap smart-move sends the obvious card home
//    TC-3.1  New game is one tap and reshuffles
//    TC-10.1 Find the rules
//
//  Determinism: the clock is pinned (QAFixtures.swift) and the board that needs a known
//  foundation card is deal #500001, dealt through the Deal # alert — its column bottoms
//  expose A♦ (column 3) and K♦ (column 5), so "the obvious card" is card.D1 / card.D13
//  by identifier, not a coordinate. Auto-play is pinned OFF so only the test's taps move
//  cards. (TC-1.1/2.1's "restored dev deal" no longer exists; today's daily deal #608530
//  exposes no Ace or King at a column bottom, which is why the smoke deal is #500001.)
//
//  Selector notes: "toolbar.howtoplay", "toolbar.newgame", "toolbar.undo", "toolbar.deal",
//  "stat.moves" / "stat.time", "card.<S><rank>"; the header subtitle, group labels and
//  rules copy are plain Text matched verbatim.
//
import XCTest

final class SmokeNoviceTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// TC-1.1 — the objective and controls are legible from the board + How to play alone,
    /// and one tap makes a correct move (Moves 1, clock running, Undo enabled).
    func testTC1_1_DiscoverObjectiveAndControlsThenMakeOneLegalMove() throws {
        let app = QA.launch(autoplay: false)

        XCTAssertTrue(app.staticTexts["build each suit from both ends"].waitForExistence(timeout: 5),
                      "the header subtitle no longer states the objective")
        XCTAssertTrue(app.staticTexts["FOUNDATIONS · A↑ / K↓"].exists, "the foundations heading is missing")
        XCTAssertTrue(app.staticTexts["FREE CELLS"].exists, "the FREE CELLS heading is missing")

        app.buttons["toolbar.howtoplay"].tap()
        XCTAssertTrue(app.navigationBars["How to play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Goal"].exists && app.staticTexts["Controls"].exists, "Goal / Controls sections missing")
        XCTAssertTrue(contains(app, "Each suit has two foundations — an up pile (A, 2, 3 …) and a down pile (K, Q, J …)"),
                      "the Goal no longer explains the both-ended foundations")
        // Exact round-2 copy (Extras.swift `rule("Controls", …)`): the tap rule says WHICH cards a
        // tap lifts — the engine's precondition exactly: nothing below, or a tidy run that reaches
        // the BOTTOM of the pile (ux/WF-10:controls-overpromises-tap) — and the wiggle sentence
        // documents the refusal cue (ux/WF-2:unmovable-card-no-feedback). Neither the pre-fix
        // "Tap a card to send it to its best spot" nor round 1's looser "heads a tidy run" must
        // satisfy this.
        XCTAssertTrue(contains(app, "Tap a card with nothing below it — or one whose tidy run reaches the bottom of its pile — to send it to its best spot: a foundation if it fits, otherwise onto another card, an empty column, or a free cell."),
                      "Controls no longer state the engine's tap precondition (run reaches the bottom of the pile)")
        XCTAssertTrue(contains(app, "Move a tidy run — cards already stacked by that rule — as a group"),
                      "Tableau no longer defines 'tidy run' where it first appears")
        XCTAssertTrue(contains(app, "A card that can't move, or has nowhere to go, just wiggles."),
                      "Controls no longer document the wiggle refusal cue")
        XCTAssertTrue(contains(app, "To place a card or run somewhere specific, drag it there instead."), "Controls no longer explain drag")
        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["How to play"], timeout: 3))

        QA.dealSeed(app, 500001)
        let moves = app.staticTexts["stat.moves"], time = app.staticTexts["stat.time"]
        XCTAssertTrue(QA.wait(5) { app.buttons["toolbar.deal"].label.hasPrefix("Deal #500001") })
        XCTAssertEqual(moves.label, "0")
        XCTAssertFalse(app.buttons["toolbar.undo"].isEnabled, "Undo must start disabled")

        XCTAssertTrue(app.descendants(matching: .any)["card.D1"].waitForExistence(timeout: 3), "A♦ is not exposed on deal #500001 — layout changed?")
        XCTAssertEqual(QA.tapCard(app, "card.D1"), "1", "one tap on an exposed Ace did not count as a move (Moves \(moves.label))")
        XCTAssertTrue(QA.wait(4) { time.label != "0:00" }, "the clock did not start on the first move (Time \(time.label))")
        XCTAssertTrue(app.buttons["toolbar.undo"].isEnabled, "Undo must enable after the first move")
    }

    /// TC-2.1 — a single tap sends an exposed Ace to the UP row and an exposed King to the
    /// DOWN row (the row beneath), no press-and-hold, no confirmation, Moves +1 each.
    func testTC2_1_TapSmartMoveSendsTheObviousCardHome() throws {
        let app = QA.launch(autoplay: false)
        QA.dealSeed(app, 500001)
        XCTAssertTrue(QA.wait(5) { app.buttons["toolbar.deal"].label.hasPrefix("Deal #500001") })
        let moves = app.staticTexts["stat.moves"]

        let ace = app.descendants(matching: .any)["card.D1"], king = app.descendants(matching: .any)["card.D13"]
        XCTAssertTrue(ace.waitForExistence(timeout: 3) && king.exists, "A♦ / K♦ are not both exposed on deal #500001")
        let tableauTop = QA.cards(app).map { $0.frame.minY }.min() ?? 0

        XCTAssertEqual(QA.tapCard(app, "card.D1"), "1", "tapping A♦ did not move it (Moves \(moves.label))")
        XCTAssertTrue(QA.wait(3) { ace.frame.maxY < tableauTop }, "A♦ did not leave the tableau for a foundation (y \(ace.frame.minY) vs tableau top \(tableauTop))")
        XCTAssertFalse(app.alerts.firstMatch.exists, "a smart-move must not ask for confirmation")

        XCTAssertEqual(QA.tapCard(app, "card.D13"), "2", "tapping K♦ did not move it (Moves \(moves.label))")
        XCTAssertTrue(QA.wait(3) { king.frame.maxY < tableauTop }, "K♦ did not leave the tableau for a foundation")
        // Up pile is the TOP row, down pile the row beneath: the Ace sits ABOVE the King.
        XCTAssertLessThan(ace.frame.midY, king.frame.midY, "A♦ (up pile) should sit in the row above K♦ (down pile)")
        XCTAssertLessThan(abs(ace.frame.midX - king.frame.midX), 4, "A♦ and K♦ belong to the same suit column of the foundations")
    }

    /// TC-3.1 — New game on an untouched board is one tap: new Deal #, Moves 0, clock reset.
    func testTC3_1_NewGameIsOneTapAndReshuffles() throws {
        let app = QA.launch()
        let dealPill = app.buttons["toolbar.deal"]
        let before = dealPill.label

        app.buttons["toolbar.newgame"].tap()
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 1.5), "an untouched board must not ask before New game")
        XCTAssertTrue(QA.wait(3) { dealPill.label != before }, "New game did not change the deal (\(dealPill.label))")
        XCTAssertTrue(dealPill.label.hasPrefix("Deal #"), "unexpected deal pill label: \(dealPill.label)")
        XCTAssertEqual(app.staticTexts["stat.moves"].label, "0")
        XCTAssertEqual(app.staticTexts["stat.time"].label, "0:00")
        XCTAssertGreaterThan(QA.cards(app).count, 40, "the reshuffled board is not fully dealt")
    }

    /// TC-10.1 — How to play carries every section a novice needs.
    func testTC10_1_RulesSheetHasEverySection() throws {
        let app = QA.launch()
        app.buttons["toolbar.howtoplay"].tap()
        XCTAssertTrue(app.navigationBars["How to play"].waitForExistence(timeout: 5))
        for title in ["Goal", "The catch", "Tableau", "Free cells", "Controls"] {
            XCTAssertTrue(app.staticTexts[title].exists, "rules section missing: \(title)")
        }
        XCTAssertTrue(contains(app, "Move all 52 cards to the foundations."), "Goal lost its 52-card statement")
        XCTAssertTrue(contains(app, "The up and down halves of a suit can never cross."), "The catch lost its statement")
        XCTAssertTrue(contains(app, "Build in alternating colours, one rank at a time, in either direction"), "Tableau lost its rule")
        XCTAssertTrue(contains(app, "Three single-card parking spots."), "Free cells lost its rule")
        XCTAssertTrue(contains(app, "The run beneath it moves with it."), "Controls lost the run rule")
        app.buttons["Done"].tap()
        XCTAssertTrue(QA.waitGone(app.navigationBars["How to play"], timeout: 3))
    }

    // MARK: - helpers

    private func contains(_ app: XCUIApplication, _ fragment: String) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).count > 0
    }
}
