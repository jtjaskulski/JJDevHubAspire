# Frontend

Ten plik jest mapą folderu. Mówi, które ekrany istnieją, skąd biorą wygląd, jak działa język i w jakiej kolejności czytać numery `01`–`08`. Kroki wdrożenia są w numerach. Ten plik nie zastępuje żadnego z nich.

Poprzedniego numeru w tym folderze nie ma: czytanie frontendu zaczyna się tutaj. Następny plik to [01-motyw.md](01-motyw.md). W kolejności pracy całego repozytorium ten folder stoi po domknięciu piramidy w [22-testy.md](../api/22-testy.md). Maszyna z [08-proxmox.md](../cicd/08-proxmox.md) już stoi. Po [08-ruch.md](08-ruch.md) obraz weba i telefonu wjeżdża jobem z [16-deploy.md](../cicd/16-deploy.md).

Web stoi w `src/clients/web`. Telefon stoi w `src/clients/mobile`. Wspólne liczby wyglądu stoją w `src/clients/shared/theme`. Wspólne klucze napisów interfejsu stoją w `src/clients/shared/i18n`. Treść CV, kursu i notatki nie leży w tych plikach. Przychodzi z API przez bramę.

## Mapa ekranów

Jedna mapa obowiązuje web. Telefon ma osobne ekrany i te same nazwy rzeczy. Adres webu jest kontraktem: późniejszy numer nie dokłada ścieżki, której nie ma w tabeli, i nie zmienia znaczenia wiersza.

Język publiczny jest pierwszym segmentem: `pl` albo `en`. `/login`, `/register` i `/intranet/*` tego segmentu nie mają. Zły język i nieznany adres wracają na `/pl`.

### Strona publiczna

| Adres | Ekran | Kto wchodzi | Skąd treść |
| --- | --- | --- | --- |
| `/` | przekierowanie na `/pl` | każdy | — |
| `/:lang` | home: skrót CV i ostatnie notatki | każdy | Cv i News przez bramę |
| `/:lang/cv` | publiczne CV | każdy | Cv |
| `/:lang/technologies/:slug` | technologia i jej kursy | każdy | Learning |
| `/:lang/courses` | lista kursów | każdy | Learning, z filtrem widoczności |
| `/:lang/courses/:slug` | spis lekcji kursu | każdy | Learning |
| `/:lang/courses/:slug/:lesson` | lekcja | wg widoczności | Learning, HTML przez jeden komponent |
| `/:lang/notes` | lista notatek | każdy | News |
| `/:lang/notes/:slug` | notatka | wg widoczności | News, HTML przez jeden komponent |
| `/:lang/contact` | formularz rekrutera | każdy, bez konta | zapis do Contact, zawsze zapytanie rekrutera |

Home nie jest osobnym dokumentem w bazie. Składa skrót publicznego CV i kilka ostatnich notatek, które API oddało dla bieżącego języka. Nagłówek strony jest jeden, w treści home, nie w belce.

CV czyta projekcję publiczną. Umiejętność prowadzi do `/:lang/technologies/:slug` slugiem technologii. Slug w adresie jest slugiem z API. Klient nie składa adresu z identyfikatora bazy.

Lista kursów pokazuje to, co brama oddała. Pusta lista jest stanem ekranu, z napisem z klucza `empty.list`. Błąd odczytu jest osobnym stanem, z kluczem `error.load`. Nieznany slug kursu, przy dobrym języku, zostaje w tym języku i pokazuje `error.notFound`. Zły język nie wchodzi w tę regułę: najpierw leci na `/pl`.

Lekcja oznaczona jako widoczna tylko dla studentów znika dla gościa jako brak treści (`404` z API), nie jako zablokowany podgląd tytułu. Notatka działa tak samo.

Formularz na `/:lang/contact` jest jedynym publicznym formularzem kontaktu. Wysłanie tworzy zapytanie rekrutera. Formularz nie pyta o rolę i nie ma przełącznika „jestem studentem”.

### Logowanie i rejestracja

| Adres | Ekran | Kto |
| --- | --- | --- |
| `/login` | logowanie | gość |
| `/register` | rejestracja z kodem zaproszenia | gość |

