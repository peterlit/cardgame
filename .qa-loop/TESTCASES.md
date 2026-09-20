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

- **Main / board.** Header (title + tagline, the `Deal #<seed> ›` chip under them —
  `✓` when that seed is already won — and Moves/Time/Won). Controls (A2 redesign,
  2026-09-13; the wrapping FlowLayout toolbar is gone). **Portrait:** a deck at the
  FOOT of the screen — a `Finish the deal` (gold) pill only when `game.canOfferFinish`,
  then a permanent tier with the two toggles `Auto-play: On/Off` and
  `Auto-finish: Ask/On/Off` (state in a badge), then the deck bar `New game`
  (gold/primary), `Undo` (disabled+40% opacity when no history), `Replay`, `Daily`,
  `More`. **Landscape:**
  the same set as a vertical rail of pills on the left (`toolbar.rail.more` cue when it
  overflows). **Both:** `Wins` and `How to play` live behind the `More` menu
  (`toolbar.more` → `toolbar.wins` / `toolbar.howtoplay`); the same `toolbar.*` ids
  address either orientation. Board: FOUNDATIONS (up row + down row, 4 suits) on the
  left, FREE CELLS (3) on the right, then 8 tableau columns. `Daily` is only present
  when the pool is non-empty (it is here).
- **Deal alert** ("Play a deal"): text field prefilled with current seed,
  numberPad keyboard (digits only — no minus/letters), buttons `Play` / `Cancel`
  (Random was removed on purpose 2026-08-16; range 1–1,000,000 is validated, not clamped).
