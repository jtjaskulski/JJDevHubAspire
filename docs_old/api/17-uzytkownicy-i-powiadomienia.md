# Powiadomienia

`Notifications.Worker` reaguje na nowe konto i nowy artykuł, wysyła powiadomienie i zapisuje, że to zrobił. Profil konta jest w Identity, na agregacie `Account` ([15-identity.md](15-identity.md)). Worker używa inboxa z [12-outbox-inbox.md](12-outbox-inbox.md) i konsumenta Kafki z [13-kafka.md](13-kafka.md). `tests/JJDevHub.Contracts.Tests` pilnuje, żeby kontrakty z `Identity.Contracts` i `News.Contracts` nie zmieniły się po cichu. Publikujący są w [15-identity.md](15-identity.md) i [16-usluga-news.md](16-usluga-news.md).

## Po co

Worker pokazuje drugą stronę szyny. Nie woła Identity po dane i nie czyta bazy `identity_write`. Buduje ślad wysyłki z faktów, które dostał. Jeśli leży przez godzinę, rejestracje dalej działają. Po restarcie konsument dojdzie do bieżącego offsetu.

Kontrakt integracyjny to API między usługami, nawet gdy autor jest jeden. Zmiana pola w `UserRegisteredIntegrationEvent` łamie Notifications bez błędu kompilacji, jeśli worker ma starą wersję paczki. Test snapshotu łapie taką zmianę w PR.

## Dlaczego ta technologia

### Notifications jako worker z samymi ścieżkami technicznymi

Powiadomienia reagują na zdarzenia i nikt ich nie wywołuje. Logika to handlery i `BackgroundService`, bez endpointów biznesowych. Proces potrzebuje jednak HTTP do dwóch rzeczy: Prometheus ściąga `/metrics` ([docs/CICD/07-prometheus.md](../CICD/07-prometheus.md)), a Compose i Aspire sprawdzają `/health`. Czysty szablon `worker` (`Host.CreateApplicationBuilder`) nie ma Kestrela, więc `MapDefaultEndpoints` i `MapPrometheusScrapingEndpoint` nie miałyby gdzie działać. Dlatego worker startuje z `WebApplication.CreateSlimBuilder`: Kestrel bez MVC, routingu kontrolerów i plików statycznych, z trzema ścieżkami technicznymi. Alternatywa to wypychanie metryk przez OTLP do kolektora, ale na VM kolektora nie ma, a Jaeger metryk nie przyjmuje.

Ślad wysyłki zostaje zwykłą tabelą. Nie ma historii, którą warto odtwarzać ze strumienia.

### `INotificationSender` z implementacją logującą

Prawdziwy e-mail wymaga dostawcy (SMTP, Cloudflare Email, SendGrid), sekretów i domeny z DKIM. To osobna decyzja i w tym numerze przegrywa. Interfejs z implementacją, która tylko loguje, pozwala zbudować i przetestować cały przepływ (zdarzenie → inbox → wysyłka → `SentNotifications`) bez dostawcy. Podmiana to jedna rejestracja w DI. Koszt: wiadomość zostaje w logu i w `SentNotifications`, a nie w skrzynce.

### Testy kontraktów jako snapshoty JSON

Zdarzenie integracyjne to publiczne API usługi. Zmiana nazwy pola w `UserRegisteredIntegrationEvent` łamie Notifications, a kompilator tego nie zobaczy, bo worker deserializuje JSON. Test serializuje przykładowe zdarzenie i porównuje z zatwierdzonym plikiem `Snapshots/{nazwa}.json`. Zmiana kształtu jest widoczna w PR jako zmiana pliku.

Alternatywy:

