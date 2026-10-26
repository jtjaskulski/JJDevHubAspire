# Telefon

Ten numer stawia klienta React Native. Ekrany są osobne od webu. Liczby wyglądu są te same, z [01-motyw.md](01-motyw.md), przez NativeWind. Klucze chromu są te same, z [02-web.md](02-web.md) i z tabeli w [README.md](README.md). Ekran O aplikacji pokazuje `mobile-vX.Y.Z` wbite przy buildzie i sześć nazw z `GET /versions`.

Poprzedni numer to [05-tresc.md](05-tresc.md). Następny to [07-powiadomienia.md](07-powiadomienia.md).

Katalog docelowy to `src/clients/mobile`. Zależność motywu to `file:../shared/theme`. Zależność napisów to pakiet `src/clients/shared/i18n`. Webowego `styles.css` telefon nie importuje.

## Po co

Ta sama treść ma wejść na telefon bez wspólnego JSX z przeglądarką. Wspólny komponent `div` nie ma odpowiednika w React Native. Wspólne mają być liczby, klucze napisów i operacje bramy: CV, kurs, lekcja, notatka, formularz studenta, wersje usług.

Właściciel na telefonie ma zobaczyć, który obraz aplikacji trzyma w ręce. Ekran O aplikacji jest odpowiednikiem stopki webu. Napis `mobile-vX.Y.Z` nie pochodzi z `GET /versions`. Pochodzi z buildu komponentu `mobile`, tak jak `web-vX.Y.Z` pochodzi z buildu webu. Lista pod napisem jest tą samą szóstką: identity, news, learning, cv, contact, gateway.

Język urządzenia bywa inny niż `pl` i `en`. `resolveLocale` zwraca wtedy `pl`, tak jak zły segment webu wraca na `/pl`. Przełącznik na telefonie zmienia kulturę chromu bez adresu, bo adresu z segmentem tu nie ma.

## Dlaczego ta technologia

### Osobne ekrany

Ekran telefonu jest funkcją w osobnym pliku, z eksportem nazwanym. Nie importuje strony z `src/clients/web`. Nie renderuje `div`, `header` ani `main`. Renderuje widoki React Native: kontener, tekst, lista, pole, przycisk platformy opakowany tak, żeby dało się go nacisnąć.

Wspólna biblioteka UI dla webu i telefonu przegrywa, bo związałaby oba klienty jednym zestawem elementów. Tamagui i podobne warstwy przegrywają z tego samego powodu i dokładają własną skalę, obok `tokens`. Udostępnianie ekranu webu w WebView przegrywa, bo telefon przestałby być osobnym klientem, a wersja `mobile-vX.Y.Z` udawałaby bundle webu.

Koszt: lista kursów powstaje dwa razy, raz w JSX webu, raz na telefonie. Hook danych może być współdzielony tylko tam, gdzie nie ciągnie DOM. W tym numerze telefon ma własne wywołania przez bramę, o typach z tego samego dokumentu OpenAPI. Plik strony webu nie jest importowany.

Nawigacja telefonu jest stosem i zakładkami, nie `react-router`. Adresy z mapy webu nie są tu ścieżkami. Nazwy ekranów z tabeli w `README.md` są kontraktem.

### NativeWind i te same liczby

NativeWind nazywa klasy tak samo jak web: `bg-canvas`, `text-ink`, `bg-accent`, `text-surface`, `p-5`, `gap-5`, `rounded-card`, `rounded-pill`, `text-body`, `text-small`. Wartości pochodzą z `cssCustomProperties()` nałożonych na korzeń przez `vars` NativeWind, oraz z mapy `@theme inline` w wejściu CSS telefonu. Heks w tym CSS nie występuje. Blok mapy ma ten sam kształt co w [03-wyglad.md](03-wyglad.md): `var(--…)` i resety, bez kopiowania tabeli pikseli.

Własna paleta w `tailwind.config` telefonu przegrywa, bo byłaby drugą paletą. Inline style z `'#9a3412'` przegrywa tak samo. Klasy webowe skopiowane „na oko” z innymi liczbami przegrywają, bo `p-5` przestałby znaczyć dwadzieścia cztery piksele.

