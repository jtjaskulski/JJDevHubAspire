# 01. Gałęzie

Ten numer jest pierwszy w produkcie. Poprzedniego kroku nie ma. Następny,
[Bramki](02-bramki.md), dokłada kompilację, format i trzy piętra testów. Tutaj powstają
reguły trzech długich gałęzi oraz joby `branch-name` i `pr-title`. Po nich repozytorium
odrzuca gałąź spoza ustalonego kształtu i tytuł pull requestu, który nie jest jedną linią
Conventional Commits. Kompilacji, testu i skanu ten numer nie dodaje. Te checki opisują
[02-bramki.md](02-bramki.md) oraz numery `03`–`07`. Słownik nazw jest w
[README.md](README.md).

Scenariusz, który bez tej ramy się rozpada, zaczyna się od lekcji w Learning i od rewizji
artykułu w News. Osoba dopisuje markdown lekcji na gałęzi `feature/lesson-markdown`,
wyciętej z `develop`. Osobny pull request News niesie tytuł
`feat(news): publish article revision`. Squash zapisuje ten tytuł jako commit na `develop`.
Numer [07-wersje.md](07-wersje.md) czyta taką linię, podbija `versions/news.json` i dopiero
na `main` wycina tag w postaci `news-v…`. Nazwa gałęzi i tytuł są sygnałem, który ten numer
zostawia numerowi wersji. Katalogu `src/services/News` jeszcze nie ma. Sposób nazywania musi
być ustalony wcześniej, bo pierwszy dokument i pierwszy workflow też wchodzą przez te dwa
joby.

Zła nazwa psuje ten łańcuch, zanim powstanie pierwsza usługa. Gałąź
`feature/lesson_markdown` ma podkreślenie. Job `branch-name` kończy się kodem `1` i ruleset
nie pozwala scalić. Commit, z którego numer `07` wyciąłby tag, nie powstaje. Ta sama lekcja
zapisana jako `moja-galaz` albo wycięta z `main` zamiast z `develop` też nie dochodzi do
pliku wersji. Tytuł `Publish article revision`, bez typu i bez zakresu, zostałby commitem
squasha. release-please nie zobaczy w nim `feat(news)`. Plik `versions/news.json` zostanie
przy stanie początkowym. Tag `news-v1.4.0` nie powstanie, a [16-deploy.md](16-deploy.md) nie
dostanie obrazu do wgrania. `GET /versions` dalej pokaże stary numer, choć zdanie o rewizji
artykułu leży już w historii.

Drugi rozjazd jest w promocji. Pull request z głową `develop` i celem `main` pomija
`release`. Kod `1` w `branch-name` zatrzymuje go, zanim ktokolwiek policzy wersję. Tag na
`main` opisywałby wtedy zmianę, która nie widziała środkowej gałęzi. Squash promocji może
nazywać się `chore: promote to release`. Ten tytuł sam nie niesie `feat(news)`. Poszczególne
`feat` i `fix` żyją jako commity na `develop`, a pliki wersji niosą je dalej, gdy squash
promocji sklei kilka commitów w jeden. Ten numer pilnuje pary gałęzi i tytułu. Liczenie
wersji zostaje w numerze `07`.

