// Load the SHIPPED web implementations out of index.html and run them for real.
//
// Why this exists: every other guard on index.html is a *string pin* (tests/ios-parity.test.mjs).
// A pin proves a line still reads the way it read when it was written; it proves nothing about what
// the line DOES, and it covers only the lines someone thought to pin. Mutation testing found the
// hole: neutering `objViolated`'s `case 'moves'` / `case 'end-bias'` bodies to `return false`, and
// neutering the live/lost comparison in `autoSendWouldBreakTier` and `autoFinishTierCost` to
// `const sLive=false, gLive=false`, all survived the whole suite. Those are precisely the shipped
// bugs bug/WF-4 fixed — auto-play denying Gold, the auto-finish prompt firing mid-flawless-line —
// and the suite stayed green with them back in.
//
// index.html is a single-file app: its game code is plain top-level declarations in one <script>,
// with no module boundary to import. So we lift the declarations we want by NAME (brace/statement
// matching, not line numbers, so ordinary edits above them don't break extraction), concatenate
// them in dependency order, and evaluate the result once in a function scope that also declares the
// handful of mutable globals the app keeps on the page (`state`, `telem`, `moveCount`,
// `challengeDay`, `dailyPool`). No DOM is touched: every function lifted here is pure over those.
//
// The extraction is deliberately strict — a missing name throws with the name in the message — so
// that RENAMING or deleting a shipped function fails loudly here instead of silently skipping the
// behavioural tests that depend on it.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
export const htmlSource = readFileSync(join(REPO, 'index.html'), 'utf8');

// Walk `src` from `i`, returning the index just past the statement/block that starts there.
// Understands nesting, ' " ` strings (with escapes and ${} interpolation) and both comment forms.
// `stopAtSemicolon` ends a const/let declaration at its own top-level `;`; otherwise we end at the
// `}` that closes the first `{` (a function body).
function scanTo(src, i, stopAtSemicolon) {
  let depth = 0, seenBrace = false;
  const stack = [];   // template-literal ${ } nesting
  while (i < src.length) {
    const c = src[i], n = src[i + 1];
    if (c === '/' && n === '/') { i = src.indexOf('\n', i); if (i < 0) return src.length; continue; }
    if (c === '/' && n === '*') { i = src.indexOf('*/', i + 2); if (i < 0) return src.length; i += 2; continue; }
    if (c === '"' || c === "'" || c === '`') {
      const q = c; i++;
      while (i < src.length) {
        if (src[i] === '\\') { i += 2; continue; }
        if (q === '`' && src[i] === '$' && src[i + 1] === '{') { stack.push(depth); depth = 0; i += 2; break; }
        if (src[i] === q) { i++; break; }
        i++;
      }
      continue;
    }
    if (c === '{' || c === '(' || c === '[') { depth++; if (c === '{') seenBrace = true; i++; continue; }
    if (c === '}' || c === ')' || c === ']') {
      depth--;
      if (depth < 0 && stack.length) {           // closing a ${ } — resume the template literal
        depth = stack.pop(); i++;
        while (i < src.length) {                 // ...to its closing backtick
          if (src[i] === '\\') { i += 2; continue; }
          if (src[i] === '$' && src[i + 1] === '{') { stack.push(depth); depth = 0; i += 2; break; }
          if (src[i] === '`') { i++; break; }
          i++;
        }
        continue;
      }
      i++;
      // A function ends at the `}` that returns depth to 0 — specifically `}`, not any closer:
      // `function isOnTime({challengeDay,...})` opens a brace INSIDE its parameter list, and
      // ending on the parameter list's `)` truncated the declaration mid-signature.
      if (depth === 0 && seenBrace && !stopAtSemicolon && c === '}') return i;
      continue;
    }
    if (c === ';' && depth === 0 && stopAtSemicolon) return i + 1;
    i++;
  }
  throw new Error('unterminated declaration while extracting from index.html');
}

