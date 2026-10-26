# 14. Outbox i inbox

Ten numer zapisuje zdarzenie integracyjne w tej samej transakcji co strumień i pamięta po
stronie odbiorcy, że wiadomość już zastosowano. Tabele i dispatcher są w
`JJDevHub.IntegrationEventLog`. Kontrakty są w `JJDevHub.EventBus`. Transport Kafki dołoży
[15-kafka.md](15-kafka.md). Cache z [13-redis.md](13-redis.md) nie przenosi tych wiadomości. Bez
tego numeru publikacja artykułu albo ginie między commitem a wysyłką, albo dociera do sąsiada,
choć strumień się wycofał, a drugi pod Contact wysyła push drugi raz.

Zdarzenie domenowe zostaje w procesie i w `EventRecords`. Na zewnątrz wychodzi osobny rekord z
`{Usługa}.Contracts`. Nazwa bierze się z `[EventName]`, na przykład `news.article-created.v1`,
nigdy z nazwy klasy CLR. `ArticleCreated` w `News.Core` może mieć pola, których sąsiad nie ma
znać. `ArticleCreatedIntegrationEvent` w `News.Contracts` jest rekordem publicznym.
`News.Contracts` referencjonuje tylko `JJDevHub.EventBus` i kernel, bo tam jest atrybut nazwy.
Nie referencjonuje `News.Core`.

Wysyłka jest co najmniej raz. Dispatcher może wysłać i paść przed oznaczeniem `ProcessedOn`.
Odbiorca dlatego ma inbox: wiersz `InboxMessages` schodzi w tej samej transakcji co skutek
wiadomości. Drugi raz ten sam `EventId` daje `ReceiveOutcome.Duplicate` i nic nie zmienia.
Kontakt z studentem i z rekruterem kończy się pushem. Bez inboxa drugi pod wysłałby
powiadomienie drugi raz. To jest ten sam mechanizm co przy każdej innej wiadomości, nie osobna
ścieżka dla telefonu. Nazwy kontraktu to `contact.student-inquiry-received.v1` i
`contact.recruiter-inquiry-received.v1`. Temat, na który pójdą, ustala numer `15`. Tu wiersz
outboxa trzyma tę nazwę w kolumnie `Name`.

## Po co

Zapis strumienia i wysłanie wiadomości do drugiej usługi to dwa systemy. Jeśli proces padnie po
commicie bazy, a przed wysyłką, sąsiad nie dowie się o fakcie. Jeśli wysyłka przejdzie, a baza
się wycofa, sąsiad dostanie fakt, który nie zaszedł. Dla artykułu oznacza to albo Cv i inne
usługi, które nigdy nie usłyszą o `news.article-created.v1`, albo sąsiada, który złożył widok
notatki wycofanej w News. Dla zapytania studenta oznacza to albo brak pusha, albo drugi push,
gdy wysyłka poszła, a wiersz skutku nie. Outbox zamienia oba przebiegi w jeden commit: wiersz
`OutboxMessages` powstaje razem ze strumieniem. Dispatcher czyta wiersz po commicie i wysyła.
Porażka wysyłki zostawia wiersz do ponowienia.

`IIntegrationEventOutbox.AddAsync` wymaga otwartej transakcji na tym samym `DbContext` co
`PostgresEventStore`. `TransactionBehavior` z [10-cqrs.md](10-cqrs.md) otwiera ją przed
handlerem. Handler woła `AppendAsync`, potem przy sukcesie `AddAsync`. Przy `conflict` wychodzi
bez outboxa. Jedno `CommitAsync` zapisuje `EventRecords` i `OutboxMessages`. `RollbackAsync`
zabiera oba. Test `Rollback_removes_stream_and_outbox` otwiera transakcję, woła oba zapisy i
`RollbackAsync`, potem widzi zero wierszy w obu tabelach. Test
`Append_and_outbox_commit_together` po `CommitAsync` widzi jeden `EventRecord` i jeden
`OutboxMessage`. `AddAsync` przy `CurrentTransaction == null` rzuca `InvalidOperationException`.
To błąd składu, kod `composition.invalid` na brzegu, nie cichy zapis poza transakcją.

Drugi pod tej samej usługi nie stosuje wiadomości drugi raz. Oba mogą ją dostać po rebalansie
grupy. Unikalny klucz `(EventId, Consumer)` puszcza jedną transakcję, druga dostaje konflikt i
zwraca `Duplicate`. `Consumer` jest nazwą usługi odbiorcy: `cv`, `contact`, `news`, `learning`,
`identity`. Dwa równoległe `ReceiveAsync` z tym samym `EventId` i tym samym `Consumer` kończą
się jednym `Handled` i jednym `Duplicate`, a skutek handlera, licznik, równa się 1. `Ignored`
jest trzecim wynikiem: nieznana nazwa albo brak handlera. To nie jest wyjątek. Na jednym temacie
leżą różne fakty, a odbiorca zna tylko swoje. Wyjątek handlera wycofuje transakcję, wiersz
inboxa nie powstaje, transport ponowi wiadomość.

Do czasu numeru `15` `IEventBus` to `InMemoryEventBus`, który w procesie oddaje kopertę do
`IIntegrationEventReceiver`. Test outboxa nie potrzebuje Kafki. `JJDevHub.EventBus` nie
referencjonuje EF ani Kafki. Redis nie jest używany jako outbox ani inbox. Restart cache nie
może skasować „trzeba wysłać” ani „już zastosowałem”. Te fakty leżą w Postgresie, w tej bazie, w
której schodzi skutek.

## Dlaczego ta technologia

### Jeden commit ze strumieniem

`IntegrationEventOutbox<TContext>.AddAsync` sprawdza transakcję, serializuje, dodaje
`OutboxMessage` z `ProcessedOn` pustym i `Attempts` równym 0, woła `SaveChangesAsync`. Nie
commituje. Commit należy do `TransactionBehavior` albo do testu, który sam otworzył transakcję.
`*WriteContext.OnModelCreating` woła `ApplyEventStore` i `ApplyIntegrationEventLog`. Dzięki temu
strumień artykułu i wiersz `news.article-created.v1` są jednym modelem EF. Osobne połączenie na
outbox z powrotem daje dwa commity.

