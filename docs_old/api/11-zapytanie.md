# Zapytanie

Zapytanie czyta gotowy widok. `News.Application` dostaje `GetArticleQuery`, `ListArticlesQuery`, model odczytu `ArticleSummary` i port `IArticleSummaryReader`. `News.Infrastructure` dostaje `ArticleSummaryReader` na `NewsReadContext`. Widok buduje projekcja z [10-projekcja.md](10-projekcja.md). Komenda, która zmienia stan, jest w [09-komenda.md](09-komenda.md). Endpointy zapytań są w [16-usluga-news.md](16-usluga-news.md).

## Po co

CQRS w dokumentacji Microsoftu rozdziela zapis od odczytu także w kodzie. eShop pisze zapytania Ordering jako osobne klasy z prostym SQL-em, bez agregatów i bez repozytorium. U nas zapytanie nie otwiera strumienia, nie składa `Article` i nie wie, że istnieje event sourcing.

Port w Application i implementacja w Infrastructure to cebula z GeekLemon. Handler da się przetestować na stubie, a EF zostaje tam, gdzie reszta bazy.

## Dlaczego ta technologia

### Zapytanie przez mediator

Endpoint mógłby czytać `NewsReadContext` sam. Przechodząc przez mediator, zapytanie dostaje te same zachowania co komenda: log z czasem i walidację parametrów. `TransactionBehavior` rozpoznaje `IQuery` i transakcji nie otwiera. Jednolitość kosztuje jedną klasę handlera, a daje jedno miejsce na późniejszy cache zapytań.

### Port `IArticleSummaryReader` zamiast `IQueryable` albo kontekstu w Application

Application mówi, czego potrzebuje (`FindAsync`, `ListAsync`), a nie jak to zdobyć. `IQueryable<ArticleSummaryRow>` wystawione do Application wyglądałoby elastycznie, ale przenosi EF do warstwy, która nie powinna go znać: zapytanie składane w handlerze wykonuje się dopiero w bazie, a błąd tłumaczenia LINQ wychodzi w runtime. Port z dwiema metodami jest nudny i dlatego dobry. Implementacja w Infrastructure używa `AsNoTracking`, bo widok jest tylko do odczytu.

### Model odczytu `ArticleSummary` osobno od wiersza tabeli

`ArticleSummaryRow` to encja EF (mapowanie, klucz, kolumny). `ArticleSummary` to rekord, który wychodzi z Application. Rozdzielenie pozwala zmienić tabelę (np. dodać kolumnę techniczną) bez zmiany kontraktu odczytu.

### Stronicowanie offsetem z limitem 50

`OFFSET/LIMIT` jest najprostsze i wystarcza, dopóki artykułów jest setki. Przy dziesiątkach tysięcy duży offset staje się wolny i lepszy jest keyset (`WHERE CreatedOn < @ostatni`). Limit 50 w walidatorze chroni bazę przed `PageSize=100000` już dziś. Przejście na keyset zmienia tylko czytnik i parametry zapytania.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/News/News.Application/Articles/ArticleSummary.cs` | `ArticleId`, `Title`, `Body`, `AuthorIdentityGuid`, `CreatedOn`, `RevisedOn`, `Version` |
| `src/services/News/News.Application/Articles/IArticleSummaryReader.cs` | `FindAsync`, `ListAsync` |
| `src/services/News/News.Application/Articles/GetArticleQuery.cs` | `ArticleId` |
| `src/services/News/News.Application/Articles/GetArticleQueryHandler.cs` | jeden widok albo `NotFound` |
| `src/services/News/News.Application/Articles/ListArticlesQuery.cs` | `Page`, `PageSize` |
| `src/services/News/News.Application/Articles/ListArticlesQueryValidator.cs` | granice stronicowania |
| `src/services/News/News.Application/Articles/ListArticlesQueryHandler.cs` | strona widoków |
| `src/services/News/News.Infrastructure/Read/ArticleSummaryReader.cs` | EF na `NewsReadContext` |
| `tests/News.Application.Tests/GetArticleQueryTests.cs` | handler na stubie |
| `tests/News.Infrastructure.Tests/ArticleSummaryReaderTests.cs` | czytnik na kontenerze |

## Plan

### 1. Model odczytu

```csharp
namespace JJDevHub.News.Application.Articles;

public sealed record ArticleSummary(
    Guid ArticleId,
    string Title,
    string Body,
    string? AuthorIdentityGuid,
    DateTimeOffset CreatedOn,
    DateTimeOffset? RevisedOn,
    int Version);
```

To DTO pod ekran, nie encja EF. `ArticleSummaryRow` z [10-projekcja.md](10-projekcja.md) zostaje w Infrastructure. `Version` trafi do nagłówka `ETag`, żeby klient mógł wysłać rewizję z `If-Match`.

### 2. Port

```csharp
namespace JJDevHub.News.Application.Articles;

public interface IArticleSummaryReader
{
    Task<ArticleSummary?> FindAsync(Guid articleId, CancellationToken cancellationToken);

