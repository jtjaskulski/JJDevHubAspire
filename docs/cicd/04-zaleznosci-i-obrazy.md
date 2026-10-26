# 04. Zależności i obrazy

Poprzedni numer, [CodeQL](03-codeql.md), czyta ścieżki w kodzie, który sami piszemy.
Następny, [SonarQube](05-sonarqube.md), stawia bramkę jakości. Ten numer dodaje cztery
checki: `dependency-vulnerabilities` na bramce `develop` oraz `image-scan`, `sbom` i
`attestations` dalej na ścieżce do `main`. Sekrety w diffie zostają w
[06-lancuch-dostaw.md](06-lancuch-dostaw.md). Wypchnięcie obrazu i deploy zostają w
[16-deploy.md](16-deploy.md). Skan obrazu, SBOM i atestacja mieszkają w jednym workflow,
`.github/workflows/artifacts.yml`. Zależności mieszkają osobno, w
`.github/workflows/dependencies.yml`, bo stoją na `develop` i nie potrzebują Dockera.

Scenariusz, który bez tej ramy się rozpada, ma zielony test i czerwoną paczkę. Pull request
News niesie `feat(news): publish article revision`. Test jednostkowy publikacji przechodzi.
CodeQL na promocji też przechodzi, bo dziura nie jest w przepływie naszego kodu. Jest w
pakiecie NuGet, często przechodnim, który
`dotnet list package --vulnerable --include-transitive` oznacza wagą `High` albo `Critical`.
Bez joba `dependency-vulnerabilities` squash wchodzi na `develop`. Numer
[07-wersje.md](07-wersje.md) może podbić `versions/news.json`, a tag `news-v…` opisze obraz,
w którym CVE już jest. Zielony test nie widzi bazy podatności. Widzi ją ten check, od
pierwszej bramki.

To samo dotyczy obrazu, gdy Dockerfile już jest. Warstwa systemu dokłada paczki, których nie
ma w `csproj`. Test jednostkowy ich nie uruchamia. Trivy na lokalnym tagu
`jjdevhub/news:scan` ma paść przy `HIGH` albo `CRITICAL`, także gdy poprawki jeszcze nie ma.
`--ignore-unfixed` zostaje wyłączone. Inaczej pierwsza podstawa obrazu wjechałaby na
`release` z wysokim CVE, a próg „podniesiemy później” zostałby na zawsze. Osobnego,
łagodniejszego progu na start nie ma.

Do dnia, w którym pojawi się lockfile albo Dockerfile, cztery joby kończą się sukcesem, bo
nie ma czego skanować, i raportują swoje nazwy tam, gdzie ruleset ich wymaga. Log brzmi
`no material for <job>`. Job nie jest skipped. Filtr `paths` na `on` jest zabroniony z tego
samego powodu co w [02-bramki.md](02-bramki.md). `feature/lesson_markdown` nadal pada kodem
`1` w numerze `01`, zanim ktokolwiek oceni paczkę. Na poprawnej gałęzi, przed pierwszym
lockfile, `dependency-vulnerabilities` jest zielony z powodu braku materiału, nie z powodu
wyłączonego checka.

## Po co

Pakiet NuGet albo npm może mieć znane CVE, choć kod produktu przechodzi test i CodeQL.
Obraz, gdy już jest, dokłada systemowe paczki podstawy. Bez wykazu składników i atestacji
numer [16-deploy.md](16-deploy.md) nie ma czego porównać z tagiem. Publikacja
`feat(news): publish article revision` może być poprawna w teście i jednocześnie wciągać
przechodnią paczkę o wadze `High`. Bramka na `develop` ma to zatrzymać, zanim plik wersji
ruszy. Bramka obrazu na `release` ma zatrzymać warstwę systemu, zanim tag w ogóle powstanie
na `main`.

Podział bramek:

| Check | Gdzie jest wymagany | Kiedy werdykt zaczyna wiązać |
| --- | --- | --- |
| `dependency-vulnerabilities` | `develop`, `release`, `main` | jest `*.csproj` albo lockfile npm |
| `image-scan` | `release`, `main` | w drzewie jest Dockerfile dotkniętego komponentu |
| `sbom` | `main` | ten sam warunek |
| `attestations` | `main` | ten sam warunek |

Pusty sukces jest jawny: log `no material for <job>`. Dla zależności linia brzmi
`no material for dependency-vulnerabilities`. Dla obrazu `no material for image-scan`,
`no material for sbom` i `no material for attestations`. Job nie jest skipped. Na `release`
joby `sbom` i `attestations` i tak się uruchamiają, logują brak swojej bramki z powodu
gałęzi i kończą się sukcesem. Ruleset `release` ich nie wymaga. Na `main` warunek puszcza
prawdziwy skan, gdy jest Dockerfile. Dzięki temu GitHub nie pokazuje ich jako skipped na
`release` w sposób, który miesza się z brakiem raportu.

Próg dla zależności i dla obrazu jest jeden: waga wysoka i krytyczna kończy job kodem `1`.
Średnia i niska zostają w logu. Dotyczy to także podatności bez poprawki. Nie ma osobnego
progu „na start łagodniej”. Fixture `.github/fixtures/vuln/packages-high.json` niesie jedną
paczkę wagi `High` w kształcie JSON z `dotnet list package --format json` i ma dać kod `1`.
Fixture `packages-none.json` nie niesie podatności i ma dać kod `0`. To są fixture bramki,
nie przywrócenie prawdziwej paczki. Czyta je `vuln-gate.sh --nuget-json`, bez sieci.

