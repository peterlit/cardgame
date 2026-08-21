# Proposal — more variety in Daily Challenge objectives

**Status: proposal only. No code changed.** Decisions needed from you are marked **[DECIDE]**.

Companion to [`daily-challenges.md`](daily-challenges.md) (the original design) and
[`solver.md`](solver.md) (certification). Every feasibility number below was measured against the
366 baked winning lines in `data/daily-solutions.json`, not estimated.

---

## 1. Why the current set feels samey

Eleven objectives ship, but they cluster into two families, and the actual per-day picks are
lopsided:

| Family | Objectives | Share of days |
|---|---|---|
| Foundation **ordering** | aces-first, kings-first, jacks-down-first, suits-top-down, suit-sprint | 76 % of Golds |
| Resource **budget** | no-cells, cells-le-1, cells-le-2 | 46 % of Silvers + 24 % of Golds |
| Efficiency | moves, no-undo | 48 % of Silvers |
| Milestone timing | down-openers-20 | 6 % of Silvers |

Measured pick counts across the 366-day calendar:

```
SILVER  moves 92 · cells-le-1 91 · no-undo 84 · cells-le-2 76 · down-openers-20 23
GOLD    suits-top-down 93 · no-cells 88 · kings-first 75 · aces-first 55 · jacks-down-first 52 · suit-sprint 3
```

Three structural observations:

1. **Five of the six Gold objectives are one idea** — "what order did cards reach the foundations
   in?" — and they carry 76 % of Gold days. The only structurally different Gold is `no-cells`.
2. **The tableau is completely unmeasured.** Half the game — supermoves, empty columns, how you
   stage cards — contributes to no objective at all.
3. **`suit-sprint` is effectively dead weight**: supported by 4 of 366 seeds, selected on **3 days a
   year**. It costs a catalogue slot and returns almost nothing.

And the signature mechanic is underused. Causeway's distinguishing feature is that each suit is
built from *both ends and you choose where it splits* — yet **no objective mentions the split
point**. The ordering objectives are all "kings before aces", which is about sequencing, not about
the meeting point.

---

## 2. The hard constraint that shapes everything

Before ideas: there is a rule here that is easy to violate catastrophically, so it goes first.

The generator picks objectives by indexing frozen arrays with a per-day RNG:

```js
silverPool = SILVER_UNIVERSAL.concat(SILVER_CERTIFIED.filter(id => rec.supports.includes(id)))
goldPool   = GOLD.filter(id => rec.supports.includes(id))
silverId   = silverPool[Math.floor(rng() * silverPool.length)]
```

I tested what happens when each array gains one new id, comparing all 366 days before and after:

| Change | Days whose challenge changed | Verdict |
|---|---|---|
| Append to `GOLD` | **0 / 366** | safe |
| Append to `SILVER_CERTIFIED` | **0 / 366** | safe |
| Append to `SILVER_UNIVERSAL` | **123 / 366** | **rewrites history** |

The reason is the `.filter(supports)`: certified pools are gated per seed, and no *existing* pool
record lists an id that didn't exist when it was certified — so its pool is unchanged. Universal
ids are concatenated unconditionally, so adding one changes `silverPool.length` for every day and
reshuffles the draw.

> **Rule 1 — every new objective must be CERTIFIED (supports-gated). Never universal.**
> A new universal objective silently reassigns ~a third of all past days, invalidating recorded
> tiers and streaks.

There is a second, subtler consequence:

> **Rule 2 — a new objective cannot appear on a day that is already pooled.**
> Giving an existing seed a new `supports` entry grows its `goldPool`, which changes that day's
> draw — the same history rewrite. New objectives therefore debut only on **newly appended seeds**.

The calendar currently covers **2026-08-12 → 2027-08-12** (366 seeds). Day 366 is
**2027-08-13**, and `dailyChallenge` returns `null` past the pool, so the app shows "No challenge
available yet". **The pool has to be extended before Aug 2027 regardless** — and that extension is
the natural, zero-migration moment to introduce new objectives. **[DECIDE]** whether that timing is
acceptable, or whether you want the optional unlock in §6.

---

## 3. What makes an objective good here

Derived from the three that were tried and abandoned:

- **Not vacuous.** `empty-column` was dropped because winning empties every column. Any "did X ever
  happen?" objective must be bounded, or it is free.
- **Deterministically checkable.** The time cap was dropped because a fair target can't be
  calibrated. Anything wall-clock-dependent is out.
