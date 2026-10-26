# Testy

Specyfikacja testów klienta web. Generator kodu dopisuje pliki `*.spec.ts` i `*.spec.tsx` obok komponentu i uruchamia je z `src/Clients/web`. Kod produkcyjny i konfiguracja Vitesta zostają takie, jakie są w repo: ten plik mówi, co nowy test ma sprawdzić.

Test czyta ekran tak, jak czyta go użytkownik: rola, dostępna nazwa, widoczny tekst, język dokumentu. Łańcuch webu (React składa HTML5, Vite podaje jeden CSS, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML) jest w teście tylko tłem renderu. Wygląd liczb, klas i ruchu opisują [motyw.md](../motyw.md), katalog `tailwind/` i katalog `motion/`.

Sąsiedzi: [01-komponenty.md](01-komponenty.md) (kształt komponentu, wczesny return na pustą kolekcję), [02-trasy.md](02-trasy.md) (drzewo tras i przełącznik języka), [03-tresc-i-auth.md](03-tresc-i-auth.md) (JSON w bundlu, `fetch` przy logowaniu).

## Po co

Jeden przebieg ma złapać trzy usterki, które widać bez zaglądania w styl:

- lista kursów bez elementów zostawia użytkownika z nagłówkiem sekcji i jednym zdaniem, że listy nie ma;
- złe hasło zostawia użytkownika na formularzu logowania ze zdaniem o błędzie;
- przycisk języka podmienia pierwszy segment treści albo zostawia `/login` i `/register` bez prefiksu.

Bramka w CI to `pnpm test:ci` w katalogu klienta. Lokalnie ten sam zestaw odpala się w trybie podglądu przez `pnpm test`.

## Wersje i pakiety

Menedżer: **pnpm** `10.33.0` (`packageManager` w `src/Clients/web/package.json`). Komendy odpalasz w `src/Clients/web`.

| Pakiet | Wersja w repo | Rola w teście |
| --- | --- | --- |
| `vitest` | `^4.0.8` | runner, `describe`, `it`, `expect`, `vi` |
| `@testing-library/react` | `^16.3.0` | `render`, `screen`, `cleanup`, `fireEvent` |
| `jsdom` | `^28.0.0` | DOM bez przeglądarki |
| `react`, `react-dom` | `19.2.3` | render komponentu |
| `react-router` | `^7.9.4` | `MemoryRouter` w teście, `BrowserRouter` w aplikacji |
| `vite` | `^7.1.9` | ten sam `defineConfig`, który niesie blok `test` |
| `typescript` | `~5.9.2` | typy, w tym `vitest/globals` |

W `devDependencies` jest Testing Library dla Reacta. Pakietów `@testing-library/user-event` i `@testing-library/jest-dom` w tym kliencie nie ma. Zapytania idą przez `screen.getByRole`, `getByLabelText`, `getByText`, `findByText` i `queryByRole`. Asercje idą przez `expect` z Vitesta (`toBe`, `toBeTruthy`, `toContain`, `toBeNull`).

Konfiguracja siedzi w bloku `test` w `src/Clients/web/vite.config.ts`. Osobnego `vitest.config.ts` nie dodajesz. `defineConfig` pochodzi z `vitest/config`.

```ts
test: {
  environment: 'jsdom',
  globals: true,
  setupFiles: './src/test-setup.ts',
},
```

`globals: true` wystawia `describe`, `it`, `expect` i `vi` globalnie. `src/Clients/web/tsconfig.json` ma `"types": ["vite/client", "vitest/globals"]`. Pliki spec i tak importują te nazwy z `vitest`, tak jak `App.spec.tsx`, żeby plik czytał się bez zgadywania, co jest globalne.

Skrypty w `package.json`:

| Skrypt | Co woła | Kiedy |
| --- | --- | --- |
| `pretest` | `node scripts/copy-cv.mjs` | sam, przed `pnpm test` |
| `test` | `vitest` | lokalnie, tryb podglądu, proces zostaje |
| `pretest:ci` | `node scripts/copy-cv.mjs` | sam, przed `pnpm test:ci` |
| `test:ci` | `vitest run` | CI i lokalna bramka, proces kończy się kodem wyjścia |

pnpm sam odpala skrypt `pre*` przed skryptem właściwym. `vitest` wpisany ręcznie, z pominięciem `pnpm test`, kopii CV nie zrobi.

## Ścieżki w repo

| Ścieżka | Rola |
| --- | --- |
| `src/Clients/web/package.json` | skrypty `test` i `test:ci` oraz hooki `pretest` / `pretest:ci` |
| `src/Clients/web/vite.config.ts` | blok `test`: jsdom, globals, plik setup |
| `src/Clients/web/src/test-setup.ts` | `localStorage` w pamięci i `window.matchMedia` |
| `src/Clients/web/src/app/App.spec.tsx` | wzorzec renderu całej aplikacji |
| `src/Clients/web/src/app/App.tsx` | drzewo tras wkładane do `MemoryRouter` |
| `src/Clients/web/src/app/auth/auth.tsx` | `AuthProvider`, `fetch` na `/api/auth/login` i `/api/auth/register` |
| `src/Clients/web/src/app/pages/login/AuthForm.tsx` | formularz, akapit błędu, przycisk wysyłki |
| `src/Clients/web/src/app/Shell.tsx` | przyciski `PL` i `EN`, `document.documentElement.lang` |
| `src/Clients/web/src/app/pages/home/HomeCourses.tsx` | lista kursów na home, prop `courses` |
| `src/Clients/web/src/app/pages/courses/CoursesPage.tsx` | lista kursów pod `/:lang/courses` |
| `src/Clients/web/src/content/pl.json` | widoczne polskie napisy, w tym nav i wykłady |
| `src/Clients/web/src/content/en.json` | widoczne angielskie napisy |
| `src/Clients/web/scripts/copy-cv.mjs` | `cv.local.json` albo `cv.example.json` → `cv.json` |
| `src/Clients/web/src/content/cv.json` | plik wygenerowany, importowany przez `content.ts`, poza gitem |
| `.github/workflows/web.yml` | krok Test w jobie `web` oraz test przed skanem Sonar, oba: `pnpm test:ci` przy `working-directory: src/Clients/web`, Node 22 |

Nowy spec leży obok komponentu. Nazwa pliku powtarza nazwę komponentu i kończy się na `.spec.tsx` (albo `.spec.ts`, gdy plik nie renderuje JSX). Vitest zbiera `*.spec.*` i `*.test.*` z katalogu pakietu. Drugiego katalogu `__tests__` nie zakładasz.

`src/test-setup.ts` podstawia `localStorage` na mapę w pamięci (`getItem`, `setItem`, `removeItem`, `clear`) i `window.matchMedia`. Stub `matchMedia` zwraca `matches: true`, gdy zapytanie zawiera `prefers-reduced-motion`. Testy z tego pliku tego stubu nie ruszają i nie asertyują ruchu.

Każdy spec, który importuje `App` albo moduł treści, ciągnie `src/Clients/web/src/app/content/content.ts`, a ten plik importuje `../../content/cv.json`. Brak `cv.json` wywala zbiór przy ładowaniu modułu, zanim pierwszy `it` wystartuje. Dlatego bramka idzie przez skrypty pnpm, które najpierw kopiują CV.

## Tutorial

### Uruchomienie

Z katalogu repozytorium:

```bash
pnpm --dir src/Clients/web test
```

Proces zostaje i przelicza specy po zapisie. Zatrzymanie: Ctrl+C.

Jednorazowa bramka, ta sama co w `.github/workflows/web.yml`:

```bash
pnpm --dir src/Clients/web test:ci
```

Oczekiwany ślad kopii, zanim Vitest wypisze pliki:

