# Strumień zdarzeń

Strumień to uporządkowana lista zdarzeń jednego agregatu. `IEventStore` dopisuje je przez `AppendAsync`, oddaje jeden strumień przez `LoadAsync`, a wszystkie zdarzenia po kolei przez `ReadAllAsync`. Ten numer trzyma dane w pamięci. Agregat, który fakty produkuje, jest w [03-agregat.md](03-agregat.md). Serializacja jest w [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md), Postgres w [06-postgres.md](06-postgres.md).

## Po co

Dwa równoległe zapisy tej samej wersji mają zwrócić `ResultError.Conflict`. To optymistyczna współbieżność: nikt nie blokuje agregatu na czas edycji, a przegrany dostaje konflikt i ładuje świeży stan. Test tego zachowania nie potrzebuje bazy. `InMemoryEventStore` jest testem kontraktu i wzorcem dla `PostgresEventStore`.

Drugi licznik, `Position`, jest globalny dla całego magazynu. `Version` mówi „który to fakt tego artykułu”. `Position` mówi „który to fakt w ogóle”. Projekcja z [10-projekcja.md](10-projekcja.md) czyta po `Position`, żeby jednym checkpointem obsłużyć wszystkie strumienie.

## Dlaczego ta technologia

### Gdzie leży strumień

Zwykła tabela stanu trzyma tylko „teraz”. Kto zmienił tytuł, kiedy, jak brzmiał wczoraj, nie wiadomo bez osobnej tabeli audytu, którą trzeba pamiętać uzupełniać. W event sourcingu źródłem prawdy jest lista faktów, a stan jest liczony. Historia, audyt i nowy widok są przejściem po zdarzeniach od początku.

Koszt jest realny: dwa modele (zapis i odczyt), ostateczna spójność odczytu, wersjonowanie zdarzeń, więcej kodu. Strumień dostają miejsca, w których ten koszt się zwraca:

- News — rewizje, publikacja i wycofanie artykułu ([21-notatki.md](21-notatki.md)),
- Learning — technologia, kurs, lekcja, wykład i hasło. Lekcja ma własny strumień: wyjaśnienie i przykłady kodu. Kurs trzyma kolejność id lekcji ([19-learning.md](19-learning.md)),
- Identity — każda zmiana konta i zaproszenia ([15-identity.md](15-identity.md)),
- Cv — historia profilu, stanowiska, projektu, edukacji, aktywności, umiejętności i języka; każdy agregat ma własny strumień, a dokument CV jest widokiem ([22-cv.md](22-cv.md)).

Notifications zostaje przy EF, tak jak ślad wysyłki nie potrzebuje strumienia. Postęp studenta też: to tabela w bazie zapisu Learning, nie strumień kursu.

### Wersja w strumieniu i globalna pozycja

`Version` mówi, które to zdarzenie w historii jednego artykułu (1, 2, 3…). Służy optymistycznej współbieżności: „dopisz, jeśli strumień ma nadal wersję 2”. `Position` to numer zdarzenia w całym magazynie, rosnący przez wszystkie strumienie. Służy projekcjom: „daj mi wszystko po pozycji 1500”. Jedna liczba nie wystarczy do obu celów. Sama wersja nie mówi projekcji, gdzie skończyła w skali całej bazy. Sama pozycja nie mówi agregatowi, czy ktoś go zmienił. EventStoreDB (dziś KurrentDB) ma ten sam podział: `StreamRevision` i `Position`.

### Optymistyczna współbieżność zamiast blokad

Dwie osoby edytują ten sam artykuł. Pesymistyczna blokada (zablokuj wiersz na czas edycji) nie działa w HTTP, gdzie między odczytem a zapisem mija minuta. Optymistyczna zakłada, że konflikt jest rzadki, i wykrywa go przy zapisie: oczekiwana wersja się nie zgadza → `Conflict`. Klient odświeża i próbuje ponownie. To ten sam mechanizm, który HTTP wyraża przez `ETag` i `If-Match` w [16-usluga-news.md](16-usluga-news.md).

### Własny `IEventStore` zamiast gotowego magazynu

Gotowe rozwiązania są dobre i darmowe:

- **Marten** (MIT) — event sourcing na PostgreSQL z projekcjami, snapshotami i asynchronicznym demonem. W projekcie produkcyjnym byłby pierwszym wyborem, bo używa tej samej bazy co reszta.
- **KurrentDB / EventStoreDB** — osobny serwer zbudowany pod strumienie. Najlepszy w swojej klasie, ale to kolejny proces do utrzymania na jednej VM, a licencja serwera zmieniała się w ostatnich latach.
- **Eventuous** (Apache 2.0) — biblioteka na KurrentDB albo Postgresie z gotowym agregatem i projekcjami.

