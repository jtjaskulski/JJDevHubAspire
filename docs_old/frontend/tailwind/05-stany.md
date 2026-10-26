# Stany

Hover, focus klawiatury, wyłączenie, pusta lista, błąd pola i `prefers-reduced-motion` są częścią wyglądu JJDevHub. Ten plik mówi, jakimi klasami Tailwind v4 je narysować na webie, żeby późniejszy kod miał jeden kontrakt na linku, polu i pustej liście.

Liczby kolorów, czasu i krzywej są w [motyw.md](../motyw.md). Nazwy tych liczb w `@theme` są w [02-motyw.md](02-motyw.md). Wejście arkusza jest w [01-instalacja.md](01-instalacja.md). Odstępy i szerokości są w [03-uklad.md](03-uklad.md), skala pisma w [04-typografia.md](04-typografia.md). Znaczniki, na których wiszą klasy, opisuje [html/01-semantyka.md](../html/01-semantyka.md).

## Wersje i pakiety

- Tailwind CSS v4: pakiety `tailwindcss` i `@tailwindcss/vite`, już wpięte według [01-instalacja.md](01-instalacja.md). Stany z tego pliku są wariantami rdzenia. Osobnego pakietu do hover, focus, disabled ani reduced motion się nie dodaje.
- Warianty używane tutaj: `hover:`, `focus-visible:`, `disabled:`, `aria-invalid:`, `aria-[current=page]:`, `motion-reduce:`.
- React 19 i `react-router` 7. `NavLink` sam ustawia `aria-current="page"` na bieżącej trasie.
- `@tailwindcss/forms` zostaje poza projektem. Pole i przycisk dostają klasy na własnym znaczniku. Gdy powstanie komponent z [shadcn/03-komponenty.md](../shadcn/03-komponenty.md), te same klasy siedzą w `src/Clients/web/src/components/ui`, a ekran ich nie powtarza.

Przykłady klas zakładają nazwy z mapowania tokenów: `ink`, `accent`, `muted`, `canvas`, `white`, `duration-nav`, `ease-standard`. Deklaracja jest w [02-motyw.md](02-motyw.md). W `className` zostają te nazwy. Heks z palety (`#f5f5f7`, `#1d1d1f`, `#0071e3`) do klasy arbitralnej nie wchodzi.

## Ścieżki w repo

| Co | Gdzie |
| --- | --- |
| Jedyny arkusz, `@import "tailwindcss"` | `src/Clients/web/src/styles.css` |
| Linki nawigacji i przełącznik języka | `src/Clients/web/src/app/Shell.tsx` |
| Pole, komunikat błędu, przycisk wysyłki | `src/Clients/web/src/app/pages/login/AuthForm.tsx` |
| Logowanie i rejestracja, ten sam formularz | `src/Clients/web/src/app/pages/login/LoginPage.tsx`, `src/Clients/web/src/app/pages/register/RegisterPage.tsx` |
| Lista wykładów i gałąź pusta | `src/Clients/web/src/app/pages/courses/CoursesPage.tsx` |
| Zdanie pustej listy, `pl` i `en` | `src/Clients/web/src/content/pl.json`, `src/Clients/web/src/content/en.json` |
| Kolory, `duration.nav` (250 ms), `easing.standard` | `src/Clients/shared/theme/tokens.ts` |

`LoginPage` i `RegisterPage` tylko podają etykiety i `onSubmit`. Wygląd stanów jest w `AuthForm`.

## Tutorial

Żadna komenda z tego pliku nie instaluje pakietu. Serwer deweloperski, port 4200 i proxy opisuje [vite/01-dev.md](../vite/01-dev.md).

```bash
cd src/Clients/web
pnpm start
```

Aplikacja wstaje na `http://localhost:4200`. Dalej w tym tutorialu są klasy docelowe i sprawdzenie ich w przeglądarce.

Czas przejścia koloru to token `duration.nav`: 250 ms, krzywa `easing.standard` (`cubic-bezier(0.4, 0, 0.2, 1)`). W klasach: `duration-nav` i `ease-standard`. Właściwość przejścia to `transition-colors`. Przejście obejmuje kolor tekstu, tła i kreski, a układ zostaje w miejscu.

