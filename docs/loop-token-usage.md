# Token usage — the review loop and the QA loop

Measured from the raw session transcripts in
`~/.claude/projects/-Users-plit-Documents-src-cardgame/`, not estimated. Every number below is
reproducible from those `.jsonl` files.

**Accounting.** "Effective tokens" weights the four billed classes by relative cost:
`input × 1 + cache_read × 0.1 + cache_write × 2 + output × 5`. Usage records are deduplicated by
`requestId` (several transcript rows share one request). Images are counted at a flat 1,600 tokens
each — base64 length in the transcript is **not** a proxy for token cost, and treating it as one
overstates image cost by 30–70×.

---

## 0. Headline

| | Review loop | QA loop |
|---|---|---|
| Runs | 17 | 1 (3 rounds) |
| Rounds | 22 | 3 |
| Findings | 26 (5 major / 21 minor) | 18 (4 major / 14 minor) |
| Subagents | 62 | 32 |
| Subagent requests | 926 | 2,844 |
| **Subagent effective tokens** | **8.40 M** | **39.87 M** |
| **Cost per finding** | **323 K** | **2.21 M** |
| **Cost per major finding** | **1.68 M** | **9.97 M** |

**The QA loop costs about 7× more per finding than the review loop.** Some of that gap is real and
earned — it drives an actual simulator and finds interaction bugs no code reader can see. But it is
where the money is, and it is the one worth tuning.

**The review loop's own plumbing is already lean.** All loop-related content the orchestrator ever
absorbed — every agent report, every ledger read, every diff — totals **140,793 tokens**, about
14.5 % of the session's content budget. The loop is not expensive because of what it holds.

---

## 1. Where the loop tokens actually went

```
Effective tokens by subagent type (all sessions)
────────────────────────────────────────────────────────────────────────
qa-loop:ux-tester           ████████████████████████████████████  37.98 M   77%
review-loop:reviewer        █████                                  5.21 M   11%
review-loop:implementer     ███                                    2.68 M    5%
qa-loop:qa-implementer      █                                      1.05 M    2%
Explore                     █                                      0.89 M    2%
skeptical-reviewer (legacy) ▌                                      0.51 M    1%
qa-loop:regression-writer   ▌                                      0.47 M    1%
qa-loop:fix-reviewer        ▌                                      0.37 M    1%
                                                                  ───────
                                                                   49.15 M
```

One agent type is 77 % of all loop spend.

| Agent type | n | requests | effective | per request | median peak context |
|---|---:|---:|---:|---:|---:|
| `qa-loop:ux-tester` | 28 | 2,706 | 37,981,844 | 14,036 | **173,290** |
| `review-loop:skeptical-reviewer` | 35 | 501 | 5,208,265 | 10,396 | 40,842 |
| `review-loop:implementer` | 20 | 375 | 2,679,540 | 7,145 | 36,032 |
| `qa-loop:qa-implementer` | 1 | 61 | 1,049,486 | 17,205 | 154,810 |
| `skeptical-reviewer` (pre-plugin) | 7 | 50 | 514,476 | 10,290 | 27,335 |
| `qa-loop:regression-test-writer` | 2 | 44 | 466,526 | 10,603 | 73,264 |
| `qa-loop:fix-reviewer` | 1 | 33 | 365,669 | 11,081 | 84,821 |

The review-loop agents are well-scoped: they hold ~36–41 K of context and answer in ~15–25 requests.
The `ux-tester` holds **4× more context** and runs **97 requests per agent**. That combination —
long-running *and* wide — is the entire cost story.

What the testers spend their requests on:

| Agent type | tool calls |
|---|---|
| `qa-loop:ux-tester` | Bash 1,875 · Read 717 · simulator control 242 |
| `review-loop:skeptical-reviewer` | Bash 396 · Read 208 |
| `review-loop:implementer` | Bash 174 · Edit 138 · Read 97 · Write 4 |

