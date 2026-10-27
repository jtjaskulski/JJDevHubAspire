# 22. Testy

Ten numer domyka piramidę testów API. Poprzedni plik tego folderu to [kontakt](21-kontakt.md).
W kolejności pracy poprzedni jest drugi pod w [15-skalowanie.md](../cicd/15-skalowanie.md).
Dalsza praca leży w [motywie](../frontend/01-motyw.md). Piramida zamyka się tutaj: motyw nie dokłada piętra
testów usług. Ten numer nie dodaje endpointu, agregatu ani bazy. Ustala, który test gdzie stoi,
jaką ma cechę i która bramka go uruchamia.

Bez tego numeru numery 01–21 dokładają przypadki do trzech pięter, ale jeden `dotnet test`
nie wie, które piętro jest które. Filtr jednostkowy zaczyna ciągnąć kontenery. Obciążenie
czekałoby na `main` i pull request do `develop` wjeżdżałby dalej bez percentyli publicznego
odczytu. Ten numer spina piętra z gałęziami, które już opisuje `docs/cicd/02-bramki.md`.

Scenariusz, który się psuje, jest konkretny. Ktoś dopisuje test outboxa z Postgresem i bez
cechy. Filtr jednostkowy go bierze, bo nie umie odrzucić kontenera. Runner `ubuntu-latest` albo
nie ma Dockera i pali się na starcie, albo ma Dockera i wydłuża każdą zmianę w jądrze. Osobno
ktoś mierzy `GET` strony pętlą `Task.WhenAll` albo odkłada narzędzie na konsolę. Bramka nie
pada sama. Po tym numerze piętro bez cechy jedzie w `unit-tests`, kontener jedzie w
`integration-tests`, a NBomber jedzie w `performance`. Trzy joby są warunkiem wejścia na
`develop`.

Motyw, który przychodzi potem, nie otwiera tej piramidy. Test komponentu React i telefonu stoi
przy `docs/frontend`. Najbliższy numer to motyw. Usługi mają już projekty, cechy i trzy komendy.
Ten numer ich nie wymyśla drugi raz. Wymaga, żeby stały w solution i żeby filtr workflow je
rozdzielił.

## Po co

Numery 01–21 dokładają przypadki do trzech pięter. Bez wspólnej reguły jeden `dotnet test`
bez filtra miesza kontener z NBomberem i z przypadkiem, który ma chodzić bez Dockera. Ten
numer spina piętra z gałęziami z `docs/cicd/02-bramki.md`. Po nim jest prawdą, że trzy joby
odpalają się na `develop`, na `release` i na `main`. Test jednostkowy idzie filtrem bez
Dockera. Test integracyjny z Testcontainers idzie filtrem `Category=Integration`. Test
NBomber z cechą `Category=Performance` idzie osobnym jobem. Czerwony przebieg któregoś z
trzech blokuje pull request do `develop`.

Każdy przypadek ma jeden powód do padnięcia i nazwę w kształcie
`Create_blank_title_returns_invalid`. Biblioteki współdzielone i każda z pięciu usług mają
projekty testowe z listy poniżej. Biblioteka dostaje projekt o nazwie biblioteki z sufiksem
`.Tests`, bo nie ma warstw Core i Api. Usługa dostaje piątkę. Jeden projekt `Tests` na usługę
odpadł, bo reguła agregatu nie może ciągnąć hosta.

Czytelnik tego numeru nie znajduje tu listy pól `Article`. Listy pól zostają w numerach 17–21.
Tu jest inventarz projektów i trzy komendy. Nowy agregat testowy w Core którejś usługi odpadł.
Osobna usługa Test odpadła. Zmiana dotyka solution, cech, filtrów workflow i luk w projektach
testowych. Nie zmienia kontraktu HTTP, strumienia ani schematu bazy usług.

## Dlaczego ta technologia

### xUnit

Runner to xUnit. Przypadek jednostkowy i integracyjny jest metodą `[Fact]`. Asercje biorą się z
`Assert` w tym runnerze. Solution ma jeden przebieg `dotnet test`. Drugi runner w tym samym
solution rozdziela filtr cech i raport bramki. Wersja pakietu xUnit, licencja Apache 2.0, stoi w
`Directory.Packages.props`. Nazwa metody niesie scenariusz, bo runner nie składa zdania z
osobnego DSL.

NUnit i MSTest odpadły jako drugi styl atrybutów obok `[Fact]`. Własny host metod testowych
odpadł. FluentAssertions odpadło: nowsze linie pakietu nie są licencją, którą ten zestaw
przyjmuje bez zastrzeżeń, a `Assert` w xUnit wystarcza do jednego powodu. Asercja oczekiwanego
błędu sprawdza kod `Result<T>` albo status HTTP, jeden skutek na metodę. Dwie asercje jednego
skutku zostają jednym powodem. Osobny `[Fact]` sprawdzałby drugi skutek, na przykład outbox obok
odrzucenia pustego tytułu.

