# Układ

Odstępy, pasek nawigacji, siatka kart kursów i szerokość artykułu na webie. Strona ma duży oddech. Ramki są dwie: linia pod nawigacją i linia nad stopką. Karta, sekcja i artykuł rozdzielają się tłem i pustą przestrzenią.

Łańcuch webu: React składa HTML5, Vite podaje jeden CSS, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Ten plik zakłada wpięcie z [01-instalacja.md](01-instalacja.md) i nazwy z [02-motyw.md](02-motyw.md). Piksele, hex i radius stoją w [../motyw.md](../motyw.md). Znaczniki opisuje [../html/01-semantyka.md](../html/01-semantyka.md). Krój i skalę dopisuje [04-typografia.md](04-typografia.md), stany wskaźnika [05-stany.md](05-stany.md).

## Po co

Generator dokłada klasy układu na shellu, liście kursów i szczegółach notatki. Jeden rytm odstępów obsługuje te trzy ekrany, więc kolejne strony (CV, kompendium, blok wykładów na home) biorą te same role, a nie nową skalę.

`main` zostaje na pełną szerokość okna. Kolumnę środkuje sama strona: lista kart albo artykuł. Dzięki temu ciemny hero na home może dojść do krawędzi okna, a tekst notatki zostaje w wąskiej mierze do czytania.

## Wersje i pakiety

Układ nie dokłada pakietu. Klasy pochodzą z Tailwind CSS 4 (`tailwindcss`, `@tailwindcss/vite`), wpiętych w [01-instalacja.md](01-instalacja.md).

| Pole | Wartość |
|------|---------|
| Tailwind | v4, klasy w JSX |
| Wejście CSS | `src/Clients/web/src/styles.css` |
| Skala odstępów | kroki `1`–`12` z `tokens.space`, po mapowaniu w `@theme` |
| React | `19.2.3` |
| `react-router` | `^7.9.4` (`NavLink`, `Link`) |

Domyślna skala Tailwinda (krok `5` = `1.25rem` = 20px) w tym kliencie nie obowiązuje. Po [02-motyw.md](02-motyw.md) przyrostek liczby jest kluczem `tokens.space`: `gap-5` to krok 5, czyli 24px z [../motyw.md](../motyw.md). `p-7` to 48px, `pt-9` to 80px, `pb-11` to 128px.

## Ścieżki w repo

| Ścieżka | Rola |
|---------|------|
| [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts) | `space`, `radius.card`, `radius.pill`, kolory |
| [src/Clients/web/src/styles.css](../../../src/Clients/web/src/styles.css) | `@import "tailwindcss"` i `@theme` |
| [src/Clients/web/src/app/Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) | kolumna strony, nav, stopka |
| [src/Clients/web/src/app/pages/courses/CoursesPage.tsx](../../../src/Clients/web/src/app/pages/courses/CoursesPage.tsx) | lista i siatka kart |
| [src/Clients/web/src/app/pages/home/HomeCourses.tsx](../../../src/Clients/web/src/app/pages/home/HomeCourses.tsx) | ta sama siatka pod hero |
| [src/Clients/web/src/app/pages/notes/NoteDetailPage.tsx](../../../src/Clients/web/src/app/pages/notes/NoteDetailPage.tsx) | kolumna artykułu |
| [docs/frontend/motyw.md](../motyw.md) | kontrakt liczb |

Klasy dopisujesz na elementach, które już są w tych plikach. Logika locale, `viewTransition` i wczesny `return` zostają w warstwie Reacta.

## Tutorial

### 1. Trzy szerokości i dwanaście kroków

Odstęp w klasie to zawsze krok `1`–`12`. Wartość w pikselach czyta [../motyw.md](../motyw.md). W JSX nie ma `p-[24px]`, `gap-[1.5rem]` ani `mx-[auto]`.

Szerokość kolumny jest osobną rolą. `tokens.ts` nie trzyma miary tekstu, więc web używa trzech klas `max-w` i żadnej czwartej:

| Rola | Klasa | Miara | Ekran |
|------|-------|-------|-------|
| Lista kart | `max-w-5xl` | 64rem | kursy, notatki (indeks), kompendium (indeks), blok wykładów na home |
| Lead pod tytułem listy | `max-w-xl` | 36rem | akapit wprowadzający pod `h1` listy |
| Artykuł | `max-w-2xl` | 42rem | szczegół notatki, szczegół kursu, hasło kompendium, CV |

Każda kolumna dostaje `mx-auto w-full`, żeby na wąskim oknie skurczyła się razem z viewportem, a na szerokim została na środku.

Przypisanie kroków, którego generator się trzyma:

| Krok | px | Klasy w tym pliku | Gdzie |
|------|----|-------------------|-------|
| 1 | 4 | `gap-1`, `py-1` | grupa PL/EN |
| 2 | 8 | `mb-2` | tytuł karty → podpis |
| 3 | 12 | `gap-3`, `py-3`, `mb-3` | nav poniżej `md`; data artykułu; akapit w karcie |
| 4 | 16 | `gap-4`, `px-3`, `px-4`, `py-4`, `mb-4` | linki nav od `md`; padding poziomy przycisku języka (`px-3`); nav poniżej `md` w poziomie (`px-4`); nav od `md` w pionie (`py-4`); lead pod `h1`; powrót i `h1` artykułu |
| 5 | 24 | `gap-5` | trzy grupy w nav od `md`; odstęp między kartami |
| 6 | 32 | `p-6`, `px-6` | środek karty; poziomy padding listy, artykułu, nav od `md` i stopki |
| 7 | 48 | `mb-7`, `pb-7` | nagłówek artykułu → treść; dół stopki |
| 8 | 64 | `mb-8`, `pt-8` | nagłówek listy → siatka; góra stopki |
| 9 | 80 | `pt-9` | góra listy i góra artykułu |
| 10 | 96 | — | zostaje dla hero w [04-typografia.md](04-typografia.md) i [../motion/02-hero.md](../motion/02-hero.md) |
| 11 | 128 | `pb-11` | dół listy i dół artykułu |
| 12 | 160 | — | wolny; ten plik go nie wydaje |

Kroki 10 i 12 nie pojawiają się na nav, siatce ani artykule. Większy oddech nad hero jest sprawą typografii i ruchu, nie drugiej skali na podstronach.

Radius karty to `rounded-card` (`tokens.radius.card`). Przycisk języka to `rounded-pill` (`tokens.radius.pill`). Nazwy wystawia `@theme` z [02-motyw.md](02-motyw.md).

### 2. Shell

Korzeń shellu jest kolumną na wysokość małego viewportu. `main` rośnie, stopka zostaje na dole krótkiej strony. Tła `bg-canvas` i atramentu `text-ink` generator nie powtarza na każdej sekcji.

`header` jest `sticky top-0 z-40` i zostaje w zwykłym przepływie. Przy starcie scrolla nie zasłania treści, więc `main` nie dostaje zapasu `padding-top` „pod pasek”. `z-40` jest jedynym `z-index` układu. Karty i artykuł zostają na `auto`.

Pasek jest płótnem o kryciu około 70% (`bg-canvas/70`) z `backdrop-blur-xl`, żeby treść przewijana pod spodem nie zlewała się z linkami. Jedna linia: `border-b border-ink/8`. `border-ink/8` to atrament z tokenu przy niskiej alfie, nie nowy hex. Header nie dostaje `overflow-hidden`, żeby pierścień fokusu z [05-stany.md](05-stany.md) miał gdzie się narysować.

Poniżej `md` (768px) pasek się zawija. Marka i grupa języka zostają w pierwszym rzędzie, język dosunięty w prawo (`ml-auto`). `nav` ma `order-last w-full`, więc linki spadają do drugiego rzędu na całą szerokość. Odstęp schodzi do kroku 3, padding do `px-4 py-3`.