Oba adresy są rodzeństwem drzewa publicznego, zadeklarowanym przed `/:lang`. Inaczej segment `login` wpadłby w bramkę języka i wrócił na `/pl`.

Zalogowany, który wejdzie na `/login` albo `/register`, schodzi z tych adresów. Cel bierze się z parametru `next`, gdy `next` jest ścieżką tej aplikacji. W pozostałych przypadkach celem jest `/pl`.

Pole kodu zaproszenia jest na rejestracji. Wydawanie kodu jest sprawą Identity, opisaną przy [17-identity.md](../api/17-identity.md). Ten folder nie dokłada do rejestracji drugiej roli.

### Strefa studenta

| Adres | Ekran | Kto |
| --- | --- | --- |
| `/:lang/student/contact` | formularz studenta | rola `student` |

Adres ma prefiks języka, bo nie jest na liście wyjątków. Wyjątki to tylko login, rejestracja i intranet.

Gość idzie na `/login` z `next` wskazującym na ten formularz. Zalogowany bez roli `student` wraca na `/pl`. Wysłanie tworzy zapytanie studenta. Ten sam formularz na stronie publicznej nie istnieje.

Na lekcji zalogowany student może oznaczyć lekcję jako przeczytaną. To polecenie idzie przez bramę do Learning. Nie jest edycją treści i nie wchodzi do intranetu.

### Intranet

Intranet jest w tym samym kliencie web. Osobnej aplikacji intranetu nie ma. Trasy są leniwe i wpuszczają tylko rolę `owner`.

| Adres | Ekran |
| --- | --- |
| `/intranet` | pulpit: wejścia do czterech obszarów |
| `/intranet/cv` | edytor CV |
| `/intranet/news` | lista notatek i edytor notatki |
| `/intranet/news/:id` | jedna notatka |
| `/intranet/courses` | lista kursów |
| `/intranet/courses/:id` | kurs, lekcje, kolejność |
| `/intranet/courses/:id/lessons/:lessonId` | lekcja |
| `/intranet/contact/students` | skrzynka zapytań studentów |
| `/intranet/contact/recruiters` | skrzynka zapytań rekruterów |

Cztery obszary pulpitu to CV, notatki, kursy i kontakt. Kontakt na pulpicie rozdziela się na dwie skrzynki. Jedna lista na dwa rodzaje zapytań nie wchodzi.

Zapis edytora CV, notatki i kursu wysyła `If-Match`. Szczegóły są w [04-intranet.md](04-intranet.md).

### Telefon

Telefon nie kopiuje adresów webu. Ma własne ekrany i te same klucze napisów.

| Ekran | Odpowiednik |
| --- | --- |
| `HomeScreen` | `/:lang` |
| `CvScreen` | `/:lang/cv` |
| `TechnologyScreen` | `/:lang/technologies/:slug` |
| `CoursesScreen` | `/:lang/courses` |
| `CourseScreen` | `/:lang/courses/:slug` |
| `LessonScreen` | lekcja |
| `NotesScreen` | `/:lang/notes` |
| `NoteScreen` | `/:lang/notes/:slug` |
| `StudentContactScreen` | formularz studenta |
| `LoginScreen`, `RegisterScreen` | `/login`, `/register` |
| `AboutScreen` | stopka webu: wersja klienta i `GET /versions` |
| `StudentInboxScreen` | skrzynka studentów, tylko `owner` |
| `RecruiterInboxScreen` | skrzynka rekruterów, tylko `owner` |

Formularz rekrutera zostaje na stronie publicznej. Na telefonie jest formularz studenta. Edytory CV, notatek i kursów zostają w intranecie webu. Skrzynki na telefonie otwierają się z powiadomienia, gdy właściciel jest zalogowany. Opis kanałów jest w [07-powiadomienia.md](07-powiadomienia.md).

## Wspólny wygląd

Wygląd obu klientów wychodzi z jednego obiektu w `src/clients/shared/theme/tokens.ts`. W obiekcie są kolory, odstępy, promienie, skala pisma i czasy. Paleta jasna ma tło `#f3efe6`, atrament `#1a1814` i akcent `#9a3412`. Krój nazywa się Inter.

