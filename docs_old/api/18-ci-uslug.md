# CI usług

Jeden workflow `ci.yml` wykrywa, które usługi zmienił commit, i dla każdej woła reużywalny `_dotnet-service.yml`: build i testy. Obraz z `dotnet publish -t:PublishContainer` powstaje przy wydaniu usługi: `release.yml` z [docs/CICD/11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md) woła ten sam workflow z obrazem, skanem Trivy, SBOM i atestacją, a obraz trafia do rejestru w sieci lokalnej. Deploy startuje z wydania, sprawdza atestację każdego obrazu ([docs/CICD/13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md)), uruchamia migracje osobnym krokiem i podnosi Compose wygenerowany przez Aspire z [14-aspire.md](14-aspire.md). Sekrety przychodzą z plików SOPS jako sekrety Compose ([docs/CICD/12-sekrety.md](../CICD/12-sekrety.md)). Ten numer przenosi też VM na nowy układ: nginx kieruje ruch na gateway, Prometheus zbiera metryki z pięciu usług (numery `19`–`22` dokładają dwie), a ślady idą do Jaegera pod nowymi nazwami. Obecny układ (runner `jjdevhub`, `release.yml`, `deploy.yml`, Sonar) jest opisany w [docs/CICD/03-github.md](../CICD/03-github.md), [10-sonarqube.md](../CICD/10-sonarqube.md) i [11](../CICD/11-branche-i-wydania.md)–[13](../CICD/13-lancuch-dostaw.md). Ten numer go rozszerza i na końcu wymienia, co w tamtych plikach trzeba zaktualizować.

## Po co

Dziś jest jeden `api.yml` dla jednego API i jeden kontener `api` na VM. Przy pięciu usługach jeden workflow budowałby wszystko przy każdej zmianie, a jeden czerwony test Notifications blokowałby deploy poprawki w News. Pięć osobnych workflowów z filtrami `paths` ma za to inny problem: wymagany check z workflowu, który się nie uruchomił, zostawia PR w stanie „Expected — waiting” na zawsze ([docs/CICD/03-github.md](../CICD/03-github.md) opisuje to przy `api` i `web`). Dlatego workflow jest jeden, uruchamia się zawsze, a w środku decyduje, które usługi budować. Wymagany check jest jeden: `ci`.

Obraz buduje się raz, przy wydaniu usługi. Merge na `main` testuje, ale nie wdraża: wdraża dopiero wydanie z [11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md), z numerem wersji i changelogiem. Na produkcję trafia dokładnie ten obraz, który przeszedł testy i skan, wskazany digestem `sha256:…` i sprawdzony atestacją podpisaną przez workflow z tego repozytorium. [13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md) robi to dla archiwum obrazu z artefaktu. Ten numer przenosi to samo na rejestr.

Do tego dochodzi przejście VM. [docs/CICD](../CICD/README.md) zna kontener `api` na `127.0.0.1:5080`, job Prometheusa `jjdevhub-api`, `service.name` `JJDevHub.Api`, komponent wydania `api` i jeden plik sekretów `infra/secrets/api.sops.env`. Po tym numerze żadna z tych rzeczy nie jest prawdą, więc przejście musi być opisane krok po kroku, razem z przeniesieniem danych z obecnej bazy.

## Dlaczego ta technologia

### GitHub Actions i dwa rodzaje runnerów

Kod jest na GitHubie, workflow już istnieją, a Actions jest darmowe dla repozytoriów publicznych. Jenkins (trzymany poza drzewem) wymagałby osobnego serwera z wtyczkami. GitLab CI wymagałby przeniesienia repozytorium.

PR wykonuje cudzy albo niesprawdzony kod: `dotnet test` może zrobić wszystko, na co pozwala proces, a z gniazdem Dockera (Testcontainers) to w praktyce root na maszynie. GitHub odradza self-hosted runnery dla PR w repozytoriach publicznych, a [docs/CICD/03-github.md](../CICD/03-github.md) i [10-sonarqube.md](../CICD/10-sonarqube.md) trzymają PR na `ubuntu-latest`. Ten numer to zachowuje. `ubuntu-latest` ma Dockera, więc Testcontainers działa tam bez zmian.

Self-hosted runner jest potrzebny tam, gdzie hostowany nie dosięgnie: push obrazu do rejestru w domowej sieci i deploy na VM. To robi tylko kod z `main`, który przeszedł review. Są dwa runnery, bo mają inne uprawnienia:

- `jjdevhub-build` na osobnej VM: buduje obrazy wydań, ma Dockera i rejestr, nie ma sekretów produkcji,
- `jjdevhub` na VM produkcji, jak dziś: deploy i Sonar, ma dostęp do klucza odszyfrowania sekretów z [12-sekrety.md](../CICD/12-sekrety.md).

Gdyby obraz budował runner produkcji, kompilacja i testy `main` konkurowałyby o pamięć z działającymi usługami na VM, która i tak jest ciasna (sekcja „Zasoby VM”).

### Runner efemeryczny

Zwykły runner zostawia stan między jobami: pliki w katalogu roboczym, kontenery, zmienne. Flaga `--ephemeral` sprawia, że runner bierze jeden job i się wyrejestrowuje, a systemd stawia nowy kontener z czystego obrazu. Kod z `main` jest zaufany, ale czysty start usuwa całą klasę błędów „u mnie działa, bo został plik z poprzedniego joba”. Actions Runner Controller robi to samo na Kubernetes. Na jednej VM pętla systemd wystarcza.

### Jeden `ci.yml` z wykrywaniem zmian zamiast filtrów `paths`

