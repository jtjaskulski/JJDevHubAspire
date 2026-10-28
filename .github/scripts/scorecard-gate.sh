#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$1" >&2
  exit 2
}

if [[ $# -ne 0 ]]; then
  usage "skrypt czyta JSON ze stdin"
fi

if [[ -t 0 ]]; then
  usage "brak JSON"
fi

if ! command -v jq >/dev/null 2>&1; then
  usage "brak jq"
fi

payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
cat > "$payload"

if ! jq empty "$payload" >/dev/null 2>&1; then
  usage "zły JSON"
fi

required=(
  Dangerous-Workflow
  Token-Permissions
  Pinned-Dependencies
)

status=0
for name in "${required[@]}"; do
  score=$(jq -r --arg name "$name" '
    [ .checks[]? | select(.name == $name) | .score ] | first // empty
  ' "$payload")
  if [[ -z $score ]]; then
    printf 'brak sondy %s\n' "$name" >&2
    status=1
    continue
  fi
  if [[ $score == -1 || $score == -1.0 ]]; then
    printf '%s wynik -1\n' "$name" >&2
    status=1
    continue
  fi
  if awk -v score="$score" 'BEGIN { exit !(score + 0 < 10) }'; then
    printf '%s wynik %s\n' "$name" "$score" >&2
    status=1
  fi
done

others=$(jq -r '
  .checks[]?
  | select(
      .name != "Dangerous-Workflow"
      and .name != "Token-Permissions"
      and .name != "Pinned-Dependencies"
    )
  | "- \(.name): \(.score)"
' "$payload")

if [[ -n $others ]]; then
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    {
      echo "## Scorecard"
      printf '%s\n' "$others"
    } >> "$GITHUB_STEP_SUMMARY"
  else
    printf '%s\n' "$others"
  fi
fi

exit "$status"
