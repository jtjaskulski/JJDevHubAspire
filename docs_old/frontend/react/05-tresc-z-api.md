# Treść z API

Ten plik przenosi treść stron z JSON-a w bundlu do usług z [docs/api](../../api/README.md): wykłady, kompendium i kursy z Learning ([19](../../api/19-learning.md)), wyszukiwanie ([20](../../api/20-wyszukiwanie.md)), notatki z News ([21](../../api/21-notatki.md)) i CV ([22](../../api/22-cv.md)). W bundlu zostaje tekst interfejsu: nawigacja, nagłówki sekcji, etykiety przycisków.

Łańcuch webu się nie zmienia: React składa HTML5, Vite podaje jeden `src/styles.css`, Tailwind v4 daje klasy, shadcn i Motion siedzą na tym samym HTML. Zmienia się źródło danych opisane w [03-tresc-i-auth.md](03-tresc-i-auth.md). Logowanie i rejestracja zostają tam, gdzie są, a ten plik dokłada do nich klienta HTTP z typami.

## Po co

Dziś zmiana literówki w lekcji to commit, build obrazu web i deploy. Treść jest w tym samym cyklu wydań co kod, a student widzi to samo co anonim, bo bundle nie zna widoczności. Po przeniesieniu treść zmienia się w intranecie ([intranet/01-dostep-i-trasy.md](../intranet/01-dostep-i-trasy.md)) i jest widoczna od razu, bez wydania. API filtruje widoczność `Public`/`Students`/`Private` po tokenie, więc ten sam adres pokazuje studentowi więcej niż gościowi.

Koszt: strona czeka na sieć. Ten plik ustala, jak to zrobić bez migotania: cache zapytań, stany ładowania i błędu jako wczesny return, prefetch przy najechaniu na link i rewalidacja przez `ETag`, którą przeglądarka robi sama.

## Dlaczego te biblioteki

