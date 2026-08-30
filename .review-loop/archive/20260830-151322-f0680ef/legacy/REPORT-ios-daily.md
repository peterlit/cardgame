# Review-loop final report — iOS Daily Challenges mirror (incl. Flawless)

**Result: CONVERGED** (round 1 of a 5-round budget). 0 open blockers/majors/minors.

Scope: the Swift/SwiftUI port of the whole Daily Challenges feature (the shared logic, telemetry,
DailyStore, Challenges & Streaks screen, live HUD, win-overlay tiers, and the Flawless tier +
streak). Loop-start SHA `b7a8477`; fixes in `f49cf43`. (Web Flawless loop archived under
`.review-loop/REPORT-web-flawless.md`.)

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 0 | 0 | 0 | 4 | 0 | -4 | converged |

Seed review filed F1–F4 (all minor); all resolved the same round (F1/F2/F4 fixed, F3 declined and
accepted). No new findings introduced by the fixes.

## What the review found

The port was judged **unusually faithful** — the skeptical pass specifically verified and cleared
the high-risk seams and found no behavioral divergence from the Node-tested web core:

- The per-day RNG seed `UInt32(truncatingIfNeeded: 0x9e3779b9 ^ (dayIndex+1))` matches `(…) >>> 0`
  across the whole day range, and the two `rng.int` picks (silver then gold) keep the same order —
  so no past day reshuffles.
- `recordHomed` appends exactly the cards homed each move, up-ascending then down-descending, with
  `moveIdx` = the post-increment `moveCount`, at every commit point (commit / autoplay ×2 / finish).
- `undo` rolls back `foundationOrder` + `cellUses` but not `undos`; `cellUses` counts only genuine
  tableau→cell parks; telemetry survives save/restore; `mergeTiers`/`evaluateChallenge`/`streaks`
  and the Flawless derivation match line-for-line.
- The bundled pool is byte-identical to `data/daily-pool.json` (366 seeds, every seed carries ≥1
  gold objective).

The four minors caught (all latent, none reachable with shipped inputs, but worth hardening):

- **F1 [minor]** — `daysFromCivil` used Swift truncating `/` where the JS reference wraps in
  `Math.floor`; the two diverge only for negative numerators (pre-year-1 dates). Fixed with
  `floorDiv`/`floorMod` helpers, provably inert for the app's real (year ≥ 2026) inputs
  (`daysFromCivil(2026,8,12)` stays `EPOCH_DAYS`, `dayIndexFor(2026,8,12) == 0`). The calendar
  weekday expression was hardened to floor-mod too.
- **F2 [minor]** — an empty `silverPool`/`goldPool` would make `pool[rng.int(0)]` a hard
  out-of-bounds **crash** (where web merely misrenders). Unreachable with today's pool, but a
  crash-on-append footgun. Fixed: `dailyChallenge` returns `nil` (the "no challenge" path callers
  already handle) when either pool is empty — placed so the normal-path RNG order/count is unchanged.
- **F3 [minor]** — three stacked `.sheet(isPresented:)` on one view. **Declined (accepted):** the
  "last sheet wins" limitation was pre-iOS-16; the target is iOS 17 and all three sheets were
  verified presenting on device this session.
- **F4 [minor]** — `ForEach(0..<first, id:\.self)` used a dynamic constant-range for the calendar's
  leading blanks (SwiftUI warns / mis-diffs on a month rollover). Fixed with stable negative ids
  that can't collide with the positive day-cell ids; visual output unchanged.

## On-device verification (this session)

Built and ran on the iPhone 17 Pro simulator. Confirmed: the Daily pill opens the Challenges &
Streaks screen; four streak cards render (Play / Silver / Gold / **Flawless**); the day card shows
Deal #10,001 with Bronze (Clear the deal) / Silver (Win in 100 moves) / Gold (aces-first) — the
**same challenge the web generates for day 0**; the month calendar highlights today with correct
weekday alignment (Aug 1 on Saturday) and carries the 🌟 legend; tapping Play deals the challenge
seed and shows the live objectives HUD over the board. Rebuilt clean after the fixes.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **The telemetry seam in `Model/Game.swift` (`recordHomed`/`snapshot`/`undo`/`autoplayOneStep`/
   `finishStep`).** Same invariant as web — "at most one card homed per move," reconstructed by
   diffing foundations against the pre-move snapshot. **Play-test on device:** win a daily with heavy
   undo/redo and with auto-finish, and confirm the awarded tiers (and a Flawless run) match what you
   actually did. There is no XCTest coverage on iOS yet — the logic is validated only by the Node
   suite it mirrors (see BACKLOG "daily logic … Node suite").
2. **Trusted-telemetry stance.** Scoring believes the app's reported stream (no re-simulation), same
   as web — fine for a local, single-player, no-server game, but a telemetry bug shows up as a wrong
   tier, not a crash.
3. **`daysFromCivil` floor-division change (`f49cf43`).** A low-level arithmetic change with a wide
   reach in principle; verified inert for real dates and corrected for negatives. Eyeball the calendar
   weekday alignment once around a real month boundary.
4. **First real day boundary.** The epoch is today (2026-08-12) — day 0 is the only playable day
   this session. Worth an eyeball at the next daily rollover that the calendar advances and a new
   day unlocks.

## Verdict
Converged: a faithful Swift port whose only issues were four latent minors (a negative-year
floor-division gap, an empty-pool crash footgun, a stacked-sheet non-issue, and a dynamic-range
ForEach) — three fixed, one soundly declined, no regressions, builds + runs on device. The Daily
Challenges feature now has full web + iOS parity, Flawless included.
