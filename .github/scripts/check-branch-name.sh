#!/usr/bin/env bash
set -euo pipefail

head=""
base=""
skip_ancestry=0
seen_head=0
seen_base=0

fail() {
  echo "$1" >&2
  exit 1
}

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --head)
      if [[ $# -lt 2 || "$2" == --* ]]; then
        usage "brak --head"
      fi
      head=$2
      seen_head=1
      shift 2
      ;;
    --base)
      if [[ $# -lt 2 || "$2" == --* ]]; then
        usage "brak --base"
      fi
      base=$2
      seen_base=1
      shift 2
      ;;
    --skip-ancestry)
      skip_ancestry=1
      shift
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ $seen_head -eq 0 || $seen_base -eq 0 || -z $head || -z $base ]]; then
  usage "brak --head albo --base"
fi

check_ancestry() {
  local head_name=$1
  local head_ref
  local merge_base

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "brak repozytorium gita przy sprawdzaniu przodków"
  fi

  if git rev-parse --verify --quiet "refs/remotes/origin/${head_name}" >/dev/null; then
    head_ref="refs/remotes/origin/${head_name}"
  elif git rev-parse --verify --quiet "refs/heads/${head_name}" >/dev/null; then
    head_ref="refs/heads/${head_name}"
  else
    fail "brak głowy w gicie: ${head_name}"
  fi

  if ! git rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
    fail "brak origin/main"
  fi

  if ! git rev-parse --verify --quiet refs/remotes/origin/develop >/dev/null; then
    fail "brak origin/develop"
  fi

  if ! merge_base=$(git merge-base "$head_ref" refs/remotes/origin/main); then
    fail "merge-base głowy z origin/main nie istnieje"
  fi

  if ! git merge-base --is-ancestor "$merge_base" refs/remotes/origin/develop; then
    fail "merge-base głowy z origin/main nie jest przodkiem origin/develop"
  fi
}

prefix='^(feature|fix|docs|chore|ci|refactor|test)/[a-z0-9]+(-[a-z0-9]+)*$'

if [[ $base != develop && $base != release && $base != main ]]; then
  fail "cel spoza develop, release i main: ${base}"
fi

if [[ $head =~ $prefix ]]; then
  if [[ $base != develop ]]; then
    fail "gałąź robocza wchodzi tylko na develop: ${head} → ${base}"
  fi
  if [[ $skip_ancestry -eq 0 ]]; then
    check_ancestry "$head"
  fi
  exit 0
fi

if [[ $head == develop ]]; then
  if [[ $base != release ]]; then
    fail "develop wchodzi tylko na release"
  fi
  exit 0
fi

if [[ $head == release ]]; then
  if [[ $base != main ]]; then
    fail "release wchodzi tylko na main"
  fi
  exit 0
fi

fail "głowa nie jest gałęzią roboczą ani promocją: ${head}"
