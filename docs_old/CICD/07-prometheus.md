# 07 — Prometheus

## Po co

Metryki z [06-opentelemetry.md](06-opentelemetry.md) powstają w procesie i nie mają gdzie się zbierać. Ten numer daje im odbiornik: co 15 sekund, w tym samym Compose, z UI tylko na `127.0.0.1`. Tunel z [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md) Prometheusa nie publikuje.

## Dlaczego ta technologia

### Prometheus i pull zamiast pusha

Prometheus (CNCF) sam robi GET na adres, który mu podasz, i składa bazę szeregów czasowych. API nie łączy się z nim: wystawia tekst pod `/metrics`. Martwy cel widać od razu, bo scrape nie wraca i metryka `up` spada do 0. Push z aplikacji do centrali przegrał: Jaeger nie przyjmuje metryk, a OTLP metryk w 06 idzie tylko na osobny adres, którego tu nie ma. Pushgateway przegrał, bo to nie jest jednorazowy job, tylko proces, który żyje. Koszt: scrape co 15 sekund, retencja na dysku kontenera i brak alertów — wykres na co dzień jest w Grafanie ([09-grafana.md](09-grafana.md)).

### Eksporter w procesie zamiast sidecaru

`AddPrometheusExporter` i `MapPrometheusScrapingEndpoint("/metrics")` w [src/api/Program.cs](../../src/api/Program.cs) otwierają czytnik na porcie, na którym API już nasłuchuje. Sidecar albo agent na hoście przegrał: dokładają drugi proces i drugą konfigurację, a tekst metryk i tak powstaje w tym samym procesie. Ścieżka bez JWT przegrała z pomysłem `RequireAuthorization`: job scrape nie ma tokenu, a 401 to target DOWN. Z zewnątrz VM jej nie ma, bo host publikuje `127.0.0.1:5080`, a nginx tej ścieżki nie proxy'uje. Koszt: oba wywołania muszą być naraz — sam eksporter nie otwiera portu, samo mapowanie bez eksportera daje pustkę.

## Co już jest w repo

- Compose bez Prometheusa: [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) — serwisy `db`, `api`, `web`; nazwy kontenerów `jjdevhub-db`, `jjdevhub-api`, `jjdevhub-web`.
- API nasłuchuje w kontenerze na `8080` (`ASPNETCORE_URLS`). Host mapuje `127.0.0.1:5080:8080` — port nie jest na wszystkich interfejsach. Bez tego bindu anonimowe `/metrics` czyta każdy, kto dosięgnie VM na `5080`, nawet gdy nginx i tunel tej ścieżki nie proxy’ują.
- nginx (`web`) proxy’uje `/api/`, `/health`, `/openapi/`, `/scalar` — **nie** `/metrics`. To nie zastępuje bindu loopback na porcie API.
- OTel (traces/metrics/logs + OTLP): [06-opentelemetry.md](06-opentelemetry.md).
- VM: [01-proxmox.md](01-proxmox.md). Deploy: [03-github.md](03-github.md).
- Pliku `infra/prometheus/` oraz serwisu `prometheus` w Compose jeszcze nie ma — to ten dokument.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie |
| --- | --- |
| Prometheus | System monitoringu: okresowy **scrape** celów HTTP, TSDB, język zapytań PromQL, UI na `:9090`. |
| Pull | Prometheus sam pyta `/metrics`; aplikacja nie pushuje do Prometheusa. |
| `/metrics` | Endpoint w formacie exposition (tekst Prometheus / OpenMetrics). |
| `scrape_interval` | Jak często pytać cel — tu **15s**. |
| Job / target | Konfiguracja w `prometheus.yml`: job_name + lista `targets` (`host:port` w sieci Dockera). |
| Bind `127.0.0.1` | Port widoczny tylko z VM/localhost, nie z LAN ani internetu. |

## Kroki

### 1. Eksporter Prometheus w API (scrape endpoint)

Dopisz pakiet (CPM + csproj), obok paczek z 06:

[Directory.Packages.props](../../Directory.Packages.props):

```xml
<PackageVersion Include="OpenTelemetry.Exporter.Prometheus.AspNetCore" Version="1.12.0-beta.1" />
```

