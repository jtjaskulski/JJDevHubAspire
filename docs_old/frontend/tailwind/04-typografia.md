# Typografia

Tekst JJDevHub ma jeden krój i jedną skalę. Rozmiar i tracking biorą się z `tokens.font` w [`tokens.ts`](../../../src/Clients/shared/theme/tokens.ts). Ten plik mówi, który stop ląduje na którym zdaniu, jak złożyć Inter Variable i jak rozdzielić ciemny hero home od jasnych sekcji.

Liczby koloru, skali i trackingu są kontraktem z [motyw.md](../motyw.md). Rejestracja tych liczb w `@theme` jest w [02-motyw.md](02-motyw.md). Tutaj zostaje zastosowanie: rodzina, stop, leading, waga, kolor tekstu.

## Wersje i pakiety

| Pakiet | Wersja | Rola |
| --- | --- | --- |
| `tailwindcss` i `@tailwindcss/vite` | Tailwind v4 | Klasy `text-*`, `font-sans`, `font-brand`. Wpięcie opisuje [01-instalacja.md](01-instalacja.md). |
| `@fontsource-variable/inter` | `^5.2.6` | Pliki Inter Variable, oś grubości 100–900. Już jest w [`src/Clients/web/package.json`](../../../src/Clients/web/package.json). |
| `@jjdevhub/theme` | `file:../shared/theme` | `tokens.font.family`, `tokens.font.size`, `tokens.font.tracking`. |

React 19 składa HTML. Klasy siedzą na znacznikach z [01-semantyka.md](../html/01-semantyka.md). Arkusz jest jeden: `src/Clients/web/src/styles.css`.

Inter Variable jest wymagany, bo waga 650 (imię w hero, marka w nav) leży między 600 a 700. Statyczny plik Inter tej wagi nie ma.

## Ścieżki w repo

| Ścieżka | Co tu jest |
| --- | --- |
| `src/Clients/shared/theme/tokens.ts` | `font.family` (`Inter`), osiem rozmiarów w px, osiem trackingów w em. |
| `src/Clients/web/package.json` | zależność `@fontsource-variable/inter`. |
| `src/Clients/web/src/main.tsx` | import fontu przed arkuszem. |
| `src/Clients/web/src/styles.css` | `@theme` dla stopni tekstu i reguły `body`. |
| `docs/frontend/motyw.md` | kontrakt liczb. |
| `docs/frontend/tailwind/02-motyw.md` | nazwy kolorów w `@theme`. |
| `docs/frontend/tailwind/03-uklad.md` | odstępy, szerokość łamu, siatka kart. |

## Skala

Stop i tracking mają ten sam klucz. `text-h1` niesie 56px i `-0.012em`. Drugiego trackingu na tym elemencie się nie dokłada.

Tracking jest w `em` i jest ujemny na każdym stopniu poza `caption`. Body (`-0.014em`) jest ciaśniejsze niż `h4` (`-0.005em`). To jest zapis tokenu. Przy implementacji kopiujesz parę, bez wyrównywania „żeby nagłówek był ciaśniejszy od tekstu”.

| Stop | Token rozmiaru | px | Token trackingu | em | Klasa |
| --- | --- | --- | --- | --- | --- |
| display | `font.size.display` | 80 | `font.tracking.display` | -0.015 | `text-display` |
| h1 | `font.size.h1` | 56 | `font.tracking.h1` | -0.012 | `text-h1` |
| h2 | `font.size.h2` | 40 | `font.tracking.h2` | -0.01 | `text-h2` |
| h3 | `font.size.h3` | 28 | `font.tracking.h3` | -0.008 | `text-h3` |
| h4 | `font.size.h4` | 21 | `font.tracking.h4` | -0.005 | `text-h4` |
| body | `font.size.body` | 17 | `font.tracking.body` | -0.014 | `text-body` |
| small | `font.size.small` | 14 | `font.tracking.small` | -0.006 | `text-small` |
| caption | `font.size.caption` | 12 | `font.tracking.caption` | 0 | `text-caption` |

`text-prose` to ten sam rozmiar i ten sam tracking co body (17px, `-0.014em`). Różni się tylko leadingiem: 1.55 zamiast 1.47. To klasa akapitu w artykule, nie dziewiąty rozmiar i nie nowe pole w `tokens.ts`.

Leading i waga nie są w `tokens.ts`. Przypisanie poniżej jest częścią tej specyfikacji. Nie dopisuj ich do tokenów.

