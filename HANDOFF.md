# HANDOFF — for whoever (or whatever) picks this up next

Written 2026-09-04 at commit `5573947`, by the assistant that had been working on this repo, for a
successor with a different account and no inherited memory. Everything below was **verified against
the working tree**, not recalled — where a fact has an expiry (a date, a count, a "current"), it
says so. Since 2026-09-09 this file is kept current as a standing rule (§1.5); last full
re-verification **2026-09-20** (all three suites, by the review-loop closeout reviewer).

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
5. **Keep this file up to date.** (Owner's instruction, 2026-09-09.) When a task invalidates
   something HANDOFF asserts — a count, a command, a trap, the state of the world — fix it in the
   same commit. This file already drifted once: for a day it denied the existence of a Swift test
   target that §3 of the same file described.

## 2. The design north star

The owner is a serious FreeCell player (MobilityWare FreeCell; also likes Beleaguered Castle) and
actively dislikes luck-driven, hidden-card solitaire — TriPeaks, Klondike, Crown. Causeway exists
because of that taste: **perfect information, pure skill, high winnability, everything face-up.**

When a design question comes up, that is the tiebreaker. Anything that adds hidden state, randomness
the player can't reason about, or an unwinnable deal is against the grain of the whole project.

## 3. Verified commands

Every command here was run and produced what it says (counts re-verified 2026-09-20).

```bash
npm test                    # node --test "tests/**/*.test.mjs" → 173 tests, 173 pass, 0 skipped
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

# ALL tests — CausewayTests (17 Swift unit tests, seconds) + CausewayUITests (72 UI test
# methods / 75 executions, ~30 min serially; run class groups so no single xcodebuild call
# exceeds a 10-min tool timeout) → 0 skipped
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

**Swift logic was untestable until 2026-09-07** — `ios/Causeway` had no unit-test target, and every
guard on Swift logic was a *string comparison* performed by a Node test (`tests/ios-parity.test.mjs`).
That era is over: `CausewayTests` now exists (commit `743b664`, pbxproj edit authorized by the owner)
with 11 unit tests across `CausewayModelTests`, `GameClockTests`, and `SolutionReplayTests`. The
parity pins remain — they are the web↔iOS drift guard, not a substitute for running tests — so the
residual trap is narrower: a Swift change covered *only* by a pin and not by `CausewayTests` is
still not tested. Run the target.

## 5. The review and QA loops

Two plugins from the `quiller` marketplace drive them: `review-loop-tools` (adversarial
implementer ↔ skeptical-reviewer, over a code diff) and `qa-loop-tools` (persona-driven UX testing in
the simulator). They are installed under `~/.claude/plugins/`, so they belong to the *machine*, not to
the account — but check they are present before promising a loop.

Things worth knowing before you run one:

- **Start a loop in a fresh session.** The same plumbing costs ~3× more in a large-context session; a
  hook warns you. The 2026-09-13 run (v0.13.0, with the panel) measured 2.99 M effective tokens
  for 6 findings; the 2026-09-09 run 5.15 M for 12.
- **Loop state is versioned** (`.review-loop/`, `.qa-loop/` are tracked; only `.qa-loop/evidence/` is
  ignored). Archive a finished loop before starting a new one — the skill's `archive` verb does it.
- **Measure the cost afterwards** with [`tools/loop-usage.py`](tools/loop-usage.py) (in-repo, reads
  the raw session transcripts) and write it up. That pattern has produced
  `docs/loop-token-usage.md` plus a feedback doc per version —
  [`docs/review-loop-0.13.0-feedback.md`](docs/review-loop-0.13.0-feedback.md) is the most recent and
  the most useful to read first, because the owner maintains these plugins and acts on the feedback.
- **The review loop has a multi-provider panel** (`.review-loop/panel.json`: codex `gpt-6-astra`,
  gemini, ollama `qwen3-coder:30b`; consent lives outside the repo under
  `~/.config/review-loop-tools/consent/`). Traps: the `GEMINI_API_KEY` is Google's free tier —
  no Pro model answers and a flash model's daily quota is gone after one diff prompt, so expect
  the gemini lane to run once per day at best; the lanes' timeouts exceed the Bash tool's 10-min
  ceiling, so run `panel_review.py run` detached (`nohup … &`) and poll its log; `read_guard`
  blocks any command whose *text* contains an xcodebuild test invocation, even a heredoc writing
  it to a file — use the Write tool for that.
- **The QA loop now drives the app through `.qa-loop/driver/` (an XCUITest server + `qa.py` client),
  NOT the MCP simulator-control tool** — that tool needs a per-device human grant on every fresh
  simulator, which an autonomous run cannot get. `bash .qa-loop/driver/start.sh <udid>` builds and
  serves; `python3 .qa-loop/driver/qa.py <udid> launch CAUSEWAY_TODAY_OVERRIDE=2026-08-15` etc.
  Fixture recipes moved to `.qa-loop/tools/README.md`. Never run the plugin's `provision_workers.sh`
  while another session might be running a qa loop on this Mac: it deletes EVERY `qa-worker-*`
  device regardless of owner (it happened on 2026-09-09; create uniquely named devices by hand).
- **UI tests seed app state through launch arguments** (`CausewayUITests/QAFixtures.swift`:
  `-causeway.game <hex plist>`), so they no longer depend on simulator state — and they all pin the
  clock. Run the UI target in class groups; the whole thing is ~30 min now.
- **A loop's conclusions are not proof.** Its convergence signal means two same-family agents agreed.
  Read its `FIX:` notes as hypotheses: the last blocker's remedy was necessary but not sufficient, and
  applying it verbatim left the tests just as red. The loop also once recorded the September calendar
  bug in its own output — as a *justification for a test skip* ("the grid shows this month only") —
  twelve hours before it arrived as a user bug report.

## 6. Where things stand (2026-09-20)

**Green.** `npm test` 173/173 (as of 2026-09-20; the iOS counts below are from 2026-09-09); iOS `CausewayTests` 17 unit + `CausewayUITests` 75 executions (72
methods — the launch test runs once per UI configuration, hence +3), zero skips anywhere, all ARMED
(no XCTSkip guards) — counts as of 2026-09-20 after the review loop. `main` is clean.

**The pool expires on 2026-10-31.** `data/daily-pool.json` holds 92 certified days from the
2026-08-01 epoch (October was appended 2026-09-20 with `node tools/solver/build-month.mjs
--select-only --extend --days 92`, from the committed certification cache — ~5 min, no new
certification needed; then `build-solutions.mjs` in four stripes and a copy of both JSON files into
`ios/Causeway/Causeway/`). After that date there are no daily challenges at all, on either platform.
Extending is the same three-step recipe with `--days 122`; the tooling is `tools/solver/` and
[`docs/solver.md`](docs/solver.md). Note: this shell exports a `NODE_OPTIONS` preload that is
missing on disk — run node tools with `NODE_OPTIONS=` cleared or they die before `main`.

**The 2026-09-20 review loop on the October extension** (`.review-loop/REPORT.md`, feedback in
`docs/review-loop-0.13.0-feedback-oct-pool.md`) converged at round 1: 9 findings, all fixed. It
left two guards you will meet at the November append — the iOS JSON copies must be byte-identical
to `data/` (`tests/ios-parity.test.mjs`) and the pool must end on a month boundary
(`tests/solutions.test.mjs`) — and one behavior change in the builder: a (Silver, Gold) pair may
not repeat within a run (the shipped day-3/day-60 repeat is grandfathered; never widen the check to
published days). Panel lesson: pathspec-excluding large files from the scope makes every external
lane file "file X was never updated" — tell the verifier what was excluded.

**Blocked on the owner, and required before an App Store submission** (see
[`docs/shipping-readiness.md`](docs/shipping-readiness.md)): a Support URL, a hosted Privacy Policy
URL, the contact email in `store/privacy-policy.md`, and a pass on real iOS 17/18 hardware — only
simulator runtimes 18.5 and 26.5 exist on this Mac. Rollback point for the shipping-prep work is the
git tag `pre-ship-prep`.

**Open work** is at the bottom of `BACKLOG.md`, newest sections last — each loop leaves a dated
section naming what it did not close. The former largest item (the missing Swift test target) is
CLOSED; what's left open is medium/low: DV-1 (daily Play/solution can silently discard an in-progress
casual game), L2 (web hotkeys fire while typing), L5 (chimera bests), L7/L8 (iOS polish), and one
deliberately-open review-loop minor (the real-clock default in `GameClock` is untested).

**The 2026-09-09 QA loop** (v0.12.0, autonomous, 4 rounds, 3 testers) fixed and device-verified 24
findings — the deal-alert double-tap discard, the export-Replace backup loss, the landscape rail, demo
step-back, Dynamic Type on the Daily sheet, a11y state on calendar cells and tier rows, identifiers on
every scored surface — and left 3 minors + 5 proposals open (`.qa-loop/REPORT.md`, decisions in
`docs/qa-loop-2026-09-09-decisions.md`, cost/feedback in `docs/qa-loop-0.12.0-feedback.md`). The
review loop then ran on those 22 app commits (`1a63ce2..836434d`) the same evening: 0 majors in the
scope itself; 4 seed minors; the fixes spawned a landscape-HUD regression chain (measure → latch →
cap) that closeout finished. Stopped `thrashing_soft` at the scoped 2-round cap; 3 minors left open
(`.review-loop/REPORT.md`, residuals in `BACKLOG.md`). Now the landscape board's HUD reserve is
measured and latched per deal rather than a fixed 50 pt — read the report's WATCH LIST before
touching `ContentView.swift`'s landscape geometry.

**2026-09-13 — the controls redesign (Option A2).** Portrait no longer has a top toolbar: the
controls are a bottom deck (`ContentView.portraitDeck`: Finish pill · Auto-play / Auto-finish
tier · New game · Undo · Replay · Daily · More) and Deal # is a header chip; landscape keeps the
rail, restyled to match (icons, state badges, More, Finish last). Wins and How to play are behind
More in BOTH orientations — UI tests reach them through `QAFixtures.openWins` /
`openHowToPlay`, and the rail-overflow tests key on `toolbar.finish` as the pill below the fold.
Same `toolbar.*` ids otherwise, plus `toolbar.more`. Design record and measured cost:
`docs/portrait-controls-proposal.md`; mockups on the design canvas linked there. The review loop
(v0.13.0 with the panel) ran on that commit the same day and **converged at round 1**: 6 minors,
0 majors; closeout made the rail's More `Menu` id static (`rail.more` / `rail.finish`, commit
`488313d`), tightened the identifier tripwire (`QA.moreItem(strictID:)`, mutation-proven), and
swept the docs. Kept as a deliberate wontfix for the owner's ruling: **PC-4**, the Finish tier's
~43 pt one-way `latchedBoardH` cost in portrait. Residue in `BACKLOG.md` (RL-A2-1..4);
`.review-loop/REPORT.md` has the WATCH LIST.

**Recent history worth skimming:** the 2026-09-07 skeptical review (`docs/skeptical-review-2026-09-07.md`)
and the pass that addressed it — the pool builder now publishes under a fail-closed contract, the
attempt lifecycle got one replacement gate, the Swift unit-test target landed, and two review-loop
rounds converged on that work. Then the loop-state git policy was codified: **conclusions in git,
evidence and scratch on disk**, enforced by `tests/repo-hygiene.test.mjs` via nested `.gitignore`
allowlists in `.qa-loop/`/`.review-loop/`. `prompts.md` entries 86–94 tell that story from the
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
