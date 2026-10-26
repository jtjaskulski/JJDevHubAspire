# 02. PostgreSQL

Poprzedni numer, [Aspire](01-aspire.md), uruchamia host i zasób Redis `cache`. Ten numer dokłada
jeden serwer PostgreSQL i pięć pustych baz zapisu. Następny numer, [odczyt](03-odczyt.md),
dokłada pięć baz odczytu na tym samym serwerze. Po tym numerze da się otworzyć połączenie do
`identity_write`, `news_write`, `learning_write`, `cv_write` i `contact_write`. Nie da się
jeszcze zapisać zdarzenia, projekcji ani sekretu. Nazwy baz są w [README.md](README.md), a
granica zapisu i odczytu w [architektura.md](architektura.md).

Scenariusz, który bez tego numeru się psuje, wygląda jak pierwsza tabela „żeby już coś było”.
Ktoś tworzy bazę `jjdevhub` i wkłada do niej News razem z Cv. Ten sam connection string sięga
strumienia artykułu i strumienia umiejętności. Błąd w zapytaniu News czyta historię CV, bo
prefiks tabeli jest tylko konwencją. Hasło ląduje w `appsettings.Development.json`, a runner CI
jest zielony wyłącznie na laptopie, na którym ten PostgreSQL już stoi. Pięć usług jeszcze nie
istnieje, a granica między nimi już zdążyła zniknąć.

Ten numer rozdziela silnik od schematu, zanim powstanie pierwszy agregat. Silnik jest jeden:
proces `postgres:16-alpine` pod nazwą zasobu `postgres`. Baz zapisu jest pięć i są puste. Puste
znaczy: po `CREATE DATABASE` da się wykonać `SELECT 1`, a w `pg_tables` dla schematu `public`
nie ma tabeli aplikacji. Aspire ma wstrzyknąć connection string do przyszłego procesu. W gicie
nie ma hasła. Test na runnerze nie zakłada, że klaster już stoi. Sam podnosi kontener.

Usługa, której jeszcze nie ma, nie dostaje referencji. AppHost tylko ogłasza zasoby.
`WithReference` do Identity, News, Learning, Cv i Contact dochodzi w numerach tych usług. Dzięki
temu ten numer nie otwiera drogi, którą News mógłby dostać ciąg do `cv_write`. Redis `cache`
zostaje tak, jak ustawił go numer 01. Obok niego pojawia się jeden serwer i pięć nazw. Dashboard
ma pokazać zasób `postgres`. Nie ma jeszcze czego czytać.

## Po co

Każda usługa ma dostać własny connection string zapisu, zanim powstanie jej pierwszy agregat.
Jeśli baza powstanie razem z pierwszą tabelą domenową, łatwo włożyć pięć usług do jednego
`Database=jjdevhub`. Ten numer rozdziela silnik od schematu. Silnik jest jeden. Baz zapisu jest
pięć. Są puste. Puste znaczy: po `CREATE DATABASE` da się wykonać `SELECT 1`, a w `pg_tables`
nie ma tabeli aplikacji. Tabela strumienia, outbox i wiersz próbny `Article` byłyby schematem,
którego nikt jeszcze nie konsumuje.

Aspire ma wstrzyknąć connection string do przyszłego procesu. W gicie nie ma hasła. Ciąg składa
się z `Host`, `Port`, `Database`, `Username` i `Password`, ale wartości nie leżą w
`appsettings.json` ani w `appsettings.Development.json`. Hasło kontenera deweloperskiego
generuje Aspire albo kontener testowy. Nie jest stałą w repozytorium. Bez `aspire run` przyszła
usługa nie ma ciągu. Test nie korzysta z AppHost: sam startuje kontener. Dwa wejścia, jedna
nazwa bazy. Obraz i nazwy muszą być wspólne. Ciąg połączenia wolno mieć inny.

Test na runnerze CI nie zakłada, że na hoście już stoi PostgreSQL. Runner `ubuntu-latest` nie ma
lokalnego klastra o nazwach `identity_write`, `news_write`, `learning_write`, `cv_write` i
`contact_write`. Test, który łączy się z bazą dewelopera, jest zielony tylko na jednej maszynie.
Dlatego fakt sam podnosi `postgres:16-alpine`, na bazie utrzymaniowej kontenera wykonuje `CREATE
DATABASE` pięć razy, otwiera osobne połączenie do każdej bazy i czyta `SELECT 1`. Docker jest tu
zależnością świadomą. Fakt ma cechę `Category=Integration` i nie wchodzi do krótkiej pętli
jednostkowej.

Usługa, której jeszcze nie ma, nie dostaje referencji. AppHost tylko ogłasza zasoby.
`WithReference` do Identity jest w [17-identity.md](17-identity.md), do News w
[18-news.md](18-news.md), do Learning w [19-learning.md](19-learning.md), do Cv w
[20-cv.md](20-cv.md), do Contact w [21-kontakt.md](21-kontakt.md). Gdyby ten numer podpiął
projekt, musiałby go najpierw utworzyć, a wtedy News mógłby dostać ciąg do `cv_write` przez
pomyłkę w jednym pliku. Ogłoszenie zasobu bez referencji zostawia nazwę w składzie i nie otwiera
sąsiedniej bazy.

