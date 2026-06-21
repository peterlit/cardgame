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
    static let cardEdge = Color(hex: 0xCDBF9D)
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
