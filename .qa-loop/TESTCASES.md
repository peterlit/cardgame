# Causeway — QA Test Cases (EXPLORATION output)

Derived by driving the booted simulator (portrait, 402x874 pt tap space) and
reading the SwiftUI/model source. These are replayable scripts; each round the app
is reinstalled fresh (no prior stats/wins). "Today" = daily deal **#10,003**
(Aug 14 2026); the daily pool spans **Aug 12 (index 0) → Aug 14 (today)**, later
days locked.

## Screen map (confirmed live)

- **Main / board.** Header (title + Moves/Time/Won). Toolbar pills (wrap via
  FlowLayout): `New game` (gold/primary), `Undo` (disabled+40% opacity when no
  history), `Replay`, `Auto-play: On/Off`, `Auto-finish: Ask/On/Off`,
  `Deal #<seed>` (shows a `✓` when that seed is already won), `Daily`, `Wins`,
  `How to play`. A `Finish` (gold) pill appears only when `game.canOfferFinish`.
  Below: FOUNDATIONS (up row + down row, 4 suits) on the left, FREE CELLS (3) on
  the right, then 8 tableau columns. `Daily` pill is only present when the pool is
  non-empty (it is here).
- **Deal alert** ("Play a deal"): text field prefilled with current seed,
  numberPad keyboard (digits only — no minus/letters), buttons `Play` /
  `Random` / `Cancel`.
- **Daily sheet** ("Daily Challenges"): 4 streak cards (Play/Silver/Gold/Flawless,
  each: current big number, "N total", "best N"); Today card (Deal #10,003; Bronze
  "Clear the deal", Silver "Open all four down-foundations within your first 20
  moves", Gold "Send all four Kings to the down-foundation before any Ace"; each
  with a checkmark circle); `Play` button; "Show me how to win:" row with
  `🥉 Clear` / `🥈 Silver` / `🥇 Gold` pills; month calendar (Aug 2026; 12/13/14
  tappable, 14 gold-outlined = today, 15+ dimmed/locked); BACKUP section with
  `Export` / `Import` and a note. `Done` (top-right) dismisses.
- **Wins sheet** ("Deals won"): "Play a deal" field (Number 1–1,000,000) with a
  `Play` button disabled while the field is empty/<1; empty state "No wins yet —
  go solve one!"; once wins exist, "N deals solved · M ranges" and tappable range
  chips → drill-in list with moves/time/date + replay. `Done` dismisses.
- **How to play sheet**: sections Goal / The catch / Tableau / Free cells /
  Controls, then About (`Causeway · v1.0 (1)`, "© 2026 Whimsical Distractions…",
  "An original two-ended-foundation solitaire."). `Done` dismisses.
- **Win overlay**: dark scrim; "You solved it! 🎉"; "Deal #S · N moves · M:SS";
  optional daily line (medals earned / "🌟 Flawless!"); buttons
  `Play deal #<next>` / `Random` / `Close`.

Note on tap mapping: screenshots return a larger PNG; multiply screenshot px by
~0.436 to get the 402-wide point coordinate used by the control tool.

---

## WF-1 — Understand the game & make a first legal move (Novice)

**TC-1.1 (Novice) — Discover objective + controls, make one legal move.**
1. Launch (cold). Observe header subtitle "build each suit from both ends" and the
   FOUNDATIONS / FREE CELLS labels.
2. Tap `How to play`. Read Goal + Controls.
3. Tap `Done`.
4. Tap the bottom (fully exposed) card of a column that has an obvious home. On the
   restored dev deal a King at a column bottom (e.g. K♠ at the bottom of column 8)
   taps to its down-foundation; on the daily/random deal, tap any exposed Ace (→ up
   foundation) or an exposed card that fits an alternating-colour neighbour.
- **Expected:** rules legibly state both-ended foundations + tap-to-move + drag;
  the tapped card animates to a sensible target; Moves increments to 1; clock
  starts; Undo enables.
- **Effort bar:** a novice makes a correct move within ~1 min using only on-screen
  affordances (How to play + tap). Discoverability finding if the objective/controls
  cannot be figured out from the board + How to play alone.

**TC-1.2 (Novice) — Tap a card with NO legal foundation/tableau home.**
1. Cold launch. Tap an exposed card whose only home is a free cell (e.g. a bottom
   card with no matching foundation step and no alternating-colour neighbour).
