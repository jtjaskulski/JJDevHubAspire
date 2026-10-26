# Outbox i inbox

Outbox zapisuje zdarzenie integracyjne w tej samej transakcji co zmianę stanu. Dispatcher wysyła je na szynę po commicie. Inbox po stronie odbiorcy pamięta przetworzone `EventId`, więc powtórzona wiadomość nie ma skutku. Biblioteka `JJDevHub.EventBus` daje kontrakty: `IIntegrationEvent`, `IntegrationEnvelope`, `IEventBus`, `IIntegrationEventOutbox`, `IIntegrationEventReceiver`. `JJDevHub.IntegrationEventLog` daje tabele i procesory na EF. Usługa News dostaje `News.Contracts` z `ArticleCreatedIntegrationEvent`. Transakcję otwiera `TransactionBehavior` z [08-mediator.md](08-mediator.md). Transport Kafka jest w [13-kafka.md](13-kafka.md).

## Po co

Zapis do bazy i wysłanie wiadomości to dwie operacje na dwóch systemach. Bez outboxa są dwa złe scenariusze. Baza się zatwierdza, a broker leży: zdarzenie ginie. Broker przyjmuje wiadomość, a baza się wycofuje: odbiorca dostaje fakt, który nie zaszedł. Outbox zamienia oba scenariusze w jeden zapis do bazy, a wysyłkę w osobny, ponawialny krok.

Wysyłka „co najmniej raz” oznacza duplikaty. Dispatcher może wysłać wiadomość i paść przed oznaczeniem wiersza. Dlatego odbiorca ma inbox: zapis `EventId` w tej samej transakcji co skutek wiadomości.

eShop ma to samo w `IntegrationEventLogEF`: tabela `IntegrationEventLog` w bazie usługi, zapis w transakcji `TransactionBehavior`, publikacja po commicie. Wcześniejsza wersja tej specyfikacji przekazywała zdarzenie integracyjne do `AppendAsync`. Magazyn zdarzeń zależał wtedy od szyny. Teraz handler mapuje zdarzenie w Application, a łączy je wspólna transakcja.

## Dlaczego ta technologia

### Transactional outbox zamiast publikacji po zapisie

Najprostszy kod to „zapisz artykuł, potem wyślij zdarzenie na Kafkę”. To jest dual write: dwa systemy bez wspólnej transakcji. Jeśli proces padnie między zapisem a wysyłką, artykuł istnieje, a Notifications nigdy się o nim nie dowie. Odwrotna kolejność (najpierw wysyłka) daje zdarzenie o artykule, którego nie ma. Outbox zamienia dwa zapisy na jeden: zdarzenie integracyjne trafia do tabeli `OutboxMessages` w tej samej transakcji co strumień. Osobny dispatcher czyta tabelę i wysyła. Jeśli wysyłka się nie uda, spróbuje ponownie. Jeśli proces padnie, wiersz czeka. Wzorzec opisują Chris Richardson (microservices.io) i Microsoft, a eShop implementuje go w `IntegrationEventLogEF`.

Alternatywa CDC (Debezium czyta log Postgresa i publikuje) usuwa dispatcher z kodu, ale dokłada klaster Kafka Connect. Na jedną VM to za dużo.

### At-least-once i inbox zamiast „dokładnie raz”

Dispatcher może wysłać wiadomość, a potem paść przed oznaczeniem jej jako wysłanej. Po restarcie wyśle ją drugi raz. „Dokładnie raz” między bazą a brokerem nie istnieje bez rozproszonej transakcji. Uczciwa gwarancja to „co najmniej raz” plus odbiorca, który rozpoznaje duplikaty. `InboxMessages` z kluczem `(EventId, Consumer)` zapisuje się w transakcji handlera. Drugi raz ta sama wiadomość daje `Duplicate` i nic nie robi.

### Zdarzenie integracyjne osobno od domenowego

`ArticleCreatedDomainEvent` to szczegół usługi News: zawiera treść, może zmienić kształt przy refaktoryzacji. `ArticleCreatedIntegrationEvent` to publiczny kontrakt dla innych usług, wersjonowany osobno (`news.integration.article-created.v1`) i bez treści artykułu. Mapowanie w Application sprawia, że wewnętrzna zmiana nie łamie konsumentów. eShop rozdziela je tak samo.

