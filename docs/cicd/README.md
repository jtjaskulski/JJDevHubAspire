# CI/CD

[Dokumentacja](../README.md)

Ten folder jest specyfikacją bramek i wydania JJDevHub. Nie jest numerem wdrożenia
i nie ma w nim kroków do wykonania w repozytorium. Kroki są w plikach `01`–`16`.
Numery `01`–`07` powstają przed kodem usług, więc pierwszy pull request z funkcją
zastaje już odrzucenie złej gałęzi, złego tytułu, czerwonego testu, sekretu w
diffie i znanej podatności. Numery `08` i `09` powstają zaraz po tagu: pusta
maszyna i tunel, zanim powstanie Aspire. Telemetria `10`–`13` czeka na
`ServiceDefaults`. OpenBao na VM jest po lokalnym OpenBao. Deploy bramy jest
zaraz po `GET /versions`. Drugi pod jest po usługach, przed piramidą testów.
Frontend nie stawia maszyny.

Poniżej są pliki tej specyfikacji. Workflow, zestawy reguł i skrypty opisane w
numerach `01`–`07` wchodzą do repozytorium razem z tymi numerami, zanim powstanie
pierwsza usługa. Maszyna i tunel nie czekają na frontend. Czekają na tag z
numeru `07`. Obraz aplikacji czeka na bramę i na job z numeru `16`.

## Kolejność względem reszty dokumentacji

Cały produkt czyta się według listy w [docs/README.md](../README.md). W tym
folderze pliki leżą `01`–`16`, ale praca nie bierze ich jednym blokiem na końcu.
`08` i `09` idą zaraz po `07`. `10`–`13` idą po [api/01](../api/01-aspire.md).
`14` idzie po [api/04](../api/04-openbao.md). `16` idzie po
[bramie](../api/16-gateway.md). `15` idzie po [kontakcie](../api/21-kontakt.md)
i przed [piramidą](../api/22-testy.md).

| Faza | Numery | Co już musi być prawdą |
| --- | --- | --- |
| Przed kodem usługi | [01](01-galezie.md)–[07](07-wersje.md) | Każdy pull request ma wymagane checki. Brak raportu z wymaganego checka blokuje scalenie |
| Pusta maszyna | [08](08-proxmox.md)–[09](09-cloudflare.md) | Tag istnieje. Repliki aplikacji są `0`. Tunel wskazuje Service `gateway` |
| Po ServiceDefaults | [10](10-opentelemetry.md)–[13](13-grafana.md) | Collector, Prometheus, Jaeger i Grafana stoją na VM. Pusty wykres jest poprawny |
| Po lokalnym OpenBao | [14](14-openbao.md) | Te same nazwy adresu i metody co w AppHost. Schematu tabel jeszcze nie ma |
| Po bramie | [16](16-deploy.md) | `GET /versions` istnieje. Pierwszy rollout to brama, jedna replika |
| Po usługach | [15](15-skalowanie.md) | Jest pod z obrazu, inbox i co najmniej dwie partycje. Web może mieć `replicas: 0` |

Jeden numer na jedno wdrożenie. Numer jest gotowy, gdy jego sekcja `## Gotowe gdy`
jest spełniona. Dwa numery nie łączą się w jednym podejściu. Kto czyta `04`, umie
odróżnić CVE paczki od skanu kodu. Kto czyta `16`, umie wgrać jeden tag i cofnąć
go do poprzedniego tagu tego samego komponentu.

Bez pierwszych siedmiu numerów zielony przycisk scalenia znaczy tylko, że git
przyjął diff. Gałąź `feature/lesson_markdown` weszłaby na `develop`, tytuł bez
zakresu stałby się commitem squasha, a [07-wersje.md](07-wersje.md) nie miałby z
czego wyciąć `news-v1.4.0`. Późniejsze numery API dokładają kod do już wymaganych
checków. Nie dokładają drugiej bramki.

## Jak czytać numer

| Sekcja | Co w niej jest |
| --- | --- |
| wstęp | co dodaje numer, link do poprzedniego i następnego, scenariusz, który bez numeru się psuje |
| `## Po co` | problem, który numer zamyka |
| `## Dlaczego ta technologia` | decyzja, alternatywy, które odpadły, i koszt, który zostaje |
| `## Klasy i ścieżki` | workflow, skrypt, zestaw reguł albo plik konfiguracji i jego rola |
| `## Plan` | kroki `### 1.` i na końcu `### Co jest do czego` |
| `## Testy` | `actionlint`, suchy przebieg i przykład, który ma paść |
| `## Zasady` | reguły tego numeru |
| `## Poza zakresem` | który inny numer to domyka |
| `## Źródła` | lista: link, potem zdania — co jest wiążące, której decyzji dotyczy, czego ze źródła nie bierzemy |
| `## Gotowe gdy` | warunki, ostatni da się sprawdzić komendą albo plikiem |

