# Review-loop final report — Causeway

**Result: CONVERGED** (round 2 of a 5-round budget).
**Stop reason:** 0 open blockers, 0 open majors, and no blockers/majors newly introduced
this round. Two open **minors** remain (F6, F7) — carried to the backlog, not fixed.

Rounds ran: cold seed → round 1 (implement+validate) → round 2 (implement+validate).
Commits produced by the loop: `5c70d95` (round 1), `50a139b` (round 2).
Start SHA: `770b422`.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 1 | 2 | 0 | 6 | 0 | -6 | continue |
| 2 | 0 | 0 | 2 | 2 | 1 | 0 | +1 | converged |

## Findings by status

**Fixed & validated**
- **F1 [blocker]** — iOS win-overlay "Close" desynced `won` from the board so `persist()`
  could save a finished/empty board that restored as a broken un-won table. Fixed:
  `dismissWin()` routes Close through the model; `persist()` guards `!won && !boardComplete`;
  `restore()` refuses a completed board. All persist call sites verified to funnel through
  the guard. (`5c70d95`)
- **F2 [major]** — web `isSeqHead` lacked the iOS bounds guard (crash on a stale index during
  the autoplay timer gap). Fixed: matching `col`/`idx` guard added; parity confirmed. (`5c70d95`)
- **F4 [minor]** — restore didn't resume autoplay. Fixed: both platforms call `runAutoplay()`
  after restore; guards prevent reentrancy. (`5c70d95`)
- **F5 [minor]** — privacy policy "Last updated" date stale. Fixed: bumped to 2026-07-05. (`50a139b`)
- **F3 [minor]** — web restore validator didn't range-check `suit`. Fixed for the reported
  case (`suit:9` now rejected; iOS parity confirmed). Related integrality gap split to F7. (`50a139b`)

**Open — minor (to backlog)**
- **F6 [minor, was major]** — a real, passing Node test harness now exists (18 tests; golden
  deal orders independently reproduced), which is genuine progress over "no tests." **But its
  headline "drift guard" is ineffective**: it hardcodes canonical strings and checks them only
  against `index.html`, never deriving them from the imported `tests/engine.mjs` functions. The
  reviewer injected an *unsound* `isSafeAutoplay` change into `engine.mjs` and **all 18 tests
  still passed** — the harness can silently diverge from the shipped engine. Also no
  `isSafeAutoplay` test makes the two opposite-colour-suit checks disagree, so a sound-vs-unsound
  rule is unobservable. iOS XCTest deferral is accepted/documented. Remediation: derive the
  drift strings via `fn.toString()` (or diff `engine.mjs` against `index.html` programmatically),
  and add an asymmetric `isSafeAutoplay` case.
- **F7 [minor]** — restore validator checks range but not integrality: a forged save card with
  `suit:1.5`/`rank:5.5` yields a non-colliding fractional id and is accepted (`isValidSave===true`
  reproduced). Single-player, on-device self-corruption only — low impact. Fix: `Number.isInteger`
  checks on suit and rank (both platforms).

**Disputed (agree-to-disagree):** none. (F6/F7 are open with clear remediation paths, not impasses.)

## HUMAN SKIM LIST — read these, the loop can't fully self-check

The loop used two same-family agents; the highest risk is them agreeing on a wrong fix. Look here:

1. **`tests/engine.mjs` (`50a139b`) — highest-priority human read.** It's a *hand-copied duplicate*
   of the web engine that every test imports, and its own drift guard was **proven not to catch it
   diverging from `index.html`** (F6). Tests here can be green while the shipped engine is broken.
   Verify `engine.mjs`'s `isSafeAutoplay`/`deal`/`isValidSave` match `index.html` line-for-line, and
   decide whether to replace the copy with real extraction.
2. **`ios/Causeway/Causeway/Model/Game.swift` `restore()`/`persist()` (`5c70d95`) — largest core-logic
   change.** The canonical-card restore validator + `boardComplete` persist guard + resume-autoplay
   decide whether a saved game loads or is *silently discarded*. A false-negative throws away a real
   in-progress game with no user signal. Confirm the validator accepts every legitimately-reachable
   partial board (esp. foundation encoding parity with how the app writes `up`/`down`).
3. **`index.html` restore/`isSeqHead`/suit-guard (`5c70d95`, `50a139b`).** Parity-critical engine
   logic; both remaining open minors (F6 harness fidelity, F7 integrality) live here.
4. **`ios/Causeway/Causeway/Views/ContentView.swift` Close→`dismissWin()` (`5c70d95`).** The F1
   blocker fix hinges on Close routing through the model plus the persist guard — confirm no other
   view path can flip `won` and re-persist a finished board.

Not machine-verified this loop (environment lacks Xcode): a clean-clone Xcode build/archive (BACKLOG
M8). All Swift was `swiftc -parse`-checked only; the iOS engine has no XCTest coverage yet (BACKLOG).

## Verdict
Converged: the blocker and both majors from the cold review are fixed and validated with no
regressions introduced. Two minor, well-characterized gaps remain and are logged for follow-up.
