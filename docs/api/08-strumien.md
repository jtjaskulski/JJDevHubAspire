# 08. Strumień

Poprzedni numer, [agregat](07-agregat.md), zbiera niezatwierdzone zdarzenia i zmienia pola tylko
w `Apply`. Ten numer dokłada port `IEventStore` i `InMemoryEventStore`: konflikt wersji oraz
globalną pozycję. Następny numer, [trwałość](09-persistence.md), przeniesie ten sam port na
PostgreSQL w bazie zapisu. Po tym numerze da się dopisać zdarzenia w pamięci procesu i dostać
`Conflict`, gdy oczekiwana wersja jest nieaktualna. Port nie zna Npgsql, connection stringa ani
nazw `identity_write` i pozostałych baz. Agregat produkcyjny nadal nie powstaje. Przepływ
appendu obok outboxa jest w [architektura.md](architektura.md).

Scenariusz, który bez tego numeru się psuje, jest dwiema edycjami tego samego artykułu. Handler
woła SQL albo `Save` na repozytorium, które chowa strumień. Caller nie widzi oczekiwanej wersji.
Oba żądania przechodzą albo drugie wybucha wyjątkiem i brzeg robi `500`, choć proces działa i
klient miał dostać konflikt oraz ponowić odczyt. Test reguły wersji chce kontenera, zanim
kontrakt portu w ogóle istnieje. Zamiana pamięci na PostgreSQL zmienia sygnaturę. Projekcja nie
ma pozycji szerszej niż wersja jednego agregatu, więc gubi kolejność między `article:{id}` a
`skill:{id}`. Pusty strumień wygląda jak `NotFound` na `GET`, choć `GET` tego portu nie woła.

Ten numer zamyka sygnaturę i semantykę. Pamięć jest implementacją, którą test jednostkowy
podnosi bez Dockera. PostgreSQL w numerze 09 ma przejść ten sam kontrakt: oczekiwana wersja,
wersja strumienia, pozycja globalna, `Result` zamiast wyjątku przy konflikcie. Puste bazy z
numeru 02 nadal nie mają tabeli strumienia.

## Po co

Handler komendy będzie wołał magazyn, nie tabelę. Jeśli od razu woła SQL, test reguły wersji
potrzebuje kontenera, a zamiana pamięci na PostgreSQL zmienia sygnaturę. `IEventStore` dopisuje
listę zdarzeń pod `StreamKey` przy oczekiwanej wersji i czyta jeden strumień. Zwraca
`Result<AppendResult>` albo `Result<StreamSlice>`. Projekt `src/shared/JJDevHub.EventStore`
referencjonuje wyłącznie `JJDevHub.Shared.Kernel`. W sygnaturze nie ma transakcji ADO.NET.
Transakcję z outboxem doda numer 09 i [14-outbox.md](14-outbox.md) po swojej stronie
implementacji, bez zmiany znaczenia wersji.

Pozycja globalna jest potrzebna projekcji. Wersja strumienia mówi, czy ten agregat ktoś zdążył
zmienić. Pozycja mówi, jak daleko worker odczytu doszedł w całej usłudze. Jeden licznik nie
zastąpi drugiego. Słownik kodu `stream.version.conflict` jest w [README.md](README.md). Obok
niego jest `stream.key.blank`. Plan dopisuje do słownika także `stream.events.empty`. Pusty
klucz i pusta lista zdarzeń są `Invalid` i nic nie zapisują. Zła wersja jest `Conflict` i też
nic nie zapisuje. Pusty strumień przy odczycie jest sukcesem z wersją `0` i pustą listą. To nie
jest `NotFound`.

Pamięć ginie z procesem i nie jest współdzielona między testami, które utworzą dwa egzemplarze.
To jest właściwe. Pozycja nie przeżywa restartu. Na PostgreSQL przeżyje, w sekwencji bazy zapisu
tej jednej usługi, nie w sekwencji wspólnej dla News i Cv. Testy, które zależą od liczby między
procesami, tu nie powstają. Test tego numeru nie otwiera kontenera i nie czyta `news_write`.
Obraz `postgres:16-alpine` nie jest zależnością tego projektu. Redis nie jest magazynem
strumienia.

Dwa równoległe dopisania z tą samą oczekiwaną wersją nie mogą oba przejść. Dlatego dopisanie
jest w `lock`: sprawdzenie wersji i dopisanie są jedną czynnością. `InMemoryEventStore` jest
`sealed`, nie używa stanu statycznego, a test tworzy nowy egzemplarz. Po `Conflict` lista
strumienia ma tyle zdarzeń, ile przed wywołaniem. Magazyn nie woła `MarkPersisted` i nie woła
`Apply`. Dostaje kopie zdarzeń. Handler po `Conflict` wyrzuca egzemplarz agregatu. `ReadAsync`
zwraca kopię listy, nie żywą listę wewnętrzną.

## Dlaczego ta technologia

### `IEventStore`

Port w `src/shared/JJDevHub.EventStore` dopisuje listę zdarzeń pod `StreamKey` przy oczekiwanej
wersji. Czyta jeden strumień. Zwraca `Result<AppendResult>` albo `Result<StreamSlice>`.
`AppendAsync` i `ReadAsync` przyjmują `CancellationToken`. Projekt referencjonuje wyłącznie
`JJDevHub.Shared.Kernel`. Nie ma innych referencji projektów. Nie ma pakietu Npgsql, EF,
Testcontainers i ASP.NET. Nie ma łańcucha `Host=`. Nie ma nazwy `news_write`.
`JJDevHub.EventStore.csproj` nie zawiera `Npgsql`. W projekcie nie ma łańcucha połączenia.

