# Causeway — QA Loop Report

**Build:** `342e3c0` · **Rounds run this session:** 2 (continuing the round-1 ledger) ·
**Testers:** 3 parallel workers + 1 uncontended perf lane · **Full pass, 47/47 test cases run**

---

## Stop condition: `thrashing` — and it is a FALSE POSITIVE

`qa_metrics.py` aborted the loop with `thrashing / "oscillation or non-positive net
over two rounds"`. The trigger is real but the diagnosis is not:

| Thrashing signal | Actual value |
|---|---|
| Any finding reopened >= 2 times | **0 findings reopened, ever** |
| Same region recurring for 3 rounds | **0 recurring regions** |
| net <= 0 for two consecutive rounds | **yes — round 1 net -2, round 2 net -9** |

Only the third signal fired. `net = closed - new`, so **any productive discovery round
is net-negative by construction** — and rounds 1 and 2 were *both* discovery passes with
no implementer dispatch between them inside this loop's accounting. Round 2 also ran a
materially stronger harness than round 1 (rotation turned out to be drivable, so
landscape moved from code-review to real interaction), which is exactly why it found
more. Nothing oscillated; the loop found 11 new real defects and closed 2.

**Recommendation: this is not a loop to abandon, it is a loop that has never been given
a fix round.** Run the implementer against the 2 open majors.

## Trend

| Round | Pass | Blockers | Majors | Minors | Proposals | Closed | New | Reopened | Net | Decision |
|-------|------|----------|--------|--------|-----------|--------|-----|----------|-----|----------|
| 1 | full | 0 | 0 | 2 | 2 | 0 | 2 | 0 | -2 | converged |
| 2 | full | 0 | 2 | 9 | 4 | 2 | 11 | 0 | -9 | thrashing |

**Closed this round** (fixed by commit `5b237b4`, verified on screen by two testers):
`bug/WF-11:cancel-note-not-updated`, `ux/WF-11:singular-plural-grammar`. The round-1
proposal `ux/WF-6:demo-done-leaves-empty-board` was also implemented and verified fixed.

---

## Open findings

### Majors (2) — both auto-routed, both unfixed

**`bug/WF-6:demo-progress-counts-as-a-real-win`** · WF-2/TC-6.3 · fix_risk: **metric-integrity**
Stop mid-demo leaves the app's own solution moves on the board with no undo history, and
finishing from there is banked as a genuine win in `causeway.wins` — Won +1, deal
check-mark, best moves/time. A run banked a **29-second "best time" for a 92-move deal
after the demo played 64 of those moves**. `showSolution()` already clears `challengeDay`
to protect the daily tiers (verified: Bronze stayed unearned after an assisted win), so
the Wins store is simply missing the same guard. **Independently reproduced by a second
tester** on deal #10,004.
*Trap:* refusing to record any post-demo win also punishes a player who stops the demo at
move 1 and genuinely solves the deal, and it changes already-persisted best-time semantics.
Suggested shape: taint the game only while assisted moves remain on the board (clear on
Replay/new deal), or record assisted wins without a time/moves best.
Evidence: `evidence/round-2/qa-worker-2/bug-demo-71of97-paused.png`,
`bug-demo-stopped-71moves.png`, `bug-assisted-win-overlay.png`

**`bug/Main:portrait-tall-column-clipped-offscreen`** · Main/TC-2.3
Portrait uses a fixed `portraitCardW` (`ContentView.swift:53`) and the tableau never
scrolls (`ContentView.swift:50-51`), so a growing column runs off the bottom of the
screen: **the bottom card is clipped at 13 cards and fully invisible — untappable,
undraggable — at 15**. Undo is the only recovery. Long alternating runs in one column are
ordinary Causeway play, not a stress test. Landscape already solves exactly this by
shrinking `cardW` to the tallest column (`ContentView.swift:62-73`); portrait needs the
same clamp. Landscape was explicitly re-tested and is **not** affected (cardW shrinks
43→39pt as a column grew 7→9).
Evidence: `evidence/round-2/qa-worker-1/bug-portrait-column-clip-14cards.png`,
`bug-portrait-column-clip-16cards.png`

### Minors — auto-routed (7)

