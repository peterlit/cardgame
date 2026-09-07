# Causeway

An original, full-information skill solitaire — no hidden cards, no luck.

**The twist:** each suit is built from *both ends*. Every suit has two foundations,
an **up** pile (A, 2, 3 …) and a **down** pile (K, Q, J …), that close toward each
other and meet in the middle — you decide where each suit splits. The two halves can
never cross, so the middle cards (7s, 8s) have no home until the ends climb to reach
them. That's the puzzle.

It plays in the FreeCell family: everything is face-up, with free cells, a
two-way alternating-colour tableau, group moves, safe auto-play, and reproducible
numbered deals.

## Play it

- **Web:** open [`index.html`](index.html) in any browser (or serve the folder, e.g.
  `python3 -m http.server`). Works offline; your progress (wins, daily records, the
  in-progress game) is saved in the browser's local storage — where the browser permits
  it, e.g. not in some private-browsing modes. *Daily Challenges need the page to be
  served* (they load a data file), so opening `index.html` straight off the disk plays
  fine but leaves the Daily button disabled.
- **iOS:** a native SwiftUI app lives in [`ios/`](ios/). Open
  `ios/Causeway/Causeway.xcodeproj` in Xcode 16+ and Run. See
  [`ios/README.md`](ios/README.md) for build details.

## How to play

- **Goal:** move all 52 cards to the foundations.
- **Tableau:** build in alternating colours, one rank at a time, in *either*
  direction (a pile can run up or down — pick a direction when you start it). Move a
  tidy run as a group if you have enough free cells / empty columns.
- **Free cells:** 3 single-card parking spots.
- **Controls:** **tap** a card (or a valid run) to send it to the best spot — a
  foundation if it fits, otherwise onto another card, then an empty column, then a free
  cell. **Drag** a card to place it somewhere specific. Everything is face-up — it's
  pure skill.

## Daily Challenges

Every calendar day serves one featured deal with three graded objectives: 🥉 Bronze
(clear the deal — keeps your streak), plus one 🥈 Silver and one 🥇 Gold constraint, such
as "send all four Kings down before any Ace". Earn all three in a *single* run and the
day is 🌟 **Flawless**. Past days stay replayable, streaks are catch-up friendly, and if
you get stuck, "Show me how to win" plays a real winning line for any tier.

The day's challenge is computed from the date — no server, no account — so every device
shows the same one. Design notes: [`docs/daily-challenges.md`](docs/daily-challenges.md).

## Layout

```
index.html   self-contained web prototype (HTML/CSS/JS)
ios/         native SwiftUI app (engine + UI ported from the web build)
data/        baked solver output — the certified daily pool + winning lines
tools/       offline solver + pool/solution builders (build-time only, never shipped)
tests/       canonical shared logic + the Node test suite (npm test)
docs/        design specs and architecture documentation
```

The web prototype and the iOS app share the same rules and deal numbering (a given
deal number produces the identical layout on both). They don't share code — the logic is
maintained as parallel copies held in sync by drift-guard tests. See
[`docs/architecture/overview.md`](docs/architecture/overview.md).

## Working on it

`npm test` runs the shared logic suite. The iOS app has an XCUITest suite; build and run
it from Xcode or with `xcodebuild test`.

If you are new to the repo — human or agent — start with [`HANDOFF.md`](HANDOFF.md): the
current state, the commands that are known to work, and the handful of traps that have
cost real time here. [`CLAUDE.md`](CLAUDE.md) holds the working agreements that apply to
every change. Outstanding work is in [`BACKLOG.md`](BACKLOG.md); the running story of the
project is in [`prompts.md`](prompts.md).
