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
import { RUN_LOG_MAX, OBJECTIVES } from './daily.mjs';

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
// ---- the per-day run log: every clear, on both platforms, with the same cap and the same key ----
// tests/daily.mjs mergeRuns is the canonical copy (behaviour-tested there). A mirror that appended
// without the (moves, elapsed) dedupe would double a player's history the first time they
// re-imported their own stats backup; one that dropped the cap would grow the record without bound;
// one that logged on a LOSS would report clears that never happened.
test('every win logs one run and mergeTiers unions the logs on both platforms (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const swift = read('Model/Daily.swift');
  // the win — and only the win — logs exactly one run
  assert.ok(swift.includes(norm('result.runs = [RunLog(moves: t.moves, elapsed: t.elapsed)]')),
    'iOS evaluateChallenge no longer logs the winning run');
  assert.ok(html.includes(norm('result.runs=[{moves:telemetry.moves,elapsed:telemetry.elapsed}]')),
    'web evaluateChallenge no longer logs the winning run');
  // the day accumulates them through mergeRuns
  assert.ok(swift.includes(norm('runs: mergeRuns(p.runs, attempt.runs)')), 'iOS mergeTiers no longer unions the run logs');
  assert.ok(html.includes(norm('runs:mergeRuns(p.runs,attempt.runs)')), 'web mergeTiers no longer unions the run logs');
  // ...deduped on (moves, elapsed), so a re-imported backup can't inflate the history
  assert.ok(swift.includes(norm('let k = "\\(r.moves):\\(r.elapsed)"')), 'iOS mergeRuns lost its (moves, elapsed) dedupe key');
  assert.ok(html.includes(norm('const k=`${r.moves}:${r.elapsed}`')), 'web mergeRuns lost its (moves, elapsed) dedupe key');
  // ...and capped at the canonical length on both platforms
  assert.ok(swift.includes(norm(`let runLogMax = ${RUN_LOG_MAX}`)), `iOS run-log cap drifted from RUN_LOG_MAX (${RUN_LOG_MAX})`);
  assert.ok(html.includes(norm(`const RUN_LOG_MAX=${RUN_LOG_MAX}`)), `web run-log cap drifted from RUN_LOG_MAX (${RUN_LOG_MAX})`);
});

// ---- ...and a solved day says what it cost, on both platforms ----
test('a solved day card reports its clears, best moves and par (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const daily = read('Views/DailyView.swift');
  assert.ok(daily.includes(norm('parts.append("par \\(par)")')), 'iOS day card stopped showing the deal\'s par');
  assert.ok(html.includes(norm('parts.push(`par ${c.par}`)')), 'web day card stopped showing the deal\'s par');
  for (const [name, src] of [['index.html', html], ['DailyView.swift', daily]])
    assert.ok(src.includes(norm('Moves each run:')), `${name}: the solved day card no longer lists the moves of each clear`);
  assert.ok(daily.includes(norm('.accessibilityIdentifier("daily.clears")')), 'iOS clears line lost its accessibility identifier');
});

// ---- the live HUD hint: end-bias is LOCKED IN once every suit holds `min` from the named end ----
// A suit's count from one end never shrinks, so this tier is decided long before the win — but both
// copies of objSecured used to drop it into `default: false`, so a player who had already banked
// (say) 10 from the King end against Aug 29's end-bias{down, 9} watched the 🥈 chip sit on `·` until
// the win awarded it anyway. tests/daily.mjs objSecured is the canonical, behaviour-tested copy;
// these pin the two shipped mirrors to it, and pin out the comment that licensed the old default.
test('objSecured secures end-bias from live board state on both platforms (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const swift = read('Model/Daily.swift');
  assert.ok(swift.includes(norm(`case "end-bias":
        let m = p.min ?? 0
        return p.end == "up" ? up.allSatisfy { $0 >= m } : down.allSatisfy { 14 - $0 >= m }`)),
    'iOS objSecured no longer secures end-bias from the live up/down foundations');
  assert.ok(html.includes(norm(`case 'end-bias':       { const m=p.min; return p.end==='up' ? up.every(u=>u>=m) : down.every(d=>14-d>=m); }`)),
    'web objSecured no longer secures end-bias from the live up/down foundations');
  for (const [name, src] of [['index.html', html], ['Daily.swift', swift]])
    assert.ok(!src.includes(norm('end-restrictions — not securable')),
      `${name}: objSecured is back to treating end-bias as unsecurable until the win`);
});

