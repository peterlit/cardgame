# Causeway — QA Workflows

Causeway is an iPhone solitaire (two-ended foundations: build each suit up from Ace
and down from King until they meet). Full-information, pure-skill. Controls: **tap**
a card/run to smart-move it to its best spot; **drag** to place it somewhere specific.
8 tableau columns, 4 foundations (up + down rows), 3 free cells. Plus Daily Challenges
(streaks, tiered objectives, calendar, "show me how to win", stats backup), a Wins
screen, and portrait + landscape layouts.

## Personas

- **Novice (discoverability):** first time opening the app. Never read a manual. Cares
  whether the goal, the controls, and "what do I do now" are figure-out-able from the
  screen. Success = can understand the objective and make legal progress without help.
- **Power user (efficiency):** plays daily, knows the rules. Cares about tap-count,
  speed, and that rare-but-legit complex tasks (replay for a better score, pick a
  specific deal, back up stats, chase a daily gold) are quick and unfrustrating.

## Workflows

Each has a stable ID and a reasonable-effort expectation.

- **WF-1 — Understand the game & make a first legal move (novice).** From cold launch,
  figure out the objective and complete at least one legal move (to a foundation or
  between columns). Expectation: objective/controls discoverable from the board + "How
  to play"; a novice makes a correct move within ~1 min without outside help.
  paths(WF-1): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Views/Extras.swift, ios/Causeway/Causeway/Model/Game.swift
- **WF-2 — Core moves: tap-to-smart-move and drag-to-place (both).** Tap a playable
  card and confirm it goes to a sensible spot; drag a card/run to a specific column/
  cell/foundation. Expectation: tap moves the obvious card with no mis-target; drag
  picks up instantly (no press-and-hold) and drops where released.
  paths(WF-2): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Views/CardView.swift, ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Model/Cards.swift
- **WF-3 — New game / Replay / Undo (both).** Start a fresh random game; replay the
  same deal from the start; undo the last move. Expectation: each is one tap; Undo is
  disabled (and clearly so) when there's nothing to undo.
  paths(WF-3): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/Game.swift
- **WF-4 — Finish a deal & see the win (power).** Drive a deal to a state where every
  card can go home and complete it (Auto-finish or manual), reaching the win overlay.
  Expectation: when the deal is unblocked, Auto-finish offers to complete it; the win
  overlay reports the result (incl. any daily tiers) and is dismissible.
  paths(WF-4): ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/WinStore.swift, ios/Causeway/Causeway/Model/GameClock.swift
- **WF-5 — Daily Challenge: read objectives, play, read stats (both).** Open Daily;
  understand Today's Bronze/Silver/Gold objectives and the four streak cards (streak /
  N total / best); start the challenge with Play. Expectation: objectives are legible;
  streak vs total vs best is not confusing; Play is one tap and hands off to the board
  with the live objectives HUD.
  paths(WF-5): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/DailyStore.swift, ios/Causeway/Causeway/Causeway/daily-pool.json, data/daily-pool.json
