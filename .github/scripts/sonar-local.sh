#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$1" >&2
  exit 2
}

if [[ $# -ne 0 ]]; then
  usage "nieznany argument: $1"
fi

command -v sysctl >/dev/null 2>&1 || usage "brak sysctl"
command -v docker >/dev/null 2>&1 || usage "brak docker"
command -v openssl >/dev/null 2>&1 || usage "brak openssl"

map_count=$(sysctl -n vm.max_map_count)
if [[ $map_count -lt 524288 ]]; then
  echo "vm.max_map_count jest ${map_count}, potrzeba co najmniej 524288" >&2
  exit 1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)

state_home=${XDG_STATE_HOME:-${HOME}/.local/state}
password_file=${SONAR_ADMIN_PASSWORD_FILE:-${state_home}/jjdevhub/sonarqube-admin-password}
token_file=$(dirname -- "$password_file")/sonarqube-analysis-token
mkdir -p -- "$(dirname -- "$password_file")"
fresh=0
if [[ ! -s $password_file ]]; then
  umask 077
  openssl rand -base64 24 | tr -d '\n' > "$password_file"
  chmod 600 "$password_file"
  fresh=1
else
  chmod 600 "$password_file"
fi

password=$(<"$password_file")
password=${password//$'\r'/}
password=${password//$'\n'/}
if [[ -z $password || ${password} =~ [[:space:]] ]]; then
  echo "pusty plik hasła" >&2
  exit 1
fi

export SONAR_HOST_URL=http://127.0.0.1:9000
export SONAR_ADMIN_PASSWORD="$password"
if [[ $fresh -eq 0 ]]; then
  export SONAR_ADMIN_PREVIOUS_PASSWORD="$password"
else
  unset SONAR_ADMIN_PREVIOUS_PASSWORD
fi
export SONAR_TOKEN_FILE="$token_file"
unset password

docker compose -p jjdevhub-sonarqube -f "${repo_root}/compose/sonarqube/compose.yml" up -d
"${repo_root}/.github/scripts/sonar-bootstrap.sh"

printf '%s\n' 'http://127.0.0.1:9000'
printf '%s\n' "$password_file"
