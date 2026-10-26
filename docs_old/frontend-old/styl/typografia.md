# Typografia

Krój na webie: **Inter Variable** z `@fontsource-variable/inter` (import w [main.tsx](../../../src/Clients/web/src/main.tsx), przed [styles.scss](../../../src/Clients/web/src/styles.scss)). Token trzyma nazwę rodziny `Inter` (`--font-family`); body używa `'Inter Variable', var(--font-family), system-ui, sans-serif`.

Podłączenie pliku fontu na Androidzie / iOS zostaje na etap mobilki — token już ma `font.family: 'Inter'`.

## Skala

Wartości px i tracking (em) są w [@jjdevhub/theme](tokeny.md). W CSS:

| Rola | Rozmiar | Tracking |
| --- | --- | --- |
| display | `--font-display` (80px) | `--tracking-display` |
| h1–h4 | `--font-h1` … `--font-h4` | odpowiadające `--tracking-*` |
| body | `--font-body` (17px) | `--tracking-body` |
| small / caption | `--font-small`, `--font-caption` | jak wyżej |

Globalnie w [styles.scss](../../../src/Clients/web/src/styles.scss): `font-size: var(--font-body)`, `letter-spacing: var(--tracking-body)`, `line-height: 1.47`, antialiasing.

## Gdzie w UI

- Hero home: imię na `clamp(…, var(--font-display))`, rola na `--font-h3` ([home.scss](../../../src/Clients/web/src/app/pages/home/home.scss))
- Nagłówki list / artykułów: `clamp` do `--font-h1`, leady często `--font-h4` + `--muted`
- Nav: `--font-small` / caption na przełączniku języka ([app.scss](../../../src/Clients/web/src/app/app.scss))

Kolor tekstu: `--ink` na pierwszym planie, `--muted` na drugim, linki `--accent` (globalnie na `a`).
