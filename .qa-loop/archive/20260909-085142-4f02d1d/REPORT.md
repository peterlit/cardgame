# Loop report — .qa-loop

**Stop condition:** `backstop` after round 2 — hit max_rounds

**Subagent tokens:** 2,483,604 across 2 round(s) (budget 3,000,000)

**Findings by status:** fixed 14, open 12

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|----------|-----|--------|----------|
| 1 | full | 0 | 7 | 8 | 6 | 0 | 15 | 0 | 0 | -15 | 1768262 | continue |
| 2 | targeted | 0 | 2 | 4 | 6 | 14 | 5 | 0 | 0 | +9 | 715342 | backstop |

## Open findings by severity

### major (2)

- **ux/WF-14:replay-forfeits-grace-silently** — major, open; region `WF-14`; fix_risk `metric-integrity`
  - The grace-aware confirm is still gated on hasLiveGame (moveCount > 0), so a ⏰ grace with ZERO moves made today — tapped Play yesterday, no move, returned today — is destroyed with no dialog at all by ALL FOUR board-replacing controls: Replay, New game, the Daily sheet's Play button, and a how-to-win demo pill. The app itself shows '⏰ Resume your attempt today and it still counts' on that state one tap earlier, then silently makes it unrecoverable.
  - evidence: `.qa-loop/evidence/round-1/wf-14/tc145-aug29-grace-line.png`, `.qa-loop/evidence/round-1/wf-14/tc146-pathB-after-replay-board.png`, `.qa-loop/evidence/round-1/wf-14/tc146-pathB-after-replay-line.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-grace-line-aug29.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-dailyplay-nodialog.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-replay-nodialog.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-replay-grace-gone.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-newgame-nodialog.png`, `.qa-loop/evidence/round-2/wf-14/wf14-zeromove-demopill-nodialog.png`, `.qa-loop/evidence/round-2/wf-14/wf14-grace-confirm-replay-withmoves.png`
  - measurements: `{"controls_that_destroy_silently": 4, "controls_tested": 4, "dialogs_shown_at_moveCount_0": 0, "dialogs_shown_at_moveCount_85": 1}`
  - note: The round-1 fix's COPY is correct wherever it renders (verified with 85 moves on the board); only the gate is wrong. Bounded: all four controls, on both the board toolbar and the Daily sheet. TRAP (unchanged): do not fix by preserving challengeStartDay across a re-deal — that would mint ⏰ for a run begun on D+1. The gate is the fix: widen hasLiveGame's use at ContentView.swift:343-345, DailyView.swift:273-274,335-336 and index.html:1797,1804 to `hasLiveGame || graceLive`, leaving hasLiveGame itself alone so a fresh casual board keeps its one-tap controls. Note the zero-move case has nothing else to lose (0 moves, 0:00), so the dialog's 'your 0 moves and your time will be discarded' clause needs suppressing there or it undercuts the warning.
- **bug/WF-7:deal-confirm-swallowed-by-double-tap** — major, open; region `WF-7`; introduced_by_fix
  - The Deal # alert's confirmation is raised 0.1 s AFTER the alert dismisses, and its destructive 'Play that deal' button lands at (274,517) - 10 pt from the 'Play' the finger just hit at (275,527). A double-tap on Play (or any second tap in that strip within ~1 s) therefore confirms a discard the user never saw: the in-progress game, its moves and its clock are destroyed with the confirmation flashing past. Reproduced 2/2.
  - evidence: `.qa-loop/evidence/round-2/wf-7-9-11/wf7-live-play-confirm.png`, `.qa-loop/evidence/round-2/wf-7-9-11/wf7-double-tap-play-result.png`, `.qa-loop/evidence/round-2/wf-7-9-11/wf7-double-tap-repro2.png`
  - measurements: `{"confirm_button_center_pt": "274,517", "alert_play_button_center_pt": "275,527", "separation_pt": 10, "deferred_present_delay_s": 0.1, "moves_lost": 1, "repro_rate": "2/2"}`
  - note: Caused by the DispatchQueue.main.asyncAfter(0.1) hop added in 9d4a4fc (ContentView.swift, deal alert Play). The confirm is a real dialog but offers no real protection while its destructive action materialises under the finger that just tapped. Cheapest safe fixes: present the confirm on the NEXT tap-eligible runloop turn but ignore touches for a short window, or make the confirmation a sheet/dialog whose destructive button is not co-located with the alert's Play (e.g. swap Keep playing to the right), or debounce pendingReset so a tap arriving <300 ms after it is raised is discarded. Do NOT solve it by dropping the confirmation.

