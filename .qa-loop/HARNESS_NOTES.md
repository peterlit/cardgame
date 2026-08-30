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

- The orchestrator runs `nfr_sampler.sh` in the background; mark your action windows in
  `marks.jsonl` and read numbers from `nfr_analyze.py`. Do not do sampler arithmetic in
  your own context.
- Instantaneous CPU: `ps -o time=,rss= -p <pid>` at both window ends ÷ wall clock; resolve the
  pid on the **host** via `pgrep -f "Causeway.app/Causeway"`.
- Baselines, uncontended iPhone 17 Pro (342e3c0): cold launch→painted board ≤0.9 s; sheets
  ~1.0-1.1 s; New game redeal 1.65 s; demo auto-advance 0.250-0.259 s/move (design 0.24);
  auto-finish ~0.18 s/card +0.38 s to overlay; idle CPU 0-1%. Only slow path: **first Export
  after a cold launch, ~1.8 s, no spinner**.
- **Timing recipe that needs no tap timestamp (loop 4).** Run the filmstrip in a background
  bash turn, fire the MCP action in the next turn, then md5 every frame: a static screen gives
  byte-identical PNGs, so change-points ARE the animation boundaries. `touch` = first frame that
  differs from the resting frame (press highlight / note-line change); `settled` = first frame of
  the final identical run. md5 is ~free next to `imgcrop_diff.py` on 70+ frames — diff only the
  2-3 frames you must attribute.
- **You cannot timestamp an MCP tap from bash** (assistant-turn overhead t_pre->tap measured
  4.0-4.3 s, and it varies). Do not quote tap latency off a bash `date`. Calibrate instead: run
  the same t_pre->visible-change measurement on an instantaneous control (the Auto-play pill is a
  pure @State flip) and quote the DIFFERENCE.
- Baselines re-measured uncontended on b2ce1a4: cold launch->painted board 0.89 s; Daily sheet
  open 0.93 s first-of-process / 0.70 s after; sheet dismiss->board 1.3 s; how-to-win pill->
  confirm dialog 0.51 s; dialog->demo bar ~1.1 s; auto-finish 0.210 s/card (4 cards 1.57 s,
  29 cards 6.10 s, continuous animation); first Export of a process touch->Files sheet 2.26 s
  (0.96 s frozen, but the "Opening Files..." note IS up). Idle CPU 0.0 %, net 0 all session.
- **nfr_analyze.py will flag a cold-launch window as a suspected leak** — a window that opens at
  `simctl launch` starts at 60-110 MB RSS and warms to ~190-235 MB. Always mark loop windows so
  they START on a warm process, and dismiss any candidate whose rss_start is below ~150 MB.
- A landscape relayout stress test needs a **13+ card column** (11+ with the daily HUD);
  below that the width term binds and nothing resizes.

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


## Chunk wf-11-backup (qa-worker-2, round 1)

- **Cropping/downscaling a screenshot costs nothing extra: `sips` is on the QA hosts.**
  `sips -c <h> <w> --cropOffset <top> <left> in.png --out out.png` (SOURCE PIXELS, @3x) and
  `sips -Z <maxdim>` to downscale. One crop of raw px `0 2320 1206 300` reads the Daily
  BACKUP note line; `1720 0 1206 900` gets calendar + BACKUP + note in ONE image.
- `.qa-loop/tools/stats_state.py <udid> dump|load|clear` — read/write `causeway.daily`
  (v3, wrapped as `{"version":3,"days":{...}}`) and `causeway.wins` in the app plist. The
  fixture + assertion channel for stats work; `dump` also surfaces `.unreadable`/`.vN` stashes.
  **Booleans must be real JSON `true`/`false`** — a `1` makes Swift's decode fail and the
  store silently stashes to `causeway.daily.unreadable` and starts empty.
- **File-picker fixtures** live in
  `<sim>/data/Containers/Shared/AppGroup/<group.com.apple.FileProvider.LocalStorage>/File Provider Storage`
  (find the group by `plutil -p <group>/.com.apple.mobile_container_manager.metadata.plist`).
  Writing/overwriting there from the host works fine.
- **Importer opens on `Recents` and can sit on "LOADING" forever** on a fresh boot — tap
  `Browse` (285,819) to get On My iPhone. It remembers Browse for later imports in the run.
  Daily sheet scrolled to bottom (3 x swipe (200,750)->(200,150)): Export (106,772),
  Import (296,772), note line raw px y≈2400. Exporter `Save` (350,110); importer close `X`
  (311,110). File grid (4 items): (71,258) (200,258) (331,258) / (71,456), alphabetical.
- **Do NOT swipe DOWN on the Daily sheet body from y<=300 to scroll back up** — it dismisses
  the sheet and the next swipe lands on SpringBoard. Re-open the sheet instead (it opens at
  the top), or accept losing the sheet.

## Chunk wf13-past-days (qa-worker-1, round 1)

- Daily sheet, scrolled to the BOTTOM (1 x swipe (200,700)->(200,300) from the top):
  `Play` (200,243); calendar cells `x = 40 + 53.6*col` (col 0=Sun), `y = 471 + 44*row`
  -> Aug 1 (361,471); Aug 2-8 y=515 at x=40/94/147/201/254/307/361; Aug 30 (40,691),
  Aug 31 (94,691). Cells are ~44 x 33 pt. `derive_daily.py <date>` prints the same
  coordinate — trust it over eyeballing.
