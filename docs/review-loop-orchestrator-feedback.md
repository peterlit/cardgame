# Review-loop plugin feedback — orchestrator's perspective (2026-09-08 run)

Run: scope `6c248b8..a0dd4a4 -- :!prompts.md`, converged after 2 rounds + closeout.
14 findings (1 blocker, 4 majors), 13 fixed, 1 open minor to BACKLOG. ~512k reported
subagent tokens. This is feedback on the *plugin*, from the session that drove it.

## What worked

- **`next-round` is the right shape.** Merge + metrics + advance + brief + phase in one
  call made each round genuinely three orchestrator turns. The verdict JSON was always
  actionable without reading any state file.
- **Automatic escalation fired correctly.** The seed blocker bumped `max_rounds` 2→5 at
  merge time with an explicit `escalated_max_rounds` key — nothing to remember.
- **Brief generation matched the doctrine exactly.** Round briefs carried the blocker,
  majors, and fix_risk minors; the two plain minors were correctly held for closeout, and
  `open … closeout` produced exactly those two. Zero hand-filtering all run.
- **The `diff` verb kept every round diff out of orchestrator context** (522 and 231 lines
  materialized to files; the read_guard never had cause to fire). The measured design goal
  — plumbing stays cheap — held: the orchestrator side of this run was a small fraction of
  subagent spend.
- **The iterate-on-regressions structure paid for itself immediately.** Round 1's blocker
  fix introduced a *new* blocker (cap starvation) that only surfaced because round 2's
  reviewer re-ran the scenario at a different size. A single-pass review ships that bug.
- **The mutation-manifest chain** (implementer writes manifest → reviewer re-runs
  `mutate.py` → reviewer also reproduces by hand) produced the strongest evidence of the
  run: the new cap assertion demonstrably kills the mutant it exists for.

## Friction

- **Usage accounting around closeout is confusing.** `next-round --usage` covers rounds,
  but closeout has no `next-round`, so its two dispatches go through `add-usage` — and the
  echo (`"round_tokens": 175115` after adding 41,862 to an implementer who had 66,346)
  reads like corruption until you realize `round_tokens` is the *round total across
  roles*. The report then folds closeout into round 2's role figures, losing the
  per-phase breakdown. Suggest: a dedicated `closeout` usage slot, and echo per-role
  figures in `add-usage` output.
- **The closeout reviewer's phase marker is unspecified.** The skill names
  `round-<N>-implementing` for the closeout implementer but never says what the closeout
  *review* phase should be; this run reused `round-2-review`. One sentence would fix it.
- **No machine verdict after the closeout merge.** `--no-escalate` merge returns counts
  only; whether the outcome is "done" vs "done-but-red" is left to the orchestrator's
  reading of prose. A closing check (any open `introduced_by_fix` blocker → done-but-red)
  would mechanize the one rule that currently rests on orchestrator diligence.
- **Watch-list candidates need pruning, not just filling.** `render_report` emitted 10
  candidates for a 2-round loop; the doctrine says a human should read 3-5. The template
  invites filling every slot. Either cap the candidates (scope + rounds + open/introduced
  findings) or say explicitly that the orchestrator should drop rows.
- **Scope pathspecs: the verbs accept them, but nothing echoes the parse.** After the
  skill's (justified) warning about quoted pathspecs reaching git literally, a
  `{"range": "...", "pathspecs": [":!prompts.md"]}` echo from `scope`/`diff` would
  confirm the exclude actually took, instead of leaving it to faith.
- **Simulator lifecycle is entirely on the orchestrator.** The skill mandates naming one
  booted udid per dispatch but never says to clean it up; on a Mac where parallel sessions
  already delete each other's simulators, leaked devices are a real cost. Add
  create-at-setup / delete-at-done to the skill text.
- **Shared-journal collision hazard.** Implementers append to `prompts.md`/`BACKLOG.md`
  per round and the orchestrator appends at closeout. Sequential today, but any future
  parallelism (or a human editing mid-loop) collides on those files.

## Net

The loop caught a structural blocker that five green commits and 153 passing tests had
hidden, then caught the regression its own fix introduced, and shipped with the full
suite green on both platforms. The verbs did what the doctrine promised; every rough edge
above is bookkeeping, not architecture.
