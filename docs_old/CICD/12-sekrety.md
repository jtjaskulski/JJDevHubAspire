# Sekrety — SOPS i age w gicie, klucz w vTPM, sekrety Compose

## Po co

Dziś sekrety produkcji leżą w jednym pliku `/etc/jjdevhub/api.env` na VM ([01-proxmox.md](01-proxmox.md)): hasło Postgresa, klucz JWT, hasło admina Grafany. Plik nie ma historii ani kopii, a jego treść trafia do zmiennych środowiskowych kontenerów, więc widzi ją każdy, kto zrobi `docker inspect jjdevhub-api` albo przeczyta `/proc/<pid>/environ`. Nie wiadomo, które sekrety istnieją, kto je zna i kiedy były zmieniane.

Po tym kroku:

- Sekrety są w gicie, zaszyfrowane [SOPS](https://github.com/getsops/sops) z kluczami [age](https://age-encryption.org/). Klucze (nazwy zmiennych) są jawne, wartości zaszyfrowane, więc diff w PR pokazuje, *który* sekret się zmienił, ale nie *na co*.
- Odszyfrować mogą trzy klucze: YubiKey właściciela, klucz awaryjny na papierze i klucz VM produkcji. Klucz VM jest zapieczętowany w wirtualnym TPM Proxmoxa przez `systemd-creds` i nie leży na dysku jawnym tekstem.
- Na VM sekrety odszyfrowują się do tmpfs (`/run/jjdevhub/secrets/`), a kontenery dostają je jako pliki przez sekrety Compose. ASP.NET Core czyta je przez `AddKeyPerFile`. W `docker inspect` nie ma haseł.
- gitleaks w hooku `pre-commit` i w CI oraz push protection GitHuba zatrzymują jawny sekret, zanim trafi do historii.
- Każdy sekret ma wpis w inwentarzu: gdzie jest, kto go czyta, jak go zmienić.

Żaden sekret produkcji nie trafia do GitHuba. CI niczego nie odszyfrowuje.

## Dlaczego ta technologia

### SOPS i age zamiast pliku na dysku VM

SOPS szyfruje wartości w pliku dotenv (AES-256-GCM, osobno każdą wartość) i zostawia nazwy kluczy jawne. Klucz danych pliku jest zaszyfrowany dla listy odbiorców. Diff w PR pokazuje, który sekret się zmienił, bez wartości. age daje jeden wiersz klucza (`age1…`) i stałe algorytmy (X25519, ChaCha20-Poly1305). GPG przegrał: keyring, podklucze i wybór algorytmu łatwo zostawić w słabej konfiguracji. git-crypt przegrał: szyfruje cały plik, więc nie ma diffu na poziomie jednego klucza i trudno zdjąć odbiorcę. Menedżer haseł w chmurze przegrał, bo deploy zależy wtedy od cudzej usługi. Serwer z dynamicznymi poświadczeniami zostaje kierunkiem w [przyszlosc.md](przyszlosc.md), nie w tym numerze: to kolejny proces do utrzymania. Koszt: trzech odbiorców (YubiKey, klucz awaryjny, klucz VM) i `sops updatekeys` przy rotacji.

### vTPM zamiast pliku `age.key`

Plik `age.key` z `chmod 600` chroni przed innymi użytkownikami tej VM. Nie chroni przed kopią dysku. `systemd-creds encrypt --with-key=host+tpm2` szyfruje klucz kluczem maszyny i TPM. Plik `.cred` skopiowany na inną VM się nie odszyfruje. Koszt: kopia zapasowa całej VM zawiera też stan vTPM, więc kopie hosta Proxmoxa mają być szyfrowane osobno. Zmiana firmware (PCR 7) unieważnia `.cred` i klucz powstaje od nowa.

### Plik sekretu Compose zamiast zmiennej środowiskowej

Kontener dostaje sekret jako plik w `/run/secrets`, a ASP.NET Core czyta go przez `AddKeyPerFile`. Zmienna środowiskowa przegrała: widać ją w `docker inspect`, w `/proc/<pid>/environ` i w zrzucie środowiska. Dwanaście czynników z 2011 roku wybierało env, bo alternatywą był plik konfiguracyjny w repo. Plik montowany przez Compose rozdziela kod i konfigurację bez wystawiania wartości w metadanych kontenera. Koszt: prawa `0444` na pliku i `0700` na katalogu, bo proces w kontenerze nie jest rootem hosta.

## Co już jest w repo

- [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml): `db` (`POSTGRES_PASSWORD` z env), `api` (`ConnectionStrings__DefaultConnection` sklejony z env, `Jwt__Key`), `grafana` (`GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:?…}`).
- [infra/docker/.env.example](../../infra/docker/.env.example): wzór dla `infra/docker/.env` (lokalnie) i `/etc/jjdevhub/api.env` (VM).
- [release-and-deploy.sh](../../infra/ci/release-and-deploy.sh): `--env-file "${JJDEVHUB_ENV_FILE:-/etc/jjdevhub/api.env}"`.
- Sekrety GitHuba z [10-sonarqube.md](10-sonarqube.md): `SONAR_TOKEN_API`, `SONAR_TOKEN_WEB`, `SONAR_HOST_URL` na poziomie repo.
- Tunel z [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md): token w usłudze `cloudflared` zainstalowanej przez `cloudflared service install`.
- [11-branche-i-wydania.md](11-branche-i-wydania.md): `apply-rulesets.sh`, ruleset `main`, deploy z wydania.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie tu |
| --- | --- |
| SOPS | Narzędzie (CNCF), które szyfruje wartości w plikach YAML, JSON, dotenv i binarnych, zostawiając klucze jawne. Plik ma metadane: odbiorców i MAC całości. |
| age | Prosty format szyfrowania plików (X25519, ChaCha20-Poly1305). Klucz publiczny `age1…`, prywatny `AGE-SECRET-KEY-1…`. |
| odbiorca (recipient) | Klucz publiczny, dla którego SOPS szyfruje klucz danych pliku. Każdy odbiorca może odszyfrować plik sam. |
| klucz danych | Losowy klucz AES, którym SOPS szyfruje wartości. Zaszyfrowany osobno dla każdego odbiorcy. |
| `age-plugin-yubikey` | Wtyczka age: klucz prywatny w slocie PIV YubiKey, odszyfrowanie wymaga PIN-u i dotyku. |
| vTPM | Wirtualny moduł TPM 2.0, który Proxmox daje maszynie (`tpmstate0`). |
| `systemd-creds` | Narzędzie systemd: szyfruje plik kluczem hosta i TPM; odszyfrować może tylko usługa z `LoadCredentialEncrypted=` na tej maszynie. |
| tmpfs | System plików w RAM (`/run`). Znika po restarcie maszyny. |
| sekret Compose | `secrets:` w Compose: plik z hosta zamontowany w kontenerze pod `/run/secrets/<nazwa>`, zamiast wartości w env. |
| `AddKeyPerFile` | Dostawca konfiguracji .NET: nazwa pliku = klucz (`__` = `:`), treść = wartość. |
| push protection | Funkcja GitHuba: odrzuca `git push` z rozpoznanym tokenem (AWS, GitHub, Stripe i inne wzorce). |
| gitleaks | Skaner sekretów w gicie (reguły regex i entropia). |
| lefthook | Menedżer hooków gita w jednym pliku `lefthook.yml`. |

## Kroki

### 1. Narzędzia na laptopie właściciela

```bash
# Arch / CachyOS
sudo pacman -S sops age age-plugin-yubikey gitleaks lefthook
# Debian / Ubuntu: sops, age i gitleaks z wydań na GitHubie (sprawdź sumy sha256), lefthook z pakietu npm albo z wydań
sops --version && age --version && age-plugin-yubikey --version
```

Wersji nie trzeba przypinać między maszynami: SOPS 3.9+ i age 1.2+ czytają i piszą ten sam format.

### 2. Trzy klucze

**YubiKey właściciela** (codzienna praca):

```bash
age-plugin-yubikey --generate --slot 1 --pin-policy once --touch-policy always --name jjdevhub
age-plugin-yubikey --identity --slot 1 >> ~/.config/sops/age/keys.txt
age-plugin-yubikey --list
```

`--identity` zapisuje do `keys.txt` tylko odnośnik (`AGE-PLUGIN-YUBIKEY-1…`), nie klucz. Klucz prywatny nie opuszcza YubiKey. `--touch-policy always` wymaga dotknięcia przy każdym odszyfrowaniu, więc proces działający w tle na laptopie nie odczyta sekretów bez wiedzy właściciela.

**Klucz awaryjny** (zgubiony albo zepsuty YubiKey):

```bash
age-keygen -o recovery.key
grep 'public key' recovery.key
```

Treść `recovery.key` drukujesz albo zapisujesz w menedżerze haseł poza tą maszyną, potem `shred -u recovery.key`. Do repo trafia tylko klucz publiczny.

**Klucz VM produkcji** — w kroku 4, bezpośrednio na VM.

### 3. `.sops.yaml` i pliki w `infra/secrets/`

`.sops.yaml` w korzeniu repo:

```yaml
creation_rules:
  - path_regex: infra/secrets/runner\.sops\.env$
    age: >-
      age1yubikey1q…owner,
      age1…recovery,
      age1…vm-build
  - path_regex: infra/secrets/.*\.sops\.(env|pem)$
    age: >-
      age1yubikey1q…owner,
      age1…recovery,
      age1…vm-prod
    unencrypted_regex: ^(POSTGRES_USER|POSTGRES_DB|JWT_ISSUER|JWT_AUDIENCE)$
```

Pierwsza pasująca reguła wygrywa. Token runnera VM build z [18-ci-uslug.md](../api/18-ci-uslug.md) ma innego odbiorcę maszynowego niż produkcja: VM produkcji nie potrzebuje go znać. `unencrypted_regex` zostawia jawne wartości, które nie są tajne, a pomagają czytać plik.

Pliki tego kroku:

| Plik | Klucze | Kto czyta |
| --- | --- | --- |
| `infra/secrets/compose.sops.env` | `POSTGRES_PASSWORD`, `GRAFANA_ADMIN_PASSWORD` | kontenery `db`, `grafana` |
| `infra/secrets/api.sops.env` | `ConnectionStrings__DefaultConnection`, `Jwt__Key` | kontener `api` |

Utworzenie (YubiKey w porcie):

```bash
sops edit infra/secrets/compose.sops.env
sops edit infra/secrets/api.sops.env
```

`sops edit` otwiera `$EDITOR` na odszyfrowanej kopii w katalogu tymczasowym, a po zapisie szyfruje i usuwa kopię. Wartości bierzesz z obecnego `/etc/jjdevhub/api.env`. W gicie plik wygląda tak:

```text
ConnectionStrings__DefaultConnection=ENC[AES256_GCM,data:3m9…,iv:…,tag:…,type:str]
Jwt__Key=ENC[AES256_GCM,data:Qx…,iv:…,tag:…,type:str]
sops_age__list_0__map_recipient=age1yubikey1q…
…
sops_mac=ENC[AES256_GCM,data:…]
```

`sops_mac` obejmuje cały plik: podmiana jednej zaszyfrowanej wartości na inną (np. ze starszej wersji) psuje MAC i SOPS odmawia odszyfrowania.

`.gitignore` dostaje:

```gitignore
infra/secrets/*
!infra/secrets/*.sops.env
!infra/secrets/*.sops.pem
!infra/secrets/*.sh
!infra/secrets/*.service
*.age.key
recovery.key
```

W `infra/secrets/` w gicie są więc tylko pliki SOPS, skrypty (`decrypt.sh`, `rotate-postgres.sh`) i unit systemd. Odszyfrowanej kopii obok zaszyfrowanej (`api.env`) nie da się przypadkiem dodać do commita.

### 4. Klucz VM w vTPM

W Proxmoxie, przy wyłączonej VM: **Hardware → Add → TPM State**, wersja `v2.0`, ten sam storage co dysk. Po starcie VM:

```bash
systemd-creds has-tpm2
```

Wynik `yes` (albo `partial` z `+firmware +driver +system +subsystem`) znaczy, że TPM jest widoczny. Klucz age powstaje w pamięci i od razu idzie do `systemd-creds`, bez zapisu jawnego pliku:

```bash
sudo install -d -m 0700 /etc/jjdevhub
key="$(age-keygen 2>/dev/null)"
printf '%s\n' "$key" | sudo systemd-creds encrypt --with-key=host+tpm2 --name=age-key - /etc/jjdevhub/age.key.cred
printf '%s\n' "$key" | age-keygen -y
unset key
```

Ostatnia komenda wypisuje klucz publiczny `age1…`, który trafia do `.sops.yaml` jako `vm-prod`. Na laptopie:

```bash
sops updatekeys infra/secrets/compose.sops.env infra/secrets/api.sops.env
```

`updatekeys` odszyfrowuje klucz danych (YubiKey) i szyfruje go dla nowej listy odbiorców. Wartości się nie zmieniają.

`--with-key=host+tpm2` wymaga obu: klucza hosta z `/var/lib/systemd/credential.secret` i TPM tej VM. Sam dysk VM skopiowany gdzie indziej nie wystarczy, sam TPM też nie. Plik `.cred` można odczytać tylko na tej maszynie, z poziomu usługi systemd.

### 5. Odszyfrowanie do tmpfs

`/etc/systemd/system/jjdevhub-secrets.service`:

```ini
[Unit]
Description=Decrypt JJDevHub secrets to /run/jjdevhub/secrets
Before=docker.service
After=local-fs.target

[Service]
Type=oneshot
LoadCredentialEncrypted=age-key:/etc/jjdevhub/age.key.cred
RuntimeDirectory=jjdevhub/secrets
RuntimeDirectoryMode=0700
RuntimeDirectoryPreserve=yes
ExecStart=/opt/jjdevhub/infra/secrets/decrypt.sh

[Install]
WantedBy=multi-user.target
```

- `LoadCredentialEncrypted` odszyfrowuje `age.key.cred` do `$CREDENTIALS_DIRECTORY/age-key`, widocznego tylko dla tego procesu i usuwanego po jego zakończeniu.
- `RuntimeDirectory` tworzy `/run/jjdevhub/secrets` na tmpfs z prawami `0700` root. `RuntimeDirectoryPreserve=yes` zostawia katalog po zakończeniu usługi `oneshot`, więc każde `systemctl start` odszyfrowuje od nowa, a pliki przeżywają do restartu VM.
- `Before=docker.service` i `WantedBy=multi-user.target`: po restarcie VM pliki są na miejscu, zanim Docker podniesie kontenery z `restart: unless-stopped`.

[infra/secrets/decrypt.sh](../../infra/secrets/decrypt.sh) (nowy):

```bash
#!/usr/bin/env bash
set -euo pipefail

export SOPS_AGE_KEY_FILE="$CREDENTIALS_DIRECTORY/age-key"
src="$(dirname "$(readlink -f "$0")")"
out=/run/jjdevhub/secrets
umask 0222

for file in "$src"/*.sops.env; do
  name="$(basename "$file" .sops.env)"
  tmp="$(mktemp -d "$out/.$name.XXXXXX")"
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    printf '%s' "$value" > "$tmp/$key"
  done < <(sops decrypt --input-type dotenv --output-type dotenv "$file")
  chmod 0755 "$tmp"
  rm -rf "$out/$name"
  mv "$tmp" "$out/$name"
done

for file in "$src"/*.sops.pem; do
  [[ -e "$file" ]] || continue
  name="$(basename "$file" .sops.pem)"
  sops decrypt --input-type binary --output-type binary "$file" > "$out/$name.pem"
done

(cd "$out" && find . -type f ! -path './.*' | sed 's|^\./||' | sort) > /run/jjdevhub/secrets.list
```

Wynik: `/run/jjdevhub/secrets/compose/POSTGRES_PASSWORD`, `/run/jjdevhub/secrets/api/Jwt__Key` i tak dalej. Pliki mają `0444`, a katalog nadrzędny `0700` root. Użytkownik na hoście (także `deploy`) nie przejdzie przez katalog nadrzędny, a kontener i tak przeczyta plik: Docker montuje sam plik, więc prawa katalogu nadrzędnego na hoście w kontenerze nie obowiązują. `0444` jest potrzebne, bo procesy w kontenerach chodzą na własnych użytkownikach (`app` w obrazie .NET, `postgres`, `grafana`).

`read -r key value` z `IFS='='` dzieli wiersz na pierwszym `=`, więc connection string z `Password=…;` trafia do pliku w całości. Wartość nie przechodzi przez argumenty żadnego procesu.

`/run/jjdevhub/secrets.list` to same nazwy plików (`api/Jwt__Key`, `compose/POSTGRES_PASSWORD`), bez wartości, czytelne dla wszystkich. Skrypt deployu sprawdza na nim, czy każdy sekret jest na miejscu, bo do samego katalogu nie wejdzie.

Instalacja na VM:

```bash
sudo cp /opt/jjdevhub/infra/secrets/jjdevhub-secrets.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now jjdevhub-secrets.service
sudo ls -l /run/jjdevhub/secrets/api
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl start jjdevhub-secrets.service' | sudo tee /etc/sudoers.d/jjdevhub-secrets
sudo visudo -cf /etc/sudoers.d/jjdevhub-secrets
```

Użytkownik runnera może tylko uruchomić odszyfrowanie. Nie może przeczytać wyniku ani klucza.

### 6. Sekrety Compose i `docker-compose.prod.yml`

Compose interpoluje każdy plik przed scaleniem, więc `${GRAFANA_ADMIN_PASSWORD:?…}` z pliku bazowego musi dostać wartość także w produkcji. Dostaje znacznik z jawnego pliku, a plik `prod` usuwa go z env kontenera.

`infra/docker/prod.env` (w gicie, bez sekretów):

```dotenv
POSTGRES_USER=postgres
POSTGRES_DB=jjdevhub
ASPNETCORE_ENVIRONMENT=Production
POSTGRES_PASSWORD=__from_secret_file__
JWT_KEY=__from_secret_file__
GRAFANA_ADMIN_PASSWORD=__from_secret_file__
```

`infra/docker/docker-compose.prod.yml`:

```yaml
services:
  db:
    environment: !override
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
    secrets:
      - postgres_password

  api:
    environment: !override
      ASPNETCORE_ENVIRONMENT: Production
      Jwt__Issuer: ${JWT_ISSUER:-JJDevHub}
      Jwt__Audience: ${JWT_AUDIENCE:-JJDevHub}
      Jwt__ExpiryMinutes: ${JWT_EXPIRY_MINUTES:-60}
      OTEL_SERVICE_NAME: ${OTEL_SERVICE_NAME:-JJDevHub.Api}
      OTEL_EXPORTER_OTLP_ENDPOINT: http://jaeger:4317
      OTEL_EXPORTER_OTLP_PROTOCOL: grpc
    secrets:
      - source: api_connection
        target: ConnectionStrings__DefaultConnection
      - source: api_jwt_key
        target: Jwt__Key

  grafana:
    environment: !override
      GF_SECURITY_ADMIN_USER: ${GRAFANA_ADMIN_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD__FILE: /run/secrets/grafana_admin_password
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_SERVER_HTTP_PORT: "3000"
      GF_SERVER_ROOT_URL: ${GRAFANA_ROOT_URL:-https://grafana.jjdevhub.com/}
      GF_SERVER_DOMAIN: ${GRAFANA_DOMAIN:-grafana.jjdevhub.com}
    secrets:
      - grafana_admin_password

secrets:
  postgres_password:
    file: /run/jjdevhub/secrets/compose/POSTGRES_PASSWORD
  grafana_admin_password:
    file: /run/jjdevhub/secrets/compose/GRAFANA_ADMIN_PASSWORD
  api_connection:
    file: /run/jjdevhub/secrets/api/ConnectionStrings__DefaultConnection
  api_jwt_key:
    file: /run/jjdevhub/secrets/api/Jwt__Key
```

- `!override` zastępuje cały blok `environment` z pliku bazowego, zamiast go scalać. Bez tego znacznik `__from_secret_file__` i sklejony connection string zostałyby w env.
- Obrazy Postgresa (`POSTGRES_PASSWORD_FILE`) i Grafany (`GF_…__FILE`) same czytają wartość z pliku.
- Lokalnie nic się nie zmienia: `docker compose up` bez pliku `prod` dalej czyta `infra/docker/.env`.

W [Program.cs](../../src/api/Program.cs) API, zaraz po `WebApplication.CreateBuilder`:

```csharp
builder.Configuration.AddKeyPerFile(source =>
{
    source.FileProvider = Directory.Exists("/run/secrets") ? new PhysicalFileProvider("/run/secrets") : null;
    source.Optional = true;
    source.IgnoreCondition = name => name.EndsWith(".pem", StringComparison.Ordinal);
});
```

Pakiet `Microsoft.Extensions.Configuration.KeyPerFile` (MIT) w `Directory.Packages.props`. Plik `/run/secrets/ConnectionStrings__DefaultConnection` staje się kluczem `ConnectionStrings:DefaultConnection`. Dostawca jest dodany po zmiennych środowiskowych, więc plik wygrywa. `IgnoreCondition` pomija klucze PEM, które [15-identity.md](../api/15-identity.md) czyta po ścieżce, a nie jako wartość konfiguracji.

### 7. Deploy z sekretami

[release-and-deploy.sh](../../infra/ci/release-and-deploy.sh):

- zamiast `ENV_FILE=/etc/jjdevhub/api.env`: `sudo systemctl start jjdevhub-secrets.service`, potem sprawdzenie, że każdy plik z sekcji `secrets:` pliku `prod` (`docker compose … config --format json | jq -r '.secrets[].file'`, bez przedrostka `/run/jjdevhub/secrets/`) jest w `/run/jjdevhub/secrets.list`; brak pliku przerywa deploy przed `up`,
- `docker compose --env-file infra/docker/prod.env -f infra/docker/docker-compose.yml -f infra/docker/docker-compose.prod.yml up -d --build --wait --wait-timeout 180`,
- przed `up`: `docker compose … config` nie może zawierać `__from_secret_file__` w żadnym `environment` — test, że `!override` zadziałał.

Workflow się nie zmienia: `release.yml` woła skrypt jak w [11-branche-i-wydania.md](11-branche-i-wydania.md). Runner nie widzi wartości, bo skrypt ich nie czyta, a kontenery dostają pliki od demona Dockera.

Przejście:

1. PR z `infra/secrets/*.sops.env`, `.sops.yaml`, `decrypt.sh`, unitem, plikami Compose i zmianą skryptu.
2. Na VM: krok 4 i 5, zanim Release PR zostanie scalony.
3. Scalenie Release PR (`infra` i `api` dostają wydanie), deploy.
4. `docker inspect` z kroku „Jak sprawdzić”, potem `sudo shred -u /etc/jjdevhub/api.env`.

[01-proxmox.md](01-proxmox.md) i [jjdevhub-release.cron](../../infra/ci/jjdevhub-release.cron) przestają wspominać `api.env` przy wdrożeniu tego numeru. W [README.md](../../README.md), w obu częściach, tabela w sekcji „Secrets” / „Sekrety” dostaje wiersze `infra/secrets/*.sops.env` (w gicie, zaszyfrowane) i `/run/jjdevhub/secrets/` (tmpfs na VM) zamiast `/etc/jjdevhub/api.env`, z odnośnikiem do tego pliku.

### 8. Ochrona przed wyciekiem

**Hook lokalny.** `lefthook.yml` w korzeniu:

```yaml
pre-commit:
  parallel: true
  commands:
    gitleaks:
      run: gitleaks git --pre-commit --staged --redact --no-banner
    sops-encrypted:
      glob: "infra/secrets/*"
      run: ./infra/ci/check-sops.sh {staged_files}
```

```bash
lefthook install
```

`infra/ci/check-sops.sh` (nowy) dla każdego pliku woła `sops filestatus "$file" | jq -e '.encrypted'` i kończy się błędem, gdy plik w `infra/secrets/` (poza `*.sh` i `*.service`) nie jest zaszyfrowany. Hook jest wygodą: `git commit --no-verify` go omija, więc ta sama kontrola stoi w CI.

**CI.** `.github/workflows/secrets.yml`, job `secrets`, na `pull_request`, pushu na `main` i `workflow_dispatch`:

- `actions/checkout` z `fetch-depth: 0` i `persist-credentials: false`,
- instalacja gitleaks z wydania na GitHubie ze sprawdzeniem `sha256sum -c`, tak jak Trivy w [api.yml](../../.github/workflows/api.yml),
- `gitleaks git --redact --log-opts="${RANGE}"`, gdzie `RANGE` przychodzi przez `env`: na PR `base.sha..head.sha`, na pushu `before..sha`, przy `workflow_dispatch` `origin/main..HEAD`,
- `./infra/ci/check-sops.sh infra/secrets/*.sops.*`.

`secrets` dochodzi do wymaganych checków w `.github/rulesets/main.json`. Release PR otwiera `GITHUB_TOKEN`, więc `pull_request` na nim nie startuje: krok „Run required checks on the release PR” w `release.yml` z [11-branche-i-wydania.md](11-branche-i-wydania.md) dostaje czwartą linię `gh workflow run secrets.yml --repo "$REPO" --ref "$BRANCH"`. Akcja `gitleaks/gitleaks-action` nie jest potrzebna: binarka z sumą kontrolną wystarcza i nie wymaga licencji.

`.gitleaks.toml`:

```toml
[extend]
useDefault = true

[allowlist]
description = "SOPS ciphertext and documented placeholders"
paths = [
  '''infra/secrets/.*\.sops\.(env|pem)$''',
  '''infra/docker/\.env\.example$''',
  '''infra/docker/prod\.env$''',
]
```

**Push protection.** Dla repozytorium publicznego bezpłatne. `apply-rulesets.sh` z [11-branche-i-wydania.md](11-branche-i-wydania.md) dostaje:

```bash
gh api -X PATCH "repos/$repo" \
  -f 'security_and_analysis[secret_scanning][status]=enabled' \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled' >/dev/null
```

GitHub odrzuca wtedy `git push` z rozpoznanym tokenem dostawcy i pokazuje plik i wiersz. Obejście wymaga podania powodu i zostaje w logu alertów.

### 9. Sekrety GitHuba w environment `sonar`

Tokeny Sonara przechodzą z sekretów repo do environment `sonar` z regułą „tylko `main`”:

```bash
gh api -X PUT repos/jtjaskulski/JJDevHub/environments/sonar \
  --input - <<'JSON'
{ "deployment_branch_policy": { "protected_branches": false, "custom_branch_policies": true } }
JSON
gh api -X POST repos/jtjaskulski/JJDevHub/environments/sonar/deployment-branch-policies -f name=main -f type=branch
gh secret set SONAR_TOKEN_API --env sonar
gh secret set SONAR_TOKEN_WEB --env sonar
gh secret set SONAR_HOST_URL --env sonar
gh secret delete SONAR_TOKEN_API && gh secret delete SONAR_TOKEN_WEB && gh secret delete SONAR_HOST_URL
```

Joby `sonar-api` i `sonar-web` dostają `environment: sonar`. Workflow zmieniony na gałęzi PR (nawet przez kogoś z prawem zapisu) nie dostanie tokenu, bo environment wydaje sekrety tylko jobom z `main`. Wcześniej chronił je tylko warunek `if:` w samym workflow, który autor PR może zmienić. Tworzenie environment trafia do `apply-rulesets.sh` obok `production`.

### 10. Inwentarz

`docs/CICD/12-sekrety.md` jest inwentarzem: każdy nowy sekret dopisuje wiersz tutaj w tym samym PR, w którym się pojawia.

| Sekret | Gdzie leży | Kto czyta | Zmiana | Skutek zmiany |
| --- | --- | --- | --- | --- |
| `POSTGRES_PASSWORD` | `compose.sops.env` | `db` przy pierwszym starcie, `api` w connection stringu | raz w roku albo po wycieku | patrz „Rotacja” niżej |
| `ConnectionStrings__DefaultConnection` | `api.sops.env` | `api` | razem z hasłem Postgresa | restart `api` |
| `Jwt__Key` | `api.sops.env` | `api` (HMAC) | raz w roku albo po wycieku | wszystkie tokeny tracą ważność, użytkownicy logują się ponownie |
| `GRAFANA_ADMIN_PASSWORD` | `compose.sops.env` | `grafana` przy pierwszym starcie | po wycieku | Grafana trzyma hasło w bazie: `docker exec jjdevhub-grafana grafana cli admin reset-admin-password --password-from-stdin` |
| klucz age VM | `/etc/jjdevhub/age.key.cred` (TPM) | `jjdevhub-secrets.service` | przy odbudowie VM albo podejrzeniu | nowy klucz, `updatekeys`, rotacja wartości |
| YubiKey właściciela | slot PIV | `sops` na laptopie | przy utracie | klucz awaryjny, nowy YubiKey, `updatekeys` |
| klucz awaryjny | papier albo menedżer haseł, offline | właściciel | po każdym użyciu | nowy klucz, `updatekeys` |
| `SONAR_TOKEN_API`, `SONAR_TOKEN_WEB` | environment `sonar` | joby Sonara | co 90 dni (ważność tokenu w Sonarze) | `gh secret set --env sonar` |
| `SONAR_DB_PASSWORD` | `/opt/sonarqube/.env` ([10-sonarqube.md](10-sonarqube.md)) | baza Sonara | po wycieku | `ALTER ROLE sonar`, restart Compose Sonara |
| token tunelu Cloudflare | unit `cloudflared` ([02-cloudflare-tunnel.md](02-cloudflare-tunnel.md)) | `cloudflared` | po wycieku | **Zero Trust → Tunnels → Refresh token**, `cloudflared service install` z nowym |
| token rejestracji runnera | nigdzie (jednorazowy) | `config.sh` | — | — |
| `GITHUB_TOKEN` | wydawany na job | workflowy | automatycznie | — |

Numery `15` i `18` dopisują klucz podpisu Identity (`identity-signing.sops.pem`), pliki na usługę i token runnera VM build (`runner.sops.env`).

### 11. Rotacja

**Hasło Postgresa.** Zmienna `POSTGRES_PASSWORD` działa tylko przy inicjalizacji pustego wolumenu, więc zmiana pliku nie zmienia hasła w bazie.

1. `sops edit infra/secrets/compose.sops.env` i `sops edit infra/secrets/api.sops.env` — nowe hasło w obu (`openssl rand -base64 32`).
2. PR `chore(infra): rotate database password`, scalenie, scalenie Release PR. Deploy odszyfrowuje nowe pliki; `api` dostaje nowy connection string i nie połączy się, dopóki baza ma stare hasło. Smoke zatrzyma deploy i przywróci poprzedni stan.
3. Dlatego przed scaleniem Release PR, na VM: `sudo systemctl start jjdevhub-secrets.service`, potem `infra/secrets/rotate-postgres.sh` (nowy), który czyta nowe hasło z `/run/jjdevhub/secrets/compose/POSTGRES_PASSWORD` i wysyła `ALTER ROLE postgres PASSWORD …` do `psql` w kontenerze przez stdin. Stary kontener `api` ma otwarte połączenia i działa dalej; nowy połączy się z nowym hasłem.

**Klucz danych pliku.** `sops rotate -i infra/secrets/api.sops.env` losuje nowy klucz danych i szyfruje nim te same wartości. Robi się to po usunięciu odbiorcy: stary klucz danych mógł zostać w kopii, którą ten odbiorca odszyfrował.

**Usunięcie odbiorcy** (np. stara VM): usunięcie z `.sops.yaml`, `sops updatekeys`, `sops rotate -i`, a potem zmiana samych wartości. Odbiorca, który kiedyś mógł odszyfrować plik, mógł zachować wartości. Zmiana listy odbiorców chroni tylko przyszłe wersje.

**Wyciek.** Jawny sekret w commicie jest skompromitowany od chwili pusha, nawet jeśli commit zniknie: forki, cache, klony. Kolejność: unieważnienie albo zmiana u źródła, nowe wartości w SOPS, deploy, dopiero potem ewentualne czyszczenie historii.

## Jak sprawdzić, że działa

```bash
sops filestatus infra/secrets/api.sops.env
git show HEAD:infra/secrets/api.sops.env | grep -c 'ENC\['
```

Na VM:

```bash
systemctl status jjdevhub-secrets.service
sudo ls -l /run/jjdevhub/secrets/api
ls /run/jjdevhub/secrets 2>&1 | head -1
docker inspect jjdevhub-api --format '{{json .Config.Env}}' | grep -E 'Password=|Jwt__Key' || echo 'no secrets in env'
docker exec jjdevhub-api ls /run/secrets
docker compose --env-file infra/docker/prod.env -f infra/docker/docker-compose.yml -f infra/docker/docker-compose.prod.yml config | grep -c __from_secret_file__
```

1. `filestatus` zwraca `{"encrypted":true}`.
2. `ls /run/jjdevhub/secrets` jako `deploy` kończy się `Permission denied`.
3. `docker inspect` nie pokazuje haseł; `/run/secrets` w kontenerze ma `ConnectionStrings__DefaultConnection` i `Jwt__Key`.
4. Ostatnia komenda wypisuje `0`.
5. Po `sudo reboot` VM aplikacja wstaje bez ręcznej akcji.
6. `git commit` pliku z `AKIA…` albo `ghp_…` zatrzymuje hook. Ten sam plik wypchnięty z `--no-verify` zatrzymuje push protection, a gdyby przeszedł, czerwony jest check `secrets`.
7. Job `sonar-api` na pushu `main` widnieje z environment `sonar`; uruchomiony z gałęzi PR przez `workflow_dispatch` nie dostaje tokenu.

## Czego w tym pliku nie ruszać

- Nie dodawaj klucza age ani żadnego sekretu produkcji do sekretów GitHuba. CI niczego nie odszyfrowuje.
- Nie zapisuj odszyfrowanych plików poza `/run/jjdevhub/secrets` (tmpfs). Żadnych `api.env` obok repo.
- Nie przekazuj sekretów przez `environment:` w Compose produkcji ani przez argumenty komend (`--connection "$(cat …)"` na hoście widać w `ps`).
- Nie zmieniaj `--touch-policy always` na YubiKey „bo wygodniej”.
- Nie usuwaj odbiorcy awaryjnego z `.sops.yaml`.
- Nie dodawaj `--no-verify` do skryptów ani aliasów.
- Vault i OpenBao zostają w [przyszlosc.md](przyszlosc.md).

## Następny numer

[13-lancuch-dostaw.md](13-lancuch-dostaw.md) — akcje przypięte do SHA, zizmor, Scorecard, SBOM i atestacje obrazów sprawdzane przed deployem.

---

## Pełny tutorial: sekrety w repozytorium i na serwerze (od zera)

Wybór SOPS, age, vTPM i pliku sekretu jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostają trzy pytania o sekret, kształt zaszyfrowanego pliku i typowe pomyłki.

### Trzy pytania o każdy sekret

1. **Gdzie jest źródło prawdy?** Jedno miejsce, z historią. Plik na serwerze bez kopii to brak historii i jedna awaria dysku od utraty.
2. **Kto może go odczytać?** Ludzie, maszyny, procesy. Im mniej, tym lepiej, i każdy wpis na liście da się uzasadnić.
3. **Jak go zmienić?** Bez przestoju, z instrukcją, bez szukania, gdzie jeszcze jest skopiowany.

SOPS w gicie odpowiada na pierwsze (historia w gicie, review w PR), odbiorcy age na drugie (lista w `.sops.yaml`), a inwentarz z rotacją na trzecie.

### Jak SOPS szyfruje plik

```text
plik dotenv
  KEY_A=value-a          ──┐
  KEY_B=value-b          ──┤  AES-256-GCM, klucz danych (losowy, jeden na plik)
                           │  każda wartość osobno, z kluczem jako danymi uwierzytelnionymi
                           ▼
  KEY_A=ENC[AES256_GCM,data:…]
  KEY_B=ENC[AES256_GCM,data:…]
  sops_age__list_0__map_enc = klucz danych zaszyfrowany dla odbiorcy 1 (YubiKey)
  sops_age__list_1__map_enc = … dla odbiorcy 2 (awaryjny)
  sops_age__list_2__map_enc = … dla odbiorcy 3 (VM)
  sops_mac = MAC całego pliku
```

Klucz zmiennej jest danymi uwierzytelnionymi wartości: zaszyfrowanej wartości `Jwt__Key` nie da się przenieść pod `POSTGRES_PASSWORD`. MAC obejmuje wszystkie wartości, więc nie da się też podmienić jednej na starszą.

Diff w PR pokazuje zmieniony wiersz `Jwt__Key=ENC[…]` i nowy `sops_mac`. Recenzent wie, który sekret się zmienił, bez dostępu do wartości.

### Sekrety w CI

Najlepszy sekret w CI to taki, którego nie ma. Ten układ trzyma w GitHubie tylko tokeny Sonara, które dotyczą narzędzia jakości, nie produkcji. Deploy nie potrzebuje sekretów, bo biegnie na VM, która sama odszyfrowuje pliki.

Gdy sekret w CI jest konieczny:

- environment z regułą gałęzi zamiast sekretu repo,
- OIDC (`id-token: write`) zamiast długowiecznego klucza tam, gdzie dostawca to obsługuje (chmury, rejestry, Sigstore w [13-lancuch-dostaw.md](13-lancuch-dostaw.md)),
- nigdy w jobie uruchamianym przez `pull_request_target` z checkoutem kodu PR.

### Typowe pomyłki

1. **`sops -e` na pliku, a potem `git add` jawnej kopii.** `.gitignore` z kroku 3 i `check-sops.sh` łapią oba przypadki.
2. **Brak odbiorcy awaryjnego.** Zgubiony YubiKey i odbudowana VM to sekrety nie do odzyskania.
3. **Zmiana `POSTGRES_PASSWORD` w pliku i oczekiwanie, że baza ją przejmie.** Obraz czyta ją tylko przy pustym wolumenie; potrzebne `ALTER ROLE`.
4. **To samo z Grafaną.** `GF_SECURITY_ADMIN_PASSWORD` działa przy pierwszym starcie; później `grafana cli admin reset-admin-password`.
5. **`environment:` scalone zamiast zastąpione.** Bez `!override` hasło z pliku bazowego zostaje w env obok pliku sekretu.
6. **Pliki `0400` root i kontener bez dostępu.** Proces w kontenerze ma innego użytkownika; prawa `0444` i katalog nadrzędny `0700` dają oba efekty naraz.
7. **`systemctl start` na usłudze `oneshot` z `RemainAfterExit=yes`.** Druga komenda nic nie robi, a nowe sekrety z wydania się nie odszyfrowują. Unit z kroku 5 nie ma `RemainAfterExit`.
8. **Sekret w argumencie komendy.** `psql -c "ALTER ROLE … PASSWORD 'x'"` na hoście widać w `ps` i w historii powłoki. Wartość idzie przez stdin.
9. **Usunięcie odbiorcy bez rotacji wartości.** Odbiorca mógł zachować odszyfrowane wartości.
10. **gitleaks bez allowlisty dla SOPS.** Zaszyfrowane wartości mają wysoką entropię i wyglądają jak sekrety.
11. **„Usunąłem commit, więc sekret jest bezpieczny”.** Nie jest. Najpierw rotacja.
12. **Nowy wymagany check bez `workflow_dispatch`.** Release PR czeka na `secrets` w nieskończoność, bo `pull_request` od `GITHUB_TOKEN` nie startuje. Każdy wymagany check ma `workflow_dispatch` i linię w kroku dispatch `release.yml`.

### Oficjalne źródła

- [SOPS](https://getsops.io/docs/) — `.sops.yaml`, `creation_rules`, `unencrypted_regex`, `updatekeys`, `rotate`, `filestatus`.
- [age](https://age-encryption.org/v1) i [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey).
- [systemd-creds](https://www.freedesktop.org/software/systemd/man/latest/systemd-creds.html) i [System and Service Credentials](https://systemd.io/CREDENTIALS/) — `LoadCredentialEncrypted`, `--with-key=host+tpm2`.
- [Proxmox VE: TPM](https://pve.proxmox.com/wiki/Manual:_qm.conf) — `tpmstate0`.
- [Compose: secrets](https://docs.docker.com/compose/how-tos/use-secrets/) i [merge: `!override`, `!reset`](https://docs.docker.com/reference/compose-file/merge/).
- [Key-per-file configuration provider](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/configuration/#key-per-file-configuration-provider).
- [Postgres image: Docker secrets](https://hub.docker.com/_/postgres) (`POSTGRES_PASSWORD_FILE`) i [Grafana: configure with `__FILE`](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#override-configuration-with-environment-variables).
- [gitleaks](https://github.com/gitleaks/gitleaks) i [lefthook](https://lefthook.dev/).
- [GitHub push protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection) i [environments: deployment protection rules](https://docs.github.com/en/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment).
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html).

### Co zapamiętać

Sekrety są w `infra/secrets/*.sops.env`, zaszyfrowane dla YubiKey właściciela, klucza awaryjnego i klucza VM. Klucz VM jest w vTPM przez `systemd-creds`, a `jjdevhub-secrets.service` odszyfrowuje pliki do tmpfs przy starcie VM i przed każdym deployem. Kontenery dostają pliki przez sekrety Compose, API czyta je przez `AddKeyPerFile`, a w env nie ma haseł. gitleaks, `check-sops.sh` i push protection zatrzymują jawny sekret. Inwentarz w tym pliku mówi, co istnieje i jak to zmienić.
