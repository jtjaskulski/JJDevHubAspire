# Komponenty shadcn na ekranach JJDevHub

## Po co

Ten plik mówi, jak złożyć ekrany klienta web z pięciu komponentów shadcn: przycisku, pola, dialogu, pustego stanu i nawigacji. To specyfikacja pod późniejsze pisanie kodu. React składa HTML5, Vite podaje jeden `src/styles.css`, Tailwind v4 daje klasy, a te komponenty siedzą na tym samym HTML.

Zestaw obsługuje publiczne strony (`pl` / `en`, home, cv, wykłady, kompendium, notatki, login i register) oraz późniejszy CRUD intranetu w tym samym kliencie, gdy treść przejdzie z JSON-a w bundlu do API. Drugiej aplikacji intranetu nie ma. Telefon składa własne ekrany; ten katalog jest dla weba.

Init, `components.json` i alias `@/` opisuje [01-init.md](01-init.md). Zmienne koloru spięte z tokenami opisuje [02-motyw.md](02-motyw.md). Liczby palety są w [motyw.md](../motyw.md).

## Wersje i pakiety

Klient web (`src/Clients/web`) ma już React 19.2.3 i react-router 7. Menedżer pakietów to pnpm. Tailwind v4 jest założeniem z [tailwind/01-instalacja.md](../tailwind/01-instalacja.md); ten plik go nie wstawia.

Komponenty shadcn nie są paczką runtime. CLI `shadcn` ściąga źródła do repozytorium. Preset składania to Radix: zależnością rejestru dla przycisku, dialogu i nawigacji jest pakiet `radix-ui`, a obce elementy wchodzą przez `asChild`. [01-init.md](01-init.md) zostawia ten preset. Przykłady poniżej używają `asChild`.

CLI dopisuje do `package.json` klienta web to, czego żąda rejestr:

- `radix-ui` — prymitywy przycisku, dialogu i menu nawigacji,
- `class-variance-authority`, `clsx`, `tailwind-merge` — warianty i `cn` w plikach `ui`.

Strony importują wyłącznie pliki z `src/components/ui`. Paczek `radix-ui` i `class-variance-authority` strona nie importuje. Osobnej zależności o nazwie `shadcn` w `dependencies` nie ma: CLI idzie przez `pnpm dlx shadcn@latest`.

`Label` dokłada się razem z `Input`, bo pole formularza ma podpis w HTML. Ikony i `Spinner` zostają poza tym zestawem. Stan „w toku” na logowaniu zmienia napis przycisku i ustawia `disabled`.

## Ścieżki w repo

Wszystkie ścieżki komponentów są względem `src/Clients/web`:

| Plik w gicie | Rejestr | Kto go składa |
| --- | --- | --- |
| `src/components/ui/button.tsx` | `button` | shell, hero, formularz, dialog, pusty stan intranetu |
| `src/components/ui/input.tsx` | `input` | login, register, później formularz intranetu |
| `src/components/ui/label.tsx` | `label` | te same formularze |
| `src/components/ui/dialog.tsx` | `dialog` | potwierdzenie usunięcia w intranecie |
| `src/components/ui/empty.tsx` | `empty` | pusta lista wykładów, kompendium, notatek |
| `src/components/ui/navigation-menu.tsx` | `navigation-menu` | pasek shellu |

`src/lib/utils.ts` powstaje przy inicjalizacji i zostaje w gicie. Pliki `ui` mogą z niego brać `cn`. Strony go nie wołają, dopóki wystarcza prop `variant`.

Ekrany, które te pliki konsumują, zostają tam, gdzie są:

- `src/app/Shell.tsx` — nawigacja i przełącznik języka,
- `src/app/pages/home/HomeHero.tsx` — dwa odnośniki CTA,
- `src/app/pages/courses/CoursesPage.tsx`, `src/app/pages/compendium/CompendiumPage.tsx`, `src/app/pages/notes/NotesPage.tsx` — lista albo pusty stan,
- `src/app/pages/home/HomeCourses.tsx` i `src/app/pages/home/HomeNotes.tsx` — ten sam pusty stan, gdy wycinek tablicy jest pusty,
- `src/app/pages/login/AuthForm.tsx` — pola i przycisk; `LoginPage.tsx` i `RegisterPage.tsx` tylko podają napisy i `onSubmit`,
- późniejszy ekran intranetu w `src/app/pages/`, obok tych stron, w tym samym `Shell` i tym samym `App`.

