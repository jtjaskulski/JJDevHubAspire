# 07. Wersje

[Spis CI/CD](README.md) · poprzedni: [06. Łańcuch dostaw](06-lancuch-dostaw.md) · następny:
[08. Proxmox](08-proxmox.md)

Ten numer dodaje osobny numer wersji każdego komponentu, zanim powstanie maszyna. Silnikiem
jest release-please w trybie manifest. Tagi mają postać `identity-vX.Y.Z` i `news-v1.4.0`.
Tag `news` nie przebudowuje pozostałych obrazów. Zmiana w `JJDevHub.Shared.Kernel` podbija
każdą usługę, która ma do niego `ProjectReference`. Pliki `versions/<komponent>.json` są
tym, co później odczyta web, telefon i `GET /versions`.

Stopka `web-vX.Y.Z` jest w [docs/frontend/02-web.md](../frontend/02-web.md). Ekran O
aplikacji z `mobile-vX.Y.Z` jest w [docs/frontend/06-mobile.md](../frontend/06-mobile.md).
Sam endpoint jest w [docs/api/16-gateway.md](../api/16-gateway.md). Ten numer nie rysuje
stopki i nie stawia YARP. Zostawia tag gita i plik wersji. Deploy tagu jest w
[16-deploy.md](16-deploy.md). Do tego czasu tag istnieje, a obrazu na maszynie nie ma. W
`versions.yml` nie ma `docker build` i nie ma wypchnięcia do rejestru.

Scenariusz, który bez tego numeru skleja osiem rzeczy w jedną, zaczyna się od jednego tagu
`v1.2.3` na całe repozytorium. Poprawka sluga w News i poprawka zapytania w Contact wchodzą
tą samą promocją. Deploy z numeru `16` widzi jeden tag i przebudowuje Identity,
Learning, Cv, bramę, web i telefon, choć ich drzewo nie drgnęło. Stopka weba pokazuje nowy
numer przy tej samej treści. Ekran O aplikacji w telefonie też. `GET /versions` nie umie
powiedzieć, który komponent naprawdę się zmienił. Osobny tag `news-v1.4.0` zostawia listę
„do zbudowania” przy News. Reszta zostaje przy swoim numerze.

Drugi scenariusz jest w tytule promocji. [01-galezie.md](01-galezie.md) wymusza zakres w
`feat` i `fix`, dopóki commity są osobne na `develop`. Promocja `develop` → `release` →
`main` ma jeden tytuł `chore: promote to release`. Ten tytuł sam nie niesie `feat(news)`.
Gdyby numer wersji liczyć z tytułu na `main`, News nie dostałoby podbicia albo dostałoby
je wszystko, co weszło tą promocją, jedną etykietą. Dlatego numer jedzie w pliku, który
release-please zaktualizował jeszcze na `develop`, póki osobne Conventional Commits były
widoczne. Job `release-tags` na pull request do `main` porównuje pliki wersji z tagami, a
nie z tytułem merge commita promocji.

Trzeci scenariusz jest przed katalogiem usługi. Manifest i `versions/*.json` wchodzą teraz,
ze stanem `0.0.0`. Diff dokumentacji nie umie dotknąć `src/services/News`, bo katalogu nie
ma, więc tag `news` nie powstaje z samego pliku dokumentacji. Wersja `0.0.0` znaczy „jeszcze
nie wydano” i nie dostaje tagu. Job `release-tags` przy tym istnieje i na pull request do
`main` jest wymagany. Pusty diff kończy się kodem `0` i logiem
`no material for release-tags`. Brak tagu nie jest brakiem checka.

Czwarty scenariusz jest w jądrze. Ktoś zmienia `JJDevHub.Shared.Kernel`, a pliki wersji
usług zostają. Pięć usług, które mają `ProjectReference` na kernel, zbudowałoby się ze
starym numerem i z nowym kodem wspólnym. Albo ktoś wiąże osiem komponentów wtyczką
`linked-versions` i zmiana News podnosi Identity do tego samego numeru. Wtyczka odpada.
Zakres `shared` nie jest ósmym tagiem. Oznacza kernel. Skrypt `kernel-dependents.sh`
wypisuje komponenty z grafu. Reszta zostaje.

## Po co

[01-galezie.md](01-galezie.md) wymusza zakres w `feat` i `fix`. Bez tego numeru zakres jest
tylko napisem. Dwa komponenty w jednym repozytorium dostałyby jeden tag `v1.2.3`, a
wdrożenie News przebudowałoby Identity. Telefon pokazałby nową wersję, choć
`src/clients/mobile` nie był w diffie. Bramka YARP dostałaby nowy numer przy zmianie
artykułu. Lista obrazów do zbudowania w numerze `16` nie miałaby z czego wybrać „tylko to,
co naprawdę doszło”.

Osobne wydanie znaczy:

- komponent ma własną wersję SemVer
- tag nazywa się `<komponent>-v<wersja>`
- na `main` powstaje tag tylko dla komponentu, którego wersja się zmieniła
- lista „do zbudowania” nie zawiera pozostałych

Komponenty: `identity`, `news`, `learning`, `cv`, `contact`, `gateway`, `web`, `mobile`.
Osiem nazw, osiem plików `versions/<komponent>.json`, osiem changelogów. Żadna z nich nie
jest tagiem `v1.4.0` bez prefiksu. Ruleset `tags.json` taki tag odrzuca. Tag `news-v1.4.0`
przy zmianie tylko Identity pada w jobie, zanim ktokolwiek go wypchnie.

