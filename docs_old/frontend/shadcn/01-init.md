# shadcn: init

Init wstawia CLI shadcn w istniejący klient Vite. Komenda kopiuje źródła komponentów do repo i zapisuje `components.json`, żeby kolejne `add` trafiały w to samo miejsce. React składa HTML, Vite podaje jeden `src/styles.css`, Tailwind v4 daje klasy, a shadcn siedzi na tym samym HTML.

Ten krok kończy się na konfiguracji i jednym komponencie `Button`. Paleta produktu jest w [02-motyw.md](02-motyw.md). Użycie na ekranach jest w [03-komponenty.md](03-komponenty.md).

## Wersje i pakiety

Klient: React 19, Vite 7, TypeScript, pnpm (`packageManager` w `src/Clients/web/package.json`). Tailwind v4 jest już wpięty według [instalacji Tailwinda](../tailwind/01-instalacja.md): pakiety `tailwindcss` i `@tailwindcss/vite`, wejście `src/styles.css` z `@import "tailwindcss"`. Tailwind v4 nie używa Sassa i nie ma `tailwind.config.js`.

CLI bierz z rejestru, bez przypinania wersji w repo:

```bash
pnpm dlx shadcn@latest init --base radix --preset vega --no-monorepo
pnpm dlx shadcn@latest add button
```

Obie komendy idą z katalogu `src/Clients/web`. Tam leży `package.json` klienta. W katalogu głównym repozytorium tego pliku nie ma.

Init dopisuje zależności, których komponenty używają w źródle:

| Pakiet | Po co |
| --- | --- |
| `clsx` | Składanie nazw klas w `cn` |
| `tailwind-merge` | Jedna klasa wygrywa, gdy dwie ustawiają to samo |
| `class-variance-authority` | Warianty `Button` (`variant`, `size`) |
| `lucide-react` | Ikony presetu Vega |
| `tw-animate-css` | Animacje pod Tailwind v4, import w `src/styles.css` |
| `@radix-ui/react-slot` | Dochodzi przy `add button` (`asChild`) |

`init` i `add` aktualizują `src/Clients/web/package.json` i `src/Clients/web/pnpm-lock.yaml`. Źródła komponentów zostają w gicie. W `node_modules` są tylko te pakiety.

Preset **Vega** niesie ikony Lucide i font Inter. Inter jest już w kliencie (`@fontsource-variable/inter` w `src/main.tsx`). Preset **Nova** wciąga Geista — w tym repo go nie wybieraj. Baza prymitywów to **Radix**, więc pole `style` w `components.json` ma być `radix-vega`.

## Ścieżki w repo

Wszystkie ścieżki CLI są względem `src/Clients/web`.

| Plik | Rola |
| --- | --- |
| `src/Clients/web/components.json` | Konfiguracja CLI |
| `src/Clients/web/tsconfig.json` | Alias `@/*` → `./src/*` |
| `src/Clients/web/vite.config.ts` | Ten sam alias dla bundla, obok `@jjdevhub/theme` |
| `src/Clients/web/src/styles.css` | Jedyny CSS. `tailwind.css` w `components.json` wskazuje `src/styles.css` |
| `src/Clients/web/src/lib/utils.ts` | Funkcja `cn` |
| `src/Clients/web/src/components/ui/button.tsx` | Źródło `Button` po `add button` |
| `src/Clients/web/src/app/pages/login/AuthForm.tsx` | Przypadek: przycisk submit |

Alias `@/` oznacza katalog `src` klienta, czyli `src/Clients/web/src`. Import `@/components/ui/button` to plik `src/Clients/web/src/components/ui/button.tsx`. Kontrakt aliasów, łącznie z istniejącym `@jjdevhub/theme`, jest w [aliasach Vite](../vite/02-aliasy.md). Plugin Tailwinda w `vite.config.ts` dokłada [instalacja Tailwinda](../tailwind/01-instalacja.md) i [pluginy Vite](../vite/03-pluginy-i-build.md).

W tym repo jest jeden `tsconfig.json`. Szablon Vite z `tsconfig.app.json` tu nie powstaje. `pnpm build` woła `tsc -p tsconfig.json --noEmit`, więc alias musi być w tym jednym pliku.

## Tutorial

### 1. Wejście CSS

Zanim odpalisz CLI, w `src/Clients/web/src/styles.css` jest przynajmniej:

```css
@import "tailwindcss";
```

