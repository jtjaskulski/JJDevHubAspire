# Intranet: edytor treści

Ten plik opisuje ekrany pisania w intranecie: edytor Markdown z podglądem z serwera, zapis z `If-Match` i rozwiązywanie konfliktu, szkic w przeglądarce, kolejność lekcji, przykłady kodu w lekcji, publikację i historię notatki oraz edycję CV z wyborem dowodów. Trasy, strażnik i listy są w [01-dostep-i-trasy.md](01-dostep-i-trasy.md), klient HTTP i `ServerHtml` w [react/05-tresc-z-api.md](../react/05-tresc-z-api.md).

## Po co

Źródłem wyjaśnienia jest Markdown z [19-learning.md](../../api/19-learning.md). Przykład kodu jest osobnym polem lekcji (`language`, `source`, podpis), nie blokiem w tym Markdownie. Edytor musi pokazywać dokładnie ten HTML wyjaśnienia, który zobaczy student, a zapis nie może po cichu nadpisać zmiany z drugiej karty.

## Dlaczego te narzędzia

- **CodeMirror 6.** Edytor tekstu z parserem Markdown (Lezer), podświetlaniem bloków kodu w kilkudziesięciu językach ładowanych na żądanie, autouzupełnianiem, historią, wyszukiwaniem i pełną obsługą czytników ekranu. Moduły ES, tree-shaking, ok. 150 kB po kompresji dla tego zestawu. Monaco (silnik VS Code) waży kilka megabajtów, wymaga web workerów i słabo działa na telefonie. Edytory WYSIWYG (TipTap, Milkdown na ProseMirror) trzymają dokument w swoim modelu i zamieniają go na Markdown przy zapisie, co gubi formatowanie lekcji z importu. Zwykłe `textarea` nie podświetli składni i nie podpowie hasła.
- **Podgląd z serwera, nie z biblioteki w przeglądarce.** `markdown-it` albo `marked` w kliencie renderują inaczej niż Markdig: inne rozszerzenia, brak `[[hasło]]`, inny sanitizer. `POST /api/learning/preview` z [19](../../api/19-learning.md) zwraca HTML z tego samego potoku co publikacja i listę brakujących haseł. Koszt to jedno żądanie po przerwie w pisaniu.
- **React 19: `useOptimistic` i `useActionState`.** Zmiana widoczności i publikacja pokazują wynik od razu i wracają same, gdy żądanie się nie uda. Formularz CV dostaje stan wysyłki i błąd bez własnego `useState` na każdą flagę.
- **`diff` (jsdiff).** Konflikt `412` i historia notatki pokazują różnicę wierszy i słów. Biblioteka ma licencję BSD-3-Clause i działa bez DOM-u.
- **`@dnd-kit/sortable`.** Kolejność lekcji przeciąga się myszą, palcem albo klawiaturą (spacja, strzałki, spacja), z komunikatami dla czytnika ekranu. Natywne HTML5 drag and drop nie ma obsługi klawiatury ani dotyku.

## Wersje i pakiety

Wersje przypina lockfile. Wszystkie pakiety trafiają do chunku intranetu ([01-dostep-i-trasy.md](01-dostep-i-trasy.md)).

| Pakiet | Licencja | Rola |
| --- | --- | --- |
| `@codemirror/state`, `@codemirror/view`, `@codemirror/commands` | MIT | rdzeń edytora, historia, skróty |
| `@codemirror/language`, `@codemirror/lang-markdown`, `@codemirror/language-data` | MIT | Markdown i bloki kodu z językiem ładowanym na żądanie |
| `@codemirror/autocomplete`, `@codemirror/search` | MIT | podpowiedź `[[hasło]]`, szukaj i zamień |
| `@lezer/highlight` | MIT | style tokenów z tokenów motywu |
| `@dnd-kit/core`, `@dnd-kit/sortable`, `@dnd-kit/utilities` | MIT | kolejność lekcji i wpisów CV |
| `diff` | BSD-3-Clause | różnica przy konflikcie i w historii |

```bash
cd src/Clients/web
pnpm add @codemirror/state @codemirror/view @codemirror/commands @codemirror/language \
  @codemirror/lang-markdown @codemirror/language-data @codemirror/autocomplete @codemirror/search \
  @lezer/highlight @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities diff
```

