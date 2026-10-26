# CSS zamiast SCSS

Łańcuch wyglądu weba jest jeden: React składa HTML5 w JSX, Vite podaje jeden arkusz `src/styles.css`, a wygląd elementów dają klasy Tailwinda na tych znacznikach. Tailwind v4 czyta natywny CSS i nie bierze udziału w kompilacji Sassa. Nowych plików `*.scss` nie ma. `@apply` zostaje rzadkim wyjątkiem w tym jednym CSS.

## Po co

Strona i shell nie dostają własnego arkusza. Selektory, zagnieżdżenia i pliki obok komponentu schodzą z drzewa, a to, co widzi użytkownik, wisi na znaczniku, który ten komponent już renderuje.

Kolejność jest stała:

1. Komponent zwraca HTML5 (`header`, `nav`, `main`, `section`, `article`, `form`, `button`, jeden `h1`). Znaczniki opisuje [html/01-semantyka.md](../html/01-semantyka.md).
2. `src/Clients/web/src/main.tsx` wciąga jeden plik: `src/Clients/web/src/styles.css`.
3. Klasa Tailwinda na tym znaczniku ustawia odstęp, typografię i stan. Katalog klas jest w [02-motyw.md](02-motyw.md), [03-uklad.md](03-uklad.md), [04-typografia.md](04-typografia.md) i [05-stany.md](05-stany.md).

Sass (`sass` `^1.93.2` w devDependencies klienta) kompiluje dziś wejście i arkusze stron. Po zejściu pakiet znika. Dyrektywy `@import "tailwindcss"`, `@theme` i `@apply` są składnią CSS Tailwinda v4. Kompilator Sassa ich nie prowadzi, więc wejście ma rozszerzenie `.css`.

## Wersje i pakiety

| Pakiet | Rola w tym pliku |
| --- | --- |
| `tailwindcss` (v4) i `@tailwindcss/vite` | Przetwarzają `src/styles.css`. Wpięcie i pierwsza klasa: [01-instalacja.md](01-instalacja.md). |
| `vite` `^7.1.9` | Zbiera ten jeden import CSS do bundla. Plugin w [vite/03-pluginy-i-build.md](../vite/03-pluginy-i-build.md). |
| `react` `19.2.3` | Składa JSX, na którym wiszą klasy. |
| `sass` `^1.93.2` | Jest w [package.json](../../../src/Clients/web/package.json) klienta web. W docelowym drzewie go nie ma. |

Menedżer pakietów: pnpm, katalog poleceń: `src/Clients/web`.

## Ścieżki w repo

Docelowe wejście, względem katalogu Vite (`src/Clients/web`):

- `src/styles.css` — jedyny arkusz klienta web
- import w [src/main.tsx](../../../src/Clients/web/src/main.tsx): `import './styles.css';`

Pełna ścieżka arkusza: `src/Clients/web/src/styles.css`.

Dziś wejście jest inne. [src/main.tsx](../../../src/Clients/web/src/main.tsx) importuje [src/styles.scss](../../../src/Clients/web/src/styles.scss). Obok komponentów, pod `src/Clients/web/src/app`, leżą arkusze stron. Każdy (poza jednym plikiem bez importu) jest wciągany z pliku TSX:

| Arkusz | Import |
| --- | --- |
| `src/app/app.scss` | [Shell.tsx](../../../src/Clients/web/src/app/Shell.tsx) |
| `src/app/pages/home/home.scss` | [HomePage.tsx](../../../src/Clients/web/src/app/pages/home/HomePage.tsx) |
| `src/app/pages/cv/cv.scss` | [CvPage.tsx](../../../src/Clients/web/src/app/pages/cv/CvPage.tsx) |
| `src/app/pages/courses/courses.scss` | [CoursesPage.tsx](../../../src/Clients/web/src/app/pages/courses/CoursesPage.tsx) |
| `src/app/pages/courses/course-detail.scss` | [CourseDetailPage.tsx](../../../src/Clients/web/src/app/pages/courses/CourseDetailPage.tsx) |
| `src/app/pages/compendium/compendium.scss` | [CompendiumPage.tsx](../../../src/Clients/web/src/app/pages/compendium/CompendiumPage.tsx) |
| `src/app/pages/compendium/compendium-detail.scss` | [CompendiumDetailPage.tsx](../../../src/Clients/web/src/app/pages/compendium/CompendiumDetailPage.tsx) |
| `src/app/pages/notes/notes.scss` | [NotesPage.tsx](../../../src/Clients/web/src/app/pages/notes/NotesPage.tsx) |
| `src/app/pages/notes/note-detail.scss` | [NoteDetailPage.tsx](../../../src/Clients/web/src/app/pages/notes/NoteDetailPage.tsx) |
| `src/app/pages/login/login.scss` | [AuthForm.tsx](../../../src/Clients/web/src/app/pages/login/AuthForm.tsx) — formularz login i register |
| `src/app/pages/register/register.scss` | Brak importu w TSX. Plik i tak schodzi z repo. |

