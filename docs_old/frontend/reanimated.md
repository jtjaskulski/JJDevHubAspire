# Hero na liście telefonu

Jedno przesunięcie ciemnego hero o offset listy na ekranie home. Dotyczy wyłącznie szkieletu `src/Clients/mobile/JJDevHubMobile`. Web opisuje [motion/02-hero.md](motion/02-hero.md).

## Po co

Skala imienia, odcinki postępu i droga klatki są w `tokens.hero` oraz `tokens.duration.heroPin`. Web czyta je w [motion/02-hero.md](motion/02-hero.md). Telefon, gdy powstanie ekran home, bierze te same pola. Nie dostaje drugiej tabeli `0.4` / `0.55` wpisanej w komponencie. Przesunięcie listy poniżej zostaje modelem telefonu: `contentOffset`, nie pin dokumentu.

Na home telefonu hero i lista są rodzeństwem w jednym ekranie. Lista jest jedynym przewijanym widokiem. Jej `contentOffset.y` przesuwa hero w górę o tyle samo pikseli, ile użytkownik przewinął, aż hero zejdzie o własną wysokość.

Gdy system prosi o ograniczenie ruchu, hero zostaje w miejscu spoczynku (`translateY` równe `0`). Lista nadal się przewija pod nim. Treść hero jest widoczna od pierwszego rysowania.

To jeden przypadek: home, offset listy, wyłączenie tego przesunięcia. Drugiej sekwencji na innych ekranach nie ma.

## Wersje i pakiety

| Element | Wersja | Rola |
| --- | --- | --- |
| React Native | `0.84` | szkielet, New Architecture |
| `react` | `19.2.3` | ta sama linia co web |
| `react-native-reanimated` | `4.6` | scroll handler, styl hero, `useReducedMotion` |
| `react-native-worklets` | `0.12` | peer Reanimated 4.6 |

Linia `4.6` obejmuje React Native `0.84`. Linia `4.7` i nowsza tego wydania nie obejmuje. Menedżer pakietów szkieletu to pnpm.

Import idzie z `react-native-reanimated`: `Animated`, `useAnimatedScrollHandler`, `useAnimatedStyle`, `useReducedMotion`, `useSharedValue`.

`useReducedMotion()` zwraca wartość ustawienia z chwili startu aplikacji. Zmiana ustawienia w trakcie sesji nie przebudowuje komponentu. Gałąź statyczna czyta ten boolean.

Zegar tej sceny to offset listy. `tokens.duration` i `tokens.easing` zostają przy webie w [motion/02-hero.md](motion/02-hero.md). Tutaj hero czyta kolory i krój przez klasy NativeWind, a liczbę ruchu bierze z `contentOffset.y` i zmierzonej wysokości.

Kontrakt palety jest w [motyw.md](motyw.md). Wpięcie klas jest w [nativewind/01-instalacja.md](nativewind/01-instalacja.md).

## Ścieżki w repo

Wszystko poniżej, poza tokenami i JSON-em, jest w `src/Clients/mobile/JJDevHubMobile/`.

| Plik | Rola |
| --- | --- |
| `package.json` | `react-native-reanimated` i `react-native-worklets` |
| `babel.config.js` | plugin Reanimated jako ostatni wpis `plugins` |
| `src/screens/home/HomeScreen.tsx` | lista, offset, gałąź reduced motion |
| `src/screens/home/HomeHero.tsx` | ciemne pole hero |
| `src/Clients/shared/theme/tokens.ts` | kolory i skala, przez klasy |
| `src/Clients/web/src/content/pl.json`, `en.json` | napisy home |
| `cv.json` w bundlu | imię na hero |

`HomeScreen` dostaje locale `pl` albo `en` propsem. Adresu URL na telefonie nie ma. Ekran stosu nazywa się `Home`.

## Tutorial

Katalog roboczy komend: `src/Clients/mobile/JJDevHubMobile`.

