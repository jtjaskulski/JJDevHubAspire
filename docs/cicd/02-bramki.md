# 02. Bramki

Poprzedni numer, [Gałęzie](01-galezie.md), odrzuca złą nazwę i zły tytuł. Następny,
[CodeQL](03-codeql.md), czyta ścieżki w kodzie. Ten numer dodaje trzy bramki jako wymagane
checki. Rozdziela je na `develop`, `release` i `main`, wykrywa dotknięte komponenty i
dokłada joby kompilacji, formatu oraz trzech pięter testów. Joby z numerów `03`–`07` wpisuje
do zestawów reguł w momencie, w którym te numery zaczynają je raportować. Sam CodeQL, skan
obrazu, SonarQube, gitleaks i tag opisują własne pliki.

Scenariusz, który bez tej ramy się rozpada, ma zielony tytuł i czerwony test. Pull request
News niesie `feat(news): publish article revision`. Job `pr-title` z numeru `01` jest
zielony, a nazwa gałęzi pasuje do prefiksu. Test jednostkowy ścieżki publikacji pada:
artykuł nie dochodzi do stanu, który test zapisał. Bez joba `unit-tests` squash i tak
wchodzi na `develop`, bo ruleset widzi tylko nazwę i tytuł. Numer
[07-wersje.md](07-wersje.md) potrafi wtedy podbić `versions/news.json` z commita, którego
test nie przeszedł. Na `main` powstaje tag `news-v…`, a [16-deploy.md](16-deploy.md) wgrywa
obraz publikacji, która pada. Zielony tytuł nie naprawia czerwonego testu.

Drugi rozjazd jest na promocji. Ten sam tytuł przechodzi test jednostkowy na `develop`, a
test integracyjny pada, bo publikacja nie widzi bazy, którą kontener podnosi dopiero na
`release`. Para `develop` → `main` jest już odrzucona przez `branch-name`. To nie wystarcza
rulesetowi `main`. Pełny ciąg na `main` jest listą checków, nie wspomnieniem, że „kiedyś na
`release` było zielono”. Starszy zielony przebieg integracji nie opisuje głowy, która doszła
później. Głową promocji jest `develop` albo `release`. Nowy commit na tej głowie powtarza
bramkę. `develop` przy promocji nie jest rebase'owane.

Trzeci rozjazd jest w pull requeście, który dotyka tylko `docs/cicd/02-bramki.md`. W drzewie
nie ma jeszcze `*.csproj`. Job `build` ma wypisać `no material for build` i skończyć się
kodem `0`. Check przy tym istnieje. Filtr `paths` na `on` w ogóle nie uruchomiłby workflowu.
Wymagany status zostałby w oczekiwaniu i dokument o bramkach nie dałby się scalić. Brak tej
nazwy na liście checków wpuściłby później pierwszy projekt bez kompilacji. Osobnej,
późniejszej bramki się nie włącza.

Po tym numerze pierwszy pull request funkcji nie wchodzi na długą gałąź tylko dlatego, że
nazwa i tytuł są poprawne. Musi jeszcze przejść bramkę tej gałęzi. Solution może nie
istnieć. Job `build` wtedy kończy się kodem `0` i jednym zdaniem w logu. Ten sam job, po
dojściu pierwszego `csproj`, kompiluje albo pada.

## Po co

[01-galezie.md](01-galezie.md) zamyka nazwę i tytuł. Zostaje luka, którą widać na rewizji
artykułu: zielony `feat(news): publish article revision` może nieść kod, który się nie
kompiluje, test, który pada, albo zmianę wpuszczoną na `main` z pominięciem testu
integracyjnego. Tytuł wybierze kiedyś tag `news`. Bramka ma zatrzymać ten tag, zanim
powstanie, jeśli publikacja nie przechodzi piętra, które do tej gałęzi należy. Sam plik
wersji jeszcze nie powstaje w tym numerze. Powstaje obowiązek statusu, bez którego wersja
nie ma prawa ruszyć.

Trzy bramki układają koszt sprawdzenia według dojrzałości zmiany.

| Cel | Przed scaleniem |
| --- | --- |
| `develop` | build, test jednostkowy, format, sekret, podatność, nazwa, tytuł |
| `release` | oraz integracja, CodeQL, SonarQube, skan obrazu |
| `main` | oraz NBomber, SBOM, atestacja, tag zmienionych |

Na `develop` prawdą ma być to, że kod dotkniętych komponentów się buduje, test jednostkowy
przechodzi, format jest czysty, sekret i podatność zależności są ocenione, a nazwa i tytuł
są poprawne. Na `release` dochodzą test integracyjny, CodeQL, SonarQube i skan obrazu, gdy
jest Dockerfile. Na `main` dochodzą test wydajności NBomber, SBOM, atestacja i tag tylko
zmienionych komponentów. Sekret, podatność, CodeQL, SonarQube, skan, SBOM, atestacja i tag
raportują joby z numerów `03`–`07`. Ten numer rezerwuje dla nich miejsce w JSON w scaleniu,
które dodaje ich workflow. Samych tych workflowów tutaj nie ma.

Checki z `develop` raportują się także na pull request do `release` i do `main`. Checki z
`release` raportują się także na pull request do `main`. Inaczej ruleset `main` czekałby na
status, którego workflow nie wysłał, i każdy merge stałby w miejscu. Promocja `release` →
`main` powtarza `build` i `unit-tests`. Powtórzenie jest tańsze niż dziura, w której zielony
tytuł z `develop` jedzie na tag bez świeżej kompilacji. Przy `ubuntu-latest` minuty
powtórzonego testu jednostkowego są kosztem, który zostaje.

Bramka jest per komponent. Zmiana w News nie uruchamia ciężkiej pracy Identity. Ścieżka
`src/services/News/News.Api/Program.cs` daje komponent `news` i nie daje `identity`.
Wykrycie jest w skrypcie. Sam job i tak startuje na każdym pasującym pull requeście, a
wewnątrz wychodzi sukcesem, gdy ten komponent nie został dotknięty albo gdy w drzewie nie ma
jeszcze jego projektu. Wymagany check nie może być pominięty filtrem `paths` na `on`, bo
GitHub wtedy w ogóle nie raportuje statusu. Zielona publikacja News nie ma prawa zależeć od
tego, czy ktoś pamiętał checkbox Identity.

