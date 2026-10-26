import { readFileSync, realpathSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const GHSA_ID = /^GHSA-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}$/i
const PACKAGE_NAME = /^(?:@[a-z0-9-~][a-z0-9-._~]*\/)?[a-z0-9-~][a-z0-9-._~]*$/
const VERSION = /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/
const ENTRY_KEYS = new Set(['package', 'version', 'dev_only', 'paths', 'expired_at', 'reason'])
const BELOW_HIGH = new Set(['info', 'low', 'moderate'])
const MIN_REASON = 40

export function utcToday(now = new Date()) {
  return now.toISOString().slice(0, 10)
}

export function parseExceptions(text) {
  const lines = String(text).replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n')
  const content = []
  for (let index = 0; index < lines.length; index++) {
    const raw = lines[index]
    const textLine = raw.trim()
    if (textLine === '' || textLine.startsWith('#')) continue
    const indent = raw.match(/^ */)?.[0].length ?? 0
    if (raw[indent] === '\t') {
      throw new Error(`pnpm-audit-exceptions.yaml:${index + 1}: tabs are not allowed`)
    }
    content.push({ indent, text: textLine, line: index + 1 })
  }

  if (content.length === 0) return []
  if (content[0].indent !== 0 || content[0].text !== 'advisories:') {
    throw new Error(`pnpm-audit-exceptions.yaml:${content[0].line}: expected top-level "advisories:"`)
  }

  const entries = []
  let index = 1
  while (index < content.length) {
    const item = content[index]
    if (item.indent !== 2 || !item.text.startsWith('- id:')) {
      throw new Error(`pnpm-audit-exceptions.yaml:${item.line}: expected "- id:"`)
    }
    const fields = {
      id: parseScalar(item.text.slice('- id:'.length), item.line, 'id'),
    }
    index += 1
    let paths = null
    while (index < content.length && content[index].indent > 2) {
      const row = content[index]
      if (row.indent !== 4) {
        throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: unexpected indent`)
      }
      const separator = row.text.indexOf(':')
      if (separator <= 0) {
        throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: expected a key`)
      }
      const key = row.text.slice(0, separator).trim()
      const rest = row.text.slice(separator + 1).trim()
      if (!ENTRY_KEYS.has(key)) {
        throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: unexpected key "${key}"`)
      }
      if (Object.hasOwn(fields, key) || (key === 'paths' && paths != null)) {
        throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: duplicate key "${key}"`)
      }
      if (key === 'paths') {
        if (rest !== '') {
          throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: paths must be a list`)
        }
        paths = []
        index += 1
        while (index < content.length && content[index].indent === 6) {
          const pathLine = content[index]
          if (!pathLine.text.startsWith('- ')) {
            throw new Error(`pnpm-audit-exceptions.yaml:${pathLine.line}: expected a path list item`)
          }
          const scope = parseScalar(pathLine.text.slice(2), pathLine.line, 'paths')
          if (scope.length < 3) {
            throw new Error(`pnpm-audit-exceptions.yaml:${pathLine.line}: path scope is too short`)
          }
          paths.push(scope)
          index += 1
        }
        if (paths.length === 0) {
          throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: paths must not be empty`)
        }
        continue
      }
      if (rest === '') {
        throw new Error(`pnpm-audit-exceptions.yaml:${row.line}: ${key} needs a value`)
      }
      fields[key] = parseScalar(rest, row.line, key)
      index += 1
    }
    entries.push(normalizeEntry(fields, paths, item.line))
  }

  const seen = new Set()
  for (const entry of entries) {
    const key = `${entry.id.toLowerCase()}\0${entry.package}\0${entry.version}`
    if (seen.has(key)) {
      throw new Error(
        `pnpm-audit-exceptions.yaml: duplicate waiver for ${entry.id} ${entry.package}@${entry.version}`,
      )
    }
    seen.add(key)
  }
  return entries
}