Publikacja do brokera na końcu handlera, po `SaveChanges`, przegrywa, bo to dwa commity. Proces
może paść w szczelinie. Zapis outboxa w osobnej bazie przegrywa z tego samego powodu: nie ma
wspólnej transakcji ze strumieniem. Change data capture z logu Postgresa przegrywa na jednej
maszynie: dokładamy klaster łącznika, a i tak musimy mieć model wiadomości. Własna tabela jest
tym modelem i jest w tej samej bazie co `EventRecords`.

Koszt: dispatcher jest osobnym procesem w tle i wiadomość do sąsiada spóźnia się o jedno
przejście pętli. Fakt domenowy jest już bezpieczny. Sąsiad jest ostatecznie spójny, tak jak
projekcja. `OutboxDispatcher<TContext>` jest `BackgroundService` o tym samym kształcie co
`ProjectionWorker`: scope, jedno przejście, przy zerze czekanie `IdleDelay`. `OutboxOptions`
mają `BatchSize` 20, `MaxAttempts` 10 i `IdleDelay` 500 ms. To jest postój pustej paczki, nie
opóźnienie biznesowe pusha. Push i tak idzie po commicie, nie w żądaniu HTTP, które przyjęło
zapytanie studenta.

`Add_without_transaction_throws` woła `AddAsync` bez `Begin` i oczekuje
`InvalidOperationException` oraz zero wierszy. Cichy zapis poza transakcją zostałby w bazie
nawet wtedy, gdy strumień się wycofa, i sąsiad dostałby artykuł, którego nie ma. Wyjątek składu
jest głośny. Na brzegu HTTP stanie się `composition.invalid`, zgodnie z numerem `11`. Ten numer
wyjątku nie tłumaczy. Tu ma być niemożliwe dojście do `INSERT` bez otwartej transakcji.

### Rekord integracyjny osobno od zdarzenia domenowego

`ArticleCreated` w `News.Core` jest faktem strumienia. Może mieć pola, których sąsiad nie ma
znać, i zmienia się upcasterem wewnątrz News. `ArticleCreatedIntegrationEvent` w
`News.Contracts` jest rekordem publicznym: `EventId`, `OccurredOn`, `PartitionKey`, pola
kontraktu. Atrybut `[EventName("news.article-created.v1")]` stoi na rekordzie. Ta sama nazwa
może stać na zdarzeniu domenowym, bo rejestr domenowy skanuje `Core`, a rejestr integracyjny
skanuje `Contracts`. W jednym rejestrze duplikat nazwy zatrzymuje host. Typ bez `[EventName]`
albo dwie nazwy takie same też zatrzymują start. Rejestr integracyjny buduje się z
`typeof(IIntegrationEvent)` i zestawu `Contracts`.

Wysyłanie zdarzenia domenowego na szynę przegrywa, bo sąsiad dostałby zależność od `News.Core`
albo dostałby JSON, którego nikt nie obiecał. Nazwa CLR na szynie przegrywa, bo przeniesienie
rekordu do innego namespace psuje odbiorców, którzy już zapisali typ. Kolumna `Name` i nagłówek
na szynie biorą atrybut. Test `Name_comes_from_attribute` zapisuje
`[EventName("test.happened.v1")]` i po commicie oczekuje `Name` równego `test.happened.v1`.
Rekordy w `*.Contracts` powstają w numerze usługi. Ten numer definiuje ich kształt i testuje go
typem `TestHappenedIntegrationEvent`.

Koszt: handler mapuje jeden fakt na drugi. To jest jawne kilka linii, nie automagiczne
kopiowanie wszystkich pól. Nie każdy fakt domenowy ma bliźniaka integracyjnego. Rewizja, która
zostaje w usłudze, nie woła outboxa. `PartitionKey` grupuje kolejność: dla artykułu
identyfikator artykułu, dla zapytania identyfikator zapytania. Serializer robi
`IntegrationEnvelope` z nazwą z rejestru i JSON-em `JsonSerializerDefaults.Web`. `FromEnvelope`
zwraca `null` dla nieznanej nazwy. `null` staje się `Ignored`, nie wyjątkiem. Dzięki temu
Contact może stać na temacie, na którym leży też fakt, którego nie obsługuje, i nie wywalać
partycji.

Przykłady nazw, które są kontraktem, nie sugestią: `news.article-created.v1`,
`contact.student-inquiry-received.v1`, `contact.recruiter-inquiry-received.v1`. Student i
rekruter są dwoma rekordami, nie jednym workiem z flagą. Inbox i tak deduplikuje po `EventId`,
więc drugi pod nie wyśle dwóch pushy tego samego identyfikatora. Nowy `EventId` przy ponowieniu
byłby nowym faktem. Tego dispatcher nie robi.

### Tabela outboxa i dispatcher

`OutboxMessage` jest `sealed`. `EventId` jest kluczem. Dalej `Name`, `PartitionKey`, `Payload`
(`jsonb`), `OccurredOn`, `CreatedOn`, `ProcessedOn` (`DateTimeOffset?`), `Attempts`, `LastError`
do 2000 znaków. Indeks częściowy po `CreatedOn` obejmuje wiersze z `ProcessedOn` pustym. Dzięki
temu paczka niewysłanych nie skanuje historii, która już poszła. Wiersze wysłane zostają w
tabeli. Retencja wierszy z ustawionym `ProcessedOn` jest osobnym, późniejszym sprzątaniem. Ten
numer ich nie kasuje, żeby dało się zobaczyć, co poszło.

`OutboxProcessor.RunOnceAsync` otwiera transakcję i bierze paczkę:

```sql
SELECT * FROM "OutboxMessages"
WHERE "ProcessedOn" IS NULL AND "Attempts" < @maxAttempts
ORDER BY "CreatedOn"
LIMIT @batch
FOR UPDATE SKIP LOCKED
```

