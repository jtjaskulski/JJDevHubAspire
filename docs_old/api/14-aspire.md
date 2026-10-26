# Aspire

.NET Aspire składa system w jednym miejscu. `JJDevHub.AppHost` opisuje zasoby: serwer Postgresa z bazami usług, broker Kafka z Kafka UI i projekty usług. `JJDevHub.ServiceDefaults` daje każdej usłudze jednym wywołaniem telemetrię, health checki, service discovery i odporność klienta HTTP. Ten numer podpina istniejące API z [src/api](../../src/api) i zasoby dla News. Kolejne numery dopisują swoje projekty do AppHost: Identity w [15-identity.md](15-identity.md), News i gateway w [16-usluga-news.md](16-usluga-news.md), Notifications w [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).

## Po co

Do tej pory każda biblioteka miała swój kontener w teście, a [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) znał jedno API. Przy pięciu procesach, pięciu bazach i brokerze ręczne Compose i connection stringi w `appsettings.json` przestają się skalować. eShop ma `eShop.AppHost` (zasoby i zależności w C#) i `eShop.ServiceDefaults` (wspólna konfiguracja usług). `aspire run` stawia całość lokalnie z dashboardem logów, śladów i metryk. Ten sam opis zasobów generuje Compose na serwer.

Aspire to też kierunek, w którym idzie .NET. Nowe szablony i integracje (`Aspire.Npgsql.EntityFrameworkCore.PostgreSQL`, `Aspire.Confluent.Kafka`) dostają health checki i telemetrię bez ręcznej konfiguracji.

## Dlaczego ta technologia

### Co robi Aspire

Aspire to zestaw narzędzi .NET do składania aplikacji z wielu procesów. Ma trzy części, które warto rozdzielić w głowie:

1. **AppHost** — zwykły projekt C# (`dotnet run` albo `aspire run`), który opisuje system kodem: „jest Postgres z bazami `news_write` i `news_read`, jest Kafka, jest projekt `News.API`, który potrzebuje obu baz i Kafki”. Przy uruchomieniu AppHost stawia kontenery w Dockerze, startuje projekty .NET jako procesy i wstrzykuje im konfigurację: connection stringi (`ConnectionStrings__news-write`), adresy innych usług (`services__identity-api__http__0`), endpoint OTLP. `WaitFor` pilnuje kolejności: News nie wstanie, zanim baza nie odpowie na health check. AppHost działa tylko w dev i w testach. Na produkcji go nie ma.
2. **Dashboard** — strona pod `https://localhost:17xxx` z listą zasobów, ich stanem, logami konsolowymi, logami strukturalnymi, śladami i metrykami wszystkich procesów w jednym miejscu. Dostaje dane przez OpenTelemetry. Lokalnie zastępuje Jaegera, Prometheusa i Grafanę.
3. **Integracje i ServiceDefaults** — pakiety po stronie usługi (`Aspire.Npgsql.EntityFrameworkCore.PostgreSQL`, `Aspire.Confluent.Kafka`), które jednym wywołaniem rejestrują klienta, health check, ślady i metryki. `ServiceDefaults` to projekt we własnym repo (nie paczka), w którym jest wspólna konfiguracja: OpenTelemetry, `/health` i `/alive`, service discovery, odporność `HttpClient`.

Do tego **publikacja**: `aspire publish` zamienia opis z AppHost na pliki wdrożeniowe. Dla nas to `docker-compose.yaml` na VM. Ten sam model dałby manifesty Kubernetes albo Azure Container Apps, gdyby kiedyś były potrzebne.

### Dlaczego Aspire, a nie ręczny Compose

Ręczny `docker-compose.yml` działa i już go mamy. Przy pięciu usługach zaczyna boleć:

- connection stringi i adresy usług są przepisywane w trzech miejscach (Compose, `appsettings.Development.json`, testy) i rozjeżdżają się,
- debugowanie usługi w IDE przy reszcie w Compose wymaga ręcznego przełączania adresów,
- telemetria lokalnie wymaga własnego Jaegera i Grafany,
- kolejność startu to `depends_on` z healthcheckiem pisanym ręcznie.

AppHost jest kodem C# z typami, więc literówka w nazwie zasobu to błąd kompilacji (`ResourceNames`). Debugowanie: F5 na AppHost startuje wszystko z debuggerem podpiętym do każdego projektu.

### Alternatywy

- **Ręczny Compose + `launchSettings.json`** — zero nowych narzędzi, wszystkie bolączki z listy wyżej.
- **Project Tye** — poprzednik Aspire od Microsoftu, porzucony w 2023.
- **Dapr** (Apache 2.0) — runtime z sidecarami: pub/sub, stan, sekrety za jednym API. Rozwiązuje inny problem (abstrakcja infrastruktury w runtime) i dokłada proces obok każdej usługi. Aspire umie go hostować, gdyby kiedyś był potrzebny.
- **Kubernetes lokalnie (kind, k3d) + Tilt/Skaffold** — realistyczne środowisko, ale ciężkie na laptopie i nie daje typów w C#.

Aspire wygrywa, bo jest natywny dla .NET, darmowy (MIT), rozwijany przez zespół .NET z szablonami w SDK i wspierany przez eShop jako wzorzec. To jest odpowiedź na „co najlepsze i przyszłościowe”.

### Koszt i ryzyko

Aspire zmienia się szybko: API AppHost i publikacji ewoluowało między wersjami 8, 9 i 13. Część kodu w tym numerze może wymagać korekty nazw metod przy aktualizacji. AppHost wymaga Dockera na maszynie dewelopera. Publikacja do Compose jest nowsza niż reszta i nie wszystko, co działa w `aspire run`, ma odpowiednik w Compose (np. dashboard trzeba dodać jawnie albo zostać przy Jaegerze i Grafanie na VM). Dlatego telemetria na VM zostaje taka jak w [docs/CICD](../CICD/README.md).

### ServiceDefaults jako projekt, nie paczka

Szablon generuje `ServiceDefaults` jako kod w repo. To celowe: każdy zespół zmienia go pod siebie (u nas eksporter Prometheusa i `AddDefaultAuthentication` z [15-identity.md](15-identity.md)), a paczka NuGet wymuszałaby jedną konfigurację dla wszystkich. Koszt: podbicie wspólnego zachowania jest zmianą w tym repo, nie wersją paczki.

### Globalny handler wyjątków w ServiceDefaults

Oczekiwany błąd to `Result<T>` i zamienia się na kod HTTP w endpointach usługi ([16-usluga-news.md](16-usluga-news.md)). Zostaje wyjątek: zerwane połączenie z bazą, błąd serializacji, błąd składu. Bez obsługi ASP.NET Core zwraca pusty `500`, a ślad w Jaegerze ma status `Unset`, więc w widoku błędów go nie widać.

`IExceptionHandler` (ASP.NET Core od 8) to interfejs, który middleware `UseExceptionHandler` woła po kolei dla każdego zarejestrowanego handlera. Jeden handler w ServiceDefaults daje każdej usłudze to samo zachowanie: log `Error` z wyjątkiem, `Activity.SetStatus(ActivityStatusCode.Error)` i zdarzenie `exception` na bieżącym spanie oraz odpowiedź `500` jako ProblemDetails z `traceId`, bez treści wyjątku. Użytkownik dostaje identyfikator, po którym znajdzie się ślad i linia logu.

Alternatywy:

- **Middleware pisany ręcznie** (`try`/`catch` wokół `next`) — robi to samo, ale omija `IProblemDetailsService` i trzeba samemu pilnować, żeby odpowiedź nie była już rozpoczęta.
- **`UseDeveloperExceptionPage`** — tylko dev, pokazuje stos. Zostaje w dev jako domyślne zachowanie szablonu.
- **Filtr na grupie endpointów** — łapie tylko wyjątki z handlerów endpointów, a nie z middleware i workerów hostowanych przez HTTP.

Koszt: jedna klasa i dwa wywołania. Handler nie zamienia wyjątków na `400` ani `404`. To byłoby sterowanie przepływem wyjątkami, a od tego jest `Result<T>`.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/aspire/JJDevHub.AppHost/JJDevHub.AppHost.csproj` | SDK `Aspire.AppHost.Sdk`, `Aspire.Hosting.PostgreSQL`, `Aspire.Hosting.Kafka`, `Aspire.Hosting.Docker` |
| `src/aspire/JJDevHub.AppHost/AppHost.cs` | zasoby i projekty |
| `src/aspire/JJDevHub.AppHost/ResourceNames.cs` | stałe nazw zasobów (`news-write`, `kafka`…) |
| `src/aspire/JJDevHub.ServiceDefaults/JJDevHub.ServiceDefaults.csproj` | `IsAspireSharedProject`, OpenTelemetry, service discovery, resilience |
| `src/aspire/JJDevHub.ServiceDefaults/ServiceDefaultsExtensions.cs` | `AddServiceDefaults`, `MapDefaultEndpoints` |
| `src/aspire/JJDevHub.ServiceDefaults/TelemetryExtensions.cs` | OTel: zasoby, źródła, mierniki, eksportery, filtr |
| `src/aspire/JJDevHub.ServiceDefaults/OtlpEndpoints.cs` | adres OTLP na sygnał, puste → `null` |
| `src/aspire/JJDevHub.ServiceDefaults/RootClientSpanSampler.cs` | odrzuca span klienta bez rodzica |
| `src/aspire/JJDevHub.ServiceDefaults/HealthCheckExtensions.cs` | `self`, tagi `live` |
| `src/aspire/JJDevHub.ServiceDefaults/GlobalExceptionHandler.cs` | `IExceptionHandler`: log, status spanu, `500` ProblemDetails z `traceId` |
| `src/api/Program.cs` | `AddServiceDefaults()` zamiast ręcznego OTel, `MapDefaultEndpoints()` |
| `src/building-blocks/JJDevHub.Cqrs`, `JJDevHub.Projections`, `JJDevHub.IntegrationEventLog`, `JJDevHub.EventBus.Kafka` | `ActivitySource` i `Meter` o nazwie projektu |
| `tests/JJDevHub.AppHost.Tests/` | `Aspire.Hosting.Testing` |

## Plan

### 1. Projekty

Szablony z pakietu `Aspire.ProjectTemplates` (`dotnet new install Aspire.ProjectTemplates`):

```bash
dotnet new aspire-apphost -n JJDevHub.AppHost -o src/aspire/JJDevHub.AppHost
dotnet new aspire-servicedefaults -n JJDevHub.ServiceDefaults -o src/aspire/JJDevHub.ServiceDefaults
dotnet new aspire-xunit -n JJDevHub.AppHost.Tests -o tests/JJDevHub.AppHost.Tests
dotnet sln add src/aspire/JJDevHub.AppHost src/aspire/JJDevHub.ServiceDefaults tests/JJDevHub.AppHost.Tests
dotnet add src/aspire/JJDevHub.AppHost reference src/api
dotnet add src/api reference src/aspire/JJDevHub.ServiceDefaults
dotnet add tests/JJDevHub.AppHost.Tests reference src/aspire/JJDevHub.AppHost
```

Wersje `Aspire.*` idą do [Directory.Packages.props](../../Directory.Packages.props). Wersja SDK AppHost jest w `JJDevHub.AppHost.csproj` (`<Project Sdk="Aspire.AppHost.Sdk/…">`), a [global.json](../../global.json) może ją przypiąć w `msbuild-sdks`. Szablon generuje kod ServiceDefaults. Zostaje on rozbity na trzy pliki według reguły jednego typu na plik.

### 2. Zasoby

`ResourceNames` trzyma stałe: `postgres`, `news-write`, `news-read`, `identity`, `notifications`, `kafka`, `api`. Te same nazwy czytają usługi jako `ConnectionStrings:<nazwa>`.

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var postgres = builder.AddPostgres(ResourceNames.Postgres)
    .WithImageTag("16-alpine")
    .WithDataVolume()
    .WithLifetime(ContainerLifetime.Persistent);

var newsWrite = postgres.AddDatabase(ResourceNames.NewsWrite, "news_write");
var newsRead = postgres.AddDatabase(ResourceNames.NewsRead, "news_read");
var jjdevhub = postgres.AddDatabase("DefaultConnection", "jjdevhub");

var kafka = builder.AddKafka(ResourceNames.Kafka)
    .WithKafkaUI()
    .WithDataVolume()
    .WithLifetime(ContainerLifetime.Persistent);

builder.AddProject<Projects.JJDevHub_Api>(ResourceNames.Api)
    .WithReference(jjdevhub)
    .WaitFor(jjdevhub);

builder.Build().Run();
```

- Postgres jest jeden, bazy są osobne. Obraz `16-alpine`, ten sam co w testach.
- `Persistent` zostawia kontenery między uruchomieniami `aspire run`, więc dane dev nie znikają.
- Baza obecnego API dostaje nazwę zasobu `DefaultConnection`. Istniejący `GetConnectionString("DefaultConnection")` działa bez zmian do [15-identity.md](15-identity.md).
- `newsWrite`, `newsRead` i `kafka` nie mają jeszcze odbiorcy. Projekt `News.API` podepnie je w `16`. Zmienne zostają, żeby `16` dopisał tylko jeden blok.
- Hasło Postgresa i klucz JWT to parametry Aspire (`builder.AddParameter("jwt-key", secret: true)`). W dev biorą się z user secrets AppHost, nie z repozytorium.

### 3. ServiceDefaults

`AddServiceDefaults(this IHostApplicationBuilder builder)`:

- `ConfigureOpenTelemetry`:
  - logi przez OTel z `IncludeFormattedMessage` i `IncludeScopes`,
  - metryki: ASP.NET Core, `HttpClient`, runtime, eksporter Prometheus (`/metrics` zostaje, jak dziś w [src/api/Program.cs](../../src/api/Program.cs)),
  - ślady: ASP.NET Core, `HttpClient`, `Npgsql`, źródła `JJDevHub.*` z bibliotek,
  - metryki z mierników `JJDevHub.*` z kroku 4 (`AddMeter`),
  - eksport OTLP osobno na każdy sygnał (krok 3a), bez `UseOtlpExporter()`,
  - filtr i sampler śladów (krok 3b),
- `AddDefaultHealthChecks`: check `self` z tagiem `live`,
- `AddServiceDiscovery`,
- `ConfigureHttpClientDefaults`: `AddStandardResilienceHandler` i `AddServiceDiscovery`.

`MapDefaultEndpoints(this WebApplication app)`:

- `/health` — wszystkie checki: baza, Kafka, `self`,
- `/alive` — tylko tag `live`,
- `/metrics` — Prometheus.

Obecne ręczne `MapGet("/health")` i blok `AddOpenTelemetry` w [src/api/Program.cs](../../src/api/Program.cs) znikają na rzecz tych dwóch wywołań. Test `AuthAndHealthTests` sprawdza dalej `/health` z kodem 200.

### 3a. Endpointy OTLP na sygnał

Szablon ServiceDefaults woła `UseOtlpExporter()`, gdy ustawione jest `OTEL_EXPORTER_OTLP_ENDPOINT`. To wysyła ślady, metryki i logi na jeden adres. W dev to dobrze, bo dashboard Aspire przyjmuje wszystkie trzy. Na VM tym adresem jest Jaeger, który przyjmuje tylko ślady, a metryki i logi wisiałyby w ponowieniach. [docs/CICD/06-opentelemetry.md](../CICD/06-opentelemetry.md) opisuje ten problem i ten sam warunkowy `if`, który tu przechodzi do ServiceDefaults.

`OtlpEndpoints.Resolve(IConfiguration)` zwraca trzy adresy (`Uri?`) według specyfikacji OpenTelemetry:

| Sygnał | Zmienna własna | Zapas |
| --- | --- | --- |
| ślady | `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| metryki | `OTEL_EXPORTER_OTLP_METRICS_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` |
| logi | `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` | `OTEL_EXPORTER_OTLP_ENDPOINT` |

Pusty albo biały string to `null`, jak `OtelSetting` z 06, żeby `new Uri` nie wywrócił startu. `AddOtlpExporter` jest wołany tylko dla sygnału z niepustym adresem.

- dev: Aspire ustawia `OTEL_EXPORTER_OTLP_ENDPOINT` na dashboard, więc idą wszystkie trzy sygnały,
- VM: ustawione jest tylko `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://jaeger:4317`, a `OTEL_EXPORTER_OTLP_ENDPOINT` zostaje puste. Ślady idą do Jaegera, metryki zbiera Prometheus z `/metrics`, logi zostają w `docker logs` z `trace_id`.

To jest zmiana względem 06 i 08, gdzie adres Jaegera siedzi w `OTEL_EXPORTER_OTLP_ENDPOINT`. Przestawienie env na VM robi [18-ci-uslug.md](18-ci-uslug.md). Do tego czasu obecne API działa ze starym env bez zmian, bo z jego `api.env` metryki i logi i tak nie mają adresu.

### 3b. Ślady bez szumu tła

Na VM Jaeger trzyma najwyżej 10 000 śladów w pamięci ([docs/CICD/08-jaeger.md](../CICD/08-jaeger.md)). Przy pięciu usługach szum zjadłby ten limit w godziny:

- Prometheus co 15 s pyta `/metrics` każdej usługi,
- `ProjectionWorker` i `OutboxDispatcher` co chwilę pytają bazę, a instrumentacja Npgsql robi z każdego pustego zapytania osobny ślad.

Dwie reguły:

- `AddAspNetCoreInstrumentation(o => o.Filter = ...)` odrzuca żądania na `/health`, `/alive` i `/metrics`,
- `RootClientSpanSampler : Sampler` w ServiceDefaults, opakowany w `ParentBasedSampler`, odrzuca span bez rodzica o rodzaju `ActivityKind.Client`. Zapytanie Npgsql z pustej pętli workera nie ma rodzica, więc znika. To samo zapytanie wewnątrz żądania HTTP albo wewnątrz spanu workera ma rodzica i zostaje.

Workery otwierają własny span dopiero wtedy, gdy jest praca (krok 4). Pusty obieg pętli nie zostawia śladu, a obieg z pracą pokazuje się jako jedno drzewo: `project article-summaries` → zapytania Npgsql.

### 3c. Nazwa usługi

Aspire ustawia `OTEL_SERVICE_NAME` na nazwę zasobu: `api` w tym numerze, potem `identity-api`, `news-api`, `notifications-worker`, `gateway`. W telemetrii obowiązuje ta nazwa, a nie `JJDevHub.Api` z 06. Wygenerowany Compose ustawia tę samą zmienną. Filtry w Jaegerze i Grafanie przechodzą na nowe nazwy w [18-ci-uslug.md](18-ci-uslug.md), razem z celami Prometheusa.

### 3d. Nieoczekiwany wyjątek

`AddServiceDefaults` rejestruje `AddProblemDetails()` i `AddExceptionHandler<GlobalExceptionHandler>()`. `MapDefaultEndpoints` woła `app.UseExceptionHandler()` poza `Development`. W dev zostaje strona wyjątku ze stosem.

```csharp
namespace JJDevHub.ServiceDefaults
{
    public sealed class GlobalExceptionHandler(
        IProblemDetailsService problemDetails,
        ILogger<GlobalExceptionHandler> logger) : IExceptionHandler
    {
        public async ValueTask<bool> TryHandleAsync(
            HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
        {
            string path = httpContext.Request.Path.ToString()
                .Replace("\r", string.Empty)
                .Replace("\n", string.Empty);
            logger.LogError(exception, "Unhandled exception on {Path}", path);
            Activity.Current?.AddException(exception);
            Activity.Current?.SetStatus(ActivityStatusCode.Error);

            httpContext.Response.StatusCode = StatusCodes.Status500InternalServerError;
            return await problemDetails.TryWriteAsync(new ProblemDetailsContext
            {
                HttpContext = httpContext,
                Exception = exception,
                ProblemDetails =
                {
                    Title = "Unexpected error",
                    Extensions = { ["traceId"] = Activity.Current?.TraceId.ToString() ?? httpContext.TraceIdentifier },
                },
            });
        }
    }
}
```

Treść wyjątku nie trafia do odpowiedzi. Ścieżka żądania w logu ma usunięte `\r` i `\n`, żeby wpis nie rozbił się na drugą linię. `OperationCanceledException` przy przerwanym żądaniu (`httpContext.RequestAborted.IsCancellationRequested`) idzie do logu na poziomie `Debug` zamiast `Error`, bez statusu `Error` na spanie: klient sam zrezygnował i odpowiedzi już nie czyta.

### 4. Źródła śladów i mierniki w bibliotekach

Każda biblioteka z pracą w tle albo na granicy ma statyczne `ActivitySource` o nazwie projektu:

- `JJDevHub.Cqrs` — span `Send {RequestName}` w `LoggingBehavior`,
- `JJDevHub.Projections` — span `project {ProjectionName}` tylko na przejście, które dostało zdarzenia,
- `JJDevHub.IntegrationEventLog` — span `outbox dispatch` tylko na paczkę z wierszami, span na odbiór w inboxie,
- `JJDevHub.EventBus.Kafka` — span `publish {topic}` i `process {topic}`, z `traceparent` z [13-kafka.md](13-kafka.md).

Te same biblioteki dostają statyczny `Meter` o nazwie projektu. Mierzą zdrowie potoku, którego nie widać w metrykach HTTP:

| Miernik | Typ | Etykiety | Kto zapisuje |
| --- | --- | --- | --- |
| `jjdevhub.projection.lag` | gauge | `projection` | runner: najwyższe `Position` w magazynie minus checkpoint |
| `jjdevhub.outbox.pending` | gauge | — | dispatcher: liczba wierszy bez `ProcessedOn` po ostatnim przejściu |
| `jjdevhub.outbox.failed` | counter | `event_type` | dispatcher: nieudana wysyłka |
| `jjdevhub.kafka.consumer.lag` | gauge | `topic`, `partition`, `group` | konsument: high watermark minus pozycja, z `GetWatermarkOffsets` |
| `jjdevhub.kafka.dlq` | counter | `topic` | konsument: wiadomość przeniesiona do `*.dlq` |
| `jjdevhub.inbox.duplicates` | counter | `consumer` | odbiornik: `ReceiveOutcome.Duplicate` |

Gauge to `Meter.CreateObservableGauge` z wartością zapamiętaną przez pętlę, a nie zapytanie do bazy przy każdym scrapie. Etykiety mają małą liczbę wartości ([docs/CICD/07-prometheus.md](../CICD/07-prometheus.md)): bez id zdarzeń i id użytkowników. W Prometheusie nazwy dostają podkreślenia (`jjdevhub_projection_lag`).

`System.Diagnostics.ActivitySource` i `System.Diagnostics.Metrics.Meter` są w platformie. Biblioteki nie dostają pakietu OpenTelemetry. ServiceDefaults rejestruje je przez `AddSource("JJDevHub.*")` i `AddMeter("JJDevHub.*")`.

### 5. Klienci Aspire w usługach

Od `16` usługi biorą połączenia przez integracje klienckie zamiast własnych `UseNpgsql`:

```csharp
builder.AddNpgsqlDbContext<NewsWriteContext>(
    ResourceNames.NewsWrite,
    settings => settings.DisableRetry = true);
builder.AddKafkaProducer<string, string>(ResourceNames.Kafka);
```

Integracja dodaje health check, ślady i metryki. Domyślnie włącza też `NpgsqlRetryingExecutionStrategy`, a ta strategia rzuca `InvalidOperationException` przy transakcji otwartej ręcznie (`BeginTransactionAsync` w `NewsUnitOfWork`). Konteksty, w których `TransactionBehavior` albo outbox otwiera transakcję (`news-write`, `identity`, `notifications`), dostają `DisableRetry = true`. Ponowienie całej komendy po błędzie przejściowym zostaje dla klienta HTTP i dla konsumenta Kafki, który i tak ponawia. Kontekst tylko do odczytu (`news-read`) zostaje z ponowieniami. `AddNewsWrite` z [09-komenda.md](09-komenda.md) i `AddNewsRead` z [10-projekcja.md](10-projekcja.md) dostają przeciążenia bez connection stringa, które pomijają `AddDbContext`. `AddKafkaEventBus` z [13-kafka.md](13-kafka.md) bierze `IProducer<string, string>` z DI, gdy już jest zarejestrowany.

### 6. Publikacja na VM

AppHost dostaje środowisko Compose:

```csharp
builder.AddDockerComposeEnvironment("jjdevhub");
```

`aspire publish -o artifacts/compose` generuje `docker-compose.yaml` i `.env` z parametrami. Katalog `artifacts/` jest w `.gitignore`. Generuje go CI w [18-ci-uslug.md](18-ci-uslug.md). Prometheus, Jaeger i Grafana zostają w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) i łączą się z usługami przez wspólną zewnętrzną sieć Dockera `jjdevhub`. Sieć dopina `PublishAsDockerComposeService` na każdym projekcie. Nazwy metod publikacji zmieniały się między wersjami Aspire, więc przed implementacją trzeba je sprawdzić w dokumentacji wersji z `Directory.Packages.props`.

