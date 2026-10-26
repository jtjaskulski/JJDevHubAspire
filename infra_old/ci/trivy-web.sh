#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

IMAGE="${TRIVY_WEB_IMAGE:-jjdevhub-web:ci}"

docker build -f src/Clients/web/Dockerfile -t "$IMAGE" src/Clients
trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$IMAGE"