Tailwind na webie i NativeWind na telefonie nazywają te liczby klasami. Drugiej palety w komponencie, w klasie arbitralnej i w konfiguracji stylu nie ma. Heks koloru stoi w `tokens.ts`.

Web składa HTML5 w JSX. Klasy Tailwinda siedzą na tych elementach. Wejście CSS webu jest jedno: `src/clients/web/src/styles.css`. Nowy plik `*.scss` nie powstaje. shadcn/ui jest zestawem komponentów w repozytorium, na tym samym HTML, nie obok niego.

Telefon ma osobne ekrany. Liczby klas są te same: `bg-canvas`, `text-ink`, `bg-accent`, `p-5`, `rounded-card`. Ruch webu idzie przez Motion (`motion/react`). Ruch telefonu idzie przez Reanimated. Czas obu pochodzi z `tokens.duration`.

## Język

Na start są dwie kultury: `pl` i `en`. Klucze chromu są wspólne dla webu i telefonu. Chrom to napis interfejsu: belka, przycisk, pusty stan, błąd odczytu, etykieta pola. Treść lekcji, notatki i CV jest mapą kultur z API i do tych plików nie wchodzi.

Pliki kluczy:

| Plik | Rola |
| --- | --- |
| `src/clients/shared/i18n/pl.json` | napisy po polsku |
| `src/clients/shared/i18n/en.json` | napisy po angielsku |
| `src/clients/shared/i18n/locale.ts` | `resolveLocale`: nieznany kod wraca jako `pl` |

Każdy klucz z tabeli poniżej jest w obu plikach. Dopisanie klucza w jednym pliku bez drugiego jest błędem testu z [02-web.md](02-web.md).

| Klucz | Gdzie widać |
| --- | --- |
| `nav.home` | belka, home |
| `nav.cv` | belka, CV |
| `nav.courses` | belka, kursy |
| `nav.notes` | belka, notatki |
| `nav.contact` | belka, formularz rekrutera na webie |
| `nav.login` | wejście do logowania |
| `nav.register` | wejście do rejestracji |
| `nav.logout` | wylogowanie |
| `nav.intranet` | link właściciela do `/intranet` |
| `nav.about` | wejście do ekranu O aplikacji na telefonie |
| `lang.pl` | przełącznik, polski |
| `lang.en` | przełącznik, angielski |
| `footer.versionLabel` | podpis przy numerze klienta |
| `version.identity` | wiersz Identity |
| `version.news` | wiersz News |
| `version.learning` | wiersz Learning |
| `version.cv` | wiersz Cv |
| `version.contact` | wiersz Contact |
| `version.gateway` | wiersz bramy |
| `version.missing` | brak numeru usługi w odpowiedzi |
| `auth.email` | pole e-mail |
| `auth.password` | pole hasła |
| `auth.invite` | kod zaproszenia |
| `auth.submitLogin` | przycisk logowania |
| `auth.submitRegister` | przycisk rejestracji |
| `auth.error` | błąd logowania, gdy API nie podało tytułu |
| `contact.name` | imię na formularzu kontaktu |
| `contact.email` | e-mail na formularzu kontaktu |
| `contact.message` | treść wiadomości |
| `contact.submit` | wyślij |
| `contact.recruiter.title` | nagłówek formularza publicznego |
| `contact.recruiter.success` | potwierdzenie zapytania rekrutera |
| `contact.student.title` | nagłówek formularza studenta |
| `contact.student.success` | potwierdzenie zapytania studenta |
| `contact.student.forbidden` | brak roli `student` |
| `inbox.students.title` | skrzynka studentów |
| `inbox.recruiters.title` | skrzynka rekruterów |
| `inbox.empty` | pusta skrzynka |
| `about.title` | ekran O aplikacji |
| `empty.list` | pusta lista |
| `error.load` | błąd odczytu |
| `error.notFound` | brak treści |
| `visibility.public` | plakietka widoczności |
| `visibility.students` | plakietka widoczności |
| `visibility.private` | plakietka widoczności |
| `editor.save` | zapisz w intranecie |
| `editor.conflict` | konflikt `412` |
| `editor.reload` | wczytaj wersję z serwera |
| `lesson.complete` | oznacz lekcję jako przeczytaną |

