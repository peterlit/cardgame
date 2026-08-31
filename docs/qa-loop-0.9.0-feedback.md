# QA loop v0.9.0 — token usage and feedback

Run of 2026-08-30 against Causeway at `b2ce1a4` (the ⏰ same-day + 🌟 flawless release, immediately
after the review loop hardened it). Plugin `qa-loop-tools@quiller` **0.9.0**, git `c9e4415`.

Settings: `max_rounds=2`, `parallel_testers=2`, `emit_regression_tests=true`,
`token_budget=3,000,000` (harness scale). Measured with `tools/loop-usage.py --since 1788119875`
against raw transcripts, same accounting as `docs/loop-token-usage.md`.

---

## 1. Headline

| | |
|---|---|
| Wall clock | ~5 h 10 min (15:57 → 21:07) |
| Rounds | round 0 (explore) + round 1 full + round 2 targeted |
| Stop condition | **backstop** (hit max_rounds) — 0 blockers, 2 open majors |
| Subagent dispatches | 27 |
| Test cases | 69, all run; 3 blocked (landscape — see §4) |
| Findings | 26 — 0 blocker, 11 major, 15 minor; 20 auto / 6 proposal |
| Outcome | 14 fixed and **verified on device**, 12 open |
| **Total effective tokens** | **27,328,130** |
| Orchestrator share | 2,913,532 (10.7%) |
| Subagent share | 24,414,598 (89.3%) |
| Cost per finding | 1.05 M |

Against `docs/loop-token-usage.md`'s prior QA measurement (2.21 M per finding, 39.87 M subagent
tokens over 3 rounds) this run is **roughly half the cost per finding**. Two rounds and chunked
dispatches account for most of that.

## 2. Where it went

| | Requests | Images | Cache read | Cache write | Output | **Effective** |
|---|---:|---:|---:|---:|---:|---:|
| Orchestrator | 90 | 1 | 19,200,226 | 201,660 | 117,682 | **2,913,532** |
| Subagents (27) | 2,332 | 440 | 167,783,358 | 2,683,133 | 312,270 | **24,414,598** |

**Cache reads are the entire story: 167.8 M read against 312 K of output.** The loop spends ~99% of
its budget re-reading context on every turn, not generating. Images are a rounding error — 440
screenshots × 1,600 = 705,600 tokens, **2.6%** of the total. Anyone optimising a simulator-driven
loop by taking fewer screenshots is optimising the wrong thing; turns and per-request context are
what cost.

## 3. What it bought

Eleven majors, and the four that matter share one root cause worth naming: **the app changed a
scored outcome with no player input.**

- **Auto-play — On by default — silently destroyed a daily medal.** Its greedy send put 8♠ on the
  *down* foundation at day 29's certified-flawless position, killing 🥇 and 🌟 with zero taps.
- **The "Ready to finish" prompt fired early and cost a medal on 19 of 30 reachable days**, today
  included: on day 21 it offers at move 64 of an 87-move flawless line, and Finish pays out 🥉🥈.
- **A legacy backup imported with 0 entries skipped and fabricated medals** (Gold 1 → 11 total),
  defeating exactly what the v2→v3 daily wipe exists to prevent.
- **The novice demo path banked nothing**: after "tap Done to try it yourself", Done landed on a
  HUD-less casual deal.

None of these are findable by reading code — they need the app running, a certified solution line,
and a tester willing to check what the medal actually says at the end. That is what the loop is for.

It also surfaced a **latent web bug nothing was looking for**: `index.html`'s `objViolated`/
`objSecured` were still switching on pre-parameterised objective ids, so every current objective fell
through to `default: false` and the web HUD never showed a ✗.

## 4. Coverage and honesty

All 69 cases ran. Three are `blocked`, not silently dropped: **device rotation is unreachable from
this toolset** and a tester exhausted four routes before recording it (no MCP orientation action; no
`simctl` rotate; Simulator's Device ▸ Rotate needs assistive access, `osascript` → -1728; the
`com.apple.iphonesimulator` orientation defaults are silently reverted on window open). WF-12 is
therefore entirely unverified, including the landscape call sites of two new confirms. The report
says so rather than implying coverage.

---

## 5. Feedback on v0.9.0

### What works, and should not be touched

1. **"A fix is fixed only when a tester confirms it on the device" is the plugin's core insight, and
   it paid out this round.** The implementer claimed 15/15 fixed. The fix-reviewer cleared 14 and
   rejected 1. Then round 2's testers found that **the reviewer's own clearance was wrong on a
   second item**: it had waved through a `0.1 s asyncAfter` hop as "a minor pattern smell but
   functions correctly", and a tester showed the hop lands the destructive button **10 pt** from the
   alert's, so an ordinary double-tap discards a live game unread. Two layers of review missed it;
   the device caught it. Do not let anyone "optimise" the loop by trusting the fix-reviewer's verdict
   as terminal.
