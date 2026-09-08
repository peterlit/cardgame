# Causeway: the good, the bad, and the ugly

Independent design and code review, 7 September 2026.

**Reviewed baseline:** `21fb200b1ce2d52a0a4a240cbb6a6954effae935`, clean `main`.

**Verdict:** The game itself is worth keeping. Its rules, deterministic deals, and certified daily puzzles have a credible foundation. The weak point is the surrounding game session: loading a saved attempt, identifying which challenge it belongs to, replacing the board, and completing a game more than once. Those paths can discard progress or award the wrong result even while the fast test suite is green. I would prioritize those defects and executable native model tests before adding more features or treating the app as ready for a broader release.

This review includes BACKLOG.md and the design, architecture, handoff, testing, and release documents. Recommendations below are proposals; no implementation, existing documentation, or BACKLOG changes were made.

## What was actually checked

Builds, tests, probes, and the web preview ran in a detached review worktree at `/private/tmp/causeway-skeptical-review-20260907`, based on the commit above. Temporary reproduction code was confined to that worktree. The original checkout was used for reading and this report.

| Check | Observed result | What that establishes |
| --- | --- | --- |
| `npm test` | **139 passed, 0 failed, 0 skipped** | Existing Node tests pass at this baseline. |
| Full iOS UI suite, serially, dedicated iPhone 16 Pro simulator, iOS 26.5 / Xcode 26.5 | **19 passed, 2 failed, 0 skipped**, approximately 500 seconds | The app and UI target compile; the UI suite is currently red in this configuration. |
| All available bundled solution lines through the original native model's legal move methods | **228 lines, 21,956 moves, all passed** | The checked deals, normal move legality, and expected tier outcomes agree across all 61 shipped daily entries. |
| Targeted execution of the shipping web script with controlled storage, fetch completion, and timers | Reproduced restore/scoring, post-win Undo, reset, and stale-drag defects below | These are executable state failures, beyond source inspection. Rendering was stubbed for these probes. |
| Original Swift model files compiled into a temporary macOS command-line harness | Reproduced attempt-identity acceptance, win–Undo–win cleanup failure, calendar mismatch, and timer undercount | Exercises the actual model implementations, but does not substitute for iOS lifecycle or accessibility testing. |
| Live web preview at 1280 × 720 | Daily modal overflow confirmed by visual inspection and DOM geometry | A normal desktop viewport cannot expose the whole modal or its Close button. |
| Calendar UI diagnostic | Missing date cells appeared after one additional swipe | The two suite failures have evidence of a faulty scrolling helper, rather than evidence that the calendar cells do not exist. |
| Month builder with a missing certification cache and a scratch output file | **Exited successfully and replaced 61 days with 0** | An underfilled generation can overwrite a valid output instead of failing closed. |

The native solution replay used `Game.drop` and checked each move's success and the expected result; it did not merely call the demo token applier. Automatic play was disabled for that controlled replay. This is unusually useful positive evidence for the core game, although it covers known solutions rather than every possible legal position.

The full UI failures were `RegressionDailyCalendarTests.testPlayButtonNamesTheSelectedDay` and `testTappingALockedFutureDayExplainsWhy`, unable to find September 6 and September 8 respectively. The other 19 tests passed, including the demo scoring protections and the tested board-layout/reset cases.

**Evidence retention limitation:** the temporary worktree and test artifacts were no longer present after the interrupted session resumed. Counts and reproduction results here are taken from completed tool outputs observed during the review. The additional calendar diagnostic's final completion was not observed, so it is not counted as a passing test. Exporting additional simulator screenshots was blocked by automatic approval review because its usage limit was reached; no screenshot artifact is promised with this report.

## The good

### 1. The central game has a clear reason to exist

The two foundations per suit make the split between ascending and descending play consequential. Combined with an entirely visible tableau, three free cells, deterministic numbered deals, and two-way tableau building, this is a coherent variation for someone who enjoys FreeCell's planning. It is more than a familiar solitaire with a different theme.

