#!/usr/bin/env bash
set -euo pipefail

from_git=0
mode=json

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
    --from-git)
      from_git=1
      shift
      ;;
    --list-roots)
      if [[ $mode != json ]]; then
        usage "jeden tryb listy"
      fi
      mode=roots
      shift
      ;;
    --list-projects)
      if [[ $mode != json ]]; then
        usage "jeden tryb listy"
      fi
      mode=projects
      shift
      ;;
    --list-packages)
      if [[ $mode != json ]]; then
        usage "jeden tryb listy"
      fi
      mode=packages
      shift
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

component_root() {
  case "$1" in
    contact) printf '%s' 'src/services/Contact' ;;
    cv) printf '%s' 'src/services/Cv' ;;
    gateway) printf '%s' 'src/gateway' ;;
    identity) printf '%s' 'src/services/Identity' ;;
    learning) printf '%s' 'src/services/Learning' ;;
    mobile) printf '%s' 'src/clients/mobile' ;;
    news) printf '%s' 'src/services/News' ;;
    web) printf '%s' 'src/clients/web' ;;
    *) return 1 ;;
  esac
}

component_names=(contact cv gateway identity learning mobile news web)
components=' '
kernel=false
repo_wide=0

add_component() {
  local name=$1
  case "$components" in
    *" ${name} "*) ;;
    *) components="${components}${name} " ;;
  esac
}

has_component() {
  case "$components" in
    *" $1 "*) return 0 ;;
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

is_repo_wide_path() {
  local path=$1
  [[ $path == *.sln || $path == Directory.Packages.props || $path == global.json ]]
}

is_kernel_path() {
  local path=$1
  local root=src/shared/JJDevHub.Shared.Kernel
  [[ $path == "$root" || $path == "$root"/* ]]
}

component_has_project() {
  local root
  root=$(component_root "$1")
  [[ -d $root ]] || return 1
  local found
  found=$(find "$root" \( -path '*/bin' -o -path '*/obj' \) -prune -o -name '*.csproj' -print -quit)
  [[ -n $found ]]
}

references_kernel() {
  local flat
  flat=$(tr '\n' ' ' < "$1")
  grep -Eq 'ProjectReference[^<]*JJDevHub\.Shared\.Kernel' <<< "$flat"
}

add_kernel_dependents() {
  local csproj relative name
  while IFS= read -r csproj; do
    [[ -z $csproj ]] && continue
    if ! references_kernel "$csproj"; then
      continue
    fi
    relative=${csproj#./}
    if name=$(component_of_path "$relative"); then
      add_component "$name"
    fi
  done < <(find . \( -path './.git' -o -path '*/bin' -o -path '*/obj' -o -path '*/node_modules' \) -prune -o -name '*.csproj' -print)
}

classify() {
  local path=$1
  local name
  path=${path%$'\r'}
  path=${path#./}
  [[ -z $path ]] && return 0
  if is_repo_wide_path "$path"; then
    repo_wide=1
    return 0
  fi
  if is_kernel_path "$path"; then
    kernel=true
    return 0
  fi
  if name=$(component_of_path "$path"); then
    add_component "$name"
  fi
}

if [[ $from_git -eq 1 ]]; then
  if [[ -z ${BASE_REF:-} || $BASE_REF == -* ]]; then
    fail "brak BASE_REF"
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    fail "brak repozytorium gita"
  fi
  if ! git rev-parse --verify --quiet "refs/remotes/origin/${BASE_REF}" >/dev/null; then
    fail "brak origin/${BASE_REF}"
  fi
  diff_output=$(git diff --name-only "origin/${BASE_REF}...HEAD")
  while IFS= read -r line; do
    classify "$line"
  done <<< "$diff_output"
else
  while IFS= read -r line; do
    classify "$line"
  done
fi

if [[ $kernel == true ]]; then
  add_kernel_dependents
fi

if [[ $repo_wide -eq 1 ]]; then
  for name in "${component_names[@]}"; do
    if component_has_project "$name"; then
      add_component "$name"
    fi
  done
fi

case "$mode" in
  roots)
    for name in "${component_names[@]}"; do
      if has_component "$name"; then
        component_root "$name"
        printf '\n'
      fi
    done
    ;;
  projects)
    for name in "${component_names[@]}"; do
      if ! has_component "$name"; then
        continue
      fi
      root=$(component_root "$name")
      [[ -d $root ]] || continue
      find "$root" \( -path '*/bin' -o -path '*/obj' -o -path '*/node_modules' \) -prune -o -name '*.csproj' -print
    done
    ;;
  packages)
    for name in "${component_names[@]}"; do
      if ! has_component "$name"; then
        continue
      fi
      root=$(component_root "$name")
      [[ -d $root ]] || continue
      find "$root" \( -path '*/node_modules' -o -path '*/bin' -o -path '*/obj' \) -prune -o -name 'package.json' -print
    done
    ;;
  json)
    json='{"components":['
    separator=''
    for name in "${component_names[@]}"; do
      if has_component "$name"; then
        json="${json}${separator}\"${name}\""
        separator=','
      fi
    done
    json="${json}],\"kernel\":${kernel}}"
    printf '%s\n' "$json"
    ;;
esac
