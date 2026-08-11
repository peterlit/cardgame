// Causeway shared-engine tests. Run: `node --test` (from repo root) or
// `node --test tests/`. Exits non-zero on failure. See tests/README.md.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import {
  mulberry32, deal, isValidSave, isSafeAutoplay, saveFromDeal, autoFinishWouldWin,
  NCOLS, NCELLS,
} from "./engine.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO = join(__dirname, "..");

/* ---------------- RNG / deal determinism ---------------- */
// Locked "golden" card orders (card id = suit*13 + rank) for known seeds. If the
// mulberry32 RNG or the shuffle/layout ever changes, these break — which is
// exactly the web<->iOS parity contract we must not silently violate.
const GOLDEN = {
  1:      [25,45,24,11,44,32,51,42,7,30,36,23,41,35,12,4,50,34,9,15,5,28,46,39,31,8,22,17,13,2,37,38,26,48,3,18,40,10,16,6,21,20,43,19,52,29,14,47,49,27,1,33],
  42:     [42,48,15,26,52,35,7,50,36,44,24,3,14,17,41,51,28,6,49,10,40,4,45,46,20,5,31,38,34,18,2,27,16,1,22,47,19,8,12,30,37,11,21,39,29,13,25,9,33,43,23,32],
  999999: [14,39,26,43,38,28,5,22,12,17,45,15,7,35,23,13,21,50,3,33,47,41,8,37,29,36,52,1,24,18,34,16,32,10,4,49,44,31,46,30,19,6,42,27,9,48,11,20,40,51,25,2],
};

test("deal is deterministic and matches golden orders per seed", () => {
  for (const [seed, ids] of Object.entries(GOLDEN)) {
    const s = deal(Number(seed));
    assert.deepEqual(s.tableau.flat().map(c => c.id), ids, `seed ${seed}`);
  }
});

test("deal always yields all 52 distinct cards with correct layout", () => {
  for (const seed of [0, 1, 7, 123456, 4294967295]) {
    const s = deal(seed);
    assert.equal(s.tableau.length, NCOLS);
    const counts = s.tableau.map(c => c.length);
    assert.deepEqual(counts, [7, 7, 7, 7, 6, 6, 6, 6]);
    const ids = new Set(s.tableau.flat().map(c => c.id));
    assert.equal(ids.size, 52);
    assert.equal(s.cells.length, NCELLS);
    assert.deepEqual(s.up, [0, 0, 0, 0]);
    assert.deepEqual(s.down, [14, 14, 14, 14]);
  }
});

test("mulberry32 returns floats in [0,1) and is a pure function of its seed", () => {
  const a = mulberry32(12345), b = mulberry32(12345);
  for (let i = 0; i < 100; i++) {
    const x = a();
    assert.ok(x >= 0 && x < 1);
    assert.equal(x, b());
  }
});

/* ---------------- isSafeAutoplay soundness ---------------- */
// Causeway's tableau builds BOTH directions, so a naive FreeCell "safe" rule is
// unsound. These are the two-way-tableau counterexamples from earlier reviews.
const st = (over = {}) => ({
  up: [0, 0, 0, 0], down: [14, 14, 14, 14], ...over,
});
const card = (suit, rank) => ({
  suit, rank, color: (suit === 1 || suit === 2) ? "red" : "black",
});

test("an Ace is NOT auto-safe while an opposite-color 2 could ascend onto it", () => {
  // This is the crux of Causeway's two-way tableau: an Ace can still be a base
  // for an ASCENDING red 2. So even a foundation-legal Ace is unsafe until both
  // red 2s are home. (A plain FreeCell rule would wrongly call it safe.)
  const s = st();
  assert.ok(canPlayUp(s, card(0, 1)));            // foundation-legal
  assert.equal(isSafeAutoplay(s, card(0, 1)), false);
});

test("an Ace becomes safe once both opposite-color 2s are home", () => {
  // rank-1=0 is trivially covered; rank+1=2 covered for both red suits (up[1]=up[2]=2).
  const s = st({ up: [0, 2, 2, 0] });
  assert.ok(isSafeAutoplay(s, card(0, 1)));
});

