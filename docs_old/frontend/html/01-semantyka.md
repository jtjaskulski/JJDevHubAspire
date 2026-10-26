# Semantyka HTML5 w JSX

## Po co

React 19 składa ekrany JJDevHub ze znaczników HTML5. Znacznik niesie rolę: baner, nawigację, treść główną, sekcję, artykuł, listę, formularz, przycisk. Czytnik ekranu, test i kolejny generator kodu czytają to drzewo, zanim zobaczą klasę.

Łańcuch webu: React składa ten HTML, Vite podaje jeden CSS, Tailwind v4 dokłada klasy na tych samych znacznikach, shadcn i Motion zostają na tym samym drzewie. Ten plik jest kontraktem drzewa. Klasy układu, typografia i stany są w katalogu [Tailwind](../tailwind/03-uklad.md).

Ekrany telefonu są osobne i nie używają tych znaczników. Web zostaje przy `pl`/`en`, trasach home, cv, courses, compendium, notes oraz login i register poza prefiksem języka.

## Wersje i pakiety

HTML5 nie ma tu osobnego pakietu. Dokument otwiera `<!doctype html>`.

| Warstwa | Wersja w kliencie web | Rola przy tym HTML |
| --- | --- | --- |
| React, react-dom | 19.2.3 | JSX zamienia się w te elementy |
| react-router | 7.9.4 | `Link` i `NavLink` renderują `<a>`, `NavLink` ustawia `aria-current="page"` |
| Vite | 7.1.9 | serwuje dokument i jeden arkusz |
| Tailwind CSS | v4, docelowo | `className` na znacznikach z tego pliku |

Wejście stylów docelowo: `src/styles.css`. Wpięcie arkusza opisuje [instalacja Tailwinda](../tailwind/01-instalacja.md), zejście z Sassa opisuje [jeden CSS](../tailwind/06-css-zamiast-scss.md). Liczby koloru, skali i odstępu siedzą w [`src/Clients/shared/theme/tokens.ts`](../../../src/Clients/shared/theme/tokens.ts) i w [motywie](../motyw.md).

## Ścieżki w repo

| Ścieżka | Co ustala dla HTML |
| --- | --- |
| [`src/Clients/web/index.html`](../../../src/Clients/web/index.html) | dokument, `lang` startowy, `#root` |
| [`src/Clients/web/src/main.tsx`](../../../src/Clients/web/src/main.tsx) | montuje aplikację w `#root` |
| [`src/Clients/web/src/app/Shell.tsx`](../../../src/Clients/web/src/app/Shell.tsx) | baner, dwie nawigacje, `main`, stopka, `lang` na `<html>` |
| [`src/Clients/web/src/app/App.tsx`](../../../src/Clients/web/src/app/App.tsx) | shell owija trasy; tabela tras jest w [trasach](../react/02-trasy.md) |
| `src/Clients/web/src/app/pages/` | jeden widok w `main`: sekcja albo artykuł |
| `src/Clients/web/src/content/pl.json`, `en.json` | widoczny tekst nawigacji i sekcji |
| `src/Clients/web/src/app/pages/login/AuthForm.tsx` | wspólne drzewo formularza logowania i rejestracji |

Kształt pliku komponentu (jeden plik, JSX jako układ) jest w [komponentach](../react/01-komponenty.md). Skąd bierze się JSON i kiedy pada `fetch`, jest w [treści i auth](../react/03-tresc-i-auth.md).

## Tutorial

### Dokument

`index.html` zostaje krótki. `lang="pl"` jest stanem sprzed pierwszego renderu. Po starcie shell wpisuje na `<html>` język z pierwszego segmentu URL: `pl` albo `en`. Na `/login` i `/register` pierwszy segment nie jest locale, więc `lang` zostaje `pl`.

```html
<!doctype html>
<html lang="pl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>JJDevHub</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

`div#root` jest węzłem `createRoot`. Nie dostaje roli landmarku i nie zastępuje `header` ani `main`. Drugiego opakowania wokół aplikacji w `body` nie ma.