Opakowania typu `@uiw/react-codemirror` nie są potrzebne. Hook poniżej ma kilkadziesiąt wierszy i daje pełną kontrolę nad cyklem życia widoku.

## Ścieżki w repo

Względem `src/Clients/web/src/app/pages/intranet/`:

| Ścieżka | Rola |
| --- | --- |
| `editor/useCodeMirror.ts` | tworzy i niszczy `EditorView`, przekazuje zmiany |
| `editor/MarkdownEditor.tsx` | pole edytora z etykietą i licznikiem rozmiaru |
| `editor/editor-theme.ts` | motyw i podświetlanie ze zmiennych CSS tokenów |
| `editor/term-completion.ts` | podpowiedź po `[[` z listy haseł |
| `editor/usePreview.ts`, `MarkdownPreview.tsx` | podgląd z `POST /api/learning/preview` |
| `editor/LocalizedEditor.tsx` | zakładki `PL` i `EN` nad dwoma edytorami |
| `editor/useDraft.ts`, `DraftBanner.tsx` | szkic w `localStorage` i baner przywrócenia |
| `editor/ConflictDialog.tsx`, `DiffView.tsx` | `412` i różnica wersji |
| `shared/useVisibility.ts` | zmiana widoczności z `useOptimistic` |
| `tracks/LessonEditPage.tsx`, `LessonOrder.tsx`, `ImportDialog.tsx`, `ImportReportTable.tsx` | lekcje i import |
| `notes/NoteEditPage.tsx`, `PublishDialog.tsx`, `LessonAttachSelect.tsx`, `HistoryPanel.tsx` | notatki |
| `cv/CvEditPage.tsx`, `cv-reducer.ts`, `EntryList.tsx`, `EvidencePicker.tsx` | CV |

## Tutorial

### 1. Hook edytora

```ts
import { defaultKeymap, history, historyKeymap } from '@codemirror/commands';
import { markdown } from '@codemirror/lang-markdown';
import { languages } from '@codemirror/language-data';
import { autocompletion } from '@codemirror/autocomplete';
import { searchKeymap } from '@codemirror/search';
import { EditorState } from '@codemirror/state';
import { EditorView, keymap } from '@codemirror/view';
import { useEffect, useRef } from 'react';

import { editorTheme } from './editor-theme';
import { termCompletion, type TermOption } from './term-completion';

type Options = {
  value: string;
  label: string;
  lang: 'pl' | 'en';
  readOnly: boolean;
  terms: readonly TermOption[];
  onChange: (value: string) => void;
  onSave: () => void;
};

export function useCodeMirror(options: Options) {
  const parent = useRef<HTMLDivElement>(null);
  const view = useRef<EditorView | null>(null);
  const latest = useRef(options);
  latest.current = options;

  useEffect(() => {
    const instance = new EditorView({
      parent: parent.current!,
      state: EditorState.create({
        doc: latest.current.value,
        extensions: [
          history(),
          markdown({ codeLanguages: languages }),
          autocompletion({ override: [termCompletion(() => latest.current.terms)] }),
          keymap.of([
            { key: 'Mod-s', preventDefault: true, run: () => (latest.current.onSave(), true) },
            ...defaultKeymap,
            ...historyKeymap,
            ...searchKeymap,
          ]),
          EditorView.lineWrapping,
          EditorState.readOnly.of(latest.current.readOnly),
          EditorView.contentAttributes.of({
            'aria-label': latest.current.label,
            lang: latest.current.lang,
            spellcheck: 'true',
          }),
          EditorView.updateListener.of((update) => {
            if (update.docChanged) {
              latest.current.onChange(update.state.doc.toString());
            }
          }),
          editorTheme,
        ],
      }),
    });
    view.current = instance;
    return () => instance.destroy();
  }, [options.readOnly, options.lang]);

  useEffect(() => {
    const instance = view.current;
    if (instance && instance.state.doc.toString() !== options.value) {
      instance.dispatch({ changes: { from: 0, to: instance.state.doc.length, insert: options.value } });
    }
  }, [options.value]);

  return parent;
}
```

Edytor jest źródłem tekstu, a rodzic trzyma kopię w stanie do zapisu. Drugi efekt podmienia dokument tylko wtedy, gdy wartość przyszła z zewnątrz (wczytanie wersji z serwera, przywrócenie szkicu). Zwykłe pisanie nie przechodzi przez ten efekt, bo `onChange` ustawia tę samą wartość, którą edytor już ma.