W Tailwindzie v4 warstwa wariantu rozstrzyga konflikt, nie kolejność klas w `className`. Przy wyłączonym przycisku dopisz jawnie `disabled:hover:…`, żeby hover nie wrócił do koloru aktywnego.

### Hover

Hover zmienia kolor. Link na płótnie (`#f5f5f7`) stoi w atramencie (`#1d1d1f`) i po najechaniu przechodzi w akcent (`#0071e3`). Bieżąca trasa jest akcentem już w spoczynku, bo `NavLink` wystawia `aria-current="page"`.

Hover nie dodaje cienia, przesunięcia, skali ani ramki. Informacja, która ma być widoczna bez myszy (bieżąca strona, błąd, pusta lista), ma własny stan opisany niżej.

Na ciemnym hero tekst w spoczynku bierze kolor pierwszego planu rozdziału (`darkChapter.foreground`, `#f5f5f7`), a hover przechodzi na ten sam akcent. Nawigacja w `Shell` stoi na płótnie. Jeden link nie łączy klas płótna i hero.

Wspólny zestaw linku w `Shell`:

```tsx
const navLinkClass =
  'text-ink transition-colors duration-nav ease-standard motion-reduce:transition-none hover:text-accent focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-accent aria-[current=page]:text-accent';
```

`home`, `cv`, `courses`, `compendium`, `notes` i marka dostają ten sam łańcuch. Przyciski języka (`PL`, `EN`) dostają ten sam hover i ten sam pierścień. Wciśnięty język ma `aria-pressed="true"` i `text-accent`.

### Focus-visible

Pierścień jest dla klawiatury. Wariant to `focus-visible:`. Obrys ma 2 px, kolor akcentu, odsunięcie 4 px na linku tekstowym i 2 px na polu oraz przycisku. Odsunięcie pokazuje tło pod spodem, więc na płótnie widać `#f5f5f7`, a na czarnym hero `#000000`.

`outline-none` występuje w parze z `focus-visible:outline-2`. Samo wycięcie obrysu zostawia kontrolkę bez śladu fokusu.

Sprawdzenie: na `http://localhost:4200/pl` naciśnij Tab. Pierścień akcentu wędruje po marce, linkach i `PL`/`EN`. Klik myszą w link nie zostawia pierścienia po przejściu.

### Disabled

Wyłączenie jest atrybutem `disabled` na przycisku, a klasy tylko je rysują. W `AuthForm` przycisk wysyłki ma `disabled={pending}`. Na czas żądania etykieta przechodzi na `pendingLabel` z propsów (`Signing in…` na logowaniu). Poprzedni komunikat błędu znika w tym samym momencie, w którym `pending` staje się prawdziwe.

Wyłączony przycisk:

- tło `muted` (`#6e6e73`), tekst `white`,
- `disabled:cursor-wait`,
- `disabled:hover:bg-muted`, żeby hover nie podmienił tła,
- ten sam pierścień `focus-visible`, dopóki fokus jest jeszcze na przycisku; po `disabled` przeglądarka zdejmuje go z sekwencji Tab.

`pointer-events-none` na ten przycisk nie wchodzi: atrybut `disabled` już blokuje wysyłkę, a kursor oczekiwania ma zostać widoczny.

Pola e-maila i hasła w trakcie `pending` zostają edytowalne. Wyłącza się sam przycisk. Gdy pole kiedyś dostanie `disabled` (przyszły formularz intranetu), używa tego samego rysunku: tekst `muted`, `disabled:cursor-not-allowed`, `disabled:opacity-100`. Kursor `wait` zostaje przy wysyłce, `not-allowed` przy polu trwale niedostępnym.

```tsx
<button
  type="submit"
  disabled={pending}
  className="bg-accent text-white transition-colors duration-nav ease-standard motion-reduce:transition-none hover:bg-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:bg-muted disabled:text-white disabled:cursor-wait disabled:hover:bg-muted"
>
  {buttonLabel}
</button>
```

Hover aktywnego przycisku idzie z akcentu w atrament. Poza tym przycisk nie dostaje cienia ani unoszenia.

### Pusto

