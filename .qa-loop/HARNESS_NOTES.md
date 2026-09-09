# Harness notes

Environment/tooling knowledge for testers. Append what you learn; keep it SHORT — every
tester pays for this file every dispatch. Loop 1-2 driver-era notes (86 KB) are archived at
`.qa-loop/archive/20260822-125736-f949d82/HARNESS_NOTES-full.md`.

## Environment (verified 2026-09-09, loop 5)

- App: `com.whimsicaldistractions.Causeway`, Debug for the iOS Simulator. Workers this loop are
  `causeway-qa-1..3` (iPhone 17 Pro, iOS 26.5, 402 x 874 pt portrait) — pass YOUR udid everywhere.
- **Drive the app with the QADriver, not the MCP control tool** (it needs a human grant; the driver
  is a superset). Read `.qa-loop/driver/README.md` once. With `Q=python3 .qa-loop/driver/qa.py <udid>`:
  `$Q launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` (the date pin), `$Q tap X Y`, `$Q tapid <id>`,
  `$Q tapbtn <label>`, `$Q drag X1 Y1 X2 Y2`, `$Q type <text>`, `$Q alert`, `$Q labels
  texts|buttons|textfields|any [substring]` (ALL visible labels/frames/values in one 0.3 s call —
  prefer it to screenshots), `$Q find <id>`, `$Q rotate landscapeLeft|portrait`, `$Q shot
  /abs/path.png` (1206x2622 px; ÷3 for points). "driver not serving" → `bash
  .qa-loop/driver/start.sh <udid>` (idempotent; the server exits after 5 h).
- Identifiers: cards `card.<S><rank>` (`card.D1` = A♦; S = C/D/H/S), toolbar `toolbar.<newgame|undo|
  replay|autoplay|autofinish|deal|daily|wins|howtoplay|finish|rail.more>`, header `stat.<moves|time|won>`,
  HUD `hud.chip.<tier>` (state glyph) / `.label` (text) / `hud.day` (past-day only), win overlay
  `win.<overlay|dealline|dailyline|play|random|close>`, Wins `wins.dealentry.<field|play>` /
  `wins.row.<seed>` / `wins.range.<lo>`, daily sheet `daily.<play|clears|lockednote|export|import|
  backupnote|flawless.pending>`, `daily.cal.<idx|prev|next|month>`, `daily.card.<header|title|
  flawless|seed>`, `daily.tier.<tier>` (value earned|open), `daily.sameday` (value
  cleared|today|grace|past), `daily.streak.<play|ontime|silver|gold|flawless>` (value = streak),
  `daily.demo.<tier>`, demo bar `demo.<headline|prev|next|start|stop|done>`.
- **Deal-# entry:** `tapid toolbar.deal` → field PRE-FILLED and focused (replay = `tapbtn Play`).
  `selectall` + `type 500001` replaces the value; confirm with `labels textfields`, and if it
  APPENDED, `tap 200 324` then redo. `key tab` hides the keypad (never `key delete`; keypad-down
  moves Play to 205,505 over the confirm's destructive button — the 0.5 s gate protects it;
  `sleep 0.6` before a deliberate destructive tap). Out-of-range input greys Play. Wins field
  `wins.dealentry.field` is not auto-focused (`tap 180 191`; `key tab` inserts a TAB there).
- A `drag` drives the app's manual card DragGesture (pickup + drop); a 0-hold flick (`drag x1 y1 x2 y2 0`)
  picks up too — there is no press-and-hold threshold to work around;
  `tapid card.H13` = smart-move (for `card.*` ids the driver taps the card's exposed TOP strip, so
  covered cards are addressed correctly). Covered cards are not movable — check the column.
  A plain `tap X Y` on a card is NOT dropped: 13/13 registered (card face, 30 pt top strip, and a
  no-sleep 3-tap burst) — loop 5 r3, so a "tap did nothing" is the app refusing, not a lost gesture.
- Reset state: `xcrun simctl uninstall <udid> com.whimsicaldistractions.Causeway` then `install`
  from the .app path in your dispatch, then `$Q launch …`. There is no in-app reset.
