#!/usr/bin/env bash
set -euo pipefail

dry_run=0
component=""
from_version=""
from_ref=""
body=""
titles=()

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
    --dry-run)
      dry_run=1
      shift
      ;;
    --component)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --component"
      fi
      component=$2
      shift 2
      ;;
    --from)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --from"
      fi
      from_version=$2
      shift 2
      ;;
    --from-ref)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --from-ref"
      fi
      from_ref=$2
      shift 2
      ;;
    --title)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --title"
      fi
      titles+=("$2")
      shift 2
      ;;
    --body)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --body"
      fi
      body=$2
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
cd -- "$repo_root"

command -v jq >/dev/null 2>&1 || fail "brak jq"
command -v git >/dev/null 2>&1 || fail "brak git"

component_names=(identity news learning cv contact gateway web mobile)
semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
title_re='^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\(([a-z]+)\))?(!)?: (.*)$'

parsed_type=""
parsed_scope=""
parsed_bang=""

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

parse_title() {
  local value=$1
  parsed_type=""
  parsed_scope=""
  parsed_bang=""
  if [[ $value == *$'\n'* || $value == *$'\r'* ]]; then
    return 1
  fi
  if [[ ! $value =~ $title_re ]]; then
    return 1
  fi
  parsed_type=${BASH_REMATCH[1]}
  parsed_scope=${BASH_REMATCH[3]:-}
  parsed_bang=${BASH_REMATCH[4]:-}
}

kind_rank() {
  case "$1" in
    fix) printf '1' ;;
    feat) printf '2' ;;
    breaking) printf '3' ;;
    *) printf '0' ;;
  esac
}

higher_kind() {
  local left=$1
  local right=$2
  local left_rank right_rank
  left_rank=$(kind_rank "$left")
  right_rank=$(kind_rank "$right")
  if ((right_rank > left_rank)); then
    printf '%s' "$right"
    return
  fi
  printf '%s' "$left"
}

kind_for() {
  local note=$1
  if [[ $parsed_type != feat && $parsed_type != fix ]]; then
    printf 'none'
    return
  fi
  if [[ -z $parsed_scope ]]; then
    printf 'invalid-scope'
    return
  fi
  if [[ -n $parsed_bang || $note == *"BREAKING CHANGE:"* || $note == *"BREAKING-CHANGE:"* ]]; then
    printf 'breaking'
    return
  fi
  printf '%s' "$parsed_type"
}