Zakres `shared` nie jest ósmym tagiem. Oznacza kernel. Zakres `infra` nie wycina tagu
obrazu. Zmiana manifestu k3s, opisanego w numerze `08`, nie dostaje `infra-v1.0.0` i nie
udaje obrazu aplikacji. `docs`, `chore`, `ci`, `refactor`, `test`, `perf`, `build` i `style`
nie podbijają wersji, chyba że niosą `feat` albo `fix`. Refaktor widoczny dla klienta
zapisuje się jako `feat` albo `fix`, nie jako `refactor(news):`, jeśli ma zmienić numer.
Tytuł `feat: publish article revision` bez zakresu pada w `check-pr-title.sh` kodem `1` i do
`prepare-versions.sh` nie dochodzi jako poprawny `feat`.

Mechanizm działa przed katalogami usług. Pierwszy `feat` danego komponentu, który dotrze na
`develop` i potem na `main`, wytnie pierwszy tag. Zanim katalog `src/services/News`
istnieje, diff nie umie go dotknąć. Check `release-tags` jest wymagany na `develop`,
`release` i `main` i kończy się sukcesem, gdy nie ma czego tagować, z jawnym logiem. Na
`develop` wersję przygotowuje release-please pull requestem. Ten sam skrypt jest checkiem
także na pull request do `release`. Tag i tak powstaje później.

Tag powstaje na `push` do `main`, nie na `develop` i nie na pull requeście. Na `develop`
akcja ma `skip-github-release: true`. Otwiera pull request wydania i aktualizuje changelog
oraz pliki wersji. Nie wycina tagu. Pull request ma `permissions: contents: read`, więc z
widelca tag nie powstanie. `push` na `main` ma `contents: write` i tworzy brakujące tagi z
JSON. Używa `GITHUB_TOKEN` z `permissions`, nie sekretu z OpenBao. Wersja `0.0.0` nie
dostaje tagu. Obrazu ten plik nie buduje.

Web i telefon nie parsują tagu gita w przeglądarce. Czytają plik albo odpowiedź
`GET /versions`, która ten plik powtórzy z działającego obrazu. Ten numer pilnuje, żeby
wartość w pliku i tag na `main` były tą samą parą. Do czasu numeru `16` pary jeszcze nie ma
na maszynie. Jest w gitcie. Stopka i ekran O aplikacji dostaną ją stąd, nie z ręcznie
wpisanego ciągu w komponencie.

## Dlaczego ta technologia

### Manifest release-please

`release-please-config.json` i `.release-please-manifest.json` są w katalogu głównym
repozytorium. Tryb manifest znaczy, że akcja nie dostaje wejścia `release-type`.
Konfiguracja pakietów jest w pliku. Typ pakietu to `simple`. Pole `component` jest ustawione
jawnie, bo typ `simple` sam nie wymyśla nazwy. Domyślny tag w tym trybie to
`<component>-v<wersja>`, czyli `news-v1.4.0`. `include-component-in-tag` zostaje włączone.
Bez tego tag szukałby `v1.4.0` i zlałby osiem komponentów w jeden kształt, którego
`tags.json` i tak nie puszcza.

`separate-pull-requests` zostaje włączone. Podbicie News otwiera osobny pull request wydania
i nie niesie w tym samym tytule podbicia Identity. Tytuł wygląda jak
`chore(news): release 0.2.0`. To jest osobne scalenie, też squashem, z tytułem, który
`pr-title` przepuszcza. Bez tego pull requestu plik wersji na `develop` stoi, a job
`release-tags` na drodze do `main` pada. Jeden wspólny pull request wydania na osiem
komponentów zlałby w tytule rzeczy, które mają zostać osobne.

Akcja `googleapis/release-please-action` jest przypięta do pełnego SHA z komentarzem wersji.
Na `push` do `develop` otwiera pull request wydania i aktualizuje changelog oraz pliki
wersji. Ma `skip-github-release: true` na tym wyzwalaczu: tag nie powstaje na `develop`. Tag
powstaje na `push` do `main`, gdy plik wersji na `main` nie ma jeszcze odpowiadającego tagu.
Do tego służy druga połowa `.github/workflows/versions.yml`. Job na pull request nazywa się
`release-tags`. Job na `push` do `main`, który tworzy tagi, może nazywać się `push-tags`.
Ruleset wymaga tylko `release-tags`. `push-tags` nie jest checkiem pull requestu. Działa po
merge commicie promocji na `main`.

`bump-minor-pre-major` jest `true`. `bump-patch-for-minor-pre-major` jest `false`.

| Commit | Wersja przed `1.0.0` | Wersja od `1.0.0` |
| --- | --- | --- |
| `fix` | patch | patch |
| `feat` | minor | minor |
| `feat!` albo stopka `BREAKING CHANGE:` | minor | major |

