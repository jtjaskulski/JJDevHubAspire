# Treść

Ten numer podpina strony pod API. Typy biorą się z dokumentów OpenAPI. Wywołanie idzie przez `openapi-fetch` i bramę. Cache i mutacje trzyma TanStack Query. Strona nie woła `fetch` i nie deklaruje ręcznie kształtu odpowiedzi. HTML notatki i lekcji wchodzi do DOM w jednym komponencie, `TrustedHtml`. Formularz publiczny tworzy zapytanie rekrutera. Formularz studenta wymaga roli `student` i tworzy zapytanie studenta.

Poprzedni numer to [04-intranet.md](04-intranet.md). Następny to [06-mobile.md](06-mobile.md). Mapa adresów zostaje ta z [README.md](README.md) i [02-web.md](02-web.md).

Odczyt `GET /versions`, który stopka zaczęła w numerze `02`, wchodzi w ten sam klient jako `useVersions`. Tekst stopki się nie zmienia.

## Po co

Treść CV, kursu i notatki żyje w usługach. Zmiana akapitu nie jest nowym obrazem webu. Klient ma pokazać to, co brama oddała dla bieżącego języka i dla roli w tokenie, i ma przestać kompilować się, gdy kontrakt JSON się zmieni.

Dwa formularze kontaktu wyglądają podobnie i znaczą co innego. Publiczny zawsze tworzy `RecruiterInquiry`, także wtedy, gdy wysyła go zalogowany student. Formularz w strefie studenta tworzy `StudentInquiry` i bez roli `student` w ogóle nie jest formularzem. Pomylenie tych zapisów wrzuciłoby wiadomość studenta do skrzynki rekruterów albo odwrotnie.

HTML z usługi jest już złożony i oczyszczony po stronie API. Klient i tak wstawia go przez `dangerouslySetInnerHTML`, więc to miejsce ma być jedno. Drugie przypisanie do `innerHTML` w komponencie strony omija politykę, którą przeglądarka ma wymusić.

## Dlaczego ta technologia

### Typy z dokumentu OpenAPI

`openapi-typescript` czyta dokument OpenAPI usługi i zapisuje moduł typów w `src/clients/web/src/api/schema`. `openapi-fetch` bierze ten moduł i sprawdza ścieżkę, parametry oraz odpowiedź przy kompilacji. Dokument leży w repozytorium obok usługi, która go wydaje. Klient nie utrzymuje drugiej, ręcznej kopii DTO w pliku strony.

Ręczny `type Note = { title: string }` w `NotePage.tsx` przegrywa, bo pole dojdzie w C# i strona dalej się skompiluje, a na ekranie zniknie dane. NSwag, Kiota i orval przegrywają objętością własnych klas klienta przy tej samej gwarancji ścieżki: tu wystarcza typ i cienkie `fetch`. Wspólny typ „dowolny JSON” przegrywa, bo wyłącza bramkę, po którą ten numer istnieje.

Koszt: zmiana kontraktu wymaga świeżego dokumentu i świeżego modułu typów w tym samym zmianie. Build pada, gdy rozjadą się ze sobą. To jest zamierzone. Lockfile przypina `openapi-typescript` jako zależność deweloperską i `openapi-fetch` jako zależność uruchomieniową. Obie na MIT.

Strona może użyć typu, który zwraca hook. Nie deklaruje własnego interfejsu odpowiedzi. Hook zwraca dane o typie z modułu `schema`.

### TanStack Query

Hook w `src/clients/web/src/api/queries` woła klienta i trzyma wynik w `QueryClient`. Strona woła hook. Dwa komponenty o tym samym kluczu dzielą jedno żądanie. Odejście ze strony anuluje żądanie sygnałem. Mutacja po sukcesie unieważnia klucz odczytu, który pokazuje ten dokument.

`useEffect` z `fetch` w stronie przegrywa, bo łatwo o wyścig, o brak anulowania i o drugi stan „dane”, który da się wyliczyć z wyniku hooka. SWR przegrywa tam, gdzie mutacja zapisu i unieważnienie listy mają iść jednym modelem; odczyt publiczny dałby się na nim złożyć, a intranetowy zapis i tak zostałby obok. RTK Query przegrywa, bo wciąga magazyn, którego klient nie ma. Loader routera jako jedyne miejsce danych przegrywa, bo drzewo z numeru `02` jest deklaratywne, a cache między stopką i stroną i tak jest potrzebny poza przejściem trasy.

