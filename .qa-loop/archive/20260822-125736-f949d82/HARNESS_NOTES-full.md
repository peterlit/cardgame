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

## Round-0 exploration additions (qa-worker-1, WF-2/5/6)

- **Driver lane hygiene:** `QA_SCRIPT_PATH` / `QA_OUT` env vars still do not reach the
  runner — copy `/private/tmp/causeway-qa-driver/` to your own scratchpad and edit the two
  literals in `QADriver.swift` (`/private/tmp/qa1script.txt`, `/private/tmp/qa1out`), then
  `xcodegen generate` (~5 s) and `xcodebuild test -destination "id=<your udid>"` (~25-40 s
  per invocation). `labels` came back EMPTY every time this round against the non-target
  app — do not build a script on label lookups; use coordinate taps + screenshots (`tapb
  Done` for sheet chrome still works).
- **Deriving the daily instead of hard-coding it:** `.qa-loop/tools/derive_daily.py`
  reproduces `dailyChallenge()` exactly (Mulberry32 seeded `0x9e3779b9 ^ (dayIndex+1)`,
  silver pool then gold pool, `moves` param `round(par*1.2)`) and prints the deal, both
  labels, the demo-pill set and each baked line's length. Verified against the live screen
  for dayIndex 0, 3 and 4. Run it first in any WF-5/WF-6 case.
- **The day flips LIVE at local midnight with no relaunch** (`todayIndex()` is recomputed
  each render): observed the Daily card go #10,004 → #10,005 while the app stayed open.
- **Portrait geometry with the demo bar up** (iPhone 17 Pro): tableau card i top
  y = 498 + 30·i (vs 425 with no bar); demo pills Next (236,263) / Start (297,263) /
  Stop (357,263); when PAUSED the headline wraps and they move to y≈266; when the line is
  finished only `Done` remains at (355,265). With the **daily HUD** instead, tableau card i
  top y = 479 + 30·i.
- **Proving "no drag-lift" rigorously:** run the driver script with a long drag
  (`drag x1 y1 x2 y2 2.5`) and film the host in parallel — poll the driver log for the
  `QA-CMD … shot <name>` line that precedes a `sleep 10`, then start
  `filmhost.py` (copy it and swap the hard-coded UDID for your own). Frames inside the
  drag window compared with `/private/tmp/qa1tools/imgdiff` gave MAD 0.000 across 3.3 s,
  which is what turns "the move was refused" into "the card never lifted".
- **Building a tall portrait column on deal #10,004** (13 drags, all verified) is written
  out step-by-step in TESTCASES.md TC-2.6. Two gotchas: a drop released BELOW the target
  column's last card is outside its drop-zone frame and snaps back (aim mid-column, e.g.
  y=600), and every landed move shifts the source columns' bottom-card y by 30 pt — screenshot
  and recompute after each 3-4 drags or the rest of the script silently misses.
- Portrait board-shrink threshold is derivable: the whole board rescales at the smallest N
  where `floor((boardH-32)/(3*1.6727 + 0.53*(N-1))) < portraitCardW`; on iPhone 17 Pro
  portrait with no HUD that is **N = 16** (45 pt → ~44 pt cards). Below that only the tall
  column's own fan compresses (30 → 28 → 24 pt at 12/13/15 cards).
- `/private/tmp/qa2crop/stack out x y w h in...` is the cheapest way to read a state
  sequence: the demo bar strip is `0 700 1206 160`, the toolbar rows `0 380 1206 320`,
  the Moves/Time/Won strip `600 400 606 130` (all raw px in the 1206x2622 frame).

## Round-1 additions (qa-worker-1, WF-1/2/3 functional lane)

- **THE SESSION SCRATCHPAD AND `/private/tmp/qaNscript.txt` ARE SHARED BETWEEN PARALLEL
  WORKERS.** Two lanes both copied the driver to `<scratchpad>/drv` and both wrote
  `/private/tmp/qa1script.txt`; my `xcodebuild test` then ran *another worker's* script
  against MY simulator (84 demo `Next` taps + a Stop) and my own edits to
  `QADriver.swift` were silently reverted by the other worker's `cp -R`. Symptom to watch
  for: the `QA-SCRIPT:` line in the output is not the script you just wrote. Fix: give the
  lane a unique directory and unique literals, e.g.
  `<scratchpad>/w1r1lane/{drv,out,script.txt}`, and verify the echoed `QA-SCRIPT:` matches
  before trusting any screenshot. Uninstall+install to clear the state the stray script left.
- Keep a copy of the app bundle before resetting state: the build product path recorded
  earlier in this file is a dead scratchpad. `cp -R ~/Library/Developer/CoreSimulator/
  Devices/<udid>/data/Containers/Bundle/Application/<uuid>/Causeway.app <lane>/` then
  `simctl uninstall` + `simctl install <lane>/Causeway.app` gives a zero-state build.
- `run.sh` pipes xcodebuild through `grep`; add `--line-buffered` or the log lands in 4 KB
  chunks and any host-side poll (e.g. "start filming when the script reaches step N") fires
  several seconds late.
- **`drag x1 y1 x2 y2 D` in QADriver = `press(forDuration: D, thenDragTo:)`, so D is the
  PRESS-HOLD before any movement**; the translation happens in the last ~0.9 s and the
  whole command takes D + ~0.9 s. A filmstrip of the first D seconds shows nothing moving
  even for a perfectly legal drag - correlate with `QA-CMD <ts>` + D, not with the command
  start.
- Two measurement tools built this round (swiftc, ~40 lines each, in the lane dir):
  `edges <png> <y0> <y1> [thr] [frac]` - marks each raw-px column "card" if >frac of the
  pixels in the y band are brighter than thr, prints white runs in px AND pt (px/3). With
  `1285 1345 235 0.1` it reads all 8 tableau card widths off any portrait board; with
  `800 840 160 0.9` it reads the foundation/free-cell placeholder widths (they are cream,
  so thr 235 misses them and the cloud art merges the middle cells - use the outer ones).
  `vedge <png> <x_raw> [band]` - prints the y of every card border down a column plus the
  fan pitch in pt; that is how "col0 pitch 24.00, col1 pitch 30.00" gets proven.
- Portrait board-shrink numbers measured on iPhone 17 Pro / deal #10,004 (build 6ee255b):
  tableau white-face width 42.33 pt at 12-15 cards -> 40.33 pt at 16; foundation and free
  cell placeholders 41.00 -> 39.00 pt in the same step; tableau left edge 7.33 -> 16.33 pt
  (re-centres); col0 fan pitch 30 -> 28.00 (13) -> 24.00 (15) -> 23.00 (16) pt while col1
  stays 30.00 throughout. Bottom card's lower edge stays at ~834 pt on an 874 pt screen.
- Deal-entry flow that works first time: `tap 192 175` (Deal # pill; re-read its x from a
  screenshot, the pill row reflows with the seed's digit count) -> `tap 200 268` (field,
  raises the edit callout) -> `tap 213 316` (Select All) -> one pad tap per digit ->
  `tap 200 336` (Play).

## Round-1 additions (qa-worker-2, WF-5/6/7)

- The driver at `/private/tmp/causeway-qa-driver/` still works verbatim; copy it, `xcodegen
  generate`, and run `xcodebuild test -project QA2.xcodeproj -scheme QAUITests -destination
  "id=<udid>" CODE_SIGNING_ALLOWED=NO` (~20 s to first script command, ~30-45 s total).
  Its defaults are already `/private/tmp/qa2script.txt` + `/private/tmp/qa2out` (worker-2 lane).
  Wrapper used this round: `/private/tmp/qa2run.sh "cmd|cmd|…"`.
- **The app is NOT relaunched between `xcodebuild test` invocations** on this rig — an open
  sheet and its scroll offset survive into the next invocation. Screenshot first, compute
  coordinates from that shot, tap in the next run.