- Rotation works (`rotate`). `xcrun simctl ui <udid> content_size <cat>` = Dynamic Type (live; since
  42b5f7e the Daily sheet and How-to-play scale — cells/labels move, re-`labels`; the board's card
  text stays fixed by design). Category names are hyphenated lower-case
  (`accessibility-extra-extra-extra-large`). Reset to `large` when done. The Daily CALENDAR only
  scales at ACCESSIBILITY sizes — cells are 49x40 at `large` AND `extra-extra-extra-large`, 49x50 at
  `accessibility-medium`, 49x92 at AX5 (since 836434d) — test marker clipping at AX sizes, not XXXL.
  At AX5 the whole Daily sheet is ~5 swipes tall (streak cards 118x103 -> 370x260, one per row), so
  scroll to the section BEFORE `labels any` (off-screen = count=0) — budget ~6 swipes to reach the calendar.
- A sheet keeps DECELERATING for >1 s after a `swipe`: `labels` and `shot` taken back-to-back can
  disagree by ~150 pt. `sleep 2` before a sheet `shot`, and re-`labels` right before it if you are
  cropping to a frame. (`sips --cropOffset Y X` IS top-left-based; a mismatch is the scroll, not sips.)
- In a PORTRAIT sheet `labels texts` returns the WHOLE scroll content, off-screen rows included, so
  one call asserts a sheet's entire copy with no scrolling (landscape sheets differ — see below);
  but `labels any`/`find` see ON-SCREEN elements only (bottom-scrolled sheet → `labels any
  daily.streak` count=0; scroll up first — that faked a "missing identifier" once).
  It escapes real newlines as `\n`; a literal `\n` in a dump is NOT a rendering bug.

## Board geometry (iPhone 17 Pro, device points)