SemVer przed `1.0.0` nie ma osobnego numeru na złamanie kontraktu w tej konfiguracji. I
`feat`, i złamanie podbijają minor. `feat(news)!: replace slug` od `0.1.0` daje `0.2.0`, nie
`1.0.0`. Ten sam tytuł od `1.4.0` daje `2.0.0`. `fix(news): correct slug` od `1.4.0` daje
`1.4.1`. `feat(news): add slug` od `1.4.0` daje `1.5.0`. To jest koszt serii zerowej,
zapisany w konfiguracji, a nie niespodzianka w dniu pierwszego `!`. Wejście w `1.0.0` robi
się stopką `Release-As: 1.0.0` w pull requeście, świadomie. Ten numer nie ustawia `1.0.0` z
góry.

Odpada jeden tag `vX.Y.Z` na całe repozytorium. Deploy nie umiałby z niego wyciąć „tylko
News”. Odpada GitVersion i MinVer oparte o wysokość historii. Po squashu wysokość nie znaczy
„feat w News”. Odpada Nerdbank.GitVersioning z tego samego powodu. Liczba commitów między
promocjami nie jest mapą ośmiu komponentów. Odpada ręczny tag z laptopa. Ruleset tagów
pozwala tworzyć tagi pasujące do wzorca tylko aplikacji Actions.

Koszt: po scaleniu `feat` na `develop` dochodzi pull request wydania. To jest drugie
scalenie, nie ozdoba. Bez niego plik na `develop` stoi, a bramka na `main` nie ma z czego
wziąć nowego numeru. Akcja na `develop` potrzebuje `contents: write` i
`pull-requests: write`, żeby ten pull request otworzyć. Na pull requeście do `main` zostaje
`contents: read`. Te dwa uprawnienia nie są jednym jobem o jednym `permissions`.

### Osobne ścieżki zamiast `linked-versions`

Wtyczka `linked-versions` podbija całą grupę do jednego numeru, gdy drgnie dowolny członek.
Wtedy zmiana News podniosłaby Identity, Learning, Cv, Contact, bramę, web i telefon. Stopka
i ekran O aplikacji skłamałyby, że klient się zmienił. Lista tagów do zbudowania miałaby
osiem pozycji przy jednym diffie. Wtyczka odpada. W konfiguracji jej nie ma. Nie dokłada się
jej „żeby numery wyglądały równo”.

Każdy komponent ma własną ścieżkę w konfiguracji i własny wpis w manifeście. release-please
przypisuje commit do pakietu, którego ścieżki commit dotknął.

| Komponent | Ścieżka obserwowana przez release-please | Plik dla klientów |
| --- | --- | --- |
| `identity` | `src/services/Identity` | `versions/identity.json` |
| `news` | `src/services/News` | `versions/news.json` |
| `learning` | `src/services/Learning` | `versions/learning.json` |
| `cv` | `src/services/Cv` | `versions/cv.json` |
| `contact` | `src/services/Contact` | `versions/contact.json` |
| `gateway` | `src/gateway` | `versions/gateway.json` |
| `web` | `src/clients/web` | `versions/web.json` |
| `mobile` | `src/clients/mobile` | `versions/mobile.json` |

Dopóki katalogu nie ma, nie ma w nim commitów i nie ma tagu. Konfiguracja i tak wymienia
ścieżkę, żeby pierwszy projekt usługi nie wymyślał drugiej mapy. `extra-files` wskazują
`versions/<komponent>.json` i pole `$.version`. Manifest na start ma osiem ścieżek ze stanem
`0.0.0`. Changelog `versions/<komponent>.changelog.md` ma jedną linię tytułu, bez fikcyjnych
wydań. Fikcyjne `1.0.0` w changelogu wyglądałoby jak wydanie, którego tag nie ma prawa
powstać.

Promocja `develop` → `release` → `main` jest merge commitem o tytule
`chore: promote to release` albo `chore: promote to main`. Podbicie powstaje wcześniej, na
`develop`, z osobnych linijek `feat` i `fix`. Job na pull request do `main` nie czyta tytułu
promocji ani rodziców merge commita jako źródła podbicia. Czyta diff ścieżek, pliki JSON
i tagi. `release-tags-gate.sh` pada kodem `1`, gdy diff dotyka ścieżki komponentu, a
`versions/<komponent>.json` się nie zmienia i nie ma już tagu równego wersji w pliku. Pada,
gdy JSON się zmienia dla komponentu, którego ścieżki diff nie dotyka, a kernel tego nie
tłumaczy. Pada, gdy dwa komponenty dostałyby ten sam tag. Pada, gdy wersja w JSON nie jest
SemVer. Pada, gdy wersja maleje względem manifestu. Pusty diff dokumentacji daje kod `0` i
`no material for release-tags`.

Odpada ręczne edytowanie `versions/news.json` „żeby dogonić”, bez commita, który
release-please rozumie. Rozjazd łapie suchy przebieg. Odpada też podbicie Identity w drzewie
roboczym, gdy ścieżki wskazują tylko News. Taki stan, przekazany bramce argumentem
`--paths`, kończy się kodem `1`. Drugi stan, `--paths src/services/News` i JSON news bez
zmiany, przy tytule `feat(news): publish article revision`, też kończy się kodem `1`: News
powinno dostać podbicie, a go nie ma. Te dwa wywołania są fixture argumentów skryptu, nie
commitem na `main`.

