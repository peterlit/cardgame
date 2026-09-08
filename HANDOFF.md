# HANDOFF — for whoever (or whatever) picks this up next

Written 2026-09-04 at commit `5573947`, by the assistant that had been working on this repo, for a
successor with a different account and no inherited memory. Everything below was **verified against
the working tree on the day it was written**, not recalled — where a fact has an expiry (a date, a
count, a "current"), it says so.

The repo's own docs cover the product ([`README.md`](README.md)), the architecture
([`docs/architecture/overview.md`](docs/architecture/overview.md)) and the outstanding work
([`BACKLOG.md`](BACKLOG.md)). **This file carries what was NOT written down anywhere** — the working
agreements and the hard-won traps that lived only in the previous assistant's memory.

---

## 1. The standing rules

These are the owner's explicit, standing instructions. They are not suggestions, and none of them
were discoverable from the code.

1. **Commit at the end of every task, without being asked.** Standing authorization; it overrides the
   usual "only commit when asked". Commit only when the task is actually done and verified, with a
   real message. Work on `main` — this is a solo local project and its whole history is on `main`; do
   not branch. Leave unrelated local artifacts (e.g. `.claude/settings.local.json`) out of the commit.
2. **Keep [`prompts.md`](prompts.md) and [`BACKLOG.md`](BACKLOG.md) current, in the same commit.**
   `prompts.md` is a numbered, chronological journal of the owner's requests and what came of each —
   append one entry per substantive request, written so it reads as a record, not a changelog.
   `BACKLOG.md` tracks outstanding work; move items to Done as they land and add what you find.
3. **Run the review loop after every non-trivial change**, unless told otherwise or the change is
   trivial (typo, formatting, one-line doc edit). The owner treats the adversarial loop as part of
   the definition of done. Ritual: implement → verify → commit → run the loop → commit its
   report/ledger. See §5 for what it costs and how to run it well.
4. **Keep the web build and the iOS app in sync.** They share no code — the rules exist as parallel
   copies in `index.html` and `ios/Causeway/Causeway/Model/*.swift`, held together by drift-guard
   tests. A rule changed on one platform and not the other is a defect, and the test suite is
   deliberately built to catch exactly that.

## 2. The design north star

The owner is a serious FreeCell player (MobilityWare FreeCell; also likes Beleaguered Castle) and
actively dislikes luck-driven, hidden-card solitaire — TriPeaks, Klondike, Crown. Causeway exists
because of that taste: **perfect information, pure skill, high winnability, everything face-up.**

When a design question comes up, that is the tiebreaker. Anything that adds hidden state, randomness
the player can't reason about, or an unwinnable deal is against the grain of the whole project.

## 3. Verified commands

Every command here was run on 2026-09-04 and produced what it says.

```bash
npm test                    # node --test "tests/**/*.test.mjs" → 153 tests, 153 pass, 0 skipped
```

Web preview — a python http.server on port 8123 is configured in `.claude/launch.json` (config name
`causeway`). Daily Challenges need the page **served**, not opened from `file://` (they fetch
`data/daily-pool.json`). If port 8123 is already taken by a stray server, just point the browser at
the existing one.

iOS — **Xcode 26.5 is installed** (older notes claiming "only Command Line Tools" are stale). The
project is `ios/Causeway/Causeway.xcodeproj`, scheme `Causeway`, bundle id
`com.whimsicaldistractions.Causeway`, iPhone-only, portrait + both landscapes.

```bash
# build only
xcodebuild build -project ios/Causeway/Causeway.xcodeproj -scheme Causeway \
  -destination 'generic/platform=iOS Simulator'

# ALL tests — CausewayTests (11 Swift unit tests, seconds) + CausewayUITests (21 UI
# tests, ~8 min serially) → 32 pass, 0 skipped
xcodebuild test -project ios/Causeway/Causeway.xcodeproj -scheme Causeway \
  -destination "id=<UDID>" -parallel-testing-enabled NO -derivedDataPath <scratch>/dd

# just the fast Swift unit tests
xcodebuild test ... -only-testing:CausewayTests
```

Create your own simulator (`xcrun simctl create <name> "iPhone 16 Pro"`) rather than borrowing a
booted one — this Mac runs parallel Claude sessions and they delete each other's devices. Delete
yours when you're done. Note that `xcodebuild test` **builds**, so it always reflects your edits;
`build-for-testing` alone does not run anything (see §4).

## 4. Traps that have cost real time

**Never make throwaway edits to `ios/Causeway/Causeway.xcodeproj/project.pbxproj`.** The owner builds
from this same working tree with Xcode open. When the pbxproj changes underneath a live Xcode session,
Xcode captures the transient value into its Deployment Info and *persists* it — even after the file
is reverted and `git status` is clean. This once shipped a **landscape-only** build to the owner's
physical iPhone that survived delete, clean build folder, and reboot, and took a long painful hunt to
trace: the committed source was correct the entire time; the bad value existed only inside Xcode. If
you need a temporary device config (e.g. rotated screenshots), rotate the *simulator* instead, or do
it in an isolated git worktree.

**A build is not a test.** The review loop's closeout once ran `xcodebuild build-for-testing`,
declared the fix verified, and left the UI test target red on `main` for four days. If your change
touches a test target, run that target.

**`mutate.py` (the mutation harness) builds its worktree from `HEAD`.** Uncommitted work is invisible
to it, and it reports every mutant as `"original text occurs 0 times (need exactly 1; add 'line')"` —
which reads like a malformed manifest and sends you off adding line numbers. Commit first; the same
manifest then runs clean.