Filtr `paths` decyduje, czy workflow w ogóle startuje. Pominięty workflow nie raportuje statusu, więc nie może być wymaganym checkiem. Wykrywanie zmian wewnątrz workflowu odwraca to: `ci.yml` startuje zawsze, job `changes` liczy listę usług z `git diff`, macierz buduje tylko je, a job `ci` na końcu raportuje jeden status. Pominięta usługa to pominięty job w macierzy, nie brak checka.

Do wykrywania jest gotowa akcja `dorny/paths-filter` (MIT). Własny skrypt `infra/ci/changed-services.mjs` wygrywa, bo repo ma już ten wzór (`deploy-gate.mjs` z testem `node --test`), mapa usług jest w jednym pliku JSON, którego używa też deploy, a reguła „zmiana w `src/building-blocks/**` buduje wszystko” jest testowana.

### Reużywalny workflow

Pięć usług z tym samym przepisem (restore, audit, build, test, obraz, skan) to jedna definicja z parametrami. `workflow_call` z macierzą daje osobny job na usługę w widoku GitHuba. Composite action działa na poziomie kroków, więc nie da osobnych jobów `test` i `image` ani różnych `runs-on` w jednym przepisie.

### Obraz z `dotnet publish` zamiast Dockerfile

SDK .NET od wersji 8 buduje obraz OCI sam (`-t:PublishContainer`): bierze obraz bazowy `aspnet` w wersji SDK, ustawia użytkownika bez roota, port i etykiety. Dockerfile na usługę to pięć plików, w których łatwo zapomnieć o `USER` albo podbiciu bazy. Dockerfile zostaje tam, gdzie SDK .NET nie ma zastosowania: klient web ma swój `web/Dockerfile`.

### Lokalny rejestr i digest

GHCR byłby wygodny, ale VM produkcji potrzebowałaby tokenu do pobierania, a obrazy wychodziłyby z domowej sieci i wracały. `registry:2` (Distribution, Apache 2.0) w LAN-ie nie wymaga sekretu GitHuba. Tag można nadpisać, digest `sha256:…` nie: to skrót zawartości. Wdrożenie po digeście gwarantuje, że produkcja uruchamia ten obraz, który przeszedł testy i Trivy.

Digest mówi „ten sam obraz”, ale nie mówi „zbudowany przez nasz workflow”. To daje atestacja z [13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md): GitHub podpisuje digest razem z nazwą workflowu i commitem, a deploy sprawdza podpis przed `up`. Atestacja leży w GitHubie, nie w rejestrze, więc `registry:2` nie musi jej obsługiwać. `gh attestation verify oci://…` czyta z rejestru tylko manifest, ale robi to po HTTPS, więc rejestr dostaje certyfikat z lokalnego CA.

### Migracje jako osobny krok

`Database.Migrate()` przy starcie jest wygodne w dev (`DevelopmentMigrator` z [16-usluga-news.md](16-usluga-news.md)). Na produkcji dwie repliki migrują naraz, usługa potrzebuje uprawnień DDL, a nieudana migracja to pętla restartów. `efbundle` to samodzielny plik wykonywalny z migracjami, uruchamiany raz przed `compose up`. Błąd zatrzymuje deploy, zanim stara wersja zniknie.

### Trivy

Trivy (Apache 2.0) skanuje obraz pod kątem znanych podatności. Już jest w [infra/ci/trivy-api.sh](../../infra/ci/trivy-api.sh). Grype (Apache 2.0) jest równoważny i przegrywa tylko dlatego, że drugi skaner nie zmienia wyniku. Koszt: kolejny krok w jobie obrazu i próg, od którego CVE zatrzymuje wydanie.

### Telemetria zostaje, zmienia się adresacja

Prometheus, Jaeger i Grafana z [docs/CICD/07](../CICD/07-prometheus.md)–[09](../CICD/09-grafana.md) zostają. Aspire na serwerze ich nie zastępuje: dashboard Aspire nie ma retencji ani alertów. Zmienia się to, co oni widzą: cel na każdą usługę zamiast jednego, nazwy usług z Aspire i endpoint śladów w `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` zamiast wspólnego. Kod po stronie usług (endpointy na sygnał, filtr śladów, mierniki) jest w [14-aspire.md](14-aspire.md).

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `.github/workflows/ci.yml` | `changes` → macierz `service` → `contracts`, `building-blocks`, `lint` → `ci` (jedyny wymagany check .NET) |
| `.github/workflows/_dotnet-service.yml` | reużywalny: test; z wejściem `release-tag` także obraz, Trivy, SBOM, atestacja, push, artefakt z digestem |
| `.github/workflows/apphost.yml` | `JJDevHub.AppHost.Tests` co noc i ręcznie |
| `.github/workflows/release.yml` | z [11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md): release-please, gate, obrazy wydanych usług, deploy |
| `.github/workflows/deploy.yml` | ponowne wdrożenie albo rollback zapisanych digestów |
| `release-please-config.json`, `.release-please-manifest.json` | komponent na usługę zamiast `api` |
| `infra/secrets/<usługa>.sops.env`, `infra/secrets/compose.sops.env` | sekrety usług z [12-sekrety.md](../CICD/12-sekrety.md) |
| `.github/workflows/api.yml` | usunięty; kroki przejmuje `ci.yml` |
| `.github/workflows/web.yml` | bez zmian |
| `infra/ci/services.json` | usługa → projekt, testy, obraz, migracje, ścieżki, klucz Sonara |
| `infra/ci/changed-services.mjs`, `changed-services.test.mjs` | lista usług z `git diff` |
| `infra/ci/deploy-gate.mjs`, `deploy-gate.test.mjs` | wymagane workflowy: `ci` i `web` |
| `infra/ci/release-and-deploy.sh` | weryfikacja atestacji, obrazy po digeście, migracje, smoke, rollback |
| `infra/ci/trivy-image.sh` | skan dowolnego obrazu (z `trivy-api.sh`) |
| `infra/ci/migrate-from-single-api.sh` | jednorazowe przejście VM: dump starej bazy `jjdevhub`, odtworzenie do `identity_write`, przeniesienie env |
| `infra/runner/Dockerfile`, `infra/runner/jjdevhub-build-runner.service` | efemeryczny runner build |
| `infra/docker/docker-compose.yml` | zostają `web`, `prometheus`, `jaeger`, `grafana`; znikają `db` i `api`; sieć `jjdevhub` jako zewnętrzna |
| `src/Clients/web/nginx.conf` | `/api/`, `/.well-known/`, `/health` → `gateway:8080` |
| `infra/prometheus/prometheus.yml` | job na usługę |
| `infra/grafana/dashboards/jjdevhub-services.json` | zastępuje `jjdevhub-api-overview.json` |
| `src/aspire/JJDevHub.AppHost/AppHost.cs` | parametry obrazów i endpointu śladów w trybie publikacji, porty, limity pamięci |
| `.cursor/rules/github-workflows.mdc` | reguła przepisana pod `ci.yml` |

