# Review-loop final report — "Show me how to win": pause + single-step (web + iOS)

**Result: CONVERGED** (round 1, clean seed review — 0 findings). 0 open blockers/majors/minors.

Scope: commit `234d989` — pause/resume + a "Next" single-step control for the "Show me how to win"
demo playback, on both the web app and the iOS app. The demo is now a state machine
(playing ↔ paused → done) with live progress in the bar.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

## What the review verified (all clean)

The skeptical pass specifically tried to construct the failure modes that live testing wouldn't
catch, and found each one closed:

- **Timer/step races.** Web: "paused ⇒ no live timer" holds on every path — `demoTick` nulls
  `demoTimer` *before* the paused/stopped bail and before rescheduling, and resume only arms
  `if(!demoTimer)`, so two `setTimeout` chains are unreachable (and JS is single-threaded). iOS: the
  `demoGen` token prevents double-advance — a step queued before Pause bails on `!demoPaused`; Resume
  bumps `demoGen` and schedules a fresh chain, and the stale step bails on `demoGen == gen`. Rapid
  Pause/Resume just queues stale-gen steps that all bail except the newest.
- **Single-step / boundary.** `demoAdvance` applies `moves[idx]` *then* increments *then* checks
  `idx >= count` → `finishDemo` — the last move is applied (board reaches solved) and the array is
  never read out of range (iOS never traps, web never yields an undefined token). Next after
  completion is a clean no-op (guarded `demoing && demoPaused`; the button is hidden anyway). Exactly
  one move per Next.
- **Unscored + no mid-demo persistence, including while paused.** `demoing` stays true while paused,
  so input stays locked (`startDrag` / `smartMove` / `drop`) and `saveGame` / `persist` still bail;
  `applyDemoToken` never routes through `commit`/`recordWin`, so `won` stays false (the observed
  Won 0). After completion, iOS `persist` still bails via `!boardComplete`.
- **Bar consistency + teardown.** Web updates progress every auto move (`demoTick`→`updateDemoBar`);
  iOS is `@Published`-driven. The done banner hides Next/Pause and relabels Stop→Done on both.
  `stopDemo()` resets `demoPaused`/`demoMoves`/`demoIdx` and is reached from every teardown chokepoint
  (`deal`, New game, Undo, Replay, Daily-play) in all three states.

## On-device / in-browser verification (this session)

- Web: pause holds; each Next advances exactly one move; Resume continues; stepping to the end shows
  the Done banner; wins + daily store unchanged throughout.
- iOS (iPhone 17 Pro simulator): paused at 53/78 with Next · Resume · Stop; two Next taps → 54 → 55;
  Resume auto-advanced to completion; Done banner; Won stays 0.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The two load-bearing guards.** Web's "null `demoTimer` before rescheduling" discipline
   (`demoTick`) and iOS's `demoGen` step-invalidation are what keep pause/resume race-free. Any future
   change to the demo loop must preserve both. **Play-test:** mash Pause/Resume rapidly, and hammer
   Next at the very last move — confirm no double-advance, no stuck timer, no crash.
2. **Input stays locked while paused (by design).** Stepping is via Next, not the board; to take over
   you Stop/Replay. Confirm that feels right in play.

## Verdict
Converged with a clean seed review — a well-scoped state-machine extension that reuses the existing
demo teardown chokepoint and adds no new scoring/persistence surface. No findings. Full web + iOS
parity for pause + single-step.