SQL jest w `OutboxProcessor` jako `FromSql`, z tokenem. Sukces `IEventBus.PublishAsync` ustawia
`ProcessedOn`. `EventBusPublishException` zwiększa `Attempts`, zapisuje `LastError` i przerywa
paczkę, żeby nie wysłać następnej wiadomości tego samego klucza przed poprzednią. `MaxAttempts`
domyślnie 10. Wiersz, który wyczerpie próby, zostaje w tabeli i loguje się jako `Error`. Nie
znika po cichu. `SKIP LOCKED` sprawia, że dwa dispatchery biorą rozłączne wiersze. Drugi pod nie
wysyła tej samej paczki równolegle z pierwszym. Test `Second_dispatcher_skips_locked_row` trzyma
dwa procesory i jeden wiersz: pierwszy trzyma transakcję, drugi `RunOnceAsync` zwraca 0.

`Dispatcher_marks_processed` kładzie wiersz niewysłany i `InMemoryEventBus`, woła `RunOnceAsync`
i oczekuje ustawionego `ProcessedOn` oraz tego, że bus dostał `EventId`.
`Publish_failure_increments_attempts` każe busowi rzucić `EventBusPublishException` i oczekuje
`Attempts` równego 1 oraz pustego `ProcessedOn`. `InMemoryEventBus` w teście zapisuje kopertę na
listę i, w osobnym teście, rzuca ten jeden wyjątek transportu. Innych wyjątków procesor nie
traktuje jako „spróbuj ponownie w tej samej semantyce”. `EventBusPublishException` jest jedynym
sygnałem ponowienia dla procesora.

Koszt: sami piszemy `FOR UPDATE SKIP LOCKED` i licznik prób. Test na Postgresie jest tego ceną i
jest w tym numerze. Obraz to `postgres:16-alpine`, cecha `Category=Integration`. Dwa dispatchery
na jednej bazie nie dublują wysyłki tej samej paczki, ale wysłanie i pad przed `ProcessedOn`
nadal jest możliwe. To nie jest wada tabeli. To jest powód inboxa. Idempotencja producenta, gdy
dojdzie w numerze `15`, też nie zastąpi inboxa. Adresuje inne powtórzenie.

### Inbox i `ReceiveOutcome`

`InboxMessage` jest `sealed`. Klucz złożony to `EventId` i `Consumer`. Dalej `Name` i
`ProcessedOn`. `IIntegrationEventReceiver.ReceiveAsync` zwraca enum `ReceiveOutcome`:

| Wartość | Kiedy |
| --- | --- |
| `Handled` | handler wykonał skutek i wiersz inboxa jest w tym samym commicie |
| `Duplicate` | wiersz `(EventId, Consumer)` już jest, skutek się nie powtarza |
| `Ignored` | nieznana nazwa albo brak handlera dla tego typu u tego odbiorcy |

Nieznana nazwa nie jest błędem. `Receive_unknown_name_is_ignored` podaje nazwę spoza rejestru i
oczekuje `Ignored` oraz braku wiersza inboxa. `Ignored` pozwala transportowi iść dalej. Porażka
handlera jest wyjątkiem: transakcja się wycofuje, wiersz inboxa nie powstaje, transport ponowi
wiadomość. Gdyby porażka zostawiała wiersz, ponowienie dostałoby `Duplicate` i skutek nigdy by
nie doszedł. `Receive_handled_writes_inbox` oczekuje `Handled`, jednego wiersza i jednego
skutku. `Receive_duplicate_skips_handler` przy istniejącym wierszu oczekuje `Duplicate` i
skutku, który nie rośnie.

`InboxReceiver.ReceiveAsync` idzie tak. `FromEnvelope` daje `null` — `Ignored`, bez transakcji.
Brak handlera — `Ignored`, bez transakcji. Transakcja, wiersz istnieje — rollback, `Duplicate`.
Handler, wstawienie `InboxMessage`, commit — `Handled`. Wyjątek handlera — rollback, wyjątek do
wołającego. `InboxOptions.Consumer` ustawia `Api` usługi. Dwa odbiory z tym samym `EventId` i
tym samym `Consumer` nie mogą oba dojść do `Handled`. Test `Parallel_receive_one_duplicate` to
sprawdza: jeden `Handled`, jeden `Duplicate`, skutek równy 1.

Handler pisze swoim `DbContext` uczestniczącym w tej transakcji. Gdy skutkiem jest dopisanie
strumienia odbiorcy, jest to ten sam kontekst zapisu i ten sam commit co strumień. Gdy skutkiem
jest kopia stanu w bazie odczytu odbiorcy, inbox leży na tym kontekście, który kopię zapisuje, i
też schodzi jednym commitem. Nie ma inboxa w osobnej bazie „na wiadomości”. Cv, które stosuje
stan z Learning, nie zapisuje „już widziałem” w trzeciej bazie, a kopię w `cv_read` albo w swoim
zapisie osobno. Rozjazd tych dwóch commitów z powrotem daje podwójny skutek albo skutek bez
śladu.

Koszt: odbiorca musi mieć tabelę inboxa w bazie, w której stosuje skutek.
`ApplyIntegrationEventLog` mapuje obie tabele, a usługa, która tylko publikuje, po prostu nie
rejestruje odbiorcy inboxa. Tabela może być w schemacie, nieużywana, albo mapowanie inboxa woła
tylko odbiorca. Wybór w kodzie: `ApplyIntegrationEventLog` zawsze mapuje obie, żeby pięć
kontekstów zapisu miało jeden kształt, a dispatcher outboxa startuje tylko tam, gdzie usługa
publikuje. Inbox receiver startuje tylko tam, gdzie usługa słucha. Pusty dispatcher u usługi,
która nic nie publikuje, tylko budziłby pustą tabelę. Pusty odbiorca u usługi, która nie słucha,
zamieniałby `Ignored` w pętlę bez potrzeby.

### Własne tabele zamiast gotowej szyny

