# Komponenty React

Komponent w JJDevHub czyta się od góry do dołu: najpierw typ propsów, potem funkcja czysta, potem hooki, wartości wyliczone, handlery i na końcu `return`. JSX składa HTML5. Filtr, pusta lista i dłuższy handler stoją nad układem.

Krótka lista zasad jest w [.cursor/rules/react.mdc](../../../.cursor/rules/react.mdc). Ten plik rozpisuje je na shellu i karcie kursu, żeby dało się z niego napisać pliki TSX.

React składa znaczniki. Vite podaje jeden arkusz `src/styles.css`. Tailwind v4 dokłada klasy na tych znacznikach. shadcn i Motion siedzą na tym samym HTML. Liczby kolorów, skali i odstępów są w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts); kontrakt opisuje [motyw.md](../motyw.md).

## Po co

Jeden plik to jeden powód do zmiany. Shell zmienia się, gdy zmienia się chrome (marka, nawigacja, język, miejsce na stronę). Karta kursu zmienia się, gdy zmienia się skrót kursu i link do szczegółu. Lista kursów zmienia się, gdy zmienia się nagłówek strony albo zachowanie pustej listy. Drugi powód albo drugi ekran to nowy plik.

Dziś skrót kursu jest wklejony w [CoursesPage.tsx](../../../src/Clients/web/src/app/pages/courses/CoursesPage.tsx) i w [HomeCourses.tsx](../../../src/Clients/web/src/app/pages/home/HomeCourses.tsx). Docelowo oba miejsca wołają `CourseCard`. Pusty blok rozdziałów już wraca wcześniej w [CourseChapters.tsx](../../../src/Clients/web/src/app/pages/courses/CourseChapters.tsx) — ten sam odruch obowiązuje listę kursów.

## Wersje i pakiety

Klient web: [src/Clients/web/package.json](../../../src/Clients/web/package.json). Manager pakietów: pnpm `10.33.0`.

| Pakiet | Wersja w repo | Rola w komponencie |
| --- | --- | --- |
| `react` | `19.2.3` | funkcja komponentu, hooki |
| `react-dom` | `19.2.3` | render w `main`; komponenty go nie importują |
| `@types/react` | `^19.2.0` | `ReactNode` i typy propsów |
| `react-router` | `^7.9.4` | `Link`, `NavLink`, `useLocation`, `useNavigate` |

Import idzie z `react-router`, nie z `react-router-dom`. JSX bierze się z automatycznego runtime React 19: plik komponentu nie zaczyna się od `import React from 'react'`. Typy wchodzą przez `import type`.

Komponent jest zwykłą funkcją z eksportem nazwanym. Nazwa pliku jest nazwą komponentu (`Shell.tsx` eksportuje `Shell`). W pliku nie ma klasy, `React.FC`, `any`, asercji `as` ani wykrzyknika przy wartości, która może być pusta.

## Ścieżki w repo

Wszystko poniżej jest klientem web. Ekran telefonu jest osobnym komponentem w `src/Clients/mobile` — [nativewind/02-ekrany.md](../nativewind/02-ekrany.md).

| Plik | Odpowiedzialność |
| --- | --- |
| [src/Clients/web/src/app/App.tsx](../../../src/Clients/web/src/app/App.tsx) | owija trasy w `<Shell>` |
| [src/Clients/web/src/app/Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) | `header`, `nav`, `main`, `footer`, przełącznik `pl` / `en` |
| [src/Clients/web/src/app/pages/courses/CourseCard.tsx](../../../src/Clients/web/src/app/pages/courses/CourseCard.tsx) | jeden kurs: tytuł, podtytuł, pierwszy akapit, link |
| [src/Clients/web/src/app/pages/courses/CoursesPage.tsx](../../../src/Clients/web/src/app/pages/courses/CoursesPage.tsx) | nagłówek listy i wczesny return, gdy `items` jest puste |
| [src/Clients/web/src/app/pages/courses/CourseChapters.tsx](../../../src/Clients/web/src/app/pages/courses/CourseChapters.tsx) | opcjonalny blok; pusta tablica znika (`return null`) |
| [src/Clients/web/src/app/content/content.model.ts](../../../src/Clients/web/src/app/content/content.model.ts) | `LocaleCode`, `CourseContent`, `NavContent` |
| [src/Clients/web/src/app/content/content.ts](../../../src/Clients/web/src/app/content/content.ts) | `localeFromPathname`, `siteFor`, `pathForLocale` |