(wersja beta bywa konieczna dla eksportera Prometheus AspNetCore — sprawdź nuget.org i użyj najnowszej zgodnej z resztą OTel 1.12.x).

[JJDevHub.Api.csproj](../../src/api/JJDevHub.Api.csproj):

```xml
<PackageReference Include="OpenTelemetry.Exporter.Prometheus.AspNetCore" />
```

W rejestracji metryk z 06 dodaj `.AddPrometheusExporter()` **zawsze** (nie tylko gdy OTLP jest ustawione):

```csharp
.WithMetrics(metrics =>
{
    metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddPrometheusExporter();
    if (metricsEndpoint is not null)
    {
        metrics.AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(metricsEndpoint);
        });
    }
});
```

Po `var app = builder.Build();` i pipeline’ie auth (albo zaraz po `UseAuthorization`), zmapuj endpoint:

```csharp
app.MapPrometheusScrapingEndpoint("/metrics");
```

`/metrics` ma być dostępny **bez JWT** (Prometheus nie loguje się do API). Nie dodawaj tej ścieżki do nginx jako publicznego proxy i nie wystawiaj jej w tunelu. W [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) port API zostaw jako `127.0.0.1:5080:8080`. Sam brak proxy nginx nie zamyka `/metrics`, dopóki host publikuje `5080` na `0.0.0.0`.

Sprawdzenie lokalne po starcie API:

```bash
curl -fsS http://127.0.0.1:5080/metrics | head
```

Powinny pojawić się linie typu `# HELP` / `# TYPE` oraz metryki `http_server_*` / runtime.

### 2. Konfiguracja Prometheusa w repo

Utwórz katalog i plik [infra/prometheus/prometheus.yml](../../infra/prometheus/prometheus.yml):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: jjdevhub-api
    metrics_path: /metrics
    scrape_interval: 15s
    static_configs:
      - targets:
          - api:8080
        labels:
          service: jjdevhub-api
```

`api` to **nazwa serwisu Compose** (DNS w sieci projektu), port **8080** to port wewnątrz kontenera API — nie `5080` z hosta.

### 3. Usługa w `docker-compose.yml`

W [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) dopisz serwis (obok `db` / `api` / `web`):

```yaml
  prometheus:
    image: prom/prometheus:v3.2.1
    container_name: jjdevhub-prometheus
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.listen-address=0.0.0.0:9090
    volumes:
      - ../prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    ports:
      - "127.0.0.1:9090:9090"
    depends_on:
      - api
```

W sekcji `volumes:` na dole pliku:

```yaml
volumes:
  postgres_data:
  prometheus_data:
```

Uwagi do ścieżki volume:

- Plik Compose leży w `infra/docker/`. Mount `../prometheus/prometheus.yml` to [infra/prometheus/prometheus.yml](../../infra/prometheus/prometheus.yml) względem tego katalogu. Nie używaj `./prometheus/…` w `infra/docker/` — tam tego pliku nie ma.

Tag obrazu `prom/prometheus:v3.2.1` podmień na aktualny stabilny z Docker Hub przy implementacji, jeśli 3.2.1 jest nieaktualny — pinuj konkretny tag, nie `latest`.

Sieć: domyślna sieć Compose łączy `prometheus` z `api` po nazwie serwisu. Osobnego `networks:` nie musisz deklarować, dopóki wszystkie serwisy są w jednym pliku bez custom network.

### 4. Cloudflare

Publiczny UI to `https://prometheus.jjdevhub.com/` → `http://127.0.0.1:9090` w tym samym tunelu. Path `/metrics` na hubie zostaje nieopublikowany. Szczegóły: [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).

Bind na hoście zostaje `127.0.0.1`. Z laptopa bez tunelu Cloudflare nadal działa port-forward:

```bash
ssh -L 9090:127.0.0.1:9090 deploy@TWOJA_VM
# lokalnie: http://127.0.0.1:9090
```

### 5. Restart stacku

Na VM (lub lokalnie):

```bash
cd /opt/jjdevhub   # lokalnie: katalog klonu
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml up -d --build
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml ps
```

## Jak sprawdzić, że działa

