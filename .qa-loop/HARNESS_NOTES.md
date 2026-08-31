# Harness notes

Environment/tooling knowledge for testers. Append what you learn; keep it SHORT — every
tester pays for this file every dispatch. Loop 1-2 driver-era notes (86 KB) are archived at
`.qa-loop/archive/20260822-125736-f949d82/HARNESS_NOTES-full.md`.

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
- Build (orchestrator only; testers do not rebuild): MCP `build` on
  `ios/Causeway/Causeway.xcodeproj`, scheme `Causeway`. Product this loop:
  `~/Library/Application Support/Claude/simulator-builds/cd85e4ffec2e279e/DerivedData/Build/Products/Debug-iphonesimulator/Causeway.app`
- Reset state: `xcrun simctl uninstall <udid> com.whimsicaldistractions.Causeway` then
  `install`. There is no in-app reset.
- **Rotation is IMPOSSIBLE with the MCP toolset — all four routes verified dead 2026-08-30,
  do not re-spend turns on it.** (1) control tool has no orientation action; (2) `simctl` has
  no rotate subcommand (`simctl ui` = appearance/contrast/content_size only); (3) Simulator.app's
  Device>Rotate needs System Events → `osascript is not allowed assistive access (-1728)`;
  (4) writing `DevicePreferences:<udid>:SimulatorWindowOrientation=LandscapeLeft` +
  `SimulatorWindowRotationAngle=90` to `~/Library/Preferences/com.apple.iphonesimulator.plist`
  and restarting Simulator.app does nothing — Simulator rewrites both keys to Portrait/0 on
  window open. No `idb`. Mark WF-12 `blocked`; never infer landscape from ContentView.swift.
- `xcrun simctl ui <udid> content_size <category>` DOES work (Dynamic Type). Sheets honour it
  live, no relaunch; the board's card/toolbar text is fixed-size and ignores it. Reset to
  `large` when done.

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

*(Archived to `.qa-loop/archive/HARNESS_NOTES-perf-section.md` — round 2 has no `[perf]` cases,
and every tester pays for this file on every request. Restore it when a perf lane runs again.
Round-1 baselines, for reference: cold launch→painted board 0.89 s; auto-finish cascade 0.210 s/card
(animation-bound, not a stall); Daily sheet first open 0.93 s vs 0.69-0.72 s after; no memory leaks
over 24 New game/Replay and 16 Daily open/dismiss cycles.)*

## Board geometry addendum: the daily HUD shifts everything

- With a live challenge the objectives banner pushes the board down ~73 pt: foundations up y≈369,
  down y≈446, tableau card i top y ≈ 498+30*i (bottom card tap = top+45). The no-HUD numbers
  (296/374/425) hit the foundation area and silently do nothing. Re-measure after any HUD/pill change.
- Cheap read-back (no full frame): `xcrun simctl io <udid> screenshot s.png; sips -c <h> 1206
  --cropOffset <top_px> 0 s.png --out c.png; sips -Z 800 c.png`. src px = pt x3; header + both pill
  rows = px 200-520.
- **The Preferences plist lags the running app** (cfprefsd cache): `PlistBuddy -c "Print :causeway.game"`
  can show a save from several actions ago — nearly cost me a phantom finding. Terminate first, or
  test durability with `simctl terminate` + `launch` and read the SCREEN.

## Rig hazards

- **NEVER `killall Simulator` / quit Simulator.app: it SHUTS DOWN EVERY BOOTED SIM DEVICE**,
  including other lanes' workers (measured — 4 booted → 0 in one call). If you already did it,
  `xcrun simctl boot <udid>` each device back immediately and say so in your summary. Merely
  `open -a Simulator` is harmless.
- A worker simulator can wedge or shut itself down mid-run (`xcodebuild`/`simctl` report
  `Busy` or `Timeout waiting for screen surfaces`). Recovery: `xcrun simctl boot <udid>`,
  wait ~30 s. UserDefaults state survives; in-flight demo state does not.
- In parallel lanes, never fire a burst of taps blind — verify state (e.g. the Moves
  counter) after each. Dropped taps under contention are a rig artifact; do not file them.
- Screenshots are ~2 MB each; delete film/scratch dirs as you go, and keep only evidence
  you will actually attach to a finding.

## Tester tooling index

- `.qa-loop/tools/save_at.mjs --day D --tier flawless --mode firstfinish|autoplaybreak|move --at N
  [--challengeDay d|none --startDay d|none]` — like `make_save.mjs`, but parks the save at an
  ARBITRARY point of a day's certified line: `firstfinish` = the first position where the cascade
  wins (day 21 -> move 64, the tier-costing offer), `autoplaybreak` = the first position where a
  safe auto-play send would break a `split-at` Gold (day 29 -> move 92, the 8♠ case), `move` = a
  literal move index. Pipe into `inject_save.py <udid>`.
- `.qa-loop/tools/imgcrop_diff.py X0 Y0 X1 Y1 base.png frame.png [...]` — pure-python PNG
  crop-diff (MAD + %pixels changed). **The QA hosts have NO PIL, NO ImageMagick, no pyobjc** —
  build nothing new for image comparison, use this. Coords are SOURCE PIXELS (simctl @3x =
  device points x 3). Cheap way to assert "Moves incremented" / "board unchanged" without
  spending a full screenshot on your context.

## Simulator-access + input recipes

- **`sips -Z N` sets the LARGER dimension, not the width.** `-Z 420` on a full 1206x2622
  screenshot yields 193x420, so coordinates read off it must be divided by 6.24, not 2.87 —
  two mis-aimed taps this round came from that. Crop first (`sips -c h w --cropOffset t l`) so
  width is the larger side, then `-Z`.