Koszt: osiem plików trzeba utrzymać obok manifestu. `prepare-versions.sh` liczy następną
wersję z commitów Conventional Commits od ostatniego tagu komponentu, a gdy tagu nie ma, od
`0.0.0`, zasadami z tabeli. Nie tworzy tagu. Tag zostaje na `push` do `main`. Osoba przed
promocją może odpalić suchy przebieg i zobaczyć `0.2.0` albo `2.0.0`, zanim otworzy pull
request. Job na `main` nie poprawia plików sam.

### Graf kernela obok manifestu

release-please nie czyta `ProjectReference`. Skrypt `.github/scripts/kernel-dependents.sh`
wypisuje komponenty, których `csproj` wskazuje `src/shared/JJDevHub.Shared.Kernel`. Mapuje
katalog na nazwę: `Identity` na `identity` i dalej tak samo dla pozostałych usług. Pull
request, który zmienia kernel, ma w tym samym diffie podbicie plików wersji tych
komponentów. Inaczej `release-tags` pada. Gdy kernel się zmienia, a komponent z grafu nie ma
zmiany JSON, kod to `1`.

Gdy żaden projekt jeszcze nie wskazuje kernela, skrypt wypisuje pustą listę i sam diff
kernela nie wymyśla tagów. Brak plików `csproj` daje pustą listę i kod `0`. To jest stan
repozytorium w tym numerze, zanim powstaną usługi. Test suchego przebiegu na tym drzewie
właśnie to sprawdza. Pusta lista nie jest błędem. Jest uczciwym grafem.

Gdy pięć usług już ma referencję, jedna zmiana kernela podbija pięć plików i, po dojściu na
`main`, wycina pięć tagów. Gateway, web i mobile zostają na poprzedniej wersji, jeśli nie
mają tej referencji. Obraz z [16-deploy.md](16-deploy.md) powstanie tylko z tagu, który
naprawdę doszedł. Pięć tagów usług to pięć obrazów usług, nie obraz weba. Telefon nie
dostaje nowego `mobile-v`, bo ktoś poprawił typ w jądrze, którego projekt telefonu nie
referencjonuje.

Odpada dopisanie kernela do `linked-versions` razem z usługami. Numery przestałyby być
niezależne. Jedna poprawka w jądrze podniosłaby także komponenty spoza grafu, albo wszystkie
osiem do jednego numeru. Odpada ósmy komponent `shared` z własnym tagiem obrazu. Kernel nie
jest obrazem, który numer `16` wdraża obok News. Jest kodem w pięciu obrazach, każdy ze
swoim tagiem. Zakres `shared` w tytule commita mówi prepare-versions, które pliki podbić.
Nie mówi rulesetowi tagów, żeby powstał `shared-v1.4.0`.

Koszt: autor pull requestu kernela uruchamia `prepare-versions.sh`, który woła graf i
podbija pliki. Dla zakresu `shared` skrypt podbija każdy wypisany komponent o jeden krok
wynikający z typu commita (`fix` albo `feat` albo złamanie). Dla zakresu `infra` nie zmienia
JSON. Job na `main` nie poprawia plików sam, bo pull request ma
`permissions: contents: read`. Kto zapomni podbić pliki, dostaje czerwony `release-tags`,
zanim tag w ogóle powstanie. To jest tańsze niż pięć obrazów ze starym numerem i nowym
jądrem.

### Plik JSON jako kontrakt dla klientów

```json
{
  "component": "news",
  "version": "0.0.0"
}
```

Pole `component` zgadza się z nazwą pliku. Pole `version` zgadza się z manifestem i z
`version.txt` typu `simple` w ścieżce pakietu, gdy katalog już istnieje. Do tego czasu
źródłem dla klienta jest JSON w `versions/`. `version.txt` dochodzi razem z katalogiem
komponentu, w numerze, który ten katalog tworzy, i od tej chwili ma być równy JSON-owi. Job
pada, gdy te dwa zapisy się różnią. `prepare-versions.sh` pisze oba, gdy `version.txt` już
jest.

Web czyta `versions/web.json` do stopki. Telefon czyta `versions/mobile.json` do ekranu O
aplikacji. Bramka, gdy powstanie, powtórzy te pliki w `GET /versions` z działającego obrazu.
Przeglądarka nie woła `git tag`. Tag na `main` i pole `version` mają być tą samą parą,
inaczej stopka pokaże numer, którego obraz nie ma, albo obraz wstanie z tagu, którego stopka
nie zna. Przy `0.0.0` pary jeszcze nie ma i tag nie powstaje. Pierwszy prawdziwy numer, na
przykład `news-v0.2.0` po `feat` przed `1.0.0`, jest pierwszą parą.

`push-tags` tworzy tag wyłącznie, gdy JSON na `HEAD` ma wersję różną od `0.0.0` i tag o tej
nazwie nie istnieje, oraz gdy ten JSON zmienił się względem poprzedniego commita na `main`
albo wersja weszła tym commitem. Nie przebudowuje obrazu. Wypisuje listę nowych tagów do
podsumowania. [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md) i
[16-deploy.md](16-deploy.md) biorą tę listę, nie „wszystkie tagi w repozytorium”. Przy
zmianie tylko News lista `identity-v*` zostaje bez nowego tagu. To jest sprawdzenie „tag
news nie przebudowuje reszty”, jeszcze przed Dockerem: lista tagów utworzonych w tym
`push-tags` ma jeden element.

