# 02 — Aliasy

Dwa aliasy klienta web. `@jjdevhub/theme` już wskazuje wspólny plik liczb. `@/` dochodzi na katalog `src`, żeby komponenty shadcn dało się importować krótką ścieżką. React składa HTML5, Vite podaje jeden CSS (`src/styles.css`), Tailwind v4 daje klasy, a shadcn i Motion siedzą na tym samym HTML. Alias jest tylko drogą importu do tego HTML.

## Po co

`@jjdevhub/theme` jest nazwą pakietu z liczbami wyglądu: kolory, skala, odstępy, radius, czasy. Web i telefon czytają ten sam plik. Komponent nie składa ścieżki względnej w górę do `src/Clients/shared`.

`@/` jest skrótem do `src/Clients/web/src`. shadcn pod Vite generuje importy `@/components/ui/...` i `@/lib/utils`. Ta nazwa nie jest pakietem w `package.json`. Rozwiązują ją dwa wpisy: `resolve.alias` w konfiguracji Vite oraz `paths` w `tsconfig.json`.

Vite i `tsc` nie dzielą jednej listy aliasów.

- Dev, `vite build` i Vitest czytają [vite.config.ts](../../../src/Clients/web/vite.config.ts). Brak klucza w `resolve.alias` daje przy bundlu `Failed to resolve import`.
- Bramka `tsc -p tsconfig.json --noEmit` czyta [tsconfig.json](../../../src/Clients/web/tsconfig.json). Brak `paths` daje `Cannot find module '@/…'`. Sam alias Vite tego nie naprawia.

`@jjdevhub/theme` jest prawdziwą zależnością, więc TypeScript znajduje ją bez `paths`. `@/` takiej zależności nie ma, więc oba pliki są wymagane.

## Wersje i pakiety

Wersje z [package.json](../../../src/Clients/web/package.json) klienta web. Ten plik ich nie podbija.

| Pakiet | Wersja w repo | Rola przy aliasach |
| --- | --- | --- |
| `vite` | `^7.1.9` | `resolve.alias` w dev i w `vite build` |
| `vitest` | `^4.0.8` | `defineConfig` z `vitest/config`, więc ten sam alias obowiązuje w `pnpm test` i `pnpm test:ci` |
| `typescript` | `~5.9.2` | `moduleResolution: "bundler"`, bramka `tsc --noEmit` |
| `@vitejs/plugin-react` | `^5.0.4` | plugin JSX; aliasów nie zastępuje |
| `react` / `react-dom` | `19.2.3` | import z `@/components/ui` zostaje komponentem Reacta |
| `@jjdevhub/theme` | `0.0.0`, `file:../shared/theme` | pakiet prywatny, `exports` wskazuje `./tokens.ts` |
| pnpm | `10.33.0` (`packageManager`) | instaluje link `file:` |

Pluginu `vite-tsconfig-paths` nie ma i nie dochodzi. Dwa wpisy są jawne. Plugin ukryłby rozjazd, a `tsc` i tak czyta wyłącznie `tsconfig.json`.

Osobnego `vitest.config.ts` nie ma. Blok `test` siedzi w tym samym pliku co `resolve.alias`.

## Ścieżki w repo

| Ścieżka | Rola |
| --- | --- |
| [src/Clients/web/vite.config.ts](../../../src/Clients/web/vite.config.ts) | `resolve.alias`. Dziś tylko `@jjdevhub/theme` |
| [src/Clients/web/tsconfig.json](../../../src/Clients/web/tsconfig.json) | `compilerOptions`. Dziś bez `baseUrl` i bez `paths`. `include` to `["src"]` |
| [src/Clients/web/package.json](../../../src/Clients/web/package.json) | `"@jjdevhub/theme": "file:../shared/theme"` |
| [src/Clients/shared/theme/package.json](../../../src/Clients/shared/theme/package.json) | `"name": "@jjdevhub/theme"`, `"exports": { ".": "./tokens.ts" }` |
| [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts) | cel aliasu motywu. Eksporty: `tokens`, typ `Tokens`, `cssCustomProperties()` |
| [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) | `cssCustomProperties` z `@jjdevhub/theme` |
| [src/Clients/web/src/app/pages/home/HomeHero.tsx](../../../src/Clients/web/src/app/pages/home/HomeHero.tsx) | `tokens` z `@jjdevhub/theme` |
| `src/Clients/web/src/` | cel docelowego `@/` |
| `src/Clients/web/src/components/ui/` | docelowe komponenty shadcn, jeszcze poza repo |

