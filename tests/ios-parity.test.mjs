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
pin('Model/Daily.swift', 'frozen objective pools', [
  'private let SILVER_UNIVERSAL = ["moves", "no-undo"]',
  'private let SILVER_CERTIFIED = ["cells-le-1", "cells-le-2", "down-openers-20"]',
  'private let GOLD = ["no-cells", "aces-first", "kings-first", "jacks-down-first", "suits-top-down", "suit-sprint"]',
]);
pin('Model/Daily.swift', 'dailyChallenge RNG seed + pick order', [
  'Mulberry32(UInt32(truncatingIfNeeded: 0x9e37_79b9 ^ (dayIndex + 1)))',
  'let silverPool = SILVER_UNIVERSAL + SILVER_CERTIFIED.filter { rec.supports.contains($0) }',
  'Int((Double(par) * 1.2).rounded())',          // moves objective N = round(par*1.2)
]);

// ---- objective checkers, mergeTiers, streaks (incl. Flawless) ----
pin('Model/Daily.swift', 'objective checkers', [
  'for e in t.foundationOrder { if a >= 4 { break }; if e.rank == 1 { a += 1 } else { return false } }', // acesFirst
  'for e in t.foundationOrder where e.rank == 13 && e.end == "down" {',                                   // downOpeners20
  'else if e.rank == 1 && e.end == "up" && k < 4 { return false }',                                       // kingsFirst
  'else if e.rank == 1 && e.end == "up" && j < 4 { return false }',                                       // jacksDownFirst
  'else if e.rank == 1 && e.end == "up" && !kd[e.suit] { return false }',                                 // suitsTopDown
  'for T in 0..<4 where T != S && started[T] && home[T] < 13 { return false }',                          // suitSprint
]);
pin('Model/Daily.swift', 'mergeTiers + streaks (Flawless)', [
  'bronze: p.bronze || attempt.bronze,',
  'flawless: p.flawless || attempt.flawless,',
  'return Streaks(play: tierRun { $0.bronze }, silver: tierRun { $0.silver },',
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
  `case "C":
      let col = n(1)
      guard col >= 0, col < tableau.count, !tableau[col].isEmpty,
            let e = cells.firstIndex(where: { $0 == nil }) else { return false }
      cells[e] = tableau[col].removeLast()`,                                                    // C = park to first empty cell
  'let run = Array(tableau[src][idx...]); tableau[src].removeSubrange(idx...)',                 // T = run move
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
    "case 'C': { const c=col(1), e=cells.indexOf(null); if(c<0||!t[c].length||e<0) return false; cells[e]=t[c].pop(); break; }",
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
