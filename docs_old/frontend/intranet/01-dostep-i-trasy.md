# Intranet: dostęp i trasy

Intranet to część klienta web pod `/intranet`, w której owner zarządza treścią: technologiami, kursami i lekcjami, wykładami, hasłami, notatkami, CV, studentami i zaproszeniami. Ten sam `Shell`, te same komponenty z [shadcn/03-komponenty.md](../shadcn/03-komponenty.md), te same tokeny z [motyw.md](../motyw.md), ten sam klient HTTP z [react/05-tresc-z-api.md](../react/05-tresc-z-api.md). Edytor treści opisuje [02-edytor.md](02-edytor.md).

## Po co

Po [react/05-tresc-z-api.md](../react/05-tresc-z-api.md) treść jest w usługach, a każda usługa ma endpointy zapisu z polityką `Owner`. Bez ekranu edycja to `curl` z tokenem i ręcznie liczonym `If-Match`. Intranet daje formularze nad tymi endpointami i nic ponad nie: reguły, walidacja i widoczność są w API, a klient pokazuje ich wynik.

Osobna aplikacja (drugi Vite, drugi obraz, drugi deploy) dałaby izolację kodu, ale podwoiłaby konfigurację, auth i komponenty dla jednego użytkownika. Wspólny klient z leniwym ładowaniem daje ten sam efekt dla gościa: kod intranetu nie trafia do jego przeglądarki.

## Dlaczego tak

- **Strażnik trasy to wygoda, nie zabezpieczenie.** `OwnerRoute` ukrywa ekrany przed kimś bez roli `owner`, ale każdy zapis i tak przechodzi przez politykę `Owner` w usłudze ([15-identity.md](../../api/15-identity.md)). Kod intranetu w publicznym repo nie zdradza niczego, czego nie widać w dokumentach OpenAPI.
- **`React.lazy` i osobny chunk.** CodeMirror, `@dnd-kit` i `diff` z [02-edytor.md](02-edytor.md) ważą razem kilkaset kilobajtów. `import()` w trasie `/intranet/*` sprawia, że Vite składa je w osobne pliki, pobierane dopiero po wejściu ownera.
- **Identyfikatory w adresach intranetu, slugi na stronie.** Slug zmienia się przy edycji tytułu, id nie. Zakładka w przeglądarce ownera przeżywa zmianę sluga.
- **Interfejs tylko po polsku.** Jedynym użytkownikiem jest owner. Formularze treści mają zakładki `PL` i `EN`, bo treść jest dwujęzyczna, ale napisy przycisków są jednojęzyczne.

## Wersje i pakiety

Bez nowych pakietów poza tymi z [react/05-tresc-z-api.md](../react/05-tresc-z-api.md) i [02-edytor.md](02-edytor.md). Komponenty shadcn dochodzą z rejestru:

```bash
cd src/Clients/web
pnpm dlx shadcn@latest add table badge select tabs textarea dropdown-menu alert-dialog sonner tooltip
```

| Komponent | Gdzie |
| --- | --- |
| `table` | listy w każdej sekcji |
| `badge` | widoczność (`Publiczne`, `Studenci`, `Prywatne`), status notatki |
| `select`, `tabs`, `textarea` | formularze, zakładki `PL`/`EN` |
| `dropdown-menu` | akcje wiersza (edytuj, zmień widoczność, usuń) |
| `alert-dialog` | potwierdzenie usunięcia i odebrania roli |
| `sonner` | komunikat po zapisie i po błędzie |
| `tooltip` | opis ikon w wierszu |

Kolory plakietek biorą się z tokenów: `Publiczne` na `accent`, `Studenci` na `ink` z obramowaniem, `Prywatne` na `muted`. Drugiej palety nie ma.

## Ścieżki w repo

Względem `src/Clients/web`:

| Ścieżka | Rola |
| --- | --- |
| `src/app/OwnerRoute.tsx` | strażnik: gość na login z `next`, zalogowany bez roli na `/pl` |
| `src/app/pages/intranet/IntranetRoutes.tsx` | drzewo tras intranetu, ładowane przez `lazy` |
| `src/app/pages/intranet/IntranetLayout.tsx` | boczna nawigacja i `Outlet` |
| `src/app/pages/intranet/DashboardPage.tsx` | `/intranet` |
| `src/app/pages/intranet/technologies/` | lista, edycja technologii z listą jej kursów |
| `src/app/pages/intranet/tracks/` | edycja kursu, lekcje, kolejność |
| `src/app/pages/intranet/lectures/`, `terms/`, `notes/`, `cv/` | pozostałe sekcje treści |
| `src/app/pages/intranet/students/`, `invites/` | role i zaproszenia |
| `src/app/pages/intranet/maintenance/` | jednorazowe importy i `republish` |
| `src/app/pages/intranet/shared/VisibilityBadge.tsx`, `ContentTable.tsx`, `LocalizedFields.tsx` | wspólne kawałki sekcji |
| `src/content/intranet.json` | napisy intranetu, jeden język |
| `src/app/auth/safe-next.ts` | walidacja parametru `next` |

