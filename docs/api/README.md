# API

Ten folder opisuje usługi JJDevHub: skład, bazy, jądro, strumień i granice między
Identity, News, Learning, Cv i Contact. Plik nie jest numerem wdrożenia i nie ma w nim
kroków do wykonania w repozytorium. Kroki są w plikach `01`–`22`. Mapa przepływów, bez
kroków, jest w [architektura.md](architektura.md). Obraz produktu i kolejność całego
repozytorium są w [README.md](../../README.md) w korzeniu.

Czytanie idzie w jedną stronę: najpierw ten słownik, potem architektura, potem jeden numer.
Numer `01` zakłada, że bramki z [docs/cicd](../cicd/README.md) już wymagają builda i testu.
Sam Aspire zaczyna się w [01-aspire.md](01-aspire.md). Dwa numery nie łączą się w jednym
wdrożeniu. Kto czyta `08`, umie wyrazić strumień w pamięci. Kto czyta `16`, umie postawić
bramę. Usługi domenowe czekają od `17`.

Słownik jest tu po to, żeby późniejszy numer nie wymyślił drugiej nazwy na ten sam byt.
`Article` nie nazywa się `News`. CV nie dostaje klasy `Cv`. Kontakt ma dwa agregaty, nie
jeden agregat o nazwie `Contact`. Kolumna „Numer” mówi, który plik pierwszy raz wprowadza
typ do kodu. Typy domenowe są zapisane wcześniej, zanim powstanie projekt usługi, żeby
granica nazwy była znana już przy jądrze.

## Szablon numeru

Każdy plik `01`–`22` trzyma sekcje w tej kolejności. Indeks i architektura tego szablonu
nie wypełniają, bo nie wdrażają kodu. Czytelnik numeru ma dostać najpierw problem, potem
uzasadnienie wyboru, potem listę plików, potem kroki, potem jeden test i warunki końca.

| Sekcja | Co w niej jest |
| --- | --- |
| wstęp | co powstaje oraz link do numeru poprzedniego i następnego |
| `## Po co` | problem zamykany przez numer i scenariusz, który bez niego się psuje |
| `## Dlaczego ta technologia` | podsekcja na decyzję, prozą: co to jest, jaki problem rozwiązuje, która alternatywa przegrała, jaki koszt zostaje |
| `## Klasy i ścieżki` | tabela plik → odpowiedzialność |
| `## Plan` | kroki `### 1.` i na końcu `### Co jest do czego` |
| `## Testy` | jeden fakt xUnit, jeden powód padnięcia, tabela arrange / act / assert, komenda `dotnet test` |
| `## Zasady` | reguły, których kod numeru nie łamie, jako lista |
| `## Poza zakresem` | link do innego numeru, jako lista |
| `## Źródła` | lista: link albo książka, potem dwa do czterech zdań — co jest wiążące, której decyzji dotyczy, czego ze źródła nie bierzemy |
| `## Gotowe gdy` | warunki końca numeru, jako lista |

`## Dlaczego ta technologia` tłumaczy wybór prozą, bez etykiet „co to jest” i „przegrało”.
Czym jest decyzja w tym repozytorium, jaki problem zamyka, która alternatywa odpadła i jaki
koszt zostaje: to jest treść podsekcji `###`, zapisana zdaniami. `## Plan` mówi, co utworzyć,
i nie powtarza uzasadnienia. `### Co jest do czego` mówi, kto woła typ i po co ten typ
istnieje w działającym procesie. Jeden numer na jedno podejście. Test numeru ma jeden powód
do padnięcia.

`## Zasady`, `## Poza zakresem` i `## Gotowe gdy` są listami, bo czytelnik odhacza je na
końcu numeru. `## Źródła` nie są tabelą. Dłuższy opis nie mieści się w kolumnie, a właśnie
opis mówi, którą decyzję adres podpiera i czego z tej strony nie kopiujemy. Książka bez
stabilnego adresu rozdziału wchodzi tak samo: autor, tytuł, potem te same dwa do czterech
zdań.

## Słownik nazw

Nazwa w tabeli jest stała. Późniejszy numer nie wprowadza drugiej nazwy na ten sam byt.
Agregat jest granicą spójności, nie nazwą systemu. Stąd `Article` w News i brak klasy `Cv`
w Cv. Jądro nie zna Identity, News, Learning, Cv ani Contact. Gdyby znało, test reguły
tytułu ciągnąłby konto, a zmiana `Skill` zmieniałaby kontrakt jądra.

