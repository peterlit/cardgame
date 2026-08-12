// Causeway rules + move model for the offline solver. Ported VERBATIM (behaviour) from the
// shipped web engine (index.html "rules" section) so a certification means the same thing the
// app enforces. Pure functions over plain state; no app/UI coupling.
//
// State: { tableau: Card[][8], cells: (Card|null)[3], up: int[4], down: int[4] }
// Card:  { suit, rank, color:'red'|'black', id }   (as produced by tests/engine.mjs deal())

export const BLACK_SUITS = [0, 3], RED_SUITS = [1, 2];

export function canUp(up, down, c)   { return c.rank === up[c.suit] + 1 && c.rank < down[c.suit]; }
export function canDown(up, down, c) { return c.rank === down[c.suit] - 1 && c.rank > up[c.suit]; }
export function isWon(s) { return [0, 1, 2, 3].every(x => s.down[x] === s.up[x] + 1); }

// A movable run is alternating-colour and monotonic by 1 — descending OR ascending.
export function isSeqHead(t, idx) {
  if (idx < 0 || idx >= t.length) return false;
  if (idx === t.length - 1) return true;
  const a = t[idx], b = t[idx + 1];
  if (a.color === b.color) return false;
  let dir;
  if (a.rank === b.rank + 1) dir = 'desc';
  else if (a.rank === b.rank - 1) dir = 'asc';
  else return false;
  for (let i = idx; i < t.length - 1; i++) {
    const x = t[i], y = t[i + 1];
    if (x.color === y.color) return false;
    if (dir === 'desc' && x.rank !== y.rank + 1) return false;
    if (dir === 'asc' && x.rank !== y.rank - 1) return false;
  }
  return true;
}
export function runDir(cards) {
  if (cards.length < 2) return 'single';
  return cards[0].rank === cards[1].rank + 1 ? 'desc' : 'asc';
}
export function tailDir(t) {
  if (t.length < 2) return 'single';
  const a = t[t.length - 2], b = t[t.length - 1];
  if (a.color !== b.color && a.rank === b.rank + 1) return 'desc';
  if (a.color !== b.color && a.rank === b.rank - 1) return 'asc';
  return 'single';
}
// Can `cards` (a valid run) stack onto column `t`? Mirrors canStackTableau in index.html,
// including the "can't reverse an established pile" tailDir rule.
export function canStackTableau(t, cards) {
  if (t.length === 0) return true;
  const top = t[t.length - 1], head = cards[0];
  if (head.color === top.color) return false;
  if (Math.abs(head.rank - top.rank) !== 1) return false;
  const conn = head.rank === top.rank - 1 ? 'desc' : 'asc';
  const rdir = runDir(cards);
  if (rdir !== 'single' && rdir !== conn) return false;
  const tdir = tailDir(t);
  if (tdir !== 'single' && tdir !== conn) return false;
  return true;
}
export function maxMovable(freeCells, emptyCols, targetEmpty) {
  const e = emptyCols - (targetEmpty ? 1 : 0);
  return (freeCells + 1) * Math.pow(2, Math.max(0, e));
}

// ---- safe auto-play (identical rule to the app) ----
function rankOnFound(up, down, suit, r) { if (r <= 0) return true; return up[suit] >= r || down[suit] <= r; }
export function isSafeAutoplay(up, down, c) {
  if (!(canUp(up, down, c) || canDown(up, down, c))) return false;
  const opp = c.color === 'red' ? BLACK_SUITS : RED_SUITS;
  return opp.every(x => rankOnFound(up, down, x, c.rank - 1) && rankOnFound(up, down, x, c.rank + 1));
}

// ---- state helpers ----
export function cloneState(s) {
  return { tableau: s.tableau.map(c => c.slice()), cells: s.cells.slice(), up: s.up.slice(), down: s.down.slice() };
}
// Canonical key: columns and cells are order-independent, so sort them (huge transposition dedup).
export function stateKey(s) {
  const cols = s.tableau.map(c => c.map(x => x.id).join(',')).sort().join('|');
  const cells = s.cells.map(x => (x ? x.id : -1)).sort((a, b) => a - b).join(',');
  return s.up.join(',') + '/' + s.down.join(',') + '/' + cells + '/' + cols;
}

