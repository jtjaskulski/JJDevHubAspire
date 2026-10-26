# Cloudflare Tunnel

VM z [proxmox.md](01-proxmox.md) nie potrzebuje publicznego IP. `cloudflared` wychodzi z VM do Cloudflare, a Cloudflare kończy TLS i wysyła ruch HTTP na nginx.

Origin aplikacji: `http://127.0.0.1:4200`. Kontener `web` proxy'uje `/api/`, `/health`, `/openapi/` i `/scalar` do API. Postgresa (`5433`) tunelem nie publikujesz.

Osobne hostname'y, każdy na korzeniu swojej subdomeny, idą w ten sam tunel:

| Hostname | Origin na VM |
| --- | --- |
| `https://grafana.jjdevhub.com/` | `http://127.0.0.1:3000` |
| `https://jaeger.jjdevhub.com/` | `http://127.0.0.1:16686` |
| `https://prometheus.jjdevhub.com/` | `http://127.0.0.1:9090` |

Porty zostają na loopbacku. `cloudflared` stoi na VM i widzi `127.0.0.1`. Routera nie przekierowujesz.

## Po co

VM z [01-proxmox.md](01-proxmox.md) nie ma publicznego IP, a strona ma być zwykłym HTTPS. Origin zostaje `http://127.0.0.1:4200`: kontener `web` w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml) proxy'uje `/api/`, `/health`, `/openapi/` i `/scalar`. Postgres (`5433`) tunelem nie wychodzi.

## Dlaczego ta technologia

### Cloudflare Tunnel zamiast publicznego IP

`cloudflared` na VM wychodzi do Cloudflare (port 7844, UDP przy QUIC albo TCP przy HTTP/2). Cloudflare kończy TLS i wysyła HTTP na nginx na loopbacku. Przekierowanie portów 80 i 443 na routerze przegrało: wystawia VM wprost w sieć i wymaga adresu, który w domu się zmienia. Samo zezwolenie na wyjście 443 nie zestawia tunelu. VPN jako jedyne wejście przegrał, bo strona ma być zwykłym adresem w przeglądarce, a nie siecią tylko dla właściciela. Koszt: domena musi być strefą na koncie Cloudflare, a konektor trzyma jednorazowy token, którego nie ma w gicie.

### Tunel zarządzany z panelu

Trasy hostname'ów zostają w dashboardzie Zero Trust. Na VM jest tylko token i jednostka systemd. Plik konfiguracji w repo przegrał: każda zmiana hostname'a byłaby commitem, a token i tak nie może leżeć obok kodu. Koszt: odtworzenie tunelu wymaga panelu, nie samego klonu. Na architekturze innej niż amd64 pakiet bierze się z kreatora, nie z linku w krokach poniżej.

## 1. Domena

Darmowy plan Cloudflare wystarcza. Domena musi być strefą na tym koncie (nameservery u rejestratora wskazują na Cloudflare). Dalej w tekście host to `hub.example.com` — podmień na swój.

## 2. Tunel zarządzany z panelu

Konfiguracja zostaje w dashboardzie, nie w tym repo.

1. [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Networks** → **Tunnels** → **Create a tunnel**.
2. Typ: **Cloudflared**. Nazwa np. `jjdevhub`.
3. **Remotely managed** (kreator domyślnie tak działa: trasa jest w panelu, na VM jest tylko token).
4. Na stronie instalacji wybierz Debian/Ubuntu i **skopiuj polecenie**. Zawiera jednorazowy token. Nie wklejaj tokenu do gita, issue ani tego dokumentu.

Na VM (po Dockrze i działającym Compose):

```bash
curl -L --output /tmp/cloudflared.deb \
  https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i /tmp/cloudflared.deb
sudo cloudflared service install 'TOKEN_Z_PANELU'
```

`service install` zakłada jednostkę systemd i startuje ją od razu. Sprawdzenie:

```bash
systemctl status cloudflared --no-pager
```

W panelu tunel przechodzi w **Healthy**. Na architekturze innej niż amd64 weź pakiet z kreatora, nie link powyżej.

## 3. Public Hostname

W tym samym tunelu: **Public Hostname** → **Add a public hostname**.

| Pole | Wartość |
| --- | --- |
| Subdomain | `hub` (albo inny) |
| Domain | Twoja strefa |
| Path | puste |
| Type | HTTP |
| URL | `127.0.0.1:4200` |

Zapisz. Rekord DNS (proxied CNAME na tunel) panel dopisuje sam. Nie dodawaj drugiego rekordu A na adres domowy.

W tym samym tunelu dodaj trzy hostname'y obserwowalności. Path pusty, typ HTTP.

| Subdomain | Domain | URL |
| --- | --- | --- |
| `grafana` | `jjdevhub.com` | `127.0.0.1:3000` |
| `jaeger` | `jjdevhub.com` | `127.0.0.1:16686` |
| `prometheus` | `jjdevhub.com` | `127.0.0.1:9090` |

Grafana bez `GF_SERVER_ROOT_URL=https://grafana.jjdevhub.com/` ładuje HTML i nie ściąga plików aplikacji. Prometheus dostaje `--web.external-url=https://prometheus.jjdevhub.com/`. Oba są w [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml); puste zmienne w `/etc/jjdevhub/api.env` biorą te adresy z domyślnych wartości Compose. Jaeger na korzeniu `jaeger.jjdevhub.com` nie potrzebuje ścieżki bazowej.

Prometheus i Jaeger nie mają logowania. Na tych trzech hostname'ach włącz Cloudflare Access (Allow tylko na twoje konto). Huba (`4200`) Accessem nie zasłaniaj — aplikacja ma własne JWT.

Innych hostname'ów nie twórz dla API ani Postgresa.

## 4. TLS i router

W strefie: **SSL/TLS** → tryb **Full**. Ruch przeglądarka → Cloudflare jest HTTPS. Odcinek Cloudflare → `cloudflared` też. Na nginx zostaje HTTP na porcie 80 wewnątrz kontenera — to zamierzone, originem jest `http://127.0.0.1:4200`.

Na routerze **nie** przekierowuj 80 ani 443 na VM. Firewall VM może zostać zamknięty na te porty z internetu.

Konektor tunelu wychodzi na **7844**: UDP przy QUIC albo TCP przy HTTP/2. To nie jest port 443. Samo zezwolenie na wyjście 443 nie zestawi tunelu.

Port 443 zostaje osobno: pobranie pakietu `.deb` i ruch do panelu Cloudflare.

## 5. Sprawdzenie

Z innej sieci niż LAN VM:

```bash
curl -fsS "https://hub.example.com/health"
```

Potem w przeglądarce `https://hub.example.com` i logowanie. API:

```bash
curl -s -X POST "https://hub.example.com/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"Password1"}'
```

Przy `ASPNETCORE_ENVIRONMENT=Production` ścieżki `/openapi` i `/scalar` nie działają. To ustawienie z `/etc/jjdevhub/api.env`, nie z tunelu.

## 6. Cloudflare Access

Nie włączaj Access przed tą aplikacją. JJDevHub ma własne logowanie JWT. Access (osobne logowanie Cloudflare) da się dołożyć później, jeśli strona ma być niewidoczna bez konta w Zero Trust.

Deploy po commitach: [github.md](03-github.md).
