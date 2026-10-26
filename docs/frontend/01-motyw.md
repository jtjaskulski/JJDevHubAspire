# Motyw

Ten numer zapisuje liczby wyglądu wspólne dla webu i telefonu. Jeden obiekt w `src/clients/shared/theme/tokens.ts` trzyma kolory, odstępy, promienie, skalę pisma i czasy. Tailwind z [03-wyglad.md](03-wyglad.md) i NativeWind z [06-mobile.md](06-mobile.md) dopiero nazywają te liczby klasami. Ten numer ich nie instaluje.

Poprzedni plik tego folderu to [README.md](README.md). Następny numer to [02-web.md](02-web.md). W kolejności pracy całego repozytorium numer stoi po domknięciu piramidy w [22-testy.md](../api/22-testy.md). Czytanie frontendu i tak zaczyna się od mapy w `README.md`.

Moduł nie importuje Reacta, Tailwinda, NativeWind, Motion ani Reanimated. Dzięki temu oba klienty biorą ten sam plik, a test liczb nie podnosi przeglądarki.

## Po co

Dwa klienty mają wyglądać jak jeden produkt. Web rysuje HTML. Telefon rysuje widoki React Native. Wspólny jest zestaw liczb, nie wspólne komponenty. Gdy akcent, odstęp karty albo czas przejścia zmieni się w jednym pliku, oba klienty czytają nową wartość przy następnym buildzie.

Paleta jasna jest częścią tego kontraktu. Tło to `#f3efe6`, atrament to `#1a1814`, akcent to `#9a3412`. Krój nazywa się Inter. Reszta kolorów w tym pliku jest tą samą rodziną, nie drugim motywem: jaśniejsza karta, drugi plan tekstu, linia obrysu. Heks wpisany w komponencie, w `styles.css` albo w konfiguracji NativeWind byłby drugą paletą, cichą i niesprawdzaną.

Czasy stoją obok kolorów, bo ruch z [08-ruch.md](08-ruch.md) ma brać milisekundy stąd. Literał `300` w wywołaniu animacji jest tym samym błędem co heks w klasie.

Skala odstępów od piątki w górę nie jest wielokrotnością czterech pikseli. Domyślna skala narzędzi CSS wzięłaby `5` za dwadzieścia pikseli. Token `space.5` to dwadzieścia cztery. Dlatego liczby muszą być jawne, zanim którekolwiek narzędzie nada im nazwę klasy.

## Dlaczego ta technologia

### Jeden moduł bez UI

Moduł `@jjdevhub/theme` jest prywatnym pakietem `type: module`. Eksport `"."` wskazuje `./tokens.ts`. Zależności uruchomieniowej nie ma. Web podepnie go jako `"@jjdevhub/theme": "file:../shared/theme"`. Telefon podepnie ten sam katalog ze swojej ścieżki względnej.

Wspólny katalog komponentów React przegrywa, bo ekrany webu i telefonu są osobne. Wspólny byłby wtedy także JSX, a telefon nie renderuje `div`. Zmienne CSS wpisane od razu w arkusz przegrywają, bo Reanimated i Motion potrzebują liczby w JavaScript, a arkusz dałby im napis z jednostką. Dwa pliki, `tokens.web.ts` i `tokens.native.ts`, przegrywają, bo różnica wkradłaby się przy pierwszej poprawce akcentu.

Koszt: każda nowa liczba to zmiana tego pliku, dopisanie właściwości w serializerze i jedna linia mapy w numerze, który maluje klasy. Trzy miejsca, jeden heks. Sam heks zostaje tutaj.

### Paleta zapisana raz

`tokens.color` jest jedynym miejscem, w którym klienty trzymają heks. Klucze są stałe.

| Klucz | Heks | Rola |
| --- | --- | --- |
| `canvas` | `#f3efe6` | tło strony |
| `surface` | `#faf8f4` | karta i tekst na akcencie |
| `ink` | `#1a1814` | tekst i tło masztu |
| `muted` | `#6f675e` | tekst drugiego planu i stan wyłączony |
| `line` | `#e4ddd0` | linia i obrys |
| `accent` | `#9a3412` | akcent, przycisk główny, fokus |

Maszt home bierze `ink` jako tło i `canvas` jako tekst. To te same dwa heksy, użyte odwrotnie na jednym pasie, nie osobna paleta masztu. Tekst na przycisku akcentu bierze `surface`.