### `FOR UPDATE SKIP LOCKED`

Dwie repliki usługi uruchomią dwa dispatchery. Bez blokady oba wezmą te same wiersze i wyślą podwójnie. `SKIP LOCKED` sprawia, że drugi dispatcher pomija wiersze zablokowane przez pierwszego i bierze następne. To idiomatyczna kolejka na Postgresie, bez wyboru lidera i bez dodatkowych narzędzi.

### Własna biblioteka zamiast gotowej szyny

Gotowe rozwiązania z outboxem:

- **MassTransit** — od wersji `9` wyłącznie płatny, odpada,
- **Wolverine** (MIT) — outbox na Postgresie, mediator i transport Kafki w jednym; dobry wybór produkcyjny, ale przejmuje konwencje całej aplikacji,
- **DotNetCore.CAP** (MIT) — outbox i inbox z Kafką i Postgresem, gotowy dashboard; najbliższy temu, co budujemy,
- **Brighter** (MIT) — command processor z outboxem.

CAP albo Wolverine zaoszczędziłyby ten numer. Piszemy własne, bo outbox jest jednym z tematów ciągu: student ma zobaczyć tabelę, transakcję i pętlę dispatchera. Interfejsy (`IIntegrationEventOutbox`, `IIntegrationEventHandler<T>`) są na tyle małe, że migracja na CAP dotyka składu, nie handlerów.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.EventBus/IIntegrationEvent.cs` | `EventId`, `OccurredOn`, `PartitionKey` |
| `src/building-blocks/JJDevHub.EventBus/IntegrationEnvelope.cs` | `EventId`, `Name`, `PartitionKey`, `Payload`, `OccurredOn` |
| `src/building-blocks/JJDevHub.EventBus/IntegrationEventSerializer.cs` | zdarzenie ↔ koperta, rejestr z [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md) |
| `src/building-blocks/JJDevHub.EventBus/IEventBus.cs` | `PublishAsync(IntegrationEnvelope)` |
| `src/building-blocks/JJDevHub.EventBus/EventBusPublishException.cs` | jedyny wyjątek publikacji |
| `src/building-blocks/JJDevHub.EventBus/IIntegrationEventOutbox.cs` | `AddAsync` |
| `src/building-blocks/JJDevHub.EventBus/IIntegrationEventHandler.cs` | `Handle(T)` |
| `src/building-blocks/JJDevHub.EventBus/IIntegrationEventReceiver.cs` | `ReceiveAsync(IntegrationEnvelope)` → `ReceiveOutcome` |
| `src/building-blocks/JJDevHub.EventBus/InMemoryEventBus.cs` | koperta prosto do odbiorcy w procesie |
| `src/building-blocks/JJDevHub.IntegrationEventLog/OutboxMessage.cs` | wiersz outboxa |
| `src/building-blocks/JJDevHub.IntegrationEventLog/InboxMessage.cs` | wiersz inboxa |
| `src/building-blocks/JJDevHub.IntegrationEventLog/IntegrationEventLogModelBuilderExtensions.cs` | `ApplyIntegrationEventLog` |
| `src/building-blocks/JJDevHub.IntegrationEventLog/IntegrationEventOutbox.cs` | `IIntegrationEventOutbox` na `TContext` |
| `src/building-blocks/JJDevHub.IntegrationEventLog/OutboxProcessor.cs` | jedno przejście z `FOR UPDATE SKIP LOCKED` |
| `src/building-blocks/JJDevHub.IntegrationEventLog/OutboxDispatcher.cs` | `BackgroundService` wokół procesora |
| `src/building-blocks/JJDevHub.IntegrationEventLog/InboxReceiver.cs` | `IIntegrationEventReceiver` z deduplikacją |
| `src/building-blocks/JJDevHub.IntegrationEventLog/IntegrationEventLogServiceCollectionExtensions.cs` | `AddIntegrationEventLog<TContext>(assemblies)` |
| `src/services/News/News.Contracts/ArticleCreatedIntegrationEvent.cs` | kontrakt na szynę |
| `tests/JJDevHub.IntegrationEventLog.Tests/` | outbox, dispatcher, inbox na kontenerze |

## Plan

### 1. Projekty

```bash
dotnet new classlib -n JJDevHub.EventBus -o src/building-blocks/JJDevHub.EventBus -f net11.0
dotnet new classlib -n JJDevHub.IntegrationEventLog -o src/building-blocks/JJDevHub.IntegrationEventLog -f net11.0
dotnet new classlib -n News.Contracts -o src/services/News/News.Contracts -f net11.0
dotnet new xunit -n JJDevHub.IntegrationEventLog.Tests -o tests/JJDevHub.IntegrationEventLog.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.EventBus src/building-blocks/JJDevHub.IntegrationEventLog src/services/News/News.Contracts tests/JJDevHub.IntegrationEventLog.Tests
dotnet add src/building-blocks/JJDevHub.EventBus reference src/building-blocks/JJDevHub.Domain
dotnet add src/building-blocks/JJDevHub.IntegrationEventLog reference src/building-blocks/JJDevHub.EventBus
dotnet add src/building-blocks/JJDevHub.IntegrationEventLog package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/services/News/News.Contracts reference src/building-blocks/JJDevHub.EventBus
dotnet add src/services/News/News.Application reference src/services/News/News.Contracts
dotnet add src/services/News/News.Infrastructure reference src/building-blocks/JJDevHub.IntegrationEventLog
```

`JJDevHub.EventBus` dostaje `Microsoft.Extensions.DependencyInjection.Abstractions` dla `InMemoryEventBus`. `News.Contracts` referencjonuje tylko `JJDevHub.EventBus`: konsument nie ciągnie domeny News.

### 2. Kontrakt zdarzenia integracyjnego

```csharp
namespace JJDevHub.EventBus;

