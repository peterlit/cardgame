# Backlog

Tracks outstanding work, seeded from the skeptical full-app review
(`REVIEW-1-20260704`). IDs (C1/H1/M1/…) reference that report. Kept up to date as items
are done or added.

## Done (review-1 fix pass, 2026-07-04)
- **C1** — stale `selection` crash: bounds-checked `selectedCards()`; clear selection in
  auto-play/auto-finish (iOS).
- **H1** — "safe" auto-play made genuinely sound for two-way tableau (require opposite-colour
  rank-1 **and** rank+1 home); both platforms.
- **H2** — auto-finish now plays each suit's closing card (XOR → OR); both platforms.
- **H3 / L3** — undo-from-win restarts the timer; auto-finish starts the clock only if it
  moved something (iOS).
- **H4 / M1** — `WinStore.load()` no longer traps on duplicate Int keys and no longer
  silently wipes unreadable history (backs it up); both concerns fixed (iOS).
- **M4** — `Game` now forwards `winStore.objectWillChange` so Won/Wins UI can't go stale.
- **M5** — web double-tap no longer performs the single-tap move + a second move (guard).
- **M9** — app icon flattened to opaque RGB (no alpha); `ITSAppUsesNonExemptEncryption = NO`
  set; target set to **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`).
- **M10 / L1 / L9 / L10 / I2** — doc fixes: bundle ID, storage claim, layout section,
  build-status, "unlimited undo", web-storage caveat, double-tap "best spot".
- **L8 (part)** — Wins "Play" disabled for out-of-range input.
- **I8** — removed dead `SlotView.glyph`.

### review-2 validation follow-ups (2026-07-04)
- **R1** — `isSeqHead()` now bounds-guards `col`/`idx` (a tap racing an auto-play removal in
  the same column could still trap); completes C1. **Both platforms** (the web guard was added
  in review-loop round 1 — F2).
- **O1** — removed the dead `INFOPLIST_KEY_UISupportedInterfaceOrientations~ipad` key
  (inert under iPhone-only target).
- **M2** — in-progress game now persists on both platforms. iOS saves the board to
  UserDefaults (`causeway.game`) after every move and on `scenePhase` background, restores
  on launch, clears on win; web mirrors it via `localStorage` (save on move + `pagehide`/
  `visibilitychange`, restore on load, clear on win). Undo history is intentionally *not*
  persisted (board only; cheap). Sanity-checks all 52 cards before restoring.

### review-loop round 1 (2026-07-05)
- **F1** — win overlay "Close" no longer desyncs `won` from a solved board on iOS. Close
  routes through `Game.dismissWin()`, and `persist()` now refuses a completed board
  (`boardComplete`), so backgrounding after Close can't resurrect an empty, un-won table.
  (Web was already safe: `saveGame()` guards `isWon()` and Close only hides the overlay.)
- **F2** — web `isSeqHead()` now bounds-guards `col`/`idx` (parity with iOS R1).
- **F3** — restore sanity check strengthened on **both platforms**: verifies the 52 canonical
  cards each appear exactly once (board + foundation-implied), foundations in range and
  non-crossing (up<down), and refuses a fully-completed board. Was count-only.
- **F4** — `restore()`/`restoreGame()` now call `runAutoplay()` after a successful restore so
  a board saved mid-autoplay-chain finishes its safe sends (no-op unless autoplay on & started).
- **F5** — privacy policy now names the in-progress board snapshot (on-device only, wiped on
  delete).

### review-loop round 2 (2026-07-05)
- **F6** — added a dependency-free Node test harness (`tests/`, `npm test` /
  `node --test "tests/**/*.test.mjs"`) locking the shared engine: deal/RNG determinism
  (golden orders per seed), `isSafeAutoplay` two-way-tableau soundness cases, and the
  restore validator (accepts partial games; rejects duplicates / out-of-range suit+rank /
  crossed foundations / completed boards / mis-shaped saves). `tests/engine.mjs` is a
  hand-copy of `index.html`'s pure logic (the file:// app can't import a module); a
  **drift guard** test reads `index.html` and fails if the canonical bodies diverge.
  XCTest deferred — see below. Notes in `tests/README.md`.
- **F3** — web restore `mark()` now range-checks `suit` in 0..3 (was rank-only); a tampered
  `suit:9` save is now rejected, matching iOS (whose Codable enum already throws).
- **F5** — privacy policy "Last updated" bumped to 2026-07-05.

### tap/drag interaction change (2026-08-11)
- **Interaction** — single tap now smart-moves a card/run to its best spot (was double-tap);
  drag places a card/run exactly. Removed the old tap-to-select model. **Web** done + tested
  (pointer-event drag with a 6px tap/drag threshold; `elementFromPoint` drop hit-test). **iOS**
  ported with native SwiftUI `.draggable`/`.dropDestination` (`Spot` is the Codable+Transferable
  payload; drop routes through `Game.drop(_:to:)` reusing the tap-era move validators; only
  valid run heads are draggable). Type-checks clean — **on-device tap/drag verification pending**
  (can't run the simulator/device here; the tap-vs-drag coexistence and drop hit-testing are the
  things a type-check can't confirm).
- **M6 — Single-tap latency (iOS)** — **resolved** by the change above: the `.onTapGesture(count: 2)`
  double-tap is gone, so a single tap fires immediately with no disambiguation delay.

## Open — high value
- **F6 (iOS XCTest target).** The Node harness covers the *shared* engine logic by
  construction (iOS runs the same deal/shuffle/safe-autoplay algorithm), but there is no
  native XCTest target yet: adding one to the hand-authored `project.pbxproj` without Xcode
  is error-prone and could break the build. Add an XCTest target in Xcode that asserts the
  Swift engine reproduces the same golden deal orders (`tests/engine.test.mjs` GOLDEN) and
  the same `isSafeAutoplay` cases, so both platforms are pinned to one contract. Ties to M8.
- **M3 — Tableau overflow / no scrolling (iOS).** Fixed 0.40 overlap in a non-scrolling
  VStack overflows on small screens / deep columns; cards become untappable. Add a
  ScrollView or compress overlap adaptively.
- **M7 — Accessibility (iOS).** No VoiceOver labels/actions; Dynamic Type ignored
  (all fixed `.system(size:)`, tap gestures not buttons).

## Open — medium
- **M8 — Verify buildability from the committed project.** App builds/runs for the owner,
  but `project.pbxproj` was hand-authored (no `productReference`); confirm a clean clone
  opens & archives in Xcode 16.
- **L2 — Web hotkeys fire while typing / under the win overlay** ("n" discards the game;
  Cmd+Z reverts under the overlay). Guard on focus/overlay state.
- **L5 — `record()` chimera bests.** `min(moves)`/`min(secs)` taken independently can store
  a best that never happened in one playthrough; `date` rewritten on no improvement. Store
  the best *playthrough*, not per-field minima. *(both platforms)*
- **L7 — Foundation-flight animations render under other piles (iOS)** — `zIndex` scoped per
  column ZStack; matched-geometry flights pass beneath siblings.
- **L8 (rest)** — deal alert / win-overlay button row can overflow at narrow widths; use
  `FlowLayout`; give invalid input feedback instead of a silent no-op.

## Open — low / polish
- **L4 — Win-time semantics differ** (iOS foreground `Timer` ticks vs web wall clock);
  align, and reconcile with `ios/README.md`.
- **L6 — No `deinit` timer invalidate; iPad multi-window hazard** (moot now that target is
  iPhone-only, but keep if iPad support returns).
- **O2 — WinStore hardening is recovery, not prevention.** The `.unreadable` backup preserves
  bytes but nothing reads it back, and `WinRecord` has no schema-version field — a future
  non-optional field still routes every user's history to the backup key. Add a version field
  and a load-time backup-restore attempt **before** any `WinRecord` schema change ships.
- **I3 — Pile direction inferred from top two cards** including dealt coincidences — document
  precisely or make explicit.
- **I6 — FIX LANDED, on-device trace pending (targets an on-device OOM).** `elapsed` was
  `@Published` on `Game`, so the 1 Hz timer re-rendered the entire `ContentView` — including
  `SummerBackground`'s `.blur()` layers and 52 cards' `matchedGeometryEffect` — every second
  even while idle, the suspected cause of memory growing until the OS killed the app (~14 min).
  Isolated the clock into `GameClock` (only a small `ClockStat` label observes it) and marked
  `SummerBackground` `Equatable` + `.equatable()` so its blur scene isn't re-rasterized on
  unrelated state changes. Also gives `GameClock` a `deinit` timer-invalidate (partially
  addresses L6). **Verified: code-level SwiftUI/Combine reasoning + full iOS type-check
  (`xcrun swiftc -typecheck`). NOT yet verified: an on-device Instruments/Allocations trace
  showing RSS actually plateaus.** See the verification task below before marking I6 DONE.
- **I6-verify — Confirm the OOM fix on device.** Profile RSS with Instruments (Allocations) over
  a 15+ min idle session on a physical device to confirm memory plateaus and the OOM is gone.
  Keep the clock-isolation (`GameClock`) + `SummerBackground.equatable` changes regardless; this
  task only validates the effect. If RSS still climbs, the leak has another source — re-open I6.
- **DRAG-verify — Confirm the iOS tap/drag hybrid on device/simulator.** Type-check can't exercise
  gestures. Confirm: (1) a single tap still smart-moves and fires with no delay; (2) `.draggable`
  and `.onTapGesture` coexist (a quick tap isn't swallowed by the drag, a press-drag isn't read as
  a tap); (3) dragging a run head lifts the whole run and drops legally onto a column/free
  cell/foundation, snapping back on an illegal drop; (4) buried (non-run-head) cards don't lift.
  If tap/drag coexistence misbehaves, fall back to a manual `DragGesture(minimumDistance:)` with a
  tap threshold (as the web build does) + a PreferenceKey drop-zone frame map.
- **L1 (rest) — Undo cap is 500 snapshots** (auto-play snapshots per card); revisit or
  document.
- **I2 — No solvability guarantee / no stuck detection.** Consider a solver-backed
  "winnable deals" mode and a "no more moves" indicator; soften "pure skill" if not.

### review-loop residuals (converged round 2; open minors)
- **F6b — Node test harness can silently diverge from the app.** `tests/engine.mjs` is a
  hand-copy of `index.html`'s engine, and the "drift guard" checks hardcoded strings against
  `index.html` only — it never verifies `engine.mjs` still matches (an unsound `isSafeAutoplay`
  change to `engine.mjs` passed all 18 tests). Derive the guard's strings via `fn.toString()`
  (or diff `engine.mjs` vs `index.html` programmatically), and add an `isSafeAutoplay` test
  where the two opposite-colour suits disagree so sound-vs-unsound is observable.
- **F7 — Restore validator accepts non-integer suit/rank.** `mark()` range-checks but not
  integrality; a forged `suit:1.5`/`rank:5.5` card yields a non-colliding fractional id and is
  accepted. Add `Number.isInteger` checks (both platforms). Single-player self-corruption only.

## Release checklist (App Store)
- [ ] Enroll in the Apple Developer Program; create the App Store Connect record.
- [ ] Confirm the app **name** is available; set final display name.
- [ ] Host **Support URL** and **Privacy Policy URL** (`store/privacy-policy.md`).
- [ ] Capture **portrait iPhone screenshots**.
- [ ] Set **Version 1.0 / Build 1**; archive; upload; submit.
- [ ] **Remove the committed `DEVELOPMENT_TEAM` (personal Team ID)** before making the repo
      public (`ios/Causeway/Causeway.xcodeproj/project.pbxproj`).