Paleta narzędzi (domyślne `slate`, `zinc`, czerń i biel z resetu) przegrywa, bo jej heksy nie są tymi liczbami. Tryb ciemny jako drugi obiekt kolorów w komponencie przegrywa z tego samego powodu: drugi zestaw heksów żyłby obok kontraktu. Osobny plik „brand” w figmie wyeksportowany do CSS przegrywa, bo telefon nie czyta tego arkusza.

Koszt: karta, drugi plan i linia są dobrane do płótna i atramentu i też mieszkają tutaj. Kto potrzebuje nowego koloru, dopisuje klucz. Nie wpisuje heksa w `className`.

### Liczby bez jednostki w obiekcie

W obiekcie odstęp, promień i rozmiar pisma są liczbą pikseli. Tracking jest liczbą w `em`. Czas jest liczbą milisekund. Krzywa jest krotką czterech liczb. Kolor i rodzina pisma są napisem, bo jednostką jest sam napis.

Funkcja `cssCustomProperties()` dokleja jednostkę i zwraca `Record<string, string>`. Woła ją web, zanim pierwszy raz pomaluje dokument, i telefon, na korzeniu drzewa. Komponent, który potrzebuje liczby dla ruchu, importuje `tokens.duration` i `tokens.easing` i nie parsuje napisu `700ms`.

Serializer, który trzymałby od razu napisy `'24px'`, przegrywa, bo Reanimated dostałby tekst albo ktoś obcinałby jednostkę z powrotem. Trzymanie i liczby, i gotowego napisu w dwóch polach przegrywa, bo te dwa pola rozjadą się przy pierwszej zmianie.

Koszt: wołający CSS musi przejść przez `cssCustomProperties()`. Bezpośredni dostęp do `tokens.space[5]` w szablonie HTML nie niesie jednostki. Na webie i tak idzie klasa, nie inline style z liczbą.

Reguły jednostek:

| Pole | W obiekcie | Napis CSS |
| --- | --- | --- |
| `font.size.*`, `space.*`, `radius.*` | liczba | `` `${n}px` `` |
| `font.tracking.*` | liczba w `em` | `` `${n}em` `` |
| `font.weight.*` | liczba | ta sama liczba jako napis |
| `duration.*` | milisekundy | `` `${n}ms` `` |
| `easing.*` | krotka czterech liczb | `` `cubic-bezier(${x1}, ${y1}, ${x2}, ${y2})` `` |
| `color.*`, `font.family` | napis | ten sam napis |

Funkcje `px`, `em`, `ms` i `cubicBezier` zostają prywatne w `tokens.ts`. Poza modułem widać `tokens`, typ `Tokens` i `cssCustomProperties`.

### Skala pisma i odstępu w tym samym obiekcie

Rodzina to `'Inter'`. Na webie plik kroju dołoży [03-wyglad.md](03-wyglad.md). Na telefonie plik kroju dołoży [06-mobile.md](06-mobile.md). Oba rejestrują rodzinę pod nazwą z `tokens.font.family`. Inna nazwa rodziny w jednym kliencie jest błędem kontraktu.

Rozmiar i tracking mają te same klucze.

| Klucz | `font.size` (px) | `font.tracking` (em) |
| --- | --- | --- |
| `display` | 80 | -0.015 |
| `h1` | 56 | -0.012 |
| `h2` | 40 | -0.01 |
| `h3` | 28 | -0.008 |
| `h4` | 21 | -0.005 |
| `body` | 17 | -0.014 |
| `small` | 14 | -0.006 |
| `caption` | 12 | 0 |

Grubość ma dwa klucze: `regular` równe `400` i `semibold` równe `600`. Trzeciej grubości ten numer nie wprowadza.

Odstępy:

| Klucz | px |
| --- | --- |
| `1` | 4 |
| `2` | 8 |
| `3` | 12 |
| `4` | 16 |
| `5` | 24 |
| `6` | 32 |
| `7` | 48 |
| `8` | 64 |
| `9` | 80 |
| `10` | 96 |
| `11` | 128 |
| `12` | 160 |

Promienie:

| Klucz | px | Rola |
| --- | --- | --- |
| `sm` | 4 | drobny obrys |
| `md` | 8 | pole formularza |
| `lg` | 12 | stopień skali |
| `card` | 12 | karta; osobny klucz, ta sama liczba co `lg` |
| `pill` | 9999 | kapsuła przycisku |

`card` i `lg` mają tę samą liczbę i zostają dwoma kluczami. Karta może później zmienić promień bez ruszania stopnia `lg`.

