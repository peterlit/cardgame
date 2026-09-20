# Daily Challenges — design

> **2026-09-20 — October appended.** `days[61..91]` (Oct 1–31 2026) were added with
> `build-month.mjs --extend`, so the pool now runs 2026-08-01..2026-10-31 (92 days); every
> published August/September day is byte-identical, no (Silver, Gold) pair repeats across the seam,
> and every new day is flawless-certified with bronze, gold and flawless lines baked. A distinct silver
> line is baked on the 24 new days whose Silver constrains the search; the other 7 (Oct 2, 4, 6, 9, 13,
> 27, 30 — universal `moves`/`no-undo` Silvers, already satisfied by the bronze line) bake none and
> show three how-to-win pills by design, exactly as the 16 such August/September days do. Where the notes below say
> "two months" or "61 days", read three months / 92 days.

> ## ⚠ 2026-08-30 REBUILD — read this first
>
> The calendar was rebuilt again on **2026-08-30**, on top of the 2026-08-23 recut below:
>
> - **Every day is FLAWLESS-CERTIFIED.** The generator now proves, per day, that ONE line wins and
>   satisfies both objectives before that day may ship — so 🌟 Flawless is reachable on every date.
>   Previously Silver and Gold were certified independently and three August days were provably
>   impossible. `certifyFlawless` / `contradiction` in `tools/solver/solve.mjs`; the gate is in
>   `build-month.mjs`'s greedy pick. See [`solver.md`](solver.md) §7.7.
> - **Two months are seeded** — August *and* September 2026 (61 days), epoch unchanged at
>   2026-08-01, so `days[]` simply runs 0-60.
> - **"How to win flawless"** — `daily-solutions.json` is v3 and bakes the certified flawless line
>   per day, offered as a fourth 🌟 demo button beside 🥉/🥈/🥇.
> - **⏰ Same-day recognition** — clearing a day *on its own date* earns a fourth boolean on the
>   record (`onTime`), a fifth streak, a calendar pip and a win-overlay callout. Orthogonal to the
>   tiers: it records WHEN, not how well. §12 has the design.
> - **History was nuked again** (daily store v2 → **v3**): every day was re-picked, so a stored
>   record's day index names a different challenge.
>
> The 2026-08-23 recut, still current except where the above supersedes it:
>
> The daily system was **rebuilt on 2026-08-23** and much of the design record below is now history.
> What changed:
>
> - **Every objective is a parameterised FAMILY**, not a fixed rule. `cells-le{N}`, `split-at{R}`,
>   `end-bias{end,min}`, `ends-first{up,down}`, `rank-rush{rank,N}` … — 13 families that generate
>   hundreds of visibly different challenges. §4 below is rewritten; the old frozen catalog is kept
>   only as the *why*.
> - **No runtime RNG.** The offline generator picks each day's seed *and* both objectives
>   deliberately, maximising variety across the month, and writes them into the pool. §7's per-day
>   `mulberry32` draw is gone.
> - **The calendar is one month.** Epoch moved to **2026-08-01** (day 0); the pool holds exactly the
>   31 days of August 2026 and nothing else. Days outside it have no challenge.
> - **Challenge deals are drawn from seeds 500,001-1,000,000**, at or below the app's single deal
>   ceiling `maxSeed = 1,000,000`. The old "IDs > 10,000" reservation and the > 10,000,000 playtest
>   sandbox are both gone.
> - **All prior challenge history was deliberately nuked** — a stored record's day index names a
>   different challenge now, so both platforms drop any pre-v2 daily store (and prune wins on seeds
>   the app can no longer deal).
>
> The generator is `tools/solver/build-month.mjs` (`build-pool.mjs` is deleted). The catalogue,
> checkers and lookup are `tests/daily.mjs`, mirrored in `index.html` and `Model/Daily.swift`.

**Status: SHIPPED on both platforms** (web + iOS). This document is the original design record —
every decision below was signed off during design review — kept for the *why*. Where the built
feature differs from the plan, an **As built** note says so; §12 and §13 record how the open items
and roadmap actually resolved.

