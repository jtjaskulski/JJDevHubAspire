# Zdarzenie domenowe

Zdarzenie to rekord opisujący coś, co już się stało. Biblioteka `JJDevHub.Domain` daje kontrakt `IDomainEvent` i atrybut `EventNameAttribute`. Usługa News dostaje pierwszy projekt, `News.Domain`, z przykładem `ArticleCreatedDomainEvent`. Value objecty są w [02-value-object.md](02-value-object.md), agregat, który zbiera zdarzenia, w [03-agregat.md](03-agregat.md).

Kolejność i słownik nazw: [README.md](README.md).

## Po co

Event sourcing zapisuje zdarzenia, nie stan. Zdarzenie żyje w bazie latami, dłużej niż nazwa klasy i namespace. W eShop zdarzenie domenowe żyje tylko w pamięci, do końca transakcji, więc nazwa CLR wystarcza. U nas trafia do `EventRecords`, więc potrzebuje stabilnej nazwy, niezależnej od C#: `news.article-created.v1`. Przeniesienie klasy między projektami nie może zepsuć odczytu starych strumieni.

Biblioteka nie zna żadnego konkretnego zdarzenia. Przykład leży w usłudze od pierwszego dnia, w `src/services/News/News.Domain`, a nie przy API. Dzięki temu test domeny nie referencjonuje projektu webowego, a późniejsze cięcie na warstwy nic nie przenosi.

## Dlaczego ta technologia

### Zdarzenie domenowe jako fakt, nie polecenie

Zdarzenie opisuje coś, co już się stało (`ArticleCreated`), w czasie przeszłym. Komenda (`CreateArticle`) to prośba, którą można odrzucić. Zdarzenia nie da się odrzucić, można najwyżej na nie zareagować. To rozróżnienie jest sercem event sourcingu: w bazie leżą fakty, a stan agregatu jest ich sumą. Gdyby w strumieniu leżały komendy, odtworzenie stanu wymagałoby ponownego uruchomienia logiki biznesowej, która w międzyczasie mogła się zmienić.

### `record` zamiast klasy

Zdarzenie jest niezmienne i porównywane po wartości. C# `record` daje to w jednej linii: konstruktor, właściwości `init`, `Equals`, `ToString`. Klasa z ręcznie pisanymi właściwościami tylko do odczytu robi to samo w dwudziestu liniach i łatwo w niej zostawić publiczny setter. Struktura (`record struct`) przegrywa, bo zdarzenia trafiają do list `IReadOnlyList<IDomainEvent>`, a opakowywanie struktur w interfejs (boxing) niweluje jej zaletę.

### Stabilna nazwa z `[EventName]` zamiast nazwy typu CLR

Poprzednia wersja zapisywała w bazie `AssemblyQualifiedName`, np. `JJDevHub.Events.NewsCreated, JJDevHub.Events, Version=1.0.0.0`. Przeniesienie klasy do innego namespace'u, zmiana nazwy projektu albo podbicie wersji zestawu sprawiały, że stare wiersze przestawały się wczytywać. Strumień zdarzeń żyje latami, kod zmienia się co tydzień. Nazwa `news.article-created.v1` to kontrakt, który nie zależy od układu kodu. Format `kontekst.zdarzenie.wersja` czyta człowiek w SQL-u i konsument w innym języku. Ten sam pomysł stosują EventStoreDB (`eventType`), CloudEvents (`type`) i Marten (aliasy typów).

Alternatywą jest mapa nazw w jednym pliku konfiguracyjnym. Przegrywa, bo nowa klasa zdarzenia wymaga wtedy edycji w dwóch miejscach. Atrybut trzyma nazwę przy typie.

### Typy proste w zdarzeniu

Zdarzenie niesie `Guid`, `string` i `DateTimeOffset`, a nie `ArticleTitle` czy `ArticleId`. Value object może zmienić reguły (np. dłuższy tytuł), a zdarzenie zapisane pięć lat temu musi się dać odczytać bez przechodzenia przez te reguły. Serializacja typów prostych jest też trywialna: żadnych konwerterów JSON. Koszt: przy `Apply` agregat buduje value objecty z prymitywów sam.

### `DateTimeOffset` zamiast `DateTime`

