# Review-loop final report — "Show me how to win": Silver & Gold lines (web + iOS)

**Result: CONVERGED** (round 1, clean seed review — 0 findings). 0 open blockers/majors/minors.

Scope: commit `767e30a` — per-tier (Bronze / Silver / Gold) winning-line demos for "Show me how to
win", spanning the offline solver builder, the baked data, and both apps' runtime.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 0 | 0 | +0 | converged |

## What the review verified (all clean)

The single most attack-worthy claim — that a builder-certified "Gold"/"Silver" line might not
actually earn its tier once the *app's own* diff-based telemetry regenerates it — the reviewer tested
**empirically across all 556 baked silver/gold lines**, replaying each through a faithful mirror of
the app's `recordHomed`/`cellUses`/`moveIdx` pipeline (not trusting the builder's reconstruction) and
re-evaluating against the canonical `tests/daily.mjs` checkers. All 556 still pass. Also confirmed:

- **Builder telemetry matches app runtime.** One F/G token homes exactly one card; `cellUses` = count
  of `C` (tableau→cell) tokens, which is exactly what the app counts (the token model has no
  cell→cell move, the only case the app excludes); `moveIdx` is the 1-based token ordinal on both, and
  the demo replays 1:1 with autoplay off — so `down-openers-20`'s "4th King ≤ 20 moves" is honest.
- **Index/day alignment across the three `dailyChallenge` variants** (builder pool-object, web inline
  pool-array, iOS Swift) — identical frozen RNG seed and append-only pool, 0 duplicate seeds. Every
  certified-silver day (190) and gold day (366) has a matching baked line; 0 missing, 0 orphaned.
- **Silver fallback** (`solutionLine('silver')→bronze`) is unreachable from the UI (the Silver button
  only renders when a distinct `sol.silver` exists) — dead but harmless, no mislabel path. And the
  bronze line always satisfies a universal Silver (par ≤ round(par·1.2); demos never undo).
- **Robustness:** a missing gold/silver → button hidden + `showSolution` no-ops; a v1 (string-valued)
  file fails the iOS `TierSolutions` decode under `try?` → feature silently off (bundled file is v2).
- **Label escaping** (web `onclick` interpolation) — all 11 OBJECTIVES labels are static English with
  no quotes/backslashes; `esc()` handles them anyway.
- **No scoring/teardown regression** — the demo never routes through `commit`/`recordWin`; `deal()`
  chokepoint still stops the demo; `demoTier`/`demoLabel` only feed the bar and are overwritten per run.

## Non-defects noted (maintenance hazards, not findings)

1. `build-solutions.mjs` hardcodes `CERTIFIED_SILVER`, duplicating `SILVER_CERTIFIED` in `daily.mjs`.
   They match today; if a future certified Silver is appended to `daily.mjs` without updating the
   builder, that day's Silver demo would silently vanish (button hidden — no mislabel). Worth a
   comment or a shared import next time the builder is touched.
2. iOS `SolutionsFile` ignores the `version` field; version skew is caught only implicitly via decode
   failure. Defensive-only.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The builder's objective re-verification (`build-solutions.mjs replay()` + `evaluate`).** This is
   what guarantees a "Gold line" actually earns Gold. It passed for all 366 gold + 190 silver lines
   with 0 rejects, and was independently re-checked against the app pipeline. Any future pool growth
   must re-run the builder (and the `CERTIFIED_SILVER` set must stay in sync with `daily.mjs`).
2. **Play-test the tiers on device.** Watch a Gold line (it should visibly hold the Aces back / order
   the foundations per the objective) and a certified-Silver line (respect the free-cell limit), and
   confirm the bar names the right objective. The unconstrained Bronze line remains the "just clear
   it" demo.

## Verdict
Converged with a clean seed review — a well-scoped extension whose one real risk (baked line doesn't
earn its tier) was empirically disproven across all 556 lines. Full web + iOS parity for per-tier
"Show me how to win".
