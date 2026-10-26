# Mediator

Mediator przyjmuje komendę albo zapytanie, przepuszcza je przez łańcuch zachowań i woła jeden handler. Biblioteka `JJDevHub.Cqrs` daje kontrakty, `Mediator` i trzy zachowania: logowanie, walidację (FluentValidation) i transakcję. Repozytorium, które handlery wołają, jest w [07-repozytorium.md](07-repozytorium.md). Pierwsze handlery usługi są w [09-komenda.md](09-komenda.md).

## Po co

W eShop Ordering każda komenda przechodzi przez `LoggingBehavior`, `ValidatorBehavior` i `TransactionBehavior`. Handler zawiera tylko logikę przypadku użycia. Log, walidacja i otwarcie transakcji nie powtarzają się w każdym handlerze. eShop używa do tego MediatR i FluentValidation.

Wcześniejsza wersja tej specyfikacji miała jeden zaszyty krok walidacji i delegata `Func<Type, object?>` zamiast `IServiceProvider`. Łańcuch zachowań jest ogólniejszy, a abstrakcje DI to mały pakiet bez implementacji kontenera.

## Dlaczego ta technologia

### Mediator zamiast wołania handlera wprost

Endpoint mógłby dostać `CreateArticleCommandHandler` z DI i zawołać `Handle`. Działa, dopóki nie trzeba dodać logu, walidacji i transakcji. Wtedy każdy handler zaczyna od tych samych dwudziestu linii albo endpoint robi to sam. Mediator daje jedno miejsce, przez które przechodzi każde żądanie, i to miejsce można owinąć zachowaniami. Handler zostaje czystym przypadkiem użycia, który da się przetestować bez HTTP. To ten sam pomysł co middleware w ASP.NET Core, tylko na poziomie warstwy Application.

Koszt: o jeden poziom pośredniości więcej. „Go to definition” na `Send` nie prowadzi do handlera. Nazwy plików (`CreateArticleCommand` → `CreateArticleCommandHandler`) to rekompensują.

### Własny mediator zamiast MediatR

MediatR od wersji `13` ma licencję podwójną: RPL 1.5 (copyleft, który obejmuje także kod używający biblioteki) albo komercyjną. Darmowa edycja Community wymaga rejestracji klucza i progu przychodu firmy poniżej 5 mln USD. Wersja `12.5` zostaje na Apache 2.0, ale nie dostaje rozwoju ani poprawek. Przypinanie zamrożonej wersji w nowym projekcie na .NET 11 to dług od pierwszego dnia.