- **Expected:** smart-move parks it in a free cell (last-resort) rather than doing
  nothing silently, OR clearly does nothing if truly unmovable. Record whether the
  novice can tell WHY nothing "useful" happened (potential discoverability finding).

---

## WF-2 — Core moves: tap-to-smart-move and drag-to-place (Both)

**TC-2.1 (Both) — Tap smart-move sends the obvious card home.**
1. Cold launch. Identify an exposed card that belongs on a foundation.
2. Single-tap it.
- **Expected:** card moves to the correct foundation (up pile for A→, down pile for
  K→), no mis-target; one tap; Moves +1. CONFIRMED live: tapping bottom K♠ sent it
  to the spades down-foundation.
- **Effort bar:** exactly 1 tap, no press-and-hold, no confirmation.

**TC-2.2 (Both) — Tap a run head moves the whole run.**
1. Cold launch (or set up a tidy alternating-colour run at a column bottom).
2. Tap the head card of a valid run.
- **Expected:** the entire run relocates to its best legal target as a group (per
  Controls text "Tapping a card in a run moves the whole run"). Buried non-head
  cards must NOT lift.

**TC-2.3 (Both) — Drag-to-place onto a specific target.**
1. Cold launch. Press an exposed/movable card and drag it (finger travel > 8 pt)
   onto a specific column / free cell / foundation, release over that target.
- **Expected:** card follows the finger IMMEDIATELY (minimumDistance:0 — no
  press-and-hold delay) and drops exactly where released if legal; if released over
  no/illegal zone it snaps back with no move counted.
- **Effort bar:** pickup is instant; drop lands where released.

**TC-2.4 (Both) — Drag an unmovable/buried card.**
1. Cold launch. Attempt to drag a buried card (not a run head).
- **Expected:** buried card does not lift (canDrag=false for non-seq-heads); a tap on
  it is still accepted as a smart-move attempt. Verify no visual "stuck at elevated
  zIndex" artifact remains after release.

**TC-2.5 (Both) — Tap that briefly shows no visible response (latency probe).**
1. Cold launch. Timestamp-screenshot immediately before and ~1 s after a smart-move
   tap.
- **Expected:** animation begins within ~0.18 s; a >1 s visible no-response with no
  motion is a (heuristic) finding.

---

## WF-3 — New game / Replay / Undo (Both)

