# Jaeger — trace z API po OTLP gRPC

## Po co

Po [06-opentelemetry.md](06-opentelemetry.md) API potrafi wysyłać spany, a po [07-prometheus.md](07-prometheus.md) ma metryki. Bez odbiornika tras nie zobaczysz spana HTTP (`GET /health`, `POST /api/auth/login`). Prometheus tego widoku nie zastępuje. Osobnego spana SQL jeszcze nie ma — instrumentacja EF nie weszła w 06.

## Dlaczego ta technologia

### Jaeger all-in-one zamiast osobnego magazynu

Jaeger zapisuje trace: drzewo spanów jednego żądania, z czasami i atrybutami. Obraz `jaegertracing/jaeger` w tym Compose to jeden proces: collector OTLP gRPC na 4317 w sieci Dockera, pamięć procesu i UI na 16686. Osobny collector, Cassandra albo Elasticsearch przegrały: ten hub nie ma ruchu, przy którym pamięć procesu przestaje wystarczać. Tempo i Grafana Cloud przegrały w tym numerze, bo dokładają konto albo drugi składnik, a OTLP z 06 i tak jest wymienialny adresem. Koszt: restart kontenera kasuje historię, a UI zostaje na loopbacku VM (`127.0.0.1:16686`). To nie jest baza metryk ani miejsce na linie `ILogger`.

## Co już jest w repo

- VM, Docker i `docker compose` — [01-proxmox.md](01-proxmox.md), katalog `/opt/jjdevhub`, sekrety w `/etc/jjdevhub/api.env`
- Tunel Cloudflare: hub na `127.0.0.1:4200`, UI Jaegera na `https://jaeger.jjdevhub.com/` → `127.0.0.1:16686` — [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md). OTLP `4317` zostaje tylko w sieci Compose
- Deploy self-hosted runnerem — [03-github.md](03-github.md), skrypt [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) woła `docker compose … -f infra/docker/docker-compose.yml up -d --build`
- Instrumentacja OTLP w API — [06-opentelemetry.md](06-opentelemetry.md). Endpoint eksportera ustawiasz zmiennymi środowiskowymi kontenera `api`
- Scrape metryk — [07-prometheus.md](07-prometheus.md). Usługa `prometheus` w Compose; Jaeger jej nie zastępuje i nie trzyma szeregów czasowych

Obecne usługi w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml): `db` (`jjdevhub-db`), `api` (`jjdevhub-api`), `web` (`jjdevhub-web`). Po 07 dochodzi `prometheus`. Ten plik dodaje `jaeger` (`jjdevhub-jaeger`).

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie tu |
| --- | --- |
| Trace | Jedno żądanie (lub operacja) jako drzewo spanów z jednym `trace_id` |
| Span | Jednostka pracy (np. HTTP request, zapytanie SQL) z czasem start/stop |
| OTLP | OpenTelemetry Protocol — format i transport telemetrii |
| OTLP gRPC | OTLP po gRPC; w tym Jaegerze port **4317** wewnątrz sieci Dockera |
| Jaeger | Backend i UI do wyszukiwania i przeglądania traców. Tu jeden proces v2: collector, query i UI |
| `max_traces` | Sufit liczby trace’ów w magazynie pamięci. Stoi w [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml), nie w zmiennej środowiska |

## Kroki

### 1. Usługa `jaeger` w Compose

Dopisz do [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) obok `api` / `prometheus` (nie zamiast nich):

```yaml
  jaeger:
    image: jaegertracing/jaeger:2.20.0
    container_name: jjdevhub-jaeger
    command: ["--config", "/etc/jaeger/config.yaml"]
    volumes:
      - ../jaeger/config.yaml:/etc/jaeger/config.yaml:ro
    ports:
      - "127.0.0.1:16686:16686"
    # 4317 nie publikuj na hoście — api łączy się po nazwie usługi w sieci Compose
    restart: unless-stopped
```