MassTransit od wersji 9 nie ma licencji, która wolno wchodzi do tego repozytorium. Nie
przypinamy starszej linii. Wolverine i CAP (oba MIT) mają gotowy outbox. Przegrywają, bo ten
numer ma pokazać tabelę, wspólną transakcję i pętlę, a transport i tak jest osobnym adapterem w
numerze `15`. Interfejs `IIntegrationEventOutbox` jest mały. Handler usługi zależy od niego, nie
od biblioteki EF. `IEventBus` ma `PublishAsync`. Jedyny wyjątek transportu to
`EventBusPublishException`. Dispatcher nie zna Kafki. W teście dostaje `InMemoryEventBus`. W
numerze `15` dostanie `KafkaEventBus` bez zmiany handlera artykułu.

Koszt: sami piszemy `FOR UPDATE SKIP LOCKED`, licznik prób i trzy wyniki odbioru. Zysk: widać,
kiedy wiersz powstaje, kiedy `ProcessedOn` się ustawia i kiedy `Duplicate` nie woła handlera.
Gotowa szyna schowałaby tę chwilę w konfiguracji i zabrałaby outbox, który ma zostać przy
strumieniu w naszym `DbContext`. `Core` nie referencjonuje `JJDevHub.EventBus` ani
`JJDevHub.IntegrationEventLog`. Kontrakt jest sprawą granicy usług, nie sprawą agregatu. Agregat
zostawia zdarzenie domenowe. Handler w `Application` mapuje je na rekord z `Contracts`, jeśli
ten fakt w ogóle wychodzi na zewnątrz.

eShop pokazuje log integracyjny oparty o EF. Z tego wzorca nie bierzemy `IntegrationEventLogEF`
ani MediatR. Zostają własne encje `OutboxMessage` i `InboxMessage`, własne
`ApplyIntegrationEventLog` i własna pętla. Pakiet `Npgsql.EntityFrameworkCore.PostgreSQL` jest
ten sam, którego używa magazyn z numeru `09`, bo to ta sama baza i ten sam kontekst. Drugi
klient SQL z powrotem rozcina transakcję.

### `EventId` jako tożsamość dostawy

Klucz outboxa i klucz inboxa to `EventId` nadany przy tworzeniu rekordu integracyjnego, nie
pozycja strumienia i nie offset Kafki. Ponowienie wysyłki tego samego wiersza ma ten sam
`EventId`. Republish z numeru `15` czyści `ProcessedOn` i wysyła ten sam identyfikator jeszcze
raz. Inbox zamienia drugą dostawę w `Duplicate`. Nowy `EventId` przy ponowieniu byłby nowym
faktem i drugi raz wysłałby push. Dla `contact.student-inquiry-received.v1` i
`contact.recruiter-inquiry-received.v1` to jest różnica między jednym powiadomieniem a dwoma.
Dla artykułu to jest różnica między jedną kopią u sąsiada a dwoma zastosowaniami tego samego
ogłoszenia.

Koszt: wołający generuje `Guid` raz, przy `AddAsync`, i nie tworzy drugi raz rekordu „bo Kafka
nie odpowiedziała”. Odpowiedź Kafki obsługuje dispatcher. Handler, który przy
`EventBusPublishException` buduje nowe zdarzenie, omija inbox. Wyjątek publikacji w ogóle nie
dochodzi do handlera: dochodzi do procesora, który zwiększa `Attempts` i zostawia `EventId`.
Pozycja strumienia nie nadaje się na klucz dostawy, bo jeden artykuł ma wiele faktów, a
republish nie jest nową pozycją. Offset Kafki nie nadaje się, bo ta sama koperta po ponownej
publikacji dostanie inny offset, a odbiorca ma rozpoznać ten sam fakt.

`IIntegrationEvent` ma `EventId`, `OccurredOn` i `PartitionKey`. Koperta niesie nazwę, klucz i
JSON. Dispatcher wysyła `IntegrationEnvelope`, nie znając typu rekordu. Odbiorca składa typ z
nazwy. Nieznana nazwa nie tworzy wiersza inboxa. Znana nazwa bez handlera też nie. Dopiero
handler, który naprawdę stosuje skutek, wchodzi w transakcję razem z `InboxMessage`. Dzięki temu
`Ignored` nie zapełnia tabeli nazwami, których usługa nie obsługuje, a `Duplicate` nie woła
handlera drugi raz.

## Klasy i ścieżki

