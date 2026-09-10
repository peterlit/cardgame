# Loop report — .review-loop

**Stop condition:** `converged` after round 2 — no open blockers or majors; none newly introduced

**Subagent tokens:** 512,248 across 3 round(s)

**Findings by status:** fixed 13, open 1

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|----------|--------|--------|--------|-----|----------|----------|-----|--------|----------|
| 1 | 1 | 0 | 2 | 9 | 2 | 0 | 0 | +7 | 174335 | continue |
| 2 | 0 | 0 | 2 | 2 | 1 | 0 | 0 | +1 | 133253 | converged |

## Tokens (reported — measured 4-7x below billed effective)

| Round | By role | Total |
|---|---|---:|
| 0 | reviewer 113,752 | 113,752 |
| 1 | implementer 94,508; reviewer 79,827 | 174,335 |
| 2 | implementer 108,208; reviewer 115,953 | 224,161 |
| **all** | | **512,248** |

## Open findings by severity

### minor (1)

- **tests/GameClockTests:real-clock-default-untested** — minor, open; region `ios/Causeway/CausewayTests/GameClockTests.swift:14-33`; introduced_by_fix
  - Every GameClockTests case is constructed through makeClock(), which overwrites `now` with the fake, so after this closeout NO test in either target exercises the production default `now = { Date() }`. Freeze that default (or wire it to the wrong clock) and all 5 unit tests plus all 21 UI tests stay green while the shipped HUD timer sits at 0:00 for an entire game and every recorded win banks 0 seconds — the deleted Thread.sleep tests were the only coverage of the real-clock path.
  - evidence: `ios/Causeway/Causeway/Model/GameClock.swift:32`, `ios/Causeway/CausewayTests/GameClockTests.swift:14-18`, `ios/Causeway/CausewayTests/GameClockTests.swift:21,36,48,73,80`, `ios/Causeway/CausewayUITests/RegressionAccessibilityIdentifiersTests.swift:51-53`
  - note: CONFIRMED by reading, not run: makeClock() (GameClockTests.swift:14-18) sets clock.now on every instance and all five tests use it. The UI side cannot cover the gap either — the only UI test touching the clock readout asserts app.staticTexts["stat.time"].exists (RegressionAccessibilityIdentifiersTests.swift:51-53), never its value, and a repo-wide grep of CausewayUITests for a time value ("N:NN" literals, DealFormat) finds only comments. Cheap fix, test-only, no shipped behavior change: one assertion that the default seam reads the real clock, e.g. XCTAssertLessThan(abs(GameClock().now().timeIntervalSinceNow), 1) — or a single retained sleep-based smoke test with a loose lower bound only (the flake came from the UPPER bounds).

## Disputed (agree-to-disagree)

_none_

## Fix review rejections

_none_

## Severity changes

_none_

## Closeout

- **tests/GameClockTests:wall-clock-upper-bounds-can-flake** — fixed; VERIFIED. GameClock.swift:32 adds `var now: () -> Date = { Date() }` and all three reads are substituted (start :38, set :58, current :75); no other Date() read remains in the file (pause/resume/reset go through stop()/start(), so they inherit the seam). Production default is the real clock and is unreachable from app code: grep of ios/Causeway/Causeway finds no assignment to `.now` anywhere (only DispatchTime.now() call sites in Game/DailyView/ContentView), so the seam is test-only in practice. The rewritten tests are not tautologies: with `now` injected, a delivery-counting clock (the R9 regression class) reads 0 against XCTAssertEqual(clock.elapsed, 2) in testZeroTimerDeliveriesStillMeasuresWallTime (GameClockTests.swift:26-33), and the pause test still fails a leak because pauseForBackground must bank at stop() to make elapsed == atPause+1 after resume (:56-72). Full-suite evidence: all 5 GameClockTests passed at 0.001s each (was ~5.7s of Thread.sleep). Parity pins are unaffected — ios-parity.test.mjs:481-487 matches only `func pauseForBackground()` / `func resumeFromBackground()` / the ContentView scene hook, none of which moved; npm test 157/157, 0 skipped. FULL-SUITE (closeout, sim DB9F4F54): xcodebuild both targets -> CausewayTests 11/11 in 2.75s, CausewayUITests 21/21 in 517s, TEST SUCCEEDED, 0 failures, 0 skipped; npm test 157/157, 0 skipped.
- **tests/builder.test.mjs:cap-variety-never-asserted** — fixed; VERIFIED. assertFamilyCap (builder.test.mjs:29-42) counts per TIER per family, which matches capped()'s key `tier + ':' + o.id` (build-month.mjs:220), and the ceiling 12 is exactly selectMonthBalanced's max cap (build-month.mjs:277) so it cannot flake. Slices are right: whole pool for the fresh publish (31 days, :120), fresh slice only for --extend (:151), which is correct under the round-2 fix that stops charging published days to the cap. Mutation re-run by the reviewer: python3 mutate.py closeout-mutants.json -> killed 1, survived 0, errors 0. I also reproduced the mutant by hand in a throwaway worktree with .cache copied in and read the actual failure text: '--extend fresh days: silver family "rank-rush" fills 22 of 31 selected days — the per-family cap (max 12) is not being enforced' — so the killer really is the new assertion, not an incidental one. Residual (not filed as a finding): only the --extend test kills the mutant; the fresh-publish assertion stayed green, and at ceiling 12 vs real headroom ~5 the pins detect total cap collapse but not a weakening (e.g. deleting the cap=3..12 tightening search and always using 12).
- **tests/GameClockTests:real-clock-default-untested** — open; CONFIRMED by reading, not run: makeClock() (GameClockTests.swift:14-18) sets clock.now on every instance and all five tests use it. The UI side cannot cover the gap either — the only UI test touching the clock readout asserts app.staticTexts["stat.time"].exists (RegressionAccessibilityIdentifiersTests.swift:51-53), never its value, and a repo-wide grep of CausewayUITests for a time value ("N:NN" literals, DealFormat) finds only comments. Cheap fix, test-only, no shipped behavior change: one assertion that the default seam reads the real clock, e.g. XCTAssertLessThan(abs(GameClock().now().timeIntervalSinceNow), 1) — or a single retained sleep-based smoke test with a loose lower bound only (the flake came from the UPPER bounds).