**67 Bash calls and 26 Reads per tester agent.** That is simulator/build orchestration done one
command at a time, plus each tester independently re-reading app source to find accessibility
identifiers.

---

## 2. The orchestrator: cheap content, expensive address

Everything the main thread absorbed from the loops, image-aware:

| What | n | tokens | mean |
|---|---:|---:|---:|
| Agent reports (review-loop) | 62 | 70,546 | 1,137 |
| Loop state files via Bash | 159 | 27,224 | 171 |
| Agent reports (qa-loop) | 32 | 17,565 | 548 |
| **`git diff` / `git show` output** | **48** | **13,048** | **271** |
| Evidence screenshots read back | 4 | 6,400 | 1,600 |
| Loop state files via Read | 5 | 6,010 | 1,202 |
| **Total** | **310** | **140,793** | |

> **Correction to an earlier recommendation.** I previously suggested the biggest available fix was
> keeping the raw diff out of the orchestrator's context by passing a patch path instead. The data
> does not support that: diffs averaged **271 tokens** and totalled 13 K across 48 calls — under 10 %
> of loop content and about 0.03 % of the session. The change would be near-free but would save
> essentially nothing. Dropped.

The cost is not *what* the orchestrator holds. It is *where it runs*:

| Session | mean context at a review-loop dispatch | effective cost of one plumbing request |
|---|---:|---:|
| `8a2551d6` (focused, 170 requests) | 166,099 | **16.6 K** |
| `901d3755` (this one, 2,387 requests) | 553,398 | **55.3 K** |

**The identical plumbing step costs 3.3× more purely because of the session it ran in.** And at
553 K of ambient context, a single orchestrator request (55.3 K) costs **5× more than a request by
the reviewer subagent it is dispatching** (10.4 K).

A round is roughly seven orchestrator requests — set SHA, dispatch implementer, compute diff,
dispatch reviewer, merge ledger, run metrics, branch on decision. That is ~387 K in a bloated
session versus ~116 K in a fresh one. Across 22 rounds: **8.5 M versus 2.6 M**.

---

## 3. Recommendations

### For the QA loop — where 77 % of the spend is

1. **Give every tester a pre-built accessibility-identifier index.** 717 Reads across 28 testers is
   the same app source read 28 times to answer the same question. Generate `ids.txt` once per round
   and pass it in. *Est. saving: 3–5 M.*
2. **Collapse simulator orchestration into single commands.** 1,875 Bash calls at ~67 per tester is
   build → install → launch → poll → log-read done stepwise. A `qa-run.sh` that does the whole
   sequence and returns one result block turns ~8 requests into 1. Each avoided request at the
   tester's 173 K context is ~14 K. *Est. saving: 8–12 M.*
3. **Cap tester context, not just tester count.** Median peak 173 K means testers accumulate a full
   session's worth of screenshots and logs. Scope each agent to **one workflow ID**, and have it
   write evidence to disk rather than carrying it. *Est. saving: 5–8 M.*
4. **Screenshot for evidence, not for control flow.** 242 simulator calls, most of them "did that
   land?". Assert against the accessibility tree; screenshot only what will be attached to a filed
   finding. *Est. saving: 1–2 M.*
5. **Shard `HARNESS_NOTES.md`.** At 86 KB (~21.5 K tokens) any agent that reads it whole pays more
   than its own working context. The `fragments/` directory already exists for this. *Preventative —
   measured reads were small, but the file keeps growing.*

Together these plausibly take the QA loop from ~40 M to ~15 M without reducing coverage.

### For the review loop — already efficient; two structural wins

6. **Document "run in a fresh session" as a precondition, not advice.** This is the single largest
   measured effect on the review loop: **3.3×**, and it requires no code change. The skill should
   refuse-or-warn when the orchestrator's context is already large at setup time.
