# React Native Reusables

Katalog przycisku, pola, karty i formularza logowania na telefonie. CLI kopiuje źródła do szkieletu `src/Clients/mobile/JJDevHubMobile`. Ekran logowania składa te pliki. Webowy `AuthForm` zostaje w `src/Clients/web`.

Wpięcie NativeWind, Metro i blok `@theme` są w [nativewind/01-instalacja.md](nativewind/01-instalacja.md). Ten plik zaczyna się, gdy klasy z tokenów (`bg-canvas`, `text-ink`, `bg-accent`, `font-sans`, `rounded-card`) już działają na szkielecie.

## Po co

Przycisk, pole i karta mają leżeć w repo jako zwykłe pliki, tak jak shadcn na webie. Rejestr React Native Reusables jest źródłem kopii pod NativeWind. Po skopiowaniu klasy w tych plikach wskazują nazwy z [motyw.md](motyw.md), a formularz woła to samo `POST /api/auth/login` co klient web.

Lista kursów zostaje przy `CourseRow` z [nativewind/02-ekrany.md](nativewind/02-ekrany.md). Ten katalog jej nie podmienia.

## Wersje i pakiety

| Element | Wersja / nazwa | Rola |
| --- | --- | --- |
| React Native | `0.84` | szkielet `src/Clients/mobile/JJDevHubMobile` |
| `react` | `19.2.3` | ta sama linia co web |
| NativeWind | linia v5 | już wpięty; tutorial instalacji jest w [01-instalacja.md](nativewind/01-instalacja.md) |
| `@react-native-reusables/cli` | `pnpm dlx …@latest` | tylko narzędzie kopii, bez wpisu w `dependencies` |
| `class-variance-authority`, `clsx`, `tailwind-merge` | dopisuje CLI | warianty przycisku i `cn` w `src/lib/utils.ts` |
| `@rn-primitives/slot`, `@rn-primitives/label` | dopisuje CLI | prymitywy przycisku i etykiety |

Menedżer pakietów szkieletu to pnpm. Flaga `--styling-library nativewind` jest obowiązkowa przy `add`, żeby CLI wzięło wariant NativeWind.

## Ścieżki w repo

Wszystko poniżej jest w `src/Clients/mobile/JJDevHubMobile/`.

| Plik | Rola |
| --- | --- |
| `components.json` | ścieżki CLI i alias `@rnr` |
| `src/components/ui/button.tsx` | przycisk |
| `src/components/ui/input.tsx` | pole tekstowe |
| `src/components/ui/label.tsx` | podpis pola |
| `src/components/ui/card.tsx` | karta |
| `src/components/ui/text.tsx` | tekst, którego importują przycisk i karta |
| `src/lib/utils.ts` | `cn` |
| `src/screens/login/AuthForm.tsx` | pola, karta, przycisk; bez `fetch` |
| `src/screens/login/LoginScreen.tsx` | napisy logowania i `onSubmit` |
| `src/auth/auth.ts` | `POST /api/auth/login` i klucz `jjdevhub.token` |

Alias `@/` zostaje przy kliencie web ([vite/02-aliasy.md](vite/02-aliasy.md)). Telefon importuje katalog przez `@rnr/…`, rozwiązane na `src/` tego szkieletu. `tsconfig.json` aplikacji:

```json
{
  "compilerOptions": {
    "paths": {
      "@rnr/*": ["./src/*"]
    }
  }
}
```

Metro ma widzieć ten sam alias obok resolvera z instalacji NativeWind. Pluginu Metro z tamtego pliku nie zastępuj.

## Tutorial

Katalog roboczy każdej komendy: `src/Clients/mobile/JJDevHubMobile`.

### 1. `components.json`

Zapisz plik w katalogu aplikacji, zanim padnie `add`. Pole `tailwind.css` wskazuje wejście CSS NativeWind z [01-instalacja.md](nativewind/01-instalacja.md). Drugiego arkusza nie ma. `tailwind.config` zostaje pusty: liczby klas biorą się z `@theme`, nie z konfiguracji Tailwind 3.