- **WF-6 — "Show me how to win" demo (novice).** From the Daily card, use Clear/Silver/
  Gold "show me how to win", including step (Next) and Stop. Expectation: the demo is
  discoverable, starts paused/ready (doesn't auto-run), and steps clearly. **Intended
  exit behavior (changed 2026-08-15):** BOTH mid-demo Stop and post-line Done re-deal
  the same seed to a fresh board — a demo-touched board is never left playable, cards
  cannot be moved (or even lifted by a drag) while the demo bar is up, and no play after
  a demo exit can bank the demo's progress as a win/best-time. A demo board that becomes
  movable, or a win recorded on demo-played moves, is a major bug, not the old behavior.
  paths(WF-6): ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Views/DailyView.swift, data/daily-solutions.json
- **WF-7 — Play a specific deal number (power).** Use "Deal #…" to enter and play an
  exact deal. Expectation: <= 3 taps to open, type, and play; out-of-range/blank input is
  handled without a crash or dead-end. (Changed 2026-08-16: the alert has exactly two
  actions, Play and Cancel — the old Random action was removed as redundant with the
  always-visible New game pill; its removal is intended, not a regression.)
  paths(WF-7): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/Game.swift
- **WF-8 — Auto-play & Auto-finish settings (power).** Toggle Auto-play On/Off and cycle
  Auto-finish (Ask/On/Off). Expectation: labels reflect state immediately; behavior
  matches the label (Auto-play only makes safe moves; Auto-finish: Ask prompts).
  paths(WF-8): ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Views/ContentView.swift
- **WF-9 — Review Wins (both).** Open Wins; read solved deals (compressed ranges, best
  time/moves). Expectation: legible, and there is an obvious way back.
  paths(WF-9): ios/Causeway/Causeway/Views/WinsView.swift, ios/Causeway/Causeway/Model/WinStore.swift
- **WF-10 — How to play / About (novice).** Open "How to play"; find the rules and the
  About/version/copyright. Expectation: rules explain both-ends foundations & controls;
  About shows app name + version; obvious dismiss.
  paths(WF-10): ios/Causeway/Causeway/Views/Extras.swift, ios/Causeway/Causeway/CausewayApp.swift
- **WF-11 — Back up & restore stats: Export / Import (power).** On the Daily screen,
  Export stats to a file and Import one back. Expectation: Export produces a dated JSON
  via the Files sheet; Import merges (never erases) and reports what it merged; a non-
  backup file is rejected with a clear message.
  paths(WF-11): ios/Causeway/Causeway/Model/StatsBackup.swift, ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/DailyStore.swift, ios/Causeway/Causeway/Model/WinStore.swift
- **WF-12 — Landscape play (both).** Rotate to landscape and play. Expectation: the
  board reflows to the rail + foundations + tableau layout, all controls remain reachable
  (rail scrolls if needed), cards are comfortably large, and dragging still works.
  paths(WF-12): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Views/CardView.swift, ios/Causeway/Causeway/Views/Theme.swift
- **WF-13 — Sandbox days & the new objective families (both).** *(added 2026-08-22)* From the
  Daily screen's month calendar, tap a **pre-epoch sandbox day** (Aug 5-11 2026 = dayIndex
  -7…-1; `calCell` deliberately makes `idx < 0` playable) and read its objectives, then Play
  it. These days are the only place the six objective types added in 31b4198 appear:
  `split-even`, `down-heavy`, `no-down-foundation`, `no-up-foundation`, `no-supermoves`,
  `one-big-move`. Expectation: a selected past/sandbox day shows its own objectives and par,
  its labels are legible and unambiguous to a novice, Play hands off to a board whose HUD
  tracks that day's objectives, and `one-big-move` shows its green secured check the moment
  a 5+ card run is relocated (it is positive and irreversible).
  **Corrected 2026-08-22 (round-0 exploration):** the constraint objectives are EVALUATIVE,
  not gating — like the older `no-cells` / `no-undo`, a disallowed move is allowed and the
  HUD chip flips to a red ✗ (a hard refusal would make Bronze unreachable on some deals).
  The bar is therefore: the violation must be reflected immediately and legibly in the HUD,
  and the tier must be correctly withheld at win time. A sandbox day that shows today's
  objectives, an objective that never registers, a violation that leaves its chip looking
  earnable, or a secured check that can be un-earned, is a bug.
  paths(WF-13): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Causeway/daily-pool.json, data/daily-pool.json
## Fixture policy

*(re-verified 2026-08-22 against build f949d82 — the previous version predated the
pre-epoch playtest sandbox and the six new objective types.)*

The app still exposes **no launch arguments, debug pickers, or seed overrides**. Its
randomness levers are the deal number, the wall-clock date, and — new — the calendar's
pre-epoch sandbox days. Pin them like this:

- **Deterministic start:** the app is uninstalled and reinstalled each round, so every
  pass begins with zero stats, zero wins, and no daily records. Never test on leftover
  state.
