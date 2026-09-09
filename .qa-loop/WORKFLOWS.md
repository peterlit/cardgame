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
  overlay reports the result (incl. any daily tiers) and is dismissible. *(Owner decision
  2026-09-08: Undo AFTER a scored win is a casual continuation — the award stands, the daily
  binding is gone, and a re-completion records a fresh casual win. Not a bug. Backgrounding the
  app now PAUSES the clock; foreground resumes it — banked time excludes background time.)*
  paths(WF-4): ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/WinStore.swift, ios/Causeway/Causeway/Model/GameClock.swift
- **WF-5 — Daily Challenge: read objectives, play, read stats (both).** Open Daily;
  understand Today's Bronze/Silver/Gold objectives and the **five** streak cards (🔥 Play,
  ⏰ Same-day, 🥈 Silver, 🥇 Gold, 🌟 Flawless — each showing streak / N total / best); start the
  challenge with Play. *(Updated 2026-08-30: it was four cards before ⏰ shipped.)* Expectation: objectives are legible;
  streak vs total vs best is not confusing; Play is one tap and hands off to the board
  with the live objectives HUD. *(Added 2026-09-09, a65bb3b: once a day has been SOLVED its
  card gains a clears line — `daily.clears`: "Cleared 3× · fewest 96 moves · fastest 5:41 · par 72",
  plus "Moves each run: …" when there is more than one run. Fewest and fastest are INDEPENDENT
  minima by design, never one run's pair. An unsolved day shows no such line and no par.)*
  paths(WF-5): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/DailyStore.swift, ios/Causeway/Causeway/daily-pool.json, data/daily-pool.json
- **WF-6 — "Show me how to win" demo (novice).** From the Daily card, use the how-to-win pills —
  **🥉 Clear / 🥈 Silver / 🥇 Gold / 🌟 Flawless, laid out as a two-column grid** *(updated
  2026-08-30: 🌟 Flawless was added and the row became a grid; the 🌟 pill itself is WF-15)* —
  including step (Next) and Stop. Expectation: the demo is
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
  *(2026-09-09: the live-game confirmation raised from the dismissing alert still hops off the
  runloop with a 0.1 s `asyncAfter` — `ContentView.requestDealFromDismissal`, now shared with the
  Wins screen's Play. The prior loop's open major `bug/WF-7:deal-confirm-swallowed-by-double-tap`
  is therefore expected to still reproduce; re-verify it and reuse the id.)*
  paths(WF-7): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/Game.swift
- **WF-8 — Auto-play & Auto-finish settings (power).** Toggle Auto-play On/Off and cycle
  Auto-finish (Ask/On/Off). Expectation: labels reflect state immediately; behavior
  matches the label (Auto-play only makes safe moves; Auto-finish: Ask prompts).
  paths(WF-8): ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Views/ContentView.swift
- **WF-9 — Review Wins (both).** Open Wins; read solved deals (compressed ranges, best
  time/moves). Expectation: legible, and there is an obvious way back. *(2026-09-09: a solved
  row reads "fewest N moves · fastest T · <date>" — independent minima, deliberately not one
  phrase. Tapping a row or the "Play a deal" entry now routes through the SAME live-game
  confirmation as the board's Deal # (ceeb5f9); silently replacing a live game from Wins is a bug.)*
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
  paths(WF-12): ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Views/CardView.swift, ios/Causeway/Causeway/Theme.swift
- **WF-13 — Past days & the objective-family inventory (both).** *(rewritten 2026-08-30: the
  pre-epoch sandbox is GONE — `dailyChallenge(-1, pool)` now returns null and the calendar
  starts at Aug 1. Past days inside the seeded range replace it as the deterministic fixture.)*
  From the Daily screen's month calendar, tap a **past day** (dayIndex 0…todayIndex-1; under this
  loop's pinned clock that is 0…13 = Aug 1-14 2026, under the real clock on 2026-09-09 it is 0…38)
  and read its objectives, then Play it. *(2026-09-09, b75ee4f: the calendar now NAVIGATES months —
  `daily.cal.prev` / `daily.cal.next` chevrons on the title row, clamped to the months the pool
  spans (Aug–Sep 2026), legend on its own row; cells carry `daily.cal.<idx>` identifiers and are
  single accessibility elements. The prior loop's proposal `ux/WF-13:calendar-month-locked-no-nav`
  is therefore implemented; verify, don't re-file.)* Expectation: a selected past day shows ITS OWN
  objectives (not today's); **par appears only on a day that has been solved**, in the `daily.clears`
  line (an unsolved day shows no par — that is the design, not the old `par-never-surfaced` gap);
  labels are legible and unambiguous to a novice, Play hands off to a board whose
  HUD tracks that day's objectives, and the HUD reflects a violation immediately.
  The thirteen families now in the pool are `moves`, `no-undo`, `cells-le`, `max-run`, `big-move`,
  `split-at`, `end-bias`, `ends-first`, `before-ace`, `suit-top-first`, `suit-sprint`, `rank-rush`,
  `suit-balance` — see the Fixture policy table for a day that exercises each.
  **Constraint objectives are EVALUATIVE, not gating** (unchanged, still true): a disallowed move is
  ALLOWED and the HUD chip flips to a red ✗ — a hard refusal would make Bronze unreachable on some
  deals. The bar is: the violation is reflected immediately and legibly in the HUD, and the tier is
  correctly withheld at win time. A past day that shows today's objectives, an objective that never
  registers, a violation that leaves its chip looking earnable, or a secured check that can be
  un-earned, is a bug. (Telemetry rollback on Undo is deliberate — the HUD telling the truth.)
  paths(WF-13): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/daily-pool.json, data/daily-pool.json
- **WF-14 — ⏰ Same-day recognition (both).** *(new 2026-08-30, commit 0b090d9 + review-loop
  5b8c4e5.)* ⏰ is a fifth strict streak: the day was cleared **on its own date**. It is orthogonal
  to the medals — a bare Bronze earned on the day counts; a Flawless replay of a past day does not.
  Surfaces to exercise: the **⏰ Same-day streak card** (5 cards now: 🔥 Play, ⏰ Same-day, 🥈 Silver,
  🥇 Gold, 🌟 Flawless); the **day-card ⏰ line**, which has FOUR branches (earned → "⏰ Cleared on the
  day"; today, unplayed → "⏰ Win today to start/keep your N-day same-day streak"; a live grace →
  "⏰ Resume your attempt today and it still counts"; a past day → "⏰ Same-day is earned on the day
  itself"); the **calendar corner pip** on ⏰ days; and the **win-overlay** same-day callout.
  Expectation: the right branch shows in each state, the streak card agrees with the calendar pips,
  and replaying a past day never mints ⏰.
  **Formerly-open trap, now claimed fixed (aa076c3 / ceeb5f9 — verify):** `Game.hasLiveGame` is now
  `(moveCount > 0 || graceLive) && …`, so a ZERO-move grace (opened on day D, returned on D+1, no
  move yet) gets the confirmation from all four board-replacing controls — titled "Give up ⏰
  Same-day for <day>?", with the "your 0 moves … will be discarded" clause dropped. The prior loop's
  open major `ux/WF-14:replay-forfeits-grace-silently` covers exactly this; re-run its repro under
  the date pin (open day 13 pinned to Aug 14, relaunch pinned to Aug 15) and reuse the id if it
  still reproduces. A confirm that fires on an untouched CASUAL board is a regression the other way.
  **The grace is day-granular by design** (BACKLOG, 2026-08-30): begun on day D, won any time on D+1
  earns ⏰. That is a recorded product decision, not a bug — but copy that promises a *midnight*
  grace is a bug.
  paths(WF-14): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Views/ContentView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/Game.swift, ios/Causeway/Causeway/Model/DailyStore.swift
- **WF-15 — 🌟 Flawless: the tier, the streak, and "how to win flawless" (both).** *(new
  2026-08-30.)* Flawless = 🥉🥈🥇 all three earned in **one single run** of that day's deal (harder
  than banking them across retries), and it is **sticky** once any single attempt aces all three.
  Surfaces: the 🌟 Flawless streak card; the "🌟 Flawless — Both objectives in one run" how-to-win
  pill on the day card, gated by `game.hasFlawlessLine(c.seed)`; the 🌟 calendar marker (which
  replaces the tier dots, since flawless implies all three); and the 🌟 line on the win overlay.
  Every one of the 61 seeded days has a certified flawless line, so the pill must appear on every day
  the calendar actually EXPOSES — **dayIndex 0…todayIndex (0…14 under this loop's pin; 0…39 on the
  real clock on 2026-09-09)**; later days are future and not selectable, so "all 61" is a data
  claim, not something you can walk in-app. A reachable day whose
  pill is missing is a gate bug, and a pill that plays a line which does NOT end flawless is worse.
  Expectation: the pill is discoverable and its demo is watchable; the 🌟 marker does not jitter the
  calendar date; a flawless win lights the tier, the streak card, and the calendar in agreement.
  paths(WF-15): ios/Causeway/Causeway/Views/DailyView.swift, ios/Causeway/Causeway/Model/Daily.swift, ios/Causeway/Causeway/Model/Game.swift, data/daily-solutions.json

## Fixture policy

*(fully re-verified 2026-08-30 against build 5b8c4e5. The previous version described a
`seeds`/`preSeeds` pool with a pre-epoch sandbox; the pool was rebuilt to schema **v4** in
f42c632 and NONE of those values survive. Everything below was recomputed from
`data/daily-pool.json` and `tests/daily.mjs` today.)*

*(2026-09-09: the "no launch arguments" claim below is OBSOLETE — see the date pin.)*

The app exposes ONE debug lever, **the date pin** (`CAUSEWAY_TODAY_OVERRIDE`, DEBUG builds only,
read in `Daily.swift:todayIndex()`; format `y-m-d`). It overrides ONLY the daily calendar's notion
of today (which day is Today, which are past/locked, the ⏰ branches, the streak arithmetic). Win
record dates, export timestamps and the clock still use the real wall clock. Everything else is
pinned by the deal number and the calendar's playable past days.

- **Launch with the pin (testers):**
  `SIMCTL_CHILD_CAUSEWAY_TODAY_OVERRIDE=2026-08-15 xcrun simctl launch <udid> com.whimsicaldistractions.Causeway`
  (`simctl` forwards `SIMCTL_CHILD_*` variables to the app's environment). The MCP `launch` action
  does NOT carry an environment — an app relaunched through it runs on the REAL date. Terminate and
  relaunch with the env line whenever a test needs the pin; the MCP tap/swipe/screenshot actions
  work on an app launched either way.
- **This loop's pinned date is 2026-08-15 → dayIndex 14** (the UI tests' pin too): seed 608530,
  par 87, silver `max-run` ("Never move more than 2 cards in a single move"), gold `end-bias`
  ("Take at least 10 of every suit from the King end"). Yesterday = Aug 14 (idx 13, seed 720307,
  silver `rank-rush`, gold `suit-top-first`); tomorrow = Aug 16 (idx 15, seed 955693, silver `moves`
  — NO silver pill by design — gold `suit-balance`), locked. Two-day ⏰ sequences: run day 13's
  steps pinned to `2026-08-14`, terminate, relaunch pinned to `2026-08-15`.
- **Fixture limits under the pin (found in round-0 exploration):** `make_save.mjs --tier gold|flawless`
  cannot park day 14 (nor 10 or 11) — the Finish cascade breaks those days' Gold. A same-day
  FLAWLESS fixture therefore pins `2026-08-14` and plays day 13; day 12 is the tier-banking fixture
  (its silver line earns 🥉🥈 only, its gold line 🥇 only). Under the Aug-15 pin, day 14 supports
  `--tier silver` (🥉🥈) and a casual re-win via `--tier bronze --challengeDay none --startDay none`.
- **Real-clock reference (only for cases that say "real clock"):** 2026-09-09 → dayIndex 39,
  seed 967030, par 80, silver `cells-le`, gold `end-bias`. Recompute with the node one-liner below.

- **Deterministic start:** the app is uninstalled and reinstalled each round, so every pass begins
  with zero stats, zero wins, and no daily records. Never test on leftover state.
- **Pool schema (changed):** `data/daily-pool.json` is **version 4**, `epoch = 2026-08-01`
  (= dayIndex 0), `days[0…60]` covering **Aug 1 – Sep 30 2026**, seeds in [500001, 1000000].
  There is no `seeds` array and no `preSeeds` array any more. **The pre-epoch sandbox is gone** —
  `dailyChallenge(-1, pool)` returns `null` and the calendar starts at Aug 1.
- **Today's daily:** `dayIndex = daysFromCivil(y,m,d) - daysFromCivil(2026,8,1)` — pinned via the
  env var above, otherwise date-derived. Recompute any day with:
  `node -e "Promise.all([import('./tests/daily.mjs'),import('fs')]).then(([m,fs])=>console.log(m.dailyChallenge(m.dayIndexFor(2026,8,30),JSON.parse(fs.readFileSync('data/daily-pool.json','utf8')))))"`
- **Past days (PINNABLE — these replace the old sandbox).** Every dayIndex below today's is playable
  from the calendar (month arrows reach August from September) and frozen. Under the pin: 0…13.
  Use them for objective testing. One day per family:

  | Date | dayIndex | seed | par | silver | gold |
  |---|---:|---:|---:|---|---|
  | Aug 1 | 0 | 691039 | 85 | `rank-rush` Queens ≤29 moves | `split-at` at the Three |
  | Aug 2 | 1 | 665641 | 109 | `end-bias` ≥7 from the Ace end | `big-move` run of 7+ |
  | Aug 3 | 2 | 539885 | 86 | `max-run` never move >3 | `suit-sprint` finish one suit first |
  | Aug 29 | 28 | 750496 | 72 | `end-bias` ≥9 from the King end | `ends-first` Kings+Queens home first |

  The remaining families — `moves`, `no-undo`, `cells-le`, `before-ace`, `suit-top-first`,
  `suit-balance` — also appear across days 0…28; enumerate with the node one-liner above rather
  than guessing. Family frequencies in the 61-day pool: `end-bias` 17, `suit-balance` 13,
  `cells-le` 12, `rank-rush`/`split-at`/`max-run`/`moves`/`ends-first`/`before-ace`/`suit-top-first` 9
  each, `no-undo` 7, `big-move` 6, `suit-sprint` 4.
- **Solution lines (corrected by the round-0 audit).** `data/daily-solutions.json` keys **bronze /
  silver / gold / flawless**. **All 61 days carry bronze, gold and flawless** — so the 🥉, 🥇 and 🌟
  how-to-win pills appear on every day. **`silver` is present on 45 of 61 days only**: it is absent
  exactly on the 16 days whose Silver objective is a "universal" family (`moves` / `no-undo`), where
  `solutionLine` falls back to bronze and `hasSilverLine` is false, so `DailyView.swift:203` does not
  render the 🥈 pill at all. **A missing Silver pill on one of those days is CORRECT, not a bug.**
  In dayIndex 0…39 those days are **Aug 5, 6, 10, 16, 21, 23, 26, Sep 6 and Sep 8** (idx 4, 5, 9, 15,
  20, 22, 25, 36, 38; re-verified 2026-09-09 against `data/daily-solutions.json`). On the other days
  the Silver line is distinct and must actually satisfy that day's Silver objective.
- **Free play (pinnable):** for a repeatable board use **Deal #…** with an explicit number rather
  than New Game's random deal. Default to the current day's daily deal number so free-play and daily
  testing share one board unless a test case names another.
- **Midnight hazard:** a run started late in the evening can cross the day boundary mid-pass — the
  Daily card, its objectives, the ⏰ branches and the demo lines all flip. If that happens mid-test-
  case, note it in the result rather than filing the flip as a bug. **This matters more now:** the ⏰
  branch logic is entirely date-driven.
- **Former gap, CLOSED 2026-09-09:** day-boundary / streak / ⏰ behaviour IS now testable
  deterministically through the date pin (two launches with different pins = two days). The old
  recommendation for a debug date override is implemented; do not re-file it. The midnight hazard
  above applies only to real-clock cases.

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
- Two test targets exist: `CausewayTests` (11 Swift unit tests, seconds) and `CausewayUITests`
  (18 test methods — xcodebuild reports 21 because the launch test runs per UI configuration —
  ~8 min, all pinned to `CAUSEWAY_TODAY_OVERRIDE=2026-08-15`). Green on 1a63ce2. UI-test files
  are picked up automatically (filesystem-synchronized group).
- **The six objective types from 2026-08-21 (`split-even`, `down-heavy`, `no-down-foundation`,
  `no-up-foundation`, `no-supermoves`, `one-big-move`) NO LONGER EXIST.** The pool was rebuilt in
  f42c632 under a flawless-certification gate and now carries thirteen different families; see
  WF-13 and the Fixture policy. Do not look for the old ones.
- **Daily history was wiped again** (store v2 → v3, both platforms) — in `0b090d9`, the ⏰ commit,
  not in the `f42c632` calendar rebuild. A fresh
  install therefore has no records at all, which is what this loop wants — but it also means any
  stats-restore test (WF-11) is exercising a v3 store against v3 exports only.
