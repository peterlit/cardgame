# Review loop v0.8.1 — token usage and feedback

Run of 2026-08-30 23:19 → 2026-08-31 10:00, scope
`b2ce1a4..HEAD -- :!prompts.md :!BACKLOG.md :!.qa-loop :!.review-loop :!causeway-reviewer-evaluation-examples.md`
— i.e. the QA loop's own output (12 fix commits + 8 XCUITests) plus the two features that landed on
top of it. Plugin `review-loop-tools@quiller` **0.8.1**.

Measured with `tools/loop-usage.py --since 1788146360` against the raw session transcripts — not
estimated. Same accounting as `docs/loop-token-usage.md`: effective tokens weight the billed classes
`input ×1 + cache_read ×0.1 + cache_write ×2 + output ×5`, records deduplicated by `requestId`,
images at a flat 1,600.

---

## 1. Headline

| | |
|---|---|
| Active wall clock | ~71 min (23:19 → 00:04, then 09:33 → 10:00; overnight pause waiting on a human answer) |
| Rounds | seed + 2 rounds + closeout |
| Stop condition | **thrashing_soft** → human chose abort + closeout |
| Subagent dispatches | 7 |
| Findings | 17 — 1 blocker, 9 major, 7 minor |
| Outcome | 7 fixed, 5 partial, 4 open, 1 disputed |
| Suite | 120 → 135 tests, all green; 27 mutants killed across 3 manifests |
| **Total effective tokens** | **4,321,064** |
| Orchestrator share | 690,613 (16.0 %) |
| Subagent share | 3,630,451 (84.0 %) |
| Cost per finding | 254 K |
| Cost per *fixed* finding | 617 K |

Against the 0.7.1 run (2.16 M, 197 K/finding) this one cost **2×** and returned a worse
per-finding number. The scope is the reason: 0.7.1 reviewed one feature's diff, this reviewed a
whole QA loop's output — 3,493 lines across web, Swift and the node suite — and it did not converge.

## 2. Where it went

| Dispatch | Role | Requests | Reported | **Effective** | Ratio |
|---|---|---:|---:|---:|---:|
| `a8dfff8d` | seed reviewer | 47 | 165,896 | **810,977** | 4.9× |
| `a7a8f5fe` | round 1 implementer | 53 | 94,901 | **533,786** | 5.6× |
| `a12debab` | round 1 reviewer | 29 | 78,083 | **291,595** | 3.7× |
| `a16f9302` | round 2 implementer | 38 | 64,903 | **318,788** | 4.9× |
| `a90878b2` | round 2 reviewer | 22 | 59,198 | **227,959** | 3.9× |
| `a73ddf38` | closeout implementer | 66 | 102,462 | **645,759** | 6.3× |
| `a1992c45` | closeout reviewer | 64 | 111,078 | **801,587** | 7.2× |
| | **subagents** | **319** | **676,521** | **3,630,451** | **5.4×** |
| `08f14643` | orchestrator | 34 | — | **690,613** | — |

By role: reviewers 2,132,118 (162 requests), implementers 1,498,333 (157 requests).

Two things stand out. **The closeout is now the most expensive phase of the loop** — its two
dispatches are 1.45 M, 40 % of all subagent spend, more than either real round. And the
reported→effective ratio is **5.4×**, not the ~4× the skill's contract line documents; it tracks
turns-per-dispatch, so the two 60+-request closeout dispatches ran at 6.3× and 7.2×. Anyone
budgeting `token_budget` on the reported scale is off by five-fold, and worse on long dispatches.

Cache reads are 19.0 M against 72 K of output. The loop pays to *re-read*, not to think.

## 3. What it actually bought

One real data-loss bug and, mostly, proof that the previous loop's work was untested:

- **`DailyView.swift:480` silently discarded the per-day clear log on import.** The backup importer
  re-built every `TierResult` field by hand and omitted `runs`, so restoring your own stats onto a
  new device dropped the entire run history the feature had just been built to record. One argument.
- **Four of the seed's five majors were test-integrity findings, all mutation-proven.** Deleting
  `if(sent) continue;` from the cascade, neutering both web tier-refusal functions, and stubbing
  `objViolated` to `return false` on *both* shipped copies each left the suite green. The features
  shipped by the QA loop were, at that point, deletable without a red test.
- **The fix for that was structural**: `tests/web-extract.mjs` lifts declarations out of `index.html`
  by name and runs the shipped code, replacing string pins with behaviour. The reviewer promptly
  defeated its first version with an indented decoy; round 2 anchored it to column 0 and made
  ambiguity throw.
- **The closeout found a blocker in its own phase**: the UI test target is red on the shipping tree,
  because the calendar cell applies `.accessibilityLabel` to a bare `ZStack` with no accessibility
  element — a locator that had never matched, hidden until an `XCTSkipUnless` was replaced with a
  hard assert. That is also a live VoiceOver defect. It is finding #1 on the watch list.