| ID | What |
|---|---|
| `bug/DailyView:calendar-weekday-header-missing-letters` | Thu and Sat have no letter — `ForEach(["S","M","T","W","T","F","S"], id: \.self)` collapses duplicate ids. Header reads `S M T W _ F _`. Column positions still correct. |
| `ux/WF-5:hud-objective-labels-truncated` | `DailyHUD.objChip` uses `lineLimit(1)`; gold reads "Win without ever usin…" — you cannot tell what gold asks for without reopening Daily. |
| `ux/WF-7:deal-field-no-clear-affordance` | Prefilled seed is neither selected on focus nor clearable: **12 taps vs the 3 WF-7 budgets**, 5 forced backspaces. |
| `ux/WF-9:deal-number-format-inconsistent` | Same deal renders three ways — `10004–10006`, `Deal #10005`, `Deal #10,004` — two of them one tap apart inside Wins. `Text(LocalizedStringKey)` group-formats; plain `String` interpolation does not. |
| `ux/WF-8:autoplay-safe-only-unexplained` | **Not a behavior bug.** `isSafeAutoplay()` (`Game.swift:576-585`) correctly requires both opposite-colour neighbours resolved, because Causeway piles build both ways. The *label* is the problem: "Auto-play: On" is the only string shown and `RulesView` never mentions Auto-play at all, so an ignored exposed Ace reads as broken. Two testers hit it independently. |
| `bug/Main:clock-pauses-while-app-backgrounded` | fix_risk: **metric-integrity**. `GameClock` is a 1 Hz Timer, so backgrounding is a free pause: 23.7 s wall spanning a 20 s background advanced the clock **6 s**. `recordWin()` stores this as best time. |
| `bug/Main:landscape-disabled-undo-blank` | Landscape rail's disabled Undo renders as a featureless white capsule — no glyph, no text at 3x zoom. Portrait's disabled state is legible. 3 reproductions. |
| `ux/Main:undo-stack-lost-on-relaunch` | fix_risk: **state-migration**. Cold launch restores the board with zero undo depth. Deliberate per the `persist()` comment, but Undo is a primary control in a pure-skill game. |
| `ux/WF-11:export-picker-no-progress-indicator` | First Export after **any** cold launch freezes ~1.8 s after touch with no spinner (3 trials, two byte-identical frames), settling 2.2–2.9 s. Warm repeat 1.2 s. Cost is `UIDocumentPicker` warm-up — the app can't make it fast, but it can show a spinner or pre-warm. |

---

## UX PROPOSALS (human decides — flip `routing` to `auto` and re-run to accept)

1. **`ux/WF-12:landscape-cards-no-bigger-than-portrait`** — The landscape branch's own
   comment claims the rail layout "frees room so the cards grow". Measured, it does not:
   landscape cardW is width-bound at **45pt, identical to portrait's 45pt**, while the
   available height would allow ~54pt, leaving a **116pt (29%) empty band** under the
   tableau. Rotating currently buys the player nothing. Structural — the 12-card-width
   three-column split is the cause — so it is a design call, not a patch.
2. **`ux/Main:clock-runs-during-modal-sheets`** (carried from round 1) — **Already decided
   against**: commit `2796867` reverted the pause and kept continuous timing for honest
   best-times. Testers were told not to re-file it. Consider closing this one as wontfix.
   Note it is the same metric family as `bug/Main:clock-pauses-while-app-backgrounded`,
   which is *open and auto-routed* — those two should be decided together.
3. **`ux/WF-5:no-hook-to-reach-daily-earned-state`** and
   **`ux/Main:no-debug-seed-or-date-override`** — Testability, not user-facing. The daily
   deal is wall-clock derived with no override, so day-boundary streak/tier behavior is
   untestable and TC-5.3 is permanently blocked. Suggested: a `#if DEBUG` launch argument
   (`-causewayDayIndex N` / `-causewaySeed N`). *Trap:* any override surviving into Release
   lets a player farm daily streaks — must be DEBUG-only and must not write the record store.

## FIX REVIEW REJECTIONS

None — no implementer ran this session, so there were no fixes to review.

## PERSONA MATRIX

