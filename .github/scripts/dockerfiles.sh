#!/usr/bin/env bash
set -euo pipefail

components_json=""
job=""

usage() {
  echo "$1" >&2
  exit 2
}

component_dockerfile() {
  case "$1" in
    contact) printf '%s' 'src/services/Contact/Dockerfile' ;;
    cv) printf '%s' 'src/services/Cv/Dockerfile' ;;
    gateway) printf '%s' 'src/gateway/Dockerfile' ;;
    identity) printf '%s' 'src/services/Identity/Dockerfile' ;;
    learning) printf '%s' 'src/services/Learning/Dockerfile' ;;
    mobile) printf '%s' 'src/clients/mobile/Dockerfile' ;;
    news) printf '%s' 'src/services/News/Dockerfile' ;;
    web) printf '%s' 'src/clients/web/Dockerfile' ;;
    *) return 1 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --components)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --components"
      fi
      components_json=$2
      shift 2
      ;;
    --job)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --job"
      fi
      job=$2
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ -z $components_json || -z $job ]]; then
  usage "brak --components albo --job"
fi

if ! command -v jq >/dev/null 2>&1; then
  usage "brak jq"
fi

if ! jq empty <<< "$components_json" >/dev/null 2>&1; then
  usage "zły JSON"
fi

names_json=$(jq -c '
  if type == "array" then .
  elif type == "object" and (.components | type == "array") then .components
  else empty
  end
' <<< "$components_json")

if [[ -z $names_json ]]; then
  usage "zły JSON komponentów"
fi

while IFS= read -r name; do
  [[ -z $name ]] && continue
  if ! component_dockerfile "$name" >/dev/null; then
    usage "nieznany komponent: ${name}"
  fi
done < <(jq -r '.[]' <<< "$names_json")

found=0
for name in contact cv gateway identity learning mobile news web; do
  if ! jq -e --arg name "$name" 'index($name) != null' <<< "$names_json" >/dev/null; then
    continue
  fi
  path=$(component_dockerfile "$name")
  if [[ -f $path ]]; then
    printf '%s %s\n' "$name" "$path"
    found=1
  fi
done

if [[ $found -eq 0 ]]; then
  printf 'no material for %s\n' "$job"
fi