Koszt jest w nazwie. Metoda nie dostaje zdania po polsku i nie dostaje słowa `Test1`. Kod i
tytuły commitów są po angielsku, a dokument numeru jest po polsku. Wzorzec to
`Czynność_warunek_skutek`. Odniesienie, które ten numer powtarza, a nie wymyśla, to
`Create_blank_title_returns_invalid`. Pusty tytuł notatki zostaje w `News.Core.Tests` albo
`News.Application.Tests`, bez cechy. Przypadek integracyjny na tej samej regule dostaje cechę i
nie powtarza asercji Core, tylko skutek transakcji.

### Testcontainers

Test integracyjny podnosi Postgresa obrazem `postgres:16-alpine` i, gdy sprawdza szynę, Kafkę
przez `Testcontainers.Kafka` w trybie KRaft, bez Zookeepera. Redis w teście, który naprawdę
dotyczy klucza, też idzie kontenerem. Cecha klasy albo metody:
`[Trait("Category", "Integration")]`. Pakiet Testcontainers jest na licencji MIT. Czas bramki
`release` i Docker na runnerze są kosztem tego piętra. Test jednostkowy tego kosztu nie płaci,
bo cecha go wyłącza z `develop`.

Wspólna baza na runnerze `ubuntu-latest` zostawia wiersze między pull requestami i kłamie, że
test jest powtarzalny. Sqlite w pamięci jako zamiennik Postgresa odpadł, bo JSONB, transakcja
outboxa i `UPSERT` mają być tym silnikiem co w AppHost. MongoDB jako kontener testowy odpadł
razem z MongoDB w produkcie. Ręczne `docker run` na hoście dewelopera odpadło, bo CI nie ma tego
kroku w skrypcie człowieka. Test integracyjny nie jest zastępowany testem w pamięci, gdy skutek
dotyczy transakcji Postgresa albo offsetu Kafki.

Koszt jest dyscypliną cechy. Przypadek integracyjny bez cechy wjedzie na `develop` i albo spali
bramkę brakiem Dockera, albo wydłuży ją kontenerem. Przegląd numeru sprawdza cechę razem z
asercją. Job `develop` nie instaluje warunku „odpal też Integration”. Obraz `postgres:16-alpine`
i tryb KRaft są wspólne dla numerów 17–21. Ten numer ich nie podmienia.

### NBomber i cecha Performance

Scenariusz obciążenia stoi w projekcie `Performance.Tests` i ma
`[Trait("Category", "Performance")]`. Odpala go NBomber. Bramka `main` jest jedyną, która ten
zestaw wymaga. Pull request do `develop` przechodzi przy czerwonym albo przy nieodpalonym
scenariuszu wydajności, o ile reszta bramki `develop` jest zielona. Test jednostkowy nie mówi,
czy publiczny `GET` strony, katalogu, listy notatek albo JWKS mieści się w czasie przy
współbieżnych odczytach.

Pętla `Task.WhenAll` bez percentyli odpadła. Osobny proces k6 poza solution odpadł, bo
scenariusz ma żyć przy endpoincie, który opisuje numer usługi, i ma dać się filtrować tą samą
cechą co reszta. Ręczne odpalanie narzędzia z konsoli bez `[Fact]` odpadło, bo `main` ma
czerwienić się samo. Każdy numer 17–21 wskazuje jeden `GET`. Ten numer go nie zastępuje: JWKS,
lista notatek, katalog, strona CV i lista zapytań studenta z tokenem ownera.

Koszt licencji jest jawny. Pakiet NBomber od wersji 5 nie jest na licencji MIT ani Apache 2.0,
gdy używa go organizacja. Użycie osobiste bywa darmowe i nie jest podstawą tego repozytorium.
Przypięcie wersji 4 tylko po to, żeby zostać przy Apache 2.0, jest sprzeczne z regułą licencji:
starej wersji nie przypina się, żeby ominąć zmianę licencji. Pakiet jest zależnością testu
wydajnościowego i nie wchodzi do obrazu usługi. Wiersz tabeli pakietów w `docs/api/README.md` ma
podać licencję NBomber, nie MIT. Scenariusz nie woła formularza publicznego Contact, żeby bramka
`main` nie zalała zapisu zapytaniami. `POST /api/contact/recruiter-inquiries` w logu filtra
wydajnościowego nie występuje.

### Trzy bramki

Filtr jest umową między tym numerem a bramkami.

| Gałąź | Job | Filtr |
| --- | --- | --- |
| `develop`, `release`, `main` | testy jednostkowe | `Category!=Integration&Category!=Performance` |
| `develop`, `release`, `main` | testy integracyjne | `Category=Integration` |
| `develop`, `release`, `main` | testy wydajnościowe | `Category=Performance` |

