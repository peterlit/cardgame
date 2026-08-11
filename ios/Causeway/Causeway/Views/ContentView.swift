import SwiftUI

/// A card/run being dragged: its source and how far the finger has moved (board coords).
private struct DragInfo: Equatable {
    var source: Spot
    var translation: CGSize
}

/// A drop target's live frame in the board coordinate space, collected via preferences.
private struct DropZoneFrame: Equatable {
    var target: DropTarget
    var rect: CGRect
}
private struct DropZonesKey: PreferenceKey {
    static var defaultValue: [DropZoneFrame] = []
    static func reduce(value: inout [DropZoneFrame], nextValue: () -> [DropZoneFrame]) {
        value.append(contentsOf: nextValue())
    }
}

struct ContentView: View {
    @StateObject private var game = Game()
    @Namespace private var ns
    @Environment(\.scenePhase) private var scenePhase

    @State private var showWins = false
    @State private var showDeal = false
    @State private var showRules = false
    @State private var dealText = ""

    // Manual drag-and-drop (see cardGesture): source+offset while dragging, and the live
    // frames of every drop target in the "board" coordinate space for hit-testing on drop.
    @State private var drag: DragInfo?
    @State private var dropZones: [DropZoneFrame] = []
    private let tapSlop: CGFloat = 8   // finger travel under this = a tap, not a drag

    private let outerPad: CGFloat = 6
    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let cardW = floor((geo.size.width - outerPad * 2 - gap * 7) / 8)
            let overlap = (cardW * Theme.cardAspect * 0.40).rounded()