Agregat nie może sam otwierać bazy, a handler nie może znać kształtu tabeli. Inaczej
[10-cqrs.md](10-cqrs.md) przywiąże komendę do PostgreSQL i test jednostkowy komendy wstanie
tylko z kontenerem. Port zna oczekiwaną wersję, bo caller ma odróżnić utworzenie od konfliktu.
Utworzenie żąda `expectedVersion` równe `0` na pustym strumieniu. Kolejna zmiana żąda wersji,
którą strumień ma po poprzednim dopisaniu. Schowanie tego w `Save` zostawia handler bez `Result`
i bez kodu `stream.version.conflict`.

Konkret JJDevHub: pierwszy produkcyjnie port zawoła `Article` w [18-news.md](18-news.md). W tym
numerze fakt woła magazyn bez agregatu `Article`, na zdarzeniu testowym `ProbeStored`. Klucz
buduje caller, na przykład `probe:{guid}`. Magazyn nie wycina typu agregatu z klucza i nie
odrzuca nieznanego prefiksu. Dzięki temu `article:{id}` i `skill:{id}` są dwoma łańcuchami, nie
dwoma klasami wewnątrz portu. Port nie zna `Skill` i nie zna `Article`. Zna nieprzezroczysty
`StreamKey` i `IDomainEvent`.

Odpadło repozytorium `GetById` i `Save`, które chowa strumień. Caller nie widzi oczekiwanej
wersji i nie umie odróżnić utworzenia od konfliktu. `GetById`, które zwraca `null`, miesza brak
strumienia z brakiem wiersza na `GET`. Odczyt portu na nieznanym kluczu jest sukcesem. `Save`,
które nadpisuje stan, nie ma listy faktów ani pozycji. Handler CQRS nie miałby czego przekazać
do `MarkPersisted` jako „to, co weszło”. Zostaje jawne dopisanie i jawny odczyt historii.

Odpadło też postawienie `NpgsqlConnection` w sygnaturze portu. Port zna wtedy konkretny silnik,
a numer 09 nie ma czego podmienić. Implementacja w pamięci i implementacja na PostgreSQL mają tę
samą sygnaturę. Transakcja ADO.NET w interfejsie związałaby pamięć z połączeniem, którego pamięć
nie ma, i zmusiłaby test konfliktu do kontenera. Outbox dojdzie po stronie implementacji
trwałej, bez zmiany znaczenia wersji. Metody `async` i tak przyjmują `CancellationToken`, żeby
anulowanie nie było dokładane później inną sygnaturą.

Koszt: dwa projekty w czasie, pamięć teraz, PostgreSQL potem. Sygnatura musi unieść oba. Dlatego
nie ma w niej transakcji ADO.NET i nie ma nazwy bazy. Implementacja w pamięci nie sprawdza, czy
połączenie do bazy żyje. Test łączności baz zostaje w numerze 02 i nie zastępuje tego faktu. Dwa
testy pilnują dwóch rzeczy. Kto w tym numerze doda `PackageReference` do Npgsql, złamie
„gotowe”, nawet jeśli test konfliktu nadal jest zielony w pamięci.

### `InMemoryEventStore`

Klasa `sealed` w tym samym projekcie. Trzyma `Dictionary<StreamKey, List<StoredEvent>>` i jeden
`long` pozycji. Dopisanie jest w `lock`, żeby sprawdzenie wersji i dopisanie były jedną
czynnością. Nie używa statycznego stanu. Test tworzy nowy egzemplarz. Gdy klucz nie istnieje,
liczba zdarzeń wynosi zero. Przy zgodności dopisuje każde zdarzenie z wersją `count + 1`, `count
+ 2`, i tak dalej. Każdemu nadaje kolejną pozycję globalną. Przy niezgodności zwraca konflikt i
nie zmienia listy ani licznika. `ReadAsync` zwraca kopię listy, nie żywą listę wewnętrzną.

Dwa równoległe dopisania z tą samą oczekiwaną wersją nie mogą oba przejść.
`ConcurrentDictionary` bez wspólnej sekcji krytycznej sprawdza wersję, potem drugi wątek też ją
sprawdza, potem oba dopisują. Oba widzą wersję `0` i oba dopisują pierwsze zdarzenie. Strumień
ma dwa fakty o tej samej wersji albo cicho gubi jedno z nich. `lock` obejmuje sprawdzenie i
dopisanie, więc drugi wątek wchodzi, gdy pierwszy już podniósł liczbę. Drugi dostaje `Conflict`,
jeśli żądał starej wersji. Po `Conflict` lista ma tyle zdarzeń, ile przed wywołaniem.

Konkret testu: nowy `InMemoryEventStore`, jeden `StreamKey`, udane `AppendAsync` jednego
zdarzenia z `expectedVersion` równym `0`. Drugie `AppendAsync` na tym samym kluczu z
`expectedVersion` równym `0` zwraca porażkę, `IsSuccess` jest fałszem, a `Error.Kind` równa się
`Conflict`. Przygotowanie zakłada, że pierwsze dopisanie się udało. Jeśli pierwsze dopisanie
padnie, fakt jest czerwony, zanim sprawdzi konflikt. Wtedy implementacja nie spełnia nawet
zapisu wersji `0`, a asercja konfliktu i tak jest tą, którą sekcja nazywa powodem. W fakcie nie
ma asercji `Position`. Nie ma kontenera. Nie ma odczytu `news_write`.

