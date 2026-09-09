// The loop directories follow "conclusions in git; evidence and scratch on disk": the nested
// .gitignore in each of .qa-loop/ and .review-loop/ is an ALLOWLIST, so anything unanticipated
// stays untracked by default. .gitignore can't stop a `git add -f` or survive being loosened,
// so these tests check the index itself — this is the layer that caught a Finder-duplicated
// "fragments 2/" (38 scratch files) and a tracked __pycache__/*.pyc in the first place.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFileSync } from 'node:fs';

const REPO = join(dirname(fileURLToPath(import.meta.url)), '..');
const LOOP_DIRS = ['.qa-loop', '.review-loop'];

function trackedLoopFiles() {
  const r = spawnSync('git', ['ls-files', '-z', ...LOOP_DIRS], { cwd: REPO, encoding: 'utf8' });
  assert.equal(r.status, 0, `git ls-files failed: ${r.stderr}`);
  return r.stdout.split('\0').filter(Boolean);
}

test('no scratch directory contents are tracked in the loop dirs', () => {
  const scratchSegment = /(^|\/)(evidence|fragments|briefs|scratch|__pycache__)\//;
  const offenders = trackedLoopFiles().filter((p) => scratchSegment.test(p) || p.endsWith('.pyc'));
  assert.deepEqual(offenders, [], 'scratch/evidence files are tracked; git rm --cached them');
});

test('no Finder-duplication artifacts ("name 2.ext") are tracked in the loop dirs', () => {
  // Finder appends " 2" (or " 3"...) before the extension or to a directory name.
  const finderDup = / \d+(\.[^/]*)?(\/|$)/;
  const offenders = trackedLoopFiles().filter((p) => finderDup.test(p));
  assert.deepEqual(offenders, [], 'a duplicated file escaped the allowlist and got committed');
});

test('every tracked loop file stays report-sized (no screenshots or binaries)', () => {
  // Largest legitimate conclusion today is ~86 KB (HARNESS_NOTES-full.md); evidence starts
  // in the megabytes. 256 KB separates the two with room for reports to grow.
  const files = trackedLoopFiles();
  const r = spawnSync('git', ['cat-file', '--batch-check=%(objectsize) %(rest)', '--buffer'],
    { cwd: REPO, encoding: 'utf8', input: files.map((p) => `:${p} ${p}`).join('\n') });
  assert.equal(r.status, 0, `git cat-file failed: ${r.stderr}`);
  const offenders = r.stdout.split('\n').filter(Boolean)
    .map((line) => { const i = line.indexOf(' '); return [Number(line.slice(0, i)), line.slice(i + 1)]; })
    .filter(([size]) => size > 256 * 1024);
  assert.deepEqual(offenders, [], 'a tracked loop file exceeds 256 KB — evidence belongs on disk');
});

test('the nested .gitignores are still allowlists (default-closed)', () => {
  for (const dir of LOOP_DIRS) {
    const lines = readFileSync(join(REPO, dir, '.gitignore'), 'utf8')
      .split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'));
    assert.equal(lines[0], '*', `${dir}/.gitignore no longer ignores-by-default; ` +
      'the allowlist is the codified "conclusions in git" rule — restore it, don\'t loosen it');
    assert.ok(lines.includes('!.gitignore'), `${dir}/.gitignore must re-include itself`);
  }
});