Katalog konfiguracji Vite (`root` w pliku configu) to `src/Clients/web`. Stąd `../shared/theme/tokens.ts` jest plikiem tokenów, a `src` jest katalogiem źródeł klienta.

## Tutorial

Komendy odpalaj z `src/Clients/web`.

### 1. Zostaw `@jjdevhub/theme` jako pakiet i jako alias Vite

Zależność zostaje:

```json
"@jjdevhub/theme": "file:../shared/theme"
```

Pakiet eksportuje wyłącznie korzeń na plik tokenów:

```json
{
  "name": "@jjdevhub/theme",
  "exports": {
    ".": "./tokens.ts"
  }
}
```

Drugiego subpath (`@jjdevhub/theme/tokens`) nie dodawaj. Import ma jedną formę:

```ts
import { cssCustomProperties, tokens } from '@jjdevhub/theme';
import type { Tokens } from '@jjdevhub/theme';
```

TypeScript z `moduleResolution: "bundler"` idzie przez `exports` i link `file:`. Dlatego tej nazwy nie wpisuj do `paths`.

Vite i tak dostaje jawny alias. W configu ESM nie ma `__dirname`. Katalog bierze istniejące `root`:

```ts
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('.', import.meta.url));
```

Wartość aliasu jest absolutna i wskazuje ten sam `tokens.ts`, który eksportuje pakiet:

```ts
'@jjdevhub/theme': path.resolve(root, '../shared/theme/tokens.ts'),
```

Po `pnpm install` nazwa żyje też w `node_modules`. Alias w Vite zostaje: bundler wskazuje plik tokenów wprost, obok klienta, tym samym wpisem co reszta konfiguracji.

Sprawdzenie, że nic się nie rozjechało, zanim dojdzie `@/`:

```bash
pnpm exec tsc -p tsconfig.json --noEmit
```

Istniejące importy w `main.tsx` i `HomeHero.tsx` mają przejść. Serwer dev (port i proxy: [01-dev.md](01-dev.md)) przy starcie nie może zgłosić `Failed to resolve import "@jjdevhub/theme"`.

### 2. Dopisz `@` w `vite.config.ts`

W `resolve.alias` dopisz klucz obok motywu. Reszta pliku (`plugins`, `server`, `test`) zostaje.

```ts
resolve: {
  alias: {
    '@jjdevhub/theme': path.resolve(root, '../shared/theme/tokens.ts'),
    '@': path.resolve(root, 'src'),
  },
},
```

`'@'` rozwiązuje import równy `@` albo zaczynający się od `@/`. `@jjdevhub/theme` nie zaczyna się od `@/`, więc zostaje przy `tokens.ts`. Klucza nie zamieniaj na wyrażenie regularne `/^@/`: takie wyrażenie połknęłoby nazwę pakietu motywu.

`path.resolve(root, 'src')` to `src/Clients/web/src`. Zamiana `@/components/ui/button` daje `src/Clients/web/src/components/ui/button`.

### 3. Dopisz `baseUrl` i `paths` w `tsconfig.json`

Do `compilerOptions` dochodzą dwa pola. Reszta opcji i `include` zostają. Docelowy plik:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "resolveJsonModule": true,
    "types": ["vite/client", "vitest/globals"],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

`baseUrl` jest `"."` względem `src/Clients/web`, czyli katalogu z tym `tsconfig.json`. Wpis `"@/*": ["./src/*"]` jest taki, jakiego oczekuje `shadcn init` pod Vite. Samą komendę init i `components.json` opisuje [shadcn/01-init.md](../shadcn/01-init.md).

`@jjdevhub/theme` w `paths` nie występuje. Gołe nazwy pakietów (`react`, `@jjdevhub/theme`) dalej idą przez `node_modules`.

