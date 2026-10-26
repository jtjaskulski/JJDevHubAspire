# Usługa News

`News.API` jest hostem usługi: składa warstwy z numerów `01`–`13`, wystawia endpointy artykułów i bierze autora z tokenu. `JJDevHub.Gateway` na YARP staje przed usługami jako jedno wejście dla klienta web. Komendy i zapytania są w [09-komenda.md](09-komenda.md) i [11-zapytanie.md](11-zapytanie.md). Walidacja tokenu przychodzi z [15-identity.md](15-identity.md). AppHost z [14-aspire.md](14-aspire.md) dostaje dwa projekty.

## Po co

Do tej pory News był zestawem bibliotek z testami. Ten numer daje mu proces: HTTP, workery w tle (projekcja, dispatcher outboxa) i migracje w dev. Endpoint robi tylko trzy rzeczy: zamienia HTTP na komendę albo zapytanie, woła `Send` i zamienia `Result<T>` na kod HTTP. eShop robi tak samo w `Ordering.API/Apis/OrdersApi.cs`.

Optymistyczna współbieżność dochodzi do klienta przez standard HTTP. `GET` zwraca `ETag` z wersją, a `PUT` wymaga `If-Match`. Klient, który edytował starą wersję, dostaje `412` zamiast nadpisać cudzą zmianę.

Gateway daje klientowi jeden adres. Klient nie wie, która usługa obsługuje `/api/articles`, a która `/api/auth`. W eShop tę rolę pełni `WebApp` z YARP.

## Dlaczego ta technologia

### Minimal API zamiast kontrolerów

Obecne API używa Minimal API, eShop też (`OrdersApi.cs` z `MapGroup`). Endpoint to jedna metoda, która zamienia HTTP na komendę, a logika jest w handlerze. Kontrolery dawały strukturę (filtry, model binding, konwencje), która przy cienkich endpointach jest narzutem. Minimal API jest szybsze przy starcie, zgodne z Native AOT i ma `TypedResults`, które opisują odpowiedzi w OpenAPI bez atrybutów.

### `ETag` i `If-Match` zamiast wersji w treści

Wersja mogłaby jechać w JSON-ie (`{ "version": 3, ... }`). Standard HTTP ma na to nagłówki: `ETag` w odpowiedzi `GET` i `If-Match` w `PUT`. Nieaktualna wersja daje `412 Precondition Failed`, brak nagłówka daje `428 Precondition Required`. Zalety: cache i proxy rozumieją `ETag`, klient HTTP nie musi znać kształtu treści, a semantyka jest opisana w RFC 9110. Koszt: klient web musi czytać nagłówek, a nie pole.

### ProblemDetails dla błędów

`Result<T>` z błędem zamienia się na odpowiedź `application/problem+json` (RFC 9457) z `type`, `title`, `status`. Jeden kształt błędu w całym systemie, obsługiwany przez `AddProblemDetails` w ASP.NET Core i rozumiany przez generatory klientów OpenAPI. Nieoczekiwany wyjątek dostaje ten sam kształt z `GlobalExceptionHandler` z [14-aspire.md](14-aspire.md).

`ResultError.Invalid` to `400`, a nie `422 Unprocessable Content`. RFC 9110 pozwala na oba: `422` znaczy „składnia poprawna, treść nie do przyjęcia”, `400` obejmuje też ten przypadek. `ValidationProblem` w ASP.NET Core i walidacja modelu domyślnie zwracają `400`, więc pusty tytuł z walidatora i zły JSON z bindera mają ten sam kod. Klient reaguje na oba tak samo: pokazuje błędy pól z `errors`. Drugi kod nie zmieniłby żadnej decyzji po stronie klienta, a rozdzielałby jeden przypadek na dwa.

### Wersjonowanie API

Klient web wdraża się razem z usługami, więc zmiana kontraktu HTTP i nowy bundle trafiają na serwer jednym deployem. Klient mobilny ([src/Clients/mobile](../../src/Clients/mobile)) tak nie działa: stara wersja aplikacji zostaje na telefonach tygodniami. Zmiana, która łamie kształt odpowiedzi, musi wtedy żyć obok starej. To jest powód wersjonowania, a nie moda.