### 1. Pakiety

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm add react-native-reanimated@4.6 react-native-worklets@0.12
```

W `babel.config.js` dopisz plugin na końcu tablicy `plugins`. Preset NativeWind zostaje przed nim.

```js
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['react-native-reanimated/plugin'],
};
```

Gdy w `plugins` są już inne wpisy, `react-native-reanimated/plugin` jest ostatni. Osobnego `react-native-worklets/plugin` obok niego nie ma: plugin Reanimated ten wpis zastępuje.

Po zmianie Babela zrestartuj Metro z czyszczeniem pamięci podręcznej.

```bash
pnpm start --reset-cache
```

### 2. Hero

`HomeHero` to nazwany eksport, funkcja, jeden plik. Przyjmuje styl animowany i pomiar layoutu. Klasy malują wewnętrzny `View`. `Animated.View` niesie tylko `translateY` i pozycję nad listą. Wysokość bierze się z layoutu, więc w klasie nie ma sztywnego piksela toru.

Transform nie zmienia ramki layoutu. `pointerEvents="none"` oddaje dotknięcia liście, gdy hero zjedzie w górę, a ramka zostaje na górze ekranu.

```tsx
import { Text, View, type LayoutChangeEvent, type ViewStyle } from 'react-native';
import Animated, { type AnimatedStyle } from 'react-native-reanimated';

interface HomeHeroProps {
  name: string;
  animatedStyle: AnimatedStyle<ViewStyle>;
  onLayout: (event: LayoutChangeEvent) => void;
}

const heroPosition = {
  position: 'absolute' as const,
  top: 0,
  left: 0,
  right: 0,
  zIndex: 1,
};

export function HomeHero({ name, animatedStyle, onLayout }: HomeHeroProps) {
  return (
    <Animated.View
      onLayout={onLayout}
      pointerEvents="none"
      style={[heroPosition, animatedStyle]}
    >
      <View accessibilityRole="header" className="bg-dark-chapter px-5 py-11">
        <Text className="font-sans text-display tracking-display text-dark-chapter-fg">{name}</Text>
      </View>
    </Animated.View>
  );
}
```

### 3. Offset listy

`HomeScreen` trzyma `scrollY` i wysokość hero. Handler listy zapisuje `contentOffset.y` na wątku UI. Styl hero odejmuje ten offset, przycięty do zmierzonej wysokości: przewinięcie o 40 px daje `translateY: -40`, a dalej przesunięcie staje na wysokości hero.

`useReducedMotion()` równe `true` zwraca `translateY: 0`. Handler może dalej zapisywać offset; styl go wtedy nie czyta.

Hero jest `absolute` na górze rodzica, więc nie dokłada drugiej wysokości nad listą. Lista dostaje `paddingTop` równy zmierzonej wysokości i startuje pod hero. Przy pełnym ruchu padding i `translateY` schodzą razem. Przy ograniczeniu ruchu hero stoi, a treść listy wjeżdża pod nie.

```tsx
import { useState } from 'react';
import { Text, View, type LayoutChangeEvent } from 'react-native';
import Animated, {
  useAnimatedScrollHandler,
  useAnimatedStyle,
  useReducedMotion,
  useSharedValue,
} from 'react-native-reanimated';

import { HomeHero } from './HomeHero';

interface HomeSection {
  id: string;
  title: string;
}

interface HomeScreenProps {
  locale: 'pl' | 'en';
  name: string;
  sections: HomeSection[];
}

export function HomeScreen({ name, sections }: HomeScreenProps) {
  const reduceMotion = useReducedMotion();
  const scrollY = useSharedValue(0);
  const heroHeightSv = useSharedValue(0);
  const [heroHeight, setHeroHeight] = useState(0);

  const onScroll = useAnimatedScrollHandler({
    onScroll: (event) => {
      scrollY.value = event.contentOffset.y;
    },
  });

  const heroStyle = useAnimatedStyle(() => {
    if (reduceMotion) {
      return { transform: [{ translateY: 0 }] };
    }
    const shift = Math.min(Math.max(scrollY.value, 0), heroHeightSv.value);
    return { transform: [{ translateY: -shift }] };
  }, [reduceMotion]);

  function onHeroLayout(event: LayoutChangeEvent) {
    const height = event.nativeEvent.layout.height;
    heroHeightSv.value = height;
    setHeroHeight(height);
  }

  return (
    <View className="flex-1 bg-canvas">
      <HomeHero name={name} animatedStyle={heroStyle} onLayout={onHeroLayout} />
      <Animated.FlatList
        className="flex-1"
        data={sections}
        keyExtractor={(section) => section.id}
        onScroll={onScroll}
        scrollEventThrottle={16}
        contentContainerStyle={{ paddingTop: heroHeight }}
        renderItem={({ item }) => (
          <Text className="px-5 py-5 font-sans text-h3 text-ink">{item.title}</Text>
        )}
      />
    </View>
  );
}
```

`locale` zostaje w propsach ekranu, żeby rodzic podał `pl` albo `en` przy odczycie bundla. Imię pochodzi z `cv.json`. Układ wiersza listy i karta wykładu są poza tym plikiem.

### 4. Podgląd

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm start
```