Jedna komenda `dotnet test` bez filtra na `develop` ciągnie Docker i NBomber przy każdym pushu
na gałąź roboczą. Osobne solution na piętro odpadło, bo projekt testowy należy do komponentu i
ma być w tym samym grafie co produkcja. Cecha w nazwie projektu zamiast `[Trait]` odpadła jako
jedyny mechanizm: projekt `Persistence.Tests` i tak niesie cechę, a filtr ma działać także
wtedy, gdy w jednym projekcie stanie obok przypadek bez cechy. Wspólna stała, jeden typ w
`src/shared/tests/TestTraits.cs` albo w każdej asemblacji tak samo, nazywa cechę `Category`, a
wartościami są `Integration` i `Performance`. Drugiej nazwy cechy na to samo piętro nie ma.

Koszt to trzy przebiegi na każdej długiej gałęzi i dyscyplina cechy. Job `unit-tests` używa
filtra bez integracji i bez wydajności. Job `integration-tests` używa `Category=Integration`.
Job `performance` używa `Category=Performance` i nie oznacza scenariusza jako pomijalnego.
Checki nazwy gałęzi, CodeQL,
SonarQube, skan obrazu, SBOM i tag komponentu zostają w `docs/cicd`. Ten numer dokłada filtr
`dotnet test` do trzech bramek i zostawia pozostałe checki tak, jak opisuje numer CI. Oczekiwany
skutek filtra jednostkowego: w logu nie ma startu kontenera `postgres:16-alpine` i nie ma startu
NBomber.

### Jeden powód i nazwa

Test ma jeden powód do padnięcia: przygotowanie, działanie, sprawdzenie. Kilka asercji jednego
skutku zostaje jednym powodem. Nazwa metody to `Czynność_warunek_skutek`, po angielsku, jak
reszta kodu: `Create_blank_title_returns_invalid`. W przykładzie kształtu, który zostaje przy
notatce, dwie asercje sprawdzają jedno odrzucenie: `IsFailure` i kod `article.title.blank`.
Osobny `[Fact]` sprawdzałby outbox. To nie jest nowa funkcja produktu. To kształt już wskazany
przez numer notatki.

Test „utwórz notatkę, opublikuj, sprawdź Kafkę i cache” pada z trzech przyczyn i w logu widać
jedną czerwoną nazwę. Słowo `Test1` odpadło. Zdanie po polsku w nazwie metody odpadło. Asercja w
`[Fact]` na dwa niepowiązane kody błędu odpadła. Koszt to więcej metod. Wspólne przygotowanie
wychodzi do konstruktora klasy testowej albo do metody prywatnej, nie do asercji drugiego
skutku. Ten numer nie kopiuje `Password_hash_is_not_plaintext` ani `Inbox_blocks_second_pod`.
Sprawdza, że takie testy mają gdzie mieszkać i którą bramką jadą.

Przegląd istniejących `[Fact]` usług 17–21 rozdziela metodę, która sprawdza dwa niepowiązane
skutki, i doprowadza nazwę do wzorca. Wzorzec odniesienia zostaje
`Create_blank_title_returns_invalid`. Testy solution, które ten numer dokłada, dotyczą solution
i cech, nie reguły notatki. Stoją w projekcie jednostkowym bez kontenera, na przykład obok
`JJDevHub.Shared.Kernel.Tests` albo w małym projekcie `tests/JJDevHub.SolutionTests`. Każdy z
nich jest osobnym `[Fact]`, bo każda usługa albo każda stała cechy jest osobnym skutkiem.

### Projekty przy bibliotece i przy usłudze

Biblioteka współdzielona dostaje projekt o nazwie biblioteki z sufiksem `.Tests`, bo nie ma
warstw Core i Api. Usługa dostaje pięć projektów: `Core.Tests`, `Application.Tests`,
`Persistence.Tests`, `Api.Tests`, `Performance.Tests`. `Core.Tests` referencjonuje tylko
`<Usługa>.Core` i nie referencjonuje Api. `Performance.Tests` referencjonuje Api tylko na czas
hosta scenariusza i ma cechę na klasie scenariusza. Nie jest kopiowany do obrazu runtime: SDK
testowe zostaje poza `Dockerfile` usługi. `JJDevHub.slnx` zawiera każdy projekt z tabel. Projekt
testowy ma `IsTestProject` ustawione tak, żeby `dotnet test` na solution go widział.

Test reguły agregatu, który referencjonuje host API, ciągnie ASP.NET do przypadku, który ma
przejść w milisekundy na `develop`. Jeden projekt `Tests` na usługę odpadł. Testy w projekcie
produkcyjnym odpadły. Projekt wydajnościowy tylko przy Cv odpadł, bo każdy numer 17–21 ma własny
`GET`, który NBomber już wskazuje, i lista projektów ma być pełna. Puste na starcie
`Performance.Tests` nie zostają puste: każdy ma jeden scenariusz odczytu opisany w numerze
usługi. Ten numer ich nie wymyśla drugi raz, tylko wymaga, żeby stały w solution.