Numer jest przed usługami i przed Dockerfile. Pierwszy pull request funkcji na `develop` już
wymaga `dependency-vulnerabilities`. Na `release` już wymaga `image-scan`. Na `main` już
wymaga `sbom` i `attestations`. Wszystkie cztery są zielone, dopóki nie ma lockfile i
Dockerfile. Gdy `package.json` jest, a `package-lock.json` nie ma, job kończy się kodem `1`.
Drzewo nie jest powtarzalne, więc nie da się powiedzieć, co weszło. Sam `package.json` nie
wystarcza, żeby nazwać zielony audyt.

Zmiana jednego komponentu nie buduje obrazu pozostałych. Diff w News, przy Dockerfile tylko
w News, skanuje `jjdevhub/news:scan` i nie skanuje Identity. Diff tylko w `docs/` daje pustą
listę komponentów i pusty sukces `image-scan`, nawet gdy Identity już ma Dockerfile. To jest
ten sam podział per komponent co w numerze `02`. Check i tak jest zielony, więc ruleset
puszcza dokumentację. Gdyby filtr `paths` wyciął `docs/`, check zostałby w oczekiwaniu i
dokumentacja by nie weszła.

## Dlaczego ta technologia

### `dotnet list` i `npm audit` w jobie, nie tylko powiadomienie

Job `dependency-vulnerabilities` woła, gdy materiał istnieje,
`dotnet list package --vulnerable --include-transitive --format json` dla każdego projektu.
Dla npm woła `npm audit --audit-level=high` w katalogu, w którym jest `package-lock.json`.
Pada, gdy w JSON NuGet waga to `High` albo `Critical`, albo gdy `npm audit` zwróci kod inny
niż zero przy tym progu. Audyt npm obejmuje zależności produkcyjne i narzędziowe. Lockfile
jest wejściem. Skrypt `vuln-gate.sh` wypisuje identyfikator paczki i wagę, bez treści
źródła. Źródło produktu nie jest potrzebne do werdyktu i nie ma czego logować z pliku, który
mógłby nieść sekret.

Gdy nie ma ani `csproj`, ani `package.json`, kod wyjścia to `0` i linia
`no material for dependency-vulnerabilities`. Wywołanie `--from-tree` robi ten sam werdykt
na drzewie, bez sieci. Gdy `package.json` jest bez `package-lock.json`, kod to `1`.
Instalacja „na bieżąco” z rejestru dałaby inne drzewo jutro niż dziś i zielony audyt nic by
nie mówił o tym, co wejdzie do obrazu. Lockfile jest umową. Brak umowy jest porażką checka,
zanim w ogóle dojdzie do wagi CVE.

Sam Dependabot jako bramka odpadł. Dependabot otwiera pull request z podbiciem, a nie
blokuje scalenia, które właśnie wpuszcza podatny pakiet. Rewizja
`feat(news): publish article revision` może dodać paczkę o wadze `High` i zostać scalona,
zanim Dependabot zdąży otworzyć drugi pull request z poprawką. Może działać obok, jako pomoc
przy aktualizacji, i nie zastępuje tego joba. Usługa z tokenem w workflow też odpadła. Token
byłby sekretem, a numer `06` nie wpuszcza sekretu aplikacji do YAML. Krok nie ustawia
`NUGET_AUTH_TOKEN` ani rejestru prywatnego. Pakiety biorą się z publicznych źródeł
zapisanych w repozytorium, gdy takie pliki konfiguracji NuGet powstaną.

Koszt zostaje przy bazie CVE w CLI. Bywa świeższa albo starsza o dzień od innej bazy.
Werdykt jest powtarzalny w jednym jobie i nie zależy od konta w obcej usłudze. Dwa konta nie
dają dwóch przycisków scalenia. `NuGetAudit` w `Directory.Build.props` może dojść razem z
pierwszym projektem, w numerze API. Ten job i tak woła `dotnet list`, żeby check miał jedną
nazwę także wtedy, gdy właściwości MSBuild jeszcze nie ma. Zielony build z włączonym audytem
w kompilatorze nie zastępuje nazwy `dependency-vulnerabilities` na liście rulesetu. Ruleset
czyta tę nazwę, nie ostrzeżenie MSBuild.

Harmonogram łapie CVE ogłoszone bez nowego commita. `dependencies.yml` ma drugi wyzwalacz
`schedule` w poniedziałek, `cron: "0 6 * * 1"`, na gałęzi `develop`, na tym samym
`ubuntu-latest`. Nie jest to check pull requestu. Nie dostaje sekretu. Następny pull request
i tak powtórzy job. Poniedziałkowy przebieg jest po to, żeby dziura w paczce News wyszła na
jaw, zanim ktoś otworzy kolejną rewizję artykułu i zobaczy czerwony check dopiero przy swoim
tytule. Czerwony harmonogram nie blokuje przycisku scalenia sam z siebie. Blokuje go
najbliższy pull request, który ten sam skrypt odpali na `develop`.

Średnia waga zostaje w logu i nie kończy joba kodem `1`. Podniesienie progu do średniej
zalałoby wczesne drzewo i nauczyło wyłączać check. Obniżenie progu poniżej wysokiej
wpuściłoby `High` na `develop` razem z tytułem, który numer `07` umie zamienić w tag. Próg
jest jeden od pierwszej bramki do `main`. Promocja nie „zaczyna liczyć CVE dopiero na
`release` ”. Na `release` i na `main` ten sam check jest wymagany ponownie, świeżo, tak jak
`build` w numerze `02`.

### Trivy dla obrazu