Obraz to binarka Jaegera v2, nie `jaegertracing/all-in-one`. v1 jest po EOL. Nie ustawiaj `COLLECTOR_OTLP_ENABLED` ani `MEMORY_MAX_TRACES` — v2 ich nie czyta. OTLP i limit śladów są w [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml): odbiornik gRPC `0.0.0.0:4317`, UI `0.0.0.0:16686`, magazyn `memory.max_traces: 10000`.

Pin **2.20.0** wynika również ze zgodności z domyślną konfiguracją Grafany 13.2. Datasource Jaegera używa `/api/services`, dopóki eksperymentalna flaga `jaegerEnableGrpcEndpoint` nie zostanie jawnie włączona; ten Compose jej nie ustawia. Jaeger 2.21 usuwa endpointy v1, więc upgrade wymaga najpierw włączenia i sprawdzenia ścieżki `/api/v3`. Samo `200` na `16686` nie dowodzi, że 4317 przyjmuje spany.

UI tylko na loopback VM. LAN i internet nie powinny widzieć `16686`. Tunel Cloudflare tego hosta nie dostaje.

### 2. API → Jaeger po OTLP gRPC

W sekcji `api` dopisz zmienne (nazwy zgodne z [06-opentelemetry.md](06-opentelemetry.md); jeśli 06 użyło innych kluczy, trzymaj jedną konwencję):

```yaml
    environment:
      # … istniejące ConnectionStrings__, Jwt__, ASPNETCORE_ENVIRONMENT …
      OTEL_SERVICE_NAME: ${OTEL_SERVICE_NAME:-JJDevHub.Api}
      OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://jaeger:4317}
      OTEL_EXPORTER_OTLP_PROTOCOL: ${OTEL_EXPORTER_OTLP_PROTOCOL:-grpc}
```

Nazwy zmiennych jak w [06-opentelemetry.md](06-opentelemetry.md) (`JJDevHub.Api`). Na VM w `/etc/jjdevhub/api.env` ustaw `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317` (puste w pliku env i tak dostaje ten adres z `:-` w Compose). Ta zmienna karmi **tylko eksporter tras**. Nie ustawiaj `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` ani `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` na `http://jaeger:4317` — ten Jaeger odrzuca te sygnały, a SDK będzie je ponawiać. Metryki zbiera Prometheus (07). Logi OTLP włączasz adresem collectora, który logi przyjmuje. Sam Jaeger nie bierze sekretu z `api.env`.

`depends_on` na `jaeger` dodaj tylko jeśli chcesz kolejność startu; eksporter i tak buforuje przy krótkim braku collectora. Nie kieruj OTLP na `prometheus` ani na host `127.0.0.1` z wnętrza kontenera `api` — z sieci Compose host loopback to nie Jaeger.

Przykład bloku `api` po zmianie (skrót — zachowaj resztę z pliku):

```yaml
  api:
    build:
      context: ../..
      dockerfile: infra/docker/Dockerfile
    container_name: jjdevhub-api
    ports:
      - "127.0.0.1:5080:8080"
    environment:
      ASPNETCORE_ENVIRONMENT: ${ASPNETCORE_ENVIRONMENT:-Production}
      ConnectionStrings__DefaultConnection: Host=db;Port=5432;Database=${POSTGRES_DB};Username=${POSTGRES_USER};Password=${POSTGRES_PASSWORD}
      Jwt__Issuer: ${JWT_ISSUER:-JJDevHub}
      Jwt__Audience: ${JWT_AUDIENCE:-JJDevHub}
      Jwt__Key: ${JWT_KEY}
      Jwt__ExpiryMinutes: ${JWT_EXPIRY_MINUTES:-60}
      OTEL_SERVICE_NAME: ${OTEL_SERVICE_NAME:-JJDevHub.Api}
      OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-http://jaeger:4317}
      OTEL_EXPORTER_OTLP_PROTOCOL: ${OTEL_EXPORTER_OTLP_PROTOCOL:-grpc}
    depends_on:
      db:
        condition: service_healthy
      jaeger:
        condition: service_started
```