1. `curl -fsS http://127.0.0.1:5080/metrics` — tekst metryk (z hosta VM).
2. `curl -fsS http://127.0.0.1:9090/-/healthy` — Prometheus healthy.
3. UI `http://127.0.0.1:9090` → **Status → Targets** — job `jjdevhub-api` w stanie **UP**, scrape co ~15 s.
4. **Query** (w starszych obrazach zakładka Graph) → np. zapytanie `http_server_request_duration_seconds_count` albo inna metryka widoczna w `/metrics` — rosnące wartości po `curl` na `/health`.
5. Z innej maszyny w LAN: `curl http://IP_VM:9090` ma **nie** działać (bind tylko localhost). Hub `https://hub…/metrics` nie serwuje metryk. UI jest na `https://prometheus.jjdevhub.com/`.
6. `docker compose … ps` pokazuje `jjdevhub-prometheus`.

## Czego w tym pliku nie ruszać

- Jaegera, Grafany, SonarQube — numery 08–10.
- Publikacji `/metrics` na hubie i binda `9090` na `0.0.0.0`. Osobny hostname `prometheus.jjdevhub.com` jest w [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).
- Zmiany bindów Postgresa i logiki deployu poza dodaniem serwisu i volume.
- Usuwania eksportu OTLP z 06 — Prometheus scrape i OTLP mają współistnieć.
- Frontendu i workflowów `api`/`web` poza naturalnym przebudowaniem obrazu API.

## Następny numer

[08-jaeger.md](08-jaeger.md) — odbieranie trace’ów OTLP gRPC przez Jaegera w tym samym Compose.

---

## Pełny tutorial: Prometheus (od zera)

Czym jest Prometheus i dlaczego pull, jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają scrape i PromQL na tym API. Przepis eksportera i Compose jest wyżej. Nie stawiasz tu Jaegera, Grafany ani Alertmanagera.

### Dwa wyjścia tych samych metryk

W 06 metryki powstają w procesie. Push OTLP idzie wyłącznie na `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` — nie na adres Jaegera. Ten numer dokłada **czytnik scrape**, zawsze:

- `AddPrometheusExporter()` — niezależnie od OTLP,
- `MapPrometheusScrapingEndpoint("/metrics")` — GET bez JWT.

Scrape i push OTLP metryk (osobny endpoint collectora) mogą działać razem. Wyłączenie jednego nie kasuje instrumentów. Prometheus nie umie przyjąć OTLP z tego API, a Jaeger nie przyjmuje metryk. Dlatego `prometheus:9090` i `http://jaeger:4317` nie są celem `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`. Adres Jaegera zostaje przy trasach (`OTEL_EXPORTER_OTLP_ENDPOINT`).

Sam `AddPrometheusExporter` bez `Map…` nie otwiera portu. Samo mapowanie bez eksportera daje pustkę albo brak trasy. Potrzebne są oba, w tej kolejności: rejestracja **przed** `Build()`, trasa **po** `Build()`.

Trasy `/metrics` nie spinaj z `RequireAuthorization()`. Job `jjdevhub-api` nie ma tokenu. 401 na scrape to target DOWN, nie „lepsze bezpieczeństwo”. Ścieżka zostaje otwarta na porcie procesu. Z zewnątrz VM jej nie ma, bo publikacja hosta to loopback (`127.0.0.1:5080:8080`), a nginx tej ścieżki nie proxy’uje.

### Co ten API naprawdę wypisze

Po `curl -fsS http://127.0.0.1:5080/metrics` zobaczysz tekst, nie JSON. Kształt (nazwy zależą od wersji instrumentacji i od `OTEL_SEMCONV_STABILITY_OPT_IN`, o czym jest 06):

```text
# HELP http_server_request_duration_seconds Duration of HTTP server requests.
# TYPE http_server_request_duration_seconds histogram
http_server_request_duration_seconds_bucket{http_request_method="GET",http_response_status_code="200",http_route="/health",le="0.01"} 4
http_server_request_duration_seconds_bucket{http_request_method="GET",http_response_status_code="200",http_route="/health",le="+Inf"} 4
http_server_request_duration_seconds_sum{http_request_method="GET",http_response_status_code="200",http_route="/health"} 0.012
http_server_request_duration_seconds_count{http_request_method="GET",http_response_status_code="200",http_route="/health"} 4
```