Domyślna skala pisma i odstępów narzędzia CSS przegrywa, bo po cichu wprowadza `16px` jako tekst i `20px` jako krok `5`. Własna skala tylko na webie przegrywa, bo telefon dostałby inne `p-5`. Skala w `rem` przy domyślnym `16px` przegrywa, bo telefon nie ma tego samego korzenia dokumentu.

Koszt: skala jest dłuższa niż `4, 8, 16, 32`. Trzeba jej pilnować w teście, klucz po kluczu. Zysk jest taki, że klasa `p-5` na webie i na telefonie oznacza dwadzieścia cztery piksele.

### Czasy i krzywe obok kolorów

Czas zostaje liczbą. `tokens.duration.reveal === 700` jest prawdą w teście. Napis `700ms` powstaje tylko w serializerze.

| Klucz | ms | Do czego bierze go numer `08` |
| --- | --- | --- |
| `reveal` | 700 | wejście sekcji |
| `revealFast` | 400 | drobny element listy |
| `heroPin` | 1200 | pas masztu |
| `heroFade` | 600 | zejście masztu |
| `nav` | 250 | belka i kolor pod wskaźnikiem |

Krzywe są krotkami `[x1, y1, x2, y2]`.

| Klucz | Krotka |
| --- | --- |
| `reveal` | `[0.25, 0.1, 0.25, 1]` |
| `hero` | `[0.22, 1, 0.36, 1]` |
| `standard` | `[0.4, 0, 0.2, 1]` |

Czas wpisany przy wywołaniu biblioteki ruchu przegrywa, bo recenzja nie odróżni `250` belki od przypadku. Krzywa jako napis `cubic-bezier(...)` w komponencie przegrywa, bo telefon bierze krotkę, a webowa biblioteka też przyjmuje liczby. Jedna krzywa „ease” na wszystko przegrywa, bo maszt i belka nie dzielą tego samego ruchu. Opis masztu jest w [08-ruch.md](08-ruch.md). Ten numer tylko trzyma liczby.

Koszt: pięć czasów i trzy krzywe trzeba nazwać z góry. Nowy ruch bierze istniejący klucz albo dopisuje klucz tutaj. Nie wybiera milisekund w pliku ekranu.

`tokens` jest `as const`. Klucz spoza tabeli nie skompiluje się u wołającego, który indeksuje obiekt przez typ `Tokens`.

## Klasy i ścieżki

