// Build (or grow) the baked certified daily-challenge pool. OFFLINE tool.
//
//   node tools/solver/build-pool.mjs [--start N] [--scan N] [--target N] [--budget N] [--out path]
//
// Scans candidate seeds (IDs > 10,000 only — 1..10,000 are reserved for personal range-play),
// certifies each, and keeps the daily-eligible ones (winnable + >=1 Gold-grade objective) until it
// reaches --target or exhausts --scan candidates. The pool is APPEND-ONLY: existing entries in the
// output file are preserved and never reordered, so past-date challenges can never shift.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { certify, isDailyEligible } from './solve.mjs';

const POOL_VERSION = 1;
const MIN_SEED = 10000;   // exclusive floor; daily pool uses IDs strictly > 10,000

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] != null ? process.argv[i + 1] : def;
}

const out = arg('out', 'data/daily-pool.json');
const scan = Number(arg('scan', 150));
const target = Number(arg('target', 40));
const budget = Number(arg('budget', 150000));

let pool = { version: POOL_VERSION, minSeed: MIN_SEED, seeds: [] };
try { pool = JSON.parse(readFileSync(out, 'utf8')); } catch { /* fresh */ }
const have = new Set(pool.seeds.map(s => s.seed));
let start = Number(arg('start', pool.seeds.length ? Math.max(...pool.seeds.map(s => s.seed)) + 1 : MIN_SEED + 1));
if (start <= MIN_SEED) start = MIN_SEED + 1;

console.log(`pool "${out}": ${pool.seeds.length} seeds; scanning ${scan} candidates from ${start}, want +${target} (budget ${budget})`);
let added = 0, scanned = 0, winnable = 0;
for (let seed = start; scanned < scan && added < target; seed++, scanned++) {
  if (have.has(seed)) continue;
  const rec = certify(seed, { budget });
  if (rec) winnable++;
  if (isDailyEligible(rec)) {
    pool.seeds.push(rec);       // append-only: never reorder existing entries
    have.add(seed);
    added++;
    process.stdout.write(`+ ${seed} par=${rec.par} gold=[${rec.supports.filter(x => require_gold(x)).join(',')}]\n`);
  }
}
function require_gold(x) { return ['no-cells', 'aces-first', 'kings-first', 'jacks-down-first', 'suits-top-down', 'suit-sprint'].includes(x); }

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(pool, null, 0) + '\n');
console.log(`done: scanned ${scanned} (winnable ${winnable}), added ${added}, pool now ${pool.seeds.length} seeds -> ${out}`);
