# 09. Magazyn zdarzeń w Postgresie

Ten numer kładzie strumień na PostgreSQL, w bazie zapisu tej usługi, która agregat posiada.
Biblioteka `JJDevHub.EventStore.Postgres` daje encje, mapowanie i `PostgresEventStore`. Kontrakt
`IEventStore`, `InMemoryEventStore` oraz reguły `AppendAsync`, `LoadAsync` i `ReadAllAsync` są w
[08-strumien.md](08-strumien.md). Transakcję wokół zapisu otworzy mediator z
[10-cqrs.md](10-cqrs.md). Bez tego numeru reguły wersji żyją tylko w pamięci procesu: restart
czyści artykuł, konto, zaproszenie, technologię, kurs, lekcję, sekcje CV i oba zapytania
Contact, choć dla produktu właśnie ta historia jest stanem.

Pięć baz zapisu stoi na jednym serwerze: `identity_write`, `news_write`, `learning_write`,
`cv_write`, `contact_write`. Każda dostaje własne tabele `EventStreams` i `EventRecords`. Usługa
nie dostaje connection stringa do bazy sąsiada. News nie otwiera `learning_write`, Contact nie
czyta strumienia notatek, a Cv nie sięga do bazy Learning po to, żeby złożyć stronę. Biblioteka
nie ma własnego `DbContext` i nie ma własnego schematu do wdrożenia. Kontekst usługi woła
`ApplyEventStore` i jest właścicielem historii schematu. Pięć historii w `__EFMigrationsHistory`
idzie obok siebie, bo pięć baz nie dzieli katalogu migracji.

Scenariusz, który bez magazynu się rozpada, wygląda tak. Owner publikuje artykuł.
`ArticleCreated` dostaje nazwę `news.article-created.v1` i trafia do `Payload` jako `jsonb`,
często z polem sluga. Proces News pada zanim ktokolwiek zdąży przeczytać stronę. Po starcie
handler ma złożyć agregat z powrotem przez `LoadAsync`. Gdy strumień został tylko w
`InMemoryEventStore`, lista jest pusta, slug nie istnieje, a publiczny odczyt nie ma z czego
zbudować widoku. Ten sam przebieg dotyczy `StudentInquiryReceived`: zapytanie studenta jest
faktem, który ma przeżyć restart, a nie zmienną w handlerze.

Drugi przebieg psuje się przy dwóch oknach. Oba odczytały strumień artykułu w wersji 4. Jedno
zapisuje nowy tytuł, drugie inną poprawkę tego samego agregatu. Bez sprawdzenia `Version` drugi
zapis dopisuje fakt tak, jakby pierwszy nie istniał. Z tym numerem przegrywa ten, kto trzyma
starą wersję: dostaje `Result` z kodem `conflict` i nie powstaje drugi wiersz. Trzeci przebieg
psuje projekcję. Sekwencja Postgresa nadaje `Position` przy `INSERT`, nie przy commicie. Bez
`pg_advisory_xact_lock` na `EventStoreLock.Key` czytelnik „wszystko po 9” zobaczy 11, zapisze
checkpoint 11 i nigdy nie wczyta 10. Slug albo tytuł z transakcji, która dostała mniejszą
pozycję, a zatwierdziła się później, znika z widoku na stałe.

Zapis i późniejszy outbox z [14-outbox.md](14-outbox.md) mają wejść w jeden commit. Osobny
serwer zdarzeń dałby log, który nie umie zatwierdzić się razem z wierszem `OutboxMessages`.
Zostają dwa commity albo protokół rozproszony, a na jednej maszynie to koszt bez zysku. Tabela w
tej samej bazie co przyszły outbox rozwiązuje to bez rozproszonego commitu. `Core` usługi zna
tylko `JJDevHub.Shared.Kernel`. Nie zna Entity Framework, Postgresa ani tej biblioteki. Port
`IEventStore` zostaje w `JJDevHub.EventStore`. Implementacja Postgresa jest adapterem, który
`Persistence` usługi spina w `Program.cs` projektu `Api`.

Oczekiwany konflikt wersji wraca jako `Result`, kodem `conflict`. Wyjątek zostaje dla awarii IO:
brak połączenia, zerwany timeout, błąd dysku. Taki wyjątek nie jest tu tłumaczony na
`ProblemDetails`. To zrobi brzeg HTTP w [11-walidacja.md](11-walidacja.md). Pusta lista zdarzeń
też nie jest awarią dysku: `AppendAsync` zwraca `Invalid` i nie otwiera transakcji, więc w
teście widać kod `invalid` i brak wiersza `EventStreams`.

## Po co

Magazyn w pamięci z numeru `08` sprawdza reguły strumienia w teście jednostkowym i ginie razem z
procesem. Artykuł, konto, zaproszenie, technologia, kurs, lekcja, sekcje CV oraz oba zapytania
Contact mają historię, która jest produktem. Ta historia musi przeżyć restart procesu i musi dać
się czytać po globalnej pozycji, bo projekcja z [12-projekcja.md](12-projekcja.md) idzie właśnie
po tej pozycji. `LoadAsync` składa jeden strumień dla handlera komendy. `ReadAllAsync` oddaje
fakty całej bazy od `Position`, dla workera tej samej usługi. Jeden licznik nie zastępuje
drugiego: wersja mówi, czy ten agregat ktoś zdążył zmienić, pozycja mówi, jak daleko doszedł
odczyt.

Gdyby magazyn zdarzeń był osobnym serwerem, commit strumienia i commit wiadomości integracyjnej
nie miałyby wspólnej transakcji. Publikacja artykułu mogłaby dojść do sąsiada, a potem wycofać
się w News, albo zostać w News i nie zostawić śladu do wysłania. Tabela `EventRecords` obok
przyszłych `OutboxMessages` jest po to, żeby `TransactionBehavior` z numeru `10` miał jeden
`DbContext` i jedno `CommitAsync`. `AppendAsync` umie w takiej transakcji uczestniczyć: widzi
`CurrentTransaction` i sam jej nie zatwierdza. Test `Append_joins_outer_transaction` robi
`BeginTransactionAsync`, `AppendAsync`, `RollbackAsync` i sprawdza, że `LoadAsync` zwraca wersję
0.

`Core` nie może dostać tej biblioteki w referencjach. Agregat woła własne `Apply` na zdarzeniu,
a nie `DbContext`. Gdyby domena znała `PostgresEventStore`, test reguły tytułu wymagałby
kontenera `postgres:16-alpine` i connection stringa. Port zostaje w `JJDevHub.EventStore`,
adapter w `JJDevHub.EventStore.Postgres`, a skład w `Api`. Handler w `Application` prosi o
`IEventStore` i nie wie, czy pod spodem stoi pamięć z testu jednostkowego, czy
`NewsWriteContext`. Repozytorium agregatu nie rozróżnia tych dwóch po typie portu.

