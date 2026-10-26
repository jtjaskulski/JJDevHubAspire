# 06. Łańcuch dostaw

[Spis CI/CD](README.md) · poprzedni: [05. SonarQube](05-sonarqube.md) · następny: [07.
Wersje](07-wersje.md)

Ten numer zatrzymuje sekret, zanim wpadnie do gita, przypina akcje GitHub do pełnego SHA i
odpala statyczną analizę workflow oraz lokalny Scorecard. Nie stawia serwera sekretów.
Produkcyjny OpenBao opisuje [14-openbao.md](14-openbao.md). Lokalny OpenBao w AppHost
opisuje [docs/api/04-openbao.md](../api/04-openbao.md). Po tym numerze bramka `develop`
wymaga `gitleaks`, `zizmor`, `action-pins` i `scorecard` obok checków z numerów `01`, `02` i
`04`.

Pierwszy pull request funkcji, jeszcze bez usługi, już nie może dodać pliku SOPS, tokenu w
diffie ani `uses` z ruchomym tagiem. Identity, News, Learning, Cv i Contact jeszcze nie mają
katalogu, a workflow z numerów `01` – `05` już są kodem, który ten pull request może zepsuć.
Checki idą na `develop`, `release` i `main`. Zły plik workflow nie czeka na promocję.

Scenariusz, który bez tego numeru zostaje w historii, zaczyna się od „chwilowego” ciągu w
teście. Ktoś wkleja token do fixture, widzi, że test Identity pada, i w następnym commicie
plik kasuje. Checkout o głębokości jeden widzi tylko głowę. Sekret w starym commicie zostaje
na `develop`. Tag z numeru `07` i obraz z numeru `16` dziedziczą historię, w której ciąg już
był. Job `gitleaks` woła `gitleaks detect --redact` przy `fetch-depth: 0`, więc kasowanie
pliku nie kasuje śladu. Log pokazuje regułę i ścieżkę. Samego ciągu nie powtarza.

Drugi scenariusz jest w YAML, nie w sekrecie aplikacji. Akcja checkout stoi na `@v4`. Tag da
się przesunąć na inny commit między dwoma przebiegami tego samego pull requestu. Recenzja
oglądała jeden kod, runner wykonał drugi. Obok ktoś dopisuje `pull_request_target` i
checkout głowy pull requestu, bo „tak da się skomentować”. Obcy kod idzie z uprawnieniem
zapisu. `zizmor --offline` ma to złapać bez tokenu do API. `check-action-pins.sh` ma paść na
`@v4` i na SHA krótszym niż 40 znaków. `check-runners.sh` ma paść na `pull_request_target` i
na `self-hosted`. Osobnej nazwy checka dla runnera nie ma. Porażka skryptu jest porażką
`action-pins`.

Trzeci scenariusz wygląda jak porządek. Plik `.env` z hasłem do lokalnego Postgresa wchodzi
„obok” `.env.example`. Albo wchodzi `app.sops.yaml`, bo szyfrogram „nie jest hasłem wprost”.
Ten numer traktuje szyfrogram sekretu jako sekret. Traktuje `.env` jako plik, którego w
gitcie nie ma. `.env.example` przechodzi tylko z pustymi wartościami po `=`. Wpisane hasło w
przykładzie pada. OpenBao nie jest w tych plikach. Magazyn sekretów powstaje później. Tutaj
granica jest wcześniejsza: sekret nie ma wejść do drzewa, które klonuje każdy deweloper i
które czyta runner.

Czwarty scenariusz to odznaka. Scorecard potrafi pokazać jedną liczbę, w której sondy
plikowe mieszają się z sondami o historii maintainerów. Lokalny przebieg bez tokenu tych
drugich nie ma. Wpuszczenie tokenu, żeby podnieść odznakę, jest poza tym numerem. Bramką są
trzy sondy na plikach, każda z progiem `10`. Wynik `-1` pada. Średnia „7.5” nie jest
progiem.

## Po co

Workflow z numerów `01` – `05` same są kodem, który pull request może zepsuć. Ruchomy tag
`@v4` da się podmienić. `pull_request_target` z checkoutem głowy pull requestu uruchamia
obcy kod z tokenem zapisu. Sekret wklejony „na chwilę” do testu zostaje w historii, nawet po
usunięciu pliku w następnym commicie. Pierwsza usługa jeszcze nie istnieje, a te cztery
wejścia już tak. Numer `07` nada tag komponentowi. Numer `16` zbuduje z tagu obraz. Sekret,
który wszedł wcześniej, jest w tej historii niezależnie od tego, czy obraz w ogóle powstał.

Ten numer zamyka cztery wejścia.

| Wejście | Check |
| --- | --- |
| sekret, klucz, hasło, token w drzewie gita | `gitleaks` |
| plik SOPS albo plik zaszyfrowanego sekretu | `gitleaks` (osobny krok skryptu) |
| niebezpieczny workflow, nadmiar uprawnień, wstrzyknięcie w wyrażeniu | `zizmor` |
| `uses` bez pełnego SHA albo bez komentarza wersji | `action-pins` |
| sondy Scorecard, które czytają pliki | `scorecard` |

Tabela ma pięć wierszy i cztery nazwy checków, bo plik SOPS jest osobnym krokiem tego samego
joba `gitleaks`. Nazwa pliku pada nawet wtedy, gdy szyfrogram ma niską entropię i reguła
treści go nie widzi. Runner i pin są jednym checkiem `action-pins`: `check-runners.sh` nie
dostaje własnej nazwy w rulesecie. Log mówi, który skrypt padł.