**TC-3.1 (Both) — New game is one tap and reshuffles.**
1. Cold launch, note current Deal #. Tap `New game`.
- **Expected:** one tap; a new random seed loads (Deal # changes), Moves=0, clock
  resets, board reshuffles.

**TC-3.2 (Both) — Replay restarts the SAME deal.**
1. Cold launch. Make 2–3 moves. Tap `Replay`.
- **Expected:** one tap; same Deal # reloads from the start, Moves back to 0, board
  identical to the deal's initial layout.

**TC-3.3 (Both) — Undo reverses the last move and is one tap.**
1. Cold launch. Make one move (Moves=1, Undo enabled). Tap `Undo`.
- **Expected:** one tap; last move reverses, Moves back to 0, board restored.
  CONFIRMED: Undo greys out (disabled + ~40% opacity) at Moves=0.

**TC-3.4 (Both) — Empty Undo (edge).**
1. Cold launch (Moves=0, no history). Attempt to tap `Undo`.
- **Expected:** `Undo` is visibly disabled (dimmed) and does nothing; clearly
  communicates "nothing to undo." Effort bar: disabled state must be obvious.

**TC-3.5 (Power) — Undo depth.**
1. Cold launch. Make 5 moves. Tap `Undo` 5 times.
- **Expected:** each tap reverses one move back to the initial board; the 6th would
  be disabled. No corruption / no over-undo.

---

## WF-4 — Finish a deal & see the win (Power)

**TC-4.1 (Power) — Auto-finish "Ask" prompts, then completes to the win overlay.**
1. Cold launch. Ensure `Auto-finish: Ask`. Drive the deal (or use a known-solvable
   seed) to a fully unblocked state where every card can cascade home.
- **Expected:** an alert "Ready to finish / Every remaining card can go home. Send
  them all now?" with `Finish` / `Not yet`. `Finish` runs the cascade; the win
  overlay shows "You solved it! 🎉", "Deal #S · N moves · M:SS", and `Play deal
  #<next>` / `Random` / `Close`.

**TC-4.2 (Power) — "Not yet" defers, then the Finish pill.**
1. Reach finishable state (as TC-4.1). Tap `Not yet`.
- **Expected:** prompt dismisses and does NOT nag again this game; a gold `Finish`
  pill is available in the toolbar (canOfferFinish) to complete manually later.

**TC-4.3 (Power) — Win overlay is dismissible and routes onward.**
1. From the win overlay: (a) tap `Close` → returns to solved board; relaunch to
   check state; (b) re-reach a win, tap `Play deal #<next>` → next seed loads;
   (c) tap `Random` → a random deal loads.
- **Expected:** each button behaves per label; Won counter increments on a genuine
  win; the just-won seed shows a `✓` on its `Deal #` pill.

**TC-4.4 (Power) — Manual finish with Auto-finish: Off.**
1. Set `Auto-finish: Off`. Reach a finishable board.
- **Expected:** no auto prompt; the `Finish` pill (or manual play) completes it.

---

## WF-5 — Daily Challenge: read objectives, play, read stats (Both)

**TC-5.1 (Both) — Open Daily and read objectives + streaks.**
1. Cold launch. Tap `Daily`.
- **Expected:** sheet titled "Daily Challenges"; 4 streak cards each showing
  current / "N total" / "best N" (all 0 on fresh install); Today card = Deal
  #10,003 with legible Bronze/Silver/Gold objective text and checkmark circles.
- **Effort bar:** streak vs total vs best must be distinguishable; objectives legible
  without truncation.

**TC-5.2 (Both) — Play hands off to the board with the live HUD.**
1. In Daily, tap `Play`.
- **Expected:** sheet dismisses; board shows the daily seed (#10,003) with the
  DailyHUD capsule (🥉 Clear / 🥈 <silver label> / 🥇 <gold label>, each ·/✓/✗).
  One tap from the card to playing.

**TC-5.3 (Both) — Replay-to-improve label after a bronze.**
1. Win the daily once (bronze earned). Re-open `Daily`.
- **Expected:** the Play button now reads "Replay to improve ↻" (grey, not gold);
  streak/total/best update; Today card checkmarks reflect earned tiers.

**TC-5.4 (Both) — Inspect a past/other day via calendar.**
1. In Daily, tap day `12` then `13` in the calendar.
- **Expected:** the day card updates to that day's deal + objectives; today (14) is
  gold-outlined; locked future days (15+) are dimmed and NOT tappable.
- **Edge:** tapping a locked future day does nothing (avail=false).

---

## WF-6 — "Show me how to win" demo (Novice)

**TC-6.1 (Novice) — Discover and start the Clear demo.**
1. Cold launch. Tap `Daily`. Under "Show me how to win:" tap `🥉 Clear`.
- **Expected:** sheet dismisses to the board; a demo status bar appears ("Winning
  line — 0 / N") and it opens PAUSED/ready (does NOT auto-run). Controls: `Next`,
  `Start`, `Stop`.

**TC-6.2 (Novice) — Step and run the demo.**
1. From TC-6.1, tap `Next` a few times (each advances one move), then tap `Start`
   (auto-advances; label becomes `Pause`), then `Pause` (label → `Resume`).
- **Expected:** progress counter increments clearly; input to the board is locked
  while demoing; nothing is scored.

**TC-6.3 (Novice) — Stop returns control cleanly.**
1. From a running/paused demo, tap `Stop`.
- **Expected:** demo bar clears (or shows a `Done` end-state that dismisses), board
  input unlocks, no lingering demo state; the board is back to a playable deal.

**TC-6.4 (Novice) — Silver / Gold demos.**
1. In Daily, tap `🥈 Silver` then (fresh) `🥇 Gold`.
- **Expected:** the demo bar headline names the tier + its objective label; only
  offered when a certified line exists (hasSilverLine / hasGoldLine).

---

## WF-7 — Play a specific deal number (Power)

**TC-7.1 (Power) — Open, type, play an exact deal.**
1. Cold launch. Tap `Deal #<seed>` pill. Clear the field, type `10003`, tap `Play`.
- **Expected:** ≤3 taps to open→type→play (open pill, edit, Play). The named deal
  loads (Deal # updates), Moves=0.

**TC-7.2 (Power) — Random from the deal alert.**
1. Open the Deal alert. Tap `Random`.
- **Expected:** a random deal loads; Deal # changes.

**TC-7.3 (Power) — Blank input (edge).**
1. Open the Deal alert. Delete all digits (empty field). Tap `Play`.
- **Expected:** no crash; `Int("")` is nil so nothing loads / alert dismisses with
  the current deal intact. (Note: the alert `Play` is always tappable — confirm it
  degrades gracefully, unlike the Wins field which disables Play.)

**TC-7.4 (Power) — Out-of-range input (edge).**
1. Open the Deal alert. Type `9999999` (> 1,000,000). Tap `Play`.
- **Expected:** no crash; deal(seed:) clamps to 1…1,000,000 (max 1,000,000). Verify
  the loaded Deal # is the clamped value, not the typed one.
2. Repeat with `0` → clamps up to 1.
- **Edge:** confirm whether the displayed pill matches the clamped seed (a mismatch
  between typed and loaded value with no feedback is a candidate finding).

**TC-7.5 (Power) — Cancel leaves state untouched.**
1. Open the Deal alert (prefilled with current seed). Tap `Cancel`.
- **Expected:** alert dismisses, same deal, no move counted. CONFIRMED reachable.

---

## WF-8 — Auto-play & Auto-finish settings (Power)

**TC-8.1 (Power) — Toggle Auto-play On/Off, label reflects state.**
1. Cold launch (default `Auto-play: On`). Tap the pill.
- **Expected:** label flips to `Auto-play: Off` immediately; tap again → `On`. The
  setting persists across relaunch (UserDefaults).

**TC-8.2 (Power) — Auto-play only makes SAFE moves.**
1. With `Auto-play: On`, make a move that exposes a trivially-safe card.
- **Expected:** only safe cards auto-advance home; it must not bury or make unsafe
  automatic moves. With `Off`, no automatic moves occur.

**TC-8.3 (Power) — Cycle Auto-finish Ask → On → Off.**
1. Tap `Auto-finish: Ask` → `On` → `Off` → back to `Ask`.
- **Expected:** label cycles in that exact order each tap; state persists across
  relaunch.

**TC-8.4 (Power) — Behavior matches label.**
1. `Ask`: reach finishable board → prompt appears (see TC-4.1).
2. `On`: reach finishable board → cascades automatically with no prompt.
3. `Off`: reach finishable board → no prompt, `Finish` pill offered.
- **Expected:** each mode behaves exactly as labeled.

---

## WF-9 — Review Wins (Both)

**TC-9.1 (Both) — Open Wins empty state.**
1. Cold launch. Tap `Wins`.
- **Expected:** "Deals won" sheet; "Play a deal" field with `Play` disabled while
  empty; "No wins yet — go solve one!". `Done` dismisses. CONFIRMED.

**TC-9.2 (Both) — Wins populated: ranges + drill-in.**
1. Win at least one deal, then open `Wins`.
- **Expected:** "N deals solved · M ranges"; range chip(s) (compressed); current
  seed's chip is gold-outlined. Tap a chip → list of deals with "X moves · M:SS ·
  <date>". Tap a row → loads that deal and dismisses. Back nav is obvious.

**TC-9.3 (Both) — Play a deal from the Wins field.**
1. In Wins, type a number, tap `Play`.
- **Expected:** loads that deal (clamped 1…1,000,000), dismisses. `Play` stays
  disabled for empty/<1 input.
- **Effort bar:** clear "way back" (Done / row-tap dismiss) — legibility per doc.

---

## WF-10 — How to play / About (Novice)

**TC-10.1 (Novice) — Find the rules.**
1. Cold launch. Tap `How to play`.
- **Expected:** sections Goal (52 cards, dual up/down foundations meeting in the
  middle), The catch, Tableau (alternating colours, either direction, no reversing),
  Free cells (3 spots), Controls (tap=smart-move, run moves together, drag=specific).
  CONFIRMED both-ends foundations + controls explained.

**TC-10.2 (Novice) — Find About / version / copyright.**
1. In How to play, scroll to the bottom.
- **Expected:** "About", "Causeway · v1.0 (1)", "© 2026 Whimsical Distractions. All
  rights reserved.", tagline. CONFIRMED.

**TC-10.3 (Novice) — Dismiss.**
1. Tap `Done`.
- **Expected:** obvious single dismiss back to the board. CONFIRMED.

---

## WF-11 — Back up & restore stats: Export / Import (Power)

**TC-11.1 (Power) — Export produces a dated JSON.**
1. Cold launch. Tap `Daily`. Scroll to BACKUP. Tap `Export`.
- **Expected:** the system file-exporter sheet appears with a suggested filename
  `Causeway-Stats-YYYY-MM-DD` (e.g. Causeway-Stats-2026-08-14) as `.json`. On save,
  the note reads "Stats exported."; on cancel "Export cancelled or failed."

**TC-11.2 (Power) — Import merges and reports.**
1. In BACKUP tap `Import`. Pick a previously exported Causeway backup `.json`.
- **Expected:** the note reports "Imported — merged X days (Y new) and Z deals (W
  new)." and merges (never erases). Verify streak/win counts only grow.

**TC-11.3 (Power) — Import a NON-backup file (edge).**
1. Tap `Import`. Pick any non-Causeway `.json` (or a `.json` that isn't a valid
   StatsBackup).
- **Expected:** rejected with "That file isn't a Causeway stats backup." No stats
  changed, no crash.

**TC-11.4 (Power) — Import a hand-edited / out-of-range backup (edge).**
1. Import a backup whose entries include out-of-range day keys, seeds
   >1,000,000/<1, or non-positive moves/times.
- **Expected:** invalid entries are sanitized/skipped; note appends "Skipped N
  invalid entr(y/ies)." Best scores are not poisoned by zero/negative values.

**TC-11.5 (Power) — Cancel the importer.**
1. Tap `Import`, then cancel the Files sheet.
- **Expected:** note reads "Import cancelled."; no change.

---

## WF-12 — Landscape play (Both) — assessed from layout code + harness shots

Not driven by live rotation in this env. Verify against ContentView landscape
branch (`geo.size.width > geo.size.height`) and any harness screenshot.

**TC-12.1 (Both) — Layout reflow (static review).**
- **Expected:** controls move into a narrow LEFT rail (fixed 118 pt wide,
  vertically scrollable — `ScrollView(.vertical)` bounded by landscapeBoardH), then
  a middle column of foundations (up+down rows) with free cells directly beneath,
  then the tableau filling remaining width (12 card-widths across). The header stays;
  the portrait toolbar is hidden in landscape.

**TC-12.2 (Both) — All controls remain reachable.**
- **Expected:** on short/notched phones or when the HUD/demo bar shows
  (landscapeHudBar=50), the rail scrolls (indicator shown) so the bottom controls
  (`Wins`, `How to play`, and conditionally `Daily`/`Finish`) never clip. Confirm
  rail height math keeps the last pill above the home-indicator zone.

**TC-12.3 (Both) — Card size & dragging.**
- **Expected:** cardW = min(width-constrained, height-constrained), ≥30 pt; cards
  sized to the current tallest column (min reserve 8) so a fresh deal nearly fills
  height. Tableau/foundations never scroll (would fight the minimumDistance:0 drag);
  dragging still works (drop-zone hit-testing is in the shared "board" coordinate
  space, orientation-independent). Flag if cardW floors to 30 (cramped) on the
  target device.

---

## Cross-cutting probes

- **P-A (sheet dismissal):** every sheet (Daily, Wins, How to play) dismisses via its
  `Done` button; the Deal / finish prompts dismiss via Cancel/Not yet. Confirm none
  trap the user. Also test swipe-down-to-dismiss on each sheet.
- **P-B (win overlay only on genuine win):** overlay appears solely when game.won;
  Close/Play-next/Random all exit it.
- **P-C (persistence):** make moves, background+relaunch (scenePhase → persist) — the
  in-progress board, seed, elapsed, and settings restore.
- **P-D (idle CPU / memory):** sit idle on the board and during the demo auto-run;
  read samples.jsonl — sustained CPU >~20% idle → drain proxy; resident memory
  climbing monotonically over a repeated New game / Undo loop (≥10x) → suspected leak.
- **P-E (latency):** timestamp screenshots around New game, Play (daily), and finish
  cascade; >1 s visible stall with no indicator → heuristic finding.
