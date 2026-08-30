// DRIFT GUARD: the iOS Swift app re-implements the shared JS core (deal RNG, calendar, daily
// generator, objective checkers, streaks, demo playback). Nothing else in the suite reads the Swift,
// so web and iOS could silently diverge — a wrong deal order or off-by-one calendar would make the
// shipping app produce different deals / daily challenges than the canonical (Node-tested) logic.
//
// These guards pin the DISTINCTIVE Swift bodies of the parity-critical logic. An edit to the Swift
// port that changes any of them trips CI, forcing a re-verification against tests/daily.mjs /
// tests/engine.mjs. Combined with the existing web drift guards (which pin index.html), both mirrors
// of each canonical block are now pinned. This is the cheap fallback for the absent XCTest target.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const norm = s => s.replace(/\s+/g, ' ').trim();
const IOS = join(REPO, 'ios/Causeway/Causeway');
const read = p => norm(readFileSync(join(IOS, p), 'utf8'));

function pin(file, label, snippets) {
  test(`iOS ${label} matches canonical logic (no web↔iOS drift)`, () => {
    const src = read(file);
    for (const s of snippets) {
      assert.ok(src.includes(norm(s)), `${file}: iOS ${label} drifted / missing: ${s.slice(0, 60)}...`);
    }
  });
}

// ---- deal RNG: the whole web↔iOS parity contract rests on Swift reproducing the golden id-orders ----
pin('Model/Cards.swift', 'mulberry32 PRNG', [
  'a = a &+ 0x6D2B79F5',
  'var t = (a ^ (a >> 15)) &* (a | 1)',
  't = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t',
  'Int(next() * Double(bound))',                 // .int(bound) == Math.floor(rng()*bound)
]);
pin('Model/Game.swift', 'deal seed + shuffle', [
  'Mulberry32(UInt32(truncatingIfNeeded: self.seed))',
  'let n = c < 4 ? 7 : 6',                        // 7,7,7,7,6,6,6,6 layout
]);

// ---- calendar + daily generator (frozen; a drift shifts every day's challenge) ----
pin('Model/Daily.swift', 'daysFromCivil (floor-division)', [
  'let era = floorDiv(y >= 0 ? y : y - 399, 400)',
  'return era * 146097 + doe - 719468',
]);
pin('Model/Daily.swift', 'the day -> challenge lookup (no runtime RNG; the pool names both tiers)', [
  'guard dayIndex >= 0, dayIndex < pool.count else { return nil }',
  'silver: makeObjective(rec.silver), gold: makeObjective(rec.gold))',
  'let EPOCH_DAYS = daysFromCivil(2026, 8, 1)',
]);