- **Typy z dokumentu OpenAPI, nie pisane ręcznie.** Usługi z [16](../../api/16-usluga-news.md), [19](../../api/19-learning.md), [21](../../api/21-notatki.md) i [22](../../api/22-cv.md) generują dokument OpenAPI przy buildzie, tak jak dziś [src/api/JJDevHub.Api.csproj](../../../src/api/JJDevHub.Api.csproj) (`OpenApiGenerateDocumentsOnBuild`). Dokument leży w gicie obok projektu. [openapi-typescript](https://openapi-ts.dev/) zamienia go na typy TypeScript, a [openapi-fetch](https://openapi-ts.dev/openapi-fetch/) daje cienkie (ok. 6 kB) opakowanie `fetch`, w którym ścieżka, parametry i odpowiedź są sprawdzane przez `tsc`. Zmiana rekordu w C# bez przebudowania typów kończy się czerwonym `pnpm build`, a nie białą stroną na produkcji. Generatory pełnych klientów (NSwag, Kiota, orval) dają więcej kodu do utrzymania przy tej samej gwarancji.
- **TanStack Query zamiast własnego `useEffect` z `fetch`.** Cache po kluczu, deduplikacja dwóch komponentów pytających o to samo, anulowanie przez `AbortSignal` przy zmianie trasy, ponowienie po błędzie sieci, mutacje z unieważnieniem kluczy. Alternatywy: SWR (mniejszy, bez mutacji z optymistycznym stanem i bez devtools), RTK Query (wymaga Reduxa, którego klient nie ma), loadery React Routera 7 (wymagają przejścia z `BrowserRouter` na tryb danych `createBrowserRouter`, a trasy z [02-trasy.md](02-trasy.md) są deklaratywne; loader nie dzieli cache między trasami).
- **Trusted Types i DOMPurify dla HTML z serwera.** Lekcje, hasła i notatki przychodzą jako HTML złożony i oczyszczony po stronie usługi (`HtmlSanitizer` w [19](../../api/19-learning.md)). Klient wstawia go przez `dangerouslySetInnerHTML`, więc to jedyne miejsce w aplikacji, gdzie string staje się DOM-em. [Trusted Types](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) w CSP sprawiają, że przeglądarka odrzuca każde inne przypisanie do `innerHTML`, a jedyna dozwolona polityka przepuszcza HTML drugi raz przez [DOMPurify](https://github.com/cure53/DOMPurify) z tą samą listą tagów. React 19 przyjmuje obiekt `TrustedHTML` w `__html`. Przeglądarka bez Trusted Types ignoruje dyrektywę, a DOMPurify działa dalej.
- **Metadane dokumentu z React 19.** `<title>` i `<meta name="description">` renderowane w komponencie strony trafiają do `<head>`. Biblioteka typu `react-helmet` nie jest potrzebna.

## Wersje i pakiety

Wersje przypina lockfile przy `pnpm add`.

| Pakiet | Rodzaj | Licencja | Rola |
| --- | --- | --- | --- |
| `openapi-fetch` | dependency | MIT | klient HTTP z typami ścieżek |
| `@tanstack/react-query` | dependency | MIT | cache zapytań i mutacje |
| `dompurify` | dependency | Apache-2.0 albo MPL-2.0 | drugie oczyszczenie HTML z serwera |
| `openapi-typescript` | devDependency | MIT | typy z dokumentów OpenAPI |
| `@types/trusted-types` | devDependency | MIT | typy `trustedTypes`, gdy `lib.dom` danej wersji TypeScriptu ich nie ma |

```bash
cd src/Clients/web
pnpm add openapi-fetch @tanstack/react-query dompurify
pnpm add -D openapi-typescript @types/trusted-types
```

## Ścieżki w repo

| Ścieżka | W gicie | Rola |
| --- | --- | --- |
| `src/services/<Usługa>/<Usługa>.API/openapi/<Usługa>.API.json` | tak | dokument OpenAPI z buildu usługi |
| `src/api/openapi/JJDevHub.Api.json` | tak | dokument dzisiejszego API; po przeniesieniu do `Identity.API` w [15](../../api/15-identity.md) pasuje do wiersza wyżej |
| `src/Clients/web/src/app/api/schema/learning.ts`, `news.ts`, `cv.ts`, `identity.ts` | tak | typy wygenerowane, nie edytuj ręcznie |
| `src/Clients/web/src/app/api/clients.ts` | tak | `learningApi`, `newsApi`, `cvApi`, `identityApi` z middleware tokenu |
| `src/Clients/web/src/app/api/api-error.ts` | tak | `ApiError(status, problem)` z `ProblemDetails` |
| `src/Clients/web/src/app/api/query-client.ts` | tak | `QueryClient` z domyślnymi opcjami |
| `src/Clients/web/src/app/api/queries/` | tak | hooki `useLesson`, `useTrack`, `useTechnology`, `useTerm`, `useLectures`, `useArticles`, `useResume`, `useSearch`, `useMe` |
| `src/Clients/web/src/app/content/ServerHtml.tsx` | tak | jedyny `dangerouslySetInnerHTML` w aplikacji |
| `src/Clients/web/src/app/content/server-html.ts` | tak | polityka Trusted Types, DOMPurify, adresy linków |
| `src/Clients/web/src/app/content/useContentLinks.ts` | tak | klik w link wewnętrzny idzie przez router |
| `src/Clients/web/src/app/pages/technologies/TechnologyPage.tsx` | tak | `/:lang/technologies/:slug` |
| `src/Clients/web/src/app/pages/learn/TrackPage.tsx`, `LessonPage.tsx` | tak | `/:lang/learn/:track`, `/:lang/learn/:track/:lesson` |
| `src/Clients/web/src/app/pages/compendium/SearchBox.tsx` | tak | pole wyszukiwania na `/:lang/compendium` |
| `src/Clients/web/src/test/stub-api.ts` | tak | stub `fetch` po metodzie i ścieżce do testów |
| `src/Clients/web/nginx.conf` | tak | nagłówek `Content-Security-Policy` |

Znikają po imporcie CV z [22](../../api/22-cv.md): `src/content/cv.example.json` (kopia trafia do `tests/Cv.API.Tests/Fixtures/`), `cv.local.json`, wygenerowany `cv.json`, `scripts/copy-cv.mjs`, hooki `prestart`, `prebuild`, `pretest`, `pretest:ci`, negacja `!web/src/content/cv.local.json` w `src/Clients/.dockerignore` i wpisy w `.gitignore`. Typy `CvFile` i `CvLocaleContent` z `content.model.ts` też odchodzą.

## Tutorial

### 1. Kolejność wdrożenia

Każda strona przechodzi na API dopiero wtedy, gdy jej usługa działa na produkcji i import starej treści się wykonał. Do tego czasu czyta bundle jak dziś.

| Po numerze API | Strony na API | Co znika z `pl.json` i `en.json` |
| --- | --- | --- |
| [15](../../api/15-identity.md) | `useMe` w shellu (role), kod zaproszenia przy rejestracji | — |
| [19](../../api/19-learning.md) | `courses`, `courses/:slug`, `compendium`, `compendium/:slug`, nowe `technologies/:slug`, `learn/*` | `courses.items`, `compendium.items` |
| [20](../../api/20-wyszukiwanie.md) | pole wyszukiwania na `compendium` | — |
| [21](../../api/21-notatki.md) | `notes`, `notes/:slug`, notatki na home | `notes.items`, `home.notes.items` |
| [22](../../api/22-cv.md) | `cv`, hero na home | `cv.json` i cały mechanizm kopiowania |

Klucze interfejsu (`title`, `lead`, `backLabel`, `lessonsTitle`, `plannedLead` i podobne) zostają w bundlu. Guardy w `content.ts` przestają wymagać tablic `items`.

### 2. Dokumenty OpenAPI w gicie

W każdym `*.API.csproj` usługi, wzorem `src/api/JJDevHub.Api.csproj`:

```xml
<PropertyGroup>
  <OpenApiGenerateDocumentsOnBuild Condition="'$(Configuration)' != 'Release'">true</OpenApiGenerateDocumentsOnBuild>
  <OpenApiDocumentsDirectory>$(MSBuildProjectDirectory)/openapi</OpenApiDocumentsDirectory>
</PropertyGroup>
```

Pakiet `Microsoft.Extensions.ApiDescription.Server` (MIT) w `Directory.Packages.props`. Usługa przy generowaniu dokumentu nie łączy się z bazą ani z Kafką: `Program.cs` sprawdza argumenty tak jak dzisiejsze `IsOpenApiDocumentGeneration`.

Job `ci` z [18-ci-uslug.md](../../api/18-ci-uslug.md) po `dotnet build` sprawdza `git diff --exit-code -- '**/openapi/*.json'`. Zmiana kontraktu bez zacommitowanego dokumentu jest czerwona.

### 3. Typy w kliencie

```json
{
  "scripts": {
    "api:types": "node scripts/api-types.mjs",
    "api:check": "node scripts/api-types.mjs && git diff --exit-code -- src/app/api/schema"
  }
}
```

`scripts/api-types.mjs` woła `openapi-typescript` dla czterech plików z sekcji „Ścieżki w repo” i zapisuje wynik w `src/app/api/schema/`. Job `web` w [web.yml](../../../.github/workflows/web.yml) uruchamia `pnpm api:check` przed `pnpm build`. Dokument usługi i typy klienta rozjeżdżają się więc tylko na gałęzi, nigdy na `main`.

Filtr ścieżek joba `web` dostaje `src/services/*/*.API/openapi/**` i `src/api/openapi/**`: zmiana kontraktu uruchamia też test klienta.

### 4. Klienci i token

```ts
import createClient, { type Middleware } from 'openapi-fetch';

import { readStoredToken, notifyUnauthorized } from '../auth/token-store';
import type { paths as CvPaths } from './schema/cv';
import type { paths as IdentityPaths } from './schema/identity';
import type { paths as LearningPaths } from './schema/learning';
import type { paths as NewsPaths } from './schema/news';

const bearer: Middleware = {
  onRequest({ request }) {
    const token = readStoredToken();
    if (token) {
      request.headers.set('Authorization', `Bearer ${token}`);
    }
    return request;
  },
  onResponse({ response }) {
    if (response.status === 401 && readStoredToken()) {
      notifyUnauthorized();
    }
    return response;
  },
};

export const learningApi = createClient<LearningPaths>();
export const newsApi = createClient<NewsPaths>();
export const cvApi = createClient<CvPaths>();
export const identityApi = createClient<IdentityPaths>();

for (const client of [learningApi, newsApi, cvApi, identityApi]) {
  client.use(bearer);
}
```

Adresy są względne (`/api/...`): w dev proxy z [vite/01-dev.md](../vite/01-dev.md), w obrazie nginx i gateway z [18-ci-uslug.md](../../api/18-ci-uslug.md). Każda usługa ma swój typ `paths`, bo dokumenty są osobne, a ścieżki nie nachodzą na siebie.

`token-store.ts` wyciąga z `auth.tsx` odczyt i zapis klucza `jjdevhub.token`. `notifyUnauthorized` wysyła zdarzenie, na które `AuthProvider` reaguje `logout()`: token wygasł albo klucz podpisu się zmienił, więc stary token nic już nie da. `postAuth` z [03-tresc-i-auth.md](03-tresc-i-auth.md) przechodzi na `identityApi.POST('/api/auth/login', …)` i dostaje typy żądania za darmo.

### 5. QueryClient i sesja

```ts
import { QueryClient } from '@tanstack/react-query';

import { ApiError } from './api-error';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 60_000,
      retry: (failureCount, error) =>
        !(error instanceof ApiError && error.status < 500) && failureCount < 2,
      refetchOnWindowFocus: false,
    },
  },
});
```

`staleTime` 60 s odpowiada `Cache-Control: public, max-age=60` z [19](../../api/19-learning.md). Błąd `4xx` się nie powtarza: `404` znaczy „nie ma albo nie dla ciebie”, a powtórka niczego nie zmieni.

Kolejność providerów w `main.tsx`: `QueryClientProvider`, w nim `AuthProvider`, w nim `BrowserRouter` i `App`. `AuthProvider` przy każdej zmianie tokenu (login, logout, `notifyUnauthorized`) woła `queryClient.clear()`. Klucze zapytań nie niosą roli: po zmianie sesji cache jest pusty, więc lekcja `Students` pobrana przez studenta nie zostaje w pamięci po wylogowaniu.

`useMe()` to `useQuery` na `GET /api/auth/me`, włączony tylko przy tokenie. Zwraca `roles` z `MeResponse` ([15](../../api/15-identity.md)). `isAuthenticated` zostaje obecnością tokenu, a `isOwner` i `isStudent` biorą się z `useMe`. Shell pokazuje link „Intranet” dla ownera.

### 6. Hook zapytania

Jeden hook na zasób, w `src/app/api/queries/`. Klucz zaczyna się od nazwy usługi, potem zasób i parametry, w tej kolejności co w adresie.

```ts
import { useQuery } from '@tanstack/react-query';

import type { LocaleCode } from '../../content/content.model';
import { ApiError } from '../api-error';
import { learningApi } from '../clients';

export function useLesson(lang: LocaleCode, track: string, lesson: string) {
  return useQuery({
    queryKey: ['learning', 'lesson', lang, track, lesson],
    queryFn: async ({ signal }) => {
      const { data, error, response } = await learningApi.GET(
        '/api/learning/tracks/{slug}/lessons/{lessonSlug}',
        { params: { path: { slug: track, lessonSlug: lesson }, query: { lang } }, signal },
      );
      if (error) {
        throw new ApiError(response.status, error);
      }
      return { lesson: data, language: response.headers.get('Content-Language') ?? lang };
    },
  });
}
```

`signal` anuluje żądanie, gdy użytkownik przejdzie dalej, zanim odpowiedź wróci. `Content-Language` mówi, w jakim języku treść naprawdę przyszła: lekcja bez wersji angielskiej wraca po polsku ([19](../../api/19-learning.md)).

Rewalidacji `ETag` klient nie pisze. Odpowiedź zalogowanego ma `Cache-Control: private, no-cache` i `ETag`, więc przeglądarka sama wysyła `If-None-Match`, a `304` zamienia na `200` z własnego cache. `fetch` widzi zwykłe `200`.

### 7. Strona z danymi z API

Ładowanie, błąd i pusty stan to wczesne returny, jak pusta lista w [01-komponenty.md](01-komponenty.md). `404` wraca na listę sekcji w tym samym języku, tak jak dziś nieznany slug ([02-trasy.md](02-trasy.md)).

```tsx
export function LessonPage() {
  const { lang, track, lesson } = useLessonParams();
  const { data, error, isPending, refetch } = useLesson(lang, track, lesson);
  const copy = siteFor(lang).learn;

  if (isPending) {
    return <PageSkeleton />;
  }
  if (error instanceof ApiError && error.status === 404) {
    return <Navigate to={`/${lang}/learn/${track}`} replace />;
  }
  if (error) {
    return <LoadError message={copy.loadError} onRetry={() => refetch()} />;
  }

  return (
    <article>
      <title>{`${data.lesson.title} · JJDevHub`}</title>
      <LanguageNotice requested={lang} actual={data.language} copy={copy} />
      <h1>{data.lesson.title}</h1>
      <ServerHtml html={data.lesson.html} context={{ lang, track, missing: data.lesson.missingTermSlugs }} />
      <LessonNav previous={data.lesson.previous} next={data.lesson.next} lang={lang} track={track} />
    </article>
  );
}
```

`PageSkeleton` trzyma wysokość nagłówka i kilku linii, więc treść po załadowaniu nie skacze. `LanguageNotice` rysuje plakietkę „Only in Polish” albo „Tylko po angielsku” z bundla, gdy `actual` różni się od `requested`. `LessonNav` na `onMouseEnter` i `onFocus` linku woła `queryClient.prefetchQuery` z kluczem następnej lekcji: kliknięcie zwykle trafia w gotowy cache.

### 8. HTML z serwera

`server-html.ts`:

```ts
import DOMPurify from 'dompurify';

export type ServerHtmlContext = { lang: LocaleCode; track?: string; missing?: readonly string[] };

const allowed = {
  ALLOWED_TAGS: ['p', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'ul', 'ol', 'li', 'table', 'thead', 'tbody', 'tr', 'th', 'td',
    'pre', 'code', 'blockquote', 'a', 'img', 'em', 'strong', 'del', 'sup', 'input', 'mark', 'span'],
  ALLOWED_ATTR: ['href', 'src', 'alt', 'title', 'id', 'class', 'data-lesson', 'data-term', 'checked', 'disabled', 'type'],
};

export function prepareServerHtml(html: string, context: ServerHtmlContext): string {
  const fragment = DOMPurify.sanitize(html, { ...allowed, RETURN_DOM_FRAGMENT: true });
  for (const link of fragment.querySelectorAll<HTMLAnchorElement>('a[data-term]')) {
    const slug = link.dataset.term!;
    if (context.missing?.includes(slug)) {
      link.removeAttribute('href');
      link.classList.add('wikilink-missing');
    } else {
      link.href = `/${context.lang}/compendium/${slug}`;
    }
  }
  for (const link of fragment.querySelectorAll<HTMLAnchorElement>('a[data-lesson]')) {
    if (context.track) {
      link.href = `/${context.lang}/learn/${context.track}/${link.dataset.lesson}`;
    }
  }
  for (const link of fragment.querySelectorAll<HTMLAnchorElement>('a[href^="http"]')) {
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
  }
  const holder = document.createElement('div');
  holder.append(fragment);
  return holder.innerHTML;
}

const policy = window.trustedTypes?.createPolicy('server-html', {
  createHTML: (html: string, context: ServerHtmlContext) => prepareServerHtml(html, context),
});

export function toTrustedHtml(html: string, context: ServerHtmlContext): string | TrustedHTML {
  return policy ? policy.createHTML(html, context) : prepareServerHtml(html, context);
}
```

Lista tagów i atrybutów jest ta sama co w `HtmlSanitizer` z [19](../../api/19-learning.md), plus `mark` i `span` ze snippetów wyszukiwania z [20](../../api/20-wyszukiwanie.md). Serwer nie wstawia `href` do `[[hasło]]`, bo nie zna tras klienta. Klient składa adres i zamienia brakujące hasło na tekst bez linku, z klasą `wikilink-missing` (podkreślenie przerywane, kolor `muted`).

`ServerHtml.tsx` wkłada wynik do `div` przez `dangerouslySetInnerHTML={{ __html: toTrustedHtml(html, context) }}`, w `useMemo` po `html` i `context`. `useContentLinks` podpina jeden `onClick` na tym `div`: klik w `a` z adresem zaczynającym się od `/`, bez modyfikatora (`ctrlKey`, `metaKey`, środkowy przycisk), robi `preventDefault` i `navigate(href)`. Link w nowej karcie działa zwykłym `href`.

Klasy treści (`prose` dla nagłówków, list, tabel, `pre`) są w `src/styles.css` pod jednym selektorem `.server-html`, z liczbami z [motyw.md](../motyw.md). Wtyczki typografii nie ma: tagów jest kilkanaście.

### 9. CSP w obrazie

W [nginx.conf](../../../src/Clients/web/nginx.conf), w `server`:

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; require-trusted-types-for 'script'; trusted-types server-html dompurify" always;
```

- `img-src` dopuszcza `https:`, bo obraz w wyjaśnieniu lekcji ma absolutny adres `https`. Skryptów z obcych hostów nie ma.
- `style-src 'unsafe-inline'` zostaje, bo Radix (pod shadcn) i CodeMirror w intranecie wstawiają elementy `<style>`. Skrypty inline są zabronione, a to one niosą XSS.
- `trusted-types` wymienia dwie polityki: `server-html` z tego pliku i `dompurify`, którą DOMPurify tworzy sam na swój wewnętrzny `innerHTML`.

Pierwszy tydzień nagłówek idzie jako `Content-Security-Policy-Report-Only`. Konsola przeglądarki pokazuje naruszenia bez blokowania. Potem zmiana nazwy na `Content-Security-Policy`. W dev nagłówka nie ma: Vite wstrzykuje style i skrypt HMR inline.

### 10. Nowe trasy

Pod `/:lang`, obok tras z [02-trasy.md](02-trasy.md):

```tsx
<Route path="technologies/:slug" element={<TechnologyPage />} />
<Route path="learn/:track" element={<TrackPage />} />
<Route path="learn/:track/:lesson" element={<LessonPage />} />
```

`/:lang/compendium` staje się wejściem do nauki: siatka technologii (`GET /api/learning/technologies`), pod nią pole wyszukiwania i lista haseł. `TechnologyPage` pokazuje opis, kursy tej technologii z liczbą lekcji i hasła z tej technologii. `TrackPage` to spis lekcji z czasem czytania, a dla studenta znacznik ukończenia. Nawigacja shellu się nie zmienia: home, CV, wykłady, kompendium, notatki.

Wyszukiwanie: `SearchBox` trzyma tekst w `?q=` adresu (`useSearchParams`), więc wynik da się podlinkować i wraca po „wstecz”. `useSearch` startuje od 2 znaków, z opóźnieniem 250 ms (`useDeferredValue` na tekście plus `staleTime`) i `placeholderData: keepPreviousData`, żeby lista nie znikała przy każdej literze. `429` pokazuje zdanie z bundla „Za dużo zapytań, spróbuj za chwilę”. Snippet trafia do `ServerHtml` bez kontekstu kursu.

### 11. Postęp studenta i kod zaproszenia

Student na `LessonPage` widzi przycisk „Oznacz jako przeczytaną”. `useMutation` wysyła `PUT /api/learning/lessons/{id}/progress` z `{ completed }`. `onMutate` ustawia `completed` w cache kursu (`setQueryData`), `onError` przywraca poprzedni stan, `onSettled` unieważnia klucz `['learning', 'track', lang, track]`. Przycisk zmienia się od razu, a błąd sieci cofa go z komunikatem.

Formularz rejestracji dostaje pole „Kod zaproszenia” (opcjonalne), wysyłane w `RegisterRequest` z [15](../../api/15-identity.md). Zalogowany użytkownik bez roli `student` może wpisać kod w menu konta: `POST /api/auth/invites/redeem` zwraca nowy token z rolą, `AuthProvider` go zapisuje, a `queryClient.clear()` przeładowuje treść z nową widocznością.

### 12. CV z API

`CvPage` czyta `GET /api/cv/{lang}` (`ResumeView`). Pod nagłówkiem dwa linki: „PDF” na `pdfUrl` i „JSON Resume” na `jsonResumeUrl`, oba zwykłe `a` z `download` dla JSON-a. Umiejętność z dowodami rozwija listę: kurs, lekcje, notatki, wykłady, z linkami złożonymi według tabeli `EvidenceLinks` z [22](../../api/22-cv.md). Home bierze z tego samego zapytania imię, rolę i dwa ostatnie wpisy doświadczenia, więc przejście z home na `/cv` nie pyta API drugi raz.

## Przypadki użycia

### Lekcja po angielsku, której nie ma po angielsku

Wejście: `/en/learn/dotnet-cqrs/outbox`. API zwraca polską treść z `Content-Language: pl`. Strona rysuje lekcję i plakietkę „Only in Polish”. Przełącznik języka nadal prowadzi na `/pl/learn/dotnet-cqrs/outbox`.

### Lekcja tylko dla studentów, wejście gościa

`GET` zwraca `404` (API nie zdradza, że zasób istnieje). Strona robi `Navigate` na `/en/learn/dotnet-cqrs`. Spis kursu u gościa tej lekcji nie ma.

### Link do brakującego hasła

Lekcja zawiera `[[saga]]`, a hasła `saga` nie ma albo jest prywatne. `missingTermSlugs` zawiera `saga`, więc w treści jest tekst „saga” bez linku, z przerywanym podkreśleniem.

### Wygasły token

Zapytanie wraca `401`. Middleware woła `notifyUnauthorized`, `AuthProvider` czyści token i cache, strona pobiera się drugi raz jako gość. Treść `Students` znika, a shell pokazuje „Zaloguj”.

## Testy

Test zostaje przy tym, co widzi użytkownik ([04-testy.md](04-testy.md)). `fetch` podstawia `stubApi` z `src/test/stub-api.ts`: mapa `'GET /api/learning/lectures'` → `{ status, body, headers }`, inny adres dostaje `500`, a test, który go wywoła, pokazuje błąd zamiast przejść. Każdy test dostaje świeży `QueryClient` z `retry: false`.

| Plik | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `LessonPage.spec.tsx` | stub lekcji z `Content-Language: pl` | render `/en/learn/t/l` | `h1` z tytułem, tekst „Only in Polish” |
| `LessonPage.spec.tsx` | stub `404` | render | jest lista lekcji kursu, nie ma `h1` lekcji |
| `LessonPage.spec.tsx` | stub `500`, potem `200` | klik „Spróbuj ponownie” | `h1` z tytułem |
| `server-html.spec.ts` | HTML z `<script>`, `onerror`, `[[cqrs]]`, `[[saga]]` z `missing: ['saga']` | `prepareServerHtml` | brak `script` i `onerror`, `href="/pl/compendium/cqrs"`, `saga` bez `href` |
| `server-html.spec.ts` | link `https://example.com` | `prepareServerHtml` | `target="_blank"`, `rel="noopener noreferrer"` |
| `ServerHtml.spec.tsx` | treść z linkiem do hasła | klik | `MemoryRouter` jest na `/pl/compendium/cqrs`, bez przeładowania |
| `SearchBox.spec.tsx` | stub wyszukiwania | wpisanie „o” | brak żądania; po „ou” jest lista wyników |
| `Session.spec.tsx` | token, stub `401` na `GET /api/auth/me` | render | token usunięty, shell pokazuje „Log in” |
| `CvPage.spec.tsx` | stub `ResumeView` | render `/pl/cv` | imię w `h1`, link „PDF” z `pdfUrl` |
| `content.spec.ts` | `pl.json` bez `items` | import `content.ts` | moduł się ładuje |

`pnpm api:check` w CI jest testem kontraktu: rekord usługi zmieniony bez nowych typów kończy się błędem `tsc` w `pnpm build`.

## Zasady

- Typy odpowiedzi API tylko z `src/app/api/schema/`. Ręcznie pisany typ odpowiedzi to błąd w review.
- Każde wołanie API przez `learningApi`, `newsApi`, `cvApi` albo `identityApi` i hook z `queries/`. Komponent strony nie woła `fetch`.
- Jedno miejsce z `dangerouslySetInnerHTML`: `ServerHtml`. HTML idzie przez `toTrustedHtml`.
- Klucz zapytania: `[usługa, zasób, ...parametry]`. Zmiana sesji czyści cały cache.
- Ładowanie, błąd i `404` to wczesne returny. `404` wraca na listę sekcji w tym samym języku.
- Tekst interfejsu w `pl.json` i `en.json`. Treść, którą edytuje owner, w API.
- Język żądania z URL (`lang`), język odpowiedzi z `Content-Language`.

## Poza zakresem

- SSR i prerender stron. Klient zostaje SPA za nginx. Metadane dokumentu z React 19 wystarczają do podglądu linku w komunikatorach, które wykonują JavaScript; reszta czeka na osobną decyzję.
- Tryb offline i service worker.
- Mock Service Worker. `stubApi` na `fetch` pokrywa testy jednostkowe, a pełne ścieżki sprawdza smoke z [18-ci-uslug.md](../../api/18-ci-uslug.md).
- Ekrany edycji — [intranet/01-dostep-i-trasy.md](../intranet/01-dostep-i-trasy.md) i [intranet/02-edytor.md](../intranet/02-edytor.md).
- Telefon. Ekrany React Native zostają przy JSON-ie z bundla, dopóki osobny plik nie przeniesie ich na API tym samym klientem.

## Źródła

- [openapi-typescript](https://openapi-ts.dev/) i [openapi-fetch](https://openapi-ts.dev/openapi-fetch/) — typy z OpenAPI 3.1 i klient z middleware.
- [Generate OpenAPI documents at build time](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/openapi/aspnetcore-openapi#generate-openapi-documents-at-build-time) — `OpenApiGenerateDocumentsOnBuild`.
- [TanStack Query: Query Keys](https://tanstack.com/query/latest/docs/framework/react/guides/query-keys), [Optimistic Updates](https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates), [Prefetching](https://tanstack.com/query/latest/docs/framework/react/guides/prefetching).
- [Trusted Types API](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) i [DOMPurify](https://github.com/cure53/DOMPurify) — polityka dla `innerHTML`.
- [React 19: document metadata](https://react.dev/reference/react-dom/components/title) — `<title>` w komponencie.
- [Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP) — dyrektywy i tryb `Report-Only`.

## Gotowe gdy

- `pl.json` i `en.json` nie mają tablic `items`, a `cv.json`, `cv.local.json`, `cv.example.json` i `copy-cv.mjs` nie istnieją w kliencie.
- `pnpm api:check` przechodzi, a zmiana rekordu odpowiedzi w usłudze bez `pnpm api:types` kończy `pnpm build` błędem.
- Student widzi lekcję `Students`, gość na tym samym adresie wraca do spisu kursu.
- Po wylogowaniu treść `Students` znika bez przeładowania strony.
- Klik w `[[hasło]]` w lekcji zmienia trasę bez przeładowania, a brakujące hasło jest tekstem.
- `/pl/compendium?q=outbox` pokazuje wyniki po wejściu z linku.
- Obraz web wysyła `Content-Security-Policy` z `require-trusted-types-for 'script'`, a konsola przeglądarki na stronie lekcji nie pokazuje naruszeń.
- Strony mają `<title>` z tytułem treści.
- `pnpm test:ci` i `pnpm build` kończą się kodem 0.
