# Lista kursów na telefonie

Telefon dostaje własny ekran listy wykładów. Klasy Tailwinda malują komponenty React Native. Ten sam produkt (`pl` / `en`, wykłady z JSON w bundlu) i osobny plik względem weba.

## Po co

Ekran pokazuje tytuł sekcji, lead i jedną kolumnę kart. Każda karta to `slug`, tytuł, podpis i akapity `summary`. Dotknięcie przekazuje `slug` dalej. Pusta tablica `items` pokazuje komunikat i nie buduje listy.

Webowy `CoursesPage` zostaje w `src/Clients/web`. Telefon go nie importuje i nie składa tej listy z HTML.

## Wersje i pakiety

- React Native 0.84 w `src/Clients/mobile/JJDevHubMobile`, React 19 (ta sama linia co web, 19.2.3).
- NativeWind z linii v5, bo klasy biorą Tailwind v4. NativeWind v4 zostaje przy Tailwindzie 3 i na tym ekranie nie występuje.
- Liczby kolorów, skali, odstępów i radiusu: [`src/Clients/shared/theme/tokens.ts`](../../../src/Clients/shared/theme/tokens.ts), opis w [`motyw.md`](../motyw.md).
- `react-native-safe-area-context` daje `SafeAreaView` wokół listy.
- Wpięcie Metro, CSS i nazwy klas z tokenów: [`01-instalacja.md`](01-instalacja.md). Ten plik tylko używa gotowych klas.

## Ścieżki w repo

| Plik | Rola |
| --- | --- |
| `src/Clients/mobile/JJDevHubMobile/src/screens/courses/CoursesScreen.tsx` | Ekran listy i pusty stan |
| `src/Clients/mobile/JJDevHubMobile/src/screens/courses/CourseRow.tsx` | Jedna karta |
| `src/Clients/mobile/JJDevHubMobile/src/content/courses.ts` | Odczyt sekcji `courses` z bundla |
| `src/Clients/web/src/content/pl.json` | Treść `pl`, w tym `courses.empty` |
| `src/Clients/web/src/content/en.json` | Treść `en`, w tym `courses.empty` |

Ekran stosu nazywa się `Courses`. Locale `pl` albo `en` przychodzi propsem. Adresu URL na telefonie nie ma.

## Tutorial

### 1. Komunikat pustej listy w JSON

Obok `title`, `lead` i `backLabel` dochodzi wymagane pole `empty`. Strażnik sekcji kursów na webie sprawdza ten napis razem z pozostałymi, żeby oba bundla miały to samo pole.

`pl`:

```json
"empty": "W tym języku nie ma jeszcze wykładów."
```

`en`:

```json
"empty": "There are no courses in this language yet."
```

`courses.ts` importuje te dwa pliki JSON i zwraca `{ title, lead, empty, items }`. Z pozycji bierze `slug`, `title`, `subtitle` i `summary`. Lekcje, rozdziały i adresy repo zostają poza listą. Import idzie w pliki JSON, nie w `src/Clients/web/src/app/`.

Gdy Metro nie widzi JSON poza katalogiem aplikacji, katalog `src/Clients/web/src/content` dopisuje się do obserwowanych ścieżek tak, jak opisuje [`01-instalacja.md`](01-instalacja.md). Drugiej listy kursów w szkielecie mobilnym nie ma.

### 2. Karta

`CourseRow` to nazwany eksport, funkcja, jeden plik. `className` siedzi na `Pressable` i na każdym `Text`. Kolor tekstu w React Native nie spływa z rodzica.

```tsx
interface CourseRowProps {
  slug: string;
  title: string;
  subtitle: string;
  summary: string[];
  onPress: () => void;
}

export function CourseRow({ title, subtitle, summary, onPress }: CourseRowProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={title}
      onPress={onPress}
      className="mb-6 rounded-card bg-white px-5 py-5 active:opacity-80"
    >
      <Text className="font-sans text-h4 text-ink">{title}</Text>
      <Text className="mt-2 font-sans text-small text-muted">{subtitle}</Text>
      {summary.map((paragraph) => (
        <Text key={paragraph} className="mt-3 font-sans text-body text-ink">
          {paragraph}
        </Text>
      ))}
    </Pressable>
  );
}
```

`slug` zostaje w propsach, żeby rodzic mógł go oddać w `onPress` bez indeksu listy.

### 3. Ekran

Pusta tablica wraca wcześniej. Wtedy na ekranie jest `SafeAreaView` i dwa teksty. `FlatList` powstaje dopiero, gdy `items` ma pozycje.

```tsx
interface CoursesScreenProps {
  locale: 'pl' | 'en';
  onOpenCourse: (slug: string) => void;
}

export function CoursesScreen({ locale, onOpenCourse }: CoursesScreenProps) {
  const section = coursesSection(locale);

  if (section.items.length === 0) {
    return (
      <SafeAreaView className="flex-1 justify-center bg-canvas px-5">
        <Text className="font-sans text-h2 text-ink">{section.title}</Text>
        <Text className="mt-4 font-sans text-body text-muted">{section.empty}</Text>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView className="flex-1 bg-canvas">
      <FlatList
        className="flex-1"
        data={section.items}
        keyExtractor={(course) => course.slug}
        contentContainerClassName="px-5 pb-7 pt-7"
        ListHeaderComponent={
          <View className="mb-8">
            <Text className="font-sans text-h2 text-ink">{section.title}</Text>
            <Text className="mt-4 font-sans text-body text-muted">{section.lead}</Text>
          </View>
        }
        renderItem={({ item }) => (
          <CourseRow
            slug={item.slug}
            title={item.title}
            subtitle={item.subtitle}
            summary={item.summary}
            onPress={() => onOpenCourse(item.slug)}
          />
        )}
      />
    </SafeAreaView>
  );
}
```

