# Notatki

Usługa News z [16-usluga-news.md](16-usluga-news.md) staje się źródłem sekcji Notatki na stronie. Agregat `Article` dostaje slug i język, publikację z widocznością `Public` albo `Students`, wycofanie i przypięcie do lekcji wykładu albo kursu z [19-learning.md](19-learning.md). Nowa projekcja `ArticleRevisions` buduje historię każdej notatki od pozycji 0, także dla artykułów zapisanych, zanim ta projekcja powstała. Opublikowany stan wychodzi na `news.integration` jako `article-published.v1` i `article-withdrawn.v1`, a Notifications z [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md) reaguje na pierwszą publikację. Konsumentem dowodów jest też CV z [22-cv.md](22-cv.md).

## Po co

Notatka to krótki wpis prowadzącego: „Dlaczego CQRS już na laboratorium”, z odnośnikiem do lekcji 3. Dziś cztery notatki leżą w [pl.json](../../src/Clients/web/src/content/pl.json) z polami `relatedCourseSlug` i `relatedLessonSlug`. Kształt jest gotowy, brakuje tylko miejsca, w którym notatkę da się napisać, poprawić i wycofać bez deployu frontu.

News ma już wszystko poza cyklem życia: artykuł z autorem, rewizje z kontrolą wersji, widok, outbox. Osobna usługa Notes powieliłaby agregat, strumień i projekcję. Notatka jest artykułem z publikacją i odnośnikiem do lekcji.

Ten numer pokazuje, po co jest event sourcing. Historia zmian notatki nie była zapisywana jako osobny model, a mimo to jest dostępna dla każdego artykułu od pierwszego dnia, bo strumień trzyma każdą rewizję. Nowa projekcja czyta strumień od początku i buduje widok, którego nikt wcześniej nie zaplanował. To samo dotyczy ponownego renderu Markdown: zmiana potoku to przebudowa projekcji, a nie migracja danych.

## Dlaczego ta technologia

### Notatki w News zamiast osobnej usługi

Osobna usługa Notes miałaby ten sam agregat (tytuł, treść, autor, rewizje), ten sam magazyn zdarzeń i te same endpointy. Różnica to trzy zdarzenia: publikacja, wycofanie, przypięcie do lekcji. Dodanie ich do `Article` to rozwój modelu, a nie nowy kontekst. Granica News pozostaje ta sama: wpisy z historią, publikowane w czasie.

### Slug i język w `news.article-created.v2` z upcasterem

Strona adresuje notatki slugiem (`/pl/notatki/dlaczego-cqrs`) i ma je w dwóch językach. `Article` z numeru `03` ma tylko id. Slug i język należą do faktu utworzenia, więc dochodzą do zdarzenia, które dostaje wersję `v2`.

Zapisane zdarzenia `v1` się nie zmieniają. `ArticleCreatedV1ToV2Upcaster` z mechanizmu z [05-rejestr-zdarzen.md](05-rejestr-zdarzen.md) uzupełnia przy odczycie `language` wartością `pl` i `slug` wartością wyliczoną z tytułu z sufiksem z ośmiu pierwszych znaków id. Sufiks sprawia, że stare artykuły nie zderzą się slugiem z nowymi. Agregat zna tylko `v2`.

Alternatywy:

- **Nowe zdarzenie `ArticleSlugAssigned`** dopisywane do starych strumieni — zmienia historię faktem, który nigdy nie zaszedł.
- **Migracja wierszy zdarzeń** („copy and transform”) — przepisuje magazyn, który z definicji jest tylko do dopisywania.
- **Slug tylko w widoku** — dwa artykuły mogłyby dostać ten sam slug, a URL zależałby od kolejności projekcji.

Tłumaczenie to artykuł z tym samym slugiem w drugim języku. Tak jest dziś w `pl.json` i `en.json`, więc import nie potrzebuje osobnego pola łączącego.

### Unikalność sluga przez tabelę rezerwacji

Agregat ze strumieniem widzi tylko siebie i nie sprawdzi, czy inny artykuł ma ten sam slug. Widok sprawdziłby to z opóźnieniem projekcji. Tabela `ArticleSlugs` w `news_write` z kluczem (`Language`, `Slug`) dostaje wiersz w tej samej transakcji co dopisanie strumienia. Duplikat kończy się naruszeniem klucza i `Conflict`, zanim strumień powstanie. To standardowe rozwiązanie unikalności w event sourcingu: zbiór rezerwacji obok magazynu, spójny transakcyjnie.

### Publikacja z widocznością jako zdarzenie

