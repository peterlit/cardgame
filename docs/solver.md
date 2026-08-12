# Causeway solver & certified pool — spec

**Phase 0 of the Daily Challenges feature** (see [daily-challenges.md](daily-challenges.md)). An
**offline** tool that certifies deals and bakes a pool of daily-eligible seeds. It is a build-time
tool — **never shipped in the app**. It also retires backlog item **I2** (no solvability guarantee).

Location: `tools/solver/` · tests: `tests/solver.test.mjs` · output: `data/daily-pool.json`.

---

## 1. What it produces

For each candidate seed (ID > 10,000), a certification record:

```json
{
  "seed": 10001,
  "winnable": true,
  "par": 83,                                  // reference solution length (moves)
  "supports": ["no-cells", "aces-first", "kings-first", "jacks-down-first",
               "suits-top-down", "cells-le-1", "cells-le-2"],
  "constraintPar": { "no-cells": 86, "aces-first": 107, "kings-first": 91 }
}
```

- `winnable` + `par` power Bronze and the **Universal** objectives (a move cap is derived from
  `par`; time caps generously from `par`).
- `supports[]` are the **Certified** objectives this seed admits — a Silver/Gold objective is only
  ever offered by the daily generator on a seed that lists it. This is what guarantees every
  offered objective is beatable (§ solvability of ordering objectives).
- `constraintPar[id]` is the reference length of the constrained solution, for calibrating caps
  under that objective.

The **pool** (`data/daily-pool.json`) keeps only **daily-eligible** seeds — winnable **and**
supporting ≥ 1 Gold-grade objective (a day needs a real Gold). It is **versioned** and
**append-only** (§5).

---

## 2. Rule & move model (`rules.mjs`)

Ported behaviourally from the shipped web engine (`index.html` "rules" section) so a certification
means exactly what the app enforces:

- **Runs** are alternating-colour, monotonic-by-1, either ascending or descending (`isSeqHead`).
- **Stacking** (`canStackTableau`): opposite colour, rank ±1, the run keeps its own direction, and
  — crucially — a column's established direction can't be reversed (`tailDir`).
- **Supermoves**: `(freeCells + 1) · 2^emptyCols`, minus one power when the target itself is an
  empty column (`maxMovable`).
- **Foundations**: dual per suit (up A→, down K→, never crossing); win when all four meet.
- **Move types**: foundation send (from a tableau top or a free cell), tableau run → column, top →
  free cell, free cell → column. Each is **one move** — matching the app's `moveCount` (a supermove
  of k cards is one move).

`rules.mjs` is pure functions over a plain `{tableau, cells, up, down}` state; unit-tested against
hand-verified cases in `tests/solver.test.mjs`. *(Open item: a drift guard tying `rules.mjs` to
`index.html`, like the engine harness has — see §7.)*

---

## 3. Search (`solve.mjs`)

**Weighted-A\* best-first** (`f = g + 2·h`) over a transposition table:

- **Heuristic** `h` = cards not yet home **+** the burial depth of each foundation's next-needed
  card (drives the search to unbury useful cards). Fast and effective; plain DFS was not (it
  wandered and failed to find wins within budget).
- **Transposition table**: canonical state key with columns and free cells sorted (they're
  order-independent), so symmetric states collapse — the key to tractability.
- **Auto-safe macro**: before branching, force all provably-safe cards home (each counts as a
  move). This matches the app's auto-play and cuts depth; for ordering objectives it is **gated by
  the constraint** so it can't break the objective.
- **Budget**: a node cap. Outcomes: `solved` (with `par`), `false` (space exhausted, no line), or
  `unknown` (budget hit first — treated as *unsupported*, i.e. the seed/objective is simply skipped).

**`par` is a reference, not proven-optimal.** Weighted A* (W=2) finds a short-but-not-guaranteed-
minimal line. Move caps are therefore derived **generously** from `par` (exact `N = f(par)` tuned in
Phase 1). True-optimal par (W=1 / IDA*) is a possible future refinement; a slightly generous cap is
the safer error for a game anyway.

---

## 4. Objectives & the solvability of ordering constraints (`solve.mjs`)

Objectives split by what the solver must prove:

- **Universal** (any winnable deal admits them; only `par` needed): move cap, time cap, no-undo,
  manual win. Not certified here.
- **Certified** (the winning *line* is restricted → prove a constrained win exists, per seed):

| Objective | Grade | How the solver enforces it |
|-----------|-------|----------------------------|
| `no-cells` | Gold | cell moves are never generated (`cellBudget = 0`) |
| `cells-le-1` / `cells-le-2` | Silver | cap cumulative cell parks (`cellBudget`) |
| `aces-first` | Gold | block any non-Ace foundation send until all four Aces are up |
| `kings-first` | Gold | block any Ace-up until all four Kings are down |
| `jacks-down-first` | Gold | block any Ace-up until K,Q,J of every suit are down |
| `suits-top-down` | Gold | block a suit's Ace-up until that suit's King is down |
| `suit-sprint` | Gold | can't start a new suit until every started suit is complete |
| `down-openers-20` | Silver | prefix goal: all four downs opened within the first 20 moves |

**Soundness (the important property):** for every *gating* objective (all but `down-openers`), the
move generator **never emits a move that violates the constraint**, so any win the search finds is,
by construction, a genuine constraint-obeying win — **no false-positive certifications**. `no-cells`
never uses a cell; `aces-first` never sends a non-Ace early; etc. `down-openers` is a positive
prefix goal, enforced by pruning past the deadline and accepting only when met. Winnability itself
is sound because `applyMove` implements the real rules and `isWon` is the real win condition.

**Dropped: `empty-column`** — winning empties *every* column, so "empty a column at some point" is
vacuously true for any win. It needs a non-trivial redefinition (e.g. "an empty column while ≥ K
cards remain") before it can be a real objective. Removed for now.

---

## 5. Pool builder (`build-pool.mjs`)

```
node tools/solver/build-pool.mjs [--start N] [--scan N] [--target N] [--budget N] [--out path]
```

Scans candidate seeds (**strictly > 10,000** — 1..10,000 are reserved for personal range-play),
certifies each, and appends the daily-eligible ones until it hits `--target` or exhausts `--scan`
candidates. Properties:

- **Append-only:** existing pool entries are preserved and never reordered, so the deterministic
  `date → seed` mapping (which indexes into this list) can never shift a past day. Growing the pool
  = running again with a later `--start`; it resumes after the highest seed already stored.
- **Versioned:** `pool.version` guards the schema.
- Resumable and idempotent (skips seeds already present).

The initial pool is intentionally modest; it grows by re-running. Certification is ~10–15 s/seed
(most of it the *unsupported* objectives exhausting their budget), so building is a batch job.

---

## 6. How to run

```bash
node --test tests/solver.test.mjs                 # unit + search tests
node tools/solver/build-pool.mjs --scan 40 --target 20   # build/grow the pool
```

The solver imports the deal/RNG from the shared engine (`tests/engine.mjs`), so its deals are
byte-identical to the app's on both platforms.

---

## 7. Known limitations & open questions

Documented per "proceed, but write down the questions." Implementation proceeded on the
**recommended** options; these are for later review:

1. **`par` is near-optimal, not optimal.** Fine for generous move caps; revisit if we want tight
   "expert" caps (would need IDA*/optimal search — slower).
2. **`rules.mjs` ↔ `index.html` drift.** The rules were hand-ported and unit-tested, but there's no
   automated drift guard yet (the engine harness has one for the shared logic). **Recommended
   next:** add a drift guard, or a verification pass that replays a claimed solution through the
   app engine. Until then, the rule port is the single trust anchor.
3. **Coverage.** The solver skips deals it can't crack within budget (`unknown`). That's acceptable
   — the pool only needs *enough* certified seeds, and skipping brutally-hard deals is arguably good
   for daily play — but it means the pool is a curated subset, not "all winnable deals."
4. **`down-openers-20` N and move-cap formula** are placeholder constants; tune in Phase 1 against
   real play.
5. **`empty-column` redefinition** (see §4) if we want that objective back.
6. **Performance.** Certification is a batch job (~10–15 s/seed). If we need a large pool quickly,
   parallelizing across worker processes is straightforward (each seed is independent).

None of these block Phase 1 (the app-side feature), which consumes the baked pool as data.
