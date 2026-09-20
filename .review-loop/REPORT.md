# Loop report — .review-loop

**Stop condition:** `converged` after round 1 — no open blockers or majors; none newly introduced

**Subagent tokens:** 442,439 across 2 round(s)

**Findings by status:** fixed 9

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|----------|--------|--------|--------|-----|----------|----------|-----|--------|----------|
| 1 | 0 | 0 | 7 | 2 | 2 | 0 | 0 | +0 | 119547 | converged |

## Tokens (reported — measured 4-7x below billed effective)

| Round | By role | Total |
|---|---|---:|
| 0 | panel-verifier 50,070; reviewer 99,320 | 149,390 |
| 1 | implementer 100,736; panel-verifier 56,395; reviewer 135,918 | 293,049 |
| **all** | | **442,439** |

## Panel (multi-provider reviewers)

_Per-lane precision — the drop-or-keep signal. Rejected candidates are counts only; confirmed ones appear among the findings tagged `via panel:<lane>`._

| Round | Lane | Filed | Confirmed | Demoted | Rejected | Kept rate |
|---|---|---:|---:|---:|---:|---:|
| 0 | codex | 1 | 0 | 0 | 1 | 0/1 |
| 0 | gemini | 6 | 0 | 0 | 6 | 0/6 |
| 0 | ollama | 10 | 0 | 0 | 10 | 0/10 |
| final | codex | 1 | 0 | 0 | 1 | 0/1 |
| final | gemini | 4 | 0 | 0 | 4 | 0/4 |
| final | ollama | 10 | 0 | 0 | 10 | 0/10 |

## Open findings by severity

_none_

## Disputed (agree-to-disagree)

_none_

## Fix review rejections

_none_

## Severity changes

_none_

## Closeout

- **docs/daily-challenges.md:four-lines-claim-false** — fixed; Verified by recount, not by claim. data/daily-solutions.json keyed by seed: bronze 92, gold 92, flawless 92, silver 69; the 23 silver-less days are exactly the 23 days whose pool silver.id is in {moves,no-undo} (0 mismatches). October (idx 61..91) holds 7 of them - 2026-10-02, 04, 06, 09, 13, 27, 30 - so 24 of 31 new days bake a distinct silver, and 16 of the 23 are Aug/Sep. docs/daily-challenges.md:6-9 now says exactly that, with the same seven dates. No residual four-lines claim elsewhere in the file (grep 'four' -> only unrelated Flawless/rank copy).
- **docs/architecture/overview.md:stale-61-prose** — fixed; Recounted from data/daily-solutions.json: 92 bronze + 92 gold + 92 flawless + 69 silver, 23 missing silvers - byte-for-byte what the new prose asserts. build-month line now says 92 records, Aug-Oct 2026, October via --extend. grep for '\b61\b' in docs/architecture/overview.md returns nothing, so no stale sibling survived.
- **docs/solver.md:extend-recipe-undocumented** — fixed; Every flag in the new recipe exists and behaves as described, checked against source not claim: build-month.mjs accepts --extend (:353-365) and --select-only gates certifyAll (:375); slotsToFill = nDays - existingDays.length (:386) matches '--days <total> - published'; the published-bytes check is real (:428-434) and the same-version rebuild refusal is real (:366-373). build-solutions.mjs accepts --stripe W/N (:116,:124) and --merge (:101-112) with --out defaulting through arg() (:38-41). The --days 122 November figure is consistent with the month-boundary test (checked separately). Unmentioned: --rebuild exists as an escape hatch and the usage block still does not list it, but §6's 'never rebuild' prose covers the intent - not worth a finding.
- **docs/qa-loop-workflows.md:stale-pool-contract** — fixed; Every figure recounted independently and all match. Family frequencies over silver+gold slots: end-bias 27, suit-balance 20, cells-le 18, rank-rush/split-at/max-run/moves/ends-first/before-ace/suit-top-first 14 each, no-undo 9, big-move 7, suit-sprint 5 - sums to 184 = 92*2, exactly WORKFLOWS.md:217-220. The universal-Silver index list (idx 4,5,9,15,20,22,25,36,38,40,42,44,45,54,57,59,62,64,66,69,73,87,90) is the complete measured set, 23 entries, no extras or omissions. days[0..91] ends 2026-10-31 (computed from epoch). minSeed/maxSeed 500001/1000000 still true (actual seeds 514195..993123). TESTCASES.md:1003 61->92 correct, and its 'reachable range 0..14 -> idx 4,5,9 and nowhere else' still holds. The dated '0..38 / 0..39 on the real clock on 2026-09-09' phrases are self-dating, not stale.
- **tests/solutions.test.mjs:no-month-boundary-pin** — fixed; Behaviour confirmed by running the assertion verbatim against synthetic lengths in a throwaway file (not the real pool): epoch 2026-08-01 with length 91 -> REJECT ('pool ends on 2026-10-30'), 92 -> ACCEPT, 100 -> REJECT ('2026-11-08'), 122 -> ACCEPT, 61 -> ACCEPT, 62 -> REJECT; a non-first epoch (2026-08-15) -> REJECT. Both claimed rejections and both claimed acceptances hold. Caveat worth knowing, not a defect: the boundary asserts sit after the literal assert.equal(pool.days.length, 92) at :113 in the same test, so on a 122-day pool :113 fires first; the comment's 'Independent of the literal length pinned above' is true of the arithmetic but the assertion is unreachable until someone updates :113. That is precisely the sequence the guard is meant to police (bump the literal for a partial month -> boundary assert catches it), so it still works - just not as a standalone tripwire.
- **docs/solver.md:no-repeat-claim-vs-grandfathered-days** — fixed; Data and code both confirm the new prose. data/daily-pool.json days[3] and days[60] are the ONLY exact (silver,gold) duplicate in 92 days, both suit-balance{N:4} + cells-le{N:0}, and idx 3/60 are indeed 2026-08-04 / 2026-09-30. The two-layer ban is real: selector skips prior-published and within-run pairs (build-month.mjs:256-257,273) and the pre-publish byte check re-runs it (:439-443) starting at base = existingDays.length (:428), which is exactly the 'published days are never re-validated against each other' the doc states. The warning not to widen the guard is correct - in fresh mode base is 0 and the loop would fail on days 3/60.
- **docs/HANDOFF.md:stale-node-test-count** — fixed; Measured: NODE_OPTIONS= npm test -> tests 173, pass 173, fail 0, skipped 0. All three sites now read 173 and are dated 2026-09-20. Swift unit target measured 17 executed / 0 failures / 0 skipped, matching HANDOFF.md:73-74 and CLAUDE.md:46-47. Full iOS suite also run this dispatch on udid 7B1ED0F9 in six class groups covering all 45 UI classes: CausewayUITests 75 executions / 0 failures / 0 skips (15+13+11+8+16+12), six ** TEST SUCCEEDED **, no XCTSkip anywhere - so HANDOFF.md:169 and CLAUDE.md:46-47 (72 methods / 75 executions, 17 unit) are accurate as of 2026-09-20, not just as of 2026-09-09.

