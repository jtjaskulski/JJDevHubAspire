# Motyw Tailwinda

`@theme inline` w jednym arkuszu weba zamienia nazwy z [tokens.ts](../../../src/Clients/shared/theme/tokens.ts) na klasy Tailwinda. Liczby, heksy i jednostki zostają w kontrakcie [motyw.md](../motyw.md). Ten plik mówi, gdzie blok wkleić, czemu ma słowo `inline`, jak nazywają się klasy i po czym poznać, że w JSX nie powstała druga paleta.

## Po co

React składa HTML5, Vite podaje jeden `src/styles.css`, Tailwind v4 wystawia klasy, a shadcn i Motion siedzą na tym samym HTML. Kolor, skala, odstęp, promień, czas i krzywa mają być tymi samymi polami `tokens`, które pętla `cssCustomProperties()` wpisuje na `<html>`. Klasa `bg-canvas` czyta `var(--canvas)`. Heks w klasie arbitralnej byłby drugą kopią palety, rozjechaną przy pierwszej zmianie obiektu.

Telefon dostaje ten sam blok CSS przy NativeWind. Ekrany zostają osobne. Ten tutorial prowadzi plik weba; wpięcie telefonu jest w [nativewind/01-instalacja.md](../nativewind/01-instalacja.md).

## Wersje i pakiety

| Pakiet | Rola |
| --- | --- |
| `tailwindcss` (v4) i `@tailwindcss/vite` | Czytają `@theme` w `src/styles.css`. Wpięcie i `@import "tailwindcss"` opisuje [01-instalacja.md](01-instalacja.md). Ten plik nie dodaje zależności. |
| `react` `19.2.3` | Na znacznikach HTML5 wiszą klasy z tabeli nazw. |
| `@fontsource-variable/inter` | Plik kroju ładuje [main.tsx](../../../src/Clients/web/src/main.tsx). `@theme` tylko wskazuje rodzinę z tokenu. |

Menedżer pakietów: pnpm. Katalog poleceń: `src/Clients/web`. Tailwind v4 nie prowadzi Sassa. Wejście motywu jest w CSS.

Alias `@jjdevhub/theme` wskazuje [tokens.ts](../../../src/Clients/shared/theme/tokens.ts) ([vite/02-aliasy.md](../vite/02-aliasy.md)). Arkusz CSS tego modułu nie importuje. Mostem są właściwości ustawione na `documentElement`.

## Ścieżki w repo

| Co | Gdzie |
| --- | --- |
| Obiekt `tokens` i `cssCustomProperties()` | [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts) |
| Kontrakt liczb, jednostek i nazw klas | [motyw.md](../motyw.md) |
| Pętla, która publikuje właściwości przed renderem | [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) |
| Jedyny arkusz, blok `@theme inline` | `src/Clients/web/src/styles.css` |
| Alias `@jjdevhub/theme` | [src/Clients/web/vite.config.ts](../../../src/Clients/web/vite.config.ts) |

Blok nie idzie do partiala, do `tailwind.config.js` ani do pliku obok komponentu. [06-css-zamiast-scss.md](06-css-zamiast-scss.md) trzyma jeden graf CSS od `main.tsx`.

## Tutorial

Zacznij, gdy [01-instalacja.md](01-instalacja.md) jest zrobiona: plugin Vite widzi Tailwinda, a `src/styles.css` zawiera co najmniej:

```css
@import "tailwindcss";
```

Serwer deweloperski, port 4200 i proxy opisuje [vite/01-dev.md](../vite/01-dev.md).

```bash
cd src/Clients/web
pnpm start
```

Aplikacja wstaje na `http://localhost:4200`. Dalej w tym tutorialu powstaje blok motywu i sprawdzenie, że klasa czyta właściwość tokenu.

### 1. Zostaw liczby w tokenach

Nowa wartość wizualna to nowe pole w `tokens` i nowy klucz w `cssCustomProperties()`, z jednostką z [motyw.md](../motyw.md) (px, em, ms, `cubic-bezier`, surowy string koloru). Potem jedna linia `var(--…)` w bloku poniżej. Heks, piksel i milisekunda do `styles.css` nie wchodzą.