- **Not redundant with policy.** `manual-win` was dropped because automation is the player's
  responsibility by design.
- **Provable offline.** The solver must be able to *gate* it (never emit a violating move), so a
  certification can't be a false positive.
- **Actually supplied.** `suit-sprint` teaches the lesson: an objective supported by ~1 % of seeds
  is not a feature. **Proposed bar: ship nothing below ~10 % support** (≈36 of 366 seeds).

I also classify each idea by implementation cost:

| Tier | Meaning | Cost |
|---|---|---|
| **T0** | Derivable from today's `foundationOrder` + counters | checker + solver gate only |
| **T1** | Needs one new scalar in `Telemetry` | + schema change on both platforms, persisted in the saved game, new drift guards |
| **T2** | Needs a new event stream | significantly more |

`foundationOrder` already carries `{suit, rank, end, moveIdx}` per send, which is richer than the
current objectives use — notably, **counting a suit's `up` events gives its split point for free**.

---

## 4. Proposed objectives

### Family A — The split point *(new; the signature mechanic; all T0)*

Nothing today targets where a suit's two halves meet. Measured distribution of the split point
across 1 464 suits (how many ranks came from the up end):

```
up=1   9  |  up=5 176  |  up=9  173  |  up=13   4
up=2  34  |  up=6 204  |  up=10 146
up=3  70  |  up=7 208  |  up=11 106
up=4 122  |  up=8 166  |  up=12  46
```

**A1 · `split-even` — "Split every suit exactly down the middle" (A–7 up, 8–K down).** Gold.
Check: for each suit, count of `end === "up"` events is exactly 7.
Solver: pure gating — never send a card up above 7 or down below 8.
Feasibility: **0 of 366** unconstrained lines do this naturally, so it is a real constraint, not a
freebie. It needs a certification run to learn the support rate — this is the main open risk.

**A2 · `one-end-suit` — "Build a whole suit from a single end."** Gold.
Check: some suit has 13 up-events (or 13 down-events).
Solver: gate per candidate suit.
Feasibility: **4 of 366** naturally — rare but demonstrably reachable.

**A3 · `down-heavy` — "Take at least 8 of every suit from the King end."** Silver.
Check: every suit's up-count ≤ 5.
Solver: gate (never send a card up above 5).
Feasibility: per-suit, up ≤ 5 happens in 411/1464 suits (28 %); all four at once is much rarer, so
this is a genuine Silver-grade stretch and a good tonal counterweight — it pushes play toward the
down foundations, the direction players neglect.

### Family B — Tempo *(generalises the one milestone objective; all T0)*

`down-openers-20` is the only "by move N" objective and it is the rarest Silver. The family
generalises cheaply because `foundationOrder` already stores `moveIdx`.

**B1 · `aces-up-by-N` — "All four Aces home within your first N moves."** Silver.
Feasibility: **15 of 366** lines get all four Aces up by move 20. N is tunable per seed from `par`,
exactly like `moves`; N ≈ 25 looks like the right stretch band.

**B2 · `half-home-by-N` — "Half the deck home by move N."** Silver.
Feasibility: the 26th card lands at median move **59** (range 37–87). N ≈ 50 makes it a real but
fair target, and it rewards a completely different skill from the ordering objectives: steady
throughput rather than a specific sequence.

**B3 · `down-openers-N` — parameterise the existing objective** instead of hard-coding 20, deriving
N from `par` like `moves` does. Not new variety, but it makes the existing one usable on more seeds
(today only 147 of 366 support the fixed-20 version).

### Family C — Free-cell *shape* rather than count *(T1)*

Today's three cell objectives all count *cumulative parks*. Peak simultaneous occupancy is a
different axis, and the original design doc explicitly parked it as "a softer variant if we want it
later".

**C1 · `peak-cells-le-2` — "Never fill all three free cells at once."** Silver or Gold.
Feasibility: peak occupancy is **3 in all 366** shortest lines — so it is genuinely orthogonal to
cumulative use and cannot be satisfied by accident. Needs constrained solving to learn the rate.
Cost: T1 — one new `peakCells` counter in `Telemetry` on both platforms.

### Family D — Move shape *(T1; makes the tableau matter)*

**D1 · `no-supermoves` — "Move one card at a time."** Silver.
Feasibility: **52 of 366** lines never move more than a single card — comfortably above the 10 %
bar without a dedicated solve.
Cost: T1 — track the largest run moved.

