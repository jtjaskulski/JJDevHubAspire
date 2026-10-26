# Bramki scalenia

Pull request do `develop` przechodzi pierwszą bramkę. Do `release` drugą. Do `main` trzecią. Check z wcześniejszej bramki jest wymagany także na dalszej gałęzi. Inaczej ruleset czekałby na status, którego workflow nie wysłał.

Ten plik jest skrótem numeru 02. Pełna specyfikacja jest w [cicd/02-bramki.md](cicd/02-bramki.md). Lista po numerach `03`–`07` jest w [cicd/README.md](cicd/README.md).

## Checki

| Gałąź | Wymagane w tym numerze |
| --- | --- |
| `develop` | `branch-name`, `pr-title`, `build`, `unit-tests`, `format` |
| `release` | checki z `develop` oraz `integration-tests` |
| `main` | checki z `release` oraz `performance` |

`codeql`, `sonarqube`, `image-scan`, `gitleaks`, `dependency-vulnerabilities`, `sbom`, `attestations`, `release-tags`, `zizmor`, `action-pins` i `scorecard` wchodzą w numerach `03`–`07`, każdy ze swoim workflowem.

Job idzie na `ubuntu-latest`. Build, format i test jednostkowy mają `20` minut. Integracja i wydajność mają `30`. Filtr `paths` na `on` jest zabroniony: pull request samej dokumentacji i tak dostaje status.

## Pusty sukces

Brak projektu we wskazanym komponencie kończy job kodem `0` i linią `no material for <job>`. To samo, gdy zmiana dotyka tylko `docs/` albo `.github/`. Ta linia pokazuje, że job doszedł do końca bez kompilacji.

Projekt produkcyjny w `src/services`, `src/gateway` albo `src/shared` bez projektu testowego jest porażką `unit-tests`, także gdy sam diff dokumentacji niczego nie rusza. `JJDevHub.AppHost` i `JJDevHub.Server` nie są komponentami tej mapy.

Wersję SDK wskazuje `global.json`. Projekt bez tego pliku kończy kompilację i test kodem innym niż zero. Sam plik, gdy żaden komponent nie ma projektu, zostawia job przy pustym sukcesie.

Zero testów w filtrze jednostkowym, przy istniejącym projekcie testowym, jest porażką. Zero testów integracyjnych albo wydajnościowych jest sukcesem. Test, który jest i pada, jest porażką joba.

## Filtry

| Job | Filtr |
| --- | --- |
| `unit-tests` | `Category!=Integration&Category!=Performance` |
| `integration-tests` | `Category=Integration` |
| `performance` | `Category=Performance` |

`integration-tests` startuje na `release` i `main`. `performance` startuje na `main`. Na `develop` te joby nie startują i ruleset ich nie wymaga.

## Komponenty

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

`src/shared/JJDevHub.Shared.Kernel/**` ustawia kernel. Komponenty biorą się z `ProjectReference` do tego projektu. Sam kernel, zanim ktoś go zreferencjonuje, nie dopisuje usługi.

`Directory.Packages.props`, `global.json` i `*.sln` oznaczają każdy komponent, który ma już projekt. Zmiana w News nie buduje Identity.

## Sync

Nazwy checków wgrywa lokalnie `.github/scripts/sync-rulesets.sh`. Kliknięcie w ustawieniach repozytorium nie jest wdrożeniem.

## Sprawdzenie lokalne

```bash
printf '%s\n' 'src/services/News/News.Api/Program.cs' 'docs/cicd/02-bramki.md' \
  | .github/scripts/affected-components.sh
printf '%s\n' 'docs/cicd/02-bramki.md' | .github/scripts/affected-components.sh
printf '%s\n' 'src/shared/JJDevHub.Shared.Kernel/Kernel.cs' \
  | .github/scripts/affected-components.sh
```

Pierwsze wywołanie zawiera `news` i nie zawiera `identity`. Drugie daje pustą listę i kod `0`. Trzecie daje `kernel` równe `true`, pustą listę i kod `0`.

```bash
empty=$(mktemp -d)
repo=$(pwd)
(cd "$empty" && "${repo}/.github/scripts/require-material.sh" --job build --pattern '*.csproj')
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
```

Materiał w pustym katalogu wypisuje `no material for build` i kończy się kodem `0`. Zła nazwa gałęzi nadal kończy się kodem `1`.