## Tutorial

### 1. Trasa w App

`/intranet/*` jest rodzeństwem `/login`, zadeklarowanym przed `/:lang`, z tego samego powodu co login w [react/02-trasy.md](../react/02-trasy.md): `LangGate` przekierowałby segment `intranet` na `/pl`.

```tsx
const IntranetRoutes = lazy(() =>
  import('./pages/intranet/IntranetRoutes').then((module) => ({ default: module.IntranetRoutes })),
);

<Route
  path="/intranet/*"
  element={
    <OwnerRoute>
      <Suspense fallback={<PageSkeleton />}>
        <IntranetRoutes />
      </Suspense>
    </OwnerRoute>
  }
/>
```

`then` zamienia nazwany eksport na `default`, którego wymaga `lazy`: zasada eksportu nazwanego z [react/01-komponenty.md](../react/01-komponenty.md) zostaje. Przełącznik języka na `/intranet/*` nie zmienia adresu, jak na `/login`.

### 2. OwnerRoute

```tsx
export function OwnerRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated } = useAuth();
  const { pathname, search } = useLocation();
  const me = useMe();

  if (!isAuthenticated) {
    return <Navigate to={`/login?next=${encodeURIComponent(pathname + search)}`} replace />;
  }
  if (me.isPending) {
    return <PageSkeleton />;
  }
  if (!me.data?.roles.includes('owner')) {
    return <Navigate to="/pl" replace />;
  }
  return children;
}
```

Gdy `GET /api/auth/me` zwróci `401`, middleware z [react/05-tresc-z-api.md](../react/05-tresc-z-api.md) wyloguje sesję, `isAuthenticated` stanie się `false`, a strażnik przekieruje na login. Zalogowany student dostaje ten sam wynik co nieznany adres: `/pl`.

`LoginPage` i `GuestRoute` po sukcesie czytają `next` przez `safeNext(search)`: wartość musi zaczynać się od `/intranet` i nie może zaczynać się od `//`. Inaczej cel to `/`. Bez tej reguły `/login?next=//evil.example` byłby otwartym przekierowaniem.

### 3. Drzewo intranetu

```text
/intranet                              IntranetLayout
  index                                DashboardPage
  technologies                         TechnologiesPage
  technologies/new                     TechnologyEditPage
  technologies/:id                     TechnologyEditPage, pod formularzem kursy tej technologii
  tracks/new?technology=:id            TrackEditPage
  tracks/:id                           TrackEditPage, lekcje, kolejność
  tracks/:id/lessons/new               LessonEditPage
  tracks/:id/lessons/:lessonId         LessonEditPage
  lectures, lectures/new, lectures/:id
  terms, terms/new, terms/:id
  notes, notes/new, notes/:id          NoteEditPage z publikacją i historią
  cv                                   CvEditPage
  students                             StudentsPage
  invites                              InvitesPage
  maintenance                          MaintenancePage
  *                                    → /intranet
```

Kursy nie mają osobnej listy: kurs należy do technologii, więc spis kursów jest na stronie technologii. To odpowiada API z [19-learning.md](../../api/19-learning.md), gdzie szczegół technologii zwraca jej kursy.

`IntranetLayout` to `aside` z `nav` (sekcje w kolejności drzewa) i `main` z `Outlet`. Poniżej szerokości `md` nawigacja jest poziomym paskiem nad treścią, przewijanym w poziomie. Belka `Shell` dla ownera ma link „Intranet” po prawej, poza menu językowym.

### 4. Listy

Każda lista to `ContentTable`: kolumny tytuł (po polsku), slug, widoczność i data zmiany. Nad tabelą filtr tekstu (po stronie klienta) i `select` widoczności. Wiersz prowadzi do edycji, a `dropdown-menu` w wierszu ma „Zmień widoczność” i „Usuń”.