Odpadł słownik bez sprawdzenia wersji, nadpisujący listę. Drugie dopisanie skasowałoby pierwszy
fakt albo dołożyło go bez porównania. Odtworzenie dostałoby inną historię niż ta, którą
zaakceptowała pierwsza komenda. Konflikt jako `Result` nie miałby kiedy powstać. Odpadło też
wejście w PostgreSQL w tym numerze. Test konfliktu stałby się integracyjny, a kontrakt portu nie
byłby jeszcze oglądany bez SQL. Baza zapisu z [02-postgres.md](02-postgres.md) zostaje pusta.
Tabela strumienia dojdzie w numerze 09. Do tego czasu `SELECT 1` z numeru 02 i ten fakt pilnują
różnych rzeczy.

Koszt: pamięć ginie z procesem i nie jest współdzielona między testami, które utworzą dwa
egzemplarze. To jest właściwe. Pozycja nie przeżywa restartu. Na PostgreSQL przeżyje. Testy,
które zależą od liczby między procesami, tu nie powstają. Stan statyczny naprawiłby
współdzielenie i zepsuł izolację faktów: jeden test zostawiłby wersję drugiemu. Dlatego
egzemplarz jest lokalny, a klasa jest `sealed`. Dziedziczenie magazynu otworzyłoby drugi
`AppendAsync`, który omija `lock`. Zostaje jedna klasa.

### Konflikt wersji jako `Result`

Pusty strumień ma wersję `0`. Pierwsze dopisanie żąda `expectedVersion` równe `0`. Po jednym
zdarzeniu wersja strumienia wynosi `1`. Kolejne dopisanie żąda `1`. Gdy żądana wersja jest inna,
metoda zwraca `Result.Fail(ResultError.Conflict("stream.version.conflict"))`. Nie dopisuje
zdarzeń. Nie rzuca. Kod jest w słowniku [README.md](README.md). Rodzaj to `Conflict` z numeru
05, nie nowy rodzaj w magazynie. Po konflikcie liczba zdarzeń w strumieniu się nie zmienia.
Licznik pozycji też się nie zmienia, bo dopisanie albo wchodzi całe, albo wcale.

Dwa żądania edycji tego samego artykułu są oczekiwane. Klient dostaje konflikt i ponawia odczyt.
Wyjątek zamieniłby to w `500` i w ślad awarii, choć proces działa. Handler musi obejrzeć
`Result`. Po `Conflict` wyrzuca egzemplarz agregatu i nie woła `MarkPersisted`. Sam magazyn
`MarkPersisted` nie woła, bo nie dostaje agregatu. Dostaje kopie zdarzeń. `AppendResult` przy
sukcesie niesie wersję strumienia po dopisaniu i pozycję ostatniego zdarzenia z tej listy. Przy
porażce tej wartości nie ma, bo getter na porażce z numeru 05 i tak nie oddaje sukcesu.

Konkret: pierwsze zdarzenie na `probe:{guid}` z wersją oczekiwaną `0` wchodzi i strumień ma
wersję `1`. Drugie żądanie z `0` nie dokłada faktu. Lista nadal ma jeden element. To jest ten
sam powód, który sprawdza fakt `Append_with_stale_version_returns_conflict`: `IsSuccess` jest
fałszem i rodzaj to `Conflict`. Fakt nie sprawdza jednocześnie, że lista ma jeden element.
Warunek „gotowe” mówi, że przy konflikcie liczba zdarzeń się nie zmienia. To jest przegląd
implementacji obok asercji rodzaju. Doklejenie liczenia listy do faktu dałoby drugi powód, jeśli
rodzaj jest dobry, a lista nie, albo odwrotnie. Nazwa metody mówi o konflikcie.

Odpadło `InvalidOperationException` przy złej wersji. Odpadł `DbUpdateConcurrencyException`. Ten
typ należy do EF, którego port nie zna, i też jest wyjątkiem dla sytuacji oczekiwanej. Port bez
EF nie ma tego typu czym rzucić, a nawet gdyby miał, brzeg bez osobnej listy wyjątków zrobiłby
`500`. `ResultError.Conflict` woła brzeg, gdy powstanie mediator. Daje kod
`stream.version.conflict` do pola `type`. Tu zwraca go magazyn. Handler w
[10-cqrs.md](10-cqrs.md) będzie tym, który łączy `Replay`, append i `MarkPersisted` i który po
konflikcie wyrzuca egzemplarz.

Koszt: handler musi obejrzeć `Result`. Zignorowanie porażki i wywołanie `MarkPersisted` kasuje
listę w agregacie, choć strumień jej nie przyjął. Numer 07 już mówi, że po konflikcie
egzemplarza się nie używa. Ten numer daje powód, dla którego handler to robi: magazyn zwrócił
`Conflict` i nie zmienił listy. Pusta lista zdarzeń przy dopisaniu nie jest konfliktem. Jest
`Invalid` i kodem `stream.events.empty`. Nie ma czego dopisywać, więc nie ma też wersji do
porównania w sposób, który wygląda jak wyścig. Ten kod dopisuje się do słownika README. Nie jest
powodem padnięcia faktu o starej wersji.

