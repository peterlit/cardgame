import Foundation
import SwiftUI
import Combine

/// A position a card can live in, used for selection and tap targets.
enum Spot: Equatable {
    case tableau(col: Int, idx: Int)
    case cell(Int)
}

enum Dir { case up, down }

private struct Snapshot {
    var tableau: [[Card]]
    var cells: [Card?]
    var up: [Int]
    var down: [Int]
    var moveCount: Int
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
    @Published var elapsed = 0
    @Published var won = false
    @Published var autoplayOn = true {
        didSet { UserDefaults.standard.set(autoplayOn, forKey: "causeway.autoplay"); if autoplayOn { runAutoplay() } }
    }

    let winStore = WinStore()

    private var history: [Snapshot] = []
    private var started = false
    private var timer: Timer?
    private var autoplaying = false
    private var cancellables = Set<AnyCancellable>()

    var canUndo: Bool { !history.isEmpty }

    init() {
        // WinStore is a nested ObservableObject; its changes don't propagate through the
        // parent automatically, so forward them (keeps "Won"/checkmark/Wins in sync).
        winStore.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        if UserDefaults.standard.object(forKey: "causeway.autoplay") != nil {
            autoplayOn = UserDefaults.standard.bool(forKey: "causeway.autoplay")
        }
        deal(seed: Int.random(in: 1...Game.maxSeed))
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
        elapsed = 0
        won = false
        started = false
        stopTimer()
        autoplaying = false
    }

    func newRandomGame() { deal(seed: randomSeed()) }

    // MARK: - Rules

    private func emptyColumns() -> Int { tableau.filter { $0.isEmpty }.count }
    private func freeCellCount() -> Int { cells.filter { $0 == nil }.count }

    private func maxMovable(targetEmpty: Bool) -> Int {
        let e = emptyColumns() - (targetEmpty ? 1 : 0)
        return (freeCellCount() + 1) * Int(pow(2.0, Double(max(0, e))))
    }

    /// Cards idx..end form an alternating-colour run monotonic by 1 (ascending or descending).
    func isSeqHead(col: Int, idx: Int) -> Bool {
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

    // MARK: - Move plumbing

    private func snapshot() {
        history.append(Snapshot(tableau: tableau, cells: cells, up: up, down: down, moveCount: moveCount))
        if history.count > 500 { history.removeFirst() }
    }

    private func commit() {
        moveCount += 1
        if !started { started = true; startTimer() }
        selection = nil
        if checkWin() { onWin(); return }
        runAutoplay()
    }

    func undo() {
        stopAutoplayPending()
        guard let h = history.popLast() else { return }
        tableau = h.tableau; cells = h.cells; up = h.up; down = h.down
        moveCount = h.moveCount
        selection = nil
        won = false
        // A win stops the clock; undoing back into play must resume it (else elapsed
        // freezes and a later re-win would persist a bogus best time).
        if started && timer == nil { startTimer() }
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

    func tapCard(_ spot: Spot) {
        if let sel = selection {
            if sel == spot { selection = nil; return }          // tap selected -> deselect
            if case .tableau(let col, _) = spot, tryMoveToTableau(col) { return }
            if case .cell(let i) = spot, tryMoveToCell(i) { return }
            // otherwise fall through to (re)select the tapped card
        }
        switch spot {
        case .cell(let i):
            if cells[i] != nil { selection = spot }
        case .tableau(let col, let idx):
            if isSeqHead(col: col, idx: idx) { selection = spot }
        }
    }

    func tapTableauColumn(_ col: Int) { _ = tryMoveToTableau(col) }
    func tapCell(_ i: Int) { _ = tryMoveToCell(i) }
    func tapFoundation(suit: Suit, dir: Dir) { _ = tryMoveToFoundation(suit: suit, dir: dir) }

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
                snapshot(); cells[i] = head; removeRun(spot); commit(); return
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
                moveCount += 1; return true
            }
        }
        for col in 0..<Game.colCount {
            guard let c = tableau[col].last, isSafeAutoplay(c) else { continue }
            snapshot(); selection = nil; tableau[col].removeLast()
            if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
            moveCount += 1; return true
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
                }
            }
        }
    }
    private func stopAutoplayPending() { autoplaying = false }

    /// Force every available card home (manual button).
    func autoFinish() {
        selection = nil
        var moved = true, any = false
        withAnimation(.easeOut(duration: 0.2)) {
            while moved {
                moved = false
                for i in 0..<Game.cellCount {
                    // OR, not XOR: a suit's closing card is legal on BOTH ends and
                    // either completes it identically — XOR wrongly skipped it.
                    if let c = cells[i], canFoundationUp(c) || canFoundationDown(c) {
                        snapshot(); cells[i] = nil
                        if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
                        moveCount += 1; moved = true; any = true
                    }
                }
                for col in 0..<Game.colCount {
                    guard let c = tableau[col].last, canFoundationUp(c) || canFoundationDown(c) else { continue }
                    snapshot(); tableau[col].removeLast()
                    if canFoundationUp(c) { up[c.suit.rawValue] = c.rank } else { down[c.suit.rawValue] = c.rank }
                    moveCount += 1; moved = true; any = true
                }
            }
        }
        if any && !started { started = true; startTimer() }
        if checkWin() { onWin() }
    }

    // MARK: - Win + timer

    private func onWin() {
        stopTimer()
        autoplaying = false
        winStore.record(seed: seed, moves: moveCount, secs: elapsed)
        won = true
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsed += 1
        }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    // helpers for views
    func isSelected(_ spot: Spot) -> Bool {
        guard let sel = selection else { return false }
        switch (sel, spot) {
        case (.cell(let a), .cell(let b)): return a == b
        case (.tableau(let sc, let si), .tableau(let c, let i)): return sc == c && i >= si
        default: return false
        }
    }
    var nextSeed: Int { seed >= Game.maxSeed ? 1 : seed + 1 }
}