Przełącznik na stronie publicznej podmienia pierwszy segment (`pl` ↔ `en`) i zostawia resztę ścieżki, query oraz hash. Na `/login`, `/register` i `/intranet/*` adresu nie rusza. Język chromu na tych adresach jest ostatnim wyborem ze strony publicznej. Brak wyboru oznacza `pl`.

`resolveLocale` jest jedyną funkcją, która zamienia dowolny kod na `pl` albo `en`. Web używa jej w bramce adresu. Telefon używa jej przy starcie, gdy czyta język urządzenia. Nieznany język urządzenia daje `pl`, tak jak zły segment daje `/pl`.

`Accept-Language` wychodzący do bramy jest tym samym kodem, którego używa chrom. Dzięki temu tytuł w `ProblemDetails` jest w języku ekranu. Kod błędu w polu `type` zostaje stabilny i klient może na nim rozgałęzić logikę.

## Wersja na ekranie

Komponenty wersjonowane, które klient pokazuje, to `web` i `mobile` oraz sześć nazw z `GET /versions`: `identity`, `news`, `learning`, `cv`, `contact`, `gateway`. Zasada tagu jest w [07-wersje.md](../cicd/07-wersje.md). Kształt odpowiedzi jest w dokumencie OpenAPI bramy z [16-gateway.md](../api/16-gateway.md).

Stopka webu pokazuje napis `web-vX.Y.Z`. Napis jest wbity w paczkę przy buildzie komponentu `web`. Ekran O aplikacji na telefonie pokazuje `mobile-vX.Y.Z`, wbity tak samo dla komponentu `mobile`.

Pod napisem klienta oba ekrany wołają `GET /versions` na bramie i układają sześć wierszy w stałej kolejności: identity, news, learning, cv, contact, gateway. Brakującej nazwy nie pomijają po cichu: wiersz dostaje `version.missing`. Siódmej usługi klient nie dopisuje.

## Kolejność plików

Jeden numer na jedno podejście. Numer nie powtarza uzasadnienia sąsiada. Plan numeru mówi, co zrobić. Uzasadnienie zostaje w `## Dlaczego ta technologia`.

| Plik | Co powstaje | Czego ten plik nie powtarza |
| --- | --- | --- |
| [01-motyw.md](01-motyw.md) | `tokens.ts`: kolory, odstępy, promienie, pismo, czasy | instalacji Tailwinda i NativeWind |
| [02-web.md](02-web.md) | React, trasy, przełącznik języka, shell, stopka `web-vX.Y.Z` | klas wyglądu i klienta OpenAPI dla treści |
| [03-wyglad.md](03-wyglad.md) | Tailwind v4, shadcn, jeden `styles.css` | drugiej palety i biblioteki ruchu |
| [04-intranet.md](04-intranet.md) | trasy `owner`, edytory, dwie skrzynki, `If-Match` | formularza publicznego i pusha |
| [05-tresc.md](05-tresc.md) | klient OpenAPI, HTML z API, oba formularze kontaktu | edytora intranetu i ekranów telefonu |
| [06-mobile.md](06-mobile.md) | React Native, te same liczby i klucze, ekran O aplikacji | edytorów webu i kanałów push |
| [07-powiadomienia.md](07-powiadomienia.md) | dwa kanały, rejestracja tokenu urządzenia przy zalogowaniu właściciela, skasowanie przy wylogowaniu | drugiego systemu wyglądu |
| [08-ruch.md](08-ruch.md) | Motion na webie, Reanimated na telefonie, czasy z tokenów | nowych czasów wpisanych w komponencie |

Numery czyta się po kolei. `01` jest przed Tailwindem i przed NativeWind, bo oba tylko mapują gotowe liczby. `03` zakłada HTML z `02`. `04` zakłada strażnika i trasy z `02` oraz klienta z `05` tam, gdzie zapis już idzie typami. Przy wdrożeniu jednego numeru sąsiad zostaje nietknięty: `04` nie przebudowuje motywu, `08` nie przebudowuje formularzy.

