# Komenda

Komenda zmienia stan. Usługa News dostaje warstwę `News.Application` z dwiema komendami: `CreateArticleCommand` i `ReviseArticleCommand`. Handler buduje value objecty, woła agregat i zapisuje go przez `IRepository<Article>`. `News.Infrastructure` dostaje `NewsUnitOfWork` i metodę składu `AddNewsWrite`. Mediator jest w [08-mediator.md](08-mediator.md), repozytorium w [07-repozytorium.md](07-repozytorium.md). Zapytanie, które czyta skutek komendy, jest w [11-zapytanie.md](11-zapytanie.md).

## Po co

W eShop `CreateOrderCommandHandler` woła agregat i repozytorium, a reszta (log, walidacja, transakcja) dzieje się w zachowaniach. U nas tak samo. Handler czyta się jak przepis: zbuduj tytuł, utwórz artykuł, zapisz.

Rewizja pokazuje optymistyczną współbieżność od klienta do bazy. Klient wysyła wersję, którą widział (`ExpectedVersion`). Jeśli ktoś w międzyczasie zapisał rewizję, handler zwraca `Conflict`, zanim cokolwiek dopisze. Ten sam `Conflict` przyjdzie z magazynu, gdy dwa żądania miną się o milisekundy.

## Dlaczego ta technologia

### Komenda jako `record` z typami prostymi

Komenda przychodzi z HTTP, więc niesie to, co przyszło: `string`, `Guid`, `int`. Gdyby niosła `ArticleTitle`, endpoint musiałby budować value objecty i decydować o błędach, czyli robić robotę handlera. `record` jest niezmienny, ma sensowny `ToString` w debugerze i porównuje się po wartości w testach. eShop ma tak samo: `CreateOrderCommand` z prostymi polami, a value objecty buduje handler.

### `ExpectedVersion` od klienta

Rewizja bez wersji od klienta to „ostatni zapis wygrywa”: dwie osoby edytują, druga po cichu nadpisuje pierwszą. Z wersją handler wie, który stan klient widział, i odrzuca zapis na nieaktualnej podstawie. Sprawdzenie w handlerze (przed `Revise`) daje szybką odpowiedź bez pracy agregatu. Sprawdzenie w magazynie (`AppendAsync` z oczekiwaną wersją) łapie wyścig dwóch żądań w tej samej milisekundzie. Potrzebne są oba, bo pierwsze nie chroni przed wyścigiem, a drugie nie wie o wersji widzianej przez klienta minutę wcześniej.

### FluentValidation przed agregatem

Walidator odrzuca żądanie, zanim handler wczyta strumień i otworzy transakcję. Dla `Revise` to oszczędność odczytu bazy przy oczywiście złym żądaniu (`ExpectedVersion = 0`). Reguła tytułu nie jest kopiowana do walidatora: `Must(title => ArticleTitle.Create(title)...)` pyta value object. Szczegóły wyboru biblioteki są w [08-mediator.md](08-mediator.md).

### Jednostka pracy na transakcji EF

