# Ruch

Ten numer dodaje ruch. Web używa Motion, z importu `motion/react`. Telefon używa Reanimated. Czas i krzywa biorą się z `tokens.duration` i `tokens.easing` w [01-motyw.md](01-motyw.md). Nie ma literału milisekund w wywołaniu animacji. Wygląd klas zostaje w [03-wyglad.md](03-wyglad.md) i [06-mobile.md](06-mobile.md). Powiadomienia z [07-powiadomienia.md](07-powiadomienia.md) nie dostają tu osobnego czasu.

Poprzedni numer to [07-powiadomienia.md](07-powiadomienia.md). To ostatni numer folderu frontend. Maszyna z [08-proxmox.md](../cicd/08-proxmox.md) już stoi. Obraz weba i telefonu wjeżdża jobem z [16-deploy.md](../cicd/16-deploy.md). Co ten numer nie opisuje, jest w sekcji Poza zakresem.

Wspólnego silnika ruchu dla webu i telefonu nie ma. Wspólne są liczby.

## Po co

Strona bez czasu z tokenów i tak „coś” animuje, bo biblioteka ma własne domyślne 300 milisekund. To jest druga skala, tak samo jak domyślne `p-5` było drugą skalą odstępu, zanim numer `03` ją wyłączył. Ten numer podpina wejście sekcji, zejście masztu i drobny ruch listy pod klucze, które już istnieją: `reveal`, `revealFast`, `heroPin`, `heroFade`, `nav`.

System operacyjny pozwala wyłączyć ruch. Web czyta `prefers-reduced-motion`. Telefon czyta odpowiednik dostępności w React Native. W obu przypadkach czas schodzi do zera, a treść jest na ekranie od razu. Maszt nie zostaje pusty przez 1200 milisekund, gdy użytkownik poprosił o spokój.

Web i telefon nie dzielą jednego przebiegu klatek. Maszt na stronie głównej webu może związać się z przewinięciem. Lista na telefonie przesuwa się gestem platformy. Liczba milisekund przy podobnym geście jest ta sama. Implementacja nie jest ta sama.

## Dlaczego ta technologia

### Motion w przeglądarce

Pakiet nazywa się `motion`. Import komponentu i właściwości idzie z `motion/react`. Starsza nazwa pakietu `framer-motion` przegrywa, bo to ten sam projekt pod poprzednią nazwą i drugi import rozdziela drzewo zależności. GSAP przegrywa, bo dokłada drugi silnik obok Motion i własną oś czasu, a licencjonowanie przy części wtyczek nie jest potrzebne, gdy wejście sekcji załatwia jeden pakiet na MIT. Lenis jako osobny przewijacz przegrywa, bo podmienia scroll dokumentu i gryzie się z ruchem, który ma tylko wejść i zejść, a nie przepinać kółko myszy. CSS `@keyframes` wpisane w `styles.css` z literałem `700ms` przegrywają, bo czas żyje w `tokens.ts`, a arkusz z numeru `03` nie ma milisekund.

Koszt: komponent, który się rusza, jest elementem Motion (`motion.section`, `motion.header`) albo dostaje właściwości przejścia. Nadal renderuje HTML z numeru `02`: `section`, `header`, `h1`. Biblioteka nie zastępuje semantyki `div`-em bez roli.

Funkcja `sectionTransition(reduced: boolean)` zwraca czas `tokens.duration.reveal` i krzywą `tokens.easing.reveal`, albo czas `0`, gdy `reduced` jest prawdą. Podobne funkcje:

| Funkcja | Klucz czasu | Klucz krzywej | Gdzie |
| --- | --- | --- | --- |
| `sectionTransition` | `reveal` | `reveal` | wejście sekcji na home, CV, kursie, notatce |
| `listItemTransition` | `revealFast` | `standard` | wiersz listy |
| `heroTransition` | `heroPin` i `heroFade` | `hero` | pas masztu |
| `navTransition` | `nav` | `standard` | belka |

`heroTransition` używa `heroPin` na przytrzymanie pasa i `heroFade` na zejście. Nie wymyśla trzeciej liczby pomiędzy.