`CourseCard.tsx` dochodzi jako osobny plik. Shell i strona listy zostają pod tymi samymi ścieżkami.

Treść karty pochodzi z JSON w bundlu (`pl` / `en`), nie z HTTP. Skąd bierze się obiekt, opisuje [03-tresc-i-auth.md](03-tresc-i-auth.md). Tablica tras opisuje [02-trasy.md](02-trasy.md).

## Tutorial

### 1. Nowy plik

Z katalogu repozytorium plik karty ląduje obok strony listy:

```bash
touch src/Clients/web/src/app/pages/courses/CourseCard.tsx
```

Shell już jest. Edycja idzie w istniejący [Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx), bez drugiego chrome i bez arkusza obok komponentu.

### 2. Kolejność w pliku karty

Nad komponentem zostaje typ i funkcja, która nie potrzebuje hooków. Ścieżka szczegółu zależy tylko od locale i sluga:

```tsx
import { Link } from 'react-router';

import type { CourseContent, LocaleCode } from '../../content/content.model';

type CourseCardProps = {
  locale: LocaleCode;
  course: CourseContent;
  heading: 'h2' | 'h3';
};

function coursePath(locale: LocaleCode, slug: string): string {
  return `/${locale}/courses/${slug}`;
}

export function CourseCard({ locale, course, heading }: CourseCardProps) {
  const to = coursePath(locale, course.slug);
  const Title = heading === 'h2' ? 'h2' : 'h3';
  const lead = course.summary[0];

  return (
    <article>
      <Title>
        <Link to={to} viewTransition>
          {course.title}
        </Link>
      </Title>
      <p>{course.subtitle}</p>
      {lead ? <p>{lead}</p> : null}
    </article>
  );
}
```

Kolejność w funkcji: wartości wyliczone, potem `return`. `lead` może być `undefined`, gdy `summary` jest puste — w JSX zostaje jeden poziom warunku, bez `course.summary[0]!`.

`heading` jest faktem z rodzica. Strona `/courses` ma własne `h1`, więc karta dostaje `'h2'`. Sekcja na home ma własne `h2`, więc karta dostaje `'h3'`. Poziom nagłówka nie jest drugim `useState`.

`viewTransition` na `Link` zostawia zmianę widoku przeglądarce. Ruch wejścia sekcji opisuje [motion/01-przejscia.md](../motion/01-przejscia.md).

### 3. Pusta lista nad układem

Strona listy ma dwa zakończenia. Puste `items` wraca, zanim powstanie `ul`. Użytkownik nadal widzi `h1` i lead. Zdanie pustego stanu nazywa się tu `emptyLabel` i przychodzi z treści aktywnego locale, tak jak `title` i `lead`. Polskiego literału w komponencie nie ma. Nazwę pola w JSON ustala [03-tresc-i-auth.md](03-tresc-i-auth.md).

```tsx
import { useLocation } from 'react-router';

import { localeFromPathname, siteFor } from '../../content/content';
import { CourseCard } from './CourseCard';

export function CoursesPage() {
  const { pathname } = useLocation();
  const locale = localeFromPathname(pathname);
  const section = siteFor(locale).courses;
  const emptyLabel = section.emptyLabel;

  if (section.items.length === 0) {
    return (
      <section>
        <header>
          <h1>{section.title}</h1>
          <p>{section.lead}</p>
        </header>
        <p>{emptyLabel}</p>
      </section>
    );
  }

  return (
    <section>
      <header>
        <h1>{section.title}</h1>
        <p>{section.lead}</p>
      </header>
      <ul>
        {section.items.map((course) => (
          <li key={course.slug}>
            <CourseCard locale={locale} course={course} heading="h2" />
          </li>
        ))}
      </ul>
    </section>
  );
}
```

