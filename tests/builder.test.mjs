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
  const r = runBuilder(['--select-only', '--extend', '--cache', join(dir, 'no-such-cache'), '--days', '92', '--out', out]);
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
});

test('--extend fills exactly the open slots, keeps every published day verbatim, and repeats no published challenge', () => {
  // R1 blocker: the selector was asked for nDays instead of the open slots, so 61 published +
  // nDays fresh always failed the candidate day-count validation — --extend could NEVER publish,
  // and --extend is the only sanctioned way to reseed the pool past 2026-09-30.
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const published = JSON.parse(realPool).days;
  const want = published.length + 4;
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
});

test('--extend refuses to shrink or stand still: --days must exceed the published count', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const r = runBuilder(['--select-only', '--extend', '--cache', join(dir, 'no-such-cache'), '--days', '61', '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /REFUSING.*raise --days/s);
  assert.equal(readFileSync(out, 'utf8'), realPool);
});
