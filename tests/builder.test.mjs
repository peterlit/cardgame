// R8 (skeptical review 2026-09-07): the content builder's publishing contract, tested by RUNNING
// the builder. The reproduced failure: with a missing certification cache, `--select-only --days
// 92` warned it could fill 0 of 92 days, then OVERWROTE a 61-day pool with zero days and exited 0.
// Publication now fails closed, refuses to clobber published days without an explicit mode, and
// an extension must preserve every published day verbatim. All runs here use scratch copies and a
// deliberately missing cache, so they are fast and touch no real asset.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const BUILDER = join(REPO, 'tools/solver/build-month.mjs');
const realPool = readFileSync(join(REPO, 'data/daily-pool.json'), 'utf8');
// The tracked certification cache: the POSITIVE cases below select from it (--select-only never
// solves, so they are fast). A suite proving only that the tool refuses is satisfied by a tool
// that always refuses — R1 shipped exactly that way, so publishing success is now asserted too.
const REAL_CACHE = join(REPO, '.cache/month-certs');
// A day's exact challenge identity, with object keys canonicalized (published and fresh days are
// serialized by the same code, but the comparison must not depend on that).
const canon = o => JSON.stringify(o, (k, v) =>
  v && typeof v === 'object' && !Array.isArray(v)
    ? Object.fromEntries(Object.keys(v).sort().map(x => [x, v[x]])) : v);
const pairOf = d => canon([d.silver.id, d.silver.param, d.gold.id, d.gold.param]);
// "An exact challenge is never repeated" (docs/solver.md) is one rule, and it binds the days
// selected in ONE run as much as the seam: the published pool's days 3 and 60 shipped the same
// (Silver, Gold) pair because the within-run rule was only a score penalty (R1 minor:
// within-run-pair-repeat). Those two are history; every run from now on is held to the rule.
const assertNoPairRepeat = (days, label) => {
  const seen = new Map();
  days.forEach((d, i) => {
    const p = pairOf(d);
    assert.ok(!seen.has(p), `${label}: days ${seen.get(p)} and ${i} ship the identical (silver, gold) challenge ${p}`);
    seen.set(p, i);
  });
};
// The per-family variety cap (closeout: cap-variety-never-asserted). selectMonthBalanced tops out
// at capPerFamily = 12 (build-month.mjs), and capped() is the only mechanism keeping a tier from
// reading as one idea. The cap governs the days selected by THIS run (an extension's published
// days are history, not cap charges — round-2 blocker), so `days` here is the selected slice.
// Real headroom is ~5 uses per family, so >12 cannot flake.
const CAP_CEILING = 12;
const assertFamilyCap = (days, label) => {
  for (const tier of ['silver', 'gold']) {
    const uses = new Map();
    for (const d of days) uses.set(d[tier].id, (uses.get(d[tier].id) || 0) + 1);
    for (const [id, n] of uses)
      assert.ok(n <= CAP_CEILING,
        `${label}: ${tier} family "${id}" fills ${n} of ${days.length} selected days — the per-family cap (max ${CAP_CEILING}) is not being enforced`);
  }
};

function runBuilder(args) {
  try {
    const stdout = execFileSync('node', [BUILDER, ...args], { encoding: 'utf8', stdio: 'pipe' });
    return { status: 0, out: stdout };
  } catch (e) {
    return { status: e.status, out: (e.stdout || '') + (e.stderr || '') };
  }
}

test('an underfilled selection FAILS CLOSED instead of overwriting the pool with nothing', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  // Fresh mode (no existing output), empty cache: 0 of 92 days can fill. The reproduced bug
  // wrote a 0-day pool here and exited 0.
  const r = runBuilder(['--select-only', '--cache', join(dir, 'no-such-cache'), '--days', '92', '--out', out]);
  assert.notEqual(r.status, 0, 'an underfilled build must exit nonzero');
  assert.match(r.out, /FAILING CLOSED/);
  assert.ok(!existsSync(out), 'nothing may be published from an underfilled selection');
});

