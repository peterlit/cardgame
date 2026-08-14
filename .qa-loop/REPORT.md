# Causeway — QA Loop Report

**Verdict: CONVERGED** after Round 1 (full pass). No open blockers or majors, none
newly introduced, confirmed on a full pass. Core play is solid across both personas;
what remains is 2 minor auto-routed defects and 2 UX proposals for your decision.

Build under test: `1fd938c`. Personas: Novice (discoverability), Power user (efficiency).
Interactive testing was portrait-only (this environment can't rotate the simulator);
landscape (WF-12) and a scored win overlay (WF-4) were code-reviewed, not live-driven.

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Net | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|-----|----------|
| 1 | full | 0 | 0 | 2 | 2 | 0 | 2 | 0 | -2 | converged |

## Open findings by severity

### Minor — auto (clear defects; cheap, localized fixes)
1. **`bug/WF-11:cancel-note-not-updated`** — Cancelling the Import file picker (X) leaves
   the default BACKUP helper text instead of "Import cancelled."; Export has the same gap
   (swipe-dismiss shows the helper text, not "Export cancelled or failed."). Root cause:
   SwiftUI `.fileImporter`/`.fileExporter` `onCompletion` isn't invoked on interactive
   cancel on this iOS build, and Import sets `backupNote = nil` first. Data-safe — purely
   missing feedback. Evidence: `evidence/round-1/wf11-import-cancel-note.png`.
2. **`ux/WF-11:singular-plural-grammar`** — Count of 1 renders plural nouns: "1 days",
   "1 deals" (`DailyView.importStats`) and "1 deals solved · 1 ranges" (`WinsView`). Should
   be "1 day" / "1 deal" / "1 range". The `entr(y/ies)` path already pluralizes, so the fix
   is localized. Evidence: `evidence/round-1/wf11-import-edited-merged-skipped.png`,
   `wf9-wins-empty.png`.

### Disputed
None.

## UX proposals (your call — flip routing to `auto` and re-run to accept)
1. **`ux/WF-6:demo-done-leaves-empty-board`** — Tapping **Done** on the demo-complete banner
   ("tap Replay to try it yourself") dismisses the only guidance and leaves an inert,
   fully-solved board (all cards home, Won still 0). Not a trap — Replay/New game/Deal# all
   work — but a novice can misread it as "I won." **Cost to user:** momentary confusion / a
   dead-end-looking screen. **Proposed fix:** have Done re-deal the seed (Replay) so the
   board is immediately playable. Evidence: `evidence/round-1/wf6-demo-done-emptyboard.png`.
2. **`ux/Main:clock-runs-during-modal-sheets`** — The solve clock keeps ticking while modal
   sheets (Daily / Wins / How to play) are open (observed 0:21 → 3:40 with zero moves).
   Since `WinStore` records seconds and daily best-times are time-sensitive, reading the
   rules or checking stats mid-solve silently inflates recorded time. **Cost to user:**
   worse recorded times through no fault of play. **Proposed fix:** pause the clock while a
   sheet is presented (vs. keep it wall-clock). Judgment call — many timers run
   continuously. Evidence: `evidence/round-1/wf-clock-runs-in-menus.png`.

## What passed (both personas, portrait)
WF-1/WF-2 tap-smart-move (to foundation and tableau) + instant drag-to-place; WF-3 New
game / Replay / Undo each one tap, empty Undo correctly dimmed; WF-5 Daily streaks +
legible objectives + calendar select/locked-future; WF-6 demo opens paused, Next/Start
step, stays unscored; WF-7 Deal # (out-of-range 9999999 clamps to 1,000,000; Cancel safe);
WF-8 Auto-play / Auto-finish toggles reflect state immediately and persist; WF-9 Wins empty
+ populated; WF-10 How to play / About (`Causeway · v1.0 (1)`); WF-11 Export (dated file) +
Import (valid merge, non-backup rejected, hand-edited sanitized — 4 skipped); sheet
swipe-dismiss; persistence of board/seed/settings/win-count across relaunch.

## NFR (Round-1 sampler, 184 samples)
Idle CPU ~0–2%, zero network — no drain/traffic concern. RSS grew 181 → ~357 MB then
plateaued (356→358→357) after a jump coinciding with the demo + Files picker. Not a
controlled repeated-action loop, so **inconclusive for a leak** — worth a New game/Undo
×10+ loop to confirm before ship.

## Not live-tested (noted, not fabricated)
- **WF-4** scored win overlay — not hand-solvable from a fresh install this session;
  overlay + record-win logic code-reviewed, looks sound.
- **WF-12** landscape — environment can't rotate the simulator; rail/foundations/tableau
  three-column branch with a scroll-bounded rail code-reviewed, looks correct.

## Watch list (read these)
- `ux/Main:clock-runs-during-modal-sheets` — **look here because** it silently corrupts a
  recorded metric (solve time / daily best) with no user error; the fix touches when the
  clock starts/stops, which interacts with the deferred-win and auto-finish timing.
- `ux/WF-6:demo-done-leaves-empty-board` — **look here because** the "fix" (Done → Replay)
  is a behavior change to the demo exit; confirm it's what you want vs. just clearer copy.
- `bug/WF-11:cancel-note-not-updated` — **look here because** it's an iOS API-behavior quirk
  (cancel doesn't call onCompletion); the fix must detect dismissal without a false
  "cancelled" on a real pick.
- **Landscape (WF-12) has no live coverage** — the one headline feature the loop could not
  exercise in this environment. Verify on a real device or a rotatable simulator.

## Loop notes
- No material `WORKFLOWS.md` edits during the loop.
- Convergence fired on Round 1 because it gates on blockers+majors only; the 2 auto-routed
  **minors were not sent to an implementer** (that happens on a `continue` verdict). They
  remain open above for a quick follow-up if you want them fixed.
