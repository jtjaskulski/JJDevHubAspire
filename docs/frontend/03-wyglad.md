# Wygląd

Ten numer kładzie Tailwind CSS v4 i shadcn/ui na HTML, który złożył [02-web.md](02-web.md). Wejście CSS jest jedno: `src/clients/web/src/styles.css`. Liczby biorą się z [01-motyw.md](01-motyw.md). Plik CSS ich nie powtarza. Ruch zostaje w [08-ruch.md](08-ruch.md). Telefon dostanie te same nazwy klas w [06-mobile.md](06-mobile.md).

Poprzedni numer to [02-web.md](02-web.md). Następny to [04-intranet.md](04-intranet.md).

Nowy plik `*.scss` nie powstaje. Drugi arkusz obok `styles.css` nie powstaje. Komponent shadcn zostaje w repozytorium, w `src/clients/web/src/components/ui`, i maluje się klasami z tego arkusza.

## Po co

Po numerze `02` strona ma adres, shell i jeden `h1`, a nie ma jeszcze wspólnego wyglądu z telefonem. Domyślna paleta narzędzia CSS wprowadziłaby własne heksy. Ten numer wyłącza tę paletę i zostawia nazwy, które wskazują na właściwości z `cssCustomProperties()`.

shadcn daje przycisk, pole, dialog, zakładki, tabelę i komunikat, których intranet i formularze użyją zaraz potem. Kopiowanie komponentu do repozytorium sprawia, że wygląd da się spiąć z tokenami bez dokładania drugiej biblioteki przycisków. Element pod spodem zostaje przyciskiem, polem i nagłówkiem. Klasa nie zastępuje HTML.

Jeden plik CSS jest bramką recenzji. Heks, piksel i milisekunda w arkuszu widać jedną komendą. Rozproszone pliki modułowe chowałyby drugi akcent w katalogu strony.

## Dlaczego ta technologia

### Tailwind CSS v4

Tailwind v4 czyta motyw z CSS, z bloku `@theme`, nie z pliku `tailwind.config.js`. Plugin `@tailwindcss/vite` podpina się w Vite. W `styles.css` stoi `@import "tailwindcss"`.

Wersja v3 z konfiguracją w JavaScript przegrywa, bo liczby już żyją w `tokens.ts` i w właściwościach CSS. Drugi plik konfiguracji byłby trzecim miejscem na heks. CSS Modules przy każdym komponencie przegrywają, bo nazwa klasy lokalnej nie zgadza się z klasą telefonu. Zestaw własnych klas w SCSS przegrywa, bo dokładamy pliki, których ten numer zabrania, i drugą skalę odstępów.

Koszt: trzeba zresetować domyślne przestrzenie kolorów, pisma, trackingu, odstępów, promieni i czasów. Bez resetu `p-5` znaczy dwadzieścia pikseli z mnożnika narzędzia, a token mówi dwadzieścia cztery. Reset jest częścią bloku `@theme`, nie osobnym arkuszem.

Słowo `inline` przy `@theme` jest obowiązkowe. Klasa dostaje `var(--canvas)`, a heks zostaje na właściwości, którą wstawił `cssCustomProperties()`. Bez `inline` narzędzie zadeklarowałoby własną zmienną o tej samej nazwie i łatwo o pętlę tam, gdzie nazwa przestrzeni pokrywa się z właściwością dokumentu.

### shadcn na tym samym HTML

shadcn nie jest zależnością uruchomieniową. `shadcn init` pod Vite i Tailwind v4 zakłada `components.json` i alias `@/` na `src`. Komponenty, które dochodzą, to źródło w `src/components/ui`: przycisk, pole, etykieta, obszar tekstu, dialog, zakładki, tabela, plakietka, komunikat. Formularz logowania, formularz kontaktu i listy intranetu biorą te pliki.

