import XCTest
@testable import Causeway

/// Replays the bundled winning lines through the REAL move API — `Game.drop`, never the demo
/// applier — turning the 2026-09-07 skeptical review's one-off native replay into repeatable
/// coverage. Every shipped day's certificate is re-proved by the shipping model on every test run.
final class SolutionReplayTests: XCTestCase {

    // TEST_HOST is Causeway.app: `UserDefaults.standard` here IS the shipping app's container, and
    // this suite writes graded records for every pool day mid-run. Snapshot every `causeway.` key,
    // clear for determinism, and restore after — an on-device run must not erase the owner's real
    // history (see CausewayModelTests for the twin).
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

    private func makeGame() -> Game {
        let g = Game()
        g.autoplayOn = false        // the lines already contain the safe sends
        g.autoFinishMode = .off     // and the finish cascade must not race the replay
        return g
    }

    /// Apply one solver token through the real move boundary. Token grammar matches
    /// rules.mjs / applyDemoToken: comma-separated, F/G/T/C/X.
    @discardableResult
    private func applyToken(_ g: Game, _ tok: Substring) -> Bool {
        let p = tok.split(separator: ",").map(String.init)
        func n(_ j: Int) -> Int { j < p.count ? (Int(p[j]) ?? -1) : -1 }
        switch p.first {
        case "F":
            let col = n(1)
            guard col >= 0, col < g.tableau.count, let c = g.tableau[col].last else { return false }
            return g.drop(.tableau(col: col, idx: g.tableau[col].count - 1),
                          to: .foundation(c.suit, n(2) == 1 ? .down : .up))
        case "G":
            let i = n(1)
            guard i >= 0, i < g.cells.count, let c = g.cells[i] else { return false }
            return g.drop(.cell(i), to: .foundation(c.suit, n(2) == 1 ? .down : .up))
        case "T":
            return g.drop(.tableau(col: n(1), idx: n(2)), to: .column(n(3)))
        case "C":
            let col = n(1)
            guard col >= 0, col < g.tableau.count,
                  let e = g.cells.firstIndex(where: { $0 == nil }) else { return false }
            return g.drop(.tableau(col: col, idx: g.tableau[col].count - 1), to: .cell(e))
        case "X":
            return g.drop(.cell(n(1)), to: .column(n(2)))
        default:
            return false
        }
    }

    /// Best line for a day: flawless if the seed has one, else bronze.
    private func line(for seed: Int) -> (tokens: [Substring], flawless: Bool)? {
        guard let s = DailyData.solutions[seed] else { return nil }
        if let f = s.flawless { return (f.split(separator: " "), true) }
        return (s.bronze.split(separator: " "), false)
    }

    /// Won = every suit's two piles meet (the same predicate as Game's private checkWin, computed
    /// from the public foundations so the test needs no access widening).
    private func isWon(_ g: Game) -> Bool { (0..<4).allSatisfy { g.down[$0] == g.up[$0] + 1 } }

    // MARK: - The corpus certificate, re-proved by the shipping model

    func testEveryBundledLineWinsThroughTheRealMoveAPI() {
        let g = makeGame()
        var replayed = 0
        for (day, entry) in g.pool.enumerated() {
            guard let l = line(for: entry.seed) else { continue }
            g.deal(seed: entry.seed)
            // Bind the day directly: playChallenge refuses future days by design, but the
            // certificate must hold for the WHOLE shipped pool, not just the days already public.
            g.challengeDay = day
            g.challengeStartDay = todayIndex()
            for (i, tok) in l.tokens.enumerated() {
                XCTAssertTrue(applyToken(g, tok),
                              "day \(day) seed \(entry.seed): token #\(i) '\(tok)' was refused by the real move API")
            }
            XCTAssertTrue(isWon(g), "day \(day) seed \(entry.seed): line completed but the board is not won")
            if l.flawless {
                XCTAssertEqual(g.dailyResult?.flawless, true,
                               "day \(day) seed \(entry.seed): the flawless line did not grade flawless")
            } else {
                XCTAssertEqual(g.dailyResult?.bronze, true,
                               "day \(day) seed \(entry.seed): the winning line did not grade bronze")
            }
            replayed += 1
        }
        XCTAssertEqual(replayed, g.pool.count,
                       "every shipped day must carry a replayable line — \(replayed) of \(g.pool.count) did")
    }

    // MARK: - R3: win → undo → win must reconcile the finished board every time

