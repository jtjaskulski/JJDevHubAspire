# Agregat

Agregat jest jedynym miejscem, które zmienia swój stan, i jedynym, które pilnuje reguł. `JJDevHub.Domain` dostaje `Entity`, `IAggregateRoot`, `AggregateRoot` i `IBusinessRule`. `News.Domain` dostaje `Article` z dwoma faktami: utworzeniem i rewizją. Zdarzenia i value objecty są w [01-zdarzenie.md](01-zdarzenie.md) i [02-value-object.md](02-value-object.md). Strumień, który zapisze fakty, jest w [04-strumien.md](04-strumien.md).

## Po co

W eShop encja woła `AddDomainEvent`, a lista nazywa się `DomainEvents`. U nas `AddDomainEvent` dodatkowo woła `Apply`, bo stan powstaje ze zdarzenia. Ta sama metoda `Apply` odtwarza agregat z bazy. Stan nie może więc rozjechać się między „zrobiłem” a „odczytałem”.

Z GeekLemon bierzemy trzy rzeczy:

- reguły jako osobne klasy (`IScoringRejectRule`) zamiast `if` w metodzie,
- abstrakcję czasu (`AppTime`) — u nas `TimeProvider` z platformy,
- statyczną fabrykę zamiast metody `Create` na pustym obiekcie, która dawała się zawołać dwa razy.

## Dlaczego ta technologia

### Agregat jako granica spójności

Agregat to grupa obiektów zmienianych razem, z jednym wejściem (korzeniem). Wszystko, co musi być prawdą po każdej zmianie (tytuł niepusty, rewizję robi autor), sprawdza korzeń. Poza nim nikt nie zmienia pól. Dzięki temu reguła nie rozjeżdża się po kontrolerach i serwisach. Evans opisuje to jako podstawowy wzorzec taktyczny DDD, Vernon dodaje zasadę „małe agregaty, referencja po id”. `Article` jest mały: tytuł, treść, autor, daty.

### `Apply` jako jedyne miejsce zmiany stanu

W event sourcingu stan powstaje na dwa sposoby: nowa operacja (`Create`, `Revise`) i odtworzenie ze strumienia (`Replay`). Gdyby każda droga ustawiała pola sama, prędzej czy później by się rozjechały: nowa operacja ustawia `UpdatedAt`, a replay zapomina. Dlatego obie drogi idą przez `Apply(event)`. Operacja sprawdza reguły i tworzy zdarzenie, `Apply` je wykonuje. `Apply` rzuca wyjątek przy nieznanym zdarzeniu, bo cicha ignorancja oznacza stan, który różni się od zapisanej historii.

Alternatywą są osobne metody `When(ArticleCreated)` wywoływane refleksją (styl wielu bibliotek, w tym Eventuous). `switch` po typie jest jawny, szybki i kompilator pomaga przy wzorcach.

### `IBusinessRule` jako klasa

Reguła `OnlyAuthorCanReviseRule` w osobnej klasie ma nazwę, test i błąd (`Forbidden`). Ten sam `if` w środku `Revise` jest krótszy, ale nie da się go nazwać w raporcie testów ani przenieść. GeekLemon robi tak z `IScoringRejectRule`. Koszt: więcej plików. Dla dwóch reguł to akceptowalne, a wzór się skaluje.

### Statyczna fabryka zamiast publicznego konstruktora

Konstruktor nie może zwrócić `Result<T>`. Może tylko rzucić wyjątek albo stworzyć niepoprawny obiekt. `Article.Create(...)` zwraca `Result<Article>`, więc odmowa jest zwykłą wartością. Publiczny konstruktor bez parametrów zostaje tylko dla `Replay`: repozytorium z ograniczeniem `new()` tworzy pusty obiekt i nakłada historię. Pusty `Article` nie ma tytułu, więc nie jest poprawnym artykułem, dopóki nie dostanie zdarzeń. To cena za generyczne repozytorium bez refleksji. Alternatywa (fabryka `Func<T>` w DI) dokłada rejestrację na każdy agregat.

### `TimeProvider` zamiast `DateTime.UtcNow`

