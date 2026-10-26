# Instalacja

NativeWind v5 na szkielecie `src/Clients/mobile/JJDevHubMobile` (React Native 0.84) podaje klasy Tailwinda v4 komponentom natywnym. Liczby zostają w [`tokens.ts`](../../../src/Clients/shared/theme/tokens.ts). Ten plik wpinia pakiety, PostCSS, Metro, jeden `global.css` i korzeń, który wpisuje `cssCustomProperties()`, zanim cokolwiek się namaluje.

Ekrany telefonu są osobne od weba. Łańcuch weba (React, HTML5, Vite, jeden `src/styles.css`, shadcn, Motion) zostaje przy kliencie web. Telefon bierze ten sam blok `@theme inline` i te same nazwy klas.

## Po co

`className` na `View` i `Text` ma znaczyć to samo co klasa na webie: `bg-canvas`, `text-ink`, `bg-accent`, `font-sans`, `text-body`, `p-5`, `rounded-card`. Bez tego wpięcia Metro zostawia napis na propsie i nie składa arkusza.

Generator dostaje naraz: przypiętą parę pakietów, `postcss.config.mjs`, `metro.config.js` owinięte `withNativewind`, `global.css`, deklarację TypeScript, zależność `@jjdevhub/theme`, `ThemeRoot` i plik kroju `Inter`. Lista kursów, katalog przycisków i przesunięcie hero dochodzą później i zakładają, że te klasy już rozwiązują się do tokenów.

## Wersje i pakiety

Katalog poleceń: `src/Clients/mobile/JJDevHubMobile`. Menedżer: pnpm, jak w README (`pnpm install`, `pnpm start`, `pnpm android`). React szkieletu: `19.2.3`, ta sama linia co web.

| Pakiet | Wersja | Rola |
| --- | --- | --- |
| `react-native` | `0.84` | Szkielet z README. New Architecture jest w tym wydaniu. |
| `nativewind` | `5.0.0-rc.0` | Klasy na komponentach natywnych. Wersja dokładnie ta. |
| `react-native-css` | `3.1.0-rc.0` | Silnik RC. Idzie w parze z NativeWind powyżej. |
| `tailwindcss` | `4.1.12` | Czyta `@theme`. DevDependency, wersja dokładnie ta. |
| `@tailwindcss/postcss` | `4.1.12` | PostCSS szkieletu CLI. DevDependency. |
| `postcss` | ta, której wymaga plugin | DevDependency, przypięta razem z pluginem. |
| `lightningcss` | `1.30.1` | DevDependency, wersja dokładnie ta. |
| `@jjdevhub/theme` | `file:../../shared/theme` | `tokens` i `cssCustomProperties()`. Zero własnych liczb w aplikacji. |

`nativewind@5.0.0-rc.0` wymaga `react-native-css@3.1.0-rc.0`. Paczek nie podmienia się osobno i nie zostawia się ich bez pinu. To wydanie RC: dokumentacja NativeWind sprawdza je na React Native 0.86.3 (Expo). Silnik deklaruje React Native `>= 0.81`, więc 0.84 jest w zakresie. Szkielet zostaje na 0.84. Przejście na Expo i podbicie React Native do 0.86 są poza tym plikiem.

Web mapuje tokeny przez Tailwind v4 i `@theme inline` ([`tailwind/02-motyw.md`](../tailwind/02-motyw.md), [`motyw.md`](../motyw.md)). Telefon używa tej samej linii, więc NativeWind jest z v5. NativeWind v4 zostaje przy Tailwindzie 3 i w tym szkielecie nie występuje.

`react-native-reanimated@4.6` i `react-native-worklets@0.12` dopisuje [`reanimated.md`](../reanimated.md). Ten tutorial ich nie instaluje.

## Ścieżki w repo

Wszystko poniżej, poza tokenami i JSON-em treści, leży w `src/Clients/mobile/JJDevHubMobile/`.