Oczekiwany błąd biznesowy i awaria infrastruktury idą różnymi drogami, bo klient ma dostać inny
status. Dwa okna z tym samym artykułem to `conflict`, później na brzegu HTTP stanie się to
`412`, gdy handler odda kod warunku, albo zostanie `409`, gdy `conflict` oznacza slug zajęty
przez inny agregat. Te mapy statusów nie powstają tutaj. Tutaj powstaje `Result`, który da się
rozróżnić od wyjątku IO. Brak połączenia, zerwany timeout i błąd dysku lecą dalej. Middleware z
numeru `11` zamieni je na `ProblemDetails`. Magazyn, który połknie `IOException` i zwróci
`conflict`, nauczy klient ponawiać zapis, który wcale nie był kolizją wersji.

Jest jeszcze powód diagnostyczny. `Payload` trzyma dokument, a `EventType` trzyma nazwę z
`[EventName]`. Da się zapytać `Payload->>'slug'` i zobaczyć, który fakt ustawił slug, bez
odtwarzania całego agregatu w debuggerze. Baza nie sprawdza schematu JSON. Zły kształt wychodzi
przy `LoadAsync`, gdy serializer i rejestr nazw z numerów `06` i `08` nie umieją złożyć
zdarzenia. To jest celowo późny błąd kontraktu, nie `CHECK` w tabeli, bo kształtów jest tyle,
ile faktów: `ArticleCreated` nie ma tych pól co `StudentInquiryReceived`.

## Dlaczego ta technologia

### PostgreSQL jako magazyn zdarzeń

Magazyn zdarzeń w tym numerze to dwie tabele dopisywane w bazie, którą usługa i tak ma.
PostgreSQL daje transakcję, unikalny indeks i `jsonb`. Serwer jest jeden, bazy są osobne, więc
pięć usług nie dzieli tabel, a nadal nie dokładamy drugiego silnika. `identity_write` trzyma
strumienie kont i zaproszeń, `news_write` strumienie artykułów, `learning_write` technologie,
kursy i lekcje, `cv_write` sekcje CV, `contact_write` oba zapytania Contact. Wspólny jest tylko
proces serwera i biblioteka mapowania. Wiersze sąsiadów nie leżą w jednym `EventRecords`.

Osobny serwer zdarzeń, czyli osobny proces tylko pod log, przegrywa, bo zdarzenie domenowe i
wiersz outboxa muszą zatwierdzić się razem. Drugi proces oznaczałby dwa commity albo protokół
rozproszony. Na maszynie z jednego AppHost nie ma quorum, które taki protokół miałby czego
bronić. MongoDB przegrywa z tego samego powodu i z licencji: projekcje i tak są wierszami albo
`jsonb` w Postgresie, a drugi silnik nic tu nie upraszcza. SQL Server przegrywa, bo na maszynie
i w AppHost jest już PostgreSQL, a drugi dialekt to drugi zestaw pakietów i testów.
Testcontainers i tak podnosi `postgres:16-alpine`. Drugi obraz nie wnosi indeksu, którego
Postgres nie umie.

Koszt jest w kształcie danych i w narzędziach. Zdarzenie żyje w `jsonb`, nie w kolumnach, więc
diagnostyka ad hoc to zapytanie po kluczu JSON, nie po tabeli z polami. Przy ruchu jednej osoby
piszącej treść ten koszt jest akceptowalny: nie optymalizujemy magazynu pod równoległe zapisy
tysięcy autorów. Pakiet dostawcy to `Npgsql.EntityFrameworkCore.PostgreSQL`, licencja
PostgreSQL. Entity Framework Core jest na MIT. Oba wpisują się do tabeli pakietów w
[README.md](README.md) przy numerze `09`, a wersja ląduje w `Directory.Packages.props`.
Biblioteka nie dokłada własnego silnika i nie dokłada klienta, który otwierałby drugą bazę „na
zdarzenia”.

Artykuł pokazuje granicę. Slug, tytuł i kolejne poprawki są faktami w `news_write`. Zapytanie
studenta jest innym kształtem w `contact_write`. Nic w tym numerze nie łączy ich złączeniem SQL.
Gdy Cv będzie potrzebowało katalogu z Learning, dostanie kopię zdarzeniem integracyjnym, nie
connection stringiem do `learning_write`. Ten numer tylko pilnuje, żeby string sąsiada w ogóle
nie istniał w konfiguracji usługi.

### Kolumna `jsonb` na treść faktu

Zdarzenia mają różne kształty. `ArticleCreated` nie ma tych pól co `StudentInquiryReceived`.
Osobna kolumna na każde pole wymusiłaby zmianę schematu przy każdym nowym fakcie i związałaby
bazę zapisu z klasą CLR. Dodanie pola do artykułu, na przykład sluga, stałoby się migracją
`news_write`, a dodanie pola do zapytania studenta migracją `contact_write`, i obie migracje
znałyby nazwy właściwości C#. Strumień ma być dopisywany. Nowa wersja kontraktu dostaje nową
nazwę w `[EventName]`, nie nową kolumnę.

`jsonb` trzyma dokument binarnie. Da się go filtrować w diagnostyce (`Payload->>'slug'`) i
założyć indeks GIN, gdy kiedyś będzie potrzebny. Ten numer indeksu GIN nie zakłada: ścieżka HTTP
nie szuka artykułu przez JSON w bazie zapisu. Szuka go projekcja w bazie odczytu. Filtr po slugu
zostaje narzędziem człowieka, który ogląda strumień, gdy widok i historia się rozjeżdżają. Typ
`json` przegrywa, bo trzyma tekst dosłownie, łącznie z kolejnością kluczy i ze spacjami, a i tak
nie czytamy go jako kanonicznego napisu. Kolumny relacyjne przegrywają, bo zbiór pól nie jest
wspólny. Dwa fakty w jednym `EventRecords` nie mają wspólnego `NOT NULL` poza kopertą: pozycja,
strumień, wersja, identyfikator, nazwa, czas.

Koszt: baza nie sprawdza schematu JSON. Kontrakt sprawdza serializer i rejestr nazw z numerów
`06` i `08`. Zły kształt wychodzi przy odczycie strumienia, nie przy `INSERT`. Zapis ze złą
treścią da się zatwierdzić, a `LoadAsync` wybuchnie później. Dlatego rejestr nazw i test
atrybutu są częścią kontraktu, a nie ozdobą. `EventType` w wierszu to nazwa z atrybutu
`[EventName]`, na przykład `news.article-created.v1`. Nazwa klasy CLR, `FullName` i
`AssemblyQualifiedName` do kolumny nie wchodzą. Przeniesienie rekordu do innego namespace nie
może zmienić historii już zapisanej. Test `Append_stores_attribute_name` pilnuje napisu
`test.happened.v1`.

Serializer dostaje zdarzenie przy `AppendAsync` i oddaje parę nazwy oraz `Payload`. Przy
`LoadAsync` idzie w drugą stronę: `EventType` wybiera typ z rejestru, `Payload` wypełnia pola.
Pole sluga w JSON-ie jest wtedy zwykłym polem zdarzenia, nie kolumną `EventRecords`.
`DateOccurred` jest obok, jako `timestamptz`, bo czas faktu jest kopertą, a nie treścią, która
zmienia się między `ArticleCreated` a `StudentInquiryReceived`.

### EF Core w kontekście usługi

