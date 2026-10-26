# Hero na home

Jedna scena scrolla na ciemnym pasie strony głównej. Dotyczy klienta web. Telefon bierze te same liczby z [tokens.ts](../../../src/Clients/shared/theme/tokens.ts); jego własny scroll opisuje [reanimated.md](../reanimated.md).

## Po co

Na `/pl` i `/en` pierwsza sekcja zostaje przyklejona na czas jednego przewinięcia. W tej klatce imię maleje, rola i linia stosu dochodzą, potem dwa pierwsze rozdziały doświadczenia. Brew, pas „Teraz”, lead i dwa odnośniki są widoczne przez cały postęp. Po zejściu ze sceny strona jedzie zwykłym scrollem: wykłady i notatki.

Drugiej przypiętej sekwencji nie ma. CV, wykłady, kompendium, notatki, login i rejestracja zostają zwykłymi stronami.

Gdy przeglądarka zgłasza `prefers-reduced-motion: reduce`, klatka jest statyczna: ta sama treść, jedna wysokość ekranu, imię w skali końcowej, bez drogi przewijania.

## Liczby

Biblioteka to `motion` `14.1.0`, import z `motion/react`: `motion`, `useScroll`, `useTransform`, `useReducedMotion`. Zegar to pozycja scrolla, nie `duration.heroFade`.

| Pole | Wartość | Rola |
| --- | --- | --- |
| `tokens.hero.nameScale` | `0.55` | skala końcowa imienia |
| `tokens.hero.runway` | `2.5` | mnożnik drogi ponad jeden ekran |
| `tokens.duration.heroPin` | `1200` | baza drogi, razy `runway` daje 3000 px |
| `tokens.hero.progress.name` | `0–0.4` | skala imienia od `1` do `nameScale` |
| `tokens.hero.progress.role` | `0.15–0.55` | krycie i `y` roli oraz linii stosu |
| `tokens.hero.progress.first` | `0.4–0.75` | pierwszy rozdział |
| `tokens.hero.progress.second` | `0.6–1` | drugi rozdział |
| `tokens.space[5]` | `24` | przesunięcie roli |
| `tokens.space[6]` | `32` | przesunięcie rozdziału |

`useReducedMotion()` równe `false` włącza scenę. `true` i `null` zostawiają układ statyczny, żeby pierwszy paint i test w jsdom pokazywały treść.

Tło to `bg-dark-chapter`, tekst `text-dark-chapter-fg`. `.NET` w linii stosu jest `text-accent`. Reszta nazw jest przy niższym kryciu tego samego pierwszego planu.

## Ścieżki

| Ścieżka | Rola |
| --- | --- |
| `src/Clients/web/src/app/pages/home/HomeHero.tsx` | tor, scroll, reduced motion |
| `src/Clients/web/src/app/pages/home/HeroChapter.tsx` | jeden rozdział |
| `src/Clients/web/src/app/pages/home/StackLine.tsx` | linia stosu |
| `src/Clients/shared/theme/tokens.ts` | skala, postęp, droga |

Rozdziały to `cv.experience.slice(0, 2)`. Dwa `useTransform` są wołane zawsze. Brak wpisu po prostu nie renderuje artykułu.

## Gotowe gdy

- Przy pełnym ruchu klatka zostaje na drodze `heroPin * runway` pikseli i przechodzi tabelę postępu.
- Przy `prefers-reduced-motion: reduce` treść jest widoczna od razu, skala imienia to `nameScale`, nie ma dodatkowej wysokości toru.
- GSAP i Lenis nie są zależnością klienta web.
- Telefon nie dostaje drugiej tabeli postępu: czyta `tokens.hero`.
