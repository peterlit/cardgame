// Zero-move save: a challenge tapped Play on day D and never moved (Game.playChallenge persists
// exactly this: challengeDay/challengeStartDay set, moveCount 0, started false).
import { dealState } from '../../tools/solver/solve.mjs';
import { dailyChallenge } from '../../tests/daily.mjs';
import { readFileSync } from 'node:fs';
const pool = JSON.parse(readFileSync(new URL('../../data/daily-pool.json', import.meta.url)));
const args = Object.fromEntries(process.argv.slice(2).join(' ').split('--').filter(Boolean)
  .map(s => s.trim().split(/\s+/)).map(([k, v]) => [k, v]));
const day = +args.day;
const ch = dailyChallenge(day, pool);
const s = dealState(ch.seed);
const card = c => ({ suit: c.suit, rank: c.rank });
const save = { seed: ch.seed, tableau: s.tableau.map(col => col.map(card)),
  cells: s.cells.map(c => c ? card(c) : null), up: s.up, down: s.down,
  moveCount: 0, elapsed: 0, started: false,
  telem: { cellUses: 0, undos: 0, maxRunMoved: 0, foundationOrder: [] },
  autoFinishDeferred: false,
  challengeDay: day, challengeStartDay: (args.startDay !== undefined ? +args.startDay : day) };
console.error(`[zero_move] day ${day} seed ${ch.seed} moveCount 0 challengeDay ${save.challengeDay} startDay ${save.challengeStartDay}`);
console.log(JSON.stringify(save));