Pętla w [main.tsx](../../../src/Clients/web/src/main.tsx) zostaje i leci przed `createRoot`:

```tsx
import { cssCustomProperties } from '@jjdevhub/theme';

for (const [name, value] of Object.entries(cssCustomProperties())) {
  document.documentElement.style.setProperty(name, value);
}
```

Styl inline na `<html>` wygrywa ze zwykłą regułą `:root` w arkuszu. Dlatego `@theme` nie deklaruje drugiej kopii `--canvas` z heksem. Gdy pętla zniknie, `var(--canvas)` jest puste i tło strony gaśnie, choć klasa `bg-canvas` dalej jest w JSX.

Komponent strony nie importuje `tokens`, żeby ustawić kolor przez `style`. Odczyt pól `tokens.duration` i `tokens.easing` zostaje przy Motion i Reanimated, bo tam API bierze liczbę i krotkę, nie klasę. Na webowym HTML kolor i skala idą przez `className`.

### 2. Wklej jeden blok

Pod `@import "tailwindcss"` w `src/Clients/web/src/styles.css` wstaw ten blok w całości. To samo brzmienie trafia później do wejścia CSS NativeWind. Nie rozdzielaj resetu i mapowania na dwa pliki.

```css
@import "tailwindcss";

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

Słowo `inline` jest obowiązkowe. Klasa dostaje wartość `var(--canvas)`, a heks zostaje na właściwości z pętli. Bez `inline` Tailwind zapisuje własną zmienną motywu na `:root`. Tam, gdzie nazwa przestrzeni pokrywa się z właściwością dokumentu, wychodzi pętla:

```css
@theme {
  --radius-sm: var(--radius-sm);
  --tracking-display: var(--tracking-display);
}
```

`--radius-sm` i `--tracking-*` tak się nazywają i w tokenach, i w przestrzeni Tailwinda. `inline` wstawia `var(--radius-sm)` do środka klasy `rounded-sm` i nie dokleja drugiej deklaracji o tej samej nazwie. Nazw w `cssCustomProperties()` nie zmieniaj, żeby kolizję obejść.

Reset `*: initial` gasi domyślną paletę, skalę pisma, tracking, mnożnik odstępów, promienie, krzywe i czasy Tailwinda. Zostają nazwy z kontraktu. Breakpointy (`sm:`, `md:`), cienie (`shadow-*`), rozmycie i `font-mono` ten reset nie rusza. To nie są tokeny i nie zastępują palety. Szerokości `max-w-5xl` i progi układu rozstrzyga [03-uklad.md](03-uklad.md).

### 3. Kolory

Po `--color-*: initial` przestrzeń koloru ma siedem nazw. Każda wskazuje właściwość z pętli. Klasa powstaje z nazwy: `--color-canvas` daje `bg-canvas`, `text-canvas`, `border-canvas`, `ring-canvas`, `outline-canvas` i stopki gradientu. Modyfikator łamany (`bg-canvas/70`, `border-ink/8`, `text-dark-chapter-fg/80`) miesza ten sam token z alfą. Nowego koloru z tego nie ma. Którą alfę wstawić na nav, w polu i na hero, mówią [03-uklad.md](03-uklad.md), [04-typografia.md](04-typografia.md) i [05-stany.md](05-stany.md).

| Klasa | Właściwość |
| --- | --- |
| `bg-canvas`, `text-canvas` | `--canvas` |
| `bg-white`, `text-white` | `--white` |
| `bg-ink`, `text-ink` | `--ink` |
| `bg-muted`, `text-muted` | `--muted` |
| `bg-accent`, `text-accent` | `--accent` |
| `bg-dark-chapter` | `--dark-chapter-bg` |
| `text-dark-chapter-fg`, `bg-dark-chapter-fg` | `--dark-chapter-fg` |

`bg-black` nie jest nazwą hero. Tło ciemnego hero to `bg-dark-chapter`. `text-white` to pole `color.white` (napis na akcencie). Tekst na hero to `text-dark-chapter-fg`, czyli pole `color.darkChapter.foreground`. Dziś te dwa pola mogą wyglądać podobnie. Zostają dwoma kluczami: zmiana jednego nie zmienia drugiego. Wartości są w [motyw.md](../motyw.md).

`bg-blue-600`, `bg-zinc-100`, `text-slate-500`, `text-gray-900` i reszta domyślnej palety po resecie nie istnieją. `bg-transparent` też schodzi razem z przestrzenią. Przezroczystość, której potrzebuje nav, jest alfą płótna (`bg-canvas/70`), nie osobną nazwą koloru.

### 4. Rodzina, rozmiar, tracking

`--font-*` w Tailwindzie to rodzina, nie stopień. Dlatego nie ma `--font-display`. Rozmiar display jest `--text-display` i klasą `text-display`.

`--font-sans` czyta `var(--font-family)` i dokleja `, sans-serif` jako zapas, zanim krój Inter zostanie zastosowany. Rodzina marki zostaje `tokens.font.family`. Drugiej klasy `font-inter` nie dodawaj. Kolejność twarzy w pliku fontu (`Inter Variable` przed słowem z tokenu) może rozszerzyć tę samą zmienną `--font-sans`. Robi to [04-typografia.md](04-typografia.md). Rozszerzenie nie wprowadza drugiej rodziny.

Klucze rozmiaru i trackingu są te same: `display`, `h1`, `h2`, `h3`, `h4`, `body`, `small`, `caption`. Rozmiar i tracking są osobnymi klasami: `text-h1` ustawia rozmiar z `--font-h1`, `tracking-h1` ustawia odstęp liter z `--tracking-h1`. Skład na hero, w tytule artykułu i w podpisie karty opisuje [04-typografia.md](04-typografia.md). W obiekcie nie ma `line-height` ani grubości, więc ten blok nie deklaruje `--leading-*`, `--font-weight-*` ani `--text-*--line-height`.

Po `--text-*: initial` i `--tracking-*: initial` odpadają `text-sm`, `text-base`, `text-xl`, `tracking-tight` i `tracking-normal`.

### 5. Odstępy

Domyślny mnożnik Tailwinda to `--spacing: 0.25rem`. Przy nim `p-5` ma 20px, a token `space` od klucza `5` w górę nie jest wielokrotnością 4. Dlatego mnożnik jest `initial`, a każdy klucz `1`–`12` ma własną linię `--spacing-N: var(--space-N)`.

Po tym mapowaniu przyrostek liczby jest kluczem `tokens.space`. `p-5`, `gap-5`, `m-5`, `w-5` i `h-5` czytają `--space-5`. Klucze `1`–`4` przypadkiem pokrywają się z krokiem 4px. Od `5` klasa Tailwinda o tej samej cyfrze oznacza krok z kontraktu, nie starą drabinkę. Piksele są w [motyw.md](../motyw.md). Który klucz na nav, siatce i artykule — [03-uklad.md](03-uklad.md).

Klucza `0` w tokenach nie ma, więc `p-0` nie powstaje z tego bloku. Brak odstępu to brak klasy odstępu, nie `p-[0px]`.

`max-w-5xl`, `max-w-xl` i `max-w-2xl` należą do przestrzeni kontenerów, której ten reset nie tyka. `max-w-5` byłby szerokością kroku `space.5`. Nazwy z `xl` zostaw układowi.

### 6. Promień

Reset `--radius-*: initial` zostawia pięć klas: `rounded-sm`, `rounded-md`, `rounded-lg`, `rounded-card`, `rounded-pill`. Domyślne `rounded-sm` i `rounded-lg` Tailwinda mają inne piksele niż tokeny. Po resecie wygrywają tokeny. Liczby są w [motyw.md](../motyw.md).

`rounded-card` i `rounded-lg` zostają dwoma kluczami, nawet gdy kontrakt nada im dziś tę samą liczbę. Karta używa `rounded-card`. Kapsuła używa `rounded-pill`. `rounded-full` po resecie nie istnieje i nie wraca jako drugi promień.

### 7. Czas i krzywa

Czas przejścia ma przestrzeń `--transition-duration-*`. Z `--transition-duration-nav: var(--duration-nav)` powstaje klasa `duration-nav`. Właściwość dokumentu zostaje `--duration-nav`, więc nazwy się nie zapętlają. Klasy: `duration-reveal`, `duration-reveal-fast`, `duration-hero-pin`, `duration-hero-fade`, `duration-nav`.

Krzywa ma przestrzeń `--ease-*` i czyta `--easing-*`: `ease-reveal`, `ease-hero`, `ease-standard`.

Domyślne `duration-150`, `duration-300`, `ease-in` i `ease-out` po resecie odpadają. `duration-700` wygląda jak `tokens.duration.reveal`, ale nie jest nazwą kontraktu. W JSX zostaje `duration-reveal`. Kiedy która klasa rusza hover, a kiedy hero, mówią [05-stany.md](05-stany.md) i [motion/02-hero.md](../motion/02-hero.md).

`duration-[250ms]` i `duration-(--duration-nav)` są obejściem obok klasy, która już istnieje. W `className` zostaje `duration-nav`.

### 8. Sprawdzenie

W bloku nie ma heksa, piksela, milisekundy ani `cubic-bezier`:

```bash
rg -n "#[0-9a-fA-F]{3,8}|[0-9]+px|[0-9]+ms|cubic-bezier" src/Clients/web/src/styles.css
```

Brak trafień. Heks palety poza obiektem tokenów:

```bash
rg -n "#f5f5f7|#1d1d1f|#0071e3|#ffffff|#6e6e73|#000000" src/Clients
```

Jedyny oczekiwany plik to `src/Clients/shared/theme/tokens.ts`.

Klasy arbitralne z liczbą wpisaną jeszcze raz:

```bash
rg -n "bg-\[#|text-\[#|text-\[[0-9]+px\]|p-\[[0-9]+px\]|rounded-\[[0-9]+px\]|duration-\[[0-9]+ms\]" src/Clients/web/src src/Clients/mobile
```

Brak trafień.

Na `http://localhost:4200/pl` w DevTools wybierz element z `bg-canvas`. W regule klasy jest `background-color: var(--canvas)` (przy `inline` Tailwind wstawia właśnie to `var`, nie heks). Na `<html>` właściwość `--canvas` pochodzi ze stylu inline ustawionego przez pętlę. Wyliczony kolor zgadza się z `color.canvas` w [motyw.md](../motyw.md). To samo dla przycisku `bg-accent` (`--accent`) i sekcji `bg-dark-chapter` (`--dark-chapter-bg`).

