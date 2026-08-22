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
        // Stable programmatic handle + VoiceOver semantics. Identifier format "card.<S><rank>"
        // with S ∈ S/H/D/C and rank 1–13, e.g. "card.H10" = 10♥ — unique per card, orientation-
        // and position-independent, so UI tests can address cards without raw coordinates.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("card.\(Self.suitLetters[card.suit.rawValue])\(card.rank)")
        .accessibilityLabel("\(rankName) of \(Self.suitNames[card.suit.rawValue])")
    }

    private static let suitLetters = ["S", "H", "D", "C"]
    private static let suitNames = ["spades", "hearts", "diamonds", "clubs"]
    private var rankName: String {
        switch card.rank {
        case 1: return "ace"
        case 11: return "jack"
        case 12: return "queen"
        case 13: return "king"
        default: return "\(card.rank)"
        }
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
    /// Which END this (empty) foundation builds from — "A" for the up pile, "K" for the down pile.
    /// The board's two foundation rows were otherwise identical empty suit slots under one
    /// FOUNDATIONS heading, so nothing on screen said which row takes an Ace and which takes a
    /// King; an Ace dragged to the wrong row just snapped back (ux/WF-1:foundation-rows-unlabelled).
    /// Only ever set on EMPTY slots — an occupied foundation shows its real card, unchanged.
    var startRank: String? = nil

    private var height: CGFloat { width * Theme.cardAspect }

    var body: some View {
        RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
            .fill(Color.white.opacity(0.22))
            .overlay(RoundedRectangle(cornerRadius: width * 0.11, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.28), lineWidth: 2))
            .overlay(glyphView)
            .overlay(alignment: .topLeading) { startGlyph }
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

    // "A"/"K" hint in the rank corner — same position a real card puts its rank, so the empty slot
    // reads as "the card that starts here".
    @ViewBuilder private var startGlyph: some View {
        if let r = startRank {
            Text(r)
                .font(.system(size: width * 0.3, weight: .bold, design: .serif))
                .foregroundStyle(Theme.ink.opacity(0.45))
                .padding(.leading, width * 0.1)
                .padding(.top, width * 0.06)
                .accessibilityHidden(true)
        }
    }
}