Szkic, publikacja i wycofanie to fakty z datą, nie flagi. `ArticlePublishedDomainEvent` niesie widoczność (`Public` albo `Students`) i datę publikacji. Ponowna publikacja z inną widocznością to kolejne zdarzenie. Wycofanie nie usuwa artykułu, tylko zdejmuje go ze strony, a historia zostaje.

Data publikacji jest polem zdarzenia obok `DateOccurred`. Import notatek z `pl.json` publikuje je z datą oryginalną (`2026-03-02`), a nie z datą importu. Zwykła publikacja ustawia obie daty na tę samą chwilę.

### Odnośnik do lekcji bez wywołania Learning

`LessonReference` to rodzaj (`lecture` albo `track`), slug wykładu albo kursu i opcjonalny slug lekcji. News nie sprawdza w Learning, czy lekcja istnieje: reguła z [README.md](README.md) zabrania wywoływać cudzej usługi w komendzie. Intranet podaje slug z listy Learning, więc literówka jest mało prawdopodobna. Odnośnik do usuniętej lekcji klient rysuje jako nieaktywny. Slugi w Learning się nie zmieniają, więc odnośnik nie zestarzeje się przez zmianę nazwy.

### Stan opublikowanego artykułu na szynie

`news.integration.article-published.v1` znaczy „tak wygląda teraz opublikowany artykuł”. Wychodzi przy publikacji i przy każdej zmianie artykułu już opublikowanego: rewizji, przypięciu, zmianie widoczności. To ten sam wzór event-carried state transfer co `learning.integration` w [19-learning.md](19-learning.md): CV robi upsert, a wersja strumienia porządkuje wiadomości. Pole `FirstPublication` odróżnia pierwszą publikację, na którą reaguje Notifications, od poprawek, które nie powinny wysyłać drugiego powiadomienia. `article-withdrawn.v1` zdejmuje artykuł u konsumentów.

Szkice nie wychodzą na szynę. Konsumenci News (Notifications, CV) potrzebują tylko treści opublikowanej, a szkic nigdy nie był widoczny, więc nie trzeba go „ukrywać” zdarzeniem. To odwrotnie niż w Learning, gdzie treść prywatna wychodzi, bo bywa publiczna i wraca do prywatnej.

### Markdown w projekcji, render przez odtworzenie

Treść notatki to Markdown, jak w Learning. Projekcja `ArticleSummaryProjection` renderuje HTML przez ten sam potok co Learning. `MarkdownRenderer` przenosi się z `Learning.Infrastructure` do biblioteki `src/building-blocks/JJDevHub.Markdown`, więc podgląd z `POST /api/learning/preview` daje ten sam HTML co notatka.

Render w projekcji to render przy zapisie po stronie odczytu: zdarzenie przychodzi raz, HTML leży w widoku. Zmiana potoku (nowa wersja Markdiga, nowe rozszerzenie) nie wymaga workera ponownego renderu jak w Learning. Wystarczy przebudować widok od pozycji 0.

### Nowa projekcja od pozycji 0

`ProjectionRunner` z [10-projekcja.md](10-projekcja.md) czyta checkpoint każdej projekcji osobno, a brak wiersza to pozycja 0. Rejestracja `ArticleRevisionsProjection` i migracja z pustą tabelą wystarczają. Pierwsze przejście po wdrożeniu czyta wszystkie zdarzenia od początku i zapisuje historię artykułów utworzonych w numerze `16`, kiedy nikt nie myślał o widoku historii. Metryka `jjdevhub_projection_lag` z [18-ci-uslug.md](18-ci-uslug.md) pokazuje, jak nowa projekcja dogania pozostałe.