Gdy `affected-components.sh` wskaże komponent, a w jego katalogu jest `Dockerfile`, job
`image-scan` buduje obraz lokalnie na runnerze i woła Trivy. Nie wypycha obrazu do rejestru.
Tag lokalny to `jjdevhub/<komponent>:scan`. Dla News jest to `jjdevhub/news:scan`. Po jobie
obraz zostaje na runnerze, który i tak znika. Rejestr i tag wydania, `news-v…`, dochodzą w
numerze `16`. Ten numer poświadcza skrót zbudowany na runnerze, nie tag w rejestrze.
Wypchnięcie „żeby Trivy miał co czytać” wciągnęłoby do rejestru obraz, którego jeszcze nie
ma prawa tam być, bo promocja może paść.

Trivy kończy się kodem `1` przy wadze `HIGH` albo `CRITICAL` w paczkach systemu i bibliotek
aplikacji. Służą do tego `--severity HIGH,CRITICAL` oraz wyłączone `--ignore-unfixed`. CVE
bez poprawki też blokuje. Wyjątek jest plikiem `.github/trivy/trivy.yaml` z regułą
ignorowania, która ma datę końca w komentarzu `# expires: YYYY-MM-DD`. Skrypt
`trivy-ignore-expiry.sh` pada, gdy data jest pusta albo wcześniejsza niż dzień przebiegu.
Bez daty nie ma wyciszenia. Plik na start nie ma reguł ignorowania. Brak ignorowań to kod
`0`. Data `2000-01-01` to kod `1`. Job woła ten skrypt przed Trivy, także gdy nie ma
Dockerfile: wtedy plik konfiguracji i tak ma być zdrowy.

Martwa reguła po dacie przewraca `image-scan`, nawet gdy samego CVE już nie ma w bazie,
dopóki reguła leży w pliku. Inaczej wyciszenie zostałoby na zawsze i wysoki CVE wróciłby w
następnej podstawie obrazu bez nowego diffu w `trivy.yaml`. Data jest kosztem świadomego,
krótkiego obejścia. Nie jest listą „na zawsze”. Komentarz bez daty jest tym samym co brak
komentarza: kod `1`.

Grype jako drugi, równoległy werdykt w tym samym checku odpadł. Dwa skanery na jednym
obrazie dają dwa czerwone powody i nie wiadomo, który ruleset czyta. Zostaje Trivy i nazwa
`image-scan`. Docker Scout jako bramka odpadł, bo werdykt wiąże z kontem usługi. Trivy w
jobie czyta publiczną bazę i nie potrzebuje tokenu. Token Scouta byłby sekretem w YAML, tak
samo zabronionym jak `NUGET_AUTH_TOKEN`.

Koszt zostaje przy obrazie, który nie korzysta z danego CVE, a i tak nie wejdzie na
`release`, gdy waga jest wysoka albo krytyczna i poprawki nie ma. Wyjątek z datą jest na ten
przypadek. Bez daty promocja stoi. To jest przyjęte. Inaczej „aplikacja z tego CVE nie
korzysta” stałoby się stałym argumentem i próg by zniknął. Dockerfile w katalogu domowym
narzędzia nie wchodzi do bramki. Szukane ścieżki są zamknięte:
`src/services/<Usługa>/Dockerfile`, `src/gateway/Dockerfile`, `src/clients/web/Dockerfile`,
`src/clients/mobile/Dockerfile`.

Gdy żaden dotknięty komponent nie ma Dockerfile, a w całym drzewie też nie ma Dockerfile,
job loguje `no material for image-scan` i kończy się kodem `0`. Gdy Dockerfile jest w
komponencie, którego diff nie dotknął, tego obrazu job nie buduje. Zmiana News nie skanuje
ponownie Identity. Gdy Dockerfile jest tylko w Identity, a pull request dotyka tylko
`docs/`, listy komponentów nie ma i job jest pustym sukcesem. `dockerfiles.sh` dostaje JSON
komponentów i wypisuje pary `komponent ścieżka`. Pusta lista daje komunikat braku materiału.
Osobnej listy „usługi do skanowania” nie ma. Mapa jest ta sama co w numerze `02`.

### Syft i SPDX jako SBOM

Job `sbom` na pull request do `main` bierze ten sam lokalny obraz co skan, jeśli Dockerfile
istnieje, i woła Syft z wyjściem SPDX JSON. Plik nazywa się `sbom-<komponent>.spdx.json` i
jest artefaktem przebiegu. Jeden komponent, jeden plik. Dla News jest to
`sbom-news.spdx.json`. Komponent bez Dockerfile nie dostaje pliku i nie powoduje porażki.
Pusty sukces na `main` bez Dockerfile to `no material for sbom` i kod `0`. Na pull request
do `release` ten job loguje, że jego bramka jest na `main`, i też kończy się sukcesem, bo
ruleset `release` go nie wymaga.

Sam CycloneDX z `dotnet` jako jedyny wykaz odpadł, bo nie obejmuje warstw systemu w obrazie.
Werdykt Trivy czyta obraz. Wykaz, który czyta tylko `csproj`, nie mówi o podstawie, na
której `image-scan` właśnie padł albo przeszedł. Syft czyta obraz, więc wykaz i skan mówią o
tym samym artefakcie, o tagu `jjdevhub/<komponent>:scan`. CycloneDX może być drugim formatem
później. Bramka tego numeru trzyma jeden plik SPDX na komponent. Drugi plik w tym samym
checku dawałby dwa artefakty i pytanie, który numer `16` porównuje z obrazem na maszynie.