Starszy semconv wygląda podobnie, tylko nazywa się `http_server_duration_seconds_*`, a etykiety bywają `http_method` / `http_status_code`. Zanim wkleisz nazwę do PromQL, przeczytaj nagłówek z tego `curl`. Krok „jak sprawdzić” podaje `http_server_request_duration_seconds_count` jako przykład, nie jako jedyną poprawną nazwę.

Seria to nazwa + etykiety w nawiasach + liczba. Typy, które tu mają znaczenie:

| Typ | Zachowanie | W tym API |
| --- | --- | --- |
| Counter | Rośnie (albo reset przy restarcie procesu). | `_count` histogramu, część metryk runtime. Tempo liczysz `rate` / `increase`, nie gołą wartością. |
| Gauge | Chodzi w górę i w dół. | Aktywne requesty, rozmiar sterty. |
| Histogram | `_bucket` z `le`, plus `_sum` i `_count`. | Czas requestu HTTP. Stąd p95. |

`http_route` to szablon (`/health`, `/api/auth/login`, `/api/auth/register`, `/api/auth/me`), nie mail z body. Tych ścieżek jest kilka, więc liczba serii zostaje mała. Email, hasło albo surowy URL z identyfikatorem jako label rozsadza TSDB: każda nowa wartość etykiety to nowa seria na zawsze (do retencji). Instrumentacja ASP.NET body i nagłówka `Authorization` do metryki nie kopiuje. Sam tego nie doklejaj.

Czas SQL-a osobnej metryki nie dostanie. Pakietu EF w 06 nie ma. Histogram HTTP obejmuje cały request, łącznie z bazą. Wychodzącego `HttpClient` też dziś nikt nie woła, więc metryki klienta HTTP będą ciche, dopóki taki call nie powstanie.

Obok HTTP są metryki procesu z `AddRuntimeInstrumentation` (GC, wątki, wyjątki). Nazwy zaczynają się zwykle od `process_runtime_dotnet_`. Służą do pytania „czy proces oddycha”, nie „czy login jest wolny”.

`/health` wchodzi do histogramu tak samo jak login. Częsty `curl` na health zdominuje `_count`. Gdy patrzysz na RPS loginu, odfiltruj route w PromQL, nie w nginx.

### Co Prometheus dopisuje sam

W tekście z API **nie ma** metryki `up`. Prometheus dokleja ją po scrapie:

- `up{job="jjdevhub-api",instance="api:8080"} 1` — GET się udał,
- `0` — połączenie padło, timeout, 404, 401, albo ciało nie jest ekspozycją.

`job` bierze się z `job_name`. `instance` to wpis z `targets` (`api:8080`), nie `localhost:5080` i nie nazwa kontenera `jjdevhub-api`. Etykieta `service="jjdevhub-api"` jest z `static_configs.labels` w przepisie. Grafana w 09 filtruje `job="jjdevhub-api"`. Ta sama etykieta.

`/health` równe 200 na `:4200` i `up` równe 0 mogą iść w parze: nginx nie pyta `/metrics`, a scrape idzie na `api:8080` od środka sieci. Odwrotnie, `up` równe 1 nie mówi, czy login zwraca 200. Do tego jest histogram albo span w Jaegerze.

### `prometheus.yml`, pole po polu

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: jjdevhub-api
    metrics_path: /metrics
    scrape_interval: 15s
    static_configs:
      - targets:
          - api:8080
        labels:
          service: jjdevhub-api
