# Grafana — dashboardy z Prometheusa i Jaegera

## Po co

Prometheus ([07-prometheus.md](07-prometheus.md)) trzyma metryki, Jaeger ([08-jaeger.md](08-jaeger.md)) trzyma trace. Bez wspólnego UI skaczesz między `:9090` a `:16686`. Port na hoście zostaje `127.0.0.1:3000`. Publiczny UI to `https://grafana.jjdevhub.com/` w tym samym tunelu ([02-cloudflare-tunnel.md](02-cloudflare-tunnel.md)).

## Dlaczego ta technologia

### Grafana jako klient, nie jako zbieracz

Grafana rysuje dane, których sama nie zbiera. W tym Compose jest klientem Prometheusa (`http://prometheus:9090`, PromQL) i Jaegera (`http://jaeger:16686`, HTTP API query, nie OTLP na 4317). Przeglądarka rozmawia tylko z Grafaną. W trybie `proxy` Grafana sama woła backendy w sieci Dockera. Tryb `direct` przegrał: przeglądarka miałaby rozwiązać nazwę `prometheus`, a na laptopie jej nie ma. Jeden panel w UI Prometheusa i drugi w UI Jaegera przegrały jako codzienne miejsce, bo to dwa logowania i dwa adresy. Koszt: katalog [infra/grafana/](../../infra/grafana/) jest źródłem prawdy dashboardu, a nie baza `grafana.db`. Exemplarze (klik w słupek otwiera span) w tym numerze nie są włączone.

## Co już jest w repo

- Compose i deploy — [01-proxmox.md](01-proxmox.md), [03-github.md](03-github.md), [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml), [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh)
- Tunel tylko na `127.0.0.1:4200` — [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md)
- OTLP w API — [06-opentelemetry.md](06-opentelemetry.md)
- Usługa `prometheus` (scrape `/metrics`, port UI na loopback) — [07-prometheus.md](07-prometheus.md)
- Usługa `jaeger` (`jjdevhub-jaeger`, UI `127.0.0.1:16686`, OTLP w sieci Compose) — [08-jaeger.md](08-jaeger.md)

Nazwy usług Dockera, których używasz w datasource’ach: `prometheus:9090`, `jaeger:16686` (query HTTP z sieci Compose). Kontenery aplikacji: `jjdevhub-api`, `jjdevhub-web`, `jjdevhub-db`.

Katalogu `infra/grafana/` jeszcze nie ma — ten plik go zakłada.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie tu |
| --- | --- |
| Datasource | Połączenie Grafany do backendu (Prometheus, Jaeger, …) |
| Provisioning | Konfiguracja z plików YAML/JSON przy starcie, bez klikania w UI |
| Dashboard as code | JSON dashboardu w git; Compose montuje go do kontenera |
| Explore | Widok ad-hoc zapytań PromQL / wyszukiwania traców |
| UID datasource | Stały identyfikator w JSON; dashboardy wskazują UID, nie losowe ID z UI |

## Kroki

### 1. Drzewo `infra/grafana/`

Utwórz:

```text
infra/grafana/
  provisioning/
    datasources/
      datasources.yml
    dashboards/
      dashboards.yml
  dashboards/
    jjdevhub-api-overview.json
```

### 2. Datasources (Prometheus + Jaeger)

Plik `infra/grafana/provisioning/datasources/datasources.yml`:

```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Jaeger
    type: jaeger
    uid: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: false
```

`access: proxy` = przeglądarka gada z Grafaną, Grafana z backendami w sieci Dockera. Nie wpisuj `127.0.0.1` jako URL datasource — z kontenera `grafana` to nie jest Prometheus/Jaeger.

### 3. Provider dashboardów

Plik `infra/grafana/provisioning/dashboards/dashboards.yml`:

```yaml
apiVersion: 1

providers:
  - name: jjdevhub
    orgId: 1
    folder: JJDevHub
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
```

### 4. Minimalny dashboard (JSON)

Plik `infra/grafana/dashboards/jjdevhub-api-overview.json` — wystarczy panel z PromQL i datasource UID `prometheus`. Poniższy szkielet da się rozbudować; przy wdrożeniu można dociągnąć panele (latency, RPS) pod metryki z 07:

