# Review-loop final report — Causeway (auto-finish feature)

**Result: CONVERGED** (round 1 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, 0 open minors; nothing newly introduced left open.

Scope: the auto-finish feature — the `.ask`/`.on`/`.off` tri-state setting, the "Ready to finish?"
prompt, the deferred "Finish" button, and the sequential one-card-at-a-time finish animation.
Commit range reviewed: `9817ecb..HEAD` (`8844567` auto-complete toggle, `ae1ebd7` Ask mode + prompt
+ sequential finish). Loop start SHA: `ae1ebd7`. Fixes landed in `af23d33`.
(Prior tap/drag loop archived at `.review-loop/REPORT-tapdrag.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

(Seed review filed F1–F4, all minor; the same round's implementer pass fixed all four, so the
round-1 row nets to zero open.)

## What the review established

**The core safety fear did not materialize — verified by reading detection against execution.**
The reviewer confirmed a false-positive that runs a finish and then strands a non-winning board
cannot happen:
- Every entry to the greedy send (`sendOneHome`) is gated by `runAutoFinish`, which self-gates on
  `autoFinishWouldWin()` — no caller sends cards on an unproven board.
- The simulation predicates are byte-identical to the real foundation rules on both platforms, and
  the greedy send is confluent (up/down advance independently and meet exactly), so the batch
  detector emptying the board guarantees the one-at-a-time chain also empties it. No lost/duplicated
  cards.
- `finishing` cannot get stuck true (set only in `runAutoFinish`, which immediately schedules a step;
  every step either schedules the next or clears the flag).
- Stale-timer safety: web clears the real `finishTimer`/`autoTimer`; iOS resets flags synchronously
  before any pending `asyncAfter` runs, and each block guards its flag.
- Web/iOS parity on mode semantics, prompt/defer, cadence, and the Finish-button gate; no dead code
  or leftover `autoFinish`/`autoFinishOn` references; stacked iOS `.alert` modifiers are valid on the
  iOS 17 target.

## Findings (all fixed)

- **F1 [minor] — FIXED.** iOS `restore()` omitted the `finishing`/`promptAutoFinish`/
  `autoFinishDeferred` resets that web `restoreGame()` performs. Harmless today (restore is
  init-only) but a latent parity gap → the three resets were added.
- **F2 [minor] — FIXED.** The iOS finish chain relied only on the `finishing` flag and never
  cancelled a pending `asyncAfter`, so an Undo-mid-finish followed by a quick re-triggering move
  could overlap two finish chains (self-healing, no card loss, but sloppy). Fixed with a monotonic
  `finishGen` token captured per scheduled step and bumped on `runAutoFinish`/`undo`/`deal`; a stale
  block from a superseded chain now bails. Reviewer traced normal-finish stability, Undo halting, and
  the restart race being closed with at most one live block per chain.
- **F3 [minor] — FIXED.** The whole safety story rests on "detection == execution," yet only the
  detector (`autoFinishWouldWin`) was tested. Added a canonical `sendOneHomeStep` executor to the
  Node harness (matching the web/iOS greedy order + up-before-down rule), a test looping it to
  fixpoint over four fixtures asserting `boardEmptied === autoFinishWouldWin(state)`, and two
  drift-guard substrings pinning the web `sendOneHome` body. 24/24 tests pass; drift guard real.
- **F4 [minor] — FIXED.** The setting key was renamed (`causeway.autofinish` → `…mode`) and the
  default flipped On→Ask with no migration; documented as intentional (app unshipped, so no legacy
  key exists) via a one-line comment on both platforms.

**Disputed (agree-to-disagree):** none.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The sequential finish + async lifecycle — `Game.swift` `runAutoFinish`/`finishStep`/`finishGen`
   and web `runAutoFinish`/`stepFinish`/`finishTimer` (commits `ae1ebd7`, `af23d33`).** This is the
   substantive change and the one with real concurrency. The reviewer traced the `finishGen` race
   closure by construction, but **timing/gesture behavior can't be unit-tested** — on a device,
   confirm: Undo mid-finish halts cleanly; New game mid-finish leaves no ghost chain; rapidly
   toggling the mode or spamming the Finish button never double-runs.
2. **The `.ask` prompt lifecycle — `ContentView.swift` `.alert(isPresented: $game.promptAutoFinish)`
   + `maybeAutoFinish` pausing safe-autoplay (commit `ae1ebd7`).** Verify on device that the prompt
   appears at the right moment, "Not yet" doesn't re-nag, the "Finish" button then works, and the
   board doesn't shuffle under the prompt. Note: a finishable *saved* game will prompt on app launch
   (restore → maybeAutoFinish) — decide if that's desirable.
3. **`sendOneHome` (iOS) has no direct test** — only the web `sendOneHomeStep` twin is tested, and
   the iOS engine shares the algorithm by construction (no iOS test target — a known backlog item).
   The drift guard pins web↔`engine.mjs` but never iOS; a future iOS-only edit to `sendOneHome` or
   the foundation predicates could silently diverge.

## Verdict
Converged round 1: no blockers/majors/minors open. The feature is move-correct and at web/iOS parity
by construction (gated detection == execution on both platforms); the one real concurrency gap (iOS
finish double-run) is fixed and re-validated; execution is now test-covered; the two documentation/
parity nits are closed. Residual risk is entirely in device-only async/gesture timing and the absence
of an iOS engine test target — flagged above for a human pass, not code.
