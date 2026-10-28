#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "$1" >&2
  exit 2
}

if [[ $# -ne 0 ]]; then
  usage "nieznany argument: $1"
fi

command -v jq >/dev/null 2>&1 || usage "brak jq"
command -v curl >/dev/null 2>&1 || usage "brak curl"

if [[ -z ${SONAR_ADMIN_PASSWORD:-} ]]; then
  usage "brak SONAR_ADMIN_PASSWORD"
fi
if [[ -z ${SONAR_TOKEN_FILE:-} ]]; then
  usage "brak SONAR_TOKEN_FILE"
fi
if [[ ${SONAR_ADMIN_PASSWORD} =~ [[:space:]] ]]; then
  usage "hasło zawiera biały znak"
fi

SONAR_HOST_URL=${SONAR_HOST_URL:-http://127.0.0.1:9000}
SONAR_HOST_URL=${SONAR_HOST_URL%/}
case "$SONAR_HOST_URL" in
  http://*|https://*) ;;
  *) usage "zły adres serwera" ;;
esac

previous=${SONAR_ADMIN_PREVIOUS_PASSWORD:-admin}
if [[ -z $previous || ${previous} =~ [[:space:]] ]]; then
  usage "złe hasło poprzednie"
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
gate_file=${SONAR_GATE_FILE:-${repo_root}/.github/sonar/quality-gate.json}
if [[ ! -f $gate_file ]]; then
  usage "brak pliku bramki"
fi

if ! jq -e '
  .name == "jjdevhub"
  and (.conditions | type == "array" and length > 0)
  and all(
    .conditions[];
    (.metric | type == "string" and length > 0)
    and (.op == "LT" or .op == "GT" or .op == "EQ")
    and (.error | type == "string" and length > 0)
  )
' "$gate_file" >/dev/null; then
  echo "bramka w pliku jest niekompletna" >&2
  exit 1
fi

netrc=$(mktemp)
prev_file=$(mktemp)
new_file=$(mktemp)
chmod 600 "$netrc" "$prev_file" "$new_file"
api_body_file=""
api_code=""

cleanup() {
  rm -f "$netrc" "$prev_file" "$new_file"
  if [[ -n $api_body_file ]]; then
    rm -f "$api_body_file"
  fi
}
trap cleanup EXIT

printf '%s' "$previous" > "$prev_file"
printf '%s' "$SONAR_ADMIN_PASSWORD" > "$new_file"

write_netrc() {
  local password=$1
  local host=${SONAR_HOST_URL#*://}
  host=${host%%/*}
  host=${host%%:*}
  printf 'machine %s\nlogin admin\npassword ' "$host" > "$netrc"
  printf '%s\n' "$password" >> "$netrc"
  chmod 600 "$netrc"
}

call_api() {
  local method=$1
  local path=$2
  shift 2
  local body_file
  body_file=$(mktemp)
  chmod 600 "$body_file"
  local code
  if ! code=$(curl --silent --show-error --netrc-file "$netrc" \
    --output "$body_file" \
    --write-out '%{http_code}' \
    --request "$method" \
    "$@" \
    --url "${SONAR_HOST_URL}${path}"); then
    rm -f "$body_file"
    echo "błąd wywołania ${path}" >&2
    exit 1
  fi
  if [[ -n $api_body_file ]]; then
    rm -f "$api_body_file"
  fi
  api_code=$code
  api_body_file=$body_file
}

authenticated() {
  [[ $api_code == 200 ]] && jq -e '.valid == true' "$api_body_file" >/dev/null 2>&1
}

deadline=$(( $(date +%s) + 180 ))
ready=0
while true; do
  now=$(date +%s)
  if [[ $now -ge $deadline ]]; then
    break
  fi
  remaining=$((deadline - now))
  if [[ $remaining -gt 5 ]]; then
    max_time=5
  else
    max_time=$remaining
  fi
  body=$(curl --silent --show-error --max-time "$max_time" "${SONAR_HOST_URL}/api/system/status" || true)
  if [[ -n $body ]] && printf '%s' "$body" | jq -e '.status == "UP"' >/dev/null 2>&1; then
    ready=1
    break
  fi
  now=$(date +%s)
  remaining=$((deadline - now))
  if [[ $remaining -le 0 ]]; then
    break
  fi
  if [[ $remaining -gt 2 ]]; then
    sleep 2
  else
    sleep "$remaining"
  fi
done
if [[ $ready -ne 1 ]]; then
  echo "kontener nie wstał" >&2
  exit 1
fi

write_netrc "$SONAR_ADMIN_PASSWORD"
call_api GET /api/authentication/validate
if ! authenticated; then
  if [[ $previous == "$SONAR_ADMIN_PASSWORD" ]]; then
    echo "logowanie nie powiodło się" >&2
    exit 1
  fi
  write_netrc "$previous"
  call_api POST /api/users/change_password \
    --data-urlencode "login=admin" \
    --data-urlencode "previousPassword@${prev_file}" \
    --data-urlencode "password@${new_file}"
  if [[ $api_code != 200 && $api_code != 204 ]]; then
    echo "zmiana hasła nie powiodła się" >&2
    exit 1
  fi
  write_netrc "$SONAR_ADMIN_PASSWORD"
  call_api GET /api/authentication/validate
  if ! authenticated; then
    echo "logowanie nie powiodło się" >&2
    exit 1
  fi
fi

call_api POST /api/projects/create \
  --data-urlencode "project=jjdevhub" \
  --data-urlencode "name=jjdevhub"
if [[ $api_code == 200 || $api_code == 204 ]]; then
  :
elif [[ $api_code == 400 ]] && jq -e 'any(.errors[]?; .msg | test("already exists"))' "$api_body_file" >/dev/null 2>&1; then
  :
else
  echo "utworzenie projektu nie powiodło się" >&2
  exit 1
fi

call_api GET /api/qualitygates/show \
  --get \
  --data-urlencode "name=jjdevhub"
if [[ $api_code == 404 ]]; then
  call_api POST /api/qualitygates/create \
    --data-urlencode "name=jjdevhub"
  if [[ $api_code != 200 && $api_code != 204 ]]; then
    echo "utworzenie bramki nie powiodło się" >&2
    exit 1
  fi
  call_api GET /api/qualitygates/show \
    --get \
    --data-urlencode "name=jjdevhub"
fi
if [[ $api_code != 200 ]]; then
  echo "odczyt bramki nie powiódł się" >&2
  exit 1
fi

gate_id=$(jq -r '.id // empty' "$api_body_file")
if [[ -z $gate_id ]]; then
  echo "brak identyfikatora bramki" >&2
  exit 1
fi
condition_ids=()
while IFS= read -r condition_id; do
  [[ -z $condition_id ]] && continue
  condition_ids+=("$condition_id")
done < <(jq -r '.conditions[]? | .id' "$api_body_file")

for condition_id in "${condition_ids[@]}"; do
  call_api POST /api/qualitygates/delete_condition \
    --data-urlencode "id=${condition_id}"
  if [[ $api_code != 200 && $api_code != 204 ]]; then
    echo "usunięcie warunku bramki nie powiodło się" >&2
    exit 1
  fi
done

while IFS=$'\t' read -r metric op error; do
  [[ -z $metric ]] && continue
  call_api POST /api/qualitygates/create_condition \
    --data-urlencode "gateId=${gate_id}" \
    --data-urlencode "metric=${metric}" \
    --data-urlencode "op=${op}" \
    --data-urlencode "error=${error}"
  if [[ $api_code != 200 && $api_code != 204 ]]; then
    echo "warunek bramki nie wszedł: ${metric}" >&2
    exit 1
  fi
done < <(jq -r '.conditions[] | [.metric, .op, .error] | @tsv' "$gate_file")

call_api POST /api/qualitygates/select \
  --data-urlencode "gateId=${gate_id}" \
  --data-urlencode "projectKey=jjdevhub"
if [[ $api_code != 200 && $api_code != 204 ]]; then
  echo "przypięcie bramki nie powiodło się" >&2
  exit 1
fi

token_name="jjdevhub-$(date +%s)-$$"
call_api POST /api/user_tokens/generate \
  --data-urlencode "name=${token_name}" \
  --data-urlencode "type=PROJECT_ANALYSIS_TOKEN" \
  --data-urlencode "projectKey=jjdevhub"
if [[ $api_code != 200 ]]; then
  echo "brak tokenu skanera" >&2
  exit 1
fi

set +x
token=$(jq -r '.token // empty' "$api_body_file")
if [[ -z $token || $token == null ]]; then
  echo "brak tokenu skanera" >&2
  exit 1
fi
token_dir=$(dirname -- "$SONAR_TOKEN_FILE")
mkdir -p -- "$token_dir"
umask 077
printf '%s' "$token" > "$SONAR_TOKEN_FILE"
chmod 600 "$SONAR_TOKEN_FILE"
unset token
