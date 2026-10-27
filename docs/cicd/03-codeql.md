# 03. CodeQL

Poprzedni numer, [Bramki](02-bramki.md), rozdziela kompilację i trzy piętra testów.
Następny, [Zależności i obrazy](04-zaleznosci-i-obrazy.md), czyta lockfile i warstwy obrazu.
Ten numer dodaje skan kodu CodeQL jako job `codeql`. Job jest wymagany na pull request do
`develop`, do `release` i do `main`. Szuka podatności w kodzie, który sami piszemy.
Podatności bibliotek i obrazów zostawia numerowi `04`. Styl i część reguł jakości zostawia
numerowi [05-sonarqube.md](05-sonarqube.md).

Scenariusz, który bez tej ramy się rozpada, ma zielony tytuł, zielony test i alert schowany
w zakładce. Pull request News niesie `feat(news): publish article revision`. `pr-title` jest
zielony. Test jednostkowy woła szczęśliwą ścieżkę publikacji i też jest zielony. W kodzie
dane z żądania dochodzą do złożenia ścieżki albo do wywołania kryptografii, którego nie
powinno ich widzieć. CodeQL w zestawie `security-extended` umie pokazać tę drogę. Domyślna
akcja analizy potrafi przy tym skończyć się sukcesem i zostawić alert w zakładce Security.
Na prywatnym repozytorium ta zakładka wymaga GitHub Code Security. Przycisk scalenia zostaje
zielony. Squash wpuszcza na `develop` publikację, której test nie umiał złapać, bo test nie
śledzi źródła i ujścia. Promocja i tag `news-v…` powtarzają tę samą dziurę.

Werdykt tego numeru jest w pliku SARIF z przebiegu, nie w zakładce. `codeql-gate.sh` czyta
`security-severity`. Wynik od `7.0` włącznie kończy job kodem `1`. Fixture `high.sarif` ma
jeden taki wynik i pada. Fixture `low.sarif` ma wynik `3.0` i kończy się kodem `0`. Alert
zostaje w logu i nie blokuje. Wynik o tagu `security` bez pola wagi jest traktowany jak
`7.0` i też blokuje. Nieznana waga alertu bezpieczeństwa nie przechodzi cicho. Wynik spoza
tagu `security` skrypt ignoruje.

Plik do dodania to `.github/workflows/codeql.yml`. W drzewie przed tym numerem go nie ma.
Plan niżej mówi, jak go utworzyć. W repozytorium może nie być jeszcze `*.cs`, `*.js`, `*.ts`
ani `*.tsx`. Wtedy pierwszy pull request na `develop` pokazuje zielony check `codeql` i
linię `no material for codeql`. Pierwszy plik C# albo TypeScript w którymś z kolejnych
numerów nie wymaga nowego workflow. Ten sam job przechodzi z pustego sukcesu w prawdziwy
skan.

## Po co

Bramka z [02-bramki.md](02-bramki.md) na `develop` ma obejmować skan kodu, zanim squash
zapisze zmianę na długiej gałęzi. Sam test jednostkowy sprawdza zachowanie, które ktoś
napisał. Nie śledzi, czy dane z żądania dochodzą do wywołania, którego nie powinno ich
widzieć. Dla
publikacji News znaczy to różnicę między zielonym `[Fact]` a drogą, którą widać dopiero w
zapytaniu o przepływ. Tytuł `feat(news): publish article revision` mówi numerowi
[07-wersje.md](07-wersje.md), który komponent podbić. Nie mówi, czy żądanie składa ścieżkę.
CodeQL jest bramką tej drugiej informacji.

CodeQL buduje bazę zapytań po kodzie i uruchamia zestaw `security-extended`. Wynik wiąże
scalenie, gdy alert ma `security-severity` co najmniej `7.0`. Niższy alert zostaje w logu
joba i nie blokuje. Próg `7.0` jest dolną krawędzią wysokiej wagi w tej skali. Krytyczna
waga leży wyżej i też blokuje, bo jest od `7.0` w górę. Innego progu plik workflow nie czyta
ze zmiennej. Obniżenie progu wymaga zmiany YAML, którą zobaczy job `action-pins` z numeru
`06`. Pull request nie ścisza bramki na czas jednej rewizji artykułu.

Brak plików, które CodeQL umie analizować, kończy job sukcesem. Job przy tym istnieje, więc
ruleset nie czeka w nieskończoność. To jest ten sam zwyczaj co `no material for build` w
numerze `02`. Linia brzmi `no material for codeql`. Bez niej zielony check na pull requeście
samej dokumentacji wygląda jak skan, którego nie było. Z nią widać, że języków nie znaleziono i
`init` nie został wywołany. Pierwszy `*.cs` w News włącza analizę od następnego pull
requestu na `develop`, na `release` i na `main`, bez nowego pliku workflow.