Dapper (Apache-2.0) jest dozwolony i dałby ręczny `INSERT`. Czysty Npgsql też. Wygrywa EF Core,
bo schemat, transakcja `DbContext` i późniejszy outbox są jednym modelem. `SaveChangesAsync` w
otwartej transakcji zapisuje strumień, a w [14-outbox.md](14-outbox.md) także wiersz outboxa,
bez drugiego połączenia. Dwa klienty SQL w jednym hoście oznaczałyby dwa sposoby na tę samą
transakcję: jeden musiałby oddać drugiemu połączenie albo zaakceptować dwa commity. Przy kilku
wstawkach na artykuł narzut ORM jest mniejszy niż ten rozjazd.

Ścieżka zapisu to kilka wstawek w jednej transakcji: ewentualnie nowy `EventStream`, potem po
jednym `EventRecord` na fakt, na końcu aktualizacja `Version`. Tam, gdzie EF nie ma
odpowiednika, wołamy SQL: `pg_advisory_xact_lock` przez `ExecuteSqlAsync`. Reszta zostaje w
modelu, bo unikalny indeks `(StreamId, Version)`, unikalny `EventId` i typ `jsonb` mają być
widoczne w migracji, a nie w napisie sklejonym w repozytorium. Kontekst trzeba trzymać jako
scoped i nie wolno go wołać równolegle z dwóch wątków. Handler i tak jest jeden na żądanie.
Równoległe `SaveChangesAsync` na tym samym `NewsWriteContext` jest błędem użycia, nie trybem
pracy.

Koszt modelu jest taki, że zmiana tabeli idzie przez migrację projektu usługi, a nie przez
`CREATE TABLE` w bibliotece. To jest świadome: biblioteka nie wie, kiedy News jest gotowy na
nową kolumnę, a Identity może być wdrożone innym tagiem. `EnsureCreatedAsync` zostaje w teście
biblioteki, na `TestWriteContext`. Produkcyjna baza dostaje `dotnet ef migrations`, historię w
`__EFMigrationsHistory` i fabrykę design-time, która czyta `ConnectionStrings__{usługa}-write`.
Brak zmiennej kończy fabrykę wyjątkiem. Hasło nie stoi w pliku w repozytorium.

Gdy `DbUpdateException` niesie wewnętrzny `PostgresException` ze `SqlState` równym `23505`,
magazyn zwraca `conflict`. To jest naruszenie unikalności wersji albo `EventId`, czyli
oczekiwany wyścig, nie awaria dysku. Inny błąd bazy nie jest łapany. Po `conflict` w cudzej
transakcji wołający wycofuje transakcję, bo Postgres oznacza ją jako przerwaną. Zrobi to
`TransactionBehavior` w numerze `10`. Sam magazyn, gdy otworzył transakcję we własnym zakresie,
wycofuje ją przy wyjątku i zatwierdza po sukcesie. Dzięki temu test biblioteki nie potrzebuje
mediatora.

### Biblioteka bez własnego `DbContext`

`JJDevHub.EventStore.Postgres` nie wystawia `DbContext` i nie trzyma katalogu schematu. Gdyby
trzymała, każda usługa dziedziczyłaby cudzą historię schematu albo otwierała drugi kontekst na
tym samym połączeniu. Outbox nie wszedłby w ten sam `SaveChanges`. Dwa konteksty na jednym
connection stringu wyglądają niewinnie, dopóki jeden nie zatwierdzi strumienia, a drugi nie
wycofa outboxa. Wspólny model w kontekście usługi jest jedynym sposobem, żeby artykuł i wiersz
„trzeba wysłać” zniknęły razem.

Mapowanie jest metodą `ApplyEventStore(this ModelBuilder)`. Kontekst usługi woła ją z
`OnModelCreating`. Pięć kontekstów, pięć baz, jeden kształt tabel. `IdentityWriteContext`,
`NewsWriteContext`, `LearningWriteContext`, `CvWriteContext` i `ContactWriteContext` różnią się
typem i bazą, nie kształtem `EventStreams`. Test biblioteki używa `TestWriteContext`, który robi
tylko to wywołanie. Dzięki temu test nie ciągnie Identity ani News. Dowód mapowania nie czeka,
aż powstanie agregat artykułu.

Koszt: każda usługa musi pamiętać o tym wywołaniu. Kontekst bez `ApplyEventStore` skompiluje się
i utworzy pustą bazę. Pierwszy `AppendAsync` dostanie wtedy wyjątek IO, bo tabel nie ma, i łatwo
wziąć go za awarię Postgresa, a nie za brak jednej linii w `OnModelCreating`. Test schematu
usługi, gdy powstanie w jej numerze, sprawdza obecność obu tabel. Ten numer sprawdza to na
`TestWriteContext` przez `Database.EnsureCreatedAsync`. Osobny indeks na `Position` nie
dochodzi: `Position` jest kluczem, a odczyt projekcji i tak robi `ORDER BY` po tym kluczu.

Biblioteka nie skanuje zestawów Identity, News, Learning, Cv ani Contact. Rejestr nazw i
`IEventSerializer` rejestruje usługa, bo zestawy zdarzeń są w jej `Core`.
`AddDbContext<TContext>` zostaje w `Api`, bo connection string zna skład hosta.
`AddPostgresEventStore<TContext>` tylko wiąże `IEventStore` z `PostgresEventStore<TContext>` w
zakresie żądania. Sama rejestracja nie otwiera bazy sąsiada i nie tworzy schematu.

### Blokada doradcza i globalna `Position`

`Position` jest kolumną `bigint` z `GENERATED ALWAYS AS IDENTITY`. Sekwencja Postgresa nadaje
numer przy `INSERT`, nie przy commicie. Transakcja A może dostać 10, transakcja B dostać 11 i
zatwierdzić się pierwsza. Projekcja, która przeczyta „wszystko po 9”, zobaczy 11, zapisze
checkpoint 11 i nigdy nie wczyta 10. Dla artykułu oznacza to zgubioną zmianę tytułu albo sluga.
Dla zapytania studenta oznacza to zgubione `StudentInquiryReceived`, jeśli dwa zapisy w
`contact_write` wyścigną się w ten sam sposób. Dziura nie boli przy jednym połączeniu. Boli, gdy
dwa żądania trzymają dwie transakcje.

`pg_advisory_xact_lock` na stały klucz `EventStoreLock.Key` serializuje dopisywanie w jednej
bazie. Numer pozycji rośnie w kolejności commitów. Blokada puszczana jest na końcu transakcji,
także gdy transakcję otworzył mediator, nie sam magazyn. `ReadAllAsync` może wtedy iść po
`Position > afterPosition` bez dziur. Klucz jest stały w kodzie, nie liczony ze sluga i nie
liczony z nazwy usługi. W jednej bazie i tak jest jedna kolejka zapisów. Osobny klucz na
strumień puściłby równoległe dopisania i z powrotem rozjechał sekwencję wobec commitów.

Blokada jest per połączenie, czyli per baza. Zapis do `news_write` nie czeka na zapis do
`identity_write`. Pięć usług nie staje w jednej kolejce. Publikacja artykułu nie stoi za
przyjęciem zapytania Contact. To jest ważne, bo blokada jest celowo gruba: obejmuje każdy
`AppendAsync` w tej bazie, nie tylko jeden strumień. Dwa artykuły zapisywane naraz też wchodzą
jeden za drugim. Przy jednym autorze treści to tani porządek. Równoległość między usługami
zostaje.

