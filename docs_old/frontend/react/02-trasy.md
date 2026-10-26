# Trasy

Ten plik ustala adresy webu JJDevHub i to, który ekran wchodzi w `main`. Wzorzec jest w [App.tsx](../../../src/Clients/web/src/app/App.tsx) i [Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx).

React składa drzewo tras i HTML5 w shellu oraz na stronach. Vite podaje jeden CSS. Klasy Tailwinda, komponenty shadcn i Motion siedzą na tym samym HTML. Tutaj jest wyłącznie URL, locale i powłoka nawigacji.

## Po co

Język jest pierwszym segmentem ścieżki. Treść publiczna żyje pod `/pl` i `/en`. Wejście na `/` oraz każdy adres spoza tej mapy ląduje na `/pl`. Login i rejestracja mają stałe ścieżki `/login` i `/register`, bez prefiksu języka.

Shell zostaje zamontowany przy każdej zmianie adresu. Przełącznik języka podmienia pierwszy segment i zostawia resztę ścieżki, query oraz hash. Na loginie i rejestracji przełącznik adresu nie zmienia.

## Wersje i pakiety

Klient: [src/Clients/web/package.json](../../../src/Clients/web/package.json).

| Pakiet | Wersja w repo |
| --- | --- |
| `react` | 19.2.3 |
| `react-dom` | 19.2.3 |
| `react-router` | ^7.9.4 |

Importy idą z pakietu `react-router`. W katalogu klienta:

```bash
cd src/Clients/web
pnpm add react-router@^7.9.4
```

`react` i `react-dom` są już przypięte do 19.2.3. Router klienta to ten pakiet.

## Ścieżki w repo

| Plik | Rola |
| --- | --- |
| [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) | `BrowserRouter` wokół `App` |
| [src/Clients/web/src/app/App.tsx](../../../src/Clients/web/src/app/App.tsx) | drzewo `Routes` |
| [src/Clients/web/src/app/Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) | belka, linki, przełącznik, `lang` dokumentu |
| [src/Clients/web/src/app/LangGate.tsx](../../../src/Clients/web/src/app/LangGate.tsx) | `pl` i `en`, dalej `Outlet` |
| [src/Clients/web/src/app/GuestRoute.tsx](../../../src/Clients/web/src/app/GuestRoute.tsx) | login i register tylko dla gościa |
| [src/Clients/web/src/app/content/content.ts](../../../src/Clients/web/src/app/content/content.ts) | `isLocale`, `localeFromPathname`, `pathForLocale` |
| [src/Clients/web/src/app/pages/home/HomePage.tsx](../../../src/Clients/web/src/app/pages/home/HomePage.tsx) | indeks `/:lang` |
| [src/Clients/web/src/app/pages/cv/CvPage.tsx](../../../src/Clients/web/src/app/pages/cv/CvPage.tsx) | `cv` |
| [src/Clients/web/src/app/pages/courses/CoursesPage.tsx](../../../src/Clients/web/src/app/pages/courses/CoursesPage.tsx) | lista kursów |
| [src/Clients/web/src/app/pages/courses/CourseDetailPage.tsx](../../../src/Clients/web/src/app/pages/courses/CourseDetailPage.tsx) | `courses/:slug` |
| [src/Clients/web/src/app/pages/compendium/CompendiumPage.tsx](../../../src/Clients/web/src/app/pages/compendium/CompendiumPage.tsx) | lista haseł |
| [src/Clients/web/src/app/pages/compendium/CompendiumDetailPage.tsx](../../../src/Clients/web/src/app/pages/compendium/CompendiumDetailPage.tsx) | `compendium/:slug` |
| [src/Clients/web/src/app/pages/notes/NotesPage.tsx](../../../src/Clients/web/src/app/pages/notes/NotesPage.tsx) | lista notatek |
| [src/Clients/web/src/app/pages/notes/NoteDetailPage.tsx](../../../src/Clients/web/src/app/pages/notes/NoteDetailPage.tsx) | `notes/:slug` |
| [src/Clients/web/src/app/pages/login/LoginPage.tsx](../../../src/Clients/web/src/app/pages/login/LoginPage.tsx) | `/login` |
| [src/Clients/web/src/app/pages/register/RegisterPage.tsx](../../../src/Clients/web/src/app/pages/register/RegisterPage.tsx) | `/register` |

