// Pure Causeway engine logic, extracted for testing (see tests/README.md).
//
// index.html is a single-file file:// app with one inline <script>, so it cannot
// `import` this module at runtime. To prevent this copy from silently drifting
// from the shipped game, tests/engine.test.mjs includes a DRIFT GUARD that reads
// index.html and asserts the canonical source of each function below still matches.
// If you change the logic in index.html, mirror it here or the tests fail.

/* ---------- constants (must match index.html) ---------- */
export const RED    = new Set([1, 2]);
export const NCELLS = 3;
export const NCOLS  = 8;
export const BLACK_SUITS = [0, 3], RED_SUITS = [1, 2];

/* ---------- CANONICAL: copied verbatim from index.html ---------- */

// CANON:mulberry32
export function mulberry32(a){ return function(){
  a|=0; a=a+0x6D2B79F5|0;
  let t=Math.imul(a^a>>>15,1|a);
  t=t+Math.imul(t^t>>>7,61|t)^t;
  return ((t^t>>>14)>>>0)/4294967296;
};}

// CANON:freshDeck
export function freshDeck(){
  const d=[];
  for(let s=0;s<4;s++) for(let r=1;r<=13;r++) d.push({suit:s,rank:r,color:RED.has(s)?"red":"black",id:s*13+r});
  return d;
}

// deal() in index.html mutates module globals (seed/state); this is the same
// algorithm returning a fresh object. The shuffle + layout lines are canonical.
export function deal(theSeed){
  const seed = theSeed>>>0;
  const rng = mulberry32(seed);
  const deck = freshDeck();
  // CANON:shuffle
  for(let i=deck.length-1;i>0;i--){ const j=Math.floor(rng()*(i+1)); [deck[i],deck[j]]=[deck[j],deck[i]]; }
  const tableau = Array.from({length:NCOLS},()=>[]);
  // CANON:layout
  let k=0;
  for(let c=0;c<NCOLS;c++){ const n = c<4?7:6; for(let i=0;i<n;i++) tableau[c].push(deck[k++]); }
  return {
    seed,
    tableau,
    cells: Array(NCELLS).fill(null),
    up:   [0,0,0,0],
    down: [14,14,14,14],
  };
}

/* ---------- safe auto-play ---------- */
// The index.html versions read a module global `state`; here we pass it explicitly.
// The predicate bodies are canonical.

// CANON:canFoundationUp
export function canFoundationUp(state, card){
  const s=card.suit;
  return card.rank===state.up[s]+1 && card.rank < state.down[s];
}
// CANON:canFoundationDown
export function canFoundationDown(state, card){
  const s=card.suit;
  return card.rank===state.down[s]-1 && card.rank > state.up[s];
}
// CANON:rankOnFound
export function rankOnFound(state, suit, r){ if(r<=0) return true; return state.up[suit]>=r || state.down[suit]<=r; }

// CANON:isSafeAutoplay
export function isSafeAutoplay(state, card){
  if(!(canFoundationUp(state,card)||canFoundationDown(state,card))) return false;
  const opp = card.color==="red" ? BLACK_SUITS : RED_SUITS;
  return opp.every(x=>rankOnFound(state,x, card.rank-1) && rankOnFound(state,x, card.rank+1));
}

// CANON:autoFinishWouldWin
// Would forcing every available card home empty the board and win? Pure simulation on
// copies — the trigger for automatic finishing. Same greedy rule as autoFinish.
export function autoFinishWouldWin(state){
  const up=state.up.slice(), down=state.down.slice();
  const cells=state.cells.slice();
  const tab=state.tableau.map(c=>c.slice());
  const canUp=c=> c.rank===up[c.suit]+1 && c.rank<down[c.suit];
  const canDown=c=> c.rank===down[c.suit]-1 && c.rank>up[c.suit];
  let moved=true;
  while(moved){
    moved=false;
    for(let i=0;i<NCELLS;i++){
      const c=cells[i]; if(!c) continue;
      if(canUp(c)){ up[c.suit]=c.rank; cells[i]=null; moved=true; }
      else if(canDown(c)){ down[c.suit]=c.rank; cells[i]=null; moved=true; }
    }
    for(let col=0;col<NCOLS;col++){
      const t=tab[col]; if(!t.length) continue;
      const c=t[t.length-1];
      if(canUp(c)){ up[c.suit]=c.rank; t.pop(); moved=true; }
      else if(canDown(c)){ down[c.suit]=c.rank; t.pop(); moved=true; }
    }
  }
  for(let s=0;s<4;s++) if(down[s]!==up[s]+1) return false;
  return true;
}

// CANON:sendOneHome
// One greedy send home — the single step the finish chain repeats to fixpoint. Mirrors
// index.html sendOneHome() (same cell-before-column order, up-before-down rule) but mutates
// the passed `state` and omits the app's snapshot()/render side effects. iOS shares this exact
// algorithm by construction (Game.swift sendOneHome); there is no iOS test target (known backlog).
export function sendOneHomeStep(state){
  for(let i=0;i<NCELLS;i++){
    const c=state.cells[i]; if(!c) continue;
    if(canFoundationUp(state,c)){ state.cells[i]=null; state.up[c.suit]=c.rank; return true; }
    if(canFoundationDown(state,c)){ state.cells[i]=null; state.down[c.suit]=c.rank; return true; }
  }
  for(let col=0;col<NCOLS;col++){
    const t=state.tableau[col]; if(!t.length) continue;
    const c=t[t.length-1];
    if(canFoundationUp(state,c)){ t.pop(); state.up[c.suit]=c.rank; return true; }
    if(canFoundationDown(state,c)){ t.pop(); state.down[c.suit]=c.rank; return true; }
  }
  return false;
}

/* ---------- restore-save validator ---------- */
// Mirrors index.html restoreGame()'s validation gate. Returns true iff `g` is a
// resumable save (52 canonical cards, foundations in range and non-crossing,
// board not already complete).
export function isValidSave(g){
  if(!g || !Array.isArray(g.tableau) || g.tableau.length!==NCOLS ||
     !Array.isArray(g.cells) || g.cells.length!==NCELLS ||
     !Array.isArray(g.up) || g.up.length!==4 || !Array.isArray(g.down) || g.down.length!==4) return false;
  const seen = new Set();
  // CANON:mark
  const mark = (suit,rank)=>{
    if(!(suit>=0 && suit<=3)) return false;
    if(!(rank>=1 && rank<=13)) return false;
    const id = suit*13 + rank;
    if(seen.has(id)) return false;
    seen.add(id); return true;
  };
  for(let s=0;s<4;s++){
    const u=g.up[s], d=g.down[s];
    if(!(u>=0 && u<=13 && d>=1 && d<=14 && u<d)) return false;
  }
  for(const col of g.tableau){ if(!Array.isArray(col)) return false;
    for(const c of col){ if(!c || !mark(c.suit,c.rank)) return false; } }
  for(const c of g.cells){ if(c && !mark(c.suit,c.rank)) return false; }
  for(let s=0;s<4;s++){
    for(let r=1;r<=g.up[s];r++) if(!mark(s,r)) return false;
    for(let r=g.down[s];r<=13;r++) if(!mark(s,r)) return false;
  }
  const boardEmpty = g.tableau.every(c=>c.length===0) && g.cells.every(c=>c===null);
  if(seen.size!==52 || boardEmpty) return false;
  return true;
}

/* ---------- helper: build a save from a dealt state ---------- */
export function saveFromDeal(seed){
  const s = deal(seed);
  return { seed, tableau: s.tableau, cells: s.cells, up: s.up, down: s.down };
}
