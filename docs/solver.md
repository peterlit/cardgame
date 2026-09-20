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
                                  [--cache .cache/month-certs] [--select-only] [--extend]
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
unused parameter of a family already used, and a rare certification (one only a few candidates
support) is preferred, since rare material is hardest to place. The chosen days are then reordered
so no two consecutive dates share a family.

**An exact `(silver, gold)` pair is never repeated — a hard ban, not a preference.** Since commit
`07aa37c` the selector refuses a pair already placed in the same run, and an `--extend` run also
refuses any pair already published; both checks re-run on the bytes about to ship. One exception is
history: before the ban was hard, the published pool shipped days 3 and 60 (Aug 4 / Sep 30 2026) with
the same `suit-balance{N:4}` + `cells-le{N:0}`. That pair is **grandfathered** — published days are
never re-validated against each other, only the days being added are checked against them — and it
must never be re-picked: changing either day's bytes would invalidate every player's banked day-3 /
day-60 medals. Do not "fix" the guard to cover the whole pool; it would go red on published data.

**Extending the calendar (`--extend`).** The pool is extended in place, never rebuilt: `--extend`
loads the published `--out` file, keeps every existing day byte-for-byte (it fails closed if any
would change, and on a same-version rebuild), and selects only the `--days <total> − published`
new days, drawing from the committed certification cache so `--select-only` needs no new
certification (~5 min). The October 2026 extension was exactly:

```bash
NODE_OPTIONS= node tools/solver/build-month.mjs --select-only --extend --days 92
# bake the lines in four stripes (parallel), then fold them into the published file
for w in 0 1 2 3; do NODE_OPTIONS= node tools/solver/build-solutions.mjs --stripe $w/4 --out .cache/sol-$w.json & done; wait
NODE_OPTIONS= node tools/solver/build-solutions.mjs --merge .cache/sol-0.json .cache/sol-1.json .cache/sol-2.json .cache/sol-3.json
cp data/daily-pool.json data/daily-solutions.json ios/Causeway/Causeway/   # the iOS copies must stay byte-identical
```

November is the same with `--days 122`; the month-boundary and iOS-parity tests
(`tests/solutions.test.mjs`, `tests/ios-parity.test.mjs`) fail on a partial month or a stale copy.

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
node tools/solver/build-month.mjs --select-only --extend --days <total>   # append a month (see §5)
```

Never rebuild the seeded pool (`build-month.mjs` without `--extend`): the published days are the
keys to every player's banked medals, and the builder refuses a same-version rebuild for that reason.
`--candidates`/`--jobs` only matter when new seeds must be *certified* (a fresh cache).

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

7. **~~Silver and Gold are certified independently~~ — RESOLVED 2026-08-30: every day is
   flawless-certified.** `certify()` still proves each `(family, parameter)` separately, but the
   month builder no longer ships a pairing on that evidence alone: `certifyFlawless(seed, silver,
   gold)` must first find ONE line that wins and — replayed through the *runtime* checkers, not the
   search gates — earns both tiers. A triple that fails is blacklisted and the slot re-picked.
   - `jointObjective()` composes the two constraints: gates AND, `cellBudget`/`maxRun` take the
     tighter bound, the existential latches (`big-move`, `rank-rush`) OR, and a `moves` Silver
     becomes a **`moveCap` prune on `g`** so it is searched rather than checked afterwards.
   - `contradiction()` rejects the structurally impossible without any search:
     `big-move{N}` × `max-run{M<N}` (one `maxRunMoved` counter, two opposite demands);
     `suit-sprint` × `suit-balance{N≤12}` (the first suit runs 13 clear);
     `suit-sprint` × `rank-rush{N<39}` (the fourth suit cannot start before 39 cards are home); and
     a rank-gated Gold (`split-at`, `end-bias`) against a `rank-rush` whose deadline is shorter than
     the 4 × per-suit prerequisite cost it forces.
   - What it cost: **nothing measurable in variety.** Before the gate, 24 of August's 31 days were
     certifiable, 3 provably impossible, 4 unproven; a gated re-run of the same greedy fill produced
     31 days with the same 13 families and 52 distinct challenges, keeping 29 of the 31 seeds. The
     shipped Aug+Sep calendar is built under the gate throughout.
   - The certified line is cached (`.cache/flawless-certs.jsonl`) and re-used by
     `build-solutions.mjs` as the baked **flawless** demo line, so the certificate and the "How to
     win flawless" button are the same artefact.

None of these block Phase 1 (the app-side feature), which consumes the baked pool as data.

## Solutions ("Show me how to win")

`solve()` optionally reconstructs the winning line (`{ withPath: true }`): each search node remembers
its parent and the move-segment that produced it (the chosen move plus the auto-safe sends that
followed), and on a win we walk parents back to the root and flatten to the complete move list from
the raw deal. `moveToken()` serializes each move to a compact, replayable token (`F/G` foundation,
`T` tableau run, `C` park, `X` cell→column; `end` 0=up/1=down; comma-separated fields, space-joined).

`tools/solver/build-solutions.mjs` bakes, for every pool seed, **one line per tier** into
`data/daily-solutions.json` (v3: `{ version, solutions: { "<seed>": { bronze, silver?, gold?, flawless? } } }`):

- **bronze** — the shortest *unconstrained* win (clear the deal).
- **flawless** — the line that satisfies BOTH objectives, i.e. the day's flawless certificate,
  re-used verbatim from `.cache/flawless-certs.jsonl` when the month builder already found it. It
  powers the 🌟 "How to win flawless" button, and its presence is what the CI test
  `every shipped day is flawless-certifiable` checks.
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
