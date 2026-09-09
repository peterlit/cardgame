import XCTest
@testable import Causeway

/// The first EXECUTABLE Swift model tests. Until this target existed, every guard on Swift logic
/// was a string comparison run by Node (`tests/ios-parity.test.mjs`) — a pin proves a line still
/// reads the same, not that it does the same (the 2026-09-07 skeptical review's central "ugly").
/// These tests construct the real `Game` and run the real methods.
///
/// `Game` persists through `UserDefaults.standard`, and TEST_HOST is Causeway.app — this suite
/// runs INSIDE the shipping app's container. On the owner's physical device those defaults ARE
/// the real win history and daily medals, so each test SNAPSHOTS every `causeway.`-prefixed key,
/// clears them for a deterministic start, and RESTORES the snapshot after itself (deleting
/// whatever the test wrote — including versioned backup keys like `causeway.daily.v<N>`). The
/// suite still passes in any order, and the host's container survives it byte-for-byte.
final class CausewayModelTests: XCTestCase {

    private var savedDefaults: [String: Any] = [:]
    private var causewayKeys: [String] {
        UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("causeway.") }
    }

    override func setUp() {
        super.setUp()
        savedDefaults = [:]
        for k in causewayKeys {
            savedDefaults[k] = UserDefaults.standard.object(forKey: k)
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
    override func tearDown() {
        for k in causewayKeys { UserDefaults.standard.removeObject(forKey: k) }
        for (k, v) in savedDefaults { UserDefaults.standard.set(v, forKey: k) }
        savedDefaults = [:]
        super.tearDown()
    }

    /// A fresh Game with autoplay off (so tests observe exactly the moves they make) and a
    /// deterministic deal.
    private func makeGame(seed: Int = 1) -> Game {
        let g = Game()
        g.autoplayOn = false
        g.autoFinishMode = .off
        g.deal(seed: seed)
        return g
    }

    // MARK: - Deal

    func testDealIsDeterministicAndComplete() {
        let a = makeGame(seed: 424242)
        let b = makeGame(seed: 424242)
        XCTAssertEqual(a.tableau, b.tableau, "same seed must deal the same board")
        XCTAssertEqual(a.tableau.flatMap { $0 }.count, 52)
        XCTAssertEqual(a.tableau.map(\.count), [7, 7, 7, 7, 6, 6, 6, 6])
        XCTAssertEqual(a.cells, [nil, nil, nil])
        XCTAssertEqual(a.up, [0, 0, 0, 0])
        XCTAssertEqual(a.down, [14, 14, 14, 14])
    }

    // MARK: - R2: the attempt's identity is (day, seed), together

    func testRestoreDropsAChallengeBindingWhoseSeedNoLongerMatches() {
        // A save can claim "day 0" while its board was dealt from another generation's seed —
        // the skeptical review's reproduction credited current day 0 with a v2-generation board.
        // The board must survive; the daily binding must not.
        let g = makeGame(seed: 12345)          // NOT day 0's pool seed
        XCTAssertNotEqual(g.pool.first?.seed, 12345, "fixture invalid: 12345 became a real pool seed")
        g.challengeDay = 0
        g.challengeStartDay = todayIndex()
        g.persist()

        let h = Game()                          // restores the save above
        XCTAssertEqual(h.seed, 12345, "the board itself must survive restore")
        XCTAssertEqual(h.moveCount, 0)
        XCTAssertNil(h.challengeDay, "a (day, seed) mismatch must resume as casual play, never as another day's challenge")
        XCTAssertNil(h.challengeStartDay)
    }

    func testRestoreKeepsAGenuineChallengeBinding() {
        let g = makeGame()
        g.playChallenge(0)                      // deals day 0's real seed and binds it
        XCTAssertEqual(g.challengeDay, 0)
        g.persist()

        let h = Game()
        XCTAssertEqual(h.challengeDay, 0, "a genuine binding must survive restore")
        XCTAssertEqual(h.seed, h.pool[0].seed)
    }

    func testDealMatchesTheWebTwin() {
        // tests/engine.mjs deals seed 1 with the same Mulberry32 + Fisher–Yates. This digest was
        // computed by the Node engine (`deal(1)`, suit-index.rank per card, columns |-joined) —
        // the executable half of the parity contract. If it fails, the RNG or layout diverged.
        let g = makeGame(seed: 1)
        let digest = g.tableau.map { col in col.map { "\($0.suit.rawValue).\($0.rank)" }.joined(separator: ",") }
                              .joined(separator: "|")
        XCTAssertEqual(digest,
            "1.12,3.6,1.11,0.11,3.5,2.6,3.12|3.3,0.7,2.4,2.10,1.10,3.2,2.9|" +
            "0.12,0.4,3.11,2.8,0.9,1.2,0.5|2.2,3.7,2.13,2.5,0.8,1.9,1.4|" +
            "0.13,0.2,2.11,2.12,1.13,3.9|0.3,1.5,3.1,0.10,1.3,0.6|" +
            "1.8,1.7,3.4,1.6,3.13,2.3|1.1,3.8,3.10,2.1,0.1,2.7")
    }

    // MARK: - smartMove reports whether it moved (ux/WF-2:unmovable-card-no-feedback)

    /// The bottom-of-column spot holding `card`, if it is exposed.
    private func exposedSpot(_ g: Game, _ suit: Suit, _ rank: Int) -> Spot? {
        for (col, pile) in g.tableau.enumerated() where pile.last == Card(suit: suit, rank: rank) {
            return .tableau(col: col, idx: pile.count - 1)
        }
        return nil
    }

    /// The tester's exact repro on deal #810129: park 5♠, 5♣, Q♥ (all three cells full), then
    /// tap the exposed 8♦ — no foundation step, no black 7/9 exposed, no empty column. The tap
    /// must report `false` and leave the board byte-identical, which is what the view keys the
    /// refusal wiggle on. The three parking moves must report `true` (the same signal is what a
    /// successful tap returns).
    func testSmartMoveReportsAFruitlessTapAndLeavesTheBoardAlone() throws {
        let g = makeGame(seed: 810129)
        for (suit, rank) in [(Suit.spade, 5), (Suit.club, 5), (Suit.heart, 12)] {
            let spot = try XCTUnwrap(exposedSpot(g, suit, rank), "\(suit) \(rank) is not exposed on deal 810129")
            XCTAssertTrue(g.smartMove(spot), "parking \(suit) \(rank) must report a move")
        }
        XCTAssertEqual(g.moveCount, 3)
        XCTAssertTrue(g.cells.allSatisfy { $0 != nil }, "the repro needs every free cell full")

        let d8 = try XCTUnwrap(exposedSpot(g, .diamond, 8))
        let tableauBefore = g.tableau, cellsBefore = g.cells, upBefore = g.up, downBefore = g.down
        XCTAssertFalse(g.smartMove(d8), "8♦ has nowhere to go — the tap must say so")
        XCTAssertEqual(g.moveCount, 3)
        XCTAssertEqual(g.tableau, tableauBefore)
        XCTAssertEqual(g.cells, cellsBefore)
        XCTAssertEqual(g.up, upBefore)
        XCTAssertEqual(g.down, downBefore)
    }
}