| Stop | Leading | Waga | Gdzie |
| --- | --- | --- | --- |
| display | 1.05 | 650 | Imię w hero home. Sufit fluida. |
| h1 | 1.08 | 600 | Jedyny `h1` strony treści: notatka, kurs, CV, kompendium, lista. Sufit fluida. |
| h2 | 1.1 | 600 | Nagłówek sekcji na jasnym płótnie. |
| h3 | 1.2 | 500 | Rola pod imieniem. Tytuł karty kursu. |
| h4 | 1.35 | 400 | Lead artykułu. Tytuł formularza logowania i rejestracji. |
| body | 1.47 | 400 | Domyślny tekst strony, opis karty, akapit w hero. |
| prose | 1.55 | 400 | Akapit w treści notatki, kursu, kompendium, CV. |
| small | 1.47 | 400 | Podpis karty, meta, nav, etykieta pola. |
| caption | 1.47 | 400 | Etykieta 12px: okres w hero, przełącznik języka. |

Marka w nav (`JJDevHub`) używa stopu `small` i wagi 650. Waga idzie klasą `font-brand`, bo `text-small` zostawia wagę 400.

### Fluid tylko na display i h1

Sufit jest tokenem. Podłoga jest regułą tego pliku, żeby 80px i 56px weszły w wąskie okno przeglądarki.

| Stop | Wartość w `@theme` |
| --- | --- |
| display | `clamp(2.75rem, 8vw, 80px)` |
| h1 | `clamp(2rem, 5vw, 56px)` |

`2.75rem` to 44px, `2rem` to 32px. Od `h2` w dół rozmiar jest stały, w px z tokenu. `80` i `56` w `clamp` są kopią `tokens.font.size`, nie nową skalą.

### Kolor tekstu

Paleta jest w tokenach. Na tekście występują tylko te klasy (rejestracja nazw: [02-motyw.md](02-motyw.md)):

| Klasa | Token | Hex | Rola |
| --- | --- | --- | --- |
| `bg-canvas` | `color.canvas` | `#f5f5f7` | Tło jasnej strony. |
| `text-ink` | `color.ink` | `#1d1d1f` | Tytuły i proza na jasnym. |
| `text-muted` | `color.muted` | `#6e6e73` | Podpis, lead, meta, nieaktywny link nav. |
| `text-accent` | `color.accent` | `#0071e3` | Link w prozie na jasnym. |
| `bg-dark-chapter` | `color.darkChapter.background` | `#000000` | Tło hero home. |
| `text-on-dark` | `color.darkChapter.foreground` | `#f5f5f7` | Tekst na hero. |

Na hero drugi i trzeci poziom to ten sam kolor z kryciem, nie nowy hex:

| Klasa | Co niesie |
| --- | --- |
| `text-on-dark` | Imię, tytuł rozdziału, tytuł „teraz”. |
| `text-on-dark/80` | Rola, akapit rozdziału. |
| `text-on-dark/55` | Nadtytuł nad imieniem, lead drugoplanowy, okres (`caption`). |

`color-scheme` na `html` zostaje `light`. Hero jest jedną ciemną sekcją na jasnej stronie. Osobnego motywu ciemnego nie ma.

## Tutorial

Zakładasz, że Tailwind v4 jest wpięty i że kolory z tabeli wyżej są już w `@theme` ([01-instalacja.md](01-instalacja.md), [02-motyw.md](02-motyw.md)). Kroki poniżej dokładają krój i stopnie.

### 1. Plik fontu

W katalogu klienta:

```bash
pnpm --dir src/Clients/web add @fontsource-variable/inter@^5.2.6
```

Pakiet przy tej wersji już jest w manifeście. Komenda ma zostać idempotentna: po niej w zależnościach jest `@fontsource-variable/inter`.

Nazwa rodziny w pliku fontu to `Inter Variable`. Token trzyma słowo `Inter`. Stos wymienia obie nazwy: załadowana twarz pierwsza, token jako zapas, potem pismo systemowe.

W [`src/Clients/web/src/main.tsx`](../../../src/Clients/web/src/main.tsx) import fontu stoi przed importem arkusza:

```tsx
import '@fontsource-variable/inter';
import './styles.css';
```

Import `@fontsource-variable/inter` wciąga oś `wght` 100–900 i podzbiory, których używa PL i EN. Osobnego `unicode-range` w `styles.css` nie dopisujesz.

### 2. Stopnie w `@theme`

Do `src/Clients/web/src/styles.css`, obok kolorów z [02-motyw.md](02-motyw.md):