The daily objectives use that distinction effectively. Constraints on foundation direction, ordering, cells, and move count can ask the player to solve a different problem on the same rules. The 13 objective families give the generator meaningful variety.

One qualification matters: perfect information does not prove that every random deal is winnable. The daily corpus has constructive evidence; the ordinary random-deal range does not have equivalent evidence from this review. “High winnability” remains a goal to measure, and “no luck” in the listing is stronger than the evidence if interpreted as a guarantee that every dealt position can be solved.

### 2. The shipped daily corpus withstands a stronger check than its existing tests

Every available bundled solution line replayed legally through the native game model and produced its expected tier result. Every shipped day has a flawless certificate. This directly addresses the older, now superseded concern that separately attainable Silver and Gold could form an impossible Flawless challenge.

Bronze for completing the deal, optional higher objectives, tiers banked across attempts, and Flawless reserved for a single qualifying attempt form an understandable progression. The same-day grace window is an explicitly accepted product decision. I would preserve these decisions while correcting the lifecycle defects around them.

### 3. Several defensive choices are sound

Saved-board validation checks shape, foundation bounds and crossings, and the exact canonical 52-card inventory. It rejects completed boards as resumable games. That is substantially better than trusting a decoded JSON object. See [native restore validation](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:288) and [web restore validation](/Users/plit/Documents/src/cardgame/index.html:553).

Demo playback begins from a fresh board and is segregated from scored play. Generation counters cancel old demo/finish work. Undo history and daily run logs are bounded. The daily store preserves unreadable or superseded payloads instead of immediately destroying the only copy. Backup generation checks are useful even though in-progress saves currently miss the same protection.

### 4. The clock's rendering boundary is a good architectural correction

Putting the ticking observable in `GameClock`, rather than invalidating the whole board every second, is sensible. Its weak timer capture and `deinit` invalidation are present. The elapsed-time calculation still needs work, but the rendering separation should be retained. See [GameClock](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/GameClock.swift:11).

This review provides no new evidence of a production memory leak and does not close the existing physical-device memory investigation.

### 5. The app has a small operational and privacy surface

The Node harness has no third-party package dependency tree. Native play uses local state and bundled resources without an account or analytics service. The web version's daily data comes from its own static assets. Those choices suit a personal, offline puzzle game and avoid substantial unnecessary infrastructure.

There is no reason to add account-based anti-cheat machinery to solve the correctness issues in this report. Correctly identifying an attempt and validating content at build time are enough for the product's current scope.

### 6. The presentation has an identity

The warm beach palette and clear card faces give Causeway a recognizable look. The landscape layout and long-column handling have received substantive attention, and the existing UI coverage provides some evidence that those corrections work. The visual design is stronger than the hierarchy of the secondary screens, discussed below.

## The bad: actionable defects

Priorities below reflect impact and when the issue should be addressed. **P1** means a high-priority correctness or basic usability defect to resolve before relying on the affected workflow. **P2** means a material defect to fix soon. “New” means I did not find the specific defect described in the checked BACKLOG; “known” identifies overlap rather than taking credit for an existing finding.

| ID | Priority | Finding | BACKLOG relationship |
| --- | --- | --- | --- |
| R1 | P1 | Web restores and automatically advances daily games before their rules load | New |
| R2 | P1 | Saved attempts can score against a different calendar generation or seed | New gap alongside known migration concerns |
| R3 | P2 | Win → Undo → win skips cleanup and leaves a resumable unfinished board | New; related to AF-test |
| R4 | P1 | Several board-replacement routes silently discard a live attempt | Known; scope is wider than the summarized routes |
| R5 | P2 | Non-Gregorian system calendars break native daily indexing | New |
| R6 | P1 | Web Daily modal overflows a normal desktop viewport without usable scrolling | New |
| R7 | P2 | Autoplay can invalidate a dragged cell card and cause a JavaScript exception | New instance beyond earlier selection guards |
| R8 | P1 | Content builder can overwrite valid data with an empty pool; extension is not append-safe | New executable failure; related to known content-expiry/migration work |
| R9 | P2 | Native elapsed time counts timer deliveries, not elapsed time | Known L4; understated as polish |
| R10 | P2 | Two UI regressions currently fail because the calendar helper stops too early | Recurrence of a known test problem |
| R11 | P2 | Statistics can describe an achievement that never happened | Known L5; additional misleading count label |