Jeden komponent na plik, nazwa pliku równa nazwie komponentu. Skład komponentu opisuje [01-komponenty.md](01-komponenty.md).

## Mapa URL

`:lang` przyjmuje wyłącznie `pl` albo `en`. Dzieci `/:lang` mają ścieżki względne, bez ukośnika na początku. Indeks `/:lang` to home. Segmentu `home` w URL nie ma.

| Adres | Wynik |
| --- | --- |
| `/` | `Navigate` z `replace` na `/pl` |
| `/pl`, `/en` | `HomePage` |
| `/:lang/cv` | `CvPage` |
| `/:lang/courses` | `CoursesPage` |
| `/:lang/courses/:slug` | `CourseDetailPage` |
| `/:lang/compendium` | `CompendiumPage` |
| `/:lang/compendium/:slug` | `CompendiumDetailPage` |
| `/:lang/notes` | `NotesPage` |
| `/:lang/notes/:slug` | `NoteDetailPage` |
| `/login` | `GuestRoute` i `LoginPage` |
| `/register` | `GuestRoute` i `RegisterPage` |
| zły `:lang`, nieznana ścieżka, `*` | `Navigate` z `replace` na `/pl` |

Lista i szczegół są rodzeństwem. `CoursesPage` nie owija `CourseDetailPage` przez `Outlet`. To samo dotyczy kompendium i notatek. Slug to jeden segment. Adres z kolejnym segmentem, na przykład `/pl/courses/a/b`, nie ma trasy dziecka i wpada w `*`.

Nieznany slug, który ma kształt `/:lang/courses/:slug`, zostaje w tym samym języku i wraca na listę tej sekcji. To osobna reguła od złego języka.

## Tutorial

### 1. BrowserRouter

W [main.tsx](../../../src/Clients/web/src/main.tsx) kolejność providerów jest taka: `AuthProvider`, wewnątrz `BrowserRouter`, wewnątrz `App`. `useNavigate` i `useLocation` działają dopiero pod routerem. Sesja auth jest dostępna dla `GuestRoute`, bo provider stoi wyżej.

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router';

import { App } from './app/App';
import { AuthProvider } from './app/auth/auth';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AuthProvider>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </AuthProvider>
  </StrictMode>,
);
```

`basename` zostaje pusty. Adresy w linkach są ścieżkami od korzenia hosta (`/pl`, `/login`).

### 2. Drzewo w App

`Shell` owija całe `<Routes>` jako `children`. Belka jest więc przy każdej trasie, a dopasowanie strony dzieje się w środku. `Shell` sam nie jest trasą z `Outlet`.

`/login` i `/register` są rodzeństwem `/:lang`, zadeklarowanym przed parametrem. `LangGate` puszcza dalej wyłącznie `pl` i `en`, więc segment `login` pod `/:lang` skończyłby się przekierowaniem na `/pl`. Gwiazdka jest ostatnim rodzeństwem i zbiera resztę.

```tsx
import { Navigate, Route, Routes } from 'react-router';

import { GuestRoute } from './GuestRoute';
import { LangGate } from './LangGate';
import { Shell } from './Shell';
import { CompendiumDetailPage } from './pages/compendium/CompendiumDetailPage';
import { CompendiumPage } from './pages/compendium/CompendiumPage';
import { CourseDetailPage } from './pages/courses/CourseDetailPage';
import { CoursesPage } from './pages/courses/CoursesPage';
import { CvPage } from './pages/cv/CvPage';
import { HomePage } from './pages/home/HomePage';
import { LoginPage } from './pages/login/LoginPage';
import { NoteDetailPage } from './pages/notes/NoteDetailPage';
import { NotesPage } from './pages/notes/NotesPage';
import { RegisterPage } from './pages/register/RegisterPage';

