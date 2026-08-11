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