Plik jest podpięty w `src/main.tsx`. Gdyby CLI zapytało o globalny CSS, odpowiedź to `src/styles.css`. Wskazanie `styles.scss` psuje ten krok: Tailwind v4 nie kompiluje Sassa, a `components.json` zapamięta złą ścieżkę.

### 2. Alias `@/`

Edytor i `tsc` czytają `src/Clients/web/tsconfig.json`. W `compilerOptions` dochodzą `baseUrl` i `paths`. Reszta opcji zostaje (`strict`, `jsx`, `moduleResolution: bundler`, `noEmit`).

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  }
}
```

Bundler czyta `resolve.alias` w `src/Clients/web/vite.config.ts`. Plik już importuje `node:path` i liczy `root` przez `fileURLToPath`. Dopisz `@` obok aliasu motywu. `defineConfig` zostaje z `vitest/config`, bo w tym samym pliku jest konfiguracja testów. Import `@tailwindcss/vite` dokłada krok Tailwinda, jeśli go jeszcze nie ma.

```ts
resolve: {
  alias: {
    '@': path.resolve(root, 'src'),
    '@jjdevhub/theme': path.resolve(root, '../shared/theme/tokens.ts'),
  },
},
```

`@types/node` nie jest tu potrzebne: `vite.config.ts` już importuje `node:path` i `node:url`.

Sprawdzenie aliasu, zanim poleci CLI: z `src/Clients/web` uruchom `pnpm exec tsc -p tsconfig.json --noEmit`. Błąd „cannot find module `@/`” na tym etapie jeszcze nie wystąpi, bo importu `@/` nie ma. Po `add button` ten sam `tsc` musi ten import rozwiązać.

### 3. Init

Z `src/Clients/web`:

```bash
pnpm dlx shadcn@latest init --base radix --preset vega --no-monorepo
```

Flagi:

- `--base radix` — prymitywy Radix (`@radix-ui/react-slot` przy przycisku).
- `--preset vega` — styl `radix-vega`, ikony Lucide, font Inter. Nazwa presetu to `vega`, nie `radix-vega` i nie `base-nova`.
- `--no-monorepo` — klient jest jednym pakietem, bez workspace’u pnpm w katalogu głównym.
- `--css-variables` jest domyślnie włączone. Zostaw je. [Motyw shadcn](02-motyw.md) podmienia zmienne CSS, a nie klasy wpisane na sztywno w komponentach.

Gdy CLI mimo flag o coś pyta, odpowiedzi są takie:

| Pytanie | Odpowiedź |
| --- | --- |
| Component library | Radix |
| Preset | Vega |
| TypeScript | tak |
| React Server Components | nie |
| Global CSS | `src/styles.css` |
| CSS variables | tak |
| Prefiks klas (`tw-`) | pusty |
| `tailwind.config.js` | pusty |
| Alias komponentów | `@/components` |

`rsc` w zapisanym pliku ma być `false`. Przy `true` CLI dopisuje `"use client"` do każdego komponentu. W Vite ta dyrektywa nic nie daje.

Komendy, które zakładają inny projekt, w tym repo nie wchodzą:

- `pnpm dlx shadcn@latest init --defaults` i flaga `-d` ustawiają szablon Next oraz preset `base-nova`.
- `pnpm dlx shadcn@latest init -t vite` i `pnpm create vite` zakładają nową aplikację. Pakiet `src/Clients/web` już jest.
- `init` z katalogu głównego repozytorium nie widzi `package.json` klienta.

Pole `style` ustala się przy inicjalizacji. Zmiana palety nie jest drugim `init`. Po pierwszym udanym init nie nadpisuj `components.json` flagą `--force`.

### 4. `components.json`

Plik leży obok `package.json`, nie w `src/`. Docelowa treść:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "radix-vega",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/styles.css",
    "baseColor": "neutral",
    "cssVariables": true,
    "prefix": ""
  },
  "iconLibrary": "lucide",
  "rtl": false,
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
```

Znaczenie pól, których CLI używa przy `add`:

- `tailwind.config` jest pustym stringiem. Przy Tailwind v4 konfiguracja kolorów żyje w CSS (`@theme`), a nie w pliku JS.
- `tailwind.css` to `src/styles.css`. Stąd CLI dopisuje zmienne.
- `tailwind.baseColor` równe `neutral` to ziarno CLI (szary start). To nie jest paleta JJDevHub. Liczby produktu spina [02-motyw.md](02-motyw.md) ze [wspólnym kontraktem tokenów](../motyw.md). `baseColor` po init zostaje; podmiana kolorów idzie przez zmienne CSS, bo `cssVariables` jest `true`.
- `tailwind.prefix` jest pusty. Klasy w komponentach to `bg-primary`, bez prefiksu `tw-`.
- `aliases.ui` równe `@/components/ui` decyduje, że `add button` pisze `src/components/ui/button.tsx`.
- `aliases.utils` równe `@/lib/utils` decyduje o imporcie `cn` w każdym komponencie.

CLI może dopisać `menuColor` (`default`) i `menuAccent` (`subtle`). Zostaw je. Pusty obiekt `registries` nie jest potrzebny: wbudowany rejestr shadcn CLI i tak zna.

Alias w `components.json` i `paths` w `tsconfig.json` opisują ten sam korzeń `@/`. Rozjazd (inny alias w JSON niż w `paths`) kończy się importem, którego nie rozwiąże ani `tsc`, ani Vite.

### 5. Pliki obok konfiguracji

**`src/lib/utils.ts`.** Init tworzy `cn`. Komponenty importują ją jako `@/lib/utils`.

```ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

**`src/styles.css`.** Na górze zostaje import Tailwinda. Init dopisuje pod nim import animacji, wariant `dark`, blok `@theme inline` i zmienne na `:root` oraz `.dark`. Nazwy zostaw. Wartości ziarna (neutralny szary start, często OKLCH) podmienia [02-motyw.md](02-motyw.md). Drugiej listy kolorów obok tego bloku nie dopisuj.

Szkielet, który ma zostać w pliku po init (wartości `:root` pochodzą z CLI):

```css
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:is(.dark *));

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
}

:root {
  --radius: 0.625rem;
  /* --background, --foreground, --primary i reszta nazw: ziarno CLI.
     Docelowe wartości: docs/frontend/shadcn/02-motyw.md */
}

.dark {
  /* ten sam zestaw nazw */
}

@layer base {
  * {
    @apply border-border outline-ring/50;
  }
  body {
    @apply bg-background text-foreground;
  }
}
```

`@import "tailwindcss"` zostaje pierwszą linijką. Zmienne nad tym importem psują kolejność warstw Tailwinda v4.

Nazwy, które CLI zwykle dopisuje i których nie usuwaj: `background`, `foreground`, `card`, `card-foreground`, `popover`, `popover-foreground`, `primary`, `primary-foreground`, `secondary`, `secondary-foreground`, `muted`, `muted-foreground`, `accent`, `accent-foreground`, `destructive`, `border`, `input`, `ring`, `chart-1` … `chart-5`, zmienne `sidebar-*`, `radius`. W `@theme inline` każda z nich ma parę `--color-*`, żeby klasy w rodzaju `bg-primary` i `text-muted-foreground` działały.

Font: import `@fontsource-variable/inter` w `src/main.tsx` zostaje. Gdy CLI dopisze w CSS drugi import Intera, zostaw jeden — ten z `main.tsx`. Geista nie dodawaj. Skala i tracking są poza tym plikiem.

### 6. Dodanie button

Gdy `components.json` jest na miejscu, z `src/Clients/web`:

```bash
pnpm dlx shadcn@latest add button
```

CLI czyta `aliases.ui`, ściąga źródło z rejestru i zapisuje `src/Clients/web/src/components/ui/button.tsx`. Dopisuje `@radix-ui/react-slot`, jeśli go jeszcze nie ma. Plik jest zwykłym źródłem w repo: eksportuje `Button` i `buttonVariants`, importuje `cn` z `@/lib/utils` i `Slot` z `@radix-ui/react-slot`. Komentarza „wygenerowane, nie ruszać” nie dodawaj — komponent da się później edytować, ale w tym kroku zostaw go w kształcie z CLI.

Publiczne API, którego używa aplikacja:

```tsx
import { Button } from '@/components/ui/button';
```

`Button` renderuje `<button>`, dopóki nie ustawisz `asChild`. Przyjmuje `variant`, `size`, `className` i zwykłe atrybuty przycisku (`type`, `disabled`). Klasy wariantów są semantyczne (`bg-primary`, `bg-secondary`). Hexa produktu do `button.tsx` nie wpisuj.

Potem, nadal z `src/Clients/web`:

```bash
pnpm exec tsc -p tsconfig.json --noEmit
```

`tsc` ma rozwiązać `@/components/ui/button` i `@/lib/utils`. Bramka pełna to `pnpm build` (kopiuje CV, potem `tsc` i `vite build`).

## Przypadek użycia

Jedyny przypadek tego pliku: przycisk wysłania formularza logowania i rejestracji. Oba ekrany używają `AuthForm` (`src/Clients/web/src/app/pages/login/AuthForm.tsx`). Submit ma zostać przyciskiem formularza, z tą samą etykietą i z blokadą na czas żądania.

```tsx
import { Button } from '@/components/ui/button';