### Co jest do czego

- `JJDevHub.AppHost` — jedno źródło prawdy o tym, co się uruchamia i od czego zależy. `aspire run` w dev, `aspire publish` na serwer.
- `ResourceNames` — nazwy zasobów współdzielone z usługami. Literówka jest błędem kompilacji, a nie pustym connection stringiem.
- `AddPostgres` + `AddDatabase` — jeden serwer, baza na usługę, zgodnie z [architektura.md](architektura.md).
- `AddKafka().WithKafkaUI()` — broker w trybie KRaft i podgląd tematów, w tym DLQ.
- `WaitFor` — usługa startuje, gdy baza odpowiada. Bez wyścigu przy migracji.
- `JJDevHub.ServiceDefaults` — każda usługa ma te same endpointy zdrowia, tę samą telemetrię i odporny `HttpClient`.
- `ActivitySource` w bibliotekach — ślad przechodzi od `POST` przez outbox i Kafkę do konsumenta.
- `Meter` w bibliotekach — opóźnienie projekcji, zaległy outbox i lag konsumenta. Przy tej architekturze to są pierwsze liczby, na które patrzysz, gdy „artykuł się nie pokazuje”.
- `OtlpEndpoints` — ślady do Jaegera, metryki do Prometheusa, każdy sygnał tam, gdzie ktoś go przyjmuje.
- `RootClientSpanSampler` i filtr ścieżek — Jaeger pokazuje żądania i pracę, a nie scrape i puste pętle.
- `GlobalExceptionHandler` — awaria w dowolnej usłudze kończy się tym samym `500` z `traceId`, czerwonym spanem i linią logu. Od `traceId` z odpowiedzi do przyczyny jest jedno wyszukiwanie.
- `AddDockerComposeEnvironment` — most do obecnego deployu na VM przez Compose.

