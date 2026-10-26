# Pluginy i build

Vite składa klienta web w jedną paczkę. Plugin Reacta jest już wpięty. Docelowo obok niego stoi plugin Tailwinda v4, który z jednego arkusza `src/styles.css` robi CSS klas użytych w JSX. Bramka przed obrazem Dockera i przed zielonym CI to `pnpm build`: TypeScript bez zapisu plików, potem `vite build`.

Łańcuch webu: React składa HTML5, Vite podaje jeden CSS, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Ten plik opisuje pluginy i bramkę. Serwer deweloperski jest w [01-dev.md](01-dev.md). Aliasy są w [02-aliasy.md](02-aliasy.md).

## Po co

Produkcja i CI mają dostać ten sam wynik co lokalna bramka. `pnpm build` w [src/Clients/web](../../../src/Clients/web) sprawdza typy w `src/`, a następnie — gdy typy się zgadzają — uruchamia Vite z pluginami. Plugin Reacta zamienia JSX na kod przeglądarki. Plugin `@tailwindcss/vite` czyta arkusz z `@import "tailwindcss"` i wpisuje do paczki klasy, które widzi w grafie modułów.

Bez pluginu Tailwinda `vite build` potrafi się skończyć kodem 0, a w `dist` brakuje klas z JSX. Bramka jest spełniona wtedy, gdy oba pluginy są w [vite.config.ts](../../../src/Clients/web/vite.config.ts), skrypt `build` przechodzi, a wyemitowany CSS zawiera klasę użytą na stronie.

Obraz nginx serwuje katalog `dist` z tego samego `pnpm build`. Osobnej komendy produkcyjnej nie ma.

## Wersje i pakiety

Z [package.json](../../../src/Clients/web/package.json) klienta web:

| Pakiet | Rola w buildzie | Wersja w repo |
| --- | --- | --- |
| `pnpm` | Uruchamia `prebuild` i `build` | `10.33.0` (`packageManager`) |
| `vite` | Składa `index.html` i graf od `/src/main.tsx` | `^7.1.9` |
| `@vitejs/plugin-react` | JSX i Fast Refresh w dev | `^5.0.4`, już w `devDependencies` |
| `typescript` | `tsc -p tsconfig.json --noEmit` | `~5.9.2` |
| `react`, `react-dom` | Biblioteka UI w paczce | `19.2.3` |
| `vitest` | `defineConfig` w tym samym pliku co pluginy | `^4.0.8` |

Docelowo, jako `devDependencies`, dokładają się dwa pakiety Tailwinda v4 w tej samej głównej wersji:

- `tailwindcss`
- `@tailwindcss/vite`

Vite 7 zostaje. Konfiguracja nadal wychodzi z `defineConfig` importowanego z `vitest/config`, bo w tym samym pliku siedzi blok `test`. Przenoszenie testów do osobnego pliku nie jest częścią tej bramki; opis testów jest w [04-testy.md](../react/04-testy.md).

Node w jobie [web.yml](../../../.github/workflows/web.yml) to 22. Etap budujący w [Dockerfile](../../../src/Clients/web/Dockerfile) to `node:26-alpine`. W obrazie pnpm jest instalowany globalnie jako `10.33.0`, bo ten tag Node nie niesie Corepacka. Skrypt bramki jest ten sam w obu miejscach.

`pnpm.onlyBuiltDependencies` w `package.json` dziś dopuszcza skrypty instalacji tylko dla `esbuild` i `@parcel/watcher`. Natywne paczki Tailwinda v4 (`@tailwindcss/oxide`, `lightningcss`) dopisujesz do tej listy. Inaczej `pnpm install` pominie ich skrypty, a `vite build` nie załaduje pluginu.

## Ścieżki w repo

