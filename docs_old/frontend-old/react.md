# React — klient web

Aplikacja to React **19** i Vite w [src/Clients/web](../../src/Clients/web). Package manager: **pnpm** (`packageManager` w `package.json`).

Login i register wołają API przez `/api` zwykłym `fetch`. Strony treści (`/:lang/...`) czytają tylko JSON z bundla — bez HTTP do API.

## Bootstrap

[main.tsx](../../src/Clients/web/src/main.tsx) przed `createRoot`:

1. Importuje `cssCustomProperties()` z `@jjdevhub/theme`.
2. Ustawia każdą parę na `document.documentElement` (`style.setProperty`).
3. Renderuje `App` w `BrowserRouter` i `AuthProvider`.

Globalne style: Inter Variable (import w `main.tsx`) oraz [styles.scss](../../src/Clients/web/src/styles.scss).

## Router

Trasy są w [App.tsx](../../src/Clients/web/src/app/App.tsx). `NavLink` i `navigate` dostają `viewTransition`, więc przeglądarka owija zmianę widoku w natywne View Transitions API. Własnych keyframesów przejścia trasy nie ma. Wejścia elementów list to klasa CSS `list-enter` — [przejscia-widoku.md](przejscia-widoku.md).

`API` idzie na ten sam origin. Pusty prefiks: proxy Vite albo nginx dokleja `/api`.

## Trasy

- `/` → `/pl`
- `/login`, `/register` — tylko dla gościa, **bez** prefiksu języka
- `/:lang` — tylko `pl` i `en`; dzieci: home, cv, courses (+ `:slug`), compendium (+ `:slug`), notes (+ `:slug`)
- nieznany `:lang` i `*` → `/pl`

## Shell

Root: [App.tsx](../../src/Clients/web/src/app/App.tsx).

- Sticky header: brand `JJDevHub`, linki z `siteFor(locale).nav`, przyciski PL/EN
- `<Routes>` w `main.shell-main`
- Footer z nazwą brandu

`pathForLocale` rozbija URL, podmienia pierwszy segment jeśli to locale (albo dokłada locale), zachowuje query i hash. Na `/login` i `/register` przełącznik nic nie zmienia.

`startLenis()` wstaje raz na cały cykl życia aplikacji.

## Treść

[content.ts](../../src/Clients/web/src/app/content/content.ts) importuje `pl.json`, `en.json` i wygenerowany `cv.json`. Locale bierze z pierwszego segmentu URL. Lookup po slug: `courseBySlug`, `compendiumBySlug`, `noteBySlug`.

Model typów: [content.model.ts](../../src/Clients/web/src/app/content/content.model.ts). Podział plików: [tresc.md](tresc.md).

## Ruch

| Mechanizm | Gdzie |
| --- | --- |
| Lenis | [lenis.ts](../../src/Clients/web/src/app/motion/lenis.ts) |
| GSAP + ScrollTrigger | [gsap-setup.ts](../../src/Clients/web/src/app/motion/gsap-setup.ts), użyte na [HomePage.tsx](../../src/Clients/web/src/app/pages/home/HomePage.tsx) |
| View transitions + CSS enter | [przejscia-widoku.md](przejscia-widoku.md) |

## Zależności wyglądu

`"@jjdevhub/theme": "file:../shared/theme"` w [package.json](../../src/Clients/web/package.json). Docker buduje z kontekstu `src/Clients`, żeby ta ścieżka się rozwiązała ([Dockerfile](../../src/Clients/web/Dockerfile)). Obraz kopiuje katalog `dist` z Vite.
