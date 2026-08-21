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

- **WF-2 — Core moves: tap-to-smart-move and drag-to-place (both).** Tap a playable
  card and confirm it goes to a sensible spot; drag a card/run to a specific column/
  cell/foundation. Expectation: tap moves the obvious card with no mis-target; drag
  picks up instantly (no press-and-hold) and drops where released.

- **WF-3 — New game / Replay / Undo (both).** Start a fresh random game; replay the
  same deal from the start; undo the last move. Expectation: each is one tap; Undo is
  disabled (and clearly so) when there's nothing to undo.

- **WF-4 — Finish a deal & see the win (power).** Drive a deal to a state where every
  card can go home and complete it (Auto-finish or manual), reaching the win overlay.
  Expectation: when the deal is unblocked, Auto-finish offers to complete it; the win
  overlay reports the result (incl. any daily tiers) and is dismissible.

- **WF-5 — Daily Challenge: read objectives, play, read stats (both).** Open Daily;
  understand Today's Bronze/Silver/Gold objectives and the four streak cards (streak /
  N total / best); start the challenge with Play. Expectation: objectives are legible;
  streak vs total vs best is not confusing; Play is one tap and hands off to the board
  with the live objectives HUD.

- **WF-6 — "Show me how to win" demo (novice).** From the Daily card, use Clear/Silver/
  Gold "show me how to win", including step (Next) and Stop. Expectation: the demo is
  discoverable, starts paused/ready (doesn't auto-run), and steps clearly. **Intended
  exit behavior (changed 2026-08-15):** BOTH mid-demo Stop and post-line Done re-deal
  the same seed to a fresh board — a demo-touched board is never left playable, cards
  cannot be moved (or even lifted by a drag) while the demo bar is up, and no play after
  a demo exit can bank the demo's progress as a win/best-time. A demo board that becomes
  movable, or a win recorded on demo-played moves, is a major bug, not the old behavior.

- **WF-7 — Play a specific deal number (power).** Use "Deal #…" to enter and play an
  exact deal. Expectation: <= 3 taps to open, type, and play; out-of-range/blank input is
  handled without a crash or dead-end. (Changed 2026-08-16: the alert has exactly two
  actions, Play and Cancel — the old Random action was removed as redundant with the
  always-visible New game pill; its removal is intended, not a regression.)

- **WF-8 — Auto-play & Auto-finish settings (power).** Toggle Auto-play On/Off and cycle
  Auto-finish (Ask/On/Off). Expectation: labels reflect state immediately; behavior
  matches the label (Auto-play only makes safe moves; Auto-finish: Ask prompts).

- **WF-9 — Review Wins (both).** Open Wins; read solved deals (compressed ranges, best
  time/moves). Expectation: legible, and there is an obvious way back.

- **WF-10 — How to play / About (novice).** Open "How to play"; find the rules and the
  About/version/copyright. Expectation: rules explain both-ends foundations & controls;
  About shows app name + version; obvious dismiss.

- **WF-11 — Back up & restore stats: Export / Import (power).** On the Daily screen,
  Export stats to a file and Import one back. Expectation: Export produces a dated JSON
  via the Files sheet; Import merges (never erases) and reports what it merged; a non-
  backup file is rejected with a clear message.

- **WF-12 — Landscape play (both).** Rotate to landscape and play. Expectation: the
  board reflows to the rail + foundations + tableau layout, all controls remain reachable
  (rail scrolls if needed), cards are comfortably large, and dragging still works.

## Fixture policy

The app exposes **no launch arguments, debug pickers, or seed overrides** — its only
randomness levers are the deal number and the wall-clock date. Pin them like this:

- **Deterministic start:** the app is uninstalled and reinstalled each round, so every
  pass begins with zero stats, zero wins, and no daily records. Never test on leftover
  state.
- **Daily deal (date-derived, NOT pinnable):** `dayIndex = daysSince(2026-08-12)` and the
  challenge is `daily-pool.json.seeds[dayIndex]`. **Derive it at test time from the
  device's date** — do not hard-code. Reference: 2026-08-15 → dayIndex 3 → deal #10,004
  (par 97, supports `no-cells / aces-first / suits-top-down / cells-le-1 / cells-le-2`);
  2026-08-16 → dayIndex 4 → deal #10,005 (par 86, adds `kings-first`). **Midnight
  hazard:** a run started late in the evening can cross the day boundary mid-pass — the
  Daily card, its objectives, and the demo lines all flip. If that happens mid-test-case,
  note it in the result rather than filing the flip as a bug.
- **Free play (pinnable):** for any test that needs a repeatable board, use **Deal #…**
  and type an explicit number rather than New Game's random deal. Use **the current
  day's daily deal number** (per the derivation above) so free-play and daily testing
  share one board unless a test case names another.
- **Gap:** because the daily challenge is wall-clock-derived with no override, daily
  streak/tier behavior across day boundaries cannot be tested deterministically. A
  proposal-routed finding recommending a debug date/seed override is in scope.

## Notes for the tester
- Landscape **is** interactively testable: `XCUIDevice.shared.orientation` works from an
  XCUITest driver. Orientation resets to portrait on every `xcodebuild test` invocation,
  so a landscape script must rotate as its first step. (Superseded the round-1 note that
  claimed rotation was undrivable — corrected in round 2.)
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
