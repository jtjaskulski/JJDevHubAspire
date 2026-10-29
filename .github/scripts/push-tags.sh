#!/usr/bin/env bash
set -euo pipefail

dry_run=0

usage() {
  echo "$1" >&2
  exit 2
}

fail() {
  echo "$1" >&2
  exit 1
}

if [[ $# -gt 1 ]]; then
  usage "za dużo argumentów"
fi

if [[ $# -eq 1 ]]; then
  if [[ $1 != --dry-run ]]; then
    usage "nieznany argument: $1"
  fi
  dry_run=1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
cd -- "$repo_root"

command -v jq >/dev/null 2>&1 || fail "brak jq"
command -v git >/dev/null 2>&1 || fail "brak git"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "brak repozytorium gita"

component_names=(identity news learning cv contact gateway web mobile)
semver_re='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
tag_re='^(identity|news|learning|cv|contact|gateway|web|mobile)-v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

created=()
name=""
for name in "${component_names[@]}"; do
  file="versions/${name}.json"
  in_head=0
  if git cat-file -e "HEAD:${file}" 2>/dev/null; then
    in_head=1
    json=$(git show "HEAD:${file}")
  elif [[ -f $file ]]; then
    json=$(cat "$file")
  else
    fail "brak ${file}"
  fi
  if ! field=$(jq -er '.component' <<< "$json"); then
    fail "zły JSON ${file}"
  fi
  if [[ $field != "$name" ]]; then
    fail "component nie zgadza się z plikiem: ${file}"
  fi
  if ! version=$(jq -er '.version' <<< "$json"); then
    fail "zły JSON ${file}"
  fi
  if [[ ! $version =~ $semver_re ]]; then
    fail "wersja nie jest SemVer: ${name} ${version}"
  fi
  if [[ $version == 0.0.0 ]]; then
    continue
  fi
  if [[ $in_head -eq 0 ]]; then
    fail "wersja ${name} nie jest w commicie"
  fi
  tag="${name}-v${version}"
  if [[ ! $tag =~ $tag_re ]]; then
    fail "zły tag: ${tag}"
  fi
  if git rev-parse --verify -q "refs/tags/${tag}^{}" >/dev/null; then
    continue
  fi
  changed=0
  if git rev-parse --verify -q 'HEAD^' >/dev/null; then
    if ! git diff --quiet 'HEAD^' HEAD -- "$file"; then
      changed=1
    fi
  else
    changed=1
  fi
  if [[ $changed -eq 0 ]]; then
    continue
  fi
  if [[ $dry_run -eq 0 ]]; then
    git tag "$tag"
  fi
  created+=("$tag")
done

if [[ ${#created[@]} -eq 0 ]]; then
  exit 0
fi

printf '%s\n' "${created[@]}"
if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
  {
    echo "## Tagi"
    printf '%s\n' "${created[@]}"
  } >> "$GITHUB_STEP_SUMMARY"
fi

if [[ $dry_run -eq 0 ]]; then
  git push origin "${created[@]}"
fi