| Sekcja | Odczyt | Zapis z listy |
| --- | --- | --- |
| technologie | `GET /api/learning/technologies` | `PUT …/technologies/{id}/visibility`, `DELETE …/technologies/{id}` |
| wykłady | `GET /api/learning/lectures` | to samo dla `lectures` |
| hasła | `GET /api/learning/terms` | to samo dla `terms` |
| notatki | `GET /api/articles?lang=pl&status=` i `lang=en` | `POST /api/articles/{id}/withdraw` |

Token ownera sprawia, że odczyty publiczne zwracają wszystkie poziomy widoczności ([19](../../api/19-learning.md), [21](../../api/21-notatki.md)). Osobnych endpointów listy dla intranetu nie ma.

Zmiana widoczności z listy wysyła `If-Match` z `revision` wiersza. Plakietka zmienia się od razu przez `useOptimistic` (wzorzec w [02-edytor.md](02-edytor.md)). `412` znaczy, że ktoś (druga karta) zmienił wpis: lista unieważnia klucz i pokazuje komunikat „Wpis się zmienił, odśwież i spróbuj ponownie”.

Usunięcie idzie przez `alert-dialog` z nazwą wpisu, jak dialog z [shadcn/03-komponenty.md](../shadcn/03-komponenty.md). `400` z API (np. technologia ma kursy) pokazuje treść `ProblemDetails` w dialogu i go nie zamyka.

### 5. Pulpit

`DashboardPage` składa kilka zapytań, które już istnieją: liczba szkiców notatek (`status=draft`), liczba prywatnych lekcji świeżo z importu, aktywne zaproszenia, data ostatniego renderu CV (z `updatedOn` w `ResumeView`). Każda liczba jest linkiem do przefiltrowanej listy. Statystyk, których API nie ma, pulpit nie liczy.

### 6. Studenci i zaproszenia

`InvitesPage`:

- formularz: etykieta (np. „PWr 2026 lato”), data ważności, limit użyć → `POST /api/auth/invites`,
- odpowiedź `201` z `code` otwiera dialog z kodem, przyciskiem „Kopiuj” (`navigator.clipboard.writeText`) i zdaniem „Kod widać tylko teraz”. Zamknięcie dialogu usuwa kod z pamięci komponentu,
- tabela z `GET /api/auth/invites`: etykieta, ważność, `usedCount`/`maxUses`, stan; akcja „Unieważnij” → `DELETE /api/auth/invites/{id}`.

`StudentsPage`: tabela z `GET /api/auth/users?role=student` (e-mail, data utworzenia), akcja „Odbierz rolę” przez `alert-dialog` → `DELETE /api/auth/users/{id}/roles/student`. Pole „Nadaj rolę” przyjmuje e-mail, szuka konta w `GET /api/auth/users` bez filtra `role` i woła `PUT …/roles/student`. Zwykle i tak wystarcza kod zaproszenia: student dostaje rolę sam przy rejestracji.

Kod zaproszenia nie trafia do `localStorage`, do adresu ani do logu konsoli.

### 7. Operacje jednorazowe

`MaintenancePage` zbiera przyciski, które wywołuje się raz po wdrożeniu numeru API:

| Przycisk | Endpoint | Numer |
| --- | --- | --- |
| „Importuj treść z bundla” | `POST /api/learning/import/legacy` | [19](../../api/19-learning.md) |
| „Importuj notatki z bundla” | `POST /api/articles/import/legacy` | [21](../../api/21-notatki.md) |
| „Importuj CV z pliku” | `POST /api/cv/import` z plikiem wybranym w `input type="file"` | [22](../../api/22-cv.md) |
| „Opublikuj stan Learning ponownie” | `POST /api/learning/republish` | [19](../../api/19-learning.md) |
| „Opublikuj notatki ponownie” | `POST /api/articles/republish` | [22](../../api/22-cv.md) |

Każdy przycisk otwiera `alert-dialog` z opisem skutku, a raport z odpowiedzi (`Imported`, `Skipped`) pokazuje się w tabeli pod przyciskiem. Plik CV czyta `FileReader` w przeglądarce i wysyła jako ciało żądania. Plik nie wychodzi nigdzie poza API.

## Przypadki użycia

### Wejście z zakładki bez sesji

`/intranet/notes/0b5c…` bez tokenu → `/login?next=%2Fintranet%2Fnotes%2F0b5c…`. Po zalogowaniu owner ląduje na edycji notatki.

### Student zna adres

