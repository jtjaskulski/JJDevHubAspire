# 16. Deploy

Ten numer wstawia na maszynę jeden komponent, z tagu nadanego na `main` po bramkach.
Poprzedni plik, [skalowanie](15-skalowanie.md), trzyma próg drugiego poda.
Następnego pliku w tym folderze nie ma. W kolejności pracy poprzedni krok to
[brama](../api/16-gateway.md), a następny to [Identity](../api/17-identity.md).
To nie jest ostatni krok produktu. Jest klaster, jest tunel, jest OpenBao.
Drugiego poda jeszcze nie ma. Tag i bramki powstają w numerach
[01-galezie.md](01-galezie.md)–[07-wersje.md](07-wersje.md). Ten
numer nie nadaje tagu. Bierze tag, który już jest, i stawia odpowiadający mu digest.

Scenariusz, który bez osobnego kroku się rozpada, zaczyna się od tagu `news-v1.4.0`. Sam tag
jest etykietą gita. Obrazu na maszynie nie ma, dopóki job nie wypchnie digestu i nie
podmieni jednego Deploymentu. Krok, który przy tym tagu stosuje całe drzewo `deploy/k3s`,
przebudowuje sąsiadów, którzy tego commita nie dostali: Identity wraca do manifestu z
gałęzi, Grafana dostaje restart, a `cloudflared` na chwilę gubi tunel. Jeden przebieg
zmienia jeden komponent. Reszta zostaje na swoim digescie.

Drugi scenariusz psuje się przy cofaniu. Gałąź `hotfix/news` buduje stary kod jeszcze raz.
Powstaje inny digest, często bez tamtej atestacji, a `GET /versions` zaczyna pokazywać
numer, którego żaden tag nie opisuje. Rollback jest poprzednim tagiem tego samego
komponentu, puszczonym przez `workflow_dispatch` tego samego pliku. Nowej gałęzi nie ma.
Nowego commitu „tylko na produkcję” nie ma.

## Po co

Tag `news-v1.4.0` znaczy, że News na tym commicie przeszedł bramki i ma numer. Bez jobu
deployu tag zostaje etykietą. Z jobem, który wdraża cały katalog naraz, etykieta jednego
komponentu rusza magazyny i telemetrię. Postgres, Redis, Kafka, OpenBao, collector,
Prometheus, Jaeger, Grafana i `cloudflared` nie są komponentem tagu. Przebieg ich nie
restartuje i nie stosuje ich manifestów drugi raz.

Na klaster wchodzi digest `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Tag rejestru
`:latest` albo `:news-v1.4.0` jako jedyna referencja w żywym Deploymentcie odpada: tag w
rejestrze da się przepiąć, digest nie. Obraz lokalny `jjdevhub/<komponent>:scan` z bramki
numeru 04 nie jest tym obrazem i nie jedzie na maszynę. Bramka ogląda obraz, którego nie ma
w rejestrze. Na klaster wchodzi digest z jobu `publish`, i tylko po udanym
`gh attestation verify` wobec właściciela `jtjaskulski`.

Job `publish` buduje na `ubuntu-latest`. Job `deploy` nie buduje. Stoi na runnerze
`runs-on: [self-hosted, jjdevhub]`, w środowisku `production`, i woła `kubectl` dopiero po
weryfikacji obu atestacji. Drugiej budowy na gościu nie ma. Digest na klastrze jest digestem
dopiero co zweryfikowanym, nie digestem złożonym drugi raz z innego kontekstu.

Stopka weba i ekran O aplikacji już pokazują swój numer. Deploy, który podmienia obraz
zbudowany bez tego numeru, kłamie na ekranie wobec `GET /versions`. Obraz `web` z tagu
`web-vX.Y.Z` ma w stopce tekst `web-vX.Y.Z`. Artefakt `mobile` z tagu `mobile-vX.Y.Z` ma na
ekranie O aplikacji tekst `mobile-vX.Y.Z`. Brak tekstu kończy przebieg. `mobile` nie dostaje
`kubectl` i nie dostaje poda. `service.version` na podzie jest tagiem, tym samym, który
numer 10 kazał trzymać w `OTEL_RESOURCE_ATTRIBUTES`. Pole w `GET /versions` zgadza się z tym
tagiem w kształcie, który zwraca brama, i nie podmienia wersji sąsiadów.

Pierwszy udany przebieg komponentu, którego Deployment z numeru 08 ma `replicas: 0`, ustawia
co najmniej jedną replikę. Nie ustawia dwóch. Drugi pod jest decyzją progu z numeru 15, nie
decyzją tagu. AppHost nie jest deployowany. Na maszynie nie wstaje dashboard Aspire.

## Dlaczego ta technologia

### Tylko tag komponentu na main

Wejściem jest tag `<komponent>-vX.Y.Z`. Komponenty: `identity`, `news`, `learning`, `cv`,
`contact`, `gateway`, `web`, `mobile`. Przykład: `news-v1.4.0`. Wzorzec jest ten sam co w
numerze 07:

```text
^(identity|news|learning|cv|contact|gateway|web|mobile)-v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$
```

`news-v1.4` odpada, bo brakuje części. `news-v1.4.0-rc.1` odpada, bo przyrostek nie
przechodzi wzorca. `blog-v1.0.0` odpada, bo nie ma takiego komponentu. `v1.4.0` odpada, bo
nie ma prefiksu. Tag powstaje na `main` po zielonych bramkach. Job sprawdza, że commit tagu
jest przodkiem albo samym czubkiem `main` (`git merge-base --is-ancestor`), i odrzuca tag
wskazujący commit spoza tej gałęzi.

Deploy z `develop`, `release` albo `feature/…` odpada. Tamte gałęzie nie są produkcją.
Deploy „wszystkiego, co na `main`” odpada, bo `main` może nieść jeden nowy tag News i stare
tagi reszty. Reszta ma zostać na swoim digescie. Ręczne `kubectl set image` z laptopa jako
droga zwykłego wydania odpada: nie zostawia przebiegu, nie sprawdza atestacji i daje się
zrobić z obrazu, który nie ma tagu.

Koszt: każdy komponent ma własny numer i własne wydanie. Poprawka w News i w Identity to dwa
tagi i dwa przebiegi, w dowolnej kolejności. Jeden przebieg, który „przy okazji” podmienia
bramę, bo commit dotknął wspólnego pliku, jest błędem. Wejściem jest nazwa przed `-v`, nie
lista plików w commicie. Zmiana kernela, która w numerze 07 wycina pięć tagów, daje pięć
przebiegów, nie jeden zbiorczy.

### Jeden obraz, po digescie, po atestacji

Job `publish` na `ubuntu-latest` buduje z tagu tylko Dockerfile tego komponentu. Ścieżki są
z [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md):
`src/services/<Usługa>/Dockerfile`, `src/gateway/Dockerfile`, `src/clients/web/Dockerfile`,
`src/clients/mobile/Dockerfile`. Wypycha
`ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Ten sam job składa atestację
pochodzenia i atestację SBOM, akcjami `actions/attest-build-provenance` i
`actions/attest-sbom`, tymi samymi co numer 04, przypiętymi do pełnego SHA z komentarzem
wersji.