Klasa `duration-nav` z numeru `03` zostaje przy prostej zmianie koloru w CSS. Tam, gdzie wołasz `motion`, nie duplikujesz tego czasu literałem. Jeśli przejście CSS i Motion dotyczą tego samego elementu, zostawiasz jedno. Belka bierze `navTransition` albo klasę, nie oba naraz na tej samej właściwości.

### Reanimated na telefonie

`react-native-reanimated` prowadzi ruch widoków natywnych. Wejście ekranu i drobny przesuw listy biorą `withTiming` z czasem `tokens.duration.reveal` albo `tokens.duration.revealFast` i z krzywą złożoną z krotki `tokens.easing`. Krotka nie jest parsowana z napisu `cubic-bezier(...)`. Serializer z numeru `01` zostaje przy CSS. Tutaj jest liczba.

Motion na telefonie przegrywa, bo celuje w DOM. Reanimated na webie jako drugi silnik obok Motion przegrywa, bo web ma już pakiet `motion` i drugi runtime na tych samych elementach. Animated z React Native bez Reanimated przegrywa tam, gdzie gest ma zejść na wątek UI; proste wejście dałoby się złożyć starą animacją, a lista i tak potrzebuje spójnego API. Wspólny plik „parallax” importowany przez web i telefon przegrywa, bo zwiąże przewinięcie dokumentu z gestem listy.

Koszt: funkcje czasu na telefonie nazywają się tak samo jak na webie (`sectionTransition`, `listItemTransition`, `heroTransition`, `navTransition`) i leżą w pliku telefonu, nie w pliku webu. Powtórzenie nazwy jest kontraktem klucza, nie wspólnym modułem React. Wspólny moduł bez Reacta, który tylko zwraca liczby, jest dozwolony i może stać przy `tokens`, jeśli oba klienty wołają te same funkcje. Ten numer wybiera jedną czystą funkcję w `src/clients/shared/theme/motion.ts`, bez importu Motion i bez importu Reanimated. Oba klienty biorą z niej `{ duration, easing }`. Biblioteka dostaje te liczby w swoim API.

`motion.ts` nie importuje Reacta. Test z numeru `01` może zostać przy liczbach, a test tego numeru sprawdza, że funkcja zwraca dokładnie pole tokenu, nie kopię wpisaną jako `700`.

### Czas z tokenów

W wywołaniu animacji nie ma `300`, `250`, `400`, `600`, `700` ani `1200`. Jest `tokens.duration.<klucz>` albo wynik `motion.ts`. Krzywa nie jest wpisana jako cztery liczby w komponencie. Jest `tokens.easing.<klucz>`.

Domyślny czas biblioteki przegrywa, bo recenzja nie widzi, który klucz produktu miał być użyty. Stała `const REVEAL = 700` w pliku ekranu przegrywa, bo odrywa się od obiektu, gdy ktoś zmieni token. Czytanie `getComputedStyle` i parsowanie `700ms` przegrywa, bo telefon nie ma tego stylu, a błąd w jednostce psuje ruch po cichu.

Koszt: nowy rodzaj ruchu potrzebuje klucza w numerze `01` albo używa istniejącego. Ten numer nie dopisuje szóstego czasu. Pięć kluczy z tabeli wystarcza na sekcję, listę, maszt i belkę.

Mapa użycia na webie:

| Miejsce | Funkcja |
| --- | --- |
| pas masztu na `HomePage` | `heroTransition` |
| sekcja notatek na home | `sectionTransition` |
| lista kursów i notatek | `listItemTransition` |
| belka `Shell` | `navTransition` |

Na telefonie ta sama mapa: maszt `HomeScreen`, sekcje, wiersze list, belka nawigacji. Skrzynka z numeru `07` używa `listItemTransition` dla wiersza, jeśli wiersz w ogóle wchodzi animacją. Nie dostaje własnego czasu.

### Ograniczenie ruchu

