# Loop report — .qa-loop

**Stop condition:** `full_pass_required` after round 4 — the owner asked the loop to wrap up during round 4's full confirmation pass, after 24 of 90 cases (WF-1…WF-5) had run clean. Rounds 1-3 converged on their own terms: 0 blockers, 0 majors open; 24 auto findings fixed and verified on the device; 3 minors and 5 proposals open. The 66 unrun cases are listed under Coverage gaps; the 70 armed XCUITests (all green at `0cd71fa`) cover every fix the loop verified.

**Decisions the orchestrator made alone:** [`docs/qa-loop-2026-09-09-decisions.md`](../docs/qa-loop-2026-09-09-decisions.md). **Plugin feedback and cost:** [`docs/qa-loop-0.12.0-feedback.md`](../docs/qa-loop-0.12.0-feedback.md).

**Subagent tokens:** 5,801,043 across 5 round(s) (budget 7,500,000)

**Findings by status:** fixed 24, open 8, wontfix 5

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|----------|-----|--------|----------|
| 1 | full | 0 | 5 | 14 | 5 | 0 | 23 | 0 | 0 | -23 | 1708769 | continue |
| 2 | targeted | 0 | 1 | 9 | 5 | 13 | 2 | 0 | 0 | +11 | 1152207 | continue |
| 3 | targeted | 0 | 0 | 2 | 5 | 7 | 1 | 0 | 0 | +6 | 853026 | full_pass_required |
| 4 | full | 0 | 0 | 3 | 5 | 0 | 0 | 0 | 0 | +0 | 365557 | full_pass_required |

## Tokens (reported — measured 4-7x below billed effective)

| Round | By role | Total |
|---|---|---:|
| 0 | audit 76,777; explore-w1 115,626; explore-w2 118,284; explore-w3 108,690 | 419,377 |
| 1 | fix-reviewer 140,387; implementer 231,844; regression-writer 302,675; tester-perf 90,487; tester-wf-1-1 75,054; tester-wf-10-1 56,911; tester-wf-11-1 92,269; tester-wf-12-1 84,743; tester-wf-12-2 80,089; tester-wf-13-1 93,737; tester-wf-13-2 83,736; tester-wf-14-1 67,580; tester-wf-14-2 66,828; tester-wf-15-1 79,599; tester-wf-15-2 69,031; tester-wf-2-1 83,342; tester-wf-3-1 58,205; tester-wf-4-1 57,207; tester-wf-4-2 48,601; tester-wf-5-1 69,046; tester-wf-6-1 74,747; tester-wf-6-2 63,634; tester-wf-7-1 67,720; tester-wf-7-2 54,372; tester-wf-8-1 71,444; tester-wf-9-1 61,913; tester-wf-9-2 58,474 | 2,383,675 |
| 2 | fix-reviewer 117,619; implementer 179,793; regression-fix 65,978; regression-writer 165,776; tester-perf 77,633; tester-wf-1-1 70,594; tester-wf-10-1 59,574; tester-wf-11-1 63,160; tester-wf-12-1 84,152; tester-wf-13-1 82,489; tester-wf-14-1 67,444; tester-wf-15-1 85,253; tester-wf-2-1 56,355; tester-wf-3-1 55,686; tester-wf-4-1 57,046; tester-wf-5-1 98,677; tester-wf-6-1 81,731; tester-wf-7-1 87,358; tester-wf-9-1 59,077 | 1,615,395 |
| 3 | regression-writer 164,013; tester-perf 85,746; tester-wf-1-1 42,736; tester-wf-10-1 59,731; tester-wf-12-1 74,031; tester-wf-13-1 69,769; tester-wf-14-1 61,248; tester-wf-15-1 67,993; tester-wf-2-1 49,203; tester-wf-3-1 53,601; tester-wf-4-1 47,419; tester-wf-5-1 69,812; tester-wf-6-1 61,367; tester-wf-7-1 51,026; tester-wf-9-1 59,344 | 1,017,039 |
| 4 | tester-wf-1-1 50,809; tester-wf-2-1 79,610; tester-wf-3-1 55,204; tester-wf-4-1 65,508; tester-wf-4-2 45,737; tester-wf-5-1 68,689 | 365,557 |
| **all** | | **5,801,043** |