Poziom `SERIALIZABLE` też by wykrył anomalię, ale kończyłby się ponawianiem całych transakcji.
Blokada po prostu czeka. Ponawianie przy `SERIALIZABLE` musiałoby objąć handler, walidację i
przyszły outbox, a klient dostałby albo opóźnienie, albo błąd, który nie jest `conflict`.
Czekanie na zamek doradczy kończy się albo sukcesem, albo prawdziwym konfliktem wersji, albo
wyjątkiem IO. `ExecuteSqlAsync` dostaje `CancellationToken`, więc odwołane żądanie nie zostawia
zamka dłużej niż transakcję. Zamek i tak puszcza się przy końcu transakcji, także przy
wycofaniu.

`ReadAllAsync(afterPosition, maxCount, cancellationToken)` czyta `Position > afterPosition`,
`OrderBy(Position)`, `Take(maxCount)`, `AsNoTracking`. Zwraca `StoredEvent` z `Position`, żeby
projekcja mogła zapisać checkpoint. Nie filtruje po usłudze: w tej bazie i tak są tylko jej
strumienie. Filtr po nazwie usługi zakładałby wspólne tabele, a każda baza trzyma tylko
swoje. Magazyn nie zna checkpointu projekcji: oddaje paczkę od `afterPosition` i kończy na
`maxCount`.

### Optymistyczna współbieżność na `Version`

Dwa żądania mogą wczytać strumień w wersji 4 i oba próbować dopisać wersję 5. Wygrywa jedno.
Drugie dostaje `Result` z kodem `conflict`, bez nowego wiersza. Dla artykułu jest to typowy
układ dwóch kart w przeglądarce. Owner w jednej poprawia tytuł, w drugiej slug. Oba okna
widziały wersję 4. Pierwsze dopisuje wersję 5. Drugie, jeśli wyśle oczekiwaną wersję 4, nie ma
prawa zbudować konkurencyjnej wersji 5. Test `Stale_append_returns_conflict` i
`Stale_append_does_not_add_row` trzymają tę parę: kod `conflict` oraz nadal jeden `EventRecord`.

Sprawdzenie jest podwójne. Najpierw odczyt `EventStreams.Version` w tej samej transakcji, po
wzięciu blokady. Potem unikalny indeks `(StreamId, Version)` na `EventRecords`. Gdy dwa
połączenia mimo to wejdą w wyścig, Postgres zwróci `23505`, a magazyn zamieni
`DbUpdateException` na `conflict`. Inny błąd bazy leci dalej jako wyjątek IO. Sam odczyt wersji
bez indeksu przegrałby przy oknie między sprawdzeniem a `INSERT`. Sam indeks bez odczytu też
zwróciłby `23505`, ale dopiero po próbie zapisu i z transakcją oznaczoną jako przerwana. Odczyt
po zamku oddaje `conflict` zanim powstanie drugi fakt, a indeks łapie resztę.

Wersja oczekiwana `0` oznacza nowy strumień. Brak wiersza przy oczekiwanej wersji innej niż 0 to
też `conflict`: ktoś usunął kontekst albo wołający ma zły identyfikator. Samo usuwanie wierszy
zdarzeń nie istnieje. Strumień jest dopisywany. Brak wiersza i `expectedVersion == 0` dodaje
`EventStream`. Każde zdarzenie dostaje `EventRecord` z `Version = expectedVersion + i + 1`.
`Version` strumienia rośnie o liczbę zdarzeń. Jeden `AppendAsync` może więc dopisać kilka faktów
i przesunąć wersję o więcej niż jeden. Dwa równoległe utworzenia tego samego strumienia kończą
się jednym sukcesem i jednym `conflict`, co sprawdza `Parallel_appends_one_wins`.

`EventId` jest drugim unikalnym kluczem. Drugi zapis tego samego identyfikatora też kończy się
`conflict`, nawet gdy wersja wygląda na świeżą. Dzięki temu powtórzone żądanie nie dokleja kopii
`ArticleCreated`. Koszt: wołający musi znać wersję, którą przeczytał. Przy HTTP ta liczba
wyjdzie na zewnątrz jako `ETag` w [11-walidacja.md](11-walidacja.md). Zapis bez wcześniejszego
odczytu nie ma uczciwej oczekiwanej wersji. `IdentityGuid` na `EventStream` jest osobno: to
opcjonalny napis właściciela z tokenu, nie klucz obcy do `identity_write` i nie wersja. Test
`Append_stores_identity_guid` zapisuje `abc` i odczytuje `abc`.

## Klasy i ścieżki