```text
Copied cv.example.json → cv.json
```

Gdy w `src/Clients/web/src/content/` leży `cv.local.json`, skrypt kopiuje ten plik i wypisuje `Copied cv.local.json → cv.json`. Oba źródła opisuje [03-tresc-i-auth.md](03-tresc-i-auth.md). `cv.json` zostaje poza gitem.

Pojedynczy plik, nadal z kopią CV:

```bash
pnpm --dir src/Clients/web test:ci src/app/App.spec.tsx
```

### Render aplikacji

Wzorzec z `src/Clients/web/src/app/App.spec.tsx`. Test układa drzewo tak, jak użytkownik wchodzi na adres: `AuthProvider`, potem `MemoryRouter` z `initialEntries`, w środku `App`. `MemoryRouter` trzyma historię w pamięci. Adresu przeglądarki test nie potrzebuje.

Po każdym teście sprzątasz DOM, język dokumentu i magazyn. `Shell` wpisuje locale do `document.documentElement.lang`. Token sesji siedzi w `localStorage` pod kluczem `jjdevhub.token`. Zostawienie jednego albo drugiego psuje kolejny przypadek.

```tsx
import { cleanup, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it } from 'vitest';

import { App } from './App';
import { AuthProvider } from './auth/auth';

afterEach(() => {
  cleanup();
  document.documentElement.lang = 'pl';
  localStorage.clear();
});

function renderAt(path: string) {
  return render(
    <AuthProvider>
      <MemoryRouter initialEntries={[path]}>
        <App />
      </MemoryRouter>
    </AuthProvider>,
  );
}

describe('App', () => {
  it('renders the brand', async () => {
    renderAt('/pl');
    expect(screen.getByRole('link', { name: 'JJDevHub' }).textContent).toContain('JJDevHub');
  });
});
```

`getByRole('link', { name: 'JJDevHub' })` szuka linku marki w shellu. `name` to dostępna nazwa (treść linku), którą czyta też czytnik ekranu. `getBy*` rzuca, gdy elementu nie ma: test pada w tym samym miejscu, w którym użytkownik nic by nie zobaczył.

Zapytania, których używasz:

| Zapytanie | Kiedy |
| --- | --- |
| `getByRole` | link, przycisk, nagłówek, grupa języka, pole po roli |
| `getByLabelText` | pole spięte z `<label>` (Email, Password) |
| `getByText` / `findByText` | zdanie błędu albo pustej listy; `findBy*` czeka na stan po `async` |
| `queryByRole` | elementu ma nie być; wynik `null` jest oczekiwany |

Kolejność szukania: rola i dostępna nazwa, potem etykieta pola, na końcu surowy tekst zdania. Po tekście klasy CSS nie sięgasz.

### Pusta lista, błąd, język

Trzy przypadki poniżej są obowiązkowe. Każdy ma własny `it`. Wspólny `renderAt` zostaje w specu aplikacji. Lista kursów, która dostaje tablicę propsem, może mieć krótszy render bez całego `App`, byle użytkownik widział ten sam nagłówek i to samo zdanie.

## Przypadki użycia

### Pusta lista

Użytkownik otwiera wykłady i nie ma ani jednej karty. Widzi nagłówek sekcji i jedno zdanie. Kart z tytułami z bundla nie ma.

Zdanie jest polem locale, tym samym, które renderuje widok:

| Locale | Pole | Tekst na ekranie |
| --- | --- | --- |
| `pl` | `courses.empty` w `pl.json` | `Brak wykładów.` |
| `en` | `courses.empty` w `en.json` | `No courses yet.` |

`pl.json` i `en.json` zostają z prawdziwymi sylabusami (`Aplikacje mobilne`, `Mobile applications`). Pusty przypadek budujesz tablicą `[]` w teście. Skasowanie `items` w pliku treści psuje pozostałe ekrany i ten test.