Job `deploy` rozwiązuje ten digest i przed zmianą Deploymentu uruchamia weryfikację wobec
właściciela `jtjaskulski`. Jedno wołanie sprawdza pochodzenie. Drugie sprawdza SBOM. Kod
wyjścia inny niż zero kończy przebieg. `kubectl` się nie wykonuje. Na klastrze zostaje
poprzedni digest.

```bash
gh attestation verify oci://ghcr.io/jtjaskulski/jjdevhub-news@sha256:<digest> \
  --owner jtjaskulski
gh attestation verify oci://ghcr.io/jtjaskulski/jjdevhub-news@sha256:<digest> \
  --owner jtjaskulski \
  --predicate-type https://spdx.dev/Document
```

Nazwa `news` i skrót są z tagu tego przebiegu. Dla innego komponentu zmienia się tylko nazwa
obrazu. Pominięcie weryfikacji, bo bramka i tak była zielona, odpada. Bramka ogląda
`jjdevhub/<komponent>:scan`. Na klaster wchodzi inny digest, ten z rejestru, i tylko on ma
atestację wydania.

Tag pływający w manifeście odpada. Po przepięciu `:news-v1.4.0` w GHCR kubelet przy
następnym restarcie poda może ściągnąć inny digest niż ten, który `gh attestation verify`
oglądał. Pole obrazu w żywym Deploymentcie jest referencją `@sha256:`. Przebieg, który
zapisuje sam tag rejestru, jest czerwony, nawet gdy rollout doszedł do Ready.

Koszt: przebieg jest dłuższy o wypchnięcie, o weryfikację i o odrzucenie obrazu bez
atestacji. Obraz bez atestacji nie jest wydaniem, nawet jeśli tag gita istnieje. Dla
`mobile` weryfikacja dotyczy artefaktu zbudowanego z tagu. `kubectl` i tak się nie wykonuje.
Jeśli istnieje `src/clients/mobile/Dockerfile`, job może wypchnąć obraz, ale nie tworzy
Deploymentu `mobile`.

### Runner jjdevhub i środowisko production

Job `deploy` ma `runs-on: [self-hosted, jjdevhub]` i `environment: production`. Runner stoi
na gościu z numeru 08, jako jednostka systemd użytkownika `deploy`, z kubeconfig o prawach
`600`. Etykieta to dokładnie `jjdevhub`. Inny workflow jej nie używa. Job `publish` zostaje
na `ubuntu-latest` i nie ma `environment`. Kubeconfig dotyka tylko `deploy`.

`pull_request` na tym runnerze odpada. W pliku `.github/workflows/deploy.yml` nie ma klucza
`pull_request`. Pull request zostaje na `ubuntu-latest`, tak jak ustaliły bramki. Wspólny
runner „żeby było szybciej” wynosi kubeconfig i sieć maszyny do kodu, który jeszcze nie jest
na `main`. Przebieg pull requestu, który zmienia komentarz w `deploy.yml`, idzie bramkami na
`ubuntu-latest`. Na liście jego jobów nie ma etykiety `jjdevhub`.

Środowisko `production` ogranicza, kto może odpalić przebieg ręczny, i trzyma dziennik
wdrożeń. Reguła: tagi pasujące do wzorca oraz `workflow_dispatch` dla osób, które wolno
wypuszczać na maszynę. Sekretów aplikacji w środowisku nie ma. Nie ma hasła bazy, tokenu
OpenBao, tokenu tunelu ani connection stringa. Hasła baz są w OpenBao. Token tunelu jest na
maszynie. Jeśli środowisko wymaga recenzenta, recenzent zatwierdza przebieg i nie wkleja
sekretu.

Koszt: runner trzeba utrzymać na gościu. Padnięty runner wstrzymuje deploy. Nie wstrzymuje
bramek pull requestu, bo te na niego nie czekają. Token rejestracji runnera jest
jednorazowy, z ustawień repozytorium. Nie wchodzi do git i nie wchodzi do logu kroków.
Katalog roboczy runnera jest poza klonem aplikacji albo jest klonem używanym tylko przez ten
przebieg.

### Akcje przypięte do pełnego SHA

