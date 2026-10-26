# Projekcja

Projekcja buduje widok pod odczyt ze strumienia zdarzeń. Biblioteka `JJDevHub.Projections` daje `ReadContext` z tabelą `Checkpoints`, kontrakt `IProjection`, `ProjectionRunner` (jedno przejście) i `ProjectionWorker` (pętla w tle). Usługa News dostaje bazę `news_read`, kontekst `NewsReadContext` i `ArticleSummaryProjection`. Strumień i `ReadAllAsync` są w [04-strumien.md](04-strumien.md) i [06-postgres.md](06-postgres.md). Zapytanie, które widok czyta, jest w [11-zapytanie.md](11-zapytanie.md).

## Po co

CQRS rozdziela model zapisu od modelu odczytu, żeby każdy dało się ustawić pod swój ruch. Strumień jest świetny do zapisu i fatalny do listy „ostatnie artykuły”. Widok `ArticleSummaries` to gotowy wiersz pod ekran.

Wcześniejsza wersja tej specyfikacji wołała projekcję synchronicznie po `SaveAsync`, z checkpointem na każdy strumień. Miało to dwie wady. Awaria po commicie zapisu zostawiała widok w tyle, a nikt nie ponawiał. Do tego worker nie miał jak dowiedzieć się o nowych strumieniach bez listy id. Teraz worker w tle czyta wszystkie zdarzenia po `Position` i pamięta jedną liczbę na projekcję. Awaria oznacza tylko, że następne przejście zacznie od tego samego miejsca.

## Dlaczego ta technologia

### Osobna baza odczytu

Widok mógłby leżeć w tej samej bazie co strumień, w drugiej tabeli. Działałoby i byłoby prostsze. Osobna baza `news_read` wymusza dyscyplinę: handler komendy fizycznie nie może czytać widoku, a zapytanie nie może zajrzeć do strumienia. Widok da się też w każdej chwili skasować i odbudować od zera (`DROP DATABASE`, checkpoint 0), bez dotykania danych źródłowych. Koszt to druga baza, druga migracja i drugi connection string. Na jednym serwerze Postgres to tylko nazwa, nie osobny proces.

### Projekcja asynchroniczna w tle zamiast w transakcji zapisu

Projekcja w tej samej transakcji co zapis (inline) daje widok spójny natychmiast. Ale wtedy każdy nowy widok spowalnia każdy zapis, błąd w projekcji wywraca zapis artykułu, a odbudowa widoku od zera wymaga osobnego kodu. Projekcja w tle jest ostatecznie spójna (widok spóźnia się o ułamek sekundy), za to zapis jest niezależny od widoków, a odbudowa to ten sam kod od checkpointu 0. Marten oferuje oba tryby i zaleca asynchroniczny dla widoków przekrojowych. Spóźnienie widoku opisuje [architektura.md](architektura.md): klient po `201` ponawia odczyt.

### Checkpoint na projekcję po globalnej `Position`

Checkpoint per strumień wymagał listy wszystkich strumieni, a nowy artykuł nie był widoczny dla workera. Jedna liczba na projekcję („przetworzyłam wszystko do pozycji 1500”) wystarcza, bo `Position` rośnie w kolejności commitów (advisory lock z [06-postgres.md](06-postgres.md)). Nowa projekcja zaczyna od 0 i dogania historię sama.

### Odpytywanie (polling) zamiast powiadomień

Worker co chwilę pyta „czy jest coś po mojej pozycji”. Alternatywy:

- `LISTEN/NOTIFY` w Postgresie — natychmiastowe, ale powiadomienie ginie, gdy worker jest wyłączony, więc i tak potrzebny jest polling jako zapas,
- Kafka między zapisem a projekcją — projekcja byłaby konsumentem tematu, ale wtedy outbox musiałby publikować zdarzenia domenowe na zewnątrz, a to łamie granicę „zdarzenie domenowe nie opuszcza usługi”,
- logiczna replikacja Postgresa (CDC, Debezium) — potężna i ciężka na jedną VM.

Polling z krótkim interwałem i pobieraniem paczkami jest prosty, odporny na restart i wystarczający przy ruchu bloga. `BackgroundService` z `Microsoft.Extensions.Hosting` jest standardowym hostem pętli w .NET.