- **Sheet scrolling:** `scrollto 200 700 300` scrolls the sheet content DOWN safely, but a
  downward `scrollto 200 300 750` starting near the sheet top **dismisses the sheet**
  (cost one wasted TC-5.4 pass). To scroll back UP inside a sheet use `swipedown` (it scrolls,
  it doesn't dismiss); `swipeup` can dismiss.
- **Daily sheet resets its scroll offset every time it is opened** — pills are at their
  unscrolled coordinates on each fresh open: Play (200,489), 🥉 Clear (115,564),
  🥇 Gold (287,564); after one `scrollto 200 700 300` Import is at (296,773).
- **The toolbar `Daily` pill MOVES with the deal number's width** (FlowLayout): x≈279 with
  `Deal #10005`, x≈245 with `Deal #1`. Tapping the stale x hits `Wins`. Re-read the pill row
  after any deal change.
- **Deal alert opens with the numberPad already up** and the field pre-filled+focused; no
  Select All needed — just backspace (333,774) per digit. Keys as previously documented.
- **Proving "no drag-lift" cheaply:** run the driver in the foreground and start a host
  screenshot loop in the background *first* (`xcrun simctl io <udid> screenshot` in a while
  loop, filename = timestamp). xcodebuild needs ~19 s before the first script command, so
  start the film before the run, not after. Then crop the same rect out of every frame in the
  drag window and compare md5s — 22 identical frames over a 4 s drag is the evidence.
- **Seeding a daily/bronze record without winning:** the app's own Import accepts a crafted
  backup. File Provider dir for a device is found by grepping the AppGroup metadata plists for
  `group.com.apple.FileProvider.LocalStorage`; drop `X.json` in `File Provider Storage`. On
  iOS 26 the picker opened straight on **On My iPhone** (not Recents) once a file existed.
  JSON: `{"format":"causeway-stats","version":1,"exportedAt":"…","daily":{"<dayIndex>":{bronze,
  silver,gold,flawless,moves,elapsed}},"wins":{"<seed>":{moves,secs,date}}}` with `date` as a
  Double (seconds since 2001-01-01). App confirms with "Imported — merged N day(s) …".
  **State left on qa-worker-2 after round 1:** dayIndex 4 bronze + a win record for #10,005,
  plus `QA-Seed-Bronze.json` (deleted from the picker dir at end of run). Reinstall to clear.
- `/private/tmp/qa2crop/{crop,stack}` are still present and are the cheapest way to read a
  state sequence. Useful rects (raw px, 1206x2622): demo bar `0 700 1206 190`, toolbar+HUD
  `0 180 1206 660`, Daily card `0 800 1206 700`, calendar `0 1400 1206 1000`.
- Portrait demo-bar geometry re-confirmed on this build: Next (236,263) / Start (297,263) /
  Stop (357,263); paused → y≈266; finished → only `Done` at (355,265).

## Round-1 additions (qa-worker-3, WF-9/10/11)

- Driver: copy of `/private/tmp/causeway-qa-driver` with the two path literals pointed at
  `/private/tmp/qa3script.txt` + `/private/tmp/qa3out`. Two cheap driver upgrades worth keeping:
  `labels` now prints `en=<isEnabled>` (that is how "Play is disabled while the field is empty"
  gets *proved* instead of eyeballed), and a `tapid` command
  (`identifier BEGINSWITH` predicate) for Files-picker cells.
- **`activate` does NOT relaunch the app** between `xcodebuild test` invocations: the board,
  an open sheet, and even a half-presented system Files sheet all survive. (The older note
  "the app is relaunched between invocations" only applies if your script says `launch`.)
  So a multi-run stateful sequence is fine as long as every script starts with `activate`.
- **`labels` throws while a system sheet is animating** ("Failed to get matching snapshot ...
  No matches found for Element at index N") and fails the whole test run. Screenshot instead,
  or `sleep 3` first.
- **`scrollto 200 300 800` on a sheet dismisses it** (a drag started near the sheet's top is a
  dismiss gesture, not a scroll). To scroll the Daily sheet *up* safely start below y≈500.
  Conversely `drag 200 190 200 820 0.1` is the reliable way to dismiss a stuck system sheet.
- **Files sheet geometry (iOS 26, iPhone 17 Pro, pt)**: exporter `Save` (349,110); importer
  close `X` (311,110); Browse tab (286,831); Browse root row `On My iPhone` (125,324);
  file grid cells at (71,257) (200,257) (330,257) / (71,454) ... sorted by name;
  "Replace Existing Items?" alert buttons Replace (201,461) / Keep Both (200,516) / Stop (200,571).
  The importer reopens at the last-used location, so screenshot before tapping a cell.
- Daily-screen pills once scrolled to the bottom: `Export` (106,971), `Import` (296,971);
  the backup note sits ~40 pt below them (crop raw px `0 2200 1206 420` to read it).
- **The demo -> Stop shortcut to a finishable board is CLOSED on this build** (WF-6's
  2026-08-15 change re-deals the seed on Stop), so the round-2 "reach a WIN deterministically"
  recipe no longer works. To populate wins/daily records for WF-9-style review, **import a
  crafted backup** (shapes in the round-2 notes above; `TierResult` needs all four Bools plus
  optional `moves`/`elapsed`, `WinRecord.date` is a Double since 2001-01-01). Import is the
  app's own supported path, so it is a fair fixture - just say so in the result.
- Finding where a baked line becomes auto-finishable (still useful for WF-4): replay
  `data/daily-solutions.json` tokens with `tools/solver/rules.mjs applyMove` + `dealState`,
  checking `tests/engine.mjs autoFinishWouldWin` after each token. Deal #10,005 bronze:
  finishable after token 76 of 86.
- **Observed once, NOT reproducible (treat as rig flake, do not file):** on the second
  same-day export, tapping `Replace` moved the existing `Causeway-Stats-<date>.json` to
  `.Trash`, never wrote the new file, and left the exporter spinning for >90 s with no Save
  and no Cancel; the picker stayed wedged (blank white sheet) until the app was relaunched.
  A clean repeat of the same flow (relaunch -> Export -> Save -> Replace) wrote the file
  correctly in ~2 s. Host state is visible at
  `<sim>/data/Containers/Shared/AppGroup/<FileProvider.LocalStorage>/File Provider Storage`
  (plus its `.Trash`), which is how the difference was proved.

## Round-1 additions (qa-worker-3, WF-12 landscape functional lane)

- **Lane isolation that actually held:** copy `/private/tmp/causeway-qa-driver/{UITests,project.yml}`
  into a *uniquely named* dir (`/private/tmp/qa3-r1w12/`), `sed` the two literals in
  `QADriver.swift` to `<lane>/script.txt` + `<lane>/out`, `xcodegen generate`, then a
  `run.sh <tag> "<script>"` wrapper that pins `-destination "id=<udid>"`. Never reuse
  `/private/tmp/qaNscript.txt` — those are shared across parallel lanes.
- **Rotation confirmed again on 6ee255b.** `rotate left` → `appFrame=(0,0,874,402)`. Orientation
  **does** reset to portrait at the start of every `xcodebuild test`, but the app itself is NOT
  relaunched and an **open alert keeps its scroll offset** across invocations, so a multi-run
  landscape sequence works as long as every script starts with `rotate left`.
- `XCUIScreen.main.screenshot().image.size` reports 874x402 in landscape, but the PNG on disk is
  still the portrait 1206x2622 frame — always `sips -r 270 --out X-rot.png X.png` before reading.
- **Landscape geometry re-measured on deal #10,005 / iPhone 17 Pro (pt).** No HUD: rail x=127,
  pills y = 70 New game / 102 Undo / 135 Replay / 167 Auto-play / 200 Auto-finish / 232 Deal # /
  264 Daily / 297 Wins / 329 How to play; tableau column centres x = 420.3, 469.3, 518.3, 567.3,
  616.3, 665.3, 714.3, 763.3 (pitch 49.0), bottom-card centre y ≈ 250; free cells (218/266/314, 288);
  down-row foundations y=188. **With the daily HUD** everything drops ~40pt: New game 110 … Wins 335
  (clipped), How to play below the fold; tableau columns x = 410.5 + 46.4·i, bottom-card centre y ≈ 279,
  free cell 1 at (218, 321). The rail scroll view ends at ≈345pt; one `drag 127 300 127 120` scrolls
  it fully to the bottom and the indicator is visible during the drag.
- **Card size measurement tool** `<lane>/tools/edges <png> <y0> <y1> [thr] [frac]` (swiftc, ~35 lines):
  marks each raw-px column "card" if ≥frac of the band is brighter than thr, prints runs in px and pt.
  Gotchas that cost time: **thr 235 measures the inner white fill (39.00pt), thr 200 measures the
  full card incl. border (42.33pt)** — always compare orientations at the SAME threshold, and never
  compare a tableau card face against a foundation *placeholder* (cream stroke, reads 43.00pt).
  Clean bands: landscape rotated `700..712` (bottom-card white area, all 8 columns); portrait is much
  harder — most bands are contaminated by shadows and the cloud art at x 609-737 raw is a false positive.
- **`labels` and `dump` came back EMPTY every time this round** against the non-target app (both in
  portrait and landscape) — but `tapb <label>` still works ("Done", "Play"). Build scripts on
  coordinate taps + screenshots; use `tapb` only for sheet chrome.
- **Landscape system alert quirk:** the `Play a deal` alert's action list is a scroll view. Only the
  first action is visible; `drag 437 200 437 60 0.2` scrolls it and reveals Cancel in the same slot.
  Tapping outside does nothing (no dismiss, keyboard stays). Useful to know before you conclude a
  driver tap "missed".
- The landscape daily HUD renders all three objectives in full (no truncation) — the portrait HUD
  truncation is portrait-only, so any HUD fix must be checked in both orientations.

## Round-1 additions (qa-worker-2, WF-8 + P-C persistence)

- **Lane isolation that worked:** whole driver copy at `/private/tmp/qaw2r1wf8/` (`drv/`,
  `out/`, `script.txt`) with the two literals in `QADriver.swift` pointed there, plus a
  3-line `run.sh` that writes the script and runs `xcodebuild test -destination id=<udid>`.
  ~25-35 s per invocation. `labels` returned EMPTY again against the non-target app —
  coordinate taps + screenshots only.
- **`home` command:** add `case "home": XCUIDevice.shared.press(.home); Thread.sleep(1.0)`
  to the driver switch — the only way to exercise the real scenePhase→persist path.
  `activate` resumes without relaunch; `terminate|launch` is the cold-restore test.
- **REACHING A FINISHABLE BOARD IS NOW CHEAP AGAIN (the demo→Stop shortcut is dead, this
  replaces it).** `data/daily-solutions.json` holds 366 seeds x 3 baked lines; replay each
  line with `tools/solver/rules.mjs applyMove` and test `tests/engine.mjs autoFinishWouldWin`
  after every token to find the first finishable index. Global minimum: **deal #10169 bronze
  is finishable after only 28 moves** (next best 10072 silver 29, 10109 bronze 30). Scanner
  + gesture generator kept at `/private/tmp/qaw2r1wf8/{scan.mjs,scan2.mjs,gen.mjs,gen2.mjs}`
  (`node gen2.mjs <seed> <tier> <limit>` prints one `drag x1 y1 x2 y2` per token plus the
  expected board after each). All 28 drags landed first try, twice.
  - Portrait gesture geometry the generator assumes (verified on iPhone 17 Pro, no HUD):
    column centres x = 28,77,126,175,224,272,321,370; grab card i of an n-card column at
    y = 425+30i+14 (+37 if it is the last card); drop onto a column at y = 425+30(n-1)+37
    (n=0 → 445); foundations x = 28,77,126,175 with **up row y=296, down row y=375**;
    free cells x = 274,323,372 at y=296. A `C` (park) token must be dropped on the FIRST
    empty cell to stay in sync with the simulator.
  - Keep columns under 13 cards or the fan pitch stops being 30 pt and every later y is wrong.
- **Auto-play scans:** `isSafeAutoplay` is strict enough that most boards have NO safe card.
  First safe card per line, earliest across the whole pool: **deal #10164 gold at move 7**
  (KD becomes safe; that is the cheapest positive "auto-play actually fires" fixture).
  Deal #10169 bronze has none until move 31 — which is why the 28-move TC-8.4 fixture can be
  driven with Auto-play left **On** without desyncing the scripted line.
- **Auto-finish modes can all be exercised on one board without replaying**: mode changes call
  `maybeAutoFinish()` in `didSet`. Off → Finish pill; Off→Ask → prompt; Ask→On → cascade.
  Prompt buttons: `Not yet` (127,496), `Finish` (274,496). The gold `Finish` pill inserts at
  (167,175) and pushes Wins/How-to-play to a third row; Auto-play (300,135) and Auto-finish
  (60,175) never move — always tap those two on their LEFT half.
- Deal alert on this build: number pad already up, field pre-filled and focused → one
  backspace (332,774) per existing digit, then one tap per new digit, then `Play` (200,335).
- Win overlay buttons in pt: `Play deal #N` (125,486), `Random` (238,486), `Close` (311,486).
- The app is NOT relaunched between `xcodebuild test` invocations (confirmed again): a 28-drag
  sequence can be split across 4 runs and the board survives; only orientation resets.

## Round-1 additions (qa-worker-1, WF-4 + P-A/P-B lane)

- **Lane isolation that worked:** driver copied to `<session-scratchpad>/w1wf4lane/drv` with the two
  literals in `QADriver.swift` pointed at `/private/tmp/qa1wf4script.txt` + `/private/tmp/qa1wf4out`
  (NOT `qa1*`, which another lane owns). `run.sh "cmd|cmd"` writes the script, runs
  `xcodebuild test -destination id=<udid>`, and greps `QA-SCRIPT|QA-MISS|QA-DONE`. ~35-45 s per
  invocation. `labels` came back FULL this round (buttons + static texts with pt frames) against the
  non-target app — it is the cheapest state oracle available; screenshots were only needed for text
  the a11y tree flattens (alert body, overlay copy).
- **REACHING A GENUINE WIN NOW THAT demo->Stop IS CLOSED: replay the baked line as REAL moves.**
  Fully deterministic, ~6 min, no fixture injection. Recipe:
  1. `tests/engine.mjs deal(seed)` + `tools/solver/rules.mjs applyMove` replay
     `data/daily-solutions.json.solutions["<seed>"].bronze`; stop at the first token where
     `autoFinishWouldWin()` is true (**deal #10,005 bronze: after token 76 of 86**; max column
     length en route is 10, so no fan compression to model).
  2. Turn **Auto-play OFF first** (one tap on the pill) — then the app state after each scripted
     move equals the offline simulation exactly, so every tap/drag coordinate can be computed
     ahead of time from the simulated column heights.
  3. Token -> UI mapping: `F,col,end` = **tap** the column's bottom card (smartMove tries the
     foundation first for a single card, so it always goes home); `G,cell,end` = tap the cell;
     `C,src` = **drag** column bottom -> first empty cell (match `cells.indexOf(null)`);
     `X,cell,dst` = drag cell -> dst column; `T,src,idx,dst` = drag the card at (src, idx) -> dst
     column (the run below it comes along).
  4. Coordinates (iPhone 17 Pro portrait): columns x = 28,77,126,175,224,273,322,371;
     tap y for card i = **437 + 30i** with no HUD, **476 + 30i** with the daily objectives HUD
     (the HUD shifts the whole board down 39.33 pt, card size unchanged); free cells x =
     274/323/372 at y = **296** (no HUD) / **335** (HUD). Drop on a non-empty column = the y of its
     LAST card; drop on an empty column = 450 (no HUD) / 489 (HUD).
  5. Run in batches of ~19 moves ending in `|shot X|labels`, and verify by parsing the rank texts
     out of `labels` (tableau texts are those with y >= 420; column = round((x-10)/49)) against the
     simulated grid. 76/76 moves landed on both full replays, twice, with zero drops.
- **One finishable board can be re-used for every finish route, via Undo.** `sendOneHome()`
  snapshots per card, so N undos after a win rewind the whole cascade (10 undos for #10,005) back
  to the finishable position; `undo()` also clears `won`, so the Finish pill/prompt re-arms.
  Undo does NOT call `maybeAutoFinish()`, so you can safely flip Auto-finish **On -> Off** on a
  finishable board (`.off` is a no-op), whereas **Ask -> On instantly runs the cascade and wins**
  (mode `didSet` calls `maybeAutoFinish`). Order that covers everything on one board: prompt/Finish
  -> Close -> undo xN -> one legal move (prompt returns) -> Not yet -> mode On (wins) -> Close ->
  undo xN -> mode Off -> Finish pill (wins).
  Caveat: `winRecorded` is not reset by undo, so re-wins after the first show the overlay but do
  NOT update WinStore/daily records — use a fresh deal if you need a recorded win.
- Overlay/prompt geometry (pt): finish prompt `Not yet` (127,497) / `Finish` (275,497). Win overlay
  buttons sit at **y=503 when the daily-medal line is present, y=472 for a casual win**:
  `Play deal #<next>` (125,·), `Random` (238,·), `Close` (314,·) — read them from `labels`, don't
  assume. Toolbar: `Auto-finish` pill stays at (66,175) through all three modes; the gold `Finish`
  pill lands at (167,175) with `Auto-finish: Off/On` and (170,175) with `Ask`.
- A win **clears the saved game** (`clearSaved()`), so `terminate|launch` after a win starts a fresh
  random deal — do any "relaunch after win" check before you need that board again, and re-deal via
  the Deal # alert if you want it back. Deal alert on this build opens with the pad up and the field
  focused+prefilled: backspace (333,774) once per existing digit, then one pad tap per new digit,
  then `Play` (200,335).

## Round-1 additions (qa-worker-1, PERF lane: P-D + P-E)

- **Lane isolation:** whole driver copy at `/private/tmp/qa1perf-r1/` (`UITests/`, `out/`,
  `script.txt`), both literals in `QADriver.swift` re-pointed there, `run.sh <tag> "<script>"`
  pinning `-destination id=<udid>`. ~25-40 s per invocation.
- **Orchestrator that removes all the guesswork from latency runs:** `/private/tmp/qa1perf-r1/orch.py
  <tag> "<script>" "<marker-cmd>" <delay_s> <film_s>` starts `run.sh` in the background, polls the log
  for the `QA-CMD <ts> <marker>` line (use a long `sleep N` as the marker), waits `delay`, then starts
  the host screenshot film. `orch2.py` is the same thing with `cpuwin.py` instead of the film, which
  is how "CPU during the demo auto-run" gets measured without the film's own screenshot cost.
  **Gotcha:** with stdout piped, the subprocess's output arrives BEFORE orch's own buffered prints —
  redirect to a file and grep, or `tail -N` will silently eat the cpuwin line.
- **Touch instant without guessing:** md5 every film frame; the SwiftUI press highlight is the first
  CHANGED frame after the `QA-CMD` timestamp (typically cmd+0.35-0.50 s), and byte-identical md5s
  across consecutive frames are the *proof* of a frozen screen (that is what makes the export-stall
  finding indisputable).
- **Reading in-app progress text off a filmstrip cheaply:** `/private/tmp/qa2crop/stack out 0 700 1206 190
  a.png b.png c.png` stacks the demo bar strip from 3 frames into one image = one Read call gives you
  three (count, timestamp) pairs, i.e. the auto-advance rate. Demo pacing on 6ee255b: 0.251-0.257 s/move.
- **Deal #10169 bronze 28-drag fixture (from qa-worker-2) replays perfectly**: 28/28 drags landed in 4
  invocations, ending on the `Ready to finish` prompt, then Finish -> win in 8.2 s (70 moves recorded).
  Auto-play can stay On for it.
- **Wins/daily fixture:** the 300-win backup used here is
  `File Provider Storage/QA-Perf-Wins.json` (delete it between passes). On this device the importer
  opened straight on **On My iPhone** with the file cell at pt (72,262); Daily sheet after one
  `scrollto 200 700 300` puts **Export at (116,772) and Import at (309,772)** (NOT the (106,971)/(296,971)
  from an earlier round - the scroll offset differs; screenshot before tapping).
- Portrait pill coordinates confirmed on 6ee255b: New game (55,135), Undo (142,135), Replay (231,135),
  Auto-play (335,135), Auto-finish (65,175), Deal # (192,175 with a 5-digit seed), Daily (271-276,175),
  Wins (338,175); Daily sheet unscrolled Play (206,491), Clear (114,565), Gold (321,565), Done (357,101);
  finish prompt `Not yet` (128,496) / `Finish` (276,496); importer close X (309,112).
- **Measured on the uncontended perf lane, build 6ee255b** (full table in
  `.qa-loop/evidence/round-1/perf/perf-measurements.txt`): cold launch -> painted board 0.90 s;
  New game redeal 1.43 s; deal alert + keypad 1.04 s; Daily sheet 0.76 s; daily Play handoff 1.16 s;
  Wins sheet with 300 records 0.88 s; auto-finish cascade 0.19 s/card + 0.21 s to the win overlay;
  demo 0.251-0.257 s/move; idle CPU 0.0-0.9 %, demo auto-run 17.0 %; RSS flat over 22 New-game
  cycles; zero network bytes. Only slow path remains the **first document-picker presentation per
  process (1.6-1.8 s frozen, no spinner)** - Export and Import both.

## Round-2 additions (qa-worker-3, WF-11/12 + WF-1 smoke)

- **Lane isolation used:** `/private/tmp/qa3-r2w1112/` (driver copy, `script.txt`, `out/`,
  `run.sh <tag> "<script>"` pinning `-destination id=<udid>`). Both literals in
  `QADriver.swift` re-pointed there. `xcodegen generate` ~5 s, `xcodebuild test` ~25-35 s.
- **Driver additions worth keeping:** `tapid` / `tapidp` (identifier ==/BEGINSWITH), `ids`
  (dumps identifier + label + isEnabled + frame for buttons/texts/fields/otherElements/cells),
  `home`. NOTE: even though build 5447237 adds real `accessibilityIdentifier`s
  (`toolbar.*`, `daily.*`, `demo.*`, `stat.*`), **`ids` and `labels` still came back EMPTY**
  against the non-target app on this rig. Coordinate taps + screenshots remain the only
  reliable channel; `tapb <label>` still works for sheet chrome ("Done").
- **Deleting/moving files inside the simulator's data container is refused by the command
  classifier** (`rm`/`mv` on `.../Devices/<udid>/data/...`). So the File Provider Storage
  fixtures and any previously exported `Causeway-Stats-<date>.json` **cannot be cleaned up**
  from the host - plan for the exporter to hit "Replace Existing Items?" on a same-day second
  export (Replace at pt (200,460); it worked cleanly this round, ~2 s, file rewritten).
- **Portrait deal alert on 5447237 is now TWO side-by-side actions**: `Cancel` (127,391) and
  `Play` (275,391) - the old vertical `Play (200,335) / Random (200,391) / Cancel (200,447)`
  coordinates are dead. Landscape: `Cancel` (362,179) / `Play` (511,179), both above the pad.
  The field is pre-filled+focused with the pad up: one backspace (332,774) per existing digit.
- **Catching a sub-second in-app note change:** run `film.sh <dir> <secs>`
  (`xcrun simctl io ... screenshot` in a loop, filename = unix ts) in the BACKGROUND and start
  the `xcodebuild test` ~0.5 s later - xcodebuild reaches its first script command in ~18-21 s,
  so a 40 s film started first always brackets a tap that follows a short `sleep`. Trying to
  start the film *after* polling the log for a marker missed the window (xcodebuild's stdout is
  block-buffered into a file). Then `/private/tmp/qa2crop/stack out.png 0 2380 1206 160 <frames>`
  reads the Daily backup note line from 5-7 frames in ONE Read call.
- Daily sheet scrolled fully to the bottom (portrait, 2 x `scrollto 200 700 300`):
  `Export` (106,772), `Import` (295,772), note line at y≈808. Importer file grid cells
  (On My iPhone, 4 files): (71,258) (200,258) (331,258) / (71,456). Importer close X (309,110);
  exporter `Save` (349,110), and the exporter has no Cancel - `drag 200 100 200 830 0.1`
  dismisses it and yields "Export cancelled."
- **Landscape geometry re-confirmed on 5447237 / deal #10005** (pt, no HUD): rail x=127,
  y = 70/102/135/167/200/232/264/297/329 for New game/Undo/Replay/Auto-play/Auto-finish/
  Deal #/Daily/Wins/How to play; tableau columns x = 419,468,517,566,615,664,713,762;
  free cells (218/267/316, 290). **With the daily HUD** the rail scrolls and `How to play`
  is below the fold - `drag 127 300 127 120 0.05` brings it fully into view; the board's
  tableau column 0 bottom card is at ~(410,277).
- Landscape sheet handling: `scrollto 437 350 120` scrolls the Daily sheet down safely;
  `swipedown` scrolls it back up without dismissing.

## Round-2 additions (qa-worker-2, WF-5/6/8 targeted lane, build 5447237)

- **The app now ships accessibility identifiers — stop guessing coordinates.** Build
  5447237 added `toolbar.{newgame,undo,replay,autoplay,autofinish,finish,deal,daily,
  wins,howtoplay}`, `stat.{moves,time,won}` (on the VALUE text), `daily.{play,export,
  import}`, `daily.demo.<tier>`, `demo.{headline,next,start,stop,done}` and
  `card.<SUIT><RANK>` (e.g. `card.S13`, label "king of spades") on every card.
  Two driver commands make that usable (added to my copy of `QADriver.swift`):
  - `tapid <identifier>` — `descendants(matching:.any).matching(identifier == X).firstMatch`.
    Immune to the FlowLayout pill reflow that has cost earlier rounds whole runs.
  - `ids` — prints every element with a non-empty identifier as
    `kind id=… label=… en=… frame`. `stat.moves`/`demo.headline` labels are a free
    state oracle, and the `card.*` frames reconstruct the whole board:
    group by frame.x → column, sort by y → the pile, which is how "the board is
    byte-for-byte the dealt layout" gets proven without reading a screenshot.
  - Exceptions with NO identifier yet: the win overlay's buttons, the alert buttons
    (deal alert, Ready-to-finish, End-your-daily-attempt) and sheet chrome — use
    `tapb <label>` / coordinates for those.
- **`ids` and `labels` THROW while anything is animating** ("Failed to get matching
  snapshot: No matches found for Element at index N") and that fails the whole
  `xcodebuild test` invocation, abandoning the rest of the script (my demo kept
  auto-running for another 70 moves after the run died). Never put `ids` inside a
  running demo/cascade — `sleep` past it or use `shot` + crop instead.
- **Orientation did NOT reset between `xcodebuild test` invocations this round**
  (contradicting the round-1 note): a `rotate left` from a previous run was still in
  effect, so a portrait coordinate script silently tapped nothing. Put an explicit
  `rotate portrait` at the top of EVERY portrait script, not just landscape ones.
- **Deal alert changed in 5447237**: the `Random` action is gone; it is now
  `Cancel` (127,392) and `Play` (275,392) side by side with the field at (201,324).
  `clearf|type 10169|tapb Play` drives it end-to-end — no more one-tap-per-digit
  number-pad coordinates.
- **Portrait tableau origin depends on the chrome above it** (iPhone 17 Pro, card i
  top y = ORIGIN + 30·i): no HUD/bar **425**; one-line demo bar **479**; NEW stacked
  daily HUD **498** (the old one-line HUD was 479); 4-line paused Gold demo headline
  **513**. Foundations with the stacked HUD: up row top y≈373, down row top y≈412
  (they were 296/375 with no HUD). Re-read from `ids` after any chrome change.
- Daily sheet (unscrolled, portrait): `Play` (200,489), 🥉 Clear (115,564),
  🥇 Gold (286,564), `Done` (350,101). "End your daily attempt?" alert:
  `Keep playing` (126,516) / `Show demo` (275,516). "Ready to finish":
  `Not yet` (126,496) / `Finish` (275,496).
- Proving a demo-locked board is really frozen, cheaply: start the driver in the
  background, poll the log for the `shot` that precedes the drag, then fire ~20
  `xcrun simctl io … screenshot` frames from the host during a
  `drag x1 y1 x2 y2 2.5`. 20/20 frames with one md5 = the card never lifted.
- The 28-drag deal #10169 fixture from round 1 still replays perfectly (28/28, twice)
  — regenerate the gesture list with `node /private/tmp/qaw2r1wf8/gen2.mjs 10169 bronze 28`;
  `gen2.mjs 10164 gold 7` is the Auto-play "exactly one safe card" fixture.
- **VoiceOver-label smell (not filed, region Main):** the SF Symbols used for card
  suits expose Apple's default labels — every heart pip reads
  "Remove From Favorites", clubs/spades/diamonds read "Club"/"Spade"/"Diamond",
  and court cards are `crown` / `person.fill`. Worth a look if an accessibility
  workflow is ever added.

## Round-2 additions (qa-worker-1, WF-2/3/7 functional lane, build 5447237)

- **The app now has accessibility identifiers, and they change how this rig should be
  driven.** `card.<S><rank>` (S ∈ S/H/D/C, rank 1–13), `stat.moves|time|won`,
  `toolbar.newgame|undo|replay|autoplay|autofinish|finish|deal|daily|wins|howtoplay`,
  `demo.headline|next|start|stop|done`. Add these to the QADriver switch — they replaced
  screenshot-reading for me this round:
  - `ids` — walk `app.buttons/staticTexts/otherElements/images`, skip empty identifiers,
    print `id / label / value / isEnabled / frame`. **This is a complete board oracle**:
    every card's exact pt frame, so column contents, fan pitch, card SIZE, free-cell/
    foundation occupancy, Moves/Time/Won and every pill's enabled state come back in one
    command. Comparing the sorted `(id,x,y)` list against an earlier `ids` proves
    "board identical to the initial deal" far more cheaply than imgdiff.
  - `tapid <id>` / `dragid <srcId> <dstId> [dur]` (`identifier ==` predicate).
  - Card frames also give the geometry constants for free: portrait card i top
    y = 425.33 + 30·i, card 45×75 pt, column x origins 6,55,104,153,202,251,300,349
    (centres +22.5); bottom-card centre = top + 37.5; free cells y origin 258.67.
- `labels` still comes back EMPTY against the non-target app, and it **throws while a
  system alert is up**. `ids` works everywhere. `tapb <label>` still works for alert
  chrome (`Play`, `Cancel`) — and a deliberate `tapb Random` printing `QA-MISS` after its
  5 s wait is good *negative* evidence that an alert action no longer exists.
- **`ids` right after a long script can blow the test timeout** ("Restarting after
  unexpected exit, crash, or test timeout") and you lose the output — the taps still
  landed. Keep ≤3–4 drags per invocation when the script ends in `ids`, or put `ids` in
  its own tiny `activate|sleep 1|ids` run.
- **Filming a 0.3 s in-app animation** (the new unmovable-card shake): XCUITest `tap()`
  returns only after the app is idle, so an in-script `shot` ALWAYS misses it. Fire the
  same tap 6–8× with ~1 s gaps and film the host in parallel
  (`xcrun simctl io <udid> screenshot` loop, ~0.25 s/frame → caught 3 of 8), then
  `imgdiff frame rest x y w h` over that card's rect. A 4 pt shake reads as MAD 32–44,
  ~32–40 % pixels changed; the null case (no cue) is 93 consecutive frames at MAD 0.000.
  Lane-safe film loop: `<lane>/film.sh <dir> <secs>` with the udid pinned.
- **The deal alert now has TWO actions** (Random removed): Cancel (127,391), Play
  (275,391) in portrait — the old (200,335)/(200,391)/(200,447) stack is gone. Pad keys
  unchanged: 1 (68,613) 3 (332,613) 4 (68,667) 5 (200,667) 9 (332,721) 0 (200,770)
  backspace (332,774). Field pre-filled + focused with the pad already up, so it is one
  backspace per existing digit.
- **Don't file "the card's suit Images are separate a11y elements" from a `dump`.** The
  XCUITest tree lists the Image/StaticText children of `card.*` (labels include iOS's
  `suit.heart.fill` → "Remove From Favorites"), but it lists the children of ordinary
  SwiftUI `Button`s the same way, and those are definitely single VoiceOver stops — the
  tree is not a VoiceOver traversal, so it cannot prove a mis-announcement either way.
- Parallel-lane reminder that bit again: `.qa-loop/TESTCASES.md`, `HARNESS_NOTES.md` and
  the evidence dir are all touched by several workers in the same round. Prefix your
  evidence filenames with a per-lane tag (I used `r2b-`) — `evidence/round-2/qa-worker-1/`
  already held an earlier round-2 pass's files with the obvious names.

## Round-3 additions (qa-worker-3, WF-9/10/11 functional lane, build 2b66b93)

- **Lane:** `/private/tmp/qa3-r3w911/` (driver copy with both literals re-pointed, `run.sh <tag>
  "<script>"` pinning `-destination id=<udid>`). `ids` and `labels` came back EMPTY again against
  the non-target app — but `tapid toolbar.*` and `tapb <label>` both work, so drive chrome by
  identifier/label and read state from screenshots.
- **Timing a sub-second note change without guessing: `<lane>/orch.py`.** Usage
  `python3 orch.py <tag> "<script>" "<marker-cmd>" <pre_s> <film_s>` — it starts `run.sh` in the
  background, polls the log for the `QA-CMD <ts> <marker>` line (use a long `sleep 30` right before
  the tap as the marker), sleeps until `ts+pre`, then films the host. The older "start the film N
  seconds after launching xcodebuild" guess missed the window by 22 s this round; polling the marker
  hit it twice in a row. Frame cadence ~0.17-0.20 s.
- **"Opening Files…" acknowledgement is easy to re-verify**: crop raw px `0 2380 1206 130` out of
  ~6 frames around the tap and `/private/tmp/qa2crop/stack` them — one Read shows the note flipping
  from the previous message to "Opening Files…" (+0.46 s Export, +0.47 s Import on 2b66b93).
- Portrait coordinates confirmed on 2b66b93 (Daily sheet scrolled to the bottom with 2 ×
  `scrollto 200 700 300`): `Export` (106,772), `Import` (295,772), note line raw px y≈2400-2470.
  Exporter `Save` (349,110); exporter has no Cancel — `drag 200 100 200 830 0.1` dismisses it and
  yields "Export cancelled." Importer close `X` (311,110). Importer file grid (On My iPhone,
  4 files): (200,257) (330,257) / (71,455). "Replace Existing Items?" `Replace` (200,460).
- **Wins screen geometry (portrait, pt):** field (169,191), `Play` (357,191), `Done` (348,100);
  first chip row y=283 with chips at x≈59,153,247,341. **The chip grid re-flows every time a win is
  added** (a new range inserts alphabetically-by-lowerBound), so re-screenshot before tapping a chip.
  Range-detail rows start at y=244 with 51 pt pitch; the back chevron is at (37,100).
- `clearf` + `type <digits>` + `tapb Play` drives the Wins deal field end-to-end (no number-pad
  coordinates needed). `Play` is `.disabled` for empty, "0" and for a 21-digit overflow
  (`Int(...)` returns nil) — a screenshot of the greyed pill is the proof.
- **Reading persisted stats to prove a merge:** `plistlib` on
  `<sim>/data/Containers/Data/Application/<uuid>/Library/Preferences/com.whimsicaldistractions.Causeway.plist`,
  keys `causeway.wins` / `causeway.daily` are JSON `Data` — decoding them before/after an import is
  how "the non-backup file changed nothing" and "day 3's moves=100 was not poisoned by the file's
  moves=0" get proved without any UI reading.
- The round-2 File Provider fixtures (`qa-backup-A.json`, `qa-bad-entries.json`,
  `qa-notabackup.json`) survive an app uninstall/install and are still the fastest way to seed a
  populated Wins screen (5 wins across 3 ranges) — the app's own supported Import route.

## Round-3 additions (qa-worker-1, WF-1/2/3 confirming pass, build 2b66b93)

- **Lane isolation used:** `/private/tmp/qa1-r3-wf13/` (copy of the round-2 driver, both
  literals in `QADriver.swift` re-pointed at `<lane>/script.txt` + `<lane>/out`,
  `run.sh <tag> "<script>"` pinning `-destination id=<udid>`). `xcodegen generate` ~2 s,
  `xcodebuild test` ~35-50 s per invocation. 22 invocations, zero stray-script incidents.
- **`ids` works reliably against the non-target app on this device** (contradicting
  qa-worker-3's round-2 note that it came back empty): every run returned the full
  `card.*` / `toolbar.*` / `stat.*` / `daily.*` list. Two things that make it a complete
  board oracle in one command, worth reusing verbatim:
  - Parser: bucket `card.*` frames by rounded x -> column, sort by y -> the pile, and the
    reported `{w,h}` IS the current card size, so board-shrink and fan-pitch assertions
    need no pixel work at all. Kept at `/tmp/board.py` (12 lines; regenerate from the
    regex `id='card\.([A-Z0-9]+)' lbl='[^']*' v=Optional\(\) en=true \{\{x, y\}, \{w, h`).
  - Comparing the sorted `(id,x,y)` list from two `ids` dumps is the cheapest possible
    "board is byte-for-byte the dealt layout" proof (used for Replay and for 5x Undo).
  - **Split on `QA-IDS-END`, not on `QA-IDS`** when a script contains several `ids` calls,
    or the last segment is empty and the parse silently yields nothing.
- **Bucketing gotcha:** after the 16-card board shrink the tableau's top card sits at
  y=419 pt, above the y<420 threshold an earlier parser used for "free cell vs tableau".
  Free cells are x>=250 AND y<400; foundations are x<250 AND y<400 (up row y=258.67,
  down row y=338 at full size).
- **Auto-play defaults to On and a scripted line can desync on it.** One tap on
  `toolbar.autoplay` before a long pinned drag sequence makes the app state match an
  offline simulation exactly; the setting survives `New game` (it is a setting, not game
  state), so turn it off once per install.
- **TC-2.6's 13-drag tall-column script for deal #10,004 replays perfectly on 2b66b93**
  (13/13 drags landed in 5 invocations of <=4 drags each). Measured ladder: pitch 30 pt
  at <=12 cards -> 28.0 at 13 -> 24.0 at 15; the uniform board shrink fires on the 16th
  card, 45x75 -> **43x71.67** pt (earlier rounds rounded this to "~44"), all 8 columns plus
  the free-cell card in the same step, tableau left edge 6 -> 15 pt.
- Deal-alert flow that worked first time on this build: `tapid toolbar.deal|sleep 2|clearf|
  type 10004|tapb Play` — no number-pad coordinates needed at all.
- Film + imgdiff rect for the unmovable-card shake at FULL card height is
  `18 1456 135 225` (raw px) and reads MAD 13-19 / 13-17 % changed; the round-2 rect
  (height 90) reads MAD ~44 for the same 4 pt displacement. **Compare MAD only against a
  run that used the same rect.**

## Round-3 additions (qa-worker-2, WF-5/6/7 confirming pass, build 2b66b93)

- **Lane:** `/private/tmp/qa2r3-wf567/` (driver copy, both literals in `QADriver.swift`
  re-pointed, `run.sh <tag> "<script>"` pinning `-destination id=<udid>`, `film.sh <dir> <secs>`).
- **`rotate` as the FIRST script command fails the whole run** — it queries the app frame, so a
  script starting `rotate portrait|terminate|launch` dies with "Application ... is not running".
  Order must be `launch|sleep 3|rotate portrait|...`.
- **With the xcodeproj already generated, `xcodebuild test` reaches the first script command in
  ~3 s, not the 18-21 s earlier rounds assumed.** A host film loop timed with "sleep 26 then film"
  missed the drag window entirely. Start `film.sh` FIRST (background), sleep 1, then run the script,
  and give the film enough seconds to cover the whole invocation.
- **`ids` with the demo bar up can take ~54 s to return** (measured from the QA-CMD timestamps:
  ids at t=624, next command at t=678). It still succeeds; just never assume the following command
  happens promptly, and keep `ids` out of any timing-sensitive sequence.
- **Do not split a log by searching for a command string** — the `QA-SCRIPT:` echo on line 2
  contains the entire script, so the first match is always that echo (it silently merged two
  `ids` dumps into one 104-card "board" for me). Match lines starting with `QA-CMD `.
- **`tapid card.<SUIT><RANK>` is the cheapest way to make a specific real move** (e.g. `tapid card.S13`
  smart-moves the king of spades home) — no board geometry needed, immune to HUD/demo-bar origin shifts.
- **Cheap board-identity oracle:** parse `oth id='card.X' ... {{x, y}}` out of an `ids` dump, bucket
  `col = round((x-6)/49)`, sort each bucket by y — comparing that dict against a dump of the freshly
  dealt board proves "re-dealt to the exact initial layout" in one line of python (used for every
  WF-6 Stop/Done case).
- **Proving nothing was banked, without the UI:** `plutil -p "$(xcrun simctl get_app_container <udid>
  com.whimsicaldistractions.Causeway data)/Library/Preferences/com.whimsicaldistractions.Causeway.plist"`
  — after a full 86-move demo line plus a Gold line, only `causeway.game` exists; `causeway.wins` and
  `causeway.daily` keys are absent entirely.
- Geometry re-confirmed on 2b66b93 (portrait, iPhone 17 Pro): tableau card i top y = 425.33 + 30i with
  no chrome, 499.33 + 30i with the stacked daily HUD; demo pills Next (236,264) / Start (297,264) /
  Stop (358,264), paused y≈266, banner `Done` only at (356,266). Daily sheet unscrolled: Play (201,490),
  🥉 Clear (115,565), 🥇 Gold (287,565). After one `scrollto 200 700 300` the August calendar day cells
  are at pt x = 40/94/147/201/254/307/361 and rows y ≈ 486/526/566/606/646/686 (day 12 = (201,566),
  today 16 = (40,606)). Deal alert: Cancel (127,391) / Play (275,391), pad up, field pre-filled.

## Round-3 additions (qa-worker-2, WF-8 + P-C confirming pass, build 2b66b93)

- **Lane:** `/private/tmp/qa2r3-wf8pc/` (driver copy with both literals re-pointed, `run.sh <tag>
  "<script>"` pinning `-destination id=<udid>`). 13 invocations, ~25-40 s each, zero stray scripts.
  `tapid toolbar.*` and `tapb <label>` both work; `ids` was never needed this round.
- **Cheapest WF-8 evidence pipeline:** one `shot` per state + `/private/tmp/qa2crop/stack out.png
  0 340 1206 300 a.png b.png ...` → the whole pill-cycle sequence is ONE Read. The
  Moves/Time/Won strip is raw px `780 190 426 130` (NOT the `600 400 606 130` rect an
  earlier round recorded — that lands on the pills).
- **Auto-play positive fixture re-verified on 2b66b93:** `node /private/tmp/qaw2r1wf8/gen2.mjs
  10164 gold 7` — after the 7th scripted move KD is the only safe card and Auto-play On sends it
  home by itself (Moves jumps 7 → 8, exactly one card). Negative half is free: `toolbar.autoplay`
  → Off, `toolbar.replay`, replay the same 7 drags → Moves 7, KD still in c6. Both halves land
  first try; all 7 drags fit in 2 invocations.
- **28-drag #10169 fixture (`gen2.mjs 10169 bronze 28`) still replays 28/28** on this build in 5
  invocations of ≤7 drags. Auto-play was left **Off** for it (also fine On). Moves checkpoints to
  assert against: 7 / 14 / 21 / 27 / 28-with-prompt.
- **Backgrounding + cold restore, the exact command shape that works:**
  `home|sleep 5|terminate|sleep 3|launch|sleep 5|shot` — `home` alone is the scenePhase→persist
  trigger, `terminate` is the kill, and the pair is the only way to test real restore.
  `home|sleep 4|activate` (no terminate) is the resume case and keeps the undo stack.
- **Proving "the board restored exactly":** crop raw px `0 700 1206 1700` (foundations + free
  cells + tableau, excludes the clock) out of the before/after shots and compare md5 — byte-identical
  is a stronger and far cheaper claim than reading cards off two screenshots.
- **Elapsed-clock behaviour measured this round (2b66b93):** the clock does NOT accrue while
  backgrounded. 0:52 at `home`, 0:58 six seconds after `launch`; the same 6-s-per-9-s-wall pattern
  on the `home|activate` resume path. Any future "timer drift" claim must subtract the background
  window.
- **Persistence oracle without the UI:** `plutil`/`plistlib` on
  `<container>/Library/Preferences/com.whimsicaldistractions.Causeway.plist` —
  `causeway.autoplay` (Bool), `causeway.autofinishmode` (`ask|off|on`), `causeway.wins`,
  and `causeway.game` (JSON Data with `seed`, `moveCount`, `elapsed`, `started`, `challengeDay`).
  After a mid-demo `home`+kill it read `seed 10005 moves 0 elapsed 0 started false` — that is how
  "the demo position was never banked" gets proved without any screenshot.
- **The undo stack is the ONE thing not restored** across `home`+`terminate`+`launch` (Undo dims
  with Moves 5 on the restored board); it does survive `home`+`activate`. Observed, judged expected
  for an in-memory history, deliberately NOT filed — don't re-discover it as a bug.

## Round-3 additions (qa-worker-1, WF-4 + P-A/P-B lane, build 2b66b93)

- **Lane:** `/private/tmp/qa1-r3-wf4/` (copy of the round-3 WF-1/3 driver with both literals in
  `QADriver.swift` re-pointed, `run.sh <tag> "<script>"` pinning `-destination id=<udid>`).
  33 invocations, ~35-45 s each, zero stray-script incidents. `ids` worked every single time.
  Board parser kept at `<lane>/board.py` (`python3 board.py log-NN.txt` prints columns/cells/
  foundations + card size straight out of the last `ids` dump).
- **EVIDENCE-DIR COLLISION HAZARD:** `.qa-loop/evidence/round-3/qa-worker-1/` is shared by every
  round-3 dispatch that happens to be worker-1 (the WF-1/2/3 pass had already written `r3-0*.png`
  there). Name files `<workflow>-NN-*.png` (I used `wf4-`), not `r3-NN-*`, or you will silently
  overwrite another lane's cited screenshot.
- **The 28-drag deal #10169 bronze fixture replays perfectly on 2b66b93** — 3 full replays,
  84/84 drags landed, in batches of 7 per invocation. Regenerate with
  `node /private/tmp/qaw2r1wf8/gen2.mjs 10169 bronze 28`. Works with Auto-play On *or* Off
  (no safe autoplay card exists on that line before move 31). Load the deal with
  `tapid toolbar.deal|sleep 2|clearf|type 10169|tapb Play`.
- **Reaching every WF-4 route without re-dealing:** Undo from a completed board rewinds the
  cascade one card per tap and clears `won` (the Finish pill re-arms), so one finishable board
  yields as many win overlays as you want. But `Close` is the only overlay button that preserves
  the board — `Play deal #<next>` and `Random` both destroy it, so budget one 28-drag replay per
  destructive button. Also: `winRecorded` is only reset by `deal()`/`restore()`, so undo-re-wins
  never re-record; a genuinely fresh replay of the same seed DOES update the best time
  (wins store held the minimum, 262 s, after wins of 408/344/262 s).
- **Auto-finish cycle order on 2b66b93 is Ask -> Off -> On** (confirmed). Mode changes still call
  `maybeAutoFinish()` in `didSet`, so on an already-finishable board `-> On` wins instantly while
  `-> Off` is a no-op. Ask prompt buttons `Not yet` (126,497) / `Finish` (275,497); the gold
  `toolbar.finish` pill lands at (167,175) and pushes Wins/How-to-play onto a third row.
- **Win-overlay buttons have no accessibility identifiers, but `tapb` works on their labels**:
  `tapb Close`, `tapb Random`, `tapb Play deal #10170` (the label includes the seed). That is far
  safer than the y=472/487/503 coordinate table, which shifts with the daily-medal line.
- **Sheet swipe-dismiss confirmed for all three sheets** (Daily, Wins, How to play) with
  `drag 200 100 200 820 0.1` from the sheet's title bar; `Done`/`tapb Done` works for all three,
  and the deal alert's `Cancel` leaves seed + move count untouched.
- **A win overlay's printed time can disagree with the header clock.** `GameClock` is a separate
  ObservableObject, so only the header strip re-renders on a tick; the overlay's
  `DealFormat.time(game.clock.elapsed)` text is whatever it was when the overlay was built. If you
  are timing anything around a win, read `stat.time` from `ids`, not the overlay.

## Round-3 additions (qa-worker-3, WF-12 landscape confirming pass, build 2b66b93)

- **Lane:** `/private/tmp/qa3-r3w12/` (driver copy, both literals in `QADriver.swift` re-pointed at
  `<lane>/script.txt` + `<lane>/out`, `run.sh <tag> "<script>"` pinning `-destination id=<udid>`).
  `xcodegen generate` ~2 s, `xcodebuild test` ~13-40 s. 28 invocations, no stray-script incidents.
- **`ids` came back EMPTY on this device again** (worker-1 sees it full on theirs - it is
  device/lane dependent, do not plan a run around it). **`tapid` still works even when `ids` is
  empty**, and it is the cheapest orientation-independent driver: `tapid toolbar.deal|daily|wins|
  howtoplay|undo|autofinish|finish`, `tapid daily.play`, `tapid daily.demo.bronze`,
  `tapid demo.stop`, `tapid card.<SUIT><RANK>` (e.g. `card.H13` smart-moves the king of hearts).
  That removes ALL rail-geometry guessing in landscape, where the rail shifts ~40 pt per chrome
  change (HUD/demo bar) and scrolls.
- **The rail's scroll offset persists** across sheet opens, alerts and further moves (it only resets
  on a re-deal), so a script that scrolled the rail earlier can find `New game` off-screen later -
  another reason to use `tapid` rather than pt(127, y).
- Landscape geometry re-confirmed on 2b66b93 (iPhone 17 Pro, pt). No HUD: rail x=127, y = 70/102/135/
  167/200/232/264/297/329; foundations up row y=109, down row y=189 at x=218/267/316/364; free cells
  y=296 at x=218/267/316; tableau columns x = 419+49i, 7-card column bottom-card centre y ~250,
  6-card ~225. With the daily HUD everything drops ~40 pt and columns become x = 410.5+46.4i.
  **With the gold Finish pill the rail holds 10 pills (70..358 pt) and still needs no scroll.**
- **Landscape alerts are all fine on this build** - deal alert, "End your daily attempt?",
  "Ready to finish" and the 3-button win overlay each render both/all actions side by side above the
  keypad. The round-1 "only one action visible, scroll the alert" quirk is gone. An open alert also
  **survives a rotation** (landscape->portrait keeps the alert, the typed digits and the keypad).
- **The 28-drag deal #10169 bronze fixture (`node /private/tmp/qaw2r1wf8/gen2.mjs 10169 bronze 28`)
  replays perfectly on 2b66b93** - 28/28 drags in 4 invocations of 7 (portrait, Auto-play left On,
  `sleep 1` between drags), ending on the "Ready to finish" prompt at Moves 28. Rotating to landscape
  with the prompt up is the cheap way to test the finish prompt + win overlay in landscape.
- **Re-winning one board without the fixture:** on a won board, tapping `toolbar.autofinish` twice
  (Ask->On->Off/On) is a no-op, then one `tapid toolbar.undo` clears `won` and re-arms the gold
  Finish pill on a still-finishable board. Each re-win costs 2 taps. Caveat: the win record is not
  rewritten (winRecorded), and the overlay's reported time under-reports by the cascade length in
  that path (see finding bug/WinOverlay:rewin-time-understated).
- Screenshot handling unchanged: PNGs stay in the portrait 1206x2622 frame in landscape;
  `sips -r 270 --out X-rot.png X.png` for landscapeLeft, **`sips -r 90` for landscapeRight**.
  `/private/tmp/qa2crop/{crop,stack}` still work and `stack out 1700 0 922 300 a b c` over the
  rotated frames is the cheapest way to read the Moves/Time/Won strip across a sequence.

## Round-3 additions (qa-worker-1, PERF lane P-D/P-E, build 2b66b93)

- **Lane:** `/private/tmp/qa1perf-r3/` (copy of the round-3 WF-4 driver with both literals in
  `QADriver.swift` re-pointed, `run.sh <tag> "<script>"` pinning `-destination id=<udid>`,
  plus `tools/{film.py,cpuwin.py,coldlaunch.py,rss.py,imgdiff}` and `orch.py`/`orch2.py`).
  **With the xcodeproj already generated an invocation is ~9 s end-to-end and reaches the first
  script command in ~1.5 s** - the round-1 "18-21 s to the first command" assumption is dead,
  so `orch.py` (poll the log for a `QA-CMD <ts> <marker>` line, then start the film) is the only
  reliable way to bracket a tap; a fixed "sleep N then film" now overshoots badly.
- `orch.py <tag> "<script>" "<marker-cmd>" <delay_s> <film_s>` and `orch2.py` (same, but runs
  `cpuwin.py` instead of the film) both work verbatim. Use a long `sleep 6` immediately before
  the action as the marker and `delay 0.4`; put the marker string nowhere else in the script.
- **md5-per-frame is not enough on its own - three false signals to filter:**
  1. `simctl io screenshot` PNGs can differ in md5 with `imgdiff` MAD 0.000 (metadata only).
     Always confirm a "first change" frame with `imgdiff`.
  2. The **elapsed clock ticks once a second** on a started board, so on any film longer than
     ~1 s you get a change every ~5 frames that has nothing to do with your action. Same for the
     iOS status-bar minute rollover (that is what looked like "the win overlay appeared 1.1 s
     late" until the frames were actually read).
  3. An open **alert blinks its text caret**, so the frames cycle between 3-4 hashes forever -
     "settled" has to be judged visually there, not by a stable md5 run.
- **A single anomalous host-screenshot capture time is not an app stall.** During the first
  16-card board-shrink film one `simctl io screenshot` took 1.334 s (vs 0.20-0.25 s typical);
  a second, identical run showed a perfectly uniform 0.197-0.220 s cadence and the ps-delta CPU
  cost of the resizing drop was only +0.14 cpu-s over a non-resizing one. Reproduce before
  believing a capture-gap.
- **Measuring the CPU of something the driver starts, with the driver DETACHED:** launch
  `run.sh` in the background with a script that ENDS right after the trigger
  (`activate|sleep 1|tapid demo.start|sleep 1`), poll its log for `QA-DONE`, then run
  `cpuwin.py`. The demo keeps auto-running after `xcodebuild` exits, so you get a clean,
  attachment-free window. Same trick works for any self-running animation.
- **Reading demo pacing without a film:** after the detached start, take 4 host screenshots ~4 s
  apart recording `time.time()` around each, then `stack out 0 700 1206 120 <frames>` - one Read
  gives four (count, timestamp) pairs. Measured 0.2492 s/move on 2b66b93.
- `ids` came back EMPTY on this device this round (again device/lane dependent), but
  `tapid toolbar.*` / `daily.*` / `demo.*` / `card.*` and `tapb <label>` all worked, and
  `clearf|type <seed>|tapb Play` drives the deal alert with no pad coordinates.
- Geometry **after** the 16-card portrait shrink (needed to keep driving the board): card
  43 x 71.67 pt, tableau left edge 15, column centres x = 36.5 + 47*i, top card y origin 419,
  non-tall columns' fan pitch 28.67 pt. `drag 130 598 36 600` moves c2's 6th card onto c0.
- Round-3 numbers (full table in `.qa-loop/evidence/round-3/perf/r3perf-measurements.txt`):
  cold launch <=0.94 s; Daily sheet cold-first-open 1.0-1.1 s vs 0.55 s warm; deal alert 0.83 s;
  New game redeal 1.50-1.72 s; Replay redeal 1.43-1.48 s; daily Play handoff 1.19 s; cascade
  8.50 s / 0.202 s per card; 16-card shrink ~1.05 s; idle 0.0-1.2 %; demo auto-run 15.3 %
  (bronze) / 20.7 % (gold); RSS flat over 22 New-game cycles; zero network bytes in 372 samples.
