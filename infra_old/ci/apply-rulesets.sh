#!/usr/bin/env bash
set -euo pipefail

repo="${1:?usage: apply-rulesets.sh owner/name}"
root="$(git rev-parse --show-toplevel)"

api() {
  local body
  body="$(mktemp)"
  if ! gh api "$@" >"$body"; then
    cat "$body" >&2
    rm -f "$body"
    exit 1
  fi
  rm -f "$body"
}

api -X PATCH "repos/$repo" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -F allow_update_branch=true

api -X PUT "repos/$repo/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=true

for file in "$root"/.github/rulesets/*.json; do
  name="$(jq -r .name "$file")"
  name_lower="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')"
  # GitHub treats ruleset names as case-insensitive. The panel default is "Main".
  id="$(gh api "repos/$repo/rulesets" --paginate \
    --jq ".[] | select((.name | ascii_downcase) == \"$name_lower\") | .id" | head -n 1)"
  if [[ -n "$id" ]]; then
    api -X PUT "repos/$repo/rulesets/$id" --input "$file"
    echo "updated ruleset $name ($id)"
  else
    api -X POST "repos/$repo/rulesets" --input "$file"
    echo "created ruleset $name"
  fi
done

api -X PUT "repos/$repo/environments/production" \
  --input - <<'JSON'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON
gh api "repos/$repo/environments/production/deployment-branch-policies" --jq '.branch_policies[].name' \
  | grep -qx main \
  || api -X POST "repos/$repo/environments/production/deployment-branch-policies" \
       -f name=main -f type=branch
