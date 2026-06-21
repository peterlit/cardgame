import SwiftUI

/// One playing card. `width` drives all internal sizing so cards scale to the device.
struct CardView: View {
    let card: Card
    let width: CGFloat
    var selected: Bool = false

    private var height: CGFloat { width * Theme.cardAspect }
    private var color: Color { Theme.suitColor(card.suit) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .fill(LinearGradient(colors: [Theme.cardCreamTop, Theme.cardTintBottom(card.suit)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                        .strokeBorder(Theme.cardEdge, lineWidth: 1))

            // rank + suit value banner across the full card width.
            // The suit is a fixed-height image; the rank font is sized so its
            // cap-height matches that height (~0.72 cap ratio) — equal heights.
            VStack(spacing: 0) {
                HStack(spacing: width * 0.04) {
                    rankText
                    Spacer(minLength: 0)
                    Image(systemName: card.suit.sfSymbol)
                        .resizable().scaledToFit()
                        .frame(height: width * 0.42)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, width * 0.09)
            .padding(.top, width * 0.08)

            // centre pip — noticeably larger than the value glyphs, seated low so
            // it never overlaps the banner. (court figure for J/Q/K)
            Image(systemName: card.rank >= 11 ? courtSymbol : card.suit.sfSymbol)
                .resizable().scaledToFit()
                .frame(height: width * (card.rank >= 11 ? 0.58 : 0.66))
                .foregroundStyle(color)
                .offset(y: height * 0.17)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .strokeBorder(Theme.gold, lineWidth: selected ? 3 : 0))
        .offset(y: selected ? -width * 0.05 : 0)
    }

    /// J / Q / K figure symbol (crown for K, open crown for Q, person for J).
    private var courtSymbol: String {
        card.rank == 13 ? "crown.fill" : card.rank == 12 ? "crown" : "person.fill"
    }

    private var rankFont: Font { .system(size: width * 0.58, weight: .heavy, design: .rounded) }

    /// Rank glyph. "10" is rendered at full height but condensed horizontally so
    /// it stays as tall as single-digit ranks while keeping a single-digit width.
    @ViewBuilder private var rankText: some View {
        if card.rank == 10 {
            Text("10").font(rankFont).fixedSize()
                .scaleEffect(x: 0.6, y: 1, anchor: .leading)
                .frame(width: width * 0.36, alignment: .leading)
        } else {
            Text(card.rankLabel).font(rankFont).lineLimit(1)
        }
    }
}

/// Empty drop slot (free cell or foundation), with an optional faint glyph.
struct SlotView: View {
    let width: CGFloat
    var glyph: String? = nil
    var glyphSuit: Suit? = nil

    private var height: CGFloat { width * Theme.cardAspect }

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
            .fill(Color.white.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.28), lineWidth: 2))
            .overlay(glyphView)
            .frame(width: width, height: height)
    }

    // Watermarks read on the light summer background (and over clouds):
    // suit-coloured pips for foundations, soft ink for any text glyph.
    @ViewBuilder private var glyphView: some View {
        if let suit = glyphSuit {
            Image(systemName: suit.sfSymbol)
                .font(.system(size: width * 0.4))
                .foregroundStyle(Theme.suitColor(suit).opacity(0.4))
        } else if let g = glyph {
            Text(g).font(.system(size: width * 0.42, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink.opacity(0.3))
        }
    }
}