| Nazwa | Projekt | Numer | Znaczenie |
| --- | --- | --- | --- |
| `Result<T>` | `JJDevHub.Shared.Kernel` | 05 | sukces z wartością albo `ResultError` |
| `Result` | `JJDevHub.Shared.Kernel` | 05 | sukces bez wartości albo `ResultError` |
| `ResultError` | `JJDevHub.Shared.Kernel` | 05 | rodzaj i stabilny kod |
| `ResultErrorKind` | `JJDevHub.Shared.Kernel` | 05 | `None`, `Invalid`, `NotFound`, `Conflict`, `Forbidden` |
| `Entity` | `JJDevHub.Shared.Kernel` | 05 | tożsamość `Guid` |
| `ValueObject` | `JJDevHub.Shared.Kernel` | 05 | równość po składowych |
| `TimeProvider` | BCL, wołany z jądra | 05 | zegar; test podstawia `FakeTimeProvider` |
| `IDomainEvent` | `JJDevHub.Shared.Kernel` | 06 | fakt, który już zaszedł |
| `EventNameAttribute` | `JJDevHub.Shared.Kernel` | 06 | nazwa `segment.fakt.vN` |
| `AggregateRoot` | `JJDevHub.Shared.Kernel` | 07 | wersja, reguły, `Apply`, `Replay` |
| `IBusinessRule` | `JJDevHub.Shared.Kernel` | 07 | warunek, który zwraca kod `Invalid` |
| `IEventStore` | `JJDevHub.EventStore` | 08 | dopisanie i odczyt strumienia |
| `InMemoryEventStore` | `JJDevHub.EventStore` | 08 | implementacja w pamięci procesu |
| `StreamKey` | `JJDevHub.EventStore` | 08 | klucz strumienia, nieparsowany przez port |
| `StoredEvent` | `JJDevHub.EventStore` | 08 | koperta: strumień, wersja, pozycja, zdarzenie |
| `AppendResult` | `JJDevHub.EventStore` | 08 | wersja strumienia i globalna pozycja po dopisaniu |
| `StreamSlice` | `JJDevHub.EventStore` | 08 | wersja i lista zdarzeń jednego strumienia |
| `ISecretReader` | `JJDevHub.Secrets` | 04 | odczyt sekretu po ścieżce logicznej |
| `OpenBaoSecretReader` | `JJDevHub.Secrets.OpenBao` | 04 | adapter HTTP do KV v2 |
| `ICommand<TResult>` | `JJDevHub.Cqrs` | 10 | komenda; handler nie otwiera bazy odczytu |
| `IQuery<TResult>` | `JJDevHub.Cqrs` | 10 | zapytanie; handler nie woła magazynu zdarzeń |
| `ICommandHandler<TCommand,TResult>` | `JJDevHub.Cqrs` | 10 | jeden handler na komendę |
| `IQueryHandler<TQuery,TResult>` | `JJDevHub.Cqrs` | 10 | jeden handler na zapytanie |
| `Account` | `Identity.Core` | 17 | konto, strumień |
| `Invite` | `Identity.Core` | 17 | zaproszenie, strumień |
| `Article` | `News.Core` | 18 | notatka, strumień |
| `Category` | `Learning.Core` | 19 | kategoria katalogu |
| `Technology` | `Learning.Core` | 19 | technologia, strumień, slug niezmienny |
| `Course` | `Learning.Core` | 19 | kurs, strumień |
| `Lesson` | `Learning.Core` | 19 | lekcja, strumień |
| `StudentProgress` | `Learning.Core` | 19 | postęp studenta, zwykły stan, bez strumienia |
| `Profile` | `Cv.Core` | 20 | sekcja CV, strumień |
| `Position` | `Cv.Core` | 20 | stanowisko, strumień |
| `Project` | `Cv.Core` | 20 | projekt, strumień |
| `Education` | `Cv.Core` | 20 | edukacja, strumień |
| `Activity` | `Cv.Core` | 20 | aktywność, strumień |
| `Skill` | `Cv.Core` | 20 | umiejętność, strumień, trzyma slug technologii |
| `Language` | `Cv.Core` | 20 | język w CV, strumień |
| `StudentInquiry` | `Contact.Core` | 21 | zapytanie studenta, tylko JWT `student` |
| `RecruiterInquiry` | `Contact.Core` | 21 | zapytanie z formularza publicznego |
| `owner` | rola w JWT | 17 | właściciel treści i dwóch skrzynek |
| `student` | rola w JWT | 17 | czytelnik lekcji i autor `StudentInquiry` |

W namespace usługi nie ma klasy o nazwie segmentu. Namespace News nie zawiera klasy `News`,
bo inaczej kompilator myli typ z przestrzenią nazw. Namespace Cv nie zawiera klasy `Cv`.
Kontakt ma dwa agregaty, `StudentInquiry` i `RecruiterInquiry`, bo formularz publiczny i
kanał studenta mają inne uprawnienie, inny fakt na szynie i inną skrzynkę na telefonie.

Przykład kodu wewnątrz lekcji jest częścią treści Markdown. Nie ma własnego strumienia i nie
ma osobnej klasy-agregatu. `StudentProgress` zapisuje się wierszem w `learning_write` obok
strumieni, ale nie przez `IEventStore`. Postęp jest prywatnym stanem studenta. Publiczne CV
właściciela nie jest dziennikiem tego postępu.