For how it is implemented rather than why, see
[`architecture/overview.md`](architecture/overview.md) §5 and the per-platform docs. The canonical
logic lives in `tests/daily.mjs`, mirrored into `index.html` and
`ios/Causeway/Causeway/Model/Daily.swift`, with drift guards in `tests/daily.test.mjs` and
`tests/ios-parity.test.mjs`.

A MobilityWare-FreeCell-style daily-challenge feature for Causeway: each calendar day serves a
featured deal with a small set of graded objectives; the player earns a badge per day and builds
streaks. Adapted to Causeway's offline, no-account, two-way-foundation nature.

---

## 1. Goals & non-goals

**Goals**
- A fresh, dated challenge every day that feels hand-authored but is generated locally.
- Graded objectives (win → optimize → play with style) that give one board real replay value.
- Objectives that celebrate Causeway's signature mechanic: foundations built from *both* ends.
- Personal progression: per-day badges, a calendar, and streaks.

**Non-goals**
- No leaderboards, friends, or social features (would require a server; the app is deliberately
  offline and account-free).
- No monetization / energy / lives.
- Not a general achievements system (that could come later; this is date-scoped daily play).

---

## 2. Constraints & principles

- **Offline & deterministic.** No server or accounts (a privacy stance). The day's challenge is a
  pure function of the calendar date, computed identically on web and iOS. We already have the
  primitive: `mulberry32`-seeded deals are byte-identical across platforms. Free consequences:
  **past days are replayable** and **every device shows the same daily** with zero coordination.
- **Parity is a tested contract.** The `date → challenge` generator and the objective checkers live
  in the shared engine and get golden Node tests + drift-guard coverage, like the rest of the
  engine. The baked solver-pool file is shared byte-for-byte between platforms.
- **Anti-frustration.** Winning the deal is all that's required to "complete" a day and hold a
  streak; the harder objectives are optional stretch stars, so a day can never become a wall.
- **Reserved deal space.** The daily pool draws only from **deal IDs > 10,000**. IDs 1–10,000 stay
  reserved for players' personal goals (winning a chosen range via `Deal #` / the Wins ranges), so
  daily play never collides with personal range-play.
- **History is frozen.** Once a date's challenge has shipped it must never change (see §7).

---

## 3. Core model — "Deal of the Day," tiered

One featured deal per day. Three graded tiers on that single deal:

| Tier | Meaning | Required? |
|------|---------|-----------|
| 🥉 **Bronze** | Clear the deal (win) | **Yes** — Bronze = the day is complete and the streak continues |
| 🥈 **Silver** | Win under a moderate constraint (one objective) | Optional stretch star |
| 🥇 **Gold** | Win under a harder style/ordering constraint (one objective) | Optional stretch star |

**Exactly one Silver objective and one Gold objective per day.** Bronze is always "win." Decoupling
day-completion (Bronze) from the constraints is the core anti-frustration decision: you can never be
locked out of a day because a cap was too tight — you still get the day, just not all three stars.

The player may **retry the deal freely**; the best tier reached and best moves/time are kept.

---

## 4. Objective catalogue — parameterised families

*(Rewritten in the 2026-08 recut. The original fixed catalog is preserved at the end of this
section, because the eligibility distinction it introduced still governs the solver.)*

All objectives are checkable from lightweight per-attempt telemetry (see §8). Each has an
**eligibility** class that determines what the offline solver must prove:

- **Universal** — achievable on *any* winnable deal (the solver only supplies a *par* for
  calibration). These constrain *how well* you win, not *whether* a winning line exists.
- **Certified** — the objective restricts the winning line itself, so the deal must be proven
  winnable **subject to that objective AND its parameter**, per seed. Offered only on seeds
  certified for that exact `(family, parameter)` pair.

Every family below takes a parameter, and the generator varies it deliberately across the month.
The full certification matrix — which parameter values are tried on every candidate seed — is
`VARIANTS` in `tools/solver/solve.mjs`.