### R1 — Restoring a daily game races its asynchronously loaded rules

**Sources:** [restore and automatic continuation](/Users/plit/Documents/src/cardgame/index.html:595), [pool fetch](/Users/plit/Documents/src/cardgame/index.html:1384), [startup](/Users/plit/Documents/src/cardgame/index.html:2028), [tier protection](/Users/plit/Documents/src/cardgame/index.html:699), [daily scoring](/Users/plit/Documents/src/cardgame/index.html:1545).

Startup calls `restoreGame()` synchronously. Restoration immediately starts autoplay and considers auto-finish, while `dailyPool` is still `null` until `fetch` completes. The tier guard treats missing daily data as permission to proceed, and daily scoring returns no result when the pool is absent.

Two controlled reproductions used reachable saved boards built through the shipping web move paths:

* **Tier loss:** August 30, day index 29, seed 551879, saved after move 92 of its flawless line. Holding the pool fetch pending allowed autoplay to reach move 94 and violate the live Gold `split-at` objective at rank 8. Loading the pool before advancing timers stopped the same board at move 93 with Gold still live.
* **Lost credit:** August 1, seed 691039, one move from completing its 93-move flawless line, with auto-finish enabled and autoplay disabled. Holding the fetch pending let the board win and set `winRecorded`, but the daily store stayed empty and the recorded win's daily result was null. The completed-board save had already been removed. Fetch completion does not retry that scoring operation.

This can affect an ordinary reload on a slow or failing request. Disabling the Daily button until the fetch returns does not protect an already saved daily attempt.

**Recommended correction:** make daily-context readiness a prerequisite for resuming an identified daily attempt's automation and scoring. Represent loading/failure explicitly. On failure, preserve the attempt and expose a recoverable state instead of silently treating unavailable rules as unrestricted casual play. Regression tests should delay and fail the fetch and verify both tier preservation and exactly-once daily credit.

### R2 — An old saved board can earn credit for today's definition of a different challenge

**Sources:** [native saved-game schema](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:246), [native restore](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:315), [native scoring](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:934), [web restore](/Users/plit/Documents/src/cardgame/index.html:584), [daily-store generation gate](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/DailyStore.swift:11).

A saved attempt carries its board seed and a numeric `challengeDay`, but no calendar-generation or challenge fingerprint. Restore accepts them independently. Scoring then looks up the current challenge at that day index without verifying that its seed is the seed actually played.

The native model accepted a valid board for seed 551879 marked as day 0, although current day 0 is seed 691039. A historical web reproduction made the upgrade problem concrete: previous content at commit `b38b9bb` used seed 543528 for day 0. A saved near-complete board from that definition was accepted by the current code, and finishing it credited **current day 0 Bronze while still playing seed 543528**. That historical setup used the old shipped token applier; the result proves the identity mismatch, not a newly certified higher-tier result for that old attempt.

The intentional history wipes and versioned backup rejection do not close this path: a live saved board bypasses those gates.

**Recommended correction:** persist a stable identity that binds date/index, seed, objectives, and content generation. Validate it before continuation and again before awarding daily credit. A mismatched board could remain available as a casual game or undergo an explicit migration; it must not score as another puzzle. Cover an actual old-generation save in tests.

### R3 — Winning again after Undo leaves the model in an inconsistent completed state

**Sources:** [native Undo](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:483), [native recordWin](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Game.swift:908), [web Undo](/Users/plit/Documents/src/cardgame/index.html:767), [web recordWin/onWin](/Users/plit/Documents/src/cardgame/index.html:1230).

`recordWin` correctly guards against duplicate awards, but puts timer shutdown and saved-game cleanup behind that same guard. After a win, Undo restores and persists an unfinished board while leaving `winRecorded` true. Completing the last move again therefore skips cleanup.