### minor (4)

- **bug/WF-4:win-overlay-seed-grouped** — minor, open; region `WF-4`
  - The win overlay prints the solved deal comma-grouped — 'Deal #551,879' — while its own 'Play deal #551880' button, the board pill and the Daily card all print the same class of number ungrouped; one dialog shows both formats at once, so a user cannot tell whether '#551,879' is the deal recorded as '551879' in Wins.
  - evidence: `.qa-loop/evidence/round-2/wf-1-3-5/15-win-overlay.png`
  - measurements: `{"overlay_result_line": "Deal #551,879", "overlay_button_label": "Play deal #551880", "board_pill_label": "Deal #551879", "source": "ios/Causeway/Causeway/Views/ContentView.swift:901 \u2014 Text(\"Deal #\\(game.seed) \u00b7 ...\") interpolates through LocalizedStringKey and auto-groups"}`
  - note: Same root cause and same one-line remedy as bug/WF-13:daily-card-seed-grouped (route through DealFormat.seed), on a surface that fix did not cover. Pre-existing, not caused by round 1's fixes.
- **ux/WF-3:replay-confirm-copy-mismatch** — minor, open; region `WF-3`; introduced_by_fix
  - The new reset confirmation reuses New-game wording for Replay: tapping Replay on a live casual game warns 'This game is not a challenge, so there is no way back to it', but Replay reloads the very same deal, so the deal is not lost at all — the warning overstates the cost of the one control whose whole purpose is to restart this deal.
  - evidence: `.qa-loop/evidence/round-2/wf-1-3-5/08-replay-live-confirm.png`, `.qa-loop/evidence/round-2/wf-1-3-5/09-after-replay.png`
  - measurements: `{"replay_alert_message": "Your 1 move and your time will be discarded. This game is not a challenge, so there is no way back to it.", "deal_before": 915806, "deal_after": 915806}`
  - note: Cheap fix: branch the message on the verb as well as on challengeDay, e.g. Replay -> 'Your N moves and your time will be discarded and this deal starts over.' CODE-LEVEL, NOT DEVICE-VERIFIED (out of turn budget): the title is chosen only by challengeDay (ContentView resetConfirmTitle), so Replay during a daily attempt should read 'End your daily attempt?' even though Game.restartDeal():236-239 deliberately re-binds challengeDay — i.e. the attempt is restarted, not ended. Worth one screenshot next round before acting on that half.
- **bug/DailyView:calendar-cells-have-no-identifier** — minor, open; region `WF-13`
  - Daily calendar cells cannot be addressed programmatically: calCell (Views/DailyView.swift:533-580) carries only .accessibilityLabel(dayLabel(idx)) — or "<day>, locked until that date" — applied to a ZStack that is never marked as a single accessibility element (.accessibilityElement(children: .combine)), and no .accessibilityIdentifier at all. Every other tappable surface in the app got identifiers on 5447237; the calendar grid was missed. Two round-2 regression guards (ux/WF-13:future-day-tap-no-feedback and ux/WF-13:selected-day-invisible-at-play) can only reach a cell through a label match against text that also appears in the day-card header and in the 'Unlocks <day>' placeholder, disambiguated by frame height — a brittle query for the one control whose mis-tap the second fix exists to prevent. The same gap hits VoiceOver: the label is attached to a container whose children (the date number, the 🌟/🔒/dot markers) are their own elements, so the cell may be announced as loose fragments rather than one 'Aug 3, gold' cell.
  - measurements: `{"cells_per_month": 31, "cell_hit_target_pt": "44x40", "guards_weakened": 2}`
  - note: Recommended fix: .accessibilityIdentifier("daily.cal.\(idx)") plus .accessibilityElement(children: .combine) on calCell's ZStack. That makes both round-2 calendar guards deterministic (RegressionDailyCalendarTests.swift) and gives VoiceOver one element per day. Filed by the regression-test pass, not observed as a user-visible defect this round.