### Globalna pozycja

Każde zdarzenie w `StoredEvent` dostaje `Position`. Licznik jest wspólny dla wszystkich
strumieni w egzemplarzu magazynu. Zaczyna się od zera. Pierwsze zdarzenie dostaje pozycję `1`.
Kolejne, także w innym `StreamKey`, dostaje `2`, `3`, i tak dalej. `AppendResult` zwraca wersję
strumienia po dopisaniu i pozycję ostatniego zdarzenia z tej listy. `StoredEvent` niesie klucz,
wersję zdarzenia w strumieniu, pozycję globalną i `IDomainEvent`. Wersja rośnie tylko w swoim
strumieniu. Pozycja rośnie przez strumienie jednego egzemplarza.

Worker projekcji potrzebuje jednego kursora na usługę. Sama wersja strumienia `article:{id}` nie
mówi, czy w międzyczasie dopisano `skill:{id}`. Bez pozycji globalnej projekcja albo skanuje
wszystkie strumienie, albo gubi kolejność między nimi. Zapis wiersza `read_document` z kursora
pozycji jest w [12-projekcja.md](12-projekcja.md). W tym numerze pamięć zwraca pozycję, a nikt
jej nie zapisuje w `read_document`. Dwa udane dopisania do dwóch kluczy dostają rosnące pozycje
globalne, a wersja każdego strumienia liczy się osobno. To jest warunek „gotowe”, nie asercja
faktu o konflikcie.

Konkret: pierwsze zdarzenie na kluczu próbnym dostaje pozycję `1` i wersję strumienia `1`.
Drugie zdarzenie na innym kluczu, po sukcesie pierwszego, dostaje większą pozycję. Wersja
tamtego strumienia zaczyna się od własnego `1`, nie od `2`. Numer `2` jest pozycją, nie wersją.
Pomylenie tych liczb sprawi, że worker przeskoczy fakty jednej sekcji CV albo drugi raz
zastosuje wersję artykułu jako kursor. `AppendResult.Position` jest ostatnią pozycją z dopisanej
listy, nie wersją. Przy jednym zdarzeniu te liczby bywają równe. Przy dwóch zdarzeniach w jednym
dopisaniu wersja strumienia rośnie o dwa, a pozycja ostatniego jest końcem tego zakresu. Przy
konflikcie licznik stoi.

Odpadł sam numer wersji w strumieniu jako kursor odczytu. Nie porządkuje faktów z różnych
agregatów. Worker, który trzyma „ostatnią wersję artykułu”, nie wie o umiejętności dopisanej
obok. Skan wszystkich kluczy przy każdym takcie jest tym, czego jedna liczba pozycji ma uniknąć,
gdy dojdzie numer 12. Ten numer skanu nie implementuje. Oddaje liczbę, po której skan nie będzie
potrzebny. Odpadł `Guid` albo `DateTimeOffset` jako kursor. Żaden z nich nie jest gęstą, rosnącą
liczbą w jednym procesie, a zegary dwóch wątków potrafią się cofnąć. `EventId` zostaje
identyfikatorem wiadomości. Nie jest kursorem.

Koszt: pozycja w pamięci jest gęsta tylko w jednym egzemplarzu. Dziura po błędzie w środku
`lock` nie powinna powstać, bo dopisanie albo wchodzi całe, albo wcale. Implementacja PostgreSQL
będzie musiała wziąć pozycję z jednej sekwencji w bazie zapisu tej usługi. Nie z sekwencji
wspólnej dla News i Cv. Każda usługa ma własny magazyn i własną bazę. Dwie usługi nie dzielą
jednego egzemplarza pozycji, gdy już będą miały po swoim magazynie. Wspólny licznik między
usługami związałby kursor News z dopisaniem Cv i złamałby osobne bazy z numeru 02. Sekwencja w
numerze 09 jest szczegółem tamtej implementacji. Port jej nie woła.

### Port bez Postgresa

`JJDevHub.EventStore.csproj` nie ma `PackageReference` do `Npgsql` ani do EF. Nie ma łańcucha
`Host=`. Nie ma nazwy `news_write`. Odczyt nieistniejącego strumienia zwraca sukces, wersję `0`
i pustą listę. To nie jest `NotFound`. Brak wiersza projekcji jest `NotFound` na ścieżce
zapytania. Brak strumienia znaczy, że komenda tworzy agregat i zaraz dopisze wersję `0`.
`StreamSlice` niesie bieżącą wersję i zdarzenia uporządkowane po wersji rosnąco. Pusta lista i
wersja `0` są poprawnym wycinkiem, nie błędem.

Gdyby port zwracał `NotFound` dla pustego strumienia, tworzenie artykułu i brak notatki na `GET`
wyglądałyby tak samo. To są różne ścieżki. `GET` nie woła tego portu. Tworzenie woła
`ReadAsync`, dostaje pustkę i dopisuje z `expectedVersion` `0`. Zapytanie woła bazę odczytu i
tam brak wiersza jest `NotFound`. Pomylenie tych kodów sprawi, że `POST` nowego artykułu zwróci
`404`, zanim cokolwiek zapisze, albo że `GET` zacznie czytać strumień. Handler zapytania i tak
nie dostaje `IEventStore`. Ten podział jest z numeru 03 i tu dostaje konsekwencję w porcie:
pusty odczyt strumienia jest sukcesem.