W YAML tych numerów nie ma wartości sekretu aplikacji i nie ma wyrażenia `secrets.`
wskazującego sekret produktu. Automatyczny `GITHUB_TOKEN` przebiegu jest uprawnieniem
`permissions`, nie sekretem wpisanym do pliku. Atestacja z numeru `04` korzysta z `id-token`
i `attestations`. Innego sekretu joby `01` – `07` nie czytają. `grep` po `.github/workflows`
nie znajduje `secrets.`. Jeśli wcześniejszy szkic workflow miał token, ten pull request go
usuwa, zanim check zacznie obowiązywać.

Plik SOPS nie wchodzi do repozytorium także wtedy, gdy treść jest szyfrogramem. Szyfrogram
sekretu jest sekretem w formie, której ten numer nie przyjmuje. Nie dodaje się klucza
deszyfrującego „obok”. Klucz obok szyfrogramu jest drugim sekretem w tym samym drzewie.
OpenBao, gdy powstanie, trzyma sekret poza gitem. Ten numer nie tworzy magazynu i nie czyta
OpenBao. User secrets na laptopie nie są plikiem w repozytorium. Ten numer ich nie opisuje
poza zakazem wrzucenia ich do gita.

Checki są wymagane na trzech gałęziach, bo zły workflow na `develop` jest już wykonaniem.
Czekanie z `zizmor` do `release` znaczyłoby, że kilka scalonych funkcji zdążyło pójść na
runnerze z `@v4` albo z `pull_request_target`. `gitleaks` jest w tabeli bramki `develop` w
[02-bramki.md](02-bramki.md). `zizmor`, `action-pins` i `scorecard` dokładają się tutaj. Te
same cztery nazwy wchodzą do `release.json` i `main.json`, bo ciąg z `develop` obowiązuje
dalej. Promocja nie zdejmuje checka, który na funkcji już był wymagany.

Harmonogram poniedziałkowy, ten sam co zależności w numerze `04`, powtarza cztery joby na
`develop`. Cron zostaje `0 6 * * 1`. To nie jest osobny check. Łapie podbicie reguł
gitleaks, zizmor i scorecard bez nowego commita aplikacji. Następny pull request i tak
powtórzy job. `runs-on` zostaje `ubuntu-latest`. Harmonogram nie dostaje sekretu. `push` na
`develop` też powtarza przebieg i nie zastępuje checka na pull requeście. Ruleset czyta
status z pull requestu.

## Dlaczego ta technologia

### gitleaks na całym drzewie

Job `gitleaks` woła `gitleaks detect --redact --source . --config .gitleaks.toml`.
`--redact` sprawia, że log pokazuje regułę i plik, a nie sam sekret. Skan idzie po bieżącym
drzewie i po historii dostępnej w checkoucie. Checkout joba używa `fetch-depth: 0`, inaczej
sekret w starym commicie, usunięty później, przeszedłby. Reszta jobów tego numeru może wziąć
`fetch-depth: 1`. Głęboka historia jest potrzebna tam, gdzie ślad sekretu żyje poza głową.

Konfiguracja rozszerza domyślne reguły gitleaks. Dokłada ścieżki, które padają nawet bez
trafienia entropii:

- `**/*.sops.yml`, `**/*.sops.yaml`, `**/sops.yaml`, `**/.sops.yaml`
- `**/*.enc.yml`, `**/*.enc.yaml`
- `.env` w dowolnym katalogu, z wyjątkiem `.env.example`, w którym wartości po znaku `=` są
  puste

`.env.example` z wpisanym hasłem pada. Pusta wartość `CONNECTIONSTRING=` przechodzi ten
dodatkowy krok i nadal może paść na regule entropii, jeśli po prawej stronie coś jest.
Skrypt `check-no-sops.sh` idzie przed gitleaks. Kończy się kodem `1`, gdy `git ls-files`
pokaże nazwę z listy SOPS albo `.env` inny niż `.env.example`. Dla `.env.example` kończy się
kodem `1`, gdy któraś linia ma znak niebędący pustą spacją po pierwszym `=`. Kolejność jest
ważna: plik SOPS pełen szyfrogramu o niskiej entropii i tak pada na nazwie.

Problem JJDevHub jest wcześniejszy niż connection string produkcyjny. Na laptopie ktoś
trzyma hasło do kontenera Postgresa w `.env`, obok klonu. Jeden `git add` wrzuca je na
`develop`. Albo fixture testu Contact zawiera kształt klucza, „żeby zobaczyć, że walidacja
działa”. Taki fixture nie należy do drzewa skanowanego w CI. Suchy przebieg podaje katalog
tymczasowy. Do repozytorium go nie commituj. Ten plik dokumentacji nie zawiera kształtu
klucza. Jeśli dokument kiedyś potrzebuje przykładu, używa jawnie fałszywego prefiksu
opisanego w `.gitleaks.toml` jako allow na jedną ścieżkę `docs/cicd/`, i tylko gdy ciąg nie
wygląda jak prawdziwy klucz. Lepiej przykładu w ogóle nie wklejać.