function parseScalar(raw, line, key) {
  const text = raw.trim()
  if (text === '') {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: ${key} needs a value`)
  }
  if (text.startsWith('"')) {
    if (!text.endsWith('"') || text.length < 2) {
      throw new Error(`pnpm-audit-exceptions.yaml:${line}: unterminated string`)
    }
    return text.slice(1, -1).replace(/\\n/g, '\n').replace(/\\"/g, '"').replace(/\\\\/g, '\\')
  }
  if (text.startsWith("'")) {
    if (!text.endsWith("'") || text.length < 2) {
      throw new Error(`pnpm-audit-exceptions.yaml:${line}: unterminated string`)
    }
    return text.slice(1, -1).replace(/''/g, "'")
  }
  if (text.includes(' #')) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: trailing comments are not allowed`)
  }
  return text
}

function normalizeEntry(fields, paths, line) {
  for (const key of ['id', 'package', 'version', 'dev_only', 'expired_at', 'reason']) {
    if (fields[key] == null) {
      throw new Error(`pnpm-audit-exceptions.yaml:${line}: missing ${key}`)
    }
  }
  if (paths == null) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: missing paths`)
  }
  if (!GHSA_ID.test(fields.id)) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: id must be a GHSA id`)
  }
  if (!PACKAGE_NAME.test(fields.package)) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: package name is invalid`)
  }
  if (!VERSION.test(fields.version)) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: version is invalid`)
  }
  if (fields.dev_only !== 'true' && fields.dev_only !== 'false') {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: dev_only must be true or false`)
  }
  if (!isIsoDate(fields.expired_at)) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: expired_at must be YYYY-MM-DD`)
  }
  const reason = fields.reason.trim()
  if (reason.length < MIN_REASON) {
    throw new Error(`pnpm-audit-exceptions.yaml:${line}: reason must explain the waiver`)
  }
  return {
    id: fields.id,
    package: fields.package,
    version: fields.version,
    devOnly: fields.dev_only === 'true',
    paths,
    expiredAt: fields.expired_at,
    reason,
  }
}

function isIsoDate(value) {
  if (!ISO_DATE.test(value)) return false
  const [year, month, day] = value.split('-').map(Number)
  const date = new Date(Date.UTC(year, month - 1, day))
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day
}

export function evaluateAudit({ report, exceptions, packageJson, today }) {
  if (!isIsoDate(today)) {
    throw new Error(`today must be YYYY-MM-DD, got ${today}`)
  }
  if (report == null || typeof report !== 'object' || Array.isArray(report) ||
    report.advisories == null || typeof report.advisories !== 'object' || Array.isArray(report.advisories)) {
    throw new Error('pnpm audit JSON has no advisories object')
  }

  const lines = []
  let ok = true
  const permanent = permanentIgnoreKeys(packageJson)
  if (permanent.length > 0) {
    ok = false
    lines.push({
      stream: 'stderr',
      text: `pnpm-audit: package.json pnpm.auditConfig.${permanent.join(' and ')} hides advisories with no expiry. Remove it and record a waiver in pnpm-audit-exceptions.yaml.`,
    })
  }

  const used = new Set()
  for (const advisory of Object.values(report.advisories)) {
    if (!failsHighGate(advisory?.severity)) continue
    const decision = decideAdvisory(advisory, exceptions, today, used)
    if (decision.waived) {
      lines.push({ stream: 'stdout', text: decision.waived })
      continue
    }
    ok = false
    lines.push({ stream: 'stderr', text: decision.failure })
  }

  for (const exception of exceptions) {
    if (used.has(exception)) continue
    lines.push({
      stream: 'stdout',
      text: `pnpm-audit: note: ${exception.id} ${exception.package}@${exception.version} no longer matches the audit report; delete it from pnpm-audit-exceptions.yaml`,
    })
  }

  if (ok) lines.push({ stream: 'stdout', text: 'pnpm-audit: ok' })
  return { ok, lines }
}

function permanentIgnoreKeys(packageJson) {
  const config = packageJson?.pnpm?.auditConfig
  if (config == null) return []
  if (typeof config !== 'object' || Array.isArray(config)) {
    throw new Error('package.json pnpm.auditConfig must be an object')
  }
  const present = []
  for (const key of ['ignoreGhsas', 'ignoreCves']) {
    if (!(key in config)) continue
    const value = config[key]
    if (!Array.isArray(value)) {
      throw new Error(`package.json pnpm.auditConfig.${key} must be a list`)
    }
    if (value.length > 0) present.push(key)
  }
  return present
}

