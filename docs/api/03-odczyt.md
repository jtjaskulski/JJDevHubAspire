# 03. Odczyt

Poprzedni numer, [PostgreSQL](02-postgres.md), stawia jeden serwer i pięć pustych baz zapisu.
Ten numer dokłada pięć baz odczytu na tym samym serwerze i kontrakt indeksu po `slug`,
`category` i `language`. Następny numer, [OpenBao](04-openbao.md), wynosi sekrety z plików
konfiguracji. Po tym numerze istnieją `identity_read`, `news_read`, `learning_read`, `cv_read` i
`contact_read`. W każdej jest tabela `read_document` i trzy indeksy. Wierszy projekcji jeszcze
nie ma. Worker, który je zapisze, jest w [12-projekcja.md](12-projekcja.md). Przepływ `POST`
potem `GET` jest w [architektura.md](architektura.md).

Scenariusz, który bez tego numeru się psuje, zaczyna się od pierwszego `GET` po `POST`. Handler
zapytania nie ma własnej bazy, więc otwiera `news_write` i czyta albo strumień, albo wiersz,
który komenda dopiero co zapisała tym samym połączeniem. Rozdział CQRS zostaje zdaniem w
komentarzu. Chwilę później projekcja jest nieaktualna, a komenda podejmuje decyzję na tym
widoku, bo nic technicznego jej nie broni. Na pustej tabeli planner i tak wybierze skan, więc
brak indeksu wyjdzie dopiero, gdy katalog artykułów urośnie. Albo slug żyje tylko w Redisie i
restart kasuje katalog strony.

Ten numer stawia kształt zapytania, zanim powstanie pierwszy wiersz i zanim powstanie worker.
Baza odczytu jest pusta wierszowo i nie jest pusta schematowo. To jest różnica wobec baz zapisu
z numeru 02, które nie mają tabeli aplikacji. Zapis trzyma historię, której schematu jeszcze nie
ma. Odczyt trzyma sposób wejścia, który jest już znany: slug, kategoria i język. `Article`,
`Lesson` i strona CV różnią się kształtem JSONB. Nie różnią się tym, że da się je znaleźć po
tych trzech polach.

Jest jeden zasób `postgres` i drugie pięć wywołań `AddDatabase`. Nie ma drugiego serwera. Nie ma
kolekcji MongoDB i nie ma indeksu OpenSearch. Redis zostaje zasobem `cache` i w tym numerze nie
dostaje klucza. Skrypt jest jeden, wołany przez skład i przez test z tej samej treści. Po
`aspire run` baza odczytu ma tabelę, baza zapisu jej nie ma.

## Po co

Odczyt HTTP ma trafić w gotowy wiersz, nie w strumień zdarzeń. Żeby to było prawdziwe, baza
odczytu musi istnieć wcześniej niż pierwsza komenda domenowa. Inaczej handler komendy i handler
zapytania dzielą jeden connection string, a rozdział CQRS zostaje umową w komentarzu. Osobna
baza wymusza osobny ciąg. Handler, który go nie dostał, nie ma czego otworzyć. Handler komendy,
gdy powstanie w [10-cqrs.md](10-cqrs.md), nie dostanie ciągu `*_read`. Handler zapytania nie
dostanie `IEventStore`.

Indeks też ma istnieć wcześniej niż dane. Gdy pierwsza projekcja dojdzie w numerze 12, autor
tabeli nie będzie wybierał między skanem a btree pod presją pustego katalogu. Kontrakt jest
jeden dla pięciu usług. Lista kategorii w jednym języku i odczyt jednej notatki po slugu mają
iść w indeks. Bez indeksu planner wybierze skan, gdy tabela urośnie, a test na pustej tabeli
tego nie pokaże. Dlatego fakt tego numeru sprawdza katalog `pg_indexes`, a nie czas odpowiedzi
na zerze wierszy. Nie woła `EXPLAIN`.

`Article`, `Lesson` i strona CV różnią się kształtem JSONB. Nie różnią się tym, że da się je
znaleźć po slugu, kategorii i języku. Notatka, lekcja i strona CV nie mają tego samego zestawu
kolumn biznesowych. Mają ten sam sposób wejścia. Kultura `pl` i `en` jest wartością w
`language`, nie parą kolumn `title_pl` i `title_en`. Nowa kultura jest nową wartością, nie nową
kolumną. Dzięki temu skrypt nie puchnie przy kolejnym języku, a filtr zostaje na kolumnie `NOT
NULL`.

Baza odczytu jest pusta wierszowo. Nie jest pusta schematowo. Tabela `read_document` stoi i
czeka na worker. Sam numer nie wstawia wiersza. `GET` jeszcze jej nie czyta, bo nie ma handlera
zapytania. Przez chwilę po `POST` odczyt zwraca `404`, bo projekcja jest asynchroniczna i bywa w
tyle za strumieniem. To jest celowe. Spójność między zapisem a odczytem jest eventual, przez
pozycję globalną strumienia, którą wprowadzi magazyn. Tłumaczenie `404` jest w
[11-walidacja.md](11-walidacja.md). Ten numer tylko stawia miejsce, w którym wiersza jeszcze nie
ma.

