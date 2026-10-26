import { realpathSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const TYPES = new Set([
  'feat',
  'fix',
  'perf',
  'refactor',
  'docs',
  'test',
  'build',
  'ci',
  'chore',
  'revert',
])

const TITLE =
  /^(?<type>[a-z]+)(\((?<scope>[a-z0-9-]+)\))?(?<breaking>!)?: (?<subject>.+)$/

const BRANCH = /^(feature|fix|docs|chore|ci|refactor|test)\/[a-z0-9][a-z0-9-]*$/

const LENGTH = 'title is longer than 100 characters'

export function checkTitle(title) {
  const errors = []
  const value = typeof title === 'string' ? title : ''
  if (value.length > 100) errors.push(LENGTH)

  const match = TITLE.exec(value)
  if (!match?.groups) {
    errors.push('title must match Conventional Commits: type(scope)!: subject')
    return errors
  }

  if (!TYPES.has(match.groups.type)) {
    errors.push(`type ${match.groups.type} is not a Conventional Commit type`)
  }

  const subject = match.groups.subject
  if (!/^[a-z0-9]/.test(subject)) {
    errors.push('subject must start with a lowercase letter or a digit')
  }
  if (subject.endsWith('.')) {
    errors.push('subject must not end with a period')
  }
  return errors
}

export function checkBranch(branch) {
  const value = typeof branch === 'string' ? branch : ''
  if (value.startsWith('dependabot/') || value.startsWith('release-please--')) return []
  if (BRANCH.test(value)) return []
  return [
    'branch must match feature|fix|docs|chore|ci|refactor|test/<name>, or start with dependabot/ or release-please--',
  ]
}

export function check(title, branch) {
  const branchName = typeof branch === 'string' ? branch : ''
  const titleErrors = checkTitle(title)
  const kept = branchName.startsWith('dependabot/')
    ? titleErrors.filter((error) => error !== LENGTH)
    : titleErrors
  return [...kept, ...checkBranch(branchName)]
}

function report(title, branch) {
  const errors = check(title, branch)
  if (errors.length === 0) return
  for (const error of errors) console.error(error)
  process.exitCode = 1
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
  report(process.env.PR_TITLE ?? '', process.env.PR_BRANCH ?? '')
}