test("black 2 is UNSAFE while a red Ace could still need it as a descending base", () => {
  // Black spade 2 playable up (up[0]=1). Red aces (suits 1,2) not yet home, so a
  // red A could still build DOWN onto this black 2 in the tableau.
  const s = st({ up: [1, 0, 0, 0] });
  assert.ok(canPlayUp(s, card(0, 2)));      // sanity: it *is* foundation-legal
  assert.equal(isSafeAutoplay(s, card(0, 2)), false);
});

test("black 2 becomes safe once BOTH red rank-1 and rank-3 neighbours are home", () => {
  // red aces home via up (up[1]=up[2]=1 covers rank-1=1); red 3s home via down
  // (down[1]=down[2]=3 covers rank+1=3, since down<=3 means the 3 is on foundation).
  const s = st({ up: [1, 1, 1, 0], down: [14, 3, 3, 14] });
  assert.ok(isSafeAutoplay(s, card(0, 2)));
});

test("a card not legal on any foundation is never 'safe'", () => {
  // black 5 with up[0]=1: not up[0]+1, and down far away -> not foundation-legal.
  assert.equal(isSafeAutoplay(st({ up: [1, 0, 0, 0] }), card(0, 5)), false);
});

test("red 8 unsafe while an opposite-color 7 or 9 remains in play", () => {
  // red heart 8 playable up (up[1]=7). Black suits 0,3 have no 7/9 home yet.
  const s = st({ up: [0, 7, 0, 0] });
  assert.equal(isSafeAutoplay(s, card(1, 8)), false);
});

// local helper mirroring canFoundationUp for the sanity assert above
function canPlayUp(s, c) { return c.rank === s.up[c.suit] + 1 && c.rank < s.down[c.suit]; }

/* ---------------- restore-save validator ---------------- */
test("a fresh dealt board is a valid resumable save", () => {
  assert.ok(isValidSave(saveFromDeal(1)));
});

test("a partial game (some cards home) validates", () => {
  const g = saveFromDeal(42);
  // Send spade Ace (id 1) home: it's in the tableau somewhere; remove & bump up[0].
  let moved = false;
  for (const col of g.tableau) {
    const i = col.findIndex(c => c.suit === 0 && c.rank === 1);
    if (i >= 0) { col.splice(i, 1); moved = true; break; }
  }
  assert.ok(moved);
  g.up[0] = 1;
  assert.ok(isValidSave(g));
});

test("rejects a duplicate card", () => {
  const g = saveFromDeal(1);
  // Overwrite the top of column 1 with a copy of column 0's top -> duplicate.
  g.tableau[1][g.tableau[1].length - 1] = { ...g.tableau[0][0] };
  assert.equal(isValidSave(g), false);
});

test("rejects out-of-range suit (F3 regression)", () => {
  const g = saveFromDeal(1);
  g.tableau[0][0] = { suit: 9, rank: 5, color: "red" };
  assert.equal(isValidSave(g), false);
});

test("rejects out-of-range rank", () => {
  const g = saveFromDeal(1);
  g.tableau[0][0] = { suit: 0, rank: 14, color: "black" };
  assert.equal(isValidSave(g), false);
});

test("rejects crossed foundations (up >= down)", () => {
  const g = saveFromDeal(1);
  g.up[0] = 8; g.down[0] = 6;   // crossed
  assert.equal(isValidSave(g), false);
});

test("rejects a completed board (all 52 home, nothing to resume)", () => {
  const g = { tableau: Array.from({ length: NCOLS }, () => []),
              cells: Array(NCELLS).fill(null),
              up: [6, 6, 6, 6], down: [7, 7, 7, 7] };
  assert.equal(isValidSave(g), false);
});

test("rejects wrong-shaped saves", () => {
  assert.equal(isValidSave(null), false);
  assert.equal(isValidSave({ tableau: [], cells: [], up: [], down: [] }), false);
  const g = saveFromDeal(1); g.cells = [null, null];   // wrong NCELLS
  assert.equal(isValidSave(g), false);
});