## Wontfix / resolved

_none_

## WATCH LIST

_The part a human should actually read. Candidates below are mechanical; the orchestrator fills each "look here because". Lead with any shipped BEHAVIOR CHANGE: convergence means two same-family agents agreed — not that the change is correct._

- **parity/index.html:clock-counts-background-time** (fix_risk True) — look here because: this is the round's biggest SHIPPED BEHAVIOR CHANGE — the web clock now freezes whenever the tab is hidden (commit `0801d8c`, `index.html` visibilitychange/`hiddenAt` machinery). Both agents agreed the iOS pause-on-background semantic is the right shared one, but that is a design call the loop made on your behalf: a player who deliberately backgrounds mid-game now gets a *better* recorded time than before. If you disagree, this is the diff to revert. The orderings (hidden win, restore-into-hidden, overlay-up-then-hide) were traced by the reviewer, but only in code — no human has played a game against it.
- **web/index.html:post-win-undo-inflates-the-displayed-clock** (fix_risk True) — look here because: the fix (`winStopAt` + startTime shift, commit `5826564`) and the round-2 `hiddenAt` shift both mutate the same `startTime` anchor. The reviewer proved they can't double-count in the cases it traced; a human eyeball on `index.html:~1264` for a minute is cheap insurance on the timing math the drift guards only string-pin.
- **web/index.html:failed-pool-fetch-permanently-disables-automation** (fix_risk True) — look here because: the retry-forever-with-backoff loop (commit `5826564`) runs unsupervised in every player's browser; a wrong backoff cap or a re-entrant reconcile would show up as battery drain or duplicate grading, which no test in this repo can see.
- **web/index.html:deferred-win-overlay-never-updates** (fix_risk True) — look here because: `onWin()` is now re-entrant by design when the deferred grade arrives (commit `5826564`); recordWin is latched, but any future edit to onWin that adds a side effect will fire it twice on deferred wins.
- **builder/build-month.mjs:extend-cap-starvation** (introduced by a fix) — look here because: the loop's own round-1 fix created this blocker, and the round-2 repair encodes a semantic rule ("the per-family cap governs only the current run's picks, history feeds scoring only", commit `0801d8c`). Two same-family agents agreed that's the intent of `capPerFamily` — verify it matches YOUR intent before the 2026-09-30 reseed, because `--extend` is the path you'll actually run.
- **builder/build-month.mjs:rebuild-gate-keyed-on-a-version-no-client-reads** (fix_risk True) — look here because: closed as PARTIAL — the refusal message now tells the truth, but the real client-side generation coupling was punted to BACKLOG. A full rebuild (not `--extend`) still silently strands client history; fine while `--extend` is the only sanctioned path, wrong the day it isn't.
- **tests/GameClockTests:real-clock-default-untested** (introduced by a fix) — look here because: the ONLY open finding. The closeout's injectable-clock fix removed all coverage of the production `now = { Date() }` default — a frozen shipped clock would pass all 32 tests today. One-line fix sketched in BACKLOG.md; do it with the next Swift change.
- **seed scope** `6c248b8..a0dd4a4 -- :!prompts.md` — 25 files, 1600 lines; largest: `index.html` (+162/-32), `ios/Causeway/CausewayUITests/RegressionDailyCalendarTests.swift` (+50/-102), `tests/ios-parity.test.mjs` (+122/-14) — look here because: this is the change you asked the loop to review, and it hid a structural blocker (`--extend` could never publish) behind a green 153-test suite — the calendar-test rewrite (+50/-102) is the one large piece no round finding ever touched, so it got the least adversarial attention.
- **round 1 diff** `a0dd4a4..5826564` (commit `5826564`) — 9 files, 289 lines; largest: `tools/solver/build-month.mjs` (+78/-15), `tests/builder.test.mjs` (+62/-0), `index.html` (+31/-7) — look here because: the most invasive diff of the loop — it rewired the builder's selection loop (and introduced the cap-starvation blocker round 2 had to fix), touched the web timing anchor, and added the UserDefaults snapshot/restore that the owner's real on-device history depends on.
- **round 2 diff + closeout** `5826564..HEAD` (commits `0801d8c`, `5819bb1`) — largest: `ios/Causeway/Causeway/Model/GameClock.swift`, `index.html` hidden-clock, `tests/builder.test.mjs` — look here because: `5819bb1` changed a PRODUCTION model file (GameClock.swift, the `now` seam) in the no-iteration closeout phase. The reviewer verified the default is the real clock and unreachable from app code, but it is still shipped-code change that only one adversarial pass examined.
