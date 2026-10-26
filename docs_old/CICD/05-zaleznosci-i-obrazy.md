# 05 — Zależności i obrazy

## Po co

Zależności NuGet / npm oraz obrazy Dockera mają swoje CVE. Ten krok:

1. Każe Dependabotowi otwierać PR z bumpami.
2. Blokuje PR, które dokładają podatne paczki (dependency review).
3. Skanuje obrazy z obu Dockerfile’y Trivym (fail na CRITICAL/HIGH).
4. Odpalają audyt NuGet i `pnpm audit` w CI.
5. Doszczelnia [api.yml](../../.github/workflows/api.yml) i [web.yml](../../.github/workflows/web.yml): `permissions: contents: read` oraz `concurrency`.

Komendy skanów żyją w [infra/ci/](../../infra/ci/). Workflowy tylko je wołają. Deploy z [03-github.md](03-github.md) i CodeQL z [04-codeql.md](04-codeql.md) zostają osobno.

## Dlaczego ta technologia

### Dependabot zamiast ręcznych bumpów

Dependabot czyta manifest (`Directory.Packages.props`, `package.json`, workflowy, Dockerfile) i otwiera PR z nowszą wersją. Sam niczego nie wdraża. Ręczny bump przegrał: CVE w zależności przechodzącej wychodzi na blogu albo po incydencie. Renovate przegrał, bo Dependabot jest wbudowany w GitHuba i wystarcza do grup i harmonogramu. Koszt: otwarte PR trzeba przepuścić przez CI, inaczej bump scala się „na oko”.

### Dependency review i audyt menedżera

Na pull requeście dependency review czyta diff locka wobec bazy GitHub Advisory i kończy job czerwono, gdy PR wprowadza podatność High albo Critical. Dług już obecny na `main` nie zawsze blokuje — brama ma nie pogarszać stanu. `dotnet package list --vulnerable --include-transitive` i `pnpm audit --audit-level=high` patrzą na cały graf, nie tylko na diff. Sam audyt przegrał jako jedyna brama: bywa rozjazd z GitHub Advisory. Same review przegrało, bo nie widzi paczki, która jest podatna od dawna i nie zmienia się w tym PR. Koszt: false positive i brak wersji z poprawką; polityka na start to fail od High w górę, nie od Low.

### Trivy na obrazie, nie tylko na manifeście

Trivy skanuje obraz, który naprawdę wstaje w Compose: paczki systemu w warstwie bazowej i biblioteki znalezione w warstwach. Skan samego `package.json` przegrał, bo produkcja i tak jedzie na `nginx` albo `aspnet` z dziurą w systemie. `trivy fs` i skan IaC zostają poza tym numerem. Koszt: komendy żyją w [infra/ci/](../../infra/ci/), nie są wklejone cztery razy do YAML, a fail na CRITICAL/HIGH boli, dopóki vendor nie wyda poprawki (`--ignore-unfixed` jest świadomym kompromisem, nie domyślnym wyłączeniem).

## Co już jest w repo