`useReducedMotion` na webie zwraca prawdę, gdy `window.matchMedia('(prefers-reduced-motion: reduce)')` pasuje. Nasłuchuje zmiany i sprząta nasłuch w efekcie. To jest efekt świata poza Reactem, zgodny z zasadą numeru `02`, nie efekt „przepisz props do stanu” bez powodu: wartość pochodzi z systemu.

Na telefonie funkcja czyta ustawienie dostępności „ogranicz ruch” i zwraca tę samą prawdę. `motion.ts` dostaje `reduced` i zwraca `duration: 0`. Krzywa przy czasie zero nie ma znaczenia; i tak ją bierzemy z tokenu, żeby gałąź nie wprowadzała `linear` wpisanego na sztywno jako druga krzywa.

Brak tej gałęzi przegrywa, bo maszt na 1200 milisekund chowa treść przed osobą, która wyłączyła animację. Osobna, uboższa strona „bez JS” przegrywa, bo treść ma być ta sama, tylko bez oczekiwania. `duration: 1` jako „prawie zero” przegrywa, bo nadal jest literałem i nadal rusza układem.

Koszt: dwa źródła sygnału, media query i API telefonu, z jedną funkcją wyniku. Test webu ustawia media query i sprawdza, że nagłówek masztu jest w dokumencie bez czekania na czas `heroPin`. Test funkcji sprawdza `duration === 0`.

Gdy ograniczenie jest wyłączone, `sectionTransition(false).duration` równa się `tokens.duration.reveal`. Test porównuje do pola obiektu, nie do liczby `700`. Dzięki temu zmiana tokenu nie wymaga zmiany oczekiwanej liczby w tym numerze. Strażnik liczby `700` zostaje w teście motywu.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/shared/theme/motion.ts` | `sectionTransition`, `listItemTransition`, `heroTransition`, `navTransition` |
| `src/clients/shared/theme/motion.test.ts` | czas równy polu tokenu, zero przy ograniczeniu |
| `src/clients/web/src/app/useReducedMotion.ts` | `prefers-reduced-motion` |
| `src/clients/web/src/pages/home/Hero.tsx` | pas masztu, `motion.header` albo `motion.section` |
| `src/clients/web/src/app/Shell.tsx` | belka woła `navTransition` |
| `src/clients/mobile/src/app/useReducedMotion.ts` | ustawienie dostępności telefonu |
| `src/clients/mobile/src/screens/HomeScreen.tsx` | maszt na liczbach z `heroTransition` |
| `src/clients/mobile/src/motion/timing.ts` | `withTiming` z wynikiem `motion.ts`, bez literału |

`Hero.tsx` zostaje funkcją w osobnym pliku. `HomePage` go składa. Jeden `h1` zostaje na stronie, w pasie albo nad nim, nie w obu.

`timing.ts` telefonu:

```ts
import { withTiming } from 'react-native-reanimated';
import { sectionTransition } from '@jjdevhub/theme/motion';