Biblioteka współdzielona nie wie, czym jest artykuł. Wie, jak dopisać wiersz i jak go odczytać.
Usługa wie, jak nazywa się jej baza i jakie zdarzenia wolno złożyć. Test wie tylko tyle, żeby
podnieść `postgres:16-alpine` i zawołać `ApplyEventStore`. Ten podział jest w tabeli: projekt
biblioteki, pięć kontekstów zapisu, które powstaną razem z usługami, oraz test, który nie
referencjonuje ich `Core`.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.EventStore.Postgres/JJDevHub.EventStore.Postgres.csproj` | referencja do `JJDevHub.EventStore`, pakiet `Npgsql.EntityFrameworkCore.PostgreSQL` |
| `src/shared/JJDevHub.EventStore.Postgres/EventStream.cs` | wiersz strumienia: `StreamId`, `Version`, `IdentityGuid` |
| `src/shared/JJDevHub.EventStore.Postgres/EventRecord.cs` | wiersz faktu: `Position`, `StreamId`, `Version`, `EventId`, `EventType`, `Payload`, `DateOccurred` |
| `src/shared/JJDevHub.EventStore.Postgres/EventStoreLock.cs` | stały klucz `pg_advisory_xact_lock` |
| `src/shared/JJDevHub.EventStore.Postgres/EventStoreModelBuilderExtensions.cs` | `ApplyEventStore` |
| `src/shared/JJDevHub.EventStore.Postgres/PostgresEventStore.cs` | `IEventStore` na `DbContext` usługi |
| `src/shared/JJDevHub.EventStore.Postgres/EventStoreServiceCollectionExtensions.cs` | `AddPostgresEventStore<TContext>` |
| `src/services/Identity/Identity.Persistence/IdentityWriteContext.cs` | `identity_write`, woła `ApplyEventStore` |
| `src/services/News/News.Persistence/NewsWriteContext.cs` | `news_write`, woła `ApplyEventStore` |
| `src/services/Learning/Learning.Persistence/LearningWriteContext.cs` | `learning_write`, woła `ApplyEventStore` |
| `src/services/Cv/Cv.Persistence/CvWriteContext.cs` | `cv_write`, woła `ApplyEventStore` |
| `src/services/Contact/Contact.Persistence/ContactWriteContext.cs` | `contact_write`, woła `ApplyEventStore` |
| `tests/JJDevHub.EventStore.Postgres.Tests/PostgresEventStoreTests.cs` | magazyn na `TestWriteContext` i Testcontainers |
| `tests/JJDevHub.EventStore.Postgres.Tests/TestWriteContext.cs` | kontekst testu, tylko `ApplyEventStore` |

Projekt `*.Persistence` usługi powstaje w numerze tej usługi. Od pierwszej klasy kontekstu ma
wywołanie `ApplyEventStore`. Ten numer dostarcza bibliotekę i test, który udowadnia zachowanie
na prawdziwym Postgresie. `Api` składa `AddPostgresEventStore<TContext>` w `Program.cs`. `Core`
tej biblioteki nie referencjonuje. `Application` widzi `IEventStore` z projektu portu, nie klasę
`PostgresEventStore`. Dzięki temu test komendy może podstawić pamięć, a test tej biblioteki może
podstawić `TestWriteContext` bez domeny artykułu.

`IEventSerializer` nie ma tu własnego pliku. Magazyn dostaje go w konstruktorze, a rejestruje go
usługa razem z nazwami z jej `Core`. Zdarzenie testowe z `[EventName("test.happened.v1")]` leży
w zestawie testu, nie w `Core` usługi. Kolumna `EventType` ma dowieść, że do bazy wchodzi
atrybut, a nie nazwa klasy z tego zestawu.

## Plan

### 1. Projekt biblioteki i testu

```bash
dotnet new classlib -n JJDevHub.EventStore.Postgres -o src/shared/JJDevHub.EventStore.Postgres -f net11.0
dotnet new xunit -n JJDevHub.EventStore.Postgres.Tests -o tests/JJDevHub.EventStore.Postgres.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.EventStore.Postgres tests/JJDevHub.EventStore.Postgres.Tests
dotnet add src/shared/JJDevHub.EventStore.Postgres reference src/shared/JJDevHub.EventStore
dotnet add src/shared/JJDevHub.EventStore.Postgres package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add tests/JJDevHub.EventStore.Postgres.Tests reference src/shared/JJDevHub.EventStore.Postgres
dotnet add tests/JJDevHub.EventStore.Postgres.Tests package Testcontainers.PostgreSql
dotnet add tests/JJDevHub.EventStore.Postgres.Tests package Microsoft.EntityFrameworkCore
```

Wersje wchodzą do `Directory.Packages.props`. Test dostaje cechę `Category=Integration`. Obraz
kontenera to `postgres:16-alpine`.

### 2. Encje i mapowanie

`EventStream` jest `sealed`. Klucz `StreamId` to `string` do 200 znaków. `Version` to `int`.
`IdentityGuid` to `string?` i trzyma właściciela strumienia, gdy agregat go ma. Nie jest kluczem
obcym do Identity: to napis z tokenu, nie odczyt cudzej bazy.

`EventRecord` jest `sealed`:

- `Position` (`long`) — klucz, `UseIdentityAlwaysColumn()`,
- `StreamId` i `Version` — unikalny indeks złożony,
- `EventId` (`Guid`) — unikalny indeks,
- `EventType` (`string`, do 200 znaków) — nazwa z `[EventName]`,
- `Payload` (`string`) — `HasColumnType("jsonb")`,
- `DateOccurred` (`DateTimeOffset`) — kolumna `timestamptz`.

`ApplyEventStore` mapuje tabele `EventStreams` i `EventRecords`. Nie dodaje innych tabel. Osobny
indeks na `Position` nie dochodzi: `Position` jest kluczem, a odczyt projekcji i tak robi `ORDER
BY` po tym kluczu.

### 3. `PostgresEventStore`

`PostgresEventStore<TContext>` gdzie `TContext : DbContext` dostaje `TContext` i
`IEventSerializer` primary constructorem. Jest `sealed` i implementuje `IEventStore`.

`AppendAsync(streamId, expectedVersion, events, identityGuid, cancellationToken)`:

- pusta lista zdarzeń zwraca `Invalid` i nie otwiera transakcji,
- gdy `Database.CurrentTransaction` jest `null`, metoda otwiera własną transakcję i zatwierdza
  ją po sukcesie,
- gdy transakcja już jest, metoda w niej uczestniczy i jej nie zatwierdza,
- `SELECT pg_advisory_xact_lock({EventStoreLock.Key})`,
- odczyt `EventStream` po `StreamId`,
- brak wiersza przy `expectedVersion != 0` zwraca `conflict`,
- wiersz o innej `Version` zwraca `conflict`,
- brak wiersza i `expectedVersion == 0` dodaje `EventStream`,
- każde zdarzenie dostaje `EventRecord` z `Version = expectedVersion + i + 1`, `EventType` i
  `Payload` z `Serialize`,
- `Version` strumienia rośnie o liczbę zdarzeń,
- `SaveChangesAsync(cancellationToken)`.

`DbUpdateException`, którego wewnętrzny `PostgresException.SqlState` równa się `23505`, zwraca
`conflict`. Po `conflict` w cudzej transakcji wołający wycofuje transakcję, bo Postgres oznacza
ją jako przerwaną. Zrobi to `TransactionBehavior` w numerze `10`. Inny wyjątek bazy nie jest
łapany.

`LoadAsync` czyta `EventRecords` strumienia, `AsNoTracking`, `OrderBy(Version)`, i deserializuje
każdy wiersz do zdarzenia domenowego. Wersja wyniku to `Version` z `EventStreams` albo 0, gdy
strumienia nie ma.

`ReadAllAsync(afterPosition, maxCount, cancellationToken)` czyta `Position > afterPosition`,
`OrderBy(Position)`, `Take(maxCount)`, `AsNoTracking`. Zwraca `StoredEvent` z `Position`, żeby
projekcja mogła zapisać checkpoint. Nie filtruje po usłudze: w tej bazie i tak są tylko jej
strumienie.

### 4. Rejestracja

```csharp
namespace JJDevHub.EventStore.Postgres
{
    public static class EventStoreServiceCollectionExtensions
    {
        public static IServiceCollection AddPostgresEventStore<TContext>(this IServiceCollection services)
            where TContext : DbContext
        {
            services.AddScoped<IEventStore, PostgresEventStore<TContext>>();
            return services;
        }
    }
}
```

`AddDbContext<TContext>` zostaje w `Api` usługi, bo connection string zna skład hosta. Rejestr
nazw i `IEventSerializer` też rejestruje usługa: zestawy zdarzeń są w jej `Core`. Biblioteka nie
skanuje Identity, News, Learning, Cv ani Contact.

### 5. Kontekst bazy zapisu

Każdy kontekst zapisu woła mapowanie i nic ponadto w tym numerze. Przykład dla News, ten sam
kształt mają Identity, Learning, Cv i Contact:

```csharp
namespace JJDevHub.News.Persistence
{
    public sealed class NewsWriteContext(DbContextOptions<NewsWriteContext> options) : DbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.ApplyEventStore();
        }
    }
}
```

Nazwy klas: `IdentityWriteContext`, `NewsWriteContext`, `LearningWriteContext`,
`CvWriteContext`, `ContactWriteContext`. Każda leży w projekcie `{Usługa}.Persistence`. Fabryka
design-time `*WriteContextFactory` czyta zmienną `ConnectionStrings__{usługa}-write`. Brak
zmiennej kończy fabrykę wyjątkiem. Hasło nie stoi w pliku w repozytorium.

Schemat usługi powstaje z jej projektu:

```bash
dotnet ef migrations add WriteInitial \
  --project src/services/News/News.Persistence \
  --context NewsWriteContext \
  --output-dir Migrations