| Family | Tier | Elig. | Parameter | Example label |
|---|---|---|---|---|
| `moves` | 🥈 | Univ. | `N` (par x 1.05-1.4) | "Win in 96 moves or fewer" |
| `no-undo` | 🥈 | Univ. | — | "Win without using undo" |
| `cells-le` | 🥈/🥇 | Cert. | `N` = 0-3 | "Win using free cells at most twice" (`N`=0 is Gold) |
| `max-run` | 🥈 | Cert. | `N` = 1-3 | "Never move more than 2 cards in a single move" |
| `big-move` | 🥇 | Cert. | `N` = 5-7 | "Move a run of 6 or more cards in a single move" |
| `split-at` | 🥇 | Cert. | `R` = 3-10 | "Split every suit exactly at the Nine — A-9 up, 10-K down" |
| `end-bias` | 🥈/🥇 | Cert. | `end`, `min` = 7-13 | "Take at least 9 of every suit from the Ace end"; `min`=13 is the one-end game |
| `ends-first` | 🥇 | Cert. | `up` 0-3, `down` 10-14 | "Send all four Aces and Twos, plus all four Kings and Queens home before any other card" |
| `before-ace` | 🥇 | Cert. | `rank` 10-13 | "Get every Queen onto the King-end foundation before any Ace goes home" |
| `suit-top-first` | 🥇 | Cert. | `rank` 11-13 | "For every suit, send its Queen home from the King end before its Ace" |
| `suit-sprint` | 🥇 | Cert. | — | "Finish one whole suit before any other suit is started" |
| `rank-rush` | 🥈 | Cert. | `rank`, `N` | "Get all four Kings home within your first 18 moves" |
| `suit-balance` | 🥈/🥇 | Cert. | `N` = 2-5 | "Never let one suit get more than 3 cards ahead of another" |

**Grades are a function of the parameter**, not of the family: `cells-le{0}` is Gold and
`cells-le{2}` is Silver; `end-bias{min:13}` is Gold and `end-bias{min:8}` is Silver. `gradeOf()`
owns that rule on all three platforms.

**How the old catalog maps in.** Every shipped objective survives as a parameter of a family:
`no-cells` = `cells-le{0}`; `cells-le-1/2` = `cells-le{1/2}`; `aces-first` = `ends-first{up:1}`;
`kings-first` = `before-ace{13}`; `jacks-down-first` = `before-ace{11}`; `suits-top-down` =
`suit-top-first{13}`; `split-even` = `split-at{7}`; `down-heavy` = `end-bias{down,8}`;
`no-down-foundation` / `no-up-foundation` = `end-bias{up,13}` / `end-bias{down,13}`;
`no-supermoves` = `max-run{1}`; `one-big-move` = `big-move{5}`; `down-openers-20` ≈
`rank-rush{13,20}`. Three families are genuinely new: **`ends-first`** with both ends specified,
**`rank-rush`** at any rank, and **`suit-balance`**.

**`rank-rush` deadlines are certified, not guessed.** A middling rank cannot come home early (rank
R from the Ace end needs A..R of every suit first), so only ranks near either extreme are searched,
and the builder then re-searches against the witness line's own completion index until it stops
improving. The `N` in the shipped label is a deadline a real line actually met.

**Metric definitions**
- Free-cell **uses** = cumulative number of cards parked into a cell (`N` = 0 ⇒ a cell is never
  touched). Peak simultaneous occupancy is available as a softer variant if we want it later.
- **Time caps** were never built: a deterministic, fair time target could not be calibrated.
- **Manual win** (no auto-play / auto-finish) was never built either — the automation policy in §5
  makes automation the player's responsibility rather than a tracked flag.
- **"Empty a tableau column"** stays dropped: it is vacuously true of every win. Its absence is
  pinned by `tests/solver.test.mjs` so it cannot be reintroduced by accident.

The two-way-foundation cluster (`ends-first`, `before-ace`, `suit-top-first`, `split-at`,
`end-bias`) is the signature — nothing in FreeCell can pose "build from the top" objectives.

---

## 5. Automation policy (decided: player responsibility)

Causeway's auto-play (sends *safe* cards home automatically) and auto-finish will happily send a
card home that **breaks an ordering objective** — "safe" ≠ "constraint-compatible." The decision:
**do nothing special.** Automation behaves identically in casual and challenge play; if it sends a
card that violates the active objective, **that objective simply fails**. The player is expected to
turn Auto-play / Auto-finish off up front when a challenge calls for it.

Consequences (all simplifying):
- **No special challenge mode** for automation — no "disable" session, no constraint-aware
  auto-play, none of that code or its edge cases.
