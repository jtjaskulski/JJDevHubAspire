# Przejścia widoku

Dwie warstwy, obie w CSS i w natywnym API przeglądarki.

## 1. Router — View Transitions API

W [App.tsx](../../src/Clients/web/src/app/App.tsx) `NavLink`, `Link` i `navigate` dostają `viewTransition`.

Gdy przeglądarka wspiera View Transitions API, React Router owija zmianę DOM w natywne przejście. Własnych keyframesów trasy nie konfigurujemy — zostaje domyślne zachowanie.

## 2. Elementy list — klasa `list-enter`

Listy dostają klasę `list-enter` w momencie renderu. Klasy CSS są w [styles.scss](../../src/Clients/web/src/styles.scss):

| Klasa | Efekt | Czas / easing |
| --- | --- | --- |
| `.list-enter` | opacity 0→1, `translateY(--space-3)` → 0 | `--duration-reveal-fast`, `--easing-reveal` |
| `.list-leave` | odwrotnie, lekko w górę | `--duration-reveal-fast`, `--easing-standard` |

`list-enter` jest na home (kafle, wiersze notatek), listach courses / notes / compendium, rozdziałach CV i paragrafach szczegółów. `.list-leave` zostaje w arkuszu na ten sam ruch w drugą stronę.

## 3. Scroll reveal (nie router)

Klasa `.reveal` na sekcjach:

```css
animation-timeline: view();
animation-range: entry 0% cover 35%;
```

Keyframe `reveal-up`: fade + `translateY(--space-5)`. To nie jest View Transition — to scroll-driven animation dla treści poniżej foldu (CV, sekcje list, artykuły).

## Reduced motion

W `@media (prefers-reduced-motion: reduce)` animacje `.reveal`, `.list-enter` i `.list-leave` są wyłączone (`animation: none`). Lenis i scrub GSAP też — [lenis.md](lenis.md), [gsap.md](gsap.md).