## Wontfix / resolved

_none_

## WATCH LIST

_Hygiene check at report time: clean (no tracked scratch, no Finder duplicates, no oversized files). Simulator `7B1ED0F9…` created for this run and deleted at close._

_The part a human should actually read. Candidates below are mechanical; the orchestrator fills each "look here because". Lead with any shipped BEHAVIOR CHANGE: convergence means two same-family agents agreed — not that the change is correct._

- **builder/build-month.mjs:within-run-pair-repeat** (fix_risk Hardening the within-run rule changes the selector predicate and therefore the content of every future generated month; the shipped fix is forward-looking only and leaves published bytes alone.) — look here because: this is the loop's ONE shipped behavior change (commit `07aa37c`, `tools/solver/build-month.mjs` selector + post-write validator). It alters what every FUTURE `--extend`/fresh run may pick — the November month will differ from what the pre-fix selector would have chosen — while the 92 published days stay byte-identical (the day-3/day-60 repeat is grandfathered on purpose; the validator walks only the fresh slice, so widening it to the whole pool would go red on shipped data). The reviewer proved no starvation (`--extend --days 154` still fills 62 days from the tracked cache without the flawless gate) but did NOT run it under the gate; if a November build fails closed, the ban is the first suspect. The test that discriminates it (`tests/builder.test.mjs` synthetic 7-seed cache) kills the ban mutants by MESSAGE match (`only 6 of 7 days could be filled`), not by exit status.
- **seed scope** `026fff0..e409698 -- :!prompts.md :!data/daily-solutions.json :!ios/Causeway/Causeway/daily-solutions.json :!.cache/flawless-certs.jsonl` — 11 files, 133 lines; largest: `ios/Causeway/Causeway/daily-pool.json` (+32/-1), `data/daily-pool.json` (+32/-1), `BACKLOG.md` (+15/-2) — look here because: the 31 October days (`days[61..91]`) and their 31 solution entries (excluded from the panel diff by size, NOT from the commit — 5 of the panel's 32 candidates were that misreading) are generated data whose correctness rests on the solver's certification and two replay guards (`tests/solutions.test.mjs`: every line wins and earns its tier through the runtime checkers; Swift `SolutionReplayTests`: all 92 through `Game.drop`). Nobody has PLAYED an October day. Spot-check one or two in the app (e.g. Oct 09 = `Win in 111 moves` + `Kings first`, Oct 24 = `no free cell` Gold) before the month starts; a mis-scored objective on real play would be a rules-drift class bug the guards cannot see.
- **round 1 diff** `e409698..HEAD` — 11 files, 182 lines; largest: `tests/builder.test.mjs` (+45/-0), `docs/solver.md` (+35/-5), `tools/solver/build-month.mjs` (+18/-7) — look here because: this range lumps round 1 (`07aa37c`, the behavior change above + the iOS byte-identity guard in `tests/ios-parity.test.mjs`) with the closeout commit (`4f4e7fb`, docs/QA-contract figures and the month-boundary assertion in `tests/solutions.test.mjs`). Two things to eyeball: (1) the month-boundary asserts sit AFTER the literal `92` pin in the same test, so they only bite once someone bumps the literal — intended, but not a standalone tripwire; (2) `.qa-loop/WORKFLOWS.md`'s recounted family frequencies and universal-Silver index list are what the next QA loop's testers will drive against — the reviewer recounted them and they match, but a wrong index there would file phantom failures, not fail a test. Panel: nothing beyond the chair (32 candidates over two passes, 0 kept).
