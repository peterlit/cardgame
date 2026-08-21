// Offline Causeway solver: certifies a deal's winnability + reference par, and — for each
// constraint objective — whether a winning line exists that obeys it. Runs OFFLINE only (build
// tool); never shipped. See docs/solver.md.
//
// Search: weighted-A* best-first (f = g + 2h) over a transposition table, with a burial-aware
// heuristic and an auto-safe macro (sends provably-safe cards home, gated by the constraint).
import { deal } from '../../tests/engine.mjs';
import { applyMove, legalMoves, isWon, isSafeAutoplay, canUp, stateKey } from './rules.mjs';

// ---- objectives ----
// allowFoundation() gates foundation sends (incl. auto-safe) so an ordering rule can't be broken.
// cellBudget caps cumulative cell parks. wantDownOpen is a prefix goal (all downs opened within N
// moves). Universal objectives (move/time caps, no-undo, manual win) need no certification — `par`
// calibrates them — so they aren't here.
const allAcesUp = s => s.up.every(u => u >= 1);
export const kingsDown = s => s.down.every(d => d <= 13);
const jacksDown = s => s.down.every(d => d <= 11);
const started = (s, T) => s.up[T] > 0 || s.down[T] < 14;
const suitDone = (s, T) => s.down[T] === s.up[T] + 1;
const blockAceUpUntil = cond => (s, c, end) => !(end === 'up' && c.rank === 1) || cond(s);

const DOWN_OPENERS_N = 20;
const BIG_MOVE_N = 5;   // 'one-big-move': relocate a run of >= 5 cards at least once
export const GOLD_GRADE = ['no-cells', 'aces-first', 'kings-first', 'jacks-down-first', 'suits-top-down', 'suit-sprint', 'split-even', 'no-down-foundation', 'no-up-foundation', 'one-big-move'];
export const SILVER_GRADE = ['cells-le-1', 'cells-le-2', 'down-openers-20', 'down-heavy', 'no-supermoves'];
export const CERTIFIED = [...GOLD_GRADE, ...SILVER_GRADE];

export function objective(id) {
  const base = { allowFoundation: () => true, cellBudget: Infinity, wantDownOpen: false,
                 maxRun: Infinity, wantBigMove: false };
  switch (id) {
    case 'unconstrained':    return { ...base };
    case 'no-cells':         return { ...base, cellBudget: 0 };
    case 'cells-le-1':       return { ...base, cellBudget: 1 };
    case 'cells-le-2':       return { ...base, cellBudget: 2 };
    case 'aces-first':       return { ...base, allowFoundation: (s, c) => c.rank === 1 || allAcesUp(s) };
    case 'kings-first':      return { ...base, allowFoundation: blockAceUpUntil(kingsDown) };
    case 'jacks-down-first': return { ...base, allowFoundation: blockAceUpUntil(jacksDown) };
    case 'suits-top-down':   return { ...base, allowFoundation: (s, c, end) => !(end === 'up' && c.rank === 1) || s.down[c.suit] <= 13 };
    case 'suit-sprint':      return {
      ...base,
      allowFoundation: (s, c) => {
        const S = c.suit;
        if (started(s, S)) return true;
        for (let T = 0; T < 4; T++) if (T !== S && started(s, T) && !suitDone(s, T)) return false;
        return true;
      },
    };
    case 'down-openers-20':  return { ...base, wantDownOpen: true, downOpenN: DOWN_OPENERS_N };
    // --- split point: where a suit's two halves meet -------------------------------------
    // A1: every suit splits exactly A-7 up / 8-K down. Gate both ends; the win condition
    // (down === up + 1) then forces up=7, down=8 on all four suits.
    case 'split-even':       return { ...base, allowFoundation: (s, c, end) => end === 'up' ? c.rank <= 7 : c.rank >= 8 };
    // A2: at least 8 of every suit comes from the King end => the up pile may never pass 5.
    case 'down-heavy':       return { ...base, allowFoundation: (s, c, end) => end !== 'up' || c.rank <= 5 };
    // --- one-end games (B3/B4). Legal because down === up + 1 still holds at 14/13 and 1/0.
    case 'no-down-foundation': return { ...base, allowFoundation: (s, c, end) => end !== 'down' };
    case 'no-up-foundation':   return { ...base, allowFoundation: (s, c, end) => end !== 'up' };
    // --- move shape ----------------------------------------------------------------------
    case 'no-supermoves':    return { ...base, maxRun: 1 };
    case 'one-big-move':     return { ...base, wantBigMove: true, bigMoveN: BIG_MOVE_N };
    default: throw new Error('unknown objective ' + id);
  }
}

