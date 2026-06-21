# Causeway — iOS (native SwiftUI)

A native SwiftUI port of the Causeway browser prototype (`../index.html`). The game
rules, seeded deals, safe auto-play, smart double-tap, win tracking, and the
MobilityWare-style look are all reimplemented in Swift — same deal numbers as the web
version (the `Mulberry32` RNG is ported verbatim).

## Requirements

- **Xcode 16+** (free, Mac App Store). Only the Command Line Tools are installed on this
  machine, which is enough to *edit* but **not to build/run** — install full Xcode first.
- iOS 17+ deployment target. Runs on the iOS Simulator or a device.

## Build & run

1. Open `Causeway/Causeway.xcodeproj` in Xcode.
2. Pick an iPhone simulator (e.g. iPhone 15) in the scheme selector.
3. Press **Run** (⌘R).

To run on your own iPhone: select the project → target **Causeway** → **Signing &
Capabilities** → set your Apple ID team and a unique **Bundle Identifier**
(currently `com.example.Causeway`). Free personal teams allow 7-day on-device signing;
a paid Apple Developer account is only needed for TestFlight / the App Store.

## If the project won't open

The `.xcodeproj` uses Xcode 16's synchronized-folder format. If your Xcode version
chokes on it, create the project fresh instead:

1. Xcode → **File ▸ New ▸ Project… ▸ iOS App**. Name it `Causeway`, interface **SwiftUI**,
   language **Swift**. Save it somewhere temporary.
2. Delete the auto-generated `ContentView.swift` and `*App.swift`.
3. Drag the contents of `Causeway/Causeway/` (the `Model/`, `Views/` folders, plus
   `Theme.swift`, `CausewayApp.swift`, `Assets.xcassets`) into the project navigator,
   choosing **Copy items if needed** and **Create groups**.
4. Set the deployment target to iOS 17 and Run.

## Project layout

```
Causeway/Causeway/
  CausewayApp.swift        @main entry
  Theme.swift              colours + background gradient
  Model/
    Cards.swift            Suit, Card, Mulberry32 RNG (ported from web)
    Game.swift             engine + ObservableObject state (rules, autoplay, smart-move, undo)
    WinStore.swift         persistence (UserDefaults) + range compression
  Views/
    ContentView.swift      board, HUD, toolbar, win overlay, deal entry
    CardView.swift         card face + empty slot
    WinsView.swift         range chips + drill-down detail
  Assets.xcassets/         AppIcon (placeholder) + AccentColor
```

## Status / known follow-ups

- Built and verified only by syntax parse here (no Xcode on this machine). On first
  build, report any compiler errors and they'll be fixed.
- App icon is a placeholder — add artwork to `Assets.xcassets/AppIcon.appiconset`.
- Court cards (J/Q/K) use SF Symbols (crown / person); could be replaced with custom
  artwork to match the web build's fleur-de-lis/crown figures.
- Card-move animations use `matchedGeometryEffect`; fine-tune timing/feel after a device test.