Kontrakt jest w `JJDevHub.EventBus`, bez EF i bez Kafki. Tabela i pętla są w
`JJDevHub.IntegrationEventLog`. Rekordy publiczne są w `*.Contracts` usług, które je posiadają.
Test używa `TestHappenedIntegrationEvent` i kontekstu, który woła `ApplyEventStore` oraz
`ApplyIntegrationEventLog`. Artykuł i oba zapytania Contact są w tabeli jako kształt, który
numer usługi wypełni. Ten numer ich nie implementuje w handlerze domenowym.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.EventBus/IIntegrationEvent.cs` | `EventId`, `OccurredOn`, `PartitionKey` |
| `src/shared/JJDevHub.EventBus/IntegrationEnvelope.cs` | koperta: nazwa, klucz, JSON |
| `src/shared/JJDevHub.EventBus/IntegrationEventSerializer.cs` | rekord na kopertę przez rejestr nazw |
| `src/shared/JJDevHub.EventBus/IEventBus.cs` | `PublishAsync` |
| `src/shared/JJDevHub.EventBus/EventBusPublishException.cs` | jedyny wyjątek transportu |
| `src/shared/JJDevHub.EventBus/IIntegrationEventOutbox.cs` | `AddAsync` |
| `src/shared/JJDevHub.EventBus/IIntegrationEventHandler.cs` | `Handle` |
| `src/shared/JJDevHub.EventBus/IIntegrationEventReceiver.cs` | `ReceiveAsync` zwraca `ReceiveOutcome` |
| `src/shared/JJDevHub.EventBus/ReceiveOutcome.cs` | `Handled`, `Duplicate`, `Ignored` |
| `src/shared/JJDevHub.EventBus/InMemoryEventBus.cs` | koperta do odbiorcy w procesie |
| `src/shared/JJDevHub.IntegrationEventLog/OutboxMessage.cs` | wiersz outboxa |
| `src/shared/JJDevHub.IntegrationEventLog/InboxMessage.cs` | wiersz inboxa |
| `src/shared/JJDevHub.IntegrationEventLog/IntegrationEventLogModelBuilderExtensions.cs` | `ApplyIntegrationEventLog` |
| `src/shared/JJDevHub.IntegrationEventLog/IntegrationEventOutbox.cs` | zapis wiersza w otwartej transakcji |
| `src/shared/JJDevHub.IntegrationEventLog/OutboxProcessor.cs` | paczka z `SKIP LOCKED` |
| `src/shared/JJDevHub.IntegrationEventLog/OutboxDispatcher.cs` | pętla w tle |
| `src/shared/JJDevHub.IntegrationEventLog/InboxReceiver.cs` | deduplikacja i handler |
| `src/services/News/News.Contracts/ArticleCreatedIntegrationEvent.cs` | `news.article-created.v1` |
| `src/services/Contact/Contact.Contracts/StudentInquiryReceivedIntegrationEvent.cs` | `contact.student-inquiry-received.v1` |
| `src/services/Contact/Contact.Contracts/RecruiterInquiryReceivedIntegrationEvent.cs` | `contact.recruiter-inquiry-received.v1` |
| `tests/JJDevHub.IntegrationEventLog.Tests/OutboxTests.cs` | jeden commit, dispatcher, inbox |

`InboxTests` leży w tym samym projekcie testu co `OutboxTests`. Osobna klasa, ten sam kontener.
`*.Contracts` nie referencjonuje `*.Core` nadawcy ani odbiorcy. `Core` nie referencjonuje
`JJDevHub.EventBus` ani `JJDevHub.IntegrationEventLog`. Pakiet Npgsql jest tylko w projekcie
logu, bo tylko tam jest EF.

## Plan

### 1. Projekty

```bash
dotnet new classlib -n JJDevHub.EventBus -o src/shared/JJDevHub.EventBus -f net11.0
dotnet new classlib -n JJDevHub.IntegrationEventLog -o src/shared/JJDevHub.IntegrationEventLog -f net11.0
dotnet new xunit -n JJDevHub.IntegrationEventLog.Tests -o tests/JJDevHub.IntegrationEventLog.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.EventBus src/shared/JJDevHub.IntegrationEventLog tests/JJDevHub.IntegrationEventLog.Tests
dotnet add src/shared/JJDevHub.EventBus reference src/shared/JJDevHub.Shared.Kernel
dotnet add src/shared/JJDevHub.IntegrationEventLog reference src/shared/JJDevHub.EventBus
dotnet add src/shared/JJDevHub.IntegrationEventLog package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add tests/JJDevHub.IntegrationEventLog.Tests reference src/shared/JJDevHub.IntegrationEventLog
dotnet add tests/JJDevHub.IntegrationEventLog.Tests reference src/shared/JJDevHub.EventStore.Postgres
dotnet add tests/JJDevHub.IntegrationEventLog.Tests package Testcontainers.PostgreSql
```

Test ma cechę `Category=Integration`. Obraz `postgres:16-alpine`. `JJDevHub.EventBus` nie
referencjonuje EF ani Kafki.

### 2. Rekord i koperta

`IIntegrationEvent` ma `EventId`, `OccurredOn` i `PartitionKey`. `PartitionKey` grupuje
kolejność: dla artykułu identyfikator artykułu, dla zapytania identyfikator zapytania.
Serializer robi `IntegrationEnvelope` z nazwą z rejestru i JSON-em `JsonSerializerDefaults.Web`.
`FromEnvelope` zwraca `null` dla nieznanej nazwy. `null` staje się `Ignored`, nie wyjątkiem.

Rejestr integracyjny buduje się z `typeof(IIntegrationEvent)` i zestawu `Contracts`. Typ bez
`[EventName]` albo dwie nazwy takie same zatrzymują start.

### 3. Zapis outboxa

`IntegrationEventOutbox<TContext>.AddAsync` sprawdza transakcję, serializuje, dodaje
`OutboxMessage` z `ProcessedOn` pustym i `Attempts` równym 0, woła `SaveChangesAsync`. Nie
commituje.

Handler komendy, w skrócie: `AppendAsync`, przy sukcesie `AddAsync`, przy `conflict` wychodzi
bez outboxa. `TransactionBehavior` zatwierdza albo wycofuje.

`*WriteContext.OnModelCreating` woła `ApplyEventStore` i `ApplyIntegrationEventLog`.

### 4. Dispatcher

`OutboxOptions`: `BatchSize` 20, `MaxAttempts` 10, `IdleDelay` 500 ms. SQL z kroku „Dlaczego”
jest w `OutboxProcessor` jako `FromSql`, z tokenem. Po wyjątku publikacji procesor nie bierze
kolejnego wiersza w tej paczce.

`InMemoryEventBus` w teście zapisuje kopertę na listę i, w osobnym teście, rzuca
`EventBusPublishException`.

### 5. Inbox

`InboxOptions.Consumer` ustawia `Api` usługi. `InboxReceiver.ReceiveAsync`:

- `FromEnvelope` daje `null` — `Ignored`, bez transakcji,
- brak handlera — `Ignored`, bez transakcji,
- transakcja, wiersz istnieje — rollback, `Duplicate`,
- handler, wstawienie `InboxMessage`, commit — `Handled`,
- wyjątek handlera — rollback, wyjątek do wołającego.

Dwa równoległe `ReceiveAsync` z tym samym `EventId` i tym samym `Consumer`: jeden `Handled`,
drugi `Duplicate`. Skutek handlera (licznik) równy 1.

### 6. Wycofanie strumienia zabiera outbox

Test otwiera transakcję, woła `AppendAsync` i `AddAsync`, potem `RollbackAsync`. `EventRecords`
jest puste i `OutboxMessages` jest puste. To jest ten jeden commit, którego numer pilnuje.

### Co jest do czego

- `IIntegrationEvent` woła rekord w `*.Contracts` i serializer. Kontrakt między usługami. Bez
  niego na szynę poszedłby `ArticleCreated` z `News.Core`, a sąsiad zależałby od domeny nadawcy.
  Niesie `EventId`, `OccurredOn` i `PartitionKey`.
- `[EventName]` woła rejestr i kolumna `Name`. To nazwa na szynie, nie nazwa CLR. Bez atrybutu
  start hosta staje, albo do kolumny wchodzi nazwa klasy i przeniesienie rekordu psuje
  odbiorców. `news.article-created.v1` może stać też na zdarzeniu domenowym, byle w osobnym
  rejestrze. Duplikat w jednym rejestrze zatrzymuje host.
- `IntegrationEnvelope` woła dispatcher i odbiorca. To, co `PublishAsync` wysyła, nie znając
  typu rekordu. Bez koperty bus musiałby referencjonować `News.Contracts` i `Contact.Contracts`.
  `FromEnvelope` zwraca `null` dla nieznanej nazwy, a `null` staje się `Ignored`.
- `IntegrationEventSerializer` woła `AddAsync` i odbiorcę. Składa JSON
  `JsonSerializerDefaults.Web` i nazwę z rejestru. Bez niego `Payload` `jsonb` nie ma ustalonego
  kształtu, a `EventType` znowu kusi nazwą CLR.
- `IIntegrationEventOutbox` woła handler komendy po udanym `AppendAsync`. Jedyna droga do
  tabeli. Wymaga transakcji strumienia. Bez portu handler albo publikuje od razu na broker, albo
  woła EF. `AddAsync` bez transakcji rzuca `InvalidOperationException` i nie zostawia wiersza.
- `OutboxMessage` woła `AddAsync` i `OutboxProcessor`. Fakt „trzeba wysłać”, trzymany obok
  strumienia. Bez wiersza pad procesu po commicie strumienia gubi `news.article-created.v1`.
  `ProcessedOn` puste oznacza pracę. Po wyczerpaniu `Attempts` wiersz zostaje i loguje się jako
  `Error`.
- `OutboxProcessor` woła dispatcher, raz na przejście. Wysyłka po commicie, z `FOR UPDATE SKIP
  LOCKED` i licznikiem prób. Bez `SKIP LOCKED` drugi pod wysyła tę samą paczkę. Bez przerwania
  paczki po `EventBusPublishException` następna wiadomość tego samego `PartitionKey` wyprzedza
  poprzednią.
- `OutboxDispatcher` woła host jako `BackgroundService`. Bez pętli wiersz zostaje niewysłany na
  zawsze albo wysyłka wraca do handlera HTTP. `BatchSize` 20, `MaxAttempts` 10, `IdleDelay` 500
  ms. Startuje tylko tam, gdzie usługa publikuje.
- `InboxMessage` woła `InboxReceiver` w tej samej transakcji co skutek. Fakt „już zastosowałem”.
  Bez wiersza drugi pod wysyła drugi push zapytania studenta albo rekrutera. Klucz to `EventId`
  i `Consumer`. Wyjątek handlera tego wiersza nie zostawia.
- `ReceiveOutcome` woła transport. Trzy jawne wyniki: `Handled`, `Duplicate`, `Ignored`. Bez
  enumu transport zgaduje po wyjątku, czy to duplikat, i albo ponawia w nieskończoność, albo
  commituje offset za wcześnie. `Duplicate` nie woła handlera. `Ignored` nie jest wyjątkiem.
- `IIntegrationEventHandler<T>` woła odbiorca tylko przy pierwszej dostawie. Bez handlera dla
  znanej nazwy wynik to `Ignored`, bez transakcji. Skutek, który idzie poza tę transakcję, z
  powrotem otwiera podwójny push.
- `InboxReceiver` woła konsumenta, w teście wprost, w numerze `15` po odczycie koperty.
  Deduplikacja i handler. Bez niego unikalny klucz nie jest sprawdzany w tej samej transakcji co
  skutek. `InboxOptions.Consumer` ustawia `Api`. Receiver startuje tylko tam, gdzie usługa
  słucha.
- `InMemoryEventBus` woła test i skład bez brokera. Ten sam `IEventBus`. Bez niego test outboxa
  podnosiłby Kafkę, a numer `14` nie domknąłby commitu. W jednym teście zapisuje kopertę na
  listę. W drugim rzuca `EventBusPublishException`.
- `EventBusPublishException` woła procesor jako jedyny sygnał „spróbuj ponownie”. Bez osobnego
  typu każdy wyjątek albo zwiększa `Attempts`, albo gubi się w `unexpected`. Po tym wyjątku
  paczka się przerywa, `ProcessedOn` zostaje puste.
- `ApplyIntegrationEventLog` woła `OnModelCreating` obok `ApplyEventStore`. Mapuje obie tabele,
  żeby pięć kontekstów zapisu miało jeden kształt. Bez tego outbox nie wchodzi w ten sam model
  co strumień. Dispatcher i odbiorca i tak startują tylko tam, gdzie usługa publikuje albo
  słucha.
- `ArticleCreatedIntegrationEvent`, `StudentInquiryReceivedIntegrationEvent` i
  `RecruiterInquiryReceivedIntegrationEvent` woła numer usługi. Tu jest ich miejsce i nazwa. Bez
  osobnych rekordów student i rekruter zlewają się w jeden kształt, a push nie ma własnego
  `EventId`. `*.Contracts` nie referencjonuje `*.Core`.

## Testy

Klasa `OutboxTests` i klasa `InboxTests` w `tests/JJDevHub.IntegrationEventLog.Tests`. xUnit,
`[Fact]`, `Category=Integration`. Jeden kontener Postgresa. Kontekst testowy woła
`ApplyEventStore` i `ApplyIntegrationEventLog`. Każdy fakt ma jeden powód do padnięcia. Obraz
`postgres:16-alpine`. Zdarzenie testowe nazywa się `test.happened.v1`, żeby nie ciągnąć
`News.Core`. Artykuł i zapytania Contact są kształtem kontraktu, nie układem tego fixture.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Append_and_outbox_commit_together` | transakcja, jeden fakt strumienia, jeden rekord integracyjny | `CommitAsync` | jeden `EventRecord` i jeden `OutboxMessage` z tą samą chwilą commitu |
| `Rollback_removes_stream_and_outbox` | zapis obu w transakcji | `RollbackAsync` | zero wierszy w obu tabelach |
| `Add_without_transaction_throws` | brak `Begin` | `AddAsync` | `InvalidOperationException`, zero wierszy |
| `Name_comes_from_attribute` | `[EventName("test.happened.v1")]` | `AddAsync` i commit | `Name` równe `test.happened.v1` |
| `Dispatcher_marks_processed` | wiersz niewysłany, `InMemoryEventBus` | `RunOnceAsync` | `ProcessedOn` ustawione, bus dostał `EventId` |
| `Publish_failure_increments_attempts` | bus rzuca `EventBusPublishException` | `RunOnceAsync` | `Attempts` równe 1, `ProcessedOn` puste |
| `Second_dispatcher_skips_locked_row` | dwa procesory, jeden wiersz, pierwszy trzyma transakcję | drugi `RunOnceAsync` | drugi zwraca 0 |
| `Receive_handled_writes_inbox` | koperta bez wiersza inboxa | `ReceiveAsync` | `Handled`, jeden wiersz, skutek handlera raz |
| `Receive_duplicate_skips_handler` | wiersz inboxa już jest | `ReceiveAsync` | `Duplicate`, skutek handlera nie rośnie |
| `Receive_unknown_name_is_ignored` | nazwa spoza rejestru | `ReceiveAsync` | `Ignored`, brak wiersza inboxa |
| `Parallel_receive_one_duplicate` | dwa wywołania tego samego `EventId` | równolegle | jeden `Handled`, jeden `Duplicate`, skutek równy 1 |