Każde `uses:` w `deploy.yml` jest pełnym SHA commita akcji i komentarzem wersji. Tag akcji
(`@v4`) albo gałąź (`@main`) odpada: wskazanie da się przepiąć po recenzji pliku. Test
numeru sprawdza kształt `@[0-9a-f]{40}` i obecność komentarza wersji. Nie zamraża jednej z
góry wybranej wartości. SHA pochodzi z repozytorium akcji w chwili dodania pliku. Podbicie
akcji jest osobnym commitem, który przechodzi bramki jak każda inna zmiana.

Dotyczy to checkoutu i akcji atestacji. Klient `gh` na runnerze jest wersją z gościa, nie
skryptem wklejonym z internetu w trakcie przebiegu. Doklejenie `curl | sh` w kroku, żeby
„mieć najnowsze gh”, jest tym samym błędem co `@main` na akcji: treść, którą recenzja
oglądała, nie jest treścią, która pójdzie na maszynę.

### Rollback to poprzedni tag

Cofnięcie News to przebieg tego samego jobu z poprzednim tagiem `news-vX.Y.Z`, wybranym
`workflow_dispatch`. Job znowu rozwiązuje digest, znowu sprawdza atestację i znowu podmienia
tylko Deployment `news`. Gałąź `hotfix/…` nie powstaje. `git branch --list 'hotfix/*'`
zostaje puste, jeśli przed cofnięciem było puste.

Poprzedni tag bierze się z listy, nie z pamięci operatora:

```bash
git tag -l 'news-v*' --sort=-v:refname
```

Druga pozycja, jeśli pierwsza jest tagiem stojącym na klastrze, jest wejściem rollbacku. Po
zakończeniu `GET /versions` pokazuje poprzedni numer News, a pozostałe komponenty zostają.
Stopka weba zmienia się tylko wtedy, gdy rollback dotyczył `web-v…`. Ekran telefonu zmienia
się tylko wtedy, gdy rollback dotyczył `mobile-v…` i artefakt poprzedniego tagu znowu jest
tym, który jest publikowany.

Cofanie przez ponowne zbudowanie starego kodu na gałęzi odpada. Powstaje inny digest.
Cofanie całego namespace do starszego manifestu odpada, bo cofa komponenty, które nie były
zepsute, i restartuje magazyny. Pull request „revert” nie jest drogą na maszynę. Revert na
`main` może powstać zwykłą bramką i dostać nowy tag. To jest nowe wydanie, nie rollback.
Rollback nie czeka na nowy numer.

Koszt: poprzedni tag zostaje w repozytorium. Usuwanie tagów komponentu po udanym deployu
jest zabronione. Bez poprzedniego tagu rollback nie ma wejścia. `git tag -d` i skasowanie
tagu na zdalnym repozytorium zamykają cofnięcie. Nie „sprzątają historii”.

### Wersja na ekranie zostaje

Obraz weba zbudowany z tagu ma w plikach statycznych tekst równy tagowi. Job znajduje ten
tekst, zanim uzna przebieg za udany. Nie buduje klienta drugi raz „na szybko”, bez zmiennej
wersji. Artefakt telefonu jest sprawdzany tak samo, na ekranie O aplikacji, którego źródło
jest z [06-mobile.md](../frontend/06-mobile.md). Brak tekstu kończy przebieg. Dla telefonu
`kubectl` się nie wykonuje.

`GET /versions` na bramie zwraca numery działających usług. Kształt jest z
[16-gateway.md](../api/16-gateway.md): pola `identity`, `news`, `learning`, `cv`, `contact`
i `gateway`, a wartość pola jest numerem wersji bez prefiksu nazwy, na przykład `1.4.0` dla
tagu `news-v1.4.0`. Zgodność z tagiem znaczy, że pole komponentu jest tym numerem z tagu
właśnie wdrożonego. Pozostałe pola zostają przy poprzednich tagach. Przebieg News, który
zmienia pole `identity`, jest czerwony, nawet gdy pole `news` jest dobre.

`service.version` na podzie jest pełnym tagiem, na przykład `news-v1.4.0`. Numer 10 przyjął
pełny tag, żeby wykres dało się zestawić z odpowiedzią bramy bez zgadywania. Job podstawia
atrybut w tym samym kroku co digest, jednym `kubectl patch` albo `kubectl apply`
ograniczonym do tego jednego obiektu. Zostawienie wzoru `news-v0.0.0` przy obrazie
`news-v1.4.0` jest błędem deployu, nie błędem collectora. Dashboard wersji z numeru 13
rysuje to, co ten job wpisał. Nie wylicza wersji z nazwy obrazu.

Deploy, który serwuje nowy JavaScript bez stopki, odpada nawet przy zielonym
`rollout status`. Ekran jest częścią wydania. Zielony rollout przy stopce `web-v1.3.0` i
tagu `web-v1.4.0` jest czerwonym przebiegiem.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `.github/workflows/deploy.yml` | Jedyny workflow wdrożenia i rollbacku |
| jednostka systemd runnera na gościu | Proces z etykietą `jjdevhub`, użytkownik `deploy`, poza git |
| `deploy/k3s/apps/<komponent>.yaml` | Deployment, którego pole obrazu job zmienia na digest |

W pliku workflow nie ma klucza `pull_request`. Job `publish` ma `runs-on: ubuntu-latest` i
nie ma `environment`. Job `deploy` ma `needs: publish`, `runs-on: [self-hosted, jjdevhub]` i
`environment: production`. Każde `uses:` jest pełnym SHA i ma komentarz wersji. SHA w
przykładzie jest miejscem na skrót wpisywany przy dodaniu pliku, nie wartością zamrożoną w
tym dokumencie.

```yaml
name: deploy
on:
  push:
    tags:
      - "*-v*"
  workflow_dispatch:
    inputs:
      tag:
        description: Tag komponentu, na przykład news-v1.4.0
        required: true
        type: string
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: checkout
        uses: actions/checkout@<pełny SHA> # vX.Y.Z
        with:
          ref: ${{ github.event.inputs.tag || github.ref }}
          fetch-depth: 0
  deploy:
    needs: publish
    runs-on: [self-hosted, jjdevhub]
    environment: production
    steps:
      - name: checkout
        uses: actions/checkout@<pełny SHA> # vX.Y.Z
        with:
          ref: ${{ github.event.inputs.tag || github.ref }}
          fetch-depth: 0
```

