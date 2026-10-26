# Powiadomienia

Ten numer podłącza push na telefonie właściciela. Gdy właściciel jest zalogowany, aplikacja rejestruje token urządzenia w Contact. Wylogowanie ten token kasuje i push przestaje dochodzić. Są dwa kanały systemu: studenci i rekruterzy. Mają inny tytuł. Dotknięcie otwiera właściwą skrzynkę. Wysyłka idzie przez FCM HTTP v1 po stronie Contact. Ten numer nie buduje drugiego systemu wyglądu.

Poprzedni numer to [06-mobile.md](06-mobile.md). Następny to [08-ruch.md](08-ruch.md). Ekrany skrzynek, do których prowadzi dotknięcie, rejestruje nawigator z numeru `06`. Zdarzenia, z których Contact robi push, są w [21-kontakt.md](../api/21-kontakt.md): `contact.student-inquiry-received.v1` i `contact.recruiter-inquiry-received.v1`.

Katalog zmian to `src/clients/mobile`. Web nie rejestruje tokenu urządzenia. Intranet w przeglądarce nie dostaje pusha z tego numeru.

## Po co

Właściciel ma dostać osobną informację o zapytaniu studenta i o zapytaniu rekrutera, na telefonie, który sam trzyma przy sobie. Jedno powiadomienie „nowa wiadomość” miesza dwie skrzynki, które produkt rozdziela od formularza aż po listę.

Token urządzenia w Contact jest upoważnieniem do wysyłki na ten aparat. Ma żyć tylko wtedy, gdy na telefonie zalogowany jest `owner`. Zalogowany student nie rejestruje tego tokenu. Wylogowanie kasuje go po stronie Contact, więc kolejny push nie ma adresata, nawet jeśli system operacyjny jeszcze pamięta kanał.

Wygląd skrzynki po otwarciu jest wyglądem z numeru `06`: te same klasy, te same klucze `inbox.students.title` i `inbox.recruiters.title`. Kanał systemu operacyjnego nie wprowadza własnej palety ani własnego kroju w aplikacji.

Sam fakt, że zapytanie powstało, nie wystarcza, żeby telefon je pokazał. Contact wysyła push dopiero wtedy, gdy w swojej bazie ma token tego aparatu. Telefon jest jedynym miejscem, które ten token oddaje i jedynym, które prosi o jego skasowanie. Webowa skrzynka z numeru `04` nadal działa bez pusha: właściciel może ją otworzyć w przeglądarce, a telefon tylko skraca drogę do tej samej pary list.

Dwa zdarzenia integracyjne nie zlewają się w jeden baner. `contact.student-inquiry-received.v1` niesie kanał studentów. `contact.recruiter-inquiry-received.v1` niesie kanał rekruterów. Klient nie składa tytułu z treści wiadomości studenta. Tytuł przychodzi w powiadomieniu, inny dla każdego kanału, a ekran po dotknięciu i tak czyta pełną listę z bramy. Dzięki temu skrót na belce systemu nie jest drugim źródłem prawdy obok skrzynki.

## Dlaczego ta technologia

### Push tylko przy zalogowanym właścicielu

Moduł `syncOwnerDevice` dostaje rolę i token urządzenia. Rola `owner` i niepusty token powodują rejestrację w Contact przez bramę. Rola `student`, brak roli i pusty token powodują skasowanie, jeśli wcześniej ten aparat był zarejestrowany, i nie powodują rejestracji. Funkcja jest czysta względem Reacta: łatwo ją wywołać z ekranu logowania i z wylogowania, i łatwo ją przetestować bez emulatora.

Rejestracja przy każdym zalogowaniu, także studenta, przegrywa, bo student dostałby na swój telefon push przeznaczony dla właściciela, albo Contact trzymałby token osoby, która skrzynek nie czyta. Rejestracja przy starcie aplikacji, zanim ktokolwiek się zaloguje, przegrywa, bo aparat bez właściciela stałby się adresem wysyłki. Osobna aplikacja „tylko dla właściciela” przegrywa, bo telefon i tak jest jednym klientem z numeru `06`.

Koszt: po wylogowaniu pierwszy moment jest bez pusha, nawet jeśli zapytanie wpadnie sekundę później. To jest właściwy wynik. Właściciel, który chce powiadomienia, zostaje zalogowany. Aplikacja nie trzyma cichego tokenu „na potem”.

