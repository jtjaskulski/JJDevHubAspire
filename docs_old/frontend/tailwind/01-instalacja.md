# Instalacja

Tailwind CSS 4 wchodzi do klienta web jako plugin Vite. Jedno wejście to `src/Clients/web/src/styles.css` z linijką `@import "tailwindcss"`. Dziś [src/main.tsx](../../../src/Clients/web/src/main.tsx) wciąga [src/styles.scss](../../../src/Clients/web/src/styles.scss); ten plik podmienia ten import i stawia pierwszą klasę na shellu.

Łańcuch webu: React składa HTML5, Vite podaje jeden CSS, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Ten plik kończy się na działającym potoku klas. Kolory i `@theme` opisuje [02-motyw.md](02-motyw.md) oraz [motyw.md](../motyw.md). Odstępy, nav i siatkę opisuje [03-uklad.md](03-uklad.md). Zejście z arkuszy `*.scss` i pakietu `sass` opisuje [06-css-zamiast-scss.md](06-css-zamiast-scss.md).

## Po co

Kolejne pliki katalogu dopisują klasy w JSX. Bez tego wpięcia Vite zapisze te nazwy jako atrybut `class` i nie wyemituje reguł. Generator ma więc najpierw dostać cztery rzeczy naraz: pakiety linii 4, plugin w [vite.config.ts](../../../src/Clients/web/vite.config.ts), arkusz `src/styles.css` i import tego arkusza z `main.tsx`.

Dowód, że potok żyje, jest jeden: klasa `min-h-svh` na korzeniu [Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx). W przeglądarce korzeń ma `min-height: 100svh`, a reguła pochodzi z arkusza złożonego przez plugin. Reszta wyglądu shellu dochodzi później.

## Wersje i pakiety

Katalog poleceń: `src/Clients/web`. Menedżer: pnpm `10.33.0` (`packageManager` w [package.json](../../../src/Clients/web/package.json)).

| Pakiet | Gdzie jest | Rola przy instalacji |
| --- | --- | --- |
| `vite` | `^7.1.9`, już w `devDependencies` | Serwuje dev i składa build. Wersja zostaje. |
| `@vitejs/plugin-react` | `^5.0.4`, już w `devDependencies` | Zostaje pierwszy w tablicy `plugins`. |
| `tailwindcss` | docelowo `devDependencies`, linia 4 | Silnik klas. Ten sam numer co plugin. |
| `@tailwindcss/vite` | docelowo `devDependencies`, linia 4 | Plugin, który rozwija `@import "tailwindcss"`. |
| `@tailwindcss/oxide` | zależność `tailwindcss` | Natywny skaner. pnpm 10 musi móc odpalić jego skrypt instalacji. |
| `lightningcss` | zależność pluginu | Optymalizacja CSS przy buildzie produkcyjnym. Ten sam wymóg co oxide. |
| `sass` | `^1.93.2`, już w `devDependencies` | Zostaje do [06-css-zamiast-scss.md](06-css-zamiast-scss.md). Plugin Tailwinda go nie woła. |

`pnpm add -D` bierze aktualną linię 4 z rejestru. Oba pakiety Tailwinda mają ten sam numer. Vite 7 z tego repozytorium jest zgodny z `@tailwindcss/vite` 4. Podbijanie Vite do 8 nie jest częścią instalacji.

Wejście v4 to CSS. Dyrektywy `@tailwind base`, `@tailwind components` i `@tailwind utilities` należą do v3 i w tym arkuszu nie występują. Konfiguracja `tailwind.config.js` z tablicą `content` też nie powstaje. Osobny `postcss.config.js` i pakiet `@tailwindcss/postcss` nie wchodzą obok pluginu Vite: CSS przeszedłby przez dwa kompilatory.

`pnpm.onlyBuiltDependencies` w `package.json` klienta dziś dopuszcza skrypty instalacji tylko dla `esbuild` i `@parcel/watcher`. Przy pnpm 10.33 skrypt spoza tej listy jest pomijany. `@tailwindcss/oxide` i `lightningcss` dopisujesz do tej samej tablicy. Inaczej dev i `vite build` nie załadują natywnego bindingu.

Bramka `pnpm build`, lockfile, Docker i CI są w [vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md). Ten plik kończy się na lokalnym dowodzie klasy.

## Ścieżki w repo