It did **not** converge. All four open majors are one structural fact: `ios/Causeway` has no Swift
unit-test target, so every Swift guard is a string comparison run by a node script, and each round
pinned the functions the reviewer named while the reviewer found new ones. `thrashing_soft` fired on
exactly the right signal.

---

## 4. Feedback on v0.8.1

### Fixed since 0.7.1 — confirmed in this run

All four actionable gaps from `docs/review-loop-0.7.1-feedback.md` are closed:

1. `mutate.py` now reports an explicit error count; every dispatch quoted "0 apply errors"
   unprompted, and the reviewer's independent re-runs matched the implementer's claims every time.
2. The Tokens column is labelled "reported" with the measured multiplier in the header.
3. `merge_ledger.py diff` takes pathspecs and excludes `.review-loop/` by default. The whole
   hand-rolled diff plumbing from last run is gone.
4. The setup rules now cover the *abandoned* loop case, not just the finished one.

### What works, and should not be touched

1. **Mutation verification remains the highest-value mechanism in the plugin.** Every major this run
   was found or killed by `mutate.py`. The reviewer's habit of writing its *own* mutants — not just
   re-running the implementer's manifest — is what caught the two rounds of over-claiming (4 of its
   9 round-1 mutants survived; 2 of its round-2 mutants survived).
2. **`region` + thrashing detection did real work.** The loop stopped because all four open majors
   shared one region, which is exactly the whack-a-mole it is designed to notice. The human question
   it produced was the right question.
3. **The three-plumbing-turns-per-round shape holds the orchestrator at 16 %** of spend across 34
   requests, on a run with 3.6 M of subagent traffic.

### Bugs and gaps, worst first

1. **The closeout shipped a red test target, and the loop has no phase left to catch it.** *(This is
   the same failure shape 0.7.1 flagged — "a closeout minor grew into a redesign" — recurring in a
   new form.)* The closeout implementer ran `xcodebuild build-for-testing`, never `test`, and its
   `verify_cmd` was node-only; nothing else in the loop executes the XCUITest target, so
   `main` is red right now. The closeout reviewer caught it only because it ran the target itself.
   **Fix:** require the closeout implementer's `verify_cmd` to cover *every test target the diff
   touches*, and have the orchestrator reject a CHANGES block whose `verify_cmd` does not mention a
   target the diff modified. A build is not a test.

2. **A blocker opened by the closeout reviewer has nowhere to go.** The rules say new closeout
   findings go to BACKLOG, no further cycle — correct for a minor, wrong for a blocker that is
   `introduced_by_fix` and leaves the tree red. The report duly filed it under "open" and the loop
   declared itself done.
   **Fix:** one exception — an `introduced_by_fix` blocker from the closeout reviewer earns a single
   scoped implementer dispatch (the same "smallest correct change" rule), or, if the human is
   unattended, an explicit `phase: done-but-red` in the report headline rather than a
   quietly-listed finding.

3. **`thrashing_soft` at `N == max_rounds` asks an incoherent question.** The skill told me to ask
   "abort, or run one more round?" while the backstop already forbade round 3. `BACKSTOP` should be
   evaluated *before* `THRASHING_SOFT`, or the prompt should say "raise `max_rounds` and continue".
   As written, "one more round" is an answer the plumbing cannot honour.

4. **`escalated_max_rounds` fired on the closeout merge, after the loop had stopped.** The
   closeout reviewer's blocker bumped `max_rounds` 2 → 5 with zero rounds left to run; the ledger
   now claims `max_rounds: 5` on a run that executed 2, which will mislead anyone reading the state
   later. **Fix:** suppress the scope-mode escalation for closeout merges — it exists to buy rounds,
   and by then there are none to buy.

5. **`render_report.py`'s watch list still inherits raw ranges** — the one 0.7.1 gap that did not get
   fixed, now the only place loop state leaks. It reported round 1 as "12 files, 1038 lines, largest
   `.review-loop/ledger.json` (+104/-192), `.review-loop/archive/…/ledger.json` (+278/-0)"; the real
   diff is 5 files, 449 lines. `merge_ledger.py diff` already knows the exclusions — reuse them.

6. **`merge_ledger.py scope` echoes only its first token.** Passing
   `b2ce1a4..HEAD -- :!prompts.md :!BACKLOG.md …` prints `{"scope": "b2ce1a4..HEAD"}` while storing
   the full string. The one moment you are checking that your excludes took, the tool says they
   didn't. One-character fix (`args[1]` → the joined value it actually wrote).

7. **A named simulator can vanish mid-run, and the agents proceed anyway.** The udid I booted and
   named in every dispatch was deleted by another session between round 2 and the closeout. The
   closeout implementer noted "the dispatched simulator does not exist" and simply skipped every
   XCUITest — which is precisely how the red target shipped unseen. **Fix:** the skill should tell
   agents to treat a missing dispatched device as a *stop-and-report*, not a skip; and the
   orchestrator should re-verify the device exists at each dispatch, not just boot it once.