- **bug/Main:scored-surfaces-addressable-only-by-copy** — minor, open; region `Main`
  - Four surfaces that regression guards must assert on have no accessibilityIdentifier, so the tests have to match visible copy — which makes a wording change look like a regression and a real regression look like a wording change. (1) The daily objectives HUD chips (Views/DailyView.swift:642-680) carry none; hud.day only renders when the challenge is NOT today, so the metric-integrity guard for ux/WF-6:demo-exit-drops-challenge-binding has to prove the HUD exists by querying the literal text 'Clear the deal'. (2) The win overlay (Views/ContentView.swift:895-905) is addressed by its 'You solved it! 🎉' title — which also blocks a guard for ux/WF-14:win-overlay-omits-the-day, whose whole content is the overlay's day prefix. (3) The Wins 'Play a deal' TextField and its Play button (Views/WinsView.swift:45-55) are reachable only by placeholder/label, though the error line beside them does have wins.dealentry.problem. (4) The BACKUP note Text (Views/DailyView.swift:383) has none, so the archived bug/WF-11:cancel-note-not-updated guard matches 'Import cancelled.' verbatim.
  - measurements: `{"surfaces_without_identifier": 4, "guards_forced_onto_copy_matching": 4}`
  - note: Recommended identifiers: hud.objectives (or hud.chip.<tier>), win.overlay + win.dailyline, wins.dealentry.field / wins.dealentry.play, daily.backupnote. Cheap, and each one converts a copy-coupled assertion in ios/Causeway/CausewayUITests/Regression*.swift into a structural one. The win-overlay case is the one that actually blocked a guard this round: ux/WF-14:win-overlay-omits-the-day needs an injected save AND a stable handle on the overlay's daily line, and has neither.

## Disputed (agree-to-disagree)

_none_

## UX proposals (human decisions — flip routing to "auto" to accept)

- **ux/WF-11:import-has-no-confirm-or-undo** — minor, open; region `WF-11`
  - Import merges the picked file into the live stores the instant it is selected — no preview of what is about to be merged, no confirmation, no undo — and since the app has no stats reset, one wrong file permanently pollutes streaks and the calendar.
  - evidence: `.qa-loop/evidence/round-1/wf-11/08-legacy-import-note.png`, `.qa-loop/evidence/round-1/wf-11/11-streaks-after-legacy.png`
  - measurements: `{"taps_from_picker_to_irreversible_merge": 1, "confirmations": 0, "undo_affordances": 0, "in_app_reset": "none (harness notes: reset requires uninstall/reinstall)"}`
  - note: Design call for the human, not a defect on its own: a 'this backup holds 10 days and 1 deal, exported 2026-07-02 — merge?' confirm step (or a one-shot 'Undo this import' on the note line) would make the destructive-by-accident case recoverable. Only worth doing if bug/WF-11:legacy-backup-defeats-daily-v3-wipe is not fully closed by stamping.
