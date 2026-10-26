# Serwer deweloperski Vite

Lokalny klient web stoi na jednym originie: `http://localhost:4200`. Vite serwuje `index.html` i graf modułów, a cztery prefiksy API przekazuje na proces Kestrel na `http://localhost:5080`. Formularz logowania woła względny `/api/auth/login`. Przeglądarka zostaje na porcie 4200, więc `fetch` idzie tym samym originem co strona.

Łańcuch webu: React składa HTML5, ten serwer podaje jeden CSS, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Ten plik opisuje wyłącznie uruchomienie deweloperskie. Alias `@/` jest w [02-aliasy.md](02-aliasy.md). Plugin Reacta, plugin Tailwinda i `pnpm build` są w [03-pluginy-i-build.md](03-pluginy-i-build.md).

## Wersje i pakiety

Kontrakt jest w [src/Clients/web/package.json](../../../src/Clients/web/package.json). Katalog klienta jest osobnym pakietem. W korzeniu repo nie ma `pnpm-workspace.yaml`.

| Pole | Wartość |
|------|---------|
| `packageManager` | `pnpm@10.33.0` |
| `type` | `module` |
| `vite` | `^7.1.9` (devDependency) |
| `@vitejs/plugin-react` | `^5.0.4` (devDependency) |
| `react`, `react-dom` | `19.2.3` |

`pnpm.onlyBuiltDependencies` dopuszcza skrypty budowania `esbuild` i `@parcel/watcher`. Vite 7 startuje na esbuildzie. Usunięcie tej listy przy pnpm 10 zostawia instalację bez silnika transformacji i `pnpm start` pada przy pierwszym żądaniu modułu.

Lockfile to [src/Clients/web/pnpm-lock.yaml](../../../src/Clients/web/pnpm-lock.yaml). Instalacja idzie z katalogu klienta, tym pnpmem, który wpisuje pole `packageManager`.

## Ścieżki w repo

| Ścieżka | Rola |
|---------|------|
| [src/Clients/web/package.json](../../../src/Clients/web/package.json) | `prestart`, `start` (`vite --port 4200`) |
| [src/Clients/web/vite.config.ts](../../../src/Clients/web/vite.config.ts) | `server.port`, `server.proxy` |
| [src/Clients/web/index.html](../../../src/Clients/web/index.html) | dokument, moduł `/src/main.tsx` |
| [src/Clients/web/scripts/copy-cv.mjs](../../../src/Clients/web/scripts/copy-cv.mjs) | hook `prestart` |
| [src/api/Properties/launchSettings.json](../../../src/api/Properties/launchSettings.json) | API na `http://localhost:5080` |
| [src/api/Auth/AuthEndpoints.cs](../../../src/api/Auth/AuthEndpoints.cs) | `POST /api/auth/login`, `POST /api/auth/register` |
| [src/Clients/web/src/app/auth/auth.tsx](../../../src/Clients/web/src/app/auth/auth.tsx) | `fetch('/api/auth/…')` |

Konfiguracja serwera w `vite.config.ts` zostaje w tym kształcie. `defineConfig` pochodzi z `vitest/config`, bo ten sam plik trzyma też blok `test`. Zachowanie testów opisuje [../react/04-testy.md](../react/04-testy.md).

```ts
server: {
  port: 4200,
  proxy: {
    '/api': { target: 'http://localhost:5080', changeOrigin: true },
    '/health': { target: 'http://localhost:5080', changeOrigin: true },
    '/openapi': { target: 'http://localhost:5080', changeOrigin: true },
    '/scalar': { target: 'http://localhost:5080', changeOrigin: true },
  },
},
```

Skrypt `start` powtarza port flagą, żeby proces z CLI i proces czytający config słuchały tego samego numeru:

```json
"prestart": "node scripts/copy-cv.mjs",
"start": "vite --port 4200"
```

## Tutorial

### 1. pnpm 10.33.0

W katalogu klienta włącz menedżera zapisany w `packageManager`:

```bash
cd src/Clients/web
corepack enable
corepack prepare pnpm@10.33.0 --activate
pnpm --version
```

Ostatnia linia wypisuje `10.33.0`. Potem instalacja z lockfile:

```bash
pnpm install
```

Katalog roboczy to `src/Clients/web`. Uruchomienie `pnpm` z korzenia repo nie widzi tego `package.json`.