```css
@theme {
  --font-sans: "Inter Variable", Inter, system-ui, sans-serif;
  --font-weight-brand: 650;

  --text-display: clamp(2.75rem, 8vw, 80px);
  --text-display--line-height: 1.05;
  --text-display--letter-spacing: -0.015em;
  --text-display--font-weight: 650;

  --text-h1: clamp(2rem, 5vw, 56px);
  --text-h1--line-height: 1.08;
  --text-h1--letter-spacing: -0.012em;
  --text-h1--font-weight: 600;

  --text-h2: 40px;
  --text-h2--line-height: 1.1;
  --text-h2--letter-spacing: -0.01em;
  --text-h2--font-weight: 600;

  --text-h3: 28px;
  --text-h3--line-height: 1.2;
  --text-h3--letter-spacing: -0.008em;
  --text-h3--font-weight: 500;

  --text-h4: 21px;
  --text-h4--line-height: 1.35;
  --text-h4--letter-spacing: -0.005em;
  --text-h4--font-weight: 400;

  --text-body: 17px;
  --text-body--line-height: 1.47;
  --text-body--letter-spacing: -0.014em;
  --text-body--font-weight: 400;

  --text-prose: 17px;
  --text-prose--line-height: 1.55;
  --text-prose--letter-spacing: -0.014em;
  --text-prose--font-weight: 400;

  --text-small: 14px;
  --text-small--line-height: 1.47;
  --text-small--letter-spacing: -0.006em;
  --text-small--font-weight: 400;

  --text-caption: 12px;
  --text-caption--line-height: 1.47;
  --text-caption--letter-spacing: 0em;
  --text-caption--font-weight: 400;
}
```

Jedna klasa `text-display` ustawia rozmiar, leading, tracking i wagę. Dzięki temu nagłówek nie dziedziczy trackingu body (`-0.014em`).

`font-brand` pochodzi z `--font-weight-brand` i daje samą wagę 650. Na marce w nav: `text-small font-brand`.

### 3. Domyślny tekst strony

Preflight Tailwinda v4 zrówna `h1`–`h6` z tekstem rodzica (`font-size` i `font-weight` na `inherit`). Stop nagłówka istnieje tylko wtedy, gdy element ma klasę z tabeli. Akapit bez klasy jest tekstem body, bo `body` ustawia stop body.

W tym samym `styles.css`:

```css
@layer base {
  html {
    color-scheme: light;
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  body {
    background-color: var(--color-canvas);
    color: var(--color-ink);
    font-family: var(--font-sans);
    font-size: var(--text-body);
    font-weight: 400;
    letter-spacing: var(--text-body--letter-spacing);
    line-height: var(--text-body--line-height);
  }

  a {
    color: var(--color-accent);
    text-decoration-thickness: 0.06em;
    text-underline-offset: 0.18em;
  }

  code {
    font-size: 0.9em;
  }
}
```

`code` zostaje w Interze, 0.9em względem otaczającego stopnia. Osobnego kroju monospace w tokenach nie ma.

Hover linku, focus i `prefers-reduced-motion` są w [05-stany.md](05-stany.md). Tutaj link w spoczynku ma kolor akcentu i cienkie podkreślenie.

### 4. Sprawdzenie w dev

```bash
pnpm --dir src/Clients/web start
```

Aplikacja wstaje na porcie 4200. W DevTools, na `body`: rodzina zaczyna się od `Inter Variable`, rozmiar `17px`, `letter-spacing` wyliczone z `-0.014em`, `line-height` 1.47, kolor `#1d1d1f`, tło `#f5f5f7`.

## Przypadki użycia

Odstępy, `max-width` łamu i siatka są w [03-uklad.md](03-uklad.md). Poniżej tylko typografia. Jeden `h1` na stronę — poziom nagłówka opisuje [01-semantyka.md](../html/01-semantyka.md). Stop wizualny i poziom to dwie osie: tytuł karty bywa `h2` albo `h3`, a i tak nosi stop `h3` (28px).

### Hero home

Jedyna ciemna płaszczyzna tekstu. Tło `#000000`, pismo `#f5f5f7`. Strony cv, courses, compendium, notes, login i register są jasne.

```tsx
<section className="bg-dark-chapter text-on-dark">
  <p className="text-small text-on-dark/55">Nadtytuł</p>
  <h1 className="text-display">Imię</h1>
  <p className="text-h3 text-on-dark/80">Rola</p>
  <h2 className="text-h4">Teraz</h2>
  <p className="text-body text-on-dark/55">Lead bieżącej rzeczy</p>
  <article>
    <p className="text-caption text-on-dark/55 tabular-nums">2020–2024</p>
    <h3 className="text-h4">Nazwa rozdziału</h3>
    <p className="text-body text-on-dark/80">Akapit rozdziału</p>
  </article>
  <a className="text-body text-on-dark" href="/pl/cv">
    CV
  </a>
</section>
```

