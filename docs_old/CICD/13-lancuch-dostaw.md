# Łańcuch dostaw — akcje po SHA, zizmor, Scorecard, SBOM i atestacje obrazów

## Po co

Dziś workflowy wskazują akcje tagiem (`actions/checkout@v7`, `pnpm/action-setup@v6`). Tag to przesuwalny wskaźnik. W marcu 2025 ktoś przejął `tj-actions/changed-files` (CVE-2025-30066) i przestawił wszystkie jego tagi na commit, który wypisywał sekrety z pamięci runnera do logów. Każde repo z `@v45` uruchomiło ten kod przy najbliższym przebiegu, bez żadnej zmiany po swojej stronie.

Obrazy produkcji powstają na VM: `compose up --build` uruchamia `dotnet restore`, `pnpm install` i `pnpm build` na maszynie, która serwuje stronę i odszyfrowuje sekrety. Trivy w [api.yml](../../.github/workflows/api.yml) skanuje inny build tego samego kodu: z innej chwili, z bazowym obrazem ściągniętym w innym momencie. Nie da się wykazać, z którego commita i jakim przepisem powstał kontener, który właśnie działa, ani co jest w środku.

Po tym kroku:

- Każde `uses:` wskazuje 40-znakowy SHA commita z komentarzem wersji. GitHub odrzuca workflow z akcją wskazaną tagiem, a lista dozwolonych akcji jest zamknięta. Dependabot podbija SHA razem z komentarzem, z kilkudniową karencją.
- [zizmor](https://docs.zizmor.sh/) sprawdza workflowy na każdym PR (wymagany check `zizmor`), a wyniki trafiają do **Security → Code scanning**.
- [OpenSSF Scorecard](https://scorecard.dev/) co tydzień ocenia praktyki repo. Wynik jest publiczny, odznaka stoi w README.
- Obrazy `api` i `web` buduje raz `release.yml` na runnerze GitHuba. Trivy skanuje dokładnie ten obraz i zapisuje SBOM w formacie CycloneDX. GitHub podpisuje (Sigstore) provenance SLSA i SBOM dla archiwum obrazu. VM sprawdza obie atestacje, łącznie z commitem wydania, zanim zrobi `docker load`. VM niczego nie buduje.
- Obrazy bazowe w Dockerfile'ach i w Compose są przypięte digestem. NuGet ma pliki lock i mapowanie źródeł, pnpm karencję nowych wersji i `trustPolicy`.
- Raz w tygodniu Trivy skanuje SBOM ostatniego wydania, czyli to, co działa, a nie to, co leży w repo.

Żadnego nowego sekretu: podpis bierze tożsamość z tokenu OIDC joba, a weryfikacja na VM używa tokenu joba deployu.

## Dlaczego ta technologia

### SHA commita zamiast tagu akcji

Tag `v7` w repozytorium akcji jest wskaźnikiem, który właściciel albo przejęty token przestawia jedną komendą. SHA commita jest hashem treści: inny kod to inny SHA. W marcu 2025 przestawione tagi `tj-actions/changed-files` uruchomiły obcy kod w każdym repo, które wskazywało `@v45`, bez zmiany po stronie tego repo. Samo przypięcie bez aktualizacji przegrało, bo zamraża podatność. Dependabot z karencją podbija SHA i komentarz wersji, ale nie w dniu publikacji. Koszt: GitHub pokazuje commit z forka pod adresem repozytorium nadrzędnego, więc SHA musi być osiągalny z gałęzi albo tagu oficjalnej akcji. To sprawdza audyt `impostor-commit` w zizmorze.

### Atestacja Sigstore zamiast klucza na VM

GitHub podpisuje provenance SLSA i SBOM tokenem OIDC joba (Fulcio, Rekor). Nie ma klucza prywatnego do rotacji: certyfikat żyje minuty i mówi, który workflow i który commit podpisał plik. VM sprawdza pola certyfikatu (`--repo`, `--signer-workflow`, `--source-ref`, `--source-digest`) zanim zrobi `docker load`. Własne PKI i Notary przegrały: dokładają klucz albo KMS, którego ten numer nie chce. cosign bezpośrednio przegrał do czasu rejestru obrazów: atestacja GitHuba jest tym samym Sigstore, a weryfikacja jest jedną komendą `gh`. Budowa obrazu na VM przegrała, bo maszyna z sekretami nie jest miejscem na `dotnet restore` i `pnpm install`, a Trivy skanowałby inny build niż ten, który działa. Koszt: poziom SLSA L2 (podpis hostowanej platformy), nie L3. L3, czyli przepis builda odizolowany od kroków z repo, jest kierunkiem [docs/api/18-ci-uslug.md](../api/18-ci-uslug.md).

### CycloneDX i Scorecard

SBOM w CycloneDX opisuje, co jest w obrazie, pod kątem podatności. SPDX przegrał w tym numerze: jest mocniejszy przy licencjach, a Trivy i `attest-sbom` i tak mówią CycloneDX natywnie. Syft z Grype przegrały, bo Trivy już skanuje obraz i umie zapisać ten format. OpenSSF Scorecard raz w tygodniu czyta praktyki repo (uprawnienia workflowów, przypięcia, ochronę gałęzi) i wystawia średnią. To nie jest certyfikat: wysoki wynik nie znaczy, że kod jest bezpieczny. Koszt: publiczny wynik i odznaka, oraz świadomość, że niski wynik Code-Review w projekcie jednej osoby opisuje stan, a nie ukrywa lukę.

## Co już jest w repo

- Workflowy z akcjami po tagu: [api.yml](../../.github/workflows/api.yml), [web.yml](../../.github/workflows/web.yml), [dependency-review.yml](../../.github/workflows/dependency-review.yml), a po [11-branche-i-wydania.md](11-branche-i-wydania.md) i [12-sekrety.md](12-sekrety.md) także `pr-title.yml`, `release.yml`, `deploy.yml` i `secrets.yml`.
- Trivy instalowany w `api.yml` i `web.yml` z wydania na GitHubie ze sprawdzeniem `sha256sum -c`. [trivy-api.sh](../../infra/ci/trivy-api.sh) i [trivy-web.sh](../../infra/ci/trivy-web.sh) budują obraz i skanują go (`CRITICAL,HIGH`, `--ignore-unfixed`).
- `release.yml` z 11: `release-please`, `gate`, `deploy` na `[self-hosted, jjdevhub]`. [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) z 11 i 12 robi `compose up --build`.
- [docker-compose.yml](../../infra/docker/docker-compose.yml): `build:` dla `api` i `web`, obrazy `postgres`, `prometheus`, `jaeger`, `grafana` po tagu. `docker-compose.prod.yml` z 12.
- [infra/docker/Dockerfile](../../infra/docker/Dockerfile) i [src/Clients/web/Dockerfile](../../src/Clients/web/Dockerfile): `FROM` po tagu.
- [dependabot.yml](../../.github/dependabot.yml) z `commit-message` i grupami z 11.
- [nuget.config](../../nuget.config): `<clear />` i jedno źródło `nuget.org`. [package.json](../../src/Clients/web/package.json) weba: `packageManager: pnpm@10.33.0`, `pnpm.onlyBuiltDependencies`.
- CodeQL w default setup ([04-codeql.md](04-codeql.md)), Immutable Releases (11), push protection (12).
- [jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron): co godzinę najnowszy tag wydania.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie tu |
| --- | --- |
| łańcuch dostaw (supply chain) | Wszystko, co wpływa na artefakt między kodem a produkcją: zależności, akcje CI, obrazy bazowe, runner, rejestr, deploy. |
| przypięcie po SHA | `uses: owner/repo@<40 znaków hex> # v7.0.1`. Commit gita jest niezmienny, tag nie. |
| zizmor | Statyczny audyt workflowów GitHub Actions: wstrzyknięcia w `run:`, nadmiarowe uprawnienia, nieprzypięte akcje, wyciek tokenu z checkoutu, zatruwanie cache. |
| SARIF | Format wyników analizy statycznej. Code scanning GitHuba przyjmuje go od dowolnego narzędzia. |
| OpenSSF Scorecard | Automatyczna ocena praktyk bezpieczeństwa repozytorium (0–10 na kilkanaście kontroli). |
| SBOM | Software Bill of Materials: lista komponentów artefaktu z wersjami, licencjami i identyfikatorami (purl). |
| CycloneDX | Standard SBOM (OWASP, ECMA-424). Drugi popularny to SPDX (ISO/IEC 5962). |
| provenance | Opis, jak powstał artefakt: repozytorium, commit, workflow, runner, parametry. Tu w formacie SLSA v1. |
| SLSA | Supply-chain Levels for Software Artifacts. Poziomy Build L1–L3 mówią, jak trudno sfałszować provenance. |
| atestacja | Podpisane twierdzenie in-toto: *ten* plik (digest) ma *taką* właściwość (provenance, SBOM). |
| Sigstore | Infrastruktura podpisów bez długowiecznych kluczy: Fulcio wystawia krótki certyfikat na tożsamość OIDC, Rekor zapisuje podpis w publicznym rejestrze przejrzystości. |
| tożsamość podpisującego | Workflow, który podpisał atestację (`.github/workflows/release.yml`), z repozytorium, refem i commitem w certyfikacie. |
| karencja (cooldown) | Liczba dni od publikacji wersji, zanim narzędzie ją zaproponuje. Złośliwe wydania zwykle znikają z rejestru w ciągu godzin albo dni. |
| digest | `sha256:…` treści obrazu. Tag `16-alpine` się zmienia, digest nie. |

## Kroki

W przykładach `<sha>` zastępuje 40-znakowy SHA commita akcji. Wpisuje go narzędzie z kroku 1, a nie człowiek.

### 1. Akcje przypięte po SHA

Na laptopie, w korzeniu repo:

```bash
pinact run
git diff --stat .github/workflows
```

[pinact](https://github.com/suzuki-shunsuke/pinact) (MIT) zamienia każde `uses: actions/checkout@v7` na `uses: actions/checkout@<sha> # v7.0.1`: rozwiązuje tag do commita i pełnej wersji. Wynik idzie jednym PR `ci: pin actions to commit SHAs`.

Repo dostaje dwa ustawienia Actions. `apply-rulesets.sh` z [11-branche-i-wydania.md](11-branche-i-wydania.md):

```bash
gh api -X PUT "repos/$repo/actions/permissions" \
  -F enabled=true -f allowed_actions=selected -F sha_pinning_required=true >/dev/null

gh api -X PUT "repos/$repo/actions/permissions/selected-actions" \
  --input - >/dev/null <<'JSON'
{
  "github_owned_allowed": true,
  "verified_allowed": false,
  "patterns_allowed": [
    "googleapis/release-please-action@*",
    "pnpm/action-setup@*",
    "ossf/scorecard-action@*",
    "zizmorcore/zizmor-action@*"
  ]
}
JSON
```

- `sha_pinning_required` — workflow z `@v7` albo `@main` kończy się błędem przed pierwszym krokiem. Lokalne workflowy reużywalne (`./.github/workflows/…`) nie potrzebują SHA.
- `github_owned_allowed` wpuszcza `actions/*` i `github/*` (`codeql-action`). Pozostałe akcje są wymienione z nazwy. `verified_allowed: false`, bo znaczek „verified creator” mówi, kim jest wydawca, a nie że ta akcja jest potrzebna.
- Nowa akcja z zewnątrz to zmiana listy w skrypcie, czyli PR z uzasadnieniem.

`.github/zizmor.yml`:

```yaml
rules:
  unpinned-uses:
    config:
      policies:
        "*": hash-pin
```

Domyślna polityka zizmora pozwala na tag dla `actions/*`. Ta wymaga SHA wszędzie, tak samo jak ustawienie repo.

### 2. Zasady pisania workflowów

Te zasady obowiązują w każdym pliku w `.github/workflows/`. zizmor z kroku 3 pilnuje większości z nich:

| Zasada | Po co | Audyt zizmora |
| --- | --- | --- |
| `permissions: {}` na poziomie workflowu, minimum w każdym jobie | token joba ma tylko to, czego job używa | `excessive-permissions` |
| `persist-credentials: false` w każdym `actions/checkout` | token nie zostaje w `.git/config`, skąd mógłby trafić do artefaktu albo kroku z kodem PR | `artipacked` |
| `${{ … }}` z danych zdarzenia tylko przez `env:` | tytuł PR albo nazwa gałęzi nie staje się kodem powłoki | `template-injection` |
| bez `pull_request_target` i bez `workflow_run` z checkoutem kodu PR | kod z forka nie dostaje tokenu z zapisem | `dangerous-triggers` |
| job wydania bez cache Actions | cache zapisany przez inny przebieg nie trafia do obrazu wydania | `cache-poisoning` |
| sekrety tylko przez `env:` i environment | wartość nie stoi w linii komend procesu na runnerze | `secrets-outside-env` |

Pierwszy przebieg zizmora na obecnych plikach pokaże `artipacked` przy każdym checkoucie w `api.yml`, `web.yml` i `dependency-review.yml`. Poprawką jest `persist-credentials: false`. Job `sonar` w obu workflowach wkleja `${{ secrets.SONAR_TOKEN_* }}` w `run:`; wartość przechodzi do `env:` (`SONAR_TOKEN`), a komenda używa `$SONAR_TOKEN`.

### 3. zizmor jako wymagany check

`.github/workflows/zizmor.yml`:

```yaml
name: zizmor

on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:

permissions: {}

jobs:
  zizmor:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          persist-credentials: false

      - name: Upload findings to code scanning
        uses: zizmorcore/zizmor-action@<sha> # v0.6.4
        with:
          config: .github/zizmor.yml

      - name: Fail on medium and above
        uses: zizmorcore/zizmor-action@<sha> # v0.6.4
        with:
          config: .github/zizmor.yml
          advanced-security: false
          min-severity: medium
```

- Pierwszy krok wysyła SARIF do code scanning i nigdy nie kończy się błędem z powodu znalezisk: w trybie SARIF zizmor zwraca kod 0, bo wynik niesie sam plik. Daje historię alertów i triage w zakładce Security.
- Drugi krok wypisuje wyniki w logu i kończy job kodem 13 (najwyższe znalezisko `medium`) albo 14 (`high`). Znaleziska poniżej progu są odfiltrowane. To on robi z `zizmor` bramkę.
- Token joba włącza audyty online: `impostor-commit` (SHA, który istnieje tylko w forku akcji, a nie w jej repo), `ref-confusion`, `known-vulnerable-actions`.
- zizmor czyta też `.github/dependabot.yml` i zgłasza ekosystem bez `cooldown` (krok 5).
- Wersja zizmora jest przypięta w akcji: `<sha>` akcji wyznacza wersję, którą akcja instaluje z PyPI.

`zizmor` dochodzi do wymaganych checków w `.github/rulesets/main.json`:

```json
"required_status_checks": [
  { "context": "api", "integration_id": 15368 },
  { "context": "web", "integration_id": 15368 },
  { "context": "pr-title", "integration_id": 15368 },
  { "context": "secrets", "integration_id": 15368 },
  { "context": "zizmor", "integration_id": 15368 }
]
```

Krok „Run required checks on the release PR” w `release.yml` dostaje linię `gh workflow run zizmor.yml --repo "$REPO" --ref "$BRANCH"`. Bez niej Release PR czeka na `zizmor` w nieskończoność, z tego samego powodu co przy `secrets` w 12.

Zamiast wymaganego checka można by użyć reguły `code_scanning` w rulesecie (blokada scalenia przy nowym alercie). Reguła patrzy na analizę zdarzenia `pull_request`, której Release PR nie ma, więc tu nie pasuje.

### 4. OpenSSF Scorecard

`.github/workflows/scorecard.yml`:

```yaml
name: scorecard

on:
  push:
    branches: [main]
  schedule:
    - cron: "17 4 * * 1"
  workflow_dispatch:

permissions: {}

jobs:
  scorecard:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
      security-events: write
      id-token: write
    steps:
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          persist-credentials: false

      - uses: ossf/scorecard-action@<sha> # v2.4.3
        with:
          results_file: scorecard.sarif
          results_format: sarif
          publish_results: true

      - uses: github/codeql-action/upload-sarif@<sha> # v4.31.0
        with:
          sarif_file: scorecard.sarif
          category: scorecard
```

`publish_results: true` wysyła wynik do publicznego API Scorecard, podpisany tokenem OIDC joba (`id-token: write`). Scorecard przyjmuje go tylko od joba, który nie ma kroków `run:`, nie ustawia `env` ani `defaults` na poziomie workflowu i używa wyłącznie akcji z jego listy (checkout, upload-artifact, upload-sarif, harden-runner, scorecard-action). Ten job spełnia te warunki i nie dostaje nic więcej.

Odznaka w [README.md](../../README.md), pod tytułem, przed częścią angielską:

```markdown
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/jtjaskulski/JJDevHub/badge)](https://scorecard.dev/viewer/?uri=github.com/jtjaskulski/JJDevHub)
```

Wynik nie musi być 10. Kilka kontroli mierzy rzeczy, których projekt jednej osoby nie ma i nie udaje:

| Kontrola | Oczekiwany wynik | Powód |
| --- | --- | --- |
| Pinned-Dependencies | wysoki | akcje po SHA, `FROM` po digeście; pojedyncze uwagi za `npm install -g pnpm@…` w Dockerfile weba |
| Token-Permissions, Dangerous-Workflow | 10 | `permissions: {}`, brak `pull_request_target` |
| SAST | 10 | CodeQL na każdym PR |
| Dependency-Update-Tool, Security-Policy, License | 10 | Dependabot, [SECURITY.md](../../SECURITY.md), [LICENSE](../../LICENSE) |
| Branch-Protection | średni | ruleset bez wymaganej recenzji (jeden autor) |
| Code-Review | niski | PR bez zatwierdzenia drugiej osoby |
| Signed-Releases | niski | GitHub Release od release-please nie ma plików z podpisem; atestacje obrazów leżą w API atestacji, nie w plikach wydania |
| Fuzzing | 0 | brak fuzzingu |
| CII-Best-Practices | 0 | do czasu wypełnienia kwestionariusza na [bestpractices.dev](https://www.bestpractices.dev/) |

Liczy się kierunek: spadek kontroli, która była na 10, to sygnał do sprawdzenia ostatnich zmian w workflowach.

### 5. Zależności: karencja, pliki lock, digesty

**Dependabot.** Każdy ekosystem w [dependabot.yml](../../.github/dependabot.yml) dostaje `cooldown`, akcje dostają grupę, a obrazy z Compose własny ekosystem:

```yaml
  - package-ecosystem: nuget
    # … schedule, commit-message i groups z 11
    cooldown:
      default-days: 7
      semver-major-days: 14

  - package-ecosystem: github-actions
    directory: "/"
    schedule:
      interval: weekly
      day: monday
    commit-message:
      prefix: ci
      include: scope
    cooldown:
      default-days: 7
    groups:
      actions:
        patterns: ["*"]

  - package-ecosystem: docker-compose
    directory: "/infra/docker"
    schedule:
      interval: weekly
      day: monday
    commit-message:
      prefix: fix
      include: scope
    cooldown:
      default-days: 7
```

`npm` dostaje ten sam `cooldown` co `nuget`, oba `docker` — `default-days: 7`. Karencja dotyczy aktualizacji wersji, nie aktualizacji bezpieczeństwa: poprawka CVE przychodzi od razu. Dependabot przy akcjach przypiętych po SHA podbija SHA i komentarz `# v7.0.2` razem.

**NuGet.** W [Directory.Build.props](../../Directory.Build.props):

```xml
<PropertyGroup>
  <RestorePackagesWithLockFile>true</RestorePackagesWithLockFile>
  <RestoreLockedMode Condition="'$(CI)' == 'true'">true</RestoreLockedMode>
</PropertyGroup>
```

Każdy projekt dostaje `packages.lock.json` z wersją i hashem każdej paczki, także przechodniej. W CI (`CI=true` ustawia GitHub) restore kończy się błędem, gdy lock nie zgadza się z projektem, zamiast po cichu rozwiązać nowszą wersję. [infra/docker/Dockerfile](../../infra/docker/Dockerfile) dostaje `--locked-mode` w `dotnet restore`. Dependabot aktualizuje pliki lock razem z `Directory.Packages.props`.

W [nuget.config](../../nuget.config), pod `packageSources`:

```xml
<packageSourceMapping>
  <packageSource key="nuget.org">
    <package pattern="*" />
  </packageSource>
</packageSourceMapping>
```

Przy jednym źródle mapowanie niczego dziś nie zmienia. Pilnuje przyszłości: drugie źródło (prywatny feed) dostanie tylko paczki z jawnym wzorcem, więc paczka o tej samej nazwie na nuget.org nie podmieni wewnętrznej (dependency confusion).

**pnpm.** `src/Clients/web/pnpm-workspace.yaml`:

```yaml
minimumReleaseAge: 4320
trustPolicy: no-downgrade
```

- `minimumReleaseAge` (minuty, tu 3 dni) — `pnpm add` i `pnpm update` nie wybiorą wersji młodszej niż trzy dni. Robaki npm z 2025 roku (np. Shai-Hulud) publikowały zainfekowane wersje znanych paczek, które rejestr usuwał w ciągu godzin.
- `trustPolicy: no-downgrade` — instalacja kończy się błędem, gdy nowa wersja paczki ma słabsze potwierdzenie pochodzenia niż poprzednie (np. wcześniejsze wydania miały provenance npm z CI, a nowe opublikowano ręcznie z laptopa). Tak wygląda typowe przejęcie konta opiekuna.
- Web Dockerfile kopiuje `web/pnpm-workspace.yaml` obok `package.json` i `pnpm-lock.yaml`.

**Obrazy bazowe.** Każdy `FROM` i każde `image:` z Compose dostaje digest obok tagu:

```bash
docker buildx imagetools inspect mcr.microsoft.com/dotnet/aspnet:11.0-preview | sed -n 's/^Digest: *//p'
```

```dockerfile
FROM mcr.microsoft.com/dotnet/aspnet:11.0-preview@sha256:<digest> AS runtime
```

```yaml
  db:
    image: postgres:16-alpine@sha256:<digest>
```

Tag zostaje dla czytelnika i dla Dependabota: ten przy każdej nowej wersji pod tagiem otwiera PR `fix(deps): bump postgres …` z nowym digestem. Bez digestu obraz bazowy zmieniał się między dwoma buildami tego samego commita i nikt tego nie widział w historii repo.

### 6. Jeden przepis na obraz

`infra/ci/install-trivy.sh` (nowy) przejmuje krok „Install Trivy” z `api.yml` i `web.yml`: `TRIVY_VERSION`, `TRIVY_SHA256`, `curl`, `sha256sum -c`, rozpakowanie. Wersja i suma są w jednym miejscu, a workflowy wołają skrypt.

`infra/ci/build-image.sh` (nowy):

```bash
#!/usr/bin/env bash
set -euo pipefail

name="$1"
sha="$2"
out="$3"

case "$name" in
  api) context=.; dockerfile=infra/docker/Dockerfile ;;
  web) context=src/Clients; dockerfile=src/Clients/web/Dockerfile ;;
  *) echo "unknown image: $name" >&2; exit 1 ;;
esac

image="jjdevhub/$name:${sha:0:12}"
mkdir -p "$out"

docker build --pull --no-cache \
  --label "org.opencontainers.image.revision=$sha" \
  --label "org.opencontainers.image.source=https://github.com/jtjaskulski/JJDevHub" \
  -f "$dockerfile" -t "$image" "$context"

trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$image"
trivy image --format cyclonedx --output "$out/$name.cdx.json" "$image"
if [[ "$name" == web ]]; then
  trivy fs --format cyclonedx --output "$out/web-bundle.cdx.json" src/Clients/web
fi

docker save "$image" -o "$out/$name.tar"
```

- `--pull --no-cache` — obraz wydania powstaje od zera, z bazowym obrazem spod digestu, bez warstw z wcześniejszych buildów.
- Etykieta `org.opencontainers.image.revision` pozwala na VM odczytać commit z `docker image inspect`.
- SBOM obrazu `api` obejmuje paczki systemowe i NuGet (Trivy czyta `*.deps.json`). Obraz `web` to nginx i statyczne pliki: paczki npm są wkompilowane w bundel i nie zostawiają w obrazie metadanych. Dlatego `web` ma drugi SBOM, z `pnpm-lock.yaml` bez zależności deweloperskich, czyli to, co Vite wkłada do bundla.

[trivy-api.sh](../../infra/ci/trivy-api.sh) i [trivy-web.sh](../../infra/ci/trivy-web.sh) wołają `build-image.sh api|web "$(git rev-parse HEAD)" "${RUNNER_TEMP:-/tmp}/image"`. PR testuje więc ten sam przepis, który zbuduje wydanie.

### 7. Budowa, SBOM i atestacje w `release.yml`

Nowy job między `gate` a `deploy`:

```yaml
  images:
    needs: gate
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
      id-token: write
      attestations: write
    strategy:
      fail-fast: true
      matrix:
        image: [api, web]
    steps:
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          persist-credentials: false

      - name: Install Trivy
        run: ./infra/ci/install-trivy.sh

      - name: Build, scan and export
        env:
          IMAGE: ${{ matrix.image }}
          RELEASE_SHA: ${{ needs.gate.outputs.sha }}
        run: ./infra/ci/build-image.sh "$IMAGE" "$RELEASE_SHA" "$RUNNER_TEMP/image"

      - uses: actions/attest-build-provenance@<sha> # v3.0.0
        with:
          subject-path: ${{ runner.temp }}/image/${{ matrix.image }}.tar

      - uses: actions/attest-sbom@<sha> # v3.0.0
        with:
          subject-path: ${{ runner.temp }}/image/${{ matrix.image }}.tar
          sbom-path: ${{ runner.temp }}/image/${{ matrix.image }}.cdx.json

      - if: matrix.image == 'web'
        uses: actions/attest-sbom@<sha> # v3.0.0
        with:
          subject-path: ${{ runner.temp }}/image/web.tar
          sbom-path: ${{ runner.temp }}/image/web-bundle.cdx.json

      - uses: actions/upload-artifact@<sha> # v5.0.0
        with:
          name: image-${{ matrix.image }}
          path: ${{ runner.temp }}/image/${{ matrix.image }}.tar
          retention-days: 90
          if-no-files-found: error

      - uses: actions/upload-artifact@<sha> # v5.0.0
        with:
          name: sbom-${{ matrix.image }}
          path: ${{ runner.temp }}/image/*.cdx.json
          retention-days: 90
          if-no-files-found: error
```

- Job biegnie na `ubuntu-latest`: świeża maszyna GitHuba na jeden job, bez stanu z poprzednich przebiegów i bez dostępu do sieci domowej.
- `id-token: write` daje token OIDC, na który Fulcio wystawia certyfikat z tożsamością workflowu. `attestations: write` zapisuje atestację w API atestacji repo. Repo jest publiczne, więc podpis trafia też do publicznego rejestru Rekor.
- `actions/attest-build-provenance` liczy SHA-256 archiwum i podpisuje provenance SLSA v1: repozytorium, commit, workflow, zdarzenie, runner. `actions/attest-sbom` podpisuje SBOM z tym samym digestem jako przedmiotem.
- Atestacje są widoczne w zakładce **Actions → Attestations** repo i pod `gh attestation verify`. Każdy może sprawdzić, skąd pochodzi obraz, bez dostępu do VM.

`deploy` zależy teraz od obu jobów i dostaje uprawnienie do odczytu atestacji:

```yaml
  deploy:
    needs: [gate, images]
    runs-on: [self-hosted, jjdevhub]
    environment:
      name: production
      url: https://hub.example.com
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    permissions:
      contents: read
      attestations: read
    steps:
      - uses: actions/download-artifact@<sha> # v5.0.0
        with:
          pattern: image-*
          path: ${{ runner.temp }}/images
          merge-multiple: true

      - name: Verify and deploy the release
        working-directory: /opt/jjdevhub
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          DEPLOY_SHA: ${{ needs.gate.outputs.sha }}
          IMAGES_DIR: ${{ runner.temp }}/images
        run: ./infra/ci/release-and-deploy.sh "$DEPLOY_SHA"
```

### 8. Weryfikacja na VM przed `docker load`

Jednorazowo na VM, GitHub CLI z repozytorium apt GitHuba:

```bash
sudo install -d -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt-get update && sudo apt-get install -y gh
gh --version
```

`gh` na VM nie jest zalogowany. Dostaje token tylko przez `GH_TOKEN` z joba deployu, ważny do końca joba.

[release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) dostaje weryfikację:

```bash
verify_image() {
  local tar="$1" record="$2"
  local signer="$REPO/.github/workflows/release.yml"

  gh attestation verify "$tar" --repo "$REPO" \
    --signer-workflow "$signer" \
    --source-ref refs/heads/main \
    --source-digest "$remote_sha" \
    --deny-self-hosted-runners \
    --format json > "$record.provenance.json"

  gh attestation verify "$tar" --repo "$REPO" \
    --signer-workflow "$signer" \
    --source-digest "$remote_sha" \
    --predicate-type https://cyclonedx.org/bom \
    --format json > "$record.sbom.json"
}
```

Każda flaga sprawdza pole certyfikatu, które wypełnia GitHub z tokenu OIDC, a nie treść, którą workflow sam wpisuje do predykatu:

| Flaga | Co wymusza |
| --- | --- |
| `--repo` | atestacja należy do tego repozytorium |
| `--signer-workflow` | podpisał `release.yml` z tego repo, a nie dowolny workflow z dostępem do `attestations: write` |
| `--source-ref refs/heads/main` | przebieg był na `main`, nie na gałęzi PR ani gałęzi Release PR |
| `--source-digest` | obraz zbudowano z commita, który właśnie jest wdrażany; archiwum z innego wydania nie przejdzie |
| `--deny-self-hosted-runners` | budował runner GitHuba, nie maszyna, którą ktoś mógł wcześniej zmodyfikować |
| `--predicate-type` | domyślnie provenance SLSA v1, w drugim wywołaniu SBOM CycloneDX |

Kolejność w skrypcie, po sprawdzeniu „already deployed” z 11:

1. Źródło archiwów: `IMAGES_DIR` (deploy z wydania), inaczej `/var/lib/jjdevhub/images/<sha>/` (wcześniejszy deploy tego wydania), inaczej pobranie z przebiegu wydania (krok 9). Brak archiwum przerywa deploy.
2. `verify_image` dla `api.tar` i `web.tar`. Błąd którejkolwiek weryfikacji kończy skrypt przed jakąkolwiek zmianą na VM.
3. Kopia archiwów i rekordów weryfikacji do `/var/lib/jjdevhub/images/<sha>/` (ten sam właściciel co `last-release-sha`).
4. `docker load -i` każdego archiwum. Skrypt porównuje wiersz `Loaded image: …` z oczekiwanym `jjdevhub/<nazwa>:<pierwsze 12 znaków sha>`.
5. `export JJDEVHUB_IMAGE_TAG="${remote_sha:0:12}"`, a potem `docker compose … up -d --no-build --wait --wait-timeout 180` (bez `--build`).
6. Po udanym `wait_http`: w `/var/lib/jjdevhub/images/` zostaje pięć najnowszych katalogów, a obrazy `jjdevhub/*` z usuniętych katalogów znikają przez `docker image rm`.

`docker-compose.prod.yml` z 12 dostaje obrazy zamiast budowania:

```yaml
  api:
    image: jjdevhub/api:${JJDEVHUB_IMAGE_TAG:?JJDEVHUB_IMAGE_TAG is required}
    pull_policy: never

  web:
    image: jjdevhub/web:${JJDEVHUB_IMAGE_TAG:?JJDEVHUB_IMAGE_TAG is required}
    pull_policy: never
```

`pull_policy: never` i `--no-build` razem znaczą: tylko obraz załadowany z archiwum po weryfikacji. Brak obrazu kończy `up` błędem zamiast po cichu zbudować go z kodu albo szukać `jjdevhub/api` w Docker Hub. Lokalnie nic się nie zmienia: plik bazowy nadal ma `build:`.

Plik `<sha>/api.sbom.json` to zweryfikowany SBOM tego, co działa. Odpowiedź na pytanie „czy produkcja ma wersję X biblioteki Y” to `jq` na tym pliku, bez dostępu do kontenera.

### 9. Rollback z zapisanych archiwów

Job `deploy` w `deploy.yml` z 11 dostaje te same zmienne co w `release.yml`, bez `IMAGES_DIR`, i jedno uprawnienie więcej:

```yaml
    permissions:
      contents: read
      attestations: read
      actions: read
    steps:
      - working-directory: /opt/jjdevhub
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          DEPLOY_SHA: ${{ needs.gate.outputs.sha }}
          JJDEVHUB_ALLOW_ROLLBACK: ${{ inputs.rollback && '1' || '0' }}
        run: ./infra/ci/release-and-deploy.sh "$DEPLOY_SHA"
```

Bez `IMAGES_DIR` skrypt bierze archiwa z `/var/lib/jjdevhub/images/<sha>/`. Gdy katalogu już nie ma (wydanie starsze niż pięć ostatnich), szuka przebiegu wydania po artefakcie:

```bash
run_id="$(gh api "repos/$REPO/actions/artifacts?name=image-api&per_page=100" \
  --jq ".artifacts[] | select(.workflow_run.head_sha == \"$remote_sha\" and (.expired | not)) | .workflow_run.id" \
  | head -n 1)"
gh run download "$run_id" --repo "$REPO" --pattern 'image-*' --dir "$tmp"
```

`actions: read` jest potrzebne do pobrania artefaktu z innego przebiegu. Weryfikacja z kroku 8 biegnie zawsze, także dla archiwum z lokalnego katalogu: kosztuje sekundy, a katalog na dysku nie jest źródłem zaufania.

Artefakty żyją 90 dni. Wydanie starsze i spoza lokalnych pięciu nie ma już obrazu. Wtedy poprawką jest nowe wydanie z `revert:`, a nie odbudowa starego obrazu poza `release.yml`.

### 10. Koniec crona

Cron z [03-github.md](03-github.md) wdrażał bez CI, potem (11) wdrażał najnowszy tag. Po tym kroku nie ma czym zweryfikować atestacji: weryfikacja potrzebuje tokenu, który istnieje tylko w jobie.

- `infra/ci/jjdevhub-release.cron` znika z repo.
- `release-and-deploy.sh` bez argumentu kończy się `usage: release-and-deploy.sh <sha> (run from release.yml or deploy.yml)` i kodem 2.
- Na VM, jako użytkownik, który ma wpis:

```bash
crontab -l | grep -v release-and-deploy.sh | crontab -
```

Runner offline w chwili wydania nie gubi deployu: job `deploy` czeka w kolejce do 24 godzin. Po dłuższej przerwie przebieg kończy się błędem, a `gh run rerun <id> --failed` wznawia sam deploy, bo archiwa leżą w artefaktach przebiegu.

[03-github.md](03-github.md) dostaje wpis w sekcji „Historia zmian”: cron usunięty, deploy tylko z `release.yml` i `deploy.yml`, obrazy z atestacją. W [README.md](../../README.md), w obu częściach, sekcja „CI / CD” opisuje budowę obrazów w `release.yml` i weryfikację na VM, a wiersz `infra/ci/` w „Layout” / „Układ” traci słowo „cron”.

### 11. Skan SBOM tego, co działa

Trivy na PR sprawdza CVE znane w dniu builda. Nowe CVE w bibliotece, która już działa na produkcji, wychodzą tygodnie później. `.github/workflows/sbom-scan.yml`:

```yaml
name: sbom-scan

on:
  schedule:
    - cron: "23 5 * * 1"
  workflow_dispatch:

permissions: {}

jobs:
  sbom-scan:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: read
    steps:
      - uses: actions/checkout@<sha> # v7.0.1
        with:
          persist-credentials: false

      - name: Install Trivy
        run: ./infra/ci/install-trivy.sh

      - name: Scan SBOMs of the latest release
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
        run: ./infra/ci/sbom-scan.sh
```

`infra/ci/sbom-scan.sh` (nowy):

- najnowszy nieprzeterminowany artefakt `sbom-api` (`GET /repos/{repo}/actions/artifacts?name=sbom-api`) wskazuje przebieg ostatniego wydania,
- `gh run download <id> --pattern 'sbom-*'`,
- `trivy sbom --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed` dla każdego pliku `*.cdx.json`.

Czerwony przebieg to mail od GitHuba i sygnał do wydania z podbitą zależnością. Skan nie buduje niczego i nie dotyka VM. Po rollbacku dalej patrzy na najnowsze wydanie, bo rollback jest stanem przejściowym.

## Jak sprawdzić, że działa

```bash
grep -rnE 'uses: [^ ]+@[^ ]{1,39}( |$)' .github/workflows || echo 'all actions pinned'
gh api repos/jtjaskulski/JJDevHub/actions/permissions
gh api repos/jtjaskulski/JJDevHub/actions/permissions/selected-actions
gh run download --repo jtjaskulski/JJDevHub -n image-api -D /tmp/rel <id przebiegu release>
gh attestation verify /tmp/rel/api.tar --repo jtjaskulski/JJDevHub \
  --signer-workflow jtjaskulski/JJDevHub/.github/workflows/release.yml --source-ref refs/heads/main
```

1. Gałąź z `uses: actions/checkout@v7` w dowolnym workflowie: przebieg kończy się błędem przed pierwszym krokiem, z komunikatem o wymaganym przypięciu do pełnego SHA.
2. PR z krokiem `run: echo "${{ github.event.pull_request.title }}"`: `zizmor` czerwony (`template-injection`), alert w **Security → Code scanning** z kategorią `zizmor`.
3. Release PR ma zielone `api`, `web`, `pr-title`, `secrets` i `zizmor`, wszystkie z `workflow_dispatch`.
4. Przebieg `scorecard` zielony, strona `scorecard.dev/viewer/?uri=github.com/jtjaskulski/JJDevHub` pokazuje wynik, odznaka w README się renderuje.
5. Po scaleniu Release PR zakładka **Attestations** pokazuje provenance i SBOM dla `api.tar` oraz provenance i dwa SBOM-y dla `web.tar`.
6. Komenda `gh attestation verify` z bloku wyżej kończy się `Verification succeeded!`. Ta sama komenda na pliku po `printf x >> /tmp/rel/api.tar` kończy się błędem.
7. Na VM: `docker image inspect jjdevhub-api --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'` zwraca SHA z `/var/lib/jjdevhub/last-release-sha`.
8. Na VM: `docker image ls mcr.microsoft.com/dotnet/sdk` i `docker image ls node` są puste — na produkcji nikt nie budował.
9. `gh workflow run deploy.yml -f tag=<poprzedni tag> -f rollback=true` wdraża archiwum z `/var/lib/jjdevhub/images/` bez pobierania; log pokazuje obie weryfikacje.
10. `crontab -l` na VM nie zawiera `release-and-deploy.sh`.
11. `gh workflow run sbom-scan.yml` kończy się na zielono albo listą CVE z obrazów ostatniego wydania.

## Czego w tym pliku nie ruszać

- Nie wracaj do `uses: …@v7` „bo czytelniej”. Komentarz `# v7.0.1` przy SHA jest dla czytelnika, SHA dla maszyny.
- Nie dodawaj akcji do `patterns_allowed` bez przeczytania jej `action.yml` i tego, co instaluje.
- Nie usuwaj `--deny-self-hosted-runners`, `--source-digest` ani `--signer-workflow` z weryfikacji „bo deploy nie przechodzi”. Nieprzechodząca weryfikacja to dokładnie ten przypadek, przed którym chroni.
- Nie buduj obrazu na VM (`compose up --build`) jako obejścia awarii. Poprawka idzie przez PR i wydanie.
- Nie dawaj jobowi `images` cache Actions ani `--cache-from`. Obraz wydania powstaje od zera.
- Nie przywracaj crona. Runner offline to job w kolejce, nie deploy bez weryfikacji.
- Nie wyłączaj `cooldown` w Dependabot ani `minimumReleaseAge` w pnpm na stałe. Pilna poprawka dostaje wyjątek dla jednej paczki (`minimumReleaseAgeExclude`), a nie wyłączenie dla wszystkich.

## Następny numer

Ciąg `docs/CICD` kończy się na tym numerze. Przeniesienie budowy obrazów na rejestr w sieci lokalnej i reużywalny workflow jako podpisującego robi [docs/api/18-ci-uslug.md](../api/18-ci-uslug.md). Dalsze pomysły (OpenBao, Kubernetes, staging) są w [przyszlosc.md](przyszlosc.md).

---

## Pełny tutorial: łańcuch dostaw oprogramowania (od zera)

Wybór SHA, atestacji Sigstore i CycloneDX jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają ogniwa ataku, poziomy SLSA, przebieg atestacji i typowe pomyłki. Przepis plików jest wyżej.

### Gdzie atakuje się łańcuch dostaw

| Ogniwo | Przykład z historii | Co go tu zamyka |
| --- | --- | --- |
| zależność kodu | `event-stream` (2018): nowy opiekun dodał kod kradnący portfele; Shai-Hulud (2025): robak publikujący zainfekowane wersje paczek npm | lock, karencja, `trustPolicy`, `pnpm audit` i NuGet audit z [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md) |
| narzędzie budowania | `xz-utils` (2024): tylna furtka w tarballu wydania, której nie było w repo | obrazy bazowe po digeście, SBOM, skan tego, co działa |
| akcja CI | `tj-actions/changed-files` (2025): tagi przestawione na złośliwy commit | SHA, lista dozwolonych akcji, `impostor-commit` w zizmorze |
| skrypt w CI | Codecov Bash Uploader (2021): zmieniony skrypt `curl \| bash` wysyłał zmienne środowiskowe | binarki ze sprawdzeniem `sha256sum -c` |
| system budowania | SolarWinds (2020): kod wstrzyknięty podczas builda, podpisany prawdziwym kluczem | build na świeżym runnerze, provenance z tożsamością workflowu |
| artefakt po buildzie | podmiana obrazu w rejestrze albo na dysku | atestacja po digeście, weryfikacja przed `docker load` |
| deploy | ręczny build na serwerze „na szybko” | VM bez builda, `pull_policy: never`, brak crona |

Żaden pojedynczy mechanizm nie zamyka wszystkiego. Łańcuch jest tak mocny, jak ogniwo bez kontroli.

### SLSA w praktyce

| Poziom Build | Wymaganie | Tu |
| --- | --- | --- |
| L0 | nic | stan sprzed tego kroku: obraz z VM, bez opisu pochodzenia |
| L1 | provenance istnieje | — |
| L2 | provenance podpisana przez hostowaną platformę budowania | ten krok: GitHub podpisuje provenance z runnera GitHuba |
| L3 | platforma izoluje build od kodu, który go wywołuje; sekrety podpisu niedostępne dla kroków użytkownika | reużywalny workflow jako podpisujący — kierunek z [18-ci-uslug.md](../api/18-ci-uslug.md) |

L2 odpowiada na pytanie „czy ten plik zbudował GitHub w tym repozytorium z tego commita”. L3 dodaje „i czy przepis builda był tym jednym, zatwierdzonym przepisem”. W 13 podpisuje `release.yml`, który sam zawiera kroki builda. Krok z kodem z repo mógłby teoretycznie wpłynąć na treść predykatu, ale nie na certyfikat — dlatego weryfikacja patrzy tylko na pola certyfikatu.

### Jak działa atestacja GitHuba

```text
job images (ubuntu-latest)
  │  1. token OIDC: repo, workflow, ref, commit, runner_environment=github-hosted
  ▼
Fulcio (Sigstore)
  │  2. certyfikat X.509 ważny ~10 min, pola z tokenu w rozszerzeniach
  ▼
job images
  │  3. podpis twierdzenia in-toto: subject = sha256(api.tar), predicate = provenance SLSA
  ▼
Rekor (publiczny rejestr przejrzystości)  ◄── 4. wpis z podpisem i znacznikiem czasu
  │
  ▼
API atestacji GitHuba  ◄── 5. pakiet (bundle): podpis, certyfikat, dowód z Rekora

VM: gh attestation verify api.tar
  6. sha256(api.tar) → pakiety z API
  7. łańcuch certyfikatu do korzenia Sigstore (TUF), znacznik czasu z Rekora
  8. pola certyfikatu == --repo, --signer-workflow, --source-ref, --source-digest
```

Nie ma klucza prywatnego, który trzeba chronić, rotować i którego wyciek pozwoliłby podpisać cokolwiek. Klucz istnieje kilka minut w pamięci joba, a certyfikat mówi, *kto* podpisał, w kategoriach workflowu, nie osoby. Wpis w Rekorze sprawia, że podpisu nie da się wystawić po cichu: każdy podpis dla tego repo jest publicznie widoczny.

### Certyfikat a predykat

`gh attestation verify --format json` zwraca dwie części. `verificationResult.signature.certificate` i `verifiedTimestamps` pochodzą od GitHuba i Sigstore. `statement.predicate` (np. lista parametrów builda w provenance) wpisuje workflow. Ktoś z kontrolą nad krokami joba mógłby wpisać tam dowolną treść.

Dlatego polityka z kroku 8 używa wyłącznie flag sprawdzających certyfikat. Gdyby kiedyś potrzebna była polityka na treści SBOM („żadnej licencji AGPL”, „Npgsql co najmniej 9.0.4”), to i tak tylko jako dodatkowa kontrola: SBOM mówi, co workflow znalazł, a podpis — że znalazł to nasz workflow.

### SBOM: CycloneDX, SPDX i VEX

| | CycloneDX | SPDX |
| --- | --- | --- |
| Pochodzenie | OWASP, ECMA-424 | Linux Foundation, ISO/IEC 5962 |
| Mocna strona | bezpieczeństwo: podatności, VEX, usługi, sprzęt | licencje i zgodność prawna |
| Tu | tak: Trivy i `attest-sbom` obsługują go natywnie | Trivy umie go zapisać (`--format spdx-json`) |

SBOM przydaje się dopiero wtedy, gdy ktoś go czyta: skan z kroku 11, `jq` na produkcyjnym SBOM przy nowym CVE, odpowiedź na pytanie klienta „czy używacie biblioteki X”.

VEX (Vulnerability Exploitability eXchange) to dokument, w którym producent mówi „CVE-… dotyczy biblioteki w obrazie, ale nas nie dotyczy, bo …”. Trivy przyjmuje VEX (`--vex`) zamiast `.trivyignore`: wyjątek ma uzasadnienie w standardowym formacie i może jechać razem z obrazem. Przy jednym autorze i komentarzach w Dockerfile to na razie nadmiar.

### Typowe pomyłki

1. **Przypięcie SHA bez Dependabota dla `github-actions`.** Akcje starzeją się z lukami. Ekosystem `github-actions` z `cooldown` musi zostać.
2. **SHA z forka.** Wygląda poprawnie w diffie. `impostor-commit` w zizmorze albo `pinact run` zamiast ręcznego kopiowania.
3. **zizmor tylko z SARIF.** Job nigdy nie jest czerwony, bo w trybie SARIF kod wyjścia to 0. Drugi krok z `advanced-security: false` robi bramkę.
4. **Nowy wymagany check bez linii w kroku dispatch `release.yml`.** Release PR stoi.
5. **Weryfikacja tylko `--repo`.** Przechodzi atestacja z dowolnego workflowu tego repo, także z gałęzi PR. `--signer-workflow`, `--source-ref` i `--source-digest` zawężają do jednego przepisu, `main` i tego wydania.
6. **Polityka na `statement.predicate`.** Treść predykatu pisze workflow; ufać można polom certyfikatu.
7. **SBOM obrazu `web` bez zależności npm.** Bundel Vite nie zostawia metadanych w obrazie; stąd drugi SBOM z `pnpm-lock.yaml`.
8. **Tag zamiast digestu w `FROM`.** Dwa buildy tego samego commita dają różne obrazy, a różnicy nie widać w gicie.
9. **`docker load` przed weryfikacją.** Obraz jest już w demonie; tag wskazuje niesprawdzoną treść, a następny `compose up` może go użyć.
10. **`compose up` bez `--no-build` i bez `pull_policy: never`.** Brak obrazu kończy się buildem na VM albo próbą pobrania z Docker Hub.
11. **Pilna poprawka bezpieczeństwa zablokowana przez `minimumReleaseAge`.** Wyjątek dla tej jednej paczki w `minimumReleaseAgeExclude` i usunięcie wyjątku po trzech dniach.
12. **Lock NuGet generowany innym SDK niż w CI.** Pruning paczek frameworka zależy od SDK. [global.json](../../global.json) przypina SDK; lock odświeża się tym samym SDK, które ma CI.
13. **Oczekiwanie Scorecard 10/10.** Code-Review i Fuzzing w projekcie jednej osoby będą niskie. Ważne, żeby nie spadały kontrole, które zależą od plików w repo.
14. **Rollback starszego wydania po 90 dniach.** Artefakt wygasł. Poprawka to nowe wydanie z `revert:`.

### Oficjalne źródła

- [Security hardening for GitHub Actions](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions) — przypinanie akcji, `GITHUB_TOKEN`, wstrzyknięcia.
- [REST API: GitHub Actions permissions](https://docs.github.com/en/rest/actions/permissions) — `allowed_actions`, `sha_pinning_required`, `selected-actions`.
- [Using artifact attestations](https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds) i [gh attestation verify](https://cli.github.com/manual/gh_attestation_verify).
- [actions/attest-build-provenance](https://github.com/actions/attest-build-provenance) i [actions/attest-sbom](https://github.com/actions/attest-sbom).
- [SLSA v1.0: Build levels](https://slsa.dev/spec/v1.0/levels) i [in-toto](https://in-toto.io/).
- [Sigstore: Fulcio, Rekor](https://docs.sigstore.dev/).
- [zizmor: audits](https://docs.zizmor.sh/audits/), [usage](https://docs.zizmor.sh/usage/) i [zizmor-action](https://github.com/zizmorcore/zizmor-action).
- [OpenSSF Scorecard: checks](https://github.com/ossf/scorecard/blob/main/docs/checks.md) i [scorecard-action](https://github.com/ossf/scorecard-action).
- [CycloneDX](https://cyclonedx.org/) i [Trivy: SBOM](https://trivy.dev/latest/docs/supply-chain/sbom/).
- [Dependabot options: cooldown](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference#cooldown-).
- [NuGet: lock files](https://learn.microsoft.com/en-us/nuget/consume-packages/package-references-in-project-files#locking-dependencies) i [package source mapping](https://learn.microsoft.com/en-us/nuget/consume-packages/package-source-mapping).
- [pnpm: minimumReleaseAge, trustPolicy](https://pnpm.io/settings).
- [pinact](https://github.com/suzuki-shunsuke/pinact).

### Co zapamiętać

Akcje są przypięte po SHA, a GitHub odrzuca inne przypięcie. Lista akcji jest zamknięta, zizmor pilnuje workflowów jako wymagany check, a Scorecard pokazuje wynik publicznie. Obrazy `api` i `web` powstają raz, w `release.yml` na runnerze GitHuba, ze skanem Trivy i SBOM-em. GitHub podpisuje provenance i SBOM archiwum obrazu przez Sigstore. VM sprawdza podpis, workflow, gałąź i commit wydania, zanim załaduje obraz, i sama niczego nie buduje. Zależności mają lock, karencję i digesty, a co tydzień Trivy skanuje SBOM ostatniego wydania. Żadnego nowego sekretu.
