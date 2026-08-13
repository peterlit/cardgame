import Foundation
import SwiftUI
import Combine

/// A position a card can live in — the source of a tap or drag.
enum Spot: Equatable {
    case tableau(col: Int, idx: Int)
    case cell(Int)
}

enum Dir { case up, down }

/// A drag-and-drop destination.
enum DropTarget: Equatable { case column(Int), cell(Int), foundation(Suit, Dir) }

/// How the game reacts when the board becomes finishable (every remaining card can cascade home).
/// `.ask` (default) prompts; `.on` finishes automatically; `.off` waits for the Finish button.
enum AutoFinishMode: String, CaseIterable {
    case ask, on, off
    var label: String { self == .ask ? "Ask" : self == .on ? "On" : "Off" }
    var next: AutoFinishMode { self == .ask ? .on : self == .on ? .off : .ask }
}

private struct Snapshot {
    var tableau: [[Card]]
    var cells: [Card?]
    var up: [Int]
    var down: [Int]
    var moveCount: Int
    var foLen: Int      // pre-move length of telem.foundationOrder (append-only cursor)
    var cellUses: Int   // pre-move free-cell-use counter
}

/// The Causeway engine + observable state for SwiftUI. Rules ported from the web prototype:
/// dual foundations per suit (build up A→ and down K→, never crossing), two-way
/// alternating-colour tableau, FreeCell-style supermoves, safe auto-play, smart double-tap.
final class Game: ObservableObject {
    static let cellCount = 3
    static let colCount = 8
    static let maxSeed = 1_000_000

    @Published var tableau: [[Card]] = Array(repeating: [], count: colCount)
    @Published var cells: [Card?] = Array(repeating: nil, count: cellCount)
    @Published var up = Array(repeating: 0, count: 4)      // highest rank on the up pile (0 = empty)
    @Published var down = Array(repeating: 14, count: 4)   // lowest rank on the down pile (14 = empty)
    @Published var selection: Spot?
    @Published var seed = 0
    @Published var moveCount = 0
    @Published var won = false

    /// Elapsed clock, isolated so its 1 Hz tick doesn't re-render the board (see GameClock).
    let clock = GameClock()
    @Published var autoplayOn = true {
        didSet { UserDefaults.standard.set(autoplayOn, forKey: "causeway.autoplay"); if autoplayOn { runAutoplay() } }
    }
    /// How reaching a finishable board is handled: `.ask` (default) prompts, `.on` finishes
    /// automatically, `.off` waits for the Finish button.
    @Published var autoFinishMode: AutoFinishMode = .ask {
        didSet { UserDefaults.standard.set(autoFinishMode.rawValue, forKey: "causeway.autofinishmode"); maybeAutoFinish() }
    }
    /// True while the sequential finish animation runs (cards flying home one at a time).
    @Published private(set) var finishing = false
    /// Drives the "ready to finish?" prompt (`.ask` mode).
    @Published var promptAutoFinish = false
    /// Set once the player defers this game's prompt, so we don't nag again (reset on deal).
    private var autoFinishDeferred = false
    /// Monotonic token identifying the current finish chain. Each `asyncAfter` block captures the
    /// value live at schedule time; any teardown/restart (undo, deal, a new runAutoFinish) bumps
    /// it so a still-queued block from a superseded chain bails instead of double-running.
    private var finishGen = 0
    /// Guards the durable win record so it fires exactly once even though recordWin() is called at
    /// the winning move and onWin() may call it again after the deferred beat. Reset per new game.
    private var winRecorded = false

    let winStore = WinStore()
    let dailyStore = DailyStore()

    /// The certified daily-challenge seed pool (empty ⇒ Daily unavailable).
    let pool = DailyData.pool

    /// The day index currently being played as a challenge (nil = casual play). @Published so the
    /// live objectives HUD shows/hides as a challenge starts/ends.
    @Published var challengeDay: Int? = nil
    /// Per-attempt telemetry (reset on deal/restore) — the ordered foundation stream + resource
    /// counters the objective checkers read. Persisted with the in-progress game across relaunch.
    private var telem = Telemetry()
    /// The graded result of the just-won challenge attempt, for the win overlay (nil for casual
    /// wins). Set in recordWin(); cleared on the next deal.
    @Published var dailyResult: TierResult? = nil

