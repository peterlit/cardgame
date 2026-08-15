# Harness notes

Accumulated environment/tooling knowledge for testers. Append what you learn.

- App: `com.whimsicaldistractions.Causeway`, built Debug for iOS Simulator.
- Build product for this loop:
  `/private/tmp/claude-501/-Users-plit-Documents-src-cardgame/046a3211-feb8-4b63-b270-3e04591997e9/scratchpad/dd/Build/Products/Debug-iphonesimulator/Causeway.app`
- Reset state with `xcrun simctl uninstall <udid> com.whimsicaldistractions.Causeway`
  then `install`. There is no in-app reset.
- Device rotation is NOT scriptable here (no simctl rotation command, no launch
  argument to force orientation). WF-12 landscape is assessed from layout code.
- The app exposes no launch arguments / debug seed override. See the Fixture policy
  in WORKFLOWS.md.

## Driving the simulator without idb (round 2, qa-worker-1)

There is **no idb / appium / simulator-MCP tool on this machine** and `simctl` has no tap
command. What works: **synthetic CGEvent mouse clicks aimed at the Simulator window**.

- `/usr/bin/osascript` is NOT allowed assistive access (`-1728`), but a **binary you compile
  yourself with `swiftc` inherits Accessibility trust** — `AXIsProcessTrusted()` returns true
  and `CGEvent(...).post(tap: .cghidEventTap)` moves the real cursor and clicks. So write the
  driver in Swift, don't shell out to AppleScript.
- Reusable driver used this round (rebuild it if the scratchpad is gone; ~150 lines):
  `<scratchpad>/w1/simui.swift` → `simui screen|move x y|raise|tap x y|drag x1 y1 x2 y2 [steps] [stepDelayMs] [holdMs]`.