`NewsUnitOfWork` opakowuje `Database.BeginTransactionAsync`. Alternatywa `TransactionScope` (transakcja ambientowa .NET) działa z Npgsql, ale łatwo ją niechcący rozszerzyć do transakcji rozproszonej i źle współpracuje z `async` bez `TransactionScopeAsyncFlowOption`. Jawna transakcja EF jest widoczna w kodzie i w śladach OpenTelemetry. eShop robi to tak samo w `OrderingContext.BeginTransactionAsync`.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/News/News.Application/News.Application.csproj` | referencje: `News.Domain`, `JJDevHub.Cqrs` (z nim FluentValidation), `JJDevHub.EventStore` |
| `src/services/News/News.Application/Articles/ArticleWritten.cs` | odpowiedź: `ArticleId`, `Version` |
| `src/services/News/News.Application/Articles/CreateArticleCommand.cs` | `Title`, `Body`, `AuthorIdentityGuid` |
| `src/services/News/News.Application/Articles/CreateArticleCommandValidator.cs` | tytuł przez `ArticleTitle.Create` |
| `src/services/News/News.Application/Articles/CreateArticleCommandHandler.cs` | agregat i `SaveAsync` |
| `src/services/News/News.Application/Articles/ReviseArticleCommand.cs` | `ArticleId`, `ExpectedVersion`, `Title`, `Body`, `EditorIdentityGuid` |
| `src/services/News/News.Application/Articles/ReviseArticleCommandValidator.cs` | tytuł, wersja co najmniej 1 |
| `src/services/News/News.Application/Articles/ReviseArticleCommandHandler.cs` | `GetAsync`, wersja, `Revise`, `SaveAsync` |
| `src/services/News/News.Application/NewsApplicationServiceCollectionExtensions.cs` | `AddNewsApplication()` |
| `src/services/News/News.Infrastructure/Persistence/NewsUnitOfWork.cs` | `IUnitOfWork` na `NewsWriteContext` |
| `src/services/News/News.Infrastructure/NewsWriteServiceCollectionExtensions.cs` | `AddNewsWrite(connectionString)` |
| `tests/News.Application.Tests/` | handlery na `InMemoryEventStore` |
| `tests/News.Infrastructure.Tests/ArticleCommandTests.cs` | komenda przez mediator na Postgresie |

## Plan

### 1. Projekty

```bash
dotnet new classlib -n News.Application -o src/services/News/News.Application -f net11.0
dotnet new xunit -n News.Application.Tests -o tests/News.Application.Tests -f net11.0
dotnet sln add src/services/News/News.Application tests/News.Application.Tests
dotnet add src/services/News/News.Application reference src/services/News/News.Domain src/building-blocks/JJDevHub.Cqrs src/building-blocks/JJDevHub.EventStore
dotnet add src/services/News/News.Infrastructure reference src/services/News/News.Application
dotnet add tests/News.Application.Tests reference src/services/News/News.Application
```

`News.Application` nie referencjonuje EF ani `News.Infrastructure`. Strzałka idzie z Infrastructure do Application, nie odwrotnie.

### 2. Komendy

```csharp
namespace JJDevHub.News.Application.Articles;

public sealed record ArticleWritten(Guid ArticleId, int Version);
```

```csharp
public sealed record CreateArticleCommand(string Title, string Body, string? AuthorIdentityGuid)
    : ICommand<ArticleWritten>;
```

```csharp
public sealed record ReviseArticleCommand(
    Guid ArticleId, int ExpectedVersion, string Title, string Body, string? EditorIdentityGuid)
    : ICommand<ArticleWritten>;
```

Do [16-usluga-news.md](16-usluga-news.md) `AuthorIdentityGuid` i `EditorIdentityGuid` są `null`. Endpoint wypełni je z tokenu.

### 3. Walidatory

```csharp
namespace JJDevHub.News.Application.Articles;

