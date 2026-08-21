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

### Daily objectives + sandbox + calendar fix (2026-08-21)
- **Six new objective types — DONE.** `split-even` (A1: every suit splits A-7 up / 8-K down),
  `down-heavy` (A2: >= 8 of every suit from the King end), `no-down-foundation` (B3: win using only
  up foundations), `no-up-foundation` (B4: win building every suit K->A), `no-supermoves` (F1: one
  card at a time), `one-big-move` (F2: relocate a run of 5+ at least once). All three copies of the
  logic + the solver + the drift guards. A1/A2/B3/B4 are pure `allowFoundation` gates (sound by
  construction); F1 added `constraint.maxRun` to `legalMoves`; F2 is existential, so the search node
  key grew a second latch (`big`) alongside `wantDownOpen`. Appending to `GOLD`/`SILVER_CERTIFIED`
  changes 0 of 366 frozen days — re-verified. See docs/daily-objectives-proposal.md section 8.
- **`maxRunMoved` telemetry — DONE.** New field serving F1 and F2: largest run ever relocated in one
  move. Threaded through snapshot/undo rollback, both multi-card move paths, the persisted saved
  game (decode-tolerant, defaults 0), and the HUD's `Attempt` reconstruction, on both platforms.
  `one-big-move` is the first *securable* objective — positive and irreversible — so the live HUD
  can show a green check mid-game rather than only ever going neutral -> violated.
- **Pre-epoch playtest sandbox — DONE.** Negative day indices now resolve to a `preSeeds` array in
  `data/daily-pool.json` (`preSeeds[i]` = day `-(i+1)`), so dates before the 2026-08-12 epoch are
  playable. Days >= 0 are frozen; the sandbox is deliberately mutable. Seven dates (2026-08-05..11)
  backfilled with certified deals from seeds > 10,000,000, rebuilt to showcase the six new
  objectives: Aug 5 = A1, Aug 6 = A2 + B3, Aug 7 = F1 + B4, Aug 8 = F2, Aug 9-11 keep familiar
  objectives for contrast. Objective assignment is steered by pool *length* (a seed certified for
  exactly one Gold pins that Gold, since the per-day RNG draw is fixed). Verified all 366 existing
  days are byte-identical before/after. Both platforms + canonical.
- **`replay()` dropped `maxRunMoved` — FIXED.** Both solution replayers (`tests/solutions.test.mjs`
  and `tools/solver/build-solutions.mjs`) reconstructed telemetry without it, which would have made
  any F1 or F2 line impossible to validate. Caught by a guard failure, fixed rather than silenced.