## Pakiety

Pakiet wolno dodać, gdy licencja jest otwarta i darmowa także produkcyjnie: MIT, Apache 2.0, BSD, PostgreSQL. Wersję przypina lockfile przy instalacji. Numer, który pakiet wprowadza, nie przypina starej wersji po to, żeby zmienić licencję.

| Pakiet | Licencja | Numer | Rola |
| --- | --- | --- | --- |
| `react`, `react-dom` | MIT | `02` | komponenty webu |
| `react-router` | MIT | `02` | trasy webu |
| `vite`, `@vitejs/plugin-react` | MIT | `02` | dev i build webu |
| `typescript` | Apache-2.0 | `02` | typy |
| `vitest`, `jsdom` | MIT | `02` | runner testów widoku |
| `@testing-library/react`, `@testing-library/user-event`, `@testing-library/jest-dom` | MIT | `02` | to, co widzi użytkownik |
| `tailwindcss`, `@tailwindcss/vite` | MIT | `03` | klasy webu |
| `@fontsource-variable/inter` | MIT | `03` | plik kroju Inter na webie |
| `openapi-fetch` | MIT | `05` | wywołania o typie ścieżki |
| `openapi-typescript` | MIT | `05` | moduł typów z dokumentu OpenAPI |
| `@tanstack/react-query` | MIT | `05` | cache odczytu i mutacje |
| `dompurify` | Apache-2.0 albo MPL-2.0 | `05` | drugie czyszczenie HTML; bierzemy Apache-2.0 |
| `react-native` | MIT | `06` | ekrany telefonu |
| `nativewind` | MIT | `06` | klasy telefonu z tych samych liczb |
| `@react-native-firebase/messaging` | Apache-2.0 | `07` | token urządzenia FCM |
| `motion` | MIT | `08` | ruch webu, import z `motion/react` |
| `react-native-reanimated` | MIT | `08` | ruch telefonu |

Komponenty shadcn są źródłem w `src/clients/web/src/components/ui`, na licencji MIT, bez zależności uruchomieniowej od rejestru. Telefon nie importuje tego katalogu.

Menedżer pakietów webu i telefonu to pnpm. Drugiego lockfile’a w kliencie nie ma.

## Słownik

Nazwy poniżej są stałe. Numer nie wymyśla drugiej nazwy na ten sam byt.

| Nazwa | Znaczenie |
| --- | --- |
| `tokens` | obiekt z `src/clients/shared/theme/tokens.ts` |
| chrom | napisy interfejsu z `pl.json` i `en.json` |
| `resolveLocale` | jedyna funkcja kodu języka na `pl` albo `en` |
| `Shell` | belka, przełącznik, `main`, stopka webu |
| `LangGate` | wpuszcza tylko `pl` i `en` |
| `GuestRoute` | login i rejestracja dla gościa |
| `OwnerRoute` | intranet dla roli `owner` |
| `StudentRoute` | formularz studenta dla roli `student` |
| `TrustedHtml` | jedyne miejsce, w którym HTML z API wchodzi do DOM |
| `web-vX.Y.Z` | wersja webu wbita przy buildzie |
| `mobile-vX.Y.Z` | wersja telefonu wbita przy buildzie |
| `useVersions` | odczyt `GET /versions` |
| skrzynka studentów | lista `StudentInquiry` |
| skrzynka rekruterów | lista `RecruiterInquiry` |
| brama | YARP, jedyny adres HTTP klientów |

## Zasady

- Jeden komponent na plik, eksport nazwany, funkcja. Klasa komponentu i `React.FC` nie wchodzą.
- Hooki idą w kolejności: stan, refy, własne hooki, efekty. Wartość wyliczona ze stanu nie dostaje własnego efektu ani drugiego stanu.
- W kodzie ekranów nie ma `any`.
- Test webu sprawdza tekst, rolę i stan, które widzi użytkownik.
- Żądanie HTTP idzie na bramę. Port usługi w kliencie nie występuje.
- Strona nie woła `fetch` sama i nie deklaruje ręcznie kształtu odpowiedzi. Robi to klient z [05-tresc.md](05-tresc.md).
- `dangerouslySetInnerHTML` występuje raz, w `TrustedHtml`.
- Zapis właściciela, który dostał `ETag`, wysyła `If-Match`.
- Heks palety występuje w `tokens.ts`. Klasa arbitralna z heksem jest błędem.
- Nowy plik `*.scss` nie powstaje. Drugie wejście CSS obok `styles.css` nie powstaje.