| Tag | Co job robi na klastrze |
| --- | --- |
| `identity-vX.Y.Z` | tylko Deployment `identity` |
| `news-vX.Y.Z` | tylko Deployment `news` |
| `learning-vX.Y.Z` | tylko Deployment `learning` |
| `cv-vX.Y.Z` | tylko Deployment `cv` |
| `contact-vX.Y.Z` | tylko Deployment `contact` |
| `gateway-vX.Y.Z` | tylko Deployment `gateway` |
| `web-vX.Y.Z` | tylko Deployment `web`, plus sprawdzenie stopki `web-vX.Y.Z` |
| `mobile-vX.Y.Z` | bez `kubectl`; sprawdzenie ekranu O aplikacji i publikacja artefaktu tagu |

`mobile` nie dostaje poda. Job nie kompiluje drzewa od nowa na runnerze maszyny. AppHost nie
jest w tabeli. Nie ma tagu, który wstawia `JJDevHub.AppHost` na klaster.

Pole obrazu po przebiegu News:

```text
ghcr.io/jtjaskulski/jjdevhub-news@sha256:<digest>
```

Atrybut zasobu, w tym samym kroku:

```yaml
- name: OTEL_RESOURCE_ATTRIBUTES
  value: service.version=news-v1.4.0,deployment.environment=production
```

Wartość `news-v1.4.0` jest tagiem tego przebiegu. Przy innym komponencie zmienia się nazwa i
tag. Wzorzec `news-v0.0.0` z numeru 10 nie zostaje na żywym podzie po pierwszym udanym
deployu.

Gdy Deployment ma `replicas: 0`, ten sam krok ustawia `replicas: 1`. Nie ustawia `2`. Gdy
replik jest już dwie, bo HPA podniosło próg, krok obrazu nie zapisuje `replicas: 2` i nie
ściąga liczby do zera. Pilnuje, żeby nie zostało zero.

## Plan

### 1. Runner na gościu

Na użytkowniku `deploy` zainstaluj runner z etykietą `jjdevhub`. Jednostka systemd jest
włączona przy starcie gościa. Kubeconfig wskazuje k3s z numeru 08 i ma prawa `600`. Token
rejestracji nie wchodzi do git i nie wchodzi do logu kroków. W ustawieniach repozytorium
runner jest idle. Żaden workflow poza `deploy.yml` nie zawiera `jjdevhub`.

### 2. Środowisko

Utwórz środowisko `production`. Reguła: tagi pasujące do wzorca z numeru 07 oraz
`workflow_dispatch` ograniczony do osób, które wolno wypuszczać na maszynę. Nie dodawaj
sekretu hasła bazy, tokenu OpenBao, tokenu tunelu ani connection stringa. Lista sekretów
środowiskowych zostaje pusta.

### 3. Plik workflow

Dodaj `.github/workflows/deploy.yml` o kształcie z sekcji ścieżek. Kroki po checkout:

1. Wyznacz tag: `github.ref_name` przy push albo wejście `tag` przy `workflow_dispatch`.
2. Odrzuć tag, który nie pasuje do wzorca z numeru 07.
3. `git fetch origin main` i sprawdź `git merge-base --is-ancestor` dla commitu tagu i
   `origin/main`.