`HomeCourses` przyjmuje `courses`. To właściwy szew: komponent, który rysuje karty, dostaje pustą tablicę i pokazuje zdanie. `CoursesPage` pod `/pl/courses` i `/en/courses` trzyma ten sam kontrakt widoku: `h1` z `courses.title` (`Wykłady` / `Courses`), to samo zdanie `courses.empty`, zero linków do kart. Notatki i kompendium, gdy ich kolekcja jest pusta, powtarzają ten układ: nagłówek sekcji zostaje, jedno zdanie z pola locale tej sekcji, brak linków pozycji.

Plik: `src/Clients/web/src/app/pages/home/HomeCourses.spec.tsx`.

```tsx
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { describe, expect, it } from 'vitest';

import pl from '../../../content/pl.json';
import { HomeCourses } from './HomeCourses';

describe('HomeCourses', () => {
  it('shows a sentence when there are no courses', () => {
    render(
      <MemoryRouter>
        <HomeCourses locale="pl" home={pl.home} courses={[]} />
      </MemoryRouter>,
    );

    expect(screen.getByRole('heading', { name: 'Wykłady' })).toBeTruthy();
    expect(screen.getByText('Brak wykładów.')).toBeTruthy();
    expect(screen.queryByRole('link', { name: 'Aplikacje mobilne' })).toBeNull();
  });
});
```

Angielski odpowiednik podaje `locale="en"`, `home` z `en.json`, nagłówek `Courses`, zdanie `No courses yet.` i `queryByRole('link', { name: 'Mobile applications' })` równe `null`.

Wczesny `return` na pustą kolekcję jest regułą komponentu z [01-komponenty.md](01-komponenty.md). Test pustej listy wykładów wymaga zdania na ekranie. Sam `return null` zostawia użytkownika bez informacji i ten `it` pada na `getByText`.

Asercja dotyczy nagłówka, zdania i braku linku karty. Siatka, klasa kafelka i odstęp zostają w plikach Tailwinda.

### Błąd logowania

Użytkownik jest na `/login`, wpisuje email i hasło, wysyła formularz, a API odpowiada `401`. Zostaje na formularzu. Nad przyciskiem widzi zdanie `Invalid email or password.` Przycisk z powrotem nazywa się `Log in` (w trakcie żądania podpis brzmi `Signing in…`).

Hasło w polu ma co najmniej 8 znaków (`minLength` na inpucie). Krótsze hasło zatrzymuje wysyłkę na walidacji pola w jsdom i akapit błędu API się nie pojawi. Email ma kształt adresu, bo pole jest `type="email"`.

`fetch` w teście jest podstawiony. Serwer na `localhost:5080` i proxy Vite do tego przypadku nie wchodzą. Stub odpowiada `401` wyłącznie na `/api/auth/login`. Inny adres dostaje `500`, a użytkownik widziałby wtedy `Request failed.` — oczekiwane zdanie `401` wtedy nie przejdzie.

`AuthForm` trzyma błąd w akapicie pod polami. `login` w `AuthProvider` jest asynchroniczny, więc asercja używa `findByText`. Po teście zdejmujesz stub globalnego `fetch` (`vi.unstubAllGlobals`), przywracasz mocki (`vi.restoreAllMocks`) i czyścisz DOM, język oraz `localStorage`.

Dopisz do `App.spec.tsx` (albo do speca obok `LoginPage`, z tym samym `AuthProvider` i `MemoryRouter`):