`lang` w atrybutach treści sprawia, że sprawdzanie pisowni przeglądarki używa słownika języka zakładki.

### 2. Motyw z tokenów

```ts
import { HighlightStyle, syntaxHighlighting } from '@codemirror/language';
import { EditorView } from '@codemirror/view';
import { tags } from '@lezer/highlight';

const base = EditorView.theme({
  '&': { color: 'var(--color-ink)', backgroundColor: 'var(--color-canvas)', fontSize: 'var(--text-small)' },
  '.cm-content': { fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', caretColor: 'var(--color-accent)' },
  '&.cm-focused': { outline: '2px solid var(--color-accent)' },
  '.cm-selectionBackground, &.cm-focused .cm-selectionBackground': {
    backgroundColor: 'color-mix(in oklab, var(--color-accent) 20%, transparent)',
  },
});

const highlight = HighlightStyle.define([
  { tag: tags.heading, fontWeight: '600', color: 'var(--color-ink)' },
  { tag: [tags.link, tags.url], color: 'var(--color-accent)' },
  { tag: tags.monospace, color: 'var(--color-muted)' },
  { tag: tags.emphasis, fontStyle: 'italic' },
  { tag: tags.strong, fontWeight: '600' },
]);

export const editorTheme = [base, syntaxHighlighting(highlight)];
```

Nazwy zmiennych to te, które [tailwind/02-motyw.md](../tailwind/02-motyw.md) wystawia z `tokens.ts`. Zaznaczenie to akcent z alfą, jak modyfikator `bg-accent/20` w klasach, a nie nowy kolor. Tokeny mają jeden krój (Inter), więc kod w edytorze dostaje systemowy krój o stałej szerokości. Tryb ciemny podmienia zmienne, więc edytor zmienia kolory bez drugiego motywu CodeMirror. CodeMirror wstawia swoje style jako element `<style>`, stąd `style-src 'unsafe-inline'` w CSP z [react/05-tresc-z-api.md](../react/05-tresc-z-api.md).

### 3. Podpowiedź hasła

```ts
import type { CompletionContext, CompletionResult } from '@codemirror/autocomplete';

export type TermOption = { slug: string; title: string };

export function termCompletion(terms: () => readonly TermOption[]) {
  return (context: CompletionContext): CompletionResult | null => {
    const match = context.matchBefore(/\[\[[a-z0-9-]*$/);
    if (!match) {
      return null;
    }
    return {
      from: match.from + 2,
      options: terms().map((term) => ({ label: term.slug, detail: term.title, apply: `${term.slug}]]` })),
      validFor: /^[a-z0-9-]*$/,
    };
  };
}
```

Lista haseł pochodzi z `GET /api/learning/terms` (klucz `['learning', 'terms', 'pl']`), już w cache po wejściu na listę haseł. Owner widzi także hasła prywatne.

### 4. Podgląd

`usePreview(markdown)`:

- czeka 400 ms od ostatniej zmiany (`useDebouncedValue`), potem `useQuery` z kluczem `['learning', 'preview', debounced]`, `gcTime: 30_000` i `placeholderData: keepPreviousData`,
- `queryFn` woła `learningApi.POST('/api/learning/preview', { body: { markdown }, signal })`; nowe zapytanie anuluje poprzednie przez `signal`,
- tekst powyżej 200 KB nie idzie na serwer. Licznik pod edytorem dostaje rysunek błędu pola z [tailwind/05-stany.md](../tailwind/05-stany.md), a podgląd pokazuje „Za długi tekst” zamiast HTML.

`MarkdownPreview` rysuje `html` przez `ServerHtml` z `missing: missingTermSlugs`. Pod podglądem lista brakujących haseł z linkiem „Utwórz” do `/intranet/terms/new?slug={slug}`: formularz hasła bierze slug z adresu.

Układ od szerokości `lg`: edytor i podgląd obok siebie, w dwóch kolumnach z [tailwind/03-uklad.md](../tailwind/03-uklad.md). Węższy ekran: zakładki „Edycja” i „Podgląd”.

