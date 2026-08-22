# Causeway — QA Loop Report (loop 3)

**Builds:** round 1 `6ee255b` → fixes `5447237` → rounds 2–3 on `2b66b93` (app binary =
`5447237`; later commits are test-files-only) · **Rounds:** 3 (cap 3) · **Testers:** 3
parallel workers + 1 uncontended perf lane · **Regression tests:** ON (4 emitted)

---

## Stop condition: **CONVERGED** (round 3, confirmed on a full pass)

0 open blockers, 0 open majors, none newly introduced, and the round-3 full pass's
coverage manifest accounts for all 51 test cases (50 ran, TC-5.3 blocked with reason).
This is the loop's first true convergence: round 1 found 13 findings, the round-1
implementer fixed all 11 auto-routed ones in a single pass, round 2 verified all of them
fixed (10 closed, 0 new), and round 3 re-confirmed on a fresh full pass.

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Net | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|-----|----------|
| 1 | full | 0 | 3 | 7 | 3 | 0 | 10 | 0 | -10 | continue |
| 2 | targeted | 0 | 0 | 1 | 3 | 10 | 0 | 0 | +10 | full_pass_required |
| 3 | full | 0 | 0 | 4 | 3 | 1 | 3 | 0 | -2 | converged |

**Focus-area verdicts (why this loop ran):** both prior-loop majors are confirmed dead.
The WF-6 demo-exit integrity contract held in every probe all three rounds: Stop and Done
re-deal the seed byte-identically fresh, a 3–4 s drag during a demo never lifts a card
(md5-identical frames), a completed 86-move line banks nothing (`causeway.wins` /
`causeway.daily` never written), and a mid-demo background+kill restores the fresh
re-deal, never the demo position. TC-2.6 confirmed the portrait tall-column fix: per-column
fan compression to the legibility floor, then ONE uniform whole-board shrink at the 16th
card (foundations + free cells + tableau to one size), monotone within a deal, bottom card
always tappable. Perf lane measured the shrink relayout at ~1.05 s settle with no stall.

## Fixed this loop (11 findings, commit `5447237`, all fix-review-accepted, all screen-verified twice)

- **major** portrait DailyHUD truncated Silver/Gold objectives → ViewThatFits stack/wrap.
- **major** demo pill silently discarded an in-progress daily attempt → confirm dialog
  ("End your daily attempt?"); cancel preserves attempt+HUD+clock; no attempt-restore
  after the demo (the trap — restoring would reopen the banked-line hole).
- **major** landscape "Play a deal" alert hid Random/Cancel behind the keyboard →
  Random action removed (redundant with New game); Play/Cancel now side-by-side, visible.
- drop released in the strip below a column was refused → column drop zones extend to the
  tableau bottom (web mirrored).
- unmovable-card interactions gave zero feedback → 0.3 s shake on non-run-head cards only
  (silent for movable-but-targetless taps; suppressed during demos).
- demo's move count shown as the player's ("Moves 86 / Time 0:00") → em-dashes during demo.
- calendar weekday header dropped Thu/Sat (duplicate ForEach ids) → positional ids.
- Auto-finish cycle passed through On and instantly ended a finishable game → cycle is now
  Ask→Off→On (web mirrored); deliberate flip-to-On still cascades (trap respected).
