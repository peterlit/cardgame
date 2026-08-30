# Review-loop final report — Causeway (OOM fix)

**Result: CONVERGED** (round 1 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, 0 open minors; nothing newly introduced left open.

Scope: the on-device OOM fix (commit `06cb6f5`) plus its doc follow-up (`1ac06f9`).
Start SHA: `06cb6f5`. (Prior converged loop archived at `.review-loop/REPORT-prev.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 2 | 0 | -2 | converged |

## What the review established

**The OOM fix's core mechanism is correct — independently verified, not just claimed.**
The reviewer built an isolated Combine test confirming that a plain (non-`@Published`) nested
`ObservableObject` (`let clock`) does **not** forward its mutations to the parent's
`objectWillChange`. So `game.clock.elapsed` ticking at 1 Hz genuinely no longer invalidates
`ContentView`; only the small `ClockStat` (`@ObservedObject var clock`) re-renders. The
`winOverlay` reading `game.clock.elapsed` in `body` does **not** re-subscribe ContentView (plain
read, gated by the already-stopped clock behind `if game.won`). `SummerBackground.equatable()`
is sound (the view has zero external inputs) and correctly shields its `.blur()` layers from
re-rasterization on both the idle-clock path and per-move board updates. Timer lifecycle
(start/stop/reset/restore/undo-from-win/win/auto-finish) is single-timer-safe; `[weak self]`
present; `elapsed` persist/restore and won-`secs` recording intact. Full iOS `swiftc -typecheck`
passes.

## Findings (all fixed)
- **F1 [minor]** — `prompts.md` duplicate numbering introduced by the OOM commit → renumbered
  monotonic, content preserved (verified by a numbers-stripped diff). (`1ac06f9`)
- **F2 [minor, process]** — the fix's "Closes I6" was asserted from reasoning + type-check, not an
  on-device trace → BACKLOG I6 retitled "FIX LANDED, on-device trace pending", verified-vs-unverified
  separated, and a concrete `I6-verify` task added. Fix code left intact. (`1ac06f9`)

**Disputed (agree-to-disagree):** none.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The whole OOM fix — `ios/.../Model/GameClock.swift`, `Model/Game.swift` clock rewiring,
   `Views/ContentView.swift` `ClockStat`, `Views/SummerBackground.swift` `.equatable()`
   (commit `06cb6f5`).** This is the substantive change. The reviewer verified the *mechanism* is
   correct, but **the fix is NOT yet confirmed on the device** — no Instruments/Allocations trace
   shows RSS actually plateaus over a long idle session.
2. **⚠️ Run the `I6-verify` task before trusting the OOM is gone.** Deploy commit `06cb6f5+`,
   leave the app **idle for 15+ minutes on the iPhone 13 Pro** under Instruments → Allocations (or
   watch the debug memory gauge), and confirm memory is flat, not climbing. If it still climbs, the
   next suspect is `matchedGeometryEffect` retention on move/autoplay-driven renders — re-open I6.
   This is the one thing a code review (and this loop) fundamentally cannot verify; it needs the device.
3. **` contentView.body` clock read** — sanity-check on device that the "Time" display still ticks
   live and the win screen shows the correct final time (the clock was moved out of `Game`'s
   published state).

## Verdict
Converged: no blockers/majors/minors open. The OOM fix is architecturally sound and mechanically
verified; its real-world efficacy is pending a single on-device memory-profiling pass (tracked as
`I6-verify` in BACKLOG.md). No regressions found.