Koszt: trzeba nazwać klucze. Fabryka `queryKeys` jest jedna. Ręczny napis `['note', slug]` w stronie rozjedzie się z unieważnieniem po zapisie. Strona nie woła `useQuery` wprost, jeśli hook w `queries` już spina klucz i klienta. Dzięki temu klucz nie rozłazi się po plikach stron.

`QueryClient` powstaje raz, nad drzewem, w `main.tsx`. Drugi klient na stronie intranetu nie powstaje.

### Jeden komponent na HTML z API

`TrustedHtml` jest jedynym plikiem, w którym występuje `dangerouslySetInnerHTML`. Dostaje napis HTML z API, przepuszcza go przez DOMPurify i, gdy przeglądarka ma Trusted Types, przez politykę `jjdevhub`. React 19 przyjmuje `TrustedHTML` w `__html`. Przeglądarka bez Trusted Types i tak dostaje wynik DOMPurify.

Polityka Trusted Types w nagłówku CSP sprawia, że inne przypisanie do `innerHTML` przeglądarka odrzuca. Nagłówek ustawia host, który serwuje web. Brak nagłówka nie wyłącza DOMPurify w komponencie.

Drugi komponent „podgląd” z własnym `dangerouslySetInnerHTML` przegrywa, bo polityka ma jedno przejście. `markdown-it` albo `marked` w przeglądarce przegrywają, bo złożą inny HTML niż usługa i ominą jej sanitację. Wstawienie odpowiedzi jako tekstu w `pre` przegrywa dla lekcji, bo wtedy nie ma nagłówków i list, które usługa już złożyła. Zostawienie surowego HTML od autora w odpowiedzi przegrywa po stronie API i tu nie wraca: klient i tak czyści drugi raz.

Koszt: lista dozwolonych znaczników jest krótka i wspólna. `script`, `style`, `iframe` i atrybuty zdarzeń odpadają. Link wewnętrzny, który wskazuje na adres tej aplikacji, przechodzi przez router przy kliknięciu, w tym samym komponencie, bez drugiej wstawki HTML.

Dozwolone znaczniki: `p`, `h2`, `h3`, `ul`, `ol`, `li`, `a`, `code`, `pre`, `strong`, `em`, `blockquote`. Atrybut `href` na `a` zostaje po oczyszczeniu. `target` nie otwiera obcego okna bez `rel`. DOMPurify jest brany na licencji Apache-2.0.

Podgląd w intranecie woła ten sam komponent. Nie ma drugiej polityki.

### Formularz publiczny zawsze tworzy zapytanie rekrutera

`RecruiterContactPage` na `/:lang/contact` wysyła mutację utworzenia `RecruiterInquiry`. Nie wysyła mutacji studenta. Nie czyta roli. Zalogowany student na tym adresie i tak tworzy zapytanie rekrutera. Gość też.

Jedno pole „kim jesteś” przegrywa, bo publiczny adres przestałby być jednoznaczny, a skrzynka rekruterów dostałaby wpis studenta. Wspólna mutacja z parametrem typu przegrywa, bo łatwo podać zły typ z przeglądarki; osobne operacje w OpenAPI trzymają to rozdzielenie, a klient publiczny ma podpiętą tylko operację rekrutera.

Koszt: dwa formularze są podobne wizualnie i mają osobne hooki. Wspólne mogą być pola `contact.name`, `contact.email`, `contact.message` i przycisk `contact.submit`. Tytuł i komunikat sukcesu są osobne: `contact.recruiter.title`, `contact.recruiter.success`.

Błąd walidacji pokazuje `title` z `ProblemDetails`. Rozgałęzienie, gdy jest potrzebne, idzie po polu `type`, nie po porównaniu zdania.

### Formularz studenta wymaga roli

`StudentContactPage` stoi pod `StudentRoute`. Gość idzie na `/login` z `next` wskazującym na `/:lang/student/contact`. Zalogowany bez roli `student` wraca na `/pl` i widzi, zanim zejdzie, nie musi, ale jeśli trasa zdąży namalować odmowę, tekst to `contact.student.forbidden`. Po zejściu na `/pl` formularza nie ma.

Mutacja to utworzenie `StudentInquiry`. Hook nie jest importowany przez `RecruiterContactPage`.

Ukrycie przycisku przy tej samej mutacji co formularz publiczny przegrywa, bo jedno żądanie znów miesza skrzynki. Wysłanie zapytania studenta bez tokenu „dla wygody” przegrywa, bo usługa i tak odpowie odmową, a ekran wyglądałby jak zepsuty formularz publiczny.

Koszt: student musi być zalogowany. To jest ten sam token, którego używa oznaczenie lekcji jako przeczytanej. Oznaczenie lekcji jest osobną mutacją Learning, na `LessonPage`, widoczną gdy rola to `student`. Nie tworzy zapytania Contact.