Wywołanie idzie na bramę, operacją Contact do rejestracji i do skasowania tokenu urządzenia. Port usługi i klucz konta usługi FCM do klienta nie wchodzą. Klucz wysyłki zostaje w OpenBao, po stronie Contact, jak mówi numer kontaktu.

### Rejestracja przy zalogowaniu i skasowanie przy wylogowaniu

`LoginScreen` po sukcesie, gdy `useMe` pokaże `owner`, bierze token urządzenia z FCM i woła `syncOwnerDevice`. `RegisterScreen` samo w sobie nie rejestruje pusha: dopiero wejście z rolą `owner` na tym telefonie. Student po rejestracji przechodzi przez tę samą funkcję i kończy na gałęzi „nie rejestruj”.

Wylogowanie woła `syncOwnerDevice` z pustą rolą, a potem kasuje token dostępu JWT. Kolejność ma znaczenie: najpierw skasowanie tokenu urządzenia w Contact, przy jeszcze ważnym tokenie dostępu, potem lokalne wylogowanie. Odwrotna kolejność zostałaby z tokenem urządzenia w bazie, bo brama odrzuciłaby żądanie bez JWT.

Zostawienie tokenu w Contact do ręcznego sprzątania przegrywa, bo telefon po wylogowaniu dalej dostawałby treść zapytań. Odświeżanie tokenu urządzenia bez roli przegrywa, bo przedłuża upoważnienie, które wylogowanie miało zdjąć. Jeden token na konto, współdzielony między aparatami bez identyfikatora, przegrywa, bo wylogowanie na jednym telefonie skasowałoby drugi. Żądanie niesie token tego aparatu. Contact kasuje ten wpis, nie wszystkie aparaty właściciela, chyba że kontrakt OpenAPI mówi inaczej: wtedy klient kasuje dokładnie to, co kontrakt nazywa bieżącym urządzeniem. Nie kasuje „na ślepo” listy, której nie dostał.

Koszt: wylogowanie czeka na odpowiedź Contact. Gdy sieć padnie, lokalnie i tak zdejmujemy JWT, a funkcja zapamiętuje, że skasowanie trzeba powtórzyć przy następnym starcie z siecią, zanim jakakolwiek rejestracja. Inaczej stary token zostałby w bazie. Powtórka nie rejestruje studenta. Powtórka tylko kasuje.

### Dwa kanały systemu

Na Androidzie powstają dwa kanały powiadomień. Na iOS powstają dwie kategorie o tych samych identyfikatorach. Identyfikatory są stałe: `students` i `recruiters`. Tytuł powiadomienia jest inny dla każdego. Tekst tytułu układa Contact przy wysyłce. Klient przy tworzeniu kanału podaje nazwę kanału z kluczy chromu, `inbox.students.title` i `inbox.recruiters.title`, żeby w ustawieniach systemu widać było tę samą parę nazw co w aplikacji.

Jeden kanał „jjdevhub” przegrywa, bo system nie pozwoli wyciszyć samych rekruterów, a dotknięcie nie będzie wiedziało, którą skrzynkę otworzyć, dopóki ładunek nie nadrobi tego, co kanał już mógł nieść. Kanał na każdy dokument przegrywa, bo system zaleje listę kanałów, a produkt ma dwa rodzaje zapytań, nie dwa tysiące.

Koszt: identyfikatory kanałów są kontraktem między Contact i telefonem. Zmiana napisu `students` na `student` psuje kierowanie starych powiadomień. Napis jest stały. Tytuł widoczny dla człowieka może być przetłumaczony. Identyfikator nie.

Ładunek niesie identyfikator kanału. Dotknięcie czyta ten identyfikator.

| Identyfikator | Ekran |
| --- | --- |
| `students` | `StudentInboxScreen` |
| `recruiters` | `RecruiterInboxScreen` |

Inny identyfikator nie otwiera ekranu edytora i nie otwiera formularza. Aplikacja zostaje na home albo na ostatnim ekranie i nie zgaduje.

Przebieg na jednym aparacie, którego testy stubują punkt po punkcie:

| Krok | Rola na telefonie | Skutek w Contact |
| --- | --- | --- |
| świeża instalacja | brak | brak tokenu tego aparatu |
| logowanie studenta | `student` | nadal brak tokenu; jeśli został po właścicielu, wpis jest skasowany |
| logowanie właściciela | `owner` | wpis z tokenem FCM tego aparatu |
| odświeżenie tokenu FCM | `owner` | stary wpis tego aparatu schodzi, nowy wchodzi |
| wylogowanie | brak | wpis skasowany, zanim lokalnie zniknie JWT |
| wylogowanie bez sieci | brak | lokalnie JWT schodzi, powtórka skasowania czeka na sieć |
| dotknięcie `students` | `owner` | otwarta skrzynka studentów, bez nowego zapisu tokenu |
| dotknięcie przy wygasłym JWT | brak | `LoginScreen`, a po wejściu `owner` skrzynka z identyfikatora |

