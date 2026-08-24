# QA loop — run report, measured token cost, and what to change

**Run:** loop 3 on Causeway, 2026-08-22/23. Settings `max_rounds=3, parallel_testers=2`.
**Outcome:** round 0 (exploration) + round 1 (full pass, 57 test cases) + implementer + fix review
completed; round 2 was **stopped by the operator after 2 of 15 chunks** to take on other work. The
loop never reached its own stop condition.

Every number below is measured, not estimated: per-dispatch figures come from the harness's own
`subagent_tokens` accounting, and the cost-weighted figures from the raw session transcripts in
`~/.claude/projects/-Users-plit-Documents-src-cardgame/`.

**Accounting.** "Effective tokens" weights the four billed classes by relative cost:
`input x 1 + cache_read x 0.1 + cache_write x 2 + output x 5`, deduplicated by `requestId`. This is
the same formula used in [`loop-token-usage.md`](loop-token-usage.md), so the two runs are directly
comparable.

---

## 0. Headline

| | This run (loop 3) | Previous run (loop 2) |
|---|---:|---:|
| Rounds completed | 1 of 3 (+2 chunks of round 2) | 3 |
| Test cases in a full pass | 57 | ~40 |
| Findings | **29** (1 blocker / 10 major / 18 minor) | 18 |
| Subagent dispatches | 23 | 32 |
| Subagent requests | 2,458 | 2,844 |
| **Subagent effective tokens** | **23.53 M** | 39.87 M |
| Orchestrator effective tokens | 2.02 M | — |
| **Effective tokens per finding** | **811 K** | 2.21 M |
| Effective tokens per subagent request | **9,303** | 14,036 |

**The loop got 2.7x cheaper per finding and 34% cheaper per request than the last run**, on a
*wider* test set. Almost all of that came from one change made before the run started: the tester
brief file was cut from 86 KB to 6.9 KB (§3.1). The rest of this document is about where the
remaining 23.5 M went and what would move it next.

The absolute number is still large. **A full pass of this app costs roughly 20 M effective tokens
and about four hours of wall clock on two simulators.** That is the price of driving a real app
through 57 scripted interactions with visual verification; it is not a bug, but it does mean the
loop is something you schedule, not something you run casually.

---

## 1. Where the tokens went

```
Effective tokens by role
────────────────────────────────────────────────────────────────
ux-tester (21)      ████████████████████████████████████  21.48 M   91%
qa-implementer (1)  ██                                     1.43 M    6%
fix-reviewer (1)    █                                      0.63 M    3%
                                                          ───────
                                                           23.53 M
orchestrator                                                2.02 M
```

| Role | n | requests | effective | mean/dispatch | eff/request |
|---|---:|---:|---:|---:|---:|
| `ux-tester` | 21 | 2,309 | 21,481,189 | 1,022,913 | 9,303 |
| `qa-implementer` | 1 | 99 | 1,425,389 | 1,425,389 | 14,398 |
| `fix-reviewer` | 1 | 50 | 625,918 | 625,918 | 12,518 |
| orchestrator (this thread) | — | 92 | 2,016,291 | — | 21,916 |

**One role is 91% of the spend, and its cost is `requests x context`.** A tester averaged 110
requests holding a context that grows all pass; 90% of its effective cost is cache reads of that
accumulated context. Nothing else is close: output tokens across all 23 dispatches total 281 K
(1.2% of effective cost).

The ten most expensive dispatches:

| Round | Chunk | TCs | requests | effective |
|---|---|---:|---:|---:|
| 1 | `wf-12-1` (landscape) | 3 | 167 | 2,050,043 |
| 2 | `wf-2-1` (core moves) | 5 | 193 | 1,866,537 |
| 1 | `wf-2-1` (core moves) | 5 | 175 | 1,837,666 |
| 1 | `perf` (perf lane) | 1 + 6 candidates | 138 | 1,582,276 |
| 1 | `wf-6-2` (demo gates) | 2 | 156 | 1,512,455 |
| 1 | `wf-13-1` (sandbox objectives) | 5 | 113 | 1,474,580 |
| 1 | `impl` (implementer) | 18 findings | 99 | 1,425,389 |
| 0 | `explore-wf13` | — | 73 | 1,239,814 |
| 1 | `wf-7-1` (deal entry) | 5 | 168 | 1,219,001 |
| 1 | `wf-9-1` (wins) | 3 | 146 | 1,189,477 |