Koszt to pięć projektów na usługę i po jednym projekcie na bibliotekę z tabeli: jądro,
`JJDevHub.Cqrs` bez MediatR, magazyn w pamięci, strumień w Postgresie, projekcja, koperta,
outbox i inbox, Kafka w trybie KRaft, brama oraz `JJDevHub.ServiceDefaults` z politykami `Owner`
i `Student` i bez klucza prywatnego w walidacji JWT. `Core.Tests` nie referencjonuje projektu
Api. `Identity.Api.csproj` i pozostałe cztery pliki Api nie zawierają referencji do
`Performance.Tests` ani pakietu NBomber. Dockerfile usług nie zawiera tego pakietu.

### Numer bez funkcji

Zmiana w tym numerze dotyka solution, cech, filtrów workflow i luk w projektach testowych. Nie
zmienia kontraktu HTTP, strumienia ani schematu bazy usług. Nie dodaje endpointu, agregatu,
tematu Kafki ani tabeli produkcyjnej. Jeśli przy układaniu testu brakuje asercji, dopisuje się
ją do projektu piętra, które już wskazuje numer usługi. `git diff` po wdrożeniu numeru nie
zawiera nowego kontrolera produktu.

Domknięcie piramidy bywa pretekstem, żeby „przy okazji” dodać endpoint zdrowia albo kolejną
tabelę. Nowy agregat testowy w Core którejś usługi odpadł. Osobna usługa Test odpadła. Czytelnik
numeru nie znajduje tu listy pól `Article`. MongoDB nie jest zależnością testową. Licencji
NBomber nie opisuje się jako MIT. Wersji 4 nie przypina się po to, żeby ominąć licencję wersji
późniejszej.

Koszt jest porządkowy. Trzy komendy lokalne, z katalogu repozytorium, są filtrem codziennym,
filtrem z Dockerem i filtrem NBomber. Trzecia wymaga Dockera wtedy, gdy scenariusz podnosi host
z bazą, i wymaga pakietu NBomber. Piramida testów API jest zamknięta. Następny dokument pracy to
`docs/frontend/01-motyw.md`. Test obciążenia HPA na maszynie zostaje w
`docs/cicd/15-skalowanie.md`. NBomber w tym numerze celuje w proces na runnerze, nie w klaster.

## Klasy i ścieżki

Cecha, projekt i filtr są inventarzem tego numeru. Tabele poniżej są wiążące: która cecha jedzie
którą bramką, który projekt biblioteki co ćwiczy, który plik usługi jest którym piętrem i który
`GET` jest scenariuszem NBomber. Zdanie przy tabeli nie dodaje endpointu produktu. Mówi, czego
projekt testowy nie referencjonuje.

Cechy:

| Cecha | Gdzie | Bramka |
| --- | --- | --- |
| brak | `Core.Tests`, `Application.Tests`, testy bibliotek bez bazy | `unit-tests` |
| `Category=Integration` | `Persistence.Tests`, `Api.Tests`, testy bibliotek z kontenerem | `integration-tests` |
| `Category=Performance` | `Performance.Tests` | `performance` |

Wspólna stała, jeden typ w `src/shared/tests/TestTraits.cs` albo w każdej asemblacji tak samo:
nazwa `Category`, wartości `Integration` i `Performance`. Filtr `dotnet test` używa tych
napisów.

Biblioteki współdzielone:

| Projekt testowy | Co ćwiczy | Piętro |
| --- | --- | --- |
| `src/shared/tests/JJDevHub.Shared.Kernel.Tests` | `Result<T>`, `Entity`, `ValueObject`, atrybut `EventName` | jednostkowe |
| `src/shared/tests/JJDevHub.Cqrs.Tests` | mediator i zachowania, bez MediatR | jednostkowe |
| `src/shared/tests/JJDevHub.EventStore.Tests` | magazyn w pamięci | jednostkowe |
| `src/shared/tests/JJDevHub.EventStore.Postgres.Tests` | strumień w Postgresie | integracyjne |
| `src/shared/tests/JJDevHub.Projections.Tests` | checkpoint; kontener tylko w teście z cechą | jednostkowe i integracyjne |
| `src/shared/tests/JJDevHub.EventBus.Tests` | koperta i nazwa z atrybutu | jednostkowe |
| `src/shared/tests/JJDevHub.IntegrationEventLog.Tests` | outbox i inbox w jednej transakcji | integracyjne |
| `src/shared/tests/JJDevHub.EventBus.Kafka.Tests` | producent i konsument, KRaft | integracyjne |
| `src/gateway/tests/JJDevHub.Gateway.Tests` | trasy YARP i skład `GET /versions` | jednostkowe dla konfiguracji, integracyjne dla wiązania portu |
| `JJDevHub.ServiceDefaults.Tests` | polityki `Owner` i `Student`, brak klucza prywatnego w walidacji JWT | jednostkowe |

Usługi. W każdej piątce nazwa zaczyna się od usługi: `Identity.Core.Tests`, `News.Core.Tests`,
`Learning.Core.Tests`, `Cv.Core.Tests`, `Contact.Core.Tests` i tak dalej dla `Application`,
`Persistence`, `Api`, `Performance`.