```json
{
  "annotations": { "list": [] },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "panels": [
    {
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "fieldConfig": { "defaults": {}, "overrides": [] },
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 0 },
      "id": 1,
      "options": {},
      "targets": [
        {
          "datasource": { "type": "prometheus", "uid": "prometheus" },
          "expr": "up{job=\"jjdevhub-api\"}",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ],
      "title": "API scrape up",
      "type": "timeseries"
    }
  ],
  "schemaVersion": 39,
  "tags": ["jjdevhub", "api"],
  "templating": { "list": [] },
  "time": { "from": "now-1h", "to": "now" },
  "title": "JJDevHub API overview",
  "uid": "jjdevhub-api-overview",
  "version": 1
}
```

Jeśli w 07 job scrapa ma inną etykietę `job`, podmień `expr`. Po starcie Grafany możesz w UI zbudować bogatszy dashboard i **Share → Export → Save to file**, potem nadpisać JSON w git (as code).

Opcjonalnie drugi panel typu `traces` / link do Jaegera z datasource `uid: jaeger` — Explore → Jaeger też wystarczy na start.

### 5. Usługa `grafana` w Compose

Dopisz do [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml):

```yaml
  grafana:
    image: grafana/grafana:13.2.2
    container_name: jjdevhub-grafana
    environment:
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?GRAFANA_ADMIN_PASSWORD is required}
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_HTTP_PORT: "3000"
    ports:
      - "127.0.0.1:3000:3000"
    volumes:
      - ../grafana/provisioning:/etc/grafana/provisioning:ro
      - ../grafana/dashboards:/var/lib/grafana/dashboards:ro
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
      - jaeger
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:3000/api/health"]
      interval: 10s
      timeout: 3s
      retries: 12
      start_period: 20s
    restart: unless-stopped
```

W sekcji `volumes:` na dole pliku dodaj `grafana_data:` obok `postgres_data`.

Ścieżki volume są względne wobec pliku Compose w `infra/docker/`, stąd `../grafana/...`.

### 6. Sekrety admina

Dopisz do [infra/docker/.env.example](../../infra/docker/.env.example) i na VM do `/etc/jjdevhub/api.env`:

```bash
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=
```

`GRAFANA_ADMIN_PASSWORD` zostaw puste w przykładzie w git. Na VM i w lokalnym `infra/docker/.env` wstaw wynik `openssl rand -base64 24`. Puste albo brak zmiennej przerywa `docker compose` (`:?` w przepisie), zamiast startu ze znanym hasłem.

```bash
openssl rand -base64 24
sudoedit /etc/jjdevhub/api.env
```

Nie commituj prawdziwego hasła. Compose nie ma wartości domyślnej dla tego sekretu, także na lokalnym labie.

### 7. Compose up

```bash
cd /opt/jjdevhub
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml up -d --build
```

Lokalnie analogicznie z `infra/docker/.env`.

### 8. Tunel

Publiczny UI to `https://grafana.jjdevhub.com/` → `http://127.0.0.1:3000`. `GF_SERVER_ROOT_URL` musi być tym adresem, inaczej HTML wstanie, a pliki aplikacji nie. Szczegóły: [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).

Z VM albo przez port-forward, bez publicznego hosta:

```bash
ssh -L 3000:127.0.0.1:3000 deploy@IP_VM
```

## Jak sprawdzić, że działa

```bash
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml ps
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3000/login
```

Zaloguj się (`GRAFANA_ADMIN_*`). **Connections → Data sources**: Prometheus i Jaeger na zielono (Save & test). **Dashboards → JJDevHub → JJDevHub API overview**: panel `up` żyje po scrapie z 07. **Explore → Jaeger**: service `JJDevHub.Api` po ruchu z API (08).

Hub `https://hub.example.com` nie serwuje Grafany. Publiczny UI jest na `https://grafana.jjdevhub.com/`.

## Czego w tym pliku nie ruszać

- Nie publikuj `3000` na wszystkich interfejsach. Publiczny hostname to `grafana.jjdevhub.com` w [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md), origin zostaje `127.0.0.1:3000`
- Nie trzymaj haseł admina w git
- Nie usuwaj provisioningu na rzecz „tylko klikniętego” datasource bez UID — dashboardy w git się rozjadą
- Nie kieruj datasource’ów na hosty spoza sieci Compose (`localhost` z kontenera)
- Nie mieszaj roli: Grafana nie scrapuje metryk sama (to Prometheus) i nie przyjmuje OTLP (to Jaeger)
- Nie zmieniaj nginx ani Public Hostname pod ten krok

## Następny numer