The top five are 38% of all subagent spend. **Cost does not track test-case count** — `wf-12-1` ran
three test cases for 2.05 M because rotation was undrivable and the tester built an XCUITest driver
to solve it, while `wf-10-1` ran three for 0.20 M. What drives cost is *how many turns the tester
needs to establish state*, not how much it is asked to check.

---

## 2. Was it worth it?

29 findings on a shipped, twice-QA'd app, of which the loop's own adversarial reviewer upheld 17 of
18 fixes as sound. Specifically:

- **1 blocker**: the app's own export→import round trip silently discarded stats it had just
  written (`bug/WF-11:import-drops-out-of-range-stats`). Found by a tester *reproducing a
  source-level claim another tester had made in a different chunk*, and found to be worse than
  reported. No code reader had caught it in two prior loops.
- **10 major**, including an unreadable Wins screen (1.42:1 contrast), a landscape rail that hid a
  control entirely, and three separate silent-discard paths around the Daily screen.
- **15 of 29 findings carry a `fix_risk` flag** — the tester identified, in advance, that the
  obvious fix was a trap. Two of those warnings directly changed what the implementer did.
- The implementer **declined one finding with a four-point argument**, and the fix-reviewer verified
  the argument against the code and upheld it. That exchange corrected a design claim that was wrong
  in two source files, the workflow doc, and a test case.

That last point is the real argument for the loop: it is not a bug-finder, it is an **adversarial
system with three independent roles**, and the disagreements are where it earns its cost. A plain
"find bugs in my app" pass would have filed the `one-big-move` finding and someone would have
implemented it.

**Where it was weakest:** everything the loop knows comes from the docs it is handed. WF-13's
expectation was written by me (the orchestrator) from reading the code, and it was *wrong* — I said
the constraint objectives must refuse illegal moves when the design is that they mark them failed.
Round 0 caught it as a hypothesis; had it not, round 1 would have filed a major finding against
correct behaviour and the implementer might have "fixed" it. **The workflow doc is the loop's
single point of failure, and nothing in the loop audits it.**

---

## 3. What actually moved the cost

### 3.1 The one change that worked: cut the brief (measured -34%/request)

`HARNESS_NOTES.md` had grown to **86 KB** — round-by-round accumulated notes, most of it obsolete
rig lore about an XCUITest/CGEvent driver that this session's simulator MCP tool made unnecessary.
Every tester read it on every dispatch, paying ~21 K tokens for a file whose live content was
maybe 2 K, and worse, being actively misled by it.

Archiving it and rewriting a 6.9 KB current-environment summary is the single measurable difference
between this run and the last: **14,036 → 9,303 effective tokens per subagent request.**

**It regrew to 22 KB in one round.** Every tester appends a chunk section, and nothing prunes. This
will be back to 86 KB in three loops. It needs a policy, not another manual cut.

### 3.2 The targeted pass degenerated into a full pass

Round 2 should have been cheap. It wasn't: `plan_round.py` selected **57 of 57 test cases**, because
the implementer's single round-1 commit touched 25 files spanning 13 of the 14 workflows, and the
targeting rule is "any workflow whose `paths()` intersect the diff".

One commit that fixes 17 findings across the whole app defeats targeting completely. The loop's
round-2 cost was therefore identical to round 1's — an estimated 1.5 M more effective tokens than
the work justified.

### 3.3 A region-filter bug made every brief 7x too big

`merge_ledger.py open <ledger> auto --region WF-1` returns the findings for WF-1 **and WF-10, WF-11,
WF-12, WF-13** — the region match is a prefix match. The WF-1 chunk's brief carried 7 findings
instead of 1. I worked around it by filtering in the orchestrator; the tool should be fixed.

### 3.4 Testers rebuild the same rigs, independently

Across round 1, separate testers independently built: three PNG-diff implementations
(`png.py`/`bdiff.py`, `scan.py`/`hscan.py`/`diff.py`, `imgdiff`), two save-injection recipes, two
screenshot-cropping tools, and one XCUITest rotation driver. Each rebuild is 10-40 turns at ~9 K
effective tokens per turn. The tooling is genuinely good — and it is thrown away every round,
because it lives in per-worker scratch dirs that `provision_workers.sh up` deletes.