```tsx
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { App } from './App';
import { AuthProvider } from './auth/auth';

afterEach(() => {
  cleanup();
  document.documentElement.lang = 'pl';
  localStorage.clear();
  vi.unstubAllGlobals();
  vi.restoreAllMocks();
});

function renderAt(path: string) {
  return render(
    <AuthProvider>
      <MemoryRouter initialEntries={[path]}>
        <App />
      </MemoryRouter>
    </AuthProvider>,
  );
}

function formOf(control: HTMLElement): HTMLFormElement {
  const form = control.closest('form');
  if (!(form instanceof HTMLFormElement)) {
    throw new Error('Login form is missing');
  }
  return form;
}

describe('App', () => {
  it('shows a login error when the password is rejected', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn(async (input: RequestInfo | URL) => {
        const url = String(input);
        if (url === '/api/auth/login') {
          return new Response(JSON.stringify({ message: 'Unauthorized' }), {
            status: 401,
            headers: { 'Content-Type': 'application/json' },
          });
        }
        return new Response(JSON.stringify({ message: 'Request failed.' }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }),
    );

    renderAt('/login');
    fireEvent.change(screen.getByLabelText('Email'), {
      target: { value: 'a@b.co' },
    });
    fireEvent.change(screen.getByLabelText('Password'), {
      target: { value: 'haslo123' },
    });
    fireEvent.submit(formOf(screen.getByLabelText('Email')));

    expect(await screen.findByText('Invalid email or password.')).toBeTruthy();
    expect(screen.getByRole('heading', { name: 'Log in' })).toBeTruthy();
    expect(screen.getByRole('button', { name: 'Log in' })).toBeTruthy();
  });
});
```

Mapowanie statusu na zdanie siedzi w `describeApiError` (`401` → `Invalid email or password.`). Spec pomocniczy tej funkcji może zostać. Przypadek z tego rozdziału i tak renderuje formularz: użytkownik czyta akapit, a sam wynik funkcji tego nie zastępuje.

Rejestracja używa tego samego `AuthForm` i tego samego kształtu błędu na `/register`. Osobnego scenariusza tu nie rozpisujesz, dopóki zdanie na logowaniu jest pokryte.

### Przełącznik języka

Dwa przejścia. Oba są w specu aplikacji, bo biorą shell, nav i trasę naraz.

Treść. Wejście na `/pl/courses`. Użytkownik widzi nagłówek `Wykłady`, grupę o nazwie `Język` i przyciski `PL` oraz `EN` (napisy z `nav.language`, `nav.languagePl`, `nav.languageEn`). Klik `EN` podmienia pierwszy segment. Widać nagłówek `Courses`, grupę `Language`, a link nawigacji do wykładów ma `href` `/en/courses`. `document.documentElement.lang` jest `en`.

Logowanie i rejestracja są poza prefiksem języka (`login` i `register` w zbiorze ścieżek bez locale). Wejście na `/login`, klik `EN`: nagłówek zostaje `Log in`, ścieżka zostaje `/login`, shell dalej liczy locale jako `pl` (pierwszy segment to `login`), grupa języka zostaje `Język`. To samo dla `/register` i przycisku `PL` na `/en/register`.

Przycisk klikasz tak, jak w obecnym `App.spec.tsx`: `screen.getByRole('button', { name: 'EN' }).click()`. Aktywny język rozpoznajesz po treści strony i po `lang` na dokumencie. Klasa na przycisku do tego nie służy.

```tsx
it('switches the courses page to English', async () => {
  renderAt('/pl/courses');

  expect(screen.getByRole('heading', { name: 'Wykłady' })).toBeTruthy();
  expect(screen.getByRole('group', { name: 'Język' })).toBeTruthy();

  screen.getByRole('button', { name: 'EN' }).click();

  expect(screen.getByRole('heading', { name: 'Courses' })).toBeTruthy();
  expect(screen.getByRole('group', { name: 'Language' })).toBeTruthy();
  expect(screen.getByRole('link', { name: 'Courses' }).getAttribute('href')).toBe('/en/courses');
  expect(document.documentElement.lang).toBe('en');
});

it('keeps login unlocalized when switching language', async () => {
  renderAt('/login');

  screen.getByRole('button', { name: 'EN' }).click();

  expect(screen.getByRole('heading', { name: 'Log in' })).toBeTruthy();
  expect(screen.getByRole('group', { name: 'Język' })).toBeTruthy();
  expect(document.documentElement.lang).toBe('pl');
});
```

