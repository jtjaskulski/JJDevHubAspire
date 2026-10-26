# Web

Ten numer stawia klienta przeglądarki: React 19, Vite, TypeScript, pnpm, drzewo tras, przełącznik języka, shell i stopkę z wersją `web-vX.Y.Z`. HTML stron jest HTML5 w JSX. Klasy wyglądu dokłada [03-wyglad.md](03-wyglad.md). Treść z API dokłada [05-tresc.md](05-tresc.md). Liczby kolorów są już w [01-motyw.md](01-motyw.md).

Poprzedni numer to [01-motyw.md](01-motyw.md). Następny to [03-wyglad.md](03-wyglad.md). Mapa adresów, której ten numer nie zmienia, jest w [README.md](README.md).

Katalog docelowy to `src/clients/web`. Pakiet motywu jest zależnością `file:../shared/theme`. Pakiet napisów, który ten numer zakłada, to `src/clients/shared/i18n`.

## Po co

Bez drzewa tras język, intranet i formularze nie mają adresu. Mapa z `README.md` zostaje umową na papierze, a zły język nie ma dokąd wrócić. Ten numer spina umowę z `BrowserRouter`.

Właściciel i czytelnik mają widzieć, który obraz webu odpowiada za ekran. Stopka pokazuje `web-vX.Y.Z` wbite przy buildzie komponentu `web`. Obok leży lista usług z `GET /versions`, w kolejności z mapy: identity, news, learning, cv, contact, gateway. Sama lista usług bez numeru klienta nie mówi, który bundle jest otwarty. Sam numer klienta bez listy nie mówi, która usługa oddała treść.

Przełącznik języka ma zmienić kulturę bez gubienia strony. Na CV, kursie i notatce podmienia pierwszy segment i zostawia resztę. Na logowaniu, rejestracji i intranecie adresu nie rusza, bo te drzewa prefiksu nie mają.

Shell jest jeden na całe drzewo. Belka, `main` i stopka nie powstają osobno na każdej stronie. Strona dokłada jeden `h1` i swoją treść.

## Dlaczego ta technologia

### React 19 jako funkcje

Komponent jest funkcją z eksportem nazwanym. Jeden komponent na plik, nazwa pliku równa nazwie funkcji. Plik czyta się od góry: typ propsów, stałe, funkcje czyste, komponent. W komponencie: stan, refy, własne hooki, efekty, wartości wyliczone, handlery, `return`. JSX zostaje układem. Filtr, mapowanie i warunek stoją nad `return`.

Klasa komponentu przegrywa, bo stan i cykl życia rozchodzą się po metodach, a test widoku i tak klika w tekst. `React.FC` przegrywa, bo dokleja dzieci i typ children tam, gdzie props ich nie ma. Jeden plik z kilkoma ekranami przegrywa, bo zmiana stopki rusza wtedy plik tras.

Koszt: drobny widok to osobny plik. `Footer`, `LangSwitch` i `Shell` nie mieszkają razem. Wspólna logika, użyta dwa razy, wychodzi do funkcji albo hooka, nie do trzeciego kopii w JSX.

`useEffect` dotyka świata poza Reactem i zwraca sprzątanie. Wartość, którą da się policzyć ze stanu albo propsów, jest stałą w renderze. Efekt, który tylko przepisuje props do stanu, nie powstaje. W kodzie ekranów nie ma `any`. Asercja `as` i wykrzyknik przy wartości nie wchodzą do plików stron.

Pusto, błąd i brak danych wracają wcześniej, zanim JSX złoży listę. W JSX zostaje jeden poziom warunku.

### Vite, TypeScript i pnpm

Vite podaje dev i build. TypeScript jest bramką typów przed paczką. pnpm jest menedżerem: jeden lockfile klienta web. Plugin Reacta podpina odświeżanie przy edycji.

Webpack jako drugi bundler przegrywa, bo dev i tak ma iść przez Vite, a dwa narzędzia buildu dają dwa zestawy aliasów. npm i Yarn obok pnpm przegrywają, bo lockfile ma być jeden. Babel jako osobny kompilator obok pluginu Vite przegrywa, bo TypeScript i tak sprawdza typy, a JSX obsługuje plugin.

Koszt: konfiguracja aliasu `@` i aliasu motywu żyje w `vite.config.ts` i w `tsconfig.json` naraz. Rozjazd tych dwóch plików widać dopiero przy teście albo przy buildzie, więc oba wchodzą w komendę „gotowe”.

