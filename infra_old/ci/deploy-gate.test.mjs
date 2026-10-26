import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

import {
  applicableWorkflows,
  decide,
  fileMatchesPaths,
  gateRelease,
  matchGithubPath,
  parsePushPaths,
} from './deploy-gate.mjs'

const root = join(dirname(fileURLToPath(import.meta.url)), '../..')

const API_PUSH_PATHS = [
  'src/services/Identity/**',
  'src/aspire/JJDevHub.ServiceDefaults/**',
  'src/building-blocks/**',
  'tests/Identity.API.Tests/**',
  'nuget.config',
  'Directory.Build.props',
  'Directory.Packages.props',
  'global.json',
  'JJDevHub.sln',
  'infra/docker/Dockerfile',
  'infra/docker/docker-compose.yml',
  'infra/jaeger/**',
  'infra/grafana/**',
  'infra/ci/nuget-audit.sh',
  'infra/ci/observability-smoke.sh',
  'infra/ci/trivy-api.sh',
  '.github/workflows/api.yml',
]

const WEB_PUSH_PATHS = [
  'src/Clients/web/**',
  'src/Clients/.dockerignore',
  'src/Clients/shared/theme/**',
  'infra/docker/docker-compose.yml',
  'infra/ci/pnpm-audit.sh',
  'infra/ci/pnpm-audit-gate.mjs',
  'infra/ci/pnpm-audit-gate.test.mjs',
  'infra/ci/trivy-web.sh',
  '.github/workflows/web.yml',
]

function liveWorkflows() {
  return [
    { name: 'api', paths: parsePushPaths(readFileSync(join(root, '.github/workflows/api.yml'), 'utf8')) },
    { name: 'web', paths: parsePushPaths(readFileSync(join(root, '.github/workflows/web.yml'), 'utf8')) },
  ]
}

function namesFor(changedFiles, triggerName, extra = {}) {
  return applicableWorkflows({
    workflows: liveWorkflows(),
    changedFiles,
    triggerName,
    ...extra,
  })
}

function success(id, created_at = '2026-10-09T00:00:00Z') {
  return { id, status: 'completed', conclusion: 'success', created_at }
}

test('github path filter examples', () => {
  const cases = [
    ['*', 'README.md', true],
    ['*', 'server.rb', true],
    ['*', 'dir/file', false],
    ['*.jsx?', 'page.js', true],
    ['*.jsx?', 'page.jsx', true],
    ['*.jsx?', 'dir/page.js', false],
    ['**', 'all/the/files.md', true],
    ['*.js', 'app.js', true],
    ['*.js', 'src/app.js', false],
    ['**.js', 'index.js', true],
    ['**.js', 'js/index.js', true],
    ['**.js', 'src/js/app.js', true],
    ['**.js', 'src/app.ts', false],
    ['docs/*', 'docs/README.md', true],
    ['docs/*', 'docs/mona/octocat.txt', false],
    ['docs/**', 'docs/README.md', true],
    ['docs/**', 'docs/mona/octocat.txt', true],
    ['docs/**', 'other/docs/a', false],
    ['docs/**/*.md', 'docs/README.md', true],
    ['docs/**/*.md', 'docs/mona/hello-world.md', true],
    ['docs/**/*.md', 'docs/a/markdown/file.md', true],
    ['docs/**/*.md', 'docs/a/file.txt', false],
    ['**/docs/**', 'docs/hello.md', true],
    ['**/docs/**', 'dir/docs/my-file.txt', true],
    ['**/docs/**', 'space/docs/plan/space.doc', true],
    ['**/README.md', 'README.md', true],
    ['**/README.md', 'js/README.md', true],
    ['**/README.md', 'js/README.md.bak', false],
    ['**/*src/**', 'a/src/app.js', true],
    ['**/*src/**', 'my-src/code/js/app.js', true],
    ['**/*-post.md', 'my-post.md', true],
    ['**/*-post.md', 'path/their-post.md', true],
    ['**/*-post.md', 'post.md', false],
    ['**/migrate-*.sql', 'migrate-10909.sql', true],
    ['**/migrate-*.sql', 'db/migrate-v1.0.sql', true],
    ['**/migrate-*.sql', 'db/sept/migrate-v1.sql', true],
    ['**/migrate-*.sql', 'db/migrate.sql', false],
    ['v[12].[0-9]+.[0-9]+', 'v1.10.1', true],
    ['v[12].[0-9]+.[0-9]+', 'v2.0.0', true],
    ['v[12].[0-9]+.[0-9]+', 'v3.0.0', false],
    ['nuget.config', 'nuget.config', true],
    ['nuget.config', 'nugetXconfig', false],
  ]
  for (const [pattern, file, expected] of cases) {
    assert.equal(matchGithubPath(pattern, file), expected, `${pattern} vs ${file}`)
  }
})