`## Dlaczego ta technologia` tłumaczy wybór, zanim powstanie plik workflow albo
manifest. `## Plan` mówi, co zrobić, i nie powtarza uzasadnień. `### Co jest do
czego` odpowiada na pytanie, po co job albo plik w ogóle istnieje i kto go woła.

`## Źródła` nie jest tabelą z jedną komórką „po co”. Punkt zaczyna się od linku.
Dalej jest to, co w tym adresie obowiązuje ten numer, której decyzji to dotyczy i
czego ze strony nie bierzemy. Adres bez tych trzech zdań nie wystarcza, bo z
jednej strony dokumentacji da się wziąć i narzędzie, i układ, którego ten
produkt nie chce.

Indeks i ten plik szablonu numeru nie wypełniają krokami. Czytelnik numeru ma
dostać najpierw problem, potem uzasadnienie, potem listę plików, potem kroki.

## Słownik

| Nazwa | Znaczenie |
| --- | --- |
| `develop`, `release`, `main` | trzy długie gałęzie |
| gałąź robocza | gałąź wycięta z `develop`, o nazwie z dozwolonego prefiksu |
| scope | zakres w tytule, z listy komponentów albo `infra`, albo `shared` |
| ruleset | zestaw reguł GitHub zapisany w `.github/rulesets` |
| check | nazwa joba, której ruleset wymaga przed scaleniem |
| komponent | `identity`, `news`, `learning`, `cv`, `contact`, `gateway`, `web`, `mobile` |
| `shared` | zakres dla `JJDevHub.Shared.Kernel`, bez własnego tagu |
| `infra` | zakres bez tagu obrazu usługi |
| SBOM | wykaz składników obrazu |
| atestacja | podpis pochodzenia obrazu i SBOM w GitHubie |

Zakresy `feat` i `fix`: `identity`, `news`, `learning`, `cv`, `contact`,
`gateway`, `web`, `mobile`, `infra`, `shared`.

Tytuł wzorcowy: `feat(news): publish article revision`. Nazwa wzorcowa:
`feature/lesson-markdown`. Nazwa, która pada: `feature/lesson_markdown`.

Słownik nie ma drugiej nazwy na ten sam byt. Check w workflow i check w rulesecie
to ten sam napis. Tag `news-v1.4.0` i pole w `versions/news.json` to ten sam
numer. Service `gateway` i origin tunelu to ten sam ClusterIP YARP.

## Gałęzie i tytuły

Długie gałęzie to `develop`, `release` i `main`. Gałąź robocza wychodzi tylko z
`develop`. Prefiksy: `feature/`, `fix/`, `docs/`, `chore/`, `ci/`, `refactor/`,
`test/`, dalej kebab-case.

Pull request do `develop` ma głowę o takim prefiksie. Pull request do `release`
ma głowę `develop`. Pull request do `main` ma głowę `release`. Inna para pada w
jobie `branch-name`. Nie da się przeskoczyć środkowej gałęzi. Poprawka nie
dostaje skrótu `hotfix` wyciętego z `main`, bo taki skrót ominąłby CodeQL i
SonarQube.

Tytuł jest Conventional Commits. `feat` i `fix` mają zakres z listy. Wejście na
`develop` jest squashem, więc commit na `develop` ma treść tytułu. Promocja na
`release` i `main` jest merge commitem. Job `pr-title` pilnuje tytułu. Zakres
wybiera komponent, którego numer wersji podbije numer `07`.

Szczegóły: [01-galezie.md](01-galezie.md).

## Trzy bramki

Skrót checków numeru 02 jest w [bramki.md](../bramki.md).

Bramki dotyczą komponentów dotkniętych zmianą i są wymagane od pierwszego pull
requestu po numerach `01`–`07`.

| Gałąź docelowa | Checki, które ruleset wymaga |
| --- | --- |
| `develop` | `build`, `unit-tests`, `integration-tests`, `performance`, `format`, `codeql`, `gitleaks`, `dependency-vulnerabilities`, `branch-name`, `pr-title`, oraz z numeru `06`: `zizmor`, `action-pins`, `scorecard` |
| `release` | checki z `develop` oraz `sonarqube`, `image-scan` |
| `main` | checki z `release` oraz `sbom`, `attestations`, `release-tags` |