- **Daily sheet** ("Daily Challenges"): 5 streak cards (🔥 Play / ⏰ Same-day / 🥈 Silver / 🥇 Gold / 🌟 Flawless,
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

The old TC-4.1-4.4 said "drive the deal to a finishable state" with no recipe; every case below now
names the save-injection fixture, which reaches a finishable board in ~4 s. Nothing retired; 4 new
cases added for the 2026-09-08 owner decisions (undo-after-win, clock pause) and for number formatting.
Fixture note: `make_save.mjs --day 14 --tier gold|flawless` FAILS ("no finishable truncation … keeps
its tiers") because day 14's gold is `end-bias` and the cascade sends cards to the wrong end — use
`--tier silver` for a scored daily win on the pinned day, `--tier bronze --challengeDay none
--startDay none` for a casual one on the same deal (608530).

**TC-4.1 [power] [smoke] [perf] (Power) — Auto-finish "Ask" prompts on restore, then completes to the win overlay.**
Start: fresh install; `node .qa-loop/tools/make_save.mjs --day 14 --tier silver --challengeDay 14
--startDay 14 | grep '^{' | python3 .qa-loop/tools/inject_save.py <udid>`;
`launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`.
Steps: `alert` → `tapbtn Finish` → wait ~8 s → `labels texts` → `labels buttons` → `find stat.won` →
`find toolbar.deal`.
Expected: alert titled "Ready to finish" / "Every remaining card can go home. Send them all now?" with
`Not yet` / `Finish`. Finish cascades every card home; overlay shows "You solved it! 🎉",
"Deal #608,530 · 97 moves · M:SS", a daily line ("Daily challenge: 🥉 🥈 earned. ⏰ On time — 1-day
same-day streak.") and the three buttons; `stat.won` = 1; the pill becomes `Deal #608530 ✓`.

**TC-4.2 [power] (Power) — "Not yet" defers, does not nag again, and leaves a Finish pill.**
Start: same injected save, freshly launched.
Steps: `tapbtn "Not yet"` → `labels buttons` → make no move for ~15 s, `alert` again → `find
toolbar.finish` → `tapid toolbar.finish` → wait ~8 s → `labels texts`.
Expected: prompt dismisses; a gold `Finish` pill appears in the toolbar (portrait row 2 between
Auto-finish and Deal #); no second prompt for the rest of the game; the pill completes the deal to the
same win overlay.

**TC-4.3 [power] (Power) — The win overlay's three exits.**
Start: win overlay from TC-4.1.
Steps: (a) `tapbtn Close` → `find stat.won`, `find toolbar.deal`, `find toolbar.undo`;
(b) re-reach a win (re-inject + relaunch + Finish) → `tapbtn "Play deal #<next>"` → `find toolbar.deal`
+ `find stat.moves`; (c) re-reach a win → `tapbtn Random` → `find toolbar.deal` + `find stat.moves`.
Expected: Close leaves the solved board with the overlay gone and the `✓` pill intact; `Play deal
#<next>` loads exactly seed+1 (608531) with Moves 0 and NO `✓`; `Random` loads some other seed with
Moves 0. Each is one tap.

**TC-4.4 [power] (Power) — All three Auto-finish modes on one finishable board.**
Start: a finishable board with the prompt already dismissed (TC-4.2 state, or post-win + one `Undo`).
Steps: `tapid toolbar.autofinish` → `find toolbar.autofinish` (expect `Auto-finish: Off`) → `alert`
(expect none) → `find toolbar.finish` → `tapid toolbar.autofinish` → `find toolbar.autofinish`
(expect `Auto-finish: On`) → wait 3 s → `find stat.moves` + `labels texts`.
Expected: cycling is one tap per mode, Ask → Off → On. In Off no prompt fires and the `Finish` pill is
the only completion route. Switching to On fires the cascade IMMEDIATELY (mode `didSet` calls
`maybeAutoFinish()`) with no prompt, ending on the win overlay.

**TC-4.5 [power] (Power) — Undo after a scored win is a casual continuation (owner decision 2026-09-08).**
Start: a won daily board (TC-4.1), overlay closed.
Steps: `find toolbar.undo` → `tapid toolbar.undo` → `find stat.moves`, `find stat.won`,
`find toolbar.deal`, `find toolbar.finish` → complete it again (Finish pill or Auto-finish: On) →
`labels texts` on the new overlay → open Daily and read the day's card.
Expected: Undo is enabled after the win; Moves decrements (97 → 96/99 per the cascade), `stat.won`
does NOT decrease, the `✓` stays, and the Finish affordance returns. The re-completion produces a win
overlay with NO daily medal line (the daily binding is gone) and records a fresh casual win. This is
NOT a bug — only a missing/decremented award or a lost daily record would be.

**TC-4.6 [power] (Power) — Backgrounding pauses the solve clock.**
Start: any live game with Time running (injected save restores at ~1:33).
Steps: read `stat.time` → `home` → wait 20 s → `activate` → read `stat.time` within 2 s → wait 10 s →
read again.
Expected: the banked time excludes the background window (delta across the background ≤ ~2 s, not
~20 s), and the clock resumes ticking on foreground (second read is ~10 s later). Note: this is a
correctness check, not a perf measurement — allow ±2 s.

**TC-4.7 [power] (Power) — Deal-number formatting is consistent on the win overlay.**
Start: any win overlay.
Steps: `labels texts | grep "Deal #"` and `labels buttons` on the overlay; compare with
`find toolbar.deal` and the Wins row for the same deal.
Expected: one format for the same class of number across the dialog. Currently the result line prints
`Deal #608,530` (comma-grouped) while the button next to it prints `Play deal #608531` and the pill and
Wins print `608530` — see CC-4A / prior finding `bug/WF-4:win-overlay-seed-grouped`.

**TC-4.8 [power] (Power) — A daily win reports its tiers and the ⏰ line correctly.**
Start: injected silver save for the pinned day (`--day 14 --tier silver --challengeDay 14 --startDay 14`).
Steps: Finish → read the overlay's daily line → `tapbtn Close` → `tapid toolbar.daily` → read the
Today card, the five streak cards and the `daily.clears` line.
Expected: overlay says exactly which medals were earned (🥉 🥈, not 🥇 — day 14's gold `end-bias` is
violated by the cascade and the HUD already shows 🥇✗) plus the ⏰ same-day line; the Daily sheet then
shows Play/Same-day/Silver streaks at 1 (Gold/Flawless 0) and a `daily.clears` line for that day whose
"fewest/fastest" match the run.

## WF-5 — Daily Challenge: read objectives, play, read stats (Both)

*(Re-explored 2026-09-09. All expectations DERIVED — run `python3 .qa-loop/tools/derive_daily.py 14`
(= pinned Today, Aug 15) before the case. Under the pin Today is `Deal #608530`, par 87, Silver
`max-run` "Never move more than 2 cards in a single move", Gold `end-bias` "Take at least 10 of every
suit from the King end". Launch every case with `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`.)*

**TC-5.1 [novice] [power] [smoke] (Both) — Open Daily and read objectives + the five streak cards.**
Start: fresh install, pinned launch.
Steps: `tapid toolbar.daily` → `labels any`.
- **Expected:** sheet titled "Daily Challenges"; **FIVE** streak cards in a 3+2 grid — 🔥 Play,
  ⏰ Same-day, 🥈 Silver, 🥇 Gold, 🌟 Flawless — each with a big current number, "N total" and
  "best N" (all 0 on a fresh install) and an accessibility label of the form
  "Play: current streak 0 days, 0 days total, best 0 days"; the explainer paragraph ("A streak counts
  consecutive days… Same-day = the deal cleared on its own date — replaying a past day never earns
  it."); the day card headed **"Today"** with `Deal #608530`; Bronze/Silver/Gold rows carrying the
  derived labels, each with an empty `circle`; the ⏰ line **"⏰ Win today to start a same-day
  streak"**; a gold `daily.play` labelled plain **"Play"**; "Show me how to win:" with all four
  `daily.demo.*` pills; then the calendar and the BACKUP section. `Done` (top-right) dismisses.
- **Expected (negative):** an unsolved day shows **no `daily.clears` line and no par anywhere** —
  that is the current design, not the old `par-never-surfaced` gap. See CC-13-B.
- **Effort bar:** streak vs total vs best distinguishable at a glance; no objective text truncated
  (long Gold labels wrap to 2 lines).

**TC-5.2 [novice] [power] (Both) — Play hands off to the board with the live HUD.**
Start: TC-5.1's sheet, Today selected.
Steps: `tapid daily.play` → `find toolbar.deal` → `find hud.day` → `labels texts | grep -E "🥉|🥈|🥇"`.
- **Expected:** one tap; sheet dismisses; `toolbar.deal` = **`Deal #608530`**; `stat.moves` 0,
  `stat.time` 0:00; the three-line stacked HUD sits directly under the toolbar with chips
  `🥉·Clear the deal` / `🥈·Never move more than 2 cards in a single move` / `🥇·Take at least 10 of
  every suit from the King end`, **no "…" anywhere** (any ellipsis is a regression of
  `ux/WF-5:daily-hud-truncates-objectives`). On TODAY's challenge `hud.day` **does not exist**
  (the day title is only rendered for a past day) — chips start at y≈250 instead of 265.
- **Also assert:** with a live casual game (≥1 move) on the board, this Play first raises "Discard the
  game in progress?" (Keep playing / Start over) and only then deals.

**TC-5.3 [novice] [power] (Both) — After a win the card switches to replay-to-improve and banks medals.**
Start: a cleared day. Fixture (deterministic, no manual play):
`node .qa-loop/tools/make_save.mjs --day 2 --tier gold --challengeDay 2 --startDay 2 | grep '^{' |
python3 .qa-loop/tools/inject_save.py <udid>` → pinned `launch` → the Auto-finish:Ask prompt
"Ready to finish" appears at once → `tapbtn Finish` → wait ~12 s → close the win overlay
(`tap 318 502`).
Steps: `tapid toolbar.daily` → 2 swipes → `tapid daily.cal.2` → `labels any`.
- **Expected:** the win overlay reads "You solved it! 🎉", "Deal #539,885 · 107 moves · 1:41" and
  **"Aug 3: Daily challenge: 🥉 🥇 earned."**; on the day card `daily.play` becomes
  **"Replay Aug 3 to improve ↻"**; the Bronze and Gold rows show `checkmark.circle.fill`, Silver
  stays an empty `circle`; the 🔥 Play streak card reads **0 day streak / 1 total / best 1** (a
  12-day-old day cannot extend a current streak) and ⏰ Same-day stays 0 (a past day never mints ⏰).

**TC-5.4 [novice] [power] [smoke] (Both) — The clears line: counts, independent minima, and par.**
*(New — `daily.clears` shipped 2026-09-09.)*
Start: TC-5.3's state (Aug 3 cleared once, 107 moves).
Steps: `find daily.clears`; then inject a SECOND, different run —
`make_save.mjs --day 2 --tier bronze --challengeDay 2 --startDay 2` → pinned launch → `tapbtn Finish`
→ close overlay → Daily → 2 swipes → `tapid daily.cal.2` → `labels any daily.clears`.
- **Expected after one run:** exactly one `daily.clears` element reading
  **"Cleared · fewest 107 moves · fastest 1:41 · par 86"** (no "1×", no per-run list).
- **Expected after two runs:** **TWO** elements both identified `daily.clears` (so use
  `labels any daily.clears`, not `find` — `find` returns only the first):
  **"Cleared 2× · fewest 96 moves · fastest 1:38 · par 86"** and
  **"Moves each run: 107 · 96"**. Fewest and fastest are INDEPENDENT minima across runs (they may
  come from different runs — that is by design); par is the pool's certified par for that day
  (`derive_daily.py 2026-08-03` → 86) and appears ONLY on a cleared day.
- **Also assert (regression):** the Gold check earned in run 1 is still ticked after the
  bronze-only run 2 — a banked medal must never be un-earned by a later, worse run.
  Evidence: `evidence/round-0-explore/wf13-5-7/wf5-clears-line-two-runs.png`.

**TC-5.5 [novice] (Novice) — Inspect a past day and get back to Today.**
*(Rewrote the old TC-5.4: the "future day shows Unlocks <Mon D>" branch is unreachable from the
calendar — a locked cell can never become the selected day; it now answers with `daily.lockednote`.)*
Start: pinned launch, Daily open, calendar scrolled in.
Steps: `tapid daily.cal.0` (Aug 1) → read card → `tapid daily.cal.14` (Aug 15) → read card.
- **Expected:** Aug 1 → header "Aug 1", `Deal #691039`, Silver "Get all four Queens home within your
  first 29 moves", Gold "Split every suit exactly at the Three — A-3 up, 4-K down", `daily.play` =
  "Play Aug 1". Tapping `daily.cal.14` restores the **"Today"** card (`Deal #608530`, plain "Play",
  ⏰ line back to "Win today to start a same-day streak"). Today's cell keeps its gold ring while the
  selected cell carries a gold tint — check both are distinguishable when Today IS the selection.
- **Effort bar (novice):** getting from Today's card to a past day's card and back should not require
  re-scrolling the sheet; note it if it does.

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

*(Re-explored 2026-09-09. **The advertised range CHANGED**: the alert body now reads "Enter a deal
number (1–1,000,000) to play that exact deal." and enforces exactly that. The old TC-7.4 expectation
of 1–4,294,967,295 is stale and is rewritten below.)*

**Mechanics (measured this round):** `tapid toolbar.deal` opens the alert with the field
**pre-filled AND already focused** — `selectall` + `type` work with NO tap on the field, so the whole
flow is `tapid toolbar.deal` → `selectall` → `type <n>` → `tapbtn Play` (2 chrome taps). Alert
buttons: `Cancel@57,368,140,48`, `Play@205,368,140,48` with the number pad up (y 583-816) — the
alert does **not** move for the keyboard, but it DOES move when the field is emptied (Play jumps to
y=505), so use `btn Play` / `tapbtn Play` and never a cached coordinate.

**TC-7.1 [power] [smoke] (Power) — Open, type, play an exact deal.**
Start: pinned launch, any board.
Steps: `tapid toolbar.deal` → `selectall` → `type 500001` → `tapbtn Play` → `find toolbar.deal` →
`find stat.moves`.
- **Expected:** 2 chrome taps (open + Play) plus typing — inside WF-7's ≤3-tap budget;
  `toolbar.deal` reads `Deal #500001`, `stat.moves` 0, no alert left on screen.
- **Also assert:** on a board whose deal is already won the pill carries a trailing ` ✓`
  (e.g. `Deal #539885 ✓`) and the toolbar reflows — re-`find` toolbar ids after any win.

**TC-7.2 [power] (Power) — The deal alert has exactly two actions.**
Steps: `tapid toolbar.deal` → `alert` → `btn Random`.
- **Expected:** `alert` reports title "Play a deal", body "Enter a deal number (1–1,000,000) to play
  that exact deal.", buttons exactly **Cancel** (left) and **Play** (right). **No `Random` action**
  (`tapbtn Random` must report a miss) — its removal in 2026-08-16 is intended; the random-deal
  capability lives in the always-visible `toolbar.newgame`.

**TC-7.3 [power] (Power) — Play is gated on a valid, in-range number (edges).**
*(Merges and RETIRES the old TC-7.3 "blank input" case, which asserted the same disabled button.)*
Steps: `tapid toolbar.deal`, then for each input `selectall` + `type` and read `btn Play`:
`9999999` → `0` → blank (`selectall` + `key delete`) → `1000000` → `1`.
- **Expected:** `enabled=false` for `9999999` (above the advertised ceiling), `0`, and blank;
  `enabled=true` for `1000000` and `1`. The app never loads a deal different from the one typed
  (no silent clamping), and `Cancel` leaves the current deal and Moves untouched.
- **Note:** with a blank field the alert grows and `Play` moves to y≈505 — assert by `btn`, not
  by coordinate.

**TC-7.4 [power] (Power) — Cancel leaves state untouched.**
Steps: make ≥1 move → `tapid toolbar.deal` → `selectall` → `type 424242` → `tapbtn Cancel` →
`find toolbar.deal` → `find stat.moves`.
- **Expected:** alert dismisses, the deal is unchanged, Moves unchanged, no confirmation alert
  appears afterwards (the 0.1 s deferred confirm must not fire on a Cancel).

**TC-7.5 [power] [smoke] (Power) — Replacing a LIVE game asks first, from both routes, and survives a double-tap.**
*(Regression guard for the prior open major `bug/WF-7:deal-confirm-swallowed-by-double-tap` —
`ContentView.requestDealFromDismissal` still hops the confirm 0.1 s off the runloop. It did NOT
reproduce on this build/device; see CC-13-D. This case is what proves it stays that way.)*
Start: pinned launch → `tapid toolbar.deal` → `selectall` → `type 500001` → `tapbtn Play` →
smart-move one card (`labels any card.`, tap the deepest card of a column) so `stat.moves` = 1.
Steps (route A — Deal pill): `tapid toolbar.deal` → `selectall` → `type 500002` →
**`doubletap 275 392`** (the centre of the alert's `Play`) → `sleep 1.5` → `alert` →
`find toolbar.deal`.
Steps (route B — Wins screen): `tapbtn "Keep playing"` → `tapid toolbar.wins` →
`tap 180 191` (the Wins "Play a deal" field is **not** auto-focused, unlike the Deal alert's) →
`type 500003` → **`doubletap 357 191`** → `sleep 1.5` → `alert` → `find toolbar.deal`.
- **Expected (both routes):** the confirmation "Discard the game in progress?" is on screen and
  INTACT after the double-tap, with buttons **Keep playing** (57,493) / **Play that deal** (205,493);
  `toolbar.deal` still reads `Deal #500001` and `stat.moves` is still 1 — i.e. the second tap of the
  double-tap neither activated the destructive action nor dismissed the confirm nor leaked through to
  the board. The confirm's buttons must stay ≥100 pt away from the button the finger just hit
  (measured this round: Play y=392 vs confirm y=493 on route A; 191 vs 493 on route B).
- **Fail condition:** the deal changes without a confirmation, OR no confirm is ever raised, OR the
  confirm appears and is dismissed by the same gesture.

**TC-7.6 [power] (Power) — Replacing a live game from the DAILY route names what is being lost.**
Steps: from a live casual board with 1 move, `tapid toolbar.daily` → `tapid daily.play` → `alert`.
- **Expected:** title "Discard the game in progress?", body **"Starting this challenge re-deals the
  board, so your 1 move and your time will be discarded. This game is not a challenge, so there is no
  way back to it."**, buttons **Keep playing** / **Start over**. The move count in the copy must match
  `stat.moves`. `Keep playing` returns to the untouched board (Moves still 1, same `toolbar.deal`);
  `Start over` deals the challenge. A 0-move board must be replaced with NO prompt.
  (See CC-13-E on the double meaning of "challenge" in that sentence.)

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

Changes verified live this loop: a drilled-in row now reads
`Deal #608530, fewest 97 moves · fastest 3:04 · Sep 9` (independent minima, one a11y element with a
`play.circle.fill` glyph) under the hint "Tap a deal to play it again."; the range list header reads
"N deal(s) solved · M range(s)"; the "Play a deal" field is EMPTY on open (unlike the board's Deal #
alert, which is prefilled) and now VALIDATES instead of clamping — out-of-range input disables `Play`
and shows `wins.dealentry.problem` "Deal numbers run 1–1,000,000."; and both the field's `Play` and a
row tap route through the live-game confirmation. TC-9.1-9.3 keep their ids with rewritten steps;
nothing retired; 9.4-9.7 are new.

**TC-9.1 [novice] [power] [smoke] (Both) — Wins empty state.**
Start: fresh install, `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`, no wins.
Steps: `tapid toolbar.wins` → `labels any` → `btn Play` → `tapbtn Done`.
Expected: sheet titled "Deals won"; a "Play a deal" row with an empty field and a `Play` button that
is `enabled=false`; "No wins yet — go solve one!"; `Done` (top-right) dismisses back to the board.

**TC-9.2 [novice] [power] (Both) — Populated Wins: counts, range chip, drill-in row, back nav.**
Start: exactly one deal won (inject + Finish per TC-4.1), board NOT live (post-win).
Steps: `tapid toolbar.wins` → `labels any` (read "1 deal solved · 1 range" and the chip) → tap the
chip → `labels any` → `tapid BackButton` → `tapbtn Done`.
Expected: "1 deal solved · 1 range" and a chip labelled `608530`; the chip opens a list whose row reads
"Deal #608530, fewest 97 moves · fastest M:SS · <date>" with a play glyph and the hint "Tap a deal to
play it again."; a `BackButton` labelled "Deals won" returns to the range list; `Done` dismisses. A
novice must be able to get back without guessing (both exits are visible).

**TC-9.3 [power] (Power) — "Play a deal" field validation.**
Start: Wins sheet open.
Steps: `btn Play` with the field empty → tap the field, `type 0` → `labels any wins.dealentry.problem`
+ `btn Play` → `selectall`, `type 2000000` → same two reads → `selectall`, `type 500001` → `btn Play`
→ `tapbtn Play`.
Expected: `Play` is `enabled=false` for empty, `0` and `2000000`, and the note
`wins.dealentry.problem` "Deal numbers run 1–1,000,000." appears for the out-of-range values (no
silent clamping); a valid number enables `Play`, which loads that deal and dismisses the sheet.

**TC-9.4 [power] [smoke] (Power) — Playing from Wins over a live game asks first (ceeb5f9).**
Start: a live casual game with at least one move (`tapid` any movable card), and at least one win on
record.
Steps: (a) `tapid toolbar.wins` → tap the field, `type 500001` → `tapbtn Play` → `alert` →
`tapbtn "Keep playing"` → `find stat.moves`; (b) `tapid toolbar.wins` → tap the range chip → tap the
row → `alert` → `tapbtn "Play that deal"` → `find toolbar.deal` + `find stat.moves`.
Expected: BOTH routes raise "Discard the game in progress? / Your N move(s) and your time will be
discarded. This game is not a challenge, so there is no way back to it." with `Keep playing` /
`Play that deal`. Keep playing preserves Moves and Time exactly (and returns to the board);
Play that deal loads the chosen deal with Moves 0. Silently replacing a live game from Wins is a bug.

**TC-9.5 [power] (Power) — Fewest and fastest are independent minima across runs.**
Start: fresh install. Run 1: `make_save.mjs --day 14 --tier silver --challengeDay 14 --startDay 14`
→ launch → Finish (records 97 moves at ~3:04). Run 2: `make_save.mjs --day 14 --tier bronze
--challengeDay none --startDay none` → launch → Finish immediately (records 100 moves at ~1:45).
Steps: after each run open Wins → chip → read the row. Then win the SAME deal a third time more slowly
(post-win `Undo`, then `Auto-finish: On`) and read the row again.
Expected: after run 2 the row reads "fewest 97 moves · fastest 1:45" — the move count from run 1 and
the time from run 2, never one run's pair. A third, slower/longer run must not change either number.

**TC-9.6 [novice] (Novice) — From a finished (non-live) board, a row tap replays immediately.**
Start: a board that has just been won and the overlay closed (nothing in progress).
Steps: `tapid toolbar.wins` → chip → tap the row → `alert` → `find stat.moves` + `find toolbar.deal`.
Expected: NO discard confirmation (there is no game in progress to lose); the deal loads with Moves 0
and the sheet dismisses in one tap.

**TC-9.7 [power] (Power) — Range compression with several wins.**
Start: win 3+ deals with adjacent and distant seeds (e.g. 608530, then `Play deal #608531` and finish
it via injection/auto-finish, then a far seed such as 500001).
Steps: `tapid toolbar.wins` → `labels any` → open each chip.
Expected: the header counts deals and ranges correctly ("N deals solved · M ranges"); adjacent seeds
collapse into one chip labelled as a range and distant ones get their own chip; every won deal is
reachable from exactly one chip and no won deal is missing.

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

## WF-12 — Landscape play (Both)

Rotation is LIVE this loop (`qa.py <udid> rotate landscapeLeft|portrait`), so every WF-12 case below is
runnable; the loop-4 "static review" cases are rewritten, none retired. Measured landscape geometry
(iPhone 17 Pro, 874x402, build 1a63ce2, no HUD): rail pills all `[68,Y,118,26]` at Y = 57 New game /
90 Undo / 122 Replay / 154 Auto-play / 186 Auto-finish / 219 Deal # / 251 Daily / 284 Wins /
316 How to play (+ `toolbar.finish` inserts after Auto-finish and pushes the rest down 32). Header
`Causeway` (68,6); Moves/Time/Won at x 686-805, y 8-44. FOUNDATIONS label (196,57); up row A slots
x=200/249/298/347 y≈75-119 (tap centre ~218/267/316/365, y=109), down row same x at y≈155-199
(centre y=189). FREE CELLS label (196,238); cells left-x 196/245/294, top y=254 (centre y≈291).
Tableau column left-x = 398,447,496,545,594,643,692,741; card i top y = 57+26*i; card size 45x75 pt —
**identical to portrait** (portrait col left-x 6,55,…,349; card i top y = 425+30*i). With the daily
objectives HUD the whole rail shifts +40 (New game y=97 … How to play y=388) and the rail's visible
scroll window is only y 97-327.

**TC-12.1 [novice] [power] [smoke] (Both) — Rotate to landscape: the board reflows and stays complete.**
Start: fresh install, `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`, portrait, no daily HUD.
Steps: `labels buttons` (record the 9 portrait toolbar pills) → `rotate landscapeLeft` → `frame` →
`labels buttons` → `labels texts` → `labels any card.`.
Expected: `frame` = 0,0,874,402. All 9 `toolbar.*` pills present in one 118-pt-wide LEFT rail at x=68,
each 26 pt tall, in the portrait order; header + Moves/Time/Won still visible; `FOUNDATIONS · A↑ / K↓`
and `FREE CELLS` labels present with 8 foundation slots and 3 cells; 52 `card.*` elements in 8 columns.
No element clipped off the 874x402 frame, no horizontal scroll bar over the board.

**TC-12.2 [novice] [power] (Both) — Every control is reachable in landscape when the daily HUD is live.**
Start: inject a live daily save — `node .qa-loop/tools/make_save.mjs --day 14 --tier silver
--challengeDay 14 --startDay 14 | grep '^{' | python3 .qa-loop/tools/inject_save.py <udid>` →
`launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` → `tapbtn "Not yet"` (the Ready-to-finish prompt) →
`rotate landscapeLeft`.
Steps: `labels buttons` → `find toolbar.wins` / `find toolbar.howtoplay` → screenshot and look for the
`⌄ more` hint under the rail → scroll the rail with a swipe that STARTS INSIDE the scroll window
(`swipe 110 300 110 130`; a swipe starting at y>327 does nothing) → `find toolbar.howtoplay` again →
`tapid toolbar.howtoplay`.
Expected: with the HUD the rail gains a 10th pill (`toolbar.finish`) and the last three
(`Daily`, `Wins`, `How to play`) fall outside the visible scroll window (`hittable=false`); a visible
affordance says more controls exist; one short swipe inside the rail brings them up and they become
`hittable=true` and tappable. Nothing is permanently unreachable. *(Discoverability of the scroll is
the point of the novice half — see CC-12A.)*

**TC-12.3 [power] (Power) — Card size, tap-to-smart-move and drag all work in landscape.**
Start: TC-12.1 state (fresh deal, landscape).
Steps: record `labels any card.` (sizes + column x) → `tapid card.<bottom card of col 0>` →
`find stat.moves` → `labels any card.<that card>` → drag a bottom card onto a legal column
(`drag <src centre> <dst column centre + 40>`) → verify its new frame → drag another bottom card to
the first free cell (`drag X Y 218 291`) → verify frame `[196,254,45,75]`.
Expected: cards are 45x75 pt (not floored to the 30-pt minimum); tap smart-moves exactly as in
portrait and Moves increments by 1 each time; both drags land on the intended target — a long
right-to-left drag across the whole 874-pt screen to a free cell must work, proving the drop-zone
hit test is orientation-independent.

**TC-12.4 [power] (Power) — A game survives a rotation round trip.**
Start: landscape, 2 moves made (one tap-move, one drag).
Steps: note `stat.moves`, `stat.time` and two card frames → `rotate portrait` → re-read the same
elements → `rotate landscapeLeft` → re-read.
Expected: Moves, Time, Won and the position of every card are preserved across both rotations; card
frames map to the other orientation's documented grid (free-cell card at portrait [253,258,45,75] ↔
landscape [196,254,45,75]); no re-deal, no lost undo history (`toolbar.undo` still enabled).

**TC-12.5 [power] (Power) — The Deal # alert is fully usable in landscape (number pad up).**
Start: landscape, any board.
Steps: `tapid toolbar.deal` → `alert` → `labels textfields` → `tap` the field, `selectall`,
`type 500001` → `tapbtn Play` → `find toolbar.deal`.
Expected: alert "Play a deal" with the prefilled current deal and exactly two buttons —
`Cancel` and `Play` — BOTH fully on screen above the number pad (the landscape keyboard eats ~170 pt;
`Random` was deliberately removed from this alert, see ContentView.swift:283 — its absence is correct,
the Screen-map line that still lists `Play / Random / Cancel` is stale). Play loads deal 500001.

**TC-12.6 [novice] [power] (Both) — Sheets in landscape: Daily, Wins, How to play.**
Start: landscape, fresh install (no wins), pinned date.
Steps: `tapid toolbar.daily` → `labels buttons` + `labels texts` + screenshot, note where
`daily.play` sits → dismiss with `tapbtn Done` → `tapid toolbar.wins` → `labels any` → `tapbtn Done`
→ scroll the rail if needed → `tapid toolbar.howtoplay` → `labels texts` → `tapbtn Done`.
Expected: each sheet fills the 874x402 screen, `Done` is at (766,28) and dismisses; text is not
truncated or overlapping; the Wins empty state ("No wins yet — go solve one!") and all How-to-play
sections (Goal / The catch / Tableau / Free cells / Controls / About) are readable by scrolling.
For Daily, record how far below the fold `daily.play` is — the primary action of the sheet should not
require a scroll to discover (see CC-12B).

**TC-12.7 [power] (Power) — The win overlay in landscape, including rotating while it is up.**
Start: injected finishable save (`--tier silver --day 14 --challengeDay 14 --startDay 14`), landscape,
`Not yet` dismissed.
Steps: scroll the rail if needed → `tapid toolbar.finish` → wait ~8 s → `labels texts` +
`labels buttons` + screenshot → `rotate portrait` → re-read → `rotate landscapeLeft` → re-read →
`tapbtn Close`.
Expected: overlay reads "You solved it! 🎉", "Deal #… · N moves · M:SS" and the daily result line, with
`Play deal #<next>` / `Random` / `Close` all on screen (landscape y≈212-227) and hittable; rotating in
either direction re-lays it out without losing the result or dismissing it; `Close` returns to the
solved board with `stat.won` incremented and the `Deal #… ✓` pill.

**TC-12.8 [power] (Power) — A tall column in landscape does not clip.**
Start: landscape, fresh deal; build one column up to ~12-14 cards (repeatedly drag legal cards onto
one column, or replay a save whose line stacks deep).
Steps: after each growth step `labels any card.` and check the lowest card's `y+h` against 402 and
whether the shared card size changed.
Expected: the fan compresses first; if it can no longer fit, the WHOLE board (foundations, cells,
tableau) shrinks once to a single smaller uniform card size — never two sizes at once, never a card
whose bottom is past the safe area, and the bottom card stays tappable (`find` reports
`hittable=true`).

## WF-13 — Past days & the objective-family inventory (Both)

*(Re-explored 2026-09-09 on the CURRENT build, worker `causeway-qa-2`, iPhone 17 Pro 402x874,
driven with `Q="python3 .qa-loop/driver/qa.py <udid>"`. Every case launches with the Fixture-policy
date pin `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` → **Today = Aug 15 = dayIndex 14, past days =
0…13, Aug 16+ locked**. The old section assumed today = Aug 30 / dayIndex 0-28 and raw calendar
coordinates; both are stale and are replaced here by `daily.cal.<idx>` identifiers.)*

**Fixture / mechanics every case below depends on (all measured this round):**
- `python3 .qa-loop/tools/derive_daily.py <YYYY-MM-DD|dayIndex>` prints the authoritative deal, par,
  Silver/Gold labels + family, and the pill set. Never hand-type an expectation. (Its "card head"
  field does not know about the pin — under the pin dayIndex 14 is headed **Today**, not "Aug 15".)
- The Daily sheet opens scrolled to the top; the month calendar is **two full screens below the
  fold** and its cells are LAZY — `tapid daily.cal.N` fails until you scroll. Recipe:
  `tapid toolbar.daily` → `swipe 200 700 200 200` **twice** → `tapid daily.cal.<idx>`.
- Calendar identifiers: `daily.cal.0…30` = Aug 1…31, `daily.cal.31…60` = Sep 1…30 (the identifier is
  the dayIndex, not the date). `daily.cal.prev` / `daily.cal.next` / `daily.cal.month`.
- Day card: header text = "Today" or "Aug D"; `daily.play` label is **"Play Aug 3"** on a past day,
  bare **"Play"** on Today, **"Replay Aug 3 to improve ↻"** once that day is cleared.
- Board with a PAST-day challenge: `hud.day` exists (gold "Aug 3") and the three chips sit at
  y=265/281/298; on TODAY's challenge `hud.day` does **not** exist and the chips start at y=250.
  Assert chip state with `labels texts | grep -E "🥉|🥈|🥇"` (marker `·` / `✓` / `✗` is part of the
  chip's own label text) — cheaper and more exact than a screenshot.
- Tableau bottom card: columns are NOT the same depth. Get it with
  `labels any card.` and take the largest y in that column (row i top y = 514 + 30·i with a 3-line
  past-day HUD). Guessing cost this exploration one bogus "the drag moved the wrong card".

**TC-13.1 [novice] [smoke] (Novice) — Find a past day in the calendar and read ITS OWN objectives.**
Start: fresh install, `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`.
Steps: `tapid toolbar.daily` → `swipe 200 700 200 200` ×2 → `tapid daily.cal.2` (Aug 3) →
`labels texts`.
- **Expected** (cross-check `derive_daily.py 2026-08-03`): card header **`Aug 3`**, `Deal #539885`;
  Bronze "Clear the deal"; Silver **"Never move more than 3 cards in a single move"**; Gold
  **"Finish one whole suit before any other suit is started"**; ⏰ line **"Same-day is earned on the
  day itself"**; `daily.play` labelled **"Play Aug 3"**; four `daily.demo.*` pills.
  **No trace of Today's card** (`Deal #608530`, "Never move more than 2 cards…", "Take at least 10 of
  every suit from the King end") anywhere — that leak is the headline bug this workflow exists for.
  `daily.clears` must NOT exist (Aug 3 unsolved on a fresh install) and no par is shown.
- **Effort bar (novice):** the calendar is the only route to a past day and needs 2 swipes from a
  sheet that opens on the streak cards. Record swipe/tap count and whether the calendar is found at
  all without being told it exists.

**TC-13.2 [novice] (Novice) — A locked future day answers the tap; today and the selection are distinct.**
*(Rewritten: the old expectation "the app gives NO feedback at all for a future-day tap" is
superseded — `daily.lockednote` now exists and locked cells carry a standing 🔒 glyph.)*
Start: as TC-13.1, with Aug 3 selected.
Steps: `find daily.cal.15` → `tapid daily.cal.15` (Aug 16, first locked day) → `find daily.lockednote`
→ `labels texts | grep "Deal #"`.
- **Expected:** `daily.cal.15`'s accessibility label is **"Aug 16, locked until that date"**; the tap
  does NOT change the day card (still `Deal #539885` / Aug 3) and instead reveals
  `daily.lockednote` = **"🔒 Aug 16 unlocks on the day itself — come back then."**; the cell shows a
  🔒 glyph even before being tapped. Every cell 15…30 (Aug 16-31) and 31…60 (September) is locked
  under the pin; `daily.cal.14` (Aug 15) is Today and selectable.
- **Watch for:** a locked note that never clears, or one that appears so far below the calendar that
  a novice never sees the answer to their own tap.

**TC-13.3 [novice] [power] (Both) — Month navigation reaches August from September and is clamped to the pool.**
*(New — `daily.cal.prev`/`daily.cal.next` shipped 2026-09-09; the prior proposal
`ux/WF-13:calendar-month-locked-no-nav` is implemented and must not be re-filed.)*
Start: as TC-13.1 (calendar on screen, August 2026 shown).
Steps: `find daily.cal.prev` → `tapid daily.cal.prev` → `find daily.cal.month` →
`tapid daily.cal.next` → `find daily.cal.month` → `find daily.cal.next` →
`labels any daily.cal | head`.
- **Expected:** the calendar opens on **August 2026** (the month containing pinned Today);
  `daily.cal.prev` is **`enabled=false`** in August and tapping it leaves the month unchanged;
  `daily.cal.next` moves to **September 2026** and is then **`enabled=false`** (Sep is the last pool
  month); September exposes `daily.cal.31`…`daily.cal.60`, all "locked until that date" under the pin.
- **Also assert:** switching months does not change the selected day card (Aug 6 selected → the card
  still reads Aug 6 / `Deal #983175` while September is displayed), and the month row does not jitter
  the sheet's scroll offset so badly that the calendar leaves the screen (August = 6 rows, September
  = 5; the layout shifts ~44 pt — re-`find` before tapping, never reuse a cached cell frame).

**TC-13.4 [power] [smoke] (Power) — Play a past day; the board HUD carries THAT day's objectives.**
Start: as TC-13.1.
Steps: `tapid daily.cal.3` (Aug 4) → `tapid daily.play` → (if a live casual game exists,
`tapbtn "Start over"`) → `find toolbar.deal` → `find hud.day` → `labels texts | grep -E "🥉|🥈|🥇"`.
- **Expected:** sheet dismisses; `toolbar.deal` reads **`Deal #625648`**; Moves 0; `hud.day` = **`Aug 4`**;
  three chips, **untruncated, no "…"**: `🥉·Clear the deal` / `🥈·Never let one suit get more than 4
  cards ahead of another` / `🥇·Win without ever using a free cell`.
- **Effort bar:** 1 tap (Daily) + 2 swipes + 2 taps from the board. The calendar is the only route —
  there is no "yesterday" shortcut and no resume affordance.
- **Also assert:** replacing a live *casual* game raises "Discard the game in progress?" with
  **Keep playing / Start over** before the challenge is dealt; a 0-move board is replaced silently.

**TC-13.5 [power] [smoke] (Power) — A constraint violation is ALLOWED, shows instantly, and Undo rolls it back.**
*(Aug 4's Gold is `cells-le` N=0 — the cheapest one-move violation in the pool.)*
Start: TC-13.4's Aug 4 board.
Steps: `labels any card.` → pick column 2's deepest card → `drag <colx> <bottom_y> 275 384` (into the
first free cell) → `find stat.moves` → `labels texts | grep 🥇` → `tapid toolbar.undo` →
`labels texts | grep 🥇`.
- **Expected:** the move is **NOT refused** (no alert, no snap-back), Moves = 1, and in the same frame
  the 🥇 chip flips **`·` → `✗`** with its label text unchanged; 🥉/🥈 stay `·`. After Undo, Moves = 0
  and 🥇 is back to **`·`** (deliberate telemetry rollback — do NOT file it).
  Evidence from exploration: `evidence/round-0-explore/wf13-5-7/wf13-aug3-hud-undo.png`.
- **Trap:** aim the drag at the column's DEEPEST card (see the fixture note) — a start point 30 pt too
  high picks up the covered card above and the violation never fires.

**TC-13.6 [power] (Power) — `no-undo` is permanently failed by Undo while achievement chips roll back.**
*(Aug 6 = dayIndex 5 = `daily.cal.5`: Silver `no-undo`, Gold `before-ace` rank 10, `Deal #983175`.)*
Start: fresh launch with the pin.
Steps: Daily → 2 swipes → `tapid daily.cal.5` → `tapid daily.play` → smart-move an Ace home
(`tapid card.<S>1` on an uncovered Ace; `sleep 1` after every smart-move — the board relayouts and a
follow-up `tapid` on a stale frame hits the wrong card) → read chips → `tapid toolbar.undo` → read
chips → make any further legal move → read chips.
- **Expected:** the Ace move is allowed and **🥇 flips to `✗`** (an Ace went home before the Tens),
  🥈 still `·`. After Undo: **🥇 returns to `·`** *and* **🥈 flips to `✗`** — and 🥈 STAYS `✗` for
  every subsequent move. Only Replay / re-entering from the Daily card clears it, and that restarts
  the attempt.

**TC-13.7 [power] (Power) — Objective-family inventory sweep (Aug 1-7 covers all thirteen families).**
Start: fresh launch with the pin; calendar on screen.
Steps: for idx 0…6: `tapid daily.cal.<idx>`, `sleep 0.6`, `labels texts`; compare **exactly** with
`derive_daily.py <date>`.
- **Expected (re-verified live this round):**

  | idx | Day | Deal # | Silver (family) | Gold (family) |
  |---|---|---|---|---|
  | 0 | Aug 1 | 691039 | Get all four Queens home within your first 29 moves (`rank-rush`) | Split every suit exactly at the Three — A-3 up, 4-K down (`split-at`) |
  | 1 | Aug 2 | 665641 | Take at least 7 of every suit from the Ace end (`end-bias`) | Move a run of 7 or more cards in a single move (`big-move`) |
  | 2 | Aug 3 | 539885 | Never move more than 3 cards in a single move (`max-run`) | Finish one whole suit before any other suit is started (`suit-sprint`) |
  | 3 | Aug 4 | 625648 | Never let one suit get more than 4 cards ahead of another (`suit-balance`) | Win without ever using a free cell (`cells-le`) |
  | 4 | Aug 5 | 850804 | Win in 115 moves or fewer (`moves`) | Send all four Aces home before any other card (`ends-first`) |
  | 5 | Aug 6 | 983175 | Win without using undo (`no-undo`) | Get every Ten onto the King-end foundation before any Ace goes home (`before-ace`) |
  | 6 | Aug 7 | 902614 | Win using free cells at most once (`cells-le`) | For every suit, send its Jack home from the King end before its Ace (`suit-top-first`) |

- **Also assert:** no label truncated or clipped (long Gold labels wrap to 2 lines); the deal number
  changes with every day; the ⏰ line is "Same-day is earned on the day itself" on all seven;
  selecting a new day never leaves the previous day's Silver/Gold text on screen.

**TC-13.8 [novice] [power] (Both) — The how-to-win pill set is exactly right per day.**
Start: calendar on screen.
Steps: `tapid daily.cal.4` → `labels any daily.demo`; repeat for `daily.cal.5`, `daily.cal.3`, `daily.cal.2`.
- **Expected:** Aug 5 (idx 4) and Aug 6 (idx 5) show **exactly three** pills —
  `daily.demo.bronze` / `daily.demo.gold` / `daily.demo.flawless`. **The missing 🥈 pill is CORRECT**
  on those days (universal Silver family `moves` / `no-undo` → no distinct silver line); the Silver
  *objective row* must still be present on the card. In the pinned reachable range 0…14 this holds
  for Aug 5, 6, 10 (idx 4, 5, 9) and nowhere else. Aug 3 and Aug 4 show all **four** pills in a 2x2 grid.
  A reachable day missing 🥉, 🥇 or 🌟 IS a bug (all 92 days carry those lines).

## WF-14 — ⏰ Same-day recognition (Both)

*(Re-explored 2026-09-09, build 1a63ce2, device `causeway-qa-3` (iPhone 17 Pro, 402x874 pt),
driven entirely through the QADriver with the **date pin**. Everything below was observed live this
pass. The prior loop's whole WF-14 fixture — the `--startDay` simulation, "there is no date
override in the app", the injector-only grace — is **superseded**: the two-day sequence is now
walked for real.)*

**Fixture / harness for every WF-14 and WF-15 case (read before the first case):**
- `Q="python3 .qa-loop/driver/qa.py <udid>"`. **Every launch names its pin**:
  `$Q launch CAUSEWAY_TODAY_OVERRIDE=<y-m-d>`. `$Q terminate` + `$Q launch <other pin>` **is** the
  day boundary — `challengeDay`/`challengeStartDay` persist across it, `todayIndex()` moves.
- **Pins used here.** Default `2026-08-15` → dayIndex 14 (Today, deal #608530, silver `max-run`,
  gold `end-bias`). `2026-08-14` → dayIndex 13 (deal #720307, silver `rank-rush` "all four Jacks
  home within your first 38 moves", gold `suit-top-first`). Under the Aug-15 pin the calendar
  exposes `daily.cal.0`…`daily.cal.14`; `daily.cal.15`+ read *"Aug 16, locked until that date"* and
  render a 🔒. Both facts verified live.
- **Win-time fixture (unchanged tools, new day numbers).**
  `node .qa-loop/tools/make_save.mjs --day <d> --tier <t> --challengeDay <d> --startDay <s>
   | grep '^{' | python3 .qa-loop/tools/inject_save.py <udid>`, then launch with the pin; the
  Auto-finish:Ask alert fires at once — drive it with `$Q tapbtn Finish` (cascade ≈ 8-10 s).
  **`--day 14`, `--day 11` and `--day 10` FAIL** with *"no finishable truncation of the flawless
  line keeps its tiers"*, so **day 13 is the flawless "today" fixture and the pin for those cases
  is `2026-08-14`.** Day 12 (Aug 13) is the banking fixture: its silver line scores 🥉🥈 only, its
  gold line 🥉🥇 only.
- **Zero-move grace fixture:** `node .qa-loop/tools/zero_move_save.mjs --day 13 | grep '^{' |
  python3 .qa-loop/tools/inject_save.py <udid>` (restored to `.qa-loop/tools/` this pass), or walk
  it for real: pin `2026-08-14` → `tapid toolbar.daily` → `tapid daily.play` → `terminate` →
  launch pinned `2026-08-15`.
- **Reset between cases:** `python3 .qa-loop/tools/inject_save.py <udid> --clear` and
  `/usr/libexec/PlistBuddy -c "Delete :causeway.daily" <plist>` (+ `:causeway.wins`), then
  `xcrun simctl spawn <udid> launchctl stop com.apple.cfprefsd.xpc.daemon`. **Verify the delete
  took** by printing the key back — see HARNESS_NOTES, the flush race eats records.
- **Use identifiers, not coordinates.** `toolbar.daily/replay/newgame`, `daily.play` (its LABEL is
  the assertion: `Play` / `Play Aug 14` / `Replay Aug 13 to improve ↻`), `daily.cal.<dayIndex>`,
  `daily.demo.<tier>`, `hud.day`. The five streak cards have **no** identifier but carry whole-card
  accessibility labels — `$Q labels any streak` returns e.g.
  `Same-day: current streak 1 days, 1 days total, best 1 days` in one call. The ⏰ line is
  `$Q labels any "⏰"` (the calendar legend's `⏰ Same-day` chip is always the last hit).
- **Alert traps.** (a) While an alert is up, `labels`/`find` return nothing useful — use `$Q alert`.
  (b) `tapbtn "New game"` is AMBIGUOUS when the confirm's verb matches a toolbar pill: it can hit
  the pill behind the alert and appear to do nothing. Tap the frame `$Q alert` reports
  (`$Q tap 275 538`).
- Sheet scroll: one `$Q swipe 200 700 200 300` brings the calendar into view; the day card grows
  when a day is banked, so re-read `daily.cal.<n>`'s frame instead of reusing an offset.

**TC-14.1 [novice] (Novice) — Five streak cards and today's unplayed ⏰ invitation.**
Start: clean records (no save, no `causeway.daily`), `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`.
Steps: `tapid toolbar.daily`; do not scroll; `labels any`.
Expected: a 3+2 grid of FIVE cards — `🔥 Play`, `⏰ Same-day`, `🥈 Silver`, `🥇 Gold`,
`🌟 Flawless` — each `0` / `day streak` / `0 total` / `best 0`, no label truncated; the legend
paragraph reads exactly *"A streak counts consecutive days holding that medal. Flawless = 🥉🥈🥇
all three earned in a single run of that day's deal. Same-day = the deal cleared on its own date —
replaying a past day never earns it."*; the card header is `Today` with `Deal #608530`, and the ⏰
line directly above `daily.play` reads **"⏰ Win today to start a same-day streak"**.
Novice bar: that legend paragraph is still the ONLY definition of ⏰ and 🌟 anywhere in the app —
record whether a first-timer can state what "Same-day" costs or pays. Baseline:
`evidence/round-0-explore/wf14-15/wf14-daily-top-fresh-aug15.png`.

**TC-14.2 [novice] (Novice) — A past day says ⏰ is out of reach, and the legend now names the pip.**
Start: clean records, pin `2026-08-15`.
Steps: `tapid toolbar.daily` → `swipe 200 700 200 300` → `tapid daily.cal.12` → `labels any "⏰"`.
Expected: the day card is headed `Aug 13`, its ⏰ line reads **"⏰ Same-day is earned on the day
itself"** (dimmer than the other branches) and `daily.play`'s label is `Play Aug 13` — nothing
claims the day can still earn ⏰. The calendar legend row lists **🥉 🥈 🥇 🌟 Flawless ⏰ Same-day**
— *(retired step: the prior TC-14.2 asserted the legend said NOTHING about the ⏰ pip; the
`⏰ Same-day` chip is present in this build, so judge only whether "Same-day" decodes to "the gold
dot in the cell's top-right corner")*.

**TC-14.3 [power] [smoke] (Power) — Winning TODAY mints ⏰ on all four surfaces at once.**
Start: clean records. Fixture: `make_save.mjs --day 13 --tier flawless --challengeDay 13
--startDay 13` injected; `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-14` (so day 13 IS today).
Steps: `alert` (must be "Ready to finish") → `tapbtn Finish` → wait ~10 s → `labels texts` →
`tapbtn Close` → `tapid toolbar.daily` → `labels any streak` → `labels any "⏰"` →
`swipe 200 700 200 300`.
Expected: overlay `Deal #720,307 · 79 moves` then the single gold line **"🌟 Flawless! 🥉🥈🥇 all in
a single run. ⏰ On time — 1-day same-day streak."** (no day prefix — it IS today); all five streak
cards read `current streak 1 days, 1 days total, best 1 days`; the card header is `Today  🌟
Flawless` with three green ✓; the ⏰ line has switched to **"⏰ Cleared on the day"**; the Aug 14
calendar cell carries its gold today-ring, a 🌟 under the date AND a small gold corner pip.
Evidence baseline: `wf15-overlay-flawless-ontime-day13.png`, `wf14-cal-aug14-star-pip.png`.

**TC-14.4 [power] (Power) — Replaying a past day never mints ⏰, however well you play it.**
Start: run TC-14.3 first (so ⏰ = 1) and stay on the `2026-08-14` pin.
Steps: inject `make_save.mjs --day 12 --tier flawless --challengeDay 12 --startDay 13`; launch
pinned `2026-08-14`; `tapbtn Finish`; read the overlay; `Close` → `toolbar.daily` →
`labels any streak` → calendar.
Expected: the overlay reads **"Aug 13: 🌟 Flawless! 🥉🥈🥇 all in a single run."** — the day is
NAMED and there is **no ⏰ clause at all**. `⏰ Same-day` stays `1 total` while 🔥/🥈/🥇/🌟 all move
to `2 total`. The calendar shows **Aug 13 with a 🌟 and NO corner pip**, Aug 14 with both.
Evidence: `wf14-overlay-pastday-no-ontime.png`, `wf14-crop-star-vs-pip-aug13-14.png`.
Any "On time" text here is a blocker-grade scoring bug.

**TC-14.5 [power] (Power) — The real two-day sequence: yesterday's untouched attempt is still live today.**
*(Replaces the prior injector-only version and its "blocked — needs a date override" escape.)*
Start: clean records.
Steps: `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-14` → `tapid toolbar.daily` → `tapid daily.play`
(label must be bare `Play` = Today) → make **no** move → `terminate` →
`launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` → `labels texts` → `tapid toolbar.daily` →
`swipe 200 700 200 300` → `tapid daily.cal.13` → `labels any "⏰"` + `find daily.play`.
Expected: after the relaunch the board still carries Aug 14's objectives HUD and `#hud.day` now
reads **`Aug 14`** (it is untitled while that challenge is today); `stat.moves` is 0. The Aug 14
day card's ⏰ line reads **"⏰ Resume your attempt today and it still counts"** and `daily.play`
reads `Play Aug 14`. Today's own card (Aug 15) is untouched and still offers the start branch.

**TC-14.6 [power] (Power) — The grace pays out, and the overlay names the day it paid for.**
Start: clean records. Fixture: `make_save.mjs --day 13 --tier flawless --challengeDay 13
--startDay 13`; **launch pinned `2026-08-15`** (so the attempt was begun yesterday).
Steps: `tapbtn Finish` → wait ~10 s → `labels texts` → `Close` → `toolbar.daily` →
`labels any streak` → `labels any "⏰"`.
Expected: overlay **"Aug 14: 🌟 Flawless! 🥉🥈🥇 all in a single run. ⏰ On time — 1-day same-day
streak."** — the grace paid for a day that is not today and the day is named (the fix for
`ux/WF-14:win-overlay-omits-the-day`). `⏰ Same-day` = 1/1/best 1, and **Today's card now reads
"⏰ Win today to keep your 1-day same-day streak"** (the fifth copy branch — the "keep" variant of
the today-unplayed line). Evidence: `wf14-overlay-grace-payout-aug14.png`.
Do NOT file the day-granularity itself (win any time on D+1 counts) — recorded product decision.
Copy promising a *midnight* deadline WOULD be a bug; none seen.

**TC-14.7 [novice] [power] [smoke] (Both) — All four board-replacing controls confirm on a ZERO-move grace.**
*(This is the repro for the open major `ux/WF-14:replay-forfeits-grace-silently`; walk all four
legs, and re-establish the grace before each leg that you let through.)*
Start: the zero-move grace of TC-14.5 (or `zero_move_save.mjs --day 13` injected, launched pinned
`2026-08-15`). `stat.moves` must be 0 and `#hud.day` `Aug 14`.
Steps and expected, each answered with `$Q alert`:
1. Daily sheet → `daily.cal.13` → `tapid daily.play` → an alert MUST appear. Observed title
   *"End your daily attempt?"*, body *"Starting this challenge re-deals the board. You began Aug
   14's challenge on the day itself — starting over makes it an attempt begun today, and Aug 14 can
   never earn ⏰ Same-day again."*, buttons `Keep playing` / `Start over`. **No "your 0 moves"
   clause** (the zero-move suppression). `tapbtn "Keep playing"` → the ⏰ line is unchanged.
2. Same card → `tapid daily.demo.bronze` → alert, same title, body leading *"Watching a demo
   re-deals the board…"*, verb `Show demo`. `Keep playing`.
3. `tapbtn Done` → `tapid toolbar.replay` → alert titled **"Give up ⏰ Same-day for Aug 14?"**,
   body *"You began Aug 14's challenge on the day itself, so finishing it today still earns ⏰
   Same-day. Starting over makes it an attempt begun today, and Aug 14 can never earn ⏰ again."*,
   verb `Replay`. `Keep playing`.
4. `tapid toolbar.newgame` → the same ⏰-titled alert, verb `New game`. Accept it (`tap` the frame
   `alert` reports — see the ambiguity trap above), then re-open Daily → `daily.cal.13`:
   the ⏰ line must have fallen back to **"⏰ Same-day is earned on the day itself"**.
Any leg that re-deals with NO dialog re-opens `ux/WF-14:replay-forfeits-grace-silently`.
Note the title split between legs 1-2 and 3-4 (see CC-14-A).
Evidence baselines: `wf14-confirm-dailyplay-zeromove.png`, `wf14-confirm-replay-zeromove-giveup.png`.

**TC-14.8 [power] (Power) — Regression guard: an untouched CASUAL board must still be one tap.**
Start: from TC-14.7 leg 4, i.e. a fresh random board, `stat.moves` 0, no `hud.day`.
Steps: `tapid toolbar.replay` → `alert`; `tapid toolbar.newgame` → `alert`.
Expected: **"no alert"** both times. A confirm here means `hasLiveGame` was widened too far and
every casual re-deal now costs a dialog — the regression the ⏰ fix must not cause.

**TC-14.9 [novice] (Novice) — Can a player FIND the live grace before spending it?**
*(Repro for the open proposal `ux/WF-14:grace-invisible-from-daily-sheet`.)*
Start: the zero-move grace of TC-14.5, pinned `2026-08-15`.
Steps: `tapid toolbar.daily`; read the whole sheet without scrolling; then
`swipe 200 700 200 300` and read the calendar; only then `tapid daily.cal.13`.
Expected/observed: the sheet opens on the **Today (Aug 15)** card and nothing on that screen
mentions the live Aug 14 attempt; the Aug 14 calendar cell carries **no in-progress mark** of any
kind; the promise exists only on the Aug 14 card, two gestures in — while the first button the
player meets, Today's `Play`, is one of the four controls that ends the grace.
Evidence: `wf14-sheet-opens-on-today-grace-hidden.png`, `wf14-crop-cal-no-inprogress-mark.png`.

**TC-14.10 [power] (Power) — Streak card and calendar pips agree across two pinned days.**
Start: clean records.
Steps: (a) pin `2026-08-14`, inject+finish day 13 flawless (TC-14.3); (b) `terminate`, pin
`2026-08-15`, inject+finish day 12 flawless with `--challengeDay 12 --startDay 14` (a past-day
replay done "today"); (c) `toolbar.daily` → `labels any streak` → calendar.
Expected: `⏰ Same-day` reads `current streak 1, 1 total, best 1` — Aug 14 earned it, Aug 13's
replay did not — while 🔥/🥈/🥇/🌟 read 2 total. Exactly ONE cell (Aug 14) carries the corner pip;
both cells carry 🌟. A pip count that disagrees with the ⏰ card's `N total` is the bug this case
exists to catch.

*Retired from the prior loop:* the old **TC-14.6** ("Two one-tap ways to destroy a live grace, one
of them silent") — the silent path no longer exists on this build; TC-14.7 (all four controls
confirm) plus TC-14.8 (casual board still silent) replace it. The old TC-14.5's
"blocked — needs a date override" escape hatch is retired with the pin.

## WF-15 — 🌟 Flawless: the tier, the streak, and "how to win flawless" (Both)

*(Same fixture header as WF-14 above. Reachable range under the `2026-08-15` pin is
**dayIndex 0…14**; `daily.cal.15`+ are locked and inert.)*

**TC-15.1 [novice] [smoke] (Novice) — The 🌟 pill is on Today, and its demo is watchable.**
Start: clean records, `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15`.
Steps: `tapid toolbar.daily` → `labels any daily.demo.` → `tapid daily.demo.flawless` →
`labels any demo.` → `tapid demo.next` → `find demo.headline` → `tapid demo.stop` →
`labels any demo.` + `labels any toolbar.finish`.
Expected: the "Show me how to win:" row is a 2x2 grid `daily.demo.bronze` `🥉 Clear`,
`daily.demo.silver` `🥈 Silver`, `daily.demo.gold` `🥇 Gold`, `daily.demo.flawless` `🌟 Flawless`.
Tapping 🌟 dismisses the sheet, re-deals that day's seed and shows `#demo.headline`
**"🌟 Flawless: 🥉🥈🥇 all three in a single run · 0 / N"** with `Next` / `Start` / `Stop` —
**paused, it must not auto-run**. `Next` advances the counter to `1 / N`. `Stop` removes the demo
bar entirely and leaves NO `toolbar.finish` pill (per WF-6, Stop re-deals). *(Retired assertion:
the prior TC-15.1 flagged the pill's words "Both objectives in one run" as contradicting the
3-medal definition; this build's headline says "🥉🥈🥇 all three in a single run" and the pill is
just `🌟 Flawless`, so the contradiction is gone — see CC-15-A.)*

**TC-15.2 [novice] [power] (Both) — The 🌟 pill is on every day the calendar exposes, including universal-Silver days.**
Start: clean records, pin `2026-08-15`, `tapid toolbar.daily` → `swipe 200 700 200 300`.
Steps: for `i` in 0…14: `tapid daily.cal.$i` then `labels any daily.demo.`; then
`find daily.cal.15`.
Expected: **all fifteen** days show `daily.demo.flawless`. `daily.demo.silver` is absent on
**exactly dayIndex 4, 5 and 9** (Aug 5, Aug 6, Aug 10 — the universal-Silver `moves`/`no-undo`
days, where a missing 🥈 pill is CORRECT); all twelve others show four pills. `daily.cal.15`
exists but its label is `Aug 16, locked until that date` and selecting it must not change the day
card. A reachable day with no 🌟 pill is a gate bug in `game.hasFlawlessLine`.
*(Walked live this pass; the 4/5/9 pattern matched the Fixture-policy prediction exactly.)*

**TC-15.3 [power] [smoke] (Power) — One flawless run lights overlay, header, streak card and calendar in agreement.**
Start: clean records; inject `make_save.mjs --day 13 --tier flawless --challengeDay 13
--startDay 13`; `launch CAUSEWAY_TODAY_OVERRIDE=2026-08-14`.
Steps: `tapbtn Finish`, wait ~10 s, read the overlay; `Close` → `toolbar.daily` →
`labels any streak` → `labels any circle` (tier ticks) → `swipe 200 700 200 300` → crop the
Aug 14 cell.
Expected: overlay `🌟 Flawless! 🥉🥈🥇 all in a single run.` (+ the ⏰ clause, TC-14.3);
`🌟 Flawless` streak card `current streak 1 days, 1 days total, best 1 days`; the day card header
is `Today  🌟 Flawless` and **all three** tier marks are `checkmark.circle.fill`; the Aug 14
calendar cell shows a **🌟 in the marker slot, replacing the three tier dots**, and the date's
baseline does not shift relative to the neighbouring cells (compare "13"/"15" in the same row —
the ⭐ is drawn in a fixed-height slot). Vertical jitter of the date is the bug this case catches.
Evidence baseline: `wf14-cal-aug14-star-pip.png`.

**TC-15.4 [power] (Power) — Banking 🥈 and 🥇 across two separate runs must NOT mint 🌟.**
*(The definitional case. Fixture day changed: **dayIndex 12 / Aug 13 / deal #616917** — its silver
line scores 🥉🥈 only and its gold line 🥉🥇 only, both verified. The old Aug-27 fixture is out of
the pinned range.)*
Start: clean records, pin `2026-08-15` (so day 12 is a past day).
Steps:
1. inject `make_save.mjs --day 12 --tier silver --challengeDay 12 --startDay 14`; launch;
   `tapbtn Finish`; read overlay; `Close`; `toolbar.daily`; `labels any streak`.
   Expected: overlay **"Aug 13: Daily challenge: 🥉 🥈 earned."** (no 🥇, no 🌟, no ⏰);
   `Silver` card `1 total`, `Gold` and `Flawless` `0 total`.
2. **Confirm the record reached disk** (`PlistBuddy -c "Print :causeway.daily"` shows
   `"silver":true`) before injecting the next save — see the HARNESS_NOTES flush race.
3. inject `make_save.mjs --day 12 --tier gold --challengeDay 12 --startDay 14`; launch;
   `tapbtn Finish`. Expected: **"Aug 13: Daily challenge: 🥉 🥇 earned."**
4. `Close` → `toolbar.daily` → `labels any streak` → `swipe` → `tapid daily.cal.12` →
   `labels any circle`/`checkmark` → crop the Aug 13 cell.
Expected: `🔥 Play` `1 total`, `🥈 Silver` `1 total`, `🥇 Gold` `1 total`, **`🌟 Flawless`
`0 streak / 0 total / best 0`**; the Aug 13 day card shows Bronze ✓, Silver ✓, Gold ✓ with **no
`🌟 Flawless` in its header**, `daily.play` reads `Replay Aug 13 to improve ↻`; and the Aug 13
calendar cell shows **three tier dots, not a 🌟**. A 🌟 here means flawless is being OR-ed across
attempts — a scoring bug and a devalued streak. Evidence: `wf15-crop-aug13-dots-not-star.png`.

**TC-15.5 [power] (Power) — 🌟 is sticky: a later, worse run never takes it away.**
*(Not walked this pass — step 2 needs a hand-played deliberate objective break. Record what you
see rather than assuming.)*
Start: run TC-15.3 (Today = Aug 14 under the `2026-08-14` pin shows `Today 🌟 Flawless`).
Steps: `tapid toolbar.daily` → `tapid daily.play` (label `Replay Aug 14 to improve ↻`) → accept
any confirm → on the board break that day's Gold deliberately (day 13's Gold is `suit-top-first`:
send any Ace home before that suit's Queen) → abandon the run (`toolbar.daily` → `daily.play`
again) → re-open `toolbar.daily`.
Expected: the header still reads `Today  🌟 Flawless`, the 🌟 streak card still reads 1, and the
Aug 14 cell still shows 🌟 — `mergeTiers` OR-accumulates and never clears. A lost 🌟 after a worse
replay is data loss.

**TC-15.6 [novice] (Novice) — Does a novice learn what 🌟 costs before chasing it?**
Start: clean records, pin `2026-08-15`, `tapid toolbar.daily`.
Steps: read only what the sheet shows — the `🌟 Flawless` streak card, the legend paragraph, the
`🌟 Flawless` pill, and (after tapping it) `#demo.headline`.
Expected/judgement: the three surfaces must agree that flawless = 🥉🥈🥇 **in one run**, and the
novice must be able to say why a `Replay to improve ↻` cannot earn it. Record any surface that
implies "two objectives", "both objectives", or that banking tiers across replays is enough.

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

*Not findings. Each needs a fresh-launch repro with evidence before it may enter a LEDGER fragment.*


HYPOTHESES ONLY — reproduce with evidence in round 1 before minting anything. All observed on
build 1a63ce2, iPhone 17 Pro / iOS 26.5, pinned date 2026-08-15.

- **CC-4A (reopen `bug/WF-4:win-overlay-seed-grouped`, minor, bug/auto).** The win overlay STILL prints
  the solved deal comma-grouped while everything around it prints it plain: overlay line
  `Deal #608,530 · 97 moves · 3:04`, its own button `Play deal #608531`, the toolbar pill
  `Deal #608530 ✓`, the Wins row `Deal #608530`. Two formats in one dialog. Evidence:
  `.qa-loop/evidence/round-0-explore/wf12-4-9/ls-win-overlay.png`, reproduced twice (landscape and
  portrait overlays). Repro: inject the day-14 silver save, launch, `tapbtn Finish`, `labels texts`.
- **CC-12A (new, suspected major for novice / minor for power, ux-design).** In landscape WITH the
  daily objectives HUD the rail holds 10 pills but its scroll window is only y 97-327: `Daily`,
  `Wins` and `How to play` are drawn at y 323/355/388 and all report `hittable=false` — i.e. three
  controls, including the only route back to the Daily sheet and to How-to-play, are invisible and
  untappable until the user scrolls a 118-pt-wide rail. The only affordance is a small grey `⌄ more`
  label below the rail. Worse, the scroll only responds to a drag that STARTS inside y 97-327: my
  first two swipes (started at y=330 and y=340, i.e. on the `⌄ more` hint itself and just below the
  last visible pill — exactly where a user who is reaching for the hidden pills would put their
  thumb) moved nothing. Evidence: `.qa-loop/evidence/round-0-explore/wf12-4-9/ls-rail-hud-clip.png`
  plus `find toolbar.wins` → `hittable=false`. Hypothesis to test in round 1: a novice in landscape
  with a daily in progress cannot find Daily/Wins/How to play.
- **CC-12B (new, suspected minor/major, ux-design, probably proposal-routed).** The Daily sheet in
  landscape puts its primary action below the fold: the visible content window is y 78-340 and
  `daily.play` sits at y=557 (~217 pt down), because the five streak cards consume the entire first
  screen. A landscape user opening Daily sees streak cards and the explanatory paragraph, no Play.
  `daily.cal.*` is at y≈746 and Export/Import at y≈1057. Evidence:
  `.qa-loop/evidence/round-0-explore/wf12-4-9/ls-daily-sheet.png`.
- **CC-12C (new, weak/low confidence, ux-design).** Landscape does not buy the player bigger cards:
  card size is 45x75 pt in BOTH orientations, while landscape leaves the tableau's lowest card at
  y=288 of a 402-pt board (~90 pt of vertical slack) and ~30 pt of horizontal slack at the right edge.
  WF-12 expects "cards are comfortably large"; they are legible, so this may be intended (the layout
  reserves 8 fan rows for growth). Verify against the ContentView landscape sizing math before
  filing anything. Evidence: `.qa-loop/evidence/round-0-explore/wf12-4-9/ls-board.png`.
- **CC-9A (new, minor, ux-design).** A deal solved three times shows no sign of it in Wins: the row
  reads "fewest 97 moves · fastest 1:45 · Sep 9" with no run count, while the Daily card for the same
  kind of repetition says "Cleared 3× · …". A user cannot tell that the two numbers come from
  different runs, which is precisely the thing the "fewest/fastest" wording is trying to convey.
  Evidence: `.qa-loop/evidence/round-0-explore/wf12-4-9/wins-row-minima.png` (recorded after 2 wins;
  a 3rd, slower win left the row unchanged).
- **CC-9B (new, weak, ux-design).** The header stat is labelled `Won` but counts DISTINCT deals
  (`WinStore.count = wins.count`): after winning deal 608530 three times it still reads `Won 1`. That
  matches "N deals solved" in Wins, so it is probably intended — but a power user replaying deals
  sees a counter that never moves. Verify intent before filing; may be wontfix by design.
- **Screen-map drift (for the orchestrator, not a finding):** the Screen map still describes the
  Deal alert as `Play / Random / Cancel` (Random was removed deliberately, ContentView.swift:283),
  the Wins field as "clamped 1…1,000,000" (it validates + disables now), and the Daily sheet as
  having 4 streak cards (there are 5).


*(HYPOTHESES from exploration — reproduce with evidence or dismiss in round 1. Evidence dir:
`.qa-loop/evidence/round-0-explore/wf13-5-7/`.)*

- **CC-13-A — The Daily sheet still snaps back to Today during a live PAST-day attempt.**
  Reuses prior open proposal **`ux/WF-13:daily-sheet-resets-to-today-midattempt`** (DailyView.swift
  `.onAppear { dayView = clampedToday }`). Reproduced this round: Daily → 2 swipes →
  `daily.cal.2` → `daily.play` (Aug 3 board, `hud.day` = "Aug 3") → one move → `tapid toolbar.daily`
  → the card is headed **"Today"** with `Deal #608530` and a bare **"Play"** button that would
  re-deal *today's* challenge over the live Aug 3 attempt. Nothing on the sheet says an Aug 3 attempt
  is in progress, and the calendar does not mark it. Screenshot:
  `wf13-sheet-resets-to-today-midattempt.png`. Getting back costs 2 swipes + 2 taps and *restarts*
  the day (Play never resumes).
- **CC-13-B — Par is only revealed AFTER you have already cleared the day.** Partial descendant of
  prior **`ux/WF-13:par-never-surfaced`**. Verified: an unsolved day (Today, Aug 4, Aug 6) shows no
  par anywhere on the card; after clearing Aug 3, `daily.clears` reads
  "Cleared 2× · fewest 96 moves · fastest 1:38 · **par 86**" (`wf5-clears-line-two-runs.png`).
  Hypothesis: par is a *target* — a number you want before the attempt, not after — so the current
  gating hides it from exactly the player who would use it. Routing would be proposal (WORKFLOWS
  currently blesses "par appears only on a solved day" as the design, so this may be dismissed).
- **CC-13-C — Calendar cells expose only their date to accessibility; earned tiers, "today" and
  the selection are visual-only.** `find daily.cal.2` on a day cleared with 🥉+🥇 returns
  `label=Aug 3` — identical to unsolved `daily.cal.3` (`label=Aug 4`) and to Today
  (`daily.cal.14` → `label=Aug 15`). Locked cells DO carry state ("Aug 16, locked until that date"),
  and `DailyView.swift:606-637` draws tier dots, a 🌟, a ⏰ pip and the today ring purely as shapes.
  Hypothesis: VoiceOver users cannot tell a solved day, today, or the selected day from any other,
  and no test can assert the calendar's medal rendering. Type bug/ux-design, small scope, minor.
- **CC-13-D — `bug/WF-7:deal-confirm-swallowed-by-double-tap` may no longer reproduce.** The 0.1 s
  `asyncAfter` in `ContentView.requestDealFromDismissal:358` is still there, but the geometry that
  made it dangerous is gone on this build: with a live 1-move game, `doubletap` on the deal alert's
  Play (275,392) and on the Wins Play (357,191) BOTH left the "Discard the game in progress?" confirm
  intact with its buttons at y=493, and `toolbar.deal`/`stat.moves` unchanged. Round 1 should re-run
  the original repro verbatim before flipping it to fixed — the prior round measured Play at
  (275,527), i.e. 10 pt from the destructive button, so something about the alert's layout changed
  and the finding may only be *masked*.
- **CC-13-E — The replace-a-live-game copy uses "challenge" in two senses in one breath.**
  Observed: "Starting this challenge re-deals the board, so your 1 move and your time will be
  discarded. **This game is not a challenge**, so there is no way back to it." Hypothesis: a novice
  reads the second sentence as contradicting the first. Minor copy fix; ux-design, small scope.
- **CC-13-F — The past-day entry point is two full screens below the fold.** On a fresh install the
  Daily sheet opens on five streak cards + explainer; `daily.cal.month` sits at y≈840 (clipped at the
  screen edge) and the day cells only materialise after **two** `swipe 200 700 200 200`s. WF-13's
  entire workflow (and now month navigation) hangs off a control a novice may never scroll to.
  Hypothesis: structural — would be routed proposal. Measure it in round 1 as a novice tap/scroll count.
- **CC-13-G — Month navigation leaves the day card and the calendar out of sync.** With Aug 6
  selected, `tapid daily.cal.next` shows September while the card above still reads Aug 6 /
  `Deal #983175`, and no cell in the visible month is highlighted. Hypothesis: a novice reads the
  card as belonging to the month on screen. Minor; may well be intended (selection persistence is
  useful) — dismiss if the human disagrees.


- **CC-14-A (new, minor, ux-design/auto).** *Hypothesis:* the grace confirm has TWO different
  titles depending on which control you touched, and only half of them name the ⏰ stake in the
  title. The board's `toolbar.replay` / `toolbar.newgame` give **"Give up ⏰ Same-day for Aug 14?"**;
  the Daily sheet's `daily.play` and `daily.demo.<tier>` give **"End your daily attempt?"** with the
  ⏰ sentence buried at the end of a 3-line body (`DailyView.swift:55` hardcodes the title, while
  `ContentView.swift:375` branches on `graceLive`). WORKFLOWS' 2026-09-09 paragraph asserts the
  ⏰ title fires from *all four* board-replacing controls — it does not. Evidence:
  `wf14-confirm-dailyplay-zeromove.png` vs `wf14-confirm-replay-zeromove-giveup.png`.
- **CC-14-B (reproduces; prior id `ux/WF-14:grace-invisible-from-daily-sheet`, open proposal).**
  *Hypothesis:* still exactly as filed — with a live grace the Daily sheet opens on the Today card,
  says nothing about the live Aug 14 attempt, and the Aug 14 calendar cell carries no in-progress
  mark; the promise lives only on that day's card, two gestures away. Evidence:
  `wf14-sheet-opens-on-today-grace-hidden.png`, `wf14-crop-cal-no-inprogress-mark.png`.
  Verify in round 1 and reuse the id; do not mint a new one.
- **CC-14-C (new, minor, ux-design/auto — accessibility).** *Hypothesis:* every calendar cell's
  accessibility label is the bare date (`daily.cal.13` → `"Aug 14"`, `daily.cal.15` →
  `"Aug 16, locked until that date"`), so the three marks the calendar exists to convey — the tier
  dots, the 🌟 and the ⏰ corner pip — are invisible to VoiceOver: a screen-reader user cannot tell
  a flawless day from an unplayed one. (Second, cheaper half: the streak cards announce
  `"current streak 1 days, 1 days total, best 1 days"` — unpluralised.) Evidence: the
  `labels any daily.cal.` dump in this fragment's TC-15.2 walk.
- **CC-14-D (prior id `ux/WF-14:win-overlay-omits-the-day` — looks FIXED).** The win overlay now
  prefixes the day whenever the finished challenge is not today: **"Aug 13: 🌟 Flawless! …"** and
  **"Aug 14: 🌟 Flawless! … ⏰ On time — 1-day same-day streak."**, and stays unprefixed for a
  same-day win. Round 1 should re-run the repro and mark it fixed, not re-file it. Evidence:
  `wf14-overlay-pastday-no-ontime.png`, `wf14-overlay-grace-payout-aug14.png`.
- **CC-14-E (prior id `ux/WF-14:replay-forfeits-grace-silently` — looks FIXED).** On a genuine
  zero-move grace (walked as a real two-day sequence, not injected) all four controls confirmed:
  `daily.play`, `daily.demo.bronze`, `toolbar.replay`, `toolbar.newgame`; the "your 0 moves" clause
  is correctly suppressed; and the regression direction is clean — an untouched CASUAL board still
  re-deals with no dialog from either `toolbar.replay` or `toolbar.newgame`. Round 1 must walk
  TC-14.7 + TC-14.8 before flipping it to fixed.
- **CC-15-A (prior concern — looks FIXED, do not re-file).** The 🌟 demo headline now reads
  "🌟 Flawless: 🥉🥈🥇 all three in a single run"; the "Both objectives in one run" wording that
  contradicted the 3-medal definition is gone from the pill and the headline.
- **CC-15-B (harness, not a product concern — recorded so round 1 does not misread it).** A
  Silver banked in run 1 appeared to VANISH after run 2 in my first pass (Silver card fell to
  `0 total`). It was a **fixture artifact**: `inject_save.py` re-writes the whole plist and can
  race the app's not-yet-flushed `causeway.daily`. Re-run with a verified flush, the merge is
  correct (`silver:true, gold:true, flawless:false`). Do NOT file a data-loss finding on this
  without proving the record was on disk before the injection.
