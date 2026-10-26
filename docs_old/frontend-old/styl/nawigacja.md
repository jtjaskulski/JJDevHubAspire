# Nawigacja

Shell w [app.html](../../../src/Clients/web/src/app/app.html) / [app.scss](../../../src/Clients/web/src/app/app.scss).

## Pasek

- `position: sticky; top: 0; z-index: 40`
- tło: `color-mix` z `--canvas` (~72% krycia) + `backdrop-filter: saturate(180%) blur(20px)`
- cienka dolna krawędź z `--ink` na 8%
- transition tła: `--duration-nav` / `--easing-standard`

**Blur i `backdrop-filter` są zabiegiem weba.** Token nie udaje, że to wspólne z RN. Mobilka później weźmie ten sam kolor paska i ten sam czas `--duration-nav`, nie ten sam filtr.

## Zawartość

1. Brand `JJDevHub` → `/:lang`
2. Linki z `nav` w JSON (`home`, `cv`, `courses`, `compendium`, `notes`) — aktywny stan `routerLinkActive` → kolor `--ink` zamiast `--muted`
3. Grupa PL / EN — `switchLocale` podmienia prefiks URL

`/login` i `/register` **nie** są w nawigacji.

## Mobile layout

Poniżej 720px nav wrapuje: linki na pełną szerokość pod brandem i przełącznikiem (`order: 3`).
