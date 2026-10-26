# Proxmox — VM pod JJDevHub

Aplikacja zostaje na Twoim komputerze. Ten dokument stawia osobną maszynę wirtualną, Dockera i pierwszy `docker compose up`. Publikacja w internecie jest w [cloudflare-tunnel.md](02-cloudflare-tunnel.md). Deploy po pushu na `main` jest w [github.md](03-github.md).

Gałąź w repo to `main`. Stack to Postgres 16, API .NET i React za nginx — plik [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml).

## Po co

Laptop zostaje maszyną do pracy. Serwer ma być osobną maszyną, na której stoi Docker i pierwszy `docker compose up` z [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml). Bez tej maszyny tunel i deploy nie mają gdzie wylądować.

## Dlaczego ta technologia

### Proxmox i zwykła VM zamiast LXC

Proxmox stawia maszynę wirtualną na własnym hoście. VM ma własny kernel, więc Docker Engine działa tak samo jak na fizycznym serwerze. Kontener LXC na Proxmoxie musiałby zagnieżdżać Dockera: nesting i cgroup przy tym układzie bywają niestabilne, a dysk i sieć dzielą kernel hosta. Koszt to 4 GB RAM, 40 GB dysku i osobny system do aktualizacji. Publiczne IP nie jest potrzebne — tunel z następnego numeru wychodzi z VM na zewnątrz.

### Docker Engine i plugin Compose

Stack jest opisany w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml). Oficjalny Docker Engine z pluginem `docker compose` buduje obrazy API i weba na VM i trzyma Postgresa, API i nginx w jednym projekcie. Stary pakiet `docker-compose` (v1, Python) przegrał: nie jest już utrzymywany i nie czyta tego samego formatu co plugin v2. Kubernetes na jednej VM przegrał, bo dokładają się etcd, ingress i osobny sposób sekretów, a dziś wystarcza jeden plik Compose. Koszt: obrazy budują się na VM, pierwszy build trwa kilka minut, a użytkownik deployu musi być w grupie `docker`.

## 1. ISO

Na hoście Proxmox pobierz obraz:

- Debian 12 (bookworm), albo
- Ubuntu Server 24.04 LTS.

W panelu: **local (pve)** → **ISO Images** → **Download from URL** albo wgraj plik ręcznie.

## 2. Nowa VM

**Create VM**. Ustawienia, które mają znaczenie:

| Krok | Wartość |
| --- | --- |
| General | nazwa `jjdevhub`, bez startu po utworzeniu dopóki nie przejdziesz kreatora |
| OS | pobrane ISO, Guest OS Linux |
| System | BIOS domyślny (SeaBIOS wystarcza), Qemu Agent: włącz |
| Disks | 40 GB, Bus **VirtIO SCSI**, cache domyślny, Discard włączone |
| CPU | 2 cores, type `host` jeśli klaster ma jeden węzeł |
| Memory | 4096 MB, Ballooning wyłączone |
| Network | most `vmbr0` (albo Twój most LAN), Model **VirtIO** |

VM może być za NAT routera. Publiczne IP i przekierowanie portów nie są potrzebne — tunel Cloudflare łączy się outbound.

Wystartuj VM, zainstaluj system (OpenSSH server: tak). Utwórz użytkownika, np. `deploy`. Po instalacji odmontuj ISO (**Hardware** → CD-ROM → **Do not use any media**) i zrestartuj.

## 3. System na VM

Zaloguj się po SSH.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git qemu-guest-agent
sudo systemctl enable --now qemu-guest-agent
```

## 4. Docker Engine i Compose

Oficjalne repozytorium Dockera (plugin `docker compose`, nie stary pakiet `docker-compose`):

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL "https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg" -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

. /etc/os-release
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/${ID}
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Wyloguj się i zaloguj ponownie, żeby grupa `docker` zadziałała. Sprawdzenie:

```bash
docker compose version
```

## 5. Klon repo

Katalog `/opt/jjdevhub`. Deploy key albo HTTPS — konto na VM potrzebuje odczytu `origin`. Zapis do GitHuba jest zbędny, dopóki nie ustawisz `JJDEVHUB_PUSH_RELEASE=1` (patrz [github.md](03-github.md)).

Deploy key (read-only), na VM jako użytkownik, który będzie robił deploy:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/jjdevhub_deploy -N ""
cat ~/.ssh/jjdevhub_deploy.pub
```