Koszt zostaje w długości wykazu. SPDX z obrazu jest dłuższy niż lista pakietów NuGet. Taki
ma być. [16-deploy.md](16-deploy.md) porównuje wykaz z obrazem, który wdraża, a nie z samym
`csproj`. Krótsza lista wygląda czytelniej i gubi paczkę systemu, która była powodem
czerwonego Trivy. Joby nie dzielą dysku, więc `sbom` buduje obraz ponownie tym samym
`docker build`, co skan. Na `main` to jest druga z trzech budów. Trzecią robi job atestacji.
Powtórzenie jest świadome.

Na `release` prawdziwy skan obrazu się wykonuje. `sbom` tam swojej pracy nie wykonuje poza
komunikatem o bramce. Inaczej ruleset `release` musiałby wymagać checka, którego tabela tego
numeru trzyma na `main`. Wymaganie go wcześniej zatrzymałoby promocję na środku o wykaz,
który deploy i tak czyta przy tagu. Środek ma zobaczyć Trivy. Koniec drogi ma zobaczyć wykaz
i atestację.

### Atestacja GitHuba bez klucza w repozytorium

Job `attestations` woła `actions/attest-build-provenance` i `actions/attest-sbom` dla skrótu
obrazu zbudowanego w tym samym workflow i dla pliku SPDX. Tożsamość bierze się z
`GITHUB_TOKEN` przebiegu oraz z `id-token: write` i `attestations: write`. Te dwa
uprawnienia są wyłącznie na jobie `attestations`. Skan i SBOM mają `contents: read`. W YAML
nie ma klucza, hasła rejestru ani `secrets.` z nazwą sekretu aplikacji. `grep` szuka
`secrets.` w obu workflowach. Brak trafień jest wynikiem pozytywnym. `id-token` i
`attestations` w `permissions` są uprawnieniami automatycznego tokenu przebiegu, nie
wyrażeniem `secrets.`.

Cosign z kluczem prywatnym w repozytorium albo w sekretach workflow tego numeru odpadł.
Klucz trzeba by obracać i gdzieś trzymać. Trzymanie go w gitcie jest sekretem w historii.
Trzymanie go w sekrecie workflow wraca do zakazu z numeru `06`. Atestacja przebiegu GitHub
Actions jest weryfikowalna z logu tego przebiegu. Rejestr i weryfikacja przy deployu
dochodzą w [16-deploy.md](16-deploy.md). Do tego czasu atestacja dotyczy skrótu zbudowanego
na runnerze, nie tagu w rejestrze. Numer `16` może odrzucić obraz bez atestacji z tego
repozytorium. Ten numer zostawia mu skrót i plik SPDX, które da się powiązać z przebiegiem.

Koszt zostaje poza GitHubem. Ta atestacja nie jest podpisem własnego klucza produktu. Dla
jednego repozytorium i deployu z tagu, który i tak wycina GitHub, to jest właściwy zakres.
Własny klucz wróciłby do Cosigna, którego ten numer odrzucił. Trzecia budowa obrazu na
`main` jest częścią tego kosztu. `attestations` nie widzi dysku joba `image-scan` ani joba
`sbom`. Buduje trzeci raz tym samym `docker build` i poświadcza skrót tej budowy.
Współdzielenie obrazu między jobami wymagałoby rejestru albo `actions/cache` dużego pliku
warstw. Na jednym komponencie trzy budowy są czytelniejsze niż ukryty stan. Gdy komponentów
przybędzie, numer `16` i tak buduje obraz wydania osobno, z tagu.

Gdy nie ma Dockerfile, job loguje `no material for attestations` i kończy się kodem `0` bez
wołania akcji atestacji. Wołanie atestacji bez skrótu obrazu skończyłoby się błędem i
zablokowało promocję dokumentacji na `main`, choć nie ma czego poświadczać. To jest ten sam
pusty sukces co przy Trivy i przy Syft. Trzy nazwy checków istnieją od tego numeru.
Zaczynają wiązać materiał w dniu, w którym komponent dostaje Dockerfile w ustalonej ścieżce.
Nowy komponent z mapy numeru `02` podlega skanowi automatycznie. Osobnej listy usług do
obrazów nie zakładaj.