Pusta lista wykładów jest gałęzią renderu, nie pseudoklasą CSS. `CoursesPage` czyta `items` z JSON-a w bundlu (`pl.json` / `en.json`), bez HTTP. Gdy `section.items.length === 0`, siatka kart się nie renderuje. Zostaje nagłówek strony (jeden `h1` z `section.title`, lead) i jedno zdanie.

Zdanie żyje w treści locale, w obu plikach, obok `title` i `lead`:

- `pl.json`: `courses.empty` = `Nie ma jeszcze wykładów.`
- `en.json`: `courses.empty` = `There are no courses yet.`

Typ `CoursesSection` w `src/Clients/web/src/app/content/content.model.ts` dostaje pole `empty: string`. Komponent early-returnuje samą siatkę, a tytuł strony zostaje. Wzorzec wczesnego returnu jest w [react/01-komponenty.md](../react/01-komponenty.md).

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
      {section.items.length === 0 ? (
        <p className="text-small text-muted">{section.empty}</p>
      ) : (
        <div>{/* karty, układ w 03-uklad.md */}</div>
      )}
    </section>
  );
}
```

`text-small` to stopień `font.size.small` (14 px) z [04-typografia.md](04-typografia.md), nie domyślne `text-sm` Tailwinda. Zdanie jest kolorem `muted`. Bez ramki, bez przerywanej obwódki, bez ikony i bez `role="alert"` — to treść strony, nie nagły błąd.

Siatka z zeroma dziećmi nie zostaje w DOM „na zapas”. Odstęp między leadem a zdaniem bierze skalę z [03-uklad.md](03-uklad.md).

Wysłany `pl.json` ma wykłady, więc gałąź pusta na `/pl/courses` w codziennym dev się nie pokaże. Sprawdzenie jest w teście albo na chwilowym pustym `items`: widać `h1` „Wykłady” i zdanie, a kart nie ma. Test opisuje [react/04-testy.md](../react/04-testy.md) i sprawdza tekst, który widzi użytkownik.

### Błąd pola

Błąd jest zdaniem przy polu, powiązanym z nim przez ARIA. Kolor zdania i kreski pola to akcent. Osobnego koloru błędu w `tokens.ts` nie ma, więc ten plik go nie wprowadza.

Dwa kształty odpowiedzi z `describeApiError` (`src/Clients/web/src/app/auth/api-error.ts`):

1. Odpowiedź ma `errors` z kluczem pola (`Email`, `Password`). Zdanie stoi pod tym polem. `aria-invalid={true}` i `aria-describedby` wskazują ten akapit.
2. Jeden komunikat bez podziału na pola (status 401, „Invalid email or password.”, albo inny tekst złożony przez `describeApiError`). Jeden akapit `role="alert"` pod oboma polami. Oba inputy mają `aria-invalid={true}` i `aria-describedby` na ten sam `id`.

Treść zdań zostaje w `describeApiError` i w propsach formularza. Tu jest miejsce i rysunek.

```tsx
const emailErrorId = 'login-email-error';
const formErrorId = 'login-form-error';

<input
  name="email"
  type="email"
  aria-invalid={emailInvalid ? true : undefined}
  aria-describedby={emailDescribedBy}
  className="border border-ink/15 bg-canvas text-ink outline-none transition-colors duration-nav ease-standard motion-reduce:transition-none focus-visible:border-accent focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent aria-invalid:border-accent disabled:text-muted disabled:cursor-not-allowed"
/>;

{
  emailError ? (
    <p id={emailErrorId} role="alert" className="text-small text-accent">
      {emailError}
    </p>
  ) : null;
}
```

Kreska spoczynkowa to ten sam atrament o niskiej nieprzezroczystości (`border-ink/15`). Focus i `aria-invalid` zamieniają ją na pełny akcent. `border-ink/15` czyta token `--color-ink`, nie nowy heks.

Hasło ma ten sam zestaw klas i własny `id` komunikatu, gdy błąd dotyczy hasła. Atrybuty `required`, `type="email"` i `minLength={8}` zostają. Komunikat, który rysujemy, jest tym z API po wysłaniu formularza.

Sprawdzenie na `http://localhost:4200/login` (trasa bez prefiksu języka, tak samo `/register`):

