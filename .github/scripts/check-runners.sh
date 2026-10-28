#!/usr/bin/env bash
set -euo pipefail

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

if [[ $# -ne 1 ]]; then
  usage "podaj katalog"
fi

target=$1
if [[ ! -d $target ]]; then
  usage "brak katalogu"
fi

status=0
while IFS= read -r file; do
  [[ -z $file ]] && continue
  if grep -q 'self-hosted' "$file"; then
    printf '%s: self-hosted\n' "$file" >&2
    status=1
  fi
  if grep -q 'pull_request_target' "$file"; then
    printf '%s: pull_request_target\n' "$file" >&2
    status=1
  fi
  line_no=0
  while IFS= read -r line || [[ -n $line ]]; do
    line_no=$((line_no + 1))
    [[ $line =~ runs-on:[[:space:]]*(.*)$ ]] || continue
    value=$(trim "${BASH_REMATCH[1]}")
    value=$(trim "${value%%#*}")
    if [[ $value == \"*\" ]]; then
      value=${value#\"}
      value=${value%\"}
    fi
    if [[ $value != ubuntu-latest ]]; then
      printf '%s:%s runs-on inne niż ubuntu-latest\n' "$file" "$line_no" >&2
      status=1
    fi
  done < "$file"
done < <(find "$target" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

exit "$status"