Alias importu to `@/components/ui/button` (oraz `input`, `label`, `dialog`, `empty`, `navigation-menu`). Konfigurację aliasu opisuje [vite/02-aliasy.md](../vite/02-aliasy.md).

## Tutorial

Katalog roboczy komend: `src/Clients/web`. Inicjalizacja z [01-init.md](01-init.md) jest już zrobiona (`components.json`, Tailwind v4, alias `@/`).

### Dodanie zestawu

```bash
pnpm dlx shadcn@latest add button input label dialog empty navigation-menu
```

Po komendzie w repozytorium leżą pliki z tabeli wyżej. `git status` pokazuje je jako źródła do commitu, razem z dopisanymi zależnościami w `package.json`. Implementacja komponentu jest w tym pliku `tsx`, więc zmiana wariantu to edycja w repozytorium i zwykły review. Odświeżenie z rejestru to ponowne `shadcn add` na nazwę komponentu i przeczytanie diffa. Ślepe nadpisanie lokalnej poprawki odpada.

Sprawdzenie, że strona nie sięga do czarnej skrzynki:

```bash
rg -n "from ['\"]radix-ui|from ['\"]shadcn" src/app src/components/ui --glob '!src/components/ui/**'
```

Trafienie w `src/app` oznacza zły import. Jedyny dozwolony import prymitywu `radix-ui` siedzi wewnątrz skopiowanych plików `src/components/ui`.

### Przycisk: akcja i odnośnik

`Button` renderuje `<button>`. Warianty z pliku w repo: `default`, `outline`, `secondary`, `ghost`, `destructive`, `link`. Rozmiar na tych ekranach zostaje `default`. `type` jest jawny: `submit` w formularzu, `button` przy języku i przy anulowaniu dialogu.

Odnośnik react-routera, który ma wyglądać jak przycisk, dostaje `asChild`. `Link` jest jedynym dzieckiem. `viewTransition` zostaje na `Link`, tak jak na pozostałych przejściach widoku.

Hero na home ma dwa wejścia z `pl.json` / `en.json` (`home.ctaCv`, `home.ctaCourses`):

```tsx
import { Link } from 'react-router';

import { Button } from '@/components/ui/button';

type HeroCtaProps = {
  locale: 'pl' | 'en';
  cvLabel: string;
  coursesLabel: string;
};

export function HeroCta({ locale, cvLabel, coursesLabel }: HeroCtaProps) {
  return (
    <p>
      <Button asChild>
        <Link to={`/${locale}/cv`} viewTransition>
          {cvLabel}
        </Link>
      </Button>
      <Button asChild variant="outline">
        <Link to={`/${locale}/courses`} viewTransition>
          {coursesLabel}
        </Link>
      </Button>
    </p>
  );
}
```

`default` jest jednym akcentem (`#0071e3` z tokenów, przez zmienne z [02-motyw.md](02-motyw.md)). `outline` jest drugim wejściem, bez drugiej palety. Ciemne tło hero używa tych samych wariantów. Osobnego `Button` „na czarno” nie ma.

### Formularz logowania

`AuthForm` zostaje wspólnym formularzem `/login` i `/register`. `LoginPage` woła `auth.login` i przechodzi na `/`. `RegisterPage` woła `auth.register`. `fetch` na `/api/auth/login` i `/api/auth/register` zostaje w `src/app/auth/auth.tsx`, zgodnie z [react/03-tresc-i-auth.md](../react/03-tresc-i-auth.md). Pliki `ui` o auth nie wiedzą.

Stan formularza: `email`, `password`, `error`, `pending`. Napis przycisku wylicza się z `pending`, bez drugiego stanu. Błąd z `describeApiError` ląduje w `error` i w `role="alert"`. Oba pola dostają `aria-invalid`, gdy `error` jest ustawiony.

Hasło: `required`, `minLength={8}`, `autoComplete` z propsa (`current-password` na logowaniu, `new-password` na rejestracji). Email: `type="email"`, `autoComplete="username"`, `required`.

