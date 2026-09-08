# Review-loop feedback — what the skeptical review saw that the loop didn't

Written 2026-09-08, while fixing all eleven findings of
[`docs/skeptical-review-2026-09-07.md`](skeptical-review-2026-09-07.md). The loop under
discussion is `review-loop-tools` v0.8.1, whose last run (2026-08-31, two rounds, 4.32 M
effective tokens, 17 findings) is archived under `.review-loop/`. This is feedback about the
*plugin*, in the spirit of [`review-loop-0.8.1-feedback.md`](review-loop-0.8.1-feedback.md),
collected as standing instruction while the fixes landed.

## The headline

The loop ran two full adversarial rounds over this codebase and found **none of R1–R8** — the
startup race that loses a live Gold, the (day, seed) identity gap, the win→undo→win cleanup
skip, five unguarded board-replacement routes, the non-Gregorian calendar bug, the unreachable
modal, the stale-drag crash, and a builder that overwrites 61 good days with 0 and exits 0. An
independent reviewer found all of them in one pass.

That is not a judgment call the loop got wrong; it is a *scope* the loop never entered. Worth
being precise about, because the loop's actual findings (the WF-3/4/7/13/14 family, the
autoplay tier guard, the calendar accessibility work) were real, and every one of its fixes
**held up** under the skeptical review — several were explicitly praised. The loop is good at
what it looks at. The gap is what it looks at.

## Why the loop missed them, concretely

1. **Diff-scoped attention.** Every R1–R4 defect lives in the *relationships* between features:
   startup × fetch, save × pool generation, undo × win recording, N different buttons × one
   predicate. A diff review meets each edge alone, and each edge alone looks fine. The
   skeptical review's decisive move was tracing one conceptual transition ("replace a board",
   "finish a game") across every entry point that performs it.
2. **Source-reading instead of probes.** The reviewer agent HAS Bash and the simulator, but in
   practice argued from source. The skeptical review *executed* everything: stubbed-DOM web
   probes, a compiled Swift harness, a scratch run of the builder. Its every P1 came with a
   reproduction; the loop's FIX: notes are hypotheses (0.8.1 feedback §5 already asks for a
   `fix_verified` flag — this run strengthens that ask into: **a P1 without an executed
   reproduction should not be reportable as a P1**).
3. **The wall clock was part of the test oracle.** The loop's green UI suite was green *because
   of the date*: the calendar helper's stopping criterion went red on Sep 7 with zero code
   changes (R10). A convergence signal that varies with the calendar is not a convergence
   signal. The suites now pin the clock (`CAUSEWAY_TODAY_OVERRIDE`); the loop should prefer
   running date-sensitive suites under a controlled date, and treat "passes today" as weak
   evidence when it cannot.
4. **Nobody audited the harness.** `web-extract.mjs` declared 4 cells against the shipping 3,
   under two loop rounds — every extracted-function test ran on a board the app never deals.
   While fixing R1 I found a second latent harness bug the same way (`scanTo` truncated any
   function with a destructured parameter). Suggest a cheap round-0 sanity pass: diff the test
   environment's constants/stubs against the shipped declarations they mirror.

## What changed in the repo that the loop should now exploit

- **`CausewayTests` exists.** Swift behaviour claims are now cheaply executable — including a
  full replay of all 61 certified lines through the real move API in ~3 s. A reviewer that
  suspects a Swift lifecycle bug can *demonstrate* it as a unit test instead of pinning text.
  The implementer should be required to leave such tests behind (this pass did: restore
  identity, win→undo→win, the clock).
- **The extraction sandbox got wider.** `loadWeb()` now stubs persistence and exposes the
  daily-lifecycle names, so shipped web scoring runs end to end in Node. Same exploit applies.
- **Pinned-clock UI tests.** `CAUSEWAY_TODAY_OVERRIDE` (DEBUG-only) exists for exactly the
  "run this under a controlled date" move.

## Concrete asks, in priority order

1. **A whole-system round type.** Once per loop (round 0 or a closing round), a reviewer
   charter that ignores the diff and traces named lifecycles end to end: every caller of the
   board-replacing/scoring/persisting operations, every async boundary between a restore and
   the data it needs. R1–R4 were all findable by that charter alone. Rotating charters
   (identity, async readiness, publishing contracts, harness sanity) would cover more per
   token than a third same-shaped round.
2. **P1 ⇒ executed reproduction** (supersedes the `fix_verified` ask — both directions:
   findings and fixes). The harnesses above make this cheap on this repo now.
3. **Controlled dates when the suite is date-sensitive**, and a warning in the report when a
   green suite was taken on the real calendar.
4. **Round-0 harness sanity check** (constants/stub drift against shipped code).
5. **Ingest external reviews when present.** A `docs/skeptical-review-*.md` in the tree is
   exactly the REVIEW.md seeding the controls doc describes — the loop should offer to consume
   it as round-0 findings instead of rediscovering (or missing) the same ground.

## Cost comparison worth keeping

The 0.8.1 run: 4.32 M tokens, 17 findings, 2 rounds, stopped on soft thrashing. This fix pass
(all 11 findings fixed, 2 new latent bugs found, 6 commits, 3 platforms of tests) ran inline
in a single session at roughly a quarter of that. The difference is not the model — it is that
the skeptical review handed over *verified, reproduced* findings, so no tokens went to
adversarial back-and-forth about whether anything was real. That is the strongest argument for
ask #2: reproduction up front is what made every downstream token productive.
