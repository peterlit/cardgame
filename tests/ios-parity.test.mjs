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
pin('Model/Game.swift', 'applyDemoToken token format', [
  'let c = tableau[n(1)].removeLast()',
  'if n(2) == 1 { down[c.suit.rawValue] = c.rank } else { up[c.suit.rawValue] = c.rank }',
  'let run = Array(tableau[src][idx...]); tableau[src].removeSubrange(idx...)',
  'if let e = cells.firstIndex(where: { $0 == nil }) { cells[e] = c }',   // C = park to first empty cell
]);

// Cross-copy: the web applyDemoToken must interpret the SAME token format (so a baked line plays
// identically on both). Pinned here alongside the iOS copy so a one-sided edit trips CI.
test('web applyDemoToken shares the iOS/solver token format', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  for (const s of [
    "case 'F': card=t[+f[1]].pop(); if(+f[2]) down[card.suit]=card.rank; else up[card.suit]=card.rank; break;",
    "case 'G': card=cells[+f[1]]; cells[+f[1]]=null; if(+f[2]) down[card.suit]=card.rank; else up[card.suit]=card.rank; break;",
    "case 'C': card=t[+f[1]].pop(); cells[cells.indexOf(null)]=card; break;",
  ]) {
    assert.ok(html.includes(norm(s)), `index.html applyDemoToken token format drifted: ${s.slice(0, 50)}...`);
  }
});