| Usługa | Katalog |
| --- | --- |
| Identity | `src/services/Identity/tests/` |
| News | `src/services/News/tests/` |
| Learning | `src/services/Learning/tests/` |
| Cv | `src/services/Cv/tests/` |
| Contact | `src/services/Contact/tests/` |

Pliki projektów w katalogu usługi:

| Plik | Piętro |
| --- | --- |
| `<Usługa>.Core.Tests.csproj` | jednostkowe, referencja tylko do `<Usługa>.Core` |
| `<Usługa>.Application.Tests.csproj` | jednostkowe, referencja do Application |
| `<Usługa>.Persistence.Tests.csproj` | integracyjne, Testcontainers |
| `<Usługa>.Api.Tests.csproj` | integracyjne, host HTTP |
| `<Usługa>.Performance.Tests.csproj` | NBomber, jeden scenariusz odczytu z numeru usługi |

`Core.Tests` nie referencjonuje projektu Api. `Performance.Tests` nie jest kopiowany do obrazu
runtime: SDK testowe zostaje poza `Dockerfile` usługi.

Scenariusze wydajnościowe, które już wskazują numery usług, i których ten numer nie zastępuje:

| Projekt | Żądanie |
| --- | --- |
| `Identity.Performance.Tests` | `GET /.well-known/jwks.json` |
| `News.Performance.Tests` | `GET /api/news?culture=pl` |
| `Learning.Performance.Tests` | `GET /api/learning/catalog?culture=pl` |
| `Cv.Performance.Tests` | `GET /api/cv/page?culture=pl` |
| `Contact.Performance.Tests` | `GET /api/contact/student-inquiries` z tokenem ownera |

Komendy lokalne, z katalogu repozytorium:

```bash
dotnet test --filter "Category!=Integration&Category!=Performance"
dotnet test --filter "Category=Integration"
dotnet test --filter "Category=Performance"
```

Pierwsza jest filtrem codziennym. Druga wymaga Dockera. Trzecia wymaga Dockera wtedy, gdy
scenariusz podnosi host z bazą, i wymaga pakietu NBomber.

Obraz Postgresa w teście integracyjnym: `postgres:16-alpine`. Kafka: `Testcontainers.Kafka`,
tryb KRaft, bez Zookeepera.

Przykład kształtu, nie nowa funkcja. Pusty tytuł notatki zostaje w `News.Core.Tests` albo
`News.Application.Tests`, bez cechy:

```csharp
[Fact]
public void Create_blank_title_returns_invalid()
{
    var result = Article.Create(slug, LocalizedText.Empty, body, lessonSlug: null, author);

    Assert.True(result.IsFailure);
    Assert.Equal("article.title.blank", result.Error.Code);
}
```

Dwie asercje sprawdzają jeden skutek: odrzucenie pustego tytułu tym kodem. Osobny `[Fact]`
sprawdzałby outbox. Przypadek integracyjny na tej samej regule dostaje
`[Trait("Category", "Integration")]` i nie powtarza asercji Core, tylko skutek transakcji.

Workflow bramek, pliki w `.github/workflows` opisane przez `docs/cicd/02-bramki.md`, dostają
filtr z tabeli jobów. Job `unit-tests` nie instaluje warunku „odpal też Integration”. Job
`performance` nie oznacza scenariusza wydajnościowego jako pomijalnego.

`JJDevHub.slnx` zawiera każdy projekt z tabel. Projekt testowy ma `IsTestProject` ustawione tak,
żeby `dotnet test` na solution go widział.

## Plan

### 1. Stała cechy

Dodaj jedno miejsce z nazwą cechy `Category` i wartościami `Integration` oraz `Performance`.
Użyj go w atrybucie `[Trait]`. Nie wprowadzaj drugiej nazwy cechy na to samo piętro.

### 2. Projekty bibliotek

Utwórz projekty z tabeli bibliotek, jeśli numer biblioteki jeszcze ich nie ma. Test z kontenerem
oznacz `Category=Integration`. Test `Result<T>` i atrybutu `EventName` zostaw bez cechy.

### 3. Piątki usług

Dla Identity, News, Learning, Cv i Contact sprawdź pięć plików `csproj` w `tests/`. `Core.Tests`
referencjonuje Core. `Performance.Tests` referencjonuje Api tylko na czas hosta scenariusza i ma
cechę `Category=Performance` na klasie scenariusza. Wpisz projekty do `JJDevHub.slnx`.

### 4. Filtr bramek

W jobie `unit-tests` ustaw
`dotnet test --filter "Category!=Integration&Category!=Performance"`. W jobie
`integration-tests` ustaw filtr `Category=Integration`. W jobie `performance` ustaw filtr
`Category=Performance`. Trzy joby startują na `develop`, `release` i `main`. Zostaw
pozostałe checki bramki tak, jak opisuje numer CI.