Strumień mają tam, gdzie historia jest produktem: artykuł, konto, zaproszenie, technologia,
kurs, lekcja, każda sekcja CV, oba zapytania. Kategoria katalogu jest wierszem, bo jest półką,
a nie materiałem, którego kolejne brzmienie trzeba odtworzyć. Slug technologii po publikacji
się nie zmienia. Zmiana nazwy wyświetlanej nie zmienia adresu, którym Cv i News wskazują
katalog.

## Nazwy zdarzeń i tematów

Nazwa na szynie, w outboxie i w tabeli strumienia pochodzi z `[EventName]`. Nazwa klasy CLR
nie wchodzi do bazy ani do Kafki. Strumień żyje dłużej niż układ projektu. Przeniesienie
klasy albo zmiana namespace'u nie może zepsuć wierszy już zapisanych. Kontrakt jest krótkim
łańcuchem, nie `AssemblyQualifiedName`.

| Nazwa | Gdzie | Numer |
| --- | --- | --- |
| `news.article-created.v1` | kształt zdarzenia w teście jądra, produkcja w News | 06, 18 |
| `contact.student-inquiry-received.v1` | push kanału studentów | 21 |
| `contact.recruiter-inquiry-received.v1` | push kanału rekruterów | 21 |
| `learning.integration` | temat kompaktowany, ostatni stan technologii i kursu | 15, 19, 20 |

Gramatyka faktu to `segment.fakt-z-myślnikami.vN`, małymi literami. Pierwszy segment to
usługa, która fakt posiada: `news`, `identity`, `learning`, `cv`, `contact`. Środkowy jest
w stronie dokonanej, bo zdarzenie już zaszło: `article-created`, nie `create-article`.
Ostatni segment to `v` i liczba. Zmiana znaczenia dostaje `v2`. `v1` zostaje czytelne dla
wierszy już zapisanych.

Temat integracyjny usługi należy do tej usługi. Zdarzenie domenowe zostaje w procesie i w
strumieniu bazy zapisu. Na szynę wychodzi rekord z projektu `Contracts`, złożony ręcznie w
`Application`. Pełny URI w stylu CloudEvents nie jest drugą nazwą obok tej gramatyki. Dwie
gramatyki rozjechałyby klucz kompaktowania. `learning.integration` niesie ostatni stan sluga,
nie całą historię pośrednich nazw. `contact.integration` niesie dwa różne fakty i dwa kanały
push.

Kody błędów mają własną gramatykę: `segment.element.powod`, małymi literami, bez spacji.
Rodzaj `ResultErrorKind` mówi, jaki wynik HTTP powstanie na brzegu. Sam kod zostaje w polu
`type` dokumentu `ProblemDetails`. Pole `title` jest tłumaczone z `Accept-Language`. Jądro
nie trzyma zdań po polsku ani po angielsku. Test porównuje kod, nie zdanie. Klient
angielski i klient polski rozgałęziają logikę po tym samym `type`.

| Kod | Rodzaj | Kto go stawia |
| --- | --- | --- |
| `probe.name.blank` | `Invalid` | agregat próbny w teście numeru 07 |
| `stream.version.conflict` | `Conflict` | `IEventStore` przy złej oczekiwanej wersji |
| `stream.key.blank` | `Invalid` | `IEventStore`, gdy klucz strumienia jest pusty |
| `stream.events.empty` | `Invalid` | `IEventStore`, gdy lista do dopisania jest pusta |
| `secret.path.missing` | `NotFound` | `ISecretReader`, gdy ścieżki nie ma w OpenBao |
| `secret.path.forbidden` | `Forbidden` | `ISecretReader`, gdy polityka odmawia |
| `article.title.blank` | `Invalid` | `Article`, numer 18 |
| `inquiry.student.forbidden` | `Forbidden` | `StudentInquiry` bez roli `student` |

`probe.name.blank` jest kodem agregatu próbnego, nie produktem. Służy do tego, żeby mechanika
`Check` miała stabilny łańcuch, zanim powstanie `Article`. Kody strumienia stawia port
magazynu, nie agregat. Kody sekretu stawia `ISecretReader`. Brzeg HTTP tłumaczy rodzaj na
status. Samo jądro statusu HTTP nie zna.

## Dziesięć baz

Jeden serwer PostgreSQL w AppHost, nazwa zasobu `postgres`, dziesięć baz. Usługa dostaje
wyłącznie swoje dwa connection stringi. To jest baza na usługę: sąsiad nie otwiera cudzego
zapisu ani cudzego odczytu. Handler komendy nie otwiera bazy odczytu. Handler zapytania nie
woła magazynu zdarzeń. Dwa schematy w jednej bazie odpadły, bo ten sam ciąg połączenia
nadal sięga obu schematów i handler łatwo woła złą tabelę.