`Asp.Versioning.Http` (MIT, .NET Foundation) to biblioteka wersjonowania dla Minimal API. Grupa endpointów dostaje zestaw wersji (`ApiVersionSet`), wersja przychodzi w nagłówku `api-version`, a odpowiedź niesie `api-supported-versions` i `api-deprecated-versions`. Żądanie bez nagłówka dostaje wersję domyślną `1.0`, więc dzisiejszy klient web i ścieżki z [docs/frontend](../frontend/README.md) działają bez zmian. Nieznana wersja kończy się `400` ProblemDetails.

Alternatywy:

- **Segment w ścieżce** (`/api/v1/articles`) — najczytelniejszy w logach i w cache, ale zmienia każdą ścieżkę: trasy gatewaya, `nginx.conf`, proxy Vite i `fetch` przy logowaniu. Przy jednej wersji to koszt bez zysku. Biblioteka obsługuje segment, więc przejście jest zmianą czytnika wersji, gdy pojawi się `2.0`.
- **Typ mediów** (`Accept: application/json;v=2`) — poprawny w teorii REST, niewygodny w kliencie i w narzędziach do testów.
- **Bez wersjonowania, tylko zmiany addytywne** — działa, dopóki nikt nie usuwa pola. Pierwsza zmiana łamiąca psuje stare aplikacje mobilne bez ostrzeżenia.

Koszt: jeden pakiet, jedno wywołanie w składzie i `WithApiVersionSet` na grupie. Kontrakty na szynie wersjonują się osobno, przez sufiks nazwy (`.v1`) z [12-outbox-inbox.md](12-outbox-inbox.md).

### YARP jako gateway

Gateway daje usługom jeden punkt wejścia za nginx z kontenera `web`: jedno miejsce na trasy, limity i nagłówki przekazania. Nginx zostaje, bo serwuje pliki klienta web i jest originem tunelu. Opcje dla samego routingu do usług:

- **YARP** (MIT) — reverse proxy Microsoftu jako biblioteka ASP.NET Core. Konfiguracja w kodzie albo `appsettings`, integracja z service discovery Aspire (`http://news-api` rozwiązywane przez Aspire), telemetria przez ServiceDefaults jak w każdej usłudze. eShop używa go w `WebApp`.
- **sam nginx z `web` / Traefik / Caddy** — dojrzałe proxy, ale osobna konfiguracja w innym języku, bez service discovery Aspire i bez wspólnej telemetrii. W dev pod `aspire run` nginx w ogóle nie działa, więc trasy trzeba by trzymać w dwóch miejscach.
- **Ocelot** (MIT) — gateway .NET, starszy, rozwijany wolniej niż YARP.
- **Bez gatewaya** — nginx zna adres każdej usługi, a każda nowa trasa to zmiana w obrazie klienta web.

Gateway nie waliduje tokenu, tylko przekazuje nagłówek. Gdyby walidował, usługi i tak musiałyby sprawdzać token (obrona w głąb), więc logika byłaby podwójna.

### Workery w procesie API