Odpada trzymanie numeru tylko w tytule pull requestu albo tylko w changelogu. Changelog jest
dla człowieka. JSON jest dla stopki, dla ekranu i dla joba. Sam changelog bez pola `version`
nie da się porównać z tagiem skryptem, który ma paść kodem `1` przy rozjeździe. Odpada też
parsowanie tagu w kliencie. Klient nie ma `.git` w obrazie przeglądarki. Ma plik, który ten
numer zostawia w repozytorium i który obraz kiedyś powtórzy.

Koszt: dwa miejsca (`versions/*.json` i `version.txt`) trzeba utrzymać równe, gdy katalog
komponentu już jest. Do tego czasu miejscem jest JSON i manifest. Osiem plików przy stanie
`0.0.0` wygląda jak szum. Jest mapą, którą pierwszy projekt usługi zastaje, zamiast wymyślać
własny numer w `appsettings`. Wzorzec tagu, który `tags.json` puszcza, to:

```text
^(identity|news|learning|cv|contact|gateway|web|mobile)-v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$
```

Tag `v1.0.0` bez prefiksu pada. Tag z zerami wiodącymi w segmencie, poza samym zerem, też
nie pasuje do wzorca. Aktor, który może utworzyć tag, to przebieg Actions. Człowiek z
laptopa nie.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `release-please-config.json` | pakiety, `bump-minor-pre-major`, osobne pull requesty |
| `.release-please-manifest.json` | ostatnia wydana wersja ścieżki, na start `0.0.0` |
| `versions/<komponent>.json` | wersja, którą odczyta klient i gateway |
| `versions/<komponent>.changelog.md` | changelog komponentu, aktualizowany przez release-please |
| `.github/workflows/versions.yml` | job `release-tags` oraz pchnięcie tagu na `main` |
| `.github/scripts/prepare-versions.sh` | wyliczenie następnej wersji i zapis plików |
| `.github/scripts/kernel-dependents.sh` | graf `ProjectReference` |
| `.github/scripts/release-tags-gate.sh` | porównanie diffu, plików i tagów |
| `.github/rulesets/develop.json`, `release.json`, `main.json` | check `release-tags` |
| `.github/rulesets/tags.json` | kto może utworzyć tag i jaki wzorzec |

`versions.yml` ma zdarzenia z tabeli.

| Zdarzenie | Uprawnienia | Co robi |
| --- | --- | --- |
| `pull_request` na `develop`, `release` i `main` | `contents: read` | job `release-tags`, suchy werdykt, bez tworzenia tagu |
| `push` na `develop` | `contents: write`, `pull-requests: write` | release-please otwiera pull request wydania, bez tagu |
| `push` na `main` | `contents: write` | tworzy brakujące tagi dla wersji z JSON |

`pull_request` nie dostaje `contents: write`. Tag z pull requestu widelca nie powstanie.
`runs-on` każdego joba to `ubuntu-latest`. `persist-credentials: false` na pull requeście.
Na `push`, który tworzy tag, checkout musi móc pchnąć tag. Używa `GITHUB_TOKEN` z
`permissions`, nie sekretu z OpenBao. W pliku nie ma `secrets.`, nie ma `self-hosted`, nie
ma `pull_request_target` i nie ma `docker build`.

`release-tags` jest w `develop.json`, `release.json` i `main.json`. `tags.json` dochodzi do
`sync-rulesets.sh` z numeru `01` w tym samym scaleniu. Wzorzec i aktor Actions są w tym
rulesecie. Job `release-tags` i tak pada, zanim tag zostanie wypchnięty, gdy para
komponent–wersja jest za szeroka albo za wąska.

Konfiguracja pakietu niesie `release-type: simple`, `component` równy nazwie,
`include-component-in-tag: true` oraz `extra-files` na `versions/<komponent>.json`. W
korzeniu konfiguracji są `bump-minor-pre-major: true`,
`bump-patch-for-minor-pre-major: false` i `separate-pull-requests: true`. Wtyczki
`linked-versions` nie ma.

## Plan

### 1. Dodać manifest i konfigurację

Utwórz oba pliki JSON. W manifeście osiem ścieżek ze stanem `0.0.0`. W konfiguracji
`bump-minor-pre-major: true`, `bump-patch-for-minor-pre-major: false`,
`separate-pull-requests: true`, dla każdego pakietu `release-type: simple`, `component`
równy nazwie, `include-component-in-tag: true` oraz `extra-files` na
`versions/<komponent>.json`.

Nie dodawaj wtyczki `linked-versions`.

### 2. Dodać osiem plików wersji i osiem changelogów

Utwórz `versions/identity.json` i pozostałe siedem, każde z `"version": "0.0.0"` i zgodnym
`component`. Utwórz pusty nagłówek changelogu `versions/<komponent>.changelog.md` z jedną
linią tytułu, bez fikcyjnych wydań.

### 3. Dodać graf kernela

Utwórz `kernel-dependents.sh`. Szuka `ProjectReference` zawierającego
`JJDevHub.Shared.Kernel`. Wypisuje komponenty według mapy katalogu (`Identity` → `identity`,
…). Brak plików `csproj` daje pustą listę i kod `0`.

### 4. Dodać przygotowanie wersji