export function App() {
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Navigate to="/pl" replace />} />
        <Route
          path="/login"
          element={
            <GuestRoute>
              <LoginPage />
            </GuestRoute>
          }
        />
        <Route
          path="/register"
          element={
            <GuestRoute>
              <RegisterPage />
            </GuestRoute>
          }
        />
        <Route path="/:lang" element={<LangGate />}>
          <Route index element={<HomePage />} />
          <Route path="cv" element={<CvPage />} />
          <Route path="courses" element={<CoursesPage />} />
          <Route path="courses/:slug" element={<CourseDetailPage />} />
          <Route path="compendium" element={<CompendiumPage />} />
          <Route path="compendium/:slug" element={<CompendiumDetailPage />} />
          <Route path="notes" element={<NotesPage />} />
          <Route path="notes/:slug" element={<NoteDetailPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/pl" replace />} />
      </Routes>
    </Shell>
  );
}
```

Przekierowania na `/pl` używają `replace`, więc zły adres nie zostaje w historii.

### 3. Bramka języka

`isLocale` w [content.ts](../../../src/Clients/web/src/app/content/content.ts) zwraca prawdę wyłącznie dla `'pl'` i `'en'`. `LangGate` czyta parametr `lang`. Zły segment zastępuje adres przez `/pl`. Dobry segment renderuje `Outlet`, czyli indeks albo dziecko.

```tsx
import { Navigate, Outlet, useParams } from 'react-router';

import { isLocale } from './content/content';

export function LangGate() {
  const { lang } = useParams();
  if (!isLocale(lang)) {
    return <Navigate to="/pl" replace />;
  }
  return <Outlet />;
}
```

Przykłady, które bramka sprowadza do `/pl`: `/de`, `/fr/cv`, `/login` gdyby ta ścieżka była dzieckiem `/:lang`. `/pl/notes/architektura` przechodzi, bo `lang` to `pl`.

### 4. Locale ze ścieżki i podmiana pierwszego segmentu

Dwie funkcje w `content.ts` są kontraktem shella. Treść JSON opisuje [03-tresc-i-auth.md](03-tresc-i-auth.md). Reguła URL zostaje tutaj.

`localeFromPathname` bierze pierwszy niepusty segment. Gdy to `pl` albo `en`, to jest język. W każdym innym przypadku, w tym na `/login` i `/register`, wynikiem jest `pl`.

`pathForLocale` składa cel przełącznika:

1. Pierwszy segment `login` albo `register` daje `null`. Shell wtedy nie woła `navigate`.
2. Pierwszy segment `pl` albo `en` jest wymieniany na język docelowy.
3. Inny pierwszy segment dostaje język docelowy doklejony z przodu.
4. `search` i `hash` z `useLocation` dopisują się bez zmian. Oba stringi z routera już zawierają `?` i `#`, albo są puste.

```tsx
const UNLOCALIZED = new Set(['login', 'register']);

export function pathForLocale(
  pathname: string,
  search: string,
  hash: string,
  next: LocaleCode,
): string | null {
  const segments = pathname.split('/').filter(Boolean);
  if (UNLOCALIZED.has(segments[0] ?? '')) {
    return null;
  }
  if (isLocale(segments[0])) {
    segments[0] = next;
  } else {
    segments.unshift(next);
  }
  return `/${segments.join('/')}${search}${hash}`;
}
```

| Było | Język | Wynik |
| --- | --- | --- |
| `/pl/notes/architektura?q=1#sekcja` | `en` | `/en/notes/architektura?q=1#sekcja` |
| `/en/cv` | `pl` | `/pl/cv` |
| `/en` | `pl` | `/pl` |
| `/login` | `en` | `null` |
| `/register` | `pl` | `null` |

### 5. Shell

Shell czyta `useLocation` i `useNavigate`. Język belki to `localeFromPathname(location.pathname)`. Etykiety linków biorą się z `siteFor(locale).nav`.