### Idempotentny upsert

Widok i checkpoint zapisują się jednym `SaveChangesAsync`, więc awaria w środku paczki niczego nie zostawia w połowie. To samo zdarzenie może jednak trafić do projekcji drugi raz: dwie repliki usługi uruchomią dwa workery, a ręczne cofnięcie checkpointu przepuści historię ponownie. Dlatego projekcja zapisuje widok tylko wtedy, gdy wersja zdarzenia jest wyższa niż wersja w wierszu. Drugie przetworzenie niczego nie zmienia. Idempotencja jest zasadą, nie optymalizacją.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Projections/JJDevHub.Projections.csproj` | EventStore, `Npgsql.EntityFrameworkCore.PostgreSQL`, `Microsoft.Extensions.Hosting.Abstractions` |
| `src/building-blocks/JJDevHub.Projections/Checkpoint.cs` | `ProjectionName`, `Position` |
| `src/building-blocks/JJDevHub.Projections/ReadContext.cs` | abstrakcyjny kontekst z `Checkpoints` |
| `src/building-blocks/JJDevHub.Projections/IProjection.cs` | `Name`, `CanHandle`, `ProjectAsync` |
| `src/building-blocks/JJDevHub.Projections/ProjectionOptions.cs` | `BatchSize`, `IdleDelay` |
| `src/building-blocks/JJDevHub.Projections/ProjectionRunner.cs` | jedno przejście: paczka → widoki → checkpointy |
| `src/building-blocks/JJDevHub.Projections/ProjectionWorker.cs` | `BackgroundService` wokół runnera |
| `src/services/News/News.Infrastructure/Read/NewsReadContext.cs` | kontekst bazy `news_read` |
| `src/services/News/News.Infrastructure/Read/ArticleSummaryRow.cs` | wiersz widoku |
| `src/services/News/News.Infrastructure/Read/ArticleSummaryRowConfiguration.cs` | mapowanie tabeli `ArticleSummaries` |
| `src/services/News/News.Infrastructure/Read/ArticleSummaryProjection.cs` | upsert po zdarzeniach artykułu |
| `src/services/News/News.Infrastructure/Read/Migrations/` | `NewsReadInitial` |
| `src/services/News/News.Infrastructure/NewsReadServiceCollectionExtensions.cs` | `AddNewsRead(connectionString)` |
| `tests/News.Infrastructure.Tests/ArticleSummaryProjectionTests.cs` | dwie bazy w jednym kontenerze |

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.Projections -o src/building-blocks/JJDevHub.Projections -f net11.0
dotnet sln add src/building-blocks/JJDevHub.Projections
dotnet add src/building-blocks/JJDevHub.Projections reference src/building-blocks/JJDevHub.EventStore
dotnet add src/building-blocks/JJDevHub.Projections package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/building-blocks/JJDevHub.Projections package Microsoft.Extensions.Hosting.Abstractions
dotnet add src/services/News/News.Infrastructure reference src/building-blocks/JJDevHub.Projections
```

### 2. Checkpoint i kontekst

`Checkpoint` jest `sealed`: klucz `ProjectionName` (`string`), `Position` (`long`).

`ReadContext` jest abstrakcyjny. To wyjątek od reguły `sealed`: klasa bazowa kontekstu. Ma `DbSet<Checkpoint> Checkpoints` i w `OnModelCreating` mapuje tabelę `Checkpoints`. Kontekst usługi dziedziczy go i dokłada swoje tabele.

```csharp
namespace JJDevHub.News.Infrastructure.Read;

public sealed class NewsReadContext(DbContextOptions<NewsReadContext> options) : ReadContext(options)
{
    public DbSet<ArticleSummaryRow> ArticleSummaries => Set<ArticleSummaryRow>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        modelBuilder.ApplyConfiguration(new ArticleSummaryRowConfiguration());
    }
}
```

Konstruktor `ReadContext` przyjmuje niegeneryczne `DbContextOptions`, żeby typ pochodny mógł podać swoje `DbContextOptions<NewsReadContext>`.

### 3. Kontrakt projekcji