| Plik | Rola |
| --- | --- |
| `package.json` | Pary RC, Tailwind, PostCSS, `lightningcss`, `@jjdevhub/theme` |
| `postcss.config.mjs` | Plugin `@tailwindcss/postcss` |
| `metro.config.js` | `withNativewind`, `watchFolders`, wyłączenie wklejania zmiennych tokenów |
| `babel.config.js` | Preset szkieletu `module:@react-native/babel-preset` |
| `global.css` | Warstwy Tailwinda v4, `@import "nativewind/theme"`, blok `@theme inline` |
| `nativewind-env.d.ts` | Typy `className`. Plik commituje się ze źródłami |
| `src/types/css.d.ts` | `declare module "*.css"` |
| `src/theme/ThemeRoot.tsx` | `vars(cssCustomProperties())` na korzeniu |
| `App.tsx` | Import `./global.css` i próbka klas |
| `react-native.config.js` | Katalog `assets/fonts` |
| `assets/fonts/Inter.ttf` | Twarz, której rodzina to `Inter` |
| [`src/Clients/shared/theme/tokens.ts`](../../../src/Clients/shared/theme/tokens.ts) | Jedyny zapis heksów, pikseli, `em`, milisekund i krzywych |
| `src/Clients/web/src/content/` | JSON `pl` / `en`. Metro go obserwuje, ten plik go nie czyta |

`components.json` z [`reusables.md`](../reusables.md) w polu `tailwind.css` dostaje `global.css`. Drugiego arkusza nie ma. `tailwind.config.js` nie powstaje.

## Tutorial

Katalog roboczy każdej komendy: `src/Clients/mobile/JJDevHubMobile`.

### 1. Pakiety

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm add --save-exact nativewind@5.0.0-rc.0 react-native-css@3.1.0-rc.0
pnpm add -D --save-exact tailwindcss@4.1.12 @tailwindcss/postcss@4.1.12 postcss lightningcss@1.30.1
pnpm add @jjdevhub/theme@file:../../shared/theme
```

W `dependencies` lądują `nativewind`, `react-native-css` i `@jjdevhub/theme`. W `devDependencies` cztery pakiety z drugiej komendy. Eksport `@jjdevhub/theme` (`"."` → `./tokens.ts`) jest tym samym specyfikatorem co na webie: `import { cssCustomProperties } from '@jjdevhub/theme'`.

Gdy `package.json` szkieletu ma `pnpm.onlyBuiltDependencies`, dopisz do tej tablicy `lightningcss`. pnpm 10 pomija skrypt instalacji spoza listy, a binding `lightningcss` jest potrzebny przy składaniu CSS.

`postcss` bierz w wersji, którą resolver ustawi obok `@tailwindcss/postcss@4.1.12`, i przypnij ją `--save-exact` tak jak resztę tej komendy.

### 2. PostCSS

W katalogu aplikacji zapisz `postcss.config.mjs`:

```js
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

Rozszerzenie to `.mjs`. Konfiguracja `tailwind.config.js` z tablicą `content` i presetem `nativewind/preset` należy do NativeWind v4 i tutaj nie powstaje.

### 3. Metro

Szkielet CLI bierze konfigurację z `@react-native/metro-config`. Owinięcie dokłada `withNativewind` (małe `w`). Opcja `input` z v4 odpada: arkusz wchodzi importem z `App.tsx`.

`@jjdevhub/theme` leży poza katalogiem aplikacji (`../../shared/theme`). JSON treści, którego użyje lista kursów, leży w `../../web/src/content`. Oba katalogi dopisujesz do `watchFolders`, żeby Metro widział pliki za symlinkiem `file:` i za granicą aplikacji.

Kompilator NativeWind potrafi wkleić wartość zmiennej w styl natywny w chwili buildu. Zmienne z `cssCustomProperties()` mają zostać `var(--…)` do czasu, aż `ThemeRoot` wpisze rekord serializera. Dlatego `inlineVariables.exclude` zawiera dokładnie klucze tego rekordu.