| Ścieżka | Rola |
| --- | --- |
| [src/Clients/web/vite.config.ts](../../../src/Clients/web/vite.config.ts) | Tablica `plugins`. Dziś: `react()`. Docelowo: `react()` i `tailwindcss()`. |
| [src/Clients/web/package.json](../../../src/Clients/web/package.json) | Skrypty `prebuild` i `build`, zależności, allowlista skryptów pnpm. |
| [src/Clients/web/pnpm-lock.yaml](../../../src/Clients/web/pnpm-lock.yaml) | Lockfile, który CI i Docker instalują z `--frozen-lockfile`. |
| [src/Clients/web/tsconfig.json](../../../src/Clients/web/tsconfig.json) | Projekt dla `tsc`. `include` to `src`. `jsx` to `react-jsx`. `noEmit` jest włączone. |
| [src/Clients/web/index.html](../../../src/Clients/web/index.html) | Wejście Vite: `<script type="module" src="/src/main.tsx">`. |
| [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) | Wciąga aplikację, font Inter i arkusz. Docelowy import arkusza: `./styles.css`. |
| [src/Clients/web/src/styles.css](../../../src/Clients/web/src/styles.css) | Docelowe jedyne wejście CSS aplikacji. Na początku `@import "tailwindcss"`. |
| [src/Clients/web/scripts/copy-cv.mjs](../../../src/Clients/web/scripts/copy-cv.mjs) | `prebuild`. Zapisuje `src/content/cv.json`, które importuje [content.ts](../../../src/Clients/web/src/app/content/content.ts). |
| [src/Clients/web/Dockerfile](../../../src/Clients/web/Dockerfile) | Multi-stage. Kontekst budowania to `src/Clients`. W środku `pnpm build`. Runtime kopiuje `dist` do nginx. |
| [src/Clients/.dockerignore](../../../src/Clients/.dockerignore) | Z kontekstu wypada `mobile`, `web/node_modules` i `web/dist`. Obraz buduje paczkę od zera. |
| [infra/docker/docker-compose.yml](../../../infra/docker/docker-compose.yml) | Serwis `web`: kontekst `../../src/Clients`, dockerfile `web/Dockerfile`, port `4200:80`. |
| [.github/workflows/web.yml](../../../.github/workflows/web.yml) | Krok `Build` w katalogu `src/Clients/web` uruchamia `pnpm build`. |
| [infra/ci/trivy-web.sh](../../../infra/ci/trivy-web.sh) | `docker build -f src/Clients/web/Dockerfile … src/Clients`. |

`vite.config.ts` leży poza `include` w `tsconfig.json`. Błąd importu pluginu wychodzi przy `vite build`, po przejściu `tsc`. Dlatego bramką jest całe `pnpm build`, a nie sam `tsc`.

## Tutorial

Katalog roboczy komend lokalnych to `src/Clients/web`.

### Plugin Reacta zostaje

W [vite.config.ts](../../../src/Clients/web/vite.config.ts) plugin jest już podłączony:

```ts
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
});
```

Zostawiasz ten import i wywołanie `react()`. Plugin kompiluje JSX zgodnie z `"jsx": "react-jsx"` (automatyczny runtime, bez `import React` w każdym pliku). Przy `pnpm start` ten sam plugin włącza Fast Refresh. Przy `vite build` składa JSX do paczki produkcyjnej. Szczegóły portu 4200 i proxy są w [01-dev.md](01-dev.md).

Alias `@jjdevhub/theme`, blok `server` i blok `test` zostają w tym pliku. Ten tutorial ich nie przepisuje.

### Plugin Tailwinda

Z katalogu klienta:

```bash
cd src/Clients/web
pnpm add -D tailwindcss @tailwindcss/vite
```

Oba pakiety mają tę samą główną wersję v4. Po instalacji dopisz natywne zależności do allowlisty, obok wpisów, które już tam są:

```json
{
  "pnpm": {
    "onlyBuiltDependencies": [
      "esbuild",
      "@parcel/watcher",
      "@tailwindcss/oxide",
      "lightningcss"
    ]
  }
}
```

Potem jeszcze raz:

```bash
pnpm install
```

`pnpm-lock.yaml` wchodzi do gita razem z tą zmianą. CI i Docker wołają `pnpm install --frozen-lockfile` i bez lockfile’a nie dobudują pluginu.

W `vite.config.ts` import i tablica pluginów wyglądają tak:

```ts
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

const root = fileURLToPath(new URL('.', import.meta.url));

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@jjdevhub/theme': path.resolve(root, '../shared/theme/tokens.ts'),
    },
  },
  server: {
    port: 4200,
    proxy: {
      '/api': { target: 'http://localhost:5080', changeOrigin: true },
      '/health': { target: 'http://localhost:5080', changeOrigin: true },
      '/openapi': { target: 'http://localhost:5080', changeOrigin: true },
      '/scalar': { target: 'http://localhost:5080', changeOrigin: true },
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: './src/test-setup.ts',
  },
});
```