```bash
dotnet test tests/JJDevHub.IntegrationEventLog.Tests
```

Commit i rollback są osobnymi faktami, bo zielony commit nie dowodzi, że wycofanie zabiera
outbox. Duplikat i odbiór równoległy są osobno, bo jeden wątek nie łapie wyścigu dwóch podów.
Nazwa z atrybutu jest osobno od samego istnienia wiersza. Cecha `Category=Integration` wyłącza
projekt z filtra bez kontenerów. Kafka do tego testu nie wchodzi.

## Zasady

- Outbox i strumień schodzą jednym commitem albo oba znikają. Złamanie zostawia
  `news.article-created.v1` u sąsiada bez faktu w News albo fakt w News bez wiersza do wysłania.
- Inbox i skutek u odbiorcy schodzą jednym commitem. Złamanie wysyła drugi push albo zostawia
  kopię stanu bez śladu „już zastosowałem”.
- Zdarzenie domenowe nie jest argumentem `IEventBus`. Złamanie wciąga sąsiada w `News.Core` albo
  wysyła JSON, którego nikt nie obiecał.
- `Name` pochodzi z `[EventName]`. Złamanie zapisuje nazwę CLR i psuje odbiorców po
  przeniesieniu rekordu.
- `*.Contracts` nie referencjonuje `*.Core` nadawcy ani odbiorcy. Złamanie łączy kontrakt
  publiczny z agregatem i z upcasterem wewnętrznym.
