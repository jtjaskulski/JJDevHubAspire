import { appendFileSync, realpathSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const WORKFLOWS = [
  { name: 'api', file: 'api.yml' },
  { name: 'web', file: 'web.yml' },
]
const API = 'https://api.github.com'
const TAG_NAME = /^[a-z0-9-]+-v\d+\.\d+\.\d+$/
const POLL_MS = 20_000
const TIMEOUT_MS = 60 * 60 * 1000

// GitHub path filters: `*` does not cross `/`, `**` does, and `**/` may match
// zero directories (`docs/**/*.md` matches `docs/README.md`). `?` and `+`
// quantify the preceding atom. The pattern matches the whole path.
export function matchGithubPath(pattern, file) {
  return githubGlobToRegExp(pattern).test(file)
}

export function fileMatchesPaths(patterns, file) {
  let matched = false
  for (const pattern of patterns) {
    if (typeof pattern !== 'string' || pattern === '') {
      throw new Error('deploy: empty path pattern')
    }
    const negated = pattern.startsWith('!')
    const body = negated ? pattern.slice(1) : pattern
    if (body === '') throw new Error(`deploy: invalid path pattern ${pattern}`)
    if (!matchGithubPath(body, file)) continue
    matched = !negated
  }
  return matched
}

// `null` means `on.push` has no `paths` filter, so the workflow always runs.
export function parsePushPaths(yaml) {
  const lines = String(yaml).replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
  let section = 'root'
  let onIndent = 0
  let pushIndent = 0
  let pathsIndent = 0
  let sawOn = false
  let sawPush = false
  let sawPaths = false
  const paths = []

  for (let index = 0; index < lines.length; index++) {
    const raw = lines[index]
    if (raw.trim() === '' || raw.trim().startsWith('#')) continue
    if (/^\t/.test(raw)) throw new Error(`workflow:${index + 1}: tabs are not allowed`)
    const indent = raw.match(/^ */)?.[0].length ?? 0
    const text = raw.trim()
    const line = index + 1

    if (section === 'root') {
      if (text === 'on:') {
        section = 'on'
        onIndent = indent
        sawOn = true
      }
      continue
    }

    if (section === 'on') {
      if (indent <= onIndent) {
        section = 'root'
        continue
      }
      if (text === 'push:') {
        section = 'push'
        pushIndent = indent
        sawPush = true
      }
      continue
    }

    if (section === 'push') {
      if (indent <= pushIndent) {
        section = indent <= onIndent ? 'root' : 'on'
        continue
      }
      if (text === 'paths:') {
        section = 'paths'
        pathsIndent = indent
        sawPaths = true
        continue
      }
      if (text.startsWith('paths:')) {
        throw new Error(`workflow:${line}: push.paths must be a block list`)
      }
      continue
    }

    if (indent <= pathsIndent) {
      if (indent <= pushIndent) section = indent <= onIndent ? 'root' : 'on'
      else section = 'push'
      continue
    }

    const item = text.match(/^-\s+(?:"([^"]*)"|'([^']*)'|(\S+))$/)
    if (!item) throw new Error(`workflow:${line}: expected a path entry`)
    paths.push(item[1] ?? item[2] ?? item[3])
  }

  if (!sawOn) throw new Error('workflow: missing on: block')
  if (!sawPush) throw new Error('workflow: missing on.push')
  if (!sawPaths) return null
  return paths
}

export function applicableWorkflows({ workflows, changedFiles, triggerName, filesTruncated = false }) {
  const names = []
  const seen = new Set()
  const add = (name) => {
    if (!name || seen.has(name)) return
    seen.add(name)
    names.push(name)
  }

  for (const workflow of workflows) {
    if (filesTruncated || workflow.paths == null) {
      add(workflow.name)
      continue
    }
    if (changedFiles.some((file) => fileMatchesPaths(workflow.paths, file))) add(workflow.name)
  }
  add(triggerName)
  return names
}

export function decide({ applicable, runsByWorkflow }) {
  const pending = []
  const failed = []

  if (applicable.length === 0) {
    return {
      deploy: false,
      wait: false,
      blocked: true,
      pending,
      failed: [{ name: '(none)', conclusion: 'no applicable workflow' }],
    }
  }

  for (const name of applicable) {
    const runs = runsByWorkflow[name] ?? []
    if (runs.length === 0) {
      pending.push(name)
      continue
    }
    const latest = latestRun(runs)
    if (latest.status !== 'completed') {
      pending.push(name)
      continue
    }
    if (latest.conclusion !== 'success') {
      failed.push({ name, conclusion: latest.conclusion ?? 'missing' })
    }
  }

  if (failed.length > 0) {
    return { deploy: false, wait: false, blocked: true, pending, failed }
  }
  if (pending.length > 0) {
    return { deploy: false, wait: true, blocked: false, pending, failed }
  }
  return { deploy: true, wait: false, blocked: false, pending, failed }
}

export async function gateRelease({
  env = process.env,
  github = requestGitHub,
  sleep = delay,
  now = Date.now,
  pollMs = POLL_MS,
  timeoutMs = TIMEOUT_MS,
} = {}) {
  const repo = env.REPO ?? ''
  const token = env.GH_TOKEN || env.GITHUB_TOKEN || ''
  if (!/^[^/\s]+\/[^/\s]+$/.test(repo)) throw new Error('deploy: REPO must be owner/name')
  if (!token) throw new Error('deploy: GH_TOKEN is required')

  const releaseTag = env.RELEASE_TAG ?? ''
  let sha
  let tag = ''
  if (releaseTag !== '') {
    if (!TAG_NAME.test(releaseTag)) {
      throw new Error('deploy: RELEASE_TAG must match <component>-vX.Y.Z')
    }
    sha = await commitShaForTag(repo, releaseTag, token, github)
    tag = releaseTag
  } else {
    sha = env.HEAD_SHA ?? ''
    if (!/^[0-9a-f]{40}$/i.test(sha)) throw new Error('deploy: HEAD_SHA must be a full commit sha')
  }

  const deadline = now() + timeoutMs
  const dispatched = new Set()

  while (now() < deadline) {
    const runsByWorkflow = {}
    for (const workflow of WORKFLOWS) {
      runsByWorkflow[workflow.name] = await listRuns(repo, workflow.file, sha, token, github)
    }
    const state = classifyRuns(runsByWorkflow)
    if (state.failed.length > 0) {
      const detail = state.failed.map((item) => `${item.name} ${item.conclusion}`).join(', ')
      throw new Error(`deploy: blocked for ${sha}: ${detail}`)
    }
    if (state.ready) {
      console.log(`deploy: api, web succeeded for ${sha}`)
      writeOutput(env, sha)
      return sha
    }

    const toDispatch = state.missing.filter((name) => !dispatched.has(name))
    if (toDispatch.length > 0) {
      if (tag === '') {
        tag = await findTagPointingAt(repo, sha, token, github)
        if (tag === '') throw new Error(`deploy: no release tag for ${sha}`)
      }
      for (const name of toDispatch) {
        const workflow = WORKFLOWS.find((item) => item.name === name)
        await github(`/repos/${repo}/actions/workflows/${workflow.file}/dispatches`, token, {
          method: 'POST',
          body: { ref: tag },
        })
        dispatched.add(name)
      }
    }

    const remaining = deadline - now()
    if (remaining <= 0) break
    await sleep(Math.min(pollMs, remaining))
  }

  throw new Error(`deploy: timed out for ${sha}`)
}

function classifyRuns(runsByWorkflow) {
  const failed = []
  const pending = []
  const missing = []
  for (const workflow of WORKFLOWS) {
    const runs = runsByWorkflow[workflow.name] ?? []
    if (runs.length === 0) {
      missing.push(workflow.name)
      continue
    }
    const latest = latestRun(runs)
    if (latest.status !== 'completed') {
      pending.push(workflow.name)
      continue
    }
    if (latest.conclusion !== 'success') {
      failed.push({ name: workflow.name, conclusion: latest.conclusion ?? 'missing' })
    }
  }
  return {
    failed,
    pending,
    missing,
    ready: failed.length === 0 && pending.length === 0 && missing.length === 0,
  }
}

export async function main(env = process.env) {
  return gateRelease({ env })
}

function githubGlobToRegExp(pattern) {
  if (typeof pattern !== 'string' || pattern === '') {
    throw new Error('deploy: empty path pattern')
  }
  let source = ''
  let index = 0
  while (index < pattern.length) {
    const atom = readAtom(pattern, index)
    index = atom.next
    if (pattern[index] === '?' || pattern[index] === '+') {
      source += `(?:${atom.source})${pattern[index]}`
      index += 1
      continue
    }
    source += atom.source
  }
  return new RegExp(`^${source}$`)
}

function readAtom(pattern, index) {
  if (pattern[index] === '\\') {
    if (index + 1 >= pattern.length) throw new Error(`deploy: trailing escape in ${pattern}`)
    return { source: escapeChar(pattern[index + 1]), next: index + 2 }
  }
  if (pattern.startsWith('**/', index)) return { source: '(?:.*/)?', next: index + 3 }
  if (pattern.startsWith('**', index)) return { source: '.*', next: index + 2 }
  if (pattern[index] === '*') return { source: '[^/]*', next: index + 1 }
  if (pattern[index] === '[') {
    const end = pattern.indexOf(']', index + 1)
    if (end === -1) throw new Error(`deploy: unclosed character class in ${pattern}`)
    return { source: `[${pattern.slice(index + 1, end)}]`, next: end + 1 }
  }
  if (pattern[index] === '?' || pattern[index] === '+') {
    throw new Error(`deploy: ${pattern[index]} has nothing to quantify in ${pattern}`)
  }
  return { source: escapeChar(pattern[index]), next: index + 1 }
}

function escapeChar(char) {
  return /[\\^$.*+?()[\]{}|]/.test(char) ? `\\${char}` : char
}

function latestRun(runs) {
  return runs.slice().sort((left, right) => {
    const byTime = Date.parse(right.created_at ?? '') - Date.parse(left.created_at ?? '')
    if (Number.isFinite(byTime) && byTime !== 0) return byTime
    return (right.id ?? 0) - (left.id ?? 0)
  })[0]
}

function delay(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms)
  })
}

