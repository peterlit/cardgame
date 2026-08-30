# Harness notes

Environment/tooling knowledge for testers. Append what you learn — keep it SHORT and
current; every tester pays for this file in tokens on every dispatch. The full
round-by-round notes from loops 1-2 (86 KB, driver-era) are archived at
`.qa-loop/archive/20260822-125736-f949d82/HARNESS_NOTES-full.md`; consult them only if
something here is missing.

## Environment (verified 2026-08-22, loop 3)

- App: `com.whimsicaldistractions.Causeway`, Debug for the iOS Simulator.
- **The simulator MCP tool `mcp__Claude_Code_iOS_Simulator__control` IS available to
  testers this loop.** Use it — `tap`, `swipe`, `touch_path`, `text`, `screenshot`,
  `launch`, `open_url`, always with your own `udid`. Do NOT build an XCUITest/CGEvent
  driver; everything in the archived notes about `simui`, `QADriver.swift`, and
  `xcodebuild test` scripting is obsolete rig, not app knowledge.
- Coordinates are **device points, origin top-left**, iPhone 17 Pro = 402 x 874 portrait.
  The `launch` result restates the coordinate space. Screenshots come back scaled; work
  from points, not pixels.
- Build (orchestrator does this; testers do not rebuild):
  `mcp__Claude_Code_iOS_Simulator__build` on `ios/Causeway/Causeway.xcodeproj`,
  scheme `Causeway`. Product this loop:
  `/Users/plit/Library/Application Support/Claude/simulator-builds/cd85e4ffec2e279e/DerivedData/Build/Products/Debug-iphonesimulator/Causeway.app`
- Reset state: `xcrun simctl uninstall <udid> com.whimsicaldistractions.Causeway` then
  `install`. There is no in-app reset.
- Rotation: `XCUIDevice` is not reachable without a driver, but the Simulator's own
  **Rotate** control and `simctl` are not needed — landscape geometry below was measured
  under XCUITest rotation in an earlier loop and still matches. If you cannot rotate with
  the tools you have, mark WF-12 cases `blocked` with that reason rather than guessing.

## Board geometry (iPhone 17 Pro, device points)

Portrait, no daily HUD, no Finish pill:
- Toolbar row 1 y≈135: New game x≈51, Undo 142, Replay 229, Auto-play 335.
  Row 2 y≈175: Auto-finish 68, Deal # 196, Daily 279, Wins 343. How to play (55, 214).
- Foundations up-row y≈296, down-row y≈374 at x≈28/77/126/175. Free cells y≈296 at
  x≈274/323/372.
- Tableau column centres x = 28, 77, 126, 175, 224, 273, 321, 370; card i (0-based) top
  y = 425 + 30*i; the bottom card of a column is full height (~75 pt).
- **The pills reflow constantly** (a `Finish` pill inserts between Auto-finish and Deal #
  and pushes Wins/How to play to a third row; the Deal pill gains a ` ✓` after a win and
  shifts Daily right). Re-read the row from a screenshot after any state change instead of
  trusting these numbers blind. Auto-play (335,135) and Auto-finish (50,175) do not move.
- Deal-entry alert: the number pad is not up when it opens; tap the field (200,268) to
  raise it, `Select All` at (213,316) to replace a pre-filled value. Pad: 1 (68,613),
  0 (200,770), 4 (68,666), backspace (333,774), Play (200,335). **One tap per digit** —
  `10011` is five taps; four taps silently gives a different, plausible-looking deal.
- Landscape (874 x 402): rail pills x=127, y = 70 New game / 102 Undo / 135 Replay /
  167 Auto-play / 200 Auto-finish / 232 Deal # / 264 Daily / 297 Wins / 329 How to play.
  Foundations up y=109, down y=189 at x=218/267/316/364; free cells y=297 at x=218/267/316.
  Tableau columns x = 420,468,517,566,615,664,713,762; card i top y = 57 + 26*i.
  `geo.size` in landscape is ~756x381 (safe-area insets already subtracted) — card-size
  math in ContentView must be evaluated with those numbers.

## Rules and traps that cost earlier testers a run

