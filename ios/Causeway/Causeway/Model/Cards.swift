import Foundation

/// Suit indices match the web prototype: 0 spade, 1 heart, 2 diamond, 3 club.
enum Suit: Int, CaseIterable, Codable {
    case spade = 0, heart, diamond, club

    var isRed: Bool { self == .heart || self == .diamond }
    var glyph: String { ["♠", "♥", "♦", "♣"][rawValue] }
    /// SF Symbol used to draw the pip.
    var sfSymbol: String {
        ["suit.spade.fill", "suit.heart.fill", "suit.diamond.fill", "suit.club.fill"][rawValue]
    }
}

struct Card: Identifiable, Equatable, Hashable, Codable {
    let suit: Suit
    let rank: Int        // 1...13 (Ace = 1, King = 13)

    /// Stable id matching the web build (suit*13 + rank) — also used for animations.
    var id: Int { suit.rawValue * 13 + rank }
    var isRed: Bool { suit.isRed }

    var rankLabel: String {
        ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank]
    }
}

/// Deterministic PRNG ported verbatim from the web build's mulberry32 so a given
/// deal number produces the identical layout on web and iOS.
struct Mulberry32 {
    private var a: UInt32
    init(_ seed: UInt32) { a = seed }

    mutating func next() -> Double {
        a = a &+ 0x6D2B79F5
        var t = (a ^ (a >> 15)) &* (a | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }

    /// Integer in 0..<bound (matches Math.floor(rng()*bound)).
    mutating func int(_ bound: Int) -> Int { Int(next() * Double(bound)) }
}