- Stack i Compose: [01-proxmox.md](01-proxmox.md), [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml).
- Tunel (nie skanuje zależności): [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).
- CI: [03-github.md](03-github.md) — `api.yml` (restore, build, test, `docker build -f infra/docker/Dockerfile .`), `web.yml` (`pnpm` + `docker build -f src/Clients/web/Dockerfile src/Clients`), `deploy.yml`.
- CodeQL: [04-codeql.md](04-codeql.md).
- Centralne wersje NuGet: [Directory.Packages.props](../../Directory.Packages.props), frontend: [src/Clients/web/package.json](../../src/Clients/web/package.json) + `pnpm-lock.yaml`.
- Dockerfile API: [infra/docker/Dockerfile](../../infra/docker/Dockerfile). Dockerfile web: [src/Clients/web/Dockerfile](../../src/Clients/web/Dockerfile).
- Skrypty audytu i Trivy: [nuget-audit.sh](../../infra/ci/nuget-audit.sh), [pnpm-audit.sh](../../infra/ci/pnpm-audit.sh), [pnpm-audit-gate.mjs](../../infra/ci/pnpm-audit-gate.mjs), [trivy-api.sh](../../infra/ci/trivy-api.sh), [trivy-web.sh](../../infra/ci/trivy-web.sh). Obok zostaje [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) i cron.
- Dependabot: [.github/dependabot.yml](../../.github/dependabot.yml). Dependency review: [.github/workflows/dependency-review.yml](../../.github/workflows/dependency-review.yml).

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie |
| --- | --- |
| Dependabot | Bot GitHuba: PR z aktualizacją wersji zależności według ekosystemu (`nuget`, `npm`, `github-actions`, `docker`). |
| Dependency review | Action na PR: porównuje lock/manifest z bazą i failuje przy nowych podatnościach według progu. |
| Trivy | Skaner Aqua: OS packages + zależności w obrazie / filesystemie. Tu: fail CRITICAL i HIGH. |
| NuGet audit | `dotnet restore` / `dotnet package list --vulnerable` z infrastrukturą audytu NuGet. |
| pnpm audit | Audyt drzewa npm przez pnpm; `--audit-level=high` failuje od High w górę. |
| `permissions` | Najmniejsze uprawnienia GITHUB_TOKEN w workflow (`contents: read`). |
| `concurrency` | Jedna aktywna runda danego workflow na ref; anuluje starsze runy przy nowym pushu. |

## Kroki

### 1. Dependabot

Utwórz [`.github/dependabot.yml`](../../.github/dependabot.yml):

```yaml
version: 2
updates:
  - package-ecosystem: nuget
    directory: "/"
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 10

  - package-ecosystem: npm
    directory: "/src/Clients/web"
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 10

  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
      day: monday

  - package-ecosystem: docker
    directory: "/infra/docker"
    schedule:
      interval: weekly
      day: monday

  - package-ecosystem: docker
    directory: "/src/Clients/web"
    schedule:
      interval: weekly
      day: monday
```

`nuget` z `directory: "/"` widzi [Directory.Packages.props](../../Directory.Packages.props) i projekty w solution. `npm` celuje wyłącznie w klienta React (`src/Clients/web`), nie w inne foldery. Dwa wpisy `docker` odpowiadają dwóm Dockerfile’om (katalog, w którym leży plik `Dockerfile`).

Po merge: **Settings → Code security → Dependabot** — włącz **Dependabot version updates** (i alerts, jeśli chcesz osobne powiadomienia CVE). W ciągu harmonogramu pojawią się PR od `dependabot[bot]`.

### 2. Skrypty w `infra/ci/`

Wszystkie skrypty: `chmod +x`, shebang `bash`, `set -euo pipefail`. Root = katalog repo (skrypt sam `cd` do top-level gita).

#### `infra/ci/nuget-audit.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

export DOTNET_NOLOGO=1
dotnet restore JJDevHub.sln
dotnet package list --project JJDevHub.sln --vulnerable --include-transitive --format json \
  --source https://api.nuget.org/v3/index.json >/tmp/nuget-audit.json

# Nagłówek „has the following vulnerable packages” jest w raporcie tekstowym przy każdym
# severity, także Low i Moderate. Tu liczy się tylko pole JSON "severity".
if grep -Eq '"severity": "(Critical|High)"' /tmp/nuget-audit.json; then
  echo "nuget-audit: failing on Critical/High" >&2
  exit 1
fi

echo "nuget-audit: ok"
```

Low i Moderate zostają w `/tmp/nuget-audit.json` i nie kończą joba. Fail jest tylko przy `"severity": "Critical"` albo `"severity": "High"`. Stderr z `dotnet package list` nie mieszaj z tym plikiem — `grep` ma widzieć sam JSON. W SDK 11 rozwiązanie idzie przez `--project`, nie jako argument pozycyjny.

#### `infra/ci/pnpm-audit.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WEB_DIR="$REPO_ROOT/src/Clients/web"
cd "$WEB_DIR"

corepack enable
pnpm install --frozen-lockfile

node --test "$REPO_ROOT/infra/ci/pnpm-audit-gate.test.mjs"

audit_json="$(mktemp)"
trap 'rm -f "$audit_json"' EXIT

