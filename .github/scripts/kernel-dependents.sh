#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "skrypt nie przyjmuje argumentów" >&2
  exit 2
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
cd -- "$repo_root"

component_names=(identity news learning cv contact gateway web mobile)

component_root() {
  case "$1" in
    identity) printf '%s' 'src/services/Identity' ;;
    news) printf '%s' 'src/services/News' ;;
    learning) printf '%s' 'src/services/Learning' ;;
    cv) printf '%s' 'src/services/Cv' ;;
    contact) printf '%s' 'src/services/Contact' ;;
    gateway) printf '%s' 'src/gateway' ;;
    web) printf '%s' 'src/clients/web' ;;
    mobile) printf '%s' 'src/clients/mobile' ;;
    *) return 1 ;;
  esac
}

component_of_path() {
  local path=$1
  local name root
  for name in "${component_names[@]}"; do
    root=$(component_root "$name")
    if [[ $path == "$root" || $path == "$root"/* ]]; then
      printf '%s' "$name"
      return 0
    fi
  done
  return 1
}

references_kernel() {
  local flat
  flat=$(tr '\n' ' ' < "$1" | tr -d '\r')
  grep -Eq 'ProjectReference[^<]*JJDevHub\.Shared\.Kernel' <<< "$flat"
}

found=' '
mark() {
  case "$found" in
    *" $1 "*) ;;
    *) found="${found}$1 " ;;
  esac
}

has() {
  case "$found" in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

while IFS= read -r csproj; do
  [[ -z $csproj ]] && continue
  if ! references_kernel "$csproj"; then
    continue
  fi
  relative=${csproj#./}
  if name=$(component_of_path "$relative"); then
    mark "$name"
  fi
done < <(find . \( -path './.git' -o -path '*/bin' -o -path '*/obj' -o -path '*/node_modules' \) -prune -o -name '*.csproj' -print)

for name in "${component_names[@]}"; do
  if has "$name"; then
    printf '%s\n' "$name"
  fi
done