public interface IIntegrationEvent
{
    Guid EventId { get; }

    DateTimeOffset OccurredOn { get; }

    string PartitionKey { get; }
}
```

`PartitionKey` mówi, które wiadomości muszą zachować kolejność. Dla artykułu to jego id. Kafka w [13-kafka.md](13-kafka.md) użyje go jako klucza wiadomości.

```csharp
namespace JJDevHub.News.Contracts;

[EventName("news.integration.article-created.v1")]
public sealed record ArticleCreatedIntegrationEvent(
    Guid EventId,
    DateTimeOffset OccurredOn,
    Guid ArticleId,
    string Title,
    string? AuthorIdentityGuid) : IIntegrationEvent
{
    [JsonIgnore]
    public string PartitionKey => ArticleId.ToString();
}
```

Nazwa ma format `kontekst.integration.fakt.vN`. Pierwsze dwa segmenty to temat Kafki (`news.integration`). Kontrakt jest węższy niż zdarzenie domenowe: bez `Body`. Konsument, który potrzebuje treści, nie powinien jej trzymać.

### 3. Koperta i serializer

```csharp
namespace JJDevHub.EventBus;

public sealed record IntegrationEnvelope(
    Guid EventId, string Name, string PartitionKey, string Payload, DateTimeOffset OccurredOn);
```

`IntegrationEventSerializer(EventTypeRegistry registry)` jest `sealed`:

- `IntegrationEnvelope ToEnvelope(IIntegrationEvent)` — nazwa z rejestru, JSON z `JsonSerializerDefaults.Web`,
- `IIntegrationEvent? FromEnvelope(IntegrationEnvelope)` — nieznana nazwa daje `null`.

`null` jest tu zamierzone. Na jednym temacie leżą różne typy zdarzeń, a konsument zna tylko te, które go interesują. Nieznany typ to nie błąd.

### 4. Porty

```csharp
public interface IEventBus
{
    Task PublishAsync(IntegrationEnvelope envelope, CancellationToken cancellationToken);
}

public interface IIntegrationEventOutbox
{
    Task AddAsync(IIntegrationEvent integrationEvent, CancellationToken cancellationToken);
}

public interface IIntegrationEventHandler<in T>
    where T : IIntegrationEvent
{
    Task Handle(T integrationEvent, CancellationToken cancellationToken);
}