`runs-on` to `ubuntu-latest`. `timeout-minutes` to `20`. Akcje checkout, Trivy, Syft i
attest są przypięte do pełnego SHA z komentarzem wersji. `self-hosted` i
`pull_request_target` są zabronione z tego samego powodu co w numerze `02`: kod pull
requestu nie jedzie na maszynę domową i nie dostaje uprawnień gałęzi docelowej. Obraz
`jjdevhub/<komponent>:scan` żyje na runnerze hostowanym. Na maszynę jedzie później tag z
numeru `07`, przez numer `16`, nie ten lokalny tag skanu.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/dependencies.yml` | job `dependency-vulnerabilities` |
| `.github/workflows/artifacts.yml` | joby `image-scan`, `sbom`, `attestations` |
| `.github/scripts/vuln-gate.sh` | próg NuGet i npm |
| `.github/scripts/dockerfiles.sh` | Dockerfile per komponent z mapy numeru `02` |
| `.github/scripts/trivy-ignore-expiry.sh` | data końca wyciszenia |
| `.github/trivy/trivy.yaml` | konfiguracja Trivy, na start bez wyciszeń |
| `.github/fixtures/vuln/packages-high.json` | jedna paczka wagi `High` |
| `.github/fixtures/vuln/packages-none.json` | brak podatności |
| `.github/rulesets/develop.json` | dopisany `dependency-vulnerabilities` |
| `.github/rulesets/release.json` | dopisany `image-scan` oraz check z `develop` |
| `.github/rulesets/main.json` | dopisane `sbom` i `attestations` |

Szukane pliki Dockerfile:

- `src/services/<Usługa>/Dockerfile`
- `src/gateway/Dockerfile`
- `src/clients/web/Dockerfile`
- `src/clients/mobile/Dockerfile`

Wyzwalacze:

| Plik | Gałęzie pull requestu |
| --- | --- |
| `dependencies.yml` | `develop`, `release`, `main` |
| `artifacts.yml` | `release` i `main` dla całego pliku |

`dependencies.yml` ma dodatkowo `schedule` z `cron: "0 6 * * 1"` na gałęzi `develop`. W
`artifacts.yml` job `image-scan` wykonuje skan na obu celach. Joby `sbom` i `attestations`
wykonują swoją pracę, gdy `github.base_ref` to `main`. `permissions` skanu i SBOM to
`contents: read`. Atestacja dokłada `id-token: write` i `attestations: write` wyłącznie na
swoim jobie.

## Plan

### 1. Dodać bramkę zależności

Utwórz `vuln-gate.sh` i `dependencies.yml`. Skrypt zwraca `0`, gdy nie ma `csproj` i nie ma
`package.json`. Zwraca `1`, gdy `package.json` jest bez `package-lock.json`. Zwraca `1`, gdy
któraś waga to `High` albo `Critical`. Wypisuje identyfikator paczki i wagę, bez treści
źródła. Dla NuGet wołaj
`dotnet list package --vulnerable --include-transitive --format json`. Dla npm wołaj
`npm audit --audit-level=high` tam, gdzie jest `package-lock.json`.

Krok w workflow nie ustawia `NUGET_AUTH_TOKEN` ani rejestru prywatnego. `runs-on` ustaw na
`ubuntu-latest`. `timeout-minutes` ustaw na `20`. `permissions` ustaw na `contents: read`.
Wyzwalacz pull requestu ustaw na `develop`, `release` i `main`. Drugi wyzwalacz ustaw na
`schedule` z `cron: "0 6 * * 1"` i gałęzią `develop`. Harmonogram nie dostaje sekretu. Nie
dodawaj `paths` ani `pull_request_target`.

### 2. Dodać wspólny workflow artefaktów

Utwórz `artifacts.yml` z trzema jobami: `image-scan`, `sbom`, `attestations`. Na początku
każdego jest `affected-components.sh` i `dockerfiles.sh`. Drugi skrypt dostaje JSON
komponentów i wypisuje pary `komponent ścieżka`. Pusta lista daje `no material for <job>`.

Na `main`, gdy Dockerfile jest, `image-scan` buduje obraz tagiem `jjdevhub/<komponent>:scan`
i skanuje go Trivy. Nie wypychaj obrazu. `sbom` buduje ponownie tym samym `docker build` i
woła Syft z wyjściem SPDX JSON do `sbom-<komponent>.spdx.json`. `attestations` buduje trzeci
raz i woła `actions/attest-build-provenance` oraz `actions/attest-sbom` dla skrótu i dla
pliku SPDX. Trzy budowy są świadome: joby nie dzielą dysku.

Na `release` wykonaj prawdziwy `image-scan`. `sbom` i `attestations` zakończ komunikatem, że
ich bramka jest na `main`, kodem `0`. Nie stawiaj `if` na całym jobie, które GitHub pokazuje
jako skipped. `runs-on` to `ubuntu-latest`. `timeout-minutes` to `20`. Trivy wołaj z
`--severity HIGH,CRITICAL` i z wyłączonym `--ignore-unfixed`.

### 3. Dodać datę wyciszenia Trivy

Utwórz `trivy.yaml` bez reguł ignorowania. Utwórz `trivy-ignore-expiry.sh`, który czyta
komentarze `# expires: YYYY-MM-DD` nad ignorowaniem. Brak ignorowań to kod `0`. Ignorowanie
bez daty to kod `1`. Data wcześniejsza niż `TODAY` to kod `1`. Job `image-scan` woła ten
skrypt przed Trivy, także gdy nie ma Dockerfile.

### 4. Dopisać nazwy do rulesetów

W scaleniu `dependencies.yml` dopisz `dependency-vulnerabilities` do trzech JSON-ów. W
scaleniu `artifacts.yml` dopisz `image-scan` do `release.json` i `main.json`, a `sbom` i
`attestations` tylko do `main.json`. Nie dopisuj nazwy w scaleniu, które jeszcze nie zawiera
workflow raportującego tę nazwę.

### 5. Zostawić wzorce, które mają paść

Utwórz `.github/fixtures/vuln/packages-high.json` z jednym pakietem wagi `High` w kształcie,
który wypisuje `dotnet list package --format json`. Utwórz `packages-none.json` bez
podatności. `vuln-gate.sh --nuget-json` czyta je bez sieci. Nie commituj przykładowego
Dockerfile z celowo dziurawą podstawą. Suchy przebieg obrazu bez Dockera kończy się na
`dockerfiles.sh`. Pełny Trivy odpala się na runnerze, gdy Dockerfile już jest.

### 6. Spiąć z komponentem

`dockerfiles.sh` używa mapy z [02-bramki.md](02-bramki.md). Nowy komponent w tej mapie
automatycznie podlega skanowi, gdy dostanie Dockerfile w ustalonej ścieżce. Osobnej listy
„usługi do skanowania” nie zakładaj. Ścieżki wpisz jako `src/services/<Usługa>/Dockerfile`,
`src/gateway/Dockerfile`, `src/clients/web/Dockerfile` i `src/clients/mobile/Dockerfile`.