// ---- objective checkers, grades, labels (every family is parameterised) ----
pin('Model/Daily.swift', 'parameterised objective checkers', [
  'case "cells-le":       return t.won && t.cellUses <= (p.N ?? 0)',
  'case "max-run":        return t.won && t.maxRunMoved <= (p.N ?? 1)',
  'case "big-move":       return t.won && t.maxRunMoved >= (p.N ?? 5)',
  'case "split-at":       return t.won && upDown(t).u.allSatisfy { $0 == (p.R ?? 7) }',
  'return (p.end == "up" ? x.u : x.d).allSatisfy { $0 >= (p.min ?? 0) }',
  'case "suit-balance":   return t.won && maxSpread(t) <= (p.N ?? 13)',
]);
pin('Model/Daily.swift', 'ordering checkers (strict prefix, loose prefix, per-suit)', [
  // endsFirstOK: the STRICT prefix — nothing else home until every suit holds A..up and K..down
  `for e in t.foundationOrder {
        if met() { break }
        let required = e.end == "up" ? e.rank <= upN : e.rank >= downN
        if !required { return false }`,
  // beforeAceOK: the LOOSE prefix — that rank down before ANY Ace goes up
  `if e.rank == r && e.end == "down" { n += 1 }
        else if e.rank == 1 && e.end == "up" && n < 4 { return false }`,
  // suitTopFirstOK: the PER-SUIT version
  `if e.rank == r && e.end == "down" { down[e.suit] = true }
        else if e.rank == 1 && e.end == "up" && !down[e.suit] { return false }`,
  'for T in 0..<4 where T != S && started[T] && home[T] < 13 { return false }',   // suitSprintOK
  'for e in t.foundationOrder where e.rank == rank && !seen[e.suit] {',           // rushCompleted
]);
pin('Model/Daily.swift', 'grades and labels derive from the parameter', [
  'case "cells-le":     return (p.N ?? 0) == 0 ? .gold : .silver',
  'case "end-bias":     return (p.min ?? 0) >= 10 ? .gold : .silver',
  'case "suit-balance": return (p.N ?? 13) <= 3 ? .gold : .silver',
  'return "Split every suit exactly at the \\(rankName(r)) — A-\\(rankShort(r)) up, \\(rankShort(r + 1))-K down"',
  'return "Send \\(parts.joined(separator: ", plus ")) home before any other card"',
  'case "rank-rush":      return "Get all four \\(rankPlural(p.rank ?? 1)) home within your first \\(p.N ?? 0) moves"',
]);
pin('Model/Daily.swift', 'mergeTiers + streaks (Flawless, Same-day)', [
  'bronze: p.bronze || attempt.bronze,',
  'flawless: p.flawless || attempt.flawless,',
  'onTime: p.onTime || attempt.onTime,',
  'return Streaks(play: tierRun { $0.bronze }, onTime: tierRun { $0.onTime },',
]);

// ---- ⏰ same-day: the date rule and its next-day grace must match tests/daily.mjs isOnTime() ----
pin('Model/Daily.swift', 'isOnTime (same-day recognition)', [
  'if winDay == day { return true }',
  'return attemptStartDay == day && winDay == day + 1',
  'onTime: bronze && onTime)',
]);
// `challengeStartDay = todayIndex()` alone appears TWICE (restartDeal + playChallenge), so a bare
// substring stays green if either call site is deleted — killing the next-day grace for every fresh
// attempt (or every retry) while the web keeps it. Pin CONTIGUOUS blocks that name their own call
// site, and count the occurrences so neither can vanish.
pin('Model/Game.swift', 'same-day attempt bookkeeping', [
  // playChallenge: a fresh attempt stamps TODAY (no semicolons — restartDeal's one-liner differs).
  `challengeDay = day
        challengeStartDay = todayIndex()
        persist()`,
  // restartDeal: a retry is a NEW attempt, re-stamped from today.
  'if let day = day { challengeDay = day; challengeStartDay = todayIndex(); persist() }',
  // persist: the start day is actually WRITTEN to the save (dropping it would make every relaunch
  // look like a pre-⏰ save).
  'challengeDay: challengeDay, challengeStartDay: challengeStartDay, telem: telem,',
  // restore: an older save without a start day stays nil — never guessed from the challenge day
  // (`?? s.challengeDay`), which would hand the next-day grace to a backfilled attempt that cannot
  // prove it. Pinned with the following line so re-adding a fallback trips the guard.
  `challengeStartDay = s.challengeStartDay
        telem = s.telem ?? Telemetry()`,
  // ...and the recorded start day is what recordChallengeResult judges the win by.
  'onTime: isOnTime(challengeDay: day, winDay: todayIndex(),',
  'attemptStartDay: challengeStartDay))',
]);
test('iOS stamps the ⏰ start day at both attempt entry points (no web↔iOS drift)', () => {
  const src = read('Model/Game.swift');
  const n = src.split(norm('challengeStartDay = todayIndex()')).length - 1;
  assert.equal(n, 2, `Game.swift: expected challengeStartDay = todayIndex() at BOTH playChallenge and restartDeal, found ${n}`);
});