- `make_save.mjs` prints a `[make_save] ...` log line to STDOUT before the JSON, so the documented
  pipe fails with a JSONDecodeError: use `node ... make_save.mjs ... | grep '^{' | python3 ... inject_save.py <udid>`.
- The MCP control tool can return "user has not granted Claude access to <device>" on the FIRST
  call of a dispatch. It is a pending grant, not a hard block: **retry the same call a few turns
  later** (worked on the 3rd attempt this round). `xcrun simctl io <udid> screenshot` keeps
  working throughout, so use it for evidence while you wait.
- **Deal-# entry in 4 turns instead of 11.** The field is pre-filled and the number pad has no
  select-all. Do: tap `Deal #` (196,175) -> `touch_path` DWELL on the field
  (points [{x:200,y:324,dt_ms:0},{x:200,y:324,dt_ms:900},{x:200,y:324,dt_ms:300}]) -> tap
  `Select All` at (143,277) -> `text` action with the digits -> `Play`. The dwell raises the
  edit menu; the `text` action replaces the selection in one turn. (After the menu tap the
  keypad drops and the alert re-centres: Play moves to ~(275,531).)
- `swipe` with duration 0.6 drives the app's manual DragGesture correctly (pickup + drop);
  no dwell is needed and adding one is not required for a card drag.
- Filming a sub-second animation: run `for i in $(seq 1 60); do xcrun simctl io <udid>
  screenshot film/f$i.png; done` as a BACKGROUND bash task (~4-5 fps), fire MCP taps while it
  runs, then `imgcrop_diff.py` each frame against f001 over the card rect.



## Chunk wf13-past-days

- Daily sheet, reading MANY past days cheaply: from the bottom-scrolled position do ONE extra
  small swipe `(200,380)→(200,470)` (+~78 pt). The day card's Silver+Gold+⏰ lines, the gold
  Play button AND the whole calendar are then on screen at once, so each further day costs
  1 tap + 1 screenshot instead of a scroll round-trip. Cells at that offset: Aug 1 (361,549),
  Aug 2-8 at y=592 (x = 40/94/147/201/254/307/361). The card HEADER (date + `Deal #`) stays
  tucked under the nav bar there — it is readable as a faded date but the deal number is
  hidden by `Done`, so use the full scroll-up only when you need the deal number.
- Batch the image `Read`s: take the per-day screenshots in separate turns, then read them all
  in one parallel block — turns, not images, are the dispatch budget.
## Chunk wf-7-9-11 (round 2)

- **Files sheets (Export save / Import pick), iPhone 17 Pro pt.** Export -> exporter sheet: `Save`
  (355,108). Import -> picker: `On My iPhone` grid, first file icon (71,257), second (200,255),
  third (~330,255); tapping the ICON (not the label) opens it and the merge happens immediately.
  Drop fixture JSON straight into the LocalStorage app group to make it appear:
  `~/Library/Developer/CoreSimulator/Devices/<udid>/data/Containers/Shared/AppGroup/<id>/File Provider Storage`
  where `<id>` is the group whose `.com.apple.mobile_container_manager.metadata.plist` says
  `group.com.apple.FileProvider.LocalStorage`. Exported files land there too — read them from the
  Mac to assert the exporter's contents.
- Daily sheet: a downward swipe on the BODY once it is already scrolled to the top DISMISSES the
  sheet (it does not just bounce). Scroll back up with 2 swipes, not 3, or re-open Daily.
- Deal-# alert with the number pad NOT raised: `Cancel` (127,529), `Play` (275,527); the live-game
  confirmation that follows puts `Keep playing` (127,517) / `Play that deal` (274,517) 10 pt away —
  a second tap at the Play coordinate hits the destructive button.

## Chunk wf-14 (round 2)

- **Zero-move daily-attempt fixture** (the state `playChallenge` persists before any move):
  `node .qa-loop/scratch/qa-worker-1/zero_move_save.mjs --day D [--startDay d]` — a fresh
  `dealState(seed)` board with `moveCount 0, started false, challengeDay/challengeStartDay`.
  20 lines; re-create it from `make_save.mjs`'s tail if the scratch dir is gone. `make_save.mjs`
  cannot produce it (it always parks at a near-win truncation).
- **`.qa-loop/tools/save_at.mjs` is BROKEN on this checkout**: its imports use `../../../tools/...`
  (one `..` too many) → `ERR_MODULE_NOT_FOUND /Users/plit/Documents/src/tools/solver/rules.mjs`.
  `make_save.mjs` (`../../`) works. Fix the paths before relying on it.
- **Do not trust a plist read for "did that tap change the model", even after `simctl terminate`**:
  a Replay that demonstrably re-stamped `challengeStartDay` still read as the old value from
  `causeway.game`. Assert on the SCREEN (re-open Daily and read the day card) instead; the
  Daily-sheet Play leg did flush, so the lag is intermittent, which is worse than always-stale.
## Chunk wf-10-15 (round 2)

- The how-to-win grid's two rows are only ~39 pt apart (bottom-scrolled sheet: Clear/Silver
  y≈744, Gold/Flawless y≈783, columns x≈115/287). A y off by 40 silently starts the
  NEIGHBOURING tier's demo — always read the demo-bar headline before trusting a pill tap.
- Stronger "sticky tier" fixture than a manual break: after the flawless win, inject
  `make_save.mjs --day D --tier bronze --challengeDay D --startDay D` and Finish. That records a
  genuine completed WORSE run on the same day, so `mergeTiers` OR-ing is tested for real.
- Wipe daily records without a reinstall: terminate + `launchctl stop cfprefsd`, then drop keys
  `causeway.daily` (+ `causeway.game`) from the app plist — copy `inject_save.py`'s preamble.