/// Lift the top-level `function NAME(...)` / `const NAME = ...` / `let NAME = ...` declaration.
/// A multi-declarator statement (`const a=..., b=...;`) comes back whole — ask for one of its names.
///
/// ANCHORED AT COLUMN 0, and ambiguity is an error, not a silent pick. index.html writes every
/// top-level declaration flush left and indents everything nested, so column 0 is what "top level"
/// means in this file. The earlier `^[ \t]*` version accepted an INDENTED declaration of the same
/// name — a local `const objViolated = ...` inside some handler — and, taking the first match, could
/// hand the behavioural tests a copy the app never calls while reporting success. Everything else in
/// this file is built on "we ran the shipped code", so a wrong-declaration pick is the one failure
/// that must never be quiet. Two flush-left declarations of one name is likewise a hard error: JS
/// would let `function` redeclare, and we would have no way to say which one the page ends up using.
export function extractDecl(name, src = htmlSource) {
  const re = new RegExp(`^(function|const|let)[ \\t]+${name}\\b`, 'gm');
  const hits = [...src.matchAll(re)];
  if (!hits.length) throw new Error(`index.html: no top-level (column-0) declaration of \`${name}\` — was it renamed, deleted, or indented into a nested scope?`);
  if (hits.length > 1) {
    const lines = hits.map(h => src.slice(0, h.index).split('\n').length);
    throw new Error(`index.html: \`${name}\` is declared ${hits.length} times at top level (lines ${lines.join(', ')}) — extraction would silently pick one; remove the duplicate`);
  }
  const m = hits[0];
  const end = scanTo(src, m.index, m[1] !== 'function');
  return src.slice(m.index, end);
}

// Dependency order matters only for `const` (TDZ); functions hoist. Kept explicit so a reader can
// see exactly which shipped code is under test here.
const NAMES = [
  // --- daily engine: objectives, checkers, the two live HUD hints ---
  'RANK_NAME', 'RANK_SHORT', 'rankName', 'upDown', 'foldHome', 'endsFirst', 'beforeAce',
  'suitTopFirst', 'suitSprint', 'rankRush', 'suitBalance', 'OBJECTIVES',
  'gradeOf', 'labelOf', 'makeObjective', 'dailyChallenge', 'evaluate', 'evaluateChallenge',
  'objViolated', 'objSecured', 'challengeBindingValid',
  // --- board rules + the two places the app moves cards by itself ---
  'BLACK_SUITS', 'canFoundationUp', 'canFoundationDown', 'rankOnFound', 'isSafeAutoplay',
  'simulateAutoFinish', 'autoFinishWouldWin', 'autoSendWouldBreakTier', 'autoFinishTierCost',
  // --- the daily calendar's month window (which months the grid may show) ---
  'civilOf', 'monthNo', 'calMonthRange', 'clampCalMonth',
  // --- the daily session lifecycle: dates, scoring, and the R1 pending-grade path ---
  'daysFromCivil', 'EPOCH_DAYS', 'dayIndexFor', 'todayIndex', 'isOnTime', 'RUN_LOG_MAX', 'mergeRuns', 'mergeTiers',
  'saveDaily', 'recordChallengeResult', 'scorePendingDaily', 'dailyRulesPending',
];
const EXPORTS = NAMES.filter(n => n === n.toLowerCase() || /^[a-z]/.test(n));

/// Build a fresh sandbox holding the shipped web functions. `g` seeds the page globals; the
/// returned object exposes the functions plus a `set(globals)` to move the board between cases.
export function loadWeb(g = {}) {
  const body = NAMES.map(n => extractDecl(n)).join('\n');   // not point-free: map's index arg would land in `src`
  const src = `
    "use strict";
    const NCELLS = 3, NCOLS = 8;
    let state = null, telem = null, moveCount = 0, challengeDay = null, dailyPool = null;
    let challengeStartDay = null, seed = 0, dailyStore = { version: 3, days: {} }, dailyView = null;
    // localStorage stand-in, so the shipped persistence-adjacent code (saveDaily,
    // scorePendingDaily, recordChallengeResult's R1 stash) RUNS instead of being stubbed out.
    // __ls is handed back for assertions.
    const __ls = {};
    const lsGet = k => Object.prototype.hasOwnProperty.call(__ls, k) ? __ls[k] : null;
    const lsSet = (k, v) => { __ls[k] = String(v); };
    const lsRemove = k => { delete __ls[k]; };
    ${body}
    return {
      ${EXPORTS.join(', ')},
      __ls,
      get dailyStore(){ return dailyStore; },
      get challengeDay(){ return challengeDay; },
      get challengeStartDay(){ return challengeStartDay; },
      set(o){ if('state' in o) state=o.state; if('telem' in o) telem=o.telem;
              if('moveCount' in o) moveCount=o.moveCount; if('challengeDay' in o) challengeDay=o.challengeDay;
              if('dailyPool' in o) dailyPool=o.dailyPool;
              if('challengeStartDay' in o) challengeStartDay=o.challengeStartDay;
              if('seed' in o) seed=o.seed; if('dailyStore' in o) dailyStore=o.dailyStore; },
    };`;
  const web = new Function(src)();
  web.set(g);
  return web;
}

/// A blank telemetry record shaped like the one index.html keeps on the page.
export function blankTelem(over = {}) {
  return { cellUses: 0, undos: 0, foundationOrder: [], maxRunMoved: 0, ...over };
}
