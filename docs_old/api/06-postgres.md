# Postgres zapisu

`PostgresEventStore<TContext>` trzyma strumienie w tabelach `EventStreams` i `EventRecords`. Biblioteka `JJDevHub.EventStore.Postgres` daje encje, mapowanie (`ApplyEventStore`) i magazyn. Usługa News dostaje własny kontekst `NewsWriteContext` w `News.Infrastructure`, bazę `news_write` i pierwszą migrację. Kontrakt magazynu jest w [04-strumien.md](04-strumien.md), serializer w [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md). Repozytorium, które tego magazynu użyje, jest w [07-repozytorium.md](07-repozytorium.md).

## Po co

Biblioteka nie może mieć własnego `DbContext` z migracjami, bo każda usługa ma swoją bazę, a do tej samej transakcji co zdarzenia musi później wejść outbox z [12-outbox-inbox.md](12-outbox-inbox.md). eShop rozwiązuje to tak samo: `OrderingContext` jest w usłudze, a `IntegrationEventLogContext` dzieli z nim połączenie. U nas biblioteka daje klocki do `OnModelCreating`, a kontekst i migracje są w usłudze.

Globalna kolumna `Position` ma jedną pułapkę w Postgresie. Sekwencja przydziela numery przy `INSERT`, a nie przy commicie. Transakcja z pozycją 11 może się zatwierdzić przed transakcją z pozycją 10. Worker przeczyta wtedy 11, zapisze checkpoint 11 i nigdy nie zobaczy 10. Dlatego zapis bierze `pg_advisory_xact_lock`: zapisy zdarzeń w jednej bazie idą po kolei, a kolejność commitów zgadza się z kolejnością pozycji. Przy ruchu bloga to tani koszt.

## Dlaczego ta technologia

### PostgreSQL jako magazyn zdarzeń

Postgres już działa w projekcie (Identity), ma transakcje, `jsonb` z indeksami i sprawdzoną obsługę na jednej VM. Magazyn zdarzeń to w gruncie rzeczy tabela tylko do dopisywania z unikalnym `(StreamId, Version)`, a to relacyjna baza robi dobrze. Najważniejszy argument: zdarzenia i outbox z [12-outbox-inbox.md](12-outbox-inbox.md) zapisują się w jednej transakcji tej samej bazy. Osobny serwer zdarzeń (KurrentDB) wymagałby rozproszonej transakcji albo innego mechanizmu publikacji.

MongoDB i SQL Server przegrywają, bo dokładają drugi silnik bazodanowy bez korzyści, które by to uzasadniały.

### `jsonb` zamiast `json` albo kolumn

Zdarzenia mają różne kształty, więc kolumna na pole nie wchodzi w grę. `jsonb` jest przechowywany w postaci binarnej: wolniejszy zapis o ułamek, ale szybkie zapytania po polach (`Data->>'authorIdentityGuid'`) i możliwe indeksy GIN, gdy kiedyś będą potrzebne do diagnostyki. `json` trzyma tekst dosłownie, łącznie z kolejnością kluczy, czego nie potrzebujemy.

### EF Core zamiast Dappera albo czystego Npgsql

Dapper (Apache 2.0) jest dozwolony i dałby szybsze, ręczne SQL-e. EF Core wygrywa z trzech powodów: migracje schematu w tym samym narzędziu co Identity, jedna transakcja `DbContext` wspólna dla zdarzeń i outboxa, oraz gotowe integracje Aspire (health check, ślady, metryki) z [14-aspire.md](14-aspire.md). Ścieżka zapisu to jeden `INSERT` kilku wierszy, więc narzut ORM jest pomijalny. Tam, gdzie EF nie wystarcza (advisory lock), wołamy SQL przez `Database.ExecuteSqlAsync`.

### Biblioteka bez własnego `DbContext`

`JJDevHub.EventStore.Postgres` daje tylko mapowanie (`ApplyEventStore(modelBuilder)`) i klasę generyczną po kontekście (`PostgresEventStore<TContext>`). Kontekst i migracje należą do usługi (`NewsWriteContext`). Gdyby biblioteka miała własny kontekst, outbox (inny kontekst) nie mógłby wejść do tej samej transakcji bez współdzielenia połączenia ręcznie. eShop robi podobnie z `IntegrationEventLogEF`: mapowanie w bibliotece, kontekst w usłudze.

### Advisory lock zamiast samej sekwencji

