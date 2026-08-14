# Review-loop final report — side-by-side landscape layout + L↔R swap (iOS)

**Result: CONVERGED** (round 1, all findings closed). 0 open blockers/majors/minors.

Scope: commit `ea5f8d2` — the landscape redesign (foundations · tableau · free cells, side by side)
plus swapping free cells and foundations left↔right in both orientations. Fixes in `faa59ce`.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 2 | 2 | 0 | -2 | converged |

## What the review confirmed sound (the headline risks)

The two things most likely to break in a layout this different — **drag hit-testing** and **z-order** in
the new side-by-side arrangement — are correct by construction, and the reviewer proved why:

- **Drag targeting is layout-agnostic.** Every drop target reports its rect via
  `GeometryReader.frame(in: .named("board"))`, and the card `DragGesture` resolves by testing the
  finger's `v.location` (same "board" space) against those rects. Moving the panels beside the tableau
  changes where the rects land but keeps both operands in one coordinate space, so tableau→foundation
  (now far left), cell→tableau (cell now far right), and tableau→cell all still resolve correctly. The
  three panels never overlap horizontally, so `.first(where:)` can't mis-pick.
- **Z-order is cosmetic only.** Drop targets are passive probes; the gesture lives on the *dragged*
  card, so z-order can't affect whether a drop lands. And the elevation is still right: a dragged cell
  raises `freeCellsSide` above everything; a dragged run raises `tableauArea` above both panels; no
  `.clipped()` cuts a floating card.

Portrait was confirmed byte-identical except the intended L↔R swap; `runOffset`/drag self-heal are
layout-agnostic; `boardStack` fully removed with no stale references.

## What the review caught

- **F1 [minor] — landscape `availH` underestimated the chrome.** The height budget used a fixed
  `- 116`, ignoring the toolbar wrapping to two rows AND the `DailyHUD`/`demoBar` that adds an extra
  bar above the board during a daily challenge or the win-demo — so a moderately long column could
  clip off the bottom (its bottom, draggable card off-screen) earlier than the documented known-minor,
  especially with the HUD showing. **Fixed:** `availH` now subtracts a 50pt HUD bar when one is present
  and carries a bit more base margin (`geo.height - 124 - hudBar`), keeping an ~11-card column on-screen
  even with the HUD. The fresh-deal on-device check hadn't surfaced this (short columns, no HUD).
- **F2 [minor] — stale comment.** The header comment said "11-across (2+8+1)"; the layout and formula
  are 15-across (4 foundation + 8 tableau + 3 free-cell). Corrected.

## On-device verification (this session)

Simulator restored (fresh dedicated `Causeway-Dev`, isolated from the parallel session). Verified both
orientations render on a fresh deal: portrait shows foundations-left / free-cells-right and a tapped
Ace smart-moves to the (now left) foundation; landscape shows the side-by-side layout with the tableau
tops fully visible and well-sized cards. (A real landscape *drag-and-drop* wasn't exercised — see the
skim list — but the mechanism is the same board-space hit-test used everywhere, confirmed above.)

## HUMAN SKIM LIST

1. **One real landscape drag on device.** Everything says it works (layout-agnostic hit-testing), but
   the only thing not physically exercised this session is a landscape drag-and-drop: drag a tableau
   run onto a left-side foundation, and drag a right-side free-cell card onto a tableau column.
2. **Landscape with a long column + the daily HUD showing** — the F1 fix targets exactly this; worth an
   eyeball that the bottom card of a ~11-card column stays reachable while a daily challenge's objective
   bar is up.

## Verdict
Converged: a substantial landscape redesign whose two riskiest seams (drag targeting, z-order) are
sound by construction, with one real height-budget minor and a stale comment fixed. Full on-device
render verification in both orientations; a landscape drag is the one thing left to eyeball.