Numer jest przed kodem usług. Brak projektu testowego przy braku projektu produkcyjnego jest
pustym sukcesem `unit-tests`. Projekt produkcyjny w `src/services`, `src/gateway` albo
`src/shared`, bez projektu testowego, tym sukcesem nie jest. Job pada. Inaczej pierwsza
usługa News weszłaby na `develop` z tytułem `feat(news): publish article revision` i z zerem
testów, a log wyglądałby tak samo jak log pull requestu, który dotyka tylko dokumentacji. Te
dwa zielone mają być rozróżnialne. Pusty sukces pisze `no material for unit-tests`. Brak
testu przy istniejącym projekcie pisze porażkę.

`feature/lesson_markdown` nadal pada w numerze `01`, kodem `1`, zanim ktokolwiek czyta log
`build`. Zielony `build` nie naprawia podkreślenia w nazwie. Poprawna nazwa
`feature/lesson-markdown` przy celu `develop` daje kod `0` i dopiero wtedy bramka kompilacji
ma sens. Pull request o złej nazwie nie wchodzi na `develop`. Zielona kompilacja nie zmienia
werdyktu `branch-name`.

Gałąź robocza, która została w tyle za `develop`, dostaje rebase na `origin/develop`, zanim
`build`, `unit-tests` i `format` raportują się na SHA, które ruleset `develop` uznaje za
aktualne. Świeżość względem celu jest włączona tylko na `develop`. Wciągnięcie `main` do
tej gałęzi nie odświeża bramki: `branch-name` pada na zamku przodków. Promocja jest merge
commitem. Jej głową jest długa gałąź, więc `develop` nie jest rebase'owane pod test
integracyjny ani pod test wydajności.

## Dlaczego ta technologia

### Trzy progi zamiast jednego workflowa

Jedna lista checków na wszystkich gałęziach jest jednym workflowem tylko z pozoru. Jedna
lista na `main`, wymagana już na `develop`, spowalnia każdy szkic o CodeQL, SonarQube i
NBomber. Rewizja artykułu, która jeszcze nie ma prawa do tagu, czekałaby na obciążenie i na
skan obrazu, choć Dockerfile może nie istnieć. Jedna lista tylko na `develop` wpuszcza na
`main` zmianę, która nigdy nie widziała testu integracyjnego. Tytuł
`feat(news): publish article revision` byłby wtedy zielony dwa razy, na nazwie i na teście
jednostkowym, a publikacja przeciwko bazie w kontenerze nie zostałaby uruchomiona ani razu.

Ręczna checklista w opisie pull requestu odpadła. Nie blokuje przycisku scalenia. Osoba może
zaznaczyć „test integracyjny odpalony” i scalić squash, którego job nie widział. Ruleset
czyta status checka, nie zdanie w opisie. Czwarta długa gałąź „tylko pod test wydajności”
też odpadła. `main` już jest tym progiem. Osobna głowa obok trzech z numeru `01`
rozjechałaby pary `branch-name` i dała drugą drogę na tag, obok `release`.

Koszt, który zostaje, jest powtórzeniem tańszych jobów przy promocji `develop` → `release` →
`main`. `build`, `unit-tests` i `format` raportują się na każdej z trzech gałęzi. Przy
`ubuntu-latest` powtórzenie kompilacji i testu jednostkowego jest tańsze niż dziura w
rulesecie. Dziura wygląda tak: na `develop` test przeszedł, na drodze do `main` nikt go nie
powtórzył, a w międzyczasie doszedł squash kernela. Głowa promocji jest czubkiem `develop`
albo `release`. Nowy commit na tej głowie zmienia SHA i stary zielony `unit-tests` jej nie
opisuje. Świeżość względem celu na `release` i `main` zostaje wyłączona. Włączona żądałaby
wciągnięcia merge commita promocji z powrotem do źródła, a kierunek z numeru `01` jest
jeden.

Podział na trzy pliki workflow, a nie jeden plik z warunkiem gałęzi w środku, trzyma nazwę
checka stabilną. `integration-tests` nie startuje na `develop`, bo wyzwalacz ma gałęzie
`release` i `main`. Na `develop` ten check nie jest wymagany. Gdyby ten sam job był w
workflowu odpalanym na `develop` i pomijany warunkiem, ruleset `develop` nie powinien go
wymagać, a pomyłka w JSON wciągnęłaby oczekiwanie. Osobny plik na piętro sprawia, że brak
przebiegu na `develop` jest skutkiem wyzwalacza, nie pominięcia wymaganego checka.

Po numerze `07` listy w JSON mają być pełne. Do tego czasu każdy numer dopisuje swoje nazwy
sam, w scaleniu, które dodaje workflow. Ten numer nie wpisuje `codeql`, `sonarqube`,
`image-scan`, `gitleaks`, `dependency-vulnerabilities`, `sbom`, `attestations`,
`release-tags`, `zizmor`, `action-pins` ani `scorecard`, dopóki ich plików nie ma w tym
samym scaleniu. Wpisanie nazwy wcześniej zatrzymuje każdy merge, łącznie z poprawką
dokumentacji bramek.

### Rebase gałęzi roboczej przed bramką

`strict_required_status_checks_policy` na `develop` wymaga, żeby głowa niosła aktualny
`develop`. Rebase na `origin/develop` i force-push dają nowe SHA, na którym `build`,
`unit-tests` i `format` raportują się od zera. Scalenie `develop` do gałęzi roboczej merge
commitem też dogoniłoby cel, ale zostawiłoby na głowie drugiego rodzica. Squash na
`develop` i tak zgniata tę historię. Rebase trzyma głowę jako linię commitów nad czubkiem
`develop`.

Wciągnięcie `main` albo `release` do gałęzi roboczej odpadło. `branch-name` kończy się
kodem `1`, bo `merge-base` z `origin/main` nie jest przodkiem `origin/develop`. Zielony
`build` takiego drzewa nie jest bramką pracy wyciętej z `develop`.