- **ux/WF-13:calendar-month-locked-no-nav** — major, open; region `WF-13`
  - The Daily month calendar renders only the CURRENT calendar month and has no prev/next control, so from 2026-09-01 every August day (dayIndex 0-30, the entire catch-up backlog) becomes impossible to select or play in-app even though dailyChallenge(idx, pool) still returns them.
  - evidence: `.qa-loop/evidence/round-1/wf-13/tc13-1-calendar-nomonthnav.png`, `.qa-loop/evidence/round-1/wf-13/tc13-3-calendar-no-inprogress-marker.png`
  - measurements: `{"months_rendered": 1, "month_nav_controls": 0, "playable_days_today": 30, "playable_days_unreachable_after_2026_09_01": 31, "code": "DailyView.swift:422-426 builds the grid from Calendar.current.dateComponents([.year,.month], from: Date()) only; calCell L462/L493 gates selection on idx <= todayIndex()"}`
  - note: SUSPECTED, not confirmed, only because the simulator clock cannot be advanced with this toolset (no simctl date subcommand; the MCP control tool has no clock action) -- the missing month navigation itself IS observed. The failure is date-triggered and lands in 2 days (2026-09-01). Structural navigation change, so proposal-routed: options are prev/next month arrows, or scoping the grid to the pool epoch range rather than the wall-clock month.
- **ux/WF-13:daily-sheet-resets-to-today-midattempt** — major, open; region `WF-13`; fix_risk `behavior-change`
  - Re-opening the Daily sheet during a live PAST-day attempt snaps it back to Today (DailyView.swift:82 `.onAppear { dayView = clampedToday }`): the card shows today's deal and objectives, the calendar marks the in-progress day in no way at all, and the one gold Play button on screen starts TODAY's deal -- the only route back to the day you are playing is to re-find it in the calendar, and Play restarts rather than resumes.
  - evidence: `.qa-loop/evidence/round-1/wf-13/tc13-3-aug4-board-hud.png`, `.qa-loop/evidence/round-1/wf-13/tc13-3-daily-resets-to-today-midattempt.png`, `.qa-loop/evidence/round-1/wf-13/tc13-3-calendar-no-inprogress-marker.png`, `.qa-loop/evidence/round-1/wf-13/tc13-3-play-today-confirm-alert.png`
  - measurements: `{"in_progress_markers_on_sheet": 0, "taps_to_return_from_sheet_to_the_live_day": "swipe + tap day + tap Play, and Play restarts the attempt (no resume affordance exists)"}`
  - note: TRAP: any 'remember the last viewed day' fix must not let the sheet open on a stale day after midnight -- WF-14's four clock-line branches are all date-driven off dayView vs todayIndex(). Marking the live day (a badge on the cell / 'Attempt in progress' on the card) is the lower-risk half. CAVEAT on the last repro step: my Aug 4 attempt had 0 NET moves at that point (one move + Undo), so I cannot claim the discard-confirmation alert is suppressed at real progress -- the finding is the missing day identity, not the missing confirm (ux/WF-7:deal-play-discards-live-game-no-confirm covers that ground). Reproduces CC-13-D.
- **ux/WF-13:par-never-surfaced** — minor, open; region `WF-13`
  - Every pool day carries a certified `par` move count (Aug 3 = 86, today = 84) that is decoded into PoolDay.par / Challenge.par but rendered nowhere in the app -- no view file references it -- while WF-13's expectation states a selected past day shows its own objectives AND par.
  - evidence: `.qa-loop/evidence/round-1/wf-13/tc13-1-aug3-card.png`, `.qa-loop/evidence/round-1/wf-13/tc13-5-aug6-board-fresh.png`
  - measurements: `{"par_render_sites_in_views": 0, "par_aug3": 86, "par_today_dayindex29": 84}`
  - note: Reproduces CC-13-E as a doc-vs-app gap, NOT a defect: par is a pool-generation/certification field and the app has simply never shown it. Human decision either way -- surface it on the day card ('Target: 86 moves', genuinely useful next to the moves-family Silver objectives) or strike 'and par' from WF-13's expectation sentence in WORKFLOWS.md. Do not auto-fix.