Dwa connection stringi na usługę są kosztem, który numer przyjmuje. Nie ma transakcji, która
zapisuje strumień i wiersz odczytu naraz. Zapisanie obu w jednej bazie pozwoliłoby komendzie
przeczytać własną projekcję tym samym połączeniem i uznać widok za aktualny. Osobne bazy ten
skrót zabierają. Fizyczna replika bazy zapisu też go nie załatwia: replika kopiuje strumień, a
ścieżka `GET` ma czytać projekcję, nie zdarzenia. Odtwarzanie strumienia przy każdym `GET`
rośnie z historią artykułu, a nie z kosztem jednego wiersza.

Redis nie jest tym miejscem. Zostaje zasobem `cache` z [01-aspire.md](01-aspire.md). Po
restarcie Redisa strona ma dalej odpowiadać z PostgreSQL. Model, po którym da się odbudować
stronę, jest w `*_read`. Klucz wolno zgubić. Wiersza nie wolno. Gdy dojdzie numer 13, gorący
dokument będzie miał dwa miejsca: wiersz i klucz. Prefiks klucza będzie nazwą usługi, żeby
`news` nie nadpisał `cv`. W tym numerze test nie ustawia Redis i nie zapisuje klucza.

## Dlaczego ta technologia

### Osobna baza odczytu

Drugie pięć wywołań `AddDatabase` na istniejącym zasobie `postgres`. Nazwy: `identity_read`,
`news_read`, `learning_read`, `cv_read`, `contact_read`. Stałe to `IdentityRead`, `NewsRead`,
`LearningRead`, `CvRead` i `ContactRead`. Nie ma drugiego `AddPostgres`. Obraz zostaje
`postgres:16-alpine` z numeru 02. Bazy `*_write` zostają bez skryptu. Na każdym zasobie `*_read`
skrypt tworzenia dostaje tę samą treść tabeli. `WithReference` do projektu usługi zostaje przy
numerze usługi. Ten numer nie daje tych zasobów projektowi, którego jeszcze nie ma, i nie daje
usłudze ciągu sąsiada.

Projekcja jest asynchroniczna i bywa w tyle za strumieniem. Jeśli leży w tej samej bazie co
strumień, komenda może ją przeczytać tym samym połączeniem i podjąć decyzję na nieaktualnym
widoku. Osobna baza wymusza osobny connection string. Handler, który go nie dostał, nie ma czego
otworzyć. Ciąg odczytu i ciąg zapisu różnią się nazwą bazy. To jest warunek ukończenia, nie
szczegół dokumentacji. `news_read` i `news_write` stoją obok siebie na jednym serwerze i nie są
dwoma schematami jednego połączenia.

Konkret JJDevHub: `POST` artykułu zapisze kiedyś zdarzenie w `news_write`. `GET` tej notatki ma
czytać wiersz w `news_read`. Między nimi jest luka. W tej luce odczyt zwraca `404`, choć zapis
już przyjął fakt. Komenda nie może zajrzeć do `news_read`, żeby „sprawdzić, czy już widać”.
Zapytanie nie może otworzyć strumienia, żeby złożyć artykuł na żywo. To samo dotyczy lekcji w
`learning_read` i strony CV w `cv_read`. Identity i Contact mają ten sam kształt tabeli, choć
ekrany są inne. Kontrakt wejścia jest wspólny. Kształt `document` jest lokalny i dojdzie razem z
projekcją.

Odpadł schemat `read` wewnątrz `news_write` i analogicznie w pozostałych bazach zapisu. Jedno
połączenie wykonuje zapytanie do obu schematów. Kto ma ciąg do zapisu, ma też odczyt, jeśli oba
są schematami tej samej bazy. Reguła „handler komendy nie dostaje `*_read`” staje się wtedy
konwencją w kodzie, a nie brakiem ciągu. `AddDatabase` na nazwie `*_read` robi z tej reguły
osobny zasób Aspire. Literówka nazwy jest pilnowana stałą, tak jak w numerze 02, tylko dla
piątki odczytu.

Odpadła też replika fizyczna bazy zapisu. Replika kopiuje strumień, a ścieżka `GET` ma czytać
projekcję, nie zdarzenia. Opóźnienie repliki nie jest opóźnieniem workera projekcji i nie niesie
kolumn `slug`, `category`, `language`. Czytanie repliki przy `GET` wraca do odtwarzania historii
albo do czytania tabeli, której w zapisie ma nie być. `read_document` w `*_write` złamałoby
numer 02. Dlatego tabela żyje tylko w `*_read`, a warunek „gotowe” mówi wprost: w bazie zapisu
tej tabeli nie ma.

