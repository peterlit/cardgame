# Review-loop final report — Daily Challenges implementation (solver + shared core)

**Result: CONVERGED** (round 2 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, 0 open minors; one disputed item accepted.

Scope: the Daily-Challenges code delivered this session — the offline constrained solver + certified
pool (`tools/solver/`) and the shared date→challenge / objective-checker / streak core
(`tests/daily.mjs`). Design docs out of scope. Reviewed `d6789fe..HEAD`. Loop start SHA: `d8460bf`.
Fixes landed in `4896a28` (round 1) and `a954543` (round 2). (Prior loops archived under
`.review-loop/REPORT-*.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 1 | 0 | 0 | 0 | +0 | converged |
| 2 | 0 | 0 | 0 | 1 | 0 | 0 | +1 | converged |

## What the review established

**Core soundness verified, not assumed.** The reviewer traced the certification pipeline and
confirmed the headline guarantee — *no false-positive certifications*: every solver move mirrors an
app-legal move, `isWon` is a genuine all-foundations-complete check, ordering constraints are
memoryless (read only `up`/`down`) so the sorted-column transposition table can't launder a
history-violating line, and `autoSafe` is gated by the constraint at every send. Determinism holds
(no `Date.now`/`Math.random`; deterministic heap tie-breaking; `par` reproducible run-to-run). The
objective checkers were shown to **mirror the solver's gates exactly**, so "certified ⇒ a passing
line exists" and "checker passes ⇒ a valid line" stay in agreement.

## Findings

- **F1 [major] — FIXED.** The solver's rule model (`rules.mjs`) — the feature's single trust anchor
  — had no drift guard against `index.html`. Added one pinning 11 verbatim rule bodies (incl. the
  `tailDir` no-reverse rule and the `maxMovable` formula); a plausible edit to the app's stacking or
  supermove rules now trips it.
- **F2 [major] — FIXED.** Frozen history depended on unguarded code constants (the objective-array
  ordering + the rng seed formula), not just the append-only pool — a future reorder/insert would
  retroactively reshuffle every past day's Silver/Gold. Added a golden-master test pinning
  `(day, fixed-pool) → {seed, silverId, goldId}` and marked the arrays + rng formula FROZEN /
  append-only.
- **F3 [minor] — FIXED.** `par` (weighted-A*, inadmissible) overstated the optimum, so move caps ran
  loose. `certify` now stores `par = min(base, …all constraintPar)` — the shortest winning line found
  in any search (deterministic). Doc updated.
- **F4 [minor] — DISPUTED (accepted).** The ordering checkers weren't "tightened" to reject
  ace-down/early-non-ace sends. Verified this is *correct*: those events are intentionally permitted
  by **both** the solver gates and the checkers (only ace-*up* is gated), so tightening would reject
  solver-certified lines and break checker↔solver parity. The trusted-telemetry stance is reasonable
  for a local, offline, no-server game; the contract is now documented.
- **F5 [minor] — FIXED.** Deleted unused `cloneState`; `constraintPar` is now consumed by F3.
- **F6 [minor] — FIXED.** Silver and Gold need not be earned on one attempt; added `mergeTiers`
  (OR the tiers, keep best moves/time across retries) and documented `evaluateChallenge` as
  per-attempt with per-day OR-accumulation.
- **F7 [minor, introduced by the F6 fix] — FIXED (round 2).** `evaluateChallenge`'s result lacked the
  `moves`/`elapsed` that `mergeTiers` reads, so best-time would silently never record once wired up.
  `evaluateChallenge` now echoes those metrics on a win (omits on a loss so a fast-but-losing run
  can't clobber a prior best); added an end-to-end composition test.

Tests: 51/51 across the suite (engine 24 + solver 10 + daily 17).

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The rule port `tools/solver/rules.mjs` vs the app `index.html` (drift guard now in
   `tests/solver.test.mjs`).** The guard pins `index.html`'s text one-directionally; `rules.mjs` is
   covered by its own behavioural tests. If you ever change Causeway's tableau/supermove rules, make
   the change in BOTH and re-run — a wrong port silently mis-certifies every future seed.
2. **`par` is near-optimal, not proven-optimal.** Move caps derive from it generously; fine for a
   game, but "expert-tight" caps would need an admissible/optimal pass.
3. **Trusted-telemetry contract (`tests/daily.mjs` header).** The checkers grade the app's reported
   `foundationOrder`/counters without re-simulating. That's a deliberate choice for a local
   single-player game — but it means **Phase-1 app integration must emit complete, correctly-ordered
   telemetry**; a telemetry bug shows up as wrong tiers, not a crash. Worth a focused test when the
   app side lands.
4. **Objective arrays + rng formula are FROZEN.** New objectives may only be *appended*; the golden
   test enforces it. A reorder is a history-rewrite.

## Verdict
Converged: the daily-challenges foundation (solver + shared core) is sound — certifications are
false-positive-free and deterministic, the rule anchor and frozen-history invariant are now guarded
by tests, and par/tier-accumulation are corrected. Remaining risk is the one-directional rule guard
and the (deliberate) trusted-telemetry model, both flagged for a human/Phase-1 pass.
