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
- With the daily HUD everything shifts down ~40 pt and cards shrink — re-measure.
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

## Reaching a finishable board deterministically

Blind tapping will not get you to a win. Use the baked demo line:
1. `data/daily-solutions.json` `.solutions["<seed>"].bronze` is the token stream the in-app
   demo replays; `tests/engine.mjs deal(seed)` reproduces the iOS deal exactly. Replay
   tokens in node and run `autoFinishWouldWin()` after each to find the first finishable
   index. (Known: **seed 10004 bronze becomes finishable at step 84 of 97.**)
2. Daily → "Show me how to win: Clear" → step `Next` that many times → `Stop`. The board
   keeps the assisted position. Taps in the demo bar are reliable.
3. Demo bar pills, ready/unpaused: Next (236,263), Start (297,263), Stop (357,263).
   **Paused, the headline wraps to two lines and they move:** Next (219,266),
   Resume (297,266), Stop (358,266).
4. Win-overlay buttons: `Play deal #N` (125,488), `Random` (238,488), `Close` (314,488).

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

## WF-13 exploration notes (loop 3)

- `mcp__Claude_Code_iOS_Simulator__control` tap/swipe/touch_path coordinates are
  DEVICE POINTS (402x874) — do not eyeball the returned screenshot's pixels: `sips`
  confirms the PNG is 1206x2622 (native @3x), rendered downscaled to you, so visual
  pixel-position estimates from the image are unreliable and cost many wasted taps.
  Trust the documented device-point geometry, or capture ground truth via
  `xcrun simctl io <udid> screenshot <path>` + read the file if in doubt.
- Tapping a tableau card: aim well BELOW the card's documented top-y, not at it — the
  fanned card above still receives the top ~15-20pt of that slice. For the column's
  bottom (full-height) card, `top_y + 45` reliably hits it; for a non-bottom fanned
  card (now covered by a card stacked on it), the live target is only that card's
  30pt slice, so tap near its vertical centre (`top_y + 15`).
  Confirmed baseline (no daily HUD): New Game deal, col0 idx6 (bottom of a 7-row
  column) — `top_y=605` (425+30·6), hit at **y=650**, missed at y=605/620.
- **Daily-challenge HUD adds a LARGE y-shift**, bigger than the ~40 pt the Fixture-
  policy/WORKFLOWS notes quote for the compact one-line chip HUD. The 3-line STACKED
  bullet-box variant (used whenever a day's labels can't one-line in portrait — i.e.
  most sandbox days) measured **+80 pt** to every board y-coordinate versus the
  no-HUD baseline (confirmed: col idx5 of a 6-row column, no-HUD hit at y=620, HUD
  hit at y=700). So under this HUD: tableau bottom-card tap y = `425 + 30·idx + 80 + 45`.
  Toolbar rows (New game/Undo/Replay/Autoplay at y=135; Auto-finish/Deal#/Daily at
  y=175) do NOT shift, but row2 grows a row3 (Wins/How to play move to y≈216) once
  the daily pills + Wins + How-to-play no longer fit two rows — re-tap Daily via its
  actual row-2 slot, don't assume x=279 still hits it (Deal # pill width varies with
  seed digit count and shoves Daily right).
- Daily-sheet calendar (unscrolled, no prior HUD): weekday row "S M T W T F S" cells
  are ≈52.8 pt apart starting at x≈42 (col 0 = Sunday); the row containing days
  2-8 sits at device y≈720. Day cell for Aug D (2026, Sunday=Aug2) → x = 42+52.8·
  ((D-2) mod 7), y = 720 + 48·((D-2) div 7) (one more row every 7 days). The selected
  day's `Play` button is at ≈(200,495) regardless of which day (Today or sandbox).
- Sandbox days Aug 5-11 (dayIndex -7..-1) ARE selectable and each shows its OWN Deal
  #/objectives distinct from Today's — confirmed live for Aug 6, 7, 8 against the
  Fixture-policy table (deal numbers, silver/gold label text, and demo-pill count
  all matched exactly, including Aug 8 correctly suppressing its Silver demo pill
  since silver's line == bronze's for that seed).

## Chunk wf-1-1 notes (round 1, loop 3)