Odpada traktowanie gitleaks jako lokalnej ciekawostki bez checka. Wtedy sekret wchodzi na
`develop` i zostaje w historii. Lokalny przebieg przed pushem jest przydatny i nie zastępuje
rulesetu. Osoba może nie odpalić narzędzia. Runner odpala je na każdym pull requeście do
trzech gałęzi i w poniedziałek na `develop`.

Odpada też skaner, który wymaga konta i tokenu w workflow, żeby w ogóle ruszyć. gitleaks w
jobie nie potrzebuje sekretu, żeby szukać sekretu. Token w YAML, „żeby skaner miał się czym
uwierzytelnić”, byłby sekretem tego numeru w pliku, który ten numer ma czyścić.
`permissions` zostają przy `contents: read`. `persist-credentials: false`. OpenBao nie jest
wołany.

Koszt: fałszywe trafienie w fixture testowym albo w przykładzie dokumentacji blokuje merge.
Fixture bramki, które celowo zawierają kształt klucza, leżą poza drzewem skanowanym w CI.
Wyciszenie gitleaks jest w `.gitleaks.toml`, z powodem, nie w interfejsie. Allow na jedną
ścieżkę dokumentacji jest wąski. Szerokie wyciszenie całego `docs/` schowałoby prawdziwy
ciąg wklejony w akapit. Ten plik takiego ciągu nie ma i allow nie jest pretekstem, żeby go
dodać.

### zizmor na workflowach

Job `zizmor` uruchamia `zizmor --offline` na `.github/workflows` i `.github/actions`, gdy
ten drugi katalog powstanie. Tryb offline nie woła API GitHuba i nie potrzebuje tokenu.
Każde trafienie kończy job kodem `1`. Nie ma progu „średnie przepuszczamy”. Wyjątek jest
wpisem w konfiguracji zizmor obok workflow, z jedną linijką powodu, i dotyczy jednej reguły
oraz jednej ścieżki. Na start `.github/zizmor.yml` ma jawną pustą listę wyjątków, żeby było
widać, że wyjątków nie ma.

`zizmor` czyta to, czego sam `actionlint` nie czyta jako ryzyka. Składnia YAML może być
poprawna, a wyzwalacz `pull_request_target` i tak uruchamia workflow w kontekście
repozytorium bazowego. Nadmiar `permissions`, trwałe poświadczenia checkoutu i wstrzyknięcie
z `github.event` też są trafieniami. Dla JJDevHub konkret jest taki: pull request funkcji
`feature/lesson-markdown` jeszcze nie niesie usługi, a już niesie workflow. Obcy fork nie
powinien dostać przebiegu z checkoutem swojej głowy i z prawem zapisu. Pusta lista wyjątków
znaczy, że pierwsza wersja tych plików nie ma świadomego odstępstwa.

Odpada sam `actionlint` w tej roli. `actionlint` sprawdza składnię. zizmor sprawdza
`pull_request_target`, nadmiar `permissions`, trwałe poświadczenia checkoutu i wstrzyknięcie
z `github.event`. Oba narzędzia zostają. `actionlint` jest w sekcji testów każdego numeru.
zizmor jest checkiem na `develop`, `release` i `main`. Składnia bez ryzyka to za mało.
Ryzyko bez składni i tak nie wejdzie, bo `actionlint` pada wcześniej na pliku, który się nie
parsuje. Ten numer nie składa ich w jeden check. Nazwy w rulesecie zostają osobne tam, gdzie
osobne jest pytanie. Runner i pin są wyjątkiem opisanym przy `action-pins`, nie przy zizmor.

Odpada próg, który przepuszcza trafienie „informacyjne” albo „średnie”. Jedno trafienie jest
porażką joba. `--min-severity` i `--no-exit-codes` nie wchodzą do wywołania. Werdykt jest
kodem wyjścia. Wynik w SARIF i upload do zakładki Security są opcjonalne, tak jak w CodeQL.
Gdy upload wymaga produktu, którego repozytorium nie ma, krok uploadu ma
`continue-on-error: true` i nie zamienia czerwonego zizmor na zielony job. Format, który
przy trafieniu kończy się zerem, nie jest werdyktem tego numeru.

Koszt: nowa reguła zizmor po aktualizacji narzędzia może zaczerwienić istniejący, wcześniej
zielony workflow. Wersja zizmor jest przypięta w workflow tak samo jak inne narzędzia,
komentarzem wersji i sumą w `.github/supply-chain/checksums.txt`. Podbicie jest osobnym pull
requestem `ci:`. W tym pull requeście widać, która reguła doszła. Wyjątek, jeśli naprawdę
jest potrzebny, jest jedną linijką powodu przy jednej regule i jednej ścieżce. Pusta lista
na start nie jest miejscem na „wyłączmy wszystko, aż będzie zielono”.

### Pełny SHA i komentarz wersji

Każde `uses` wskazujące cudzą akcję ma postać:

```text
właściciel/akcja@<40 znaków hex> # vX.Y.Z
```

Skrypt `check-action-pins.sh` pada, gdy:

- po `@` jest tag (`@v4`, `@main`, `@latest`)
- SHA jest krótszy niż 40 znaków
- brak komentarza z wersją zaczynającą się od `v`
- użyto `docker://` bez `sha256`

Dozwolone bez SHA: `uses: ./.github/workflows/…` i `uses: ./.github/actions/…`. Akcja
lokalna i tak jest w tym samym pull requeście, a zizmor ją czyta. Cudza akcja bez komentarza
wersji pada nawet przy pełnym SHA. Komentarz jest dla człowieka, który czyta diff. SHA jest
dla runnera. Oba są wymagane. Sam numer przy `@v4` nie wystarcza, bo tag da się przesunąć.