- `AddAsync` bez transakcji jest błędem składu. Złamanie robi cichy `INSERT` i zostawia wiersz,
  którego strumień nie zatwierdził.
- `ReceiveOutcome.Duplicate` nie woła handlera. Złamanie drugi raz wykonuje skutek tego samego
  `EventId` i drugi raz idzie push.
- `Ignored` nie jest wyjątkiem. Złamanie zatrzymuje partycję na nazwie, której ta usługa nie
  obsługuje.
- Wyjątek handlera nie zostawia wiersza inboxa. Złamanie zamienia ponowienie w `Duplicate` i
  skutek nigdy nie dochodzi.
- `Core` nie referencjonuje `JJDevHub.EventBus` ani `JJDevHub.IntegrationEventLog`. Złamanie
  wciąga agregat w kopertę i w EF.
- Redis nie jest używany jako outbox ani inbox. Złamanie kasuje „trzeba wysłać” razem z
  restartem cache.

## Poza zakresem

- Producent i konsument Kafki, DLQ oraz kompaktowanie są w [15-kafka.md](15-kafka.md). Tu
  `IEventBus` w teście jest `InMemoryEventBus`. Republish czyści `ProcessedOn` dopiero tam, tym
  samym `EventId`.
- Projekcja w bazie odczytu nadawcy jest w [12-projekcja.md](12-projekcja.md). Outbox nie buduje
  wiersza listy. Sąsiad jest ostatecznie spójny osobno od widoku nadawcy.
- Cache jest w [13-redis.md](13-redis.md). Nie przenosi kopert i nie zastępuje `InboxMessages`.
- Treść zdarzeń Identity, Learning i Cv dochodzi w numerach tych usług. Tu są nazwy News i
  Contact oraz typ testowy `test.happened.v1`.
- Push FCM na telefon ownera jest w [21-kontakt.md](21-kontakt.md). Inbox, który pilnuje jednego
  pusha, jest tutaj. Kolejność HTTP do FCM dopnie numer Contact.
- Schemat JSON na szynie jako rejestr zewnętrzny nie powstaje. Kontrakt jest rekordem C# i
  testem nazwy.

## Źródła

- [Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html).
  Chris Richardson: jeden commit z danymi biznesowymi, osobna wysyłka. W tym pliku dane to
  `EventRecords`, a wiersz to `OutboxMessages` na tym samym `DbContext`. Nie bierzemy publikacji
  na końcu handlera po `SaveChanges`. Nie bierzemy outboxa w osobnej bazie. Dispatcher idzie po
  commicie i zostawia wiersz przy porażce.