- MCP `control` needs `attach` on your udid BEFORE `launch`, or launch fails with
  "does not have the user's permission to use this device". `launch` also requires
  `app_path` (the .app bundle) — `bundle_id` alone is rejected.
- **Deal alert, corrected:** the number pad is ALREADY UP when the alert opens (the
  older note saying you must tap the field is stale), the field is prefilled with the
  current seed, and with the pad up `Play` sits at **(276,392)**, `Cancel` at (130,392)
  — NOT (200,335). Clear the field with 6 taps of backspace (333,775); `Select All` is
  unnecessary. Digit `1` (68,613), `0` (200,775) confirmed.
- Cheap screenshots: `xcrun simctl io <udid> screenshot f.png` then
  `sips -Z 900 --out v.png f.png` to view (or `sips -c H W --cropOffset Y X` for one
  region; the header Moves/Time/Won box is `-c 160 420 --cropOffset 200 780`). Avoids
  the MCP screenshot round trip entirely.
- **The clock starts on the FIRST MOVE, not at deal time** (verified: Replay, 40 s idle
  → Time 0:00; first move → clock begins). Do not read a nonzero clock right after a
  move as app latency: an MCP tap→bash-screenshot round trip is **5-10 s of harness
  latency**, which is what makes the clock read 0:06-0:09 "immediately" after a move.
- Detecting transient animations: `xcrun simctl io <udid> recordVideo out.mov` in the
  background, tap, `kill -INT`, then `ffmpeg -i out.mov -vf "fps=20,crop=..."` and md5
  the frames — the board repaints on a 1 Hz cadence, so an off-cadence 2-frame change
  is the real UI event. Found the ~100 ms card lift on an unmovable tap this way.
- `node -e "import('./tests/engine.mjs').then(m=>...m.deal(SEED))"` prints the exact
  tableau for a pinned deal — far cheaper and safer than reading ranks off a screenshot.

## WF-2 chunk notes (loop 3, round 1)

- The MCP control tool needs a per-device permission grant; a fresh worker sim can answer
  "user has not granted access" for the first minute. `xcrun simctl launch` works meanwhile;
  retry `attach`/`tap` after ~60 s rather than treating it as blocked.
- Cheap state reading without burning image tokens: `xcrun simctl io <udid> screenshot` +
  the scratch helpers `scan.py` (vertical pixel scan → each column's card top-edge y list,
  so card COUNT and fan pitch are text) and `hscan.py` (horizontal scan → card left/right
  border x, i.e. card width after a board shrink). Full-res PNG is 1206x2622 = 3x device pt.
- To read one value (Moves/Time), crop first: `sips -c 120 500 --cropOffset 250 700` then
  `-Z 300` gives a legible strip for ~1/20th the tokens of a full frame.
- `swipe` with duration 0.1 s still performs a card drag (proves pickup has no press-and-hold);
  `touch_path` with a final repeated point and `dt_ms: 4000` holds the card mid-drag so a
  background `simctl` film loop (~3 fps) can capture the lifted card's rendered position.
- The dragged card is rendered CENTRED on the touch point (measured: finger x=52 → card span
  30.0-74.0 pt), and the tableau drop frames equal the card frames, so the ~5 pt inter-column
  gutter is a dead zone. Aim drops at a column CENTRE, never near x = centre+24.

## Chunk wf-3-1 notes (round 1, loop 3)

- No PIL / no ImageMagick on this box. A dependency-free PNG reader (zlib+struct, all 5
  filter types) is checked into `.qa-loop/scratch/qa-worker-1/png.py` with `diff.py`
  (bbox of changed pixels), `diffmap.py` (per-row-band diff extents) and `bdiff.py`
  (board-only diff, native rows 800+ = pt 267+, skips status bar/header/toolbar). Copy
  these instead of rewriting: pixel-exact board comparison verifies Replay/Undo restore
  with ZERO image tokens.
- Verifying "board restored" by eye is unreliable; by pixel it is exact. Expect 0-70
  differing subpixels between two truly identical boards (card borders shift <1 native px
  between renders) and >30,000 significant-delta pixels for a real card move. Threshold:
  count pixels with per-channel delta >= 60.
