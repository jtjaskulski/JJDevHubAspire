# 12. Projekcja do bazy odczytu

Ten numer buduje widok pod odczyt w bazie `*_read` tej samej usługi, która ma strumień w
`*_write`. Biblioteka `JJDevHub.Projections` daje `Checkpoint`, `IProjection` i
`ProjectionWorker`. Zapis strumienia i globalna `Position` są w
[09-persistence.md](09-persistence.md). Język błędu odczytu, w tym `404` dla treści
niewidocznej, jest w [11-walidacja.md](11-walidacja.md). Cache gorącego widoku dołoży
[13-redis.md](13-redis.md). Bez tego numeru każde `GET` składa artykuł ze strumienia, a lista
„ostatnie notatki” czyta całą historię po to, żeby pokazać slug, język i datę.

Handler komendy nie otwiera bazy odczytu. Handler zapytania nie woła `IEventStore`. Worker czyta
magazyn zapisu od checkpointu i robi upsert w bazie odczytu tej samej usługi. `POST` zatwierdza
strumień i wraca, zanim widok dogoni pozycję. Klient, który natychmiast zrobi `GET`, może dostać
`404` i ponawia odczyt. To jest uczciwy koszt osobnego modelu, nie dziura do zatkania
synchroniczną projekcją w transakcji zapisu.

Pięć baz odczytu stoi na tym samym serwerze Postgresa co bazy zapisu: `identity_read`,
`news_read`, `learning_read`, `cv_read`, `contact_read`. Usługa dostaje dwa connection stringi,
swoje. Worker News czyta `news_write` i pisze `news_read`. Nie widzi `learning_write`. Cv nie
składa strony z bazy Learning. Kopię stanu, której potrzebuje, dostanie zdarzeniem z
[15-kafka.md](15-kafka.md), z tematu `learning.integration`, a nie zapytaniem SQL do sąsiada.
MongoDB nie wchodzi. Osobny silnik dokumentów nie przyspiesza odczytu po slugu wobec
indeksowanego wiersza i `jsonb` w bazie, którą i tak mamy. Licencja drugiego silnika też nie
przechodzi listy dozwolonych w sposób, w jaki PostgreSQL przechodzi.

## Po co

Strumień jest dobry do zapisu reguł i zły do listy „ostatnie notatki” albo do strony CV złożonej
pod slug. Odtwarzanie agregatu na każdym `GET` czyta całą historię i trzyma reguły na ścieżce,
która ma być tania. Widok jest wierszem albo dokumentem `jsonb` ułożonym pod zapytanie, które
ekran naprawdę woła. Lista notatek filtruje po slugu, języku, statusie i dacie. Strona o
kształcie zmiennym może trzymać złożoną sekcję w `jsonb` obok kolumn, po których jest `WHERE`.
Indeks jest na kolumnach zapytania. Strumienia nikt nie odtwarza na ścieżce HTTP.

Projekcja jest asynchroniczna. `ArticleCreated` z nazwą `news.article-created.v1` siedzi już w
`EventRecords`, a wiersza w `news_read` jeszcze nie ma. `GET` po slugu dostaje `not_found` z
numeru `11`, tak samo jak przy prawdziwym braku i tak samo jak przy treści, której czytelnik nie
ma widzieć. Klient ponawia odczyt. Zapis nie czeka na indeksy odczytu. Błąd mapowania widoku nie
wycofuje faktu, który już zaszedł. Test `Read_after_command_before_projection_is_empty` zapisuje
fakt do bazy zapisu i czyta bazę odczytu, zanim poleci runner. Wynik jest pusty. Drugie
wywołanie, po `RunOnceAsync`, widzi wiersz. To jest zachowanie, nie błąd do zatkania.

Pięć usług nie dzieli widoków. `contact_read` trzyma to, co Contact pokazuje ze swoich zapytań.
`learning_read` trzyma katalog kursu dla Learning. Cv, które chce pokazać technologię na
stronie, nie otwiera `learning_read`. Dostaje kopię przez `learning.integration`. Ten numer
buduje mechanizm wewnątrz jednej usługi: `projection_write` i `projection_read` w teście,
`news_write` i `news_read` w hoście. Kasowanie `news_read` i checkpointu od zera odbudowuje
widok ze strumienia. Strumień zostaje.

Handler komendy, który „szybko sprawdzi, czy slug jest wolny”, nie robi `SELECT` po `*_read`.
Odczyt w komendzie jest tabelą w bazie zapisu, w tej samej transakcji co strumień, albo regułą
agregatu. Widok jest ostatecznie spójny i potrafi jeszcze nie znać sluga, który commit już ma.
Sprawdzenie po widoku puściłoby dwa artykuły z tym samym slugiem. `ICommandHandler` dostaje
`IEventStore` albo repozytorium na `IEventStore` oraz `IUnitOfWork` na kontekście zapisu. W
konstruktorze nie ma `*ReadContext`. `IQueryHandler` dostaje port czytnika, na przykład
`IArticleReader`, i nie dostaje `IEventStore`.

## Dlaczego ta technologia

### Osobna baza odczytu tej samej usługi

Widok mógłby być drugą tabelą w `news_write`. Byłoby mniej connection stringów. Osobna baza
wymusza granicę, której kompilator i connection string bronią razem: proces zapytania nie ma w
konfiguracji bazy zapisu, proces komendy nie ma bazy odczytu. Da się skasować `news_read` i
zbudować ją od checkpointu 0, bez dotykania strumienia. Dwa schematy w jednej bazie
przegrywają, bo ten sam connection string otwiera obie i handler łatwo woła złą tabelę. Wtedy
komenda „przy okazji” czyta widok, a zapytanie „przy okazji” dopisuje fakt. Osobna baza to ucina
na konfiguracji, zanim dojdzie do recenzji.