Uprawnienia atestacji ustaw tylko na jobie `attestations`: `id-token: write` i
`attestations: write`. Skan i SBOM zostaw przy `contents: read`. Każdą akcję `uses` przypnij
do pełnego SHA i dopisz komentarz wersji. W YAML nie umieszczaj `secrets.` sekretu
aplikacji.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `dependencies.yml` | pull request na trzy gałęzie, harmonogram poniedziałkowy | check `dependency-vulnerabilities` |
| `artifacts.yml` | pull request na `release` i `main` | trzy checki obrazu w jednym miejscu |
| `vuln-gate.sh` | job zależności i suchy przebieg | próg bez sieci na fixture |
| `dockerfiles.sh` | trzy joby artefaktów | ten sam warunek „czy jest Dockerfile” |
| `trivy-ignore-expiry.sh` | `image-scan` | wyciszenie nie zostaje po dacie |
| `trivy.yaml` | Trivy | konfiguracja w gitcie, nie w interfejsie |
| JSON-y rulesetów | sync z numeru `01` | zamiana statusu w blokadę |

Job `build` nie woła Trivy. Czerwony skan ma własną nazwę na liście checków. Zielony
`unit-tests` przy czerwonym `dependency-vulnerabilities` nie scala
`feat(news): publish article revision` na `develop`.

## Testy

`actionlint`:

```bash
actionlint .github/workflows/dependencies.yml .github/workflows/artifacts.yml
```

Kod `0`.

```bash
grep -nE 'self-hosted|pull_request_target|secrets\.' \
  .github/workflows/dependencies.yml .github/workflows/artifacts.yml
```

Brak trafień. Kod grepa `1` jest wynikiem pozytywnym. `id-token` i `attestations` w
`permissions` są uprawnieniami automatycznego tokenu przebiegu, nie wyrażeniem `secrets.`.

Suchy przebieg zależności na fixture:

```bash
.github/scripts/vuln-gate.sh --nuget-json .github/fixtures/vuln/packages-none.json
echo $?
.github/scripts/vuln-gate.sh --nuget-json .github/fixtures/vuln/packages-high.json
echo $?
```

Pierwszy kod `0`. Drugi kod `1`. Drugi jest przykładem, który ma paść: wysoka podatność
blokuje `develop`. Powód padnięcia jest jeden: waga `High`. Średnia waga w takim pliku ma
dać kod `0` i zostać w logu. Krytyczna pada tak samo jak wysoka.

W drzewie bez `csproj` i bez `package.json`:

```bash
.github/scripts/vuln-gate.sh --from-tree
```

Kod `0` i `no material for dependency-vulnerabilities`.

Dockerfile:

```bash
.github/scripts/dockerfiles.sh --components '[]'
```

Kod `0` i `no material for image-scan`, gdy skrypt wołany jest w tym trybie z nazwą joba
`--job image-scan`. To samo dla `sbom` i `attestations`.

Data wyciszenia. Plik tymczasowy poza repozytorium, nie commit:

```bash
d=$(mktemp)
printf '%s\n' '# expires: 2000-01-01' 'CVE-TEST' > "$d"
.github/scripts/trivy-ignore-expiry.sh --file "$d"; echo $?
rm -f "$d"
```

Kod `1`. Powód padnięcia jest jeden: data `2000-01-01` jest wcześniejsza niż dzień
przebiegu. Ten sam skrypt na `trivy.yaml` bez reguł ignorowania kończy się kodem `0`.
Ignorowanie bez linii `# expires: YYYY-MM-DD` też kończy się kodem `1`.

Zła gałąź, zanim ktokolwiek oceni paczkę:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. `feature/lesson-markdown` do `develop` daje kod `0`. Na takiej gałęzi, przed
pierwszym lockfile, `dependency-vulnerabilities` jest zielony z powodu braku materiału, a
nie z powodu wyłączonego checka. Zielony test jednostkowy nie wyłącza tego checka. Czerwony
fixture wagi `High` blokuje `develop` przy poprawnym tytule
`feat(news): publish article revision`.

`dependencies.yml` ma w pliku `cron: "0 6 * * 1"`. Harmonogram idzie na `ubuntu-latest` i
nie dostaje sekretu. Nie jest checkiem pull requestu. Najbliższy pull request na `develop`
powtarza ten sam `vuln-gate.sh`.

## Zasady

- Próg zależności i obrazu to wysoka i krytyczna waga, łącznie z podatnością bez poprawki.
- `dependency-vulnerabilities` jest wymagany od `develop` w górę.
- `image-scan` jest wymagany od `release` w górę. `sbom` i `attestations` od `main`.
- Te trzy joby są w `artifacts.yml` także wtedy, gdy w repozytorium nie ma Dockerfile.
- Brak materiału to sukces z logiem. Jest materiał i jest trafienie, to porażka.
- Job nie wypycha obrazu i nie loguje się do rejestru. Tag lokalny to
  `jjdevhub/<komponent>:scan`.
- Wyciszenie Trivy ma datę końca. Po dacie job `image-scan` pada, dopóki martwa reguła leży
  w pliku.
