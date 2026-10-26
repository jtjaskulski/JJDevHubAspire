# 06 — OpenTelemetry w API

## Po co

`JJDevHub.Api` ma emitować trasy, metryki i logi oraz wysyłać je, gdy w środowisku jest adres. Bez zmiennej spany powstają w procesie i są porzucane. W tym numerze nie stawiasz collectora, Prometheusa ani Jaegera; odbiornik metryk dochodzi w [07-prometheus.md](07-prometheus.md), tras w [08-jaeger.md](08-jaeger.md).

## Dlaczego ta technologia

### OpenTelemetry zamiast klienta jednego backendu

OpenTelemetry (CNCF) to wspólny opis telemetrii: API na `System.Diagnostics.Activity` i `System.Diagnostics.Metrics`, SDK (sampling, batch, resource), gotowe instrumentacje ASP.NET Core, `HttpClient` i runtime oraz eksporter. Instrumentujesz raz w [src/api/Program.cs](../../src/api/Program.cs). Backend (Jaeger, Tempo, Grafana Cloud) wymieniasz adresem, nie przepisując endpointów. Klient jednego dostawcy przegrał: zmiana narzędzia na VM byłaby zmianą kodu API. Własne logowanie czasu żądania przegrało, bo nie niesie `trace_id` między procesami. Koszt: cztery pakiety w [Directory.Packages.props](../../Directory.Packages.props) i puste zmienne, gdy odbiornika jeszcze nie ma.

### OTLP gRPC zamiast własnego protokołu

OTLP wynosi telemetrię z procesu. gRPC na porcie 4317 jest transportem, którego słucha Jaeger w następnym numerze. HTTP/protobuf na 4318 przegrał w tym stacku: Jaeger w Compose nie jest tak ustawiony, a SDK doklejałby `/v1/traces`. Collector jako osobny proces przegrał w tym numerze: nie ma jeszcze odbiornika, a dokładanie hopa przed Jaegerem i Prometheusem nic nie upraszcza. Koszt: `http://` przy gRPC znaczy „bez TLS”, a `https://` pada na odbiorniku bez certyfikatu. Metryki i logi nie idą na adres Jaegera — mają własne zmienne i zostają w procesie, dopóki ich nie ustawisz.

## Co już jest w repo

- API: [src/api/Program.cs](../../src/api/Program.cs), projekt [JJDevHub.Api.csproj](../../src/api/JJDevHub.Api.csproj), wersje centralne [Directory.Packages.props](../../Directory.Packages.props).
- Compose: usługa `api` w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) — env z `/etc/jjdevhub/api.env` (wzór [infra/docker/.env.example](../../infra/docker/.env.example)).
- Obraz API: [infra/docker/Dockerfile](../../infra/docker/Dockerfile).
- VM i sekrety: [01-proxmox.md](01-proxmox.md). Tunel tylko na `4200`: [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md). CI: [03-github.md](03-github.md). Security CI: [04-codeql.md](04-codeql.md), [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md).
- Pakiety OpenTelemetry i zmienne `OTEL_*` w Compose / `.env.example` są już w repozytorium — ten dokument.
- Endpoint `/metrics` pod scrape Prometheusa **nie** należy do tego pliku (07).

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie |
| --- | --- |
| OpenTelemetry (OTel) | Standard instrumentacji: API + SDK + eksportery. Jeden sposób opisu telemetrii, wiele backendów. |
| Trace / span | Ślad żądania: drzewo spanów. W tym numerze zostaje span HTTP; span SQL dojdzie dopiero z osobną instrumentacją EF. |
| Metric | Licznik / histogram / gauge w czasie (np. liczba requestów, czas trwania). |
| Log | Zdarzenie tekstowe / strukturalne skorelowane z trace id, gdy pipeline to spina. |
| OTLP | OpenTelemetry Protocol — transport telemetrii. Tu: **gRPC**. |
| Resource | Atrybuty procesu: `service.name`, wersja, środowisko. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Adres **tras**. Później `http://jaeger:4317`. Jaeger nie przyjmuje metryk ani logów. Puste = brak eksportu tras. |

## Kroki

### 1. Pakiety NuGet (Central Package Management)

W [Directory.Packages.props](../../Directory.Packages.props) dopisz wersje (dobierz aktualne stabilne z nuget.org; poniżej orientacyjne — przy implementacji sprawdź najnowsze zgodne z net11):