- **iOS seed clamp — FIXED.** `Game.deal(seed:)` clamped to `maxSeed = 1_000_000`, so any pool seed
  above that dealt a DIFFERENT board on iOS than on web. Split into `maxSeed` (what the player may
  type into Deal #) and `maxValidSeed` (UInt32 max, what the RNG accepts, matching web's `>>> 0`).
- **iOS calendar hid days 1-6 of EVERY month — FIXED (pre-existing).** The month grid is one
  LazyVGrid with three sibling ForEach blocks sharing an identity space; the weekday header used
  `id: \.offset` (0...6) and the day cells `id: \.self` (1...31), so ids 1-6 collided and SwiftUI
  collapsed them. Itself a regression from the earlier fix for duplicate "T"/"S" header letters.
  Now uses prefixed string ids (`hdr-`/`pad-`/`day-`) so the three spaces are provably disjoint.

### QA loop — round 1 findings (2026-08-14)
Simulator-driven UX/QA loop (`.qa-loop/REPORT.md`) converged round 1: no blockers/majors.
All four findings (2 auto + 2 accepted proposals) **fixed** in `5b237b4`:
- **DONE (auto)** — file-picker Cancel now shows "Import/Export cancelled." via the iOS 17
  `onCancellation:` overloads (onCompletion isn't called on interactive cancel).
- **DONE (auto)** — count-of-1 grammar: "1 day" / "1 deal" / "1 range" (`importStats`, `WinsView`).
- **DONE (proposal)** — demo "Done" now re-deals the seed (`restartDeal`) → playable board. (Review
  note, accepted as-is: a daily demo's Replay board is casual/unscored since you saw the solution.)
- **REVERTED (proposal)** — clock-pause-in-sheets (`2796867`): a follow-up skeptical review flagged it
  as a metric-integrity regression (any sheet becomes a pause button → gameable daily best-times).
  User chose continuous wall-clock timing. Original "reading a sheet inflates time" complaint judged
  minor/self-inflicted and left as wall-clock.
- **Coverage gaps (open)** — WF-4 scored win overlay and WF-12 landscape were code-reviewed only
  (env can't rotate the simulator / deal not hand-solvable this session); verify on device.
- **NFR (open)** — idle CPU ~0–2%, no network; RSS 181→~357 MB then plateaued — inconclusive for a
  leak, worth a New game/Undo ×10 loop.
- **Parity follow-up (DONE 2026-08-15, review-loop round 2)** — the demo-exit integrity rule is now
  mirrored to web: `index.html`'s demo Stop/Done routes through `restartDeal()`, `finishDemo` re-deals
  unless the line completed the board, and `applyDemoToken` validates tokens (aborting to a re-deal on
  bad baked data) — matching iOS. Pinned by `tests/ios-parity.test.mjs` ("web demo exit paths
  re-deal"). Clock-pause needs no mirror (it was reverted; both apps use continuous timing).

### QA loop — round 2 MAJOR fixes (2026-08-15)
Both round-2 majors fixed (user-directed; simulator re-verification pending next qa-loop round):
- **DONE — demo progress can no longer bank a real win.** Input was already locked while
  `demoing` (drop/smartMove guards; pause keeps `demoing` true); the hole was the demo bar's
  mid-demo **Stop**, which called `stopDemo()` and left the solution's moves on a playable board
  with no undo history. Now both Stop and Done route through `restartDeal()` — leaving a demo
  always lands on a fresh board of the same seed, so a demo-touched board can never be played or
  scored. This sidesteps the flagged trap: no win-tainting or best-time reinterpretation needed,
  and a player who stops the demo early can still solve the same deal legitimately from scratch.
  Defense in depth: `undo()` now no-ops while `demoing` (it called `stopDemo()` and would unlock
  input), and cards can't even lift during a demo (`canDrag` gates on `!game.demoing`).
- **DONE — portrait tall column can no longer clip off-screen (also closes M3).** Instead of
  landscape's shrink-all-cards clamp (which the watch list flagged for per-move size thrash), each
  tableau column now compresses **its own fan** just enough to fit the measured board height
  (portrait: a greedy `GeometryReader` supplies the true remaining height; landscape gets
  `landscapeBoardH` as a backstop for the 30pt cardW floor, retiring the "17+ cards clip past the
  floor" known-minor). Card size and other columns' spacing never change; 8pt overlap floor.

### QA loop — round 2 findings (2026-08-15) — minors/proposals OPEN, majors fixed above
Second simulator-driven pass on `342e3c0` (`.qa-loop/REPORT.md`): 3 parallel testers, full pass,
47/47 test cases, plus an uncontended perf lane. Round-1's three implemented fixes all **verified
fixed on screen**. The loop aborted with `thrashing`, which is a **false positive** — 0 findings
reopened, 0 recurring regions; only the `net <= 0 for two rounds` signal fired, and any productive
discovery round is net-negative by construction. Rounds 1 and 2 were both discovery passes; the
implementer has never run inside the loop.

- **MAJOR (auto) — demo progress banks a real win.** Stop mid-demo leaves the app's solution moves
  on the board with no undo history; finishing from there records a genuine win in `causeway.wins`
  (one run banked a 29 s "best time" for a 92-move deal after the demo played 64 of them).
  `showSolution()` already clears `challengeDay` to protect the daily tiers — the Wins store is
  missing the same guard. Reproduced by two testers. *Trap (metric-integrity):* blanket-refusing
  post-demo wins punishes a player who stops at move 1 and genuinely solves it, and it re-interprets
  already-persisted best-times. Prefer tainting only while assisted moves remain on the board.
- **MAJOR (auto) — portrait tall column runs offscreen.** Fixed `portraitCardW`
  (`ContentView.swift:53`) + a non-scrolling tableau: bottom card clipped at 13 cards, fully
  invisible/untappable at 15; Undo is the only recovery. Landscape already shrinks `cardW` to the
  tallest column (`ContentView.swift:62-73`) and was re-tested as **not** affected. Reachable in
  ordinary play. *Watch:* the clamp resizes cards mid-game — check for per-move size thrash.
- **Minors (auto)** — FIXED in qa-loop round 1 (fix pass 2026-08-16): calendar weekday header
  drops Thu/Sat (positional `ForEach` id); daily HUD truncates objectives (`ViewThatFits` →
  stacked wrapped chips in portrait); landscape rail's disabled Undo blank capsule (dropped
  `.buttonStyle(.plain)` — it kept the near-white label when disabled); cold-launch Export/Import
  stall now acknowledged ("Opening Files…" note painted before the `UIDocumentPicker` warm-up,
  which itself can't be made fast). Still open: Deal # field neither selects-on-focus nor clears
  (12 taps vs the 3 budgeted); deal number rendered three ways (`10004–10006` / `Deal #10005` /
  `Deal #10,004`) two taps apart in Wins; "Auto-play: On" label overpromises (the *rule* is correct
  — `isSafeAutoplay()` needs both opposite-colour neighbours resolved because piles build both ways
  — but `RulesView` never mentions Auto-play, so an ignored Ace reads as broken; **do not** make
  Auto-play aggressive); backgrounding pauses the clock (23.7 s wall over a 20 s background advanced
  it 6 s) and `recordWin()` banks that as best time.
- **Proposals (human call)** — landscape cards measure 45pt, *identical* to portrait, with a 116pt
  (29%) empty band, so rotating gains nothing (structural: the 12-card-width split); a `#if DEBUG`
  day-index/seed override to make daily streak/tier rollover testable (TC-5.3 is permanently blocked
  without it) — must not survive into Release or players farm streaks. Also: `clock-runs-during-
  modal-sheets` is still carried as an open proposal but was **already decided** in `2796867`
  (continuous timing) — close it as wontfix, and decide it together with the background-pause bug,
  which is the same metric family pointing the other way.
- **Perf lane clean** — idle CPU 0.0–1.0%, RSS flat over 12 undo cycles and 15 New game + 15 Replay
  (retires the round-1 inconclusive leak note), cold launch ≤0.9 s, demo 0.259 s/move vs 0.24
  designed, auto-finish ~0.18 s/card, 0 network bytes.
- **Coverage gaps closed since round 1** — landscape rotation *is* drivable
  (`XCUIDevice.shared.orientation` from an XCUITest driver; resets to portrait each `xcodebuild
  test` run), so WF-12 ran interactively rather than by code review, and WF-4's win overlay was
  driven to a real win. Only TC-5.3 remains blocked.

### review-loop round 1 on the QA-round-2 major fixes (2026-08-15)
Adversarial review of `66d1682` (demo-exit re-deal + per-column fan compression); all in-scope
findings fixed:
- **DONE — demo unlock is now code-enforced, not data-enforced.** `finishDemo()` only shows the
  "try it yourself" banner when the board is genuinely complete (`boardComplete`); an imperfect
  baked line re-deals like a mid-demo Stop, so a demo-touched partial board can never become
  playable/scorable. `applyDemoToken` is now fully defensive (returns Bool; bounds/emptiness
  guards on every case — the old code could destroy a card on `C` with no free cell, silently
  desync on `G`/`X`, or trap on `removeLast()` of an empty column); a token that doesn't apply
  aborts the demo via `restartDeal()`. All 922 baked lines were verified clean, so this was
  unreachable with shipped data — the fix closes the invariant in code. Drift-guard snippets in
  `tests/ios-parity.test.mjs` re-pinned to the new (semantically identical) applier.
- **DONE — portrait fan compression got a legibility floor.** Compression never squeezes a buried
  card below its readable rank band (~0.42·cardW: 0.05·w top inset + ~0.36·w rank cap); when even
  that can't fit the tallest column, `tableauArea` shrinks the tableau's card size (the landscape
  strategy, 30pt clamp) instead of fanning into unreadable slivers. The 8pt overlap floor remains
  only as a last-resort backstop (degenerate 20+-card columns on short phones).
- **DONE** — end-of-demo banner copy now says "tap Done" (the demo bar's actual button), not
  "tap Replay".
- **DECLINED (→ open minor DV-1 below)** — pre-existing, outside the reviewed diff: Daily
  "Play"/"Show me how to win" silently discard an in-progress casual game.

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
  - **Security review (done — cleared, requirements baked in):** No cross-app exposure risk. KVS is
    isolated by app sandbox + team-scoped entitlement (`com.apple.developer.ubiquity-kvstore-identifier`,
    default `<TeamID>.<bundleID>`) + code-signing, so no third-party app can read our store, and our app's
    iCloud reach is scoped to its own ~1 MB container only (no path to Photos/Drive/other apps' data — so
    even a compromised build can't pivot into the user's broader iCloud). Data is non-sensitive game
    progress; encrypted in transit + at rest (E2EE only under Advanced Data Protection). Requirements when
    building: (1) keep the DEFAULT per-app container — don't broaden the entitlement; (2) **sanitize on
    read** from KVS exactly like `importStats` (clamp day/seed ranges, reject non-positive moves/secs) so a
    corrupt/oversized value can't crash or poison a best-time; (3) **merge, don't overwrite** on
    `didChangeExternallyNotification`; (4) store ONLY game progress — no ids/PII/secrets.
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
- **Known-minor (landscape, deferred)** — whole-board resize when the tallest column crosses 8
  (user-approved play-driven resizing). The other half — very long columns (17+ cards) clipping
  past the 30pt min card-size floor — is retired by the 2026-08-15 per-column fan compression.

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
- **UITEST-target — RESOLVED 2026-08-21.** The `CausewayUITests` UI Testing Bundle target now
  exists in `project.pbxproj` and runs. Xcode had never re-serialized the project when the target
  was added in the GUI, leaving both schemes pointing at a blueprint id that no target defined.
  Fixed by writing the target into the pbxproj directly (user-authorised exception to the
  "don't hand-edit the pbxproj" rule), reusing the id the schemes already referenced
  (`C761C3703031FA7B00429DAC`) so no scheme edits were needed: a
  `PBXFileSystemSynchronizedRootGroup` for `CausewayUITests/`, native target with
  `productType = com.apple.product-type.bundle.ui-testing`, Sources/Frameworks/Resources phases,
  a `PBXTargetDependency` on the app, Debug+Release configs with `TEST_TARGET_NAME = Causeway`,
  and `TargetAttributes.TestTargetID`. **The blocker this item predicted was the real one:** the
  first `test` run failed with `UITargetAppPath should be provided` because the *app* target had
  no `productReference` — so a `PBXFileReference` for `Causeway.app` was added and referenced by
  the app target (this also closes half of M8). All six XCUITests pass; the four QA-loop
  regression guards were unparked (skip lines removed). One needed recalibration — see
  `.qa-loop/REPORT.md`. **Still open:** a model-level *unit*-test target (F6).
- **M7 — Accessibility (iOS).** No VoiceOver labels/actions; Dynamic Type ignored
  (all fixed `.system(size:)`, tap gestures not buttons).

## Open — medium
- **M8 — Verify buildability from the committed project.** App builds/runs for the owner.
  The missing `productReference` noted here was added 2026-08-21 (it blocked UI testing — see
  UITEST-target), so the project is now closer to what Xcode itself writes; `xcodebuild` builds
  Debug + Release and runs tests from the command line. Still to confirm: a clean clone opens
  and **archives** in the Xcode GUI.
- **DV-1 — Daily "Play"/"Show me how to win" silently discard an in-progress game.**
  `playChallenge()`/`showSolution()` call `deal()` + `persist()`, overwriting the saved casual
  game (any moves/elapsed) with no confirmation or undo. Add a confirm when a different game is
  in progress (`started && moveCount > 0`). Pre-existing; flagged in review-loop 2026-08-15.
  *Partially narrowed (qa-loop round 1 fix, 2026-08-16):* the demo pills now confirm before
  discarding an in-progress **daily attempt** (`challengeDay != nil && moveCount > 0`, iOS +
  web). Still open for the casual-game case and for the "Play" button.
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

### review-loop residuals — qa-loop-majors loop, 2026-08-15 (converged round 2) — ALL FIXED same day
Full report: `.review-loop/REPORT.md`. Four minors were open at convergence; all fixed:
- **RL-1 DONE** — F/C token parity pins are now the CONTIGUOUS case bodies (the bare
  `let col = n(1)` substring matched both cases, so an F-only mutation stayed green —
  mutation-verified the new pin trips).
- **RL-2 DONE** — the cross-copy demo-exit test now pins the iOS model guards too
  (`finishDemo`'s `guard boardComplete else { restartDeal() … }` and `demoAdvance`'s
  abort-to-re-deal), making drift protection two-directional.
- **RL-3 DONE** — the tableau centres only when shrunk (`alignment: w < cardW ? .center :
  .leading`); unshrunk keeps the exact pre-shrink leading alignment with the upper row.
- **RL-4 DONE (user decision: uniform card size)** — the shrink is now WHOLE-BOARD: portrait's
  `portraitFitCardW` computes one shared card width for foundations + free cells + tableau from
  the height of an outer GeometryReader that spans exactly those areas (everything above it is
  card-size-independent, so the fit is a one-shot pure function — no measure→resize feedback).
  Shrinking the upper row frees height too, so the shared size stays as large as possible
  (e.g. 4.7" phone: no shrink until a 15-card column, 41→39pt — vs the old tableau-only path
  triggering at 13 with two card sizes on screen). Deal-scoped monotone latch unchanged.
- **Simulator re-verification pending** — next qa-loop round should re-run TC-2.3 (tall column)
  and the WF-6 demo cases on screen.

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