## Testy

Projekt `tests/JJDevHub.AppHost.Tests`, klasa `AppHostTests`. `DistributedApplicationTestingBuilder.CreateAsync<Projects.JJDevHub_AppHost>()`, start, `ResourceNotifications.WaitForResourceHealthyAsync`. Wymaga Dockera na runnerze. Timeout testu: 3 minuty.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Api_becomes_healthy` | aplikacja uruchomiona | `GET /health` na `api` | 200 |
| `Api_exposes_alive` | aplikacja uruchomiona | `GET /alive` na `api` | 200 |
| `Postgres_has_service_databases` | aplikacja uruchomiona | `SELECT datname FROM pg_database` przez connection string `postgres` | są `news_write`, `news_read`, `jjdevhub` |
| `Kafka_becomes_healthy` | aplikacja uruchomiona | `WaitForResourceHealthyAsync("kafka")` | bez timeoutu |

Klasa `TelemetryConfigurationTests` w tym samym projekcie, bez uruchamiania AppHost. `ConfigurationBuilder.AddInMemoryCollection`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Shared_endpoint_feeds_all_signals` | tylko `OTEL_EXPORTER_OTLP_ENDPOINT` | `Resolve` | trzy równe adresy |
| `Traces_endpoint_does_not_feed_metrics` | tylko `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | `Resolve` | ślady ustawione, metryki i logi `null` |
| `Blank_endpoint_is_null` | `OTEL_EXPORTER_OTLP_ENDPOINT = " "` | `Resolve` | trzy `null` |
| `Root_client_span_is_dropped` | `SamplingParameters` bez rodzica, `ActivityKind.Client` | `ShouldSample` | `Drop` |
| `Root_server_span_is_kept` | bez rodzica, `ActivityKind.Server` | `ShouldSample` | `RecordAndSample` |

Klasa `GlobalExceptionHandlerTests` w tym samym projekcie. `WebApplication.CreateSlimBuilder()` z `AddServiceDefaults()`, `WebHost.UseTestServer()` (`Microsoft.AspNetCore.TestHost` przychodzi z `Microsoft.AspNetCore.Mvc.Testing`), środowisko `Production`, endpoint `/boom` rzucający `InvalidOperationException("secret detail")`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Unhandled_exception_returns_problem_500` | host z `/boom` | `GET /boom` | `500`, `Content-Type` `application/problem+json` |
| `Problem_has_trace_id` | host z `/boom` | `GET /boom` | pole `traceId` niepuste |
| `Problem_hides_exception_message` | host z `/boom` | `GET /boom` | treść bez `secret detail` |

