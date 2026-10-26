#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${JJDEVHUB_ENV_FILE:-/etc/jjdevhub/api.env}"
STATE_FILE="${JJDEVHUB_STATE_FILE:-/var/lib/jjdevhub/last-release-sha}"
TAGS_FILE="${JJDEVHUB_TAGS_FILE:-/var/lib/jjdevhub/last-release-tags}"
ALLOW_ROLLBACK="${JJDEVHUB_ALLOW_ROLLBACK:-0}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing env file: $ENV_FILE" >&2
  echo "copy infra/docker/.env.example and fill secrets; on the server use /etc/jjdevhub/api.env (chmod 600)" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

# One deploy at a time. Cron and the runner share this clone; the state check
# and the write at the end must not run in parallel.
LOCK_FILE="${JJDEVHUB_LOCK_FILE:-/var/lib/jjdevhub/deploy.lock}"
mkdir -p "$(dirname "$LOCK_FILE")"
exec 9>"$LOCK_FILE"
flock 9

# Optional argument: commit to deploy. Cron omits it and tracks the latest release tag.
target_sha="${1:-}"

git fetch origin main --tags

if [[ -n "$target_sha" ]]; then
  git cat-file -e "${target_sha}^{commit}"
  remote_sha="$(git rev-parse "${target_sha}^{commit}")"
else
  if ! described="$(git describe --tags --abbrev=0 --match '*-v*' origin/main 2>/dev/null)"; then
    echo "no release yet"
    exit 0
  fi
  remote_sha="$(git rev-parse "${described}^{commit}")"
fi

if [[ -f "$STATE_FILE" ]]; then
  saved_sha="$(tr -d '[:space:]' < "$STATE_FILE")"
  if [[ -n "$saved_sha" && "$saved_sha" == "$remote_sha" ]]; then
    echo "already deployed $remote_sha"
    exit 0
  fi
  # A later green run of an older commit must not roll back a newer deploy.
  if [[ "$ALLOW_ROLLBACK" != "1" ]] \
    && [[ -n "$saved_sha" ]] \
    && git cat-file -e "${saved_sha}^{commit}" 2>/dev/null \
    && git merge-base --is-ancestor "$remote_sha" "$saved_sha"; then
    echo "already deployed $saved_sha"
    exit 0
  fi
fi

git checkout --detach "$remote_sha"

docker compose --env-file "$ENV_FILE" -f "$REPO_ROOT/infra/docker/docker-compose.yml" up -d --build --wait --wait-timeout 180

# Jaeger is distroless, so Compose has no in-container healthcheck for it.
# --wait only treats that service as ready once the process is running.
# Require the published endpoints before recording the SHA.
wait_http() {
  local name="$1" url="$2"
  local deadline=$((SECONDS + 60))
  local status
  while (( SECONDS < deadline )); do
    status="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo missing)"
    case "$status" in
      exited|dead|restarting)
        echo "deploy: $name is $status" >&2
        docker logs --tail 80 "$name" >&2 || true
        exit 1
        ;;
    esac
    if curl -fsS -o /dev/null --max-time 2 "$url"; then
      echo "deploy: $name ready at $url"
      return 0
    fi
    sleep 2
  done
  echo "deploy: timeout waiting for $url" >&2
  docker logs --tail 80 "$name" >&2 || true
  exit 1
}

wait_http jjdevhub-api "http://127.0.0.1:5080/health"
wait_http jjdevhub-jaeger "http://127.0.0.1:16686/"

mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$TAGS_FILE")"
printf '%s\n' "$remote_sha" > "$STATE_FILE"
git tag --points-at "$remote_sha" --list '*-v*' | tee "$TAGS_FILE"
echo "deployed $remote_sha"