Widok ustawia `document.title` na tekst swojego `h1`, pauzę typograficzną i nazwę serwisu: `Dlaczego CQRS już na laboratorium — JJDevHub`. Strona startowa bierze tekst z `h1` hero, czyli imię z CV. Zanim React wstanie, tytuł z `index.html` brzmi `JJDevHub`.

### Drzewo landmarków

Na każdej trasie, także na logowaniu i rejestracji, shell renderuje jedno drzewo. `header` shella nie leży w `main`, `section` ani `article`, więc w drzewie dostępności jest banerem. `header` wewnątrz artykułu albo sekcji banerem nie jest — to nagłówek tego fragmentu.

```tsx
<>
  <a href="#tresc">{nav.skip}</a>
  <header>
    <NavLink to={`/${locale}`} end>
      JJDevHub
    </NavLink>
    <nav aria-label={nav.primary}>
      <NavLink to={`/${locale}`} end>
        {nav.home}
      </NavLink>
      <NavLink to={`/${locale}/cv`}>{nav.cv}</NavLink>
      <NavLink to={`/${locale}/courses`}>{nav.courses}</NavLink>
      <NavLink to={`/${locale}/compendium`}>{nav.compendium}</NavLink>
      <NavLink to={`/${locale}/notes`}>{nav.notes}</NavLink>
    </nav>
    <nav aria-label={nav.language}>
      <button type="button" aria-pressed={locale === 'pl'} onClick={showPolish}>
        {nav.languagePl}
      </button>
      <button type="button" aria-pressed={locale === 'en'} onClick={showEnglish}>
        {nav.languageEn}
      </button>
    </nav>
  </header>
  <main id="tresc">{children}</main>
  <footer>
    <p>JJDevHub</p>
  </footer>
</>
```

Reguły tego drzewa:

- Jeden `main` na dokument. Widok strony jest dzieckiem `main` i drugiego `main` nie otwiera.
- Dwa `nav` mają różne nazwy. Menu główne i przełącznik języka inaczej brzmią w czytniku.
- Link „Start” ma `end`, żeby `aria-current="page"` na `/pl` gasło na `/pl/cv` i dalej. Zostawienie stanu wyłącznie w klasie CSS nie wystarcza.
- Przełącznik języka to `button type="button"`. Zmienia pierwszy segment ścieżki w miejscu; mechanizm jest w [trasach](../react/02-trasy.md). Aktywny język ma `aria-pressed="true"`.
- Odnośnik pomijający nawigację jest zwykłym `<a href="#tresc">`, nie `Link` routera. `id="tresc"` siedzi tylko na `main`.
- Marka w banerze i w stopce to link albo akapit. `h1` należy do widoku w `main`.
- Stopka shella jest jedna. Adres e-mail na CV zostaje w artykule, w elemencie `address`.

Tekst baneru pochodzi z `nav` w `pl.json` i `en.json`. Pola już obecne (`home`, `cv`, `courses`, `compendium`, `notes`, `language`, `languagePl`, `languageEn`) zostają. Dwa napisy dokładają się obok nich, bo landmark ich potrzebuje:

| Pole | `pl` | `en` |
| --- | --- | --- |
| `nav.primary` | Nawigacja | Navigation |
| `nav.skip` | Przejdź do treści | Skip to content |

`nav.language` jest już „Język” / „Language” i nazywa drugi `nav`, nie menu główne.

### Jeden h1 i drabinka

W `main` jest dokładnie jeden `h1`. Kolejny nagłówek schodzi o jeden poziom: po `h1` jest `h2`, po `h2` jest `h3`. Poziom nie skacze.

