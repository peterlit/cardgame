//
//  RegressionRestoredBoardShrinkLatchTests.swift
//  CausewayUITests
//
//  Regression tripwire for:
//    ux/WF-12:landscape-board-rescales-every-move   (TC-12.8, minor)
//  Verified FIXED in qa-loop round 3 (build de5e5d0).
//
//  FIXED contract this test guards (Views/ContentView.swift shrinkLatchCount, seeded in
//  .onAppear):
//   - The landscape board is sized for the tallest column seen THIS DEAL, never for the
//     current tallest column, so a move that shortens the tallest column cannot grow
//     every card, foundation and free cell at once. The latch used to be seeded only by
//     onChange(of: game.moveCount), which never fires for a game RESTORED at launch, so
//     a restored deep-column board sat at latch 0 and the FIRST move off the tall column
//     rescaled all 52 cards once (34×57 → 36×60 measured; Undo → 34×57; the same move →
//     36×60 again). Since de5e5d0 the latch is seeded from the restored tableau on
//     appear, so the card size is constant across that first move, its undo and its redo.
//
//  Original repro (round 2/3, QADriver):
//    python3 .qa-loop/scratch/causeway-qa-2/tall.py 14 | inject_save.py <udid>
//      (14-card column 0, all 52 cards on the tableau, moveCount 5, Auto-play Off)
//    rotate landscapeLeft; terminate; launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15
//    labels any card. -> all 52 cards 34x57, tallest column 14
//    tapid card.H4 (smart-move the bottom card off the tall column) -> all 52 cards 36x60
//    tapid toolbar.undo -> 34x57; tapid card.H4 again -> STAYS 34x57 (latch now seeded)
//    Round 3: 34x57 before AND after the first move, at depths 14 and 20.
//
//  The fixture below is tall.py 14 verbatim (seed 608530; column 0 = 2♠…Q♠ 2♥ 3♥ 4♥, the
//  other 51 cards dealt round-robin; no challenge binding). 4♥ heads a one-card run with
//  no foundation or tableau home, so its smart-move parks it in a free cell — one move,
//  column 0 goes 14 → 13, the tallest column shrinks. Auto-play is pinned OFF so no
//  foundation sends follow the move. Selector notes: card.<S><rank> (CardView),
//  toolbar.undo, stat.moves are real identifiers; sizes are compared, never hard-coded.
//
import XCTest

final class RegressionRestoredBoardShrinkLatchTests: XCTestCase {