/* ---------------- DRIFT GUARD ---------------- */
/* ---------------- auto-finish trigger (autoFinishWouldWin) ---------------- */
test("autoFinishWouldWin: true when the four remaining Kings can all cascade up", () => {
  const state = { up:[12,12,12,12], down:[14,14,14,14], cells:[null,null,null],
    tableau:[[{suit:0,rank:13}],[{suit:1,rank:13}],[{suit:2,rank:13}],[{suit:3,rank:13}],[],[],[],[]] };
  assert.equal(autoFinishWouldWin(state), true);
});

test("autoFinishWouldWin: true when a full ordered suit must peel off across many steps", () => {
  const spades = []; for(let r=13;r>=1;r--) spades.push({suit:0,rank:r});   // A on top
  const state = { up:[0,13,13,13], down:[14,14,14,14], cells:[null,null,null],
    tableau:[spades,[],[],[],[],[],[],[]] };
  assert.equal(autoFinishWouldWin(state), true);
});

test("autoFinishWouldWin: false when a card can't reach any foundation", () => {
  const state = { up:[0,0,0,0], down:[14,14,14,14], cells:[null,null,null],
    tableau:[[{suit:0,rank:5}],[],[],[],[],[],[],[]] };   // lone 5 spades, foundations empty
  assert.equal(autoFinishWouldWin(state), false);
});

test("autoFinishWouldWin: false for a freshly dealt board", () => {
  assert.equal(autoFinishWouldWin(deal(42)), false);   // deal() returns a full state
});

// engine.mjs is a hand-copy of index.html's inline <script> logic. Assert the
// canonical function bodies still appear verbatim in index.html so the copy can't
// silently rot. Whitespace-normalized substring match.
const norm = s => s.replace(/\s+/g, " ").trim();

test("engine.mjs logic still matches index.html (no drift)", () => {
  const html = norm(readFileSync(join(REPO, "index.html"), "utf8"));
  const canon = [
    // mulberry32
    "a|=0; a=a+0x6D2B79F5|0; let t=Math.imul(a^a>>>15,1|a); t=t+Math.imul(t^t>>>7,61|t)^t; return ((t^t>>>14)>>>0)/4294967296;",
    // freshDeck body
    'for(let s=0;s<4;s++) for(let r=1;r<=13;r++) d.push({suit:s,rank:r,color:RED.has(s)?"red":"black",id:s*13+r});',
    // shuffle
    "for(let i=deck.length-1;i>0;i--){ const j=Math.floor(rng()*(i+1)); [deck[i],deck[j]]=[deck[j],deck[i]]; }",
    // layout
    "for(let c=0;c<NCOLS;c++){ const n = c<4?7:6; for(let i=0;i<n;i++) tableau[c].push(deck[k++]); }",
    // rankOnFound
    "function rankOnFound(suit,r){ if(r<=0) return true; return state.up[suit]>=r || state.down[suit]<=r; }",
    // isSafeAutoplay body
    'if(!(canFoundationUp(card)||canFoundationDown(card))) return false; const opp = card.color==="red" ? BLACK_SUITS : RED_SUITS; return opp.every(x=>rankOnFound(x, card.rank-1) && rankOnFound(x, card.rank+1));',
    // mark() with the F3 suit guard
    "const mark = (suit,rank)=>{ if(!(suit>=0 && suit<=3)) return false; if(!(rank>=1 && rank<=13)) return false;",
    // autoFinishWouldWin: the greedy cascade predicates + the win check
    "const canUp=c=> c.rank===up[c.suit]+1 && c.rank<down[c.suit]; const canDown=c=> c.rank===down[c.suit]-1 && c.rank>up[c.suit];",
    "for(let s=0;s<4;s++) if(down[s]!==up[s]+1) return false; return true;",
  ];
  for (const c of canon) {
    assert.ok(html.includes(norm(c)), `index.html no longer contains: ${c.slice(0, 60)}...`);
  }
});
