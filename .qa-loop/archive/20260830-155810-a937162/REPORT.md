# Loop report — .qa-loop

> **STOPPED EARLY — NOT A CONVERGED RUN.** The operator halted the loop after 2 of round 2's 15
> chunks to take on other work. Round 1's 29 findings are merged, 17 of 18 auto-routed ones were
> fixed and the fixes were reviewed as sound — but only the two chunks round 2 completed
> (`wf-1-1`, `wf-2-1`) actually VERIFIED a fix against the running app. Every other "fixed" claim
> below is the implementer's, not the loop's. Cost analysis and process feedback for this run:
> `docs/qa-loop-feedback.md`.


**Stop condition:** `continue` after round 1 — progress continuing

**Subagent tokens:** 1,929,240 across 1 round(s)

**Findings by status:** open 27, fixed 2, partial 1

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|----------|-----|--------|----------|
| 1 | full | 1 | 6 | 11 | 11 | 0 | 18 | 0 | 0 | -18 | 222590 | continue |

## Open findings by severity

### blocker (1)

- **bug/WF-11:import-drops-out-of-range-stats** — blocker, open; region `WF-11`
  - Import permanently drops stats that Export itself wrote: DailyView.importStats keeps only wins whose seed is in 1...Game.maxSeed (1,000,000) and only daily records whose dayIndex is in 0...todayIndex()+2, while StatsBackup.make exports every entry. Restoring the app's own untouched backup onto a fresh install silently lost a real win on deal #872,465,152 and the whole Bronze+Silver+Gold+Flawless record for the Aug 11 sandbox day (dayIndex -1) - both of them earned through normal play of the shipped pre-epoch sandbox days - and reported them as 'Skipped 2 invalid entries', directly contradicting the section's own promise 'Importing merges - it never erases progress.'
  - evidence: `.qa-loop/evidence/round-1/wf-11-1/tc11-2-import-own-export-skipped2.png`, `.qa-loop/evidence/round-1/wf-11-1/restore-before-fresh-install.png`, `.qa-loop/evidence/round-1/wf-11-1/restore-after-import-losses.png`, `.qa-loop/evidence/round-1/wf-11-1/exported-backup.json`
  - measurements: `{"exported_daily_keys": [-1, 10], "exported_win_seeds": [777, 10011, 872465152], "restored_daily_keys": [10], "restored_win_seeds": [777, 10011], "entries_lost": 2, "wins_filter": "1...1000000", "daily_filter": "0...todayIndex()+2"}`
  - note: TRAP: those two range checks are the sanitizer that makes TC-11.4 pass (a hand-edited backup with seeds 0/1000001, day -3/9999 and zero moves/secs was correctly skipped, and no best score was poisoned). Do not simply delete them - widen them to what the app can legitimately produce (sandbox dayIndex >= -preSeeds.count, and win seeds up to the sandbox seed range / any seed the Deal # alert accepts) while keeping the moves>0 / secs>0 checks. Secondary, same fix site: the note calls the user's own untouched export 'invalid entries' and never says which entries were dropped.

### major (6)

- **ux/WF-12:rail-hides-howtoplay** — major, open; region `WF-12`
  - In landscape, whenever the 50pt daily-HUD chip bar or the demo bar is on screen the left rail's ScrollView shrinks to 248pt while its pill stack is 285pt tall, so the last pill ('How to play') is rendered 100% below the viewport with no partial pill, no fade and no resting scroll indicator — the rail's visible bottom edge lands exactly on a pill boundary after 'Wins', so a novice playing the daily in landscape sees no evidence the rules are still reachable.
  - evidence: `.qa-loop/evidence/round-1/wf-12-1/tc122-dailyhud-rail-howtoplay-absent.png`, `.qa-loop/evidence/round-1/wf-12-1/tc122-rail-zoom-ends-at-wins.png`, `.qa-loop/evidence/round-1/wf-12-1/tc122-rail-after-scroll-howtoplay-visible.png`, `.qa-loop/evidence/round-1/wf-12-1/tc122-demobar-rail-howtoplay-absent.png`, `.qa-loop/evidence/round-1/wf-12-1/measure-hierarchy-dailyhud.txt`
  - measurements: `{"rail_scrollview_frame_with_hud": "{68,97,118x248}", "rail_content_height": 285, "howtoplay_pill_frame": "{68,355.7,118x26.3}", "howtoplay_visible_fraction": 0.0, "wins_pill_clipped_pt": 4.6, "rail_scrollview_frame_no_hud": "{68,57.7,118x310}", "a11y_scrollbar_label_with_hud": "Vertical scroll bar, 2 pages", "same_state_in_portrait": "all 9 pills visible in a 3-row toolbar, nothing clipped"}`
  - note: Arithmetic (not observed live): with the HUD AND a 'Finish' pill the stack is 317.3pt in the same 248pt viewport, so 'Wins' would join 'How to play' below the fold. Cheap fixes that stay inside the current design: keep the rail's content inset so the next pill always half-peeks, or add a persistent bottom fade/chevron. Do not fix by shrinking pills below the 26.3pt hit target.
- **bug/WF-13:one-big-move-check-lost-on-undo** — major, partial; region `WF-13`; fix_risk `metric-integrity`
  - On the Aug 8 sandbox day (deal #186,441,603, gold = one-big-move) the Gold HUD chip flips to a green check the instant a 6-card run is relocated, but a single tap of Undo un-earns it: the chip drops back to '·'. Game.swift's undo() restores telem.maxRunMoved from the move snapshot, so the objective WORKFLOWS.md WF-13 and Daily.swift:426 both call 'positive + irreversible: locked in the moment it happens' is in fact reversible, while telem.undos (the negative no-undo objective) is deliberately never rolled back — an inconsistency that can silently cost a player the Gold medal.
  - evidence: `.qa-loop/evidence/round-1/wf-13-1/tc13.4-before-bigrun-moves19.png`, `.qa-loop/evidence/round-1/wf-13-1/tc13.4-after-bigrun-gold-check.png`, `.qa-loop/evidence/round-1/wf-13-1/tc13.4-after-undo-gold-check-lost.png`
  - measurements: `{"run_length_moved": 6, "moves_at_secure": 20, "moves_after_undo": 19, "gold_chip_before_undo": "green check", "gold_chip_after_undo": "dot (unearned)"}`
  - note: WONTFIX ARGUMENT HOLDS ON THE CODE, BUT THE DISPOSITION IS INCOMPLETE (round 1). Verified: telem.maxRunMoved is genuinely read by two opposite-polarity objectives (Daily.swift:150/149, index.html:1179-1180); making it a one-way ratchet to satisfy one-big-move would itself be a NEW metric-integrity exploit -- a player could do one 5+ card supermove, immediately Undo it, and keep Gold credit forever even though the actual winning line never contained that move, i.e. exactly the 'peek and score' trap the finding's own note warned against. The HUD chip and the win-time checker (oneBigMove) read the identical field, so the live preview never lies about the eventual grade, and every other objSecured case (jacks-down-first, down-openers-20, suit-sprint, etc.) already un-secures on undo the same way, since they read up/down arrays that undo genuinely rewinds. index.html carries the identical rollback and comment fix, keeping web/iOS parity (verified via `npm test`, 71/71, including the ios-parity suite). So the decline itself is the right call, not a rubber stamp.  HOWEVER: .qa-loop/TESTCASES.md TC-13.4 (lines 696-711) was NOT updated and still asserts the opposite as the canonical, testable expectation: 'After Undo (step 3), the chip **stays green** (maxRunMoved is telemetry that is never rolled back -- the objective is "positive and irreversible" per WORKFLOWS.md WF-13)' with an explicit Fail condition '...reverts to ·/✗ after Undo ... is a HUD/telemetry bug.' That is the precise, literal behavior the implementer just re-confirmed is CORRECT and by design. The implementer rewrote TC-7.3/TC-7.4/TC-11.4 to match its other fixes in this same commit but left this one contradicting test case stale, so the next round's tester, following TC-13.4 to the letter, will re-observe the chip reverting on Undo, invoke the test's own 'Fail condition', and refile this exact finding -- an avoidable repeat loop. Action needed before this can close: rewrite TC-13.4's Expected/Fail-condition (and its WORKFLOWS.md WF-13 citation) to state that the chip correctly reverts on Undo and that this is intended, matching the corrected comments in Daily.swift/index.html.
- **ux/WF-13:daily-play-discards-live-attempt-silently** — major, open; region `WF-13`; fix_risk `behavior-change`
  - Tapping the Daily card's gold `Play` while a daily attempt is already in progress re-deals the board and throws the attempt away with no confirmation and no hint on the card that one is live — even when it is the SAME day you are playing. The identical loss via a 'Show me how to win' pill IS gated by an 'End your daily attempt?' alert, so the app protects the rarer path and not the common one.
  - evidence: `.qa-loop/evidence/round-1/wf-13-1/tc13.5-daily-card-play-during-live-attempt.png`, `.qa-loop/evidence/round-1/wf-13-1/tc13.5-aug7-both-violations-marked.png`
  - measurements: `{"moves_lost": 3, "elapsed_lost_sec": 104, "confirm_dialogs_shown": 0, "confirm_dialogs_on_equivalent_demo_path": 1}`
  - note: Also seen across days: an Aug 8 attempt at Moves 19 / 7:51 was discarded the same way by picking Aug 7 -> Play. Minimal fix is to reuse the existing 'End your daily attempt?' alert (challengeDay != nil && moveCount > 0) on the day-card Play path; the alternative ('Play' resumes the live attempt, or the card shows 'Resume') is a design call for the human. TRAP: whichever is chosen must not create a way to restart a daily for a better time while keeping the earlier attempt's banked telemetry.
- **ux/WF-6:demo-pill-discards-casual-game** — major, open; region `WF-6`; fix_risk `behavior-change`
  - With a free-play game in progress, tapping a "Show me how to win" pill instantly replaces the board with the demo (on a different deal) and destroys that game with no confirmation and no recovery - Undo is disabled afterwards and the Deal # has changed - even though the app deliberately puts an "End your daily attempt?" confirm in front of exactly the same loss when the in-progress game is a daily attempt.
  - evidence: `.qa-loop/evidence/round-1/wf-6-2/tc67-casual-in-progress.png`, `.qa-loop/evidence/round-1/wf-6-2/tc67-casual-destroyed-no-warning.png`
  - measurements: `{"moves_lost": 3, "elapsed_lost_s": 22, "deal_before": 784301, "deal_after": 10011, "confirm_shown": false, "confirm_shown_for_daily_attempt": true}`
  - note: TRAP: the existing alert copy is daily-specific ('your current attempt ... you can replay the challenge afterwards') and must not be reused verbatim for a casual game; and the guard must stay off when moveCount == 0, or the normal 'open a demo from a fresh board' path (TC-6.1) grows a pointless prompt.
- **ux/WF-5:daily-play-restarts-attempt-without-warning** — major, open; region `WF-5`; fix_risk `behavior-change`
  - On the Daily sheet the primary Play button silently RESTARTS a daily challenge that is already in progress - Moves 1 -> 0, Time 0:00, board re-dealt, Undo disabled - with no confirmation and no way back, while the demo pills one row below it confirm that exact same loss. Found while validating the TC-6.7 confirm gate: the gate is the only guarded path into the loss it guards.
  - evidence: `.qa-loop/evidence/round-1/wf-6-2/wf5-play-before-moves1.png`, `.qa-loop/evidence/round-1/wf-6-2/wf5-play-after-restart.png`
  - measurements: `{"moves_before": 1, "moves_after": 0, "elapsed_before_s": 9, "elapsed_after_s": 0, "confirm_shown": false}`
  - note: Cheapest consistent fix is to route this button through the same confirm the demo pills use (and/or label it 'Resume' when a live attempt exists on that day). TRAP: 'Play' MUST still restart when the user confirms - the alert's own promise 'you can replay the challenge afterwards' depends on it - so do not turn it into a pure resume.
- **bug/WinsView:row-text-contrast** — major, open; region `WF-9`
  - In the Wins range detail list every row is a Button, so SwiftUI tints the whole label with the gold accent: the per-deal stats ("122 moves · 4:14 · Aug 22"), coded as .foregroundStyle(.secondary), render as RGB(236,214,170) on white = 1.42:1 contrast (deal title 2.09:1), i.e. the only content the screen exists to show is effectively unreadable.
  - evidence: `.qa-loop/evidence/round-1/wf-9-1/tc92-range-drilldown.png`, `.qa-loop/evidence/round-1/wf-9-1/tc92-row-contrast-closeup.png`
  - measurements: `{"meta_text_rgb": "236,214,170", "meta_contrast_vs_white": 1.42, "deal_title_rgb": "217,173,85", "deal_title_contrast_vs_white": 2.09, "wcag_aa_min": 4.5}`
  - note: WinsView.rangeDetail wraps the HStack in a Button inside a List; the accent tint overrides .secondary. Likely one-line fix (.buttonStyle(.plain) or explicit foregroundStyle). Colours sampled from the native 1206x2622 PNG; ratios are WCAG relative luminance.

### minor (10)

- **ux/WF-10:automation-undocumented** — minor, open; region `WF-10`
  - The board ships two automation pills that are active by default — 'Auto-play: On' and 'Auto-finish: Ask' — but the app's only help surface, 'How to play', never mentions either (0 occurrences of 'auto' in RulesView; the sheet fits on one screen, so nothing is hidden below the fold). A novice cannot learn what the app will do on its own, nor what toggling those two pills changes; Auto-finish: Ask will later raise a mid-game prompt the player was never told about.
  - evidence: `.qa-loop/evidence/round-1/wf-10-1/tc10-1-00-board-toolbar.png`, `.qa-loop/evidence/round-1/wf-10-1/tc10-1-01-rules-full.png`
  - measurements: `{"rules_sections": 5, "mentions_of_auto_play": 0, "mentions_of_auto_finish": 0, "scroll_needed_to_see_all_rules": false}`
  - note: Text-only fix on an existing screen. The core novice content (both-ended foundations, tap-vs-drag, free cells) IS present and correct, which is why this is minor and not major. The Daily screen self-documents its objectives in plain English, so the gap is specific to the two automation pills.
- **ux/WF-13:demo-headline-emdash-collides-with-label** — minor, open; region `WF-13`
  - The demo bar builds its headline as "<label> — <progress>" (ContentView.swift:665), but three objective labels already contain an em dash of their own. On Aug 5 the Gold demo bar reads "🥇 Gold: Split every suit exactly down the middle — A-7 up, 8-K down — 0 / 106", so the move counter is punctuated exactly like the second half of the objective and reads as more objective text rather than as progress.
  - evidence: `.qa-loop/evidence/round-1/wf-13-2/tc136-demo-headline-emdash.png`
  - measurements: `{"labels_containing_em_dash": 3, "labels_total": 18, "affected_ids": ["split-even", "no-supermoves", "no-up-foundation"], "headline_lines_wrapped": 3}`
  - note: Cheap fix: use a different separator (· or a bullet) or render the progress as its own Text/pill. Only affects the three labels that embed an em dash, all of them on the new sandbox-day objective families.
- **bug/WF-4:autofinish-defer-not-persisted** — minor, open; region `WF-4`; fix_risk `state-migration`
  - 'Not yet' stops the auto-finish prompt only for the life of the process: the app re-offers 'Ready to finish' the moment the very same game is restored after an app kill/cold relaunch (same deal, same move count, same clock), so the promise that it will not nag again this game is broken by any process restart.
  - evidence: `.qa-loop/evidence/round-1/wf-4-1/tc42-deferred-before-relaunch.png`, `.qa-loop/evidence/round-1/wf-4-1/tc42-prompt-returns-after-relaunch.png`
  - measurements: `{"moves_before_kill": 70, "moves_after_relaunch": 70, "prompt_reappeared": true}`
  - note: autoFinishDeferred is not part of Game.SavedGame and restore() resets it to false before calling maybeAutoFinish(). Fix is an optional field on the persisted save — decode defensively so old saves still load (fix_risk: state-migration).
- **ux/WF-5:streak-card-headline-unlabelled** — minor, open; region `WF-5`
  - Each of the four streak cards shows THREE numbers but labels only two of them: the large serif headline number (the current streak) has no label at all, and the word "streak" appears nowhere on the Daily sheet. A novice reading "🔥 1 / Play / 1 total / best 1" cannot tell which number is the current streak, which is the lifetime total, and which is the record.
  - evidence: `.qa-loop/evidence/round-1/wf-5-1/tc51-streak-cards-fresh.png`, `.qa-loop/evidence/round-1/wf-5-1/tc53-daily-after-bronze.png`
  - measurements: `{"numbers_per_card": 3, "labelled_numbers_per_card": 2, "occurrences_of_the_word_streak_in_the_sheet": 1, "note_on_that_one_occurrence": "only in the BACKUP footnote 'Save your streaks & solved deals to a file', far below the cards"}`
  - note: WF-5's stated bar is 'streak vs total vs best is not confusing'. Cheapest correct fix: label the headline (e.g. a 'streak' caption under it, or an accessibility/visible label), and define 'Flawless' somewhere. The card title doubles as the streak's name ('Play'), which also collides with the gold Play button below it.
- **ux/WF-5:unattempted-objective-shows-red** — minor, open; region `WF-5`
  - On a never-played day every objective row shows a RED empty circle (Theme.red), identical to the marker shown for an objective that was attempted and missed. On a fresh install the Daily card therefore reads as 'you already failed all three of today's objectives' before the user has made a single move.
  - evidence: `.qa-loop/evidence/round-1/wf-5-1/tc51-objective-circles-fresh.png`, `.qa-loop/evidence/round-1/wf-5-1/tc51-objective-circles-after-attempt.png`
  - measurements: `{"unattempted_marker": "circle, Theme.red", "attempted_and_missed_marker": "circle, Theme.red (identical)", "earned_marker": "checkmark.circle.fill, green"}`
  - note: DailyView.tierRow: `let color: Color = done ? .green : (future ? .secondary : Theme.red)`. A future day already gets neutral .secondary; a never-attempted past/today row should too (red only when a recorded attempt exists and missed the tier).
- **ux/WF-5:board-hud-omits-challenge-day** — minor, open; region `WF-5`
  - When a catch-up day is played from the calendar, nothing on the board says WHICH day is in progress, and re-opening Daily resets the card to Today. Playing Aug 12 (deal #10,001) and then tapping Daily shows the Today card for deal #10,011 with its Bronze/Silver green checks, so the user is looking at the earned state of a different challenge than the one on their board.
  - evidence: `.qa-loop/evidence/round-1/wf-5-1/hud-no-day-board-aug12.png`, `.qa-loop/evidence/round-1/wf-5-1/hud-no-day-sheet-shows-today.png`
  - measurements: `{"day_identifiers_on_board": 0, "sheet_day_on_reopen": "Today (todayIndex), not the in-progress challengeDay"}`
  - note: Smallest correct fix is a day label on the DailyHUD (e.g. a leading 'Aug 12' when challengeDay != todayIndex). Making the sheet's `dayView` default to the in-progress challengeDay is a behaviour change - if the implementer prefers that route it should be proposal-routed, not done unattended.
- **bug/WF-7:deal-entry-range-not-enforced** — minor, open; region `WF-7`; fix_risk `behavior-change`
  - The Deal # alert's field advertises the range "1–1,000,000" but does not enforce it: typing 9999999 plays and displays Deal #9999999 (a real deal outside the advertised range), and typing 5000000000 silently loads Deal #4294967295 — a different deal from the one typed, with no message. Only the lower bound is enforced (0 correctly becomes 1).
  - evidence: `.qa-loop/evidence/round-1/wf-7-1/tc74-typed-9999999.png`, `.qa-loop/evidence/round-1/wf-7-1/tc74-loaded-deal-9999999.png`, `.qa-loop/evidence/round-1/wf-7-1/tc74-typed-5000000000.png`, `.qa-loop/evidence/round-1/wf-7-1/tc74-clamped-to-4294967295.png`, `.qa-loop/evidence/round-1/wf-7-1/tc74-zero-clamps-to-1.png`
  - measurements: `{"advertised_range": "1-1,000,000", "typed_9999999_loaded": 9999999, "typed_5000000000_loaded": 4294967295, "typed_0_loaded": 1, "testcase_expected_9999999_loaded": 1000000}`
  - note: TRAP: do NOT fix this by restoring a clamp inside Game.deal(seed:). Game.swift:47-51 deliberately widened that clamp to maxValidSeed = 4,294,967,295 because the daily/sandbox challenge pools use seeds > 10,000,000, and clamping there would deal boards that differ from the web build. The guard belongs in ContentView.swift:241 (the alert's Play action, currently a bare `if let n = Int(dealText) { game.deal(seed: n) }`) and in WinsView.playEntered, whose own comment 'Game.deal clamps to 1...maxSeed' is now false. SECOND-ORDER (inferred from source, not reproduced live): StatsBackup import filters wins with `(1...Game.maxSeed).contains($0.key)` (DailyView.swift:282) while export writes every win unfiltered, so a win banked on a deal > 1,000,000 — which this alert lets you play — is silently discarded on restore and counted only in the 'Skipped N invalid entries' line. Whichever bound is chosen, decide what happens to already-persisted wins above it. TESTCASES.md TC-7.4 records the OLD behaviour ('9999999 -> Deal #1000000, verified on build 5447237'); that expectation is stale on f949d82 and should be rewritten with the fix.
- **bug/WinsView:deal-entry-range-not-enforced** — minor, open; region `WF-9`; fix_risk `behavior-change`
  - The Wins "Play a deal" field advertises "Number 1–1,000,000" (and WinsView's own comment claims Game.deal clamps to maxSeed) but typing 2000000 and tapping Play loads Deal #2000000 — Game.deal clamps to maxValidSeed 4,294,967,295, so the promised range is not enforced anywhere.
  - evidence: `.qa-loop/evidence/round-1/wf-9-1/tc93-deal-2000000-not-clamped.png`
  - measurements: `{"typed": 2000000, "advertised_max": 1000000, "loaded_deal": 2000000, "actual_clamp": 4294967295}`
  - note: TRAP: do NOT fix by clamping to 1,000,000. Daily/sandbox seeds legitimately exceed it (verified: a win on seed 561325499 appears in this very list and its row loads fine), so clamping would make won daily deals unreplayable. Reword the placeholder / stale comment instead.
- **ux/WinsView:seed-format-inconsistent** — minor, open; region `WF-9`
  - The same deal number is formatted two ways on one screen: the range chip and navigation title render "561325499" (String interpolation) while the row underneath renders "Deal #561,325,499" (LocalizedStringKey grouping), which reads as two different deals.
  - evidence: `.qa-loop/evidence/round-1/wf-9-1/tc92-seed-format-inconsistent.png`
  - measurements: `{"title": "561325499", "row": "Deal #561,325,499"}`
  - note: DealFormat.rangeLabel vs Text("Deal #\(seed)"). The board pill is ungrouped too, so grouping in the row is the odd one out.
- **ux/WF-2:no-drop-target-highlight** — minor, open; region `WF-2`
  - Nothing on the board indicates where a dragged card will land: no column, free cell or foundation is highlighted at any point during a drag, and a refused release is silently identical to a release over dead space (card returns to origin, Moves unchanged). Now that the round-1 gutter fix resolves a gutter release to the nearer column centre, an invisible 1 pt boundary decides the outcome - releasing J♦ at x=53 snaps back (resolved to col0, illegal) while x=54 lands on col1 - and a novice has no way to see which column is armed.
  - evidence: `.qa-loop/evidence/round-2/wf-2-1/wf2-middrag-no-target-highlight.png`, `.qa-loop/evidence/round-2/wf-2-1/wf2-gutter-x53-jd-refused-snapback.png`, `.qa-loop/evidence/round-2/wf-2-1/wf2-gutter-x54-lands-col1.png`
  - measurements: `{"held_drag_duration_s": 4, "frames_filmed_during_hold": 28, "frames_showing_a_target_highlight": 0, "resolution_boundary_pt": "between x=53 and x=54", "boundary_width_pt": 1}`
  - note: Not introduced by the gutter fix - the highlight was already absent in round 1 - but the fix makes it matter more, because which of two neighbouring columns receives a gutter release is now decided by an invisible midpoint. The app already invests in touch feedback elsewhere (the 0.3 s wiggle for an unliftable card, ux/WF-2:unmovable-card-no-feedback), so a silent snap-back is inconsistent with its own feedback vocabulary. Cheap fix: tint/outline the zone that dropTarget(at:) currently resolves to while the drag is live.

## Disputed (agree-to-disagree)

_none_

## UX proposals (human decisions — flip routing to "auto" to accept)

- **ux/WF-4:clock-pauses-in-background** — minor, open; region `WF-4`; fix_risk `metric-integrity`
  - The scored elapsed clock stops while the app is backgrounded, so any recorded best time / daily time can be gamed by simply switching apps to think for as long as you like — measured 3:32 -> 3:38 (+6 s) across 64 s of wall clock with 60 s of that backgrounded, same process (pid unchanged). The same app treats its OWN modal alerts the opposite way: the clock keeps ticking under the Deal # and 'Ready to finish' dialogs, so 'the player is not playing' is scored two contradictory ways.
  - evidence: `.qa-loop/evidence/round-1/perf-l3/bgclock-t0-time-3m32s.png`, `.qa-loop/evidence/round-1/perf-l3/bgclock-t64s-wall-time-3m38s.png`, `.qa-loop/evidence/round-1/perf-l3/measurements.txt`
  - measurements: `{"wall_seconds": 64, "backgrounded_seconds": 60, "foreground_seconds_est": 4, "clock_before": "3:32", "clock_after": "3:38", "clock_delta_seconds": 6, "pid_before": 36342, "pid_after": 36342, "second_run_mcp_home": "clock 2:32 -> 2:59 (+27 s) over 78 s wall with 45 s backgrounded"}`
  - note: TRAP — do not 'fix' by counting background time: that punishes a player who takes a phone call, and it would retroactively invalidate nothing while making every future time worse than an already-banked one. The honest options are (a) accept the background pause and make the in-app alerts pause too (consistent, but then any sheet becomes a pause button — see ux/WF-4:clock-runs-during-finish-prompt, whose naive fix has the mirror-image risk), or (b) show the pause explicitly (e.g. mark a resumed game's time as paused) so the recorded number keeps its meaning. Either way this is a scoring-semantics decision for the human, not an unattended fix. fix_risk: metric-integrity.
- **ux/WF-12:landscape-cards-smaller-than-portrait** — minor, open; region `WF-12`
  - Rotating to landscape makes the cards SMALLER, not bigger: on the same fresh deal the card is 45.0x75.3pt in landscape vs 49x75 in portrait, and the tallest column bottoms out at y=289 of the 381pt usable height, leaving ~24% of the board height as empty background. Width binds (12 card-widths + the 118pt rail across 756pt), so landscape buys the player nothing over portrait.
  - evidence: `.qa-loop/evidence/round-1/wf-12-1/tc121-landscape-board-deal10011.png`, `.qa-loop/evidence/round-1/wf-12-1/measure-hierarchy-nohud.txt`
  - measurements: `{"card_w_h_landscape_fresh": "45.0 x 75.3", "card_w_h_portrait_fresh": "49 x 75", "card_w_h_landscape_daily_hud": "43.0 x 72.0", "tableau_fan_pitch_landscape": 26.0, "tallest_column_bottom_edge": 289.0, "usable_board_bottom": 381.0, "unused_height_fraction": 0.24, "tableau_right_edge": 786.0, "usable_width_right": 815.0}`
  - note: Structural — the human decides. The layout is internally consistent (uniform shrink verified: a 13-card column takes the WHOLE board to 36.0x60.3 with pitch 20 and no clipping, floor 30 never hit), so this is a question of whether landscape should reserve a 118pt rail and a 4-wide foundation block across the top row at all.
- **ux/WF-13:objective-labels-ignore-text-size** — major, open; region `WF-13`
  - The objective labels a player must read while playing are hard-coded to 10 pt (`DailyView.swift:453`, `Text(label).font(.system(size: 10))`) and do not respond to the system text-size setting at all: with iOS text size at accessibility-extra-large the board's daily HUD renders byte-for-byte identically to the default size, so a large-text user still reads Aug 5's Gold objective 'Split every suit exactly down the middle - A-7 up, 8-K down' at 10 pt - the smallest text on the board, below Apple's 11 pt floor. On the Daily card the same setting DOES enlarge the tier status circles while the label text stays put, so the app is partly Dynamic-Type-aware and the labels look like an oversight rather than a deliberate whole-app opt-out.
  - evidence: `.qa-loop/evidence/round-1/wf-13-2/tc136-hud-stacked-full-label.png`, `.qa-loop/evidence/round-1/wf-13-2/tc136-hud-accessibility-xl-unchanged.png`, `.qa-loop/evidence/round-1/wf-13-2/tc136-card-accessibility-xl.png`
  - measurements: `{"hud_label_font_pt": 10, "apple_min_recommended_pt": 11, "content_sizes_tested": ["large (default)", "accessibility-extra-large"], "hud_crop_md5_default": "eea6f3c2d681fba350883d2fc287cf0d", "hud_crop_md5_ax_xl": "eea6f3c2d681fba350883d2fc287cf0d", "fixed_size_font_calls_in_Views": 45, "semantic_font_calls_in_Views": 9, "gold_label_chars": 51}`
  - note: TRAP: the naive fix (swap the 45 fixed-size fonts for semantic ones) reflows the whole board - the stacked daily HUD already costs +80 pt of board height, and at AX sizes an enlarged HUD plus toolbar would push the tableau off-screen and invalidate every geometry note in HARNESS_NOTES.md. A bounded scale (e.g. scaledValue capped) or a tap-to-expand objective readout is likelier right; that is a design call, hence proposal routing. Scope note: the fixed-size pattern is app-wide, not WF-13-specific - filed here because TC-13.6 is where it bites hardest (the HUD label is the smallest text on the board and the only in-play statement of what Gold requires).
- **ux/WF-3:new-game-discards-in-progress-deal** — minor, open; region `WF-3`; fix_risk `behavior-change`
  - Tapping `New game` mid-deal instantly destroys the in-progress game with no confirmation, no toast and no recovery path: Undo is cleared and greyed out, `Replay` from then on restarts the NEW deal, and the abandoned deal number is not surfaced anywhere in the UI, so a player who mis-taps the largest/gold/top-left pill cannot return to the deal they were solving (verified: Deal #910,172 at Moves 3 / 7:15 -> Deal #110,714 at Moves 0 / 0:00 in one tap).
  - evidence: `.qa-loop/evidence/round-1/wf-3-1/ux-newgame-before-3moves-deal910172.png`, `.qa-loop/evidence/round-1/wf-3-1/ux-newgame-after-discarded-deal110714.png`
  - measurements: `{"taps_to_destroy": 1, "confirmation_steps": 0, "recovery_affordances": 0, "moves_lost": 3, "elapsed_lost_mmss": "7:15"}`
  - note: TRAP: the obvious fix (a confirm dialog on New game) directly contradicts WORKFLOWS.md WF-3's stated 'each is one tap' expectation and would also hit Replay. Non-breaking alternatives exist (an undoable 'Deal #N abandoned - Undo' toast, or keeping the previous deal number visible/one-tap-restorable), but which - if any - to adopt is a human call. Replay has the same no-confirm behaviour; it is less severe because the deal number survives on screen.
- **ux/WF-4:clock-runs-during-finish-prompt** — minor, open; region `WF-4`; fix_risk `metric-integrity`
  - The game clock keeps running while the app's own modal "Ready to finish" alert blocks all input, and that dead time lands in the result the win overlay reports (and in the stored best time): with the alert up and no input possible the header clock advanced 3:42 -> 4:28 over a 45 s wall-clock window.
  - evidence: `.qa-loop/evidence/round-1/wf-4-1/clock-during-prompt-t0.png`, `.qa-loop/evidence/round-1/wf-4-1/clock-during-prompt-t45.png`, `.qa-loop/evidence/round-1/wf-4-1/tc41-ask-prompt.png`
  - measurements: `{"clock_before": "3:42", "clock_after": "4:28", "wall_window_s": 45, "input_possible_during_window": false}`
  - note: TRAP: the naive fix (pause GameClock while a modal is up) turns any sheet — Daily, Wins, How to play — into a pause button and corrupts recorded best times. If anything is done here, scope it to the app-initiated auto-finish alert only (e.g. subtract the alert's dwell), and leave user-opened sheets alone.
- **ux/WF-4:undo-after-win-reopens-solved-deal** — minor, open; region `WF-4`; fix_risk `metric-integrity`
  - After a win, tapping Close and then Undo un-wins the completed deal: the last card comes back out of the foundation, the game clock resumes on a deal that is already banked, the Finish pill reappears, and tapping it fires a second 'You solved it!' overlay for the same deal with a worse time (98 moves 3:07 -> 98 moves 3:45). The loop can be repeated indefinitely.
  - evidence: `.qa-loop/evidence/round-1/wf-4-1/tc44-manual-finish-overlay.png`, `.qa-loop/evidence/round-1/wf-4-1/undo-after-win-unwins-board.png`, `.qa-loop/evidence/round-1/wf-4-1/undo-after-win-second-overlay.png`
  - measurements: `{"first_overlay": "98 moves / 3:07", "second_overlay": "98 moves / 3:45", "won_counter": 1, "repeatable": true}`
  - note: No data corruption observed: WinStore keeps min(moves,secs) per deal and the Won counter (distinct deals) stays 1, so the repeat overlays cannot improve or damage a record. TRAP: disabling Undo once a deal is complete is a behaviour change and also touches the daily-attempt path (an undo after a recorded daily win bumps telem.undos) — human call, and worth checking DailyStore before changing anything.
- **ux/WF-6:done-hands-back-casual-board** — major, open; region `WF-6`; fix_risk `metric-integrity`
  - The completed-demo banner says "That's a winning line — tap Done to try it yourself", but Done (and Stop) re-deal the day's seed as a CASUAL board with no objectives HUD and no challenge binding, so the novice who accepts that invitation plays the whole daily deal for zero daily credit — no Bronze/Silver/Gold tier, no streak — with nothing on screen to warn them. Daily -> Play on the identical deal shows the 3-line objectives HUD; demo -> Done shows none.
  - evidence: `.qa-loop/evidence/round-1/wf-6-1/tc64-completion-banner.png`, `.qa-loop/evidence/round-1/wf-6-1/tc64-after-done-casual-board.png`, `.qa-loop/evidence/round-1/wf-6-1/wf6-daily-play-board-has-hud.png`, `.qa-loop/evidence/round-1/wf-6-1/tc63-after-stop-fresh-board.png`
  - measurements: `{"demo_exit_board_has_objectives_hud": false, "daily_play_board_has_objectives_hud": true, "deal_both_cases": 10011}`
  - note: TRAP: the obvious fix - have Stop/Done re-arm challengeDay for the day just demoed - changes what can be scored, and must not let the demo's own moves/telemetry survive into the scored attempt (Game.showSolution already clears telem via deal(); Game.restartDeal restores challengeDay only if it was set). The cheap alternative is wording-only: stop promising 'try it yourself' and say the board is practice / point at Daily -> Play. Scoring consequence verified by inspection (Game.swift recordChallengeResult guards on challengeDay, which showSolution clears), not by playing a full deal to a win.
- **ux/WF-7:deal-entry-tap-cost** — minor, open; region `WF-7`
  - WORKFLOWS.md budgets <=3 taps to open, type and play a specific deal; the real cost is 13 (1 open + 6 backspaces to erase the prefilled current seed + 5 digits + 1 Play), because the alert prefills the current seed with the caret at the end and never selects it, so the first digit typed appends to the old seed instead of replacing it.
  - evidence: `.qa-loop/evidence/round-1/wf-7-1/tc71-prefilled-cursor-at-end.png`, `.qa-loop/evidence/round-1/wf-7-1/tc71-deal-10003-loaded.png`
  - measurements: `{"taps": 13, "expected_taps": 3, "chrome_taps": 2, "backspaces_wasted": 6}`
  - note: Routed proposal on purpose: round-0 exploration already ruled this 'within the bar' by redefining the budget as chrome taps only (TESTCASES.md TC-7.1), which contradicts WORKFLOWS.md's WF-7 line. A human should settle which bar applies before anyone edits code. Two cheap options if it is accepted: select the prefilled seed when the alert opens (standard iOS field behaviour, first digit replaces), or open the field empty since the placeholder '1-1,000,000' already states the range. TRADE-OFF: select-all makes 'nudge the current seed by one' harder, which is why this is a taste call rather than an obvious defect.
- **ux/WF-7:clock-runs-during-deal-alert** — minor, open; region `WF-7`; fix_risk `metric-integrity`
  - The elapsed-time clock keeps ticking while the modal Deal # alert is up, so time spent in a dialog where no card can be touched is banked into the deal's recorded time; opening the alert and cancelling took Moves 1 / Time 0:07 to Moves 1 / Time 1:01.
  - evidence: `.qa-loop/evidence/round-1/wf-7-1/tc75-cancel-state-intact-time-1m01.png`
  - measurements: `{"time_before_alert_s": 7, "time_after_cancel_s": 61, "moves_delta": 0}`
  - note: TRAP: the naive fix (stop GameClock whenever a modal is presented) turns the Deal alert — and every sheet: Daily, Wins, How to play — into a free pause button, which corrupts WinStore best-times and daily best-times. GameClock has no pause concept today and there is no scenePhase pause either (ContentView.swift:208 only persists), so this is a policy decision, not a bug: either accept wall-clock timing everywhere or design a single, non-exploitable pause rule. Elapsed here is inflated by harness latency, but the mechanism — clock advancing with a modal up and no play possible — is what the finding is about, not the exact 54 s. Other lanes may observe the same behaviour behind their own sheets; this is one issue, not several.
- **ux/WF-8:autofinish-off-to-ask-forces-destructive-on** — major, open; region `WF-8`; fix_risk `metric-integrity`
  - The Auto-finish pill is a forward-only 3-state cycle (Ask -> Off -> On -> Ask), so a user sitting in `Off` on a finishable board cannot get back to `Ask` without passing through `On` — and merely landing on `On` instantly auto-finishes the game. One tap intended as a settings change banked a permanent win (Moves 70 -> 93, Won 0 -> 1, Deal pill gained a check), with no confirmation, no long-press menu offering the states directly, no reverse cycle, and no mention of Auto-finish anywhere in `How to play`. Undo rewinds the board (Moves 92, Finish pill returns) but Won stays 1 and the deal stays marked solved, so the accidental win cannot be retracted.
  - evidence: `.qa-loop/evidence/round-1/wf-8-1/tc84-not-yet-finish-pill.png`, `.qa-loop/evidence/round-1/wf-8-1/tc84-off-nothing-happens.png`, `.qa-loop/evidence/round-1/wf-8-1/tc84-on-cascades-win.png`, `.qa-loop/evidence/round-1/wf-8-1/tc84-longpress-no-menu-cycles-on-to-ask.png`, `.qa-loop/evidence/round-1/wf-8-1/tc84-undo-does-not-retract-win.png`
  - measurements: `{"taps_needed_off_to_ask": 2, "destructive_states_transited": 1, "moves_before_settings_tap": 70, "moves_after_settings_tap": 93, "won_before": 0, "won_after": 1, "won_after_undo": 1, "help_sheet_mentions_autofinish": 0}`
  - note: TRAP: the naive fixes are both costly. Making `On` apply only to future boards, or adding a confirmation, breaks the deliberate 'Off -> On is the finish shortcut' documented on AutoFinishMode.next; making the pill reversible/long-pressable changes when wins and best-times are written to WinStore. Distinct from ux/WF-4:undo-after-win-reopens-solved-deal (that is about re-winning; this is about a settings control banking a win the user never asked for). TC-8.3's Ask->Off ordering guard still holds — the 2026-08-16 fix protected only that one direction.
- **ux/WF-9:row-tap-discards-game** — major, open; region `WF-9`; fix_risk `behavior-change`
  - Tapping a deal row in Wins (or Play in the deal field) immediately deals that seed over the game in progress — no confirmation, no undo, and returning to the abandoned deal starts it from scratch: a mid-game player who browses their wins and taps a row loses the whole attempt.
  - evidence: `.qa-loop/evidence/round-1/wf-9-1/tc92-before-switch-moves1.png`, `.qa-loop/evidence/round-1/wf-9-1/tc92-row-tap-discards-progress.png`, `.qa-loop/evidence/round-1/wf-9-1/tc92-after-return-moves0.png`
  - measurements: `{"moves_before_switch": 1, "moves_after_returning": 0, "confirmations_shown": 0}`
  - note: TRAP: the obvious fix (confirm dialog before deal-switch) also has to decide whether New game / Deal # / Daily get the same gate, and an always-on prompt would add a tap to the intended browse-and-replay flow. Human call: warn only when moveCount > 0, or none at all.

## Fix review rejections

_none_

## Severity changes

_none_

## Persona matrix (round 2)

| Workflow | novice | power |
|---|---|---|
| WF-1 | 2✓ | — |
| WF-2 | 5✓ | 5✓ |

## Coverage gaps

_none_

## Closeout

_no closeout cycle ran_

## Wontfix / resolved

_none_

## WATCH LIST

_The part a human should actually read. Candidates below are mechanical; the orchestrator fills each "look here because"._

- **ux/WF-4:clock-pauses-in-background** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-12:landscape-cards-smaller-than-portrait** (proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **bug/WF-13:one-big-move-check-lost-on-undo** (fix_risk metric-integrity) — look here because: <!-- orchestrator fills -->
- **ux/WF-13:daily-play-discards-live-attempt-silently** (fix_risk behavior-change) — look here because: <!-- orchestrator fills -->
- **ux/WF-13:objective-labels-ignore-text-size** (proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-3:new-game-discards-in-progress-deal** (fix_risk behavior-change, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-4:clock-runs-during-finish-prompt** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **bug/WF-4:autofinish-defer-not-persisted** (fix_risk state-migration) — look here because: <!-- orchestrator fills -->
- **ux/WF-4:undo-after-win-reopens-solved-deal** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-6:done-hands-back-casual-board** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-6:demo-pill-discards-casual-game** (fix_risk behavior-change) — look here because: <!-- orchestrator fills -->
- **ux/WF-5:daily-play-restarts-attempt-without-warning** (fix_risk behavior-change) — look here because: <!-- orchestrator fills -->
- **bug/WF-7:deal-entry-range-not-enforced** (fix_risk behavior-change) — look here because: <!-- orchestrator fills -->
- **ux/WF-7:deal-entry-tap-cost** (proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-7:clock-runs-during-deal-alert** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-8:autofinish-off-to-ask-forces-destructive-on** (fix_risk metric-integrity, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **ux/WF-9:row-tap-discards-game** (fix_risk behavior-change, proposal awaiting decision) — look here because: <!-- orchestrator fills -->
- **bug/WinsView:deal-entry-range-not-enforced** (fix_risk behavior-change) — look here because: <!-- orchestrator fills -->
- **round 1 diff** `f949d82..369c365` — 25 files, 8398 lines; largest: `.qa-loop/HARNESS_NOTES.md` (+488/-1074), `.qa-loop/ledger.json` (+879/-637), `.qa-loop/archive/20260822-125736-f949d82/HARNESS_NOTES-full.md` (+1076/-0) — look here because: <!-- orchestrator fills -->