set +e
pnpm audit --audit-level=high --json >"$audit_json"
audit_status=$?
set -e

if [[ "$audit_status" -ne 0 && "$audit_status" -ne 1 ]]; then
  echo "pnpm-audit: pnpm audit exited ${audit_status}" >&2
  cat "$audit_json" >&2
  exit "$audit_status"
fi

node "$REPO_ROOT/infra/ci/pnpm-audit-gate.mjs" \
  --audit "$audit_json" \
  --exceptions "$WEB_DIR/pnpm-audit-exceptions.yaml" \
  --package-json "$WEB_DIR/package.json"
```

#### `infra/ci/trivy-api.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

IMAGE="${TRIVY_API_IMAGE:-jjdevhub-api:ci}"

docker build -f infra/docker/Dockerfile -t "$IMAGE" .
trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$IMAGE"
```

#### `infra/ci/trivy-web.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

IMAGE="${TRIVY_WEB_IMAGE:-jjdevhub-web:ci}"

docker build -f src/Clients/web/Dockerfile -t "$IMAGE" src/Clients
trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$IMAGE"
```

`--ignore-unfixed` pomija CVE bez dostępnej poprawki w upstreamie. Jeśli wolisz failować także na unfixed, usuń flagę — świadomie, bo job będzie częściej czerwony.

Skan API nie ma pliku wyjątków. HIGH i CRITICAL z poprawką w upstreamie kończą job.

[pnpm-audit-exceptions.yaml](../../src/Clients/web/pnpm-audit-exceptions.yaml) ma pustą listę `advisories`. High z `pnpm audit` kończy job; nie ma wyłączeń. `auditConfig.ignoreGhsas` w `package.json` nie ma daty i wycina advisory z raportu, zanim bramka je zobaczy — skrypt taki wpis odrzuca.

Lokalnie (opcjonalnie):

```bash
# Trivy: ta sama wersja co w workflow (v0.76.0), nie skrypt z gałęzi main.
# https://github.com/aquasecurity/trivy/releases/tag/v0.76.0
./infra/ci/nuget-audit.sh
./infra/ci/pnpm-audit.sh
./infra/ci/trivy-api.sh
./infra/ci/trivy-web.sh
```

### 3. Dependency review — osobny workflow na PR

Utwórz [`.github/workflows/dependency-review.yml`](../../.github/workflows/dependency-review.yml):

```yaml
name: dependency-review

on:
  pull_request:

permissions:
  contents: read

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
```

Wymaga włączonego dependency graph / Dependabot w Settings. Działa na PR; na samym pushu do `main` nie zastępuje Trivy ani audytów.

### 4. Dopiski do `api.yml` i `web.yml`

Nie powielaj logiki skanów w YAML — wołaj skrypty. Zachowaj filtry `paths` na `push` do `main` i kroki build/test. Na `pull_request` filtrów nie ma: checki `api` i `web` mają powstać na każdym PR.

Docelowy kształt [api.yml](../../.github/workflows/api.yml) (pełny plik po zmianach):

```yaml
name: api

on:
  pull_request:
  push:
    branches: [main]
    paths:
      - "src/api/**"
      - "tests/JJDevHub.Api.Tests/**"
      - "nuget.config"
      - "Directory.Build.props"
      - "Directory.Packages.props"
      - "global.json"
      - "JJDevHub.sln"
      - "infra/docker/Dockerfile"
      - "infra/docker/docker-compose.yml"
      - "infra/ci/nuget-audit.sh"
      - "infra/ci/trivy-api.sh"
      - ".github/workflows/api.yml"
  workflow_dispatch:

