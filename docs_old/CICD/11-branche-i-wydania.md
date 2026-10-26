# Branche i wydania — trunk-based, release-please, deploy z tagu

## Po co

Dziś każdy zielony merge na `main` od razu jedzie na produkcję: [deploy.yml](../../.github/workflows/deploy.yml) startuje po `api` albo `web` (`workflow_run`), a [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) zakłada lokalną gałąź `release/YYYY-MM-DD.N` jako znacznik wdrożenia. Nie ma numeru wersji, changelogu ani odpowiedzi na pytanie „co jest na produkcji i co zmieniło się od wczoraj”. Branch protection z [03-github.md](03-github.md) jest wyklikana w panelu i nie ma jej w gicie.

Po tym kroku:

- `main` jest jedyną długowieczną gałęzią. Praca idzie krótkimi gałęziami z prefiksem (`feature/`, `fix/`, …) i wraca jednym commitem squash, którego treścią jest tytuł PR w formacie Conventional Commits.
- [release-please](https://github.com/googleapis/release-please) czyta te commity i trzyma otwarty **Release PR**: podbite wersje komponentów i changelog. Scalenie Release PR to wydanie: tagi `api-v0.4.0`, `web-v0.3.1`, `infra-v0.2.0` i GitHub Release z notatkami.
- Deploy startuje tylko z wydania, w tym samym workflow `release.yml`, po sprawdzeniu, że CI tego commita jest zielone. `deploy.yml` zostaje do ponownego wdrożenia i rollbacku wybranego tagu.
- Reguły gałęzi i tagów są plikami JSON w `.github/rulesets/`, nakładanymi skryptem. Tag wydania nie da się przesunąć ani usunąć, a GitHub Release jest niezmienny (Immutable Releases).

Wszystko na `GITHUB_TOKEN`. Ten krok nie dodaje żadnego sekretu.

## Dlaczego ta technologia

### Trunk-based i Release PR zamiast GitFlow

GitFlow (`develop`, `release/*`, `hotfix/*`) powstał dla produktu, w którym kilka wersji żyje równolegle. Usługa webowa ma jedną wersję: tę na serwerze. Długie gałęzie dają duże scalenia tuż przed wydaniem. Trunk-based trzyma jedną długowieczną gałąź, `main`, i krótkie gałęzie wracające jednym squashem. Sam GitHub Flow („scalenie = wdrożenie”) przegrał, bo odbiera chwilę, w której widać, co wchodzi razem. Release PR jest tą chwilą: wersje i changelog przed tagiem. Koszt: tytuł PR musi być Conventional Commitem, a merge commit i rebase merge są wyłączone, bo changelog zakłada jeden commit na PR.

### release-please zamiast wydania przy każdym pushu

[release-please](https://github.com/googleapis/release-please) czyta commity od ostatniego tagu `<komponent>-v*` i trzyma otwarty Release PR (`version.txt`, `CHANGELOG.md`, manifest). Scalenie tego PR tworzy tagi i GitHub Release. semantic-release przegrał: wydaje przy każdym pushu, bez przeglądu, i jest ekosystemem Node. Changesets przegrały: dokładają plik `.changeset` do każdego PR i są nastawione na npm. GitVersion i Nerdbank.GitVersioning przegrały: liczą wersję z historii albo wysokości commita i nie piszą changelogu pod przegląd. Koszt: tag tworzy `GITHUB_TOKEN`, więc zdarzenie `release` nie odpala kolejnych workflowów. Deploy jest następnym jobem w `release.yml`, nie osobnym triggerem `release: published`.

### Ruleset w gicie zamiast branch protection w panelu

Ruleset to jeden JSON w `.github/rulesets/`, nakładany skryptem. Klasyczna branch protection przegrała: żyje w panelu, administrator ją omija, a tagów nie obejmuje (stara ochrona tagów jest wycofana). Ruleset obowiązuje także administratora, chyba że jest na liście `bypass_actors`, i umie `target: tag`. Koszt: reguła w trybie wymuszania blokuje scalenie, dopóki wymagany check nie pojawi się na commicie. Immutable Releases dokładają drugą kłódkę: tagu wydania nie da się przesunąć na inny commit, a `gh release verify` sprawdza atestację in-toto.

## Co już jest w repo

- [api.yml](../../.github/workflows/api.yml) (job `api`) i [web.yml](../../.github/workflows/web.yml) (job `web`): każdy PR bez filtra ścieżek, push na `main` z filtrem, `workflow_dispatch` w obu.
- [deploy.yml](../../.github/workflows/deploy.yml): `workflow_run` po `api` i `web`, job `gate` na `ubuntu-latest` z [deploy-gate.mjs](../../infra/ci/deploy-gate.mjs) (wymaga zielonych workflowów, których filtr pasuje do zmian), job `deploy` na `[self-hosted, jjdevhub]`.
- [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh): `flock`, stan w `/var/lib/jjdevhub/last-release-sha`, test „starszy commit nie cofa nowszego” (`merge-base --is-ancestor`), gałąź `release/YYYY-MM-DD.N`, `compose up --build --wait`, `wait_http`.
- [jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron): co godzinę wdraża `origin/main`.
- [dependabot.yml](../../.github/dependabot.yml): `nuget`, `npm`, `github-actions`, dwa `docker`, co tydzień.
- Branch protection `main` z [03-github.md](03-github.md): wymagany PR, wymagane checki `api` i `web`.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie tu |
| --- | --- |
| trunk-based development | Jedna gałąź główna, krótkie gałęzie tematyczne (godziny, dni), częste scalanie. Bez `develop` i długich gałęzi wydań. |
| squash merge | Cały PR wchodzi na `main` jednym commitem. Treść commita bierze się z tytułu i opisu PR. |
| Conventional Commits | Format `typ(zakres)!: opis`, np. `feat(web): add lesson search`. Typ decyduje o podbiciu wersji. |
| SemVer | `MAJOR.MINOR.PATCH`. Przed `1.0.0` zmiana łamiąca podbija `MINOR` (`bump-minor-pre-major`). |
| release-please | Narzędzie Google: z commitów od ostatniego tagu składa Release PR z wersjami i changelogiem, po scaleniu tworzy tagi i GitHub Release. |
| Release PR | PR `chore: release main` na gałęzi `release-please--branches--main`. Aktualizuje się przy każdym pushu na `main`. |
| tryb manifest | Konfiguracja wielu komponentów w jednym repo: `release-please-config.json` i `.release-please-manifest.json`. |
| komponent | Ścieżka w repo z własną wersją, changelogiem i tagiem `<komponent>-vX.Y.Z`. |
| ruleset | Nowsza forma ochrony gałęzi i tagów: zestaw reguł z warunkiem na nazwę refa, zarządzany przez REST API. |
| required status check | Check, który musi być zielony na ostatnim commicie PR, zanim GitHub pozwoli scalić. |
| Immutable Releases | Ustawienie repo: opublikowany GitHub Release ma zablokowany tag i pliki, a GitHub wystawia atestację wydania. |
| environment | Nazwany cel wdrożenia w GitHubie (`production`) z regułą, z której gałęzi wolno wdrażać, i historią wdrożeń. |
| `GITHUB_TOKEN` | Token joba. Zdarzenie wywołane nim (push, tag, PR) nie uruchamia innych workflowów, z wyjątkiem `workflow_dispatch` i `repository_dispatch`. |

## Kroki

### 1. Model gałęzi

`main` zawsze nadaje się do wydania. Każda zmiana idzie gałęzią z prefiksem i wraca PR-em:

| Prefiks gałęzi | Typowy typ w tytule PR | Przykład |
| --- | --- | --- |
| `feature/` | `feat` | `feature/lesson-search` → `feat(web): add lesson search` |
| `fix/` | `fix` | `fix/etag-weak-compare` → `fix(api): compare weak etags` |
| `docs/` | `docs` | `docs/cicd-11` → `docs: describe release flow` |
| `chore/` | `chore`, `build` | `chore/bump-sdk` → `build: bump .NET SDK to preview 7` |
| `ci/` | `ci` | `ci/pr-title` → `ci: check pull request titles` |
| `refactor/` | `refactor` | `refactor/result-type` → `refactor(api): extract result type` |
| `test/` | `test` | `test/identity-invites` → `test(api): cover expired invites` |

Nazwa po prefiksie: małe litery, cyfry i myślniki. Gałęzie botów (`dependabot/…`, `release-please--…`) mają własne prefiksy i przechodzą bez zmian.

Gałąź żyje krótko. Gdy `main` uciekł, PR aktualizuje się przyciskiem **Update branch** (rebase) albo `gh pr update-branch --rebase`. Niedokończona funkcja wchodzi na `main` ukryta: endpoint bez trasy w gateway, treść z widocznością `Private`, strona bez linku w nawigacji.

Poprawka produkcji nie ma osobnej ścieżki: gałąź `fix/…`, PR, scalenie, scalenie Release PR. Szybszy ratunek to rollback poprzedniego tagu z kroku 8, a poprawka idzie potem zwykłą drogą.

### 2. Squash jako jedyny sposób scalania

Ustawienia repozytorium idą z pliku, nie z panelu. [infra/ci/apply-rulesets.sh](../../infra/ci/apply-rulesets.sh) (nowy) zaczyna od:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo="${1:?usage: apply-rulesets.sh owner/name}"
root="$(git rev-parse --show-toplevel)"

gh api -X PATCH "repos/$repo" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -f squash_merge_commit_title=PR_TITLE \
  -f squash_merge_commit_message=PR_BODY \
  -F delete_branch_on_merge=true \
  -F allow_auto_merge=true \
  -F allow_update_branch=true >/dev/null

gh api -X PUT "repos/$repo/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=true >/dev/null
```

- `squash_merge_commit_title=PR_TITLE` — commit na `main` ma dokładnie tytuł PR. Commity na gałęzi mogą być roboczymi „wip”, bo do historii `main` nie trafiają.
- `default_workflow_permissions=read` — token joba bez `permissions:` w workflow dostaje tylko odczyt. Zapis ma tylko job, który go zadeklarował.
- `can_approve_pull_request_reviews=true` — pozwala `GITHUB_TOKEN` otwierać PR-y (GitHub łączy to z zatwierdzaniem w jednym przełączniku). release-please bez tego nie założy Release PR.

### 3. Tytuł PR jako Conventional Commit

`infra/ci/pr-title.mjs` (nowy) eksportuje `checkTitle(title)` i `checkBranch(branch)`, każda zwraca listę błędów. Wywołany jako skrypt czyta `PR_TITLE` i `PR_BRANCH` ze środowiska, wypisuje błędy i kończy się kodem 1.

Reguły tytułu:

- wzorzec `^(?<type>[a-z]+)(\((?<scope>[a-z0-9-]+)\))?(?<breaking>!)?: (?<subject>.+)$`,
- `type` z listy: `feat`, `fix`, `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `revert`,
- `subject` zaczyna się małą literą albo cyfrą i nie kończy kropką,
- cały tytuł do 100 znaków; gałęzie `dependabot/…` są zwolnione, bo nazwy pakietów NuGet bywają długie.

Reguły gałęzi: `^(feature|fix|docs|chore|ci|refactor|test)/[a-z0-9][a-z0-9-]*$` albo prefiks `dependabot/` lub `release-please--`.

Typu i prefiksu gałęzi skrypt nie wiąże. Changelog powstaje z tytułu, a nazwa gałęzi służy ludziom.

`infra/ci/pr-title.test.mjs` (`node --test`) sprawdza przykłady z tabeli kroku 1, `feat(api)!: drop v1 routes`, tytuły Dependabota i release-please oraz odrzucenia: `Added search`, `feat: Add search`, `feat: add search.`, `feature: add search`, gałąź `my-branch`.

`.github/workflows/pr-title.yml`:

```yaml
name: pr-title

on:
  pull_request:
    types: [opened, edited, synchronize, reopened]
  workflow_dispatch:
    inputs:
      title:
        required: true
        type: string
      branch:
        required: true
        type: string

permissions:
  contents: read

jobs:
  check:
    name: pr-title
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Test the checker
        run: node --test infra/ci/pr-title.test.mjs

      - name: Check title and branch
        env:
          PR_TITLE: ${{ github.event.pull_request.title || inputs.title }}
          PR_BRANCH: ${{ github.head_ref || inputs.branch }}
        run: node infra/ci/pr-title.mjs
```

- `edited` uruchamia check po poprawieniu tytułu, bez nowego commita.
- `synchronize` jest potrzebne, bo wymagany check musi istnieć na **ostatnim** commicie PR. Bez niego każdy nowy push zostawiałby PR bez `pr-title` i blokował scalenie.
- Tytuł trafia do skryptu przez `env`, nigdy przez `${{ … }}` wklejone w `run:`. Tytuł PR pisze autor PR, a wklejony w skrypt powłoki staje się kodem (`feat: x"; curl …`).
- `workflow_dispatch` z wejściami służy Release PR z kroku 6: PR założony przez `GITHUB_TOKEN` nie wywołuje zdarzenia `pull_request`.

### 4. Rulesets jako kod

`.github/rulesets/main.json`:

```json
{
  "name": "main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] }
  },
  "bypass_actors": [],
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    { "type": "required_signatures" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_extra_approval_for_unattributed_changes": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [
          { "context": "api", "integration_id": 15368 },
          { "context": "web", "integration_id": 15368 },
          { "context": "pr-title", "integration_id": 15368 }
        ]
      }
    }
  ]
}
```

- `bypass_actors: []` — reguły obowiązują także właściciela repo. Klasyczna branch protection domyślnie przepuszcza administratora.
- `required_signatures` — na `main` wchodzą tylko podpisane commity. Commit squash tworzy GitHub i podpisuje go swoim kluczem, więc lokalny klucz GPG nie jest potrzebny.
- `required_approving_review_count: 0` — jedyny autor nie zatwierdzi własnego PR. PR jest wymagany dla checków i historii, nie dla recenzji.
- `integration_id: 15368` to aplikacja GitHub Actions. Check o tej nazwie z innej aplikacji nie zaliczy reguły.
- `strict_required_status_checks_policy: false` — PR nie musi być zrebase'owany na najnowszy `main` przed scaleniem. Przy jednym autorze kolizje są rzadkie, a ewentualny błąd wychodzi w CI na pushu `main`, zanim Release PR zostanie scalony.

`.github/rulesets/release-tags.json`:

```json
{
  "name": "release-tags",
  "target": "tag",
  "enforcement": "active",
  "conditions": {
    "ref_name": { "include": ["refs/tags/*-v*"], "exclude": [] }
  },
  "bypass_actors": [],
  "rules": [
    { "type": "update" },
    { "type": "deletion" }
  ]
}
```

Tag wydania raz utworzony nie zmienia commita i nie znika. Reguły `creation` ruleset nie ma: tag tworzy release-please tokenem joba, a wyjątek dla aplikacji Actions w `bypass_actors` wpuściłby każdy workflow z `contents: write`, czyli ten sam krąg co bez reguły. Tworzyć tagi mogą więc owner i workflow z zapisem, a sekcja „Czego w tym pliku nie ruszać” zabrania ręcznych tagów.

Dalsza część `apply-rulesets.sh`:

```bash
for file in "$root"/.github/rulesets/*.json; do
  name="$(jq -r .name "$file")"
  id="$(gh api "repos/$repo/rulesets" --paginate --jq ".[] | select(.name == \"$name\") | .id")"
  if [[ -n "$id" ]]; then
    gh api -X PUT "repos/$repo/rulesets/$id" --input "$file" >/dev/null
    echo "updated ruleset $name ($id)"
  else
    gh api -X POST "repos/$repo/rulesets" --input "$file" >/dev/null
    echo "created ruleset $name"
  fi
done

gh api -X PUT "repos/$repo/environments/production" \
  --input - >/dev/null <<'JSON'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON
gh api "repos/$repo/environments/production/deployment-branch-policies" --jq '.branch_policies[].name' \
  | grep -qx main \
  || gh api -X POST "repos/$repo/environments/production/deployment-branch-policies" \
       -f name=main -f type=branch >/dev/null
```

Uruchomienie z laptopa, z kontem właściciela zalogowanym w `gh`:

```bash
./infra/ci/apply-rulesets.sh jtjaskulski/JJDevHub
gh ruleset check main --repo jtjaskulski/JJDevHub
```

Po pierwszym zielonym przebiegu `pr-title` na dowolnym PR (GitHub musi znać nazwę checka) usuń klasyczną regułę z [03-github.md](03-github.md), żeby nie było dwóch źródeł prawdy:

```bash
gh api -X DELETE repos/jtjaskulski/JJDevHub/branches/main/protection
```

[03-github.md](03-github.md) dostaje wpis w sekcji „Historia zmian”: ochrona `main` jest w `.github/rulesets/main.json`.

Merge queue (`merge_queue` w rulesecie) jest dostępna dla repozytoriów organizacji. Repo jest na koncie osobistym, więc ten krok jej nie używa. Po przeniesieniu do organizacji kolejka zastępuje `strict_required_status_checks_policy`: GitHub sam testuje PR na szczycie `main` przed scaleniem.

### 5. release-please w trybie manifest

Trzy komponenty. Każdy ma wersję, changelog i tag:

| Komponent | Ścieżka w konfiguracji | Plik wersji | Co obejmuje |
| --- | --- | --- | --- |
| `api` | `.` z wykluczeniami | `src/services/Identity/Identity.API/version.txt` | `src/services`, `src/building-blocks`, `src/aspire`, `src/gateway`, `tests`, `Directory.*.props`, `global.json`, `nuget.config`, `JJDevHub.sln` |
| `web` | `src/Clients` | `src/Clients/version.txt` i `web/package.json` | klient web i `shared/theme`, bez `mobile` |
| `infra` | `infra` | `infra/version.txt` | Compose, Prometheus, Jaeger, Grafana, skrypty CI i deployu |

Komponent `api` jest korzeniem repo z wykluczeniami, bo pliki budowania .NET (`Directory.Packages.props`, `global.json`) leżą w korzeniu. Bump paczki NuGet od Dependabota (`fix(deps): …` w `Directory.Packages.props`) wydaje więc `api`, a nie ginie poza komponentami. `infra` istnieje, bo zmiana dashboardu albo `docker-compose.yml` też musi dojechać na produkcję, a nie należy ani do API, ani do weba. `docs/`, `.github/` i `.cursor/` nie wydają niczego.

`release-please-config.json`:

```json
{
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "release-type": "simple",
  "include-component-in-tag": true,
  "bump-minor-pre-major": true,
  "separate-pull-requests": false,
  "group-pull-request-title-pattern": "chore: release ${branch}",
  "bootstrap-sha": "SHA_MAIN_W_DNIU_WDROZENIA",
  "changelog-sections": [
    { "type": "feat", "section": "Features" },
    { "type": "fix", "section": "Bug Fixes" },
    { "type": "perf", "section": "Performance" },
    { "type": "revert", "section": "Reverts" },
    { "type": "refactor", "section": "Refactoring", "hidden": true },
    { "type": "docs", "section": "Documentation", "hidden": true },
    { "type": "test", "section": "Tests", "hidden": true },
    { "type": "build", "section": "Build", "hidden": true },
    { "type": "ci", "section": "CI", "hidden": true },
    { "type": "chore", "section": "Chores", "hidden": true }
  ],
  "packages": {
    ".": {
      "component": "api",
      "package-name": "api",
      "version-file": "src/services/Identity/Identity.API/version.txt",
      "changelog-path": "src/services/Identity/Identity.API/CHANGELOG.md",
      "exclude-paths": ["src/Clients", "infra", "docs", ".github", ".cursor", "legacy"]
    },
    "src/Clients": {
      "component": "web",
      "package-name": "web",
      "exclude-paths": ["src/Clients/mobile"],
      "extra-files": [{ "type": "json", "path": "web/package.json", "jsonpath": "$.version" }]
    },
    "infra": {
      "component": "infra",
      "package-name": "infra"
    }
  }
}
```

`.release-please-manifest.json` przy pierwszym wdrożeniu:

```json
{ ".": "0.1.0", "src/Clients": "0.1.0", "infra": "0.1.0" }
```

- `bootstrap-sha` — commit, od którego release-please liczy historię. Bez niego pierwszy changelog zbierze wszystkie commity od początku repo, także te sprzed Conventional Commits. Po pierwszym scalonym Release PR wpis można usunąć.
- `bump-minor-pre-major` — przed `1.0.0` `feat!:` podbija `0.4.0` → `0.5.0`, a nie skacze do `1.0.0`. Wersję `1.0.0` ustawia się świadomie jednorazowym `"release-as": "1.0.0"` w komponencie.
- Typy ukryte nie wydają komponentu. PR `docs:` albo `ci:` nie otwiera Release PR.
- `src/services/Identity/Identity.API/version.txt` czyta [Directory.Build.props](../../Directory.Build.props):

```xml
<PropertyGroup Condition="Exists('$(MSBuildProjectDirectory)/version.txt')">
  <Version>$([System.IO.File]::ReadAllText('$(MSBuildProjectDirectory)/version.txt').Trim())</Version>
</PropertyGroup>
```

SDK dokleja SHA commita do `InformationalVersion` (`0.4.0+3f9c2e1…`). API podaje tę wartość jako `service.version` w zasobie OpenTelemetry, więc Grafana i Jaeger pokazują wersję obok nazwy usługi. Web czyta `version` z `package.json` przez `define` w `vite.config.ts` i pokazuje ją w stopce.

### 6. release.yml

```yaml
name: release

on:
  push:
    branches: [main]

permissions: {}

concurrency:
  group: release
  cancel-in-progress: false

jobs:
  release-please:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
      actions: write
    outputs:
      released: ${{ steps.rp.outputs.releases_created }}
    steps:
      - id: rp
        uses: googleapis/release-please-action@v4
        with:
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

      - name: Run required checks on the release PR
        if: steps.rp.outputs.prs_created == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          BRANCH: ${{ fromJSON(steps.rp.outputs.pr).headBranchName }}
          TITLE: ${{ fromJSON(steps.rp.outputs.pr).title }}
        run: |
          gh workflow run api.yml --repo "$REPO" --ref "$BRANCH"
          gh workflow run web.yml --repo "$REPO" --ref "$BRANCH"
          gh workflow run pr-title.yml --repo "$REPO" --ref "$BRANCH" -f title="$TITLE" -f branch="$BRANCH"

  gate:
    needs: release-please
    if: needs.release-please.outputs.released == 'true'
    runs-on: ubuntu-latest
    timeout-minutes: 75
    permissions:
      actions: write
      contents: read
    outputs:
      sha: ${{ steps.gate.outputs.sha }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Test deploy gate
        run: node --test infra/ci/deploy-gate.test.mjs

      - id: gate
        name: Require green CI for the release commit
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          HEAD_SHA: ${{ github.sha }}
        run: node infra/ci/deploy-gate.mjs

  deploy:
    needs: gate
    runs-on: [self-hosted, jjdevhub]
    environment:
      name: production
      url: https://hub.example.com
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    permissions:
      contents: read
    steps:
      - name: Deploy the release commit
        working-directory: /opt/jjdevhub
        env:
          DEPLOY_SHA: ${{ needs.gate.outputs.sha }}
        run: ./infra/ci/release-and-deploy.sh "$DEPLOY_SHA"
```

Dlaczego wszystko w jednym workflow: tag i GitHub Release tworzy release-please tokenem `GITHUB_TOKEN`, a zdarzenie z tego tokenu nie uruchamia innych workflowów. Osobny `deploy.yml` na `release: published` nigdy by nie wystartował. Ten sam przebieg, który utworzył wydanie, przechodzi więc do bramki i deployu.

Dlaczego krok „Run required checks on the release PR”: Release PR otwiera i aktualizuje `GITHUB_TOKEN`, więc `pull_request` na nim nie odpala, a ruleset z kroku 4 czeka na `api`, `web` i `pr-title`. `workflow_dispatch` jest wyjątkiem od reguły o tokenie. Uruchomiony na gałęzi Release PR raportuje checki na jej ostatnim commicie, czyli dokładnie tam, gdzie patrzy ruleset. Alternatywą jest token GitHub App albo PAT w sekretach — ten sposób nie potrzebuje żadnego sekretu.

`deploy-gate.mjs` zmienia tryb. Zamiast „workflow, które wywołało `workflow_run`, i te, których filtr pasuje”:

- wymaga `api` i `web` dla `HEAD_SHA`, bez filtra ścieżek, bo wydanie wdraża cały stan repo,
- brakujący przebieg uruchamia przez `POST /repos/{repo}/actions/workflows/{file}/dispatches` z `ref` równym tagowi wydania (pierwszy tag `*-v*` wskazujący `HEAD_SHA` z `GET /repos/{repo}/tags`); `ref` musi być nazwą, nie SHA, a tag wskazuje dokładnie ten commit, w przeciwieństwie do `main`, który mógł już pójść dalej,
- czeka (co 20 s, do 60 min) na zakończenie; czerwony przebieg albo przekroczenie czasu kończy job błędem,
- zapisuje `sha` w `GITHUB_OUTPUT`.

Commit scalenia Release PR zmienia `version.txt` i `CHANGELOG.md` komponentów, więc push zwykle sam uruchamia `api` albo `web` (ich filtr obejmuje `src/api/**` i `src/Clients/web/**`). Wydanie samego `infra` zmienia `infra/CHANGELOG.md`, którego żaden filtr nie łapie — wtedy bramka uruchamia oba przez `dispatch`.

`deploy-gate.test.mjs` dostaje przypadki trybu wydania z podstawionym klientem API: oba zielone → `sha`; brak `web` → jedno wywołanie `dispatches` z `ref` tagu, potem zielony → `sha`; czerwony `api` → błąd; brak tagu na `HEAD_SHA` → błąd; limit czasu → błąd.

Job `deploy` ma `environment: production`. Reguła środowiska z kroku 4 przepuszcza tylko `main`. W zakładce **Deployments** repo widać każde wdrożenie z tagiem, czasem i linkiem do `hub.example.com`. Environment może też dostać „Required reviewers” z właścicielem: wtedy wydanie czeka na kliknięcie „Approve”. Ten krok tego nie włącza, bo scalenie Release PR już jest świadomą decyzją.

### 7. release-and-deploy.sh

Zmiany w [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh):

- `git fetch origin main --tags` zamiast `git fetch origin main`,
- bez argumentu (cron) cel to ostatni tag wydania osiągalny z `main`: `git describe --tags --abbrev=0 --match '*-v*' origin/main`; brak tagu → `no release yet` i kod 0,
- znika tworzenie `release/YYYY-MM-DD.N` i `JJDEVHUB_PUSH_RELEASE`; skrypt robi `git checkout --detach "$remote_sha"`, a wdrożenie identyfikują tagi z `git tag --points-at "$remote_sha" --list '*-v*'`, wypisane w logu i zapisane do `/var/lib/jjdevhub/last-release-tags`,
- test „starszy commit nie cofa nowszego” zostaje, ale `JJDEVHUB_ALLOW_ROLLBACK=1` go pomija,
- reszta (lock, `compose up`, `wait_http`, zapis SHA) bez zmian.

Jednorazowo na VM, po pierwszym wdrożeniu nowym skryptem:

```bash
cd /opt/jjdevhub
git for-each-ref --format='%(refname:short)' 'refs/heads/release/*' | xargs -r git branch -D
```

[jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron) zmienia tylko komentarz: co godzinę wdraża najnowszy tag wydania, jeśli runner był offline w chwili wydania. Commit bez wydania nie trafia na produkcję także z crona.

[README.md](../../README.md) w obu częściach, sekcja „CI / CD”: deploy z wydania (`release.yml`), rollback przez `deploy.yml`, tagi `<komponent>-vX.Y.Z` zamiast gałęzi `release/YYYY-MM-DD.N` i `workflow_run`. Wiersz `/etc/jjdevhub/api.env` w tabeli sekretów traci zdanie o `release/*`.

### 8. deploy.yml do rollbacku

`deploy.yml` traci `workflow_run`:

```yaml
name: deploy

on:
  workflow_dispatch:
    inputs:
      tag:
        description: Release tag, e.g. api-v0.4.0
        required: true
        type: string
      rollback:
        description: Allow a commit older than the deployed one
        type: boolean
        default: false

permissions: {}

jobs:
  gate:
    runs-on: ubuntu-latest
    timeout-minutes: 75
    permissions:
      actions: write
      contents: read
    outputs:
      sha: ${{ steps.gate.outputs.sha }}
    steps:
      - uses: actions/checkout@v7
        with:
          persist-credentials: false
      - id: gate
        env:
          GH_TOKEN: ${{ github.token }}
          REPO: ${{ github.repository }}
          RELEASE_TAG: ${{ inputs.tag }}
        run: node infra/ci/deploy-gate.mjs

  deploy:
    needs: gate
    runs-on: [self-hosted, jjdevhub]
    environment:
      name: production
      url: https://hub.example.com
    concurrency:
      group: deploy-production
      cancel-in-progress: false
    permissions:
      contents: read
    steps:
      - working-directory: /opt/jjdevhub
        env:
          DEPLOY_SHA: ${{ needs.gate.outputs.sha }}
          JJDEVHUB_ALLOW_ROLLBACK: ${{ inputs.rollback && '1' || '0' }}
        run: ./infra/ci/release-and-deploy.sh "$DEPLOY_SHA"
```

`deploy-gate.mjs` z `RELEASE_TAG` sprawdza nazwę (`^[a-z0-9-]+-v\d+\.\d+\.\d+$`), zamienia tag na SHA przez `GET /repos/{repo}/commits/{tag}` i dalej działa jak w kroku 6. `concurrency` `deploy-production` jest wspólne z `release.yml`, więc rollback i wydanie nie biegną naraz.

```bash
gh workflow run deploy.yml -f tag=api-v0.3.0 -f rollback=true
```

### 9. Immutable Releases

**Settings → General → Releases → Enable release immutability.** Od tej chwili opublikowany GitHub Release:

- ma zablokowany tag (nie da się go przesunąć ani usunąć, dopóki wydanie istnieje, a po usunięciu wydania nazwy tagu nie da się użyć ponownie),
- ma zablokowane pliki wydania,
- dostaje od GitHuba atestację wydania (tag, commit, pliki), którą sprawdza `gh release verify`.

```bash
gh release verify api-v0.4.0 --repo jtjaskulski/JJDevHub
```

Tytuł i notatki wydania nadal da się edytować. release-please publikuje wydanie od razu (bez `draft`) i bez plików, więc ustawienie nie koliduje z jego przebiegiem. Changelog w `CHANGELOG.md` poprawia się w treści Release PR przed scaleniem, bo po scaleniu jest już w historii `main`.

### 10. Dependabot w tym samym formacie

W [dependabot.yml](../../.github/dependabot.yml) każdy ekosystem dostaje `commit-message`, a NuGet i npm grupy:

```yaml
  - package-ecosystem: nuget
    directory: "/"
    schedule:
      interval: weekly
      day: monday
    open-pull-requests-limit: 10
    commit-message:
      prefix: fix
      prefix-development: chore
      include: scope
    groups:
      nuget-minor-patch:
        update-types: [minor, patch]
```

| Ekosystem | `prefix` | Tytuł PR | Skutek po scaleniu |
| --- | --- | --- | --- |
| `nuget`, `npm` | `fix` (dev: `chore`) | `fix(deps): bump Npgsql from 9.0.3 to 9.0.4` | wydanie `api` albo `web` w wersji patch |
| `docker` | `fix` | `fix(deps): bump node from 22.17-alpine to 22.18-alpine` | wydanie `infra` albo `web` |
| `github-actions` | `ci` | `ci(deps): bump actions/checkout from 7.0.0 to 7.0.1` | bez wydania |

Poprawka bezpieczeństwa w paczce produkcyjnej dostaje więc wersję i trafia na produkcję przy najbliższym scaleniu Release PR. Grupa `minor`/`patch` łączy drobne bumpy w jeden PR tygodniowo. `major` przychodzi osobno, bo zwykle wymaga zmian w kodzie.

## Jak sprawdzić, że działa

```bash
gh api repos/jtjaskulski/JJDevHub/rulesets --jq '.[].name'
gh ruleset check main --repo jtjaskulski/JJDevHub
node --test infra/ci/pr-title.test.mjs infra/ci/deploy-gate.test.mjs
```

1. `git push origin HEAD:main` z laptopa kończy się `GH013: Repository rule violations found`.
2. PR z tytułem `Added search` ma czerwony `pr-title` z opisem błędu. Po zmianie tytułu na `feat(web): add search` check zmienia się na zielony bez nowego commita.
3. Na PR jest tylko przycisk **Squash and merge**.
4. Po scaleniu PR `feat: …` workflow `release` otwiera albo aktualizuje PR `chore: release main` z changelogiem i podbitą wersją. Na tym PR są zielone `api`, `web` i `pr-title` uruchomione przez `workflow_dispatch`.
5. PR `docs: …` po scaleniu nie zmienia Release PR.
6. Scalenie Release PR tworzy tagi i GitHub Release. W przebiegu `release` job `deploy` ma środowisko `production`, a zakładka **Deployments** pokazuje wdrożenie.
7. `gh release verify api-v0.2.0` kończy się sukcesem. `git push --delete origin api-v0.2.0` jest odrzucone.
8. `gh workflow run deploy.yml -f tag=api-v0.1.0 -f rollback=true` wdraża starszy commit; bez `rollback=true` skrypt kończy się `already deployed`.
9. `/var/log/jjdevhub-release.log` po godzinie pokazuje `already deployed` dla bieżącego tagu.

## Czego w tym pliku nie ruszać

- Nie zamieniaj `GITHUB_TOKEN` na PAT „żeby Release PR odpalał checki”. `workflow_dispatch` robi to bez sekretu.
- Nie wklejaj `${{ github.event.pull_request.title }}` ani `${{ github.head_ref }}` bezpośrednio w `run:`. Tylko przez `env`.
- Nie używaj `pull_request_target` w `pr-title.yml`. Check nie potrzebuje tokenu z zapisem.
- Nie włączaj merge commit ani rebase merge. Changelog zakłada jeden commit na PR.
- Nie edytuj `CHANGELOG.md` ani `version.txt` ręcznie i nie twórz tagów `*-v*` z laptopa. Wersjami zarządza release-please.
- Nie dodawaj `bypass_actors` do `main.json` „na wszelki wypadek”. Awaryjnie: `enforcement: "disabled"` w pliku i `apply-rulesets.sh`, co zostawia ślad w historii repo i w audit logu.
- Nie przywracaj `workflow_run` w `deploy.yml`. Deploy jest tylko z wydania.

## Następny numer

[12-sekrety.md](12-sekrety.md) — sekrety w gicie zaszyfrowane SOPS i age, klucz VM w vTPM, sekrety Compose zamiast `/etc/jjdevhub/api.env`.

---

## Pełny tutorial: gałęzie, wersje i wydania (od zera)

Wybór trunk-based, release-please i rulesetów jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają Conventional Commits, przebieg release-please i typowe pomyłki. Przepis plików jest wyżej.

### Conventional Commits i SemVer

Specyfikacja [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/): `typ(zakres)!: opis`, opcjonalna treść i stopka `BREAKING CHANGE: …`. Narzędzia wyciągają z tego wersję:

| Commit | Przed `1.0.0` (z `bump-minor-pre-major`) | Od `1.0.0` |
| --- | --- | --- |
| `fix: …` | `0.4.0` → `0.4.1` | `1.4.0` → `1.4.1` |
| `feat: …` | `0.4.0` → `0.5.0` | `1.4.0` → `1.5.0` |
| `feat!: …` albo stopka `BREAKING CHANGE:` | `0.4.0` → `0.5.0` | `1.4.0` → `2.0.0` |
| `docs:`, `ci:`, `chore:` | bez wydania | bez wydania |

[SemVer](https://semver.org/) mówi, że `0.y.z` to faza, w której wszystko może się zmienić. Przejście na `1.0.0` to obietnica stabilnego API publicznego, a nie nagroda za dojrzałość kodu.

Squash z tytułem PR przenosi wymaganie formatu z każdego commita na jeden tytuł. Lokalnie nie trzeba commitlinta ani hooka `commit-msg`: commit roboczy „fix test” na gałęzi nie trafi do historii `main`.

Przycisk **Revert** w GitHubie tworzy PR `Revert "feat: …"`, który nie przejdzie `pr-title`. Tytuł zmienia się ręcznie na `revert: feat: …`, a w opisie zostaje `This reverts commit <sha>.`.

### Jak działa release-please

Dwie fazy przy każdym pushu na `main`:

1. **release-pr** — dla każdego komponentu szuka ostatniego tagu `<komponent>-v*`, zbiera commity od niego, które dotykają ścieżki komponentu, i liczy nową wersję. Jeśli jest co wydać, tworzy albo aktualizuje Release PR: `version.txt`, `CHANGELOG.md`, `.release-please-manifest.json`, pliki z `extra-files`. Etykieta `autorelease: pending`.
2. **github-release** — jeśli push to scalenie Release PR (etykieta `autorelease: pending` na scalonym PR), tworzy tagi i GitHub Release dla wydanych komponentów i zmienia etykietę na `autorelease: tagged`.

Release PR jest miejscem przeglądu: widać, co wejdzie, jakie wersje i z jakim opisem. Można poprawić changelog, edytując treść PR, zanim się go scali. Kilka scaleń w ciągu dnia daje jedno wydanie.

Commit dotykający dwóch komponentów pojawia się w obu changelogach. Commit spoza wszystkich ścieżek (np. `docs/`) nie pojawia się nigdzie.

### Typowe pomyłki

1. **Required check `pr-title` bez `synchronize`.** Po kolejnym pushu check nie istnieje na nowym commicie i PR stoi.
2. **Wymagany check, którego nazwa nigdy się nie pojawiła.** GitHub nie podpowie go w regule, a PR czeka w nieskończoność. Najpierw jeden przebieg, potem ruleset.
3. **Release PR bez checków.** Brak kroku `workflow_dispatch`; ruleset blokuje scalenie Release PR.
4. **Pierwszy changelog z całą historią repo.** Brak `bootstrap-sha`.
5. **`feat!:` przed `1.0.0` daje `1.0.0`.** Brak `bump-minor-pre-major`.
6. **Bump NuGet nie wydaje API.** `Directory.Packages.props` poza ścieżką komponentu; dlatego `api` jest korzeniem z wykluczeniami.
7. **Deploy na `release: published`.** Nie startuje, bo wydanie utworzył `GITHUB_TOKEN`.
8. **Dispatch bramki na `main` zamiast na tag.** CI biegnie na nowszym commicie niż wydanie i zalicza nie ten SHA.
9. **Ręczny tag `api-v0.5.0` z laptopa.** release-please uzna go za ostatnie wydanie, a changelog i manifest się rozjadą.
10. **Usunięcie wydania, żeby „wydać jeszcze raz” pod tą samą wersją.** Przy Immutable Releases nazwa tagu po usuniętym wydaniu jest spalona. Poprawka to następna wersja patch.
11. **Tytuł z wielką literą (`feat: Add search`).** Changelog miesza style; `pr-title` odrzuca.
12. **Rollback bez `rollback=true`.** Skrypt widzi, że wdrożony commit jest nowszy, i kończy się `already deployed`.

### Oficjalne źródła

- [release-please: manifest releaser](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md) i [release-please-action](https://github.com/googleapis/release-please-action) — konfiguracja, wyjścia (`releases_created`, `prs_created`, `pr`, `paths_released`).
- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) i [SemVer 2.0.0](https://semver.org/).
- [About rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets) i [REST API: repository rules](https://docs.github.com/en/rest/repos/rules).
- [Triggering a workflow from a workflow](https://docs.github.com/en/actions/writing-workflows/choosing-when-your-workflow-runs/triggering-a-workflow#triggering-a-workflow-from-a-workflow) — reguła `GITHUB_TOKEN` i wyjątek `workflow_dispatch`.
- [Immutable releases](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases) i `gh release verify`.
- [Managing environments for deployment](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment).
- [Dependabot options: commit-message, groups](https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference).
- [Security hardening: script injection](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#understanding-the-risk-of-script-injections).
- [trunkbaseddevelopment.com](https://trunkbaseddevelopment.com/) i raporty [DORA](https://dora.dev/).

### Co zapamiętać

Jedna gałąź `main`, krótkie gałęzie z prefiksem, tylko squash, tytuł PR w formacie Conventional Commits pilnowany przez `pr-title`. release-please trzyma Release PR dla trzech komponentów (`api`, `web`, `infra`), a jego scalenie tworzy niezmienne tagi `<komponent>-vX.Y.Z` i wydania. Deploy biegnie w tym samym `release.yml`, po bramce, która w razie potrzeby sama uruchamia brakujące CI na tagu. `deploy.yml` służy do rollbacku. Reguły są w `.github/rulesets/` i obowiązują także właściciela. Żadnego nowego sekretu.