- Cheap Moves-counter read: `sips -c 80 210 --cropOffset 225 800 <shot>.png` then
  `sips -z 90 236` — a ~5 KB strip showing "Moves N", far cheaper than a header crop.
- Confirmed tap targets on a no-HUD board, deal #910,172: col5 bottom of a 6-row column
  (273,620), col6 bottom (321,620), col3 bottom of a 7-row column (175,650), col7 bottom
  6-row (370,620) and 5-row (370,590). Formula `y = 425 + 30*idx + 45` held every time.
- Undo does NOT rewind the elapsed clock (Moves 0 at Time 5:45 after 5 undos); Replay
  does reset it to 0:00. Both look intentional — don't file the first as a bug.

## Chunk wf-4-1 notes (round 1, loop 3) — reaching a finishable board

- **The old "demo line then Stop" recipe above is STALE.** `demoPill(... Stop/Done) { game.restartDeal() }`
  — both re-deal a fresh board, so a demo can never hand you an assisted position.
- **Working recipe: inject a save into UserDefaults.** `Game.SavedGame` is JSON in key
  `causeway.game` (fields: seed, tableau, cells, up, down, moveCount, elapsed, started,
  challengeDay?, telem?). `restore()` validates 52 unique cards and refuses a complete board,
  then calls `runAutoplay()` + `maybeAutoFinish()` — so a finishable injected board prompts at launch.
  Scripts (copy them, don't rewrite): `.qa-loop/evidence/round-1/wf-4-1/mkstate.mjs` (replays a
  seed's bronze line from `data/daily-solutions.json` to step N and emits the save JSON; deal
  **#10011 becomes finishable after step 70**, and step 95 leaves 3 cards) and `inject.sh`.
- **Order is critical** (cost me two wasted runs): `simctl terminate` → `simctl spawn <udid>
  launchctl kickstart -k system/com.apple.cfprefsd.xpc.daemon` → write the plist → `simctl launch`.
  Writing the plist first is silently reverted by cfprefsd's cached copy, and `killall` does
  not exist in the iOS runtime. Plist: `$(xcrun simctl get_app_container <udid> <bid> data)/Library/Preferences/<bid>.plist`
  (python3 `plistlib`, value = raw JSON bytes). You can inject `causeway.autoplay` (bool) and
  `causeway.autofinishmode` ("ask"/"on"/"off") in the same write to pin the mode before launch.
- Geometry confirmed live: auto-finish alert buttons `Not yet` (128,497) / `Finish` (273,497);
  win-overlay `Play deal #N` (125,488) / `Random` (238,488) / `Close` (314,488) still correct.
  Auto-finish pill x≈60 hits it for all three labels; the `Finish` pill sits at (167,175).
- Auto-finish mode cycles **Ask → Off → On → Ask** (one tap Ask→Off).
- `Won` counts DISTINCT deals (WinStore is a seed→record map), so re-winning the same deal
  does not increment it — don't file that as a bug.

## Chunk wf-5-1 notes (round 1, loop 3)

- `sips -c H W --cropOffset Y X` gave inconsistent origins here; a dependency-free
  cropper is checked in at `.qa-loop/scratch/qa-worker-1/crop.py`
  (`python3 crop.py src.png dst.png x0 y0 x1 y1`, args in DEVICE POINTS, native = 3x).
  Cropping a region is ~1/10th the image tokens of a full frame — use it for every
  checkpoint read.
- **Winning a DAILY deterministically:** extend the wf-4-1 injection recipe with
  `challengeDay` + a faithful `telem`. `.qa-loop/scratch/qa-worker-1/mkdaily.mjs
  <seed> <dayIndex> <out.json> [step]` replays the bronze line, rebuilds
  `telem.foundationOrder` from the per-move up[]/down[] deltas, and writes the save;
  `.qa-loop/scratch/qa-worker-1/inject.sh <save.json> [ask|on|off]` writes it plus
  `causeway.autofinishmode`. With mode `on`, `simctl launch` cascades straight to the
  win overlay — a scored daily win in ~15 s.
- Deal #10,011's bronze line is finishable after step 70 and earns Bronze+Silver but
  NOT Gold (`suits-top-down`: suits 0 and 3 send the Ace home before the King) — a
  ready-made mixed-tier fixture.
- Daily-sheet geometry, sheet at top: `Done` (349,101), `Play`/`Replay to improve`
  (201,490). Reopening the sheet always resets scroll to the top AND resets the
  selected day to Today. Calendar cell for Aug D (2026): x = 42+53.4*((D-2) mod 7),
  y = 763 + 48*(...) at that top scroll position; re-read after any scroll.
- Deal numbers are grouped in the Daily sheet ("Deal #10,011", SwiftUI
  LocalizedStringKey Int interpolation) but ungrouped on the board pill
  ("Deal #10011"). Cosmetic; not filed.

## Chunk wf-6-1 notes (round 1, loop 3)

- **MCP `touch_path` does NOT drag a card** on this build/tool combo — a 6-point path with a
  long final hold left 110 filmstrip frames unchanged on a *playable* board. `swipe` (with an
  explicit `duration`, e.g. 4.0 s for a slow drag) does. Use `swipe` for every drag test; a null
  `touch_path` result proves nothing.
- **MCP call latency vs a host filmstrip:** a background `simctl io screenshot` loop runs at
  ~0.24 s/frame, but the MCP action does not start until ~7-9 s after you launch the loop. A
  14-frame film (~3.4 s) finishes BEFORE the gesture. Use >=110 frames (~26 s) to be sure you
  span it, and always run a positive control at the same timing before believing a null.
- **The demo bar shifts the whole board down ~+55 pt** (tableau card i top = 480 + 30*i instead
  of 425 + 30*i; free cells move y 296 -> ~350). Demo pills: Next (236,263) Start/Pause (295,263)
  Stop (357,263); paused/2-line: Resume (289,265); completion banner: Done (356,265).
- Cheap exact geometry: `.qa-loop/scratch/qa-worker-2/col.py <shot.png> <x_pt>` prints every
  card top edge in a column in device points (pure-python PNG scan, no image tokens).
  `bbox.py a.png b.png` prints changed-pixel count + bbox in points — use it instead of eyeballing.
- md5 of a `sips`-cropped board region is a valid "board unchanged" test, but only one-way: the
  background art/cloud makes two visually identical boards hash differently, so inequality is
  not evidence of a move (use bbox.py).

## Chunk wf-7-1 notes (round 1, loop 3)

- **Clearing the deal field fast:** MCP `touch_path` with points
  `[(331,772), (331,772, dt_ms 3000), (331,772, dt_ms 500)]` long-presses backspace and
  key-repeats away a 10-digit value in ONE call. Beats 6-10 separate `tap` calls.
  (`touch_path` still does not drag cards — see wf-6-1 — but it does hold a key.)
- Deal-alert keypad, measured on this build (device pt): columns x = 67 / 200 / 331;
  rows y = 610 (1 2 3), 665 (4 5 6), 720 (7 8 9), 772 (0, backspace at x 331).
  Cancel (129,389), Play (274,389). Field y ~ 325. Pad is already up on open.
- With an empty field the alert shows placeholder `1–1,000,000`; the field is prefilled
  with the current seed, caret at END and NOT selected, so a typed digit appends.
- A ten-digit deal number ("Deal #4294967295") widens the pill enough to push the
  toolbar to THREE rows (Wins / How to play drop to y≈216). Re-read the row after
  loading a big seed.
- Cheapest correctness check for "did the right deal load": crop pt y 418-460 full width
  (`crop.py shot.png out.png 0 418 402 460`) to read all eight top-row cards, then compare
  with `tests/engine.mjs deal(seed)`. Suit index mapping is **0=♠ 1=♥ 2=♦ 3=♣**.

## Chunk wf-6-2 notes (round 1, loop 3)

- Daily-sheet geometry with the sheet at top (no scroll): `Done` (350,101), `Play` (201,490),
  demo pills row y≈565 (y≈551 when the Gold objective fits one line): Clear x≈114/126,
  Silver x≈200, Gold x≈291 (2 pills) / x≈315 (3 pills). Re-read after any label change.
- Calendar cell for Aug D 2026 at that scroll position: **x = 40 + 53.5·((D-2) mod 7),
  y = 722 + 41·((D-2) div 7)** (verified: Aug 10 → (94,763), Aug 17 → (94,795-805),
  Aug 22/today → (361,795)). Future days are inert — tapping Aug 23 changed nothing.
- The "End your daily attempt?" alert: `Keep playing` (127,516), `Show demo` (275,516).
  It fires from any tier pill and remembers which pill you tapped.
- The demo bar headline WRAPS with tier+objective text, so the pills move: 1 line → y≈263,
  2 lines → y≈265, 3 lines (today's Gold) → y≈272. Read them per demo, don't reuse.
- Silver demo pills exist only where `daily-solutions.json` has a distinct `silver` key
  (today #10011 has none; Aug 10 sandbox #561325499 has bronze 94 / silver 91 / gold 113 —
  a good 3-pill fixture). Demo-bar totals equal those token counts exactly.
- Cheapest "board unchanged / re-dealt" proof: `bbox.py a.png b.png`. Two truly identical
  frames differ only in the status-bar clock band (x 57-92, y 27-38).

## Chunk wf-8-1 notes (round 1, loop 3)

- TC-8.4's documented fixture (`node /private/tmp/qaw2r1wf8/gen2.mjs`, deal #10169, 28 real
  drags) is **gone** — that dir does not exist. Use injection instead; it is ~10x cheaper.
- `mkstate.mjs`'s relative imports resolve from the SCRIPT's dir, so running the copy in
  `.qa-loop/evidence/round-1/wf-4-1/` fails with ERR_MODULE_NOT_FOUND. Fixed copy (absolute
  imports) + a udid-parameterised injector are at
  `.qa-loop/evidence/round-1/wf-8-1/{mk82.mjs,inj.sh}`; `inj.sh <save.json> [ask|on|off]
  [autoplayTrue|autoplayFalse]` writes causeway.game + both settings keys and launches.
- **You can hand-craft an arbitrary board**, not just replay a solution line: `restore()`
  only checks 52 unique cards, `up[s] < down[s]`, and not-complete. `mk82.mjs` builds one that
  isolates a single autoplay decision. Useful for any "does feature X fire here" test.
- `isSafeAutoplay` is much stricter than FreeCell: a card is safe only if BOTH opposite-colour
  suits have already resolved rank-1 and rank+1. So **an Ace is never auto-played on a fresh
  deal** — do not expect autoplay to fire early; craft a state with foundations advanced.
- Deal #10011 (today's daily) becomes finishable at bronze step 70; injecting step 69 then
  swiping (224,590) -> (370,495) plays token `T,4,5,7` (col4 idx5 2-card supermove -> col7)
  and triggers the Ask prompt. Cascade from there ends at Moves 93.
- The Auto-finish/Auto-play pills have **no long-press menu** — a 1.8 s hold registers as a
  plain tap and advances the cycle. Don't waste calls looking for a context menu.
- With the `Finish` pill present the toolbar is 3 rows: row2 = Auto-finish (68,175),
  Finish (167,175), Deal #, Daily; row3 = Wins, How to play (y≈216). Auto-finish pill x=62
  hits all three labels.
- `How to play` (RulesView in Views/Extras.swift) documents Goal/catch/Tableau/Free cells/
  Controls only — **no Auto-play or Auto-finish text anywhere in the app**.

## Chunk wf-9-1 notes (round 1, loop 3) — populating Wins cheaply

- **Any deal can be won in ~10 s without a solution line.** `restore()` never checks the
  board against the seed, so inject a synthetic near-win: tableau `[[K♠],[K♥],[K♦],[K♣],[],[],[],[]]`,
  `up=[12,12,12,12]`, `down=[14,14,14,14]`, `cells=[null,null,null]`, `started:true`, plus any
  `seed`/`moveCount`/`elapsed`. With `causeway.autofinishmode="on"` the launch cascades to the win
  overlay and records a genuine win. Scripts: `.qa-loop/scratch/qa-worker-2/mkwin.py <seed> <moves>
  <secs> <out.json>` + `inject2.sh <save.json> [on|ask|off]` (same terminate → cfprefsd kickstart →
  plist → launch order as wf-4-1). Recorded moves = injected moveCount + 4 finish moves.
- Bulk wins for range/scroll tests: write `causeway.wins` directly (`{"<seed>":{"moves":Int,
  "secs":Int,"date":<apple-epoch float>}}`) — `.qa-loop/scratch/qa-worker-2/injwins.py`. 97 wins /
  35 ranges render as a 4-column chip grid with no scroll needed; a 61-row range detail scrolls fine.
- **Software keyboard never appears on this worker** (verified: also absent in Safari's address
  bar) — a hardware-keyboard/rig state, NOT an app bug; do not file it. Use MCP `text` to type;
  focus with a tap first. This contradicts the wf-1-1/wf-7-1 note that the deal keypad is "already up".
- `sips -Z N` scales by the LARGER dimension: on a 1206x2622 frame `-Z 620` yields 285x620, so
  img→device-pt factor is 402/285 ≈ 1.41, not 402/620. Getting this wrong wastes taps; prefer
  `sips -z 620 285` (explicit) or `crop.py` in points.
- Wins sheet geometry (sheet freshly presented, no scroll): Done (349,100), deal field (168,191),
  Play (358,191), first chip row centres y≈276 with 4 columns at x≈76/165/245/330, detail-list
  first row y≈193, back chevron (35,100).

## Chunk wf-10-1 notes (round 1, loop 3) — How to play / About

- On a FRESH install (no Finish pill) the toolbar is already **3 rows**: row1 y=135
  New game/Undo/Replay/Auto-play, row2 y=175 Auto-finish/Deal #/Daily/Wins,
  row3 `How to play` at **(55,214)**. The 2-row layout in the geometry table above only
  happens on narrower content; assume 3 rows on iPhone 17 Pro portrait.
- `How to play` sheet: `Done` at **(348,100)**. The whole sheet (Goal, The catch, Tableau,
  Free cells, Controls, About) **fits on one screen with no scroll** on iPhone 17 Pro — a
  swipe-up on the body moves nothing, so don't hunt for hidden content.
- Cheap evidence trick: `xcrun simctl io <udid> screenshot <file>` writes straight to the
  evidence dir without putting an image in context; then `sips -Z 560 --out small.png`
  and Read only the small one when you actually need to see it. Full frames are ~2 MB.
- Deal on fresh install here was #723811 (New Game randomises at first launch; it is NOT
  seeded from the daily). Use `Deal #…` if you need a pinned free-play board.