| Workflow | Label | Novice | Power | Hole? |
|---|---|---|---|---|
| WF-1 | novice | yes | — | no |
| WF-2 | both | yes | yes | no |
| WF-3 | both | yes | yes | no |
| WF-4 | power | — | yes | no |
| WF-5 | both | yes | yes | no |
| WF-6 | novice | yes | — | no |
| WF-7 | power | — | yes | no |
| WF-8 | power | — | yes | no |
| WF-9 | both | yes | yes | no |
| WF-10 | novice | yes | — | no |
| WF-11 | power | — | yes | no |
| WF-12 | both | yes | yes | no |

Every workflow labeled "both" was exercised by both personas. **No coverage holes.**
Cross-cutting probes P-A…P-E ran power-only (they are not persona-scoped).

## COVERAGE GAPS

- **TC-5.3 — blocked.** "Replay to improve" label, streak/total/best update, tier
  check-marks. The only legitimate route to a daily record is solving a par-97 deal by
  hand; the demo deliberately clears `challengeDay` and no debug/state override exists.
  Tracked by proposal `ux/WF-5:no-hook-to-reach-daily-earned-state`.

All other 46 test cases ran. 45 passed, 1 failed (TC-12.1, landscape disabled-Undo).

## Material WORKFLOWS.md edits this round (flagged, not re-gated)

1. **Added a "Fixture policy" section** (the round-1 file had none). Pins the deal number,
   documents that the app has no launch arguments or seed override, and names the
   day-boundary gap.
2. **Corrected the daily deal:** the round-1 note hard-coded #10,003 (dayIndex 2, Aug 14).
   Today is 2026-08-15 = dayIndex 3 = **#10,004**, verified on screen. The note is now
   derivation-based rather than a hard-coded number.
3. **Deleted the claim that landscape rotation is undrivable.** It is drivable —
   `XCUIDevice.shared.orientation` works from an XCUITest driver (orientation resets to
   portrait each `xcodebuild test` run, so a landscape script must rotate first). WF-12
   ran as real interactive testing this round, not code review.

`TESTCASES.md` still describes the Aug-14 daily (#10,003) with different Silver/Gold
labels in its screen map — refresh WF-5/WF-6 test cases before the next round.

---

## WATCH LIST — read this part

| # | Item | Why look |
|---|---|---|
| 1 | `bug/WF-6:demo-progress-counts-as-a-real-win` | fix_risk **metric-integrity**, and the obvious fix is a trap: blanket-refusing post-demo wins punishes an honest player who stops at move 1, and it re-interprets already-persisted best-times. Whatever ships here needs human sign-off on the semantics, not just a green test. |
| 2 | `bug/Main:clock-pauses-while-app-backgrounded` | fix_risk **metric-integrity**, and it directly contradicts a decision you already made (`2796867` kept continuous timing). Fixing one and not the other leaves best-times inconsistent in opposite directions. A wall-clock anchor also charges the player for phone calls — and must not double-count the persisted `elapsed` on restore. |
| 3 | `ux/Main:undo-stack-lost-on-relaunch` | fix_risk **state-migration**. Persisting undo history changes the `SavedGame` `Codable` shape; without an optional field + decode fallback, every in-progress game on an upgraded install is silently discarded. |
| 4 | `ux/WF-8:autoplay-safe-only-unexplained` | Listed *because its obvious fix is wrong.* Making Auto-play aggressive would strip real skill decisions and can strand a deal. The rule is correct; only the label and the rules text need to change. |
| 5 | `bug/Main:portrait-tall-column-clipped-offscreen` | The clamp is easy, but it changes card size mid-game as columns grow — verify it doesn't cause card-size thrash on every move, which is the failure mode landscape's version already flirts with. |
| 6 | Both testability proposals | Accepting either adds a code path to a shipping app. `#if DEBUG` discipline is the whole safety argument. |

**Perf lane was clean.** Idle CPU 0.0–1.0% in every orientation/HUD combination, RSS flat
across 12 undo cycles and 15 New game + 15 Replay (no leak), cold launch <=0.9 s to a
painted board, demo 0.259 s/move vs 0.24 designed, auto-finish ~0.18 s/card, 0 network
bytes. The only stall found is the Export picker warm-up above.