Koszt: wejście CSS telefonu powtarza nazwy zmiennych z webu. Powtórzenie nazw jest mapą, nie drugą wartością. Gdy numer `01` dostanie nowy klucz, dopisujesz jedną linię tutaj i jedną w `styles.css` webu. Test telefonu nie porównuje heksów na nowo: test motywu już je trzyma. Ten numer sprawdza, że w katalogu telefonu heksa nie ma.

Krój Inter jest zarejestrowany pod nazwą `tokens.font.family`. Inna rodzina, systemowa albo „podobna”, nie wchodzi jako zamiennik napisu `Inter`. Plik kroju leży w pakiecie telefonu i ładuje się przy starcie, zanim pierwszy ekran się namaluje.

Korzeń:

```tsx
import { cssCustomProperties } from '@jjdevhub/theme';
import { vars } from 'nativewind';

const themeVars = vars(cssCustomProperties());

export function ThemeRoot({ children }: { children: React.ReactNode }) {
  return <View style={themeVars}>{children}</View>;
}
```

`ThemeRoot` jest jeden, nad nawigacją. Ekran nie woła `cssCustomProperties()` sam.

### Te same klucze chromu

Telefon importuje `chrome` i `resolveLocale` z `src/clients/shared/i18n`. Nie ma `pl.mobile.json`. Dopisanie klucza tylko w kliencie telefonu jest błędem: typ klucza pochodzi ze wspólnego pliku, a test z numeru `02` pilnuje, że `pl` i `en` mają ten sam zbiór.

Przełącznik używa `lang.pl` i `lang.en`. Zapis wyboru zostaje na urządzeniu, pod tą samą regułą: tylko `pl` albo `en`. Przy starcie kod urządzenia idzie przez `resolveLocale`. `Accept-Language` wychodzący do bramy jest tym kodem.

Osobny słownik „krótszych” napisów na telefon przegrywa, bo belka i błąd rozjadą się z webem przy pierwszej poprawce zdania. Tłumaczenie na sztywno w `Text` przegrywa, bo omija test kluczy.

Koszt: napis zaprojektowany pod szeroką belkę webu bywa długi na wąskim ekranie. Skrócenie jest zmianą wartości w obu plikach JSON, nie nowym kluczem `nav.home.short`, dopóki mapa kluczy w `README` tego klucza nie ma. Nowy klucz dopisuje się najpierw w mapie, potem w obu kulturach.

### Ekran O aplikacji

`AboutScreen` pokazuje `about.title`, potem `mobile-vX.Y.Z` z modułu `mobile-version.ts`, potem sześć wierszy. Etykiety wierszy to te same klucze `version.*` co stopka webu. Brak nazwy daje `version.missing`. Błąd sieci daje `error.load`, a napis wersji aplikacji zostaje.

Skrypt buildu zapisuje `export const mobileVersion = "mobile-vX.Y.Z"`. Wzorzec jest `^mobile-v\d+\.\d+\.\d+$`. Bez numeru wydania skrypt zapisuje `mobile-v0.0.0` i nie udaje tagu. Źródło numeru jest to samo co przy webie: numer komponentu z [07-wersje.md](../cicd/07-wersje.md), tu komponentu `mobile`.

Pokazanie na tym ekranie wersji webu przegrywa, bo to inny artefakt. Pobranie `mobile-vX.Y.Z` z `GET /versions` przegrywa, bo brama zwraca usługi i siebie, nie bundle ze sklepu. Jeden wspólny numer „aplikacji” dla webu i telefonu przegrywa, bo tagi są osobne.

Koszt: deweloperski start pokazuje `mobile-v0.0.0`. Wydanie bez skryptu nie przechodzi, bo zły napis kończy build kodem innym niż 0.

Odczyt wersji idzie na bramę, tak jak na webie. Telefon nie woła portu usługi. Hook albo funkcja `loadVersions` czyta `GET /versions` i układa sześć nazw w stałej kolejności. Gdy stos telefonu korzysta z TanStack Query, klucz jest `versions` i nie dubluje ręcznego typu odpowiedzi w pliku ekranu. Typ pochodzi z dokumentu OpenAPI, tak jak w numerze `05`.