Koszt to dwa connection stringi na usługę i brak transakcji, która zapisuje strumień i wiersz
odczytu naraz. To jest celowe. Spójność między nimi jest eventual, przez pozycję globalną
strumienia, którą wprowadzi magazyn. Pozycja jako kursor workera i wypełnianie wiersza są w
[12-projekcja.md](12-projekcja.md). Ten numer pozycji nie zapisuje w `read_document` i nie
tworzy kolumny kursora. Przez chwilę po `POST` odczyt zwraca `404`. Kto doda transakcję rozpiętą
na obie bazy, zdejmie lukę, którą architektura chce mieć, i zwiąże komendę z widokiem.

### Wiersz albo JSONB w PostgreSQL

Tabela `read_document` ma kolumny `id`, `slug`, `category`, `language` i `document` typu
`jsonb`. Kolumny skalarne służą filtrowi. `document` niesie treść złożoną pod konkretny ekran.
Pięć baz dostaje ten sam skrypt `db/read/001_read_document.sql`. `id` jest `uuid` i kluczem
głównym. `slug`, `category`, `language` i `document` są `NOT NULL`. Para `(slug, language)` jest
unikalna w jednej bazie przez ograniczenie `read_document_slug_language_unique`. Skrypt nie
zawiera `CREATE EXTENSION` pod wyszukiwanie pełnotekstowe jako zamiennik sluga.

Notatka, lekcja i strona CV nie mają tego samego zestawu kolumn biznesowych. Mają ten sam sposób
wejścia: slug, kategoria, język. JSONB trzyma resztę bez dokładania kolumny przy nowej kulturze.
Kultura `pl` i `en` jest wartością w `language`, nie parą kolumn `title_pl` i `title_en`.
Artykuł może nieść treść, której lekcja nie ma. Lekcja może nieść porządek, którego nie ma
strona CV. Kolumny filtra tego nie udają. Walidacja kształtu `document` należy do projekcji w
numerze 12, nie do tego skryptu. Skrypt pilnuje, że dokument w ogóle jest i że da się go
znaleźć.

Konkret: w `news_read` wiersz artykułu i w `cv_read` wiersz strony mają te same pięć kolumn i
inny JSON. W `learning_read` lekcja wchodzi tym samym indeksem `(slug, language)`. Kategoria
listy jest kolumną, nie ścieżką wewnątrz JSON-a, bo lista kategorii w jednej kulturze ma iść w
btree `(category, language)`. Identyfikator `id` jest tożsamością wiersza projekcji. Nie
zastępuje sluga w adresie strony. Dwa byty nie mogą dostać tego samego sluga w tej samej
kulturze w jednej bazie odczytu. Unikalność dotyczy jednej bazy: `news_read` nie widzi slugów z
`cv_read`, bo to inne połączenie.

Odpadło MongoDB jako baza odczytu. Drugi silnik, a serwer MongoDB jest na SSPL, poza listą
licencji. Projekcja po slugu nie potrzebuje osobnego dokumentu poza tym, co daje JSONB. Drugi
proces oznacza drugi obraz, drugi connection string poza dziesięcioma bazami PostgreSQL i pakiet
klienta, którego w solution ma nie być. Skrypt SQL nie tworzy kolekcji. Fakt czyta `pg_indexes`,
nie katalog MongoDB. Odpadnięcie jest licencyjne i graniczne: odczyt zostaje na serwerze, który
numer 02 już postawił.

Odpadł OpenSearch. To silnik wyszukiwania. Strona woła dokument po slugu i listę kategorii, a
nie pełnotekstowy indeks jako źródło prawdy. `CREATE EXTENSION` pod pełny tekst jako zamiennik
sluga jest wprost zabronione warunkiem „gotowe”. Zapytanie strony jest równością sluga i języka.
Do równości służą kolumny i btree, nie skorowidz słów. Klient OpenSearch nie wchodzi do
solution. Indeks wyszukiwarki nie zastępuje `read_document`.

Koszt: dokument JSONB da się zepsuć kształtem, którego nie pilnuje kolumna. Kolumny filtra są
`NOT NULL`, więc slug, kategoria i język nie chowają się tylko w środku dokumentu. Zły kształt
środka wyjdzie w numerze 12, przy zapisie projekcji, a nie przy `CREATE TABLE`. Ten numer nie
dodaje `CHECK` na strukturę JSON-a artykułu, bo artykułu jako typu jeszcze tu nie ma. Kształt
`Article` jest w [18-news.md](18-news.md). Katalog Learning jest w
[19-learning.md](19-learning.md). Złożenie strony CV z kopii sluga jest w [20-cv.md](20-cv.md).
Listy Contact są w [21-kontakt.md](21-kontakt.md).

### Indeks btree po slug, category i language

Unikalny indeks `(slug, language)` powstaje z ograniczenia `read_document_slug_language_unique`.
Indeks `(category, language)` nazywa się `read_document_category_language_idx`. Indeks
`(language, slug)` nazywa się `read_document_language_slug_idx`. Wszystkie btree. Skrypt tworzy
je w każdej bazie odczytu. Osobnego indeksu GIN nie ma. Kolumna `slug` razem z `language` jest w
ograniczeniu unikalnym, które tworzy indeks btree. Osobny indeks kategorii i osobny indeks
języka z slugiem pokrywają listę i filtr kultury.