Notatki używają tego samego podglądu. [21-notatki.md](../../api/21-notatki.md) przenosi renderer do `JJDevHub.Markdown`, więc HTML z `POST /api/learning/preview` i HTML opublikowanej notatki są identyczne.

### 5. Zapis z If-Match

Ekran edycji wczytuje dokument z `GET /api/learning/{kind}/{id}` ([19](../../api/19-learning.md)), `GET /api/articles/{id}` ([21](../../api/21-notatki.md)) albo `GET /api/cv` ([22](../../api/22-cv.md)). `ETag` z odpowiedzi trafia do stanu ekranu razem z treścią, z której edycja startuje (`base`).

```ts
const save = useMutation({
  mutationFn: async (draft: LessonDraft) => {
    const { data, error, response } = await learningApi.PUT('/api/learning/tracks/{id}/lessons/{lessonId}', {
      params: { path: { id: trackId, lessonId } },
      headers: { 'If-Match': etag },
      body: draft,
    });
    if (error) {
      throw new ApiError(response.status, error);
    }
    return { written: data, etag: response.headers.get('ETag')! };
  },
  onSuccess: ({ etag: next }, sent) => {
    setEtag(next);
    setBase(sent);
    draft.clear();
    toast.success(copy.saved);
    queryClient.invalidateQueries({ queryKey: ['learning'] });
  },
});
```

`Mod-S` w edytorze i przycisk „Zapisz” wołają tę samą mutację. Odpowiedź `ContentWritten(Id, Slug, Revision)` niesie nowy slug, więc link „Zobacz na stronie” od razu prowadzi pod właściwy adres. `428` nie występuje, bo klient zawsze wysyła `If-Match`; test pilnuje, żeby tak zostało.

Lekcje są częścią agregatu `Track`, więc `If-Match` lekcji to `Revision` kursu. Zapis innej lekcji tego samego kursu w drugiej karcie też daje `412`, opisane w następnym kroku.

### 6. Konflikt 412

`ConflictDialog` pobiera bieżący dokument z serwera i porównuje trzy wersje: `base` (od czego zaczęła się edycja), `server` (co jest teraz) i `local` (co jest w edytorze).

| Sytuacja | Zachowanie |
| --- | --- |
| treść tej lekcji na serwerze równa `base` | konflikt dotyczy innej części kursu; klient ponawia zapis z nowym `ETag` bez pytania |
| treść na serwerze inna niż `base` | dialog z `DiffView` (`diffWordsWithSpace` z `diff`) między `server` a `local` |

Dialog ma trzy przyciski:

- „Weź wersję z serwera” — edytor dostaje `server`, `local` trafia do szkicu, więc da się go odzyskać z banera,
- „Zapisz moją wersję” — `PUT` z nowym `ETag`, świadome nadpisanie,
- „Anuluj” — edytor zostaje z `local`, nic nie idzie na serwer.

Ten sam dialog obsługuje CV, z różnicą sformatowanego JSON-a (`JSON.stringify(doc, null, 2)` i `diffLines`).

### 7. Szkic w przeglądarce

`useDraft(key, value, etag)` zapisuje `{ value, etag, savedAt }` w `localStorage` pod `jjdevhub.draft.{kind}.{id}` dwie sekundy po ostatniej zmianie. Zapis udany czyści klucz.

Po wejściu na edycję `DraftBanner` sprawdza szkic:

- `etag` szkicu równy bieżącemu i treść inna → „Masz niezapisany szkic z 14:32” z przyciskami „Przywróć” i „Odrzuć”,
- `etag` inny → ten sam baner z dopiskiem „Treść zmieniła się od tego czasu” i przyciskiem „Pokaż różnicę”, który otwiera `DiffView`.

Zamknięcie karty przy niezapisanej zmianie pokazuje pytanie przeglądarki (`beforeunload`). Nawigacja wewnątrz aplikacji nie pyta, bo `useBlocker` React Routera działa tylko w trybie danych (`createBrowserRouter`), a klient używa `BrowserRouter`. Szkic w `localStorage` chroni treść w obu przypadkach.

### 8. Widoczność z useOptimistic