`check-runners.sh` przechodzi `*.yml` w `.github/workflows`. Pada, gdy znajdzie
`self-hosted`, `pull_request_target` albo `runs-on` inne niż `ubuntu-latest`. Woła go job
`action-pins`, żeby runner i pin były jednym miejscem „czy workflow wolno scalić”. Każdy job
numerów `01` – `07` używa `ubuntu-latest`. Runner własny nie wchodzi. `pull_request_target`
nie wchodzi. Log mówi, który z dwóch skryptów padł, więc czerwony check da się rozróżnić bez
drugiej nazwy w rulesecie.

Problem jest konkretny na workflow, które już istnieją. Checkout i `setup-dotnet` z numeru
`05`, akcja release-please z numeru `07` i akcje z numerów `01` – `04` mają w pliku pełny
SHA i komentarz `# vX.Y.Z`. Włączenie checka na workflow, który sam łamie pin, zablokuje
każdy merge. Najpierw piny, w tym samym pull requeście co nowy job. `docker://` bez `sha256`
pada tak samo jak `@v4`. Obraz akcji wskazany tagiem jest tym samym ruchomym celem.

Odpada pin do tagu głównej wersji. Tag da się przesunąć na inny commit. Recenzja i przebieg
rozjeżdżają się bez zmiany pliku w gitcie. Odpada pin „bo Dependabot i tak podbije”.
Dependabot może podbijać, a bramka i tak wymaga, żeby w pliku był SHA. Pull request
Dependabota przechodzi `action-pins` albo pada. Samo podbicie numerka przy `@v4` nie jest
zmianą, którą ten check rozumie jako pin.

Odpada osobny check o nazwie runnera. Pytanie „czy wolno scalić workflow” jest jedno: pin,
komentarz, `ubuntu-latest`, brak `self-hosted`, brak `pull_request_target`. Dwie nazwy w
rulesecie dublowałyby ten sam plik. `actionlint` nie wymusza SHA. Dlatego pin jest osobnym
checkiem, a nie krokiem w teście lokalnym wyłącznie. `actionlint` zostaje w sekcji testów i
kończy się kodem `0` na czterech workflowach. Zielony `actionlint` przy `@v4` jest
oczekiwany. Czerwony jest `check-action-pins.sh`.

Koszt: podbicie akcji jest edycją SHA i komentarza, nie samą zmianą numerka przy `@v4`. To
jest kilka minut i jest celem tego numeru. Komentarz wersji da się rozjechać ze SHA, jeśli
ktoś zaktualizuje tylko jedną stronę. Przegląd pull requestu `ci:` patrzy na obie. Skrypt
wymusza obecność komentarza zaczynającego się od `v`. Nie wymusza, żeby numer w komentarzu
był kryptograficznie związany z obiektem gita. Związek jest SHA. Komentarz jest
czytelnością.

### Scorecard lokalnie, bez tokenu

Job `scorecard` woła `scorecard --local .` i czyta JSON. Blokuje, gdy któraś z tych sond ma
wynik niższy niż `10`:

| Sonda | Co czyta |
| --- | --- |
| `Dangerous-Workflow` | niebezpieczne wzorce w workflow |
| `Token-Permissions` | uprawnienia tokenu w plikach |
| `Pinned-Dependencies` | piny w workflow, Dockerfile i skryptach |

Pozostałe sondy trafiają do podsumowania joba i nie blokują. Część z nich pyta usługę
GitHuba o historię maintainerów, recenzje albo podpisy wydań. Lokalny przebieg bez tokenu
nie ma tych danych. Wpuszczenie tokenu do joba, żeby podnieść punktację odznaki, jest poza
tym numerem. Odznaka nie jest bramką. `scorecard-gate.sh` czyta JSON i porównuje trzy sondy
z progiem `10`. Inne sondy dopisuje do `$GITHUB_STEP_SUMMARY`, gdy zmienna istnieje, a
lokalnie drukuje na stdout. Brak którejś z trzech sond w JSON to kod `1`.

Na plikach JJDevHub te trzy sondy mają być maksymalnie ocenione, bo pliki naprawdę je
spełniają. `Dangerous-Workflow` widzi brak `pull_request_target` i brak wzorca, który
uruchamia obcy kod z prawem zapisu. `Token-Permissions` widzi `permissions` ustawione w
pliku, w tym `contents: read` na pull requeście, a nie szeroki token wpisany jako sekret.
`Pinned-Dependencies` widzi SHA w `uses` i `sha256` przy `docker://`. Wynik `-1` na
`ubuntu-latest` pada. Niejasny wynik nie jest sukcesem. Na runnerze GitHuba ścieżki są
uniksowe i lokalny tryb te trzy sondy widzi.

Odpada traktowanie pojedynczej liczby „Scorecard 7.5” jako progu. Ta liczba miesza sondy
plikowe z sondami, których ten job świadomie nie zasila. Sonda o podpisanych wydaniach albo
o recenzjach maintainerów potrafi ściągnąć średnią, choć workflow jest przypięty i
uprawnienia są wąskie. Bramka na średniej karałaby repozytorium za brak tokenu albo
nagradzała je za token w jobie. Oba wyjścia są poza tym numerem. Trzy sondy z tabeli mają
próg `10`. Reszta jest w podsumowaniu, żeby było widać, co lokalny przebieg w ogóle
zmierzył.