Projekcja i dispatcher outboxa działają jako `BackgroundService` w procesie `News.API`. Osobny proces workera byłby czystszy przy skalowaniu (dwie repliki API, jeden worker), ale na jednej VM to drugi kontener bez korzyści. `SKIP LOCKED` w dispatcherze i idempotentna projekcja sprawiają, że dwie repliki z workerami są bezpieczne, gdy kiedyś powstaną.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/News/News.API/News.API.csproj` | Web SDK, referencje do Application, Infrastructure, ServiceDefaults, `JJDevHub.EventBus.Kafka` |
| `src/services/News/News.API/Program.cs` | skład |
| `src/services/News/News.API/Articles/ArticleEndpoints.cs` | `MapArticles` |
| `src/services/News/News.API/Articles/CreateArticleRequest.cs` | `Title`, `Body` |
| `src/services/News/News.API/Articles/ReviseArticleRequest.cs` | `Title`, `Body` |
| `src/services/News/News.API/Http/ResultHttpExtensions.cs` | `ResultError` → `IResult` |
| `src/services/News/News.API/Http/EntityTag.cs` | `ETag` ↔ wersja |
| `src/services/News/News.API/Http/CurrentUser.cs` | `sub` z tokenu |
| `src/services/News/News.API/Migrations/DevelopmentMigrator.cs` | `MigrateAsync` obu kontekstów tylko w dev |
| `src/aspire/JJDevHub.ServiceDefaults/ApiVersioningExtensions.cs` | `AddDefaultApiVersioning`: nagłówek `api-version`, domyślnie `1.0` |
| `src/gateway/JJDevHub.Gateway/JJDevHub.Gateway.csproj` | `Yarp.ReverseProxy`, `Microsoft.Extensions.ServiceDiscovery.Yarp`, ServiceDefaults |
| `src/gateway/JJDevHub.Gateway/Program.cs` | YARP z konfiguracji |
| `src/gateway/JJDevHub.Gateway/appsettings.json` | trasy i klastry |
| `tests/News.API.Tests/` | `WebApplicationFactory` z kontenerem |

## Plan

### 1. Projekty

```bash
dotnet new web -n News.API -o src/services/News/News.API -f net11.0
dotnet new web -n JJDevHub.Gateway -o src/gateway/JJDevHub.Gateway -f net11.0
dotnet new xunit -n News.API.Tests -o tests/News.API.Tests -f net11.0
dotnet sln add src/services/News/News.API src/gateway/JJDevHub.Gateway tests/News.API.Tests
dotnet add src/services/News/News.API reference src/services/News/News.Infrastructure src/aspire/JJDevHub.ServiceDefaults src/building-blocks/JJDevHub.EventBus.Kafka
dotnet add src/gateway/JJDevHub.Gateway reference src/aspire/JJDevHub.ServiceDefaults
dotnet add src/gateway/JJDevHub.Gateway package Yarp.ReverseProxy
dotnet add src/gateway/JJDevHub.Gateway package Microsoft.Extensions.ServiceDiscovery.Yarp
dotnet add src/aspire/JJDevHub.ServiceDefaults package Asp.Versioning.Http
dotnet add src/aspire/JJDevHub.AppHost reference src/services/News/News.API src/gateway/JJDevHub.Gateway
dotnet add tests/News.API.Tests reference src/services/News/News.API
```

### 2. Skład usługi

```csharp
var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();
builder.AddDefaultAuthentication();
builder.AddNpgsqlDbContext<NewsWriteContext>(ResourceNames.NewsWrite, s => s.DisableRetry = true);
builder.AddNpgsqlDbContext<NewsReadContext>(ResourceNames.NewsRead);
builder.AddKafkaProducer<string, string>(ResourceNames.Kafka);

builder.Services
    .AddNewsApplication()
    .AddNewsWrite()
    .AddNewsRead()
    .AddIntegrationEventLog<NewsWriteContext>(typeof(ArticleCreatedIntegrationEvent).Assembly)
    .AddKafkaEventBus(builder.Configuration, options => options.PublishedTopics = ["news.integration"])
    .AddDefaultApiVersioning();

if (builder.Environment.IsDevelopment())
{
    builder.Services.AddHostedService<DevelopmentMigrator>();
}