`baseColor` w pliku CLI może zostać `neutral`. Krok 3 i tak podmienia klasy na tokeny. Szary motyw z rejestru nie jest paletą produktu.

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "TU-WEJŚCIE-CSS-Z-NATIVEWIND",
    "baseColor": "neutral",
    "cssVariables": true
  },
  "aliases": {
    "components": "@rnr/components",
    "utils": "@rnr/lib/utils",
    "ui": "@rnr/components/ui",
    "lib": "@rnr/lib",
    "hooks": "@rnr/hooks"
  }
}
```

`TU-WEJŚCIE-CSS-Z-NATIVEWIND` zamień na ścieżkę pliku CSS ze szkieletu (tę, którą wpiął NativeWind).

### 2. Kopia czterech elementów

```bash
pnpm dlx @react-native-reusables/cli@latest add --styling-library nativewind -y -p src/components/ui button input label card text
```

CLI zapisuje pliki `.tsx` w `src/components/ui/` i dopisuje prymitywy do `package.json`. `text` schodzi razem z przyciskiem i kartą, bo oba go importują. Komenda `init` tu nie występuje: składa nową aplikację i omija istniejący szkielet.

Sprawdzenie:

```bash
pnpm dlx @react-native-reusables/cli@latest doctor --summary
```

Import w skopiowanym pliku ma postać `@rnr/lib/utils` i `@rnr/components/ui/text`.

### 3. Klasy z tokenów

W `button.tsx`, `input.tsx`, `label.tsx`, `card.tsx` i `text.tsx` zamień klasy rejestru na nazwy z [motyw.md](motyw.md). Z plików schodzą `bg-primary`, `bg-background`, `text-foreground`, `text-muted-foreground`, `border-input`, `border-border`, `bg-card` oraz paleta domyślna (`zinc`, `slate`, `gray`, `neutral`). Heks w `className` nie dochodzi.

Zostaw wariant, którego używa logowanie. Resztę wariantów przycisku usuń, żeby w pliku nie został kolor spoza tokenów.

`button.tsx`, wariant `default`:

```tsx
const buttonVariants = cva('font-sans text-small active:opacity-80', {
  variants: {
    variant: {
      default: 'bg-accent text-white rounded-pill px-5 py-3',
    },
  },
  defaultVariants: {
    variant: 'default',
  },
});
```

`disabled` na przycisku zostawia ten sam akcent i dokładnia `opacity-50`.

Pole w `input.tsx` w spoczynku:

```tsx
className={cn(
  'bg-canvas font-sans text-body tracking-body text-ink rounded-md px-4 py-3',
  className,
)}
```

Fokus dokłada `border border-accent`. Spoczynek obrysu nie ma. `label.tsx` używa `font-sans text-small text-ink`.

Karta w `card.tsx`: `bg-white rounded-card p-7`. Obrysu i cienia nie ma — biel odcina się od `bg-canvas`. Odstęp między dziećmi to `gap-5`.

`text.tsx` zostawia `font-sans text-ink`. Kolor i stopień dopisuje ekran przez `className`.

### 4. Formularz

`AuthForm` jest funkcją, eksportem nazwanym, jednym plikiem. Stan: `email`, `password`, `error`, `pending`. Napis przycisku wynika z `pending`. Plik nie woła `fetch`.

Email: `keyboardType="email-address"`, `autoCapitalize="none"`, `autoComplete="username"`, `required` po stronie walidacji ekranu (pusty string nie wychodzi w `onSubmit`). Hasło: `secureTextEntry`, `autoComplete` z propsa, długość co najmniej 8 znaków zanim poleci żądanie. Krótsze hasło zostawia komunikat pod polem i nie woła API.

```tsx
import { useState } from 'react';
import { View } from 'react-native';

import { Button } from '@rnr/components/ui/button';
import { Card } from '@rnr/components/ui/card';
import { Input } from '@rnr/components/ui/input';
import { Label } from '@rnr/components/ui/label';
import { Text } from '@rnr/components/ui/text';

