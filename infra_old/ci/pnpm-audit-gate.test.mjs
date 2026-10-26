import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

import { evaluateAudit, parseExceptions } from './pnpm-audit-gate.mjs'

const REASON = 'Shared-cache max-stale leak; http-cache-semantics@4.2.0 is waived only on paths through @angular/cli, not on other make-fetch-happen consumers or the browser bundle.'

const waiver = {
  id: 'GHSA-ch52-4w7c-c8xp',
  package: 'http-cache-semantics',
  version: '4.2.0',
  devOnly: true,
  paths: ['@angular/cli>'],
  expiredAt: '2026-12-31',
  reason: REASON,
}

const cleanPackage = { pnpm: { overrides: { piscina: '5.3.2' } } }

function finding(overrides = {}) {
  return {
    version: '4.2.0',
    dev: true,
    paths: ['.>@angular/cli>pacote>make-fetch-happen>http-cache-semantics'],
    ...overrides,
  }
}

function advisory(overrides = {}) {
  return {
    github_advisory_id: 'GHSA-ch52-4w7c-c8xp',
    module_name: 'http-cache-semantics',
    severity: 'high',
    title: 'max-stale cache leak',
    findings: [finding()],
    ...overrides,
  }
}

function evaluate(overrides = {}) {
  return evaluateAudit({
    report: { advisories: { '1': advisory() } },
    exceptions: [waiver],
    packageJson: cleanPackage,
    today: '2026-10-06',
    ...overrides,
  })
}

test('active scoped waiver suppresses only the matching dev path', () => {
  const result = evaluate()
  assert.equal(result.ok, true)
  assert.match(result.lines.at(-1).text, /pnpm-audit: ok/)
  assert.match(result.lines[0].text, /waived GHSA-ch52-4w7c-c8xp/)
  assert.match(result.lines[0].text, /through 2026-12-31 UTC/)
})

test('waiver still applies on the expiry date', () => {
  const result = evaluate({ today: '2026-12-31' })
  assert.equal(result.ok, true)
})

test('expired waiver fails the high gate again', () => {
  const result = evaluate({ today: '2027-01-01' })
  assert.equal(result.ok, false)
  assert.match(result.lines[0].text, /waiver expired 2026-12-31/)
  assert.doesNotMatch(result.lines.map((line) => line.text).join('\n'), /pnpm-audit: ok/)
})

test('matching Angular CLI path with dev omitted is waived', () => {
  const result = evaluate({
    report: { advisories: { '1': advisory({ findings: [finding({ dev: undefined })] }) } },
  })
  assert.equal(result.ok, true)
})

test('omitted dev on a make-fetch-happen path outside Angular CLI is not waived', () => {
  const result = evaluate({
    report: {
      advisories: {
        '1': advisory({
          findings: [finding({ dev: undefined, paths: ['app>make-fetch-happen>http-cache-semantics'] })],
        }),
      },
    },
  })
  assert.equal(result.ok, false)
  assert.match(result.lines[0].text, /not covered by an active waiver/)
})

test('explicit production finding is not waived', () => {
  const result = evaluate({
    report: {
      advisories: {
        '1': advisory({
          findings: [finding({ dev: false })],
        }),
      },
    },
  })
  assert.equal(result.ok, false)
  assert.match(result.lines[0].text, /not covered by an active waiver/)
})

test('same advisory on a production path still fails', () => {
  const result = evaluate({
    report: { advisories: { '1': advisory({ findings: [finding({ dev: false, paths: ['app>http-cache-semantics'] })] }) } },
  })
  assert.equal(result.ok, false)
  assert.match(result.lines[0].text, /not covered by an active waiver/)
})

test('another installed version is not covered', () => {
  const result = evaluate({
    report: {
      advisories: {
        '1': advisory({
          findings: [finding({ version: '4.1.0', paths: ['cli>make-fetch-happen>http-cache-semantics'] })],
        }),
      },
    },
  })
  assert.equal(result.ok, false)
})

test('a second high advisory still fails', () => {
  const result = evaluate({
    report: {
      advisories: {
        '1': advisory(),
        '2': advisory({
          github_advisory_id: 'GHSA-xxxx-yyyy-zzzz',
          module_name: 'left-pad',
          findings: [finding({ version: '1.0.0', paths: ['app>left-pad'] })],
        }),
      },
    },
  })
  assert.equal(result.ok, false)
  assert.match(result.lines.map((line) => line.text).join('\n'), /GHSA-xxxx-yyyy-zzzz/)
})

test('ignoreGhsas fails even when the audit report was already stripped', () => {
  const result = evaluate({
    report: { advisories: {} },
    packageJson: { pnpm: { auditConfig: { ignoreGhsas: ['GHSA-ch52-4w7c-c8xp'] } } },
  })
  assert.equal(result.ok, false)
  assert.match(result.lines[0].text, /ignoreGhsas hides advisories with no expiry/)
})

test('moderate advisories stay below the high gate', () => {
  const result = evaluate({
    report: { advisories: { '1': advisory({ severity: 'moderate' }) } },
    exceptions: [],
  })
  assert.equal(result.ok, true)
})

test('parser rejects a waiver with no expiry', () => {
  assert.throws(
    () => parseExceptions(`
advisories:
  - id: GHSA-ch52-4w7c-c8xp
    package: http-cache-semantics
    version: 4.2.0
    dev_only: true
    paths:
      - "@angular/cli>"
    reason: ${REASON}
`),
    /missing expired_at/,
  )
})

test('committed exceptions list has no waivers', () => {
  const text = readFileSync(new URL('../../src/Clients/web/pnpm-audit-exceptions.yaml', import.meta.url), 'utf8')
  assert.deepEqual(parseExceptions(text), [])
})