```xml
<PackageVersion Include="OpenTelemetry.Extensions.Hosting" Version="1.19.1" />
<PackageVersion Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.19.0" />
<PackageVersion Include="OpenTelemetry.Instrumentation.Http" Version="1.19.0" />
<PackageVersion Include="OpenTelemetry.Instrumentation.Runtime" Version="1.19.0" />
<PackageVersion Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.19.1" />
```

W [JJDevHub.Api.csproj](../../src/api/JJDevHub.Api.csproj):

```xml
<PackageReference Include="OpenTelemetry.Extensions.Hosting" />
<PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" />
<PackageReference Include="OpenTelemetry.Instrumentation.Http" />
<PackageReference Include="OpenTelemetry.Instrumentation.Runtime" />
<PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" />
```

Nie dodawaj tu `OpenTelemetry.Exporter.Prometheus.AspNetCore` — to [07-prometheus.md](07-prometheus.md).

### 2. Instrumentacja w `Program.cs`

Po konfiguracji JWT / DbContext / Identity, **przed** `var app = builder.Build();`, dodaj rejestrację OTel. Eksporter OTLP tylko gdy endpoint jest ustawiony:

```csharp
using OpenTelemetry.Logs;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

// … istniejący kod builder.Services …

// Jaeger (08) przyjmuje tylko trasy. Wspólny endpoint to ten adres.
// Metryki i logi nie spadają na niego — inaczej batch idzie w retry do odbiornika samych tras.
var tracesEndpoint = OtelSetting(builder.Configuration, "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT")
    ?? OtelSetting(builder.Configuration, "OTEL_EXPORTER_OTLP_ENDPOINT");
var metricsEndpoint = OtelSetting(builder.Configuration, "OTEL_EXPORTER_OTLP_METRICS_ENDPOINT");
var logsEndpoint = OtelSetting(builder.Configuration, "OTEL_EXPORTER_OTLP_LOGS_ENDPOINT");

var serviceName = OtelSetting(builder.Configuration, "OTEL_SERVICE_NAME")
    ?? "JJDevHub.Api";

builder.Services.AddOpenTelemetry()
    .ConfigureResource(resource => resource.AddService(serviceName: serviceName))
    .WithTracing(tracing =>
    {
        tracing
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation();
        if (tracesEndpoint is not null)
        {
            tracing.AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(tracesEndpoint);
                // gRPC — domyślne dla OTLP w tym eksporterze przy porcie 4317
            });
        }
    })
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation();
        if (metricsEndpoint is not null)
        {
            metrics.AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri(metricsEndpoint);
            });
        }
    });

builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
    if (logsEndpoint is not null)
    {
        logging.AddOtlpExporter(options =>
        {
            options.Endpoint = new Uri(logsEndpoint);
        });
    }
});
```

`OtelSetting` czyta klucz z konfiguracji, potem ze zmiennej procesu, i zwraca `null` dla pustego albo białego stringa (żeby `new Uri` nie wywalił startu).

Wymuś protokół gRPC przez środowisko (zalecane, zamiast hardcodu w każdym miejscu):

- `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`

SDK OTel czyta standardowe zmienne `OTEL_*` także sam z siebie; jawne `AddOtlpExporter` + env dają przewidywalność w Compose.

Nie zmieniaj mapowań `/health`, auth, CORS, migracji EF — tylko dopinasz telemetrię.

### 3. Compose i plik env — zmienne, bez odbiornika

W usłudze `api` w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) dopisz do `environment:`:

```yaml
      OTEL_SERVICE_NAME: ${OTEL_SERVICE_NAME:-JJDevHub.Api}
      OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-}
      OTEL_EXPORTER_OTLP_TRACES_ENDPOINT: ${OTEL_EXPORTER_OTLP_TRACES_ENDPOINT:-}
      OTEL_EXPORTER_OTLP_METRICS_ENDPOINT: ${OTEL_EXPORTER_OTLP_METRICS_ENDPOINT:-}
      OTEL_EXPORTER_OTLP_LOGS_ENDPOINT: ${OTEL_EXPORTER_OTLP_LOGS_ENDPOINT:-}
      OTEL_EXPORTER_OTLP_PROTOCOL: ${OTEL_EXPORTER_OTLP_PROTOCOL:-grpc}
```

W [infra/docker/.env.example](../../infra/docker/.env.example) (i później w `/etc/jjdevhub/api.env` na VM):

```bash
# Trasy. Puste = bez eksportu. Po 08-jaeger.md: http://jaeger:4317
# Jaeger nie przyjmuje metryk ani logów OTLP — tych sygnałów tam nie kieruj.
OTEL_EXPORTER_OTLP_ENDPOINT=
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=
OTEL_EXPORTER_OTLP_METRICS_ENDPOINT=
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
OTEL_SERVICE_NAME=JJDevHub.Api
```

