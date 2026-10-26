# GitHub — deploy na VM

Push na `main` ma przebudować Compose na VM z [01-proxmox.md](01-proxmox.md). Aplikacja jest wtedy dostępna tunelem z [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).

## Po co

Workflowy `api` i `web` już budują i testują. Brakuje mechanizmu, który ten sam commit postawi na maszynie z `/etc/jjdevhub/api.env`. Bez tego zielone CI nie zmienia tego, co widać przez tunel.

## Dlaczego ta technologia

### Self-hosted runner zamiast `ubuntu-latest`

Runner GitHub Actions stoi na tej samej VM co Compose, z etykietą `jjdevhub`. Sam wychodzi do GitHuba, więc do domu nie wchodzi webhook. Hosted runner `ubuntu-latest` przegrał: nie ma `/etc/jjdevhub/api.env`, nie widzi Dockera na Proxmoxie i budowałby obrazy gdzie indziej niż one działają. Webhook HTTP na VM przegrał: wymaga otwartego portu albo osobnej trasy tunelu i sekretu. Koszt: runner musi być online w chwili sukcesu CI, a usługa chodzi na użytkowniku deployu, nie na root, żeby `docker` i `git` w `/opt/jjdevhub` były te same co przy ręcznym Compose. Poleceń pobrania archiwum runnera nie ma w tym pliku — wersja zmienia się w panelu.

### Cron jako zapas

[infra/ci/jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron) i [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) co godzinę dociągają `origin/main`, gdy runner leży. Sam cron przegrał jako jedyna ścieżka: czeka do 59 minut i wstaje nawet, gdy `api` albo `web` jest czerwony. Deploy po zielonym CI idzie z [.github/workflows/deploy.yml](../../.github/workflows/deploy.yml) dla tego SHA. Koszt: dwa wejścia do tego samego skryptu biorą `flock` na `/var/lib/jjdevhub/deploy.lock`, inaczej cron i runner zrobią `git checkout` naraz.

## Co już jest w repo

Dwa workflowy tylko budują i testują, bez sekretów produkcyjnych:

- [`.github/workflows/api.yml`](../../.github/workflows/api.yml) — smoke Jaegera i Grafany ([observability-smoke.sh](../../infra/ci/observability-smoke.sh)), potem restore, build, test i `docker build` API
- [`.github/workflows/web.yml`](../../.github/workflows/web.yml) — `pnpm` test/build i obraz Reacta

Oba startują na każdym pull requeście, bez filtra `paths` na `pull_request`. Push na `main` nadal ma filtr ścieżek: commit, który nie tyka API, nie uruchomi `api`. To samo dotyczy `web`. Pominięty workflow na pushu nie jest wiszącym checkiem na PR.

Cron co godzinę, jeśli `origin/main` zmienił SHA:

- [infra/ci/jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron)
- [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh)

Skrypt robi `git fetch origin main`, przy nowym SHA tworzy lokalną gałąź `release/YYYY-MM-DD.N` i `docker compose up -d --build --wait --wait-timeout 180` z `--env-file /etc/jjdevhub/api.env`. Potem z hosta wymaga `http://127.0.0.1:5080/health` i `http://127.0.0.1:16686/`. Obraz Jaegera nie ma shella, więc sam `--wait` widzi tylko, że proces wstał. SHA w `/var/lib/jjdevhub/last-release-sha` zapisuje się dopiero, gdy te sprawdzenia wrócą 0. Kontener w pętli restartu nie jest wtedy „wdrożony”.

Ograniczenia crona: deploy czeka do 59 minut i poleci nawet, gdy `api` albo `web` na GitHubie jest czerwony.

## 1. Branch protection

GitHub → **Settings** → **Branches** → reguła dla `main`:

- **Require a pull request before merging**
- **Require status checks to pass**: `api` i `web`

Oba checki lecą na każdym PR, więc oba można wymagać od razu, gdy nazwa pojawi się na liście (GitHub dopisuje ją po pierwszym uruchomieniu workflowu). Wcześniejszy zielony run innego SHA nowego PR nie zalicza. Push na `main` nadal może pominąć workflow, którego diff nie trafia w `paths`. To pominięcie nie zostawia wiszącego required checka na pull requeście.

## 2. Runner na VM

GitHub → **Settings** → **Actions** → **Runners** → **New self-hosted runner**. System: Linux, architektura x64. Skopiuj stamtąd `mkdir`, `curl` i `tar` — wersja archiwum zmienia się w panelu, nie trzymaj jej w tym pliku.