Dev słucha na porcie `4200`. Przeglądarka woła ten sam origin. Proxy Vite wysyła `/versions` i ścieżki API na bramę z adresu w środowisku, nie na port usługi. W kodzie klienta nie ma `localhost` z portem Identity, News, Learning, Cv ani Contact.

`engines` wymaga Node 22, tej linii, na której test motywu uruchamia `node:test`. Build to sprawdzenie typów i `vite build`. Napis wersji powstaje przed tym buildem.

### Język w pierwszym segmencie

Dozwolone kultury na start to `pl` i `en`. `/` oraz każdy nieznany adres idą na `/pl` przez `Navigate` z `replace`. `LangGate` czyta pierwszy segment. `resolveLocale` z `src/clients/shared/i18n/locale.ts` zamienia nieznany kod na `pl`. Bramka i telefon wołają tę samą funkcję.

Tłumaczenie tylko w stanie Reacta, bez segmentu w adresie, przegrywa, bo link do notatki nie niósłby języka, a odświeżenie wracałoby do `pl`. Osobna domena na język przegrywa, bo produkt ma jedną bramę i jeden bundle. Więcej niż dwa segmenty kultur na start przegrywa, bo API i pliki chromu mają `pl` i `en`. Nowa kultura dojdzie jako dane: trzeci plik kluczy i dopisek do listy dozwolonych, nie przebudowa tras.

Koszt: każdy publiczny link niesie język. Helper `pathForLocale` jest jedynym miejscem, które składa ten prefiks. Ręczny napis `` `/${lang}/cv` `` w komponencie rozjedzie się z helperem przy pierwszym wyjątku.

Na `/login`, `/register` i `/intranet/*` przełącznik nie zmienia ścieżki. Język chromu bierze z ostatniego wyboru na stronie publicznej. Brak zapisu oznacza `pl`. Zapis leży w `localStorage` pod kluczem `jjdevhub.locale` i przyjmuje tylko `pl` albo `en`. Inna wartość jest ignorowana, a `resolveLocale` i tak zwróci `pl`.

### Trasy poza prefiksem

Kolejność w `App` jest częścią kontraktu. Najpierw `/` na `/pl`. Potem `/login` i `/register` w `GuestRoute`. Potem `/intranet/*` w `OwnerRoute`. Potem `/:lang` w `LangGate`. Na końcu `*` na `/pl`.

Gdyby intranet stał pod `/:lang`, segment `intranet` nie przeszedłby bramki języka. Gdyby `*` stało przed `/login`, logowanie nigdy by nie powstało. Deklaracja dziecka z ukośnikiem na początku urwałaby je od rodzica `/:lang`, dlatego dzieci języka mają ścieżki względne.

Osobna aplikacja na intranet przegrywa, bo byłby drugi bundle, drugi login i druga kopia shellu dla jednej osoby. Trzymanie intranetu pod `/pl/intranet` przegrywa, bo mapa mówi, że to drzewo jest poza prefiksem, a przełącznik nie ma tam pierwszego segmentu do podmiany.

Koszt: strażnik `OwnerRoute` i lazy dochodzą w [04-intranet.md](04-intranet.md). Ten numer zostawia miejsce w drzewie: ścieżka `/intranet/*` jest zarejestrowana i bez roli wraca na `/pl` albo na login. Pełne edytory nie wchodzą do tego numeru, żeby chunk właściciela nie powstał, zanim jest co w nim trzymać. Placeholder pulpitu może być pusty `main` z jednym nagłówkiem z klucza, byle adres istniał i nie wpadł w `*`.

`StudentRoute` dla `/:lang/student/contact` też jest w drzewie. Sam formularz i jego mutacja są w [05-tresc.md](05-tresc.md). Ten numer wpuszcza rolę albo odsyła: gość na login z `next`, inna rola na `/pl`.

`safeNext` przyjmuje ścieżkę, która zaczyna się od `/`, nie zaczyna się od `//` i nie zawiera `://`. Inna wartość daje `/pl`. Dzięki temu parametr po logowaniu nie wynosi przeglądarki poza aplikację.

### Wersja wbita przy buildzie

Stopka pokazuje dwa piętra. Pierwsze to napis `web-vX.Y.Z` z modułu `web-version.ts`. Drugie to sześć wierszy z `GET /versions`.