```ts
export function useVisibility(kind: ContentKind, id: string, visibility: Visibility, etag: string) {
  const [optimistic, setOptimistic] = useOptimistic(visibility);
  const [isPending, startTransition] = useTransition();
  const mutation = useChangeVisibility(kind, id);

  function change(next: Visibility) {
    startTransition(async () => {
      setOptimistic(next);
      try {
        await mutation.mutateAsync({ visibility: next, etag });
      } catch (error) {
        toast.error(describeApiError(error));
      }
    });
  }

  return { visibility: optimistic, isPending, change };
}
```

`setOptimistic` pokazuje nową plakietkę od razu. Gdy przejście się skończy, React wraca do wartości `visibility` z propsów: po sukcesie to nowa wartość z odświeżonego zapytania, po błędzie stara. Osobnego kodu cofania nie ma.

Ten sam hook obsługuje listę z [01-dostep-i-trasy.md](01-dostep-i-trasy.md) i ekran edycji. Lekcja `Public` w kursie `Students` ma widoczność efektywną `Students` ([19](../../api/19-learning.md)): plakietka lekcji pokazuje obie wartości, np. „Publiczna, w kursie dla studentów”.

### 9. Kolejność lekcji

`LessonOrder` na stronie kursu:

- `DndContext` z `PointerSensor` i `KeyboardSensor` (`sortableKeyboardCoordinates`), `SortableContext` z `verticalListSortingStrategy`,
- komunikaty `accessibility.announcements` po polsku („Podniesiono lekcję Outbox, pozycja 3 z 7”),
- `onDragEnd` → `arrayMove`, nowa kolejność od razu w cache (`setQueryData`), potem `PUT /api/learning/tracks/{id}/lessons/order` z listą id i `If-Match` kursu,
- `412` albo `400` (lista nie jest permutacją, bo w międzyczasie doszła lekcja) → unieważnienie klucza kursu i komunikat.

Ruch wyłącza się przy `prefers-reduced-motion`: `DragOverlay` bez animacji `dropAnimation`.

### 10. Przykłady w lekcji

`LessonEditPage` ma edytor Markdown wyjaśnienia i listę przykładów pod nim.

- każdy przykład: `select` języka z listy w [19](../../api/19-learning.md) (`tsx` dla komponentu React, `csharp`, `sql` i reszta), pole źródła i opcjonalny podpis,
- kolejność przykładów to kolejność na stronie; strzałki w górę i w dół, ten sam układ co przy lekcjach kursu,
- zapis lekcji to jeden `PUT` z wyjaśnieniem i całą listą przykładów oraz `If-Match` lekcji. `ETag` kursu się od tego nie zmienia,
- nowa lekcja to `POST /api/learning/lessons` z `If-Match` kursu.

Podgląd Markdown dotyczy wyjaśnienia. Źródło przykładu w podglądzie jest kodem, nie HTML-em z serwera.

### 11. Notatka: publikacja, lekcja i historia

`NoteEditPage` ma tytuł, slug (liczony z tytułu, dopóki owner go nie zmieni), język (wybierany przy tworzeniu, potem tylko do odczytu), edytor i podgląd.

- `LessonAttachSelect`: technologia → kurs → lekcja albo wykład; wybór → `PUT /api/articles/{id}/lesson` z `{ kind, parentSlug, lessonSlug }` i `If-Match`. „Odłącz” → `DELETE …/lesson`.
- `PublishDialog`: widoczność `Studenci` albo `Publiczna` → `POST /api/articles/{id}/publish`. Opublikowana notatka ma przycisk „Wycofaj” → `POST …/withdraw`. Status i widoczność idą przez `useOptimistic` jak w kroku 8.
- `HistoryPanel`: `GET /api/articles/{id}/history` z [21](../../api/21-notatki.md). Lista rewizji (rodzaj, data, tytuł). Zaznaczenie dwóch rewizji pokazuje `DiffView` ich treści. To widok strumienia zdarzeń: każda rewizja, także sprzed wprowadzenia historii, jest w magazynie zdarzeń News.

### 12. CV i dowody

`CvEditPage` wczytuje `GET /api/cv` z `ETag` i trzyma dokument w `useReducer(cvReducer, document)`. Akcje reduktora: zmiana pola profilu, dodanie, usunięcie i przesunięcie wpisu w sekcji, zmiana umiejętności, przełączenie dowodu.

