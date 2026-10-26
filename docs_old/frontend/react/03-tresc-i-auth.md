# Treść i auth

Strony JJDevHub biorą tekst z JSON włożonego do bundla. Login i register wołają API zwykłym `fetch` i zapisują token. Ten plik jest specyfikacją tego podziału: kształt plików, skrypt lokalnego CV, odczyt w komponencie i kontrakt żądania auth.

Łańcuch webu: React składa HTML5, Vite podaje jeden `src/styles.css`, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Tu jest źródło danych. Znaczniki opisuje [html/01-semantyka.md](../html/01-semantyka.md), klasy układu [tailwind/03-uklad.md](../tailwind/03-uklad.md), mapę URL [02-trasy.md](02-trasy.md).

## Po co

Treść dydaktyczna (nawigacja, home, wykłady, kompendium, notatki) i CV są znane w chwili buildu. Strona czyta je synchronicznie z modułu. Dzięki temu `/pl/courses` i `/en/notes/dlaczego-cqrs` renderują się z bundla, a przeglądarka nie prosi API o copy.

Konto jest odwrotnie: hasło idzie na serwer, w odpowiedzi wraca JWT. Jedyne wołanie `fetch` w kliencie webu to `POST /api/auth/login` i `POST /api/auth/register`.

Intranet, gdy treść kiedyś przeniesie się do API, zostaje w tym samym kliencie i tym samym wzorcu `fetch`. Ten plik go nie wdraża.

## Wersje i pakiety

Klient: [src/Clients/web/package.json](../../../src/Clients/web/package.json).

| Składnik | Wersja w repo | Rola tutaj |
| --- | --- | --- |
| React | 19.2.3 | komponent strony czyta moduł treści albo `useAuth` |
| react-router | ^7.9.4 | `useLocation`, `useParams`, `useNavigate`, `Link` |
| Vite | ^7.1.9 | składa import JSON do bundla; w dev proxy’uje `/api` |
| TypeScript | ~5.9.2 | `resolveJsonModule` |
| pnpm | 10.33.0 | hooki `prestart`, `prebuild`, `pretest`, `pretest:ci` |

Osobnej biblioteki i18n, klienta HTTP ani CMS-a nie ma. `fetch` jest w przeglądarce. Skrypt CV używa `node:fs` i `node:path`.

`resolveJsonModule` jest włączone w [src/Clients/web/tsconfig.json](../../../src/Clients/web/tsconfig.json). Import `*.json` jest modułem ES, nie żądaniem w runtime.

## Ścieżki w repo

| Ścieżka | W gicie | Rola |
| --- | --- | --- |
| [src/Clients/web/src/content/pl.json](../../../src/Clients/web/src/content/pl.json) | tak | copy stron dla `pl` |
| [src/Clients/web/src/content/en.json](../../../src/Clients/web/src/content/en.json) | tak | copy stron dla `en`, te same klucze i te same slugi |
| [src/Clients/web/src/content/cv.example.json](../../../src/Clients/web/src/content/cv.example.json) | tak | placeholdery CV (`Imię Nazwisko`, `you@example.com`) |
| `src/Clients/web/src/content/cv.local.json` | nie | prawdziwe CV na maszynie i w kontekście obrazu |
| `src/Clients/web/src/content/cv.json` | nie | plik, który importuje aplikacja; wynik skryptu |
| [src/Clients/web/scripts/copy-cv.mjs](../../../src/Clients/web/scripts/copy-cv.mjs) | tak | kopiuje local albo example do `cv.json` |
| [src/Clients/web/src/app/content/content.model.ts](../../../src/Clients/web/src/app/content/content.model.ts) | tak | typy |
| [src/Clients/web/src/app/content/content.ts](../../../src/Clients/web/src/app/content/content.ts) | tak | import, guardy, lookup |
| [src/Clients/web/src/app/auth/auth.tsx](../../../src/Clients/web/src/app/auth/auth.tsx) | tak | `fetch`, token, `AuthProvider` |
| [src/Clients/web/src/app/auth/api-error.ts](../../../src/Clients/web/src/app/auth/api-error.ts) | tak | odczyt błędu i pola `token` |
| [src/Clients/web/src/main.tsx](../../../src/Clients/web/src/main.tsx) | tak | `AuthProvider` wokół `BrowserRouter` |
| [src/Clients/web/nginx.conf](../../../src/Clients/web/nginx.conf) | tak | w obrazie `location /api/` na API |