Drugi terminal:

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm android
```

Na czas sprawdzenia `Home` może być pierwszym ekranem stosu.

1. Wejście na home przy pełnym ruchu: ciemne hero z imieniem, lista zaczyna się pod nim.
2. Przewinięcie listy w górę treści: hero jedzie w górę o ten sam offset i zatrzymuje się po własnej wysokości.
3. Dalsze przewijanie: jedzie sama lista, na płótnie `#f5f5f7`.
4. Start aplikacji z włączonym ograniczeniem ruchu: hero zostaje na `translateY` równym `0`, imię jest widoczne, lista przewija się pod spodem.

## Przypadki użycia

### Home

Użytkownik otwiera `Home` z locale `pl` albo `en`. Hero pokazuje imię z CV w bundlu. Lista podaje offset.

Przy pełnym ruchu `translateY` hero jest ujemnym offsetem listy, nie większym co do wartości niż wysokość hero. Jedno pole `transform` robi całe przesunięcie.

Gdy `useReducedMotion()` zwraca `true`, styl hero to `translateY: 0` przez cały scroll. `paddingTop` listy zostaje przy zmierzonej wysokości, więc pierwszy wiersz startuje pod hero, a dalsze wiersze wjeżdżają pod nieruchome pole. Ten sam układ jest dla `pl` i `en`.

## Zasady wyglądu

Hero jest ciemnym polem: `bg-dark-chapter` (`#000000`), tekst `text-dark-chapter-fg` (`#f5f5f7`), krój `font-sans` (Inter), tytuł `text-display` ze `tracking-display`. Płótno listy to `bg-canvas` (`#f5f5f7`), tekst wiersza `text-ink` (`#1d1d1f`). Akcent `#0071e3` zostaje przy kontrolkach jasnych sekcji.

Oddech hero to `px-5` i `py-11` ze skali `space`. Obrysu nie ma. Ruch hero to wyłącznie `translateY` z offsetu. Krycie, skala i droga w pikselach z `duration.heroPin` zostają w scenie webu.

## Poza zakresem

- Przypięta scena webu, skala imienia i wejście rozdziałów: [motion/02-hero.md](motion/02-hero.md).
- Wejścia sekcji i zmiana widoku na webie: [motion/01-przejscia.md](motion/01-przejscia.md).
- Wpięcie NativeWind i nazwy klas: [nativewind/01-instalacja.md](nativewind/01-instalacja.md).
- Ekran listy wykładów i pusty stan: [nativewind/02-ekrany.md](nativewind/02-ekrany.md).
- Przycisk, pole i formularz logowania: [reusables.md](reusables.md).
- Pełna tabela tokenów: [motyw.md](motyw.md).
- CV, kompendium, notatka, login, register i intranet jako osobne ekrany z tym przesunięciem.
- GSAP, Lenis, biblioteka `motion`, Tamagui, scroll dokumentu.

## Gotowe gdy

- `react-native-reanimated@4.6` i `react-native-worklets@0.12` są zależnościami szkieletu, a plugin Babela jest ostatni w `plugins`.
- `HomeScreen` i `HomeHero` leżą w `src/screens/home/` i nie importują `HomePage` z klienta web.
- Hero jest `absolute` na górze ekranu, a `paddingTop` listy jest równy zmierzonej wysokości hero.
- Przy pełnym ruchu `translateY` hero jest równy ujemnemu `contentOffset.y` listy, przyciętemu do wysokości hero.
- Przy `useReducedMotion()` równym `true` hero ma `translateY` równe `0`, a lista nadal się przewija.
- Przesunięcie jest zamontowane tylko na `Home`.
- Scena webu zostaje w [motion/02-hero.md](motion/02-hero.md) i nie jest powtórzona w tym pliku.
