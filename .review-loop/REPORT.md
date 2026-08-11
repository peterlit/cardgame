# Review-loop final report — Causeway (tap/drag refactor)

**Result: CONVERGED** (round 1 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, 0 open minors; nothing newly introduced left open.

Scope: the tap/drag interaction refactoring — single tap = smart-move, drag = place exactly —
across commits `db2dd49..HEAD` (web `2b7703a`, iOS native-draggable `f334972`, iOS manual-gesture
`62be89c`, docs `e183317`). Loop start SHA: `e183317`. Fixes landed in `bfb64c8`.
(Prior OOM loop archived at `.review-loop/REPORT-oom.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

(Seed review filed F1–F4; the same round's implementer pass fixed F1/F2/F3 and deferred F4, so the
round-1 metrics row nets to zero open.)

## What the review established

**The headline fear did not materialize — verified, not assumed.** The reviewer traced both
platforms and confirmed no tap/drag path can produce an illegal move, move the wrong run, drop an
internally-invalid run, or lose/duplicate a card:
- iOS `Game.drop` stages `selection = source`, dispatches to a `tryMove*` validator, then clears
  `selection` on **every** path (success via `commit()`, failure explicitly) — no stale-selection
  reuse, fully synchronous, no re-entrancy. `isSeqHead` + `canStackTableau` + `maxMovable` re-guard
  at drop time; cell/foundation targets enforce single-card.
- Web `dragUp` re-stages `selection` and re-validates through `tryDest*` against current state, so
  even an autoplay chain firing mid-drag yields at worst a legal shorter move or a snap-back.
- Smart-move priority, run-drag legality, same-column rejection, and buried-card (tappable but
  non-draggable) behavior are **at parity** between web and iOS. The removed web M5 double-move
  guard is correctly obsolete under the one-`smartMove`-per-tap pointer model. Web listener
  add/remove is symmetric; `elementFromPoint` null / dragged-element cases handled.

## Findings (all resolved)

- **F1 [major] — FIXED** (`ContentView.swift` `cardGesture.onEnded`). iOS had no concurrency guard:
  a second finger tapping card Y while finger A dragged head X fired a stray `smartMove(Y)` and
  cleared A's in-flight `drag` (could net two moves from one intended drag). Fix: `guard drag == nil
  || drag?.source == spot else { return }` at the top of `onEnded`. Reviewer verified all four paths
  (tap-on-draggable, tap-on-buried, real drag end, second-finger release) still behave and the guard
  swallows nothing legitimate. Moves were individually validated, so this was recoverable, not a
  blocker.
- **F2 [minor] — FIXED** (`.onChange(of: game.moveCount)` + `dragSourceHoldsCard`). A drag whose card
  is torn down mid-gesture by an async autoplay step never receives `onEnded`, leaving `drag` stuck
  at an elevated `zIndex`. Fix clears `drag` **only** when its source no longer holds a card, so an
  unrelated autoplay step during a legitimate drag can't cancel it. Reviewer confirmed autoplay
  mutates the board before `moveCount++` and that normal drops null `drag` synchronously before the
  `onChange` runs — no wrong-cancel, no double-processing.
- **F3 [minor] — FIXED** (`CardView.swift`, `index.html`). Dead selection-highlight residue
  (`CardView.selected` + its stroke/lift; the web `.card.sel` CSS) left over from removing the
  select model. Removed on both platforms; grep confirms no remaining `selected:`/`.sel`/`isSelected`
  reference, and the unrelated `Game.selectedCards()` is untouched.

**Disputed (agree-to-disagree):** none.

## Deferred (accepted)
- **F4 [minor] — WONTFIX-ACCEPTED → BACKLOG.** Suspected cosmetic drop "hitch" on iOS: `.offset`
  (drag follow) zeroes in the same `withAnimation` as the `matchedGeometryEffect` relocation, so a
  legal drop *may* jump finger→old-slot→glide rather than fly from the finger. Unconfirmed on device;
  a real fix reworks the verified-working drag rendering. Declining and deferring was judged correct
  rather than destabilize a shipped-feeling interaction. Logged in `BACKLOG.md`.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The whole refactor diff `db2dd49..HEAD`** — the substantive change. Two same-family agents
   agreeing it's correct is exactly what this loop can't fully de-risk. The move-correctness argument
   rests on *drop-time re-validation*; if you ever change `tryMoveToTableau/Cell/Foundation` or
   `drop()`'s `selection` staging, that guarantee must be re-checked.
2. **`ContentView.swift` `cardGesture` (F1 guard) + `.onChange(of: moveCount)` (F2 self-heal), commit
   `bfb64c8`.** Both fixes hinge on SwiftUI gesture/`onChange` *ordering and delivery* under
   `minimumDistance: 0` — the one thing a code review can't run. **Verify on device:** (a) two fingers
   on two cards at once doesn't double-move or strand a drag; (b) a card autoplayed out from under a
   moving finger resets its column `zIndex` cleanly and doesn't leave a floating ghost.
3. **iOS drop hit-testing via `DropZonesKey` frames in the `"board"` coordinate space
   (`ContentView.swift`).** Was live-verified on the iPhone 17 Pro simulator this session (tap,
   single drag, illegal snap-back, 2-card run drag). Re-confirm on a physical device that
   `dropZones` isn't stale right after New Game / a deal change (drop onto a just-relaid column).
4. **F4 drop-animation hitch** — the one known-unverified cosmetic item; eyeball a legal drop on
   device and decide if it's perceptible before pulling it off the backlog.

## Verdict
Converged round 1: no blockers/majors/minors open. The refactor is move-correct and at web/iOS
parity by construction (drop-time re-validation on both platforms); the three real defects (one
concurrency major, two minor) are fixed and re-validated; one cosmetic, device-only item is
deferred. Residual risk is entirely in SwiftUI gesture timing / device feel — flagged above for a
human device pass, not code.