```js
const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const { withNativewind } = require('nativewind/metro');

const projectRoot = __dirname;

/** Klucze cssCustomProperties() z tokens.ts. Nowy klucz serializera dopisujesz tutaj. */
const tokenVariables = [
  '--canvas',
  '--white',
  '--ink',
  '--muted',
  '--accent',
  '--dark-chapter-bg',
  '--dark-chapter-fg',
  '--font-family',
  '--font-display',
  '--font-h1',
  '--font-h2',
  '--font-h3',
  '--font-h4',
  '--font-body',
  '--font-small',
  '--font-caption',
  '--tracking-display',
  '--tracking-h1',
  '--tracking-h2',
  '--tracking-h3',
  '--tracking-h4',
  '--tracking-body',
  '--tracking-small',
  '--tracking-caption',
  '--space-1',
  '--space-2',
  '--space-3',
  '--space-4',
  '--space-5',
  '--space-6',
  '--space-7',
  '--space-8',
  '--space-9',
  '--space-10',
  '--space-11',
  '--space-12',
  '--radius-sm',
  '--radius-md',
  '--radius-lg',
  '--radius-card',
  '--radius-pill',
  '--duration-reveal',
  '--duration-reveal-fast',
  '--duration-hero-pin',
  '--duration-hero-fade',
  '--duration-nav',
  '--easing-reveal',
  '--easing-hero',
  '--easing-standard',
];

const config = mergeConfig(getDefaultConfig(projectRoot), {
  watchFolders: [
    path.resolve(projectRoot, '../../shared/theme'),
    path.resolve(projectRoot, '../../web/src/content'),
  ],
});

module.exports = withNativewind(config, {
  inlineVariables: { exclude: tokenVariables },
});
```

### 4. Babel

Preset szkieletu zostaje. Wtyczkę przepisywania importów dokłada Metro (`globalClassNamePolyfill` w `withNativewind` jest włączony domyślnie). `babel.config.js` po tym kroku:

```js
module.exports = {
  presets: ['module:@react-native/babel-preset'],
};
```

[`reanimated.md`](../reanimated.md) dopisze później `react-native-reanimated/plugin` jako ostatni wpis `plugins`. Ten krok tablicy `plugins` nie dodaje.

### 5. `global.css`

Wejście telefonu stoi w katalogu aplikacji i nazywa się `global.css`. Warstwy są rozdzielone tak, jak wymaga NativeWind v5: motyw i preflight w swoich warstwach, utilities bez warstwy. Jedna linia `@import "tailwindcss"` na telefonie spycha utilities pod domyślne style i klasy cichną, choć build przechodzi. Na webie ta jedna linia zostaje, bo tam arkusz składa plugin Vite ([`tailwind/01-instalacja.md`](../tailwind/01-instalacja.md)).

Blok `@theme inline` jest ten sam co w [`motyw.md`](../motyw.md). Słowo `inline` jest obowiązkowe: klasa dostaje `var(--canvas)`, a heks zostaje w rekordzie `cssCustomProperties()`. Literału koloru, piksela, `ms` i `cubic-bezier` w tym pliku nie ma.

`@source` obejmuje `App.tsx` i `src/**/*.{ts,tsx}` tego szkieletu. Skaner ma widzieć próbkę, późniejsze ekrany i pliki skopiowane do `src/components`. Źródeł z `src/Clients/web` tu nie dopisuj.

