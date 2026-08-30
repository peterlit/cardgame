// The app is allowed to move cards on the player's behalf in exactly two places — safe auto-play
// and the auto-finish cascade — and on a scored daily BOTH of them were spending tiers the player
// had not lost:
//
//   bug/WF-4:autoplay-denies-daily-gold        one tap on the (default-ON) Auto-play pill at day
//                                              29's certified-flawless position sent 8♠ to the DOWN
//                                              foundation and killed 🥇 + 🌟 with zero card input.
//   bug/WF-4:autofinish-cascade-can-deny-gold  the "Ready to finish" prompt fires at the FIRST
//                                              finishable position, which on many days is inside
//                                              the flawless line — accepting it awards 🥉🥈 and no 🥇.
//
// Neither is fixed by making the app play better: reordering a cascade's sends, or steering
// auto-play toward an objective, would have the app quietly play the challenge for the player. Both
// fixes are refusals — don't send, don't offer — and both refusals need to know when a send is
// costly. This file pins the ground truth those refusals are computed from, on the canonical Node
// engine, so a future change to the cascade or to the checkers can't quietly move it.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { applyMove, isWon } from '../tools/solver/rules.mjs';
import { dealState } from '../tools/solver/solve.mjs';
import { simulateAutoFinish, isSafeAutoplay, canFoundationUp } from './engine.mjs';
import { dailyChallenge, evaluateChallenge } from './daily.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const pool = JSON.parse(readFileSync(join(REPO, 'data/daily-pool.json'), 'utf8'));
const sol = JSON.parse(readFileSync(join(REPO, 'data/daily-solutions.json'), 'utf8'));

function parseToken(tok) {
  const f = tok.split(',');
  switch (f[0]) {
    case 'F': return { k: 'F', from: { col: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'G': return { k: 'F', from: { cell: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'T': return { k: 'T', src: +f[1], idx: +f[2], dst: +f[3] };
    case 'C': return { k: 'C', src: +f[1] };
    case 'X': return { k: 'X', cell: +f[1], dst: +f[2] };
    default: throw new Error('bad token ' + tok);
  }
}

// Walk a baked line one move at a time, yielding the board + the telemetry the checkers read at
// every prefix (position 0 = the fresh deal, position n = the whole line played).
function* walk(seed, tokens) {
  let s = dealState(seed);
  const t = { won: false, moves: 0, elapsed: 0, cellUses: 0, undos: 0, foundationOrder: [], maxRunMoved: 0 };
  yield { state: s, telem: { ...t, foundationOrder: t.foundationOrder.slice() } };
  for (const tok of tokens.split(' ')) {
    const f = tok.split(',');
    t.moves++;
    if (f[0] === 'F') { const col = s.tableau[+f[1]]; const c = col[col.length - 1]; t.foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: t.moves }); }
    else if (f[0] === 'G') { const c = s.cells[+f[1]]; t.foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: t.moves }); }
    else if (f[0] === 'C') { t.cellUses++; }
    else if (f[0] === 'T') { t.maxRunMoved = Math.max(t.maxRunMoved, s.tableau[+f[1]].length - (+f[2])); }
    s = applyMove(s, parseToken(tok));
    yield { state: s, telem: { ...t, won: isWon(s), foundationOrder: t.foundationOrder.slice() } };
  }
}

// What the app would score if the player accepted the cascade from `position`.
function finishFrom({ state, telem }, ch) {
  const sim = simulateAutoFinish(state, telem.moves);
  // A board that is ALREADY solved is not an "offer to finish" — the app gates on !checkWin() for
  // exactly this reason. Only positions with cards still out are the cascade's business.
  if (!sim.won || sim.events.length === 0) return null;
  return evaluateChallenge(ch, { ...telem, won: true, moves: sim.moves,
                                 foundationOrder: telem.foundationOrder.concat(sim.events) });
}

const flawlessDays = () => pool.days
  .map((d, i) => ({ day: i, seed: d.seed, line: sol.solutions[String(d.seed)]?.flawless }))
  .filter(d => d.line);

// ---------------------------------------------------------------------------------------------
// The measurement the finding was filed on, as an executable canon. "Tier-preserving" means: there
// is SOME position on the day's certified flawless line where the cascade both wins and keeps every
// tier the line was earning. On the days below there is none — which is exactly why the app must
// not auto-offer the cascade purely because the board became finishable.
test('the greedy finish cascade cannot preserve the tiers on every day (canon: days 21, 24, 27)', () => {
  const noTierPreservingFinish = [];
  const ok = [];
  for (const { day, seed, line } of flawlessDays()) {
    if (day < 20 || day > 29) continue;   // the range the round-1 pass measured in the app
    const ch = dailyChallenge(day, pool);
    let keeps = false;
    for (const pos of walk(seed, line)) {
      const res = finishFrom(pos, ch);
      if (res && res.silver && res.gold) { keeps = true; break; }
    }
    (keeps ? ok : noTierPreservingFinish).push(day);
  }
  assert.deepEqual(noTierPreservingFinish, [21, 24, 27],
    'the set of days whose flawless line has NO tier-preserving cascade moved — re-verify the auto-finish gate');
  assert.deepEqual(ok, [20, 22, 23, 25, 26, 28, 29],
    'the set of days whose flawless line HAS a tier-preserving cascade moved — the gate must stay a refusal, not a blanket block');
});