```

| Pole | Sens |
| --- | --- |
| `scrape_interval` w `global` | Domyślna częstość dla jobów, które swojej nie podają. |
| `scrape_interval` przy jobie | Wygrywa z global dla `jjdevhub-api`. Tu i tak 15 s. Sekunda na jednym celu jest zbędna; 15 s wystarcza do `rate` na oknie minuty. |
| `evaluation_interval` | Jak często liczyć reguły i alerty. Reguł w tym pliku nie ma. Nic nie alarmuje. Alertmanagera nie dodajesz. |
| `job_name` | Etykieta `job`. Zostaje `jjdevhub-api`, bo tak woła ją dashboard z 09. |
| `metrics_path` | Ma się zgadzać z argumentem `MapPrometheusScrapingEndpoint`. Domyślny path eksportera to też `/metrics`; w przepisie oba są jawne. |
| `targets` | Host i port **z sieci kontenera Prometheusa**. Usługa `api`, port procesu `8080`. |
| `labels` | Doklejane do każdej serii z tego targetu. |

`5080` istnieje tylko na hoście (`127.0.0.1:5080:8080` w Compose API). Z kontenera `jjdevhub-prometheus` port `5080` nic nie znaczy, a `127.0.0.1` to sam Prometheus. Stąd `api:8080`.

Osobnej sieci `networks:` nie deklarujesz. Serwisy z jednego pliku Compose widzą się po nazwie usługi. `container_name: jjdevhub-prometheus` nie jest nazwą DNS. Datasource Grafany i tak używa `prometheus:9090`.

Plik leży w [infra/prometheus/prometheus.yml](../../infra/prometheus/prometheus.yml). Mount w Compose to `../prometheus/prometheus.yml`, bo plik Compose jest w `infra/docker/`. Zapis `./prometheus/…` szuka katalogu obok `docker-compose.yml` i kontener wstaje z błędem braku configu albo z cudzym plikiem. Ścieżka volume jest względem pliku Compose, nie względem katalogu, z którego wołasz polecenie.

Edycja YAML na hoście **nie** wchodzi sama. Bind-mount `prometheus.yml` nie zmienia definicji usługi Compose, więc samo `up -d` potrafi zostawić działający proces ze starymi targetami. W przepisie nie ma `--web.enable-lifecycle`, więc HTTP `/-/reload` nie działa. Albo odtwórz kontener tymi samymi plikami Compose i env:

```bash
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml up -d --force-recreate prometheus
```

albo wyślij SIGHUP:

```bash
docker kill --signal=SIGHUP jjdevhub-prometheus
```

Zły YAML przy restarcie: proces nie wstanie, w `docker logs jjdevhub-prometheus` jest błąd parsowania. Przy SIGHUP zły plik zostawia poprzedni config i pisze błąd do logu.

### Kontener i port 9090

W środku kontenera proces słucha `0.0.0.0:9090` (`--web.listen-address`). Tak ma być. Docker przekazuje opublikowany port na adres kontenera w sieci mostka, nie na loopback **wewnątrz** kontenera. Gdyby proces słuchał tylko `127.0.0.1` w środku, `curl` z VM na `127.0.0.1:9090` dostałby odmowę, mimo bindu na hoście.

Na hoście publikacja to `127.0.0.1:9090:9090`. Z LAN-u i z internetu portu nie ma. Z laptopa:

```bash
ssh -L 9090:127.0.0.1:9090 deploy@TWOJA_VM
```

Potem `http://127.0.0.1:9090`. Tunel Cloudflare tego nie dostaje. UI bez hasła pokazuje topologię (`api:8080`) i ruch po route. To narzędzie operatora na VM, nie strona huba.

`depends_on: api` czeka, aż kontener API **wstanie**, nie aż Kestrel przyjmie połączenie. `MigrateAsync()` w `Program.cs` leci przed `app.Run()`. Przez te sekundy scrape dostaje connection refused, target jest DOWN, `up` jest 0. Po starcie Kestrela kolejny scrape (do 15 s) przechodzi na UP. Czerwony target w pierwszej minucie po `compose up` nie jest złym `prometheus.yml`.

### Dysk

TSDB jest w `/prometheus` w kontenerze, a to named volume `prometheus_data`. Zwykły restart kontenera historię zostawia. `docker compose down -v` volume kasuje i wykres w Grafanie zaczyna się od zera.

Domyślna retencja obrazu to **15 dni** (`--storage.tsdb.retention.time`), dopóki jej nie nadpiszesz. Przepis flagi nie ustawia, więc zostaje te 15 dni. Jeden target, scrape co 15 s i kilka route’ów to nieduży katalog, nie powód, żeby skracać retencję w ciemno. Krótszy okres albo sufit rozmiaru (`--storage.tsdb.retention.size`) dokładasz, gdy `docker system df` pokaże, że volume rośnie ponad tę VM. Bez volume w ogóle każdy restart czyści historię — tego w przepisie nie rób.