Od `md` jest jeden rząd (`flex-nowrap`): marka, linki (`flex-1`), język (`ml-0`). Odstęp między tymi trzema grupami to krok 5, między linkami krok 4, padding `px-6 py-4`. Linki wewnątrz `nav` mogą zawinąć się same (`flex-wrap`, `min-w-0`). Grupa języka nie spada wtedy do nowego rzędu, bo zawijanie jest wyłączone na `header`.

Aktywny link zmienia kolor według [05-stany.md](05-stany.md). Padding, gap i rozmiar zostają te same, więc rząd nie skacze.

Stopka ma jedną linię `border-t border-ink/8`, padding `px-6 pt-8 pb-7`. Dół strony (`pb-11`) i góra stopki (`pt-8`) sumują się celowo: tekst kończy się wcześniej niż marka w stopce.

```tsx
<div className="flex min-h-svh flex-col bg-canvas text-ink">
  <header className="sticky top-0 z-40 flex flex-wrap items-center gap-3 border-b border-ink/8 bg-canvas/70 px-4 py-3 backdrop-blur-xl md:flex-nowrap md:gap-5 md:px-6 md:py-4">
    <NavLink to={`/${locale}`} end className="shrink-0">
      JJDevHub
    </NavLink>
    <nav
      aria-label={nav.language}
      className="order-last flex w-full min-w-0 flex-wrap items-center gap-3 md:order-none md:w-auto md:flex-1 md:gap-4"
    >
      <NavLink to={`/${locale}`} end>
        {nav.home}
      </NavLink>
      <NavLink to={`/${locale}/cv`}>{nav.cv}</NavLink>
      <NavLink to={`/${locale}/courses`}>{nav.courses}</NavLink>
      <NavLink to={`/${locale}/compendium`}>{nav.compendium}</NavLink>
      <NavLink to={`/${locale}/notes`}>{nav.notes}</NavLink>
    </nav>
    <div className="ml-auto flex shrink-0 gap-1 md:ml-0" role="group" aria-label={nav.language}>
      <button type="button" className="rounded-pill px-3 py-1" onClick={showPolish}>
        {nav.languagePl}
      </button>
      <button type="button" className="rounded-pill px-3 py-1" onClick={showEnglish}>
        {nav.languageEn}
      </button>
    </div>
  </header>
  <main className="w-full flex-1">{children}</main>
  <footer className="border-t border-ink/8 px-6 pt-8 pb-7">
    <p>JJDevHub</p>
  </footer>
</div>
```

`className` na linkach nav ograniczasz do układu. Kolor spoczynku, hover i stan aktywny dopisuje [05-stany.md](05-stany.md) na tych samych `NavLink`. Rozmiar pisma dopisuje [04-typografia.md](04-typografia.md).

### 3. Lista kursów

Sekcja listy: `mx-auto w-full max-w-5xl px-6 pt-9 pb-11`. Nagłówek strony (`header` z `h1` i leadem) ma `mb-8 max-w-xl`. Między `h1` a leadem jest `mb-3` na nagłówku. Lead nie dostaje własnego marginesu dolnego, bo `mb-8` na `header` już trzyma siatkę.

Siatka to lista:

```tsx
<ul className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
```

- poniżej `sm` (640px): jedna kolumna
- od `sm`: dwie
- od `lg` (1024px): trzy

Przy `max-w-5xl` i `px-6` komórka od `sm` ma ponad 16rem szerokości, więc karta nie robi się wąskim paskiem. Szablon `minmax(...)` i klasa arbitralna `grid-cols-[...]` są zbędne. `gap-5` jest w obu osiach. `preflight` Tailwinda zeruje punktor i padding `ul`; dodatkowej ramki listy nie ma.

Karta jest linkiem na całą komórkę. `h-full` wyrównuje wysokość w rzędzie. `min-w-0` na `li` pozwala długiemu tytułowi zawinąć się w siatce.