- **Uniform evaluation.** The objective checker watches the stream of cards reaching the
  foundations and does not care whether the player or auto-play moved a card — a violating card
  fails the objective regardless of source. Auto-play moves also count toward move budgets exactly
  like manual moves (keeping the move cap honest against the solver's par).
- **UI obligation (so it isn't a hidden trap):** the challenge card states each objective plainly
  and keeps the Auto-play / Auto-finish toggles visible during the attempt, so the "should I turn
  this off?" choice is in front of the player.

---

## 6. Solver & certified pool (Phase 0 — the prerequisite)

Causeway currently has **no winnability guarantee** (backlog I2). A daily "win this" challenge is
untenable without one, and ordering objectives need something stronger still. Phase 0 builds an
**offline constrained solver** that certifies seeds and bakes the results into the app. This
retires I2 as a bonus.

**Per-seed output schema** (produced offline, over candidate seeds > 10,000):

```json
{
  "seed": 428173,
  "winnable": true,
  "par": 118,                              // min moves to win (unconstrained)
  "supports": ["no-cells", "kings-first", "jacks-down-first", "empty-column"],
  "constraintPar": { "no-cells": 131, "kings-first": 124 }
}
```

- `winnable` + `par`: powers Bronze and all Universal objectives (Silver move cap `N = par + margin`,
  tunable per objective; time cap derived generously from par).
- `supports[]`: the Certified objectives this seed admits — a Gold/Silver objective is only ever
  offered on a seed that lists it.
- `constraintPar{}`: per-constraint par where a tighter cap is wanted under the constraint.

**Solver nature.** A search (e.g. IDA*/DFS with a transposition table + admissible heuristic) that
Causeway's two-way foundations + supermoves make non-trivial but tractable offline. For each
constraint it must find (or prove absent) a *winning line that obeys the constraint*. It runs
**offline only** — never in the shipped app.

**Baked pool.** The certified results ship as a small JSON file, **shared verbatim** across web and
iOS. Only seeds with `winnable: true` **and** at least one certified Gold-grade objective are
"daily-eligible" (a day needs a real Gold). The pool file is **versioned** and **append-only** (see
§7).

> **As built** — `data/daily-pool.json` holds **366 seeds** (10001–10376), one per day for a year.
> "Shared verbatim" is literally true: the file is byte-identical to the copy in the iOS bundle
> (SHA-256 verified), as is `data/daily-solutions.json`, which was added later for "Show me how to
> win". The web `fetch`es both from its own origin; iOS reads them from `Bundle.main`. One practical
> consequence: opening `index.html` from `file://` cannot fetch, so Daily is disabled there while the
> rest of the game plays normally.

---

## 7. Generation (rewritten in the 2026-08 recut)

`dailyChallenge(dayIndex, pool) → { seed, par, silver, gold }` is a **pure table lookup**:

1. The day index is `daysFromCivil(y,m,d) - EPOCH_DAYS`, where `EPOCH_DAYS = daysFromCivil(2026, 8, 1)`
   — day 0 is 2026-08-01, using the device's **local** calendar date.
2. `pool.days[D]` names that day's seed, its par, and both objectives with their parameters.
3. Labels and grades are computed from the parameters at read time.

There is **no runtime RNG at all**. The choice happens offline, once, in
`tools/solver/build-month.mjs`, which:

- draws candidate seeds deterministically from 500,001-1,000,000,
- certifies each against the whole `(family, parameter)` matrix in parallel worker processes, with a
  resumable JSONL cache,
- then fills the month greedily, at each step taking the `(seed, gold, silver)` triple that adds the
  most **new** variety — an unused family scores far above an unused parameter of a family already
  used, and a certification only a few seeds support is preferred over a common one, since rare
  material is the hardest to place,
- and finally reorders the chosen days so no two consecutive dates share a family.

**Why history is no longer "frozen."** The old design froze the calendar because a per-day RNG over
an append-only pool would otherwise reshuffle past days. With the choice baked per day, the pool
file *is* the history: a day changes only if someone edits that day's record. The recut deliberately
rewrote every day, which is exactly why both platforms drop pre-v2 stored records (§9) rather than
crediting tiers against challenges that no longer exist.

**Time zone.** "Today" uses the **device-local calendar date**. Midnight boundaries / timezone
travel are a minor documented edge; no server truth to reconcile against.

---

## 8. Telemetry & evaluation

A **ChallengeTracker** records per-attempt data, active during a challenge attempt and reset on
retry / new deal:

- `moveCount`, `elapsed` (already exist).
- `freeCellUses` (cumulative cards parked), optionally `peakCellOccupancy`.
- `undoCount`.
- `usedAutoplay` / `usedAutoFinish` flags.
- `foundationOrder`: the ordered stream of cards reaching a foundation, each with its move index and
  end (up/down) — this powers every ordering objective and the "down-openers within N moves" one.
- board-state events for `empty-column`.

**Evaluation timing**
- **Fail-fast** objectives (ordering, no-cells, no-undo) are marked failed the instant they are
  violated, so the live HUD can show it and the player can restart early.
- **At-win** objectives (move/time caps, empty-column success) are settled when the deal is won.
- On win, the tiers achieved are computed and the day's record updated.

**Retry semantics.** Unlimited retries per day; each attempt starts fresh from the seed. Best tier
and best moves/time are kept (monotonic — a later worse attempt never lowers a recorded best).

**Where an attempt "counts."** Challenges are attempted from the Challenges screen, which deals the
featured seed with the tracker + live HUD active. Casually dealing the same number via `Deal #` is
ordinary play and does not track objectives (the tracker/HUD aren't engaged). *(Open item: whether a
challenge attempt shares the single in-progress-resume slot with casual play or gets its own — see
§12.)*

---

## 9. Persistence & data model

A **DailyStore** mirrors the existing `WinStore` pattern (Codable/JSON in `UserDefaults` on iOS,
`localStorage` on web), under a key such as `causeway.daily`.

```
DailyRecord {
  bronze: Bool
  silver: Bool
  gold:   Bool
  bestMoves: Int?      // best winning attempt
  bestSecs:  Int?
}
DailyStore {
  version: Int                     // schema version FROM DAY ONE (WinStore lacking this is O2)
  days: [dateKey: DailyRecord]
}
```

> **As built** — the record is `TierResult` (`tests/daily.mjs`, `Model/Daily.swift:221`), with two
> changes: a fourth boolean **`flawless`**, and the best-score fields named **`moves` / `elapsed`**
> rather than `bestMoves` / `bestSecs`. The key is `dateKey = dayIndex` (an integer offset from the
> 2026-08-12 epoch), not a date string. Tiers OR-accumulate and best scores take the minimum via
> `mergeTiers`, so a later worse attempt can never lower a record. `DailyStore.version` is written
> but, as of today, never actually validated on load — forward tolerance comes instead from a
> permissive decoder that defaults every missing field.

**Streaks are derived, not stored.** All six streak numbers are computed from `days` on demand, so
there are no counters to drift:

- 🔥 **Play streak** — consecutive calendar days with `bronze`.
- 🥈 **Silver streak** — consecutive days with `silver`.
- 🥇 **Gold streak** — consecutive days with `gold`.
- Each has a **current** value (the run of consecutive completed days ending at today, or yesterday
  if today isn't done yet) and an **all-time longest**.

> **As built** — there are **four** streaks, not three: 🌟 Flawless joined the list. Each also
> reports a third number, **`total`** (lifetime days holding that tier), because a streak alone was
> misread — two non-consecutive Flawless days correctly showed a streak of 1, which looked like a
> lost record. The cards now read *streak / N total / best N*. The current-run anchor is: today if
> today was played **at all** (a played-but-missed today breaks that tier's run), else yesterday if
> played, else nothing.

**Catch-up friendly (decided).** Because past days are replayable, a streak is the longest run of
consecutive calendar *dates* all completed **whenever** completed — finishing yesterday's deal today
repairs the run. This is friendly, needs no anti-cheat (it's personal), and falls straight out of
the record with no "completed-at" timestamp.

---

## 10. UI/UX — dedicated Challenges & Streaks screen

A new screen (its own entry; the toolbar is already crowded), containing:

- **Header:** today's date and the three streaks (current, with best on tap).
- **Today's card:** Deal #, the three tiers with their objective text and 🥉/🥈/🥇 status, a **Play**
  button, and the visible Auto-play / Auto-finish state (per §5).
- **Month calendar:** one cell per day showing completion (badge + which stars). Tap a past day to
  play it; future days are locked. Optional monthly-completion badge. *(As built: the calendar
  shipped; the monthly badge did not. Flawless days show a ⭐ in place of the tier dots.)*
- **Live objectives HUD (during an attempt):** a small checklist over the board — the move counter
  ticks toward the cap; an ordering objective turns red the instant it's broken; etc. This live
  feedback is most of the feel.
- **Win overlay:** reports the tiers earned this attempt ("🥉🥈 — Gold missed: used 2 free cells").

---

## 11. Parity & testing

- The `date → challenge` generator and every objective checker live in the **shared engine**, with
  **golden tests** (date X → seed Y + objective set Z) and **drift-guard** coverage, exactly as the
  deal/RNG/`isSafeAutoplay`/`autoFinishWouldWin` logic is guarded today.
- The baked certified-pool JSON is **identical** on web and iOS (checked in once, referenced by
  both), so a given date yields the same challenge everywhere by construction.
- Objective checkers are tested against synthetic play traces (a `foundationOrder`/telemetry
  fixture → expected pass/fail per objective).
- The offline solver gets its own test surface (known-winnable and known-unwinnable seeds; a
  constrained solution, when claimed, is replayed and verified to actually win under the
  constraint).

---

## 12. Open items — how they resolved

- **In-progress slot** — ✅ **Settled as planned:** challenge play reuses the single game context.
  `challengeDay` rides along with the saved game (`causeway.game` / the web `localStorage` twin), so
  a challenge attempt survives backgrounding and reload. Starting a challenge re-deals, exactly like
  entering a deal number.
- **Move-cap margin** — ✅ **Settled:** `N = round(par × 1.2)` for the `moves` objective
  (`tests/daily.mjs:42`). See the shipped-data caveat in [`solver.md`](solver.md) §1: on 274 of 366
  days the stored `par` is the unconstrained length, making the cap up to ~14 % looser than intended.
- **Time-cap formula** — ❌ **Moot:** the time-cap objective was never built (§4 #3).
- **Monthly badge** — ❌ **Not built.** Never started; would be additive.
- **Objective-family rotation** — ✅ **Built in the 2026-08 recut**, and it is now the whole point:
  the offline generator maximises family and parameter variety across the month and spreads
  families so no two consecutive days share one. (Between the original build and the recut, the
  plain per-day RNG draw was judged sufficient.)
- **Pool size / repeat spacing** — ↩ **Resettled:** one seeded month (31 days), each seed used
  exactly once — so repeat spacing never arises. Seeding another month means running
  `build-month.mjs` again; it no longer grows by appending.

**Added after this design was written** (not anticipated here):

- 🌟 **Flawless** — a fourth tier for earning Bronze + Silver + Gold in a *single* attempt, rather
  than banking them across free retries. It gets its own streak, a calendar star, and a win-overlay
  callout.
  > ✅ **Certified since the 2026-08-30 rebuild.** Every seeded day now ships with a proven line
  > that earns all three tiers at once, and that same line is baked as the 🌟 "How to win flawless"
  > demo. Before the gate, three of August's 31 days were provably impossible (`suit-sprint` under a
  > Silver it contradicts; a 5-card run under "never move more than 2"). Gating cost no variety —
  > see [`solver.md`](solver.md) §7.7.

- ⏰ **Same-day** — recognition for clearing a day *on the date it posted*, added 2026-08-30 to give
  daily play a reason to be daily. It is **orthogonal to the tiers** (it records WHEN, not how well):
  a bare Bronze earned today counts, a Flawless replay of a past day does not. One boolean on the
  record (`onTime`), OR-accumulated like the tiers; **no timestamps are stored**, so there is nothing
  to drift and no new privacy surface.
  - **The rule** (`isOnTime`, shared core): the win lands on the challenge's own day index, OR the
    attempt *began* on that date and lands one day later. The grace clause is the anti-frustration
    rule for the late-evening start — but since **no clock time is stored**, it is day-granular: an
    attempt begun on day D counts if it is finished *any time on D+1*, not just just-after-midnight.
    That is knowingly generous (a tight midnight window would need a start timestamp, which §2 rules
    out); it is bounded by the fact that only the single in-progress attempt carries a start day, a
    game resumed two or more days later never counts, and a retry is a new attempt judged from today.
  - **An unprovable start day forfeits the grace.** The attempt's start day rides in the in-progress
    save alongside `challengeDay`. A save written before ⏰ shipped has no start day; on restore both
    platforms leave it *null* rather than assuming the challenge's own day. Assuming it would credit
    an attempt that cannot prove it — a **backfilled** day D begun today and finished after a
    relaunch on D+1 would be falsely awarded ⏰. With null, such a save can still earn ⏰ by winning
    on day D itself; the grace comes back only via **Replay**, which begins a provably-today attempt
    and so re-stamps the start day on both platforms (`restartDeal`).
  - **Its streak is strict.** 🔥 Play stays catch-up-repairable (finish yesterday's deal today and
    the run heals); ⏰ cannot be repaired, and that asymmetry is the incentive. Both are labelled in
    the UI so the difference is legible.
  - **Surfaces:** a fifth streak card, a line on the day card that states the rule *before* you play
    (so a past-day replay can't silently fail to earn it — and when yesterday's attempt is still in
    progress, that line switches to "resume your attempt today and it still counts", because the
    grace is live and Replay would forfeit it), a gold corner pip on earned calendar days,
    and a win-overlay callout with the running streak. Deliberately **no countdown timer** — the goal
    is a reason to open the app, not time pressure.
  - **Cheatability:** the device clock is authoritative and trivially spoofable. That is fine and
    consistent with §2 — the game is offline, account-free, and the streak is personal.
- **"Show me how to win"** — a baked, replayable winning line per tier
  (`data/daily-solutions.json`), animated as an assisted, pausable, single-steppable demo that is
  never scored. See [`solver.md`](solver.md) § Solutions.
- **Live objectives HUD** with "on track" detection — an objective shows a green ✓ the moment it is
  *locked in* (guaranteed by any completion), not merely un-violated.
- **Stats export/import** (iOS only) — a portable JSON backup of daily records and wins.

---

## 13. Roadmap

- **Phase 0 — prerequisite:** the offline constrained solver + the baked certified pool
  (winnable, par, supports, constraintPar) over seeds > 10,000. Retires backlog I2. *Gates
  everything below.*
- **Phase 1 — MVP:** Deal of the Day from the pool; Bronze + a couple of Silver/Gold objectives
  (moves, ≤K cells, one ordering objective); the three streaks; a simple recent-days list;
  persistence — both platforms, parity-tested.
- **Phase 2 — full:** the month calendar, the full objective catalog (incl. all two-way-foundation
  ones), the live objectives HUD, monthly badges.
- **Phase 3 — polish:** share cards, richer badges, animations.

> **As delivered.** **Phase 0 ✅** (`tools/solver/`, output `data/daily-pool.json`; retired backlog
> I2). **Phase 1 ✅ on both platforms** — the shared core landed as `tests/daily.mjs`, then was
> inlined into `index.html` and ported to `Model/Daily.swift`. **Phase 2 ✅ except monthly badges** —
> month calendar, the full *implemented* catalogue (§4) and the live objectives HUD all shipped.
> **Phase 3 ⏳ not started** — share cards and richer badges remain open; animations effectively
> landed along the way (card flight, sequential auto-finish reveal, demo playback). Two things not
> on this roadmap also shipped: 🌟 Flawless and "Show me how to win" (see §12).

---

## 14. Decisions log (design review)

1. **Model A** — one Deal of the Day, tiered (not multiple separate tasks).
2. **Solver-first**, with a certified pool restricted to **deal IDs > 10,000** (1–10,000 reserved
   for personal range-play).
3. **Bronze required; Silver + Gold optional** stretch stars.
4. **Past days replayable.**
5. Objective menu **frozen** as in §4 (down-foundation building, jacks-to-down-before-aces,
   move caps, limited/no free cells, aces-first — with per-seed certification guaranteeing every
   offered objective is beatable). **One Silver + one Gold per day.**
6. **Automation policy #3** — no special handling; a violating auto-move fails the objective; the
   player disables Auto-play/Auto-finish up front if needed.
7. **Dedicated Challenges & Streaks screen**, with Play / Silver / Gold streaks (current + longest).
