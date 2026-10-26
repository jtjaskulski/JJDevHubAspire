# GSAP — przypięty hero

GSAP 3 jest zależnością weba (`gsap` w [package.json](../../src/Clients/web/package.json)). Używamy go **tylko na stronie wejścia** — jedna sekwencja ScrollTrigger z `pin` i `scrub`. Pozostałe rozdziały animują CSS (`animation-timeline: view()`), nie GSAP.

## Rejestracja pluginów

[gsap-setup.ts](../../src/Clients/web/src/app/motion/gsap-setup.ts) rejestruje `ScrollTrigger` raz (`ensureGsapPlugins`). Wywołują to Lenis i home przed pierwszym timeline.

## Gdzie jest timeline

[HomePage.tsx](../../src/Clients/web/src/app/pages/home/HomePage.tsx), w `useLayoutEffect`:

1. Bierze refy pinu, imienia, roli i rozdziałów.
2. Czyta czasy z obiektu `tokens` (`@jjdevhub/theme`): `duration.heroFade`, `duration.heroPin` — nie z CSS.
3. Buduje `gsap.timeline` ze `scrollTrigger`:
   - `trigger` = kontener pin
   - `start: 'top top'`
   - `end: +=${heroPin * 2.5}` (ms × 2.5 jako długość scrolla)
   - `pin: true`, `scrub: true`, `anticipatePin: 1`
4. Sekwencja: skala imienia → `0.55`, fade-in roli, potem fade-in dwóch pierwszych pozycji z CV (`experience.slice(0, 2)`).

Style ciemnego hero: [home.scss](../../src/Clients/web/src/app/pages/home/home.scss) (`--dark-chapter-bg` / `--dark-chapter-fg`).

## Reduced motion

Jeśli `LenisService.prefersReducedMotion()`, timeline nie powstaje. Zamiast tego `gsap.set` ustawia końcowy stan (skala imienia, pełna opacity roli i rozdziałów). Scrub i Lenis są wtedy wyłączone.

## Sprzątanie

`ngOnDestroy` → `killHero()`: zabija timeline i powiązany ScrollTrigger, plus ewentualne triggery z tym samym `trigger` co pin. Bez tego przy wyjściu z home pin zostaje w DOM / pamięci.

## Czego GSAP tu nie robi

- Brak osobnych timeline na CV, kursach, kompendium, notatkach.
- Brak synchronizacji z View Transitions — to osobna warstwa routera.
- `backdrop-filter` nawigacji i Lenis to nie GSAP; scrub ScrollTrigger jest zabiegiem **tylko weba** (mobilka później weźmie te same ms z tokenów do `Animated`, nie ten pin).
