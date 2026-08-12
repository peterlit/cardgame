# Review-loop final report — Causeway (deferred win overlay)

**Result: CONVERGED** (round 1 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, no new blockers/majors introduced. One minor
(F3, a test-gap) remains open and is filed to BACKLOG.md.

Scope: commit `f1ef1f1` — "hold the win overlay until the last auto-finish card lands" (deferring
`onWin()` by ~0.32–0.38s so the win popup doesn't cover a still-animating foundation). Reviewed
`e19754b..HEAD`. Loop start SHA: `f1ef1f1`. Fixes landed in `7f45ea5`.
(Prior auto-finish loop archived at `.review-loop/REPORT-autofinish.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 1 | 0 | 0 | 0 | +0 | converged |

(Seed review filed a blocker F1 + a major F2; the same round's implementer pass fixed both, and the
reviewer opened a new minor F3. Metrics converge — no open blockers/majors, F1/F2's fixes introduced
no new blocker/major.)

## What the review caught (this is why the loop earned its keep)

The one-line "hold the overlay" change had **two real bugs**, both found and fixed this round:

- **F1 [BLOCKER, iOS] — FIXED.** During the ~0.38s deferred-win window the board is complete but
  `won`/`finishing` are both false, and `autoFinishWouldWin()` returns true on an already-complete
  board — so `canOfferFinish` was true and the **"Finish" pill re-appeared over the solved board**.
  Tapping it (or toggling `autoFinishMode`) called `runAutoFinish()`, which bumped `finishGen`,
  which made the pending `onWin()` block bail — **the win was permanently discarded** (no overlay,
  no recorded win, board not persisted). Root cause: iOS gated re-entry on the *flag* `!won` while
  web gated on the *position* `!isWon()`. Fix: added `!checkWin()` to iOS `canOfferFinish`,
  `runAutoFinish`, and `maybeAutoFinish`, matching web's position-based gate (canonical
  `autoFinishWouldWin` + its drift guard left untouched). Reviewer audited every `finishGen` bump
  site and confirmed the pending `onWin` now fires and a normal finish still completes.
- **F2 [MAJOR, both] — FIXED.** During the delay the board was complete but the win was neither
  recorded nor persisted (`persist()`/`saveGame()` refuse a complete board), so a **process kill /
  tab close inside the ~0.32–0.38s window lost the win + best time** — a regression, since `onWin()`
  used to fire synchronously. Fix: split out `recordWin()` (stop clock, clear saved game, write the
  win/best-time) and call it **synchronously at the winning move**, guarded once
  (`winRecorded`/`pendingWin`); the timer now defers **only** the overlay presentation. Reviewer
  verified exactly-once recording across all win entry points, no `moveCount`/`clock` off-by-one,
  correct flag reset on deal/restore, and that record-then-undo is coherent (the board genuinely
  reached all-52-home; the resumable save is re-persisted after the undo).

**Disputed (agree-to-disagree):** none.

## Open findings

- **F3 [minor] — OPEN → BACKLOG (`AF-test`).** The win-record / deferred-overlay / re-entry-gate
  logic has zero automated coverage; both bugs above were timing bugs invisible to the current Node
  suite, and there is no iOS test target. Suggested: a headless test asserting `recordWin`
  idempotency, undo-during-beat records exactly once, and the three gates reject a complete board.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The deferred-win + synchronous-record split — iOS `Game.swift` `finishStep`/`recordWin`/`onWin`/
   `winRecorded`/`!checkWin()` gates and web `stepFinish`/`recordWin`/`pendingWin` (commits `f1ef1f1`,
   `7f45ea5`).** This is subsecond async state with a durable side effect — the exact class of thing
   the loop reasons about but cannot execute. **On device, verify:** (a) auto-finish to a win, then
   confirm the win is in Wins with the right time; (b) **kill the app during the ~0.38s beat** and
   confirm the win still shows in Wins on relaunch (F2's whole point); (c) undo *during* the beat and
   confirm no overlay, no wedge, the board is playable, and the seed still counts as won.
2. **`record-then-undo` semantics (F2b).** A win recorded, then undone in the beat, stays recorded.
   That is the intended durability tradeoff (you can't have "survives a kill" and "undo un-records"
   at once), but it's a behavior nuance a human should bless. Minor residual: `winRecorded` isn't
   reset on undo, so a *faster* re-solve of the same seed in the same session won't lower the stored
   best time — accepted, `WinStore` keeps `min` anyway.
3. **The absent test coverage (F3).** Two serious bugs in a 7-line change slipped past CI because the
   timing logic is untested. Until `AF-test` lands, this whole area is human-verify-only.

## Verdict
Converged round 1: the "hold the overlay" change shipped with a blocker and a major; both are fixed
and independently re-validated (position-based re-entry gating on iOS to match web; durable win
recorded synchronously with overlay-only deferral). Residual risk is a genuine test gap (F3) and
device-only async timing — flagged above for a human pass.