```tsx
<section className="mx-auto w-full max-w-5xl px-6 pt-9 pb-11">
  <header className="mb-8 max-w-xl">
    <h1 className="mb-3">{section.title}</h1>
    <p>{section.lead}</p>
  </header>
  <ul className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
    {section.items.map((course) => (
      <li key={course.slug} className="min-w-0">
        <Link className="block h-full rounded-card bg-white p-6" to={`/${locale}/courses/${course.slug}`}>
          <h2 className="mb-2">{course.title}</h2>
          <p className="mb-4">{course.subtitle}</p>
          {course.summary.map((paragraph) => (
            <p key={paragraph} className="mb-3 last:mb-0">
              {paragraph}
            </p>
          ))}
        </Link>
      </li>
    ))}
  </ul>
</section>
```

Karta: białe tło, `rounded-card`, padding kroku 6. Obrysu, `ring`, `shadow` i `divide-y` na siatce nie ma. Płótno shellu jest szare (`#f5f5f7`), karta biała (`#ffffff`) — kontrast bierze się z tokenów, nie z ramki. Odstęp `gap-5` jest światłem między kartami.

Blok wykładów na home (`HomeCourses`) używa tej samej `ul` i tej samej karty. Sekcja home, która nie jest hero, dostaje `mx-auto w-full max-w-5xl px-6`. Hero zostaje poza tą kolumną: pełna szerokość `main`, opis w [../motion/02-hero.md](../motion/02-hero.md) i [04-typografia.md](04-typografia.md).

Indeks notatek i indeks kompendium biorą kolumnę listy (`max-w-5xl`) i tę samą siatkę. Osobnej, ciaśniejszej kratki te ekrany nie dostają.

Pusta lista: `ul` się nie renderuje (wczesny widok z [../react/01-komponenty.md](../react/01-komponenty.md)). Pusty komunikat siedzi w tej samej kolumnie `max-w-5xl px-6 pt-9 pb-11`, żeby nie kleił się do lewej krawędzi pod navem. Wygląd komunikatu jest w [05-stany.md](05-stany.md).

### 4. Artykuł notatki

Szczegół notatki używa kolumny `max-w-2xl` (42rem). To miara czytania przy rozmiarze treści z [04-typografia.md](04-typografia.md): linia zostaje krótka, margines po bokach na szerokim oknie jest duży. Ta sama klasa idzie na szczegół kursu, hasło kompendium i CV. Indeks (lista) zostaje przy `max-w-5xl`.

Pion i poziom są jak na liście: `px-6 pt-9 pb-11`. Nagłówek artykułu ma `mb-7` (krok 7, ciaśniej niż `mb-8` nad siatką, bo pod spodem jest jeden wątek, nie kratka). Wewnątrz nagłówka: powrót `mb-4`, data `mb-3` i `block`, `h1` z `mb-4`. Lead (`summary`) bez dolnego marginesu.

Akapity treści stoją w jednym stosie `flex flex-col gap-4`. `gap-4` trzyma równe 16px między akapitami i nie dokłada światła pod ostatnim. Stos jest osobnym wrapperem, żeby `gap` nie rozsunął też nagłówka.

```tsx
<article className="mx-auto w-full max-w-2xl px-6 pt-9 pb-11">
  <header className="mb-7">
    <p className="mb-4">
      <Link to={`/${locale}/notes`}>{/* powrót, etykieta z treści */}</Link>
    </p>
    <time className="mb-3 block" dateTime={note.date}>
      {note.date}
    </time>
    <h1 className="mb-4">{note.title}</h1>
    <p>{note.summary}</p>
  </header>
  <div className="flex flex-col gap-4">
    {note.body.map((paragraph) => (
      <p key={paragraph}>{paragraph}</p>
    ))}
  </div>
</article>
```

Artykuł nie ma ramki, tła karty ani `max-w-5xl`. Biegnie po płótnie shellu. Jeden `h1` zostaje w `header`, zgodnie z [../html/01-semantyka.md](../html/01-semantyka.md).