Lista kategorii w jednym języku i odczyt jednej notatki po slugu mają iść w indeks. Bez indeksu
planner wybierze skan, gdy tabela urośnie, a test na pustej tabeli tego nie pokaże. Dlatego fakt
tego numeru sprawdza katalog `pg_indexes`, a nie czas odpowiedzi na zerze wierszy. Na pustej
tabeli planner i tak może wybrać skan, więc `EXPLAIN` nic by nie udowodnił. Asercja patrzy na
`indexname` i `indexdef` w schemacie `public`. W każdej bazie definicje zawierają kolumny
`slug`, `category` i `language` oraz istnieją trzy nazwy z sekcji testów.

Konkret odczytu: jeden dokument w kulturze idzie w `(slug, language)`. Lista kategorii w
kulturze idzie w `(category, language)`. Lista w jednej kulturze uporządkowana po slugu idzie w
`(language, slug)`. Kolejność kolumn w indeksie złożonym jest częścią kontraktu, nie kosmetyką.
Indeks `(language, slug)` nie jest kopią unikalnego `(slug, language)`. Służy innemu wejściu.
Unikalność `(slug, language)` odrzuca drugą projekcję tego samego adresu. Dwa byty nie mogą
dostać tego samego sluga w tej samej kulturze w jednej bazie odczytu. Worker numeru 12 zapłaci
za aktualizację trzech indeksów. Żądanie HTTP tego kosztu nie płaci.

Odpadło odtwarzanie strumienia przy każdym `GET`. Koszt rośnie z historią artykułu, a nie z
kosztem jednego wiersza. Strumień żyje w bazie zapisu, której schematu jeszcze nie ma, i port
`IEventStore` nie jest wołany przez zapytanie. Nawet gdy port powstanie w
[08-strumien.md](08-strumien.md), handler zapytania go nie dostanie. Złożenie strony z faktów
przy każdym odczycie sprzęga czas odpowiedzi z długością historii i zamyka lukę `404`, którą
projekcja ma mieć prawo mieć. Indeks na wierszu jest odpowiedzią na odczyt. Strumień jest
odpowiedzią na zapis.

Odpadł sam indeks GIN na całym `document` jako jedyna droga. GIN służy zawieraniu JSON-a.
Zapytanie strony jest równością sluga i języka, a do równości służy btree na kolumnach. GIN na
dokumencie zachęca, żeby slug i język schować w środku JSON-a i filtrować po ścieżce. Kolumny
`NOT NULL` są po to, żeby filtr miał pole, które planner widzi bez rozbierania dokumentu. GIN
może kiedyś obsłużyć zawieranie, którego ten numer nie potrzebuje. Jako jedyna droga do sluga
odpada. Skrypt go nie tworzy.

Koszt zapisu trzech indeksów ponosi worker, nie żądanie. Unikalność potrafi odrzucić drugą
projekcję. To jest pożądane w jednej bazie i w jednej kulturze. Nie jest zakazem tego samego
sluga w `pl` i w `en`: para obejmuje obie kolumny. Nie jest też zakazem tego samego sluga w
`news_read` i w `cv_read`, bo to osobne bazy. Kto doda czwarty indeks „na zapas” bez nazwy z
kontraktu, nie spełni faktu, jeśli zabraknie jednej z trzech nazw. Jedna brakująca nazwa w
jednej bazie wystarcza, żeby fakt był czerwony. To nadal jeden powód: kontrakt indeksu odczytu
nie jest kompletny.

### Redis nie zastępuje tabeli

Redis zostaje zasobem `cache` z [01-aspire.md](01-aspire.md). Ten numer nie zapisuje w nim
klucza i nie czyta go w teście. Model, po którym da się odbudować stronę, jest w `*_read`. Cache
gorącej projekcji dojdzie w [13-redis.md](13-redis.md). Do tego czasu jedynym trwałym katalogiem
sluga, kategorii i języka jest PostgreSQL. Test integracyjny nie ustawia Redis. Padnięcie, bo
kontener bazy nie wstał, jest awarią przygotowania. Asercja dotyczy wyłącznie katalogu indeksów.

Cache jest ulotny. Po restarcie Redisa strona ma dalej odpowiadać z PostgreSQL. Jeśli jedyny
indeks sluga żyje w Redisie, restart kasuje katalog. Strona zostaje bez listy i bez dokumentu,
choć wiersze nigdy nie powstały albo powstały tylko w pamięci. Reguła z architektury, że w cache
nie leży jedyna kopia projekcji, dostaje tu fizyczny odpowiednik: kopia, z której da się
odbudować stronę, jest wierszem `read_document`. Klucza jeszcze nie ma, więc nie ma też czego
odbudowywać z pamięci.