Konkret klucza: pusty łańcuch albo same białe znaki to `stream.key.blank` i rodzaj `Invalid`.
Nic nie jest zapisane. Caller, który złoży `probe:` bez identyfikatora albo samą spację, dostaje
błąd wywołania, nie pusty strumień. Pusty strumień jest dla klucza, który jest niepusty i
jeszcze nic nie ma. Pusta lista zdarzeń przy dopisaniu to `stream.events.empty`, też `Invalid`.
Nie ma sensu podbijać wersji o zero faktów i zajmować pozycji. Oba kody są oczekiwane. Nie są
wyjątkami. `stream.version.conflict` i `stream.key.blank` są w słowniku README.
`stream.events.empty` plan każe dopisać obok nich.

Odpadło utworzenie `JJDevHub.EventStore.Postgres` w tym numerze. Odpadł EventStoreDB jako
silnik. To osobny produkt i osobny proces obok PostgreSQL, który już jest serwerem zapisu.
EventStoreDB odpadł. Strumień ma leżeć w bazie zapisu usługi, od numeru 09. Drugi proces
oznaczałby drugi obraz, drugi port i trzeci test łączności obok numeru 02. Pamięć nie jest tym
produktem. Jest implementacją portu na czas, w którym tabeli jeszcze nie ma. Kto wstawi tu
klienta obcego silnika, zwiąże sygnaturę z produktem, którego numer 09 nie podstawi pod
PostgreSQL.