Telefon użyje tych samych dwóch operacji: studenckiej na swoim ekranie, rekrutera nie ma na telefonie. Opis ekranu jest w [06-mobile.md](06-mobile.md).

### Ruch tylko przez bramę

Baza klienta to origin bramy. W dev przeglądarka zostaje na `localhost:4200`, a proxy z numeru `02` przekazuje ścieżki na bramę. W kodzie nie ma hosta Identity, News, Learning, Cv ani Contact.

`Accept-Language` ustawia middleware klienta na kod chromu, `pl` albo `en`. Token dostępu, gdy jest, dokleja ten sam middleware. Strona nie składa nagłówków sama.

Wołanie usługi po jej porcie z Vite przegrywa, bo omija bramę, która sprawdza JWT i wystawia `GET /versions`. Osobny klient HTTP na każdą usługę, z innym originem, przegrywa tak samo. Typy mogą pochodzić z kilku dokumentów OpenAPI, po jednym na usługę. Wywołanie i tak idzie na jeden origin bramy, ścieżką, którą dokument opisuje jako ścieżkę publiczną.

Koszt: gdy brama nie wystawi ścieżki, ekran dostaje błąd, nawet jeśli usługa na swoim porcie żyje. To jest poprawny wynik. Klient nie ma awaryjnego adresu.