## Chunk wf-11-1 notes (round 1, loop 3) — Export/Import plumbing

- The Files sandbox "On My iPhone" backing dir on this worker is
  `.../Devices/<udid>/data/Containers/Shared/AppGroup/24DBEEB0-.../File Provider Storage`
  (`find <sim data> -name "Causeway-Stats*"` locates it after one Export). Drop hand-made
  `.json` fixtures there on the HOST and they appear instantly in the importer under
  Browse > On My iPhone — that is how you test "import a non-backup / edited file".
  It SURVIVES `simctl uninstall`, so an export made before a reinstall is still importable
  after it (exactly what a restore test needs).
- Exporter sheet has NO Cancel button: header is `<` / `…` / `Save` only. Cancel it with a
  swipe from (200,75) to (200,760). Save is at (350,110). Importer sheet DOES have an X at
  (320,110); its tabs are Recents/Shared/Browse at y=812 (Browse x=286), file tiles in a
  3-column grid at y=258, x = 67 / 200 / 330.
- Daily sheet: one swipe (200,700)->(200,250) scrolls BACKUP into view; Export ≈ (112,772),
  Import ≈ (300,772) — re-read after the note grows to two lines (everything shifts ~15 pt).
- To create app-authored stats fast, extend the wf-9-1 near-win injection with a
  `challengeDay` field (`.qa-loop/scratch/qa-worker-2/mkwin2.py <seed> <moves> <secs>
  <out.json> [day]` + `inject2.sh <save> on`): the app runs recordWin() AND
  recordChallengeResult(), so `causeway.daily` gets a real graded record — including for
  NEGATIVE sandbox day indices. Read both stores back with `plistlib` from
  `.../Library/Preferences/com.whimsicaldistractions.Causeway.plist` (terminate the app
  first so UserDefaults flushes).