| Ścieżka | Rola w tym pliku |
| --- | --- |
| [src/Clients/web/package.json](../../../src/Clients/web/package.json) | `devDependencies` i `pnpm.onlyBuiltDependencies` |
| [src/Clients/web/pnpm-lock.yaml](../../../src/Clients/web/pnpm-lock.yaml) | Lockfile po `pnpm add` |
| [src/Clients/web/vite.config.ts](../../../src/Clients/web/vite.config.ts) | `plugins: [react(), tailwindcss()]`. `defineConfig` zostaje z `vitest/config`. |
| [src/Clients/web/index.html](../../../src/Clients/web/index.html) | Zostaje ze skryptem `/src/main.tsx`. Linku do CSS w `<head>` nie ma. |
| [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) | Dziś `import './styles.scss'`. Docelowo `import './styles.css'`. |
| [src/Clients/web/src/styles.scss](../../../src/Clients/web/src/styles.scss) | Obecne wejście globalne. Po podmianie importu Vite go nie wciąga. Usunięcie pliku jest w [06-css-zamiast-scss.md](06-css-zamiast-scss.md). |
| `src/Clients/web/src/styles.css` | Nowe jedyne wejście CSS aplikacji |
| [src/Clients/web/src/app/Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) | Pierwsza klasa, na korzeniu |
| [src/Clients/web/src/vite-env.d.ts](../../../src/Clients/web/src/vite-env.d.ts) | `vite/client` typuje boczny import CSS, więc `tsc` przyjmuje `import './styles.css'` |

Alias `@jjdevhub/theme`, port `4200`, proxy i blok `test` w `vite.config.ts` zostają. Dev opisuje [vite/01-dev.md](../vite/01-dev.md).

## Tutorial

Katalog roboczy komend: `src/Clients/web`.

### 1. Pakiety

```bash
cd src/Clients/web
pnpm add -D tailwindcss @tailwindcss/vite
```

W `package.json` dopisz natywne paczki do allowlisty, obok wpisów, które już tam są:

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

Potem:

```bash
pnpm install
```

Gdy pnpm wypisze, że pominął skrypty `@tailwindcss/oxide` albo `lightningcss`, nazwy w tablicy są niepełne albo instalacja poszła przed zapisem allowlisty. Popraw tablicę i uruchom `pnpm install` jeszcze raz. `pnpm-lock.yaml` zostaje w gicie; CI i Docker instalują go z `--frozen-lockfile` ([vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md)).

### 2. Plugin w Vite

W [vite.config.ts](../../../src/Clients/web/vite.config.ts) `defineConfig` jest importowany z `vitest/config`, bo w tym samym pliku siedzi blok `test`. Ten import zostaje. Dopisujesz import pluginu i drugie wywołanie w tablicy. Kolejność: najpierw `react()`, potem `tailwindcss()`.