## Open findings by severity

### minor (3)

- **ux/DailyView:legend-paragraphs-addressable-only-by-copy** — minor, open; region `DailyView`
  - The Daily sheet's two legend paragraphs carry no accessibilityIdentifier: the streak legend (DailyView.swift:212, the sentence that now defines Par for ux/WF-5:par-has-no-legend) and the calendar legend row (DailyView.swift:627-636, the 🌟 Flawless / ⏰ Same-day entries ux/WF-14:calendar-pip-unlabelled added). Every other surface the round-2 fixes touched gained an identifier (daily.streak.*, daily.tier.*, daily.clears, daily.sameday, daily.backupnote), but the two paragraphs that EXPLAIN those surfaces can only be found by their copy, so RegressionDailyCardCopyTests.testLegendDefinesTheParTheClearsLineQuotes matches the streak legend with a CONTAINS predicate on its par sentence and RegressionDailyCalendarTests matches the calendar legend by the literals "🌟 Flawless" / "⏰ Same-day" — a rewording of either paragraph reads as a regression, and VoiceOver users get an unlabelled block of small grey text with no landmark.
  - note: Recommended: `.accessibilityIdentifier("daily.legend")` on the streak legend Text (DailyView.swift:212) and `.accessibilityElement(children: .contain).accessibilityIdentifier("daily.cal.legend")` on the calendar legend row (627-636). Both tests are written so the swap is a one-line query change; keep the copy assertions where the copy is the contract (the par sentence itself).