Konkret: `news` i `cv` będą kiedyś dzielić jeden zasób `cache` i nie mogą dzielić klucza bez
prefiksu. Prefiks i tak będzie nazwą usługi, żeby `news` nie nadpisał `cv`. Ten numer prefiksu
nie ustawia, bo nie zapisuje klucza. Gdyby indeks `(category, language)` istniał tylko jako
struktura w Redisie, fakt `pg_indexes` byłby czerwony albo w ogóle niepatrzyłby na PostgreSQL.
Kontrakt tego numeru jest w katalogu bazy odczytu. Cache może później trzymać gorący dokument
pod kluczem, który wolno zgubić. Po zgubieniu worker albo odczyt wraca do wiersza. Do wiersza,
którego nie wolno zgubić razem z procesem Redis.

Odpadło trzymanie projekcji wyłącznie w Redisie. Odpadł też Redis jako jedyne miejsce indeksu
kategorii. Oba mylą cache z bazą odczytu. Zasób `cache` został w numerze 01 właśnie jako cache,
z danymi, które wolno stracić. Zamiana go na katalog strony odwraca tę decyzję bez zmiany nazwy
zasobu. Nazwa zostałaby, a semantyka by zniknęła. Test, który ustawia Redis i sprawdza klucz,
sprawdzałby inny numer. Dlatego go tu nie ma.

Koszt to dwa miejsca na gorący dokument, gdy dojdzie numer 13: wiersz i klucz. Klucz wolno
zgubić. Wiersza nie wolno. Trzeba będzie pilnować, że unieważnienie klucza nie kasuje wiersza i
że brak klucza nie jest `404`, jeśli wiersz jest. Tego pilnowania ten numer nie implementuje.
Zostawia trwałą stronę umowy: tabela, trzy indeksy, zero wierszy, zero kluczy. Kto wstawi tu
zapis do Redis, zwiąże fakt katalogu z procesem, którego asercja nie czyta.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `JJDevHub.AppHost/AppHost.cs` | pięć `AddDatabase` odczytu na istniejącym `postgres` |
| `src/shared/JJDevHub.Databases/DatabaseNames.cs` | stałe `identity_read`, `news_read`, `learning_read`, `cv_read`, `contact_read` |
| `db/read/001_read_document.sql` | tabela `read_document` i trzy indeksy |
| `src/shared/JJDevHub.Projections/Sql/read_document.sql` | ten sam skrypt jako zasób osadzony, bez workera |
| `src/shared/JJDevHub.Projections/JJDevHub.Projections.csproj` | biblioteka, która osadza SQL |
| `tests/JJDevHub.Integration.Tests/ReadIndexTests.cs` | fakt obecności indeksów w pięciu bazach |

Projekt `JJDevHub.Projections` w tym numerze nie ma klasy workera, checkpointu ani subskrypcji.
Ma plik SQL i metodę, która zwraca jego treść, żeby test i AppHost czytały jeden byt. Worker
dochodzi w [12-projekcja.md](12-projekcja.md). Ta metoda to `ReadDocumentSql.Text`.

## Plan

### 1. Stałe i zasoby

Do `DatabaseNames` dodaj `IdentityRead`, `NewsRead`, `LearningRead`, `CvRead`, `ContactRead`. W
`AppHost.cs` weź istniejący zasób `postgres` i wywołaj na nim `AddDatabase` dla tych pięciu
nazw. Nie dodawaj drugiego serwera. Nie dawaj tych zasobów projektowi usługi. `WithReference`
zostaje przy numerze usługi.

### 2. Skrypt tabeli

Utwórz `db/read/001_read_document.sql` o treści:

```sql
CREATE TABLE read_document (
    id uuid PRIMARY KEY,
    slug text NOT NULL,
    category text NOT NULL,
    language text NOT NULL,
    document jsonb NOT NULL,
    CONSTRAINT read_document_slug_language_unique UNIQUE (slug, language)
);

CREATE INDEX read_document_category_language_idx
    ON read_document (category, language);

CREATE INDEX read_document_language_slug_idx
    ON read_document (language, slug);
```

Kolumna `slug` razem z `language` jest w ograniczeniu unikalnym, które tworzy indeks btree.
Osobny indeks kategorii i osobny indeks języka z slugiem pokrywają listę i filtr kultury. Nie
dodawaj indeksu GIN. Nie dodawaj kolumn `title_pl` ani `title_en`.

### 3. Jeden tekst skryptu

Skopiowanie ręczne do dwóch miejsc się rozjedzie. `JJDevHub.Projections` osadza plik. Test czyta
treść z API tej biblioteki albo wprost z `db/read/001_read_document.sql`, jeśli projekt
projekcji jeszcze nie jest referencjonowany przez test. AppHost, jeśli używa
`WithCreationScript`, dostaje ten sam łańcuch. Wybierz jedną funkcję `ReadDocumentSql.Text`,
która zwraca treść pliku. I AppHost, i test wołają ją, a nie własną kopię.

### 4. Podpięcie przy tworzeniu bazy

Na każdym zasobie `*_read` ustaw skrypt tworzenia tą treścią. Bazy `*_write` zostają bez
skryptu, tak jak w numerze 02. Po `aspire run` baza odczytu ma tabelę, baza zapisu jej nie ma.