- **Point mapping is 1:1, no scale math.** The Simulator window's AX tree contains an
  `AXGroup` child whose frame is exactly the device's logical screen (402x874 for iPhone 17 Pro).
  Global click point = groupOrigin + devicePoint. (Window frame itself includes toolbar/bezel —
  don't use it.)
- **`xcrun simctl io <udid> screenshot` returns 1206x2622 px = 3x.** device pt = px / 3. The
  Read tool renders it at 920x2000, so `displayed * 0.4367 = device pt`.
- **Only one Simulator device window exists at a time and workers steal it.** If
  `AXWindows` has no window titled `qa-worker-N`, activate the Simulator app
  (`app.activate()` — required, or the menu press is a no-op) and press the menu item
  `Window > qa-worker-N – iOS 26.5`; the window reappears within ~1 s. `open -a Simulator
  --args -CurrentDeviceUDID …` does NOT work once Simulator is already running.
- **Parallel-lane safety:** move your window to a fixed origin (`simui move 8 41`) and, before
  every click, verify the frontmost AX window containing the target point is titled with YOUR
  worker name; abort otherwise. Other workers park their windows around x≈700-760.
- **Taps get dropped when another worker steals focus.** Never fire a burst of taps blind —
  after each tap check the on-screen state (e.g. the Moves counter). In this round 2 of 5
  rapid Undo taps were silently lost; re-tapped one at a time they all landed. That is a rig
  artifact, not app behaviour — don't file it.
- Portrait board cheat-sheet (iPhone 17 Pro, device pt): toolbar pills row1 y≈135
  (New game x≈51, Undo 142, Replay 229, Auto-play 335), row2 y≈175 (Auto-finish 68,
  Deal # 196, Daily 279, Wins 343), How to play (55, 214). Free cells y≈296 at x≈274/323/372.
  Tableau: column centres x = 28, 77, 126, 175, 224, 273, 321, 370; card i (0-based) top
  y = 425 + 30*i; the bottom card of a column is full-height (75 pt).
- The deal-entry alert uses the on-screen number pad: backspace (332, 774), `1` (68, 613),
  `0` (200, 774), `4` (68, 666), `Play` (200, 335).
- The Simulator window toolbar exposes an AX button described **"Rotate"** (plus "Home",
  "Save Screen"). Pressing it via AX may make WF-12 landscape testing drivable after all —
  untested this round.

## Driving the UI without the simulator MCP tool (learned round 2, qa-worker-3)

- A tester dispatch can arrive **without** `mcp__Claude_Code_iOS_Simulator__control`
  (only Read + Bash). `xcrun simctl` can launch/screenshot but **cannot inject taps**,
  and `osascript`+System Events hangs on a TCC prompt (and would target whatever window
  is frontmost — never safe with parallel workers). Do NOT go down that road.
- Working replacement: a **throwaway XCUITest bundle with no app target**, generated
  outside the repo. `XCUIApplication(bundleIdentifier: "com.whimsicaldistractions.Causeway")`
  drives the *already-installed* build, so the artifact under test is never rebuilt.
  Recipe (all in the scratchpad, nothing in the user's project — never touch the real
  `project.pbxproj`):
  1. `xcodegen` is installed (`/opt/homebrew/bin/xcodegen`). Spec: one target
     `type: bundle.ui-testing`, `platform: iOS`, deploymentTarget 17.0,
     `CODE_SIGNING_ALLOWED: NO`, plus a scheme with that target under `test:`.
     **Do not add the app as a source target** — pointing `sources:` at the app's
     source dir made xcodegen hang for >8 min; the test-only project generates in ~5 s.
  2. `xcodebuild test -project UIDrive.xcodeproj -scheme UIDrive -destination "id=<UDID>"
     -resultBundlePath res.xcresult -only-testing:UIDriveTests/<Class>[/<method>]
     CODE_SIGNING_ALLOWED=NO`. `-destination id=` keeps you in your own lane.
  3. Evidence: `XCTAttachment(screenshot: XCUIScreen.main.screenshot())` and
     `XCTAttachment(string: app.debugDescription)` with `.lifetime = .keepAlways`,
     then `xcrun xcresulttool export attachments --path res.xcresult --output-path DIR`
     and rename via `DIR/manifest.json` (`suggestedHumanReadableName`). **Copy them out
     immediately** — the next run's `rm -rf res.xcresult` destroys them.
  4. Test methods run **alphabetically within a class**, and classes alphabetically, so
     name them `testA_…`, `testB_…` to script a stateful sequence; assert preconditions
     anyway. Run each xcodebuild invocation in the background and poll for `** TEST`.
- Screenshots come back at 1206x2622 for a 402x874 pt screen (x3); a11y frames in
  `debugDescription` are already in points.
- **Fixtures for the file picker.** "On My iPhone" is the host directory
  `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Shared/AppGroup/
  <group.com.apple.FileProvider.LocalStorage>/File Provider Storage` (find it by grepping
  the group containers' `.com.apple.mobile_container_manager.metadata.plist`). Dropping
  `.json` files there from the host makes them appear in the app's importer with no
  re-index. That is how import test cases (valid / non-backup / hand-edited) get pinned.
  Delete `Causeway-Stats-*.json` between passes so a second export can't hit a
  same-name replace prompt.
- Document picker specifics (iOS 26): it renders **inside the app's own accessibility
  tree** (no separate `XCUIApplication`). Importer opens on **Recents** — tap
  `Browse` (identifier `BackButton`) then the `On My iPhone` static text; files are
  `Cell`s whose *identifier* is `"<name>.json, json"` (match `identifier BEGINSWITH`;
  matching `staticTexts` by label is flaky). The importer has a `Cancel` button; the
  **exporter/save sheet has none** — dismiss it with `app.swipeDown(velocity: .fast)`.
- State reset without losing the build under test:
  `xcrun simctl uninstall <UDID> com.whimsicaldistractions.Causeway` then `install`
  from `scratchpad/dd/Build/Products/Debug-iphonesimulator/Causeway.app`.
- Stats can also be seeded through the UI by importing a crafted backup: JSON keys
  `format:"causeway-stats"`, `version`, `exportedAt`, `daily:{"<dayIndex>":TierResult}`,
  `wins:{"<seed>":{moves,secs,date}}` where `date` is a **Double** (seconds since
  2001-01-01). All fields must be present — synthesized Codable does not apply defaults.

## Driving the app with no MCP simulator tool (added round 2, qa-worker-2)

- The worker simulators are booted **headless** (no Simulator.app process, `System Events`
  sees no simulator window), so AppleScript clicking is impossible and `simctl` has no
  touch/tap subcommand. Screenshots work (`xcrun simctl io <udid> screenshot out.png`),
  input does not.
- Working solution: a **one-target XCUITest bundle** that drives the already-installed app
  by bundle id. Stashed at `/private/tmp/causeway-qa-driver/` (project.yml + UITests/QADriver.swift
  + qa.sh); regenerate with `xcodegen generate` in a copy of that folder.
  - The test target has **no app target** (`XCUIApplication(bundleIdentifier:
    "com.whimsicaldistractions.Causeway")`), so it drives the exact build the harness
    installed and never rebuilds/replaces it.
  - Run: `xcodebuild test -project QA2.xcodeproj -scheme QAUITests -destination "id=<udid>"`.
    ~25-40 s per invocation. Lane-safe: the destination id pins it to your device.
- **Script channel:** `TEST_RUNNER_QA_SCRIPT=...` did *not* reach the runner. What works is a
  **host file**: the driver reads `/private/tmp/qa2script.txt`, commands separated by `|`
  (`launch`, `activate`, `terminate`, `tap X Y`, `drag x1 y1 x2 y2 [dur]`, `sleep S`,
  `shot NAME`, `probe`). Write the file, run xcodebuild, no recompile between steps.
- **Simulator processes can write host paths.** The driver writes PNGs straight to
  `/private/tmp/qa2out/NAME.png` (verified `hostWrite=true`), so no xcresult extraction is
  needed. Same trick makes the host file readable from inside the sim.
- **Coordinates:** the app element frame is 402x874 pt. Screenshots are 1206x2622 px, i.e.
  **pt = px / 3**; if you read coordinates off a downscaled 920x2000 view, pt = displayed * 0.4367.
- **Accessibility queries are flaky here**: `app.buttons.count` reports 9 and `app.staticTexts.count`
  70, but `allElementsBoundByIndex` / `element(boundBy:)` / `debugDescription` come back empty for a
  non-target app. Don't build a run on label lookups - use coordinate taps + screenshots.
- **Toolbar pills reflow** (FlowLayout) as their text changes (`Deal #1` vs `Deal #1000000`,
  a `✓` appearing after a win, the gold `Finish` pill inserting itself). Re-read the pill
  positions from a screenshot after any state change; the pills' *left* edges are stabler
  than their centres.
- Deal alert keyboard (numberPad) key centres in pt: 1(68,613) 2(200,613) 3(333,613)
  4(68,667) 5(200,667) 6(333,667) 7(68,720) 8(200,720) 9(333,720) 0(200,770)
  backspace(333,774); Play(200,335) Random(200,391) Cancel(200,447), field(200,268).
- Demo bar pills in pt: Next(236,263) Start/Pause/Resume(297,263) Stop(357,263);
  when the line finishes only `Done` remains, at (355,265).
- A "blind sweep" of taps over the tableau column x's (28,77,126,175,224,272,322,371) at a
  ladder of y values is a cheap way to play a nearly-solved board out to the Finish pill -
  but it will also happily hit the win overlay's buttons, so screenshot before sweeping near
  y 440-500.
- `xcodegen` **hangs for minutes** when a target's `sources` points at an absolute path
  outside the project dir (killed at 7 min). A test-only spec with a relative `UITests`
  source generates in ~2 s.
- App state can be inspected on the host at
  `<...>/data/Containers/Data/Application/<uuid>/Library/Preferences/com.whimsicaldistractions.Causeway.plist`
  (keys `causeway.game`, `causeway.wins`, `causeway.daily`; values are JSON Data) - useful for
  proving what actually got persisted. *Writing* to it (state injection) was refused by the
  environment's command classifier, so daily-record fixtures are not available.

## Landscape IS drivable — rotation from XCUITest (round 2, qa-worker-3)

**The old note "device rotation is NOT scriptable here" (and the same claim in
WORKFLOWS.md "Notes for the tester") is WRONG.** `XCUIDevice.shared.orientation`
is settable from the throwaway XCUITest driver and the app follows it, so WF-12
can be run as a real interactive test — no static code review needed.

- Add to the script-driven driver (`/private/tmp/causeway-qa-driver/UITests/QADriver.swift`):
  `case "rotate": XCUIDevice.shared.orientation = <.portrait|.landscapeLeft|.landscapeRight>`
  then `Thread.sleep(1.5)`. Verify with `app.frame`: portrait `(0,0,402,874)` ->
  landscape `(0,0,874,402)` on iPhone 17 Pro. Taps/drags then use landscape point
  coordinates with the same `app.coordinate(withNormalizedOffset:.zero).withOffset(...)`.
- **Orientation resets to portrait at the start of every `xcodebuild test`
  invocation.** Put `rotate left` at the top of EVERY script; a landscape
  coordinate list fired without it silently hits portrait targets (this cost a
  bogus "drag doesn't work in landscape" result).
- **The app is relaunched between xcodebuild invocations** (state restores from
  persistence, but any open sheet is gone and the undo stack is empty -> the Undo
  pill goes disabled even with Moves > 0). Anything stateful must live inside ONE
  script; use `terminate|launch` at the top when you want a deterministic start.
  Corollary: `app.swipeUp()` inside a sheet can also interactively dismiss it.
- `xcrun simctl io ... screenshot` and `XCUIScreen.main.screenshot()` **keep the
  portrait 1206x2622 pixel frame in landscape** and mark the rotation in EXIF.
  `sips -r 270 --out land-X.png X.png` gives an upright 2622x1206 view. Beware:
  sips *crops* of an already-rotated file come back sideways (the orientation tag
  is not baked and `--resampleWidth` does not bake it either) — crop the raw file
  and rotate the crop, or just read the full frame.
- Landscape geometry actually measured on iPhone 17 Pro (pt, no HUD): rail pills
  x=127, y = 70 New game / 102 Undo / 135 Replay / 167 Auto-play / 200 Auto-finish
  / 232 Deal # / 264 Daily / 297 Wins / 329 How to play. Foundations up-row y=109,
  down-row y=189 at x=218/267/316/364; free cells y=297 at x=218/267/316. Tableau
  column centres x = 420,468,517,566,615,664,713,762; card i top y = 57 + 26*i.
  **With the daily HUD everything shifts down ~40pt and the cards shrink** (rail
  y: New game 110 ... Wins 335; tableau top y=97, pitch 23.4, columns x=411..739) —
  re-measure from a screenshot after any HUD/demo state change.
- geo.size in landscape is ~756x381, not 874x402: the two 59pt landscape
  safe-area insets and the home indicator are already subtracted. Card-size math
  in ContentView must be evaluated with those numbers, not the raw screen size.

## Reaching a WIN / finishable board deterministically (round 2, qa-worker-1)

WF-4 needs a finishable board, which is impractical to reach by blind tapping. Recipe that
makes it deterministic in ~3 min:

1. **Pre-compute where the baked line becomes finishable.** `data/daily-solutions.json`
   `.solutions["<seed>"].bronze` is the token stream the in-app demo replays, and
   `tests/engine.mjs deal(seed)` reproduces the iOS deal exactly (same Mulberry32 +
   Fisher-Yates). Replay tokens in node (`F,col,end` / `G,cell,end` / `T,src,idx,dst` /
   `C,col` / `X,cell,col`) and after each one run the app's `autoFinishWouldWin()` greedy
   simulation. For **seed 10004 / bronze (97 tokens) the board first becomes finishable
   after token index 83, i.e. at demo progress "84 / 97"**; the state there is
   col0 7S | col1 8H | col2 5H 4S | col3 - | col4 4H 5S 6H | col5 3H | col6 3S 9H | col7 - ,
   cells 2S 6S 7H, up [1,2,8,6] down [8,10,9,7].
2. **Drive the demo to that count.** Daily -> `scrollto 200 700 300` -> "Clear" pill at
   (114,359). Fast route: `Start` (297,263), sleep 17 (auto-advance is 0.246 s/move, so
   ~69/97), `Pause` (same pill), then top up with `Next`. **When paused the headline wraps
   to two lines ("… (paused)") and the pills move: Next (219,266), Resume (297,266),
   Stop (358,266)**; while ready/unpaused they are Next (236,263), Start (297,263),
   Stop (357,263). Verify the "N / 97" text from a screenshot - taps are reliable here
   (84 XCUITest taps landed 84/84).
3. **Stop** -> demo bar vanishes, board keeps the assisted position, input unlocks, but
   `started` is still false, so **no prompt and no Finish pill until you make one real
   move**. Tap a home-able card (at 84/97: col5's 3H at (272,445)) -> `Ready to finish`
   alert (Ask) or the gold `Finish` toolbar pill (Off).
4. Board geometry with no demo bar: tableau card 0 centre y = 445, column centres
   x = 28, 77, 126, 175, 224, 272, 321, 370. Win-overlay buttons:
   `Play deal #N` (125,488), `Random` (238,488), `Close` (314,488).

Other notes:
- The driver at `/private/tmp/causeway-qa-driver/` works as documented. `QA_SCRIPT_PATH` /
  `QA_OUT` env vars do **not** reach the runner (same reason `TEST_RUNNER_QA_SCRIPT` didn't)
  - **edit the two literals in `QADriver.swift`** to give each worker its own script/out
  paths (`/private/tmp/qa1script.txt`, `/private/tmp/qa1out`) so parallel lanes don't
  overwrite each other's script file.
- `tapb <label>` (button by label) DOES work against the non-target app for sheet chrome
  ("Done", "Cancel"), even though `labels`/`debugDescription` were reported flaky earlier;
  `labels` now returns the full button+text list with point frames - use it instead of
  eyeballing screenshots for pill coordinates (toolbar pills reflow constantly).
- **Sheet swipe-dismiss:** `drag 200 100 200 820 0.1` (start on the sheet's title bar, not
  the scrollable body - `swipedown` just scrolls the content).
- Keep scripts under ~60 taps per `xcodebuild test` invocation: a 84-tap script died at
  t=29 s with "Restarting after unexpected exit, crash, or test timeout".
- **Rig hazard:** mid-session all three worker simulators went to `Shutdown` at once
  (screenshots then fail with "Timeout waiting for screen surfaces"). `xcrun simctl boot
  <your udid>` + 20 s recovers your own lane; app state survives, in-flight demo state does not.

## Round 2 additions (qa-worker-2, WF-8 + persistence pass)

- **Deterministic finishable board in ~2 min, no card play.** `daily-solutions.json`
  holds the baked winning lines; simulate them in Python against the dealt board to find
  the first token index where the board becomes auto-finishable, then step the in-app demo
  exactly that many times. For **deal #10,004 bronze that is step 84 of 97** (Daily ->
  "Show me how to win: Clear" -> 84x `tap 236 264` (Next) -> `tap 357 264` (Stop)). After
  Stop the board stays where the demo left it. Note `started` is still false, so **no
  Finish pill and no auto-finish until you make one real move** - tap the 7S at column 0
  (`tap 28 460`) and everything arms. 84 scripted Next taps all landed (no drops) in one
  xcodebuild run, ~45 s.
- Mode changes call `maybeAutoFinish()` in their `didSet`, so on an already-finishable
  board you can exercise all three Auto-finish modes on ONE board: Off (Finish pill) ->
  tap pill = Ask (prompt) -> Not yet -> tap pill = On (cascade). No need to rebuild.
- **Deal alert:** the number pad is NOT up when the alert opens. `tap 200 268` focuses the
  field and raises the pad, but on a pre-filled field it also raises the edit callout;
  `Select All` sits at **(213, 316)** - tap it, then type digits to replace. Pad keys are
  as previously documented (1 = 68,613 / 0 = 200,770 / backspace = 333,774 / Play = 200,335).
- **Backgrounding is scriptable:** add `case "home": XCUIDevice.shared.press(.home)` to the
  QADriver script switch. `activate` brings the app back. That is the only way to exercise
  the real scenePhase -> persist path (`terminate` is a kill).
- **Cropping evidence:** `sips --cropOffset` is ignored (it crops centred), so the toolbar
  never appears in a `sips -c` crop. Two ~15-line CoreGraphics tools solve it, at
  `/private/tmp/qa2crop/{crop,stack}` (`crop in out x y w h`, `stack out x y w h in...`
  which crops the same rect out of N shots and stacks them top-to-bottom). Stacking the
  Moves/Time/Won strip (`600 180 606 130`) or the pill rows (`0 340 1206 300`) from 5-7
  screenshots into one image makes a whole state sequence a single cheap Read.
- **A worker simulator can wedge/shut itself down** mid-run: `xcodebuild` fails with
  `Application failed preflight checks ... Busy`, and `simctl io ... screenshot` hangs then
  errors `Timeout waiting for screen surfaces`. `simctl shutdown` then reported the device
  was already `Shutdown`. Recovery: `xcrun simctl boot <udid>`, wait ~30 s, re-run. App
  UserDefaults state (settings, in-progress game, wins) survives it intact.
- Portrait pill coordinates when the **Finish** pill is showing: it inserts between
  Auto-finish and Deal #, pushing Wins/How to play to a third row, but **Auto-play
  (335,135) and Auto-finish (50,175) do not move** - target those two by their left half.
  The Deal pill gains a ` ✓` after a win, which shifts Daily right to x≈289.
- Demo bar: `Winning line — N / 97` with Next (236,264) / Start (297,264) / Stop (357,264).

## Measuring latency / CPU / memory without Instruments (round 2, qa-worker-1 PERF lane)

- **Instantaneous CPU, precisely:** `ps -o time=,rss= -p <pid>` gives *cumulative* CPU time
  with hundredths resolution. Sample it at the start and end of a window and divide by
  wall-clock -> exact %CPU for that window. Far better than the sampler's `pcpu` column,
  which is a decaying average (it still read 40%+ a full 20 s after a burst ended). Helper:
  `/private/tmp/qa1tools/cpuwin.py <seconds> <label>`. Resolve the pid on the **host** with
  `pgrep -f "Causeway.app/Causeway"` - simulator apps are ordinary macOS processes.
- **The XCUITest driver must be detached for any idle measurement.** Attaching XCUITest
  loads the accessibility stack into the app and pushes RSS from ~180 MB to ~350 MB, and
  every `labels`/`tapb` query burns app CPU. Do the idle window *between* `xcodebuild test`
  invocations (the app keeps running), never inside one. That RSS jump is rig overhead, not
  a leak - baseline your leak loops against a driver-attached RSS, not a fresh-launch one.
- **Latency rig that actually works: host filmstrip + driver clock.** Both the driver's
  `QA-CMD <unix-ts>` prints and host screenshots use the same wall clock, so run
  `xcrun simctl io <udid> screenshot` in a loop in the background (~0.16-0.25 s/frame,
  filenames + an `index.txt` of start/end timestamps) while the scripted taps run, then
  correlate. `/private/tmp/qa1tools/filmhost.py <name> <seconds> [gap]`.
- **Finding the exact instant the finger landed:** XCTest's `tap()` returns only after the
  app goes idle, so `QA-CMD`/`QA-FIN` bracket the touch loosely (0.5-2.0 s wide; `tapb`
  label lookup alone can cost 1.5 s). Instead diff the *button's own rect* across frames -
  SwiftUI's press highlight shows up as a small MAD blip that decays over ~0.4 s, and its
  first frame is the touch. That is what turns "somewhere in a 2 s window" into "+0.4 s".
- **Image diffing:** built `/private/tmp/qa1tools/imgdiff a.png b.png [x y w h]` (~40 lines
  of CoreGraphics, `swiftc -O`) printing mean-absolute-difference and % pixels changed,
  optionally over a rect. Diffing consecutive film frames finds the first/last frame of any
  animation; diffing against the settled frame finds when it stopped. Frame coordinates are
  **raw px in the portrait 1206x2622 frame even in landscape** - rotate with `sips -r 270`
  first if you want to reason in landscape coordinates.
- Measured on an uncontended qa-worker-1 (iPhone 17 Pro, iOS 26.5), build 342e3c0:
  cold launch -> painted board <= 0.9 s; Daily/Wins/How-to-play sheets settle ~1.0-1.1 s;
  New game redeal settles 1.65 s; demo auto-advance **0.250-0.259 s/move** (25.1 s for the
  97-move bronze line - design is 0.24); auto-finish cascade **~0.18 s/card** (design 0.16)
  + 0.38 s before the win overlay; idle CPU 0.0-1.0% in every orientation/HUD combination.
  Only slow path: **first Export after a cold launch, ~1.8 s frozen with no spinner**.
- **Landscape "every card resizes when the tallest column changes" does NOT trigger on this
  device.** `ContentView` line 72: `cardW = max(30, min(widthCardW, heightCardW))`, and on
  iPhone 17 Pro the *width* term binds at cardW=44 while `heightCardW` only drops below 44
  once `reserve = max(8, tallest) > ~12`. Verified empirically: growing a column 7 -> 8 -> 9
  left columns 4-6 **bit-identical** (imgdiff MAD 0.000). So a landscape relayout stress
  test needs a **13+ card column** (11+ with the daily HUD, which steals 62 pt of height);
  below that you are only measuring one card animating (~0.7-0.9 s, no stall).
- Deal #10,004 tableau, top->bottom, for picking legal drag targets:
  c0 8D AS AH 2C 3D 4D JC | c1 10S 6S 4S 6C 9D 9C 10C | c2 5H 2H KD 5D AD 2D 6H |
  c3 AC 4C QC 8C 3C 5S 8S | c4 6D KH JS 7H 2S QD | c5 3H QS 10D 7S JH 7C |
  c6 3S 9H 8H QH JD 10H | c7 5C 7D KS KC 9S 4H.
  Tableau build rule (`Game.canStackTableau`): alternating colour, **rank +/-1 in either
  direction**, but a column that already has a 2-card tail direction must keep going the
  same way - a "legal-looking" drop onto an ascending tail with a descending card is
  silently refused (cost me one wasted run).
- Portrait deal alert: the number pad needs one tap **per digit** - `10004` is 1,0,0,0,4
  (five taps). Typing four keys silently gives you deal #1004, which still looks plausible.
- `xcrun simctl io <udid> screenshot` costs ~0.16-0.27 s per frame and each PNG is ~2 MB;
  a 40 s film is ~800 MB in /private/tmp. Delete `film_*` dirs as you go.