| Trasa | Korzeń w `main` | Tekst `h1` | Niżej |
| --- | --- | --- | --- |
| `/:lang` | fragment sekcji | imię z CV | `h2` bloku, `h3` pozycji w hero i na karcie |
| `/:lang/cv` | `article` | imię | `h2` doświadczenia, wykształcenia, dodatków; `h3` pozycji |
| `/:lang/courses` | `section` | tytuł sekcji wykładów | `h2` karty kursu |
| `/:lang/courses/:slug` | `article` | tytuł kursu | `h2` lekcji, rozdziałów, planu; `h3` rozdziału |
| `/:lang/compendium` | `section` | tytuł kompendium | `h2` hasła |
| `/:lang/compendium/:slug` | `article` | hasło | akapity definicji |
| `/:lang/notes` | `section` | tytuł notatek | `h2` wpisu |
| `/:lang/notes/:slug` | `article` | tytuł notatki | akapity treści |
| `/login`, `/register` | `section` | tytuł formularza | pól nagłówkami nie podpisujemy |

Tytuł karty jest nagłówkiem o jeden poziom niższym niż nagłówek, który otwiera listę. Na home sekcja „Wykłady” ma `h2`, więc karta kursu ma `h3`. Na indeksie wykładów strona ma `h1`, więc karta ma `h2`.

### Sekcja, artykuł, lista

`section` grupuje temat, który ma własny nagłówek: hero, blok na home, indeks listy, blok lekcji w kursie, rozdział CV.

`article` jest całością, którą da się czytać osobno: notatka, kurs, hasło kompendium, dokument CV, zapowiedź takiej całości na liście.

Powtarzalne rodzeństwo jest listą. `ul` gdy kolejność jest zbiorem (karty na indeksie). `ol` gdy kolejność jest programem (lekcje, rozdziały kursu, pozycje CV). `key` jest slugiem albo parą `tytuł|okres`, nie indeksem tablicy.

Szablon indeksu, gdy lista ma pozycje:

```tsx
<section>
  <header>
    <h1>{section.title}</h1>
    <p>{section.lead}</p>
  </header>
  <ul>
    {section.items.map((item) => (
      <li key={item.slug}>
        <article>
          <h2>
            <Link to={href}>{item.title}</Link>
          </h2>
          <p>{item.summary}</p>
        </article>
      </li>
    ))}
  </ul>
</section>
```

Cała karta może być jednym linkiem. W HTML5 `<a>` może objąć `h2` i akapity, dopóki w środku nie ma drugiego linku ani przycisku:

```tsx
<li key={course.slug}>
  <article>
    <Link to={`/${locale}/courses/${course.slug}`}>
      <h2>{course.title}</h2>
      <p>{course.subtitle}</p>
      {course.summary.map((paragraph) => (
        <p key={paragraph}>{paragraph}</p>
      ))}
    </Link>
  </article>
</li>
```

Data jednorazowa (pole `date` notatki, format `2026-03-02`) jest elementem `time`, a `dateTime` równa się tej wartości ISO. Zakres w CV („2020–2024”) zostaje akapitem: to nie jest jedna data.

Link wewnętrzny to `Link` albo `NavLink`. Link na zewnątrz (repozytorium, laboratorium, słownik) to `<a href target="_blank" rel="noopener noreferrer">`. Adres e-mail to `<a href="mailto:…">` wewnątrz `address`.

Blok opcjonalny wewnątrz artykułu (lekcje, rozdziały, plan, notatki na home) przy pustej tablicy zwraca `null`. Strona, której sensem jest sama lista, przy pustce zostawia `h1` i akapit — przypadek niżej.

### Formularz

Logowanie i rejestracja dzielą jedno drzewo. `h1` jest tytułem widoku. Każde pole ma widoczną etykietę; placeholder etykiety nie zastępuje. Przycisk wysłania ma `type="submit"`, więc Enter w polu wysyła formularz. Przycisk, który nie wysyła (język w shellu), ma `type="button"`.