W tym numerze nie ma jeszcze klas CSS. Są nazwy właściwości, które później staną się klasami. Nazwa właściwości jest stała, żeby mapa w `03` i na telefonie nie wymyślała drugiej.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/shared/theme/package.json` | pakiet prywatny, eksport `./tokens.ts`, zero zależności |
| `src/clients/shared/theme/tokens.ts` | obiekt `tokens`, typ `Tokens`, `cssCustomProperties` |
| `src/clients/shared/theme/tokens.test.ts` | liczby z tabel tego numeru |

Publiczny kształt modułu:

```ts
export const tokens: Tokens;
export type Tokens = typeof tokens;
export function cssCustomProperties(): Record<string, string>;
```

Właściwości, które serializer wpisuje na dokument:

| Pole | Właściwość |
| --- | --- |
| `color.canvas` | `--canvas` |
| `color.surface` | `--surface` |
| `color.ink` | `--ink` |
| `color.muted` | `--muted` |
| `color.line` | `--line` |
| `color.accent` | `--accent` |
| `font.family` | `--font-family` |
| `font.size.h1` | `--font-h1` |
| `font.size.body` | `--font-body` |
| `font.size.small` | `--font-small` |
| `font.size.display` | `--font-display` |
| `font.size.h2` | `--font-h2` |
| `font.size.h3` | `--font-h3` |
| `font.size.h4` | `--font-h4` |
| `font.size.caption` | `--font-caption` |
| `font.tracking.*` | `--tracking-<klucz>` |
| `font.weight.regular` | `--font-weight-regular` |
| `font.weight.semibold` | `--font-weight-semibold` |
| `space.1` … `space.12` | `--space-1` … `--space-12` |
| `radius.sm` `md` `lg` `card` `pill` | `--radius-sm` i pozostałe klucze |
| `duration.*` | `--duration-reveal`, `--duration-reveal-fast`, `--duration-hero-pin`, `--duration-hero-fade`, `--duration-nav` |
| `easing.*` | `--easing-reveal`, `--easing-hero`, `--easing-standard` |

Klucz z tabeli, którego nie ma w obiekcie, albo właściwość spoza tej listy, jest błędem testu serializera. Test sprawdza komplet kluczy, nie próbkę.

## Plan

### 1. Pakiet

W `src/clients/shared/theme/package.json` ustaw nazwę `@jjdevhub/theme`, `"private": true`, `"type": "module"`, `"exports": { ".": "./tokens.ts" }`. Pola `dependencies` nie dodawaj. Reacta, Tailwinda i NativeWind nie instaluj.

### 2. Obiekt liczb

W `tokens.ts` zapisz `tokens` jako `as const` z polami `color`, `font`, `space`, `radius`, `duration`, `easing`. Wartości weź z tabel tego numeru. `font.family` to `'Inter'`. `color.canvas` to `'#f3efe6'`, `color.ink` to `'#1a1814'`, `color.accent` to `'#9a3412'`.

Klucze `space` zapisuj jako liczby, nie jako napisy `'5'`, jeśli typ na to pozwala; wołający i tak adresuje `tokens.space[5]`. W obiekcie trzymaj jedenaście progów od `1` do `12` dokładnie z tabeli.

### 3. Serializer

`cssCustomProperties()` zwraca jedną mapę. Dla każdego pola z tabeli jednostek dokleja jednostkę albo przepisuje napis. Nie przyjmuje argumentu schematu kolorów: paleta w tym numerze jest jedna. Nie czyta `document` i nie czyta `localStorage`. Wołający sam nakłada mapę na węzeł.

Nazwy właściwości z tabeli „Właściwości” są jedynymi kluczami wyniku. Test porównuje zbiór kluczy.

### 4. Test liczb

W `tokens.test.ts` użyj `node:test`. Asercje:

- `tokens.color.canvas`, `ink`, `accent`, `surface`, `muted`, `line` równe heksom z tabeli,
- `tokens.font.family` równe `'Inter'`,
- `tokens.font.size.body` równe `17`, `tokens.space[5]` równe `24`, `tokens.radius.card` równe `12`, `tokens.radius.pill` równe `9999`,
- `tokens.duration.reveal` równe `700`, `tokens.duration.nav` równe `250`,
- `tokens.easing.standard` głęboko równe `[0.4, 0, 0.2, 1]`,
- `cssCustomProperties()['--canvas']` równe `#f3efe6`,
- `cssCustomProperties()['--space-5']` równe `24px`,
- `cssCustomProperties()['--duration-nav']` równe `250ms`,
- `cssCustomProperties()['--easing-hero']` równe `cubic-bezier(0.22, 1, 0.36, 1)`,
- zbiór kluczy wyniku równy zbiorowi właściwości z tabeli.

### 5. Zakaz heksa obok

W tym numerze jedyny plik klienta z heksem to `tokens.ts`. Sprawdzenie z sekcji Testy ma zero trafień poza tym plikiem. Katalogów webu i telefonu jeszcze nie ma; komenda i tak obejmuje `src/clients`.

### Co jest do czego

- `tokens` — jedyny zapis liczb. Web, telefon, Motion i Reanimated importują ten obiekt. Nikt nie kopiuje heksa do swojego pliku.
- `Tokens` — typ wyprowadzony z obiektu. Nowy klucz w obiekcie od razu jest w typie. Ręczny interfejs obok obiektu rozjechałby się z wartością.
- `cssCustomProperties` — jedyne miejsce, które dokleja `px`, `em`, `ms` i `cubic-bezier`. Woła je punkt startu webu i korzeń telefonu, nie ekran.
- `tokens.color` — paleta jasna. Mapa klas w numerze `03` i na telefonie wskazuje na właściwości z tego pola.
- `tokens.duration` i `tokens.easing` — liczby dla ruchu. Numer `08` bierze je w JavaScript. Serializer i tak wystawia napis, żeby prosta zmiana koloru w CSS mogła użyć tego samego czasu.
- `tokens.test.ts` — dowód, że tabela z tego pliku i obiekt w repozytorium są tym samym. Późniejszy numer nie powtarza tych asercji.

## Testy

Runner tego numeru to `node:test`, bez Vitest i bez jsdom. Vitest dochodzi razem z webem w [02-web.md](02-web.md) i nie jest potrzebny, żeby sprawdzić liczbę.

Każdy fakt ma jeden powód do padnięcia.