Liczby kolorów, skali, odstępów, radiusa i czasów zostają w [tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Kontrakt opisuje [motyw.md](../motyw.md). Nazwy utility powstają w `@theme` według [02-motyw.md](02-motyw.md). Pętla `cssCustomProperties()` w `main.tsx` nie jest drugim arkuszem; to, czy zostaje po wejściu `@theme`, rozstrzyga ten plik motywu.

Zmienne shadcn, gdy dojdą, lądują w tym samym `styles.css`. Osobnego wejścia dla komponentów `ui` nie ma ([shadcn/02-motyw.md](../shadcn/02-motyw.md)).

## Tutorial

Zacznij, gdy [01-instalacja.md](01-instalacja.md) jest zrobiona: pakiety Tailwinda są w kliencie, plugin Vite je widzi, a `src/styles.css` zawiera co najmniej:

```css
@import "tailwindcss";
```

Blok `@theme` dopisuje [02-motyw.md](02-motyw.md) do tego samego pliku. Tego bloku nie rozdzielaj na partiale.

### 1. Podmień wejście

W [src/main.tsx](../../../src/Clients/web/src/main.tsx) zostaw import kroju przed arkuszem i zmień sam arkusz:

```tsx
import '@fontsource-variable/inter';
import './styles.css';
```

`import './styles.scss'` schodzi. Vite ma wtedy jeden graf CSS, od `main.tsx`, a nie jedenaście importów ubocznych z komponentów.

### 2. Przenieś wygląd na znaczniki

Dla każdego wiersza tabeli powyżej:

1. Otwórz plik TSX, który importuje arkusz.
2. Usuń linię `import '.….scss'`.
3. Na znacznikach HTML5, które komponent już zwraca, ustaw `className` klasami Tailwinda. Powtórzony układ wyprowadź do komponentu ([react/01-komponenty.md](../react/01-komponenty.md)), nie do nowego pliku stylu.
4. Usuń plik `*.scss`.

Selektory z arkusza nie przepisują się 1:1 do `styles.css`. Preflight włączony przez `@import "tailwindcss"` obejmuje `box-sizing`, marginesy dokumentu i skalowanie obrazków. Reguł dokumentu, które nie mają węzła w JSX, jest mało: `html` i `body` stoją w [index.html](../../../src/Clients/web/index.html). Klasy dokumentu wiszą na `<body>`:

```html
<body class="bg-canvas text-ink antialiased">
```

Nazwy `canvas` i `ink` pochodzą z tokenów przez `@theme`. Skala pisma i tracking są w [04-typografia.md](04-typografia.md).

Klasy ruchu z wejścia SCSS (`.reveal`, `.list-enter`, `.list-leave`) i reguły biblioteki przewijania nie dostają następcy w CSS. Wejście sekcji i zmianę widoku opisuje [motion/01-przejscia.md](../motion/01-przejscia.md).

### 3. Przykład łańcucha

Lista kursów zostaje komponentem. Wygląd karty jest klasą na `article` i linku. Plik `courses.scss` nie powstaje na nowo i nie zostaje obok strony.

```tsx
export function CoursesPage() {
  return (
    <main>
      <header>
        <h1 className="text-h1 text-ink">{section.title}</h1>
        <p className="text-body text-muted">{section.lead}</p>
      </header>
      <ul className="grid gap-6">
        {section.items.map((course) => (
          <li key={course.slug}>
            <article>
              <a className="block text-ink" href={`/${locale}/courses/${course.slug}`}>
                <h2 className="text-h3">{course.title}</h2>
              </a>
            </article>
          </li>
        ))}
      </ul>
    </main>
  );
}
```

`gap-6`, `text-h1` i `text-ink` są skrótem: konkretne utility odstępu, skali i koloru bierz z plików 02–05, zawsze z tokenów (`#f5f5f7`, `#1d1d1f`, `#0071e3`, Inter). W JSX nie ma `style={{ … }}` z hexem i nie ma klasy arbitralnej z drugim kolorem.

### 4. `@apply` — wyjątek w jednym pliku

Domyślna ścieżka to `className` w JSX albo klasa na `<body>` w `index.html`. `@apply` wolno użyć tylko w `src/styles.css`, gdy selektor nie ma węzła, na którym da się powiesić klasę. Nad regułą stoi jedno zdanie, dlaczego klasa w JSX nie ma gdzie wrócić.

```css
@import "tailwindcss";

/* @theme: 02-motyw.md */

@layer base {
  /* ::selection nie jest elementem JSX. */
  ::selection {
    @apply bg-accent text-canvas;
  }
}
```

`@apply` w komponencie, w pliku obok strony, w `*.scss` i w drugim `.css` nie wchodzi. Zagnieżdżanie selektorów w stylu Sassa, `@mixin` i `@use` nie mają następcy: powtórzenie jest komponentem React albo krótką listą klas.

### 5. Zdejmij Sass i sprawdź bramkę

Gdy żaden TSX nie importuje `.scss` i pliki z tabeli są usunięte, w `src/Clients/web`:

```bash
pnpm remove sass
rg -n "\.scss" --glob '!pnpm-lock.yaml' .
find src -name '*.scss'
pnpm build
```

`rg` i `find` kończą się pustym wynikiem. `pnpm build` (`tsc -p tsconfig.json --noEmit && vite build`) przechodzi. Zostawiony import `.scss` albo plik `.scss` oznacza, że zejście jest niedokończone.

## Przypadki użycia

### Pokusa dopisania `page.scss`

Nowy ekran — kolejna sekcja albo późniejszy intranet w tym samym kliencie — kusi plikiem obok strony, na wzór `home.scss` czy `courses.scss`.

Zostaw jeden komponent (albo kilka, gdy ekran ma drugi powód do zmiany). Układ to HTML5 w `return`. Odstęp, szerokość i siatka to klasy z [03-uklad.md](03-uklad.md). Pusto, błąd i hover to klasy z [05-stany.md](05-stany.md). Intranet korzysta z tego samego `styles.css` i tych samych komponentów `ui`, bez `intranet.scss`.

Gdy ta sama grupa klas wraca na dwóch ekranach, wytnij komponent z [react/01-komponenty.md](../react/01-komponenty.md). Plik stylu obok niego nie powstaje.

### Pokusa skopiowania wejścia SCSS do `styles.css`

[styles.scss](../../../src/Clients/web/src/styles.scss) miesza reset, kroje i klatki animacji. Docelowy `styles.css` trzyma `@import "tailwindcss"`, `@theme` i co najwyżej wyjątek `@apply` z komentarzem. Reszta wyglądu stoi na znacznikach. Długi odpowiednik starego wejścia w nowym pliku CSS zamyka łańcuch: klasy przestają być widoczne w JSX, a drugi system selektorów wraca pod inną nazwą.

## Zasady wyglądu

- Jeden arkusz, `src/Clients/web/src/styles.css`. Strona, shell i formularz auth nie dokładają pliku.
- Klasa na znaczniku HTML5. Nazwy kolorów i skali idą z `@theme` spiętego z [tokens.ts](../../../src/Clients/shared/theme/tokens.ts): płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3`, krój Inter.
- Duży oddech, mało ramek i ciemny hero są klasami z plików układu i typografii, na elementach shellu i home.
- `@apply` jest wyjątkiem udokumentowanym w `styles.css`. Zwykły komponent go nie używa.
- Ekran telefonu ma osobne komponenty i NativeWind. Nie współdzieli tego pliku CSS.

## Poza zakresem

- Instalacja `tailwindcss`, `@tailwindcss/vite` i pierwsza klasa na shellu: [01-instalacja.md](01-instalacja.md).
- Mapowanie liczb na `@theme`: [02-motyw.md](02-motyw.md) i [motyw.md](../motyw.md).
- Odstępy, nav, siatka, szerokość artykułu: [03-uklad.md](03-uklad.md).
- Inter, tracking, ciemny hero: [04-typografia.md](04-typografia.md).
- Hover, focus, pusto, błąd, `prefers-reduced-motion`: [05-stany.md](05-stany.md).
- Ruch sekcji i hero: katalog [motion/](../motion/).
- Semantyka znaczników: [html/01-semantyka.md](../html/01-semantyka.md).
- Katalog komponentów shadcn: [shadcn/](../shadcn/). Ten plik pilnuje tylko tego, że shadcn nie otwiera drugiego arkusza.
- NativeWind i ekrany telefonu.

## Gotowe gdy

- Jedyny arkusz klienta web to `src/Clients/web/src/styles.css` z `@import "tailwindcss"`.
- [main.tsx](../../../src/Clients/web/src/main.tsx) importuje `./styles.css`.
- W `src/Clients/web/src` nie ma plików `*.scss` ani importów `.scss`. Tabela arkuszy pod `src/app`, łącznie z `register.scss`, jest pusta.
- `sass` nie występuje w [package.json](../../../src/Clients/web/package.json).
- Nowy ekran dokłada klasy na HTML5 w JSX. Plik `page.scss` nie powstaje.
- `@apply`, jeśli jest, siedzi wyłącznie w `styles.css` i ma komentarz, czemu selektor nie jest węzłem JSX.
- `pnpm build` w `src/Clients/web` przechodzi.