Sam Prometheus **nie** jest na liście targetów. W TSDB nie będzie serii `prometheus_tsdb_*`, dopóki nie dopiszesz joba na `localhost:9090` **wewnątrz** tego kontenera. Brak tych serii nie znaczy, że proces nie żyje. Życie procesu sprawdzasz `/-/healthy` i tym, że target `jjdevhub-api` jest UP.

### Jak czytać UI

Obraz `prom/prometheus:v3.2.1` ma nowe UI. Zapytanie jest na stronie **Query** (starsze poradniki piszą „Graph”). **Status → Targets** pokazuje job, stan, czas ostatniego scrapa i tekst błędu.

1. Target `jjdevhub-api` / `api:8080` — UP, błąd pusty.
2. Query, zakres ostatniej godziny, wyrażenie `up{job="jjdevhub-api"}`. Linia na 1.
3. To samo zapytanie, które widzisz w `/metrics` (nazwa z `_count`), po kilku `curl` na `/health` — liczba rośnie. Goły counter to stan „ile od startu procesu”, nie „ile na sekundę”.
4. Z innej maszyny w LAN `curl http://IP_VM:9090` ma nie dojść. `https://hub…/metrics` też nie.

`rate` potrzebuje co najmniej dwóch próbek w oknie. Przy scrapie co 15 s okno `[1m]` zaczyna działać po minucie ruchu. `[10s]` często jest puste. `[5m]` jest spokojniejsze i tego używa szkic w 09.

```promql
up{job="jjdevhub-api"}

sum by (http_route) (
  rate(http_server_request_duration_seconds_count{job="jjdevhub-api"}[5m])
)

histogram_quantile(
  0.95,
  sum by (le, http_route) (
    rate(http_server_request_duration_seconds_bucket{job="jjdevhub-api"}[5m])
  )
)
```

Podmień nazwę histogramu, jeśli w `/metrics` jest `http_server_duration_seconds_*`. `sum by (le)` przy kwantylu zostawia granicę kubełka. `sum()` bez `le` skleja kubełki i p95 kłamie. `rate` idzie na `_bucket` i na `_count`, nie na `up` i nie na gauge sterty.

Restart API zeruje countery w procesie. `rate` ten reset znosi. Różnica dwóch gołych odczytów `_count` po deployu potrafi wyjść ujemna — to nie jest RPS.

### Gdy wynik jest zły

| Objaw | Co sprawdzić |
| --- | --- |
| `curl :5080/metrics` — odmowa połączenia | API nie słucha (migracja, zły port). To jeszcze nie wina Prometheusa. |
| `/metrics` to 404 | Brak `MapPrometheusScrapingEndpoint` albo inna ścieżka niż `/metrics`. |
| `/metrics` to 401 | Ktoś dodał `RequireAuthorization()`. Scrape ma być anonimowy. |
| Tekst jest, ale nie ma `http_server_` | Eksporter jest, instrumentacji ASP.NET nie ma (krok 06). Zostaną najwyżej metryki procesu. |
| Kontener `jjdevhub-prometheus` w kółko pada | Zła ścieżka mountu albo YAML, którego proces nie parsuje. `docker logs jjdevhub-prometheus`. |
| Targets puste | Inny plik configu niż myślisz (stary checkout na VM w `/opt/jjdevhub`). |
| Target DOWN, `connection refused` | `localhost` / `5080` w `targets`, albo API jeszcze nie doszło do `Run()`. |
| Target DOWN, `404` | `metrics_path` nie równa się trasie w kodzie. |
| UP, a zapytanie o histogram puste | Nazwa z poradnika ≠ nazwa w tekście. Wklej tę z `curl`. Albo okno `rate` krótsze niż dwa scrape’e. |
| `up` jest 0, `/health` na `:4200` działa | Scrape nie używa nginx. Patrz błąd na Targets, nie kod health. |
| Po `compose down -v` wykres startuje od zera | Volume `prometheus_data` poszedł z flagą `-v`. |
| UI z laptopa nie wchodzi, z VM wchodzi | Bind `127.0.0.1`. Tak ma być bez tunelu SSH. |
| Zmiana YAML nic nie zmienia w Targets | Brak przeładowania. `up -d --force-recreate prometheus` (te same pliki Compose i env) albo SIGHUP. Nie `/-/reload`, dopóki sam nie włączysz lifecycle. |

