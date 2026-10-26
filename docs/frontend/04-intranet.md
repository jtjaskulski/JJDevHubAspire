# Intranet

Ten numer otwiera trasy właściciela w tym samym kliencie web: edytor CV, edytor notatek, edytor kursów i dwie skrzynki Contact. Trasy są leniwe. Zapis, który przeczytał `ETag`, wysyła `If-Match`. Wygląd biorą komponenty z [03-wyglad.md](03-wyglad.md). Odczyt i mutacja idą klientem z [05-tresc.md](05-tresc.md). Adresy są poza prefiksem języka, jak ustalił [02-web.md](02-web.md).

Poprzedni numer to [03-wyglad.md](03-wyglad.md). Następny to [05-tresc.md](05-tresc.md).

Rola w tokenie JWT to `owner`. Brak roli nie kończy się „prawie intranetem” z zablokowanymi przyciskami. Kończy się innym adresem.

## Po co

Treść CV, notatki i kursu zmienia właściciel, bez nowego wydania webu. Endpointy zapisu są w usługach i wymagają roli `owner`. Bez ekranu zostaje ręczne żądanie i ręcznie przepisany `If-Match`. Intranet jest formularzem nad tymi endpointami. Reguła widoczności, walidacja i konflikt wersji zostają w API.

Są dwa rodzaje zapytań: `StudentInquiry` i `RecruiterInquiry`. Dwie skrzynki pokazują je osobno, z osobnym nagłówkiem z chromu. Jedna tabela z filtrem „typ” gubi różnicę, którą telefon później otwiera z dwóch kanałów.

Osobna aplikacja intranetu dałaby drugi bundle i drugi login. Leniwy chunk daje gościowi ten sam skutek przy pobieraniu: kod edytora schodzi dopiero po wejściu właściciela.

## Dlaczego ta technologia

### Leniwy chunk w tym samym kliencie

`/intranet/*` ładuje się przez `React.lazy`. Vite składa ten graf w osobne pliki. `Suspense` pokazuje stan ładowania, zanim chunk dojdzie. Eksport stron zostaje nazwany; adapter przy `lazy` bierze nazwany eksport i podaje go jako `default`, którego wymaga `lazy`.

Drugi projekt Vite tylko dla właściciela przegrywa, bo dubluje shell, auth i komponenty z `components/ui`. Trzymanie edytora w głównym bundle przegrywa, bo gość pobiera kod, którego nie otworzy. iframe z innym originem przegrywa, bo cookie i token rozchodzą się na dwa dokumenty.

Koszt: pierwszy raz na `/intranet` jest krótsza pauza na sieć. Stan ładowania jest widoczny i ma tekst, nie pusty `main`. Błąd chunka pokazuje `error.load` i nie zostawia białej strony.

Przełącznik języka na tych adresach nie zmienia ścieżki. To reguła z numeru `02`. Chrom intranetu i tak jest w `pl` i `en`, bo klucze są wspólne. Zakładki treści `pl` i `en` są czym innym: to mapa kultur w dokumencie, nie język belki.

### Strażnik roli

`OwnerRoute` czyta wynik `useMe`. Gość idzie na `/login?next=` z bieżącą ścieżką, po `encodeURIComponent`. Zalogowany bez `owner` idzie na `/pl`. W trakcie odczytu widać stan ładowania, nie błysk pulpitu.

Strażnik jest wygodą nawigacji. Zapis i tak odrzuca usługa, gdy roli nie ma. Polityka roli jest w [17-identity.md](../api/17-identity.md). Ukrycie przycisku w publicznym repozytorium nie jest zabezpieczeniem: dokumenty OpenAPI i tak opisują endpoint.

Sprawdzenie roli tylko w kliencie, bez polityki API, przegrywa, bo żądanie da się wysłać poza ekranem. Osobny login dla właściciela przegrywa, bo konto i role są jedną usługą Identity. Hasło wpisane drugi raz na `/intranet` przegrywa, bo drugiego logowania tu nie ma: jest jedno, na `/login`.

Koszt: każde wejście na intranet czeka na `useMe`. To jedno żądanie, współdzielone przez cache z numeru `05`. Przy `401` klient wylogowuje, a strażnik widzi gościa i prowadzi na login.

