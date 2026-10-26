#!/usr/bin/env bash
# Boots the Compose Jaeger and Grafana services with the repo configs and
# fails if either process exits or Grafana provisioning reports an error.
# Does not start db, api, or prometheus. Refuses to run when the real
# containers already exist, so a local stack is left alone.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

COMPOSE_FILE="$REPO_ROOT/infra/docker/docker-compose.yml"
PROJECT="jjdevhub-obs-smoke"
JAEGER_NAME="jjdevhub-jaeger"
GRAFANA_NAME="jjdevhub-grafana"

if docker container inspect "$JAEGER_NAME" >/dev/null 2>&1 \
  || docker container inspect "$GRAFANA_NAME" >/dev/null 2>&1; then
  echo "observability-smoke: $JAEGER_NAME or $GRAFANA_NAME already exists; not touching a running stack" >&2
  exit 1
fi

python3 - "$REPO_ROOT/infra/grafana/dashboards" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = sorted(root.glob("*.json"))
if not files:
    sys.exit(f"observability-smoke: no dashboard json in {root}")
for path in files:
    doc = json.loads(path.read_text())
    uid = doc.get("uid")
    title = doc.get("title")
    panels = doc.get("panels")
    if not isinstance(uid, str) or not uid:
        sys.exit(f"observability-smoke: {path.name} missing uid")
    if not isinstance(title, str) or not title:
        sys.exit(f"observability-smoke: {path.name} missing title")
    if not isinstance(panels, list) or not panels:
        sys.exit(f"observability-smoke: {path.name} missing panels")
PY

env_file="$(mktemp)"
started=0
cleanup() {
  local rc=$?
  if [[ "$started" == 1 ]]; then
    docker compose -p "$PROJECT" --env-file "$env_file" -f "$COMPOSE_FILE" \
      down -v --remove-orphans >/dev/null 2>&1 || true
  fi
  rm -f "$env_file"
  exit "$rc"
}
trap cleanup EXIT

# Shell values win over the env file. Set both so a parent empty
# GRAFANA_ADMIN_PASSWORD does not fail Compose interpolation.
export POSTGRES_USER=ci
export POSTGRES_PASSWORD=ci
export POSTGRES_DB=ci
export JWT_KEY=ci-smoke-jwt-key-at-least-32-characters-long
export GRAFANA_ADMIN_USER=admin
export GRAFANA_ADMIN_PASSWORD=ci-smoke-not-a-secret
cat >"$env_file" <<EOF
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
JWT_KEY=$JWT_KEY
GRAFANA_ADMIN_USER=$GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWORD
EOF

compose() {
  docker compose -p "$PROJECT" --env-file "$env_file" -f "$COMPOSE_FILE" "$@"
}

fail_logs() {
  local name="$1"
  echo "observability-smoke: $name failed" >&2
  docker logs "$name" >&2 || true
  exit 1
}

wait_http() {
  local name="$1" url="$2"
  local deadline=$((SECONDS + 90))
  local status
  while (( SECONDS < deadline )); do
    status="$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || echo missing)"
    case "$status" in
      exited|dead|restarting)
        echo "observability-smoke: $name is $status" >&2
        fail_logs "$name"
        ;;
    esac
    if curl -fsS -o /dev/null --max-time 2 "$url"; then
      return 0
    fi
    sleep 1
  done
  echo "observability-smoke: timeout waiting for $url" >&2
  fail_logs "$name"
}

started=1
compose up -d --no-deps jaeger grafana

wait_http "$JAEGER_NAME" "http://127.0.0.1:16686/"
wait_http "$GRAFANA_NAME" "http://127.0.0.1:3000/api/health"

logs=""
deadline=$((SECONDS + 30))
while (( SECONDS < deadline )); do
  status="$(docker inspect -f '{{.State.Status}}' "$GRAFANA_NAME" 2>/dev/null || echo missing)"
  case "$status" in
    exited|dead|restarting)
      echo "observability-smoke: $GRAFANA_NAME is $status" >&2
      fail_logs "$GRAFANA_NAME"
      ;;
  esac
  logs="$(docker logs "$GRAFANA_NAME" 2>&1 || true)"
  if grep -q 'finished to provision dashboards' <<<"$logs" \
    && grep -q 'uid=prometheus' <<<"$logs" \
    && grep -q 'uid=jaeger' <<<"$logs"; then
    break
  fi
  sleep 1
done

if ! grep -q 'finished to provision dashboards' <<<"$logs" \
  || ! grep -q 'uid=prometheus' <<<"$logs" \
  || ! grep -q 'uid=jaeger' <<<"$logs"; then
  echo "observability-smoke: Grafana provisioning did not finish" >&2
  printf '%s\n' "$logs" >&2
  exit 1
fi

# Grafana 13 logs level=error when provisioning/plugins and provisioning/alerting
# are absent. This stack does not ship those directories. Only datasource and
# dashboard provisioning errors mean the mounted config is wrong.
if grep -E 'logger=provisioning\.(datasources|dashboard)[[:space:]].*level=error|level=error[[:space:]].*logger=provisioning\.(datasources|dashboard)' <<<"$logs"; then
  echo "observability-smoke: Grafana provisioning error" >&2
  printf '%s\n' "$logs" >&2
  exit 1
fi

echo "observability-smoke: ok"