Using the original native move path, win → dismiss overlay → Undo → last move produced `won=true`, `runningClock=true`, and an unfinished saved board still present. The equivalent web sequence left the old save intact and reused the original pending-win payload. Reload restored an unfinished board with one card remaining at move 92, despite the player having completed move 93 again.

**Recommended correction:** separate “award this attempt once” from “always reconcile a completed board's clock, automation, persistence, and presentation.” Define what post-win Undo means for an already scored attempt. Simply resetting `winRecorded` risks double-counting and is not a complete fix. AF-test should include this sequence as well as the deferred win-overlay window.

### R4 — Protection against discarding progress depends on which button the player uses

**Sources:** [native Wins typed deal and history row](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/WinsView.swift:85), [web daily play](/Users/plit/Documents/src/cardgame/index.html:1398), [web demo confirmation](/Users/plit/Documents/src/cardgame/index.html:1528), [web Wins play](/Users/plit/Documents/src/cardgame/index.html:1865), [web random button and keyboard shortcut](/Users/plit/Documents/src/cardgame/index.html:2012).

The native Wins sheet calls `game.deal` directly for both a typed seed and a saved-win row. On web, daily Play/Replay, Wins entry/history, the random choice inside the deal dialog, and the global `N` shortcut can replace a live board without the shared protection. The web demo check is weaker than `hasLiveGame`: it misses casual progress and a zero-move attempt carrying next-day grace.

With one real move made in a daily attempt, controlled web calls through daily Play, Wins Play, the `N` handler, and the random-deal button each reset the board to zero moves with **zero confirmation calls**. The confirmation stub would have refused if invoked.

This is more than inconvenience. Re-dealing can permanently forfeit the accepted same-day grace. The global keyboard handler also has no input-focus or modal check.

**Recommended correction:** put board-replacement policy behind one session-level entry point used by every user-triggered replacement route. Preserve the distinction between a live attempt, a finished board, and an unscored demo. Exercise the full route matrix, including cancellation, casual progress, and zero-move grace. The native Daily Play/demo guards already present are improvements to preserve.

### R5 — Native day indexing mixes calendar systems

**Source:** [todayIndex and its Gregorian helper](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Daily.swift:35).

`todayIndex()` extracts year/month/day with `Calendar.current`, then sends those components into a Gregorian day-number algorithm. These are incompatible when the system's preferred calendar is Buddhist, Hebrew, or Islamic.

Running the original function with `th_TH@calendar=buddhist` produced day index **198364**, rather than **37** for September 7, 2026. Independent Foundation component checks for that same date also demonstrated the mismatch for Hebrew and Islamic calendars.

From the code, a very large index makes all shipped future dates look past and prevents correct same-day recognition; a sufficiently negative index makes the shipped dates look future. Those UI consequences follow from the date guards, rather than from a completed device-language UI audit.

**Recommended correction:** use a Gregorian calendar with the player's local time zone for the product's civil-date arithmetic. Use locale preferences for presentation. Inject the date/calendar boundary so native tests can cover calendar choice, midnight, grace, and pool boundaries deterministically.

### R6 — The web Daily dialog is taller than the viewport and cannot be scrolled into reach

**Source:** [overlay and panel CSS](/Users/plit/Documents/src/cardgame/index.html:124).

At 1280 × 720, the live Daily panel measured approximately **1071 px high**, beginning at **−175 px** and ending at **895 px**. Its Close button occupied approximately **835–868 px**, below the viewport. The fixed flex overlay centers the oversized panel without a bounded scrolling region. Scrolling moved the board behind the overlay instead of exposing the rest of the dialog.

The title/top content is clipped above the screen and dismissal/later content lies below it. There is no general Escape handler for this dialog. Visible Play/demo actions can lead out by replacing the board, compounding R4.

**Recommended correction:** give the dialog a viewport-bounded scrollable layout with reachable dismissal, keyboard dismissal, and proper focus handling. Test the complete dialog at common laptop and smaller viewport heights, not only the board at a large viewport.

