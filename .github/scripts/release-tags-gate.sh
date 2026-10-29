#!/usr/bin/env bash
set -euo pipefail

base_ref=""
head_ref=""
head_name=""
title=""
paths=()
fixture=0

usage() {
  echo "$1" >&2
  exit 2
}

fail() {
  echo "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-ref)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --base-ref"
      fi
      base_ref=$2
      shift 2
      ;;
    --head-ref)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --head-ref"
      fi
      head_ref=$2
      shift 2
      ;;
    --head-name)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --head-name"
      fi
      head_name=$2
      shift 2
      ;;
    --title)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --title"
      fi
      title=$2
      shift 2
      ;;
    --paths)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --paths"
      fi
      paths+=("$2")
      fixture=1
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ $fixture -eq 0 && ( -z $base_ref || -z $head_ref ) ]]; then
  usage "brak --base-ref albo --head-ref"
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
cd -- "$repo_root"

command -v jq >/dev/null 2>&1 || fail "brak jq"
command -v git >/dev/null 2>&1 || fail "brak git"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "brak repozytorium gita"

component_names=(identity news learning cv contact gateway web mobile)
semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
title_re='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([a-z]+)\))?(!)?: (.*)$'
rp_re='^release-please--branches--develop--components--(identity|news|learning|cv|contact|gateway|web|mobile)$'
kernel_root=src/shared/JJDevHub.Shared.Kernel

declare -A head_version=()
declare -A base_version=()
declare -A head_present=()
declare -A json_changed=()
declare -A path_hit=()
declare -A explained=()

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

is_component() {
  local name=$1
  local item
  for item in "${component_names[@]}"; do
    if [[ $item == "$name" ]]; then
      return 0
    fi
  done
  return 1
}

scope_known() {
  if [[ $1 == shared || $1 == infra ]]; then
    return 0
  fi
  is_component "$1"
}

is_semver() {
  [[ $1 =~ $semver_re ]]
}