`DateTime` nie wie, w jakiej strefie jest, a `Kind` łatwo zgubić przy serializacji. `DateTimeOffset` niesie przesunięcie, a Npgsql mapuje go na `timestamptz`. Nazwa `DateOccurred` pochodzi z eShop (`IDomainEvent` w e-booku mikroserwisów).

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Domain/JJDevHub.Domain.csproj` | biblioteka, `net11.0`, zero `PackageReference` |
| `src/building-blocks/JJDevHub.Domain/IDomainEvent.cs` | `EventId`, `DateOccurred` |
| `src/building-blocks/JJDevHub.Domain/EventNameAttribute.cs` | stabilna nazwa zdarzenia w danych |
| `src/services/News/News.Domain/News.Domain.csproj` | domena usługi, referencja tylko do `JJDevHub.Domain` |
| `src/services/News/News.Domain/Articles/ArticleCreatedDomainEvent.cs` | fakt: powstał artykuł |
| `tests/JJDevHub.Domain.Tests/JJDevHub.Domain.Tests.csproj` | testy biblioteki |
| `tests/News.Domain.Tests/News.Domain.Tests.csproj` | testy domeny News |

## Plan

### 1. Porządki

Katalogi `src/JJDevHub.Aggregates`, `src/JJDevHub.Events`, `src/JJDevHub.EventStore` i `tests/JJDevHub.EventSourcing.Tests` mają tylko `bin` i `obj` po starym podejściu. Usuń je i wypisz z [JJDevHub.sln](../../JJDevHub.sln), jeśli tam są. Nowe projekty nie mogą kolidować z nimi nazwą.

### 2. Projekty

```bash
dotnet new classlib -n JJDevHub.Domain -o src/building-blocks/JJDevHub.Domain -f net11.0
dotnet new classlib -n News.Domain -o src/services/News/News.Domain -f net11.0
dotnet new xunit -n JJDevHub.Domain.Tests -o tests/JJDevHub.Domain.Tests -f net11.0
dotnet new xunit -n News.Domain.Tests -o tests/News.Domain.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.Domain src/services/News/News.Domain tests/JJDevHub.Domain.Tests tests/News.Domain.Tests
dotnet add src/services/News/News.Domain reference src/building-blocks/JJDevHub.Domain
dotnet add tests/JJDevHub.Domain.Tests reference src/building-blocks/JJDevHub.Domain
dotnet add tests/News.Domain.Tests reference src/services/News/News.Domain
```

`Class1.cs` i `UnitTest1.cs` znikają. Wersje `xunit` i `Microsoft.NET.Test.Sdk` biorą się z [Directory.Packages.props](../../Directory.Packages.props), więc w csproj testów zostaje `PackageReference` bez `Version`. `RootNamespace` w `News.Domain.csproj` to `JJDevHub.News.Domain`.

### 3. Kontrakt zdarzenia

```csharp
namespace JJDevHub.Domain;

public interface IDomainEvent
{
    Guid EventId { get; }

    DateTimeOffset DateOccurred { get; }
}
```

`EventId` jest nowe przy każdym fakcie. Później posłuży do deduplikacji. `DateOccurred` to czas faktu w domenie, nie czas zapisu do bazy.

### 4. Nazwa zdarzenia

```csharp
namespace JJDevHub.Domain;

[AttributeUsage(AttributeTargets.Class, Inherited = false)]
public sealed class EventNameAttribute(string name) : Attribute
{
    public string Name { get; } = name;
}
```

Format nazwy: `kontekst.fakt.vN`, małe litery, fakt w kebab-case i w czasie przeszłym. `v1` podnosi się tylko przy zmianie kształtu, której nie da się odczytać starym kodem. Upcasting opisuje [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md).

### 5. Zdarzenie artykułu

`src/services/News/News.Domain/Articles/ArticleCreatedDomainEvent.cs`:

```csharp
using JJDevHub.Domain;

namespace JJDevHub.News.Domain.Articles;

[EventName("news.article-created.v1")]
public sealed record ArticleCreatedDomainEvent(
    Guid EventId,
    DateTimeOffset DateOccurred,
    Guid ArticleId,
    string Title,
    string Body,
    string? AuthorIdentityGuid) : IDomainEvent;