Napis klienta powstaje skryptem przed `vite build`. Skrypt czyta numer komponentu `web` tak, jak opisuje go [07-wersje.md](../cicd/07-wersje.md), i zapisuje `export const webVersion = "web-vX.Y.Z"`. Build pada, gdy napis nie pasuje do `^web-v\d+\.\d+\.\d+$`. W repozytorium zostaje plik z wartością deweloperską `web-v0.0.0`, którą skrypt nadpisuje na buildzie wydania. Test stopki podmienia moduł i nie zależy od tagu na dysku.

Pobranie numeru webu z `GET /versions` przegrywa, bo brama zwraca numery usług i swój numer, a bundle webu może stać obok, na innym tagu. Wpisywanie wersji ręcznie w stopce przegrywa, bo rozjedzie się z tagiem komponentu. Trzymanie wersji tylko w `package.json` przeglądarkowego pakietu przegrywa, gdy tag komponentu i pole `version` paczki npm nie są tym samym krokiem. Źródłem napisu jest numer komponentu z ciągu wydań, a skrypt jest tym, który wkłada go do bundla.

Koszt: lokalny `pnpm dev` pokazuje `web-v0.0.0`, dopóki skrypt nie dostanie numeru wydania. To jest widoczne i nie udaje tagu. Wydanie bez przejścia skryptu nie powstaje, bo build wersji jest częścią `pnpm build`.

Lista usług woła bramę. W tym numerze funkcja `loadVersions` mieszka przy stopce i czyta `GET /versions`. [05-tresc.md](05-tresc.md) przenosi to wywołanie do klienta OpenAPI jako `useVersions`. Tekst stopki zostaje ten sam: podpis, napis klienta, sześć wierszy w stałej kolejności. Brak nazwy w odpowiedzi daje `version.missing`, nie znikający wiersz.

### HTML5 w JSX

Shell renderuje `header`, w nim `nav`, potem `main` z `Outlet`, potem `footer`. Strona renderuje jeden `h1`. Lista jest `ul` albo `ol`. Formularz jest `form`, przycisk jest `button`, pole ma `label`. Link wewnętrzny jest `Link` z routera i w DOM zostaje kotwicą.

Klikalny `div` przegrywa, bo klawiatura i nazwa dostępna nie biorą się z samego handlera. Nagłówek strony w belce przegrywa, bo każda podstrona miałaby ten sam `h1`, a swój tytuł schowany w `div`. Osobny komponent „typografia”, który maluje `div` z rolą nagłówka, przegrywa, bo HTML już ma `h1`–`h4`.