Utwórz `prepare-versions.sh`. Liczy następną wersję z commitów Conventional Commits od
ostatniego tagu komponentu, a gdy tagu nie ma, od `0.0.0`, zasadami z tabeli. Dla zakresu
`shared` woła graf i podbija każdy wypisany komponent o jeden krok wynikający z typu commita
(`fix` albo `feat` albo złamanie). Dla zakresu `infra` nie zmienia JSON. Nie tworzy tagu.
Tag zostaje na `push` do `main`.

### 5. Dodać bramkę i workflow

Utwórz `release-tags-gate.sh` i `versions.yml` zdarzeniami z tabeli. Job na pull request
nazywa się `release-tags`. Job na `push` do `main`, który tworzy tagi, może nazywać się
`push-tags`. Ruleset wymaga tylko `release-tags`. `push-tags` nie jest checkiem pull
requestu: działa po merge commicie promocji na `main`.

`push-tags` tworzy tag wyłącznie, gdy JSON na `HEAD` ma wersję różną od `0.0.0` i tag o tej
nazwie nie istnieje, oraz gdy ten JSON zmienił się względem poprzedniego commita na `main`
albo wersja weszła tym commitem. Nie przebudowuje obrazu. Wypisuje listę nowych tagów do
podsumowania. [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md) i
[16-deploy.md](16-deploy.md) biorą tę listę, nie „wszystkie tagi w repozytorium”.

Na `push` do `develop` akcja release-please ma `skip-github-release: true`. Jest przypięta
do pełnego SHA z komentarzem wersji. Wejścia `release-type` na akcji nie ma.

### 6. Dopisać rulesety

W tym samym scaleniu dopisz `release-tags` do `develop.json`, `release.json` i `main.json`.
Utwórz `tags.json` i dołóż go do `sync-rulesets.sh` z numeru `01`. Na `develop` wersję
nadal przygotowuje release-please pull requestem, a zła nazwa gałęzi i tak pada w numerze
`01`. Werdykt „czy plik wersji pasuje do diffu” jest na trzech gałęziach. Tag powstaje
dopiero na `push` do `main`.

### 7. Nie budować obrazu

W `versions.yml` nie ma `docker build`. Nie ma wypchnięcia do rejestru. Jest tag i plik.
`runs-on` to `ubuntu-latest`. Na pull requeście `contents: read` i
`persist-credentials: false`. Na `push`, który tworzy tag, `contents: write`.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `release-please-config.json` | akcja na `push` do `develop` | zasady SemVer i ścieżki |
| `.release-please-manifest.json` | ta sama akcja | ostatnia wydana wersja |
| `versions/*.json` | klienci, później gateway, job `release-tags` | numer, który widać poza gitem |
| `prepare-versions.sh` | osoba przed promocją, test | ten sam wzór co akcja, lokalnie |
| `kernel-dependents.sh` | `prepare-versions.sh` i bramka | kernel podbija zależności, nie sąsiadów |
| `release-tags-gate.sh` | job `release-tags` | blokuje `main`, gdy tag byłby za szeroki albo za wąski |
| `versions.yml` | GitHub | check oraz prawdziwy tag po wejściu na `main` |
| `tags.json` | sync rulesetów | człowiek nie wypycha tagu z laptopa |

Pull request funkcji nie woła deployu. Tag na `main` czeka, aż [16-deploy.md](16-deploy.md)
będzie miał maszynę.

## Testy

`actionlint`:

```bash
actionlint .github/workflows/versions.yml
```

Kod `0`. W pliku jest `ubuntu-latest`, nie ma `self-hosted`, `pull_request_target` ani
`secrets.`.

Suchy przebieg grafu w drzewie bez `csproj`:

```bash
.github/scripts/kernel-dependents.sh
```

Pusta lista, kod `0`.

Suchy przebieg bramki na samych dokumentach, bez zmiany `versions/`:

```bash
.github/scripts/release-tags-gate.sh --base-ref origin/main --head-ref HEAD
```

Gdy diff nie dotyka ścieżek komponentów, kod `0` i `no material for release-tags`.

Przykład, który ma paść. Tymczasowy stan, bez commita do długiej gałęzi: plik
`versions/identity.json` podbity w drzewie roboczym, diff ścieżek ograniczony do
`src/services/News` przez argument `--paths`. Oczekiwany kod `1`, bo Identity dostałoby
wersję bez zmiany swojej ścieżki i bez kernela. Drugi przykład: `--paths src/services/News`
i JSON news bez zmiany, przy tytule `feat(news): publish article revision` przekazanym przez
`--title`. Kod `1`, bo News powinien dostać podbicie, a go nie ma.

Te dwa wywołania są w teście skryptu jako fixture argumentów, nie jako commit na `main`.

Zła gałąź, zanim wersja w ogóle jest liczona:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. `feature/lesson-markdown` do `develop` daje kod `0`. Tytuł
`feat(news): publish article revision` daje kod `0` w `check-pr-title.sh`. Tytuł
`feat: publish article revision` daje kod `1` i do `prepare-versions.sh` nie dochodzi jako
poprawny `feat` bez zakresu.

SemVer przed `1.0.0`, suchy przebieg `prepare-versions.sh` na fikcyjnym stanie `0.1.0` i
tytule `feat(news)!: replace slug`:

```bash
.github/scripts/prepare-versions.sh --dry-run --component news --from 0.1.0 --title 'feat(news)!: replace slug'
```