Element z `p-5` ma padding z `--space-5`, nie 1.25rem. Element z `duration-nav` ma `transition-duration: var(--duration-nav)`.

## Przypadki użycia

Wartości liczbowe każdego przypadku są w [motyw.md](../motyw.md). Tu są klasy, które ten blok rejestruje, i miejsce, w którym widać, że paleta jest jedna.

### Tło strony

Jasna strona (home pod hero, listy, artykuł, CV, logowanie) stoi na płótnie. Atrament jest kolorem tekstu. Rodzina jest `font-sans`. Wyciszony jest drugim planem (lead, meta, nieaktywny podpis), nie drugim szarym z palety Tailwinda.

Korzeń shellu:

```tsx
export function Shell({ children }: ShellProps) {
  return (
    <div className="flex min-h-svh flex-col bg-canvas font-sans text-ink">
      <main className="w-full flex-1">{children}</main>
    </div>
  );
}
```

[06-css-zamiast-scss.md](06-css-zamiast-scss.md) może powiesić `bg-canvas text-ink` na `<body>` w `index.html`, gdy węzeł nie ma komponentu. Źródło koloru jest to samo: `--canvas` i `--ink`. Drugi raz tych klas na `body` i na korzeniu nie łącz, jeśli oba węzły malują pełne tło. Wystarczy jeden.