W modelu CRUD ta sama funkcja wymagałaby tabeli audytu od pierwszego dnia albo zaczynałaby się od dnia wdrożenia.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/News/News.Domain/Articles/ArticleSlug.cs`, `ArticleLanguage.cs` | value object sluga, enum `Pl`, `En` |
| `src/services/News/News.Domain/Articles/ArticleStatus.cs`, `ArticleVisibility.cs` | `Draft`, `Published`, `Withdrawn`; `Students`, `Public` |
| `src/services/News/News.Domain/Articles/LessonReference.cs` | `Kind`, `ParentSlug`, `LessonSlug` |
| `src/services/News/News.Domain/Articles/ArticleCreatedDomainEvent.cs` | nazwa `news.article-created.v2`, pola `Slug` i `Language` |
| `src/services/News/News.Domain/Articles/ArticlePublishedDomainEvent.cs`, `ArticleWithdrawnDomainEvent.cs` | publikacja i wycofanie |
| `src/services/News/News.Domain/Articles/ArticleAttachedToLessonDomainEvent.cs`, `ArticleDetachedFromLessonDomainEvent.cs` | odnośnik do lekcji |
| `src/services/News/News.Domain/Articles/ArticleMustHaveBodyToPublishRule.cs`, `OnlyPublishedArticleCanBeWithdrawnRule.cs` | reguły |
| `src/services/News/News.Domain/Articles/Article.cs` | `Publish`, `Withdraw`, `AttachToLesson`, `DetachFromLesson` |
| `src/services/News/News.Infrastructure/Upcasting/ArticleCreatedV1ToV2Upcaster.cs` | `v1` → `v2` na `JsonObject` |
| `src/services/News/News.Infrastructure/Write/ArticleSlugRow.cs`, `ArticleSlugRegistry.cs` | rezerwacja sluga w `news_write` |
| `src/services/News/News.Infrastructure/Write/ArticleSlugBackfill.cs` | rezerwacje dla artykułów sprzed numeru, raz przy starcie |
| `src/services/News/News.Application/Articles/PublishArticleCommand.cs`, `WithdrawArticleCommand.cs` | komendy z walidatorami i handlerami |
| `src/services/News/News.Application/Articles/AttachArticleToLessonCommand.cs`, `DetachArticleFromLessonCommand.cs` | komendy z walidatorami i handlerami |
| `src/services/News/News.Application/Articles/ImportLegacyNotesCommand.cs` | cztery notatki z `pl.json` i `en.json` |
| `src/services/News/News.Application/Articles/PublishedArticleEvents.cs` | artykuł → `ArticlePublishedIntegrationEvent` |
| `src/services/News/News.Application/Articles/ArticleFilter.cs`, `ReaderScope.cs` | filtr listy i zakres czytelnika |
| `src/services/News/News.Application/Articles/ArticleRevision.cs`, `GetArticleHistoryQuery.cs`, `IArticleRevisionReader.cs` | historia |
| `src/services/News/News.Infrastructure/Read/ArticleRevisionRow.cs`, `ArticleRevisionsProjection.cs`, `ArticleRevisionReader.cs` | widok historii |
| `src/services/News/News.Contracts/ArticlePublishedIntegrationEvent.cs`, `ArticleWithdrawnIntegrationEvent.cs` | kontrakty na `news.integration` |
| `src/building-blocks/JJDevHub.Markdown/` | `MarkdownRenderer` przeniesiony z Learning |
| `src/services/Notifications/Notifications.Worker/IntegrationEvents/ArticlePublishedHandler.cs` | powiadomienie o pierwszej publikacji |

## Plan

### 1. Biblioteka Markdown

```bash
dotnet new classlib -n JJDevHub.Markdown -o src/building-blocks/JJDevHub.Markdown -f net11.0
dotnet sln add src/building-blocks/JJDevHub.Markdown
dotnet add src/building-blocks/JJDevHub.Markdown package Markdig
dotnet add src/building-blocks/JJDevHub.Markdown package HtmlSanitizer
dotnet add src/services/Learning/Learning.Infrastructure reference src/building-blocks/JJDevHub.Markdown
dotnet add src/services/News/News.Infrastructure reference src/building-blocks/JJDevHub.Markdown
```

`MarkdownRenderer`, `MarkdownRenderResult`, `MarkdownContext` i trzy klasy `WikiLink*` przenoszą się z `Learning.Infrastructure/Markdown/` bez zmian w zachowaniu. Learning dalej woła je przez swój port `IMarkdownRenderer`, a `RerenderWorker` zostaje w Learning. Testy `MarkdownRendererTests` przenoszą się do `tests/JJDevHub.Markdown.Tests`.

### 2. Domena

`ArticleSlug` ma te same reguły co `Slug` w Learning (`^[a-z0-9]+(-[a-z0-9]+)*$`, do 80 znaków, `From(title)` bez polskich znaków). Kopia zamiast wspólnego typu, bo domeny usług nie dzielą klas.

```csharp
namespace JJDevHub.News.Domain.Articles
{
    [EventName("news.article-created.v2")]
    public sealed record ArticleCreatedDomainEvent(
        Guid EventId,
        DateTimeOffset DateOccurred,
        Guid ArticleId,
        string Slug,
        string Language,
        string Title,
        string Body,
        string? AuthorIdentityGuid) : IDomainEvent;
}
```

`Article.Create(ArticleTitle title, ArticleSlug slug, ArticleLanguage language, string body, string? authorIdentityGuid, TimeProvider time)`. Test atrybutu nazwy z [01-zdarzenie.md](01-zdarzenie.md) zmienia oczekiwaną wartość na `v2`.

Nowe metody, każda z `OnlyAuthorCanReviseRule` z [03-agregat.md](03-agregat.md):

| Metoda | Reguły | Zdarzenie | Bez zmiany |
| --- | --- | --- | --- |
| `Publish(ArticleVisibility visibility, DateTimeOffset? publishedOn, string? editor, TimeProvider time)` | `ArticleMustHaveBodyToPublishRule` | `ArticlePublishedDomainEvent(…, string Visibility, DateTimeOffset PublishedOn)` | już `Published` z tą samą widocznością |
| `Withdraw(string? editor, TimeProvider time)` | `OnlyPublishedArticleCanBeWithdrawnRule` | `ArticleWithdrawnDomainEvent` | — |
| `AttachToLesson(LessonReference lesson, string? editor, TimeProvider time)` | — | `ArticleAttachedToLessonDomainEvent(…, string Kind, string ParentSlug, string? LessonSlug)` | ten sam odnośnik |
| `DetachFromLesson(string? editor, TimeProvider time)` | — | `ArticleDetachedFromLessonDomainEvent` | brak odnośnika |

`Apply` dostaje cztery gałęzie. Stan agregatu: `Slug`, `Language`, `Status`, `Visibility`, `FirstPublishedOn`, `Lesson`. `publishedOn` puste znaczy „teraz”. `FirstPublishedOn` ustawia się przy pierwszej publikacji i już się nie zmienia.

`Revise` działa w każdym stanie. Poprawka opublikowanej notatki od razu zmienia jej treść na stronie.

### 3. Upcaster i rezerwacja sluga

`ArticleCreatedV1ToV2Upcaster : IEventUpcaster`, `FromName` `news.article-created.v1`, `ToName` `news.article-created.v2`. `Upcast` dopisuje `language: "pl"` i `slug: ArticleSlug.From(title) + "-" + articleId[..8]`. Rejestracja w `AddNewsWrite` obok serializera.

`ArticleSlugRow` (`sealed`): `Language`, `Slug` (klucz z dwóch kolumn), `ArticleId`. Migracja `NewsWriteSlugs` w `NewsWriteContext`.

`IArticleSlugRegistry.ReserveAsync(ArticleLanguage language, ArticleSlug slug, Guid articleId, CancellationToken)` → `Result<bool>`. `ArticleSlugRegistry` robi `Add` i `SaveChangesAsync`. `PostgresException` z `SqlState` `23505` zamienia na `Conflict`. `CreateArticleCommandHandler` rezerwuje slug przed `SaveAsync`, w tej samej transakcji `TransactionBehavior`. `POST` z zajętym slugiem kończy się `409`.

`ArticleSlugBackfill : IHostedService` przy starcie czyta `ReadAllAsync` od pozycji 0, bierze zdarzenia `ArticleCreatedDomainEvent` (po upcastingu) i wstawia brakujące rezerwacje z `ON CONFLICT DO NOTHING`. Uruchomienie drugi raz niczego nie zmienia.

### 4. Komendy

- `CreateArticleCommand` dostaje `Slug` (opcjonalny, domyślnie `ArticleSlug.From(Title)`) i `Language`.
- `PublishArticleCommand(Guid ArticleId, int ExpectedVersion, string Visibility, string? EditorIdentityGuid)`.
- `WithdrawArticleCommand(Guid ArticleId, int ExpectedVersion, string? EditorIdentityGuid)`.
- `AttachArticleToLessonCommand(Guid ArticleId, int ExpectedVersion, string Kind, string ParentSlug, string? LessonSlug, string? EditorIdentityGuid)`.
- `DetachArticleFromLessonCommand(Guid ArticleId, int ExpectedVersion, string? EditorIdentityGuid)`.

Każda ma walidator i sprawdza `ExpectedVersion` jak `ReviseArticleCommand` z [09-komenda.md](09-komenda.md). Odpowiedź to `ArticleWritten`.

Po udanym `SaveAsync` każdy handler zmiany (także `ReviseArticleCommandHandler`) woła:

- `Status == Published` → `outbox.AddAsync(PublishedArticleEvents.For(article, version, firstPublication))`,
- `Withdraw` → `outbox.AddAsync(new ArticleWithdrawnIntegrationEvent(...))`,
- szkic → nic.

`firstPublication` jest `true` tylko w handlerze publikacji, gdy przed zmianą `FirstPublishedOn` było puste.

### 5. Kontrakty

```csharp
namespace JJDevHub.News.Contracts
{
    [EventName("news.integration.article-published.v1")]
    public sealed record ArticlePublishedIntegrationEvent(
        Guid EventId,
        DateTimeOffset OccurredOn,
        Guid ArticleId,
        int Version,
        string Slug,
        string Language,
        string Title,
        string Visibility,
        DateTimeOffset FirstPublishedOn,
        bool FirstPublication,
        LessonReferenceContract? Lesson) : IIntegrationEvent
    {
        [JsonIgnore]
        public string PartitionKey => ArticleId.ToString();
    }
}
```

`LessonReferenceContract(string Kind, string ParentSlug, string? LessonSlug)`. `ArticleWithdrawnIntegrationEvent(Guid EventId, DateTimeOffset OccurredOn, Guid ArticleId, int Version)` z nazwą `news.integration.article-withdrawn.v1`. Treść notatki nie jedzie na szynę.

`ArticleCreatedIntegrationEvent` z [12-outbox-inbox.md](12-outbox-inbox.md) zostaje bez zmian. `JJDevHub.Contracts.Tests` dostaje próbki i snapshoty dwóch nowych kontraktów.

### 6. Widok listy

Migracja `NewsReadNotes` w `NewsReadContext` dodaje do `ArticleSummaries` kolumny `Slug`, `Language`, `Status`, `Visibility`, `FirstPublishedOn`, `LessonKind`, `LessonParentSlug`, `LessonSlug`, `BodyHtml`, `Excerpt`. Indeksy: unikalny (`Language`, `Slug`), (`Language`, `Status`, `Visibility`, `FirstPublishedOn` malejąco), (`LessonKind`, `LessonParentSlug`, `LessonSlug`).

Ta sama migracja przebudowuje widok, bo stare wiersze nie mają sluga ani HTML-a:

```csharp
migrationBuilder.Sql("""
    TRUNCATE "ArticleSummaries";
    DELETE FROM "Checkpoints" WHERE "ProjectionName" = 'article-summaries';
    """);