Wypisuje `0.2.0`, nie `1.0.0`. Ten sam tytuł przy `--from 1.4.0` wypisuje `2.0.0`.
`fix(news): correct slug` przy `--from 1.4.0` wypisuje `1.4.1`. `feat(news): add slug` przy
`--from 1.4.0` wypisuje `1.5.0`.

`jq` na ośmiu plikach:

```bash
for c in identity news learning cv contact gateway web mobile; do
  jq -e --arg c "$c" '.component == $c and .version == "0.0.0"' "versions/$c.json"
done
```

Osiem razy `true`, kod `0`.

Po pierwszym prawdziwym tagu na `main`:

```bash
git tag -l 'news-v*'
git tag -l 'identity-v*'
```

Przy zmianie tylko News lista identity zostaje bez nowego tagu. To jest sprawdzenie „tag
news nie przebudowuje reszty”, jeszcze przed Dockerem: lista tagów utworzonych w tym
`push-tags` ma jeden element.

Suchy przebieg da się zrobić przed katalogami usług. `jq` widzi osiem razy `0.0.0`. Graf
kernela jest pusty. Bramka na samych dokumentach mówi `no material for release-tags`.
Podbicia `0.2.0`, `2.0.0`, `1.4.1` i `1.5.0` widać w `--dry-run`, bez tagu i bez obrazu.

## Zasady

- Osiem komponentów wydaje się osobno. Manifest nie wiąże ich wtyczką `linked-versions`.
- Tag to `<komponent>-v<SemVer>`. Innego kształtu `tags.json` nie puszcza.
- Przed `1.0.0` złamanie podbija minor. Od `1.0.0` złamanie podbija major.
- `feat` podbija minor. `fix` podbija patch. Inne typy nie podbijają.
- Zakres `shared` podbija usługi z grafu `ProjectReference` na kernel, każdą o jej własny
  krok.
- Zakres `infra` nie tworzy tagu.
- Tag powstaje na `push` do `main`, nie na `develop` i nie na pull requeście.
- Na `develop` akcja ma `skip-github-release: true`.
- Check `release-tags` jest wymagany na `develop`, `release` i `main` i kończy się sukcesem,
  gdy nie ma czego tagować, z jawnym logiem.
- Job nie buduje obrazu.
- Plik `versions/<komponent>.json` jest źródłem dla stopki, ekranu O aplikacji i
  `GET /versions`.
- Wersja `0.0.0` znaczy „jeszcze nie wydano” i nie dostaje tagu.
- Workflow wersji idzie na `ubuntu-latest` i nie czyta sekretu aplikacji.
- Pull request ma `contents: read`. `push`, który tworzy tag albo pull request wydania, ma
  `contents: write`.
- `include-component-in-tag` zostaje włączone. `component` w typie `simple` jest jawny.
- Wejście w `1.0.0` jest stopką `Release-As: 1.0.0`, nie skutkiem ubocznym `feat!` przed
  jedynką.

## Poza zakresem

| Temat | Numer |
| --- | --- |
| Zakres w tytule i squash | [01-galezie.md](01-galezie.md) |
| To, że tag w ogóle jest checkiem bramki `main` | [02-bramki.md](02-bramki.md) |
| SBOM i atestacja obrazu, który kiedyś powstanie z tagu | [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md) |
| Pin akcji release-please | [06-lancuch-dostaw.md](06-lancuch-dostaw.md) |
| Stopka weba | [docs/frontend/02-web.md](../frontend/02-web.md) |
| Ekran O aplikacji | [docs/frontend/06-mobile.md](../frontend/06-mobile.md) |
| `GET /versions` | [docs/api/16-gateway.md](../api/16-gateway.md) |
| Maszyna | [08-proxmox.md](08-proxmox.md) |
| Deploy i rollback do poprzedniego tagu tego komponentu | [16-deploy.md](16-deploy.md) |

Ten numer nie rysuje stopki, nie stawia bramy i nie buduje obrazu. Nie opisuje schematu
bazy. Nie wybiera, który digest trafi do Deploymentu. Zostawia ósemkę plików, manifest i
tag, który `push-tags` wypisze na `main`, gdy wersja wyjdzie z `0.0.0`.

## Źródła