Pusta baza jest uczciwym stanem, nie brakiem dokończenia. `aspire run` po tym numerze pokazuje
serwer i pięć baz, w których nie ma czego czytać. To zamyka pokusę, żeby „skoro połączenie już
jest”, wstawić wiersz demonstracyjny. Agregatu `Article` jeszcze nie ma. Port strumienia w
pamięci jest w [08-strumien.md](08-strumien.md), a ten sam port na PostgreSQL w
[09-persistence.md](09-persistence.md). Skrypt `db/read/001_read_document.sql` nie jest podpięty
do baz zapisu. Odczyt dostanie własne bazy w następnym numerze, na tym samym `AddPostgres`.

Jedna awaria dysku i CPU jest przyjętym kosztem jednego procesu na hoście deweloperskim.
Izolacja, której potrzebuje reguła „usługa nie otwiera bazy sąsiada”, jest nazwą bazy w
connection stringu, nie drugim postmasterem. Osobna maszyna na każdą usługę nie jest obietnicą
tego numeru. Logiczna granica ma być prawdziwa już teraz, bo później trudniej ją wyciąć z
wspólnego `public`. Backup będzie per baza albo per klaster, nie per tabela. Nazwy są stałe i
zapisane w słowniku [README.md](README.md).

## Dlaczego ta technologia

### Jeden serwer PostgreSQL

Zasób Aspire `postgres` to jeden proces `postgres:16-alpine`. Pięć baz wisi na tym procesie.
Pakiet hostingu `Aspire.Hosting.PostgreSQL` jest na MIT. Sterownik `Npgsql` jest na licencji
PostgreSQL. W `AppHost.cs` jest jedno wywołanie `AddPostgres`, z argumentem
`DatabaseNames.Postgres`, którego wartość to `postgres`. Obraz w teście i w AppHost to ten sam
tag. Dialekt SQL ma być ten sam w developmentcie, w fakcie na runnerze i później na maszynie.
Wersje pakietu hostingu, Npgsql i Testcontainers stoją w `Directory.Packages.props`.

Development, test i później maszyna mają mówić tym samym dialektem SQL. Osobny silnik na odczyt
albo na jedną usługę mnoży procesy, kopie zapasowe i wersje obrazu bez dawania izolacji, której
nie daje już osobna baza. Odczyt i tak dojdzie jako drugie pięć baz na tym samym serwerze, nie
jako drugi postmaster. Redis zostaje cache z numeru 01 i nie staje się magazynem strumienia.
RabbitMQ nie pojawia się w AppHost. MongoDB i OpenSearch nie pojawiają się w csproj. Skład ma
jeden wolny silnik relacyjny.

Konkret JJDevHub: Identity, News, Learning, Cv i Contact dostaną kiedyś po swoim zapisie, ale
dziś dzielą jeden proces i nie dzielą nazwy bazy. `identity_write` nie jest schematem wewnątrz
`news_write`. Restart tego jednego kontenera kładzie wszystkie pięć baz naraz. Na laptopie
dewelopera to jest przyjęte. Na maszynie osobny numer opisze, jak ten sam obraz jest prowadzony.
Ten numer nie udaje klastra. Udowadnia, że nazwy i obraz są wspólne, oraz że po połączeniu da
się wykonać `SELECT 1`.

Odpadło pięć procesów PostgreSQL, po jednym na usługę. Izolacja, której potrzebuje reguła
„usługa nie otwiera bazy sąsiada”, jest nazwą bazy w connection stringu, nie drugim
postmasterem. Pięć kontenerów oznacza pięć haseł, pięć portów i pięć tagów do pilnowania. Test
CI podnosiłby pięć razy ten sam obraz, żeby sprawdzić `SELECT 1`. Granica i tak siedzi w polu
`Database`. Drugi postmaster nie zatrzyma zapytania, które dostało zły connection string.
Zatrzyma je to, że projekt News tego stringa w ogóle nie dostaje, gdy referencja w ogóle
powstanie.

Odpadł też SQL Server. Jego licencja nie jest na liście MIT, Apache-2.0, BSD i PostgreSQL, a
skład i tak ma jeden wolny silnik. Pakiet hostingu pod inny silnik rozjechałby
`Directory.Packages.props` i obraz w teście. Dialekt i narzędzia kopii zapasowej byłyby inne niż
na maszynie, jeśli maszyna ma zostać przy PostgreSQL. Ten numer nie trzyma dwóch silników „na
czas migracji”. Jest jeden tag `postgres:16-alpine`.

Odpadł SQLite. Nie ma `CREATE DATABASE` w tym samym znaczeniu, słabo znosi równoległe testy
kontenerowe i nie jest silnikiem na maszynie. Plik `jjdevhub.db` w katalogu roboczym wraca do
problemu jednej bazy dla pięciu usług albo do pięciu plików, których Aspire nie ogłasza jako
zasobu `postgres`. Fakt łączności ma dotyczyć tego samego obrazu, który stawia AppHost. SQLite
przeszedłby test na laptopie i nic nie powiedział o kontenerze, który zobaczy CI.

Koszt jednego procesu jest wspólna awaria dysku i CPU. Izolacja logiczna nie zastępuje osobnej
maszyny. Na jednym hoście deweloperskim to jest przyjęty koszt. Dziesięć baz, gdy dojdzie
odczyt, nadal wisi na tym samym procesie: pięć zapisu z tego numeru i pięć odczytu z następnego.
Backup jest per baza albo per klaster, nie per tabela. Kto doda drugi `AddPostgres`, złamie
zasadę jednego zasobu i rozdwoi obraz, tag i hasło. W AppHost zostaje jedno wywołanie.

