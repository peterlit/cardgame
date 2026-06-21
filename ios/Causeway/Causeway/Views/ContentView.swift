import SwiftUI

struct ContentView: View {
    @StateObject private var game = Game()
    @Namespace private var ns

    @State private var showWins = false
    @State private var showDeal = false
    @State private var showRules = false
    @State private var dealText = ""

    private let outerPad: CGFloat = 6
    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let cardW = floor((geo.size.width - outerPad * 2 - gap * 7) / 8)
            let overlap = (cardW * Theme.cardAspect * 0.33).rounded()

            ZStack {
                SummerBackground()

                VStack(alignment: .leading, spacing: 12) {
                    header
                    toolbar
                    upperArea(cardW: cardW)
                    tableauArea(cardW: cardW, overlap: overlap)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, outerPad)
                .padding(.top, 6)

                if game.won { winOverlay }
            }
            .foregroundStyle(Theme.ink)
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
            stat("Time", DealFormat.time(game.elapsed))
            stat("Won", "\(game.winStore.count)")
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
            pill("Auto-finish") { game.autoFinish() }
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

    private func cellView(_ i: Int, cardW: CGFloat) -> some View {
        Group {
            if let c = game.cells[i] {
                CardView(card: c, width: cardW, selected: game.isSelected(.cell(i)))
                    .matchedGeometryEffect(id: c.id, in: ns)
                    .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.16)) { game.smartMove(.cell(i)) } }
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapCard(.cell(i)) } }
            } else {
                SlotView(width: cardW)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapCell(i) } }
            }
        }
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
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapFoundation(suit: suit, dir: dir) } }
            } else {
                SlotView(width: cardW, glyphSuit: suit)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapFoundation(suit: suit, dir: dir) } }
            }
        }
    }

    // MARK: tableau

    private func tableauArea(cardW: CGFloat, overlap: CGFloat) -> some View {
        let cardH = cardW * Theme.cardAspect
        return HStack(alignment: .top, spacing: gap) {
            ForEach(0..<Game.colCount, id: \.self) { col in
                column(col, cardW: cardW, cardH: cardH, overlap: overlap)
            }
        }
    }
    private func column(_ col: Int, cardW: CGFloat, cardH: CGFloat, overlap: CGFloat) -> some View {
        let cards = game.tableau[col]
        let height = cards.isEmpty ? cardH : CGFloat(cards.count - 1) * overlap + cardH
        return ZStack(alignment: .top) {
            if cards.isEmpty {
                SlotView(width: cardW)
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapTableauColumn(col) } }
            }
            ForEach(Array(cards.enumerated()), id: \.element.id) { idx, card in
                CardView(card: card, width: cardW, selected: game.isSelected(.tableau(col: col, idx: idx)))
                    .matchedGeometryEffect(id: card.id, in: ns)
                    .offset(y: CGFloat(idx) * overlap)
                    .zIndex(Double(idx))
                    .onTapGesture(count: 2) { withAnimation(.easeOut(duration: 0.16)) { game.smartMove(.tableau(col: col, idx: idx)) } }
                    .onTapGesture { withAnimation(.easeOut(duration: 0.16)) { game.tapCard(.tableau(col: col, idx: idx)) } }
            }
        }
        .frame(width: cardW, height: height, alignment: .top)
    }

    // MARK: win overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("You solved it! 🎉").font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.gold)
                Text("Deal #\(game.seed) · \(game.moveCount) moves · \(DealFormat.time(game.elapsed))")
                    .font(.system(size: 14)).multilineTextAlignment(.center).foregroundStyle(.white)
                HStack(spacing: 8) {
                    pill("Play deal #\(game.nextSeed)", primary: true) { withAnimation { game.deal(seed: game.nextSeed) } }
                    pill("Random") { withAnimation { game.newRandomGame() } }
                    pill("Close") { game.won = false }
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: 0x2C3B3A)))
            .padding(28)
        }
    }
}

#Preview { ContentView() }