Student wpisuje `/intranet`. `useMe` zwraca `roles: ['student']`, strażnik robi `Navigate` na `/pl`. Chunk intranetu się nie pobiera, bo `Suspense` z `lazy` jest pod strażnikiem.

### Owner w dwóch kartach

Karta A zmienia widoczność hasła. Karta B, otwarta wcześniej, próbuje tego samego. API zwraca `412`, karta B unieważnia listę i pokazuje komunikat. Zmiana z karty A zostaje.

## Testy

Wzorzec renderu z [react/04-testy.md](../react/04-testy.md), stub API ze [react/05-tresc-z-api.md](../react/05-tresc-z-api.md).

| Plik | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `OwnerRoute.spec.tsx` | brak tokenu | render `/intranet/terms` | jest formularz logowania, adres `/login?next=%2Fintranet%2Fterms` |
| `OwnerRoute.spec.tsx` | token, `me` z rolą `student` | render `/intranet` | jest home `/pl` |
| `OwnerRoute.spec.tsx` | token, `me` z rolą `owner` | render `/intranet` | jest nagłówek pulpitu |
| `safe-next.spec.ts` | `//evil.example`, `/pl`, `/intranet/cv` | `safeNext` | `/`, `/`, `/intranet/cv` |
| `InvitesPage.spec.tsx` | stub `201` z `code` | wysłanie formularza | dialog z kodem; po zamknięciu kodu nie ma w DOM |
| `ContentTable.spec.tsx` | stub `412` na zmianę widoczności | wybór „Studenci” | plakietka wraca do poprzedniej, komunikat o zmianie |
| `MaintenancePage.spec.tsx` | stub raportu `{ imported: 8, skipped: 0 }` | klik i potwierdzenie | tabela z `8` |

Kontrola chunków po `pnpm build`: `scripts/check-chunks.mjs` czyta `dist/.vite/manifest.json` (`build.manifest: true`) i sprawdza, że plik wejścia (`index.html` → `isEntry`) nie importuje statycznie modułów `@codemirror/*`, `@dnd-kit/*` ani `diff`. Skrypt biegnie w jobie `web` po buildzie.

## Zasady

- Ekrany intranetu w `src/app/pages/intranet/`, w tym samym `App` i `Shell`.
- Wszystko pod `/intranet/*` ładuje się przez jeden `lazy`. Strona publiczna nie importuje niczego z `pages/intranet/`.
- Każdy zapis z `If-Match`. `412` to komunikat i odświeżenie, nie ciche nadpisanie.
- Błąd z API pokazuje `title` i `errors` z `ProblemDetails` przy polu albo w dialogu. Klient nie powtarza walidacji domeny.
- Napisy intranetu w `src/content/intranet.json`. Treść ma zakładki `PL` i `EN`.
- Kod zaproszenia widać raz, w dialogu.

## Poza zakresem

- Drugi klient intranetu, osobny obraz i osobna domena.
- Role inne niż `owner` w intranecie (redaktor, recenzent).
- Własne statystyki ruchu. Dane o ruchu są w Grafanie z [docs/CICD/09-grafana.md](../../CICD/09-grafana.md).
- Edycja na telefonie. Ekrany są responsywne, ale klient React Native intranetu nie ma.
- Edytor treści, podgląd, kolejność lekcji, import i CV — [02-edytor.md](02-edytor.md).

## Źródła

- [React Router: lazy loading](https://reactrouter.com/start/declarative/routing) i [React `lazy`](https://react.dev/reference/react/lazy) — chunk ładowany przy wejściu na trasę.
- [OWASP: Unvalidated Redirects and Forwards](https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html) — walidacja `next`.
- [Vite: build manifest](https://vite.dev/guide/backend-integration) — `manifest.json` z importami chunków.
- [shadcn/ui: Data Table](https://ui.shadcn.com/docs/components/data-table) — tabela na `table`.

## Gotowe gdy

- `/intranet` dla ownera pokazuje pulpit, dla studenta prowadzi na `/pl`, dla gościa na login z `next`.
- Po zalogowaniu z `next=/intranet/cv` owner jest na edycji CV, a `next=//evil.example` prowadzi na `/`.
- Każda sekcja z drzewa ma listę i formularz, a zapisy idą z `If-Match`.
- Kod zaproszenia pojawia się raz i nie zostaje w `localStorage`.
- `scripts/check-chunks.mjs` przechodzi: wejście publiczne nie ładuje CodeMirror.
- `pnpm test:ci` i `pnpm build` kończą się kodem 0.