Na VM jako ten sam użytkownik, który jest w grupie `docker` i właścicielem `/opt/jjdevhub`:

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# wklej polecenia Download i tar z panelu GitHuba
./config.sh --url https://github.com/jtjaskulski/JJDevHub --token TOKEN_Z_PANELU --labels jjdevhub --name jjdevhub
sudo ./svc.sh install "$USER"
sudo ./svc.sh start
```

Token z kreatora jest jednorazowy. Etykieta `jjdevhub` jest tą, której użyje przyszły workflow. Usługa ma chodzić na użytkowniku deployu, nie na root, żeby `docker` i `git` w `/opt/jjdevhub` były te same co przy ręcznym `compose`.

Sprawdzenie: runner w panelu ma status **Idle**.

## 3. Docelowy workflow (historyczne)

Nie wykonuj tej sekcji. `deploy.yml` już jest. Szkic poniżej woła skrypt bez SHA i jest nieaktualny. Aktualne wywołanie jest w [Historii zmian](#po-dodaniu-ścieżki-sha).

Zapis sprzed pliku, zostawiony bez zmian w treści szkicu:

- trigger `workflow_run` po **ukończonym sukcesem** workflow `api` i `web`, tylko dla `main`
- `runs-on: [self-hosted, jjdevhub]`
- job na VM woła deploy tego SHA, które przeszło CI — nie czeka na cron

`workflow_run` czyta definicję z domyślnej gałęzi (`main`). Runner musi być online w momencie sukcesu CI.

Planowane wtedy rozdzielenie [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh):

- cron dalej sam sprawdza, czy `origin/main` się ruszył
- osobna ścieżka robi `compose up` dla SHA podanego przez runner

Oba mechanizmy czytają `/var/lib/jjdevhub/last-release-sha`. Drugi nie przebudowuje tego samego SHA (`already deployed` w obecnym skrypcie).

Szkic historyczny, bez argumentu SHA. Nie wklejaj go:

```yaml
name: deploy

on:
  workflow_run:
    workflows: [api, web]
    types: [completed]
    branches: [main]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: [self-hosted, jjdevhub]
    steps:
      - name: Deploy SHA that passed CI
        run: /opt/jjdevhub/infra/ci/release-and-deploy.sh
