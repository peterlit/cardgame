# Review-loop final report — qa-loop round-2 major fixes (demo-exit integrity + tableau fan compression)

**Result: CONVERGED** (round 2): 0 open blockers, 0 open majors, none newly introduced this
round. 4 open minors remain (2 partial, 2 new) — mop-up candidates, none ship-blocking.

Scope: commit `66d1682` (mid-demo Stop re-deals so a demo-touched board can never be played or
scored; per-column tableau fan compression against measured board height), then the loop's own
fix commits `0894907` (round 1) and `101beb5` (round 2).

## Why it stopped

Round 2 closed the round-1 major (the same demo-Stop exploit was live in the web prototype)
and introduced no new blockers/majors. The convergence condition — no open or newly-introduced
blockers/majors — fired.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 1 | 4 | 2 | 4 | 0 | -2 | continue |
| 2 | 0 | 0 | 4 | 3 | 2 | 0 | +1 | converged |

(Seed = round 0: 1 major + 3 minors against `66d1682`. The round-1 "new major" was the web
parity gap, not a reopen; nothing reopened in either round.)

## Closed along the way

- **Seed major** — iOS `finishDemo()` unlocked input without verifying the board was actually
  complete, and `applyDemoToken` applied tokens blind (a bad `C` token destroyed a card; a
  desync could trap on `removeLast()`). The "demo boards are never playable" guarantee rested
  on the bundled solutions JSON being perfect. Now: `finishDemo()` only unlocks on
  `boardComplete`, otherwise it re-deals; every token is validated and a failed token aborts
  the demo to a re-deal. (Reviewer independently simulated all 922 baked lines — none actually
  misbehave today; the fix makes the invariant code-enforced instead of data-dependent.)
- **Round-1 major** — the exact original exploit (Stop mid-demo, finish by hand, bank a win +
  best time) was still live in the **web prototype**. Web now mirrors iOS: Stop/Done re-deal,
  `finishDemo` guards completion, token applier validated, and a cross-copy parity test pins
  the wiring on both platforms.
- Minors: demo banner copy ("tap Done"), legibility floor constant corrected 0.42 → 0.53
  (SF-ascent derivation, verified against CardView), portrait shrunk-tableau centering,
  transient zero-height layout pass no longer collapses card size.
- Wontfix (recorded): `showSolution`/`playChallenge` silently discard an in-progress casual
  game — pre-existing, out of scope; filed as backlog item **DV-1** with a concrete fix shape.

## Open findings (all minor)

- **partial** `test/ios-parity.test.mjs:f-token-field-pin-loosened` — the re-added pin
  `let col = n(1)` is an unanchored substring that also matches case `C`, so mutating only
  case `F` to `n(2)` stays green. Pin the contiguous case body instead (reviewer supplied the
  exact normalized snippet).
- **open** `test/ios-parity.test.mjs:ios-demo-exit-guards-unpinned` — the new cross-copy test
  pins the three web guards but not the iOS `finishDemo` `boardComplete` guard (the word
  appears only in a comment); drift protection is currently one-directional.
- **open** `layout/ContentView.swift:tableau-centering-misaligns-unshrunk` — the unconditional
  `.frame(maxWidth: .infinity)` centres the *non*-shrunk tableau too, offsetting it ~3–3.5pt
  from the full-width upper row on 375/390pt devices. Fix: center only when shrunk.
- **partial** `layout/ContentView.swift:tableau-shrink-detaches-from-upper-row` — the shrink
  latch is sound (monotone, written only in the `moveCount` onChange, reset exactly at fresh
  deal), but each *new* tallest-column maximum still rescales all 52 cards, the 0.53 floor
  lowered the first trigger to ~13 cards on a 4.7" phone, and the shrunk state renders two
  card sizes at once (upper row vs tableau). Reviewer explicitly offered to flip this to
  wontfix if the trade is argued as deliberate — it is a design call for the human.

## Disputed items

None — no finding ended in `disputed`; the one declined finding (DV-1) was accepted by the
reviewer as a justified wontfix with a backlog entry.

## HUMAN SKIM LIST — read these diffs

1. **`0894907` — Game.swift `finishDemo`/`applyDemoToken` rewrite.** The demo-integrity
   invariant now lives here: unlock-only-on-`boardComplete` plus a validating token applier
   that aborts to `restartDeal()`. Look here because both agents agreed this is *the* guard —
   if its logic is subtly wrong (e.g. a path that re-deals when it shouldn't, eating a
   legitimate demo), nothing else catches it.
2. **`101beb5` — index.html demo Stop/Done + `applyDemoToken` guards.** A hand-mirrored port
   of the Swift logic into the web prototype's inline script. Same-family agents porting their
   own fix is exactly where a shared blind spot would land; the parity test pins text, not
   behavior.
3. **`101beb5`/`0894907` — ContentView.swift `tableauArea` shrink path + `shrinkLatchCount`.**
   New @State driving whole-board card size from a `moveCount` onChange. Look here because
   layout/@State feedback loops and the two-card-sizes-on-screen trade are visual judgments a
   reviewer can only partially verify by reading (`swiftc -parse` passed; no simulator
   screenshot was taken this loop).
4. **`66d1682` — the original per-column fan compression + portrait GeometryReader swap.** It
   replaced the portrait Spacer with a greedy GeometryReader; drop zones, zIndex and
   matchedGeometryEffect were reasoned about, not exercised on screen.
5. **`101beb5` — tests/ios-parity.test.mjs re-pins.** Twice now a re-pin shipped weaker than
   claimed (the F-token substring; the unpinned iOS guard). Skim the pinned snippets and ask
   "would this fail if the code regressed?"

**Verification run:** iOS `xcodebuild` BUILD SUCCEEDED each round; `npm test` 68/68 (one test
added); all 922 baked solution lines replayed clean through both the iOS-semantics and the new
guarded web applier; web Undo second-door checked closed (demo never snapshots history).
**Not run:** any simulator/on-screen check of the new portrait layout — the next qa-loop round
should re-verify TC-2.3 (tall column) and the demo WF-6 cases on screen.