export function enter(reduced: boolean) {
  const transition = sectionTransition(reduced);
  return withTiming(1, {
    duration: transition.duration,
    easing: bezierFromToken(transition.easing),
  });
}
```

`bezierFromToken` czyta krotkę z tokenu. Nie przyjmuje czterech liczb z wywołania w ekranie. Jeśli Reanimated wymaga obiektu `Easing.bezier`, argumenty biorą się z krotki `tokens.easing.reveal` (albo innego klucza, który zwróciła funkcja), nie z literału w `HomeScreen`.

## Plan

### 1. Czyste funkcje

Dodaj `motion.ts` obok `tokens.ts`. Eksport pakietu `@jjdevhub/theme` wskazuje też `./motion.ts`, na przykład pod ścieżką `./motion`. Plik importuje tylko `tokens` z tego samego katalogu.

`sectionTransition(false)` zwraca `duration: tokens.duration.reveal` i `easing: tokens.easing.reveal`. `sectionTransition(true)` zwraca `duration: 0` i tę samą krzywą. Analogicznie pozostałe funkcje według tabeli. `heroTransition` zwraca dwa czasy, `pin` i `fade`, oba zero, gdy ruch jest ograniczony.

Nie wpisuj `700` w tym pliku. Porównanie w teście idzie przez identyczność z polem `tokens.duration`.

### 2. Web

Dodaj zależność `motion`. W `Hero.tsx` użyj `motion.section` albo `motion.header` z czasem z `heroTransition(useReducedMotion())`. `h1` zostaje prawdziwym nagłówkiem. Treść masztu (skrót z home) jest w drzewie od pierwszej klatki, gdy ruch jest ograniczony.

`useReducedMotion` subskrybuje media query i zwraca boolean. Efekt czyści nasłuch.

Listy kursów i notatek, jeśli wchodzą animacją, biorą `listItemTransition`. Belka bierze `navTransition` i nie dokłada literału w `transition`.

### 3. Telefon

Dodaj `react-native-reanimated`. `timing.ts` woła `withTiming` wyłącznie z liczbą z `motion.ts`. `HomeScreen` używa `enter` albo `heroTransition` przez ten plik. `useReducedMotion` czyta ustawienie systemu.

Nie dodawaj `motion` do pakietu telefonu. Nie dodawaj Reanimated do pakietu webu.

### 4. Zakaz literału

Przeszukaj wywołania. W plikach, które importują `motion/react` albo `react-native-reanimated`, nie ma literału czasu. Dozwolone zero jest tylko wewnątrz `motion.ts`, jako gałąź ograniczenia, i test pilnuje, że to jedyne miejsce.

### 5. Test widoku

Na webie, przy `prefers-reduced-motion: reduce`, render `HomePage` znajduje nagłówek bez sztucznego opóźnienia testu. Przy ruchu włączonym ten sam nagłówek też jest w dokumencie: animacja nie usuwa go z dostępności. Test nie sprawdza piksela przesunięcia.

### Co jest do czego

- `motion.ts` — jedyne miejsce, które wybiera klucz czasu. Wołają je web i telefon. Nie woła biblioteki UI.
- `sectionTransition` — wejście sekcji. Strona nie przekazuje własnych milisekund.
- `listItemTransition` — wiersz listy, także wiersz skrzynki, jeśli jest animowany.
- `heroTransition` — pas masztu, dwa klucze `heroPin` i `heroFade`.
- `navTransition` — belka, klucz `nav`.
- `useReducedMotion` — sygnał systemu. Są dwie implementacje, web i telefon, jeden kształt wyniku: boolean.
- `Hero.tsx` — pas na home webu. Składa go `HomePage`.
- `timing.ts` — adapter Reanimated. Ekran telefonu nie woła `withTiming` z liczbą wpisaną na miejscu.

## Testy

Vitest. Funkcje z `motion.ts` nie potrzebują jsdom. Test widoku webu potrzebuje jsdom i Testing Library. Każdy fakt ma jeden powód do padnięcia.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `section_uses_reveal_token` | `reduced` równe `false` | `sectionTransition` | `duration` to `tokens.duration.reveal` |
| `section_reduced_is_zero` | `reduced` równe `true` | `sectionTransition` | `duration` równe `0` |
| `list_uses_reveal_fast` | ruch włączony | `listItemTransition` | czas to `tokens.duration.revealFast` |
| `hero_uses_pin_and_fade` | ruch włączony | `heroTransition` | `pin` to `tokens.duration.heroPin`, `fade` to `tokens.duration.heroFade` |
| `nav_uses_nav_token` | ruch włączony | `navTransition` | czas to `tokens.duration.nav` |
| `easing_is_token_tuple` | ruch włączony | `sectionTransition` | krzywa to `tokens.easing.reveal` |
| `reduced_hero_text_is_visible` | media `reduce` | render home | nagłówek jest w dokumencie |
| `motion_import_is_from_motion_react` | pliki webu | `rg` | import z `motion/react`, brak `framer-motion` |

```bash
node --experimental-strip-types --test src/clients/shared/theme/motion.test.ts
cd src/clients/web && pnpm exec vitest run
```

Szukanie literału w adapterach:

```bash
rg -n "duration:\s*[0-9]+|withTiming\([^)]*[0-9]{3}" src/clients/web/src src/clients/mobile/src
```

Trafienie w `motion.ts` dla zera przy gałęzi ograniczenia jest dozwolone tylko w tym pliku. Trafienie `250` albo `700` w ekranie jest błędem. Komenda po ekranach:

```bash
rg -n "\b(250|300|400|600|700|1200)\b" src/clients/web/src src/clients/mobile/src
```

Brak trafień w plikach ekranów i w `Shell`. Jeśli trafienie padnie na test, który celowo pilnuje braku literału, przenieś oczekiwanie na porównanie z `tokens.duration`, żeby komenda została pusta.

## Zasady

- Web importuje ruch z `motion/react`. Telefon używa Reanimated. Pakiety się nie krzyżują.
- Czas animacji pochodzi z `tokens.duration` przez `motion.ts`.
- Krzywa pochodzi z `tokens.easing`. Komponent nie wpisuje czterech liczb.
- `prefers-reduced-motion` i ustawienie telefonu dają czas `0`.
- Przy czasie zero treść jest w drzewie. Maszt nie czeka na `heroPin`.
- `styles.css` nie dostaje `@keyframes` z milisekundą. Prosta zmiana koloru zostaje przy klasie `duration-*` z numeru `03`, która i tak wskazuje zmienną tokenu.
- `motion.ts` nie importuje Reacta, Motion ani Reanimated.
- Nowy czas nie powstaje w tym numerze. Najpierw klucz w `01`, potem użycie.
- HTML masztu zostaje nagłówkiem i sekcją. Telefon zostaje przy widokach natywnych.
- Skrzynka powiadomień nie dostaje własnej skali czasu.

## Poza zakresem

- Wartości milisekund i krotek krzywych — [01-motyw.md](01-motyw.md). Ten numer tylko je wybiera po kluczu.
- Klasy `duration-nav` w CSS — [03-wyglad.md](03-wyglad.md).
- Skład ekranów telefonu i NativeWind — [06-mobile.md](06-mobile.md).
- Rejestracja pusha i kanały — [07-powiadomienia.md](07-powiadomienia.md).
- Po tym numerze nie stawia się maszyny. Obraz weba i telefonu wjeżdża jobem z [16-deploy.md](../cicd/16-deploy.md). Maszyna już stoi w [08-proxmox.md](../cicd/08-proxmox.md). Ten numer nie opisuje obrazu, Proxmoxa ani wdrożenia.
- GSAP, Lenis, wspólny parallax webu i telefonu, druga oś czasu.
- Tamagui i animacja jako powód wspólnych komponentów.

## Źródła

- [Motion for React](https://motion.dev/docs/react) — import z `motion/react`.
- [Reanimated withTiming](https://docs.swmansion.com/react-native-reanimated/docs/animations/withTiming) — czas i krzywa jako argument, tu z tokenu.
- [prefers-reduced-motion](https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-reduced-motion) — sygnał przeglądarki, który zeruje czas.
- [React Native AccessibilityInfo](https://reactnative.dev/docs/accessibilityinfo) — sygnał „ogranicz ruch” na telefonie.
- [WCAG 2.2: Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html) — ruch, który da się wyłączyć, a treść zostaje.

## Gotowe gdy

- `sectionTransition(false)` zwraca `tokens.duration.reveal`, a `sectionTransition(true)` zwraca czas `0`.
- Maszt używa `heroPin` i `heroFade`, belka używa `nav`, lista używa `revealFast`.
- Przy `prefers-reduced-motion: reduce` nagłówek home jest w dokumencie.
- Web nie importuje `framer-motion` ani Reanimated. Telefon nie importuje `motion`.
- W ekranach nie ma literału `250`, `300`, `400`, `600`, `700` ani `1200`.
- `node --experimental-strip-types --test src/clients/shared/theme/motion.test.ts` kończy się kodem 0.
- `cd src/clients/web && pnpm exec vitest run` kończy się kodem 0.