## Plan

### 1. Zasoby VM

[docs/CICD/01-proxmox.md](../CICD/01-proxmox.md) daje VM 4096 MB. Po tym numerze na VM produkcji działają:

| Kontener | Limit pamięci |
| --- | --- |
| `postgres` | 512 MB |
| `kafka` (`KAFKA_HEAP_OPTS=-Xms256m -Xmx512m`) | 768 MB |
| `identity-api`, `news-api`, `gateway`, `notifications-worker` | po 256 MB |
| `web` (nginx) | 64 MB |
| `prometheus` | 384 MB |
| `jaeger` (`max_traces: 10000`) | 256 MB |
| `grafana` | 256 MB |
| `sonarqube` + `sonarqube-db` ([10-sonarqube.md](../CICD/10-sonarqube.md)) | około 2,5 GB |

Razem około 6,5 GB plus system i Docker. Minimum to 8 GB.

Numery `19`–`22` dokładają dwie usługi i podnoszą limit Postgresa:

| Kontener | Limit pamięci | Od numeru |
| --- | --- | --- |
| `learning-api` (model ONNX w pamięci procesu) | 768 MB | `19`, `20` |
| `cv-api` (Typst jako proces potomny przy renderze) | 384 MB | `22` |
| `postgres` (indeks HNSW, `maintenance_work_mem` przy budowie) | 768 MB zamiast 512 MB | `20` |

Po nich siedem usług i razem około 7,5 GB. Minimum to 10 GB, zalecane 12 GB. VM `jjdevhub-build`: 4 GB i 2 vCPU, bo testy `main` uruchamiają Postgresa i Kafkę w Testcontainers. Limity ustawia AppHost w trybie publikacji (callback `PublishAsDockerComposeService`, nazwy właściwości według wersji Aspire z `Directory.Packages.props`). .NET w kontenerze z limitem sam dopasowuje stertę GC.

Kafka UI z `WithKafkaUI()` działa tylko w dev i nie trafia do publikacji.

### 2. Runnery

| Runner | Etykiety | Gdzie | Joby |
| --- | --- | --- | --- |
| hostowany | `ubuntu-latest` | GitHub | wszystkie joby PR: `changes`, testy, `contracts`, `building-blocks`, `lint`, `ci` |
| build | `[self-hosted, jjdevhub-build]` | VM Proxmox `jjdevhub-build` | na `push` do `main`: testy; w `release.yml`: testy i obraz |
| produkcja | `[self-hosted, jjdevhub]` | VM produkcji, jak dziś | na `push` do `main`: Sonar; job `deploy` w `release.yml` i `deploy.yml` |

`runs-on` w `_dotnet-service.yml` to wyrażenie: `github.event_name == 'pull_request' && 'ubuntu-latest' || 'jjdevhub-build'` z etykietą `self-hosted`. Żaden job wywołany przez `pull_request` nie trafia na self-hosted. To jest warunek, nie konwencja: test `actionlint` z regułą w `lint` sprawdza, że każde `runs-on` z `self-hosted` ma obok `if` z `github.event_name != 'pull_request'` albo wyrażenie wyżej.

Runner build: `infra/runner/Dockerfile` na bazie `ghcr.io/actions/actions-runner` z SDK .NET z [global.json](../../global.json), Node 22 i Trivy. Systemd uruchamia kontener w pętli z `--ephemeral`. Token rejestracji (GitHub App albo PAT z uprawnieniem do runnerów) leży w `infra/secrets/runner.sops.env`, zaszyfrowany dla klucza VM build i klucza właściciela, i odszyfrowuje się tym samym mechanizmem co na produkcji ([12-sekrety.md](../CICD/12-sekrety.md)). Kontener dostaje gniazdo Dockera VM build. VM build widzi VM produkcji tylko na porcie rejestru.

### 3. Rejestr

`registry:2` na VM build, port `5000`, tylko z LAN-u Proxmoxa. Adres to zmienna repozytorium `vars.REGISTRY` (np. `registry.jjdevhub.lan:5000`), nie sekret. Certyfikat wystawia lokalne CA (`step-ca` albo jednorazowy `openssl`), a obie VM mają certyfikat CA w magazynie systemu i w `/etc/docker/certs.d/<adres>/ca.crt`. `insecure-registries` odpada, bo weryfikacja atestacji po `oci://` wymaga HTTPS.

Obrazy: `jjdevhub/identity-api`, `jjdevhub/news-api`, `jjdevhub/notifications-worker`, `jjdevhub/gateway`, `jjdevhub/web` oraz `jjdevhub/<usługa>-migrations`. `19` i `22` dokładają `jjdevhub/learning-api` i `jjdevhub/cv-api`. Obraz web przechodzi z archiwum w artefakcie ([13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md)) na ten sam rejestr.