Istniejące `tests/JJDevHub.Api.Tests` przechodzą bez zmian poza endpointem `/health`, który daje teraz ServiceDefaults.

`dotnet test tests/JJDevHub.AppHost.Tests` i `dotnet test tests/JJDevHub.Api.Tests`.

## Zasady

- Nazwy zasobów są stałymi w `ResourceNames` i są nazwami connection stringów w usługach.
- Usługa woła `AddServiceDefaults()` i `MapDefaultEndpoints()` jako pierwsze i ostatnie wywołanie konfiguracji.
- Sekrety to parametry Aspire. W dev są w user secrets, na VM w `/etc/jjdevhub/<usługa>.env`. W repozytorium ich nie ma.
- Biblioteki budulcowe nie referencjonują Aspire ani OpenTelemetry. Mają tylko `ActivitySource` i `Meter` z platformy.
- Każdy sygnał OTLP ma własny adres. Metryki i logi nie idą na adres Jaegera.
- Etykieta metryki nie zawiera identyfikatora zdarzenia, użytkownika ani adresu e-mail.
- Jedna baza na usługę, nawet gdy serwer jest wspólny.
- Nieoczekiwany wyjątek kończy się `500` ProblemDetails z `traceId`. Treść wyjątku jest tylko w logu i w spanie.