Kod, który woła zegar sam, nie da się przetestować deterministycznie: „data utworzenia równa się teraz” to test, który czasem pada. GeekLemon rozwiązuje to własnym `AppTime`. Od .NET 8 platforma ma `TimeProvider` w bibliotece standardowej, a pakiet `Microsoft.Extensions.TimeProvider.Testing` daje `FakeTimeProvider`. Nie piszemy własnego interfejsu zegara, bo standardowy już istnieje i znają go wszystkie biblioteki Microsoftu. W testach wystarcza mały `FixedTimeProvider`.

### `internal MarkPersisted` przez `InternalsVisibleTo`

Wersję agregatu po zapisie musi ustawić magazyn, ale nikt inny. Metoda publiczna (jak dawne `MarkVersion`) pozwalała każdemu przestawić wersję i zepsuć optymistyczną współbieżność. `internal` z `InternalsVisibleTo("JJDevHub.EventStore")` daje dostęp tylko temu jednemu projektowi. To kompromis: domena wie o istnieniu projektu magazynu z nazwy, ale nie zależy od niego w kodzie.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Domain/Entity.cs` | `Guid Id` |
| `src/building-blocks/JJDevHub.Domain/IAggregateRoot.cs` | znacznik korzenia |
| `src/building-blocks/JJDevHub.Domain/AggregateRoot.cs` | `Version`, `DomainEvents`, `AddDomainEvent`, `Apply`, `Replay`, `MarkPersisted`, `Check` |
| `src/building-blocks/JJDevHub.Domain/IBusinessRule.cs` | `IsBroken`, `Error` |
| `src/services/News/News.Domain/Articles/ArticleRevisedDomainEvent.cs` | fakt: zmieniono tytuł lub treść |
| `src/services/News/News.Domain/Articles/ArticleBodyMustFitLimitRule.cs` | treść do 20 000 znaków |
| `src/services/News/News.Domain/Articles/OnlyAuthorCanReviseRule.cs` | rewizja tylko przez autora |
| `src/services/News/News.Domain/Articles/Article.cs` | agregat |
| `tests/JJDevHub.Domain.Tests/AggregateRootTests.cs` | mechanika korzenia na agregacie testowym |
| `tests/News.Domain.Tests/ArticleTests.cs` | reguły i fakty artykułu |

## Plan

### 1. Encja i znacznik

`Entity` jest abstrakcyjna i ma `Guid Id { get; protected set; }`. Konstruktor nie wymusza id: ustawia je pierwsze `Apply`.

`IAggregateRoot` jest pustym interfejsem. `IRepository<T>` z [07-repozytorium.md](07-repozytorium.md) przyjmuje tylko korzenie.

### 2. Reguła biznesowa

```csharp
namespace JJDevHub.Domain;

public interface IBusinessRule
{
    ResultError Error { get; }

    bool IsBroken();
}
```

Reguła to `sealed record` z danymi, które sprawdza. Nie rzuca wyjątku. Zwraca błąd, a agregat przerywa metodę przed `AddDomainEvent`.

### 3. Korzeń agregatu

`AggregateRoot` dziedziczy `Entity` i implementuje `IAggregateRoot`. Powierzchnia:

| Składowa | Widoczność | Co robi |
| --- | --- | --- |
| `int Version` | `public get` | ostatnia wersja zapisana w strumieniu; po samym `Create` równa 0 |
| `IReadOnlyCollection<IDomainEvent> DomainEvents` | `public` | fakty jeszcze nie zapisane |
| `AddDomainEvent(IDomainEvent)` | `protected` | `Apply`, potem dopisanie do listy; `Version` bez zmian |
| `Apply(IDomainEvent)` | `protected abstract` | jedyne miejsce zmiany pól |
| `Replay(IDomainEvent, int version)` | `public` | `Apply` i `Version = version`; lista bez zmian |
| `MarkPersisted(int version)` | `internal` | czyści listę i ustawia `Version` po udanym zapisie |
| `Check(params IBusinessRule[])` | `protected static` | `Error` pierwszej złamanej reguły albo `None` |

`MarkPersisted` jest `internal`, a `JJDevHub.Domain.csproj` dostaje:

```xml
<ItemGroup>
  <InternalsVisibleTo Include="JJDevHub.EventStore" />
