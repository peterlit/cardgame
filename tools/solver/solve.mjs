// Offline Causeway solver: certifies a deal's winnability + reference par, and — for each
// constraint objective — whether a winning line exists that obeys it. Runs OFFLINE only (build
// tool); never shipped. See docs/solver.md.
//
// Search: weighted-A* best-first (f = g + 2h) over a transposition table, with a burial-aware
// heuristic and an auto-safe macro (sends provably-safe cards home, gated by the constraint).
import { deal } from '../../tests/engine.mjs';
import { applyMove, legalMoves, isWon, isSafeAutoplay, canUp, stateKey } from './rules.mjs';

// ---- objectives ----
// Every objective is a FAMILY: `objective(id, param)` turns one (id, param) pair into a search
// constraint. allowFoundation() gates foundation sends (incl. auto-safe) so an ordering rule can't
// be broken; cellBudget caps cumulative cell parks; maxRun caps run relocations; wantBigMove and
// wantRank are existential/prefix goals the search must actually achieve, not merely permit.
// The universal families (`moves`, `no-undo`) need no certification — `par` calibrates them.
//
// Each gate MUST mirror the matching checker in tests/daily.mjs exactly, so that
// "certified => a passing line exists" and "checker passes => a valid line" stay in agreement.
import { gradeOf, evaluate } from '../../tests/daily.mjs';

const homeCount = (s, x) => s.up[x] + (14 - s.down[x]);
const started = (s, T) => s.up[T] > 0 || s.down[T] < 14;
const suitDone = (s, T) => s.down[T] === s.up[T] + 1;
const blockAceUpUntil = cond => (s, c, end) => !(end === 'up' && c.rank === 1) || cond(s);

export function objective(id, param = {}) {
  const p = param;
  const base = { allowFoundation: () => true, cellBudget: Infinity, maxRun: Infinity,
                 wantBigMove: false, wantRank: null, moveCap: Infinity };
  switch (id) {
    case 'unconstrained': return { ...base };

    // Universal families. `no-undo` is free (a solver line never undoes); a `moves` cap is a real
    // search bound, so it becomes a prune rather than a post-hoc check.
    case 'no-undo': return { ...base };
    case 'moves':   return { ...base, moveCap: p.N };

    case 'cells-le':  return { ...base, cellBudget: p.N };
    case 'max-run':   return { ...base, maxRun: p.N };
    case 'big-move':  return { ...base, wantBigMove: true, bigMoveN: p.N };

    // Split point: gate both ends; the win condition (down === up + 1) then forces up === R.
    case 'split-at':  return { ...base, allowFoundation: (s, c, end) => (end === 'up' ? c.rank <= p.R : c.rank >= p.R + 1) };

    // At least `min` of every suit from one end => the OTHER pile may take at most 13 - min cards.
    case 'end-bias':  return { ...base, allowFoundation: (s, c, end) =>
      p.end === 'up' ? (end !== 'down' || c.rank >= p.min + 1)
                     : (end !== 'up'   || c.rank <= 13 - p.min) };

    // STRICT prefix: nothing else goes home until every suit holds A..up and K..down.
    case 'ends-first': return { ...base, allowFoundation: (s, c, end) => {
      const met = s.up.every(u => u >= p.up) && s.down.every(d => d <= p.down);
      return met || (end === 'up' ? c.rank <= p.up : c.rank >= p.down);
    } };
    // LOOSE prefix: every <rank> down before any Ace goes up.
    case 'before-ace':     return { ...base, allowFoundation: blockAceUpUntil(s => s.down.every(d => d <= p.rank)) };
    case 'suit-top-first': return { ...base, allowFoundation: (s, c, end) => !(end === 'up' && c.rank === 1) || s.down[c.suit] <= p.rank };
    case 'suit-sprint':    return { ...base, allowFoundation: (s, c) => {
      const S = c.suit;
      if (started(s, S)) return true;
      for (let T = 0; T < 4; T++) if (T !== S && started(s, T) && !suitDone(s, T)) return false;
      return true;
    } };

    case 'rank-rush':    return { ...base, wantRank: { rank: p.rank, N: p.N } };
    case 'suit-balance': return { ...base, allowFoundation: (s, c) => {
      const home = [0, 1, 2, 3].map(x => homeCount(s, x));
      home[c.suit]++;
      return Math.max(...home) - Math.min(...home) <= p.N;
    } };

    default: throw new Error('unknown objective ' + id);
  }
}