## Poza zakresem

- Kubernetes, Helm i `aspire publish` do Azure.
- Zastąpienie Prometheusa, Jaegera i Grafany dashboardem Aspire na serwerze. Dashboard jest dla dev.
- Backend logów na VM (Loki, OpenSearch). Logi zostają w `docker logs` z `trace_id`, a ślad prowadzi do linii logu.
- Zmiana env, celów Prometheusa i dashboardów na VM — [18-ci-uslug.md](18-ci-uslug.md).
- Identity, News.API, Notifications w AppHost — numery `15`–`17`.
- Pipeline publikacji — [18-ci-uslug.md](18-ci-uslug.md).

## Źródła

- [.NET Aspire overview](https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview) — AppHost, zasoby, integracje.
- [Service defaults](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/service-defaults) — `AddServiceDefaults`, health checks, OTel, resilience.
- [Aspire PostgreSQL integration](https://learn.microsoft.com/en-us/dotnet/aspire/database/postgresql-entity-framework-integration) — `AddPostgres`, `AddDatabase`, `AddNpgsqlDbContext`.
- [Aspire Apache Kafka integration](https://learn.microsoft.com/en-us/dotnet/aspire/messaging/kafka-integration) — `AddKafka`, `WithKafkaUI`, `AddKafkaProducer`.
- [Aspire testing](https://learn.microsoft.com/en-us/dotnet/aspire/testing/write-your-first-test) — `DistributedApplicationTestingBuilder`.
- [Aspire deployment with Docker Compose](https://learn.microsoft.com/en-us/dotnet/aspire/deployment/overview) — `aspire publish` i środowisko Compose.
- [dotnet/eShop — eShop.AppHost](https://github.com/dotnet/eShop/tree/main/src/eShop.AppHost) i [eShop.ServiceDefaults](https://github.com/dotnet/eShop/tree/main/src/eShop.ServiceDefaults) — wzorzec składu.
- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/dotnet/) — źródła, eksportery OTLP i Prometheus.
- [OTLP exporter configuration](https://opentelemetry.io/docs/specs/otel/protocol/exporter/) — zmienne `OTEL_EXPORTER_OTLP_*` na sygnał i zapas na wspólny adres.
- [Sampling](https://opentelemetry.io/docs/concepts/sampling/) — `ParentBased` i własny sampler korzenia.
- [.NET metrics instrumentation](https://learn.microsoft.com/en-us/dotnet/core/diagnostics/metrics-instrumentation) — `Meter`, `CreateObservableGauge`, `Counter`.
- [docs/CICD/06-opentelemetry.md](../CICD/06-opentelemetry.md) i [08-jaeger.md](../CICD/08-jaeger.md) — dlaczego metryki i logi nie idą do Jaegera i skąd limit śladów.
- [Handle errors in ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling) — `IExceptionHandler`, `UseExceptionHandler`, `IProblemDetailsService`.

## Gotowe gdy

- `aspire run` stawia Postgresa z bazami `jjdevhub`, `news_write`, `news_read`, Kafkę z Kafka UI i istniejące API.
- API ma `/health`, `/alive` i `/metrics` z `MapDefaultEndpoints`, a ręczny blok OTel zniknął z `Program.cs`.
- W dashboardzie Aspire nie ma śladów `/metrics`, `/health` ani pustych zapytań workerów.
- `curl /metrics` pokazuje serie `jjdevhub_*` z kroku 4 dla bibliotek, które działają w procesie.
- `aspire publish -o artifacts/compose` generuje plik Compose bez sekretów w treści.
- Wyjątek w endpoincie poza dev zwraca `500` ProblemDetails z `traceId`, a span w dashboardzie ma status `Error`.
- `dotnet test tests/JJDevHub.AppHost.Tests` i `dotnet test tests/JJDevHub.Api.Tests` kończą się kodem 0.
