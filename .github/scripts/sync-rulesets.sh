#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "skrypt nie przyjmuje argumentów" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "brak jq" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "brak gh" >&2; exit 1; }

if ! gh auth status; then
  exit 1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
cd -- "$repo_root"

if ! repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner); then
  echo "błąd API" >&2
  exit 1
fi

for name in develop release main; do
  path=".github/rulesets/${name}.json"
  if ! jq empty "$path"; then
    echo "błąd składni ${path}" >&2
    exit 1
  fi
  if ! ids=$(gh api --paginate "repos/${repo}/rulesets" --jq ".[] | select(.name==\"${name}\") | .id"); then
    echo "błąd API" >&2
    exit 1
  fi
  id=${ids%%$'\n'*}
  if [[ -z $id ]]; then
    if ! gh api --method POST "repos/${repo}/rulesets" --input "$path" >/dev/null; then
      echo "błąd API" >&2
      exit 1
    fi
  else
    if ! gh api --method PUT "repos/${repo}/rulesets/${id}" --input "$path" >/dev/null; then
      echo "błąd API" >&2
      exit 1
    fi
  fi
  echo "wgrano ${name}"
done

if ! gh api --method PATCH "repos/${repo}" --input - >/dev/null <<'EOF'
{"delete_branch_on_merge":true}
EOF
then
  echo "błąd API" >&2
  exit 1
fi

echo "delete_branch_on_merge: true"