- [Database per service](https://microservices.io/patterns/data/database-per-service). Wiążące
  jest to, że usługa nie czyta bazy sąsiada, żeby dowiedzieć się o fakcie. W tym pliku sąsiad
  dostaje kopertę, a nie connection string. Inbox leży w bazie odbiorcy, w tej, w której stosuje
  skutek, nie w bazie nadawcy. Nie bierzemy wspólnej bazy „na wiadomości” dla pięciu usług.
- [Idempotent
  Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html).
  Hohpe i Woolf: druga dostawa bez drugiego skutku. W tym pliku `Duplicate` przy istniejącym
  `(EventId, Consumer)` nie woła handlera. Nie bierzemy deduplikacji po offsecie Kafki ani po
  `Position` strumienia. Nowy `EventId` przy ponowieniu byłby nowym faktem i drugi raz wysłałby
  push.
- Martin Fowler, [What do you mean by
  “event-driven”?](https://martinfowler.com/articles/201701-event-driven.html). Wiążące jest
  rozróżnienie zdarzenia wewnątrz modelu i powiadomienia na zewnątrz. W tym pliku
  `ArticleCreated` zostaje w `News.Core`, a na zewnątrz idzie rekord z `Contracts`. Nie bierzemy
  wysyłania zdarzenia domenowego na szynę. Nie każdy fakt domenowy ma bliźniaka. Rewizja, która
  zostaje w usłudze, nie woła outboxa.
- Vaughn Vernon, *Implementing Domain-Driven Design*. Wiążące jest zdarzenie aplikacyjne na
  granicy kontekstu, publikowane po zatwierdzeniu stanu. W tym pliku publikacja jest wierszem w
  tej samej transakcji, a wysyłka jest później. Nie bierzemy publikacji w pamięci procesu jako
  jedynego śladu. Pad między commitem a brokerem zostawia `OutboxMessage` z pustym
  `ProcessedOn`.
- Gregory Young, *Versioning in an Event Sourced System*. Wiążąca jest tożsamość faktu
  niezależna od nazwy klasy. W tym pliku `Name` pochodzi z `[EventName]`, na przykład
  `contact.student-inquiry-received.v1`. Nie bierzemy `FullName` ani `AssemblyQualifiedName` na
  szynie. Upcaster zdarzenia domenowego zostaje wewnątrz News i nie zmienia rekordu, który
  sąsiad już zna.
- Eric Evans, *Domain-Driven Design*. Wiążąca jest granica modelu: kontrakt publiczny nie jest
  modelem wewnętrznym. W tym pliku `*.Contracts` nie referencjonuje `*.Core`, a `Core` nie
  referencjonuje `JJDevHub.EventBus`. Nie bierzemy współdzielonej biblioteki domenowej między
  News a Contact. Wspólny jest kernel i atrybut nazwy.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest obraz logu integracyjnego obok zapisu
  usługi. Z tego repozytorium nie bierzemy `IntegrationEventLogEF` ani MediatR. Zostają
  `OutboxMessage`, `InboxMessage`, `ApplyIntegrationEventLog` i `IIntegrationEventOutbox`.
  Handler zależy od portu, nie od biblioteki EF. Transport dołoży numer `15`, bez zmiany tego
  portu.
- [PostgreSQL locking: FOR UPDATE SKIP
  LOCKED](https://www.postgresql.org/docs/16/sql-select.html#SQL-FOR-UPDATE-SHARE). Wiążące są
  rozłączne paczki dwóch dispatcherów. W tym pliku `OutboxProcessor` bierze niewysłane wiersze z
  `Attempts` poniżej `MaxAttempts`, kolejnością `CreatedOn`, z limitem paczki. Nie bierzemy
  blokady, która każe drugiemu dispatcherowi czekać na cały zbiór. `SKIP LOCKED` oddaje mu inne
  wiersze. Test drugiego procesora oczekuje 0, gdy pierwszy trzyma jedyny wiersz.
- [PostgreSQL indexes on expressions and partial
  indexes](https://www.postgresql.org/docs/16/indexes-partial.html). Wiążący jest indeks, który
  obejmuje tylko wiersze spełniające warunek. W tym pliku indeks po `CreatedOn` obejmuje
  `ProcessedOn` puste. Nie bierzemy skanowania całej historii wysłanych wiadomości przy każdym
  budzeniu. Retencji wysłanych wierszy ten numer nie robi. Zostają, żeby dało się zobaczyć, co
  poszło.
- [Using transactions in EF
  Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions). Wiążąca jest jedna
  transakcja `DbContext`, w której stoi strumień i outbox. W tym pliku `AddAsync` nie commituje,
  a brak `CurrentTransaction` rzuca. Nie bierzemy drugiego kontekstu na tym samym stringu.
  `SaveChangesAsync` w otwartej transakcji zapisuje oba ślady. `RollbackAsync` zabiera oba.
  Inbox używa tej samej zasady po stronie odbiorcy.
- [Npgsql EF Core: JSON mapping](https://www.npgsql.org/efcore/mapping/json.html). Wiążący jest
  `Payload` jako `jsonb`. W tym pliku dokument koperty nie dostaje kolumny na każde pole
  `ArticleCreatedIntegrationEvent` ani zapytania Contact. Nie bierzemy typu `json`, który trzyma
  tekst dosłownie. Nazwa faktu i tak jest kolumną `Name`, osobno od dokumentu, bo po niej
  odbiorca wybiera rekord.

## Gotowe gdy

- Rollback po `AppendAsync` i `AddAsync` zostawia obie tabele puste.
- Commit zostawia strumień i wiersz outboxa z nazwą z atrybutu.
- `AddAsync` bez transakcji rzuca.
- Dispatcher oznacza `ProcessedOn` po udanej publikacji i zwiększa `Attempts` po
  `EventBusPublishException`.
- Drugi `ReceiveAsync` tego samego `EventId` zwraca `Duplicate` i nie powtarza skutku.
- Dwa równoległe odbiory kończą się jednym skutkiem.
- `dotnet test tests/JJDevHub.IntegrationEventLog.Tests` kończy się kodem 0.