## Chunk wf-13-1 (round 1, qa-worker-2)

- **Toolbar reflow is real and it bites:** with a 9-digit sandbox deal (`Deal #186441603`) the
  `Daily` pill moves from x≈279 to x≈311-315; tapping 279 opens the *Play a deal* alert instead.
  Read row 2 from a screenshot after every deal change.
- **Board geometry WITH the stacked daily HUD** (portrait, iPhone 17 Pro): tableau card i top
  y = 498 + 30i; grab a non-last card at y = 498+30i+14, the last card at +37. Foundations up-row
  y≈370, down-row y≈448 at x = 28/77/126/175 (♠♥♦♣); free cells y≈370 at x = 276/325/373.
  Tableau column centres are unchanged (28,77,126,175,224,272,321,370). A drop anywhere in the
  destination column's strip works — y=650 for a non-empty column, 560 for an empty one.
- `swipe` with `duration: 0.4` is a reliable card drag (20/20 landed); no press-and-hold needed.
- **Turn `Auto-play: Off` (one tap at 335,135) before replaying a scripted move list** — otherwise
  safe autoplay inserts moves and every later coordinate is wrong.
- Reaching an arbitrary board state cheaply: `tools/solver/rules.mjs` + `solve.mjs` reproduce the
  iOS deal exactly. A best-first search over `legalMoves` found a 19-move setup to a 6-card
  supermove on deal #186441603 (`.qa-loop/scratch/qa-worker-2/search5.mjs`, prints ready-made
  drag coordinates). Far cheaper than replaying a 76-token baked line.