Darmowe alternatywy istnieją. [Mediator](https://github.com/martinothamar/Mediator) (MIT) generuje kod źródłowy zamiast refleksji i jest szybszy od MediatR. Wolverine (MIT) jest pełną szyną z mediatorem w środku. Pierwszy byłby rozsądnym wyborem w projekcie produkcyjnym. Tu przegrywa, bo celem ciągu jest zrozumienie mechanizmu: własny mediator to około stu linii, które pokazują rozwiązywanie typów generycznych z DI, cache wrapperów i składanie łańcucha. Interfejsy mają nazwy jak w MediatR (`IRequest`, `IPipelineBehavior`, `RequestHandlerDelegate`), więc zamiana na bibliotekę później to głównie zmiana `using`.

Wolverine przegrywa także dlatego, że przejmuje więcej niż mediator: transport, outbox, konwencje nazw handlerów. W ciągu te części są osobnymi numerami.

### FluentValidation zamiast własnego interfejsu walidatora

FluentValidation (Apache 2.0) to standard walidacji w .NET: reguły jako wyrażenia (`RuleFor(c => c.Title).NotEmpty()`), komunikaty z nazwą pola, walidatory złożone i asynchroniczne. eShop używa go w `ValidatorBehavior`. Własny `IValidator<T>` z jedną metodą `ResultError Validate(T)` byłby prostszy, ale gubi informację, które pole jest złe, a każdy walidator piszemy ręcznie `if` po `if`. FluentValidation daje to za darmo i bez zależności tranzytywnych.

Walidator nie zastępuje value objectu. Reguła tytułu żyje w `ArticleTitle.Create`, a walidator ją woła (`Must`). FluentValidation jest szybką bramką na wejściu, która odrzuca śmieci przed transakcją. Ostateczną bramką zostaje domena.

Data Annotations (`[Required]`, `[MaxLength]`) przegrywają, bo wiążą reguły z rekordem komendy atrybutami i nie umieją zapytać value objectu.

### Zachowania jako open generics w DI

`IPipelineBehavior<,>` rejestrowane jako open generic oznacza, że kontener sam zamyka typ dla każdej komendy. Nowa komenda nie wymaga rejestracji zachowań. Kolejność rejestracji to kolejność owijania, a to jest jawne w jednym miejscu (`AddCqrs`). Dekoratory (Scrutor) dałyby to samo, ale to kolejna biblioteka do jednego wywołania. Koszt: zła kolejność w `AddCqrs` zmienia wynik i nie pada kompilacją.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Cqrs/JJDevHub.Cqrs.csproj` | Domain + `Microsoft.Extensions.DependencyInjection.Abstractions` + `Microsoft.Extensions.Logging.Abstractions` + `FluentValidation` + `FluentValidation.DependencyInjectionExtensions` |
| `src/building-blocks/JJDevHub.Cqrs/IRequest.cs` | wspólny znacznik `IRequest<TResponse>` |
| `src/building-blocks/JJDevHub.Cqrs/ICommand.cs` | `ICommand<TResponse> : IRequest<TResponse>` |
| `src/building-blocks/JJDevHub.Cqrs/IQuery.cs` | `IQuery<TResponse> : IRequest<TResponse>` |
| `src/building-blocks/JJDevHub.Cqrs/IRequestHandler.cs` | `Handle` |
| `src/building-blocks/JJDevHub.Cqrs/ICommandHandler.cs`, `IQueryHandler.cs` | nazwane aliasy handlera |
| `src/building-blocks/JJDevHub.Cqrs/RequestHandlerDelegate.cs` | „następny krok” łańcucha |
| `src/building-blocks/JJDevHub.Cqrs/IPipelineBehavior.cs` | zachowanie wokół handlera |
| `src/building-blocks/JJDevHub.Cqrs/IMediator.cs`, `Mediator.cs` | `Send` |
| `src/building-blocks/JJDevHub.Cqrs/RequestHandlerWrapper.cs` | typowany pośrednik, cache per typ żądania |
| `src/building-blocks/JJDevHub.Cqrs/IUnitOfWork.cs` | `HasActiveTransaction`, `BeginAsync`, `CommitAsync`, `RollbackAsync` |
| `src/building-blocks/JJDevHub.Cqrs/Behaviors/LoggingBehavior.cs` | nazwa żądania, czas, wynik |
| `src/building-blocks/JJDevHub.Cqrs/Behaviors/ValidatorBehavior.cs` | walidatory FluentValidation, porażka → `Invalid` |
| `src/building-blocks/JJDevHub.Cqrs/Behaviors/TransactionBehavior.cs` | transakcja dla komend |
| `src/building-blocks/JJDevHub.Cqrs/CqrsServiceCollectionExtensions.cs` | `AddCqrs(assemblies)` |
| `tests/JJDevHub.Cqrs.Tests/` | łańcuch na fałszywych handlerach |

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.Cqrs -o src/building-blocks/JJDevHub.Cqrs -f net11.0
dotnet new xunit -n JJDevHub.Cqrs.Tests -o tests/JJDevHub.Cqrs.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.Cqrs tests/JJDevHub.Cqrs.Tests
dotnet add src/building-blocks/JJDevHub.Cqrs reference src/building-blocks/JJDevHub.Domain
dotnet add src/building-blocks/JJDevHub.Cqrs package Microsoft.Extensions.DependencyInjection.Abstractions
dotnet add src/building-blocks/JJDevHub.Cqrs package Microsoft.Extensions.Logging.Abstractions
dotnet add src/building-blocks/JJDevHub.Cqrs package FluentValidation
dotnet add src/building-blocks/JJDevHub.Cqrs package FluentValidation.DependencyInjectionExtensions
dotnet add tests/JJDevHub.Cqrs.Tests reference src/building-blocks/JJDevHub.Cqrs
```

Wersje dochodzą do [Directory.Packages.props](../../Directory.Packages.props): abstrakcje w linii platformy `11.0.0-*`, FluentValidation w najnowszej stabilnej `12.x`. Testy dostają `Microsoft.Extensions.DependencyInjection`, żeby zbudować prawdziwy kontener.

### 2. Kontrakty

```csharp
namespace JJDevHub.Cqrs;

public interface IRequest<TResponse>;

public interface ICommand<TResponse> : IRequest<TResponse>;

public interface IQuery<TResponse> : IRequest<TResponse>;
```

Każdy interfejs ma własny plik. Handler:

```csharp
namespace JJDevHub.Cqrs;

public interface IRequestHandler<in TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    Task<Result<TResponse>> Handle(TRequest request, CancellationToken cancellationToken);
}
```

`ICommandHandler<TCommand, TResponse>` i `IQueryHandler<TQuery, TResponse>` dziedziczą `IRequestHandler` z ograniczeniem na `ICommand` albo `IQuery`. Kontener rozwiązuje zawsze `IRequestHandler<,>`. Nazwane interfejsy są dla czytelnika.

### 3. Łańcuch

```csharp
namespace JJDevHub.Cqrs;

public delegate Task<Result<TResponse>> RequestHandlerDelegate<TResponse>();

public interface IPipelineBehavior<in TRequest, TResponse>
    where TRequest : IRequest<TResponse>
{
    Task<Result<TResponse>> Handle(
        TRequest request, RequestHandlerDelegate<TResponse> next, CancellationToken cancellationToken);
}
```

Zachowanie robi coś przed `next()`, woła `next()` albo zwraca wynik bez niego (walidacja), i robi coś po.

### 4. Mediator

```csharp
public interface IMediator
{
    Task<Result<TResponse>> Send<TResponse>(IRequest<TResponse> request, CancellationToken cancellationToken);
}
```

`Mediator(IServiceProvider services)` jest `sealed`. W `Send` znany jest tylko `TResponse`, a typ żądania dopiero w czasie wykonania. Dlatego:

- `RequestHandlerWrapper<TResponse>` jest abstrakcyjną bazą z metodą `Handle(IRequest<TResponse>, IServiceProvider, CancellationToken)`,
- `RequestHandlerWrapper<TRequest, TResponse>` ją implementuje: rzutuje żądanie, bierze `IRequestHandler<TRequest, TResponse>` przez `GetService`, zbiera `GetServices<IPipelineBehavior<TRequest, TResponse>>()` i składa łańcuch od końca,
- `Mediator` trzyma statyczny `ConcurrentDictionary<Type, object>` z wrapperem na typ żądania; refleksja (`MakeGenericType`, `Activator.CreateInstance`) idzie raz na typ.

Brak handlera → `InvalidOperationException` z nazwą typu żądania. To błąd składu aplikacji, nie błąd danych.

Kolejność: zachowanie zarejestrowane pierwsze jest najbardziej zewnętrzne. `AddCqrs` rejestruje `LoggingBehavior`, `ValidatorBehavior`, `TransactionBehavior`. Log widzi więc także odrzucenie walidacji, a transakcja nie otwiera się dla niepoprawnego żądania.

### 5. Zachowania

- `LoggingBehavior<TRequest, TResponse>` — `ILogger` z primary constructora. Loguje `Handling {RequestName}` przed i `Handled {RequestName} in {ElapsedMs} ms with {Error}` po. Pola żądania nie trafiają do logu, bo mogą zawierać dane osobowe.
- `ValidatorBehavior<TRequest, TResponse>` — `IEnumerable<FluentValidation.IValidator<TRequest>>`. Woła `ValidateAsync` każdego walidatora z tokenem. Gdy którykolwiek wynik ma `IsValid == false`, loguje na poziomie `Debug` nazwy pól z błędami (`PropertyName`, `ErrorCode`, bez wartości) i zwraca `Result<TResponse>.Fail(ResultError.Invalid)` bez `next()`. Brak walidatorów oznacza od razu `next()`. Wyjątek `ValidationException` nie jest używany: niepoprawne żądanie to oczekiwany błąd.
- `TransactionBehavior<TRequest, TResponse>` — `IUnitOfWork?` (opcjonalny, `GetService`). Kroki:
  - żądanie nie jest `ICommand<TResponse>` albo brak `IUnitOfWork` → `next()`,
  - `HasActiveTransaction` → `next()` (komenda w komendzie nie otwiera drugiej),
  - `BeginAsync`, `next()`, sukces → `CommitAsync`, porażka → `RollbackAsync`,
  - wyjątek → `RollbackAsync` w `finally`, gdy commit nie nastąpił; wyjątek leci dalej.

```csharp
namespace JJDevHub.Cqrs;

public interface IUnitOfWork
{
    bool HasActiveTransaction { get; }

    Task BeginAsync(CancellationToken cancellationToken);

    Task CommitAsync(CancellationToken cancellationToken);

    Task RollbackAsync(CancellationToken cancellationToken);
}
```

Implementację `IUnitOfWork` na EF dostaje usługa w [09-komenda.md](09-komenda.md).

### 6. Rejestracja

```csharp
services.AddCqrs(typeof(CreateArticleCommand).Assembly);
```

`AddCqrs` skanuje zestawy i rejestruje jako scoped:

- każdą zamkniętą implementację `IRequestHandler<,>`,
- walidatory przez `AddValidatorsFromAssemblies(assemblies, ServiceLifetime.Scoped)` z FluentValidation,
- `IMediator` → `Mediator`,
- trzy zachowania jako open generic `IPipelineBehavior<,>`, w kolejności z kroku 4.

### Co jest do czego

- `IRequest<TResponse>` — wspólny typ, dzięki któremu `Send` ma jedną sygnaturę dla komend i zapytań.
- `ICommand` / `IQuery` — znaczniki intencji. `TransactionBehavior` patrzy na nie, żeby zapytanie nie otwierało transakcji.
- `IRequestHandler` — jeden przypadek użycia. Wołany wyłącznie przez mediator.
- `IPipelineBehavior` — miejsce na sprawy przekrojowe. Kolejne (metryki, cache zapytań) dochodzą bez zmiany handlerów.
- `RequestHandlerWrapper` — most między „znam tylko `TResponse`” a „potrzebuję `TRequest`”. Chowa refleksję w jednym miejscu.
- `AbstractValidator<T>` (FluentValidation) — szybka bramka na wejściu. Agregat i value objecty zostają drugą, ostateczną bramką.
- `IUnitOfWork` — abstrakcja transakcji. Dzięki niej zdarzenia i outbox z [12-outbox-inbox.md](12-outbox-inbox.md) zapiszą się razem albo wcale.

## Testy

Projekt `tests/JJDevHub.Cqrs.Tests`. Kontener z `ServiceCollection`. Żądania, handlery i walidatory testowe w plikach testu. Kolejność wywołań zapisuje wspólna lista `List<string>` zarejestrowana jako singleton.

Klasa `MediatorTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Send_reaches_handler` | handler zwracający `Ok(42)` | `Send` | `Value` 42 |
| `Send_without_handler_throws` | brak rejestracji | `Send` | `InvalidOperationException` |
| `Behaviors_wrap_in_registration_order` | dwa zachowania zapisujące `a>`, `b>`, `<b`, `<a` | `Send` | lista `a>`, `b>`, `handler`, `<b`, `<a` |
| `Send_passes_cancellation_token` | handler zapisujący token | `Send` z tokenem | ten sam token |

Klasa `ValidatorBehaviorTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Invalid_request_skips_handler` | `AbstractValidator` z `RuleFor(r => r.Name).NotEmpty()`, pusta nazwa | `Send` | `Invalid`, handler nie wywołany |
| `Valid_request_reaches_handler` | ten sam walidator, niepusta nazwa | `Send` | handler wywołany |
| `Validator_receives_cancellation_token` | walidator z `MustAsync` zapisującym token | `Send` z tokenem | ten sam token |

Klasa `TransactionBehaviorTests`. `FakeUnitOfWork` zapisuje wywołania.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Successful_command_commits` | komenda z `Ok` | `Send` | `Begin`, `Commit` |
| `Failed_command_rolls_back` | komenda z `Conflict` | `Send` | `Begin`, `Rollback` |
| `Throwing_command_rolls_back` | handler rzuca | `Send` | wyjątek i `Rollback` |
| `Query_skips_transaction` | zapytanie | `Send` | brak `Begin` |
| `Active_transaction_is_reused` | `HasActiveTransaction` równe `true` | `Send` komendy | brak `Begin` |

`dotnet test tests/JJDevHub.Cqrs.Tests`.

## Zasady

- Komenda: czasownik + rzeczownik + `Command`. Zapytanie: `Get…Query`. Handler: nazwa żądania + `Handler`.
- Handler ma jedną metodę `Handle` i zwraca `Result<T>`.
- Mediator nie łapie wyjątków handlera. Logowanie wyjątku zostaje dla hosta.
- `JJDevHub.Cqrs` nie referencjonuje EF ani MediatR.
- Zapytanie nigdy nie otwiera transakcji zapisu.

## Poza zakresem

- Implementacja `IUnitOfWork` na EF — [09-komenda.md](09-komenda.md).
- Powiadomienia in-process (`INotification`). Zdarzenia między częściami systemu idą przez outbox — [12-outbox-inbox.md](12-outbox-inbox.md).
- Cache zapytań.

## Źródła

- [Implement the command and command handler patterns](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-implementation-web-api#implement-the-command-and-command-handler-patterns) — komenda, handler i mediator w eShop.
- [Apply cross-cutting concerns with behaviors](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/microservice-ddd-cqrs-patterns/microservice-application-layer-implementation-web-api#apply-cross-cutting-concerns-when-processing-commands-with-the-behaviors-in-mediatr) — `LoggingBehavior`, `ValidatorBehavior`, `TransactionBehavior`.
- [dotnet/eShop — Ordering.API/Application/Behaviors](https://github.com/dotnet/eShop/tree/main/src/Ordering.API/Application/Behaviors) — kod tych trzech zachowań.
- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs) — komenda zmienia stan, zapytanie go czyta.
- [FluentValidation](https://docs.fluentvalidation.net/en/latest/) — reguły, `AbstractValidator<T>`, rejestracja w DI.
- [MediatR: licencja](https://mediatr.io/) — dlaczego wersji `13+` nie bierzemy.
- [martinothamar/Mediator](https://github.com/martinothamar/Mediator) — darmowa alternatywa na generatorze źródeł.
- [Dependency injection: open generics](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection#service-registration-methods) — rejestracja `IPipelineBehavior<,>`.
- [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) — komendy i zapytania w warstwie Application.

## Gotowe gdy

- `Send` znajduje handler, przepuszcza żądanie przez zachowania w kolejności rejestracji i zwraca `Result<T>`.
- Niepoprawne żądanie nie dochodzi do handlera ani do transakcji.
- Komenda z porażką kończy się `RollbackAsync`, zapytanie nie otwiera transakcji.
- `JJDevHub.Cqrs` nie ma referencji do EF ani MediatR.
- `dotnet test tests/JJDevHub.Cqrs.Tests` kończy się kodem 0.