- Tableau build rule (`Game.canStackTableau`): alternating colour, rank ±1 **in either
  direction**, but a column with a 2-card tail must keep that direction. A "legal-looking"
  drop onto an ascending tail with a descending card is silently refused — that is the
  design, not a bug.
- After the demo's Stop, `started` is still false: **no Finish pill and no auto-finish
  until you make one real move.**
- Mode changes call `maybeAutoFinish()` in `didSet`, so all three Auto-finish modes can be
  exercised on ONE finishable board: Off (Finish pill) → Ask (prompt) → On (cascade).
- Sheets dismiss by dragging the **title bar** down (a swipe on the body just scrolls).
- Control-tool coordinates are DEVICE POINTS (402x874); the returned PNG is 1206x2622
  (@3x) and is shown to you downscaled again — never estimate a tap from image pixels.
  Ground truth: `xcrun simctl io <udid> screenshot <path>`, then scale by 402/width.
- Tapping a tableau card: aim well BELOW its documented top-y. Bottom (full-height) card:
  `top_y + 45`. A fanned, covered card: only a 30 pt slice is live, so aim `top_y + 15`.

## Reaching a finishable board deterministically

Blind tapping will not get you to a win, and **the old demo recipe is dead: Stop/Done call
`restartDeal()`, so a demo ALWAYS re-deals and never leaves the assisted position** (intended
since 2026-08-15, WF-6). Inject a save instead:
1. `node .qa-loop/tools/make_save.mjs --day <dayIndex> --tier <bronze|silver|gold|flawless>
   [--challengeDay <d|none>] [--startDay <d|none>] | python3 .qa-loop/tools/inject_save.py <udid>`
   — replays that day's certified line, parks it at the first position where the app's Finish
   cascade wins AND keeps the tier, and writes it to the app's Preferences plist (terminates the
   app + stops cfprefsd first; `--clear` wipes the save). Delete key `causeway.daily` from the
   same plist to reset daily records without a reinstall.
2. Relaunch → board restores, Auto-finish:Ask fires at once: **Finish (275,497) / Not yet
   (127,497)**; cascade + overlay ≈ 6-8 s.
3. Demo bar pills, ready/unpaused: Next (236,263), Start (297,263), Stop (357,263). **Paused the
   headline wraps to two lines:** Next (219,266), Resume (297,266), Stop (358,266); the 🌟 label
   wraps to three, pills at y=273.
4. Win-overlay buttons: `Play deal #N` (125,488), `Random` (238,488), `Close` (314,488) — **y=512
   when the daily result line wraps to two rows**.

## Performance measurement (PERF lane only)

- The orchestrator runs `nfr_sampler.sh` in the background; mark your action windows in
  `marks.jsonl` and read numbers from `nfr_analyze.py`. Do not do sampler arithmetic in
  your own context.
- Instantaneous CPU: `ps -o time=,rss= -p <pid>` at both ends of a window ÷ wall clock.
  Resolve the pid on the **host**: `pgrep -f "Causeway.app/Causeway"`.
- Baselines measured on an uncontended iPhone 17 Pro (build 342e3c0): cold launch → painted
  board ≤ 0.9 s; sheets settle ~1.0-1.1 s; New game redeal 1.65 s; demo auto-advance
  0.250-0.259 s/move (design 0.24); auto-finish ~0.18 s/card + 0.38 s to the overlay; idle
  CPU 0-1%. Only slow path found: **first Export after a cold launch, ~1.8 s with no
  spinner**.
- A landscape relayout stress test needs a **13+ card column** (11+ with the daily HUD);
  below that the width term binds and nothing resizes.

## Rig hazards

- A worker simulator can wedge or shut itself down mid-run (`xcodebuild`/`simctl` report
  `Busy` or `Timeout waiting for screen surfaces`). Recovery: `xcrun simctl boot <udid>`,
  wait ~30 s. UserDefaults state survives; in-flight demo state does not.
- In parallel lanes, never fire a burst of taps blind — verify state (e.g. the Moves
  counter) after each. Dropped taps under contention are a rig artifact; do not file them.
- Screenshots are ~2 MB each; delete film/scratch dirs as you go, and keep only evidence
  you will actually attach to a finding.