- The app survives a SpringBoard restart: after the simulator dropped input ("likely rebooted",
  black screen), `xcrun simctl launch` restored the in-progress daily board, seed and HUD intact.
  If the MCP `launch` action fails with `disclaimer exited with code 143`, use `xcrun simctl launch`.

## Chunk wf-12-1 notes (round 1, loop 3) — HOW TO ROTATE (solved)

- **Rotation works; WF-12 need not be blocked.** Host routes are all dead (osascript/System
  Events has no Accessibility grant, `screencapture` no Screen Recording, `simctl` has no
  orientation verb, the guest has no AssistiveTouch and no `notifyutil`). The working route:
  the repo's `CausewayUITests` target is a `PBXFileSystemSynchronizedRootGroup`, so **a .swift
  file dropped into `ios/Causeway/CausewayUITests/` joins the target with NO pbxproj edit**.
  A test that only does `XCUIDevice.shared.orientation = .landscapeLeft` (no `app.launch()`)
  rotates the device live; **the orientation persists after the test process exits**, so you
  then drive the app in landscape with the normal MCP tool. Delete the file when done, and
  `git checkout -- ios/Causeway/Causeway.xcodeproj/project.pbxproj` afterwards — xcodebuild
  re-sorts the pbxproj (semantic no-op, but the tree must be left clean).
