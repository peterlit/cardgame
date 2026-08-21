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
   year**. It costs a catalogue slot and returns almost nothing. §4 C2 diagnoses why — it is the
   extreme setting of an otherwise well-behaved family — and proposes the fix.

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

Nine families below; every feasibility figure is measured against the 366 baked winning lines.
"Natural rate" means *how often the move-optimal winning line already satisfies it* — a lower bound,
since a constrained solve will usually do better. Anything at ~100 % is vacuous; anything at 0 %
needs certification to prove it is reachable at all.

### Family A — The split point *(T0)*

Nothing today targets where a suit's two halves meet. Measured split points across 1 464 suits
(ranks taken from the up end):

```
up=1   9  |  up=5 176  |  up=9  173  |  up=13   4
up=2  34  |  up=6 204  |  up=10 146
up=3  70  |  up=7 208  |  up=11 106
up=4 122  |  up=8 166  |  up=12  46
```

**A1 · `split-even` — "Split every suit exactly down the middle" (A–7 up, 8–K down).** Gold.
Check: every suit has exactly 7 up-events. Solver: pure gating (never send up above 7 or down
below 8). **Natural rate 0/366** — a real constraint, not a freebie.

**A2 · `down-heavy` — "Take at least 8 of every suit from the King end."** Silver.
Check: every suit's up-count ≤ 5. Solver: gating. Per-suit natural rate 411/1464 (28 %); all four
at once is rarer. Pushes play toward the down foundations, which players neglect.

### Family B — Build a suit from one end *(your idea; T0)*

Sharper than my earlier "one-end suit" because up and down are **very** different in difficulty:

| Variant | Natural rate |
|---|---|
| A suit built entirely **A→K** (straight up) | **4** / 1464 suits |
| A suit built entirely **K→A** (in reverse) | **0** / 1464 suits |
| Whole game using **only up** foundations | **0** / 366 |
| Whole game using **only down** foundations | **0** / 366 |

Reverse is much harder, and the reason is instructive: to build K→A you must withhold that suit's
Ace for twelve sends, and the Ace is the card auto-play most wants to send up.

**B1 · `suit-all-up` — "Build one whole suit from Ace to King."** Gold. Gating: for the chosen
suit, never use its down end.

**B2 · `suit-all-down` — "Build one whole suit from King down to Ace."** Gold, harder than B1.

**B3 · `no-down-foundation` — "Purist: win without ever using a down foundation."** Gold.
This is legal — with `up[s] = 13` and `down[s] = 14`, `down == up + 1` holds, so the deal is won.
It turns Causeway into FreeCell-with-a-two-way-tableau for a day. Gating is trivial (never emit an
`end = down` move), so certification is sound by construction.

**B4 · `no-up-foundation` — "Upside down: win building every suit K→A."** Gold, the hardest thing
proposed here, and the most distinctive. Same trivial gate, mirrored.

**Risk:** B3/B4 are 0/366 naturally. They may prove infeasible on most seeds — but they are the
cheapest of all ideas to test (one gate, one certify run), so the answer is a few minutes away.

### Family C — Suit runs *(your ideas; T0; the best difficulty dials found)*

**C1 · `suit-run-N` — "Send N cards of one suit to the foundations back-to-back."**
An unbroken same-suit run anywhere in the stream. Measured natural rates:

| N | 4 | 5 | 6 | 7 | 8 | 10 | 13 |
|---|---|---|---|---|---|---|---|
| lines | 87 % | 54 % | **29 %** | 13 % | **6 %** | 2 % | 0 % |

A textbook tunable objective — **N = 6 for Silver, N = 8 for Gold**, with room to derive N per seed.
Rejected at N ≤ 4 (87 % is nearly free).

**C2 · `suit-opener-N` — "Send N cards of one suit home before any other card."**
The same idea anchored at the start. Measured:

| N | 3 | 4 | 5 | 6 | 13 |
|---|---|---|---|---|---|
| lines | 17 % | **11 %** | 3 % | 2 % | 0 % |