### 4. Mapa usług i wykrywanie zmian

`infra/ci/services.json`:

```json
{
  "shared": ["src/building-blocks/**", "src/aspire/JJDevHub.ServiceDefaults/**", "Directory.Packages.props", "Directory.Build.props", "global.json", ".github/workflows/ci.yml", ".github/workflows/_dotnet-service.yml"],
  "services": {
    "news": {
      "paths": ["src/services/News/**", "tests/News.*/**"],
      "releasePath": "src/services/News",
      "project": "src/services/News/News.API/News.API.csproj",
      "tests": ["tests/News.Domain.Tests", "tests/News.Application.Tests", "tests/News.Infrastructure.Tests", "tests/News.API.Tests"],
      "image": "jjdevhub/news-api",
      "migrations": [
        { "context": "NewsWriteContext", "project": "src/services/News/News.Infrastructure" },
        { "context": "NewsReadContext", "project": "src/services/News/News.Infrastructure" }
      ],
      "secrets": ["ConnectionStrings__news-write", "ConnectionStrings__news-read"],
      "sonarKey": "jjdevhub-news"
    }
  }
}
```

Pozostałe usługi analogicznie. Identity zachowuje `sonarKey` `jjdevhub-api`, żeby historia analizy z [10-sonarqube.md](../CICD/10-sonarqube.md) nie przepadła. Notifications ma w `paths` oba `*.Contracts`.

`releasePath` to ścieżka komponentu w `release-please-config.json`, a klucz usługi (`news`) to nazwa komponentu i przedrostek tagu (`news-v1.4.0`). `release.yml` zamienia `paths_released` z release-please na klucze usług przez to pole. Opcjonalne `setup` to skrypt uruchamiany przed testami, gdy usługa potrzebuje pliku spoza repozytorium: model wektorów w [20-wyszukiwanie.md](20-wyszukiwanie.md), Typst w [22-cv.md](22-cv.md). Workflow trzyma jego wynik w `actions/cache` z kluczem z sumy manifestu.

Numery `19`–`22` dopisują swoje usługi do `services.json`, do `release-please-config.json` i do `infra/prometheus/prometheus.yml` w tym samym PR co kod usługi. Smoke deployu liczy cele Prometheusa z `services.json`, więc nowa usługa nie wymaga zmiany skryptu.

`changed-services.mjs` dostaje bazę porównania (`github.event.pull_request.base.sha` albo `github.event.before`) i wypisuje `services=["news"]` do `GITHUB_OUTPUT`. Zmiana pliku z `shared` zwraca wszystkie usługi. `workflow_dispatch` i pierwszy push gałęzi (baza `0000…`) też.

### 5. `ci.yml`

`on: pull_request`, `push` na `main`, `workflow_dispatch`. Bez `paths`.

- `changes` — checkout z `fetch-depth: 0`, `node --test infra/ci/changed-services.test.mjs`, potem `changed-services.mjs`,
- `service` — `needs: changes`, `if: needs.changes.outputs.services != '[]'`, `strategy.matrix.service: ${{ fromJson(needs.changes.outputs.services) }}`, `uses: ./.github/workflows/_dotnet-service.yml` z `service: ${{ matrix.service }}`,
- `building-blocks` — testy `tests/JJDevHub.*.Tests` bez obrazu, gdy zmienił się `shared`,
- `contracts` — `tests/JJDevHub.Contracts.Tests`, gdy zmieniły się `*.Contracts`,
- `lint` — `actionlint`, `shellcheck infra/ci/*.sh`, `infra/ci/observability-smoke.sh` (zostaje z `api.yml`),
- `ci` — `needs` wszystkich powyżej, `if: always()`, kończy się błędem, gdy którykolwiek wynik to `failure` albo `cancelled`. `skipped` jest w porządku.

Ruleset `main` z [docs/CICD/11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md) (`.github/rulesets/main.json`): wymagane checki `ci`, `web`, `pr-title` i `secrets` zamiast `api`, `web`, `pr-title` i `secrets`, potem `apply-rulesets.sh`.

### 6. Reużywalny workflow

`_dotnet-service.yml`, `on: workflow_call`, wejścia `service` i opcjonalne `release-tag`. Pierwszy krok czyta parametry usługi z `services.json` (`jq`), więc wywołanie ma jedno wejście obowiązkowe.

- `test` — macierz po `tests`: `setup` usługi, gdy jest, `setup-dotnet` z [global.json](../../global.json), `restore`, `infra/ci/nuget-audit.sh`, `build -c Release`, `dotnet test` z coverage, artefakt wyników,
- `image` — po `test`, tylko gdy `release-tag` jest niepusty (wywołanie z `release.yml`), na `jjdevhub-build`:
  - `dotnet publish {project} -c Release -t:PublishContainer -p:ContainerRepository={image} -p:ContainerImageTag={release-tag}`, wersja w etykiecie `org.opencontainers.image.version`,
  - `infra/ci/trivy-image.sh {image}:{release-tag}` z progiem `HIGH,CRITICAL`,
  - `docker push`, digest z `docker inspect --format '{{index .RepoDigests 0}}'`,
  - SBOM `trivy image --format cyclonedx` dla digestu,
  - `actions/attest-build-provenance` i `actions/attest-sbom` z `subject-name: {registry}/{image}` i `subject-digest`, bez `push-to-registry`,
  - dla każdej migracji `dotnet ef migrations bundle --self-contained -r linux-x64 --context {context} --project {project}`, obraz `{image}-migrations`, push, digest, atestacja,
  - artefakt `digest-{service}` z dwiema liniami `image=` i `migrations=`,
