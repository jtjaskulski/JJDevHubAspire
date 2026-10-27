#!/usr/bin/env bash
set -euo pipefail

job=""
pattern=""
seen_job=0
seen_pattern=0

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --job)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --job"
      fi
      job=$2
      seen_job=1
      shift 2
      ;;
    --pattern)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --pattern"
      fi
      pattern=$2
      seen_pattern=1
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ $seen_job -eq 0 || $seen_pattern -eq 0 || -z $job || -z $pattern ]]; then
  usage "brak --job albo --pattern"
fi

match=$(find . -path './.git' -prune -o -name "$pattern" -print -quit)
if [[ -z $match ]]; then
  printf 'no material for %s\n' "$job"
fi
