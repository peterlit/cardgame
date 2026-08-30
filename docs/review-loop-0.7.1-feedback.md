# Review loop v0.7.1 — token usage and feedback

Run of 2026-08-30, scope `f42c632..HEAD -- ':!prompts.md'` (the ⏰ same-day + 🌟 how-to-win-flawless
release). Plugin `review-loop-tools@quiller` **0.7.1**, git `c9e4415`.

Measured with `tools/loop-usage.py --since 1788117181` against the raw session transcripts — not
estimated. Accounting is the same as `docs/loop-token-usage.md`: effective tokens weight the billed
classes `input ×1 + cache_read ×0.1 + cache_write ×2 + output ×5`, records deduplicated by
`requestId`, images at a flat 1,600.

---

## 1. Headline

| | |
|---|---|
| Wall clock | ~44 min (15:13 → 15:57) |
| Rounds | seed + 2 rounds + closeout |
| Stop condition | **converged** (0 open blockers, 0 open majors) |
| Subagent dispatches | 7 |
| Findings | 11 — 0 blocker, 2 major, 9 minor |
| Outcome | 8 fixed, 1 partial, 2 open |
| **Total effective tokens** | **2,162,432** |
| Orchestrator share | 531,816 (24.6%) |
| Subagent share | 1,630,616 (75.4%) |
| Cost per finding | 197 K |
| Cost per *fixed* finding | 270 K |

For comparison, the 17 runs in `docs/loop-token-usage.md` averaged **323 K per finding**. This run
came in at 197 K — better, and the scope-mode default (`max_rounds=2`) is a large part of why.

## 2. Where it went

| Dispatch | Role | Requests | Reported | **Effective** | Ratio |
|---|---|---:|---:|---:|---:|
| `ab92f43a` | seed reviewer | 30 | 79,621 | **326,448** | 4.1× |
| `a9cbdc5b` | round 1 implementer | 15 | 30,287 | **95,793** | 3.2× |
| `ae38df25` | round 1 reviewer | 22 | 43,343 | **142,889** | 3.3× |
| `ac010cf4` | round 2 implementer | 32 | 57,446 | **243,873** | 4.2× |
| `a66672c7` | round 2 reviewer | 27 | 64,490 | **232,864** | 3.6× |
| `a6c2b7fb` | closeout implementer | 36 | 67,201 | **288,070** | 4.3× |
| `a17fd7d0` | closeout reviewer | 35 | 68,888 | **300,679** | 4.4× |
| | **subagents** | **197** | **411,276** | **1,630,616** | **4.0×** |
| `f20bb660` | orchestrator | 33 | — | **531,816** | — |

Cache reads dominate: 7.34 M cache-read tokens across the subagents against 21 K of output. The loop
is overwhelmingly paying to *re-read context*, not to think — which is why chunking and diff
materialization matter more than model choice.

## 3. What it actually bought

Not padding. The two majors were both real and both mutation-proven:

- **The entire web ⏰ feature was deletable with a green test suite.** The seed reviewer proved it by
  mutation: it replaced `index.html:1433` with `const onTime=false;`, dropped the start-day stamp,
  and got `daily.test.mjs` 32/32 and `ios-parity.test.mjs` 14/14. Without mutation testing this
  would have been an opinion; with it, it was a fact.
- **A real correctness bug in shipped Swift.** `restore`'s `?? s.challengeDay` fallback would have
  **falsely awarded ⏰** for a backfilled day D finished on D+1 after a relaunch. Fixed on both
  platforms, with the totality argument (`challengeDay != nil ⇒ challengeStartDay != nil`)
  independently re-derived by the reviewer.

It also fixed a bug in this very measurement script (`--since` was file-granular, over-reporting a
long session touched recently), which is why the numbers above are trustworthy.

---

## 4. Feedback on v0.7.1

### What works, and should not be touched

1. **Mutation verification is the highest-value thing in this plugin.** Every major finding this run
   was a coverage gap that only `mutate.py` could turn from opinion into evidence. It also caught
   the implementer over-claiming, twice.