```

To zdanie jest historyczne: wtedy ścieżki SHA nie było i szkic deployowałby czubek `main`. Teraz skrypt przyjmuje SHA — patrz [Po dodaniu ścieżki SHA](#po-dodaniu-ścieżki-sha).

## 4. Cron jako zapas

Gdy runner leży, godzinny wpis i tak dociągnie `main`. `/etc/jjdevhub/api.env` i `/var/lib/jjdevhub` są już z [proxmox.md](01-proxmox.md). Wpis crona dodaj jako użytkownik z grupy `docker`:

```bash
crontab -e
```

Wklej linię z [infra/ci/jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron):

```cron
0 * * * * cd /opt/jjdevhub && JJDEVHUB_ENV_FILE=/etc/jjdevhub/api.env /opt/jjdevhub/infra/ci/release-and-deploy.sh >> /var/log/jjdevhub-release.log 2>&1
```

Log:

```bash
sudo touch /var/log/jjdevhub-release.log
sudo chown "$USER:$USER" /var/log/jjdevhub-release.log
```

`JJDEVHUB_PUSH_RELEASE` zostaw `0`. Gałąź `release/*` jest lokalna na VM. Ustaw `1` tylko wtedy, gdy remote key ma prawo push.

Ręczny przebieg (nic nie zrobi, jeśli SHA się nie zmienił):

```bash
cd /opt/jjdevhub
JJDEVHUB_ENV_FILE=/etc/jjdevhub/api.env ./infra/ci/release-and-deploy.sh
```

## Czego nie robić

- Webhook HTTP na VM (potrzebny otwarty port albo osobna trasa tunelu i sekret).
- Job deploy na `ubuntu-latest`.
- Sekretów (`JWT_KEY`, hasło Postgresa, token tunelu, token runnera) w repo albo w GitHub Actions secrets po to, żeby hosted runner stawiał produkcję.

## Historia zmian

Dopisuj tu kolejny stan. Sekcji wyżej nie przerabiaj.

### Zanim był `deploy.yml`

Skrypt [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) po `git fetch origin main` zawsze brał aktualny `origin/main`. Przy nowym SHA tworzył `release/YYYY-MM-DD.N` i robił `docker compose up -d --build`. Stan lądował w `/var/lib/jjdevhub/last-release-sha`. Nie było argumentu SHA: zielone CI API bez zmian na `main` i tak zdeployowałoby czubek `main`.

Pliku `.github/workflows/deploy.yml` nie było. Docelowy kształt, zapisany wtedy jako szkic do następnego kroku:

- trigger `workflow_run` po sukcesie `api` i `web`, tylko dla `main`
- `runs-on: [self-hosted, jjdevhub]`
- job woła ten sam skrypt, bez SHA

```yaml
name: deploy

on:
  workflow_run:
    workflows: [api, web]
    types: [completed]
    branches: [main]

jobs:
  deploy:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: [self-hosted, jjdevhub]
    steps:
      - name: Deploy SHA that passed CI
        run: /opt/jjdevhub/infra/ci/release-and-deploy.sh
```

Cron zostawał zapasem na tym samym pliku stanu.

### Po dodaniu ścieżki SHA

Doszedł [.github/workflows/deploy.yml](../../.github/workflows/deploy.yml). Job `gate` startuje tylko przy `conclusion == success`, `head_branch == main` i evencie `push` albo `workflow_dispatch`. Deploy woła skrypt z `workflow_run.head_sha`.

Skrypt dostał opcjonalny argument. Bez niego cron dalej bierze `origin/main`. Z argumentem deployuje ten commit, po `git fetch` i `git cat-file -e`. Jeśli zapisany SHA jest tym samym commitem albo już go zawiera (`git merge-base --is-ancestor`), skrypt kończy się `already deployed` i nie robi checkoutu. Drugi zielony workflow tego samego pusha nie przebudowuje obrazów, a wolniejsze CI starszego commita nie cofa nowszego deployu.

Job na runnerze, z `/opt/jjdevhub`:

```bash
./infra/ci/release-and-deploy.sh "$DEPLOY_SHA"
```

`DEPLOY_SHA` to `workflow_run.head_sha`. Job `gate` puszcza deploy dopiero, gdy każdy workflow wymagany przez ten commit ma zielony run tego samego SHA: wymagany jest ten, którego `on.push.paths` trafia w diff wobec pierwszego rodzica, plus workflow, który właśnie się skończył. Sam `api` nie wdraża, gdy `web` dla tego SHA jeszcze leci albo spadł; `web` pominięty filtrem nie blokuje. Drugi zielony przebieg i tak kończy się przez plik stanu. Katalog `/opt/jjdevhub` ma być czysty. Po zmergowaniu na `main` raz `git pull` na VM, zanim pierwszy `workflow_run` wywoła skrypt.

### Blokada crona i runnera

Sam plik stanu nie serializuje dwóch procesów. Jeśli cron i `workflow_run` wejdą w skrypt zanim którykolwiek zrobi `printf` na końcu, oba przechodzą sprawdzenie i naraz robią `git checkout` oraz `docker compose` w `/opt/jjdevhub`.

Skrypt bierze `flock` na `/var/lib/jjdevhub/deploy.lock` (`JJDEVHUB_LOCK_FILE`) zanim zrobi `git fetch`, i trzyma go do końca procesu: sprawdzenie stanu, checkout, Compose i zapis SHA. Drugie wywołanie czeka. Deskryptor zamyka się przy wyjściu, także przy `already deployed`.

### Wydanie z tagu

Ochrona `main` jest w [.github/rulesets/main.json](../../.github/rulesets/main.json), nakładana przez [infra/ci/apply-rulesets.sh](../../infra/ci/apply-rulesets.sh). Tagów wydania pilnuje [.github/rulesets/release-tags.json](../../.github/rulesets/release-tags.json).

[.github/workflows/deploy.yml](../../.github/workflows/deploy.yml) nie startuje po `workflow_run`. Deploy idzie z [.github/workflows/release.yml](../../.github/workflows/release.yml) po scaleniu Release PR, albo ręcznie z tagu `<komponent>-vX.Y.Z`. Skrypt [infra/ci/release-and-deploy.sh](../../infra/ci/release-and-deploy.sh) robi `git checkout --detach` na commicie tagu i zapisuje tagi w `/var/lib/jjdevhub/last-release-tags`. `JJDEVHUB_ALLOW_ROLLBACK=1` pozwala wdrożyć starszy commit.