[10-sonarqube.md](10-sonarqube.md) — SonarQube na VM, analiza po merge commita na `main`, coverage z `dotnet test`.

---

## Pełny tutorial: Grafana (od zera)

Czym jest Grafana jako klient backendów, jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają provisioning i to, co zobaczysz po zalogowaniu. Przepis plików jest wyżej. Nie dodajesz tu scrapera, collectora OTLP ani alertów na Slacka.

### Co realnie widać po tym kroku

Po `Save & test` i ruchu z API:

1. **Connections → Data sources** — Prometheus i Jaeger, oba zielone. UID `prometheus` i `jaeger` są takie jak w YAML, nie losowe numery z klikania.
2. **Dashboards → JJDevHub → JJDevHub API overview** — jeden wykres `up{job="jjdevhub-api"}`. Wartość `1` znaczy, że Prometheus ściągnął `/metrics` z `api:8080`. To nie jest wynik `GET /health` i nie jest liczbą requestów.
3. **Explore → Jaeger**, service `JJDevHub.Api` — ten sam span HTTP co w UI Jaegera (`GET /health`, `POST /api/auth/login`). Jedno dziecko SQL-a się nie pojawi; instrumentacji EF nie ma od 06. Restart Jaegera czyści listę, bo storage jest w pamięci. Grafana trace’ów nie trzyma.

`curl` na `http://127.0.0.1:3000/login` zwraca `200`, zanim datasource w ogóle wstanie. To tylko żywy proces HTTP.

### Proxy, nazwy, porty

`access: proxy` w YAML: zapytanie idzie przeglądarka → Grafana → backend. `access: direct` kazałoby przeglądarce łączyć się z URL-em datasource sama. `prometheus:9090` na laptopie się nie rozwiąże. Zostawiasz `proxy`.

URL-e biorą **nazwę usługi** Compose, nie nazwę kontenera i nie loopback:

| Datasource | URL | Czemu nie inny |
| --- | --- | --- |
| Prometheus | `http://prometheus:9090` | `jjdevhub-prometheus` to `container_name`. `127.0.0.1:9090` w kontenerze Grafany to ona sama. |
| Jaeger | `http://jaeger:16686` | Query HTTP. `jaeger:4317` to gRPC ze spanami; plugin Jaegera w Grafanie tego nie mówi. |

Bind `127.0.0.1:3000:3000` jest dla Ciebie. Grafana do Prometheusa i Jaegera używa sieci Compose i nie potrzebuje ich portów na hoście — tak samo jak 08 pisało o `16686`. Z laptopa:

```bash
ssh -L 3000:127.0.0.1:3000 deploy@IP_VM
```

Potem `http://127.0.0.1:3000`. Tunel Cloudflare zostaje przy `4200`. Metryki `up` i lista tras z Jaegera nie są stroną huba.

Obraz w przepisie to `grafana/grafana:13.2.2`. Wersja 11.5.2 jest po EOL i jest podatna na CVE-2025-4123 (pierwsza łatka tej linii to 11.5.4+security-01; wspierana linia to 13.2). Pluginy Prometheus i Jaeger są w tym obrazie. Od Grafany 13.2 datasource Jaegera jest preinstalowanym, samodzielnym pluginem, ale domyślnie nadal używa endpointów v1; `/api/v3` wymaga jawnego włączenia eksperymentalnej flagi `jaegerEnableGrpcEndpoint`. Dlatego obecny pin Jaegera 2.20 pozostaje istotny. Osobnego `grafana-cli plugins install` nie ma.

### Pliki, które Grafana czyta przy starcie

Dwa mounty z `infra/docker/docker-compose.yml`. Ścieżka `../grafana` jest względem pliku Compose (`infra/docker/`), nie względem katalogu, z którego wołasz `docker compose`.

| W kontenerze | Na hoście | Kiedy się odświeża |
| --- | --- | --- |
| `/etc/grafana/provisioning` | `infra/grafana/provisioning` | Datasource: po **restarcie** kontenera. Sama edycja YAML na dysku nie przebija działającego procesu. |
| `/var/lib/grafana/dashboards` | `infra/grafana/dashboards` | Provider co `updateIntervalSeconds` (w przepisie 30). JSON da się podmienić bez restartu. |
| `/var/lib/grafana/grafana.db` | volume `grafana_data` | Użytkownicy, sesje, hasło admina. Dashboard z gita tu nie mieszka jako źródło prawdy. |