```css
@import "tailwindcss/theme.css" layer(theme);
@import "tailwindcss/preflight.css" layer(base);
@import "tailwindcss/utilities.css";

@import "nativewind/theme";

@source "./App.tsx";
@source "./src/**/*.{ts,tsx}";

@theme inline {
  --color-*: initial;
  --color-canvas: var(--canvas);
  --color-white: var(--white);
  --color-ink: var(--ink);
  --color-muted: var(--muted);
  --color-accent: var(--accent);
  --color-dark-chapter: var(--dark-chapter-bg);
  --color-dark-chapter-fg: var(--dark-chapter-fg);

  --font-sans: var(--font-family), sans-serif;

  --text-*: initial;
  --text-display: var(--font-display);
  --text-h1: var(--font-h1);
  --text-h2: var(--font-h2);
  --text-h3: var(--font-h3);
  --text-h4: var(--font-h4);
  --text-body: var(--font-body);
  --text-small: var(--font-small);
  --text-caption: var(--font-caption);

  --tracking-*: initial;
  --tracking-display: var(--tracking-display);
  --tracking-h1: var(--tracking-h1);
  --tracking-h2: var(--tracking-h2);
  --tracking-h3: var(--tracking-h3);
  --tracking-h4: var(--tracking-h4);
  --tracking-body: var(--tracking-body);
  --tracking-small: var(--tracking-small);
  --tracking-caption: var(--tracking-caption);

  --spacing: initial;
  --spacing-1: var(--space-1);
  --spacing-2: var(--space-2);
  --spacing-3: var(--space-3);
  --spacing-4: var(--space-4);
  --spacing-5: var(--space-5);
  --spacing-6: var(--space-6);
  --spacing-7: var(--space-7);
  --spacing-8: var(--space-8);
  --spacing-9: var(--space-9);
  --spacing-10: var(--space-10);
  --spacing-11: var(--space-11);
  --spacing-12: var(--space-12);

  --radius-*: initial;
  --radius-sm: var(--radius-sm);
  --radius-md: var(--radius-md);
  --radius-lg: var(--radius-lg);
  --radius-card: var(--radius-card);
  --radius-pill: var(--radius-pill);

  --ease-*: initial;
  --ease-reveal: var(--easing-reveal);
  --ease-hero: var(--easing-hero);
  --ease-standard: var(--easing-standard);

  --transition-duration-*: initial;
  --transition-duration-reveal: var(--duration-reveal);
  --transition-duration-reveal-fast: var(--duration-reveal-fast);
  --transition-duration-hero-pin: var(--duration-hero-pin);
  --transition-duration-hero-fade: var(--duration-hero-fade);
  --transition-duration-nav: var(--duration-nav);
}
```

Import `nativewind/theme` dokłada skalę `elevation`, warianty `ios:` / `android:` / `native:` i domyślną rodzinę platformy (`System` na iOS, `SystemAndroid` na Androidzie). Linia `--font-sans` w bloku powyżej wskazuje `var(--font-family)`. Po `ThemeRoot` rodzina klasy `font-sans` to string z tokenu.

Dyrektywy `@tailwind base`, `@tailwind components` i `@tailwind utilities` są z v3 i w tym pliku ich nie ma.

Sprawdzenie, że arkusz nie niesie drugiej kopii liczb:

```bash
rg -n "#[0-9a-fA-F]{3,8}|[0-9]+px|[0-9]+ms|cubic-bezier" src/Clients/mobile/JJDevHubMobile/global.css
```

Po wklejeniu bloku komenda nie znajduje trafień.

### 6. TypeScript

W katalogu aplikacji zapisz `nativewind-env.d.ts`. Nazwa jest dokładnie taka. Plik `nativewind.d.ts` TypeScript pominie.

```ts
/// <reference types="react-native-css/types" />

// NOTE: This file should not be edited and should be committed with your source code.
// It is generated by react-native-css. If you need to move or disable this file,
// please see the documentation.
```

`tsconfig.json` szkieletu obejmuje ten plik (`include` z `nativewind-env.d.ts` albo wzorzec, który go łapie). Treści pliku się nie edytuje.

Gdy kompilator zgłosi import `./global.css`, dopisz osobną deklarację `src/types/css.d.ts` i upewnij się, że `tsconfig` ją widzi:

```ts
declare module '*.css';
```

### 7. Korzeń zmiennych

`cssCustomProperties()` dokleja jednostki do pól `tokens` (`px`, `em`, `ms`, `cubic-bezier`, surowy heks). `ThemeRoot` wpisuje cały rekord, zanim powstanie próbka i zanim powstanie jakikolwiek ekran. RC 5.0.0-rc.0 eksportuje `vars` z `nativewind`. Słownik to zwrotka serializera, jeden do jednego.

`src/theme/ThemeRoot.tsx`:

```tsx
import type { ReactNode } from 'react';
import { View } from 'react-native';
import { vars } from 'nativewind';
import { cssCustomProperties } from '@jjdevhub/theme';

const themeVars = vars(cssCustomProperties());

export function ThemeRoot({ children }: { children: ReactNode }) {
  return (
    <View style={themeVars} className="flex-1">
      {children}
    </View>
  );
}
```