| Baza | Usługa | Co w niej leży po domknięciu usług |
| --- | --- | --- |
| `identity_write` | Identity | strumień `Account`, strumień `Invite`, outbox |
| `identity_read` | Identity | skrót konta i zaproszenia, indeks pod odczyt |
| `news_write` | News | strumień `Article`, outbox |
| `news_read` | News | lista i treść notatki, slug i język |
| `learning_write` | Learning | strumienie treści, wiersz `StudentProgress`, outbox |
| `learning_read` | Learning | katalog, lekcja, postęp, indeks kategorii i języka |
| `cv_write` | Cv | strumienie sekcji CV, outbox |
| `cv_read` | Cv | złożony widok strony i kopia sluga z `learning.integration` |
| `contact_write` | Contact | `StudentInquiry`, `RecruiterInquiry`, token urządzenia, outbox |
| `contact_read` | Contact | dwie listy dla roli `owner` |

Identity trzyma historię konta i zaproszenia w zapisie. Odczyt pokazuje skrót, bez materiału,
którym da się podpisać token albo odtworzyć hasło. News trzyma strumień artykułu i projekcję
pod slug oraz język. Learning trzyma strumienie treści i osobny wiersz postępu. Cv składa
stronę wyłącznie ze swojego odczytu, a nazwę technologii bierze z kopii ostatniego stanu, nie
z `learning_read`. Contact trzyma dwa strumienie zapytań, token urządzenia właściciela i dwie
listy, które student i rekruter widzą inaczej.

Numery [02-postgres.md](02-postgres.md) i [03-odczyt.md](03-odczyt.md) tworzą puste bazy i
kontrakt indeksu. Tabele strumienia dochodzą w [09-persistence.md](09-persistence.md).
Wiersze projekcji dochodzą w [12-projekcja.md](12-projekcja.md). Redis nie jest jedenastą
bazą. Redis jest cachem, a klucz zaczyna się od nazwy usługi, więc `news` nie nadpisuje
klucza `cv`.

Odczyt jest wierszem albo dokumentem JSONB w PostgreSQL. Indeks pokrywa równość `slug`,
`category` i `language`. MongoDB nie jest modelem odczytu. OpenSearch nie jest modelem
odczytu. Drugi silnik nie upraszcza zapytania, które i tak trafia w slug. Utrata Redisa
spowalnia `GET`. Dane zostają w PostgreSQL.

## Pakiety i licencje

Pakiet wolno dodać, gdy licencja jest otwarta i darmowa także produkcyjnie: MIT, Apache-2.0,
BSD-2-Clause, BSD-3-Clause, PostgreSQL. Wersja ląduje w `Directory.Packages.props`. Projekt
używa `PackageReference` bez własnego numeru wersji. OpenBao jest serwerem na MPL-2.0, nie
pakietem NuGet w jądrze. HashiCorp Vault odpada przez BSL, nie przez brak funkcji sekretów.

| Pakiet albo serwer | Licencja | Numer | Rola |
| --- | --- | --- | --- |
| `Aspire.AppHost.Sdk` | MIT | 01 | skład, wersja linii 13 z projektu AppHost |
| `Aspire.Hosting.Redis` | MIT | 01 | zasób o nazwie `cache` |
| `OpenTelemetry.Extensions.Hosting` | Apache-2.0 | 01 | rejestracja logów, śladów i metryk |
| `OpenTelemetry.Exporter.OpenTelemetryProtocol` | Apache-2.0 | 01 | eksport OTLP, gdy jest endpoint |
| `OpenTelemetry.Instrumentation.AspNetCore` | Apache-2.0 | 01 | ślad żądania HTTP |
| `OpenTelemetry.Instrumentation.Http` | Apache-2.0 | 01 | ślad `HttpClient` |
| `OpenTelemetry.Instrumentation.Runtime` | Apache-2.0 | 01 | metryki runtime |
| `Microsoft.Extensions.Http.Resilience` | MIT | 01 | standardowy handler odporności |
| `Microsoft.Extensions.ServiceDiscovery` | MIT | 01 | nazwy usług ze składu |
| `Microsoft.Extensions.Diagnostics.HealthChecks` | MIT | 01 | `/health` i `/alive` |
| `xunit` | Apache-2.0 | 01 | `[Fact]` |
| `xunit.runner.visualstudio` | Apache-2.0 | 01 | adapter runnera |
| `Microsoft.NET.Test.Sdk` | MIT | 01 | host testu |
| `Aspire.Hosting.PostgreSQL` | MIT | 02 | jeden zasób `postgres` |
| `Npgsql` | PostgreSQL | 02 | połączenie w teście łączności |
| `Testcontainers` | MIT | 02 | cykl życia kontenera |
| `Testcontainers.PostgreSql` | MIT | 02 | obraz `postgres:16-alpine` |
| `Microsoft.Extensions.TimeProvider.Testing` | MIT | 05 | `FakeTimeProvider` |
| `Polly` | BSD-3-Clause | 01 | zależność przechodnia handlera odporności |
| FluentValidation | Apache-2.0 | 11 | walidacja brzegu, wynik zamieniany na `Result` |
| `Microsoft.EntityFrameworkCore` | MIT | 09 | mapowanie w Persistence |
| `Npgsql.EntityFrameworkCore.PostgreSQL` | PostgreSQL | 09 | dostawca zapisu i odczytu |
| `Confluent.Kafka` | Apache-2.0 | 15 | producent i konsument KRaft |
| `Testcontainers.Kafka` | MIT | 15 | broker w teście integracyjnym |
| `Yarp.ReverseProxy` | MIT | 16 | brama i `GET /versions` |
| `Aspire.StackExchange.Redis` | MIT | 13 | klient cache, prefiks nazwy usługi |
| Markdig | BSD-2-Clause | 18 | Markdown notatki i lekcji |
| HtmlSanitizer | MIT | 18 | sanitacja HTML przed odpowiedzią |
| NBomber | Apache-2.0 | 22 | test z cechą `Category=Performance` |
| OpenBao, obraz `openbao/openbao` | MPL-2.0 | 04 | serwer sekretów, tryb dev w AppHost |

