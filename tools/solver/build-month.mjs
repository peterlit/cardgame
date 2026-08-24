// Build one month of Daily Challenges: certify a wide net of candidate deals, then choose the
// month's days so that the set of objectives is as VARIED as the certified material allows.
// OFFLINE tool — never shipped.
//
//   node tools/solver/build-month.mjs [--candidates 240] [--days 31] [--budget 120000]
//                                     [--jobs 8] [--sample-seed 20260801] [--out data/daily-pool.json]
//                                     [--cache .cache/month-certs] [--select-only]
//
// Phase 1 (parallel, resumable): draw `candidates` deal seeds deterministically from the daily
// range (500,001 - 1,000,000), and certify each against the full variant matrix in
// solve.mjs — every (objective, parameter) pair, not just every objective. Results are appended to
// per-worker JSONL cache files, so an interrupted run resumes instead of restarting.
//
// Phase 2 (selection): greedily fill the month, at each step taking the (seed, gold, silver) triple
// that adds the most NEW variety — an unused objective family scores far above an unused parameter
// of a family already used, and a rare certification (one only a few seeds support) is preferred
// over a common one, since rare material is the hardest to place. Adjacent days are then reordered
// so no two consecutive days share an objective family.
import { readFileSync, writeFileSync, mkdirSync, appendFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, basename } from 'node:path';
import { fork } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { mulberry32 } from '../../tests/engine.mjs';
import { certify, VARIANTS, variantKey, isGold, isDailyEligible } from './solve.mjs';
import { gradeOf, labelOf } from '../../tests/daily.mjs';

const POOL_VERSION = 3;          // v3: explicit per-day objectives, one seeded month, seeds <= 1e6
const MIN_SEED = 500001;         // daily deals live in the upper half of the deal space...
const MAX_SEED = 1000000;        // ...and never exceed the app's deal-number ceiling.
// Universal Silvers need no certification. `moves` is listed once per multiplier so the month can
// serve visibly different move caps rather than the same "par x 1.2" every time.
const MOVE_FACTORS = [1.05, 1.1, 1.15, 1.25, 1.4];

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] != null ? process.argv[i + 1] : def;
}
const has = name => process.argv.includes('--' + name);

// Deterministic candidate draw: same sample-seed => same candidate list, so a re-run reuses cache.
function candidates(n, sampleSeed) {
  const rng = mulberry32(sampleSeed >>> 0);
  const seen = new Set(), out = [];
  while (out.length < n) {
    const s = MIN_SEED + Math.floor(rng() * (MAX_SEED - MIN_SEED + 1));
    if (!seen.has(s)) { seen.add(s); out.push(s); }
  }
  return out;
}

function cacheFiles(cache) {
  const dir = dirname(cache), base = basename(cache);
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter(f => f.startsWith(base) && f.endsWith('.jsonl')).map(f => `${dir}/${f}`);
}
function readCache(cache) {
  const bySeed = new Map();
  for (const f of cacheFiles(cache)) {
    for (const line of readFileSync(f, 'utf8').split('\n')) {
      if (!line.trim()) continue;
      try { const rec = JSON.parse(line); bySeed.set(rec.seed, rec); } catch { /* torn line */ }
    }
  }
  return bySeed;
}

// ---- worker mode -------------------------------------------------------------------------------
if (has('worker')) {
  const w = Number(arg('worker', 0)), jobs = Number(arg('jobs', 1));
  const budget = Number(arg('budget', 120000));
  const cache = arg('cache', '.cache/month-certs');
  const list = candidates(Number(arg('candidates', 240)), Number(arg('sample-seed', 20260801)));
  const done = new Set(readCache(cache).keys());
  const outFile = `${cache}-${w}.jsonl`;
  mkdirSync(dirname(outFile), { recursive: true });
  for (let i = w; i < list.length; i += jobs) {
    const seed = list[i];
    if (done.has(seed)) continue;
    const t0 = Date.now();
    const rec = certify(seed, { budget }) || { seed, winnable: false, par: null, supports: [] };
    appendFileSync(outFile, JSON.stringify(rec) + '\n');
    process.send?.({ seed, ok: !!rec.winnable, n: rec.supports.length, secs: (Date.now() - t0) / 1000 });
  }
  process.exit(0);
}