```tsx
<section>
  <h1>{title}</h1>
  <form onSubmit={onFormSubmit}>
    <label>
      Email
      <input
        name="email"
        type="email"
        autoComplete="username"
        required
        value={email}
        onChange={(event) => setEmailFromInput(event.target.value)}
      />
    </label>
    <label>
      Password
      <input
        name="password"
        type="password"
        autoComplete={passwordAutoComplete}
        required
        minLength={8}
        value={password}
        onChange={(event) => setPasswordFromInput(event.target.value)}
      />
    </label>
    {error ? <p role="alert">{error}</p> : null}
    <button type="submit" disabled={pending}>
      {buttonLabel}
    </button>
  </form>
  <p>{hint}</p>
</section>
```

`autoComplete` logowania to `current-password`, rejestracji `new-password`. Na czas żądania przycisk jest `disabled`, a jego tekst to `pendingLabel`. Akapit błędu jest w formularzu tylko wtedy, gdy jest tekst; `role="alert"` ogłasza go po odpowiedzi API. Skąd bierze się tekst błędu i `fetch`, opisuje [treść i auth](../react/03-tresc-i-auth.md).

Komponenty shadcn, gdy wejdą, renderują te same `button` i `input` w tym `form`. Katalog jest w [komponentach shadcn](../shadcn/03-komponenty.md).

### Klasa zostaje na znaczniku

`className` dopisujesz na `header`, `nav`, `main`, `section`, `article`, `ul`, `form`, `button` — na tym elemencie, który już ma rolę. Osobne opakowanie po to, żeby powiesić klasę, nie powstaje.

Nazw klas ten plik nie podaje. Odstęp, szerokość artykułu, nav i siatka kart: [układ](../tailwind/03-uklad.md). Inter, skala, ciemny hero i jasne sekcje: [typografia](../tailwind/04-typografia.md). Hover, focus, disabled, pusto i reduced motion jako wygląd: [stany](../tailwind/05-stany.md).

Motion animuje ten sam węzeł: `motion.section`, `motion.article`, `motion.p`. Sekcja nie zamienia się w `motion.div`. Wejścia i reduced motion: [przejścia](../motion/01-przejscia.md). Hero na home: [hero](../motion/02-hero.md). `ref` pod ruch wisi na sekcji albo artykule.

### Sprawdzenie

Pakietu do instalacji nie ma. Serwer deweloperski (port 4200) opisuje [Vite](../vite/01-dev.md):

```bash
cd src/Clients/web
pnpm start
```

Po złożeniu drzewa, na `http://localhost:4200/pl`, w konsoli dokumentu:

```js
document.documentElement.lang
document.querySelectorAll('h1').length
document.querySelectorAll('main').length
[...document.querySelectorAll('header, nav, main, footer')].map((node) => node.tagName)
```

Oczekiwane: `lang` równe `pl`, jeden `h1`, jeden `main`, kolejność baner → nawigacje → `main` → stopka. Na `/pl/notes/dlaczego-cqrs` wewnątrz `main` jest `article` z `time[datetime="2026-03-02"]`. Na `/login` wewnątrz `main` jest jeden `form`, a tytuł formularza jest `h1`.

Test Vitest sprawdza to samo przez role, nie przez klasy. Harness jest w [testach](../react/04-testy.md). Zapytania, które ten kontrakt ma spełniać:

```tsx
expect(document.querySelectorAll('h1')).toHaveLength(1);
expect(screen.getByRole('banner')).toBeInTheDocument();
expect(screen.getByRole('navigation', { name: 'Nawigacja' })).toBeInTheDocument();
expect(screen.getByRole('navigation', { name: 'Język' })).toBeInTheDocument();
expect(screen.getByRole('main')).toBeInTheDocument();
expect(screen.getByRole('contentinfo')).toBeInTheDocument();
```

Uruchomienie zestawu z katalogu klienta web: `pnpm test:ci`.

## Przypadki użycia

### Shell

Shell jest wspólny dla home, CV, wykładów, kompendium, notatek, logowania i rejestracji. Poniższy `return` jest całym układem chrome. Handlery `showPolish` i `showEnglish` oraz wyliczenie `locale` stoją nad `return`; ich zachowanie opisują [trasy](../react/02-trasy.md).