`safeNext` z numeru `02` ogranicza powrót. Cel po udanym logowaniu, który ma wrócić do intranetu, zaczyna się od `/intranet`, nie od `//`. Inna wartość daje `/pl`.

Link `nav.intranet` w belce widać tylko wtedy, gdy `useMe` ma rolę `owner`. Gość i student tego linku nie dostają. Adres i tak jest strzeżony, gdy ktoś wpisze go ręcznie.

### Zapis z If-Match

Odczyt edytora bierze nagłówek `ETag`. Zapis wysyła ten sam znacznik w `If-Match`. Brak nagłówka po stronie API to `428`. Nieaktualny znacznik to `412`. Treść niewidoczna to `404`. Kody są w [11-walidacja.md](../api/11-walidacja.md).

Klient, który zapisuje bez `If-Match`, przegrałby cichym nadpisaniem albo dostał `428` i wyglądał jak awaria sieci. Optymistyczny zapis „ostatni wygrywa” przegrywa, bo dwie karty właściciela gubią akapit. Blokada dokumentu na czas edycji przegrywa, bo właściciel jest jeden, a i tak edytuje z telefonu i z przeglądarki; zamek zostałby na zerwanym połączeniu.

Koszt: przy `412` autor widzi konflikt i nie dostaje cichego ponowienia. Ekran pokazuje `editor.conflict` i `editor.reload`. Wczytanie bierze świeży `ETag` i świeżą treść. Własny szkic zostaje w stanie lokalnym, dopóki autor sam nie zastąpi go wersją z serwera. Drugi zapis sam z siebie nie idzie.

Nowy dokument, który jeszcze nie ma `ETag`, idzie jako utworzenie (`POST`) bez `If-Match`. Pierwszy zapis istniejącego dokumentu już go ma. Usunięcie, jeśli endpoint je ma i zwraca wersję, też wysyła `If-Match`.

`428` w teście klienta oznacza błąd programu: mutacja istniejącego dokumentu wyszła bez nagłówka. Ekran pokazuje `error.load`, a test mutacji pada, gdy nagłówka nie ma.

### Dwie skrzynki

`StudentInboxPage` czyta listę zapytań studentów. `RecruiterInboxPage` czyta listę zapytań rekruterów. Nagłówki to `inbox.students.title` i `inbox.recruiters.title`. Pusta lista to `inbox.empty`.

Jedna strona z przełącznikiem filtrującym po typie przegrywa, bo telefon otwiera konkretną skrzynkę z konkretnego kanału. Adres ma być inny, żeby powiadomienie miało dokąd wejść także w przeglądarce, gdy właściciel kliknie ten sam podział. Wspólny komponent wiersza jest dozwolony. Wspólna trasa nie.

Koszt: dwa odczyty, dwa stany pustki, dwa wpisy w nawigacji intranetu. Zapis odpowiedzi, jeśli dojdzie, niesie `If-Match` tej jednej pozycji, nie całej listy.

Skrzynka nie tworzy zapytania. Zapytanie rekrutera powstaje na stronie publicznej, zapytanie studenta w strefie studenta. Oba opisy są w [05-tresc.md](05-tresc.md).

### Edytory trzech treści

CV, notatka i kurs mają osobne strony. CV jest zestawem pól: profil, stanowisko, projekt, edukacja, aktywność, umiejętność, język. Umiejętność wskazuje technologię slugiem, nie identyfikatorem z bazy Learning. Notatka i lekcja mają treść w dwóch kulturach, `pl` i `en`, na zakładkach. Pole treści jest `textarea`. Podgląd bierze HTML z bramy, z tej samej ścieżki, którą usługa składa przy publikacji, i wstawia go przez `TrustedHtml`.

Edytor WYSIWYG, który trzyma własny model dokumentu, przegrywa, bo przy zapisie zamienia go z powrotem na Markdown i gubi kształt, który trzyma API. Drugi renderer Markdown w przeglądarce przegrywa, bo rozjedzie się z sanitacją usługi. Ciężki edytor kodu w głównym bundle przegrywa wagą; w tym numerze pole tekstowe wystarcza, a podgląd i tak jest odpowiedzią API.