### Typowe pomyłki

1. **Target `127.0.0.1:5080` albo `localhost:8080` w `prometheus.yml`.** Z kontenera Prometheusa to on sam. Cel to `api:8080`.
2. **`web.listen-address=127.0.0.1:9090` „bo bezpieczeństwo”.** Ucinasz przekierowanie Dockera. Bezpieczeństwo portu jest w `127.0.0.1:9090:9090` po stronie **hosta**.
3. **`0.0.0.0:9090:9090` na hoście.** UI na LAN. Metryki opisują trasy i ruch.
4. **Proxy `/metrics` w nginx albo hostname w tunelu.** Ten sam wyciek, tylko przez hub. Origin zostaje `4200`.
5. **JWT na `/metrics`.** Prometheus nie jest użytkownikiem API. Target będzie DOWN.
6. **OTLP pchnięte na `http://prometheus:9090`.** Ten port mówi HTTP z PromQL i scrapem, nie gRPC.
7. **Wyłączenie `AddOtlpExporter`, bo „metryki już są w Prometheusie”.** To drugi kanał. Trace’e z 08 i tak idą OTLP-em. Eksporter Prometheus zostaje włączony zawsze, OTLP warunkowo, jak w kroku 1.
8. **`rate(up[5m])` jako RPS.** `up` to gauge scrapa. Tempo requestów jest na `_count` histogramu.
9. **`histogram_quantile` bez `sum by (le)`.** Kwantyl bez granicy kubełka jest liczbą z kapelusza.
10. **Goły counter jako „ile requestów na sekundę”.** To suma od startu procesu. Sekundy daje `rate`.
11. **Scrape co 1 s „żeby wykres był gładszy”.** Na jednym API 15 s wystarcza i nie mieli `/metrics` w kółko.
12. **Brak volume.** Każdy deploy czyści TSDB. `prometheus_data` zostaje.
13. **Alert tylko na brak punktów na wykresie.** Padnięty scrape widać jako `up == 0`. Pusty histogram bywa też złym oknem albo złą nazwą.
14. **Email w etykiecie.** Kilka szablonów tras jest tanich. Wartość per użytkownik już nie.
15. **Czekanie na span SQL albo log w tym UI.** Prometheus trzyma liczby. Łańcuch requestu jest w Jaegerze (08), obrazek w Grafanie (09).

### Oficjalne źródła

- [prometheus.io/docs](https://prometheus.io/docs/introduction/overview/) — model pull, konfiguracja, PromQL (`rate`, `histogram_quantile`, `up`).
- Format ekspozycji i OpenMetrics.
- Flagi obrazu `prom/prometheus`: `--config.file`, `--storage.tsdb.path`, `--storage.tsdb.retention.time`, `--web.listen-address`.
- OpenTelemetry .NET: `OpenTelemetry.Exporter.Prometheus.AspNetCore`, `AddPrometheusExporter`, `MapPrometheusScrapingEndpoint`. Wersja w przepisie jest z linii beta przy OTel 1.12; przy wdrożeniu bierz aktualną zgodną z resztą paczek z 06.

Tag w przepisie to `prom/prometheus:v3.2.1`. Nowszy stabilny pin jest w porządku. `latest` nie.

### Co zapamiętać

Prometheus w tym Compose co 15 s czyta `http://api:8080/metrics` i składa z tego TSDB na volume. API tylko wystawia tekst, bez JWT i bez pusha. `up` mówi, czy scrape żyje. Histogram HTTP mówi, jak długo trwały requesty — pod nazwą, którą naprawdę wypisze `/metrics`. UI na `127.0.0.1:9090` zostaje na VM. Wykres na stałe i tak oglądasz w Grafanie, tym samym `job="jjdevhub-api"`.