### 2. API na porcie 5080

Proxy ma dokąd iść dopiero wtedy, gdy coś słucha na `localhost:5080`. Profil `http` w `launchSettings.json` ustawia `applicationUrl` na `http://localhost:5080`.

Postgres zostaje w Compose (port `127.0.0.1:5433`). API odpalasz z korzenia repo, obok kontenera bazy:

```bash
cd infra/docker
cp .env.example .env   # raz
docker compose up -d db
cd ../..
dotnet run --project src/api --launch-profile http
```

Kontener `api` z pełnego Compose też publikuje `127.0.0.1:5080:8080`. Drugi proces na 5080 wtedy nie wstanie. Zostaw jeden z tych dwóch: kontener `api` albo `dotnet run`.

Kontener `web` publikuje `4200:80` i zajmuje port klienta. Zatrzymaj go, zanim wstanie Vite:

```bash
cd infra/docker
docker compose stop web
```

Sprawdzenie samego API, jeszcze poza proxy:

```bash
curl -fsS http://localhost:5080/health
```

Odpowiedź zawiera `"Status":"Healthy"`.

### 3. Start klienta

Drugi terminal, katalog klienta:

```bash
cd src/Clients/web
pnpm start
```

pnpm odpala lifecycle po kolei. Najpierw `prestart` (`node scripts/copy-cv.mjs`) kopiuje `cv.local.json` albo `cv.example.json` do `src/content/cv.json`. Potem `start` uruchamia `vite --port 4200`. Skąd bierze się plik CV, opisuje [../react/03-tresc-i-auth.md](../react/03-tresc-i-auth.md).

W logu Vite widać lokalny adres:

```text
Local:   http://localhost:4200/
```

`server.host` w configu nie ma, więc Vite 7 trzyma się `localhost` i nie wystawia klienta na interfejs sieci lokalnej. Wejście w przeglądarce: [http://localhost:4200](http://localhost:4200). Dokument to `index.html`, skrypt typu `module` wskazuje `/src/main.tsx`. Dalsze pliki Vite podaje jako natywne moduły ES, z gorącym podmienianiem, bez pełnego `vite build`.

Gdy 4200 jest zajęty, Vite bez `strictPort` przeskakuje na kolejny port i wypisuje inny `Local:`. Kontrakt tego repo to 4200. Zatrzymaj proces, który trzyma port (najczęściej kontener `web`), i uruchom `pnpm start` ponownie, aż log pokaże `http://localhost:4200/`.

### 4. Co robi proxy

Żądanie, którego ścieżka zaczyna się od klucza z `server.proxy`, Vite przekazuje na `target`. Ścieżki Vite nie przepisuje: brak `rewrite`. `changeOrigin: true` ustawia nagłówek `Host` na host z `target` (`localhost:5080`).

| Żądanie przeglądarki | Proces API |
|----------------------|------------|
| `http://localhost:4200/api/…` | `http://localhost:5080/api/…` |
| `http://localhost:4200/health` | `http://localhost:5080/health` |
| `http://localhost:4200/openapi/…` | `http://localhost:5080/openapi/…` |
| `http://localhost:4200/scalar` | `http://localhost:5080/scalar` |

Klucz jest prefiksem. `/api` obejmuje `/api/auth/login`. `/health` obejmuje `GET /health`. Reszta ścieżek (`/`, `/pl`, `/pl/cv`, `/login`, `/src/main.tsx`, pliki z `public/`) zostaje w Vite.

Sprawdzenie czterech prefiksów przez origin klienta. OpenAPI i Scalar odpowiadają, gdy API jest w `Development` (tak startuje profil `http`):

```bash
curl -fsS http://localhost:4200/health
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:4200/openapi/v1.json
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:4200/scalar
```

`/health` zwraca ten sam JSON co bezpośrednie `curl` na `:5080`. Kody OpenAPI i Scalar to `200`.

Gdy API nie słucha, terminal Vite loguje błąd proxy, a przeglądarka dostaje odpowiedź 500 na adresie `:4200`. Sam klient (HTML strony `/pl`) dalej się otwiera. 500 na `/api/…` przy żywym `pnpm start` oznacza brak procesu na 5080, a nie złą ścieżkę w Reactcie.

### 5. Logowanie przez proxy

Strony treści (`/:lang` oraz home, cv, courses, compendium, notes) czytają JSON z bundla. HTTP do API zostaje przy `/login` i `/register`. Obie trasy są poza prefiksem języka. Klient woła względny URL, tak jak w `postAuth`:

```ts
const response = await fetch(`/api/auth/${path}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password }),
});
```

`path` to `'login'` albo `'register'`. W dev przeglądarka wysyła `POST http://localhost:4200/api/auth/login`. Vite widzi prefiks `/api` i oddaje ciało na `POST http://localhost:5080/api/auth/login`. Odpowiedź wraca do karty na originie 4200. Token ląduje w `localStorage` pod kluczem `jjdevhub.token`. Gorące przeładowanie modułu nie zmienia originu, więc zapisany token zostaje.

