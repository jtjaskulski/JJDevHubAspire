#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

IMAGE="${TRIVY_API_IMAGE:-jjdevhub-api:ci}"

docker build -f infra/docker/Dockerfile -t "$IMAGE" .
trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$IMAGE"
