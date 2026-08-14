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

### QA loop — round 1 findings (2026-08-14)
Simulator-driven UX/QA loop (`.qa-loop/REPORT.md`) converged round 1: no blockers/majors.
- **Fix (auto, minor)** — file-picker Cancel shows the default BACKUP helper text instead of
  "Import cancelled." / "Export cancelled or failed." (SwiftUI `.fileImporter`/`.fileExporter`
  `onCompletion` isn't called on interactive cancel; Import also nils the note first). Data-safe.
- **Fix (auto, minor)** — count-of-1 grammar: "1 days" / "1 deals" (`DailyView.importStats`) and
  "1 deals solved · 1 ranges" (`WinsView`) should be "1 day" / "1 deal" / "1 range".
- **Proposal (decide)** — demo "Done" leaves an inert fully-solved board (Won still 0, no
  guidance); consider Done → Replay the seed.
- **Proposal (decide)** — solve clock keeps ticking while modal sheets (Daily/Wins/How-to-play)
  are open, inflating recorded time; consider pausing on sheet-present.
- **Coverage gaps** — WF-4 scored win overlay and WF-12 landscape were code-reviewed only (env
  can't rotate the simulator / deal not hand-solvable this session); verify on device.
- **NFR** — idle CPU ~0–2%, no network; RSS 181→~357 MB then plateaued — inconclusive for a leak,
  worth a New game/Undo ×10 loop.

### stats backup + flawless total (2026-08-14)
- **Local Export/Import (iOS)** — a "Backup" section on the Daily screen exports stats (daily records
  + solved deals) to a dated `.json` and imports/merges them back. `StatsBackup` = versioned
  "causeway-stats" JSON; `DailyStore.merge`/`WinStore.merge` are non-destructive (OR-accumulate tiers,
  keep best) so import never erases. No iCloud entitlements. Format is platform-agnostic. iOS-only for
  now (`StatsBackup.swift`, `DailyView.swift` backup section).
- **Flawless (and all tiers) now show a lifetime `total`** alongside the consecutive-day streak, so
  two non-consecutive flawless days read as "2 total" not just a streak of "1".
- **Follow-up (offered, not done): iCloud Key-Value sync** — `NSUbiquitousKeyValueStore` for automatic
  hands-off backup/restore across the user's devices; low privacy surface (user's own private iCloud).
  Needs the iCloud KVS entitlement + merge-on-change (reuses `mergeTiers`) + signed-out fallback.
- **Follow-up (parity): web Export/Import** — mirror the iOS backup on web (localStorage → download /
  upload the same `causeway-stats` JSON) so files move between prototype and app.

### landscape redesign v2 — left rail + bigger cards (2026-08-14)
- **Landscape layout** — three columns: vertical button rail (left) · foundations with free cells
  beneath · tableau (fills the rest). Toolbar off the top + free-cells-under-foundations (15→12
  across) make tableau cards width-bound ~58pt (was height-bound ~46pt). Reserve floor 11→8 fills
  the bottom gap; columns past 8 shrink to avoid clipping. Portrait untouched. iOS-only
  (`ContentView.swift`). Safety tag `pre-landscape-v2`. Review loop (2 rounds) caught + fixed a
  ship-blocker: the button rail had no height bound, clipping controls off-screen on short phones /
  during the Daily HUD → now a HUD-aware `landscapeBoardH`-bounded ScrollView.
- **Known-minor (landscape, deferred)** — very long tableau columns (17+ cards) clip past the 30pt
  min card-size floor (no-scroll tableau by design); whole-board resize when the tallest column
  crosses 8 (user-approved play-driven resizing). Both pre-existing / accepted.

### daily HUD on-track indicator + calendar star (2026-08-14)
- **Daily HUD "on-track"** — the live objectives HUD now shows a green ✓ for a Silver/Gold objective
  as soon as it is *secured* (guaranteed to be earned on any completion), not only at the win overlay.
  New `objSecured(obj, up, down, t)` on both platforms (web `index.html`, iOS `Daily.swift`): achievement
  objectives flip to ✓ when their locked-in board condition holds and they aren't already violated
  (kings-first / suits-top-down / down-openers-20 → all four Kings down; aces-first → all Aces up;
  jacks-down-first → all Jacks down; suit-sprint → one whole suit home). Budget objectives
  (moves/no-undo/cells) stay neutral '·' pre-win since they can still be blown. Parity drift-guards
  pin the Swift mirror.
- **Calendar Flawless star** — the 🌟 no longer overlaps the date number: moved from an absolute
  top-right corner overlay into the day-cell marker slot (replaces the tier dots — flawless implies all
  three). Both platforms.

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
  - **Phase 1 web integration — DONE:** the shared core is inlined into `index.html`
    (drift-guarded in `tests/daily.test.mjs`), the pool is fetched at load, and the Challenges &
    Streaks overlay (streaks + today's card + month calendar) is wired to a "Daily" toolbar button.
    Per-attempt telemetry (moves/cells/undos/foundation-order via a diff-based `recordHomed`, which
    leaves the drift-guarded send functions untouched) + a live objectives HUD during play;
    `recordChallengeResult` scores tiers on win into a versioned `causeway.daily` DailyStore
    (OR-accumulated across retries), streaks derived, tiers shown in the win overlay; challenge
    context persists across reload. Verified end-to-end in the browser. `build-pool.mjs` now writes
    the pool one-seed-per-line (readable).
  - **Flawless recognition — DONE (web):** a 4th tier for earning Bronze+Silver+Gold in a SINGLE
    attempt (vs. banking them across free retries). `evaluateChallenge` sets `flawless`, `mergeTiers`
    keeps it sticky, `streaks` derives a 4th run (all drift-guarded). Web shows a 4-up 🌟 streak card,
    a today-card header badge, a calendar ⭐ on flawless days, and a win-overlay callout. iOS: TODO
    (mirror as part of the Phase 1 iOS integration below).
  - **Phase 1 iOS integration — DONE:** the shared core is ported to Swift (`Model/Daily.swift` —
    generator, objective checkers, streaks, Flawless, bundle pool loader) with `Model/DailyStore.swift`
    (versioned UserDefaults). `Model/Game.swift` carries the per-attempt telemetry (diff-based
    `recordHomed`, snapshot/undo rollback of foundationOrder+cellUses, cellUses on genuine parks,
    challengeDay lifecycle preserved across relaunch, `recordChallengeResult` on win). `Views/DailyView.swift`
    is the Challenges & Streaks screen (4 streaks incl. Flawless, tiered day card, month calendar with
    ⭐ + legend) plus a live objectives HUD; ContentView adds the Daily pill, sheet, HUD, and the
    win-overlay tiers/Flawless callout. Pool JSON auto-bundled via the synchronized group. Builds +
    runs on the iPhone 17 Pro simulator; day 0 → Deal #10,001 with the same objectives as web.
    No XCTest coverage yet (the daily logic is validated by the Node suite it mirrors; see below).
  - **"Show me how to win" — DONE (web + iOS).** The solver reconstructs the winning line
    (`solve({withPath})` + `moveToken`) and `tools/solver/build-solutions.mjs` bakes each pool seed's
    shortest unconstrained line (re-simulated to a verified win) into append-only
    `data/daily-solutions.json`. Both apps show a "💡 Show me how to win" button on a playable Daily
    day card that resets the deal and animates the line (assisted, input locked, never scored). iOS:
    `DailyData.solutions` loads the bundled JSON; `Game.showSolution/stopDemo/applyDemoToken` drive
    the playback (asyncAfter step loop, demoGen token), a `demoBar` in ContentView shows status +
    Stop/Done. Verified on the iPhone 17 Pro simulator (deal 10002 clears in 78 moves, Won stays 0).
    Playback is pausable and single-steppable: a Pause/Resume toggle + a "Next" button (paused only)
    that advances one move at a time, with live progress in the bar. Both platforms.
    Now offers a line per TIER: `build-solutions.mjs` bakes bronze + a Gold line (solved under the
    day's Gold objective) + a Silver line (only for certified Silvers; universal ones fall back to
    bronze), each re-verified against the objective checker (data schema v2 `{bronze,silver?,gold?}`;
    366 gold + 190 silver, 0 rejected). Both apps show a 🥉/🥈/🥇 button row and name the objective
    in the demo bar.
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