`develop` przyjmuje zmianę po pierwszej bramce. `release` po drugiej. `main` po
trzeciej. Na `main` leżą zmiany, które przeszły pełny ciąg. Check z wcześniejszej
bramki raportuje się także na dalszej gałęzi. Inaczej ruleset `main` czekałby na
status, którego workflow nie wysłał.

Job pull requestu idzie na `ubuntu-latest`. Runner własny nie startuje na
`pull_request`. W numerach `01`–`07` każdy job, także `push` i harmonogram,
używa `ubuntu-latest`. Etykieta `jjdevhub` pojawia się dopiero w numerze `16` i
tylko w jobie deployu.

Skan obrazu, SBOM i atestacja są w jednym workflow od początku. Zaczynają wiązać
wynik, gdy komponent dostaje Dockerfile. Do tej pory job kończy się sukcesem, bo
nie ma czego skanować, ale job istnieje i raportuje check. Required check,
którego job nie raportuje, blokuje merge. Dlatego job wymagany zawsze się
uruchamia. Filtr `paths` na poziomie `on` jest zabroniony dla tych workflowów:
pull request dotykający tylko dokumentacji i tak musi dostać zielony check.

Pusty sukces obowiązuje tylko, gdy w drzewie nie ma materiału tego joba. Gdy
pojawi się projekt produkcyjny, test oznaczony kategorią albo Dockerfile, ten
sam job zaczyna wymagać przejścia. Szczegóły progów są w numerach `02`–`07`.

## Rejestr jobów

| Check | Plik workflow do dodania | Numer |
| --- | --- | --- |
| `branch-name` | `.github/workflows/branch-name.yml` | [01](01-galezie.md) |
| `pr-title` | `.github/workflows/pr-title.yml` | [01](01-galezie.md) |
| `build` | `.github/workflows/build.yml` | [02](02-bramki.md) |
| `unit-tests` | `.github/workflows/unit-tests.yml` | [02](02-bramki.md) |
| `format` | `.github/workflows/format.yml` | [02](02-bramki.md) |
| `integration-tests` | `.github/workflows/integration-tests.yml` | [02](02-bramki.md) |
| `performance` | `.github/workflows/performance.yml` | [02](02-bramki.md) |
| `codeql` | `.github/workflows/codeql.yml` | [03](03-codeql.md) |
| `dependency-vulnerabilities` | `.github/workflows/dependencies.yml` | [04](04-zaleznosci-i-obrazy.md) |
| `image-scan`, `sbom`, `attestations` | `.github/workflows/artifacts.yml` | [04](04-zaleznosci-i-obrazy.md) |
| `sonarqube` | `.github/workflows/sonarqube.yml` | [05](05-sonarqube.md) |
| `gitleaks` | `.github/workflows/gitleaks.yml` | [06](06-lancuch-dostaw.md) |
| `zizmor` | `.github/workflows/zizmor.yml` | [06](06-lancuch-dostaw.md) |
| `action-pins` | `.github/workflows/action-pins.yml` | [06](06-lancuch-dostaw.md) |
| `scorecard` | `.github/workflows/scorecard.yml` | [06](06-lancuch-dostaw.md) |
| `release-tags` | `.github/workflows/versions.yml` | [07](07-wersje.md) |

Nazwa joba jest nazwą checka. Zmiana nazwy w workflow bez zmiany rulesetu albo
odwrotnie blokuje scalenie albo przepuszcza zmianę bez bramki. Nazwę dopisuje
się do JSON w tym samym scaleniu, w którym workflow zaczyna ją raportować.

Deploy nie jest w tej tabeli. Nie jest checkiem pull requestu. Jego plik to
`.github/workflows/deploy.yml` z numeru [16](16-deploy.md).

## Pliki tego folderu

### [01-galezie.md](01-galezie.md)

Gałęzie oraz checki nazw i tytułów. Dodaje `.github/workflows/branch-name.yml`,
`.github/workflows/pr-title.yml`, skrypty tych dwóch checków i trzy zestawy
reguł: `develop`, `release`, `main`. Chroni długie gałęzie przed kasowaniem i
przed pushem, który nie jest przewinięciem do przodu. Na `develop` zostawia
squash, na `release` i `main` merge commit.