### 5. Fakt katalogu indeksów

Test integracyjny startuje `postgres:16-alpine`. Tworzy pięć baz odczytu. Na każdej wykonuje
skrypt. Potem czyta `pg_indexes` w schemacie `public`. Nie wstawia wiersza. Nie woła `EXPLAIN`.
Na pustej tabeli planner i tak może wybrać skan, więc czas odpowiedzi nic by nie udowodnił.

### Co jest do czego

`AddDatabase` dla nazwy `*_read` woła `AppHost.cs`. Oddziela connection string odczytu od zapisu
tej samej usługi. Gdy wywołania nie ma, `GET` i `POST` dzielą jeden ciąg albo odczyt w ogóle nie
ma bazy. Drugi `AddPostgres` dokłada serwer, którego ten numer nie chce. Usługa nie dostaje tu
referencji. Bez późniejszego `WithReference` w numerze usługi ciąg zostaje w składzie i nie
wchodzi do procesu sąsiada.

`read_document` jest miejscem, do którego numer 12 zapisze projekcję. W tym numerze tabela tylko
stoi. `GET` jeszcze jej nie czyta, bo nie ma handlera zapytania. Gdy tabeli nie ma, worker nie
ma gdzie wpisać wiersza, a strona nie ma modelu, z którego da się ją odbudować. Wiersz wstawiony
już teraz kłamie, że projekcja doszła. Tabela w `*_write` łamie pusty zapis z numeru 02.

Indeks `(slug, language)` służy odczytowi jednego dokumentu w kulturze i jest unikalny pod nazwą
`read_document_slug_language_unique`. Gdy go nie ma, dwa wiersze mogą dostać ten sam adres w
jednej kulturze, a odczyt notatki nie ma btree pod równość. Ograniczenie jest tym indeksem.
Osobny byt w drugiej bazie odczytu tym ograniczeniem nie jest związany.

Indeks `(category, language)` służy liście kategorii w kulturze i nazywa się
`read_document_category_language_idx`. Gdy go nie ma, lista kategorii na dużej tabeli ląduje w
skanie, a fakt katalogu jest czerwony. Kategoria schowana tylko w `document` nie ma tego
indeksu, nawet jeśli JSON da się przeszukać inaczej.

Indeks `(language, slug)` służy liście w jednej kulturze uporządkowanej po slugu i nazywa się
`read_document_language_slug_idx`. Gdy go nie ma, filtr kultury nie ma własnej drogi, a unikalny
indeks o odwrotnej kolejności kolumn tej listy nie zastępuje. Fakt wymaga tej nazwy osobno.

`ReadDocumentSql.Text` wołają test i skład. Jest jednym źródłem DDL. Gdy funkcji nie ma, a treść
żyje w dwóch kopiach, AppHost i test rozjadą się o kolumnę albo o nazwę indeksu. Test czyta ją z
API biblioteki albo wprost z `db/read/001_read_document.sql`, jeśli projekt projekcji jeszcze
nie jest referencjonowany. Własna kopia w teście jest tym, czego krok planu zabrania.

`pg_indexes` w teście jest katalogiem, nie ścieżką HTTP. Mówi, czy kontrakt fizycznie jest w
bazie. Gdy fakt zamiast katalogu mierzy czas albo woła `EXPLAIN`, na pustej tabeli potrafi
przejść bez indeksu. Wtedy numer wygląda na skończony, a planner na żywych danych wybierze skan.
Jedna brakująca nazwa w jednej z pięciu baz wystarcza do czerwonego faktu.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]` i cechę `Category=Integration`.
Powód padnięcia jest jeden: w którejś bazie odczytu brakuje indeksu kontraktu `slug`, `category`
albo `language`. NBomber nie wchodzi. Jest w [22-testy.md](22-testy.md). Cecha integracyjna
trzyma Dockera poza krótką pętlą jednostkową. Zdjęcie cechy związałoby katalog indeksów z
filtrem, który ma działać bez kontenera.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | kontener `postgres:16-alpine`, `CREATE DATABASE` dla pięciu nazw `*_read`, wykonanie `001_read_document.sql` na każdej |
| Działanie (act) | `SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public'` |
| Sprawdzenie (assert) | w każdej bazie definicje zawierają kolumny `slug`, `category` i `language` oraz istnieją nazwy `read_document_slug_language_unique`, `read_document_category_language_idx` i `read_document_language_slug_idx` |

Nazwa metody: `Read_document_has_slug_category_and_language_indexes`.

```text
dotnet test tests/JJDevHub.Integration.Tests/JJDevHub.Integration.Tests.csproj --filter "FullyQualifiedName~Read_document_has_slug_category_and_language_indexes"
```

Test nie łączy się z bazą zapisu i nie wymaga, żeby tabele zapisu istniały. Test nie ustawia
Redis. Padnięcie, bo kontener nie wstał, jest awarią przygotowania. Asercja dotyczy wyłącznie
katalogu indeksów. Jedna brakująca nazwa w jednej bazie wystarcza, żeby fakt był czerwony. To
nadal jeden powód: kontrakt indeksu odczytu nie jest kompletny.