### 3. Lokalnie i na VM

Lokalnie (sekrety z `infra/docker/.env` albo skopiowanego przykładu):

```bash
cd /home/jakubj/git/JJDevHub   # albo Twój klon
docker compose --env-file infra/docker/.env -f infra/docker/docker-compose.yml up -d --build
```

Na VM (ścieżki z 01):

```bash
cd /opt/jjdevhub
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml up -d --build
```

Deploy przez runner i tak przebuduje Compose — wystarczy commit na `main` po zielonym CI ([03-github.md](03-github.md)). Zły [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml) albo provisioning Grafany wywala wcześniej [infra/ci/observability-smoke.sh](../../infra/ci/observability-smoke.sh) w jobie `api`. Na VM skrypt deployu, zanim zapisze SHA, jeszcze raz pyta `127.0.0.1:16686` i `127.0.0.1:5080/health`. Obraz Jaegera nie ma czym zrobić healthchecka w środku kontenera.

### 4. Wygeneruj ruch

```bash
curl -fsS http://127.0.0.1:4200/health
curl -s -X POST http://127.0.0.1:4200/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"Password1"}'
```

### 5. Tunel — nic nie zmieniaj

W [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md) hub zostaje `http://127.0.0.1:4200`. UI Jaegera to osobny hostname `jaeger.jjdevhub.com` → `127.0.0.1:16686`. `4317` do tunelu nie wchodzi.

## Jak sprawdzić, że działa

Na VM lub laptopie z mapowaniem portu:

```bash
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml ps
curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:16686/
```

Oczekiwane: kontener `jjdevhub-jaeger` działa, UI zwraca `200`. W przeglądarce (SSH tunnel albo lokalnie): `http://127.0.0.1:16686` → Service `JJDevHub.Api` → Find Traces → widać spany po `curl` na `/health` lub login.

Sprawdź, że **nie** ma hostname Cloudflare na Jaegera:

```bash
# z innej sieci niż LAN VM — ma się nie udać / nie być opublikowane
curl -fsS "https://hub.example.com:16686/" && echo 'ŹLE: UI w tunelu'
```

Prometheus (`http://127.0.0.1:9090`) nadal osobno; Jaeger nie listuje metryk `http_*` jak Prometheus.

## Czego w tym pliku nie ruszać

- Nie wystawiaj `16686` ani `4317` jako `0.0.0.0` ani przez Cloudflare
- Nie łącz OTLP traców z Prometheusem — metryki zostają w 07
- Nie zmieniaj Public Hostname tunelu ani nginx (`src/Clients/web/nginx.conf`) pod Jaegera
- Nie kasuj usług `db`, `api`, `web`, `prometheus`
- Nie przenoś Jaegera poza Compose „na razie” — ten krok ma ten sam plik co reszta stacku
- Nie edytuj [04-codeql.md](04-codeql.md), [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md) ani wcześniejszych numerów w ramach tego kroku

## Następny numer

[09-grafana.md](09-grafana.md) — Grafana czyta Prometheusa i Jaegera, dashboardy jako kod w `infra/grafana/`.

---

## Pełny tutorial: Jaeger (od zera)

Czym jest Jaeger all-in-one, jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostaje, co zobaczysz w UI po `curl`. Przepis Compose jest wyżej. Nie dodajesz tu Prometheusa, Grafany ani instrumentacji EF.

### Co realnie widać po tym kroku

Weź `POST /api/auth/login` z kroku 4. W UI jest **jeden** span serwerowy:

- usługa `JJDevHub.Api` (`OTEL_SERVICE_NAME` / `AddService` z 06),
- operacja w rodzaju `POST /api/auth/login` albo `GET /health`,
- czas paska = całe żądanie, łącznie z Identity i Postgresem,
- atrybuty metody, szablonu trasy i kodu statusu.