### Formularz studenta i brak edytorów

`StudentContactScreen` wysyła tę samą operację co web: utworzenie `StudentInquiry`, tylko przy roli `student`. Gość widzi wejście do `LoginScreen`. Rola inna niż `student` nie widzi formularza.

`RecruiterContact` na telefonie nie powstaje. Publiczny formularz zostaje na `/:lang/contact` w webie. Dzięki temu telefon nie ma drugiej ścieżki, która mogłaby utworzyć zapytanie rekrutera przez pomyłkę.

Edytory CV, notatek i kursów nie powstają. Właściciel edytuje na webie. Na telefonie, gdy rola to `owner`, są skrzynki. Ich otwarcie z powiadomienia opisuje [07-powiadomienia.md](07-powiadomienia.md). Ten numer dodaje `StudentInboxScreen` i `RecruiterInboxScreen` do nawigatora, żeby kanał miał dokąd wejść, i pokazuje je w nawigacji tylko dla `owner`.

Logowanie i rejestracja są na telefonie, bo formularz studenta i powiadomienie właściciela potrzebują tokenu. Rejestracja ma pole `auth.invite`. Zapis do Identity idzie przez bramę.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/mobile/package.json` | React Native, NativeWind, zależność motywu i napisów |
| `src/clients/mobile/src/app/ThemeRoot.tsx` | `vars(cssCustomProperties())` |
| `src/clients/mobile/src/app/mobile-version.ts` | `mobileVersion` |
| `src/clients/mobile/scripts/write-version.mjs` | zapis napisu przed buildem wydania |
| `src/clients/mobile/src/i18n/use-chrome.ts` | `chrome` dla bieżącego locale |
| `src/clients/mobile/src/navigation/RootNavigator.tsx` | stos i zakładki |
| `src/clients/mobile/src/screens/HomeScreen.tsx` | skrót CV i notatki |
| `src/clients/mobile/src/screens/CvScreen.tsx` | publiczne CV |
| `src/clients/mobile/src/screens/TechnologyScreen.tsx` | technologia |
| `src/clients/mobile/src/screens/CoursesScreen.tsx` | lista kursów |
| `src/clients/mobile/src/screens/CourseScreen.tsx` | spis lekcji |
| `src/clients/mobile/src/screens/LessonScreen.tsx` | lekcja |
| `src/clients/mobile/src/screens/NotesScreen.tsx` | lista notatek |
| `src/clients/mobile/src/screens/NoteScreen.tsx` | notatka |
| `src/clients/mobile/src/screens/StudentContactScreen.tsx` | formularz studenta |
| `src/clients/mobile/src/screens/LoginScreen.tsx` | logowanie |
| `src/clients/mobile/src/screens/RegisterScreen.tsx` | rejestracja z kodem |
| `src/clients/mobile/src/screens/AboutScreen.tsx` | `mobile-vX.Y.Z` i sześć wersji |
| `src/clients/mobile/src/screens/StudentInboxScreen.tsx` | skrzynka studentów |
| `src/clients/mobile/src/screens/RecruiterInboxScreen.tsx` | skrzynka rekruterów |
| `src/clients/mobile/src/api/gateway.ts` | origin bramy, bez portu usługi |

Wejście CSS NativeWind leży przy konfiguracji telefonu i zawiera tylko mapę zmiennych. Nazwa pliku nie koliduje z webowym `styles.css`: to inny pakiet. Heksu w nim nie ma.

Zakładki: home, kursy, notatki, CV. Ekran O aplikacji jest osiągalny z belki, kluczem `nav.about`. Formularz studenta jest osiągalny z home albo z CV, nie jako piąta zakładka gościa, który nie ma roli.

## Plan

### 1. Pakiet

Załóż `src/clients/mobile` na React Native i NativeWind. Dopnij `@jjdevhub/theme` i napisy. Zarejestruj krój Inter pod nazwą z `tokens.font.family` zanim nawigacja się namaluje. Owiń drzewo w `ThemeRoot`.

Nie dodawaj Tamagui. Nie importuj `src/clients/web`.

### 2. Mapa klas

Wpisz w CSS telefonu ten sam `@theme inline` co web, bez heksów. Sprawdź komendą, że katalog telefonu nie zawiera heksa. Klasy na `HomeScreen` i na przycisku używają `bg-canvas`, `text-ink`, `bg-accent`, `text-surface`, `p-5`, `rounded-pill`.

### 3. Nawigacja i język

`RootNavigator` rejestruje ekrany z tabeli. `use-chrome` bierze locale z zapisu albo z `resolveLocale` na kodzie urządzenia. Przełącznik zapisuje tylko `pl` albo `en`.

Odczyt CV, kursów i notatek idzie przez `gateway.ts` na bramę. Ekran nie deklaruje ręcznie typu odpowiedzi: typ przychodzi z modułu zbudowanego z OpenAPI, tak jak na webie. HTML lekcji i notatki na telefonie nie używa `dangerouslySetInnerHTML`. React Native nie ma tego API. Tekst złożony pokaż jako natywny widok z danych, które API oddało obok HTML, albo jako ograniczony zestaw bloków, który nie wykonuje HTML. Jeśli usługa oddaje tylko HTML, ekran lekcji pokazuje treść po przejściu przez oczyszczenie do tekstu bloków, bez interpretera HTML w silniku web. Skrypt i iframe nie mają jak powstać, bo nie ma DOM.

Ten podział jest świadomy: web ma jedno `TrustedHtml`, telefon nie dokłada drugiego silnika HTML.

### 4. O aplikacji

`write-version.mjs` zapisuje `mobile-version.ts`. `AboutScreen` czyta `mobileVersion` i `GET /versions`. Kolejność wierszy: identity, news, learning, cv, contact, gateway. Test podstawia `mobile-v1.4.0` i stub odpowiedzi, potem sprawdza, że oba teksty są na ekranie.

### 5. Formularz i skrzynki

`StudentContactScreen` woła operację studenta tylko przy roli `student`. Brak roli prowadzi do logowania albo chowa formularz, zgodnie z webem. `StudentInboxScreen` i `RecruiterInboxScreen` są zarejestrowane i dostępne z nawigatora dla `owner`. Podpięcie powiadomienia do tych nazw jest w numerze `07`.

### Co jest do czego

- `ThemeRoot` — jedyne nałożenie zmiennych motywu. Woła go korzeń aplikacji, raz.
- `RootNavigator` — rejestr nazw ekranów. Powiadomienie z numeru `07` otwiera nazwę stąd, nie wymyśla trzeciej.
- `use-chrome` — napisy z wspólnych kluczy. Ekran nie trzyma własnego słownika.
- `AboutScreen` — wersja komponentu `mobile` i wersje usług. Odpowiednik `Footer` z webu.
- `mobileVersion` — napis wbity przy buildzie. Ekran go czyta. Test go podmienia.
- `gateway.ts` — origin bramy dla telefonu. Ekran nie składa URL usługi.
- `StudentContactScreen` — ta sama operacja co formularz studenta na webie.
- `StudentInboxScreen` i `RecruiterInboxScreen` — cele nawigacji dla dwóch skrzynek. Kanały opisuje numer `07`.

## Testy

Logikę locale i napis wersji da się sprawdzić bez emulatora, Vitestem, na czystych funkcjach i na module wersji. Ekran O aplikacji sprawdzamy tak, żeby w asercji był tekst, który widzi użytkownik. Jeśli runner komponentów telefonu w danym kroku nie maluje natywnego drzewa, test funkcji `aboutLines(mobileVersion, versions)` zwraca linie, które ekran ma pokazać, a test tej funkcji jest kontraktem treści. Ekran tylko je renderuje, bez dokładania siódmej nazwy.

| Fakt | Assert |
| --- | --- |
| `device_locale_de_resolves_pl` | `resolveLocale('de')` równe `pl` |
| `about_shows_baked_mobile_version` | linia zawiera `mobile-v1.4.0`, gdy moduł tak mówi |
| `about_lists_six_services` | linie mają identity, news, learning, cv, contact, gateway |
| `about_marks_missing_news` | brak `news` daje tekst `version.missing` przy tej nazwie |
| `student_screen_uses_student_operation` | wysłanie przy roli `student` woła operację studenta |
| `no_recruiter_form_module` | w `src/clients/mobile` nie ma ekranu tworzenia `RecruiterInquiry` |
| `mobile_sources_have_no_hex` | `rg` heksa w `src/clients/mobile` milczy |

```bash
cd src/clients/mobile
pnpm exec vitest run
rg -n "#[0-9a-fA-F]{3,8}" src
```

Drugie polecenie, odpalone w katalogu telefonu, ma zero trafień. Heks zostaje w `tokens.ts`, poza tym pakietem.

Build wydania:

```bash
node src/clients/mobile/scripts/write-version.mjs
```

Kończy się kodem innym niż 0, gdy wynik nie pasuje do `mobile-vX.Y.Z`. Dla braku numeru zapisuje `mobile-v0.0.0` i kończy się kodem 0 tylko wtedy, gdy wołający jawnie prosi o wariant deweloperski. Wydanie bez numeru nie jest sukcesem.

## Zasady

- Ekran telefonu nie importuje plików z `src/clients/web`.
- Klasa koloru i odstępu nazywa się tak samo jak na webie i bierze wartość z `tokens`.
- W katalogu telefonu nie ma heksa.
- Klucze napisów pochodzą ze wspólnego `i18n`. Drugi plik słownika nie powstaje.
- `resolveLocale` jest jedyną funkcją obcego kodu języka.
- `AboutScreen` pokazuje `mobile-vX.Y.Z` i sześć nazw usług, w tej kolejności co stopka webu.
- Żądanie idzie na bramę.
- Formularz rekrutera na telefonie nie powstaje.
- Edytor CV, notatki i kursu na telefonie nie powstaje.
- HTML nie wchodzi do silnika web na telefonie. `dangerouslySetInnerHTML` zostaje jednym trafieniem, na webie.
- Krój rejestruje się jako `Inter`.

## Poza zakresem

- Wartości tokenów — [01-motyw.md](01-motyw.md).
- Trasy URL webu — [02-web.md](02-web.md).
- Arkusz webu i shadcn — [03-wyglad.md](03-wyglad.md). Telefon nie używa `components/ui` z webu.
- Edytory intranetu i `If-Match` — [04-intranet.md](04-intranet.md).
- Kształt operacji OpenAPI i `TrustedHtml` — [05-tresc.md](05-tresc.md).
- Rejestracja tokenu urządzenia, dwa kanały, skasowanie przy wylogowaniu — [07-powiadomienia.md](07-powiadomienia.md).
- Reanimated — [08-ruch.md](08-ruch.md). Ten numer tylko zostawia klasy bez literału czasu w wywołaniu animacji.
- Tag komponentu — [07-wersje.md](../cicd/07-wersje.md).

## Źródła

- [React Native](https://reactnative.dev/docs/getting-started) — osobne widoki, nie DOM.
- [NativeWind](https://www.nativewind.dev/) — klasy na tych widokach.
- [NativeWind vars](https://www.nativewind.dev/docs/guides/themes) — nałożenie zmiennych na korzeń.
- [Inter](https://rsms.me/inter/) — rodzina `Inter` także na telefonie.
- [React Navigation](https://reactnavigation.org/docs/getting-started) — stos i zakładki; telefon nie używa routera webu.
- [GET /versions](../api/16-gateway.md) — sześć nazw, które ekran O aplikacji układa w stałej kolejności.

## Gotowe gdy

- `ThemeRoot` nakłada `cssCustomProperties()` i ekran używa `bg-canvas` oraz `bg-accent`.
- Nieznany język urządzenia daje `pl` przez `resolveLocale`.
- `AboutScreen` pokazuje napis `mobile-vX.Y.Z` i sześć nazw usług.
- W `src/clients/mobile` nie ma heksa i nie ma formularza rekrutera.
- Ekrany skrzynek są w nawigatorze dla roli `owner`.
- `cd src/clients/mobile && pnpm exec vitest run` kończy się kodem 0.
- Skrypt wersji odrzuca napis spoza wzorca `mobile-vX.Y.Z`.
- Tag `mobile-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job nie tworzy poda. Artefakt zostawia ten tag na ekranie O aplikacji.