```ts
import tailwindcss from '@tailwindcss/vite';
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

Reszta obiektu — `resolve.alias` na `tokens.ts`, `server.port` `4200`, proxy i `test` — zostaje tak, jak jest w pliku. Pełny kształt po wpięciu, razem z bramką `pnpm build`, jest w [vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md).

Plugin czyta klasy z grafu modułów Vite, od `index.html` przez `/src/main.tsx`. Osobna tablica ścieżek `content` nie powstaje. Dyrektywa `@source` też nie: pliki shellu i stron są w tym grafie, bo komponenty są importowane. Skan telefonu z `src/Clients/mobile` do tego arkusza nie należy; NativeWind ma własny tutorial w [nativewind/01-instalacja.md](../nativewind/01-instalacja.md).

Skaner bierze pełne literały w `className` i w funkcji, która zwraca gotową nazwę klasy. Nazwa złożona w runtime ze sklejonych fragmentów nie wchodzi do CSS. W shellu pierwsza klasa jest więc wpisana w całości: `min-h-svh`.

Zmiana `vite.config.ts` wymaga nowego procesu. Działający `pnpm start` zatrzymujesz i odpalasz ponownie. Sam hot reload konfiguracji nie przeładowuje.

### 3. Arkusz `src/styles.css`

Tworzysz `src/Clients/web/src/styles.css`. Na tym etapie plik ma jedną linię:

```css
@import "tailwindcss";
```

Import stoi na początku pliku. Plugin rozwija go w warstwy Tailwinda v4: domyślny motyw, preflight i klasy narzędziowe, których skaner faktycznie użył. Do bundla nie wpada cały katalog klas, tylko te widziane w grafie.

W tym pliku zostaje sam import. Blok `@theme` dopisuje do tego samego arkusza [02-motyw.md](02-motyw.md). Drugiego pliku CSS dla motywu, układu albo komponentu nie zakładasz. `@import` arkusza `*.scss` do `styles.css` nie wchodzi: plugin Vite Tailwinda kompiluje CSS, a nie Sass. Importy `*.scss` przy komponentach, dopóki istnieją, Vite obsługuje osobno dzięki pakietowi `sass`. Ich zejście jest w [06-css-zamiast-scss.md](06-css-zamiast-scss.md).

[index.html](../../../src/Clients/web/index.html) zostaje z jednym skryptem modułu. Vite sam wstawi do wynikowego HTML odwołanie do CSS powstałego z grafu `main.tsx`. Ręczny `<link>` do `styles.css` w `<head>` dubluje wejście.

### 4. Podmiana wejścia

W [src/main.tsx](../../../src/Clients/web/src/main.tsx) import kroju zostaje przed arkuszem. Zmieniasz sam arkusz:

```tsx
import '@fontsource-variable/inter';
import './styles.css';
```

`import './styles.scss'` schodzi. Pętla `cssCustomProperties()` z `@jjdevhub/theme` zostaje w tym pliku: to ustawienie zmiennych na `<html>`, a nie drugie wejście CSS. Czy zostaje po `@theme`, rozstrzyga [02-motyw.md](02-motyw.md).

Pliku `styles.scss` ten krok nie kasuje. Po odpięciu importu Vite go nie kompiluje jako wejścia aplikacji. Przeniesienie wyglądu na klasy i usunięcie arkuszy stron oraz pakietu `sass` robi [06-css-zamiast-scss.md](06-css-zamiast-scss.md). Reguł z `styles.scss` nie przepisujesz do `styles.css` przy instalacji.

### 5. Pierwsza klasa na shellu

Korzeń w [Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) dostaje jedną klasę narzędziową. Znacznik zostaje `div`, który już owija `header`, `main` i `footer`. Drzewo landmarków opisuje [html/01-semantyka.md](../html/01-semantyka.md); ten krok go nie przebudowuje.

```tsx
<div className="shell min-h-svh">
```

`min-h-svh` jest klasą domyślnej skali v4 i działa zanim powstanie `@theme`. W wygenerowanym CSS odpowiada jej `min-height: 100svh`. Docelowy korzeń (`flex min-h-svh flex-col` oraz tło i atrament z tokenów) składa [03-uklad.md](03-uklad.md) po nazwach z [02-motyw.md](02-motyw.md). Przy samej instalacji tych klas nie dopisujesz: `bg-canvas` i `text-ink` istnieją dopiero po mapowaniu tokenów.

Logika locale, `NavLink`, przełącznik języka i efekty w `Shell` zostają. Funkcja `navClass` nadal zwraca stan aktywny po swojemu; stany wskaźnika opisuje [05-stany.md](05-stany.md).

### 6. Sprawdzenie

Serwer deweloperski, z katalogu klienta:

```bash
cd src/Clients/web
pnpm start
```

Skrypt `start` to `vite --port 4200`. Hook `prestart` kopiuje CV. Proxy opisuje [vite/01-dev.md](../vite/01-dev.md).

Otwierasz `http://localhost:4200/pl`. W inspektorze korzeń shellu ma klasę `min-h-svh`, a obliczone `min-height` wynosi `100svh`. W arkuszu podanym przez Vite jest reguła tej klasy. Ta sama reguła jest na `http://localhost:4200/login`, bo login siedzi w tym samym `Shell` i w tym samym imporcie CSS.

Gdy klasa jest w JSX, a reguły nie ma w CSS, sprawdzasz po kolei: plugin jest w tablicy `plugins`, proces Vite wstał po zapisie konfiguracji, `main.tsx` importuje `./styles.css`, a plik CSS zaczyna się od `@import "tailwindcss"`.

Lokalna bramka po tym wpięciu:

```bash
cd src/Clients/web
pnpm build
```

Zielony przebieg i obecność `.min-h-svh` w CSS pod `dist/assets/` domykają instalację od strony paczki. Składniki bramki (`tsc`, potem `vite build`, obraz Dockera) opisuje [vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md).