Dziecka „SELECT” nie będzie. Pakiet EF nie jest w kroku 06, więc czas bazy siedzi w środku paska HTTP. `HttpClient` w tym API też nikt nie woła. Brak drzewa nie oznacza zepsutego Jaegera.

`curl` na login może zwrócić 401, gdy użytkownika nie ma. Span i tak powstaje. Kod procesu `curl` i pusta lista w Jaegerze to dwa różne objawy.

`GET /health` przez nginx (`4200`) też daje span. Healthcheck kontenera `web` bije w `/` nginxu, nie w API — z niego spana nie będzie.

### Droga spana

1. Kestrel obsługuje request. Instrumentacja ASP.NET otwiera `Activity`.
2. SDK .NET **nie** wysyła spana od razu. Batch (domyślnie okolice 5 s, `OTEL_BSP_SCHEDULE_DELAY` z 06) zbiera paczkę. `curl` i natychmiastowe odświeżenie UI często trafia w pustkę; odczekaj kilka sekund. `docker stop` robi flush, `docker kill` gubi ostatnią porcję.
3. Eksporter pcha OTLP gRPC na `http://jaeger:4317`. Schemat `http://` znaczy „bez TLS”. `https://` albo ścieżka `/v1/traces` na tym adresie psuje gRPC — `/v1/traces` należy do OTLP po HTTP, port **4318**.
4. Collector dokleja span do storage. Sampling jest po stronie SDK, nie Jaegera: w 06 zostaje 100%, więc collector dostaje każde żądanie, które doszło do Kestrela.
5. UI czyta ten sam storage. Dropdown **Service** napełnia się z tego, co już przyszło. Pusty dropdown przy żywym UI znaczy „nic nie dotarło”, nie „Jaeger padł”.

`ASPNETCORE_ENVIRONMENT=Production` tej ścieżki nie wyłącza. Rejestracja OTel z 06 nie jest owinięta w `IsDevelopment()`.

### Porty

Proces słucha w kontenerze więcej, niż publikujesz. Thrift i Zipkin w tym `config.yaml` nie są włączone:

| Port | Po co | W tym Compose |
| --- | --- | --- |
| 4317 | OTLP gRPC | Zostaje w sieci Compose. API woła nazwę `jaeger`. Na hoście go nie ma. |
| 4318 | OTLP HTTP | Słucha w sieci Compose (jest w `config.yaml`). API go nie używa. Na hoście go nie ma. |
| 16686 | UI i API query | `127.0.0.1:16686:16686`. Z laptopa przez tunel SSH, nie z internetu. |
| 6831 / 6832 UDP | Stary agent Jaeger (Thrift) | Nie włączasz. SDK mówi OTLP. |
| 14268, 14250, 9411 | Jaeger Thrift, model proto, Zipkin | To samo: zamknięte. |

Publikacja `4317` na `0.0.0.0` pozwala każdemu w LAN wstrzyknąć fałszywy trace. UI na `0.0.0.0` oddaje mapę wywołań API. Przepis zostawia zapis w Dockerze, a odczyt na loopbacku VM. Tunel Cloudflare ([02-cloudflare-tunnel.md](02-cloudflare-tunnel.md)) dalej ma jeden origin, `127.0.0.1:4200`.

[09-grafana.md](09-grafana.md) zapyta Jaegera po DNS Compose (`http://jaeger:16686`). Do tego nie potrzebuje portu opublikowanego na hoście. `127.0.0.1:16686` jest dla Ciebie, nie dla Grafany.

OTLP włącza receiver w [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml), nie flaga `COLLECTOR_OTLP_ENABLED` z v1. Samo `200` na `16686` nie dowodzi, że 4317 przyjmuje spany. Kontener bez tego mountu albo ze starym obrazem `all-in-one` to inny Jaeger niż ten w repo.

### Pamięć i restart

