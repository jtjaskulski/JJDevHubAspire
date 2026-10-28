#!/usr/bin/env bash
set -euo pipefail

nuget_json=""
npm_json=""
from_tree=0

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --nuget-json)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --nuget-json"
      fi
      nuget_json=$2
      shift 2
      ;;
    --npm-json)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --npm-json"
      fi
      npm_json=$2
      shift 2
      ;;
    --from-tree)
      from_tree=1
      shift
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

modes=0
if [[ -n $nuget_json ]]; then
  modes=$((modes + 1))
fi
if [[ -n $npm_json ]]; then
  modes=$((modes + 1))
fi
if [[ $from_tree -eq 1 ]]; then
  modes=$((modes + 1))
fi
if [[ $modes -ne 1 ]]; then
  usage "jeden tryb"
fi

if ! command -v jq >/dev/null 2>&1; then
  usage "brak jq"
fi

blocking_severity() {
  case "$1" in
    High|Critical|high|critical) return 0 ;;
    *) return 1 ;;
  esac
}

gate_nuget_file() {
  local file=$1
  local id severity status
  status=0
  if [[ ! -f $file ]]; then
    usage "brak pliku JSON"
  fi
  if ! jq empty "$file" >/dev/null 2>&1; then
    usage "zły JSON"
  fi
  while IFS=$'\t' read -r id severity; do
    [[ -z $id ]] && continue
    printf '%s %s\n' "$id" "$severity"
    if blocking_severity "$severity"; then
      status=1
    fi
  done < <(jq -r '
    .projects[]?.frameworks[]?
    | (.topLevelPackages[]?, .transitivePackages[]?)
    | . as $pkg
    | ($pkg.vulnerabilities[]?.severity) as $sev
    | select($sev != null and $sev != "")
    | "\($pkg.id)\t\($sev)"
  ' "$file")
  return "$status"
}

gate_npm_file() {
  local file=$1
  local name severity status
  status=0
  if [[ ! -f $file ]]; then
    usage "brak pliku JSON"
  fi
  if ! jq empty "$file" >/dev/null 2>&1; then
    usage "zły JSON"
  fi
  while IFS=$'\t' read -r name severity; do
    [[ -z $name ]] && continue
    printf '%s %s\n' "$name" "$severity"
    if blocking_severity "$severity"; then
      status=1
    fi
  done < <(jq -r '
    (.vulnerabilities // {}) | to_entries[]
    | "\(.key)\t\(.value.severity)"
  ' "$file")
  return "$status"
}

collect_tree() {
  find . \
    \( -path './.git' -o -path '*/bin' -o -path '*/obj' -o -path '*/node_modules' \) -prune \
    -o \( -name '*.csproj' -o -name 'package.json' \) -print
}

if [[ -n $nuget_json ]]; then
  gate_nuget_file "$nuget_json"
  exit $?
fi

if [[ -n $npm_json ]]; then
  gate_npm_file "$npm_json"
  exit $?
fi

csprojs=()
packages=()
while IFS= read -r path; do
  [[ -z $path ]] && continue
  case "$path" in
    *.csproj) csprojs+=("$path") ;;
    *) packages+=("$path") ;;
  esac
done < <(collect_tree)

if [[ ${#csprojs[@]} -eq 0 && ${#packages[@]} -eq 0 ]]; then
  printf 'no material for dependency-vulnerabilities\n'
  exit 0
fi

if [[ ${#csprojs[@]} -gt 0 && ! -f global.json ]]; then
  echo "brak global.json przy projekcie" >&2
  exit 1
fi

status=0
for package_json in "${packages[@]}"; do
  dir=$(dirname "$package_json")
  if [[ ! -f ${dir}/package-lock.json ]]; then
    echo "brak package-lock.json przy ${package_json}" >&2
    status=1
  fi
done

if [[ $status -ne 0 ]]; then
  exit 1
fi

for csproj in "${csprojs[@]}"; do
  json=$(mktemp)
  dotnet list "$csproj" package --vulnerable --include-transitive --format json > "$json"
  if ! gate_nuget_file "$json"; then
    status=1
  fi
  rm -f "$json"
done

for package_json in "${packages[@]}"; do
  dir=$(dirname "$package_json")
  json=$(mktemp)
  set +e
  (
    cd "$dir"
    npm audit --audit-level=high --json
  ) > "$json"
  npm_code=$?
  set -e
  if ! gate_npm_file "$json"; then
    status=1
  fi
  if [[ $npm_code -ne 0 ]]; then
    status=1
  fi
  rm -f "$json"
done

exit "$status"
