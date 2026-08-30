// tools/loop-usage.py is how the loop's token cost gets measured, and a measurement tool that
// over-reports is worse than none: --since used to filter whole TRANSCRIPT FILES by mtime and then
// sum every record in them, so a long session touched a minute ago counted in full. These tests pin
// the per-record semantics against a synthetic transcript: only records inside the window count,
// and a record with no usable timestamp is COUNTED (never silently dropped) and disclosed.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const TOOL = join(REPO, 'tools/loop-usage.py');
const havePy = spawnSync('python3', ['--version']).status === 0;

const usage = (n) => ({ input_tokens: n, cache_read_input_tokens: 0,
                        cache_creation_input_tokens: 0, output_tokens: 0 });
function fixture() {
  const dir = mkdtempSync(join(tmpdir(), 'loop-usage-'));
  const rec = (ts, id, n) => JSON.stringify({
    ...(ts ? { timestamp: ts } : {}), requestId: id, message: { usage: usage(n) } });
  writeFileSync(join(dir, 'session.jsonl'), [
    rec('2026-01-01T00:00:00.000Z', 'r1', 100),   // before the window
    rec('2026-01-02T00:00:00.000Z', 'r2', 200),   // inside the window
    rec(null, 'r3', 400),                          // undated: counted, and disclosed
  ].join('\n') + '\n');
  return dir;
}
const run = (dir, since) => {
  const r = spawnSync('python3', [TOOL, '--dir', dir, '--since', String(since)], { encoding: 'utf8' });
  assert.equal(r.status, 0, `loop-usage.py failed: ${r.stderr}`);
  return { rows: JSON.parse(r.stdout), stderr: r.stderr };
};

test('loop-usage --since filters per RECORD, not per transcript file', { skip: !havePy && 'python3 unavailable' }, () => {
  const dir = fixture();
  const since = Date.parse('2026-01-01T12:00:00Z') / 1000;
  const { rows } = run(dir, since);
  assert.equal(rows.length, 1);
  // r1 is before the cutoff and must NOT be summed just because the file is recent.
  assert.equal(rows[0].requests, 2, 'records outside the window were counted (file-granular filter?)');
  assert.equal(rows[0].input_tokens, 600, 'summed the wrong records');
});

test('loop-usage counts an undated record and says so rather than dropping it', { skip: !havePy && 'python3 unavailable' }, () => {
  const dir = fixture();
  const since = Date.parse('2026-01-01T12:00:00Z') / 1000;
  const { rows, stderr } = run(dir, since);
  assert.equal(rows[0].undated, 1, 'undated records are not disclosed in the row');
  assert.match(stderr, /undated|no parsable timestamp/i, 'no stderr note about undated records');
  // ...and with no window at all, everything counts and nothing is flagged.
  const all = run(dir, 0).rows;
  assert.equal(all[0].requests, 3);
  assert.equal(all[0].undated, 0);
});