Magazyn to `memory` w [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml). Spany żyją w procesie. Restart `jjdevhub-jaeger`, `compose up` od zera albo reboot VM czyści historię. Volume nic nie utrwali, dopóki storage nie pisze na dysk. `compose down -v` nie jest tu warunkiem utraty — nie ma czego odpiąć.

VM z [01-proxmox.md](01-proxmox.md) ma 4096 MB. API próbuje każdy request, a Prometheus co 15 s scrapuje `/metrics` i też zostawia ślad. Dlatego `max_traces: 10000` — trochę ponad doba samego scrapa, rząd wielkości ~100 MB. v1 wołało to `MEMORY_MAX_TRACES` albo `--memory.max-traces`. v2 tej zmiennej nie czyta. Podnosisz liczbę w YAML i odtwarzasz kontener.

Trwały dysk jest poza tym krokiem. W v2 to inny backend w `config.yaml`, nie `SPAN_STORAGE_TYPE` / `BADGER_*` w `environment`. Cassandra albo Elasticsearch to już inny rozmiar klastra.

### Compose, nazwa usługi, plik na VM

Kontener nazywa się `jjdevhub-jaeger`. Usługa Compose nazywa się `jaeger`. DNS w sieci projektu rozwiązuje **nazwę usługi**, więc endpoint to `http://jaeger:4317`, nie `http://jjdevhub-jaeger:4317` i nie adres IP z `docker inspect`.

`127.0.0.1` w środowisku kontenera `api` to sam kontener API. Ten adres jest prawdziwy tylko przy `dotnet run` na hoście, gdy Jaeger ma opublikowany `4317` — a przepis go nie publikuje. Z laptopa do UI używasz `127.0.0.1:16686`, bo ten jeden port jest zbindowany na hoście.

W 06 domyślna wartość w Compose bywała pusta (`${OTEL_EXPORTER_OTLP_ENDPOINT:-}`). W tym pliku domyślna to `http://jaeger:4317`. **Podmień** tamtą linię. Druga linia z tym samym kluczem w YAML: zostaje ta późniejsza, a pierwsza cicho myli przy czytaniu.

`${OTEL_EXPORTER_OTLP_ENDPOINT:-http://jaeger:4317}` wstawia adres, gdy zmienna jest nieustawiona albo pusta. Pusty wpis z 06 w `/etc/jjdevhub/api.env` przy tej składni i tak da `http://jaeger:4317`. Jawne `OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4317` w tym pliku jest czytelniejsze: nie zależy od `:-`.

Sam `api.env` nie wchodzi do procesu. `docker compose --env-file` podstawia wartości pod `${...}` w pliku Compose. Klucz musi być w bloku `environment:` usługi `api`. Dopisanie linii tylko na VM, bez Compose, nic nie eksportuje.

`depends_on` z `service_started` (tak jest w przykładzie kroku 2) ustawia kolejność tworzenia kontenerów. Nie czeka, aż 4317 naprawdę słucha — Jaeger nie ma tu healthchecka. Eksporter .NET przy krótkiej dziurze ponawia. API i tak wstaje dzięki `db` (`service_healthy`). Pierwsze spany tuż po `compose up` mogą zginąć; `/health` minutę później już nie.

### Jak czytać UI

Wejście: `http://127.0.0.1:16686` na maszynie, gdzie port jest zbindowany. Z laptopa na VM:

```bash
ssh -L 16686:127.0.0.1:16686 user@vm
```

Potem ta sama przeglądarka, `http://127.0.0.1:16686`. Nie otwieraj Jaegera hostname’em z tunelu Cloudflare.

