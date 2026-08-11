import SwiftUI

/// One playing card. `width` drives all internal sizing so cards scale to the device.
struct CardView: View {
    let card: Card
    let width: CGFloat

    private var height: CGFloat { width * Theme.cardAspect }
    private var color: Color { Theme.suitColor(card.suit) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .fill(Color.white)
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
                    suitPip(card.suit, height: width * 0.36)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, width * 0.09)
            .padding(.top, width * 0.05)

            // centre pip — noticeably larger than the value glyphs, seated low so
            // it never overlaps the banner. (court figure for J/Q/K)
            Group {
                if card.rank >= 11 {
                    Image(systemName: courtSymbol).resizable().scaledToFit().frame(height: width * 0.58)
                } else {
                    suitPip(card.suit, height: width * 0.66)
                }
            }
            .foregroundStyle(color)
            .offset(y: height * 0.17)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
    }

    /// J / Q / K figure symbol (crown for K, open crown for Q, person for J).
    private var courtSymbol: String {
        card.rank == 13 ? "crown.fill" : card.rank == 12 ? "crown" : "person.fill"
    }

    private var rankFont: Font { .system(size: width * 0.50, weight: .heavy, design: .rounded) }

    /// Suit pip sized to a consistent visual width. The diamond symbol is
    /// intrinsically narrow (aspect ~0.84), so it's stretched to ~square to
    /// match the width of the other suits; the rest keep their natural aspect.
    @ViewBuilder private func suitPip(_ s: Suit, height h: CGFloat) -> some View {
        if s == .diamond {
            Image(systemName: s.sfSymbol).resizable().frame(width: h, height: h)
        } else {
            Image(systemName: s.sfSymbol).resizable().scaledToFit().frame(height: h)
        }
    }

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

    // Foundation watermark: suit-coloured pip, readable on the light summer background.
    @ViewBuilder private var glyphView: some View {
        if let suit = glyphSuit {
            Image(systemName: suit.sfSymbol)
                .font(.system(size: width * 0.4))
                .foregroundStyle(Theme.suitColor(suit).opacity(0.4))
        }
    }
}
