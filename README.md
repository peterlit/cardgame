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
  `python3 -m http.server`). Works offline; win history is saved in the browser.
- **iOS:** a native SwiftUI app lives in [`ios/`](ios/). Open
  `ios/Causeway/Causeway.xcodeproj` in Xcode 16+ and Run. See
  [`ios/README.md`](ios/README.md) for build details.

## How to play

- **Goal:** move all 52 cards to the foundations.
- **Tableau:** build in alternating colours, one rank at a time, in *either*
  direction (a pile can run up or down — pick a direction when you start it). Move a
  tidy run as a group if you have enough free cells / empty columns.
- **Free cells:** 3 single-card parking spots.
- **Controls:** tap a card then tap its destination; double-tap to auto-move a card
  (or a valid run) to the best spot.

## Layout

```
index.html   self-contained web prototype (HTML/CSS/JS)
ios/         native SwiftUI app (engine + UI ported from the web build)
```

The web prototype and the iOS app share the same rules and deal numbering (a given
deal number produces the identical layout on both).