### R7 — A dragged cell card can disappear before drop

**Sources:** [selectedCards and tableau placement](/Users/plit/Documents/src/cardgame/index.html:798), [drag completion](/Users/plit/Documents/src/cardgame/index.html:1192).

The drag stores a source location. Autoplay can move that source card before pointer-up; `dragUp` reinstates the old location as the selection. A vacant cell produces `[null]`, which passes the nonempty-array guard and reaches code expecting a card.

A reachable position from seed 551879 had 6♠ in cell 0 and its ascending foundation at 5. With the position treated as casual play, capturing that cell location and running the actual `autoplayOneStep()` emptied the cell. Reusing the captured location and dropping on tableau column 2 threw **`Cannot read properties of null (reading 'color')`**. This is the state transition performed by drag completion; it was not reproduced as a timed physical pointer gesture.

The evidence shows an exception, an aborted drop, and skipped selection cleanup. It does not establish permanent board corruption or an unrecoverable app crash.

**Recommended correction:** reject vacant/stale sources in the move boundary, validate the captured card identity, and cancel or coordinate a drag when automation changes its source. The native `selectedCards` vacant-cell check is already better here.

### R8 — The next content generation needs a safer publishing contract

**Sources:** [builder defaults](/Users/plit/Documents/src/cardgame/tools/solver/build-month.mjs:93), [selection](/Users/plit/Documents/src/cardgame/tools/solver/build-month.mjs:174), [reordering](/Users/plit/Documents/src/cardgame/tools/solver/build-month.mjs:249), [warning followed by overwrite](/Users/plit/Documents/src/cardgame/tools/solver/build-month.mjs:283), [BACKLOG extension/migration note](/Users/plit/Documents/src/cardgame/BACKLOG.md:610).

The pool ends on **September 30, 2026**. Reseeding is explicitly deferred by the owner; that is an accepted scheduling decision, not forgotten work.

The unsafe part is the mechanism awaiting that decision. `build-month.mjs --days 92` selects from scratch and reorders the whole selected set. It does not load the existing pool and preserve its prefix. The BACKLOG correctly warns that rebuilding can invalidate history, but also describes the command as extending `days[]`; there is no append guarantee enforcing that interpretation.

There is also a directly reproduced destructive failure: with a missing cache, `--select-only --days 92` warned that it could fill 0 of 92 days, then **overwrote a scratch copy of the 61-day pool with zero days and exited 0**. The real bundled assets were untouched.

**Recommended correction:** fail with a nonzero exit and leave the previous output intact when generation is incomplete. Write and validate a candidate bundle before replacing outputs. An extension mode should assert that every published date retains its seed and objective definition and that pool/solution/native assets agree. An intentional rebuild should require a deliberate migration identity. No 92-day regeneration was performed in this review; the lack of a prefix guarantee is established by the implementation, not a claimed measured count of changed dates.

### R9 — Native recorded time depends on how often the run loop services the timer

**Sources:** [GameClock tick](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/GameClock.swift:17), [scene-phase persistence](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/ContentView.swift:249), [web elapsed-time calculation](/Users/plit/Documents/src/cardgame/index.html:1235).

The Swift clock adds one per timer delivery. It does not reconcile elapsed time when execution stalls. In a native probe, approximately **2.26 seconds** of wall time with the main thread blocked yielded **1 recorded second** after the run loop resumed. Background handling persists state but does not repair this elapsed-time discrepancy. Web uses a wall-clock difference.

The owner has already chosen continuous timing while inspecting sheets. That policy need not be reopened to fix the implementation. Recorded performance should follow the chosen policy, not incidental scheduling.

**Recommended correction:** separate display refreshes from elapsed-time measurement and explicitly account for the chosen background/relaunch semantics. Keep the isolated clock observable. Test suspension and delayed callback delivery with an injected time source.

### R10 — The calendar helper mistakes a visible legend for a materialized grid

**Source:** [openDailyCalendar](/Users/plit/Documents/src/cardgame/ios/Causeway/CausewayUITests/RegressionDailyCalendarTests.swift:161).

