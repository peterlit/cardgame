# Review-loop final report — RL-1..4 residual fixes (uniform whole-board portrait card sizing)

**Result: CONVERGED** (round 2): **0 open findings of any severity** — every finding fixed or
justified-wontfix. 14 tracked total across seed + 2 rounds.

Scope: commit `e77f664` (RL-1..4 — whole-board uniform card shrink per the user's decision,
conditional tableau centring, hardened F/C token pins, iOS demo-exit guard pins), then the
loop's fix commits `40e9f36` (round 1) and `787fec9` (round 2).

## Why it stopped

Round 2 closed all three remaining findings and introduced none. Reviewer's closing line:
"Nothing for the implementer to act on next round."

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 1 | 2 | 1 | 2 | 0 | -1 | continue |
| 2 | 0 | 0 | 0 | 3 | 0 | 0 | +3 | converged |

(Seed = round 0 against `e77f664`: verified RL-1/2/3 fixed, RL-4 partial, plus 2 new minors.)

## What the loop caught and fixed

- **Height-latch pulse (seed minor → fixed round 1).** The one-shot-fit height input
  (`bg.size.height`) is card-size-independent but not *constant*: the conditional Finish pill
  can add/drop a toolbar FlowLayout row mid-deal and the demo bar's wrapping headline changes
  per step — with the column latch holding a shrink alive, that wobble would rescale the whole
  board up and down. Fixed with `latchedBoardH`: the per-deal minimum board height, monotone
  like the column latch.
- **Latch invalidation bug (round-1 MAJOR → fixed round 2).** Both latches reset only in
  `.onChange(of: moveCount)`, which fires on *transitions* — a deal→deal hop where moveCount
  never leaves 0 (demo Stop before Start; Daily → Play → immediate New game) left a fresh deal
  permanently sized for chrome no longer on screen. Fixed at the model level: `dealGeneration`
  counter bumped in `Game.deal()` (the single chokepoint every deal path routes through);
  ContentView resets both latches on its change. Reviewer verified the chokepoint claim by
  grepping every `tableau =`/`moveCount = 0` write site.
- **Rotation/keyboard latch poisoning (round-1 minor → fixed round 2).**
  `.onChange(of: geo.size)` on the root reader resets the height latch on any container-size
  change (rotation intermediates, the deal-alert keyboard shrinking the safe area). Reviewer
  proved chrome wobble cannot move root `geo.size`, so this can't reintroduce the pulse.
- **G/T/X token pins (seed minor → fixed rounds 1–2).** The RL-1 fix anchored F/C but left
  G/T/X mutable: five single-token mutations kept the suite green. Now all five iOS case
  bodies and all five web case bodies are pinned contiguously; both sides mutation-verified
  (9 distinct mutations, each fails exactly the right test).

## Wontfix (justified, recorded)

- `layout/ContentView.swift:tableau-shrink-detaches-from-upper-row` — the residual
  "whole board re-flows on a new tallest-column maximum" is the **user's explicit choice**
  (uniform card size across foundations/free cells/tableau); bounded to one re-flow per new
  maximum per deal by the monotone latches.
- `dataloss/DailyView.swift:show-solution-discards-in-progress-game` — pre-existing, out of
  scope; tracked as backlog DV-1.

## Disputed items

None.

## HUMAN SKIM LIST — read these diffs

1. **`787fec9` — Game.swift `dealGeneration` + ContentView latch resets.** A new @Published
   on the model exists purely for view-layer cache invalidation. Look here because it's the
   invariant everything else leans on: if any future deal-like path bypasses `deal()`, stale
   latches return silently.
2. **`e77f664` — `portraitFitCardW` + the outer/inner GeometryReader restructure.** The
   whole-board fit formula (3·aspect + 0.53·(n−1) units, 32pt chrome constant) was hand-checked
   by both agents but never screenshot-verified; the 32pt constant is derived, not measured.
3. **`40e9f36`/`787fec9` — the two-latch mechanism (`shrinkLatchCount`, `latchedBoardH`).**
   Three @State caches + three reset triggers (deal generation, moveCount 0, geo.size) now
   govern portrait card size. It's correct per review, but it's the most stateful this view has
   ever been — worth a skim for whether chrome stabilisation (reserving the Finish pill slot)
   would let most of it be deleted later.
4. **`787fec9` — tests/ios-parity.test.mjs web T/X pins.** Pins are normalized-substring
   matches against minified-ish inline JS; they were mutation-verified today, but any web
   refactor will trip them — that's by design, just know the failure mode.

**Verification run:** `xcodebuild` BUILD SUCCEEDED every round (reviewer round 2 built from
clean derived data independently); `npm test` 68/68 every round; 9 pin mutations exercised.
**Not run:** simulator/on-screen check of shrink behavior — the next qa-loop round should
re-run TC-2.3 (tall column, now expecting a uniform whole-board shrink at ~15 cards on 4.7")
and the WF-6 demo cases.