Mediator, magazyn zdarzeń i outbox są kodem tego repozytorium. Powstają w
[10-cqrs.md](10-cqrs.md), [08-strumien.md](08-strumien.md), [09-persistence.md](09-persistence.md)
i [14-outbox.md](14-outbox.md). Są tematem numeru, nie luką po odrzuconym pakiecie. Widać w
nich, jak zamyka się typ generyczny, jak rośnie pozycja strumienia i jak jeden commit trzyma
fakt oraz wiersz outboxa.

| Odrzucone | Powód | Zamiast tego |
| --- | --- | --- |
| MediatR 13 i nowsze | licencja produkcyjna nie jest wolna | `JJDevHub.Cqrs` |
| AutoMapper 15 i nowsze | licencja produkcyjna nie jest wolna | mapowanie ręczne w Application |
| MassTransit 9 i nowsze | licencja produkcyjna nie jest wolna | `JJDevHub.EventBus.Kafka` |
| Duende IdentityServer | licencja produkcyjna nie jest wolna | usługa Identity i własny JWT |
| QuestPDF | próg licencji społecznościowej | ten ciąg nie generuje PDF |
| HashiCorp Vault | licencja BSL | OpenBao |
| Keycloak | drugi produkt kont i ról | `Account`, `Invite`, role `owner` i `student` |
| MongoDB | serwer na SSPL i drugi silnik | projekcja w PostgreSQL |
| OpenSearch | silnik wyszukiwania, strona czyta slug | btree po `slug`, `category`, `language` |
| RabbitMQ | brak kompaktowanego tematu pod ostatni stan technologii | Kafka KRaft |

Starszej wersji MediatR, AutoMapper albo MassTransit nie przypina się po to, żeby ominąć
zmianę licencji. Taka pinia zostawia projekt na linii bez poprawek. Pakiet spoza tabeli
dochodzi najpierw tutaj, z licencją i numerem, a potem w `Directory.Packages.props`.
`PackageReference` w csproj nie niesie własnego numeru wersji.

## Projekty testowe

Piramida jest jedna. Numer dokłada test do właściwego piętra. Test wydajnościowy nie wchodzi
do numerów `01`–`08`. Jest wymieniony tutaj, bo cecha `Category=Performance` ma być ta sama,
gdy dojdzie [22-testy.md](22-testy.md). Bramka `develop` nie ciągnie kontenerów. Bramka
wydania ciągnie integrację. Obciążenie nie blokuje zwykłego pull requestu.

| Projekt | Piętro | Numer | Cecha |
| --- | --- | --- | --- |
| `tests/JJDevHub.ServiceDefaults.Tests` | jednostkowy | 01 | brak |
| `tests/JJDevHub.Integration.Tests` | integracyjny | 02, 03, 04 | `Category=Integration` |
| `tests/JJDevHub.Shared.Kernel.Tests` | jednostkowy | 05, 06, 07 | brak |
| `tests/JJDevHub.EventStore.Tests` | jednostkowy | 08 | brak |
| `tests/JJDevHub.Performance.Tests` | wydajnościowy | 22 | `Category=Performance` |

Runner to xUnit. Kontener PostgreSQL w teście używa obrazu `postgres:16-alpine`. Filtr
lokalny bez kontenerów i bez NBombera:

```text
dotnet test --filter "Category!=Integration&Category!=Performance"
```

Test integracyjny numeru uruchamia się filtrem `FullyQualifiedName` podanym w sekcji testów
tego numeru. Jeden fakt pada z jednego powodu. Nazwa metody mówi, co jest prawdą, gdy test
przechodzi, na przykład `Health_endpoint_returns_ok_outside_development`. Padnięcie z
timeoutu kontenera w teście, który miał sprawdzić status HTTP, znaczy, że test sprawdza za
dużo.

## Ścieżki