- **Do not hard-code coordinates: ask the driver.** `labels buttons` gives every pill's frame (pills
  REFLOW after a win or with a Finish pill); `labels any card.` every card's frame (`labels texts
  card.` gives 0). Frames are ORIGINS: +22/+37 for a card centre. Portrait reference: foundations
  up-row y≈296 / down-row 374 at x≈28/77/126/175; free cells y≈296 at x≈274/323/372; columns
  x = 28+49c, card i top y = 425+30i; a live challenge HUD pushes the board down ~73-90 pt.
  Portrait TALL col (r4, #10004): ITS fan pitch alone 30(<=12)/28@13/24@15, cards 45x75; on the 16th the
  WHOLE board (tableau+cells) -> 43x71, tableau re-centres x=15+47c, no regrow till New game/Replay/deal.
- Foundation COLUMNS are suit-fixed left-to-right in Suit.allCases order **♠ ♥ ♦ ♣** (Cards.swift:5),
  not C/D/H/S: A♠ landing in the leftmost up slot is correct, not a mis-target.
- **`sleep 1` after every card `tapid`/`drag`**: the board relayouts and the next `tapid` resolves
  against a stale frame (this faked a "wrong card moved" bug twice in one dispatch).
- Tap = `smartMove`: gated by `isSeqHead` (the run must reach the column BOTTOM) and a single card
  always falls back to a FREE CELL — a bottom card wiggles only once all 3 cells are full (`drag`
  two bottoms to cell centres x≈275/324/373, y≈295). Deal **646203** is the tap fixture: col2
  S12+H13 = tidy run not reaching bottom (wiggle); D2, H2, then col4 H12+S13 moves as a pair.
- **Proving "no visible feedback"**: film (`xcrun simctl io <udid> screenshot` loop) + `imgcrop_diff.py`
  cropped to the CARD (pt×3; col3 bottom = `280 1780 480 2060`), 26-30 frames: the refusal wiggle is
  1-2 frames at 10-28% changed (10.4% measured on a col-0 card, crop `0 1440 200 1700`), truly
  silent is 0.0%. Since 3407a77 EVERY fruitless tap wiggles
  (buried, liftable-with-nowhere-to-go, stuck free cell); a snapped-back DRAG never does, by design.
  No haptics or sounds anywhere in the app.
- Landscape (874 x 402 after `rotate landscapeLeft`): rail pills at x≈127 in a scroll window that
  ends half-way through a pill; `toolbar.rail.more` (label "More controls" / "Back to the top of
  the controls" at the end) scrolls it. In a landscape SHEET `labels` returns scroll-content frames
  beyond 402 pt; the `Vertical scroll bar` frame is the visible window.
- Landscape card size = tallest column seen THIS DEAL (fb45f4b latch, reset by New game/deal/undo
  to 0; since de5e5d0 a RESTORED save seeds the latch from its own board — no first-move pulse):
  45x75 at 7-8, 42x70 at 11, 39x65 at 12, 36x60 at 13, 34x57 at 14, floor 30x50 at >=16 (deeper columns just
  compress the fan; 20 fits). Synthetic deep-column fixture: any tableau restores unvalidated —
  empty foundations encode as `"up":[0,0,0,0],"down":[14,14,14,14]`, cells `[null,null,null]`.
- Alerts: while one is up `labels`/`find` return nothing — `$Q alert` and tap the FRAME it prints
  (`tapbtn New game`/`Replay` is ambiguous with the pill behind). Rows move with body length
  (y≈483-503). Titles: casual New game "Discard the game in progress?", daily New game "End your
  daily attempt?", Replay "Start this deal over?" / "Restart your daily attempt?", any live ⏰ grace
  "Give up ⏰ Same-day for <day>?" (wins over all; verified r4 for BOTH controls). `daily.play` over a
  live casual game is a 3rd variant — "Discard the game in progress?" with buttons Keep playing /
  **Start over** (rows y≈503). NO confirm fires for New game on a live DAILY at Moves 0 (hasLiveGame =
  moveCount>0 || graceLive) — by design, not data loss; only a GRACE confirms at 0 moves.
  A confirm raised from a DISMISSING alert/sheet keeps its destructive button disabled 0.5 s — `sleep 0.6` first.
## Rules and traps that cost earlier testers a run

- `terminate`+`launch` RESTORES the in-progress game (board/moves/clock): a "cold launch" case is NOT
  a fresh board. Reset deterministically with `toolbar.replay` (confirm sits 10 pt higher than the Deal
  one — `Replay@205,483`, tap 275 507) or the Deal # alert.
- Auto-play deliberately leaves an exposed ACE on the tableau (both directions build, so an
  opposite-colour 2 may still need it — `isSafeAutoplay`, Game.swift:685). By design; do not file.
- Tableau build rule: alternating colour, rank ±1 **in either direction**, but a 2-card tail fixes
  the direction: a descending card dropped on an ascending tail is refused BY DESIGN.
- Mode changes call `maybeAutoFinish()` in `didSet`, so all three Auto-finish modes can be
  exercised on ONE finishable board: Off (Finish pill) → Ask (prompt) → On (cascade).
- The Deal alert is `Play`/`Cancel` only (Random removed on purpose); Wins' "Play a deal" field
  validates (disables Play + `wins.dealentry.problem`) instead of clamping.
- zsh: `rm -f dir/*.png` with no matches ABORTS an `&&` chain (nomatch) — use `rm -f dir/f*.png 2>/dev/null;`.
  Also: `$Q` does NOT word-split in zsh (`Q="python3 …/qa.py <udid>"` → "no such file") — use `${=Q}`, and
  absolute paths: the agent's cwd resets between Bash calls, so `cd <repo>;` first or `.qa-loop/…` fails.
## Fixtures, Daily sheet, demo bar, win overlay — see `.qa-loop/tools/README.md`

- Read `.qa-loop/tools/README.md` when a case touches the Daily sheet/calendar, a demo, a win, or an
  injected board: `make_save.mjs … | inject_save.py <udid>` then `launch` → Finish prompt (cascade
  ≈ 4-6 s; `--tier gold|flawless` FAILS on days 10/11/14 — day 13 under pin `2026-08-14` is the
  flawless fixture); calendar cells are LAZY (one swipe first; ids are dayIndex); win-overlay
  buttons have no ids; Auto-finish mode PERSISTS across relaunch; the plist LAGS the app — assert
  on the SCREEN; `terminate`+`launch` with the next day's pin IS the day boundary.
- Do NOT tap during an auto-finish cascade: an `Undo` mid-cascade aborts it ~2 moves short of the win
  and leaves a `toolbar.finish` pill (measured 1a63ce2). Wait ~12 s, then act.

## Performance measurement (PERF lane only)

*(Recipes and baselines: `.qa-loop/archive/HARNESS_NOTES-perf-section.md`.)*

## Rig hazards

- **NEVER `killall Simulator` / quit Simulator.app: it SHUTS DOWN EVERY BOOTED DEVICE**, including
  other sessions' (measured). If you did, `xcrun simctl boot <udid>` yours back.
- A wedged worker (`Busy`, `Timeout waiting for screen surfaces`): `xcrun simctl boot <udid>`, wait
  ~30 s, `bash .qa-loop/driver/start.sh <udid>`. UserDefaults survive; demo state does not.
- Screenshots are ~2 MB; keep only real evidence.