```tsx
import { useState, type FormEvent, type ReactNode } from 'react';

import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { describeApiError } from '../../auth/auth';

type AuthFormProps = {
  title: string;
  submitLabel: string;
  pendingLabel: string;
  passwordAutoComplete: 'current-password' | 'new-password';
  hint: ReactNode;
  onSubmit: (email: string, password: string) => Promise<void>;
};

export function AuthForm({
  title,
  submitLabel,
  pendingLabel,
  passwordAutoComplete,
  hint,
  onSubmit,
}: AuthFormProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const invalid = error !== null;
  const buttonLabel = pending ? pendingLabel : submitLabel;

  function setEmailFromInput(value: string): void {
    setEmail(value);
  }

  function setPasswordFromInput(value: string): void {
    setPassword(value);
  }

  async function submit(event: FormEvent): Promise<void> {
    event.preventDefault();
    setPending(true);
    setError(null);
    try {
      await onSubmit(email, password);
    } catch (err) {
      setPending(false);
      setError(describeApiError(err));
    }
  }

  function onFormSubmit(event: FormEvent): void {
    void submit(event);
  }

  return (
    <section>
      <h1>{title}</h1>
      <form onSubmit={onFormSubmit}>
        <Label htmlFor="email">Email</Label>
        <Input
          id="email"
          name="email"
          type="email"
          value={email}
          required
          autoComplete="username"
          aria-invalid={invalid}
          onChange={(event) => setEmailFromInput(event.target.value)}
        />
        <Label htmlFor="password">Password</Label>
        <Input
          id="password"
          name="password"
          type="password"
          value={password}
          required
          minLength={8}
          autoComplete={passwordAutoComplete}
          aria-invalid={invalid}
          onChange={(event) => setPasswordFromInput(event.target.value)}
        />
        {error ? <p role="alert">{error}</p> : null}
        <Button type="submit" disabled={pending}>
          {buttonLabel}
        </Button>
      </form>
      <p>{hint}</p>
    </section>
  );
}
```

`LoginPage` przekazuje `title="Log in"`, `submitLabel="Log in"`, `pendingLabel="Signing in…"`. Podpowiedź to zdanie z odnośnikiem na `/register`. Odnośnik w zdaniu jest `Button` `variant="link"` z `asChild` i `Link`. `RegisterPage` jest lustrzanym układem: „Create account” / „Creating account…” i odnośnik na `/login`. Login i register stoją poza prefiksem języka; napisy tych dwóch stron zostają propsami, a napisy nawigacji i list biorą się z JSON-a.

Wyłączenie przycisku na czas `pending` jest jedyną blokadą podwójnego wysłania. Po udanym `onSubmit` nawigacja odmontowuje formularz. Po błędzie `pending` wraca na `false`, a komunikat zostaje nad przyciskiem.

### Nawigacja w shellu

Pasek to płaska lista pięciu miejsc. `NavigationMenuTrigger` i `NavigationMenuContent` na tym pasku nie występują: nie ma menu rozwijanego.

Pozycje buduje się nad `return` z `siteFor(locale).nav` i ze ścieżek z [react/02-trasy.md](../react/02-trasy.md). Home używa `end`, żeby `/${locale}` nie był aktywny na podstronach.

```tsx
import { NavLink } from 'react-router';

import { Button } from '@/components/ui/button';
import {
  NavigationMenu,
  NavigationMenuItem,
  NavigationMenuLink,
  NavigationMenuList,
} from '@/components/ui/navigation-menu';

type ShellNavItem = {
  to: string;
  label: string;
  end: boolean;
};

type ShellNavProps = {
  items: ShellNavItem[];
  languageLabel: string;
  polishLabel: string;
  englishLabel: string;
  polishPressed: boolean;
  englishPressed: boolean;
  onPolish: () => void;
  onEnglish: () => void;
};

export function ShellNav({
  items,
  languageLabel,
  polishLabel,
  englishLabel,
  polishPressed,
  englishPressed,
  onPolish,
  onEnglish,
}: ShellNavProps) {
  return (
    <header>
      <NavigationMenu aria-label={languageLabel}>
        <NavigationMenuList>
          {items.map((item) => (
            <NavigationMenuItem key={item.to}>
              <NavigationMenuLink asChild>
                <NavLink to={item.to} end={item.end} viewTransition>
                  {item.label}
                </NavLink>
              </NavigationMenuLink>
            </NavigationMenuItem>
          ))}
        </NavigationMenuList>
      </NavigationMenu>
      <div role="group" aria-label={languageLabel}>
        <Button type="button" variant="ghost" aria-pressed={polishPressed} onClick={onPolish}>
          {polishLabel}
        </Button>
        <Button type="button" variant="ghost" aria-pressed={englishPressed} onClick={onEnglish}>
          {englishLabel}
        </Button>
      </div>
    </header>
  );
}
```

