# Review-loop final report — "Show me how to win" for Daily deals (web + iOS)

**Result: CONVERGED** (round 3 of a 5-round budget). 0 open blockers/majors/minors.

Scope: commits `e8fdf9d` (solver path reconstruction + offline solution builder + web playback) and
`3a0940e` (iOS mirror), plus the loop's own fixes `67f6fa0` and `cb08a91`. The feature bakes each
certified daily seed's winning line into `data/daily-solutions.json` and animates it on demand as a
demonstration (assisted, input-locked, never scored).

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 3 | 3 | 0 | -3 | continue |
| 2 | 0 | 1 | 0 | 0 | 1 | 0 | -1 | (cold pass found F4) |
| 3 | 0 | 0 | 0 | 1 | 0 | 0 | +0 | converged |

Round 1 seed filed F1–F3 (a blocker, a major, a minor) — all fixed and validated same round. Round 2
was a cold confirmation pass that surfaced a new major (F4). Round 3 fixed F4 and re-validated clean.

## What the review caught — this is why the loop earned its keep

The feature's happy path shipped with a **blocker** and, uncovered only on the second pass, a
second **major** — both in the demo teardown seam, exactly where the animated-playback design adds
new lifecycle edges:

- **F1 [BLOCKER] — iOS `deal(seed:)` wasn't the demo chokepoint.** `stopDemo()` had been sprinkled
  onto some callers but not `deal()` itself, so `playChallenge` and the Deal-number alert could
  re-deal mid-demo; a queued `demoStep` then ran `applyDemoToken` against the fresh board —
  `removeLast` on an emptied column **traps**, or a stale banner strands `demoing=true` (input
  locked). Fixed by making `stopDemo()` the first statement of `deal(seed:)` — one chokepoint for
  every deal path.
- **F2 [major] — web `deal()` had the same gap.** The `'n'` shortcut, seed modal, and wins-play
  re-dealt without stopping the demo; the pending `setTimeout` step then threw a `TypeError`
  (`pop()===undefined`) inside the timer *before* rescheduling or clearing `demoing`, permanently
  locking input. Fixed identically (`stopDemo()` first in `deal()`).
- **F3 [minor] — a mid-demo board was persisted** as a resumable casual game (backgrounding runs the
  normal save hooks; `isWon()` is false mid-demo). Fixed: web `saveGame` and iOS `persist` skip while
  `demoing`.
- **F4 [major, round 2] — web `stopDemo()` couldn't dismiss a *completed* demo.** Its guard
  `if(!demoing && !demoTimer) return;` early-returned once the line finished (both falsy, bar still
  shown), so the "Done" button and every later `deal()` teardown left the "That's one way to win…"
  banner rendered above the board for the rest of the session. Fixed to also fire when the bar is
  shown, mirroring iOS's `demoing || demoDoneMessage != nil`. (Round 1's live test only exercised
  *mid*-demo teardown, where `demoTimer` is non-null — which is exactly the case the old guard
  already handled; the completed-state path was untested until the round-2 cold read.)

Verified clean (not findings): token-replay fidelity across the three replayers (solver `applyMove`,
web + iOS `applyDemoToken`) and deal alignment; `withPath` doesn't change `par`; the builder
re-simulates all 366 lines to a verified win; scoring isolation (no demo routes through
`commitMove`/`recordWin`, `challengeDay` stays null, no win overlay, wins/dailyStore untouched); iOS
`demoGen`/`[weak self]` step invalidation; and the "complete but not won" end board doesn't trip
auto-finish or resurrect on restore.

## On-device / in-browser verification (this session)

- Solver: 366/366 solutions generated and re-simulated to wins by `build-solutions.mjs`.
- Web: full demo of deal 10001 clears the board in 83 moves; wins + daily store unchanged; no win
  overlay. Re-dealing mid-demo (`deal(777)`) tears down cleanly with no errors. The completed-banner
  fix dismisses via both the Done button and a fresh deal, and no-ops safely otherwise.
- iOS: demo of deal 10002 animates to a cleared board in 78 moves, ends with the "tap Replay" banner,
  **Won stays 0** (unscored); Done dismisses the bar. Builds clean on the iPhone 17 Pro simulator.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The demo teardown seam — `deal()`/`stopDemo()` on both platforms (commits `67f6fa0`, `cb08a91`).**
   `deal()` is now the single point that cancels a running/finished demo. The invariants: a queued
   step (web `setTimeout`, iOS `asyncAfter`) must never apply a token to a board it wasn't computed
   for, and the banner must always be dismissable. **Play-test:** start "Show me how to win", then
   mid-line tap New game / Replay / Deal# / Daily→Play / press `n`; and separately let it finish and
   tap Done, then Replay — confirm no stuck banner, no locked input, no crash.
2. **The trusted-solution stance.** Playback applies baked tokens directly to the board (not through
   the move validators), so a bad token would desync silently. The build-time re-simulation
   (`build-solutions.mjs verify()`) is the guard; it passed for all 366 seeds, but any future pool
   growth must re-run it.
3. **Assisted = unscored.** Confirmed a demo never banks Bronze/Silver/Gold and never records a win.
   Worth one on-device check that watching a solution then playing the same daily still scores your
   own attempt normally.

## Verdict
Converged: the feature shipped with two real teardown defects (a mid-demo re-deal crash and a
permanently-locked input path) plus a persistence leak, and a second cold pass caught a
non-dismissable completed banner — all fixed, independently re-validated, no regressions. Full web +
iOS parity for "Show me how to win."