`h1` dostaje `text-display`: na szerokim oknie 80px, waga 650, leading 1.05, tracking `-0.015em`. Kolor dziedziczy z sekcji (`text-on-dark`), więc imię jest `#f5f5f7` w pełnym kryciu.

Link w hero nadpisuje bazowy akcent. Zostaje `#f5f5f7`, bez `#0071e3` na czerni. Podkreślenie spoczynkowe może zostać; zachowanie hover jest w [05-stany.md](05-stany.md).

`tabular-nums` na okresie trzyma cyfry w równej szerokości. Inter Variable to umie. Na zwykłym zdaniu tej klasy nie ma.

### Tytuł artykułu

Notatka, szczegół kursu, hasło kompendium i CV. Strona jest jasna: tło płótna, tytuł atramentowy. Ten sam `h1` (stop `h1`, sufit 56px) stoi na listach: courses, notes, compendium.

```tsx
<article>
  <header>
    <a className="text-small text-muted" href="/pl/notes">
      Notatki
    </a>
    <time className="text-small text-muted tabular-nums" dateTime="2026-10-11">
      11.10.2026
    </time>
    <h1 className="text-h1 text-ink">Tytuł notatki</h1>
    <p className="text-h4 text-muted">Lead, jedno albo dwa zdania.</p>
  </header>
  <div>
    <p className="text-prose text-ink">Akapit treści.</p>
    <p className="text-prose text-ink">
      Link w zdaniu zostaje <a href="/pl/courses">akcentem</a>.
    </p>
  </div>
</article>
```

`text-h1` daje clamp do 56px, leading 1.08, tracking `-0.012em`, wagę 600. Lead jest stopem `h4` (21px, `-0.005em`) w kolorze `muted`. Akapit jest `text-prose`: 17px i tracking body, leading 1.55. Link wewnątrz akapitu bierze `#0071e3` z reguły `a`.

Data jest stopem `small` i `tabular-nums`, kolor `muted`.

### Podpis karty

Karta kursu na home i na `/pl/courses` oraz `/en/courses`. Tytuł karty to stop `h3` (28px, waga 500, tracking `-0.008em`), kolor `ink`. Podpis to `course.subtitle`: stop `small` (14px, `-0.006em`), kolor `muted`. Opis pod podpisem zostaje stopem body i kolorem `muted`.

Na liście kursów `h1` strony jest tytułem sekcji (`text-h1`). Tytuł karty jest niżej w outline i wizualnie jest `h3`, także gdy znacznik to `h2`.

```tsx
<section>
  <header>
    <h1 className="text-h1 text-ink">Kursy</h1>
    <p className="text-body text-muted">Lead listy.</p>
  </header>
  <a href="/pl/courses/przyklad">
    <h2 className="text-h3 text-ink">Tytuł kursu</h2>
    <p className="text-small text-muted">Podpis karty</p>
    <p className="text-body text-muted">Krótki opis.</p>
  </a>
</section>
```

Podpis nie schodzi do `caption`. 12px zostaje dla etykiet (okres, język), nie dla zdania, które ma się dać przeczytać jako podtytuł.

Na home ta sama karta stoi w jasnej sekcji pod hero. Nagłówek sekcji („Kursy”) jest `text-h2 text-ink`. Lead sekcji jest `text-body text-muted`. Karta ma białe tło (`bg-white` z tokenu `color.white`); kolor tytułu i podpisu się od tego nie zmienia.

### Reszta stopni, żeby skala była zamknięta

| Miejsce | Klasy |
| --- | --- |
| Marka w nav | `text-small font-brand text-ink` |
| Link w nav | `text-small text-muted`; aktywny: `text-ink` |
| Przełącznik języka | `text-caption text-muted`; aktywny: `text-ink` |
| Stopka | `text-small text-muted` |
| Tytuł logowania i rejestracji | `text-h4 text-ink` |
| Etykieta pola | `text-small text-muted` |
| Wartość w polu | dziedziczy body (`font: inherit` na inpucie) |

Stany hover, focus, disabled i błąd pola: [05-stany.md](05-stany.md). Wygląd przycisku i inputa jako komponentu: katalog shadcn. Etykieta przycisku używa stopu `small` i wagi 600 (`font-semibold` dopiero po zmapowaniu wagi 600 na tokenową klasę; domyślne `font-semibold` Tailwinda jest 600 i tu się zgadza, bo 600 jest wagą z tej specyfikacji, nie rozmiarem).

## Zasady wyglądu