Przygotowanie tworzy `identity_read`, `news_read`, `learning_read`, `cv_read` i `contact_read`,
nie piątkę zapisu. Skrypt na każdej bazie jest tym samym tekstem z `ReadDocumentSql.Text` albo z
pliku `db/read`, jeśli test jeszcze nie referencjonuje projektu projekcji. Działanie czyta
katalog, nie wiersze `read_document`. Sprawdzenie nie wstawia dokumentu i nie mierzy czasu.
Pusta tabela z trzema nazwami indeksów jest sukcesem. Tabela z wierszem i bez jednej nazwy jest
porażką numeru, nawet jeśli ktoś uznałby ją za „bliższą produkcji”.

Fakt nie woła `EXPLAIN` i nie otwiera `news_write`. Obecność tabeli zapisu nie jest warunkiem
tego testu. Jej obecność z tabelą `read_document` byłaby złamaniem numeru 02 i warunku „w bazie
`*_write` tej tabeli nie ma”, sprawdzanym osobno. Redis, który nie wstał, nie może być powodem
czerwieni. Jeśli test pada przez Redis, sprawdza za dużo.

## Zasady

- Jest jeden zasób `postgres`. Drugi serwer rozdwaja obraz i connection stringi bez dawania
  innej izolacji niż nazwa bazy.
- Baza odczytu nie jest schematem wewnątrz bazy zapisu. Jeden ciąg do obu schematów pozwala
  komendzie czytać projekcję.
- Skrypt nie tworzy kolekcji MongoDB i nie tworzy indeksu OpenSearch. Oba silniki wypadają z
  odczytu JJDevHub.
- Redis nie dostaje klucza. Klucz jako jedyny katalog znika przy restarcie i myli cache z bazą.
- Tabela nie ma wierszy po samym numerze. Wiersz udaje projekcję, której worker jeszcze nie
  zapisał.
- `document` jest typu `jsonb`. Inny typ zabiera resztę ekranu, która nie mieści się w kolumnach
  filtra.
- `slug`, `category` i `language` są `NOT NULL`. Null chowa filtr w środku dokumentu i omija
  btree.
- Para `(slug, language)` jest unikalna w jednej bazie. Druga projekcja tego samego adresu w tej
  samej kulturze ma zostać odrzucona.
- Usługa nie dostaje connection stringa sąsiada. Cudzy ciąg otwiera `cv_read` z procesu News.
- Handler komendy, gdy powstanie w [10-cqrs.md](10-cqrs.md), nie dostanie ciągu `*_read`. Ten
  ciąg pozwoliłby podjąć decyzję na widoku, który bywa w tyle.
- Handler zapytania nie dostanie `IEventStore`. Zapytanie wróciłoby do odtwarzania strumienia
  przy każdym `GET`.
- Nowa kultura jest wartością `language`, nie nową kolumną. Kolumna `title_pl` albo `title_en`
  zamyka słownik kultur w schemacie.
- Skrypt w `db/read` i tekst wołany przez test są tym samym plikiem. Dwie kopie rozjadą nazwę
  indeksu.

## Poza zakresem

- Wypełnianie wiersza, checkpoint i pozycja globalna jako kursor workera są w
  [12-projekcja.md](12-projekcja.md). Ten numer zostawia tabelę pustą.
- Cache gorącej projekcji jest w [13-redis.md](13-redis.md). Ten numer nie zapisuje klucza.
- Kształt `Article` jest w [18-news.md](18-news.md). Ten numer nie definiuje kolumn biznesowych
  artykułu.
- Katalog Learning jest w [19-learning.md](19-learning.md). Ten numer nie definiuje lekcji poza
  wspólnym wejściem sluga.
- Złożenie strony CV z kopii sluga jest w [20-cv.md](20-cv.md). Ten numer nie składa strony.
- Listy Contact są w [21-kontakt.md](21-kontakt.md). Ten numer nie zapisuje zapytań.
- Mediator, który pilnuje, że komenda nie widzi odczytu, jest w [10-cqrs.md](10-cqrs.md). Ten
  numer rozdziela ciągi, nie handler.
- Tłumaczenie `404` jest w [11-walidacja.md](11-walidacja.md). Ten numer tylko zostawia lukę po
  `POST`.
- Port strumienia, którego zapytanie nie woła, jest w [08-strumien.md](08-strumien.md). Ten
  numer nie dodaje `IEventStore`.

## Źródła