Ignore: [`.gitignore`](../../../.gitignore) wyklucza `src/Clients/web/src/content/cv.local.json` i `src/Clients/web/src/content/cv.json`.

Kontekst Dockera to `src/Clients` ([src/Clients/web/Dockerfile](../../../src/Clients/web/Dockerfile)). [src/Clients/.dockerignore](../../../src/Clients/.dockerignore) ma negację `!web/src/content/cv.local.json`, żeby lokalne CV mogło wejść do buildu, gdy plik leży na dysku. `pnpm build` i tak odpala `prebuild`.

## Tutorial

### 1. Dwa pliki stron i jeden plik CV

[content.ts](../../../src/Clients/web/src/app/content/content.ts) wciąga trzy moduły na poziomie pliku:

```ts
import en from '../../content/en.json';
import pl from '../../content/pl.json';
import cvFile from '../../content/cv.json';
```

`pl.json` i `en.json` mają kształt `SiteContent`: `nav`, `home`, `courses`, `compendium`, `notes`. Danych osobowych tam nie ma.

`cv.json` ma kształt `CvFile`: jeden obiekt z kluczami `pl` i `en`. Każdy klucz to `CvLocaleContent`.

Vite wkłada te moduły w bundle przy `vite` i przy `vite build`. Wejście na `/pl/courses` nie wysyła `GET` po `pl.json`. Brak `cv.json` na dysku wywala import całego grafu, także `/login`, bo shell i strony ciągną ten sam moduł.

Język bierze się z pierwszego segmentu URL (`localeFromPathname`). Dozwolone wartości to `pl` i `en`. Inny segment funkcji nie zdarza się na trasie z [02-trasy.md](02-trasy.md): zły język ląduje na `/pl`.

Slug kursu, hasła i notatki jest ten sam w `pl.json` i `en.json`. Przełącznik języka podmienia pierwszy segment i zostawia resztę ścieżki. Rozjazd slugów sprawia, że `/en/courses/mobile` nie znajdzie wpisu, który jest tylko po polsku.

### 2. Kontrakt pól

Guardy w `content.ts` sprawdzają kształt w runtime. Brak wymaganego pola przerywa ewaluację modułu, zanim pierwsza strona się narysuje.

`pl.json` / `en.json`:

| Miejsce | Wymagane stringi | Tablice i pola opcjonalne |
| --- | --- | --- |
| `nav` | `home`, `cv`, `courses`, `compendium`, `notes`, `language`, `languagePl`, `languageEn` | — |
| `home` | `eyebrow`, `ctaCv`, `ctaCourses`, `currentTitle`, `currentLead`, `coursesTitle`, `coursesLead`, `notesTitle`, `notesLead`, `viewAll` | — |
| `courses` | `title`, `lead`, `backLabel` | `items`: `CourseContent[]` |
| kurs | `slug`, `title`, `subtitle`, `repoUrl`, `repoLabel` | `summary: string[]`; opcjonalnie `labUrl`, `labLabel`, `lessonsTitle`, `lessons`, `chaptersTitle`, `chapters`, `plannedTitle`, `plannedLead`, `planned` |
| lekcja | `slug`, `title`, `summary`, `url` | `url` to adres zewnętrzny (GitHub), nie trasa aplikacji |
| rozdział (`chapters` / `planned`) | `slug`, `title`, `summary` | — |
| `compendium` | `title`, `lead`, `backLabel`, `glossaryUrl`, `glossaryLabel` | `items`: hasła |
| hasło | `slug`, `term` | `definition: string[]` |
| `notes` | `title`, `lead`, `backLabel` | `items`: `NoteContent[]` |
| notatka | `slug`, `title`, `date`, `summary` | `body: string[]`; opcjonalnie `relatedLessonSlug`, `relatedCourseSlug` |