- **ux/WF-14:grace-invisible-from-daily-sheet** — major, open; region `WF-14`
  - A live ⏰ grace is not surfaced anywhere a player would look: the Daily sheet always opens on Today, the calendar puts no in-progress mark on the graced day, and the only place the promise exists is that day's card, two gestures away (swipe to calendar + tap the right cell). The one screen the player does see instead offers Today's `Play`, whose confirm destroys the grace — so the feature's headline case ('you can still save yesterday') is reachable mostly by accident.
  - evidence: `.qa-loop/evidence/round-1/wf-14/tc145-sheet-first-screen-grace-live.png`, `.qa-loop/evidence/round-1/wf-14/tc145-calendar-no-inprogress-mark.png`, `.qa-loop/evidence/round-1/wf-14/tc145-aug29-grace-line.png`
  - measurements: `{"gestures_from_sheet_open_to_the_grace_promise": 3, "hints_on_the_first_screen": 0}`
  - note: Structural (where the state is surfaced) so routed proposal; related to the DailyView onAppear snap-to-today behaviour also flagged in WF-13, but the cost here is a lost streak rather than lost context. Cheapest candidate fixes for the human to weigh: an in-progress dot on the graced calendar cell, or a one-line banner above the Today card while graceLive.
- **ux/Main:clock-runs-during-modal-sheets** — minor, open; region `WF-4`; fix_risk `metric-integrity`
  - The solve clock keeps ticking while the app's OWN auto-raised 'Ready to finish' modal blocks play, so a recorded best time silently absorbs however long the user takes to answer a prompt they never asked for (measured: Time advanced 1:35 -> 1:39 across 3.5 s in which the counter was the only pixel on screen that changed). Previously filed against user-opened sheets (Daily/Wins/How to play) in the 342e3c0 loop and never resolved; this is the sharper, app-initiated instance.
  - evidence: `.qa-loop/evidence/round-1/perf/r1-clock-prompt-t0.png`, `.qa-loop/evidence/round-1/perf/r1-clock-prompt-t+3.5s.png`, `.qa-loop/evidence/round-1/perf/r1-finishprompt-full-t0.png`, `.qa-loop/evidence/round-1/perf/r1-perf-measurements.txt`
  - measurements: `{"counter_region_raw_px": "820,250 - 980,350", "counter_region_MAD_over_3.5s": [10.131, 7.656, 7.656], "counter_region_pct_pixels_changed": [8.1, 6.6, 6.6], "rest_of_screen_region_raw_px": "0,800 - 1206,1800", "rest_of_screen_MAD_same_frames": [0.0, 0.0, 0.0], "clock_reading_t0": "1:35", "clock_reading_t_plus_3.5s": "1:39", "modal_up_before_answer_seconds_observed": [6.7, 4.4], "film_sampling_interval_ms": 230}`
  - note: TRAP: the obvious fix (pause GameClock while any sheet/alert is presented) turns every sheet into a free pause button and corrupts recorded best times in the other direction - a player could stop the clock indefinitely by opening How to play. Any fix must distinguish app-initiated modality (this prompt) from user-initiated sheets, or leave the clock alone and instead not raise the prompt unbidden. Reuses the id filed in the 342e3c0 archive loop (routing proposal, still open there); no re-decision by a human has happened since.

## Fix review rejections

_none_

## Severity changes

_none_

## Persona matrix (round 2)

| Workflow | novice | power |
|---|---|---|
| WF-1 | 1✓ | — |
| WF-2 | 1✓ | — |
| WF-3 | — | 1✓ |
| WF-4 | — | 1✓ |
| WF-5 | 1✓ | — |
| WF-6 | 1✓ | — |
| WF-7 | — | 2✓ |
| WF-8 | — | 1✓ |
| WF-9 | — | 1✓ |
| WF-10 | 1✓ | — |
| WF-11 | — | 1✓ |
| WF-13 | 2✓ | 2✓ 1… |
| WF-14 | 2✓ | 2✓ 1… |
| WF-15 | 1✓ | 3✓ |

## Coverage gaps

