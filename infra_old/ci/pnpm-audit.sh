#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WEB_DIR="$REPO_ROOT/src/Clients/web"
cd "$WEB_DIR"

corepack enable
pnpm install --frozen-lockfile

node --test "$REPO_ROOT/infra/ci/pnpm-audit-gate.test.mjs"

audit_json="$(mktemp)"
trap 'rm -f "$audit_json"' EXIT

set +e
pnpm audit --audit-level=high --json >"$audit_json"
audit_status=$?
set -e

if [[ "$audit_status" -ne 0 && "$audit_status" -ne 1 ]]; then
  echo "pnpm-audit: pnpm audit exited ${audit_status}" >&2
  cat "$audit_json" >&2
  exit "$audit_status"
fi

node "$REPO_ROOT/infra/ci/pnpm-audit-gate.mjs" \
  --audit "$audit_json" \
  --exceptions "$WEB_DIR/pnpm-audit-exceptions.yaml" \
  --package-json "$WEB_DIR/package.json"