To jest pierwszy numer całego produktu. Nie zakłada solution, testu ani
Dockerfile. Gałąź `feature/lesson-markdown` przechodzi. Gałąź
`feature/lesson_markdown` pada kodem `1`, zanim ktokolwiek spojrzy na kompilację.
Tytuł `feat(news): publish article revision` przechodzi. Tytuł `feat:` bez
zakresu pada. Recenzja drugiej osoby nie jest wymagana. Bramką jest check.

### [02-bramki.md](02-bramki.md)

Trzy bramki jako wymagane checki. Dodaje workflow budowania, testów
jednostkowych, formatu, testów integracyjnych i testów wydajnościowych NBomber.
Rozpisuje, które checki z późniejszych numerów wchodzą do którego rulesetu.
Definiuje wykrywanie dotkniętych komponentów w
`.github/scripts/affected-components.sh`.

Przed kodem usługi joby `build`, `unit-tests`, `format`, `integration-tests` i
`performance` kończą się sukcesem po komunikacie, że nie ma projektów albo
testów danej kategorii. Job przy tym istnieje. Filtr `paths` na `on` jest
zabroniony, bo pominięty job nie jest sukcesem w rulesecie. Zmiana w News nie
kompiluje Identity. Pusty sukces dotyczy braku materiału, nie wyłączenia checka.

### [03-codeql.md](03-codeql.md)

Skan kodu CodeQL na bramce `develop` i ponownie przy wejściu na `release` oraz
`main`. Dodaje `.github/workflows/codeql.yml` i job `codeql`. Zestaw zapytań to
`security-extended`. Próg niepowodzenia to `security-severity` co najmniej `7.0`.

Gdy w drzewie nie ma plików C#, JavaScript ani TypeScript, job kończy się
sukcesem z logiem `no material for codeql`. Gdy takie pliki są, wynik skanu
wiąże scalenie. Werdykt jest kodem wyjścia z SARIF, nie zakładką Security.
Alert bezpieczeństwa bez pola wagi też blokuje. Check jest wymagany na trzech
długich gałęziach.

### [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md)

Podatności zależności na bramce `develop` oraz skan obrazu, SBOM i atestacja.
Zależności: `dotnet list package --vulnerable` i `npm audit`, próg wysoki i
krytyczny, także bez poprawki. Obraz: Trivy, ten sam próg, gdy jest Dockerfile.
SBOM: Syft w SPDX. Atestacja: wbudowane atestacje artefaktów GitHuba, bez klucza
w repozytorium.

Joby `image-scan`, `sbom` i `attestations` żyją w `.github/workflows/artifacts.yml`
od tego numeru. `image-scan` jest wymagany od `release`. `sbom` i `attestations`
od `main`. Wypchnięcie obrazu do rejestru i deploy są w numerze `16`. Zmiana
News nie skanuje obrazu Identity.

### [05-sonarqube.md](05-sonarqube.md)

Bramka jakości SonarQube Community Build, wymagana od pierwszego pull requestu,
który celuje w `release` albo `main`. Na czas developmentu serwer to jeden
kontener. Job `sonarqube` w CI stawia świeży kontener na `ubuntu-latest` i
ładuje bramkę `jjdevhub` z pliku w gicie, więc wynik nie zależy od kliknięć w
interfejsie.

Warunki na nowym kodzie: zero nowych blockerów, zero nowych critical, sto
procent przejrzanych hotspotów, gęstość duplikacji co najwyżej trzy procent,
pokrycie co najmniej osiemdziesiąt procent, gdy są linie do pokrycia. Token
serwera nie wchodzi do repozytorium. Późniejsze miejsce kontenera na maszynie
opisuje [08-proxmox.md](08-proxmox.md). Bramka zostaje włączona po tym
przeniesieniu. Zmienia się adres, nie próg.

### [06-lancuch-dostaw.md](06-lancuch-dostaw.md)

Sekret w diffie, akcje i Scorecard. Dodaje gitleaks, zakaz plików SOPS, zizmor,
przypięcie akcji do pełnego SHA z komentarzem wersji oraz lokalny przebieg
OpenSSF Scorecard. Cztery checki są wymagane już na `develop`.

Ten numer zatrzymuje sekret, zanim wpadnie do gita. Produkcyjny OpenBao jest w
[14-openbao.md](14-openbao.md). Lokalny OpenBao jest w
[docs/api/04-openbao.md](../api/04-openbao.md). W plikach workflow nie ma
wartości sekretu i nie ma odwołania `secrets.` do sekretu aplikacji. Scorecard
blokuje na trzech sondach plikowych z progiem `10`, nie na średniej z sond,
które wymagają tokenu.