test('a non-empty published pool refuses a bare overwrite — the mode must be explicit', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const r = runBuilder(['--select-only', '--cache', join(dir, 'no-such-cache'), '--days', '92', '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /REFUSING/);
  assert.match(r.out, /--extend/, 'the refusal must teach the safe path');
  assert.equal(readFileSync(out, 'utf8'), realPool, 'the published pool must be untouched');
});

test('--extend with nothing certified fails closed and leaves every published day in place', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const want = JSON.parse(realPool).days.length + 31;   // one more month than is published
  const r = runBuilder(['--select-only', '--extend', '--cache', join(dir, 'no-such-cache'), '--days', String(want), '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /FAILING CLOSED/);
  assert.equal(readFileSync(out, 'utf8'), realPool, 'extension failure must not touch the published days');
});

test('--rebuild on the same POOL_VERSION refuses — a rebuild is a generation change', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const r = runBuilder(['--select-only', '--rebuild', '--cache', join(dir, 'no-such-cache'), '--days', '92', '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /REFUSING.*POOL_VERSION/s);
  assert.equal(readFileSync(out, 'utf8'), realPool);
});

test('a pool that exists but will not parse REFUSES — corruption is not absence', () => {
  // R1 blocker sibling: a truncated daily-pool.json used to fall through to `existing = null`,
  // and a bare run then rebuilt 61 published days from scratch, exiting 0.
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  const truncated = realPool.slice(0, 400);
  writeFileSync(out, truncated);
  const r = runBuilder(['--select-only', '--no-flawless-gate', '--cache', REAL_CACHE, '--days', '31', '--out', out]);
  assert.notEqual(r.status, 0, 'a corrupt pool must refuse, not count as absent');
  assert.match(r.out, /REFUSING.*cannot be parsed/s);
  assert.equal(readFileSync(out, 'utf8'), truncated, 'the corrupt file must be left for a human, untouched');
});

test('the builder can still PUBLISH: a fresh select-only run against the real cache writes a valid pool', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  const r = runBuilder(['--select-only', '--no-flawless-gate', '--cache', REAL_CACHE, '--days', '31', '--out', out]);
  assert.equal(r.status, 0, 'fresh publish failed:\n' + r.out);
  const pool = JSON.parse(readFileSync(out, 'utf8'));
  assert.equal(pool.days.length, 31);
  assert.equal(new Set(pool.days.map(d => d.seed)).size, 31, 'every day must use a distinct seed');
  for (const d of pool.days) {
    assert.ok(d.silver?.id && d.gold?.id && Number.isFinite(d.par), 'every day must be complete');
    assert.notEqual(d.silver.id, d.gold.id, 'a day must never pair a family with itself');
  }
  assertFamilyCap(pool.days, 'fresh publish');
  assertNoPairRepeat(pool.days, 'fresh publish');
});

test('a run whose material forces a repeated (silver, gold) pair FAILS CLOSED rather than shipping it twice', () => {
  // Reproduction of the day-3/day-60 hole with a cache that leaves the selector no honest choice:
  // seven eligible seeds that each certify exactly ONE Gold (cells-le{N:0}) and no Silver-grade
  // variant, so the only Silvers are the universal ones — five `moves` caps (one per factor, all
  // distinct at par 100) and no-undo. Six distinct pairs exist; a seventh day can only repeat one.
  // Before the fix the selector took the -60 penalty and published the repeat with exit 0.
  const seeds = readFileSync(join(REPO, '.cache/month-certs-0.jsonl'), 'utf8').trim().split('\n')
    .slice(0, 7).map(l => JSON.parse(l).seed);           // real candidates, so the builder's list admits them
  assert.equal(seeds.length, 7);
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  writeFileSync(join(dir, 'certs-0.jsonl'), seeds.map(seed => JSON.stringify(
    { seed, winnable: true, par: 100, supports: [{ id: 'cells-le', param: { N: 0 }, par: 100 }] })).join('\n') + '\n');
  const cache = join(dir, 'certs');
  // Positive control first: six days DO fill from this material, with six distinct pairs — so the
  // refusal below is the never-repeat rule, not a fixture the selector cannot read.
  const ok6 = join(dir, 'six.json');
  const r6 = runBuilder(['--select-only', '--no-flawless-gate', '--cache', cache, '--days', '6', '--out', ok6]);
  assert.equal(r6.status, 0, 'six distinct pairs must publish:\n' + r6.out);
  const six = JSON.parse(readFileSync(ok6, 'utf8')).days;
  assert.equal(six.length, 6);
  assertNoPairRepeat(six, 'six-day control');
  // The seventh slot has nothing but a repeat to offer: the SELECTOR must refuse it (so the run
  // fails closed as under-filled), and no pool may be written.
  const out7 = join(dir, 'seven.json');
  const r7 = runBuilder(['--select-only', '--no-flawless-gate', '--cache', cache, '--days', '7', '--out', out7]);
  assert.notEqual(r7.status, 0, 'a forced repeat must not publish:\n' + r7.out);
  assert.match(r7.out, /FAILING CLOSED: only 6 of 7 days could be filled/,
    'the selector itself must leave the seventh slot empty rather than hand a repeat to the validator');
  assert.ok(!existsSync(out7), 'no pool may be written when the selection is refused');
});

test('--extend fills a FULL MONTH of open slots, keeps every published day verbatim, and repeats no published challenge', () => {
  // R1 blocker: the selector was asked for nDays instead of the open slots, so 61 published +
  // nDays fresh always failed the candidate day-count validation — --extend could NEVER publish,
  // and --extend is the only sanctioned way to reseed the pool past 2026-09-30.
  // R2 blocker (extend-cap-starvation): the R1 fix charged the published days against the
  // per-family CAP (max 12), whose 61 days pre-spent 9 slots on six silver families — so any
  // extension past 23 days failed closed forever, and this test's original +4 was the one size
  // small enough to dodge the ceiling. The extension size below is the actual use case: a full
  // 31-day month. Do not shrink it.
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const published = JSON.parse(realPool).days;
  const want = published.length + 31;
  const r = runBuilder(['--select-only', '--no-flawless-gate', '--extend', '--cache', REAL_CACHE,
                        '--days', String(want), '--out', out]);
  assert.equal(r.status, 0, 'extension failed:\n' + r.out);
  const pool = JSON.parse(readFileSync(out, 'utf8'));
  assert.equal(pool.days.length, want, 'the extension must land exactly at --days');
  for (let i = 0; i < published.length; i++)
    assert.deepEqual(pool.days[i], published[i], `published day ${i} must be preserved verbatim`);
  assert.equal(new Set(pool.days.map(d => d.seed)).size, want, 'a published seed must not be re-dealt');
  // The builder's own never-repeat rule, across the published/new seam (R1 major): a fresh day
  // re-issuing an exact published (silver, gold) pair silently reruns August's puzzle.
  const publishedPairs = new Set(published.map(pairOf));
  for (let i = published.length; i < pool.days.length; i++)
    assert.ok(!publishedPairs.has(pairOf(pool.days[i])),
      `fresh day ${i} repeats a published (silver, gold) challenge pair`);
  assertFamilyCap(pool.days.slice(published.length), '--extend fresh days');
  assertNoPairRepeat(pool.days.slice(published.length), '--extend fresh days');
});

test('--extend refuses to shrink or stand still: --days must exceed the published count', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const published = String(JSON.parse(realPool).days.length);   // --days == what is already published
  const r = runBuilder(['--select-only', '--extend', '--cache', join(dir, 'no-such-cache'), '--days', published, '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /REFUSING.*raise --days/s);
  assert.equal(readFileSync(out, 'utf8'), realPool);
});