```tsx
export function Shell({ children }: ShellProps) {
  // locale, nav, showPolish, showEnglish — nad return
  return (
    <>
      <a href="#tresc">{nav.skip}</a>
      <header>
        <NavLink to={`/${locale}`} end>
          JJDevHub
        </NavLink>
        <nav aria-label={nav.primary}>
          <NavLink to={`/${locale}`} end>
            {nav.home}
          </NavLink>
          <NavLink to={`/${locale}/cv`}>{nav.cv}</NavLink>
          <NavLink to={`/${locale}/courses`}>{nav.courses}</NavLink>
          <NavLink to={`/${locale}/compendium`}>{nav.compendium}</NavLink>
          <NavLink to={`/${locale}/notes`}>{nav.notes}</NavLink>
        </nav>
        <nav aria-label={nav.language}>
          <button type="button" aria-pressed={locale === 'pl'} onClick={showPolish}>
            {nav.languagePl}
          </button>
          <button type="button" aria-pressed={locale === 'en'} onClick={showEnglish}>
            {nav.languageEn}
          </button>
        </nav>
      </header>
      <main id="tresc">{children}</main>
      <footer>
        <p>JJDevHub</p>
      </footer>
    </>
  );
}
```

Kolejność linków jest kolejnością z JSON: Start, CV, Wykłady, Kompendium, Notatki. Shell przy montażu ustawia `document.documentElement.lang` na `locale` i przy odmontowaniu przywraca poprzednią wartość.

### Artykuł notatki

Trasa `/:lang/notes/:slug`. Brak slugu przenosi na indeks notatek (`Navigate`) i nie renderuje pustego artykułu. Treść akapitów to `note.body` z bundla.

```tsx
<article>
  <header>
    <p>
      <Link to={`/${locale}/notes`} aria-label={section.backLabel}>
        ←
      </Link>
    </p>
    <time dateTime={note.date}>{note.date}</time>
    <h1>{note.title}</h1>
    <p>{note.summary}</p>
  </header>
  {note.body.map((paragraph) => (
    <p key={paragraph}>{paragraph}</p>
  ))}
  {relatedHref ? (
    <aside>
      <p>
        <Link to={relatedHref}>{relatedTitle}</Link>
      </p>
    </aside>
  ) : null}
</article>
```

Dla `dlaczego-cqrs` w `pl`: `h1` to „Dlaczego CQRS już na laboratorium”, `time` ma `dateTime="2026-03-02"`, trzy akapity z `body` są bezpośrednimi dziećmi `article`. `aria-label` powrotu czyta „Wróć do notatek” z `notes.backLabel`. Widoczny znak to strzałka.

Gdy notatka ma `relatedCourseSlug` i `relatedLessonSlug`, `aside` ma jeden link. Tekst linku jest tytułem powiązanej lekcji albo kursu, adres prowadzi do lekcji albo do `/${locale}/courses/${relatedCourseSlug}`. Slug sam w sobie tekstem linku nie jest.

To samo drzewo artykułu mają szczegół kursu i hasło kompendium: `header` ze strzałką powrotu (`backLabel` swojej sekcji), jeden `h1`, potem treść. Kurs dokłada pod nagłówkiem akapity `summary`, linki zewnętrzne repozytorium i laboratorium oraz sekcje z listami. Hasło dokłada akapity `definition` jako `p` w `article`. Szczegóły niżej, w mapie ekranów.

### Formularz logowania

Trasa `/login`, wewnątrz shella, poza `/:lang`. Tytuł jest `h1`, nie `h2`.

```tsx
<section>
  <h1>Log in</h1>
  <form onSubmit={onFormSubmit}>
    <label>
      Email
      <input
        name="email"
        type="email"
        autoComplete="username"
        required
        value={email}
        onChange={(event) => setEmailFromInput(event.target.value)}
      />
    </label>
    <label>
      Password
      <input
        name="password"
        type="password"
        autoComplete="current-password"
        required
        minLength={8}
        value={password}
        onChange={(event) => setPasswordFromInput(event.target.value)}
      />
    </label>
    {error ? <p role="alert">{error}</p> : null}
    <button type="submit" disabled={pending}>
      {pending ? 'Signing in…' : 'Log in'}
    </button>
  </form>
  <p>
    No account? <Link to="/register">Register</Link>
  </p>
</section>
```

