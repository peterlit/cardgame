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

test('--extend refuses to shrink or stand still: --days must exceed the published count', () => {
  const dir = mkdtempSync(join(tmpdir(), 'causeway-builder-'));
  const out = join(dir, 'pool.json');
  writeFileSync(out, realPool);
  const r = runBuilder(['--select-only', '--extend', '--cache', join(dir, 'no-such-cache'), '--days', '61', '--out', out]);
  assert.notEqual(r.status, 0);
  assert.match(r.out, /REFUSING.*raise --days/s);
  assert.equal(readFileSync(out, 'utf8'), realPool);
});