Koszt: wygląd z numeru `03` dokłada klasy na te elementy, a nie zastępuje ich. Zmiana belki na `div` z rolą `banner` byłaby krokiem wstecz i test shellu ma szukać roli `banner`, którą daje sam `header`, oraz roli `navigation`.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/web/package.json` | pnpm, skrypty `dev`, `build`, `test` |
| `src/clients/web/vite.config.ts` | port `4200`, proxy do bramy, alias `@` i `@jjdevhub/theme` |
| `src/clients/web/tsconfig.json` | te same aliasy, `strict` |
| `src/clients/web/scripts/write-version.mjs` | zapis `web-version.ts` przed buildem |
| `src/clients/web/src/main.tsx` | `BrowserRouter`, język dokumentu |
| `src/clients/web/src/app/App.tsx` | drzewo `Routes` |
| `src/clients/web/src/app/Shell.tsx` | `header`, `nav`, `main`, `footer` |
| `src/clients/web/src/app/LangGate.tsx` | tylko `pl` i `en` |
| `src/clients/web/src/app/LangSwitch.tsx` | podmiana segmentu albo sam chrom |
| `src/clients/web/src/app/GuestRoute.tsx` | login i rejestracja dla gościa |
| `src/clients/web/src/app/OwnerRoute.tsx` | miejsce na intranet; pełny strażnik w numerze `04` |
| `src/clients/web/src/app/StudentRoute.tsx` | rola `student` |
| `src/clients/web/src/app/safe-next.ts` | walidacja `next` |
| `src/clients/web/src/app/locale-storage.ts` | klucz `jjdevhub.locale` |
| `src/clients/web/src/app/paths.ts` | `pathForLocale`, `localeFromPathname` |
| `src/clients/web/src/app/Footer.tsx` | `web-vX.Y.Z` i sześć wierszy |
| `src/clients/web/src/app/web-version.ts` | `export const webVersion` |
| `src/clients/web/src/app/load-versions.ts` | `GET /versions` na bramie, do czasu hooka z numeru `05` |
| `src/clients/shared/i18n/pl.json` | klucze z mapy |
| `src/clients/shared/i18n/en.json` | ten sam zbiór kluczy |
| `src/clients/shared/i18n/locale.ts` | `resolveLocale` |
| `src/clients/shared/i18n/translate.ts` | `chrome(locale, key)` |
| `src/clients/web/src/pages/home/HomePage.tsx` | indeks `/:lang` |
| `src/clients/web/src/pages/cv/CvPage.tsx` | `cv` |
| `src/clients/web/src/pages/technologies/TechnologyPage.tsx` | `technologies/:slug` |
| `src/clients/web/src/pages/courses/CoursesPage.tsx` | lista |
| `src/clients/web/src/pages/courses/CoursePage.tsx` | `courses/:slug` |
| `src/clients/web/src/pages/courses/LessonPage.tsx` | `courses/:slug/:lesson` |
| `src/clients/web/src/pages/notes/NotesPage.tsx` | lista |
| `src/clients/web/src/pages/notes/NotePage.tsx` | `notes/:slug` |
| `src/clients/web/src/pages/contact/RecruiterContactPage.tsx` | `contact` |
| `src/clients/web/src/pages/student/StudentContactPage.tsx` | `student/contact` |
| `src/clients/web/src/pages/login/LoginPage.tsx` | `/login` |
| `src/clients/web/src/pages/register/RegisterPage.tsx` | `/register` |

Strony treści w tym numerze renderują shellowy układ i stany pusty oraz błąd z kluczy chromu. Podpięcie odczytu API jest w numerze `05`. Test tego numeru sprawdza adres, język i stopkę, nie kształt notatki.

Drzewo, które ma utrzymać `App`:

```text
/                          → /pl
/login                     LoginPage w GuestRoute
/register                  RegisterPage w GuestRoute
/intranet/*                OwnerRoute
/:lang                     LangGate, tylko pl i en
  index                    HomePage
  cv                       CvPage
  technologies/:slug       TechnologyPage
  courses                  CoursesPage
  courses/:slug            CoursePage
  courses/:slug/:lesson    LessonPage
  notes                    NotesPage
  notes/:slug              NotePage
  contact                  RecruiterContactPage
  student/contact          StudentContactPage w StudentRoute
*                          → /pl
```

## Plan

### 1. Pakiet i runner

W `src/clients/web` ustaw pnpm, React 19, `react-dom`, `react-router`, Vite, TypeScript, Vitest, jsdom i Testing Library. Dopisz zależność `file:../shared/theme`. `engines.node` ustaw na `>=22.13.0`.

Skrypty: `dev` to Vite na porcie `4200`, `test` to `vitest run`, `build` to skrypt wersji, potem `tsc -p tsconfig.json --noEmit`, potem `vite build`. Proxy kieruje `/versions` i prefiks API na adres bramy ze zmiennej środowiska. W repozytorium nie zapisuj wartości tej zmiennej, jeśli zawiera sekret. Adres bramy deweloperskiej bez sekretu może stać w przykładzie środowiska, obok nazwy zmiennej.

### 2. Napisy

Załóż `src/clients/shared/i18n`. `pl.json` i `en.json` mają dokładnie klucze z tabeli w [README.md](README.md). `translate.ts` eksportuje `chrome(locale, key)`. Brak klucza w typie nie kompiluje się: typ klucza jest sumą kluczy polskiego pliku. `locale.ts` eksportuje `resolveLocale`. Nieznany kod, pusty napis i `*` dają `pl`.

### 3. Trasy

Złóż `App` według drzewa z sekcji ścieżek. `LangGate` woła `resolveLocale` i przy niezgodności segmentu z wynikiem robi `Navigate` na `/pl` z `replace`, gdy segmentu nie ma na liście `pl` i `en`. Dla `pl` i `en` renderuje `Outlet` w `Shell`.

`LangSwitch` na ścieżce z prefiksem woła `pathForLocale` i zachowuje query oraz hash. Na `/login`, `/register` i ścieżce zaczynającej się od `/intranet` zapisuje locale i nie woła nawigacji. `document.documentElement.lang` ustawia na bieżący kod chromu.

`safeNext` zaimplementuj według reguły z sekcji tras. `GuestRoute` po wejściu osoby zalogowanej idzie na `safeNext` albo na `/pl`.

### 4. Stopka

`Footer` pokazuje `footer.versionLabel`, wartość `webVersion` i sześć wierszy. Etykiety wierszy to `version.identity`, `version.news`, `version.learning`, `version.cv`, `version.contact`, `version.gateway`, w tej kolejności. `loadVersions` woła `GET /versions` na tym samym originie. Brak pola daje tekst `version.missing`. Błąd sieci daje `error.load` raz, pod listą, a napis `webVersion` zostaje.

`write-version.mjs` pisze `web-version.ts`. Gdy nie dostanie numeru wydania, zapisuje `web-v0.0.0`. Gdy dostanie numer, który po złożeniu nie pasuje do wzorca `web-vX.Y.Z`, kończy proces kodem innym niż 0.

### 5. Strony-zaślepki

Każda strona z tabeli ma jeden `h1` albo stan `empty.list` / `error.notFound` tam, gdzie numer `05` podepnie dane. W tym numerze `h1` może być kluczem chromu (`nav.cv`, `contact.recruiter.title`, `contact.student.title`). Strona nie woła `fetch` po treść notatki. Wyjątkiem numeru jest `loadVersions` przy stopce, do czasu hooka z numeru `05`.

`LoginPage` i `RegisterPage` renderują pola z kluczy `auth.*`. `RegisterPage` ma pole `auth.invite`. Wysyłka do Identity dochodzi razem z klientem w numerze `05`; ten numer trzyma formularz i adres.

### Co jest do czego

- `App` — jedyne drzewo adresów. Test tras renderuje `App`, nie osobny router na stronie.
- `Shell` — rama każdej strony języka. `LoginPage` i intranet mogą dostać tę samą ramę, skoro prefiksu nie mają, ale stopka z wersją zostaje widoczna.
- `LangGate` — odcina zły segment, zanim powstanie strona.
- `LangSwitch` — jedyne miejsce, które zmienia język. Link w treści nie podmienia segmentu na własną rękę.
- `pathForLocale` — składa adres publiczny. Komponent nie skleja prefiksu stringiem.
- `resolveLocale` — wspólne z telefonem. Web nie ma drugiej funkcji „czy to polski”.
- `safeNext` — cel po logowaniu. Wołają je `GuestRoute` i później `OwnerRoute`.
- `Footer` — wersja bundle’a i wersje usług. Woła go `Shell`.
- `webVersion` — napis wbity przy buildzie. Stopka go czyta. Test go podmienia.
- `loadVersions` — odczyt bramy dla stopki, dopóki numer `05` nie poda `useVersions`.
- `chrome` — napis z klucza. Komponent strony nie wstawia polskiego zdania na sztywno, poza testem, który sprawdza konkretną kulturę.

## Testy

Vitest, jsdom, Testing Library. Test szuka roli i nazwy, nie klasy CSS. Każdy fakt ma jeden powód do padnięcia.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `root_redirects_to_pl` | wejście na `/` | render `App` | ścieżka `/pl` |
| `unknown_lang_redirects_to_pl` | wejście na `/de/cv` | render | ścieżka `/pl` |
| `star_redirects_to_pl` | wejście na `/nie-ma` | render | ścieżka `/pl` |
| `switch_keeps_the_rest_of_the_path` | `/pl/courses/slug` | wybór `lang.en` | ścieżka `/en/courses/slug` |
| `switch_on_login_keeps_the_path` | `/login` | wybór `lang.en` | ścieżka zostaje `/login` |
| `switch_on_intranet_keeps_the_path` | `/intranet/cv` | wybór `lang.en` | ścieżka zostaje `/intranet/cv` |
| `chrome_keys_match` | oba pliki JSON | porównanie kluczy | zbiory równe i równe tabeli z `README` |
| `footer_shows_baked_web_version` | mock `webVersion` = `web-v1.2.3` | render `Footer` | widać `web-v1.2.3` |
| `footer_lists_six_services` | stub `GET /versions` z sześcioma nazwami | render `Footer` | sześć etykiet w kolejności mapy |
| `footer_marks_missing_service` | stub bez `news` | render `Footer` | wiersz news ma `version.missing` |
| `shell_has_one_main_and_nav` | `/pl` | render | jedna rola `navigation`, jedna `main` |
| `page_has_one_h1` | `/pl/cv` | render | jeden `h1` |
| `unsafe_next_falls_back_to_pl` | `next=//evil.example` | wynik `safeNext` | `/pl` |

```bash
cd src/clients/web
pnpm exec vitest run
```

Test stopki nie łączy się z prawdziwą bramą. Stubuje odpowiedź. Test przekierowania nie sprawdza koloru belki.

## Zasady

- Jeden komponent na plik, eksport nazwany, funkcja. Bez klasy i bez `React.FC`.
- Kolejność hooków: stan, refy, własne hooki, efekty. Potem wartości wyliczone i handlery.
- Efekt nie przepisuje propsów do stanu. Zależności efektu są kompletne.
- W plikach stron i `app` nie ma `any`.
- JSX to układ. Wczesny `return` obsługuje pustkę, błąd i brak danych.
- Adres publiczny składa `pathForLocale`. Dozwolone segmenty języka to `pl` i `en`.
- `/login`, `/register` i `/intranet/*` stoją w drzewie przed `/:lang`.
- `next` przechodzi przez `safeNext`.
- Stopka pokazuje `webVersion` także wtedy, gdy `GET /versions` się nie uda.
- Proxy deweloperskie celuje w bramę. Port usługi w `vite.config.ts` nie występuje.
- Strona tego numeru nie pobiera treści notatki, kursu ani CV. To numer `05`.
- Elementy to HTML5: `header`, `nav`, `main`, `footer`, jeden `h1` na stronę, `form`, `label`, `button`.

## Poza zakresem

- Klasy, Tailwind, shadcn i jedyny plik CSS — [03-wyglad.md](03-wyglad.md).
- Edytory, dwie skrzynki i `If-Match` — [04-intranet.md](04-intranet.md).
- Klient OpenAPI, `TrustedHtml`, oba formularze jako zapis — [05-tresc.md](05-tresc.md).
- Telefon i `mobile-vX.Y.Z` — [06-mobile.md](06-mobile.md).
- Ruch belki i masztu — [08-ruch.md](08-ruch.md).
- Reguła tagu `web-vX.Y.Z` — [07-wersje.md](../cicd/07-wersje.md).
- Kształt JSON `GET /versions` — [16-gateway.md](../api/16-gateway.md). Ekran i tak pokazuje sześć nazw w stałej kolejności.
- Wydawanie kodu zaproszenia — [17-identity.md](../api/17-identity.md). Rejestracja tylko zbiera pole.

## Źródła

- [React: rules of components](https://react.dev/reference/rules) — funkcja, hooki na górze, ta sama kolejność wywołań.
- [React: You Might Not Need an Effect](https://react.dev/learn/you-might-not-need-an-effect) — wartość wyliczona zostaje w renderze.
- [React Router](https://reactrouter.com/start/declarative/routing) — deklaratywne drzewo `Routes`.
- [Vite: server proxy](https://vite.dev/config/server-options.html) — przeglądarka zostaje na jednym originie, cel to brama.
- [Testing Library](https://testing-library.com/docs/queries/about/) — rola i nazwa, nie klasa.
- [HTML sections](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/header) — `header`, `nav`, `main`, `footer`.
- [Numbered component versions](../cicd/07-wersje.md) — skąd skrypt bierze numer komponentu `web`.

## Gotowe gdy

- Wejście na `/` i na `/de` kończy się na `/pl`.
- Przełącznik na `/pl/courses/slug` daje `/en/courses/slug`, a na `/login` i `/intranet/cv` ścieżki nie zmienia.
- `pl.json` i `en.json` mają ten sam zbiór kluczy, zgodny z mapą.
- Stopka pokazuje napis `web-vX.Y.Z` z modułu wersji i sześć nazw usług.
- Shell ma `header`, `nav`, `main` i `footer`. Strona ma jeden `h1`.
- `cd src/clients/web && pnpm exec vitest run` kończy się kodem 0.
- `pnpm build` pada, gdy napis wersji nie pasuje do `web-vX.Y.Z`, i przechodzi dla `web-v0.0.0` oraz dla poprawnego tagu.
- Tag `web-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job podmienia tylko Deployment `web` i zostawia stopkę z tym tagiem.