Rebase `develop` pod promocję odpadł. Głową pull requestu `develop` → `release` jest sama
gałąź `develop`. `non_fast_forward` nie pozwala jej przepisać. Promocja jest merge
commitem: na `release` dochodzi test integracyjny, na `main` test wydajności, a tańsze
joby powtarzają się na tej głowie. Świeżość względem celu zostaje wyłączona na tych dwóch
gałęziach, żeby GitHub nie żądał powrotu merge commita do źródła.

### `ubuntu-latest` na pull request

Każdy job tego numeru, i każdy job numerów `01` oraz `03`–`07`, ustawia
`runs-on: ubuntu-latest`. Dotyczy to zdarzeń `pull_request`, `push` i `schedule`. Etykieta
jest jedna. Obraz runnera niesie kompilator z `global.json`, gdy plik już jest, oraz
Dockera, którego użyje test integracyjny, gdy test z kategorią już będzie. Do tego dnia
Docker może zostać nieużyty. Job i tak jest zielony, bo brak testu `Category=Integration`
jest pustym sukcesem, nie błędem obrazu.

Runner własny na `pull_request` odpadł. Kod z pull requestu wykonywałby się na maszynie,
która może mieć dostęp do sieci domowej albo do plików spoza repozytorium. Rewizja artykułu
wciągałaby wtedy do joba nie tylko diff News, ale i otoczenie, którego nie ma w gitcie. Ten
produkt nie ma takiego runnera w bramce. Maszyna z [08-proxmox.md](08-proxmox.md) przyjmuje
obraz z tagu w [16-deploy.md](16-deploy.md), a nie job z otwartego pull requestu. Tag
`news-v…` jest granicą. Przed tagiem kod ogląda tylko `ubuntu-latest`.

Koszt zostaje w minutach GitHub Actions, nie w sprzęcie stojącym przy biurku. Test z
kontenerem, gdy numer API już nada cechę `Category=Integration`, korzysta z Dockera
dostępnego na obrazie `ubuntu-latest`. Osobnej usługi bazy w `services:` workflow nie ma.
Test, który ma kategorię, podnosi kontener sam. Gdy testów nie ma, blok `services:` i tak
startowałby kontener na każdy pull request dokumentacji. Dlatego bloku nie ma. Pusty sukces
nie płaci za bazę, której fakt jeszcze nie potrzebuje.

`self-hosted` nie występuje w plikach tego numeru. `pull_request_target` też nie. To
zdarzenie wykonuje workflow z uprawnieniami gałęzi docelowej. Bramka kompilacji czyta kod
głowy i nie potrzebuje sekretu. `permissions` joba to `contents: read`. Sekretów nie ma.
Checkout ustawia `persist-credentials: false`, żeby token nie został w katalogu roboczym na
dalsze kroki. `timeout-minutes` to `20` dla buildu, formatu i testu jednostkowego oraz `30`
dla integracyjnego i wydajnościowego. Wiszący kontener nie trzyma runnera do wieczora.

Ta sama etykieta obowiązuje później harmonogram z numeru `04` i skan z numeru `03`. Rozjazd
jednej etykiety, „tylko ten job na szybszej maszynie”, wraca do runnera, którego bramka nie
ma. Test tego numeru szuka `self-hosted` w pięciu workflowach. Brak trafień, przy kodzie
grepa `1`, jest wynikiem pozytywnym.

### Job, który zawsze raportuje

Workflow wymagany przez ruleset nie ustawia `paths` ani `paths-ignore`. Nie ustawia `if` na
całym jobie w sposób, który przy braku plików pomija job. Pominięty job nie zastępuje
sukcesu w zestawie reguł, który wymaga statusu. Pull request dokumentacji ma dostać zielony
`build`, nie pustą kratkę. Zielony bez logu `no material for build` wygląda jak pomyłka w
warunku: kompilacja niby przeszła, a kompilatora nie było. Jedna linia w logu rozdziela te
dwa przypadki.

W pierwszym kroku skrypt mówi, czy jest materiał. Brak `*.csproj` w `build` i `unit-tests`
to sukces. Brak testu `Category=Integration` to sukces joba `integration-tests`. Brak testu
`Category=Performance` to sukces joba `performance`. Brak Dockerfile obsługuje numer `04`,
tym samym zwyczajem. Kroki wewnętrzne mogą mieć `if`, byle job jako całość dostał wniosek
`success`. GitHub pokazuje wtedy sukces, nie pominięcie. Ruleset umie ten wniosek
przeczytać.

„Wyłączymy job, aż powstanie solution” odpadło. Pierwszy pull request z kodem łatwo wchodzi,
zanim ktoś włączy check z powrotem. W tym oknie tytuł `feat(news): publish article revision`
jest zielony, a `build` nie istnieje. Ruleset albo blokuje wszystko, bo nazwa checka już
jest w JSON, albo puszcza kod, bo nazwy jeszcze nie ma. Oba stany są złe, gdy rozjadą się
względem siebie. Scalenie, które dodaje `build.yml`, dopisuje `build` do JSON w tym samym
diffie. Przed tym scaleniem nazwy nie ma. Po nim job już raportuje, także pustym sukcesem,
gdy projektu jeszcze nie ma.

Koszt zostaje w kilku sekundach przebiegu na pull request, który dotyka tylko `docs/`. To
jest zamierzone. Tańsze byłoby pominięcie, i właśnie to pominięcie zostawia wymagany check w
oczekiwaniu, gdy filtr `paths` wytnie dokumentację. Strona o pominiętych przebiegach mówi
wprost, że taki check blokuje scalenie. Dlatego filtr ścieżek jest zabroniony, a pusty
sukces jest jawny. Test tego numeru czyta log z suchego przebiegu `require-material.sh`, nie
z chmury.

Projekt produkcyjny bez projektu testowego nie korzysta z tego pustego sukcesu. `unit-tests`
pada. Sam dokument w `docs/` przy braku projektów nie wymusza testu. Granica jest w drzewie
plików, nie w opisie pull requestu. Kto doda `src/services/News` i nie doda projektu
testowego, dostanie czerwony check, choć `require-material.sh` na samym `*.csproj` znalazłby
materiał kompilacji. To są dwa skrypty. Kompilacja może być zielona, a test czerwony. Tytuł
publikacji nie skleja ich w jeden werdykt.

### Piętra testów zgodne z resztą dokumentacji