Koszt: podczas pisania widać surowy tekst, a sformatowany wynik po odpowiedzi podglądu. Podgląd nie idzie przy każdym klawiszu. Idzie po przerwie w pisaniu, jednym żądaniem, które da się anulować przy następnym. Błąd podglądu pokazuje `error.load` obok pola i nie kasuje tekstu autora.

Widoczność notatki i kursu jest plakietką z klucza `visibility.public`, `visibility.students` albo `visibility.private`. Kolor plakietki bierze się z klas numeru `03`: akcent, atrament, `muted`. Czwartej widoczności klient nie wymyśla.

Kolejność lekcji w kursie jest zapisem z `If-Match` na dokumencie kursu. Przeciąganie, jeśli dojdzie, kończy się tą samą mutacją co zmiana numeru w polu. Ten numer wymaga zapisu kolejności. Nie wymaga konkretnej biblioteki gestu.

## Klasy i ścieżki

Względem `src/clients/web/src`:

| Plik | Odpowiedzialność |
| --- | --- |
| `app/OwnerRoute.tsx` | gość na login z `next`, rola inna niż `owner` na `/pl` |
| `pages/intranet/IntranetRoutes.tsx` | drzewo leniwe |
| `pages/intranet/IntranetLayout.tsx` | nawigacja czterech obszarów i `Outlet` |
| `pages/intranet/DashboardPage.tsx` | `/intranet` |
| `pages/intranet/cv/CvEditorPage.tsx` | edytor CV |
| `pages/intranet/news/NewsListPage.tsx` | lista notatek |
| `pages/intranet/news/NewsEditorPage.tsx` | jedna notatka, zakładki kultur, podgląd |
| `pages/intranet/courses/CourseListPage.tsx` | lista kursów |
| `pages/intranet/courses/CourseEditorPage.tsx` | kurs i kolejność lekcji |
| `pages/intranet/courses/LessonEditorPage.tsx` | lekcja |
| `pages/intranet/contact/StudentInboxPage.tsx` | skrzynka studentów |
| `pages/intranet/contact/RecruiterInboxPage.tsx` | skrzynka rekruterów |
| `pages/intranet/editor/ConflictDialog.tsx` | `412`, klucze `editor.conflict` i `editor.reload` |
| `pages/intranet/editor/LocaleTabs.tsx` | zakładki `pl` i `en` treści |
| `pages/intranet/editor/usePreview.ts` | podgląd HTML z bramy, anulowanie |
| `pages/intranet/editor/useSaveWithMatch.ts` | dokleja `If-Match` do zapisu istniejącego dokumentu |

Drzewo:

```text
/intranet                         IntranetLayout
  index                           DashboardPage
  cv                              CvEditorPage
  news                            NewsListPage
  news/:id                        NewsEditorPage
  courses                         CourseListPage
  courses/:id                     CourseEditorPage
  courses/:id/lessons/:lessonId   LessonEditorPage
  contact/students                StudentInboxPage
  contact/recruiters              RecruiterInboxPage
```

Identyfikator w adresie intranetu jest identyfikatorem dokumentu, nie slugiem publicznym. Slug może zmienić się przy edycji tytułu. Adres karty właściciela ma przeżyć tę zmianę. Publiczny adres i tak jest slugiem, zgodnie z mapą.

## Plan

### 1. Wejście leniwe

W `App` ścieżka `/intranet/*` renderuje `OwnerRoute`, w nim `Suspense`, w nim leniwe `IntranetRoutes`. Adapter `lazy` mapuje nazwany eksport. Fallback to widoczny stan ładowania, nie `null`.

`OwnerRoute` zaimplementuj według sekcji strażnika. `useMe` pochodzi z klienta numeru `05`. Gdy ten numer wdrażasz razem z już istniejącym hookiem, nie pisz drugiego `fetch` w strażniku.

### 2. Nawigacja

`IntranetLayout` ma cztery wejścia: CV, notatki, kursy, kontakt. Kontakt prowadzi do dwóch linków, studentów i rekruterów. Bieżący adres jest oznaczony na linku, `aria-current="page"`. `DashboardPage` powtarza te wejścia.