`Position` to kolumna `identity`. Sekwencja Postgresa przydziela numery w chwili `INSERT`, a nie commitu. Transakcja A dostaje 10, transakcja B dostaje 11 i commituje pierwsza. Projekcja czyta „wszystko po 9”, widzi 11, zapisuje checkpoint 11 i nigdy nie zobaczy 10. To realny błąd, opisany przy wielu magazynach na Postgresie. `pg_advisory_xact_lock` na jedną stałą serializuje dopisywanie do magazynu: numery są przydzielane w kolejności commitów. Koszt: zapisy do News nie idą równolegle. Przy blogu z jednym autorem to bez znaczenia. Marten rozwiązuje ten sam problem „high water mark” bardziej złożonym algorytmem.

Poziom izolacji `SERIALIZABLE` też by pomógł, ale kończyłby się ponawianiem transakcji, a lock po prostu czeka.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.EventStore.Postgres/JJDevHub.EventStore.Postgres.csproj` | referencja do EventStore, pakiet `Npgsql.EntityFrameworkCore.PostgreSQL` |
| `src/building-blocks/JJDevHub.EventStore.Postgres/EventStream.cs` | `StreamId`, `Version`, `IdentityGuid` |
| `src/building-blocks/JJDevHub.EventStore.Postgres/EventRecord.cs` | `Position`, `StreamId`, `Version`, `EventId`, `EventType`, `Payload`, `DateOccurred` |
| `src/building-blocks/JJDevHub.EventStore.Postgres/EventStoreModelBuilderExtensions.cs` | `ApplyEventStore(this ModelBuilder)` |
| `src/building-blocks/JJDevHub.EventStore.Postgres/PostgresEventStore.cs` | `IEventStore` na dowolnym `DbContext` z mapowaniem |
| `src/building-blocks/JJDevHub.EventStore.Postgres/EventStoreServiceCollectionExtensions.cs` | `AddPostgresEventStore<TContext>()` |
| `src/services/News/News.Infrastructure/News.Infrastructure.csproj` | infrastruktura News |
| `src/services/News/News.Infrastructure/Persistence/NewsWriteContext.cs` | kontekst bazy `news_write` |
| `src/services/News/News.Infrastructure/Persistence/NewsWriteContextFactory.cs` | `IDesignTimeDbContextFactory` dla `dotnet ef` |
| `src/services/News/News.Infrastructure/Persistence/Migrations/` | `NewsWriteInitial` |
| `tests/JJDevHub.EventStore.Postgres.Tests/` | magazyn na kontekście testowym |
| `tests/News.Infrastructure.Tests/` | migracja usługi |

## Plan

### 1. Projekty

```bash
dotnet new classlib -n JJDevHub.EventStore.Postgres -o src/building-blocks/JJDevHub.EventStore.Postgres -f net11.0
dotnet new classlib -n News.Infrastructure -o src/services/News/News.Infrastructure -f net11.0
dotnet new xunit -n JJDevHub.EventStore.Postgres.Tests -o tests/JJDevHub.EventStore.Postgres.Tests -f net11.0
dotnet new xunit -n News.Infrastructure.Tests -o tests/News.Infrastructure.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.EventStore.Postgres src/services/News/News.Infrastructure tests/JJDevHub.EventStore.Postgres.Tests tests/News.Infrastructure.Tests
dotnet add src/building-blocks/JJDevHub.EventStore.Postgres reference src/building-blocks/JJDevHub.EventStore
dotnet add src/building-blocks/JJDevHub.EventStore.Postgres package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/services/News/News.Infrastructure reference src/building-blocks/JJDevHub.EventStore.Postgres src/services/News/News.Domain
dotnet add src/services/News/News.Infrastructure package Microsoft.EntityFrameworkCore.Design
```

`Microsoft.EntityFrameworkCore.Design` w `News.Infrastructure` ma `PrivateAssets="all"`, tak jak dziś w API. Testy dostają `Testcontainers.PostgreSql`. Wersje są już w [Directory.Packages.props](../../Directory.Packages.props).

### 2. Encje

- `EventStream` (`sealed`): klucz `StreamId` (`string`, do 200 znaków), `Version` (`int`), `IdentityGuid` (`string?`).
- `EventRecord` (`sealed`):
  - `Position` (`long`) — klucz, `UseIdentityAlwaysColumn()`,
  - `StreamId` i `Version` — unikalny indeks złożony,
  - `EventId` (`Guid`) — unikalny indeks,
  - `EventType` (`string`) — nazwa z rejestru, nie nazwa CLR,
  - `Payload` (`string`) — `HasColumnType("jsonb")`,
  - `DateOccurred` (`DateTimeOffset`).

`ApplyEventStore` mapuje obie encje na tabele `EventStreams` i `EventRecords`. Kontekst usługi woła je w `OnModelCreating`.

### 3. Kontekst usługi

```csharp
namespace JJDevHub.News.Infrastructure.Persistence;