- **Pact** (PactNet, MIT) — kontrakty sterowane przez konsumenta, z brokerem kontraktów. Potężne przy wielu zespołach. Przy jednym repo i jednym autorze broker to zbędny serwer.
- **Verify** (MIT) — biblioteka snapshotów z narzędziami do porównywania i zatwierdzania. Dozwolona i wygodniejsza przy wielu snapshotach. Przy kilku plikach `File.ReadAllText` i porównanie stringów wystarcza, a przejście na Verify to zamiana jednej metody pomocniczej.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/Notifications/Notifications.Worker/Notifications.Worker.csproj` | Web SDK (Kestrel tylko na ścieżki techniczne), ServiceDefaults, oba `*.Contracts` |
| `src/services/Notifications/Notifications.Worker/Data/NotificationsContext.cs` | baza `notifications` |
| `src/services/Notifications/Notifications.Worker/Data/SentNotification.cs` | ślad wysyłki |
| `src/services/Notifications/Notifications.Worker/Sending/INotificationSender.cs` | port wysyłki |
| `src/services/Notifications/Notifications.Worker/Sending/LoggingNotificationSender.cs` | wysyłka do logu |
| `src/services/Notifications/Notifications.Worker/IntegrationEvents/WelcomeUserHandler.cs` | powitanie nowego konta |
| `src/services/Notifications/Notifications.Worker/IntegrationEvents/ArticleCreatedHandler.cs` | informacja o nowym artykule |
| `tests/Notifications.Worker.Tests/` | konsumpcja i idempotencja |
| `tests/JJDevHub.Contracts.Tests/` | snapshoty kontraktów |

## Plan

### 1. Projekty

```bash
dotnet new web -n Notifications.Worker -o src/services/Notifications/Notifications.Worker -f net11.0
dotnet new xunit -n Notifications.Worker.Tests -o tests/Notifications.Worker.Tests -f net11.0
dotnet new xunit -n JJDevHub.Contracts.Tests -o tests/JJDevHub.Contracts.Tests -f net11.0
dotnet sln add src/services/Notifications/Notifications.Worker tests/Notifications.Worker.Tests tests/JJDevHub.Contracts.Tests
dotnet add src/services/Notifications/Notifications.Worker reference src/aspire/JJDevHub.ServiceDefaults src/services/Identity/Identity.Contracts src/services/News/News.Contracts src/building-blocks/JJDevHub.IntegrationEventLog src/building-blocks/JJDevHub.EventBus.Kafka
dotnet add tests/JJDevHub.Contracts.Tests reference src/services/Identity/Identity.Contracts src/services/News/News.Contracts
```

Notifications nie zna `Identity.API` ani `News.Domain`, tylko kontrakty.

### 2. Ślad wysyłki

`NotificationsContext : DbContext` z `DbSet<SentNotification>` i `ApplyIntegrationEventLog()`. `SentNotification` (`sealed`): `Id`, `EventId`, `Kind` (`welcome`, `article-created`), `Recipient` (`string?`), `CreatedOn`. Unikalny indeks na `EventId` + `Kind`. Migracja `NotificationsInitial`.

```csharp
namespace JJDevHub.Notifications.Worker.Sending;

public interface INotificationSender
{
    Task SendAsync(string kind, string? recipient, string text, CancellationToken cancellationToken);
}
```

`LoggingNotificationSender` zapisuje powiadomienie do logu (`Information`). Prawdziwy kanał (e-mail, webhook Discorda) to druga implementacja tego interfejsu, poza tym numerem.

Handlery:

- `WelcomeUserHandler` — `UserRegisteredIntegrationEvent` → `SendAsync("welcome", email, …)` i `SentNotification`,
- `ArticleCreatedHandler` — `ArticleCreatedIntegrationEvent` → `SendAsync("article-created", null, title)` i `SentNotification`.

Kolejność jest celowa: najpierw wysyłka, potem zapis w tej samej transakcji co inbox. Awaria po wysyłce, a przed commitem, wyśle powiadomienie drugi raz. Dla powiadomienia to akceptowalne. Odwrotna kolejność mogłaby je zgubić.

Skład w `Program.cs` workera: `WebApplication.CreateSlimBuilder(args)`, `AddServiceDefaults`, `AddNpgsqlDbContext<NotificationsContext>` z `DisableRetry = true` (powód w [14-aspire.md](14-aspire.md)), `AddIntegrationEventLog` z oboma zestawami kontraktów i `PublishOutbox = false`, `AddKafkaConsumer` z grupą `notifications` i tematami `identity.integration` oraz `news.integration`. Po `Build()` tylko `app.MapDefaultEndpoints()`: `/health`, `/alive`, `/metrics`. Innych tras worker nie ma.

`PublishOutbox = false` nie rejestruje `OutboxDispatcher`. Worker niczego nie publikuje. Opcja dochodzi do `AddIntegrationEventLog` z [12-outbox-inbox.md](12-outbox-inbox.md) w tym numerze.

### 3. Kontrakty pod testem

Projekt `tests/JJDevHub.Contracts.Tests`:

- `ContractCatalog` zbiera wszystkie typy `IIntegrationEvent` z `Identity.Contracts` i `News.Contracts`,
- `ContractSamples` ma dla każdego typu przykładową instancję ze stałymi wartościami (`EventId` = `00000000-0000-0000-0000-000000000001`, stała data),
- snapshot to plik `Snapshots/{event-name}.json` z wynikiem `IntegrationEventSerializer.ToEnvelope(sample).Payload`, sformatowanym z wcięciami.

Zmiana kształtu kontraktu psuje test. Poprawka jest jedna z dwóch: nowa wersja nazwy (`.v2`) obok starej, albo świadoma aktualizacja snapshotu w PR, jeśli pole jest tylko dodane i nullable.

### 4. AppHost

```csharp
var notificationsDb = postgres.AddDatabase(ResourceNames.Notifications, "notifications");

builder.AddProject<Projects.Notifications_Worker>(ResourceNames.NotificationsWorker)
    .WithReference(notificationsDb).WaitFor(notificationsDb)
    .WithReference(kafka).WaitFor(kafka);