### 5. Sprawdzenie

Pakietu pod sam układ nie instalujesz. Serwer dev jest w [../vite/01-dev.md](../vite/01-dev.md):

```bash
cd src/Clients/web
pnpm start
```

Potem, przy oknie szerokim (od `lg`) i zwężonym poniżej `md`:

- http://localhost:4200/pl — pasek w jednym rzędzie, po zwężeniu linki w drugim rzędzie, hero do krawędzi `main`
- http://localhost:4200/pl/courses — kolumna 64rem, siatka 3 / 2 / 1, białe karty, światło między nimi
- http://localhost:4200/pl/notes/dlaczego-cqrs — kolumna 42rem, akapity z równym krokiem 4, nav i stopka jak na liście

Treść tych adresów jest w bundlu (`pl.json`). API na 5080 nie jest potrzebne.

## Przypadki użycia

### Shell

Użytkownik otwiera dowolną stronę pod `/:lang` albo `/login`. Widzi markę, pięć linków (home, CV, kursy, kompendium, notatki) i PL/EN w jednym pasku przyklejonym do góry. Na szerokim oknie wszystko jest w jednym rzędzie. Poniżej 768px marka i język zostają u góry, linki schodzą niżej na całą szerokość. Przewinięcie trzyma pasek na górze; treść wjeżdża pod mleczne płótno. Aktywna pozycja nie zmienia wysokości paska. Stopka z marką jest pod treścią, także gdy strona jest krótka (`min-h-svh`). Login i register siedzą w tym samym shellu; szerokość formularza ustala [../shadcn/03-komponenty.md](../shadcn/03-komponenty.md), nie kolumna listy.

### Lista kursów

`/pl/courses` i `/en/courses`. Tytuł i lead są w węższej mierze (36rem) wewnątrz kolumny 64rem. Karty są białe, z radiusem tokenu, bez obrysu. Od `lg` są trzy w rzędzie, od `sm` dwie, węziej jedna. Odstęp między kartami jest taki sam w pionie i w poziomie (krok 5). Wnętrze karty ma 32px zapasu. Ta sama karta wraca w bloku wykładów na home. Pusta lista zostawia nav i stopkę, a komunikat trzyma kolumnę listy.

### Szczegół notatki

`/pl/notes/dlaczego-cqrs` (i ten sam slug przy `en`, gdy wpis jest w `en.json`). Tekst jest wyśrodkowany w 42rem. Nad tytułem jest powrót do indeksu i data. Pod tytułem lead, potem akapity co 16px. Po bokach na monitorze zostaje szerokie płótno. Indeks `/pl/notes` jest listą (`max-w-5xl`), nie tą wąską kolumną. Szczegół kursu, hasło kompendium i CV powtarzają `max-w-2xl` z tym samym `px-6 pt-9 pb-11`.

## Zasady wyglądu

- Duży oddech: góra strony krok 9 (80px), dół krok 11 (128px), siatka krok 5 (24px), karta krok 6 (32px). Generator nie ściska tego „żeby więcej weszło na ekran”.
- Mało ramek: `border-b border-ink/8` na `header` nav i `border-t border-ink/8` na `footer`. Karta, artykuł, sekcja, lead i przycisk języka zostają bez `border`, `ring`, `shadow` i `outline` od układu.
- Karta odcina się `bg-white` i `rounded-card` od `bg-canvas`. Paleta zostaje przy tokenach (`#f5f5f7`, `#ffffff`, `#1d1d1f`). Akcent `#0071e3` na układzie paska i siatki nie występuje; należy do stanów i przycisków.
- `main` i korzeń shellu nie dostają `max-w-5xl` ani `max-w-2xl`. Kolumnę nakłada sekcja listy albo `article`.
- Równy odstęp między rodzeństwem w stosie to `flex flex-col gap-*`. Margines zostaje tam, gdzie sąsiedzi mają różne kroki (tytuł karty, nagłówek artykułu).
- Przyrostki `1`–`12` oznaczają `tokens.space` po `@theme`. Klasa arbitralna odstępu, koloru i radiusu nie wchodzi.
- Pasek nav jest wspólny dla `pl` i `en`, dla stron treści oraz dla `/login` i `/register`. Intranet później używa tego samego paska i tych samych kolumn w tym samym kliencie.
- Ekran telefonu jest osobny. Te same kroki odstępu może przenieść [../nativewind/02-ekrany.md](../nativewind/02-ekrany.md). `sticky` dokumentu, `backdrop-blur` i `md:` zostają przy webie.