Link `nav.intranet` w shellu publicznym włącz tylko dla roli `owner`.

### 3. Edytor z wersją

`useSaveWithMatch` przyjmuje mutację i `etag`. Dla istniejącego dokumentu ustawia nagłówek `If-Match` na ten `etag`. Bez `etag` nie wysyła zapisu aktualizacji i wystawia błąd, który test widzi. Utworzenie dokumentu idzie osobną mutacją, bez tego nagłówka.

Przy odpowiedzi `412` otwórz `ConflictDialog`. Przycisk `editor.reload` unieważnia odczyt i zamyka dialog po świeżych danych. Przycisk nie wysyła ponownie starego ciała.

`LocaleTabs` przełącza kulturę pól. Obie kultury są w stanie formularza naraz. Zmiana zakładki nie kasuje drugiej kultury.

`usePreview` woła podgląd bramy po przerwie i przy zmianie tekstu anuluje poprzednie żądanie. Wynik renderuje `TrustedHtml`. Surowy tekst z pola nie idzie do `TrustedHtml`.

### 4. Skrzynki

`StudentInboxPage` i `RecruiterInboxPage` wołają dwa różne hooki odczytu. Wiersz pokazuje dane, które API oddało dla tej listy. Strona studentów nie czyta listy rekruterów „na wszelki wypadek”.

Pusty wynik pokazuje `inbox.empty`. Błąd pokazuje `error.load`.

### 5. Testy nagłówka i roli

Dopisz fakty z tabeli testów. Stub bramy zapisuje ostatni nagłówek `If-Match`. Test konfliktu zwraca `412` i sprawdza, że w dokumencie jest `editor.conflict`, a drugie żądanie zapisu nie wyszło samo.

### Co jest do czego

- `OwnerRoute` — nawigacja dla roli. Woła go drzewo `App`. Usługa i tak sprawdza rolę drugi raz.
- `IntranetRoutes` — jedyne miejsce adresów intranetu. Nowa podstrona właściciela dopisuje się tutaj, nie w publicznym `/:lang`.
- `IntranetLayout` — nawigacja czterech obszarów. Strony edytora jej nie rysują od nowa.
- `useSaveWithMatch` — jedyne miejsce, które dokleja `If-Match` do zapisu treści. Edytor CV, notatki i kursu wołają ten hook.
- `ConflictDialog` — odpowiedź na `412`. Nie jest ogólnym dialogiem błędów sieci.
- `LocaleTabs` — dwie kultury dokumentu. To nie jest `LangSwitch` belki.
- `usePreview` — HTML z bramy do `TrustedHtml`. Pole tekstowe nie renderuje Markdown samo.
- `StudentInboxPage` — lista `StudentInquiry`. Otwiera ją link intranetu i, na telefonie, kanał studentów.
- `RecruiterInboxPage` — lista `RecruiterInquiry`. Otwiera ją drugi link i drugi kanał.
- `CvEditorPage` — pola CV i slug technologii przy umiejętności. Zapis idzie z `If-Match`.

## Testy

Vitest i Testing Library. Stub klienta nie puszcza żądania do prawdziwej bramy. Każdy fakt ma jeden powód do padnięcia.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `guest_is_sent_to_login` | brak zalogowania, `/intranet` | render | ścieżka `/login` i `next` zaczyna się od `/intranet` |
| `student_is_sent_home` | rola `student` | wejście na `/intranet/cv` | ścieżka `/pl` |
| `owner_sees_dashboard` | rola `owner` | wejście na `/intranet` | widać wejścia do CV, notatek, kursów i obu skrzynek |
| `intranet_chunk_is_lazy` | build | manifest | moduł intranetu nie jest w pliku wejścia gościa |
| `save_sends_if_match` | dokument z `ETag` `v5` | zapis | nagłówek `If-Match` równy `v5` |
| `save_without_etag_does_not_put` | istniejący dokument bez znacznika | próba zapisu | brak żądania aktualizacji |
| `conflict_shows_reload` | stub `412` | zapis | widać `editor.conflict`, brak drugiego zapisu |
| `student_inbox_hides_recruiter_rows` | dwie listy w stubie | `/intranet/contact/students` | widać wiersz studenta, nie widać wiersza rekrutera |
| `recruiter_inbox_has_its_title` | stub listy rekruterów | wejście na skrzynkę | nagłówek `inbox.recruiters.title` |
| `preview_goes_through_trusted_html` | stub HTML z akapitem | podgląd | widać tekst akapitu, nie widać znacznika `script` |
| `locale_tab_keeps_the_other_culture` | tekst w `pl` | przełączenie na `en` i z powrotem | tekst `pl` na miejscu |