```

Pola są typami prostymi. `ArticleTitle` z [02-value-object.md](02-value-object.md) nie wchodzi do zdarzenia, bo zmiana value objectu zmieniłaby JSON w bazie. `AuthorIdentityGuid` jest od początku, choć do [16-usluga-news.md](16-usluga-news.md) zostaje `null`. Pole dodane później wymagałoby `v2`.

### Co jest do czego

- `IDomainEvent` — wspólny typ wszystkich faktów. Dzięki niemu `AggregateRoot` trzyma jedną listę `DomainEvents`, a magazyn ma jedno `AppendAsync`. Implementują go rekordy zdarzeń w domenach usług.
- `EventId` — tożsamość faktu, nie agregatu. Odbiorca po nim rozpozna duplikat. Wypełnia go metoda agregatu w [03-agregat.md](03-agregat.md).
- `DateOccurred` — kiedy fakt zaszedł w domenie. Projekcja pokaże go jako datę utworzenia artykułu.
- `EventNameAttribute` — kontrakt danych. Czyta go `EventTypeRegistry` z [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md), żeby zapisać nazwę zamiast `AssemblyQualifiedName`.
- `ArticleCreatedDomainEvent` — pierwszy fakt agregatu `Article`. Produkuje go `Article.Create`, konsumuje `Apply`, a później projekcja i mapowanie na zdarzenie integracyjne.
- `News.Domain` — najgłębsza warstwa usługi. Nie ma w niej EF, JSON-a ani HTTP. Wszystko inne w News od niej zależy.

## Testy

Klasa `EventNameAttributeTests` w `tests/JJDevHub.Domain.Tests`. Zdarzenie testowe (`SampleHappenedDomainEvent`) jest `sealed record` w pliku testu.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Attribute_exposes_name` | typ z `[EventName("test.sample-happened.v1")]` | odczyt atrybutu refleksją | `Name` równe `test.sample-happened.v1` |
| `Attribute_is_not_inherited` | typ pochodny bez atrybutu | `GetCustomAttribute<EventNameAttribute>()` | `null` |

Klasa `ArticleCreatedDomainEventTests` w `tests/News.Domain.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Event_has_stable_name` | typ `ArticleCreatedDomainEvent` | odczyt atrybutu | `news.article-created.v1` |
| `Same_values_are_equal` | dwa rekordy o tych samych polach | porównanie | równe |
| `Different_event_id_is_not_equal` | te same pola poza `EventId` | porównanie | różne |

`dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests`.

## Zasady

- Zdarzenie jest `sealed record`, implementuje `IDomainEvent` i ma `[EventName]`.
- Nazwa klasy jest w czasie przeszłym i kończy się na `DomainEvent`. Nazwa w atrybucie ma sufiks `.vN`.
- Pola zdarzenia to typy proste. Bez value objectów, encji i kolekcji encji.
- Nowe pole, którego stare zdarzenia nie mają, jest nullable albo dostaje nową wersję nazwy.
- `JJDevHub.Domain` nie referencjonuje żadnej usługi, EF ani `System.Text.Json`.

## Poza zakresem

- `ValueObject`, `ArticleId`, `ArticleTitle` — [02-value-object.md](02-value-object.md).
- `AggregateRoot` i `Article` — [03-agregat.md](03-agregat.md).
- Serializacja i mapa nazwa → typ — [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md).
- Zdarzenie integracyjne na szynę — [12-outbox-inbox.md](12-outbox-inbox.md).

## Źródła

- [Domain events: design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation) — zdarzenie jako fakt w czasie przeszłym, różnica między domenowym a integracyjnym.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — zdarzenie jako trwały zapis, nie komunikat w pamięci.
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning/read) — Greg Young: stabilne nazwy, wersje i upcasting.
- [GeekLemonConference — Domain](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example/tree/master/GeekLemonConference.Domain) — zdarzenia przy agregacie w projekcie domeny.
- [dotnet/eShop — Ordering.Domain](https://github.com/dotnet/eShop/tree/main/src/Ordering.Domain) — `OrderStartedDomainEvent` i katalog `Events`.
- Vaughn Vernon, *Implementing Domain-Driven Design* — rozdział o zdarzeniach domenowych.

## Gotowe gdy

- Puste katalogi starego podejścia są usunięte.
- `JJDevHub.Domain` buduje się bez `PackageReference`.
- `ArticleCreatedDomainEvent` leży w `News.Domain` i ma nazwę `news.article-created.v1`.
- `News.Domain` referencjonuje tylko `JJDevHub.Domain`.
- `dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests` kończą się kodem 0.