### [07-wersje.md](07-wersje.md)

Osobny numer każdego komponentu, zanim powstanie VM. Dodaje manifest
release-please, pliki `versions/<komponent>.json` i job `release-tags`. Tagi
mają postać `identity-vX.Y.Z` i `news-v1.4.0`. Tag `news` nie przebudowuje
pozostałych obrazów. Wtyczka `linked-versions` nie wchodzi.

Zmiana w `JJDevHub.Shared.Kernel` podbija każdą usługę, która ma do niego
`ProjectReference`. SemVer: przed `1.0.0` zmiana łamiąca podbija minor. Web
pokaże `web-vX.Y.Z` w stopce, telefon `mobile-vX.Y.Z` na ekranie O aplikacji,
oba zawołają `GET /versions`. Te trzy zachowania opisują numery frontu i
gatewaya. Ten numer zostawia im tagi i pliki wersji. Obrazu nie buduje.

### [08-proxmox.md](08-proxmox.md)

Zaraz po numerze `07`, przed Aspire. Jedna maszyna wirtualna na własnym hoście
Proxmox i k3s w jednym węźle, z containerd. Gość ma 4 vCPU, 16 GiB bez balonowania, dysk 120
GiB, UEFI i vTPM. Traefik i ServiceLB są wyłączone, bo jedyną bramą HTTP
zostaje YARP.

Na klastrze stoją Postgres z dziesięcioma pustymi bazami, Redis jako cache i
jeden broker Kafki w trybie KRaft. AppHost zostaje na laptopie. Deploymenty
aplikacji mają zero replik, dopóki numer `16` nie wpisze digestu. Tu przenosi
się kontener SonarQube z numeru `05`. Bramka jakości się nie wyłącza. Publiczna
chmura nie jest celem. Kopia `vzdump` obejmuje stan TPM.

### [09-cloudflare.md](09-cloudflare.md)

Zaraz po maszynie, przed Aspire. DNS i tunel. `cloudflared` wychodzi z klastra na
port 7844.
Jedyny origin aplikacji to Service `gateway` na porcie 8080. YARP nie dostaje
sąsiada w postaci drugiej bramy. Rekord jest proxied, tryb SSL to Full, rekord
A na adres domu nie powstaje.

Panele Grafany, Jaegera i Prometheusa, jeśli mają hostname, idą za Cloudflare
Access i obok bramy, nie przez nią. Postgres, Redis, Kafka, OpenBao i OTLP nie
dostają nazwy publicznej. Token tunelu żyje w Secretcie na maszynie. Ten numer
nie zmienia bramek pull requestu.

### [10-opentelemetry.md](10-opentelemetry.md)

Po [api/01](../api/01-aspire.md), gdy jest `ServiceDefaults`. Telemetria na
maszynie. Instrumentacja zostaje w
`JJDevHub.ServiceDefaults`. Collector w namespace `jjdevhub` jest jedynym
odbiornikiem OTLP na VM. Metryki idą na port 8889, ślady do Jaegera. Usługa nie
wystawia `/metrics`.

Dashboard Aspire zostaje przy `aspire run` i nie zastępuje tego numeru. Laptop
nie wysyła sygnału na VM. `service.name` jest nazwą komponentu.
`service.version` jest pełnym tagiem, na przykład `news-v1.4.0`. Awaria
collectora gubi sygnał z okna awarii i nie gubi żądania HTTP.

### [11-prometheus.md](11-prometheus.md)

Po collectorze, przed bazami w `api/02`. Prometheus na tej samej VM scrapuje
collector co 15 sekund i
trzyma próbki 15 dni na PVC. Nie scrapuje podów usług. CPU dla autoskalowania
zostaje przy metrics-server.

Rekord `jjdevhub:http_server_active_requests:sum` jest stabilną nazwą, którą
czyta numer `15`. UI, jeśli jest publikowane, idzie hostname’em z numeru `09`
za Access. Port 9090 nie słucha na adresie gościa.

### [12-jaeger.md](12-jaeger.md)

Po collectorze, obok Prometheusa. Jaeger all-in-one trzyma ślady w Badgerze na
PVC, z retencją 7
dni. Collector wysyła OTLP na port 4317 Jaegera. Aplikacja tego adresu nie zna.
UI na 16686 nie idzie przez YARP.

Sampling zostaje `parentbased_always_on`, zgodny z laptopem. `trace_id` w logu
na stdout otwiera to samo drzewo. Elasticsearch, Cassandra i kolejka na Kafce
produktu jako magazyn śladów odpadają.

