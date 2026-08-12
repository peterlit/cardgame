# Daily Challenges — design

**Status:** design approved (concept level); not yet implemented. This document is the
authoritative reference; every decision below was signed off during design review. Implementation
begins with Phase 0 (the solver + pool).

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

## 4. Objective catalog (frozen)

All objectives are checkable from lightweight per-attempt telemetry (see §8). Each has an
**eligibility** class that determines what the offline solver must prove:

- **Universal** — achievable on *any* winnable deal (the solver only supplies a *par* for
  calibration). These constrain *how well* you win, not *whether* a winning line exists.
- **Certified** — the objective restricts the winning line itself, so the deal must be proven
  winnable **subject to the constraint**, per seed. Offered only on seeds certified to support it.

| # | Objective | Tier | Eligibility | Runtime check |
|---|-----------|------|-------------|---------------|
| 1 | Clear the deal | 🥉 | Universal (winnable + par) | `won` |
| 2 | Win in ≤ N moves | 🥈 | Universal (par → N) | `moveCount ≤ N` |
| 3 | Win in ≤ T time | 🥈 | Universal (soft, par-derived) | `elapsed ≤ T` |
| 4 | Win without undo | 🥈 | Universal | `undoCount == 0` |
| 5 | Manual win — no auto-play / auto-finish | 🥈 | Universal | automation-used flags false |
| 6 | ≤ K free-cell uses (K = 1 or 2) | 🥈 | Certified | cumulative cell-entries ≤ K |
| 7 | Start all four down-foundations within the first N moves | 🥈 | Certified (+par) | milestone + move index |
| 8 | Empty a tableau column at some point | 🥈 | Certified | board-state event |
| 9 | **No** free cell ever touched | 🥇 | Certified | cell-entries == 0 |
| 10 | All **Kings down** before any Ace goes up | 🥇 | Certified | foundation order |
| 11 | All **Jacks to the down-foundation** before any Ace goes up | 🥇 | Certified | foundation order |
| 12 | **Every suit built top-down** — its King (down) home before its Ace (up) | 🥇 | Certified | foundation order |
| 13 | All **Aces up** before any other card goes home (hard; rare) | 🥇 | Certified | foundation order |
| 14 | **Suit sprint** — finish one whole suit before a second suit sends any card home | 🥈/🥇 | Certified | foundation order |

The two-way-foundation cluster (10–13) is the signature — nothing in FreeCell can pose "build from
the top" objectives. Aces-first (13) is deliberately hard and therefore appears rarely, only on
certified seeds; the calendar never demands the impossible.

**Metric definitions**
- Free-cell **uses** = cumulative number of cards parked into a cell (K = 0 ⇒ a cell is never
  touched). Peak simultaneous occupancy is available as a softer variant if we want it later.
- **Time caps** cannot be calibrated exactly and deterministically, so they are treated as
  **generous, par-derived estimates**, not tight targets.

**Silver vs Gold assignment.** Silver is drawn from the Silver-eligible set (universal ones + any
Silver-grade certified objective this seed supports); Gold is drawn from the seed's certified
Gold-grade set. The generator rotates objective families across days (deterministically) for
variety (see §6).

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

---

## 7. Deterministic generation & frozen history

`dailyChallenge(dateKey) → { seed, silverObjective, goldObjective }`, a pure function:

1. Seed `mulberry32` with the date (e.g. `YYYYMMDD` as an integer, or a day-index since an epoch).
2. Pick a `seed` from the **frozen, append-only** daily-eligible list.
3. Pick the Silver objective from the Silver-eligible set (rotating families for variety).
4. Pick the Gold objective from that seed's certified Gold set.

**Freezing (critical).** Once a date has shipped, its challenge must never change — otherwise
growing the pool or re-tuning par would silently rewrite old days and invalidate streaks and bests.
Therefore:
- The generator **indexes into a frozen ordered list**; appending new certified seeds to the *end*
  never shifts any past-date output.
- Par values and objective params used by past dates are pinned (the baked file is versioned; a new
  version affects only dates on/after its introduction).

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

**Streaks are derived, not stored.** All six streak numbers are computed from `days` on demand, so
there are no counters to drift:

- 🔥 **Play streak** — consecutive calendar days with `bronze`.
- 🥈 **Silver streak** — consecutive days with `silver`.
- 🥇 **Gold streak** — consecutive days with `gold`.
- Each has a **current** value (the run of consecutive completed days ending at today, or yesterday
  if today isn't done yet) and an **all-time longest**.

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
  play it; future days are locked. Optional monthly-completion badge.
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

## 12. Open items (to settle before/within implementation)

- **In-progress slot:** does starting a challenge replace the casual in-progress game (like dealing
  a number does today), or does challenge play get its own resume slot? Leaning: reuse the single
  game context for MVP; revisit if it feels wrong.
- **Move-cap margins & time-cap formula:** exact `N = f(par)` per objective and the seconds-per-move
  estimate for time caps — tune during Phase 1 with real play.
- **Monthly badge:** whether completing a full month grants a distinct trophy (nice, Phase 2).
- **Objective-family rotation:** the exact deterministic rotation that keeps variety high across a
  week/month.
- **Pool size / repeat spacing:** how many certified seeds to ship initially and how the generator
  spaces repeats.

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