public sealed class CreateArticleCommandValidator : AbstractValidator<CreateArticleCommand>
{
    public CreateArticleCommandValidator()
    {
        RuleFor(c => c.Title)
            .Must(title => ArticleTitle.Create(title).Error == ResultError.None)
            .WithErrorCode("article.title");
        RuleFor(c => c.Body).NotNull();
    }
}
```

Reguła tytułu nie jest skopiowana: walidator pyta value object. Długość treści sprawdza reguła agregatu `ArticleBodyMustFitLimitRule` z [03-agregat.md](03-agregat.md), więc walidator jej nie powtarza.

`ReviseArticleCommandValidator : AbstractValidator<ReviseArticleCommand>` ma tę samą regułę tytułu oraz `RuleFor(c => c.ArticleId).NotEmpty()` i `RuleFor(c => c.ExpectedVersion).GreaterThanOrEqualTo(1)`.

### 4. Handler tworzenia

`CreateArticleCommandHandler(IRepository<Article> articles, TimeProvider time)`:

```csharp
public async Task<Result<ArticleWritten>> Handle(CreateArticleCommand command, CancellationToken cancellationToken)
{
    var title = ArticleTitle.Create(command.Title);
    if (!title.TryGetValue(out var validTitle))
    {
        return Result<ArticleWritten>.Fail(title.Error);
    }

    var created = Article.Create(validTitle, command.Body, command.AuthorIdentityGuid, time);
    if (!created.TryGetValue(out var article))
    {
        return Result<ArticleWritten>.Fail(created.Error);
    }

    var saved = await articles.SaveAsync(article, cancellationToken);
    if (!saved.TryGetValue(out var version))
    {
        return Result<ArticleWritten>.Fail(saved.Error);
    }

    return Result<ArticleWritten>.Ok(new ArticleWritten(article.Id, version));
}
```

`TryGetValue` z [02-value-object.md](02-value-object.md) zastępuje `Value!`, którego reguła [.cursor/rules/csharp.mdc](../../.cursor/rules/csharp.mdc) zakazuje. Każdy krok ma jeden poziom wcięcia i wczesny `return`.

### 5. Handler rewizji

`ReviseArticleCommandHandler(IRepository<Article> articles, TimeProvider time)`:

- `GetAsync(command.ArticleId)` → `NotFound` wraca od razu,
- `article.Version != command.ExpectedVersion` → `Conflict`,
- `ArticleTitle.Create` → błąd wraca,
- `article.Revise(title, body, command.EditorIdentityGuid, time)` → `Forbidden` albo `Invalid` wraca,
- `SaveAsync` → `Ok(new ArticleWritten(article.Id, version))`.

Rewizja bez zmian treści nie dopisuje faktu. `SaveAsync` zwraca wtedy obecną wersję, a odpowiedź ma tę samą `Version`.

### 6. Jednostka pracy

`NewsUnitOfWork(NewsWriteContext context) : IUnitOfWork`:

- `HasActiveTransaction` → `context.Database.CurrentTransaction is not null`,
- `BeginAsync` → `context.Database.BeginTransactionAsync`,
- `CommitAsync` i `RollbackAsync` → na `CurrentTransaction`.

`PostgresEventStore` z [06-postgres.md](06-postgres.md) widzi otwartą transakcję i w niej uczestniczy. Advisory lock trwa do commitu komendy.

### 7. Skład

```csharp
public static IServiceCollection AddNewsApplication(this IServiceCollection services) =>
    services.AddCqrs(typeof(CreateArticleCommand).Assembly);
```

`AddNewsWrite(this IServiceCollection services, string connectionString)` w `News.Infrastructure` rejestruje:

- `AddDbContext<NewsWriteContext>(o => o.UseNpgsql(connectionString))`,
- `EventTypeRegistry.FromAssemblies(typeof(IDomainEvent), typeof(Article).Assembly)` jako singleton,
- `IEventSerializer` → `JsonEventSerializer`,
- `AddPostgresEventStore<NewsWriteContext>()`,
- `IRepository<>` → `Repository<>`, `IStreamNaming<Article>` → `ArticleStreamNaming`,
- `IUnitOfWork` → `NewsUnitOfWork`,
- `TimeProvider.System` przez `TryAddSingleton`.

### Co jest do czego

- `CreateArticleCommand` — intencja „chcę nowy artykuł”. Niesie dane z HTTP, nie value objecty.
- `ReviseArticleCommand` — intencja „zmieniam artykuł, który widziałem w wersji N”.
- `ArticleWritten` — odpowiedź zapisu. Id dla `Location`, wersja dla nagłówka `ETag` w [16-usluga-news.md](16-usluga-news.md).
- Walidatory — szybkie `400` bez ładowania strumienia. Pytają value objecty, więc reguła jest w jednym miejscu.
- Handlery — przepis przypadku użycia. Nie znają EF, HTTP ani bazy odczytu.
- `NewsUnitOfWork` — transakcja na `NewsWriteContext`. Otwiera ją `TransactionBehavior`, a od [12-outbox-inbox.md](12-outbox-inbox.md) obejmuje też outbox.
- `AddNewsApplication` / `AddNewsWrite` — dwa wejścia składu. `News.API` z [16-usluga-news.md](16-usluga-news.md) woła oba.

## Testy

Projekt `tests/News.Application.Tests`. Kontener z `AddNewsApplication()`, `InMemoryEventStore`, prawdziwym `Repository<Article>`, testowym `TestArticleStreamNaming` i `FixedTimeProvider`. Bez bazy i bez referencji do `News.Infrastructure`.

Klasa `CreateArticleCommandTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Send_returns_version_one` | tytuł `Nowy wpis` | `Send` | `Version` równe 1 |
| `Send_blank_title_returns_invalid` | tytuł `"  "` | `Send` | `Invalid` |
| `Send_blank_title_appends_nothing` | tytuł `"  "` | `Send`, potem `ReadAllAsync(0, 10)` | pusta lista |
| `Send_stores_author` | autor `a` | `Send`, potem `GetAsync` | `AuthorIdentityGuid` równe `a` |

Klasa `ReviseArticleCommandTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Revise_returns_version_two` | artykuł w wersji 1 | `Send` z `ExpectedVersion` 1 | `Version` 2 |
| `Revise_stale_version_returns_conflict` | artykuł w wersji 2 | `Send` z `ExpectedVersion` 1 | `Conflict` |
| `Revise_unknown_article_returns_not_found` | pusty magazyn | `Send` | `NotFound` |
| `Revise_by_other_user_returns_forbidden` | artykuł autora `a` | `Send` z edytorem `b` | `Forbidden` |
| `Revise_zero_version_returns_invalid` | dowolny artykuł | `Send` z `ExpectedVersion` 0 | `Invalid` |

Klasa `ArticleCommandTests` w `tests/News.Infrastructure.Tests`. Kontener Postgresa, `AddNewsApplication()`, `AddNewsWrite(connectionString)`, `AddLogging()`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Send_persists_article_stream` | tytuł `Nowy wpis` | `Send` | wiersz `EventStreams` `article-{id}` w wersji 1 |
| `Send_commits_transaction` | tytuł `Nowy wpis` | `Send`, odczyt nowym kontekstem | jeden `EventRecord` |
| `Parallel_revisions_one_conflicts` | artykuł w wersji 1 | dwa `Send` rewizji z wersją 1 w osobnych scope'ach | jeden `Conflict` |