`className="flex-1"` trzyma drzewo w oknie. Kolorów na tym widoku nie ma: tło i pismo ustawiają klasy niżej, już z rozwiązanymi zmiennymi.

`themeVars` powstaje raz, przy załadowaniu modułu. Heksa w `style={{ backgroundColor: '…' }}` tu nie ma.

### 8. Krój Inter

`tokens.font.family` to `'Inter'`. Klasa `font-sans` czyta `var(--font-family)`. Plik twarzy leży w aplikacji, a zarejestrowana rodzina na Androidzie i na iOS nazywa się dokładnie `Inter` (na Androidzie rodziną jest nazwa pliku bez rozszerzenia, więc plik to `Inter.ttf`; na iOS wewnętrzna nazwa twarzy to `Inter`).

`react-native.config.js` w katalogu aplikacji:

```js
module.exports = {
  assets: ['./assets/fonts'],
};
```

Potem:

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm exec react-native-asset
```

Tokeny nie mają grubości ani `line-height`. Jedna twarz `Inter` wystarcza do `font-sans`. Oś zmiennej i waga 650 zostają przy webie ([`tailwind/04-typografia.md`](../tailwind/04-typografia.md)).

### 9. Próbka w `App.tsx`

Import arkusza stoi w pliku komponentu korzenia, obok `ThemeRoot`. Plik, który woła `AppRegistry.registerComponent` (`index.js`), tego importu nie dostaje: Fast Refresh arkusza urywa się, gdy CSS wchodzi z rejestracji.

Próbka sprawdza potok. To jeden widok na czas instalacji, z klasami tokenów. Ekranów produktu tu nie ma.

```tsx
import './global.css';
import { Text, View } from 'react-native';
import { ThemeRoot } from './src/theme/ThemeRoot';

function TokenProbe() {
  return (
    <View className="flex-1 items-center justify-center bg-canvas">
      <Text className="font-sans text-body tracking-body text-ink">JJDevHub</Text>
      <View className="mt-4 rounded-pill bg-accent px-5 py-3">
        <Text className="font-sans text-small tracking-small text-white">Dalej</Text>
      </View>
    </View>
  );
}

export default function App() {
  return (
    <ThemeRoot>
      <TokenProbe />
    </ThemeRoot>
  );
}
```

Oczekiwane liczby, wszystkie z `tokens`:

| Klasa na próbce | Pole | Wartość po serializerze |
| --- | --- | --- |
| `bg-canvas` | `color.canvas` | `#f5f5f7` |
| `text-ink` | `color.ink` | `#1d1d1f` |
| `font-sans` | `font.family` | `Inter` |
| `text-body` | `font.size.body` | `17px` |
| `tracking-body` | `font.tracking.body` | `-0.014em` |
| `mt-4` | `space.4` | `16px` |
| `bg-accent` | `color.accent` | `#0071e3` |
| `px-5` | `space.5` | `24px` |
| `py-3` | `space.3` | `12px` |
| `rounded-pill` | `radius.pill` | `9999px` |
| `text-small` | `font.size.small` | `14px` |
| `tracking-small` | `font.tracking.small` | `-0.006em` |
| `text-white` | `color.white` | `#ffffff` |

`px-5` ma 24px, bo `--spacing` jest `initial`, a `--spacing-5` czyta `--space-5`. Domyślne 20px Tailwinda (`0.25rem * 5`) po tym bloku nie obowiązuje.

### 10. Uruchomienie

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm start --reset-cache
```

Drugi terminal:

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm android
```

Na ekranie widać płótno `#f5f5f7`, napis „JJDevHub” w Interze, 17px, kolor `#1d1d1f`, i kapsułę `#0071e3` z białym „Dalej”. Padding poziomy kapsuły ma 24px. Czerwony ekran Metro na imporcie `@jjdevhub/theme` albo `./global.css` znaczy, że krok 3 albo 9 jest niekompletny. Po zmianie `metro.config.js` lub `babel.config.js` Metro wstaje z `--reset-cache`.