var app = builder.Build();
app.UseAuthentication();
app.UseAuthorization();
app.MapArticles();
app.MapDefaultEndpoints();
app.Run();
```

`AddProblemDetails` jest już w `AddServiceDefaults` z [14-aspire.md](14-aspire.md), razem z `GlobalExceptionHandler`.

`ResourceNames` dostaje projekt współdzielony z AppHost (plik linkowany przez `<Compile Include="..\..\..\aspire\JJDevHub.AppHost\ResourceNames.cs" Link="ResourceNames.cs" />`), żeby usługa nie kopiowała stałych.

`DevelopmentMigrator : IHostedService` w `StartAsync` migruje `NewsWriteContext` i `NewsReadContext`. Jest zarejestrowany przed workerami, więc kończy pracę, zanim one wystartują. Poza dev migracje idą osobnym krokiem w [18-ci-uslug.md](18-ci-uslug.md).

### 3. Endpointy

`MapArticles` tworzy grupę `/api/articles` z tagiem `Articles`.

| Metoda i ścieżka | Autoryzacja | Wejście | Wynik |
| --- | --- | --- | --- |
| `GET /api/articles?page=1&pageSize=20` | anonimowo | `ListArticlesQuery` | `200` z listą `ArticleSummary` |
| `GET /api/articles/{id:guid}` | anonimowo | `GetArticleQuery` | `200` + `ETag`, `404` |
| `POST /api/articles` | `RequireAuthorization()` | `CreateArticleRequest` → `CreateArticleCommand` z autorem z `sub` | `201` + `Location` + `ETag`, `400` |
| `PUT /api/articles/{id:guid}` | `RequireAuthorization()` | `If-Match` + `ReviseArticleRequest` → `ReviseArticleCommand` | `200` + `ETag`, `400`, `403`, `404`, `412`, `428` |

Endpoint to statyczna metoda z parametrami `IMediator`, `CurrentUser` (dla zapisu) i `CancellationToken`. Bez logiki poza mapowaniem.

### 3a. Wersja API

`AddDefaultApiVersioning(this IServiceCollection services)` w ServiceDefaults, żeby każda usługa HTTP miała te same reguły:

```csharp
services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
    options.ApiVersionReader = new HeaderApiVersionReader("api-version");
});
```

`MapArticles` buduje zestaw wersji i podpina go pod grupę:

```csharp
var versions = app.NewApiVersionSet().HasApiVersion(new ApiVersion(1, 0)).Build();
var group = app.MapGroup("/api/articles").WithApiVersionSet(versions).WithTags("Articles");
```

Endpoint, który zmienia kształt w `2.0`, dostaje drugą metodę z `MapToApiVersion(2, 0)`. Stara zostaje z `HasDeprecatedApiVersion(1, 0)`, a odpowiedź niesie `api-deprecated-versions: 1.0`, dopóki w sklepie jest wersja aplikacji mobilnej, która jej używa. Gateway przekazuje nagłówek `api-version` bez zmian.

### 4. ETag i If-Match

`EntityTag.From(int version)` → `"\"{version}\""` (silny ETag w cudzysłowie). `EntityTag.TryParse(string? header, out int version)` przyjmuje dokładnie ten format.

- `GET` po id i `201`/`200` po zapisie ustawiają `ETag`.
- `PUT` bez `If-Match` → `428 Precondition Required`. Klient musi powiedzieć, którą wersję edytuje.
- `If-Match` nieparsowalny → `400`.
- `Conflict` z `ReviseArticleCommand` → `412 Precondition Failed`.

Widok jest ostatecznie spójny, więc `GET` tuż po `POST` może zwrócić `404`. Klient po `201` używa wartości z odpowiedzi (`ArticleId`, `Version`), a widok czyta z ponowieniem.

### 5. Mapowanie wyników

`ResultHttpExtensions.ToProblem(this ResultError error)`:

| `ResultError` | HTTP |
| --- | --- |
| `Invalid` | `400` ProblemDetails |
| `NotFound` | `404` |
| `Conflict` | `409`; dla `PUT` z `If-Match` endpoint zamienia go na `412` |
| `Forbidden` | `403` |

To jedyne miejsce, które zna kody HTTP. Handlery nie wiedzą o HTTP.

### 6. Autor z tokenu

`CurrentUser` jest scoped i czyta `ClaimsPrincipal` z `IHttpContextAccessor`. `IdentityGuid` to claim `sub`. Brak claimu na chronionym endpoincie nie wystąpi, bo `RequireAuthorization` odrzuci żądanie wcześniej. `POST` przekazuje `IdentityGuid` jako `AuthorIdentityGuid`, a `PUT` jako `EditorIdentityGuid`. Reguła `OnlyAuthorCanReviseRule` z [03-agregat.md](03-agregat.md) zaczyna działać.

### 7. Gateway

`Program.cs`:

```csharp
var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .AddServiceDiscoveryDestinationResolver();

var app = builder.Build();
app.MapReverseProxy();
app.MapDefaultEndpoints();
app.Run();
```

Trasy w `appsettings.json`:

| Trasa | Klaster | Adres klastra |
| --- | --- | --- |
| `/api/auth/{**catch-all}` | `identity` | `http://identity-api` |
| `/.well-known/{**catch-all}` | `identity` | `http://identity-api` |
| `/api/articles/{**catch-all}` | `news` | `http://news-api` |

Adresy klastrów to nazwy zasobów Aspire. Resolver zamienia je na adresy. Gateway nie waliduje tokenu, tylko przekazuje nagłówek `Authorization`. Każda usługa sprawdza token sama.

Klient web ([src/Clients/web](../../src/Clients/web)) w dev kieruje proxy Vite na gateway zamiast na `identity-api`.

