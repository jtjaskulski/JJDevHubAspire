#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$1" >&2
  exit 2
}

path_is_ignored() {
  local rest=$1
  local segment

  while [[ -n $rest ]]; do
    segment=${rest%%/*}
    case "$segment" in
      bin|obj|node_modules|dist) return 0 ;;
    esac
    if [[ $rest == */* ]]; then
      rest=${rest#*/}
    else
      rest=""
    fi
  done
  return 1
}

if [[ $# -ne 0 ]]; then
  usage "nieznany argument: $1"
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  usage "brak repozytorium gita"
fi

has_csharp=0
has_js=0

while IFS= read -r path; do
  [[ -z $path ]] && continue
  if path_is_ignored "$path"; then
    continue
  fi
  case "$path" in
    *.cs) has_csharp=1 ;;
    *.js|*.ts|*.tsx) has_js=1 ;;
  esac
done < <(git -c core.quotepath=off ls-files)

if [[ $has_csharp -eq 0 && $has_js -eq 0 ]]; then
  printf 'no material for codeql\n'
  exit 0
fi

if [[ $has_csharp -eq 1 ]]; then
  printf 'csharp\n'
fi

if [[ $has_js -eq 1 ]]; then
  printf 'javascript-typescript\n'
fi