Na serwerze po deployu:

```bash
sudoedit /etc/jjdevhub/api.env
# dopisz linie jak wyżej; endpointy na razie zostaw puste
```

**Nie** dodawaj kontenera `otel-collector`, `jaeger` ani `prometheus` w tym kroku. **Nie** publikuj żadnego nowego portu w tunelu Cloudflare.

### 4. Build i test lokalnie / na VM

```bash
dotnet restore JJDevHub.sln
dotnet build src/api/JJDevHub.Api.csproj -c Release
dotnet test tests/JJDevHub.Api.Tests/JJDevHub.Api.Tests.csproj -c Release
```

Compose (local lub `/opt/jjdevhub`):

```bash
docker compose --env-file infra/docker/.env -f infra/docker/docker-compose.yml up -d --build api
# na VM: --env-file /etc/jjdevhub/api.env
curl -fsS http://127.0.0.1:5080/health
curl -fsS http://127.0.0.1:4200/health
```

Bez endpointu API ma wstawać i odpowiadać jak wcześniej. Log startu nie powinien sypać błędami połączenia OTLP — eksportera sieciowego wtedy nie ma.

Opcjonalny smoke z fałszywym endpointem (ma logować błędy eksportu / retry, ale proces żyje):

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4317 \
OTEL_EXPORTER_OTLP_PROTOCOL=grpc \
dotnet run --project src/api
```

## Jak sprawdzić, że działa

1. Solution buduje się; testy API przechodzą.
2. `curl` na `/health` (port `5080` lub przez nginx `4200`) zwraca Healthy.
3. W kodzie widać `AddOpenTelemetry`, instrumentacje ASP.NET / Http / Runtime oraz warunkowy `AddOtlpExporter`.
4. W Compose / `.env.example` są `OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_ENDPOINT` (trasy), osobne `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` i `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` oraz `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`.
5. Brak kontenerów collector/Prometheus/Jaeger w tym commicie; tunel Cloudflare bez nowych hostname’ów.
6. Po ustawieniu prawdziwego endpointu w późniejszym numerze (Jaeger) spany pojawią się w UI odbiornika — tu wystarczy gotowość konfiguracji.

## Czego w tym pliku nie ruszać

- Contenerów Prometheus / Grafana / Jaeger / otel-collector.
- `MapPrometheusScrapingEndpoint` / eksportera Prometheus — [07-prometheus.md](07-prometheus.md).
- Publikacji OTLP ani `/metrics` przez Cloudflare ([02-cloudflare-tunnel.md](02-cloudflare-tunnel.md) zostaje przy samym `4200`).
- Workflowów security (04–05) i logiki deployu, poza tym że obraz API przebuduje się naturalnie po zmianie kodu.
- Frontendu React — instrumentacja przeglądarkowa jest poza tym numerem.

## Następny numer

[07-prometheus.md](07-prometheus.md) — kontener Prometheus w Compose, scrape `/metrics` co 15 s, bind `127.0.0.1`.

---

## Pełny tutorial: OpenTelemetry (od zera)

Czym jest OpenTelemetry i dlaczego OTLP gRPC, jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają trzy sygnały jednego żądania i kod z [kroku 2](#2-instrumentacja-w-programcs). Tutaj nie dodajesz Jaegera, Prometheusa ani collectora — odbiorniki są w [07-prometheus.md](07-prometheus.md) i [08-jaeger.md](08-jaeger.md).

### Jedno żądanie, trzy sygnały

Weź `POST /api/auth/login` tak, jak jest dziś: nginx proxy’uje `/api/` na `api:8080` ([nginx.conf](../../src/Clients/web/nginx.conf)), endpoint w [AuthEndpoints.cs](../../src/api/Auth/AuthEndpoints.cs) woła Identity i [TokenService](../../src/api/Auth/TokenService.cs), a baza to EF Core + Npgsql.

**Trace.** Instrumentacja ASP.NET otwiera jeden span serwerowy na czas obsługi HTTP. Wspólny `trace_id`, własny `span_id`. Atrybuty opisują metodę, szablon trasy (`/api/auth/login`, nie konkretny email) i kod statusu. Długość paska na osi czasu to cały request: odczyt użytkownika, weryfikacja hasła, złożenie JWT. W tym numerze **nie ma** osobnego spana SQL — pakiet EF Core nie wchodzi do listy z kroku 1. Czas bazy jest w środku paska HTTP, bez rozbicia. To jest właściwy pierwszy kształt, nie zepsuty eksport.

**Metryka.** Ten sam request dodaje obserwację do histogramu czasu po stronie serwera (liczba requestów, rozkład latencji, status). Histogram jest tani: tysiąc loginów to kilka liczb, nie tysiąc drzew spanów. Alert „p95 ponad próg” bierze się stąd, nie z Jaegera.

**Log.** `ILogger` zapisany w trakcie tego requestu może dostać `trace_id` i `span_id` z bieżącego `Activity`. W UI logów (później) skaczesz z wolnego spana do linii tego jednego żądania. Hasła, klucza JWT i connection stringa do logu nie wkładaj — telemetria ląduje w narzędziu, które czytasz miesiącami.

`GET /health` ma ten sam kształt, tylko krótszy: jeden span, jedna obserwacja histogramu, zwykle bez logu aplikacji. Kontener `web` w Compose sprawdza siebie przez `wget` na `/` nginxu, nie na `/health` API. Spany `/health` biorą się z ręcznego `curl` i z tego, co proxy’uje nginx, a nie z healthchecka frontu.

`MigrateAsync()` w [Program.cs](../../src/api/Program.cs) leci przy starcie, zanim Kestrel przyjmie ruch, i nie jest żądaniem HTTP. Bez instrumentacji EF nie zobaczysz go jako spana. Pad migracji ubija proces, zanim jakikolwiek eksport zdąży coś pokazać.

### Activity, nagłówek traceparent, nginx

W .NET span to `System.Diagnostics.Activity`. `Activity.Current` to span „na tym wątku async”. Instrumentacja ASP.NET ustawia go na czas requestu i zdejmuje na końcu. Własny kod, który wołasz z endpointu, widzi tego rodzica automatycznie — dopóki nie odpalisz pracy na boku bez przekazania kontekstu.

Między procesami kontekst jedzie nagłówkiem W3C `traceparent` (i opcjonalnie `tracestate`). Nginx w tym repo dokleja `Host`, `X-Real-IP` i `X-Forwarded-For`, a reszty nagłówków nie wycina, więc `traceparent` od klienta doszedłby do Kestrela. Dziś go nie ma kto wysłać: React z tego numeru nie jest instrumentowany. Każde żądanie do API jest więc **korzeniem** trace’u, nie dzieckiem spana z przeglądarki.

Adres, który widzi span, to ten, który widzi API: ścieżka `/api/auth/login` albo `/health`, port **8080** w kontenerze. `5080` to mapowanie na hoście (`127.0.0.1:5080:8080`). Peer w atrybutach sieciowych to adres z sieci Dockera (kontener `web`), nie przeglądarka użytkownika.

### OTLP

OTLP to protokół wynoszenia telemetrii. Dwa transporty, których ludzie mylą, bo oba są „HTTP-podobne”:

| | gRPC | HTTP/protobuf |
| --- | --- | --- |
| Zmienna `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | `http/protobuf` |
| Port odbiornika | **4317** | **4318** |
| Endpoint w tym stacku | `http://jaeger:4317` | nie używasz |
| Ścieżka | sam host i port | SDK dopisuje `/v1/traces`, `/v1/metrics`, `/v1/logs` |