```

Runner po starcie odtwarza widok od pozycji 0. Do tego czasu lista jest pusta albo niepełna: to sekundy przy setkach zdarzeń.

`ArticleSummaryProjection` dostaje `MarkdownRenderer`:

- `Created` i `Revised` → `BodyHtml` z renderu, `Excerpt` z pierwszego akapitu czystego tekstu (do 240 znaków),
- `Published` → `Status`, `Visibility`, `FirstPublishedOn` (tylko gdy puste),
- `Withdrawn` → `Status`,
- `Attached` i `Detached` → trzy kolumny odnośnika.

Warunek wersji z [10-projekcja.md](10-projekcja.md) obowiązuje dla każdej gałęzi.

`ArticleSummary` dostaje te same pola. `IArticleSummaryReader.ListAsync(ArticleFilter filter, int skip, int take)` i `FindBySlugAsync(ArticleLanguage, ArticleSlug)`. `ArticleFilter(ArticleLanguage Language, ReaderScope Scope, string? LessonKind, string? ParentSlug, string? LessonSlug, ArticleStatus? Status)`.

`ReaderScope(bool Students, bool Drafts)`: anonim `(false, false)`, student `(true, false)`, owner `(true, true)`. Bez `Drafts` czytnik zwraca tylko `Published`. Bez `Students` tylko `Visibility = Public`. Szczegół niewidoczny dla zakresu to `NotFound`.

### 7. Historia

`ArticleRevisionRow` (`sealed`): klucz (`ArticleId`, `Version`), `Kind` (`created`, `revised`, `published`, `withdrawn`, `attached`, `detached`), `Title`, `Body` (puste dla zdarzeń bez treści), `Visibility`, `OccurredOn`. Tabela `ArticleRevisions` w `news_read`, migracja `NewsReadRevisions`.

`ArticleRevisionsProjection`, `Name` `article-revisions`. Każde zdarzenie artykułu to jeden wiersz z `Version` ze `StoredEvent`. Wiersz o tym kluczu już jest → nic, więc powtórka jest bezpieczna.

`GetArticleHistoryQuery(Guid ArticleId)` → `IReadOnlyList<ArticleRevision>` posortowane po `Version`. Porównanie dwóch wersji robi klient: ma obie treści w jednej odpowiedzi.

### 8. Import notatek

`ImportLegacyNotesCommand(JsonElement Pl, JsonElement En, string OwnerIdentityGuid)` dla każdego `notes.items[]` z obu plików:

- slug już zarezerwowany w tym języku → `Skipped`,
- `Article.Create` z tytułem, slugiem, językiem i treścią: `summary` jako pierwszy akapit, potem `body[]` jako kolejne,
- `Publish(Public, publishedOn: date, …)`,
- `relatedCourseSlug` → `AttachToLesson(new LessonReference("lecture", relatedCourseSlug, relatedLessonSlug))`,
- jeden `SaveAsync` na artykuł, zdarzenie `article-published.v1` w outboxie.

Odpowiedź: `LegacyNotesReport(int Imported, int Skipped)`. Wywołanie raz na produkcji, jak import treści w [19-learning.md](19-learning.md), na `POST /api/articles/import/legacy`.

### 9. Endpointy

`POST` i `PUT` z [16-usluga-news.md](16-usluga-news.md) przechodzą z `RequireAuthorization()` na `RequireAuthorization(Policies.Owner)`. Testy z `16` dostają token z rolą `owner`.

| Metoda i ścieżka | Polityka | Wynik |
| --- | --- | --- |
| `GET /api/articles?lang=pl&lecture=&track=&lesson=&status=&page=&pageSize=` | anonimowo | lista z zakresu czytelnika; `status` tylko dla ownera |
| `GET /api/articles/{id:guid}` | anonimowo | `200` + `ETag`, `404` poza zakresem |
| `GET /api/articles/{lang:length(2)}/{slug}` | anonimowo | to samo po slugu, dla adresów strony |
| `POST /api/articles/{id:guid}/publish` | `Owner` | body `{ visibility }` + `If-Match` → `200` + `ETag`, `400`, `412`, `428` |
| `POST /api/articles/{id:guid}/withdraw` | `Owner` | `If-Match` → `200` + `ETag`, `400` dla szkicu |
| `PUT /api/articles/{id:guid}/lesson` | `Owner` | body `{ kind, parentSlug, lessonSlug }` + `If-Match` → `200` |
| `DELETE /api/articles/{id:guid}/lesson` | `Owner` | `If-Match` → `200` |
| `GET /api/articles/{id:guid}/history` | `Owner` | lista `ArticleRevision` |
| `POST /api/articles/import/legacy` | `Owner` | `200` z `LegacyNotesReport` |

`ReaderScope` buduje endpoint przez `IAuthorizationService` z politykami `Student` i `Owner`, jak `CurrentAudience` w Learning. Publikacja to `POST` na podzasobie, bo zmienia stan przez fakt, a nie przez nadpisanie pola.

### 10. Notifications

`ArticleCreatedHandler` z [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md) znika: szkic nie jest powodem do powiadomienia. Dochodzi `ArticlePublishedHandler : IIntegrationEventHandler<ArticlePublishedIntegrationEvent>`:

- `FirstPublication == false` → nic,
- `true` → `SendAsync("article-published", null, title)` i `SentNotification` z rodzajem `article-published`.

Unikalny indeks `EventId` + `Kind` z numeru `17` zostaje. Grupa `notifications` dalej słucha `news.integration`.

### Co jest do czego

- `ArticleSlug` i `ArticleLanguage` — adres notatki na stronie i para tłumaczeń bez osobnego pola.
- `ArticleCreatedV1ToV2Upcaster` — stare strumienie czytają się w nowym kształcie bez zmiany ani jednego wiersza.
- `ArticleSlugs` — unikalność, której agregat ze strumieniem sam nie sprawdzi.
- `Publish`, `Withdraw` — cykl życia notatki jako fakty z datą. Historia pokazuje, kiedy i z jaką widocznością.
- `LessonReference` — notatka przy lekcji wykładu albo kursu, bez zależności od dostępności Learning.
- `ReaderScope` — ta sama lista dla gościa, studenta i ownera, z filtrem w SQL.
- `ArticleRevisionsProjection` — widok, którego nie było w planie, zbudowany z historii, która już była w bazie.
- `JJDevHub.Markdown` — jeden potok HTML dla Learning i News.
- `ArticlePublishedIntegrationEvent` — stan opublikowanej notatki dla CV i Notifications. Szkice nie wychodzą z usługi.
- `ArticlePublishedHandler` — jedno powiadomienie na notatkę, nie na każdą poprawkę.

## Testy

Projekt `tests/News.Domain.Tests`, klasa `ArticlePublicationTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `New_article_is_draft` | `Article.Create` | odczyt `Status` | `Draft` |
| `Publish_sets_visibility_and_first_date` | szkic | `Publish(Students, null, …)` | `Published`, `Students`, `FirstPublishedOn` równe czasowi z `FakeTimeProvider` |
| `Publish_keeps_given_date` | szkic | `Publish(Public, 2026-03-02, …)` | `FirstPublishedOn` 2026-03-02 |
| `Empty_body_cannot_be_published` | szkic z pustą treścią | `Publish` | `Invalid` |
| `Same_publication_adds_no_event` | `Published`, `Public` | `Publish(Public, …)` | zero nowych zdarzeń |
| `Republish_keeps_first_date` | opublikowany, wycofany | `Publish` | `FirstPublishedOn` z pierwszej publikacji |
| `Draft_cannot_be_withdrawn` | szkic | `Withdraw` | `Invalid` |
| `Other_user_cannot_publish` | artykuł autora `a` | `Publish` z `b` | `Forbidden` |
| `Attach_same_lesson_adds_no_event` | przypięty do `mobile/cqrs` | `AttachToLesson` z tym samym | zero nowych zdarzeń |
| `Replay_restores_publication_state` | strumień z publikacją i przypięciem | `Replay` po kolei | ten sam `Status`, `Visibility`, `Lesson` |