Karta na tym tle jest `bg-white` i `rounded-card`. Obrysu w tokenach nie ma. Biel odcina się od płótna. Odstęp karty bierze klucz skali, na przykład `p-6`, według [03-uklad.md](03-uklad.md). `bg-gray-50` i `bg-[#f5f5f7]` na shellu są drugą paletą, nawet gdy heks zgadza się z kontraktem.

Sprawdzenie: `http://localhost:4200/pl`. Tło za navem i pod listą jest płótnem. W arkuszu przy `bg-canvas` widać `var(--canvas)`.

### Akcent przycisku

Akcent jest jeden na płótnie i na ciemnym hero: `bg-accent`, napis `text-white`. Promień kapsuły to `rounded-pill`. Padding to klucze skali (`px-5 py-3`), rozmiar napisu `text-small`, tracking `tracking-small`.

```tsx
export function AccentButton({ children }: AccentButtonProps) {
  return (
    <button
      type="button"
      className="bg-accent text-white rounded-pill px-5 py-3 text-small tracking-small duration-nav ease-standard"
    >
      {children}
    </button>
  );
}
```

`duration-nav` i `ease-standard` są tu dlatego, że przejście koloru ma czytać token, nie `duration-150` ani `ease-in-out`. Warianty `hover:`, `focus-visible:` i `disabled:` dokłada [05-stany.md](05-stany.md) na tym samym przycisku. Hover nie wprowadza `bg-blue-700` ani `bg-[#005bb5]`.

