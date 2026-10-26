# Lenis — smooth scroll

Pakiet `lenis` w kliencie web. Jedna instancja na całą aplikację, start w `useEffect` roota `App`.

## Moduł

[lenis.ts](../../src/Clients/web/src/app/motion/lenis.ts):

- `startLenis()` — no-op, gdy już działa, gdy `prefers-reduced-motion: reduce`, albo gdy brak `ResizeObserver`
- `new Lenis({ autoRaf: false, smoothWheel: true })`
- `lenis.on('scroll', ScrollTrigger.update)` — ScrollTrigger widzi pozycję Lenisa
- `gsap.ticker.add` woła `lenis.raf(time * 1000)`; `lagSmoothing(0)`
- `stopLenis()` przy odmontowaniu — usuwa ticker i `lenis.destroy()`

`ensureGsapPlugins()` idzie przed startem, żeby ScrollTrigger był zarejestrowany.

## Style HTML

[styles.scss](../../src/Clients/web/src/styles.scss) ustawia klasy Lenisa (`html.lenis`, `.lenis-smooth` z `scroll-behavior: auto !important`), żeby natywny smooth nie walczył z biblioteką.

## Reduced motion

`prefersReducedMotion()` czyta `matchMedia('(prefers-reduced-motion: reduce)')`. Home używa tej samej metody, żeby nie odpalać scrub GSAP. Wyłączenie Lenisa i scrubu to ten sam warunek użytkownika.

## Zakres

Tylko web. Tokeny trzymają czasy/easing wspólne z przyszłą mobilką; sam Lenis nie jest współdzielony z React Native.