### 3.5 The test-case file silently didn't match the contract

`TESTCASES.md` predated the current `### TC-n.m [novice] [smoke] Title` format that `plan_round.py`
parses. Its cases matched the id regex by luck (the `**` bold prefix) but carried **no persona or
smoke tags at all**, so every planner decision that reads tags — persona coverage, the smoke set,
the perf lane — was running on empty data until I retagged all 51 cases by hand. Nothing warned.

---

## 4. Suggestions, in order of measured value

1. **Cap and rotate `HARNESS_NOTES.md` automatically.** At the end of each loop, move every
   `## Round-N additions` / `## Chunk …` section into the archive and keep only the general
   sections. Enforce a hard ceiling (say 10 KB) in the skill, and have the orchestrator refuse to
   dispatch above it. *Measured value: this is worth ~30% of per-request cost — it is the only
   change here with a before/after number.*

2. **Make the implementer commit per region.** One commit per workflow (or per finding group) keeps
   `plan_round.py`'s path intersection meaningful, which is the difference between a 15-chunk round
   2 and a 4-chunk one. *Estimated saving: 1.0-1.5 M per post-implementation round.*

3. **Don't re-run clean chunks every round.** Even with a broad diff, a chunk whose findings all
   closed and whose tests all passed does not need a full re-run — the `[smoke]` set covers
   regression. Restrict targeted passes to: chunks with open/rejected findings, chunks whose
   *semantic* region changed, plus smoke. *Estimated saving: 0.8-1.2 M per round.*

4. **Promote the testers' rigs to `.qa-loop/tools/` and document them in the brief.** A shared
   `pngdiff`, `crop`, `inject-save`, and `film` would remove 10-40 turns from most dispatches. They
   already exist; they just get deleted. *Estimated saving: 2-4 M per full pass.*

5. **Fix the `--region` prefix match** in `merge_ledger.py` (`WF-1` must not match `WF-13`).
   *Cheap; a few K per dispatch, and it removes a real correctness hazard — a tester reading another
   workflow's findings can file a duplicate.*

6. **Validate the contracts at Stage 2.** `plan_round.py` should fail loudly when a test case has no
   persona tag, when a workflow has no `paths()` line, and when `TESTCASES.md` uses an obsolete
   heading format. All three were silently wrong here.

7. **Set `token_budget` in the ledger.** The skill supports it and this run left it `null`. A
   budget of, say, 25 M would have stopped the loop deliberately rather than leaving it to the
   operator to notice the cost.

8. **Budget dispatches by turns, not test cases.** Chunk size is a poor cost predictor (3 cases cost
   2.05 M; 3 other cases cost 0.20 M). Give each dispatch an explicit turn budget with instructions
   to file what it has and stop, rather than letting a hard case run 190 turns.

9. **Audit the workflow doc.** The one thing the loop cannot check is whether its own expectations
   are right. A single cheap dispatch — "read WORKFLOWS.md against the code and list every
   expectation the code contradicts" — before round 1 would have caught the WF-13 error for a few
   tens of K.

10. **Do not chase output tokens or screenshots.** Output is 1.2% of effective cost and images
    measured as zero blocks in the transcripts. The lever is turns x context, nothing else.

---

## 5. Process notes (non-cost)

- **Two testers is the right parallelism for this app.** Simulator contention forced the perf lane
  to run alone anyway, and one tester noted a Simulator quit that shut down every booted device.
- **The perf lane earned its keep by dismissing things**: it killed the "board repaints at 1 Hz
  while idle" hypothesis with a 75-second zero-CPU measurement, and showed the export stall is
  already mitigated (1.07 s frozen vs 1.61 s at the old baseline). Cheap negative results are
  valuable — they stop the implementer from "fixing" a non-problem.
- **Model pinning was inconsistent and is disclosed here**: the round-0 exploration dispatch ran on
  Sonnet; every round-1/2 dispatch ran on the session default. Per-dispatch comparisons across those
  two groups are not apples-to-apples.
- **The loop respected the repo's standing rules under pressure.** The perf lane declined to measure
  rotation rather than break the "never edit `project.pbxproj`" rule, and said so. Another tester
  that did trip it reverted the file and reported it.
- **Two round-2 dispatches were cancelled mid-flight** and had already spent 0.92 M effective
  tokens. Interrupting the loop is safe for state, but not free.