Klucz elementu listy to `course.slug`. Indeks tablicy kluczem nie jest. Proste mapowanie na `CourseCard` zostaje w JSX. Filtr i gałąź „pusto” są nad nim.

Blok, którego przy pustce użytkownik w ogóle nie widzi (rozdziały, lekcje, plan), robi to co `CourseChapters`: `if (chapters.length === 0) return null`. Nagłówek takiego bloku nie renderuje się nad pustą listą.

### 4. Shell

[App.tsx](../../../src/Clients/web/src/app/App.tsx) renderuje `<Shell><Routes /></Shell>`. Shell przyjmuje `children` i nie zna tabeli tras.

W komponencie kolejność jest stała: hooki (stan, refy, własne hooki, efekty), wartości wyliczone, handlery, `return`. Locale jest segmentem URL, więc nie ma `useState` na język. Jedyny efekt dotyka `document.documentElement.lang` i w sprzątaniu przywraca poprzedni język. Zależność to `[locale]`. Wyłączenie lintera zależności nie wchodzi do pliku.

Handler w JSX ma jedną linijkę (`onClick={showPolish}`). `switchLocale` żyje nad `return`, bo ma kilka wyjść: ten sam język, brak ścieżki (`pathForLocale` zwraca `null` na `/login` i `/register`), w pozostałych przypadkach `navigate`.

`NavLink` sam oznacza bieżącą stronę atrybutem `aria-current="page"`. Przycisk języka dostaje `aria-pressed`. Aktywny wygląd jest klasą Tailwinda na tym atrybucie — [tailwind/05-stany.md](../tailwind/05-stany.md) — a nie sklejanym stringiem klasy w komponencie.

```tsx
import { useEffect, type ReactNode } from 'react';
import { NavLink, useLocation, useNavigate } from 'react-router';

import { localeFromPathname, pathForLocale, siteFor } from './content/content';
import type { LocaleCode } from './content/content.model';

type ShellProps = {
  children: ReactNode;
};

export function Shell({ children }: ShellProps) {
  const location = useLocation();
  const navigate = useNavigate();
  const locale = localeFromPathname(location.pathname);
  const nav = siteFor(locale).nav;

  useEffect(() => {
    const previous = document.documentElement.lang;
    document.documentElement.lang = locale;
    return () => {
      document.documentElement.lang = previous;
    };
  }, [locale]);

  function switchLocale(next: LocaleCode): void {
    if (next === locale) {
      return;
    }
    const target = pathForLocale(location.pathname, location.search, location.hash, next);
    if (!target) {
      return;
    }
    void navigate(target, { viewTransition: true });
  }

  function showPolish(): void {
    switchLocale('pl');
  }

  function showEnglish(): void {
    switchLocale('en');
  }

  return (
    <>
      <header>
        <NavLink to={`/${locale}`} end viewTransition>
          JJDevHub
        </NavLink>
        <nav aria-label={nav.language}>
          <NavLink to={`/${locale}`} end viewTransition>
            {nav.home}
          </NavLink>
          <NavLink to={`/${locale}/cv`} viewTransition>
            {nav.cv}
          </NavLink>
          <NavLink to={`/${locale}/courses`} viewTransition>
            {nav.courses}
          </NavLink>
          <NavLink to={`/${locale}/compendium`} viewTransition>
            {nav.compendium}
          </NavLink>
          <NavLink to={`/${locale}/notes`} viewTransition>
            {nav.notes}
          </NavLink>
        </nav>
        <div role="group" aria-label={nav.language}>
          <button type="button" aria-pressed={locale === 'pl'} onClick={showPolish}>
            {nav.languagePl}
          </button>
          <button type="button" aria-pressed={locale === 'en'} onClick={showEnglish}>
            {nav.languageEn}
          </button>
        </div>
      </header>
      <main>{children}</main>
      <footer>
        <p>JJDevHub</p>
      </footer>
    </>
  );
}
```

