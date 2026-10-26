#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

export DOTNET_NOLOGO=1
dotnet restore JJDevHub.sln
dotnet package list --project JJDevHub.sln --vulnerable --include-transitive --format json \
  --source https://api.nuget.org/v3/index.json >/tmp/nuget-audit.json

# Nagłówek „has the following vulnerable packages” jest w raporcie tekstowym przy każdym
# severity, także Low i Moderate. Tu liczy się tylko pole JSON "severity".
if grep -Eq '"severity": "(Critical|High)"' /tmp/nuget-audit.json; then
  echo "nuget-audit: failing on Critical/High" >&2
  exit 1
fi

echo "nuget-audit: ok"