Koszt: implementacja w pamięci nie sprawdza, czy połączenie do bazy żyje. Test łączności baz
zostaje w numerze 02 i nie zastępuje tego faktu. Dwa testy pilnują dwóch rzeczy. Zielony
konflikt w pamięci nie mówi, że `identity_write` ma tabelę. Nie ma jej mieć. Warunek „gotowe”
powtarza: puste bazy z numeru 02 nadal nie mają tabeli strumienia. Czerwony fakt z powodu
kontenera znaczyłby, że test sprawdza za dużo. Dlatego nie ma cechy `Category=Integration` i nie
ma cechy `Category=Performance`. NBomber jest w [22-testy.md](22-testy.md). Test wydajnościowy
dopisywania nie dostaje tu cechy wydajnościowej.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.EventStore/IEventStore.cs` | `AppendAsync` i `ReadAsync` |
| `src/shared/JJDevHub.EventStore/StreamKey.cs` | łańcuch klucza, bez parsowania |
| `src/shared/JJDevHub.EventStore/StoredEvent.cs` | strumień, wersja, pozycja, `IDomainEvent` |
| `src/shared/JJDevHub.EventStore/AppendResult.cs` | wersja strumienia i pozycja ostatniego dopisanego |
| `src/shared/JJDevHub.EventStore/StreamSlice.cs` | wersja i lista zdarzeń |
| `src/shared/JJDevHub.EventStore/InMemoryEventStore.cs` | słownik, `lock`, licznik pozycji |
| `src/shared/JJDevHub.EventStore/JJDevHub.EventStore.csproj` | referencja jądra, zero Npgsql |
| `tests/JJDevHub.EventStore.Tests/AppendConflictTests.cs` | fakt złej oczekiwanej wersji |
| `tests/JJDevHub.EventStore.Tests/ProbeStored.cs` | zdarzenie testowe, nie `Article` |

Klucz strumienia buduje caller, na przykład `probe:{guid}`. Magazyn nie wycina typu agregatu z
klucza i nie odrzuca nieznanego prefiksu. Pusty klucz zwraca
`ResultError.Invalid("stream.key.blank")` i nic nie zapisuje.

## Plan

### 1. Projekt

Utwórz `src/shared/JJDevHub.EventStore`. Referencja do `JJDevHub.Shared.Kernel`. Brak innych
referencji projektów. Brak pakietu Npgsql, EF, Testcontainers i ASP.NET. Dopnij projekt do
solution.

### 2. Typy portu

`StreamKey` jest rekordem z jednym łańcuchem. `StoredEvent` niesie klucz, wersję zdarzenia w
strumieniu, pozycję globalną i `IDomainEvent`. `AppendResult` niesie wersję strumienia po
dopisaniu i pozycję ostatniego zdarzenia z dopisanej listy. `StreamSlice` niesie bieżącą wersję
i zdarzenia uporządkowane po wersji rosnąco. `IEventStore` ma `AppendAsync` i `ReadAsync`. Obie
przyjmują `CancellationToken`.

### 3. Pamięć

`InMemoryEventStore` trzyma `Dictionary<StreamKey, List<StoredEvent>>` i `long`. W `lock`
porównuje oczekiwaną wersję z liczbą zdarzeń w liście. Gdy klucz nie istnieje, liczba wynosi
zero. Przy zgodności dopisuje każde zdarzenie z wersją `count + 1`, `count + 2`, i tak dalej.
Każdemu nadaje kolejną pozycję globalną. Przy niezgodności zwraca konflikt i nie zmienia listy
ani licznika.

### 4. Odczyt i pusty klucz

`ReadAsync` zwraca kopię listy, nie żywą listę wewnętrzną. Pusty strumień to sukces, wersja `0`,
pusta lista. Klucz o pustym łańcuchu albo z samych białych znaków to `stream.key.blank` i rodzaj
`Invalid`. Pusta lista zdarzeń przy dopisaniu to też `Invalid`, kod `stream.events.empty`.
Dopisz ten kod do słownika w [README.md](README.md).

### 5. Fakt konfliktu

Test dopisuje jedno zdarzenie z oczekiwaną wersją `0`. Drugie dopisanie do tego samego klucza
żąda znowu `0`. Asercja patrzy wyłącznie na rodzaj `Conflict`. Nie sprawdza w tej samej asercji
pozycji globalnej. Pozycja jest w „Gotowe gdy” jako osobny przegląd implementacji: drugie
zdarzenie innego strumienia, dopisane po sukcesie, ma większą pozycję niż pierwsze.

### Co jest do czego

`IEventStore` woła handler komendy. Ukrywa pamięć i później PostgreSQL. Gdy portu nie ma,
handler woła SQL albo `Save` i test wersji chce kontenera. Gdy w sygnaturze jest
`NpgsqlConnection`, numer 09 nie ma czego podmienić. Gdy port zwraca `NotFound` na pustym
strumieniu, tworzenie artykułu wygląda jak brak notatki na `GET`.

`AppendAsync` woła ten handler po metodzie agregatu. Bierze `UncommittedEvents` i wersję sprzed
tej metody jako oczekiwaną. W teście woła go fakt, bez agregatu `Article`. Gdy metody nie ma,
nie ma gdzie odrzucić starej wersji bez wyjątku. Gdy przy konflikcie dopisuje mimo `Result`,
lista rośnie, a klient dostaje kod, który kłamie. Gdy nie bierze `CancellationToken`, anulowanie
nie ma wejścia.

`ReadAsync` woła handler przed `Replay`. Zwraca historię. Nie zwraca projekcji. Gdy zwraca żywą
listę wewnętrzną, caller dopisze do niej z zewnątrz i ominie `lock`. Gdy na nieznanym kluczu
rzuca, `expectedVersion` `0` nie ma z czego wyniknąć. Kopia i sukces z wersją `0` są tym, czego
`Replay` na nowym agregacie potrzebuje.

`InMemoryEventStore` woła test i, do czasu numeru 09, skład, który jeszcze nie ma komendy
produkcyjnej. Trzyma fakty procesu. Gdy klasy nie ma, fakt nie ma czego zbudować bez SQL. Gdy
stan jest statyczny, testy dzielą wersję. Gdy klasa nie jest `sealed`, podklasa omija `lock`.
Gdy `lock` obejmuje tylko dopisanie, a sprawdzenie jest poza nim, dwa wątki przechodzą z tą samą
wersją.

`StreamKey` woła caller. Rozdziela strumienie. Magazyn traktuje go jako nieprzezroczysty
łańcuch. Gdy magazyn parsuje prefiks i odrzuca nieznany, `probe:{guid}` pada, zanim powstanie
`Article`. Gdy klucz pusty jest sukcesem, zdarzenia lądują w worku bez nazwy. `stream.key.blank`
tego broni i nic nie zapisuje.

`AppendResult.Position` woła w przyszłości worker z [12-projekcja.md](12-projekcja.md). W tym
numerze zwraca ją pamięć, a nikt jej nie zapisuje w `read_document`. Gdy pozycji nie ma, worker
zostaje przy wersji jednego strumienia i gubi fakt sąsiedniego agregatu. Gdy pozycja jest
wspólna dla News i Cv, kursor jednej usługi zależy od drugiej bazy.

`ResultError.Conflict` woła brzeg, gdy powstanie mediator. Daje kod `stream.version.conflict` do
pola `type`. Tu zwraca go magazyn. Gdy zamiast niego leci wyjątek, brzeg robi `500`. Gdy rodzaj
jest `Invalid`, klient nie ponawia odczytu tak, jak przy konflikcie wersji. Pusta lista i pusty
klucz zostają przy `Invalid`, nie przy `Conflict`.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]`. Nie ma cechy
`Category=Integration`. Nie ma cechy `Category=Performance`. Powód padnięcia jest jeden: drugie
dopisanie ze starą oczekiwaną wersją nie zwraca `Conflict`. NBomber jest w
[22-testy.md](22-testy.md). Docker nie jest zależnością. Obraz `postgres:16-alpine` nie wstaje.
Odczyt `news_write` nie wchodzi do metody.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | nowy `InMemoryEventStore`, jeden `StreamKey`, udane `AppendAsync` jednego zdarzenia z `expectedVersion` równym `0` |
| Działanie (act) | drugie `AppendAsync` na tym samym kluczu z `expectedVersion` równym `0` |
| Sprawdzenie (assert) | `IsSuccess` jest fałszem, a `Error.Kind` równa się `Conflict` |

Nazwa metody: `Append_with_stale_version_returns_conflict`.

```text
dotnet test tests/JJDevHub.EventStore.Tests/JJDevHub.EventStore.Tests.csproj --filter "FullyQualifiedName~Append_with_stale_version_returns_conflict"
```

Przygotowanie zakłada, że pierwsze dopisanie się udało. Jeśli pierwsze dopisanie padnie, fakt
jest czerwony zanim sprawdzi konflikt. Wtedy implementacja nie spełnia nawet zapisu wersji `0`,
a asercja konfliktu i tak jest tą, którą sekcja nazywa powodem. Nie dodawaj w tym fakcie asercji
`Position`. Nie otwieraj kontenera. Nie czytaj `news_write`.