The helper scrolls only while the Same-day legend is not hittable. On the reviewed simulator the legend was already hittable while the grid's date cells had not materialized. It therefore made zero swipes and both date tests failed.

The diagnostic output was:

```text
beforeScroll: legendHittable=true, yesterdayExists=false, tomorrowExists=false
afterScroll:  yesterdayExists=true, tomorrowExists=true
```

This narrows the failure to the helper's stopping criterion. It does not justify reporting the whole class green: the diagnostic's subsequent action assertions and final result were not observed before interruption.

**Recommended correction:** scroll toward the actual target cell or a reliable grid anchor, with stable identifiers. Use a controlled date and explicit pool boundaries. The BACKLOG's existing pool-end time-bomb note remains relevant; success on a particular real calendar day is a weak long-term test contract.

### R11 — “Best moves in time” can describe no actual run

**Sources:** [WinStore independent minima](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/WinStore.swift:24), [daily merge](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Model/Daily.swift:423), [daily summary wording](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/DailyView.swift:276).

Independent bests are legitimate statistics, but the display combines them into an apparent single performance. Runs of 80 moves in 10 minutes and 100 moves in 5 minutes become “best 80 moves in 5:00,” which never occurred.

The “Cleared N×” label also comes from a bounded, deduplicated run list. It is not a lifetime clear count once more than 20 records exist, and identical move/time pairs can collapse.

**Recommended correction:** label lowest moves and fastest time separately, or choose an actual run under an explicit ranking rule. Label the retained log as recent recorded runs, or maintain a separate total if a lifetime count is intended. There is no need to expand storage merely to make the current wording honest.

## The ugly: why the defects keep escaping

### Tests provide narrower confidence than their names and comments suggest

The fast suite is valuable, but much of the native “parity” checking searches normalized Swift source for expected text. [The `pin` helper](/Users/plit/Documents/src/cardgame/tests/ios-parity.test.mjs:22) does not execute Swift. A function body can be present while startup ordering, state transitions, or a caller is wrong. More pins cannot establish those behaviors.

There is concrete harness drift: [the extracted web sandbox declares four cells](/Users/plit/Documents/src/cardgame/tests/web-extract.mjs:119), while [the shipping game uses three](/Users/plit/Documents/src/cardgame/index.html:443). This does not invalidate every test, but it disproves the assumption that the extraction environment automatically matches production.

[The bundled-line tests](/Users/plit/Documents/src/cardgame/tests/solutions.test.mjs:45) apply solver tokens and inspect the result; [the solver applier](/Users/plit/Documents/src/cardgame/tools/solver/rules.mjs:83) is not itself a full legality validator. A replay certificate should verify each legal transition, not only the final foundation state and objective telemetry. The independent native replay in this review closes that gap for the current corpus, and found no bad line. It should become repeatable project coverage.

There is no native model unit-test target, and no repository CI configuration was found under `.github`. Comments about “tripping CI” should not be read as evidence that an automated service is currently enforcing the checks.

The next testing investment should execute the shipping models with controlled time, storage, content readiness, and session transitions. Keep text checks for genuinely static contracts, such as bundled-asset equality; stop treating them as behavioral proof.

### Session policy is scattered across views, timers, and persistence

The same conceptual transition—replace a board—is implemented through multiple buttons and shortcuts. The same conceptual state—finished—appears as a board predicate, overlay flag, record-once flag, saved snapshot, and pending payload. A daily attempt's identity is distributed across seed, day, start day, telemetry, store generation, and an asynchronously available pool.

R1–R4 are consequences of those relationships being implicit. The increasing number of defensive comments and local checks shows real care, but each local fix leaves another entry point or flag combination to discover.

A modest refactor could establish four clear boundaries: pure rules; an attempt/session lifecycle; stores and migration; and automation scheduling. State transitions such as restore, discard, win, post-win Undo, and demo entry should be operations on that lifecycle. This does not require replacing SwiftUI or rewriting the game in a cross-platform framework.

### Multiple hand-maintained implementations make every change expensive

