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
  (pointer-event drag with a 6px tap/drag threshold; `elementFromPoint` drop hit-test). **iOS**:
  single tap confirmed great on device. The first port used native `.draggable`/`.dropDestination`
  but felt wrong on device — press-and-hold to lift + the system copy "+"/ghost drag chrome — so it
  was replaced with a **manual `DragGesture(minimumDistance: 0)`**: instant grab, the run follows
  the finger in place (`runOffset` + per-area z-ordering), tap-vs-drag split at an 8px slop, and a
  `DropZonesKey` PreferenceKey collects every drop target's frame in a "board" coordinate space so
  release hit-tests the zone under the finger. Drops still route through `Game.drop(_:to:)`
  (tap-era validators; only valid run heads drag). Type-checks + builds for the simulator + renders
  the board; **on-device drag feel/hit-test re-check pending (DRAG-verify)**.
- **M6 — Single-tap latency (iOS)** — **resolved** by the change above: the `.onTapGesture(count: 2)`
  double-tap is gone, so a single tap fires immediately with no disambiguation delay.

## Open — high value
- **DAILY — Daily Challenges feature (design approved; Phase 0 landed).** MobilityWare-style dated
  challenges: a "Deal of the Day" with 🥉 Bronze (win, required) + one 🥈 Silver + one 🥇 Gold
  optional objective, deterministic from the date, past days replayable, three catch-up streaks
  (Play/Silver/Gold), dedicated Challenges & Streaks screen. Full design in
  [docs/daily-challenges.md](docs/daily-challenges.md).
  - **Phase 0 — DONE:** the offline constrained solver + certified pool (`tools/solver/`, spec in
    [docs/solver.md](docs/solver.md), tests in `tests/solver.test.mjs`, output `data/daily-pool.json`).
    Certifies winnable/par/supports/constraintPar over seeds > 10,000; gating objectives are sound
    by construction (no false-positive certs). This also **retires I2**. Grow the pool by re-running
    `build-pool.mjs`. Follow-ups: a `rules.mjs`↔`index.html` drift guard (or replay-verify pass);
    optimal par (currently near-optimal); redefine the dropped `empty-column` objective.
  - **Phase 1 shared core — DONE:** the deterministic `date → challenge` generator, objective
    checkers, and streak computation, in `tests/daily.mjs` (canonical, Node-tested — 13 tests) for
    both platforms to build on. Day index = days since the 2026-08-12 epoch → `pool.seeds[dayIndex]`
    (append-only ⇒ frozen history); per-day RNG picks Silver/Gold from the seed's certified supports.
  - **Phase 1 app integration — TODO:** wire the shared core into each platform — the Challenges &
    Streaks screen, the per-attempt telemetry tracker (moves/cells/undos/foundation-order/auto
    flags), the DailyStore (persist per-day tiers; derive the 3 streaks), and challenge play + live
    objectives HUD + win-tier reporting. Web (inline the daily logic, drift-guarded; load the pool)
    then iOS (mirror in Swift; bundle the pool). Not started.
- **AF-test — Cover the auto-finish win-record / deferred-overlay timing (review-loop F3).**
  The deferred-win logic has zero automated coverage, yet it has already produced a blocker
  (Finish pill re-offering over a solved board → win discarded) and a major (kill-during-beat
  loses the win) — both timing bugs invisible to the current Node suite. Add a headless test:
  `recordWin` is idempotent under a double-call; a simulated undo-during-beat leaves the win
  recorded exactly once; and `canOfferFinish`/`maybeAutoFinish`/`runAutoFinish` all reject a
  board where `checkWin()`/`isWon()` is true. Ties to the missing iOS test target (F6).
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
- **I6 — REOPENED: fix helped but did not fully clear the OOM; measurement was contaminated.**
  `elapsed` was `@Published` on `Game`, so the 1 Hz timer re-rendered the entire `ContentView` —
  including `SummerBackground`'s `.blur()` layers and 52 cards' `matchedGeometryEffect` — every
  second even while idle, a suspected cause of memory growth. Isolated the clock into `GameClock`
  (only a small `ClockStat` label observes it) and marked `SummerBackground` `Equatable` +
  `.equatable()`. This **helped**: a fresh on-device OOM report (2026-08-11, iPhone 13 Pro / iOS
  26.6) shows the app now survives **~21.6 min** vs **~14.2 min** pre-fix — but it *still* got
  jetsam-killed. **However that crash is not a trustworthy read of production memory:** it was a
  Debug build under LLDB with View Debugging (`viewDebugging_insertDylibOnLaunch=1`), Malloc Stack
  Logging, and the Main-Thread / Thread-Performance checkers all enabled — instrumentation that
  inflates and continuously grows RSS over minutes largely independent of app code. Code review
  finds **no idle-time unbounded growth** in the app: `GameClock` is single-timer + `[weak self]` +
  `deinit`-invalidate; `runAutoplay` self-terminates and guards `!autoplaying`; undo `history` is
  bounded to 500 and only grows on moves. Keep the `GameClock`/`equatable` changes regardless.
  Remaining app-level suspect *if* a clean build still climbs: `matchedGeometryEffect` retention
  across per-move re-renders during active play. Do I6-verify before spending any more on a fix.