```

Historia zostaje w `__EFMigrationsHistory` tej bazy. Pięć baz ma pięć niezależnych historii.
Biblioteka współdzielona własnej historii nie ma.

### 6. Udział w transakcji wołającego

Gdy `TransactionBehavior` otworzy transakcję na tym samym `DbContext`, `AppendAsync` widzi
`CurrentTransaction` i nie woła `Commit`. Wycofanie wołającego zabiera wiersze strumienia. Test
`Append_joins_outer_transaction` robi `BeginTransactionAsync`, `AppendAsync`, `RollbackAsync` i
sprawdza, że `LoadAsync` zwraca wersję 0.

Gdy wołający nie otworzył transakcji, magazyn otwiera własną, zatwierdza po sukcesie i wycofuje
przy wyjątku. Dzięki temu test biblioteki nie potrzebuje mediatora.

### Co jest do czego

- `EventStream` woła `PostgresEventStore` przy `AppendAsync` i przy `LoadAsync`. Jeden wiersz na
  agregat trzyma aktualną `Version` i opcjonalny `IdentityGuid`. Na nim widać konflikt, zanim
  powstanie drugi fakt. Bez tej tabeli nie ma gdzie porównać oczekiwanej wersji z zapisaną:
  pierwszy zapis nie ma kotwicy, a odczyt nie umie oddać wersji 0 dla strumienia, którego nie
  było. `StreamId` do 200 znaków jest kluczem. `IdentityGuid` nie sięga do `identity_write`.
- `EventRecord` woła ten sam magazyn, raz na fakt, oraz `ReadAllAsync`, gdy projekcja idzie po
  pozycji. Wiersz nie jest aktualizowany i nie jest kasowany. `Payload` to `jsonb`, `EventType`
  to nazwa z atrybutu. Bez tabeli `LoadAsync` nie ma historii artykułu, a restart gubi
  `ArticleCreated` i `StudentInquiryReceived` tak samo jak magazyn w pamięci. `DateOccurred`
  jako `timestamptz` zostaje przy kopercie, nie w JSON-ie.
- `Position` woła `ReadAllAsync` i, dalej, worker projekcji tej samej usługi. To porządek
  commitów w tej jednej bazie. Czyta go projekcja News z `news_write`, nigdy projekcja Learning.
  Bez kolumny `GENERATED ALWAYS AS IDENTITY` i bez zamka checkpoint nie ma liczby, która rośnie
  w kolejności zatwierdzeń. Dziura 10 przy widocznym 11 zostaje na stałe.
- `EventId` woła unikalny indeks i test `Unique_event_id_returns_conflict`. To identyfikator
  faktu, nie slug i nie wersja. Drugi zapis tego samego `EventId` kończy się `conflict`. Bez
  indeksu powtórzone żądanie dokleiłoby drugi `EventRecord` o tej samej tożsamości i projekcja
  zobaczyłaby dwa fakty tam, gdzie zaszedł jeden.
- `ApplyEventStore` woła `OnModelCreating` każdego `*WriteContext` oraz `TestWriteContext`. To
  jedyne miejsce, w którym tabele wchodzą do modelu EF. Dzięki temu outbox dołączy do tego
  samego kontekstu. Bez wywołania kontekst kompiluje się, `EnsureCreated` albo migracja buduje
  pustą bazę i pierwszy zapis kończy się wyjątkiem IO, nie `conflict`.
- `EventStoreLock` woła `AppendAsync` przed odczytem wersji, przez `ExecuteSqlAsync`. Jeden
  klucz blokady na bazę wyrównuje kolejność `Position` z kolejnością commitów. Bez
  `pg_advisory_xact_lock` sekwencja identity oddaje numer przy wstawieniu i projekcja gubi fakt,
  który zatwierdził się po sąsiedzie, a dostał mniejszą pozycję. Zamek nie łączy pięciu baz w
  jedną kolejkę.
- `PostgresEventStore<TContext>` woła handler przez port `IEventStore`, a rejestruje go
  `AddPostgresEventStore`. To implementacja portu z numeru `08`. Repozytorium agregatu nie
  rozróżnia pamięci i Postgresa po typie portu. Bez rejestracji w `Api` komenda nie ma adaptera:
  historia zostaje w procesie albo kontener w ogóle nie składa handlera. Klasa jest `sealed` i
  dostaje `TContext` oraz `IEventSerializer` primary constructorem.
- `IEventSerializer` woła magazyn przy `Serialize` w trakcie dopisania i przy deserializacji w
  `LoadAsync`. Rejestruje go usługa, nie biblioteka. Bez niego nie powstaje `EventType` z
  `[EventName]` ani `Payload`. Do kolumny weszłaby pokusa zapisania nazwy CLR. Serializer trzyma
  rejestr z `Core` usługi, a test podstawia rejestr z `test.happened.v1`.
- `*WriteContext` woła `Api` przy starcie hosta i fabryka design-time przy migracji. To
  właściciel bazy `*_write` i jej schematu. `Api` tworzy go ze stringa, który Aspire albo user
  secrets podały tylko tej usłudze. Bez kontekstu nie ma gdzie zawołać `ApplyEventStore`, a
  `dotnet ef migrations add WriteInitial` nie ma `--context`. Hasło zostaje poza repozytorium, w
  zmiennej `ConnectionStrings__{usługa}-write`.
- `TestWriteContext` woła fixture testu integracyjnego. Dowód, że mapowanie działa bez domeny
  usługi. Bez niego test albo ciągnąłby `News.Core`, albo sprawdzałby SQL na ślepo, poza modelem
  EF. `EnsureCreatedAsync` na tym kontekście ma utworzyć `EventStreams` i `EventRecords` i nic
  więcej.
- `StoredEvent` woła `ReadAllAsync` jako wynik dla projekcji. Niesie `Position`, żeby checkpoint
  miał co zapisać. Bez tej pozycji worker musiałby zgadywać postęp po `Version` strumienia i
  gubiłby nowy artykuł, którego identyfikatora jeszcze nie zna. Magazyn nie filtruje wyniku po
  nazwie usługi.
- `AddPostgresEventStore<TContext>` woła `Program.cs` usługi. Wiąże `IEventStore` jako scoped.
  Bez tej linii port zostaje niezbindowany albo, co gorsza, ktoś podstawia magazyn w pamięci w
  hoście, który miał przeżyć restart. Metoda nie rejestruje `DbContext` i nie skanuje zestawów
  usług.

## Testy

Projekt `tests/JJDevHub.EventStore.Postgres.Tests`. Runner xUnit, metody `[Fact]`, cecha
`[Trait("Category", "Integration")]`. Każdy fakt ma jeden powód do padnięcia. Kontener
`PostgreSqlBuilder("postgres:16-alpine")` wstaje w fixture `IAsyncLifetime`. `TestWriteContext`
woła `ApplyEventStore`, schemat tworzy `Database.EnsureCreatedAsync`. Fixture zamyka kontener w
`DisposeAsync`.

Zdarzenie testowe ma `[EventName("test.happened.v1")]` i leży w zestawie testu, nie w `Core`
usługi. Układ zastępuje artykuł i zapytanie studenta mniejszym faktem: jedno pole `Title` równe
`Notatka` sprawdza, że `jsonb` trzyma treść, a atrybut sprawdza, że kolumna nie dostała nazwy
klasy. Dwa konteksty w `Parallel_appends_one_wins` sprawdzają wyścig nowego strumienia.
Wycofanie w `Append_joins_outer_transaction` sprawdza, że magazyn nie commituje cudzej
transakcji.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Append_stores_stream_version` | jedno zdarzenie, oczekiwana wersja 0 | `AppendAsync` | `EventStreams.Version` równe 1 |
| `Append_stores_identity_guid` | `identityGuid` równe `abc` | `AppendAsync` | `IdentityGuid` równe `abc` |
| `Append_stores_attribute_name` | zdarzenie z `[EventName("test.happened.v1")]` | `AppendAsync` | `EventType` równe `test.happened.v1` |
| `Append_stores_jsonb_payload` | zdarzenie z polem `Title` równym `Notatka` | `AppendAsync` | `Payload` zawiera `title` i `Notatka` |
| `Load_roundtrip_returns_event` | zapis jednego faktu | `LoadAsync` | zdarzenie równe zapisanemu, wersja 1 |
| `Empty_append_returns_invalid` | pusta lista, strumień nie istnieje | `AppendAsync` | kod `invalid`, brak wiersza `EventStreams` |
| `Stale_append_returns_conflict` | strumień w wersji 1 | `AppendAsync` z oczekiwaną wersją 0 | kod `conflict` |
| `Stale_append_does_not_add_row` | jeden fakt w strumieniu | zapis ze złą wersją | nadal jeden `EventRecord` |
| `Parallel_appends_one_wins` | dwa konteksty, pusty strumień | dwa `AppendAsync` z wersją 0 | jeden sukces i jeden `conflict` |
| `Read_all_orders_by_position` | zapisy do dwóch strumieni | `ReadAllAsync(0, 10)` | `Position` rośnie i nie ma dziury na starcie |
| `Read_all_respects_after_position` | trzy fakty | `ReadAllAsync` od pozycji pierwszego | wynik bez pierwszego faktu |
| `Append_joins_outer_transaction` | `BeginTransactionAsync`, zapis, `RollbackAsync` | `LoadAsync` | wersja 0 |
| `Unique_event_id_returns_conflict` | dwa rekordy z tym samym `EventId` | drugi `AppendAsync` | kod `conflict` |

