# Value object

Value object to wartość bez tożsamości: dwa tytuły o tym samym tekście są tym samym tytułem. `JJDevHub.Domain` dostaje `ValueObject` oraz `Result<T>` z `ResultError`, bo tworzenie value objectu może się nie udać. `News.Domain` dostaje `ArticleId` i `ArticleTitle`. Zdarzenie, które przenosi te wartości jako typy proste, jest w [01-zdarzenie.md](01-zdarzenie.md). Agregat, który ich używa, jest w [03-agregat.md](03-agregat.md).

## Po co

Bez value objectów agregat dostaje `string title` i sam pilnuje, że tekst nie jest pusty, nie jest za długi i nie ma białych znaków na brzegach. Ta sama reguła wraca potem w walidatorze, w endpointach i w testach. GeekLemon trzyma takie wartości w katalogu `ValueObjects` domeny. Każda pilnuje swojej reguły w jednym miejscu, a agregat dostaje gotową, poprawną wartość.

Typowany identyfikator (`ArticleId` zamiast `Guid`) zamyka drugą klasę błędów: kompilator nie pozwoli podać id użytkownika tam, gdzie oczekiwane jest id artykułu.

## Dlaczego ta technologia

### Value object zamiast `string`

`string title` przyjmie pusty tekst, dwa megabajty i same spacje. Każda metoda, która go dostaje, musi to sprawdzić albo ufać, że ktoś sprawdził wcześniej. `ArticleTitle` da się zbudować tylko przez `Create`, który sprawdza reguły. Jeśli masz w ręku `ArticleTitle`, to jest poprawny. Reguła żyje w jednym miejscu, a kompilator pilnuje, żeby nikt nie podał treści w miejsce tytułu. GeekLemon trzyma takie typy w folderze `ValueObjects`, a e-book mikroserwisów .NET opisuje klasę bazową `ValueObject` z `GetEqualityComponents`. Koszt: osobny typ na każde pojęcie i `Create` zamiast przypisania.

### Klasa bazowa `ValueObject` i `record` obok siebie

`record` daje równość po wartości za darmo i jest dobry dla prostych typów. Klasa bazowa `ValueObject` z `GetEqualityComponents` jest potrzebna, gdy równość ma ignorować część pól albo porównywać kolekcje po elementach, czego `record` nie robi (porównuje referencje list). Trzymamy obie drogi: bazę dla złożonych value objectów, wzór z eShop, i `record struct` dla identyfikatorów. Sama klasa bazowa przegrałaby przy identyfikatorze, bo alokowałaby obiekt tam, gdzie wystarcza struktura. Sam `record` przegrałby przy kolekcji, bo porównuje listy po referencji. Koszt: nowy value object musi wybrać jedną z tych dróg.

### Typowane id jako `readonly record struct`

`Guid` artykułu i `Guid` użytkownika są nie do odróżnienia, a zamiana argumentów miejscami kompiluje się bez ostrzeżenia. `ArticleId` to osobny typ: pomyłka jest błędem kompilacji. `readonly record struct` nie alokuje na stercie, więc kosztuje tyle co sam `Guid`. Biblioteki generujące takie typy (StronglyTypedId, Vogen, obie MIT) są dozwolone, ale przy kilku identyfikatorach w całym systemie generator jest większy niż kod, który by wygenerował.

### `Result<T>` zamiast wyjątków dla oczekiwanych błędów

Pusty tytuł to nie awaria, tylko normalna odpowiedź „nie”. Wyjątek w takim miejscu jest kosztowny (ślad stosu), niewidoczny w sygnaturze metody i kusi, żeby złapać go piętro wyżej ogólnym `catch`. `Result<T>` mówi w sygnaturze: ta metoda może odmówić. `ResultError` to wyliczenie (`Invalid`, `NotFound`, `Conflict`, `Forbidden`), które endpoint w [16-usluga-news.md](16-usluga-news.md) mapuje jeden do jednego na `400`, `404`, `409`/`412`, `403`. Wyjątki zostają dla awarii: baza nie odpowiada, brak rejestracji w DI.