Baza sąsiada przegrywa z zasady produktu: usługa nie czyta cudzej bazy. News nie dostaje stringa
do `learning_read` ani do `learning_write`. Cv nie składa strony zapytaniem do Learning. Kopię
stanu niesie temat `learning.integration` z numeru `15`. Ten numer tylko nie daje connection
stringa, który taką kopię obejść. Pięć baz odczytu na jednym serwerze to ten sam układ co pięć
baz zapisu: jeden Postgres, osobne bazy, osobne historie schematu.

Koszt: drugi kontekst EF, druga historia schematu, krótkie okno, w którym zapis już jest, a
odczyt jeszcze nie. Okno jest widoczne dla klienta jako `404` i znika po przejściu workera.
Domyślnie worker przy pustej paczce czeka `IdleDelay` 500 ms. Opóźnienie jest rzędu tego postoju
plus czas paczki. Przy jednym autorze treści to jest tanie wobec ceny złożenia całej historii na
każdym `GET`. `*ReadContext` nie woła `ApplyEventStore`. Tabele `EventStreams` i `EventRecords`
nie leżą w bazie odczytu. Test, który tworzy dwie bazy na jednym serwerze, sprawdza, że tabele
się nie mieszają.

### Worker od checkpointu, nie projekcja w transakcji zapisu

Projekcja w tej samej transakcji co `AppendAsync` dałaby widok od razu. Każdy nowy widok
spowalniałby każdy zapis, błąd mapowania wycofywałby fakt, a odbudowa widoku potrzebowałaby
osobnej ścieżki. Worker w tle czyta `ReadAllAsync` i jest tą samą ścieżką co odbudowa: kasujesz
wiersz checkpointu, worker idzie od zera. Nie ma drugiej procedury „przebuduj artykuły”. Jest
`RunOnceAsync`, które test woła bez czekania na zegar, i pętla, która woła je w hoście.

`ProjectionWorker<TReadContext>` jest `BackgroundService`. Na przejście otwiera scope, woła
`GetRequiredService<ProjectionRunner<TReadContext>>`, potem `RunOnceAsync`. Przy wyniku 0 czeka
`Task.Delay(IdleDelay, stoppingToken)`. Awaria `DbException` albo `DbUpdateException` loguje się
jako `Warning` i pętla zostaje. Fakty w bazie zapisu czekają. Worker nie wycofuje strumienia, bo
strumień jest już zatwierdzony. Następna pętla czyta od tego samego checkpointu, a upsert po
`Version` nie cofa nowszego tytułu, jeśli widok zdążył dojść dalej.

Koszt: odczyt jest ostatecznie spójny, nie natychmiastowy. Liczba ta jest rzędu jednego
`IdleDelay` plus czas paczki, domyślnie pół sekundy postoju, gdy nie ma nowych faktów. Dwie
repliki procesu uruchomiłyby dwa workery na tych samych checkpointach. Upsert po wersji nie
zepsuje wiersza, ale obie robiłyby tę samą pracę. Gdy usługa dostanie drugi pod, worker bierze
`pg_advisory_lock` na bazie odczytu albo staje się osobnym procesem. To dopina
[docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). W tym numerze test idzie na jednym
workerze, a idempotencja jest już prawdziwa. `LISTEN/NOTIFY` przegrywa jako jedyny mechanizm, bo
powiadomienie ginie, gdy proces stoi, i tak trzeba by czytać od zapisanej pozycji. Zostaje
odpytywanie. `LISTEN` można dołożyć później jako budzenie, nie jako źródło prawdy.

### Checkpoint na globalnej `Position`

Jedna liczba na projekcję, w tabeli `Checkpoints` bazy odczytu, mówi: „przetworzyłam wszystko do
tej pozycji w bazie zapisu”. `Position` rośnie w kolejności commitów dzięki blokadzie z numeru
`09`, więc checkpoint nie przeskakuje dziury. Gdyby dziura była, worker zapisałby pozycję 11 i
nigdy nie wczytał 10, a slug z faktu 10 nie wszedłby do widoku. Zamek w bazie zapisu jest po to,
żeby ta liczba była bezpiecznym kursorem. Checkpoint leży w bazie odczytu, nie w bazie zapisu, i
zapisuje się w tym samym `SaveChangesAsync` co widok. Awaria w środku paczki nie zostawia widoku
bez checkpointu ani checkpointu bez widoku.

`Checkpoint` jest `sealed`. Klucz `ProjectionName` to `string` do 200 znaków. `Position`
(`long`) startuje od 0, gdy wiersza nie ma. `ProjectionCheckpointMap.ApplyCheckpoints` mapuje
tabelę. Kontekst odczytu woła tę metodę obok mapowania swoich wierszy. Biblioteka nie ma
własnego `DbContext`. Tak samo jak magazyn z numeru `09`: schemat należy do `*ReadContext`
usługi. Dwie projekcje w jednej usłudze mogą być w różnych miejscach historii. To jest
zamierzone. Da się odbudować jedną, kasując jej wiersz i jej tabelę, bez ruszania drugiej.

Checkpoint per strumień przegrywa, bo worker musiałby znać listę wszystkich strumieni, a nowy
artykuł byłby dla niego niewidoczny, dopóki ktoś nie dopisze identyfikatora. `ReadAllAsync`
idzie po globalnej pozycji właśnie dlatego, że nie zna listy slugów z góry. Runner liczy `after`
jako minimum pozycji tych projekcji, które jeszcze nie są na końcu znanej historii. Czyta
`ReadAllAsync(after, BatchSize)`. Dla zdarzenia woła `Project` tylko tę projekcję, której
checkpoint jest mniejszy niż `Position` i która `CanHandle`. Potem ustawia checkpoint każdej
projekcji, która brała udział, na `Position` ostatniego zdarzenia paczki, które ta projekcja
miała prawo zobaczyć. Jedno `SaveChangesAsync` domyka widok i liczby.