test('negated patterns apply in order', () => {
  assert.equal(fileMatchesPaths(['*.md', '!README.md'], 'hello.md'), true)
  assert.equal(fileMatchesPaths(['*.md', '!README.md'], 'README.md'), false)
  assert.equal(fileMatchesPaths(['*.md', '!README.md'], 'docs/hello.md'), false)
  assert.equal(fileMatchesPaths(['*.md', '!README.md', 'README*'], 'README.md'), true)
  assert.equal(fileMatchesPaths(['*.md', '!README.md', 'README*'], 'README.doc'), true)
  assert.equal(fileMatchesPaths(['sub-project/**', '!sub-project/docs/**'], 'sub-project/index.js'), true)
  assert.equal(fileMatchesPaths(['sub-project/**', '!sub-project/docs/**'], 'sub-project/src/index.js'), true)
  assert.equal(fileMatchesPaths(['sub-project/**', '!sub-project/docs/**'], 'sub-project/docs/readme.md'), false)
})

test('parser reads only on.push.paths', () => {
  const yaml = `
name: sample
on:
  pull_request:
    paths:
      - "only-pr/**"
  push:
    branches: [main]
    paths:
      - "only-push/**"
      - 'exact.txt'
  workflow_dispatch:
`
  assert.deepEqual(parsePushPaths(yaml), ['only-push/**', 'exact.txt'])
})

test('push without paths is unfiltered', () => {
  assert.equal(parsePushPaths('on:\n  push:\n    branches: [main]\n'), null)
})

test('parser rejects a missing on block', () => {
  assert.throws(() => parsePushPaths('name: sample\n'), /missing on: block/)
})

test('live api and web push filters', () => {
  const [api, web] = liveWorkflows()
  assert.deepEqual(api.paths, API_PUSH_PATHS)
  assert.deepEqual(web.paths, WEB_PUSH_PATHS)
})

test('api-only commit does not require web', () => {
  const [api, web] = liveWorkflows()
  assert.equal(fileMatchesPaths(api.paths, 'src/services/Identity/Identity.API/Program.cs'), true)
  assert.equal(fileMatchesPaths(web.paths, 'src/services/Identity/Identity.API/Program.cs'), false)
  assert.deepEqual(namesFor(['src/services/Identity/Identity.API/Program.cs'], 'api'), ['api'])
})

test('web-only commit does not require api', () => {
  const [api, web] = liveWorkflows()
  assert.equal(fileMatchesPaths(web.paths, 'src/Clients/web/src/App.tsx'), true)
  assert.equal(fileMatchesPaths(api.paths, 'src/Clients/web/src/App.tsx'), false)
  assert.deepEqual(namesFor(['src/Clients/web/src/App.tsx'], 'web'), ['web'])
})

test('shared compose file requires api and web', () => {
  assert.deepEqual(namesFor(['infra/docker/docker-compose.yml'], 'api'), ['api', 'web'])
})

test('workflow_dispatch still requires a path-matched sibling', () => {
  assert.deepEqual(namesFor(['src/Clients/web/package.json'], 'api'), ['web', 'api'])
})

test('workflow_dispatch on an untouched commit requires only the trigger', () => {
  assert.deepEqual(namesFor(['README.md'], 'api'), ['api'])
})

test('a truncated diff requires every workflow', () => {
  assert.deepEqual(namesFor(['README.md'], 'web', { filesTruncated: true }), ['api', 'web'])
})

test('an unfiltered push workflow is always required', () => {
  const names = applicableWorkflows({
    workflows: [
      { name: 'api', paths: null },
      { name: 'web', paths: WEB_PUSH_PATHS },
    ],
    changedFiles: ['README.md'],
    triggerName: 'web',
  })
  assert.deepEqual(names, ['api', 'web'])
})

test('both successes deploy', () => {
  const decision = decide({
    applicable: ['api', 'web'],
    runsByWorkflow: { api: [success(1)], web: [success(2)] },
  })
  assert.equal(decision.deploy, true)
})

test('the only applicable success deploys', () => {
  const decision = decide({
    applicable: ['api'],
    runsByWorkflow: { api: [success(1)] },
  })
  assert.equal(decision.deploy, true)
  assert.equal(decision.wait, false)
})