```csharp
namespace JJDevHub.Projections;

public interface IProjection
{
    string Name { get; }

    bool CanHandle(IDomainEvent domainEvent);

    Task ProjectAsync(StoredEvent storedEvent, CancellationToken cancellationToken);
}
```

Projekcja dostaje swój kontekst z DI (ten sam scoped obiekt co runner) i tylko zmienia encje. `SaveChangesAsync` woła runner, raz na paczkę, razem z checkpointami.

### 4. Runner

`ProjectionRunner<TContext> where TContext : ReadContext` dostaje `IEventStore`, `TContext`, `IEnumerable<IProjection>` i `IOptions<ProjectionOptions>`. `RunOnceAsync(CancellationToken)` zwraca liczbę przerobionych zdarzeń:

- checkpointy wszystkich projekcji; brak wiersza to pozycja 0,
- `ReadAllAsync(min(checkpoint), BatchSize)`; pusta paczka → 0,
- dla każdego zdarzenia i każdej projekcji z checkpointem mniejszym niż `Position` i z `CanHandle` → `ProjectAsync`,
- checkpoint każdej projekcji ustawiony na `Position` ostatniego zdarzenia paczki,
- jedno `SaveChangesAsync`: widoki i checkpointy razem albo wcale.

Checkpoint na projekcję pozwala przebudować jeden widok. Usuwasz jego wiersz w `Checkpoints` i czyścisz tabelę, a runner przejdzie strumień od początku tylko dla tej projekcji.

### 5. Worker

`ProjectionWorker<TContext> : BackgroundService` dostaje `IServiceScopeFactory`, `IOptions<ProjectionOptions>` i `ILogger`. Pętla do anulowania:

- nowy scope, `ProjectionRunner<TContext>` ze scope'a, `RunOnceAsync`,
- 0 przerobionych → `Task.Delay(IdleDelay, stoppingToken)`,
- `DbException` albo `DbUpdateException` → log `Warning`, opóźnienie, kolejne przejście.

Domyślnie `BatchSize` 100, `IdleDelay` 500 ms. Przy jednej instancji usługi to wystarcza. Dwie instancje workera pracowałyby na tych samych checkpointach. Kiedy usługa dostanie repliki, worker zrobi się osobnym procesem albo weźmie advisory lock na `news_read`. To jest poza tym numerem.

### 6. Widok artykułu

`ArticleSummaryRow` jest `sealed`: `ArticleId` (klucz), `Title`, `Body`, `AuthorIdentityGuid`, `CreatedOn`, `RevisedOn`, `Version`. Tabela `ArticleSummaries`, indeks na `CreatedOn` malejąco pod listę.

`ArticleSummaryProjection(NewsReadContext read)` ma `Name` równe `article-summaries`:

- `ArticleCreatedDomainEvent` → wiersz po `ArticleId`; brak → `Add`, jest → nadpisanie pól,
- `ArticleRevisedDomainEvent` → wiersz po `ArticleId`; aktualizacja tylko wtedy, gdy `row.Version < storedEvent.Version`,
- `Version` wiersza = `storedEvent.Version`.

Warunek wersji robi z projekcji operację idempotentną. Powtórka po utracie checkpointu nie cofa tytułu do starszej rewizji.

### 7. Baza i skład

`news_read` powstaje obok `news_write`. Do numeru `14` w testach i lokalnie ręcznie (`CREATE DATABASE news_read`), od `14` przez Aspire.

```bash
dotnet ef migrations add NewsReadInitial \
  --project src/services/News/News.Infrastructure \
  --context NewsReadContext \
  --output-dir Read/Migrations
```

`NewsReadContextFactory` działa jak fabryka zapisu z [06-postgres.md](06-postgres.md), zmienna `ConnectionStrings__news-read`.

`AddNewsRead(this IServiceCollection services, string connectionString)` rejestruje:

- `AddDbContext<NewsReadContext>`,
- `IProjection` → `ArticleSummaryProjection` (scoped),
- `ProjectionRunner<NewsReadContext>` (scoped),
- `AddHostedService<ProjectionWorker<NewsReadContext>>()`,
- `ProjectionOptions` z sekcji `Projections`.

### Co jest do czego

