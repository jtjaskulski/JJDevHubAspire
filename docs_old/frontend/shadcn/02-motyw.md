# Motyw shadcn

Szablon z `shadcn init` maluje komponenty szarym `oklch` (przycisk prawie czarny, pole i karta na cynku). JJDevHub ma jedną paletę. Ten plik mówi, jak zdjąć ten szary blok i spiąć nazwy, których szukają komponenty shadcn, ze zmiennymi z [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts).

Liczby, hex i skala są w [motyw.md](../motyw.md). Tu jest tylko powiązanie nazw. Hex w CSS shadcn się nie pojawia.

## Po co

Komponenty z `src/Clients/web/src/components/ui` (przycisk, pole, karta) czytają klasy Tailwinda: `bg-primary`, `bg-card`, `border-input`, `ring-ring`, `rounded-xl`. Te klasy biorą kolory z bloku `@theme`, który init wpisuje do arkusza. Dopóki blok wskazuje szary `:root`, przycisk primary zostaje szary, niezależnie od `tokens.color.accent`.

Po podmianie:

- płótno (`color.canvas`) jest tłem strony,
- atrament (`color.ink`) jest tekstem,
- akcent (`color.accent`) jest wypełnieniem przycisku primary i pierścieniem fokusu,
- biel (`color.white`) jest wypełnieniem karty i pola,
- drugi plan (`color.muted`) jest kolorem podpisu i placeholdera,
- promień karty (`radius.card`) jest promieniem karty shadcn.

Ciemny hero czyta `color.darkChapter` z tego samego pliku tokenów. Osobnego motywu `.dark` w szarym `oklch` nie zostawiamy.

## Wersje i pakiety

Klient web: React 19, Vite 7, pnpm. Wejście docelowe stylów to jeden `src/styles.css` (Tailwind v4, bez Sassa). shadcn siedzi na tym samym HTML co reszta łańcucha: React składa znaczniki, Vite podaje ten CSS, Tailwind daje klasy.

Pakiet CLI i `components.json` opisuje [01-init.md](01-init.md). Do motywu potrzeba tylko tego, co init już wstawił: `cssVariables: true` oraz arkusz wskazany w `components.json` (`src/styles.css`). Nowej biblioteki kolorów nie instalujemy. Tokeny wchodzą pakietem `@jjdevhub/theme`, który wskazuje `tokens.ts`.

## Ścieżki w repo

| Co | Gdzie |
| --- | --- |
| Liczby palety | [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts) |
| Kontrakt liczb | [motyw.md](../motyw.md) |
| Wstrzyknięcie zmiennych na `<html>` | [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) — `cssCustomProperties()` |
| Arkusz, w którym żyje motyw shadcn | `src/Clients/web/src/styles.css` |
| Nazwy klas tokenów w Tailwindzie | [tailwind/02-motyw.md](../tailwind/02-motyw.md) |
| Komponenty ui | `src/Clients/web/src/components/ui` |

`main.tsx` ustawia na `document.documentElement` między innymi `--canvas`, `--white`, `--ink`, `--muted`, `--accent`, `--dark-chapter-bg`, `--dark-chapter-fg`, `--radius-sm`, `--radius-md`, `--radius-lg`, `--radius-card`, `--radius-pill`, `--font-family`. Styl inline wygrywa ze zwykłym `:root` w arkuszu. Dlatego bloku shadcn nie wolno zapisać pod tymi samymi nazwami z inną treścią: nadpisze albo przegra z tokenem i kolor się rozjedzie.

## Te same nazwy, inne role

Trzy nazwy z init kolidują z kontraktem tokenów.

| Nazwa | W `tokens.ts` / `cssCustomProperties()` | W szablonie shadcn |
| --- | --- | --- |
| `--accent` | akcent marki, `color.accent` | jasne tło hover i zaznaczenia |
| `--muted` | kolor tekstu drugiego planu, `color.muted` | jasne tło powierzchni |
| `--radius` | brak jednej bazy; jest skala `--radius-sm` … `--radius-pill` | jedna liczba, z której `calc(...)` liczy resztę |

Marka zostaje na zmiennej tokenu `--accent`. Klasa `bg-primary` czyta ją przez `--color-primary`. Klucz `--color-accent` w motywie shadcn (hover menu, zaznaczenie) wskazuje `var(--canvas)`, czyli płótno, a nie błękit przycisku.

Tekst drugiego planu zostaje na zmiennej tokenu `--muted`. Klasa `text-muted-foreground` czyta ją przez `--color-muted-foreground`. Klucz `--color-muted` (tło powierzchni) wskazuje `var(--canvas)`.

Skali `calc(var(--radius) * …)` nie ma. Klucze promienia w `@theme` wskazują gotowe zmienne tokenów.

## Tutorial

Init i katalog `components/ui` są w [01-init.md](01-init.md). Ten krok zaczyna się, gdy w `src/Clients/web/src/styles.css` leży już wygenerowany motyw.