Pusta tablica przechodzi guarda (`every` na pustej liście jest prawdziwe). Pole opcjonalne może zniknąć. `null` w miejscu stringa guarda nie przechodzi.

`cv.json` (to samo w `cv.example.json` i `cv.local.json`):

| Miejsce | Wymagane | Opcjonalne |
| --- | --- | --- |
| korzeń | klucze `pl` i `en` | — |
| locale | `name`, `role`, `email`, `experienceTitle`, `educationTitle`, `extrasTitle` | — |
| locale | `experience`, `education`, `extras` — tablice wpisów | — |
| wpis | `title`, `period`, `paragraphs: string[]` | `company`, `institution` |

Komunikaty przy złym kształcie, dosłownie:

- `Site content is missing required fields.`
- `CV content is missing required fields.`

Nadmiarowe klucze guard puszcza. Nowy wymagany klucz na stronie oznacza trzy edycje naraz: typ w `content.model.ts`, warunek w guardzie, oba pliki `pl.json` i `en.json`.

### 3. Odczyt w stronie

Moduł trzyma już sprawdzone obiekty. Strona nie woła `fetch` i nie trzyma kopii w `useState`.

```ts
export function siteFor(locale: LocaleCode): SiteContent
export function cvFor(locale: LocaleCode): CvLocaleContent
export function courseBySlug(slug: string, locale: LocaleCode): CourseContent | undefined
export function compendiumBySlug(slug: string, locale: LocaleCode): CompendiumTerm | undefined
export function noteBySlug(slug: string, locale: LocaleCode): NoteContent | undefined
```

Locale z URL:

```ts
const { pathname } = useLocation();
const locale = localeFromPathname(pathname);
const section = siteFor(locale).courses;
```

`localeFromPathname` bierze pierwszy niepusty segment. Segment spoza `pl` / `en` daje `pl`.

Lookup po slug zwraca `undefined`, gdy wpisu nie ma. Strona szczegółu robi wtedy `<Navigate replace>` na listę tego samego języka:

- kurs → `/${locale}/courses`
- hasło → `/${locale}/compendium`
- notatka → `/${locale}/notes`

Kto czyta które pola:

| Ekran | Wywołanie |
| --- | --- |
| shell | `siteFor(locale).nav` — etykiety linków i przełącznika |
| home | `siteFor(locale)` oraz `cvFor(locale)`; hero bierze `name`, `role` i dwa pierwsze wpisy `experience`; notatki na home to `notes.items.slice(0, 3)` |
| CV | `cvFor(locale)` — trzy sekcje: doświadczenie (`company`), edukacja (`institution`), aktywność |
| lista i szczegół kursu | `courses` i `courseBySlug` |
| lista i szczegół kompendium | `compendium` i `compendiumBySlug`; `glossaryUrl` to link zewnętrzny |
| lista i szczegół notatki | `notes` i `noteBySlug` |

`pathForLocale` siedzi w tym samym module, bo zna zbiór ścieżek bez języka: `login` i `register`. Dla nich zwraca `null` — przełącznik języka na tych trasach nie przebudowuje URL. Zachowanie tras opisuje [02-trasy.md](02-trasy.md).

`key` listy to `slug` kursu, hasła albo notatki. Akapit w `summary`, `body`, `definition` albo `paragraphs` nie ma własnego id; kluczem jest tekst akapitu, a w jednym bloku teksty są unikalne. Wpis CV nie ma sluga: klucz to `` `${entry.title}|${entry.period}` ``.

