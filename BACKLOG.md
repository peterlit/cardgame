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

### QA loop 3, round 1 — implementer pass (2026-08-22)
15 of the 18 open auto-routed findings fixed; 2 argued down. All in the iOS app unless noted.
- **BLOCKER `bug/WF-11` — import ate the app's own export.** `DailyView.importStats` sanitized
  daily keys to `0...today+2` and win seeds to `1...Game.maxSeed` (1,000,000), but a sandbox day
  is `dayIndex < 0` and its deals use seeds above 100,000,000 — so an untouched export→import
  round trip lost a real win and a whole day's four tiers while promising "Importing merges — it
  never erases progress". Bounds widened to what the app can PRODUCE (`-preSeeds.count...today+2`,
  `1...Game.maxValidSeed`); the moves>0/secs>0 poison guards stay; the skipped line now names what
  was dropped instead of calling the user's own file "invalid entries".
- **`bug/WF-7` + `bug/WinsView` — deal entry advertised 1–1,000,000 and enforced nothing** (typing
  5,000,000,000 silently loaded a *different* deal, #4,294,967,295). Enforced at the two entry
  points, NOT in `Game.deal` (whose 4,294,967,295 ceiling exists so daily/sandbox seeds deal the
  same board as web). New `DealFormat.seedRangeHint` is the single honest range string.
- **`ux/WF-5` + `ux/WF-6` + `ux/WF-13` — three reports of one shape.** The Daily sheet confirmed
  before discarding a live game on the *demo* path only, and only for a *daily* attempt. One
  `PendingAction` now gates the day card's `Play` too, and covers casual games, with copy that
  doesn't promise a casual game is replayable. Guard stays off at `moveCount == 0` and on a solved
  board (`Game.hasLiveGame`). Confirmed `Play` still restarts — telemetry is reset by `deal()`, so
  a restart can never keep the old attempt's banked moves/time.
- **`bug/WinsView:row-text-contrast`** — List rows were Buttons, so the gold accent tinted the whole
  label and the stats rendered at 1.42:1 on white. `.buttonStyle(.plain)` + a "Tap a deal to play it
  again." footer keeps the affordance in words.
- **`ux/WF-12`** — the landscape rail clipped "How to play" 100% away with no cue whenever the HUD
  bar shrank its viewport; it now measures its own stack and shows a persistent "▾ more" below the
  scroll area when it overflows.
- **`ux/WF-2`** — column drop frames now overhang the inter-column gutter and a release resolves to
  the nearest column centre, so the ~5 pt gutter no longer belongs to nobody.
- **`bug/WF-4`** — `autoFinishDeferred` is persisted with the saved game (optional field, old saves
  still decode), so "Not yet" survives a kill.
- Smaller: A/K hint on empty foundation slots + `FOUNDATIONS · A↑ / K↓` (WF-1); an "Automation"
  section in How to play (WF-10); streak headline labelled "day streak" + a Flawless definition
  (WF-5); never-attempted objectives no longer show red (WF-5); the board HUD names a catch-up day
  (WF-5); demo headline separator `—` → `·` (WF-13); ungrouped deal numbers in the Wins drill-in.
- **Argued down:** `bug/WF-13:one-big-move-check-lost-on-undo` — undo MUST keep rolling
  `telem.maxRunMoved` back; only the "positive + irreversible" comment (both platforms) was wrong.
  See the CHANGES rationale in the round-1 record.

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
  **Partially mitigated 2026-08-30 (review-loop round 1).** `tests/web-extract.mjs` now lifts the
  shipped web functions out of `index.html` by name and RUNS them (`tests/web-behaviour.test.mjs`
  for `objViolated`/`objSecured`; `tests/autofinish-tiers.test.mjs` for `autoSendWouldBreakTier`,
  `autoFinishTierCost` and the cascade send order), so the web half of the shared contract has
  behavioural — not just string-pin — coverage. Swift still has none: its guards are the drift
  pins, now extended to every `objViolated` family and to the live-tier reads inside both
  refusals. F6 remains the only way to make the Swift copies executable under test.
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
- **L4 — CLOSED (2026-09-08, review-loop round 2)** — win-time semantics aligned: both platforms
  measure banked wall-clock play time and exclude background/hidden stretches (iOS
  `GameClock.pauseForBackground`; web freezes `startTime` on `document.hidden`), drift-guarded.
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

## QA loop 2026-08-30 round 1 — implementer follow-ups

All 15 open auto-routed findings of `.qa-loop/briefs/round-1-impl-brief.json` were addressed
(one commit per WF region, `ba6e773..b7edbde`). Left open deliberately:

- **Deal-entry parity**: iOS *enforces* the 1–1,000,000 bound (Play disabled + a reason, per
  ux/WF-9), while `index.html`'s deal modal and Wins field still `Math.max/min`-**clamp** an
  out-of-range entry and silently deal a different deal — the bug ux/WF-7 fixed on iOS. Not in
  the round-1 brief; needs its own finding.
- **`WinsView.playEntered` is unguarded**: it re-deals over a live game with no confirmation,
  exactly like the Deal # alert did before ux/WF-7. Same for the web's `winsPlay`. The reported
  control was the Deal # alert, so scope was kept there.
- **`⏰` grace forfeited from the Daily sheet**: the sheet's own confirm now names the loss
  (WF-14), but the *no live game* path (`Play` with nothing in progress) still cannot warn,
  because there is nothing to confirm. Only reachable when the graced attempt was already
  abandoned.
- **Stamp-less stats backups lose their daily half on import** (bug/WF-11). Intended: an
  unstamped export cannot be told apart from a pre-recut one. If a pre-release tester has such
  a file, the wins half still restores.


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

### Token-cost analysis of the review/QA loops (2026-08-22)
- **Measured, written up in `docs/loop-token-usage.md`.** Review loop: 17 runs, 22 rounds, 26
  findings for 8.40M effective subagent tokens (323K per finding). QA loop: 3 rounds, 18 findings
  for 39.87M (2.21M per finding) — ~7x more per finding, with `qa-loop:ux-tester` alone accounting
  for 77% of all loop spend. Recommendations are in the doc; the two with the best
  effort-to-saving ratio are (a) run a loop in a FRESH session — measured 3.3x on identical
  plumbing — and (b) give QA testers a pre-built accessibility-identifier index instead of having
  28 agents each re-read the app source. Not repo code changes; they are plugin/skill changes and
  working-habit changes.
- **One earlier recommendation was retracted by the data:** passing the raw diff to the reviewer by
  path rather than in-context saves nothing. Diffs averaged 271 tokens across 48 calls.

### QA loop 3 — parked, with a measured cost report (2026-08-23)
- **`docs/qa-loop-feedback.md`** is the write-up: 23.5M effective subagent tokens for 29 findings
  (811K/finding vs 2.21M last loop; 9.3K/request vs 14.0K). The gain came from cutting the 86 KB
  tester brief to 6.9 KB before the run — it has already regrown to 22 KB.
- **The loop is parked, not converged.** Round 2 ran 2 of 15 chunks. `.qa-loop/REPORT.md` carries a
  banner: 17 of 18 round-1 fixes were reviewed as sound but only three were *verified against the
  running app*. Resuming means re-running round 2 from its step 1.
- Open from round 1: **11 proposal-routed findings await your decision** (they never block the
  loop), plus the round-1 minors that round 2 never got to re-test.
- Top recommendations that are plugin/skill changes, not repo code: cap and rotate
  `HARNESS_NOTES.md`; make the implementer commit per region so targeted passes stay targeted;
  promote the testers' throwaway rigs (PNG diff, save injection, cropping) into `.qa-loop/tools/`
  instead of rebuilding them every round; fix `merge_ledger.py --region WF-1` matching WF-10..13.

### Daily Challenges — the August 2026 recut (2026-08-23)
- Objectives are now **parameterised families** (`docs/daily-challenges.md` §4). Adding variety is
  adding a parameter value to `VARIANTS` in `tools/solver/solve.mjs` and re-running the generator.
- **Only August 2026 is seeded.** After 2026-08-31 there is no daily challenge until someone runs
  `node tools/solver/build-month.mjs` for another month — and the epoch/day-index mapping assumes
  day 0 = 2026-08-01, so a second month needs a decision about whether to extend `days[]` (simple,
  keeps history) or move the epoch again (nukes history again).
- Regenerating the month **rewrites history by design**; both platforms drop a pre-v2 daily store.
  If a future recut is ever meant to preserve history, that is a migration, not a rebuild.
- Ideas certified but not currently offered anywhere: `end-bias` at `min` 7-8 (very common, low
  value as a Gold), and mid-rank `rank-rush`, which is unreachable by construction and is excluded
  from the matrix on purpose.

### Flawless feasibility — measured, not enforced (2026-08-30)
- The pool certifies each day's **Silver and Gold independently**; nothing proves a *single* line
  satisfies both, so 🌟 Flawless — which requires all three tiers in one attempt — can be
  unattainable on a shipped day. Measured on August 2026: **24/31 flawless-certifiable, 3 provably
  impossible** (Aug 1 & 26 pair `suit-sprint` with a Silver that contradicts it; Aug 30 asks for a
  5-card run under "never move more than 2"), 4 uncertified within budget.
- **Adding the constraint costs no variety.** Re-running the same greedy fill with a joint
  feasibility gate produced 31 days / 13 families / 52 distinct challenges — identical to the
  shipped month — keeping 29 of its 31 seeds; the failures are repaired by swapping the *Silver*,
  not the deal (each bad day had 3-8 jointly-feasible alternative Silvers on the same seed+Gold).
  Cost: ~111 extra joint solves (~5 min) per month.
- **Not implemented** — enforcing it means regenerating the month, which rewrites daily history
  again. Cheapest path: land the gate in `build-month.mjs` and let the *next* month be the first
  certified one. Details and an implementation sketch in `docs/solver.md` §7.7.

### Daily Challenges — the Aug+Sep 2026 rebuild (2026-08-30)
- **Every day is flawless-certified.** `certifyFlawless` (in `tools/solver/solve.mjs`) proves a
  single line wins and satisfies both objectives before a day may ship; `contradiction()` rejects
  the structurally impossible pairings with no search. The month builder gates every greedy pick on
  it. Regenerating a month therefore costs one joint search per pick (plus retries) on top of
  phase 1 — cheap next to certification itself.
- **Two months are seeded** (Aug 1 – Sep 30 2026, `days[0..60]`, epoch unchanged). Seeding October
  means re-running `build-month.mjs --days 92` and extending `days[]`; the epoch stays put.
- **History was nuked again** (daily store v2 → v3, both platforms). Any future rebuild that must
  PRESERVE history is a migration, not a rebuild — the day index is the key, and re-picking days
  invalidates it.
- **⏰ Same-day recognition** ships with it: one boolean (`onTime`) on the record, a fifth strict
  streak, a calendar pip, a day-card line and a win-overlay callout. No timestamps are stored, so
  the flag can never be reconstructed after the fact — a later feature would have started from zero,
  which is why it shipped in the same release as the history wipe.
- **The ⏰ grace is day-granular, and that is a product decision, not a bug** (review-loop closeout,
  2026-08-30). `isOnTime` compares day INDICES, so an attempt begun on day D earns ⏰ if it is won
  any time on D+1 — not only just after midnight. A tight window would need a start *timestamp*,
  which §2 of `docs/daily-challenges.md` deliberately rules out ("no timestamps are stored"). The
  docs and both platforms' comments now say what the rule actually is, and the day card offers a
  "resume your attempt today and it still counts" line while the window is open. Open only if we
  ever decide the one-day-lag pattern (start D, finish on D+1, forever) devalues the streak: the fix
  is a stored start timestamp plus a schema bump, i.e. a privacy/schema trade, not a one-liner.
- Open, not done: the App Store listing copy (`store/app-store-listing.md`) still says nothing about
  Daily Challenges, streaks, or the demo — it predates the whole feature.


## Review loop 2026-08-30 (scope `f42c632..HEAD`) — findings left open at closeout

Full report: `.review-loop/REPORT.md` (converged after round 2 + closeout; 0 blockers, 0 majors).

- **The ⏰ grace rewording is only half applied** (`correctness/daily.mjs:ontime-grace-window-too-wide`,
  partial). Behaviour is unchanged and correct, but the comments sitting on BOTH shipping `isOnTime`
  implementations still assert the disproven "midnight grace" framing: `index.html:1240-1241`,
  `ios/Causeway/Causeway/Model/Daily.swift:341-344`, plus `index.html:450-451` and
  `docs/architecture/overview.md:369`. Only the shared-core/test/restore comments were rewritten, so a
  maintainer reading either shipping implementation still learns the wrong rule. Fix: paste the
  `tests/daily.mjs:264-266` wording onto those four sites. (`prompts.md:698` is a historical prompt
  log — leave it.)
- **The new "resume and it still counts" line sits above a button that forfeits the grace**
  (`ux/index.html:gracelive-play-button-forfeits`, introduced by the closeout's own fix). On web,
  `index.html:1474-1475` calls `playChallenge()` with NO confirmation, re-dealing the live attempt and
  re-stamping `challengeStartDay=todayIndex()` — one silent tap loses both the game and the ⏰ the line
  just promised. iOS has a dialog, but its reassurance "You can replay the challenge afterwards"
  (`DailyView.swift:53`) is exactly false in this state. Cheapest fix: extend the line to "Resume your
  attempt today (close this) and it still counts"; better: gate the web button behind a confirm and
  append "— this forfeits ⏰ same-day" to the iOS `confirmMessage`.
- **`tools/loop-usage.py` never reports an agent type** (`tools/loop-usage.py:agent-always-null`,
  pre-existing). `agent_type_of()` scans for keys that do not appear in real subagent transcripts, so
  every row emits `"agent": null` and sidechain cost cannot be split implementer vs reviewer. Token
  numbers are unaffected (`sidechain: true` still works). Fix: try
  `json.load(path + '.meta.json')["agentType"]` first, then the first record's `attributionAgent`,
  keeping the existing scan as a last resort.

## QA loop 2026-08-30 (v0.9.0) — findings left open at the backstop

Full report: `.qa-loop/REPORT.md`. 26 findings, 14 fixed and device-verified, 12 open, 0 blockers.

**Two open majors, both able to lose a player's work:**
- `bug/WF-7:deal-confirm-swallowed-by-double-tap` (**introduced by the loop's own fix**, `9d4a4fc`).
  The `0.1 s asyncAfter` hop puts the destructive "Play that deal" at (274,517), 10 pt from the
  alert's "Play" at (275,527), so a double-tap discards a live game unread (Moves 1 → 0, Undo
  greyed). Reproduced 2/2. Fix the geometry or the timing — not by removing the confirm.
- `ux/WF-14:replay-forfeits-grace-silently` (rejected fix, `c74fa96`). The grace-aware confirm is
  gated on `hasLiveGame` (`moveCount > 0`), never widened. A zero-move grace attempt is destroyed
  silently by **all four** controls (Daily-sheet Play, Replay, New game, demo pill). Fix is the gate:
  `hasLiveGame || graceLive` at `Game.swift:432`, `ContentView.swift:343-345`,
  `DailyView.swift:273-274,335-336`, `index.html:1797,1804` — and suppress the "your 0 moves and
  your time will be discarded" clause in that state.

**Open minors:** `bug/WF-4:win-overlay-seed-grouped` (the one seed surface the round-1 fix missed,
`ContentView.swift:901`); `ux/WF-3:replay-confirm-copy-mismatch` (introduced by a fix — Replay reuses
New-game wording and warns "there is no way back to it" about a deal Replay reloads verbatim);
`bug/DailyView:calendar-cells-have-no-identifier` and `bug/Main:scored-surfaces-addressable-only-by-copy`
(both filed by the regression writer; they are why two guards are weak, and the first also degrades
VoiceOver).

**Six proposals awaiting your decision** — excluded from convergence by design. The two with teeth:
`ux/WF-13:daily-sheet-resets-to-today-midattempt` (behavior-change) and
`ux/Main:clock-runs-during-modal-sheets` (metric-integrity — the clock ticks under the app's own
auto-raised modal, measured at 1 Hz). Also: `ux/WF-13:calendar-month-locked-no-nav`,
`ux/WF-13:par-never-surfaced` (now HALF answered — the day card's new clear line prints par beside
your best moves, but only on a day you have already solved; whether an *unsolved* day should show
its target up front is still your call), `ux/WF-14:grace-invisible-from-daily-sheet`,
`ux/WF-11:import-has-no-confirm-or-undo`.

**Action required from you:** the eight new XCUITest files in `ios/Causeway/CausewayUITests/`
(commit `1241c08`) are all `XCTSkipIf(true, "verify selectors, then remove this line")` and have
**never run on a device**. Run the suite once and delete that line from each test that passes, in
this order: `RegressionDemoExitRebindsDayTests` (metric-integrity) → `RegressionDiscardConfirmTests`
→ `RegressionDealEntryRangeTests` / `RegressionFlawlessDemoLabelTests` (all-real selectors) →
`RegressionAccessibilityIdentifiersTests` / `RegressionDailyCardSeedFormatTests` →
`RegressionDailyCalendarTests` → `RegressionBackupCancelNoteTests` (expect flake).

**Environment gap:** WF-12 (landscape) is entirely unverified — rotation is unreachable from this
toolset (four routes exhausted; see `.qa-loop/REPORT.md`), so the landscape rail call sites of the
new WF-3/WF-7 confirms were never exercised. A debug date override remains the highest-value
testability change available; the ⏰ grace needs a two-day sequence to test honestly.

### review-loop closeout (2026-08-31) — declined here, still open

The closeout pass fixed all five carried minors (grace-at-zero-moves on both platforms, the two
green-by-skip calendar tripwires, the web deal-entry clamp, and both self-inflicted pin findings).
What it deliberately did NOT do, with enough detail to pick up cold:

- **`winsPlay` refuses out of range, but says nothing.** `index.html`'s wins overlay has a second
  deal-number box (`#winsDealInput`). It shared the silent clamp that
  `parity/index.html:deal-entry-clamps-silently` reported against `goDeal`, and now shares
  `parseDealNumber()` — so it no longer deals a board you did not ask for, but on a refusal it
  simply does nothing (as it already did for an empty/NaN entry). The deal modal got an explained
  refusal because its panel has a prose line (`#dealHint`) to reuse; the wins panel has no text slot
  that isn't the results summary. Sketch: add a `<p id="winsDealErr" class="deal-err">` under
  `.wins-deal`, reuse `setDealHint`-style toggling, and pin the copy in `tests/ios-parity.test.mjs`
  next to the `goDeal` pin. Small, but it is new markup + CSS, which is why it was not done in a
  no-iteration pass.
- **`swiftFunc`'s scanner still understands only plain `"…"` literals.** The whole-body pin's
  comment stripper is now nesting-aware for `/* … */`, but a `"""multi-line"""` or `#"raw"#` literal
  inside a pinned body would still be mis-scanned. Rather than write a full Swift lexer, `swiftFunc`
  now ASSERTS that no such literal appears in the body it pinned, so the failure is loud and named
  instead of a bogus "a statement was added". If a pinned body ever needs one of those literals,
  teach the scanner then.
- **The two calendar XCUITests still skip on a DATE.** `testTappingALockedFutureDayExplainsWhy`
  skips on the last day of the month and `testPlayButtonNamesTheSelectedDay` on the 1st, because the
  grid draws the current month only. That is now the *only* permitted kind of skip in that file (see
  its SKIP POLICY header) — no skip may be keyed on a locator a fix introduces. The real cure is the
  already-filed `bug/DailyView:calendar-cells-have-no-identifier` plus a debug date override, which
  would let these run on any date against a fixed calendar.
- **Both grace fixes are unverified on a device.** `hasLiveGame` now ORs in the ⏰ grace on iOS and
  web; the web predicate is *run* by `tests/web-behaviour.test.mjs`
  ("a zero-move attempt still carrying a live ⏰ grace"), the iOS one only string-pinned, and the
  dialog itself needs a two-day sequence (open a challenge, roll the clock a day, tap `New game`)
  that this toolset cannot stage. Same environment gap as the rest of the ⏰ work.

## Review loop v0.8.1 (2026-08-31) — what it left open

Report: `.review-loop/REPORT.md` (stopped at `thrashing_soft` after round 2; a human chose abort +
closeout). Full state is versioned under `.review-loop/`. Four items outlive the loop.

- ~~**BLOCKER — the UI test target is RED on `main`, and the cause is a shipping VoiceOver defect.**~~
  **FIXED 2026-09-04** (see the correction below the entry).
  `RegressionDailyCalendarTests.testPlayButtonNamesTheSelectedDay` fails at
  `RegressionDailyCalendarTests.swift:135` ("no calendar cell for Aug 30"), verified by running the
  target, not by reading it. `DailyView.swift:626` applies `.accessibilityLabel` to a bare `ZStack`
  with no `.accessibilityElement(children: .combine)` and no button trait, so XCUITest sees only the
  child `staticText` and VoiceOver announces every day as a bare number — no month, no earned tiers,
  no lock state, no button trait. The closeout replaced the `XCTSkipUnless` that had been hiding
  this; `testTappingALockedFutureDayExplainsWhy` uses the same query and escaped only because the
  run was on the last day of the month — it goes red 2026-09-01. **Fix:** add
  `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)` +
  `.accessibilityIdentifier("daily.cal.<idx>")` at `DailyView.swift:626`, then run BOTH calendar
  tests (not `build-for-testing`). This is the same work as the already-filed
  `bug/DailyView:calendar-cells-have-no-identifier`.

  **Correction, from fixing it:** the reviewer's remedy was necessary but NOT sufficient, and doing
  exactly what the note said left both tests still failing. Dumping the accessibility tree showed two
  faults. (1) The cell was not an accessibility element — `.accessibilityElement(children: .combine)`
  plus `.accessibilityAddTraits(.isButton)` fixes that, and cells now expose as
  `Button, label: "Sep 3"` (locked ones as `"Sep 5, locked until that date"`) instead of a bare
  `staticText "3"`; that is the VoiceOver half, and it was real. (2) `openDailyCalendar` scrolled
  until the legend `.exists`, which is TRUE for an element that is merely in the hierarchy, so it
  stopped after zero swipes with the grid still below the fold — and the grid is a `LazyVGrid`, which
  materialises nothing (not even its weekday header) until it is on screen. `.isHittable` is what
  turned the class green: 3 tests, 3 passed, 0 skipped, plus the full UI suite. Any future
  "no calendar cell for <day>" failure should be read as a scroll-predicate problem first.
- **The loop's structural stopper: `ios/Causeway` has no Swift unit-test target.** Every guard on
  Swift is a string comparison performed by `tests/ios-parity.test.mjs`. Two rounds of pinning the
  functions the reviewer named ended with the reviewer finding new ones — mutants
  `y-ios-endsFirstOK-early-true` (`Daily.swift:128`) and `y-ios-liveAttempt-zero-moves`
  (`Game.swift:967`) both survive the full suite today, i.e. the iOS tier ✗ chips and the iOS
  moves-family refusal can be disabled with everything green. Pinning function-by-function will not
  converge. The decision is a real test target vs. accepting text pins and documenting the limit.
- **Three re-deal entry points bypass `hasLiveGame`**, so the ⏰ grace the closeout protected is
  still forfeitable: web daily-sheet Play/Replay (`index.html:1587-1588`, straight from `onclick`),
  `showSolution` (`index.html:1522`, its own weaker `challengeDay!=null && moveCount>0`), and the
  Wins sheet on both platforms (`WinsView.swift:87,108`; web `winsPlay`). The comment at
  `index.html:1863` claiming the Daily sheet has guarded this "since round 0" is false. Fix shape:
  route those through `confirmReset()`/`hasLiveGame()` the way `ContentView.requestReset` does.
- **`RegressionDailyCalendarTests` pool-end time bomb.** `testPlayButtonNamesTheSelectedDay` guards
  the pool's start (`yesterday >= 2026-08-01`) but not its end; `daily-pool.json` seeds 61 days
  (2026-08-01..09-30), so from 2026-10-02 the yesterday cell is unavailable and the test hard-fails
  blaming the calendar grid. Round 3 also widened the locked-note assertion to an OR, so after
  2026-09-30 `testTappingALockedFutureDayExplainsWhy` passes through the out-of-pool branch and no
  longer exercises the ux/WF-13 path it was written for. Fix: bound the date guard by pool size and
  keep the two lockedNote branches as distinct assertions.

## Skeptical review 2026-09-07 — findings verified against source 2026-09-08

An independent review ([docs/skeptical-review-2026-09-07.md](docs/skeptical-review-2026-09-07.md),
baseline `21fb200`) filed 11 findings. Each was re-verified here at the cited lines; **all 11 are
real at the code level.** (Runtime measurements — modal pixel geometry, the 2.26 s clock probe, the
Buddhist-calendar index value — are the reviewer's, but every mechanism behind them checks out.)
Open items, in the review's IDs:

- **R1 (P1, web)** — startup `restoreGame()` (`index.html:2028→595`) runs autoplay/auto-finish
  synchronously while `dailyPool` is still null (fetch at 1391); the tier guard bails permissive
  when the pool is absent (700) and `recordChallengeResult` returns null with no retry (1546) after
  `recordWin` has already cleared the save. Tier loss and lost daily credit on a slow/failed fetch.
- **R2 (P1, both)** — a saved attempt carries seed + `challengeDay` but no binding between them:
  `recordChallengeResult` (`Game.swift:935`, web 1546-1549) scores the CURRENT challenge at that day
  index without checking its seed is the seed played. Becomes live for every player the moment the
  pool is regenerated. Minimal fix: verify `pool[day].seed == seed` at restore and at scoring.
- **R3 (P2, both)** — `recordWin`'s guard (`Game.swift:909`, web `index.html:1231`) puts
  stopTimer/clearSaved behind `winRecorded`; `undo()` re-persists an unfinished board without
  resetting it (`Game.swift:507`, web 783), so win→undo→win skips all cleanup.
- **R4 (P1, both)** — `confirmReset()` guards only newBtn/replayBtn/goDeal; web `playChallenge`
  (1401), `winsPlay` (1870), `dealRandom` (2012), the unfocused `N` key (2020) and iOS WinsView
  (`WinsView.swift:87,108`) all `deal()` straight through a live attempt, forfeiting ⏰ grace.
  `showSolution`'s own guard (1528) misses casual progress. Wider than the earlier three-route note.
- **R5 (P2, iOS)** — `todayIndex()` feeds `Calendar.current` components into the Gregorian
  day-number algorithm (`Daily.swift:61`); Buddhist/Hebrew/Islamic system calendars produce garbage
  indices. Fix: Gregorian calendar + local time zone for civil arithmetic.
- **R6 (P1, web)** — `.overlay`/`.panel` (`index.html:124`) has no max-height or internal scroll;
  the Daily panel overflows a 720 px viewport with Close unreachable, and no Escape handler.
- **R7 (P2, web)** — `dragUp` reinstates a stale source (`index.html:1201`); a cell emptied by
  autoplay mid-drag yields `[null]`, which passes the `.length` guards and throws in `canStack*`.
- **R8 (P1, tooling)** — `build-month.mjs` warns on underfill then writes anyway with exit 0
  (283-297), selects from scratch and reorders (no append/prefix guarantee). Must fail closed
  **before** any reseeding; the pool still runs out 2026-09-30, which couples this to R2.
- **R9 (P2, iOS)** — `GameClock` does `elapsed += 1` per timer delivery (`GameClock.swift:21`);
  stalls undercount. This is the old L4, upgraded from polish to measurement defect.
- **R10 (P2, tests)** — the `.isHittable`-legend scroll criterion
  (`RegressionDailyCalendarTests.swift:171`) is layout/date-sensitive: green 2026-09-04, red (2 of
  21) on the reviewer's 2026-09-07 run with the legend hittable before the LazyVGrid materialised.
  Durable fix: scroll toward the target cell with stable per-day identifiers + a controlled date;
  same visit should close the pool-end time bomb above.
- **R11 (P2, iOS)** — `mergeTiers` keeps independent minima (`Daily.swift:431-432`) and
  `clearsSummary` (`DailyView.swift:284`) renders them as one run that never happened; "Cleared N×"
  reads a bounded, deduplicated list as a lifetime count.
- **Harness drift (tests)** — `tests/web-extract.mjs:119` declares `NCELLS = 4`; shipping
  `index.html:443` says 3. Five-minute fix, and a caution against treating extraction as production.

A phased fix plan was proposed in conversation (prompts.md #87): lifecycle P1s first (R4→R2→R1→R3),
then surfaces (R5/R6/R7/R10), then a swiftc-based native harness (no pbxproj edits), then the
fail-closed builder before reseeding, then polish. Owner decisions pending: post-win-undo
semantics, seed-binding vs full generation fingerprint, Swift test-target timing, and whether R8
jumps the queue given the 09-30 pool expiry.

## 2026-09-08 — the skeptical review's findings addressed

All eleven findings from the 2026-09-07 review (verified section above) were fixed in one pass,
commits `6c248b8..23114d0` + the docs commit that carries this note. Per-item status:

- **R1 FIXED** — `dailyRulesPending()` holds all automation while a restored daily attempt's pool
  fetch is outstanding; a win meanwhile banks a durable pending grade, replayed by
  `scorePendingDaily()` on pool arrival (any session). Executable web tests run the shipped path.
- **R2 FIXED (minimal, per owner)** — `challengeBindingValid` (both platforms) at restore, pool
  arrival, and scoring; mismatch degrades to casual. Native unit tests cover restore both ways.
- **R3 FIXED (owner: casual continuation)** — post-win undo resets the record-once latch; a re-win
  reconciles clock/save/stores. Native test drives win→undo→win through the real move API.
- **R4 FIXED** — web `requestDeal()` gate over all 8 user routes (+ typing/dialog guards on the
  keyboard shortcut); iOS WinsView routes through `ContentView.requestDealFromDismissal`. The route
  matrix is pinned; the older "three re-deal entry points" item above is closed by this.
- **R5 FIXED** — `todayIndex()` is Gregorian + local time zone; presentation keeps the locale.
- **R6 FIXED** — `.panel` is viewport-bounded with internal scroll; Escape closes the top
  informational dialog (never the finish prompt — that's a decision).
- **R7 FIXED** — `selectedCards()` refuses vacant/stale sources; a mid-drag autoplay steal snaps
  back instead of throwing.
- **R8 FIXED** — builder publishing contract: fail-closed underfill, candidate-validate-swap
  writes, `--extend` preserves published days verbatim, `--rebuild` demands a POOL_VERSION bump.
  Five tests run the builder. **Reseeding itself stays deferred by the owner** — but the mechanism
  is now safe to resume with (`--extend --days 92` when the time comes). Pool still ends
  **2026-09-30**.
- **R9 FIXED** — GameClock measures wall time; background pause is explicit. 5 unit tests incl. a
  blocked-run-loop probe. (Closes L4. The physical-device memory item I6/I6-verify remains open
  and untouched.)
- **R10 FIXED** — calendar UI tests pin the clock (CAUSEWAY_TODAY_OVERRIDE, DEBUG-only), scroll to
  the target cell by the new stable `daily.cal.<idx>` identifier. Closes the pool-end test time
  bomb and `bug/DailyView:calendar-cells-have-no-identifier`. One note: the out-of-pool
  locked-note branch ("No challenge on …") is no longer exercised by UI test — it is only
  reachable when today is past the pool end, which the pinned clock deliberately never is.
- **R11 FIXED** — fewest/fastest labelled separately everywhere; clear count caps at the bounded
  log ("20+×"). Pinned as parity contract.
- **Harness drift FIXED** — web-extract NCELLS 4→3; plus a second latent extraction bug found
  while testing R1: `scanTo` truncated any function with a destructured parameter.
- **F6 (no Swift unit-test target) CLOSED** — `CausewayTests` exists (owner authorized the pbxproj
  edit, Xcode closed). 11 unit tests incl. a full 61-day certified-line replay through the real
  move API (~3 s). F6b's concrete drift example is fixed; the wider "generate the inline web
  script from a canonical module" idea stays open below.

**Still open after this pass** (unchanged from the review's "ugly" chapter): the secondary-screen
hierarchy simplification (daily sheet information density), a real VoiceOver/large-text
playthrough (owner or device time), the single-file-web build step idea, daily-challenges.md's
corrections-first structure, and the owner-only shipping items (URLs, contact email, physical
iOS 17/18 pass, I6 Release memory measurement).

## 2026-09-08 — review-loop round 1 on the pass above

- **Blocker FIXED** — `--extend` could never publish: the selector was asked for `--days` days
  instead of the open slots, so every extension failed its own candidate day-count check.
  Selection now fills exactly the open slots; verified end-to-end (61 published + 4 fresh).
- **Majors FIXED** — an extension inherits the published days' novelty counters and hard-bars
  exact published (silver, gold) pairs, enforced again on the output bytes; a daily-pool.json
  that exists but won't parse REFUSES instead of counting as absent (corruption ≠ absence);
  builder tests now include three POSITIVE cases (fresh publish, extend publish, corrupt-refusal)
  against the tracked cache — the suite can no longer be satisfied by a tool that always refuses;
  the Swift unit tests snapshot/restore every `causeway.*` default instead of deleting them, so
  the still-pending on-device run cannot erase the owner's real history (sentinel-verified).
- **Minors FIXED** — the web pool fetch retries with capped backoff (one failed fetch no longer
  disables automation for the whole session); web post-win undo re-anchors the clock past the
  overlay dwell (iOS GameClock parity, pinned in ios-parity.test.mjs); a deferred win overlay
  redraws with the actual medals when the pool lands.
- **NEW OPEN: clients don't couple daily history to the pool generation.** POOL_VERSION (builder,
  4) and the clients' store gates (web `g.version===3`, iOS `DailyStore.version = 3`) are
  independent numbers — bumping POOL_VERSION satisfies `--rebuild`'s gate but changes nothing on
  either client, so after a rebuild every player's day-N medals would score against a different
  day-N challenge. The builder's refusal message now states this outright (bump = necessary, not
  sufficient). Only matters if a rebuild is ever chosen over `--extend`; the sanctioned reseed
  path is `--extend`, which is unaffected.

## 2026-09-08 — review-loop round 2 on the round-1 fixes

- **Blocker (introduced by round 1) FIXED — extend-cap-starvation.** Seeding the novelty counters
  from the published pool also fed the per-family cap (max 12), and the 61 published days had
  pre-spent 9 of those 12 on six silver families — so `--extend` could never fill more than 23
  new days, while its failure message pointed at `--candidates`/`--budget` (which could never
  help), and the round-1 extend test used +4 days, the one size that dodged the ceiling. Fix:
  the SCORING counters still inherit the published history (novelty debt across the seam), but
  the CAP counters now count only the current run's picks. Verified end-to-end on a scratch
  copy: `--extend --days 92` publishes all 31 new days, the 61 published stay byte-identical,
  zero published-pair repeats; the extend test now demands a full 31-day month (do not shrink it).
- **Minor FIXED — web clock counted hidden-tab time.** iOS pauses `GameClock` when the scene
  leaves `.active`; the web only saved on `visibilitychange`, so ten hidden minutes inflated the
  HUD, the win overlay, and the persisted best. The web now freezes the anchor while
  `document.hidden` and shifts it past the hidden stretch on return — covering saves written
  from a hidden tab, autoplay wins in a hidden tab, and tabs restored in the background — with a
  two-sided drift guard in ios-parity.test.mjs. This also closes **L4** (win-time semantics):
  both platforms now measure banked wall-clock play time, excluding background/hidden stretches.

## 2026-09-08 — review-loop closeout (converged round 2; both open minors CLOSED)

- **Minor FIXED — GameClockTests wall-clock flake.** The suite slept ~5.7 real seconds and
  asserted loose bounds (`elapsed <= 3` after a 2.3s sleep with `Int()` truncation), so 0.7s of
  scheduler overshoot on a loaded Mac turned a correct clock red. `GameClock` now takes an
  injectable `now: () -> Date` (production default: the real clock; three call sites), and the
  tests advance a fake date by hand — exact-equality assertions, zero sleeps, and the
  delivery-counting regression stays pinned (a synchronous test services no run loop, so a
  counter would read 0 where the measurement reads 2). Unit suite: 11/11 in ~2.5s.
- **Minor FIXED — per-family cap never asserted.** Both builder publish tests now assert that no
  silver and no gold family occupies more than 12 of the days the run selects (the
  `selectMonthBalanced` ceiling) — for `--extend`, the fresh slice only, matching the round-2
  cap semantics. Measured headroom is ~5 uses per family, so the assertion cannot flake; a
  neutered `capped()` now has a test in its way.

- **Open minor (closeout reviewer, `introduced_by_fix`) — real-clock default untested.**
  `tests/GameClockTests:real-clock-default-untested`: every GameClock unit test goes through
  `makeClock()`, which overwrites the injected `now`, so nothing exercises the production
  default `now = { Date() }` (`GameClock.swift:32`). Freeze that default and all 5 unit tests
  plus all 21 UI tests stay green while the shipped HUD sits at 0:00 and wins bank 0 seconds —
  the only UI test touching the readout asserts `stat.time` *exists*, never its value.
  Test-only fix, no shipped-behavior change: e.g.
  `XCTAssertLessThan(abs(GameClock().now().timeIntervalSinceNow), 1)`. Filed from closeout
  (no further loop cycle available); ledger id in `.review-loop/ledger.json`.

## 2026-09-09 — qa-loop v0.12.0 (autonomous, 4 rounds, 3 testers; stopped by the owner in round 4)

Report: `.qa-loop/REPORT.md`. Decisions: `docs/qa-loop-2026-09-09-decisions.md`. Cost + plugin feedback:
`docs/qa-loop-0.12.0-feedback.md`.

- **FIXED and device-verified (24):** deal-alert double-tap discard (`bug/WF-7`, 0.5 s disarmed destructive
  button); same-day second export trashing the only backup (`bug/WF-11`, `-HHmmss` filename); landscape
  rail hiding Daily/Wins/How to play + inert "more" cue + per-move board rescale (`ux/WF-12` ×3); demo Prev
  incl. from the completion banner (`ux/WF-6`); Daily sheet Dynamic Type + calendar-marker slot (`ux/WF-5`
  ×2) + par legend; a11y state on calendar cells and tier rows (`ux/WF-13` ×2); grace-confirm title on the
  sheet (`ux/WF-14`); 🌟 headline objectives + banked-tiers "Not yet Flawless" line + proportionate demo bar
  (`ux/WF-15` ×3); win-overlay seed ungrouped (`bug/WF-4`); Replay confirm title/body (`ux/WF-3`);
  How-to-play Controls precondition + "tidy run" definition (`ux/WF-10`); casual-tail copy (`ux/WF-7`);
  fruitless-tap wiggle (`ux/WF-2`); identifiers on the win overlay, HUD chips, Wins, streak/day cards.
- **OPEN minors (3):** `ux/WF-3:grace-newgame-body-describes-replay` (New game's grace body describes
  Replay; one-line copy fix in `resetConfirmMessage`'s graceLive branch); `ux/DailyView:legend-paragraphs-addressable-only-by-copy`
  and `ux/ContentView:demo-bar-container-has-no-identifier` (identifiers `daily.legend`, `daily.cal.legend`, `demo.bar`).
- **OPEN proposals (5, owner decisions):** Daily sheet snaps to Today mid-attempt (WF-13, behaviour-change
  trap); live ⏰ grace invisible from the sheet (WF-14, metric-integrity trap); landscape Daily sheet's Play
  below the fold (WF-12); import has no confirm/undo (WF-11); the clock runs during the app's own modal
  prompts (Main, metric-integrity trap). Plus one data decision: no 🥈 demo on universal-family days.
- **WONTFIX:** `ux/WF-9:wins-row-no-run-count` (a run count is a persisted-format migration shared by iOS,
  web and the backup; the footer states the independence instead).
- **Doc drift to refresh in `.qa-loop/TESTCASES.md`** (expected text stale after the copy fixes): TC-1.1
  step 4 (dev deal), TC-2.6 shrink size, TC-3.1/3.2 "one tap" on a live game, TC-4.4/4.7/14.3 grouped deal
  numbers, TC-5.2/5.3/5.4 chip/xmark/fixture times, TC-6.2/6.6/6.7 demo bar text, TC-7.5/7.6 gate/copy,
  TC-9.5 fixture times, TC-10.1 sections, TC-11.1/11.4 filename + sanitizer, TC-12.2, TC-14.7, TC-15.1.
- **Round 4 unrun:** the confirmation pass stopped at 24/90 (WF-1…5 clean); WF-6…15 were last exercised
  in rounds 2-3 with every fix verified and no regressions.
- **Review loop not run** on the 22 app commits `1a63ce2..836434d` (CLAUDE.md standing rule; skipped per
  decision D8 because this session was 4 MB). Start it fresh: `/review-loop-tools:review-loop 1a63ce2..836434d`.
- **Plugin issues for the maintainer** (top three): worker names collide across sessions and the
  provisioner deletes other sessions' devices; the MCP control tool's per-device grant blocks autonomous
  runs (ship the driver); `notes-rotate` archives the largest section (it archived the driver section
  three times).