- **Today's daily (date-derived, NOT pinnable):** `dayIndex = daysSince(2026-08-12)`,
  challenge = `daily-pool.json.seeds[dayIndex]`. **Derive it at test time from the
  device's date** — do not hard-code. Reference for this loop: **2026-08-22 → dayIndex 10
  → deal #10,011, par 98, silver `no-undo`, gold `suits-top-down`.** Recompute with
  `node -e "import('./tests/daily.mjs').then(async m=>{const p=JSON.parse((await import('fs')).readFileSync('data/daily-pool.json','utf8'));console.log(m.dailyChallenge(<dayIndex>,p))})"`.
- **Sandbox days (PINNABLE — use these for objective testing).** `preSeeds[i]` is day
  `-(i+1)`, i.e. Aug 11 2026 = -1 … Aug 5 2026 = -7, all reachable from the calendar this
  month and all frozen:

  | Date | dayIndex | seed | par | silver | gold |
  |---|---:|---:|---:|---|---|
  | Aug 11 | -1 | 872465152 | 70 | no-undo | no-cells |
  | Aug 10 | -2 | 561325499 | 91 | cells-le-2 | kings-first |
  | Aug 9  | -3 | 339664220 | 84 | (moves) | aces-first |
  | Aug 8  | -4 | 186441603 | 80 | moves ≤ 96 | **one-big-move** |
  | Aug 7  | -5 | 942660922 | 91 | **no-supermoves** | **no-up-foundation** |
  | Aug 6  | -6 | 699587523 | 88 | **down-heavy** | **no-down-foundation** |
  | Aug 5  | -7 | 191924978 | 106 | moves ≤ 127 | **split-even** |

  Bold = an objective type that exists nowhere else in the app. This closes the old
  "daily behaviour cannot be tested deterministically" gap for objectives; it does **not**
  close it for streak/day-boundary behaviour, which is still wall-clock-driven.
- **Free play (pinnable):** for a repeatable board, use **Deal #…** with an explicit
  number rather than New Game's random deal. Default to **the current day's daily deal
  number** (#10,011 today) so free-play and daily testing share one board unless a test
  case names another.
- **Midnight hazard:** a run started late in the evening can cross the day boundary
  mid-pass — the Daily card, its objectives, and the demo lines all flip. If that happens
  mid-test-case, note it in the result rather than filing the flip as a bug.
- **Remaining gap:** daily streak/tier behaviour across day boundaries still cannot be
  tested deterministically (no date override). A proposal-routed finding recommending a
  debug date override remains in scope.

## Notes for the tester
- Landscape **is** testable, but how depends on your tools. With the simulator MCP control
  tool there is no orientation API — if you cannot rotate, mark WF-12 cases `blocked` with
  that reason rather than inferring behaviour from code. (Rotation via
  `XCUIDevice.shared.orientation` worked from an XCUITest driver in loop 2; the landscape
  geometry in HARNESS_NOTES.md came from there.)
- **Portrait tall columns (changed 2026-08-15):** growing one column no longer clips it
  off-screen. Intended behavior now: the column's fan compresses first; when the tallest
  column can't fit even at the legibility floor (~15 cards on a 4.7" phone, later on
  taller phones), the WHOLE board — foundations, free cells, and tableau — shrinks to
  one smaller shared card size (uniform; never two card sizes at once), monotone within
  a deal (it does not grow back until a new deal/replay). Clipping or an untappable
  bottom card is a bug; a one-time uniform shrink at a new tallest-column maximum is
  the design.
- The `CausewayUITests` target now exists in `project.pbxproj` (added 2026-08-21) and the
  scheme's testable reference resolves. `xcodebuild ... test` runs six XCUITests; all pass.
- The six objective types added 2026-08-21 (`split-even`, `down-heavy`,
  `no-down-foundation`, `no-up-foundation`, `no-supermoves`, `one-big-move`) appear only on
  sandbox days — see WF-13 and the Fixture policy table. `no-supermoves` is enforced through
  `constraint.maxRun` in `legalMoves`, and `one-big-move` through a `maxRunMoved` telemetry
  field that must survive undo, both multi-card move paths, and a save/restore cycle.
