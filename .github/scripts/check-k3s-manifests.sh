#!/usr/bin/env bash
set -euo pipefail

# Repliki aplikacji zostają na 0, dopóki numer 16 nie wpisze digestu.

root=""

usage() {
  echo "$1" >&2
  exit 2
}

fail() {
  echo "$1" >&2
  status=1
}

trim() {
  local value=$1
  value=${value#"${value%%[![:space:]]*}"}
  value=${value%"${value##*[![:space:]]}"}
  printf '%s' "$value"
}

password_line_allowed() {
  case "$1" in
    "- name: POSTGRES_PASSWORD_FILE"|"value: /secrets/postgres/password"|"- key: password"|"path: password"|"secretName: postgres-superuser"|"- name: GF_SECURITY_ADMIN_PASSWORD"|"key: admin-password")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_line() {
  local file=$1
  local pattern=$2
  local reason=$3
  if ! grep -E -q "$pattern" "$file"; then
    fail "${file}: ${reason}"
  fi
}

require_count() {
  local file=$1
  local pattern=$2
  local expected=$3
  local reason=$4
  local count
  count=$(grep -E -c "$pattern" "$file" || true)
  if [[ $count -ne $expected ]]; then
    fail "${file}: ${reason}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 || $2 == --* ]]; then
        usage "brak --root"
      fi
      root=$2
      shift 2
      ;;
    *)
      usage "nieznany argument: $1"
      ;;
  esac
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/../.." && pwd)
if [[ -n $root ]]; then
  if [[ ! -d $root ]]; then
    usage "brak katalogu"
  fi
  repo_root=$(CDPATH='' cd -- "$root" && pwd)
fi

k3s="${repo_root}/deploy/k3s"
compose="${repo_root}/compose/sonarqube/compose.yml"
if [[ ! -d $k3s ]]; then
  usage "brak deploy/k3s"
fi
if [[ ! -f $compose ]]; then
  usage "brak compose sonarqube"
fi

status=0

expected_files=(
  namespace.yaml
  postgres/service.yaml
  postgres/statefulset.yaml
  redis/service.yaml
  redis/statefulset.yaml
  kafka/service.yaml
  kafka/statefulset.yaml
  sonar/service.yaml
  sonar/statefulset.yaml
  apps/identity.yaml
  apps/news.yaml
  apps/learning.yaml
  apps/cv.yaml
  apps/contact.yaml
  apps/gateway.yaml
  apps/web.yaml
  cloudflared/deployment.yaml
  cloudflared/secret.example.yaml
  observability/otel-collector.yaml
  observability/prometheus.yaml
  observability/prometheus/rules.yaml
  observability/jaeger.yaml
  observability/grafana/grafana.yaml
  observability/grafana/kustomization.yaml
  observability/grafana/datasources.yaml
  observability/grafana/dashboards.yaml
  observability/grafana/dashboards/jjdevhub-uslugi.json
  observability/grafana/dashboards/jjdevhub-wersje.json
)

expected_list=$(printf '%s\n' "${expected_files[@]}" | sort)
found_list=$(find "$k3s" -type f -printf '%P\n' | sort)
if [[ $expected_list != "$found_list" ]]; then
  fail "drzewo deploy/k3s nie jest listą numerów 08, 09, 10, 11, 12 i 13"
  echo "oczekiwane:" >&2
  printf '%s\n' "$expected_list" >&2
  echo "znalezione:" >&2
  printf '%s\n' "$found_list" >&2
fi

while IFS= read -r relative || [[ -n $relative ]]; do
  [[ -z $relative ]] && continue
  file="${k3s}/${relative}"
  base=$(basename -- "$relative" | tr '[:upper:]' '[:lower:]')
  if [[ $base == *mobile* ]]; then
    fail "${file}: mobile nie jest podem"
  fi
  line_no=0
  while IFS= read -r line || [[ -n $line ]]; do
    line_no=$((line_no + 1))
    trimmed=$(trim "$line")
    lower=$(printf '%s' "$trimmed" | tr '[:upper:]' '[:lower:]')
    if [[ $trimmed == *":latest"* ]]; then
      fail "${file}:${line_no}: tag latest"
    fi
    if [[ $trimmed == *"LoadBalancer"* || $trimmed == *"NodePort"* || $trimmed == *"Ingress"* ]]; then
      fail "${file}:${line_no}: publikacja poza ClusterIP"
    fi
    if [[ $trimmed == *"hostPort"* || $trimmed == *"externalIPs"* ]]; then
      fail "${file}:${line_no}: port na hoście"
    fi
    if [[ $lower == *"traefik"* || $lower == *"svclb"* ]]; then
      fail "${file}:${line_no}: dodatek k3s"
    fi
    if [[ $trimmed == *"AppHost"* ]]; then
      fail "${file}:${line_no}: AppHost nie jest Deploymentem"
    fi
    if [[ $lower == *"mobile"* ]]; then
      fail "${file}:${line_no}: mobile nie jest podem"
    fi
    if [[ $lower == *"password"* ]] && ! password_line_allowed "$trimmed"; then
      fail "${file}:${line_no}: hasło w manifeście"
    fi
  done < "$file"
done < <(find "$k3s" -type f -printf '%P\n' | sort)

namespace="${k3s}/namespace.yaml"
require_line "$namespace" '^kind: Namespace$' "brak Namespace"
require_line "$namespace" '^  name: jjdevhub$' "namespace nie nazywa się jjdevhub"

databases=(
  identity_write
  identity_read
  news_write
  news_read
  learning_write
  learning_read
  cv_write
  cv_read
  contact_write
  contact_read
)
postgres="${k3s}/postgres/statefulset.yaml"
for database in "${databases[@]}"; do
  require_count "$postgres" "^[[:space:]]*CREATE DATABASE ${database};$" 1 "brak bazy ${database}"
done
if grep -E -q 'CREATE (TABLE|ROLE|USER)|GRANT ' "$postgres"; then
  fail "${postgres}: init tworzy coś poza pustą bazą"
fi
require_line "$postgres" '^kind: StatefulSet$' "brak StatefulSet"
require_line "$postgres" '^  name: postgres$' "StatefulSet nie nazywa się postgres"
require_count "$postgres" '^  replicas: 1$' 1 "Postgres nie ma jednej repliki"
require_line "$postgres" 'image: postgres:16-alpine@sha256:[0-9a-f]{64}$' "obraz Postgresa bez digestu 16-alpine"
require_line "$postgres" 'storageClassName: local-path$' "PVC Postgresa bez local-path"
require_line "$postgres" 'storage: 40Gi$' "PVC Postgresa nie ma 40Gi"
require_line "$postgres" 'pg_isready' "brak probe pg_isready"
require_line "$postgres" 'secretName: postgres-superuser$' "brak odniesienia do Secretu superużytkownika"
require_line "$postgres" 'name: POSTGRES_PASSWORD_FILE$' "hasło nie wchodzi z pliku"

require_line "${k3s}/postgres/service.yaml" '^  name: postgres$' "Service nie nazywa się postgres"
require_line "${k3s}/postgres/service.yaml" '^  type: ClusterIP$' "Service postgres nie jest ClusterIP"
require_line "${k3s}/postgres/service.yaml" 'port: 5432$' "Service postgres nie słucha na 5432"

redis="${k3s}/redis/statefulset.yaml"
require_line "$redis" '^  name: cache$' "StatefulSet nie nazywa się cache"
require_count "$redis" '^  replicas: 1$' 1 "Redis nie ma jednej repliki"
require_line "$redis" 'image: redis:8.6@sha256:[0-9a-f]{64}$' "obraz Redisa bez digestu 8.6"
require_line "$redis" 'sizeLimit: 1Gi$' "emptyDir Redisa bez limitu 1Gi"
if grep -E -q 'cluster-enabled|requirepass|persistentVolumeClaim' "$redis"; then
  fail "${redis}: Redis nie jest samym cache"
fi

require_line "${k3s}/redis/service.yaml" '^  name: cache$' "Service nie nazywa się cache"
require_line "${k3s}/redis/service.yaml" '^  type: ClusterIP$' "Service cache nie jest ClusterIP"
require_line "${k3s}/redis/service.yaml" 'port: 6379$' "Service cache nie słucha na 6379"

kafka="${k3s}/kafka/statefulset.yaml"
require_line "$kafka" '^  name: kafka$' "StatefulSet nie nazywa się kafka"
require_count "$kafka" '^  replicas: 1$' 1 "Kafka nie ma jednej repliki"
require_line "$kafka" 'image: apache/kafka:4.1.2@sha256:[0-9a-f]{64}$' "obraz Kafki bez digestu 4.1.2"
require_line "$kafka" 'storageClassName: local-path$' "PVC Kafki bez local-path"
require_line "$kafka" 'storage: 20Gi$' "PVC Kafki nie ma 20Gi"
require_line "$kafka" 'value: PLAINTEXT://kafka.jjdevhub.svc.cluster.local:9092$' "listener nie jest nazwą Service"
if ! grep -A1 'name: CLUSTER_ID' "$kafka" | grep -E -q 'value: [A-Za-z0-9_-]{22}$'; then
  fail "${kafka}: CLUSTER_ID nie jest stałym identyfikatorem"
fi

kafka_service="${k3s}/kafka/service.yaml"
require_line "$kafka_service" '^  name: kafka$' "Service nie nazywa się kafka"
require_line "$kafka_service" '^  type: ClusterIP$' "Service kafka nie jest ClusterIP"
require_line "$kafka_service" 'port: 9092$' "Service kafka nie słucha na 9092"
if grep -q '9093' "$kafka_service"; then
  fail "${kafka_service}: port kontrolera jest w Service"
fi

sonar_compose=$(grep -E -o 'sonarqube@sha256:[0-9a-f]{64}' "$compose" | head -n 1)
if [[ -z $sonar_compose ]]; then
  fail "${compose}: brak digestu Sonara"
fi
sonar="${k3s}/sonar/statefulset.yaml"
require_line "$sonar" '^  name: sonarqube$' "StatefulSet nie nazywa się sonarqube"
require_count "$sonar" '^  replicas: 1$' 1 "Sonar nie ma jednej repliki"
require_line "$sonar" "image: ${sonar_compose}$" "digest Sonara rozjechał się z compose"
require_line "$sonar" 'storageClassName: local-path$' "PVC Sonara bez local-path"
require_line "$sonar" 'storage: 10Gi$' "PVC Sonara nie ma 10Gi"
if grep -q '0.0.0.0' "$sonar" || grep -q '0.0.0.0' "${k3s}/sonar/service.yaml"; then
  fail "Sonar słucha na 0.0.0.0"
fi

require_line "${k3s}/sonar/service.yaml" '^  name: sonarqube$' "Service nie nazywa się sonarqube"
require_line "${k3s}/sonar/service.yaml" '^  type: ClusterIP$' "Service sonarqube nie jest ClusterIP"
require_line "${k3s}/sonar/service.yaml" 'port: 9000$' "Service sonarqube nie słucha na 9000"

apps=(identity news learning cv contact gateway web)
domain=(identity news learning cv contact)
for name in "${apps[@]}"; do
  file="${k3s}/apps/${name}.yaml"
  require_line "$file" '^kind: Deployment$' "brak Deploymentu"
  require_line "$file" '^kind: Service$' "brak Service"
  require_line "$file" "^  name: ${name}$" "nazwa nie jest ${name}"
  require_count "$file" '^  replicas: 0$' 1 "replicas nie jest 0"
  require_count "$file" '^[[:space:]]*replicas:' 1 "więcej niż jedno replicas"
  require_line "$file" "^[[:space:]]*image: ghcr.io/jtjaskulski/jjdevhub-${name}@sha256:[0-9a-f]{64}$" "obraz nie jest digestem ghcr"
  require_count "$file" 'path: /health$' 2 "probe nie woła /health"
  require_line "$file" 'containerPort: 8080$' "kontener nie słucha na 8080"
  require_line "$file" '^  type: ClusterIP$' "Service nie jest ClusterIP"
  require_line "$file" 'port: 8080$' "Service nie słucha na 8080"
  require_line "$file" 'name: OTEL_EXPORTER_OTLP_ENDPOINT$' "brak OTEL_EXPORTER_OTLP_ENDPOINT"
  require_line "$file" 'value: http://otel-collector\.jjdevhub\.svc\.cluster\.local:4317$' "endpoint OTLP nie wskazuje collectora"
  require_line "$file" 'name: OTEL_EXPORTER_OTLP_PROTOCOL$' "brak OTEL_EXPORTER_OTLP_PROTOCOL"
  require_line "$file" 'value: grpc$' "protokół OTLP nie jest grpc"
  require_line "$file" 'name: OTEL_SERVICE_NAME$' "brak OTEL_SERVICE_NAME"
  require_line "$file" "value: ${name}$" "OTEL_SERVICE_NAME nie jest ${name}"
  require_line "$file" "value: service\\.version=${name}-v[0-9]+\\.[0-9]+\\.[0-9]+,deployment\\.environment=production$" "service.version nie jest tagiem komponentu"
done

for name in "${domain[@]}"; do
  file="${k3s}/apps/${name}.yaml"
  require_line "$file" "name: ConnectionStrings__${name}_write$" "brak connection stringa zapisu"
  require_line "$file" "value: Host=postgres.jjdevhub.svc.cluster.local;Port=5432;Database=${name}_write$" "zapis nie wskazuje Service postgres"
  require_line "$file" "name: ConnectionStrings__${name}_read$" "brak connection stringa odczytu"
  require_line "$file" "value: Host=postgres.jjdevhub.svc.cluster.local;Port=5432;Database=${name}_read$" "odczyt nie wskazuje Service postgres"
  require_line "$file" 'name: ConnectionStrings__cache$' "brak connection stringa cache"
  require_line "$file" 'value: cache.jjdevhub.svc.cluster.local:6379$' "cache nie wskazuje Service cache"
  require_line "$file" 'name: ConnectionStrings__kafka$' "brak connection stringa kafka"
  require_line "$file" 'value: kafka.jjdevhub.svc.cluster.local:9092$' "kafka nie wskazuje Service kafka"
done

for name in gateway web; do
  file="${k3s}/apps/${name}.yaml"
  if grep -q 'ConnectionStrings__' "$file"; then
    fail "${file}: brama i web nie dostają connection stringa bazy"
  fi
done

cloudflared="${k3s}/cloudflared/deployment.yaml"
require_line "$cloudflared" '^kind: Deployment$' "brak Deploymentu"
require_line "$cloudflared" '^  name: cloudflared$' "Deployment nie nazywa się cloudflared"
require_line "$cloudflared" '^  namespace: jjdevhub$' "namespace nie nazywa się jjdevhub"
require_count "$cloudflared" '^  replicas: 1$' 1 "cloudflared nie ma jednej repliki"
require_count "$cloudflared" '^[[:space:]]*replicas:' 1 "więcej niż jedno replicas"
require_line "$cloudflared" '^[[:space:]]*image: cloudflare/cloudflared@sha256:[0-9a-f]{64}$' "obraz nie jest digestem cloudflared"
require_line "$cloudflared" '^[[:space:]]*- tunnel$' "brak argumentu tunnel"
require_line "$cloudflared" '^[[:space:]]*- --no-autoupdate$' "brak --no-autoupdate"
require_line "$cloudflared" '^[[:space:]]*- run$' "brak argumentu run"
require_line "$cloudflared" '^[[:space:]]*- name: TUNNEL_TOKEN$' "brak TUNNEL_TOKEN"
require_line "$cloudflared" '^[[:space:]]*name: cloudflared-token$' "token nie pochodzi z Secretu cloudflared-token"
require_line "$cloudflared" '^[[:space:]]*key: token$' "klucz Secretu nie nazywa się token"
if grep -q 'eyJ' "$cloudflared"; then
  fail "${cloudflared}: token w manifeście"
fi
if grep -q 'hostNetwork' "$cloudflared"; then
  fail "${cloudflared}: hostNetwork"
fi
if grep -R -q 'kind: HorizontalPodAutoscaler' "${k3s}/cloudflared"; then
  fail "cloudflared ma HPA"
fi

secret_example="${k3s}/cloudflared/secret.example.yaml"
require_line "$secret_example" '^kind: Secret$' "brak Secretu"
require_line "$secret_example" '^  name: cloudflared-token$' "Secret nie nazywa się cloudflared-token"
require_line "$secret_example" '^  namespace: jjdevhub$' "namespace nie nazywa się jjdevhub"
require_line "$secret_example" '^[[:space:]]*token: ""$' "przykład Secretu ma puste pole token"
if grep -q 'eyJ' "$secret_example"; then
  fail "${secret_example}: token w przykładzie"
fi

collector="${k3s}/observability/otel-collector.yaml"
require_line "$collector" '^kind: ConfigMap$' "brak ConfigMap"
require_line "$collector" '^kind: Deployment$' "brak Deploymentu"
require_line "$collector" '^kind: Service$' "brak Service"
require_count "$collector" '^  name: otel-collector$' 3 "nazwa nie jest otel-collector"
require_count "$collector" '^  replicas: 1$' 1 "collector nie ma jednej repliki"
require_count "$collector" '^[[:space:]]*replicas:' 1 "więcej niż jedno replicas"
require_line "$collector" '^[[:space:]]*image: otel/opentelemetry-collector@sha256:[0-9a-f]{64}$' "obraz collectora bez digestu"
require_line "$collector" '^  type: ClusterIP$' "Service collectora nie jest ClusterIP"
require_line "$collector" 'port: 4317$' "Service collectora nie słucha na 4317"
require_line "$collector" 'port: 8889$' "Service collectora nie słucha na 8889"
require_line "$collector" 'containerPort: 13133$' "probe nie ma portu 13133"
require_count "$collector" 'port: health$' 2 "probe nie woła portu health"
if grep -q 'port: 13133' "$collector"; then
  fail "${collector}: port 13133 jest w Service"
fi
require_line "$collector" 'cpu: 100m$' "brak żądania 100m CPU"
require_line "$collector" 'memory: 256Mi$' "brak żądania 256Mi"
require_line "$collector" 'endpoint: 0\.0\.0\.0:4317$' "receiver OTLP nie słucha na 4317"
require_line "$collector" 'endpoint: 0\.0\.0\.0:8889$' "eksporter Prometheus nie słucha na 8889"
require_line "$collector" 'endpoint: jaeger\.jjdevhub\.svc\.cluster\.local:4317$' "ślady nie idą na Service jaeger"
require_line "$collector" 'insecure: true$' "odcinek do Jaegera nie jest insecure"
require_line "$collector" 'endpoint: 0\.0\.0\.0:13133$' "health_check nie słucha na 13133"
require_line "$collector" 'exporters: \[prometheus\]$' "potok metryk nie kończy się na Prometheusie"
require_line "$collector" 'exporters: \[otlp/jaeger\]$' "potok śladów nie kończy się na otlp/jaeger"
require_line "$collector" 'exporters: \[debug\]$' "potok logów nie kończy się na debug"
if grep -q 'metricstransform:' "$collector"; then
  fail "${collector}: metricstransform w potoku"
fi
if grep -E -q 'probabilistic_sampler|tail_sampling' "$collector"; then
  fail "${collector}: sampler w potoku śladów"
fi

jaeger="${k3s}/observability/jaeger.yaml"
require_line "$jaeger" '^kind: StatefulSet$' "brak StatefulSet"
require_line "$jaeger" '^kind: Service$' "brak Service"
require_count "$jaeger" '^  name: jaeger$' 2 "nazwa nie jest jaeger"
require_count "$jaeger" '^  replicas: 1$' 1 "Jaeger nie ma jednej repliki"
require_count "$jaeger" '^[[:space:]]*replicas:' 1 "więcej niż jedno replicas"
require_line "$jaeger" '^[[:space:]]*image: jaegertracing/all-in-one@sha256:[0-9a-f]{64}$' "obraz Jaegera bez digestu"
require_line "$jaeger" '^  type: ClusterIP$' "Service Jaegera nie jest ClusterIP"
require_line "$jaeger" 'port: 4317$' "Service Jaegera nie słucha na 4317"
require_line "$jaeger" 'port: 16686$' "Service Jaegera nie słucha na 16686"
require_line "$jaeger" 'storageClassName: local-path$' "PVC Jaegera bez local-path"
require_line "$jaeger" 'storage: 10Gi$' "PVC Jaegera nie ma 10Gi"
require_line "$jaeger" 'mountPath: /badger$' "Badger nie jest montowany w /badger"
require_line "$jaeger" 'name: SPAN_STORAGE_TYPE$' "brak SPAN_STORAGE_TYPE"
require_line "$jaeger" 'value: badger$' "magazyn nie jest Badgerem"
require_line "$jaeger" 'name: BADGER_EPHEMERAL$' "brak BADGER_EPHEMERAL"
require_line "$jaeger" 'value: "false"$' "Badger jest efemeryczny"
require_line "$jaeger" 'name: BADGER_DIRECTORY_VALUE$' "brak katalogu wartości"
require_line "$jaeger" 'value: /badger/data$' "katalog wartości nie jest /badger/data"
require_line "$jaeger" 'name: BADGER_DIRECTORY_KEY$' "brak katalogu kluczy"
require_line "$jaeger" 'value: /badger/key$' "katalog kluczy nie jest /badger/key"
require_line "$jaeger" 'name: BADGER_SPAN_STORE_TTL$' "brak retencji"
require_line "$jaeger" 'value: 168h$' "retencja nie jest 7 dni"
require_line "$jaeger" 'name: QUERY_BASE_PATH$' "brak QUERY_BASE_PATH"
require_line "$jaeger" 'value: /$' "baza ścieżki UI nie jest /"
if grep -E -q '4318|9411|14268|14250|COLLECTOR_ZIPKIN|emptyDir' "$jaeger"; then
  fail "${jaeger}: port spoza 4317 i 16686 albo magazyn efemeryczny"
fi
if grep -R -E -q '16686|jaeger\.jjdevhub' "${k3s}/apps"; then
  fail "aplikacja zna Jaegera"
fi

grafana="${k3s}/observability/grafana/grafana.yaml"
require_line "$grafana" '^kind: Deployment$' "brak Deploymentu"
require_line "$grafana" '^kind: Service$' "brak Service"
require_line "$grafana" '^kind: PersistentVolumeClaim$' "brak PVC"
require_count "$grafana" '^  name: grafana$' 3 "nazwa nie jest grafana"
require_count "$grafana" '^  replicas: 1$' 1 "Grafana nie ma jednej repliki"
require_count "$grafana" '^[[:space:]]*replicas:' 1 "więcej niż jedno replicas"
require_line "$grafana" '^[[:space:]]*image: grafana/grafana@sha256:[0-9a-f]{64}$' "obraz Grafany bez digestu"
require_line "$grafana" '^  type: ClusterIP$' "Service Grafany nie jest ClusterIP"
require_line "$grafana" 'port: 3000$' "Service Grafany nie słucha na 3000"
require_line "$grafana" 'containerPort: 3000$' "kontener nie słucha na 3000"
require_line "$grafana" 'cpu: 100m$' "brak żądania 100m CPU"
require_line "$grafana" 'memory: 256Mi$' "brak żądania 256Mi"
require_line "$grafana" 'storageClassName: local-path$' "PVC Grafany bez local-path"
require_line "$grafana" 'storage: 10Gi$' "PVC Grafany nie ma 10Gi"
require_line "$grafana" 'mountPath: /var/lib/grafana$' "katalog danych nie jest /var/lib/grafana"
require_line "$grafana" 'mountPath: /var/lib/grafana/dashboards$' "JSON nie jest montowany obok katalogu danych"
require_line "$grafana" 'mountPath: /etc/grafana/provisioning/datasources$' "brak montowania datasource"
require_line "$grafana" 'mountPath: /etc/grafana/provisioning/dashboards$' "brak montowania providerów"
require_line "$grafana" 'name: grafana-datasources$' "brak ConfigMapy datasource"
require_line "$grafana" 'name: grafana-dashboard-provider$' "brak ConfigMapy providerów"
require_line "$grafana" 'name: grafana-dashboards$' "brak ConfigMapy dashboardów"
require_line "$grafana" 'name: GF_SECURITY_ADMIN_PASSWORD$' "brak hasła z Secreta"
require_line "$grafana" 'name: grafana-admin$' "hasło nie pochodzi z Secretu grafana-admin"
require_line "$grafana" 'key: admin-password$' "klucz Secretu nie nazywa się admin-password"
require_line "$grafana" 'name: GF_AUTH_ANONYMOUS_ENABLED$' "brak wyłączenia anonimowego dostępu"
require_line "$grafana" 'value: "false"$' "anonimowy dostęp nie jest wyłączony"
require_count "$grafana" 'path: /api/health$' 3 "probe nie woła /api/health"
require_line "$grafana" 'runAsUser: 472$' "proces nie działa jako użytkownik obrazu"
if grep -E -q 'GF_SERVER_ROOT_URL|stringData|emptyDir|loki|Loki|promtail|Promtail|otlp|OTLP|4317|hostPort|nodePort' "$grafana"; then
  fail "${grafana}: root URL, sekret, dysk efemeryczny albo obcy sygnał"
fi

datasources="${k3s}/observability/grafana/datasources.yaml"
require_line "$datasources" 'uid: prometheus$' "brak uid prometheus"
require_line "$datasources" 'uid: jaeger$' "brak uid jaeger"
require_line "$datasources" 'isDefault: true$' "Prometheus nie jest domyślny"
require_count "$datasources" 'editable: false$' 2 "datasource da się zmienić w UI"
require_count "$datasources" 'access: proxy$' 2 "datasource nie idzie przez proxy"
require_line "$datasources" 'url: http://prometheus\.jjdevhub\.svc\.cluster\.local:9090$' "adres Prometheusa"
require_line "$datasources" 'url: http://jaeger\.jjdevhub\.svc\.cluster\.local:16686$' "adres Jaegera"

providers="${k3s}/observability/grafana/dashboards.yaml"
require_line "$providers" 'allowUiUpdates: false$' "zapis z UI jest wydaniem"
require_line "$providers" 'path: /var/lib/grafana/dashboards$' "ścieżka JSON się rozjechała"
require_line "$providers" 'foldersFromFilesStructure: true$' "katalog dashboardów nie jest z plików"
require_line "$providers" 'name: jjdevhub$' "provider nie nazywa się jjdevhub"

uslugi="${k3s}/observability/grafana/dashboards/jjdevhub-uslugi.json"
wersje="${k3s}/observability/grafana/dashboards/jjdevhub-wersje.json"
require_line "$uslugi" 'jjdevhub:http_server_active_requests:sum' "panel nie woła rekordu żądań w toku"
require_line "$uslugi" 'http_server_request_duration_seconds_bucket' "panel nie woła histogramu czasu"
require_line "$uslugi" '"uid": "prometheus"' "panel usług nie ma uid prometheus"
require_line "$uslugi" '"uid": "jaeger"' "link śladu nie ma uid jaeger"
require_line "$uslugi" 'trace_id' "link śladu nie używa trace_id"
require_line "$uslugi" '"repeat": "service_name"' "wiersz usług nie powtarza service_name"
require_line "$wersje" 'service_version' "panel wersji nie czyta service_version"
require_line "$wersje" 'count by \(service_name, instance\)' "liczba replik nie liczy instancji"
require_line "$wersje" '"uid": "prometheus"' "panel wersji nie ma uid prometheus"
require_line "$wersje" '"repeat": "service_name"' "wiersz wersji nie powtarza service_name"
for dashboard in "$uslugi" "$wersje"; do
  if grep -E -q 'mobile|ghcr\.io|ReplicaSet|kube_pod|kube_deployment' "$dashboard"; then
    fail "${dashboard}: panel zna telefon, obraz albo nazwę poda"
  fi
done

kustomization="${k3s}/observability/grafana/kustomization.yaml"
require_line "$kustomization" '^[[:space:]]*- grafana\.yaml$' "kustomizacja nie bierze grafana.yaml"
require_line "$kustomization" 'name: grafana-datasources$' "brak generatora datasource"
require_line "$kustomization" 'name: grafana-dashboard-provider$' "brak generatora providerów"
require_line "$kustomization" 'name: grafana-dashboards$' "brak generatora dashboardów"
require_line "$kustomization" 'jjdevhub-uslugi\.json=' "brak klucza dashboardu usług"
require_line "$kustomization" 'jjdevhub-wersje\.json=' "brak klucza dashboardu wersji"
if grep -q 'disableNameSuffixHash' "$kustomization"; then
  fail "${kustomization}: hash ConfigMapy jest wyłączony"
fi

if grep -R -i -q 'grafana' "${k3s}/apps"; then
  fail "aplikacja zna Grafanę"
fi
if grep -R -q 'kind: HorizontalPodAutoscaler' "${k3s}/observability"; then
  fail "collector ma HPA"
fi

exit "$status"