Zdarzenie w przygotowaniu to `ProbeStored`, nie `Article`. Klucz jest niepusty. Oczekiwana
wersja pierwszego dopisania to `0`, bo strumień dopiero powstaje. Działanie powtarza `0` na tym
samym kluczu, nie na drugim. Sprawdzenie patrzy na rodzaj, nie na treść kodu w osobnej asercji i
nie na długość listy. Długość listy po konflikcie jest warunkiem ukończenia: liczba zdarzeń się
nie zmienia. Pozycja drugiego strumienia jest osobnym przeglądem. Oba zostałyby drugim i trzecim
powodem, gdyby weszły do tej metody.

Brak cechy integracyjnej jest częścią kontraktu. Filtr, który omija `Category=Integration` i
`Category=Performance`, ma ten fakt wykonać, bo cech nie ma i Dockera nie potrzebuje. Nadanie
cechy wydajnościowej przeniosłoby próg czasu do metody, która sprawdza rodzaj. Nadanie cechy
integracyjnej związałoby `Conflict` z kontenerem, którego csproj nie ma prawa potrzebować.

## Zasady

- Port nie referencjonuje Npgsql, EF, ASP.NET, Kafki ani projektu usługi. Referencja wiąże
  sygnaturę z silnikiem albo z `Article` i numer 09 nie ma czego podmienić.
- Konflikt wersji jest `Result` z rodzajem `Conflict` i kodem `stream.version.conflict`. Wyjątek
  zamiast tego wyniku wychodzi na brzeg jako `500`.
- Nie jest wyjątkiem. `InvalidOperationException` albo `DbUpdateConcurrencyException` mieszają
  wyścig z awarią procesu.
- Pusty strumień przy odczycie jest sukcesem z wersją `0`. `NotFound` na pustym strumieniu myli
  tworzenie artykułu z brakiem wiersza na `GET`.
- Pusty klucz jest `Invalid`. Zapis pod pustym łańcuchem składa wszystkie fakty do jednego worka
  bez nazwy.
- Pozycja globalna rośnie przez strumienie jednego egzemplarza magazynu. Licznik per strumień
  nie porządkuje faktów sąsiednich agregatów.
- Wersja rośnie tylko w swoim strumieniu. Wspólna wersja dla dwóch kluczy robi z nich jeden
  agregat.
- `lock` obejmuje sprawdzenie i dopisanie. Samo dopisanie w `lock`, ze sprawdzeniem przed nim,
  przepuszcza dwa wątki z tą samą oczekiwaną wersją.
- Po `Conflict` lista strumienia ma tyle zdarzeń, ile przed wywołaniem. Dopisanie mimo konfliktu
  kłamie wobec kodu, który handler pokaże klientowi.
- Magazyn nie woła `MarkPersisted`. Czyszczenie listy w magazynie wymagałoby referencji do
  agregatu, której port nie dostaje.
- Magazyn nie woła `Apply`. Odtworzenie w magazynie dubluje ścieżkę numeru 07 i wiąże zapis ze
  stanem pól.
- Kopia zwrócona z `ReadAsync` nie jest wewnętrzną listą. Żywa lista pozwala dopisać z zewnątrz
  i ominąć `lock`.
- Obraz `postgres:16-alpine` nie jest zależnością tego projektu. Kontener w teście konfliktu
  sprawdza inny numer niż wersję w pamięci.
- Redis nie jest magazynem strumienia. Restart kasuje historię, która ma być produktem, a cache
  wolno zgubić.
- Dwie usługi nie dzielą jednego egzemplarza pozycji, gdy już będą miały po swoim magazynie.
  Wspólny licznik wiąże kursor News z dopisaniem Cv.

## Poza zakresem

- Implementacja na PostgreSQL, sekwencja pozycji i tabela strumienia są w
  [09-persistence.md](09-persistence.md). Ten numer nie tworzy `JJDevHub.EventStore.Postgres`.
- Handler, który łączy `Replay`, append i `MarkPersisted`, jest w [10-cqrs.md](10-cqrs.md). Ten
  numer woła port z faktu, nie z handlera produkcyjnego.
- Zapis wiersza `read_document` z kursora pozycji jest w [12-projekcja.md](12-projekcja.md). Ten
  numer pozycji w tabeli odczytu nie zapisuje.
- Outbox w tej samej transakcji co append jest w [14-outbox.md](14-outbox.md). Ten numer nie
  wkłada transakcji ADO.NET do sygnatury.
- Kafka jest w [15-kafka.md](15-kafka.md). Ten numer nie publikuje faktu.
- Puste bazy zapisu zostają puste aż do numeru 09 i są opisane w
  [02-postgres.md](02-postgres.md). Ten numer nie dodaje tabeli do `news_write`.
- `Article` jako agregat, który pierwszy produkcyjnie woła port, jest w
  [18-news.md](18-news.md). Ten numer używa `ProbeStored`.
- Test wydajnościowy dopisywania jest w [22-testy.md](22-testy.md) i nie dostaje cechy
  `Category=Performance` w tym numerze.

## Źródła