1. Wyślij nieprawidłowe dane. Pod polami widać zdanie akcentem, pola mają kreskę akcentu, czytnik dostaje alert.
2. Wyślij ponownie. Na czas `pending` zdanie znika, przycisk ma tło `muted` i `pendingLabel`.
3. Po odpowiedzi przycisk wraca do akcentu, a zdanie wraca razem z `aria-invalid`.

### prefers-reduced-motion

`motion-reduce:` w Tailwindzie v4 jest media query `prefers-reduced-motion: reduce`. Na linku, polu i przycisku z tego pliku stoi `motion-reduce:transition-none`. Kolor stanu nadal się zmienia (hover, bieżąca trasa, kreska błędu, tło disabled). Znika 250 ms przejścia. Pierścień `focus-visible` zostaje i pojawia się od razu.

Ręczna media query w `src/styles.css` jest zbędna dla tych sześciu stanów. Wariant na elemencie wystarcza. Komponent nie czyta `matchMedia` po to, żeby wyłączyć kolor.

Sprawdzenie w narzędziach przeglądarki: Rendering → emulacja `prefers-reduced-motion: reduce`. Najedź na „Wykłady” w nawigacji. Kolor przechodzi w akcent bez fade. Tab nadal rysuje obrys. Wyłącz emulację: fade 250 ms wraca.

Wejścia sekcji, zmiana widoku i wyłączenie ruchu w bibliotece Motion są w [motion/01-przejscia.md](../motion/01-przejscia.md). Scroll hero na home jest w [motion/02-hero.md](../motion/02-hero.md). Ten plik obejmuje przejścia klas na kontrolkach.

## Przypadki użycia

### Link w nawigacji

`Shell` maluje markę, pięć linków (`/:lang`, `cv`, `courses`, `compendium`, `notes`) i parę `PL`/`EN`. Każdy link dostaje `navLinkClass` z tutorialu. Bieżący link jest akcentem przez `aria-[current=page]:text-accent`, bez pigułki i bez tła. Hover na bieżącym linku zostawia akcent. Focus klawiatury dokłada obrys, mysz po kliknięciu go nie zostawia.

Przełącznik języka używa tych samych klas hover i focus. Aktywny język: `aria-pressed="true"` i `text-accent`.

Na ciemnym hero inny link (przycisk CTA home) używa koloru pierwszego planu rozdziału i tego samego akcentu w hover oraz focus. Nawigacja shella tego zestawu nie dziedziczy.

### Input logowania

`AuthForm` obsługuje logowanie i rejestrację. Pole e-mail, pole hasła i przycisk `type="submit"` mają klasy z sekcji disabled, focus-visible i błąd pola. Etykiety zostają w `<label>` nad inputem. Komunikat jest akapitem pod polem albo jeden alert pod formularzem, zawsze `text-small text-accent`.

Gdy `pending` jest prawdziwe, przycisk jest `disabled`, ma tło `muted` i kursor `wait`, a poprzedni alert znika. Pola zostają w sekwencji Tab.

### Pusta lista kursów

`CoursesPage` przy `items.length === 0` zostawia `h1` i lead, rysuje `section.empty` jako `text-small text-muted` i nie renderuje siatki. Tekst pochodzi z `pl.json` albo `en.json` według locale w URL. Ta sama gałąź obowiązuje listę notatek i kompendium, gdy ich `items` jest puste: jedno zdanie w `muted`, bez karty-zaślepki. Przypadek, który domyka ten plik, to wykłady.

## Zasady wyglądu

- Paleta stanu to tokeny: płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, `muted` `#6e6e73`, biel, pierwszy plan ciemnego rozdziału. Czas 250 ms i krzywa `standard` też pochodzą z `tokens.ts`.
- Duży oddech i mało ramek zostają. Ramka, która tu występuje, to kreska pola: cienka w spoczynku, akcent przy focus i przy `aria-invalid`. Link nawigacji ramki nie dostaje.
- Hover i zmiana disabled ruszają kolorem (`transition-colors`), przez `duration-nav` i `ease-standard`.
- Focus klawiatury jest obrysem akcentu (`focus-visible`), z odsunięciem. Na hero odsunięcie odsłania czerń rozdziału.
- Disabled przy wysyłce: tło `muted`, tekst biały, `cursor-wait`, hover zamrożony na tym tle. Etykieta mówi, że żądanie trwa.
- Pusto: jedno zdanie `muted` w rozmiarze `small`, pod nagłówkiem strony, bez karty.
- Błąd pola: zdanie `small` w akcencie, `role="alert"`, `aria-invalid` i `aria-describedby` na polu. Kreska pola w akcencie.
- `motion-reduce:transition-none` stoi na każdej kontrolce, która ma `transition-colors`. Kolor i obrys zostają, czas przejścia spada do zera.
- Przyszły formularz intranetu w tym samym kliencie używa tego samego pola, alertu i disabled. Drugiego rysunku błędu nie będzie.