Pliki do dodania są w sekcji [Klasy i ścieżki](#klasy-i-ścieżki). Żaden z nich nie jest w
tym opisie traktowany jako już obecny w drzewie. Plan mówi, co utworzyć. Pierwszy pull
request funkcji, także taki, który tylko dodaje dokument albo workflow, już przechodzi przez
`branch-name` i `pr-title`. Sam plik usługi nie jest do tego potrzebny.

## Po co

Jedna osoba prowadzi trzy długie gałęzie i wiele krótkich. `develop` zbiera codzienną pracę.
`release` jest miejscem, przez które zmiana przechodzi, zanim zbliży się do tagu. `main`
jest miejscem, na którym numer `07` wycina tag komponentu. Bez wspólnej nazwy historia
miesza funkcję, poprawkę i dokumentację. Squash na gałąź docelową zapisuje wtedy przypadkowy
tytuł. Późniejsze wydanie czyta ten tytuł jak listę zmian. Zły tytuł albo zła nazwa psuje
numer wersji, zanim powstanie katalog usługi.

Gałąź robocza wychodzi z `develop`. Prefiks mówi, jakiej pracy szukać, gdy ktoś za pół roku
czyta `feature/lesson-markdown` obok `fix/contact-form`. Lekcja Learning i poprawka
formularza Contact mają być rozróżnialne z samej nazwy, zanim ktokolwiek otworzy diff. Cel
takiej gałęzi jest jeden: `develop`. Wepchnięcie `feature/lesson-markdown` od razu na
`release` kończy się kodem `1`. Środkowa gałąź nie jest skrótem dla funkcji, która wygląda
na małą. Rewizja artykułu i tak ma zobaczyć bramkę z [02-bramki.md](02-bramki.md), zanim
plik wersji pojedzie dalej.

Na `release` wchodzi głowa `develop`. Na `main` wchodzi głowa `release`. Para `develop` →
`main` pomija test integracyjny, CodeQL i skan obrazu, które stoją na środku. Tag wycięty z
takiej pary opisywałby rewizję artykułu, która nie stała na `release`. Ancestry dokłada
drugi zamek. `merge-base` głowy roboczej z `origin/main` ma być przodkiem `origin/develop`.
Gałąź wycięta z `main` jako cicha poprawka, nawet z prefiksem `fix/`, pada tym samym kodem
`1`. Osobnej gałęzi `hotfix` ten numer nie wprowadza. Poprawka wraca na `main` tą samą drogą
co funkcja, tagiem komponentu.

Tytuł `feat` i `fix` niesie zakres. Lista jest zamknięta: `identity`, `news`, `learning`,
`cv`, `contact`, `gateway`, `web`, `mobile`, `infra`, `shared`.
`feat(news): publish article revision` wskazuje News. `feat(blog): publish article revision`
pada, bo `blog` nie jest zakresem i nie ma pliku `versions/blog.json`. Wielka litera w
`feat(News):` pada z tego samego powodu, dla którego tag jest `news-v1.4.0`. Bez zakresu w
`feat` numer `07` nie wie, który komponent podbić. Jeden commit znaczyłby wtedy „coś się
zmieniło w całym repozytorium”, a wdrożenie News ruszyłoby historię, która nie nazywa News.

`docs:` bez zakresu jest poprawne i nie podbija wersji. `docs(cicd):` pada, bo `cicd` nie ma
na liście. Opis bramek nie jest zmianą News. Gdyby taki zakres przeszedł, plik wersji usługi
mógłby drgnąć od poprawki zdania w `docs/`. Zakres `shared` oznacza `JJDevHub.Shared.Kernel`
i nie jest tagiem obrazu. Zakres `infra` nie tworzy tagu obrazu usługi. Oba wolno wpisać.
Numer, który liczy z nich podbicie, jest numerem `07`. Ten numer nie pozwala wpisać nazwy
spoza listy.

Scalenie squashem sprawia, że commit na gałęzi docelowej jest równy tytułowi pull requestu.
Drugiego opisu w osobnym polu nie ma. Treść commitów z gałęzi roboczej nie staje się
osobnymi commitami na `develop`. Numer `07` dostaje jedną linijkę na jedną zmianę wpuszczoną
na `develop`. Merge commit zostawiłby na długiej gałęzi drugi opis, inny niż tytuł, i
wydanie nie wiedziałoby, który czytać. Rebase z zachowaniem serii commitów z gałęzi roboczej
rozbiłby jedną rewizję artykułu na kilka linijek, z których tylko jedna miałaby zakres.

Przykład nazwy, która przechodzi: `feature/lesson-markdown`. Przykład nazwy, która pada:
`feature/lesson_markdown`. Przykład tytułu, który przechodzi:
`feat(news): publish article revision`. Reszta nazw i tytułów pada w jobie albo w zestawie
reguł. Cyfra w nazwie jest dozwolona, więc `feature/lesson-2` przechodzi. Podwójny myślnik w
`feature/lesson--markdown` pada. Pusta nazwa po prefiksie, `feature/`, pada. Prefiks
`bugfix/` pada. `release/1.0.0` pada, bo `release` jest długą gałęzią, a nie prefiksem
pracy.

Ten numer zamyka też lukę w samym przycisku scalenia. Wymagany check, którego żaden workflow
nie raportuje, blokuje każdy merge. JSON tego numeru wymienia więc tylko `branch-name` i
`pr-title`. Nazwę `build` dopisze numer `02` w tym samym scaleniu, w którym ląduje workflow
raportujący `build`. Wpisanie jej wcześniej zatrzymałoby także poprawkę samego rulesetu.
`required_approving_review_count` zostaje `0`. Produkt utrzymuje jedna osoba. Bramką jest
check. Czekanie na drugą recenzję zatrzymałoby pierwszy pull request z workflowem.

`strict_required_status_checks_policy` jest włączone. Gałąź w pull requeście jest aktualna
względem celu. Zielony `pr-title` z poprzedniego przebiegu nie wystarcza, gdy na `develop`
wszedł w międzyczasie inny squash. Inaczej rewizja artykułu scaliłaby się ze starym
werdyktem, a tytuł na gałęzi docelowej nie odpowiadałby temu, co ruleset ostatnio widział.
Po squashu `delete_branch_on_merge` kasuje gałąź roboczą. Chronione `develop`, `release` i
`main` zostają.

## Dlaczego ta technologia

### Trzy długie gałęzie

`develop` jest miejscem integracji codziennej pracy. Ląduje tu squash z
`feature/lesson-markdown` i squash z poprawki Contact. `release` jest miejscem testów
integracyjnych, CodeQL, SonarQube i skanu obrazu. `main` jest miejscem testu wydajności,
SBOM, atestacji i tagu. Podział bramek jest zapisany w [02-bramki.md](02-bramki.md). Ten
numer nie uruchamia tych jobów. Pilnuje kolejności: najpierw `develop`, potem `release`,
potem `main`. Na każdej z trzech gałęzi da się wtedy wymagać innego zestawu checków, bo
każda ma własny plik JSON.

Jedna długa gałąź z wydaniem z każdego commita odpadła. Test integracyjny i tag mieszałyby
się z niedokończoną funkcją. Rewizja `feat(news): publish article revision` dostałaby tag w
tym samym kroku, w którym jeszcze nie ma wyniku CodeQL. Nie byłoby gałęzi, na której widać,
że zmiana przeszła środek, a tagu jeszcze nie ma. `release` jest tą gałęzią. Bez niej numer
`07` wycinałby `news-v…` z commita, który nie stał na środku, a deploy wgrałby obraz opisany
tagiem sprzed bramki środkowej.

Osobna gałąź `hotfix` wycięta z `main` też odpadła. Poprawka wychodzi z `develop` jako
`fix/…`, przechodzi trzy bramki i wraca na `main` tagiem komponentu. Skrót obok trzech
bramek obchodziłby CodeQL i SonarQube. Ancestry w `check-branch-name.sh` łapie ten skrót
nawet wtedy, gdy nazwa jest poprawna, a wycięcie poszło z `main`. `merge-base` z
`origin/main` nie jest wtedy przodkiem `origin/develop`. Kod wyjścia to `1`. Tag poprawki
nie powstanie z historii, która pominęła `develop`, bo plik wersji aktualizuje się na
`develop`.

Koszt, który zostaje, jest tempem jednej osoby. Każda zmiana, która ma trafić na maszynę,
pokonuje dwa dodatkowe pull requesty: `develop` → `release` i `release` → `main`. To nie
jest narzut zespołu recenzentów. Recenzji nikt nie wymaga. Kosztem jest drugi i trzeci
przebieg checków oraz czekanie, aż środkowa gałąź będzie zielona, zanim powstanie tag. Przy
jednej osobie to tempo jest przyjęte. Ominięcie go skróciłoby drogę do `news-v1.4.0` i
zostawiłoby w tagu zmianę bez środkowej bramki.

Długie gałęzie `develop`, `release` i `main` nie muszą pasować do wyrażenia prefiksu. Są
dozwolone tylko jako głowa promocji. `develop` wchodzi na `release`. `release` wchodzi na
`main`. Głowa `develop` przy celu `develop` pada. Głowa `main` przy celu `develop` pada.
`main` nie jest gałęzią roboczą i nie służy do dopisywania lekcji. Promocja w drugą stronę,
z `release` z powrotem na `develop`, też pada. Kierunek jest jeden.

### Prefiks i kebab-case

Nazwa gałęzi roboczej pasuje do wyrażenia:

```text
^(feature|fix|docs|chore|ci|refactor|test)/[a-z0-9]+(-[a-z0-9]+)*$
```

Prefiks mówi, jakiej pracy szukać w historii. Siedem słów wystarcza, żeby oddzielić funkcję,
poprawkę, dokument, porządek, workflow, przebudowę i test. Kebab-case z małych liter da się
wpisać w adresie i w nazwie katalogu worktree. Cyfra jest dozwolona, więc `feature/lesson-2`
przechodzi. Podwójny myślnik, podkreślenie, spacja, wielka litera i ukośnik w środku nazwy
odpadają. `feature/lesson_markdown` jest wzorcem, który ma paść, choć diff lekcji może być
poprawny. Job nie ostrzega. Job kończy się kodem `1`.

Dowolny tekst odpadł. `moja-galaz` i `wip` nie mówią, czy w środku jest funkcja, poprawka,
czy notatka. Prefiks spoza listy też odpadł: `bugfix/`, `feature-` bez ukośnika,
`release/1.0`. `release` i `main` są długimi gałęziami, nie prefiksami pracy. Numer ticketa
jako jedyna nazwa odpadł, bo w repozytorium nie ma drugiego systemu biletów. Prefiks niesie
rodzaj zmiany. Sam numer z zewnętrznej tablicy nic by nie powiedział osobie, która czyta
`git log` po squashu i szuka, która linia dotyczy Learning.

Koszt zostaje przy nazwie, nie przy treści commita. Gałąź `feature/Lesson_Markdown` trzeba
przemianować, nawet gdy markdown lekcji jest dobry. Skrypt lokalny robi to tanio, zanim
otworzy się pull request. Zamiana nazwy po otwarciu powtarza job `branch-name`. Wielka
litera pada z tego samego powodu co wielka litera w zakresie tytułu: tagi i pliki wersji są
małymi literami, a adres gałęzi ma być taki sam na każdej maszynie. Spacja w nazwie
rozjechałaby się między cudzysłowem w powłoce a adresem w przeglądarce.

Wyrażenie nie opisuje trzech długich gałęzi. Te trzy nazwy są dozwolone osobną gałęzią
decyzji w skrypcie, zanim w ogóle dojdzie do porównania z wyrażeniem prefiksu. Dzięki temu
promocja `develop` → `release` nie musi udawać `chore/promote`. Głowa jest dokładnie
`develop`. Cel jest dokładnie `release`. Gałąź robocza, która tylko wygląda podobnie, na
przykład `develop-wip`, nie przechodzi ani jako długa gałąź, ani jako prefiks. Kod `1` jest
ten sam. Powód w logu ma mówić, która z decyzji padła, żeby nie szukać jej w wyrażeniu.

Job w CI nie dostaje `--skip-ancestry`. Suchy przebieg bez repozytorium gita pomija krok
przodków tylko z tym przełącznikiem. W runnerze pełna historia jest obecna, bo checkout
bierze `fetch-depth: 0`. Płytki klon z jednym commitem nie umie policzyć `merge-base`. Gałąź
wycięta z `main` wyglądałaby wtedy jak wycięta z `develop`, a tag poprawki powstałby z
historii, która obeszła środek. Błąd użycia, czyli brak `--head` albo `--base`, kończy się
kodem `2`. Kod `2` nie jest odmową nazwy. Jest odmową wywołania. Ruleset i tak nie zobaczy
sukcesu.

### Conventional Commits i zakres

Tytuł pull requestu jest jedną linią Conventional Commits. Typy, które skrypt zna, to
`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` i
`revert`. Lista jest zapisana w `check-pr-title.sh`, nie w zmiennej workflow. Suchy przebieg
lokalny widzi tę samą listę co job. Dopisanie typu w YAML, bez zmiany skryptu, nie
przeszłoby lokalnego polecenia i rozjechałoby werdykt.

`feat` i `fix` wymagają zakresu w nawiasie. Zakres jest jednym z dziesięciu: `identity`,
`news`, `learning`, `cv`, `contact`, `gateway`, `web`, `mobile`, `infra`, `shared`. Przy
pozostałych typach zakres może wystąpić. Gdy występuje, jest z tej samej listy.
`docs: opis bramek` jest poprawne. `docs(cicd): opis bramek` pada, bo `cicd` nie jest
zakresem. `feat(news):` bez opisu pada. `feat:` bez nawiasu pada, nawet gdy opis jest pełnym
zdaniem o rewizji artykułu. To jest właśnie luka, która zostawia `versions/news.json` bez
ruchu.

Opis po dwukropku zaczyna się małą literą albo cyfrą, ma co najmniej trzy znaki, nie kończy
się kropką i jest oddzielony od dwukropka dokładnie jedną spacją. Cały tytuł ma co najwyżej
120 znaków. `feat(news): Publish article revision` pada przez wielką literę opisu.
`feat(news): publish article revision.` pada przez kropkę na końcu. Dwie spacje po dwukropku
padają tak samo jak brak spacji. `!` przed dwukropkiem jest dozwolone i oznacza zmianę
łamiącą, na przykład `feat(news)!: publish article revision`. Znaczenie wykrzyknika dla
numeru wersji jest w [07-wersje.md](07-wersje.md). Ten skrypt tylko przepuszcza znak.
`revert:` przyjmuje po sobie drugi, poprawny tytuł, na przykład
`revert: feat(news): publish article revision`.

Dowolne zdanie w tytule odpadło. Po squashu stałoby się jedyną linijką, którą widzi numer
`07`, i nie niosłoby typu ani zakresu. Gitmoji jako jedyny sygnał odpadło z tego samego
powodu: obrazek nie jest zakresem `news` i nie wybierze pliku `versions/news.json`. Zakres
pisany wielką literą odpadł, bo pliki wersji i tagi są małymi literami. `feat(News):` nie
złoży się z ścieżką `src/services/News` w sposób, którego oczekuje manifest wersji. Mała
litera zakresu jest częścią kontraktu z numerem `07`, nie ozdobą tytułu.

Koszt zostaje przy układaniu tytułu, zanim otworzy się pull request. Skrypt lokalny robi to
tanio i bez runnera. Zamiana tytułu w interfejsie powtarza job `pr-title`. To jest celowe:
tytuł jest treścią commita na gałęzi docelowej, więc zmiana tytułu jest zmianą przyszłego
`git log`. Opis krótszy niż trzy znaki pada, żeby `feat(news): x` nie udawał rewizji
artykułu. Limit 120 znaków trzyma linię w narzędziu, które pokazuje tytuł pull requestu obok
nazwy checka.

Zakres `shared` oznacza `JJDevHub.Shared.Kernel` i nie jest ósmym tagiem obrazu. Zakres
`infra` nie tworzy tagu obrazu usługi. Numery wersji z tych dwóch zakresów liczy
[07-wersje.md](07-wersje.md). Ten numer tylko nie pozwala wpisać zakresu spoza listy. Dzięki
temu `feat(shared):` nie zostanie pomylone z `feat(news):`, a zmiana kernela nie dostanie
nazwy komponentu, którego nie ma na liście tagów. Promocja `chore: promote to release`
zakresu nie potrzebuje. Poszczególne `feat` i `fix` zostały już zapisane na `develop`.

### Squash jako jedyne scalenie

Zestaw reguł na `develop`, `release` i `main` dopuszcza wyłącznie squash. Pole
`allowed_merge_methods` zawiera jedną wartość: `squash`. Commit na gałęzi docelowej dostaje
tytuł pull requestu. Treść commitów z gałęzi roboczej nie staje się osobnymi commitami na
`develop`. Dla rewizji artykułu znaczy to jedną linijkę
`feat(news): publish article revision` w historii, z której numer `07` umie odczytać zakres
`news`.

Merge commit odpadł. Na długiej gałęzi zostaje wtedy drugi opis, często domyślne „Merge pull
request”, inne niż tytuł. Wydanie nie wie, który tekst czytać. Rewizja artykułu miałaby w
historii i tytuł z zakresem, i drugi commit bez zakresu. release-please mogłoby przypisać
zmianę do złej linii albo do żadnej. Rebase z zachowaniem serii commitów z gałęzi roboczej
odpadł z tego samego powodu. [07-wersje.md](07-wersje.md) ma dostać jedną linijkę na jedną
zmianę wpuszczoną na `develop`. Seria „wip”, „poprawka”, „już naprawdę” z gałęzi roboczej
nie jest tą linijką.

Koszt, który zostaje, jest utratą drobnej historii wewnątrz gałęzi roboczej w momencie
scalenia. Gałąź roboczą wolno force-pushować, dopóki nie jest chroniona. Trzy długie gałęzie
force-pusha nie przyjmują. Reguła `non_fast_forward` jest włączona na każdej z nich.
Przepisanie `develop` zepsułoby commity, z których numer `07` już policzył pliki wersji.
Reguła `deletion` jest włączona z tego samego powodu: skasowanie `develop` kasuje historię,
na której stoją wersje. Gałąź robocza po squashu znika osobnym ustawieniem repozytorium, nie
przez zdjęcie ochrony z długiej gałęzi.

Pull request promocji, `develop` → `release` oraz `release` → `main`, też jest squashem.
Jego tytuł nadal musi przejść `pr-title`. Może to być `chore: promote to release`, bez
zakresu. Poszczególne `feat` i `fix` żyją jako commity na `develop`. Pliki wersji niosą je
dalej, gdy squash promocji sklei kilka commitów w jeden. To jest opisane w
[07-wersje.md](07-wersje.md) i nie jest liczone w tym numerze. Gdyby promocja szła merge
commitem, na `main` zostałaby para opisów, a job tagu nie wiedziałby, czy czytać tytuł
promocji, czy tytuły schowane w rodzicach commita.

Jedna metoda na trzech gałęziach jest też warunkiem syncu. Trzy pliki JSON mają to samo
ograniczenie metody. Suchy przebieg `jq` sprawdza, że `allowed_merge_methods` jest równe
liście z jednym elementem `squash`. Rozjazd jednego pliku, na przykład zostawienie `merge`
na `main`, wpuściłby na tag historię o innym kształcie niż historia na `develop`. Numer `07`
czyta obie. Różna metoda scalenia na końcu drogi unieważnia umowę „jedna linijka, jeden
zakres”.

### Ruleset w gitcie

Źródłem prawdy są pliki JSON w `.github/rulesets`. Sync woła API GitHuba z lokalnego `gh`
osoby z uprawnieniem administracyjnym. Samo wyklikanie reguły w ustawieniach repozytorium
nie jest wdrożeniem tego numeru. Po miesiącu interfejs może pokazywać inny zestaw checków
niż diff, który został przejrzany. Kolejny pull request dokumentacji nie pokaże tej różnicy.
Plik w gitcie pokazuje ją przy każdym `git diff`.

Wyłącznie klasyczna ochrona gałęzi trzymana w interfejsie odpadła. Nie ma jej w diffie, więc
pull request nie pokazuje, że wymagany check się zmienił. Trzymanie reguł tylko w prozie
tego pliku, bez JSON, też odpadło. Job nie umie zdiffować zdania. `schema.json` jest
wycinkiem pól, którego pilnuje suchy przebieg `jq`. Brak `squash` albo brak nazwy checka
widać lokalnie, zanim ktokolwiek uruchomi sync. Pełnego schematu wszystkich możliwych reguł
GitHuba ten wycinek nie kopiuje. Kopiuje pola, które ten numer ustawia.

Koszt zostaje przy syncu na maszynie osoby z uprawnieniem admina. Po zmianie JSON trzeba
uruchomić `sync-rulesets.sh` lokalnie. Job CI nie woła API reguł, bo token administracyjny
musiałby wejść do workflow. [06-lancuch-dostaw.md](06-lancuch-dostaw.md) tego zabrania. CI
sprawdza składnię JSON i obecność plików. Skrypt nie drukuje tokenu, nie czyta plików `.env`
i nie przyjmuje wartości sekretu argumentem. Błąd API kończy się kodem `1`. Do czasu syncu
pliki w gitcie są źródłem, które następny sync wgra. `gh api repos/{owner}/{repo}/rulesets`
po syncu ma pokazać te same nazwy checków i te same trzy gałęzie.

Wymagany check, którego żaden workflow nie raportuje, blokuje każdy merge. Nazwę checka
dopisuje się do JSON w tym samym scaleniu, w którym ląduje workflow raportujący tę nazwę. W
tym numerze są to `branch-name` i `pr-title`. Resztę dopisują numery `02`–`07`, każdy swoje
nazwy razem ze swoim workflow. Wpisanie `codeql` albo `build` w tym numerze zatrzymałoby
scalenie samego rulesetu. Nazwa joba w workflow, pole `name` oraz identyfikator, jeśli jest
ustawiony osobno, ma być dokładnie tekstem z JSON. Ruleset porównuje ten tekst, nie opis
kroku.

Liczba wymaganych recenzji zostaje `0`. Produkt utrzymuje jedna osoba. Bramką jest check,
nie druga para oczu. Włączenie recenzji „na zapas” zablokowałoby każdy squash, łącznie z
promocją `chore: promote to release`, bo nie ma kto zatwierdzić.
`strict_required_status_checks_policy` zostaje włączone obok tej liczby. Świeżość gałęzi
względem celu jest osobnym warunkiem od liczby recenzji. Stary zielony przebieg `pr-title`
nie zastępuje przebiegu na aktualnej głowie.

Ustawienie repozytorium `delete_branch_on_merge` ustawia ten sam skrypt sync na `true`.
Osobnego kliknięcia w ustawieniach nie zostawia się jako jedynego śladu. Chronione
`develop`, `release` i `main` GitHub i tak zostawia, bo reguła `deletion` jest włączona.
Kasowana jest gałąź robocza po squashu, na przykład `feature/lesson-markdown`. Zostawienie
jej po scaleniu myli następną próbę tej samej nazwy z historią, która już weszła do pliku
wersji. Force-push tej gałęzi przed scaleniem jest dozwolony. Po scaleniu gałąź znika i nie
ma czego przepisywać.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/branch-name.yml` | workflow joba `branch-name` |
| `.github/workflows/pr-title.yml` | workflow joba `pr-title` |
| `.github/scripts/check-branch-name.sh` | reguła nazwy i pary głowa/cel |
| `.github/scripts/check-pr-title.sh` | reguła Conventional Commits |
| `.github/rulesets/develop.json` | ochrona `develop` |
| `.github/rulesets/release.json` | ochrona `release` |
| `.github/rulesets/main.json` | ochrona `main` |
| `.github/scripts/sync-rulesets.sh` | wysłanie JSON do API, tylko lokalnie |
| `.github/rulesets/schema.json` | wycinek pól, którego pilnuje suchy przebieg |

Workflow nasłuchuje `pull_request` na `develop`, `release` i `main`. Nie używa `paths`. Nie
używa `pull_request_target`. `permissions` na poziomie pliku to puste, a job dostaje
`contents: read`. `runs-on` to `ubuntu-latest`. Checkout gałęzi dla `branch-name` bierze
`fetch-depth: 0`, bo skrypt porównuje przodków z `develop` i `main`. Pull request, który
dotyka tylko `docs/`, i tak uruchamia oba joby. Filtr ścieżek zostawiłby wymagany check w
stanie oczekiwania i zablokował scalenie dokumentu o bramkach.

Job `pr-title` czyta `github.event.pull_request.title`. Nie potrzebuje pełnej historii.
Zmiana tytułu w interfejsie uruchamia go ponownie na tym samym diffie kodu. Dzięki temu
poprawka `feat(news): publish article revision` po odrzuceniu
`feat: publish article revision` nie wymaga nowego commita w plikach, ale wymaga nowego
werdyktu checka. Ruleset czyta ten werdykt, nie treść opisu pull requestu pod tytułem. Opis
pod tytułem nie jest drugą linią Conventional Commits i numer `07` go nie czyta.

`sync-rulesets.sh` czyta trzy pliki JSON, szuka rulesetu o tej samej nazwie i woła `POST`
albo `PUT` na `/repos/{owner}/{repo}/rulesets`. Nazwa szukana w API jest nazwą pliku bez
rozszerzenia: `develop`, `release`, `main`. Uruchamia go osoba zalogowana w `gh`. W workflow
tego wywołania nie ma. Przed wysłaniem skrypt sprawdza `jq` i `gh auth status`. Gdy API
zwróci błąd, kończy się kodem `1` i nie drukuje tokenu.

Pola, które mają być w każdym z trzech JSON:

| Pole | Wartość |
| --- | --- |
| `target` | `branch` |
| `enforcement` | `active` |
| `conditions.ref_name.include` | jedna gałąź: `refs/heads/develop`, `refs/heads/release` albo `refs/heads/main` |
| reguła `deletion` | włączona |
| reguła `non_fast_forward` | włączona |
| reguła `pull_request` | wymagany pull request, `allowed_merge_methods` równe wyłącznie `squash` |
| reguła `required_status_checks` | na starcie tego numeru: `branch-name` i `pr-title` |

`required_approving_review_count` jest `0`. `strict_required_status_checks_policy` jest
włączone. Gałąź w pull requeście jest aktualna względem celu, inaczej check z poprzedniego
przebiegu nie wystarcza. Jeden plik JSON obejmuje jedną długą gałąź. Wpisanie trzech nazw do
`include` w jednym pliku nałożyłoby ten sam zestaw checków na wszystkie głowy i zabrało
numerom `02`–`07` możliwość dokładania checków tylko na `release` albo tylko na `main`.

Akcje `uses` w obu workflowach są przypięte do pełnego SHA, z komentarzem tagu wersji obok.
Sam tag `@v4` odrzuci później job `action-pins` z
[06-lancuch-dostaw.md](06-lancuch-dostaw.md). Ten numer nie wdraża tamtego joba. Zostawia
pin w swoich dwóch plikach, żeby pierwszy workflow nie wszedł do historii z ruchomym tagiem.
Krok `run` woła skrypt i przekazuje argumenty. Logika nazwy i tytułu zostaje w skrypcie.
`actionlint` widzi wtedy krótkie `run`, a test lokalny nie potrzebuje runnera.

## Plan

### 1. Dodać skrypt nazwy

Utwórz `.github/scripts/check-branch-name.sh`. Skrypt przyjmuje `--head` i `--base`. W jobie
wartości pochodzą z `github.head_ref` i `github.base_ref`. Lokalnie da się je podać ręcznie.
Wyrażenie prefiksu jest w skrypcie, takie samo jak w sekcji o kebab-case.

Kolejność decyzji:

1. Cel spoza `develop`, `release`, `main` kończy się kodem `1`.
2. Gdy głowa pasuje do prefiksu, cel musi być `develop`. Inny cel kończy się kodem `1`.
3. Gdy głowa to `develop`, cel musi być `release`.
4. Gdy głowa to `release`, cel musi być `main`.
5. Gdy głowa to `main` albo cokolwiek innego, kod `1`.
6. Dla gałęzi roboczej skrypt liczy `merge-base` głowy z `origin/main`. Ten commit ma być
   przodkiem `origin/develop`. Inaczej kod `1`.

Brak repozytorium gita w suchym przebiegu pomija krok 6, gdy podano `--skip-ancestry`. Job w
CI tego przełącznika nie dostaje. Błąd użycia, czyli brak argumentu, kończy się kodem `2`.
`feature/lesson-markdown` przy celu `develop` ma dać kod `0`. `feature/lesson_markdown` przy
tym samym celu ma dać kod `1`.

### 2. Dodać skrypt tytułu

Utwórz `.github/scripts/check-pr-title.sh`. Przyjmuje `--title`. Typy i zakresy są zapisane
w skrypcie, nie w zmiennej workflow. `feat` i `fix` bez nawiasu z zakresem padają. Zakres
spoza listy pada. `!` przed dwukropkiem jest dozwolone. Skrypt przepuszcza wykrzyknik i nie
liczy wersji.

`feat(news): publish article revision` ma dać kod `0`. `feat: publish article revision` ma
dać kod `1`. `feat(blog): publish article revision` ma dać kod `1`.
`feat(news): Publish article revision` ma dać kod `1`. `docs: opis bramek` ma dać kod `0`.
`docs(cicd): opis bramek` ma dać kod `1`. `chore: promote to release` ma dać kod `0`.
`revert: feat(news): publish article revision` ma dać kod `0`.
`feat(news)!: publish article revision` ma dać kod `0`. Tytuł z kropką na końcu opisu ma dać
kod `1`.

### 3. Dodać dwa workflowy

Utwórz `branch-name.yml` i `pr-title.yml`. Nazwa joba, czyli `name` oraz identyfikator,
jeśli jest ustawiony osobno, to dokładnie `branch-name` i `pr-title`. Ruleset porównuje ten
tekst.

W kroku `run` jest wywołanie skryptu i nic poza przekazaniem argumentów. Logika zostaje w
skrypcie. Przypnij każdą akcję `uses` do pełnego SHA i dopisz komentarz z tagiem wersji.
Checkout w `branch-name.yml` ustawia `fetch-depth: 0`. `pr-title.yml` czyta tytuł ze
zdarzenia i pełnej historii nie bierze.

Wyzwalacz obu plików to `pull_request` z gałęziami `develop`, `release` i `main`. `runs-on`
to `ubuntu-latest`. `permissions` na pliku zostaw puste. Job dostaje `contents: read`. Nie
dodawaj `paths`. Nie dodawaj `pull_request_target`.

### 4. Dodać trzy JSON-y rulesetów

Utwórz `develop.json`, `release.json` i `main.json` polami z tabeli wyżej. W tym numerze
lista checków ma dwie nazwy: `branch-name`, `pr-title`. JSON rulesetu nie trzyma komentarzy.
Kolejne nazwy dopiszą następne numery w swoich scaleniach. Nie dopisuj `build` ani
`gitleaks`.

`required_approving_review_count` ustaw na `0`. `strict_required_status_checks_policy`
włącz. `allowed_merge_methods` ustaw na listę zawierającą wyłącznie `squash`. Reguły
`deletion` i `non_fast_forward` włącz. Każdy plik obejmuje jedną gałąź w
`conditions.ref_name.include`.

### 5. Dodać sync

Utwórz `sync-rulesets.sh`. Skrypt:

1. Sprawdza `jq` i `gh auth status`.
2. Dla każdego pliku pobiera rulesety repozytorium i szuka wpisu o `name` równym nazwie
   pliku bez rozszerzenia.
3. Wysyła treść pliku jako `POST` albo `PUT` na `/repos/{owner}/{repo}/rulesets`.
4. Kończy się kodem `1`, gdy API zwróci błąd.

Nie drukuje tokenu. Nie czyta plików `.env`. Nie przyjmuje wartości sekretu argumentem. Nie
wołaj tego skryptu z workflow.

### 6. Ustawić kasowanie gałęzi roboczej

W tym samym skrypcie ustaw `delete_branch_on_merge` na `true` przez API repozytorium.
Osobnego kliknięcia w ustawieniach nie zostawiaj jako jedynego śladu. Chronione `develop`,
`release` i `main` mają zostać. Kasowana jest gałąź robocza po squashu.

### 7. Spiąć kolejność z następnym numerem

Nie dopisuj jeszcze `build` ani `gitleaks` do JSON. Te joby jeszcze nie raportują.
[02-bramki.md](02-bramki.md) dopisze swoje nazwy razem ze swoimi workflowami. Po numerze
`07` lista w JSON zgadza się z tabelą w [README.md](README.md). Do tego czasu ruleset wymaga
tylko checków, które mają workflow w tym samym drzewie.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `check-branch-name.sh` | job `branch-name`, człowiek lokalnie | jedna implementacja reguły nazwy |
| `check-pr-title.sh` | job `pr-title`, człowiek lokalnie | jedna implementacja reguły tytułu |
| `branch-name.yml` | GitHub na pull request | raportuje check, którego wymaga ruleset |
| `pr-title.yml` | GitHub na pull request | to samo dla tytułu |
| `develop.json`, `release.json`, `main.json` | `sync-rulesets.sh` | ochrona gałęzi bez klikania |
| `sync-rulesets.sh` | osoba z uprawnieniem admina | przenosi JSON do GitHuba |
| `schema.json` | suchy przebieg `jq` | łapie brak `squash` albo brak nazwy checka |

Job nie woła drugiego joba. Ruleset woła oba przez wymaganie statusu. Skrypt sync nie
uczestniczy w pull requeście. Czerwony `branch-name` przy `feature/lesson_markdown`
zatrzymuje scalenie, zanim `pr-title` stanie się commitem, z którego numer `07` wyciąłby
tag.

## Testy

Zainstaluj `actionlint` i uruchom go na obu workflowach:

```bash
actionlint .github/workflows/branch-name.yml .github/workflows/pr-title.yml
```

Kod wyjścia `0` znaczy, że składnia workflow i przywołane programy w `run` nie mają błędu,
który `actionlint` umie zobaczyć. `actionlint` nie zna reguły biznesowej nazwy. Tę regułę
sprawdza suchy przebieg skryptu.

Suchy przebieg nazwy, bez sieci:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson-markdown --base develop --skip-ancestry
```

Oczekiwany kod `0`. Ta nazwa jest wzorcem gałęzi, na której wolno prowadzić lekcję Learning.
Po squashu tytuł z zakresem może stać się commitem, który numer `07` umie przypisać do
komponentu.

Przykład, który ma paść. Podkreślenie nie jest kebab-case:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Oczekiwany kod `1`. Ta sama nazwa jako głowa pull requestu do `develop` kończy job
`branch-name` na czerwono i ruleset nie pozwala scalić. Powód padnięcia jest jeden:
podkreślenie w nazwie. Diff lekcji może być pusty albo gotowy. Werdykt i tak jest czerwony,
więc tag z numeru `07` nie powstanie z commita, którego nie ma.

Kolejne nazwy, które mają paść tym samym kodem:

| Głowa | Cel | Dlaczego |
| --- | --- | --- |
| `Feature/lesson-markdown` | `develop` | wielka litera |
| `feature/lesson-markdown` | `release` | gałąź robocza wchodzi tylko na `develop` |
| `bugfix/lesson-markdown` | `develop` | prefiks spoza listy |
| `feature/lesson--markdown` | `develop` | podwójny myślnik |
| `feature/` | `develop` | pusta nazwa po prefiksie |
| `develop` | `main` | pominięte `release` |
| `develop` | `develop` | długa gałąź nie jest swoją głową |
| `main` | `develop` | `main` nie jest gałęzią roboczą |
| `release/1.0.0` | `develop` | `release/` nie jest prefiksem pracy |

Każdy wiersz ma jeden powód. `develop` przy celu `main` pada, bo pomija `release`, i ten
jeden powód wystarcza, żeby nie liczyć wersji na `main`. `feature/lesson-markdown` przy celu
`release` pada, bo gałąź robocza wchodzi tylko na `develop`, nawet gdy tytuł
`feat(learning):` byłby poprawny.

Para, która przechodzi poza gałęzią roboczą:

```bash
.github/scripts/check-branch-name.sh --head develop --base release --skip-ancestry
.github/scripts/check-branch-name.sh --head release --base main --skip-ancestry
```

Oba kody `0`. To są dwie promocje. Ich tytuł nadal przechodzi przez `pr-title`. Typowym
tytułem jest `chore: promote to release`, bez zakresu.

Brak argumentów jest błędem użycia, nie odmową nazwy:

```bash
.github/scripts/check-branch-name.sh
echo $?
```

Oczekiwany kod `2`. Job w CI zawsze podaje `--head` i `--base`. Kod `2` na runnerze znaczy,
że workflow nie przekazał argumentów.

Suchy przebieg tytułu:

```bash
.github/scripts/check-pr-title.sh --title 'feat(news): publish article revision'
```

Kod `0`. Ta linia jest wzorcem, który po squashu na `develop` niesie zakres `news` do numeru
`07`.

```bash
.github/scripts/check-pr-title.sh --title 'feat: publish article revision'
.github/scripts/check-pr-title.sh --title 'feat(blog): publish article revision'
.github/scripts/check-pr-title.sh --title 'feat(news): Publish article revision'
```

Każde z trzech kończy się kodem `1`. Powody, po jednym na wywołanie: brak zakresu, zakres
spoza listy, wielka litera w opisie. Każdy z tych trzech zostawiłby `versions/news.json` bez
pewnego ruchu, gdyby stał się commitem squasha.

Kropka na końcu opisu pada osobno:

```bash
.github/scripts/check-pr-title.sh --title 'feat(news): publish article revision.'
echo $?
```

Kod `1`. Powód padnięcia jest jeden: opis kończy się kropką.

Tytuły, które mają przejść, bo specyfikacja je dopuszcza:

```bash
.github/scripts/check-pr-title.sh --title 'docs: opis bramek'
.github/scripts/check-pr-title.sh --title 'chore: promote to release'
.github/scripts/check-pr-title.sh --title 'feat(news)!: publish article revision'
.github/scripts/check-pr-title.sh --title 'revert: feat(news): publish article revision'
```

Każde kończy się kodem `0`. `docs(cicd): opis bramek` ma paść kodem `1`, bo `cicd` nie jest
zakresem:

```bash
.github/scripts/check-pr-title.sh --title 'docs(cicd): opis bramek'
echo $?
```

JSON rulesetu:

```bash
jq -e '.rules[] | select(.type=="pull_request") | .parameters.allowed_merge_methods == ["squash"]' \
  .github/rulesets/develop.json \
  .github/rulesets/release.json \
  .github/rulesets/main.json
```

Polecenie ma wypisać `true` trzy razy i skończyć się kodem `0`.

`actionlint` i oba skrypty da się odpalić, zanim ruleset zostanie zsynchronizowany. Sync
sprawdź na repozytorium testowym albo po wdrożeniu, poleceniem
`gh api repos/{owner}/{repo}/rulesets`, i porównaj `allowed_merge_methods` z plikiem. Job w
CI nie dostaje `--skip-ancestry`. Gałąź wycięta z `main` pada kodem `1` na kroku przodków,
także wtedy, gdy nazwa jest `feature/lesson-markdown`, a cel jest `develop`. Suchy przebieg
z przełącznikiem tego kroku nie wykonuje. To jest jeden powód padnięcia, osobny od
podkreślenia w nazwie.

## Zasady

- Gałąź robocza wychodzi z `develop`. Prefiks jest jednym z siedmiu: `feature`, `fix`,
  `docs`, `chore`, `ci`, `refactor`, `test`. Reszta nazwy jest kebab-case.
- `feature/lesson-markdown` przechodzi. `feature/lesson_markdown` pada kodem `1`.
- Na `release` wchodzi głowa `develop`. Na `main` wchodzi głowa `release`. Para `develop` →
  `main` pada.
- Tytuł jest jedną linią Conventional Commits. `feat` i `fix` mają zakres z listy dziesięciu
  nazw.
- Wzorzec tytułu, który przechodzi, to `feat(news): publish article revision`.
- Scalenie jest squashem. Merge commit i rebase nie są metodami tych trzech gałęzi.
- Wymagane checki tego numeru to `branch-name` i `pr-title`. Oba raportuje workflow na
  `ubuntu-latest`.
- Force-push długiej gałęzi jest wyłączony. Force-push gałęzi roboczej jest dozwolony.
- `required_approving_review_count` jest `0`. Recenzja drugiej osoby nie jest wymagana.
- `strict_required_status_checks_policy` jest włączone. Check z poprzedniego przebiegu nie
  wystarcza.
- Sync rulesetu zostaje na maszynie osoby z uprawnieniem admina. W YAML nie ma tokenu.
- `fetch-depth` joba `branch-name` jest `0`. Job nie używa `pull_request_target` ani
  `paths`.
- Nazwy checków z numerów `02`–`07` dochodzą razem z workflowami, które je raportują.
- Kod `1` jest odmową reguły. Kod `2` jest błędem użycia. Kod `0` jest zgodą.

## Poza zakresem

- Build, test, format i trzy bramki są w [02-bramki.md](02-bramki.md). Ten numer nie dodaje
  jobów `build`, `unit-tests` ani `format`.
- CodeQL jest w [03-codeql.md](03-codeql.md). Ten numer nie czyta SARIF i nie ustawia progu
  `security-severity`.
- Podatności, skan obrazu, SBOM i atestacja są w
  [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md). Ten numer nie woła Trivy ani Syft.
- SonarQube jest w [05-sonarqube.md](05-sonarqube.md). Ten numer nie stawia bramki jakości.
- gitleaks, zizmor, SHA akcji, Scorecard i zakaz sekretu w YAML są w
  [06-lancuch-dostaw.md](06-lancuch-dostaw.md). Ten numer nie woła API reguł z workflow.
- Tag i plik wersji z zakresu w tytule są w [07-wersje.md](07-wersje.md). Ten numer nie
  tworzy tagu `news-v1.4.0`. Przepuszcza tytuł, z którego numer `07` taki tag wytnie.
- Deploy tagu jest w [16-deploy.md](16-deploy.md). Ten numer nie stawia kontenera, nie woła
  skanera i nie czyta sekretu.

## Źródła

- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
  Wiążący jest ruleset jako obiekt w repozytorium, z celem `branch` i z wymuszeniem
  `active`. Dotyczy trzech plików JSON w `.github/rulesets` oraz tego, że wyklikanie reguły
  w ustawieniach nie jest wdrożeniem. Ze źródła nie bierzemy trzymania reguł wyłącznie w
  interfejsie. Diff pull requestu ma pokazać zmianę checka.
- [Available rules for rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
  Wiążące są reguły `pull_request`, `required_status_checks`, `deletion` i
  `non_fast_forward`. Dotyczy wyłącznego `squash`, listy `branch-name` i `pr-title`, zakazu
  kasowania długiej gałęzi i zakazu force-pusha. Ze źródła nie bierzemy wymaganej liczby
  recenzji większej niż zero. `required_approving_review_count` zostaje `0`.
- [REST: create a repository ruleset](https://docs.github.com/en/rest/repos/rules#create-a-repository-ruleset).
  Wiążące jest wywołanie `POST` na `/repos/{owner}/{repo}/rulesets`, gdy rulesetu o tej
  nazwie jeszcze nie ma. Dotyczy `sync-rulesets.sh` uruchamianego lokalnie przez osobę z
  uprawnieniem admina. Ze źródła nie bierzemy wołania tego endpointu z workflow. Token
  administracyjny nie wchodzi do YAML.
- [REST: update a repository ruleset](https://docs.github.com/en/rest/repos/rules#update-a-repository-ruleset).
  Wiążące jest wywołanie `PUT`, gdy ruleset o nazwie pliku już istnieje. Dotyczy drugiej
  ścieżki tego samego skryptu sync, po zmianie JSON w kolejnym scaleniu. Ze źródła nie
  bierzemy edycji reguły w interfejsie jako zamiennika `PUT`. Plik w gitcie zostaje treścią,
  którą skrypt wysyła.
- [REST: get repository rulesets](https://docs.github.com/en/rest/repos/rules#get-all-repository-rulesets).
  Wiążące jest pobranie listy rulesetów i porównanie pola `name` z nazwą pliku bez
  rozszerzenia. Dotyczy kroku syncu, który wybiera `POST` albo `PUT`, oraz sprawdzenia po
  syncu poleceniem `gh api repos/{owner}/{repo}/rulesets`. Ze źródła nie bierzemy
  traktowania odpowiedzi API jako źródła prawdy przed wysłaniem pliku. Źródłem jest JSON w
  repozytorium.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/). Wiążące są
  typ, zakres, `!` i opis po dwukropku. Dotyczy `check-pr-title.sh`, listy typów oraz
  obowiązku zakresu przy `feat` i `fix`. Ze źródła nie bierzemy stopki `BREAKING CHANGE`
  jako pola, które parsuje ten skrypt. Stopkę i numer wersji czyta numer `07`, a ten skrypt
  widzi jedną linię tytułu.
- [Workflow syntax, pull_request](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request).
  Wiążące są typy aktywności pull requestu oraz pola głowy i celu, z których job bierze
  `github.head_ref` i `github.base_ref`. Dotyczy wyzwalacza obu workflowów na `develop`,
  `release` i `main`. Ze źródła nie bierzemy filtra `paths` ani zdarzenia
  `pull_request_target`. Dokument w `docs/` ma dostać oba checki.
- [pull_request_target](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#pull_request_target).
  Wiążący jest opis zdarzenia, które wykonuje workflow w kontekście gałęzi docelowej i
  dostaje uprawnienia tej gałęzi. Dotyczy zakazu `pull_request_target` w `branch-name.yml` i
  w `pr-title.yml`. Ze źródła nie bierzemy tego zdarzenia jako sposobu na czytanie tytułu.
  Wystarcza `pull_request` z `contents: read`.
- [Workflow syntax for GitHub Actions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions).
  Wiążące są `on`, `jobs`, `runs-on` i nazwa joba. Dotyczy `ubuntu-latest`, nazwy checka
  równej `branch-name` albo `pr-title` oraz kroku `run`, który tylko woła skrypt. Ze źródła
  nie bierzemy `workflow_dispatch` jako wyzwalacza tych dwóch checków. Ruleset czyta status
  ze zdarzenia pull requestu.
- [Workflow permissions](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#permissions).
  Wiążące jest zawężenie tokenu przebiegu: puste uprawnienia na pliku i `contents: read` na
  jobie. Dotyczy obu workflowów tego numeru. Ze źródła nie bierzemy `contents: write` ani
  uprawnienia do rulesetów na jobie. Sync zostaje poza CI.
- [Require status checks before merging](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).
  Wiążące jest to, że wymagany check musi zaraportować sukces na aktualnej głowie. Dotyczy
  `branch-name`, `pr-title` i włączonego `strict_required_status_checks_policy`. Ze źródła
  nie bierzemy klasycznej ochrony gałęzi wyklikanej w ustawieniach ani wymaganej recenzji z
  tej samej strony. Źródłem jest JSON rulesetu.
- [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
  Wiążące jest to, że check ma przejść na najnowszym SHA, oraz że workflow pominięty filtrem
  ścieżek zostaje w stanie oczekiwania i blokuje scalenie. Dotyczy zakazu `paths` i wymogu
  świeżego przebiegu po aktualizacji gałęzi względem celu. Ze źródła nie bierzemy
  traktowania pominiętego joba jako wystarczającego sukcesu tych dwóch checków. Oba
  workflowy mają się wykonać.
- [Skipping workflow runs](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).
  Wiążące jest to, że instrukcja pominięcia w wiadomości commita zostawia wymagany check w
  stanie oczekiwania. Dotyczy tytułu squasha: `feat(news): publish article revision` nie
  dostaje dopisku, który wyłącza `branch-name`. Ze źródła nie bierzemy `[skip ci]` jako
  sposobu na promocję `develop` → `release`. Ruleset i tak czeka na oba statusy.
- [Managing the automatic deletion of branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-the-automatic-deletion-of-branches).
  Wiążące jest ustawienie kasowania głowy po scaleniu oraz to, że reguła repozytorium może
  zostawić gałąź chronioną. Dotyczy `delete_branch_on_merge` ustawianego przez
  `sync-rulesets.sh` oraz reguły `deletion` na `develop`, `release` i `main`. Ze źródła nie
  bierzemy samego kliknięcia w ustawieniach jako jedynego śladu. Po squashu znika
  `feature/lesson-markdown`, a trzy długie gałęzie zostają.
- [About pull request merges](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges).
  Wiążące jest to, że squash zapisuje na gałęzi docelowej jeden commit o tytule pull
  requestu. Dotyczy `allowed_merge_methods` równego wyłącznie `squash` na trzech długich
  gałęziach. Ze źródła nie bierzemy merge commita ani rebase jako drugiej dozwolonej metody.
  Numer `07` ma dostać jedną linijkę z zakresem.
- [Checkout action](https://github.com/actions/checkout). Wiążące jest `fetch-depth: 0`,
  które pobiera historię potrzebną do `merge-base`. Dotyczy checkoutu w jobie `branch-name`.
  Ze źródła nie bierzemy domyślnej płytkiej głębokości dla tego joba. Job `pr-title` pełnej
  historii nie potrzebuje, bo czyta tytuł ze zdarzenia.
- [GitHub context](https://docs.github.com/en/actions/learn-github-actions/contexts#github-context).
  Wiążące są pola zdarzenia dostępne w przebiegu, w tym tytuł pull requestu. Dotyczy kroku
  `pr-title`, który przekazuje `github.event.pull_request.title` do skryptu, oraz pary
  `head_ref` i `base_ref` w jobie nazwy. Ze źródła nie bierzemy opisu pull requestu pod
  tytułem jako drugiej linii do parsowania. Skrypt widzi jedną linię.
- [actionlint](https://github.com/rhysd/actionlint). Wiążące jest lokalne sprawdzenie
  składni workflow i odwołań w `run`. Dotyczy polecenia na `branch-name.yml` i
  `pr-title.yml`, z oczekiwanym kodem `0`. Ze źródła nie bierzemy werdyktu `actionlint` jako
  reguły nazwy gałęzi albo tytułu. Prefiks i Conventional Commits sprawdza suchy przebieg
  skryptu.

## Gotowe gdy

- W repozytorium są oba workflowy, oba skrypty, trzy JSON-y i `sync-rulesets.sh`.
- `actionlint` na obu workflowach kończy się kodem `0`.
- Suchy przebieg `feature/lesson-markdown` do `develop` kończy się kodem `0`.
- Suchy przebieg `feature/lesson_markdown` do `develop` kończy się kodem `1`.
- Suchy przebieg `develop` do `release` oraz `release` do `main` kończy się kodem `0`.
- Wywołanie `check-branch-name.sh` bez argumentów kończy się kodem `2`.
- Suchy przebieg `feat(news): publish article revision` kończy się kodem `0`, a
  `feat: publish article revision` kodem `1`.
- `docs(cicd): opis bramek` kończy się kodem `1`. `chore: promote to release` kończy się
  kodem `0`.
- `jq` potwierdza, że jedyną metodą scalenia w trzech JSON-ach jest `squash`, wypisuje
  `true` trzy razy i kończy się kodem `0`.
- Po syncu `gh api repos/{owner}/{repo}/rulesets` pokazuje te same dwie nazwy checków i te
  same trzy gałęzie. Do czasu syncu pliki w gitcie są źródłem, które następny sync wgra.
- W JSON tego numeru nie ma checków, których workflow jeszcze nie raportuje.