Darmowe biblioteki istnieją: Ardalis.Result (MIT), FluentResults (MIT), ErrorOr (MIT), OneOf (MIT). Każda jest większa, niż potrzebujemy, i każda ma własny pomysł na listę błędów i komunikaty. Nasz typ ma jedno pole błędu i jedno pole wartości, a `TryGetValue` z `[NotNullWhen(true)]` daje analizę null bez operatora `!`. Gdy kiedyś potrzebne będą komunikaty per pole, ErrorOr jest najbliższy naszemu kształtowi.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Domain/ResultError.cs` | `None`, `Invalid`, `NotFound`, `Conflict`, `Forbidden` |
| `src/building-blocks/JJDevHub.Domain/Result.cs` | `Result<T>` |
| `src/building-blocks/JJDevHub.Domain/ValueObject.cs` | równość po składowych |
| `src/services/News/News.Domain/Articles/ArticleId.cs` | typowany identyfikator |
| `src/services/News/News.Domain/Articles/ArticleTitle.cs` | tytuł: niepusty, przycięty, do 200 znaków |
| `tests/JJDevHub.Domain.Tests/ValueObjectTests.cs` | równość na przykładowym `Money` |
| `tests/News.Domain.Tests/ArticleTitleTests.cs` | reguły tytułu |

`Email` pojawia się w Identity w [15-identity.md](15-identity.md) według tego samego wzoru.

## Plan

### 1. Wynik

```csharp
namespace JJDevHub.Domain;

public enum ResultError
{
    None,
    Invalid,
    NotFound,
    Conflict,
    Forbidden,
}
```

```csharp
namespace JJDevHub.Domain;

public sealed record Result<T>(T? Value, ResultError Error)
{
    public bool Succeeded => Error == ResultError.None;

    public static Result<T> Ok(T value) => new(value, ResultError.None);

    public static Result<T> Fail(ResultError error) => new(default, error);

    public bool TryGetValue([NotNullWhen(true)] out T? value)
    {
        value = Value;
        return Succeeded && value is not null;
    }
}
```

`TryGetValue` (z `System.Diagnostics.CodeAnalysis`) daje wartość bez operatora `!`, którego zakazuje [.cursor/rules/csharp.mdc](../../.cursor/rules/csharp.mdc). Wołający pisze `if (!result.TryGetValue(out var title)) return …`.

`Result<T>` jest jeden w całym ciągu. Magazyn, mediator i endpointy zwracają ten sam typ. API mapuje `ResultError` na kod HTTP w jednym miejscu, w [16-usluga-news.md](16-usluga-news.md).

### 2. Bazowy value object

```csharp
namespace JJDevHub.Domain;

public abstract class ValueObject
{
    protected abstract IEnumerable<object?> GetEqualityComponents();

    public override bool Equals(object? obj)
    {
        if (obj is not ValueObject other || other.GetType() != GetType())
        {
            return false;
        }

        return GetEqualityComponents().SequenceEqual(other.GetEqualityComponents());
    }

    public override int GetHashCode() => GetEqualityComponents().Aggregate(0, HashCode.Combine);
}
```

Dochodzą operatory `==` i `!=` delegujące do `Equals`. Bez nich porównanie dwóch tytułów przez `==` sprawdzałoby referencje, a to częsty błąd w testach.

### 3. Typowany identyfikator

```csharp
namespace JJDevHub.News.Domain.Articles;