4. Z nazwy przed `-v` weź jeden komponent.
5. Na `ubuntu-latest` zbuduj i wypchnij tylko ten komponent, digestem do
   `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Dla `mobile` wypchnij artefakt tagu.
   Obraz z `src/clients/mobile/Dockerfile` wolno wypchnąć, gdy plik jest. Nie twórz
   Deploymentu `mobile`.
6. Złóż atestację pochodzenia i atestację SBOM. Na runnerze `jjdevhub` zweryfikuj obie przez
   `gh attestation verify` z `--owner jtjaskulski`. Brak którejkolwiek kończy przebieg przed
   `kubectl`.
7. Dla `web` znajdź w plikach statycznych obrazu tekst równy tagowi. Brak tekstu kończy
   przebieg.
8. Dla `mobile` znajdź w artefakcie tagu tekst równy tagowi na ekranie O aplikacji. Brak
   tekstu kończy przebieg. `kubectl` się nie wykonuje.
9. Dla pozostałych oraz dla `web` zapamiętaj obraz wszystkich Deploymentów aplikacji. Ustaw
   obraz tylko tego jednego na digest. `replicas` co najmniej 1 i nie 2.
10. `kubectl -n jjdevhub rollout status deploy/<komponent>`.
11. W tym samym kroku co obraz ustaw `OTEL_RESOURCE_ATTRIBUTES` tak, żeby `service.version`
    było tagiem.
12. `GET /versions` przez Service `gateway`. Pole tego komponentu zgadza się z tagiem.
    Pozostałe pola zostają przy zapamiętanej liście.

Akcje w krokach 5 i 6 też są na pełnym SHA, z komentarzem wersji.

### 4. Czego job nie robi

Nie wywołuje `kubectl apply -f deploy/k3s` na całym drzewie. Nie restartuje Postgresa,
Redisa, Kafki, OpenBao, collectora, Prometheusa, Jaegera, Grafany ani `cloudflared`. Nie
zmienia HPA. Nie usuwa tagu. Nie tworzy gałęzi. Nie deployuje AppHost. Job `deploy` nie
buduje obrazu. Nie wypisuje do logu treści Secreta, tokenu runnera ani dzierżawy OpenBao.

### 5. Rollback

Ustal poprzedni tag listą `git tag -l '<komponent>-v*' --sort=-v:refname`. Uruchom
`workflow_dispatch` z drugą pozycją, gdy pierwsza jest tagiem na klastrze. Ten sam plik
wykonuje kroki z punktu 3. Nie otwieraj pull requestu revert jako drogi na maszynę.

### 6. Pierwsze podniesienie replik

Deployment z numeru 08 ma `replicas: 0` do pierwszego tagu. Pierwszy udany przebieg danego
komponentu ustawia `replicas: 1`. Nie ustawia `2`. HPA z numeru 15 trzyma potem podłogę 1 i
sufit 2. Drugi pod powstaje z progu, nie z tagu.

### Co jest do czego

| Element | Po co istnieje | Kto go woła |
| --- | --- | --- |
| Tag `<komponent>-vX.Y.Z` | Wejście wydania i wejście rollbacku | Push tagu albo `workflow_dispatch` |
| Job `publish` | Jeden obraz i dwie atestacje | `ubuntu-latest` |
| Job `deploy` | Weryfikacja i podmiana jednego Deploymentu | Runner `jjdevhub` |
| Środowisko `production` | Dziennik i ograniczenie ręcznego startu | Tylko job `deploy` |
| `gh attestation verify` | Wiązanie digestu z właścicielem `jtjaskulski` | Krok przed `kubectl` |
| `GET /versions` | Numer, który widzi klient | Krok po `rollout status` |
| Stopka i ekran O aplikacji | Numer, który widzi człowiek | Krok `web` i `mobile` przed sukcesem |
| Poprzedni tag | Wejście rollbacku | Ten sam workflow |

Tag woła job. Gdy tag nie jest na `main`, job kończy się przed `kubectl`, a YAML
Deploymentów przed i po jest ten sam. Gdy tag pasuje do dwóch komponentów, wzorzec i tak
wycina jedną nazwę przed `-v`. Przebieg nie bierze drugiej nazwy z diffu.

`publish` woła rejestr. Wypycha jeden digest. Obraz `:scan` zostaje na runnerze bramki i
znika razem z nim. Na GHCR go nie ma jako obrazu wydania.

`deploy` woła `gh attestation verify`, potem jeden Deployment. Gdy weryfikacja pada,
`rollout status` się nie wykonuje. Gdy weryfikacja przechodzi, zmienia się digest tego
jednego komponentu. Digest sąsiada zostaje. AppHost nie jest na liście obiektów do podmiany.

`GET /versions` woła brama po rolloutcie. Pole komponentu jest numerem z tagu, w kształcie
bramy. Pole sąsiada, które się zmieniło, znaczy, że job ruszył drugi Deployment albo że pod
sąsiada wstał z cudzym `service.version`. Jedno i drugie jest błędem tego numeru.

Stopka woła pliki statyczne obrazu `web`, zanim przebieg jest zielony. Ekran O aplikacji
woła artefakt `mobile`. Żaden z tych dwóch kroków nie jest ozdobą po zielonym rolloutcie.
Dla telefonu rolloutu nie ma.

Bramki pull requestu tego jobu nie wołają. Ten job bramek nie zastępuje. Numer 07 nadaje
tag. Ten numer go nie przesuwa i go nie kasuje.

## Testy

1. Kształt pliku. Powód padnięcia: w `deploy.yml` jest `pull_request`, etykieta `jjdevhub`
   występuje w innym workflow, albo `uses:` nie jest pełnym SHA z komentarzem wersji.

```bash
git grep -n "pull_request" -- .github/workflows/deploy.yml && exit 1 || true
git grep -n "jjdevhub" -- .github/workflows/*.yml
```

`jjdevhub` występuje tylko w `deploy.yml`. W tym pliku nie ma `pull_request`. Job `publish`
ma `ubuntu-latest`. Job `deploy` ma `runs-on: [self-hosted, jjdevhub]` i
`environment: production`. Każda linia `uses:` pasuje do `@[0-9a-f]{40}` i ma komentarz
wersji.

2. Odrzucenie złego wejścia. Powód padnięcia: `workflow_dispatch` z `news-v1.4` albo z
   `blog-v1.0.0` dochodzi do `kubectl`. Oba kończą się na kroku wzorca.
   `kubectl -n jjdevhub get deploy -o yaml` przed i po przebiegu jest identyczny. To samo
   dla tagu, którego commit nie jest przodkiem `main`.

3. Jeden komponent. Powód padnięcia: przy zielonym `news-vX.Y.Z` zmienia się digest innego
   Deploymentu. Digest `news` przechodzi na `ghcr.io/jtjaskulski/jjdevhub-news@sha256:…`.
   Digest `identity`, `learning`, `cv`, `contact`, `gateway` i `web` zostaje. `mobile` nie
   dostaje Deploymentu. Postgres, Redis, Kafka, OpenBao, collector, Prometheus, Jaeger,
   Grafana i `cloudflared` nie są restartowane.

4. Atestacja. Powód padnięcia: digest bez atestacji dochodzi do `rollout`. Podmień na czas
   testu krok obrazu na digest bez atestacji albo na nieistniejący. Przebieg pada na
   `gh attestation verify --owner jtjaskulski`, przed `kubectl`. Na klastrze zostaje
   poprzedni digest. Po teście wróć do prawdziwego tagu tym samym jobem. Właściciel inny niż
   `jtjaskulski` jest tym samym powodem padnięcia.

5. Wersje. Powód padnięcia: stopka, ekran albo `GET /versions` nie zgadza się z tagiem, albo
   zmienia się pole sąsiada. Po `web-vX.Y.Z` odpowiedź strony zawiera ten tekst w stopce. Po
   `mobile-vX.Y.Z` artefakt zawiera ten tekst na ekranie O aplikacji i `kubectl` się nie
   wykonał. Po News:

```bash
kubectl -n jjdevhub exec deploy/gateway -- wget -qO- http://127.0.0.1:8080/versions
```

Pole komponentu jest numerem z tagu w kształcie bramy. Pozostałe pola są takie jak przed
przebiegiem. `service.version` na podzie jest pełnym tagiem. Wzorzec `news-v0.0.0` przy
obrazie z innego tagu jest błędem.

6. Rollback. Powód padnięcia: drugi przebieg z poprzednim tagiem News nie przywraca
   poprzedniego digestu albo tworzy gałąź. `GET /versions` pokazuje poprzedni numer News.
   `git branch --list 'hotfix/*'` jest puste, jeśli przed testem było puste. Nowy tag nie
   powstaje w tym przebiegu.

7. Runner nie bierze pull requestu. Powód padnięcia: pull request, który zmienia komentarz w
   `deploy.yml`, ma job z etykietą `jjdevhub`. Bramki tego pull requestu idą na
   `ubuntu-latest`.

8. Repliki. Powód padnięcia: pierwszy deploy komponentu ustawia `replicas: 2` albo zostawia
   `0`. Po pierwszym zielonym tagu Deployment ma co najmniej 1 replikę i nie ma wpisanej
   dwójki jako decyzji tagu. Drugi pod, jeśli jest, pochodzi z HPA, nie z tego jobu.

9. Sekrety środowiska. Powód padnięcia: środowisko `production` ma sekret aplikacji. Lista
   sekretów środowiskowych jest pusta. Log przebiegu nie zawiera hasła bazy, tokenu OpenBao
   ani tokenu tunelu.

10. Tag zostaje. Powód padnięcia: po zielonym deployu tagu nie ma w
    `git tag -l '<komponent>-v*'`. Kasowanie tagu zamyka rollback. Ten test nie kasuje tagu,
    żeby to pokazać. Sprawdza, że job w swoich krokach nie woła usunięcia.

## Zasady

- Deploy jest z tagu `<komponent>-vX.Y.Z` wskazującego commit na `main`. Wzorzec jest ten
  sam co w numerze 07.
- Jeden przebieg zmienia jeden komponent.
- Obraz na klastrze to `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Tag rejestru nie
  jest referencją w żywym Deploymentcie.
- Job `publish` na `ubuntu-latest` buduje i atestuje. Job `deploy` nie buduje.
- `gh attestation verify` z `--owner jtjaskulski` przechodzi dla pochodzenia i dla SBOM,
  zanim wykona się `kubectl`.
- Job `deploy` ma `runs-on: [self-hosted, jjdevhub]` i `environment: production`. Inny
  workflow tej etykiety nie używa.
- `pull_request` nie używa tego runnera i nie występuje w `deploy.yml`.
- `uses:` ma pełny SHA i komentarz wersji. `@v4` i `@main` są błędem.
- W środowisku `production` nie ma sekretu aplikacji.
- Rollback jest poprzednim tagiem tego komponentu, tym samym jobem, przez
  `workflow_dispatch`. Gałąź naprawcza nie jest drogą na maszynę.
- Tagów komponentu się nie kasuje.
- Stopka `web-vX.Y.Z` i ekran `mobile-vX.Y.Z` są sprawdzane. Przebieg, który je gubi, jest
  czerwony.
- `mobile` nie dostaje `kubectl` i nie dostaje poda.
- `GET /versions` zgadza się z tagiem właśnie wdrożonym i nie podmienia wersji sąsiadów.
- `service.version` na podzie jest tym tagiem.
- Job nie stosuje całego drzewa manifestów. Nie restartuje Postgresa, Redisa, Kafki,
  OpenBao, collectora, Prometheusa, Jaegera, Grafany ani `cloudflared`. Nie zmienia HPA.
- Pierwszy deploy komponentu ustawia co najmniej jedną replikę i nie ustawia dwóch. Drugą
  zostawia HPA.
- AppHost nie jest deployowany.
- Log przebiegu nie zawiera sekretu.
- Obraz `:scan` z bramki nie jedzie na maszynę.

## Poza zakresem

- Nadawanie tagu, SemVer i to, który commit dostaje numer, są w
  [07-wersje.md](07-wersje.md). Ten numer nie woła release-please i nie przesuwa pliku
  `versions/<komponent>.json`.
- Bramki, które muszą być zielone, zanim tag powstanie, są w [02-bramki.md](02-bramki.md),
  [03-codeql.md](03-codeql.md), [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md),
  [05-sonarqube.md](05-sonarqube.md) i [06-lancuch-dostaw.md](06-lancuch-dostaw.md).
  Atestacja, którą ten numer weryfikuje przy wydaniu, powstaje na digestcie z rejestru.
  Bramka ogląda obraz `:scan`. Ten numer nie obniża progu CVE i nie wyłącza CodeQL.
- Maszyna, na której stoi runner, jest w [08-proxmox.md](08-proxmox.md). Ten numer nie
  zmienia rozmiaru VM i nie otwiera portu na gościu.
- Nazwa publiczna, pod którą `GET /versions` widać z zewnątrz, jest w
  [09-cloudflare.md](09-cloudflare.md). Sprawdzenie z testu idzie przez Service bramy
  wewnątrz klastra.
- Atrybut `service.version` jako kontrakt telemetrii jest w
  [10-opentelemetry.md](10-opentelemetry.md). Ten numer podstawia wartość tagu. Nie zmienia
  nazwy atrybutu.
- Wykres wersji jest w [13-grafana.md](13-grafana.md). Deploy nie klika dashboardu. Zostawia
  atrybut, który dashboard już umie narysować.
- Poświadczenie bazy przy starcie nowego poda jest w [14-openbao.md](14-openbao.md). Deploy
  hasła nie przynosi i nie wstawia `OPENBAO_TOKEN`.
- Drugi pod jest w [15-skalowanie.md](15-skalowanie.md). Ten numer nie ustawia `replicas: 2`
  i nie zmienia progu HPA.
- Kształt JSON `GET /versions` i trasy YARP są w [16-gateway.md](../api/16-gateway.md). Ten
  numer pilnuje zgodności pola z tagiem. Nie dokłada siódmego pola.
- Miejsce stopki i ekranu O aplikacji jest w [02-web.md](../frontend/02-web.md) i
  [06-mobile.md](../frontend/06-mobile.md). Ten numer pilnuje, żeby deploy ich nie starł.
- AppHost zostaje na laptopie, jak w numerze Aspire. Na klaster nie jedzie.

## Źródła

- [Środowiska GitHub](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment).
  Wiążące jest `environment: production` jako dziennik wdrożenia i ograniczenie tego, kto
  uruchamia job ręcznie. Dotyczy wyłącznie jobu `deploy` oraz reguły tagów i
  `workflow_dispatch`. Ze źródła nie bierzemy sekretów aplikacji w środowisku. Hasło bazy,
  token OpenBao i token tunelu tam nie wchodzą.
- [Sekrety w Actions](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions).
  Wiążące jest trzymanie wartości poza plikiem workflow. Dotyczy pustej listy sekretów
  środowiska `production` i zakazu wypisywania ich w logu. Ze źródła nie bierzemy `secrets.`
  z hasłem bazy jako sposobu na deploy. Poświadczenie bazy zostaje w OpenBao.
- [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners).
  Wiążące jest to, że job z etykietą runnera wykonuje się na maszynie, która tę etykietę ma.
  Dotyczy `runs-on: [self-hosted, jjdevhub]`, użytkownika `deploy` i kubeconfig o prawach
  `600`. Ze źródła nie bierzemy tej etykiety na `pull_request` i nie bierzemy jej w bramkach
  numerów 01–07.
- [Etykiety runnera](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/using-labels-with-self-hosted-runners).
  Wiążące jest trafienie jobu tylko w runner z podaną etykietą. Dotyczy etykiety dokładnie
  `jjdevhub` i zakazu używania jej w innym pliku workflow. Ze źródła nie bierzemy etykiety
  `self-hosted` bez `jjdevhub`, która złapałaby inny runner.
- [Atestacje artefaktów](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds).
  Wiążące jest złożenie pochodzenia i SBOM dla digestu oraz weryfikacja przed użyciem
  artefaktu. Dotyczy jobu `publish` i kroku `gh attestation verify` przed `kubectl`. Ze
  źródła nie bierzemy pominięcia weryfikacji tylko dlatego, że bramka `:scan` była zielona.
- [Atestacja pochodzenia](https://github.com/actions/attest-build-provenance). Wiążąca jest
  akcja, która poświadcza digest obrazu tożsamością przebiegu. Dotyczy jobu `publish`,
  pełnego SHA w `uses:` i komentarza wersji. Ze źródła nie bierzemy klucza podpisu w
  repozytorium i nie bierzemy atestacji obrazu `:scan` jako atestacji obrazu na klastrze.
- [Atestacja SBOM](https://github.com/actions/attest-sbom). Wiążąca jest osobna atestacja
  wykazu, sprawdzana drugim wołaniem. Dotyczy predykatu `https://spdx.dev/Document` przy
  SPDX z numeru 04. Ze źródła nie bierzemy SBOM bez weryfikacji na runnerze `jjdevhub` i nie
  bierzemy wklejenia pliku SPDX do logu jako zamiennika `gh attestation verify`.
- [`gh attestation verify`](https://cli.github.com/manual/gh_attestation_verify). Wiążące są
  `--owner` i kod wyjścia inny niż zero, gdy atestacji nie ma albo właściciel się nie
  zgadza. Dotyczy właściciela `jtjaskulski` i referencji
  `oci://ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Ze źródła nie bierzemy
  przejścia do `kubectl` po niezerowym kodzie. Klient `gh` jest wersją z gościa.
- [Przypinanie akcji](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions).
  Wiążące jest pełne SHA w `uses:` zamiast tagu lub gałęzi, które da się przepiąć. Dotyczy
  każdego `uses:` w `deploy.yml` i komentarza wersji obok skrótu. Ze źródła nie bierzemy
  `@v4` i `@main`. Ten dokument nie zamraża jednego skrótu z góry.
- [`workflow_dispatch`](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#workflow_dispatch).
  Wiążące jest ręczne wejście z polem `tag`. Dotyczy rollbacku poprzednim tagiem tego
  komponentu i odrzucenia tagu spoza wzorca. Ze źródła nie bierzemy ręcznego deployu z
  gałęzi `hotfix` i nie bierzemy tego zdarzenia jako drogi, która omija atestację.
- [Aktualizacja Deploymentu](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#updating-a-deployment).
  Wiążąca jest podmiana obrazu jednego Deploymentu. Dotyczy jednego komponentu na przebieg i
  referencji po digescie. Ze źródła nie bierzemy `kubectl apply` na całe drzewo `deploy/k3s`
  i nie bierzemy podmiany sąsiada „przy okazji”.
- [Rolling update](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#rolling-update-deployment).
  Wiążące jest czekanie, aż nowy pod będzie gotowy, zanim uzna się wydanie za widoczne.
  Dotyczy `kubectl -n jjdevhub rollout status deploy/<komponent>` przed `GET /versions`. Ze
  źródła nie bierzemy zielonego rolloutu jako zamiennika stopki i zgodności wersji.
- [`kubectl set image`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_set/kubectl_set_image/).
  Wiążące jest ustawienie obrazu jednego kontenera bez stosowania reszty manifestów. Dotyczy
  zakazu drogi z laptopa jako zwykłego wydania: to samo polecenie w jobie jest po atestacji
  i zostawia przebieg. Ze źródła nie bierzemy ręcznego `set image` obrazu bez tagu.
- [`kubectl rollout status`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_rollout/kubectl_rollout_status/).
  Wiążące jest zakończenie kroku kodem zero dopiero, gdy rollout się skończy. Dotyczy
  kolejności: najpierw status, potem `GET /versions`. Ze źródła nie bierzemy wywołania tego
  polecenia dla Postgresa, Kafki, OpenBao, Grafany albo `cloudflared` w tym jobie.
- [`kubectl patch`](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_patch/).
  Wiążąca jest zmiana ograniczona do jednego obiektu. Dotyczy wstawienia `service.version`
  razem z digestem, bez stosowania całego pliku katalogu. Ze źródła nie bierzemy patcha,
  który ustawia `replicas: 2`, i nie bierzemy patcha StatefulSet magazynu.
- [Obraz po digescie](https://kubernetes.io/docs/concepts/containers/images/#image-names).
  Wiążące jest `obraz@sha256:…` jako referencja, której nie da się przepiąć tagiem. Dotyczy
  pola obrazu w żywym Deploymentcie. Ze źródła nie bierzemy `:latest` i nie bierzemy tagu
  `news-v1.4.0` jako jedynej referencji na klastrze.
- [GHCR](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry).
  Wiążący jest rejestr `ghcr.io` i nazwa obrazu właściciela. Dotyczy
  `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:…`. Ze źródła nie bierzemy obrazu
  lokalnego `jjdevhub/<komponent>:scan` jako obrazu, który kubelet ściąga na maszynę.
- [Zmienne OTEL](https://opentelemetry.io/docs/languages/sdk-configuration/general/).
  Wiążące jest `OTEL_RESOURCE_ATTRIBUTES` jako miejsce na `service.version`. Dotyczy
  wstawienia pełnego tagu w tym samym kroku co digest. Ze źródła nie bierzemy zostawienia
  `news-v0.0.0` na podzie, który serwuje inny tag, i nie bierzemy adresu kolektora wpisanego
  na sztywno w tym jobie.
- [Atrybut service](https://opentelemetry.io/docs/specs/semconv/resource/#service). Wiążące
  jest `service.version` jako wersja usługi w zasobie telemetrii. Dotyczy pełnego tagu
  `<komponent>-vX.Y.Z`, zgodnego z numerem 10. Ze źródła nie bierzemy wersji wyliczonej z
  nazwy obrazu, gdy atrybut jest ustawiony, i nie bierzemy jednego `service.version`
  wspólnego dla wszystkich podów.
- [`git merge-base`](https://git-scm.com/docs/git-merge-base). Wiążące jest `--is-ancestor`:
  commit tagu jest na `main` albo jest jego czubkiem. Dotyczy odrzucenia tagu wskazującego
  commit spoza `main`, zanim powstanie digest na klastrze. Ze źródła nie bierzemy deployu z
  `develop`, `release` ani z gałęzi funkcji.
- [`git tag`](https://git-scm.com/docs/git-tag). Wiążące jest listowanie tagów komponentu, w
  tym `--sort=-v:refname`. Dotyczy wyboru poprzedniego tagu jako wejścia rollbacku i zakazu
  kasowania tagów. Ze źródła nie bierzemy `git tag -d` po udanym deployu. Bez poprzedniego
  tagu rollback nie ma wejścia.
- [SemVer](https://semver.org/). Wiążący jest numer `X.Y.Z`, który wzorzec z numeru 07 już
  wycina. Dotyczy odrzucenia `news-v1.4` i przyrostka, którego wzorzec nie przepuszcza. Ze
  źródła nie bierzemy zakresu wersji, pre-release ani metadanych budowania. Tag jest
  dokładnie tym wyrażeniem, nie „zgodny z SemVer w przybliżeniu”.

## Gotowe gdy

- `.github/workflows/deploy.yml` istnieje. Nie ma w nim `pull_request`. Job `publish` jest
  na `ubuntu-latest`. Job `deploy` ma `runs-on: [self-hosted, jjdevhub]` i
  `environment: production`. Każde `uses:` jest pełnym SHA z komentarzem wersji.
- Runner na gościu jest idle z etykietą `jjdevhub`. `git grep jjdevhub -- .github/workflows`
  wypisuje tylko `deploy.yml`.
- Wzorzec tagu jest ten sam co w numerze 07. `news-v1.4` i `blog-v1.0.0` padają przed
  `kubectl`.
- Przebieg tagu `news-vX.Y.Z` z `main` zmienia wyłącznie digest News, po udanej
  `gh attestation verify --owner jtjaskulski`, i `GET /versions` pokazuje ten tag w polu
  News. Sąsiedzi zostają.
- Obraz w Deploymentcie jest `ghcr.io/jtjaskulski/jjdevhub-news@sha256:…`. `service.version`
  jest pełnym tagiem.
- Przebieg z digestem bez atestacji pada przed `kubectl`. Digesty Deploymentów zostają.
- Przebieg `web-vX.Y.Z` zostawia w odpowiedzi strony stopkę z tym tagiem. Przebieg
  `mobile-vX.Y.Z` zostawia ten tag na ekranie O aplikacji, nie woła `kubectl` i nie tworzy
  poda.
- Pierwszy deploy ustawia co najmniej jedną replikę i nie ustawia dwóch. Drugi pod, jeśli
  wstanie, wstaje z HPA.
- `workflow_dispatch` z poprzednim tagiem News przywraca poprzedni digest. Nowa gałąź nie
  powstaje. Tagów się nie kasuje.
- Job nie stosuje całego drzewa i nie restartuje magazynów, telemetrii ani `cloudflared`.
- W środowisku `production` nie ma sekretu aplikacji. AppHost nie jest deployowany.