- [Event sourcing](https://martinfowler.com/eaaDev/EventSourcing.html). Wiążące są dopisanie do
  strumienia i oczekiwana wersja. Dotyczy `AppendAsync` oraz tego, że konflikt nie dopisuje
  zdarzeń. Ze źródła nie bierzemy EventStoreDB jako osobnego silnika. EventStoreDB odpadł,
  strumień ma leżeć w PostgreSQL usługi od numeru 09, i nie
  bierzemy repozytorium `Save`, które chowa wersję.
- [Optimistic
  concurrency](https://learn.microsoft.com/azure/architecture/patterns/event-sourcing). Wiążące
  jest traktowanie konfliktu wersji jako wyniku oczekiwanego, po którym klient ponawia odczyt.
  Dotyczy `Result` z rodzajem `Conflict` i kodem `stream.version.conflict`. Ze źródła nie
  bierzemy chmury z tamtej strony jako runtime. Runtime tego systemu jest PostgreSQL, a w tym
  numerze pamięć, i nie bierzemy wyjątku współbieżności EF.
- [Event-driven log](https://martinfowler.com/articles/201701-event-driven.html). Wiążące jest
  to, że jeden dziennik ma pozycję szerszą niż wersja jednego agregatu. Dotyczy `Position`
  wspólnej dla strumieni jednego egzemplarza i osobnej wersji w `StreamKey`. Ze źródła nie
  bierzemy pełnego URI jako nazwy zdarzenia i nie bierzemy jednego dziennika dla News i Cv.
  Każda usługa ma własny magazyn.
- [lock
  statement](https://learn.microsoft.com/dotnet/csharp/language-reference/statements/lock).
  Wiążące jest objęcie sprawdzenia i zmiany jedną sekcją. Dotyczy `lock` w `InMemoryEventStore`
  wokół porównania wersji i dopisania. Ze źródła nie bierzemy sprawdzenia wersji przed wejściem
  do sekcji. `ConcurrentDictionary` bez wspólnej sekcji przepuszcza dwa dopisania z tą samą
  oczekiwaną wersją.
- [PostgreSQL sequences](https://www.postgresql.org/docs/16/sql-createsequence.html). Wiążące
  jest to, czym pozycja stanie się w numerze 09: jedna sekwencja w bazie zapisu usługi. Dotyczy
  kosztu, który zostaje po gęstym liczniku w pamięci. Ze źródła nie bierzemy odwołania do
  sekwencji w porcie i nie bierzemy sekwencji wspólnej dla wszystkich usług. W tym numerze
  sekwencji nie ma, jest `long` w egzemplarzu.
- Young, *Versioning in an Event Sourced System*. Wiążące jest oczekiwanie numeru wersji przy
  dopisaniu i odrzucenie dopisania, gdy numer jest nieaktualny. Dotyczy `expectedVersion` `0` na
  pustym strumieniu i `Conflict` przy powtórnym `0`. Ze książki nie bierzemy wersji kontraktu
  `v1` jako pola strumienia. Ta wersja jest w nazwie faktu, w numerze 06, a wydanie nie ma
  stabilnego URL.
- Kleppmann, *Designing Data-Intensive Applications*. Wiążące jest odróżnienie offsetu dziennika
  od wersji jednego bytu oraz to, że znacznik czasu albo identyfikator losowy słabo nadaje się
  na gęsty kursor. Dotyczy `Position` obok wersji strumienia i odrzucenia `Guid` oraz
  `DateTimeOffset` jako kursora. Ze książki nie bierzemy jednego dziennika dla wszystkich usług
  i nie bierzemy klastra w tym numerze. Licznik jest lokalny dla egzemplarza magazynu, a wydanie
  nie ma stabilnego URL.
- [xUnit](https://xunit.net/). Wiążące są `[Fact]` oraz brak cech, których ten numer nie nadaje.
  Dotyczy `Append_with_stale_version_returns_conflict` i jednego powodu: drugie dopisanie nie
  zwraca `Conflict`. Ze źródła nie bierzemy asercji `Position` w tej metodzie i nie bierzemy
  `Category=Integration` ani `Category=Performance`. Kontener nie wstaje.
- Evans, *Domain-Driven Design*. Wiążące jest trzymanie niezmiennika agregatu przy zapisie, bez
  chowania wyścigu w repozytorium, które zwraca tylko „zapisane albo wyjątek”. Dotyczy jawnej
  oczekiwanej wersji w `AppendAsync`. Ze książki nie bierzemy `GetById` i `Save` jako portu tego
  numeru. Te operacje odpadły, a wydanie nie ma stabilnego URL.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: port zapisu nie jest
  klientem jednego produktu bazy w sygnaturze wołanej przez komendę. Dotyczy `IEventStore` bez
  Npgsql i bez nazwy `news_write`. Z tego repozytorium nie bierzemy MediatR ani
  IntegrationEventLogEF. Nie bierzemy też tabeli strumienia w tym numerze, bo pamięć wystarcza,
  żeby zobaczyć konflikt.

## Gotowe gdy

- Fakt `Append_with_stale_version_returns_conflict` kończy się kodem zero.
- Przy konflikcie liczba zdarzeń w strumieniu się nie zmienia.
- Odczyt nieznanego klucza zwraca wersję `0` i pustą listę.
- Dwa udane dopisania do dwóch kluczy dostają rosnące pozycje globalne, a wersja każdego
  strumienia liczy się osobno.
- `JJDevHub.EventStore.csproj` nie zawiera `Npgsql`.
- W projekcie nie ma łańcucha połączenia.
- `stream.version.conflict` i `stream.key.blank` są w słowniku [README.md](README.md).
- Puste bazy z numeru 02 nadal nie mają tabeli strumienia.
- Klasa magazynu jest `sealed`.
- Metody `async` przyjmują `CancellationToken`.