Gdy właściciel dotknie powiadomienia, a JWT już wygasł, nawigator idzie na `LoginScreen`, a po udanym logowaniu z rolą `owner` wchodzi na skrzynkę z identyfikatora. Cel przechodzi przez tę samą ostrożność co `safeNext` na webie: tylko te dwie nazwy ekranów, nic z zewnątrz.

### FCM HTTP v1

Telefon uzyskuje token rejestracji FCM przez `@react-native-firebase/messaging` (Apache-2.0). Ten token wysyła do Contact. Wysyłkę powiadomienia wykonuje Contact, protokołem FCM HTTP v1, także na APNs. Klient nie woła `https://fcm.googleapis.com` i nie trzyma klucza konta usługi.

Starszy protokół FCM z kluczem serwera w nagłówku przegrywa, bo jest wycofywany i kusi, żeby włożyć klucz do aplikacji. Bezpośrednie APNs z telefonu przegrywa, bo drugi tor wysyłki rozjechałby się z jednym miejscem w Contact, które już słucha dwóch zdarzeń. Expo Notifications jako warstwa obowiązkowa przegrywa, bo związałaby klienta z Expo, którego ten numer nie zakłada. Sam moduł FCM wystarcza, żeby dostać token i kanał.

Koszt: build telefonu wymaga konfiguracji Firebase na aplikację (plik konfiguracyjny platformy, bez klucza wysyłki). Plik z kluczem konta usługi w repozytorium jest błędem i nie jest częścią tego numeru. Instrukcja sekretu zostaje przy OpenBao i przy numerze kontaktu.

Odświeżenie tokenu FCM przez system, w trakcie gdy właściciel jest zalogowany, woła rejestrację jeszcze raz z nowym tokenem i kasuje poprzedni token tego aparatu, jeśli API przyjmuje identyfikator urządzenia. Jeśli API przyjmuje tylko surowy token, klient wysyła nowy i prosi o skasowanie starego tą samą operacją, którą używa wylogowanie. Nie zostawia obu na zawsze.

### Ten sam motyw

Ekran skrzynki po dotknięciu używa klas z numeru `06`. Nie dokłada widoku „centrum powiadomień” z własnymi kolorami. Baner w aplikacji, rysowany nad treścią w czasie, gdy push już otworzył skrzynkę, nie powstaje jako drugi system. System operacyjny pokazuje powiadomienie. Aplikacja po dotknięciu pokazuje skrzynkę.

Własny zestaw ikon i heksów tylko dla pusha przegrywa, bo paleta jest jedna, w `tokens.ts`. Osobny font w kanale przegrywa, bo krój aplikacji to Inter, a kanał systemu i tak rysuje system, nie nasz CSS.