- [PostgreSQL indexes](https://www.postgresql.org/docs/16/indexes.html). Wiążące jest to, kiedy
  planner sięga po btree, a kiedy po skan, oraz że pusty katalog tego nie pokazuje. Dotyczy
  trzech indeksów na `read_document` i faktu, który czyta katalog zamiast mierzyć czas. Ze
  źródła nie bierzemy indeksu GIN jako jedynej drogi do sluga i nie bierzemy `EXPLAIN` na tabeli
  bez wierszy jako dowodu.
- [JSON types](https://www.postgresql.org/docs/16/datatype-json.html). Wiążący jest typ `jsonb`
  obok kolumn, po których się filtruje. Dotyczy kolumny `document` oraz tego, że slug, kategoria
  i język zostają kolumnami `NOT NULL`. Ze źródła nie bierzemy chowania filtra wyłącznie w
  JSON-ie i nie bierzemy pełnego tekstu jako zamiennika równości sluga.
- [Index-only scans and multicolumn
  indexes](https://www.postgresql.org/docs/16/indexes-multicolumn.html). Wiążąca jest kolejność
  kolumn w indeksie złożonym. Dotyczy `(category, language)`, `(language, slug)` i unikalnej
  pary `(slug, language)`. Ze źródła nie bierzemy jednego indeksu „na wszystkie zapytania”.
  Każde z trzech wejść strony ma własną nazwę.
- [System catalog pg_indexes](https://www.postgresql.org/docs/16/view-pg-indexes.html). Wiążące
  jest to, co fakt czyta: `indexname` i `indexdef` w schemacie `public`. Dotyczy asercji na
  pięciu bazach `*_read`. Ze źródła nie bierzemy pomiaru czasu odpowiedzi ani wstawiania wiersza
  po to, żeby katalog „wyglądał na żywy”.
- [Constraints](https://www.postgresql.org/docs/16/ddl-constraints.html). Wiążące jest to, że
  `UNIQUE (slug, language)` tworzy indeks btree i odrzuca drugą taką parę. Dotyczy nazwy
  `read_document_slug_language_unique`. Ze źródła nie bierzemy unikalności samego sluga bez
  języka: `pl` i `en` mogą nieść ten sam slug jako dwie pary.
- [CREATE INDEX](https://www.postgresql.org/docs/16/sql-createindex.html). Wiążące są dwa jawne
  indeksy btree spoza ograniczenia unikalnego. Dotyczy `read_document_category_language_idx` i
  `read_document_language_slug_idx`. Ze źródła nie bierzemy `USING gin` na `document` i nie
  bierzemy kolumn `title_pl` ani `title_en`.
- [MongoDB SSPL](https://www.mongodb.com/licensing/server-side-public-license). Wiążąca jest
  informacja o licencji serwera, który do odczytu nie wchodzi. Dotyczy odrzucenia MongoDB jako
  bazy projekcji: SSPL jest poza listą, a JSONB już niesie dokument. MongoDB odpadło, więc ze
  źródła
  nie bierzemy kolekcji, klienta ani modelu dokumentu, a OpenSearch odpada jako silnik
  wyszukiwania.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Wiążące jest trzymanie odczytu za osobnym connection stringiem, którego komenda nie dostaje.
  Dotyczy piątki `*_read` obok piątki `*_write` na jednym serwerze. Ze źródła nie bierzemy
  drugiego procesu PostgreSQL na odczyt i nie bierzemy schematu `read` wewnątrz bazy zapisu.
- [What do you mean by
  Event-Driven](https://martinfowler.com/articles/201701-event-driven.html). Wiążące jest
  czytanie zbudowanego widoku zamiast składania odpowiedzi ze strumienia przy każdym zapytaniu.
  Dotyczy luki między `POST` a `GET` oraz tego, że `GET` trafia w `read_document`. Ze źródła nie
  bierzemy odtwarzania historii artykułu na ścieżce zapytania i nie bierzemy pełnego URI jako
  nazwy zdarzenia. Nazwy faktów są w innym numerze.
- [xUnit](https://xunit.net/). Wiążące są `[Fact]` i cecha integracyjna. Dotyczy
  `Read_document_has_slug_category_and_language_indexes` oraz jednego powodu padnięcia:
  niekompletnego kontraktu indeksu. Ze źródła nie bierzemy NBombera i nie bierzemy asercji
  czasu. Cecha `Category=Performance` tu nie wchodzi.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: osobny model odczytu
  obok zapisu usługi. Dotyczy tabeli `read_document` w bazie `*_read`, a nie w bazie strumienia.
  Z tego repozytorium nie bierzemy MediatR ani IntegrationEventLogEF. Nie bierzemy też wiersza
  projekcji w tym numerze: worker jest później.

## Gotowe gdy

- AppHost ma dziesięć baz: pięć z numeru 02 i pięć z tego numeru, na jednym `AddPostgres`.
- W każdej bazie `*_read` istnieją tabela `read_document` i trzy nazwy indeksów z sekcji testów.
- W bazie `*_write` tej tabeli nie ma.
- Skrypt nie zawiera `CREATE EXTENSION` pod wyszukiwanie pełnotekstowe jako zamiennik sluga.
- Komenda z sekcji testów kończy się kodem zero.
- W solution nie ma pakietu klienta MongoDB ani klienta OpenSearch.
- Żaden `appsettings` nie zawiera connection stringa z hasłem do bazy odczytu.
- Ciąg odczytu i ciąg zapisu różnią się nazwą bazy.
