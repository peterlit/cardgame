# Review-loop final report — Daily Challenges web integration

**Result: CONVERGED** (round 1 of a 5-round budget). 0 open blockers/majors/minors.

Scope: wiring the shared daily core into the web app (`index.html`) — commit `f71a8aa`. Loop start
SHA `f71a8aa`; fixes in `f87154e`. (Prior loops archived under `.review-loop/*-*.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

(Seed review filed F1–F6 — 2 blockers, 2 major, 2 minor; all fixed and validated the same round.)

## What the review caught — this is why the loop earned its keep

The integration shipped with **two blockers**, both in the telemetry/robustness seams:

- **F1 [BLOCKER] — undo didn't roll back challenge telemetry.** `snapshot()`/`undo()` restored the
  board and `moveCount` but not `telem.foundationOrder`/`cellUses`, so exploring with undo — a
  first-class, app-encouraged mechanic ("Replay to improve") — polluted the objective stream: a
  deserved Gold/Silver could be *denied* (an undone early non-ace still sat in `foundationOrder`; an
  undone cell park kept `cellUses` high), and a count objective could be *inflated*
  (home-a-King-down / undo / redo appends duplicate entries → false `down-openers-20`). Fixed by
  recording `foundationOrder.length` + `cellUses` in the snapshot and truncating/restoring on undo
  (both append-only; `undos` intentionally stays failed).
- **F2 [BLOCKER] — the Daily overlay crashed** (null deref) whenever `todayIndex()` fell outside
  `[0, pool.length)` — before the 2026-08-12 epoch (a user west of UTC at launch), or after the
  366-day horizon. Fixed by clamping `dailyView` and rendering a "no challenge available" card
  instead of dereferencing a null challenge.
- **F3 [major]** — autoplay persisted telemetry one card behind the board (`saveGame` inside
  `autoplayOneStep` ran before the caller's `recordHomed`), so a reload mid-autoplay-chain saved a
  foundation with no `foundationOrder` entry → wrong tier on eventual win. Fixed by moving
  `recordHomed` into `autoplayOneStep` (before its save) and removing the now-duplicate call.
- **F4 [major]** — cell→cell relocation over-counted `cellUses`, wrongly failing `no-cells`/
  `cells-le-N`. Fixed (only count a genuine tableau→cell park).
- **F5 [minor]** — widened the daily drift guard to pin the previously-unpinned checkers and the
  `EPOCH_DAYS`/`dayIndexFor` constants.
- **F6 [minor]** — the live-HUD `objViolated` for `down-openers-20` didn't flag failure after the
  20-move deadline; now matches the authoritative checker.

Core telemetry correctness in forward play, `challengeDay` lifecycle, once-only scoring, old-save
compatibility, and no global-name collisions were all verified clean. 52/52 tests (engine 24 +
solver 10 + daily 18, incl. 3 drift guards).

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The telemetry seam — `recordHomed`/`snapshot`/`undo`/`autoplayOneStep` (commits `f71a8aa`,
   `f87154e`).** It reconstructs the foundation-order stream by diffing snapshots; the invariant is
   "at most one card homed per move." If a future change ever homes 2+ cards in one move, the
   `moveIdx` and truncation logic need revisiting. **Play-test on device:** win a daily with heavy
   undo/redo and with safe-autoplay on, and confirm the awarded tiers match what you actually did.
2. **The trusted-telemetry stance.** Scoring believes the app's reported stream (no re-simulation) —
   fine for a local, single-player, no-server game, but it means a telemetry bug shows up as a wrong
   tier, not a crash. The drift guard + these fixes are the safety net.
3. **Out-of-range dates (F2).** Confirmed fixed, but the launch-day / timezone boundary is exactly
   the kind of thing to eyeball once on a real device around the epoch date.

## Verdict
Converged: the web integration shipped with two real blockers (undo telemetry pollution; an
out-of-date-range overlay crash) plus two majors and two minors — all fixed and independently
re-validated, no regressions, 52/52. iOS mirror still pending (BACKLOG DAILY).