// Force all currently-safe cards home (each counts as a move), gated by the constraint so an
// ordering objective isn't broken by an auto-send. Matches the app's auto-play and cuts the search.
function autoSafe(s, constraint) {
  let st = s, moves = 0, changed = true;
  const applied = [];   // the exact auto-safe foundation sends, in order (for path reconstruction)
  while (changed) {
    changed = false;
    for (let i = 0; i < st.cells.length && !changed; i++) {
      const c = st.cells[i];
      if (c && isSafeAutoplay(st.up, st.down, c)) {
        const end = canUp(st.up, st.down, c) ? 'up' : 'down';
        if (constraint.allowFoundation(st, c, end)) { const m = { k: 'F', from: { cell: i }, end }; st = applyMove(st, m); applied.push(m); moves++; changed = true; }
      }
    }
    for (let col = 0; col < st.tableau.length && !changed; col++) {
      const t = st.tableau[col]; if (!t.length) continue;
      const c = t[t.length - 1];
      if (isSafeAutoplay(st.up, st.down, c)) {
        const end = canUp(st.up, st.down, c) ? 'up' : 'down';
        if (constraint.allowFoundation(st, c, end)) { const m = { k: 'F', from: { col }, end }; st = applyMove(st, m); applied.push(m); moves++; changed = true; }
      }
    }
  }
  return { state: st, moves, applied };
}

// h = cards not yet home + burial depth of each foundation's next-needed card (guides unburying).
function heuristic(s) {
  let home = 0;
  for (let x = 0; x < 4; x++) home += s.up[x] + (14 - s.down[x]);
  let h = 52 - home;
  const needed = new Set();
  for (let x = 0; x < 4; x++) {
    if (s.up[x] + 1 < s.down[x]) needed.add(x * 13 + (s.up[x] + 1));
    if (s.down[x] - 1 > s.up[x]) needed.add(x * 13 + (s.down[x] - 1));
  }
  for (const col of s.tableau) for (let i = 0; i < col.length; i++) if (needed.has(col[i].id)) h += col.length - 1 - i;
  return h;
}

class MinHeap {
  constructor() { this.a = []; }
  size() { return this.a.length; }
  push(x) { const a = this.a; a.push(x); let i = a.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (a[p].f <= a[i].f) break; [a[p], a[i]] = [a[i], a[p]]; i = p; } }
  pop() { const a = this.a, top = a[0], last = a.pop(); if (a.length) { a[0] = last; let i = 0; for (;;) { let l = 2 * i + 1, r = l + 1, m = i; if (l < a.length && a[l].f < a[m].f) m = l; if (r < a.length && a[r].f < a[m].f) m = r; if (m === i) break; [a[m], a[i]] = [a[i], a[m]]; i = m; } } return top; }
}

// Best-first search. Returns { solved:true, par } | { solved:false } (space exhausted, none) |
// { solved:'unknown' } (node budget hit before either — treated as unsupported).
// Compact, replayable token for one move (see rules.mjs applyMove for the shapes). `end` is
// encoded 0=up / 1=down. Fields are comma-separated; a solution is the tokens space-joined.
export function moveToken(m) {
  if (m.k === 'F') return m.from.col !== undefined
    ? `F,${m.from.col},${m.end === 'up' ? 0 : 1}`
    : `G,${m.from.cell},${m.end === 'up' ? 0 : 1}`;
  if (m.k === 'T') return `T,${m.src},${m.idx},${m.dst}`;
  if (m.k === 'C') return `C,${m.src}`;
  if (m.k === 'X') return `X,${m.cell},${m.dst}`;
  throw new Error('bad move ' + JSON.stringify(m));
}