Schemat `http://` przy gRPC znaczy „bez TLS”, nie „to zwykły POST”. `https://jaeger:4317` włącza TLS i pada na Jaegerze v2 bez certyfikatu. Do adresu gRPC nie doklejasz `/v1/traces` — ta ścieżka należy do transportu HTTP.

`OTEL_EXPORTER_OTLP_ENDPOINT` w tym stacku karmi **tylko trasy** (Jaeger z [08-jaeger.md](08-jaeger.md) przyjmuje OTLP trace, nie metryki i nie logi). Spec zna zmienne per sygnał i kod ich używa:

- trasy: `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, a gdy puste — `OTEL_EXPORTER_OTLP_ENDPOINT`,
- metryki: wyłącznie `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` (collector albo backend metryk), bez zejścia na adres Jaegera,
- logi: wyłącznie `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT`.

Puste metryki i logi nie rejestrują `AddOtlpExporter`. Inaczej batch leci w retry na `http://jaeger:4317` i nic nie dochodzi.

Eksporter .NET **bez** ustawionego endpointu celuje w `http://localhost:4317`. Dlatego krok 2 woła `AddOtlpExporter` tylko gdy zmienna jest niepusta. Bezwarunkowe `AddOtlpExporter()` przy pustym env sypie w logu retry do loopbacka kontenera API. Pusty string w Compose (`${OTEL_EXPORTER_OTLP_ENDPOINT:-}`) wpada w `IsNullOrWhiteSpace` i eksportera nie ma. Wartość `null` albo przypadkowa spacja już tak — `new Uri(...)` wywali start.