    func testWinUndoWinStopsTheClockAndClearsTheSaveBothTimes() {
        let g = makeGame()
        let seed = g.pool[0].seed
        guard let l = line(for: seed) else { return XCTFail("day 0 lost its bundled line") }
        g.deal(seed: seed)
        for tok in l.tokens { XCTAssertTrue(applyToken(g, tok)) }

        // First win: recorded, clock stopped, save cleared.
        XCTAssertTrue(isWon(g))
        XCTAssertTrue(g.winStore.isWon(seed))
        XCTAssertFalse(g.clock.isRunning, "the first win must stop the clock")
        XCTAssertNil(UserDefaults.standard.data(forKey: "causeway.game"),
                     "the first win must clear the in-progress save")

        // Undo back into play: casual continuation (owner decision 2026-09-08) — board resumable,
        // clock ticking again.
        g.undo()
        XCTAssertFalse(isWon(g))
        XCTAssertTrue(g.clock.isRunning, "undoing a win resumes play — the clock must follow")
        XCTAssertNotNil(UserDefaults.standard.data(forKey: "causeway.game"),
                        "an undone win is a resumable board again")

        // Re-complete the final move. Before the R3 fix this skipped ALL cleanup: the clock kept
        // running and the stale unfinished save resurrected on relaunch, one card from done.
        XCTAssertTrue(applyToken(g, l.tokens[l.tokens.count - 1]))
        XCTAssertTrue(isWon(g))
        XCTAssertFalse(g.clock.isRunning, "the SECOND win must stop the clock too (R3)")
        XCTAssertNil(UserDefaults.standard.data(forKey: "causeway.game"),
                     "the SECOND win must clear the save too — a relaunch must not resurrect a one-card-left board (R3)")
        XCTAssertTrue(g.winStore.isWon(seed))
    }

    // MARK: - "Prev" re-simulates, it never undoes (ux/WF-6:demo-has-no-step-back)

    func testDemoStepBackReSimulatesOneMoveShorterAndNeverArmsUndo() throws {
        let seed = makeGame().pool[0].seed
        // Reference: a demo stepped forward exactly twice.
        let ref = makeGame()
        ref.showSolution(seed, tier: "bronze")
        ref.demoStepOnce(); ref.demoStepOnce()
        // Subject: three steps, then one back.
        let g = makeGame()
        g.showSolution(seed, tier: "bronze")
        XCTAssertFalse(g.demoCanStepBack, "nothing to rewind at move 0")
        g.demoStepOnce(); g.demoStepOnce(); g.demoStepOnce()
        XCTAssertTrue(g.demoCanStepBack)
        g.demoStepBack()

        XCTAssertEqual(g.demoProgress, ref.demoProgress, "Prev must land one move earlier")
        XCTAssertEqual(g.tableau, ref.tableau, "Prev must show the same position a fresh two-step replay shows")
        XCTAssertEqual(g.cells, ref.cells)
        XCTAssertEqual(g.up, ref.up)
        XCTAssertEqual(g.down, ref.down)
        XCTAssertTrue(g.demoing, "Prev must not leave the demo")
        XCTAssertTrue(g.demoPaused, "Prev must leave the demo paused")
        XCTAssertFalse(g.canUndo, "Prev must never arm Undo — the demo board is not playable")
        XCTAssertFalse(g.winStore.isWon(seed), "a demo never records anything")

        // Back to the opening position, and Prev then has nothing left to do.
        g.demoStepBack(); g.demoStepBack()
        XCTAssertEqual(g.demoProgress, "0 / \(ref.demoProgress.split(separator: "/").last!.trimmingCharacters(in: .whitespaces))")
        XCTAssertFalse(g.demoCanStepBack)
        let fresh = makeGame(); fresh.deal(seed: seed)
        XCTAssertEqual(g.tableau, fresh.tableau, "rewound to move 0 the board must be the opening position")
    }

    /// Round 2: Prev is offered from the completion banner too, and re-enters the paused demo one
    /// move short — the finished board never becomes playable, and nothing is scored.
    func testDemoStepBackFromCompletionBannerReentersPausedDemoOneMoveShort() throws {
        let seed = makeGame().pool[0].seed
        let g = makeGame()
        g.showSolution(seed, tier: "bronze")
        let total = Int(g.demoProgress.split(separator: "/").last!.trimmingCharacters(in: .whitespaces))!
        XCTAssertGreaterThan(total, 1)
        for _ in 0..<total { g.demoStepOnce() }
        XCTAssertFalse(g.demoing, "a complete line ends the demo")
        XCTAssertNotNil(g.demoDoneMessage, "a complete line shows the banner")
        XCTAssertTrue(g.demoCanStepBack, "the banner must offer Prev")

        // Reference: the same line stepped forward to N-1.
        let ref = makeGame()
        ref.showSolution(seed, tier: "bronze")
        for _ in 0..<(total - 1) { ref.demoStepOnce() }

        g.demoStepBack()
        XCTAssertTrue(g.demoing, "Prev from the banner re-enters the demo (input locked)")
        XCTAssertTrue(g.demoPaused, "…paused, not auto-advancing")
        XCTAssertNil(g.demoDoneMessage, "…and takes the banner down")
        XCTAssertEqual(g.demoProgress, "\(total - 1) / \(total)")
        XCTAssertEqual(g.tableau, ref.tableau, "Prev from the banner must show the position before the last move")
        XCTAssertEqual(g.cells, ref.cells)
        XCTAssertEqual(g.up, ref.up)
        XCTAssertEqual(g.down, ref.down)
        XCTAssertFalse(g.hasLiveGame, "a demo board is never a live game")
        XCTAssertFalse(g.canUndo, "Prev must never arm Undo")
        XCTAssertFalse(g.winStore.isWon(seed), "a demo never records anything")

        // Next replays the final move and the banner returns, exactly as before.
        g.demoStepOnce()
        XCTAssertFalse(g.demoing)
        XCTAssertNotNil(g.demoDoneMessage)
        XCTAssertFalse(g.winStore.isWon(seed))
    }
}