1. **Service** — `JJDevHub.Api`. Inna nazwa znaczy, że do collectora doszedł inny `service.name` (literówka w env wygrywa z tym, co masz w głowie).
2. **Operation** — `POST /api/auth/login` albo `GET /health`. Puste „all” pokaże oba, jeśli oba doszły.
3. **Lookback** — okno względem zegara Jaegera. Domyślna godzina wstecz nie pokaże trace’u sprzed wczoraj, ani trace’u z przyszłości, gdy zegar VM jest zły (`date` na hoście).
4. **Tags** — filtr w stylu `http.response.status_code=401` albo starsze `http.status_code=401`, zależnie od semconv z 06. `error=true` łapie spany oznaczone jako błąd. 401 z loginu bywa zwykłym statusem HTTP, bez czerwieni „wyjątek”.
5. **Min / Max duration** — odcinają szybki `/health`, gdy szukasz wolnego loginu.
6. Oś czasu — szerokość to czas. Jedno dziecko pod spodem pojawi się dopiero po własnym `ActivitySource` albo po instrumentacji EF. Dziura w pasku bez dziecka to praca w tym procesie (baza, hasło, JWT), nie zgubiony span.
7. **Tags** spana — metoda, route, status. Brak `db.statement` jest oczekiwany. Email, hasło i `Jwt__Key` nie powinny tu być; jeśli są, wyleciały z tagu, który ktoś dopisał w kodzie.
8. **Process** — atrybuty resource (`service.name`, `service.instance.id`). Nowy `instance.id` po restarcie API to ten sam serwis, nie drugi produkt.

Dwa trace’e tego samego loginu porównujesz z listy (zaznaczenie i compare, jeśli ta wersja UI je ma). Różnica szerokości bez dzieci mówi „ten request był dłuższy”, nie „winny jest Postgres”. Do winy bazy potrzebny span SQL albo metryka z 07.

Zakładka zależności / architektury przy jednym serwisie jest pojedynczym kółkiem. To poprawny obraz, nie zepsuty collector.

### Gdy wynik jest zły

| Objaw | Co sprawdzić |
| --- | --- |
| `jjdevhub-jaeger` nie ma na liście `ps` | Usługa nie weszła do Compose, który naprawdę odpaliłeś (inny plik, stary checkout na VM w `/opt/jjdevhub`). |
| Kontener w kółko pada | Zły YAML albo brak mountu `../jaeger/config.yaml`. `docker logs jjdevhub-jaeger`. Nie podmieniaj obrazu na `jaegertracing/all-in-one`. |
| `curl` na `127.0.0.1:16686` z VM nie łączy | Bind nie jest na loopbacku albo kontener padł. `docker logs jjdevhub-jaeger`. Obraz często nie ma `wget` w środku — sprawdzaj z hosta. |
| UI z laptopa nie wchodzi, z VM wchodzi | Tak ma być bez tunelu SSH. `16686` nie jest na LAN. |
| UI `200`, dropdown Service pusty | Nic nie doszło na 4317. Endpoint API, protokół `grpc`, czy API w ogóle dostało zmienną (blok `environment`, nie tylko komentarz w `api.env`). |
| W logu API retry do `127.0.0.1:4317` | Eksporter celuje w loopback kontenera `api`. Ma być `http://jaeger:4317`. |
| UI puste tuż po `curl` | Batch. Odczekaj kilka sekund i poszerz lookback. |
| Jest tylko `GET /health` | Login nie doszedł do tego procesu albo filtr Operation go odcina. 401 z `curl` spana nie kasuje. |
| Span jest, bez SQL | Zgodne z 06. Czas bazy jest w pasku HTTP. |
| Po restarcie Jaegera historia zniknęła | Storage `memory`. Tak działa ten przepis. |
| Trace „z przyszłości” albo lookback pusty mimo ruchu | Zegar VM. |
| Dwa serwisy w dropdownie | Drugi `service.name` (został domyślny `unknown_service` z runu bez `AddService`, albo inny env). |
| Metryk `http_*` w Jaegerze nie ma | Ich tu nie będzie. Wykres jest w Prometheusie (`127.0.0.1:9090`). |

### Typowe pomyłki