- TC-13.7 (power): skipped — turn budget — 5 of 7 days verified string-exact against derive_daily.py (Aug 1 rank-rush/split-at, Aug 2 end-bias/big-move, Aug 3 max-run/suit-sprint, Aug 4 suit-balance/cells-le, plus Aug 7 cells-le/suit-top-first = 5 days). No truncation, no stale labels across selections, ⏰ line right on all. Aug 5 (moves/ends-first) and Aug 6 (no-undo/before-ace) not read; deal numbers were legible only for Aug 3/Aug 4 at the scroll position used.
- TC-14.3 (power): skipped — turn budget

## Closeout

_no closeout cycle ran_

## Wontfix / resolved

_none_

## WATCH LIST

_The part a human should actually read. The fix-reviewer decorrelates the loop's blind spots but cannot eliminate them, and this round proved it: a fix it explicitly cleared was later broken open by a tester on the device._

### Read these two first — both still open, both can lose a player's work

- **`bug/WF-7:deal-confirm-swallowed-by-double-tap`** (major, **introduced by a fix**, commit `9d4a4fc`) — look here because **this is the loop's own regression, and the fix reviewer waved it through.** Round 1 filed "Deal # Play silently discards a live game". The implementer added a confirm raised `0.1 s` later via `asyncAfter` so the dismissing alert would not swallow it. The code reviewer called that runloop hop "a minor pattern smell but functions correctly." It does not: the hop lands the destructive **"Play that deal"** button at (274,517), **10 pt** from the alert's own **"Play"** at (275,527), so an ordinary double-tap confirms a discard the player never reads — live game and clock gone, Moves 1 → 0, Undo greyed. Reproduced 2/2. Do not fix by removing the confirm; fix the geometry or the timing.

- **`ux/WF-14:replay-forfeits-grace-silently`** (major, `fix_risk: metric-integrity`, commit `c74fa96`) — look here because it is **the one fix the reviewer rejected, and a tester then proved the hole is total.** The grace-aware copy is right wherever it shows; *showing* it is gated on the pre-existing `hasLiveGame` (`moveCount > 0`), which was never widened. With a zero-move grace attempt (tapped Play yesterday, made no moves, returned today) **all four controls destroy it with no dialog at all** — Daily-sheet Play, Replay, New game, and a how-to-win demo pill, 4/4 silent. The fix is the gate, not the copy: `hasLiveGame || graceLive` at the four call sites (`Game.swift:432`, `ContentView.swift:343-345`, `DailyView.swift:273-274,335-336`, `index.html:1797,1804`). One trap the tester flagged: the zero-move dialog would otherwise read "your 0 moves and your time will be discarded" — suppress that clause.

### The four metric-integrity fixes — verified, but this is where a silent regression would hide

All four shared one root cause: **the app changed a scored outcome with no player input.** The implementer's principle — *"the app may withhold an automatic action, but it may never re-choose one"* — is sound and was upheld on the device. They are here because the failure mode is invisible: a player only finds out when a medal is missing.

- **`bug/WF-4:autoplay-denies-daily-gold`** (`f7c4788`) — Auto-play is **On by default**; its greedy send put 8♠ on the *down* foundation at day 29's certified-flawless position and killed 🥇 and 🌟 outright. Now `autoSendWouldBreakTier` declines such a send. Verified: auto-play left the 8♠ alone and the deal finished 🌟 Flawless; manual play stays ungated, so the player can still make the tier-breaking move deliberately.
- **`bug/WF-4:autofinish-cascade-can-deny-gold`** (`f7c4788`) — the "Ready to finish" prompt fired at move 64 of day 21's 87-move flawless line and Finish then paid out 🥉🥈 only. Measured to cost a medal on **19 of 30 reachable days, today included.** **The riskiest change in the whole loop rides along with it:** the win-detection predicate was rewritten (`autoFinishWouldWin` → `simulateAutoFinish().won`), and a false negative there would silently strip the Finish affordance from winnable boards. A tester differentially compared old and new across **21,956 prefix positions with zero disagreements**, and `tests/autofinish-tiers.test.mjs` now guards that property permanently (observed failing when the predicate is mutated). That is as verified as this loop can make it — but it is still a rewritten win predicate.
- **`ux/WF-6:demo-exit-drops-challenge-binding`** (`e70b251`) — the novice path banked nothing: after the demo said "tap Done to try it yourself", Done landed on a HUD-less casual deal. Now re-binds through `playChallenge` → `deal()` with Moves 0 / 0:00 / empty telemetry, surviving a hard kill.
- **`ux/WF-8:autoplay-toggle-mutates-scored-game`** (`b7edbde`) — one tap on a *setting* played two cards and flipped 🥇 to ✗. Now arms on the next move instead. **Note the regression writer deliberately wrote no UI guard here**: on a fresh deal almost nothing is safe under `isSafeAutoplay`, so "Moves unchanged after toggling" passes with the fix reverted. A non-discriminating test is worse than none — this one rests on the parity pin alone.