8. **Minors wait for the one phase where they are most dangerous.** Three seed minors sat untouched
   for two rounds and were then all fixed in the no-iteration closeout — where one of them changed
   the `hasLiveGame` predicate on *both platforms*. The "minors never cost a round" rule is right
   about cost and wrong about risk: a minor that touches shipping code should be routable into a
   round, or explicitly flagged in the closeout brief as "behaviour change — expect a reviewer
   audit of every call site" (which, to its credit, is what the reviewer then did).

### Structural note

The loop's convergence signal still is not evidence that a behaviour change is correct — and this
run has a clean instance: `hasLiveGame` now ORs in the ⏰ grace on both platforms, audited by one
reviewer that enumerated the call sites and ran one XCUITest class. The watch list leads with it, as
designed. Worth repeating because this run makes the sharper version of the point: the loop is
*excellent* at proving a test is worthless, and only as good as one agent's reading at proving a
shipped predicate is right.

---

## 5. Postscript — what the days after the run taught (2026-09-04)

Three days of ordinary work on the reviewed code turned two of the gaps above from arguments into
measurements, and found one new item that matters more than any of them.

### The closeout-blocker gap has a price now

Gap #2 predicted that a blocker opened by the closeout reviewer has nowhere to go. It went nowhere:
the loop wrote its report, marked itself `done`, and left the UI test target RED on `main`. It stayed
red until a human read the report and asked for the fix by hand. Nothing in the loop escalated, and
nothing would have.

### NEW — a "FIX:" note carries the reviewer's authority whether or not the reviewer tried it

The blocker's note ended with a specific, confident remedy: *add
`.accessibilityElement(children: .combine)` … then re-run BOTH calendar tests.* Applying exactly that
left both tests still failing. Dumping the accessibility tree showed why — **two** faults, not one:

1. the cell was not an accessibility element (the reviewer's half — necessary, and it does work: cells
   now expose as `Button, label: "Sep 3"` instead of a bare `staticText "3"`); and
2. `openDailyCalendar` scrolls until the legend `.exists`, which is TRUE for an element that is only
   in the hierarchy — so it stopped after zero swipes with the grid still below the fold, and the grid
   is a `LazyVGrid`, which materialises nothing (not even its weekday header) until it is on screen.
   Switching that predicate to `.isHittable` is what turned the class green, 3/3, 0 skipped.

The reviewer ran the test and read its failure message; it never inspected the tree, so its causal
story was the plausible one rather than the true one. That is a fair thing for a reviewer to do — but
the report renders a PROPOSED fix and a VERIFIED one in identical prose, and a reader (or the next
implementer) cannot tell them apart.

**Fix:** add a `fix_verified` flag to any finding whose note carries a remedy, set only when the agent
actually applied it and re-ran, and render the others as "remedy proposed, not verified". One field,
and it stops a confident sentence from being mistaken for a tested one.

### NEW — the loop normalised a product defect into an environmental constraint

The closeout implementer wrote this skip reason, and the closeout reviewer read the file and endorsed
it: `XCTSkip("today is the last day of the month — the grid shows this month only, so it holds no
future cell")`. Both agents therefore KNEW the calendar drew the current month and nothing else. Both
treated it as a property of the app to design tests around.

Twelve hours later that exact fact arrived as a user bug report: *"We are in September now, and I can
no longer navigate to August to play older deals."* Every August challenge — including an attempt
still inside its ⏰ grace — had fallen off both platforms on the 1st.

The finding was never missed for want of evidence; it was written down, in the loop's own output, as
a justification. A scoped review looks at a diff, and "the grid can only ever show one month" was not
in the diff — so the constraint got absorbed instead of questioned.

**Fix:** when an agent justifies a skip, an exemption, or a test-shape decision by citing a product
limitation, that citation must be emitted as a finding (severity arguable, existence not). It is
mechanical, it is nearly free, and here it was the difference between a report and a user's bug
report. Worth a companion line in the report template too: *"this review saw only `<range>`; behaviour
outside it was not examined"* — the WATCH LIST is diff-anchored and should say so.

### mutate.py's error message points at the wrong thing

`mutate.py` builds an isolated worktree from HEAD, so uncommitted work is invisible to it. A manifest
run against a working tree returns every mutant as
`"original text occurs 0 times (need exactly 1; add 'line')"` — which reads as a malformed manifest
and invites you to go add line numbers. The same manifest, unchanged, went 7 killed / 0 survived /
0 errors the moment the change was committed. **Fix:** when the count is 0, say so in the worktree's
own terms — *"not found in the worktree at HEAD; mutate.py cannot see uncommitted changes."*