`BatchSize` domyślnie 100. Pusta paczka zwraca 0. Test `Run_respects_batch_size` kładzie trzy
fakty przy `BatchSize` 2: pierwsze `RunOnceAsync` zwraca 2, trzeci fakt dochodzi w drugim
wywołaniu. Runner nie otwiera transakcji rozproszonej między dwoma bazami. Odczyt strumienia
jest `AsNoTracking` i jest zatwierdzony wcześniej. Zapis dotyczy tylko bazy odczytu. Powtórzenie
paczki jest bezpieczne dzięki wersji w wierszu. Koszt minimum zamiast zera: runner nie skanuje
całej historii przy każdym budzeniu, a wolniejsza projekcja nie gubi faktów, które szybsza już
ma za sobą.

### Wiersz i `jsonb`, nie osobny silnik

Widok listy jest wierszem z kolumnami, po których jest `WHERE` i `ORDER BY`: slug, język,
status, data. Widok o kształcie zmiennym, na przykład złożona sekcja strony, może być kolumną
`jsonb` obok kolumn filtrowanych. Indeks jest na kolumnach, których szuka zapytanie.
`IArticleReader.FindBySlugAsync(language, slug, cancellationToken)` czyta taki wiersz. Nie
składa agregatu i nie woła `LoadAsync`. Implementacja w `News.Persistence` używa tylko
`NewsReadContext`.

MongoDB przegrywa: drugi klaster, inna licencja, a zapytanie i tak jest „znajdź po slugu”.
Trzymanie projekcji tylko w Redisie przegrywa, bo Redis nie jest źródłem prawdy. To cache w
[13-redis.md](13-redis.md). Utrata Redisa spowalnia `GET`. Utrata bazy odczytu odbudowuje się z
checkpointu 0. Utrata strumienia nie odbudowuje się z widoku, bo widok jest skutkiem, nie
historią. Dlatego `EventRecord` zostaje w `*_write`, a wiersz listy w `*_read`.

Koszt: kształt widoku jest świadomie zduplikowany wobec zdarzeń. Zmiana ekranu zmienia projekcję
i schemat odczytu, nie zdarzenia historyczne. `news.article-created.v1` zostaje w strumieniu
nawet wtedy, gdy kolumna listy dostanie nowe pole. Nowe pole dostaje projekcja i migracja
`*ReadContext`, nie migracja bazy zapisu. `CanHandle` patrzy na `EventType` z nazwy atrybutu,
nie na nazwę klasy CLR. Projekcja artykułu obsługuje `news.article-created.v1` i kolejne fakty
tego strumienia, a ignoruje resztę. Fakt zapytania Contact w tej samej bazie nie wchodzi do
wiersza notatki. W teście rolę faktu gra `test.happened.v1`.

Konkretny wiersz, na przykład `ArticleSummaryRow` i `ArticleSummaryProjection`, powstaje w
numerze News. Ten numer dowodzi mechanizmu na `TestSummaryRow` i `TestSummaryProjection`.
Kontrakt `IProjection` jest taki sam dla pięciu usług. `Project` tylko zmienia encje śledzone
przez kontekst odczytu, który projekcja dostała w konstruktorze. Nie woła `SaveChangesAsync`.
Zapis jest jeden, w runnerze, razem z checkpointami. Dzięki temu widok i checkpoint nie
rozjeżdżają się.

### Upsert idempotentny

Ta sama pozycja może przyjść drugi raz. Dwa procesy workera, powtórzone przejście po skasowanym
checkpointcie, ponowienie po wyjątku tuż przed zapisem checkpointu. Projekcja zapisuje wiersz
tylko wtedy, gdy `storedEvent.Version` jest większa niż `Version` w wierszu, albo wiersza nie
ma. Druga aplikacja starszej wersji nie cofa tytułu. Widok nie ma reguł agregatu. Nie woła
`Apply`. Jest skutkiem ubocznym faktu, złożonym pod odczyt.

Pseudokod, który spełni test, jest krótki. Brak wiersza oznacza `Add`. Wiersz z `Version`
mniejszą niż `storedEvent.Version` oznacza nadpisanie pól i wersji. Wiersz z wersją równą albo
większą oznacza nic. Test `Run_applies_newer_version` kładzie dwa fakty, drugi zmienia tytuł, i
oczekuje `Title` z drugiego faktu oraz `Version` 2. Test
`Replay_after_lost_checkpoint_keeps_latest` ma widok po wersji 2, kasuje wiersz checkpointu i po
`RunOnceAsync` nadal ma `Title` z wersji 2 oraz jeden wiersz. Test
`Older_event_does_not_overwrite` kładzie wiersz w wersji 2 i podaje projekcji tylko fakt wersji
1. `Title` zostaje z wersji 2.

Koszt: projekcja musi nieść wersję w wierszu. Bez tej kolumny idempotencja byłaby zgadywaniem po
treści. Dwa fakty z tym samym tytułem nie powiedzą, który jest nowszy. Wersja strumienia już
jest na `StoredEvent`. Widok ją kopiuje. To nie jest `Version` optymistyczna zapisu HTTP. To
jest warunek „nie cofaj”. `ETag` zapisu zostaje w numerze `11`. Słaby `ETag` widoku publicznego
dojdzie z numerem usługi.

`Run_inserts_row` oczekuje jednego wiersza i `Title` równego `Nowy wpis` po fakcie
`test.happened.v1`. `Run_writes_checkpoint` oczekuje w `Checkpoints` nazwy projekcji i
`Position` tego faktu. `Second_run_does_nothing` oczekuje zwróconego 0 i nadal jednego wiersza.
Trzy testy razem mówią: pierwsza paczka wstawia i przesuwa kursor, druga nie dubluje. Osobno
idzie powtórka po skasowanym kursorze, żeby nie pomylić „nic nowego” z „odbudowa nie psuje
nowego tytułu”.

