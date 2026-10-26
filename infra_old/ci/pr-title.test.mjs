import assert from 'node:assert/strict'
import { spawnSync } from 'node:child_process'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

import { check, checkBranch, checkTitle } from './pr-title.mjs'

const script = join(dirname(fileURLToPath(import.meta.url)), 'pr-title.mjs')

const samples = [
  ['feature/lesson-search', 'feat(web): add lesson search'],
  ['fix/etag-weak-compare', 'fix(api): compare weak etags'],
  ['docs/cicd-11', 'docs: describe release flow'],
  ['chore/bump-sdk', 'build: bump .NET SDK to preview 7'],
  ['ci/pr-title', 'ci: check pull request titles'],
  ['refactor/result-type', 'refactor(api): extract result type'],
  ['test/identity-invites', 'test(api): cover expired invites'],
]

test('branch prefixes from the release model pass with their example titles', () => {
  for (const [branch, title] of samples) {
    assert.deepEqual(check(title, branch), [], `${branch} ${title}`)
  }
})

test('a breaking title passes', () => {
  assert.deepEqual(checkTitle('feat(api)!: drop v1 routes'), [])
})

test('dependabot and release-please branches pass', () => {
  const longTitle = `fix(deps): bump ${'VeryLongPackage'.repeat(8)} from 9.0.3 to 9.0.4`
  assert.ok(longTitle.length > 100)
  assert.deepEqual(check(longTitle, 'dependabot/nuget/VeryLongPackage'), [])
  assert.deepEqual(
    check('fix(deps): bump Npgsql from 9.0.3 to 9.0.4', 'dependabot/nuget/npgsql'),
    [],
  )
  assert.deepEqual(check('chore: release main', 'release-please--branches--main'), [])
})

test('a long title on a feature branch is rejected', () => {
  const longTitle = `fix(deps): bump ${'VeryLongPackage'.repeat(8)} from 9.0.3 to 9.0.4`
  assert.deepEqual(check(longTitle, 'feature/bump-package'), [
    'title is longer than 100 characters',
  ])
})

test('titles that are not Conventional Commits are rejected', () => {
  assert.match(checkTitle('Added search').join('\n'), /Conventional Commits/)
  assert.match(checkTitle('feat: Add search').join('\n'), /lowercase letter or a digit/)
  assert.match(checkTitle('feat: add search.').join('\n'), /period/)
  assert.match(checkTitle('feature: add search').join('\n'), /feature/)
})

test('a branch without a prefix is rejected', () => {
  assert.deepEqual(checkBranch('my-branch'), [
    'branch must match feature|fix|docs|chore|ci|refactor|test/<name>, or start with dependabot/ or release-please--',
  ])
})

test('the cli prints errors and exits 1', () => {
  const result = spawnSync(process.execPath, [script], {
    env: { ...process.env, PR_TITLE: 'Added search', PR_BRANCH: 'my-branch' },
    encoding: 'utf8',
  })
  assert.equal(result.status, 1)
  assert.match(result.stderr, /Conventional Commits/)
  assert.match(result.stderr, /my-branch|branch must match/)
})