```bash
dotnet test tests/JJDevHub.EventStore.Postgres.Tests
```

Test jednostkowy bez kontenera, z filtrem z [README.md](README.md) dokumentacji, tego projektu
nie obejmuje: cały projekt jest integracyjny. Filtr `Category!=Integration` po prostu go pomija.
Padnięcie jednego wiersza tabeli ma zostawiać pozostałe fakty zielone. Wspólny fixture kontenera
nie zwalnia z jednego powodu do padnięcia na metodę: wersja, nazwa atrybutu, `jsonb`, konflikt i
pozycja są osobnymi faktami, bo inaczej czerwony test nie mówi, która decyzja się rozjechała.

## Zasady

- `Core` nie referencjonuje `JJDevHub.EventStore.Postgres`, Entity Framework ani Npgsql.
  Złamanie wciąga agregat w schemat bazy i test reguły artykułu wstaje tylko z kontenerem.
- Biblioteka nie ma własnego `DbContext` i nie trzyma katalogu schematu. Złamanie daje usługom
  wspólną historię migracji albo drugi kontekst, w którym outbox nie wejdzie w ten sam
  `SaveChanges`.
- `EventType` pochodzi z `[EventName]`. Nazwa CLR w kolumnie jest błędem testu
  `Append_stores_attribute_name`. Złamanie psuje odczyt historii po przeniesieniu klasy, bo
  stary `Payload` zostaje przy nazwie, której już nie ma.
- `Payload` jest `jsonb`. Pola zdarzenia nie dostają kolumn w bazie zapisu. Złamanie wymusza
  migrację przy każdym nowym polu `ArticleCreated` albo `StudentInquiryReceived` i wiąże pięć
  baz z kształtami CLR.
- `AppendAsync` uczestniczy w istniejącej transakcji i nie zatwierdza cudzej. Złamanie commituje
  strumień w połowie handlera, więc `RollbackAsync` mediatora zostawia artykuł, którego komenda
  nie uznała.
- Każdy zapis bierze `pg_advisory_xact_lock` przed odczytem wersji. Złamanie rozjeżdża
  `Position` wobec kolejności commitów i projekcja gubi fakt za checkpointem.
- Konflikt wersji i naruszenie unikalności `23505` wracają jako `Result` z kodem `conflict`.
  Inny błąd bazy jest wyjątkiem. Złamanie każe klientowi ponawiać awarię dysku albo zamienia
  zwykły timeout w błąd bez kodu.
- `CancellationToken` idzie do `ToListAsync`, `ExecuteSqlAsync` i `SaveChangesAsync`. Złamanie
  zostawia polecenie na połączeniu po tym, jak klient już rozłączył żądanie.
- Usługa otwiera tylko swoją bazę `*_write`. Nazwa bazy jest na liście: `identity_write`,
  `news_write`, `learning_write`, `cv_write`, `contact_write`. Złamanie daje News wgląd w
  strumień sąsiada i omija granicę, której broni też brak connection stringa.
- Wiersz `EventRecord` nie jest aktualizowany ani usuwany. Złamanie sprawia, że `LoadAsync`
  składa inny artykuł niż ten, który kiedyś zatwierdzono, i nie ma już faktu, od którego
  projekcja mogłaby iść.

## Poza zakresem

- Port `IEventStore` i magazyn w pamięci są w [08-strumien.md](08-strumien.md). Ten numer ich
  nie zmienia: dokładka Postgresa ma przejść ten sam kontrakt wersji, pozycji i `Result`.
- Mediator, `TransactionBehavior` i `IUnitOfWork` są w [10-cqrs.md](10-cqrs.md). Tutaj magazyn
  tylko umie dołączyć do transakcji, którą ktoś już otworzył, albo otworzyć własną, gdy wołający
  jej nie ma.
- Tłumaczenie wyjątku IO na `ProblemDetails` jest w [11-walidacja.md](11-walidacja.md).
  `conflict` wychodzi stąd jako `Result`, a `ETag` z `Version` też powstanie dopiero na brzegu
  HTTP.
- Bazy `*_read`, checkpoint i worker projekcji są w [12-projekcja.md](12-projekcja.md).
  `ReadAllAsync` oddaje pozycję, ale nie zapisuje widoku artykułu ani sluga.
- Tabele `OutboxMessages` i `InboxMessages` w tym samym kontekście są w
  [14-outbox.md](14-outbox.md). Wspólny commit jest powodem kształtu biblioteki, nie powodem,
  żeby te tabele mapować już teraz.