W dokumentacji .NET 8+ widać skrót `UseOtlpExporter()`: jedna linia spina trzy sygnały i czyta `OTEL_*`. Przepis jej nie używa. Skrót i tak dokleja eksporter, a pusty endpoint zostawia domyślny localhost. Jawny `if` jest tu po to, żeby VM bez Jaegera wstawała cicho.

Ustawienie `options.Endpoint` w kodzie nadpisuje adres. Protokół i tak bierze się z `OTEL_EXPORTER_OTLP_PROTOCOL` (w przepisie `grpc`), dopóki nie ustawisz `options.Protocol` w callbacku. Rozjazd „adres na 4318, protokół grpc” wygląda jak martwy odbiornik.

SDK nie wysyła spana po każdym requestcie. Batch (domyślnie okolice 5 s, `OTEL_BSP_SCHEDULE_DELAY`) zbiera paczkę. `curl` i natychmiastowe `docker kill` gubią ostatnią porcję. Zwykłe zatrzymanie hosta (`docker stop`, Ctrl+C przy `dotnet run`) robi flush. Po podłączeniu Jaegera odczekaj kilka sekund, zanim uznasz, że eksport nie działa.

Collector OTel (osobny proces: filtr, tail sampling, rozdział na kilka backendów) nie jest w tym numerze. OTLP przyjmuje Jaeger v2 z [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml), opisany w [08-jaeger.md](08-jaeger.md). Osobny collector dochodzi, gdy jeden proces ma karmić i trace’e, i coś jeszcze, albo gdy zechcesz odrzucać `/health` poza aplikacją.

### Zmienne, które czyta SDK