`defineConfig` zostaje z `vitest/config`. Kolejność w tablicy: najpierw `react()`, potem `tailwindcss()`. Plugin Tailwinda v4 skanuje klasy w plikach widocznych dla Vite od `index.html`. Osobny `tailwind.config.js` z tablicą `content` nie wchodzi do tego pliku.

Treść arkusza, pierwsza klasa na shellu i `@theme` są w [01-instalacja.md](../tailwind/01-instalacja.md) i [02-motyw.md](../tailwind/02-motyw.md). Dla bramki wystarcza wejście, które plugin potrafi przeczytać. W [src/main.tsx](../../../src/Clients/web/src/main.tsx) import arkusza wskazuje CSS:

```ts
import '@fontsource-variable/inter';
import './styles.css';
```

Plik `src/styles.css` zaczyna się od:

```css
@import "tailwindcss";
```

[index.html](../../../src/Clients/web/index.html) zostaje z jednym skryptem modułu `/src/main.tsx` i elementem `#root`. Drugiego arkusza w `<head>` nie dodajesz. Vite sam wstawi do wynikowego HTML link do CSS, który powstał z tego grafu. `base` zostaje domyślne `/`, żeby trasy `/pl`, `/en`, `/login` i `/register` działały na nginx tak samo jak na serwerze Vite.

Tailwind v4 kompiluje CSS pluginem Vite. Pakiet `sass` nie jest częścią tej tablicy pluginów. Zejście z dotychczasowego importu arkusza opisuje [06-css-zamiast-scss.md](../tailwind/06-css-zamiast-scss.md).

### Bramka `pnpm build`

Skrypty w `package.json` zostają w tej postaci:

```json
{
  "prebuild": "node scripts/copy-cv.mjs",
  "build": "tsc -p tsconfig.json --noEmit && vite build"
}
```

Uruchomienie:

```bash
cd src/Clients/web
pnpm build
```

Kolejność jest stała.

1. pnpm widzi `prebuild` i uruchamia [copy-cv.mjs](../../../src/Clients/web/scripts/copy-cv.mjs). Skrypt zapisuje `src/content/cv.json` (z `cv.local.json`, gdy plik jest na dysku, w przeciwnym razie z `cv.example.json`). Import w `content.ts` ma ten plik zobaczyć. Źródło CV opisuje [03-tresc-i-auth.md](../react/03-tresc-i-auth.md).
2. `tsc -p tsconfig.json --noEmit` sprawdza katalog `src` przy `strict: true`. Flaga `--noEmit` jest w skrypcie i w `tsconfig.json`. Kompilator nie zapisuje `.js` obok źródeł. Vite jest jedynym narzędziem, które emituje kod przeglądarki.
3. Gdy `tsc` kończy się kodem 0, operator `&&` puszcza `vite build`. Vite czyta `index.html`, przechodzi graf, uruchamia `react()` i `tailwindcss()`, składa Inter z `@fontsource-variable/inter` i zapisuje wynik do `dist/`.

Gołe `vite build` omija `prebuild` i `tsc`. Bramką jest `pnpm build`.

Po zielonym przebiegu w `dist/` jest `index.html` oraz pliki w `dist/assets/` (JS, CSS aplikacji, CSS i pliki fontu Inter). W `index.html` siedzą odwołania do tych plików z hashem w nazwie. Katalog `dist/` zostaje poza gitem.

Sprawdzenie lokalne:

```bash
cd src/Clients/web
pnpm build
test -f dist/index.html
```

Klasa Tailwinda wpisana w JSX (nazwy kolorów biorą się z [motyw.md](../motyw.md)) ma wystąpić w wyemitowanym pliku CSS w `dist/assets/`.

### Docker z kontekstu `src/Clients`

Zależność `"@jjdevhub/theme": "file:../shared/theme"` wskazuje katalog obok `web`. Kontekst `docker build` to więc [src/Clients](../../../src/Clients), a plik Dockerfile leży w `web/`. Sam katalog `web` jako kontekst nie widzi `../shared/theme`.

Z katalogu głównego repozytorium:

```bash
docker build -f src/Clients/web/Dockerfile -t jjdevhub-web src/Clients
```

Tę samą parę kontekstu i Dockerfile ma serwis `web` w [docker-compose.yml](../../../infra/docker/docker-compose.yml) (`context: ../../src/Clients`, `dockerfile: web/Dockerfile`) oraz [trivy-web.sh](../../../infra/ci/trivy-web.sh).