| Job | Filtr | Kiedy jest wymagany |
| --- | --- | --- |
| `unit-tests` | `Category!=Integration&Category!=Performance` | `develop`, `release`, `main` |
| `integration-tests` | `Category=Integration` | `release`, `main` |
| `performance` | `Category=Performance` | `main` |

Runner testu to xUnit i `[Fact]`. Test integracyjny, gdy już powstanie w numerach API,
podnosi kontener sam. Test wydajnościowy używa NBomber i cechy `Category=Performance`. Nie
blokuje pull requestu do `develop`. Szkic funkcji, w tym poprawka dokumentacji idąca tylko
na `develop`, nie czeka na obciążenie. Na `develop` job integracyjny nie jest wymagany i
jego workflow nie startuje. Startuje, gdy ta sama poprawka idzie na `release` albo na
`main`.

Osobny serwer testów poza GitHub Actions odpadł. Werdykt żyłby poza statusem, który czyta
ruleset. Trzeba by przenieść go do checka osobnym tokenem, a token byłby sekretem w
workflow. Joby tego numeru sekretów nie czytają. Wrzucenie NBombera do bramki `develop` też
odpadło. Szkic `feat(news): publish article revision` nie czeka na scenariusz obciążenia
endpointu, którego jeszcze nie ma. Piętro wydajności stoi na `main`, obok tagu. Czerwony
NBomber zatrzymuje promocję na `main`, nie każdy commit na `develop`.

Koszt zostaje w czasie testu integracyjnego na `release`. Trwa dłużej niż test jednostkowy,
dlatego nie stoi na każdej poprawce dokumentacji wchodzącej tylko na `develop`. Stoi, gdy ta
poprawka idzie dalej. Zero testów w filtrze integracyjnym albo wydajnościowym to sukces.
Test, który jest i pada, to porażka joba. Jeden czerwony `[Fact]` z cechą
`Category=Integration` wystarcza, żeby zatrzymać promocję News, nawet gdy test jednostkowy
tej samej publikacji jest zielony. Powód padnięcia jest jeden: filtr znalazł test i test nie
przeszedł.

Gdy jest projekt testowy, `dotnet test` z filtrem jednostkowym musi przejść i liczba testów
musi być większa od zera. Pusty zbiór przy istniejącym projekcie testowym nie udaje sukcesu.
Filtr lokalny z dokumentacji produktu,
`--filter "Category!=Integration&Category!=Performance"`, ma dawać ten sam zbiór co job
`unit-tests`. Innego filtra trzy pliki nie mają. Rozjazd filtra w YAML wciągnąłby test
integracyjny na `develop` albo wyciąłby test jednostkowy z bramki, którą ruleset nazywa
`unit-tests`.

NBomber jest zależnością projektu testowego w numerze, który doda endpoint. Ten numer tylko
rezerwuje job i filtr. Licencja NBomber używana w tym jobie to Apache 2.0. Pakietu nie
wpisuje się, dopóki nie ma projektu testowego. Wpisać go wcześniej znaczyłoby trzymać
zależność bez testu, który ją woła, i bez `csproj`, przy którym `unit-tests` umie paść.
`performance` nie otwiera ruchu na zewnątrz. NBomber, gdy test już jest, celuje w proces
podniesiony w jobie.

### Wykrywanie komponentu

Skrypt `.github/scripts/affected-components.sh` czyta listę zmienionych ścieżek i wypisuje
komponenty. Joby `build`, testów i formatu ograniczają pracę do tej listy, ale sam job
pozostaje zielony, gdy lista jest pusta. Wejście to lista ścieżek, po jednej w linii, albo
`--from-git`, które liczy `git diff --name-only` względem celu pull requestu. Wyjście jest
JSON-em. Dla ścieżki News i pliku dokumentacji obok niej lista zawiera `news` i nie zawiera
`identity`, a `kernel` jest `false`.

Zawsze pełne `dotnet test` na całym solution odpadło, gdy solution urośnie do pięciu usług i
dwóch klientów. Zmiana w News płaciłaby czasem Identity, Cv, Contact, Learning, bramy, weba
i telefonu. Ręczny wybór usługi w formularzu workflow też odpadł. Przy squashu łatwo
zapomnieć checkbox, a ruleset i tak potrzebuje statusu. Formularz nie uruchamia się na
zwykłym pull requeście. Mapa ścieżek jest w gitcie i pokrywa układ docelowy, więc pierwszy
projekt usługi nie wymyśla drugiej mapy.

Koszt zostaje przy aktualizacji skryptu, gdy dojdzie nowy katalog komponentu. Do tego czasu
tabela ścieżek jest umową. `src/shared/JJDevHub.Shared.Kernel/**` ustawia `kernel` na
`true`. Lista komponentów przy `kernel: true` pochodzi z `ProjectReference`. Gdy żaden
`csproj` jeszcze nie wskazuje kernela, lista z samego kernela jest pusta i job kończy się
sukcesem. Po powstaniu usług ta sama ścieżka wypełni listę. Podbicie wersji tych usług robi
[07-wersje.md](07-wersje.md). Ten skrypt tylko mówi, kogo budować.

`Directory.Packages.props`, `global.json` i `*.sln` oznaczają wszystkie komponenty, które
już mają projekt. Przed pierwszym projektem ta ścieżka nie wymyśla Identity ani News. Zakres
`infra` oraz katalogi `docs/**` i `.github/**` nie dodają komponentu aplikacji. Joby
kompilacji kończą się wtedy sukcesem po pustej liście, o ile sam workflow w `.github`
przechodzi `actionlint` w teście tego numeru. Zmiana tylko w `docs/cicd/02-bramki.md` daje
pustą listę i kod `0`.

Build, gdy jest solution albo projekt, woła `dotnet build --configuration Release --nologo`.
Wersja SDK pochodzi z `global.json`. Gdy `global.json` nie istnieje, a projektów też nie ma,
kompilator się nie uruchamia. Gdy projekt jest, a `global.json` nie ma, job pada. Numer API,
który doda pierwszy projekt, dodaje `global.json` w tym samym scaleniu. Ten numer CI nie
zgaduje numeru SDK. Zgadywanie wpuściłoby News na innym kompilatorze niż ten, który później
opisze plik w korzeniu, i zielony `build` znaczyłby co innego na dwóch pull requestach.

