# Review-loop final report — "Show me how to win": ready-state Start button (web + iOS)

**Result: CONVERGED** (round 1, clean seed review — 0 findings). 0 open blockers/majors/minors.

Scope: commit `b0c8fca` — the demo now opens in a READY (not-started) state (Next / Start / Stop)
instead of auto-running; Start begins auto-play (→ Pause → Resume); Next steps one move even before
Start. New `demoStarted` flag distinguishes initial "Start" from paused-after-play "Resume".

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

## What the review verified (all clean)

- **No auto-start:** neither platform schedules a step in `showSolution`; a stale queued step is
  invalidated three ways on iOS (leading `stopDemo`, the `deal()` chokepoint, and the `demoGen==gen`
  guard). No move advances before Start/Next.
- **Label/suffix logic is byte-identical web↔iOS** and correct across every transition
  (initial→Next→Start→Pause→Resume→Next).
- **Next boundary:** `demoAdvance`→`finishDemo` at the last move; Next after completion bails on the
  `demoing` guard; Start after manual stepping resumes from the live `demoIdx`.
- **iOS gen races:** rapid Start→Pause→Start can't double-advance (each Start bumps `demoGen`; pause
  relies on the `!demoPaused` guard). `scheduleDemoStep` losing its `first:` param breaks no caller.
- **Teardown/lock/no-score unchanged:** deal/New game/Undo/Replay funnel through `stopDemo` (now also
  resets `demoStarted`); input stays locked in the ready state (demoing=true → step via Next, by
  design); still never scored.

## Verification note

WEB was verified end-to-end this session (opens ready at move 0/N, no auto-advance after 700ms, Next
steps one move while still "Start", Start→"Pause"→"Resume"). **iOS could NOT be launched on the
simulator** — the host CoreSimulator wedged (SBMainWorkspace launch denial affecting even a fresh
clean simulator while Safari launched fine; a parallel session was running its own simulator, so a
shared-service restart was avoided). The change is pure post-`main` Swift logic, which cannot cause a
pre-launch SpringBoard denial, so the denial is environmental, not from this commit. iOS was verified
by close code-reading + a successful compile, and the reviewer traced the iOS state machine
specifically because it lacked a live check.

## HUMAN SKIM LIST

1. **Re-run the iOS demo on device once the simulator is healthy** — confirm it opens with Next /
   Start / Stop (not auto-running), Start→Pause→Resume, and Next steps one move. This is the only
   piece not live-verified this session.
2. **The `demoStarted` state machine** (web `index.html` + iOS `Game.swift`) is the load-bearing new
   logic; the toggle label and the "no auto-start" invariant both hinge on it.

## Verdict
Converged with a clean seed review — a small, well-scoped state change with identical web/iOS logic.
No findings. iOS live check deferred to a healthy simulator (environmental block, not a code issue).