| Zmienna | Przykład w JJDevHub | Sens |
| --- | --- | --- |
| `OTEL_SERVICE_NAME` | `JJDevHub.Api` | `service.name` w UI. Fallback w kodzie jest taki sam. |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | puste, później `http://jaeger:4317` | Adres **tras**, gdy nie ma `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`. |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | puste | Nadpisuje adres tras. |
| `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | puste | Jedyny adres pushu metryk. Nie ustawiaj na Jaegera. |
| `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` | puste | Jedyny adres pushu logów. Nie ustawiaj na Jaegera. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `grpc` | Transport. Musi pasować do portu. |
| `OTEL_RESOURCE_ATTRIBUTES` | `deployment.environment.name=prod` | Doklejane atrybuty procesu. Bez sekretów. |
| `OTEL_TRACES_SAMPLER` | nie ustawiasz | Domyślnie zapis 100% (parent-based, always on). |
| `OTEL_TRACES_SAMPLER_ARG` | np. `0.1` przy ratio | Ułamek trace’ów, gdy sampler to ratio. |
| `OTEL_SDK_DISABLED` | `true` | Wyłącza SDK. Na VM tego nie ustawiasz. |
| `OTEL_SEMCONV_STABILITY_OPT_IN` | nie ustawiasz w tym kroku | Przełącza stare i nowe nazwy atrybutów HTTP (`http` / `http/dup`). |

`OTEL_SERVICE_NAME` w kodzie kroku 2 jest czytane i z konfiguracji ASP.NET (env wchodzi do `IConfiguration` samo), i ze zmiennej procesu. Potem `AddService` wpisuje tę nazwę w resource. Compose ustawia tę samą wartość. Gdyby się rozjechały, w UI zostanie ta z `AddService`.

### Kod z kroku 2, kawałek po kawałku

Rejestracja stoi **przed** `var app = builder.Build()`. Provider powstaje przy budowie hosta. Dopisanie OTel po `Build()` nic nie eksportuje.

| Fragment | Po co |
| --- | --- |
| `AddOpenTelemetry()` | Spina SDK z hostem genericznym. |
| `ConfigureResource` + `AddService` | `service.name`. Bez tego UI pokazuje `unknown_service` plus nazwę procesu. |
| `AddAspNetCoreInstrumentation` | Span i metryka na każde żądanie, które doszło do Kestrela. |
| `AddHttpClientInstrumentation` | Span klienta na wychodzące `HttpClient`. W tym API dziś nikt `HttpClient` nie woła (Identity i Npgsql idą inną drogą), więc przy loginie dziecka HTTP nie będzie. Zostaje na kolejny wychodzący call. |
| `AddRuntimeInstrumentation` | Metryki procesu: GC, thread pool, wyjątki. Do dashboardu „czy proces oddycha”, nie do ścieżki requestu. |
| `if` wokół `AddOtlpExporter` | Osobny adres na każdy sygnał. Trasy biorą Jaegera. Metryki i logi nie dziedziczą tego adresu. |
| `builder.Logging.AddOpenTelemetry` | Trzeci sygnał. Nie wchodzi w `WithTracing` / `WithMetrics`. |
| `IncludeFormattedMessage` | W rekordzie jest gotowy tekst komunikatu, nie tylko szablon. |
| `IncludeScopes` | Dokleja scope’y `ILogger`. To nie to samo co `trace_id`. |
| Brak `ClearProviders()` | Konsola (`docker logs`) zostaje. OTel jest dodatkowym providerem. |

`trace_id` na logu OTel bierze się z `Activity.Current` w momencie `Log...`, nie z `IncludeScopes`. Linia wypisana poza requestem (start hosta, migracja) nie ma spana i nie dostanie identyfikatora trace’u.

### Resource

Resource to etykiety **procesu**, te same przy każdym spanie i metryce:

- `service.name` — `JJDevHub.Api`, stałe między restartami,
- `service.instance.id` — `AddService` dokleja wygenerowany identyfikator instancji (domyślnie w SDK 1.12), inny po każdym starcie kontenera,
- `telemetry.sdk.name` / `telemetry.sdk.language` — `opentelemetry` / `dotnet`.

`service.name` nie zastępuj hostname’em. Dwie repliki mają się zlać w jeden serwis; rozróżnia je `service.instance.id`.

`OTEL_RESOURCE_ATTRIBUTES` dokleja pary `klucz=wartość` (lista po przecinku). Aktualna nazwa środowiska w semconv to `deployment.environment.name`. Starsze przykłady używają `deployment.environment` — dashboard filtrowany po starym kluczu nowego atrybutu nie zobaczy. Hasła, `Jwt__Key` i connection string nie są atrybutem resource: Jaeger i Prometheus potraktują je jak zwykłą etykietę.

### Metryki: są w procesie, wychodzą dwiema drogami

W tym numerze push metryk OTLP włącza się wyłącznie przez `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`. Adres Jaegera (`OTEL_EXPORTER_OTLP_ENDPOINT`) tego czytnika nie otwiera. Bez adresu metryk instrumenty i tak powstają, ale nikt ich nie zbiera: nie ma czytnika (reader). `curl` na `/metrics` nic nie pokaże — tego endpointu jeszcze nie ma.

[07-prometheus.md](07-prometheus.md) dokłada czytnik scrape: eksporter Prometheus. Push OTLP metryk (osobny endpoint, collector) i pull `/metrics` mogą żyć naraz. Prometheus nie czyta OTLP z tego API, a Jaeger nie przyjmuje metryk.

Nazwy zależą od wersji instrumentacji i od `OTEL_SEMCONV_STABILITY_OPT_IN`:

- starszy histogram: `http.server.duration`,
- stabilniejszy: `http.server.request.duration`.

Prometheus zamieni kropki na podkreślenia i dopisze jednostkę, stąd w następnym numerze kształt w rodzaju `http_server_request_duration_seconds`. Nie szukaj tej nazwy w logu API po samym kroku 6.

Etykieta metryki ma mieć małą liczbę wartości. Szablon trasy (`http.route` = `/api/auth/login`) jest bezpieczny — w tym API są cztery stałe ścieżki (`/health`, `/api/auth/register`, `/api/auth/login`, `/api/auth/me`). Surowy URL z mailem albo identyfikatorem użytkownika jako label rozsadza bazę Prometheusa. Email zostaje w body JSON; domyślna instrumentacja ASP.NET body ani nagłówka `Authorization` do spana nie kopiuje.

### Jak czytać trace, gdy stanie Jaeger

UI jest w numerze 08. Żeby wiedzieć, czego szukać:

1. **Service** — `JJDevHub.Api`. Inna nazwa znaczy, że `AddService` dostał inny string niż myślisz.
2. **Operation** — zwykle `POST /api/auth/login` albo `GET /health`.
3. **Oś czasu** — jeden pasek na request. Dziura w środku bez dziecka to najczęściej baza albo CPU w `TokenService`, nie „zgubiony span”. Dziecko pojawi się dopiero po instrumentacji EF albo po wychodzącym `HttpClient`.
4. **Status** — kod 5xx i nieobsłużony wyjątek malują span na błąd. 401 z loginu to zakończone żądanie z `http.response.status_code` (albo starsze `http.status_code`), niekoniecznie czerwień „wyjątek”.
5. **Atrybuty** — metoda, route, status. Brak `db.statement` w tym numerze jest oczekiwany.

Porównanie dwóch loginów: wolniejszy pasek bez dzieci mówi „czas siedzi w tym procesie”. Nie mówi, czy winny jest Postgres. Do tego potrzebny span SQL albo metryka z zewnątrz (np. czas zapytań po stronie bazy).

### Sampling

Domyślny sampler .NET zapisuje każdy trace, gdy rodzic nie nakaże inaczej. Przy jednym API i ruchu z `curl` oraz z własnego frontu zostaw 100%. Gubienie 9 na 10 loginów na tym etapie utrudnia sprawdzenie, czy eksport w ogóle żyje.

Gdy ruch urośnie, head sampling ustawiasz zmiennymi, bez przebudowy obrazu:

```bash
OTEL_TRACES_SAMPLER=parentbased_traceidratio
OTEL_TRACES_SAMPLER_ARG=0.1
```

Decyzja zapada na początku requestu. Wolny login może wypaść z próbki. Tail sampling (zostaw błędne i wolne, resztę odrzuć) robi się w collectorze, po złożeniu całego trace’u. Tego procesu w tym numerze nie ma.

Metryki się nie samplują tym samym pokrętłem. Histogram i tak agreguje wszystko, co doszło do instrumentu.

### Własny span — poza tym krokiem

Przepis kończy się na instrumentacji frameworka. Własny span dokładasz, gdy w jednym requeście chcesz rozdzielić „szukanie użytkownika” od „składanie JWT”, a pasek HTTP jest za gruby. Szkic, którego **nie** commitujesz razem z samym krokiem 6:

```csharp
private static readonly ActivitySource AuthSource = new("JJDevHub.Api.Auth");