**D2 · `one-big-move` — "Relocate a run of 5 or more cards in a single move."** Gold.
Feasibility: 15 of 366 naturally. Positive (not a prohibition), so it can't be vacuous, and it is
the only proposed objective that rewards *using* supermove capacity rather than avoiding it.

---

## 5. Ideas I tested and am NOT proposing

Recording these so they don't get re-invented:

| Idea | Measurement | Verdict |
|---|---|---|
| `strong-finish` — last 13 cards in ≤ 13 moves | median **13**, minimum **13** | **Vacuous.** The endgame is always a clean cascade. |
| Resurrect `empty-column` with a "while ≥ K cards remain" clause | 349/366 lines qualify even at K = 35; median board size at first empty column is 46 of 52 | **Still nearly free.** Would need K ≥ 45 to bite, and then it's a coin flip, not a skill. |
| `rainbow` — no two consecutive sends from the same suit | **0/366** naturally | Probably infeasible: endgame cascades force same-suit runs. Cheap to test, but expect rejection. |
| `finish-suits-in-order` — complete ♠ then ♥ then ♦ then ♣ | not measured | Suspect it is `suit-sprint` but four times harder — i.e. another 1 %-support dud. |
| Any **universal** objective | 123/366 days rewritten | Blocked by Rule 1. |
| Time caps, manual-win | — | Already settled in the original design; unchanged. |

**Related cleanup [DECIDE]:** retire `suit-sprint` from `GOLD` for *future* seeds. It cannot be
removed from the array (that would rewrite history), but new pool records simply need not certify
it, so it would quietly stop appearing after day 365 while the three historical days keep working.

---

## 6. Optional unlock — decouple the pools from history

Everything above is constrained by "the arrays are frozen because history is derived from them".
That coupling is avoidable.

**Proposal:** snapshot the current 366 days' `(seed, silverId, goldId, param)` into a frozen lookup
table checked into the repo. `dailyChallenge` consults the table for any day it covers, and only
*computes* a challenge for days beyond it.

Cost: one generated file plus a branch in the generator, mirrored on both platforms and pinned by a
golden test (the existing `GOLDEN_PICKS` test already proves such a table would be correct).

Benefit: the arrays stop being append-only-forever. You could reorder them, retire `suit-sprint`
properly, re-certify old seeds to enrich them, and tune `moves` params — all without touching a
single recorded day. It converts "frozen by construction" (fragile, and one careless append from
disaster) into "frozen by record" (explicit and safe).

**[DECIDE]** whether this is worth doing before or alongside the new objectives. My recommendation:
**yes, and do it first** — it is a small, testable change, and it removes the single sharpest
footgun in the codebase.

---

## 7. Suggested rollout

1. **Build a feasibility probe** (`tools/solver/probe-objective.mjs`). It replays the 366 baked
   lines and reports how often a candidate checker passes — exactly the measurements in this
   document. This caught two duds (`strong-finish`, `empty-column`) in minutes; making it repeatable
   means no objective ships on a hunch. *Cheapest, highest-leverage step.*
2. **Decide the shortlist** from §4, plus the §5 and §6 decisions.
3. **Implement checkers** in `tests/daily.mjs` (canonical) → mirror into `index.html` and
   `Model/Daily.swift` → extend the drift guards. T0 objectives stop here.
4. **Implement solver gates** in `tools/solver/solve.mjs` `objective()`, and **certify a sample**
   (say 40 seeds) to measure real support rates. Drop anything under ~10 %.
5. **Extend the pool** with `build-pool.mjs --start 10377`, which certifies against the enlarged
   objective set, then rebuild solutions. This both refills the calendar past Aug 2027 and debuts
   the new objectives.
6. **T1 telemetry** (`peakCells`, `maxRunMoved`) only if C1/D1/D2 make the cut — it touches the
   saved-game schema on both platforms, so it deserves its own review pass.

## 8. Risks

- **Support rate is unknown until certification.** A1 (`split-even`) is the most exciting idea and
  also the most likely to come back under 10 %. Step 4 exists to find that out cheaply, before any
  app code is written.
- **T1 objectives change the persisted `Telemetry` shape.** Both platforms decode it defensively
  today, so an added field is backward-compatible, but it needs the drift guards extended and a
  round-trip check on a saved in-progress challenge.
- **More objectives means a longer tail of rarely-seen ones.** Worth capping the catalogue and
  retiring low-support entries (§5) rather than only adding.
