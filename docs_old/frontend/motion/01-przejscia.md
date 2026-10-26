# Przejścia

Wejście sekcji i zmiana widoku na webu. Biblioteka Motion siedzi na tym samym HTML5, który składa React. Vite podaje jeden `src/styles.css`, klasy układu daje Tailwind v4. Ten plik opisuje tylko krótki ruch treści. Scroll hero jest w [02-hero.md](02-hero.md).

## Wersje i pakiety

Klient web ma Reacta 19.2.3 i react-router 7. Pakiet animacji to `motion` w linii 14. Import wyłącznie z `motion/react`. Pakietu `framer-motion` nie ma.

```bash
pnpm add motion
```

Komenda idzie w `src/Clients/web`.

Z `motion/react` wchodzą: `motion`, `AnimatePresence`, `MotionConfig`, `useReducedMotion`.

Czasy i easing biorą się z [tokens.ts](../../../src/Clients/shared/theme/tokens.ts). Kontrakt liczb opisuje [motyw.md](../motyw.md). Motion liczy czas w sekundach, tokeny są w milisekundach, więc duration w propsach to wartość tokenu podzielona przez 1000.

| Ruch | Token | W Motion |
| --- | --- | --- |
| Wejście sekcji | `duration.reveal` (700) | 0,7 s |
| Zmiana widoku i stagger kart | `duration.revealFast` (400) | 0,4 s |
| Easing obu | `easing.reveal` | `[0.25, 0.1, 0.25, 1]` |
| Przesunięcie sekcji | `space[5]` | 24 px w osi Y |
| Przesunięcie widoku | `space[3]` | 12 px w osi Y |

Opóźnienie między kartami to `duration.revealFast / 8` milisekund (0,05 s). Nowego czasu w `tokens.ts` nie dodajemy.

## Ścieżki w repo

| Plik | Rola |
| --- | --- |
| `src/Clients/web/package.json` | zależność `motion` |
| `src/Clients/web/src/app/App.tsx` | `MotionConfig` na korzeniu drzewa |
| `src/Clients/web/src/app/LangGate.tsx` | zmiana widoku wokół `Outlet` pod `/:lang` |
| `src/Clients/web/src/app/motion/section-enter.ts` | warianty wejścia sekcji |
| `src/Clients/web/src/app/pages/courses/CoursesPage.tsx` | lista kursów |
| `src/Clients/web/src/app/pages/courses/CourseDetailPage.tsx` | szczegół kursu |

`Shell` zostawia `header`, `nav`, `main` i `footer` na miejscu. Animowany jest wyłącznie węzeł wewnątrz `main`. Landmark `main` nie jest komponentem `motion`.

## Tutorial

### Korzeń

`MotionConfig` obejmuje całą aplikację. `reducedMotion="user"` wyłącza w bibliotece animacje transformacji i layoutu, gdy system ma `(prefers-reduced-motion: reduce)`. Samo to ustawienie zostawia fade opacity. Wejście sekcji i zmiana widoku mają iść dalej: przy włączonym ograniczeniu nie ma żadnego tweenu.

```tsx
import { MotionConfig } from 'motion/react';

export function App() {
  return (
    <MotionConfig reducedMotion="user">
      <Shell>{/* trasy */}</Shell>
    </MotionConfig>
  );
}
```

### Zmiana widoku

Owijką jest `LangGate`, bo lista i szczegół kursu są dziećmi `/:lang`. Klucz to `location.pathname`, więc `/pl/courses` i `/pl/courses/:slug` są osobnymi widokami. `mode="wait"` zdejmuje stary widok, zanim wejdzie nowy. Jeden `motion.div` jest tylko granicą obecności. Strona w środku zostaje `section` albo `article`.

Hooki stoją przed wczesnym `return`. `useReducedMotion() === true` pomija `AnimatePresence` i renderuje sam `Outlet`, w stanie końcowym, bez czekania na wyjście.

```tsx
import { AnimatePresence, motion, useReducedMotion } from 'motion/react';
import { Navigate, Outlet, useLocation, useParams } from 'react-router';

import { tokens } from '@jjdevhub/theme';

import { isLocale } from './content/content';

export function LangGate() {
  const { lang } = useParams();
  const location = useLocation();
  const reduce = useReducedMotion() === true;

  if (!isLocale(lang)) {
    return <Navigate to="/pl" replace />;
  }

  if (reduce) {
    return <Outlet />;
  }

  return (
    <AnimatePresence mode="wait">
      <motion.div
        key={location.pathname}
        initial={{ opacity: 0, y: tokens.space[3] }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0 }}
        transition={{
          duration: tokens.duration.revealFast / 1000,
          ease: tokens.easing.reveal,
        }}
      >
        <Outlet />
      </motion.div>
    </AnimatePresence>
  );
}
```

Zmianę widoku niesie Motion. `viewTransition` na `Link`, `NavLink` i `navigate` nie wchodzi w tę warstwę. Dwa mechanizmy na jednej nawigacji nakładają się.

Ten sam wrapper obejmuje każde dziecko `/:lang`. Przykłady poniżej są na kursach. Login i register leżą poza `/:lang` i tej zmiany nie dostają.

### Wejście sekcji