- `ReadContext` — baza odczytu z miejscem na checkpointy. Usługa dokłada do niej swoje widoki.
- `Checkpoint` — „do której pozycji ta projekcja już doszła”. Leży w bazie odczytu, w tej samej transakcji co widok.
- `IProjection` — tłumacz zdarzenie → wiersz. Nie zapisuje sam, więc widok i checkpoint nie mogą się rozjechać.
- `ProjectionRunner` — jedno deterministyczne przejście. Testy wołają je wprost, bez czekania na tło.
- `ProjectionWorker` — pętla w procesie usługi. Dzięki niej zapis nie czeka na widok.
- `ArticleSummaryRow` — kształt pod ekran. Nie jest agregatem: nie ma `Apply` ani reguł.
- `ArticleSummaryProjection` — upsert z warunkiem wersji. Bezpieczna przy powtórce.
- `NewsReadContext` — właściciel bazy `news_read` i jej migracji.

## Testy

Klasa `ArticleSummaryProjectionTests` w `tests/News.Infrastructure.Tests`. Jeden kontener Postgresa. Fixture tworzy `news_read` (`CREATE DATABASE`), migruje `NewsWriteContext` i `NewsReadContext`. Zdarzenia zapisuje mediator z [09-komenda.md](09-komenda.md). Runner jest wołany wprost.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Run_inserts_summary` | `CreateArticleCommand` z tytułem `Nowy wpis` | `RunOnceAsync` | jeden wiersz z `Title` równym `Nowy wpis` |
| `Run_writes_checkpoint` | jeden artykuł | `RunOnceAsync` | `Checkpoints` ma `article-summaries` z `Position` ostatniego zdarzenia |
| `Second_run_does_nothing` | projekcja już wykonana | drugie `RunOnceAsync` | wynik 0, nadal jeden wiersz |
| `Run_applies_revision` | artykuł i rewizja | `RunOnceAsync` | `Title` z rewizji, `Version` 2 |
| `Replay_after_lost_checkpoint_keeps_latest` | widok po rewizji, wiersz `Checkpoints` usunięty | `RunOnceAsync` | `Title` z rewizji, jeden wiersz |
| `Run_respects_batch_size` | trzy artykuły, `BatchSize` 2 | `RunOnceAsync` | wynik 2 |

`dotnet test tests/News.Infrastructure.Tests`.

## Zasady

- Projekcja czyta tylko `IEventStore`. Nie czyta `NewsWriteContext` wprost.
- Widok i checkpoint zapisują się jednym `SaveChangesAsync`.
- Projekcja jest idempotentna: powtórka zdarzenia nie zmienia wyniku.
- Komenda nie czeka na projekcję i nie otwiera `NewsReadContext`.
- Checkpoint leży w bazie odczytu.

## Poza zakresem

- Zapytanie i port czytnika — [11-zapytanie.md](11-zapytanie.md).
- Kilka replik workera i lider. Jeden proces na usługę wystarcza.
- Powiadomienie klienta o gotowym widoku (SignalR). Klient ponawia `GET`.
- Projekcje między usługami. Inna usługa buduje widok ze zdarzeń integracyjnych — [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).

## Źródła

- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs) — osobna baza odczytu i spójność ostateczna.
- [Materialized View pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/materialized-view) — widok pod zapytanie, odświeżany ze źródła.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — projekcja ze strumienia.
- [Background tasks with hosted services](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services) — `BackgroundService` i scope na przejście.
- [CQRS](https://martinfowler.com/bliki/CQRS.html) — Martin Fowler: osobny model do czytania i koszt spójności ostatecznej.
- [Idempotent Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html) — Hohpe i Woolf: powtórka bez skutków ubocznych.

## Gotowe gdy

- `news_read` istnieje obok `news_write` i ma `ArticleSummaries` oraz `Checkpoints`.
- Po `CreateArticleCommand` jedno przejście runnera wstawia jeden wiersz i przesuwa checkpoint.
- Powtórka po utracie checkpointu nie dubluje wiersza i nie cofa rewizji.
- `CreateArticleCommandHandler` nie zależy od `NewsReadContext`.
- `dotnet test tests/News.Infrastructure.Tests` kończy się kodem 0.