1. **`0.0.0.0:16686` albo hostname w tunelu.** Mapa requestów API na zewnątrz. Zostaje `127.0.0.1` i brak Public Hostname.
2. **Opublikowany `4317`.** Zapis trace’ów z LAN-u. API i tak łączy się po sieci Compose.
3. **`http://127.0.0.1:4317` w kontenerze `api`.** Loopback kontenera, nie Jaegera i nie hosta.
4. **Doklejona druga linia `OTEL_EXPORTER_OTLP_ENDPOINT` obok pustej z 06.** Zostaw jedną, z domyślną `http://jaeger:4317`.
5. **Wiara, że sam `api.env` bez klucza w Compose coś ustawia.** Interpolacja bierze plik tylko tam, gdzie jest `${...}`.
6. **Szukanie drzewa EF.** Jeden span HTTP to sukces tego kroku.
7. **Czytanie 401 z `curl` jako „Jaeger nie działa”.** Span z statusem 401 jest dowodem, że droga żyje.
8. **OTLP pchnięte na `prometheus:9090`.** Prometheus nie przyjmuje gRPC ze spanami.
9. **Stary transport 6831 / Zipkin „bo tutorial z sieci”.** Ten SDK mówi OTLP gRPC.
10. **`https://jaeger:4317` albo endpoint z `/v1/traces`.** gRPC: `http://`, host, port.
11. **Porównanie Jaegera z grafem RPS.** Rate i p95 są w 07. Jaeger odpowiada na „ten jeden request”.
12. **Remote sampling Jaegera (`SAMPLING_STRATEGIES_FILE`) przy pierwszym teście.** Decyzję i tak podejmuje SDK w API. Zostaw 100% z 06, aż zobaczysz trace.
13. **Wklejenie `SPAN_STORAGE_TYPE` / `BADGER_*` do usługi v2.** Te zmienne są z all-in-one. Ten kontener ich nie czyta. Limit jest `max_traces` w `config.yaml`.
14. **Oczekiwanie, że `depends_on` zaczeka na port.** `service_started` to kolejność kontenerów. Pierwsze sekundy po starcie mogą być puste.
15. **Powrót do `jaegertracing/all-in-one:1.66` albo `COLLECTOR_OTLP_ENABLED`.** To v1 po EOL, bez limitu śladów i bez tego `config.yaml`. Zostaje `jaegertracing/jaeger:2.20.0` i mount pliku.
16. **Podbicie do 2.21, bo nowszy tag.** Query gubi `/api/services`. Grafana 13 tego ścieżką szuka i Explore milknie, choć UI Jaegera żyje. Pin zostaje 2.20.0.
17. **Pamięć jako magazyn na miesiące.** Sufit to 10 000 trace’ów, restart i tak kasuje historię. Dłuższa historia to inny backend w YAML, nie kolejny bind portu.

### Oficjalne źródła

- Jaeger v2 docs: *Getting Started*, *Deployment*, *Configuration* (`jaeger_storage` / `memory.max_traces`). v1 (`all-in-one`, `COLLECTOR_OTLP_ENABLED`, `MEMORY_MAX_TRACES`) tego kontenera nie opisuje.
- Opis OTLP w collectorze: porty 4317 i 4318.
- OpenTelemetry: zmienne `OTEL_EXPORTER_OTLP_ENDPOINT` i `OTEL_EXPORTER_OTLP_PROTOCOL` — po stronie API, opisane w [06-opentelemetry.md](06-opentelemetry.md).

Tag w przepisie to `jaegertracing/jaeger:2.20.0`. 2.21 łamie API, którego używa Grafana. Podbijasz pin świadomie, nie „bo UI puste”.

### Co zapamiętać

Jaeger w tym Compose to jeden kontener v2: collector OTLP na `jaeger:4317` i UI na `127.0.0.1:16686`, config z [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml). API wysyła tam span HTTP, który 06 już umie zbudować. Widać login i `/health`, nie zapytanie SQL i nie wykres RPS. Historia siedzi w pamięci procesu, najwyżej 10 000 trace’ów, i znika z restartem. Tunel Cloudflare tego portu nie dostaje. Grafana czyta ten sam Jaeger po sieci Dockera (`http://jaeger:16686`).