| Ścieżka | Co tam leży |
| --- | --- |
| `JJDevHub.AppHost` | skład Aspire: Redis `cache`, PostgreSQL, OpenBao dev |
| `JJDevHub.ServiceDefaults` | telemetria, health, odkrywanie usług, handler odporności |
| `src/shared/JJDevHub.Shared.Kernel` | `Result`, kody, `Entity`, `ValueObject`, kontrakt zdarzenia, agregat |
| `src/shared/JJDevHub.Secrets` | port `ISecretReader` |
| `src/shared/JJDevHub.Secrets.OpenBao` | adapter HTTP i stała obrazu |
| `src/shared/JJDevHub.Cqrs` | mediator i zachowania |
| `src/shared/JJDevHub.EventStore` | port magazynu i pamięć |
| `src/shared/JJDevHub.EventStore.Postgres` | strumień w bazie zapisu |
| `src/shared/JJDevHub.Projections` | checkpoint, worker, SQL kontraktu odczytu |
| `src/shared/JJDevHub.EventBus` | koperta, port outbox, port inbox |
| `src/shared/JJDevHub.IntegrationEventLog` | tabele outbox i inbox |
| `src/shared/JJDevHub.EventBus.Kafka` | adapter Kafki |
| `src/services/<Nazwa>/<Nazwa>.Api` | host HTTP, skład portów |
| `src/services/<Nazwa>/<Nazwa>.Application` | komendy, zapytania, porty |
| `src/services/<Nazwa>/<Nazwa>.Core` | agregaty usługi |
| `src/services/<Nazwa>/<Nazwa>.Persistence` | konteksty zapisu i odczytu tej usługi |
| `src/services/<Nazwa>/<Nazwa>.Infrastructure` | Redis, Kafka, OpenBao, FCM |
| `src/services/<Nazwa>/<Nazwa>.Contracts` | rekordy zdarzeń integracyjnych |
| `src/gateway/JJDevHub.Gateway` | YARP, klucz publiczny JWT, `GET /versions` |
| `db/read/001_read_document.sql` | tabela i indeksy baz odczytu |
| `Directory.Packages.props` | wersje pakietów |
| `aspire.config.json` | ścieżka do `JJDevHub.AppHost` |
| `docs/api` | numery `01`–`22` i ten indeks |

`<Nazwa>` przyjmuje wartości `Identity`, `News`, `Learning`, `Cv`, `Contact`. `Core`
referencjonuje wyłącznie jądro i nie zna MediatR, Entity Framework, Kafki ani ASP.NET.
`Application` zna `Core` i własne porty. `Api` jest jedynym miejscem z `Program.cs` usługi
i jedynym miejscem, które wiąże port z implementacją. `Persistence` i `Infrastructure`
implementują porty. `Contracts` wolno referencjonować z innej usługi. Reszty sąsiada
referencjonować nie wolno. Test jednostkowy `Core` nie podnosi kontenera.

Framework docelowy projektów to `net11.0`, tak jak w `JJDevHub.AppHost`. Jeden publiczny typ
na plik. Klasa implementacji jest `sealed`. Rekord niesie dane. Metoda `async` przyjmuje
`CancellationToken`. Te reguły obowiązują od pierwszego projektu współdzielonego, nie od
pierwszej usługi.

Biblioteki współdzielone nie znają `Article` ani `Skill`. Dzięki temu projekcja, outbox i
adapter Kafki służą pięciu usługom bez kopiowania pętli. Usługa dokłada własne agregaty w
`Core` i własne rekordy integracyjne w `Contracts`.

## CQRS i błędy

Komenda ładuje strumień z bazy zapisu, robi `Replay`, wywołuje metodę agregatu i dopisuje
zdarzenia. Outbox idzie w tej samej transakcji co strumień, więc na szynie nie pojawia się
fakt, którego nie ma w historii. Zapytanie czyta projekcję z bazy odczytu i może użyć Redis.
Po `POST` klient może przez chwilę dostać `404` na `GET`, bo projekcja jest asynchroniczna,
i wtedy ponawia odczyt. To okno jest stanem przejściowym, nie błędem komendy.

Odtwarzanie strumienia na ścieżce `GET` nie występuje. Lista notatek i strona CV są
zapytaniem pod indeks, nie złożeniem historii. Handler komendy, który zajrzałby do `*_read`,
uzależniłby regułę domeny od projekcji, która może być w tyle. Handler zapytania, który
wołałby `IEventStore`, omijałby indeks i czytałby całą historię na każdym odczycie.

Oczekiwany błąd to `Result<T>`. Wyjątek zostaje dla awarii IO i dla błędu składu hosta. Oba
kończą się jako `ProblemDetails` w języku z nagłówka `Accept-Language`. Walidacja
FluentValidation nie rzuca wyjątku do klienta. Zamienia się na `Result` z rodzajem `Invalid`.
Pusty tytuł, brak wiersza projekcji, konflikt wersji i brak roli są rodzajami `Invalid`,
`NotFound`, `Conflict` i `Forbidden`. Pole `type` zostaje kodem. Pole `title` jest
przetłumaczone. Na start są kultury `pl` i `en`.

