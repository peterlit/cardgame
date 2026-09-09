import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

/// Palette ported from the MobilityWare-style web theme.
enum Theme {
    /// Card height ÷ width. Standard playing-card ratio (92/66), made ~20% taller.
    static let cardAspect: CGFloat = (92.0 / 66.0) * 1.2

    static let cardCream = Color(hex: 0xF3ECD9)
    static let cardCreamTop = Color(hex: 0xF8F2E2)
    static let cardEdge = Color(hex: 0x000000)   // deepest-black card border on the white face
    static let red = Color(hex: 0xB04738)
    static let black = Color(hex: 0x2A3B44)
    static let ink = Color(hex: 0x33403C)
    static let gold = Color(hex: 0xD9AD55)

    /// Soft misty forest background (original, not the reference app's artwork).
    static let background = LinearGradient(
        colors: [Color(hex: 0x5D706C), Color(hex: 0x7B8F89), Color(hex: 0xA3B7AF),
                 Color(hex: 0xC2CEC3), Color(hex: 0xD3D8CC)],
        startPoint: .top, endPoint: .bottom)

    static func suitColor(_ suit: Suit) -> Color { suit.isRed ? red : black }

    /// Whisper-subtle per-suit tint on the cream base.
    static func cardTintBottom(_ suit: Suit) -> Color {
        switch suit {
        case .spade:   return Color(hex: 0xECEADB)
        case .heart:   return Color(hex: 0xF3E6D6)
        case .diamond: return Color(hex: 0xF4E8CF)
        case .club:    return Color(hex: 0xE9ECD9)
        }
    }
}

extension DynamicTypeSize {
    /// The UIKit content-size category this SwiftUI size corresponds to.
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

extension Theme {
    /// A fixed point size scaled for Dynamic Type. `Font.system(size:)` is deliberately fixed, and
    /// the Daily sheet used it everywhere — at Accessibility XXXL its 11 pt objective text sat
    /// beside 53 pt SF-Symbol checks that DO scale (ux/WF-5:daily-sheet-ignores-dynamic-type).
    /// At the default size this returns `base` unchanged, so no layout moves for anyone who has
    /// not asked for larger text; the board is intentionally NOT routed through this (its sizes
    /// are geometry, not type). Small copy (< 13 pt) follows the caption curve, which grows
    /// less steeply than body at accessibility sizes, so captions stay captions.
    static func scaled(_ base: CGFloat, for size: DynamicTypeSize) -> CGFloat {
        let style: UIFont.TextStyle = base < 13 ? .caption1 : .body
        let traits = UITraitCollection(preferredContentSizeCategory: size.uiContentSizeCategory)
        return UIFontMetrics(forTextStyle: style).scaledValue(for: base, compatibleWith: traits)
    }
}