- Rodzina na stronie to stos `"Inter Variable", Inter, system-ui, sans-serif`. Drugiego kroju nagłówkowego nie ma.
- Każdy widoczny nagłówek, podpis, meta i lead ma klasę stopu. Sam znacznik `h1` po preflightcie wygląda jak body.
- Rozmiar z lewej kolumny tabeli idzie zawsze ze swoim trackingiem. `text-h2` i wbudowane `tracking-tight` (`-0.025em`) na jednym elemencie psują parę.
- Wbudowane stopnie Tailwinda (`text-xs`, `text-sm`, `text-base`, `text-lg`, `text-xl`, `text-2xl` i większe) oraz wbudowany tracking (`tracking-tighter`, `tracking-tight`, `tracking-wide`) nie występują w JSX.
- Klasa arbitralna rozmiaru albo trackingu (`text-[15px]`, `tracking-[-0.02em]`) nie występuje. Brakujący stop oznacza lukę w tej tabeli, nie jednorazowy wyjątek w komponencie.
- Kolor tekstu to `text-ink`, `text-muted`, `text-accent` albo `text-on-dark` (wraz z `/80` i `/55`). `text-black`, `text-white`, `text-gray-*` i `text-neutral-*` są drugą paletą.
- Jasna sekcja: tło `#f5f5f7`, tytuł i proza `#1d1d1f`, tekst drugiego planu `#6e6e73`, link `#0071e3`.
- Hero home: tło `#000000`, tekst `#f5f5f7`. Akcent nie wchodzi na hero. Krycie drugiego planu to tylko `/80` i `/55`.
- Waga 650 jest tylko na `text-display` i `font-brand`. `h1` i `h2` są 600. `h3` jest 500. Reszta jest 400.
- `caption` ma tracking `0em`. To jedyny stop bez ściągania.
- Data i zakres lat dostają `tabular-nums`.
- Antialiasing (`antialiased` plus grayscale na Firefoxie) jest na `html`, raz, w bazie.
- Telefon czyta te same px i em z `tokens.ts`, ale ekran i klasy są osobne. Ten plik jest webem.

## Poza zakresem

| Temat | Plik |
| --- | --- |
| Instalacja Tailwinda i wejście `styles.css` | [01-instalacja.md](01-instalacja.md) |
| Pełne `@theme` kolorów, odstępów, radiusu | [02-motyw.md](02-motyw.md) |
| Kontrakt liczb | [motyw.md](../motyw.md) |
| Odstęp, nav, siatka kart, szerokość artykułu | [03-uklad.md](03-uklad.md) |
| Hover, focus, disabled, pusto, błąd, reduced motion | [05-stany.md](05-stany.md) |
| Zejście ze starych arkuszy | [06-css-zamiast-scss.md](06-css-zamiast-scss.md) |
| Znaczniki i jeden `h1` | [01-semantyka.md](../html/01-semantyka.md) |
| Ruch hero i scroll | [02-hero.md](../motion/02-hero.md) |
| Te same liczby na telefonie | [01-instalacja.md](../nativewind/01-instalacja.md) |

## Gotowe gdy

- `body` w DevTools ma rodzinę zaczynającą się od `Inter Variable`, 17px, tracking `-0.014em`, leading 1.47, kolor `#1d1d1f`, tło `#f5f5f7`.
- Przy szerokości okna 1280px `h1` hero ma 80px, wagę 650, leading 1.05, tracking `-0.015em`, kolor `#f5f5f7`, a sekcja hero ma tło `#000000`.
- Przy szerokości 360px ten sam `h1` schodzi clampem (podłoga 2.75rem), a wiersz się mieści.
- Tytuł artykułu i tytuł listy używają `text-h1`: sufit 56px, waga 600, leading 1.08, tracking `-0.012em`, kolor `#1d1d1f`.
- Lead artykułu jest `text-h4 text-muted`. Akapit treści jest `text-prose` (17px, leading 1.55, tracking `-0.014em`).
- Podpis karty kursu jest `text-small text-muted` (14px, `-0.006em`). Tytuł karty jest `text-h3 text-ink` (28px, waga 500, `-0.008em`).
- Etykieta 12px (`text-caption`) ma `letter-spacing: 0px`.
- Na stronie jest jeden element wizualnego displayu i jest nim imię w hero. Pozostałe strony nie mają tła `#000000` pod tekstem.
- W JSX nie ma `text-sm` / `text-xl` / `tracking-tight` ani arbitralnego rozmiaru czcionki.
- Link w akapicie na jasnej stronie jest `#0071e3`. Link w hero jest `#f5f5f7`.
