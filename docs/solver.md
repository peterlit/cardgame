# Causeway solver & certified pool — spec

**Phase 0 of the Daily Challenges feature** (see [daily-challenges.md](daily-challenges.md)). An
**offline** tool that certifies deals and bakes a pool of daily-eligible seeds. It is a build-time
tool — **never shipped in the app**. It also retires backlog item **I2** (no solvability guarantee).

Location: `tools/solver/` · tests: `tests/solver.test.mjs` · output: `data/daily-pool.json`.

---

## 1. What it produces

*(Updated for the 2026-08 recut: objectives are parameterised families, so a certification is per
`(family, parameter)` pair, not per objective id.)*

For each candidate seed drawn from the daily range (500,001-1,000,000), a certification record:

```json
{
  "seed": 700001,
  "winnable": true,
  "par": 90,                                  // reference solution length (moves)
  "supports": [
    { "id": "cells-le",  "param": { "N": 1 },              "par": 94 },
    { "id": "split-at",  "param": { "R": 9 },              "par": 103 },
    { "id": "end-bias",  "param": { "end": "up", "min": 11 }, "par": 98 },
    { "id": "rank-rush", "param": { "rank": 13, "N": 18 }, "par": 96 }
  ]
}
```

- `winnable` + `par` power Bronze and the **Universal** families (the `moves` cap is derived from
  `par`). `par` = **reference par = the shortest winning line found in any of our searches**
  (unconstrained *and* every constrained one — each constrained line is still a legal unconstrained
  win, and constrained sub-searches often beat the unconstrained line). It is a real upper bound on
  the optimum, not proven-minimal.
- Each entry's own `par` is the reference length of that constrained solution.
- `rank-rush` records a **tightened** `N`: the builder re-searches against the witness line's own
  completion index until it stops improving, so the shipped deadline is one a real line met.

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

## 5. Month builder (`build-month.mjs`)

```
node tools/solver/build-month.mjs [--candidates 320] [--days 31] [--budget 100000]
                                  [--jobs 8] [--sample-seed 20260801] [--out data/daily-pool.json]
                                  [--cache .cache/month-certs] [--select-only]
```

*(Replaces the old append-only `build-pool.mjs`, which is deleted along with the "IDs > 10,000"
reservation. Daily deals now come from 500,001-1,000,000, at or under the app's single
`maxSeed = 1,000,000` ceiling.)*

**Phase 1 — certify, in parallel and resumably.** Candidate seeds are drawn deterministically from
the daily range (same `--sample-seed` ⇒ same list ⇒ cache hits), then certified against the whole
`VARIANTS` matrix — 63 `(family, parameter)` pairs — across `--jobs` worker processes, each
appending JSONL to its own cache file. An interrupted run resumes where it stopped.

**Phase 2 — choose the month for maximum variety.** A greedy fill takes, at each step, the
`(seed, gold, silver)` triple that adds the most new variety: an unused family scores far above an
unused parameter of a family already used, an exact challenge is never repeated, and a rare
certification (one only a few candidates support) is preferred, since rare material is hardest to
place. The chosen days are then reordered so no two consecutive dates share a family.

Certification is **~90-150 s/seed** at `--budget 100000` — most of it the *unsupported* variants
exhausting their node budget — so a 320-candidate month is roughly an hour on 8 cores. Building is
a batch job; run it with `nohup` and watch the log.

**Objective supply is very uneven**, which is why the net has to be cast wide: on a typical seed,
`cells-le`, `max-run`, `split-at` and `suit-balance` certify at nearly every parameter, while
`ends-first` (the strict both-ends prefix) certifies on 2 of 13 parameters, `big-move` is
seed-dependent, and mid-rank `rank-rush` deadlines are unreachable by construction.

---

## 6. How to run

```bash
node --test tests/solver.test.mjs                 # unit + search tests
node tools/solver/build-month.mjs --candidates 320 --jobs 8   # rebuild the seeded month
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

7. **Silver and Gold are certified independently — 🌟 Flawless is not certified at all.** `certify()`
   proves a winning line exists for each `(family, parameter)` *separately*; the month builder then
   pairs a Gold and a Silver on one seed with nothing checking that a *single* line can satisfy
   both. Since Flawless = all three tiers in one attempt, a day can ship whose Flawless star is
   unreachable. Measured over the shipped August month (joint search, budget 120k, then 600k on the
   failures): **24/31 certifiable, 3 provably impossible, 4 uncertified within budget**. The three
   impossibilities are structural, not solver weakness:
   `big-move{5}` × `max-run{2}` (Aug 30) is contradictory on `maxRunMoved`; `suit-sprint` ×
   `suit-balance{4}` (Aug 26) breaks the moment the first suit runs 5 cards ahead; `suit-sprint` ×
   `rank-rush{rank 1, N 20}` (Aug 1) needs 3 whole suits home (≥39 moves) before the fourth Ace.
   A gate is cheap and costs no variety — a joint-certified re-run of the same greedy fill produced
   31 days, 13 families, 52 distinct challenges (identical to the shipped month) keeping 29 of its
   31 seeds, at 111 extra joint solves (~5 min, 44 accepted / 66 budget-limited / 1 proven
   impossible). Implementation sketch: compose the two constraint gates (∧ of `allowFoundation`,
   min of `cellBudget`/`maxRun`, ∨ of the existential goals), add a `g > moveCap` prune so a
   `moves` Silver is searched rather than checked after the fact, verify each greedy pick and
   blacklist the pair on failure. A static contradiction table would reject the three structural
   cases instantly, without search.

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