test('a missing sibling run waits', () => {
  const decision = decide({
    applicable: ['api', 'web'],
    runsByWorkflow: { api: [success(1)], web: [] },
  })
  assert.deepEqual(decision, {
    deploy: false,
    wait: true,
    blocked: false,
    pending: ['web'],
    failed: [],
  })
})

test('a queued or in-progress sibling waits', () => {
  for (const status of ['queued', 'in_progress', 'waiting', 'requested', 'pending']) {
    const decision = decide({
      applicable: ['api', 'web'],
      runsByWorkflow: {
        api: [success(1)],
        web: [{ id: 2, status, conclusion: null, created_at: '2026-10-09T00:01:00Z' }],
      },
    })
    assert.equal(decision.wait, true, status)
    assert.deepEqual(decision.pending, ['web'])
  }
})

test('a failed sibling blocks even while another run is still pending', () => {
  const decision = decide({
    applicable: ['api', 'web'],
    runsByWorkflow: {
      api: [{ id: 1, status: 'in_progress', conclusion: null, created_at: '2026-10-09T00:02:00Z' }],
      web: [{ id: 2, status: 'completed', conclusion: 'failure', created_at: '2026-10-09T00:01:00Z' }],
    },
  })
  assert.equal(decision.blocked, true)
  assert.equal(decision.deploy, false)
  assert.deepEqual(decision.failed, [{ name: 'web', conclusion: 'failure' }])
})

test('cancelled, timed out, and startup failure block', () => {
  for (const conclusion of ['cancelled', 'timed_out', 'startup_failure']) {
    const decision = decide({
      applicable: ['web'],
      runsByWorkflow: {
        web: [{ id: 1, status: 'completed', conclusion, created_at: '2026-10-09T00:00:00Z' }],
      },
    })
    assert.equal(decision.blocked, true, conclusion)
    assert.equal(decision.failed[0].conclusion, conclusion)
  }
})

test('the newest run wins over an older result', () => {
  const deployed = decide({
    applicable: ['web'],
    runsByWorkflow: {
      web: [
        { id: 1, status: 'completed', conclusion: 'failure', created_at: '2026-10-09T00:00:00Z' },
        success(2, '2026-10-09T00:05:00Z'),
      ],
    },
  })
  assert.equal(deployed.deploy, true)

  const blocked = decide({
    applicable: ['api'],
    runsByWorkflow: {
      api: [
        success(1, '2026-10-09T00:00:00Z'),
        { id: 2, status: 'completed', conclusion: 'failure', created_at: '2026-10-09T00:05:00Z' },
      ],
    },
  })
  assert.equal(blocked.blocked, true)
})

test('no applicable workflow blocks', () => {
  const decision = decide({ applicable: [], runsByWorkflow: {} })
  assert.equal(decision.blocked, true)
  assert.equal(decision.deploy, false)
})

const RELEASE_SHA = 'a'.repeat(40)
const RELEASE_REPO = 'jtjaskulski/JJDevHub'

function apiResponse(body, link = '') {
  return { body, headers: { get: (name) => (name === 'link' ? link : '') } }
}

function releaseEnv(extra = {}) {
  return {
    REPO: RELEASE_REPO,
    GH_TOKEN: 'token',
    HEAD_SHA: RELEASE_SHA,
    ...extra,
  }
}

test('both green release workflows write the sha', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'deploy-gate-'))
  const output = join(dir, 'github-output')
  try {
    const sha = await gateRelease({
      env: releaseEnv({ GITHUB_OUTPUT: output }),
      github: async (path) => {
        if (path.includes('/workflows/api.yml/runs')) return apiResponse({ workflow_runs: [success(1)] })
        if (path.includes('/workflows/web.yml/runs')) return apiResponse({ workflow_runs: [success(2)] })
        throw new Error(`unexpected ${path}`)
      },
    })
    assert.equal(sha, RELEASE_SHA)
    assert.equal(readFileSync(output, 'utf8'), `sha=${RELEASE_SHA}\n`)
  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})

