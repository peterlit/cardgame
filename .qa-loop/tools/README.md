# `.qa-loop/tools/` — the testers' reusable rigs

Read this when a test case needs a FIXTURE (a finishable board, a solved day, a zero-move
attempt, a pinned deal shape) or image evidence. Everything here is shared across parallel
workers; edit in place, never copy into scratch.

## Fixtures (finishable boards, solved days, zero-move attempts)

- Finishable / solved boards: `make_save.mjs … | grep '^{' | python3 inject_save.py <udid>` then
  `launch` → the Auto-finish:Ask prompt (`tapbtn Finish`, `sleep 12`). **`--tier gold|flawless`
  fails on days 10, 11, 14** — day 13 (pin `2026-08-14`) is the flawless fixture, day 12 the
  tier-banking one (day 12 takes silver, gold AND `--tier flawless`, so the whole banked-→-flawless
  transition is testable on ONE day: inject+Finish each in turn
  = the ✓✓✓-banked-but-`flawless:false` fixture, 2 cycles ≈ 6 turns), day 14 takes `--tier silver`.
  An injected save carries NO undo history (`find toolbar.undo` → `enabled=false`), so a `no-undo`
  Silver cannot be burned on an injected board — violate it with a real move instead.
  `zero_move_save.mjs` = the ⏰-grace-at-zero-moves
  state. `inject_save.py` writes ONLY the `causeway.game` key (an on-disk `causeway.daily` survives, so cross-run
  tier-banking fixtures work) but it RACES the app's unflushed `causeway.daily` (verify the tier on the SCREEN
  before injecting the next save); the plist LAGS the app (cfprefsd) — never assert on a plist read
  of a RUNNING app. But `terminate` + `sleep 3` DOES flush it, and a
  `plistlib.load(...)['causeway.daily']` read at that moment is the cheapest proof a record survived
  before the next injection (defeats the CC-15-B phantom-data-loss trap; verified loop 5).
  After a REINSTALL it errors "no preferences plist … launch the app once first" — `launch` +
  `terminate` first. Two injected wins record the SAME time (elapsed 90 + ~12 s cascade = 1:42):
  patch the JSON's `elapsed` between `grep '^{'` and `inject_save.py` to vary the recorded time.
- `deal_scan.mjs` finds a pinned deal with a wanted shape (#1793: exposed A♠/K♠ + a movable run);
  `save_at.mjs` parks a save mid-line — **copy it into your 3-deep scratch dir and its `../../../`
  imports resolve as-is** (`--mode move --at N --challengeDay none --startDay none` = any point of a
  day's line as a CASUAL game; day 14 bronze move 51 exposes a safe K♥ = the auto-play positive
  control; `make_save --day 14 --tier bronze --challengeDay none --startDay none` = a casual
  finishable board, Moves 77 → cascade 100). With **Auto-play On an injected save auto-sends on
  launch** (moveCount +1 before you touch anything) — set Auto-play Off first if the count matters.
  `imgcrop_diff.py`
  = pure-python frame diff (source px); crop with `sips -c` before `sips -Z`; `rm -f`, not `rm`.


## Daily sheet, demo bar, win overlay

- `tapid toolbar.daily` → `swipe 200 700 200 200` (ONE swipe reaches the bottom on 1a63ce2 — the
  sheet is 2 pages; a second is a no-op) → calendar. `tapid daily.cal.<idx>` re-finds the element,
  so a month change never needs a cached frame. Cells are LAZY (`tapid
  daily.cal.<idx>` fails before the scroll); the id is the dayIndex (`daily.cal.0` = Aug 1 …
  `30` = Aug 31, `31…60` = Sep). `daily.cal.prev/next/month` navigate (`enabled=false` at the pool
  edges); a month change shifts every cell ~44 pt — re-`find`. From the bottom-scrolled position a
  tapped day's card header sits ABOVE the fold (y≈-25): assert with `labels`, don't screenshot. A
  downward swipe from the top of the content DISMISSES the sheet; `tapbtn Done` also dismisses.
  Tapping a LOCKED future day does NOT move the top day card (it keeps the last playable selection)
  — it only renders `daily.lockednote` below the calendar; the demo pills still shown are TODAY's.
- Day-card FLAWLESS state is a text badge in the card HEADER — `labels texts` → `[86,443] 🌟 Flawless`
  between `Today` and `Deal #N`, present only when earned; there is NO unearned branch, so a banked
  ✓✓✓ day and a flawless day differ by that badge alone (open `ux/WF-15:day-card-banked-tiers-read-as-flawless`).
- Day-card earned state is IMAGES, not text: since 42b5f7e `labels images` reads the state outright —
  `checkmark.circle.fill earned` / `xmark.circle missed` (solved, tier missed) / `circle not attempted`.
  Calendar cells say it too: `find daily.cal.<i>` → `Aug 6, selected, earned Bronze, Silver`,
  `Aug 15, today, not yet cleared`, `Aug 14, today, selected, Flawless, all three medals in one run,
  cleared on the day`, `Aug 16, locked until that date` — assert day state with `find`, not pixels.
  Cheapest per-tier assertion there is; order is Bronze/Silver/Gold top-down at x=352.
- Chip state (`·`/`✓`/`✗`) is inside each chip's text: `labels texts | grep -E "🥉|🥈|🥇"` — since
  836434d the objective TEXT is a separate `hud.chip.<tier>.label` element, so use `labels any hud.`
  to read state and wording together. `hud.day`
  exists only on a PAST-day challenge. Two elements share `daily.clears` on a multi-run day —
  `labels any daily.clears`, not `find`. Streak cards have whole-card labels:
  `labels any streak` → `Same-day: current streak 1 days, 1 days total, best 1 days`.
- Opening `toolbar.daily` while a PAST-day challenge is live resets the selection to Today
  (`daily.play` reads plain "Play"; that is proposal `ux/WF-13:daily-sheet-resets-to-today-midattempt`);
  `daily.play` on a live game raises "End your daily attempt?" (challenge) vs "Discard the game in
  progress?" (casual) — but since 42b5f7e a live ⏰ GRACE overrides both, and all four
  board-replacing controls (`daily.play`, `daily.demo.<tier>`, `toolbar.replay`, `toolbar.newgame`)
  title it "Give up ⏰ Same-day for <day>?" (bodies still differ sheet-vs-board; verbs unchanged).
  Grace-payout WIN fixture (the overlay's day-prefix branch): inject `make_save --day 13 --tier
  flawless --challengeDay 13 --startDay 13` and `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` →
  Finish → "Aug 14: 🌟 Flawless! … ⏰ On time"; the same save pinned 2026-08-14 gives the
  unprefixed same-day line. Deal numbers are UNGROUPED everywhere (`DealFormat.seed`): the overlay
  reads `Deal #720307`, so a doc expecting `#720,307` is stale, not a bug.
- Demo bar ids `demo.next`/`demo.start`(Start/Pause/Resume)/`demo.stop`/`demo.done`/`demo.headline`.
  After Stop/Done `started` is false: no Finish pill / auto-finish until one real move. Headline
  `Winning line · N / TOTAL` (silver/gold/flawless name the objective and wrap, pills drop to y≈260);
  TOTAL = the line's length in `data/daily-solutions.json` (seed 608530: bronze/silver 100, gold 97).
  Since 836434d the bar is a `ViewThatFits`: ONE row while the headline fits (bronze 0/N, pills y250),
  else headline ABOVE a full-width pill row (bronze paused 61 pt tall, pills y271; gold 68/78 pt, y286;
  FLAWLESS paused mid-line 92 pt on days 5/14 and 108 pt on day 13's 3-line headline, pills y301/y316 —
  bar top = headline y - 8, bottom = pill y + 26 + 8; ux/WF-15:flawless-demo-banner fixed on de5e5d0).
  Re-`labels buttons` after each step; the 21 pt shift when Prev appears does not eat a repeat tap.
  The trailing `…` while a demo RUNS is the deliberate playing suffix, not truncation.
  `stat.moves`/`stat.time` read `—` during a demo, and the daily objective HUD chips are HIDDEN for its
  whole run — tier telemetry cannot be read mid-demo (assert on the headline instead). A demo auto-runs at
  ~4 steps/s (day 13 flawless = 79 steps ≈ 20 s) and ends on `demo.done` + headline "That's a Flawless line
  — tap Done to try it yourself." Demo-pill confirm rows: y493 (daily) / y503 (casual).
- Since 836434d `demo.prev` exists while PAUSED with idx>0 AND on the completion banner (`demo.prev`
  + `demo.done`; Prev there re-enters the demo paused at N-1, Next/Resume restores the banner);
  absent at 0/N and during the auto-run. It re-simulates from the deal,
  so `labels any card.` after Prev-to-N is byte-identical to the forward-stepped N (use that diff as the
  fidelity assertion); rapid taps with no dwell are safe. It widens the pill row to 4 (layout note above).
- Win overlay: since 836434d everything is addressable — `win.overlay` (container), `win.dealline`,
  `win.dailyline`, `win.play`/`win.random`/`win.close` (the headline "You solved it! 🎉" still has no
  id). `tapid win.play` deals nextSeed, `win.random` a random deal, both at Moves 0. `win.dailyline`
  is ABSENT on a REPEAT win of an already-banked day (post-win `Undo` → `toolbar.finish`), and the
  rows sit ~24 pt higher without it — re-`find`, don't cache frames. Repeat wins do not bump `stat.won`. `tapbtn "Not yet"` on the auto-finish prompt leaves a
  `toolbar.finish` pill, so you can read the HUD (e.g. `🥇✗`) BEFORE the win.
- **Auto-finish mode PERSISTS across relaunch and save injection** — a previous case's `On` makes
  the next injected board cascade to a win right after `launch` (phantom auto-win). Set `Ask`/`Off`.
  `tapid toolbar.autofinish` cycles **Ask → Off → On → Ask**; from a won game, post-win `Undo` then
  `On` cascades a whole extra recorded run in ~15 s (with `Ask` it is Undo → `toolbar.finish` pill).
  Toolbar `tapid`s are SWALLOWED by the overlay scrim — `win.close` FIRST, then cycle the mode (a
  silent no-op cost 2 turns, r4). A `Not yet` deferral survives further moves AND terminate+launch:
  the Finish pill stays and the prompt never re-nags for that game (r4).
- Wins rows are single a11y elements labelled with the bare seed (`608530`): `labels any`, not
  `texts`. Tapping a row routes into Play-that-deal; the drilled-in list has no `Done`, only
  `BackButton`, and win-row DATES use the real clock, not `CAUSEWAY_TODAY_OVERRIDE`. A WON game is
  not "live" (loading a deal after a win raises no discard confirm); post-win `Undo` re-arms it
  (moves 100->99, clock resumes) = a cheap extra run.
- **Wins fixture for ARBITRARY seeds:** `restore()` never checks board-vs-seed, so patch `seed`
  (and `elapsed`, for distinct times) in a `make_save --day 14 --tier bronze --challengeDay none
  --startDay none` blob before `inject_save.py`, then `launch` -> `Finish` -> overlay `Close`:
  each cycle (~20 s) records a REAL win under any deal number (seed `1000000` = Game.maxSeed is the
  widest-grouping edge and makes the overlay's next-deal button WRAP to `Play deal #1`; patching
  `elapsed` past 3600 shows `62:25`, minutes-not-hours, on both header and overlay). 4 cycles built the range fixture
  500001 / 608530 / 608531 / 608533 ("4 deals solved · 3 ranges"). Won-count survives re-injection.
- **The date pin makes the day boundary real:** `terminate` then `launch CAUSEWAY_TODAY_OVERRIDE=
  <next day>` keeps the saved game (challengeDay/challengeStartDay) and moves `todayIndex()`.
  Proof the pin took: `find daily.cal.15` label = `Aug 16, locked until that date` under Aug 15.


## Files export / import sheets (system UI — verified 2026-09-09, iPhone 17 Pro pt)

- Exporter (`tapid daily.export`): `labels` returns only a mislabelled `Cancel` at [263,92] which is
  really the `…` menu — `Save` is at **352,109**, the back/close chevron at **37,110** (tap it twice
  from "On My iPhone": once to Browse, once to cancel → note "Export cancelled."). Files land in the
  LocalStorage group `File Provider Storage/` (find it by MCMMetadataIdentifier
  `group.com.apple.FileProvider.LocalStorage`) — read/write them from the Mac to stage fixtures.
- Since 42b5f7e the default name is `Causeway-Stats-<yyyy-MM-dd-HHmmss>` (real clock, NOT the date
  pin), so repeat exports never collide — 4 back-to-back exports = 4 files, 0 alerts, and the sheet's
  present/dismiss floors the interval at ~4 s. The "Save as" row (bottom of the sheet, crop px y2000+)
  is the only place the name shows and it TRUNCATES to `Causeway-Stats-2026-…`. If you force a
  collision by typing an existing name, "Replace Existing Items?" = `Replace` 201,461 / `Keep Both`
  201,516 / `Stop` 201,570 and **`Replace` WEDGES the sheet and trashes the old file** — use
  `Keep Both`; escape a wedged sheet with `swipe 200 120 200 800`.
- Importer (`tapid daily.import`) opens on **Recents**; `tap 322 818` = Browse tab, `tap 200 324` =
  "On My iPhone". Every file is an element whose IDENTIFIER is its filename — `labels any | grep json`
  gives exact frames (row 1 icons y≈257 at x 71/201/331, row 2 y≈454). Tap the ICON, not the label;
  the merge fires immediately with no confirm. The picker CLOSES after a pick — re-`tapid daily.import`
  before the next one (a stale-note read faked a "second import did nothing" for one dispatch).

## Index

- `make_save.mjs`, `inject_save.py`, `zero_move_save.mjs` — see "Reaching a finishable board".
- `deal_model.mjs` + `deal_scan.mjs` — the deal generator in node; `deal_scan.mjs` finds a PINNED
  deal with a wanted shape (edit its predicate). **#1793**: A♠ and K♠ exposed at column bottoms, a
  movable 6♥/7♣/8♥ run (c2 → c6).
- `save_at.mjs --day D --tier flawless --mode firstfinish|autoplaybreak|move --at N` — parks a save
  at an ARBITRARY point of a day's line (`autoplaybreak` = where a safe auto-play send breaks a
  Gold). **Its imports are one `..` too deep — fix `../../../tools` → `../../tools` before use.**
- `imgcrop_diff.py X0 Y0 X1 Y1 base.png frame.png [...]` — pure-python crop-diff (no PIL/ImageMagick
  on this host). Coords are SOURCE PIXELS (= points × 3). Filming: loop `xcrun simctl io <udid>
  screenshot film/f$i.png` in a background bash task (~4-5 fps) while driver taps run.
- LANDSCAPE screenshots are stored 1206x2622 with a rotation flag, so `sips -c` offsets do NOT map
  to landscape points — crop only if you then eyeball it; a whole-frame `sips -Z 900` is the reliable
  landscape evidence shot.
- Cheap evidence: `sips -c H W --cropOffset Y X in.png --out crop.png` (source px, y then x), then
  `sips -Z 560 crop.png` (`-Z` sets the LARGER side — crop first); `rm -f` the 2 MB original (bare
  `rm` prompts and silently keeps it). Or skip images: use `labels`.