`baseUrl` ustawione na `src` albo `paths` w postaci `"@/*": ["./*"]` przy innym `baseUrl` rozjedzie się z CLI shadcn. Zostaw parę z bloku powyżej.

### 4. Import w kodzie

Tokeny, bez zmiany nazwy:

```tsx
import { tokens } from '@jjdevhub/theme';
```

Komponent ui, gdy plik już leży w repo (shadcn kopiuje źródło do repozytorium):

```tsx
import { Button } from '@/components/ui/button';
```

To jest `src/Clients/web/src/components/ui/button.tsx`. Sąsiad w tym samym katalogu ekranu zostaje importem względnym (`./AuthForm`). `@/` wskazuje katalog `src`, nie każdy plik obok.

### 5. Sprawdź oba rozwiązywania

Z `src/Clients/web`:

```bash
pnpm exec tsc -p tsconfig.json --noEmit
pnpm build
```

`pnpm build` odpala ten sam `tsc -p tsconfig.json --noEmit`, a potem `vite build`. Skrypt i plugin Tailwinda opisuje [03-pluginy-i-build.md](03-pluginy-i-build.md). Tutaj liczy się podział błędu:

| Objaw | Brakuje |
| --- | --- |
| `tsc`: `Cannot find module '@/components/ui/button'` | `baseUrl` / `paths` w `tsconfig.json` |
| Vite: `Failed to resolve import "@/components/ui/button"` | klucz `'@'` w `resolve.alias` |
| `Failed to resolve import "@jjdevhub/theme"` albo `tsc` nie widzi tej nazwy | alias Vite, zależność `file:` albo `pnpm install` |
| oba narzędzia nie widzą pliku, a aliasy są wpisane | pliku jeszcze nie ma w `src/components/ui/` |

Sam `vite build` przechodzi przy braku `paths`, dopóki bundler znajdzie plik. Sam `tsc` przechodzi przy braku aliasu Vite. Dlatego obie połówki `pnpm build` mają być zielone, gdy w repo jest już komponent ui.

`pnpm test` widzi te same aliasy, bo Vitest bierze `defineConfig` z tego pliku. Co test sprawdza, opisuje [react/04-testy.md](../react/04-testy.md).

## Przypadki użycia

### Import tokenów

Miejsca wzorcowe: [main.tsx](../../../src/Clients/web/src/main.tsx) i [HomeHero.tsx](../../../src/Clients/web/src/app/pages/home/HomeHero.tsx).

Start aplikacji bierze mapę zmiennych CSS:

```tsx
import { cssCustomProperties } from '@jjdevhub/theme';

for (const [name, value] of Object.entries(cssCustomProperties())) {
  document.documentElement.style.setProperty(name, value);
}
```

Jedno wywołanie, na `document.documentElement`, zanim powstanie drzewo Reacta. Hex i skala zostają w `tokens.ts`. Strona czyta je jako zmienne, a docelowo także jako klasy Tailwinda zmapowane z tych samych liczb ([motyw.md](../motyw.md), [tailwind/02-motyw.md](../tailwind/02-motyw.md)).

Komponent, który w JavaScripcie potrzebuje liczby (czas, easing), importuje obiekt:

```tsx
import { tokens } from '@jjdevhub/theme';

const fadeSeconds = tokens.duration.heroFade / 1000;
```

Ścieżka `../../../shared/theme/tokens.ts` z głębi `src/app/pages/` nie wchodzi. Alias i pakiet trzymają ten import przy przenoszeniu pliku.

Telefon czyta ten sam `tokens.ts`. Alias `@/` jest tylko klienta web. Ekran NativeWind nie importuje `@/components/ui`.

### Import komponentu ui

Formularz logowania (`/login`, bez prefiksu języka) składa pola z komponentów w repo:

```tsx
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

export function LoginForm() {
  return (
    <form>
      <Input name="email" type="email" autoComplete="username" />
      <Input name="password" type="password" autoComplete="current-password" />
      <Button type="submit">Zaloguj</Button>
    </form>
  );
}
```