### Handler komendy i handler zapytania

`ICommandHandler` dostaje `IEventStore` albo repozytorium zbudowane na `IEventStore`, oraz
`IUnitOfWork` na kontekście zapisu. W jego konstruktorze nie ma `*ReadContext`. Test referencji
projektu `Application` nie zawiera pakietu, który otwiera bazę odczytu. Odczyt w komendzie „czy
slug jest wolny” jest tabelą w bazie zapisu, w tej samej transakcji co strumień, albo regułą
agregatu. Nie jest `SELECT` po `*_read`. Test `Command_path_does_not_open_read_database` daje
komendzie testowej licznik otwarć kontekstu odczytu i oczekuje 0 po `Handle`. Test
`Command_handler_type_does_not_take_read_context` sprawdzi konstruktory w zestawie
`Application`, gdy ten zestaw powstanie. W tym numerze test pilnuje `TestCommand`, którego
konstruktor z `TestReadContext` odrzuca rejestracja pomocnicza.

`IQueryHandler` dostaje port czytnika, na przykład `IArticleReader`, zaimplementowany w
`Persistence` na `*ReadContext`. W jego konstruktorze nie ma `IEventStore`. Zapytanie nie składa
agregatu. Gdy wiersza nie ma, zwraca `not_found`. Gdy wiersz jest, a czytelnik nie ma go
widzieć, też zwraca `not_found`, zgodnie z numerem `11`. Test
`Query_path_does_not_call_event_store` stawia czytnik na `TestReadContext`, liczy wołania
`IEventStore` i oczekuje 0 po `Find`. Publiczny slug i ukryty szkic rozróżnia handler zapytania,
nie worker. Worker zapisuje wiersz. Nie decyduje o `403`.

Koszt: nie da się w komendzie „szybko sprawdzić widoku”. Na tym polega rozdział. Slug i inne
jednoznaczności pilnuje baza zapisu. Zapytanie HTTP dostaje inny scope niż worker:
`NewsReadContext` i brak `IEventStore`. Skład w `Program.cs` rejestruje oba konteksty, a
handlery biorą tylko swój port. `AddProjectionWorker<NewsReadContext>` rejestruje runner jako
scoped, projekcje jako scoped i hosted service. `IEventStore` w hoście workera wskazuje
`PostgresEventStore<NewsWriteContext>`. Pomieszanie tych scope’ów w jednym konstruktorze jest
tym, co test odrzuca.

`NewsReadContext` i pozostałe cztery konteksty dziedziczą po `DbContext`, wołają
`ApplyCheckpoints` i mapują własne tabele. Nie wołają `ApplyEventStore`. Nazwy:
`IdentityReadContext`, `NewsReadContext`, `LearningReadContext`, `CvReadContext`,
`ContactReadContext`. Każdy jest właścicielem swojej bazy `*_read` i jej schematu. Usługa nie
dostaje connection stringa do `*_read` ani `*_write` sąsiada. `Core` nie referencjonuje
`JJDevHub.Projections`. Projekcja jest adapterem odczytu, nie modelem domeny.

## Klasy i ścieżki

Biblioteka zna paczkę, checkpoint i pętlę. Nie zna artykułu. Usługa zna wiersz listy i port
czytnika. Test zna `TestSummaryRow`, dwie bazy i `PostgresEventStore<TestWriteContext>`. Tabela
trzyma ten podział. Konkretny `ArticleSummaryRow` do tabeli nie wchodzi, bo powstaje w numerze
News, na tym samym `IProjection`.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Projections/JJDevHub.Projections.csproj` | referencja do `JJDevHub.EventStore`, EF Core PostgreSQL, hosting |
| `src/shared/JJDevHub.Projections/Checkpoint.cs` | `ProjectionName`, `Position` |
| `src/shared/JJDevHub.Projections/ProjectionCheckpointMap.cs` | tabela `Checkpoints` |
| `src/shared/JJDevHub.Projections/IProjection.cs` | `Name`, `CanHandle`, `Project` |
| `src/shared/JJDevHub.Projections/ProjectionOptions.cs` | `BatchSize`, `IdleDelay` |
| `src/shared/JJDevHub.Projections/ProjectionRunner.cs` | jedno przejście paczki |
| `src/shared/JJDevHub.Projections/ProjectionWorker.cs` | pętla w tle |
| `src/shared/JJDevHub.Projections/ProjectionServiceCollectionExtensions.cs` | `AddProjectionWorker<TReadContext>` |
| `src/services/Identity/Identity.Persistence/IdentityReadContext.cs` | `identity_read` |
| `src/services/News/News.Persistence/NewsReadContext.cs` | `news_read` |
| `src/services/Learning/Learning.Persistence/LearningReadContext.cs` | `learning_read` |
| `src/services/Cv/Cv.Persistence/CvReadContext.cs` | `cv_read` |
| `src/services/Contact/Contact.Persistence/ContactReadContext.cs` | `contact_read` |
| `tests/JJDevHub.Projections.Tests/ProjectionRunnerTests.cs` | dwie bazy w jednym kontenerze |

`IArticleReader` leży w `JJDevHub.News.Application` i zasłania EF przed przypadkiem użycia.
Implementacja leży w `News.Persistence`. W tym numerze odpowiednikiem jest czytnik na
`TestReadContext`. Pakiety biblioteki to `Npgsql.EntityFrameworkCore.PostgreSQL` i
`Microsoft.Extensions.Hosting.Abstractions`, plus referencja do `JJDevHub.EventStore`. Test
dokłada `Testcontainers.PostgreSql` i referencję do `JJDevHub.EventStore.Postgres`, bo zapis
idzie prawdziwym `PostgresEventStore`, nie atrapą w pamięci. Inaczej dziura w `Position` nie
byłaby sprawdzana na tym silniku, który ją potrafi zrobić.

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.Projections -o src/shared/JJDevHub.Projections -f net11.0
dotnet new xunit -n JJDevHub.Projections.Tests -o tests/JJDevHub.Projections.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.Projections tests/JJDevHub.Projections.Tests
dotnet add src/shared/JJDevHub.Projections reference src/shared/JJDevHub.EventStore
dotnet add src/shared/JJDevHub.Projections package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add src/shared/JJDevHub.Projections package Microsoft.Extensions.Hosting.Abstractions
dotnet add tests/JJDevHub.Projections.Tests reference src/shared/JJDevHub.Projections
dotnet add tests/JJDevHub.Projections.Tests reference src/shared/JJDevHub.EventStore.Postgres
dotnet add tests/JJDevHub.Projections.Tests package Testcontainers.PostgreSql
```