## Poza zakresem

- Instalacja Tailwinda, plugin Vite, zamiana wejścia CSS — [01-instalacja.md](01-instalacja.md).
- Zapis `@theme` i zakaz drugiej palety — [02-motyw.md](02-motyw.md). Liczby — [../motyw.md](../motyw.md).
- Inter, tracking, rozmiary `h1` i kontrast ciemnego hero z jasną sekcją — [04-typografia.md](04-typografia.md).
- hover, focus-visible, disabled, wygląd pustej listy i błąd pola — [05-stany.md](05-stany.md).
- Zejście z arkuszy `*.scss` i `@apply` — [06-css-zamiast-scss.md](06-css-zamiast-scss.md).
- Który znacznik jest `header`, `nav`, `main`, `article` — [../html/01-semantyka.md](../html/01-semantyka.md). Ten plik tylko nakłada na nie klasy.
- Drzewo tras i przełącznik pierwszego segmentu — [../react/02-trasy.md](../react/02-trasy.md).
- Wejście sekcji, zmiana widoku, scroll hero — [../motion/01-przejscia.md](../motion/01-przejscia.md), [../motion/02-hero.md](../motion/02-hero.md). Układ nie przesuwa karty przy hoverze.
- Formularz logowania (button, input, miara formularza) — [../shadcn/03-komponenty.md](../shadcn/03-komponenty.md).
- Lista kursów na telefonie — [../nativewind/02-ekrany.md](../nativewind/02-ekrany.md).
- Tamagui, drugi klient intranetu, Sass.

## Gotowe gdy

- Klasy odstępu na shellu, liście kursów i szczegółach notatki używają kroków z tabeli (1–9 i 11). W tych plikach nie ma `p-[…]`, `gap-[…]` ani kroku Tailwinda w znaczeniu „n × 0.25rem”.
- Korzeń shellu to `flex min-h-svh flex-col`. `main` ma `w-full flex-1` i nie ma `max-w-*`.
- Od `md` nav jest jednym rzędem (`gap-5`, linki `gap-4`, `px-6 py-4`). Poniżej `md` linki są w drugim rzędzie (`order-last w-full`, `gap-3`, `px-4 py-3`), a PL/EN zostaje w pierwszym (`ml-auto`, `gap-1`).
- Jedyny `z-index` to `z-40` na `header`. Header jest `sticky top-0`, z `bg-canvas/70`, `backdrop-blur-xl` i `border-b border-ink/8`. Stopka ma `border-t border-ink/8`, `px-6 pt-8 pb-7`.
- `/pl/courses`: sekcja `max-w-5xl px-6 pt-9 pb-11`, lead `max-w-xl`, siatka `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3` i `gap-5`. Karta to `block h-full rounded-card bg-white p-6` bez obrysu i cienia.
- `/pl/notes/dlaczego-cqrs`: `article` z `max-w-2xl px-6 pt-9 pb-11`, nagłówek `mb-7`, akapity w `flex flex-col gap-4`.
- Ta sama karta i siatka są na bloku wykładów home. Ta sama kolumna `max-w-2xl` jest na szczegółach kursu, haśle kompendium i CV. Indeksy notatek i kompendium zostają przy `max-w-5xl`.
- Hero home dochodzi do krawędzi `main`. Pusta lista kursów trzyma kolumnę `max-w-5xl` pod tym samym navem.