bump_version() {
  local version=$1
  local kind=$2
  local major minor patch
  IFS=. read -r major minor patch <<< "$version"
  case "$kind" in
    fix)
      patch=$((10#$patch + 1))
      ;;
    feat)
      minor=$((10#$minor + 1))
      patch=0
      ;;
    breaking)
      if ((10#$major == 0)); then
        minor=$((10#$minor + 1))
        patch=0
      else
        major=$((10#$major + 1))
        minor=0
        patch=0
      fi
      ;;
    *)
      fail "nieznane podbicie: ${kind}"
      ;;
  esac
  printf '%s.%s.%s' "$major" "$minor" "$patch"
}

release_as_value=""

scan_release_as() {
  local note=$1
  local line value
  release_as_value=""
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ ! $line =~ ^Release-As:[[:space:]]*(.*)$ ]]; then
      continue
    fi
    value=${BASH_REMATCH[1]}
    value=${value#"${value%%[![:space:]]*}"}
    value=${value%"${value##*[![:space:]]}"}
    if ! is_semver "$value"; then
      fail "Release-As nie jest SemVer: ${value}"
    fi
    release_as_value=$value
  done <<< "$note"
}

manifest_version_at() {
  local rev=$1
  local root=$2
  local json
  if ! json=$(git show "${rev}:.release-please-manifest.json" 2>/dev/null); then
    printf '0.0.0'
    return
  fi
  jq -r --arg path "$root" '.[$path] // "0.0.0"' <<< "$json"
}

release_boundary() {
  local rev=$1
  local root=$2
  local start=$3
  local sha parent_version current
  while IFS= read -r sha; do
    [[ -z $sha ]] && continue
    current=$(manifest_version_at "$sha" "$root")
    if [[ $current != "$start" ]]; then
      continue
    fi
    if git rev-parse --verify -q "${sha}^" >/dev/null; then
      parent_version=$(manifest_version_at "${sha}^" "$root")
    else
      parent_version=""
    fi
    if [[ $parent_version != "$start" ]]; then
      printf '%s' "$sha"
      return 0
    fi
  done < <(git rev-list "$rev" -- .release-please-manifest.json)
  return 1
}

next_from_ref() {
  local name=$1
  local rev=$2
  local root start range best sha subject note kind found_as boundary
  root=$(component_root "$name")
  start=$(manifest_version_at "$rev" "$root")
  if ! is_semver "$start"; then
    fail "manifest nie jest SemVer: ${name} ${start}"
  fi
  range=$rev
  if [[ $start != 0.0.0 ]]; then
    if git rev-parse --verify -q "refs/tags/${name}-v${start}^{}" >/dev/null; then
      range="${name}-v${start}..${rev}"
    elif boundary=$(release_boundary "$rev" "$root" "$start"); then
      range="${boundary}..${rev}"
    fi
  fi
  best=none
  found_as=""
  while IFS= read -r sha; do
    [[ -z $sha ]] && continue
    subject=$(git log -1 --format='%s' "$sha")
    note=$(git log -1 --format='%b' "$sha")
    if ! parse_title "$subject"; then
      continue
    fi
    if [[ -n $parsed_scope ]] && ! scope_known "$parsed_scope"; then
      continue
    fi
    kind=$(kind_for "$note")
    if [[ $kind == invalid-scope || $kind == none ]]; then
      continue
    fi
    best=$(higher_kind "$best" "$kind")
    scan_release_as "$note"
    if [[ -n $release_as_value ]]; then
      found_as=$release_as_value
    fi
  done < <(git rev-list --reverse "$range" -- "$root")
  if [[ -n $found_as ]]; then
    printf '%s' "$found_as"
    return
  fi
  if [[ $best == none ]]; then
    printf '%s' "$start"
    return
  fi
  bump_version "$start" "$best"
}

read_file_version() {
  local name=$1
  local file="versions/${name}.json"
  local value
  if [[ ! -f $file ]]; then
    fail "brak ${file}"
  fi
  if ! value=$(jq -er '.version' "$file"); then
    fail "zły JSON ${file}"
  fi
  if ! is_semver "$value"; then
    fail "wersja nie jest SemVer: ${name} ${value}"
  fi
  printf '%s' "$value"
}

write_json() {
  local name=$1
  local version=$2
  local file="versions/${name}.json"
  local tmp
  tmp=$(mktemp "${file}.tmp.XXXXXX")
  if ! jq --arg version "$version" '.version = $version' "$file" > "$tmp"; then
    rm -f "$tmp"
    fail "zły JSON ${file}"
  fi
  mv "$tmp" "$file"
}

write_manifest() {
  local root=$1
  local version=$2
  local tmp
  tmp=$(mktemp ".release-please-manifest.json.tmp.XXXXXX")
  if ! jq --arg path "$root" --arg version "$version" '.[$path] = $version' .release-please-manifest.json > "$tmp"; then
    rm -f "$tmp"
    fail "zły manifest"
  fi
  mv "$tmp" .release-please-manifest.json
}

write_version_txt() {
  local root=$1
  local version=$2
  local file="${root}/version.txt"
  if [[ -f $file ]]; then
    printf '%s\n' "$version" > "$file"
  fi
}

if [[ -n $component ]] && ! is_component "$component"; then
  fail "nieznany komponent: ${component}"
fi

if [[ -n $from_version ]] && ! is_semver "$from_version"; then
  fail "wersja nie jest SemVer: ${from_version}"
fi

if [[ -n $from_ref && ${#titles[@]} -gt 0 ]]; then
  usage "--from-ref nie łączy się z --title"
fi

if [[ -n $from_ref ]]; then
  if [[ $dry_run -eq 0 || -z $component ]]; then
    usage "--from-ref wymaga --dry-run i --component"
  fi
  if ! git rev-parse --verify -q "${from_ref}^{commit}" >/dev/null; then
    fail "brak ${from_ref}"
  fi
  if ! next=$(next_from_ref "$component" "$from_ref"); then
    exit 1
  fi
  printf '%s\n' "$next"
  exit 0
fi

if [[ ${#titles[@]} -eq 0 ]]; then
  usage "brak --title"
fi

scope=""
best=none
chosen_release=""
title=""
for title in "${titles[@]}"; do
  if ! parse_title "$title"; then
    fail "tytuł nie jest Conventional Commits"
  fi
  if [[ -n $parsed_scope ]] && ! scope_known "$parsed_scope"; then
    fail "zakres spoza listy: ${parsed_scope}"
  fi
  kind=$(kind_for "$body")
  if [[ $kind == invalid-scope ]]; then
    fail "feat i fix wymagają zakresu"
  fi
  if [[ -z $scope ]]; then
    scope=$parsed_scope
  elif [[ $parsed_scope != "$scope" ]]; then
    fail "różne zakresy"
  fi
  best=$(higher_kind "$best" "$kind")
done

scan_release_as "$body"
if [[ -n $release_as_value ]]; then
  chosen_release=$release_as_value
fi

if [[ $scope == infra ]]; then
  if [[ -n $chosen_release ]]; then
    fail "infra nie zmienia wersji"
  fi
  exit 0
fi

if [[ $scope == shared && -n $chosen_release ]]; then
  fail "Release-As przy zakresie shared wymaga osobnego komponentu"
fi

targets=()
if [[ $scope == shared ]]; then
  mapfile -t targets < <("${script_dir}/kernel-dependents.sh")
  if [[ -n $component ]]; then
    found=0
    item=""
    for item in "${targets[@]+"${targets[@]}"}"; do
      if [[ $item == "$component" ]]; then
        found=1
      fi
    done
    if [[ $found -eq 0 ]]; then
      fail "komponent poza grafem kernela: ${component}"
    fi
    targets=("$component")
  fi
elif [[ -n $scope ]]; then
  if [[ -n $component && $component != "$scope" ]]; then
    fail "zakres nie pasuje do komponentu: ${scope}"
  fi
  targets=("$scope")
elif [[ -n $component ]]; then
  targets=("$component")
else
  usage "brak komponentu"
fi

if [[ ${#targets[@]} -eq 0 ]]; then
  exit 0
fi

lines=()
name=""
for name in "${targets[@]}"; do
  if [[ -n $from_version ]]; then
    start=$from_version
  else
    start=$(read_file_version "$name")
  fi
  if [[ -n $chosen_release ]]; then
    next=$chosen_release
  elif [[ $best == none ]]; then
    next=$start
  else
    next=$(bump_version "$start" "$best")
  fi
  if ! is_semver "$next"; then
    fail "wersja nie jest SemVer: ${next}"
  fi
  if [[ $dry_run -eq 0 && $next != "$start" ]]; then
    write_json "$name" "$next"
    write_version_txt "$(component_root "$name")" "$next"
    if [[ $scope == shared ]]; then
      write_manifest "$(component_root "$name")" "$next"
    fi
  fi
  lines+=("$next")
done

if [[ $dry_run -eq 0 ]]; then
  exit 0
fi

if [[ ${#targets[@]} -eq 1 ]]; then
  printf '%s\n' "${lines[0]}"
  exit 0
fi

index=0
for name in "${targets[@]}"; do
  printf '%s %s\n' "$name" "${lines[$index]}"
  index=$((index + 1))
done
