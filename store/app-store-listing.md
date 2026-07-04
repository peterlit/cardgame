# App Store listing — Causeway (draft)

Copy-paste into App Store Connect. Character limits noted in (parens); stay under them.

> ⚠️ **Early alpha.** This build has only been tested on **iPhone 13 Pro** and supports
> **portrait orientation only**. The warning below is repeated in the user-facing copy.

---

## Name (30)
```
Causeway Solitaire
```
("Causeway" alone may be taken — check availability; adjust if needed.)

## Subtitle (30)
```
Build each suit from both ends
```

## Promotional text (170 — editable later without review)
```
Early alpha! A new full-information solitaire — build each suit from both ends. Pure skill, no luck. Currently iPhone-only, portrait. Feedback very welcome!
```

## Keywords (100, comma-separated, no spaces after commas)
```
solitaire,freecell,patience,card game,puzzle,brain,skill,strategy,cards,offline,klondike
```

## Description
```
EARLY ALPHA — please read

Causeway is a brand-new game in active development. This release has only been tested on
iPhone 13 Pro and supports portrait orientation only. You may hit rough edges, and it may
not look right on other devices yet. Feedback is very welcome — thank you for trying it!

----------

Causeway is an original, full-information solitaire — no hidden cards and no luck, just skill.

THE TWIST: you build each suit from BOTH ends. Every suit has two foundations — an "up"
pile (A, 2, 3 ...) and a "down" pile (K, Q, J ...) — that close toward each other and meet
in the middle. You choose where each suit splits, but the two halves can never cross, so
the middle cards have no home until the ends climb to reach them. That's the puzzle.

If you like FreeCell, you'll feel right at home: everything is face-up, with free cells, a
two-way alternating-colour tableau, and group moves.

FEATURES
- Pure skill — every card is visible, no luck involved
- Build each suit from both ends (dual foundations)
- 3 free cells and two-way tableau building
- Smart double-tap, undo, and safe auto-play
- Numbered deals (1-1,000,000) — replay or share any exact deal
- Tracks the deals you've solved
- Fully offline: no accounts, no ads, no data collected
```

## Support URL (required)
Host a simple page (a GitHub repo README works) and put its URL here, e.g.:
```
https://github.com/<your-username>/causeway
```
Or a support email page. App Review will reject a missing/broken support URL.

## Marketing URL (optional)
Leave blank or use the same as Support URL.

## Privacy Policy URL (required)
Host `privacy-policy.md` (see this folder) — GitHub Pages is easy — and paste the URL, e.g.:
```
https://<your-username>.github.io/causeway/privacy
```

---

## Category & rating
- **Primary category:** Games → Card
- **Secondary (optional):** Games → Board or Puzzle
- **Age rating:** 4+ (no objectionable content)

## App Privacy questionnaire (answers)
- **Data collection:** *Data Not Collected.* The app collects no data of any kind.
- **Tracking:** No.
- This matches the bundled `PrivacyInfo.xcprivacy` (no tracking, no collected data;
  UserDefaults used only for local win history).

## Export compliance
- Uses no encryption beyond Apple's standard OS — answer **"No"** to the encryption
  question. `ITSAppUsesNonExemptEncryption = NO` is already set in the build settings, so
  uploads won't prompt.

## Screenshots (required)
Capture in **portrait** from the iPhone 13 Pro (or the 6.9" simulator) — required set is
the largest iPhone size; reuse for others. Suggested shots:
1. A fresh deal (full board)
2. Mid-game with a suit closing from both ends
3. The win screen
4. The Wins screen (ranges / deal entry)

## Review notes (paste into "Notes for the Reviewer")
```
This is an early alpha. It is designed and tested for iPhone in portrait only. No login,
no network, no data collection. Everything is playable from a fresh launch.
```

## Recommended before submitting (alpha)
- **Device family is now iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`) to match the tested
  scope — no iPad screenshots needed.
- Set a real **Version** (1.0) and **Build** (1) in the target before archiving.
- The committed `DEVELOPMENT_TEAM` is a personal Team ID; remove it before making the repo
  public (see BACKLOG.md).
