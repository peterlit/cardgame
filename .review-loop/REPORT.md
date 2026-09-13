# Loop report — .review-loop

**Stop condition:** `converged` after round 1 — no open blockers or majors; none newly introduced

**Subagent tokens:** 419,585 across 2 round(s)

**Findings by status:** fixed 3, wontfix 2, partial 1

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Promoted | Net | Tokens | Decision |
|-------|----------|--------|--------|--------|-----|----------|----------|-----|--------|----------|
| 1 | 0 | 0 | 5 | 0 | 1 | 0 | 0 | -1 | 73327 | converged |

## Tokens (reported — measured 4-7x below billed effective)

| Round | By role | Total |
|---|---|---:|
| 0 | panel-verifier 58,941; reviewer 104,885 | 163,826 |
| 1 | implementer 88,993; panel-verifier 52,160; reviewer 114,606 | 255,759 |
| **all** | | **419,585** |

## Panel (multi-provider reviewers)

_Per-lane precision — the drop-or-keep signal. Rejected candidates are counts only; confirmed ones appear among the findings tagged `via panel:<lane>`._

| Round | Lane | Filed | Confirmed | Demoted | Rejected | Kept rate |
|---|---|---:|---:|---:|---:|---:|
| 0 | codex | 1 | 1 | 0 | 0 | 1/1 |
| 0 | gemini | 5 | 0 | 2 | 3 | 2/5 |
| 0 | ollama | 10 | 0 | 0 | 10 | 0/10 |
| final | codex | 1 | 0 | 0 | 0 | 0/1 |
| final | ollama | 10 | 0 | 0 | 9 | 0/10 |

## Open findings by severity

### minor (1)