// All four cards of `rank` are home (from either end).
export const rankHome = (s, rank) => [0, 1, 2, 3].every(x => s.up[x] >= rank || s.down[x] <= rank);

// ---- the certification matrix -----------------------------------------------------------------
// The full set of (id, param) variants the pool builder tries on every candidate seed. Wide on
// purpose: the month generator picks from whatever a seed certifies, and variety across the month
// is the whole point. `rank-rush` is special-cased by the builder (its N is TIGHTENED to the
// witness line's real completion index rather than guessed), so it lists only the search cap.
// `rank-rush` deadlines: a middling rank cannot come home early (rank R from the Ace end needs
// A..R of every suit first), so only the ranks near either extreme are worth searching, each with a
// deadline scaled to how deep it sits. The builder then TIGHTENS N from the witness line.
export const RUSH_CAPS = { 1: 26, 2: 34, 3: 42, 11: 42, 12: 34, 13: 26 };
export const VARIANTS = [
  ...[0, 1, 2, 3].map(N => ({ id: 'cells-le', param: { N } })),
  ...[1, 2, 3].map(N => ({ id: 'max-run', param: { N } })),
  ...[5, 6, 7].map(N => ({ id: 'big-move', param: { N } })),
  ...[3, 4, 5, 6, 7, 8, 9, 10].map(R => ({ id: 'split-at', param: { R } })),
  ...[7, 8, 9, 10, 11, 12, 13].flatMap(min => [
    { id: 'end-bias', param: { end: 'up', min } },
    { id: 'end-bias', param: { end: 'down', min } },
  ]),
  ...[[1, 14], [2, 14], [3, 14], [0, 13], [0, 12], [0, 11], [0, 10],
      [1, 13], [1, 12], [1, 11], [2, 13], [2, 12], [3, 13]].map(([up, down]) => ({ id: 'ends-first', param: { up, down } })),
  ...[10, 11, 12, 13].map(rank => ({ id: 'before-ace', param: { rank } })),
  ...[11, 12, 13].map(rank => ({ id: 'suit-top-first', param: { rank } })),
  { id: 'suit-sprint', param: {} },
  ...Object.keys(RUSH_CAPS).map(Number).map(rank => ({ id: 'rank-rush', param: { rank, N: RUSH_CAPS[rank] } })),
  ...[2, 3, 4, 5].map(N => ({ id: 'suit-balance', param: { N } })),
];