Lekcja kursu renderuje się jako `<a href={lesson.url} target="_blank" rel="noopener noreferrer">`. To nie jest `Link` routera.

### 4. Nowy kurs albo notatka

1. Dopisz obiekt do `courses.items` albo `notes.items` w `pl.json` i w `en.json`. Ten sam `slug`.
2. Zostaw kształt z tabeli powyżej. Guard już go zna — nowej trasy w routerze nie potrzeba, bo szczegół jest pod `courses/:slug` i `notes/:slug`.
3. Odśwież dev server. `copy-cv.mjs` przy stronach `pl` / `en` nic nie robi.

Przykład wpisu, który lista kursów już umie pokazać (skrót; pełny sylabus zostaje w JSON):

```json
{
  "slug": "mobile",
  "title": "Aplikacje mobilne",
  "subtitle": "Studia zaoczne · React Native + .NET CQRS",
  "summary": ["Dwanaście lekcji od wstępu do React Native."],
  "repoUrl": "https://github.com/jtjaskulski/KursReactNativeCQRS",
  "repoLabel": "Konspekt wykładów"
}
```

Notatka `dlaczego-cqrs` ma `date` w postaci `YYYY-MM-DD`, `summary`, `body` jako tablicę akapitów oraz opcjonalne `relatedLessonSlug` i `relatedCourseSlug`. Szczegół pokazuje `title`, `date`, `summary` i `body`. Slugi powiązań zostają w JSON do odczytu; osobnej trasy lekcji nie ma.

### 5. CV lokalne

Aplikacja importuje wyłącznie `cv.json`. Tego pliku nie edytuje się ręcznie: najbliższy `prestart`, `prebuild`, `pretest` albo `pretest:ci` nadpisze go kopią.

[scripts/copy-cv.mjs](../../../src/Clients/web/scripts/copy-cv.mjs):

1. Szuka `src/Clients/web/src/content/cv.local.json`.
2. Gdy plik jest — kopiuje go do `cv.json` i loguje `Copied cv.local.json → cv.json`.
3. Gdy go nie ma — kopiuje `cv.example.json` i loguje `Copied cv.example.json → cv.json`.

Hooki w `package.json` wołają skrypt przed `vite`, `vite build`, `vitest` i `vitest run`. Na runnerze CI nie ma `cv.local.json`, więc do bundla wchodzą placeholdery. Świeży klon zachowuje się tak samo, dopóki lokalny plik nie powstanie.

Prawdziwe CV na maszynie:

```bash
cd src/Clients/web
# plik: src/content/cv.local.json  (kształt jak cv.example.json, oba locale)
node scripts/copy-cv.mjs
pnpm start
```

`git checkout` tego pliku nie przywiezie. Obraz webu bierze go tylko wtedy, gdy leży w kontekście `src/Clients` przed `pnpm build`. Sam wpis w `.gitignore` kontekstu Dockera nie wycina i nie wpuszcza — robi to negacja w `.dockerignore`. Bez lokalnego pliku obraz buduje się z example: placeholdery na home i na `/cv`.

Po zmianie `cv.local.json` ponów `node scripts/copy-cv.mjs` albo restart `pnpm start` (`prestart` kopiuje sam).

### 6. `fetch` przy login i register

`AuthProvider` w [main.tsx](../../../src/Clients/web/src/main.tsx) otacza `BrowserRouter`. `useAuth()` poza tym drzewem rzuca `useAuth requires AuthProvider`.

Token leży w `localStorage` pod kluczem `jjdevhub.token`. Brak `localStorage` (środowisko bez okna) daje `null` i nic nie zapisuje. `isAuthenticated` to obecność tego stringa. Klient nie woła `GET /api/auth/me`, żeby odtworzyć sesję.

Wspólna funkcja w [auth.tsx](../../../src/Clients/web/src/app/auth/auth.tsx):