1. Otwórz `src/Clients/web/src/styles.css`.
2. Usuń z niego bloki kolorów szablonu: `:root` i `.dark` z wartościami `oklch(...)`, zmienne `--chart-*` i `--sidebar-*` oraz promienie zapisane jako `calc(var(--radius) …)`.
3. Zostaw import Tailwinda i importy, które opisuje [tailwind/01-instalacja.md](../tailwind/01-instalacja.md). W to miejsce wstaw jeden blok `@theme inline`. Słowo `inline` zostawia w klasie odwołanie `var(--…)`, więc zmiana liczby w `tokens.ts` wchodzi na stronę bez drugiego hex w CSS.
4. Nie dopisuj w tym pliku `#f5f5f7`, `#1d1d1f`, `#0071e3` ani żadnego innego hex. Wartość płynie z `var(--canvas)`, `var(--ink)`, `var(--accent)` i pozostałych nazw z `cssCustomProperties()`.

Blok do wstawienia:

```css
@theme inline {
  --color-background: var(--canvas);
  --color-foreground: var(--ink);

  --color-card: var(--white);
  --color-card-foreground: var(--ink);
  --color-popover: var(--white);
  --color-popover-foreground: var(--ink);

  --color-primary: var(--accent);
  --color-primary-foreground: var(--white);

  --color-secondary: var(--canvas);
  --color-secondary-foreground: var(--ink);

  --color-muted: var(--canvas);
  --color-muted-foreground: var(--muted);

  --color-accent: var(--canvas);
  --color-accent-foreground: var(--ink);

  --color-destructive: var(--ink);
  --color-destructive-foreground: var(--white);

  --color-border: var(--canvas);
  --color-input: var(--canvas);
  --color-ring: var(--accent);

  --radius-sm: var(--radius-sm);
  --radius-md: var(--radius-md);
  --radius-lg: var(--radius-lg);
  --radius-xl: var(--radius-card);
  --radius-2xl: var(--radius-card);
  --radius-3xl: var(--radius-card);
  --radius-4xl: var(--radius-card);

  --font-sans: var(--font-family);
}
```

Co ten blok robi:

- `--color-primary` to akcent marki. Tekst na nim to `color.white`.
- `--color-background` to płótno strony. `--color-foreground` to atrament.
- `--color-card` i `--color-popover` to biel. Tekst na nich to atrament.
- `--color-accent` shadcn (hover) i `--color-muted` (tło) to płótno. Podpis i placeholder idą przez `--color-muted-foreground` do `color.muted`.
- `--color-border` i `--color-input` to płótno: spoczynkowa kreska zlewa się z tłem strony. Skupienie rysuje `--color-ring`, czyli akcent.
- `--color-destructive` to atrament, tekst na nim to biel. Czerwieni w tokenach nie ma, więc jej tu nie dokładamy.
- `--radius-xl` i większe klucze, których szuka generator karty (`rounded-xl` i wyżej), wskazują `var(--radius-card)`. Większego promienia niż karta tokeny nie mają.
- `--font-sans` wskazuje `var(--font-family)`. Plik fontu ładuje `main.tsx` (`@fontsource-variable/inter`). Drugiego importu kroju w CSS shadcn nie ma.

Ciemny hero jest sekcją, nie klasą `.dark` na `<html>`:

```css
[data-chapter="dark"] {
  background: var(--dark-chapter-bg);
  color: var(--dark-chapter-fg);
}
```

Przycisk primary w tej sekcji dalej bierze `var(--accent)` i `var(--white)`. Karty w hero zostają białe (`var(--white)`) z atramentem. Tła hero nie przepisujemy na `--canvas`.

Sprawdzenie, że szary szablon zszedł z arkusza:

```bash
rg -n "oklch\\(|--chart-|--sidebar-|calc\\(var\\(--radius\\)" src/Clients/web/src/styles.css
```

Brak trafień. Drugi przebieg ma pokazać same odwołania do tokenów:

```bash
rg -n "var\\(--(canvas|ink|accent|white|muted|radius-card|font-family)\\)" src/Clients/web/src/styles.css
```

`components.json` może zostać z etykietą `baseColor` z init. Wygląd i tak bierze się z bloku powyżej. Ponowny `shadcn init` wstawia szary `:root` od nowa — po tej podmiance init się nie powtarza. Kolejne komponenty dodaje się tak, jak w [01-init.md](01-init.md).

## Przypadki użycia

Klasy poniżej są tym, co generator wkłada do `components/ui`. Ekrany i formularz logowania składa [03-komponenty.md](03-komponenty.md).

### Przycisk primary

Wariant domyślny `Button` używa `bg-primary text-primary-foreground`. Po mapowaniu wypełnienie to `var(--accent)`, napis to `var(--white)`. Hover `bg-primary/90` rozjaśnia ten sam akcent, bez nowego hex.