- `sonar` — po `test`, tylko na `push` do `main`, na `[self-hosted, jjdevhub]`, bo SonarQube słucha na `127.0.0.1:9000` VM produkcji. `environment: sonar` z [12-sekrety.md](../CICD/12-sekrety.md). Klucz projektu z `sonarKey`. Token: jeden globalny token analizy `SONAR_TOKEN_SERVICES` dla usług .NET zamiast tokenu na projekt. `SONAR_TOKEN_WEB` zostaje dla `web.yml`.

Uprawnienia workflowu: `contents: read`, `actions: read`. Job `image` dodaje `id-token: write` i `attestations: write`, bo atestacja potrzebuje tokenu OIDC i zapisu w API atestacji. Push do lokalnego rejestru nie wymaga sekretu GitHuba. Akcje są przypięte po SHA ([13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md)).

Podpisującym atestacji jest reużywalny workflow, nie `release.yml`. Deploy sprawdza więc `--signer-workflow jtjaskulski/JJDevHub/.github/workflows/_dotnet-service.yml`: obraz musiał zbudować ten jeden przepis, bez względu na to, kto go wywołał.

### 7. Telemetria na VM

Zmiany w plikach z [docs/CICD](../CICD/README.md), wdrażane razem z pierwszym deployem nowego układu:

- `infra/prometheus/prometheus.yml` — zamiast `jjdevhub-api` jeden job na usługę: `job_name` równe nazwie zasobu (`identity-api`, `news-api`, `notifications-worker`, `gateway`), cel `<nazwa>:8080`, `metrics_path: /metrics`, `scrape_interval: 15s`. Prometheus jest w sieci `jjdevhub` razem z usługami z Compose Aspire.
- `infra/grafana/dashboards/jjdevhub-services.json` — zmienna `service` z `label_values(up, job)`, panele: `up{job=~"$service"}`, tempo i p95 z `http_server_request_duration_seconds_*` po `http_route`, `jjdevhub_projection_lag`, `jjdevhub_outbox_pending`, `jjdevhub_kafka_consumer_lag`, `rate(jjdevhub_kafka_dlq_total[5m])`. Stary `jjdevhub-api-overview.json` znika, jego `uid` przestaje istnieć.
- Ślady: AppHost w trybie publikacji ustawia każdej usłudze `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` z parametru `otlp-traces-endpoint` (`http://jaeger:4317` w `compose.env`). `OTEL_EXPORTER_OTLP_ENDPOINT` zostaje puste, więc metryki i logi nie idą do Jaegera ([14-aspire.md](14-aspire.md), krok 3a). `OTEL_SERVICE_NAME` to nazwa zasobu. W Jaegerze i w Explore Grafany usługi to `identity-api`, `news-api`… zamiast `JJDevHub.Api`.
- `max_traces: 10000` w [infra/jaeger/config.yaml](../../infra/jaeger/config.yaml) zostaje. Filtr `/metrics` i `/health` oraz sampler z 14 utrzymują ruch tła blisko zera.

### 8. Porty i nginx

W wygenerowanym Compose port na hoście ma tylko gateway: `127.0.0.1:5080:8080`, ten sam co dziś API. Skrypt deployu i ręczny `curl 127.0.0.1:5080/health` działają dalej, a `/metrics` usług nie jest widoczne z LAN-u ([docs/CICD/07-prometheus.md](../CICD/07-prometheus.md)). Postgres: `127.0.0.1:5433:5432`, jak dziś `db`. Kafka bez portu na hoście. AppHost ustawia to w callbacku publikacji. `aspire publish` w CI kończy się `grep` na wygenerowanym pliku: każdy wpis `ports:` zaczyna się od `127.0.0.1:`, inaczej job pada.

[src/Clients/web/nginx.conf](../../src/Clients/web/nginx.conf): `location /api/`, `location /.well-known/` i `location = /health` kierują na `http://gateway:8080`. `/openapi/` i `/scalar` znikają, bo w produkcji i tak nie działały ([docs/CICD/02-cloudflare-tunnel.md](../CICD/02-cloudflare-tunnel.md)). Tunel Cloudflare się nie zmienia: origin `127.0.0.1:4200`, hostname'y Grafany, Jaegera i Prometheusa bez zmian.

### 9. Sekrety i env

Mechanizm jest z [12-sekrety.md](../CICD/12-sekrety.md): zaszyfrowane pliki w `infra/secrets/`, odszyfrowane na VM przez `jjdevhub-secrets.service` do `/run/jjdevhub/secrets/` (tmpfs), podane kontenerom jako sekrety Compose i czytane przez `AddKeyPerFile`. Ten numer dzieli pliki na usługi:

| Plik w gicie | Klucze | Skąd |
| --- | --- | --- |
| `infra/secrets/compose.sops.env` | `POSTGRES_PASSWORD`, `GRAFANA_ADMIN_PASSWORD` | bez zmian z 12 |
| `infra/secrets/identity.sops.env` | `ConnectionStrings__identity` | z `api.sops.env`; `Jwt__Key` znika |
| `infra/secrets/identity-signing.sops.pem` | klucz RSA z [15-identity.md](15-identity.md) | nowy |
| `infra/secrets/news.sops.env`, `notifications.sops.env` | connection stringi baz usługi | nowe |
| `infra/secrets/learning.sops.env`, `cv.sops.env` | connection stringi baz usługi | od `19` i `22` |