| Fakt | Assert |
| --- | --- |
| `canvas_is_warm_paper` | `tokens.color.canvas === '#f3efe6'` |
| `ink_is_near_black` | `tokens.color.ink === '#1a1814'` |
| `accent_is_clay` | `tokens.color.accent === '#9a3412'` |
| `family_is_inter` | `tokens.font.family === 'Inter'` |
| `space_5_is_24` | `tokens.space[5] === 24` |
| `card_radius_is_12` | `tokens.radius.card === 12` |
| `reveal_is_700` | `tokens.duration.reveal === 700` |
| `serializer_emits_px_ms_and_bezier` | `--space-5`, `--duration-nav`, `--easing-hero` mają jednostki z tabeli |
| `serializer_covers_every_property` | klucze wyniku równe tabeli właściwości |

```bash
node --experimental-strip-types --test src/clients/shared/theme/tokens.test.ts
```

Node na tej komendzie to linia 22, tę samą, którą web zapisze w `engines` w numerze `02`.

Osobno, heks poza obiektem:

```bash
rg -n "#[0-9a-fA-F]{3,8}" src/clients --glob '!**/tokens.ts'
```

Brak trafień. Trafienie w teście, które porównuje heks do stałej z `tokens`, jest dozwolone tylko wtedy, gdy stała po prawej pochodzi z importu, nie z literału. Testy tego numeru porównują do literału świadomie: one są strażnikiem literału. Inny test literału koloru nie powtarza.

## Zasady

- Heks koloru klienta stoi w `tokens.color`. Drugi heks w `src/clients` jest błędem komendy `rg`.
- `tokens.ts` nie importuje Reacta, Tailwinda, NativeWind, Motion ani Reanimated.
- Jednostkę dokleja tylko `cssCustomProperties`. Pole obiektu zostaje liczbą tam, gdzie tabela jednostek mówi „liczba”.
- `font.family` to `Inter`. Web i telefon ładują plik kroju pod tę nazwę w swoich numerach.
- `space.5` to `24`. Mnożnik „co cztery piksele” nie wchodzi do tego obiektu.
- `radius.card` i `radius.lg` mogą mieć tę samą liczbę i zostają osobnymi kluczami.
- Nowy czas animacji jest nowym kluczem `duration`, nie literałem w ekranie.
- Paleta w tym numerze jest jedna. Drugi schemat kolorów nie dostaje klas `dark:` w komponencie.
- Eksport publiczny to `tokens`, `Tokens` i `cssCustomProperties`. Pomocnicze funkcje jednostek nie wychodzą z pliku.

## Poza zakresem

- Składnia klas, `@theme` i plik `styles.css` — [03-wyglad.md](03-wyglad.md).
- Nałożenie tych samych zmiennych na korzeń React Native — [06-mobile.md](06-mobile.md).
- Wejście sekcji, maszt i `prefers-reduced-motion` — [08-ruch.md](08-ruch.md).
- Plik kroju Inter na webie — [03-wyglad.md](03-wyglad.md). Plik kroju na telefonie — [06-mobile.md](06-mobile.md).
- Trasy, shell i stopka — [02-web.md](02-web.md).
- Tryb ciemny jako drugi zestaw heksów. Gdy kiedyś powstanie, będzie nowymi wartościami w tym samym obiekcie, nie klasą w komponencie.
- Tamagui i wspólne komponenty webu z telefonem.

## Źródła

- [CSS custom properties](https://developer.mozilla.org/en-US/docs/Web/CSS/--*) — właściwości, które serializer wystawia, a mapa klas tylko wskazuje.
- [CSS Values: lengths](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_Values_and_Units/CSS_length) — `px` i `em` doklejane przy serializacji, nie w obiekcie.
- [prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) — konsumuje je numer `08`; czasy, które wtedy zeruje, leżą tutaj.
- [Node test runner](https://nodejs.org/api/test.html) — `node:test` bez dokładania runnera UI do pakietu liczb.
- [Inter](https://rsms.me/inter/) — rodzina, której nazwa CSS to `Inter`.

## Gotowe gdy

- `src/clients/shared/theme/tokens.ts` eksportuje `tokens` i `cssCustomProperties`.
- `tokens.color.canvas` to `#f3efe6`, `ink` to `#1a1814`, `accent` to `#9a3412`, `font.family` to `Inter`.
- `space.5` to `24`, `duration.reveal` to `700`, `duration.nav` to `250`.
- Serializer zwraca `--space-5` jako `24px` i `--duration-nav` jako `250ms`.
- Pakiet nie ma zależności od Reacta ani Tailwinda.
- `node --experimental-strip-types --test src/clients/shared/theme/tokens.test.ts` kończy się kodem 0.
- `rg -n "#[0-9a-fA-F]{3,8}" src/clients --glob '!**/tokens.ts'` nie znajduje trafień.