public readonly record struct ArticleId(Guid Value)
{
    public static ArticleId New() => new(Guid.NewGuid());

    public override string ToString() => Value.ToString();
}
```

Identyfikator to `record struct`, nie `ValueObject`. Ma jedną składową, a rekord daje równość za darmo. `ValueObject` zostaje dla wartości z regułą albo z kilkoma składowymi.

### 4. Tytuł

`ArticleTitle` dziedziczy `ValueObject`, ma prywatny konstruktor i fabrykę:

```csharp
public static Result<ArticleTitle> Create(string? value)
```

Kroki fabryki:

- `null` albo same białe znaki → `Invalid`,
- przycięcie `Trim()`,
- długość powyżej `MaxLength` (stała `200`) → `Invalid`,
- inaczej `Ok(new ArticleTitle(trimmed))`.

`Value` jest jedyną składową równości. `ToString()` zwraca `Value`.

### Co jest do czego

- `Result<T>` — nośnik oczekiwanego błędu. Fabryka value objectu, agregat, repozytorium i handler mówią „nie wyszło, bo…” bez wyjątku. Wołający sprawdza `Succeeded`.
- `ResultError` — zamknięta lista powodów. `Forbidden` dochodzi dla edycji cudzego artykułu w [16-usluga-news.md](16-usluga-news.md).
- `ValueObject` — baza dla wartości z regułą. Daje równość po składowych, żeby `ArticleTitle.Create("A") == ArticleTitle.Create("A")`.
- `ArticleId` — chroni przed pomyleniem identyfikatorów. Używa go agregat, repozytorium (id strumienia) i komenda rewizji.
- `ArticleTitle` — jedyne miejsce reguły tytułu. Woła go `Article.Create` i `Article.Revise`. Walidator komendy z [09-komenda.md](09-komenda.md) używa tej samej fabryki, więc reguła nie jest skopiowana.

## Testy

Klasa `ValueObjectTests` w `tests/JJDevHub.Domain.Tests`. `Money` (kwota i waluta) jest `sealed` i zostaje w pliku testu.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Equal_components_are_equal` | dwa `Money` po `10 PLN` | `Equals` | `true` |
| `Equal_components_share_hash_code` | dwa `Money` po `10 PLN` | `GetHashCode` | równe |
| `Different_amount_is_not_equal` | `10 PLN` i `11 PLN` | `Equals` | `false` |
| `Different_type_is_not_equal` | `Money` i drugi typ o tych samych składowych | `Equals` | `false` |
| `Equality_operator_compares_components` | dwa `Money` po `10 PLN` | `==` | `true` |

Klasa `ResultTests` w `tests/JJDevHub.Domain.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Ok_gives_value` | `Result<int>.Ok(5)` | `TryGetValue` | `true` i 5 |
| `Fail_gives_no_value` | `Result<string>.Fail(Invalid)` | `TryGetValue` | `false` |

Klasa `ArticleTitleTests` w `tests/News.Domain.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Blank_title_is_invalid` | `"   "` | `Create` | `Invalid` |
| `Null_title_is_invalid` | `null` | `Create` | `Invalid` |
| `Too_long_title_is_invalid` | 201 znaków | `Create` | `Invalid` |
| `Title_is_trimmed` | `"  Nowy wpis  "` | `Create` | `Value` równe `Nowy wpis` |
| `Same_text_is_equal` | dwa razy `"Nowy wpis"` | `Create` i `==` | `true` |

`dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests`.

## Zasady

- Value object jest niezmienny. Brak publicznych setterów.
- Value object z regułą ma prywatny konstruktor i fabrykę `Create` zwracającą `Result<T>`.
- Value object nie trzyma tożsamości encji. Identyfikator to osobny `record struct`.
- `Result<T>` jest `sealed record` i jest jeden, w `JJDevHub.Domain`.
- Value object nie trafia do JSON-a zdarzenia. Zdarzenie dostaje `title.Value`.

## Poza zakresem

- Agregat i reguły złożone z kilku wartości — [03-agregat.md](03-agregat.md).
- Mapowanie `ArticleId` na kolumnę EF w widoku — [10-projekcja.md](10-projekcja.md).
- `Email` — [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).

## Źródła

- [Implement value objects](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/implement-value-objects) — bazowa klasa `ValueObject` z eShop i równość po składowych.
- [Domain model validations](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-model-layer-validations) — walidacja w konstruktorze lub fabryce wartości.
- [GeekLemonConference — ValueObjects](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example/tree/master/GeekLemonConference.Domain/ValueObjects) — wartości domeny w osobnym katalogu.
- [Value Object](https://martinfowler.com/bliki/ValueObject.html) — Martin Fowler: równość po wartości, niezmienność.
- [Records](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record) — `record struct` dla typowanego identyfikatora.
- Eric Evans, *Domain-Driven Design* — value object jako wartość bez tożsamości.

## Gotowe gdy

- `Result<T>` i `ResultError` leżą w `JJDevHub.Domain`.
- `ValueObject` porównuje składowe i ma operatory `==` oraz `!=`.
- `ArticleTitle.Create("  ")` zwraca `Invalid`, a `Create("  Nowy wpis ")` zwraca tytuł `Nowy wpis`.
- `ArticleId` jest `readonly record struct`.
- `dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/News.Domain.Tests` kończą się kodem 0.