Skan nie zastępuje bramki jakości z SonarQube i nie czyta lockfile w poszukiwaniu CVE
biblioteki. Te trzy rzeczy mogą naraz być czerwone z trzech różnych powodów. Tak ma być.
Zielony test i zielony CodeQL przy wysokim CVE w paczce to luka numeru `04`, nie tego.
Zielony CodeQL przy czerwonym teście jednostkowym to luka numeru `02`. Ten numer zamyka
trzecią: zielony test, zielony tytuł i alert, który widać tylko w zakładce.

Job stoi na `develop` i powtarza się na `release` oraz na `main`, żeby każdy ruleset dostał
świeży status, a nie wspomnienie z poprzedniej gałęzi. Szkic
`feat(news): publish article revision` na `develop` czeka na bazę zapytań.
`feature/lesson_markdown` nadal pada kodem `1` w numerze `01` i do CodeQL nie dochodzi.
Poprawna nazwa `feature/lesson-markdown` przy celu `develop` startuje ten workflow. Ten sam
job startuje na promocji `develop` → `release` i `release` → `main`.

## Dlaczego ta technologia

### CodeQL jako skaner ścieżek w kodzie

CodeQL opisuje źródło i ujście. Zapytanie umie pokazać drogę między nimi, a nie tylko
dopasowanie wzorca w jednej linii. Dla C# i dla TypeScript, które dojdą z API i z klientów,
ta różnica dotyczy zapytań HTTP, składania ścieżek i użyć kryptografii. Publikacja artykułu,
która skleja ścieżkę z części żądania, może przejść test „zapisany artykuł wraca w
odpowiedzi” i nadal mieć drogę, którą zapytanie oznaczy. Test sprawdza kształt, który ktoś
świadomie wpisał. Zapytanie sprawdza, czy dane z jednego miejsca dochodzą do drugiego.

Poleganie wyłącznie na analizatorach kompilatora odpadło. Zostają one przy `dotnet build` i
przy SonarQube, bo łapią styl, część błędów i proste wzorce. Nie są zestawem
`security-extended`. Zielony `build` z numeru `02` znaczy, że konfiguracja `Release` się
skompilowała. Nie znaczy, że baza zapytań została przejrzana. Drugi zielony check obok
kompilacji jest tu celowy. Czerwony CodeQL przy zielonym buildzie ma własną nazwę na liście,
`codeql`, żeby osoba czytająca pull request widziała, który check padł.

Semgrep jako jedyny skan tego numeru odpadł. Jest szybki w regułach lokalnych. Ten numer
chce zapytań o przepływ danych utrzymywanych razem z ekstraktorami C# i JavaScript. Drugi
silnik reguł w tym samym checku dublowałby werdykt. Dwa czerwone powody na jednym jobie nie
mówią, który ruleset czyta. Zostaje jeden silnik i jedna nazwa checka. Reguły lokalne, jeśli
kiedyś dojdą, nie zastępują zestawu `security-extended` i nie obniżają progu `7.0`.

Koszt zostaje w czasie przebiegu. CodeQL jest wyraźnie dłuższy niż `dotnet build`.
Czekanie z tym skanem do `release` odpadło. Droga z żądania do złożenia ścieżki siedziałaby
wtedy na `develop` przez kilka squashy, a tag widziałby ją dopiero przy promocji.
`timeout-minutes` to `30`. Powtórzenie na `release` i na `main` jest świeżym statusem dla
rulesetu, nie kopią logu z `develop`. W międzyczasie na `develop` mógł wejść inny squash.
Stary zielony `codeql` nie opisuje głowy promocji. To jest ten sam rygor świeżości co przy
teście jednostkowym w numerze `02`.

Ekstraktor startuje tylko dla języka, który w drzewie ma pliki. Sztywna lista
`csharp,javascript-typescript` od pierwszego commita tego numeru odpadła. Sam workflow
padałby na braku kodu i ruleset `develop` stałby w miejscu, zanim powstanie usługa. Pusty
sukces z linią `no material for codeql` trzyma check przy życiu. Pierwszy plik `*.cs` włącza
analizę od razu, także gdy to jeszcze nie jest pełna usługa. To jest ten sam cel co w
numerze `02`: pierwszy pull request, który już ma materiał, jest bramkowany bez osobnego
„włączenia skanu później”.

### Zestaw `security-extended` i próg `7.0`

Wejście `queries` akcji `init` to `security-extended`. Zestaw `security-and-quality` wciąga
zapytania jakości, które pokrywają się z SonarQube i z `dotnet format`. Ten numer nie
prowadzi drugiej bramki stylu. Czerwony job od odstępstwa formatowania ma zostać przy
`format` albo przy SonarQube, nie przy `codeql`. Inaczej promocja News padałaby dwa razy za
to samo, a osoba nie wiedziałaby, czy poprawiać przepływ danych, czy odstęp.

Alert z `security-severity` poniżej `7.0` nie kończy joba kodem `1`. Alert od `7.0` w górę
kończy. Fixture `low.sarif` niesie `3.0` i ma dać kod `0`. Fixture `high.sarif` niesie `7.0`
i ma dać kod `1`. Próg jest włączający: `7.0` blokuje, nie przechodzi „bo to dopiero próg”.
Skala, której ten próg używa, stawia wysoką wagę od `7.0`, a średnią poniżej. Innego progu,
na przykład tylko krytycznego, plik nie czyta. Wysoka wada w przepływie danych ma zatrzymać
`release`. Zostawienie jej do „kiedyś na `main` ” wpuściłoby ją do tagu, jeśli ktoś
podniósłby próg tylko na ostatniej gałęzi. Próg jest jeden na obu gałęziach, na których job
w ogóle stoi.