### Osobna baza na usługę

`AddDatabase` wołane pięć razy na zasobie `postgres`. Nazwy: `identity_write`, `news_write`,
`learning_write`, `cv_write`, `contact_write`. Nazwa bazy jest nazwą zasobu Aspire i nazwą
connection stringa. Stałe w `DatabaseNames` nazywają się `Postgres`, `IdentityWrite`,
`NewsWrite`, `LearningWrite`, `CvWrite` i `ContactWrite`. Wartości to `postgres`,
`identity_write`, `news_write`, `learning_write`, `cv_write`, `contact_write`. AppHost i test
biorą te stałe, żeby literówka `identity_write` nie rozjechała składu z `CREATE DATABASE`.

Błąd w zapytaniu News nie może przeczytać strumienia CV. Najpewniejszy prosty hamulec to inny
connection string, którego projekt News w ogóle nie dostaje. W tym numerze nie dostaje go żadna
usługa, bo `WithReference` nie jest wołane. Granica jest już w nazwach. Gdy referencja dojdzie,
News zobaczy tylko `news_write`, a później swój `news_read`. Nie zobaczy `cv_write`. Jedna
usługa, gdy już powstanie, dostaje tylko swój `*_write` i później swój `*_read`. W tym numerze
nie dostaje żadnego.

Konkret domeny: artykuł, konto, kurs i sekcja CV nie mają jeszcze tabel, ale mają już osobne
bazy na swoje przyszłe strumienie. `learning_write` jest miejscem Learning, nie wspólnym workiem
z Contact. `contact_write` nie trzyma projekcji zapytań, bo projekcja pójdzie do bazy odczytu.
Zapis trzyma historię, której schematu jeszcze nie ma. Dlatego baza jest pusta, a nazwa już jest
właściwa. Zamiana `cv_write` na schemat `cv` wewnątrz jednej bazy zostawiłaby jeden ciąg, którym
da się sięgnąć także `news`.

Odpadła jedna baza i pięć schematów `identity`, `news`, `learning`, `cv`, `contact`. Ten sam
ciąg połączenia sięga każdego schematu, jeśli ktoś poda nazwę w SQL. Uprawnienie da się zawęzić,
ale projekt, który ma connection string do serwera i do tej bazy, nadal otwiera połączenie, na
którym nazwa schematu jest tylko tekstem zapytania. Reguła JJDevHub ma być mocniejsza: sąsiad
nie dostaje ciągu. Schemat wewnątrz wspólnej bazy tej reguły nie spełnia. `AddDatabase` tworzy
osobny byt, którego nazwa staje się polem `Database`.

Odpadła też jedna baza i jeden schemat `public` z prefiksem tabel `news_`. Prefiks jest
konwencją, nie granicą połączenia. Zapytanie bez prefiksu albo z cudzym prefiksem przechodzi,
jeśli autor ma ten sam ciąg. Test `SELECT 1` na takiej bazie byłby zielony i nic by nie
powiedział o granicy. Pięć wywołań `AddDatabase` jest widocznych w `AppHost.cs` i w teście jako
pięć nazw. Prefiks tabeli łatwo pominąć przy pierwszym `CREATE TABLE`. Osobnej bazy nie da się
pominąć, bo jej po prostu nie ma w połączeniu.

Koszt to dziesięć baz, gdy dojdzie odczyt: dziesięć wpisów w AppHost i dziesięć connection
stringów na maszynie. Backup jest per baza albo per klaster, nie per tabela. Nazwy są stałe.
Zmiana `news_write` na inną nazwę psuje słownik, test i przyszłe `WithReference` naraz. Dlatego
stałe żyją w `src/shared/JJDevHub.Databases/DatabaseNames.cs`, a biblioteka nie umie otworzyć
połączenia. Nie ma metody, która zwraca connection string. Łańcuch z hasłem nie ma prawa powstać
w tym projekcie. Stałe odczytu mogą być w tym samym typie, ale zasoby odczytu dodaje dopiero
[03-odczyt.md](03-odczyt.md). Jeśli stała odczytu już jest, AppHost w tym numerze jej nie używa.

### Pusta baza

Po utworzeniu baza ma katalog systemowy PostgreSQL i nie ma tabeli `read_document`, tabeli
strumienia ani outboxa. Test wykonuje `SELECT 1`. Nie wykonuje `CREATE TABLE`. Nie dodaje
`WithCreationScript`. Nie uruchamia narzędzia EF, które tworzy tabele. Nie tworzy projektu
`JJDevHub.EventStore.Postgres`. Po starcie baza przyjmuje połączenie i nie ma tabeli aplikacji.
Zapytanie `SELECT count(*) FROM pg_tables WHERE schemaname = 'public'` w pustej bazie zwraca
zero. Nie jest to drugi powód padnięcia faktu łączności. Jest warunkiem w sekcji „Gotowe gdy”.

Ten numer ma udowodnić łączność i nazwy. Tabela strumienia bez portu `IEventStore` byłaby
schematem, którego nikt jeszcze nie konsumuje, i rozjechałaby się z numerem persistence.
`JJDevHub.EventStore` jeszcze nie istnieje albo, jeśli ktoś go dodał wcześniej, ten numer go nie
zmienia. Plik `db/read/001_read_document.sql` jeszcze nie jest podpięty do tych baz. Wiersz w
`public` oznacza, że schemat doszedł za wcześnie, nawet gdy `SELECT 1` zwraca `1`. Łączność i
pustość są dwoma warunkami. Fakt pilnuje pierwszego. Przegląd katalogu pilnuje drugiego.