// ---- phase 1: certify in parallel ---------------------------------------------------------------
const nCandidates = Number(arg('candidates', 240));
const nDays = Number(arg('days', 31));
const jobs = Number(arg('jobs', 8));
const budget = Number(arg('budget', 120000));
const sampleSeed = Number(arg('sample-seed', 20260801));
const cache = arg('cache', '.cache/month-certs');
const out = arg('out', 'data/daily-pool.json');

const list = candidates(nCandidates, sampleSeed);

async function certifyAll() {
  const todo = new Set(list.filter(s => !readCache(cache).has(s)));
  if (!todo.size) { console.log(`all ${list.length} candidates already certified (cache hit)`); return; }
  console.log(`certifying ${todo.size} of ${list.length} candidates on ${jobs} workers (budget ${budget})`);
  const self = fileURLToPath(import.meta.url);
  let done = 0;
  await Promise.all(Array.from({ length: jobs }, (_, w) => new Promise(res => {
    const child = fork(self, ['--worker', String(w), '--jobs', String(jobs), '--candidates', String(nCandidates),
                              '--sample-seed', String(sampleSeed), '--budget', String(budget), '--cache', cache],
                       { stdio: 'inherit' });
    child.on('message', m => {
      done++;
      process.stdout.write(`[${done}/${todo.size}] seed ${m.seed} ${m.ok ? `par-ok, ${m.n} variants` : 'not winnable'} (${m.secs.toFixed(0)}s)\n`);
    });
    child.on('exit', res);
  })));
}

// ---- phase 2: choose the month ------------------------------------------------------------------
// Silver options for a seed: its certified Silver-grade variants, plus the two universal families
// (a `moves` cap per multiplier, and no-undo).
function silverOptions(rec) {
  const opts = rec.supports.filter(v => gradeOf(v.id, v.param) === 'silver')
    .map(v => ({ id: v.id, param: v.param, key: variantKey(v.id, v.param), rare: true }));
  for (const f of MOVE_FACTORS) {
    const N = Math.max(rec.par, Math.round(rec.par * f));
    opts.push({ id: 'moves', param: { N }, key: `moves:f=${f}`, rare: false });
  }
  opts.push({ id: 'no-undo', param: {}, key: 'no-undo', rare: false });
  return opts;
}
const goldOptions = rec => rec.supports.filter(isGold)
  .map(v => ({ id: v.id, param: v.param, key: variantKey(v.id, v.param), rare: true }));

function selectMonth(recs, capPerFamily) {
  const eligible = recs.filter(isDailyEligible);
  // Rarity: how many eligible seeds certify each variant key. Rare material gets placed first.
  const support = new Map();
  for (const r of eligible) for (const v of r.supports) {
    const k = variantKey(v.id, v.param);
    support.set(k, (support.get(k) || 0) + 1);
  }
  // Counters are PER TIER: a family used four times as the Gold should not also fill every Silver.
  // Without the per-tier cap, families whose parameter is effectively continuous (rank-rush's
  // deadline is per-seed, so its key is always new) win every slot and the tier reads as one idea.
  const idUses = new Map(), keyUses = new Map();
  const bump = (m, k) => m.set(k, (m.get(k) || 0) + 1);
  const capped = (tier, o) => (idUses.get(tier + ':' + o.id) || 0) >= capPerFamily;
  const novelty = (tier, o) => {
    const idN = idUses.get(tier + ':' + o.id) || 0, keyN = keyUses.get(o.key) || 0;
    let s = 150 / (1 + idN);                                // diminishing, never quite zero
    s += keyN === 0 ? 40 : -60 * keyN;                      // never repeat an exact challenge
    s -= 12 * (idUses.get('gold:' + o.id) || 0) + 12 * (idUses.get('silver:' + o.id) || 0);
    if (o.rare) s += Math.max(0, 24 - 2 * (support.get(o.key) || 0));   // scarce certifications first
    return s;
  };

  const used = new Set(), chosen = [];
  for (let slot = 0; slot < nDays; slot++) {
    let best = null;
    for (const rec of eligible) {
      if (used.has(rec.seed)) continue;
      const golds = goldOptions(rec).filter(o => !capped('gold', o));
      const silvers = silverOptions(rec).filter(o => !capped('silver', o));
      for (const g of golds) {
        const gs = novelty('gold', g);
        for (const s of silvers) {
          // Never pair a family with itself: "at least 7 from the Ace end" as the Silver under
          // "at least 10 from the Ace end" as the Gold is one objective printed twice, and the
          // Gold implies the Silver.
          if (s.id === g.id) continue;
          const score = gs + novelty('silver', s);
          if (!best || score > best.score) best = { score, rec, gold: g, silver: s };
        }
      }
    }
    if (!best) break;
    used.add(best.rec.seed);
    bump(idUses, 'gold:' + best.gold.id); bump(keyUses, best.gold.key);
    bump(idUses, 'silver:' + best.silver.id); bump(keyUses, best.silver.key);
    chosen.push(best);
  }
  return chosen;
}