„Czerwony job od pierwszego drobnego alertu” odpadł. Przy `security-extended` drobne
trafienia potrafią zalać wczesny kod i nauczyłyby omijać bramkę, na przykład przez
wyłączenie joba do czasu „porządnego” serwisu. Próg tylko na krytyczne też odpadł. Wysoka
waga zostaje po złej stronie przycisku scalenia. Zmienna workflow z progiem odpadła z
trzeciego powodu: pull request mógłby obniżyć `7.0` bez zmiany pliku, który recenzuje się
tak samo jak reszta YAML. Próg jest stałą w `codeql-gate.sh`.

Koszt zostaje przy fałszywym trafieniu o wadze `7.0`. Blokuje promocję, dopóki zapytanie nie
zostanie wyciszone w pliku w repozytorium, z komentarzem dlaczego. Wyciszenie w samym
interfejsie GitHuba nie wystarcza, bo job czyta SARIF z przebiegu, a nie listę kliknięć.
Kliknięcie „odepnij” w zakładce, której na prywatnym repozytorium może nie być, nie zmienia
kodu wyjścia `codeql-gate.sh`. Plik wyciszenia jedzie w diffie, więc widać go przy tytule
`feat(news): publish article revision` tak samo jak zmianę kodu publikacji.

Brak pola `security-severity` przy wyniku o tagu `security` jest osobną furtką, którą próg
zamyka. Traktowanie braku jak zera wpuściłoby alert, którego paczka zapytań nie opisała
wagą, a tag mówi, że to alert bezpieczeństwa. Skrypt podstawia wtedy `7.0` i blokuje. Wynik
spoza tagu `security` nie dostaje tego podstawienia i nie blokuje, nawet gdy ma wysoką
liczbę w innym polu. Bramka jest o bezpieczeństwie. Jakość zostaje przy SonarQube i przy
`dotnet format`.

### Werdykt joba, nie tylko zakładka Security

Akcja analizy domyślnie może skończyć się sukcesem mimo alertów i zostawić werdykt w
zakładce Security. Ta zakładka na prywatnym repozytorium wymaga GitHub Code Security. Bramka
tego produktu nie zależy od wykupionej zakładki. Gdyby zależała, zielony job przy
`high.sarif` scaliłby promocję na koncie, które zakładki nie ma, i zablokowałby ją na
koncie, które zakładkę ma. Ten sam YAML dawałby dwa przyciski scalenia. `codeql-gate.sh`
daje jeden kod wyjścia na obu kontach, bo czyta plik z przebiegu.

Job po analizie czyta SARIF. Gdy którykolwiek wynik ma `security-severity` większe albo
równe `7.0`, krok kończy się kodem `1`. To obejmuje wynik z wagą dokładnie `7.0` i wynik
tagu `security` bez pola wagi. Upload SARIF, jeśli konto go przyjmuje, jest dodatkowym
widokiem. Gdy upload zwróci błąd uprawnień albo braku produktu, krok uploadu jest pomijany
wewnątrz joba, a werdykt z `jq` zostaje. Krok uploadu ma `continue-on-error: true`. Błąd
uploadu nie zmienia kodu z kroku bramki. Job jako całość nie jest skipped.

Trzymanie blokady wyłącznie w „code scanning merge protection” wyklikanym w ustawieniach
odpadło. To nie ląduje w `.github/rulesets` jako nazwa `codeql` i łatwo rozjeżdża się z
resztą bramek. Numer `02` trzyma nazwy checków w JSON. Ten numer dopisuje `codeql` do
`develop.json`, `release.json` i `main.json` w tym samym scaleniu co workflow. Po syncu
pull request do `develop` czeka na ten check. Pull request do `release` i do `main` też
czeka, bo ten sam workflow raportuje tam świeży status.

Koszt zostaje w kilkunastu liniach skryptu, które zamieniają SARIF na kod wyjścia. Suchy
przebieg na `low.sarif` i `high.sarif` sprawdza próg bez uruchamiania całego skanu i bez
sieci. Fixture nie jest wynikiem prawdziwego kodu produktu. Oba pliki są małe i nie
zawierają fragmentu kodu usługi. Dzięki temu test bramki nie wciąga do gita ścieżki z
prawdziwego żądania News. Pełny skan odpala się na runnerze, gdy w drzewie już jest `*.cs`
albo plik JavaScript albo TypeScript.

Wynikowy plik SARIF zostaje artefaktem przebiegu o nazwie `codeql-sarif`, retencja 14 dni.
Artefakt nie jest sekretem. Nie wrzuca się go do obrazu. Obrazem zajmie się numer `04`, i to
innym plikiem. Kto włoży SARIF do warstwy kontenera, miesza log skanu z tym, co później
idzie na maszynę. Retencja 14 dni wystarcza, żeby wrócić do przebiegu promocji, która padła
na `7.0`, bez trzymania historii skanów w rejestrze.