Próba z terminala, tym samym originem co formularz. Hasło jest przykładem z README, nie sekretem repo:

```bash
curl -sS -X POST http://localhost:4200/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"Password1"}'

curl -sS -D - -o /tmp/jjdevhub-login.json \
  -X POST http://localhost:4200/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"Password1"}'

jq -r .token /tmp/jjdevhub-login.json
```

Rejestracja nowego adresu zwraca 201 i JSON z tokenem. Kolejne logowanie zwraca 200 i pole `token`. Nagłówek odpowiedzi idzie z API (`application/json`), a adres w `curl` zostaje na `:4200`.

Złe hasło też musi dojść do API:

```bash
curl -sS -D - -o /tmp/jjdevhub-login-bad.json \
  -X POST http://localhost:4200/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@test.com","password":"zle-haslo"}'
```

Status to 401, ciało jest JSON-em problemu z API. Taki wynik znaczy, że prefiks `/api` zadziałał. HTML `index.html` albo 404 z samego Vite znaczy, że ścieżka minęła tablicę `proxy`.

W przeglądarce: otwórz [http://localhost:4200/login](http://localhost:4200/login), wyślij formularz i w zakładce sieci zostaw filtr na `login`. Wiersz ma adres `http://localhost:4200/api/auth/login`, metodę POST i status 200 albo 401. Kolumna origin nie pokazuje portu 5080.

Ten sam kształt URL działa później za nginx w obrazie klienta: przeglądarka dalej woła `/api/…` na hoście strony. W dev celem proxy jest `localhost:5080`. W Compose nginx na opublikowanym porcie 4200 przekazuje `/api/`, `/health`, `/openapi/` i `/scalar` do `api:8080`. Kod `fetch` się nie zmienia.

## Przypadki użycia

### Logowanie na żywym API

API słucha na 5080, `pnpm start` trzyma 4200. Użytkownik otwiera `/login`, podaje email i hasło. `fetch('/api/auth/login')` przechodzi proxy, Identity sprawdza hasło, odpowiedź z tokenem wraca na 4200, a klient zapisuje `jjdevhub.token`. Po odświeżeniu `/pl` token zostaje w `localStorage`, bo origin się nie zmienił.

### Rejestracja

`/register` woła `POST /api/auth/register` tym samym helperem i tym samym prefiksem `/api`. Nowe konto dostaje 201. Zajęty email dostaje problem walidacji z API (ciało JSON, status 4xx), nadal przez port 4200.

### Health, OpenAPI i Scalar z paska przeglądarki

Deweloper sprawdza proces API bez przełączania portu:

- [http://localhost:4200/health](http://localhost:4200/health) — JSON `Healthy`
- [http://localhost:4200/openapi/v1.json](http://localhost:4200/openapi/v1.json) — dokument OpenAPI w `Development`
- [http://localhost:4200/scalar](http://localhost:4200/scalar) — UI Scalar

Te trzy adresy są w tej samej tablicy `proxy` co `/api`. Formularz logowania ich nie woła.

### Strona treści przy wyłączonym API

`/pl`, `/pl/cv`, `/pl/courses`, kompendium i notatki czytają `pl.json`, `en.json` i wygenerowany `cv.json` z bundla. Vite serwuje je przy leżącym API. Pasek sieci na takiej nawigacji nie zawiera `/api`. Pad proxy widać dopiero na `/login`, `/health`, `/openapi` albo `/scalar`.

### Port 4200 zajęty przez Compose

Pełne `docker compose up` trzyma nginx na 4200. `pnpm start` albo nie wstanie na kontrakcie, albo (bez `strictPort`) przeskoczy na inny port. Logowanie na tym innym porcie mija proxy opisane w tym pliku tylko wtedy, gdy config i flaga `--port` naprawdę wskazują proces, którego używasz. Docelowy przebieg: `docker compose stop web`, potem `pnpm start`, log `http://localhost:4200/`.

### API leży, klient stoi

Strona `/pl` się otwiera. `POST /api/auth/login` kończy się 500, a terminal Vite pisze błąd połączenia z `localhost:5080`. Naprawa jest po stronie API (profil `http` albo kontener `api`), nie w ścieżce `fetch`.

## Zasady wyglądu

Serwer dev podaje dokument z [index.html](../../../src/Clients/web/index.html): jeden `h1` i reszta semantycznego HTML5 powstają w JSX, a Vite tylko dostarcza ten dokument na `localhost:4200`.

Jeden arkusz CSS. Docelowe wejście to `src/styles.css` (`@import "tailwindcss"`). Wpięcie pliku opisuje [../tailwind/01-instalacja.md](../tailwind/01-instalacja.md). HMR podmienia klasy na żywo i zostawia origin `http://localhost:4200`, więc sesja logowania w `localStorage` przeżywa zapis pliku.

Liczby koloru, skali, odstępów, radiusa i czasu siedzą w [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Paleta to `#f5f5f7`, `#1d1d1f`, `#0071e3`, krój Inter, duży oddech, mało ramek, ciemny hero na home. Serwer dev nie dokleja własnego motywu, nakładki ani drugiej palety. Mapowanie liczb na klasy jest w [../motyw.md](../motyw.md) i w plikach `docs/frontend/tailwind/`.

Ekran telefonu jest osobnym procesem w `src/Clients/mobile/JJDevHubMobile`. Port 4200 obsługuje web.

## Poza zakresem

- Alias `@jjdevhub/theme` i docelowy `@/` — [02-aliasy.md](02-aliasy.md).
- Plugin `@vitejs/plugin-react` (już jest w tablicy `plugins`), docelowy `@tailwindcss/vite`, skrypt `build` i obraz Dockera — [03-pluginy-i-build.md](03-pluginy-i-build.md).
- Trasy, locale `pl`/`en`, shell — [../react/02-trasy.md](../react/02-trasy.md).
- JSON w bundlu, `cv.local.json`, kształt formularza — [../react/03-tresc-i-auth.md](../react/03-tresc-i-auth.md).
- Vitest — [../react/04-testy.md](../react/04-testy.md).
- Konfiguracja nginx w [src/Clients/web/nginx.conf](../../../src/Clients/web/nginx.conf) i Compose. Ten plik ustala tylko proxy Vite. Prefiksy URL są te same, żeby `fetch` został względny.
- Intranet. Gdy treści intranetu wejdą do API, pójdą tym samym klientem i tym samym prefiksem `/api` na porcie 4200.
- Tamagui, drugi klient intranetu, wspólny parallax webu i telefonu.

## Gotowe gdy

- `pnpm --version` w `src/Clients/web` zwraca `10.33.0`, a `pnpm install` kończy się na istniejącym `pnpm-lock.yaml`.
- `package.json` ma `"start": "vite --port 4200"` i `"prestart": "node scripts/copy-cv.mjs"`.
- `pnpm start` w logu wypisuje skopiowanie CV, potem `Local: http://localhost:4200/`.
- `server.port` to `4200`. `server.proxy` ma dokładnie klucze `/api`, `/health`, `/openapi`, `/scalar`. Każdy ma `target: 'http://localhost:5080'` i `changeOrigin: true`, bez `rewrite`.
- Przy API na 5080: `curl -fsS http://localhost:4200/health` zwraca JSON ze statusem Healthy.
- `POST http://localhost:4200/api/auth/login` z poprawnym ciałem zwraca JSON z `token` i status 200. Złe hasło zwraca 401 i JSON z API.
- W przeglądarce formularz na `http://localhost:4200/login` pokazuje w sieci żądanie na `:4200/api/auth/login`.
- `http://localhost:4200/pl` otwiera się z Vite przy zatrzymanym API. `http://localhost:4200/openapi/v1.json` i `http://localhost:4200/scalar` otwierają się, gdy API jest w `Development`.
- `fetch` auth zostaje ścieżką względną `/api/auth/login` i `/api/auth/register`. W kodzie klienta nie ma hosta `localhost:5080`.