Test ma cechę `Category=Integration`. Obraz to `postgres:16-alpine`. Jeden kontener, dwie bazy:
`projection_write` i `projection_read`, tworzone przez `CREATE DATABASE` z połączenia do
`postgres`.

### 2. Checkpoint

`Checkpoint` jest `sealed`. Klucz `ProjectionName` (`string`, do 200 znaków). `Position`
(`long`) startuje od 0, gdy wiersza nie ma. `ProjectionCheckpointMap.ApplyCheckpoints(this
ModelBuilder)` mapuje tabelę `Checkpoints`. Kontekst odczytu woła tę metodę obok mapowania
swoich wierszy.

Biblioteka nie ma własnego `DbContext`. Tak samo jak magazyn z numeru `09`: schemat należy do
`*ReadContext` usługi.

### 3. Kontrakt projekcji

```csharp
namespace JJDevHub.Projections
{
    public interface IProjection
    {
        string Name { get; }

        bool CanHandle(StoredEvent storedEvent);

        void Project(StoredEvent storedEvent);
    }
}
```

`Project` tylko zmienia encje śledzone przez kontekst odczytu, który projekcja dostała w
konstruktorze. Nie woła `SaveChangesAsync`. Zapis jest jeden, w runnerze, razem z checkpointami.
Dzięki temu widok i checkpoint nie rozjeżdżają się.

`CanHandle` patrzy na `EventType` z nazwy atrybutu, nie na nazwę klasy CLR. Projekcja artykułu
obsługuje `news.article-created.v1` i kolejne fakty tego strumienia, a ignoruje resztę.

Wersja w wierszu jest częścią upsertu. Pseudokod, który spełni test:

- brak wiersza — `Add`,
- wiersz z `Version` mniejszą niż `storedEvent.Version` — nadpisanie pól i wersji,
- wiersz z wersją równą albo większą — nic.

### 4. Runner

`ProjectionRunner<TReadContext>` dostaje `IEventStore`, `TReadContext`,
`IEnumerable<IProjection>` i `ProjectionOptions`. `RunOnceAsync` zwraca liczbę przerobionych
zdarzeń.

Kroki:

- wczytaj checkpointy, brak wiersza to pozycja 0,
- `after` to minimum pozycji tych projekcji, które jeszcze nie są na końcu znanej historii,
- `ReadAllAsync(after, BatchSize)`,
- pusta paczka zwraca 0,
- dla każdego zdarzenia i każdej projekcji, której checkpoint jest mniejszy niż `Position` i
  która `CanHandle`, wołaj `Project`,
- ustaw checkpoint każdej projekcji, która brała udział, na `Position` ostatniego zdarzenia
  paczki, które ta projekcja miała prawo zobaczyć,
- jedno `SaveChangesAsync`.

`BatchSize` domyślnie 100. Runner nie otwiera transakcji rozproszonej między dwoma bazami.
Odczyt strumienia jest `AsNoTracking` i jest zatwierdzony wcześniej. Zapis dotyczy tylko bazy
odczytu. Powtórzenie paczki jest bezpieczne dzięki wersji w wierszu.

### 5. Worker

`ProjectionWorker<TReadContext>` w `ExecuteAsync` aż do anulowania:

- scope, `GetRequiredService<ProjectionRunner<TReadContext>>`,
- `RunOnceAsync`,
- wynik 0 — `Task.Delay(IdleDelay, stoppingToken)`, domyślnie 500 ms,
- `DbException` albo `DbUpdateException` — log `Warning`, to samo opóźnienie, kolejna pętla.

Dwie repliki procesu uruchomiłyby dwa workery na tych samych checkpointach. Upsert po wersji nie
zepsuje wiersza, ale obie robiłyby tę samą pracę. Gdy usługa dostanie drugi pod, worker bierze
`pg_advisory_lock` na bazie odczytu albo staje się osobnym procesem. To dopina
[docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). W tym numerze test idzie na jednym
workerze, a idempotencja jest już prawdziwa.

### 6. Kontekst odczytu usługi

`NewsReadContext` i pozostałe cztery konteksty dziedziczą po `DbContext`, wołają
`ApplyCheckpoints` i mapują własne tabele. Nie wołają `ApplyEventStore`. Strumień nie leży w
bazie odczytu.

`AddProjectionWorker<NewsReadContext>` rejestruje runner jako scoped, projekcje jako scoped i
hosted service. `IEventStore` w tym hoście wskazuje `PostgresEventStore<NewsWriteContext>`.
Zapytania HTTP dostają inny scope, z `NewsReadContext` i bez `IEventStore`. Skład w `Program.cs`
rejestruje oba konteksty, a handlery biorą tylko swój port. Test
`Command_handler_type_does_not_take_read_context` sprawdza konstruktory w zestawie
`Application`, gdy ten zestaw powstanie. W tym numerze test pilnuje `TestCommand`, którego
konstruktor z `TestReadContext` odrzuca rejestracja pomocnicza.