using var activity = AuthSource.StartActivity("IssueJwt");
activity?.SetTag("auth.method", "password");
```

`StartActivity` zwraca `null`, gdy żaden SDK nie słucha tego źródła. Stąd `activity?.`. Samo `new ActivitySource` nic nie eksportuje, dopóki tracing nie dostanie tej samej nazwy:

```csharp
tracing.AddSource("JJDevHub.Api.Auth");
```

Tag `enduser.email`, surowe hasło albo `Jwt__Key` na spanie zostają w Jaegerze na stałe. Metoda logowania (`password`) wystarcza.

Konsolowy eksporter (`OpenTelemetry.Exporter.Console`, `AddConsoleExporter()`) wypisuje spany na stdout. Nadaje się do `dotnet run` na chwilę, gdy chcesz zobaczyć drzewo bez Jaegera. Na VM miesza się z logiem aplikacji — do obrazu go nie dodajesz.

### Gdy wynik jest zły

| Objaw | Co sprawdzić |
| --- | --- |
| API nie wstaje, wyjątek przy `new Uri` | `OTEL_EXPORTER_OTLP_ENDPOINT` nie jest pusty, ale nie jest URL-em (`null`, spacja, goły host bez schematu). |
| W logu retry do `127.0.0.1:4317` | Eksporter włączony bez odbiornika. W kontenerze loopback to sam kontener `api`, nie Jaeger i nie host. Albo wyczyść endpoint, albo ustaw `http://jaeger:4317` dopiero gdy serwis z numeru 08 stoi w tej samej sieci Compose. |
| `curl /health` działa, w Jaegerze pusto | Pusty endpoint (eksport wyłączony), zły protokół względem portu, za krótki czas na batch, albo `service.name` inne niż filtr w UI. |
| W UI jest serwis, nie ma `POST /api/auth/login` | Ruch nie doszedł do tego procesu (curl na zły port, nginx nie proxy’uje tej ścieżki) albo oglądasz za krótki zakres czasu. |
| Jest tylko `GET /health` | To ruch, który naprawdę poszedł. Login wygeneruj osobno. Healthcheck `web` spana API nie tworzy. |
| Szukasz spana SQL i go nie ma | Pakiet EF nie jest w kroku 1. Czas bazy siedzi w spanie HTTP. |
| Szukasz spana wychodzącego HTTP | W tym kodzie nie ma wołania `HttpClient`. |
| `curl /metrics` — connection refused albo 404 | Tak ma być po samym tym numerze. Scrape jest w 07. |
| Logi z `docker logs` zniknęły | Ktoś wywołał `ClearProviders()` przed `AddOpenTelemetry`. Konsola ma zostać. |
| Span jest, log obok nie ma `trace_id` | Linia poszła poza requestem albo patrzysz na provider konsoli, a identyfikator jest na rekordzie OTel. |
| Po `docker kill` znika ostatni request | Batch nie zdążył. Do sprawdzenia użyj zwykłego stopu albo odczekaj kilka sekund. |