function failsHighGate(severity) {
  return !BELOW_HIGH.has(severity)
}

function decideAdvisory(advisory, exceptions, today, used) {
  const label = advisoryLabel(advisory)
  const findings = advisory?.findings
  if (!Array.isArray(findings) || findings.length === 0) {
    return { failure: `pnpm-audit: failing ${label} — advisory has no findings to scope a waiver against` }
  }

  const applied = []
  for (const finding of findings) {
    const matches = exceptions.filter((exception) => scopeMatch(exception, advisory, finding))
    for (const exception of matches) used.add(exception)
    const active = matches.filter((exception) => today <= exception.expiredAt)
    if (active.length > 0) {
      applied.push(...active)
      continue
    }
    const expired = matches.find((exception) => today > exception.expiredAt)
    const expiredText = expired
      ? `waiver expired ${expired.expiredAt} (UTC); the high gate fails again while ${expired.package}@${expired.version} is still reported`
      : 'not covered by an active waiver'
    return { failure: `pnpm-audit: failing ${label} — ${expiredText}` }
  }

  const until = applied.map((exception) => exception.expiredAt).sort()[0]
  return {
    waived: `pnpm-audit: waived ${label} through ${until} UTC — ${applied[0].reason}`,
  }
}

function advisoryLabel(advisory) {
  const ghsa = advisory?.github_advisory_id || advisory?.url || 'unknown-advisory'
  const moduleName = advisory?.module_name || 'unknown-package'
  const versions = Array.isArray(advisory?.findings)
    ? [...new Set(advisory.findings.map((finding) => finding?.version).filter(Boolean))].join(', ')
    : ''
  const versionText = versions ? `@${versions}` : ''
  const severity = advisory?.severity || 'unknown'
  return `${ghsa} ${moduleName}${versionText} (${severity})`
}

function scopeMatch(exception, advisory, finding) {
  const ghsa = advisory?.github_advisory_id
  if (typeof ghsa !== 'string' || ghsa.toLowerCase() !== exception.id.toLowerCase()) return false
  if (advisory?.module_name !== exception.package) return false
  if (finding?.version !== exception.version) return false
  // pnpm 10.33's audit JSON often omits `dev`. Enforce the flag when the
  // report includes it. An omitted flag still matches, so a dev_only waiver
  // has to name the dev root in paths (for example `@angular/cli>`); a later
  // shared segment such as `make-fetch-happen>` would also cover production.
  if (exception.devOnly && finding?.dev === false) return false
  if (!Array.isArray(finding?.paths) || finding.paths.length === 0) return false
  return finding.paths.every((entry) =>
    typeof entry === 'string' && exception.paths.some((scope) => entry.includes(scope)),
  )
}

function readJson(file) {
  return JSON.parse(readFileSync(file, 'utf8'))
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

function failCli(message) {
  console.error(message)
  process.exit(1)
}

if (invokedAsCli()) {
  const args = process.argv.slice(2)
  const options = {}
  for (let index = 0; index < args.length; index += 2) {
    const flag = args[index]
    const value = args[index + 1]
    if (!flag?.startsWith('--') || value == null || value.startsWith('--')) {
      failCli('usage: pnpm-audit-gate.mjs --audit <report.json> --exceptions <file.yaml> --package-json <package.json>')
    }
    options[flag.slice(2)] = value
  }
  for (const flag of ['audit', 'exceptions', 'package-json']) {
    if (!options[flag]) {
      failCli(`pnpm-audit: missing --${flag}`)
    }
  }

  try {
    const result = evaluateAudit({
      report: readJson(options.audit),
      exceptions: parseExceptions(readFileSync(options.exceptions, 'utf8')),
      packageJson: readJson(options['package-json']),
      today: utcToday(),
    })
    for (const line of result.lines) {
      if (line.stream === 'stderr') console.error(line.text)
      else console.log(line.text)
    }
    process.exit(result.ok ? 0 : 1)
  } catch (error) {
    failCli(`pnpm-audit: ${error.message}`)
  }
}