Rejestracja (`/register`) używa tego samego drzewa. Różnią się cztery teksty i jeden atrybut: `h1` „Register”, przycisk „Create account” / „Creating account…”, `autoComplete="new-password"`, podpowiedź z linkiem do `/login` („Already registered? Log in”).

### Pusta lista

Indeks wykładów, notatek i kompendium przy `items.length === 0` zostawia nagłówek strony i jeden akapit. Pustego `ul` nie ma. Wczesny `return` jest nad listą.

```tsx
export function CoursesPage() {
  const section = siteFor(locale).courses;

  if (section.items.length === 0) {
    return (
      <section>
        <header>
          <h1>{section.title}</h1>
          <p>{section.lead}</p>
        </header>
        <p>{section.empty}</p>
      </section>
    );
  }

  return (
    <section>
      <header>
        <h1>{section.title}</h1>
        <p>{section.lead}</p>
      </header>
      <ul>
        {section.items.map((course) => (
          <li key={course.slug}>
            <article>
              <Link to={`/${locale}/courses/${course.slug}`}>
                <h2>{course.title}</h2>
                <p>{course.subtitle}</p>
                {course.summary.map((paragraph) => (
                  <p key={paragraph}>{paragraph}</p>
                ))}
              </Link>
            </article>
          </li>
        ))}
      </ul>
    </section>
  );
}
```

Zdanie pustki leży w JSON sekcji, obok `title` i `lead`:

| Sekcja | Pole | `pl` | `en` |
| --- | --- | --- | --- |
| wykłady | `courses.empty` | Nie ma jeszcze wykładów. | No courses yet. |
| notatki | `notes.empty` | Nie ma jeszcze notatek. | No notes yet. |
| kompendium | `compendium.empty` | Nie ma jeszcze haseł. | No entries yet. |

Na home pusta wycinek notatek albo pusta lista kursów usuwa całą sekcję (`return null`). Pusty stan z `h1` jest na indeksie, nie w stopce strony startowej.

Ten sam podział wraca później w intranecie, w tym samym kliencie, gdy lista przyjdzie z API: indeks ma `h1` i akapit pustki, blok poboczny przy braku danych znika. Wygląd pustki jest w [stanach](../tailwind/05-stany.md), zestaw kontrolek w [shadcn](../shadcn/03-komponenty.md).

### Mapa pozostałych ekranów

Home (`/:lang`) jest fragmentem trzech sekcji, bez opakowania. Hero jest ciemne wyglądem — klasy w [typografii](../tailwind/04-typografia.md), scroll w [hero](../motion/02-hero.md). Drzewo:

```tsx
<>
  <section aria-labelledby="hero-title">
    <p>{home.eyebrow}</p>
    <h1 id="hero-title">{cv.name}</h1>
    <p>{cv.role}</p>
    <section aria-labelledby="hero-current">
      <h2 id="hero-current">{home.currentTitle}</h2>
      <p>{home.currentLead}</p>
      <ol>
        {chapters.map((item) => (
          <li key={`${item.title}|${item.period}`}>
            <article>
              <p>{item.period}</p>
              <h3>{item.title}</h3>
              {item.company ? <p>{item.company}</p> : null}
              {item.paragraphs.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
            </article>
          </li>
        ))}
      </ol>
    </section>
    <p>
      <Link to={`/${locale}/cv`}>{home.ctaCv}</Link>
      <Link to={`/${locale}/courses`}>{home.ctaCourses}</Link>
    </p>
  </section>
  <section aria-labelledby="home-courses">
    <header>
      <h2 id="home-courses">{home.coursesTitle}</h2>
      <p>{home.coursesLead}</p>
    </header>
    <ul>
      {courses.map((course) => (
        <li key={course.slug}>
          <article>
            <h3>
              <Link to={`/${locale}/courses/${course.slug}`}>{course.title}</Link>
            </h3>
            <p>{course.subtitle}</p>
            <p>{course.summary[0]}</p>
          </article>
        </li>
      ))}
    </ul>
  </section>
  <section aria-labelledby="home-notes">
    <header>
      <h2 id="home-notes">{home.notesTitle}</h2>
      <p>{home.notesLead}</p>
    </header>
    <ul>
      {notes.map((note) => (
        <li key={note.slug}>
          <article>
            <h3>
              <Link to={`/${locale}/notes/${note.slug}`}>{note.title}</Link>
            </h3>
            <time dateTime={note.date}>{note.date}</time>
            <p>{note.summary}</p>
          </article>
        </li>
      ))}
    </ul>
    <p>
      <Link to={`/${locale}/notes`}>{home.viewAll}</Link>
    </p>
  </section>
</>
```

`aria-labelledby` wskazuje widoczny nagłówek sekcji. Osobny `aria-label` jest zbędny, gdy nagłówek już jest na ekranie.

CV (`/:lang/cv`):

```tsx
<article>
  <header>
    <h1>{cv.name}</h1>
    <p>{cv.role}</p>
    <address>
      <a href={`mailto:${cv.email}`}>{cv.email}</a>
    </address>
  </header>
  <section>
    <h2>{cv.experienceTitle}</h2>
    <ol>
      {cv.experience.map((entry) => (
        <li key={`${entry.title}|${entry.period}`}>
          <h3>{entry.title}</h3>
          <p>{entry.period}</p>
          {entry.company ? <p>{entry.company}</p> : null}
          {entry.paragraphs.map((paragraph) => (
            <p key={paragraph}>{paragraph}</p>
          ))}
        </li>
      ))}
    </ol>
  </section>
</article>
```

Wykształcenie i dodatki są drugą i trzecią `section` z własnym `h2` (`educationTitle`, `extrasTitle`) i taką samą `ol`. W wykształceniu organizacja bierze się z `institution`.

Szczegół kursu (`/:lang/courses/:slug`), po `header` z `h1` = `course.title`, podtytułem, akapitami `summary` i linkami zewnętrznymi:

```tsx
<section>
  <h2>{course.lessonsTitle}</h2>
  <ol>
    {lessons.map((lesson) => (
      <li key={lesson.slug}>
        <a href={lesson.url} target="_blank" rel="noopener noreferrer">
          {lesson.title}
        </a>
        <p>{lesson.summary}</p>
      </li>
    ))}
  </ol>
</section>
<section>
  <h2>{course.chaptersTitle}</h2>
  <ol>
    {chapters.map((chapter) => (
      <li key={chapter.slug}>
        <h3>{chapter.title}</h3>
        <p>{chapter.summary}</p>
      </li>
    ))}
  </ol>
</section>
```

Lekcja jest pozycją listy, nie kolejnym nagłówkiem: tytuł jest tekstem linku. Rozdział jest podsekcją, więc ma `h3`. Trzecia sekcja, plan, ma `h2` z `plannedTitle`, akapit `plannedLead` i `ol` jak rozdziały. Pusta tablica lekcji, rozdziałów albo planu pomija swoją sekcję.

Indeks kompendium ma w `header` dodatkowo link zewnętrzny słownika (`glossaryUrl`, tekst `glossaryLabel`). Karta hasła: `h2` to `term`, akapit to pierwszy element `definition`. Szczegół hasła:

```tsx
<article>
  <header>
    <p>
      <Link to={`/${locale}/compendium`} aria-label={section.backLabel}>
        ←
      </Link>
    </p>
    <h1>{term.term}</h1>
  </header>
  {term.definition.map((paragraph) => (
    <p key={paragraph}>{paragraph}</p>
  ))}
</article>
```