Konkret: w `news_write` nie ma artykułu, w `cv_write` nie ma umiejętności, w `identity_write`
nie ma konta. Nie ma też wiersza próbnego, którym dałoby się „pokazać dashboardowi, że baza
żyje”. Życie bazy pokazuje `SELECT 1` i zasób na ekranie Aspire. Dane demonstracyjne w pustym
zapisie zmyliłyby następny numer, który spodziewa się katalogu systemowego i zera tabel
aplikacji. Outbox w transakcji dojdzie w [14-outbox.md](14-outbox.md) i potrzebuje tabeli,
której tu nie ma. Dziś transakcji zapisu nie ma, bo nie ma schematu i nie ma portu.

Odpadło tworzenie tabeli zdarzeń w tym numerze. To jest [09-persistence.md](09-persistence.md).
Tabela założona teraz miałaby kolumny wymyślone przed `StoredEvent` i przed `AppendAsync`. Numer
09 albo by się do nich dopasował, albo by je porzucił. Jedno i drugie jest rozjazdem. Skrypt
tworzenia przy `AddDatabase` utrwaliłby ten kształt w AppHost. Dlatego krok planu zabrania
`WithCreationScript` na bazach zapisu. Bazy odczytu dostaną skrypt w następnym numerze. Zapis
zostaje bez niego.

Odpadło też zasilenie wierszem próbnym `Article`. Agregatu `Article` jeszcze nie ma, a pusty
zapis nie jest miejscem na dane demonstracyjne. Wiersz w `news_write` wyglądałby jak projekcja
albo jak zdarzenie, a nie jest ani jednym, ani drugim. Test, który wstawia wiersz, przestałby
być testem łączności. Dostałby drugi powód padnięcia: zły kształt kolumny. Nazwa metody
`Write_databases_accept_select_one` mówi, co jest sprawdzane. Jedna liczba `1` z każdej bazy.
Nic więcej.

Koszt jest pusty ekran. `aspire run` po tym numerze pokazuje serwer i pięć baz, w których nie ma
czego czytać. To jest uczciwy stan, nie brak dokończenia. Deweloper, który zajrzy do `psql` i
zobaczy sam katalog systemowy, widzi numer skończony, a nie numer urwany. Dopiero tabela
aplikacji znaczy, że ktoś poszedł dalej, niż ten plik pozwala. Warunek „w żadnej z tych baz nie
ma tabeli w schemacie `public`” jest bramką przeglądu, nie asercją faktu `SELECT 1`.

### Connection string ze składu

Aspire buduje ciąg `Host`, `Port`, `Database`, `Username`, `Password` i przekazuje go procesowi,
który ma `WithReference`. W tym numerze jedynym konsumentem w teście jest kod testu, który sam
tworzy bazy na kontenerze Testcontainers. Hasło kontenera deweloperskiego generuje Aspire albo
kontener testowy. Nie jest stałą w repozytorium. Hasło zostaje parametrem zasobu Aspire. Nie
dodaje się wolumenu z hasłem w pliku gita. Żaden plik json w repozytorium nie zawiera hasła
PostgreSQL. W repozytorium nie ma też gotowego connection stringa z hasłem.

Hasło w `appsettings.Development.json` zostaje w historii gita. Każdy deweloper musiałby mieć
ten sam lokalny PostgreSQL albo poprawiać plik i ryzykować commit. Pusty klon ma wstać przez
`aspire run`, które wygeneruje parametr, a nie przez kopiowanie cudzego ciągu. Test idzie inną
drogą i też nie czyta pliku z hasłem: builder kontenera wydaje własne poświadczenie w pamięci
uruchomienia. Dwa wejścia mają tę samą nazwę bazy i ten sam obraz. Ciąg wolno mieć inny, bo
host, port i hasło są właściwością procesu, a `identity_write` właściwością kontraktu.

Konkret JJDevHub: przyszły proces News dostanie ciąg do `news_write` ze składu, a nie z pliku
obok csproj. Do tego czasu nawet News nie ma projektu, więc nie ma gdzie tego pliku położyć.
Pokusa pojawia się wcześniej, w AppHost, przez `launchSettings` albo przez `.env`. Ten numer jej
nie spełnia. Parametr zasobu Aspire trzyma hasło poza drzewem. Stałe w `DatabaseNames` trzymają
nazwy, nie wartości sekretu. `JJDevHub.Databases` nie referencjonuje Npgsql, EF ani ASP.NET,
więc nie ma w nim miejsca na otwarcie połączenia „dla wygody”.

Odpadło wpisywanie connection stringa w `appsettings.json` i w `appsettings.Development.json`.
Odpadł też plik `.env` commitowany obok AppHost. Oba trzymają sekret w drzewie. Zaszyfrowana
wartość w repozytorium nadal byłaby sekretem, który trzeba czymś otworzyć, i ten numer jej nie
wprowadza. Gotowy ciąg z hasłem w dokumentacji albo w komentarzu testu jest tym samym błędem:
historia gita go nie zapomina. Asercja faktu porównuje liczbę `1`, nie treść ciągu.