public interface IIntegrationEventReceiver
{
    Task<ReceiveOutcome> ReceiveAsync(IntegrationEnvelope envelope, CancellationToken cancellationToken);
}
```

Każdy interfejs w osobnym pliku. `ReceiveOutcome` to enum: `Handled`, `Duplicate`, `Ignored`. Implementacja `IEventBus` zgłasza problem z transportem wyłącznie przez `EventBusPublishException`.

`InMemoryEventBus(IServiceScopeFactory scopes) : IEventBus` otwiera scope i woła `IIntegrationEventReceiver`. Służy testom i jednemu procesowi bez brokera.

### 5. Tabele

`OutboxMessage` (`sealed`):

| Pole | Rola |
| --- | --- |
| `EventId` | klucz |
| `Name`, `PartitionKey`, `Payload` (`jsonb`), `OccurredOn` | koperta |
| `CreatedOn` | kolejność wysyłki, indeks częściowy `WHERE "ProcessedOn" IS NULL` |
| `ProcessedOn` | `DateTimeOffset?`, puste do udanej publikacji |
| `Attempts`, `LastError` | licznik prób i ostatni błąd, do 2000 znaków |

`InboxMessage` (`sealed`): klucz złożony `EventId` + `Consumer`, `Name`, `ProcessedOn`.

`ApplyIntegrationEventLog(this ModelBuilder)` mapuje obie tabele: `OutboxMessages` i `InboxMessages`. Kontekst usługi woła je obok `ApplyEventStore`.

### 6. Zapis do outboxa

`IntegrationEventOutbox<TContext>(TContext context, IntegrationEventSerializer serializer)`. `AddAsync`:

- `context.Database.CurrentTransaction` jest `null` → `InvalidOperationException`; outbox bez transakcji nie jest atomowy, więc to błąd składu,
- koperta → `OutboxMessage`, `Add`, `SaveChangesAsync`.

Handler tworzenia artykułu z [09-komenda.md](09-komenda.md) dostaje `IIntegrationEventOutbox outbox` i po udanym `SaveAsync` woła:

```csharp
await outbox.AddAsync(
    new ArticleCreatedIntegrationEvent(
        Guid.NewGuid(), time.GetUtcNow(), article.Id, article.Title, article.AuthorIdentityGuid),
    cancellationToken);