concurrency:
  group: api-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  build:
    name: api
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: "11.0.x"
          dotnet-quality: preview

      - name: Restore
        run: dotnet restore JJDevHub.sln

      - name: NuGet audit
        run: ./infra/ci/nuget-audit.sh

      - name: Build
        run: dotnet build JJDevHub.sln --no-restore -c Release

      - name: Test
        run: dotnet test tests/JJDevHub.Api.Tests/JJDevHub.Api.Tests.csproj --no-build -c Release

      - name: Install Trivy
        env:
          TRIVY_VERSION: "0.76.0"
          TRIVY_SHA256: "e24b1c51293c1b15e4ba8d45bbc7891ba053f90278ec2698f3562c993e145fe7"
        run: |
          set -euo pipefail
          tarball="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
          curl -fsSL -o "/tmp/${tarball}" \
            "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${tarball}"
          echo "${TRIVY_SHA256}  /tmp/${tarball}" | sha256sum -c -
          sudo tar -xzf "/tmp/${tarball}" -C /usr/local/bin trivy
          trivy --version

      - name: Docker image + Trivy
        run: ./infra/ci/trivy-api.sh
```

Docelowy kształt [web.yml](../../.github/workflows/web.yml):

```yaml
name: web

on:
  pull_request:
  push:
    branches: [main]
    paths:
      - "src/Clients/web/**"
      - "src/Clients/.dockerignore"
      - "src/Clients/shared/theme/**"
      - "infra/docker/docker-compose.yml"
      - "infra/ci/pnpm-audit.sh"
      - "infra/ci/pnpm-audit-gate.mjs"
      - "infra/ci/pnpm-audit-gate.test.mjs"
      - "infra/ci/trivy-web.sh"
      - ".github/workflows/web.yml"
  workflow_dispatch:

concurrency:
  group: web-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
  build:
    name: web
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: src/Clients/web
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          package_json_file: src/Clients/web/package.json

      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: pnpm
          cache-dependency-path: src/Clients/web/pnpm-lock.yaml

      - name: Install
        run: pnpm install --frozen-lockfile

      - name: pnpm audit
        working-directory: .
        run: ./infra/ci/pnpm-audit.sh

      - name: Test
        run: pnpm test:ci

      - name: Build
        run: pnpm build

      - name: Install Trivy
        working-directory: .
        env:
          TRIVY_VERSION: "0.76.0"
          TRIVY_SHA256: "e24b1c51293c1b15e4ba8d45bbc7891ba053f90278ec2698f3562c993e145fe7"
        run: |
          set -euo pipefail
          tarball="trivy_${TRIVY_VERSION}_Linux-64bit.tar.gz"
          curl -fsSL -o "/tmp/${tarball}" \
            "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/${tarball}"
          echo "${TRIVY_SHA256}  /tmp/${tarball}" | sha256sum -c -
          sudo tar -xzf "/tmp/${tarball}" -C /usr/local/bin trivy
          trivy --version

      - name: Docker image + Trivy
        working-directory: .
        run: ./infra/ci/trivy-web.sh