            ZStack {
                SummerBackground().equatable()   // never changes; skip re-rasterizing its blur layers

                VStack(alignment: .leading, spacing: 12) {
                    header
                    toolbar
                    upperArea(cardW: cardW)
                        .zIndex(dragInUpper ? 10 : 0)      // a dragged free-cell card floats over the tableau
                    tableauArea(cardW: cardW, overlap: overlap)
                        .zIndex(dragInUpper ? 0 : 1)       // ...otherwise the tableau floats over the free cells
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, outerPad)
                .padding(.top, 6)

                if game.won { winOverlay }

                if DebugFlags.memoryHUD {
                    VStack { Spacer(); MemoryHUD().padding(.bottom, 6) }   // TESTING ONLY
                }
            }
            .coordinateSpace(name: "board")
            .onPreferenceChange(DropZonesKey.self) { dropZones = $0 }
            .foregroundStyle(Theme.ink)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { game.persist() }   // capture latest board + elapsed before eviction
        }
        .onChange(of: game.moveCount) { _, _ in
            // Self-heal a drag whose card was torn down mid-gesture by an async autoplay step
            // (its view — and gesture — vanish, so onEnded never fires, leaving `drag` stuck at
            // an elevated zIndex). Only clear when the source no longer holds its card, so an
            // unrelated autoplay never cancels a legitimate in-flight drag (whose source still
            // holds the card until the drop mutates the board).
            if let d = drag, !dragSourceHoldsCard(d.source) { drag = nil }
        }
        .sheet(isPresented: $showWins) { WinsView(game: game) }
        .sheet(isPresented: $showRules) { RulesView() }
        .alert("Play a deal", isPresented: $showDeal) {
            TextField("1–1,000,000", text: $dealText).keyboardType(.numberPad)
            Button("Play") {
                if let n = Int(dealText) { withAnimation { game.deal(seed: n) } }
            }
            Button("Random") { withAnimation { game.newRandomGame() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter a deal number to play that exact deal.") }
        .alert("Ready to finish", isPresented: $game.promptAutoFinish) {
            Button("Finish") { withAnimation { game.runAutoFinish() } }
            Button("Not yet", role: .cancel) { game.deferAutoFinish() }
        } message: { Text("Every remaining card can go home. Send them all now?") }
    }

    // MARK: header + toolbar

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Causeway").font(.system(size: 22, weight: .bold, design: .serif))
                Text("build each suit from both ends").font(.system(size: 11)).opacity(0.65)
            }
            Spacer()
            stat("Moves", "\(game.moveCount)")
            ClockStat(clock: game.clock)   // observes only the clock, so its 1 Hz tick
            stat("Won", "\(game.winStore.count)")   // doesn't re-render the board
        }
    }
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 12)).opacity(0.8)
            Text(value).font(.system(size: 18, weight: .bold, design: .serif))
        }
    }

    private var toolbar: some View {
        FlowLayout(spacing: 8) {
            pill("New game", primary: true) { withAnimation { game.newRandomGame() } }
            pill("Undo") { withAnimation { game.undo() } }.disabled(!game.canUndo).opacity(game.canUndo ? 1 : 0.4)
            pill(game.autoplayOn ? "Auto-play: On" : "Auto-play: Off") { game.autoplayOn.toggle() }
            pill("Auto-finish: \(game.autoFinishMode.label)") { game.cycleAutoFinishMode() }
            if game.canOfferFinish {
                pill("Finish", primary: true) { withAnimation { game.runAutoFinish() } }
            }
            pill("Deal #\(game.seed)\(game.winStore.isWon(game.seed) ? " ✓" : "")") {
                dealText = "\(game.seed)"; showDeal = true
            }
            pill("Wins") { showWins = true }
            pill("How to play") { showRules = true }
        }
    }
    private func pill(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(primary ? Theme.gold : Color(hex: 0x2A3B44).opacity(0.46)))
                .foregroundStyle(primary ? Color(hex: 0x3A2B00) : Color(hex: 0xF4EFE2))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        }
    }

    // MARK: free cells + foundations

    private func upperArea(cardW: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                groupLabel("FREE CELLS")
                HStack(spacing: gap) {
                    ForEach(0..<Game.cellCount, id: \.self) { i in
                        cellView(i, cardW: cardW)
                            .zIndex(drag?.source == .cell(i) ? 5 : 0)   // dragged cell floats over its neighbours
                    }
                }
            }
            Spacer(minLength: gap)
            VStack(alignment: .trailing, spacing: 4) {
                groupLabel("FOUNDATIONS")
                VStack(spacing: gap) {
                    foundationRow(dir: .up, cardW: cardW)
                    foundationRow(dir: .down, cardW: cardW)
                }
            }
        }
    }
    private func groupLabel(_ t: String) -> some View {
        Text(t).font(.system(size: 10, weight: .semibold)).tracking(1).opacity(0.6)
    }

    // MARK: tap / drag

    private var dragInUpper: Bool { if case .cell = drag?.source { return true } else { return false } }
    private var dragColumn: Int? { if case .tableau(let c, _) = drag?.source { return c } else { return nil } }

    /// Whether the drag's source slot still holds its card. False once an autoplay step has
    /// removed the dragged card out from under the finger — used to self-heal a stuck drag.
    private func dragSourceHoldsCard(_ s: Spot) -> Bool {
        switch s {
        case .cell(let i):            return game.cells[i] != nil
        case .tableau(let c, let i):  return i < game.tableau[c].count
        }
    }

    /// The finger offset to apply to `spot` — non-zero only for the card(s) in the run
    /// currently being dragged (the run head plus everything stacked below it).
    private func runOffset(_ spot: Spot) -> CGSize {
        guard let d = drag else { return .zero }
        switch (d.source, spot) {
        case (.cell(let a), .cell(let b)):
            return a == b ? d.translation : .zero
        case (.tableau(let sc, let si), .tableau(let c, let i)):
            return (sc == c && i >= si) ? d.translation : .zero
        default:
            return .zero
        }
    }

    /// One unified gesture per card: a small finger travel is a tap (smart-move); a larger one
    /// is a drag that drops onto whichever registered drop zone is under the finger on release.
    /// `minimumDistance: 0` means the card follows the finger instantly — no press-and-hold.
    private func cardGesture(for spot: Spot, canDrag: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("board"))
            .onChanged { v in
                guard canDrag else { return }
                if drag == nil { drag = DragInfo(source: spot, translation: v.translation) }
                else if drag?.source == spot { drag?.translation = v.translation }
            }
            .onEnded { v in
                // Ignore a second finger's release while another card owns the drag: acting on
                // it would fire a stray smartMove and clear `drag`, snapping the in-flight drag
                // back. Only the owning card (or a fresh tap, drag == nil) may resolve here.
                guard drag == nil || drag?.source == spot else { return }
                let travelled = hypot(v.translation.width, v.translation.height)
                withAnimation(.easeOut(duration: 0.18)) {
                    if travelled < tapSlop {
                        game.smartMove(spot)                                   // tap
                    } else if canDrag, let z = dropZones.first(where: { $0.rect.contains(v.location) }) {
                        game.drop(spot, to: z.target)                          // drop onto target under finger
                    }
                    drag = nil                                                 // else: snaps back
                }
            }
    }

    /// A transparent probe that reports this view's frame in board coordinates as a drop zone.
    private func dropZone(_ target: DropTarget) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: DropZonesKey.self,
                                   value: [DropZoneFrame(target: target, rect: g.frame(in: .named("board")))])
        }
    }

    private func cellView(_ i: Int, cardW: CGFloat) -> some View {
        Group {
            if let c = game.cells[i] {
                CardView(card: c, width: cardW)
                    .matchedGeometryEffect(id: c.id, in: ns)
                    .offset(runOffset(.cell(i)))
                    .gesture(cardGesture(for: .cell(i), canDrag: true))
            } else {
                SlotView(width: cardW)
            }
        }
        .background(dropZone(.cell(i)))
    }

    private func foundationRow(dir: Dir, cardW: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(Suit.allCases, id: \.rawValue) { suit in
                foundationCell(suit: suit, dir: dir, cardW: cardW)
            }
        }
    }
    private func foundationCell(suit: Suit, dir: Dir, cardW: CGFloat) -> some View {
        let s = suit.rawValue
        let rank = dir == .up ? game.up[s] : (game.down[s] < 14 ? game.down[s] : 0)
        return Group {
            if rank >= 1 {
                let card = Card(suit: suit, rank: rank)
                CardView(card: card, width: cardW)
                    .matchedGeometryEffect(id: card.id, in: ns)
            } else {
                SlotView(width: cardW, glyphSuit: suit)
            }
        }
        .background(dropZone(.foundation(suit, dir)))   // drop target only; foundation cards aren't dragged
    }

    // MARK: tableau

    private func tableauArea(cardW: CGFloat, overlap: CGFloat) -> some View {
        let cardH = cardW * Theme.cardAspect
        return HStack(alignment: .top, spacing: gap) {
            ForEach(0..<Game.colCount, id: \.self) { col in
                column(col, cardW: cardW, cardH: cardH, overlap: overlap)
                    .zIndex(dragColumn == col ? 5 : 0)   // the column holding the dragged run floats over its neighbours
            }
        }
    }
    private func column(_ col: Int, cardW: CGFloat, cardH: CGFloat, overlap: CGFloat) -> some View {
        let cards = game.tableau[col]
        let height = cards.isEmpty ? cardH : CGFloat(cards.count - 1) * overlap + cardH
        return ZStack(alignment: .top) {
            if cards.isEmpty {
                SlotView(width: cardW)
            }
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                tableauCard(col: col, idx: idx, card: card, cardW: cardW, overlap: overlap)
            }
        }
        .frame(width: cardW, height: height, alignment: .top)
        .background(dropZone(.column(col)))
    }

    /// A single tableau card: single tap = smart-move; drag = manual placement. Only cards
    /// heading a valid run can drag (so buried cards don't lift); every card is still tappable.
    private func tableauCard(col: Int, idx: Int, card: Card, cardW: CGFloat, overlap: CGFloat) -> some View {
        CardView(card: card, width: cardW)
            .matchedGeometryEffect(id: card.id, in: ns)
            .offset(y: CGFloat(idx) * overlap)              // fan the pile
            .offset(runOffset(.tableau(col: col, idx: idx))) // + follow the finger while dragging
            .zIndex(Double(idx))
            .gesture(cardGesture(for: .tableau(col: col, idx: idx),
                                 canDrag: game.isSeqHead(col: col, idx: idx)))
    }

    // MARK: win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("You solved it! 🎉").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.gold)
                Text("Deal #\(game.seed) · \(game.moveCount) moves · \(DealFormat.time(game.clock.elapsed))")
                    .font(.system(size: 14)).multilineTextAlignment(.center).foregroundStyle(.white)
                HStack(spacing: 8) {
                    pill("Play deal #\(game.nextSeed)", primary: true) { withAnimation { game.deal(seed: game.nextSeed) } }
                    pill("Random") { withAnimation { game.newRandomGame() } }
                    pill("Close") { game.dismissWin() }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x2C3B3A)))
            .padding(28)
        }
    }
}

/// Time readout that observes only the isolated clock, so its per-second update
/// invalidates just this label instead of the whole board.
private struct ClockStat: View {
    @ObservedObject var clock: GameClock
    var body: some View {
        VStack(spacing: 1) {
            Text("Time").font(.system(size: 12)).opacity(0.8)
            Text(DealFormat.time(clock.elapsed)).font(.system(size: 18, weight: .bold, design: .serif))
        }
    }
}

#Preview { ContentView() }