- **Scrolling the sheet back UP: swipe (200,400)->(200,740).** The notes' warning is real —
  starting a downward swipe at y<=300 dismisses the sheet.
- **Daily HUD shifts the whole board down by +88 pt** (3 objective lines + a day title).
  Tableau card i top y = 513 + 30*i; bottom (full-height) card tap = top_y + 45; free
  cells y=384 at x=274/323/372; foundations up y=384 / down y=462. Toolbar is ABOVE the
  HUD and does not move (Undo 142,135; Daily 290,175).
- Reading the HUD costs no full screenshot: `sips -c 190 1206 --cropOffset 740 0 shot.png`
  gives the day title + all three objective markers legibly.
- The `touch_path` free-cell drag from TC-13.4 works first try: 7 points, ~750 ms total,
  ending with a 150 ms dwell on the cell.

## Chunk wf-9-13b (qa-worker-2, round 1)

- **Batch gestures.** Several MCP `control` calls in ONE assistant block execute in order, and a
  `Read` of the previous screenshot can ride along in the same block. Reading a Daily day card
  therefore costs 2 turns, not 6: block = [swipe x2 to the calendar, tap the day cell, swipe back
  up] + Read(previous), then one bash screenshot+crop.
- **Calendar anchor.** The Daily sheet's BOTTOM is a hard scroll stop, so `derive_daily.py`'s
  `cal cell y=515` is only reliable there: swipe (200,700)->(200,340) **twice** from a day-card
  view lands on the stop every time (day cards differ in height when a day has 3 vs 4 pills, so
  never reuse a mid-scroll offset). Scroll the card back with (200,340)->(200,700) once.
- **One crop reads a whole day card:** `sips -c 1300 1206 --cropOffset 1050 0 shot.png` then
  `sips -Z 600` — header + all three tier rows + the ⏰ line + the pill grid, legible.
- Wins-sheet geometry: `Wins` pill moves to (345,175) once the Deal pill gains its ` ✓`.
  Sheet: Done (339,99), deal field (164,186), Play (356,186). `dealText` is @State and RESETS on
  every reopen — cheaper than fighting the number pad for a select-all (the field's long-press
  edit menu did not appear for me at all).
- Seeding wins is far cheaper than winning 7 deals: `stats_state.py <udid> load` with
  `{"wins":{"<seed>":{"date":<Double>,"moves":N,"secs":N}}}` populates the Wins grid directly
  (date is secs since 2001-01-01). One real injected-save win first to prove the record path.

## Chunk wf-15 (qa-worker-2, round 1)

- **Park a save at the FIRST finishable position REGARDLESS of tiers** (the fixture make_save
  refuses to): copy `make_save.mjs` into your scratch, fix its three `'../../` import paths to
  `'../../../`, and relax line 72 to `const need = a.won;`. Its stderr line then reports what the
  app's own cascade would score (`silver=… gold=…`) — matched the in-app overlay exactly (day 21:
  predicted finalMoves=83, overlay read 83 moves). Sweeping days 0-29 costs one bash turn.
- **Reading a day card costs 2 turns**: one block = [swipe (200,700)->(200,340) x2 to the calendar
  stop, tap the day cell, swipe (200,400)->(200,740) back up], then one bash
  `screenshot + sips -c 1500 1206 --cropOffset 900 0 + sips -Z 450` shows header, all three
  objectives, the ⏰ line and the whole pill grid legibly.
- Today card pill grid (fresh install, unplayed): 🥉 Clear (115,747) 🥈 Silver (293,747)
  🥇 Gold (115,787) 🌟 Flawless (293,787). A 3-pill day drops Silver and puts 🌟 alone on row 2.
- Win overlay after a flawless+⏰ win: Close is at (316,512) (two-line result row); the Daily pill
  on the board is then at (302,175).

## Chunk wf-14-sameday (qa-worker-1, round 1)

- **Injected ⏰ grace fixture works and is honest state, not a code inference:**
  `make_save.mjs --day 28 --tier flawless --challengeDay 28 --startDay 28 | inject_save.py <udid>`
  writes exactly "began Aug 29's challenge on Aug 29"; relaunch -> Not yet -> the Aug 29 day
  card shows the live-grace branch. `stats_state.py <udid> clear` between grace repeats.
- Auto-play: **Off survives inject_save + relaunch** (the injector only rewrites `causeway.game`),
  so set it once at the start of the dispatch.
- Win-overlay `Close` measured this round: **(318,511)** when the daily line wraps to two rows,
  **(318,503)** when it does not. Cascade -> overlay took ~6-9 s from the Finish tap.
- Day-card ⏰ line, sheet scrolled so the card is fully visible after
  swipe(200,700->300) + tap cell + swipe(200,400->740): card `Play` sits at **(201,672)** and the
  ⏰ line at raw px y≈1855-1900. Crops that read it: `sips -c 170 1206 --cropOffset 1750`.
- Calendar last two rows in ONE cheap crop: `sips -c 320 1206 --cropOffset 1870 shot.png` —
  shows Aug 23-31 with tier glyphs and the ⏰ corner pip legibly at `-Z 800`.