test('a missing web run dispatches once on the release tag', async () => {
  let webPolls = 0
  let clock = 0
  const dispatches = []
  const sha = await gateRelease({
    env: releaseEnv(),
    now: () => clock,
    sleep: async (ms) => {
      clock += ms
    },
    pollMs: 20_000,
    timeoutMs: 60_000,
    github: async (path, _token, request = {}) => {
      if (request.method === 'POST') {
        dispatches.push({ path, body: request.body })
        return apiResponse({})
      }
      if (path.includes('/tags?')) {
        return apiResponse([{ name: 'api-v0.4.0', commit: { sha: 'annotated-tag-object' } }])
      }
      if (path.includes('/commits/api-v0.4.0')) return apiResponse({ sha: RELEASE_SHA })
      if (path.includes('/workflows/api.yml/runs')) return apiResponse({ workflow_runs: [success(1)] })
      if (path.includes('/workflows/web.yml/runs')) {
        webPolls += 1
        if (webPolls === 1) return apiResponse({ workflow_runs: [] })
        return apiResponse({ workflow_runs: [success(2)] })
      }
      throw new Error(`unexpected ${path}`)
    },
  })
  assert.equal(sha, RELEASE_SHA)
  assert.deepEqual(dispatches, [
    {
      path: `/repos/${RELEASE_REPO}/actions/workflows/web.yml/dispatches`,
      body: { ref: 'api-v0.4.0' },
    },
  ])
})

test('a red api run blocks the release', async () => {
  await assert.rejects(
    () =>
      gateRelease({
        env: releaseEnv(),
        github: async (path) => {
          if (path.includes('/workflows/api.yml/runs')) {
            return apiResponse({
              workflow_runs: [
                { id: 1, status: 'completed', conclusion: 'failure', created_at: '2026-10-09T00:00:00Z' },
              ],
            })
          }
          if (path.includes('/workflows/web.yml/runs')) return apiResponse({ workflow_runs: [success(2)] })
          throw new Error(`unexpected ${path}`)
        },
      }),
    /api failure/,
  )
})

test('a missing run without a release tag fails', async () => {
  const dispatches = []
  await assert.rejects(
    () =>
      gateRelease({
        env: releaseEnv(),
        github: async (path, _token, request = {}) => {
          if (request.method === 'POST') {
            dispatches.push(path)
            return apiResponse({})
          }
          if (path.includes('/tags?')) return apiResponse([])
          if (path.includes('/workflows/api.yml/runs')) return apiResponse({ workflow_runs: [success(1)] })
          if (path.includes('/workflows/web.yml/runs')) return apiResponse({ workflow_runs: [] })
          throw new Error(`unexpected ${path}`)
        },
      }),
    /no release tag/,
  )
  assert.deepEqual(dispatches, [])
})

test('an unfinished release times out', async () => {
  let clock = 0
  await assert.rejects(
    () =>
      gateRelease({
        env: releaseEnv(),
        now: () => clock,
        sleep: async (ms) => {
          clock += ms
        },
        pollMs: 20_000,
        timeoutMs: 60_000,
        github: async (path) => {
          if (path.includes('/workflows/')) {
            return apiResponse({
              workflow_runs: [
                { id: 1, status: 'in_progress', conclusion: null, created_at: '2026-10-09T00:00:00Z' },
              ],
            })
          }
          throw new Error(`unexpected ${path}`)
        },
      }),
    /timed out/,
  )
})

test('a rollback tag resolves to its commit and can dispatch that ref', async () => {
  let webPolls = 0
  let clock = 0
  const dispatches = []
  const tagCalls = []
  const sha = await gateRelease({
    env: releaseEnv({ RELEASE_TAG: 'api-v0.3.0', HEAD_SHA: '' }),
    now: () => clock,
    sleep: async (ms) => {
      clock += ms
    },
    pollMs: 20_000,
    timeoutMs: 60_000,
    github: async (path, _token, request = {}) => {
      if (path.includes('/tags?')) tagCalls.push(path)
      if (request.method === 'POST') {
        dispatches.push(request.body)
        return apiResponse({})
      }
      if (path.includes('/commits/api-v0.3.0')) return apiResponse({ sha: RELEASE_SHA })
      if (path.includes('/workflows/api.yml/runs')) return apiResponse({ workflow_runs: [success(1)] })
      if (path.includes('/workflows/web.yml/runs')) {
        webPolls += 1
        if (webPolls === 1) return apiResponse({ workflow_runs: [] })
        return apiResponse({ workflow_runs: [success(2)] })
      }
      throw new Error(`unexpected ${path}`)
    },
  })
  assert.equal(sha, RELEASE_SHA)
  assert.deepEqual(dispatches, [{ ref: 'api-v0.3.0' }])
  assert.deepEqual(tagCalls, [])
})

test('a rollback tag with the wrong shape is rejected', async () => {
  await assert.rejects(
    () => gateRelease({ env: releaseEnv({ RELEASE_TAG: 'main' }) }),
    /RELEASE_TAG must match/,
  )
})