    private var history: [Snapshot] = []
    private var started = false
    private var autoplaying = false
    private var cancellables = Set<AnyCancellable>()

    var canUndo: Bool { !history.isEmpty }

    init() {
        // WinStore is a nested ObservableObject; its changes don't propagate through the
        // parent automatically, so forward them (keeps "Won"/checkmark/Wins in sync).
        winStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        // DailyStore is a nested ObservableObject too; forward its changes so the Challenges
        // screen and any streak/badge readouts stay in sync.
        dailyStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        if UserDefaults.standard.object(forKey: "causeway.autoplay") != nil {
            autoplayOn = UserDefaults.standard.bool(forKey: "causeway.autoplay")
        }
        // No migration from the pre-release `causeway.autofinish` bool: the app hasn't shipped,
        // so no such key exists in the wild, and the default intentionally moved On -> Ask.
        if let raw = UserDefaults.standard.string(forKey: "causeway.autofinishmode"),
           let mode = AutoFinishMode(rawValue: raw) {
            autoFinishMode = mode
        }
        if !restore() { deal(seed: randomSeed()) }   // resume an in-progress game if one was saved
    }

    // MARK: - Dealing

    func randomSeed() -> Int { Int.random(in: 1...Game.maxSeed) }

    func deal(seed: Int) {
        self.seed = max(1, min(Game.maxSeed, seed))
        var rng = Mulberry32(UInt32(truncatingIfNeeded: self.seed))
        var deck: [Card] = []
        for s in 0..<4 { for r in 1...13 { deck.append(Card(suit: Suit(rawValue: s)!, rank: r)) } }
        // Fisher–Yates identical to the web build.
        var i = deck.count - 1
        while i > 0 { let j = rng.int(i + 1); deck.swapAt(i, j); i -= 1 }

        tableau = Array(repeating: [], count: Game.colCount)
        var k = 0
        for c in 0..<Game.colCount {
            let n = c < 4 ? 7 : 6   // 7,7,7,7,6,6,6,6 = 52
            for _ in 0..<n { tableau[c].append(deck[k]); k += 1 }
        }
        cells = Array(repeating: nil, count: Game.cellCount)
        up = Array(repeating: 0, count: 4)
        down = Array(repeating: 14, count: 4)
        selection = nil
        history = []
        moveCount = 0
        clock.reset()
        won = false
        telem = Telemetry()      // fresh attempt; a plain deal is casual play until playChallenge sets challengeDay
        challengeDay = nil
        dailyResult = nil
        winRecorded = false      // fresh game — allow the next win to record
        started = false
        autoplaying = false
        finishing = false
        finishGen &+= 1          // invalidate any finish block queued from the previous game
        promptAutoFinish = false
        autoFinishDeferred = false
        persist()
    }

    func newRandomGame() { deal(seed: randomSeed()) }

    /// Restart the CURRENT deal from scratch — re-deal the same seed, preserving the daily-challenge
    /// context if one is active (so a challenge replay stays scored as that same challenge/day).
    func restartDeal() {
        let day = challengeDay
        deal(seed: seed)                    // re-deal same seed; resets telemetry/board, clears challengeDay
        if let day = day { challengeDay = day; persist() }   // keep it a challenge if it was one
    }

    // MARK: - In-progress persistence (survives backgrounding / eviction)

    private let gameKey = "causeway.game"

    private struct SavedGame: Codable {
        var seed: Int
        var tableau: [[Card]]
        var cells: [Card?]
        var up: [Int]
        var down: [Int]
        var moveCount: Int
        var elapsed: Int
        var started: Bool
        var challengeDay: Int?      // preserve a challenge attempt (+ its telemetry) across relaunch
        var telem: Telemetry?
    }