- **docs/qa-loop:stale-toolbar-screen-map** — minor, partial; region `.qa-loop/TESTCASES.md:25-45`; via chair
  - Three checked-in reference docs still describe the deleted portrait toolbar, so the next QA loop drives the app off a stale map and reports phantom failures.
  - note: Core fixed and verified: TESTCASES.md's screen map is rewritten for A2 (portrait deck / landscape rail / More menu ids, all matching ContentView.swift:841-884 and 619-693), app.md #7 is marked gone with its number kept, ios/README.md:80 no longer lists FlowLayout. EDGE STILL OPEN — the case STEPS the QA loop actually executes were not swept and still describe the deleted toolbar: (a) TESTCASES.md:272-273 states the Finish pill appears 'in the toolbar (portrait row 2 between Auto-finish and Deal #)' — under A2 it is its own tier at the TOP of the foot deck (ContentView.swift:843-845) and Deal # is a header chip (ContentView.swift:816), so a driver checking TC-4.2's stated position files a phantom failure; (b) TESTCASES.md:77 'Tap How to play' as a board step, with no More-menu step, in the smoke case TC-1.1 — there is no board-level How to play control any more; (c) TESTCASES.md:357 'the three-line stacked HUD sits directly under the toolbar'. Text-only, no shipped behavior.

## Disputed (agree-to-disagree)

_none_

## Fix review rejections

_none_

## Severity changes

_none_

## Closeout

- **tests/RegressionAccessibilityIdentifiersTests.swift:more-menu-id-tripwire-weakened** — fixed; Closeout verified: QAFixtures.swift:114-121 adds strictID (default false) which asserts byId.waitForExistence(5) and returns the id element with no label fallback; the tripwire passes strictID: true for Wins and asserts toolbar.howtoplay by waitForExistence, the `|| app.buttons["How to play"]` disjunct is gone. Ran the class on 2F77A1A8: passed in 31.6s, and the run log shows both ids resolving on the first ~1s poll (t=8.16 wait -> t=9.19 toolbar.wins; t=9.39 wait -> t=10.43 toolbar.howtoplay), so the strict path resolves on the real identifier, not on a label. Mutation re-run pending. Mutation manifest re-run at HEAD (split verbatim into 2 parts, foreground): strip-wins-id KILLED, strip-howtoplay-id KILLED, control-comment-only SURVIVED — 3/3 match, errors 0, so the kill count is verified, not asserted.
- **tests/QAFixtures.swift:more-menu-id-wait** — wontfix; The wait itself is unchanged; the implementer's argument is that it never times out, and the run log bears that out: in RegressionAccessibilityIdentifiersTests both toolbar.wins and toolbar.howtoplay resolved on the first ~1.03s XCUITest poll, i.e. the id IS surfaced by the Menu and waitForExistence(2) short-circuits. The residual ~1s per call is XCUITest's poll interval, not the fallback, so removing the wait would save nothing. Declining accepted. Residual edge (not worth a fix): the strict proof was taken in portrait only; no landscape (rail Menu) strict run exists.
- **state/ContentView.swift:rail-more-dynamic-id** — fixed; Verified on the code: ContentView.swift:654 is now the unconditional .id("rail.more") on the Menu and :660 gives the conditional Finish pill .id("rail.finish"), so no view's identity depends on canOfferFinish any more (the Finish pill is created/destroyed by the `if` regardless). The cue picks the end anchor at tap time (:685-686), and since Finish is the rail's last child when present and More when absent, the scroll target is the same element the old "rail.last" resolved to — no behavior change. No duplicate .id() is introduced (old code never had one either). Layout-neutral as claimed: .id() adds no view to the VStack, so railContentH/the fold arithmetic are byte-identical; the rejected sentinel would indeed have added one 6 pt spacing. Declining the sentinel is correct. Runtime: both rail classes pass on 2F77A1A8 — RegressionLandscapeRailMoreCueTests (18.7s) scrolls the rail to its end via the cue with Finish live (exercising scrollTo("rail.finish")) and then opens the rail's More menu and lands on the How-to-play sheet; RegressionRailCueFlipsAtEndTests (14.6s) round-trips the cue both ways with Finish live. RESIDUAL (not worth a fix): nothing pins the staticness — no test and no mutant reproduces the open-menu-during-canOfferFinish-flip dismissal, so a future edit could re-introduce a conditional .id() on the Menu silently.
- **docs/qa-loop:stale-toolbar-screen-map** — partial; Core fixed and verified: TESTCASES.md's screen map is rewritten for A2 (portrait deck / landscape rail / More menu ids, all matching ContentView.swift:841-884 and 619-693), app.md #7 is marked gone with its number kept, ios/README.md:80 no longer lists FlowLayout. EDGE STILL OPEN — the case STEPS the QA loop actually executes were not swept and still describe the deleted toolbar: (a) TESTCASES.md:272-273 states the Finish pill appears 'in the toolbar (portrait row 2 between Auto-finish and Deal #)' — under A2 it is its own tier at the TOP of the foot deck (ContentView.swift:843-845) and Deal # is a header chip (ContentView.swift:816), so a driver checking TC-4.2's stated position files a phantom failure; (b) TESTCASES.md:77 'Tap How to play' as a board step, with no More-menu step, in the smoke case TC-1.1 — there is no board-level How to play control any more; (c) TESTCASES.md:357 'the three-line stacked HUD sits directly under the toolbar'. Text-only, no shipped behavior.
- **docs/ContentView.swift:finish-tier-trade-understated** — fixed; Verified on the current text: ContentView.swift:830-834 now says 'finishable and then NOT finishable again ... undo OR from any forward move that breaks the cascade: canOfferFinish is a pure function of position and, unlike maybeAutoFinish, has no autoFinishTierCost() guard', names the live-tier daily / Auto-finish Off / 'Not yet' paths, and the 'remaining play is normally the finish itself' clause is gone. BACKLOG.md:1032-1037 carries the same corrected trigger set. Matches Game.swift's actual guards as cited in the original finding.

## Wontfix / resolved

- **tests/QAFixtures.swift:more-menu-id-wait** — The wait itself is unchanged; the implementer's argument is that it never times out, and the run log bears that out: in RegressionAccessibilityIdentifiersTests both toolbar.wins and toolbar.howtoplay resolved on the first ~1.03s XCUITest poll, i.e. the id IS surfaced by the Menu and waitForExistence(2) short-circuits. The residual ~1s per call is XCUITest's poll interval, not the fallback, so removing the wait would save nothing. Declining accepted. Residual edge (not worth a fix): the strict proof was taken in portrait only; no landscape (rail Menu) strict run exists.
- **layout/ContentView.swift:finish-tier-latch-cost** — Round 1: decline ACCEPTED on the merits. The mechanism is unchanged in the code (portraitDeck:834-838 still gates finishPill on canOfferFinish; latchedBoardH:325/349-352 still holds the per-deal minimum) — the round changed only the doc comment and BACKLOG, which is what a wontfix should look like. The three alternatives all cost more than the defect: (a) unconditional reserve charges every portrait deal ~43 pt, and because canOfferFinish CAN flip repeatedly the alternative of unlatching on the falling edge is a genuine repeatable up/down pulse, not a one-shot correction — the fix_risk stands; (b) folding Finish into the toggle tier contradicts the owner's decided A2 layout and is not an implementer's call; (c) latching the reservation after first appearance is a no-op, the 43 pt is already spent at that moment. Symptom stays bounded: one shrink step, no clipping. BUT the recorded rationale is wrong about how narrow the trigger is — see docs/ContentView.swift:finish-tier-trade-understated, which must be corrected before the owner rules on PC-4.

## WATCH LIST

_The part a human should actually read. Candidates below are mechanical; the orchestrator fills each "look here because". Lead with any shipped BEHAVIOR CHANGE: convergence means two same-family agents agreed — not that the change is correct._

- **layout/ContentView.swift:finish-tier-latch-cost** (fix_risk Changes portrait card sizing — any fix must not reintroduce the up-AND-down rescale pulse latchedBoardH exists to prevent. The safe shape is to make the Finish tier occupy its height UNCONDITIONALLY (reserve the row with an invisible placeholder when !canOfferFinish) so the deck height is constant within a deal and the latch has nothing to absorb; do NOT simply unlatch on canOfferFinish flips.) — look here because: the loop KEPT this as a deliberate wontfix (BACKLOG PC-4) after a real dispute: the ~43 pt one-way latch drop is in the shipped code, and its trigger set is wider than the round-1 rationale first claimed (undo OR any burying forward move, on a live-tier daily / Auto-finish Off / after Not yet). Two same-family agents agreed to keep it; the owner should rule, not inherit the default
- **seed scope** `fa2de2e..bc4c59f` — 23 files, 543 lines; largest: `ios/Causeway/Causeway/Views/ContentView.swift` (+192/-68), `ios/Causeway/Causeway/Views/Extras.swift` (+0/-33), `docs/portrait-controls-proposal.md` (+30/-1) — look here because: `ContentView.swift` +192/-68 is the whole redesign — `portraitDeck`, the restyled rail, `header(landscape:)`, `FlowLayout` deleted. The rail's overflow/fold arithmetic (`railContentH`, pill pitch) and the portrait `latchedBoardH` interplay were verified by test classes on one device (iPhone 16 Pro / iOS 26.5), not by eye on every size class; nothing in the loop looked at iOS 17/18 hardware
- **round 1 diff** `773edcc..HEAD` — 7 files, 92 lines; largest: `ios/Causeway/Causeway/Views/ContentView.swift` (+22/-6), `.qa-loop/TESTCASES.md` (+14/-8), `BACKLOG.md` (+13/-0) — look here because: the ONLY shipped behavior change the loop made is in commit 488313d: the landscape rail's More `Menu` lost its conditional `.id(canOfferFinish ? "rail.more" : "rail.last")` for static `rail.more` / `rail.finish` with the cue choosing the target at tap time. Both rail classes pass, but no test or mutant pins the staticness — a future conditional `.id()` on the Menu would regress silently. The same commit tightened the identifier tripwire (`QA.moreItem(strictID:)`), proven by a 3-mutant manifest re-run at HEAD
- **Most invasive diffs, all rounds:** `bc4c59f` (the scope itself, 23 files / 543 lines, iOS presentation + 14 UI test files) · `488313d` (closeout: rail Menu identity, strict tripwire, three doc sweeps, PC-4 wording) · `8e87557` (round 1: comment + BACKLOG only, no code).
- **Panel:** seed pass kept 3 of 16 candidates (codex 1/1 confirmed; gemini 2/5 demoted to minor — one became the rail `.id()` fix, the other a proven wontfix; ollama qwen3-coder:30b 0/10). Final pass: nothing beyond the chair — 2 of 11 candidates were duplicates of open ledger rows, 9 rejected (ollama 0/10 again).
- **Gemini lane disclosure:** the key is Google's FREE tier. No Pro model is reachable on it (2.5 Pro retired for new users → 404; 3.1 Pro free-tier limit 0), so the lane is pinned to `gemini-3.7-flash`, not the Pro model the owner asked for. It ran ONCE: the seed run on 3.8-flash died on "exhausted your daily quota", a 3.7-flash retry produced the 5 seed candidates, and BOTH final-pass attempts (3.7-flash, then a 3.5-flash retry) died on the same daily-quota error. The final pass therefore had no gemini row. Free-tier inputs may be used for training under Google's unpaid-tier terms — the owner consented to remote lanes knowing the diff leaves the machine.
- **Open residue → BACKLOG.md:** `docs/qa-loop:stale-toolbar-screen-map` stays partial (the QA loop's case STEPS in `.qa-loop/TESTCASES.md:77, 272-273, 357` still describe the deleted toolbar); the two reviewer-noted residuals (no pin on the rail Menu's static id; strict-id proof taken in portrait only) are recorded there too.
- **Hygiene:** clean at report time (no tracked scratch, no Finder duplicates; archive of the 2026-09-09 loop moved with 0 duplicates).
- **Cost:** measured with `tools/loop-usage.py` — 2.99 M effective total (1.98 M subagents, 4.7× the ledger's 419,585; orchestrator 1.01 M). Write-up: `docs/review-loop-0.13.0-feedback.md`.