Gotowa biblioteka komponentów z własnym motywem (osobny system przycisków, własny plik zmiennych) przegrywa, bo wnosi drugą paletę i własne nazwy odstępów. Zostawienie komponentów tylko w rejestrze, bez kopii w gicie, przegrywa, bo wygląd zależałby od sieci przy buildzie i nie dałoby się spiąć zmiennej z tokenem w recenzji. Rysowanie przycisku jako `div` z rolą przegrywa, bo plik shadcn ma zostać przy elemencie `button`.

Koszt: katalog `components/ui` jest w repozytorium i przy aktualizacji komponentu z rejestru trzeba powtórzyć spięcie ze zmiennymi. Aktualizacja nie przywraca domyślnej palety shadcn. Komenda na heks w tym katalogu ma być pusta.

Komponent bierze klasę z kontraktu: `bg-accent`, `text-surface`, `rounded-pill`, `px-5`. Nie bierze `bg-[#9a3412]`.

### Jeden plik CSS

`src/clients/web/src/main.tsx` importuje `./styles.css` raz. Żaden komponent nie importuje innego pliku CSS ani SCSS. `@import "tailwindcss"` i blok `@theme inline` stoją w `styles.css`. Import kroju Inter też stoi tutaj, jeden raz: pakiet `@fontsource-variable/inter`. Rodzina, którą plik rejestruje, nazywa się `Inter`, zgodnie z `tokens.font.family`.

Pliki `*.module.css` przy stronach przegrywają, bo omijają jedną komendę szukającą heksa i rozdzielają motyw. Sass i nowe `*.scss` przegrywają wprost: ten numer ich nie wprowadza, a zagnieżdżony selektor nie daje nic, czego nie da klasa na elemencie. `@apply` w wielu plikach przegrywa, bo chowa zestaw klas przed recenzją JSX. W `styles.css` `@apply` nie jest potrzebny. Wyjątek, gdyby narzędzie wymusiło jedną regułę, zostaje w tym jednym pliku i nie niesie heksa.

Koszt: globalne warstwy narzędzia są w jednym miejscu. Komponent nie ma lokalnego arkusza, więc stan hover i fokus opisuje klasa na elemencie, nie selektor w osobnym pliku.

Przed pierwszym malowaniem `main.tsx` woła `cssCustomProperties()` i wpisuje wynik na `document.documentElement`. Bez tego klasy wskazują puste zmienne. Telefon zrobi ten sam krok na swoim korzeniu, w swoim numerze.

### Mapa bez drugiej palety

Blok `@theme inline` resetuje przestrzenie i podstawia `var(--…)` z serializera. Literał piksela, milisekundy i heksu w tym bloku nie występuje.

| Przestrzeń | Reset | Wpis |
| --- | --- | --- |
| kolor | `--color-*: initial` | `--color-canvas: var(--canvas)` i dalej `surface`, `ink`, `muted`, `line`, `accent` |
| rodzina | — | `--font-sans: var(--font-family), sans-serif` |
| rozmiar | `--text-*: initial` | `--text-display` … `--text-caption` z `var(--font-…)` |
| tracking | `--tracking-*: initial` | klucze z `01`, z `var(--tracking-…)` |
| odstęp | `--spacing: initial` | `--spacing-1` … `--spacing-12` z `var(--space-…)` |
| promień | `--radius-*: initial` | `sm`, `md`, `lg`, `card`, `pill` |
| krzywa | `--ease-*: initial` | `reveal`, `hero`, `standard` |
| czas | `--transition-duration-*: initial` | `reveal`, `reveal-fast`, `hero-pin`, `hero-fade`, `nav` |

`--font-sans` dokleja `, sans-serif` jako zapas, gdy plik Inter jeszcze nie doszedł. W `@theme` nie ma `--font-display` jako rodziny: w tym narzędziu `--font-*` to rodzina, a rozmiar display jest `--text-display`.

Klasa czasu to `duration-nav`, a właściwość dokumentu zostaje `--duration-nav`. Klasa krzywej to `ease-standard`, właściwość zostaje `--easing-standard`. Te klasy służą prostej zmianie koloru i krycia. Wejście sekcji i maszt biorą liczby w JavaScript w numerze `08`, z tego samego `tokens.duration`.