Ten sam zestaw kolorów idzie na wysyłkę logowania i rejestracji oraz na każdy przycisk primary, zanim alias shadcn `bg-primary` wskaże ten sam `--accent` ([shadcn/02-motyw.md](../shadcn/02-motyw.md)). Do tego czasu ekran używa `bg-accent`, nie `bg-primary`.

Sprawdzenie: przycisk na `/login`. Wyliczone tło to `color.accent` z [motyw.md](../motyw.md). W klasie nie ma `#0071e3`.

### Ciemny hero

Hero na home jest jedną ciemną sekcją, nie trybem `.dark` na `<html>`. Tło: `bg-dark-chapter`. Tekst: `text-dark-chapter-fg`. Tytuł dokłada stopień i tracking z tego samego klucza: `text-display tracking-display`. Akcent na hero zostaje `bg-accent` / `text-accent`.

```tsx
export function HomeHero({ title }: HomeHeroProps) {
  return (
    <section className="bg-dark-chapter text-dark-chapter-fg">
      <h1 className="text-display tracking-display">{title}</h1>
    </section>
  );
}
```

`bg-black`, `text-white` i `bg-[#000000]` na tej sekcji omijają pola `darkChapter`. Tekst hero nie pożycza `text-white`: to inne pole tokenu. Alfa na drugim planie wisi na tej samej klasie (`text-dark-chapter-fg/80`). Które krycie na roli, leadzie i podpisie — [04-typografia.md](04-typografia.md).

Czas wejścia i przypięcia nie jest klasą arbitralną. Klasy `duration-reveal`, `duration-hero-fade`, `duration-hero-pin` i `ease-hero` są zarejestrowane powyżej. To, że na home jest jeden scroll, a na podstronach go nie ma, opisuje [motion/02-hero.md](../motion/02-hero.md). Telefon przesuwa hero osobno ([reanimated.md](../reanimated.md)) i używa tych samych nazw klas.

Sprawdzenie: `http://localhost:4200/pl`, sekcja na górze strony. Tło to `--dark-chapter-bg`, kolor `h1` to `--dark-chapter-fg`. Sekcje pod hero wracają do `bg-canvas` i `text-ink`.

## Zasady wyglądu