```bash
cd src/clients/web
pnpm exec vitest run
```

Test leniwego chunka może czytać wynik `vite build` i listę plików. Jeśli manifest w danym buildzie nazywa chunk inaczej, asercja brzmi: plik wejścia nie zawiera napisu `CvEditorPage`.

## Zasady

- `/intranet/*` jest przed `/:lang` i ładuje się leniwie.
- `OwnerRoute` puszcza tylko rolę `owner`. Gość idzie na login. Inna rola na `/pl`.
- Strażnik nie zastępuje polityki API.
- Aktualizacja istniejącego CV, notatki i kursu wysyła `If-Match` równy ostatniemu `ETag`.
- `412` nie jest ponawiane samo. Autor widzi konflikt i może wczytać serwer.
- `428` traktuj jak błąd klienta: aktualizacja bez nagłówka nie powinna wyjść z `useSaveWithMatch`.
- Skrzynka studentów i skrzynka rekruterów mają osobne adresy i osobne hooki.
- Podgląd Markdown jest HTML-em z bramy, wstawionym przez `TrustedHtml`.
- Umiejętność w CV trzyma slug technologii.
- Adres intranetu trzyma identyfikator dokumentu, nie slug publiczny.
- Widoczność ma trzy klucze chromu. Czwarta plakietka nie powstaje.
- Komponent intranetu zostaje funkcją w osobnym pliku, z eksportem nazwanym.

## Poza zakresem

- Formularz publiczny rekrutera i formularz studenta — [05-tresc.md](05-tresc.md). Intranet te zapytania czyta, nie tworzy ich z roli gościa.
- Klient OpenAPI, `useMe`, `TrustedHtml` — [05-tresc.md](05-tresc.md).
- Kanały push i otwarcie skrzynki na telefonie — [07-powiadomienia.md](07-powiadomienia.md).
- Wygląd przycisku i tabeli — [03-wyglad.md](03-wyglad.md).
- Wydawanie kodu zaproszenia — [17-identity.md](../api/17-identity.md). Ten numer nie dokłada piątego edytora zaproszeń.
- Kody `428`, `412` i `404` po stronie usługi — [11-walidacja.md](../api/11-walidacja.md).
- Edytor kursu na telefonie. Telefon dostaje skrzynki, nie edytory.

## Źródła

- [If-Match](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/If-Match) — zapis wersji, którą klient przeczytał.
- [412 Precondition Failed](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/412) — nieaktualny znacznik.
- [428 Precondition Required](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/428) — brak `If-Match` tam, gdzie zapis go wymaga.
- [React: lazy](https://react.dev/reference/react/lazy) — osobny chunk przy wejściu na intranet.
- [ETag](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/ETag) — znacznik z odczytu, który wraca w zapisie.
- [Identity](../api/17-identity.md) — rola `owner` w tokenie.
- [Contact](../api/21-kontakt.md) — dwa agregaty zapytań.

## Gotowe gdy

- Gość z `/intranet` ląduje na `/login` z bezpiecznym `next`. Student ląduje na `/pl`. Właściciel widzi pulpit.
- Zapis istniejącej notatki, kursu i CV wysyła `If-Match`.
- Odpowiedź `412` pokazuje konflikt i nie wysyła drugi raz sama.
- `/intranet/contact/students` i `/intranet/contact/recruiters` pokazują różne listy i różne nagłówki.
- Podgląd lekcji idzie przez `TrustedHtml`.
- Chunk intranetu nie wchodzi do pliku, który pobiera gość na `/pl`.
- `cd src/clients/web && pnpm exec vitest run` kończy się kodem 0.
