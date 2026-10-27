#!/usr/bin/env bash
set -euo pipefail

sarif=""
seen_sarif=0

usage() {
  echo "$1" >&2
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sarif)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --sarif"
      fi
      sarif=$2
      seen_sarif=1
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

if [[ $seen_sarif -eq 0 || -z $sarif ]]; then
  usage "brak --sarif"
fi

if [[ ! -f $sarif ]]; then
  usage "brak pliku SARIF"
fi

if ! command -v jq >/dev/null 2>&1; then
  usage "brak jq"
fi

if ! jq empty "$sarif" >/dev/null 2>&1; then
  usage "zły JSON"
fi

count=$(jq -r --argjson threshold 7.0 '
  def security_tag($props):
    (($props // {}).tags // []) | any(. == "security");
  def severity_of($props):
    ($props // {})["security-severity"];
  def rule_for($run; $result):
    [ $run.tool.driver.rules[]?, $run.tool.extensions[]?.rules[]? ] as $rules
    | (
        [ $rules[]
          | select(.id != null and (.id == $result.ruleId or .id == $result.rule.id))
        ][0]
      ) as $by_id
    | (
        if ($result.ruleIndex | type) == "number" then
          $run.tool.driver.rules[$result.ruleIndex]
        elif ($result.rule.index | type) == "number" then
          $run.tool.driver.rules[$result.rule.index]
        else
          null
        end
      ) as $by_index
    | $by_id // $by_index // {};
  def score_of($raw):
    if $raw == null or $raw == "" then
      7.0
    elif ($raw | type) == "number" then
      $raw
    else
      ($raw | tostring | tonumber?) // 7.0
    end;
  [
    .runs[]? as $run
    | $run.results[]? as $result
    | ($result.properties // {}) as $result_props
    | (rule_for($run; $result).properties // {}) as $rule_props
    | select(security_tag($result_props) or security_tag($rule_props))
    | score_of(severity_of($result_props) // severity_of($rule_props)) as $score
    | select($score >= $threshold)
  ] | length
' "$sarif")

printf '%s\n' "$count"

if [[ $count -gt 0 ]]; then
  exit 1
fi