type AuthSubmitProps = {
  label: string;
  pending: boolean;
};

export function AuthSubmit({ label, pending }: AuthSubmitProps) {
  return (
    <Button type="submit" disabled={pending}>
      {label}
    </Button>
  );
}
```

W `AuthForm` w miejscu dotychczasowego `<button type="submit">` stoi `AuthSubmit`. `label` to `pending ? pendingLabel : submitLabel`. `type="submit"` zostaje wprost, `disabled` dostaje `pending`. Wariantu ani `className` z własnym kolorem tu nie ma — wygląd primary opisuje [02-motyw.md](02-motyw.md). Reszta formularza (pola, błąd, `fetch`) zostaje jak w [treści i auth](../react/03-tresc-i-auth.md).

`AuthSubmit` trzyma się reguł komponentu: jeden plik, nazwa jak komponent, eksport nazwany, funkcja. Źródło `button.tsx` z CLI zostaje w kształcie rejestru (własny układ importów i `cva`).

## Zasady wyglądu

`Button` jest znacznikiem `<button>` z klasami Tailwinda. Osobnego arkusza pod przycisk nie ma. Wejście stylów to jeden `src/styles.css`.

Klasy w `button.tsx` zostają semantyczne (`bg-primary`, `text-primary-foreground`, `border-border`). Kolor, radius i font biorą się ze zmiennych, które [02-motyw.md](02-motyw.md) spina z `src/Clients/shared/theme/tokens.ts`. Ziarno `neutral` z init nie jest wyglądem stron.

Do `className` na ekranie nie dokładaj arbitralnego hexa ani drugiej palety. Dodatkowa klasa układu (margines, szerokość) może dojść później; ten krok jej nie wymaga.

Przycisk submit nie dostaje własnej ramki spoza wariantu. Duży oddech formularza jest sprawą układu, nie tego init.

## Poza zakresem

- Paleta, podmiana zmiennych `--background` / `--primary` / `--radius` i odejście od szarego ziarna: [02-motyw.md](02-motyw.md). Liczby źródłowe: [motyw.md](../motyw.md).
- Input, dialog, pusty stan, nawigacja, pełny formularz logowania i późniejszy CRUD: [03-komponenty.md](03-komponenty.md).
- Instalacja `tailwindcss` i `@tailwindcss/vite`, zamiana wejścia na `src/styles.css`: [01-instalacja.md](../tailwind/01-instalacja.md).
- Opis aliasu `@jjdevhub/theme`: [02-aliasy.md](../vite/02-aliasy.md). Tu dochodzi tylko `@/`.
- Ekrany telefonu, NativeWind i React Native Reusables.
- Szablon Next, flaga `--defaults`, nowy projekt z `init -t vite`.
- Katalog wariantów przycisku na kolejnych ekranach. Wystarczy defaultowy `Button` na submit.

## Gotowe gdy

- W `src/Clients/web` jest `components.json` jak wyżej: `style` = `radix-vega`, `rsc` = `false`, `tailwind.config` = `""`, `tailwind.css` = `src/styles.css`, `cssVariables` = `true`, `aliases.ui` = `@/components/ui`.
- `tsconfig.json` mapuje `@/*` na `./src/*`. `vite.config.ts` mapuje `@` na `src` i zostawia `@jjdevhub/theme`. `defineConfig` zostaje z `vitest/config`.
- Jest `src/lib/utils.ts` z `cn` oraz `src/components/ui/button.tsx`. Import `@/components/ui/button` przechodzi w `tsc`.
- `src/styles.css` zaczyna się od `@import "tailwindcss"`, ma `@theme inline` i zmienne CLI. Wartości produktu jeszcze nie są podmienione.
- Submit w `AuthForm` renderuje `Button` z `type="submit"` i `disabled={pending}`.
- Z `src/Clients/web` przechodzi `pnpm build`.