- Agregaty Identity, News, Learning, Cv i Contact są w [17-identity.md](17-identity.md) i
  numerach usług po nim. `TestWriteContext` celowo nie zna `ArticleCreated` poza przykładem
  nazwy w prozie tego numeru.
- Connection string z AppHost jest w [01-aspire.md](01-aspire.md). Tutaj wiadomo tylko, że hasło
  nie leży w repozytorium, a zmienna `ConnectionStrings__{usługa}-write` zasila fabrykę
  design-time.

## Źródła

- [Event Sourcing
  pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing).
  Wiążący jest log dopisywany i odczyt stanu przez złożenie faktów: `EventRecord` nie jest
  aktualizowany, a `LoadAsync` składa strumień. Decyzja tego pliku to dwie tabele w bazie zapisu
  usługi, nie osobny produkt. Ze wzorca nie bierzemy projekcji w tej samej transakcji co zapis i
  nie bierzemy jednego wspólnego logu dla pięciu usług.
- Martin Fowler, [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html). Wiążące
  jest trzymanie historii zmian jako źródła prawdy zamiast samego aktualnego wiersza artykułu. W
  tym pliku dotyczy to `EventStreams` i `EventRecords` oraz zakazu kasowania faktu. Nie bierzemy
  stąd osobnego serwera zdarzeń ani odtwarzania agregatu na każdym `GET`: odczyt strony jest w
  numerze `12`.
- Gregory Young, *Versioning in an Event Sourced System*. Wiążące jest oczekiwana wersja przy
  dopisaniu oraz tożsamość faktu niezależna od nazwy klasy CLR. W tym pliku stąd bierze się
  `conflict` przy starej `Version` i `EventType` z `[EventName]`, na przykład
  `news.article-created.v1`. Nie bierzemy stąd osobnego produktu, który zastąpiłby PostgreSQL,
  ani zapisu nazwy klasy CLR w kolumnie `EventType`.
- Martin Kleppmann, *Designing Data-Intensive Applications*. Wiążący jest dopisywany log i
  skutek numeru nadanego przed commitem: sekwencja identity potrafi oddać 11 wcześniej niż 10. W
  tym pliku dotyczy to `Position` i `pg_advisory_xact_lock`. Nie bierzemy kompaktowania logu, bo
  wiersz `EventRecord` nie jest usuwany, i nie bierzemy Kafki jako magazynu strumienia
  domenowego.
- [Database per service](https://microservices.io/patterns/data/database-per-service). Chris
  Richardson: usługa nie czyta bazy sąsiada. W tym pliku dotyczy to pięciu baz `identity_write`,
  `news_write`, `learning_write`, `cv_write` i `contact_write` oraz braku connection stringa do
  sąsiada. Nie bierzemy osobnego serwera na każdą usługę: serwer Postgresa jest jeden. Nie
  bierzemy też złożenia strony CV z bazy Learning.
- [PostgreSQL explicit locking: advisory
  locks](https://www.postgresql.org/docs/16/explicit-locking.html#ADVISORY-LOCKS). Wiążące jest
  `pg_advisory_xact_lock` trzymane do końca transakcji, także gdy transakcję otworzył wołający.
  Decyzja tego pliku to stały `EventStoreLock.Key` na bazę, nie na strumień. Nie bierzemy zamków
  doradczych jako sposobu na koordynację między pięcioma bazami i nie bierzemy poziomu
  `SERIALIZABLE` zamiast czekania.
- [PostgreSQL INSERT: identity
  columns](https://www.postgresql.org/docs/16/sql-createtable.html). Wiążące jest to, że numer
  identity powstaje przy wstawieniu, nie przy commicie. W tym pliku dotyczy to kolumny
  `Position` z `UseIdentityAlwaysColumn()` i powodu, dla którego sam indeks nie wystarczy
  projekcji. Nie bierzemy możliwości wstawienia własnej pozycji z klienta. `GENERATED ALWAYS`
  jest po to, żeby wołający jej nie podał.
- [Npgsql EF Core: JSON mapping](https://www.npgsql.org/efcore/mapping/json.html). Wiążąca jest
  kolumna `jsonb` przez `HasColumnType("jsonb")`. Decyzja tego pliku to jeden `Payload` dla
  `ArticleCreated` i dla `StudentInquiryReceived`, z diagnostyką `Payload->>'slug'`. Nie
  bierzemy typu `json`, który trzyma tekst dosłownie, i nie bierzemy indeksu GIN w tym numerze.
- [Npgsql EF Core: generated
  properties](https://www.npgsql.org/efcore/modeling/generated-properties.html). Wiążące jest
  `UseIdentityAlwaysColumn` dla klucza `Position`. W tym pliku EF nie wysyła wartości pozycji
  przy `INSERT`, a odczyt projekcji robi `ORDER BY` po kluczu bez osobnego indeksu. Nie bierzemy
  generowania `Version` przez bazę: wersję liczy magazyn z oczekiwanej wartości i liczby faktów.
- [Using transactions in EF
  Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions). Wiążące jest
  `CurrentTransaction` i transakcja współdzielona na jednym `DbContext`. Decyzja tego pliku:
  `AppendAsync` uczestniczy i nie woła `Commit`, a `23505` wewnątrz `DbUpdateException` staje
  się `conflict`. Nie bierzemy rozproszonej transakcji między bazą zapisu a osobnym logiem. Inny
  błąd bazy zostaje wyjątkiem.
- [EF Core migrations](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/).
  Wiążące jest trzymanie schematu w projekcie, który posiada `DbContext`. W tym pliku migracja
  `WriteInitial` idzie z `{Usługa}.Persistence`, a historia zostaje w `__EFMigrationsHistory`
  tej bazy. Nie bierzemy katalogu migracji w `JJDevHub.EventStore.Postgres`. Pięć baz ma pięć
  historii. Hasło nie wchodzi do pliku w repozytorium.
- [PostgreSQL License](https://www.postgresql.org/about/licence/). Wiążąca jest licencja pakietu
  `Npgsql.EntityFrameworkCore.PostgreSQL`, zgodna z listą dozwolonych, obok Entity Framework
  Core na MIT. W tym pliku oba pakiety wpisują się do tabeli w `README` przy numerze `09`, a
  wersja ląduje w `Directory.Packages.props`. Nie bierzemy drugiego silnika tylko dlatego, że
  też umie dokument: Dapper zostaje dozwolony (Apache-2.0), ale nie wygrywa mapowania.

## Gotowe gdy

- `ApplyEventStore` tworzy w teście tabele `EventStreams` i `EventRecords`.
- `EventRecords.EventType` zawiera `test.happened.v1`, a nie nazwę klasy.
- `EventRecords.Payload` ma typ `jsonb`.
- Drugi zapis ze starą `Version` zwraca `conflict` i nie dodaje wiersza.
- Dwa równoległe zapisy tego samego nowego strumienia kończą się jednym sukcesem i jednym
  `conflict`.
- `ReadAllAsync` zwraca fakta w kolejności `Position`.
- Zapis w transakcji, która się wycofuje, nie zostawia strumienia.
- `dotnet test tests/JJDevHub.EventStore.Postgres.Tests` kończy się kodem 0.
- Żaden projekt `*.Core` nie ma referencji do `JJDevHub.EventStore.Postgres`.