Odpada też odpalenie Scorecard tylko jako odznaki w README. Odznaka nie blokuje merge. Job
`scorecard` jest w trzech rulesetach. Suchy przebieg, gdy binarka z `checksums.txt` jest na
ścieżce, woła trzy sondy i przekazuje JSON do `scorecard-gate.sh`. Kod `0` oznacza trzy
dziesiątki. Kod `1` oznacza wynik poniżej `10`, wynik `-1` albo brak sondy w JSON.

Koszt: `Pinned-Dependencies` potrafi wymagać skrótu także w Dockerfile, gdy Dockerfile już
jest. Do tego czasu brak Dockerfile nie obniża sondy do porażki joba, jeśli reszta pinów w
workflow jest kompletna. Gdy pojawi się Dockerfile komponentu, pin obrazu wchodzi w tę samą
sondę. Osobnego progu „Dockerfile później” nie ma. Jest stan repozytorium: nie ma pliku, nie
ma w nim nieprzypiętej zależności. Jest plik, skrót ma w nim być.

Wersje narzędzi (gitleaks, zizmor, scorecard) są przypięte w workflow do wydania i do sumy
kontrolnej pliku release, nie do tagu „latest” ściąganego w locie bez sumy. Krok, który
ściąga binarkę, porównuje sumę z pliku `.github/supply-chain/checksums.txt` trzymanego w
repozytorium. Zmiana wersji narzędzia zmienia ten plik w pull requeście `ci:`. Workflow nie
przyjmuje innej wersji niż wiersz w tym pliku. `timeout-minutes` czterech jobów to `15`.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/gitleaks.yml` | job `gitleaks` |
| `.github/workflows/zizmor.yml` | job `zizmor` |
| `.github/workflows/action-pins.yml` | job `action-pins` |
| `.github/workflows/scorecard.yml` | job `scorecard` |
| `.gitleaks.toml` | reguły i ścieżki SOPS oraz `.env` |
| `.github/scripts/check-no-sops.sh` | nazwy plików, niezależnie od entropii |
| `.github/scripts/check-action-pins.sh` | SHA i komentarz wersji |
| `.github/scripts/check-runners.sh` | zakaz `self-hosted` i `pull_request_target` |
| `.github/scripts/scorecard-gate.sh` | próg trzech sond |
| `.github/zizmor.yml` | wyjątki, na start puste |
| `.github/supply-chain/checksums.txt` | suma binarek gitleaks, zizmor i scorecard |
| `.github/rulesets/develop.json` | cztery nowe checki |
| `.github/rulesets/release.json` | te same, bo ciąg z `develop` obowiązuje dalej |
| `.github/rulesets/main.json` | te same |

Wyzwalacz czterech workflowów: `pull_request` na `develop`, `release` i `main`, bez `paths`.
Dodatkowo `schedule` z cronem `0 6 * * 1` i `push` na `develop` dla powtórki, przy czym
ruleset i tak czyta status z pull requestu. `push` na `develop` nie zastępuje checka na pull
requeście.

`permissions`: `contents: read`. Checkout `persist-credentials: false`. `fetch-depth: 0`
tylko w `gitleaks`. Reszta może wziąć `fetch-depth: 1`. `timeout-minutes: 15`.
`runs-on: ubuntu-latest`. W plikach workflow nie ma `secrets.`. Nie ma `self-hosted`. Nie ma
`pull_request_target`.

`checksums.txt` ma wiersz z nazwą narzędzia, wersją i sumą SHA256 paczki wydania używanej na
`ubuntu-latest`. Job nie ściąga „latest” bez porównania sumy. Rozjazd sumy jest czerwoną
komendą, zanim narzędzie w ogóle skanuje drzewo.

Cztery nazwy w rulesetach to `gitleaks`, `zizmor`, `action-pins` i `scorecard`. Sync jest z
numeru `01`. Ten numer dopisuje je w scaleniu, które dodaje workflow. Włączenie checka na
nieprzypiętych YAML-ach z numerów `01` – `05` blokuje każdy merge, więc piny wchodzą w tym
samym pull requeście.

## Plan

### 1. Dodać konfigurację gitleaks i zakaz SOPS

Utwórz `.gitleaks.toml` i `check-no-sops.sh`. Skrypt kończy się kodem `1`, gdy
`git ls-files` pokaże nazwę z listy SOPS albo `.env` inny niż `.env.example`. Dla
`.env.example` kończy się kodem `1`, gdy któraś linia ma znak niebędący pustą spacją po
pierwszym `=`.

Utwórz `gitleaks.yml`. Job woła najpierw `check-no-sops.sh`, potem
`gitleaks detect --redact --source . --config .gitleaks.toml`. Checkout `fetch-depth: 0`.

### 2. Dodać piny i runner

Utwórz `check-action-pins.sh` i `check-runners.sh` oraz `action-pins.yml`, który woła oba.
Przejrzyj workflowi z numerów `01` – `05` i popraw `uses` do pełnego SHA z komentarzem, w
tym samym scaleniu albo w scaleniu bezpośrednio poprzedzającym włączenie tego checka.
Włączenie checka na workflow, który sam łamie pin, zablokuje każdy merge. Najpierw piny, w
tym samym pull requeście co nowy job.

### 3. Dodać zizmor

Utwórz `zizmor.yml` i pusty `.github/zizmor.yml` z jawną pustą listą wyjątków, żeby było
widać, że wyjątków nie ma. Job woła `zizmor --offline`. Pada na pierwszym trafieniu, kodem
`1`.

### 4. Dodać Scorecard

Utwórz `scorecard-gate.sh` i `scorecard.yml`. Skrypt czyta JSON i porównuje trzy sondy z
progiem `10`. Inne sondy dopisuje do `$GITHUB_STEP_SUMMARY`, gdy zmienna istnieje, a
lokalnie drukuje na stdout. Brak którejś z trzech sond w JSON to kod `1`. Wynik `-1` to kod
`1`.

### 5. Dodać sumy narzędzi

Utwórz `.github/supply-chain/checksums.txt` z nazwą narzędzia, wersją i sumą SHA256 paczki
wydania używanej na `ubuntu-latest`. Workflow nie przyjmuje innej wersji niż wiersz w tym
pliku.

### 6. Dopisać checki do trzech rulesetów

W scaleniu, które dodaje cztery workflowy, dopisz `gitleaks`, `zizmor`, `action-pins` i
`scorecard` do `develop.json`, `release.json` i `main.json`. `gitleaks` jest w tabeli bramki
`develop` w [02-bramki.md](02-bramki.md). Trzy pozostałe dokładają się tutaj, bo zły
workflow nie może czekać na `release`.

### 7. Przejrzeć istniejące YAML-e pod kątem sekretu

W tym samym pull requeście `grep` po `.github/workflows` nie znajduje `secrets.` poza
sytuacją, której ten numer nie przewiduje. Jeśli jakiś wcześniejszy szkic workflow miał
token, usuń go, zanim check zacznie obowiązywać. OpenBao nie jest w tych plikach. Dopisz
`schedule` cron `0 6 * * 1` i `push` na `develop` obok `pull_request` na trzy gałęzie.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `gitleaks.yml` | pull request na trzy gałęzie | check `gitleaks` |
| `.gitleaks.toml` | gitleaks | te same reguły lokalnie i w CI |
| `check-no-sops.sh` | job `gitleaks` | nazwa pliku, nie tylko entropia |
| `zizmor.yml` | pull request | check `zizmor` |
| `.github/zizmor.yml` | zizmor | pusta lista wyjątków |
| `action-pins.yml` | pull request | check `action-pins` |
| `check-action-pins.sh` | ten job i suchy przebieg | SHA oraz komentarz |
| `check-runners.sh` | ten sam job | `ubuntu-latest` i zakaz `pull_request_target` |
| `scorecard.yml` | pull request | check `scorecard` |
| `scorecard-gate.sh` | job `scorecard` | trzy sondy, nie średnia |
| `checksums.txt` | kroki instalacji narzędzi | powtarzalna binarka |
| trzy JSON-y rulesetów | sync z numeru `01` | cztery checki wymagane |

Żaden z tych jobów nie woła OpenBao i nie odkłada sekretu do artefaktu.

## Testy

`actionlint`:

```bash
actionlint \
  .github/workflows/gitleaks.yml \
  .github/workflows/zizmor.yml \
  .github/workflows/action-pins.yml \
  .github/workflows/scorecard.yml