Rules exist in the inline web script, the Node reference/test modules, Swift, and solver logic. Several copies are intentional, but string pinning shifts much of the burden onto synchronized editing and reviewer memory.

The single-file web artifact does not require hand-maintained duplication: a build step could generate the inline script from a canonical module while preserving a distributable HTML file. Swift still needs executable cross-language fixtures and behavior tests. That is a more durable use of automation than growing a catalog of source substrings.

### The secondary UI asks the player to parse too much state

Five streak types, each showing current/best/total, put as many as 15 statistics before the day-specific task. The day card adds medal conditions, history, same-day status, and multiple demo choices. That hierarchy contributes to the overflow problem and makes optional objectives compete with the simple next action: play or resume this day.

Keep the approved features, but make the primary action and current attempt status dominant. Move detailed history and alternate demo choices behind deliberate disclosure. Distinguish banked medals from what remains attainable on the live attempt without forcing the player to infer that distinction from multiple small symbols.

Accessibility is partially implemented, not absent. [Card names are labeled](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/CardView.swift:51), and [calendar cells now have combined elements and button traits](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/DailyView.swift:648). However, the native card interaction is still driven by a custom [drag gesture](/Users/plit/Documents/src/cardgame/ios/Causeway/Causeway/Views/ContentView.swift:635), with no equivalent source/destination action model evident in the inspected code. Calendar labels omit earned-tier/same-day status, and fixed small typography limits adaptation. The web similarly lacks a complete keyboard move and modal-focus model.

A real VoiceOver and large-text playthrough is needed before claiming accessibility. This review did not perform one and does not claim that every assistive interaction is unusable.

### Documentation records history more reliably than current behavior

BACKLOG is useful evidence of prior reasoning, but it mixes open work, historical findings, corrections, deferred owner decisions, and superseded status. A reader must reconstruct chronology to decide what is true today. That encourages both duplicate fixes and false confidence.

Examples outside BACKLOG reinforce the problem: [the iOS README](/Users/plit/Documents/src/cardgame/ios/README.md:10) says only Command Line Tools are installed, while this review built with Xcode 26.5. [The daily design](/Users/plit/Documents/src/cardgame/docs/daily-challenges.md:1) leads with corrections and retains older incompatible descriptions below them. Its historical automation policy also needs to be distinguished from current tier-preserving withholding behavior.

[The listing draft](/Users/plit/Documents/src/cardgame/store/app-store-listing.md:5) still says portrait-only and smart double-tap, and omits the daily system. [The privacy draft](/Users/plit/Documents/src/cardgame/store/privacy-policy.md:14) says game data never leaves the device, although the user can now export a backup through Files to a chosen destination. That should describe user-directed export accurately; it is not evidence of undisclosed app telemetry. Support/contact placeholders also remain. These are draft-artifact inconsistencies, not a claim about current external store approval rules.

## BACKLOG reconciliation

The following reflects the reviewed code, not edits to BACKLOG.

