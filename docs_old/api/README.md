# API — od zdarzenia domenowego do mikroserwisów

Specyfikacja budowana kawałek po kawałku. Ten plik ustala szablon numerów, słownik nazw, bazy, pakiety i kolejność. Obraz całości (usługi, szyna, bazy) jest w [architektura.md](architektura.md). Każdy numer `01`–`22` to jeden zamknięty krok: kod, testy, zielony `dotnet test`.

Dziś w repo jest jedno API w [src/api](../../src/api) z Identity i JWT ([`AppDbContext`](../../src/api/Data/AppDbContext.cs), migracja `InitialIdentity`). Ciąg buduje obok biblioteki w `src/building-blocks`, usługę News z event sourcingiem, a od numeru `14` składa całość w .NET Aspire i rozcina na procesy połączone Kafką. Część F przenosi treść strony z bundla klienta do usług: kompendium z kursami, wyszukiwanie, notatki i żywe CV, edytowane w intranecie tego samego klienta web.

## Po co

Wzorce są dwa. [dotnet/eShop](https://github.com/dotnet/eshop) daje układ usług (`Ordering.Domain`, `Ordering.Infrastructure`, `Ordering.API`), Aspire (`eShop.AppHost`, `eShop.ServiceDefaults`), outbox (`IntegrationEventLogEF`) i pragmatyzm: DDD i CQRS tylko tam, gdzie domena tego wymaga, reszta jest zwykłym CRUD-em. [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) daje bogatą domenę: value objecty, reguły biznesowe jako klasy, abstrakcję czasu (`AppTime`) i event sourcing w warstwie infrastruktury.

Paczek z tych przykładów nie bierzemy. Biblioteki budulcowe są nasze, żeby student widział każdy mechanizm i żeby dało się je później wydać jako NuGet.

## Szablon numeru

Każdy plik `NN-*.md` ma te sekcje, w tej kolejności:

| Sekcja | Co zawiera |
| --- | --- |
| wstęp | jeden akapit: co powstaje, link do numeru poprzedniego i następnego |
| `## Po co` | problem, który numer rozwiązuje, i odniesienie do eShop, GeekLemon albo dokumentacji |
| `## Dlaczego ta technologia` | podsekcja `### <wybór>` na każdą decyzję: co to jest, jaki problem rozwiązuje, alternatywy i dlaczego przegrały, koszt |
| `## Klasy i ścieżki` | tabela plik → odpowiedzialność |
| `## Plan` | kroki `### 1.` … do wykonania, kod tylko tam, gdzie kształt jest decyzją; na końcu `### Co jest do czego` |
| `## Testy` | projekt, klasa, tabela Fakt / Arrange / Act / Assert, komenda `dotnet test` |
| `## Zasady` | reguły, których kod nie łamie |
| `## Poza zakresem` | co jest gdzie indziej, z linkiem do numeru |
| `## Źródła` | `[tytuł](url) — po co`, plus książki bez linku |
| `## Gotowe gdy` | warunki do sprawdzenia, ostatni to komenda z kodem 0 |

`## Dlaczego ta technologia` tłumaczy wybory, zanim powstanie kod. `## Plan` to same kroki, bez uzasadnień, bo te są wyżej. `### Co jest do czego` na końcu planu to lista dla studenta: element, po co istnieje, kto go woła. Ma odpowiadać na pytanie „dlaczego ta klasa w ogóle jest”, a nie powtarzać kroków.

Zasady C# są w [.cursor/rules/csharp.mdc](../../.cursor/rules/csharp.mdc): jeden publiczny typ na plik, `sealed`, rekord dla danych, oczekiwany błąd jako `Result<T>`, `CancellationToken` w każdej metodzie `async`.

## Kolejność

### Część A — domena

| Plik | Zakres |
| --- | --- |
| [01-zdarzenie.md](01-zdarzenie.md) | `IDomainEvent`, `EventNameAttribute`, `ArticleCreatedDomainEvent` |
| [02-value-object.md](02-value-object.md) | `Result<T>`, `ValueObject`, `ArticleId`, `ArticleTitle` |
| [03-agregat.md](03-agregat.md) | `Entity`, `AggregateRoot`, `IBusinessRule`, `Article`, `TimeProvider` |

### Część B — zapis zdarzeń

| Plik | Zakres |
| --- | --- |
| [04-strumien.md](04-strumien.md) | `IEventStore`, `InMemoryEventStore`, konflikt `Version`, globalne `Position` |
| [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md) | `EventTypeRegistry`, `JsonEventSerializer`, `IEventUpcaster` |
| [06-postgres.md](06-postgres.md) | `ApplyEventStore`, `PostgresEventStore<TContext>`, `NewsWriteContext`, baza `news_write` |
| [07-repozytorium.md](07-repozytorium.md) | `IRepository<T>`, `Repository<T>`, `IStreamNaming<T>` |

### Część C — CQRS

| Plik | Zakres |
| --- | --- |
| [08-mediator.md](08-mediator.md) | `IMediator`, `IPipelineBehavior`, `LoggingBehavior`, `ValidatorBehavior`, `TransactionBehavior` |
| [09-komenda.md](09-komenda.md) | `CreateArticleCommand`, `ReviseArticleCommand`, walidatory, handlery |
| [10-projekcja.md](10-projekcja.md) | `ReadContext`, `Checkpoint`, `IProjection`, `ProjectionWorker`, baza `news_read` |
| [11-zapytanie.md](11-zapytanie.md) | `GetArticleQuery`, `IArticleSummaryReader`, `ArticleSummary` |

### Część D — integracja

| Plik | Zakres |
| --- | --- |
| [12-outbox-inbox.md](12-outbox-inbox.md) | `IIntegrationEvent`, `OutboxMessage`, `InboxMessage`, `OutboxDispatcher` |
| [13-kafka.md](13-kafka.md) | `IEventBus`, `KafkaEventBus`, `KafkaConsumerWorker`, tematy i DLQ |

### Część E — platforma i usługi

| Plik | Zakres |
| --- | --- |
| [14-aspire.md](14-aspire.md) | `JJDevHub.AppHost`, `JJDevHub.ServiceDefaults`, publikacja do Compose |
| [15-identity.md](15-identity.md) | `Identity.API`, klucz RSA, JWKS, `UserRegisteredIntegrationEvent`, role `owner` i `student`, kody zaproszeń |
| [16-usluga-news.md](16-usluga-news.md) | `News.API`, endpointy, autor z tokenu, `JJDevHub.Gateway` (YARP) |
| [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md) | `Notifications.Worker`, testy kontraktów |
| [18-ci-uslug.md](18-ci-uslug.md) | `ci.yml` z wykrywaniem zmian, reużywalny workflow, obraz przy wydaniu, deploy z wydania, przejście VM (nginx → gateway, Prometheus na usługę, RAM) |

### Część F — treść

| Plik | Zakres |
| --- | --- |
| [19-learning.md](19-learning.md) | `Learning.*`: technologie, kurs (kolejność lekcji), lekcja z przykładami kodu, wykłady, hasła, widoczność, Markdown, postęp studenta, `learning.integration` ze stanem |
| [20-wyszukiwanie.md](20-wyszukiwanie.md) | wyszukiwanie w Learning: pełny tekst Postgresa i pgvector, RRF, model ONNX w procesie, `EmbeddingWorker` |
| [21-notatki.md](21-notatki.md) | `Article` jako notatka: publikacja, wycofanie, lekcja, slug, historia z projekcji od zera, `JJDevHub.Markdown` |
| [22-cv.md](22-cv.md) | `Cv.API`: CV ze strumieni profilu, stanowisk, projektu, edukacji, aktywności, umiejętności i języków; widok strony, PDF i JSON Resume; dowody z Learning i News, `HybridCache`, Typst |

Numery `01`–`13` nie dotykają [src/api](../../src/api). Do `14` istniejące API działa jak dziś. Kolejność części F wynika z zależności: notatki przypinają się do lekcji z `19`, a CV liczy dowody z `19` i `21`.

## Nazwy

| Nazwa | Gdzie | Skąd |
| --- | --- | --- |
| `Entity`, `ValueObject`, `IAggregateRoot`, `AggregateRoot` | `JJDevHub.Domain` | model domeny w e-booku mikroserwisów .NET |
| `IDomainEvent`, sufiks `DomainEvent`, `DateOccurred` | `JJDevHub.Domain` | eShop: `OrderStartedDomainEvent` |
| `EventNameAttribute`, nazwa `news.article-created.v1` | `JJDevHub.Domain` | stabilny kontrakt zamiast nazwy CLR |
| `IBusinessRule` | `JJDevHub.Domain` | GeekLemon: `IScoringRejectRule` |
| `Result<T>`, `ResultError` (`None`, `Invalid`, `NotFound`, `Conflict`, `Forbidden`) | `JJDevHub.Domain` | jeden typ wyniku w całym ciągu |
| `AddDomainEvent`, `DomainEvents`, `Apply`, `Replay`, `MarkPersisted` | `AggregateRoot` | eShop + event sourcing |
| `Article`, `ArticleId`, `ArticleTitle` | `News.Domain` | przykład agregatu z event sourcingiem |
| `IEventStore`, `AppendAsync`, `LoadAsync`, `ReadAllAsync` | `JJDevHub.EventStore` | wzorzec Event Sourcing |
| `Version`, `Position`, `StoredEvent`, `EventStreamRead` | `JJDevHub.EventStore` | wersja w strumieniu, pozycja globalna |
| `EventTypeRegistry` | `JJDevHub.Domain` | nazwa ↔ typ dla zdarzeń domenowych i integracyjnych |
| `IEventSerializer`, `JsonEventSerializer`, `IEventUpcaster` | `JJDevHub.EventStore` | wersjonowanie zdarzeń |
| `IRepository<T>`, `GetAsync`, `SaveAsync`, `IStreamNaming<T>` | `JJDevHub.EventStore` | repozytorium z dokumentacji Microsoftu |
| `EventStream`, `EventRecord`, `ApplyEventStore`, `PostgresEventStore<TContext>` | `JJDevHub.EventStore.Postgres` | klocki do kontekstu usługi |
| `NewsWriteContext`, `NewsReadContext` | `News.Infrastructure` | jak `OrderingContext : DbContext` w eShop |
| `IRequest<T>`, `ICommand<T>`, `IQuery<T>`, handlery | `JJDevHub.Cqrs` | eShop Ordering |
| `IMediator.Send`, `IPipelineBehavior<TRequest, TResponse>` | `JJDevHub.Cqrs` | łańcuch zachowań z eShop |
| `LoggingBehavior`, `ValidatorBehavior`, `TransactionBehavior`, `IUnitOfWork` | `JJDevHub.Cqrs` | te same nazwy co w eShop |
| `AbstractValidator<T>`, sufiks `Validator` | FluentValidation, w Application | eShop: `CreateOrderCommandValidator` |
| `CreateArticleCommand`, `ReviseArticleCommand`, `GetArticleQuery` | `News.Application` | komenda i zapytanie |
| `ReadContext`, `Checkpoint`, `IProjection`, `ProjectionWorker` | `JJDevHub.Projections` | materialized view |
| `ArticleSummary`, `IArticleSummaryReader` | `News.Application` | model odczytu i port |
| `IIntegrationEvent`, sufiks `IntegrationEvent` | `JJDevHub.EventBus` | eShop: `OrderStartedIntegrationEvent` |
| `IEventBus`, `IIntegrationEventHandler<T>` | `JJDevHub.EventBus` | eShop: `IEventBus` |
| `IntegrationEnvelope`, `ReceiveOutcome` (`Handled`, `Duplicate`, `Ignored`) | `JJDevHub.EventBus` | koperta na szynę i wynik odbioru |
| `OutboxMessage`, `InboxMessage`, `IIntegrationEventOutbox`, `OutboxDispatcher` | `JJDevHub.IntegrationEventLog` | eShop: `IntegrationEventLogEF` |
| `PublishOutbox` | opcja `AddIntegrationEventLog` | usługa tylko konsumująca nie uruchamia dispatchera |
| `KafkaEventBus`, `KafkaConsumerWorker`, `KafkaOptions` | `JJDevHub.EventBus.Kafka` | adapter jak `EventBusRabbitMQ` w eShop |
| `JJDevHub.AppHost`, `JJDevHub.ServiceDefaults`, `AddServiceDefaults` | `src/aspire` | eShop: `eShop.AppHost`, `eShop.ServiceDefaults` |
| `ResourceNames` (`news-write`, `kafka`, `identity-api`, `identity-write`, `identity-read`, `news-api`, `notifications-worker`, `gateway`, `learning-write`, `learning-read`, `learning-api`, `cv-write`, `cv-read`, `cv-api`…) | `JJDevHub.AppHost` | nazwy zasobów i connection stringów |
| `IdentityGuid` | wszędzie | eShop: id użytkownika Identity na agregacie `Buyer` |
| `UserRegisteredIntegrationEvent`, `ArticleCreatedIntegrationEvent` | `*.Contracts` | kontrakty publikowane na szynę |
| `Account`, `StudentInvite`, `InviteCode` | `Identity.API` | konto i zaproszenie ze strumienia; w zdarzeniu skrót hasła albo kodu, nigdy tekst jawny |
| `Roles` (`owner`, `student`), `Policies` (`Owner`, `Student`) | `JJDevHub.ServiceDefaults` | role konta w tokenie |
| `ResultHttpExtensions`, `EntityTag`, `CurrentUser` | `JJDevHub.ServiceDefaults/Http` | `Result<T>` → HTTP, `ETag` i `If-Match`, użytkownik z tokenu |
| `Technology`, `Track`, `Lesson`, `CodeExample`, `Lecture`, `Term` | `Learning.Domain` | technologia, kurs (kolejność), lekcja z przykładami, wykład, hasło |
| `Slug`, `LocalizedText`, `LocalizedMarkdown`, `Visibility` (`Private`, `Students`, `Public`), `Audience` | `Learning.Domain` | adres, dwa języki, kto widzi treść |
| `Version`, `*ChangedIntegrationEvent`, `IsDeleted` | `Learning.Contracts` | pełny stan agregatu na szynie; `Version` to wersja strumienia |
| `IContentChanges` | `Learning.Application` | po zapisie samo zdarzenie do outboxa; indeks z `20` buduje projekcja |
| `MarkdownRenderer`, `WikiLinkExtension`, `MarkdownRenderResult` | `JJDevHub.Markdown` | Markdown → bezpieczny HTML, linki `[[slug]]` do haseł |
| `ISearchIndex`, `SearchDocument`, `SearchChunk`, `EmbeddingWorker`, `OnnxEmbeddingGenerator` | Learning | wyszukiwanie hybrydowe i wektory w procesie |
| `ArticleStatus`, `ArticleVisibility`, `LessonReference`, `ArticleSlug` | `News.Domain` | notatka: szkic, publikacja, wycofanie, lekcja |
| `ArticlePublishedIntegrationEvent`, `ArticleWithdrawnIntegrationEvent`, `FirstPublication` | `News.Contracts` | stan opublikowanej notatki na szynie |
| `Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill`, `Language`, `Period`, `EvidenceItem`, `ResumeView` | `Cv.API` | agregaty CV, każdy ze swoim strumieniem; widok złożony, dowody z innych usług |

### Dlaczego `Article`, a nie `News`

Usługa nazywa się News, a jej namespace to `JJDevHub.News.*`. Klasa `News` w takim drzewie trafia na błąd CS0118: kompilator widzi `News` jako namespace, nie typ. eShop omija to tak samo: usługa `Ordering`, agregat `Order`. U nas usługa News, agregat `Article`. Strumień: `article-{guid}`. Tak samo w [22-cv.md](22-cv.md): usługa Cv nie ma klasy `Cv`. Agregaty to `Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill` i `Language`.

## Bazy

Jeden serwer Postgres 16 (Compose dziś, Aspire od `14`), osobna baza na usługę. Usługa nie otwiera cudzej bazy. Kolumny i klucze są w [bazy.md](bazy.md).

| Baza | Usługa | Co w niej leży | Od numeru |
| --- | --- | --- | --- |
| `news_write` | News | `EventStreams`, `EventRecords`, `OutboxMessages` (od `12`), `ArticleSlugs` (od `21`) | `06` |
| `news_read` | News | `ArticleSummaries`, `Checkpoints`, `ArticleRevisions` (od `21`) | `10` |
| `identity_write` (zasób `identity-write`) | Identity | `EventStreams`, `EventRecords`, `AccountEmails`, `InviteCodeHashes`, `OutboxMessages` | `15` |
| `identity_read` | Identity | `AccountSummaries`, `InviteSummaries`, `Checkpoints` | `15` |
| `notifications` | Notifications | `SentNotifications`, `InboxMessages` | `17` |
| `learning_write` | Learning | `EventStreams`, `EventRecords`, `ContentSlugs`, `LessonSlugs`, `TechnologyUses`, `LessonProgress`, `OutboxMessages` | `19` |
| `learning_read` | Learning | projekcje treści, `TermLinks`, `Checkpoints`; od `20` `SearchDocuments`, `SearchChunks` | `19` |
| `cv_write` | Cv | `EventStreams`, `EventRecords` strumieni agregatów CV, `SkillSlugs` | `22` |
| `cv_read` | Cv | bieżący skład (profil, stanowiska, projekty, edukacja, aktywność, umiejętności, języki), tabele historii, `EvidenceItems`, `CvState`, `ResumeDocuments`, `InboxMessages`, `Checkpoints` | `22` |

Do numeru `14` testy dostają bazy z Testcontainers, a istniejące API łączy się z `jjdevhub`. Od [15-identity.md](15-identity.md) ta baza nazywa się `identity_write` i przenosi wiersze `AspNetUsers` do strumieni.

Od [20-wyszukiwanie.md](20-wyszukiwanie.md) serwer działa na obrazie `pgvector/pgvector:pg16` (Postgres 16 z rozszerzeniem `vector`, Debian). Przejście z `postgres:16-alpine` na VM idzie przez zrzut i odtworzenie, bo zmiana biblioteki C zmienia porządek sortowania tekstu.

Każda baza ma jeden kontekst i domyślną tabelę `__EFMigrationsHistory`. Biblioteki budulcowe nie mają własnych migracji: dają mapowanie (`ApplyEventStore`, `ApplyIntegrationEventLog`), a kontekst i migracje są w usłudze.

Connection stringi nazywają się jak zasoby Aspire: `ConnectionStrings:news-write`, `news-read`, `identity-write`, `identity-read`, `notifications`, `learning-write`, `learning-read`, `cv-write`, `cv-read`, `kafka`.

## Pakiety

Wersje centralnie w [Directory.Packages.props](../../Directory.Packages.props). Numer dopisuje wersję tylko wtedy, gdy pakietu jeszcze nie ma.

| Pakiet | Licencja | Rola | Od numeru |
| --- | --- | --- | --- |
| `Npgsql.EntityFrameworkCore.PostgreSQL` (jest) | PostgreSQL | `NewsWriteContext`, `ReadContext`, konteksty usług | `06` |
| `Microsoft.EntityFrameworkCore.Design` (jest) | MIT | migracje, `PrivateAssets` przy projekcie startowym | `06` |
| `Testcontainers.PostgreSql` (jest) | MIT | testy baz | `06` |
| `FluentValidation`, `FluentValidation.DependencyInjectionExtensions` | Apache 2.0 | walidatory komend i zapytań | `08` |
| `Microsoft.Extensions.Hosting.Abstractions` | MIT | `ProjectionWorker` (`BackgroundService`) | `10` |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | MIT | sekcja `Projections` dla `ProjectionOptions` | `10` |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | MIT | `InMemoryEventBus` | `12` |
| `Testcontainers.Kafka` | MIT | test szyny | `13` |
| `Confluent.Kafka` | Apache 2.0 | producent i konsument | `13` |
| `Aspire.Hosting.AppHost`, `Aspire.Hosting.PostgreSQL`, `Aspire.Hosting.Kafka`, `Aspire.Hosting.Docker` | MIT | AppHost i publikacja Compose | `14` |
| `Aspire.Npgsql.EntityFrameworkCore.PostgreSQL`, `Aspire.Confluent.Kafka` | MIT | klienci w usługach | `14` |
| `Aspire.Hosting.Testing` | MIT | test AppHost | `14` |
| `Microsoft.Extensions.ServiceDiscovery`, `Microsoft.Extensions.Http.Resilience` | MIT | `ServiceDefaults` | `14` |
| `OpenTelemetry.*` (są) | Apache 2.0 | `ServiceDefaults` | `14` |
| `Npgsql.OpenTelemetry` | PostgreSQL | ślady zapytań Npgsql w `ServiceDefaults` | `14` |
| `Npgsql` | PostgreSQL | lista baz w teście AppHost | `14` |
| `Yarp.ReverseProxy`, `Microsoft.Extensions.ServiceDiscovery.Yarp` | MIT | `JJDevHub.Gateway` | `16` |
| `Asp.Versioning.Http` | MIT | wersja API w nagłówku `api-version`, `ServiceDefaults` | `16` |
| `Markdig` | BSD-2-Clause | Markdown → HTML; od `21` w `JJDevHub.Markdown` | `19` |
| `HtmlSanitizer` | MIT | lista dozwolonych znaczników po renderze | `19` |
| `Pgvector.EntityFrameworkCore` | MIT | typ `vector` i operatory odległości w EF | `20` |
| `Microsoft.Extensions.AI.Abstractions`, `Microsoft.Extensions.AI` | MIT | `IEmbeddingGenerator`, cache i telemetria wokół generatora | `20` |
| `Microsoft.ML.OnnxRuntime` | MIT | model wektorów w procesie, na CPU | `20` |
| `Microsoft.ML.Tokenizers` | MIT | tokenizer SentencePiece modelu | `20` |
| `Microsoft.Extensions.Caching.Hybrid` | MIT | `HybridCache` widoku CV | `22` |
| `UglyToad.PdfPig` | Apache 2.0 | odczyt tekstu i linków PDF w testach | `22` |
| `JsonSchema.Net` | MIT | walidacja eksportu JSON Resume w testach | `22` |

Poza NuGetem:

| Składnik | Licencja | Rola | Od numeru |
| --- | --- | --- | --- |
| `intfloat/multilingual-e5-small` (ONNX) | MIT | model wektorów, pobierany przez `infra/models/download.sh` po sumie SHA-256 | `20` |
| Typst | Apache 2.0 | skład PDF CV, w obrazie bazowym `jjdevhub/cv-base` | `22` |
| Inter | SIL OFL 1.1 | czcionka PDF, ta sama co na stronie | `22` |

### Licencje

Dozwolone jest wszystko na otwartej, darmowej licencji (MIT, Apache 2.0, BSD, PostgreSQL, a dla czcionek SIL OFL), także spoza tabeli: Ardalis, Marten, Wolverine, Eventuous, Dapper. Nowy pakiet dopisuje się do tabeli w numerze, który go wprowadza.

Odpadają wersje z licencją komercyjną albo wymagającą rejestracji klucza na produkcji:

| Pakiet | Od wersji | Co się stało |
| --- | --- | --- |
| MediatR | `13` | licencja podwójna (RPL 1.5 albo komercyjna); darmowa edycja Community wymaga klucza i progu przychodu |
| AutoMapper | `15` | jak MediatR |
| MassTransit | `9` | tylko płatna subskrypcja; `8` bez wsparcia |
| Duende IdentityServer | — | płatna licencja dla firm; Identity wydaje tokeny samo ([15-identity.md](15-identity.md)) |
| QuestPDF | `2022.12` | licencja Community tylko poniżej progu przychodu, typ licencji deklarowany w kodzie; PDF składa Typst ([22-cv.md](22-cv.md)) |

Starej wersji z wolną licencją nie przypinamy: nie dostanie poprawek bezpieczeństwa ani wsparcia dla .NET 11.

Mediator, rejestr zdarzeń, magazyn zdarzeń i outbox piszemy sami nie z powodu zakazu, tylko dlatego, że to są tematy ciągu. Uzasadnienie jest w sekcji `## Dlaczego ta technologia` numerów `04`–`08` i `12`.

## Ścieżki w repo

| Ścieżka | Co tam leży | Od numeru |
| --- | --- | --- |
| `src/building-blocks/JJDevHub.Domain` | `Entity`, `AggregateRoot`, `ValueObject`, `IDomainEvent`, `IBusinessRule`, `Result<T>`, `EventTypeRegistry` | `01` |
| `src/building-blocks/JJDevHub.EventStore` | `IEventStore`, `InMemoryEventStore`, rejestr, serializer, `IRepository<T>` | `04` |
| `src/building-blocks/JJDevHub.EventStore.Postgres` | `EventStream`, `EventRecord`, `ApplyEventStore`, `PostgresEventStore<TContext>` | `06` |
| `src/building-blocks/JJDevHub.Cqrs` | mediator i zachowania | `08` |
| `src/building-blocks/JJDevHub.Projections` | `ReadContext`, `Checkpoint`, `ProjectionWorker` | `10` |
| `src/building-blocks/JJDevHub.EventBus` | `IIntegrationEvent`, `IEventBus`, `InMemoryEventBus` | `12` |
| `src/building-blocks/JJDevHub.IntegrationEventLog` | outbox, inbox, dispatcher | `12` |
| `src/building-blocks/JJDevHub.EventBus.Kafka` | adapter Kafki | `13` |
| `src/aspire/JJDevHub.AppHost`, `src/aspire/JJDevHub.ServiceDefaults` | skład i wspólne ustawienia | `14` |
| `src/services/News/News.Domain` | `Article`, zdarzenia, value objecty | `01` |
| `src/services/News/News.Application` | komendy, zapytania, porty | `09` |
| `src/services/News/News.Infrastructure` | `NewsWriteContext`, `NewsReadContext`, projekcja, czytnik | `06` |
| `src/services/News/News.Contracts` | `ArticleCreatedIntegrationEvent` | `12` |
| `src/services/News/News.API` | endpointy | `16` |
| `src/services/Identity/Identity.API`, `Identity.Contracts` | konto, JWT, JWKS, nazwa wyświetlana | `15` |
| `src/services/Notifications/Notifications.Worker` | powiadomienia | `17` |
| `src/gateway/JJDevHub.Gateway` | YARP przed klientem web | `16` |
| `src/services/Learning/Learning.Domain`, `.Application`, `.Infrastructure`, `.Contracts`, `.API` | kompendium, kursy, wykłady, hasła; od `20` wyszukiwanie | `19` |
| `src/building-blocks/JJDevHub.Markdown` | `MarkdownRenderer` wspólny dla Learning i News | `21` |
| `src/services/Cv/Cv.API` | żywe CV, dowody, eksport, PDF | `22` |
| `infra/models` | manifest i skrypt pobrania modelu wektorów | `20` |
| `infra/cv` | obraz bazowy z Typst i skrypt instalacji | `22` |

Do czasu paczki NuGet wszystko idzie przez `ProjectReference`. Nazwa projektu jest przyszłym identyfikatorem paczki.

Puste katalogi po starym podejściu (`src/JJDevHub.Aggregates`, `src/JJDevHub.Events`, `src/JJDevHub.EventStore`, `tests/JJDevHub.EventSourcing.Tests`) znikają w numerze `01`, zanim powstanie nowy kod.

## Testy

Runner to xUnit (`[Fact]`), jak w [tests/JJDevHub.Api.Tests](../../tests/JJDevHub.Api.Tests). Jeden test ma jeden powód do padnięcia. Nazwa metody mówi, co jest prawdą, gdy test przechodzi (`Create_blank_title_returns_invalid`). Kontenery: `postgres:16-alpine` i `confluentinc/cp-kafka` w trybie KRaft (obraz domyślny `Testcontainers.Kafka`). Testy Learning biorą `pgvector/pgvector:pg16`.

| Projekt testowy | Numery | Co jest prawdą na końcu |
| --- | --- | --- |
| `tests/JJDevHub.Domain.Tests` | `01`–`03`, `05` | atrybut nazwy, równość value objectu, mechanika `AggregateRoot`, rejestr nazw |
| `tests/News.Domain.Tests` | `01`–`03`, `21` | `ArticleTitle`, `Article.Create`, `Article.Revise`, reguły, publikacja i wycofanie |
| `tests/JJDevHub.EventStore.Tests` | `04`, `05`, `07` | konflikt wersji, `Position`, rejestr, upcasting, runda repozytorium w pamięci |
| `tests/JJDevHub.EventStore.Postgres.Tests` | `06` | wiersze strumienia, `Position`, konflikt w bazie |
| `tests/JJDevHub.Cqrs.Tests` | `08` | kolejność zachowań, brak handlera, walidacja |
| `tests/News.Application.Tests` | `09`, `11` | handlery na stubach, bez bazy |
| `tests/News.Infrastructure.Tests` | `06`, `07`, `09`–`12`, `21` | migracje, repozytorium na Postgresie, komenda w kontenerze, projekcja, czytnik, outbox, upcaster, rezerwacja sluga, historia |
| `tests/JJDevHub.IntegrationEventLog.Tests` | `12` | outbox w transakcji, dispatcher, inbox |
| `tests/JJDevHub.EventBus.Kafka.Tests` | `13`, `19` | publikacja, konsumpcja, DLQ, temat kompaktowany |
| `tests/JJDevHub.AppHost.Tests` | `14`–`16`, `19`, `22` | zasoby, health checki, polityki, trasy gatewaya |
| `tests/Identity.API.Tests` | `15` | rejestracja, outbox, JWKS, role, zaproszenia (przemianowany `JJDevHub.Api.Tests`) |
| `tests/News.API.Tests` | `16`, `21`, `22` | endpointy, 401, 409, trasa przez gateway, notatki, ponowna publikacja stanu |
| `tests/Notifications.Worker.Tests`, `tests/JJDevHub.Contracts.Tests` | `17`, `19`, `21` | konsumpcja, idempotencja, snapshot kontraktów |
| `tests/Learning.Domain.Tests`, `tests/Learning.Infrastructure.Tests`, `tests/Learning.API.Tests` | `19`, `20` | reguły treści, widoczność, Markdown, import, wyszukiwanie |
| `tests/JJDevHub.Markdown.Tests` | `21` | render i sanitacja po przeniesieniu z Learning |
| `tests/Cv.API.Tests` | `22` | import, dowody, cache, JSON Resume, PDF |

`18` nie dodaje projektu testowego. Sprawdzeniem jest `actionlint` i zielony przebieg workflowu.

Testy, które potrzebują pliku spoza repozytorium, mają cechę i filtr: `[Trait("Category", "Model")]` dla modelu wektorów z `20`, `[Trait("Category", "Typst")]` dla Typst z `22`. CI pobiera oba przez pole `setup` w `infra/ci/services.json`. Lokalnie bez nich: `--filter "Category!=Model&Category!=Typst"`.

## Zasady

- Jeden publiczny typ na plik. Namespace w klamrach (`namespace X.Y { … }`), jak w [csharp.mdc](../../.cursor/rules/csharp.mdc) i w kodzie numerów `01`–`04`. Klasa `sealed`. Zdarzenie, komenda, zapytanie i DTO to `record`.
- Zdarzenie niesie typy proste (`Guid`, `string`, `DateTimeOffset`). Value object nie wchodzi do JSON-a strumienia.
- Typ zdarzenia w bazie i na szynie to nazwa z `[EventName]`. Nazwa CLR nie trafia do danych.
- Pole agregatu zmienia tylko `Apply`. `AddDomainEvent` i `Replay` to dwie drogi do tego samego `Apply`.
- Handler komendy nie otwiera bazy odczytu. Handler zapytania nie woła `IEventStore`.
- Oczekiwany błąd (pusty tytuł, brak wiersza, konflikt wersji, brak uprawnień) to `Result<T>`. Wyjątek zostaje dla awarii IO i błędu składu aplikacji.
- Między usługami idzie zdarzenie integracyjne przez outbox i Kafkę. Usługa nie woła cudzej komendy i nie czyta cudzej bazy.
- Event sourcing mają News (`Article`), Learning (`Technology`, `Track`, `Lesson`, `Lecture`, `Term`), Identity (`Account`, `StudentInvite`) i Cv (`Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill`, `Language`). Notifications i postęp studenta to EF bez strumieni. `CodeExample` jest encją wewnątrz `Lesson`, bez strumienia. Nazwa wyświetlana jest polem `Account`.
- Usługa, której stan jest potrzebny innym (Learning, notatki News), publikuje pełny stan z wersją. Konsument trzyma kopię i pomija wiadomość ze starszą wersją.
- Treść niewidoczna dla czytelnika to `404`, nie `403`. Odpowiedź nie zdradza, że coś istnieje.
- Zapis z `ETag` wymaga `If-Match`: brak to `428`, nieaktualny to `412`.

## Poza zakresem

- Keycloak, Vault, Jenkins, EventStoreDB, MongoDB, OpenSearch, RabbitMQ.
- Kubernetes i Helm. Docelowo jest Compose wygenerowany przez Aspire na jednej VM.
- Snapshoty strumieni. Artykuł, konto i dokument CV mają krótkie strumienie, replay jest tani.
- Saga i proces wieloetapowy między usługami.
- Publikacja paczek na nuget.org.
- Kilka instancji jednej usługi: cache drugiego poziomu, rozproszone blokady, kolejka zadań poza procesem.
- Zewnętrzne API modeli językowych. Wektory liczy model w procesie ([20-wyszukiwanie.md](20-wyszukiwanie.md)).
- Ekrany klienta. Intranet i strony treści są w [docs/frontend](../frontend/README.md).

## Źródła

- [.NET microservices: architecture for containerized .NET applications](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/) — e-book, z którego biorą się nazwy warstw i klas.
- [dotnet/eShop](https://github.com/dotnet/eshop) — referencyjna aplikacja: Aspire, usługi, outbox, szyna.
- [GeekLemonConference](https://github.com/PanNiebieski/GeekLemonConference-CQRS-EventSourcing-CleanArchitecture-DDD-Example) — Cezary Walenciuk: cebula, value objecty, reguły, event sourcing.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — strumień jako źródło stanu.
- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs) — osobny model zapisu i odczytu.
- [Transactional outbox pattern](https://learn.microsoft.com/en-us/azure/architecture/databases/guide/transactional-outbox-cosmos) — zapis i publikacja w jednej transakcji (przykład na Cosmos DB, idea ta sama dla Postgresa).
- [.NET Aspire overview](https://learn.microsoft.com/en-us/dotnet/aspire/get-started/aspire-overview) — AppHost i ServiceDefaults.
- [Apache Kafka documentation](https://kafka.apache.org/documentation/) — tematy, partycje, grupy konsumentów, kompaktowanie.
- [What do you mean by “Event-Driven”?](https://martinfowler.com/articles/201701-event-driven.html) — Martin Fowler: powiadomienie o zdarzeniu a przenoszenie stanu w zdarzeniu.
- Eric Evans, *Domain-Driven Design*; Vaughn Vernon, *Implementing Domain-Driven Design*.

## Gotowe gdy

- Ten plik wymienia kolejność `01`–`22`, szablon numeru i słownik nazw.
- Każda baza ma jedną usługę-właściciela.
- Każdy pakiet ma numer, w którym dochodzi.
- Każdy projekt testowy ma numery, które go zasilają.