async function commitShaForTag(repo, tag, token, github) {
  const { body } = await github(`/repos/${repo}/commits/${encodeURIComponent(tag)}`, token)
  if (typeof body.sha !== 'string' || !/^[0-9a-f]{40}$/i.test(body.sha)) {
    throw new Error(`deploy: tag ${tag} did not resolve to a commit`)
  }
  return body.sha
}

async function findTagPointingAt(repo, sha, token, github) {
  for (let page = 1; page <= 10; page++) {
    const { body, headers } = await github(`/repos/${repo}/tags?per_page=100&page=${page}`, token)
    if (!Array.isArray(body)) throw new Error('deploy: tags were not a list')
    for (const tag of body) {
      if (typeof tag?.name !== 'string' || !TAG_NAME.test(tag.name)) continue
      const commitSha = await commitShaForTag(repo, tag.name, token, github)
      if (commitSha === sha) return tag.name
    }
    const link = headers.get('link') ?? ''
    if (!link.includes('rel="next"')) return ''
    if (page === 10) throw new Error(`deploy: too many tags while looking for ${sha}`)
  }
  return ''
}

async function listRuns(repo, file, sha, token, github) {
  const runs = []
  for (let page = 1; page <= 10; page++) {
    const { body, headers } = await github(
      `/repos/${repo}/actions/workflows/${file}/runs?head_sha=${sha}&per_page=100&page=${page}`,
      token,
    )
    if (!Array.isArray(body.workflow_runs)) {
      throw new Error(`deploy: workflow runs for ${file} at ${sha} were not a list`)
    }
    for (const run of body.workflow_runs) {
      runs.push({
        id: run.id,
        status: run.status,
        conclusion: run.conclusion,
        created_at: run.created_at,
      })
    }
    const link = headers.get('link') ?? ''
    if (!link.includes('rel="next"')) return runs
    if (page === 10) throw new Error(`deploy: too many runs for ${file} at ${sha}`)
  }
  return runs
}