    Task<IReadOnlyList<ArticleSummary>> ListAsync(int skip, int take, CancellationToken cancellationToken);
}
```

`null` jest dozwolone na granicy portu. Handler zamienia je na `NotFound`, raz.

### 3. Zapytania i handlery

- `GetArticleQuery(Guid ArticleId) : IQuery<ArticleSummary>`. `GetArticleQueryHandler(IArticleSummaryReader reader)` zwraca `NotFound` dla `null`, inaczej `Ok`.
- `ListArticlesQuery(int Page, int PageSize) : IQuery<IReadOnlyList<ArticleSummary>>`. Walidator `ListArticlesQueryValidator : AbstractValidator<ListArticlesQuery>`: `RuleFor(q => q.Page).GreaterThanOrEqualTo(1)` i `RuleFor(q => q.PageSize).InclusiveBetween(1, 50)`. `ValidatorBehavior` zamienia porażkę na `Invalid`. Handler woła `ListAsync((Page - 1) * PageSize, PageSize)`.

Zapytanie nie przechodzi przez transakcję: `TransactionBehavior` z [08-mediator.md](08-mediator.md) pomija `IQuery`.

### 4. Czytnik

`ArticleSummaryReader(NewsReadContext read) : IArticleSummaryReader`:

- `FindAsync` → `AsNoTracking`, `Where(ArticleId)`, `Select` do `ArticleSummary`, `FirstOrDefaultAsync`,
- `ListAsync` → `AsNoTracking`, `OrderByDescending(CreatedOn)`, `ThenBy(ArticleId)`, `Skip`, `Take`, `Select`, `ToListAsync`.

Projekcja `Select` idzie do SQL. Encja nie jest materializowana.

`AddNewsRead` z [10-projekcja.md](10-projekcja.md) dostaje rejestrację `IArticleSummaryReader` → `ArticleSummaryReader` (scoped).

### Co jest do czego

- `ArticleSummary` — kontrakt odczytu w Application. Endpoint zwraca go jako JSON, a test porównuje rekordy.
- `IArticleSummaryReader` — port. Application mówi „potrzebuję widoku”, nie „potrzebuję EF”.
- `GetArticleQuery` / `ListArticlesQuery` — dwie intencje odczytu. Dalsze (po autorze, wyszukiwanie) dochodzą według tego wzoru.
- `ListArticlesQueryValidator` — chroni bazę przed `PageSize=100000`.
- `ArticleSummaryReader` — jedyne miejsce, które zna tabelę `ArticleSummaries` po stronie odczytu.

## Testy

Klasa `GetArticleQueryTests` w `tests/News.Application.Tests`. `StubArticleSummaryReader` w pliku testu trzyma słownik.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Get_returns_summary` | stub z jednym widokiem | `Send(GetArticleQuery)` | `Title` z widoku |
| `Get_missing_returns_not_found` | pusty stub | `Send` | `NotFound` |
| `List_zero_page_returns_invalid` | dowolny stub | `Send(ListArticlesQuery(0, 10))` | `Invalid` |
| `List_too_large_page_returns_invalid` | dowolny stub | `Send(ListArticlesQuery(1, 51))` | `Invalid` |

Klasa `ArticleSummaryReaderTests` w `tests/News.Infrastructure.Tests`. Kontener, migracja `NewsReadContext`, wiersze wstawione w arrange przez kontekst. Strumień nie jest otwierany.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Find_returns_row` | jeden wiersz | `FindAsync` | rekord z tym tytułem |
| `Find_missing_returns_null` | pusta tabela | `FindAsync` | `null` |
| `List_orders_newest_first` | trzy wiersze o różnych `CreatedOn` | `ListAsync(0, 10)` | malejąco po `CreatedOn` |
| `List_pages` | trzy wiersze | `ListAsync(2, 10)` | jeden rekord |

`dotnet test tests/News.Application.Tests` i `dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- Nazwa zapytania zaczyna się od `Get` albo `List` i kończy na `Query`.
- Handler zapytania nie zna `IEventStore`, `IRepository<Article>` ani `NewsWriteContext`.
- Odpowiedź to DTO z Application. Ani `Article`, ani `ArticleSummaryRow` nie wychodzą z handlera.
- Czytnik używa `AsNoTracking` i `Select` do DTO.
- Zapytanie nie naprawia widoku. Widok składa projekcja.

## Poza zakresem

- `GET /api/articles` i `ETag` — [16-usluga-news.md](16-usluga-news.md).
- Wyszukiwanie pełnotekstowe. Postgres `tsvector` na tym samym widoku, gdy dojdzie ekran.
- Cache odpowiedzi.

## Źródła

- [Implement reads/queries in a CQRS microservice](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/cqrs-microservice-reads) — zapytania bez agregatów, DTO pod ekran, eShop Ordering.
- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs) — zapytania do bazy zoptymalizowanej pod odczyt.
- [Tracking vs. no-tracking queries](https://learn.microsoft.com/en-us/ef/core/querying/tracking) — `AsNoTracking` dla odczytu.
- [Pagination](https://learn.microsoft.com/en-us/ef/core/querying/pagination) — `Skip`/`Take` i stabilne sortowanie.
- [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) — zapytania w Application, odczyt w Persistence.

## Gotowe gdy

- `GetArticleQuery` zwraca `ArticleSummary` z `news_read`, a brak wiersza daje `NotFound`.
- `ListArticlesQuery` zwraca strony od najnowszego i odrzuca `PageSize` powyżej 50.
- W handlerach zapytań nie ma `IEventStore` ani `IRepository<Article>`.
- `dotnet test tests/News.Application.Tests` i `dotnet test tests/News.Infrastructure.Tests` kończą się kodem 0.
