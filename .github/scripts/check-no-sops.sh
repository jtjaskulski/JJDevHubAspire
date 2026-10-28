#!/usr/bin/env bash
set -euo pipefail

root=""

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --root"
      fi
      root=$2
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ -n $root && ! -d $root ]]; then
  usage "brak katalogu"
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)

is_sops_name() {
  local base
  base=$(basename -- "$1")
  base=$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]')
  case "$base" in
    *.sops.yml|*.sops.yaml|sops.yaml|.sops.yaml|*.enc.yml|*.enc.yaml)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_dotenv_name() {
  local base
  base=$(basename -- "$1")
  if [[ $base == .env.example ]]; then
    return 1
  fi
  case "$base" in
    .env|.env.*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

example_has_value() {
  local file=$1
  local line value
  while IFS= read -r line || [[ -n $line ]]; do
    [[ $line == *=* ]] || continue
    value=${line#*=}
    if [[ $value =~ [^[:space:]] ]]; then
      return 0
    fi
  done < "$file"
  return 1
}

status=0
while IFS= read -r path; do
  [[ -z $path ]] && continue
  if [[ -n $root ]]; then
    file=$path
  else
    file="${repo_root}/${path}"
  fi
  if is_sops_name "$path" || is_dotenv_name "$path"; then
    printf '%s\n' "$path" >&2
    status=1
    continue
  fi
  if [[ $(basename -- "$path") == .env.example ]] && example_has_value "$file"; then
    printf '%s\n' "$path" >&2
    status=1
  fi
done < <(
  if [[ -n $root ]]; then
    find "$root" \( -path '*/.git' -o -path '*/.git/*' \) -prune -o -type f -print
  else
    git -C "$repo_root" ls-files
  fi
)

exit "$status"