```

Obie operacje są w transakcji `TransactionBehavior` na `NewsWriteContext`. Commit zapisuje strumień i outbox razem. `Conflict` z `SaveAsync` kończy handler przed outboxem, a transakcja się wycofuje.

`NewsWriteContext.OnModelCreating` dostaje `modelBuilder.ApplyIntegrationEventLog()`. Migracja `NewsWriteOutbox`.

### 7. Dispatcher

`OutboxProcessor<TContext>(TContext context, IEventBus bus, TimeProvider time, IOptions<OutboxOptions> options)`. `RunOnceAsync` zwraca liczbę wysłanych:

- `BeginTransactionAsync`,
- `FromSql`: `SELECT * FROM "OutboxMessages" WHERE "ProcessedOn" IS NULL AND "Attempts" < {MaxAttempts} ORDER BY "CreatedOn" LIMIT {BatchSize} FOR UPDATE SKIP LOCKED`,
- dla każdego wiersza `PublishAsync`; sukces → `ProcessedOn = now`; `EventBusPublishException` → `Attempts++`, `LastError` i przerwanie paczki, żeby nie wysłać następnych wiadomości tego samego klucza przed poprzednią,
- `SaveChangesAsync`, `CommitAsync`.

`SKIP LOCKED` sprawia, że dwie instancje dispatchera biorą rozłączne wiersze. Wiersz po `MaxAttempts` (domyślnie 10) zostaje w tabeli do ręcznej decyzji, widoczny w logu jako `Error`.

`OutboxDispatcher<TContext> : BackgroundService` woła procesor w nowym scope, a przy zerze wysłanych czeka `IdleDelay` (500 ms). Ten sam wzór co `ProjectionWorker` z [10-projekcja.md](10-projekcja.md).

### 8. Inbox

`InboxReceiver<TContext>(TContext context, IntegrationEventSerializer serializer, IServiceProvider services, IOptions<InboxOptions> options) : IIntegrationEventReceiver`. `Consumer` z opcji to nazwa usługi. `ReceiveAsync`:

- `FromEnvelope` zwraca `null` → `Ignored`,
- `BeginTransactionAsync`,
- `InboxMessages` ma (`EventId`, `Consumer`) → `RollbackAsync`, `Duplicate`,
- handler `IIntegrationEventHandler<T>` dla typu z koperty, przez generyczny wrapper jak w mediatorze; brak handlera → `Ignored`,
- `Handle`, `Add(new InboxMessage(...))`, `SaveChangesAsync`, `CommitAsync` → `Handled`.

Skutek handlera i wpis inboxa są w jednej transakcji. Handler zapisuje przez ten sam `TContext`.

### 9. Skład

```csharp
services.AddIntegrationEventLog<NewsWriteContext>(typeof(ArticleCreatedIntegrationEvent).Assembly);
```

Rejestruje:

- `IntegrationEventSerializer` z `EventTypeRegistry.FromAssemblies(typeof(IIntegrationEvent), …)` (singleton),
- `IIntegrationEventOutbox` → `IntegrationEventOutbox<TContext>`,
- `OutboxProcessor<TContext>` i hosted `OutboxDispatcher<TContext>`,
- `IIntegrationEventReceiver` → `InboxReceiver<TContext>`,
- handlery `IIntegrationEventHandler<>` z podanych zestawów usługi przez osobne `AddIntegrationEventHandlers(assembly)`.

`IEventBus` rejestruje transport. Do [13-kafka.md](13-kafka.md) jest to `InMemoryEventBus`.

### Co jest do czego

- `IIntegrationEvent` — kontrakt między usługami. Żyje w `*.Contracts`, nie w domenie.
- `PartitionKey` — gwarancja kolejności faktów jednego artykułu u odbiorcy.
- `IntegrationEnvelope` — to, co płynie przez outbox i szynę: nazwa, klucz, JSON. Dispatcher nie musi znać typów.
- `IntegrationEventSerializer` — przejście typ ↔ koperta, oparte na tym samym rejestrze nazw co zdarzenia domenowe.
- `IIntegrationEventOutbox` — „wyślij, gdy transakcja się uda”. Woła go handler w Application.
- `OutboxMessage` — trwała kolejka wysyłki w bazie usługi.
- `OutboxProcessor` / `OutboxDispatcher` — przejście i pętla wysyłki. Ponawiają do skutku albo do limitu prób.
- `IEventBus` — port transportu. Pamięć w testach, Kafka od `13`.
- `IIntegrationEventReceiver` / `InboxReceiver` — wejście wiadomości do usługi z deduplikacją.
- `InboxMessage` — pamięć „to już zrobiłem”. Bez niej at-least-once oznaczałby podwójne skutki.

## Testy

Projekt `tests/JJDevHub.IntegrationEventLog.Tests`. Kontener Postgresa, `TestLogContext` z `ApplyIntegrationEventLog` i tabelą `Effects` (skutek handlera testowego), `EnsureCreatedAsync`. Zdarzenie testowe `SampleIntegrationEvent` z `[EventName("test.integration.sample.v1")]`. `RecordingEventBus` zapisuje koperty i na żądanie rzuca `EventBusPublishException`.

Klasa `IntegrationEventOutboxTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Add_without_transaction_throws` | kontekst bez transakcji | `AddAsync` | `InvalidOperationException` |
| `Add_in_committed_transaction_stores_row` | transakcja | `AddAsync`, `CommitAsync` | jeden `OutboxMessage` z nazwą z atrybutu |
| `Add_in_rolled_back_transaction_stores_nothing` | transakcja | `AddAsync`, `RollbackAsync` | zero wierszy |

Klasa `OutboxProcessorTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Run_publishes_pending_row` | jeden wiersz | `RunOnceAsync` | szyna dostała kopertę z tym `EventId` |
| `Run_sets_processed_on` | jeden wiersz | `RunOnceAsync` | `ProcessedOn` ustawione |
| `Run_skips_processed_row` | wiersz z `ProcessedOn` | `RunOnceAsync` | szyna nic nie dostała |
| `Failed_publish_increments_attempts` | szyna rzuca | `RunOnceAsync` | `Attempts` 1, `ProcessedOn` puste |
| `Parallel_processors_do_not_double_publish` | 20 wierszy, dwa procesory w osobnych kontekstach | `Task.WhenAll` | 20 różnych kopert |

Klasa `InboxReceiverTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Receive_handles_once` | handler dopisujący `Effect` | `ReceiveAsync` | `Handled`, jeden `Effect` |
| `Second_receive_is_duplicate` | ta sama koperta już przyjęta | `ReceiveAsync` | `Duplicate`, nadal jeden `Effect` |
| `Unknown_name_is_ignored` | koperta z obcą nazwą | `ReceiveAsync` | `Ignored` |
| `Throwing_handler_leaves_no_inbox_row` | handler rzuca | `ReceiveAsync` | wyjątek i zero `InboxMessages` |

Klasa `ArticleOutboxTests` w `tests/News.Infrastructure.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Create_writes_outbox_row` | `CreateArticleCommand` | `Send` | jeden `OutboxMessage` z nazwą `news.integration.article-created.v1` |
| `Conflict_writes_no_outbox_row` | rewizja ze starą wersją | `Send` | liczba wierszy outboxa bez zmian |

`dotnet test tests/JJDevHub.IntegrationEventLog.Tests` i `dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- Zdarzenie integracyjne jest `sealed record`, ma `[EventName]`, leży w `*.Contracts` i ma tylko typy proste.
- Zdarzenie domenowe nie wychodzi z usługi. Mapowanie na integracyjne robi handler w Application.
- `AddAsync` outboxa wymaga otwartej transakcji.
- Dispatcher oznacza wiersz dopiero po udanym `PublishAsync`. Dostawa jest co najmniej raz.
- Odbiorca zapisuje `InboxMessage` w tej samej transakcji co skutek.
- Nieznany typ na temacie jest ignorowany, nie zgłaszany jako błąd.