Jedyny przewijany widok to `FlatList`. `className="flex-1"` trzyma listę w obszarze pod bezpiecznym marginesem. Odstęp treści listy to `contentContainerClassName`. Nagłówek jedzie z listą jako `ListHeaderComponent`.

Rejestracja na stosie, locale z aplikacji:

```tsx
<Stack.Screen name="Courses">
  {(props) => (
    <CoursesScreen
      locale={locale}
      onOpenCourse={(slug) => props.navigation.navigate('Course', { slug })}
    />
  )}
</Stack.Screen>
```

Układ ekranu `Course` jest poza tym plikiem. Callback oddaje sam `slug`.

### 4. Podgląd

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm install
pnpm start
```

Drugi terminal:

```bash
cd src/Clients/mobile/JJDevHubMobile
pnpm android
```

Wejście „Wykłady” otwiera `Courses` z bieżącym locale. Na czas sprawdzenia listy ten ekran może być pierwszy na stosie.

## Przypadki użycia

### Lista

Locale `pl` czyta `pl.json`, `en` czyta `en.json`. Bundel ma dwie pozycje: `mobile` i `web`. Ekran pokazuje tytuł sekcji, lead i dwie karty. Karta `mobile` ma tytuł „Aplikacje mobilne” po polsku i „Mobile applications” po angielsku. Dotknięcie woła `onOpenCourse` ze `slug` tej karty. Sieci przy tym nie ma.

### Pusty stan

`items` równe `[]` maluje tytuł sekcji i `empty` na środku płótna. Listy, separatorów i drugiego scrolla nie ma. Lead („Sylabusy…”) przy pustej tablicy zostaje schowany, bo opisuje istniejące kursy. Po polsku widać „W tym języku nie ma jeszcze wykładów.”, po angielsku „There are no courses in this language yet.”

## Zasady wyglądu

Klasy nazywają klucze z tokenów. Heksy i piksele zostają w `tokens.ts`.

| Klasa | Klucz |
| --- | --- |
| `bg-canvas` | `color.canvas` `#f5f5f7` |
| `bg-white` | `color.white` |
| `text-ink` | `color.ink` `#1d1d1f` |
| `text-muted` | `color.muted` |
| `text-h2` | `font.size.h2` (40) — tytuł ekranu |
| `text-h4` | `font.size.h4` (21) — tytuł karty |
| `text-body` | `font.size.body` (17) |
| `text-small` | `font.size.small` (14) |
| `font-sans` | `font.family` Inter |
| `px-5`, `py-5` | `space.5` (24) |
| `mb-6` | `space.6` (32) między kartami |
| `mb-8`, `pt-7`, `pb-7` | `space.8` (64) pod leadem, `space.7` (48) przy krawędzi listy |
| `rounded-card` | `radius.card` (18) |
| `active:opacity-80` | stan wciśnięcia wiersza |

Karta jest biała na płótnie, bez obrysu. Akcent `#0071e3` na tej liście nie maluje tła karty. Jedna kolumna na całą szerokość bezpiecznego obszaru. Tytuł ekranu bierze stopień `h2` ze wspólnej skali. Stopień `display` (80) zostaje przy hero na home.

Tło ekranu i kart jest kryjące. W klasach nie ma `backdrop-blur` ani `backdrop-filter`.

## Poza zakresem

- Wpięcie NativeWind, Metro i `@theme`: [`01-instalacja.md`](01-instalacja.md).
- Szerokość artykułu, nav i siatka kart weba: [`tailwind/03-uklad.md`](../tailwind/03-uklad.md).
- Przycisk, pole, karta z katalogu i formularz logowania: [`reusables.md`](../reusables.md).
- Przesunięcie hero względem offsetu listy: [`reanimated.md`](../reanimated.md).
- Szczegół kursu, kompendium, notatki, CV, login i register (`fetch` tylko przy auth).
- Intranet, Tamagui, shadcn, Motion, scroll dokumentu (`window`, `document`, Lenis).
- Testy, które sprawdzają nazwy klas.

## Gotowe gdy

- `CoursesScreen` i `CourseRow` leżą w szkielecie mobilnym i nie importują stron z `src/Clients/web/src/app/`.
- Lista `pl` i `en` maluje tytuł, lead i karty klasami z tabeli. `key` karty to `slug`.
- Pusta tablica pokazuje `empty` i nie renderuje `FlatList`.
- Przewija się wyłącznie `FlatList`. W klasach ekranu nie ma `backdrop-blur` ani `backdrop-filter`.
- `courses.empty` jest w obu plikach JSON i przechodzi strażnik sekcji kursów.