// ---- the live HUD hint: is this tier already IMPOSSIBLE? (objViolated, the fail-fast checker) ----
// This is the most load-bearing UI-only function in the app: it draws the ✗ on a tier chip AND it is
// the predicate both auto-play refusals are computed from (autoSendWouldBreakTier,
// autoFinishTierCost). It has rotted before — all three copies sat on a pre-parameterised id set
// ('aces-first', 'split-even', 'cells-le-1'), none of which the generator can emit, so every
// objective fell through to `default: false` and no chip ever went ✗. Nothing caught it, because
// the only objViolated assertions in the suite exercised tests/daily.mjs, the copy nobody ships.
//
// index.html's copy is now RUN for real (tests/web-behaviour.test.mjs). Swift has no test target, so
// it gets the strongest cheap guard: every family the generator can emit must be handled by name,
// no retired id may reappear, and each branch's body is pinned to the canonical rule.
test('iOS objViolated handles every objective family the generator can emit (no fall-through rot)', () => {
  const raw = readFileSync(join(IOS, 'Model/Daily.swift'), 'utf8');
  const start = raw.indexOf('func objViolated(');
  assert.ok(start > 0, 'Daily.swift no longer defines objViolated');
  const end = raw.indexOf('\n}', start);
  const body = norm(raw.slice(start, end));
  for (const id of Object.keys(OBJECTIVES))
    assert.ok(body.includes(`case "${id}":`),
      `iOS objViolated has no branch for '${id}' — it falls through to \`default: false\`, so that tier's chip can never go ✗ and neither auto-play refusal will ever protect it`);
  for (const dead of ['aces-first', 'split-even', 'cells-le-1'])
    assert.ok(!body.includes(`case "${dead}"`), `iOS objViolated is back on the retired id '${dead}'`);
  // No per-branch substring pins here: every one of them was a substring of the WHOLE-BODY
  // equality pin below (IOS_BODIES['Model/Daily.swift objViolated']), so a canonical-rule
  // change had to be transcribed twice in this one file and the weaker copy could only ever
  // fail where the stronger one already did. The coverage checks above are NOT redundant:
  // they are driven by the generator's own OBJECTIVES table, which the pinned text is not.
});

// ---- ...and no line may be SPLICED INTO the three functions that carry the iOS refusals ----
// Every other iOS guard here is a substring pin. A substring pin sees an EDIT to the line it quotes
// and is structurally blind to an INSERTED one: appending `; if 1 == 1 { return false }` after
// `let p = obj.param` blacks out every iOS tier ✗ chip, and the same splice in
// autoSendWouldBreakTier switches the auto-play refusal off (bug/WF-4, shipped back verbatim) —
// with every pin above still satisfied. Both mutants survived a full suite run.
//
// So these three bodies — the fail-fast checker and the two refusals computed from it — are pinned
// WHOLE, by equality, not by substring. Comments and formatting are stripped first, so re-wrapping
// a line or rewriting a comment is free; adding, removing or reordering a STATEMENT is not. When a
// body legitimately changes, re-derive the expected text (the failure prints the actual) after
// re-checking the behaviour against tests/daily.mjs and the shipped web copy.
const stripSwiftComments = src => {
  let out = '', i = 0;
  while (i < src.length) {
    const c = src[i], n = src[i + 1];
    if (c === '/' && n === '/') { const j = src.indexOf('\n', i); i = j < 0 ? src.length : j; continue; }
    if (c === '/' && n === '*') {                     // Swift block comments NEST: /* a /* b */ still open */
      let depth = 1; i += 2;
      while (i < src.length && depth > 0) {
        if (src[i] === '/' && src[i + 1] === '*') { depth++; i += 2; continue; }
        if (src[i] === '*' && src[i + 1] === '/') { depth--; i += 2; continue; }
        i++;
      }
      out += ' '; continue;
    }
    // Only plain "..." literals are understood. A multi-line ("""…""") or raw (#"…"#) literal
    // inside a pinned body would be mis-scanned, so swiftFunc asserts that none appears.
    if (c === '"') {                                  // string literal: copied through verbatim
      out += c; i++;
      while (i < src.length) {
        if (src[i] === '\\') { out += src.slice(i, i + 2); i += 2; continue; }
        out += src[i]; if (src[i] === '"') { i++; break; }
        i++;
      }
      continue;
    }
    out += c; i++;
  }
  return out;
};

