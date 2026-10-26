# Frontend — React w JJDevHub

Klient webowy żyje w [src/Clients/web](../../src/Clients/web). To React 19 + Vite + pnpm. Wygląd (kolory, skala typu, odstępy, czasy) pochodzi ze wspólnego pakietu [@jjdevhub/theme](../../src/Clients/shared/theme), bez drugiego zapisu heksów w SCSS.

Treść kursów i etykiet jest w JSON w repo. Dane osobowe CV nie — tylko lokalny plik przed buildem, jak sekrety API. Szczegóły: [tresc.md](tresc.md).

Mobilka w [src/Clients/mobile/JJDevHubMobile](../../src/Clients/mobile/JJDevHubMobile) na razie jest szkieletem. Wspólne z nią są tokeny, nie ekrany i nie ścieżka do CV.

Lokalny start i Docker: [src/Clients/web/README.md](../../src/Clients/web/README.md). Deploy obrazu: [github.md](../CICD/03-github.md), [proxmox.md](../CICD/01-proxmox.md).

## Mapa stron

Prefiks języka jest w URL. `/` przekierowuje na `/pl`. Segmenty stałe: `cv`, `courses`, `compendium`, `notes`. Trasy: [App.tsx](../../src/Clients/web/src/app/App.tsx).

| URL | Komponent | Co pokazuje |
| --- | --- | --- |
| `/` | redirect | → `/pl` |
| `/:lang` | `HomePage` | ciemny hero z imieniem z CV, kafle kursów, skrót notatek |
| `/:lang/cv` | `CvPage` | doświadczenie, edukacja, aktywność z CV |
| `/:lang/courses` | `CoursesPage` | lista wykładów |
| `/:lang/courses/:slug` | `CourseDetailPage` | sylabus / rozdziały / „w planach” |
| `/:lang/compendium` | `CompendiumPage` | siatka haseł |
| `/:lang/compendium/:slug` | `CompendiumDetailPage` | definicja hasła |
| `/:lang/notes` | `NotesPage` | lista notatek |
| `/:lang/notes/:slug` | `NoteDetailPage` | treść notatki |
| `/login`, `/register` | auth | poza `/:lang`, bez linków w nawigacji |

Nieprawidłowy `:lang` → `/pl`. Catch-all `*` też na `/pl`.

Shell (nav, footer, przełącznik PL/EN): [App.tsx](../../src/Clients/web/src/app/App.tsx). Przełącznik podmienia tylko pierwszy segment URL.

## Spis dokumentów

| Plik | Temat |
| --- | --- |
| [react.md](react.md) | wersja, shell, trasy, bootstrap tokenów |
| [gsap.md](gsap.md) | przypięty hero na wejściu |
| [lenis.md](lenis.md) | smooth scroll + ticker GSAP |
| [przejscia-widoku.md](przejscia-widoku.md) | View Transitions i `animate.enter` / `leave` |
| [styl/tokeny.md](styl/tokeny.md) | `@jjdevhub/theme` — źródło hex i skali |
| [styl/typografia.md](styl/typografia.md) | Inter, skala, tracking |
| [styl/nawigacja.md](styl/nawigacja.md) | sticky bar, blur (tylko web) |
| [styl/rozdzialy.md](styl/rozdzialy.md) | ciemny hero vs jasne sekcje |
| [styl/kafle.md](styl/kafle.md) | kafle list i hover |
| [styl/artykul.md](styl/artykul.md) | układ szczegółu |
| [styl/budzet.md](styl/budzet.md) | limity `anyComponentStyle` |
| [tresc.md](tresc.md) | JSON kursów vs lokalne CV |

## Ruch (tylko web)

- GSAP 3 + ScrollTrigger — jedna przypięta sekwencja na home
- Lenis — jedna instancja, spięta z tickerem GSAP
- CSS `animation-timeline: view()` — klasa `.reveal` na pozostałych rozdziałach
- View Transitions API (`viewTransition` na linkach) + klasa `list-enter`
- `prefers-reduced-motion` wyłącza Lenisa i scrub hero