## Mapowanie tych samych liczb

Kontrakt pól, jednostek i nazw jest w [`motyw.md`](../motyw.md). Tutaj jest tylko przekład na telefon: klasa → zmienna w `@theme inline` → klucz `cssCustomProperties()` → pole `tokens`. Heks i piksel powstają w `tokens.ts`. Arkusz trzyma `var(--…)`.

`color.darkChapter.foreground` i `color.canvas` mają dziś ten sam heks `#f5f5f7`. To dwa pola. `radius.card` i `radius.lg` mają dziś `18`. To dwa klucze.

### Kolory

| Klasa | Zmienna klasy | Klucz serializera | Pole | Liczba |
| --- | --- | --- | --- | --- |
| `bg-canvas`, `text-canvas` | `--color-canvas` | `--canvas` | `color.canvas` | `#f5f5f7` |
| `bg-white`, `text-white` | `--color-white` | `--white` | `color.white` | `#ffffff` |
| `bg-ink`, `text-ink` | `--color-ink` | `--ink` | `color.ink` | `#1d1d1f` |
| `bg-muted`, `text-muted` | `--color-muted` | `--muted` | `color.muted` | `#6e6e73` |
| `bg-accent`, `text-accent` | `--color-accent` | `--accent` | `color.accent` | `#0071e3` |
| `bg-dark-chapter` | `--color-dark-chapter` | `--dark-chapter-bg` | `color.darkChapter.background` | `#000000` |
| `text-dark-chapter-fg`, `bg-dark-chapter-fg` | `--color-dark-chapter-fg` | `--dark-chapter-fg` | `color.darkChapter.foreground` | `#f5f5f7` |

Po `--color-*: initial` zostaje te siedem nazw. `bg-black` nie jest tłem hero. Tło ciemnego pola to `bg-dark-chapter`. `bg-blue-600`, `bg-zinc-100` i reszta domyślnej palety po resecie nie istnieją.

### Pismo

`--font-sans` → `--font-family` → `font.family` → `Inter`.

Rozmiar i tracking mają ten sam klucz i są osobnymi klasami. W obiekcie nie ma `line-height` ani grubości, więc blok nie deklaruje `--leading-*` ani `--text-*--line-height`.

| Klucz | `text-*` | px | `tracking-*` | em |
| --- | --- | --- | --- | --- |
| `display` | `text-display` | 80 | `tracking-display` | -0.015 |
| `h1` | `text-h1` | 56 | `tracking-h1` | -0.012 |
| `h2` | `text-h2` | 40 | `tracking-h2` | -0.01 |
| `h3` | `text-h3` | 28 | `tracking-h3` | -0.008 |
| `h4` | `text-h4` | 21 | `tracking-h4` | -0.005 |
| `body` | `text-body` | 17 | `tracking-body` | -0.014 |
| `small` | `text-small` | 14 | `tracking-small` | -0.006 |
| `caption` | `text-caption` | 12 | `tracking-caption` | 0 |

Zmienne rozmiaru w arkuszu to `--text-h1` → `--font-h1` i dalej analogicznie. Zmienne trackingu to `--tracking-h1` → `--tracking-h1` z serializera (ta sama nazwa; `inline` wstawia odwołanie do środka klasy). Po `--text-*: initial` i `--tracking-*: initial` odpadają `text-sm`, `text-base`, `text-xl`, `tracking-tight` i `tracking-normal`.

### Odstępy

Mnożnik `--spacing` jest `initial`. Każdy klucz `1`–`12` ma `--spacing-N: var(--space-N)`. Ten sam piksel stoi za paddingiem, marginesem, `gap`, `w-*` i `h-*`.

| Klucz | px | Przykład |
| --- | --- | --- |
| `1` | 4 | `p-1` |
| `2` | 8 | `p-2` |
| `3` | 12 | `p-3` |
| `4` | 16 | `p-4`, `mt-4` |
| `5` | 24 | `px-5`, `py-5` |
| `6` | 32 | `mb-6` |
| `7` | 48 | `pt-7`, `pb-7` |
| `8` | 64 | `mb-8` |
| `9` | 80 | `gap-9` |
| `10` | 96 | `p-10` |
| `11` | 128 | `py-11` |
| `12` | 160 | `p-12` |

