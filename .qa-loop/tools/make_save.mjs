// Build a Causeway SavedGame ("causeway.game" in UserDefaults) parked ONE TAP from a win,
// by replaying a baked solution line from data/daily-solutions.json and stopping at the first
// position where the app's Finish/auto-finish cascade would win AND still earn the tiers asked for.
// Used with inject_save.py to reach win-time surfaces (⏰ / 🌟 / calendar / streak cards) without
// playing 80+ moves by hand. Fixture only — the line is the app's own certified line.
//
//   node .qa-loop/tools/make_save.mjs --day 29 --tier flawless --challengeDay 29 --startDay 29
//   node .qa-loop/tools/make_save.mjs --day 28 --tier flawless --challengeDay 28 --startDay 28
//   ... --challengeDay none    → a casual (unscored) save
import { readFileSync } from 'node:fs';
import { applyMove, isWon } from '../../tools/solver/rules.mjs';
import { dealState } from '../../tools/solver/solve.mjs';
import { dailyChallenge, evaluate } from '../../tests/daily.mjs';
import { autoFinishWouldWin, sendOneHomeStep } from '../../tests/engine.mjs';

const args = Object.fromEntries(process.argv.slice(2).join(' ').split('--').filter(Boolean)
  .map(s => s.trim().split(/\s+/)).map(([k, v]) => [k, v]));
const pool = JSON.parse(readFileSync(new URL('../../data/daily-pool.json', import.meta.url)));
const sols = JSON.parse(readFileSync(new URL('../../data/daily-solutions.json', import.meta.url)));

const day = +args.day;
const tier = args.tier || 'flawless';
const ch = dailyChallenge(day, pool);
if (!ch) throw new Error('no challenge for day ' + day);
const tokens = sols.solutions[String(ch.seed)][tier].split(' ');

function parseToken(tok) {
  const f = tok.split(',');
  switch (f[0]) {
    case 'F': return { k: 'F', from: { col: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'G': return { k: 'F', from: { cell: +f[1] }, end: +f[2] ? 'down' : 'up' };
    case 'T': return { k: 'T', src: +f[1], idx: +f[2], dst: +f[3] };
    case 'C': return { k: 'C', src: +f[1] };
    case 'X': return { k: 'X', cell: +f[1], dst: +f[2] };
  }
  throw new Error('bad token ' + tok);
}
const clone = s => ({ tableau: s.tableau.map(c => c.slice()), cells: s.cells.slice(), up: s.up.slice(), down: s.down.slice() });

// Simulate the app's finish cascade from `s`, extending telemetry; returns the attempt record.
function afterFinish(s, telem, moves) {
  const st = clone(s), fo = telem.foundationOrder.slice();
  let m = moves;
  while (true) {
    const before = { up: st.up.slice(), down: st.down.slice() };
    if (!sendOneHomeStep(st)) break;
    m++;
    for (let suit = 0; suit < 4; suit++) {
      if (st.up[suit] !== before.up[suit]) fo.push({ suit, rank: st.up[suit], end: 'up', moveIdx: m });
      if (st.down[suit] !== before.down[suit]) fo.push({ suit, rank: st.down[suit], end: 'down', moveIdx: m });
    }
  }
  return { won: isWon(st), moves: m, elapsed: 90, cellUses: telem.cellUses, undos: 0,
           foundationOrder: fo, maxRunMoved: telem.maxRunMoved };
}

let s = dealState(ch.seed);
const telem = { cellUses: 0, undos: 0, maxRunMoved: 0, foundationOrder: [] };
let picked = null;
for (let i = 0; i < tokens.length; i++) {
  const tok = tokens[i], f = tok.split(',');
  const moves = i + 1;
  if (f[0] === 'F') { const col = s.tableau[+f[1]]; const c = col[col.length - 1]; telem.foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
  else if (f[0] === 'G') { const c = s.cells[+f[1]]; telem.foundationOrder.push({ suit: c.suit, rank: c.rank, end: +f[2] ? 'down' : 'up', moveIdx: moves }); }
  else if (f[0] === 'C') telem.cellUses++;
  else if (f[0] === 'T') telem.maxRunMoved = Math.max(telem.maxRunMoved, s.tableau[+f[1]].length - (+f[2]));
  s = applyMove(s, parseToken(tok));
  if (isWon(s)) break;                       // never inject an already-won board (restore() rejects it)
  if (!autoFinishWouldWin(s)) continue;
  const a = afterFinish(s, telem, moves);
  const silver = evaluate(ch.silver, a), gold = evaluate(ch.gold, a);
  const need = a.won && (tier === 'flawless' ? (silver && gold)
                        : tier === 'silver' ? silver : tier === 'gold' ? gold : true);
  if (need) { picked = { i, moves, state: clone(s), telem: JSON.parse(JSON.stringify(telem)), a, silver, gold }; break; }
}
if (!picked) throw new Error('no finishable truncation of the ' + tier + ' line keeps its tiers');

const card = c => ({ suit: c.suit, rank: c.rank });
const cd = args.challengeDay === 'none' ? null : (args.challengeDay !== undefined ? +args.challengeDay : day);
const sd = args.startDay === 'none' ? null : (args.startDay !== undefined ? +args.startDay : cd);
const save = {
  seed: ch.seed,
  tableau: picked.state.tableau.map(col => col.map(card)),
  cells: picked.state.cells.map(c => c ? card(c) : null),
  up: picked.state.up, down: picked.state.down,
  moveCount: picked.moves, elapsed: 90, started: true,
  telem: picked.telem, autoFinishDeferred: false,
};
if (cd !== null) save.challengeDay = cd;
if (sd !== null) save.challengeStartDay = sd;
console.error(`[make_save] day ${day} seed ${ch.seed} tier ${tier}: stop at move ${picked.moves}/${tokens.length}; ` +
  `finish → won=${picked.a.won} silver=${picked.silver} gold=${picked.gold} finalMoves=${picked.a.moves} ` +
  `challengeDay=${cd} startDay=${sd}`);
console.log(JSON.stringify(save));