### 8. AppHost

```csharp
var newsApi = builder.AddProject<Projects.News_API>(ResourceNames.NewsApi)
    .WithReference(newsWrite).WaitFor(newsWrite)
    .WithReference(newsRead).WaitFor(newsRead)
    .WithReference(kafka).WaitFor(kafka)
    .WithEnvironment("Identity__Url", identityApi.GetEndpoint("http"));

builder.AddProject<Projects.JJDevHub_Gateway>(ResourceNames.Gateway)
    .WithReference(identityApi)
    .WithReference(newsApi)
    .WithExternalHttpEndpoints();
```

`ResourceNames` dostaje `NewsApi = "news-api"` i `Gateway = "gateway"`. Tylko gateway ma zewnętrzny endpoint. Usługi są osiągalne w sieci wewnętrznej.

Na VM tunel Cloudflare z [docs/CICD/02-cloudflare-tunnel.md](../CICD/02-cloudflare-tunnel.md) się nie zmienia: origin to dalej `127.0.0.1:4200`, czyli nginx w kontenerze `web`. Zmienia się cel nginx. Dziś [src/Clients/web/nginx.conf](../../src/Clients/web/nginx.conf) przekazuje `/api/` i `/health` na `api:8080`. Po wdrożeniu z [18-ci-uslug.md](18-ci-uslug.md) przekazuje `/api/`, `/.well-known/` i `/health` na `gateway:8080`. Klient web zostaje pod tym samym adresem, a nowych hostname'ów w tunelu nie ma. W tym numerze `nginx.conf` się nie zmienia, bo VM uruchamia jeszcze stary Compose.

### Co jest do czego

- `News.API` — proces usługi. Hostuje HTTP, `ProjectionWorker` i `OutboxDispatcher`.
- `ArticleEndpoints` — tłumacz HTTP ↔ mediator. Nie zawiera reguł.
- `CreateArticleRequest` / `ReviseArticleRequest` — kształt JSON-a od klienta. Autor nie przychodzi w body, tylko z tokenu.
- `EntityTag` — wersja agregatu w nagłówku HTTP. Łączy `Version` ze strumienia z `If-Match` klienta.
- `ResultHttpExtensions` — jedno mapowanie błędów na kody.
- `AddDefaultApiVersioning` — miejsce na drugą wersję endpointu, zanim aplikacja mobilna w sklepie zostanie z kontraktem, którego serwer już nie zna.
- `CurrentUser` — `IdentityGuid` zalogowanego użytkownika dla komend.
- `DevelopmentMigrator` — wygoda dev. W produkcji schemat zmienia osobny krok wdrożenia.
- `JJDevHub.Gateway` — jedno wejście, trasy do usług. Bez logiki biznesowej i bez walidacji tokenu.

## Testy

Projekt `tests/News.API.Tests`, `NewsApiFactory : WebApplicationFactory<Program>, IAsyncLifetime`:

- kontener Postgresa z bazami `news_write` i `news_read`, connection stringi `ConnectionStrings:news-write` i `news-read`,
- `IEventBus` → `RecordingEventBus`, hosted workery wyłączone opcją; test woła `ProjectionRunner` wprost,
- uwierzytelnienie: testowy klucz RSA, `PostConfigure<JwtBearerOptions>` z `IssuerSigningKey` i bez `Authority`; `TestTokens.For(identityGuid)` wystawia token.

Klasa `ArticleEndpointsTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Post_without_token_returns_401` | brak nagłówka | `POST` | `401` |
| `Post_returns_201_with_location` | token `a` | `POST` z tytułem | `201`, `Location` `/api/articles/{id}` |
| `Post_returns_etag_one` | token `a` | `POST` | `ETag` `"1"` |
| `Post_blank_title_returns_400` | token `a` | `POST` z `"  "` | `400` ProblemDetails |
| `Get_after_projection_returns_article` | `POST`, potem `RunOnceAsync` | `GET` po id | `200`, tytuł, `ETag` `"1"` |
| `Get_unknown_returns_404` | pusta baza | `GET` | `404` |
| `Put_without_if_match_returns_428` | artykuł `a` | `PUT` bez nagłówka | `428` |
| `Put_stale_if_match_returns_412` | artykuł w wersji 2 | `PUT` z `If-Match: "1"` | `412` |
| `Put_by_other_user_returns_403` | artykuł `a` | `PUT` z tokenem `b` | `403` |
| `Put_returns_new_etag` | artykuł `a` w wersji 1 | `PUT` z `If-Match: "1"` | `200`, `ETag` `"2"` |
| `List_too_large_page_returns_400` | dowolnie | `GET ?pageSize=51` | `400` |
| `Request_without_version_uses_default` | dowolnie | `GET /api/articles` bez `api-version` | `200`, `api-supported-versions: 1.0` |
| `Unknown_version_returns_400` | dowolnie | `GET` z `api-version: 9.0` | `400` ProblemDetails |

