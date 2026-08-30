# Causeway — QA Test Cases (EXPLORATION output)

Derived by driving the booted simulator (portrait, 402x874 pt tap space) and
reading the SwiftUI/model source. These are replayable scripts; each round the app
is reinstalled fresh (no prior stats/wins).

**Derive "today" at test time — never hard-code a daily deal number or objective
label.** `dayIndex = daysSince(2026-08-12)` from the *device's* local date; the
challenge deal is `data/daily-pool.json.seeds[dayIndex].seed`; Silver/Gold come
from the frozen per-day RNG (Mulberry32 seeded `0x9e3779b9 ^ (dayIndex + 1)`,
silver pool `["moves","no-undo"]` + the seed's certified silver ids, gold pool =
the seed's supported GOLD ids, `moves` param = `round(par * 1.2)`), and the "show
me how to win" pills follow `data/daily-solutions.json.solutions["<seed>"]` (a
Silver pill appears only when a distinct `silver` line exists — for the whole
current pool head there is none, so expect **Clear + Gold only**). A ready-made
deriver is checked in at `.qa-loop/tools/derive_daily.py`
(`python3 derive_daily.py [dayIndex]`); it was verified against the live screen
for dayIndex 0, 3 and 4.

**Midnight hazard (observed, not a bug):** the app recomputes `todayIndex()` on
every render, so a session that crosses local midnight sees the Daily card, its
objectives, the demo lines and the calendar highlight flip **live, with no
relaunch** — seen 2026-08-15 23:59 → 2026-08-16 00:00 (Deal #10,004 → #10,005).
If a case flips mid-run, say so in the result instead of filing it.

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
  each: current big number, "N total", "best N"); the selected day's card — headed
  **Today** for `todayIndex()`, else "<Mon D>" — with `Deal #<derived seed>` (grouped
  digits) and Bronze "Clear the deal" / Silver / Gold rows carrying the DERIVED
  objective labels and a checkmark circle each; a gold `Play` button ("Replay to
  improve ↻" once bronze is banked, "Unlocks <Mon D>" for a future day); a "Show me
  how to win:" row of pills (`🥉 Clear`, plus `🥈 Silver` / `🥇 Gold` only when
  `daily-solutions.json` holds that tier's line — currently Clear + Gold), shown only
  for days ≤ today; the month calendar (days in the pool up to today are tappable,
  today is gold-outlined, the selected day gets a tint, later days are dimmed and
  inert); BACKUP section with `Export` / `Import` and a note. `Done` (top-right)
  dismisses. **Derive every number/label here at test time** — see the header.
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

**TC-1.1 [novice] [smoke] (Novice) — Discover objective + controls, make one legal move.**
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

**TC-1.2 [novice] (Novice) — Tap a card with NO legal foundation/tableau home.**
1. Cold launch. Tap an exposed card whose only home is a free cell (e.g. a bottom
   card with no matching foundation step and no alternating-colour neighbour).
- **Expected:** smart-move parks it in a free cell (last-resort) rather than doing
  nothing silently, OR clearly does nothing if truly unmovable. Record whether the
  novice can tell WHY nothing "useful" happened (potential discoverability finding).

---

## WF-2 — Core moves: tap-to-smart-move and drag-to-place (Both)

**TC-2.1 [novice] [power] [smoke] (Both) — Tap smart-move sends the obvious card home.**
1. Cold launch. Identify an exposed card that belongs on a foundation.
2. Single-tap it.
- **Expected:** card moves to the correct foundation (up pile for A→, down pile for
  K→), no mis-target; one tap; Moves +1. CONFIRMED live: tapping bottom K♠ sent it
  to the spades down-foundation.
- **Effort bar:** exactly 1 tap, no press-and-hold, no confirmation.

**TC-2.2 [novice] [power] (Both) — Tap a run head moves the whole run.**
1. Cold launch (or set up a tidy alternating-colour run at a column bottom).
2. Tap the head card of a valid run.
- **Expected:** the entire run relocates to its best legal target as a group (per
  Controls text "Tapping a card in a run moves the whole run"). Buried non-head
  cards must NOT lift.

**TC-2.3 [novice] [power] (Both) — Drag-to-place onto a specific target.**
1. Cold launch. Press an exposed/movable card and drag it (finger travel > 8 pt)
   onto a specific column / free cell / foundation, release over that target.
- **Expected:** card follows the finger IMMEDIATELY (minimumDistance:0 — no
  press-and-hold delay) and drops exactly where released if legal; if released over
  no/illegal zone it snaps back with no move counted.
- **Effort bar:** pickup is instant; drop lands where released.
- **Note (contract INVERTED 2026-08-16, build 5447237 — supersedes the old "a release
  below the column's last card snaps back" expectation that `ux/WF-2:drop-below-column-refused`
  argued was itself the defect):** every column's drop frame now extends from the column
  top down to the **bottom of the tableau area**, so a legal run released anywhere in the
  empty strip below a column must land ON that column. Regression check for that finding:
  on deal #10,004, `drag 322 613 → 28 700` (20 pt below column 0's last card, whose bottom
  edge is 680.3) and `drag 322 613 → 28 800` (120 pt below) must BOTH move 10♥ onto J♣
  (Moves +1, card.H10 lands at x=6). A release at y≈860 is past the tableau area (the last
  card's bottom edge is ≈836 pt) and correctly still snaps back — that is out-of-board, not
  a refusal. Repeated legal drops onto one column is also the practical way to build a tall
  column — see TC-2.6.

**TC-2.4 [novice] [power] (Both) — Drag/tap an unmovable/buried card (refusal cue).**
1. Cold launch. Attempt to drag a buried card (not a run head); then plain-tap it.
- **Expected:** buried card does not lift (canDrag=false for non-seq-heads) and no move
  is counted; no "stuck at elevated zIndex" artifact after release. **Added 2026-08-16
  (build 5447237, fix for `ux/WF-2:unmovable-card-no-feedback`):** the touch must be
  ACKNOWLEDGED with a ~0.3 s horizontal wiggle (±4 pt) of that one card, so silence is
  never mistaken for a dropped touch. Deliberate non-goals to check for over-cueing: a
  tap on a card that CAN be lifted but has no legal target stays silent (verified on a
  free-cell card with no target), and the cue is suppressed while a demo line plays.
- **How to see a 0.3 s animation:** XCUITest's `tap()` returns only after the app goes
  idle, so a scripted `shot` right after the tap always misses it. Tap the buried card
  6–8× with ~1 s gaps while a host screenshot loop films
  (`xcrun simctl io <udid> screenshot`, ~4 fps), then `imgdiff` every frame against a rest
  frame over that card's rect. Measured on deal #10,004, A♥ at column 0 index 2 (tap
  28 500): 3 of 8 taps caught a displaced frame at MAD 32–44 / 32–40 % pixels changed;
  the same 8-tap loop on a movable-but-targetless free-cell card gave MAD 0.000 in 93
  consecutive frames.

**TC-2.5 [novice] [power] [perf] (Both) — Tap that briefly shows no visible response (latency probe).**
1. Cold launch. Timestamp-screenshot immediately before and ~1 s after a smart-move
   tap.
- **Expected:** animation begins within ~0.18 s; a >1 s visible no-response with no
  motion is a (heuristic) finding.

**TC-2.6 [novice] [power] (Both) — Portrait tall column: the column's fan compresses, then the whole
board shrinks ONCE.** *(Rewritten 2026-08-16. Supersedes the old "clipping at
13–15 cards" expectation that the round-2 ledger filed under TC-2.3 as
`bug/Main:portrait-tall-column-clipped-offscreen` — this case is that finding's
regression test.)*
1. Cold launch. Tap `Deal #…`, enter the **current day's daily deal number**
   (derive it — see the header), tap `Play`. Portrait, no daily HUD.
2. Grow ONE column (col 0) as far as legality allows. Verified drag sequence for
   deal **#10,004** on iPhone 17 Pro (device pt; 0-based column centres
   x = 28, 77, 126, 175, 224, 272, 321, 370; free cell 1 at (274,296); the bottom
   card of an N-card column is centred at y = 462 + 30·(N−1)):
   1. `drag 321 612 → 28 600` (10♥ c6→c0, col0 = 8)
   2. `drag 370 612 → 274 296` (4♥ c7→free cell 1)
   3. `drag 370 582 → 28 600` (9♠ c7→c0, 9)
   4. `drag 321 582 → 77 600` (J♦ c6→c1)
   5. `drag 321 552 → 370 560` (Q♥ c6→c7 onto K♣)
   6. `drag 321 522 → 28 600` (8♥ c6→c0, 10)
   7. `drag 272 612 → 28 600` (7♣ c5→c0, 11)
   8. `drag 126 642 → 28 600` (6♥ c2→c0, 12)
   9. `drag 175 642 → 321 470` (8♠ c3→c6 onto 9♥)
   10. `drag 175 612 → 28 600` (5♠ c3→c0, **13**)
   11. `drag 274 296 → 28 600` (4♥ cell→c0, 14)
   12. `drag 175 582 → 28 600` (3♣ c3→c0, 15)
   13. `drag 126 612 → 28 600` (2♦ c2→c0, **16**)
   Screenshot after each add; compare that column's fan pitch with a neighbour's,
   and the card width of the FOUNDATIONS / FREE CELLS rows.
3. On the shrunken board, tap the **bottom** card of the tall column (after the
   shrink col 0 is centred at x ≈ 36 and its bottom card at y ≈ 800), then tap
   `Undo`.
- **Expected (all four legs):**
  a. **Never clipped.** At every count the bottom card is fully on screen, above the
     home-indicator zone, and still hit-testable. A card cut by the screen edge, or
     one that swallows a tap, is a blocker-grade bug.
  b. **Fan compression first.** The tall column compresses only ITS OWN fan; every
     other column keeps the normal pitch and the card SIZE does not change. Measured:
     pitch 30 pt at ≤12 cards → 28 pt at 13 → 24 pt at 15, card width 45 pt
     throughout.
  c. **One uniform board shrink at the legibility floor.** When that column's fan
     would drop below the legibility floor, the WHOLE board switches to one smaller
     shared card size — foundations, free cells and tableau together, never two card
     sizes on screen at once — and the narrower tableau re-centres. Measured on
     iPhone 17 Pro portrait: fires on the **16th** card (45 pt → ~44 pt).
  d. **Monotone within the deal.** Shortening the column again must NOT grow the
     board back. Verified: tapping the 16-card column's bottom card parked it in a
     free cell (Moves +1) and the board stayed small; `Undo` restored 16 cards, still
     small. Only a new deal / `Replay` / `New game` restores full size.