Pliki: `src/Clients/web/src/components/ui/button.tsx` i `input.tsx`. Import z `@/components/ui/button`, nie z `node_modules` i nie przez kilka `../` z `src/app/pages/login/`.

`fetch` na `/api` zostaje w module auth, obok formularza. Alias nie woła sieci. Katalog komponentów, dialog i pusta lista: [shadcn/03-komponenty.md](../shadcn/03-komponenty.md).

## Zasady wyglądu

Alias nie niesie koloru. Liczby są w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Paleta: płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, krój Inter, duży oddech, mało ramek, ciemny hero. Kontrakt skali, odstępów, radiusu i czasów: [motyw.md](../motyw.md).

Import `@jjdevhub/theme` w komponencie jest odczytem tego kontraktu. Drugi hex przy okazji importu nie dochodzi. Import `@/components/ui/button` jest odczytem komponentu, który bierze zmienne spięte z tokenami ([shadcn/02-motyw.md](../shadcn/02-motyw.md)).

Wygląd na stronie nakładają klasy Tailwinda na znacznikach HTML5. Wejście CSS to `src/styles.css`. Tailwind v4 nie używa Sassa.

`@/` nie wskazuje `src/Clients/shared`. Wspólny wygląd webu i telefonu idzie przez `@jjdevhub/theme`. Plik fontu Inter (`@fontsource-variable/inter` w `main.tsx`) zostaje osobnym importem; alias motywu niesie nazwę kroju, nie plik fontu.

## Poza zakresem

- Port `4200` i proxy `/api`, `/health`, `/openapi`, `/scalar`: [01-dev.md](01-dev.md).
- Plugin Reacta, docelowy `@tailwindcss/vite`, skrypt `pnpm build`, kontekst Dockera: [03-pluginy-i-build.md](03-pluginy-i-build.md). Zależność `file:../shared/theme` nadal wymaga kontekstu `src/Clients`. Alias `@/` mieści się w katalogu klienta web.
- `shadcn init`, `components.json`, katalog `src/components/ui`: [shadcn/01-init.md](../shadcn/01-init.md). Użycie na ekranach: [shadcn/03-komponenty.md](../shadcn/03-komponenty.md).
- Mapowanie liczb na `@theme`: [tailwind/02-motyw.md](../tailwind/02-motyw.md). Wejście `src/styles.css`: [tailwind/01-instalacja.md](../tailwind/01-instalacja.md).
- Jeden CSS zamiast arkuszy SCSS: [tailwind/06-css-zamiast-scss.md](../tailwind/06-css-zamiast-scss.md).
- Ekrany telefonu, NativeWind, Reusables. Alias `@/` do klienta mobile nie wchodzi. Instalacja NativeWind: [nativewind/01-instalacja.md](../nativewind/01-instalacja.md).
- Podmiana `@jjdevhub/theme` na `@/theme` albo kopia `tokens.ts` do `src/Clients/web/src`.

## Gotowe gdy

- W `resolve.alias` zostaje `'@jjdevhub/theme': path.resolve(root, '../shared/theme/tokens.ts')`.
- Obok jest `'@': path.resolve(root, 'src')`. `root` dalej pochodzi z `fileURLToPath(new URL('.', import.meta.url))`.
- W `tsconfig.json` jest `"baseUrl": "."` i `"paths": { "@/*": ["./src/*"] }`. `include` zostaje `["src"]`. `@jjdevhub/theme` nie jest w `paths`.
- Zależność `"@jjdevhub/theme": "file:../shared/theme"` zostaje. `exports` pakietu nadal wskazuje `./tokens.ts`.
- Z `src/Clients/web` przechodzą `pnpm exec tsc -p tsconfig.json --noEmit` i `pnpm build`, z dotychczasowym importem `@jjdevhub/theme` oraz z `import { Button } from '@/components/ui/button'`, gdy plik komponentu już jest.
- Sąsiad w katalogu ekranu jest importem względnym. Komponent ui jest importem `@/components/ui/…`.
- W zależnościach nie ma `vite-tsconfig-paths`. Alias `@/` nie wchodzi do `src/Clients/mobile`.