`Shell` sam liczy `locale`, woła `switchLocale` i podaje napisy `nav.home`, `nav.cv`, `nav.courses`, `nav.compendium`, `nav.notes`, `nav.language`, `nav.languagePl`, `nav.languageEn`. Aktywny język ma `aria-pressed`. Oba przyciski języka zostają `variant="ghost"`. Marka „JJDevHub” jest osobnym `NavLink` na `/${locale}`, poza listą menu. `main` shellu nadal owija dzieci tras.

Aktywna pozycja menu bierze `aria-current="page"` z `NavLink`. Wygląd aktywnego odnośnika (akcent, bez ramki wokół całego paska) dopina [tailwind/05-stany.md](../tailwind/05-stany.md) na tym atrybucie. Progu „jestem aktywny” nie trzyma się w `useState`.

### Pusty stan listy

Gdy `section.items` jest puste, strona zostawia `h1` i lead, a w miejscu siatki stawia `Empty`. Wczesny `return` dotyczy regionu listy. Cała strona z samym `null` znika razem z tytułem, więc tak się jej nie kończy.

Kopia pustego stanu leży w bundlu, obok tytułu sekcji, w `src/content/pl.json` i `src/content/en.json`:

- `courses.emptyTitle`, `courses.emptyLead`,
- `compendium.emptyTitle`, `compendium.emptyLead`,
- `notes.emptyTitle`, `notes.emptyLead`.

Publiczna strona nie dostaje przycisku „dodaj”. Treść wykładów, haseł i notatek jest w JSON-ie, dopóki intranet jej nie przeniesie do API.

```tsx
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
} from '@/components/ui/empty';

type CourseListProps = {
  title: string;
  lead: string;
  emptyTitle: string;
  emptyLead: string;
  items: readonly { slug: string }[];
};

export function CourseList({ title, lead, emptyTitle, emptyLead, items }: CourseListProps) {
  if (items.length === 0) {
    return (
      <section>
        <header>
          <h1>{title}</h1>
          <p>{lead}</p>
        </header>
        <Empty>
          <EmptyHeader>
            <EmptyTitle>{emptyTitle}</EmptyTitle>
            <EmptyDescription>{emptyLead}</EmptyDescription>
          </EmptyHeader>
        </Empty>
      </section>
    );
  }

  return (
    <section>
      <header>
        <h1>{title}</h1>
        <p>{lead}</p>
      </header>
      {/* siatka kart, gdy items ma wpisy */}
    </section>
  );
}
```

`HomeCourses` i `HomeNotes` używają tej samej pary zdań z `courses` i `notes`. Drugiego kompletu napisów na home nie ma. Pusty sylabus na stronie wykładu (`CourseLessons`, `CourseChapters`) zostawia nagłówek rozdziału i wstawia `Empty` z leadu tego rozdziału, bez przycisku.

`EmptyMedia` zostaje nieużyte, dopóki zestaw nie ma własnej ikony w repo. Paczki ikon pod sam pusty stan nie dokładamy.

### Dialog potwierdzenia

Dialog na publicznych stronach do czytania nie występuje. Pojawia się przy usuwaniu wpisu intranetu. Komponent dostaje nazwę rekordu i funkcję `onConfirm`. Ścieżkę HTTP zna wywołujący ekran; dialog jej nie składa.

`DialogTitle` jest obowiązkowy. `DialogDescription` wymienia nazwę wpisu. Anulowanie to `Button` `variant="outline"` `type="button"`. Potwierdzenie to `Button` `variant="destructive"` `type="button"`, `disabled` na czas żądania. Zamknięcie po udanym `onConfirm` należy do ekranu (kontrolowane `open` / `onOpenChange`).