Domyślne `bg-black` jako maszt przegrywa, bo czerń nie jest w palecie. Maszt używa `bg-ink text-canvas`. Domyślne `rounded-lg` bez resetu przegrywa, bo oznacza osiem pikseli, a token `lg` to dwanaście. Klasa arbitralna `p-[24px]` przegrywa, bo powtarza `space.5`, który już nazywa się `p-5`.

Koszt: po resecie nie ma `text-sm` ani `p-4` w starym sensie narzędzia. Jest `text-small`, `text-body`, `p-4` równe szesnastu pikselom z tokenu `space.4`. Autor klasy patrzy w tabelę z numeru `01`, nie w pamięć domyślnej skali.

Stany, które zostają klasami na HTML:

| Stan | Klasy |
| --- | --- |
| przycisk główny | `bg-accent text-surface rounded-pill px-5 py-3 text-small` |
| przycisk wyłączony | `bg-muted text-surface` i atrybut `disabled` |
| fokus | `focus-visible:outline` kolorem akcentu, bez usuwania obrysu |
| karta | `bg-surface text-ink rounded-card border border-line` |
| drugi plan | `text-muted` |
| maszt | `bg-ink text-canvas` |
| pusta lista | tekst z `empty.list`, ten sam skład karty |

Hover przycisku zostaje przy akcencie. Nie wprowadza nowego heksa „ciemniejszego akcentu”. Jeśli przyciemnienie jest potrzebne, jest nowym kluczem w `tokens.color`, nie klasą `bg-accent/80`, która miesza kanał na własną rękę poza paletą. Ten numer nie dokłada siódmego koloru.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/web/src/styles.css` | jedyne wejście: import narzędzia, `@theme inline`, import Inter |
| `src/clients/web/src/main.tsx` | import arkusza i `cssCustomProperties()` na `documentElement` |
| `src/clients/web/vite.config.ts` | plugin `@tailwindcss/vite` |
| `src/clients/web/components.json` | konfiguracja shadcn, alias `@/` |
| `src/clients/web/src/components/ui/button.tsx` | `button` |
| `src/clients/web/src/components/ui/input.tsx` | `input` |
| `src/clients/web/src/components/ui/label.tsx` | `label` |
| `src/clients/web/src/components/ui/textarea.tsx` | `textarea` |
| `src/clients/web/src/components/ui/dialog.tsx` | dialog konfliktu i potwierdzeń |
| `src/clients/web/src/components/ui/tabs.tsx` | zakładki `pl` i `en` w edytorze |
| `src/clients/web/src/components/ui/table.tsx` | listy intranetu |
| `src/clients/web/src/components/ui/badge.tsx` | widoczność |
| `src/clients/web/src/components/ui/sonner.tsx` | komunikat po zapisie |

Nazwy plików shadcn zostają przy nazwie komponentu. Eksport jest nazwany, funkcja, zgodnie z numerem `02`. Jeśli szablon z rejestru wstawi `React.FC` albo domyślny eksport, przy dodaniu poprawiamy na funkcję nazwaną, zanim plik wejdzie do drzewa.

Klasa na elemencie shellu, po tym numerze:

```tsx
export function Shell({ children }: { children: React.ReactNode }) {
  return (
    <>
      <header className="bg-canvas text-ink border-b border-line">
        <nav className="flex gap-5 px-5 py-3">{/* linki */}</nav>
      </header>
      <main className="bg-canvas text-body text-ink">{children}</main>
      <footer className="text-small text-muted px-5 py-4">{/* Footer */}</footer>
    </>
  );
}
```

`gap-5` i `px-5` to dwadzieścia cztery piksele. `py-3` to dwanaście. Żadna z tych liczb nie stoi w `className` jako arbitr.

## Plan

### 1. Plugin i jeden import

Dodaj `tailwindcss` i `@tailwindcss/vite`. W `vite.config.ts` wstaw plugin. W `main.tsx` zaimportuj `./styles.css` i przed renderem ustaw właściwości z `cssCustomProperties()` na `document.documentElement`.

Usuń z drzewa każdy inny import CSS, jeśli jakiś powstał przy starcie Vite. Zostaje jeden.

### 2. Blok motywu

W `styles.css` wklej `@import "tailwindcss"` i `@theme inline` według tabeli mapy. Wartości po prawej to wyłącznie `var(--…)` oraz resety `initial`. Dopisz import `@fontsource-variable/inter`.

Nie kopiuj heksów z `tokens.ts` do arkusza. Nie ustawiaj `--spacing: 0.25rem`.

### 3. shadcn

Uruchom inicjalizację pod Vite i Tailwind v4. Alias `@` wskazuje `src`. Dodaj komponenty z tabeli ścieżek. Po dodaniu przejrzyj `components/ui`: element przycisku zostaje `button`, pole zostaje `input`, etykieta zostaje `label`. Podmień kolory szablonu na klasy z kontraktu (`bg-accent`, `bg-surface`, `text-ink`, `border-line`, `rounded-md`, `rounded-pill`).

`components.json` zostaje w repozytorium, żeby kolejny komponent z rejestru wpadł w ten sam alias.

### 4. Shell i formularz

Nałóż klasy na `Shell`, `LangSwitch` i formularze logowania oraz rejestracji. Błąd pola stoi przy polu, spięty `aria-describedby` albo `aria-invalid`, i korzysta z komponentu etykiety. Tekst błędu pochodzi z `title` w `ProblemDetails`, gdy numer `05` podepnie zapis. W tym numerze widać miejsce na ten tekst, z kluczem `auth.error`, gdy tytułu jeszcze nie ma.

Pusty stan listy, tam gdzie strona już go ma z numeru `02`, dostaje skład karty i `text-muted`. Nie dostaje ilustracji z obcego heksa.

### 5. Sprawdzenie arkusza

Odpal komendy z sekcji Testy. Trafienie heksa w `styles.css` albo w `components/ui` cofa krok 2 albo 3. Trafienie `*.scss` cofa cały numer.

### Co jest do czego

- `styles.css` — jedyne wejście wyglądu webu. Importuje je `main.tsx`. Numer `06` nie importuje tego pliku; składa własną mapę o tych samych nazwach zmiennych.
- `@theme inline` — słownik klas. Wskazuje właściwości z numeru `01` i nie trzyma drugiej wartości.
- `cssCustomProperties()` w `main.tsx` — wstawia heks i jednostki na dokument, zanim powstanie pierwsza klasa.
- `components/ui/button.tsx` i sąsiedzi — kontrolki formularza i intranetu. Wołają je strony, nie odwrotnie.
- `badge.tsx` — plakietka widoczności. Kolor bierze z `accent`, `ink` albo `muted` według klucza `visibility.*`, nie z osobnej palety statusów.
- `@fontsource-variable/inter` — plik kroju na webie. Nazwa rodziny zostaje `Inter`.
- Plugin Vite — sprawia, że jeden import arkusza wystarcza w dev i w buildzie.

## Testy

Wygląd, który da się sprawdzić bez zrzutu ekranu, sprawdzamy tekstem, rolą i tym, że w arkuszu nie ma drugiej palety. Test Vitest nie porównuje pikseli.

| Fakt | Assert |
| --- | --- |
| `login_button_is_a_button` | na `/login` przycisk wysyłki ma rolę `button` i nazwę z `auth.submitLogin` |
| `field_error_is_next_to_the_field` | przy błędzie pole ma `aria-invalid`, a tekst błędu jest w dokumencie |
| `empty_list_shows_chrome` | pusta lista kursów pokazuje `empty.list` |
| `styles_have_no_hex` | komenda `rg` po `styles.css` milczy |
| `ui_has_no_hex` | komenda `rg` po `components/ui` milczy |
| `no_scss_files` | brak plików `*.scss` pod `src/clients/web` |
| `one_css_import` | `rg` po `import` plików CSS w `src` znajduje tylko `styles.css` |

```bash
cd src/clients/web
pnpm exec vitest run
rg -n "#[0-9a-fA-F]{3,8}|[0-9]+px|[0-9]+ms|cubic-bezier" src/styles.css
rg -n --glob '*.scss' . src
```

Pierwsza komenda `rg` po arkuszu ma zero trafień. Druga, po plikach SCSS, też. Szukanie importów:

```bash
rg -n "\.css|\.scss" src/clients/web/src --glob '!**/styles.css'
```

Dozwolone trafienie to linia w `main.tsx`, która importuje `./styles.css`. Inny import arkusza jest błędem.

Test logowania z tego numeru nie wysyła żądania. Sprawdza element i nazwę.

## Zasady

- Jedyny arkusz webu to `src/clients/web/src/styles.css`.
- W arkuszu i w `components/ui` nie ma heksa, piksela, milisekundy ani `cubic-bezier`.
- Nowy plik `*.scss` nie powstaje. `@apply` nie rozłazi się po komponentach.
- `@theme` jest `inline` i po prawej stronie ma `var(--…)` albo `initial`.
- Klasa arbitralna z heksem albo pikselem (`bg-[#9a3412]`, `p-[24px]`, `duration-[250ms]`) nie wchodzi do JSX.
- Maszt to `bg-ink text-canvas`. Przycisk główny to `bg-accent text-surface`.
- shadcn zostaje przy elementach HTML: `button`, `input`, `label`, `textarea`.
- Fokus `focus-visible` zostaje widoczny. `outline-none` bez zastępczego obrysu nie wchodzi.
- Wyłączony przycisk ma atrybut `disabled` i kolor `muted`, nie osobny heks.
- Telefon nie importuje `styles.css`. Dostanie własną mapę w numerze `06`, na te same właściwości.

## Poza zakresem

- Wartości heksów, odstępów i czasów — [01-motyw.md](01-motyw.md).
- Drzewo tras i stopka — [02-web.md](02-web.md).
- Zapis intranetu, konflikt `412` i treść edytora — [04-intranet.md](04-intranet.md). Dialog i tabela z tego numeru są tylko kontrolkami.
- HTML z API — [05-tresc.md](05-tresc.md). Ten numer nie wstawia `dangerouslySetInnerHTML`.
- NativeWind — [06-mobile.md](06-mobile.md).
- Wejście sekcji, maszt w ruchu, `prefers-reduced-motion` — [08-ruch.md](08-ruch.md). Klasa `duration-nav` zostaje dla prostej zmiany koloru.
- Tryb ciemny i klasa `dark:`.
- Tamagui, Sass, drugi zestaw komponentów obok `components/ui`.

## Źródła

- [Tailwind CSS v4: theme variables](https://tailwindcss.com/docs/theme) — `@theme` i `@theme inline`.
- [@tailwindcss/vite](https://tailwindcss.com/docs/installation/using-vite) — plugin przy Vite, jeden import arkusza.
- [shadcn/ui: Vite](https://ui.shadcn.com/docs/installation/vite) — `components.json`, komponenty w repozytorium.
- [shadcn/ui: theming](https://ui.shadcn.com/docs/theming) — zmienne CSS zamiast osobnej palety w komponencie.
- [Fontsource Inter](https://fontsource.org/fonts/inter) — plik kroju, rodzina `Inter`.
- [:focus-visible](https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-visible) — fokus klawiatury zostaje obrysem.

## Gotowe gdy

- `main.tsx` importuje tylko `styles.css` i nakłada `cssCustomProperties()` przed renderem.
- Przycisk logowania jest przyciskiem o nazwie z chromu, pole błędu jest przy polu.
- W `styles.css` i w `components/ui` nie ma heksa ani literału piksela.
- Pod `src/clients/web` nie ma pliku `*.scss`.
- `p-5` w motywie wskazuje `var(--space-5)`, a token `space.5` to `24`.
- `cd src/clients/web && pnpm exec vitest run` kończy się kodem 0.
- `rg -n "#[0-9a-fA-F]{3,8}" src/clients/web/src/styles.css src/clients/web/src/components/ui` nie znajduje trafień.