```

Kod `0`.

Suchy przebieg pinów na własnych workflowach:

```bash
.github/scripts/check-action-pins.sh .github/workflows
.github/scripts/check-runners.sh .github/workflows
```

Oba kody `0` po tym, jak YAML-e mają SHA.

Przykład pinu, który ma paść. Plik tymczasowy poza repozytorium:

```bash
f=$(mktemp)
printf '%s\n' 'jobs:' '  t:' '    runs-on: ubuntu-latest' '    steps:' \
  '      - uses: actions/checkout@v4' > "$f"
.github/scripts/check-action-pins.sh "$f"; echo $?
rm -f "$f"
```

Kod `1`, bo `@v4` nie jest pełnym SHA i nie ma komentarza wersji.

Suchy przebieg SOPS, też poza repozytorium:

```bash
dir=$(mktemp -d)
touch "$dir/app.sops.yaml"
.github/scripts/check-no-sops.sh --root "$dir"; echo $?
rm -rf "$dir"
```

Kod `1`.

Gitleaks na katalogu tymczasowym z oczywistym sekretem testowym (ciąg budowany w powłoce,
nie w tym pliku dokumentacji). Oczekiwany kod `1` i log bez powtórzenia pełnego ciągu,
dzięki `--redact`. Katalog tymczasowy skasuj. Nie dodawaj go do `git add`.

Zła gałąź:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. Poprawne `feature/lesson-markdown` do `develop` daje kod `0`. Na takim pull
requeście `gitleaks` i `zizmor` oceniają prawdziwe pliki, także gdy nie ma jeszcze `csproj`.

Scorecard lokalnie, gdy binarka z `checksums.txt` jest na ścieżce:

```bash
scorecard --local . --checks Dangerous-Workflow,Token-Permissions,Pinned-Dependencies --format json \
  | .github/scripts/scorecard-gate.sh
