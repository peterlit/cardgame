# Review-loop final report — Replay button + Undo icon (web + iOS)

**Result: CONVERGED** (round 1, clean seed review — 0 findings). 0 open blockers/majors/minors.

Scope: commit `1132c8c` — a "Replay" button that restarts the current deal from scratch (preserving
the daily-challenge context if one is active) and a recognizable curved/left-bent arrow icon on the
Undo button, on both the web app and the iOS app.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

## What the review verified (all clean)

- **`restartDeal` preserves the challenge correctly (both platforms).** It mirrors `playChallenge`:
  capture `challengeDay`, re-`deal(seed)` (which resets telemetry and clears challengeDay/win state),
  then restore `challengeDay` and re-persist. Telemetry is fresh (a proper new attempt), so a
  subsequent win still folds into that day's record.
- **No persistence race.** Web `saveGame()` (synchronous localStorage) and iOS `persist()`
  (synchronous UserDefaults on the main actor, no `await` between the two writes) mean the transient
  casual snapshot written inside `deal()` is always overwritten by the final write carrying the
  restored `challengeDay` before control returns — no window where a challenge is persisted as casual.
- **No stale state / orphaned timers.** `deal()` clears `winRecorded`/`pendingWin` (web) and
  `dailyResult`/`winRecorded`, stops autoplay, and bumps `finishGen` to invalidate queued finish
  blocks (iOS). A Replay-after-win becomes a plain casual re-deal (scoring already banked) —
  consistent across platforms, by design.
- **HUD.** Web's trailing `render()` re-shows the live objectives HUD after challengeDay is restored;
  iOS `challengeDay` is `@Published` so the HUD stays bound. Casual restart correctly hides it.
- **The new `pill(systemImage:)` overload** inserts an optional param before `primary:`; all existing
  call sites resolve unchanged, and Undo's `.disabled/.opacity` still apply. The web Undo SVG is
  `aria-hidden` with the "Undo" label intact (accessibility preserved).

## On-device / in-browser verification (this session)

- Web: casual `restartDeal` resets moves/history/telemetry for the same seed (verified via the engine).
- iOS: played a move on the daily (A♥ home, Moves 1), tapped **Replay** → board reset to a fresh
  Deal #10,001 (A♥ back in the tableau, foundation empty, Moves 0) with the live objectives HUD still
  showing — i.e. the daily-challenge context was preserved across the restart. Undo shows the u-turn
  arrow icon (enabled after a move, greyed with the icon when there's no history).

## Verdict
Converged with a clean seed review — a small, well-scoped change that faithfully reuses the existing
`playChallenge`/`deal` lifecycle. No findings.