## Poza zakresem

- Kafka, tematy i DLQ — [13-kafka.md](13-kafka.md).
- Konsument w Notifications — [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).
- Outbox w Identity — [15-identity.md](15-identity.md).
- Sprzątanie starych wierszy outboxa i inboxa. Zadanie cykliczne usuwające wiersze starsze niż 7 dni dochodzi, gdy tabele urosną.

## Źródła

- [Transactional outbox pattern](https://learn.microsoft.com/en-us/azure/architecture/databases/guide/transactional-outbox-cosmos) — zapis i publikacja rozdzielone outboxem w bazie usługi.
- [Implementing event-based communication between microservices](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/multi-container-microservice-net-applications/integration-event-based-microservice-communications) — zdarzenia integracyjne, `IntegrationEventLogEF`, idempotencja w eShop.
- [dotnet/eShop — IntegrationEventLogEF](https://github.com/dotnet/eShop/tree/main/src/IntegrationEventLogEF) — tabela outboxa i usługa logu.
- [Transactional Outbox](https://microservices.io/patterns/data/transactional-outbox.html) — Chris Richardson: wzorzec i jego warianty.
- [Idempotent Consumer](https://microservices.io/patterns/communication-style/idempotent-consumer.html) — tabela przetworzonych wiadomości.
- [PostgreSQL SELECT … FOR UPDATE SKIP LOCKED](https://www.postgresql.org/docs/16/sql-select.html#SQL-FOR-UPDATE-SHARE) — kolejka w tabeli bez podwójnego pobrania.
- [Komenda wołająca komendę](https://cezarywalenciuk.pl/blog/programing/command-wywolujacy-kolejny-command-to-kiepski-pomysl) — między kawałkami systemu idzie zdarzenie.

## Gotowe gdy

- `CreateArticleCommand` zostawia w `news_write` jeden `EventRecord` i jeden `OutboxMessage` z tego samego commitu.
- Wycofana transakcja nie zostawia wiersza outboxa.
- Dwa procesory nie wysyłają tej samej wiadomości.
- Powtórzona koperta u odbiorcy kończy się `Duplicate` bez drugiego skutku.
- `dotnet test tests/JJDevHub.IntegrationEventLog.Tests` i `dotnet test tests/News.Infrastructure.Tests` kończą się kodem 0.