export function variantKey(id, param) {
  const keys = Object.keys(param || {}).sort();
  return keys.length ? `${id}:${keys.map(k => `${k}=${param[k]}`).join(',')}` : id;
}
export const isGold = v => gradeOf(v.id, v.param) === 'gold';

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
  const usesRush = !!constraint.wantRank;
  const usesBig = constraint.wantBigMove;
  const key = (s, cellUses, rushed, big) =>
    stateKey(s) + '#' + (usesCells ? 'c' + cellUses : '') + (usesRush ? 'r' + (rushed ? 1 : 0) : '')
                      + (usesBig ? 'b' + (big ? 1 : 0) : '');

  const moveCap = constraint.moveCap ?? Infinity;
  const push = (s, g, cellUses, rushed, big, parent, seg) => {
    if (g > moveCap) return;              // move-budget prune: a `moves` cap is SEARCHED, not
                                          // checked afterwards, so a joint line can meet it.
    const k = key(s, cellUses, rushed, big);
    if (best.has(k) && best.get(k) <= g) return;
    best.set(k, g);
    heap.push({ f: g + 2 * heuristic(s), g, s, cellUses, rushed, big, k, parent: withPath ? parent : null, seg: withPath ? seg : null });
  };
  const reconstruct = node => {
    const segs = [];
    for (let n = node; n; n = n.parent) segs.push(n.seg);
    return segs.reverse().flat();
  };

  const a0 = autoSafe(state0, constraint);
  push(a0.state, a0.moves, 0,
       usesRush ? (rankHome(a0.state, constraint.wantRank.rank) && a0.moves <= constraint.wantRank.N) : false,
       false, null, withPath ? a0.applied.slice() : null);

  let nodes = 0;
  while (heap.size()) {
    if (++nodes > budget) return { solved: 'unknown' };
    const node = heap.pop();
    if (best.get(node.k) < node.g) continue;            // superseded by a cheaper path
    const { s, g } = node;
    if (isWon(s)) {
      // Existential goals must have been achieved somewhere along the path, not merely be winnable.
      const goalsMet = (!usesRush || node.rushed) && (!usesBig || node.big);
      if (goalsMet) return withPath ? { solved: true, par: g, moves: reconstruct(node) } : { solved: true, par: g };
      continue;
    }
    for (const m of legalMoves(s, node.cellUses, constraint)) {
      const a = autoSafe(applyMove(s, m), constraint);
      const ns = a.state;
      const ng = g + 1 + a.moves;
      const ncell = node.cellUses + (m.k === 'C' ? 1 : 0);
      let rushed = node.rushed;
      if (usesRush) {
        if (!rushed && rankHome(ns, constraint.wantRank.rank) && ng <= constraint.wantRank.N) rushed = true;
        if (!rushed && ng > constraint.wantRank.N) continue;   // deadline blown, can't satisfy
      }
      // 'one-big-move': latch once any tableau run of >= bigMoveN cards is relocated.
      let big = node.big;
      if (usesBig && !big && m.k === 'T' && (s.tableau[m.src].length - m.idx) >= constraint.bigMoveN) big = true;
      push(ns, ng, ncell, rushed, big, node, withPath ? [m, ...a.applied] : null);
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
  const rec = { seed, winnable: true, par: base.par, supports: [] };
  for (const v of VARIANTS) {
    if (v.id === 'rank-rush') {
      // Search with a generous deadline, then TIGHTEN N to the witness line's real completion
      // index — a certified, honest number rather than a guessed one.
      let best = null;
      let deadline = v.param.N;
      // Search, then re-search against the witness's own completion index minus a step, a few
      // times: each success is a genuinely certified tighter deadline, not an estimate.
      for (let attempt = 0; attempt < 4; attempt++) {
        const r = solve(dealState(seed), objective(v.id, { rank: v.param.rank, N: deadline }), { ...opts, withPath: true });
        if (r.solved !== true) break;
        const N = rushIndex(seed, r.moves, v.param.rank);
        if (N == null) break;
        best = { id: v.id, param: { rank: v.param.rank, N }, par: r.par };
        if (N <= 4) break;
        deadline = N - 1;
      }
      if (!best) continue;
      rec.supports.push(best);
      if (best.par < rec.par) rec.par = best.par;
    } else {
      const r = solve(dealState(seed), objective(v.id, v.param), opts);
      if (r.solved !== true) continue;
      rec.supports.push({ id: v.id, param: v.param, par: r.par });
      if (r.par < rec.par) rec.par = r.par;   // best legal winning line seen so far
    }
  }
  return rec;
}

// Replay a witness line and report the move index at which the fourth card of `rank` reached a
// foundation — the tightest N for which that line certifies `rank-rush`.
export function rushIndex(seed, moves, rank) {
  let st = dealState(seed);
  if (rankHome(st, rank)) return 0;
  for (let i = 0; i < moves.length; i++) {
    st = applyMove(st, moves[i]);
    if (rankHome(st, rank)) return i + 1;
  }
  return null;
}

// Daily-eligible = winnable AND certifies >= 1 Gold-grade variant (a day needs a real Gold) AND
// >= 1 certified Silver-grade variant (the universal Silvers always exist, but a day whose only
// Silver is "win in N moves" is a thin day).
export function isDailyEligible(rec) {
  return !!rec && rec.winnable && rec.supports.some(isGold);
}

// ---- joint (Flawless) certification -------------------------------------------------------------
// A day ships a Silver AND a Gold, certified INDEPENDENTLY above — nothing there proves a single
// line can satisfy both, yet 🌟 Flawless requires exactly that (all three tiers in one attempt).
// `certifyFlawless` proves it constructively: one line that wins and passes both real checkers.

// Compose several objectives into one search constraint: gates AND together, budgets take the
// tighter bound, existential goals OR (solve() already tracks a `rushed` and a `big` latch).
// Only one wantRank / one wantBigMove is representable — that is not a limitation in practice,
// because a day never pairs a family with itself and only `rank-rush` / `big-move` use them.
export function jointObjective(specs) {
  const cs = specs.map(o => objective(o.id, o.param));
  return {
    allowFoundation: (s, c, end) => cs.every(x => x.allowFoundation(s, c, end)),
    cellBudget: Math.min(...cs.map(x => x.cellBudget)),
    maxRun: Math.min(...cs.map(x => x.maxRun)),
    wantBigMove: cs.some(x => x.wantBigMove),
    bigMoveN: cs.find(x => x.wantBigMove)?.bigMoveN,
    wantRank: cs.find(x => x.wantRank)?.wantRank ?? null,
    moveCap: Math.min(...cs.map(x => x.moveCap)),
  };
}

// Which foundation end a rank may use under a per-card gate, and the cheapest number of that
// suit's cards that must go home for it to arrive (itself included): r from the Ace end needs
// A..r; r from the King end needs K..r. Only the families whose gate is a pure rank/end rule are
// modelled — prefix rules (`ends-first`, `before-ace`, …) are left to the search.
function rankCost(rank, o) {
  const up = { ok: true, n: rank }, down = { ok: true, n: 14 - rank };
  if (o.id === 'split-at')  { up.ok = rank <= o.param.R; down.ok = rank >= o.param.R + 1; }
  if (o.id === 'end-bias')  {
    if (o.param.end === 'up')   down.ok = rank >= o.param.min + 1;
    else                        up.ok   = rank <= 13 - o.param.min;
  }
  return Math.min(up.ok ? up.n : Infinity, down.ok ? down.n : Infinity);
}

// Contradictions provable WITHOUT search — each one a real pairing the greedy fill would otherwise
// hand to the solver for a long, doomed run. Returns a reason string, or null if not provably
// impossible (which is NOT a proof of possibility — that is what certifyFlawless is for).
export function contradiction(a, b) {
  const of = id => [a, b].find(o => o.id === id);
  const big = of('big-move'), run = of('max-run'), sprint = of('suit-sprint');
  const bal = of('suit-balance'), rush = of('rank-rush');

  // Both read the same telemetry counter: maxRunMoved must be >= N and <= M.
  if (big && run && run.param.N < big.param.N)
    return `big-move{${big.param.N}} needs a run max-run{${run.param.N}} forbids`;
  // suit-sprint drives one suit to 13 home before any other starts, so the spread hits 13.
  if (sprint && bal && bal.param.N <= 12)
    return `suit-sprint runs one suit 13 ahead, over suit-balance{${bal.param.N}}`;
  // The 4th card of any rank means all four suits have started; under suit-sprint the fourth suit
  // cannot start until the other three are COMPLETE (39 cards home, so >= 39 moves).
  if (sprint && rush && rush.param.N < 39)
    return `suit-sprint needs 39 moves before the 4th suit starts, over rank-rush{N=${rush.param.N}}`;
  // A rank-gated Gold sets a floor on how early a rank can come home: each suit must first send
  // rankCost() cards, and all four suits must do so.
  if (rush) {
    const other = rush === a ? b : a;
    const floor = 4 * rankCost(rush.param.rank, other);
    if (floor > rush.param.N)
      return `${other.id} forces >= ${floor} sends before all four ${rush.param.rank}s, over rank-rush{N=${rush.param.N}}`;
  }
  return null;
}

// Replay a solver move list into the telemetry the SHIPPED checkers read (tests/daily.mjs).
// Mirrors build-solutions.mjs's token replay, from move descriptors rather than tokens.
export function traceOf(seed, moves) {
  let s = dealState(seed);
  const foundationOrder = [];
  let cellUses = 0, n = 0, maxRunMoved = 0;
  for (const m of moves) {
    n++;
    if (m.k === 'F') {
      const c = m.from.col !== undefined ? s.tableau[m.from.col][s.tableau[m.from.col].length - 1]
                                         : s.cells[m.from.cell];
      foundationOrder.push({ suit: c.suit, rank: c.rank, end: m.end, moveIdx: n });
    } else if (m.k === 'C') cellUses++;
    else if (m.k === 'T') maxRunMoved = Math.max(maxRunMoved, s.tableau[m.src].length - m.idx);
    s = applyMove(s, m);
  }
  return { won: isWon(s), moves: n, elapsed: 0, cellUses, undos: 0, foundationOrder, maxRunMoved };
}

// Prove a (seed, silver, gold) triple is FLAWLESS-achievable: find one line, then re-check it
// against both real checkers rather than trusting the search gates. Returns
// { ok:true, par, moves, trace } | { ok:false, why }.
export function certifyFlawless(seed, silver, gold, opts = {}) {
  const why = contradiction(silver, gold);
  if (why) return { ok: false, why: 'contradiction: ' + why };
  const r = solve(dealState(seed), jointObjective([silver, gold]), { ...opts, withPath: true });
  if (r.solved !== true) return { ok: false, why: r.solved === false ? 'proven-impossible' : 'budget' };
  const t = traceOf(seed, r.moves);
  const okS = evaluate(silver, t), okG = evaluate(gold, t);
  if (!okS || !okG) return { ok: false, why: `line rejected by the ${!okS ? 'Silver' : 'Gold'} checker` };
  return { ok: true, par: r.par, moves: r.moves, trace: t };
}