Projekt `tests/News.Infrastructure.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `V1_created_event_reads_as_v2` | wiersz `news.article-created.v1` zapisany wprost w `EventRecords` | `LoadAsync` | `Language` `pl`, `Slug` z tytułu i sufiksem z id |
| `Duplicate_slug_is_conflict` | artykuł `pl/dlaczego-cqrs` | `CreateArticleCommand` z tym slugiem | `Conflict`, brak nowego strumienia |
| `Same_slug_in_other_language_is_allowed` | artykuł `pl/dlaczego-cqrs` | `CreateArticleCommand` `en/dlaczego-cqrs` | `Ok` |
| `Backfill_reserves_old_slugs` | strumień `v1` bez rezerwacji | `ArticleSlugBackfill.StartAsync` dwa razy | jedna rezerwacja |
| `Publish_writes_published_event_to_outbox` | szkic | `PublishArticleCommand` | jeden wiersz `news.integration.article-published.v1` z `FirstPublication` `true` |
| `Revise_of_draft_writes_no_published_event` | szkic | `ReviseArticleCommand` | brak wiersza `article-published` |
| `Revise_of_published_writes_state` | opublikowany | `ReviseArticleCommand` | wiersz `article-published` z `FirstPublication` `false` |
| `Summary_has_html_and_excerpt` | artykuł z `**a**\n\nb` | przejście runnera | `BodyHtml` z `<strong>a</strong>`, `Excerpt` `a` |
| `List_hides_drafts_and_students_for_anonymous` | szkic, `Public`, `Students` | `ListAsync` z zakresem anonima | tylko `Public` |
| `List_filters_by_lesson` | dwie notatki, jedna przy `mobile/cqrs` | `ListAsync` z `lecture=mobile`, `lesson=cqrs` | jedna |
| `New_projection_rebuilds_history_from_position_zero` | dwa artykuły z rewizjami, przejście tylko `article-summaries`; potem rejestracja `ArticleRevisionsProjection` | `RunOnceAsync` | wiersz historii dla każdego zdarzenia, checkpoint `article-revisions` na ostatniej pozycji |
| `History_replay_is_idempotent` | historia zbudowana, checkpoint usunięty | `RunOnceAsync` | ta sama liczba wierszy |
| `Summary_rebuild_after_migration_restores_rows` | widok po `NewsReadNotes` (pusty, bez checkpointu) | `RunOnceAsync` do zera | wiersze z `Slug` i `BodyHtml` dla wszystkich artykułów |

Projekt `tests/News.API.Tests`, klasa `NotesEndpointsTests`. Fixture `Fixtures/pl.json` i `en.json`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Student_cannot_create_article` | token studenta | `POST /api/articles` | `403` |
| `Publish_returns_new_etag` | szkic w wersji 1 | `POST …/publish` z `If-Match: "1"` | `200`, `ETag` `"2"` |
| `Publish_without_if_match_returns_428` | szkic | `POST …/publish` bez nagłówka | `428` |
| `Draft_is_404_for_anonymous` | szkic | `GET` po id bez tokenu | `404` |
| `Students_note_is_visible_to_student` | notatka `Students` | `GET /api/articles/pl/{slug}` z tokenem studenta | `200` |
| `History_requires_owner` | notatka | `GET …/history` z tokenem studenta | `403` |
| `History_lists_every_change` | utworzenie, rewizja, publikacja | `GET …/history` ownerem | trzy wpisy w kolejności wersji |
| `Legacy_import_publishes_four_notes_per_language` | fixture | `POST /api/articles/import/legacy` | `Imported` 8, `GET ?lang=en` zwraca 4 |
| `Legacy_import_keeps_original_date` | po imporcie | `GET /api/articles/pl/dlaczego-cqrs` | `FirstPublishedOn` 2026-03-02 |
| `Second_legacy_import_skips` | po imporcie | drugi import | `Imported` 0, `Skipped` 8 |