Format, gdy jest `*.csproj` i `.editorconfig`, woła
`dotnet format --verify-no-changes --severity info`. Gdy jest `package.json` z Prettierem
albo innym formaterem zapisanym w tym pliku, job woła jego sprawdzenie. Gdy nie ma ani
projektów C#, ani `package.json`, kod wyjścia to `0`. Czerwony format przy zielonym tytule
`feat(news): publish article revision` zatrzymuje scalenie tak samo jak czerwony test. Sam
tytuł nie mówi, czy plik jest ułożony.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/build.yml` | job `build` |
| `.github/workflows/unit-tests.yml` | job `unit-tests` |
| `.github/workflows/format.yml` | job `format` |
| `.github/workflows/integration-tests.yml` | job `integration-tests` |
| `.github/workflows/performance.yml` | job `performance` |
| `.github/scripts/affected-components.sh` | mapa ścieżek na komponenty |
| `.github/scripts/require-material.sh` | wspólny komunikat „nie ma materiału, kod 0” |
| `.github/rulesets/develop.json` | dopisane checki pierwszej bramki, w miarę jak joby raportują |
| `.github/rulesets/release.json` | dopisane checki drugiej bramki |
| `.github/rulesets/main.json` | dopisane checki trzeciej bramki |

Mapa ścieżek:

| Ścieżka | Komponent |
| --- | --- |
| `src/services/Identity/**` | `identity` |
| `src/services/News/**` | `news` |
| `src/services/Learning/**` | `learning` |
| `src/services/Cv/**` | `cv` |
| `src/services/Contact/**` | `contact` |
| `src/gateway/**` | `gateway` |
| `src/clients/web/**` | `web` |
| `src/clients/mobile/**` | `mobile` |
| `src/shared/JJDevHub.Shared.Kernel/**` | każda usługa, której `csproj` ma `ProjectReference` do tego projektu |
| `Directory.Packages.props`, `global.json`, `*.sln` | wszystkie komponenty, które już mają projekt |

Wyzwalacze:

| Workflow | `pull_request.branches` |
| --- | --- |
| `build.yml`, `unit-tests.yml`, `format.yml` | `develop`, `release`, `main` |
| `integration-tests.yml` | `release`, `main` |
| `performance.yml` | `main` |

`permissions` joba to `contents: read`. Nie ma `secrets`. Checkout z
`persist-credentials: false`. `timeout-minutes` to `20` dla buildu, formatu i testu
jednostkowego, `30` dla integracyjnego i wydajnościowego. `runs-on` to `ubuntu-latest`.
Identyfikator joba jest równy nazwie checka. Zmiana tej nazwy przy refaktorze YAML rozjeżdża
ruleset: JSON dalej wymaga starego tekstu, a workflow raportuje nowy.

Test jednostkowy. Gdy nie ma żadnego `*.csproj`, sukces i linia
`no material for unit-tests`. Gdy jest projekt produkcyjny w `src/services`, `src/gateway`
albo `src/shared`, a nie ma projektu testowego, job pada. Gdy projekt testowy jest,
`dotnet test` z filtrem jednostkowym musi przejść i liczba testów musi być większa od zera.
Test integracyjny i wydajnościowy: `dotnet test` z filtrem z tabeli. Zero testów w filtrze
to sukces. Test, który jest i pada, to porażka.

## Plan

### 1. Dodać mapę komponentów

Utwórz `affected-components.sh`. Wejście to lista ścieżek, po jednej w linii, albo
`--from-git`. Wyjście to JSON. Dla ścieżki News kształt jest taki:

```json
{"components":["news"],"kernel":false}
```

`kernel` ustaw na `true`, gdy diff dotyka `src/shared/JJDevHub.Shared.Kernel`. Listę
komponentów przy `kernel: true` bierz z `ProjectReference`. Gdy żaden `csproj` jeszcze nie
wskazuje kernela, lista komponentów z samego kernela jest pusta i skrypt kończy się kodem
`0`. Ścieżki z tabeli wyżej wpisz w skrypt. Nie zakładaj drugiej mapy w workflow.

### 2. Dodać pięć workflowów

Utwórz pliki z tabeli ścieżek. Identyfikator joba jest równy nazwie checka. Pierwszy krok
woła mapę albo `require-material.sh`. Dalsze kroki wykonują się, gdy jest materiał. Gdy go
nie ma, workflow dochodzi do końca z kodem `0` i nie używa `if` na całym jobie. Kroki
wewnętrzne mogą mieć `if`, byle job jako całość dostał wniosek `success`.

`runs-on` ustaw na `ubuntu-latest`. `permissions` joba ustaw na `contents: read`. Checkout
ustaw z `persist-credentials: false`. `timeout-minutes` ustaw na `20` albo `30` według
tabeli czasów. Wyzwalacze ustaw według tabeli gałęzi. Nie dodawaj `paths`, `paths-ignore`,
`self-hosted` ani `pull_request_target`.

Build, gdy jest solution albo projekt, woła `dotnet build --configuration Release --nologo`.
Gdy projekt jest, a `global.json` nie ma, zakończ job kodem innym niż zero. Format, gdy jest
`*.csproj` i `.editorconfig`, woła `dotnet format --verify-no-changes --severity info`.

### 3. Dopisać checki do rulesetów

W scaleniu, które dodaje `build.yml`, `unit-tests.yml` i `format.yml`, dopisz do trzech
JSON-ów nazwy `build`, `unit-tests`, `format`. W scaleniu, które dodaje test integracyjny,
dopisz `integration-tests` do `release.json` i `main.json`. W scaleniu testu wydajności
dopisz `performance` do `main.json`.

Nie dopisuj `codeql`, `sonarqube`, `image-scan`, `gitleaks`, `dependency-vulnerabilities`,
`sbom`, `attestations`, `release-tags`, `zizmor`, `action-pins` ani `scorecard` w scaleniu,
które jeszcze nie zawiera ich workflow. Każdy z numerów `03`–`07` dopisuje swoje nazwy sam.

Po numerze `07` listy mają wyglądać tak:

| Plik | Checki |
| --- | --- |
| `develop.json` | `branch-name`, `pr-title`, `build`, `unit-tests`, `format`, `gitleaks`, `dependency-vulnerabilities`, `zizmor`, `action-pins`, `scorecard` |
| `release.json` | checki z `develop` oraz `integration-tests`, `codeql`, `sonarqube`, `image-scan` |
| `main.json` | checki z `release` oraz `performance`, `sbom`, `attestations`, `release-tags` |

### 4. Zostawić pusty sukces jawnym logiem

Każdy wcześniejszy powrót pisze jedną linię `no material for <job>`. Dla buildu linia brzmi
`no material for build`. Bez tej linii zielony job bez kompilacji wygląda jak pomyłka w
warunku. `require-material.sh` przyjmuje `--job` i `--pattern`. W drzewie bez `*.csproj`
wywołanie dla buildu kończy się kodem `0` i tą linią.

### 5. Spiąć filtr z piramidą

W `unit-tests.yml` filtr jest dokładnie `Category!=Integration&Category!=Performance`. W
integracyjnym `Category=Integration`. W wydajnościowym `Category=Performance`. Innego filtra
te trzy pliki nie mają. Gdy projekt testowy jest, a filtr jednostkowy nie znajduje żadnego
testu, job `unit-tests` ma paść. Zero testów w filtrze integracyjnym i wydajnościowym jest
sukcesem.

### 6. Ustawić Dockera tylko tam, gdzie test go potrzebuje

`integration-tests` zakłada Docker na `ubuntu-latest`. Nie stawiaj osobnej usługi bazy w
`services:` workflow. Gdy testów nie ma, Docker pozostaje nieużyty, a job i tak jest
zielony. `performance` nie otwiera ruchu na zewnątrz. Pakietu NBomber nie dodawaj, dopóki
nie ma projektu testowego. Licencja, której ten job użyje, gdy pakiet już będzie, to Apache
2.0.

### 7. Nie dublować skanów

Nie wkładaj CodeQL, Trivy, gitleaks ani SonarQube do `build.yml`. Te joby mają własne pliki
i własne nazwy checków. `build.yml` kończy się na kompilacji. Czerwony test i czerwony skan
mają być dwoma wierszami na liście checków pull requestu z tytułem
`feat(news): publish article revision`.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `affected-components.sh` | joby tego numeru i numerów `04` oraz `07` | jedna mapa ścieżka → komponent |
| `require-material.sh` | pierwszy krok joba | wspólny, widoczny w logu powód pustego sukcesu |
| `build.yml` | pull request na trzy gałęzie | check `build` |
| `unit-tests.yml` | pull request na trzy gałęzie | check `unit-tests` |
| `format.yml` | pull request na trzy gałęzie | check `format` |
| `integration-tests.yml` | pull request na `release` i `main` | check `integration-tests` |
| `performance.yml` | pull request na `main` | check `performance` |
| trzy JSON-y rulesetów | sync z numeru `01` | zamiana zielonego statusu w blokadę przycisku |

Ruleset nie uruchamia testu. Workflow uruchamia test i publikuje status. Ruleset czyta
status. Zielony `pr-title` przy czerwonym `unit-tests` nie scala rewizji artykułu.

## Testy

`actionlint` na plikach tego numeru:

```bash
actionlint \
  .github/workflows/build.yml \
  .github/workflows/unit-tests.yml \
  .github/workflows/format.yml \
  .github/workflows/integration-tests.yml \
  .github/workflows/performance.yml
```

Oczekiwany kod `0`. Dodatkowo przeszukaj pliki i upewnij się, że nie ma `self-hosted` ani
`paths:`:

```bash
grep -nE 'self-hosted|paths:|pull_request_target' .github/workflows/build.yml \
  .github/workflows/unit-tests.yml .github/workflows/format.yml \
  .github/workflows/integration-tests.yml .github/workflows/performance.yml
```

Brak trafień, kod grepa `1`, jest wynikiem pozytywnym. Jedno trafienie `paths:` na
`build.yml` wystarcza, żeby pull request samej dokumentacji zostawił check `build` w
oczekiwaniu.

Suchy przebieg mapy, bez workflow:

```bash
printf '%s\n' 'src/services/News/News.Api/Program.cs' 'docs/cicd/02-bramki.md' \
  | .github/scripts/affected-components.sh
```

Oczekiwany JSON zawiera `news` i nie zawiera `identity`. Powód, dla którego padłby zły
skrypt: ścieżka dokumentacji obok News dodałaby drugi komponent albo wciągnęłaby Identity.

```bash
printf '%s\n' 'docs/cicd/02-bramki.md' | .github/scripts/affected-components.sh
```

Oczekiwana lista komponentów pusta, kod `0`. Sam plik tej dokumentacji nie buduje usługi.

Sam kernel, zanim jakikolwiek `csproj` ma do niego `ProjectReference`:

```bash
printf '%s\n' 'src/shared/JJDevHub.Shared.Kernel/Kernel.cs' \
  | .github/scripts/affected-components.sh
```

Oczekiwane `kernel` równe `true`, pusta lista komponentów i kod `0`. Powód padnięcia złej
mapy byłby jeden: skrypt dopisał `identity` albo `news` bez `ProjectReference`.

Suchy przebieg materiału:

```bash
.github/scripts/require-material.sh --job build --pattern '*.csproj'
```

W drzewie bez projektów kod `0` i linia `no material for build`.

Zła nazwa gałęzi nadal pada wcześniej, w numerze `01`. Powtórzenie, które ma się nie udać,
zanim ktokolwiek spojrzy na `build`:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. Poprawna nazwa `feature/lesson-markdown` przy celu `develop` daje kod `0` i dopiero
wtedy ma sens patrzeć na bramkę kompilacji. Pull request o złej nazwie nie naprawia się
zielonym `build`.

Gdy w drzewie jest już solution, suchy przebieg kompilacji lokalnie to:

```bash
dotnet build --configuration Release --nologo
dotnet test --configuration Release --filter 'Category!=Integration&Category!=Performance' --nologo
```

Ten drugi filtr ma się zgadzać z `unit-tests.yml`. Na gałęzi przed pierwszym projektem obie
komendy nie są kryterium joba. Kryterium jest `require-material.sh`. Gdy projekt już jest, a
`global.json` nie ma, job `build` pada. Ten numer nie podstawia numeru SDK.

Po syncu rulesetu pull request do `develop` pokazuje wymagane `build`, `unit-tests` i
`format`. Brak którejkolwiek pozycji na liście sprawdzeń w interfejsie, przy jednoczesnej
obecności w JSON, oznacza, że sync nie został wykonany. Zielony tytuł
`feat(news): publish article revision` przy czerwonym `unit-tests` zostawia przycisk
scalenia zablokowany. To jest bramka, której sam numer `01` nie ma.

## Zasady

- Bramka `develop` nie wymaga testu integracyjnego, CodeQL, SonarQube, skanu obrazu,
  NBombera, SBOM, atestacji ani tagu.
- Bramka `release` dokłada test integracyjny i checki numerów `03`, `04` (skan obrazu) oraz
  `05`.
- Bramka `main` dokłada NBomber, SBOM, atestację i tag.
- Check z wcześniejszej bramki jest wymagany także na dalszej gałęzi.
- Job wymagany zawsze się kończy statusem, którego ruleset umie przeczytać. Pominięcie joba
  nie zastępuje sukcesu.
- Pusty sukces jest legalny tylko bez materiału. Projekt produkcyjny bez projektu testowego
  nie jest pustym sukcesem `unit-tests`.
- `runs-on` to `ubuntu-latest`. Innej etykiety te pliki nie zawierają.
- Filtr `paths` na `on` jest zabroniony. `pull_request_target` też.
- `timeout-minutes` to `20` dla buildu, formatu i testu jednostkowego oraz `30` dla
  integracji i wydajności.
- Joby tego numeru nie czytają `secrets`. Checkout ma `persist-credentials: false`.
- Filtry to dokładnie `Category!=Integration&Category!=Performance`, `Category=Integration`
  i `Category=Performance`.
- Licencja NBomber w tym jobie to Apache 2.0. Pakietu nie ma, dopóki nie ma projektu
  testowego.
- Nazwa joba nie zmienia się przy okazji refaktoru YAML. Ruleset trzyma ten sam tekst.
- Zielony tytuł `feat(news): publish article revision` nie scala się przy czerwonym teście.
- Zaległa gałąź robocza jest rebase'owana na `origin/develop`, zanim bramka `develop` jest
  zielona na jej SHA.
- Promocja jest merge commitem. `develop` nie jest rebase'owane pod bramkę `release` ani
  `main`.

## Poza zakresem

- Wyrażenie nazwy gałęzi i tytuł są w [01-galezie.md](01-galezie.md). Ten numer nie zmienia
  prefiksu ani listy zakresów.
- Zapytania CodeQL i próg severity są w [03-codeql.md](03-codeql.md). Ten numer nie woła
  `codeql` i nie czyta SARIF.
- `dependency-vulnerabilities`, `image-scan`, `sbom` i `attestations` są w
  [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md). Ten numer nie woła Trivy.
- Bramka jakości SonarQube jest w [05-sonarqube.md](05-sonarqube.md). Ten numer nie stawia
  serwera jakości.
- `gitleaks`, `zizmor`, `action-pins` i `scorecard` są w
  [06-lancuch-dostaw.md](06-lancuch-dostaw.md). Ten numer nie czyta sekretu z diffu.
- Wycięcie tagu jest w [07-wersje.md](07-wersje.md). Ten numer nie tworzy `news-v1.4.0`.
  Zatrzymuje czerwony test, zanim tag w ogóle ma z czego powstać.
- Treść testu usługi, kontener w teście i cecha na metodzie są w numerach `docs/api`. Ten
  numer rezerwuje filtr i check.
- Deploy jest w [16-deploy.md](16-deploy.md). Ten numer nie wgrywa obrazu na maszynę.
- Ten numer nie pisze testu NBomber dla endpointu, którego jeszcze nie ma. Rezerwuje check,
  który taki test zatrzyma na `main`, gdy test już będzie w repozytorium i zacznie padać.

## Źródła

- [Required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).
  Wiążące jest to, że scalenie czeka na sukces wymienionych checków. Dotyczy `build`,
  `unit-tests` i `format` na trzech gałęziach oraz dokładania `integration-tests` i
  `performance` tam, gdzie tabela to mówi. Ze źródła nie bierzemy klasycznej ochrony gałęzi
  wyklikanej w ustawieniach ani wymaganej recenzji. Nazwy siedzą w JSON rulesetu.
- [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
  Wiążące jest to, że workflow pominięty filtrem ścieżek zostawia check w oczekiwaniu i
  blokuje scalenie, oraz że sukces ma dotyczyć najnowszego SHA. Dotyczy zakazu `paths`,
  rebase gałęzi roboczej przed bramką `develop` i powtórzenia jobów na głowie promocji
  `release` → `main`. Ze źródła nie bierzemy pominięcia całego joba warunkiem `if` jako
  zamiennika linii `no material for build`. Ze źródła nie bierzemy świeżości względem celu
  na `release` i `main`.
- [Workflow syntax for paths](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore).
  Wiążące są filtry `paths` i `paths-ignore`, które ograniczają, kiedy workflow w ogóle
  startuje. Dotyczy zakazu tych filtrów w pięciu plikach tego numeru. Ze źródła nie bierzemy
  przykładu, w którym dokumentacja omija kompilację. Pull request do `docs/` ma dostać
  zielony `build` z jawnym logiem.
- [Jobs on GitHub-hosted runners](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners).
  Wiążący jest obraz `ubuntu-latest` jako runner hostowany przez GitHuba, z siecią i
  narzędziami obrazu, bez dostępu do maszyny domowej. Dotyczy każdego joba tego numeru oraz
  jobów numerów `01` i `03`–`07` na `pull_request`, `push` i `schedule`. Ze źródła nie
  bierzemy etykiety `self-hosted`. Maszyna z numeru `08` dostaje obraz z tagu, nie job z
  pull requestu.
- [Workflow syntax for runs-on](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idruns-on).
  Wiążące jest pole `runs-on`, które `actionlint` i numer `06` czytają. Dotyczy wartości
  `ubuntu-latest` w pięciu workflowach. Ze źródła nie bierzemy tablicy etykiet ani grupy
  runnerów własnych. Jedna etykieta trzyma bramkę w jednym obrazie.
- [Workflow permissions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#permissions).
  Wiążące jest zawężenie tokenu przebiegu do `contents: read`. Dotyczy jobów kompilacji,
  formatu i testów. Ze źródła nie bierzemy `contents: write` ani wpisu `secrets` w YAML.
  Checkout dodatkowo gasi `persist-credentials`.
- [Job timeout-minutes](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes).
  Wiążący jest limit minut, po którym GitHub przerywa job. Dotyczy `20` dla `build`,
  `format` i `unit-tests` oraz `30` dla `integration-tests` i `performance`. Ze źródła nie
  bierzemy braku limitu. Wiszący kontener nie zostaje do domyślnego, dłuższego sufitu.
- [Job if](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idif).
  Wiążące jest to, że warunek na całym jobie pomija job. Dotyczy zakazu takiego warunku, gdy
  brak `csproj` miałby pominąć `build`. Ze źródła nie bierzemy pominięcia jako sukcesu
  bramki. Sukcesem pustego drzewa jest job, który doszedł do końca z linią
  `no material for build`, a warunek na kroku wewnątrz joba zostaje.
- [dotnet test filter](https://learn.microsoft.com/dotnet/core/tools/dotnet-test#filter-option).
  Wiążąca jest składnia `--filter` i operatorów na cechach. Dotyczy trzech filtrów z tabeli
  pięter oraz lokalnego polecenia z `Category!=Integration&Category!=Performance`. Ze źródła
  nie bierzemy innego wyrażenia filtra w tych trzech plikach. Nazwa cechy zostaje
  `Category`.
- [dotnet build](https://learn.microsoft.com/dotnet/core/tools/dotnet-build). Wiążące są
  konfiguracja i kod wyjścia kompilacji. Dotyczy
  `dotnet build --configuration Release --nologo`, gdy w drzewie jest solution albo projekt.
  Ze źródła nie bierzemy zgadywania wersji SDK, gdy projektu nie towarzyszy `global.json`.
  Brak projektu i brak `global.json` w ogóle nie uruchamia kompilatora.
- [global.json](https://learn.microsoft.com/dotnet/core/tools/global-json). Wiążące jest
  wskazanie SDK, którego `dotnet` używa w katalogu repozytorium. Dotyczy decyzji, że job
  `build` pada, gdy projekt już jest, a `global.json` nie. Ze źródła nie bierzemy wyboru
  najnowszego SDK z obrazu runnera. Numer API, który dodaje pierwszy projekt, dodaje ten
  plik w tym samym scaleniu.
- [dotnet format](https://learn.microsoft.com/dotnet/core/tools/dotnet-format). Wiążące jest
  `--verify-no-changes`, które kończy się błędem, gdy formatowanie zmieniłoby plik. Dotyczy
  joba `format` przy `*.csproj` i `.editorconfig`, z `--severity info`. Ze źródła nie
  bierzemy zapisu zmian w runnerze. Bramka tylko sprawdza, a brak projektów i brak
  `package.json` daje kod `0`.
- [NBomber](https://nbomber.com/). Wiążące jest narzędzie testu obciążenia, które ten numer
  rezerwuje pod cechę `Category=Performance`. Dotyczy joba `performance` wymaganego na
  `main` i niewymaganego na `develop`. Ze źródła nie bierzemy uruchomienia obciążenia na
  każdym szkicu. Pakietu nie ma w repozytorium, dopóki nie ma projektu testowego.
- [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0). Wiążący jest tekst
  licencji, na której wolno wziąć NBomber do joba `performance`. Dotyczy zdania, że licencja
  używana w tym jobie to Apache 2.0. Ze źródła nie bierzemy innej licencji narzędzia
  obciążenia jako zamiennika. Dopóki nie ma projektu testowego, pakiet nie wchodzi do
  `Directory.Packages.props`.
- [xUnit](https://xunit.net/). Wiążące jest oznaczenie metody atrybutem `[Fact]` i cecha,
  której filtr `dotnet test` szuka. Dotyczy trzech pięter oraz tego, że test bez cechy
  integracyjnej i wydajnościowej należy do `unit-tests`. Ze źródła nie bierzemy osobnego
  runnera poza `dotnet test`. Jeden czerwony fakt w filtrze jest porażką joba.
- [Checkout](https://github.com/actions/checkout). Wiążące jest
  `persist-credentials: false`, które nie zostawia tokenu w katalogu po checkoutcie. Dotyczy
  pięciu workflowów tego numeru. Ze źródła nie bierzemy domyślnego zostawienia poświadczeń.
  Joby nie wypychają commitów i nie czytają sekretów.
- [actionlint](https://github.com/rhysd/actionlint). Wiążące jest lokalne sprawdzenie
  składni pięciu workflowów. Dotyczy polecenia `actionlint` z oczekiwanym kodem `0`. Ze
  źródła nie bierzemy werdyktu `actionlint` jako mapy komponentów. Mapę sprawdza suchy
  przebieg `affected-components.sh`, a zakaz `self-hosted` i `paths:` sprawdza `grep`.

## Gotowe gdy

- Pięć workflowów i dwa skrypty są w ścieżkach z tabeli.
- `actionlint` na tych workflowach kończy się kodem `0`.
- `grep` nie znajduje `self-hosted`, `paths:` ani `pull_request_target`, więc kończy się
  kodem `1`.
- Suchy przebieg mapy dla ścieżki News zwraca `news` i nie zwraca `identity`.
- Suchy przebieg samego pliku w `docs/cicd` zwraca pustą listę i kod `0`.
- Suchy przebieg samego kernela, bez `ProjectReference`, zwraca `kernel` równe `true`, pustą
  listę komponentów i kod `0`.
- `require-material.sh --job build` w drzewie bez `csproj` kończy się kodem `0` i linią
  `no material for build`.
- `check-branch-name.sh` dla `feature/lesson_markdown` nadal kończy się kodem `1`.
- W `develop.json` są `build`, `unit-tests` i `format` dopiero w scaleniu, które dodaje
  odpowiadające im workflowy, i `gh api` po syncu pokazuje te same nazwy.
- Filtr w `unit-tests.yml` jest dokładnie `Category!=Integration&Category!=Performance`.
- W pięciu workflowach `runs-on` to `ubuntu-latest`, a `timeout-minutes` to `20` albo `30`
  według joba.