// When `withPath` is set, each node remembers its parent and the move-segment that produced it
// (the chosen move plus the auto-safe sends that followed); on a win we walk parents back to the
// root and flatten to the complete move list from the raw deal. Off by default so the certify hot
// loop pays nothing.
export function solve(state0, constraint, { budget = 300000, withPath = false } = {}) {
  const heap = new MinHeap();
  const best = new Map();                 // key -> best g seen (lazy-deletion transposition)
  const usesCells = constraint.cellBudget < Infinity;
  const usesOpen = constraint.wantDownOpen;
  const usesBig = constraint.wantBigMove;
  const key = (s, cellUses, opened, big) =>
    stateKey(s) + '#' + (usesCells ? 'c' + cellUses : '') + (usesOpen ? 'o' + (opened ? 1 : 0) : '')
                      + (usesBig ? 'b' + (big ? 1 : 0) : '');

  const push = (s, g, cellUses, opened, big, parent, seg) => {
    const k = key(s, cellUses, opened, big);
    if (best.has(k) && best.get(k) <= g) return;
    best.set(k, g);
    heap.push({ f: g + 2 * heuristic(s), g, s, cellUses, opened, big, k, parent: withPath ? parent : null, seg: withPath ? seg : null });
  };
  const reconstruct = node => {
    const segs = [];
    for (let n = node; n; n = n.parent) segs.push(n.seg);
    return segs.reverse().flat();
  };

  const a0 = autoSafe(state0, constraint);
  push(a0.state, a0.moves, 0, usesOpen ? (kingsDown(a0.state) && a0.moves <= constraint.downOpenN) : false,
       false, null, withPath ? a0.applied.slice() : null);

  let nodes = 0;
  while (heap.size()) {
    if (++nodes > budget) return { solved: 'unknown' };
    const node = heap.pop();
    if (best.get(node.k) < node.g) continue;            // superseded by a cheaper path
    const { s, g } = node;
    if (isWon(s)) {
      // Existential goals must have been achieved somewhere along the path, not merely be winnable.
      const goalsMet = (!usesOpen || node.opened) && (!usesBig || node.big);
      if (goalsMet) return withPath ? { solved: true, par: g, moves: reconstruct(node) } : { solved: true, par: g };
      continue;
    }
    for (const m of legalMoves(s, node.cellUses, constraint)) {
      const a = autoSafe(applyMove(s, m), constraint);
      const ns = a.state;
      const ng = g + 1 + a.moves;
      const ncell = node.cellUses + (m.k === 'C' ? 1 : 0);
      let opened = node.opened;
      if (usesOpen) {
        if (!opened && kingsDown(ns) && ng <= constraint.downOpenN) opened = true;
        if (!opened && ng > constraint.downOpenN) continue;   // deadline blown, can't satisfy
      }
      // 'one-big-move': latch once any tableau run of >= bigMoveN cards is relocated.
      let big = node.big;
      if (usesBig && !big && m.k === 'T' && (s.tableau[m.src].length - m.idx) >= constraint.bigMoveN) big = true;
      push(ns, ng, ncell, opened, big, node, withPath ? [m, ...a.applied] : null);
    }
  }
  return { solved: false };
}

export function dealState(seed) { const s = deal(seed); return { tableau: s.tableau, cells: s.cells, up: s.up, down: s.down }; }

// Certify one seed: winnable + reference par, and which certified objectives it supports.
// null if not provably winnable within budget (skip it).
//
// `par` = reference par = the shortest winning line found in ANY of our searches (the
// unconstrained search plus every constrained one). A constrained search restricts the move
// generator but every line it finds is still a legal *unconstrained* win, so it is a valid witness
// for par — and constrained sub-searches routinely beat the unconstrained f=g+2h line (which is
// inadmissible). Taking the min keeps par a real, deterministic upper bound on the optimum and
// makes any par-derived move cap tighter. `constraintPar[id]` keeps each objective's own length.
export function certify(seed, opts = {}) {
  const base = solve(dealState(seed), objective('unconstrained'), opts);
  if (base.solved !== true) return null;
  const rec = { seed, winnable: true, par: base.par, supports: [], constraintPar: {} };
  for (const id of CERTIFIED) {
    const r = solve(dealState(seed), objective(id), opts);
    if (r.solved === true) {
      rec.supports.push(id);
      rec.constraintPar[id] = r.par;
      if (r.par < rec.par) rec.par = r.par;   // best legal winning line seen so far
    }
  }
  return rec;
}

// Daily-eligible = winnable AND supports >=1 Gold-grade objective (a day needs a real Gold).
export function isDailyEligible(rec) { return !!rec && rec.winnable && GOLD_GRADE.some(id => rec.supports.includes(id)); }
