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
  `par`; time caps generously from `par`). `par` = **reference par = the shortest winning line
  found in any of our searches** (unconstrained *and* every constrained one — each constrained line
  is still a legal unconstrained win, and constrained sub-searches often beat the unconstrained
  line). It is a real upper bound on the optimum, not proven-minimal.

  > **Shipped-data caveat.** `certify()` takes that minimum today (`solve.mjs:186-188`), but **274 of
  > the 366 records in `data/daily-pool.json` predate that change** and store the *unconstrained*
  > length instead, so their `par` is larger than `min(constraintPar)` (e.g. seed 10002: `par 78`,
  > `min 77`; seed 10004: `par 97`, `min 85`). Because the pool is append-only (§5) they were never
  > regenerated. The only consequence is that the `moves` Silver objective — `N = round(par × 1.2)`
  > — is up to ~14 % looser than intended on those days, which errs toward the player. Regenerating
  > would silently re-tune historical days, so it should not be done casually; if it ever is,
  > migrate `moves` params for shipped dates rather than recomputing them.
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
hand-verified cases in `tests/solver.test.mjs`. A **drift guard** ties it to the shipped web engine:
the first test in `tests/solver.test.mjs` (lines 24–47) reads `index.html` and asserts the canonical
bodies — `isSeqHead`, `runDir`, `tailDir`, `canStackTableau`'s `conn`/`rdir`/`tdir` rules,
`maxMovable`, and both foundation predicates — still appear there verbatim. Editing the rules in one
place without the other fails CI.

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
minimal line. `certify` reports the **shortest line found across the unconstrained and all
constrained searches** (each constrained win is also a legal unconstrained win), which is a tighter,
still-deterministic upper bound than the unconstrained line alone. Move caps are derived
**generously** from `par` (exact `N = f(par)` tuned in Phase 1). True-optimal par (W=1 / IDA*) is a
possible future refinement; a slightly generous cap is the safer error for a game anyway.

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

The pool currently holds **366 seeds** (10001–10376 — a full year of daily challenges); it grows by
re-running with a later `--start`. Of the seeds scanned in that range, 10 were rejected as not
daily-eligible. Certification is ~10–15 s/seed (most of it the *unsupported* objectives exhausting
their budget), so building is a batch job.

**Objective supply is uneven**, which is worth knowing before tuning the generator: across the 366
seeds, `cells-le-2` is supported by 366, `cells-le-1` by 364, `suits-top-down` by 353, `no-cells` by
304, `kings-first` by 292, `aces-first` by 223, `jacks-down-first` by 184, `down-openers-20` by 147
— and **`suit-sprint` by only 4** (seeds 10105, 10192, 10210, 10312), so it is actually chosen as
the day's Gold on just 3 days of the year.

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
2. ~~**`rules.mjs` ↔ `index.html` drift.**~~ **Resolved.** A drift guard now pins the canonical rule
   bodies in `index.html` (`tests/solver.test.mjs:24-47`, see §2), and baked solutions are
   additionally replay-verified against the real rules and the runtime objective checkers at build
   time and again in CI (`tests/solutions.test.mjs`).
3. **Coverage.** The solver skips deals it can't crack within budget (`unknown`). That's acceptable
   — the pool only needs *enough* certified seeds, and skipping brutally-hard deals is arguably good
   for daily play — but it means the pool is a curated subset, not "all winnable deals."
4. **`down-openers-20` N and move-cap formula** are placeholder constants; tune in Phase 1 against
   real play.
5. **`empty-column` redefinition** (see §4) if we want that objective back.
6. **Performance.** Certification is a batch job (~10–15 s/seed). If we need a large pool quickly,
   parallelizing across worker processes is straightforward (each seed is independent).

None of these block Phase 1 (the app-side feature), which consumes the baked pool as data.

## Solutions ("Show me how to win")

`solve()` optionally reconstructs the winning line (`{ withPath: true }`): each search node remembers
its parent and the move-segment that produced it (the chosen move plus the auto-safe sends that
followed), and on a win we walk parents back to the root and flatten to the complete move list from
the raw deal. `moveToken()` serializes each move to a compact, replayable token (`F/G` foundation,
`T` tableau run, `C` park, `X` cell→column; `end` 0=up/1=down; comma-separated fields, space-joined).

`tools/solver/build-solutions.mjs` bakes, for every pool seed, **one line per tier** into
`data/daily-solutions.json` (`{ version, solutions: { "<seed>": { bronze, silver?, gold? } } }`):

- **bronze** — the shortest *unconstrained* win (clear the deal).
- **gold** — a win solved under the day's Gold objective (`solve(objective(ch.gold.id))`), always a
  certified/constraining objective. The day's objective is keyed by the seed's **pool index**
  (`dailyChallenge(index, pool)`), frozen by the append-only pool.
- **silver** — a win under the day's Silver objective, but only when it's a *certified* (constraining)
  objective (free-cell limits / down-openers). A "universal" Silver (win in N moves / no undo) is
  already satisfied by the bronze line, so it's omitted and the app falls back to bronze.

Every line is **re-simulated through `rules.mjs`** and, for silver/gold, **re-checked against the
actual objective checker** (`tests/daily.mjs evaluate`) — a line that doesn't win *and* earn its tier
is dropped (the current 366-seed pool: 366 gold + 190 silver lines, 0 rejected). The apps offer a
"Show me how to win" button per available tier and animate the line as a demonstration (assisted,
pausable/single-steppable, never scored).
