# Causeway — reviewer-agent evaluation examples

Five real commits from this repository, each with a **verified answer key**: the defect(s) the diff
actually contained, established by later commits in the same history that fixed or reverted them
(or, in one case, by code that is still wrong at that commit). Use them to score AI reviewer agents
across models: how much real signal each finds, how much noise it invents, and whether it reaches
the right ship / don't-ship verdict.

Every claim in the answer keys below was re-derived from the diffs, not taken from commit prose.
Where an answer key rests on a later commit, that commit is cited.

---

## How to run a case

The later commits **are the answer key**, so the reviewer must not see them. Make a throwaway clone
whose history ends at the case commit:

```bash
git clone --no-local . /tmp/rev-case-a && git -C /tmp/rev-case-a reset --hard b50087a
```

Then give the agent the standard prompt: *"Review the most recent commit (`git show HEAD`) as a
skeptical reviewer. Report findings with severity, file:line, and a concrete failing scenario."*

Two deliberate choices:

- **The commit message is part of the input.** These messages make verification claims ("Verified on
  web and on device", "67 tests green"). Case D turns on one of those claims being false, so
  stripping messages would remove real signal. Score message-credulity explicitly.
- **The parent is the base.** `git show <sha>` is the review unit. For Case D, exclude the generated
  JSON (`data/*.json`, `ios/Causeway/Causeway/*.json`) — 2 MB of regenerated deal data drowns a
  113-line code diff and tests context management rather than review skill. Say so in the prompt.

## Repo context to give the reviewer

Without these facts, several findings are unreachable, and withholding them tests memory rather than
review ability:

1. **Three mirrors of the same canonical logic.** `tests/*.mjs` is canonical and Node-tested,
   `index.html` is the web app, and `ios/Causeway/Causeway/**.swift` is a hand-port. Web↔iOS parity
   is pinned by string-matching drift guards in `tests/ios-parity.test.mjs`.
2. **No Swift test target** at these commits (a UI test bundle only arrives later, at `68506c5`).
   The Swift side is covered by drift pins and by hand — "67 tests green" says nothing about Swift
   behaviour.
3. **Stats are persisted and irreplaceable.** Daily tier records and solved deals live in
   UserDefaults / localStorage; there is no server copy. Silent corruption or silent dropping is
   unrecoverable for the player.
4. **Product values.** Causeway is a full-information skill game with no hidden state and no luck.
   Recorded solve time, move count, and daily tier are the competitive metrics; anything that lets a
   player inflate them is a correctness problem, not a UX preference.

## Shared scoring rubric

| Axis | Points | Notes |
|---|---|---|
| P1 findings (each) | +3 | Blocker/major in the key. Requires the right *mechanism*, not just the right file. |
| P2 findings (each) | +1 | Minor/legitimate secondary in the key. |
| Novel verified defect | +3 / +1 | Credit at the matching severity **after you verify it**. Do not penalize a real bug just because it is not in the key. |
| Correct overall verdict | +2 | Ship / ship-with-fixes / don't-ship, consistent with what it found. |
| Evidence quality | +0..2 | Cites file:line and gives a concrete failing input or state; 0 for assertion-only findings. |
| False positive (each) | −2 | Claims a defect that provably is not one. Includes contradicting the diff's own code. |
| Style noise (each) | −0.5 | Naming, formatting, "consider extracting" with no defect behind it. |
| Missed P1 | −2 | Applied on top of the missing +3. |

A finding "hits" a key item if it names the same mechanism and would lead a competent implementer to
the same fix. "The HUD logic looks risky" does not hit "suit-sprint is secured one suit too early".

---

## Case A — `b50087a` · on-track ✓ in the live objectives HUD

|  |  |
|---|---|
| Head / base | `b50087a` / `a89aefe` |
| Size | 5 files, +86 −15 (2 code files + web + docs) |
| Difficulty | **Medium** — domain reasoning inside a small, self-contained diff |
| Discriminates | Can the model reason about *game rules*, not just code shape? |

**What it does.** Adds `objSecured(obj, up, down, t)` in both `index.html` and
`ios/Causeway/Causeway/Model/Daily.swift`, so the live HUD shows a green ✓ for a Silver/Gold
objective that is already *locked in* — guaranteed to be earned on any completion of the deal —
instead of waiting for the win overlay. Also moves the calendar's Flawless 🌟 out of a corner overlay
into the day cell's marker slot.

Foundation encoding: `up[s]` is the highest rank sent home from the Ace end (0 = empty), `down[s]` is
the lowest rank sent home from the King end (14 = empty), and a suit is complete when
`down[s] == up[s] + 1`.

### Answer key

**P1 — `suit-sprint` is marked secured one suit too early.**
`case 'suit-sprint': return [0,1,2,3].some(s => down[s] === up[s]+1)` (and the Swift
`(0..<4).contains { ... }`) treats *one* completed suit as a guarantee. The objective requires
finishing each suit before starting the next, so with one suit home the player can still interleave
the remaining three and fail it. The ✓ is a false promise about the player's tier — in a game whose
whole appeal is that the information is complete. Correct threshold is **≥3 suits home**: with one
suit left, no "started a new suit while another was incomplete" event remains possible.
*Evidence: fixed in `f96c06b` on both platforms.*

**P2 — the flawless star has no reserved height (iOS).**
`Text("🌟").font(.system(size: 11))` replaces an `HStack { ... }.frame(height: 6)` dots row inside the
same `VStack`. The star's intrinsic height differs from 6, so the date number sits at a different
`y` on flawless vs. non-flawless cells and the numbers jitter across the month grid.
*Evidence: fixed in `18e49fd` by adding `.frame(height: 6)`.*

**P2 — the two platforms are not verified equally.** The diff lands parity-critical logic in Swift
where CI only string-pins it; a reviewer that notes the iOS `objSecured` has no executable coverage,
and that the web/iOS bodies must be checked line-for-line, earns credit.

### False-positive traps

- **`kings-first` / `suits-top-down` / `down-openers-20` all returning `down.every(d => d <= 13)`.**
  Looks like copy-paste; is correct. `down` starts at 14, so `<= 13` means that suit's King is down,
  and all three objectives are secured by exactly that state (their differing *violation* conditions
  are already handled by the `objViolated` early-out). Flagging this as a bug is a −2.
- **"`objSecured` ignores `t`".** It does not — the first line is `if objViolated(obj, t)`.
- **"Budget objectives should also show ✓".** They must not; moves/undo/free-cell budgets can still
  be blown, which is exactly why `default: return false` is right.
- **Missing tests for `objSecured`.** Legitimate as a style/coverage note (+0), but it is a UI-only
  hint that cannot change a recorded score — a reviewer that calls its absence a blocker is
  mis-severity, not a find.

### Expected verdict

Ship-with-fixes. One correctness bug in user-visible scoring feedback, one cosmetic layout bug,
neither risking persisted state.

---

## Case B — `ebd31df` · local Export / Import of stats

|  |  |
|---|---|
| Head / base | `ebd31df` / `2f3dbcc` |
| Size | 4 files, +148 (one new file) |
| Difficulty | **Medium** — trust-boundary reasoning, with an over-claim trap |
| Discriminates | Does it find the real data-integrity hole without inventing a security scare? |

**What it does.** Adds `StatsBackup` (versioned JSON snapshot of the daily record map and the solved
deals map), `DailyStore.merge` / `WinStore.merge` (non-destructive, add-or-keep-better), and an
Export/Import section in `DailyView` using `.fileExporter` / `.fileImporter`. The UI promises:
*"Importing merges — it never erases progress."*

### Answer key

**P1 — imported values are structurally validated but never range- or sanity-checked.**
`StatsBackup.decode` only checks the `format` marker; `dailyInts` / `winsInts` accept any key that
parses as an `Int`. A hand-edited or corrupt-but-well-formed file therefore merges straight into
permanent storage:
- unbounded keys inject phantom days (`-3`, `999999999`) and phantom solved deals, inflating streaks
  and the Wins ranges with days and deals that do not exist;
- because `WinStore.merge` keeps `min(moves)` and `min(secs)`, a record with `moves: 0, secs: 0`
  poisons a genuine best score **irreversibly** — merge never deletes, so there is no path back.

The reviewer should tie this to the UI's own promise: "never erases progress" is false once a best
score can be silently overwritten with a fabricated one.
*Evidence: `0874c5c` adds exactly this sanitization (key clamping + `moves > 0 && secs > 0`) and
reports skipped entries.*

**P2 — `WinStore.merge` fabricates a record that never happened.**
`WinRecord(moves: min(prev.moves, rec.moves), secs: min(prev.secs, rec.secs), date: max(...))`
composes the three fields from potentially *different* solves, so a player can end up with a "best"
pairing a move count and a time that never occurred together. Defensible as a deliberate
per-field-best, but it is undocumented and unremarked. Credit a reviewer that spots the composition
and asks which semantics were intended.

**P2 — the confirmation line reports file counts, not merged counts.**
`"merged \(backup.daily.count) days"` prints what was in the file, so once anything is skipped or
de-duplicated the message overstates what happened. (`0874c5c` also switches this to actual counts.)

**P2 — `encoded()` swallows encoding failure.** `(try? enc.encode(self)) ?? Data()` exports a
zero-byte `.json` on failure while the completion handler still reports "Stats exported." A silent
empty backup is worse than a visible error for a feature whose purpose is a safety net.

### False-positive traps

- **"Arbitrary file read / path traversal / remote code execution."** The input is a user-chosen local
  file inside a security-scoped resource, decoded by `JSONDecoder` into fixed `Codable` structs.
  There is no injection surface. Severity inflation here is a −2; the real risk is *self-inflicted
  data corruption*, not attacker compromise.
- **"`startAccessingSecurityScopedResource` result is ignored."** It is captured in `scoped` and
  balanced in a `defer`.
- **"Merge can erase progress."** As written, both merges only add or keep-better; the hole is
  poisoning a *value*, not deletion. A reviewer claiming deletion has the wrong mechanism and does
  not hit the P1.

### Expected verdict

Ship-with-fixes, gated on validating input before it reaches permanent storage.

---

## Case C — `5b237b4` · four QA fixes, including "pause the clock in sheets"

|  |  |
|---|---|
| Head / base | `5b237b4` / `c20a998` |
| Size | 4 files, +43 −9 |
| Difficulty | **Hard** — the defect is in the *product decision*, not the code |
| Discriminates | Does the model review intent, or only implementation? |

**What it does.** Four unrelated QA fixes: `onCancellation` handlers for the file dialogs, singular
grammar via a `pl()` helper, demo "Done" re-dealing the seed, and — the one that matters —
`Game.suspendClockForSheet()` / `resumeClockAfterSheet()`, wired via `.onChange` on the three sheet
bindings so the solve clock stops while the Daily, Wins, or How-to-play sheet is open.

The clock-pause code is *correct*: it guards on `clock.isRunning`, latches
`clockSuspendedForSheet`, and resumes only a started, un-won game. A reviewer looking only for bugs
finds nothing.

### Answer key

**P1 — the clock pause turns "How to play" into a pause button and corrupts the game's headline
metric.** The clock being paused is the clock that gets *recorded*. A player mid-solve can open How
to play, plan the rest of the deal against a frozen timer, close it, and execute — recording an
artificially fast daily best time. In a full-information skill game where solve time is the
competitive metric, that is strictly worse than the complaint it fixes (time spent reading a sheet
is self-inflicted and avoidable). The right shape is either continuous wall-clock timing, or
splitting displayed time from recorded time — not pausing the recorded clock.
*Evidence: reverted wholesale in `2796867`; the other three fixes were kept.*

**P2 — the demo "Done" → `restartDeal()` change is unremarked state churn.** "Done" now replaces the
board instead of exiting, so a player who was mid-demo on a deal they cared about loses the position
with no confirmation. (Later work introduces a `PendingAction` guard on exactly these
board-replacing routes, in `84a9e01`.)

**P2 — three `.onChange` handlers share one non-reentrant latch.** `clockSuspendedForSheet` is a
single `Bool`; overlapping or rapidly re-presented sheets can resume a clock that another sheet still
has open. Real, though secondary to the fact that the feature should not exist.

### False-positive traps

- **The `pl()` helper.** `"\(n) \(noun)\(n == 1 ? "" : "s")"` is fine for "day"/"deal"/"range".
  English-pluralization and localization lectures are style noise here — the app ships one locale and
  the strings are hard-coded three lines away.
- **"`onCancellation` overloads are iOS 17-only".** The project already targets iOS 17 (it uses the
  two-parameter `.onChange` closure signature in the same diff).
- **"Import failure message regressed".** It did not: cancel now routes to `onCancellation`, so the
  `guard` really does mean failure, which the diff's comment states.

### Expected verdict

**Don't ship the clock-pause; ship the other three.** A reviewer that approves the whole commit
because the code is clean fails this case even with a perfect nit list. This is the single best
discriminator in the set between models that review code and models that review *changes*.

---

## Case D — `6a49b75` · pre-epoch playtest sandbox (negative day indices)

|  |  |
|---|---|
| Head / base | `6a49b75` / `f62c3d2` |
| Size | 14 files, +3604 −766 total; **+113 −27 excluding generated JSON** |
| Difficulty | **Hard** — the defects are in files the diff does not touch |
| Discriminates | Does it hunt for code that depended on the invariant being widened? |

**What it does.** Widens two long-standing domains at once. Day indices, previously `0 ..< pool.count`,
gain negative values backed by a `preSeeds` array (day `-1` = `preSeeds[0]`). Deal seeds, previously
clamped to `maxSeed = 1_000_000`, gain a second ceiling `maxValidSeed = 4_294_967_295` because the
sandbox uses seeds above 10,000,000. It also fixes a pre-existing `LazyVGrid` id collision that hid
days 1–6 of every month on iOS.

Suggested review prompt: *"exclude the regenerated `data/*.json` and
`ios/Causeway/Causeway/*.json`; review the code diff."*

### Answer key

**P1 — the web `playChallenge` crashes on every sandbox day.** The guard was widened but the body was
not:

```js
function playChallenge(day){
  if(!dailyPool||!dailyRec(day)||day>todayIndex()) return;   // dailyRec() now admits day < 0
  stopDemo();
  deal(dailyPool[day].seed);                                  // dailyPool[-1] is undefined
```

`dailyPool` is still the `seeds` array, so for any negative day `dailyPool[day]` is `undefined` and
`.seed` throws a `TypeError`. Every sandbox day is selectable in the calendar and reachable from the
day card's Play button (`onclick="playChallenge(${day})"`), so the entire feature is dead on web
while working on iOS — the exact platform divergence the parity discipline exists to prevent. The
commit message says "Verified on web and on device." **Verified by inspection at that commit:
`data/daily-pool.json` there has 366 `seeds` and 7 `preSeeds`.** It was never fixed; the August-2026
recut later deleted the sandbox and made `dailyRec` return `null` for negative days.

**P1 — the import sanitizer now silently drops the app's own exports.**
`DailyView.importStats` (untouched by this diff) clamps daily keys to `0...todayIndex()+2` and win
seeds to `1...Game.maxSeed`. After this commit the app produces day records at negative indices and
wins on seeds above 10,000,000, so exporting and re-importing an untouched backup **discards** the
sandbox tier records and those wins — under a UI that promises "Importing merges — it never erases
progress." Widening a domain requires auditing every place that validated the old one.
*Evidence: filed as a blocker (`bug/WF-11`) and fixed in `84a9e01`, which widens the bounds to
`-preSeeds.count ... today+2` and `1 ... maxValidSeed` while keeping the poison guards.*

**P2 — `Game.deal` now clamps to `4_294_967_295` at *every* call site.** The typed Deal # entry
inherits the wider ceiling, so the "1–1,000,000" hint stops matching what the field accepts. The
enforcement belongs at the entry points, not in `deal`. (Fixed in `84a9e01` as `bug/WF-7`.)

**P2 — the mutable-sandbox claim is asserted, not enforced.** "rewriting it can never disturb a day
≥ 0" holds only because the RNG is seeded from `dayIndex + 1` and pool indices are disjoint. Nothing
in code or tests pins that; a reviewer that asks for a regression test on the frozen-history property
earns credit.

**P2 — credit for catching the false verification claim itself** — "Verified on web" is disproved by
the web code in the same diff.

### False-positive traps

- **`UInt32(truncatingIfNeeded: 0x9e37_79b9 ^ (dayIndex + 1))` for negative days.** Ugly, and it is
  *supposed* to be: the formula is explicitly frozen, and negative indices land in a disjoint region
  of it. Not a defect.
- **`preSeeds` being optional in `PoolFile`.** Correct and deliberate — a build without a sandbox
  decodes to `[]`.
- **The `LazyVGrid` id fix.** It is right (three sibling `ForEach` blocks sharing one identity space,
  prefixed string ids make the spaces disjoint). Calling it wrong is a −2.

### Expected verdict

Don't ship. Two blockers, one of which silently destroys player data.

---

## Case E — `8a6bcd6` · lifetime total per tier (near-clean control)

|  |  |
|---|---|
| Head / base | `8a6bcd6` / `d073347` |
| Size | 5 files, +12 −7 |
| Difficulty | **Control** — measures false-positive rate |
| Discriminates | Does the model stay quiet when the change is correct? |

**What it does.** Adds `total` (lifetime count of days holding a tier) to `streaks()` in all three
mirrors — `tests/daily.mjs` (canonical), `index.html`, and `Daily.swift`'s `StreakRun` — and renders
it between the tier label and "best N". Adds three assertions to `tests/daily.test.mjs` covering the
non-consecutive case that motivated the change.

### Answer key

**No correctness defects.** `days` is already the tier-filtered, sorted key list, so `days.length` is
exactly the lifetime count; the three mirrors change in lockstep; the `Streaks(...)` drift pin in
`tests/ios-parity.test.mjs` still passes; and the new behaviour is what the three added assertions
cover.

**P2 (the one real finding) — the streak card now shows three unlabelled numbers.** After this diff
each card renders icon / **24pt number** / tier name / "N total" / "best N". The headline is the only
figure on the sheet with no caption, and the word "streak" appears nowhere near it, so "🌟 1 / 2 total
/ best 1" reads as a puzzle. There is also no `accessibilityLabel`, so VoiceOver reads four
disconnected fragments per card.
*Evidence: filed as `ux/WF-5:streak-card-headline-unlabelled` and fixed in `84a9e01`, which moves the
tier name above the headline, adds a "day streak" caption, and adds an
`.accessibilityElement`/`accessibilityLabel` per card.*

**P2 — three text rows added to a fixed-width four-across card with no `lineLimit` /
`minimumScaleFactor`,** so larger Dynamic Type sizes will wrap or clip. (The same later commit adds
both.)

### Scoring note

This case is scored **inverted**: the win condition is a short report — the labeling/a11y observation,
optionally the Dynamic Type one, and an explicit "the logic is correct and covered". Any claimed
*correctness* defect here is a false positive at −2. Common inventions to watch for: "`total` should
exclude future days" (it cannot — records only exist for played days), "`StreakRun` is not
`Codable`" (it is never persisted), "the web and iOS totals can diverge" (both compute `days.length`
over the same filtered list, and the canonical `tests/daily.mjs` copy is asserted).