### Języki, które naprawdę są w drzewie

Job wykrywa języki przed `init`. `codeql-languages.sh` przechodzi drzewo `git ls-files`.
Wypisuje `csharp`, gdy jest plik `*.cs`. Wypisuje `javascript-typescript`, gdy jest `*.js`,
`*.ts` albo `*.tsx`. Innych języków nie wpisuje. YAML workflow i Markdown nie są językiem
tego skanu. Ignoruje `bin`, `obj`, `node_modules` i `dist`. Gdy nie wypisze nic, kończy się
kodem `0` i linią `no material for codeql`. Kod `2` jest tylko dla błędu użycia.

Gdy lista jest pusta, kolejne kroki skanu się nie wykonują, a job kończy się sukcesem.
`init` nie startuje. Ekstraktor uruchomiony „na zapas” dla języka bez plików potrafi
zakończyć się błędem i zablokować pull request dokumentacji. To jest ten sam błąd co sztywna
lista języków w YAML: ruleset `develop` stoi, choć nie ma czego analizować. Gdy lista ma
jedną pozycję, `init` dostaje tę jedną. Web z samym TypeScript nie uruchamia ekstraktora C#.
Usługa z samym C# nie uruchamia ekstraktora JavaScript.

Konfiguracja w `.github/codeql/codeql-config.yml` wyklucza `docs/**`, `versions/**`,
`**/*.Generated.cs` oraz katalogi `bin` i `obj`. `versions/**` to pliki numeru `07`, nie
kod, w którym zapytanie szuka źródła i ujścia. Generator, gdy kiedyś zapisze `Generated.cs`,
nie ma być drugim źródłem prawdy obok pliku, z którego powstał. `docs/**` jest prozą. Nie
wyklucza się `src/**`. Nie wyklucza się testów. Zapytanie o test potrafi pokazać, że test
wyłącza walidację. Jeśli któreś zapytanie hałasuje tylko w projekcie testowym, wykluczenie
dopisuje się ścieżką projektu testowego i zdaniem powodu, nie całym `src`.

Build C#, gdy język wszedł na listę, idzie po każdym śledzonym `*.csproj`:
`dotnet build <projekt> --configuration Release`. Goły `dotnet build` w korzeniu odpada, bo
w korzeniu nie ma solution, a projekty leżą w podkatalogach. `autobuild` zostaje wyłączony
dla C#, żeby nie było drugiej, innej kompilacji. Dwie kompilacje potrafią dać dwa różne
zestawy ostrzeżeń i dwa różne werdykty przy jednym checku `codeql`. SDK bierze się z
`global.json`. Wersja to `11.0.100-rc.3.26522.148`, z `allowPrerelease` i
`rollForward: latestFeature`, bo projekty celują w `net11.0`, a obraz runnera tego SDK nie
niesie. Job instaluje je krokiem `setup-dotnet` z `global-json-file: global.json`, zanim
zacznie budować. Gdy projekt C# jest, a `global.json` nie ma, kompilacja pada z tego samego
powodu co `build`. Dla `javascript-typescript` zostaje wbudowane wykrycie CodeQL, bez
osobnego bundla. Skan ma widzieć źródło, nie paczkę z `dist/`.

Checkout bierze `fetch-depth: 2`. Tyle wystarcza do diffu pull requestu. Pełna historia nie
jest potrzebna. Job nazwy z numeru `01` bierze `fetch-depth: 0`, bo liczy przodków. Ten job
przodków nie liczy. `persist-credentials: false`. `runs-on` to `ubuntu-latest`.
`permissions` na pliku są puste. Job ma `contents: read`. `security-events: write` jest
tylko na kroku uploadu, jeśli ten krok jest w przebiegu. Gdy upload jest wyłączony zmienną
`CODEQL_UPLOAD` ustawioną na `false`, zostaje `contents: read`. Domyślnie upload jest
próbowany. Akcje `init`, analiza i checkout są przypięte do pełnego SHA z komentarzem
wersji. Job `action-pins` ma to zobaczyć.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/codeql.yml` | job `codeql` |
| `.github/codeql/codeql-config.yml` | wykluczenia ścieżek, próg zapisany obok workflow |
| `.github/scripts/codeql-languages.sh` | lista języków albo komunikat braku materiału |
| `.github/scripts/codeql-gate.sh` | czyta SARIF i stosuje próg `7.0` |
| `.github/codeql/fixtures/high.sarif` | jeden wynik `security-severity` równy `7.0` |
| `.github/codeql/fixtures/low.sarif` | jeden wynik `security-severity` równy `3.0` |
| `.github/rulesets/develop.json` | dopisany check `codeql` |
| `.github/rulesets/release.json` | ten sam check |
| `.github/rulesets/main.json` | ten sam check |

`codeql-config.yml` wyklucza:

- `docs/**`
- `versions/**`
- `**/*.Generated.cs`, gdy taki plik kiedyś powstanie z generatora
- katalogi `bin` i `obj`

Wyzwalacz:

```yaml
on:
  pull_request:
    branches: [develop, release, main]