Zapis ze znacznikiem `ETag` wymaga `If-Match`. Brak nagłówka to odpowiedź `428`. Nieaktualny
znacznik to `412`. Treść niewidoczna dla czytelnika to `404`, żeby osobny status nie zdradzał,
że wiersz istnieje. Te kody HTTP ustawia brzeg `Api`, nie `Core`. Dwa okna z tym samym
artykułem nie nadpisują się po cichu.

Wersja strumienia i globalna pozycja to dwa liczniki. Pozycja rośnie przez wszystkie strumienie
usługi i jest kursorem projekcji. Wersja rośnie tylko w swoim strumieniu i jest kursorem
optymistycznej współbieżności jednego agregatu. Konflikt wersji zwraca `Result` z kodem
`stream.version.conflict`. Komenda nie rzuca wyjątku tylko dlatego, że ktoś zapisał ten sam
strumień chwilę wcześniej.

## Sekrety

W gicie nie ma wartości sekretu, tokenu, hasła ani connection stringa z hasłem produkcyjnym.
`appsettings.json` i `appsettings.Development.json` trzymają puste wartości tam, gdzie w ogóle
jest klucz konfiguracji. Token deweloperski OpenBao siedzi w user secrets projektu
`JJDevHub.AppHost`. Numer, który czyta sekret, przechodzi przez `ISecretReader`. Szczegóły są
w [04-openbao.md](04-openbao.md).

Klucz prywatny JWT czyta tylko Identity. Brama i sąsiednie usługi biorą klucz publiczny z
JWKS. Klucz konta usługi do pusha leży w OpenBao i jest czytany w chwili wysyłki. Brak
OpenBao w tej chwili jest awarią IO: wyjątek i ponowienie, bez cichego przejścia na pusty
klucz. Na maszynie klucz rozszczelnienia jest w vTPM. Ten indeks nie opisuje kroków stawiania
maszyny.

Log ze śladu nie zapisuje ciała, które mogłoby być tokenem, treścią notatki albo treścią
zapytania Contact. Odpowiedź `/health` nie zawiera connection stringa ani ciała wyjątku.

## Kolejność 01–22

Numery API idą po kolei. Nie łączy się dwóch numerów w jednym wdrożeniu. W całym
repozytorium przed `01` są dokumenty cicd `01`–`07`, a po `22` są frontend i maszyna. Ta
lista jest wyłącznie kolejką API.

1. [01-aspire.md](01-aspire.md) — AppHost, `JJDevHub.ServiceDefaults`, Redis `cache`, health, haki OpenTelemetry, dashboard.
2. [02-postgres.md](02-postgres.md) — jeden serwer i pięć baz zapisu, sama łączność.
3. [03-odczyt.md](03-odczyt.md) — pięć baz odczytu i indeksy `slug`, `category`, `language`.
4. [04-openbao.md](04-openbao.md) — port sekretów, OpenBao dev, puste appsettings, token w user secrets.
5. [05-kernel.md](05-kernel.md) — `Result`, `ResultError`, `Entity`, `ValueObject`, `TimeProvider`.
6. [06-zdarzenie.md](06-zdarzenie.md) — `IDomainEvent`, `[EventName]`, kształt `ArticleCreatedDomainEvent`.
7. [07-agregat.md](07-agregat.md) — `AggregateRoot`, `IBusinessRule`, `Apply`, `Replay`.
8. [08-strumien.md](08-strumien.md) — `IEventStore`, `InMemoryEventStore`, konflikt wersji, pozycja globalna.
9. [09-persistence.md](09-persistence.md) — ten sam port na PostgreSQL, w bazie zapisu.
10. [10-cqrs.md](10-cqrs.md) — mediator własny, rozdział komendy i zapytania.
11. [11-walidacja.md](11-walidacja.md) — `ProblemDetails` i zasoby `pl` oraz `en`.
12. [12-projekcja.md](12-projekcja.md) — worker, który wypełnia `read_document`.
13. [13-redis.md](13-redis.md) — cache projekcji, prefiks nazwy usługi.
14. [14-outbox.md](14-outbox.md) — outbox w transakcji strumienia i inbox.
15. [15-kafka.md](15-kafka.md) — Kafka KRaft, temat `learning.integration` kompaktowany.
16. [16-gateway.md](16-gateway.md) — YARP i `GET /versions`.
17. [17-identity.md](17-identity.md) — `Account`, `Invite`, role `owner` i `student`.
18. [18-news.md](18-news.md) — agregat `Article`.
19. [19-learning.md](19-learning.md) — kategoria, technologia, kurs, lekcja, postęp jako stan.
20. [20-cv.md](20-cv.md) — sekcje CV i slug technologii.
21. [21-kontakt.md](21-kontakt.md) — dwa zapytania i dwa pushe.
22. [22-testy.md](22-testy.md) — domknięcie piramidy, w tym NBomber.