Projekt `tests/Notifications.Worker.Tests`: `Article_created_sends_once` i `Duplicate_article_sends_nothing` zmieniają się na:

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `First_publication_sends_once` | koperta `article-published` z `FirstPublication` `true` | `ReceiveAsync` | jedno wywołanie nadawcy |
| `Correction_sends_nothing` | koperta z `FirstPublication` `false` | `ReceiveAsync` | nadawca nie wywołany |
| `Created_event_is_ignored` | koperta `article-created` | `ReceiveAsync` | `Ignored` |

`dotnet test` dla `tests/News.Domain.Tests`, `tests/News.Infrastructure.Tests`, `tests/News.API.Tests`, `tests/Notifications.Worker.Tests`, `tests/JJDevHub.Markdown.Tests` i `tests/JJDevHub.Contracts.Tests`.

## Zasady

- Zapisany wiersz zdarzenia się nie zmienia. Nowe pola w starym zdarzeniu daje upcaster.
- Slug rezerwuje się w transakcji dopisania strumienia. Widok nie decyduje o unikalności.
- Szkic nie wychodzi na szynę. Stan opublikowanej notatki wychodzi po każdej zmianie.
- Lista i szczegół filtrują po zakresie czytelnika w SQL. Szkic i notatka `Students` są `404` dla gościa.
- News nie woła Learning. Odnośnik do lekcji to slug, nie sprawdzony identyfikator.
- Zmiana widoku to migracja z przebudową od pozycji 0, nie ręczna aktualizacja wierszy.
- Zapis, publikacja i historia wymagają polityki `Owner`.

