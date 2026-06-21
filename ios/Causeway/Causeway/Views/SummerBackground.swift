import SwiftUI

/// Original "sun & summer" background: warm sky, radiating sun, soft clouds,
/// a calm sea and sandy beach with a little sailboat. Drawn as vectors so it
/// stays crisp at any resolution. Kept calm in the upper half where cards sit.
struct SummerBackground: View {
    // Pinwheel sun rays (alternating warm wedges and gaps).
    private static let rayStops: [Gradient.Stop] = {
        var s: [Gradient.Stop] = []
        let n = 20
        for i in 0..<n {
            let c = i % 2 == 0 ? Color(hex: 0xFFE7A0).opacity(0.55) : Color.clear
            s.append(.init(color: c, location: Double(i) / Double(n)))
            s.append(.init(color: c, location: Double(i + 1) / Double(n)))
        }
        return s
    }()

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let sun = CGPoint(x: w * 0.5, y: h * 0.58)
            let horizon = h * 0.72
            let sandTop = h * 0.85
            let rayD = max(w, h) * 1.9

            ZStack {
                // Sky
                LinearGradient(stops: [
                    .init(color: Color(hex: 0xFFD777), location: 0.0),
                    .init(color: Color(hex: 0xFDE6A2), location: 0.42),
                    .init(color: Color(hex: 0xFDF1D2), location: 0.72),
                    .init(color: Color(hex: 0xFBF4DC), location: 1.0),
                ], startPoint: .top, endPoint: .bottom)

                // Sun rays
                AngularGradient(gradient: Gradient(stops: Self.rayStops), center: .center)
                    .frame(width: rayD, height: rayD)
                    .mask(RadialGradient(colors: [.white, .white.opacity(0)],
                                         center: .center, startRadius: rayD * 0.04, endRadius: rayD * 0.30))
                    .blur(radius: 3)
                    .opacity(0.45)
                    .position(sun)

                // Sun glow + disc
                RadialGradient(colors: [Color(hex: 0xFFF6D6).opacity(0.9), Color(hex: 0xFBD45F).opacity(0)],
                               center: .center, startRadius: 0, endRadius: w * 0.55)
                    .frame(width: w * 1.2, height: w * 1.2).position(sun)
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFFF3CC), Color(hex: 0xFAC74B)],
                                         center: .center, startRadius: 0, endRadius: w * 0.30))
                    .frame(width: w * 0.56, height: w * 0.56)
                    .position(sun)

                // Clouds
                cloud(w * 0.22).position(x: w * 0.24, y: h * 0.15).opacity(0.9)
                cloud(w * 0.15).position(x: w * 0.82, y: h * 0.10).opacity(0.8)
                cloud(w * 0.18).position(x: w * 0.66, y: h * 0.31).opacity(0.65)

                // Sea then sand (both with a gentle wavy top edge)
                wave(baseY: horizon, amp: h * 0.012, to: h, width: w)
                    .fill(LinearGradient(colors: [Color(hex: 0xA3DBC8), Color(hex: 0x82CBB6)],
                                         startPoint: .top, endPoint: .bottom))
                wave(baseY: sandTop, amp: h * 0.010, to: h, width: w)
                    .fill(LinearGradient(colors: [Color(hex: 0xF4DEA8), Color(hex: 0xE9CE8F)],
                                         startPoint: .top, endPoint: .bottom))

                // Sailboat resting on the water
                sailboat(size: w * 0.12).position(x: w * 0.7, y: horizon - w * 0.012)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }

    private func cloud(_ s: CGFloat) -> some View {
        ZStack {
            Circle().frame(width: s, height: s)
            Circle().frame(width: s * 0.72, height: s * 0.72).offset(x: -s * 0.55, y: s * 0.05)
            Circle().frame(width: s * 0.8, height: s * 0.8).offset(x: s * 0.55, y: s * 0.04)
            Capsule().frame(width: s * 1.8, height: s * 0.6).offset(y: s * 0.2)
        }
        .foregroundStyle(.white)
        .blur(radius: s * 0.05)
    }

    private func wave(baseY: CGFloat, amp: CGFloat, to bottom: CGFloat, width w: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: baseY))
        let segs = 4
        let sw = w / CGFloat(segs)
        for i in 0..<segs {
            let x = CGFloat(i) * sw
            p.addQuadCurve(to: CGPoint(x: x + sw, y: baseY),
                           control: CGPoint(x: x + sw / 2, y: baseY + (i % 2 == 0 ? -amp : amp)))
        }
        p.addLine(to: CGPoint(x: w, y: bottom))
        p.addLine(to: CGPoint(x: 0, y: bottom))
        p.closeSubpath()
        return p
    }

    private func sailboat(size s: CGFloat) -> some View {
        ZStack {
            Path { p in   // sail
                p.move(to: CGPoint(x: s * 0.02, y: -s * 0.52))
                p.addLine(to: CGPoint(x: s * 0.42, y: s * 0.24))
                p.addLine(to: CGPoint(x: s * 0.02, y: s * 0.24))
                p.closeSubpath()
            }.fill(Color(hex: 0xE8674F))
            Path { p in   // hull
                p.move(to: CGPoint(x: -s * 0.46, y: s * 0.26))
                p.addLine(to: CGPoint(x: s * 0.46, y: s * 0.26))
                p.addLine(to: CGPoint(x: s * 0.3, y: s * 0.5))
                p.addLine(to: CGPoint(x: -s * 0.3, y: s * 0.5))
                p.closeSubpath()
            }.fill(Color(hex: 0x3A4A55))
        }
        .frame(width: s, height: s)
    }
}

#Preview { SummerBackground() }