Koszt: bez `aspire run` usługa nie ma ciągu. Test nie korzysta z AppHost i sam startuje
kontener. Trzeba pilnować, żeby obraz i nazwy były wspólne, gdy wejścia są dwa. Rozjazd tagu
`postgres:16` w teście i `postgres:15` w AppHost albo odwrotnie znaczy, że CI sprawdza inny
dialekt niż dashboard. Dlatego oba miejsca używają `postgres:16-alpine`. Rozjazd nazwy
`identity_write` między stałą a literałem w teście jest tym, czemu służy `DatabaseNames`. Metody
zwracającej ciąg tu nie dodajemy, bo ciąg bez hasła jest niekompletny, a ciąg z hasłem nie może
powstać w bibliotece.

### Testcontainers

Projekt `tests/JJDevHub.Integration.Tests` podnosi `PostgreSqlBuilder` z obrazem
`postgres:16-alpine`. Na domyślnej bazie kontenera, bazie utrzymaniowej, wykonuje `CREATE
DATABASE` pięć razy. Potem otwiera osobne połączenie do każdej bazy i czyta `SELECT 1`. Fakt ma
cechę `Category=Integration`. Pakiety w projekcie testu to xUnit, Testcontainers.PostgreSql i
Npgsql. `JJDevHub.Databases` nie referencjonuje żadnego z nich. Kontener jest zatrzymywany w
`finally` albo przez `await using`. Metoda nazywa się `Write_databases_accept_select_one`.

Runner `ubuntu-latest` nie ma lokalnego klastra o nazwach `identity_write` i dalej. Test, który
łączy się z bazą dewelopera, jest zielony tylko na jednej maszynie. Współdzielony PostgreSQL na
hoście dewelopera jako baza CI odpada, bo CI nie ma tego procesu, a równoległe joby kasowałyby
sobie bazy. Kontener daje proces, którego runner nie musi mieć z góry. Obraz jest ten sam, który
stawia AppHost. Dzięki temu fakt nie utrwala lokalnego portu `5432` ani lokalnego użytkownika
wpisanego w źródle.

Konkret przebiegu: przygotowanie startuje builder i tworzy pięć baz zapisu. Działanie otwiera
pięć połączeń Npgsql z `Database` ustawionym na te nazwy i na każdym wykonuje `SELECT 1`.
Sprawdzenie żąda liczby całkowitej `1`. Test nie wstawia wiersza. Test nie czyta `news_read` ani
innej bazy odczytu, bo ten numer ich nie tworzy. Jeśli pierwsza baza zwróci `1`, a czwarta nie
przyjmie połączenia, fakt jest czerwony z jednego powodu: któraś z pięciu baz zapisu nie zwraca
`1`. Nie dokłada się drugiej asercji o czasie odpowiedzi. NBomber i cecha `Category=Performance`
są w [22-testy.md](22-testy.md).

Odpadł współdzielony PostgreSQL na hoście dewelopera jako baza CI. Równoległe joby nie mogą
zakładać, że `cv_write` jest pusta i należy do nich. `DROP DATABASE` jednego joba kasuje stan
drugiego. Lokalny klaster ma też inne hasło niż parametr Aspire i inny tag niż
`postgres:16-alpine`. Zielony wynik na jednym laptopie nie jest bramką. Bramką jest komenda z
sekcji testów, która sama podnosi kontener. Filtr `Category!=Integration&Category!=Performance`
nie wymaga tego faktu i nie psuje się przez brak Dockera w krótkiej pętli jednostkowej.

Odpadł też kontener innego silnika w tym numerze. Łączność ma dotyczyć tego samego obrazu, który
stawia AppHost. Kontener SQL Server albo SQLite sprawdziłby bibliotekę klienta, a nie ścieżkę
`AddPostgres` plus `AddDatabase`. Obraz alpine i tag 16 są częścią kontraktu, nie szczegółem
wygody. Zmiana tagu tylko w teście albo tylko w AppHost rozjeżdża „gotowe”. Oba miejsca mają
`postgres:16-alpine`.

Koszt: test integracyjny potrzebuje Dockera i nie wchodzi do filtra `Category!=Integration`.
Jest wymagany na bramce, która puszcza testy integracyjne. Lokalnie uruchamia się komendą z
sekcji testów. Krótka pętla jednostkowa zostaje szybka i nie podnosi kontenera. Kto zdejmie
cechę `Category=Integration`, wciągnie Dockera do filtra, który ma działać bez niego. Kto doda
drugą cechę wydajnościową, zwiąże `SELECT 1` z progiem czasu. Powód padnięcia ma zostać jeden.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `JJDevHub.AppHost/AppHost.cs` | `AddPostgres("postgres")` i pięć `AddDatabase` zapisu |
| `src/shared/JJDevHub.Databases/DatabaseNames.cs` | stałe nazw dziesięciu baz, w tym piątki zapisu |
| `src/shared/JJDevHub.Databases/JJDevHub.Databases.csproj` | biblioteka bez Npgsql i bez EF |
| `tests/JJDevHub.Integration.Tests/JJDevHub.Integration.Tests.csproj` | xUnit, Testcontainers.PostgreSql, Npgsql |
| `tests/JJDevHub.Integration.Tests/WriteDatabaseConnectivityTests.cs` | fakt `SELECT 1` na pięciu bazach |
| `Directory.Packages.props` | wersje Aspire.Hosting.PostgreSQL, Npgsql, Testcontainers |

