# Prompts log

A running, chronological log of the user requests that have shaped Causeway. Newest at
the bottom. Kept up to date as new instructions come in (paraphrased, one line each).

## Concept & web prototype
1. Design a new card game I might like (I love MobilityWare FreeCell, like Castle;
   dislike TriPeaks/Solitaire/Crown), implement it in the browser, iterate.
2. Add MobilityWare-style auto-play.
3. Add pictures to cards (they're hard to distinguish); use images for J/Q/K.
4. Add the ability to build a tableau pile from the other end (two-way building).
5. Double-tap: if no foundation, move onto another column, else empty column, else free
   cell; default suggestion = next deal number.
6. Don't start auto-play until the first move.
7. Add deal-number entry + track/visualise ranges of deals won (like the reference), with
   a drill-down to individual deals + stats.
8. Fix: single-click sends card under the next one (z-index bug).
9. Restyle to look like MobilityWare FreeCell (cream cards, muted palette).
10. Deal button gave no input box; add per-suit tint.
11. Fix: pip layout too close to value / 10s overlap; use figures for J/Q/K.
12. Win popup: option to leave the board and not start a new game.
13. Commit working-tree changes at the end of every task (standing instruction).

## iOS app
14. Turn the web prototype into an iOS app → chose a **native SwiftUI rewrite**.
15. Fix toolbar overflow (Deal #/Wins hidden); add How-to-play.
16. Review + fix security implications of running on my iPhone.
17. Design an app icon; make it deploy-ready.
18. Debug device-install signing errors (ad-hoc / stale scheme / launch resolution).
19. "Low-res" display fix → added a launch-screen storyboard.
20. Bigger card values; match rank height to suit; enlarge the centre pip.
21. "10" should be tall & slender (condense, don't shrink).
22. Fix Q descender clipped on stacked cards.
23. Make the diamond the same width as the other suit icons.
24. Original sun-&-summer background artwork.
25. Fix: cloud obscures foundation slot watermarks.
26. Add deal-number entry on the Wins screen.

## Cross-platform + release
27. Port all the iOS features/style/visuals back into the web prototype.
28. Double-tap works on any card heading a valid run (both platforms).
29. Add a root README.
30. How do I publish to the App Store? → drafted `store/` listing + privacy policy;
    warn users it's an early alpha (tested only on iPhone 13 Pro, portrait only).
31. Act on the skeptical full-app review; create & maintain `prompts.md` and `BACKLOG.md`.
32. Address the post-fix validation review (REVIEW-2): closed R1 (isSeqHead guard), O1
    (dead iPad key); logged O2 (WinStore schema versioning) to the backlog.
33. M2 — persist the in-progress game so backgrounding/reload doesn't lose it (both
    platforms; restore on launch, clear on win).
34. Run the adversarial review loop (skeptical-reviewer <-> implementer) to convergence.
35. Review-loop round 1 — fixed the win-overlay "Close" persist desync (F1, iOS), web
    `isSeqHead` bounds guard (F2), canonical-deck restore validation (F3, both), resume
    autoplay after restore (F4, both), and privacy-policy in-progress-save disclosure (F5).
36. Review-loop round 2 — added a dependency-free Node engine test harness (F6:
    deal/RNG determinism, `isSafeAutoplay` soundness, restore validator, + a drift guard;
    XCTest deferred to backlog), suit range-check in the web restore validator (F3), and
    bumped the privacy-policy date (F5).
37. Fix an on-device OOM: isolate the 1 Hz clock (GameClock) and make SummerBackground
    equatable so the blurred scene isn't re-rasterized every second (I6). Then re-run the loop.
38. Analyze then change interaction: single tap = smart-move (was double-tap) + drag to place
    a card/stack exactly (hybrid). Removes the old tap-to-select model and double-tap latency
    (M6). Web done + tested. iOS: single tap great on device, but the first `.draggable` port felt
    wrong (press-and-hold to lift + the system "+"/ghost drag chrome) — replaced with a manual
    `DragGesture(minimumDistance: 0)` (instant grab, in-place finger-follow, tap/drag split at an
    8px slop) + a `PreferenceKey` map of drop-zone frames in a "board" coordinate space for
    hit-testing. Verified on the iPhone 17 Pro simulator: tap→smart-move, single drag to a chosen
    free cell, illegal-drop snap-back, and a 2-card run drag across columns all work.
39. Review a fresh on-device OOM report (iPhone 13 Pro, ~21.6 min). Finding: the app now survives
    longer post-fix (was ~14 min) but was still jetsam-killed — however the crash came from a Debug
    build under Xcode with View Debugging + Malloc Stack Logging + checkers, which inflate/grow RSS
    and make it an invalid read of production memory. Code review finds no idle-time leak (clock
    isolated, autoplay self-terminating, undo bounded). Reopened I6; I6-verify now demands a
    Release + untethered (or Instruments Allocations) re-measure before chasing any fix.
40. Third tethered OOM (~32 min, still Debug+Xcode instrumentation). Doesn't change the call —
    same contaminated setup; survival is *increasing* across runs (14→21.6→32 min), and a code
    audit finds no unbounded-growth mechanism (no audio, one Combine sink, undo bounded, clock
    isolated). Built an in-app memory HUD (`DebugFlags.memoryHUD`, `MemoryMonitor`/`MemoryHUD`:
    live phys_footprint MEM/PEAK/FREE via task_vm_info) so a Release + untethered run can show
    whether footprint actually climbs — the clean signal Instruments/JetsamEvent would give,
    without either. Must set the flag false before shipping (release checklist).
41. Card appearance: keep 8px radius, make the face flat white, border deepest black. Both
    platforms — web `.card` white bg + `--card-edge` #000 + removed per-suit tints; iOS
    `CardView` white fill + `Theme.cardEdge` #000. Empty slots left as-is.
42. Make Auto-finish a toggle (on by default) that fires automatically instead of on tap.
    Trigger = "when the game is won" (a full send-everything-home cascade would win); action =
    the existing aggressive `autoFinish()`. New `autoFinishWouldWin()` dry-run gates a
    `maybeAutoFinish()` called after each move / autoplay-settle / restore. Both platforms +
    persisted setting; 4 new engine tests (22/22) with drift guard; verified end-to-end on web
    (ON auto-completes, OFF doesn't, fresh deal never false-triggers).
43. Auto-finish: add a third mode "Ask" (now the default) — On/Off/Ask cycle. In Ask, reaching a
    finishable board shows a "Ready to finish?" pop-up (Finish / Not yet); deferring stops nagging
    but leaves a "Finish" button to run it later. Replaced the abrupt batch finish with a sequential
    one-card-at-a-time flight (each starts as the previous lands), reusing the safe-autoplay reveal
    cadence. Both platforms; persisted (`causeway.autofinishmode`). Verified all 3 modes end-to-end
    on web (prompt, defer+no-renag, Finish button, sequential finish, On auto, Off manual); iOS
    type-checks + builds, toolbar shows "Auto-finish: Ask". Review loop requested next.
44. Fix: the finish's win overlay popped up over a still-animating (incomplete-looking) foundation.
    Now hold `onWin()` until the last card lands + a short beat (web setTimeout 320ms after the
    140ms flight; iOS 0.38s after the 0.2s flight), guarded so undo/new-game during the delay cancels
    it. Verified on web that onWin fires strictly after the final card's render.
45. Design (no code) a MobilityWare-style Daily Challenges feature. Iterated to a fully-decided
    design and wrote it up: `docs/daily-challenges.md`. Model A "Deal of the Day" tiered
    (Bronze=win required + one Silver + one Gold), deterministic-from-date, solver-certified pool of
    seeds >10,000 (1–10,000 reserved for personal range-play; Phase 0 constrained solver retires I2),
    frozen replayable history, automation policy #3 (violating auto-move fails the objective),
    dedicated Challenges & Streaks screen with Play/Silver/Gold streaks. Logged as BACKLOG DAILY.
46. Document the solver spec and implement Phase 0. Built the offline Causeway solver `tools/solver/`
    (rules ported from index.html; weighted-A* best-first with a burial heuristic + transposition +
    gated auto-safe; certifies winnable/par + which constraint objectives each seed admits, sound by
    construction for gating objectives). Spec in `docs/solver.md`; tests `tests/solver.test.mjs`
    (9 pass); pool builder emits append-only `data/daily-pool.json` over seeds >10,000. Retires I2.
    Dropped `empty-column` (vacuous — winning empties all columns). Par is near-optimal (documented).
47. Start Phase 1 + grow pool + review loop. Grew the certified pool in the background (toward a
    year). Built the shared Daily-Challenges core `tests/daily.mjs` (Node-tested, 13 tests): the
    deterministic date→challenge generator (day index off a 2026-08-12 epoch → pool.seeds[dayIndex],
    append-only frozen history; per-day RNG picks Silver/Gold from the seed's certified supports),
    the objective checkers (evaluate from foundation-order + resource telemetry), and the three
    catch-up streaks. App integration (screen/telemetry/DailyStore, both platforms) still TODO.
48. Pool → 366 seeds (a full year; ~98% winnable), reformatted one-seed-per-line. Prototyped the
    Challenges & Streaks screen (Artifact) for review. Then wired the shared core into the WEB app:
    inlined daily logic (drift-guarded), fetch the pool, Daily button + Challenges/Streaks overlay
    (streaks + today card + month calendar), per-attempt telemetry (diff-based recordHomed leaves the
    pinned send fns untouched; cellUses/undos), live objectives HUD, on-win tier scoring into a
    versioned causeway.daily store (OR across retries) + derived streaks + win-overlay tiers, persisted
    across reload. Verified end-to-end in the browser (52 tests, 3 drift guards). iOS mirror still TODO.
49. Add a "Flawless" recognition + a 4th Flawless streak: earning Bronze+Silver+Gold in a SINGLE
    attempt (harder than banking them across free retries). Shared core (`tests/daily.mjs`):
    evaluateChallenge sets `flawless`, mergeTiers keeps it sticky, streaks derives a 4th run; web
    (`index.html`) mirrors all three (drift-guarded) + a 4-up streak card (🌟), a today-card header
    badge, a calendar ⭐ on flawless days, and a win-overlay callout. 55 tests green; verified in the
    browser (4 streak cards, badge, 2 calendar stars). Then run a review loop; then mirror to iOS.
50. Web Flawless review loop — converged (round 2). Round 1 caught a major (calendar ⭐ was
    position:absolute with no positioned ancestor → all stars piled in the overlay corner; fixed by
    .dcell{position:relative}) and a minor (legend missing the 🌟 entry); round 2 cold pass clean.
51. Mirror the whole Daily Challenges feature (incl. Flawless) into the iOS app. New Swift port of
    the shared core (`Model/Daily.swift`: date→challenge generator, objective checkers, streaks,
    Flawless, pool loader) + `Model/DailyStore.swift` (versioned UserDefaults). Telemetry wired into
    `Model/Game.swift` (diff-based recordHomed, snapshot/undo rollback of foundationOrder+cellUses,
    cellUses on genuine parks, challengeDay lifecycle + persist/restore, recordChallengeResult on
    win). New `Views/DailyView.swift` — Challenges & Streaks screen (4 streaks, tiered day card,
    month calendar with ⭐ + legend) + a live objectives HUD. ContentView gets a Daily pill, the
    sheet, the HUD, and the win-overlay tiers/Flawless callout. Pool JSON bundled (auto-synced
    group). Builds + runs on the iPhone 17 Pro simulator; the generator produces the same Deal
    #10,001 + objectives as web. Review loop next.
52. Add a Replay button (restart the current deal from scratch — preserving the daily-challenge
    context if one is active, so a challenge replay stays scored as that day) and give the Undo
    button a recognizable icon (a left-bent/curved arrow). Both platforms: web adds an inline
    Material-style undo SVG on the Undo pill + a Replay toolbar button wired to a new `restartDeal()`
    (re-deals `seed`, keeps `challengeDay`); iOS adds a `pill(systemImage:)` overload, an
    `arrow.uturn.backward` icon on Undo, a Replay pill (`arrow.clockwise`), and `Game.restartDeal()`.
    Verified: web casual restart resets moves/history/telemetry for the same seed; iOS Replay on a
    daily reset the board to a fresh Deal #10,001 with the live HUD (challenge) preserved. Standing
    rule from this task on: run a review loop after every non-trivial change unless told otherwise.
53. Add a "Show me how to win" feature for Daily Challenge deals. The offline solver now reconstructs
    the winning line (weighted-A* with parent/segment tracking, incl. the auto-safe sends) and
    `tools/solver/build-solutions.mjs` bakes each pool seed's shortest UNCONSTRAINED line as a compact
    token string into an append-only `data/daily-solutions.json` (366 seeds, each re-simulated to a
    verified win). Web: a "💡 Show me how to win" button on any playable Daily day card resets to the
    fresh deal and animates the line move-by-move over a "Showing a winning line…" bar (Stop/Done);
    it's a demonstration — input is locked during playback, `challengeDay` stays null, and nothing is
    scored (verified: board clears in 83 moves, wins + daily store unchanged, no win overlay). iOS
    mirror + review loop next.
54. Mirror "Show me how to win" into iOS. `DailyData.solutions` loads the bundled
    `daily-solutions.json`; `Game.showSolution/stopDemo/applyDemoToken` animate the line (asyncAfter
    step loop gated by a `demoGen` token; `demoing`/`demoDoneMessage` @Published), with input locked
    (guards in smartMove/drop) and nothing scored; New game/Undo/Replay stop the demo. `DailyView`
    gains the "💡 Show me how to win" button; ContentView gains a `demoBar` (status + Stop/Done).
    Verified on the iPhone 17 Pro simulator: deal 10002 animates to a cleared board in 78 moves, ends
    with the "tap Replay to try it yourself" banner, Won stays 0 (assisted, unscored). Review loop next.
55. Add pause + single-step controls to "Show me how to win" (both platforms). The demo is now a
    state machine (playing ↔ paused, then done): a Pause/Resume toggle stops/starts the auto-advance,
    and a "Next" button (shown only while paused) advances exactly one move; the bar shows live
    progress ("Winning line — 55 / 78 (paused)"). Web refactors `showSolution` into
    `demoAdvance`/`demoTick`/`demoTogglePause`/`demoStepOnce` + `updateDemoBar` over module state
    (demoMoves/demoIdx/demoPaused); iOS mirrors it (`scheduleDemoStep` guards on `!demoPaused`,
    `demoAdvance`/`demoStepOnce`/`demoTogglePause`, `demoProgress`, demoBar shows Next/Pause/Resume/
    Stop/Done). Verified: web pause holds + Next steps one move + Resume continues + step-to-end shows
    Done (unscored); iOS same on the simulator (paused 53/78, Next→54→55, Resume→done, Won 0).
56. Add Silver/Gold options to "Show me how to win" (it previously only aimed at Bronze/clear).
    The solver now bakes ONE line per tier: `build-solutions.mjs` solves each seed under its day's
    Gold objective (`dailyChallenge(index).gold`) and, when the day's Silver is a *certified*
    objective, under that Silver too (universal Silvers — win-in-N / no-undo — fall back to bronze).
    Each silver/gold line is re-checked against the real objective checker (`tests/daily.mjs evaluate`),
    not just isWon — 366 gold + 190 silver lines, 0 rejected. Data schema v2: `{bronze, silver?, gold?}`
    per seed. Both apps show a per-tier "Show me how to win:" button row (🥉 Clear / 🥈 Silver / 🥇 Gold)
    and the demo bar names the objective ("🥇 Gold: Get every Jack onto the down-foundation… — 49/88").
    Verified: web + iOS tier buttons render; the Gold demo visibly holds the Aces back while sending
    Jacks down; lines satisfy their objectives; still assisted/unscored.
57. "Show me how to win" should NOT auto-start. The demo now opens in a READY state (paused, no
    timer) showing Next / Start / Stop; Start begins auto-play and the button becomes Pause; pausing
    makes it Resume; Next still steps one move at a time (even before Start). New `demoStarted` flag
    distinguishes initial ("Start") from paused-after-play ("Resume"). Both platforms. Web verified
    end-to-end (opens ready at move 0, no auto-advance, Next steps, Start→Pause→Resume). iOS is a
    line-for-line mirror + compiles; live sim check deferred — the host CoreSimulator wedged
    (SBMainWorkspace launch denial affecting even a fresh clean sim while Safari launches; a parallel
    session is running its own sim, so I avoided a shared-service restart).
58. Deep review of App Store shipping readiness + implement. Ran two audits (iOS/App-Store readiness
    + test coverage). Created rollback tag `pre-ship-prep`; documented the plan/status in
    `docs/shipping-readiness.md`. Implemented: (B1, blocker) `DebugFlags.memoryHUD=false` so the debug
    MEM/PEAK overlay doesn't ship; (F2) an About/copyright screen (app name + version + © line) on the
    iOS How-to-play and the web rules panel; (F1) iOS landscape — enabled landscape orientations and
    made the board scroll + centre in landscape (card size capped) while portrait stays byte-identical;
    (F4) regression tests — `tests/solutions.test.mjs` replays every baked "Show me how to win" line and
    asserts win+objective (366 seeds), and `tests/ios-parity.test.mjs` adds 10 Swift drift guards
    pinning the iOS port's parity-critical logic (deal RNG, calendar, daily generator, checkers,
    mergeTiers/streaks, once-only win gate, applyDemoToken) — closing the "iOS has zero drift guards"
    gap. 67 tests green. Owner action items (Support/Privacy URLs, contact email, real 17/18-device
    testing) and the on-device landscape screenshot (sim wedged) are tracked in the doc. Review loop:
    converged round 2 — caught a real landscape ScrollView-vs-drag gesture conflict (fixed by a
    no-scroll fit-to-height layout that keeps portrait's exact drag mechanics) + tightened two weak
    tests; one documented landscape known-minor (long-column clipping on small phones). Published an
    owner-facing shipping-status page (Artifact). 67 tests green.
59. Restart the simulator (dedicated instance, no conflict with the parallel session) and verify
    landscape on-device. Cleared the CoreSimulator wedge at the device level (shut down my sims,
    fresh dedicated Causeway-Dev) without touching the other session. Then, from the on-device view,
    two follow-ups the user asked for: (a) redesign landscape as a SIDE-BY-SIDE layout — foundations
    (left) · tableau (middle, full height) · free cells (right) — so the tableau's top cards are no
    longer hidden under an upper row; (b) swap free cells ↔ foundations left/right in BOTH orientations
    (foundations left, free cells right) for MobilityWare-FreeCell muscle memory. Reuses the existing
    drag atoms (drop zones in "board" space, layout-agnostic). Verified both orientations on-device
    (portrait smart-move to the now-left foundation; landscape tableau tops fully visible). Review loop
    converged: drag/z-order confirmed sound by construction; fixed a landscape height-budget minor
    (account for the 2-row toolbar + daily HUD bar) + a stale comment. 67 tests green.
60. From real device play (3 screenshots): (A) show an "on-track" indicator in the live objectives HUD
    as soon as a Silver/Gold objective is GUARANTEED just by finishing the deal — not only at the win
    overlay. Added `objSecured(obj, up, down, t)` (web `index.html` + iOS `Daily.swift`): an achievement
    objective is "secured" once its locked-in board condition holds (all four Kings down for
    kings-first / suits-top-down / down-openers-20-within-20; all Aces up for aces-first; all Jacks down
    for jacks-down-first; ≥3 whole suits home for suit-sprint) and it isn't already violated. The HUD's
    live state now returns 'ok' (green ✓) for a secured objective mid-attempt, not just at win; budget
    objectives (moves/no-undo/cells) stay '·' until the deal is actually done, since they can still be
    blown. (B) The calendar Flawless 🌟 no longer overlaps the date — moved from an absolute top-right
    corner overlay into the day-cell's marker slot (replacing the tier dots, since flawless implies all
    three). Both platforms mirrored; parity drift-guards keep the Swift `objSecured` pinned. Verified on
    web (HUD DOM shows 🥈✓/🥇✓ with all Kings down on Deal #10003 before winning; calendar star measured
    0px overlap with the date) and on the iOS simulator (identical challenge renders; live HUD renders).
    Review loop (skeptical pass) caught a real false-positive: suit-sprint was "secured" at just ONE suit
    home, but the objective needs each suit finished before the next starts, so one suit home doesn't
    guarantee it on every completion — proved a winning line that fails the checker; fixed to ≥3 suits
    home (only one left, no interleave possible). Also fixed an iOS calendar date-jitter (flawless star
    now reserves the same height:6 as the dots row). 67 tests green.
61. From landscape device play: "unused space at the bottom and on the sides; make the cards bigger."
    Redesigned the iOS landscape board (portrait untouched) into three columns — a narrow vertical
    button rail (left) · foundations with the free cells directly beneath them · tableau (fills the
    rest). Moving the toolbar off the top frees the full board height, and free-cells-under-foundations
    drops the across-count 15→12 (4 foundation + 8 tableau), so the tableau cards become WIDTH-bound at
    ~58pt (max for 8 columns) instead of height-bound at ~46pt. Lowered the landscape reserve floor 11→8
    so a fresh 7-card deal nearly fills the height (kills the bottom gap); columns growing past 8 shrink
    to stay on-screen rather than clip. Rail + foundations run parallel to the tableau so all three fit
    iPhone landscape's short (~393pt) height. Reuses the same card gestures + board-space drop zones
    (layout-agnostic); z-index floats a dragged run over the side columns and a dragged free-cell over
    the tableau. Verified on-device (landscape cards visibly larger + space filled; portrait unchanged).
    67 tests green. Safety tag `pre-landscape-v2`. Review loop converged in 2 rounds: round 1 caught a
    real ship-blocker (M1) — the 10-pill rail had no height bound, so on short/notched phones and on ANY
    phone while the Daily/demo HUD bar shows, the bottom controls clipped off-screen and were untappable;
    fixed by bounding the rail to a HUD-aware `landscapeBoardH` and wrapping it in a ScrollView (safe: the
    rail holds no cards, so it can't fight the card drag). Round 2 confirmed M1 closed and tightened a
    ~6-10pt chrome underestimate (subtrahend 64→72) so the rail viewport clears the home-indicator zone,
    plus enabled the scroll indicator. Deferred known-minors (pre-existing): the 30pt min-card clip on
    pathological 17+ card columns (no-scroll tableau by design); the play-driven whole-board resize when
    the tallest column crosses 8 (user-approved); a latent height-limited-device free-cell clip with no
    trigger on current iPhones. Follow-up: user confirmed the play-driven resizing looks good, and
    verified there was no leftover landscape-only lock (git tree, no commit, and the built Info.plist all
    list portrait + both landscape — the temp screenshot hack was fully reverted).
62. Bug report: earned Flawless on two non-consecutive days (Aug 12 + 14; Aug 13 played but not flawless)
    yet the summary card showed "1". Root cause: the four cards are consecutive-day STREAKS (🔥), so a
    flawless streak of 1 is technically correct (Aug 13 breaks the run) — no data loss (Aug 12's 🌟 is
    recorded). Per the user's choice, added a lifetime `total` (all days ever holding the tier) shown as a
    "N total" line between the label and "best N", so the card reads "🌟 1 / 2 total / best 1" — streak,
    count, and best run all visible. Added `total: days.length` to `streaks()` across canonical
    (tests/daily.mjs) + web (index.html) + iOS (Daily.swift StreakRun), rendered on both platforms; the
    streaks drift guard pins the unchanged return lines. Added total assertions to the streak test.
    Verified on web (Flawless → "2 total") and the iOS card layout. 67 tests green.
63. Support: user's physical iPhone was orientation-locked to landscape. Diagnosed as a STALE
    landscape-only build on the device — the temporary landscape-only pbxproj I used for rotated
    screenshots briefly touched the shared working tree; a device build/run during that window shipped
    landscape-only, and reverting the source didn't rebuild the phone. Current source is clean (both
    configs list all 3 orientations; built Info.plist confirms; no lock code). Fix without data loss:
    reinstall the new build OVER the app (Xcode Run is non-destructive to the UserDefaults container) —
    do NOT delete the app (that wipes stats). Corrected my earlier wrong "delete first" advice.
64. Feature (user asked, iCloud vs local discussed): added a LOCAL Export/Import of stats so streaks +
    solved deals aren't a single-device single-point-of-failure — no iCloud entitlements / privacy
    surface. `StatsBackup` = versioned "causeway-stats" JSON of the daily record map + wins map. New
    `DailyStore.merge` / `WinStore.merge` are NON-DESTRUCTIVE (OR-accumulate tiers, keep best time/moves)
    so importing only ever adds/keeps-better — never erases. UI: a "Backup" section at the bottom of the
    Daily screen with Export (`.fileExporter` → dated .json) + Import (`.fileImporter`, security-scoped,
    rejects non-Causeway files) + a status line. iOS-only for now; the JSON format is platform-agnostic
    so web (localStorage) could read the same files later. Verified the full round-trip on-device
    (export writes JSON to Files → import decodes + merges + reports). 67 tests green. Review loop:
    confirmed import is non-destructive for our own exports (merge is add/keep-better only; malformed/
    empty/truncated files are rejected pre-merge since synthesized Decodable throws on missing keys).
    Round 1 found a real risk for hand-edited/corrupt-but-valid files — unbounded junk keys (phantom
    days/deals) and a min()-poisoned best (moves:0) persisting irreversibly. Fixed: importStats now
    clamps daily keys to 0…todayIndex()+2 and win seeds to 1…Game.maxSeed, requires win moves/secs >0,
    drops non-positive daily moves/elapsed, and reports the actually-merged counts + any skipped
    entries. Accepted pre-existing minor (not a regression): win record merge takes min moves and min
    secs independently (also in `record()`).
65. Landscape orientation-lock support saga: user's physical iPhone was stuck landscape-only despite a
    correct committed pbxproj (all 3 orientations on both configs, device+sim Info.plist verified, no
    lock code). Root cause was MINE: my temporary landscape-only pbxproj edits (for rotated screenshots)
    raced with the user's open Xcode, which captured landscape-only into Deployment Info and persisted/
    shipped it — surviving delete + clean-build + reboot. Fixed by re-checking Portrait+Landscape L/R in
    Xcode → General → Deployment Info. Saved a memory ([[no-temp-pbxproj-edits]]) to never do throwaway
    pbxproj edits in the working tree again.
66. Ran the `qa-loop` plugin (simulator-driven UX/QA) on the iOS app. Drafted WORKFLOWS.md (12 workflows,
    novice+power personas), signed off, exploration→TESTCASES.md, then a full round-1 pass via the
    ux-tester subagent. Converged round 1: no blockers/majors, 4 minor findings. User accepted all 4;
    fixed in `5b237b4`: (1) file-picker Cancel feedback via iOS 17 onCancellation overloads; (2) "1 day/
    deal/range" singular grammar; (3) demo "Done" re-deals the seed to a playable board; (4) solve clock
    pauses while a modal sheet is open. All state under `.qa-loop/` (REPORT.md). Coverage gaps: WF-4 win
    overlay + WF-12 landscape code-reviewed only (env can't rotate the sim). Also gave the plugin author
    feedback (sampler lifecycle, finding schema, deterministic-deal seeding, convergence-ignores-minors).
66. Produce architectural documentation for both codebases (web prototype + iOS app) from a full
    review of the code, git history and docs. Wrote `docs/architecture/{overview,web-prototype,app}.md`:
    a shared overview (system context, the three-copies-plus-drift-guards strategy, shared domain
    model, build-time solver pipeline, repo map, feature-parity matrix) and a detailed doc per
    codebase (top-level architecture, module inventory with file:line citations, key flows as
    sequence diagrams, persisted-data ER diagrams, and a candid "state of the architecture" section
    covering decisions + inferred rationale, coupling/debt, cross-codebase inconsistencies and
    grep-proven vestigial code). 20 Mermaid diagrams, all validated and each ≤11 nodes; module
    inventory cross-checked against the directory tree. Verified independently rather than inferred:
    the two baked JSON files are byte-identical between `data/` and the iOS bundle; **274 of 366**
    pool records violate the `par = min(unconstrained, constraintPar)` invariant in
    `solve.mjs:186-188` (they predate that change and append-only preserves them), so the `moves`
    Silver is up to ~14% looser than intended; `suit-sprint` is supported by only 4 seeds and
    selected on 3 days; `.card.hintsrc` (web) and `Theme.cardCream`/`cardTintBottom`/`background`,
    `Suit.glyph`, `MemoryMonitor.stop()` (iOS) have zero callers; the `.unreadable` corruption-backup
    keys are written but never read; and the live-HUD checkers (`objViolated`/`objSecured`) are a
    third, entirely unguarded copy of the objective semantics on both platforms. Docs-only change;
    67 tests still green.
67. Fix the documentation drift found in the architecture review. Four documents described a system
    that no longer existed; all corrected against verified source, preserving the original design
    intent and adding "As built" notes where the shipped behaviour diverged from the plan:
    (a) root `README.md` — the Controls section still described the REMOVED tap-to-select /
    double-tap model (now tap = smart-move, drag = place); added the missing Daily Challenges
    section, the `file://`-disables-Daily caveat, and the full repo layout.
    (b) `ios/README.md` — "iPhone-only, portrait" (landscape shipped), "smart double-tap", a project
    layout predating the whole daily feature + memory work (7 files and 2 bundled JSONs missing),
    2 UserDefaults keys documented where 5 live ones exist, and an imprecise "no URLs" privacy claim
    (the app does handle picker-supplied `file://` URLs for stats backup); added the backup feature,
    the no-XCTest note, and the M7 accessibility caveat.
    (c) `docs/solver.md` — claimed in two places that the `rules.mjs ↔ index.html` drift guard did
    not exist yet (it does, `tests/solver.test.mjs:24-47`); documented the shipped-`par` caveat
    (274/366 records predate the min() change, loosening the `moves` cap ~14%) and the real pool
    size + uneven objective supply (`suit-sprint` on 4 seeds / 3 days).
    (d) `docs/daily-challenges.md` — still said "not yet implemented"; marked which 11 of the 14
    catalogued objectives shipped (time-cap and manual-win never built, `empty-column` deliberately
    dropped as vacuous and pinned absent by a test), corrected the generator description (frozen
    `mulberry32((0x9e3779b9 ^ (dayIndex+1)) >>> 0)`, day→pool index rather than a draw, no
    family rotation), the record shape (`flawless` + `moves`/`elapsed`), four streaks with `total`,
    and resolved §12 open items + §13 roadmap. Also updated the architecture docs' own
    "documentation has drifted" findings, which this task made stale. Docs-only; 67 tests green.
68. `/qa-loop max 3 rounds, use 3 testers` — second simulator-driven UX/QA pass, on `342e3c0`.
    Continued the round-1 ledger (rounds 2..4 budgeted). Provisioned 3 worker simulators and ran a
    full pass in two waves (WF-1..3 / WF-5..7 / WF-9..11, then WF-4+P-A/P-B / WF-8+P-C / WF-12),
    followed by a single uncontended perf lane with the NFR sampler attached: **47/47 test cases
    run**, 45 passed, 1 failed, 1 blocked. Round-1's three fixes (`5b237b4`) all verified fixed on
    screen. Found 11 new findings — 2 majors (demo progress banks a real win in `causeway.wins`,
    reproduced by two testers; portrait tall columns run offscreen and become untappable at 15
    cards), 7 auto minors, and 4 proposals. Perf lane clean (no leak across 12 undo + 15 New game +
    15 Replay cycles; idle CPU ≤1%; only stall is the cold-launch `UIDocumentPicker` warm-up).
    Two harness corrections worth keeping: landscape rotation **is** drivable via
    `XCUIDevice.shared.orientation` from an XCUITest driver (round 1 wrongly recorded it as
    impossible, so WF-12 had been code-reviewed only), and the round-1 fixture note hard-coded the
    wrong daily deal (#10,003 = dayIndex 2; today is #10,004) — WORKFLOWS.md now derives it and
    carries a real Fixture policy section. The loop aborted with `thrashing`; diagnosed as a **false
    positive** (0 reopened, 0 recurring regions — only the `net <= 0 for two rounds` signal fired,
    and `net = closed - new` makes every productive discovery round negative). No implementer or
    fix-review dispatch has run inside this loop yet; both majors are open.
69. `While in demo mode the user should not be able to move cards … implement it as well as any
    other remaining major findings from the qa loop that ended in thrashing, then run the review
    loop and provide any feedback on the review loop plugin` — fixed both open round-2 majors.
    (1) Demo-win exploit: input was already locked while `demoing`; the real hole was the demo
    bar's mid-demo **Stop**, which left the app's solution moves on a playable board. Stop now
    routes through `restartDeal()` like Done, so leaving a demo always lands on a fresh board of
    the same seed — a demo-touched board can never be played or scored, and no win-tainting /
    best-time reinterpretation is needed. Defense in depth: `undo()` no-ops while `demoing`, and
    `canDrag` gates on `!game.demoing` so cards don't even lift. (2) Portrait tall-column clip
    (also closes backlog M3): per-column fan compression against the measured board height
    (greedy `GeometryReader` in portrait, `landscapeBoardH` backstop in landscape) — only the
    overflowing column tightens, card size never changes, no per-move size thrash. Build green,
    67 Node tests green. Then ran the review loop on the change.
70. `Make the RL-1 through RL-4 fixes. Re RL-4 it probably makes sense to keep the card sizes the
    same across foundation, free cells, and the main game area when it rescales` — fixed all four
    review-loop residuals. RL-4 per the user's call: replaced the tableau-only shrink with a
    whole-board uniform card size — `portraitFitCardW` solves the shared width from an outer
    GeometryReader spanning the upper row + tableau (chrome above is card-size-independent, so
    no feedback loop); the freed upper-row height raises the shrink threshold (4.7" phone: 15
    cards vs 13) and one size renders everywhere. RL-3 folded in (centre only when shrunk).
    RL-1/RL-2: parity pins re-anchored to contiguous case bodies (mutation-verified) and the iOS
    finishDemo/demoAdvance guards pinned. Build green, 68 tests green. Review loop re-run on the
    change.
71. `Added a UI Testing Bundle target and set emit_regression_tests to true … Let's set the
    regression tests build target aside. We will figure it out later` — verified the qa-loop flag
    (true, kept) but found the Xcode target add never persisted: Xcode wrote the scheme testable +
    template files, yet project.pbxproj was never re-serialized (zero CausewayUITests references;
    xcodebuild -list shows only the app target) even after builds — strong evidence for the M8
    hand-authored-pbxproj concern. Confirmed build-for-testing still succeeds despite the dangling
    scheme testable, so the state is harmless; parked per user decision as backlog UITEST-target
    (with resume steps) and committed the flag + orphan files as-is.
72. *(qa-loop round 1 fix pass, agent-driven)* — addressed all 11 open auto-routed findings from
    `.qa-loop/briefs/round-1-open-auto.json` on build 6ee255b. Majors: portrait daily HUD now
    stacks/wraps the three objective chips via `ViewThatFits` (Silver/Gold fully readable); the
    Daily demo pills confirm before discarding an in-progress daily attempt (no restore-after-demo,
    per the banked-line trap; web `confirm()` mirror); the deal alert dropped its redundant
    `Random` action (dup of New game) so Play/Cancel render side-by-side above the landscape
    keyboard. Minors: column drop frames extend to the tableau bottom (web mirror: all `.col`
    hit boxes get the tallest column's height); unmovable-card touches get a shake refusal cue
    (`ShakeEffect`, never fires on movable-card taps); Moves/Time show "—" while a demo runs or
    its banner shows (web mirror); calendar weekday `ForEach` id → positional; Auto-finish cycles
    Ask→Off→On on both platforms (On never a pass-through, flip-to-On affordance kept per trap);
    rail Undo readable when disabled (dropped `.buttonStyle(.plain)`); Export/Import taps paint
    "Opening Files…" before the UIDocumentPicker warm-up stall; accessibility identifiers added
    (cards `card.<S><rank>` + VoiceOver labels, `stat.*`, `demo.*`, `toolbar.*`, `daily.*`).
    Build green, 68 Node tests green.
72. `Run a qa loop, max 3 rounds, use 3 testers, give me feedback on this latest version of the
    qa-loop plugin when you are done` — loop 3 CONVERGED at round 3 on a full 51-case pass
    (previous state archived; WORKFLOWS refreshed for the changed demo-exit/tall-column/daily
    contracts). Round 1 full pass: 13 findings (3 majors). Implementer fixed all 11 auto-routed
    in 5447237 (HUD wrap, daily-attempt confirm, two-action deal alert, drop zones to tableau
    bottom, buried-card shake, demo header dashes, calendar ids, Ask→Off→On auto-finish cycle,
    rail pill styling, "Opening Files…" acknowledgement, full accessibility-identifier pass);
    fix review 11/11 sound. Round 2 targeted verified all 10 on screen → full_pass_required;
    round 3 full pass confirmed convergence. Both prior-loop majors (demo banking, tall-column
    clip) re-confirmed dead all three rounds. 4 regression XCUITests emitted skip-guarded into
    the parked CausewayUITests dir (e02161a, 2b66b93), retrofitted to the new a11y ids. Open:
    4 minors (re-win clock pair w/ metric-integrity trap, deal-number grouping, a11y gaps) +
    3 proposals (challenge-mode-dropped-after-demo major, new-game confirm, debug date
    override). Perf clean at baselines. Plugin feedback delivered (implemented_rounds fixed the
    thrashing false positive; merge_coverage persona-collapse bug found; shared-/tmp worker
    collision; regression writer blind to archived fixes).
68. "XCUI tests won't build/run — as an exception, edit `project.pbxproj` to make it work."
    Root cause: Xcode never re-serialized the project when the UI test target was added in the GUI,
    so BOTH schemes pointed at blueprint id `C761C3703031FA7B00429DAC` that no target defined
    (BACKLOG "UITEST-target"). Wrote the target into the pbxproj directly, reusing that same id so
    no scheme edits were needed: synchronized root group for `CausewayUITests/`, native target with
    `productType = com.apple.product-type.bundle.ui-testing`, Sources/Frameworks/Resources phases,
    `PBXTargetDependency` + `PBXContainerItemProxy` on the app, Debug+Release configs with
    `TEST_TARGET_NAME = Causeway`, and `TargetAttributes.TestTargetID`. First `test` run then failed
    with `UITargetAppPath should be provided` — the *app* target had no `productReference` (the M8
    hand-authored quirk, which the backlog item had predicted); added a `PBXFileReference` for
    `Causeway.app` and wired it up. Diff is purely additive (134 insertions, 0 deletions).
    Then unparked the four QA-loop regression tests (removed the `XCTSkipIf(true, …)` lines). Three
    passed immediately; `landscape-disabled-undo` failed, so I measured real pixels via a temporary
    diagnostic before touching anything: disabled Undo 0.0725 vs enabled same-style Replay 0.3088 in
    landscape, and 0.1293 vs 0.3718 in portrait (known-good). The app fix was intact — the test's
    absolute `> 0.10` threshold was simply unreachable, because disabled pills are `.opacity(0.4)`
    and the P95–P5 metric is diluted by a full-width rail pill's empty area. Rewrote the assertion as
    contrast *relative* to an enabled pill of the same style in the same orientation (ratio 0.235
    measured; a blank capsule ⇒ ~0), with a guard-the-guard check on the reference. All 6 XCUITests
    pass; app builds Debug+Release; 68 Node tests green. Updated the docs that claimed no test target
    existed (ios/README, tests/README, both architecture docs, .qa-loop REPORT + WORKFLOWS) and
    marked UITEST-target resolved / half of M8 closed.
69. "Come up with more ideas for daily challenges — add variety. Don't make changes yet; write a
    proposal." Wrote `docs/daily-objectives-proposal.md`. Grounded every claim in measurements over
    the 366 baked winning lines rather than guesses. Key findings: (a) the catalogue is lopsided —
    five of the six Golds are foundation-ORDERING variants (76% of Gold days) and the tableau is
    completely unmeasured; (b) **a new objective must be certified/supports-gated, never universal**
    — empirically, appending an id to `GOLD` or `SILVER_CERTIFIED` changes 0/366 days, but appending
    to `SILVER_UNIVERSAL` rewrites **123/366**, because universal ids are concat'd wholesale while
    certified ones are `.filter(supports)`-gated; (c) consequently new objectives can only debut on
    newly-appended seeds — and the calendar runs out 2027-08-12 anyway, so the required pool
    extension is the natural zero-migration moment. Proposed 9 objectives in 4 families, each with
    measured feasibility: the split point (0/366 split all-suits 7/8; 4/366 build a suit from one
    end), tempo (26th card lands at median move 59; 15/366 get all Aces up by move 20), peak cell
    occupancy (3 in ALL 366 lines — orthogonal to cumulative use), and move shape (52/366 never
    supermove; 15/366 move a run of 5+). Rejected 4 ideas WITH data — `strong-finish` is vacuous
    (last 13 cards take exactly 13 moves, median and min), the `empty-column` rescue is still nearly
    free (349/366 qualify even at ≥35 cards remaining), `rainbow` is 0/366 and likely infeasible.
    Also proposed retiring `suit-sprint` for future seeds (supported by 4/366, picked 3 days/year),
    a reusable feasibility-probe tool, and an optional "freeze history in a lookup table" refactor
    that would decouple the frozen arrays from recorded history. No code changed; 68 tests green.
70. Four more daily-objective ideas, added to the proposal (still no code): (a) fill the free cells
    with a specific set of card values at some point; (b) build a foundation completely in reverse
    (K→A) or completely straight up (A→K); (c) send an unbroken streak of N cards of one suit home;
    (d) send N cards of one suit home before any other card. Measured all four against the 366 baked
    lines. Findings that changed the shape of the proposal: **(b) is asymmetric** — a suit built
    A→K happens 4/1464 naturally, K→A **0/1464** (you must withhold that suit's Ace for twelve
    sends), and the maximal form is legal and striking: winning with `up[s]=13, down[s]=14` still
    satisfies `down == up+1`, so "never use a down foundation" (and its mirror) are valid, trivially
    gateable objectives. **(c) has the cleanest difficulty dial found** — unbroken same-suit run
    N≥5 54%, N≥6 29%, N≥8 6%, N≥13 0% → N=6 Silver, N=8 Gold. **(d) supersedes `suit-sprint`**:
    suit-sprint *is* (d) at N=13, which is exactly why it has 4/366 support and appears 3 days a
    year; at N=4 the same idea gets ~11% natural support, reviving a dead family. **(a) only works
    if the set is specific** — all three cells full happens in 366/366 lines (vacuous) and a matching
    pair in 264/366 (too easy), but three consecutive ranks is 74/366 (20%, Silver) and three of a
    kind 8/366 (2%, Gold); telemetry is cheaper than feared (median 7 distinct rank-triples per game,
    ~63 bytes). Proposal now has 6 families / ~16 objectives, 6 [DECIDE] points, and a rollout that
    front-loads the one-line solver gates (B3/B4) because they answer the most interesting
    feasibility question for the least work. 68 tests green.
71. "Validate the ideas assuming auto-play and auto-finish are OFF — incompatibility with automation
    shouldn't force us to discard ideas." This exposed a real flaw in my measurements: every
    "natural rate" I'd quoted came from the baked solver lines, and `solve.mjs` runs an `autoSafe`
    macro that force-sends provably-safe cards home — i.e. **auto-play was baked into every number**,
    and those numbers measured *incidental* occurrence on move-optimal unconstrained play, not
    achievability. Re-measured properly and **reversed two conclusions in each direction**:
    (a) RESCUED — `no-down-foundation` wins on 6/8 sampled seeds and `no-up-foundation` on ≥4/8
    (the rest budget-limited, not infeasible: seed 10004 flipped unknown→WIN par 118 when the budget
    went 400k→1.2M). Their 0/366 incidental rate was pure artifact; these are now among the
    strongest ideas. (b) DOWNGRADED — the free-cell configs are reachable in 3 moves (E1, 6/6 seeds)
    and 4–6 moves (E2, 5/6) when *targeted*, so E1 is recommended dropped and E2's difficulty lives
    entirely in the unmeasured "win from there". Also established that auto-play needn't constrain
    the design at all: `autoSafe` is gated by `constraint.allowFoundation` so certification stays
    sound, and auto-play is nearly inert in the opening (`isSafeAutoplay` needs foundations built),
    which is why the cell probes hit identical depth with it on and off. Corrected the ~10% support
    bar to apply to CERTIFIED support only (applying it to incidental rates would have killed
    B3/B4), withdrew the `rainbow` rejection as based on invalid evidence, and added a solver-cost
    table: the constraint API is memoryless, so state-derivable gates (A1/A2/B1–B4/C2/F1) are cheap,
    while C1 and `rainbow` need history in the node key and D/E/F2 need reach-and-win. Cost signal
    recorded: B4 runs ~24–30s/seed at 1.2M and a 3M budget exhausted an 8GB heap. **Found a UX
    parity gap**: the design doc made showing automation state a UI obligation "so it isn't a hidden
    trap"; web's daily card shows `Your call: [Auto-play][Auto-finish]` but iOS `DailyView` has no
    equivalent — so on the shipping platform the player gets no hint. Still proposal-only; 68 green.
72. Three things: (a) "What is B4?" — the doc used opaque IDs before defining them, so added a §0
    index table naming all 15 proposed objectives up front (B4 = `no-up-foundation`, win building
    every suit K→A, never touching an up foundation). (b) DECIDED: it's fine to give players no hint
    about how auto-play/auto-finish affect a particular deal — figuring that out is part of the
    challenge. Recorded as overruling the original design's "UI obligation" clause; the live HUD
    already fails the objective the instant it breaks, and a restart is free. Auto-play hostility is
    no longer a mark against any objective. (c) New implementation plan: backfill 2026-08-05..08-11
    as a playtest sandbox, play a few days, iterate, then commit to future dates. Worked out the
    mechanics: those dates are **negative day indices (−7…−1)** because the epoch is 2026-08-12, and
    that turns out to be the ideal shape — every freeze constraint in §2 applies to days ≥0 only, so
    backfilling below the epoch touches no existing seed, index, or RNG draw: **zero history
    rewrite** (vs. moving the epoch back, which would re-roll every existing day's objectives).
    Gives a clean rule: days ≥0 frozen, days <0 mutable sandbox. Streaks need no work — the
    backwards run-scan walks into negatives for free. Catalogued the 8 guard sites that assume
    non-negative days, and proposed a separate `preSeeds` array so sandbox data can never shift live
    data. Two measured constraints found: **Gold is fully steerable by seed choice, Silver is not** —
    `SILVER_UNIVERSAL` permanently occupies indices 0–1, so a low RNG draw can never reach a
    certified Silver, and only 3 of the 7 requested days (08-06/07/10) can carry one; recommended
    extending back to 08-01 for 7 of 11 days, or adding sandbox-only forceSilver/forceGold overrides
    (safe precisely because the sandbox is outside the frozen region). Also flagged that the
    calendar renders **the current month only** with no month navigation on either platform, so the
    backfilled August days are reachable only during August 2026. Still proposal-only; 68 green.
73. "Run the solver on randomly-selected deals above 10,000,000 until you have seven certified deals
    with bronze/silver/gold showcasing variety. Backfill seven dates before 8/12/2026. Go."
    **Shipped.** Sampled 22 random seeds in 10,000,001–999,999,999 and certified **22/22** (~10–20s
    each). Searched assignments of seed→day-slot to maximise variety, since the RNG draw is fixed per
    day and the seed's `supports` steer the pick: landed **5/5 distinct Silvers** (all three certified
    ones included) and **5/6 Golds** — only `suit-sprint` missing, as no candidate supports it (~1%
    rate; the objective §6 recommends retiring). Backfilled 2026-08-05..08-11 = day indices −7..−1 via
    a new `preSeeds` array (`preSeeds[i]` = day −(i+1)) in the pool file, wired through canonical
    `tests/daily.mjs`, web, and Swift, plus the calendar/playChallenge guards on both platforms.
    Baked + validated bronze and gold lines for all 7 (and silver for the 3 certified-Silver days).
    **Verified history intact**: all 366 existing days byte-identical before/after, `pool.seeds`
    unchanged, all 366 original solution entries untouched. Two blockers found and fixed en route:
    (a) `Game.deal(seed:)` clamped every deal to `maxSeed = 1_000_000`, so a >10M seed would have
    dealt a DIFFERENT board on iOS than web — split into `maxSeed` (max the player may type) vs
    `maxValidSeed` (UInt32, what the RNG accepts, matching web's `>>>0`); (b) **pre-existing: the iOS
    calendar hid days 1–6 of every month.** Proved pre-existing by rebuilding the unmodified view.
    Cause: the month grid is one LazyVGrid with three sibling ForEach blocks sharing an identity
    space — the weekday header used `id: \.offset` (0…6) and the day cells `id: \.self` (1…31), so
    ids 1–6 collided and SwiftUI collapsed them. Itself a regression from the earlier fix for the
    duplicate "T"/"S" header letters. Fixed with prefixed string ids (`hdr-`/`pad-`/`day-`).
    Verified on web and on-device (Aug 5 → Deal #333,604,570, correct objectives, calendar shows
    1–31 with 5–11 playable). 70 node tests + 10 XCUI tests green.
74. "Still not enough variety — I want examples of A1 (split the stacks exactly halfway), A2, B3, B4,
    F1, F2." Implemented **six new objective types** end to end (canonical + web + Swift + solver +
    drift guards) and rebuilt the sandbox around them:
    A1 `split-even` (every suit A-7 up / 8-K down), A2 `down-heavy` (>=8 of every suit from the King
    end), B3 `no-down-foundation` (win using only up foundations), B4 `no-up-foundation` (win building
    every suit K->A), F1 `no-supermoves` (one card at a time), F2 `one-big-move` (relocate a run of 5+).
    Two new solver mechanisms were needed: `constraint.maxRun` gating supermove generation in
    `legalMoves` (F1), and a second existential latch alongside `wantDownOpen` for F2 (the node key
    grows a `big` flag). A1/A2/B3/B4 are pure `allowFoundation` gates. Verified soundness by replaying
    each gated line: split-even -> up=[7,7,7,7], no-down-foundation -> down=[0,0,0,0],
    no-up-foundation -> up=[0,0,0,0], no-supermoves -> maxRun=1. F1/F2 needed new telemetry
    (`maxRunMoved`) threaded through both platforms — Telemetry struct, snapshot/undo rollback, both
    multi-card move paths, and the HUD's Attempt reconstruction. Steered the objective assignment by
    exploiting the fixed per-day RNG draw: giving a seed exactly ONE certified gold forces
    goldPool=[that], len 1, pick index 0 — so each named objective lands deterministically. Hunted
    seeds >10M for the specific combos and got all four day-slots in **6 seeds**. Final sandbox:
    Aug 5 = A1, Aug 6 = A2 + B3, Aug 7 = F1 + B4, Aug 8 = F2, Aug 9-11 keep existing objectives for
    contrast. Verified all 366 frozen days are byte-identical (the array appends and sandbox edits
    changed 0). Two guard failures caught real gaps and were fixed rather than silenced: the iOS
    frozen-pool pins needed updating for the appends, and BOTH `replay()` reconstructions
    (solutions.test.mjs and build-solutions.mjs) failed to emit `maxRunMoved`, so an F1/F2 line could
    never validate. 71 node tests green; verified on web and on device.

    **Verification.** All four new-objective sandbox days render correctly on device (Aug 5 A1,
    Aug 6 A2+B3, Aug 7 F1+B4, Aug 8 F2), the two-line labels wrap without truncating, and the
    "show me how to win" row correctly offers Silver only on the three certified-Silver days —
    matching §8.3's prediction of exactly which days can carry one. All 10 XCUITests pass. Live-HUD
    behaviour spot-checked on web: `one-big-move` secures at maxRunMoved>=5 and is never violated at
    any value; `no-supermoves` violates at 2 but not 1; `no-up-foundation` violates on the first up
    send but not on a down send. Also fixed drift the change introduced in `docs/architecture/`:
    the Telemetry ER diagrams on all three pages were missing `maxRunMoved`, the web page pinned the
    old `telem` initialiser, and the objective catalogue still said "11 implemented ids" (now 17).
75. "Reflect on token usage so far including the review loop; suggest reductions — plus a dedicated
    summary for the review-loop agent." Then: "Create a .md with the analysis specific to the review
    loop (and qa loop) and recommendations." Measured it from the raw session transcripts rather
    than estimating: dedupe usage by `requestId`, weight `input×1 + cache_read×0.1 + cache_write×2 +
    output×5`, and match all 98 subagent transcripts back to their `subagent_type` by normalising the
    dispatching `Agent` prompt (98/98 matched). Findings: 243M effective tokens across the project;
    this session alone is 187M, of which 63% is re-reading context at a mean of 497K over 2,387
    requests. Loop-specific: the review loop cost 8.40M of subagent tokens for 26 findings (323K
    each) while the QA loop cost 39.87M for 18 (2.21M each) — `qa-loop:ux-tester` alone is 77% of all
    loop spend, at 97 requests and a 173K median context per agent versus the review agents' 36-41K.
    **A mid-analysis measurement retracted my own earlier recommendation**: I had proposed keeping the
    raw diff out of the orchestrator's context, but diffs averaged 271 tokens across 48 calls, so the
    change would save nothing — dropped it and said so in the doc. The real review-loop lever is
    ambient context: the identical plumbing request cost 16.6K in a focused session and 55.3K in this
    one, a measured 3.3x for no code change. Also corrected an image-sizing error mid-analysis
    (base64 length in the transcript overstates image token cost by 30-70x), which had briefly made
    four QA evidence PNGs look like 470K tokens instead of ~6K. Written up in
    `docs/loop-token-usage.md`.

76. QA loop 3, round 1 — implementer pass over the 18 open auto-routed findings from the 57-case
    persona sweep (1 blocker, 5 major, 12 minor). Fixed 15, argued 2 down, and rewrote the two
    stale test cases the fixes invalidate (TC-7.3/7.4, TC-11.4). The blocker was the app eating its
    own backup: `importStats` sanitized daily keys to `0...today+2` and win seeds to
    `1...Game.maxSeed`, but pre-epoch sandbox days are NEGATIVE indices and their deals use seeds
    above 100,000,000 — so an untouched export→import lost a real win plus a whole day's four tiers
    behind the message "Skipped 2 invalid entries", under a UI promising it never erases progress.
    The fix widens the bounds to what the app can actually produce rather than deleting the
    sanitizer (which is what makes the hand-edited-backup case pass). Three separate UX reports
    turned out to be one shape — the Daily sheet confirmed before discarding a live game on the
    demo path only, and only for a daily attempt — so they were fixed together behind one
    `PendingAction`, with copy that does not promise a casual game is replayable and a guard that
    stays off at move 0 and on a solved board. **The one I pushed back on**: WF-13 wanted
    `telem.maxRunMoved` to stop rolling back on undo so the Gold "one big move" check would be
    irreversible as its own comment claimed. Declined with numbers: the same field feeds
    `no-supermoves` with the opposite polarity, so a one-way counter would make an *undone* 2-card
    move permanently fail Silver; the win-time checker reads the rolled-back field on both
    platforms, so the reverting chip is the truthful prediction of the grade; and every other
    `objSecured` case un-secures on undo too. The comment was the bug, and it was wrong in
    `index.html` as well.

77. Run the QA loop (max 3 rounds, 2 testers), measure token usage, and write up feedback plus
    suggestions for reducing it. Round 0 explored the new sandbox objectives, round 1 ran a full
    57-case pass across 15 chunks on two simulators plus a solo perf lane, the implementer fixed 17
    of 18 auto-routed findings and argued one down, and the fix reviewer upheld the decline. Round 2
    was stopped by hand after 2 of 15 chunks. Measured from the raw transcripts: 23.5M effective
    subagent tokens for 29 findings — 811K per finding against 2.21M in the previous loop, and 9.3K
    per subagent request against 14.0K. Nearly all of that came from one change made before the run
    started: `HARNESS_NOTES.md` had grown to 86 KB of obsolete driver lore that every tester paid
    for on every dispatch, and cutting it to 6.9 KB is the whole delta. It regrew to 22 KB in one
    round, which is why recommendation #1 is to cap and rotate it automatically. Write-up in
    `docs/qa-loop-feedback.md`; the loop is parked with a banner on its report saying what is and
    is not verified.

78. Add more Daily Challenge variety: two new objective shapes by name (send every <rank> home from
    the Ace end and every <higher rank> from the King end before anything else; get all four
    <rank>s home in <N> moves or fewer), plus ideas of my own; nuke all existing challenges and
    challenge history; put the deal-seed cap back to 1,000,000 and draw challenge deals from
    500,001-1,000,000; seed exactly August 2026 with the most varied set the generator can find,
    casting a wide net and varying every tunable parameter. Turned the whole catalogue into
    parameterised families (13 ids, hundreds of distinct challenges) so that "vary the parameter" is
    the design rather than a special case, and every previously shipped objective became a parameter
    of one of them. Replaced the per-day RNG with an offline generator that certifies a wide net of
    candidate seeds against all 63 (family, parameter) variants in parallel and then fills the month
    greedily for maximum variety — the choice is baked per day, so `dailyChallenge` is now a table
    lookup. Moved the epoch to 2026-08-01, deleted the pre-epoch sandbox, and collapsed
    `maxValidSeed` back into a single `maxSeed` now that no challenge seed exceeds it.

79. Build a corpus for evaluating AI reviewer agents across models: suggest a few real diffs from
    this repo and write down what a good review verdict looks like for each. Picked five commits
    whose answer keys are *verifiable from later history* rather than from my own judgement:
    `b50087a` (the `objSecured` suit-sprint false positive, fixed in `f96c06b`), `ebd31df` (stats
    Import with no range validation, hardened in `0874c5c`), `5b237b4` (the clock-pause-in-sheets
    exploit, reverted wholesale in `2796867`), `6a49b75` (the pre-epoch sandbox, whose two blockers
    live in files the diff never touches), and `8a6bcd6` as a near-clean control that scores
    restraint instead of recall. Re-derived every finding from the diffs rather than trusting the
    commit prose, and confirmed one still-unfixed bug in the process: at `6a49b75` the web
    `playChallenge` widened its guard to admit negative day indices but still read
    `dailyPool[day].seed`, so every sandbox day threw a `TypeError` on web while working on iOS —
    under a commit message that says "Verified on web and on device". It was never fixed, only
    obsoleted when the August-2026 recut deleted the sandbox. Each case carries base/head SHAs, a
    throwaway-clone command that hides the answer key, the must-find/credit split, the
    false-positive traps (the ones that read like bugs and are not), and an inverted rubric for the
    control. Write-up in `causeway-reviewer-evaluation-examples.md`.

80. Consider requiring that every challenge deal be solvable *flawlessly* — one line that satisfies
    both the Silver and the Gold — and say how much variety that would cost. Measured it rather than
    argued it: composed the two objective gates into a joint constraint (∧ of `allowFoundation`, min
    of the cell/run budgets, ∨ of the existential goals, plus a move-cap prune so a `moves` Silver is
    searched instead of checked afterwards) and ran it over the shipped month — 24 of 31 days
    certify, 3 are *provably* impossible (`suit-sprint` × `suit-balance`, `suit-sprint` ×
    `rank-rush`, `big-move{5}` × `max-run{2}` — including today's, Aug 30), 4 more went uncertified
    within budget. Then re-ran the month generator with the gate wired into the greedy pick: 31 days,
    13 families, 52 distinct challenges — *identical* variety to the shipped month, 29 of its 31
    seeds kept — for 111 extra joint solves. Also checked the cheap repair: every impossible day has
    3-8 alternative Silvers on the same seed and Gold. Wrote the finding up in `docs/solver.md` §7.7
    and `docs/daily-challenges.md` §12; no code change, because enforcing it regenerates the month
    and rewrites daily history.

81. Nuke August and its history, backfill it and add September so both months are populated and
    certified; add a "How to win flawless" button; propose a design for recognising a challenge
    solved on the day it posted, and say whether it should ship with the rest. Shipped all three as
    one release in ordered commits. The solver gained `certifyFlawless` (compose both gates, take
    the tighter budgets, OR the existential latches, and prune on `g > moveCap` so a `moves` Silver
    is searched rather than checked afterwards) plus a `contradiction()` table that rejects the
    provably impossible pairings without search; the month builder now gates every greedy pick on a
    certified flawless line and blacklists what fails. `build-solutions.mjs` bakes that same
    certified line as the v3 `flawless` tier, which is what the new 🌟 button demonstrates. For the
    third piece I proposed ⏰ Same-day as an axis orthogonal to the tiers — it records WHEN, not how
    well — with a midnight grace for an attempt begun before it, a deliberately strict streak (🔥
    Play stays catch-up-repairable, ⏰ cannot be), and no countdown timer; and argued for shipping it
    in the same release, because the record schema was being wiped anyway and no `onTime` flag can
    ever be reconstructed for days played before it exists.

82. Why did the 🥈 chip stay `·` on Aug 29 when 4-K was already home in all four down foundations,
    and (mid-task) start tracking the moves of every win and show them on the challenge screen.
    The chip: `end-bias` fell through `objSecured`'s `default: false`, so a tier that a monotone
    counter had already locked in never went green until the win awarded it anyway — cosmetic, but
    it made the day's Silver look unearned for the whole endgame. Fixed in both mirrors, and
    `objViolated`/`objSecured` (which had lived ONLY in index.html and Daily.swift, untested) were
    ported into `tests/daily.mjs` as the canonical copy so the behaviour is covered and both mirrors
    are pinned to it. The enhancement: every win now logs one `{moves, elapsed}` run into the day's
    record (`mergeRuns` — dedupes on the pair so a re-imported backup can't inflate the log, keeps
    the most recent 20, while the day's best-of moves/time stay separate and untrimmed), and a
    solved day card reads "Cleared 3× · best 96 moves in 5:52 · par 84" over "Moves each run:
    118 · 106 · 96". Par reaches the UI for the first time here. Records banked before the log
    decode with an empty one and simply show their best.

83. Run the review loop over everything the QA loop shipped, and collect token-usage data and
    feedback for the loop itself. Scope `b2ce1a4..HEAD` — 12 QA-loop fix commits, 8 XCUITests and
    the two features on top, 3,493 lines. Seed + 2 rounds + closeout, 7 dispatches, 17 findings
    (1 blocker, 9 major, 7 minor), stopped at `thrashing_soft` by my call rather than converging.
    What it bought: one real data-loss bug (the backup importer rebuilt every `TierResult` without
    `runs`, silently discarding the whole per-day clear log on restore), and mutation proof that
    four of the QA loop's headline fixes were deletable with a green suite — the cascade's send
    order, both web tier-refusal functions and `objViolated` on BOTH shipped copies. The cure was
    structural: `tests/web-extract.mjs` now lifts declarations out of `index.html` by name and RUNS
    the shipped code instead of string-matching it (the reviewer defeated its first version with an
    indented decoy; round 2 anchored it to column 0 and made ambiguity throw). It stopped because
    all four open majors were one fact — `ios/Causeway` has no Swift unit-test target, so every
    Swift guard is a string pin and each round pinned the functions the reviewer named while the
    reviewer found new ones. The closeout then changed `hasLiveGame` on both platforms and shipped
    a RED UI test target, which its own reviewer caught by running it: the calendar cell's
    `.accessibilityLabel` sits on a bare `ZStack`, so the locator never matched and VoiceOver reads
    every day as a bare number. Measured at 4.32M effective tokens (`tools/loop-usage.py`, whose
    per-agent attribution I fixed first — read the `agent-<id>.meta.json` sidecar) — 254K per
    finding, reported→effective 5.4×, and the closeout is now 40% of subagent spend. Written up in
    `docs/review-loop-0.8.1-feedback.md`: all four v0.7.1 gaps are fixed, and the new ones are the
    closeout's build-is-not-a-test blind spot, a closeout blocker with nowhere to go, and
    `thrashing_soft` asking for "one more round" at the backstop.

84. "We are in September now, and I can no longer navigate to August to play older deals." Correct:
    the calendar grid was rendered straight from `new Date()` on both platforms — `renderDailyCal`
    took `y`/`m` from today, `DailyView.calendar` from `Calendar.current.dateComponents(from: Date())`
    — and nothing else in the sheet could change the month, so on the 1st every earlier day fell off
    the app: no replaying a past challenge, and no reaching an attempt still inside its ⏰ grace. The
    month is now state (`calY`/`calM`, `calMonth`) with a back/forward arrow either side of the
    title, clamped to exactly the months the seeded pool spans, and the drawn month stays
    independent of which day the card shows. Verified in both shipping surfaces, not just in tests:
    the browser (September → ‹ → all 31 August days playable, Aug 12 opens deal #706747) and the
    simulator (same day, same deal number — parity by observation). The arrows cost the iOS legend
    ~68 pt and truncated "⏰ Same-day" to "Sam…", so the legend moved to its own line. Guarded by
    running the shipped web helpers (`civilOf`, `calMonthRange`, `clampCalMonth` lifted out of
    index.html) and by whole-body pins on the Swift twins plus a pin that the grid reads `calMonth`
    and never `Date()`; 7/7 mutants killed, including "the grid reads Date() again" on both sides.

85. Do the one-modifier fix (the review loop's open blocker: the UI test target red on `main`), defer
    seeding more dates; then give feedback on the latest review loop. The "one modifier" was
    necessary but not sufficient — a good lesson in taking a reviewer's FIX note as a hypothesis
    rather than a diagnosis. `.accessibilityElement(children: .combine)` + `.accessibilityAddTraits(.isButton)`
    on the calendar cell is real and fixes the VoiceOver defect (cells now expose as
    `Button, label: "Sep 3"`, locked ones as `"Sep 5, locked until that date"`, instead of a bare
    `staticText "3"`), but applying it alone left both tests still failing. Dumping the accessibility
    tree showed the whole grid missing — weekday header letters included, which no per-cell modifier
    could cause: `openDailyCalendar` scrolled until the legend `.exists`, which is TRUE for an
    element that is only in the hierarchy, so it stopped after zero swipes with the grid below the
    fold, and a `LazyVGrid` materialises nothing until it is on screen. `.isHittable` turned the
    class green. Whole UI suite now 21/21, zero skips (it had been 9-of-11 with skips); node 139/139.
    Feedback went into `docs/review-loop-0.8.1-feedback.md` §5: a "FIX:" note reads the same whether
    the reviewer tried it or not (wants a `fix_verified` flag), and — the one that stings — the loop
    had written the September calendar bug down itself, as a *justification* for a test skip ("the
    grid shows this month only"), twelve hours before it arrived as a user bug report.

86. Moving the project to another Claude account that will have the working directory but none of my
    memory — what exists only there, and write it down. Eight memory files, of which the load-bearing
    ones were never in the repo at all: the four standing rules (commit every task; keep prompts.md
    and BACKLOG.md current in the same commit; run the review loop after any non-trivial change;
    keep web and iOS in sync), the design north star (perfect-information pure-skill solitaire for a
    FreeCell player who dislikes luck and hidden cards — the tiebreaker for design questions), and
    the pbxproj trap that once shipped a landscape-only build to a physical iPhone and survived a
    delete + clean + reboot. Written as HANDOFF.md (state, verified commands, traps, loop economics,
    a map of where knowledge lives) plus a short CLAUDE.md that a session auto-loads, with README
    pointing at both. Everything was re-verified rather than copied: the memory still claimed Xcode
    was not installed and that the suite had 67 tests — it is Xcode 26.5 and 139 + 21. Also recorded
    the two live deadlines a newcomer cannot infer: the daily pool runs dry 2026-09-30, and the App
    Store submission is blocked on four owner-only items.

87. Review `docs/skeptical-review-2026-09-07.md` — agree or not, and propose a plan. Verified all
    11 findings against the cited source lines rather than taking the report's word: every one is
    real at the code level, including the ones that contradict our own green Sep-4 state (R10's
    calendar-helper fragility — the `.isHittable` legend criterion is layout/date-sensitive, so
    "green on the 4th" and "red on the 7th" are both true). Confirmed along the way: `confirmReset`
    guards only 3 of the ~8 board-replacement routes; `recordChallengeResult` never checks the
    pool's seed against the seed played; `recordWin`'s cleanup sits behind the once-only guard while
    `undo()` re-persists; web restore runs autoplay before the daily pool fetch lands; `GameClock`
    counts deliveries, not time; `web-extract.mjs` sandboxes 4 cells against the shipping 3. Two
    places I'd shade the review: R2+R8 are coupled to the 09-30 pool expiry harder than it says
    (reseeding makes R2 live for every saved attempt), and R1's fix is simpler than its
    recommendation reads — gate restore's automation on pool readiness and the exactly-once retry
    machinery mostly evaporates. Findings recorded as a dated BACKLOG section with verified line
    references; phased plan proposed (lifecycle P1s → surfaces → swiftc native harness → fail-closed
    builder → polish) with four owner decisions flagged. No fixes applied — assessment only, as asked.

88. Proceed with the plan from #87 (all four decisions taken: post-win undo → casual, R2 →
    minimal seed-binding, Xcode closed → real test target authorized, order approved), collecting
    review-loop feedback along the way. Everything landed, in six commits: the NCELLS harness
    drift; a real Swift unit-test target (the pbxproj edited while Xcode was verifiably closed —
    first executable Swift model tests ever, including a replay of all 61 certified lines through
    the real move API in ~3 s); the lifecycle P1s (one board-replacement gate over all eight web
    routes + the iOS Wins sheet, (day,seed) identity binding, pool-readiness gating with a
    durable pending grade, post-win-undo latch reset); the surfaces (bounded scrollable panels +
    Escape, stale-drag rejection, Gregorian todayIndex, wall-clock GameClock with explicit
    background pause, calendar tests pinned to Aug 15 scrolling to daily.cal.<idx>, fewest/fastest
    unfused); the builder's publishing contract (fail-closed, --extend verbatim-prefix, --rebuild
    requires a generation bump — five tests run the builder); and the stale docs (iOS README's
    "no Xcode" line, listing's portrait-only/double-tap/missing-daily, privacy's export wording,
    HANDOFF/CLAUDE refreshed). Two more latent bugs surfaced en route: web-extract's scanTo
    truncated destructured-param functions, and the deferred-onWin race with the R3 fix turned
    out already guarded by finishGen. Suites at close: node 153/153, native unit 11/11, calendar
    UI 3/3, full iOS suite re-run this session. Review-loop feedback collected throughout went to
    docs/review-loop-skeptical-review-feedback.md.

89. Review-loop round 1 (automated skeptical reviewer) on the #88 pass: 9 open findings — 1
    blocker, 4 major, 4 minor. All addressed. The blocker was real and embarrassing: `--extend`
    could never publish, because the selector filled `--days` slots instead of the open ones, so
    61 published + N fresh always failed the builder's own candidate validation — and the only
    sanctioned reseed path for the 2026-09-30 pool expiry failed closed on its happy path. Fixed
    (selection fills exactly the open slots), plus the majors: extension now seeds novelty
    counters from the published days and hard-bars exact published (silver, gold) pairs (checked
    again on the output bytes); a corrupt daily-pool.json refuses instead of parsing as absent;
    three POSITIVE builder tests (fresh publish, extend publish, corrupt-refusal) against the
    tracked cache, closing the "a suite of refusals is satisfied by a tool that always refuses"
    hole; Swift unit tests snapshot/restore `causeway.*` defaults instead of deleting them
    (sentinel-verified — an on-device run no longer erases real history). Minors: pool fetch
    retries with capped backoff, web post-win undo re-anchors the clock past the overlay dwell
    (iOS parity, newly pinned), the deferred win overlay redraws when the pool lands, and the
    `--rebuild` gate's message stops claiming a client coupling that doesn't exist (the missing
    coupling is a new BACKLOG item). Suites: node 156/156 (3 new), native unit 11/11.

90. Review-loop round 2: the round-1 fix itself shipped a fresh blocker. Seeding the novelty
    counters from the published pool also fed the per-family CAP (max 12), and the 61 published
    days pre-spent 9 of those 12 on six silver families — so `--extend` could never fill more
    than 23 new days, ever, while its error message pointed at `--candidates`/`--budget`
    (useless), and the round-1 extend test asked for +4 days, the one size that dodged the
    ceiling. Fixed by splitting the counters: scoring still inherits the published history
    (novelty debt across the seam), but the cap now counts only the run's own picks. Proven on a
    scratch copy: `--extend --days 92` publishes all 31 new days, published 61 byte-identical,
    zero published-pair repeats; the extend test now demands a full 31-day month. Also closed the
    reviewer's minor: the web clock now freezes while the tab is hidden and re-anchors on return
    (background time is not play time — the iOS `GameClock.pauseForBackground` semantic), covering
    hidden-tab saves, autoplay wins in a hidden tab, and background-restored tabs, with a new
    two-sided drift guard. Suites: node 157/157 (1 new); no Swift touched.

91. Review-loop closeout (converged after round 2): the two open minors, both test-hardening.
    (1) GameClockTests slept 5.7 real seconds and asserted loose wall-clock bounds that a busy
    scheduler could flake; `GameClock` gained an injectable `now` provider (three call sites,
    production unchanged) and the tests now advance a fake clock — exact assertions, instant,
    and the delivery-counting regression still pinned. (2) The builder suite never asserted the
    per-family variety cap it exists to enforce; both publish tests now check that no silver or
    gold family exceeds 12 of the selected days (fresh slice for `--extend`). Suites: node
    157/157, native unit 11/11.

92. Review loop over `6c248b8..a0dd4a4` (the previous task's five commits), plus feedback on
    the plugin itself. Converged after 2 rounds + closeout: 14 findings (1 blocker — `--extend`
    structurally could not publish; 4 majors incl. a pool-clobber path and tests wiping real
    UserDefaults), 13 fixed across commits 5826564/0801d8c/5819bb1, 1 open test-only minor to
    BACKLOG. Full suites green at close: node 157/157, iOS 32/32 (both targets). Report:
    `.review-loop/REPORT.md` (read the WATCH LIST — the hidden-tab clock freeze is a shipped
    behavior change the loop decided on its own). Plugin feedback:
    `docs/review-loop-orchestrator-feedback.md`.