// The wiring above only computes ⏰; these pin the SURFACES that show it. Without them the whole
// award is deletable green on the platform that ships: the calendar pip, the day-card line, the
// streaks-strip column and the win-overlay line can each be removed from the Swift and the suite
// stays quiet, while the web twins of all four ARE pinned in tests/daily.test.mjs.
pin('Views/DailyView.swift', '⏰ award surfaces (streaks strip, day-card line, calendar pip)', [
  // the Same-day column of the streaks strip, in the canonical order the web renders.
  '[("🔥", "Play", s.play), ("⏰", "Same-day", s.onTime), ("🥈", "Silver", s.silver),',
  // the day card's ⏰ line: earned on the day...
  `if rec?.onTime == true {
            Text("⏰ Cleared on the day")`,
  // ...and today's invitation, which names the running streak.
  'Text(run.current > 0 ? "⏰ Win today to keep your \\(run.current)-day same-day streak"',
  // ...the LIVE next-day grace variant (yesterday's attempt still in progress), pinned WITH the
  // condition that gates it so it cannot be constant-folded into always/never, and the past-day
  // explainer it replaces. Web twin: `graceLive` in index.html's renderDailyCard.
  'let graceLive = game.challengeDay == day && game.challengeStartDay == day && ti == day + 1',
  `} else if graceLive {
            Text("⏰ Resume your attempt today and it still counts")`,
  'Text("⏰ Same-day is earned on the day itself")',
  // the calendar pip (paired with the shape it draws, so a constant condition can't satisfy it).
  `if rec?.onTime == true {
                Circle().fill(Theme.gold).frame(width: 5, height: 5)`,
]);
pin('Views/ContentView.swift', 'win-overlay ⏰ line', [
  // The whole ternary, not just `d.onTime`: a pin on the bare read stays green if the value is
  // ANDed with a constant, and the streak number must come from streaks(...).onTime.current.
  `let onTime = d.onTime
            ? " ⏰ On time — \\(streaks(game.dailyStore.days, todayIndex()).onTime.current)-day same-day streak."
            : ""`,
  // ...and it must actually be appended to whichever tier line this attempt earned.
  'if d.flawless { return "🌟 Flawless! 🥉🥈🥇 all in a single run." + onTime }',
  'return "Daily challenge: \\(earned.isEmpty ? "—" : earned) earned." + onTime',
]);

// ---- once-only win record (guards the auto-finish deferred-win "record exactly once" invariant) ----
pin('Model/Game.swift', 'recordWin once-only gate', [
  'guard !winRecorded else { return }',
]);

// ---- "Show me how to win" token applier: MUST match the web + solver token semantics ----
// F = column-top → foundation; G = free cell → foundation; end 0=up / 1=down; T/C/X per rules.mjs.
// (The iOS copy validates each token and returns false on a malformed/inapplicable one — pure
// defense against bad baked data; the applied semantics below are identical to web/rules.mjs.)
pin('Model/Game.swift', 'applyDemoToken token format', [
  // CONTIGUOUS case bodies, not bare fragments: `let col = n(1)` alone appears in both F and
  // C, so an unanchored pin would stay green if only one of them drifted.
  `case "F":
      let col = n(1)
      guard col >= 0, col < tableau.count, !tableau[col].isEmpty else { return false }
      let c = tableau[col].removeLast()
      if n(2) == 1 { down[c.suit.rawValue] = c.rank } else { up[c.suit.rawValue] = c.rank }`,   // F = column-top → foundation
  `case "G":
      let idx = n(1)
      guard idx >= 0, idx < cells.count, let c = cells[idx] else { return false }
      cells[idx] = nil
      if n(2) == 1 { down[c.suit.rawValue] = c.rank } else { up[c.suit.rawValue] = c.rank }`,   // G = free cell → foundation
  `case "T":
      let src = n(1), idx = n(2), dst = n(3)
      guard src >= 0, src < tableau.count, dst >= 0, dst < tableau.count, src != dst,
            idx >= 0, idx < tableau[src].count else { return false }
      let run = Array(tableau[src][idx...]); tableau[src].removeSubrange(idx...)
      tableau[dst].append(contentsOf: run)`,                                                    // T = run move src[idx...] → dst
  `case "C":
      let col = n(1)
      guard col >= 0, col < tableau.count, !tableau[col].isEmpty,
            let e = cells.firstIndex(where: { $0 == nil }) else { return false }
      cells[e] = tableau[col].removeLast()`,                                                    // C = park to first empty cell
  `case "X":
      let idx = n(1), dst = n(2)
      guard idx >= 0, idx < cells.count, let c = cells[idx],
            dst >= 0, dst < tableau.count else { return false }
      cells[idx] = nil; tableau[dst].append(c)`,                                                // X = free cell → tableau dst
]);