// The in-app reproduction, offline: the app raised "Ready to finish" at the first finishable
// position of day 21's 87-move flawless line and the cascade then denied Gold. The gate the fix
// installs is "would finishing NOW cost a tier that is still live?", so this pins that the answer
// at that position is yes.
test('day 21: the first finishable position wins but loses Gold — the app must not offer it there', () => {
  const day = 21, ch = dailyChallenge(day, pool);
  const line = sol.solutions[String(pool.days[day].seed)].flawless;
  let first = null, atMove = null;
  for (const pos of walk(pool.days[day].seed, line)) {
    const res = finishFrom(pos, ch);
    if (res) { first = res; atMove = pos.telem.moves; break; }
  }
  assert.ok(first, 'day 21 never becomes finishable along its own flawless line');
  assert.equal(first.bronze, true, 'the cascade does win from there — which is why it was offered');
  assert.equal(first.gold, false, 'day 21 should still lose Gold to the greedy cascade at its first finishable position');
  assert.ok(atMove < line.split(' ').length,
    'the offer arrives BEFORE the flawless line ends — that is the whole defect');
});

// The control: the guard must be a refusal in a real, computable condition, not a blanket block on
// finishing during a challenge. Day 29's line does have a position where the cascade keeps
// everything, and the app must still offer it there.
test('day 29: the cascade keeps every tier from the tail of its flawless line (the guard is not a blanket block)', () => {
  const day = 29, ch = dailyChallenge(day, pool);
  const line = sol.solutions[String(pool.days[day].seed)].flawless;
  const keeping = [];
  for (const pos of walk(pool.days[day].seed, line)) {
    const res = finishFrom(pos, ch);
    if (res && res.silver && res.gold && res.flawless) keeping.push(pos.telem.moves);
  }
  assert.ok(keeping.length > 0, 'day 29 lost its tier-preserving finish — the day-29 in-app control would now fail too');
});

// ---------------------------------------------------------------------------------------------
// Safe auto-play, the other place the app moves cards by itself. On day 29 the Gold objective is
// `split-at` R=8 (A-8 up, 9-K down), and at the flawless line's tail the only legal end for the 8♠
// is DOWN — so auto-play, which never chooses an end (only one is ever legal on a non-closing
// card), sends it there and the split is wrong forever. The look-ahead the fix installs is exactly
// the checker's own violation rule for the family, so pin that the rule fires here.
test('day 29: an unguarded safe auto-play send would break the day\'s Gold split (the look-ahead must refuse it)', () => {
  const day = 29, ch = dailyChallenge(day, pool);
  assert.equal(ch.gold.id, 'split-at', 'day 29 Gold is no longer a split-at objective — re-derive this case');
  const R = ch.gold.param.R;
  const line = sol.solutions[String(pool.days[day].seed)].flawless;
  // The canonical fail-fast rule for split-at (Daily.swift objViolated / index.html objViolated):
  // exceed R up-sends, or 13-R down-sends, for any suit and the exact split can never be reached.
  const violated = fo => {
    const u = [0, 0, 0, 0], d = [0, 0, 0, 0];
    for (const e of fo) { if (e.end === 'up') u[e.suit]++; else d[e.suit]++; }
    return u.some(x => x > R) || d.some(x => x > 13 - R);
  };
  let refusals = 0, unguardedBreaks = 0;
  for (const { state, telem } of walk(pool.days[day].seed, line)) {
    if (violated(telem.foundationOrder)) break;   // the line itself never gets here; belt and braces
    const cards = [
      ...state.cells.map((c, i) => c && { c, where: `cell${i}` }),
      ...state.tableau.map((t, i) => t.length && { c: t[t.length - 1], where: `col${i}` }),
    ].filter(Boolean);
    for (const { c } of cards) {
      if (!isSafeAutoplay(state, c)) continue;
      const toUp = canFoundationUp(state, c);
      const after = telem.foundationOrder.concat([{ suit: c.suit, rank: c.rank, end: toUp ? 'up' : 'down', moveIdx: telem.moves + 1 }]);
      if (violated(after)) { unguardedBreaks++; refusals++; }
    }
  }
  assert.ok(unguardedBreaks > 0,
    'no safe-autoplay send along day 29\'s flawless line breaks the Gold split any more — the reproduction moved, so re-verify Game.autoSendWouldBreakTier');
  assert.equal(refusals, unguardedBreaks,
    'every breaking send must be refused by the look-ahead — a send that breaks a live tier may never be made automatically');
});