### 5. Nazwy

Przejrzyj istniejące `[Fact]` usług 17–21. Rozdziel metodę, która sprawdza dwa niepowiązane
skutki. Nazwę doprowadź do wzorca `Czynność_warunek_skutek`. Wzorzec odniesienia:
`Create_blank_title_returns_invalid`.

### 6. Obrazy testowe

W teście Postgresa ustaw obraz `postgres:16-alpine`. W teście Kafki użyj `Testcontainers.Kafka`
w trybie KRaft. Nie dodawaj kontenera MongoDB.

### 7. Pakiety

Wpisz xUnit i Testcontainers do `Directory.Packages.props`. Wpisz NBomber jako zależność
wyłącznie projektów `Performance.Tests`. W tabeli pakietów `docs/api/README.md` podaj przy
NBomber licencję pakietu, nie MIT. Pakietu wydajnościowego nie dodawaj do `Dockerfile` usługi.

### 8. Brak nowej funkcji

Nie dodawaj endpointu, agregatu, tematu Kafki ani tabeli produkcyjnej. Jeśli przy układaniu
testu brakuje asercji, dopisz ją do projektu piętra, które już wskazuje numer usługi.

### Co jest do czego

| Element | Po co istnieje | Kto woła |
| --- | --- | --- |
| `[Fact]` | jeden powód, jedna nazwa | `dotnet test` |
| `[Trait("Category", "Integration")]` | wyłącza kontener z `unit-tests` | filtr `integration-tests` |
| `[Trait("Category", "Performance")]` | trzyma NBomber poza `unit-tests` | filtr `performance` |
| `*.Core.Tests` | reguła agregatu bez hosta | job `unit-tests` |
| `*.Application.Tests` | handler z portem podstawionym | job `unit-tests` |
| `*.Persistence.Tests` | transakcja w Postgresie | job `integration-tests` |
| `*.Api.Tests` | status HTTP i `ProblemDetails` | job `integration-tests` |
| `*.Performance.Tests` | scenariusz odczytu | job `performance` |
| Filtr lokalny bez cech integracji i wydajności | codzienny przebieg bez Dockera | `dotnet test` w katalogu repozytorium |
| `Testcontainers.Kafka` | szyna w trybie KRaft | test outboxa i konsumenta |

`[Fact]` jest jednym powodem i jedną nazwą dla `dotnet test`.
`[Trait("Category", "Integration")]` wyłącza kontener z `unit-tests` i wpuszcza go do
`integration-tests`. `[Trait("Category", "Performance")]` trzyma NBomber w `performance`.
`*.Core.Tests` ćwiczy regułę
agregatu bez hosta. `*.Application.Tests` ćwiczy handler z portem podstawionym.
`*.Persistence.Tests` ćwiczy transakcję w Postgresie. `*.Api.Tests` ćwiczy status HTTP i
`ProblemDetails`. `*.Performance.Tests` ćwiczy scenariusz odczytu.

Filtr lokalny bez cech integracji i wydajności jest codziennym przebiegiem bez Dockera.
`Testcontainers.Kafka` jest szyną w trybie KRaft dla testu outboxa i konsumenta. Stała cechy ma
jedną nazwę `Category`. Wartość `Integration` i wartość `Performance` nie dostają drugiej
etykiety. Projekt wydajnościowy nie wchodzi do referencji Api i nie wchodzi do `Dockerfile`.

## Testy

Ten numer testuje sam filtr i obecność projektów. Asercja dotyczy solution i cech. Nowy agregat
produktu tu nie powstaje.

Przypadki, które stoją przy solution, w projekcie jednostkowym bez kontenera, na przykład obok
`JJDevHub.Shared.Kernel.Tests` albo w małym projekcie `tests/JJDevHub.SolutionTests`:

- `Performance_project_is_not_referenced_by_api` — `Identity.Api.csproj`, `News.Api.csproj`,
  `Learning.Api.csproj`, `Cv.Api.csproj` i `Contact.Api.csproj` nie zawierają referencji do
  projektu `Performance.Tests` ani pakietu NBomber. Jeden test na usługę, jeden powód.
- `Core_tests_do_not_reference_api` — `Identity.Core.Tests.csproj` referencjonuje
  `Identity.Core` i nie referencjonuje `Identity.Api`. Ten sam kształt dla News, Learning, Cv i
  Contact, każdy osobnym `[Fact]`, bo każda usługa jest osobnym skutkiem.
- `Integration_trait_value_is_integration` — stała cechy ma wartość `Integration`.
- `Performance_trait_value_is_performance` — stała cechy ma wartość `Performance`.

Komenda, która ma być zielona na maszynie bez Dockera po tym numerze:

```bash
dotnet test --filter "Category!=Integration&Category!=Performance"
```

Komenda integracyjna, zielona tam, gdzie jest Docker:

```bash
dotnet test --filter "Category=Integration"
```

Komenda wydajnościowa:

```bash
dotnet test --filter "Category=Performance"
```