Klasa `AppHostTests` z [14-aspire.md](14-aspire.md) dostaje:

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Gateway_routes_articles` | aplikacja uruchomiona | `GET /api/articles` na `gateway` | `200` |
| `Gateway_routes_jwks` | aplikacja uruchomiona | `GET /.well-known/jwks.json` na `gateway` | `200` |

`dotnet test tests/News.API.Tests` i `dotnet test tests/JJDevHub.AppHost.Tests`.

## Zasady

- Endpoint nie zawiera reguł biznesowych. Woła `Send` i mapuje wynik.
- Autor i edytor pochodzą z tokenu, nigdy z body.
- `PUT` wymaga `If-Match`. Zapis bez wersji jest odrzucany.
- Kody HTTP zna tylko `ResultHttpExtensions`.
- Gateway nie zna usług z nazwy w kodzie, tylko z konfiguracji. Nie waliduje tokenu.
- Migracje przy starcie tylko w `Development`.
- Każda grupa endpointów ma zestaw wersji. Żądanie bez `api-version` dostaje `1.0`.

## Poza zakresem

- Rate limiting i cache na gatewayu.
- Publikacja, wycofanie i przypięcie artykułu do lekcji — [21-notatki.md](21-notatki.md).
- Upload obrazów.
- Notifications w AppHost — [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).
- OpenAPI usługi. `AddOpenApi` i Scalar według wzoru z obecnego `Identity.API`, gdy klient zacznie generować typy.

## Źródła

- [Minimal APIs overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/minimal-apis/overview) — grupy tras, `RequireAuthorization`, `TypedResults`.
- [dotnet/eShop — Ordering.API/Apis](https://github.com/dotnet/eShop/tree/main/src/Ordering.API/Apis) — endpointy jako cienka warstwa nad mediatorem.
- [RFC 9110: conditional requests](https://www.rfc-editor.org/rfc/rfc9110#name-conditional-requests) — `ETag`, `If-Match`, `412`.
- [RFC 6585: 428 Precondition Required](https://www.rfc-editor.org/rfc/rfc6585#section-3) — wymuszenie warunku przy zapisie.
- [YARP documentation](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/getting-started) — trasy i klastry z konfiguracji.
- [Service discovery in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/service-discovery) — `AddServiceDiscoveryDestinationResolver` dla YARP.
- [The API gateway pattern](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/architect-microservice-container-applications/direct-client-to-microservice-communication-versus-the-api-gateway-pattern) — jedno wejście przed usługami.
- [Problem details](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling#problem-details) — format błędów `400`.
- [RFC 9110: 422 Unprocessable Content](https://www.rfc-editor.org/rfc/rfc9110#name-422-unprocessable-content) — dlaczego `400` wystarcza.
- [dotnet/aspnet-api-versioning](https://github.com/dotnet/aspnet-api-versioning) — `Asp.Versioning.Http`, `ApiVersionSet`, czytniki wersji.

## Gotowe gdy

- `aspire run` stawia `news-api` i `gateway`, a `GET /api/articles` przez gateway zwraca `200`.
- `POST` z tokenem zwraca `201` z `Location` i `ETag`, a bez tokenu `401`.
- `PUT` bez `If-Match` zwraca `428`, a ze starą wersją `412`.
- Artykuł zapisany przez API ma `IdentityGuid` strumienia równy `sub` z tokenu.
- Odpowiedź niesie `api-supported-versions: 1.0`, a nieznana wersja w `api-version` daje `400`.
- `dotnet test tests/News.API.Tests` i `dotnet test tests/JJDevHub.AppHost.Tests` kończą się kodem 0.