```ts
async function postAuth(path: 'login' | 'register', email: string, password: string): Promise<string> {
  const response = await fetch(`/api/auth/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) {
    const payload: unknown = await response.json().catch(() => null);
    throw readApiError(response.status, payload);
  }
  const payload: unknown = await response.json();
  const token = readToken(payload);
  if (!token) {
    throw readApiError(response.status, { message: 'Request failed.' });
  }
  return token;
}
```

Ciało żądania, camelCase, zgodne z `LoginRequest` / `RegisterRequest`:

```json
{ "email": "you@example.com", "password": "secret-at-least-8" }
```

Odpowiedź `AuthResponse`, którą czyta `readToken`: niepusty string w polu `token`. Pole `expiresAt` w odpowiedzi jest; klient go nie zapisuje. W `localStorage` ląduje sam JWT.

| Wywołanie | Sukces | Błąd, który widzi formularz |
| --- | --- | --- |
| `POST /api/auth/login` | 200 i `token` | 401 → tekst `Invalid email or password.` |
| `POST /api/auth/register` | 201 i `token` | problem walidacji: `errors` spłaszczone do jednego zdania |
| którekolwiek, sieć albo brak `token` | — | `Something went wrong.` albo `Request failed.` |

`describeApiError` skleja tablice stringów z `errors` spacją. Przy 401 ten tekst wygrywa z resztą payloadu. Komunikaty formularza są po angielsku, w kodzie klienta. `pl.json` ich nie niesie: `/login` i `/register` stoją poza `/:lang`.

Po sukcesie `login` / `register` wołają `storeToken`, potem `setToken`. `logout` czyści klucz i stan. `GuestRoute` przy `isAuthenticated` robi `<Navigate to="/" replace />`. Submit strony po sukcesie nawiguje na `/` (`viewTransition`). `/` prowadzi na `/pl` — mapa jest w [02-trasy.md](02-trasy.md).

W dev adres `/api/auth/login` zostaje względny. Vite na porcie 4200 proxy’uje `/api` na `localhost:5080`. Kroki proxy są w [vite/01-dev.md](../vite/01-dev.md). W obrazie to samo `/api/` przejmuje nginx i oddaje do `api:8080`.

Hasła i maila do logu, do query stringa i do etykiety metryki nie wpisuj. Token zostaje w `localStorage` i w pamięci stanu.

## Przypadki użycia

### Lista kursów

Wejście: `/pl/courses` albo `/en/courses`.

Dane: `siteFor(locale).courses`. Nagłówek bierze `title` (jeden `h1`) i `lead`. Każdy element `items` to link `/${locale}/courses/${course.slug}` z `title`, `subtitle` i akapitami `summary`. `key` to `course.slug`.

Pusta `items` zostawia nagłówek i nie rysuje siatki. Wczesny return listy jest w [01-komponenty.md](01-komponenty.md). Osobnego zdania „brak kursów” nie ma w JSON — nie wymyślaj go w komponencie.

```tsx
export function CoursesPage() {
  const { pathname } = useLocation();
  const locale = localeFromPathname(pathname);
  const section = siteFor(locale).courses;

  return (
    <section>
      <header>
        <h1>{section.title}</h1>
        <p>{section.lead}</p>
      </header>
      <CourseList locale={locale} items={section.items} />
    </section>
  );
}
```

`CourseList` przy `items.length === 0` wraca wcześniej. W przeciwnym razie renderuje listę linków. Szczegół kursu (`courseBySlug`) dokłada `repoUrl` / `labUrl` jako linki zewnętrzne i bloki lekcji oraz rozdziałów. Pusta `lessons` nie rysuje sekcji sylabusa.

Sieć: wejście na listę nie wysyła `fetch`.

### Szczegół notatki

Wejście: `/pl/notes/dlaczego-cqrs` (slug z JSON).

```tsx
export function NoteDetailPage() {
  const { slug = '' } = useParams();
  const { pathname } = useLocation();
  const locale = localeFromPathname(pathname);
  const section = siteFor(locale).notes;
  const note = noteBySlug(slug, locale);

  if (!note) {
    return <Navigate to={`/${locale}/notes`} replace />;
  }

  return (
    <article>
      <header>
        <p>
          <Link to={`/${locale}/notes`} aria-label={section.backLabel}>
            ←
          </Link>
        </p>
        <time dateTime={note.date}>{note.date}</time>
        <h1>{note.title}</h1>
        <p>{note.summary}</p>
      </header>
      {note.body.map((paragraph) => (
        <p key={paragraph}>{paragraph}</p>
      ))}
    </article>
  );
}
```

Dla `dlaczego-cqrs` użytkownik widzi datę `2026-03-02`, tytuł i trzy akapity `body` z `pl.json` (albo odpowiednik z `en.json` pod `/en/notes/dlaczego-cqrs`). Slug spoza listy, także pusty, wraca na listę notatek tego języka.

`relatedCourseSlug` (`mobile` przy tej notatce) i `relatedLessonSlug` zostają na obiekcie. Szczegół ich nie zamienia na drugą nawigację, dopóki copy linku nie stoi w JSON.

Sieć: wejście na szczegół nie wysyła `fetch`.

### Formularz logowania

Wejście: `/login`. Zalogowany użytkownik nie zostaje na formularzu: `GuestRoute` odsyła na `/`.

Etykiety są w komponentach, po angielsku: tytuł `Log in`, submit `Log in`, w trakcie `Signing in…`, pola `Email` i `Password`, podpowiedź z linkiem do `/register`. Rejestracja używa tego samego formularza: `Register`, `Create account`, `Creating account…`, `autoComplete="new-password"`, link do `/login`.

```tsx
export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();

  async function submit(email: string, password: string): Promise<void> {
    await auth.login(email, password);
    void navigate('/', { viewTransition: true });
  }

  return (
    <AuthForm
      title="Log in"
      submitLabel="Log in"
      pendingLabel="Signing in…"
      passwordAutoComplete="current-password"
      hint={
        <>
          No account? <Link to="/register">Register</Link>
        </>
      }
      onSubmit={submit}
    />
  );
}
```

Formularz trzyma `email`, `password`, `error` i `pending`. Submit czyści błąd, ustawia `pending` i woła `onSubmit`. Sukces zostawia przycisk w stanie oczekiwania aż do odmontowania (nawigacja). Błąd zdejmuje `pending` i pokazuje jeden akapit z `describeApiError`.

Pola: `type="email"` i `type="password"`, oba `required`, hasło `minLength={8}`, `autoComplete` `username` oraz `current-password` (przy rejestracji `new-password`). Przycisk `type="submit"` jest `disabled` w trakcie żądania.

Przebieg, który ma wyjść z tego formularza:

1. Użytkownik wpisuje mail i hasło i wysyła formularz.
2. Klient robi `POST /api/auth/login` z JSON-em `{ email, password }` i bez nagłówka `Authorization`.
3. Odpowiedź 401 pokazuje `Invalid email or password.` i zostawia gościa na `/login`.
4. Odpowiedź 200 z `token` zapisuje `jjdevhub.token` i przechodzi na `/`, a stamtąd na `/pl`.
5. Odświeżenie strony z tokenem w `localStorage` ustawia `isAuthenticated`. Wejście na `/login` wraca na `/`.
6. `logout` usuwa klucz. Formularz znowu jest dostępny.

Rejestracja różni się ścieżką (`/api/auth/register`) i kodem sukcesu 201. Zły format Identity wraca jako `errors`; formularz pokazuje złączone komunikaty, nie surowy JSON.

Wygląd kontrolek (`button`, `input`) jest w [shadcn/03-komponenty.md](../shadcn/03-komponenty.md). Ten przypadek ustala pola, stany i `fetch`.

## Zasady wyglądu

Klasy Tailwinda siedzą na znacznikach z przypadków powyżej. Heksy w `className` nie występują. Liczby są w [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts), opisane w [motyw.md](../motyw.md): płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, krój Inter.

Lista kursów i artykuł notatki są jasne: tło płótna, tekst atramentu, link akcentem. Duży odstęp między kartami i między akapitami, mało ramek. Szerokość artykułu i siatkę kart bierze [tailwind/03-uklad.md](../tailwind/03-uklad.md), skalę pisma [tailwind/04-typografia.md](../tailwind/04-typografia.md).

Ciemny hero jest na home i bierze `cv.name` oraz `cv.role` z tego modułu. Ruch hero opisuje [motion/02-hero.md](../motion/02-hero.md). Podstrony kursu i notatki hero nie powtarzają.

Formularz logowania jest jasną stroną w `main`: jeden `h1`, `<form>`, etykiety powiązane z polami, akapit błędu, przycisk. Stan `disabled`, fokus i błąd pola opisuje [tailwind/05-stany.md](../tailwind/05-stany.md).

Jeden `h1` na widok. Lista kursów: `h1` to `section.title`, karta ma `h2`. Notatka: `h1` to `note.title`. Login: `h1` to tytuł formularza.

## Poza zakresem

- Mapa routera, `LangGate` i `BrowserRouter` — [02-trasy.md](02-trasy.md).
- Jeden komponent na plik, kolejność w pliku, wczesny return — [01-komponenty.md](01-komponenty.md).
- Testy listy, błędu logowania i przełącznika języka — [04-testy.md](04-testy.md).
- Port 4200 i tabela proxy — [vite/01-dev.md](../vite/01-dev.md).
- Katalog `button` / `input` shadcn i późniejszy CRUD intranetu na tych samych kontrolkach — [shadcn/03-komponenty.md](../shadcn/03-komponenty.md).
- Ekran listy kursów na telefonie — [nativewind/02-ekrany.md](../nativewind/02-ekrany.md). Telefon ma własny ekran i te same liczby z `tokens.ts`. Drugiego źródła copy tu nie przybywa.
- `GET /api/auth/me` istnieje w API. Ten klient używa go do narysowania stron treści ani do sprawdzenia sesji przy starcie.
- Wołanie HTTP po wykłady, notatki, kompendium albo CV. Do czasu intranetu copy zostaje w bundlu.
- Tamagui.

## Gotowe gdy

- `pl.json` i `en.json` przechodzą `readSite`, a wygenerowany `cv.json` przechodzi `readCv`. Zły kształt przerywa start modułu komunikatem z tego pliku.
- Slug kursu, hasła i notatki jest wspólny dla `pl` i `en`. Przełącznik języka zostawia ten slug na ścieżce.
- `/pl/courses` pokazuje `title` i karty z bundla (`Aplikacje mobilne` i drugi kurs). Wejście nie wysyła `fetch`. Pusta `items` zostawia `h1` i lead, bez siatki.
- `/pl/notes/dlaczego-cqrs` pokazuje datę, tytuł, summary i akapity `body`. Nieznany slug robi `replace` na `/pl/notes`. To samo dla `en`.
- `node scripts/copy-cv.mjs` przy obecnym `cv.local.json` loguje `Copied cv.local.json → cv.json`. Bez tego pliku loguje `Copied cv.example.json → cv.json`. Oba pliki wyniku i local są poza gitem; `cv.example.json` jest w repo.
- `pnpm start`, `pnpm build` i `pnpm test:ci` kopiują CV, zanim Vite albo Vitest zaimportuje `cv.json`.
- Submit na `/login` wysyła `POST /api/auth/login` z `{ email, password }`. 401 pokazuje `Invalid email or password.`. 200 zapisuje `jjdevhub.token` i schodzi z formularza na `/`.
- `/register` używa tej samej funkcji ze ścieżką `register`. Sukces 201 zapisuje ten sam klucz.
- Strony home, CV, kursów, kompendium i notatek nie wołają `fetch`. `useAuth` działa pod `AuthProvider`.