interface AuthFormProps {
  title: string;
  submitLabel: string;
  pendingLabel: string;
  passwordAutoComplete: 'current-password' | 'new-password';
  hint: string;
  onHintPress: () => void;
  onSubmit: (email: string, password: string) => Promise<void>;
}

export function AuthForm({
  title,
  submitLabel,
  pendingLabel,
  passwordAutoComplete,
  hint,
  onHintPress,
  onSubmit,
}: AuthFormProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [focused, setFocused] = useState<'email' | 'password' | null>(null);

  async function submit(): Promise<void> {
    if (email.trim() === '' || password.length < 8) {
      setError('Invalid email or password.');
      return;
    }
    setPending(true);
    setError(null);
    try {
      await onSubmit(email, password);
    } catch (err) {
      setPending(false);
      setError(err instanceof Error ? err.message : 'Something went wrong.');
    }
  }

  const fieldClass = (name: 'email' | 'password') =>
    focused === name ? 'border border-accent' : '';

  return (
    <View className="flex-1 justify-center bg-canvas px-5">
      <Card>
        <Text className="font-sans text-h3 text-ink">{title}</Text>
        <View className="mt-5 gap-5">
          <View>
            <Label>Email</Label>
            <Input
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoComplete="username"
              onFocus={() => setFocused('email')}
              onBlur={() => setFocused(null)}
              className={fieldClass('email')}
            />
          </View>
          <View>
            <Label>Password</Label>
            <Input
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              autoComplete={passwordAutoComplete}
              onFocus={() => setFocused('password')}
              onBlur={() => setFocused(null)}
              className={fieldClass('password')}
            />
          </View>
          {error ? (
            <Text accessibilityLiveRegion="polite" className="font-sans text-small text-accent">
              {error}
            </Text>
          ) : null}
          <Button disabled={pending} onPress={() => void submit()}>
            <Text className="font-sans text-small text-white">
              {pending ? pendingLabel : submitLabel}
            </Text>
          </Button>
          <Text className="font-sans text-small text-accent" onPress={onHintPress}>
            {hint}
          </Text>
        </View>
      </Card>
    </View>
  );
}
```

Eksporty `Card`, `Label`, `Input` i `Button` mają się zgadzać z nazwami, które zapisało CLI. Gdy rejestr owija kartę w `CardHeader` i `CardContent`, formularz używa tych części, a klasy tła, promienia i paddingu zostają na zewnętrznym `Card`.

`LoginScreen` podaje `title="Log in"`, `submitLabel="Log in"`, `pendingLabel="Signing in…"`, `passwordAutoComplete="current-password"` i hint prowadzący na ekran rejestracji. `onSubmit` woła `login` z `src/auth/auth.ts`.

Żądanie ma to samo ciało co web ([react/03-tresc-i-auth.md](react/03-tresc-i-auth.md)): `POST /api/auth/login`, nagłówek `Content-Type: application/json`, JSON `{ email, password }`, bez `Authorization`. Origin to adres API widoczny z telefonu. Ścieżka zostaje `/api/auth/login`. Odpowiedź 200 czyta pole `token`, zapisuje je pod kluczem `jjdevhub.token` i schodzi na ekran `Courses`. Odpowiedź 401 rzuca `Error` z tekstem `Invalid email or password.`. Inna porażka rzuca `Something went wrong.` albo zdania z `errors`, zlepione spacją. `GET /api/auth/me` nie odtwarza sesji.

Sukces zostawia `pending` do zejścia z ekranu. Błąd zdejmuje `pending` i pokazuje jeden tekst akcentem.

Rejestracja jest drugim ekranem na tym samym `AuthForm`: napisy `Create account` / `Creating account…`, `passwordAutoComplete="new-password"`, `POST /api/auth/register`, sukces ze statusem 201 i ten sam klucz tokenu.

## Przypadki użycia

### Przycisk

Na logowaniu jeden przycisk `default`: tło akcentu, biały napis, kapsuła. W trakcie żądania jest `disabled` i czyta `Signing in…`. Wciśnięcie poza `disabled` ma `active:opacity-80`.

### Pole

Dwa pola, email nad hasłem. Podpis `text-small text-ink` stoi nad kontrolką. Kontrolka w spoczynku jest płótnem na białej karcie, bez obrysu. Fokus dokłada jedną kreskę `border-accent`. Hasło jest zamaskowane.

### Karta

Formularz leży na jednej białej karcie na płótnie `bg-canvas`, z `rounded-card` i `p-7`. Lista kursów tej karty nie używa.

### Formularz logowania

Gość widzi tytuł `Log in`, pola `Email` i `Password`, przycisk `Log in` i zdanie prowadzące do rejestracji. Puste pole albo hasło krótsze niż 8 znaków pokazuje `Invalid email or password.` i nie wysyła żądania. 401 pokazuje to samo zdanie i zostawia gościa na formularzu. 200 zapisuje `jjdevhub.token` i otwiera `Courses`.

## Zasady wyglądu

Klasy nazywają klucze z [motyw.md](motyw.md). Heksy zostają w `tokens.ts`.

| Element | Klasy |
| --- | --- |
| Tło ekranu | `flex-1 bg-canvas px-5` |
| Karta | `bg-white rounded-card p-7` |
| Tytuł | `font-sans text-h3 text-ink` |
| Podpis pola | `font-sans text-small text-ink` |
| Pole | `bg-canvas font-sans text-body tracking-body text-ink rounded-md px-4 py-3` |
| Fokus pola | `border border-accent` |
| Błąd | `font-sans text-small text-accent` |
| Przycisk | `bg-accent text-white rounded-pill px-5 py-3 font-sans text-small active:opacity-80` |
| Przycisk wyłączony | te same klasy i `opacity-50` |
| Odstęp pól | `gap-5` |

Duży oddech: padding karty `p-7`, pola rozdzielone `gap-5`. Obrys ma tylko pole w fokusie. Cienia, skali i drugiej palety nie ma. Krój to Inter (`font-sans`).

Komunikat błędu na webie jest tym samym akcentem ([tailwind/05-stany.md](tailwind/05-stany.md)). Na telefonie jest `Text` z `accessibilityLiveRegion="polite"`.

## Poza zakresem

- Instalacja NativeWind, Metro, `@theme` i pierwsze klasy na liście kursów — [nativewind/01-instalacja.md](nativewind/01-instalacja.md), [nativewind/02-ekrany.md](nativewind/02-ekrany.md).
- Kontrakt liczb — [motyw.md](motyw.md).
- shadcn, alias `@/` i formularz HTML weba — [shadcn/03-komponenty.md](shadcn/03-komponenty.md), [vite/02-aliasy.md](vite/02-aliasy.md).
- `pnpm dlx @react-native-reusables/cli@latest init` oraz `add -a`.
- Uniwind (`--styling-library uniwind`).
- Katalog rejestru poza `button`, `input`, `label`, `card`, `text`.
- Hero, Reanimated, Motion, Tamagui, intranet.
- Proxy Vite. Telefon woła ten sam path i to samo ciało JSON pod adresem API urządzenia.

## Gotowe gdy

- W szkielecie leżą `components.json`, `src/lib/utils.ts` i pięć plików w `src/components/ui/` (`button`, `input`, `label`, `card`, `text`). Importy idą przez `@rnr/`, nie przez `@/` weba.
- W tych plikach klasy to nazwy z tabeli wyglądu. Nie ma `bg-primary`, `bg-background` ani heksa w `className`.
- `AuthForm` i `LoginScreen` nie importują `src/Clients/web`.
- Logowanie wysyła `POST /api/auth/login` z `{ email, password }`. 401 pokazuje `Invalid email or password.`. 200 zapisuje `jjdevhub.token` i otwiera `Courses`.
- `doctor --summary` przechodzi dla tej kopii, a `CourseRow` listy kursów zostaje bez importu z `components/ui`.