Na płótnie i w ciemnym hero przycisk wygląda tak samo: akcent i biały tekst.

### Pole

Wygenerowany `Input` niesie `border-input`, `placeholder:text-muted-foreground` i pierścień `ring-ring` (albo `focus-visible:border-ring`).

- Obrys w spoczynku: `--color-input` → `var(--canvas)`, więc na stronie kreska nie dokłada nowego szarego.
- Wypełnienie: biel, czyli `var(--white)`. Gdy generator zostawił `bg-transparent`, zamień tło pola na klasę karty (`bg-card`), która już wskazuje `var(--white)`. Na białej karcie pole może zostać przezroczyste — karta i tak jest `var(--white)`.
- Placeholder: `text-muted-foreground` → `var(--muted)`.
- Tekst wpisany: atrament, `var(--ink)`.
- Fokus: `--color-ring` → `var(--accent)`.

### Karta

`Card` używa `bg-card text-card-foreground` i `rounded-xl`. Wypełnienie to `var(--white)`, tekst to `var(--ink)`, róg to `var(--radius-card)` przez `--radius-xl`.

Obrys `border` bierze `--color-border` → `var(--canvas)`. Na płótnie strony kreska znika, kartę odcina biel od płótna. Drugiej ramki (osobny szary border) nie dokładamy.

## Zasady wyglądu

- Jedna paleta. Każdy kolor shadcn to `var(--canvas)`, `var(--white)`, `var(--ink)`, `var(--muted)`, `var(--accent)`, `var(--dark-chapter-bg)` albo `var(--dark-chapter-fg)`.
- Zmiana odcienia odbywa się w `tokens.ts`. `cssCustomProperties()` publikuje ją na `<html>`. CSS shadcn się przy tym nie edytuje.
- Duży oddech i mało ramek: obrys spoczynku to płótno, fokus to akcent, karta to biel na płótnie.
- Promienie tylko ze skali tokenów. `rounded-full` pokrywa się z `radius.pill`.
- Krój tekstu komponentów to `var(--font-family)` (Inter). Skala rozmiarów jest w [motyw.md](../motyw.md) i [tailwind/04-typografia.md](../tailwind/04-typografia.md).
- Modyfikator przezroczystości (`bg-primary/90`, `ring-ring/50`) miesza istniejący token. Nowego koloru z tego nie powstaje.

## Poza zakresem

- Instalacja CLI, `components.json`, alias `@/` i katalog `components/ui` — [01-init.md](01-init.md).
- Skład ekranów: dialog, pusta lista, nawigacja, formularz logowania — [03-komponenty.md](03-komponenty.md).
- Pełna skala `@theme` tokenów (odstępy, czasy, nazwy klas płótna) — [tailwind/02-motyw.md](../tailwind/02-motyw.md).
- Wejście `src/styles.css` zamiast dotychczasowego arkusza — [tailwind/01-instalacja.md](../tailwind/01-instalacja.md) i [tailwind/06-css-zamiast-scss.md](../tailwind/06-css-zamiast-scss.md).
- Hover, disabled, błąd pola i `prefers-reduced-motion` — [tailwind/05-stany.md](../tailwind/05-stany.md). Błąd pola korzysta z atramentu i akcentu; osobnego koloru błędu paleta nie ma.
- Wykresy, sidebar shadcn i globalny tryb `.dark`. Ciemna powierzchnia produktu to hero z `color.darkChapter`, opisany w [motyw.md](../motyw.md).
- Telefon. Te same liczby idą przez NativeWind; ten plik dotyczy CSS weba.

## Gotowe gdy

- W `src/Clients/web/src/styles.css` nie ma `oklch(`, `--chart-*`, `--sidebar-*` ani `calc(var(--radius)`.
- W tym pliku nie ma hex palety. Kolory shadcn są wyłącznie `var(--…)` z listy `cssCustomProperties()`.
- `--color-background` wskazuje `var(--canvas)`, `--color-foreground` wskazuje `var(--ink)`, `--color-primary` i `--color-ring` wskazują `var(--accent)`, `--color-primary-foreground` wskazuje `var(--white)`.
- `--color-accent` (hover shadcn) wskazuje `var(--canvas)`. Zmienna tokenu `--accent` na `<html>` nadal jest akcentem marki z `tokens.ts` i nie została podmieniona na tło hover.
- `--color-muted-foreground` wskazuje `var(--muted)`. `--color-muted` wskazuje `var(--canvas)`.
- `--color-card` wskazuje `var(--white)`, `--color-card-foreground` wskazuje `var(--ink)`, `--radius-xl` wskazuje `var(--radius-card)`.
- Przycisk primary jest akcentem z białym napisem, pole ma białe wypełnienie, placeholder z `color.muted` i fokus akcentem, karta jest biała z promieniem `radius.card`.
- Ciemny hero bierze `--dark-chapter-bg` i `--dark-chapter-fg`. Bloku `.dark` z szarego init nie ma.
