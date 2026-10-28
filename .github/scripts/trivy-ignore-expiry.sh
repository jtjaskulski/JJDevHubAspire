#!/usr/bin/env bash
set -euo pipefail

file=""

usage() {
  echo "$1" >&2
  exit 2
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --file"
      fi
      file=$2
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ -z $file ]]; then
  usage "brak --file"
fi

if [[ ! -f $file ]]; then
  usage "brak pliku"
fi

today=$(date +%Y-%m-%d)
status=0
last=""

while IFS= read -r raw || [[ -n $raw ]]; do
  line=$(trim "$raw")
  if [[ -z $line ]]; then
    continue
  fi

  if [[ $line =~ ^#\ expires:[[:space:]]*(.*)$ ]]; then
    stamp=$(trim "${BASH_REMATCH[1]}")
    if [[ -z $stamp ]]; then
      status=1
      last=bad
      continue
    fi
    if [[ ! $stamp =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      status=1
      last=bad
      continue
    fi
    normalized=$(date -d "$stamp" +%Y-%m-%d 2>/dev/null || true)
    if [[ $normalized != "$stamp" || $stamp < $today ]]; then
      status=1
      last=bad
      continue
    fi
    last=expires
    continue
  fi

  advisory=$line
  advisory=${advisory#- }
  advisory=$(trim "$advisory")
  if [[ $advisory == id:* ]]; then
    advisory=$(trim "${advisory#id:}")
  fi

  if [[ $advisory =~ ^(CVE|GHSA|NSWG|RUSTSEC|GO|DLA|TEMP|OSV)-[A-Za-z0-9._-]+$ ]]; then
    if [[ $last != expires ]]; then
      status=1
    fi
    last=other
    continue
  fi

  last=other
done < "$file"

exit "$status"