version_lt() {
  local left=$1
  local right=$2
  local left_major left_minor left_patch right_major right_minor right_patch
  IFS=. read -r left_major left_minor left_patch <<< "$left"
  IFS=. read -r right_major right_minor right_patch <<< "$right"
  if ((10#$left_major < 10#$right_major)); then
    return 0
  fi
  if ((10#$left_major > 10#$right_major)); then
    return 1
  fi
  if ((10#$left_minor < 10#$right_minor)); then
    return 0
  fi
  if ((10#$left_minor > 10#$right_minor)); then
    return 1
  fi
  if ((10#$left_patch < 10#$right_patch)); then
    return 0
  fi
  return 1
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

json_at_rev() {
  local rev=$1
  local file=$2
  if ! git cat-file -e "${rev}:${file}" 2>/dev/null; then
    return 1
  fi
  git show "${rev}:${file}"
}

text_at_rev() {
  local rev=$1
  local file=$2
  if ! git cat-file -e "${rev}:${file}" 2>/dev/null; then
    return 1
  fi
  git show "${rev}:${file}"
}

read_pair() {
  local name=$1
  local file="versions/${name}.json"
  local head_json=""
  local base_json=""
  head_present[$name]=0
  head_version[$name]=""
  base_version[$name]=""
  json_changed[$name]=0
  path_hit[$name]=0
  explained[$name]=0
  if [[ $fixture -eq 1 ]]; then
    if [[ -f $file ]]; then
      head_json=$(cat "$file")
      head_present[$name]=1
    fi
  elif head_json=$(json_at_rev "$head_ref" "$file"); then
    head_present[$name]=1
  else
    head_json=""
  fi
  if [[ -n $base_ref ]]; then
    if ! base_json=$(json_at_rev "$base_ref" "$file"); then
      base_json=""
    fi
  elif base_json=$(json_at_rev HEAD "$file"); then
    :
  else
    base_json=""
  fi
  if [[ ${head_present[$name]} -eq 1 ]]; then
    local field version
    if ! field=$(jq -er '.component' <<< "$head_json"); then
      fail "zły JSON ${file}"
    fi
    if [[ $field != "$name" ]]; then
      fail "component nie zgadza się z plikiem: ${file}"
    fi
    if ! version=$(jq -er '.version' <<< "$head_json"); then
      fail "zły JSON ${file}"
    fi
    if ! is_semver "$version"; then
      fail "wersja nie jest SemVer: ${name} ${version}"
    fi
    head_version[$name]=$version
  elif [[ -n $base_json ]]; then
    fail "brak ${file}"
  fi
  if [[ -n $base_json ]]; then
    local base_field
    if ! base_field=$(jq -er '.version' <<< "$base_json"); then
      fail "zły JSON ${file} na bazie"
    fi
    if ! is_semver "$base_field"; then
      fail "wersja nie jest SemVer: ${name} ${base_field}"
    fi
    base_version[$name]=$base_field
  fi
  if [[ ${head_present[$name]} -eq 0 ]]; then
    return
  fi
  if [[ -z ${base_version[$name]} ]]; then
    if [[ ${head_version[$name]} != 0.0.0 ]]; then
      json_changed[$name]=1
    fi
    return
  fi
  if [[ ${head_version[$name]} != "${base_version[$name]}" ]]; then
    json_changed[$name]=1
  fi
}

manifest_version() {
  local name=$1
  local root json value
  root=$(component_root "$name")
  if [[ $fixture -eq 1 ]]; then
    if [[ ! -f .release-please-manifest.json ]]; then
      printf '0.0.0'
      return
    fi
    json=$(cat .release-please-manifest.json)
  elif ! json=$(json_at_rev "$head_ref" .release-please-manifest.json); then
    printf '0.0.0'
    return
  fi
  if ! value=$(jq -er --arg path "$root" '.[$path] // "0.0.0"' <<< "$json"); then
    fail "zły manifest"
  fi
  if ! is_semver "$value"; then
    fail "manifest nie jest SemVer: ${name} ${value}"
  fi
  printf '%s' "$value"
}

version_txt_matches() {
  local name=$1
  local root file raw value
  root=$(component_root "$name")
  file="${root}/version.txt"
  if [[ $fixture -eq 1 ]]; then
    if [[ ! -f $file ]]; then
      return 0
    fi
    raw=$(cat "$file")
  elif ! raw=$(text_at_rev "$head_ref" "$file"); then
    return 0
  fi
  value=$(trim "$raw")
  if [[ $value != "${head_version[$name]}" ]]; then
    fail "version.txt różni się od JSON: ${name}"
  fi
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

is_dependent() {
  local name=$1
  local item
  for item in "${dependents[@]+"${dependents[@]}"}"; do
    if [[ $item == "$name" ]]; then
      return 0
    fi
  done
  return 1
}

tag_exists() {
  git rev-parse --verify -q "refs/tags/$1^{}" >/dev/null
}

name=""
for name in "${component_names[@]}"; do
  read_pair "$name"
  if [[ ${head_present[$name]} -eq 0 ]]; then
    continue
  fi
  if [[ -n ${base_version[$name]} ]] && version_lt "${head_version[$name]}" "${base_version[$name]}"; then
    fail "wersja maleje: ${name} ${base_version[$name]} -> ${head_version[$name]}"
  fi
  manifest=$(manifest_version "$name")
  if version_lt "${head_version[$name]}" "$manifest"; then
    fail "wersja maleje względem manifestu: ${name} ${head_version[$name]} < ${manifest}"
  fi
  version_txt_matches "$name"
done

declare -A tag_seen=()
for name in "${component_names[@]}"; do
  if [[ ${head_present[$name]} -eq 0 ]]; then
    continue
  fi
  tag="${name}-v${head_version[$name]}"
  if [[ -n ${tag_seen[$tag]:-} ]]; then
    fail "dwa komponenty dostały ten sam tag: ${tag}"
  fi
  tag_seen[$tag]=1
done

if [[ $fixture -eq 0 ]]; then
  if ! git rev-parse --verify -q "${base_ref}^{commit}" >/dev/null; then
    fail "brak ${base_ref}"
  fi
  if ! git rev-parse --verify -q "${head_ref}^{commit}" >/dev/null; then
    fail "brak ${head_ref}"
  fi
  mapfile -t diff_paths < <(git diff --name-only "${base_ref}...${head_ref}")
else
  diff_paths=("${paths[@]}")
fi

kernel=0
path=""
for path in "${diff_paths[@]+"${diff_paths[@]}"}"; do
  path=${path%$'\r'}
  path=${path#./}
  [[ -z $path ]] && continue
  if [[ $path == "$kernel_root" || $path == "$kernel_root"/* ]]; then
    kernel=1
  fi
  if hit=$(component_of_path "$path"); then
    path_hit[$hit]=1
  fi
done

mapfile -t dependents < <("${script_dir}/kernel-dependents.sh")

if [[ $kernel -eq 1 ]]; then
  for name in "${dependents[@]+"${dependents[@]}"}"; do
    if [[ ${json_changed[$name]} -ne 1 ]]; then
      fail "kernel bez podbicia: ${name}"
    fi
  done
fi

rp_component=""
if [[ -n $head_name && $head_name =~ $rp_re ]]; then
  rp_component=${BASH_REMATCH[1]}
fi

if [[ -n $rp_component && ${json_changed[$rp_component]} -eq 1 ]]; then
  if [[ -z $base_ref ]]; then
    fail "brak --base-ref"
  fi
  if ! expected=$("${script_dir}/prepare-versions.sh" --dry-run --component "$rp_component" --from-ref "$base_ref"); then
    exit 1
  fi
  if [[ $expected != "${head_version[$rp_component]}" ]]; then
    fail "wersja ${rp_component} ${head_version[$rp_component]} nie jest wyliczeniem ${expected}"
  fi
  explained[$rp_component]=1
fi

if [[ -n $title ]]; then
  if [[ $title == *$'\n'* || $title == *$'\r'* || ! $title =~ $title_re ]]; then
    fail "tytuł nie jest Conventional Commits"
  fi
  title_type=${BASH_REMATCH[1]}
  title_scope=${BASH_REMATCH[3]:-}
  if [[ -n $title_scope ]] && ! scope_known "$title_scope"; then
    fail "zakres spoza listy: ${title_scope}"
  fi
  if [[ ( $title_type == feat || $title_type == fix ) && -z $title_scope ]]; then
    fail "feat i fix wymagają zakresu"
  fi
  if [[ $title_scope == infra ]]; then
    for name in "${component_names[@]}"; do
      if [[ ${json_changed[$name]} -eq 1 ]]; then
        fail "infra nie zmienia wersji: ${name}"
      fi
    done
  elif [[ $title_scope == shared ]]; then
    for name in "${dependents[@]+"${dependents[@]}"}"; do
      if [[ ${json_changed[$name]} -ne 1 ]]; then
        fail "shared bez podbicia: ${name}"
      fi
    done
  elif [[ $title_type == feat || $title_type == fix ]]; then
    if [[ ${head_present[$title_scope]} -eq 0 || ${json_changed[$title_scope]} -ne 1 ]]; then
      fail "brak podbicia: ${title_scope}"
    fi
  fi
fi

for name in "${component_names[@]}"; do
  if [[ ${json_changed[$name]} -ne 1 ]]; then
    continue
  fi
  if [[ ${path_hit[$name]} -eq 1 || ${explained[$name]} -eq 1 ]]; then
    continue
  fi
  if [[ $kernel -eq 1 ]] && is_dependent "$name"; then
    continue
  fi
  fail "podbicie bez ścieżki: ${name}"
done

base_branch=${base_ref##*/}
if [[ $base_branch == release || $base_branch == main ]]; then
  for name in "${component_names[@]}"; do
    if [[ ${path_hit[$name]} -ne 1 || ${json_changed[$name]} -eq 1 ]]; then
      continue
    fi
    if [[ ${head_present[$name]} -eq 0 ]]; then
      fail "brak pliku wersji: ${name}"
    fi
    tag="${name}-v${head_version[$name]}"
    if ! tag_exists "$tag"; then
      fail "ścieżka bez podbicia i bez tagu: ${name}"
    fi
  done
fi

material=0
if [[ $kernel -eq 1 ]]; then
  material=1
fi
for name in "${component_names[@]}"; do
  if [[ ${path_hit[$name]} -eq 1 || ${json_changed[$name]} -eq 1 ]]; then
    material=1
  fi
done

if [[ $material -eq 0 ]]; then
  echo "no material for release-tags"
fi