Oba mounty plików są `:ro`. Grafana nie zapisze eksportu z UI z powrotem do repo. Ściągasz JSON (Export) i commitujesz sam.

Gdy zamontujesz tylko `provisioning`, datasource wstaną, a folder JJDevHub będzie pusty: provider wskazuje `/var/lib/grafana/dashboards`, a ten katalog jest drugim mountem. Odwrotnie (sam JSON, bez YAML providera) plik na dysku Grafana ignoruje.

`grafana_data` musi być do zapisu. Named volume to załatwia. Bind `:ro` na dashboardach jest celowy.

### YAML datasource, pole po polu

| Pole | Sens w tym pliku |
| --- | --- |
| `apiVersion: 1` | Format provisioningu. Zostaje 1. |
| `name` | Napis na liście (Prometheus, Jaeger). |
| `type` | `prometheus` albo `jaeger`. Literówka = plugin się nie ładuje. |
| `uid` | Stały identyfikator. JSON dashboardu wskazuje `uid`, nie `name`. Zmiana UID bez poprawki JSON daje panel „datasource not found”. |
| `access: proxy` | Zapytanie leci z kontenera Grafany. |
| `url` | Adres widziany z tej sieci. Bez końcowego ukośnika, bez `/metrics` (ścieżkę scrapa dokleja Prometheus w 07, nie datasource). |
| `isDefault: true` | Tylko przy Prometheusie. Nowy panel w UI bierze go, gdy nie wybierzesz innego. |
| `editable: false` | Formularza w UI nie zmienisz. Poprawka idzie w git i restart. **Save & test** dalej działa. |

Test z UI wykonuje się w kontenerze `jjdevhub-grafana`. Zielony test to DNS + port + żywy backend. Czerwony „connection refused” przy poprawnym URL zwykle znaczy, że Prometheus albo Jaeger jeszcze nie słuchają (`depends_on` bez healthchecka puszcza Grafanę od razu po starcie kontenerów). Kolejne zapytanie po minucie już przejdzie; proces Grafany nie trzeba z tego powodu restartować, o ile YAML się nie zmienił.

### Provider dashboardów

`dashboards.yml` nie zawiera wykresów. Mówi: co 30 s czytaj JSON-y z katalogu, wrzuć je do folderu **JJDevHub**, org `1` (domyślna organizacja).

`allowUiUpdates: false` robi z provisioned dashboardu widok tylko do odczytu. **Save** na „JJDevHub API overview” nie zostanie. Kliknięcia sprzed 30 s i tak nadpisałby plik z gita. Bogatszą wersję składasz tak:

1. New → Dashboard (to już nie jest ten z pliku; żyje w `grafana.db`).
2. Albo chwilowo `allowUiUpdates: true`, edycja, eksport, powrót do `false`.
3. Share → Export → Save to file. Wklejasz JSON do `infra/grafana/dashboards/jjdevhub-api-overview.json`.
4. Czekasz do 30 s albo odświeżasz stronę. Provider podmienia dashboard o tym samym `uid`.

`disableDeletion: false` znaczy: zniknięcie pliku z katalogu usuwa **provisioned** dashboard przy następnym pollu. Dashboard złożony tylko w UI, bez pliku, zostaje w volume. Restart Grafany go nie kasuje. Restart z `docker volume rm` volume’a już tak — pliki z gita wrócą, klikane bez eksportu nie.

Pole `editable: true` w JSON przegrywa z `allowUiUpdates: false`. Wygrywa provider.

### JSON z kroku 4

Szkielet ma jeden panel `timeseries`. `datasource.uid` i `targets[].datasource.uid` to `prometheus`. Sam `expr` bez UID potrafi wziąć zły domyślny source, gdy kiedyś dodasz drugi Prometheus.

`up{job="jjdevhub-api"}` pasuje do `job_name` z [07-prometheus.md](07-prometheus.md). Etykieta `instance` będzie `api:8080` (target scrapa). Dodatkowa etykieta `service="jjdevhub-api"` jest z `static_configs` tamtego pliku; filtr `job` wystarcza, dopóki job jest jeden.

`up` dokłada sam Prometheus, nie aplikacja:

- `1` — ostatni scrape `/metrics` się udał,
- `0` — target jest na liście, scrape padł (zły port, proces nie żyje, path inny niż `/metrics`).

Publiczny `curl` na `https://hub…/health` może być zdrowy, a `up` równe 0, bo nginx nie proxy’uje `/metrics`, a Prometheus bije w `api:8080` od środka. Odwrotnie: `up` równe 1 nie mówi, czy login zwraca 200. Do tego jest histogram albo span w Jaegerze.