Sekcja poniżej nagłówka strony wchodzi raz, gdy około 20% jej wysokości jest w widoku (`viewport.once`, `amount: 0.2`). Powrót scrollem nie odtwarza ruchu. Wariant trzyma opacity i jedno przesunięcie Y. Karty listy dostają `staggerChildren`.

Węzeł, który już animuje zmiana widoku, nie dostaje `whileInView`. Na liście kursów granicą widoku jest owijka w `LangGate`. Wejściem sekcji jest lista kart. Na szczególe granicą widoku jest artykuł. Wejściem sekcji są bloki pod nagłówkiem (lekcje, rozdziały).

Gdy `useReducedMotion()` zwraca `true`, `initial` to `false`, a transition ma `duration: 0`. Treść jest od razu w stanie końcowym.

```tsx
import { tokens } from '@jjdevhub/theme';
import { motion, useReducedMotion } from 'motion/react';

const ease = tokens.easing.reveal;
const enterY = tokens.space[5];
const enterSeconds = tokens.duration.reveal / 1000;
const staggerSeconds = tokens.duration.revealFast / 8000;

export function CourseCards({ courses }: { courses: CourseCard[] }) {
  const reduce = useReducedMotion() === true;

  if (courses.length === 0) {
    return <p>{emptyLabel}</p>;
  }

  return (
    <motion.ul
      initial={reduce ? false : 'hidden'}
      whileInView="visible"
      viewport={{ once: true, amount: 0.2 }}
      variants={{
        hidden: {},
        visible: {
          transition: reduce ? { duration: 0 } : { staggerChildren: staggerSeconds },
        },
      }}
    >
      {courses.map((course) => (
        <motion.li
          key={course.slug}
          variants={{
            hidden: { opacity: 0, y: enterY },
            visible: {
              opacity: 1,
              y: 0,
              transition: { duration: reduce ? 0 : enterSeconds, ease },
            },
          }}
        >
          <a href={course.href}>{course.title}</a>
        </motion.li>
      ))}
    </motion.ul>
  );
}
```

W produkcyjnej liście karta jest `Link` z react-router do `/${locale}/courses/${course.slug}`. `key` to `slug`, nie indeks. `motion.ul` i `motion.li` zostają listą. Klasy Tailwinda siedzą na tych znacznikach. Układ siatki opisuje [03-uklad.md](../tailwind/03-uklad.md).

## Przypadki użycia

### Lista kursów

Trasa `/:lang/courses`, strona `CoursesPage`. Wejście na listę z nawigacji jest zmianą widoku: treść w `main` pojawia się z 12 px i opacity, shell stoi. Siatka kart jest wejściem sekcji: karty wjeżdżają raz, z opóźnieniem 0,05 s, na 24 px. Pusta lista wraca wcześniej zwykłym akapitem, bez `motion` i bez staggeru pustki.

### Otwarcie szczegółu

Trasa `/:lang/courses/:slug`, strona `CourseDetailPage`. Klik karty zmienia pathname. Lista wychodzi (sam fade), artykuł wchodzi tym samym `revealFast`. Nagłówek artykułu jedzie ze zmianą widoku. Lekcje i rozdziały pod nagłówkiem używają wejścia sekcji, raz, gdy wejdą w widok. Link powrotu na `/:lang/courses` odtwarza tę samą zmianę w drugą stronę. Nieznany `slug` robi `Navigate` na listę i nie animuje brakującej treści.

`prefers-reduced-motion: reduce` na obu przypadkach: lista i artykuł są od razu na swoim miejscu, bez przesunięcia, fade, staggeru i bez czekania `mode="wait"`.

## Zasady wyglądu

Ruch jest krótki i w jednej osi. Dozwolone są opacity i `y`. Skala, obrót, rozmycie, paralaksa, pin i scrub nie wchodzą.

Odległość i czas pochodzą z tabeli wyżej. Easing to `easing.reveal`. Paleta się nie zmienia: płótno `#f5f5f7`, atrament `#1d1d1f`, akcent `#0071e3` zostają w tokenach, animacja ich nie podmienia.

Duży oddech strony zostaje. Przejście nie dokłada ramek, cienia ani drugiego tła. Nav nie rusza się przy zmianie widoku.

Wejście sekcji odpala się raz. Dłuższa lista nie wydłuża staggeru nowym tokenem. Opóźnienie karty jest ułamkiem `revealFast`.

## Poza zakresem

- Scroll przypiętego hero na home: [02-hero.md](02-hero.md). `useScroll` i `scrollYProgress` nie należą do wejścia sekcji.
- GSAP, ScrollTrigger i Lenis. Ta warstwa ich nie importuje.
- Hero na telefonie: [reanimated.md](../reanimated.md). Ekran telefonu jest osobny.
- Stany CSS (`hover`, `focus-visible`, pusto, błąd): [05-stany.md](../tailwind/05-stany.md). Tam zostaje skrót CSS przy reduced motion. Tu reduced motion gasi tweeny Motion.
- Login, register i wspólny element `layoutId` między kartą a artykułem.

## Gotowe gdy

- `motion` jest zależnością `src/Clients/web`, a importy idą z `motion/react`.
- Lista kursów wchodzi raz jako sekcja. Przejście na szczegół i z powrotem animuje treść w `main`, a shell stoi.
- Przy `(prefers-reduced-motion: reduce)` oba ruchy pokazują stan końcowy od razu.
- W plikach tego ruchu nie ma GSAP, Lenisa ani scrolla hero.