### Typowe pomyłki

1. **Port 4318 przy protokole `grpc` (albo 4317 przy `http/protobuf`).** Połączenie jest odrzucane, API żyje, UI puste.
2. **`https://` albo `/v1/traces` w adresie gRPC.** Schemat `http://` i sam host z portem.
3. **`http://127.0.0.1:4317` w środowisku kontenera `api`.** To loopback kontenera. Z hosta, przy `dotnet run`, ten adres jest prawdziwy. W Compose odbiornik wołasz po nazwie serwisu.
4. **Bezwarunkowy `AddOtlpExporter()`.** Cichy default na localhost i retry w logu na VM, na której Jaegera jeszcze nie ma.
5. **`UseOtlpExporter()` wzięty z dokumentacji .NET zamiast `if` z kroku 2.** Ten sam default. Przepis jest dłuższy celowo.
6. **OTel dopisany po `builder.Build()`.** Host już złożył providery.
7. **`ClearProviders()`.** Znika log, po którym diagnozujesz start i migrację.
8. **Email, hasło, JWT albo connection string w tagu spana lub w `OTEL_RESOURCE_ATTRIBUTES`.** Resource i atrybuty są indeksowane. Zostają w backendzie dłużej niż linia logu na VM.
9. **`service.name` ustawione na hostname albo nazwę kontenera.** Każdy restart wygląda jak nowy serwis. Nazwa zostaje `JJDevHub.Api`.
10. **Oczekiwanie drzewa EF i HttpClient po samym tym pliku.** Jest jeden span HTTP. Reszta to osobna decyzja, gdy pasek będzie za gruby.
11. **Szukanie `/metrics` albo dashboardu RPS w tym kroku.** Metryki OTLP wychodzą tylko na `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT`. Od numeru 07 dochodzi scrape. Jaeger nie rysuje wykresu requestów na sekundę i nie jest adresem metryk.
12. **Wystawienie 4317 w tunelu Cloudflare.** Telemetria niesie trasy, statusy i czasem fragmenty błędów. Zostaje w sieci Dockera. Tunel dalej publikuje tylko `4200`.
13. **Sampler ratio „na wszelki wypadek” przy pierwszym teście.** Dziewięć na dziesięć `curl` nie trafi do UI i wygląda to jak zepsuty eksport.
14. **Własny `ActivitySource` bez `AddSource`.** `StartActivity` zwraca `null`, spanu nie ma, kod z `?.` po cichu nic nie robi.
15. **Span na każdą linijkę `TokenService`.** Zostaw jeden span HTTP, dopóki nie masz pytania, którego ten pasek nie rozstrzyga.

### Oficjalne źródła

- [opentelemetry.io](https://opentelemetry.io/docs/) — spec sygnałów, semconv, OTLP.
- Spec zmiennych środowiskowych (`OTEL_SERVICE_NAME`, `OTEL_EXPORTER_OTLP_*`, `OTEL_TRACES_SAMPLER`, `OTEL_RESOURCE_ATTRIBUTES`).
- Repozytorium `open-telemetry/opentelemetry-dotnet` — `AddOpenTelemetry`, instrumentacje AspNetCore / Http / Runtime, eksporter OTLP, domyślny endpoint.
- Semconv HTTP: różnica `http.server.duration` kontra `http.server.request.duration` i flaga `OTEL_SEMCONV_STABILITY_OPT_IN`.
- Dokumentacja .NET `UseOtlpExporter` — skrót, którego ten przepis świadomie nie bierze, gdy endpoint bywa pusty.

### Co zapamiętać

OpenTelemetry w tym API to trzy sygnały na żądanie, które i tak obsługuje Kestrel: jeden span HTTP, obserwacja histogramu, log z `trace_id`, gdy linia powstanie w trakcie requestu. Eksport OTLP gRPC tras włącza się adresem Jaegera; metryki i logi mają własne endpointy i na Jaegera nie spadają. Inaczej proces milczy i `/health` działa jak wcześniej. SQL, wychodzące HTTP i scrape `/metrics` do tego numeru nie należą. Kolejny krok zbiera metryki Prometheusem (pull), a trasy oglądasz w Jaegerze pod `service.name` `JJDevHub.Api` i adresem `http://jaeger:4317`.