/// The whole text of a Swift func, from its declaration to the `}` that closes its body, with
/// comments removed and whitespace collapsed. Brace-matched, so it is immune to line renumbering.
function swiftFunc(file, decl) {
  const raw = readFileSync(join(IOS, file), 'utf8');
  const at = raw.indexOf(decl);
  assert.ok(at >= 0, `${file}: no declaration \`${decl}\` — was it renamed or deleted?`);
  assert.equal(raw.indexOf(decl, at + 1), -1, `${file}: \`${decl}\` is declared twice — this pin would be ambiguous`);
  const src = stripSwiftComments(raw.slice(at));
  let depth = 0, i = 0, opened = false;
  while (i < src.length) {
    const c = src[i];
    if (c === '"') { i++; while (i < src.length) { if (src[i] === '\\') { i += 2; continue; } if (src[i] === '"') { i++; break; } i++; } continue; }
    if (c === '{') { depth++; opened = true; }
    else if (c === '}') { depth--; if (depth === 0 && opened) { i++; break; } }
    i++;
  }
  assert.ok(opened && depth === 0, `${file}: unterminated body for \`${decl}\``);
  const body = src.slice(0, i);
  // The scanner understands only plain "..." literals; a multi-line or raw literal in the body
  // would be mis-read (its contents scanned as code), so fail loudly rather than pin garbage.
  assert.ok(!/"""|#"/.test(body),
    `${file}: \`${decl}\` contains a multi-line or raw string literal — this pin's scanner cannot read those`);
  return norm(body);
}

// The pins above promise that a COMMENT edit is free. That promise is only as good as the
// stripper, and Swift's block comments nest — a `/* … /* … */ … */` inside a pinned body used to
// end at the FIRST `*/`, leaking the outer comment's tail (braces included) into the brace matcher
// and truncating the body, so a pure comment edit failed the pin with "a statement was added".
test('the whole-body pin\'s comment stripper is nesting-aware (a comment edit stays free)', () => {
  assert.equal(norm(stripSwiftComments('func f() { /* a /* b */ still comment } */ return 1 }')),
    'func f() { return 1 }');
  assert.equal(norm(stripSwiftComments('func f() { // } not code\n return 1 }')), 'func f() { return 1 }');
  // ...and comment markers INSIDE a string literal are still code.
  assert.equal(norm(stripSwiftComments('let s = "a /* b */ c" // x')), 'let s = "a /* b */ c"');
});

const IOS_BODIES = {
  'Model/Daily.swift objViolated': ['Model/Daily.swift', 'func objViolated(',
    'func objViolated(_ obj: Objective, _ t: Attempt) -> Bool { let p = obj.param switch obj.id { ' +
    'case "moves": return t.moves > (p.N ?? 0) case "no-undo": return t.undos > 0 ' +
    'case "cells-le": return t.cellUses > (p.N ?? 0) case "max-run": return t.maxRunMoved > (p.N ?? 1) ' +
    'case "big-move": return false case "split-at": let r = p.R ?? 7, x = upDown(t) ' +
    'return x.u.contains { $0 > r } || x.d.contains { $0 > 13 - r } case "end-bias": ' +
    'let m = p.min ?? 0, x = upDown(t) return (p.end == "up" ? x.d : x.u).contains { $0 > 13 - m } ' +
    'case "ends-first": return !endsFirstOK(t, p) case "before-ace": return !beforeAceOK(t, p) ' +
    'case "suit-top-first": return !suitTopFirstOK(t, p) case "suit-sprint": return !suitSprintOK(t) ' +
    'case "rank-rush": let n = p.N ?? 0 if let at = rushCompleted(t, p.rank ?? 1) { return at > n } ' +
    'return t.moves > n case "suit-balance": return maxSpread(t) > (p.N ?? 13) default: return false } }'],
  'Model/Game.swift autoSendWouldBreakTier': ['Model/Game.swift', 'private func autoSendWouldBreakTier(',
    'private func autoSendWouldBreakTier(_ c: Card, toUp: Bool) -> Bool { ' +
    'guard let ch = liveChallenge else { return false } var t = liveAttempt() ' +
    'let silverWasLive = !objViolated(ch.silver, t) let goldWasLive = !objViolated(ch.gold, t) ' +
    'guard silverWasLive || goldWasLive else { return false } t.moves = moveCount + 1 ' +
    't.foundationOrder.append(FoundationEvent(suit: c.suit.rawValue, rank: c.rank, ' +
    'end: toUp ? "up" : "down", moveIdx: t.moves)) ' +
    'return (silverWasLive && objViolated(ch.silver, t)) || (goldWasLive && objViolated(ch.gold, t)) }'],
  'Model/Game.swift autoFinishTierCost': ['Model/Game.swift', 'func autoFinishTierCost(',
    'func autoFinishTierCost() -> [String] { guard let ch = liveChallenge else { return [] } ' +
    'var t = liveAttempt() let silverWasLive = !objViolated(ch.silver, t) ' +
    'let goldWasLive = !objViolated(ch.gold, t) guard silverWasLive || goldWasLive else { return [] } ' +
    'let sim = simulateAutoFinish() guard sim.won else { return [] } t.won = true t.moves = sim.moves ' +
    't.foundationOrder.append(contentsOf: sim.events) let after = evaluateChallenge(ch, t) ' +
    'var lost: [String] = [] if silverWasLive && !after.silver { lost.append("🥈 Silver") } ' +
    'if goldWasLive && !after.gold { lost.append("🥇 Gold") } return lost }'],
  // The calendar's month window. `civilOf` is the inverse of dayIndexFor and decides which months
  // the grid may show; get it wrong and the grid either strands a seeded month (the 2026-09-01 bug:
  // August unreachable) or offers a month of dead cells.
  'Model/Daily.swift civilOf': ['Model/Daily.swift', 'func civilOf(',
    'func civilOf(_ idx: Int) -> (year: Int, month: Int, day: Int) { var c = DateComponents(); ' +
    'c.year = 2026; c.month = 8; c.day = 1 let cal = Calendar(identifier: .gregorian) ' +
    'guard let base = cal.date(from: c), let d = cal.date(byAdding: .day, value: idx, to: base) ' +
    'else { return (2026, 8, 1) } let p = cal.dateComponents([.year, .month, .day], from: d) ' +
    'return (p.year ?? 2026, p.month ?? 8, p.day ?? 1) }'],
  'Views/DailyView.swift monthNo': ['Views/DailyView.swift', 'private func monthNo(of',
    'private func monthNo(of idx: Int) -> Int { let c = civilOf(idx) return c.year * 12 + (c.month - 1) }'],
  'Views/DailyView.swift calMonthRange': ['Views/DailyView.swift', 'private var calMonthRange',
    'private var calMonthRange: ClosedRange<Int> { let last = max(0, pool.count - 1) ' +
    'return monthNo(of: 0)...max(monthNo(of: 0), monthNo(of: last)) }'],
};

test('the iOS fail-fast checker and both refusals are pinned WHOLE — nothing can be spliced into them', () => {
  for (const [label, [file, decl, expected]] of Object.entries(IOS_BODIES))
    assert.equal(swiftFunc(file, decl), expected,
      `${label} changed shape. A statement was added, removed or reordered in a function that decides ` +
      `whether a tier chip goes ✗ and whether auto-play/auto-finish may spend a live tier. Re-verify the ` +
      `behaviour against tests/daily.mjs and the shipped web copy, then update the expected text here.`);
});

// ---- the calendar grid must be drawn from calMonth, never from today's date ----
// The grid read `Calendar.current.dateComponents([.year, .month], from: Date())` directly, so it
// could only ever draw the current month: on 2026-09-01 every August day became unreachable, with
// no control to go back, and the ⏰ grace on a 2026-08-31 attempt could not be reached either.
// The web twin (index.html renderDailyCal) is covered behaviourally in tests/web-behaviour.test.mjs.
test('iOS daily calendar draws the month it is NAVIGATED to, not today (both arrows present, both bounded)', () => {
  const view = read('Views/DailyView.swift');
  assert.ok(view.includes(norm('let shown = calMonth == 0 ? monthNo(of: clampedToday) : calMonth')),
    'the grid no longer takes its month from calMonth — if it reads Date() again, every earlier month is stranded');
  assert.ok(!/private var calendar: some View \{ let now = Calendar\.current/.test(view),
    'the calendar is reading Date() for its month again');
  assert.ok(view.includes(norm('monthArrow("chevron.left", "Previous month", by: -1, enabled: shown > range.lowerBound)')),
    'the back arrow is gone, or is no longer bounded by the pool');
  assert.ok(view.includes(norm('monthArrow("chevron.right", "Next month", by: 1, enabled: shown < range.upperBound)')),
    'the forward arrow is gone, or is no longer bounded by the pool');
  // The step itself clamps into the pool, the same clamp index.html's clampCalMonth applies.
  assert.ok(view.includes(norm('calMonth = min(r.upperBound, max(r.lowerBound, (calMonth == 0 ? monthNo(of: clampedToday) : calMonth) + delta))')),
    'the month step no longer clamps to the seeded pool');
  // Tapping a cell must not move the grid, and stepping the grid must not move the day card.
  assert.ok(view.includes(norm('if avail { dayView = idx; lockedDay = nil } else { lockedDay = idx }')),
    'the cell tap changed shape — the day card and the drawn month are meant to stay independent');
});

// ---- a restored stats backup must bring the per-day clear log with it ----
// The importer re-builds every imported TierResult field by field (to sanitise hand-edited files),
// and left `runs` off the constructor — so restoring onto a NEW DEVICE, the feature's whole point,
// returned every solved day with an empty history and the day card fell back to "best N moves".
// DailyStore.merge folds through mergeRuns(local, imported), so nothing downstream could recover it.
test('iOS stats import carries the per-day run log (restoring a backup keeps the clear history)', () => {
  const view = read('Views/DailyView.swift');
  assert.ok(view.includes(norm('runs: Array(r.runs.filter { $0.moves > 0 && $0.elapsed > 0 }.suffix(runLogMax))')),
    'the stats importer stopped carrying `runs` — a restored backup silently drops every day\'s clear log');
});

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
  // ...and it must actually be appended to whichever tier line this attempt earned, which now
  // also carries the DAY the attempt scored (empty for today's challenge) — a grace/past-day win
  // used to render identically to today's (ux/WF-14:win-overlay-omits-the-day).
  'if d.flawless { return winDayLabel + "🌟 Flawless! 🥉🥈🥇 all in a single run." + onTime }',
  'return winDayLabel + "Daily challenge: \\(earned.isEmpty ? "—" : earned) earned." + onTime',
  `guard let day = game.dailyResultDay, day != todayIndex() else { return "" }
        return "\\(dayLabel(day)): "`,
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
    // Stop/Done go through endDemo, which ALWAYS re-deals — either into that day's fresh scored
    // challenge (playChallenge → deal) or into a plain re-deal. Both branches are pinned below, so
    // "re-deal" can't be quietly dropped from either one (ux/WF-6:demo-exit-drops-challenge-binding
    // moved this call site; the invariant it guards is unchanged).
    'document.getElementById("demoStop").onclick=()=>endDemo();',
    `function endDemo(){
  const day = demoDay;
  if(day!=null && day<=todayIndex() && dailyRec(day)) playChallenge(day);
  else restartDeal();
}`,
    'if(!state.tableau.every(c=>c.length===0) || !state.cells.every(c=>c===null)){ restartDeal(); return; }',
    'if(!applyDemoToken(demoMoves[demoIdx++])){ restartDeal(); return false; }',
  ]) {
    assert.ok(html.includes(norm(s)), `index.html demo exit integrity drifted: ${s.slice(0, 60)}...`);
  }
  const swift = read('Views/ContentView.swift');
  assert.ok(swift.includes(norm('demoPill(game.demoing ? "Stop" : "Done") { withAnimation { game.endDemo() } }')),
    'ContentView demo Stop/Done no longer routes through endDemo');
  assert.ok(read('Model/Game.swift').includes(norm(`let day = demoDay
        if let d = day, d <= todayIndex(), dailyChallenge(d, pool) != nil {
            playChallenge(d)
        } else {
            restartDeal()
        }`)), 'Game.endDemo no longer re-deals on both branches');
  // The iOS model-side guards, mirroring the three web pins above: finishDemo only unlocks a
  // genuinely complete board, and demoAdvance aborts to a re-deal on a token that fails to apply.
  const game = read('Model/Game.swift');
  assert.ok(game.includes(norm('guard boardComplete else { restartDeal(); return }')),
    'Game.finishDemo no longer guards the unlock on a complete board');
  assert.ok(game.includes(norm('guard applied else { restartDeal(); return false }')),
    'Game.demoAdvance no longer aborts to a re-deal on a bad token');
});

// ---- 🌟 Flawless says the SAME thing on every surface (ux/WF-15:flawless-pill-both-vs-three) ----
// The how-to-win pill's label is the only definition of 🌟 a novice reads before spending a demo on
// it, and it feeds the demo bar's headline verbatim. It used to say "Both objectives in one run"
// while the legend, the day card and the win overlay all said "all three earned in a single run" —
// two surfaces contradicting three, on the one screen that exists to teach the tier. Pin the agreed
// wording on both platforms AND the absence of the old two-objective phrasing, so neither copy can
// drift back on its own.
test('the 🌟 Flawless demo label says "all three" on both platforms (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const daily = read('Views/DailyView.swift');
  const label = '🥉🥈🥇 all three in a single run';
  assert.ok(daily.includes(norm(`showPill(c.seed, "flawless", "🌟 Flawless", "${label}")`)),
    'iOS 🌟 pill no longer labels Flawless as all three tiers in one run');
  assert.ok(html.includes(norm(`b('flawless','${label}','🌟 Flawless')`)),
    'web 🌟 pill no longer labels Flawless as all three tiers in one run');
  for (const [name, src] of [['index.html', html], ['DailyView.swift', daily]]) {
    assert.ok(!src.includes('Both objectives in one run'),
      `${name}: the 🌟 pill is back to "Both objectives in one run", which contradicts the legend/day card/win overlay`);
  }
  // ...and the iOS surface it must agree WITH (the streaks legend, which the web sheet has no
  // twin for) is still saying "all three".
  assert.ok(daily.includes(norm('Flawless = 🥉🥈🥇 all three earned in a single run')), 'iOS streak legend lost its Flawless definition');
});

// ---- the Daily calendar: day identity travels with the action, and a locked cell answers ----
// Three round-1 findings, one theme: the calendar told the player less than it knew.
//   * bug/WF-13:daily-card-seed-grouped — the card printed "Deal #691,039" (LocalizedStringKey
//     grouping) while the board pill and every Wins surface printed "691039" for the same deal.
//   * ux/WF-13:selected-day-invisible-at-play — scrolled to the grid, the only confirmation of
//     WHICH day Play would start was a pale tint on a 44x33 pt cell.
//   * ux/WF-13:future-day-tap-no-feedback — a tap on a future cell changed nothing at all.
test('the Daily calendar names the day it will play and answers a locked tap (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const daily = read('Views/DailyView.swift');
  // deal number: ungrouped, through the shared formatter (never Text("Deal #\(c.seed)")).
  assert.ok(daily.includes(norm('Text("Deal #" + DealFormat.seed(c.seed))')),
    'DailyView day card no longer formats its deal number through DealFormat.seed (it will group the digits)');
  // (the negative form is anchored on the rendered call, since the explanatory comment beside it
  // quotes the old interpolation on purpose)
  assert.ok(!daily.includes(norm('Text("Deal #\\(c.seed)").font(')),
    'DailyView day card is back to the digit-grouping interpolation');
  // the day name rides on the Play/Replay button on both platforms...
  assert.ok(daily.includes(norm('let daySuffix = day == ti ? "" : " \\(dayLabel(day))"')),
    'iOS Play button no longer names the selected day');
  assert.ok(daily.includes(norm('Text(replay ? "Replay\\(daySuffix) to improve ↻" : "Play\\(daySuffix)")')),
    'iOS Play button label dropped its day suffix');
  assert.ok(html.includes(norm("const daySuffix = isToday ? '' : ` ${dstr}`;")),
    'web Play button no longer names the selected day');
  assert.ok(html.includes(norm('>Play${daySuffix}</button>')), 'web Play button label dropped its day suffix');
  // ...and an unavailable cell produces feedback instead of swallowing the tap.
  assert.ok(daily.includes(norm('if avail { dayView = idx; lockedDay = nil } else { lockedDay = idx }')),
    'iOS calendar cell no longer records a tap on an unavailable day');
  assert.ok(daily.includes(norm('"🔒 \\(dayLabel(idx)) unlocks on the day itself — come back then."')),
    'iOS lost the "unlocks on the day itself" message for a locked cell');
  assert.ok(html.includes(norm('`lockedDay=${idx};renderDaily()`')),
    'web calendar cell no longer records a tap on an unavailable day');
  assert.ok(html.includes(norm('unlocks on the day itself — come back then.')),
    'web lost the "unlocks on the day itself" message for a locked cell');
});

// ---- the board's destructive pills confirm before discarding a live game ----
// ux/WF-3:board-reset-pills-no-confirm — `New game` and `Replay` sit 91 pt and 87 pt from `Undo`
// and used to reset the board (dropping a live daily attempt, its HUD and its whole undo history)
// in one unconfirmed tap, while the Daily sheet guarded the identical destruction with a dialog.
// The guard MUST stay state-gated (`hasLiveGame`), or the common one-tap reset on an untouched
// board grows a tap; and the daily-only promise ("you can replay the challenge afterwards") must
// never be shown for a casual game, whose loss really is final.
test('board reset controls confirm only when there is a live game to lose (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const content = read('Views/ContentView.swift');
  // iOS: both pills (portrait toolbar + landscape rail) route through requestReset, which is the
  // only place the state gate lives.
  assert.ok(content.includes(norm('pill("New game", primary: true) { requestReset(.newGame) }')),
    'portrait New game pill no longer routes through requestReset');
  assert.ok(content.includes(norm('pill("Replay", systemImage: "arrow.clockwise") { requestReset(.replay) }')),
    'portrait Replay pill no longer routes through requestReset');
  assert.ok(content.includes(norm('railPill("New game", primary: true) { requestReset(.newGame) }')),
    'landscape New game pill no longer routes through requestReset');
  assert.ok(content.includes(norm('railPill("Replay", systemImage: "arrow.clockwise") { requestReset(.replay) }')),
    'landscape Replay pill no longer routes through requestReset');
  assert.ok(content.includes(norm('if game.hasLiveGame { pendingReset = action } else { performReset(action) }')),
    'iOS reset confirmation is no longer gated on hasLiveGame (an untouched board must stay one tap)');
  // web: same gate, same two-branch copy.
  assert.ok(html.includes(norm('function hasLiveGame(){ return (moveCount>0 || graceLiveNow()) && !isWon() && !demoing; }')),
    'web lost its hasLiveGame gate');
  assert.ok(html.includes(norm('if(!hasLiveGame()) return true;')), 'web confirmReset is no longer state-gated');
  assert.ok(html.includes(norm('document.getElementById("replayBtn").onclick=()=>{ if(!confirmReset()) return; restartDeal(); };')),
    'web Replay no longer confirms');
  assert.ok(html.includes(norm('document.getElementById("newBtn").onclick=()=>{ if(!confirmReset()) return; stopDemo(); deal(randomSeed()); };')),
    'web New game no longer confirms');
  // the casual branch must NOT inherit the challenge-only promise.
  for (const [name, src] of [['index.html', html], ['ContentView.swift', content]]) {
    assert.ok(src.includes(norm('This game is not a challenge, so there is no way back to it.')),
      `${name}: the casual reset copy lost its "no way back" warning`);
  }
  // ...and the gate is NOT a bare move count: a challenge opened yesterday and not yet moved in
  // (moveCount == 0) still has day D's ⏰ riding on it, and a re-deal spends it forever
  // (bug/Game.swift:grace-forfeited-without-confirm-at-zero-moves). Both platforms OR in the grace.
  assert.ok(read('Model/Game.swift').includes(
    norm('var hasLiveGame: Bool { (moveCount > 0 || graceLive) && !won && !demoing && !boardComplete }')),
    'iOS hasLiveGame is back on a bare move count — a zero-move attempt begun yesterday forfeits its ⏰ with no dialog');
  // and neither dialog may then say "your 0 moves ... will be discarded".
  assert.ok(content.includes(norm('let cost = game.moveCount == 0 ? nil')),
    'ContentView reset copy no longer drops the cost sentence at zero moves');
  assert.ok(read('Views/DailyView.swift').includes(norm('let lead = game.moveCount == 0 ? cause')),
    'DailyView reset copy no longer drops the cost sentence at zero moves');
  assert.ok(html.includes(norm("const cost = moveCount===0 ? '' :")),
    'web reset copy no longer drops the cost sentence at zero moves');
});

// ---- the Deal # alert's `Play` is destructive and must say so ----
// ux/WF-7:deal-play-discards-live-game-no-confirm — the field is pre-filled with the CURRENT deal,
// so `Play` reads as "play this deal" while it re-deals and throws away a live daily attempt (its
// moves, its clock, its objectives HUD) with no warning, one mis-tap from `Cancel` in the same row.
// It shares the board pills' state gate: an unconditional confirm would cost the common path a tap.
test('the deal-number entry confirms before discarding a live game (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const content = read('Views/ContentView.swift');
  assert.ok(content.includes(norm(`if game.hasLiveGame {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { pendingReset = .deal(n) }
                } else {
                    withAnimation { game.deal(seed: n) }
                }`)),
    'the iOS "Play a deal" alert no longer confirms (or no longer state-gates) its re-deal');
  assert.ok(html.includes(norm(`if(!confirmReset()) return;
  closeDeal(); deal(n);`)),
    'the web deal modal no longer confirms its re-deal');
});

// ---- ⏰ Same-day: named in the legend, named in the overlay, and never lost in silence ----
// Three round-1 findings against the ⏰ award's surfaces:
//   * ux/WF-14:replay-forfeits-grace-silently — one Replay tap during a live grace destroyed it
//     with no dialog and no notice, and no user action can ever restore it.
//   * ux/WF-14:calendar-pip-unlabelled — the ⏰ marker is an unlabelled 5 pt gold dot and the
//     legend listed only 🥉🥈🥇🌟.
//   * ux/WF-14:win-overlay-omits-the-day — the overlay never named which day was completed.
test('⏰ Same-day is labelled, dated, and never forfeited silently (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const game = read('Model/Game.swift');
  const content = read('Views/ContentView.swift');
  const daily = read('Views/DailyView.swift');
  // the grace predicate: exactly isOnTime's grace window, on both platforms. It must NOT be
  // "fixed" by preserving challengeStartDay across a restart — that would bank ⏰ for a run begun
  // the next day — so the guard is a warning, and these pin the warning.
  assert.ok(game.includes(norm(`guard let day = challengeDay, let start = challengeStartDay else { return false }
        return start == day && todayIndex() == day + 1`)),
    'Game.graceLive no longer matches isOnTime\'s grace window');
  assert.ok(html.includes(norm('function graceLiveNow(){ return challengeDay!=null && challengeStartDay===challengeDay && todayIndex()===challengeDay+1; }')),
    'web graceLiveNow no longer matches isOnTime\'s grace window');
  // ...and both reset confirmations lead with the loss that no replay can undo.
  for (const [name, src] of [['ContentView.swift', content], ['index.html', html], ['DailyView.swift', daily]]) {
    assert.ok(src.includes('can never earn ⏰'),
      `${name}: a live ⏰ grace can be destroyed without saying that the day can never earn it again`);
  }
  // the calendar legend names the pip, as a DOT (it is drawn the same size/colour as the gold
  // tier dot, so an ⏰ glyph alone would not teach it).
  assert.ok(daily.includes(norm(`HStack(spacing: 3) {
                        Circle().fill(Theme.gold).frame(width: 5, height: 5)
                        Text("⏰ Same-day")
                    }`)), 'iOS calendar legend lost its ⏰ pip entry');
  assert.ok(html.includes(norm('<span><i class="d3 legpip"></i>⏰ Same-day</span>')),
    'web calendar legend lost its ⏰ pip entry');
  // the win overlay names the day whenever it is not today's challenge.
  assert.ok(html.includes(norm("const winDay = (w.dailyDay!=null && w.dailyDay!==todayIndex()) ? `${fmtDayLabel(w.dailyDay)}: ` : '';")),
    'web win overlay no longer names a past-day / grace win');
  assert.ok(html.includes(norm('dailyDay: daily ? daily.day : null')),
    'web pendingWin no longer carries the day it scored');
});

// ---- leaving a demo lands on the SCORED challenge, still as a fresh attempt ----
// ux/WF-6:demo-exit-drops-challenge-binding — every exit from a how-to-win demo (mid-line Stop and
// post-line Done alike) dropped the player on a CASUAL deal of the day's seed, so "tap Done to try
// it yourself" banked no tier, no streak and no ⏰. The trap is the naive re-arm: the FRESH re-deal
// must stay, or a player could watch the app's own line and bank a tier on it. Both platforms
// therefore re-bind through playChallenge, which routes through deal() and zeroes the board, the
// clock, the move count and the telemetry.
test('demo exit re-binds the day as a FRESH attempt (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const game = read('Model/Game.swift');
  const daily = read('Views/DailyView.swift');
  // the day travels from the card that opened the demo...
  assert.ok(daily.includes(norm('game.showSolution(seed, tier: tier, label: label, day: day)')),
    'iOS demo pill no longer hands showSolution the day it was opened from');
  assert.ok(html.includes(norm("`<button class=\"btn dshow\" onclick=\"showSolution(${c.seed},'${tier}','${esc(label)}',${day})\">${txt}</button>`")),
    'web demo button no longer hands showSolution the day it was opened from');
  // ...is stored only AFTER the deal that clears it...
  assert.ok(game.includes(norm('demoDay = day                // AFTER deal(), which clears it — see endDemo()')),
    'iOS showSolution no longer records the demo\'s day after its deal');
  assert.ok(html.includes(norm('demoDay = (typeof day==="number") ? day : null;')),
    'web showSolution no longer records the demo\'s day after its deal');
  // ...and the re-bind goes through playChallenge, never through a resume of the demo board.
  assert.ok(game.includes(norm('demoDay = nil')), 'iOS deal() no longer clears demoDay');
  assert.ok(html.includes(norm('challengeStartDay=null; demoDay=null;')), 'web deal() no longer clears demoDay');
});

// ---- the app never spends a tier the player has not spent (bug/WF-4, both halves) ----
// Auto-play and the auto-finish cascade are the only two places the app moves cards by itself, and
// on a scored daily both were taking tiers with no player input at all. The behavioural ground
// truth lives in tests/autofinish-tiers.test.mjs; these pin that both platforms actually consult
// it, and — just as important — that the fix is a REFUSAL and not a reorder: neither cascade may
// ever choose a different end to protect an objective, because that is the app playing the
// challenge for the player.
test('auto-play and auto-finish refuse (never reorder) when a live tier is at stake (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const game = read('Model/Game.swift');
  const content = read('Views/ContentView.swift');
  // auto-play looks one send ahead and skips the card rather than sending it elsewhere.
  assert.ok(game.includes(norm('if autoSendWouldBreakTier(c, toUp: toUp) { continue }')),
    'iOS auto-play no longer declines a send that breaks a live tier');
  assert.ok(html.includes(norm('if(autoSendWouldBreakTier(c,toUp)) continue;')),
    'web auto-play no longer declines a send that breaks a live tier');
  assert.ok(game.includes(norm('return (silverWasLive && objViolated(ch.silver, t)) || (goldWasLive && objViolated(ch.gold, t))')),
    'iOS look-ahead no longer compares live-before against violated-after');
  assert.ok(html.includes(norm('return (sLive && objViolated(ch.silver,t)) || (gLive && objViolated(ch.gold,t));')),
    'web look-ahead no longer compares live-before against violated-after');
  // The `WasLive`/`Live` half of that comparison is the load-bearing one: hard-code it to false and
  // both refusals silently switch off (auto-play denies Gold again, the finish prompt fires
  // mid-flawless-line) while every other pin here still passes. tests/autofinish-tiers.test.mjs now
  // runs the web pair for real; iOS has no test target, so these lines are pinned on both.
  const count = (hay, needle) => hay.split(norm(needle)).length - 1;
  // BOTH iOS refusals (autoSendWouldBreakTier and autoFinishTierCost) must compute it, hence 2.
  assert.equal(count(game, 'let silverWasLive = !objViolated(ch.silver, t) let goldWasLive = !objViolated(ch.gold, t)'), 2,
    'an iOS refusal stopped computing which tiers are still live — hard-coding those to false switches the refusal off silently');
  assert.equal(count(html, 'const sLive=!objViolated(ch.silver,base), gLive=!objViolated(ch.gold,base);'), 2,
    'a web refusal stopped computing which tiers are still live — hard-coding those to false switches the refusal off silently');
  // ...and the end it would use is the one the engine already picked, never a "better" one.
  assert.ok(game.includes(norm('let toUp = canFoundationUp(c)')), 'iOS auto-play no longer takes the engine\'s end');
  assert.ok(html.includes(norm('const toUp=canFoundationUp(c);')), 'web auto-play no longer takes the engine\'s end');
  // auto-finish: not offered, not auto-run, while it would cost a live tier.
  assert.ok(game.includes(norm('guard autoFinishTierCost().isEmpty else { return }')),
    'iOS maybeAutoFinish no longer withholds a tier-costing cascade');
  assert.ok(html.includes(norm('if(autoFinishTierCost().length) return;')),
    'web maybeAutoFinish no longer withholds a tier-costing cascade');
  // ...but still reachable by hand, after naming the price.
  assert.ok(content.includes(norm('let cost = game.autoFinishTierCost()')) &&
            content.includes(norm('if cost.isEmpty { withAnimation { game.runAutoFinish() } } else { finishCost = cost }')),
    'the iOS Finish button no longer asks before a tier-costing cascade');
  assert.ok(html.includes(norm('const cost=autoFinishTierCost();')) && html.includes('Finish now and miss'),
    'the web Finish button no longer asks before a tier-costing cascade');
  // the cascade simulation must keep predicting in the EXECUTION order (one card, then restart from
  // the cells) — a sweep-order prediction can predict a different split from the one that runs.
  assert.ok(game.includes(norm('if sent { continue }')), 'iOS simulateAutoFinish left sendOneHome\'s order');
  assert.ok(html.includes(norm('if(sent) continue;')), 'web simulateAutoFinish left sendOneHome\'s order');
});

// ---- the Auto-play pill is a preference, not a move (ux/WF-8:autoplay-toggle-mutates-scored-game) ----
// Tapping it mid-game instantly played two cards and advanced the move counter 92 -> 94 on a scored
// daily run. Causeway scores move counts (par, "within your first N moves" objectives, Wins
// best-moves), so a settings tap must not spend them: turning it ON now takes effect from the
// player's next move. Turning it OFF still halts a running chain at once — that direction only ever
// prevents moves.
test('turning Auto-play on does not move cards (no web↔iOS drift)', () => {
  const html = norm(readFileSync(join(REPO, 'index.html'), 'utf8'));
  const game = read('Model/Game.swift');
  assert.ok(game.includes(norm(`didSet {
            UserDefaults.standard.set(autoplayOn, forKey: "causeway.autoplay")
            if !autoplayOn { stopAutoplayPending() }
        }`)), 'the iOS Auto-play setter is back to firing a sweep (or stopped halting one)');
  assert.ok(html.includes(norm(`autoplayOn=!autoplayOn;
  lsSet("causeway.autoplay", autoplayOn?"on":"off");
  refreshAutoplayBtn();
  if(!autoplayOn) stopAutoplay();`)), 'the web Auto-play toggle is back to firing a sweep');
  // autoplay must still be armed by real play — the setting is not simply dead.
  assert.ok(game.includes(norm('if !finishing && !promptAutoFinish { runAutoplay() }')),
    'iOS commit() no longer arms auto-play after a player move');
  assert.ok(html.includes(norm('if(!finishing && !finishPromptOpen) runAutoplay();')),
    'web commitMove no longer arms auto-play after a player move');
});