- Profil i opisy mają pola `PL` i `EN` z `LocalizedFields`.
- Doświadczenie, edukacja i aktywności to `EntryList`: wpisy sortowane `@dnd-kit/sortable`, okres jako dwa pola `type="month"` (koniec pusty = „obecnie”), punkty jako `textarea` na język.
- Umiejętność wybiera technologię z `GET /api/learning/technologies`. Pod nią `EvidencePicker` czyta `GET /api/cv/evidence?technology={slug}`: lista dowodów (kurs, lekcje, notatki, wykłady) z polem wyboru. Odznaczenie dopisuje klucz dowodu do `hiddenEvidence`, zaznaczenie go usuwa.

Zapis to formularz z akcją:

```tsx
const [state, saveAction, isPending] = useActionState(async () => {
  const result = await saveCv(document, etag);
  if (result.kind === 'conflict') {
    openConflict(result.server);
    return { error: null };
  }
  if (result.kind === 'invalid') {
    return { error: result.problem };
  }
  setEtag(result.etag);
  toast.success(copy.cvSaved);
  return { error: null };
}, { error: null });

return <form action={saveAction}>…</form>;
```

`isPending` wyłącza przycisk „Zapisz”, a `state.error` rozkłada `errors` z `ProblemDetails` przy polach. Po zapisie komunikat mówi „PDF odświeży się w ciągu kilku sekund”, bo render w [22](../../api/22-cv.md) czeka 2 s ciszy. Linki „Podgląd” (`/pl/cv` w nowej karcie) i „PDF” są nad formularzem.

## Przypadki użycia

### Nowa lekcja z brakującym hasłem

Owner pisze `Zobacz [[saga]]`. Po 400 ms podgląd pokazuje „saga” jako tekst bez linku, a pod podglądem „Brakuje: saga — Utwórz”. Klik otwiera formularz hasła ze slugiem `saga`. Po zapisaniu hasła i powrocie podgląd odświeża się i „saga” jest linkiem.

### Dwie karty, ta sama lekcja

Karta A zapisuje lekcję. Karta B, otwarta wcześniej, zapisuje swoją wersję i dostaje `412`. Treść na serwerze różni się od `base` karty B, więc dialog pokazuje różnicę. Owner wybiera „Weź wersję z serwera”, a jego tekst zostaje w szkicu.

### Dwie karty, różne lekcje kursu

Karta A zapisuje lekcję 2, karta B lekcję 5. Karta B dostaje `412`, ale lekcja 5 na serwerze jest równa `base`. Klient ponawia zapis z nowym `ETag` i pokazuje zwykłe „Zapisano”.

### Zamknięta karta

Owner pisze, zamyka kartę, odpowiada „Opuść” na pytanie przeglądarki. Po powrocie baner proponuje przywrócenie szkicu sprzed dwóch sekund od ostatniej zmiany.

### Ukrycie dowodu w CV

Owner odznacza notatkę „Pierwsze kroki z Expo” przy React Native i zapisuje. `GET /api/cv/pl` po chwili nie ma tej notatki przy umiejętności, a PDF po kilku sekundach też jej nie ma.

## Testy

CodeMirror w jsdom działa bez układu strony (brak `getClientRects` daje ostrzeżenia, nie błędy). Test nie pisze w edytorze klawiaturą: bierze widok przez `EditorView.findFromDOM(element)` i woła `dispatch`. Reszta przez Testing Library jak w [react/04-testy.md](../react/04-testy.md).

