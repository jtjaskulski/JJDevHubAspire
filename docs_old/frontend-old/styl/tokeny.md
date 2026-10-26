# Tokeny — wspólny wygląd

Hex, skala typografii, odstępy, promienie, czasy i easing żyją w pakiecie **`@jjdevhub/theme`**:

- [src/Clients/shared/theme/tokens.ts](../../../src/Clients/shared/theme/tokens.ts)
- [src/Clients/shared/theme/package.json](../../../src/Clients/shared/theme/package.json) (`exports`: `"."` → `./tokens.ts`)

Nie ma tu Reacta ani React Native — zwykły obiekt TypeScript.

## Web

[src/Clients/web/package.json](../../../src/Clients/web/package.json): `"@jjdevhub/theme": "file:../shared/theme"`.

Przy starcie [main.tsx](../../../src/Clients/web/src/main.tsx) woła `cssCustomProperties()` i wpisuje wynik na `documentElement`. SCSS i style komponentów czytają **tylko** `var(--…)`. Drugiego zapisu heksów w arkuszach nie ma.

Home timeline GSAP importuje `tokens` bezpośrednio (ms dla pin/fade), bo ScrollTrigger nie czyta CSS custom properties tak wygodnie — źródło i tak jest to samo `tokens.ts`.

## Mobile (później)

Aplikacja mobilna na tym etapie **nie** ma zależności od theme. Plan: `"@jjdevhub/theme": "file:../../shared/theme"` i złożenie `StyleSheet` z tego samego obiektu `tokens` (kolory, font.size, space, duration, easing). Nie kopiujemy implementacji `backdrop-filter` ani scrub GSAP — tylko wartości.

## Co jest w obiekcie

| Gałąź | Przykłady | Zmienne CSS |
| --- | --- | --- |
| `color` | canvas `#f5f5f7`, ink `#1d1d1f`, muted `#6e6e73`, accent `#0071e3`, darkChapter `#000` / `#f5f5f7` | `--canvas`, `--ink`, `--muted`, `--accent`, `--dark-chapter-bg`, `--dark-chapter-fg`, `--white` |
| `font.family` | `Inter` | `--font-family` |
| `font.size` | display 80 … caption 12 (px) | `--font-display` … `--font-caption` |
| `font.tracking` | em, pod Inter | `--tracking-display` … |
| `space` | 4…160 px (klucze 1–12) | `--space-1` … `--space-12` |
| `radius` | sm…pill | `--radius-sm` … `--radius-pill`, `--radius-card` |
| `duration` | reveal 700, heroPin 1200, … (ms) | `--duration-reveal` … |
| `easing` | cubic-bezier jako tablice | `--easing-reveal`, `--easing-hero`, `--easing-standard` |

Mapowanie do stringów CSS robi wyłącznie `cssCustomProperties()` w tym samym pliku co `tokens`.