AppHost w trybie publikacji (callback `PublishAsDockerComposeService`) usuwa z wygenerowanego `environment:` wpisy z wartością sekretną (connection stringi z hasłem) i dopisuje usłudze `secrets:` z plikami `/run/jjdevhub/secrets/<usługa>/<klucz>`. Identity dostaje jawne `Jwt__SigningKeyPath=/run/secrets/identity-signing.pem`. Postgres dostaje `POSTGRES_PASSWORD_FILE`, Grafana `GF_SECURITY_ADMIN_PASSWORD__FILE`. Wartości jawne (`Jwt__Issuer`, `Identity__Url`, `otlp-traces-endpoint`, adresy obrazów) zostają parametrami Aspire w wygenerowanym `.env`, a w pliku SOPS są niezaszyfrowane dzięki `unencrypted_regex` z [12-sekrety.md](../CICD/12-sekrety.md).

`OTEL_*` znikają z env: ustawia je AppHost. `infra/secrets/api.sops.env` zostaje do udanego pierwszego deployu jako punkt powrotu, potem jest usuwany. `services.json` dostaje pole `secrets` z listą plików usługi, a `release-and-deploy.sh` sprawdza, że każdy z nich jest w `/run/jjdevhub/secrets.list` (lista nazw z [12-sekrety.md](../CICD/12-sekrety.md)), zanim ruszy cokolwiek. Workflow nie zawiera sekretów produkcji.

### 10. Przejście z jednego API

Jednorazowo, ręcznie, przez `infra/ci/migrate-from-single-api.sh` na VM produkcji:

- wyłączenie `release.yml` i `deploy.yml` w GitHubie, żeby żadne wydanie nie wdrożyło się w trakcie,
- `pg_dump -Fc jjdevhub` z kontenera `jjdevhub-db` do `/var/lib/jjdevhub/backup/`,
- pliki z kroku 9 powstają wcześniej, w PR tego numeru, przez `sops edit` na maszynie właściciela; skrypt tylko sprawdza, że odszyfrowały się na VM,
- pierwszy deploy nowego układu bez usług (`postgres`, `kafka`), `pg_restore` do bazy `identity_write` w nowym Postgresie,
- pełny deploy, smoke, włączenie obu workflowów.

Stary kontener `jjdevhub-db` i jego volume zostają zatrzymane, nie usunięte, do czasu potwierdzenia, że logowanie działa na starych kontach.

Nowy Postgres może od razu wstać z obrazu `pgvector/pgvector:pg16`. Dane i tak przechodzą przez `pg_restore`, więc zmiana biblioteki C nie ma tu znaczenia, a [20-wyszukiwanie.md](20-wyszukiwanie.md) nie potrzebuje wtedy drugiego przejścia przez zrzut. AppHost dostaje wtedy `WithImage("pgvector/pgvector", "pg16")` w tym numerze.

### 11. Deploy

Deploy jest częścią `release.yml` z [11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md). Po scaleniu Release PR release-please tworzy tagi wydanych komponentów (`news-v1.4.0`, `web-v0.9.0`) i GitHub Release. Dalej, w tym samym przebiegu:

- `gate` — [infra/ci/deploy-gate.mjs](../../infra/ci/deploy-gate.mjs) w trybie wydania wymaga zielonego `ci` i `web` dla SHA wydania; brakujący przebieg uruchamia przez `workflow_dispatch` z `ref` równym tagowi i czeka,
- `images` — macierz po wydanych usługach (`paths_released` → klucze z `services.json`), `uses: ./.github/workflows/_dotnet-service.yml` z `release-tag`; wydanie komponentu `platform` (`src/building-blocks`, `src/aspire`) buduje obrazy wszystkich usług,
- `deploy` — na `[self-hosted, jjdevhub]`, `environment: production` (tylko `main`), `permissions: attestations: read`.

Job `deploy`:

- digesty z artefaktów `digest-*` tego przebiegu; dla usługi spoza wydania digest z `/var/lib/jjdevhub/images.env`,
- `gh attestation verify oci://{registry}/{image}@{digest} --repo jtjaskulski/JJDevHub --signer-workflow jtjaskulski/JJDevHub/.github/workflows/_dotnet-service.yml --source-ref refs/heads/main` dla każdego nowego obrazu i obrazu migracji, z `GH_TOKEN` równym tokenowi joba; błąd przerywa deploy, zanim cokolwiek się zmieni,
- `sudo systemctl start jjdevhub-secrets.service` z [12-sekrety.md](../CICD/12-sekrety.md) i sprawdzenie plików z pola `secrets`,
- `aspire publish -o /var/lib/jjdevhub/compose` z parametrami obrazów (`news-api-image=…@sha256:…`),
- migracje: `docker run --rm --network jjdevhub -v /run/jjdevhub/secrets/news:/run/secrets:ro --entrypoint /bin/sh {news-api-migrations}@{digest} -c './efbundle --connection "$(cat /run/secrets/ConnectionStrings__news-write)"'` dla każdego kontekstu; connection string czyta powłoka w kontenerze, więc nie trafia do argumentów na hoście; błąd przerywa deploy,
- `docker compose -f /var/lib/jjdevhub/compose/docker-compose.yaml up -d --wait --wait-timeout 180`,
- `docker compose -f infra/docker/docker-compose.yml -f infra/docker/docker-compose.prod.yml up -d` dla `web` i telemetrii,
- smoke jak `wait_http` w obecnym skrypcie: `127.0.0.1:5080/health` (gateway), `127.0.0.1:4200/health` (nginx → gateway), `127.0.0.1:16686/`, `127.0.0.1:9090/api/v1/targets` z liczbą celów `up` równą liczbie usług w `services.json`,
- sukces → zapis `images.env`, dopisanie go do `images.history` z tagami wydania, SHA do `last-release-sha`,
- porażka → `compose up` z poprzednim `images.env` i kod wyjścia 1.