```

`ResourceNames` dostaje `NotificationsWorker = "notifications-worker"`. Gateway nie dostaje trasy workera: HTTP workera to tylko zdrowie i metryki wewnątrz sieci.

### Co jest do czego

- `Notifications.Worker` — usługa bez endpointów biznesowych i bez publikacji. Tylko reaguje. HTTP ma wyłącznie dla zdrowia i metryk.
- `WelcomeUserHandler` — tłumaczy rejestrację z Identity na powitanie. Inbox nie wpuszcza tego samego `EventId` drugi raz.
- `INotificationSender` — port kanału. Log dziś, e-mail jutro, bez zmiany handlerów.
- `SentNotification` — ślad, co i komu wysłano. Pomaga przy reklamacji „nie dostałem”.
- `JJDevHub.Contracts.Tests` — strażnik kontraktów między usługami.

## Testy

Projekt `tests/Notifications.Worker.Tests`. Host z `Host.CreateApplicationBuilder`, kontener Postgresa (baza `notifications`), `RecordingNotificationSender`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Article_created_sends_once` | koperta artykułu | `ReceiveAsync` | jedno wywołanie nadawcy, jeden `SentNotification` |
| `Duplicate_article_sends_nothing` | koperta już przyjęta | `ReceiveAsync` | nadawca nadal raz |
| `Registration_sends_welcome_to_email` | koperta rejestracji | `ReceiveAsync` | `Recipient` równy e-mailowi |
| `Unknown_event_is_ignored` | koperta obcego typu | `ReceiveAsync` | `Ignored`, nadawca nie wywołany |

Projekt `tests/JJDevHub.Contracts.Tests`, klasa `ContractSnapshotTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Every_contract_has_sample` | katalog typów | porównanie z `ContractSamples` | brak typu bez próbki |
| `Every_name_has_integration_segment_and_version` | katalog typów | odczyt `[EventName]` | wzór `^[a-z]+\.integration\.[a-z-]+\.v\d+$` |
| `Payload_matches_snapshot` | `[Theory]` po typach | `ToEnvelope(sample).Payload` | równe plikowi snapshotu |
| `Registry_builds_without_duplicates` | oba zestawy | `EventTypeRegistry.FromAssemblies` | bez wyjątku |

`dotnet test tests/Notifications.Worker.Tests`, `dotnet test tests/JJDevHub.Contracts.Tests` i `dotnet test tests/JJDevHub.AppHost.Tests`.

## Zasady

- Konsument buduje własny model z faktów. Nie woła HTTP usługi-nadawcy i nie czyta jej bazy.
- Handler zdarzenia jest idempotentny, nawet z inboxem.
- Złe dane w zdarzeniu kończą się logiem, nie wyjątkiem, który blokuje partycję.
- Usługa bez publikacji ma `PublishOutbox = false`.
- Zmiana kontraktu integracyjnego to nowa wersja nazwy albo świadoma zmiana snapshotu w PR.
- Worker nie trzyma hasła ani kopii konta. Nazwa wyświetlana zostaje w Identity.

## Poza zakresem

- Prawdziwy kanał powiadomień (SMTP, Discord). Druga implementacja `INotificationSender`.
- Preferencje powiadomień użytkownika.
- `UserDeletedIntegrationEvent`.
- Pokazanie `DisplayName` przy artykule. Widok News może kiedyś konsumować `identity.integration`.

## Źródła

- [Implementing event-based communication between microservices](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/integration-event-based-microservice-communications) — subskrypcja, handler zdarzenia integracyjnego, idempotencja.
- [dotnet/eShop — OrderProcessor](https://github.com/dotnet/eShop/tree/main/src/OrderProcessor) — worker bez HTTP biznesowego.
- [Worker services in .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/workers) — szablon `worker` i `BackgroundService`.
- [Consumer-Driven Contracts](https://martinfowler.com/articles/consumerDrivenContracts.html) — Ian Robinson: kontrakt pilnowany testem.
- [Unit testing best practices](https://learn.microsoft.com/en-us/dotnet/core/testing/unit-testing-best-practices) — test deterministyczny ze stałymi danymi, jak próbki kontraktów.
- [Idempotent Consumer](https://microservices.io/patterns/communication-style/idempotent-consumer.html) — Chris Richardson.

## Gotowe gdy

- Rejestracja przez gateway zostawia powitanie w `notifications`. Nazwa konta jest w strumieniu Identity, bez drugiej bazy.
- Nowy artykuł zostawia jeden `SentNotification` z rodzajem `article-created`.
- Powtórzona wiadomość nie tworzy drugiego powiadomienia.
- Zmiana pola w kontrakcie bez nowej wersji psuje `ContractSnapshotTests`.
- `dotnet test` dla trzech projektów z sekcji Testy kończy się kodem 0.