`id: null` w JSON jest poprawne. Grafana nadaje numeryczne id w swojej bazie. `uid: jjdevhub-api-overview` zostawiasz stabilne — po nim działa link i podmiana pliku. `schemaVersion: 39` jest starsze niż Grafana 13. Obraz `13.2.2` ten plik czyta przy provisioningu; schema podbija się przy zapisie z UI, a ten dashboard i tak jest tylko do odczytu (`allowUiUpdates: false`).

Zakres `now-1h` w JSON to domyślne okno po otwarciu dashboardu. Próbki `up` pojawiają się w kilkanaście sekund od pierwszego scrapa (15 s w 07), nie po godzinie.

Nazwy histogramu HTTP zależą od semconv, o czym jest 06 i 07. W PromQL spotkasz albo starsze `http_server_duration_seconds_*`, albo `http_server_request_duration_seconds_*`. Zanim wkleisz `rate(...)` do panelu, zobacz surową nazwę w `http://127.0.0.1:5080/metrics` albo w UI Prometheusa. Potem na przykład:

```promql
sum(rate(http_server_request_duration_seconds_count{job="jjdevhub-api"}[5m]))
```

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(http_server_request_duration_seconds_bucket{job="jjdevhub-api"}[5m])
  )
)
```

`rate` na counterze albo `_count` / `_bucket` histogramu. Nie na `up` i nie na gauge aktywnych requestów. Okno `[5m]` przy scrapie co 15 s ma z czego liczyć; `[10s]` często wyjdzie puste.

### Hasło admina i volume

`GF_SECURITY_ADMIN_PASSWORD` obowiązuje przy **pierwszym** starcie, gdy `grafana.db` jeszcze nie ma. Compose nie podstawia hasła, gdy zmienna jest pusta albo jej nie ma — `up` wtedy pada na interpolacji. Na VM hasło jest z `openssl rand -base64 24` w `/etc/jjdevhub/api.env`, nie w git. Lokalny lab używa tego samego mechanizmu (`infra/docker/.env`).

Zmiana tej zmiennej przy istniejącym volume **nie** zmienia hasła. Zostaje to z pierwszego bootu. Rotacja:

```bash
docker exec -it jjdevhub-grafana grafana-cli admin reset-admin-password 'nowe-haslo'
```

Albo skasowanie volume `grafana_data` (znikają użytkownicy i dashboardy klikane tylko w UI; JSON z gita wraca po starcie) i ponowny `up` już z nowym env.

`GF_USERS_ALLOW_SIGN_UP=false` wyłącza rejestrację. Anonimowego dostępu nie włączasz (`GF_AUTH_ANONYMOUS_ENABLED` zostaje nieustawione). `GF_SERVER_ROOT_URL` to `https://grafana.jjdevhub.com/` — korzeń własnego hostname'a, nie ścieżka pod hubem.

Hasło ląduje w środowisku procesu. `docker inspect jjdevhub-grafana` je pokaże. To ten sam model co `Jwt__Key` w kontenerze API: sekret na VM, nie w repozytorium.

### Gdy wynik jest zły

| Objaw | Co sprawdzić |
| --- | --- |
| `curl` na `:3000` z VM nie łączy | Bind, `docker logs jjdevhub-grafana`, czy `up` w ogóle stworzył kontener. Z laptopa bez SSH tak ma być. |
| Login odrzuca hasło z aktualnego `api.env` | Volume powstał przy innym haśle (pierwszy boot). Reset `grafana-cli` albo nowy volume. |
| Save & test: lookup `prometheus` | URL z `127.0.0.1` albo z `container_name`. Ma być `http://prometheus:9090`. |
| Save & test: connection refused | Backend jeszcze nie słucha albo zły port (`9090` vs `8080`, Jaeger `16686` vs `4317`). |
| Datasource zielony, folder JJDevHub pusty | Brak drugiego mountu na `/var/lib/grafana/dashboards` albo zły `path` w providerze. |
| Dashboard jest, panel „No data” | Zakres czasu, literówka w `job`, scrape w 07 nie jest UP. W Prometheusie to samo zapytanie mówi, czy wina jest w Grafanie, czy niżej. |
| Panel „datasource not found” | `uid` w JSON ≠ `uid` w YAML. |
| Edycja w UI znika po pół minucie | `allowUiUpdates: false` i poll pliku. Eksport do gita, nie Save na provisioned dashboardzie. |
| Po restarcie Grafany znika dashboard złożony tylko klikaniem | Był w `grafana.db`. Bez JSON w `infra/grafana/dashboards/` deploy na świeży volume go nie ma. |
| Explore Jaeger puste, Prometheus żyje | To droga z 08: endpoint OTLP, batch, `service.name`, pamięć Jaegera po restarcie. Grafana tu nic nie scrapuje. |
| W Explore jest span, na wykresie nie ma RPS | Panel z kroku 4 rysuje tylko `up`. `rate(...)` dokładasz osobnym panelem, po sprawdzeniu nazwy metryki. |
| `up` = 0, a `/health` na `:4200` działa | Scrape nie dochodzi do `api:8080/metrics`. Nginx i health tego nie naprawiają. |