**This supersedes `suit-sprint`.** `suit-sprint` *is* C2 at N = 13 — "finish a whole suit before a
second suit starts" — which is precisely why it is supported by 4 seeds and appears 3 days a year.
Parameterising the same idea at N = 4 gives ~11 % natural support before any constrained solving,
reviving a family that is currently dead weight. **[DECIDE]** adopt C2 and stop certifying
`suit-sprint` on new seeds (it cannot be deleted — see §5).

*Suit choice:* both are cheapest as "some suit" (solver tries each). Naming a specific suit
("six hearts in a row") reads better but requires the pool record to carry which suit is
achievable — a schema addition. **[DECIDE]** flavour vs. cost; I lean suit-agnostic first.

### Family D — Tempo *(T0)*

`down-openers-20` is the only "by move N" objective and the rarest Silver. The family generalises
cheaply because `foundationOrder` already stores `moveIdx`.

**D1 · `aces-up-by-N` — "All four Aces home within your first N moves."** Silver.
Natural rate 15/366 at N = 20; N ≈ 25 looks like the right band.

**D2 · `half-home-by-N` — "Half the deck home by move N."** Silver.
The 26th card lands at median move **59** (range 37–87), so N ≈ 50 is a real but fair target. It
rewards steady throughput — a skill no current objective touches.

**D3 · `down-openers-N` — parameterise the existing objective** rather than hard-coding 20,
deriving N from `par` like `moves` does. Not new variety, but it lifts support beyond today's
147/366.

### Family E — Free-cell configuration *(your idea; T1)*

The first objective family about a *board configuration* rather than counts or order. Measured:

| Configuration ever reached | Natural rate |
|---|---|
| All three cells occupied at once | **366 / 366** — vacuous on its own |
| Two cells holding the same rank | 264 / 366 (72 %) — too easy |
| Three cells holding **three consecutive ranks** | **74 / 366 (20 %)** |
| Three cells holding **three of the same rank** | **8 / 366 (2 %)** |

So the idea works, but *only if the set is specific* — "fill the free cells" alone is free, because
every optimal line already fills them.

**E1 · `cells-straight` — "Hold three cards in sequence in the free cells at once" (e.g. 6-7-8).**
Silver. 20 % natural.

**E2 · `cells-three-of-a-kind` — "Park three of a kind in the free cells at once" (e.g. three
Kings).** Gold. 2 % natural — memorable and genuinely hard.

*Cost:* T1, but **cheaper than expected**. The checker needs only the set of rank-triples ever held
while all three cells were full — measured at a median of **7 distinct triples per game (max 12)**,
about **63 bytes** (worst case ~108). That is a small, objective-agnostic addition to `Telemetry`,
not an event log.

*Solver:* this is a **positive/existential** goal like `down-openers-20`, not a gate — the search
must *reach* a state, so the node key gains an "achieved" flag. New shape, but precedent exists.

### Family F — Move shape *(T1; makes the tableau matter)*

**F1 · `no-supermoves` — "Move one card at a time."** Silver. Natural rate 52/366 (14 %).

**F2 · `one-big-move` — "Relocate a run of 5+ cards in a single move."** Gold. 15/366 (4 %).
Positive rather than prohibitive, and the only proposal that rewards *using* supermove capacity.

*Cost:* T1 — one `maxRunMoved` scalar.

## 5. Ideas I tested and am NOT proposing

Recording these with their measurements so they are not re-invented:

| Idea | Measurement | Verdict |
|---|---|---|
| "Fill the free cells" (unqualified) | **366/366** | **Vacuous** — every optimal line fills them. Only a *specific* set is an objective (Family E). |
| Two cells holding the same rank | 264/366 (72 %) | Too easy. |
| `suit-run-N` at N ≤ 4 | 87 % | Too easy; the dial only bites from N = 5. |
| `strong-finish` — last 13 cards in ≤ 13 moves | median **13**, minimum **13** | **Vacuous.** The endgame is always a clean cascade. |
| Resurrect `empty-column` with "while ≥ K cards remain" | 349/366 qualify even at K = 35; median board size at first empty column is 46 of 52 | **Still nearly free.** Would need K ≥ 45 to bite, and then it is a coin flip, not a skill. |
| `rainbow` — no two consecutive sends from the same suit | **0/366** | Likely infeasible — endgame cascades force same-suit runs. The exact opposite of C1, and a good illustration of why C1 works. |
| `finish-suits-in-order` — ♠ then ♥ then ♦ then ♣ | not measured | Suspect it is C2 at N = 13, four times over — i.e. another 1 %-support dud. |
| Any **universal** objective | 123/366 days rewritten | Blocked by Rule 1. |
| Time caps, manual-win | — | Settled in the original design; unchanged. |

**On `suit-sprint` [DECIDE]:** it cannot be removed from the `GOLD` array (that rewrites history),
but new pool records simply need not certify it. Adopting **C2** makes this natural: C2 at N = 13 is
the same objective, so the family survives in tunable form while the unusable extreme quietly stops
appearing after day 365.

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

Ordered so the cheap, high-information steps come first and no app code is written on a hunch.

1. **Build a feasibility probe** (`tools/solver/probe-objective.mjs`). Replays the 366 baked lines
   and reports how often a candidate checker passes — every number in this document came from an
   ad-hoc version of it. It killed four ideas (`strong-finish`, `empty-column`, unqualified
   cell-filling, `suit-run` at N ≤ 4) in minutes. *Cheapest, highest-leverage step.*
2. **Decide the shortlist** from §4, plus the `suit-sprint`/C2 question in §5 and the §6 refactor.
3. **Ship the T0 families first (A–D).** Checkers go in `tests/daily.mjs` (canonical) → mirrored
   into `index.html` and `Model/Daily.swift` → drift guards extended. No schema change, no app
   state change; these are the low-risk wins and they already cover the two biggest gaps (the split
   point and the tableau-adjacent suit runs).
4. **Solver work, cheapest first.** B3/B4 (`no-down-foundation` / `no-up-foundation`) are one-line
   gates and answer the most interesting feasibility question, so do them first. Then A1/A2, B1/B2,
   C1/C2 (all gates), then D (prefix goals, reusing the `down-openers` shape). **Certify a 40-seed
   sample and drop anything under ~10 %.**
5. **Extend the pool** with `build-pool.mjs --start 10377` against the enlarged objective set, then
   rebuild solutions. This refills the calendar past Aug 2027 *and* debuts the new objectives — the
   one moment where both can happen without a history migration.
6. **T1 families (E, F) last, as their own change.** They add `cellTriples` (~63 bytes, median 7
   entries) and `maxRunMoved` to `Telemetry`, which is persisted inside the saved game on both
   platforms — so it deserves an independent review pass and a resume round-trip test.

## 8. Risks

- **Support rate is unknown until certification.** The most distinctive ideas are the least
  proven: A1 (`split-even`), B3/B4 (one-end games) and E2 (three of a kind) are all 0–2 %
  naturally. That is *expected* — it is what makes them objectives rather than freebies — but some
  will come back uncertifiable. Step 4 finds out for the price of one solver run.
- **Existential goals cost solver time.** Families E and D need the search to *reach* a state
  rather than merely avoid one, which adds a flag to the node key and enlarges the space. Gating
  objectives (A, B, C) stay cheap; budget certification time accordingly.
- **T1 changes the persisted `Telemetry` shape.** Both platforms decode it defensively today, so an
  added field is backward-compatible — but the drift guards need extending and an in-progress
  challenge must survive a save/restore round trip.
- **Catalogue bloat.** Going from 11 to ~20 objectives lengthens the tail of rarely-seen ones. The
  ~10 % support bar and the C2-supersedes-`suit-sprint` cleanup are there to keep the set curated
  rather than merely larger.
- **Two ideas here overlap deliberately.** C1 (run anywhere) and C2 (run at the start) are close
  cousins, as are B1/B2 and B3/B4. If the catalogue feels crowded, ship one of each pair first and
  add the sibling only if the family plays well.