Port czytnika:

```csharp
namespace JJDevHub.News.Application
{
    public interface IArticleReader
    {
        Task<ArticleSummary?> FindBySlugAsync(string language, string slug, CancellationToken cancellationToken);
    }
}
```

Implementacja jest w `News.Persistence` i używa tylko `NewsReadContext`.

### 7. Okno po zapisie

Test `Read_after_command_before_projection_is_empty` zapisuje fakt do bazy zapisu i czyta bazę
odczytu zanim poleci runner. Wynik jest pusty. Drugi fakt testu woła `RunOnceAsync` i widzi
wiersz. Dokumentujemy to jako zachowanie, nie jako błąd do zatkania synchroniczną projekcją.

### Co jest do czego

- `Checkpoint` woła runner przy starcie paczki i przy `SaveChangesAsync`. Pamięć workera w bazie
  odczytu. Jedna liczba na projekcję, klucz `ProjectionName`. Bez wiersza pozycja startuje od 0
  i widok buduje się od początku strumienia. Bez zapisu w tym samym `SaveChanges` co widok
  awaria zostawia wiersz artykułu bez kursora albo kursor bez wiersza.
- `ApplyCheckpoints` woła `OnModelCreating` każdego `*ReadContext`. Bez tego tabela
  `Checkpoints` nie wchodzi do modelu, a worker nie ma gdzie zapisać `Position`. Metoda nie woła
  `ApplyEventStore`. Strumień nie pojawia się w `*_read`.
- `IProjection` woła runner dla każdego `StoredEvent`, który projekcja `CanHandle`. Tłumaczy
  fakt na encje widoku. Nie zapisuje sama. Bez `Project` nie ma kto złożyć sluga i tytułu. Bez
  `CanHandle` po `EventType` projekcja artykułu łykałaby fakt o nazwie klasy CLR albo fakt
  zapytania Contact.
- `ProjectionOptions` woła runner i worker. `BatchSize` domyślnie 100, `IdleDelay` domyślnie 500
  ms. Bez opcji paczka albo skanuje całą historię na raz, albo host nie ma postoju, gdy faktów
  nie ma. Test `Run_respects_batch_size` ustawia 2 i oczekuje dwóch przejść na trzy fakty.
- `ProjectionRunner` woła test i worker. Jedno przejście, które test woła bez czekania na zegar.
  Bez niego pętla w tle byłaby jedyną ścieżką, a okno „zapis jest, odczytu nie ma” nie dałoby
  się pokazać bez zegara. `RunOnceAsync` zwraca liczbę przerobionych zdarzeń. Zero oznacza pustą
  paczkę.
- `ProjectionWorker` woła host jako `BackgroundService`. Pętla sprawia, że komenda nie woła
  projekcji. Bez workera widok stoi w miejscu albo komenda czeka na indeksy odczytu i błąd
  widoku wycofuje fakt. `DbException` i `DbUpdateException` zostają w logu `Warning`. Strumień
  czeka na następną pętlę.
- `*ReadContext` woła `Api` i worker. Właściciel bazy `*_read` i jej schematu:
  `IdentityReadContext`, `NewsReadContext`, `LearningReadContext`, `CvReadContext`,
  `ContactReadContext`. Bez kontekstu nie ma gdzie mapować wiersza listy ani checkpointu.
  Kontekst zapisu nie zastępuje odczytu: komenda nie dostaje `*ReadContext`.
- `IArticleReader` i porty bliźniacze woła handler zapytania. Jedyna droga zapytania do wiersza.
  Zasłania EF przed `Application`. Bez portu zapytanie albo bierze `DbContext`, albo woła
  `IEventStore` i składa artykuł na `GET`. `FindBySlugAsync` przyjmuje język i slug.
  Implementacja używa tylko `NewsReadContext`.
- `TestSummaryProjection` i `TestSummaryRow` woła `ProjectionRunnerTests`. Dowód upsertu i
  checkpointu bez domeny News. Bez nich test ciągnąłby `ArticleSummaryRow`, którego ten numer
  nie posiada. Tytuł `Nowy wpis` i fakt `test.happened.v1` wystarczą, żeby pokazać wstawienie,
  wersję 2 i powtórkę.
- `AddProjectionWorker<TReadContext>` woła `Program.cs` obok rejestracji obu kontekstów.
  Rejestruje runner i projekcje jako scoped oraz hosted service. Bez tego pętla nie wstaje, a
  `IEventStore` hosta workera nie wskazuje `PostgresEventStore<NewsWriteContext>`. Zapytania
  HTTP zostają w scope bez `IEventStore`.
- Wersja w wierszu woła upsert. Warunek, dzięki któremu powtórka nie cofa widoku. Bez kolumny
  `Version` skasowany checkpoint nadpisałby tytuł starszym faktem. Test
  `Older_event_does_not_overwrite` i `Replay_after_lost_checkpoint_keeps_latest` padają, gdy
  warunek zniknie.
- `StoredEvent.Position` woła checkpoint. Bez pozycji z numeru `09` kursor nie ma liczby
  rosnącej w kolejności commitów. Runner nie liczy jej ze sluga. Slug jest kolumną widoku, nie
  kursorem całej bazy.

## Testy