```

Kod `0`, gdy trzy sondy mają `10`. Wynik `-1` albo poniżej `10` daje kod `1`.

`grep -R 'secrets\.' .github/workflows` nie znajduje trafień.

Te przebiegi da się odpalić zanim powstanie pierwsza usługa. Fixture z `@v4` i fixture z
`app.sops.yaml` żyją w katalogu tymczasowym i nie wchodzą do commita. Sekret testowy
gitleaks też zostaje w powłoce, poza tym plikiem. Na pull requeście
`feature/lesson-markdown` cztery checki czytają prawdziwe workflow, nawet gdy diff jest samą
dokumentacją.

## Zasady

- Sekret aplikacji, token, hasło i connection string z hasłem nie wchodzą do gita.
- Plik SOPS i plik `*.enc.yaml` nie wchodzą do gita.
- `.env` nie wchodzi. `.env.example` ma puste wartości.
- `gitleaks` jest wymagany na `develop`, `release` i `main`.
- `zizmor`, `action-pins` i `scorecard` też.
- Każde cudze `uses` ma 40-znakowy SHA i komentarz `# v…`.
- `pull_request_target` i `self-hosted` nie występują.
- Każdy job `01` – `07` używa `ubuntu-latest`.
- Scorecard blokuje na trzech sondach plikowych. Nie blokuje na średniej z sond, które
  wymagają tokenu.
- Wynik sondy `-1` jest porażką joba `scorecard`.
- Wyjątek zizmor i wyciszenie gitleaks są w pliku w repozytorium, z powodem, nie w
  interfejsie.
- Każde trafienie `zizmor --offline` kończy job kodem `1`.
- Ten numer nie tworzy magazynu sekretów i nie czyta OpenBao.
- W workflow nie ma wyrażenia `secrets.`.
- `docker://` bez `sha256` pada w `check-action-pins.sh`.
- Harmonogram jest ten sam co w numerze `04`: cron `0 6 * * 1` na `develop`.

## Poza zakresem

| Temat | Numer |
| --- | --- |
| OpenBao na VM, vTPM, poświadczenie bazy | [14-openbao.md](14-openbao.md) |
| OpenBao w AppHost i user secrets | [docs/api/04-openbao.md](../api/04-openbao.md) |
| CVE paczek i obrazów | [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md) |
| CodeQL | [03-codeql.md](03-codeql.md) |
| SonarQube | [05-sonarqube.md](05-sonarqube.md) |
| Nazwa gałęzi | [01-galezie.md](01-galezie.md) |
| Deploy | [16-deploy.md](16-deploy.md) |

User secrets na laptopie nie są plikiem w repozytorium. Ten numer ich nie opisuje poza
zakazem wrzucenia ich do gita. Nie opisuje polityk OpenBao, poświadczenia bazy ani vTPM. Nie
skanuje CVE. Nie liczy pokrycia. Nie nadaje tagu komponentu.

## Źródła

