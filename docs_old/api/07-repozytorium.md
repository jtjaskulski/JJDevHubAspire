# Repozytorium

`IRepository<T>` zapisuje nowe fakty agregatu i składa go z powrotem przez `Replay`. Handler komendy zna tylko ten interfejs, nie magazyn. Nazwę strumienia i właściciela podaje `IStreamNaming<T>` z infrastruktury usługi, więc domena nie zna przedrostków bazy. Magazyn jest w [04-strumien.md](04-strumien.md) i [06-postgres.md](06-postgres.md), agregat w [03-agregat.md](03-agregat.md). Komenda, która woła repozytorium, jest w [09-komenda.md](09-komenda.md).

## Po co

W dokumentacji Microsoftu `IRepository<T>` stoi między aplikacją a trwałością. W eShop zapis idzie przez `UnitOfWork` i `SaveEntitiesAsync`. Przy event sourcingu zapis to dopisanie zdarzeń z oczekiwaną wersją, a odczyt to replay strumienia. Repozytorium chowa obie operacje za dwiema metodami.

Wcześniejsza wersja tej specyfikacji kazała agregatowi implementować `IHasStream`, a `MarkVersion` było publiczne. Domena znała wtedy pojęcie strumienia, a każdy mógł przestawić wersję. Teraz nazwa strumienia jest w infrastrukturze, a wersję ustawia `internal` `MarkPersisted`, widoczne tylko dla tego projektu.

## Dlaczego ta technologia

### Repozytorium nad magazynem zdarzeń

Handler komendy chce powiedzieć „daj mi artykuł” i „zapisz artykuł”. Nie powinien wiedzieć, że artykuł to strumień, że trzeba zebrać `DomainEvents`, podać oczekiwaną wersję i wywołać `MarkPersisted`. Repozytorium chowa ten przepis. Microsoft w e-booku mikroserwisów zaleca jedno repozytorium na agregat i tylko dla korzeni agregatów, bez ogólnych `IQueryable`. U nas `IRepository<T>` ma dwie metody i nic więcej.

Generyczne repozytorium ma złą sławę, kiedy jest cienką nakładką na `DbSet` z `GetAll` i `Find(predicate)`. Tutaj tego problemu nie ma: magazyn zdarzeń i tak umie tylko „wczytaj strumień” i „dopisz”, więc repozytorium jest generyczne z natury.

### `IStreamNaming<T>` zamiast `IHasStream` w agregacie

Wcześniej agregat implementował interfejs z nazwą strumienia. Domena znała wtedy pojęcie z infrastruktury i każdy agregat powtarzał format `article-{id}`. Osobny `IStreamNaming<Article>` w Infrastructure mówi, jak nazwać strumień i kto jest jego właścicielem (`IdentityGuid` autora), a agregat zostaje czysty. Koszt: jedna mała klasa i rejestracja w DI na agregat.

### `Result<int>` z `SaveAsync`

Zapis może się nie udać w oczekiwany sposób: konflikt wersji. To jest `Result.Fail(Conflict)`, a nie wyjątek, bo handler ma na to sensowną odpowiedź (`409`). Wyjątek przegrał: sygnatura `SaveAsync` nie mówiłaby, że odmowa jest normalna. Udany zapis zwraca nową wersję, potrzebną do nagłówka `ETag`. Koszt: handler rozgałęzia się na `Result`, zamiast liczyć, że wyjątek poleci sam.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.EventStore/IRepository.cs` | `GetAsync`, `SaveAsync` |
| `src/building-blocks/JJDevHub.EventStore/IStreamNaming.cs` | `StreamId`, `IdentityGuid` |
| `src/building-blocks/JJDevHub.EventStore/Repository.cs` | implementacja na `IEventStore` |
| `src/services/News/News.Infrastructure/Persistence/ArticleStreamNaming.cs` | `article-{guid}`, autor jako właściciel |
| `tests/JJDevHub.EventStore.Tests/RepositoryTests.cs` | runda w pamięci na agregacie testowym |
| `tests/News.Infrastructure.Tests/ArticleRepositoryTests.cs` | runda `Article` na Postgresie |

## Plan

### 1. Kontrakty

```csharp
namespace JJDevHub.EventStore;

public interface IRepository<T>
    where T : AggregateRoot, new()
{
    Task<Result<T>> GetAsync(Guid id, CancellationToken cancellationToken);

    Task<Result<int>> SaveAsync(T aggregate, CancellationToken cancellationToken);
}
```

```csharp
namespace JJDevHub.EventStore;

public interface IStreamNaming<in T>
    where T : AggregateRoot
{
    string StreamId(Guid id);

    string? IdentityGuid(T aggregate);
}
```

`new()` jest potrzebne, bo `GetAsync` składa pustą instancję przed `Replay`. Dlatego `Article` ma publiczny konstruktor bez parametrów, który nic nie ustawia.

### 2. Zapis

`Repository<T>` dostaje `IEventStore` i `IStreamNaming<T>` primary constructorem. `SaveAsync`:

- `DomainEvents` puste → `Ok(aggregate.Version)`, bez wołania magazynu,
- `AppendAsync(naming.StreamId(aggregate.Id), aggregate.Version, aggregate.DomainEvents, naming.IdentityGuid(aggregate), ct)`,
- sukces → `aggregate.MarkPersisted(result.Value)`,
- `Conflict` → zwrot bez zmian; `DomainEvents` zostają, żeby wołający mógł zdecydować, co dalej.

`JJDevHub.Domain.csproj` ma już `InternalsVisibleTo` dla `JJDevHub.EventStore` z [03-agregat.md](03-agregat.md).

### 3. Odczyt

`GetAsync`:

- `LoadAsync(naming.StreamId(id), ct)`,
- `Version` 0 → `Fail(NotFound)`,
- inaczej `new T()`, potem `Replay(stored.DomainEvent, stored.Version)` dla każdego zdarzenia,
- `Ok(aggregate)`.

Po odczycie `DomainEvents` jest puste, a `Version` równa się wersji ostatniego faktu.

### 4. Nazwa strumienia artykułu

```csharp
namespace JJDevHub.News.Infrastructure.Persistence;