async function requestGitHub(path, token, request = {}) {
  const headers = {
    Accept: 'application/vnd.github+json',
    Authorization: `Bearer ${token}`,
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'jjdevhub-deploy-gate',
  }
  const init = { method: request.method ?? 'GET', headers }
  if (request.body !== undefined) {
    headers['Content-Type'] = 'application/json'
    init.body = JSON.stringify(request.body)
  }
  const response = await fetch(`${API}${path}`, init)
  const text = await response.text()
  let body = {}
  if (text) {
    try {
      body = JSON.parse(text)
    } catch {
      body = { message: text.slice(0, 300) }
    }
  }
  if (!response.ok) {
    const message = typeof body.message === 'string' ? body.message : response.statusText
    const error = new Error(`GitHub API ${response.status} ${path}: ${message}`)
    error.status = response.status
    throw error
  }
  return { body, headers: response.headers }
}

function writeOutput(env, sha) {
  if (!env.GITHUB_OUTPUT) return
  appendFileSync(env.GITHUB_OUTPUT, `sha=${sha}\n`)
}

function invokedAsCli() {
  const entry = process.argv[1]
  if (!entry) return false
  try {
    return import.meta.url === pathToFileURL(realpathSync(entry)).href
  } catch {
    return false
  }
}

if (invokedAsCli()) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error)
    process.exit(1)
  })
}