- Jedna paleta. W `className` występują `canvas`, `white`, `ink`, `muted`, `accent`, `dark-chapter`, `dark-chapter-fg`. Heks z kontraktu (`#f5f5f7`, `#1d1d1f`, `#0071e3` i reszta pól) do klasy arbitralnej nie wchodzi.
- Zakaz drugiej palety: `bg-[#f5f5f7]`, `text-[#1d1d1f]`, `bg-[#0071e3]`, `bg-blue-600`, `text-zinc-900`, `bg-slate-100`, `bg-black`, `text-[17px]`, `p-[24px]`, `gap-[1.5rem]`, `rounded-[18px]`, `tracking-[-0.012em]`, `duration-[250ms]`.
- Skala odstępu to klucze `1`–`12`. Skala pisma to `display`, `h1`, `h2`, `h3`, `h4`, `body`, `small`, `caption`. Promień to `sm`, `md`, `lg`, `card`, `pill`.
- Duży oddech bierze się z górnych kluczy `space`, nie z nowej liczby w nawiasie. Mało ramek: token obrysu nie istnieje, karta odcina się bielą i `rounded-card`.
- Ciemny hero jest sekcją `bg-dark-chapter`. Osobnego motywu ciemnego na `<html>` nie ma.
- `font-sans` jest krojem strony. `font-serif` i `font-mono` zostają w domyślnym temacie i na stronę nie wchodzą.
- `shadow-*` domyślnego tematu nie jest tokenem. Karta, artykuł i przycisk akcentu go nie używają jako zamiennika palety.

## Poza zakresem

- Instalacja paczek, plugin Vite i pierwsza klasa po samym `@import` — [01-instalacja.md](01-instalacja.md).
- Który klucz `space` na nav, siatce kart i szerokości artykułu, oraz `max-w-*` kontenerów — [03-uklad.md](03-uklad.md).
- Skład stopni na hero i w artykule, leading, waga, kolejność `Inter Variable` — [04-typografia.md](04-typografia.md).
- `hover:`, `focus-visible:`, `disabled:`, pusta lista, błąd pola, `motion-reduce:` — [05-stany.md](05-stany.md).
- Zejście z arkuszy `*.scss` do jednego `styles.css` — [06-css-zamiast-scss.md](06-css-zamiast-scss.md).
- Aliasy shadcn (`--color-primary`, `--color-background`, `--radius-xl` i dalej) w drugim `@theme inline` w tym samym pliku. Wskazują `var(--accent)`, `var(--canvas)`, `var(--radius-card)` i nie powtarzają `--color-*: initial` ani `--radius-*: initial`, bo reset z tego pliku zgasiłby siedem nazw. Przepis aliasów: [shadcn/02-motyw.md](../shadcn/02-motyw.md).
- Wpięcie NativeWind i ekran listy na telefonie — [nativewind/01-instalacja.md](../nativewind/01-instalacja.md), [nativewind/02-ekrany.md](../nativewind/02-ekrany.md). Blok CSS jest ten sam. Tutorialu instalacji tu nie ma.
- Jeden scroll hero i reduced motion jako zachowanie — [motion/02-hero.md](../motion/02-hero.md).

## Gotowe gdy

- W `src/Clients/web/src/styles.css`, bezpośrednio pod `@import "tailwindcss"`, jest jeden blok `@theme inline` z tego tutorialu: resety `initial` i linie `var(--…)`, bez heksa, px, ms i `cubic-bezier`.
- `main.tsx` nadal woła `cssCustomProperties()` na `documentElement` przed renderem. `tokens.ts` nie dostaje drugiej palety obok, żeby „naprawić” klasę.
- `bg-canvas`, `text-ink`, `text-muted`, `bg-white`, `bg-accent`, `text-white`, `bg-dark-chapter`, `text-dark-chapter-fg`, `font-sans`, `text-body`, `tracking-body`, `p-5`, `gap-7`, `rounded-card`, `rounded-pill`, `duration-nav` i `ease-standard` rozwiązują się do właściwości z pętli.
- `bg-gray-100`, `bg-blue-600`, `bg-black`, `text-xl`, `tracking-tight`, `rounded-full`, `duration-150` i `ease-in` nie są klasami motywu JJDevHub.
- Trzy przypadki są na stronie: shell na `bg-canvas`, przycisk na `bg-accent text-white`, hero na `bg-dark-chapter text-dark-chapter-fg`. W DevTools przy tych klasach widać `var(--canvas)`, `var(--accent)` i `var(--dark-chapter-bg)`.
- Komendy `rg` z kroku 8 nie znajdują heksa palety poza `tokens.ts` ani klasy arbitralnej z heksem, pikselem lub milisekundą w `src/Clients/web/src` i `src/Clients/mobile`.