| Plik | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `term-completion.spec.ts` | hasła `cqrs`, `outbox` | kontekst z tekstem `Zobacz [[ou` | jedna opcja `outbox`, `apply` `outbox]]` |
| `LessonEditPage.spec.tsx` | stub dokumentu i podglądu | `dispatch` z tekstem, zegar +400 ms | jedno żądanie podglądu, HTML w podglądzie |
| `LessonEditPage.spec.tsx` | stub `PUT` | `Mod-S` | żądanie ma nagłówek `If-Match` z `ETag` dokumentu |
| `ConflictDialog.spec.tsx` | `PUT` → `412`, serwer = `base` | zapis | drugi `PUT` z nowym `ETag`, brak dialogu |
| `ConflictDialog.spec.tsx` | `PUT` → `412`, serwer ≠ `base` | zapis | dialog z różnicą; „Weź wersję z serwera” ustawia treść serwera, szkic zawiera lokalną |
| `useDraft.spec.ts` | zmiana treści | zegar +2 s | wpis `jjdevhub.draft.lesson.{id}` w `localStorage` |
| `DraftBanner.spec.tsx` | szkic z innym `etag` | render | baner z „Treść zmieniła się od tego czasu” |
| `useVisibility.spec.tsx` | stub `500` | zmiana na `Students` | plakietka `Studenci`, potem z powrotem `Prywatne`, komunikat błędu |
| `LessonOrder.spec.tsx` | trzy lekcje | spacja, strzałka w dół, spacja na pierwszej | `PUT …/order` z id w nowej kolejności |
| `ImportDialog.spec.tsx` | stub `503` z `Retry-After: 42` | wysłanie | przycisk wyłączony, tekst z `42` |
| `ImportDialog.spec.tsx` | repozytorium `nie poprawne` | wysłanie | błąd przy polu, brak żądania |
| `CvEditPage.spec.tsx` | stub dowodów dla `react-native` | odznaczenie notatki i zapis | ciało `PUT /api/cv` ma klucz notatki w `hiddenEvidence` |
| `HistoryPanel.spec.tsx` | dwie rewizje | zaznaczenie obu | `DiffView` z dodanym słowem |

## Zasady

- Treść wyjaśnienia pisze się w Markdown. HTML pochodzi z serwera, także w podglądzie. Przykład kodu zapisuje się jako źródło i język.
- Zapis zawsze z `If-Match`. Nadpisanie wersji z serwera wymaga kliknięcia „Zapisz moją wersję”.
- Szkic w `localStorage` zawiera tylko treść i `ETag`. Tokenu, kodów zaproszeń i danych z CV poza treścią formularza tam nie ma.
- Kolory edytora ze zmiennych tokenów, bez drugiej palety.
- Każda operacja przeciągania ma odpowiednik z klawiatury.

## Poza zakresem

- Wspólna edycja w czasie rzeczywistym (Yjs, CRDT). Jeden owner, a konflikty łapie `If-Match`.
- WYSIWYG i edycja w podglądzie.
- Wgrywanie obrazów. Obraz w wyjaśnieniu linkuje absolutnym adresem `https`.
- Synchronizacja przewijania edytora i podglądu.
- Edycja `cv.local.json`. Plik służy tylko do jednorazowego importu z [01-dostep-i-trasy.md](01-dostep-i-trasy.md).

## Źródła

- [CodeMirror: System Guide](https://codemirror.net/docs/guide/) i [Autocompletion](https://codemirror.net/examples/autocompletion/) — widok, stan, rozszerzenia, źródło podpowiedzi.
- [CodeMirror: Styling](https://codemirror.net/examples/styling/) — `EditorView.theme` i `HighlightStyle`.
- [React: useOptimistic](https://react.dev/reference/react/useOptimistic) i [useActionState](https://react.dev/reference/react/useActionState).
- [dnd-kit: Sortable](https://docs.dndkit.com/presets/sortable) i [Accessibility](https://docs.dndkit.com/guides/accessibility).
- [jsdiff](https://github.com/kpdecker/jsdiff) — `diffWordsWithSpace`, `diffLines`.
- [HTTP conditional requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Conditional_requests) — `If-Match`, `412`, lost update.
- [React Router: useBlocker](https://reactrouter.com/api/hooks/useBlocker) — dostępny w trybie danych.

## Gotowe gdy

- Lekcja, hasło, wykład, technologia i notatka mają edytor z podglądem z serwera, a `[[` podpowiada hasła.
- Zapis z nieaktualnym `ETag` otwiera dialog różnicy albo ponawia się sam, gdy zmieniła się inna część kursu.
- Zamknięcie karty bez zapisu zostawia szkic, który da się przywrócić.
- Kolejność lekcji da się zmienić myszą i klawiaturą, a API dostaje pełną listę id.
- Import pokazuje raport, a nowe lekcje są prywatne.
- Historia notatki pokazuje różnicę dwóch rewizji.
- CV zapisuje się z `If-Match`, a odznaczony dowód znika ze strony i z PDF-a.
- Chunk wejścia strony publicznej nie zawiera CodeMirror (`scripts/check-chunks.mjs`).
- `pnpm test:ci` i `pnpm build` kończą się kodem 0.
