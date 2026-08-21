# Causeway — iOS (native SwiftUI)

A native SwiftUI port of the Causeway browser prototype (`../index.html`). The game
rules, seeded deals, safe auto-play, tap-to-smart-move / drag-to-place controls, Daily
Challenges, win tracking, and the MobilityWare-style look are all reimplemented in Swift
— same deal numbers as the web version (the `Mulberry32` RNG is ported verbatim).

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
the App Store. The target is **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`) and supports
**portrait and both landscape orientations** — landscape uses a different board layout
(controls in a left rail, foundations and free cells beside the tableau).

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
  CausewayApp.swift        @main entry (forces light colour scheme)
  Theme.swift              colours + palette + card aspect ratio
  LaunchScreen.storyboard  launch screen (native-resolution)
  PrivacyInfo.xcprivacy    privacy manifest
  daily-pool.json          certified daily seeds — byte-identical copy of ../../data/
  daily-solutions.json     baked "Show me how to win" lines — likewise
  Model/
    Cards.swift            Suit, Card, Mulberry32 RNG (ported from web)
    Game.swift             engine + ObservableObject state (rules, autoplay, auto-finish,
                           undo, persistence, daily scoring, demo playback)
    Daily.swift            daily logic ported from tests/daily.mjs: calendar, objective
                           checkers, date→challenge generator, streaks, bundle loader
    DailyStore.swift       per-day tier records (UserDefaults, versioned)
    WinStore.swift         solved deals (UserDefaults) + contiguous-range compression
    GameClock.swift        isolated elapsed-time timer (kept off Game to avoid
                           re-rendering the board every second)
    StatsBackup.swift      portable JSON export/import of daily + win records
    MemoryMonitor.swift    DebugFlags + phys_footprint sampler (debug HUD only)
  Views/
    ContentView.swift      board, toolbar/landscape rail, drag system, demo bar,
                           win overlay, sheet hosting, live objectives HUD
    CardView.swift         card face + empty slot
    DailyView.swift        Challenges screen: streaks, day card, calendar, backup
    WinsView.swift         deal-number entry, range chips + drill-down detail
    SummerBackground.swift original sun-&-summer background (vector, Equatable)
    Extras.swift           FlowLayout + How-to-play / About sheet
    MemoryHUD.swift        debug memory overlay (off in release)
  Assets.xcassets/         AppIcon (opaque 1024) + AccentColor
tools/make_icon.swift      app-icon generator (standalone macOS script, not in the target)
```

There is a **UI Testing Bundle target** (`CausewayUITests`) covering the app end-to-end in the
simulator — run it with `xcodebuild -scheme Causeway -destination 'platform=iOS Simulator,name=<sim>' test`,
or ⌘U in Xcode. There is still **no unit-test (XCTest) target** for the model layer; that Swift
logic is instead pinned from the Node suite by
`../tests/ios-parity.test.mjs`, which asserts the parity-critical Swift bodies (deal RNG,
calendar, daily generator, objective checkers, streaks, the once-only win gate, the demo
token applier) still match the canonical logic. See `../tests/README.md`.

## Privacy & security

Causeway is fully offline and self-contained:

- **No networking** — no `URLSession`, no sockets, no requests of any kind; nothing is
  sent off the device. (The app does handle local `file://` URLs, but only the
  security-scoped ones the system document picker hands back for stats backup — see
  below.)
- **No web view or dynamic code execution.**
- **No permissions** — no camera, location, contacts, notifications, pasteboard, or
  device identifiers are requested. No entitlements file exists.
- **No third-party dependencies** — Apple frameworks only (no supply-chain surface).
- **Storage** — everything lives in `UserDefaults` inside the app sandbox, encrypted at
  rest by iOS. Five keys:

  | Key | Holds |
  |---|---|
  | `causeway.wins` | solved deals — deal number, best moves, best time, date |
  | `causeway.daily` | per-day challenge records (tiers earned, best moves/time) |
  | `causeway.game` | the in-progress board so backgrounding doesn't lose it |
  | `causeway.autoplay` | auto-play on/off |
  | `causeway.autofinishmode` | auto-finish Ask/On/Off |

  (Plus `causeway.wins.unreadable` / `causeway.daily.unreadable`, written only if a store
  ever fails to decode, so corrupt bytes are quarantined rather than overwritten.)
- **Stats backup is user-initiated and local.** The Daily screen can export your records
  to a JSON file and import one back, through the system document picker — the app never
  reads or writes files you didn't pick, and nothing is uploaded. Import *merges* (it can
  only add or improve a record, never delete one) and rejects files that aren't Causeway
  backups.
- A **Privacy Manifest** (`Causeway/PrivacyInfo.xcprivacy`) declares no tracking, no
  data collection, and the required-reason for `UserDefaults` (CA92.1).

## Status / known follow-ups

- Builds and runs on device (iPhone 13 Pro, iOS 26); portrait and landscape both verified
  on device. Testing on real iOS 17/18 hardware is still outstanding before submission —
  see `../docs/shipping-readiness.md` and the repo-root `BACKLOG.md`.
- **Accessibility is not done** — no VoiceOver labels or actions, and Dynamic Type is
  ignored (all type is fixed `.system(size:)`). Tracked as **M7** in `BACKLOG.md`.
- App icon: an opaque 1024px icon (two fanned cards, A♥/K♠ on teal) lives in
  `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`. Regenerate it with
  `swift tools/make_icon.swift Causeway/Causeway/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`.
- Court cards (J/Q/K) use SF Symbols (crown / person); could be replaced with custom
  artwork to match the web build's fleur-de-lis/crown figures.
- Card-move animations use `matchedGeometryEffect`; fine-tune timing/feel after a device test.