Etap `build` w Dockerfile, bez zmiany samego pliku przy dodawaniu pluginu:

```dockerfile
# Build context is src/Clients so file:../shared/theme resolves.
FROM node:26-alpine AS build
WORKDIR /src

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
ENV CI=true

RUN npm install -g pnpm@10.33.0

COPY shared/theme ./shared/theme
COPY web/package.json web/pnpm-lock.yaml ./web/

WORKDIR /src/web
RUN pnpm install --frozen-lockfile

COPY web/ ./
RUN pnpm build
```

Najpierw kopiowane są `package.json` i lockfile, potem instalacja, potem reszta źródeł, na końcu `pnpm build`. Nowa zależność pluginu wchodzi tym pierwszym kopiowaniem, więc lockfile musi już ją zawierać. `RUN pnpm build` odpala `prebuild`, `tsc --noEmit` i `vite build` wewnątrz kontenera. Kod wyjścia inny niż 0 przerywa budowę obrazu.

[.dockerignore](../../../src/Clients/.dockerignore) wyrzuca z kontekstu `web/node_modules` i `web/dist`. Paczka w obrazie powstaje w `RUN`, a nie ze lokalnego `dist/` z laptopa. Katalog `mobile` też wypada z kontekstu: ten Vite buduje tylko klienta web.

Etap `runtime` to `nginx:1.31-alpine`. Kopiuje `web/nginx.conf` i wynik:

```dockerfile
COPY --from=build /src/web/dist /usr/share/nginx/html
```

Nginx serwuje `index.html` i assets. `location /` ma `try_files` z powrotem na `index.html`, więc odświeżenie `/pl` i `/login` zostaje w aplikacji. Port kontenera 80 jest na hoście mapowany na 4200. Healthcheck serwisu `web` woła `wget` na `/` i oczekuje tego `index.html`.

Dockerfile zostaje w tej postaci. Zmiana wersji Node, nginx albo kolejności `COPY` nie jest potrzebna do wpięcia pluginu.

## Przypadki użycia

### Bramka `pnpm build`

Jeden przebieg decyduje, czy zmiana komponentu może iść dalej. Ten sam skrypt odpalasz lokalnie, w kroku `Build` workflow `web` (katalog roboczy `src/Clients/web`, po `pnpm test:ci`) i jako `RUN pnpm build` w obrazie.

Weź kartę kursu. W propsach `title` jest `string`, a ktoś przypisze go do `number`:

```tsx
function CourseCard({ title }: { title: string }) {
  const label: number = title;

  return <article>{label}</article>;
}
```

`pnpm build` uruchamia `prebuild`, potem `tsc`. Kompilator zgłasza, że `string` nie pasuje do `number`, i kończy się kodem innym niż 0. `vite build` się nie startuje. `dist/` z poprzedniego zielonego przebiegu zostaje nietknięte przez ten przebieg. W CI krok `Build` jest czerwony. `docker build` urywa się na `RUN pnpm build` i etap nginx nie dostaje nowej paczki.

Po poprawce (`label` zostaje `string`) ten sam `pnpm build` przechodzi `tsc` i wchodzi w Vite. `react()` składa JSX artykułu. `tailwindcss()` widzi klasy na tym `<article>` i na shellu, bo pliki są w grafie od `index.html`. W `dist/index.html` jest moduł JS i link do CSS. W pliku CSS jest klasa z karty. Import `@fontsource-variable/inter` dokłada Inter do `dist/assets/`.

Workflow nie dostaje nowego kroku. Istniejący krok `Build` staje się zielony, gdy lockfile zawiera `@tailwindcss/vite`, a skrypt kończy się kodem 0. Obraz z `docker build -f src/Clients/web/Dockerfile src/Clients` serwuje tę paczkę. Wejście na `http://localhost:4200/` (mapowanie `4200:80`) oddaje zbudowany `index.html`, a odświeżenie `/pl` zostaje przy kliencie dzięki `try_files`.

Osobno: sam zielony `tsc` nie dowodzi, że plugin Tailwinda jest w paczce. Brak pakietu albo skrypt instalacji ucięty przez allowlistę pnpm wychodzi dopiero przy `vite build` (`Cannot find package '@tailwindcss/vite'` albo błąd natywnego bindowania). Pełne `pnpm build` łapie obie połówki.

## Zasady wyglądu