</ItemGroup>
```

Tylko repozytorium z [07-repozytorium.md](07-repozytorium.md) może oznaczyć agregat jako zapisany. Kod aplikacji nie przestawi wersji ręcznie.

### 4. Artykuł

`Article : AggregateRoot` jest `sealed`. Stan: `Title` (`string`), `Body`, `AuthorIdentityGuid` (`string?`), `CreatedOn`, `RevisedOn` (`DateTimeOffset?`). Właściwość `ArticleId ArticleId => new(Id)`. Publiczny konstruktor bez parametrów istnieje dla `Replay` i nie ustawia niczego.

Fabryka:

```csharp
public static Result<Article> Create(
    ArticleTitle title, string body, string? authorIdentityGuid, TimeProvider time)
```

- `Check(new ArticleBodyMustFitLimitRule(body))`; błąd wraca od razu jako `Fail`.
- `new Article()`, potem `AddDomainEvent(new ArticleCreatedDomainEvent(Guid.NewGuid(), time.GetUtcNow(), ArticleId.New().Value, title.Value, body, authorIdentityGuid))`.
- `Ok(article)`.

Rewizja:

```csharp
public Result<ArticleId> Revise(
    ArticleTitle title, string body, string? editorIdentityGuid, TimeProvider time)
```

- `Check(new OnlyAuthorCanReviseRule(AuthorIdentityGuid, editorIdentityGuid), new ArticleBodyMustFitLimitRule(body))`.
- Ten sam tytuł i ta sama treść → `Ok(ArticleId)` bez zdarzenia. Ponowione żądanie nie produkuje pustej rewizji.
- Inaczej `AddDomainEvent(new ArticleRevisedDomainEvent(...))` z `[EventName("news.article-revised.v1")]`.

`OnlyAuthorCanReviseRule` łamie się, gdy autor jest znany i różny od edytora. Zwraca wtedy `Forbidden`. Artykuł bez autora (sprzed [16-usluga-news.md](16-usluga-news.md)) może poprawić każdy.

`Apply` to `switch` po typie:

```csharp
protected override void Apply(IDomainEvent domainEvent)
{
    switch (domainEvent)
    {
        case ArticleCreatedDomainEvent created:
            ApplyCreated(created);
            break;
        case ArticleRevisedDomainEvent revised:
            ApplyRevised(revised);
            break;
        default:
            throw new InvalidOperationException($"Article cannot apply {domainEvent.GetType().Name}.");
    }
}
```

Nieznane zdarzenie to błąd kontraktu. Cichy `return` zostawiłby agregat w stanie, którego nie ma w bazie.

### 5. Czas

Czas wchodzi parametrem `TimeProvider`. W API rejestrowany jest `TimeProvider.System`. W teście jest `FixedTimeProvider : TimeProvider` z nadpisanym `GetUtcNow`, zdefiniowany w projekcie testowym. Pakietu z fałszywym zegarem nie dodajemy.

### Co jest do czego

- `Entity` — daje tożsamość. Dwa artykuły o tym samym tytule to dwa różne artykuły.
- `AggregateRoot` — granica spójności i transakcji. Repozytorium zapisuje i ładuje tylko korzenie. Zbiera nowe fakty w `DomainEvents`.
- `Apply` — jedyny kod, który ustawia pola. Wołają go `AddDomainEvent` (nowy fakt) i `Replay` (fakt z bazy).
- `Version` — numer ostatniego zapisanego faktu. Repozytorium podaje go jako oczekiwaną wersję, a magazyn wykrywa konflikt.
- `MarkPersisted` — przejście „w pamięci” → „w bazie”. Woła je wyłącznie `Repository<T>`.
- `IBusinessRule` — reguła z nazwą. Test sprawdza ją osobno, a agregat czyta się jak lista warunków.
- `TimeProvider` — czas jako zależność. Test wie, jakie `DateOccurred` dostanie.
- `Article.Create` / `Article.Revise` — publiczne zachowania. Wołają je handlery komend z [09-komenda.md](09-komenda.md).

## Testy

Klasa `AggregateRootTests` w `tests/JJDevHub.Domain.Tests`. Agregat testowy `Counter` (zdarzenie `Incremented`) jest w pliku testu. Test widzi `MarkPersisted` dzięki `InternalsVisibleTo` dla `JJDevHub.Domain.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Add_applies_and_collects` | nowy `Counter` | `Increment()` | `Value` 1 i jedno zdarzenie |
| `Add_keeps_version` | nowy `Counter` | `Increment()` | `Version` 0 |
| `Replay_sets_version_without_collecting` | nowy `Counter` | `Replay(incremented, 3)` | `Version` 3, lista pusta |
| `Mark_persisted_clears_events` | `Counter` po `Increment()` | `MarkPersisted(1)` | lista pusta, `Version` 1 |
| `Check_returns_first_broken_rule` | reguła `Invalid` i reguła `Conflict`, obie złamane | `Check` | `Invalid` |

Klasa `ArticleTests` w `tests/News.Domain.Tests`. Zegar: `FixedTimeProvider` z `2026-01-01T10:00:00Z`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Create_collects_created_event` | tytuł `Nowy wpis` | `Create` | jedno `ArticleCreatedDomainEvent` |
| `Create_sets_title_through_apply` | tytuł `Nowy wpis` | `Create` | `Title` równe `Nowy wpis` |
| `Create_uses_time_provider` | zegar stały | `Create` | `DateOccurred` równe czasowi zegara |
| `Create_too_long_body_returns_invalid` | treść 20 001 znaków | `Create` | `Invalid` |
| `Revise_by_other_user_returns_forbidden` | artykuł autora `a` | `Revise` przez `b` | `Forbidden` |
| `Revise_without_change_collects_nothing` | artykuł po `Replay` | `Revise` tym samym tytułem i treścią | lista pusta |
| `Revise_collects_revised_event` | artykuł po `Replay` | `Revise` nowym tytułem | jedno `ArticleRevisedDomainEvent` |
| `Apply_unknown_event_throws` | nowy `Article` | `Replay` obcego zdarzenia | `InvalidOperationException` |

`dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests`.

## Zasady

- Metoda publiczna agregatu albo zwraca błąd i nic nie dopisuje, albo dopisuje zdarzenie przez `AddDomainEvent`.
- Pola agregatu zmienia wyłącznie `Apply`. `Apply` nie sprawdza reguł: fakt z bazy już się wydarzył.
- `Apply` rzuca przy nieznanym zdarzeniu.
- Agregat nie woła `DateTimeOffset.UtcNow`. Czas przychodzi przez `TimeProvider`.
- Reguła to `sealed record : IBusinessRule`, jedna na plik.
- `News.Domain` referencjonuje tylko `JJDevHub.Domain`.

## Poza zakresem

- Strumień i konflikt wersji — [04-strumien.md](04-strumien.md).
- Nazwa strumienia `article-{guid}` — [07-repozytorium.md](07-repozytorium.md). Domena nie zna przedrostków bazy.
- Publikacja i wycofanie artykułu. To kolejne zdarzenia według tego samego wzoru.
- Snapshoty.

## Źródła

- [Implement a microservice domain model with DDD](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/net-core-microservice-domain-model) — `Entity`, korzeń agregatu, `AddDomainEvent`.
- [Domain events: design and implementation](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-events-design-implementation) — zbieranie zdarzeń na agregacie.
- [GeekLemonConference — Domain](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example/tree/master/GeekLemonConference.Domain) — `IScoringRejectRule`, `ScoringRules`, `AppTime`.
- [TimeProvider](https://learn.microsoft.com/en-us/dotnet/standard/datetime/timeprovider-overview) — abstrakcja czasu w .NET.
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) — stan jako wynik kolejnych `Apply`.
- [Effective Aggregate Design](https://www.dddcommunity.org/library/vernon_2011/) — Vaughn Vernon: małe agregaty, granica transakcji.
- Eric Evans, *Domain-Driven Design* — agregat i niezmienniki.

## Gotowe gdy

- `Article.Create` jest statyczne i zwraca `Result<Article>`.
- `Apply` jest jedynym miejscem, które ustawia pola artykułu, i rzuca przy nieznanym zdarzeniu.
- `MarkPersisted` jest `internal` i widoczne tylko dla `JJDevHub.EventStore` oraz testów.
- `Revise` przez innego użytkownika zwraca `Forbidden`, a bez zmiany treści nie dopisuje faktu.
- `dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests` kończą się kodem 0.