2. **`fix_risk` is the highest-signal field in the schema.** Nine findings carried one, and the four
   `metric-integrity` ones drove the implementer to an explicit principle — *"the app may withhold an
   automatic action, but it may never re-choose one"* — that is visibly better than what it would
   have done unprompted.
3. **Proposals excluded from convergence.** Six design questions sat out the whole loop without
   deadlocking it. Exactly right.
4. **`plan_round.py` targeting.** Round 2 went from 69 cases to 24 automatically, and `paths(WF-n)`
   made it deterministic rather than a judgment call.
5. **The regression writer's refusal to write a non-discriminating test.** It declined a UI guard for
   `ux/WF-8` because "on a fresh deal almost nothing is safe under `isSafeAutoplay`, so *Moves
   unchanged after toggling* passes with the fix reverted." A loop that knows the difference between
   a guard and a green checkmark is worth a great deal.

### Bugs and gaps, worst first

1. **`set-usage` ACCUMULATES instead of setting — and the budget is what it feeds.** Calling it twice
   for the same `(round, role)` adds. I recorded round 1 as 1,191,000 and later as 1,334,000, and the
   ledger read **2,525,000** — 89% over, against a 3,000,000 budget. A BUDGET stop would have fired
   mid-loop on a number that was never spent. Either make the verb idempotent (its name says `set`)
   or add `add-usage` and make `set-usage` replace.

2. **The harness figure is ~11× low here, not the "directional floor" the contract implies.**
   Reported cumulative **2,483,604** against a measured **27,328,130**. Compare the review loop the
   same day: 4.0×. The multiplier is not a constant — it scales with turns per dispatch, and the QA
   loop's testers run 80-150 tool calls each. A `token_budget` set on the documented scale
   under-controls by an order of magnitude. Recommend: state that the ratio is workload-dependent and
   roughly 4× for code loops and 10×+ for simulator loops, or record effective tokens directly.

3. **`qa_metrics.py` is not idempotent — it appends a trend row on every invocation.** Running it
   three times for round 1 (perfectly reasonable: once after the functional lane, once after the perf
   lane, once after the fix review) put three round-1 rows in `rounds.md`, and `render_report.py`
   rendered all five rows as the trend table. I had to dedupe by hand. Replace the round's row
   instead of appending.

4. **`HARNESS_NOTES.md` fights its own ceiling, and every tester pays.** The skill says keep it under
   ~10 KB and warns an 86 KB file was ~30% of per-request cost. Testers append to it every dispatch —
   correctly, they learn real things — so it crossed the ceiling **four times** in one loop (39 KB →
   9.6 → 18.9 → 12.0 → 18.5 → 10.1). `notes-rotate` twice reported `over_ceiling: true` and could not
   get under on its own; I had to hand-archive a section. With 27 dispatches each paying for the file,
   this is real money. Suggest: rotate automatically before every dispatch, and cap per-chunk appends.

5. **`fix-reviewer` writes only exceptions to its fragment, which reads as a contract violation.** The
   dispatch instructions say "set each reviewed finding's `current_status`"; it returned "14 sound, 1
   rejected" but wrote **one** finding. That turns out to be correct — the tester owns verification —
   but the merge printed `updated: 1` against 15 reviewed and I had to reason about whether the
   artifact was truncated. One sentence in the skill ("the fix-reviewer records rejections only;
   `fixed` is minted by the next test pass") would remove the ambiguity.

6. **Nothing resets device state between chunks within a round.** The skill resets per round. But
   testers inject saves (`make_save.mjs`, `stats_state.py`), and one chunk's fixture became the next
   chunk's starting state — a tester reported "this device arrived **not** state-reset (today already
   showed 🌟 Flawless and 1-day streaks)" and had to wipe prefs itself. I added a reset between every
   pair. Worth making that the documented default in parallel mode.

7. **Minor: `merge_ledger.py diff` has no pathspec** (same gap as the review loop's). The report's
   watch-list candidates read "22 files, 3207 lines" for the round-1 diff because `.qa-loop/ledger.json`
   (+943) and `coverage.json` (+440) are counted as source changes. The loop's own state is never
   under review.

8. **Minor: `agent` is always `null`** in the usage rows, so subagent cost cannot be split tester vs
   implementer vs reviewer. (This is a bug in *our* `tools/loop-usage.py`, already filed in BACKLOG —
   noted here because it is why §2 has no per-role breakdown.)

### One judgment call worth recording

The Stage 1 gate asks the human to sign off on `WORKFLOWS.md`, and this run showed why that gate
earns its cost: the doc had gone stale across six commits and was **materially wrong** — it described
a pre-epoch sandbox that no longer exists and six objective families that had all been replaced. Had
testing started against it, testers would have filed false bugs for a whole round. The subsequent
`fix-reviewer` audit then caught three more material errors in my own rewrite, including one
("silver falls back to bronze, there is no `silver` key") that would have made testers file a false
"missing pill" bug on seven reachable days. **The audit step is the cheapest insurance in the
plugin** — 110 K tokens against a round that costs ~15 M.