## Poza zakresem

- Publiczna historia opublikowanych wersji i porównanie po stronie serwera.
- Komentarze studentów pod notatką.
- Wyszukiwanie w notatkach. Indeks z [20-wyszukiwanie.md](20-wyszukiwanie.md) jest w bazie Learning.
- Zaplanowana publikacja („opublikuj w poniedziałek o 8:00”). To worker, który wydaje `PublishArticleCommand` o czasie.
- Kanał RSS albo Atom.
- Ekrany notatek w intranecie — [docs/frontend/intranet/02-edytor.md](../frontend/intranet/02-edytor.md).

## Źródła

- [Versioning in an Event Sourced System](https://leanpub.com/esversioning) — Greg Young: upcasting i dlaczego nie przepisuje się zdarzeń.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — odtwarzanie widoków z historii, nowy widok z istniejących zdarzeń.
- [How to ensure uniqueness in Event Sourcing](https://event-driven.io/en/uniqueness-in-event-sourcing/) — Oskar Dudycz: rezerwacja w tabeli obok magazynu zdarzeń.
- [What do you mean by “Event-Driven”?](https://martinfowler.com/articles/201701-event-driven.html) — Martin Fowler: event-carried state transfer.
- [RFC 9110: conditional requests](https://www.rfc-editor.org/rfc/rfc9110#name-conditional-requests) — `If-Match` przy publikacji i wycofaniu.
- [PostgreSQL error codes](https://www.postgresql.org/docs/16/errcodes-appendix.html) — `23505 unique_violation`.

## Gotowe gdy

- Cztery notatki z `pl.json` i cztery z `en.json` są opublikowane w News z oryginalną datą i odnośnikiem do lekcji.
- Szkic nie pojawia się na liście ani pod adresem dla gościa, a notatka `Students` pojawia się dla studenta.
- `GET /api/articles/{id}/history` zwraca historię artykułu utworzonego w numerze `16`, przed powstaniem projekcji.
- Zdarzenie `news.article-created.v1` zapisane przed tym numerem wczytuje się z `Language` i `Slug`.
- Pierwsza publikacja zostawia jeden `SentNotification` `article-published`, a poprawka żadnego.
- `dotnet test` dla sześciu projektów z sekcji Testy kończy się kodem 0.
