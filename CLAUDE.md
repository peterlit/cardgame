# Working agreements for Causeway

Read [`HANDOFF.md`](HANDOFF.md) once at the start of a new stretch of work — it carries the project's
state, its verified commands, and the traps that have cost real time. The rules below are the ones
that apply to *every* task, so they live here.

## Standing instructions from the owner

- **Commit at the end of every task, unasked.** Standing authorization. Only when the work is done
  and verified, with a real message, on `main` (never branch — solo project, single-line history).
  Keep unrelated local artifacts out of the commit.
- **Update [`prompts.md`](prompts.md) and [`BACKLOG.md`](BACKLOG.md) in that same commit.**
  `prompts.md` gets one numbered entry per substantive request — what was asked, what was actually
  found, what was done. `BACKLOG.md` gets what's newly open or newly closed.
- **Run the review loop after any non-trivial change** (`review-loop-tools:review-loop`), unless the
  owner says otherwise or the change is genuinely trivial. It is part of the definition of done.
  Start it in a *fresh session* — it costs ~3× more in a large one.
- **Loop directories: conclusions in git, evidence and scratch on disk.** The nested
  `.gitignore` allowlists in `.qa-loop/` and `.review-loop/` are the definition of
  "conclusion". To track a new durable output type, add its exact name to the allowlist;
  never `git add -f` around it. `tests/repo-hygiene.test.mjs` enforces this.
- **Keep `HANDOFF.md` up to date.** When a task invalidates something it asserts — a count, a
  command, a trap, the state of the world — fix it in the same commit.
- **Web and iOS must stay in sync.** `index.html` and `ios/Causeway/Causeway/Model/*.swift` are
  parallel implementations of the same rules, held together by drift-guard tests. Change a rule on
  one platform, change it on the other, and make a test prove it.

## Design north star

Causeway is a **perfect-information, pure-skill** solitaire, built for a FreeCell player who dislikes
luck and hidden cards. Everything face-up, high winnability, no randomness the player can't reason
about. That is the tiebreaker for design questions.

## Two things that will bite you

- **Never make throwaway edits to `ios/Causeway/Causeway.xcodeproj/project.pbxproj`.** The owner has
  Xcode open on this same tree; it captures transient values and ships them even after you revert.
  This once shipped a landscape-only build to a physical iPhone. Rotate the simulator, or use an
  isolated worktree.
- **A build is not a test.** If a change touches a test target, run that target — `build-for-testing`
  passing has already let a red UI suite sit on `main` for days.

## Verify before you claim

- `npm test` → 171 tests, 0 skipped (as of 2026-09-09, after the review loop).
- iOS: `xcodebuild test -project ios/Causeway/Causeway.xcodeproj -scheme Causeway
  -destination "id=<UDID>" -parallel-testing-enabled NO` runs BOTH targets — `CausewayTests`
  (17 Swift unit tests, seconds) and `CausewayUITests` (72 UI test methods / 75 executions,
  ~30 min; split into class groups if one xcodebuild call would exceed 10 min) → 0 skipped. Create your own simulator; parallel sessions on this Mac delete each other's.
- The daily pool runs out **2026-10-31** (`data/daily-pool.json`, 92 days from 2026-08-01). Extend it
  with `build-month.mjs --extend --days <total>` (see `docs/solver.md` §5); never rebuild.