- [gitleaks](https://github.com/gitleaks/gitleaks). Wiążące są `detect`, `--redact`,
  `--source` i plik konfiguracji. Dotyczy polecenia
  `gitleaks detect --redact --source . --config .gitleaks.toml` oraz logu, który pokazuje
  regułę i plik. Ze źródła nie bierzemy podmiany tego polecenia na inne podpolecenie w tym
  numerze. Job zostaje przy `detect`. Nie bierzemy skanera, który potrzebuje tokenu, żeby w
  ogóle ruszyć.
- [README gitleaks](https://github.com/gitleaks/gitleaks/blob/master/README.md). Wiążące są
  flaga `--redact`, flaga `--config` i to, że konfiguracja w `.gitleaks.toml` rozszerza
  reguły domyślne. Dotyczy allow na jedną ścieżkę `docs/cicd/` tylko dla jawnie fałszywego
  ciągu oraz ścieżek SOPS i `.env` dokładanych obok reguł entropii. Ze źródła nie bierzemy
  wyciszenia całego drzewa i nie bierzemy przykładu prawdziwego klucza w dokumentacji. Ten
  plik takiego kształtu nie zawiera.
- [zizmor](https://docs.zizmor.sh/). Wiążące są audyty workflow bez stawiania własnego
  serwera. Dotyczy checka `zizmor` na `.github/workflows` i na `.github/actions`, gdy ten
  drugi katalog powstanie. Ze źródła nie bierzemy akcji `zizmorcore/zizmor-action` jako
  zamiennika joba. Binarka jest przypięta wersją i sumą w `checksums.txt`. Werdykt jest
  kodem wyjścia, nie odznaką w README.
- [zizmor, użycie](https://docs.zizmor.sh/usage/). Wiążący jest tryb `--offline`: brak
  wywołań API i brak tokenu. Dotyczy joba, który nie czyta `secrets.` i nie potrzebuje
  `GITHUB_TOKEN` do audytu. Strona opisuje też kody procesu, w tym kody powyżej `10` dla
  trafień różnej wagi oraz kod `0` przy braku trafień. W tym numerze każde trafienie kończy
  job kodem `1`. Ze źródła nie bierzemy `--no-exit-codes`, nie bierzemy `--min-severity` i
  nie bierzemy formatu, który przy trafieniu kończy się zerem. Średnie trafienie nie
  przechodzi.
- [zizmor, audyty](https://docs.zizmor.sh/audits/). Wiążące są audyty, które widzą
  `pull_request_target`, nadmiar uprawnień i wstrzyknięcie z kontekstu zdarzenia, także
  offline. Dotyczy zakazu `pull_request_target` w `check-runners.sh` i pustej listy wyjątków
  w `.github/zizmor.yml`. Ze źródła nie bierzemy wyjątku bez jednej linijki powodu. Wyjątek,
  gdy kiedyś powstanie, dotyczy jednej reguły i jednej ścieżki.
- [zizmor, integracja](https://docs.zizmor.sh/integrations/). Wiążące jest to, że upload
  SARIF nie zastępuje kodu wyjścia. Dotyczy opcjonalnego kroku uploadu z
  `continue-on-error: true`, który nie zamienia czerwonego zizmor na zielony job. Ze źródła
  nie bierzemy werdyktu opartego na SARIF, gdy ten format przy trafieniu zwraca zero. Nie
  bierzemy produktu Security, którego repozytorium może nie mieć, jako warunku scalenia.
  Werdykt zostaje kodem `1` przy trafieniu.
- [OpenSSF Scorecard](https://github.com/ossf/scorecard). Wiążące są `--local` i nazwy sond.
  Dotyczy joba `scorecard`, który czyta JSON i nie dostaje tokenu do podnoszenia odznaki. Ze
  źródła nie bierzemy jednej liczby „Scorecard 7.5” jako progu. Odznaka nie jest bramką. Nie
  bierzemy sond, które pytają usługę o maintainerów, jako warunków scalenia.
- [Scorecard checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md). Wiążące są
  trzy sondy plikowe: `Dangerous-Workflow`, `Token-Permissions` i `Pinned-Dependencies`,
  oraz wynik `-1` przy braku danych. Dotyczy progu `10` w `scorecard-gate.sh` i kodu `1`,
  gdy wyniku nie ma albo jest za niski. Ze źródła nie bierzemy pozostałych sond jako
  blokady. Trafiają do podsumowania. Brak Dockerfile nie jest porażką, dopóki w workflow
  piny są kompletne. Gdy Dockerfile jest, skrót w nim podlega tej samej sondzie.
- [Security hardening for GitHub
  Actions](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions).
  Wiążące są pełny SHA zamiast tagu, jawne `permissions` i ryzyko `pull_request_target` z
  checkoutem głowy. Dotyczy postaci `uses` z 40 znakami hex i komentarzem `# vX.Y.Z` oraz
  zakazu `pull_request_target` i `self-hosted`. Ze źródła nie bierzemy pinu do `@v4` „bo to
  główna wersja”. Tag da się przesunąć. Nie bierzemy runnera innego niż `ubuntu-latest`.
- [Automatic token
  authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication).
  Wiążące jest to, że `GITHUB_TOKEN` przebiegu jest uprawnieniem, nie wartością wpisaną do
  pliku. Dotyczy `permissions: contents: read` i `persist-credentials: false` oraz tego, że
  atestacja z numeru `04` używa `id-token` i `attestations`, a nie sekretu produktu. Ze
  źródła nie bierzemy wyrażenia `secrets.` w workflow numerów `01` – `07`. `grep` ma być
  pusty. OpenBao nie jest tu czytany.
- [Events that trigger
  workflows](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows).
  Wiążące są `pull_request`, `push` i `schedule`. Dotyczy wyzwalacza na `develop`, `release`
  i `main` oraz cronu `0 6 * * 1`, tego samego co zależności w numerze `04`. Ze źródła nie
  bierzemy `pull_request_target`. Ze źródła nie bierzemy `paths`, które wyłączyłyby check na
  zmianie samego workflow. `push` na `develop` nie zastępuje statusu na pull requeście.
- [actionlint](https://github.com/rhysd/actionlint). Wiążąca jest składnia czterech
  workflowów. Dotyczy `actionlint` z kodem `0` na `gitleaks.yml`, `zizmor.yml`,
  `action-pins.yml` i `scorecard.yml`. Ze źródła nie bierzemy actionlint jako zamiennika
  pinów SHA. Plik tymczasowy z `uses: actions/checkout@v4` kończy `check-action-pins.sh`
  kodem `1`, choć składnia YAML może być poprawna.

## Gotowe gdy

- Są cztery workflowy, `.gitleaks.toml`, pusta konfiguracja zizmor, `checksums.txt` i
  skrypty `check-no-sops.sh`, `check-action-pins.sh`, `check-runners.sh` oraz
  `scorecard-gate.sh`.
- `actionlint` na czterech workflowach kończy się kodem `0`.
- `check-action-pins.sh` i `check-runners.sh` na `.github/workflows` kończą się kodem `0`.
- Plik tymczasowy z `uses: actions/checkout@v4` kończy `check-action-pins.sh` kodem `1`.
- Katalog tymczasowy z `app.sops.yaml` kończy `check-no-sops.sh` kodem `1`.
- `grep` nie znajduje `secrets.` w `.github/workflows`.
- `feature/lesson_markdown` pada kodem `1` w `check-branch-name.sh`.
- Trzy rulesety wymagają `gitleaks`, `zizmor`, `action-pins` i `scorecard`.
- W repozytorium nie ma pliku `*.sops.yaml` ani `.env` z wartością.
- `gitleaks detect` idzie z `--redact` i z checkoutem `fetch-depth: 0`.
- `zizmor --offline` kończy job kodem `1` przy każdym trafieniu.
- Trzy sondy Scorecard mają próg `10`. Wynik `-1` daje kod `1`.
- Cudze `uses` ma 40 znaków hex i komentarz `# vX.Y.Z`. `docker://` ma `sha256`.
- Nie ma `self-hosted` ani `pull_request_target`. OpenBao nie jest w tych plikach.