- Brak lockfile przy `package.json` pada kodem `1`.
- Polecenie NuGet to `dotnet list package --vulnerable --include-transitive`.
- Polecenie npm to `npm audit --audit-level=high`.
- Zmiana jednego komponentu nie buduje obrazu pozostałych.
- W workflow nie ma `secrets.` sekretu aplikacji. Nie ma `NUGET_AUTH_TOKEN`.
- `id-token: write` i `attestations: write` są tylko na jobie `attestations`.
- Harmonogram to poniedziałek, `cron: "0 6 * * 1"`, gałąź `develop`, `ubuntu-latest`.
- `timeout-minutes` to `20`. `runs-on` to `ubuntu-latest`.
- Na `main` trzy budowy obrazu jednego komponentu są świadome.

## Poza zakresem

- CodeQL po kodzie źródłowym jest w [03-codeql.md](03-codeql.md). Ten numer nie czyta SARIF
  z zapytań o przepływ i nie ustawia progu `7.0`.
- Gitleaks i pin akcji są w [06-lancuch-dostaw.md](06-lancuch-dostaw.md). Ten numer nie
  szuka sekretu w diffie. Przypina własne akcje do SHA.
- Tag, który powie, który obraz w ogóle powstaje, jest w [07-wersje.md](07-wersje.md). Ten
  numer nie wycina `news-v1.4.0`. Skanuje lokalny tag `jjdevhub/news:scan`.
- Rejestr, wdrożenie i odrzucenie obrazu bez atestacji na maszynie są w
  [16-deploy.md](16-deploy.md). Ten numer nie wypycha obrazu.
- Treść Dockerfile usługi jest w numerze API, który dodaje projekt i obraz. Ten numer nie
  wybiera bazy `aspnet`. Przeskanuje to, co tamten numer wskaże.
- OpenBao jest w [14-openbao.md](14-openbao.md). Ten numer nie czyta tokenu rejestru i nie
  wkłada klucza do YAML.
- Mapa komponentów jest w [02-bramki.md](02-bramki.md). Ten numer nie zakłada drugiej listy
  usług do skanowania.
- Nazwa gałęzi jest w [01-galezie.md](01-galezie.md). `feature/lesson_markdown` nadal kończy
  się kodem `1`, zanim bramka paczki w ogóle wystartuje.

## Źródła