Koszt: w ustawieniach systemu kanał wygląda natywnie. Spójność z produktem jest na ekranie skrzynki, nie w chromie Androida. Tytuł i tak pochodzi z wysyłki Contact i ma być inny dla studentów i rekruterów, zgodnie z dwoma zdarzeniami.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/clients/mobile/src/push/sync-owner-device.ts` | rejestracja albo skasowanie według roli |
| `src/clients/mobile/src/push/sync-owner-device.test.ts` | fakty roli bez emulatora |
| `src/clients/mobile/src/push/channels.ts` | identyfikatory `students` i `recruiters` |
| `src/clients/mobile/src/push/open-inbox.ts` | identyfikator kanału na nazwę ekranu |
| `src/clients/mobile/src/push/fcm-token.ts` | odczyt tokenu urządzenia, bez klucza wysyłki |
| `src/clients/mobile/src/push/retry-delete.ts` | powtórka skasowania, gdy wylogowanie nie miało sieci |
| `src/clients/mobile/src/screens/LoginScreen.tsx` | po sukcesie woła `syncOwnerDevice` |
| `src/clients/mobile/src/screens/StudentInboxScreen.tsx` | cel kanału `students` |
| `src/clients/mobile/src/screens/RecruiterInboxScreen.tsx` | cel kanału `recruiters` |

`channels.ts` eksportuje stałe, nie napisy rozsiane po ekranach:

```ts
export const studentChannelId = 'students';
export const recruiterChannelId = 'recruiters';
```

`open-inbox.ts` zwraca nazwę ekranu albo `null`. Nawigator woła tę funkcję przy starcie z powiadomienia i przy dotknięciu w czasie działania.

## Plan

### 1. Funkcja roli

Zaimplementuj `syncOwnerDevice(input, client)`. `input` niesie rolę (`owner`, `student` albo brak) i opcjonalny token urządzenia. `client` ma `register(token)` i `remove(token)`.

Dla `owner` i tokenu woła `register`. Dla innej roli woła `remove`, gdy token jest znany lokalnie, i nie woła `register`. Dla wylogowania woła `remove` i czyści lokalny ślad tokenu tylko po sukcesie albo zapisuje powtórkę, gdy sieci nie ma.

### 2. Wejścia z logowania

W `LoginScreen` po udanym logowaniu odczytaj rolę. Wywołaj `syncOwnerDevice`. Wylogowanie w nawigatorze woła najpierw `remove`, potem czyści JWT. `RegisterScreen` nie woła `register` samo.

Nie wołaj Contact z komponentu inaczej niż przez tę funkcję.

### 3. Kanały

Przy starcie, gdy rola to `owner`, utwórz dwa kanały o identyfikatorach z `channels.ts`. Nazwy widoczne weź z `chrome`. Przy roli innej niż `owner` kanałów nie używaj do rejestracji tokenu. Istniejące kanały systemowe mogą zostać; bez tokenu w Contact i tak nic nie przyjdzie.

### 4. Dotknięcie

Podłącz `open-inbox` do wejścia z powiadomienia. `students` otwiera `StudentInboxScreen`. `recruiters` otwiera `RecruiterInboxScreen`. Inna wartość zwraca `null` i nie nawiguje. Gdy brak JWT, zapamiętaj dozwoloną nazwę ekranu i po logowaniu `owner` na nią wejdź. Po logowaniu `student` cel porzuć.

### 5. Testy

Dopisz fakty z tabeli. Stub `client` zapisuje, czy wołano `register`, czy `remove`, i w jakiej kolejności. Test nie łączy się z FCM i nie stawia emulatora. Osobny fakt sprawdza, że nieznany identyfikator kanału nie nawiguje, oraz że powtórka skasowania idzie przed rejestracją, gdy oba ślady są naraz.

### 6. Brak klucza wysyłki

Przejrzyj `src/clients/mobile` i pliki konfiguracyjne obok pakietu. Wolno w nich trzymać identyfikator aplikacji, którego SDK używa, żeby dostać token urządzenia. Nie wolno trzymać klucza konta usługi, pliku JSON konta usługi ani adresu `fcm.googleapis.com`. Wysyłka zostaje w Contact. Ten krok kończy się komendą `rg` z sekcji Testy, z pustym wynikiem.

### Co jest do czego

- `syncOwnerDevice` — jedyna decyzja, czy token urządzenia idzie do Contact. Wołają ją logowanie, wylogowanie i odświeżenie tokenu FCM.
- `channels.ts` — dwa identyfikatory. Contact wkłada je do wysyłki. Telefon czyta je przy dotknięciu.
- `open-inbox` — mapa identyfikatora na ekran z numeru `06`. Nawigator nie ma drugiej mapy.
- `fcm-token.ts` — odczyt tokenu z SDK. Nie wysyła powiadomienia.
- `retry-delete.ts` — skasowanie, które nie doszło przy wylogowaniu. Start aplikacji woła je przed jakąkolwiek rejestracją.
- `StudentInboxScreen` — treść po kanale studentów. Wygląd z numeru `06`.
- `RecruiterInboxScreen` — treść po kanale rekruterów.

## Testy

Vitest na czystych funkcjach. Bez emulatora i bez klucza FCM. Każdy fakt ma jeden powód do padnięcia.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `owner_login_registers_device` | rola `owner`, token `abc` | `syncOwnerDevice` | `register('abc')`, brak `remove` |
| `student_login_does_not_register` | rola `student`, token `abc` | `syncOwnerDevice` | brak `register` |
| `student_login_removes_previous_owner_token` | wcześniej zapisany token, rola `student` | `syncOwnerDevice` | `remove` z tym tokenem |
| `logout_removes_token` | rola pusta, token `abc` | `syncOwnerDevice` | `remove('abc')` |
| `logout_without_network_schedules_retry` | `remove` rzuca błąd sieci | wylogowanie | ślad powtórki ustawiony, `register` niewołane |
| `retry_runs_before_register` | ślad powtórki i nowe logowanie `owner` | start | najpierw `remove`, potem `register` |
| `tap_students_opens_student_inbox` | identyfikator `students` | `open-inbox` | `StudentInboxScreen` |
| `tap_recruiters_opens_recruiter_inbox` | identyfikator `recruiters` | `open-inbox` | `RecruiterInboxScreen` |
| `unknown_channel_opens_nothing` | identyfikator `other` | `open-inbox` | `null` |
| `titles_differ_by_channel_id` | oba identyfikatory | porównanie | identyfikatory różne i równe `students` oraz `recruiters` |

```bash
cd src/clients/mobile
pnpm exec vitest run src/push/sync-owner-device.test.ts
```

Test nie wymaga urządzenia. Integracja z prawdziwym FCM nie wchodzi do tej komendy.

Osobno, w drzewie telefonu nie ma adresu `fcm.googleapis.com`:

```bash
rg -n "fcm.googleapis.com|server_key|AIza" src/clients/mobile
```

Brak trafień. Plik konfiguracyjny platformy, jeśli trzyma identyfikator aplikacji bez klucza wysyłki, nie używa tych napisów. Klucz konta usługi w ogóle nie leży w `src/clients`.

## Zasady

- Token urządzenia rejestruje się w Contact tylko dla roli `owner` na tym telefonie.
- Wylogowanie kasuje token urządzenia. Push potem nie ma wpisu, na który Contact mógłby wysłać.
- Zalogowany `student` nie rejestruje tokenu właściciela.
- Najpierw skasowanie w Contact, potem lokalne zdjęcie JWT. Przy błędzie sieci zostaje powtórka, która idzie przed kolejną rejestracją.
- Kanały są dwa: `students` i `recruiters`. Tytuły powiadomień są różne.
- Dotknięcie otwiera tylko `StudentInboxScreen` albo `RecruiterInboxScreen`.
- Klient nie woła FCM HTTP v1 i nie trzyma klucza wysyłki.
- Wywołanie rejestracji idzie przez bramę.
- Ekran skrzynki nie dostaje osobnej palety.
- Web nie bierze tokenu urządzenia w tym numerze.

## Poza zakresem

- Wysyłka FCM, klucz w OpenBao, inbox zdarzenia i dwa fakty Contact — [21-kontakt.md](../api/21-kontakt.md).
- Ekrany, NativeWind i `AboutScreen` — [06-mobile.md](06-mobile.md).
- Skrzynki w przeglądarce — [04-intranet.md](04-intranet.md).
- Formularze, które tworzą zapytania — [05-tresc.md](05-tresc.md).
- Ruch listy na ekranie skrzynki — [08-ruch.md](08-ruch.md). Czas i tak bierze z tokenów, nie z tego numeru.
- Drugi system wizualny powiadomień w aplikacji, baner z własnym heksem, osobny krój kanału w UI.

## Źródła

- [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/migrate-v1) — wysyłka, którą wykonuje Contact, nie telefon.
- [FCM: rejestracja klienta](https://firebase.google.com/docs/cloud-messaging/android/client) — token urządzenia, który aplikacja wysyła na swoją bramę.
- [React Native Firebase Messaging](https://rnfirebase.io/messaging/usage) — odczyt tokenu, licencja Apache-2.0.
- [Android notification channels](https://developer.android.com/develop/ui/views/notifications/channels) — dwa kanały, osobno wyciszane.
- [Apple notification categories](https://developer.apple.com/documentation/usernotifications/declaring-your-actionable-notification-types) — para identyfikatorów na iOS.
- [Contact](../api/21-kontakt.md) — `contact.student-inquiry-received.v1` i `contact.recruiter-inquiry-received.v1`.

## Gotowe gdy

- Zalogowanie `owner` woła rejestrację tokenu urządzenia w Contact przez bramę.
- Zalogowanie `student` tej rejestracji nie woła.
- Wylogowanie woła skasowanie tokenu, a przy braku sieci zostawia powtórkę przed kolejną rejestracją.
- Dotknięcie kanału `students` otwiera skrzynkę studentów, a `recruiters` skrzynkę rekruterów.
- W `src/clients/mobile` nie ma adresu FCM HTTP ani klucza wysyłki.
- Skrzynka po otwarciu używa klas z numeru `06`, bez osobnej palety.
- `cd src/clients/mobile && pnpm exec vitest run src/push/sync-owner-device.test.ts` kończy się kodem 0.