`DatabaseNames` nie otwiera połączenia. Trzyma łańcuchy, żeby AppHost i test nie rozjechały się
w literówce `identity_write`. Stałe odczytu mogą być w tym samym typie, ale zasoby odczytu
dodaje dopiero [03-odczyt.md](03-odczyt.md). Jeśli stała odczytu już jest, AppHost w tym numerze
jej nie używa. Biblioteka nie zwraca connection stringa i nie zna hasła.

## Plan

### 1. Stałe nazw

Utwórz `src/shared/JJDevHub.Databases`. W `DatabaseNames` dodaj publiczne stałe: `Postgres`,
`IdentityWrite`, `NewsWrite`, `LearningWrite`, `CvWrite`, `ContactWrite`. Wartości to
`postgres`, `identity_write`, `news_write`, `learning_write`, `cv_write`, `contact_write`. Nie
dodawaj metody, która zwraca connection string.

### 2. Zasób w AppHost

W `AppHost.cs` dodaj `builder.AddPostgres(DatabaseNames.Postgres)`. Obraz ustaw na
`postgres:16-alpine`. Na tym zasobie wywołaj `AddDatabase` dla pięciu stałych zapisu. Zostaw
`AddRedis("cache")` z numeru 01. Nie wywołuj `WithReference` na projekcie usługi. Nie dodawaj
wolumenu z hasłem w pliku gita. Hasło zostaje parametrem zasobu Aspire.

### 3. Brak schematu

Nie dodawaj `WithCreationScript`. Nie uruchamiaj narzędzia EF, które tworzy tabele. Nie twórz
projektu `JJDevHub.EventStore.Postgres`. Po starcie baza przyjmuje połączenie i nie ma tabeli
aplikacji.

### 4. Pakiety

Do `Directory.Packages.props` dopisz `Aspire.Hosting.PostgreSQL`, `Npgsql`, `Testcontainers` i
`Testcontainers.PostgreSql`. Projekt AppHost referencjonuje pakiet hostingu PostgreSQL. Projekt
testu referencjonuje xUnit, Testcontainers.PostgreSql i Npgsql. `JJDevHub.Databases` nie
referencjonuje żadnego z nich.

### 5. Fakt łączności

W teście atrybut `[Trait("Category", "Integration")]`. Builder kontenera używa
`postgres:16-alpine`. Po starcie, na bazie utrzymaniowej kontenera, wykonaj `CREATE DATABASE`
dla pięciu nazw. Otwórz pięć połączeń z `Database` ustawionym na te nazwy. Na każdym wykonaj
`SELECT 1` i odbierz jedną liczbę. Nie twórz tabel. Zatrzymaj kontener w `finally` albo przez
`await using`.

### Co jest do czego

`AddPostgres` woła `AppHost.cs`. Tworzy jeden proces, na którym wiszą bazy. Dashboard pokazuje
zasób `postgres`. Gdy wywołania nie ma, pięć `AddDatabase` nie ma do czego się podpiąć i `aspire
run` nie pokazuje serwera. Drugie wywołanie `AddPostgres` rozdwaja silnik, którego ten numer ma
właśnie jednego.

`AddDatabase` woła ten sam plik, raz na bazę zapisu. Tworzy bazę i nazwę connection stringa. Nie
tworzy tabeli. Gdy brakuje jednej z pięciu nazw, usługa, która kiedyś poprosi o swój zapis,
dostanie obcy ciąg albo nie dostanie żadnego. Gdy ktoś doda skrypt tworzenia, baza przestaje być
pusta i numer 09 zastaje schemat, którego nie projektował.

`DatabaseNames` wołają AppHost i test. Pilnują, żeby łańcuch w składzie i łańcuch w `CREATE
DATABASE` były tym samym literałem. Gdy stałej nie ma, nazwa żyje w dwóch miejscach i literówka
`identity_write` przechodzi w jednym z nich. Gdy metoda zwraca connection string, biblioteka bez
Npgsql zaczyna znać hasło albo znać ciąg, którego nie wolno commitować.

`PostgreSqlBuilder` woła fakt testowy. Daje proces, którego CI nie musi mieć z góry. Gdy
buildera nie ma, test albo łączy się z bazą dewelopera, albo w ogóle nie wstaje na
`ubuntu-latest`. Gdy obraz jest inny niż `postgres:16-alpine`, fakt sprawdza inny silnik niż
AppHost.