```

Bez `push`. Bez `paths`. `timeout-minutes` to `30`. Nie ma `self-hosted` i nie ma
`pull_request_target`. Check `codeql` wchodzi do `develop.json`, `release.json` i
`main.json`.

Skrypt bramki wyciąga `security-severity` z `runs[].results[]` oraz z `properties`, zależnie
od tego, gdzie dana paczka zapytań je kładzie. Na końcu wypisuje liczbę wyników blokujących.
Kod `1`, gdy liczba jest większa od zera. Kod `0`, gdy liczba jest zerem. Fixture
`high.sarif` ma dać liczbę większą od zera. Fixture `low.sarif` ma dać zero.

## Plan

### 1. Dodać wykrywanie języków

Utwórz `codeql-languages.sh`. Przejdź drzewo `git ls-files`. Wypisz `csharp`, jeśli
znajdziesz `.cs`. Wypisz `javascript-typescript`, jeśli znajdziesz `.js`, `.ts` albo `.tsx`.
Ignoruj `bin`, `obj`, `node_modules` i `dist`. Gdy nie wypiszesz nic, zakończ kodem `0` i
linią `no material for codeql`. Kod `2` zostaw dla błędu użycia. Nie wpisuj innych języków.
Nie wpisuj YAML ani Markdown.

### 2. Dodać bramkę SARIF

Utwórz `codeql-gate.sh`. Argument `--sarif` wskazuje plik. Czytaj `security-severity` z
`runs[].results[]` oraz z `properties`. Brak pola przy wyniku o tagu `security` traktuj jak
`7.0`. Wynik spoza tagu `security` ignoruj. Próg trzymaj jako stałą w skrypcie. Wypisz
liczbę wyników blokujących. Zakończ kodem `1`, gdy liczba jest większa od zera.

`high.sarif` ma kończyć się kodem `1`. `low.sarif` ma kończyć się kodem `0`. Nie czytaj
progu ze zmiennej workflow.

### 3. Dodać workflow

Utwórz `codeql.yml` z jobem o nazwie `codeql`. Kroki:

1. Checkout z `fetch-depth: 2` i `persist-credentials: false`.
2. `codeql-languages.sh`. Gdy linia `no material` jest w wyjściu, kolejne kroki skanu się
   nie wykonują, a job kończy się sukcesem.
3. `init` z językami z kroku 2, z `queries: security-extended` i z `config-file` wskazującym
   `.github/codeql/codeql-config.yml`.
4. Dla C#: zainstaluj SDK z `global.json` krokiem `setup-dotnet`, potem
   `dotnet build <projekt> --configuration Release` na każdym śledzonym `*.csproj`.
   `autobuild` dla C# wyłącz. Brak `global.json` przy wykrytym C# kończy krok kodem `1`.
5. `analyze` z wyjściem SARIF do ustalonej ścieżki.
6. `codeql-gate.sh`.
7. Upload SARIF, gdy zmienna przebiegu `CODEQL_UPLOAD` nie jest ustawiona na `false`.
   Domyślnie próbuj. Krok uploadu ustaw na `continue-on-error: true`.

`runs-on` ustaw na `ubuntu-latest`. `timeout-minutes` ustaw na `30`. `permissions` na pliku
zostaw puste. Job dostaje `contents: read`. `security-events: write` dodaj tylko na kroku
uploadu, gdy ten krok jest w przebiegu. Wyzwalacz to `pull_request` na `develop`, `release`
i `main`. Nie dodawaj `paths`, `pull_request_target` ani `push`. Nie dodawaj języka na
sztywno w YAML. Każdą akcję `uses` przypnij do pełnego SHA i dopisz komentarz wersji.
Artefakt przebiegu nazwij `codeql-sarif` i ustaw retencję na 14 dni.

### 4. Dodać konfigurację wykluczeń

Utwórz `codeql-config.yml` z `paths-ignore` z sekcji ścieżek. Nad każdym wykluczeniem zostaw
komentarz YAML z powodem. Nie dodawaj `queries` w tym pliku. Zestaw zostaje w `init`. Nie
wykluczaj `src/**`. Nie wykluczaj testów całym katalogiem `src`.

### 5. Dopisać check do rulesetów

W tym samym scaleniu dopisz `codeql` do `.github/rulesets/develop.json`,
`.github/rulesets/release.json` i `.github/rulesets/main.json`. Po syncu pull request do
`develop` czeka na ten check. Pull request do `release` i do `main` też czeka. Nie dopisuj
nazwy w scaleniu, które jeszcze nie zawiera `codeql.yml`.

### 6. Zostawić wzorzec SARIF do suchego przebiegu

Utwórz `.github/codeql/fixtures/high.sarif` z jednym wynikiem `security-severity` równym
`7.0`. Utwórz `.github/codeql/fixtures/low.sarif` z jednym wynikiem `3.0`. To nie są wyniki
prawdziwego kodu produktu. Oba pliki mają być małe i nie zawierać fragmentu kodu usługi.
Służą do testu `codeql-gate.sh`.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `codeql-languages.sh` | job `codeql`, suchy przebieg | nie wołać `init` bez języka |
| `codeql-gate.sh` | job `codeql`, suchy przebieg | zamienić SARIF na kod wyjścia |
| `codeql-config.yml` | `init` | te same wykluczenia lokalnie i w CI |
| `codeql.yml` | GitHub na pull request do `develop`, `release` i `main` | check `codeql` |
| `fixtures/*.sarif` | test lokalny bramki | próg bez uruchamiania całego skanu |
| `develop.json`, `release.json`, `main.json` | sync z numeru `01` | check wymagany |

Job `build` z numeru `02` nie woła CodeQL. Osoba czytająca czerwony pull request ma
zobaczyć, który check padł. Zielony `unit-tests` przy czerwonym `codeql` zostawia pull
request na `develop` zablokowany, choć tytuł `feat(news): publish article revision` jest
poprawny. Ta sama czerwień powtarza się na promocji `develop` → `release`.

## Testy

`actionlint`:

```bash
actionlint .github/workflows/codeql.yml
```

Kod `0`. W pliku ma być `ubuntu-latest` i nie ma być `self-hosted`, `pull_request_target`
ani `paths:`.

```bash
grep -nE 'self-hosted|pull_request_target|^[[:space:]]*paths:' .github/workflows/codeql.yml
```

Brak trafień. Kod grepa `1` jest wynikiem pozytywnym. Jedno trafienie `pull_request_target`
wystarcza, żeby skan kodu z pull requestu dostał uprawnienia gałęzi docelowej.

Suchy przebieg języków w drzewie bez źródeł C# i TypeScript:

```bash
.github/scripts/codeql-languages.sh
```

Linia `no material for codeql`, kod `0`. Powód, dla którego padłby zły skrypt: wypisał
`csharp` bez pliku `*.cs` i job zawołałby `init` na promocji dokumentacji.

Suchy przebieg bramki:

```bash
.github/scripts/codeql-gate.sh --sarif .github/codeql/fixtures/low.sarif
echo $?
.github/scripts/codeql-gate.sh --sarif .github/codeql/fixtures/high.sarif
echo $?
```

Pierwszy kod `0`. Drugi kod `1`. To jest przykład, który ma paść: severity `7.0` blokuje,
nawet gdy reszta pull requestu jest pusta. Powód padnięcia drugiego wywołania jest jeden:
waga równa progowi. Waga `3.0` tego progu nie sięga i zostaje w logu.

Zła nazwa gałęzi nadal pada w numerze `01` i nie dochodzi do sensownego werdyktu CodeQL:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. Nazwa `feature/lesson-markdown` przy celu `develop` daje kod `0`. CodeQL na takim
pull requeście do `develop` startuje. Przy braku źródeł kończy się `no material for codeql`.
Przy obecności `*.cs` kończy się wynikiem bramki SARIF. Ten sam job startuje na promocji
`develop` → `release` i na `release` → `main`.

Pełnego skanu CodeQL nie trzeba ciągnąć w pętli nad każdą poprawką dokumentacji. Raz na
gałęzi, która już ma plik `*.cs`, lokalnie można odpalić ten sam workflow przez runner
GitHuba. Otwarty pull request do `develop` ma w logu albo `no material for codeql`, albo
podsumowanie liczby alertów od `7.0`. Upload, który padnie brakiem produktu, nie zmienia
tego kodu, bo krok ma `continue-on-error: true`.

W `codeql.yml` każdy `uses` ma pełny SHA i komentarz wersji. Brak SHA na
`github/codeql-action/init` jest osobnym powodem, dla którego później padnie `action-pins`.
Ten numer zostawia pin w pliku od pierwszego scalenia workflowu.

## Zasady

- Check nazywa się `codeql` i jest wymagany na `develop`, `release` oraz `main`.
- Workflow startuje na pull requeście do tych trzech gałęzi. Na `push` nie startuje.
- Zestaw zapytań to `security-extended`.
- Blokuje `security-severity` od `7.0` włącznie. Alert bezpieczeństwa bez pola wagi też
  blokuje.
- `low.sarif` z wagą `3.0` kończy się kodem `0`. `high.sarif` z wagą `7.0` kończy się kodem
  `1`.
- Brak `*.cs` i brak plików JavaScript oraz TypeScript to sukces z linią
  `no material for codeql`.
- Języki wykrywa skrypt: `csharp` oraz `javascript-typescript`. Listy na sztywno w YAML nie
  ma.
- Job idzie na `ubuntu-latest`. `timeout-minutes` to `30`. `fetch-depth` to `2`.
- Werdykt jest kodem wyjścia joba. Zakładka Security jest widokiem, gdy upload się uda.
- Krok uploadu ma `continue-on-error: true`. Błąd uploadu nie zmienia kodu bramki.
- Wykluczenie ścieżki jest w `codeql-config.yml` razem z powodem w komentarzu YAML.
- Akcje są przypięte do pełnego SHA.
- Job nie czyta sekretu aplikacji i nie loguje się do obcej usługi skanującej.
- `paths` i `pull_request_target` są zabronione.

## Poza zakresem

- Które checki w ogóle są wymagane na której gałęzi, jest w [02-bramki.md](02-bramki.md).
  Ten numer dopisuje `codeql` do `develop`, `release` i `main`.
- CVE w pakiecie NuGet, npm i w warstwach obrazu są w
  [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md). Ten numer nie czyta lockfile i nie
  woła Trivy.
- Bramka jakości, duplikacja i pokrycie są w [05-sonarqube.md](05-sonarqube.md). Ten numer
  nie uruchamia zestawu `security-and-quality`.
- Sekrety w diffie i pin akcji są w [06-lancuch-dostaw.md](06-lancuch-dostaw.md). Ten numer
  przypina własne `uses` do SHA i nie trzyma tokenu w YAML.
- Naprawa konkretnego alertu w kodzie usługi jest w numerze API, który ten kod dodaje. Ten
  numer nie opisuje treści zapytań poszczególnych CVE.
- Maszyna, na której kiedyś stoi Sonar, jest w [08-proxmox.md](08-proxmox.md). Ten numer nie
  stawia tam CodeQL. Skan idzie na `ubuntu-latest`.
- Nazwa gałęzi i tytuł są w [01-galezie.md](01-galezie.md). Ten numer nie puszcza
  `feature/lesson_markdown`. Kod `1` zostaje przy tamtym skrypcie.

Alert CodeQL w usłudze naprawia się w pull requeście tej usługi. Ten numer nie opisuje
treści zapytań poszczególnych CVE.

## Źródła

- [About code scanning with CodeQL](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql).
  Wiążące jest to, że CodeQL buduje bazę po kodzie i uruchamia zapytania o przepływ, a nie
  tylko szuka wzorca w linii. Dotyczy joba `codeql` na `develop`, `release` i `main` oraz
  tego, że skan nie czyta lockfile. Ze źródła nie bierzemy zastąpienia testu jednostkowego
  tym skanem.
  Zielony `[Fact]` i czerwony `codeql` mogą współistnieć, a CVE paczki zostaje w numerze
  `04`.
- [CodeQL query suites](https://docs.github.com/en/code-security/code-scanning/managing-your-code-scanning-configuration/codeql-query-suites).
  Wiążąca jest nazwa zestawu `security-extended` oraz różnica wobec zestawu z zapytaniami
  jakości. Dotyczy wejścia `queries` w `init`. Ze źródła nie bierzemy
  `security-and-quality`. Jakość zostaje przy SonarQube i przy `dotnet format`, a próg `7.0`
  zostaje stałą w `codeql-gate.sh`.
- [About code scanning alerts](https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts/about-code-scanning-alerts#about-alert-severity-and-security-severity-levels).
  Wiążąca jest skala `security-severity`, w której wysoka waga zaczyna się od `7.0`. Dotyczy
  progu włączającego, fixture `high.sarif` z wagą `7.0` i fixture `low.sarif` z wagą `3.0`.
  Ze źródła nie bierzemy samego poziomu słownego z zakładki jako werdyktu joba. Werdykt
  czyta liczbę z SARIF, a brak liczby przy tagu `security` blokuje tak jak `7.0`.
- [CodeQL action](https://github.com/github/codeql-action). Wiążące są wejścia `init` i
  `analyze`: języki, `queries`, plik konfiguracji i wyjście SARIF. Dotyczy kroków workflowu
  przypiętych do pełnego SHA. Ze źródła nie bierzemy `autobuild` dla C#. Kompilacja C# to
  `dotnet build` każdego śledzonego `*.csproj` w konfiguracji `Release`, po instalacji SDK
  z `global.json`. Dla `javascript-typescript` zostaje wykrycie źródła, bez bundla z
  `dist/`.
- [Customizing code scanning](https://docs.github.com/en/code-security/code-scanning/creating-an-advanced-setup-for-code-scanning/customizing-your-advanced-setup-for-code-scanning).
  Wiążące są identyfikatory języków i `paths-ignore` w pliku konfiguracji. Dotyczy
  wykrywania `csharp` oraz `javascript-typescript` oraz wykluczeń `docs/**`, `versions/**`,
  `**/*.Generated.cs`, `bin` i `obj`. Ze źródła nie bierzemy sztywnej listy języków w YAML
  od pierwszego commita. Pusta lista kończy się linią `no material for codeql` i nie woła
  `init`.
- [SARIF support for code scanning](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning).
  Wiążące jest pole `security-severity` w wyniku SARIF, także gdy leży w `properties`.
  Dotyczy `codeql-gate.sh` i progu `7.0`. Ze źródła nie bierzemy uploadu jako jedynego
  miejsca, w którym waga zaczyna obowiązywać. Skrypt czyta plik z przebiegu, zanim upload
  cokolwiek pokaże w zakładce.
- [Uploading a SARIF file](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github).
  Wiążące jest to, że upload pokazuje alerty w code scanning, gdy konto przyjmuje plik
  SARIF. Dotyczy kroku uploadu z `continue-on-error: true`, uprawnienia
  `security-events: write` tylko na tym kroku i artefaktu `codeql-sarif` trzymanego 14 dni.
  Ze źródła nie bierzemy nieudanego uploadu jako porażki bramki. Kod z `codeql-gate.sh`
  zostaje, a plik SARIF nie wchodzi do obrazu.
- [continue-on-error](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idstepscontinue-on-error).
  Wiążące jest to, że krok z tym polem nie przewraca wniosku całego joba swoim błędem.
  Dotyczy wyłącznie kroku uploadu SARIF. Ze źródła nie bierzemy tego pola na kroku
  `codeql-gate.sh`. Bramka przy wadze `7.0` ma zakończyć job kodem `1`, a upload ma prawo
  się nie udać i nie zmienić tego kodu.
- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).
  Wiążące są zawężone `permissions` i `persist-credentials: false`. Dotyczy pustych
  uprawnień na pliku, `contents: read` na jobie i zakazu `pull_request_target`. Ze źródła
  nie bierzemy szerokiego tokenu „żeby upload na pewno przeszedł”. Upload, który potrzebuje
  `security-events: write`, dostaje je na swoim kroku, a reszta joba ich nie ma.
- [Checkout](https://github.com/actions/checkout). Wiążące jest `fetch-depth`. Dotyczy
  wartości `2` w jobie `codeql`, wystarczającej do diffu pull requestu. Ze źródła nie
  bierzemy `fetch-depth: 0` w tym jobie. Pełna historia zostaje przy jobie `branch-name`, a
  płytkość `1` ucięłaby diff, którego analiza pull requestu używa.
- [Require status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).
  Wiążące jest to, że wymieniony check musi zaraportować sukces, inaczej scalenie stoi.
  Dotyczy dopisania `codeql` do `develop.json`, `release.json` i `main.json` w scaleniu,
  które dodaje workflow. Ze źródła nie bierzemy pominięcia tej nazwy na `develop`. Workflow
  tam startuje i nazwa jest wymagana. Inaczej squash wpuściłby drogę, którą widać dopiero
  przy promocji.
- [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
  Wiążące jest to, że filtr `paths` zostawia wymagany check w oczekiwaniu. Dotyczy zakazu
  `paths` w `codeql.yml`, także na promocji, która dotyka tylko dokumentacji. Ze źródła nie
  bierzemy pominięcia joba jako zamiennika linii `no material for codeql`. Pusty sukces jest
  jawnym logiem i kodem `0`.
- [GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners).
  Wiążący jest obraz `ubuntu-latest` bez dostępu do sieci domowej. Dotyczy `runs-on` joba
  `codeql` i limitu `timeout-minutes` równego `30` na tym obrazie. Ze źródła nie bierzemy
  `self-hosted`. Skan pull requestu nie jedzie na maszynę z numeru `08`.
- [Job timeout-minutes](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes).
  Wiążący jest limit minut przebiegu. Dotyczy wartości `30` przy CodeQL, dłuższym niż
  `dotnet build`. Ze źródła nie bierzemy zdjęcia limitu „bo skan czasem trwa”. Po
  trzydziestu minutach przebieg się kończy i ruleset widzi porażkę, nie wiszący check.
- [actionlint](https://github.com/rhysd/actionlint). Wiążące jest lokalne sprawdzenie
  składni `codeql.yml`, z oczekiwanym kodem `0`. Dotyczy workflowu tego numeru. Ze źródła
  nie bierzemy werdyktu `actionlint` jako progu `7.0`. Próg sprawdza suchy przebieg
  `codeql-gate.sh` na dwóch plikach SARIF, a zakaz `self-hosted` i `paths:` sprawdza `grep`.

## Gotowe gdy

- Są `codeql.yml`, `codeql-config.yml`, oba skrypty i dwa pliki SARIF w `fixtures`.
- `actionlint .github/workflows/codeql.yml` kończy się kodem `0`.
- `grep` nie znajduje `self-hosted`, `pull_request_target` ani `paths:` i kończy się kodem
  `1`.
- `codeql-languages.sh` w drzewie bez C# i TypeScript wypisuje `no material for codeql` i
  kończy się kodem `0`.
- `codeql-gate.sh` na `low.sarif` kończy się kodem `0`, a na `high.sarif` kodem `1`.
- `develop.json`, `release.json` i `main.json` zawierają `codeql`.
- `check-branch-name.sh` dla `feature/lesson_markdown` kończy się kodem `1`.
- W `codeql.yml` każdy `uses` ma pełny SHA i komentarz wersji.
- `queries` w `init` to `security-extended`. Progu nie ma w zmiennej workflow.
- `timeout-minutes` to `30`, `runs-on` to `ubuntu-latest`, a checkout ma `fetch-depth: 2`.
- Krok uploadu ma `continue-on-error: true`.