Etykiety (`nav.home`, `nav.languagePl`, …) pochodzą z `siteFor(locale).nav`. Shell ma jeden `h1` mniej: tytuł strony jest w `children`. Znaczniki `header`, `nav`, `main` i `footer` zostają; katalog semantyki jest w [html/01-semantyka.md](../html/01-semantyka.md).

Logika użyta drugi raz (ta sama karta na home i na liście, ten sam pusty return w opcjonalnym bloku) wychodzi do komponentu albo do funkcji czystej. Drugi raz wklejony JSX jest sygnałem do wycięcia pliku.

### 5. Sprawdzenie typów

Z katalogu repozytorium:

```bash
pnpm --dir src/Clients/web exec tsc -p tsconfig.json --noEmit
```

Komenda ma wrócić kodem 0. `emptyLabel` na sekcji courses musi być w typie, który czyta strona — inaczej `tsc` słusznie stanie na tym polu, aż dokument treści doda je do modelu. Bramka `pnpm build` (typ plus Vite) jest w dokumencie Vite o buildzie, nie tutaj.

Test komponentu sprawdza tekst, który widzi użytkownik (tytuł kursu, puste zdanie, aktywny język). Przepis testu jest w [04-testy.md](04-testy.md).

W przykładach celowo nie ma klas odstępu ani koloru. Te klasy dopisuje się na tych samych znacznikach. Przepis układu jest w [tailwind/03-uklad.md](../tailwind/03-uklad.md), mapowanie tokenów na klasy w [tailwind/02-motyw.md](../tailwind/02-motyw.md).

## Przypadki użycia

### Shell

Użytkownik jest na `/pl/courses`. Shell czyta locale `pl` z pathname, ustawia `lang` dokumentu na `pl` i pokazuje etykiety z polskiego JSON. W `nav` są: home, cv, courses, compendium, notes. Marka `JJDevHub` prowadzi na `/pl`. Grupa języka ma `aria-pressed` na polskim przycisku.

Klik „EN” woła `showEnglish`. `pathForLocale` podmienia pierwszy segment. `navigate` idzie na `/en/courses` i zostawia query oraz hash. Efekt sprząta poprzedni `lang`, potem ustawia `en`.

Na `/login` i `/register` `pathForLocale` zwraca `null`. Przycisk języka kończy handler i zostawia adres. Login i register są poza prefiksem języka; szczegóły tras są w [02-trasy.md](02-trasy.md).

`main` renderuje `children`. Shell nie wybiera strony kursu ani formularza.

### Karta kursu

Lista dostaje z bundla kurs o slugu `dotnet`, tytule, podtytule i `summary` z co najmniej jednym akapitem. `CourseCard` z `heading="h2"` renderuje artykuł, link na `/pl/courses/dotnet` i pierwszy akapit. Kolejne akapity `summary` zostają na stronie szczegółu, nie w karcie.

Ta sama karta na home dostaje `heading="h3"`, bo sekcja home ma już `h2`. Propsy są te same: `locale`, `course`, `heading`.

Gdy `summary` jest puste, karta nadal pokazuje tytuł i podtytuł. Akapit leadu się nie renderuje. Brak sluga w danych nie jest naprawiany w karcie — slug jest częścią `CourseContent` i kluczem listy.

### Wczesny return na pustą listę

Sekcja courses dla locale ma `items: []`. `CoursesPage` wraca przed `ul`: widać `h1`, lead i `emptyLabel`. Mapowania kart nie ma, więc nie ma też pustego `ul` ani klucza z indeksu.