### [13-grafana.md](13-grafana.md)

Po Prometheusie i Jaegerze, przed `api/02`. Grafana OSS czyta Prometheusa i
Jaegera. Datasource i dashboardy
`jjdevhub-uslugi` oraz `jjdevhub-wersje` są w git. Hasło administratora jest w
Secretcie na maszynie.

Wykres grupuje po `service_name`. `mobile` nie ma panelu poda, bo telefon nie
jest repliką. Grafana nie scrapuje podów, nie przyjmuje OTLP i nie magazynuje
logów. YARP nie dostaje trasy do panelu.

### [14-openbao.md](14-openbao.md)

Po lokalnym OpenBao z [api/04](../api/04-openbao.md), przed jądrem. OpenBao na
VM, licencja MPL-2.0. Klucz rozszczelnienia jest w
pieczęci `systemd-creds` na vTPM. Pod zgłasza się metodą Kubernetes i dostaje
poświadczenie własnej bazy na godzinę. Rola News nie czyta bazy Identity.

Do tego czasu numery `01`–`07` tylko pilnują, żeby sekret i plik SOPS nie
weszły do gita. HashiCorp Vault i Keycloak nie wchodzą. Token deweloperski z
laptopa na tym serwerze nie działa. OpenBao nie dostaje publicznego hostname.

### [15-skalowanie.md](15-skalowanie.md)

Po [kontakcie](../api/21-kontakt.md), przed [piramidą testów](../api/22-testy.md).
HPA podnosi drugi pod tej samej usługi, gdy CPU przekroczy 70
procent requestu albo liczba żądań HTTP w toku przekroczy 20. Sufit to dwie
repliki. Podłoga to jedna.

Siedem obiektów: pięć usług, brama i web. Postgres, Kafka, Redis, OpenBao,
telemetria i konektor tunelu nie dostają HPA. Inbox sprawia, że drugi konsument
nie zastosuje tej samej wiadomości drugi raz. Aspire zostaje przy jednej
replice. Tagowanie się nie zmienia.

### [16-deploy.md](16-deploy.md)

Zaraz po [bramie](../api/16-gateway.md), przed Identity. Deploy ponumerowanego
tagu i rollback do poprzedniego tagu tego
samego komponentu. Wejściem jest tag z numeru `07` oraz SBOM i atestacja z
numeru `04`. Job `publish` buduje jeden obraz na `ubuntu-latest`. Job `deploy`
na runnerze `jjdevhub` weryfikuje atestację i podmienia jeden digest.

Rollback jest tym samym jobem, z poprzednim tagiem, bez gałęzi `hotfix`. Pierwszy
rollout to brama. Identity, News, Learning, Cv, Contact, web i telefon idą tym
samym jobem, gdy ich numer jest gotowy. Stopka `web-vX.Y.Z` i ekran
`mobile-vX.Y.Z` są sprawdzane przy tagu weba i telefonu, nie przy pierwszym
rolloucie bramy. `GET /versions` zgadza się z tagiem właśnie wgranym i nie
podmienia sąsiadów. Deploy nie jest checkiem pull requestu w numerach `01`–`07`.
Nie jest też ostatnim krokiem produktu.

## Pierwszy pull request funkcji

Po wdrożeniu numerów `01`–`07`, a przed pierwszym projektem usługi, pull request
wygląda tak.

1. Gałąź `feature/lesson-markdown` wychodzi z `develop`.
2. Tytuł spełnia Conventional Commits. Dla przyszłej lekcji będzie to
   `feat(learning): …` z zakresem z listy. Sam dokument CI może iść jako
   `docs: …` albo `ci: …`.
3. Cel to `develop`. Job `branch-name` i `pr-title` oceniają naprawdę.
4. `build`, `unit-tests`, `integration-tests`, `performance` i `format` kończą
   się sukcesem, bo nie ma jeszcze `*.csproj` w komponencie. `codeql` kończy się
   sukcesem, gdy nie ma `*.cs`, `*.js`, `*.ts` ani `*.tsx`. Log mówi
   `no material`, a job nie jest skipped.
5. `gitleaks`, `zizmor`, `action-pins` i `scorecard` oceniają workflow dodane w
   `01`–`07`. Sekret w diffie i `uses` z tagiem `@v4` padają już tutaj.
6. `dependency-vulnerabilities` kończy się sukcesem, dopóki nie ma lockfile ani
   projektu. `package.json` bez lockfile pada.