    /// Snapshot the live (unfinished) game to UserDefaults. Cheap: board only, no undo
    /// history. Called after every move and on backgrounding.
    func persist() {
        // Refuse to save a finished board. `won` is a view-mutable flag (the win overlay's
        // "Close" clears it), so guard on the actual position too: a completed table must
        // never be written, else restore() would resurrect an empty, un-won game.
        guard !won, !boardComplete else { return }
        let s = SavedGame(seed: seed, tableau: tableau, cells: cells, up: up, down: down,
                          moveCount: moveCount, elapsed: clock.elapsed, started: started,
                          challengeDay: challengeDay, telem: telem)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: gameKey)
        }
    }
    private func clearSaved() { UserDefaults.standard.removeObject(forKey: gameKey) }

    /// Restore a saved in-progress game; false if none / invalid.
    private func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: gameKey),
              let s = try? JSONDecoder().decode(SavedGame.self, from: data),
              s.tableau.count == Game.colCount, s.cells.count == Game.cellCount,
              s.up.count == 4, s.down.count == 4 else { return false }
        // Sanity: reject a corrupt/impossible save. Foundations must be in range and
        // non-crossing (up < down per suit), and the 52 canonical cards — those still in the
        // tableau/cells plus those implied as home by the foundation ranks — must each appear
        // exactly once. A completed board (all 52 home) is refused too: it isn't a resumable
        // game, and letting it through would restore an empty, un-won table.
        for st in 0..<4 {
            guard s.up[st] >= 0, s.up[st] <= 13, s.down[st] >= 1, s.down[st] <= 14,
                  s.up[st] < s.down[st] else { return false }
        }
        var seen = Set<Int>()   // card id = suit*13 + rank
        func mark(suit: Int, rank: Int) -> Bool {
            guard rank >= 1, rank <= 13 else { return false }
            return seen.insert(suit * 13 + rank).inserted
        }
        for col in s.tableau { for c in col { guard mark(suit: c.suit.rawValue, rank: c.rank) else { return false } } }
        for c in s.cells.compactMap({ $0 }) { guard mark(suit: c.suit.rawValue, rank: c.rank) else { return false } }
        for st in 0..<4 {
            if s.up[st] >= 1 { for r in 1...s.up[st] where !mark(suit: st, rank: r) { return false } }
            if s.down[st] <= 13 { for r in s.down[st]...13 where !mark(suit: st, rank: r) { return false } }
        }
        guard seen.count == 52, !Game.boardComplete(tableau: s.tableau, cells: s.cells) else { return false }

        seed = s.seed; tableau = s.tableau; cells = s.cells; up = s.up; down = s.down
        moveCount = s.moveCount; clock.set(s.elapsed); started = s.started
        selection = nil; history = []; won = false; autoplaying = false
        challengeDay = s.challengeDay          // resume a challenge attempt if one was in progress
        telem = s.telem ?? Telemetry()
        dailyResult = nil
        winRecorded = false      // restore() only accepts an in-progress board (boardComplete rejected above)
        // Reset finish state too (parity with web restoreGame): restore() is init-only so these
        // are already default, but keep it explicit and robust against future re-entrant restores.
        finishing = false; promptAutoFinish = false; autoFinishDeferred = false
        stopTimer()
        if started { startTimer() }
        // A kill mid-autoplay-chain can save a board with more safe cards still to send.
        // runAutoplay() is a no-op unless started && autoplayOn, and only sends provably
        // safe cards, so this is safe to call unconditionally here.
        runAutoplay()
        maybeAutoFinish()   // a resumed board might already be finishable
        return true
    }

    // MARK: - Rules

    private func emptyColumns() -> Int { tableau.filter { $0.isEmpty }.count }
    private func freeCellCount() -> Int { cells.filter { $0 == nil }.count }

    private func maxMovable(targetEmpty: Bool) -> Int {
        let e = emptyColumns() - (targetEmpty ? 1 : 0)
        return (freeCellCount() + 1) * Int(pow(2.0, Double(max(0, e))))
    }

    /// Cards idx..end form an alternating-colour run monotonic by 1 (ascending or descending).
    func isSeqHead(col: Int, idx: Int) -> Bool {
        // A view can call this with a Spot captured at render time that auto-play has since
        // invalidated (tap disambiguation races the 0.14 s autoplay tick) — guard the index.
        guard col < tableau.count, idx < tableau[col].count else { return false }
        let t = tableau[col]
        if idx == t.count - 1 { return true }
        let a = t[idx], b = t[idx + 1]
        if a.isRed == b.isRed { return false }
        let asc: Bool
        if a.rank == b.rank + 1 { asc = false }
        else if a.rank == b.rank - 1 { asc = true }
        else { return false }
        for i in idx..<(t.count - 1) {
            let x = t[i], y = t[i + 1]
            if x.isRed == y.isRed { return false }
            if !asc && x.rank != y.rank + 1 { return false }
            if asc && x.rank != y.rank - 1 { return false }
        }
        return true
    }

    private func runDir(_ cards: [Card]) -> String {
        guard cards.count >= 2 else { return "single" }
        return cards[0].rank == cards[1].rank + 1 ? "desc" : "asc"
    }

    private func tailDir(_ col: Int) -> String {
        let t = tableau[col]
        guard t.count >= 2 else { return "single" }
        let a = t[t.count - 2], b = t[t.count - 1]
        if a.isRed != b.isRed && a.rank == b.rank + 1 { return "desc" }
        if a.isRed != b.isRed && a.rank == b.rank - 1 { return "asc" }
        return "single"
    }

    private func canStackTableau(_ cards: [Card], onto col: Int) -> Bool {
        let t = tableau[col]
        guard let head = cards.first else { return false }
        if t.isEmpty { return true }
        let top = t[t.count - 1]
        if head.isRed == top.isRed { return false }
        if abs(head.rank - top.rank) != 1 { return false }
        let conn = head.rank == top.rank - 1 ? "desc" : "asc"
        let rdir = runDir(cards)
        if rdir != "single" && rdir != conn { return false }
        let tdir = tailDir(col)
        if tdir != "single" && tdir != conn { return false }
        return true
    }

    func canFoundationUp(_ c: Card) -> Bool {
        let s = c.suit.rawValue
        return c.rank == up[s] + 1 && c.rank < down[s]
    }
    func canFoundationDown(_ c: Card) -> Bool {
        let s = c.suit.rawValue
        return c.rank == down[s] - 1 && c.rank > up[s]
    }

    private func checkWin() -> Bool { (0..<4).allSatisfy { down[$0] == up[$0] + 1 } }

    /// All 52 cards are home (nothing left in tableau or cells). A completed board must
    /// never be persisted/restored, whatever the `won` flag currently says.
    private static func boardComplete(tableau: [[Card]], cells: [Card?]) -> Bool {
        tableau.allSatisfy { $0.isEmpty } && cells.allSatisfy { $0 == nil }
    }
    private var boardComplete: Bool { Game.boardComplete(tableau: tableau, cells: cells) }

    /// Dismiss the win overlay through the model. The finished game was already cleared from
    /// storage by onWin(); we just drop the banner and leave the solved board on screen.
    /// Persisting stays blocked by `boardComplete` so backgrounding can't resurrect it.
    func dismissWin() { won = false }

    // MARK: - Move plumbing

    private func snapshot() {
        history.append(Snapshot(tableau: tableau, cells: cells, up: up, down: down, moveCount: moveCount,
                                foLen: telem.foundationOrder.count, cellUses: telem.cellUses))
        if history.count > 500 { history.removeFirst() }
    }

    /// Record any cards newly sent home this move by diffing the foundations against the pre-move
    /// snapshot (each move homes at most one card). Non-invasive — leaves the move plumbing
    /// untouched. Call right after moveCount is bumped at each commit point. Builds the ordered
    /// foundation stream the daily objective checkers read. Mirrors index.html's recordHomed().
    private func recordHomed() {
        guard let p = history.last else { return }
        for s in 0..<4 {
            if up[s] > p.up[s] {
                for r in (p.up[s] + 1)...up[s] {
                    telem.foundationOrder.append(FoundationEvent(suit: s, rank: r, end: "up", moveIdx: moveCount))
                }
            }
            if down[s] < p.down[s] {
                for r in stride(from: p.down[s] - 1, through: down[s], by: -1) {
                    telem.foundationOrder.append(FoundationEvent(suit: s, rank: r, end: "down", moveIdx: moveCount))
                }
            }
        }
    }

    private func commit() {
        moveCount += 1
        recordHomed()   // capture any card this move sent home (for daily-challenge telemetry)
        if !started { started = true; startTimer() }
        selection = nil
        if checkWin() { onWin(); return }
        persist()
        maybeAutoFinish()   // offer/auto-complete if this move made the board finishable
        if !finishing && !promptAutoFinish { runAutoplay() }
    }

    func undo() {
        stopAutoplayPending()
        finishing = false        // halt any running finish cascade
        finishGen &+= 1          // invalidate any asyncAfter block still queued for the old chain
        promptAutoFinish = false
        telem.undos += 1        // an undo permanently fails the no-undo objective (never rolled back)
        guard let h = history.popLast() else { return }
        tableau = h.tableau; cells = h.cells; up = h.up; down = h.down
        moveCount = h.moveCount
        // Roll back challenge telemetry too, so exploring with undo can't pollute the stream:
        // truncate the append-only foundationOrder to its pre-move length and restore the cell-use
        // counter. (undos itself intentionally stays incremented.)
        if telem.foundationOrder.count > h.foLen { telem.foundationOrder.removeLast(telem.foundationOrder.count - h.foLen) }
        telem.cellUses = h.cellUses
        selection = nil
        won = false
        // A win stops the clock; undoing back into play must resume it (else elapsed
        // freezes and a later re-win would persist a bogus best time).
        if started && !clock.isRunning { startTimer() }
        persist()
    }

    private func selectedCards() -> [Card] {
        guard let sel = selection else { return [] }
        switch sel {
        case .cell(let i):
            guard i < cells.count else { return [] }
            return cells[i].map { [$0] } ?? []
        case .tableau(let col, let idx):
            // Defense in depth: a stale selection (e.g. after autoplay/auto-finish
            // removed cards) must not index out of bounds.
            guard col < tableau.count, idx < tableau[col].count else { return [] }
            return Array(tableau[col][idx...])
        }
    }

    private func remove(from spot: Spot) {
        switch spot {
        case .cell(let i): cells[i] = nil
        case .tableau(let col, _): tableau[col].removeLast()
        }
    }

    // MARK: - User intents (called by the views)

    /// Manual placement via drag-and-drop: move the run headed by `source` onto `target`,
    /// exactly where the player dropped it. Returns whether the drop was legal (and applied).
    /// Reuses the tap-era move validators by staging `selection` for the duration of the move.
    @discardableResult
    func drop(_ source: Spot, to target: DropTarget) -> Bool {
        if case .tableau(let c, let i) = source, !isSeqHead(col: c, idx: i) { return false }
        selection = source
        let moved: Bool
        switch target {
        case .column(let col): moved = tryMoveToTableau(col)
        case .cell(let i): moved = tryMoveToCell(i)
        case .foundation(let suit, let dir): moved = tryMoveToFoundation(suit: suit, dir: dir)
        }
        selection = nil   // no persistent selection in the tap/drag model
        return moved
    }

    @discardableResult
    private func tryMoveToTableau(_ col: Int) -> Bool {
        let cards = selectedCards()
        guard let sel = selection, !cards.isEmpty else { return false }
        if case .tableau(let sc, _) = sel, sc == col { return false }
        guard canStackTableau(cards, onto: col) else { return false }
        let targetEmpty = tableau[col].isEmpty
        guard cards.count <= maxMovable(targetEmpty: targetEmpty) else { return false }
        snapshot()
        switch sel {
        case .cell(let i): cells[i] = nil
        case .tableau(let scol, let sidx): tableau[scol].removeSubrange(sidx...)
        }
        tableau[col].append(contentsOf: cards)
        commit()
        return true
    }

    @discardableResult
    private func tryMoveToCell(_ i: Int) -> Bool {
        let cards = selectedCards()
        guard let sel = selection, cards.count == 1, cells[i] == nil else { return false }
        if case .cell(let si) = sel, si == i { return false }
        snapshot()
        remove(from: sel)
        cells[i] = cards[0]
        // A cell→cell shuffle isn't a new free-cell use; only a tableau→cell park counts.
        if case .cell = sel {} else { telem.cellUses += 1 }
        commit()
        return true
    }

    @discardableResult
    private func tryMoveToFoundation(suit: Suit, dir: Dir) -> Bool {
        let cards = selectedCards()
        guard let sel = selection, cards.count == 1, cards[0].suit == suit else { return false }
        let card = cards[0]
        if dir == .up && !canFoundationUp(card) { return false }
        if dir == .down && !canFoundationDown(card) { return false }
        snapshot()
        remove(from: sel)
        if dir == .up { up[suit.rawValue] = card.rank } else { down[suit.rawValue] = card.rank }
        commit()
        return true
    }

    /// Double-tap: foundation → onto another card → empty column → free cell.
    /// Double-tap. Works on any card heading a valid run (the card plus the
    /// sub-stack below it), moving the whole run. Priority: foundation → onto
    /// another card → empty column → free cell (foundation/free cell single-card only).
    func smartMove(_ spot: Spot) {
        let run: [Card]
        switch spot {
        case .cell(let i): guard let c = cells[i] else { return }; run = [c]
        case .tableau(let col, let idx):
            guard isSeqHead(col: col, idx: idx) else { return }   // card + cards below must form a run
            run = Array(tableau[col][idx...])
        }
        guard let head = run.first else { return }
        let n = run.count

        // 1) foundation (single card only)
        if n == 1, canFoundationUp(head) || canFoundationDown(head) {
            snapshot(); removeRun(spot)
            if canFoundationUp(head) { up[head.suit.rawValue] = head.rank }
            else { down[head.suit.rawValue] = head.rank }
            commit(); return
        }
        // 2) onto another (non-empty) column
        for col in 0..<Game.colCount {
            if case .tableau(let sc, _) = spot, sc == col { continue }
            if !tableau[col].isEmpty, canStackTableau(run, onto: col), n <= maxMovable(targetEmpty: false) {
                snapshot(); removeRun(spot); tableau[col].append(contentsOf: run); commit(); return
            }
        }
        // 3) an empty column (skip if the run is already the whole source column)
        let wholeCol: Bool = { if case .tableau(_, let idx) = spot { return idx == 0 }; return false }()
        if !wholeCol {
            for col in 0..<Game.colCount where tableau[col].isEmpty {
                if n <= maxMovable(targetEmpty: true) {
                    snapshot(); removeRun(spot); tableau[col].append(contentsOf: run); commit(); return
                }
            }
        }
        // 4) a free cell (single card, and not already in a cell)
        if n == 1, case .tableau = spot {
            for i in 0..<Game.cellCount where cells[i] == nil {
                snapshot(); cells[i] = head; telem.cellUses += 1; removeRun(spot); commit(); return
            }
        }
    }

    private func removeRun(_ spot: Spot) {
        switch spot {
        case .cell(let i): cells[i] = nil
        case .tableau(let col, let idx): tableau[col].removeSubrange(idx...)
        }
    }

    // MARK: - Safe auto-play (waits for the first move)

    private func rankOnFoundation(_ suit: Int, _ r: Int) -> Bool {
        r <= 0 || up[suit] >= r || down[suit] <= r
    }
    private func isSafeAutoplay(_ c: Card) -> Bool {
        guard canFoundationUp(c) || canFoundationDown(c) else { return false }
        let opp = c.isRed ? [Suit.spade.rawValue, Suit.club.rawValue]
                          : [Suit.heart.rawValue, Suit.diamond.rawValue]
        // Causeway's tableau builds BOTH directions, so an opposite-colour rank-1
        // (descending) or rank+1 (ascending) card could still need `c` as a base.
        // Only safe home once neither neighbour is still in play (ranks <1 / >13 are
        // treated as already-resolved). This is stricter than plain FreeCell but sound.
        return opp.allSatisfy { rankOnFoundation($0, c.rank - 1) && rankOnFoundation($0, c.rank + 1) }
    }

    @discardableResult
    private func autoplayOneStep() -> Bool {
        for i in 0..<Game.cellCount {
            if let c = cells[i], isSafeAutoplay(c) {
                snapshot(); selection = nil; cells[i] = nil
                if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
                moveCount += 1; recordHomed(); persist(); return true
            }
        }
        for col in 0..<Game.colCount {
            guard let c = tableau[col].last, isSafeAutoplay(c) else { continue }
            snapshot(); selection = nil; tableau[col].removeLast()
            if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
            moveCount += 1; recordHomed(); persist(); return true
        }
        return false
    }

    func runAutoplay() {
        guard autoplayOn, started, !autoplaying, !won else { return }
        autoplaying = true
        step()
    }
    private func step() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
            guard let self, self.autoplaying else { return }
            withAnimation(.easeOut(duration: 0.14)) {
                if self.autoplayOneStep() {
                    if self.checkWin() { self.autoplaying = false; self.onWin(); return }
                    self.step()
                } else {
                    self.autoplaying = false
                    self.maybeAutoFinish()   // safe-autoplay settled; auto-complete if now finishable
                }
            }
        }
    }
    private func stopAutoplayPending() { autoplaying = false }

    /// Send exactly one available card home — cells first, then tableau tops left→right, taking
    /// whichever end (up/down) is legal. Returns whether a card moved. Drives the sequential finish.
    @discardableResult
    private func sendOneHome() -> Bool {
        for i in 0..<Game.cellCount {
            if let c = cells[i], canFoundationUp(c) || canFoundationDown(c) {
                snapshot(); cells[i] = nil
                if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
                return true
            }
        }
        for col in 0..<Game.colCount {
            // OR, not XOR: a suit's closing card is legal on BOTH ends and either completes it.
            if let c = tableau[col].last, canFoundationUp(c) || canFoundationDown(c) {
                snapshot(); tableau[col].removeLast()
                if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
                return true
            }
        }
        return false
    }

    /// Run auto-finish: fly every remaining card home one at a time — each card starts as the
    /// previous lands, the same sequential reveal the safe-autoplay chain uses. Only meaningful
    /// when the board is finishable (callers gate on that); a no-op otherwise.
    func runAutoFinish() {
        // `!checkWin()`: an already-complete board (e.g. during the deferred-overlay beat, when
        // `won` is still false) has nothing to finish — re-entering here would bump finishGen and
        // orphan the pending win. autoFinishWouldWin() alone returns true on a solved board.
        guard !finishing, !won, !checkWin(), autoFinishWouldWin() else { return }
        promptAutoFinish = false
        stopAutoplayPending()   // the finish chain supersedes safe-autoplay
        selection = nil
        finishing = true
        finishGen &+= 1
        finishStep(gen: finishGen)
    }
    private func finishStep(gen: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { [weak self] in
            guard let self, self.finishing, self.finishGen == gen else { return }
            var sent = false
            withAnimation(.easeOut(duration: 0.2)) { sent = self.sendOneHome() }
            guard sent else { self.finishing = false; return }
            self.moveCount += 1
            self.recordHomed()   // auto-finish sends count in the foundation-order stream too
            if !self.started { self.started = true; self.startTimer() }
            if self.checkWin() {
                self.finishing = false
                self.recordWin()   // durable side effects NOW so a kill during the beat can't lose the win
                // Let the last card actually LAND (and the completed board show for a beat) before
                // the win overlay covers it — otherwise it pops up over a still-animating foundation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { [weak self] in
                    guard let self, self.finishGen == gen, self.checkWin(), !self.won else { return }
                    self.onWin()
                }
                return
            }
            self.persist()
            self.finishStep(gen: gen)
        }
    }

    /// Would forcing every available card home (the aggressive `autoFinish`) empty the board and
    /// win? A pure simulation on copies of the state — the trigger for automatic finishing. Uses
    /// the same greedy rule as `autoFinish` so detection and execution can never disagree.
    private func autoFinishWouldWin() -> Bool {
        var u = up, d = down, cs = cells, tb = tableau
        func canUp(_ c: Card) -> Bool { c.rank == u[c.suit.rawValue] + 1 && c.rank < d[c.suit.rawValue] }
        func canDown(_ c: Card) -> Bool { c.rank == d[c.suit.rawValue] - 1 && c.rank > u[c.suit.rawValue] }
        var moved = true
        while moved {
            moved = false
            for i in 0..<Game.cellCount {
                if let c = cs[i], canUp(c) || canDown(c) {
                    cs[i] = nil
                    if canUp(c) { u[c.suit.rawValue] = c.rank } else { d[c.suit.rawValue] = c.rank }
                    moved = true
                }
            }
            for col in 0..<Game.colCount {
                if let c = tb[col].last, canUp(c) || canDown(c) {
                    tb[col].removeLast()
                    if canUp(c) { u[c.suit.rawValue] = c.rank } else { d[c.suit.rawValue] = c.rank }
                    moved = true
                }
            }
        }
        return (0..<4).allSatisfy { d[$0] == u[$0] + 1 }
    }

    /// Offer or perform auto-finish when the board becomes finishable, per the current mode.
    func maybeAutoFinish() {
        guard started, !won, !finishing, !promptAutoFinish, !checkWin(), autoFinishWouldWin() else { return }
        switch autoFinishMode {
        case .on:  runAutoFinish()
        case .ask: if !autoFinishDeferred { stopAutoplayPending(); promptAutoFinish = true }
        case .off: break   // the Finish button (canOfferFinish) lets the player start it
        }
    }

    /// Player chose "Not yet": stop prompting this game, but keep the Finish button available.
    func deferAutoFinish() {
        autoFinishDeferred = true
        promptAutoFinish = false
        runAutoplay()   // resume the safe-autoplay we paused for the prompt
    }

    func cycleAutoFinishMode() { autoFinishMode = autoFinishMode.next }

    /// Whether to show the manual "Finish" button: the board is finishable and idle.
    var canOfferFinish: Bool {
        // `!checkWin()` mirrors web's position-based `!isWon()` gate: never offer Finish over an
        // already-solved board (incl. the deferred-overlay window, where `won` is still false).
        started && !won && !finishing && !promptAutoFinish && !checkWin() && autoFinishWouldWin()
    }

    // MARK: - Win + timer

    /// Durable win side effects — recorded exactly once, synchronously at the winning move so a
    /// process kill during the deferred-overlay beat can't lose the win/best-time.
    private func recordWin() {
        guard !winRecorded else { return }
        winRecorded = true
        stopTimer()
        autoplaying = false
        clearSaved()   // finished game — next launch should start fresh
        let secs = clock.elapsed
        winStore.record(seed: seed, moves: moveCount, secs: secs)
        dailyResult = recordChallengeResult(secs: secs)   // score the daily attempt (if any); clears challengeDay
    }

    // MARK: - Daily challenges

    /// Begin playing `day` as a challenge: deal its seed (which resets telemetry and clears
    /// challengeDay), then mark this attempt as that challenge. No-op if unavailable / in the future.
    func playChallenge(_ day: Int) {
        guard day >= 0, day < pool.count, day <= todayIndex() else { return }
        deal(seed: pool[day].seed)   // resets telem + clears challengeDay + dailyResult
        challengeDay = day
        persist()
    }

    /// Fold a won challenge attempt into the day's record (OR-accumulated). Returns the graded
    /// attempt for the win overlay, or nil for casual play. Clears challengeDay.
    private func recordChallengeResult(secs: Int) -> TierResult? {
        guard let day = challengeDay, let ch = dailyChallenge(day, pool) else { return nil }
        let attempt = Attempt(won: true, moves: moveCount, elapsed: secs,
                              cellUses: telem.cellUses, undos: telem.undos,
                              foundationOrder: telem.foundationOrder)
        let res = evaluateChallenge(ch, attempt)
        dailyStore.record(day: day, result: res)
        challengeDay = nil
        return res
    }

    /// The live objectives HUD's view of the current challenge attempt (nil when not on a challenge).
    /// The authoritative scoring happens at win via the checkers; this drives the in-play hints.
    var liveChallenge: Challenge? {
        guard let day = challengeDay else { return nil }
        return dailyChallenge(day, pool)
    }
    /// A snapshot of the current attempt's telemetry for the HUD (`won` reflects the live board).
    func liveAttempt() -> Attempt {
        Attempt(won: checkWin(), moves: moveCount, elapsed: 0,
                cellUses: telem.cellUses, undos: telem.undos, foundationOrder: telem.foundationOrder)
    }
    private func onWin() {
        recordWin()   // no-op if the winning step already recorded it
        won = true
    }

    private func startTimer() { clock.start() }
    private func stopTimer() { clock.stop() }

    // helpers for views
    var nextSeed: Int { seed >= Game.maxSeed ? 1 : seed + 1 }
}
