#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C.UTF-8

title=""
seen_title=0

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      if [[ $# -lt 2 || "$2" == --* ]]; then
        usage "brak --title"
      fi
      title=$2
      seen_title=1
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ $seen_title -eq 0 ]]; then
  usage "brak --title"
fi

scope_allowed() {
  case "$1" in
    identity|news|learning|cv|contact|gateway|web|mobile|infra|shared)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

check_title() {
  local value=$1
  local pattern='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([a-z]+)\))?(!)?: (.*)$'
  local type
  local scope
  local description
  local first

  if [[ $value == *$'\n'* || $value == *$'\r'* ]]; then
    echo "tytuł ma więcej niż jedną linię" >&2
    return 1
  fi

  if [[ ${#value} -gt 120 ]]; then
    echo "tytuł dłuższy niż 120 znaków" >&2
    return 1
  fi

  if [[ ! $value =~ $pattern ]]; then
    echo "tytuł nie jest jedną linią Conventional Commits" >&2
    return 1
  fi

  type=${BASH_REMATCH[1]}
  scope=${BASH_REMATCH[3]:-}
  description=${BASH_REMATCH[5]:-}

  if [[ -n $scope ]] && ! scope_allowed "$scope"; then
    echo "zakres spoza listy: ${scope}" >&2
    return 1
  fi

  if [[ $type == feat || $type == fix ]] && [[ -z $scope ]]; then
    echo "feat i fix wymagają zakresu" >&2
    return 1
  fi

  if [[ $type == revert ]]; then
    check_title "$description"
    return
  fi

  if [[ ${#description} -lt 3 ]]; then
    echo "opis krótszy niż trzy znaki" >&2
    return 1
  fi

  if [[ $description == *. ]]; then
    echo "opis kończy się kropką" >&2
    return 1
  fi

  first=${description:0:1}
  if [[ ! $first =~ ^[[:lower:][:digit:]]$ ]]; then
    echo "opis nie zaczyna się małą literą ani cyfrą" >&2
    return 1
  fi
}

check_title "$title"