7. **Fold seeding into round 1.** There were 35 reviewer dispatches for 22 rounds. The extra ~13 are
   cold-seeding passes that redo most of round 1's work. One reviewer per run, seeding *and*
   reviewing in a single pass. *Est. saving: ~1.5 M.*
8. **Default `max_rounds` to 2 for scoped changes.** Every multi-round run here converged at round 2
   or 3, and round 2 typically closed everything with zero new findings. The DIMINISHING rule needs
   two consecutive low-net rounds, so it cannot fire before round 3 — it never actually saved a
   round. Escalate to 5 only when round 1 returns a blocker.
9. **Route minors straight to `BACKLOG.md`.** 21 of 26 findings were minor. They are worth a
   reviewer pass; they are rarely worth an implementer round.
10. **Do not restructure the ledger/diff data flow.** Measured at 141 K total — there is nothing
    there to win. Leave it alone.

### Cross-cutting

11. **The loops are not the problem; long sessions are.** This session ran 2,387 requests at a mean
    context of 497 K, peaking at 998 K and compacting five times. Its cache reads alone are 118.7 M
    effective. Any work done inside it — loop or otherwise — pays that tax. Splitting by task is
    worth roughly 5× and dominates every item above.
12. **Subagents are the cheap place to do work.** A subagent request averaged 11.2 K effective
    against the main thread's 78.6 K — **7× cheaper** — because each runs in a fresh ~46 K context
    and returns a summary. Both loops already get this right; the lesson generalizes to ordinary
    feature work.

---

## 4. Reproducing these numbers

The measurement script now lives in the repo: **`tools/loop-usage.py`** (the scratchpad scripts this
document was first written from did not survive their session). Run it with the loop's start time:

```
python3 tools/loop-usage.py --since $(date -v-3H +%s)
```

Each row is one transcript. `sidechain: true` marks a subagent; `agent` names its type and `label`
its dispatch description, both read from the `agent-<id>.meta.json` sidecar — sum the sidechain rows
for a loop's subagent cost, and group by `agent` for the implementer/reviewer split. The method:

1. Parse each `*.jsonl`; dedupe assistant records by `requestId`; sum `message.usage`.
2. Match subagent transcripts to their `subagent_type` by normalizing the `Agent` tool's `prompt`
   and matching it to the subagent's first user message (98/98 matched, no fuzzy fallback needed).
3. For context-carry attribution, walk the transcript in order and charge each added block
   `size × requests_remaining × 0.1`.
4. Count `type: "image"` blocks at a flat rate; never measure them by base64 length.

---

## 5. Run log — measured runs of the plugin

Per-run detail lives in the `docs/*-feedback.md` files; this is the comparable series.

| Run | Plugin | Scope | Stop | Findings | Subagent eff. | Orch. eff. | **Total** | Per finding |
|---|---|---|---|---:|---:|---:|---:|---:|
| 2026-08-30 15:13 | review-loop 0.7.1 | one feature diff | converged R2 | 11 | 1.63 M | 0.53 M | **2.16 M** | 197 K |
| 2026-08-30 23:19 | review-loop 0.8.1 | a whole QA loop's output | thrashing_soft R2 | 17 | 3.63 M | 0.69 M | **4.32 M** | 254 K |

Both ran in fresh sessions, which is why the orchestrator share fell from the 22-round baseline's
profile to 24.6 % and then 16.0 %. Two things the second run changed in the picture above:

- **The reported→effective multiplier is not a constant ~4×.** Measured 5.4× overall and 7.2× on the
  longest single dispatch. It tracks turns-per-dispatch, so `token_budget` set on the reported scale
  under-counts by five-fold or more on long runs.
- **The closeout is now the most expensive phase**, not a mop-up: 1.45 M across two dispatches, 40 %
  of subagent spend, more than either real round. Recommendation 9 above ("route minors straight to
  BACKLOG") is only half right — deferring every minor to one no-iteration pass is what makes that
  phase both expensive and risky. Minors that touch shipping code belong in a round.