### Typowe pomyłki

1. **`0.0.0.0:3000` albo Public Hostname na Grafanę.** Konto admina i mapa requestów na zewnątrz. Zostaje loopback i SSH.
2. **Domyślne hasło w Compose**, gdy w env brak `GRAFANA_ADMIN_PASSWORD`. Przepis używa `${GRAFANA_ADMIN_PASSWORD:?…}` — brak sekretu zatrzymuje `up`, nie wpuszcza znanego hasła.
3. **Wiara, że nowy `GRAFANA_ADMIN_PASSWORD` sam wejdzie.** Bez pustego volume albo `grafana-cli` zostaje stare.
4. **Datasource `http://127.0.0.1:9090` albo `http://jaeger:4317`.** Pierwsze to loopback Grafany. Drugie to gRPC, nie query UI.
5. **`access: direct`.** Przeglądarka szuka Dockera po swojej stronie.
6. **Jeden mount.** Albo są źródła bez dashboardu, albo pliki JSON, których provider nie widzi.
7. **Save w UI traktowany jak git.** Przy `allowUiUpdates: false` i tak wygrywa plik. Eksport, commit, poll 30 s.
8. **„Grafana scrapuje co 15 s”.** Co 15 s scrape robi Prometheus. Grafana odpytuje go, gdy otwierasz wykres.
9. **OTLP wysłane do Grafany.** Spany kończą się na Jaegerze. Ten kontener ich nie przyjmuje.
10. **Klik z panelu `up` w trace.** Tego połączenia przepis nie robi. Explore albo osobny panel.
11. **`rate(up[5m])` jako RPS.** `up` to gauge scrapa. Tempo requestów bierzesz z `_count` histogramu, którego nazwę sprawdzasz w `/metrics`.
12. **Job `jjdevhub` zamiast `jjdevhub-api`.** Etykieta jest z `job_name` w `prometheus.yml`.
13. **Anonimowy dostęp „żeby nie logować się przez SSH”.** Wtedy każdy, kto dosięgnie portu, czyta metryki. Port i tak zostaje na loopbacku, konto zostaje.
14. **Alert rule w tym kroku, z tokenem Slacka w repo.** Najpierw zielony datasource i panel `up`. Powiadomienia to osobna konfiguracja, nie ten numer.
15. **Zostawienie `grafana/grafana:11.5.2`, bo „tak jest w starej notatce”.** Ta linia jest po EOL i bez łatki CVE-2025-4123. Pin w Compose to `13.2.2`. Pusty panel to zapytanie albo scrape, nie powód, żeby cofać obraz.

### Oficjalne źródła

- Grafana docs: *Provisioning*, *Provision data sources*, *Provision dashboards*, zmienne `GF_SECURITY_*` i `GF_USERS_ALLOW_SIGN_UP`.
- Dokumentacja datasource Prometheus i Jaeger (URL query to port UI Jaegera, tryb proxy).
- PromQL: `up`, `rate`, `histogram_quantile` — oraz nazwy metryk z [07-prometheus.md](07-prometheus.md), po sprawdzeniu faktycznego `/metrics`.

### Co zapamiętać

Grafana w tym Compose to UI na `127.0.0.1:3000`, które po sieci Dockera czyta `prometheus:9090` i `jaeger:16686`. Dashboard z gita pokazuje, czy scrape API żyje. Trace tego samego loginu jest w Explore, jednym spanem HTTP, bez SQL-a. Hasło admina zapisuje się raz, w volume. Powtarzalny deploy to YAML i JSON w `infra/grafana/`, nie kliknięcia w `grafana.db`.