```tsx
import { Button } from '@/components/ui/button';
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';

type ConfirmDeleteProps = {
  open: boolean;
  title: string;
  recordName: string;
  confirmLabel: string;
  cancelLabel: string;
  pending: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => void;
};

export function ConfirmDelete({
  open,
  title,
  recordName,
  confirmLabel,
  cancelLabel,
  pending,
  onOpenChange,
  onConfirm,
}: ConfirmDeleteProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>{recordName}</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button type="button" variant="outline">
              {cancelLabel}
            </Button>
          </DialogClose>
          <Button type="button" variant="destructive" disabled={pending} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
```

Fokus zostaje w dialogu, dopóki jest otwarty. To daje prymityw z `dialog.tsx`. Osobnej obsługi `Escape` w stronie nie piszemy.

## Przypadki użycia

### Shell: pięć miejsc i język

`header` zawiera markę, `NavigationMenu` i grupę języka. Pozycje: Start `/${locale}`, CV `/${locale}/cv`, Wykłady `/${locale}/courses`, Kompendium `/${locale}/compendium`, Notatki `/${locale}/notes`. Napisy z `nav` w JSON-ie dla `pl` i `en`. Zły język i `*` nadal prowadzą na `/pl`; menu tego nie obsługuje, robi to brama tras.

Przełącznik języka podmienia pierwszy segment ścieżki przez istniejącą funkcję w `Shell`. Przycisk aktywnego języka ma `aria-pressed={true}`. Klik w ten sam język nic nie nawiguje.

### Home: dwa wejścia na ciemnym hero

`home.ctaCv` jest `Button` `default` do CV. `home.ctaCourses` jest `Button` `outline` do listy wykładów. Oba są `Link` przez `asChild`. Sekcje „Wykłady” i „Ostatnie notatki” na dole strony, przy pustej tablicy, pokazują `Empty` z kopii listy. Przy niepustej tablicy zostają kartami-odnośnikami, bez dokładania `Button` na każdą kartę.

### Wykłady, kompendium, notatki

Niepusta lista: siatka odnośników do `/:lang/courses/:slug`, `/:lang/compendium/:slug`, `/:lang/notes/:slug`. Pusta lista: `h1`, lead, `Empty`. Słownik na kompendium (`glossaryLabel`) zostaje zwykłym odnośnikiem zewnętrznym w nagłówku, obok pustego stanu, i nie staje się `Button`.

### Logowanie i rejestracja

Gość na `/login` widzi `h1`, dwa pola z podpisami, przycisk submit i zdanie z odnośnikiem na `/register`. Błędna odpowiedź API zostawia go na formularzu z `role="alert"`. Poprawne logowanie idzie na `/`. `/register` używa tego samego `AuthForm` z innymi napisami i `autoComplete="new-password"`.

Pola i przycisk pochodzą z `input.tsx`, `label.tsx` i `button.tsx` w repo. Walidacja długości hasła to atrybut `minLength` na polu. Komunikat serwera to akapit, nie dialog.

### Intranet później, ten sam zestaw

Gdy wykłady, kompendium albo notatki przestaną być wyłącznie JSON-em bundla i wejdą do API, CRUD staje w tym samym `src/Clients/web`, w tym samym `Shell` i na tych samych plikach `ui`. Osobnego klienta, osobnego katalogu komponentów i osobnej palety pod intranet nie budujemy.

| Czynność | Skład |
| --- | --- |
| Pusta lista u redaktora | Ten sam `Empty`, a w `EmptyContent` jeden `Button` „dodaj”, którego publiczna strona nie renderuje |
| Nowy i edycja | `Label` + `Input` + `Button` `type="submit"`, ten sam układ co login: stan pól, `pending`, `role="alert"` |
| Usunięcie | `ConfirmDelete` na `dialog.tsx`, potwierdzenie `variant="destructive"` |
| Powrót do listy | `Button` `variant="link"` z `asChild` i `Link` |

`onConfirm` i zapis formularza wołają `fetch` tak jak auth: zwykłe żądanie do API, token z istniejącego kontekstu auth. Kontrakt ścieżek zostaje przy API. Do czasu tej przeprowadzki listy publiczne czytają `pl.json`, `en.json` i wygenerowany `cv.json`, a dialog usuwania nie ma ekranu, który by go otwierał.

`cv.local.json` zostaje poza gitem. Formularz CV w przeglądarce nie powstaje razem z tym zestawem.

## Zasady wyglądu

