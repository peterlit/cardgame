// Renders the Causeway app icon to a 1024x1024 PNG.
// Usage: swift make_icon.swift <output.png>
import AppKit
import Foundation
import ImageIO
import CoreGraphics

let size: CGFloat = 1024
guard CommandLine.arguments.count > 1 else { fatalError("usage: make_icon.swift <out.png>") }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("rep") }
rep.size = NSSize(width: size, height: size)
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

let bounds = NSRect(x: 0, y: 0, width: size, height: size)

// Background: misty teal, darker at the edges for depth.
NSGradient(colors: [color(0x2C3B3A), color(0x5D706C), color(0x87998F)])!.draw(in: bounds, angle: 90)
NSGradient(colors: [NSColor(white: 1, alpha: 0.16), NSColor(white: 1, alpha: 0)])!
    .draw(fromCenter: NSPoint(x: size/2, y: size*0.58), radius: 0,
          toCenter: NSPoint(x: size/2, y: size*0.58), radius: size*0.55, options: [])

func drawSuit(_ name: String, color c: NSColor, center: NSPoint, height: CGFloat) {
    let cfg = NSImage.SymbolConfiguration(pointSize: height, weight: .black)
        .applying(.init(paletteColors: [c]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return }
    let s = img.size
    img.draw(in: NSRect(x: center.x - s.width/2, y: center.y - s.height/2, width: s.width, height: s.height))
}

func drawText(_ s: String, size fs: CGFloat, color c: NSColor, center: NSPoint) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fs, weight: .heavy), .foregroundColor: c]
    let sz = s.size(withAttributes: attrs)
    s.draw(at: NSPoint(x: center.x - sz.width/2, y: center.y - sz.height/2), withAttributes: attrs)
}

func drawCard(cx: CGFloat, cy: CGFloat, rot: CGFloat, content: () -> Void) {
    let w: CGFloat = 360, h: CGFloat = 512
    let rect = NSRect(x: -w/2, y: -h/2, width: w, height: h)
    let path = NSBezierPath(roundedRect: rect, xRadius: 46, yRadius: 46)

    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: cx, yBy: cy)
    t.rotate(byDegrees: rot)
    t.concat()

    // drop shadow under the card
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow()
    sh.shadowColor = NSColor(white: 0, alpha: 0.38)
    sh.shadowBlurRadius = 40
    sh.shadowOffset = NSSize(width: 0, height: -16)
    sh.set()
    color(0xF4EFE0).setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    color(0xCDBF9D).setStroke()
    path.lineWidth = 5
    path.stroke()

    content()
    NSGraphicsContext.restoreGraphicsState()
}

// Left card — Ace of hearts (the "up" end), leaning toward centre.
drawCard(cx: 384, cy: 506, rot: -11) {
    let red = color(0xB04738)
    drawSuit("suit.heart.fill", color: red, center: NSPoint(x: -24, y: -34), height: 180)
    drawText("A", size: 92, color: red, center: NSPoint(x: -120, y: 168))
}
// Right card — King of spades (the "down" end), drawn on top.
drawCard(cx: 640, cy: 506, rot: 11) {
    let navy = color(0x2A3B44)
    drawSuit("suit.spade.fill", color: navy, center: NSPoint(x: 24, y: -34), height: 180)
    drawText("K", size: 92, color: navy, center: NSPoint(x: 120, y: 168))
}

NSGraphicsContext.restoreGraphicsState()

// Flatten to an OPAQUE PNG (no alpha channel) — App Store Connect rejects marketing
// icons that carry an alpha channel. The drawn background already covers every pixel.
guard let drawn = rep.cgImage else { fatalError("cgImage") }
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx2 = CGContext(data: nil, width: Int(size), height: Int(size),
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("ctx") }
ctx2.draw(drawn, in: CGRect(x: 0, y: 0, width: size, height: size))
guard let opaque = ctx2.makeImage(),
      let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("dest") }
CGImageDestinationAddImage(dest, opaque, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("finalize") }
print("wrote \(outURL.path) (opaque)")