---

## Using the set

| Case | Commit | Difficulty | P1s | Primarily tests |
|---|---|---|---|---|
| A | `b50087a` | Medium | 1 | Domain reasoning inside a small diff |
| B | `ebd31df` | Medium | 1 | Trust boundaries, without severity inflation |
| C | `5b237b4` | Hard | 1 | Reviewing intent when the code is clean |
| D | `6a49b75` | Hard | 2 | Cross-file invariants; auditing verification claims |
| E | `8a6bcd6` | Control | 0 | Restraint; false-positive rate |

Run all five per model. The informative pairs:

- **C vs. E** — a model that flags the clock-pause exploit *and* stays quiet on the streak totals is
  reviewing changes. One that misses C and invents defects in E is pattern-matching on diff size.
- **D alone** — the only case where the answer requires reading files the diff does not touch. Models
  that review the patch in isolation cannot pass it, however careful they are.
- **A vs. B** — both reward domain grounding, but B additionally penalizes the reflex to reach for
  security language when the real risk is self-inflicted corruption.

Two grading rules that matter more than the point weights:

1. **Verify novel findings before scoring them.** These commits are real and not exhaustively
   audited; a model may surface something genuinely wrong that is not in a key. Check it, then credit
   it. Penalizing correct findings for being unlisted trains exactly the wrong behaviour.
2. **Score mechanism, not vocabulary.** Several keys have a shallow near-miss that reads similarly
   (Case B: "merge can erase progress"; Case A: "the HUD may show a wrong tier"). Require the model
   to state the failing state or input.