Klucze `1`–`4` pokrywają się z krokiem 4px. Od `5` klasa o tej cyfrze oznacza token, nie drabinkę `0.25rem`. Klucza `0` w tokenach nie ma. Który klucz na liście kursów, decyduje [`02-ekrany.md`](02-ekrany.md). Układ weba jest w [`tailwind/03-uklad.md`](../tailwind/03-uklad.md).

### Promień

| Klasa | Pole | px |
| --- | --- | --- |
| `rounded-sm` | `radius.sm` | 8 |
| `rounded-md` | `radius.md` | 12 |
| `rounded-lg` | `radius.lg` | 18 |
| `rounded-card` | `radius.card` | 18 |
| `rounded-pill` | `radius.pill` | 9999 |

Domyślne `rounded-sm` Tailwinda to `0.25rem` (4px), a token `sm` to 8px. Po `--radius-*: initial` zostaje pięć klas z tabeli. `rounded-full` po resecie nie istnieje. Karta używa `rounded-card`.

### Czas i krzywa

Czas w CSS to `--transition-duration-*`, stąd klasa `duration-*`. Krzywa to `--ease-*`, a właściwość dokumentu zostaje `--easing-*`. W JS Motion i Reanimated biorą liczbę i krotkę z `tokens`, nie te klasy. Ten plik tylko rezerwuje nazwy.

| Klasa | Pole | Wartość |
| --- | --- | --- |
| `duration-reveal` | `duration.reveal` | `700ms` |
| `duration-reveal-fast` | `duration.revealFast` | `400ms` |
| `duration-hero-pin` | `duration.heroPin` | `1200ms` |
| `duration-hero-fade` | `duration.heroFade` | `600ms` |
| `duration-nav` | `duration.nav` | `250ms` |
| `ease-reveal` | `easing.reveal` | `cubic-bezier(0.25, 0.1, 0.25, 1)` |
| `ease-hero` | `easing.hero` | `cubic-bezier(0.22, 1, 0.36, 1)` |
| `ease-standard` | `easing.standard` | `cubic-bezier(0.4, 0, 0.2, 1)` |

Domyślne `duration-150` po resecie nie istnieje.

## Przypadki użycia

### Próbka po wpięciu

`TokenProbe` z kroku 9 wstaje na Androidzie. Tło okna to `#f5f5f7`, napis jest Interem 17px w kolorze `#1d1d1f`, kapsuła jest `#0071e3` z paddingiem poziomym 24px i pionowym 12px, promień to 9999px, podpis kapsuły to 14px i `#ffffff`. Żadna z tych liczb nie stoi w `className` ani w `global.css`.

### Ten sam akcent co web

Kapsuła próbki używa `bg-accent` i `text-white`. Webowy przycisk z [`motyw.md`](../motyw.md) używa tych samych nazw i czyta `--accent` → `#0071e3`. Telefon nie dostaje innego niebieskiego. Gdy styl musi być obiektem (później Reanimated), źródłem jest `tokens.color.accent`, nie heks wpisany w komponencie.

### Klasy ciemnego pola

`bg-dark-chapter` rozwiązuje się do `#000000` (`color.darkChapter.background`). `text-dark-chapter-fg` rozwiązuje się do `#f5f5f7` (`color.darkChapter.foreground`). `text-display` to 80px, `tracking-display` to `-0.015em`, `py-11` to 128px. Ekran, który składa z tego hero nad listą, jest w [`reanimated.md`](../reanimated.md). Ten plik hero nie buduje.

### Import spoza katalogu aplikacji

`ThemeRoot` importuje `@jjdevhub/theme`. Metro startuje bez błędu „unable to resolve”, bo zależność `file:` jest w `package.json`, a `watchFolders` obejmuje `src/Clients/shared/theme`. Ten sam wpis obserwuje `src/Clients/web/src/content`, żeby późniejszy odczyt `pl.json` i `en.json` z listy kursów ([`02-ekrany.md`](02-ekrany.md)) nie wymagał drugiej konfiguracji Metro.

