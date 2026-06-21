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

            // rank + suit spanning the full card width, like a bold banner
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: width * 0.04) {
                    Text(card.rankLabel)
                        .font(.system(size: width * 0.52, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    Image(systemName: card.suit.sfSymbol)
                        .font(.system(size: width * 0.44, weight: .bold))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(color)
            .padding(.horizontal, width * 0.1)
            .padding(.top, width * 0.08)

            // centre figure — court symbol for J/Q/K, otherwise a single large pip.
            // Both sit low-centre so they never overlap the top-left index.
            Image(systemName: card.rank >= 11 ? courtSymbol : card.suit.sfSymbol)
                .font(.system(size: width * (card.rank >= 11 ? 0.46 : 0.5)))
                .foregroundStyle(color)
                .offset(y: height * 0.12)
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
