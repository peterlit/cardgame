# Review-loop final report — App Store shipping-prep pass (web + iOS)

**Result: CONVERGED** (round 2 of a 5-round budget). 0 open blockers/majors/minors.

Scope: commit `5e5384d` — the shipping-readiness pass (release HUD off, About/copyright screen, iOS
landscape, +12 regression tests). Loop-start `5e5384d`; fixes in `dffd216` (round 1) and `7febbc3`
(round 2). Rollback point: tag `pre-ship-prep`.

## Trend

| Round | Blockers | Majors | Minors | Closed | New | Reopened | Net | Decision |
|-------|----------|--------|--------|--------|-----|----------|-----|----------|
| 1 | 0 | 1 | 3 | 0 | 4 | 0 | -4 | continue |
| 2 | 0 | 0 | 0 | 5 | 1 | 0 | +4 | converged |

Round-1 seed filed a major + 3 minors; the fix retired the major and 2 minors but the checker-pin fix
was only partial and the no-scroll landscape fix introduced a new minor. Round 2 closed both.

## What the review caught — this earned its keep

The landscape work was the risk area (no on-device verification — the simulator was wedged all
session), and the loop caught two real problems there plus two weak tests:

- **F1 [major] — landscape ScrollView vs. card drag.** The first landscape implementation wrapped
  the board in a `ScrollView`, whose pan gesture fights every card's `DragGesture(minimumDistance:0)`
  — risking either un-scrollable content or stuck/hijacked drags, unverifiable without a device.
  **Fixed** by dropping the ScrollView entirely and instead shrinking the cards to fit the landscape
  height (`max(32, min(widthCardW, heightCardW))`): landscape now uses the *exact same* non-scrolling
  drag/coordinate mechanics as the well-tested portrait layout — the interaction risk is retired by
  construction, not by tuning.
- **F5 [minor, introduced by the F1 fix] — long-column clipping in landscape.** No-scroll means a
  very long tableau column (~12+ cards) on a short landscape viewport can push its bottom cards
  off-screen. **Mitigated** by compressing the landscape fan (overlap 0.30 vs portrait 0.40); the
  residual (extreme columns on small phones) is an accepted, documented known-minor — v1 landscape is
  portrait-primary and this needs on-device tuning / a future side-by-side landscape layout.
- **F2 [minor]** — the extracted `boardStack` shifted portrait foundations by a few px; fixed by
  keeping portrait on the exact original inline layout (byte-identical), `boardStack` landscape-only.
- **F3 [minor]** — the baked-solution test's sanity bounds (`>= seeds-2`, `> 0`) let absent lines
  slip; tightened to exact (`goldChecked == 366`, `silverChecked == computed 190`).
- **F4 [minor]** — 3 of the new Swift checker drift-guards pinned lines that also exist in the
  `objViolated` HUD mirror, so they didn't actually guard the authoritative checker; **fixed** by
  pinning the distinctive `return false` violation branches (verified 1 occurrence each).

Parts verified clean throughout: the release-HUD flip (only two references), the About screen
(version read + fallbacks + consistent © entity), and — for landscape — the fact that
`.coordinateSpace("board")` sits *outside* any scroll and the drag/drop-zone machinery is untouched.

## Verification note

Full suite **67/67 green** (was 55). iOS **compiles** (`BUILD SUCCEEDED`) at every step. The iOS
**simulator was unavailable all session** (host CoreSimulator wedged — SBMainWorkspace launch denial
even on a fresh clean sim while Safari launched; a parallel session runs its own sim, so a
shared-service restart was avoided). Landscape therefore has **no on-device visual check** — but the
converged design deliberately makes landscape share portrait's proven mechanics, so the outstanding
risk is cosmetic (card size / extreme-column clipping), not broken interaction.

## HUMAN SKIM LIST — read these, the loop can't self-check

1. **Landscape, on a real device (`ContentView.swift`, commits `dffd216`/`7febbc3`).** Rotate on a
   few sizes and confirm: cards are tappable, drag-and-drop and drop-targeting work exactly as
   portrait, and long columns are acceptable (a 12+ card column on a small phone is the worst case —
   see F5). If clipping is a problem in practice, the follow-up is a side-by-side landscape layout
   (free cells + foundations beside the tableau), not a ScrollView.
2. **The iOS parity drift guards (`tests/ios-parity.test.mjs`).** These are now the primary defense
   against web↔iOS divergence (there's no XCTest target). They pin *substrings*; if you refactor the
   Swift port's canonical logic, update the pins deliberately (that's the tripwire working).
3. **Owner action items** in `docs/shipping-readiness.md` (Support/Privacy URLs, contact email, real
   iOS 17/18 device test) — required for submission, external to this repo.

## Verdict
Converged: the shipping pass landed its one code blocker fix plus the About screen and a
correct-by-construction landscape layout, backed by +12 regression tests (incl. the first-ever iOS
drift guards). The loop caught a real landscape gesture conflict and two weak tests. Remaining work is
external (owner URLs/testing) and one documented landscape known-minor, all tracked in
`docs/shipping-readiness.md`.
