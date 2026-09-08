import XCTest
@testable import Causeway

/// The first EXECUTABLE Swift model tests. Until this target existed, every guard on Swift logic
/// was a string comparison run by Node (`tests/ios-parity.test.mjs`) — a pin proves a line still
/// reads the same, not that it does the same (the 2026-09-07 skeptical review's central "ugly").
/// These tests construct the real `Game` and run the real methods.
///
/// `Game` persists through `UserDefaults.standard`, so each test clears the game's keys before and
/// after itself: the suite must pass in any order and leave the test host's container clean.
final class CausewayModelTests: XCTestCase {

    private let gameKeys = ["causeway.game", "causeway.daily", "causeway.wins",
                            "causeway.autoplay", "causeway.autofinishmode"]

    override func setUp() {
        super.setUp()
        for k in gameKeys { UserDefaults.standard.removeObject(forKey: k) }
    }
    override func tearDown() {
        for k in gameKeys { UserDefaults.standard.removeObject(forKey: k) }
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
}