`loadVersions` z numeru `02` schodzi ze stopki. `Footer` woła `useVersions`. Kolejność wierszy zostaje.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/web/src/api/schema/*.ts` | typy z OpenAPI, bez ręcznej edycji |
| `src/clients/web/scripts/write-api-types.mjs` | woła `openapi-typescript` na dokumenty z repozytorium |
| `src/clients/web/src/api/client.ts` | `openapi-fetch`, origin bramy, `Accept-Language`, token |
| `src/clients/web/src/api/query-client.ts` | jeden `QueryClient` |
| `src/clients/web/src/api/query-keys.ts` | fabryka kluczy |
| `src/clients/web/src/api/queries/use-cv.ts` | publiczne CV |
| `src/clients/web/src/api/queries/use-notes.ts` | lista i jedna notatka |
| `src/clients/web/src/api/queries/use-courses.ts` | lista, kurs, lekcja, technologia |
| `src/clients/web/src/api/queries/use-versions.ts` | `GET /versions` |
| `src/clients/web/src/api/queries/use-me.ts` | bieżące role |
| `src/clients/web/src/api/queries/use-recruiter-inquiry.ts` | mutacja publiczna |
| `src/clients/web/src/api/queries/use-student-inquiry.ts` | mutacja studenta |
| `src/clients/web/src/api/queries/use-lesson-progress.ts` | oznaczenie lekcji |
| `src/clients/web/src/content/TrustedHtml.tsx` | jedyny `dangerouslySetInnerHTML` |
| `src/clients/web/src/content/sanitize.ts` | DOMPurify i polityka `jjdevhub` |
| `src/clients/web/src/pages/contact/RecruiterContactPage.tsx` | formularz publiczny |
| `src/clients/web/src/pages/student/StudentContactPage.tsx` | formularz studenta |

Hooki intranetu (zapis CV, notatki, kursu, listy skrzynek, podgląd) mieszkają obok, w `src/api/queries/intranet/`, i też nie są wołane przez `fetch` w stronie. Doklejenie `If-Match` zostaje w `useSaveWithMatch` z numeru `04`, które woła te mutacje.

Klucze, które fabryka wystawia i których strona nie składa ręcznie:

| Funkcja | Kiedy unieważnić |
| --- | --- |
| `queryKeys.cv(locale)` | zapis CV |
| `queryKeys.notes(locale)` | zapis notatki |
| `queryKeys.note(locale, slug)` | zapis tej notatki |
| `queryKeys.courses(locale)` | zapis kursu |
| `queryKeys.course(locale, slug)` | zapis kursu i lekcji |
| `queryKeys.lesson(locale, course, lesson)` | zapis lekcji |
| `queryKeys.technology(locale, slug)` | zapis technologii powiązanej z kursem |
| `queryKeys.versions()` | nie unieważnia się zapisem treści; odświeżenie przy wejściu na stopkę |
| `queryKeys.me()` | po logowaniu i wylogowaniu |
| `queryKeys.studentInbox()` | po zmianie statusu pozycji, jeśli zapis dojdzie |
| `queryKeys.recruiterInbox()` | tak samo dla drugiej skrzynki |

## Plan

### 1. Moduł typów

Dodaj `openapi-fetch` i `@tanstack/react-query`. Jako zależność deweloperską dodaj `openapi-typescript` i DOMPurify w zależnościach uruchomieniowych. Skrypt `write-api-types.mjs` czyta dokumenty OpenAPI z repozytorium i zapisuje `src/api/schema`. Plików w `schema` nie edytuj ręcznie. Skrypt `build` odpala to przed `tsc`, albo osobny skrypt `api:check` porównuje wynik z tym, co jest w gicie, i pada przy różnicy.

### 2. Klient bramy

`client.ts` tworzy klienta na pustej bazie URL (ten sam origin) albo na bazie ze zmiennej bez sekretu, jeśli dev tak wymaga. Middleware ustawia `Accept-Language` z bieżącego locale chromu i nagłówek tokenu, gdy token jest. Przy `401` czyści token i unieważnia `queryKeys.me()`.

Nie dodawaj drugiego klienta z hostem usługi.

### 3. Hooki stron

Podłącz `HomePage`, `CvPage`, `TechnologyPage`, `CoursesPage`, `CoursePage`, `LessonPage`, `NotesPage`, `NotePage` do hooków. Stan ładowania i błąd są wczesnym `return` z `error.load`. Brak danych po `404` to `error.notFound`. Pusta lista to `empty.list`.

`NotePage` i `LessonPage` podają pole HTML do `TrustedHtml`. Nie składają treści w JSX przez `innerHTML`.

`Footer` przechodzi na `useVersions`. Usuń bezpośrednie `fetch` z `load-versions.ts`, gdy hook oddaje te same sześć wierszy.

### 4. Formularze

`RecruiterContactPage` woła tylko mutację rekrutera. Po sukcesie widać `contact.recruiter.success` i formularz nie wysyła drugi raz bez nowej treści.

`StudentContactPage` woła tylko mutację studenta, za `StudentRoute`. Po sukcesie widać `contact.student.success`.

`LessonPage` pokazuje przycisk `lesson.complete`, gdy `useMe` ma rolę `student`. Mutacja to postęp w Learning. Gość przycisku nie widzi.

### 5. TrustedHtml

Zaimplementuj `sanitize.ts`: DOMPurify z listą znaczników z tego numeru, potem polityka Trusted Types o nazwie `jjdevhub`, gdy `window.trustedTypes` istnieje. `TrustedHtml` wstawia wynik. Test z `<script>` nie znajduje tego znacznika w dokumencie. Test z `<p>` znajduje tekst akapitu.

Przeszukać drzewo:

```bash
rg -n "dangerouslySetInnerHTML" src/clients
```

Jedno trafienie, w `TrustedHtml.tsx`.

### Co jest do czego

- `schema` — kontrakt odpowiedzi. Woła go `client.ts`. Strona go nie importuje po to, żeby napisać własny podzbiór pól.
- `client.ts` — jedyne `fetch` warstwy danych. Dokleja język i token. Celuje w bramę.
- `query-keys.ts` — nazwy cache. Mutacja intranetu unieważnia stąd, nie z literału w stronie.
- `useVersions` — lista dla stopki i, na telefonie, dla ekranu O aplikacji. Ten sam kształt sześciu nazw.
- `useMe` — role dla `OwnerRoute`, `StudentRoute` i przycisku lekcji. Woła go shell i strażnicy.
- `use-recruiter-inquiry` — wyłącznie formularz publiczny.
- `use-student-inquiry` — wyłącznie formularz studenta.
- `TrustedHtml` — jedyna droga HTML do DOM. Wołają go lekcja, notatka i podgląd intranetu.
- `sanitize.ts` — DOMPurify i polityka. Komponent nie czyści drugim sposobem „tylko dla podglądu”.

## Testy

Vitest i Testing Library. Stub `fetch` albo stub klienta rozróżnia operację rekrutera i operację studenta. Każdy fakt ma jeden powód do padnięcia.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `note_shows_sanitized_paragraph` | HTML `<p>Lekcja</p><script>` | render notatki | widać `Lekcja`, brak `script` |
| `only_one_unsafe_html_sink` | drzewo `src/clients` | `rg` | jedno `dangerouslySetInnerHTML` |
| `public_form_creates_recruiter_inquiry` | gość na `/pl/contact` | wysłanie | wołana operacja rekrutera, nie studenta |
| `logged_in_student_on_public_form_stays_recruiter` | rola `student` na `/pl/contact` | wysłanie | operacja rekrutera |
| `student_form_requires_role` | gość na `/pl/student/contact` | render | ścieżka logowania |
| `student_form_creates_student_inquiry` | rola `student` | wysłanie | operacja studenta, nie rekrutera |
| `owner_without_student_role_misses_student_form` | rola `owner` | wejście na formularz studenta | brak formularza, ścieżka `/pl` |
| `page_does_not_declare_response_type` | pliki `pages` | przegląd | brak ręcznego typu odpowiedzi; asercja skryptem na `export type` ciała API w `pages` |
| `footer_uses_versions_hook` | stub `GET /versions` | render stopki | sześć nazw, brak prywatnego `fetch` w `Footer.tsx` |
| `lesson_complete_visible_for_student` | rola `student` | lekcja | widać `lesson.complete` |
| `accept_language_follows_locale` | locale `en` | odczyt notatki | nagłówek `Accept-Language` to `en` |

```bash
cd src/clients/web
pnpm exec vitest run
rg -n "dangerouslySetInnerHTML" src/clients
```

Drugie polecenie ma jedno trafienie.

## Zasady

- Strona woła hook z `api/queries`. Nie woła `fetch` i nie woła `useEffect` po to, żeby pobrać dane.
- Plik strony nie deklaruje ręcznie typu odpowiedzi API.
- Typy w `schema` pochodzą ze skryptu i z dokumentów OpenAPI. Ręczna edycja schematu rozjedzie się z `api:check`.
- Origin HTTP to brama. Host usługi w kliencie nie występuje.
- `dangerouslySetInnerHTML` występuje tylko w `TrustedHtml.tsx`.
- HTML z API przechodzi przez DOMPurify. Polityka Trusted Types nazywa się `jjdevhub`.
- Formularz na `/:lang/contact` tworzy wyłącznie zapytanie rekrutera.
- Formularz na `/:lang/student/contact` istnieje dla roli `student` i tworzy wyłącznie zapytanie studenta.
- `Accept-Language` jest kodem chromu.
- Klucze cache pochodzą z `queryKeys`.
- Jest jeden `QueryClient` na aplikację.
- Błąd pokazuje `title` z `ProblemDetails`, a gałąź logiczna patrzy na `type`.

## Poza zakresem

- Edytor, `If-Match` i dwie skrzynki jako ekrany — [04-intranet.md](04-intranet.md). Ten numer daje im hooki.
- Wygląd pól — [03-wyglad.md](03-wyglad.md).
- Ekrany telefonu, które wołają te same operacje — [06-mobile.md](06-mobile.md).
- Push — [07-powiadomienia.md](07-powiadomienia.md).
- Kody błędów i `ETag` po stronie usługi — [11-walidacja.md](../api/11-walidacja.md).
- Kształt `GET /versions` — [16-gateway.md](../api/16-gateway.md).
- Dwa agregaty Contact — [21-kontakt.md](../api/21-kontakt.md).
- Renderer Markdown w przeglądarce i drugi komponent z `innerHTML`.

## Źródła

- [openapi-fetch](https://openapi-ts.dev/openapi-fetch/) — wywołanie o typie ścieżki.
- [openapi-typescript](https://openapi-ts.dev/openapi-typescript/) — moduł typów z dokumentu.
- [TanStack Query](https://tanstack.com/query/latest/docs/framework/react/overview) — klucz, anulowanie, unieważnienie.
- [DOMPurify](https://github.com/cure53/DOMPurify) — czyszczenie HTML; licencja Apache-2.0 jest na liście dozwolonych.
- [Trusted Types](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) — przeglądarka odrzuca inne `innerHTML`.
- [React: dangerouslySetInnerHTML](https://react.dev/reference/react-dom/components/common#dangerously-setting-the-inner-html) — jedno miejsce, wartość po oczyszczeniu.
- [Accept-Language](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Accept-Language) — język tytułu błędu.
- [Contact](../api/21-kontakt.md) — `StudentInquiry` i `RecruiterInquiry`.

## Gotowe gdy

- Strona notatki pokazuje tekst z HTML API i nie pokazuje `script`.
- W `src/clients` jest jedno `dangerouslySetInnerHTML`.
- Formularz publiczny, także dla zalogowanego studenta, woła operację rekrutera.
- Formularz studenta bez roli `student` nie wysyła zapytania studenta.
- Stopka bierze sześć nazw z `useVersions`.
- Pliki stron nie zawierają ręcznego typu odpowiedzi.
- `cd src/clients/web && pnpm exec vitest run` kończy się kodem 0.
- `rg -n "dangerouslySetInnerHTML" src/clients` wypisuje jedną linię, w `TrustedHtml.tsx`.