| Item or theme | Assessment now |
| --- | --- |
| **F6 / native unit-test target; F6b / harness divergence** | Still open and high value. Source pins miss actual failures; the four-cell sandbox is a concrete drift example. |
| **AF-test / win recording and deferred presentation** | Still open. Add the reproduced win–Undo–win sequence and restoration while daily data is unavailable. |
| **Re-deal bypasses / DV1 / L2** | Still open in native Wins and several web routes. Native Daily Play/demo and the shared zero-move-grace predicate have improved; do not re-file all routes as unfixed. |
| **Calendar accessibility and scrolling closeout** | Partial implementation is real: combined elements/button traits and better labels exist. A per-day stable identifier is still absent. The revised legend-hittable helper is not reliable on the reviewed simulator. |
| **Calendar tests at pool end** | Still open. Date-dependent tests outlive the finite fixture pool. |
| **Eight unconditional skipped UI regressions** | Stale as a current status claim. This full run executed 21 tests with zero skips, although two failed. |
| **Older Flawless infeasibility findings** | Superseded by the Aug–Sep rebuild. All current days have a flawless line; the independent native replay passed. |
| **October content** | Deliberately deferred by the owner. September 30 remains the actual last supplied day. Before resuming generation, address R8 and preserve content identity. |
| **M7 / accessibility** | Still open, but “no VoiceOver labels” is stale. Labels exist; playable actions, informative state, and adaptable layout remain the meaningful work. |
| **L4 / timing** | Still open; observable measurement inconsistency, not merely cosmetic polish. |
| **L5 / best-score chimera** | Still open; current wording actively combines independent minima into one apparent run. |
| **L6 / missing timer deinit** | The missing-invalidation claim is stale: `GameClock.deinit` invalidates its timer. This does not prove the separate memory investigation resolved. |
| **I6 / production OOM and I6-verify** | Unresolved by this review. Requires the specified sustained physical-device Release measurement without confounding debug instrumentation. |
| **`loop-usage.py` always reports null agent** | Stale: the implementation reads `.meta.json` `agentType` and fallback attribution fields; related tests exist. |
| **Clean archive / release readiness / store materials** | Simulator compilation is verified. A clean distribution archive, signing, physical-device matrix, and corrected listing/privacy drafts remain outside the completed validation. |

The useful maintenance change would be a short current queue linking to an archived decision/finding history. Rewriting that queue was intentionally outside this report-only task.

## Recommended order of work

1. **Protect the attempt's identity and lifecycle.** Resolve pool readiness, saved-generation binding, post-win Undo cleanup, and every reset entry point. Add regression tests against the shipping implementation for each reproduced sequence.
2. **Make the basic surfaces reliable.** Fix the web modal, stale drag sources, and native calendar arithmetic. Repair the calendar test helper and control its date before using a green UI suite as a release signal.
3. **Establish executable native model coverage.** Preserve the all-lines legal replay; add injected clocks, storage, and content fixtures. Keep existing fast tests but correct the three-cell/four-cell discrepancy and narrow claims made by text pins.
4. **Make content publication fail safely before the owner resumes reseeding.** Preserve existing challenges on extension, reject incomplete output, validate pool/solution/native agreement, and explicitly version intentional migrations.
5. **Finish the product contract.** Correct timing and statistics semantics, conduct accessible playthroughs, simplify secondary-screen hierarchy, and publish one current description of controls, daily rules, and data export. Perform the already requested physical Release memory and distribution checks before closing those risks.

I would not start with another objective family, another review-loop mechanism, or a wholesale rewrite. The current core has earned targeted repair. The surrounding state machine and the evidence used to declare it correct have not yet earned the same confidence.

## Limits and reproduction guidance

The completed iOS suite ran with:

```sh
xcodebuild test -project ios/Causeway/Causeway.xcodeproj -scheme Causeway \
  -destination 'id=<dedicated iPhone 16 Pro simulator>' \
  -parallel-testing-enabled NO \
  -derivedDataPath <scratch>/derived \
  -resultBundlePath <scratch>/ui.xcresult
```

To reproduce R8 without touching real content, copy the pool to a scratch output and run `build-month.mjs --select-only --cache <missing-scratch-cache> --days 92 --out <scratch-output>`. Compare its day count and the process exit status. Never use the real asset path for that probe.

For R1, control completion of the daily-pool fetch independently from startup and the automation timers. Use the certified day-29 prefix at move 92 for tier loss and the day-0 flawless prefix one move from completion for lost credit. For R3, finish normally, dismiss the banner, undo the final move, finish again, then inspect saved state and relaunch. For R2, use an old-calendar save whose day index now maps to a different seed; a structurally valid board alone must not confer current daily identity.

No exhaustive random-deal solvability study, broad device/browser matrix, real VoiceOver session, large-text audit, clean distribution archive, or sustained physical-device Release memory test was completed. No unobserved diagnostic completion is presented as a pass. These limits matter particularly for the old OOM report and shipping-readiness claims.

**Repository effect:** this report is the sole intended file change. No fixes were applied to the game, tests, assets, project settings, BACKLOG, or prompt journal.