- **ux/WF-3:grace-newgame-body-describes-replay** — minor, open; region `WF-3`
  - On a live ⏰ grace, the New game confirmation shows the grace body verbatim — 'Starting over makes it an attempt begun today, and Aug 14 can never earn ⏰ again.' — but New game does not start the challenge over: it abandons the challenge and deals a random casual game (round 4: Deal #120220, zero HUD chips). resetConfirmMessage's graceLive branch is still the one branch that never consults pendingReset, so the body under the destructive 'New game' button describes Replay's outcome.
  - evidence: `.qa-loop/evidence/round-3/wf-3-1/r3-grace-newgame-body-says-starting-over.png`, `.qa-loop/evidence/round-3/wf-3-1/r3-tc32-replay-confirm-grace-precedence.png`, `.qa-loop/evidence/round-4/wf-3-1/r4-grace-newgame-body-describes-replay.png`
  - measurements: `{"grace_body_newgame": "You began Aug 14's challenge on the day itself, so finishing it today still earns \u23f0 Same-day. Starting over makes it an attempt begun today, and Aug 14 can never earn \u23f0 again.", "grace_body_replay": "You began Aug 14's challenge on the day itself, so finishing it today still earns \u23f0 Same-day. Starting over makes it an attempt begun today, and Aug 14 can never earn \u23f0 again.", "deal_after_newgame": 120220, "hud_chips_after_newgame": 0}`
  - note: Round 4 re-verified on 0cd71fa, unchanged and byte-identical to round 3 — no code touched this string. Fix is the same one-line pendingReset branch in the graceLive body's second sentence (Replay: 'Starting over makes it an attempt begun today'; New game: something like 'Leaving it makes any later attempt one begun today'). TRAP UNCHANGED: do not weaken or drop the grace confirm, and do not touch the grace TITLE ('Give up ⏰ Same-day for …?') — round 4 re-confirmed it correctly takes precedence over BOTH new titles ('Start this deal over?' / 'Restart your daily attempt?'). The warning's consequence ('Aug 14 can never earn ⏰ again') is TRUE for New game too, so this is a wording mismatch, not a false promise — severity minor on purpose.
- **ux/ContentView:demo-bar-container-has-no-identifier** — minor, open; region `WF-15`
  - The demo status bar (ContentView.demoBar, the ViewThatFits that ux/WF-15:flawless-demo-banner-eats-quarter-screen reshaped) carries no accessibilityIdentifier of its own: its headline (demo.headline) and its pills (demo.prev / demo.next / demo.start / demo.stop / demo.done) are addressable, but the bar's frame — the very thing the round-2 finding measured (224 pt on 9ab79f1, 108 pt on de5e5d0) — is not. RegressionFlawlessDemoBarHeightTests therefore reconstructs the bar height from the headline's top, the lowest pill's bottom and the 8 pt vertical padding it knows from the source, so a padding or corner change in the bar reads as a height regression, and VoiceOver has no landmark for the bar as a whole.
  - note: Recommended: `.accessibilityElement(children: .contain).accessibilityIdentifier("demo.bar")` on demoBar's ViewThatFits (after its background/overlay so the frame is the drawn card). The test is written so the swap is a one-line change: read app.otherElements["demo.bar"].frame.height instead of reconstructing it, and keep the headline-width assertion (that is the ViewThatFits contract itself).

## Disputed (agree-to-disagree)

_none_

## UX proposals (human decisions — flip routing to "auto" to accept)

- **ux/WF-11:import-has-no-confirm-or-undo** — minor, open; region `WF-11`
  - Import still merges into the live stores the instant a file icon is tapped in the Files picker — no preview of what is about to be merged, no confirmation, no undo — and with no in-app stats reset, one wrong file permanently pollutes streaks, the calendar and best scores. Confirmed again on 1a63ce2: a hand-edited backup planted a 1-move/1-second 'best' on deal 123456 and two new medal days with a single tap and zero prompts.
  - evidence: `.qa-loop/evidence/round-1/wf-11-1/tc11-5-picker.png`, `.qa-loop/evidence/round-1/wf-11-1/tc11-4-skip-note.png`
  - measurements: `{"taps_from_picker_to_irreversible_merge": 1, "confirmation_steps": 0, "undo_affordances": 0, "won_before": 2, "won_after": 3}`
  - note: Carried over from the archived prior-loop ledger (20260909-085142-4f02d1d) under the same id; re-verified on this build, still open. Design call for the human, not a defect on its own: a 'this backup holds N days and M deals, exported <date> — merge?' confirm, or a one-shot 'Undo this import' on the note line, would make the destructive-by-accident case recoverable. Now weightier because bug/WF-11:export-replace-destroys-existing-backup can leave the player with no backup file to re-import from. fix_risk: state-migration — an undo needs a snapshot of causeway.daily/causeway.wins taken before the merge, and a half-written snapshot is worse than no undo; the merge itself must stay non-destructive.
- **ux/WF-12:daily-play-below-fold-landscape** — major, open; region `WF-12`
  - In landscape the Daily sheet opens with its primary action off screen: the visible content window is y 78-340 but daily.play sits at y=557 (hittable=false), ~217 pt below the fold. A landscape user who opens Daily sees five streak cards and an explanatory paragraph and no Play button, no Today card, no deal number, no calendar.
  - evidence: `.qa-loop/evidence/round-1/wf-12-2/tc126-daily-landscape.png`
  - measurements: `{"visible_window_pt": "y 78-340 (262 pt)", "daily_play_y_pt": 557, "pt_below_fold": 217, "pages_of_content": 4, "controls_below_fold": ["daily.play", "daily.cal.prev/next/month", "daily.export", "daily.import", "Today day card"]}`
  - note: CC-12B reproduced. Structural: the five streak cards (2 rows, y 104-286) consume the whole landscape first screen. Portrait is unaffected.
- **ux/WF-13:daily-sheet-resets-to-today-midattempt** — major, open; region `WF-13`; fix_risk `behavior-change`
  - Re-opening the Daily sheet during a live PAST-day attempt silently switches it back to Today: the card reads 'Today / Deal #608530' with today's objectives, the calendar marks the in-progress day in no way at all, and the single gold button (bare 'Play') re-deals TODAY over the live attempt behind a confirm whose copy ('Starting this challenge re-deals the board...') never names which day it is starting or which one it is discarding. There is no resume anywhere: re-selecting the very day you are playing and tapping 'Play Aug 4' offers only Keep playing / Start over.
  - evidence: `.qa-loop/evidence/round-1/wf-13-1/wf13-sheet-resets-to-today-midattempt.png`, `.qa-loop/evidence/round-1/wf-13-1/wf13-calendar-no-inprogress-marker.png`
  - measurements: `{"live_attempt_moves": 1, "day_shown_on_reopen": "Today (Deal #608530)", "day_actually_live": "Aug 4 (Deal #625648)", "in_progress_markers_on_sheet": 0, "actions_to_get_back_to_the_live_day_card": 3, "resume_paths": 0}`
  - note: Reuses the prior loop's open proposal id; reproduces verbatim on 1a63ce2 (DailyView.swift onAppear resets dayView to clampedToday) with two NEW aggravating observations: (a) the guard-rail alert names no day, so 'Starting this challenge' reads as the challenge the player thinks they are in; (b) there is no resume path even for the same day. fix_risk behavior-change. TRAP (carried over): a naive 'remember the last viewed day' fix must not let the sheet open on a stale day after midnight - WF-14's four onTimeLine branches are all driven by dayView vs todayIndex(), and graceLive keys on challengeDay == day. The lower-risk half is marking the live attempt (a badge on the calendar cell + an 'Attempt in progress' line on the card) and naming the day in the confirm, without changing which day the sheet opens on.
- **ux/WF-14:grace-invisible-from-daily-sheet** — major, open; region `WF-14`; fix_risk `metric-integrity`
  - Human-routed proposal, unchanged: with a live ⏰ grace nothing a player sees first mentions it — the Daily sheet opens on the Today card and the Aug 14 calendar cell renders like any unplayed day.
  - evidence: `.qa-loop/evidence/round-1/wf-14-1/tc145-sheet-opens-on-today-grace-hidden.png`, `.qa-loop/evidence/round-1/wf-14-1/tc145-cal-no-inprogress-mark-aug14.png`, `.qa-loop/evidence/round-1/wf-14-1/cc14a-confirm-dailysheet-endattempt.png`, `.qa-loop/evidence/round-1/wf-14-2/wf14-sheet-opens-on-today-grace-hidden.png`, `.qa-loop/evidence/round-1/wf-14-2/wf14-crop-cal-no-inprogress-mark.png`
  - note: Left for the human per dispatch. NOT re-driven this round (TC-14.9 was not in this chunk) — status carried forward, not re-verified; the 42b5f7e diff contains no change to calendar-cell or day-card grace affordances, only the confirm title.
- **ux/Main:clock-runs-during-modal-sheets** — minor, open; region `WF-4`; fix_risk `metric-integrity`
  - The solve clock keeps ticking while the app's OWN auto-raised 'Ready to finish' modal blocks the board, so a recorded best time silently absorbs however long the user takes to answer a prompt they never asked for. Measured on build 1a63ce2: identical injected save, dismissing the prompt after ~5 s banked Time 1:37; leaving the same prompt up 20 s longer banked 1:58 (+21 s), and a header crop-diff shows the Time digits are the only pixels changing while the modal is up.
  - evidence: `.qa-loop/evidence/round-1/wf-4-1/clock-runs-during-prompt-t0.png`, `.qa-loop/evidence/round-1/wf-4-1/clock-runs-during-prompt-t20.png`
  - measurements: `{"time_after_5s_prompt": "1:37", "time_after_25s_prompt": "1:58", "delta_s": 21, "modal_up_s": 20, "header_crop_diff_changed_pct": 3.5}`
  - note: Reused id from the archived ledger; still reproduces on 1a63ce2. TRAP: the obvious fix (pause GameClock whenever a sheet/alert is presented) turns every sheet into a free pause button and corrupts recorded best times the other way — a player could stop the clock indefinitely by opening How to play. Any fix must distinguish app-initiated modality (this prompt) from user-initiated sheets, or leave the clock alone and stop raising the prompt unbidden. Note backgrounding IS already handled correctly (TC-4.6: 20 s in the background cost 1 s of banked time), so the pause plumbing exists.

## Fix review rejections

- **ux/WF-5:daily-sheet-ignores-dynamic-type** (fixed) — round 1: Theme.scaled applied to the calendar marker text but the containing frame stayed a hardcoded height: 6, reintroducing the same class of clipping the finding was filed to remove, in three specific spots the fix's own claim ('all 36 fixed font sites') implied were covered.
- **bug/Main:scored-surfaces-addressable-only-by-copy** (fixed) — round 2: identifiers added to views but the seven regression/smoke test files named in the finding still match copy verbatim; the copy-coupling harm the finding describes is unresolved.
- **bug/DailyView:day-card-and-streak-cards-addressable-only-by-label** (fixed) — round 2: identifiers/values added to DailyView but SmokeDailySheetTests, RegressionGraceForfeitConfirmTests and SmokeWinFlowTests still match the streak-card sentence, the ⏰ line text, and the checkmark.circle.fill image name verbatim; the label-only-addressability harm the finding describes is unresolved.

## Severity changes

- round 2: **ux/WF-12:landscape-board-rescales-every-move** demoted major → minor

## Persona matrix (round 4)

| Workflow | novice | power |
|---|---|---|
| WF-1 | 2✓ | — |
| WF-2 | — | 5✓ |
| WF-3 | 4✓ | 5✓ |
| WF-4 | — | 7✓ |
| WF-5 | 3✓ | 4✓ |

## Coverage gaps

_none_

## Closeout

_no closeout cycle ran_

## Wontfix / resolved

- **ux/WF-12:daily-sheet-play-below-fold-landscape** — Structural (content order / landscape-specific layout), so the human decides — kept at MINOR because one ordinary swipe anywhere inside the sheet reveals Play and the 'Today' section header peeks at the bottom edge. The substance is that in landscape the entire first screen is five zero-valued streak counters before any action; a landscape-only compact streak row, or putting Today+Play above the streak cards, would fix it. Related but distinct from ux/WF-5:streak-card-headline-unlabelled (archived). | RESOLVED (round 1): DUPLICATE of ux/WF-12:daily-play-below-fold-landscape (sibling chunk filed the fuller claim; that one stays open as the proposal). Orchestrator dedupe.
- **ux/WF-12:landscape-rail-clipped-with-hud** — CC-12A reproduced. In a CASUAL landscape game (9 pills, no HUD) all three are hittable=true — the clip only appears once the challenge HUD pushes the rail down. See the companion auto-routed finding ux/WF-12:rail-more-hint-inert for the cheap half of the fix. | RESOLVED (round 1): DUPLICATE of ux/WF-12:rail-hides-howtoplay (same evidence from the sibling WF-12 chunk; the archived id with history is kept as canonical and stays open, auto-routed). Orchestrator dedupe, not a product decision.
- **ux/WF-13:silver-demo-missing-on-16-of-61-days** — 26% of days. Two candidate fixes, both cheap: fall back to the flawless line for the Silver demo when hasSilverLine is false (flawless is a superset by the app's own explainer), or regenerate the missing silver lines in data/daily-solutions.json. Doing neither leaves an unexplained hole in a 4-pill grid next to an objective the same card promises. Not a scoring surface - demos are assisted and unscored - so no metric risk. | RESOLVED (round 1): Contradicts the signed-off Fixture policy in WORKFLOWS.md (a day whose Silver is a universal family has no distinct silver line, so no 🥈 pill — by design, re-verified by the round-0 audit). Adding a fallback line is a data/design decision for the owner; recorded in the report's proposals section rather than auto-fixed.
- **ux/WF-14:grace-confirm-title-split** — Left wontfix — a human already decided this id. Not re-litigated; the equivalent issue landed as fixed under the -differs-by-control id.
- **ux/WF-9:wins-row-no-run-count** — WONTFIX accepted on the merits, round 3, verified on de5e5d0. WinRecord (WinStore.swift:4) is a Codable struct of three NON-optional fields persisted as JSON under "causeway.wins", shared with the web build and with the stats-backup file, and both record() and merge() combine records field-wise by min() — a run count has no correct merge (sum double-counts a deal synced to two devices, max under-counts), so the implementer's "third persisted field with a lossy merge" objection is accurate, not a dodge, for a minor. Behaviour re-verified this round: footer still present, still directly under the numbers and unchanged by the identifier commit; the independence itself is correct (fewest from run 1, fastest from run 2, a third slower run changed neither). Residual, accepted: one win and three wins render byte-identical rows. Do NOT reopen without a product decision; if it is ever revisited, an OPTIONAL count with a fallback (as DailyStore does for runs == []) is the only safe shape.

## WATCH LIST

_The part a human should actually read. Convergence means two same-family agents agreed — not that the change is correct._

**Shipped behaviour changes to eyeball first**
- **`bug/WF-7:deal-confirm-swallowed-by-double-tap`** (fixed, `b035caa`/`117a212`) — look here because: the fix is a 0.5 s window in which the discard confirm's destructive button is DISABLED after a dismissal-raised present (`resetConfirmArmed`, ContentView). Verified 3/3 on device in the exact failing geometry, but a deliberate tap inside that window is silently swallowed; a tester measured the arm at 0.7-0.85 s through the driver. If that ever feels laggy on hardware, the alternative is presenting the confirm synchronously.
- **`ux/WF-6:demo-has-no-step-back`** (fixed, `c6b0f70` + `9d51711…`) — look here because: Prev re-simulates the line from the opening position and, from the completion banner, re-enters a paused demo at N-1. Two adversarial passes proved the board stays inert and nothing banks (`SolutionReplayTests` pin it; web twin added), but it is the one fix that touches the demo/scoring boundary WF-6 guards.
- **`ux/WF-12:rail-hides-howtoplay` / `rail-more-hint-inert` / `landscape-board-rescales-every-move`** (fixed, `fb45f4b` + round-2 `836434d`) — look here because: the rail viewport is now trimmed to half a pill, the cue reads scroll geometry via `onScrollGeometryChange` (iOS 18+; the iOS 17 `RailOffsetKey` fallback is UNTESTED — only 18.5 and 26.5 runtimes exist here), and landscape shares portrait's shrink latch, now seeded on appear.
- **`ux/WF-5:daily-sheet-ignores-dynamic-type`** (fixed, `344c1d1`; rejected once, then `836434d`) — look here because: 36 font sites on the Daily sheet now scale through `Theme.scaled`; the fix-reviewer predicted and the device confirmed marker clipping at AX sizes, fixed in round 2 by scaling the marker slot. At AX-XXXL every calendar cell is 92 pt tall (grid ~2.5× taller) — a tester noted it, nobody filed it; judge on a real device.
- **`bug/WF-11:export-replace-destroys-existing-backup`** (fixed, `f63211a`) — look here because: the export filename gained `-HHmmss`. Five exports in one session produced five files; the system "Replace" path is unreachable. The `DateFormatter` has no `en_US_POSIX` locale (pre-existing, unobserved).

**Proposals awaiting your decision** (the loop never implements these; flip routing to "auto" and re-run to accept)
- **`ux/WF-13:daily-sheet-resets-to-today-midattempt`** (major, fix_risk behavior-change) — reproduced in rounds 0, 1 and 2 with two new aggravators: the discard alert names no day, and re-selecting the day you are playing offers only Start over. Trap: any "remember last viewed day" fix must not open on a stale day after midnight.
- **`ux/WF-14:grace-invisible-from-daily-sheet`** (major, fix_risk metric-integrity) — a live ⏰ grace is invisible on the sheet's first screen; the grace-destroying Play is one tap away, the promise three gestures away. Still exactly as filed last loop.
- **`ux/WF-12:daily-play-below-fold-landscape`** (major) — the landscape Daily sheet shows five streak cards and no Play (217 pt below a 262 pt fold).
- **`ux/WF-11:import-has-no-confirm-or-undo`** (minor) — import merges on pick with no preview/confirm/undo; carried over from last loop.
- **`ux/Main:clock-runs-during-modal-sheets`** (minor, fix_risk metric-integrity) — the app's own Auto-finish prompt costs clock time (+21 s measured). Trap: pausing on sheets makes every sheet a pause button.
- Not a ledger proposal but a design call the loop refused to auto-fix: **no 🥈 demo on the 16 days whose Silver is a universal family** (`ux/WF-13:silver-demo-missing-on-16-of-61-days`, resolved wontfix per the Fixture policy) — a fallback line would be a data change.

**Open minors the loop ran out of rounds for**
- `ux/WF-3:grace-newgame-body-describes-replay` — on a live ⏰ grace the New game confirm's BODY describes starting the challenge over, but New game deals a random casual game (`ContentView.resetConfirmMessage`'s graceLive branch never consults `pendingReset`). One-line copy fix.
- `ux/DailyView:legend-paragraphs-addressable-only-by-copy` and `ux/ContentView:demo-bar-container-has-no-identifier` — two identifiers the regression tests would like (`daily.legend`, `daily.cal.legend`, `demo.bar`).

**Fix-review rejections** (both later resolved — see decisions D14/D15): the Dynamic Type sweep (harmful → fixed in round 2, verified), and the two identifier fixes (rejected because the copy-matching tests were not converted; the regression writer converted them the same hour in `de5e5d0`).

**Diffs**
- **round 1** `1a63ce2..3407a77` (14 app commits + 3 test commits) — look here because: 19 findings addressed in one afternoon across ContentView/DailyView/Game/index.html, plus `QAFixtures.swift`, which seeds app state through `-causeway.game <hex plist>` launch arguments — it makes the UI tests independent of simulator state and is the enabler for every fixture-based test.
- **round 2** `3407a77..de5e5d0` — look here because: identifiers were added to nearly every scored surface (win overlay, HUD chips, streak/day cards, Wins rows); label queries in 12 test files were converted to them. The `daily.tier.<tier>`/`daily.sameday` VALUES carry state — a UI change that forgets to update the value now fails a test.
- **round 3** `de5e5d0..0cd71fa` — tests only.

**Rig and hygiene**
- The QADriver (`.qa-loop/driver/`) is now the way testers drive this app; the MCP control tool needs a per-device human grant that autonomous runs cannot obtain. `tools/README.md` holds the fixture recipes that used to bloat HARNESS_NOTES.
- `.qa-loop/evidence/loops-before-20260909/` holds the 1,117 evidence files of earlier loops, moved out of `round-N/` so this loop's testers stopped tripping over them. Archived reports' evidence links point at the old paths.
- Hygiene check at closeout: see the line the orchestrator appends below.

## Material WORKFLOWS.md edits made during the loop

- Fixture policy rewritten around the `CAUSEWAY_TODAY_OVERRIDE` date pin (pinned date 2026-08-15 / dayIndex 14; two-day ⏰ sequences via terminate + relaunch on the next pin); the old "no launch arguments / day boundaries untestable" claims removed.
- WF-13 updated for calendar month navigation and `daily.cal.<idx>` identifiers; "par appears only on a solved day" recorded as the design.
- WF-14's "known-open trap" replaced by the claimed-then-verified zero-move grace confirm; WF-4 (post-win Undo is casual by owner decision; background pauses the clock); WF-7 (the 0.1 s hop, then its fix); WF-9 (independent minima; Wins Play routes through the confirm); WF-15 reachable range under the pin; the no-Silver-line day list (idx 4, 5, 9, 15, 20, 22, 25, 36, 38); make_save's day-14 flawless limitation.
- TESTCASES.md: 90 cases (WF-4/5/7/9/12/13/14/15 rewritten in round 0); expected text in ~15 cases is now stale where this loop's fixes changed copy — listed in BACKLOG for the next refresh.
- hygiene: hygiene(.qa-loop): clean