`dotnet test tests/News.Application.Tests` i `dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- Handler zna `IRepository<Article>`, `TimeProvider` i domenę. Nie zna `NewsWriteContext`, `NewsReadContext` ani HTTP.
- Wersja z klienta jest sprawdzana przed `Revise`. Konflikt nie dopisuje faktu.
- Walidator nie duplikuje reguł value objectu.
- `News.Application` nie referencjonuje EF.
- Wyjątek z bazy przechodzi przez mediator. Oczekiwane błędy to `Result<T>`.

## Poza zakresem

- Zdarzenie integracyjne po zapisie — [12-outbox-inbox.md](12-outbox-inbox.md). Handler tworzenia dostanie tam jedną linię.
- Endpointy i mapowanie `ResultError` na HTTP — [16-usluga-news.md](16-usluga-news.md).
- Widok `ArticleSummary` — [10-projekcja.md](10-projekcja.md).

## Źródła

- [Implement the application layer using the Web API](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-implementation-web-api) — komenda, handler, transakcja w eShop.
- [Apply simplified CQRS and DDD patterns](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/apply-simplified-microservice-cqrs-ddd-patterns) — strona zapisu przez agregat i repozytorium.
- [Domain model validations](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/domain-model-layer-validations) — walidacja na wejściu i niezmiennik w domenie.
- [FluentValidation: custom validators](https://docs.fluentvalidation.net/en/latest/custom-validators.html) — `Must` pytający value object.
- [Optimistic Offline Lock](https://martinfowler.com/eaaCatalog/optimisticOfflineLock.html) — wersja widziana przez klienta.
- [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) — handlery komend w Application, repozytorium event sourcingu w Infrastructure.
- [Komenda wołająca komendę](https://cezarywalenciuk.pl/blog/programing/command-wywolujacy-kolejny-command-to-kiepski-pomysl) — handler nie woła drugiej komendy.

## Gotowe gdy

- `Send(new CreateArticleCommand("Nowy wpis", "cześć", null))` zapisuje strumień `article-{id}` w `news_write` i zwraca wersję 1.
- Pusty tytuł zwraca `Invalid`, a magazyn nie dostaje wywołania.
- Rewizja ze starą wersją zwraca `Conflict`, a obca rewizja `Forbidden`.
- `News.Application` nie ma referencji do EF ani `News.Infrastructure`.
- `dotnet test tests/News.Application.Tests` i `dotnet test tests/News.Infrastructure.Tests` kończą się kodem 0.