Klasa `ProjectionRunnerTests` w `tests/JJDevHub.Projections.Tests`. xUnit, `[Fact]`,
`[Trait("Category", "Integration")]`. Fixture podnosi `postgres:16-alpine`, tworzy dwie bazy,
woła `EnsureCreated` na `TestWriteContext` i `TestReadContext`. Zapis idzie przez
`PostgresEventStore<TestWriteContext>`. Odczyt sprawdza `TestSummaryRow`. Każdy fakt ma jeden
powód do padnięcia. Jeden kontener i `CREATE DATABASE` z połączenia do `postgres` są po to, żeby
nie udawać granicy baz dwoma schematami na jednym stringu.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Run_inserts_row` | jeden fakt `test.happened.v1` z tytułem `Nowy wpis` | `RunOnceAsync` | jeden wiersz, `Title` równe `Nowy wpis` |
| `Run_writes_checkpoint` | jeden fakt | `RunOnceAsync` | `Checkpoints` ma nazwę projekcji i `Position` tego faktu |
| `Second_run_does_nothing` | projekcja już wykonana | drugie `RunOnceAsync` | zwrócone 0, nadal jeden wiersz |
| `Run_applies_newer_version` | dwa fakty, drugi zmienia tytuł | `RunOnceAsync` | `Title` z drugiego faktu, `Version` 2 |
| `Replay_after_lost_checkpoint_keeps_latest` | widok po wersji 2, wiersz checkpointu skasowany | `RunOnceAsync` | nadal `Title` z wersji 2, jeden wiersz |
| `Older_event_does_not_overwrite` | wiersz w wersji 2, do runnera wchodzi tylko fakt wersji 1 przez cofnięty checkpoint i filtr testowy | `Project` | `Title` zostaje z wersji 2 |
| `Run_respects_batch_size` | trzy fakty, `BatchSize` 2 | `RunOnceAsync` | zwrócone 2, trzeci fakt dochodzi w drugim wywołaniu |
| `Query_path_does_not_call_event_store` | czytnik na `TestReadContext`, licznik wołań `IEventStore` | `Find` | licznik równy 0 |
| `Command_path_does_not_open_read_database` | komenda testowa z licznikiem otwarć kontekstu odczytu | `Handle` | licznik równy 0 |

```bash
dotnet test tests/JJDevHub.Projections.Tests
```

Test `Read_after_command_before_projection_is_empty` jest w planie jako opis zachowania okna.
Tabela wyżej pilnuje skutku runnera, wersji i tego, że komenda oraz zapytanie nie mieszają baz.
Jeden fakt nie łączy „wstawiono wiersz” z „zapytanie nie woła strumienia”, bo czerwony test ma
wskazać jedną decyzję. Obraz kontenera zostaje `postgres:16-alpine`. Cecha
`Category=Integration` wyłącza ten projekt z filtra bez kontenerów.

## Zasady

- Worker czyta `IEventStore` swojej usługi i zapisuje tylko jej `*ReadContext`. Złamanie daje
  News zapis do `learning_read` albo odczyt strumienia sąsiada.
- Handler komendy nie dostaje `*ReadContext` i nie otwiera bazy `*_read`. Złamanie sprawdza
  wolny slug na widoku, który jeszcze nie dogonił commitu, i puszcza dwa artykuły.
- Handler zapytania nie dostaje `IEventStore` i nie woła `LoadAsync` ani `ReadAllAsync`.
  Złamanie składa agregat na `GET` i ciągnie reguły oraz całą historię na ścieżkę listy.
- Widok i checkpoint schodzą jednym `SaveChangesAsync`. Złamanie zostawia wiersz bez kursora
  albo kursor, za którym wiersza nie ma, i powtórka gubi albo dubluje tytuł.
- Upsert jest idempotentny po `Version`. Złamanie pozwala starszemu faktowi cofnąć tytuł po
  skasowanym checkpointcie albo po drugim workerze.
- `EventType` w `CanHandle` to nazwa z `[EventName]`. Złamanie wiąże widok z nazwą klasy CLR i
  gubi `news.article-created.v1` po przeniesieniu typu.
- Projekcja nie leży w MongoDB i nie leży w Redisie jako jedyna kopia. Złamanie dokłada drugi
  silnik albo kasuje jedyny widok razem z cache.
- `Core` nie referencjonuje `JJDevHub.Projections`. Złamanie wciąga agregat w worker i w
  kontekst odczytu.
- Baza odczytu nie zawiera tabel `EventStreams` ani `EventRecords`. Złamanie miesza strumień z
  widokiem i kasowanie `*_read` kasuje historię.
- Usługa nie dostaje connection stringa do `*_read` ani `*_write` sąsiada. Złamanie pozwala Cv
  złożyć stronę z `learning_read` zamiast z kopii niesionej przez `learning.integration`.

## Poza zakresem

- Kształt `ArticleSummaryRow`, katalogu kursu i strony CV jest w numerach usług, od
  [17-identity.md](17-identity.md). Tu jest `TestSummaryRow` i kontrakt `IProjection`.
- Cache i unieważnienie klucza po udanej projekcji są w [13-redis.md](13-redis.md). Widok w
  Postgresie zostaje źródłem odczytu nawet wtedy, gdy klucz zniknie.
- Zdarzenie integracyjne do innej usługi jest w [14-outbox.md](14-outbox.md) i
  [15-kafka.md](15-kafka.md). `learning.integration` nie zastępuje `learning_read` wewnątrz
  Learning.
- `ETag` zapisu jest w [11-walidacja.md](11-walidacja.md). Słaby `ETag` widoku publicznego
  dochodzi z numerem usługi, nie z checkpointu.
- Drugi pod i blokada workera są w [docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). Ten
  numer testuje jednego workera. Idempotencja po `Version` już obowiązuje.
- Powiadomienie przeglądarki, że widok już jest, nie powstaje. Klient ponawia `GET`. `LISTEN`
  nie jest źródłem prawdy.

## Źródła

- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs). Wiążący
  jest osobny model odczytu i spójność ostateczna. W tym pliku komenda nie otwiera `*_read`,
  zapytanie nie woła `IEventStore`, a `GET` zaraz po `POST` może dostać `404`. Nie bierzemy
  synchronicznej projekcji w transakcji `AppendAsync`. Błąd widoku nie wycofuje faktu.
- [Materialized View
  pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/materialized-view).
  Wiążący jest widok pod zapytanie, odświeżany ze źródła, a nie składany przy każdym odczycie. W
  tym pliku wiersz ma kolumny sluga, języka, statusu i daty, a kształt zmienny może iść do
  `jsonb`. Nie bierzemy odświeżania widoku wewnątrz bazy zapisu jako jedynej kopii. Źródłem
  odświeżenia jest `ReadAllAsync`, a widok leży w `*_read`.
- [Event Sourcing
  pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing).
  Wiążąca jest projekcja ze strumienia zdarzeń. W tym pliku worker czyta `StoredEvent` od
  `Position` i woła `Project`. Nie bierzemy odtwarzania agregatu na ścieżce HTTP. `CanHandle`
  używa nazwy z `[EventName]`, na przykład `news.article-created.v1`, a nie nazwy klasy.
- Martin Fowler, [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html). Wiążące
  jest budowanie widoku z historii i możliwość odbudowy tego widoku od zera. W tym pliku
  skasowanie wiersza checkpointu i tabeli widoku puszcza worker od pozycji 0, bez dotykania
  `EventRecords`. Nie bierzemy osobnego produktu na zdarzenia. Strumień zostaje w Postgresie
  usługi, w bazie `*_write`.
- Martin Kleppmann, *Designing Data-Intensive Applications*. Wiążący jest log jako źródło danych
  pochodnych i kursor, który nie przeskakuje dziury. W tym pliku `Position` z numeru `09` jest
  tym kursorem, a checkpoint zapisuje się razem z widokiem. Nie bierzemy kompaktowania
  strumienia domenowego: fakty w `*_write` zostają. Nie bierzemy Kafki jako bazy odczytu tej
  usługi. `learning.integration` jest kopią dla sąsiada, nie zamiennikiem `learning_read`.
- Gregory Young, *Versioning in an Event Sourced System*. Wiążąca jest wersja faktu, która mówi,
  co jest nowsze. W tym pliku wiersz widoku niesie `Version`, a starszy `storedEvent` nie
  nadpisuje tytułu. Nie bierzemy zgadywania idempotencji po treści. Test
  `Older_event_does_not_overwrite` i powtórka po skasowanym checkpointcie stoją na tej liczbie.
- Vaughn Vernon, *Implementing Domain-Driven Design*. Wiążąca jest ostateczna spójność modelu
  odczytu: użytkownik może nie zobaczyć skutku zapisu w tym samym żądaniu. W tym pliku okno po
  komendzie jest udokumentowane testem pustego odczytu, a klient ponawia `GET`. Nie bierzemy
  dociągania widoku w tej samej transakcji co agregat. Nie bierzemy też czytania bazy sąsiada,
  żeby „mieć świeższy” katalog.
- [Database per service](https://microservices.io/patterns/data/database-per-service). Chris
  Richardson: usługa nie czyta cudzej bazy. W tym pliku dochodzi druga baza tej samej usługi,
  `*_read`, i zakaz stringa do `*_read` oraz `*_write` sąsiada. Nie bierzemy złożenia obu modeli
  w jednej bazie pod dwoma schematami. Nie bierzemy też jednego wspólnego odczytu dla News i
  Learning.
- [Idempotent
  Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html).
  Hohpe i Woolf: powtórka nie cofa stanu. W tym pliku powtórka paczki, drugi worker i odbudowa
  po skasowanym checkpointcie opierają się na `Version` w wierszu. Nie bierzemy deduplikacji po
  samym `EventId` widoku, jeśli wersja mówi, że fakt jest starszy. Brak wiersza to `Add`. Wersja
  równa albo większa to brak zapisu.
- [Background
  tasks](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/host/hosted-services).
  Wiążący jest `BackgroundService` i scope na jedno przejście. W tym pliku `ProjectionWorker`
  woła `GetRequiredService` wewnątrz scope, a `DbException` nie kończy procesu. Nie bierzemy
  projekcji na wątku żądania HTTP. `IdleDelay` 500 ms jest postojem pustej paczki, nie
  harmonogramem biznesowym.
- [PostgreSQL JSON types](https://www.postgresql.org/docs/16/datatype-json.html). Wiążący jest
  `jsonb` tam, gdzie widok nie jest płaską listą kolumn. W tym pliku kolumna dokumentu stoi obok
  kolumn filtrowanych, a indeks jest na slug, język, status i datę. Nie bierzemy typu `json` ani
  drugiego silnika dokumentów. Lista „ostatnie notatki” zostaje wierszem.
- [PostgreSQL explicit locking: advisory
  locks](https://www.postgresql.org/docs/16/explicit-locking.html#ADVISORY-LOCKS). Wiążący jest
  zamek sesji, gdy dwa procesy chcą robić tę samą pracę. W tym pliku drugi pod, gdy przyjdzie,
  bierze `pg_advisory_lock` na bazie odczytu albo worker staje się osobnym procesem. Tę decyzję
  dopina numer o skalowaniu. Nie bierzemy drugiego workera w teście tego numeru. Idempotencja po
  `Version` już obowiązuje, zamek tylko odcina podwójną pracę.

## Gotowe gdy

- Test tworzy dwie bazy na jednym serwerze i nie miesza ich tabel.
- Jedno `RunOnceAsync` wstawia wiersz i przesuwa `Checkpoints`.
- Drugie przejście zwraca 0.
- Powtórka po skasowanym checkpointcie nie dubluje wiersza i nie cofa nowszej wersji.
- Zapytanie testowe nie woła `IEventStore`.
- Komenda testowa nie otwiera kontekstu odczytu.
- `dotnet test tests/JJDevHub.Projections.Tests` kończy się kodem 0.