## Zasady wyglądu

Płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, biel `#ffffff`, muted `#6e6e73`, krój `Inter`. Duży oddech bierze `space` od `7` w górę. Mało ramek: w tokenach nie ma koloru obrysu, więc próbka i późniejsze karty oddzielają się płótnem, bielą i `rounded-card`.

Klasy nazywają klucze z tabeli. `bg-[#0071e3]`, `text-[#1d1d1f]`, `text-[17px]`, `p-[24px]`, `rounded-[18px]`, `tracking-[-0.014em]` i `duration-[250ms]` są drugą kopią palety. Alfa istniejącego tokenu (`bg-canvas/70`, `text-ink/80`) zostaje przy tym samym polu.

Tło jest kryjące. W klasach szkieletu nie ma `backdrop-blur` ani `backdrop-filter`. Ekran web i ekran telefonu to osobne pliki. Jeden akcent obowiązuje oba klienty. Intranet, gdy wejdzie do tego samego klienta, używa `bg-accent` i reszty tej mapy.

`flex-1`, `items-center`, `justify-center` i `active:opacity-80` zostają z rdzenia Tailwinda. To nie jest druga skala kolorów ani odstępów.

## Poza zakresem

- Lista kursów, pusty stan i `FlatList`: [`02-ekrany.md`](02-ekrany.md).
- Przycisk, pole, karta i formularz logowania kopiowane do repo: [`reusables.md`](../reusables.md). Pole `tailwind.css` wskazuje `global.css` z tego pliku.
- Przesunięcie hero, Reanimated i Worklets: [`reanimated.md`](../reanimated.md).
- Kontrakt liczb i pętla na `documentElement` weba: [`motyw.md`](../motyw.md).
- Plugin Vite, `src/styles.css` i pierwsza klasa shellu: [`tailwind/01-instalacja.md`](../tailwind/01-instalacja.md).
- Skład Inter Variable, leading i waga na webie: [`tailwind/04-typografia.md`](../tailwind/04-typografia.md).
- Nav, siatka i szerokość artykułu weba: [`tailwind/03-uklad.md`](../tailwind/03-uklad.md).
- Hover, focus, disabled i `prefers-reduced-motion` weba: [`tailwind/05-stany.md`](../tailwind/05-stany.md).
- shadcn, Motion, Tamagui, Sass, drugi klient intranetu.
- Preset `nativewind/babel`, `jsxImportSource` i `tailwind.config.js`.

## Gotowe gdy

- W `src/Clients/mobile/JJDevHubMobile` są `nativewind@5.0.0-rc.0`, `react-native-css@3.1.0-rc.0`, `tailwindcss@4.1.12`, `@tailwindcss/postcss@4.1.12`, `lightningcss@1.30.1` i `@jjdevhub/theme` z `file:../../shared/theme`.
- `metro.config.js` woła `withNativewind`, obserwuje katalog tokenów i `src/Clients/web/src/content`, a `inlineVariables.exclude` pokrywa klucze `cssCustomProperties()`.
- `global.css` ma trzy importy warstw, `@import "nativewind/theme"` i blok `@theme inline` z samymi `var(--…)`. Komenda `rg` z kroku 5 nie znajduje heksa ani piksela w tym pliku.
- `App.tsx` importuje `./global.css`. `ThemeRoot` maluje drzewo po `vars(cssCustomProperties())`. Plik rejestracji `AppRegistry` arkusza nie importuje.
- `assets/fonts/Inter.ttf` jest zlinkowany, a `font-sans` rozwiązuje się do rodziny `Inter`.
- Próbka na Androidzie pokazuje płótno `#f5f5f7`, tekst `#1d1d1f` w 17px i kapsułę `#0071e3` z `px-5` równym 24px.
- `bg-dark-chapter` to `#000000`, `text-body` to 17px, `rounded-card` to 18px, `duration-nav` to 250ms. Ekranów listy i hero w tym kroku nie ma.
