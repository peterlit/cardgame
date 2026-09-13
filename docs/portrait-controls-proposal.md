# Proposal — the portrait control buttons (iOS)

**Status: proposal, 2026-09-13. Nothing implemented.** Mockups are on the design canvas
<https://claude.ai/code/artifact/4e97ce19-249a-4426-9466-138264440882> (six phone artboards: the
current layout, Option A in three states, Options B and C). The artboards are generated from the
app's real values by [`tools/design/portrait-controls-gen.mjs`](../tools/design/portrait-controls-gen.mjs)
(pill style, palette and card geometry lifted from `ContentView.swift`, `Theme.swift` and
`SummerBackground.swift`), so the canvas can be re-seeded after edits. Landscape is untouched — the
owner likes the rail.

## What the current portrait toolbar gets wrong

`ContentView.toolbar` is a `FlowLayout` of ten pills (nine when no daily pool is loaded). On an
iPhone 16 Pro it wraps **4 / 4 / 1**: `New game · Undo · Replay · Auto-play: On` /
`Auto-finish: Ask · Deal #… · Daily · Wins` / `How to play` — an orphan on its own row.

- **No hierarchy.** Play actions (New game, Undo, Replay), settings (Auto-play, Auto-finish),
  reference pages (Daily, Wins, How to play) and a readout (Deal #) all wear the same pill. Only
  New game is gold.
- **No rhythm.** Ten pills of ten widths; the ragged right edge and the orphan row read as
  unfinished next to the landscape rail's single ordered column.
- **Reflow.** `Finish` is inserted mid-flow when `canOfferFinish` flips, so every pill after it
  jumps.
- **Wrong place.** Undo — the most-used control — sits at the top of a 6.3" screen while the
  thumb zone below the tableau is empty sand.
- **Cost.** Three rows ≈ 124 pt of the board's height budget (`portraitFitCardW` fits the board
  under it).

## Option A — Deck (recommended)

A bottom bar in the thumb zone, sitting on the sand band: five equal cells, icon over an 11 pt
label — **New game** (gold) · **Undo** · **Replay** · **Daily** · **More**. The bar is the same
translucent capsule material as today's pills (`2A3B44 @ .46`, white hairline), 20 pt radius, 60 pt
tall, 14 pt above the home indicator.

- **More** is an iOS `Menu`: `Auto-play ✓ On`, `Auto-finish Ask`, then `Wins`, `How to play`.
  Menu rows show state, so nothing is hidden — it is one tap further away.
- **Deal #** becomes a small readout chip under the subtitle (`Deal #408843 ›`); tapping it opens
  the existing deal alert. The header's stats align to the top so the chip does not push them.
- **Finish**, when offered, rises as a gold pill centred above the bar. Nothing else moves.
- The Daily HUD and demo bar keep their slot under the header (they no longer sit under a
  toolbar).

Gains roughly 60 pt of board height in portrait (124 pt of toolbar out, ~64 pt of bar in, the
bar overlapping sand the tableau rarely reaches). Tradeoffs: two settings are behind a menu; the
bar covers the bottom of very long columns on short phones (the existing shrink latch handles
the fit exactly as it does for the toolbar today).

**Implementation notes.** UI tests address `toolbar.autoplay`, `toolbar.autofinish`,
`toolbar.wins`, `toolbar.howtoplay` directly (5–21 references each). Keep those identifiers on the
menu items and add a `QAFixtures` helper that taps `toolbar.more` first in portrait; the landscape
rail keeps its flat list so the helper is orientation-aware. `RegressionAccessibilityIdentifiersTests`
counts "nine toolbar pills" and would need the More step. `pill` / `FlowLayout` stay for the
Daily HUD's capsules.

## Option B — Two rows (conservative)

Everything stays at the top, in two fixed-height rows:

1. A segmented capsule of four equal cells: **New game** (gold) · **Undo** · **Replay** · **Daily**.
2. A quiet status strip: low-contrast chips `Deal #408843` · `Auto-play On` · `Auto-finish Ask`
   on the left, a round **More** button (Wins, How to play) on the right.

Finish, when offered, appears as a full-width gold bar under the strip. Saves ~30 pt, never
reflows, and leaves the identifier scheme almost untouched. Weaker than A on reach: Undo is still
at the top.

## Option C — Grid (minimal)

The same ten pills snapped to a 4-column grid of equal cells (wide labels span two): `New game ·
Undo · Replay · Daily` / `Auto-play On · Auto-finish Ask · Deal #…` / `Wins · How to play`.
Nothing changes but rhythm. Honest but weakest: still three rows of same-weight buttons, and
Finish still has to squeeze in.

## Recommendation

**A.** It is the portrait equivalent of what the rail already does in landscape — one ordered set
of actions with a single primary — and it is the only option that puts Undo under the thumb and
gives the board its height back. If the menu for the two auto settings feels like a step too far,
B is the fallback: same hierarchy, same fixed rhythm, top placement kept.