Wybieramy własny interfejs, bo celem ciągu jest zrozumienie mechanizmu: co to jest strumień, jak działa konflikt wersji, skąd projekcja wie, gdzie skończyła. Każda z bibliotek chowa to za jednym wywołaniem. Interfejs jest celowo mały (`AppendAsync`, `LoadAsync`, `ReadAllAsync`), więc podmiana na Martena później dotyka tylko Infrastructure.

### Implementacja w pamięci najpierw

`InMemoryEventStore` pozwala napisać i przetestować całą logikę (konflikt, pozycje, kolejność) bez Dockera, w milisekundach. Postgres w [06-postgres.md](06-postgres.md) musi przejść te same testy. Pamięciowa wersja zostaje w testach Application jako szybki dubler.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.EventStore/JJDevHub.EventStore.csproj` | referencja tylko do Domain |
| `src/building-blocks/JJDevHub.EventStore/IEventStore.cs` | `AppendAsync`, `LoadAsync`, `ReadAllAsync` |
| `src/building-blocks/JJDevHub.EventStore/StoredEvent.cs` | `Position`, `StreamId`, `Version`, `DomainEvent` |
| `src/building-blocks/JJDevHub.EventStore/EventStreamRead.cs` | `Version` strumienia i jego zdarzenia |
| `src/building-blocks/JJDevHub.EventStore/InMemoryEventStore.cs` | słownik strumieni, lista globalna, `lock` |
| `tests/JJDevHub.EventStore.Tests/InMemoryEventStoreTests.cs` | konflikt, kolejność, `Position` |

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.EventStore -o src/building-blocks/JJDevHub.EventStore -f net11.0
dotnet new xunit -n JJDevHub.EventStore.Tests -o tests/JJDevHub.EventStore.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.EventStore tests/JJDevHub.EventStore.Tests
dotnet add src/building-blocks/JJDevHub.EventStore reference src/building-blocks/JJDevHub.Domain
dotnet add tests/JJDevHub.EventStore.Tests reference src/building-blocks/JJDevHub.EventStore
```

### 2. Kształty

```csharp
namespace JJDevHub.EventStore;

public sealed record StoredEvent(long Position, string StreamId, int Version, IDomainEvent DomainEvent);
```

```csharp
namespace JJDevHub.EventStore;

public sealed record EventStreamRead(int Version, IReadOnlyList<StoredEvent> Events);
```

Każdy rekord ma własny plik.

### 3. Kontrakt

```csharp
namespace JJDevHub.EventStore;

public interface IEventStore
{
    Task<Result<int>> AppendAsync(
        string streamId,
        int expectedVersion,
        IReadOnlyCollection<IDomainEvent> domainEvents,
        string? identityGuid,
        CancellationToken cancellationToken);

    Task<EventStreamRead> LoadAsync(string streamId, CancellationToken cancellationToken);

    Task<IReadOnlyList<StoredEvent>> ReadAllAsync(
        long afterPosition, int maxCount, CancellationToken cancellationToken);
}
```

- `AppendAsync` zwraca nową wersję strumienia albo `Conflict`. Pusta lista zdarzeń to `Invalid`.
- `identityGuid` jest właścicielem strumienia (autor artykułu). Zapisuje się przy pierwszym zapisie i dalej się nie zmienia.
- `LoadAsync` nieznanego strumienia zwraca `Version` 0 i pustą listę. Brak strumienia to nie błąd magazynu. `NotFound` zwraca dopiero repozytorium.
- `ReadAllAsync` zwraca zdarzenia o `Position > afterPosition`, rosnąco, najwyżej `maxCount`.

### 4. Oczekiwana wersja

Pusty strumień przyjmuje `expectedVersion` równe 0. Po dwóch zdarzeniach w jednej paczce wersja wynosi 2, a zdarzenia mają wersje 1 i 2.

`InMemoryEventStore` trzyma słownik `streamId` → lista `StoredEvent` i jedną listę globalną. Zapis wchodzi pod `lock`:

- wersja zapisana (0 dla nieznanego) różna od oczekiwanej → `Conflict`, nic się nie zmienia,
- inaczej każde zdarzenie dostaje `Version = expected + i + 1` i `Position = ++lastPosition` i trafia do obu list.

Instancje zdarzeń wracają z `LoadAsync` te same, które weszły. JSON dochodzi w [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md).