// Apply one move descriptor, returning a NEW state (does not mutate).
//   {k:'F', from:{col}|{cell}, end:'up'|'down'}   foundation send
//   {k:'T', src, idx, dst}                        move run t[src][idx..] onto column dst
//   {k:'C', src}                                  top of column src -> first empty cell
//   {k:'X', cell, dst}                            free cell -> column dst
export function applyMove(s, m) {
  const t = s.tableau.map(c => c.slice());
  const cells = s.cells.slice();
  const up = s.up.slice(), down = s.down.slice();
  if (m.k === 'F') {
    let card;
    if (m.from.col !== undefined) card = t[m.from.col].pop();
    else { card = cells[m.from.cell]; cells[m.from.cell] = null; }
    if (m.end === 'up') up[card.suit] = card.rank; else down[card.suit] = card.rank;
  } else if (m.k === 'T') {
    const run = t[m.src].splice(m.idx);
    for (const c of run) t[m.dst].push(c);
  } else if (m.k === 'C') {
    const card = t[m.src].pop();
    cells[cells.indexOf(null)] = card;
  } else if (m.k === 'X') {
    const card = cells[m.cell]; cells[m.cell] = null;
    t[m.dst].push(card);
  }
  return { tableau: t, cells, up, down };
}

// All legal moves from `s`, gated by a constraint (see solve.mjs). `cellUses` = cumulative
// cell parks so far on this path (for the ≤K-cells constraint). Foundation moves first.
export function legalMoves(s, cellUses, constraint) {
  const { tableau, cells, up, down } = s;
  const moves = [];
  for (let col = 0; col < tableau.length; col++) {
    const t = tableau[col]; if (!t.length) continue;
    const c = t[t.length - 1];
    if (canUp(up, down, c) && constraint.allowFoundation(s, c, 'up')) moves.push({ k: 'F', from: { col }, end: 'up' });
    else if (canDown(up, down, c) && constraint.allowFoundation(s, c, 'down')) moves.push({ k: 'F', from: { col }, end: 'down' });
  }
  for (let i = 0; i < cells.length; i++) {
    const c = cells[i]; if (!c) continue;
    if (canUp(up, down, c) && constraint.allowFoundation(s, c, 'up')) moves.push({ k: 'F', from: { cell: i }, end: 'up' });
    else if (canDown(up, down, c) && constraint.allowFoundation(s, c, 'down')) moves.push({ k: 'F', from: { cell: i }, end: 'down' });
  }
  const emptyCols = tableau.reduce((n, c) => n + (c.length === 0 ? 1 : 0), 0);
  const freeCells = cells.reduce((n, c) => n + (c === null ? 1 : 0), 0);
  for (let src = 0; src < tableau.length; src++) {
    const t = tableau[src]; if (!t.length) continue;
    for (let idx = 0; idx < t.length; idx++) {
      if (!isSeqHead(t, idx)) continue;
      const run = t.slice(idx);
      for (let dst = 0; dst < tableau.length; dst++) {
        if (dst === src) continue;
        const dstEmpty = tableau[dst].length === 0;
        if (idx === 0 && dstEmpty) continue;   // pointless whole-column relocation
        if (!canStackTableau(tableau[dst], run)) continue;
        if (run.length > maxMovable(freeCells, emptyCols, dstEmpty)) continue;
        moves.push({ k: 'T', src, idx, dst });
      }
    }
  }
  if (cellUses < constraint.cellBudget && cells.indexOf(null) >= 0) {
    for (let src = 0; src < tableau.length; src++) if (tableau[src].length) moves.push({ k: 'C', src });
  }
  for (let i = 0; i < cells.length; i++) {
    const c = cells[i]; if (!c) continue;
    for (let dst = 0; dst < tableau.length; dst++) if (canStackTableau(tableau[dst], [c])) moves.push({ k: 'X', cell: i, dst });
  }
  return moves;
}