`deploy.yml` zostaje do ręcznego `workflow_dispatch`: wejście `release` (tag albo `previous`) wybiera wpis z `images.history`, sprawdza atestacje tych digestów ponownie i woła ten sam skrypt. Cron znika w [13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md): job czeka na runner do 24 godzin, a cron nie miałby tokenu do weryfikacji atestacji.

Migracje są wstecznie zgodne (dodanie kolumny teraz, usunięcie w kolejnym wydaniu), więc rollback obrazów nie wymaga rollbacku schematu.

Komponenty release-please po tym numerze: jeden na usługę (`identity`, `news`, `notifications`, `gateway`, od `19` i `22` także `learning` i `cv`), `platform`, `web` i `infra`. `api` znika z `release-please-config.json`; `identity` startuje od wersji, na której skończyło się `api`, bo to ten sam kod po przeniesieniu. Zmiana w `*.Contracts` wydaje usługę, która kontrakt publikuje. Konsument nie musi się przebudować: zgodna zmiana kontraktu jest addytywna, a niezgodna to `.v2` i zmiana w kodzie konsumenta, czyli osobne wydanie.

### 12. Aktualizacja docs/CICD i reguły

Pliki w [docs/CICD](../CICD/README.md) opisują stan przed tym numerem i zostają prawdziwe do jego wdrożenia. Przy wdrożeniu tego numeru dostają aktualizację:

| Plik | Zmiana |
| --- | --- |
| [01-proxmox.md](../CICD/01-proxmox.md) | RAM VM produkcji 12 GB; druga VM `jjdevhub-build` z rejestrem i certyfikatem lokalnego CA |
| [03-github.md](../CICD/03-github.md) | wpis w „Historii zmian”: ruleset `main` wymaga `ci`, `web`, `pr-title` i `secrets` |
| [06-opentelemetry.md](../CICD/06-opentelemetry.md) | kod OTel w ServiceDefaults; ślady przez `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` |
| [07-prometheus.md](../CICD/07-prometheus.md) | job na usługę, cele `<zasób>:8080` |
| [08-jaeger.md](../CICD/08-jaeger.md) | nazwy usług z Aspire |
| [09-grafana.md](../CICD/09-grafana.md) | dashboard `jjdevhub-services` |
| [10-sonarqube.md](../CICD/10-sonarqube.md) | klucz projektu na usługę, `SONAR_TOKEN_SERVICES` w environment `sonar` |
| [11-branche-i-wydania.md](../CICD/11-branche-i-wydania.md) | komponent na usługę plus `platform`; ruleset `main` wymaga `ci` zamiast `api`; job `images` w `release.yml` |
| [12-sekrety.md](../CICD/12-sekrety.md) | plik SOPS na usługę, sekrety Compose dopisywane przez AppHost, `identity-signing.sops.pem` |
| [13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md) | atestacja po digeście w rejestrze zamiast pliku archiwum, `--signer-workflow` na `_dotnet-service.yml` |

[.cursor/rules/github-workflows.mdc](../../.cursor/rules/github-workflows.mdc) dostaje nową treść:

- jeden `ci.yml` bez `paths`, wymagane checki `ci` i `web`,
- joby `pull_request` tylko na `ubuntu-latest`,
- obraz na `jjdevhub-build` tylko w `release.yml`, deploy i Sonar na `jjdevhub`, tylko z `main`,
- obraz na produkcję tylko po digeście i po `gh attestation verify` z `--signer-workflow` na `_dotnet-service.yml`,
- sekrety serwera tylko z `infra/secrets/*.sops.*` przez `jjdevhub-secrets.service`.

### Co jest do czego

- `ci.yml` — zawsze startuje, więc zawsze raportuje `ci`. Wymagany check nie wisi.
- `changed-services.mjs` i `services.json` — jedno miejsce z wiedzą, która ścieżka należy do której usługi. Używa go CI i deploy.
- `_dotnet-service.yml` — jedna definicja „jak budujemy usługę .NET”. Poprawka trafia do wszystkich usług naraz.
- `ubuntu-latest` dla PR — niezaufany kod nie dotyka domowej sieci.
- runner `jjdevhub-build` — buduje obrazy wydań w kontenerze, który znika po jobie, z dala od pamięci produkcji.
- runner `jjdevhub` — ma dostęp do sekretów, robi deploy i Sonar, tylko z `main`.
- rejestr lokalny i digest — produkcja uruchamia przetestowany obraz, a obrazy nie wychodzą z sieci.
- atestacja i `--signer-workflow` — obraz zbudował nasz przepis z naszego repozytorium, a nie ktoś z dostępem do rejestru.
- komponent release-please na usługę — wersja i changelog na usługę, a wydanie buduje tylko to, co się zmieniło.
- obraz migracji (`efbundle`) — schemat zmieniany przed startem nowej wersji, raz.
- `images.env` i `images.history` — stan „co jest wdrożone” i lista poprzednich stanów. Podstawa rollbacku.
- job Prometheusa na usługę i dashboard `jjdevhub-services` — widać, która usługa leży i gdzie rośnie lag.
- `migrate-from-single-api.sh` — jedyne miejsce, które zna stary układ. Po przejściu można go usunąć.

## Testy

Projektu .NET w tym numerze nie ma. Sprawdzenia:

| Sprawdzenie | Gdzie | Wynik |
| --- | --- | --- |
| `node --test infra/ci/changed-services.test.mjs` | job `changes` | zmiana tylko w `src/services/News/**` daje `["news"]`; zmiana w `src/building-blocks/**` daje wszystkie; zmiana w `Identity.Contracts` daje `identity`, `notifications`; brak zmian .NET daje `[]` |
| `node --test infra/ci/deploy-gate.test.mjs` | job `gate` w `release.yml` | wymaga `ci` i `web` dla SHA wydania; brakujący przebieg zostaje uruchomiony |
| `actionlint` | job `lint` | kod 0 |
| `shellcheck infra/ci/*.sh` | job `lint` | kod 0 |
| porty w wygenerowanym Compose | po `aspire publish` | każdy `ports:` zaczyna się od `127.0.0.1:` |
| PR zmieniający tylko `src/services/News/**` | GitHub | `service (news)` na `ubuntu-latest`, check `ci` zielony, brak jobów self-hosted |
| PR zmieniający tylko `README.md` | GitHub | `service` pominięty, check `ci` zielony |
| push na `main` bez Release PR | GitHub | `ci` zielony, brak obrazu i deployu |
| scalenie Release PR z `news-v…` | GitHub + VM | obraz `news-api` z `jjdevhub-build`, atestacja w zakładce Attestations, `deploy` zielony, `images.env` z nowym digestem tylko dla `news-api` |
| obraz wypchnięty do rejestru ręcznie pod tym samym tagiem | VM | `gh attestation verify` pada, deploy się nie zaczyna |
| Prometheus po deployu | `127.0.0.1:9090/api/v1/targets` | cel `up` dla każdej usługi z `services.json` |
| Jaeger po `POST /api/articles` | `127.0.0.1:16686` | ślad `gateway` → `news-api` → `publish news.integration` → `notifications-worker` |
| smoke z celowo zepsutym `/health` | ręczny `workflow_dispatch` z gałęzi testowej | rollback do poprzednich digestów |

## Zasady

- Joby `pull_request` nie działają na self-hosted runnerach.
- Build i testy `main` nie działają na runnerze produkcji. Deploy nie działa na runnerze build.
- Wymagany check .NET jest jeden: `ci`. Workflow z `paths` nie może być wymagany.
- Obraz na produkcję jest wskazany digestem i ma sprawdzoną atestację. Serwer nie buduje obrazów.
- Obraz powstaje tylko przy wydaniu. Merge na `main` nie wdraża.
- Migracje to osobny krok przed `up` i są wstecznie zgodne.
- Na hoście porty są tylko na `127.0.0.1`. Z usług port ma tylko gateway.
- Sekrety są w `infra/secrets/*.sops.*` i trafiają do kontenerów jako pliki. Workflow nie ma sekretów produkcji.
- Zmiana w `src/building-blocks/**` buduje wszystkie usługi, w CI i w wydaniu (`platform`).

## Poza zakresem

- Kubernetes, Argo CD, GitOps.
- Środowisko staging. Smoke i rollback na produkcji wystarczają przy jednym użytkowniku.
- Backend logów (Loki, OpenSearch) i Alertmanager.
- Wydawanie paczek NuGet bibliotek budulcowych.
- Przeniesienie SonarQube na osobną VM. Przy 10 GB na VM produkcji to pierwsza rzecz do rozważenia.

## Źródła

- [Reusing workflows](https://docs.github.com/en/actions/sharing-automations/reusing-workflows) — `workflow_call`, macierz z reużywalnym workflow.
- [Troubleshooting required status checks](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks) — dlaczego pominięty workflow blokuje PR.
- [Self-hosted runners: security](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#self-hosted-runner-security) — dlaczego PR nie trafia na runner domowy.
- [Ephemeral runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/autoscaling-with-self-hosted-runners#using-ephemeral-runners-for-autoscaling) — `--ephemeral`, jeden job na runner.
- [actions/runner — obraz kontenera](https://github.com/actions/runner/pkgs/container/actions-runner) — oficjalna baza runnera.
- [Containerize a .NET app with dotnet publish](https://learn.microsoft.com/en-us/dotnet/core/containers/sdk-publish) — `PublishContainer` bez Dockerfile.
- [EF Core migration bundles](https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/applying#bundles) — `efbundle` jako osobny krok wdrożenia.
- [Using environments for deployment](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment) — `production` i reguły ochrony.
- [Distribution registry](https://distribution.github.io/distribution/) — `registry:2` w sieci lokalnej.
- [Prometheus configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/) — `scrape_configs` na usługę.
- [Kafka: memory](https://kafka.apache.org/documentation/#java) — `KAFKA_HEAP_OPTS` i rozmiar sterty brokera.
- [actionlint](https://github.com/rhysd/actionlint) — statyczna kontrola workflowów.
- [Using artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds) — `attest-build-provenance`, `gh attestation verify`, reużywalny workflow jako podpisujący.
- [release-please: manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) — komponent na ścieżkę w monorepo.

## Gotowe gdy

- PR dotykający tylko News uruchamia `service (news)` na `ubuntu-latest`, a check `ci` jest zielony bez jobów self-hosted.
- Zmiana w `src/building-blocks/**` buduje wszystkie usługi.
- Push na `main` testuje, ale nie buduje obrazów. Scalenie Release PR buduje obrazy wydanych usług na `jjdevhub-build`, a deploy sprawdza ich atestacje, podnosi je po digeście po udanych migracjach i zapisuje `images.env`.
- Obraz bez atestacji z `_dotnet-service.yml` nie przechodzi weryfikacji i deploy się nie zaczyna.
- Kontenery dostają sekrety jako pliki w `/run/secrets/`, a `docker inspect` nie pokazuje haseł w `Env`.
- Na VM nginx kieruje `/api/` na gateway, a Prometheus pokazuje cel `up` dla każdej usługi z `services.json`.
- W Jaegerze są ślady pod nazwami zasobów, bez śladów `/metrics` i `/health`.
- Nieudany smoke przywraca poprzednie digesty.
- `node --test infra/ci/changed-services.test.mjs`, `node --test infra/ci/deploy-gate.test.mjs`, `actionlint` i `shellcheck` kończą się kodem 0.