Efekt ustawia `document.documentElement.lang` na ten język i przy sprzątaniu przywraca poprzednią wartość. Wejście na `/en` daje `lang="en"`. Wejście na `/login` daje `lang="pl"`, bo pierwszy segment nie jest locale.

Przełącznik to dwa przyciski, po jednym na `pl` i `en`. Klik w już aktywny język kończy się od razu. W przeciwnym razie shell liczy `pathForLocale`. `null` kończy obsługę. Inaczej:

```tsx
void navigate(target, { viewTransition: true });
```

To dopisuje wpis historii. Wstecz wraca do poprzedniego języka. `viewTransition` jest haczykiem zmiany widoku; ruch opisuje [motion/01-przejscia.md](../motion/01-przejscia.md).

Linki belki wskazują bieżący język:

| Kontrolka | Cel | `end` |
| --- | --- | --- |
| Marka JJDevHub | `` `/${locale}` `` | tak |
| Home | `` `/${locale}` `` | tak |
| CV | `` `/${locale}/cv` `` | nie |
| Kursy | `` `/${locale}/courses` `` | nie |
| Kompendium | `` `/${locale}/compendium` `` | nie |
| Notatki | `` `/${locale}/notes` `` | nie |

`end` na marce i home sprawia, że przy `/pl/courses` aktywny jest link kursów. `NavLink` sam stawia `aria-current="page"` na bieżącej pozycji. Wygląd tego stanu jest w [tailwind/05-stany.md](../tailwind/05-stany.md). Każdy `NavLink` belki ma `viewTransition`.

Przycisk języka jest aktywny, gdy `locale` równa się jego kodowi. Na `/login` aktywne zostaje PL, a klik EN adresu nie zmienia, bo `pathForLocale` zwraca `null`.

Szkielet powłoki, bez klas układu:

```tsx
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
        <button type="button" onClick={showPolish}>
          {nav.languagePl}
        </button>
        <button type="button" onClick={showEnglish}>
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
```

Login i register nie mają pozycji w tym `nav`. Wchodzi się na nie adresem albo linkiem z formularza: z logowania `Link` na `/register`, z rejestracji `Link` na `/login`.

Znaczniki `header`, `nav`, `main` i jeden `h1` na stronie dopina [html/01-semantyka.md](../html/01-semantyka.md).

### 6. Szczegół po slug

Strona szczegółu czyta `slug` z `useParams` i język z `localeFromPathname(pathname)`. Brak rekordu w bundlu dla tej pary zastępuje adres listą tej samej sekcji i tego samego języka:

| Strona | Brak rekordu |
| --- | --- |
| `CourseDetailPage` | `` `/${locale}/courses` `` |
| `CompendiumDetailPage` | `` `/${locale}/compendium` `` |
| `NoteDetailPage` | `` `/${locale}/notes` `` |

```tsx
const { slug = '' } = useParams();
const { pathname } = useLocation();
const locale = localeFromPathname(pathname);
const course = courseBySlug(slug, locale);

if (!course) {
  return <Navigate to={`/${locale}/courses`} replace />;
}
```

Lista linkuje do szczegółu z tym samym prefiksem, na przykład `` `/${locale}/courses/${course.slug}` ``, z `viewTransition` na `Link`. Skąd bierze się rekord, opisuje [03-tresc-i-auth.md](03-tresc-i-auth.md).

### 7. Gość na loginie i rejestracji

`GuestRoute` czyta `isAuthenticated` z auth. Gość widzi dzieci. Zalogowany dostaje `<Navigate to="/" replace />`. Trasa `/` od razu zamienia to na `/pl`, więc zalogowany użytkownik otwierający `/login` albo `/register` ląduje na polskim home.

Po udanym submit logowanie i rejestracja wołają:

```tsx
void navigate('/', { viewTransition: true });
```

Ten sam łańcuch kończy się na `/pl`. Fetch formularza jest w [03-tresc-i-auth.md](03-tresc-i-auth.md).