## Przypadki użycia

### Pierwsza klasa na shellu

Użytkownik otwiera `/pl`. Korzeń shellu sięga co najmniej wysokości małego viewportu (`100svh`), także gdy treść strony jest krótka. W inspektorze widać `min-h-svh` i regułę z arkusza Tailwinda. To jedyny wygląd, który ten plik wprowadza.

### Ten sam arkusz na logowaniu

`/login` i `/register` renderują ten sam `Shell` co strony `/:lang`. Osobnego `styles.css` dla formularza nie ma. Klasa z korzenia jest na obu trasach, bo obie przechodzą przez `main.tsx`.

### Nazwa klasy w całości

Skaner zapisuje klasę, którą widzi jako kompletny napis. `className="min-h-svh"` wchodzi do CSS. Złożenie `` `min-h-${'svh'}` `` albo złożenie z tablicy fragmentów nie wchodzi. Gdy klasa ma zależeć od stanu, funkcja zwraca gotowy literał, tak jak dziś `navClass` zwraca swoją nazwę. Zestaw stanów (hover, focus, pusto, błąd) dopisuje [05-stany.md](05-stany.md) już pełnymi nazwami.

## Zasady wyglądu

Ten plik ustala potok, a nie paletę. Liczby kolorów, skali, odstępów, radiusa i czasów stoją w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Kontrakt liczb jest w [motyw.md](../motyw.md). Nazwy utility z tych liczb powstają w `@theme` według [02-motyw.md](02-motyw.md).

W kroku instalacji na korzeniu shellu jest `min-h-svh`. Odstęp, nav, siatka kart i szerokość artykułu dochodzą w [03-uklad.md](03-uklad.md). Inter, tracking i ciemny hero dochodzą w [04-typografia.md](04-typografia.md). Hex w klasie arbitralnej (`bg-[#f5f5f7]` i podobne) w tym kroku nie powstaje: paleta ma jedną mapę, w pliku motywu.

Klasa wisi na znaczniku, który komponent już renderuje. Znaczniki shellu opisuje [html/01-semantyka.md](../html/01-semantyka.md).

## Poza zakresem

- `@theme`, nazwy `canvas`, `ink`, `accent` i zakaz drugiej palety: [02-motyw.md](02-motyw.md), liczby w [motyw.md](../motyw.md).
- Kolumna shellu, pasek, siatka kursów, szerokość artykułu: [03-uklad.md](03-uklad.md).
- Krój, skala pisma, ciemny hero: [04-typografia.md](04-typografia.md).
- hover, focus-visible, disabled, pusto, błąd, `prefers-reduced-motion`: [05-stany.md](05-stany.md).
- Usunięcie `styles.scss`, arkuszy stron, pakietu `sass` i reguła `@apply`: [06-css-zamiast-scss.md](06-css-zamiast-scss.md).
- Bramka `pnpm build`, Docker, frozen lockfile: [vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md).
- `shadcn init` i `components.json`: [shadcn/01-init.md](../shadcn/01-init.md). Zakłada to wpięcie.
- NativeWind na telefonie: [nativewind/01-instalacja.md](../nativewind/01-instalacja.md). Ekrany telefonu są osobne.

## Gotowe gdy

- W `devDependencies` klienta web są `tailwindcss` i `@tailwindcss/vite` w tej samej wersji linii 4.
- `pnpm.onlyBuiltDependencies` zawiera `esbuild`, `@parcel/watcher`, `@tailwindcss/oxide` i `lightningcss`. `pnpm install` nie pomija skryptów oxide i lightningcss.
- W `vite.config.ts` tablica to `plugins: [react(), tailwindcss()]`, a `defineConfig` nadal pochodzi z `vitest/config`. Alias, proxy i test zostały.
- `src/Clients/web/src/styles.css` zaczyna się od `@import "tailwindcss"` i na tym etapie nie ma `@theme` ani importu Sassa.
- `main.tsx` importuje `./styles.css`. Importu `./styles.scss` w tym pliku nie ma.
- Korzeń `Shell` ma klasę `min-h-svh`. Na `http://localhost:4200/pl` obliczone `min-height` to `100svh`, a reguła jest w CSS z pluginu.
- `pnpm build` w `src/Clients/web` kończy się kodem 0, a w CSS pod `dist/assets/` jest `.min-h-svh`.