Oczekiwany skutek filtra jednostkowego: w logu nie ma startu kontenera `postgres:16-alpine` i
nie ma startu NBomber. Oczekiwany skutek filtra wydajnościowego: w logu jest scenariusz JWKS,
listy notatek, katalogu, strony CV i listy zapytań studenta, a nie ma
`POST /api/contact/recruiter-inquiries`.

Test kontenera z numerów 17–21 zostaje w tamtych projektach. Ten numer nie kopiuje
`Password_hash_is_not_plaintext` ani `Inbox_blocks_second_pod`. Sprawdza, że takie testy mają
gdzie mieszkać i którą bramką jadą.

Układ przypadku zostaje: przygotowanie, działanie, sprawdzenie, jeden powód. W
`Integration_trait_value_is_integration` przygotowaniem jest stała cechy, działaniem odczyt
wartości, sprawdzeniem napis `Integration`. `Performance_trait_value_is_performance` stoi
osobno. W `Core_tests_do_not_reference_api` jednym faktem jest `Identity.Core.Tests.csproj`:
referencja do `Identity.Core` i brak referencji do `Identity.Api`. News, Learning, Cv i Contact
dostają własny `[Fact]`, bo każda usługa jest osobnym skutkiem.
`Performance_project_is_not_referenced_by_api` też jest jeden test na usługę.

## Zasady

- Jeden `[Fact]` ma jeden powód do padnięcia. Dwie asercje zostają tylko wtedy, gdy sprawdzają
  jeden skutek, tak jak odrzucenie pustego tytułu jednym kodem.
- Nazwa metody to `Czynność_warunek_skutek`. Wzorzec: `Create_blank_title_returns_invalid`.
  Słowo `Test1` i zdanie po polsku w nazwie metody odpadły.
- Przypadek bez cechy jedzie w `unit-tests`. `Category=Integration` jedzie w
  `integration-tests`. `Category=Performance` jedzie w `performance`. Trzy joby są warunkiem
  wejścia na `develop` i powtarzają się na `release` oraz na `main`. Czerwony NBomber
  blokuje pull request do `develop`.
- Postgres w teście to `postgres:16-alpine`. Kafka w teście to KRaft przez Testcontainers.
  Zookeepera w tym przebiegu nie ma.
- Pięć usług ma `Core.Tests`, `Application.Tests`, `Persistence.Tests`, `Api.Tests` i
  `Performance.Tests`. Piątka jest w `JJDevHub.slnx` i `dotnet test` na solution ją widzi.
- Biblioteka współdzielona ma projekt `NazwaBiblioteki.Tests`, nie piątkę warstw. Nie ma tu
  warstw Core i Api do rozcięcia.
- `Core.Tests` nie referencjonuje Api. Obraz usługi nie zawiera NBomber. SDK testowe zostaje
  poza `Dockerfile`.
- Test integracyjny nie jest zastępowany testem w pamięci, gdy skutek dotyczy transakcji
  Postgresa albo offsetu Kafki. Sqlite nie zastępuje JSONB, outboxa ani `UPSERT`.
- Test wydajnościowy nie zapisuje publicznego formularza rekrutera. W logu filtra
  `Category=Performance` nie ma `POST /api/contact/recruiter-inquiries`.
- Ten numer nie dodaje funkcji produktu. Brak asercji dopisuje się do piętra, które już wskazuje
  numer usługi, a nie jako nowy endpoint.
- MongoDB nie jest zależnością testową. Kontener testowy MongoDB odpadł razem z MongoDB w
  produkcie.
- Licencji NBomber nie opisuje się jako MIT. Wersji 4 nie przypina się po to, żeby ominąć
  licencję wersji późniejszej. Wiersz w `docs/api/README.md` podaje licencję pakietu.
- xUnit zostaje runnerem. Asercja oczekiwanego błędu sprawdza kod `Result<T>` albo status HTTP,
  jeden skutek na metodę. FluentAssertions do solution nie wchodzi.

## Poza zakresem

- Przypadki reguł konta, notatki, lekcji, strony i zapytania są w [17](17-identity.md),
  [18](18-news.md), [19](19-learning.md), [20](20-cv.md) i [21](21-kontakt.md). Ten numer
  wymaga, żeby miały projekt i cechę. Nie kopiuje ich asercji do projektu solution.
- Checki nazwy gałęzi, CodeQL, SonarQube, skan obrazu, SBOM i tag komponentu zostają w
  `docs/cicd`. Ten numer dokłada filtr `dotnet test` do trzech bramek z
  `docs/cicd/02-bramki.md`. Pozostałych checków nie kasuje.
- Test komponentu React i telefonu jest przy `docs/frontend`. Najbliższy numer to
  [motyw](../frontend/01-motyw.md). Piramida usług jest już zamknięta i motyw jej nie otwiera.
- Test obciążenia HPA na maszynie jest w `docs/cicd/15-skalowanie.md`. NBomber w tym numerze
  celuje w proces na runnerze, nie w klaster.
