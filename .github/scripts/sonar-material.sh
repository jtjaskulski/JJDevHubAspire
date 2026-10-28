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

repo_root=$(git rev-parse --show-toplevel)
cd -- "$repo_root"

found=0
while IFS= read -r path; do
  [[ -z $path ]] && continue
  case "$path" in
    src/*.cs|src/*.js|src/*.ts|src/*.tsx) ;;
    *) continue ;;
  esac
  if path_is_ignored "$path"; then
    continue
  fi
  found=1
  break
done < <(git -c core.quotepath=off ls-files)

if [[ $found -eq 0 ]]; then
  printf 'no material for sonarqube\n'
else
  printf 'material\n'
fi
