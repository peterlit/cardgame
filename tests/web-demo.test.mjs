// BEHAVIOURAL guard on the shipped web demo step-back (index.html layoutBoard / demoStepBack).
//
// ux/WF-6:demo-has-no-step-back split deal() so the opening position lives in layoutBoard(), and
// demoStepBack() re-simulates the baked line from move 0 to move N-1. Until now the only guard on
// either was a source-text pin (tests/ios-parity.test.mjs), which stays green through an
// off-by-one in the target or a wrong board out of layoutBoard — while the identical iOS logic has
// two real tests in SolutionReplayTests. Here the shipped declarations are lifted by name
// (tests/web-extract.mjs's extractDecl) into a sandbox that stubs the four DOM touches
// (document.getElementById, setMoves, updateDemoBar, render) and records restartDeal — the abort
// path — so a token that fails to apply cannot pass silently.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { extractDecl } from './web-extract.mjs';
import { deal as canonDeal } from './engine.mjs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const sol = JSON.parse(readFileSync(join(REPO, 'data/daily-solutions.json'), 'utf8')).solutions;

// Dependency order matters only for the consts (TDZ); the functions hoist.
const NAMES = ['RED', 'NCELLS', 'NCOLS', 'mulberry32', 'freshDeck', 'layoutBoard', 'applyDemoToken', 'demoStepBack'];

function loadDemo() {
  const body = NAMES.map(n => extractDecl(n)).join('\n');
  const src = `
    "use strict";
    let state = null, seed = 0, moveCount = 0, selection = null;
    let demoing = false, demoPaused = false, demoStarted = false, demoMoves = null, demoIdx = 0;
    const calls = { restartDeal: 0, render: 0, updateDemoBar: 0 };
    let bannerShown = false;
    const document = { getElementById: id => id === 'demoBar'
      ? { classList: { contains: c => c === 'show' && bannerShown } } : null };
    const setMoves = () => {};
    const updateDemoBar = () => { calls.updateDemoBar++; };
    const render = () => { calls.render++; };
    const restartDeal = () => { calls.restartDeal++; };
    ${body}
    return {
      layoutBoard, applyDemoToken, demoStepBack, calls,
      get state(){ return state; }, get moveCount(){ return moveCount; },
      get demoing(){ return demoing; }, get demoPaused(){ return demoPaused; },
      get demoStarted(){ return demoStarted; }, get demoIdx(){ return demoIdx; },
      set(o){ if('state' in o) state=o.state; if('seed' in o) seed=o.seed; if('moveCount' in o) moveCount=o.moveCount;
              if('demoing' in o) demoing=o.demoing; if('demoPaused' in o) demoPaused=o.demoPaused;
              if('demoStarted' in o) demoStarted=o.demoStarted; if('demoMoves' in o) demoMoves=o.demoMoves;
              if('demoIdx' in o) demoIdx=o.demoIdx; if('bannerShown' in o) bannerShown=o.bannerShown; },
    };`;
  return new Function(src)();
}

// A real baked line: the first seeded day's flawless line, split the way showSolution splits it.
const SEED = Number(Object.keys(sol)[0]);
const LINE = sol[String(SEED)].flawless.split(' ');
assert.ok(LINE.length >= 6 && LINE.every(t => t.length > 0), `fixture: a real line with no empty token (${LINE.length} tokens)`);

// The board after the first `n` tokens of LINE, simulated fresh — the oracle demoStepBack must match.
function boardAfter(web, n) {
  web.set({ state: web.layoutBoard(SEED), moveCount: 0 });
  for (let i = 0; i < n; i++) assert.ok(web.applyDemoToken(LINE[i]), `fixture: token ${i} '${LINE[i]}' applies`);
  return structuredClone(web.state);
}

test('layoutBoard(seed) is the canonical opening position (tests/engine.mjs deal) and is seed-normalised', () => {
  const web = loadDemo();
  for (const s of [0, 1, SEED, 0x7fffffff, 0xffffffff]) {
    const { seed: _s, ...canon } = canonDeal(s);
    assert.deepEqual(web.layoutBoard(s), canon, `layoutBoard(${s}) differs from the canonical deal`);
  }
  // deal() normalises with >>>0 before calling; layoutBoard itself does not, so a future caller
  // handing it a negative/overflowed seed must still get the same board the page dealt.
  assert.deepEqual(web.layoutBoard(-1), web.layoutBoard(0xffffffff));
  assert.deepEqual(web.layoutBoard(2 ** 32 + SEED), web.layoutBoard(SEED));
  assert.notDeepEqual(web.layoutBoard(SEED), web.layoutBoard(SEED + 1), 'two seeds gave one board');
});

test('demoStepBack from move N yields exactly the board of re-simulating N-1 moves (paused mid-line)', () => {
  const web = loadDemo();
  for (const n of [1, 2, 5, LINE.length - 1, LINE.length]) {
    const expected = boardAfter(web, n - 1);
    boardAfter(web, n);                                   // the live demo board sits at move n
    web.set({ seed: SEED, demoing: true, demoPaused: true, demoStarted: true, demoMoves: LINE, demoIdx: n, bannerShown: false });
    web.demoStepBack();
    assert.equal(web.demoIdx, n - 1, `demoIdx after stepping back from ${n}`);
    assert.equal(web.moveCount, n - 1, `moveCount after stepping back from ${n}`);
    assert.deepEqual(web.state, expected, `board after stepping back from move ${n} is not the move-${n - 1} position`);
    assert.equal(web.calls.restartDeal, 0, 'step-back took the abort path (a token failed to re-apply)');
    assert.ok(web.demoing && web.demoPaused, 'step-back left the paused demo state');
  }
});

test('demoStepBack is a no-op at move 0, while the demo is running, and outside a demo', () => {
  const web = loadDemo();
  const at2 = boardAfter(web, 2);
  const cases = [
    ['at move 0', { demoing: true, demoPaused: true, demoIdx: 0 }],
    ['while running (not paused)', { demoing: true, demoPaused: false, demoIdx: 2 }],
    ['outside a demo, banner down', { demoing: false, demoPaused: false, demoIdx: 2, bannerShown: false }],
  ];
  for (const [label, g] of cases) {
    web.set({ state: structuredClone(at2), moveCount: 2, seed: SEED, demoMoves: LINE, demoStarted: true, bannerShown: false, ...g });
    const idx = web.demoIdx, renders = web.calls.render;
    web.demoStepBack();
    assert.equal(web.demoIdx, idx, `${label}: demoIdx moved`);
    assert.deepEqual(web.state, at2, `${label}: the board changed`);
    assert.equal(web.calls.render, renders, `${label}: it re-rendered`);
  }
});

test('demoStepBack from the completed-line banner re-enters the demo paused one move short', () => {
  const web = loadDemo();
  const n = LINE.length;
  const expected = boardAfter(web, n - 1);
  boardAfter(web, n);
  web.set({ seed: SEED, demoing: false, demoPaused: false, demoStarted: false, demoMoves: LINE, demoIdx: n, bannerShown: true });
  web.demoStepBack();
  assert.ok(web.demoing && web.demoPaused && web.demoStarted, 'banner step-back did not re-enter the paused demo');
  assert.equal(web.demoIdx, n - 1);
  assert.deepEqual(web.state, expected, 'banner step-back is not the position before the last move');
  assert.equal(web.calls.restartDeal, 0);
});