- Nowy endpoint, nowy agregat i nowa baza nie są treścią tego numeru. `git diff` po wdrożeniu
  nie zawiera nowego kontrolera produktu.

## Źródła

- [xUnit](https://xunit.net/). Wiążące są `[Fact]` i `Assert`. W tym pliku jeden przebieg
  `dotnet test` i jeden powód padnięcia stoją na tym runnerze. Nie bierzemy stąd NUnit, MSTest
  ani FluentAssertions. Nazwa metody zostaje scenariuszem, bez osobnego DSL.
- [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). Wiążąca jest licencja
  pakietu xUnit zapisana w `Directory.Packages.props`. W tym pliku ta licencja jest przyjęta.
  Nie bierzemy stąd przypięcia NBomber 4 tylko po to, żeby zostać przy Apache 2.0. Starej wersji
  nie przypina się, żeby ominąć zmianę licencji.
- [Testcontainers for .NET](https://dotnet.testcontainers.org/). Wiążący jest kontener w teście
  i licencja MIT. W tym pliku Postgres, a gdy test dotyczy szyny, także Kafka, wstają na czas
  przypadku z cechą `Category=Integration`. Nie bierzemy stąd wspólnej bazy na runnerze
  `ubuntu-latest` ani ręcznego `docker run` w skrypcie człowieka.
- [Testcontainers Kafka](https://github.com/testcontainers/testcontainers-dotnet). Wiążący jest
  moduł Kafki użyty w trybie KRaft. W tym pliku `Testcontainers.Kafka` obsługuje test outboxa i
  konsumenta, bez Zookeepera. Nie bierzemy stąd osobnego solution na piętro integracyjne.
  Projekt zostaje przy komponencie.
- [PostgreSQL, obraz 16](https://hub.docker.com/_/postgres). Wiążące jest to, skąd bierze się
  `postgres:16-alpine`. W tym pliku ten obraz jest silnikiem testu integracyjnego, tym samym co
  AppHost wobec JSONB, transakcji outboxa i `UPSERT`. Nie bierzemy stąd Sqlite w pamięci jako
  zamiennika.
- [NBomber, licencja](https://nbomber.com/docs/getting-started/license/). Wiążący jest koszt
  pakietu od linii, która nie jest MIT ani Apache 2.0 dla organizacji. W tym pliku pakiet jest
  zależnością wyłącznie `Performance.Tests` i nie wchodzi do obrazu usługi. Nie bierzemy stąd
  opisu licencji jako MIT w `docs/api/README.md` ani wołania publicznego formularza rekrutera w
  scenariuszu.
- [Kafka, KRaft](https://kafka.apache.org/documentation/#kraft). Wiążący jest tryb brokera w
  teście, bez Zookeepera. W tym pliku test szyny z numerów 17–21 używa tego trybu. Nie bierzemy
  stąd dokładania Zookeepera do joba `release`.
- [dotnet test, filtr](https://learn.microsoft.com/dotnet/core/tools/dotnet-test). Wiążąca jest
  składnia `--filter` i cechy. W tym pliku `unit-tests` używa
  `Category!=Integration&Category!=Performance`, `integration-tests` używa
  `Category=Integration`, a `performance` używa `Category=Performance`. Trzy joby jadą na
  `develop`, `release` i `main`. Nie bierzemy stąd jednego `dotnet test` bez filtra na
  gałęzi roboczej.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic usług i warstw bez
  MediatR. W tym pliku `JJDevHub.Cqrs.Tests` ćwiczy własny mediator i zachowania, bez MediatR, a
  `Core.Tests` nie referencjonuje hosta Api. Nie bierzemy stąd MediatR w projekcie testowym ani
  w `Directory.Packages.props`.

## Gotowe gdy

- `dotnet test --filter "Category!=Integration&Category!=Performance"` przechodzi bez startu
  kontenera i bez NBomber.
- Job `unit-tests` używa tego filtra na `develop`, `release` i `main`. Job
  `integration-tests` używa `Category=Integration` na tych trzech gałęziach. Job
  `performance` używa `Category=Performance` na tych trzech gałęziach.
- W solution są projekty testowe bibliotek z tabeli oraz piątka `Core.Tests`,
  `Application.Tests`, `Persistence.Tests`, `Api.Tests`, `Performance.Tests` dla Identity, News,
  Learning, Cv i Contact.
- `Identity.Core.Tests` nie referencjonuje `Identity.Api`. Ta sama reguła jest prawdziwa dla
  pozostałych czterech usług.
- Dockerfile usług nie zawiera pakietu NBomber.
- W `docs/api/README.md` wiersz NBomber nie nazywa licencji MIT.
- Nie powstał endpoint ani agregat z tego numeru. `git diff` po wdrożeniu numeru nie zawiera
  nowego kontrolera produktu.
- Piramida testów API jest zamknięta. Następny dokument pracy to `docs/frontend/01-motyw.md`.