7. Wejście na `release` uruchamia `sonarqube` i `image-scan`, i powtarza testy
   oraz `codeql`. Bez kodu i bez Dockerfile te joby raportują sukces.
8. Wejście na `main` uruchamia `sbom`, `attestations` i `release-tags`, i
   powtarza testy. Tag powstaje tylko dla komponentu, którego plik wersji się
   zmienił. Wersja `0.0.0` tagu nie dostaje.

Gałąź `feature/lesson_markdown` pada na `branch-name` niezależnie od tego, czy
katalog Learning już jest. Zielony `build` tej nazwy nie naprawia.

Gdy później dojdzie projekt usługi, nie dodaje się drugiej bramki. Te same joby
przestają wychodzić pustym sukcesem i zaczynają kompilować, testować i skanować
dotknięty komponent. Projekt produkcyjny bez projektu testowego nie jest pustym
sukcesem `unit-tests`.

## Zasady wspólne dla `01`–`07`

- Workflow pull requestu ustawia `permissions` najwężej, jak da się wykonać job.
  Wartość sekretu aplikacji nie występuje w YAML.
- `pull_request_target` nie występuje.
- `runs-on` to `ubuntu-latest`.
- Akcja w `uses` ma pełny SHA commita i komentarz z tagiem wersji. Sprawdza to
  job `action-pins`.
- Ruleset w `.github/rulesets` jest źródłem prawdy. Ustawienie wyklikane w
  interfejsie i niezapisane do pliku wraca do treści pliku przy najbliższym
  syncu.
- Nazwę checka dopisuje się do rulesetu w tym samym scaleniu, w którym workflow
  zaczyna tę nazwę raportować.
- Komponenty wydają się osobno. Zmiana News nie przebudowuje obrazu Identity.
- Pusty sukces jest jawny w logu. Pominięty job nie zastępuje zielonego statusu.
- Harmonogram poniedziałkowy, tam gdzie numer go ma, nie dostaje sekretu i nie
  zastępuje checka pull requestu.

## Poza tym folderem w numerach `01`–`07`

| Temat | Gdzie |
| --- | --- |
| Host Aspire, Postgres, Redis, mediator, usługi | [docs/api](../api/README.md) |
| Stopka `web-vX.Y.Z` | [docs/frontend/02-web.md](../frontend/02-web.md) |
| Ekran O aplikacji z `mobile-vX.Y.Z` | [docs/frontend/06-mobile.md](../frontend/06-mobile.md) |
| `GET /versions` | [docs/api/16-gateway.md](../api/16-gateway.md) |
| OpenBao w AppHost | [docs/api/04-openbao.md](../api/04-openbao.md) |
| OpenBao na VM | [14-openbao.md](14-openbao.md) |
| Deploy i rollback | [16-deploy.md](16-deploy.md) |

Numery `08`–`16` nie zmieniają nazw checków z tabeli bramek. Dokładają maszynę,
na którą tag już wolno wgrać. Schemat tabel, trasy YARP i treść ekranu zostają
w swoich folderach. Ten indeks ich nie powtarza.

## Jak sprawdzić sam indeks

```bash
test -f docs/cicd/README.md
test -f docs/cicd/01-galezie.md
test -f docs/cicd/02-bramki.md
test -f docs/cicd/03-codeql.md
test -f docs/cicd/04-zaleznosci-i-obrazy.md
test -f docs/cicd/05-sonarqube.md
test -f docs/cicd/06-lancuch-dostaw.md
test -f docs/cicd/07-wersje.md
test -f docs/cicd/08-proxmox.md
test -f docs/cicd/09-cloudflare.md
test -f docs/cicd/10-opentelemetry.md
test -f docs/cicd/11-prometheus.md
test -f docs/cicd/12-jaeger.md
test -f docs/cicd/13-grafana.md
test -f docs/cicd/14-openbao.md
test -f docs/cicd/15-skalowanie.md
test -f docs/cicd/16-deploy.md
```

Te polecenia sprawdzają, że specyfikacja szesnastu numerów jest w drzewie. Nie
sprawdzają, że VM już stoi i że workflow już raportuje check. Maszyna i tunel
powstają po numerze `07`, zanim powstanie Aspire. Deploy powstaje po bramie.
Ich brak jako procesów, przy obecności plików specyfikacji, jest zgodny z tym,
że specyfikacja wyprzedza pracę.

## Źródła

- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets).
  Wiążący jest ruleset zapisany jako plik, a nie ochrona wyklikana tylko w
  interfejsie. Dotyczy trzech długich gałęzi i tego, że nazwa checka w JSON
  jest tą samą nazwą co job. Ze źródła nie bierzemy wymaganej drugiej recenzji.
  Produkt utrzymuje jedna osoba. Bramką jest check.
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
  Wiążące są typ, zakres i znak `!`. Dotyczy tytułu pull requestu i tego, że
  squash na `develop` zapisuje ten tytuł jako commit, z którego numer `07` liczy wersję. Ze
  źródła nie bierzemy zakresu spoza listy komponentów, `infra` i `shared`.
  `docs(cicd):` pada, bo `cicd` nie jest zakresem.
- [Required status checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging).
  Wiążące jest to, że check, który nie raportuje statusu, blokuje scalenie.
  Dotyczy zakazu `paths` na workflow wymaganym przez ruleset i pustego sukcesu
  z jawnym logiem. Ze źródła nie bierzemy pominiętego joba jako zielonego.
- [SemVer](https://semver.org/lang/pl/). Wiążące są major, minor, patch i seria
  `0.y.z`. Dotyczy osobnego numeru każdego komponentu i tego, że przed `1.0.0`
  złamanie podbija minor. Ze źródła nie bierzemy jednego tagu `vX.Y.Z` na całe
  repozytorium. Tag News nie przebudowuje Identity.
- [k3s](https://docs.k3s.io/installation). Wiążące są flagi, które zostawiają
  jeden węzeł bez Traefika i bez ServiceLB. Dotyczy numeru `08` i tego, że
  YARP jest jedyną bramą HTTP. Ze źródła nie bierzemy chmury publicznej ani
  drugiego mastera. Cel runtime to jedna maszyna.
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/).
  Wiążące jest wyjście z klastra i origin wskazany nazwą Service. Dotyczy
  numeru `09` i tego, że publiczny hostname aplikacji kończy się na
  `gateway`. Ze źródła nie bierzemy otwartego portu 443 na gościu ani osobnego
  hostname na każdą usługę.
- [OpenTelemetry](https://opentelemetry.io/docs/concepts/). Wiążące są trzy
  sygnały i zasób z `service.name`. Dotyczy numerów `10`–`13`: collector,
  Prometheus, Jaeger i Grafana czytają to, co ServiceDefaults już eksportuje.
  Ze źródła nie bierzemy drugiego SDK w `Program.cs` ani dashboardu Aspire
  jako magazynu maszyny.
- [OpenBao](https://openbao.org/docs/what-is-openbao/). Wiążący jest serwer
  sekretów na MPL-2.0 oraz rola, ścieżka i czas życia. Dotyczy numeru `14`.
  Ze źródła nie bierzemy HashiCorp Vault ani pliku SOPS w git. Numery `01`–`07`
  sekretu nie czytają. Pilnują tylko, żeby nie wszedł do drzewa.
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).
  Wiążące są podłoga, sufit i więcej niż jeden sygnał. Dotyczy numeru `15`:
  minimum 1, maksimum 2, CPU i żądania w toku. Ze źródła nie bierzemy trzeciej
  repliki ani HPA na Postgresie. Drugi pod serwuje to samo HTTP.
- [Artifact attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds).
  Wiążące jest powiązanie digestu z przebiegiem, bez klucza w git. Dotyczy
  numeru `04`, który atestację składa, i numeru `16`, który ją weryfikuje przed
  `kubectl`. Ze źródła nie bierzemy tagu `:latest` jako referencji na klastrze.
  Obraz bez atestacji nie jest wydaniem.

## Gotowe gdy

- Istnieje szesnaście pozycji `01`–`16` w tym pliku i każda mówi, co zamyka.
- Z tabeli bramek da się odczytać nazwę checka i plik workflow.
- Widać, że `01`–`07` są przed kodem usługi, maszyna i tunel zaraz po nich,
  deploy zaraz po bramie, a drugi pod po usługach i przed frontendem.
- Widać, że tag powstaje w `07`, a pierwszy obraz wjeżdża w `16`, zanim powstaną pozostałe usługi.
- Widać, że sekret aplikacji i plik SOPS nie wchodzą do workflowów `01`–`07`,
  a serwer sekretów na VM jest w `14`.
- `## Źródła` w tym pliku jest listą zdań, nie tabelą z jedną komórką.
- Polecenia `test -f` z sekcji sprawdzenia indeksu kończą się kodem zero dla
  szesnastu plików numerów i dla tego README.