Szczegół kursu bez rozdziałów woła `CourseChapters`. Długość `chapters` równa 0 kończy się `return null`. Sekcja szczegółu nie dostaje pustego `h2`.

Błąd ładowania JSON z bundla i błąd `fetch` logowania to inne pliki ([03-tresc-i-auth.md](03-tresc-i-auth.md)). Tu „pusto” znaczy: tablica treści, którą komponent już dostał, ma długość 0.

## Zasady wyglądu

Komponent zostawia w drzewie semantyczny HTML. Shell: `header`, `nav`, `main`, `footer`. Lista: `section`, jeden `h1`, `ul` / `li`. Karta: `article` i tytuł `h2` albo `h3` według propsa. Przycisk języka jest `button type="button"`.

Klasy na tych znacznikach biorą płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3` i krój Inter z tokenów (`canvas`, `ink`, `accent`, `font.family` w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts)). Hex w `className` i druga paleta w komponencie nie występują. Odstęp jest duży, ramek mało: karta kursu nie dostaje obrysu „na zapas”. Ciemny hero (`darkChapter`) jest na home, nie w shellu i nie na karcie kursu.

Aktywny link i wciśnięty język wyglądają przez `aria-current` i `aria-pressed`, nie przez osobny zestaw klas liczony w JS.

## Poza zakresem

- Tablica `Routes`, `LangGate`, redirect złego języka — [02-trasy.md](02-trasy.md).
- Import `pl.json` / `en.json` / `cv.json`, `cv.local.json`, `fetch` na `/login` i `/register` — [03-tresc-i-auth.md](03-tresc-i-auth.md).
- Vitest i Testing Library — [04-testy.md](04-testy.md).
- Katalog znaczników ponad przykład shellu i karty — [html/01-semantyka.md](../html/01-semantyka.md).
- Instalacja Tailwinda, `@theme`, siatka, typografia — katalog `docs/frontend/tailwind/`.
- `button` i `input` z shadcn — [shadcn/03-komponenty.md](../shadcn/03-komponenty.md). Nawigacja shellu zostaje przy `NavLink`.
- Wejście sekcji, hero i `prefers-reduced-motion` — katalog `docs/frontend/motion/`.
- Ekran listy na telefonie — [nativewind/02-ekrany.md](../nativewind/02-ekrany.md). To osobny komponent, nie ten sam plik webowy.
- Intranet. Gdy treść będzie w API, nowy ekran jest nowym plikiem w tym samym kliencie web, na tych samych zasadach kolejności.
- Tamagui.

## Gotowe gdy

- `Shell`, `CourseCard` i `CoursesPage` są osobnymi funkcjami w plikach o tych samych nazwach, z eksportem nazwanym.
- W pliku karty nad komponentem jest typ propsów i czysta `coursePath`. W shellu hooki poprzedzają handlery, a handler w JSX ma jedną linijkę.
- Pusta lista kursów wraca przed `ul` i pokazuje `h1` oraz `emptyLabel` z locale. Pusty blok rozdziałów zwraca `null`.
- Lista używa `key={course.slug}`. Karta prowadzi na `/${locale}/courses/${slug}` i pokazuje tytuł, podtytuł oraz pierwszy akapit `summary`, gdy ten akapit jest.
- Shell ustawia `document.documentElement.lang` i sprząta efekt. Przełącznik podmienia pierwszy segment albo nic nie robi na `/login` i `/register`.
- W plikach komponentów nie ma `any`, `as`, `!` ani `React.FC`.
- `pnpm --dir src/Clients/web exec tsc -p tsconfig.json --noEmit` kończy się kodem 0.
- Użytkownik na `/pl/courses` widzi markę, pięć linków nawigacji, przełącznik języka oraz karty albo jedno zdanie pustej listy.