Po numerach `01`–`04` jest rama: jedna komenda podnosi dashboard, Redis nazywa się `cache`,
pięć baz zapisu i pięć baz odczytu istnieją na jednym serwerze, a sekret da się przeczytać
przez port. Agregatu jeszcze nie ma. Po numerze `08` jądro umie wyrazić sukces, błąd,
zdarzenie, agregat i strumień w pamięci. PostgreSQL dla strumienia, mediator, projekcja,
cache, szyna, brama i pięć usług czekają na własne numery.

Numery `09`–`16` kładą ten sam port na bazę zapisu, rozdzielają komendę od zapytania,
tłumaczą błąd na język klienta, wypełniają widok, dokładają cache, outbox, Kafkę i jedyne
wejście HTTP. Po `16` da się przejść żądanie przez bramę, ale treść strony jeszcze nie żyje
w usługach. Numery `17`–`21` wstawiają pięć modeli. `22` spina piramidę z bramkami i nie
dokłada endpointu produktu.

Przepływ między tymi kawałkami, jeszcze bez kolejności prac, jest w
[architektura.md](architektura.md). Wersja komponentu jest osobna: `identity`, `news`,
`learning`, `cv`, `contact`, `gateway`, `web`, `mobile`. Zmiana w `JJDevHub.Shared.Kernel`
podbija każdą usługę, która go referencjonuje. Tag jednej usługi nie przebudowuje pozostałych
obrazów. `GET /versions` pokazuje numery działających usług obok numeru klienta.

## Źródła

- Eric Evans, *Domain-Driven Design*. Słownik nazw jest językiem tego systemu: agregat to
  granica spójności, nie nazwa produktu. Stąd `Article` w News, brak klasy `Cv` i brak klasy
  `Contact`. Nie bierzemy stąd jednego modelu na całą firmę. Pięć usług ma pięć modeli, a
  jądro nie zna ich nazw.
- [eShop](https://github.com/dotnet/eshop). Wzór granic usług, osobnej bazy, Aspire, outboxa
  i bramy YARP. Układ projektu usługi i wspólny `ServiceDefaults` są stąd. Nie bierzemy stąd
  MediatR, AutoMappera ani paczki `IntegrationEventLogEF`. Mediator, magazyn zdarzeń i outbox
  są kodem tego repozytorium, bo mechanizm jest treścią numerów.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Chris Richardson: usługa nie czyta cudzej bazy. W tym indeksie znaczy to dziesięć baz na
  jednym PostgreSQL, po dwie na usługę, a nie dziesięć serwerów i nie dwa schematy jednego
  connection stringa. Osobny serwer na usługę odpadł, bo strumień i outbox mają jeden commit.
- [CQRS](https://learn.microsoft.com/azure/architecture/patterns/cqrs). Osobny model zapisu i
  odczytu. Komenda nie otwiera `*_read`, zapytanie nie woła `IEventStore`. Spójność odczytu
  jest ostateczna: zaraz po `POST` klient może dostać `404` i ponawia `GET`. Nie bierzemy
  stąd drugiego silnika dokumentów pod widok.
- [PostgreSQL licence](https://www.postgresql.org/about/licence/). Licencja silnika i pakietów
  Npgsql, które wolno wziąć produkcyjnie. Wiersz w tabeli pakietów bez licencji otwartej i
  darmowej także produkcyjnie nie wchodzi do `Directory.Packages.props`.
- [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/). Licencja OpenBao.
  Serwer sekretów jest dozwolony. Nie jest pakietem NuGet w jądrze i nie zastępuje usługi
  Identity. Konta i role zostają przy `Account` oraz `Invite`.
- [HashiCorp license FAQ](https://www.hashicorp.com/license-faq). Business Source License
  produktu Vault. To powód odrzucenia, nie instrukcja wdrożenia. Zamiast Vaulta stoi OpenBao.
  Starszej linii produktu z nową licencją nie przypinamy po to, żeby ominąć zmianę.
- Greg Young, *Versioning in an Event Sourced System*. Nazwa zdarzenia i kształt ładunku są
  kontraktem na lata. Stąd `[EventName]` i gramatyka `segment.fakt.vN`. Zmiana znaczenia
  dostaje `v2`. Nie bierzemy stąd osobnego rejestru schematów poza atrybutem i rekordem w
  `Contracts`.
- [Event-driven architecture](https://martinfowler.com/articles/201701-event-driven.html).
  Martin Fowler: fakt ma jawną nazwę, niezależną od klasy. Nazwa CLR nie wchodzi do bazy ani
  do Kafki. Zdarzenie domenowe zostaje w procesie. Na szynę wychodzi osobny rekord. Pełny
  URI CloudEvents nie staje się drugą nazwą obok krótkiego łańcucha.
- [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457). `ProblemDetails`: pole `type` zostaje
  kodem błędu, pole `title` jest zdaniem. Język zdania bierze się z `Accept-Language`, nie z
  jądra. Nie bierzemy stąd dowolnego URI w `type`. U nas `type` jest kodem
  `segment.element.powod`.