`getByRole('link', { name: 'Courses' })` trafia w link nawigacji. Karty kursów mają w nazwie tytuł wykładu, więc nazwa `Courses` zostaje przy navie. Nagłówek strony jest rolą `heading`, więc z linkiem się nie zlewa.

Po tym bloku `afterEach` wraca `document.documentElement.lang` na `pl`.

## Zasady wyglądu

Test pilnuje tego, co da się przeczytać i wskazać rolą.

- Marka `JJDevHub` jest linkiem.
- Pusta lista wykładów ma nagłówek sekcji i zdanie `Brak wykładów.` albo `No courses yet.`
- Błąd logowania przy `401` ma zdanie `Invalid email or password.` i z powrotem przycisk `Log in`.
- Przełącznik ma przyciski `PL` i `EN`. Po zmianie języka na stronie treści zmienia się nagłówek, nazwa grupy (`Język` / `Language`), `href` linku nav i `document.documentElement.lang`.
- Login i register zostają przy swoich nagłówkach (`Log in` i odpowiednik rejestracji) po kliknięciu drugiego języka.

Paleta `#f5f5f7`, `#1d1d1f`, `#0071e3`, krój Inter, oddech, obramowanie i ciemny hero są kontraktem [motyw.md](../motyw.md). Test ich nie powtarza. Klasa na znaczniku, stan hover, focus i pusto jako styl są w katalogu `tailwind/`. Ruch i `prefers-reduced-motion` są w katalogu `motion/`. Tutaj pusto i błąd istnieją jako tekst i rola, zgodnie z semantyką z [html/01-semantyka.md](../html/01-semantyka.md).

## Poza zakresem

- Asercje klasy, `className`, `style`, koloru wyliczonego, zrzutu drzewa z klasami i „czy Tailwind nadał właściwy utility”.
- Osobny runner przeglądarkowy, Playwright, testy wizualne.
- Telefon, NativeWind, Reanimated.
- Prawdziwe API, proxy z `vite.config.ts`, intranet.
- Tamagui.
- Implementacja GSAP, Lenisa i biblioteki Motion. Stub `matchMedia` w `test-setup.ts` zostaje jak jest.
- Zmiana `vite.config.ts`, `package.json` i skryptu kopiowania CV. Nowe zależności testowe dokładaj tylko wtedy, gdy ten plik zostanie świadomie rozszerzony.

## Gotowe gdy

- `pnpm --dir src/Clients/web test:ci` kończy się kodem 0, a przed Vitestem widać linię `Copied cv.example.json → cv.json` albo `Copied cv.local.json → cv.json`.
- `App.spec.tsx` dalej renderuje markę `JJDevHub` przez `getByRole('link', …)` oraz trzyma wspólne `afterEach` (`cleanup`, `lang` z powrotem na `pl`, `localStorage.clear()`).
- Jest test pustej listy: nagłówek `Wykłady`, tekst `Brak wykładów.`, brak linku `Aplikacje mobilne`, a `items` w `pl.json` zostają na miejscu. Angielski wariant sprawdza `Courses`, `No courses yet.` i brak `Mobile applications`.
- Jest test logowania: stub `fetch` zwraca `401` dla `/api/auth/login`, a ekran pokazuje `Invalid email or password.` i przycisk `Log in`.
- Jest test przełącznika: z `/pl/courses` klik `EN` daje nagłówek `Courses`, `href` `/en/courses` i `document.documentElement.lang === 'en'`. Z `/login` klik `EN` zostawia nagłówek `Log in` i język dokumentu `pl`.
- Żaden z tych testów nie czyta klasy CSS, koloru ani snapshotu stylu.
- Krok Test w `.github/workflows/web.yml` zostaje przy `pnpm test:ci` w `src/Clients/web`.