### Co jest do czego

- `IEventStore` — port zapisu. Repozytorium zna tylko ten interfejs, więc test używa pamięci, a produkcja Postgresa.
- `expectedVersion` — token współbieżności. Wołający mówi „zmieniam stan, który widziałem w wersji N”.
- `Conflict` — sygnał „ktoś był szybszy”. Endpoint zamieni go na `409` w [16-usluga-news.md](16-usluga-news.md).
- `StoredEvent` — zdarzenie z metadanymi magazynu. `Replay` potrzebuje `Version`, projekcja potrzebuje `Position`.
- `EventStreamRead` — odpowiedź `LoadAsync`. `Version` wystarcza, żeby odróżnić pusty strumień od istniejącego.
- `ReadAllAsync` — czytanie „od miejsca, w którym skończyłem”. Woła je `ProjectionWorker`.
- `InMemoryEventStore` — magazyn testowy i specyfikacja zachowania. Te same testy przejdą później na Postgresie.

## Testy

Klasa `InMemoryEventStoreTests` w `tests/JJDevHub.EventStore.Tests`. Zdarzenie testowe `SampleHappenedDomainEvent` jest w pliku testu. Strumień: `sample-{guid}`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Append_to_empty_stream_returns_batch_size` | pusty magazyn, dwa zdarzenia, wersja 0 | `AppendAsync` | `Ok(2)` |
| `Append_with_stale_version_returns_conflict` | strumień w wersji 1 | `AppendAsync` z wersją 0 | `Conflict` |
| `Stale_append_leaves_stream_unchanged` | strumień z jednym faktem | zapis ze złą wersją, potem `LoadAsync` | wersja 1, jeden fakt |
| `Append_with_current_version_appends` | strumień w wersji 1 | `AppendAsync` z wersją 1 | `LoadAsync` zwraca dwa fakty, wersja 2 |
| `Load_unknown_stream_returns_empty` | pusty magazyn | `LoadAsync` | wersja 0, pusta lista |
| `Append_empty_batch_returns_invalid` | dowolny strumień | `AppendAsync` z pustą listą | `Invalid` |
| `Positions_grow_across_streams` | zapis do `a`, potem do `b` | `ReadAllAsync(0, 10)` | pozycje 1 i 2, w tej kolejności |
| `Read_all_skips_up_to_position` | trzy fakty | `ReadAllAsync(2, 10)` | jeden fakt z pozycją 3 |
| `Parallel_appends_one_wins` | pusty strumień | dwa `AppendAsync` z wersją 0 przez `Task.WhenAll` | dokładnie jeden `Conflict` |

`dotnet test tests/JJDevHub.EventStore.Tests`.

## Zasady

- Wersje w strumieniu rosną o 1, bez dziur. `Position` rośnie o 1 w całym magazynie.
- Konflikt nie rzuca wyjątku i nie zmienia danych.
- `IdentityGuid` strumienia ustawia pierwszy zapis. Kolejne go nie nadpisują.
- `InMemoryEventStore` jest `sealed` i bez zależności w konstruktorze.
- Projekt nie referencjonuje EF ani żadnej usługi.

## Poza zakresem

- JSON i nazwy typów — [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md).
- Tabele `EventStreams` i `EventRecords` — [06-postgres.md](06-postgres.md).
- `IRepository<T>` i `Replay` — [07-repozytorium.md](07-repozytorium.md).

## Źródła

- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — strumień agregatu, dopisywanie, odtworzenie.
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) — Martin Fowler: replay i wersja jako ochrona przed zgubioną aktualizacją.
- [Optimistic concurrency](https://learn.microsoft.com/en-us/ef/core/saving/concurrency) — oczekiwana wersja jako token współbieżności.
- [Optimistic Offline Lock](https://martinfowler.com/eaaCatalog/optimisticOfflineLock.html) — wzorzec konfliktu przy zapisie.
- Greg Young, [Versioning in an Event Sourced System](https://leanpub.com/esversioning/read) — rozdział o strumieniach i oczekiwanej wersji.

## Gotowe gdy

- `AppendAsync` z wersją 0 na pusty strumień zwraca liczbę zapisanych zdarzeń.
- Drugi zapis z tą samą oczekiwaną wersją zwraca `Conflict`, a strumień się nie zmienia.
- `ReadAllAsync` zwraca zdarzenia wielu strumieni w kolejności `Position`.
- Równoległe zapisy tej samej wersji dają jeden sukces i jeden konflikt.
- `dotnet test tests/JJDevHub.EventStore.Tests` kończy się kodem 0.