Z `/login` linki belki wskazują polskie ścieżki (`/pl`, `/pl/cv`, …), bo locale z tej ścieżki wypada jako `pl`.

### 8. Odczyt w przeglądarce

Szczegóły portu 4200 i proxy `/api` są w [vite/01-dev.md](../vite/01-dev.md). Samo drzewo tras widać po starcie klienta:

```bash
cd src/Clients/web
pnpm start
```

Potem, na `http://localhost:4200`:

1. Otwórz `/`. Pasek adresu przechodzi na `/pl`, w `main` jest home, belka zostaje.
2. Otwórz `/en/cv`. `document.documentElement.lang` to `en`. `aria-current="page"` siedzi na linku CV.
3. Kliknij przełącznik PL. Adres to `/pl/cv`.
4. Wejdź na `/en/notes/przykladowy-slug?q=1#sekcja` (slug musi istnieć w bundlu). Przełącznik PL daje `/pl/notes/przykladowy-slug?q=1#sekcja`.
5. Otwórz `/de` i dowolną ścieżkę spoza mapy, na przykład `/pl/nie-ma`. Obie kończą się na `/pl`.
6. Otwórz `/login`. Klik EN zostawia `/login`. Klik „Kursy” idzie na `/pl/courses`.
7. Otwórz `/en/courses/slug-bez-rekordu`. Adres wraca na `/en/courses`.

Testy tego zachowania owijają `App` w `MemoryRouter`. Scenariusze pisze [04-testy.md](04-testy.md).

## Przypadki użycia

### Wejście na korzeń

Użytkownik wpisuje host bez ścieżki. Trasa `/` robi `replace` na `/pl`. Historia ma jeden wpis, polski home. Odświeżenie zostaje na `/pl`.

### Angielskie CV z belki

Użytkownik jest na `/en`. Klika CV. `NavLink` prowadzi na `/en/cv`. `LangGate` widzi `en` i puszcza `CvPage` przez `Outlet`. Przycisk EN w grupie języka jest aktywny. `document.documentElement.lang` to `en`.

### Kurs po slug

Z `/pl/courses` karta prowadzi na `/pl/courses/identyfikator`. `CourseDetailPage` znajduje rekord i rysuje artykuł. Link wstecz wraca na `/pl/courses`. Przełącznik EN wymienia tylko pierwszy segment: `/en/courses/identyfikator`, razem z ewentualnym query i hashem.

### Slug bez rekordu

Adres ma kształt szczegółu, ale `courseBySlug` nic nie zwraca. Strona robi `replace` na `/pl/courses` albo `/en/courses`, zgodnie z prefiksem, który już był w URL. Na `/pl` ten przypadek nie spada.

### Zły język

`/de`, `/de/cv` i każdy inny kod w pierwszym segmencie łapie `/:lang`, a `LangGate` robi `replace` na `/pl`. Użytkownik widzi polski home.

### Adres spoza mapy

`/konto`, `/pl/courses/a/b` i literówka sekcji nie pasują do żadnego dziecka. Trasa `*` robi `replace` na `/pl`.

### Przełącznik na notatce

Na `/en/notes/architektura?q=1#sekcja` klik PL woła `pathForLocale` i `navigate` na `/pl/notes/architektura?q=1#sekcja`. Wstecz wraca na angielski adres, bo to zwykły wpis historii.

### Przełącznik na loginie

Na `/login` pierwszy segment jest na liście nielokalizowanej. `pathForLocale` zwraca `null`, `navigate` się nie wykonuje, zostaje `LoginPage`. Etykiety belki są po polsku, bo `localeFromPathname('/login')` to `pl`. Link z formularza na `/register` też jest bez prefiksu.

### Zalogowany otwiera login

`GuestRoute` widzi sesję i robi `replace` na `/`. Stamtąd drugi `replace` prowadzi na `/pl`. Gość na tym samym URL widzi formularz.

### Po udanym logowaniu albo rejestracji

Submit kończy się `navigate('/')`. Korzeń zamienia adres na `/pl`. Miejsce lądowania jest polskim home także wtedy, gdy wcześniej użytkownik czytał `/en/...`, bo `/login` nie niesie segmentu języka.

