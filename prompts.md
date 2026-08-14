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
    for jacks-down-first; one whole suit home for suit-sprint) and it isn't already violated. The HUD's
    live state now returns 'ok' (green ✓) for a secured objective mid-attempt, not just at win; budget
    objectives (moves/no-undo/cells) stay '·' until the deal is actually done, since they can still be
    blown. (B) The calendar Flawless 🌟 no longer overlaps the date — moved from an absolute top-right
    corner overlay into the day-cell's marker slot (replacing the tier dots, since flawless implies all
    three). Both platforms mirrored; parity drift-guards keep the Swift `objSecured` pinned. Verified on
    web (HUD DOM shows 🥈✓/🥇✓ with all Kings down on Deal #10003 before winning; calendar star measured
    0px overlap with the date) and on the iOS simulator (identical challenge renders; live HUD renders).
    67 tests green.