public sealed class NewsWriteContext(DbContextOptions<NewsWriteContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyEventStore();
    }
}
```

Baza `news_write` ma tylko ten kontekst, więc historia migracji zostaje domyślna `__EFMigrationsHistory`. `NewsWriteContextFactory` czyta connection string ze zmiennej `ConnectionStrings__news-write`, a bez niej bierze `Host=localhost;Port=5433;Database=news_write;Username=postgres;Password=password`.

```bash
dotnet ef migrations add NewsWriteInitial \
  --project src/services/News/News.Infrastructure \
  --context NewsWriteContext \
  --output-dir Persistence/Migrations
```

### 4. Append

`PostgresEventStore<TContext> where TContext : DbContext` dostaje `TContext` i `IEventSerializer` primary constructorem. `AppendAsync`:

- pusta lista → `Invalid`,
- transakcja: gdy `Database.CurrentTransaction` jest `null`, metoda otwiera własną i ją zatwierdza; gdy transakcja już jest (otworzył ją `TransactionBehavior` z [08-mediator.md](08-mediator.md)), metoda w niej uczestniczy i jej nie zatwierdza,
- `SELECT pg_advisory_xact_lock(@key)` ze stałym kluczem `EventStoreLock.Key`,
- odczyt `EventStream` po `StreamId`; brak wiersza przy `expectedVersion != 0` albo inna `Version` → `Conflict`,
- brak wiersza i wersja 0 → nowy `EventStream` z `IdentityGuid`,
- dla każdego zdarzenia `EventRecord` z `Version = expected + i + 1`, `EventType` i `Payload` z `Serialize`,
- `Version` strumienia podbite o liczbę zdarzeń, `SaveChangesAsync(cancellationToken)`.

`DbUpdateException` z naruszeniem unikalności (`PostgresException.SqlState == "23505"`) zamienia się na `Conflict`. Inny wyjątek bazy przechodzi dalej. Po `Conflict` w cudzej transakcji wołający musi ją wycofać, bo Postgres oznaczył ją jako przerwaną. Robi to `TransactionBehavior`.

### 5. Load i ReadAll

- `LoadAsync`: `EventRecords` danego strumienia, `AsNoTracking`, `OrderBy(Version)`, każdy przez `Deserialize(EventType, Payload)` do `StoredEvent`. Wersja to `Version` z `EventStreams` albo 0.
- `ReadAllAsync`: `Position > afterPosition`, `OrderBy(Position)`, `Take(maxCount)`, `AsNoTracking`.

### 6. Rejestracja

```csharp
services.AddPostgresEventStore<NewsWriteContext>();
```

Rozszerzenie rejestruje `IEventStore` → `PostgresEventStore<NewsWriteContext>` jako scoped. `AddDbContext`, rejestr i serializer dodaje usługa, bo connection string i zestawy zdarzeń zna tylko ona.

### Co jest do czego

- `EventStream` — jeden wiersz na agregat: aktualna wersja i właściciel. Na nim sprawdzamy konflikt.
- `EventRecord` — jeden wiersz na fakt. Nigdy się nie zmienia i nie jest usuwany.
- `Position` — globalny porządek w bazie. Czyta go projekcja.
- `EventId` z unikalnym indeksem — ten sam fakt nie trafi do bazy dwa razy.
- `ApplyEventStore` — mapowanie do wpięcia w kontekst usługi. Dzięki niemu outbox wejdzie później do tego samego kontekstu i tej samej transakcji.
- `pg_advisory_xact_lock` — gwarancja, że kolejność commitów zgadza się z `Position`.
- `NewsWriteContext` — kontekst bazy `news_write`, właściciel migracji.
- `PostgresEventStore<TContext>` — implementacja `IEventStore`. Repozytorium nie widzi różnicy względem pamięci.

## Testy

Projekt `tests/JJDevHub.EventStore.Postgres.Tests`, klasa `PostgresEventStoreTests`. Kontener `PostgreSqlBuilder("postgres:16-alpine")`. Kontekst testowy `TestEventStoreContext` woła `ApplyEventStore`, a schemat tworzy `EnsureCreatedAsync`. Biblioteka nie ma migracji. Fixture implementuje `IAsyncLifetime`, jak [`ApiFactory`](../../tests/JJDevHub.Api.Tests/ApiFactory.cs).

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Append_stores_stream_version` | jedno zdarzenie, wersja 0 | `AppendAsync` | `EventStreams.Version` równe 1 |
| `Append_stores_identity_guid` | `identityGuid` równe `"abc"` | `AppendAsync` | `EventStreams.IdentityGuid` równe `abc` |
| `Append_stores_attribute_name` | zdarzenie z `[EventName]` | `AppendAsync` | `EventRecords.EventType` równe nazwie z atrybutu |
| `Load_roundtrip_returns_event` | zapis jednego faktu | `LoadAsync` | zdarzenie równe zapisanemu |
| `Stale_append_returns_conflict` | strumień w wersji 1 | `AppendAsync` z wersją 0 | `Conflict` |
| `Stale_append_does_not_add_row` | strumień z jednym faktem | zapis ze złą wersją | nadal jeden `EventRecord` |
| `Parallel_appends_one_wins` | dwa konteksty, pusty strumień | dwa `AppendAsync` z wersją 0 równolegle | jeden `Conflict` |
| `Read_all_orders_by_position` | zapisy do dwóch strumieni | `ReadAllAsync(0, 10)` | pozycje rosną |
| `Append_joins_outer_transaction` | `BeginTransactionAsync`, `AppendAsync`, `RollbackAsync` | `LoadAsync` | pusty strumień |