- **I6-verify — Re-measure the OOM WITHOUT debug instrumentation (this is the real test).** The
  on-device OOM numbers all came from Debug builds under Xcode with View Debugging + Malloc Stack
  Logging + checkers attached (three runs: ~14 → ~21.6 → ~32.2 min survival, increasing — more
  consistent with tooling/environment variance than a fixed code leak), which is invalid for
  judging production memory. A code audit finds **no unbounded-growth mechanism** (no audio/haptics,
  one Combine `.sink`, no per-render allocation, clock isolated, autoplay self-terminating, undo
  capped 500); only `matchedGeometryEffect` remains framework-level unverifiable.
  **Easiest clean read (built 2026-08-11): the in-app memory HUD** (`DebugFlags.memoryHUD`,
  `MemoryMonitor`/`MemoryHUD`) shows live `phys_footprint` (MEM), its high-water mark (PEAK — the
  tell: if it never plateaus, real leak) and jetsam headroom (FREE). **Build Release, launch
  untethered (not from Xcode), play/idle 25–30 min, watch MEM/PEAK:** flat/plateau → the OOM was a
  debug-tooling artifact, close I6; steadily climbing → real leak, and the HUD gives the rate.
  Alternatives: capture `JetsamEvent-…Causeway` (Settings → Privacy & Security → Analytics Data)
  for the kill size, or Instruments → Allocations generations. Chase `matchedGeometryEffect` only
  if a clean run genuinely climbs. Remove the HUD (flag → false) before shipping — see checklist.
- **DRAG-verify — DONE (simulator-verified 2026-08-11).** The manual `DragGesture` build was
  driven on the iPhone 17 Pro simulator: tap→smart-move, single drag to a specific free cell
  (overriding the smart choice), illegal drop (heart→spade foundation) snapping back with no move
  counted, tap-park to a free cell, and a **2-card run drag** ([10♠,9♦]→J♥ across columns) all
  behaved correctly — instant grab, no system drag chrome, correct frame hit-testing. Note: a
  zero-dwell instant *flick* can occasionally fail to latch the drag; a normal finger drag (any
  slight initial dwell) is reliable. Physical-device feel re-check is optional (the earlier
  press-and-hold + "+"/ghost-chrome complaint is resolved by the instant-grab design).
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
- **F4 — iOS: suspected drop hitch (deferred, unverified).** On a successful drop
  `.offset(runOffset…)` snaps to zero in the same `withAnimation` as the `matchedGeometryEffect`
  relocation; the card *may* jump finger→old slot→glide instead of flying straight from the
  finger. Cosmetic and unconfirmed on device; a fix means reworking the verified-working drag
  rendering, so deferred until reproduced on hardware (`ios/.../Views/ContentView.swift`
  `cardGesture`/`runOffset`/`tableauCard`).

## Release checklist (App Store)
- [ ] Enroll in the Apple Developer Program; create the App Store Connect record.
- [ ] Confirm the app **name** is available; set final display name.
- [ ] Host **Support URL** and **Privacy Policy URL** (`store/privacy-policy.md`).
- [ ] Capture **portrait iPhone screenshots**.
- [ ] Set **Version 1.0 / Build 1**; archive; upload; submit.
- [ ] **Remove the committed `DEVELOPMENT_TEAM` (personal Team ID)** before making the repo
      public (`ios/Causeway/Causeway.xcodeproj/project.pbxproj`).
- [ ] **Set `DebugFlags.memoryHUD = false`** (`Model/MemoryMonitor.swift`) — the on-screen
      memory HUD is a diagnostic for I6-verify and must not ship. (Not `#if DEBUG`-gated on
      purpose, so it can be watched in a Release/untethered run.)