## Testy

Test webu to Vitest i Testing Library, w `src/clients/web`. Test mówi, co jest prawdą, gdy przechodzi, i ma jeden powód do padnięcia. Nazwa jest w stylu `footer_shows_baked_web_version`.

Liczby motywu sprawdza osobny test przy `tokens.ts`, zanim powstanie runner webu. Opis jest w [01-motyw.md](01-motyw.md).

Telefon sprawdza ekran O aplikacji tak, jak web sprawdza stopkę: widać `mobile-vX.Y.Z` i sześć nazw usług. Logika rejestracji powiadomienia jest czystą funkcją i ma test Vitest bez emulatora. Opis jest w [06-mobile.md](06-mobile.md) i [07-powiadomienia.md](07-powiadomienia.md).

```bash
cd src/clients/web
pnpm exec vitest run
```

## Poza zakresem

- Usługi, brama i kształt `GET /versions` — [16-gateway.md](../api/16-gateway.md) i numery usług.
- Tag komponentu i reguła podbijania wersji — [07-wersje.md](../cicd/07-wersje.md).
- Maszyna już stoi — [08-proxmox.md](../cicd/08-proxmox.md). Obraz weba wjeżdża jobem z [16-deploy.md](../cicd/16-deploy.md).
- Osobna aplikacja intranetu, drugi klient tylko do edycji.
- Druga paleta, tryb ciemny jako osobny zestaw heksów w komponencie, Tamagui.
- GSAP, Lenis i wspólny silnik ruchu webu i telefonu.
- Sass i pliki `*.scss`.
- Formularz publiczny, który tworzy zapytanie studenta.
- Push, gdy na telefonie nikt nie jest zalogowany jako `owner`, i push przy zalogowanym studencie.

## Źródła

- [React](https://react.dev/) — komponenty funkcyjne i HTML w JSX.
- [Vite](https://vite.dev/guide/) — dev i build webu.
- [Tailwind CSS v4 theme](https://tailwindcss.com/docs/theme) — `@theme` jako mapa zmiennych.
- [shadcn/ui](https://ui.shadcn.com/docs) — komponenty kopiowane do repozytorium.
- [Motion](https://motion.dev/docs/react) — import z `motion/react`.
- [NativeWind](https://www.nativewind.dev/) — klasy na React Native.
- [Reanimated](https://docs.swmansion.com/react-native-reanimated/) — ruch telefonu.
- [openapi-fetch](https://openapi-ts.dev/openapi-fetch/) — klient o typie ścieżki.
- [TanStack Query](https://tanstack.com/query/latest) — cache i mutacje.
- [Trusted Types](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) — jedyna droga HTML do DOM.
- [If-Match](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Match) — zapis wersji, którą klient przeczytał.
- [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/migrate-v1) — wysyłka, którą wykonuje Contact, nie klient.

## Gotowe gdy

- Tabela adresów webu zgadza się z drzewem, które opisuje [02-web.md](02-web.md).
- Klucze chromu z tego pliku są kompletne w obu kulturach i żaden numer nie dokłada drugiej nazwy na ten sam napis.
- Paleta, Inter i zakaz drugiej palety zgadzają się z [01-motyw.md](01-motyw.md).
- Stopka webu i ekran O aplikacji pokazują wersję swojego komponentu oraz sześć nazw z `GET /versions`.
- Kolejność `01`–`08` jest kompletna. Po `08` nie stawia się maszyny. Obraz wjeżdża jobem z [16-deploy.md](../cicd/16-deploy.md).
- `find docs/frontend -name '*.md' | sort` pokazuje ten plik i osiem numerów.
