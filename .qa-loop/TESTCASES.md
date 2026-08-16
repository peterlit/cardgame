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

**TC-2.4 (Both) — Drag/tap an unmovable/buried card (refusal cue).**
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

**TC-2.5 (Both) — Tap that briefly shows no visible response (latency probe).**
1. Cold launch. Timestamp-screenshot immediately before and ~1 s after a smart-move
   tap.
- **Expected:** animation begins within ~0.18 s; a >1 s visible no-response with no
  motion is a (heuristic) finding.

**TC-2.6 (Both) — Portrait tall column: the column's fan compresses, then the whole
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

*All expectations below are DERIVED — run `derive_daily.py` (no argument = today)
before the case and compare its output to the screen. Do not paste a deal number
into an expectation.*

**TC-5.1 (Both) — Open Daily and read objectives + streaks.**
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

**TC-5.2 (Both) — Play hands off to the board with the live HUD.**
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

**TC-5.3 (Both) — Replay-to-improve label after a bronze.**
1. Win the daily once (bronze earned). Re-open `Daily`.
- **Expected:** the Play button now reads "Replay to improve ↻" (grey, not gold);
  Play streak/total/best update from 0; the Today card's Bronze circle is checked and
  the Silver/Gold circles reflect what that attempt actually met.

**TC-5.4 (Both) — Inspect a past / future day via the calendar.**
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

**TC-6.1 (Novice) — Discover and start the Clear demo; it opens paused/ready.**
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

**TC-6.2 (Novice) — Step, run, pause, resume.**
1. From TC-6.1 tap `Next` three times.
2. Tap `Start`, wait ~3 s, then tap the same pill (now `Pause`).
- **Expected:** each `Next` advances the counter by exactly 1 (verified 0→3) and
  animates one move. `Start` auto-advances at ~0.25 s/move, hides `Next` and shows
  `Pause` + `Stop` only, and the headline gains a trailing "…". `Pause` restores
  `Next` / `Resume` / `Stop` and the headline reads `N / total (paused)` — which
  wraps to two lines and nudges the pills to y≈266 (re-read them from a screenshot).
  Moves/Time in the header are not the player's score and nothing is committed.

**TC-6.3 (Novice) — Mid-demo `Stop` re-deals the SAME seed to a fresh board.**
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

**TC-6.4 (Novice) — Run the line to the end, then `Done`.**
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

**TC-6.5 (Novice) — Input is locked while the demo bar is up, including drag-LIFT.**
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

**TC-6.7 (Both) — Demo request with a daily attempt in progress must CONFIRM.**
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

**TC-6.6 (Novice) — Silver / Gold demo lines.**
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

**TC-7.1 (Power) — Open, type, play an exact deal.**
1. Cold launch. Tap `Deal #<seed>` pill. Clear the field, type `10003`, tap `Play`.
- **Expected:** ≤3 taps to open→type→play (open pill, edit, Play) — chrome taps only;
  the number pad costs one tap per digit and one backspace per pre-filled digit, which
  round 1 accepted as within the bar. The named deal loads (Deal # updates), Moves=0.
  Verified on build 5447237: 6 backspaces + `10003` + Play → Deal #10003, Moves 0.

**TC-7.2 (Power) — The deal alert has exactly two actions (contract CHANGED 2026-08-16,
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
  between typed and loaded value with no feedback is a candidate finding). Verified on
  build 5447237: `9999999` → Deal #1000000, `0` → Deal #1, blank → deal unchanged.

**TC-7.5 (Power) — Cancel leaves state untouched.**
1. Open the Deal alert (prefilled with current seed). Tap `Cancel`.
- **Expected:** alert dismisses, same deal, no move counted. CONFIRMED reachable.
  Since 2026-08-16 `Cancel` is the LEFT of the alert's two actions (127,391).

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

**TC-8.3 (Power) — Cycle Auto-finish Ask → Off → On.**
*(order CHANGED 2026-08-16, build 5447237, for `ux/WF-8:autofinish-cycle-through-on-ends-game`:
`.on` is the one state whose mere selection ends a finishable game, so it must never
be a pass-through from the default.)*
1. Tap `Auto-finish: Ask` → `Off` → `On` → back to `Ask`.
- **Expected:** label cycles in that exact order, one tap each, updating immediately;
  the mode persists across `terminate` + `launch` (verified with `On`). Reaching
  `Off` from the default `Ask` must take exactly ONE tap and must never transit `On`.

**TC-8.4 (Power) — Behavior matches label, on a real finishable board.**
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