Projekt `tests/News.Infrastructure.Tests`, klasa `NewsWriteMigrationTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Migrate_creates_event_tables` | świeży kontener | `NewsWriteContext.Database.MigrateAsync` | są `EventStreams` i `EventRecords` |

`dotnet test tests/JJDevHub.EventStore.Postgres.Tests` i `dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- Biblioteka nie ma własnego `DbContext` z migracjami. Kontekst i migracje są w usłudze.
- `EventType` to nazwa z rejestru.
- `Payload` to `jsonb`. Pola zdarzenia nie dostają własnych kolumn w bazie zapisu.
- `AppendAsync` uczestniczy w istniejącej transakcji i nie zatwierdza cudzej.
- Każdy zapis bierze `pg_advisory_xact_lock` przed odczytem wersji.
- `CancellationToken` idzie do każdego `ToListAsync`, `ExecuteSql*` i `SaveChangesAsync`.

## Poza zakresem

- `IRepository<T>` — [07-repozytorium.md](07-repozytorium.md).
- Baza `news_read` — [10-projekcja.md](10-projekcja.md).
- Tabela `OutboxMessages` w `NewsWriteContext` — [12-outbox-inbox.md](12-outbox-inbox.md).
- Connection string z Aspire — [14-aspire.md](14-aspire.md).
- Zmiana [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml). Do `14` baza żyje w testach i lokalnie.

## Źródła

- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — magazyn zdarzeń jako log tylko do dopisywania.
- [Infrastructure persistence layer with EF Core](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-implementation-entity-framework-core) — kontekst w usłudze, jak `OrderingContext`.
- [Npgsql EF Core: JSON mapping](https://www.npgsql.org/efcore/mapping/json.html) — kolumna `jsonb`.
- [Npgsql EF Core: identity columns](https://www.npgsql.org/efcore/modeling/generated-properties.html) — `UseIdentityAlwaysColumn`.
- [PostgreSQL advisory locks](https://www.postgresql.org/docs/16/explicit-locking.html#ADVISORY-LOCKS) — `pg_advisory_xact_lock` trzymany do końca transakcji.
- [Using transactions in EF Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions) — `CurrentTransaction` i transakcja współdzielona.
- [Migrations overview](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/) — `dotnet ef migrations` i fabryka design-time.

## Gotowe gdy

- `NewsWriteInitial` tworzy `EventStreams` i `EventRecords` w `news_write`.
- `EventRecords.EventType` zawiera `news.article-created.v1`, a nie nazwę CLR.
- Drugi zapis ze starą wersją zwraca `Conflict`, a liczba wierszy się nie zmienia.
- `AppendAsync` w cudzej transakcji wycofuje się razem z nią.
- `dotnet test tests/JJDevHub.EventStore.Postgres.Tests` i `dotnet test tests/News.Infrastructure.Tests` kończą się kodem 0.