// Fill the month under the tightest per-family cap that still fills it. A tight cap is what forces
// the tiers to range across families instead of one family with many parameters.
function selectMonthBalanced(recs) {
  let best = [];
  for (let cap = 3; cap <= 12; cap++) {
    const chosen = selectMonth(recs, cap);
    if (chosen.length > best.length) best = chosen;
    if (chosen.length >= nDays) return chosen;
  }
  return best;
}

// Spread the chosen days so no two consecutive dates share an objective family (a greedy pass over
// the selection order; purely cosmetic, but a month that alternates reads as more varied).
function spread(chosen) {
  const pool = chosen.slice(), out = [];
  while (pool.length) {
    const prev = out[out.length - 1];
    let i = 0;
    if (prev) {
      const clash = c => c.gold.id === prev.gold.id || c.silver.id === prev.silver.id;
      const j = pool.findIndex(c => !clash(c));
      if (j >= 0) i = j;
    }
    out.push(pool.splice(i, 1)[0]);
  }
  return out;
}

function serialize(pool) {
  const rows = pool.days.map(d => '    ' + JSON.stringify(d)).join(',\n');
  return `{\n  "version": ${pool.version},\n  "epoch": ${JSON.stringify(pool.epoch)},\n  "minSeed": ${pool.minSeed},\n  "maxSeed": ${pool.maxSeed},\n  "days": [\n${rows}\n  ]\n}\n`;
}

if (!has('select-only')) await certifyAll();

const recs = [...readCache(cache).values()].filter(r => list.includes(r.seed));
const winnable = recs.filter(r => r.winnable);
console.log(`\ncertified ${recs.length} candidates: ${winnable.length} winnable, ${recs.filter(isDailyEligible).length} daily-eligible`);

const chosen = spread(selectMonthBalanced(recs));
if (chosen.length < nDays) console.warn(`WARNING: only ${chosen.length} of ${nDays} days could be filled — widen --candidates`);

const pool = {
  version: POOL_VERSION, epoch: '2026-08-01', minSeed: MIN_SEED, maxSeed: MAX_SEED,
  days: chosen.map(c => ({
    seed: c.rec.seed,
    par: c.rec.par,
    silver: { id: c.silver.id, param: c.silver.param },
    gold: { id: c.gold.id, param: c.gold.param },
  })),
};
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, serialize(pool));

const ids = new Set(), keys = new Set();
for (const c of chosen) { ids.add(c.gold.id); ids.add(c.silver.id); keys.add(c.gold.key); keys.add(c.silver.key); }
console.log(`\nmonth written to ${out}: ${pool.days.length} days, ${ids.size} distinct objective families, ${keys.size} distinct challenges`);
for (let i = 0; i < chosen.length; i++) {
  const c = chosen[i];
  console.log(`  Aug ${String(i + 1).padStart(2)}  #${c.rec.seed}  par ${String(c.rec.par).padStart(3)}  ` +
              `S: ${labelOf(c.silver.id, c.silver.param)}\n              G: ${labelOf(c.gold.id, c.gold.param)}`);
}