2. **`next-round` folding merge + metrics + advance into one call.** The orchestrator held at 24.6%
   of spend across 33 requests. The three-plumbing-turns-per-round design is doing its job.
3. **`open <ledger> closeout` encoding eligibility in the verb.** No hand filtering, and it
   correctly swept in `introduced_by_fix` findings of any severity — exactly the regressions the
   loop must not ship to BACKLOG.
4. **The adversarial pairing is productive, not ceremonial.** Round 1: implementer claimed "8/8
   mutants killed"; reviewer re-ran and found one had silently errored. Round 2: implementer pinned
   the web surfaces and claimed parity; reviewer ran five iOS mutants and *all five survived*. The
   loop's value is concentrated in the reviewer refusing to take the implementer's word.
5. **`archive` with `legacy/` handling.** It swept 30+ ad-hoc `REPORT-*.md` files that had piled up
   over previous runs into one timestamped directory. Good hygiene, zero effort.

### Bugs and gaps, worst first

1. **`mutate.py` fails silently enough that a false "all killed" survives a round.** *(integrity —
   this one undermines the plugin's best feature.)* A manifest entry pairing a **multi-line
   `original`** with a `"line": N` key can never match (`mutate.py:38` matches within one line). It
   errors, the process exits 1 — and the round still reported 8/8 killed, because the per-mutant
   error is easy to miss in a summary and nothing forces the caller to check the exit code. The
   round-1 reviewer only caught it by re-running the manifest independently.
   **Fix:** reject at parse time when `original` contains `\n` and `line` is set (it is
   unsatisfiable by construction); add an explicit `errors: N` to the summary object; and print a
   loud banner when `errors > 0`. Silent under-verification is worse than no verification, because
   it launders a guess into a claim.

2. **`set-usage` numbers are ~4× low, and `token_budget` inherits the error.** The skill documents
   the harness figure as "a directional FLOOR (~final context)". Measured here: **411 K reported vs
   1.63 M effective — a 4.0× multiplier**, consistent across all seven dispatches (3.2×–4.4×).
   Anyone setting `token_budget` on the documented scale will overspend by roughly 4×.
   **Fix:** state the measured multiplier in the contract line, or let `set-usage` take an
   effective-token figure. At minimum, label the report's Tokens column "reported" so it does not
   read as billed cost.

3. **`merge_ledger.py diff` does not accept pathspecs, but `scope` does.** The closeout range picked
   up the loop's own state files (`ledger.json`, the archive move) and ballooned to **862 lines /
   49 files**; the actual source change was 444 lines / 11 files. I had to hand-roll
   `git diff … -- ':!.review-loop'` and write `.stat`/`.diff` myself, which is exactly the hand
   plumbing the verbs exist to prevent.
   **Fix:** accept the same pathspec syntax `scope` already takes, or exclude the loop directory by
   default — nothing in `.review-loop/` is ever under review.

4. **`render_report.py`'s watch-list candidates inherit gap #3.** It reported the round-2 diff as
   "49 files, 524 lines", re-derived from the raw range including loop state. Same root cause, but
   it lands in the one section a human is told to actually read.

5. **Minor: the setup rules only say to archive a *finished* loop.** This repo had an *interrupted*
   one (`.phase` = `seed-review:waiting:human-interrupted`, a round-0 ledger with a stale scope and
   no findings). Neither "REPORT.md exists" nor "`.phase` says done" matched, so the letter of the
   rule said leave it — while "never pile a new loop's files next to an old one's" said clear it.
   Worth one sentence covering the abandoned case.

### One structural note, not a bug

The loop cannot catch two same-family agents agreeing on a wrong fix, and this run has a live
instance: the **only shipped behavior change** (dropping the `?? s.challengeDay` restore fallback)
rests on a totality argument that the implementer made and the reviewer then endorsed. The plugin
handles this honestly — it is exactly what the WATCH LIST exists for, and the report says so. But it
is worth stating plainly that the loop's convergence signal is *not* evidence that a behavior change
is correct; it is evidence that two agents of the same family agreed. A human still has to check
that one, and the watch list should keep leading with it.