// Cross-copy: the web applyDemoToken must interpret the SAME token format (so a baked line plays
// identically on both). Pinned here alongside the iOS copy so a one-sided edit trips CI. Both
// copies validate each token and return false on a malformed/inapplicable one (defense against
// bad baked data); the applied semantics are identical to tools/solver rules.mjs.
test('web applyDemoToken shares the iOS/solver token format', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  for (const s of [
    "case 'F': { const c=col(1); if(c<0||!t[c].length) return false; card=t[c].pop(); if(+f[2]) down[card.suit]=card.rank; else up[card.suit]=card.rank; break; }",
    "case 'G': { const i=+f[1]; if(!(i>=0&&i<cells.length)||!cells[i]) return false; card=cells[i]; cells[i]=null; if(+f[2]) down[card.suit]=card.rank; else up[card.suit]=card.rank; break; }",
    "case 'T': { const s=col(1), d=col(3), i=+f[2]; if(s<0||d<0||s===d||!(i>=0&&i<t[s].length)) return false; const run=t[s].splice(i); for(const c of run) t[d].push(c); break; }",
    "case 'C': { const c=col(1), e=cells.indexOf(null); if(c<0||!t[c].length||e<0) return false; cells[e]=t[c].pop(); break; }",
    "case 'X': { const i=+f[1], d=col(2); if(!(i>=0&&i<cells.length)||!cells[i]||d<0) return false; card=cells[i]; cells[i]=null; t[d].push(card); break; }",
  ]) {
    assert.ok(html.includes(norm(s)), `index.html applyDemoToken token format drifted: ${s.slice(0, 50)}...`);
  }
});

// Cross-copy: leaving a demo must never leave a demo-touched board playable/scorable. iOS pins the
// Stop/Done → restartDeal wiring and the finishDemo boardComplete guard; the web copy must keep
// the mirror wiring (demoStop → restartDeal, all-cards-home guard in finishDemo, and demoAdvance
// aborting to restartDeal on a bad token) or the two apps diverge on a scoring-integrity rule.
test('web demo exit paths re-deal (no playable demo-touched board)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  for (const s of [
    'document.getElementById("demoStop").onclick=()=>restartDeal();',
    'if(!state.tableau.every(c=>c.length===0) || !state.cells.every(c=>c===null)){ restartDeal(); return; }',
    'if(!applyDemoToken(demoMoves[demoIdx++])){ restartDeal(); return false; }',
  ]) {
    assert.ok(html.includes(norm(s)), `index.html demo exit integrity drifted: ${s.slice(0, 60)}...`);
  }
  const swift = read('Views/ContentView.swift');
  assert.ok(swift.includes(norm('demoPill(game.demoing ? "Stop" : "Done") { withAnimation { game.restartDeal() } }')),
    'ContentView demo Stop/Done no longer re-deals');
  // The iOS model-side guards, mirroring the three web pins above: finishDemo only unlocks a
  // genuinely complete board, and demoAdvance aborts to a re-deal on a token that fails to apply.
  const game = read('Model/Game.swift');
  assert.ok(game.includes(norm('guard boardComplete else { restartDeal(); return }')),
    'Game.finishDemo no longer guards the unlock on a complete board');
  assert.ok(game.includes(norm('guard applied else { restartDeal(); return false }')),
    'Game.demoAdvance no longer aborts to a re-deal on a bad token');
});