**XCUITest `.exists` is true for off-screen elements, and a `LazyVGrid` materialises nothing until it
is actually on screen.** A helper that scrolls "until the element exists" stops after zero swipes and
then finds an empty grid. `.isHittable` on a landmark is NOT enough either — the legend can clear the
fold while the grid below it is still empty; that went green on Sep 4 and red on Sep 7 with no code
change. The calendar helper now scrolls until the TARGET CELL itself (`daily.cal.<idx>`) is hittable,
under a pinned clock (`CAUSEWAY_TODAY_OVERRIDE`, DEBUG-only). Scroll toward the thing you need, and
never key a UI test on the real date — the pool is finite, so real-date tests are time bombs.

**`ios/Causeway` has no Swift unit-test target** (only `CausewayUITests`). Every guard on Swift logic
is therefore a *string comparison* performed by a Node test (`tests/ios-parity.test.mjs`) — whole-body
pins that catch an inserted line, plus behavioural coverage of the web twin. This is a known
structural weakness, it is what stalled the last review loop, and adding a real test target is an open
decision, not an oversight. Until then: a Swift change that is only "pinned" is not tested.

## 5. The review and QA loops

Two plugins from the `quiller` marketplace drive them: `review-loop-tools` (adversarial
implementer ↔ skeptical-reviewer, over a code diff) and `qa-loop-tools` (persona-driven UX testing in
the simulator). They are installed under `~/.claude/plugins/`, so they belong to the *machine*, not to
the account — but check they are present before promising a loop.

Things worth knowing before you run one:

- **Start a loop in a fresh session.** The same plumbing costs ~3× more in a large-context session; a
  hook warns you. The last run measured 4.32 M effective tokens for 17 findings.
- **Loop state is versioned** (`.review-loop/`, `.qa-loop/` are tracked; only `.qa-loop/evidence/` is
  ignored). Archive a finished loop before starting a new one — the skill's `archive` verb does it.
- **Measure the cost afterwards** with [`tools/loop-usage.py`](tools/loop-usage.py) (in-repo, reads
  the raw session transcripts) and write it up. That pattern has produced
  `docs/loop-token-usage.md` plus a feedback doc per version —
  [`docs/review-loop-0.8.1-feedback.md`](docs/review-loop-0.8.1-feedback.md) is the most recent and
  the most useful to read first, because the owner maintains these plugins and acts on the feedback.
- **A loop's conclusions are not proof.** Its convergence signal means two same-family agents agreed.
  Read its `FIX:` notes as hypotheses: the last blocker's remedy was necessary but not sufficient, and
  applying it verbatim left the tests just as red. The loop also once recorded the September calendar
  bug in its own output — as a *justification for a test skip* ("the grid shows this month only") —
  twelve hours before it arrived as a user bug report.

## 6. Where things stand (2026-09-04)

**Green.** `npm test` 139/139, the iOS UI suite 21/21, zero skips on either. `main` is clean.

**The pool expires on 2026-09-30.** `data/daily-pool.json` holds 61 certified days from the
2026-08-01 epoch. After that date there are no daily challenges at all, on either platform. The owner
has explicitly **deferred** seeding more; the tooling to do it is `tools/solver/` and
[`docs/solver.md`](docs/solver.md). This is the single most time-sensitive item in the repo.

**Blocked on the owner, and required before an App Store submission** (see
[`docs/shipping-readiness.md`](docs/shipping-readiness.md)): a Support URL, a hosted Privacy Policy
URL, the contact email in `store/privacy-policy.md`, and a pass on real iOS 17/18 hardware — only
simulator runtimes 18.5 and 26.5 exist on this Mac. Rollback point for the shipping-prep work is the
git tag `pre-ship-prep`.

**Open work** is at the bottom of `BACKLOG.md`, newest sections last — the last review loop and QA
loop each left a section naming what they did not close. The largest open item there is the missing
Swift test target described in §4.

**Recent history worth skimming:** the last four commits fixed the daily calendar (it could only ever
draw the current month, so on 2026-09-01 all of August became unreachable), fixed the calendar cells'
accessibility, and recorded the loop measurements. `prompts.md` entries 83–85 tell that story from the
owner's side.

## 7. Where the knowledge lives

| Path | What it holds |
|---|---|
| `README.md` | The game, how to play, how to run it |
| `prompts.md` | Numbered journal of every request and its outcome — the project's narrative |
| `BACKLOG.md` | Outstanding work, with the loops' leftovers in dated sections |
| `docs/architecture/` | `overview.md` (both platforms + the parity contract), `app.md`, `web-prototype.md` |
| `docs/daily-challenges.md` | The daily-challenge design and its objective grammar |
| `docs/solver.md`, `tools/solver/` | The offline solver that certifies the daily pool |
| `docs/shipping-readiness.md` | App Store status, owner action items |
| `docs/*-feedback.md`, `docs/loop-token-usage.md` | Loop economics and plugin feedback |
| `.review-loop/`, `.qa-loop/` | Live and archived loop state, ledgers, reports |
| `tests/` | The canonical shared logic (`daily.mjs`, `engine.mjs`) + the suite; `web-extract.mjs` lifts and RUNS shipped `index.html` code; `ios-parity.test.mjs` pins the Swift twins |

## 8. What you do not inherit

The previous assistant kept per-project memory outside this repo; a different account starts empty.
Everything from it that still matters has been folded into this file and
[`CLAUDE.md`](CLAUDE.md) — the memory itself is not worth reconstructing, and parts of it had gone
stale (it still claimed Xcode was not installed and that the suite had 67 tests).

If your setup supports persistent memory, the four rules in §1 and the pbxproj trap in §4 are the
ones worth storing, because they are the ones that cost something when forgotten.
