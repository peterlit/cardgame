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
Capabilities** → set your Apple ID team and a unique **Bundle Identifier** (currently
`com.whimsicaldistractions.Causeway` — change it to your own). Free personal teams allow
7-day on-device signing; a paid Apple Developer account is only needed for TestFlight /
the App Store. The target is **iPhone-only, portrait**.

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
  Theme.swift              colours + palette
  LaunchScreen.storyboard  launch screen (native-resolution)
  PrivacyInfo.xcprivacy    privacy manifest
  Model/
    Cards.swift            Suit, Card, Mulberry32 RNG (ported from web)
    Game.swift             engine + ObservableObject state (rules, autoplay, smart-move, undo)
    WinStore.swift         persistence (UserDefaults) + range compression
  Views/
    ContentView.swift      board, HUD, toolbar, win overlay, deal entry
    CardView.swift         card face + empty slot
    SummerBackground.swift original sun-&-summer background (vector)
    WinsView.swift         deal-number entry, range chips + drill-down detail
    Extras.swift           FlowLayout + How-to-play rules sheet
  Assets.xcassets/         AppIcon (opaque 1024) + AccentColor
tools/make_icon.swift      app-icon generator
```

## Privacy & security

Causeway is fully offline and self-contained:

- **No networking** — no `URLSession`, URLs, or sockets; nothing leaves the device.
- **No web view or dynamic code execution.**
- **No permissions** — no camera, location, contacts, notifications, pasteboard, or
  device identifiers are requested.
- **No third-party dependencies** — Apple frameworks only (no supply-chain surface).
- **Storage** — the win history (deal numbers, moves, times) and the auto-play preference
  in `UserDefaults`, inside the app sandbox and encrypted at rest by iOS.
- A **Privacy Manifest** (`Causeway/PrivacyInfo.xcprivacy`) declares no tracking, no
  data collection, and the required-reason for `UserDefaults` (CA92.1).

## Status / known follow-ups

- Builds and runs on device (iPhone 13 Pro, iOS 26). Broader device/orientation testing
  is still pending — see the repo-root `BACKLOG.md`.
- App icon: an opaque 1024px icon (two fanned cards, A♥/K♠ on teal) lives in
  `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Regenerate it with
  `swift tools/make_icon.swift Causeway/Causeway/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- Court cards (J/Q/K) use SF Symbols (crown / person); could be replaced with custom
  artwork to match the web build's fleur-de-lis/crown figures.
- Card-move animations use `matchedGeometryEffect`; fine-tune timing/feel after a device test.