### Z logowania w głąb serwisu

Klik „Notatki” na `/login` idzie na `/pl/notes`. Dalej działa zwykła mapa `/:lang`.

## Zasady wyglądu

Belka jest jedna dla całej mapy: header z marką, `nav`, grupa dwóch przycisków języka, `main` na dopasowaną stronę, stopka z nazwą JJDevHub. Zmiana trasy wymienia dzieci `main`. Header zostaje.

Login i register siedzą w tym samym `main` i w tej samej belce co home oraz CV.

Home i marka używają `end`. Na podstronie aktywna jest jedna pozycja sekcji. Aktywny przycisk języka odpowiada `locale` z pierwszego segmentu; na `/login` i `/register` jest to PL.

Płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3` i krój Inter biorą się z [tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Kontrakt liczb jest w [motyw.md](../motyw.md). Belka ma duży oddech i mało ramek: pozycje nawigacji stoją w jednym rzędzie, bez ramki na każdą z nich. Odstęp, szerokość i siatka są w [tailwind/03-uklad.md](../tailwind/03-uklad.md).

Ciemny hero jest treścią `HomePage` wewnątrz `main`. Belka na home i na `/pl/cv` jest ta sama.

## Poza zakresem

- Skład komponentu i wczesny return: [01-komponenty.md](01-komponenty.md).
- JSON w bundlu, `cv.local.json` i `fetch` przy auth: [03-tresc-i-auth.md](03-tresc-i-auth.md).
- Aserje `MemoryRouter`, przełącznik i błąd logowania w teście: [04-testy.md](04-testy.md).
- Port 4200 i proxy API: [vite/01-dev.md](../vite/01-dev.md).
- Katalog znaczników HTML: [html/01-semantyka.md](../html/01-semantyka.md).
- Klasy odstępu belki: [tailwind/03-uklad.md](../tailwind/03-uklad.md).
- Wygląd aktywnego linku: [tailwind/05-stany.md](../tailwind/05-stany.md).
- Animacja zmiany widoku: [motion/01-przejscia.md](../motion/01-przejscia.md).
- Ekrany telefonu: osobny klient, [nativewind/02-ekrany.md](../nativewind/02-ekrany.md). Tego `BrowserRouter` tam nie ma.
- Intranet dojdzie później w tym samym `App` i tym samym kliencie web. Tabeli jego tras ten plik nie zawiera.

## Gotowe gdy

- [main.tsx](../../../src/Clients/web/src/main.tsx) ma `AuthProvider`, a w nim `BrowserRouter` i `App`. Import routera pochodzi z `react-router`.
- [App.tsx](../../../src/Clients/web/src/app/App.tsx) owija `<Routes>` w `Shell`.
- `/` i `*` robią `replace` na `/pl`.
- `/login` i `/register` są rodzeństwem `/:lang`, każde w `GuestRoute`.
- Dzieci `/:lang` to indeks (home), `cv`, `courses`, `courses/:slug`, `compendium`, `compendium/:slug`, `notes`, `notes/:slug`.
- `LangGate` renderuje `Outlet` tylko dla `pl` i `en`. Każdy inny `:lang` robi `replace` na `/pl`.
- `pathForLocale` wymienia pierwszy segment, dokleja `search` i `hash`, a dla `login` i `register` zwraca `null`.
- Shell buduje linki jako `` `/${locale}/…` ``, marka i home mają `end`, przełącznik woła `navigate` tylko gdy cel nie jest `null`.
- `document.documentElement.lang` śledzi locale ze ścieżki, z fallbackiem `pl`.
- Nieznany slug kursu, hasła albo notatki wraca `replace` na listę tej sekcji w tym samym języku.
- Zalogowany na `/login` albo `/register` oraz udany submit kończą na `/pl`.
- Wejście na `/`, `/en/cv`, zły język, `*` i klik języka na `/login` daje adresy z tabeli w tym pliku.