- landscape disabled Undo was a blank capsule → removed `.buttonStyle(.plain)` from rail pills.
- Export/Import gave no acknowledgement before the ~1–2 s picker warm-up → immediate
  "Opening Files…" note (+0.46 s vs stall's 1.6–1.8 s); warm-up itself is system cost, accepted.
- zero accessibility identifiers in the app → `card.<S><rank>` (+VoiceOver labels),
  `stat.*`, `toolbar.*`, `demo.*`, `daily.*` added; verified by ~40 identifier-driven
  interactions with no gesture change.

## Open findings — auto-routed minors (4)

| ID | What / evidence |
|---|---|
| `bug/WF-4:clock-never-stops-on-repeat-win` · fix_risk **metric-integrity** | Undo out of a won deal, re-complete it: the overlay re-shows but the clock keeps running on an all-home board (12:45→13:03 observed). **Trap in ledger note:** fix by moving `stopTimer()` out of the `winRecorded` guard — do NOT reset `winRecorded` (that guard keeps undo-padded elapsed out of WinStore; verified the banked best stayed honest). Evidence: `evidence/round-3/qa-worker-1/wf4-*.png` |
| `bug/WinOverlay:rewin-time-understated` · fix_risk **metric-integrity** | Same family, other face: the re-win overlay reports a time short by exactly the cascade (11:26 vs header 11:34). Fix together with the above. Evidence: `evidence/round-3/qa-worker-3/` |
| `bug/WinsView:deal-number-grouping-inconsistent` | `10005–10007` (range chip) vs `Deal #10,005` (row) vs `Deal #10006 ✓` (pill) — LocalizedStringKey interpolation groups Ints, String interpolation doesn't. Same family as the archived loop's `deal-number-format-inconsistent`. |
| `bug/Main:accessibility-identifier-gaps-remaining` | Known gaps after the a11y fix: win-overlay title/pills, alert buttons, empty slots, calendar letters/cells (suggested names in ledger). Also: heart pips expose VoiceOver label "Remove From Favorites" (SF Symbol default) — cosmetic a11y blemish noted by two testers. |

## UX PROPOSALS (human decides — flip routing to `auto` and re-run to accept)

1. **`ux/WF-6:challenge-mode-silently-dropped-after-demo` (major).** After demo-exit from a
   daily, the player is silently in casual mode — no HUD, no notice; solving from there
   earns no tier. *Trap flagged at filing:* silently re-arming the challenge would let a
   player bank a tier off the shown line; any fix needs the design-intent check.
2. **`ux/WF-3:new-game-discards-progress-no-confirm` (minor).** One tap discards an
   in-progress game with no confirm — includes the demo-pill-on-casual-game path two
   testers reproduced (the round-1 confirm fix deliberately covers daily attempts only).
   A confirm would break WF-3's documented one-tap bar; that's the trade to decide.
   Related backlog: DV-1.
3. **`ux/WF-5:no-seed-or-date-override-for-daily` (minor).** TC-5.3 (day-boundary streaks/
   tiers) is permanently blocked without a `#if DEBUG` date/seed override. Must not ship in
   Release (streak farming), must not write the record store.

## FIX REVIEW REJECTIONS

None — all 11 round-1 fixes judged sound on first review (traps explicitly checked:
WF-8's maybeAutoFinish shortcut, WF-6's no-restore rule, WF-2's no-cue-on-movable rule,
drop-zone priority, disabled-pill styling collateral).

## REGRESSION TESTS (emitted; parked target)

Four XCTSkip-guarded XCUITests in `ios/Causeway/CausewayUITests/` (commits `e02161a`,
`2b66b93`): demo-never-scores contract, portrait tall-column tap-ability, calendar
weekday letters, landscape disabled-Undo legibility (pixel-contrast assertion). Round 2's
identifier work let the first two be retrofitted from raw coordinates to `card.*`/`stat.*`
queries. **They now run** (2026-08-21): the UI Testing Bundle target was added to `project.pbxproj`
directly, the skip lines were removed, and all four pass. One needed recalibration —
`landscape-disabled-undo` asserted an absolute luminance spread > 0.10, which no rail pill can
reach because disabled pills are `.opacity(0.4)` and the metric is diluted by the pill's empty
area; it now asserts contrast *relative* to an enabled pill of the same style (measured: disabled
0.0725 / enabled 0.3088 = 0.235; a blank capsule would be ~0). The round-3-verified a11y fix got no dedicated
test: the two retrofitted tests inherently fail if the identifiers vanish, which is the
same guard.

## PERSONA MATRIX (from the results manifests)

| Workflow | Label | Novice | Power | Hole? |
|---|---|---|---|---|
| WF-1, WF-10 | novice | yes | — | no |
| WF-4, WF-7, WF-8, WF-11 | power | — | yes | no |
| WF-2, WF-3, WF-5, WF-6, WF-9, WF-12 | both | yes | yes | no |
| P-A..P-E | probes | — | yes | (power-only by design) |

No coverage holes. *Caveat:* `coverage.json` itself under-reports personas — merge_coverage
keeps one row per test case per round, so a both-persona submission is collapsed
(last-write-wins). This table is built from the raw fragments, which retain both rows.

## COVERAGE GAPS

- **TC-5.3 (both personas, every round) — blocked.** Day-boundary daily behavior needs a
  date override that doesn't exist; tracked by proposal #3. The one legitimate observation:
  the midnight flip (#10,004→#10,005) was watched live during round-0 exploration and the
  Daily card updated correctly without relaunch.

## Material WORKFLOWS.md edits this loop (flagged, not re-gated)

1. WF-6 expectation rewritten to the changed demo-exit contract (Stop/Done re-deal; a
   movable demo board or a banked demo win is a major bug).
2. New tall-column tester note (uniform whole-board shrink is design; clipping is a bug).
3. Fixture policy: daily deal is derive-at-test-time with a midnight-crossing hazard note
   (this loop ran across midnight; a tester watched the flip live).
4. WF-7 rewritten post-fix: the deal alert is now Play/Cancel only (Random removed as
   redundant) — removal is intended, not a regression.

## WATCH LIST — read this part

| # | Item | Why look |
|---|---|---|
| 1 | Re-win clock pair (`clock-never-stops-on-repeat-win` + `rewin-time-understated`) | fix_risk **metric-integrity** and the obvious fix is a trap (don't reset `winRecorded`). One root cause, two symptoms; whoever fixes it should land both and re-verify the banked-best honesty test the tester ran. |
| 2 | `ux/WF-6:challenge-mode-silently-dropped-after-demo` | The only open major (proposal). Its naive fix re-opens the demo-banking hole this whole loop exists to keep closed. Design-intent check is mandatory on acceptance. |
| 3 | Auto-finish cycle change (`5447237`, Game.swift + index.html) | Behavior change to a shipping control (Ask→Off→On). Reviewed + verified, but it also changed the Off→Ask path to pass through On — a tester noted it; nobody judged it worth filing. Your call. |
| 4 | Deal-alert Random removal (`5447237`, ContentView.swift) | The implementer removed a user-visible action as its fix (justified: byte-identical to New game). Verified fine; flagged because deleting UI is the kind of fix a human should consciously bless. |
| 5 | Demo-discard confirm (`5447237`, DailyView.swift + index.html) | Guards daily attempts only; casual games still re-deal silently (deliberate scope, folded into proposal #2/#3 decisions). |

**Perf lane (both rounds measured): clean.** Cold launch ≤0.94 s, idle 0.0–1.2 %, RSS flat
~370–380 MB across 22 deal cycles, cascade 0.20 s/card, demo 0.249–0.257 s/move, board-shrink
relayout ~1.05 s with continuous animation, zero network bytes ever. Only stall: the accepted
UIDocumentPicker warm-up (unchanged, now acknowledged in-UI).
