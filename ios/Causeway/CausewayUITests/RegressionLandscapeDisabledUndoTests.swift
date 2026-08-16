//
//  RegressionLandscapeDisabledUndoTests.swift
//  CausewayUITests
//
//  Regression tripwire for: bug/Main:landscape-disabled-undo-blank
//  Verified FIXED in qa-loop round 2 (build 5447237) by TC-12.1.
//
//  FIXED contract this test guards (see .qa-loop/ledger.json):
//   - In landscape, the left rail's DISABLED Undo pill still shows its
//     "arrow.uturn.backward" glyph and "Undo" label, greyed — NOT a
//     featureless blank capsule.
//   - Root cause was .buttonStyle(.plain) on railPill preserving the explicit
//     near-white label colour when disabled, which over the 0.4-opacity faded
//     capsule rendered as blank white. The fix removed the .plain style so the
//     default style greys the disabled label (ContentView.railPill — see the
//     "NO .buttonStyle(.plain) here" comment guarding the same contract in code).
//
//  Original repro: launch fresh (empty undo stack ⇒ Undo disabled), rotate to
//  landscape (XCUIDevice.shared.orientation = .landscapeLeft), look at the
//  second pill of the left rail between "New game" and "Replay"
//  (pt (127,102) with no HUD; (127,141) with the daily HUD — kept as comments
//  only; the query below is by identifier).
//
//  Detection note: the accessibility LABEL "Undo" is reported whether or not
//  the glyph/text is visibly rendered (the bug was purely visual — white text
//  on a white capsule), so a label assertion alone cannot catch a regression.
//  The core tripwire is therefore pixel contrast: an element screenshot of the
//  pill's centre must contain dark-ish label pixels against the light capsule.
//  A blank capsule is near-uniform (contrast ≈ 0). The 0.10 luminance-spread
//  threshold needs one verification run: measured-good pills should land well
//  above it (dark grey text on a light capsule), the blank-bug rendering well
//  below (uniform white).
//
//  Selector notes (mined from Views/*.swift on 5447237):
//   - rail Undo pill:  accessibilityIdentifier "toolbar.undo" — the SAME id is
//     used by the portrait toolbar pill and the landscape rail pill
//     (ContentView lines ~263/~366); only one hierarchy exists at a time, so
//     after rotation the query resolves to the rail pill. The test asserts the
//     window is actually landscape before trusting that.
//   - disabled state:  fresh launch ⇒ empty undo stack ⇒ game.canUndo == false
//     (.disabled(!game.canUndo).opacity(canUndo ? 1 : 0.4)).
//
import XCTest

final class RegressionLandscapeDisabledUndoTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        XCUIDevice.shared.orientation = .portrait
    }

    /// bug/Main:landscape-disabled-undo-blank — the disabled rail Undo pill
    /// must render a legible (greyed) glyph + label, not a blank capsule.
    func testLandscapeDisabledUndoPillIsNotBlank() throws {
        try XCTSkipIf(true, "verify selectors, then remove this line")

        let app = XCUIApplication()
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        // --- rotate to landscape (the finding's trigger) -------------------------
        XCUIDevice.shared.orientation = .landscapeLeft
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(waitFor(timeout: 5) { window.frame.width > window.frame.height },
                      "rotation to landscape never took effect")

        // --- the rail's Undo pill, disabled on a fresh board ---------------------
        let undo = app.buttons["toolbar.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5),
                      "no toolbar.undo pill in the landscape rail")
        XCTAssertFalse(undo.isEnabled,
                       "fresh launch should leave Undo disabled (empty undo stack) — " +
                       "precondition for the blank-pill bug not met")
        // Sanity only (see detection note in the header: this passes even when blank).
        XCTAssertTrue(undo.label.contains("Undo"))

        // --- THE core regression: the pill's face must have visible contrast -----
        // Central 60% crop excludes the capsule stroke, rounded corners and any
        // background bleed, isolating label-vs-capsule contrast.
        let shot = undo.screenshot().image
        guard let spread = luminanceSpread(of: shot, centralFraction: 0.6) else {
            XCTFail("could not read pixels of the Undo pill screenshot")
            return
        }
        XCTAssertGreaterThan(spread, 0.10,
                             "disabled landscape Undo pill is near-uniform " +
                             "(luminance spread \(spread)) — the blank white capsule is back")

        // --- collateral guard: the ENABLED pill still renders and acts -----------
        // (The round-1 fix candidate risked washing out the enabled state; round 2
        // verified enabled pills unchanged. Cheap to re-assert.)
        let newGame = app.buttons["toolbar.newgame"]
        XCTAssertTrue(newGame.exists)
        XCTAssertTrue(newGame.isEnabled)
        guard let ngSpread = luminanceSpread(of: newGame.screenshot().image, centralFraction: 0.6) else {
            XCTFail("could not read pixels of the New game pill screenshot")
            return
        }
        XCTAssertGreaterThan(ngSpread, 0.10, "enabled rail pill lost its label contrast")
    }

    // MARK: - helpers

    /// P95–P5 luminance spread (0…1) over the central `fraction` of the image.
    /// A blank capsule ⇒ near 0; text/glyph on a capsule ⇒ a clearly larger value.
    /// Percentiles (not min–max) so a stray anti-aliased pixel can't mask a
    /// regression or rescue a blank pill.
    private func luminanceSpread(of image: UIImage, centralFraction fraction: CGFloat) -> Double? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let cropW = Int(CGFloat(w) * fraction), cropH = Int(CGFloat(h) * fraction)
        guard cropW > 4, cropH > 4,
              let crop = cg.cropping(to: CGRect(x: (w - cropW) / 2, y: (h - cropH) / 2,
                                                width: cropW, height: cropH))
        else { return nil }

        // Redraw into a known RGBA8 layout so byte order is predictable.
        let bytesPerRow = cropW * 4
        var buf = [UInt8](repeating: 0, count: bytesPerRow * cropH)
        guard let ctx = CGContext(data: &buf, width: cropW, height: cropH,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(crop, in: CGRect(x: 0, y: 0, width: cropW, height: cropH))

        var lums: [Double] = []
        lums.reserveCapacity(cropW * cropH)
        for y in 0..<cropH {
            for x in 0..<cropW {
                let p = y * bytesPerRow + x * 4
                let r = Double(buf[p]), g = Double(buf[p + 1]), b = Double(buf[p + 2])
                lums.append((0.299 * r + 0.587 * g + 0.114 * b) / 255.0)
            }
        }
        guard lums.count > 20 else { return nil }
        lums.sort()
        let p5 = lums[Int(Double(lums.count - 1) * 0.05)]
        let p95 = lums[Int(Double(lums.count - 1) * 0.95)]
        return p95 - p5
    }

    private func waitFor(timeout: TimeInterval, _ cond: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if cond() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return cond()
    }
}