```

Uwagi:

- Stary krok samego `docker build` w `api` / `web` zastępuje skrypt Trivy (on i tak buduje obraz).
- `pnpm-audit.sh` sam robi `pnpm install` w `src/Clients/web` — podwójny install jest OK; jeśli chcesz przyspieszyć, wydziel w skrypcie sam `pnpm audit` i polegaj na kroku Install (wtedy skrypt nie wolaj `install` drugi raz — wybierz jedną konwencję i trzymaj ją).
- `deploy.yml` **nie** dostaje Trivy ani `permissions` poza tym, co już ma; nie ruszaj self-hosted joba w tym numerze.
- Instalacja Trivy to wydanie `v0.76.0` i SHA256 wpisany w YAML. Nie wracaj do `curl | sh` ze skryptu na gałęzi `main`. Przy bumpie wersji podmień oba pola i hash z `trivy_<wersja>_checksums.txt` dla `Linux-64bit.tar.gz`.

### 5. Branch protection (po pierwszym zielonym runie)

W regule `main` możesz dodać check `dependency-review` obok `api` i `web`. Nie wymagaj checków, które jeszcze nigdy nie przeszły — dopisz je po pierwszym sukcesie (jak w [03-github.md](03-github.md)).

## Jak sprawdzić, że działa

1. PR zmieniający tylko markdown nie musi odpalać `api`/`web` (path filters). PR z bumpem w `Directory.Packages.props` → `api` z krokiem NuGet audit; PR w `package.json` → `web` z pnpm audit.
2. **Actions**: zielone `api` i `web` z logami `nuget-audit: ok` / `pnpm audit` exit 0 oraz Trivy bez CRITICAL/HIGH.
3. Otwórz testowy PR z celowo starą, znaną podatną wersją (na throwaway branch) → dependency review albo audit/Trivy czerwone → zamknij bez merge.
4. Po tygodniu (albo ręcznym **Dependabot → Check for updates**): PR od bota dla nuget/npm/actions/docker.
5. `permissions: contents: read` widać w YAML; przy `GITHUB_TOKEN` job nie powinien móc pushować do repo.

## Czego w tym pliku nie ruszać

- Logiki [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) i [deploy.yml](../../.github/workflows/deploy.yml) (poza tym, że path filters w `api`/`web` mogą zawierać nowe skrypty — deploy zostaje jak jest).
- Tunelu Cloudflare, bindów portów Compose (to 01 / 07).
- CodeQL ([04-codeql.md](04-codeql.md)) — osobny workflow / default setup.
- OpenTelemetry i Prometheus (06–07).
- Nie wrzucaj pełnych komend `trivy` / `pnpm audit` inline do YAML poza instalacją Trivy i wywołaniem `./infra/ci/…`.

## Następny numer

[06-opentelemetry.md](06-opentelemetry.md) — instrumentacja `JJDevHub.Api`, eksport OTLP gRPC przez zmienną środowiskową.

---

## Pełny tutorial: zależności, audyty i skan obrazów (od zera)

Wybór Dependabota, dependency review, audytu i Trivy jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają uprawnienia tokenu, przebieg w zespole i typowe pomyłki.

### `permissions` i `concurrency` w Actions

Domyślny `GITHUB_TOKEN` bywał szeroki. Jawne:

```yaml
permissions:
  contents: read
```

ogranicza token do odczytu treści repo — wystarczy do checkout + build. Job, który uploaduje SARIF, dokłada `security-events: write`. Deploy na self-hosted i tak nie potrzebuje write do contents, jeśli nie pushuje gałęzi (w JJDevHub push release jest wyłączony domyślnie).

```yaml
concurrency:
  group: api-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Przy serii pushy na ten sam branch anuluje poprzedni run — oszczędza minuty i unikasz race „starszy build nadpisuje status nowszego” w UI.

### Typowy przebieg w zespole

1. Dependabot otwiera PR „bump Npgsql…”.
2. Odpalają się `api`, dependency-review, ewentualnie CodeQL.
3. Zielone → review → merge.
4. `deploy.yml` (po sukcesie CI na `main`) przebudowuje Compose na VM.
5. Gdy Trivy złapie CVE w `aspnet` base — PR podbija tag obrazu bazowego w Dockerfile, nie „wyłącza skaner”.

### Typowe pomyłki

1. **Skan tylko `package.json`, bez obrazu** — produkcja i tak leci na nginx/dotnet base z dziurą OS.
2. **Trivy w YAML skopiowany 4 razy** — dryf flag; trzymaj skrypt w `infra/ci/`.
3. **Dependabot bez CI na PR** — merge bumpa „na oko”.
4. **`permissions: write-all` „na wszelki wypadek”** — zbędne ryzyko przy skradzionym workflow.
5. **Ignorowanie transitive** — `dotnet package list … --include-transitive` i lockfile istnieją po to.
6. **Jeden ekosystem `npm` na root monorepo**, gdy frontend siedzi w podkatalogu — bot nic nie znajdzie; `directory` musi wskazać `src/Clients/web`.
7. **Fail na Low w pierwszym tygodniu** — zespół wyłącza cały skaner; zacznij od High/Critical.
8. **Mylenie dependency review z CodeQL** — review = zależności; CodeQL = wzorce w Twoim kodzie.

### Oficjalne źródła

- GitHub Docs: Dependabot, dependency review action, GITHUB_TOKEN permissions, concurrency.
- NuGet: auditing packages / `dotnet package list --vulnerable`.
- pnpm: `pnpm audit`.
- Aqua Trivy: dokumentacja `trivy image`, severity, ignore file.