### State migration — the fix that can destroy real data

- **`bug/WF-11:legacy-backup-defeats-daily-v3-wipe`** (`be67947`, `fix_risk: state-migration`) — a pre-recut backup imported with **0 entries skipped** and fabricated medals (Gold 1 → 11 total, Aug 11-20 all lit), defeating exactly what the v2→v3 wipe exists to prevent. The importer now drops a daily map it cannot prove came from this calendar, **treating a missing stamp as NO**. Verified on all four legs, including that `wins` still imports and the user is told why. Watch it because the safe direction here is also the destructive one: any legitimate pre-stamp backup loses its daily history by design.

### Decisions that are yours, not the loop's

Six proposals are awaiting you and are excluded from convergence by design. The two with teeth: **`ux/WF-13:daily-sheet-resets-to-today-midattempt`** (`behavior-change` — the sheet opens on Today with no sign of a live attempt on another day, and the visible Play swaps the board) and **`ux/Main:clock-runs-during-modal-sheets`** (`metric-integrity` — the solve clock ticks under the app's *own* auto-raised "Ready to finish" modal; measured at 1 Hz with the rest of the screen static). Also open: `ux/WF-13:calendar-month-locked-no-nav`, `ux/WF-13:par-never-surfaced`, `ux/WF-14:grace-invisible-from-daily-sheet`, `ux/WF-11:import-has-no-confirm-or-undo`.

### Most invasive diffs

- **`b2ce1a4..4f02d1d`** (round 1 fixes, eleven commits) — `index.html` +231/-67, `ios/Causeway/Causeway/Model/Game.swift`, `Views/ContentView.swift`, `Views/DailyView.swift`, `Model/StatsBackup.swift`. This is where all fourteen fixes live, and where the two regressions above were born.
- **`4f02d1d..HEAD`** (regression tests, `1241c08`) — eight new XCUITest files, +794 lines. **They are all `XCTSkipIf(true)`-guarded and have never run on a device**; they are tripwires you must arm (see Closeout).
- **A latent web bug was found inside the blast radius, not by a test:** `index.html`'s `objViolated`/`objSecured` were still switching on **pre-parameterised objective ids** (`'aces-first'`, `'split-even'`, `'cells-le-1'`), so every current objective fell through to `default: false` — the web HUD never showed a ✗, and the new WF-4 guards would have been inert there. Now ported from the canonical Swift. Nothing in the loop was looking for this; the implementer volunteered it.

### Environment gaps you should know about

- **WF-12 (landscape) is entirely unverified.** Rotation is unreachable from this toolset — four routes were exhausted (no MCP orientation action; no `simctl` rotate; Simulator's Device ▸ Rotate needs assistive access, `osascript` returns -1728; the `com.apple.iphonesimulator` orientation defaults are silently reverted on window open). All three WF-12 cases are `blocked`, and the landscape rail call sites of the new WF-3/WF-7 confirms were never exercised.
- **The ⏰ grace needs a two-day sequence and there is no date override**, so parts of WF-14 are only reachable by injecting saves. A debug date override remains the highest-value testability change available.