- **Threshold is device- and chrome-dependent — derive it, don't hard-code 16.** The
  shrink starts at the smallest N where
  `floor((boardH − 32) / (3·1.6727 + 0.53·(N−1))) < portraitCardW`, with
  `portraitCardW = floor((screenW − 12 − 28) / 8)` and `boardH` = the height of the
  foundations+tableau area (≈612 pt here). A taller phone shrinks later; the daily
  HUD or the demo bar steals height, so it shrinks **earlier** on a challenge board.
- **Effort bar / evidence:** `wf2-tall-13cards-fan-compressed.png`,
  `wf2-tall-15cards-no-shrink-yet.png`, `wf2-tall-16cards-uniform-board-shrink.png`,
  `wf2-tall-bottom-card-tappable-no-regrow.png` (round-0 exploration).

---

## WF-3 — New game / Replay / Undo (Both)

**TC-3.1 [novice] [power] [smoke] (Both) — New game is one tap and reshuffles.**
1. Cold launch, note current Deal #. Tap `New game`.
- **Expected:** one tap; a new random seed loads (Deal # changes), Moves=0, clock
  resets, board reshuffles.

**TC-3.2 [novice] [power] (Both) — Replay restarts the SAME deal.**
1. Cold launch. Make 2–3 moves. Tap `Replay`.
- **Expected:** one tap; same Deal # reloads from the start, Moves back to 0, board
  identical to the deal's initial layout.

**TC-3.3 [novice] [power] (Both) — Undo reverses the last move and is one tap.**
1. Cold launch. Make one move (Moves=1, Undo enabled). Tap `Undo`.
- **Expected:** one tap; last move reverses, Moves back to 0, board restored.
  CONFIRMED: Undo greys out (disabled + ~40% opacity) at Moves=0.

**TC-3.4 [novice] [power] (Both) — Empty Undo (edge).**
1. Cold launch (Moves=0, no history). Attempt to tap `Undo`.
- **Expected:** `Undo` is visibly disabled (dimmed) and does nothing; clearly
  communicates "nothing to undo." Effort bar: disabled state must be obvious.

**TC-3.5 [power] (Power) — Undo depth.**
1. Cold launch. Make 5 moves. Tap `Undo` 5 times.
- **Expected:** each tap reverses one move back to the initial board; the 6th would
  be disabled. No corruption / no over-undo.

---

## WF-4 — Finish a deal & see the win (Power)

**TC-4.1 [power] (Power) — Auto-finish "Ask" prompts, then completes to the win overlay.**
1. Cold launch. Ensure `Auto-finish: Ask`. Drive the deal (or use a known-solvable
   seed) to a fully unblocked state where every card can cascade home.
- **Expected:** an alert "Ready to finish / Every remaining card can go home. Send
  them all now?" with `Finish` / `Not yet`. `Finish` runs the cascade; the win
  overlay shows "You solved it! 🎉", "Deal #S · N moves · M:SS", and `Play deal
  #<next>` / `Random` / `Close`.

**TC-4.2 [power] (Power) — "Not yet" defers, then the Finish pill.**
1. Reach finishable state (as TC-4.1). Tap `Not yet`.
- **Expected:** prompt dismisses and does NOT nag again this game; a gold `Finish`
  pill is available in the toolbar (canOfferFinish) to complete manually later.

**TC-4.3 [power] (Power) — Win overlay is dismissible and routes onward.**
1. From the win overlay: (a) tap `Close` → returns to solved board; relaunch to
   check state; (b) re-reach a win, tap `Play deal #<next>` → next seed loads;
   (c) tap `Random` → a random deal loads.
- **Expected:** each button behaves per label; Won counter increments on a genuine
  win; the just-won seed shows a `✓` on its `Deal #` pill.

**TC-4.4 [power] (Power) — Manual finish with Auto-finish: Off.**
1. Set `Auto-finish: Off`. Reach a finishable board.
- **Expected:** no auto prompt; the `Finish` pill (or manual play) completes it.

---

## WF-5 — Daily Challenge: read objectives, play, read stats (Both)

*All expectations below are DERIVED — run `derive_daily.py` (no argument = today)
before the case and compare its output to the screen. Do not paste a deal number
into an expectation.*

**TC-5.1 [novice] [power] [smoke] (Both) — Open Daily and read objectives + streaks.**
1. Derive today: `python3 .qa-loop/tools/derive_daily.py`.
2. Cold launch. Tap `Daily`.
- **Expected:** sheet titled "Daily Challenges"; four streak cards (Play / Silver /
  Gold / Flawless) each showing a big current number, "N total" and "best N" (all 0
  on a fresh install); the card is headed **"Today"** with `Deal #<derived seed>`
  (grouped, e.g. "Deal #10,005"); Bronze = "Clear the deal", Silver and Gold text
  **exactly** matching the derived labels, each with an empty checkmark circle; a
  gold `Play` button; a "Show me how to win:" row whose pills match the derived
  set (Clear + Gold for every day in the current pool head — a `Silver` pill must
  appear only if `daily-solutions.json` has a distinct `silver` line for that seed);
  then the month calendar and the BACKUP section. `Done` (top-right) dismisses.
- **Effort bar:** streak vs total vs best distinguishable at a glance; no objective
  text truncated on this card (it wraps to 2 lines when long — verified for
  "For every suit, send its King home before its Ace").

**TC-5.2 [novice] [power] (Both) — Play hands off to the board with the live HUD.**
1. In Daily, tap `Play`.
- **Expected:** one tap; sheet dismisses; the `Deal #` pill shows the derived daily
  seed; Moves 0, Time 0:00; a DailyHUD capsule replaces nothing else and sits under
  the toolbar showing three medal chips (🥉 Clear the deal · 🥈 <silver label> ·
  🥇 <gold label>), each with ·/✓/✗ state.
- **HUD layout (changed 2026-08-16, build 5447237):** the HUD is a `ViewThatFits` —
  landscape still renders all three chips on ONE line, and portrait (~402 pt), where
  one line cannot fit them untruncated, STACKS the three chips in a rounded box with
  fully wrapped labels. Expect NO "…" in either orientation; the portrait HUD is
  ~28 pt taller than the old capsule and the tableau starts at y≈498 (card i top
  y = 498 + 30·i) instead of 479. Any ellipsis in a HUD chip is a regression of
  `ux/WF-5:daily-hud-truncates-objectives`.

**TC-5.3 [novice] [power] (Both) — Replay-to-improve label after a bronze.**
1. Win the daily once (bronze earned). Re-open `Daily`.
- **Expected:** the Play button now reads "Replay to improve ↻" (grey, not gold);
  Play streak/total/best update from 0; the Today card's Bronze circle is checked and
  the Silver/Gold circles reflect what that attempt actually met.

**TC-5.4 [novice] [power] (Both) — Inspect a past / future day via the calendar.**
1. In Daily, scroll to the calendar. Tap an earlier day inside the pool (e.g. the
   12th, dayIndex 0).
2. Tap a day AFTER today (locked).
3. Tap today again.
- **Expected:** selecting a past day retitles the card from "Today" to "<Mon D>" and
  swaps in that day's derived deal + objectives (verified: Aug 12 → "Deal #10,001",
  Silver "Win in 100 moves or fewer", Gold "Send all four Aces home before any other
  card"); the selected day gets a filled tint while **today keeps the gold outline**;
  days after today are dimmed and inert (verified: tapping tomorrow changes nothing);
  tapping today restores the "Today" card.
- **Edge:** the daily is catch-up-friendly — `Play` on a past (unlocked) day calls
  `playChallenge(day)` and IS scored against that day (HUD present, `dayIndex <=
  today` guard in Game.swift). A future day shows "Unlocks <Mon D>" instead of a
  Play button and offers no "show me how to win" pills.

---

## WF-6 — "Show me how to win" demo (Novice)

*Rewritten 2026-08-16 for the NEW intended exit behavior (WORKFLOWS.md WF-6): both
mid-demo `Stop` and post-line `Done` re-deal the same seed to a FRESH board, the
board is fully input-locked while the demo bar is up (a card must not even lift
under a drag), and nothing a demo plays can ever be banked as a win/best-time or a
daily tier. These cases are the regression test for the round-2 finding
`bug/WF-6:demo-progress-counts-as-a-real-win`. Derive the day's seed and labels
first (see header).*

**TC-6.1 [novice] (Novice) — Discover and start the Clear demo; it opens paused/ready.**
1. Cold launch. Tap `Daily`. Under "Show me how to win:" tap `🥉 Clear`.
- **Expected:** the sheet dismisses to the board; the `Deal #` pill shows the derived
  daily seed; a dark demo bar sits where the HUD/toolbar gap is, reading
  `Winning line — 0 / <bronze line length>` (derive the length from
  `daily-solutions.json`; e.g. 97 for #10,004, 86 for #10,005) with pills
  `Next` (236,263) · `Start` (297,263) · `Stop` (357,263).
- **It must NOT auto-run:** the counter stays at `0 / N` and the pill says `Start`
  (not `Pause`) until the user acts. `Undo` disabled.
- **Header while the demo bar is up (changed 2026-08-16, build 5447237):** `Moves`
  and `Time` both read an em-dash `—` (the demo's move count is the app's, not the
  player's); `Won` keeps its real value. This holds for the whole demo — ready,
  running, paused and on the completion banner. A real number in Moves/Time while
  demoing is a regression of `ux/WF-6:demo-moves-counter-in-player-header`.

**TC-6.2 [novice] (Novice) — Step, run, pause, resume.**
1. From TC-6.1 tap `Next` three times.
2. Tap `Start`, wait ~3 s, then tap the same pill (now `Pause`).
- **Expected:** each `Next` advances the counter by exactly 1 (verified 0→3) and
  animates one move. `Start` auto-advances at ~0.25 s/move, hides `Next` and shows
  `Pause` + `Stop` only, and the headline gains a trailing "…". `Pause` restores
  `Next` / `Resume` / `Stop` and the headline reads `N / total (paused)` — which
  wraps to two lines and nudges the pills to y≈266 (re-read them from a screenshot).
  Moves/Time in the header are not the player's score and nothing is committed.

**TC-6.3 [novice] (Novice) — Mid-demo `Stop` re-deals the SAME seed to a fresh board.**
1. From a stepped or running demo (any progress > 0), tap `Stop`.
0. *(Precondition for the confirm gate below: reach the demo from a board with NO
   daily attempt in progress, or the "End your daily attempt?" alert fires first.)*
- **Expected:** the demo bar disappears; the board is the **fresh initial layout of
  the same deal** — every column back to its dealt 6–7 cards, free cells empty,
  foundations empty, `Moves 0`, `Time 0:00`, `Undo` disabled, `Deal #` unchanged.
  The assisted position must NOT survive (that was the round-2 bug: it let the
  player finish the app's own line and bank it as a win/best time).
- **Fail conditions:** any card still sitting where the demo left it; Moves > 0; a
  `Finish` pill offered; the win overlay appearing.

**TC-6.4 [novice] (Novice) — Run the line to the end, then `Done`.**
1. Start the Clear demo and tap `Start`; let it run to `N / N` (~25 s for a 97-move
   line; ~22 s for 86).
2. Read the bar, then tap `Done`.
- **Expected:** at the end the bar becomes a banner — "That's a **winning** line —
  tap Done to try it yourself." (Silver/Gold lines say "a Silver/Gold line") — with a
  single `Done` pill at (355,265); `Next`/`Start`/`Stop` are gone. `Done` re-deals
  the same seed to a fresh board exactly like `Stop`: Moves 0, full columns.
- **Nothing is banked:** `Won` stays 0, the win overlay never appears, `Wins` still
  reads "No wins yet — go solve one!", and the Daily card's tier circles and all four
  streak cards stay at 0. (Verified end-to-end on a fresh install with the 97-move
  #10,004 Clear line.)

**TC-6.5 [novice] (Novice) — Input is locked while the demo bar is up, including drag-LIFT.**
1. Start the Clear demo, tap `Next` a few times so the board is mid-line.
2. Attempt a normal drag on a movable-looking bottom card (e.g. press col 0's bottom
   card at (28,681) and drag it slowly, ~2.5 s, to another column).
3. Attempt a plain tap on an exposed card that would obviously smart-move.
- **Expected:** the card does not lift, tilt, or follow the finger at ALL — not just
  "the move is refused" (`canDrag = !demoing && isSeqHead`). The progress counter,
  Moves and the whole board must be unchanged. Verified with a host filmstrip across
  the 3.3 s drag: every frame byte-identical to the pre-drag frame (imgdiff MAD
  0.000), counter still `3 / 97`.
- **Fail:** any lift/ghost/zIndex artifact, any move applied, any counter change.

**TC-6.7 [novice] [power] (Both) — Demo request with a daily attempt in progress must CONFIRM.**
*(added 2026-08-16 for the fix to `ux/WF-6:demo-discards-daily-attempt-without-warning`)*
1. `Daily` → `Play`, then make ≥1 move on the board (HUD up, Moves > 0, Undo enabled).
2. `Daily` → tap any "Show me how to win" pill.
- **Expected:** an alert "End your daily attempt?" / "Watching a demo re-deals the
  board, so your current attempt (moves and time) will be discarded. You can replay
  the challenge afterwards." with `Keep playing` (cancel) and `Show demo`
  (destructive).
3. Tap `Keep playing`, dismiss the sheet with `Done`.
- **Expected:** the attempt is untouched — same Moves, the clock still running, Undo
  still enabled, foundations unchanged, objectives HUD still up.
4. Re-open `Daily`, tap the same pill, tap `Show demo`.
- **Expected:** the sheet dismisses, the demo bar opens at `0 / N`, the board is
  re-dealt and the attempt is gone (by design — there is deliberately no
  restore-after-demo; see the trap note on the finding).
- **Known gap (not covered by the gate):** the confirm only fires when
  `challengeDay != nil && moveCount > 0`. A CASUAL game in progress (free play, or
  the board left after a demo exit) is still re-dealt by a demo pill with no warning.

**TC-6.6 [novice] (Novice) — Silver / Gold demo lines.**
1. In Daily, tap the `🥇 Gold` pill (and `🥈 Silver` on any day whose seed has a
   distinct silver line — derive; there is none in the current pool head).
2. Tap `Next` once, then `Stop`.
- **Expected:** the bar headline names the tier AND its derived objective label —
  e.g. `🥇 Gold: Win without ever using a free cell — 0 / 109` — with the same
  Next/Start/Stop pills; the total matches that tier's line length in
  `daily-solutions.json` (gold 109 for #10,004). `Stop` re-deals as in TC-6.3.
- **Discoverability:** the pill row appears only for `dayIndex <= today` and only
  when a baked line exists; a day with no solution shows no "Show me how to win" row
  at all.

---

## WF-7 — Play a specific deal number (Power)

**TC-7.1 [power] [smoke] (Power) — Open, type, play an exact deal.**
1. Cold launch. Tap `Deal #<seed>` pill. Clear the field, type `10003`, tap `Play`.
- **Expected:** ≤3 taps to open→type→play (open pill, edit, Play) — chrome taps only;
  the number pad costs one tap per digit and one backspace per pre-filled digit, which
  round 1 accepted as within the bar. The named deal loads (Deal # updates), Moves=0.
  Verified on build 5447237: 6 backspaces + `10003` + Play → Deal #10003, Moves 0.

**TC-7.2 [power] (Power) — The deal alert has exactly two actions (contract CHANGED 2026-08-16,
build 5447237).** *(Supersedes the old "Random from the deal alert" case: the `Random`
action was removed as the portrait side of the fix for
`ux/WF-12:deal-alert-actions-hidden-in-landscape`, where landscape's auto-raised number
pad pushed Random/Cancel off the visible alert and left destructive `Play` as the only
visible exit. WORKFLOWS.md's WF-7 line still mentions "(and the Random option)" — that
sentence is now stale.)*
1. Open the Deal alert. Enumerate its actions.
- **Expected:** exactly `Cancel` (left) and `Play` (right), side by side, with the number
  pad already up and the field pre-filled + focused. **No `Random` action** — a driver
  `tapb Random` must report a miss.
2. Dismiss the alert and tap the toolbar `New game` pill.
- **Expected:** the random-deal capability the alert used to offer is still one tap away
  and always visible (`New game` calls the same `newRandomGame()`); Deal # changes.
- **Portrait action coordinates on iPhone 17 Pro (pt):** Cancel (127,391), Play (275,391)
  — NOT the (200,335)/(200,391)/(200,447) three-action stack from earlier rounds.

**TC-7.3 [power] (Power) — Blank input (edge).**
1. Open the Deal alert. Delete all digits (empty field). Tap `Play`.
- **Expected:** no crash; the deal is left intact. Since round 1 the alert's `Play`
  is DISABLED on an empty/out-of-range field (matching the Wins field), so there is
  nothing to tap.

**TC-7.4 [power] (Power) — Out-of-range input (edge).**
- **REWRITTEN after bug/WF-7 (round 1).** The old expectation ("`9999999` → Deal
  #1000000, verified on build 5447237") is stale: `Game.maxSeed` (1,000,000) is only
  the RANDOM-deal ceiling, while `Game.deal` legitimately accepts up to
  `maxValidSeed` = 4,294,967,295 because the daily/sandbox pools use seeds above
  10,000,000. The alert now ADVERTISES and ENFORCES the real range instead of
  silently clamping to a different deal.
1. Open the Deal alert. Type `9999999`. Tap `Play`.
- **Expected:** `Play` is enabled and Deal #9999999 loads — it is inside the
  advertised range (1–4,294,967,295).
2. Type `5000000000` (or any value above 4,294,967,295, or a run of 20 digits).
- **Expected:** `Play` is DISABLED (greyed) while the field is out of range — the
  app never loads a deal different from the one typed. Cancel leaves the deal intact.
3. Type `0` → `Play` is disabled (below the range). Blank → `Play` disabled.
- **Edge:** the pill must always show exactly the number that was typed.

**TC-7.5 [power] (Power) — Cancel leaves state untouched.**
1. Open the Deal alert (prefilled with current seed). Tap `Cancel`.
- **Expected:** alert dismisses, same deal, no move counted. CONFIRMED reachable.
  Since 2026-08-16 `Cancel` is the LEFT of the alert's two actions (127,391).

---

## WF-8 — Auto-play & Auto-finish settings (Power)

**TC-8.1 [power] (Power) — Toggle Auto-play On/Off, label reflects state.**
1. Cold launch (default `Auto-play: On`). Tap the pill.
- **Expected:** label flips to `Auto-play: Off` immediately; tap again → `On`. The
  setting persists across relaunch (UserDefaults).

**TC-8.2 [power] (Power) — Auto-play only makes SAFE moves.**
1. With `Auto-play: On`, make a move that exposes a trivially-safe card.
- **Expected:** only safe cards auto-advance home; it must not bury or make unsafe
  automatic moves. With `Off`, no automatic moves occur.

**TC-8.3 [power] (Power) — Cycle Auto-finish Ask → Off → On.**
*(order CHANGED 2026-08-16, build 5447237, for `ux/WF-8:autofinish-cycle-through-on-ends-game`:
`.on` is the one state whose mere selection ends a finishable game, so it must never
be a pass-through from the default.)*
1. Tap `Auto-finish: Ask` → `Off` → `On` → back to `Ask`.
- **Expected:** label cycles in that exact order, one tap each, updating immediately;
  the mode persists across `terminate` + `launch` (verified with `On`). Reaching
  `Off` from the default `Ask` must take exactly ONE tap and must never transit `On`.

**TC-8.4 [power] (Power) — Behavior matches label, on a real finishable board.**
*Fixture (deterministic, ~4 min): `Deal #` → `10169` → `Play`, then replay the first
28 tokens of that seed's bronze line as real drags. Regenerate the gesture list with
`node /private/tmp/qaw2r1wf8/gen2.mjs 10169 bronze 28` (portrait, no HUD, no demo bar:
column centres x = 28,77,126,175,224,272,321,370; card i grab y = 425+30i+14, +37 for
the last card; foundations x = 28,77,126,175 with up row y=296 / down row y=375; free
cells x = 274,323,372 at y=296). Auto-play may stay `On` — this line has no safe
autoplay before move 31. Verified 28/28 drags land, Moves = 28.*
1. `Ask` (default): the 28th drag makes the board finishable → the "Ready to finish"
   alert appears by itself ("Every remaining card can go home. Send them all now?"),
   `Not yet` / `Finish`.
2. Tap `Not yet` → the board stays playable, Moves unchanged, and the gold `Finish`
   pill appears in the toolbar (id `toolbar.finish`).
3. Tap the `Auto-finish` pill ONCE.
- **Expected (the regression guard):** the label becomes `Auto-finish: Off` — NOT
  `On` — and NOTHING happens to the board: Moves still 28, `Won` unchanged, no
  cascade, no win overlay, `Finish` pill still offered. (`Off` behaving as labeled
  and the one-tap Ask→Off route are the same assertion.)
4. Tap the `Auto-finish` pill again → `On`.
- **Expected:** landing on `On` deliberately DOES cascade immediately (the intended
  shortcut): all remaining cards fly home, `Moves` ends at 70, the win overlay reads
  "You solved it! · Deal #10,169 · 70 moves", `Won` +1, the `Deal #` pill gains ` ✓`.
- **Note:** the destructive transition still exists at `Off → On`; that is the
  deliberate shortcut, documented on `AutoFinishMode.next`.

---

## WF-9 — Review Wins (Both)

**TC-9.1 [novice] [power] (Both) — Open Wins empty state.**
1. Cold launch. Tap `Wins`.
- **Expected:** "Deals won" sheet; "Play a deal" field with `Play` disabled while
  empty; "No wins yet — go solve one!". `Done` dismisses. CONFIRMED.

**TC-9.2 [novice] [power] (Both) — Wins populated: ranges + drill-in.**
1. Win at least one deal, then open `Wins`.
- **Expected:** "N deals solved · M ranges"; range chip(s) (compressed); current
  seed's chip is gold-outlined. Tap a chip → list of deals with "X moves · M:SS ·
  <date>". Tap a row → loads that deal and dismisses. Back nav is obvious.

**TC-9.3 [novice] [power] (Both) — Play a deal from the Wins field.**
1. In Wins, type a number, tap `Play`.
- **Expected:** loads that deal (clamped 1…1,000,000), dismisses. `Play` stays
  disabled for empty/<1 input.
- **Effort bar:** clear "way back" (Done / row-tap dismiss) — legibility per doc.

---

## WF-10 — How to play / About (Novice)

**TC-10.1 [novice] [smoke] (Novice) — Find the rules.**
1. Cold launch. Tap `How to play`.
- **Expected:** sections Goal (52 cards, dual up/down foundations meeting in the
  middle), The catch, Tableau (alternating colours, either direction, no reversing),
  Free cells (3 spots), Controls (tap=smart-move, run moves together, drag=specific).
  CONFIRMED both-ends foundations + controls explained.

**TC-10.2 [novice] (Novice) — Find About / version / copyright.**
1. In How to play, scroll to the bottom.
- **Expected:** "About", "Causeway · v1.0 (1)", "© 2026 Whimsical Distractions. All
  rights reserved.", tagline. CONFIRMED.

**TC-10.3 [novice] (Novice) — Dismiss.**
1. Tap `Done`.
- **Expected:** obvious single dismiss back to the board. CONFIRMED.

---

## WF-11 — Back up & restore stats: Export / Import (Power)

**TC-11.1 [power] (Power) — Export produces a dated JSON.**
1. Cold launch. Tap `Daily`. Scroll to BACKUP. Tap `Export`.
- **Expected:** the system file-exporter sheet appears with a suggested filename
  `Causeway-Stats-YYYY-MM-DD` (e.g. Causeway-Stats-2026-08-14) as `.json`. On save,
  the note reads "Stats exported."; on cancel "Export cancelled or failed."

**TC-11.2 [power] (Power) — Import merges and reports.**
1. In BACKUP tap `Import`. Pick a previously exported Causeway backup `.json`.
- **Expected:** the note reports "Imported — merged X days (Y new) and Z deals (W
  new)." and merges (never erases). Verify streak/win counts only grow.

**TC-11.3 [power] (Power) — Import a NON-backup file (edge).**
1. Tap `Import`. Pick any non-Causeway `.json` (or a `.json` that isn't a valid
   StatsBackup).
- **Expected:** rejected with "That file isn't a Causeway stats backup." No stats
  changed, no crash.

**TC-11.4 [power] (Power) — Import a hand-edited / out-of-range backup (edge).**
1. Import a backup whose entries include out-of-range day keys, out-of-range
   seeds, or non-positive moves/times.
- **REWRITTEN after bug/WF-11 (round 1):** the sanitizer's bounds are now the range
  the app can actually PRODUCE, not a narrower convenience range. Valid (must be
  merged, not skipped): day keys `-7 … today+2` (day −1 … −7 are the pre-epoch
  playtest sandbox; `preSeeds.count` = 7) and win seeds `1 … 4,294,967,295`.
  Phantom probe values must therefore now be day `-8` / `9999` and seed `0` /
  `4294967296` — the old probes (day `-3`, seed `1000001`) are legitimate entries
  and are expected to merge.
- **Expected:** genuinely impossible entries are skipped; the note names what was
  dropped ("Skipped 1 day and 1 deal this app can't have produced."). Best scores
  are not poisoned by zero/negative values.
- **Regression to keep:** export→import of the app's OWN untouched backup must skip
  ZERO entries, including a sandbox-day record and a win on a seed > 1,000,000.

**TC-11.5 [power] (Power) — Cancel the importer.**
1. Tap `Import`, then cancel the Files sheet.
- **Expected:** note reads "Import cancelled."; no change.

---

## WF-12 — Landscape play (Both) — assessed from layout code + harness shots

Not driven by live rotation in this env. Verify against ContentView landscape
branch (`geo.size.width > geo.size.height`) and any harness screenshot.

**TC-12.1 [novice] [power] (Both) — Layout reflow (static review).**
- **Expected:** controls move into a narrow LEFT rail (fixed 118 pt wide,
  vertically scrollable — `ScrollView(.vertical)` bounded by landscapeBoardH), then
  a middle column of foundations (up+down rows) with free cells directly beneath,
  then the tableau filling remaining width (12 card-widths across). The header stays;
  the portrait toolbar is hidden in landscape.

**TC-12.2 [novice] [power] (Both) — All controls remain reachable.**
- **Expected:** on short/notched phones or when the HUD/demo bar shows
  (landscapeHudBar=50), the rail scrolls (indicator shown) so the bottom controls
  (`Wins`, `How to play`, and conditionally `Daily`/`Finish`) never clip. Confirm
  rail height math keeps the last pill above the home-indicator zone.

**TC-12.3 [novice] [power] (Both) — Card size & dragging.**
- **Expected:** cardW = min(width-constrained, height-constrained), ≥30 pt; cards
  sized to the current tallest column (min reserve 8) so a fresh deal nearly fills
  height. Tableau/foundations never scroll (would fight the minimumDistance:0 drag);
  dragging still works (drop-zone hit-testing is in the shared "board" coordinate
  space, orientation-independent). Flag if cardW floors to 30 (cramped) on the
  target device.

---

## WF-13 — Past days & the objective-family inventory (Both)

*(The six cases here were DELETED 2026-08-30: they tested the pre-epoch sandbox days
(Aug 5-11 2026, dayIndex -7…-1) and the objective families `split-even`, `down-heavy`,
`no-down-foundation`, `no-up-foundation`, `no-supermoves`, `one-big-move` — none of which
exist any more. The pool was rebuilt to schema v4 in f42c632; `dailyChallenge(-1, pool)`
now returns null. Round-0 exploration re-writes this section against playable PAST days
(dayIndex 0-28) and the thirteen current families.)*

*(Round-0 exploration, 2026-08-30, build f0680ef. All coordinates below are DEVICE POINTS
on an iPhone 17 Pro portrait (402x874) and were measured live this round — the old geometry
note in this file was for a different month layout and a different "today".)*

**Fixture / geometry for every case below (measured, reproducible):**
- `python3 .qa-loop/tools/derive_daily.py <YYYY-MM-DD|dayIndex>` prints the expected card
  (deal, par, Silver/Gold label + family id, the exact pill set, and the calendar cell
  coordinate). **The tool was rewritten this round** — the old one crashed with
  `KeyError: 'seeds'` on pool v4. It shells out to `tests/daily.mjs`, so its labels are the
  shipped strings; never hand-type an expectation.
- Toolbar (3 rows on a fresh install): `Daily` = **(290, 176)**, `Undo` = (142, 135),
  `New game` = (51, 135). These do NOT move when the daily HUD appears.
- Daily sheet: opens scrolled to the TOP and the month calendar is **entirely below the
  fold**. **One** swipe `(200,700) → (200,300)` pins it at the bottom of its scroll; from
  there the layout is identical for every day (verified across Today, Aug 1, 3, 4, 5, 6).
- **Calendar cell (bottom-scrolled), August 2026:** `x = 40 + 53.5·((D+5) mod 7)`,
  `y = 471 + 44·((D+5) div 7)`. So Aug 1 (361,471); Aug 2 (40,515), Aug 3 (94,515),
  Aug 4 (147,515), Aug 5 (201,515), Aug 6 (254,515), Aug 7 (307,515), Aug 8 (361,515);
  Aug 29 (361,647); Aug 30 = today (40,691); Aug 31 = future (94,691).
- **Day card (bottom-scrolled): `Play` = (200, 243)** for every day. Scroll back up with
  `(200,300) → (200,640)` to read the card header (date + `Deal #`), which is hidden behind
  the nav bar at the bottom scroll position.
- **Board with the 3-line stacked daily HUD: every board y is +88 pt** vs the no-HUD
  baseline in HARNESS_NOTES (measured, not the ~40/80 quoted there). Free cells
  (275,384)/(324,384)/(373,384); foundations up-row y=384, down-row y=462;
  tableau bottom-card tap y = `425 + 30·idx + 88 + 45`, x = 28/77/126/175/224/273/321/370.

**TC-13.1 [novice] [smoke] (Novice) — Find a past day in the calendar and read ITS OWN objectives.**
1. Cold launch (fresh install). Tap `Daily` (290,176).
2. Swipe `(200,700) → (200,300)` to bring the month calendar on-screen.
3. Tap **Aug 3** at (94,515).
4. Swipe `(200,300) → (200,640)` to scroll the card header back into view.
- **Expected (all strings exact; cross-check `derive_daily.py 2026-08-03`):** the card
  header reads **`Aug 3`** (not "Today") with **`Deal #539,885`** on the right; Bronze
  "Clear the deal"; Silver **"Never move more than 3 cards in a single move"**; Gold
  **"Finish one whole suit before any other suit is started"**; the ⏰ line reads
  **"Same-day is earned on the day itself"**; a gold **`Play`** button; "Show me how to
  win:" with a 2x2 grid of **🥉 Clear / 🥈 Silver / 🥇 Gold / 🌟 Flawless**.
  **Today's objectives must appear nowhere** — a card still showing "Get all four Kings
  home within your first 9 moves" / "Split every suit exactly at the Eight" or
  `Deal #551,879` is the headline bug this workflow exists to catch.
  The Aug 3 calendar cell is tinted gold-ish (selected); Aug 30 keeps its gold ring (today).
- **Effort bar (novice):** the only affordance for a past day is the calendar itself, and
  it is below the fold. Record whether the tester finds it without being told, and how many
  scroll/tap attempts it took.

**TC-13.2 [novice] (Novice) — A future day is inert, and today is distinguishable.**
1. Cold launch → `Daily` (290,176) → swipe `(200,700) → (200,300)`.
2. Tap **Aug 3** (94,515)  — the card now shows Aug 3 (see TC-13.1).
3. Tap **Aug 31** (94,691) — a future day (dayIndex 30 > today's 29).
- **Expected:** the tap is a no-op — the day card **still shows Aug 3 / Deal #539,885**,
  the Aug 3 cell stays selected and Aug 31 stays dim-grey with no selection tint.
  Aug 30 (today) is the only cell with a gold *ring*.
- **Watch for (novice reading):** the app gives NO feedback at all for the future-day tap —
  no toast, no "Unlocks Aug 31" text (that `playButton` branch only renders when
  `dayView > todayIndex`, which the calendar can never set). Judge whether a first-timer
  can tell "not yet" from "broken". See candidate concern CC-13-B.
- **Also check:** every cell Aug 1…Aug 30 IS selectable (spot-check Aug 1 at (361,471) →
  header `Aug 1`, `Deal #691,039`, Silver "Get all four Queens home within your first
  29 moves", Gold "Split every suit exactly at the Three — A-3 up, 4-K down").

**TC-13.3 [power] [smoke] (Power) — Play a past day; the board HUD carries THAT day's objectives.**
1. Cold launch. Tap `Daily` (290,176) → swipe `(200,700)→(200,300)` → tap **Aug 4**
   (147,515) → tap `Play` (200,243).
- **Expected:** the sheet dismisses; the `Deal #` pill reads **`Deal #625648`**;
  Moves 0, Time 0:00. The daily HUD is the 3-line stacked box directly under the toolbar
  and is **titled `Aug 4` in gold** (`hud.day`), then three bullets, **untruncated, no "…"**:
  `🥉 · Clear the deal` / `🥈 · Never let one suit get more than 4 cards ahead of another` /
  `🥇 · Win without ever using a free cell`. All three markers are the neutral `·`.
- **Effort bar:** 3 taps + 1 swipe from the board. WF-13 gives no explicit budget; flag if
  it exceeds this. Note the calendar is the ONLY route — there is no "yesterday" shortcut.
- **Then, still mid-attempt, tap `Daily` (290,176) again.** Expected/observed this round:
  the sheet **resets to the `Today` card** (Deal #551,879, today's objectives) with no mark
  anywhere saying the live attempt is Aug 4, and the visible `Play` button would start
  *today's* deal. Record what a power user has to do to get back to Aug 4 (swipe + tap day
  + tap Play, and Play *restarts* — it never resumes). See CC-13-D.

**TC-13.4 [power] [smoke] (Power) — A constraint violation is ALLOWED, shows instantly, and Undo rolls it back.**
*(Aug 4's Gold is `cells-le` N=0 — "Win without ever using a free cell" — the cheapest
one-move violation in the pool.)*
1. Set up the Aug 4 board exactly as TC-13.3.
2. Drag the bottom card of column 0 — `3♦` — from **(28,738)** to the first free cell
   **(275,384)** (`touch_path`, ~6 points, 500-600 ms total; a plain tap smart-moves it
   elsewhere and will not exercise the cell).
- **Expected:** the move is **NOT refused** — no alert, no snap-back; `3♦` sits in the free
  cell and Moves = 1. Within the same frame the HUD's **🥇 marker flips from `·` to a red
  `✗`** while its label text is unchanged; 🥉 and 🥈 stay `·`.
  A hard refusal, or a 🥇 chip that still looks earnable, is the bug.
3. Tap `Undo` (142,135).
- **Expected:** `3♦` returns to column 0 and the **🥇 chip returns to `·`** — the
  free-cell counter is rolled back with the board. (This telemetry rollback is deliberate;
  do NOT file it.) Evidence from exploration:
  `evidence/round-0-explore-wf13/wf13-aug4-cell-violation-hud.png` and
  `wf13-aug4-after-undo-hud.png`.

**TC-13.5 [power] (Power) — `no-undo` is permanently failed by Undo while achievement chips roll back.**
*(Aug 6 = dayIndex 5: Silver `no-undo`, Gold `before-ace` rank 10.)*
1. Cold launch → `Daily` (290,176) → swipe `(200,700)→(200,300)` → tap **Aug 6** (254,515)
   → `Play` (200,243). Expect `Deal #983175` and the HUD titled `Aug 6` with
   `🥈 · Win without using undo` / `🥇 · Get every Ten onto the King-end foundation before
   any Ace goes home`.
2. Tap the bottom card of column 2 — `A♠` — at **(126,738)**. It smart-moves to the Ace
   foundation.
- **Expected:** move allowed; **🥇 flips to red `✗`** (an Ace went home before the Tens);
  🥈 still `·`.
3. Tap `Undo` (142,135).
- **Expected:** **🥇 returns to `·`** (foundation order rewound) **and 🥈 flips to red `✗`**
  and STAYS `✗`.
4. Make any further legal move.
- **Expected:** 🥈 is still `✗` — an undo can never be un-undone. Only `Replay` (or
  re-entering from the Daily card) clears it, and doing so restarts the attempt.
  Evidence: `wf13-aug6-gold-violated-hud.png`, `wf13-aug6-noundo-permanent-hud.png`.

**TC-13.6 [novice] [power] (Both) — The how-to-win pill set is exactly right per day (3 pills on a universal-Silver day).**
1. Cold launch → `Daily` → swipe to the calendar.
2. Tap **Aug 5** (201,515), scroll up, count the pills. Then repeat for **Aug 6** (254,515),
   **Aug 3** (94,515) and **Aug 4** (147,515).
- **Expected:**
  - **Aug 5** (`Deal #850,804`, Silver "Win in 115 moves or fewer", Gold "Send all four Aces
    home before any other card") and **Aug 6** (`Deal #983175`, Silver "Win without using
    undo") show **exactly three** pills: `🥉 Clear`, `🥇 Gold`, `🌟 Flawless`.
    **The missing 🥈 Silver pill is CORRECT** — those days' Silver family is universal
    (`moves` / `no-undo`) so `daily-solutions.json` carries no distinct silver line and
    `hasSilverLine` is false. In the reachable range this holds for **Aug 5, 6, 10, 16, 21,
    23, 26** and nowhere else. **Do not file it.** The Silver *tier row* (medal + label +
    empty circle) must still be present in the objectives list on those days.
  - **Aug 3** and **Aug 4** show **all four** pills in a 2x2 grid.
  - A *reachable* day missing the 🥉, 🥇 or 🌟 pill IS a bug (all 61 days carry those lines).
- Cross-check every count with `derive_daily.py <date>`, whose `pills` line is authoritative.

**TC-13.7 [power] (Power) — Objective-family inventory sweep: all thirteen families in one pass.**
*(Aug 1-7 happens to cover all 13 current families, so one row of the calendar is the whole
inventory. Aug 1 is at (361,471); Aug 2…Aug 7 are at y=515, x = 40/94/147/201/254/307.)*
For each day: tap its cell, swipe `(200,300)→(200,640)`, read the card, swipe back down.
Compare every string **exactly** to `python3 .qa-loop/tools/derive_daily.py <date>`.
- **Expected cards:**
  | Day | Deal # | Silver (family) | Gold (family) |
  |---|---|---|---|
  | Aug 1 | 691,039 | Get all four Queens home within your first 29 moves (`rank-rush`) | Split every suit exactly at the Three — A-3 up, 4-K down (`split-at`) |
  | Aug 2 | 665,641 | Take at least 7 of every suit from the Ace end (`end-bias`) | Move a run of 7 or more cards in a single move (`big-move`) |
  | Aug 3 | 539,885 | Never move more than 3 cards in a single move (`max-run`) | Finish one whole suit before any other suit is started (`suit-sprint`) |
  | Aug 4 | 625,648 | Never let one suit get more than 4 cards ahead of another (`suit-balance`) | Win without ever using a free cell (`cells-le`) |
  | Aug 5 | 850,804 | Win in 115 moves or fewer (`moves`) | Send all four Aces home before any other card (`ends-first`) |
  | Aug 6 | 983,175 | Win without using undo (`no-undo`) | Get every Ten onto the King-end foundation before any Ace goes home (`before-ace`) |
  | Aug 7 | 902,614 | Win using free cells at most once (`cells-le`) | For every suit, send its Jack home from the King end before its Ace (`suit-top-first`) |
- **Also assert:** no label is truncated or clipped on the day card (long Gold labels wrap
  to 2-3 lines); each day's deal number changes with the day; the ⏰ line is
  "Same-day is earned on the day itself" on all seven; selecting a new day never leaves the
  previous day's Silver/Gold text on screen (a stale-label bug would be a blocker here).
- **Effort bar (power):** 7 days x (1 tap + 2 swipes). Flag if reading a past day's full card
  needs more than one scroll round-trip.


## WF-14 — ⏰ Same-day recognition (Both)

*(Round-0 exploration, 2026-08-30 16:30-16:45 local, build f0680ef, iPhone 17 Pro portrait,
device points. Every string and coordinate below was observed live this round unless a case says
otherwise.)*

**Fixture / harness for every WF-14 and WF-15 case:**
- ⏰ and 🌟 only appear at WIN time, and no reachable board is winnable by hand in a test pass.
  Two NEW tools make win-time states reachable in ~3 taps (see HARNESS_NOTES "Chunk wf14-15"):
  `node .qa-loop/tools/make_save.mjs --day <dayIndex> --tier <bronze|silver|gold|flawless>
   --challengeDay <d|none> --startDay <d|none>` prints a SavedGame parked at the first position
  where the app's own Finish cascade wins AND still earns that tier; pipe it into
  `python3 .qa-loop/tools/inject_save.py <udid>` and relaunch. The board restores, Auto-finish:Ask
  fires "Ready to finish" immediately, and **Finish (275,497) / Not yet (127,497)**.
  The lines are the app's OWN certified lines from `data/daily-solutions.json` — no illegal state.
- `--startDay` is what makes ⏰ testable without a date override: `--challengeDay 29 --startDay 29`
  = today's attempt begun today (earns ⏰); `--challengeDay 26 --startDay 29` = a past-day replay
  begun today (must NOT earn ⏰); `--challengeDay 28 --startDay 28` = **yesterday's attempt begun
  yesterday**, i.e. the live grace, the one branch that otherwise needs a two-day sequence.
- Fresh install = zero records. To reset records only, delete key `causeway.daily` from the app's
  Preferences plist (`inject_save.py --clear` wipes only the saved game).
- Geometry, Daily sheet **unscrolled** (it opens at the top and shows all 5 streak cards + the whole
  Today card; only the calendar is below the fold): streak cards 🔥(75,199) ⏰(201,199) 🥈(327,199)
  🥇(75,310) 🌟(201,310); Today card header y=450; ⏰ line y=632; Play (200,672);
  pills 🥉(115,747) 🥈(287,747) 🥇(115,786) 🌟(287,786). `Done` (349,100).
- Geometry, **bottom-scrolled** (one swipe (200,700)→(200,300)): day-card ⏰ line y≈203,
  `Play` (200,243); calendar cell `x = 40 + 53.5·((D+5) mod 7)`, `y = 471 + 44·((D+5) div 7)` →
  Aug 27 (254,647), Aug 29 (361,647), Aug 30 (40,691).
- **Toolbar trap:** on a finishable board the `Finish` pill inserts into row 2 and `Daily` moves
  from (290,176) to **(359,175)**; after a win the `Deal #` pill gains ` ✓` and `Daily` sits at
  (302,175). Re-read the row from a screenshot before tapping Daily, or you will open the
  Deal-number alert instead (this cost this dispatch three taps).

**TC-14.1 [novice] [smoke] (Novice) — Five streak cards, and today's unplayed ⏰ invitation.**
1. Fresh install (no records). Launch → tap `Daily` (290,176). Do not scroll.
- **Expected (exact):** a 3+2 grid of FIVE cards — `🔥 Play`, `⏰ Same-day`, `🥈 Silver`,
  `🥇 Gold`, `🌟 Flawless` — each reading `0` / `day streak` / `0 total` / `best 0`, no label
  truncated; then the legend paragraph **"A streak counts consecutive days holding that medal.
  Flawless = 🥉🥈🥇 all three earned in a single run of that day's deal. Same-day = the deal cleared
  on its own date — replaying a past day never earns it."**
  The Today card (Deal #551,879) shows the ⏰ line **"⏰ Win today to start a same-day streak"**
  in secondary grey directly above the gold `Play`.
- **Novice bar:** the ONLY explanation of ⏰ and 🌟 is that one 10 pt legend paragraph. Record
  whether a first-timer can say what "Same-day" means from the card alone. Evidence baseline:
  `evidence/round-0-explore-wf14-15/wf14-today-unplayed-branch.png`.

**TC-14.2 [novice] (Novice) — A past day tells you ⏰ is out of reach; the calendar pip is unlabelled.**
1. Fresh install. `Daily` (290,176) → swipe (200,700)→(200,300) → tap **Aug 27** (254,647).
- **Expected:** the day card's ⏰ line reads **"⏰ Same-day is earned on the day itself"**
  (dimmer than the other three branches: 12 pt, secondary at 70% opacity) and the `Play` button is
  unchanged. Nothing claims the day can still earn ⏰.
2. Read the calendar's legend row (right of "August 2026").
- **Expected/observed:** it lists **🥉 🥈 🥇 🌟 Flawless** and says NOTHING about the ⏰ corner pip
  that ⏰ days carry (a 5 pt gold dot, top-right of the cell). Judge whether a novice can decode a
  bare gold dot. See CC-14-A.

**TC-14.3 [power] [smoke] (Power) — Winning TODAY mints ⏰ across all four surfaces at once.**
1. Fresh install. `node .qa-loop/tools/make_save.mjs --day 29 --tier flawless --challengeDay 29
   --startDay 29 | python3 .qa-loop/tools/inject_save.py <udid>`; relaunch.
   *(Expect the console line `stop at move 92/96`; deal #551879, HUD untitled = today.)*
2. Tap `Finish` (275,497) on the "Ready to finish" prompt; wait ~6 s for the cascade.
- **Expected — win overlay:** `Deal #551,879 · 96 moves`, then the gold line
  **"🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day streak."**
  (⏰ rides after the tier line; buttons sit at y≈512 because that line wraps to two rows).
3. `Close` (318,512) → `Daily` (302,175).
- **Expected — sheet:** all five streak cards read `1` / `1 total` / `best 1`; the Today card
  header is **`Today  🌟 Flawless`**, all three tier circles are green ✓, and the ⏰ line has
  switched to **"⏰ Cleared on the day"** in gold; the button is now **`Replay to improve ↻`**
  (grey, not gold).
4. Swipe (200,700)→(200,300).
- **Expected — calendar:** Aug 30 carries its gold today-ring, a **🌟 under the date** (the tier
  dots are replaced) and a **5 pt gold pip in the top-right corner** (⏰). No other day is marked.
  Evidence: `wf15-win-overlay-flawless-ontime.png`, `wf14-crop-aug30-pip.png`.

**TC-14.4 [power] [smoke] (Power) — Replaying a past day never mints ⏰, however well you play it.**
*(Runs on top of TC-14.3's state so the streak numbers are diagnostic.)*
1. `node .qa-loop/tools/make_save.mjs --day 26 --tier flawless --challengeDay 26 --startDay 29
   | python3 .qa-loop/tools/inject_save.py <udid>`; relaunch. The HUD must be titled **`Aug 27`**
   and the deal `#937619`.
2. `Finish` (275,497).
- **Expected — win overlay:** **"🌟 Flawless! 🥉🥈🥇 all in a single run."** and **NO ⏰ clause at
  all** — this is the orthogonality bar. Any "On time" text here is a blocker-grade scoring bug.
3. `Close` → `Daily`.
- **Expected:** `⏰ Same-day` still reads **1 day streak / 1 total** while 🔥 Play, 🥈, 🥇 and 🌟 all
  advance to **2 total**; the calendar shows **Aug 27 with a 🌟 and NO corner pip**, Aug 30 with
  both. Evidence: `wf14-crop-pastday-no-ontime.png`, `wf14-crop-sameday-total-1.png`,
  `wf15-crop-star-vs-pip.png`.

**TC-14.5 [power] (Power) — The day-granular grace: yesterday's attempt, finished today, earns ⏰.**
*(This is the fourth ⏰ branch. It is reachable ONLY as a two-day sequence or via the save
injector — there is no date override in the app. The injected save is honest: `challengeDay 28,
startDay 28` is exactly "began Aug 29's challenge on Aug 29". If the injector is unavailable, mark
this case **blocked — needs a date override**; do not infer it from code.)*
1. Records wiped for Aug 29. `node .qa-loop/tools/make_save.mjs --day 28 --tier flawless
   --challengeDay 28 --startDay 28 | python3 .qa-loop/tools/inject_save.py <udid>`; relaunch;
   `Not yet` (127,497) on the finish prompt.
2. `Daily` (**359,175** — the Finish pill is present) → swipe (200,700)→(200,300) → tap **Aug 29**
   (361,647).
- **Expected:** the ⏰ line reads **"⏰ Resume your attempt today and it still counts"**
  (secondary grey), NOT "Same-day is earned on the day itself".
3. `Done` (349,100) → `Finish` (170,175 — the toolbar's Finish pill) and wait for the cascade.
- **Expected:** the win overlay reads **"🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time —
  2-day same-day streak."** — the grace paid out for a day that is not today, and Aug 29 + Aug 30
  are consecutive so the streak is 2. The calendar must then show a corner pip on **Aug 29**.
  Evidence: `wf14-crop-grace-line.png`, `wf14-crop-grace-win.png`.
- **Do NOT file the day-granularity itself** (win any time on D+1 counts) — recorded product
  decision. Copy that promises a *midnight* deadline WOULD be a bug; none was seen this round.

**TC-14.6 [power] [novice] (Both) — Two one-tap ways to destroy a live grace, one of them silent.**
*(Set up the grace exactly as TC-14.5 steps 1-2 and stop with the Aug 29 card on screen.)*
1. **Path A (known-open `ux/index.html:gracelive-play-button-forfeits`):** with the grace line
   showing, tap the card's only button, `Play` (200,243).
- **Expected/observed copy:** an alert titled **"End your daily attempt?"** whose body is
  **"Starting this challenge re-deals the board, so your 85 moves and your time will be discarded.
  You can replay the challenge afterwards."** with `Keep playing` / `Start over`. Judge that last
  sentence against the state: replaying is possible, but the ⏰ the line just promised is gone for
  good, and the alert never says so. Tap `Keep playing` (127,517) and confirm the card is unchanged.
2. **Path B (no dialog at all):** `Done` (349,100) → tap the board's `Replay` pill (229,135).
3. Re-open `Daily` (304,175) → swipe → tap **Aug 29** (361,647).
- **Expected/observed:** the ⏰ line has silently fallen back to **"⏰ Same-day is earned on the day
  itself"** — one unconfirmed tap on a pill that costs nothing on a same-day attempt permanently
  forfeited the grace, with no warning before or after. Evidence:
  `wf14-crop-confirm-copy.png`, `wf14-crop-after-replay-line.png`. See CC-14-B / CC-14-C.

## WF-15 — 🌟 Flawless: the tier, the streak, and "how to win flawless" (Both)

**TC-15.1 [novice] [smoke] (Novice) — The 🌟 pill is on every reachable day, and its demo runs.**
1. Fresh install. `Daily` (290,176). On the Today card, count the "Show me how to win:" pills.
- **Expected:** a 2x2 grid — `🥉 Clear` (115,747), `🥈 Silver` (287,747), `🥇 Gold` (115,786),
  `🌟 Flawless` (287,786). Cross-check with `python3 .qa-loop/tools/derive_daily.py <date>`
  (`pills` line is authoritative).
2. Tap `🌟 Flawless` (287,786).
- **Expected:** the sheet dismisses, the board re-deals #551879 and the demo bar reads
  **"🌟 Flawless: Both objectives in one run · 0 / 96"**, paused/ready — it must NOT auto-run.
  The headline wraps to **three** lines here, so the pills sit at **Next (237,273) / Start (297,273)
  / Stop (357,273)** (one line lower than the two-line variant in HARNESS_NOTES).
3. Tap `Next` once → progress must read `1 / 96`. Tap `Stop` (357,266 once the headline re-wraps).
- **Expected:** per WF-6, Stop re-deals a fresh board of the same seed (no demo residue, no Finish
  pill until a real move). Evidence: `wf15-crop-demo-bar.png`.
- **Novice bar:** the pill's own words are "Both objectives in one run" while the definition
  everywhere else is 🥉🥈🥇 (three). Note whether that reads as a contradiction. See CC-15-A.

**TC-15.2 [novice] [power] (Both) — The 🌟 pill is present on every day the calendar exposes, including universal-Silver days.**
1. `Daily` → swipe (200,700)→(200,300). Tap in turn **Aug 5** (201,515), **Aug 6** (254,515),
   **Aug 26** (201,647), **Aug 3** (94,515), **Aug 29** (361,647), **Aug 30** (40,691).
- **Expected:** every one of those days shows a `🌟 Flawless` pill. Aug 5, 6 and 26 show exactly
  **three** pills (🥉/🥇/🌟) — **the missing 🥈 is CORRECT** on the universal-Silver days
  (Aug 5, 6, 10, 16, 21, 23, 26 in the reachable range); the rest show four.
  A reachable day with NO 🌟 pill is a gate bug in `game.hasFlawlessLine(c.seed)` —
  all 61 seeded days carry a certified flawless line (verified in `data/daily-solutions.json`
  and by `tests/solutions.test.mjs`).
- **Also:** a future day (Aug 31, (94,691)) is not selectable at all, so it can show no pills.

**TC-15.3 [power] [smoke] (Power) — A single-run flawless win lights tier row, header, streak card and calendar in agreement.**
1. Fresh install. Inject and finish today's flawless line exactly as **TC-14.3** steps 1-2.
- **Expected — overlay:** `🌟 Flawless! 🥉🥈🥇 all in a single run.` (+ the ⏰ clause, TC-14.3).
- **Expected — Daily sheet:** `🌟 Flawless` streak card = `1 / 1 total / best 1`; card header
  `Today  🌟 Flawless` in gold at 12 pt; **all three** tier circles green.
- **Expected — calendar:** the Aug 30 cell shows a **🌟 in the marker slot, replacing the three
  tier dots**, and **the date does not shift** — compare the baseline of the "30" against
  "23"-"29" in the row above (the ⭐ is drawn in a `frame(height: 6)` slot identical to the dot
  row). Any vertical jitter of the date is the bug this case exists to catch.
  Evidence: `wf14-crop-aug30-pip.png` (30 with ⭐ + pip), `wf15-crop-star-vs-pip.png`.

**TC-15.4 [power] (Power) — Banking 🥈 and 🥇 across two separate runs must NOT mint 🌟.**
*(The definitional case. Aug 27 / dayIndex 26 / deal #937619 is the fixture: its silver line earns
Silver-not-Gold and its gold line earns Gold-not-Silver, verified offline.)*
1. Fresh install (or wipe `causeway.daily`).
   `node .qa-loop/tools/make_save.mjs --day 26 --tier silver --challengeDay 26 --startDay 29
    | python3 .qa-loop/tools/inject_save.py <udid>`; relaunch; `Finish` (275,497).
- **Expected:** overlay reads **"Daily challenge: 🥉 🥈 earned."** — no 🥇, no 🌟, no ⏰.
2. `node .qa-loop/tools/make_save.mjs --day 26 --tier gold --challengeDay 26 --startDay 29
   | python3 .qa-loop/tools/inject_save.py <udid>`; relaunch; `Finish` (275,497).
- **Expected:** overlay reads **"Daily challenge: 🥉 🥇 earned."**
3. `Close` (318,512) → `Daily` (302,175); read the streak cards, then swipe to the calendar.
- **Expected:** `🔥 Play`, `🥈 Silver`, `🥇 Gold` each show **1 total**; **`🌟 Flawless` shows 0
  streak / 0 total / best 0**; the **Aug 27 cell shows three tier dots, NOT a 🌟**; and the Aug 27
  day card has all three tier circles green with **no `🌟 Flawless` in its header**.
  A 🌟 appearing anywhere after this sequence would mean flawless is being OR-ed across attempts —
  a scoring bug (and a devalued streak). Evidence: `wf15-crop-bank-silver.png`,
  `wf15-crop-bank-gold.png`, `wf15-crop-flawless-0-total.png`, `wf15-crop-aug27-dots.png`.

**TC-15.5 [power] (Power) — 🌟 is sticky: a later worse run never takes it away.**
1. Run **TC-15.3** (today is flawless; header shows `Today 🌟 Flawless`).
2. From the Daily card tap **`Replay to improve ↻`** (200,672) → confirm if prompted, then on the
   board tap `Undo`-free but deliberately break Gold (today's Gold is `split-at` at the Eight —
   tap any card that goes home to the wrong end), then abandon: `Daily` → `Play` today again.
3. Re-open `Daily`.
- **Expected:** the header still reads `Today  🌟 Flawless`, the 🌟 streak card still reads 1, and
  the calendar cell still shows 🌟 — `mergeTiers` ORs flawless and never clears it. A lost 🌟 after
  a worse replay is a data-loss bug.
- *(Not walked this round — the injector fixture covers steps 1 and 3; step 2's manual break was
  not executed. Treat the expectation as the model's stated contract, and record what you see.)*


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

---

## Candidate concerns (round-0 exploration HYPOTHESES — reproduce or dismiss in round 1)

*Not findings. Each needs a fresh-launch repro with evidence before it may enter a
LEDGER fragment.*

- **CC-1 (WF-5, DailyHUD) — the live objectives HUD truncates Silver and Gold.**
  On the 402 pt portrait board the HUD renders all three chips on one line, so the
  two longer labels are cut: "🥈 · Win in 103 moves or…" and "🥇 · For every suit,
  send i…". The full text exists only on the Daily card, so a player chasing Gold
  cannot read what Gold is while playing. Hypothesis: WF-5's "objectives are
  legible" is not met for any label longer than ~22 characters (most of the GOLD
  catalogue). Check landscape too (the HUD is 50 pt there). Evidence:
  `evidence/round-0-explore/wf5-hud-objectives-truncated.png`.

- **CC-2 (WF-6 × WF-5) — watching a demo silently discards an in-progress daily
  attempt AND drops the player out of challenge mode.** Repro seen: Daily → `Play`
  → make 1 real move (HUD up, `Undo` enabled) → Daily → `🥉 Clear` → the demo bar
  replaces the HUD and `Undo` is greyed (history emptied) → `Stop` → the board is a
  *casual* fresh deal of the same seed with **no HUD**; the attempt and the
  challenge binding are both gone with no warning, and the player must reopen
  Daily → Play to be scored again. Hypothesis: with 30+ moves of real progress this
  is silent data loss on the user's main scored activity; the "never leave a demo
  board playable" rule may be over-applying to the pre-demo attempt. Evidence:
  `wf5-daily-attempt-in-progress.png`, `wf6-stop-drops-out-of-challenge.png`.
  NOTE for whoever fixes it: restoring the pre-demo attempt is state-migration-ish
  and must not re-open the "finish the app's line and bank it" hole.

- **CC-3 (WF-6, header) — the completed-demo banner leaves "Moves 97 / Time 0:00"
  in the header.** After the Clear line finishes, the header shows the demo's move
  count against a zero clock while the "tap Done to try it yourself" banner is up.
  Hypothesis: a novice reads it as their own 97-move, 0-second game. Cosmetic and
  cheap (blank or label the counters while `demoing || demoDoneMessage != nil`),
  but confirm a novice actually misreads it before filing. Evidence:
  `wf6-demo-line-complete-done-banner.png`.

- **CC-4 (WF-13, Game.swift) — the `no-supermoves` / `no-up-foundation` /
  `no-down-foundation` constraint objectives are not enforced as gates; they are
  telemetry checked only after the move, contradicting WF-13's written expectation.**
  Grepped `Game.swift`: `legalMoves`/`tryMoveToTableau`/`smartMove` have no reference
  to any daily-objective constraint (no `constraint`, no `activeChallenge` gating);
  `Daily.swift` only reads `t.maxRunMoved` / `up[]`/`down[]` counts post-hoc in
  `objViolated`/`liveState` to colour the HUD chip red. Live repro on Aug 7 (deal
  #942,660,922, silver=no-supermoves, gold=no-up-foundation): tapped a legally-built
  2-card run's head — it relocated normally (Moves 2→ Silver chip flips to red ✗,
  no refusal, no prompt); separately exposed and tapped an Ace — it went straight to
  the up-foundation (Moves 3→4, Gold chip flips red ✗, no refusal, no prompt).
  Hypothesis: either (a) this is a real gap against WF-13's stated bar ("must refuse
  a run move"/"must refuse the disallowed end") and the fix should refuse or at least
  confirm the disallowed action while that day's silver/gold is still reachable, or
  (b) WF-13's expectation itself is wrong given the game design (up-foundation moves
  are still needed to legitimately CLEAR the deal for Bronze even on a
  no-up-foundation gold day, so a hard refuse would make Bronze/Silver harder or
  impossible on some deals) — a human should decide which. **fix_risk note for
  whoever files this: a naive "just refuse the move" fix could make the deal
  unsolvable for Bronze/Silver on days where the disallowed foundation is load-
  bearing for clearing — verify solvability-without-that-foundation before blocking
  anything, and consider a confirm-dialog (like WF-6's daily-attempt guard) instead
  of an outright refusal.** Evidence:
  `evidence/round-0-explore-l3/wf13-aug7-constraints-not-gated.png`.

- **CC-13-A (WF-13, DailyView.swift `calendar`, ~L421-425) — the month calendar renders ONLY
  the current calendar month and has no prev/next control, so at every month rollover the
  still-playable past days become unreachable in-app.** `let now = Calendar.current
  .dateComponents([.year,.month], from: Date())` and the grid is built from that single
  `(y,m)`; there is no ‹ › affordance anywhere on the sheet (confirmed visually: the header
  row is just "August 2026" + the medal legend). Today this is benign — every playable day
  (dayIndex 0-29 = Aug 1-30) is in August. Hypothesis: **on 2026-09-01 the sheet renders
  September, and all 31 August days — the entire catch-up backlog, including any day the
  player never cleared — become impossible to select or play**, permanently, even though
  `dailyChallenge(idx, pool)` still returns them. Evidence that would settle it: set the
  host/simulator clock to 2026-09-01, cold-launch, open Daily and try to reach Aug 12.
  Structural (navigation shape) → if confirmed this is **proposal**-routed, not auto.

- **CC-13-B (WF-13, novice; DailyView.swift `calCell` vs `playButton`) — tapping a future day
  does absolutely nothing and the "Unlocks <date>" affordance is unreachable dead code.**
  Repro seen: Daily → scroll → tap Aug 3 (94,515) → tap Aug 31 (94,691): the card stays on
  Aug 3, Aug 31 shows no press feedback, no tint, no message. `calCell`'s tap gesture is
  `if avail { dayView = idx }` and `avail` requires `idx <= todayIndex()`, so `playButton`'s
  `if day > ti { Text("Unlocks \(dayLabel(day))") }` branch can never render. Hypothesis: a
  novice reads the dim cell + silent tap as "the calendar is broken" rather than "not yet",
  and the app already contains the copy that would fix it. Small-scope ux-design → **auto**.
  Evidence: `evidence/round-0-explore-wf13/wf13-aug31-future-not-selectable.png`,
  `wf13-aug31-inert-card-unchanged.png`.

- **CC-13-C (WF-13, novice discoverability) — past days are only reachable through a calendar
  that is entirely below the fold, and nothing on screen says a day is tappable.** On the
  402x874 portrait sheet the first screen is 5 streak cards + the Today card; the calendar
  needs a deliberate scroll, and once you scroll to it the day card's header (the date and
  `Deal #`) is hidden behind the nav bar — after tapping Aug 4 the only confirmation of what
  you selected is a pale tint on a 40 pt cell, and you must scroll back up to see "Aug 4".
  Hypothesis: a first-time user never discovers past days at all, and a user who does cannot
  confirm which day they are about to Play without a second scroll. Evidence that would
  settle it: a clean novice run of TC-13.1 with the tester forbidden to scroll on a hint;
  count attempts. Compare `wf13-calendar-geometry.png` (first screen has no calendar) with
  `wf13-aug4-hud-fresh.png`.

- **CC-13-D (WF-13 x WF-5, DailyView.swift L82 `.onAppear { dayView = clampedToday }`) — the
  Daily sheet always snaps back to Today, even while a PAST-day attempt is in progress, and
  nothing marks the live day.** Repro seen: play Aug 4 from the calendar (HUD correctly reads
  "Aug 4"), then tap `Daily` again — the card is "Today", `Deal #551,879`, today's Silver/Gold,
  and the big gold `Play` button now starts *today's* deal. Neither the card nor the calendar
  marks Aug 4 as in-progress. Hypothesis: a power user mid-Aug-4 taps that Play expecting
  "resume/replay my challenge" and silently swaps deals (the confirm alert's "You can replay
  the challenge afterwards" is technically true but names no day). Note the sheet is also the
  only route back to Aug 4, and its Play *restarts* rather than resumes. Evidence:
  `wf13-daily-resets-to-today-midattempt.png`, `wf13-daily-resets-to-today-card.png`.
  **fix_risk note:** any "remember the last viewed day" fix must not make the sheet open on a
  stale day after midnight (WF-14's ⏰ branches are all date-driven).

- **CC-13-E (WF-13, doc-vs-app) — `par` is parsed but never displayed anywhere, on either
  platform, while WF-13's expectation says a selected past day "shows ITS OWN objectives and
  par".** `PoolDay.par`/`Challenge.par` exist (`Daily.swift:290,301,482`) and every day has one
  (Aug 3 = 86, today = 84), but grepping the Swift views finds no render site, and `index.html`
  only carries it through `dailyChallenge`. Hypothesis: this is a **WORKFLOWS.md wording error,
  not an app gap** — par is a pool-generation/certification field. Do NOT mint a bug from it;
  settle it by a human decision, either surface par on the day card (it is genuinely useful:
  "target 86 moves") or strike "and par" from WF-13. Routing if pursued: **proposal**.

- **CC-14-A (WF-14, novice; DailyView.swift `calendar` legend vs `calCell` pip) — the ⏰ calendar
  pip is an unlabelled 5 pt gold dot; the legend explains 🥉🥈🥇 and 🌟 but not it.** Observed: after
  a same-day win the Aug 30 cell gains a plain gold circle in its top-right corner, while the
  legend row right of "August 2026" reads only `🥉 🥈 🥇 🌟 Flawless`. The pip's colour
  (`Theme.gold`) is also within a hair of the gold TIER dot (`0xD9AD55`) drawn in the same cell at
  the same 5 pt size, so on a non-flawless ⏰ day the two golds appear together with different
  meanings. Hypothesis: a novice reads the corner dot as noise or as a fourth medal. Evidence that
  would settle it: a novice pass on TC-14.2 asking "what does the dot on the 30th mean?".
  Small-scope ux-design (add `⏰` to the legend row) → **auto**. Evidence:
  `evidence/round-0-explore-wf14-15/wf14-crop-aug30-pip.png`, `wf15-crop-aug27-dots.png`.

- **CC-14-B (WF-14, power; ContentView `Replay` pill → `Game.restartDeal`) — the board's `Replay`
  pill silently and permanently forfeits a live ⏰ grace, with no confirmation and no notice.**
  `restartDeal()` preserves `challengeDay` but re-stamps `challengeStartDay = todayIndex()`, and
  the pill has no alert (`pill("Replay") { game.restartDeal() }`, ContentView:416). Live repro
  this round (grace injected for Aug 29, `challengeDay 28 / startDay 28`): the Aug 29 card read
  "⏰ Resume your attempt today and it still counts"; one tap of `Replay` (229,135), no dialog; the
  same card then read **"⏰ Same-day is earned on the day itself"** — the grace was gone and Aug 29
  can never earn ⏰ again. On a same-day attempt Replay costs nothing, so the asymmetry is
  invisible. This is a DIFFERENT surface from the known-open `ux/index.html:gracelive-play-button-
  forfeits` (that one is the Daily card's Play + its false "You can replay the challenge
  afterwards" line, which this round also reproduced verbatim — see `wf14-crop-confirm-copy.png`).
  Hypothesis: worth a confirm (or a "this ends your ⏰ grace" note) ONLY while `graceLive`.
  **fix_risk: metric-integrity** — the naive fix (keep `challengeStartDay` across Replay) would let
  a player start a fresh, full run on D+1 and still bank ⏰, which is exactly what "same-day" is
  supposed to exclude; the safe fix is a warning, not a semantics change. Evidence:
  `wf14-crop-grace-line.png`, `wf14-after-replay-board.png`, `wf14-crop-after-replay-line.png`.

- **CC-14-C (WF-14, both; DailyView.swift L82 `.onAppear { dayView = clampedToday }`) — a live ⏰
  grace is invisible unless you already know to go looking for yesterday's cell.** The Daily sheet
  always opens on Today, whose ⏰ line reads "Win today to start a same-day streak"; the calendar
  puts no in-progress mark on Aug 29; and the grace line exists ONLY on the Aug 29 day card, two
  gestures away (swipe + tap the right cell). The only other hint anywhere is the board HUD's
  small gold `Aug 29` title. Hypothesis: the branch the copy was written for — "you can still save
  yesterday's streak" — is reachable mostly by accident, so the feature under-delivers on the day
  it matters. Related to CC-13-D (same `onAppear` snap-back) but distinct in cost: here the
  player loses a streak, not just context. Structural (where the state is surfaced) →
  **proposal**. Evidence that would settle it: a power pass on TC-14.5 stopping after step 1 —
  can the tester find the grace from the sheet's first screen? Evidence: `wf14-crop-grace-line.png`.

- **CC-14-D (WF-14, novice copy) — the win overlay's ⏰ clause reports the streak but never names
  the day, so a grace win reads as if today were cleared.** Observed on the grace win: "🌟
  Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 2-day same-day streak." for a deal that was
  **Aug 29's**, finished on Aug 30, while Aug 30 itself was still unplayed. Nothing in the overlay
  says "Aug 29" (the Deal # is the only clue), and "2-day same-day streak" invites the reading
  "including today". Hypothesis: low-severity but genuinely misleading — a player may skip today's
  challenge believing it is done. Cheap fix: name the day in the daily line for any
  `challengeDay != todayIndex()` win. Small-scope ux-design → **auto**, minor. Evidence:
  `wf14-crop-grace-win.png`, `wf14-crop-pastday-no-ontime.png` (same anonymity on a past-day win).

- **CC-15-A (WF-15, novice copy) — the 🌟 pill and its demo bar say "Both objectives in one run"
  while every other surface defines Flawless as 🥉🥈🥇 (three).** `DailyView.swift:206` hard-codes
  the label; the demo bar renders "🌟 Flawless: Both objectives in one run · 0 / 96", the streak
  legend says "Flawless = 🥉🥈🥇 all three earned in a single run", and the win overlay says "all in
  a single run". Hypothesis: "Both" (silver+gold, excluding the clear itself) vs "all three" is a
  small but real contradiction on the one screen a novice uses to learn what 🌟 costs. Cheap,
  clearly-correct fix (one string). Small-scope ux-design → **auto**, minor. Evidence:
  `wf15-crop-demo-bar.png`, `wf14-today-unplayed-branch.png` (legend paragraph).

- **CC-15-B (WF-15/WF-5, both; DailyView `streaksRow`) — five streak cards in a 3-column grid
  leave a conspicuous empty sixth slot, and all five numbers move together on almost every win.**
  Observed after the flawless same-day win: 🔥/⏰/🥈/🥇/🌟 all read exactly `1 / 1 total / best 1`,
  five identical cards over one blank cell. Hypothesis (weak, needs a novice to settle it): the
  five-card wall is now more numbers than signal — 🌟 strictly implies 🥈/🥇/🥉, so three of the
  five cards are redundant whenever a player plays flawlessly, while the one card carrying
  genuinely independent information (⏰) is the one with no legend on the calendar (CC-14-A).
  Only worth pursuing if a novice pass reports the row as noise; structural if pursued →
  **proposal**. Evidence: `wf14-streaks-after-pastday.png`, `wf15-crop-flawless-0-total.png`.

- **CC-15-C (WF-15, testability; data/daily-solutions.json + Game.runAutoFinish) — some baked
  flawless lines cannot be finished by the app's own auto-finish cascade without losing Gold.**
  Not a user-visible bug, a fixture finding: building "one tap from a flawless win" saves this
  round, dayIndexes **21, 24 and 27** had NO truncation of their flawless line where the greedy
  `sendOneHome` cascade preserves the day's Gold (ordering objectives like `ends-first` /
  `split-at` conflict with greedy sends), while 20, 22, 23, 25, 26, 28 and 29 all did. Hypothesis:
  a player who plays a perfect line and then accepts "Ready to finish" can be denied Gold **by the
  app's own auto-finish**, on those days, at the last moment. Evidence that would settle it: replay
  day 21's flawless line to its first finishable position in `tests/`, run the cascade, and
  evaluate Gold (the harness in `.qa-loop/tools/make_save.mjs` already does exactly this) — then
  reproduce in-app and check whether the win overlay drops 🥇. If it reproduces in-app this is a
  **bug**, routing auto, and its fix_risk is **metric-integrity** (making auto-finish
  objective-aware changes scored outcomes).