Bramka nie wybiera palety. Liczby zostają w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts): płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, Inter, duży oddech, mało ramek, ciemny hero. Plugin Tailwinda tylko zamienia klasy z tych tokenów na CSS. Drugiej palety w konfiguracji Vite nie ma.

Wejście stylów aplikacji to jeden `src/styles.css`. Ciemny hero i jasne sekcje są klasami na HTML5, który składa React, i lądują w tym CSS. Osobnego trybu budowania dla hero nie ma.

Inter wchodzi do paczki importem `@fontsource-variable/inter` w `main.tsx`. `vite build` zostawia pliki fontu w `dist`. Obcinanie tego importu przy „czyszczeniu” builda usuwa krój z produkcji.

shadcn i Motion nie mają własnego bundla ani własnej komendy. Ich kod siedzi w tym samym JSX i przechodzi przez `react()` oraz `tailwindcss()` przy tym samym `pnpm build`.

Ekran telefonu idzie inną ścieżką (NativeWind). Ten Dockerfile i ten `vite build` składają klienta web.

## Poza zakresem

- Port 4200, proxy `/api`, `/health`, `/openapi`, `/scalar` i `pnpm start`: [01-dev.md](01-dev.md).
- Alias `@jjdevhub/theme` i docelowy `@/`: [02-aliasy.md](02-aliasy.md). W przykładzie konfiguracji powyżej alias jest tylko po to, żeby plik został spójny ze stanem repo.
- Kroki `@import`, pierwsza klasa na shellu, `@theme`: [01-instalacja.md](../tailwind/01-instalacja.md), [02-motyw.md](../tailwind/02-motyw.md).
- Zejście z arkuszy `*.scss` i pakietu `sass`: [06-css-zamiast-scss.md](../tailwind/06-css-zamiast-scss.md).
- Vitest, Testing Library i `pnpm test:ci`: [04-testy.md](../react/04-testy.md). Krok testów w workflow zostaje przed bramką builda.
- Skąd bierze się `cv.local.json`: [03-tresc-i-auth.md](../react/03-tresc-i-auth.md). Tu liczy się tylko to, że `prebuild` zapisuje `cv.json` zanim ruszy `tsc`.
- Reguły proxy nginx dla API. Dla tej bramki runtime ma serwować `dist` i oddawać nieznane ścieżki do `index.html`.
- Skan Trivy, audit pnpm i progi CVE. Skrypt obrazu woła ten sam `docker build`, polityka skanu zostaje w `infra/ci`.
- Klient mobilny, NativeWind, Reanimated, Tamagui.

## Gotowe gdy

- W `devDependencies` są `tailwindcss` i `@tailwindcss/vite` (Tailwind v4, ta sama główna wersja), a `pnpm-lock.yaml` jest zaktualizowany.
- `pnpm.onlyBuiltDependencies` zawiera `@tailwindcss/oxide` i `lightningcss` obok `esbuild` i `@parcel/watcher`. `pnpm install` w `src/Clients/web` kończy się kodem 0.
- [vite.config.ts](../../../src/Clients/web/vite.config.ts) importuje `tailwindcss` z `@tailwindcss/vite` i ma `plugins: [react(), tailwindcss()]`. `defineConfig` pochodzi z `vitest/config`. Bloki `server` i `test` oraz alias `@jjdevhub/theme` pozostają.
- `src/main.tsx` importuje `./styles.css`. `src/styles.css` zaczyna się od `@import "tailwindcss"`. `index.html` nadal ładuje wyłącznie `/src/main.tsx`.
- Skrypt `build` to `tsc -p tsconfig.json --noEmit && vite build`. Skrypt `prebuild` to `node scripts/copy-cv.mjs`.
- `pnpm build` w `src/Clients/web` kończy się kodem 0. Istnieje `dist/index.html`. W `dist/assets/` jest CSS aplikacji i pliki Inter.
- Celowy błąd typu w `src/` (przypisanie `string` do `number`) sprawia, że `pnpm build` kończy się kodem innym niż 0 na `tsc`, zanim wystartuje `vite build`.
- Klasa Tailwinda użyta w JSX występuje w CSS zapisanym w `dist/assets/`.
- `docker build -f src/Clients/web/Dockerfile src/Clients` przechodzi `RUN pnpm build`. Obraz runtime ma zawartość `dist` w `/usr/share/nginx/html`.
- Krok `Build` w [web.yml](../../../.github/workflows/web.yml) nadal uruchamia `pnpm build` w `src/Clients/web` i jest zielony na tej zmianie.
