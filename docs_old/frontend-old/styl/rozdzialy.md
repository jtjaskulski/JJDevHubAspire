# Rozdziały strony

Dwa rejestry wizualne — oba z tokenów, bez lokalnych heksów.

## Ciemny rozdział (hero wejścia)

Tylko home, sekcja `.hero`:

- tło `--dark-chapter-bg` (`#000` w theme)
- tekst `--dark-chapter-fg` (`#f5f5f7`)
- pełna wysokość viewportu w `.hero-pin`, treść wyśrodkowana w kolumnie max ~56rem

Tu gra GSAP (pin + scrub) — [gsap.md](../gsap.md). W środku „Teraz”: dwa wpisy z `cv.experience` jako `.hero-chapter` (lekki półprzezroczysty panel, `--radius-card`).

CTA pod spodem: linki w kolorze foreground z podkreśleniem, nie accent niebieski (czytelność na czerni).

## Jasne sekcje

Reszta aplikacji na `--canvas`:

- kontener `.section` / `.page` — max-width ~64rem (listy) albo węższy artykuł
- nagłówek sekcji: h2 + lead w `--muted`
- odstępy z `--space-*` (typowo `space-9`…`space-11` na pionie strony)

Wejście w viewport: klasa `.reveal` ([styles.scss](../../../src/Clients/web/src/styles.scss)) — scroll-driven, nie GSAP.

## CV jako ciąg rozdziałów

[cv.scss](../../../src/Clients/web/src/app/pages/cv/cv.scss): sekcje doświadczenie / edukacja / aktywność, każdy wpis `.cv-chapter` oddzielony linią `color-mix(--ink 8%)`. To ten sam jasny rejestr, bez ciemnego tła.