- [Audyt pakietów NuGet](https://learn.microsoft.com/nuget/concepts/auditing-packages).
  Wiążące są wagi podatności i to, że `dotnet list package --vulnerable` bez
  `--include-transitive` nie pokazuje paczek przechodnich. Dotyczy progu `High` i `Critical`
  oraz polecenia z `--include-transitive --format json`. Ze źródła nie bierzemy samego
  `NuGetAudit` w MSBuild jako zamiennika checka. Job i tak woła `dotnet list`, żeby ruleset
  miał nazwę `dependency-vulnerabilities`.
- [dotnet list package](https://learn.microsoft.com/dotnet/core/tools/dotnet-list-package).
  Wiążące są flagi `--vulnerable`, `--include-transitive` i `--format json`. Dotyczy
  wywołania w `dependencies.yml` i fixture czytanych przez `vuln-gate.sh --nuget-json`. Ze
  źródła nie bierzemy innej pisowni polecenia jako zamiennika tego, co jest zapisane w tym
  numerze. Nie bierzemy też audytu bez paczek przechodnich.
- [npm audit](https://docs.npmjs.com/cli/v10/commands/npm-audit). Wiążące jest
  `--audit-level=high` i kod wyjścia inny niż zero, gdy próg zostanie osiągnięty. Dotyczy
  katalogu z `package-lock.json` oraz tego, że audyt obejmuje zależności produkcyjne i
  narzędziowe. Ze źródła nie bierzemy niższego progu, który zalałby `develop` wagą średnią.
  Średnia zostaje w logu.
- [package-lock.json](https://docs.npmjs.com/cli/v10/configuring-npm/package-lock-json).
  Wiążące jest to, że lockfile zapisuje drzewo, które da się powtórzyć. Dotyczy kodu `1`,
  gdy `package.json` jest, a `package-lock.json` nie ma. Ze źródła nie bierzemy instalacji z
  samego `package.json` jako wejścia audytu. Bez lockfile nie da się powiedzieć, co weszło
  do obrazu.
- [Trivy](https://trivy.dev/docs/latest/). Wiążący jest skan obrazu lokalnego, bez
  wypchnięcia do rejestru. Dotyczy tagu `jjdevhub/<komponent>:scan` i joba `image-scan` na
  `release` oraz `main`. Ze źródła nie bierzemy Grype ani Docker Scout jako drugiego
  werdyktu w tym samym checku. Token obcej usługi nie wchodzi do YAML.
- [Trivy vulnerability scanner](https://trivy.dev/docs/latest/scanner/vulnerability/).
  Wiążące są `--severity` oraz flaga pomijania podatności bez poprawki. Dotyczy
  `--severity HIGH,CRITICAL` i wyłączonego `--ignore-unfixed`, więc CVE bez poprawki też
  blokuje. Ze źródła nie bierzemy `--ignore-unfixed` włączonego na stałe. Wyjątek jest
  wpisem w `trivy.yaml` z datą końca, nie globalnym puszczeniem niezałatanych dziur.
- [Trivy config file](https://trivy.dev/docs/latest/references/configuration/config-file/).
  Wiążące jest trzymanie opcji skanu w pliku konfiguracji w repozytorium. Dotyczy
  `.github/trivy/trivy.yaml`, na start bez reguł ignorowania, i komentarza
  `# expires: YYYY-MM-DD`. Ze źródła nie bierzemy wyciszenia bez daty.
  `trivy-ignore-expiry.sh` kończy się kodem `1`, gdy data jest pusta albo wcześniejsza niż
  dzień przebiegu.
- [Syft](https://github.com/anchore/syft). Wiążące jest czytanie obrazu i wyjście SPDX JSON.
  Dotyczy pliku `sbom-<komponent>.spdx.json` oraz tego, że wykaz opisuje ten sam lokalny
  obraz co Trivy. Ze źródła nie bierzemy CycloneDX z samego `dotnet` jako jedynego wykazu
  bramki. Warstw systemu w `csproj` nie ma, a jeden komponent daje jeden plik.
- [SPDX](https://spdx.github.io/spdx-spec/v2.3/). Wiążący jest jeden dokument składników na
  artefakt. Dotyczy wyjścia Syft jako SPDX JSON, które numer `16` porówna z obrazem
  wdrażanym na maszynę. Ze źródła nie bierzemy drugiego formatu w tym samym checku.
  CycloneDX może dojść później i nie jest plikiem, którego ten numer wymaga.
- [Artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds).
  Wiążące jest poświadczenie pochodzenia budowy i SBOM tożsamością przebiegu, bez klucza w
  gitcie. Dotyczy joba `attestations` oraz uprawnień `id-token: write` i
  `attestations: write` tylko na tym jobie. Ze źródła nie bierzemy Cosigna z kluczem
  prywatnym w repozytorium albo w sekrecie workflow. Poza GitHubem to nie jest podpis
  własnego klucza produktu.
- [attest-build-provenance](https://github.com/actions/attest-build-provenance). Wiążące
  jest poświadczenie skrótu artefaktu zbudowanego w przebiegu. Dotyczy trzeciej budowy
  obrazu na `main` i skrótu tagu `jjdevhub/<komponent>:scan`, który nie jest wypychany. Ze
  źródła nie bierzemy wypchnięcia do rejestru jako warunku atestacji. Rejestr dochodzi w
  numerze `16`, a akcja jest przypięta do pełnego SHA.
- [attest-sbom](https://github.com/actions/attest-sbom). Wiążące jest poświadczenie pliku
  wykazu obok skrótu obrazu. Dotyczy `sbom-<komponent>.spdx.json` w tym samym jobie
  `attestations`. Ze źródła nie bierzemy atestacji bez pliku SPDX, gdy Dockerfile już jest.
  Gdy Dockerfile nie ma, job nie woła akcji i loguje `no material for attestations`.
- [Schedule](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule).
  Wiążące jest wyrażenie cron i to, że harmonogram nie jest checkiem pull requestu. Dotyczy
  `cron: "0 6 * * 1"` w `dependencies.yml`, w poniedziałek, na gałęzi `develop`, na
  `ubuntu-latest`. Ze źródła nie bierzemy sekretu w przebiegu harmonogramu. Najbliższy pull
  request i tak powtarza `vuln-gate.sh`.
- [Require status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).
  Wiążące jest to, że check bez raportu blokuje scalenie. Dotyczy dopisania
  `dependency-vulnerabilities` do trzech JSON-ów oraz `image-scan`, `sbom` i `attestations`
  tylko tam, gdzie tabela tego numeru je wymaga. Ze źródła nie bierzemy wymagania `sbom` na
  `release`. Na `release` ten job kończy się komunikatem i kodem `0`, a ruleset go nie
  wymienia.
- [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
  Wiążące jest to, że filtr `paths` zostawia wymagany check w oczekiwaniu. Dotyczy zakazu
  `paths` w `dependencies.yml` i w `artifacts.yml`. Ze źródła nie bierzemy pominięcia całego
  joba jako zamiennika linii `no material for image-scan`. Pusty sukces jest kodem `0` i
  jawnym logiem.
- [actionlint](https://github.com/rhysd/actionlint). Wiążące jest lokalne sprawdzenie
  składni obu workflowów, z oczekiwanym kodem `0`. Dotyczy `dependencies.yml` i
  `artifacts.yml`. Ze źródła nie bierzemy werdyktu `actionlint` jako progu `High`. Próg
  sprawdza `vuln-gate.sh` na fixture, datę sprawdza `trivy-ignore-expiry.sh`, a zakaz
  `secrets.` sprawdza `grep`.

## Gotowe gdy

- Są `dependencies.yml`, `artifacts.yml`, trzy skrypty, `trivy.yaml` i dwa fixture JSON.
- `actionlint` na obu workflowach kończy się kodem `0`.
- `grep` nie znajduje `self-hosted`, `pull_request_target` ani `secrets.` i kończy się kodem
  `1`.
- Fixture wagi `High` kończy `vuln-gate.sh` kodem `1`, fixture bez podatności kodem `0`.
- `vuln-gate.sh --from-tree` w drzewie bez `csproj` i bez `package.json` kończy się kodem
  `0` i linią `no material for dependency-vulnerabilities`.
- `dockerfiles.sh` na pustej liście komponentów kończy się kodem `0` i logiem braku
  materiału.
- Wyciszenie z datą `2000-01-01` kończy `trivy-ignore-expiry.sh` kodem `1`.
- `feature/lesson_markdown` nadal pada w `check-branch-name.sh` kodem `1`.
- Trzy JSON-y rulesetów mają nazwy checków z tabeli „Po co”, dopisane w scaleniu, które
  dodaje workflow.
- W `dependencies.yml` jest `cron: "0 6 * * 1"`. W jobie atestacji są `id-token: write` i
  `attestations: write`, a w pozostałych jobach ich nie ma.
- Polecenie NuGet w workflow to `dotnet list package --vulnerable --include-transitive`.
  Trivy ma `--severity HIGH,CRITICAL` i wyłączone `--ignore-unfixed`.