`NpgsqlConnection` w teście woła `SELECT 1`. To jest jedyny klient SQL tego numeru. Usługa
domenowa jeszcze go nie ma. Gdy połączenie idzie do innej bazy niż pięć nazw zapisu, fakt
pilnuje cudzego bytu. Gdy zamiast `SELECT 1` wykonuje `CREATE TABLE`, schemat wchodzi tylnymi
drzwiami i warunek pustego `public` przestaje być prawdziwy.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]` i cechę `Category=Integration`.
Powód padnięcia jest jeden: któraś z pięciu baz zapisu nie zwraca `1` z `SELECT 1`. NBomber i
cecha `Category=Performance` nie wchodzą. Są w [22-testy.md](22-testy.md). Brak Dockera na
maszynie bez cechy integracyjnej nie jest porażką tego faktu, bo filtr jednostkowy go nie
uruchamia. Porażką jest czerwona komenda z sekcji testów na bramce, która Dockera ma.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | start `PostgreSqlBuilder` z obrazem `postgres:16-alpine`, `CREATE DATABASE` dla `identity_write`, `news_write`, `learning_write`, `cv_write`, `contact_write` |
| Działanie (act) | osobne połączenie Npgsql do każdej z tych baz i `SELECT 1` |
| Sprawdzenie (assert) | każde zapytanie zwraca liczbę całkowitą `1` |

Nazwa metody: `Write_databases_accept_select_one`.

```text
dotnet test tests/JJDevHub.Integration.Tests/JJDevHub.Integration.Tests.csproj --filter "FullyQualifiedName~Write_databases_accept_select_one"
```

Test nie wstawia wiersza. Test nie czyta `news_read` ani innej bazy odczytu, bo ten numer ich
nie tworzy. Jeśli `SELECT 1` przechodzi, a w bazie jest tabela aplikacji, numer nie jest
skończony: schemat doszedł za wcześnie. To widać zapytaniem `SELECT count(*) FROM pg_tables
WHERE schemaname = 'public'`, które w pustej bazie zwraca zero. Nie jest to drugi powód
padnięcia faktu łączności. Jest warunkiem w sekcji „Gotowe gdy”.

Przygotowanie używa bazy utrzymaniowej kontenera tylko po to, żeby wykonać `CREATE DATABASE`.
Połączenia właściwe ustawiają `Database` na pięć nazw ze słownika. Działanie nie współdzieli
jednego połączenia między bazami, bo jedno połączenie nie zmienia pola `Database` w locie w
sposób, który ten fakt ma pokazać: każda nazwa jest osobnym wejściem. Sprawdzenie porównuje
wynik z liczbą `1`, nie z tekstem komunikatu serwera. Kontener kończy się w `finally` albo przez
`await using`, żeby job nie zostawił procesu na runnerze.

Cecha `[Trait("Category", "Integration")]` jest częścią kontraktu faktu, nie ozdobą. Filtr
`Category!=Integration&Category!=Performance` ma przejść bez tego testu i bez Dockera. Zdjęcie
cechy psuje krótką pętlę. Dodanie asercji o `pg_tables` do tego samego faktu dałoby drugi powód
padnięcia. Katalog pustego `public` zostaje warunkiem ukończenia numeru, sprawdzanym osobno od
jedynki z `SELECT 1`.

## Zasady

- Jest jedno wywołanie `AddPostgres`. Drugie wywołanie dokłada drugi proces i drugi obraz do
  pilnowania, a izolacji ponad nazwę bazy i tak nie daje.
- Nazwy baz zapisu są dokładnie te ze słownika. Inna nazwa rozjeżdża `DatabaseNames`, `CREATE
  DATABASE` i przyszły connection string.
- Żaden plik json w repozytorium nie zawiera hasła PostgreSQL. Hasło w json zostaje w historii
  gita.
- Test i AppHost używają obrazu `postgres:16-alpine`. Inny tag sprawia, że CI i dashboard mówią
  innym dialektem.
- Baza zapisu nie dostaje skryptu tabel. Skrypt tworzy schemat, którego port strumienia jeszcze
  nie konsumuje.
- `JJDevHub.Databases` nie referencjonuje Npgsql, EF ani ASP.NET. Referencja zamienia stałe nazw
  w klienta albo w host HTTP.
- Test ma cechę `Category=Integration` i nie uruchamia się filtrem jednostkowym. Brak cechy
  wciąga Dockera do krótkiej pętli.
- Jedna usługa, gdy już powstanie, dostaje tylko swój `*_write` i później swój `*_read`. Cudzy
  ciąg pozwala News otworzyć `cv_write`.
- W tym numerze usługa nie dostaje żadnego ciągu. `WithReference` przed istnieniem projektu
  otwiera drogę do obcej bazy.
- MongoDB i OpenSearch nie pojawiają się w csproj. Drugi silnik kasuje wybór jednego PostgreSQL
  na licencji z listy.
- RabbitMQ nie pojawia się w AppHost. Broker nie jest serwerem baz tego numeru.

## Poza zakresem

- Indeksy i bazy `*_read` są w [03-odczyt.md](03-odczyt.md). Ten numer nie woła `AddDatabase`
  dla odczytu i nie tworzy `read_document`.
- Sekret hasła produkcyjnego jest w [04-openbao.md](04-openbao.md). Ten numer nie wpisuje hasła
  maszyny do gita.
- Port strumienia w pamięci jest w [08-strumien.md](08-strumien.md). Ten numer nie dodaje
  `IEventStore`.
- Ten sam port na PostgreSQL jest w [09-persistence.md](09-persistence.md). Ten numer nie tworzy
  `JJDevHub.EventStore.Postgres` ani tabeli strumienia.
- Outbox w transakcji jest w [14-outbox.md](14-outbox.md). Ten numer nie tworzy tabeli outboxa.
- Przypięcie `WithReference` do Identity jest w [17-identity.md](17-identity.md), do News w
  [18-news.md](18-news.md), do Learning w [19-learning.md](19-learning.md), do Cv w
  [20-cv.md](20-cv.md), do Contact w [21-kontakt.md](21-kontakt.md).
- Redis jako cache zostaje zasobem z [01-aspire.md](01-aspire.md), a zapis klucza jest w
  [13-redis.md](13-redis.md). Ten numer nie woła klienta Redis.

## Źródła

- [PostgreSQL integration in
  Aspire](https://learn.microsoft.com/dotnet/aspire/database/postgresql-integration). Wiążące są
  `AddPostgres` i `AddDatabase`: jeden zasób serwera i baza, której nazwa staje się nazwą
  connection stringa. Dotyczy jednego wywołania `AddPostgres(DatabaseNames.Postgres)` oraz
  pięciu baz zapisu bez `WithReference`. Ze źródła nie bierzemy skryptu tworzenia tabel na bazie
  zapisu i nie bierzemy hasła wpisanego w repozytorium. Hasło zostaje parametrem zasobu.
- [CREATE DATABASE](https://www.postgresql.org/docs/16/manage-ag-createdb.html). Wiążące jest
  znaczenie pustej bazy na serwerze: katalog systemowy istnieje, a tabela aplikacji nie. Dotyczy
  `CREATE DATABASE` dla pięciu nazw i warunku, że `pg_tables` w schemacie `public` nie zawiera
  tabeli aplikacji. Ze źródła nie bierzemy `CREATE TABLE`, rozszerzeń ani danych
  demonstracyjnych. `SELECT 1` sprawdza łączność, nie kształt domeny.
- [PostgreSQL licence](https://www.postgresql.org/about/licence/). Wiążąca jest licencja
  silnika, zgodna z listą dopuszczoną w repozytorium. Dotyczy wyboru PostgreSQL oraz odrzucenia
  SQL Server, którego licencja na tej liście nie stoi. Ze źródła nie bierzemy pięciu osobnych
  instalacji jako sposobu na izolację usług. Izolacją tego numeru jest nazwa bazy.
- [Npgsql](https://www.npgsql.org/doc/license.html). Wiążąca jest licencja PostgreSQL
  sterownika, którego używa wyłącznie test tego numeru. Dotyczy `NpgsqlConnection` i `SELECT 1`
  oraz zakazu referencji Npgsql w `JJDevHub.Databases`. Ze źródła nie bierzemy mapowania
  obiektów ani narzędzia, które tworzy tabele. Sterownik w teście tylko otwiera połączenie i
  czyta jedną liczbę.
- [Npgsql connection string](https://www.npgsql.org/doc/connection-string-parameters.html).
  Wiążące są pola `Host`, `Port`, `Database`, `Username` i `Password`, z których Aspire składa
  ciąg. Dotyczy decyzji, że ciąg powstaje w składzie albo w kontenerze testu, a nie w pliku
  json. Ze źródła nie bierzemy gotowego ciągu z hasłem w gicie i nie bierzemy metody w
  `DatabaseNames`, która taki ciąg zwraca.
- [Testcontainers for .NET](https://dotnet.testcontainers.org/modules/postgresql/). Wiążący jest
  `PostgreSqlBuilder` i obraz kontenera w fakcie. Dotyczy `postgres:16-alpine`, `CREATE
  DATABASE` na bazie utrzymaniowej i cechy `Category=Integration`. Ze źródła nie bierzemy
  współdzielonego klastra na hoście dewelopera jako bazy CI i nie bierzemy kontenera innego
  silnika. Obraz ma być ten sam co w AppHost.
- [PostgreSQL 16](https://www.postgresql.org/docs/16/). Wiążący jest jeden dialekt serii 16 dla
  developmentu, testu i maszyny. Dotyczy tagu obrazu `postgres:16-alpine` w AppHost i w teście.
  Ze źródła nie bierzemy replikacji, obcych silników ani schematu aplikacji. SQLite odpada, bo
  nie jest tym serwerem i nie niesie `CREATE DATABASE` w tym samym znaczeniu.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Wiążące jest to, że usługa nie sięga do danych sąsiada. Dotyczy pięciu baz zapisu i reguły, że
  News nie dostaje ciągu do `cv_write`. Ze źródła nie bierzemy pięciu procesów PostgreSQL: w tym
  numerze granicą jest nazwa bazy na jednym `AddPostgres`. Nie bierzemy też wspólnego schematu z
  prefiksem tabel jako zamiennika tej granicy.
- [xUnit](https://xunit.net/). Wiążące są `[Fact]` i cecha kategorii. Dotyczy
  `[Trait("Category", "Integration")]` oraz filtra, który pomija ten fakt w krótkiej pętli bez
  Dockera. Ze źródła nie bierzemy cechy `Category=Performance` i nie bierzemy wielu powodów
  padnięcia w jednej metodzie. Powodem jest brak liczby `1` z którejś bazy zapisu.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: osobna baza na usługę w
  składzie Aspire. Dotyczy `AddDatabase` dla Identity, News, Learning, Cv i Contact oraz tego,
  że AppHost ogłasza zasób, zanim powstanie projekt usługi. Z tego repozytorium nie bierzemy
  MediatR ani IntegrationEventLogEF. Nie bierzemy też wiersza demonstracyjnego w pustej bazie
  zapisu.

## Gotowe gdy

- AppHost rejestruje jeden zasób `postgres` i dokładnie pięć baz zapisu o nazwach ze słownika.
- Obraz to `postgres:16-alpine`.
- W żadnej z tych baz nie ma tabeli w schemacie `public`.
- W repozytorium nie ma hasła ani gotowego connection stringa z hasłem.
- Komenda z sekcji testów kończy się kodem zero.
- Filtr `Category!=Integration&Category!=Performance` nie wymaga tego faktu i nie psuje się
  przez brak Dockera w krótkiej pętli jednostkowej.
- `JJDevHub.EventStore` jeszcze nie istnieje albo, jeśli ktoś go dodał wcześniej, ten numer go
  nie zmienia.
- Plik `db/read/001_read_document.sql` jeszcze nie jest podpięty do tych baz.