- [release-please](https://github.com/googleapis/release-please). Wiążący jest silnik, który
  z Conventional Commits otwiera pull request wydania i aktualizuje changelog oraz pliki
  wersji. Dotyczy manifestu w korzeniu i tego, że tag komponentu nie powstaje z wysokości
  historii. Ze źródła nie bierzemy jednego tagu `vX.Y.Z` na całe repozytorium. Nie bierzemy
  GitVersion, MinVer ani Nerdbank.GitVersioning. Po squashu wysokość nie znaczy „feat w
  News”.
- [Manifest
  releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md).
  Wiążące są tryb manifest, tag `<component>-v<wersja>`, `include-component-in-tag`,
  `bump-minor-pre-major`, `bump-patch-for-minor-pre-major`, `separate-pull-requests` i opis
  wtyczki `linked-versions`. Dotyczy `news-v1.4.0`, flag `true` i `false` przy serii przed
  `1.0.0` oraz osobnych pull requestów wydania. Ze źródła nie bierzemy `linked-versions`.
  Wtyczka zrównałaby numery komponentów, gdy drgnie jeden. Nie bierzemy
  `include-component-in-tag: false`, bo tag bez prefiksu zlałby ósemkę.
- [release-please-action](https://github.com/googleapis/release-please-action). Wiążące są
  wejścia akcji: w trybie manifest nie ustawia się `release-type`, a `skip-github-release`
  rozdziela pull request wydania od tagu. Dotyczy `skip-github-release: true` na `push` do
  `develop` i drugiej połowy `versions.yml`, która tnie tag na `push` do `main`. Ze źródła
  nie bierzemy przykładu z `secrets` i tokenem PAT. Ten workflow używa `GITHUB_TOKEN` z
  `permissions`. Nie bierzemy pływającego `@v4`. Akcja jest na pełnym SHA z komentarzem
  wersji. Typ `simple` stoi w pliku konfiguracji, nie jako wejście akcji.
- [SemVer](https://semver.org/lang/pl/). Wiążące są major, minor, patch i to, że seria
  `0.y.z` jest serią początkową. Dotyczy tabeli podbić oraz tego, że `feat!` przed `1.0.0`
  daje minor (`0.1.0` → `0.2.0`), a od `1.0.0` major (`1.4.0` → `2.0.0`). Ze źródła nie
  bierzemy automatycznego skoku do `1.0.0` przy pierwszym złamaniu. Wejście w `1.0.0` jest
  stopką `Release-As: 1.0.0`. Nie bierzemy wersji z zerami wiodącymi w segmencie, poza samym
  zerem. Wzorzec tagu ich nie puszcza.
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). Wiążące są `feat`,
  `fix`, `!` i stopka `BREAKING CHANGE:`. Dotyczy tego, że `feat` podbija minor, `fix`
  patch, a złamanie idzie według tabeli. Ze źródła nie bierzemy `docs`, `chore`, `ci`,
  `refactor`, `test`, `perf`, `build` ani `style` jako podbicia, chyba że commit niesie
  `feat` albo `fix`. Refaktor widoczny dla klienta zapisuje się jako `feat` albo `fix`.
  Tytuł `feat` bez zakresu nie dochodzi do prepare-versions jako poprawny `feat`.
- [Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
  Wiążące jest to, że ruleset dotyczy także tagów, nie tylko gałęzi. Dotyczy `tags.json` i
  checka `release-tags` w `develop.json`, `release.json` i `main.json`. Ze źródła nie
  bierzemy rulesetu, który pozwala człowiekowi wypchnąć tag z laptopa. Aktor tworzenia tagu
  to przebieg Actions. Ze źródła nie bierzemy wymagania `release-tags` wyłącznie na `main`.
- [Available rules for
  rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets).
  Wiążący jest wzorzec nazwy tagu i ograniczenie, kto może tag utworzyć. Dotyczy wyrażenia
  na osiem komponentów i SemVer oraz odrzucenia `v1.0.0` bez prefiksu. Ze źródła nie
  bierzemy wzorca `v*`, który przepuściłby jeden tag na całe repozytorium. Tag `news-v1.4.0`
  przy zmianie tylko Identity i tak pada wcześniej, w jobie, zanim ktokolwiek go wypchnie.
- [actionlint](https://github.com/rhysd/actionlint). Wiążąca jest składnia `versions.yml`.
  Dotyczy `actionlint .github/workflows/versions.yml` z kodem `0`. Ze źródła nie bierzemy
  actionlint jako sprawdzenia SemVer. Podbicia `0.2.0`, `2.0.0`, `1.4.1` i `1.5.0` liczy
  `prepare-versions.sh --dry-run`. W pliku workflow ma być `ubuntu-latest` i nie ma być
  `docker build` ani `secrets.`.

## Gotowe gdy

- Są oba pliki manifestu, osiem JSON-ów w `versions/`, osiem changelogów, trzy skrypty,
  `versions.yml` i `tags.json`.
- `actionlint .github/workflows/versions.yml` kończy się kodem `0`.
- `jq` pokazuje `0.0.0` i zgodny `component` w ośmiu plikach.
- `kernel-dependents.sh` bez `csproj` kończy się kodem `0` i pustą listą.
- `prepare-versions.sh --dry-run --component news --from 0.1.0 --title 'feat(news)!: replace slug'`
  wypisuje `0.2.0`.
- Ta sama zmiana od `1.4.0` wypisuje `2.0.0`.
- `fix` od `1.4.0` wypisuje `1.4.1`. `feat` od `1.4.0` wypisuje `1.5.0`.
- Bramka pada kodem `1`, gdy podbity jest Identity, a ścieżki wskazują tylko News.
- `feature/lesson_markdown` pada kodem `1` w `check-branch-name.sh`.
- `develop.json`, `release.json` i `main.json` wymagają `release-tags`.
- W `versions.yml` nie ma `docker build` ani `secrets.`.
- Nie ma wtyczki `linked-versions`. Tag ma postać `<komponent>-v<wersja>`, na przykład
  `news-v1.4.0`.
- Wersja `0.0.0` nie dostaje tagu. Tag powstaje na `push` do `main`.
- Na pull requeście uprawnienie to `contents: read`. Na `push` tworzący tag albo pull
  request wydania jest `contents: write`.
- Zakres `shared` idzie przez `kernel-dependents.sh` i `ProjectReference`, nie przez ósmy
  tag. Zakres `infra` tagu nie wycina.