public sealed class ArticleStreamNaming : IStreamNaming<Article>
{
    public string StreamId(Guid id) => $"article-{id}";

    public string? IdentityGuid(Article aggregate) => aggregate.AuthorIdentityGuid;
}
```

### 5. Rejestracja

```csharp
services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
services.AddSingleton<IStreamNaming<Article>, ArticleStreamNaming>();
```

Pełny skład usługi (`AddNewsInfrastructure`) powstaje w [10-projekcja.md](10-projekcja.md).

### Co jest do czego

- `IRepository<T>` — port dla warstwy Application. Handler mówi „daj artykuł” i „zapisz artykuł”, nie „dopisz zdarzenia do strumienia”.
- `Repository<T>` — jedna implementacja dla wszystkich agregatów z event sourcingiem. Tłumaczy agregat na wywołania `IEventStore`.
- `IStreamNaming<T>` — wiedza o bazie, której domena nie powinna mieć: przedrostek strumienia i właściciel.
- `ArticleStreamNaming` — `article-{guid}` i autor jako `IdentityGuid` strumienia.
- `MarkPersisted` — moment, w którym fakty przestają być „nowe”. Woła je wyłącznie `Repository<T>`.
- `NotFound` — brak strumienia z perspektywy aplikacji. Endpoint zamieni go na `404`.

## Testy

Klasa `RepositoryTests` w `tests/JJDevHub.EventStore.Tests`. `InMemoryEventStore`, agregat testowy `Counter` i `CounterStreamNaming` w plikach testu.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Save_sets_version` | `Counter` po dwóch `Increment` | `SaveAsync` | `Version` równe 2 |
| `Save_clears_domain_events` | `Counter` po `Increment` | `SaveAsync` | `DomainEvents` puste |
| `Save_without_events_skips_store` | `Counter` już zapisany | drugie `SaveAsync` | magazyn ma nadal jeden fakt |
| `Save_conflict_keeps_domain_events` | dwie kopie tego samego `Counter`, pierwsza zapisana | `SaveAsync` drugiej po `Increment` | `Conflict` i jedno zdarzenie na liście |
| `Get_restores_state` | zapisany `Counter` z wartością 2 | `GetAsync` | `Value` 2 |
| `Get_leaves_domain_events_empty` | zapisany `Counter` | `GetAsync` | `DomainEvents` puste |
| `Get_unknown_id_returns_not_found` | pusty magazyn | `GetAsync` | `NotFound` |

Klasa `ArticleRepositoryTests` w `tests/News.Infrastructure.Tests`. Kontener i `MigrateAsync` jak w [06-postgres.md](06-postgres.md).

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Save_writes_article_stream` | `Article.Create` | `SaveAsync` | jest wiersz `EventStreams` o `StreamId` `article-{id}` |
| `Save_writes_author_as_identity_guid` | artykuł autora `a` | `SaveAsync` | `IdentityGuid` strumienia równe `a` |
| `Get_restores_revised_title` | zapis, `Revise`, zapis | `GetAsync` | `Title` równe tytułowi rewizji i `Version` 2 |

`dotnet test tests/JJDevHub.EventStore.Tests` i `dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- `GetAsync` woła `Replay`. `AddDomainEvent` przy odczycie nie występuje.
- `SaveAsync` podaje `aggregate.Version` sprzed nowych faktów jako oczekiwaną wersję.
- Repozytorium nie serializuje JSON-a. To robi magazyn.
- Brak strumienia to `NotFound`, nie wyjątek i nie pusty agregat.
- Domena nie zna `IStreamNaming<T>` ani przedrostka `article-`.

## Poza zakresem

- Mediator i handler — [08-mediator.md](08-mediator.md), [09-komenda.md](09-komenda.md).
- Ponawianie komendy po `Conflict`. Decyzję podejmuje klient: dostaje `409` i aktualną wersję.
- Cache agregatów i snapshoty.

## Źródła

- [Design the infrastructure persistence layer](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/infrastructure-persistence-layer-design) — repozytorium na agregat, interfejs w domenie lub aplikacji, implementacja w infrastrukturze.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — odtworzenie agregatu z jego strumienia.
- [Repository](https://martinfowler.com/eaaCatalog/repository.html) — Martin Fowler: kolekcja obiektów domeny nad mechanizmem trwałości.
- [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) — repozytorium event sourcingu w warstwie infrastruktury, obok repozytorium SQL.
- [InternalsVisibleTo](https://learn.microsoft.com/en-us/dotnet/api/system.runtime.compilerservices.internalsvisibletoattribute) — ograniczenie `MarkPersisted` do jednego zestawu.

## Gotowe gdy

- `SaveAsync` po `Article.Create` zostawia w `news_write` strumień `article-{id}` w wersji 1, a agregat ma `Version` 1 i puste `DomainEvents`.
- `GetAsync` zwraca artykuł z tytułem z ostatniej rewizji.
- Nieznane id zwraca `NotFound`.
- `MarkPersisted` nie jest wołane poza `Repository<T>`.
- `dotnet test tests/JJDevHub.EventStore.Tests` i `dotnet test tests/News.Infrastructure.Tests` kończą się kodem 0.