- Run it: `xcodebuild test -project ios/Causeway/Causeway.xcodeproj -scheme CausewayUITests
  -destination "id=<udid>" -derivedDataPath <SESSION scratchpad>/DD -parallel-testing-enabled NO
  -only-testing:...`. **`-parallel-testing-enabled NO` is mandatory** — without it Xcode runs on
  "Clone 1 of <device>" and SHUTS DOWN your worker. **DerivedData must live outside
  ~/Documents** (fileprovider xattrs → `CodeSign ... resource fork/Finder information` failure).
- **NEVER quit Simulator.app in a parallel run: quitting shuts down every booted device**
  (it killed qa-worker-2, iPhone 17 Pro and WeatherTimeline mid-round; recovery is
  `xcrun simctl boot <udid>` + ~30 s). `pkill -9` it instead if you must.
- **Landscape coordinate mapping for MCP taps** (tool still reports 402x874 = portrait):
  landscapeLeft: `portrait_x = 402 - land_y`, `portrait_y = land_x`.
  landscapeRight: `portrait_x = land_y`, `portrait_y = 874 - land_x`. Drag/tap/swipe all work.
  View a shot in reading order: `sips -r 270` (landscapeLeft) / `-r 90` (landscapeRight);
  helper `.qa-loop/scratch/qa-worker-1/land.sh <base> [width]` shoots+rotates+downscales.
