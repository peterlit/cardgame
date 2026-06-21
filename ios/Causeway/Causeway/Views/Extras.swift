import SwiftUI

/// Simple wrapping flow layout so the toolbar pills flow onto as many rows as
/// needed instead of overflowing / hiding off-screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(maxW, widest), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let maxW = bounds.width
        var x: CGFloat = bounds.minX, y: CGFloat = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX, x - bounds.minX + sz.width > maxW {
                x = bounds.minX; y += rowH + spacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

/// How-to-play rules (ported from the web prototype).
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rule("Goal", "Move all 52 cards to the foundations. Each suit has two foundations — an up pile (A, 2, 3 …) and a down pile (K, Q, J …). They build toward each other and meet in the middle; you choose where each suit splits.")
                    rule("The catch", "The up and down halves of a suit can never cross. A 7 or 8 has no home until the ends climb to reach it — plan around it.")
                    rule("Tableau", "Build in alternating colours, one rank at a time, in either direction — a pile can run down (red on black) or up. Pick a direction when you start a pile; you can't reverse it partway. Move a tidy run as a group if you have enough free cells and empty columns.")
                    rule("Free cells", "Three single-card parking spots.")
                    rule("Controls", "Tap a card to pick it up, then tap where it should go. Double-tap a card to auto-move it: to a foundation if it fits, otherwise onto another card, an empty column, or a free cell. Everything is face-up — it's pure skill.")
                }
                .padding()
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func rule(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundStyle(Theme.gold)
            Text(body).font(.subheadline).foregroundStyle(.primary)
        }
    }
}