    /// tall.py 14: a 14-card column 0 with every card on the tableau, parked at move 5.
    private static let tallColumn14 = #"{"seed":608530,"tableau":[[{"suit":0,"rank":2},{"suit":0,"rank":3},{"suit":0,"rank":4},{"suit":0,"rank":5},{"suit":0,"rank":6},{"suit":0,"rank":7},{"suit":0,"rank":8},{"suit":0,"rank":9},{"suit":0,"rank":10},{"suit":0,"rank":11},{"suit":0,"rank":12},{"suit":1,"rank":2},{"suit":1,"rank":3},{"suit":1,"rank":4}],[{"suit":1,"rank":5},{"suit":1,"rank":12},{"suit":2,"rank":8},{"suit":3,"rank":4},{"suit":3,"rank":11},{"suit":1,"rank":1}],[{"suit":1,"rank":6},{"suit":2,"rank":2},{"suit":2,"rank":9},{"suit":3,"rank":5},{"suit":3,"rank":12},{"suit":2,"rank":1}],[{"suit":1,"rank":7},{"suit":2,"rank":3},{"suit":2,"rank":10},{"suit":3,"rank":6},{"suit":0,"rank":13},{"suit":3,"rank":1}],[{"suit":1,"rank":8},{"suit":2,"rank":4},{"suit":2,"rank":11},{"suit":3,"rank":7},{"suit":1,"rank":13}],[{"suit":1,"rank":9},{"suit":2,"rank":5},{"suit":2,"rank":12},{"suit":3,"rank":8},{"suit":2,"rank":13}],[{"suit":1,"rank":10},{"suit":2,"rank":6},{"suit":3,"rank":2},{"suit":3,"rank":9},{"suit":3,"rank":13}],[{"suit":1,"rank":11},{"suit":2,"rank":7},{"suit":3,"rank":3},{"suit":3,"rank":10},{"suit":0,"rank":1}]],"cells":[null,null,null],"up":[0,0,0,0],"down":[14,14,14,14],"moveCount":5,"elapsed":60,"started":true,"telem":{"cellUses":0,"undos":0,"maxRunMoved":1,"foundationOrder":[]},"autoFinishDeferred":true}"#

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// ux/WF-12:landscape-board-rescales-every-move — the first move off a RESTORED
    /// 14-card column must not change the size of a single card.
    func testRestoredDeepColumnKeepsCardSizeAcrossTheFirstMove() throws {
        let app = QA.app(game: Self.tallColumn14, autoplay: false)
        XCUIDevice.shared.orientation = .landscapeLeft     // restored straight into landscape, as the repro
        app.launch()
        XCTAssertTrue(app.buttons["toolbar.deal"].waitForExistence(timeout: 10), "the board never appeared")
        let window = app.windows.firstMatch
        XCTAssertTrue(QA.wait(5) { window.frame.width > window.frame.height }, "the app did not come up in landscape")

        let moves = app.staticTexts["stat.moves"]
        XCTAssertTrue(QA.wait(5) { moves.label == "5" }, "fixture precondition: Moves 5, got \(moves.label)")
        let tall = app.descendants(matching: .any)["card.H4"]
        XCTAssertTrue(tall.waitForExistence(timeout: 5), "fixture precondition: 4♥ (bottom of the 14-card column) is missing")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))   // let the restore animation settle

        // Every card is one uniform size on a landscape board; record it.
        let before = sizes(app)
        XCTAssertEqual(before.count, 52, "fixture precondition: 52 card elements, got \(before.count)")
        let w0 = before.values.map { $0.width }.min() ?? 0
        XCTAssertGreaterThan(w0, 20)
        assertUniform(before, width: w0, state: "restored, before any move")

        // --- the first move shortens the tallest column: 14 → 13 --------------------------
        let after = QA.tapCard(app, "card.H4")
        XCTAssertEqual(after, "6", "the smart-move of 4♥ did not register as one move (Moves \(after))")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        assertUniform(sizes(app), width: w0, state: "after the first move on a restored board")

        // --- Undo and redo the same move: still the restored size --------------------------
        app.buttons["toolbar.undo"].tap()
        XCTAssertTrue(QA.wait(3) { moves.label == "5" }, "Undo did not step back to Moves 5")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        assertUniform(sizes(app), width: w0, state: "after Undo")

        XCTAssertEqual(QA.tapCard(app, "card.H4"), "6", "the second smart-move of 4♥ did not register")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        assertUniform(sizes(app), width: w0, state: "after the same move a second time")
    }

    // MARK: - helpers

    /// identifier → frame size for every card.* element. Frames are read once per call.
    private func sizes(_ app: XCUIApplication) -> [String: CGSize] {
        var out: [String: CGSize] = [:]
        for card in QA.cards(app) { out[card.identifier] = card.frame.size }
        return out
    }

    /// Every card must be  wide (±0.5 pt): a single deviating card means the board
    /// rescaled (uniformly — the finding's symptom — or, worse, unevenly).
    private func assertUniform(_ sizes: [String: CGSize], width: CGFloat, state: String) {
        let off = sizes.filter { abs($0.value.width - width) > 0.5 }
        XCTAssertTrue(off.isEmpty,
                      "card size changed \(state): expected every card \(width) pt wide, but \(off.count) differ, e.g. "
                      + off.prefix(3).map { "\($0.key)=\($0.value.width)×\($0.value.height)" }.joined(separator: ", ")
                      + " — the landscape board rescaled")
    }
}