Kolory, skala, odstępy, radius i czasy biorą się z `src/Clients/shared/theme/tokens.ts`. Na ekranie widać płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3` i krój Inter. Ciemny hero używa tej samej pary przycisków. Drugiej palety w `button.tsx` ani w klasie arbitralnej na stronie nie dopisujemy. Mapowanie na zmienne shadcn jest w [02-motyw.md](02-motyw.md).

Duży oddech i mało ramek: pasek nawigacji, karta formularza i dialog nie dostają obwódki „na wszelki wypadek”. Dialog jest powierzchnią na płótnie, ze skupieniem na tytule i dwóch akcjach. Pusty stan jest typografią (`EmptyTitle`, `EmptyDescription`), bez ilustracji.

Wariant na ekranie:

| Miejsce | Wariant |
| --- | --- |
| Zapis, logowanie, główne CTA hero | `default` |
| Drugie CTA hero, anulowanie dialogu | `outline` |
| Język w shellu | `ghost`, wybór przez `aria-pressed` |
| Odnośnik w zdaniu, powrót do listy | `link` |
| Potwierdzenie usunięcia | `destructive` |

`secondary` zostaje w pliku komponentu, bo tak przychodzi z rejestru. Ekrany JJDevHub go nie używają, żeby obok akcentu nie stanął trzeci przycisk.

Stany hover, focus-visible, disabled i błąd pola opisuje [tailwind/05-stany.md](../tailwind/05-stany.md). Ten plik wymaga tylko, żeby `disabled` na submit i na potwierdzeniu był prawdziwym atrybutem, a błąd formularza miał `role="alert"` oraz `aria-invalid` na polach. `prefers-reduced-motion` nie zmienia zestawu komponentów.

Znaczniki: `header` i `nav` (przez menu) w shellu, jeden `h1` na stronie, `form` wokół pól logowania, `button` albo `a` po złożeniu `asChild`. Siatkę, szerokość artykułu i odstępy klasami Tailwinda opisuje [tailwind/03-uklad.md](../tailwind/03-uklad.md).

## Poza zakresem

- Inicjalizacja CLI, `components.json` i katalog `ui` jako taki: [01-init.md](01-init.md).
- Zmienne CSS, odejście od domyślnego szarego szablonu, radius: [02-motyw.md](02-motyw.md) i [motyw.md](../motyw.md).
- Trasy, locale i przełączanie pierwszego segmentu: [react/02-trasy.md](../react/02-trasy.md).
- Skąd strona bierze JSON i gdzie jest `fetch`: [react/03-tresc-i-auth.md](../react/03-tresc-i-auth.md).
- Układ, typografia i stany interakcji klasami: katalog [tailwind/](../tailwind/01-instalacja.md).
- Wejścia sekcji i hero-scroll: katalog [motion/](../motion/01-przejscia.md).
- Telefon, NativeWind i kopia komponentów na React Native: [nativewind/01-instalacja.md](../nativewind/01-instalacja.md) i [reusables.md](../reusables.md). Tamagui jest poza specyfikacją.
- Biblioteki formularza (`react-hook-form`, Zod), toast, sheet, sidebar, tabela i menu rozwijane. Login zostaje na `useState` w `AuthForm`.
- Drugi klient intranetu i drugi zestaw przycisków.

## Gotowe gdy

- `button.tsx`, `input.tsx`, `label.tsx`, `dialog.tsx`, `empty.tsx` i `navigation-menu.tsx` leżą w `src/Clients/web/src/components/ui` i są w gicie. Import ekranu wskazuje te pliki przez `@/`.
- Shell pokazuje pięć miejsc z JSON-a jako `NavigationMenuLink` oraz dwa przyciski języka z `aria-pressed`.
- `/login` i `/register` składają się z `Label`, `Input` i `Button`; błąd API jest w `role="alert"`; udane logowanie schodzi z formularza na `/`.
- Pusta lista wykładów, kompendium i notatek pokazuje `Empty` z kopii `pl.json` / `en.json` i zostawia `h1`. Publiczny pusty stan nie ma przycisku dodawania.
- Usuwanie w przyszłym intranecie jest opisane jako `Dialog` na tych samych plikach, w tym samym kliencie web, wołane dopiero gdy treść jest w API.
- Strony w `src/app` nie importują `radix-ui` ani paczki `shadcn`.