## Poza zakresem

- Instalacja Tailwinda, `@import "tailwindcss"` i zamiana wejścia arkusza — [01-instalacja.md](01-instalacja.md).
- Deklaracja `@theme` i siatka nazw — [02-motyw.md](02-motyw.md). Kontrakt liczb — [motyw.md](../motyw.md).
- Siatka kart, szerokość artykułu, nav jako układ — [03-uklad.md](03-uklad.md).
- Inter, skala, tracking, ciemny hero jako typografia — [04-typografia.md](04-typografia.md).
- Wejścia sekcji, zmiana widoku i reduced motion po stronie biblioteki Motion — [motion/01-przejscia.md](../motion/01-przejscia.md). Scroll hero — [motion/02-hero.md](../motion/02-hero.md).
- Ekran listy na telefonie, w tym pusty stan NativeWind — [nativewind/02-ekrany.md](../nativewind/02-ekrany.md). Ten plik jest tylko dla weba.
- Skład `button` i `input` w `components/ui` — [shadcn/03-komponenty.md](../shadcn/03-komponenty.md). Dopóki ich nie ma, klasy są na znacznikach w `Shell` i `AuthForm`.
- Testy obecności klas narzędziowych. Test widzi zdanie puste, tekst alertu i przycisk wyłączony w trakcie wysyłki — [react/04-testy.md](../react/04-testy.md).
- Tłumaczenie komunikatów z `describeApiError`. Zostają w module auth; tu jest ich miejsce na formularzu.
- Osobny heks błędu, plugin `@tailwindcss/forms`, ręczny `@media (prefers-reduced-motion)` w `styles.css` dla tych stanów, `matchMedia` w komponencie dla koloru, cień i unoszenie na hover.

## Gotowe gdy

- Link w `Shell` (marka i pięć pozycji) ma `hover:text-accent`, obrys `focus-visible` w akcencie i `aria-[current=page]:text-accent`. Przejście to `transition-colors duration-nav ease-standard` oraz `motion-reduce:transition-none`.
- `PL`/`EN` mają ten sam hover i focus. Wybrany język ma `aria-pressed="true"` i kolor akcentu.
- Tab po nawigacji pokazuje pierścień. Klik myszą go nie zostawia. Przy emulacji `prefers-reduced-motion: reduce` kolor hover zmienia się bez 250 ms fade, a pierścień zostaje.
- Przycisk wysyłki w `AuthForm` przy `pending` ma `disabled`, tło `muted`, tekst biały, `cursor-wait` i `disabled:hover:bg-muted`. Etykieta to `pendingLabel`. Pola zostają edytowalne.
- Po błędzie API widać akapit `text-small text-accent` z `role="alert"`. Pole wskazane przez komunikat (albo oba pola przy jednym zdaniu) ma `aria-invalid` i `aria-describedby`. Kreska pola jest akcentem. Na czas kolejnego `pending` alert znika.
- W klasach stanu nie ma heksa spoza tokenów i nie ma koloru błędu spoza akcentu, atramentu, `muted`, bieli i płótna.
- `CoursesPage` przy pustym `items` pokazuje `h1`, lead i `courses.empty` z JSON-a bieżącego języka (`Nie ma jeszcze wykładów.` / `There are no courses yet.`) w `text-small text-muted`. Siatki kart w DOM nie ma.
- `LoginPage` i `RegisterPage` korzystają z tego samego `AuthForm`, więc oba formularze wyglądają tak samo w focus, disabled i błędzie.