Indeks notatek używa szablonu listy z tego tutorialu: `h1` to tytuł sekcji, w `li` jest `article` z `h2`, `time` i `p` streszczenia. Pusty wariant jest w przypadku wyżej, z `notes.empty`.

## Zasady wyglądu

Drzewo jest rzadkie: baner, treść, sekcja, artykuł, lista. Z tego bierze się duży oddech i mało ramek. Odstępy i siatkę dopisuje [układ](../tailwind/03-uklad.md) jako klasy na tych znacznikach.

Paleta `#f5f5f7`, `#1d1d1f`, `#0071e3` i krój Inter są liczbami w `tokens.ts`. Ten plik ich w klasach nie powtarza. Mapowanie na CSS jest w [motywie](../motyw.md) i w [motywie Tailwinda](../tailwind/02-motyw.md).

Ciemny hero jest jedną sekcją na home, z jednym `h1`. Jasne sekcje pod nim mają `h2`. Wygląd tego kontrastu opisuje [typografia](../tailwind/04-typografia.md).

Jeden `h1` na widok jest hierarchią treści. `document.title` powtarza ten sam tekst.

## Poza zakresem

- Klasy odstępu, nav, siatki i szerokości artykułu — [układ](../tailwind/03-uklad.md).
- Skala pisma i wygląd ciemnego hero — [typografia](../tailwind/04-typografia.md).
- Hover, `focus-visible`, wygląd `disabled`, pustego stanu i `prefers-reduced-motion` — [stany](../tailwind/05-stany.md).
- Jeden `src/styles.css` zamiast arkuszy SCSS — [CSS zamiast SCSS](../tailwind/06-css-zamiast-scss.md).
- Plik komponentu, hooki, wczesny return jako reguła Reacta — [komponenty](../react/01-komponenty.md).
- Tabela tras, `BrowserRouter`, podmiana segmentu języka — [trasy](../react/02-trasy.md).
- JSON w bundlu, `cv.local.json`, `fetch` przy auth — [treść i auth](../react/03-tresc-i-auth.md).
- Vitest, Testing Library, jsdom — [testy](../react/04-testy.md). Ten plik podaje tylko role, które test ma znaleźć.
- Button, input, dialog i nawigacja jako komponenty shadcn — [shadcn](../shadcn/03-komponenty.md).
- Ruch sekcji i scroll hero — [przejścia](../motion/01-przejscia.md), [hero](../motion/02-hero.md).
- Ekran telefonu (tam są widoki natywne, nie te znaczniki) — [ekrany NativeWind](../nativewind/02-ekrany.md).
- Tamagui.
- Osobny klient intranetu. Późniejszy CRUD zostaje w tym samym webie i używa `form`, `button`, `ul` oraz akapitu pustki z tego pliku.

## Gotowe gdy

- Shell na każdej trasie ma jeden baner, nawigację „Nawigacja”, nawigację „Język”, jeden `main#tresc` i jedną stopkę. Odnośnik „Przejdź do treści” prowadzi do `#tresc`.
- `document.documentElement.lang` jest `pl` albo `en` zgodnie z URL. Na `/login` i `/register` jest `pl`.
- W `main` jest dokładnie jeden `h1`, a `document.title` kończy się na `— JJDevHub` i zawiera tekst tego `h1`.
- Notatka, kurs, hasło i CV są `article`. Indeksy są `section` z listą `ul`/`ol`. Data notatki jest `time` z `dateTime` w ISO.
- Logowanie i rejestracja są `form` z etykietami, `button type="submit"` i akapitem `role="alert"` tylko przy błędzie. Tytuł formularza jest tym jedynym `h1`.
- Pusty indeks wykładów, notatek albo kompendium pokazuje `h1`, lead i zdanie z pola `empty`. Listy w DOM wtedy nie ma.
- `className` wisi na znacznikach z tego pliku. Katalog klas jest w `docs/frontend/tailwind/`, nie tutaj.