Klucz publiczny: GitHub → repo **Settings** → **Deploy keys** → **Add deploy key**. Bez **Allow write access**.

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
  IdentityFile ~/.ssh/jjdevhub_deploy
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config

sudo mkdir -p /opt/jjdevhub
sudo chown "$USER:$USER" /opt/jjdevhub
git clone git@github.com:jtjaskulski/JJDevHub.git /opt/jjdevhub
cd /opt/jjdevhub
git checkout main
```

HTTPS zamiast klucza: `git clone https://github.com/jtjaskulski/JJDevHub.git /opt/jjdevhub`.

## 6. Sekrety poza klonem

Hasła nie wchodzą do gita. Wzorzec jest w [infra/docker/.env.example](../../infra/docker/.env.example). Na serwerze plik żyje w `/etc/jjdevhub/api.env` i przeżywa `git checkout` gałęzi `release/*`.

```bash
sudo install -d -o root -g docker -m 750 /etc/jjdevhub
sudo install -d -o "$USER" -g "$USER" -m 700 /var/lib/jjdevhub
sudo cp /opt/jjdevhub/infra/docker/.env.example /etc/jjdevhub/api.env
sudo chown root:docker /etc/jjdevhub/api.env
sudo chmod 640 /etc/jjdevhub/api.env
openssl rand -base64 48
sudoedit /etc/jjdevhub/api.env
```

Wpis z `openssl` wklej jako `JWT_KEY` (co najmniej 32 znaki). Reszta:

- `POSTGRES_PASSWORD` — własne hasło, nie `change-me`
- `ASPNETCORE_ENVIRONMENT=Production` (Development włącza `/openapi`)
- `POSTGRES_USER`, `POSTGRES_DB`, `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_EXPIRY_MINUTES` mogą zostać z przykładu

Katalog i plik są roota, grupa `docker` ma odczyt. Samo `chmod 600` przy właścicielu root zablokowałoby `docker compose` z konta deploy. Plik zostaje poza klonem, więc `git checkout` gałęzi `release/*` go nie rusza.

## 7. Postgres tylko na hoście

Kontener `db` w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) publikuje port tylko na loopbacku VM:

```yaml
ports:
  - "127.0.0.1:5433:5432"
```

Z samej VM `localhost:5433` działa. Z LAN-u port nie jest widoczny. API w Compose i tak łączy się po nazwie usługi `db`, nie przez ten port. Tunel z następnego dokumentu `5433` nie publikuje.

## 8. Pierwszy start

Jako użytkownik z grupy `docker`, z katalogu klonu:

```bash
cd /opt/jjdevhub
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml up -d --build
```

Obrazy budują się na VM (API z [infra/docker/Dockerfile](../../infra/docker/Dockerfile), web z [src/Clients/web/Dockerfile](../../src/Clients/web/Dockerfile)). Pierwszy build trwa kilka minut.

Sprawdzenie na VM:

```bash
curl -fsS http://127.0.0.1:4200/health
docker compose --env-file /etc/jjdevhub/api.env -f infra/docker/docker-compose.yml ps
```

`/health` idzie przez nginx (`web`, port 4200) do API. API nasłuchuje też bezpośrednio na `127.0.0.1:5080`, ale na zewnątrz wystawiasz tylko `4200` — nginx proxy'uje `/api/`, `/health`, `/openapi/` i `/scalar`.

Rejestracja testowego konta (zostaw na VM, nie przez internet, dopóki nie ma tunelu):

```bash
curl -s -X POST http://127.0.0.1:4200/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"Password1"}'
```

Dalej: [cloudflare-tunnel.md](02-cloudflare-tunnel.md).