- A landscape test dumping `app.debugDescription` from the same throwaway test gives EXACT
  element frames (rail viewport, card w/h, pill y) — far cheaper and more precise than pixels.
  Measured landscape frames: rail ScrollView {68,57.7,118x310} no HUD, {68,97,118x248} with the
  daily HUD/demo bar; pills pitch 32.3 from y=57.7 (no HUD); card 45x75.3 fresh, 43x72 with HUD,
  36x60.3 with a 13-card column; tableau x=398+49·i (no HUD), fan pitch 26.

## Chunk wf-13-2 notes (round 1, qa-worker-1)

- **Dynamic Type can be driven from the host:** `xcrun simctl ui <udid> content_size
  accessibility-extra-large` (underscore, NOT `content-size` — the hyphen form prints usage
  and silently does nothing). Takes effect live, no relaunch. Reset with `content_size large`
  and leave it there for the next chunk.
- The daily HUD is **byte-identical** across default and accessibility text sizes (md5 of the
  same crop matched), so screenshot diffing is a sound way to test text-size response here.
- Daily-sheet calendar y drifts with sheet scroll/restore: Aug 5's cell was at y=722 on the
  first open of the pass and y=746 on a later open. Crop 0,620-402,800 and read the row
  before tapping instead of reusing a remembered y.
- Aug 5 (dayIndex -7, seed 191,924,978) has exactly two demo lines in daily-solutions.json
  (bronze + gold, no silver), and the sheet correctly shows two pills: `🥉 Clear`, `🥇 Gold`.
  With the sheet freshly opened on that day the Gold pill sits at (287,566).

## Chunk perf (round 1, loop 3) — measuring latency without screenshots

- **`xcrun simctl io <udid> recordVideo` is variable-frame-rate: it emits a packet ONLY when
  the display changes.** `ffprobe -v error -select_streams v -show_entries packet=pts_time
  -of csv=p=0 x.mov | sort -g` is a frame-accurate change timeline for ~0 tokens. A gap in
  the list = the screen was literally frozen that long; a 20 s idle recording with ONE packet
  proves nothing repainted. Read the tap time off the video (first packet of the response
  burst), so MCP round-trip latency never enters the number. Extract a frame with
  `ffmpeg -ss T -i x.mov -frames:v 1 -pix_fmt rgb24 f.png` (**`-pix_fmt rgb24` is required**
  or `crop.py`/`png.py` throw IndexError; `-vsync` no longer exists in this ffmpeg).
- **MCP `tap` holds the finger ~0.49 s.** Anything that commits on touch-UP (card smart-move,
  button action) therefore looks 0.49 s slow. For latency probes use a zero-length
  `swipe` (`x2=x, y2=y, duration: 0.05`) — measured app response then drops to 0.069 s.
- Packet spacing is NOT a frame-rate proxy: a single-card move shows ~22 fps spacing while a
  23-card cascade shows ~60 fps. This rig proves stalls, never dropped frames.
- Background the app deterministically without MCP: `xcrun simctl launch <udid>
  com.apple.mobilesafari`; re-launching Causeway foregrounds the SAME pid (verify with pgrep)
  — it does not restart, so state/clock tests are valid.
- `bbox.py` samples every 3rd pixel with threshold 60, so it reports "0 changed" for h264
  encoding noise (max delta ~48) — that is the right behaviour for "did the UI change", but
  do not use it to detect a subtle press highlight.
- Injection recipe works from this dir: copy `wf-4-1/mkstate.mjs` into
  `.qa-loop/scratch/qa-worker-1/` (3 levels below the repo root, so its `../../../tools/...`
  imports resolve) and run it from the repo root; `wf-8-1/inj.sh` already carries qa-worker-1's
  udid. A hand-built save with a 15-card column 0 (`tall16.json`) is a ready tall-column
  fixture — note the board does NOT uniformly shrink even at 16 cards in portrait.
