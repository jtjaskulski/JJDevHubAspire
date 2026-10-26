# 21. Kontakt

Ten numer stawia usługę Contact. Są dwa agregaty: `StudentInquiry` i `RecruiterInquiry`.
Poprzedni numer to [CV](20-cv.md). Następny plik tego folderu to
[testy](22-testy.md), które domykają piramidę. W kolejności pracy najpierw jest
drugi pod w [15-skalowanie.md](../cicd/15-skalowanie.md).
Telefon właściciela dostaje dwa różne powiadomienia. Osobnej usługi powiadomień nie ma. Obraz
tego kodu ma tag `contact-vX.Y.Z`.

Bez tego numeru student i rekruter wpadają do jednej skrzynki. Student pisze z konta, które
dostało kod zaproszenia. Rekruter pisze z publicznego formularza przy stronie CV i konta nie ma.
Jedna lista zmusza klienta i push do zgadywania rodzaju po polu. Gdyby formularz miał flagę
`asStudent`, anonim stałby się studentem przez body. Ten numer ma dwa `POST`, dwie listy i dwa
kanały. Token studenta na ścieżce publicznej i tak tworzy `RecruiterInquiry`.

Drugi pęknięty scenariusz dotyczy telefonu. Właściciel ma wiedzieć, która skrzynka przyszła,
zanim otworzy aplikację. Jeden kanał i jeden tytuł „Nowa wiadomość” mieszają wyciszenie i każą
otworzyć aplikację, żeby rozróżnić naukę od rekrutacji. Ten numer wysyła kanał `students` albo
`recruiters`, inny tytuł i pole `screen`. Treści zapytania na ekranie blokady nie ma.

Trzeci scenariusz dotyczy sesji logowania. Token FCM na telefonie właściciela jest sekretem
dostawy. Ma żyć tak długo jak sesja, nie tak długo jak instalacja aplikacji. Wylogowanie z
Identity publikuje `identity.session-ended.v1`. Ten numer kasuje wiersz urządzenia tej pary
`IdentityGuid` i `sessionId`. Po skasowaniu adapter pusha nie ma adresata. Drugi telefon z innym
`sid` zostaje. Bez tego zdarzenia wylogowany aparat dostawałby dalej cudze zapytania.

## Po co

Student pisze do właściciela z zalogowanej strefy. Rekruter pisze z publicznego formularza, bez
konta. Właściciel czyta dwie listy i na telefonie widzi, która skrzynka przyszła, zanim otworzy
aplikację. `StudentInquiry` powstaje tylko z tokenu o roli `student`. `RecruiterInquiry`
powstaje z formularza anonimowego. Formularz nie ma pola roli i nie staje się zapytaniem
studenta, nawet gdy w żądaniu jest token.

Owner czyta dwie listy, nie jedną skrzynkę z filtrem. Urządzenie rejestruje się tylko w sesji
logowania `owner`. Koniec tej sesji kasuje token urządzenia i push przestaje iść. Dwa kanały
systemu, studenci i rekruterzy, mają inny tytuł i otwierają inny ekran. Wysyłka jest adapterem
tej usługi: FCM HTTP v1 i APNs, klucz w OpenBao, outbox w transakcji zapisu, inbox przy drugim
podzie.

Sześć luk zamyka się bez obrazu `notifications`. Tag komponentu zostaje `contact-vX.Y.Z`. W
`GET /versions` usługa nazywa się Contact. Dalsze sekcje rozpisują dwa strumienie, limit
formularza, urządzenie przy `sid`, dwa kanały i to, czemu drugi pod nie woła dostawcy drugi raz.

## Dlaczego ta technologia

### Dwa agregaty

`StudentInquiry` i `RecruiterInquiry` są osobnymi strumieniami w `contact_write`. Mają osobne
projekcje i osobne endpointy listy. Strumień studenta to `student-inquiry-{guid}`. Strumień
rekrutera to `recruiter-inquiry-{guid}`. `StudentInquiry` trzyma `IdentityGuid`, treść, chwilę i
`read`. `RecruiterInquiry` trzyma imię, e-mail, organizację, treść, chwilę i `read`. Treść jest
jednym tekstem nadawcy. Mapa kultur dotyczy tytułu pusha, nie treści zapytania: nadawca pisze w
swoim języku, a owner czyta ten tekst.

Mieszana lista zmusza klienta i push do zgadywania rodzaju po polu, a reguła „kto może utworzyć”
jest inna dla każdego rodzaju. Jeden agregat `Inquiry` z dyskryminatorem odpadł, bo utworzenie
studenta i utworzenie rekrutera mają inny kontrakt wejścia i inny fakt na szynie. Jedna lista z
parametrem `kind` odpadła jako odczyt ownera: łatwo z niej zrobić widok, który miesza nadawców.
Osobna usługa na rodzaj odpadła, bo obie listy czyta ten sam owner i ten sam telefon.

Koszt to dwa workery projekcji i dwa ekrany. Wspólne pole „przeczytane” i tak jest metodą
każdego agregatu osobno. Oznaczenie przeczytane zostaje w strumieniu jako
`contact.student-inquiry-read.v1` albo `contact.recruiter-inquiry-read.v1` i na szynę nie
wychodzi. `Contact.Core` nie referencjonuje MediatR, Entity Framework, Kafki, ASP.NET ani
klienta HTTP dostawcy. Nie ma agregatu `Notification` i nie ma projektu `Notifications`.

### Wejście studenta

`POST /api/contact/student-inquiries` wymaga polityki `Student`. `IdentityGuid` bierze się z
`sub`. Body niesie treść i nie niesie identyfikatora osoby ani roli. Brak roli `student` kończy
się 403 i kodem `inquiry.student.forbidden`: to odmowa akcji na ścieżce, która istnieje tylko
dla tej roli, a nie ukryty dokument. Token `owner` albo brak roli daje 403 i zero strumieni
`student-inquiry`. Test `Student_post_without_role_returns_forbidden` to sprawdza.

Zapytanie studenta ma być przypisane do konta, które dostało kod zaproszenia, a nie do wpisanego
e-maila. Przyjmowanie `identityGuid` z JSON odpadło. Traktowanie każdego zalogowanego, w tym
`owner`, jako studenta odpadło. Zapis studenta do strumienia rekrutera „gdy brak roli” odpadł,
bo to inna lista. Pusta treść daje `inquiry.body.blank` i HTTP 400. Testy
`Create_blank_student_body_returns_invalid` i `Create_blank_recruiter_body_returns_invalid`
rozdzielają oba wejścia.

Koszt jest taki, że owner nie pisze do własnej skrzynki studenckiej. Student bez tokenu dostaje
401. Rola nie jest polem body. Kontrakt studenta nie zawiera właściwości roli. Na szynę wychodzi
`StudentInquiryReceivedIntegrationEvent` z polami `inquiryId`, `identityGuid` i `occurredOn`.
Treści na szynie nie ma.

### Wejście rekrutera

`POST /api/contact/recruiter-inquiries` jest anonimowy. Pola: imię, e-mail, organizacja, treść.
Roli w kontrakcie nie ma. Gdy żądanie ma nagłówek `Authorization`, handler go nie czyta i i tak
dopisuje `RecruiterInquiry`. Token studenta na tej ścieżce nie tworzy `StudentInquiry`. Test
`Student_token_on_public_form_stays_recruiter` sprawdza oba skutki. Test
`Anonymous_post_creates_recruiter_inquiry` sprawdza brak tokenu. Test
`Public_form_has_no_role_field` sprawdza, że kontrakt body nie zawiera właściwości roli ani
`identityGuid`.

Publiczny formularz stoi przy stronie CV. Każdy, kto zobaczy stronę, ma móc napisać, i nikt nie
ma móc tą ścieżką udawać studenta. Jedna ścieżka z flagą `asStudent` odpadła. Awans anonima do
roli, bo wpisał e-mail równy kontu, odpadł. Konto rekrutera w Identity odpadło w
[numerze 17](17-identity.md). Zły e-mail daje `inquiry.recruiter.email.invalid` i HTTP 400.

Koszt to limit częstości na adres IP, inaczej formularz jest otwartym zapisem. Licznik siedzi w
Redis pod `contact:recruiter:{ip}`. Okno limitu to minuta. Przekroczenie zwraca 429 i kod
`inquiry.rate.limited`. Utrata Redisa zdejmuje limit i zostawia zapis w Postgresie. Treść i tak
przechodzi walidację długości. Na szynę wychodzi `RecruiterInquiryReceivedIntegrationEvent` z
polami `inquiryId` i `occurredOn`, bez treści i bez `identityGuid`.

### Dwie listy

`GET /api/contact/student-inquiries` i `GET /api/contact/recruiter-inquiries` wymagają polityki
`Owner`. Każdy czyta własną tabelę w `contact_read`: `student_inquiry_list` albo
`recruiter_inquiry_list`. Identyfikator z drugiej listy na pierwszej ścieżce daje 404. Gość na
liście dostaje 401. Student na liście dostaje 403. Test `Owner_lists_are_separate` sprawdza, że
wiersz studenta nie występuje w `GET` listy rekrutera. Test
`Foreign_id_on_student_list_returns_404` sprawdza identyfikator rekrutera pod ścieżką studenta.

Właściciel ma osobno zobaczyć naukę i rekrutację. Telefon otwiera konkretną skrzynkę, więc API
musi mieć konkretną listę. Jedna kolekcja z sortowaniem po dacie odpadła. 403 przy obcym
identyfikatorze na liście ownera odpadło: dla ownera obcy identyfikator jest brakiem w tej
liście, czyli 404. Ukrywanie listy przed studentem kodem 404 odpadło, bo ścieżka listy jest
akcją ownera, a nie dokumentem publicznym o zmiennej widoczności.

Koszt jest taki, że klient intranetu woła dwa endpointy. Wspólny licznik nieprzeczytanych, jeśli
powstanie w kliencie, jest sumą dwóch odpowiedzi. Szczegół
`GET /api/contact/student-inquiries/{id}` i `GET /api/contact/recruiter-inquiries/{id}` zwraca
200 albo 404. Szukanie identyfikatora w złej tabeli kończy się 404. `POST .../read` wymaga
`If-Match` i ustawia `read=true`. Brak nagłówka to 428 i `precondition.required`. Zła wersja to
412 i `precondition.failed`. Zdarzenie przeczytania zostaje w strumieniu i nie wchodzi do
outboxa.

### Urządzenie tylko przy sesji ownera

Tabela `owner_device` w `contact_write` trzyma `IdentityGuid`, `sessionId` z claimu `sid`, token
urządzenia, platformę `android` albo `ios`, kulturę `pl` albo `en` i `installationId`.
`PUT /api/contact/devices` wymaga polityki `Owner`. Student dostaje 403. Test
`Device_put_requires_owner` sprawdza, że wiersz nie powstaje. Zła platforma daje
`device.platform.invalid` i HTTP 400. `PUT` nadpisuje token dla pary `installationId` i
`sessionId`. `owner_device` nie jest strumieniem.

Wylogowanie kasuje wiersze tej pary `IdentityGuid` i `sessionId`. Kasowanie robi konsument
`identity.session-ended.v1` z [Identity](17-identity.md). Dodatkowo
`DELETE /api/contact/devices` przy żywym access tokenie kasuje wiersze tej sesji od razu, zanim
owner wywoła logout. Po skasowaniu wiersza adapter pusha nie ma adresata. Test
`Logout_event_deletes_device_token` sprawdza, że dany `sessionId` znika, a drugi `sessionId`
tego samego ownera zostaje. Test `Delete_device_stops_push` sprawdza, że po `DELETE` konsument
nie woła sendera, bo lista urządzeń jest pusta.

Token FCM na telefonie właściciela jest sekretem dostawy. Ma żyć tak długo jak sesja logowania,
nie tak długo jak instalacja aplikacji. Rejestracja urządzenia dla studenta odpadła. Trzymanie
tokenu w kliencie bez wiersza serwera odpadło, bo serwer nie wiedziałby, dokąd wysłać push.
Osobna sesja „urządzeń” bez związku z `sid` odpadła, bo wylogowanie z jednego telefonu
skasowałoby drugi. Koszt jest podwójne czyszczenie. Klient woła `DELETE` urządzenia jeszcze z
access tokenem, a potem logout. Gdy klient umrze wcześniej, zdarzenie
`identity.session-ended.v1` i tak czyści wiersz. Do tego czasu drugi telefon z innym `sid`
zostaje.

### Dwa kanały systemu

Powiadomienie studenta używa kanału `students`. Powiadomienie rekrutera używa kanału
`recruiters`. Tytuł studenta i tytuł rekrutera są różnymi napisami, w kulturze zapisanej na
urządzeniu. Po polsku: „Nowe zapytanie studenta” i „Nowe zapytanie rekrutera”. Po angielsku:
„New student inquiry” i „New recruiter inquiry”. Ładunek `data` niesie `screen`:
`student-inquiries` albo `recruiter-inquiries`, oraz `inquiryId`. Treści zapytania na ekranie
blokady nie ma. Test `Push_omits_inquiry_body` sprawdza, że w `data` są `screen` i `inquiryId`,
a treści nie ma.

Jeden kanał i jeden tytuł „Nowa wiadomość” zmuszają właściciela do otwarcia aplikacji, żeby
wiedzieć, która skrzynka, i mieszają ustawienia wyciszenia. Jeden kanał z innym podtytułem
odpadł, bo system operacyjny grupuje i wycisza po kanale, nie po podtytule. Wysyłanie obu pushy
na każde zapytanie odpadło. Android: `android.notification.channel_id` równy kanałowi. APNs:
`thread-id` równy kanałowi, `apns-push-type` równy `alert`. Test
`Student_push_uses_students_channel` sprawdza `channel_id` `students` i tytuł studenta. Test
`Recruiter_push_uses_recruiters_channel` sprawdza `thread-id` `recruiters` i inny tytuł.

Koszt jest po stronie aplikacji telefonu. Zakłada dwa kanały o stałych identyfikatorach. Układ
ekranu, na który wskazuje `screen`, jest w `docs/frontend/07-powiadomienia.md`. Ten numer ustala
identyfikator i tytuł. Kultura urządzenia wybiera zasób `pl` albo `en`. Nadawca nie wybiera
tytułu. Tytuł nie jest treścią zapytania.

### FCM HTTP v1 i APNs

Android idzie przez FCM HTTP v1 (`POST
https://fcm.googleapis.com/v1/projects/{project}/messages:send`) z tokenem OAuth z konta usługi.
iOS idzie przez APNs HTTP/2, klucz `.p8`, algorytm ES256. Oba sekrety czyta Infrastructure z
OpenBao: `secret/contact/fcm` i `secret/contact/apns`. W gicie ich nie ma. Port `IPushSender` ma
dwie implementacje za jednym wywołaniem konsumenta. `FcmPushSender` kładzie kanał w
`channel_id`. `ApnsPushSender` kładzie kanał w `thread-id`. Pakiet Firebase w obrazie nie jest
wymagany: wystarcza `HttpClient`.

Telefon właściciela jest albo Androidem, albo iOS. Platforma w wierszu to `android` albo `ios`.
Jeden protokół nie adresuje obu tokenów. Wysyłka tylko przez FCM także na iOS odpadła jako
jedyna droga, bo ten numer wymienia APNs osobno i klucz APNs w OpenBao. Klucz w zmiennej obrazu
odpadł razem z resztą sekretów. Trzeci dostawca push odpadł. Test, który czyta OpenBao, dostaje
sekret z kontenera testowego albo z dublera portu, nie z wartości w repozytorium. Sender w
teście jest dublerem, bez sieci do Google i Apple.

Koszt to dwa klucze do rotacji, dwa formaty błędu dostawcy i token urządzenia, który dostawca
może unieważnić. Unieważniony token usuwa wiersz `owner_device`. Bez wiersza kolejny push tej
sesji nie wychodzi. Sekret bierze się z OpenBao przy starcie procesu i przy rotacji. Treści
zapytania do ładunku pusha nie wkładamy. JwtBearer waliduje JWKS i nie podpisuje.

### Outbox, konsument, inbox

Dopisanie strumienia zapytania i wiersz outboxa są jedną transakcją w `contact_write`.
Dispatcher publikuje temat `contact.integration`. Konsument w tej samej usłudze Contact, grupa
`contact-push`, wysyła push. Inbox ma klucz główny na identyfikatorze wiadomości. Drugi pod,
który dostanie powtórkę, natrafia na klucz i nie woła FCM ani APNs drugi raz. Test
`Outbox_commits_with_stream` sprawdza, że porażka outboxa wycofuje też zdarzenie strumienia.
Test `Inbox_blocks_second_pod` sprawdza, że druga dostawa tego samego identyfikatora nie woła
`IPushSender`. Test `Event_name_is_stable` sprawdza obie nazwy i brak nazwy klasy w kolumnie
typu.

Przy rebalance widać dwa pody HPA i dostawę co najmniej raz. Podwójny dźwięk na telefonie jest
błędem. Osobna usługa Notifications odpadła. Wysyłka pusha w tym samym wątku co `POST`, przed
commitem, odpadła, bo dostawca jest poza transakcją bazy. Publikacja na szynę bez outboxa
odpadła, bo proces potrafi paść między commitem strumienia a `Produce`. Inbox jest idempotentnym
odbiorcą: kolizja klucza kończy obsługę bez drugiej wysyłki.

Koszt jest po stronie czasu. Push jest chwilę po `POST`, nie w tej samej milisekundzie. Tag komponentu
zostaje `contact-vX.Y.Z`. Obrazu `notifications` nie ma. Redis ma prefiks `contact:` i trzyma
limit formularza oraz cache, nic poza tym. MongoDB nie wchodzi. NBomber czyta listę studencką
zalogowanego ownera na danych już zapisanych. Publiczny `POST` rekrutera do scenariusza NBomber
nie wchodzi, żeby bramka nie zalała zapisu zapytaniami.

## Klasy i ścieżki

Sześć projektów rozdziela dwa agregaty, listy ownera, urządzenie sesji i adaptery FCM oraz APNs.
W Core nie ma agregatu `Notification` i nie ma projektu powiadomień. Tabele poniżej są wiążące
dla strumienia, kanału, endpointu i kodu błędu. Zdanie przy tabeli mówi, co wychodzi na szynę, a
co zostaje przy oznaczeniu przeczytane.

| Projekt | Referencje | Odpowiedzialność |
| --- | --- | --- |
| `src/services/Contact/Contact.Core` | tylko `JJDevHub.Shared.Kernel` | `StudentInquiry`, `RecruiterInquiry` |
| `src/services/Contact/Contact.Application` | `Contact.Core`, `JJDevHub.Cqrs` | komendy, zapytania, port pusha i urządzeń |
| `src/services/Contact/Contact.Persistence` | porty Application | `ContactWriteContext`, `ContactReadContext` |
| `src/services/Contact/Contact.Infrastructure` | porty Application | FCM, APNs, OpenBao, Redis, Kafka |
| `src/services/Contact/Contact.Api` | `JJDevHub.ServiceDefaults` | endpointy |
| `src/services/Contact/Contact.Contracts` | atrybut `EventName` | dwa rekordy integracyjne |

W Core nie ma MediatR, Entity Framework, Kafki, ASP.NET ani klienta HTTP dostawcy. Nie ma
agregatu `Notification` i nie ma projektu `Notifications`.

Strumienie:

| Strumień | Agregat | Kto tworzy |
| --- | --- | --- |
| `student-inquiry-{guid}` | `StudentInquiry` | rola `student` |
| `recruiter-inquiry-{guid}` | `RecruiterInquiry` | formularz publiczny |

`StudentInquiry` trzyma `IdentityGuid`, treść, chwilę, `read`. `RecruiterInquiry` trzyma imię,
e-mail, organizację, treść, chwilę, `read`. Treść jest jednym tekstem nadawcy. Mapa kultur
dotyczy tytułu pusha, nie treści zapytania: nadawca pisze w swoim języku, a owner czyta ten
tekst.

Zdarzenia strumienia: `contact.student-inquiry-received.v1` i
`contact.recruiter-inquiry-received.v1` są zarazem nazwami integracyjnymi. Oznaczenie
przeczytane zostaje w strumieniu jako `contact.student-inquiry-read.v1` albo
`contact.recruiter-inquiry-read.v1` i na szynę nie wychodzi.

| Klasa | `EventName` | Pola |
| --- | --- | --- |
| `StudentInquiryReceivedIntegrationEvent` | `contact.student-inquiry-received.v1` | `inquiryId`, `identityGuid`, `occurredOn` |
| `RecruiterInquiryReceivedIntegrationEvent` | `contact.recruiter-inquiry-received.v1` | `inquiryId`, `occurredOn` |

Treść zapytania na szynę nie wchodzi. Konsument czyta treść z bazy tej usługi, gdy układa
podgląd wewnętrzny, a na telefon wysyła tylko tytuł kanału i `inquiryId`. Ładunek JSON to
prymitywy.

Tabele:

| Miejsce | Tabela | Po co |
| --- | --- | --- |
| `contact_write` | strumienie, outbox, inbox, `owner_device` | zapis i dostawa |
| `contact_read` | `student_inquiry_list`, `recruiter_inquiry_list` | dwie listy ownera |

`owner_device` nie jest strumieniem. `PUT` nadpisuje token dla pary `installationId` i
`sessionId`.

Endpointy:

| Metoda i ścieżka | Kto | Skutek |
| --- | --- | --- |
| `POST /api/contact/student-inquiries` | `Student` | strumień studenta, outbox pierwszej nazwy |
| `POST /api/contact/recruiter-inquiries` | anonim | strumień rekrutera, outbox drugiej nazwy |
| `GET /api/contact/student-inquiries` | `Owner` | lista studencka |
| `GET /api/contact/recruiter-inquiries` | `Owner` | lista rekrutera |
| `GET /api/contact/student-inquiries/{id}` | `Owner` | szczegół albo 404 |
| `GET /api/contact/recruiter-inquiries/{id}` | `Owner` | szczegół albo 404 |
| `POST /api/contact/student-inquiries/{id}/read` | `Owner`, `If-Match` | `read=true` |
| `POST /api/contact/recruiter-inquiries/{id}/read` | `Owner`, `If-Match` | `read=true` |
| `PUT /api/contact/devices` | `Owner` | wiersz urządzenia dla `sid` |
| `DELETE /api/contact/devices` | `Owner` | kasuje wiersze tego `sid` |

Kanały i tytuły (zasoby `pl` i `en`, wybór według kultury urządzenia):

| Kanał | `screen` | Tytuł `pl` | Tytuł `en` |
| --- | --- | --- | --- |
| `students` | `student-inquiries` | Nowe zapytanie studenta | New student inquiry |
| `recruiters` | `recruiter-inquiries` | Nowe zapytanie rekrutera | New recruiter inquiry |

Android: `android.notification.channel_id` równy kanałowi. APNs: `thread-id` równy kanałowi,
`apns-push-type` równy `alert`.

Kody:

| Kod | HTTP |
| --- | --- |
| `inquiry.body.blank` | 400 |
| `inquiry.recruiter.email.invalid` | 400 |
| `inquiry.student.forbidden` | 403, token bez roli `student` na ścieżce studenta |
| `inquiry.rate.limited` | 429 |
| `device.platform.invalid` | 400 |
| `precondition.required` | 428 |
| `precondition.failed` | 412 |

Szczegół nieznany i identyfikator z drugiej listy: 404.

AppHost: `Contact.Api`, `contact-write`, `contact-read`, Redis, Kafka, OpenBao. JwtBearer
waliduje JWKS i nie podpisuje. Wydanie komponentu: tag `contact-vX.Y.Z` i obraz o tej nazwie. W
`GET /versions` usługa nazywa się Contact.

## Plan

### 1. Projekty

Utwórz sześć projektów Contact. `Contact.Core` referencjonuje tylko `JJDevHub.Shared.Kernel`.
Nie twórz projektu powiadomień. W AppHost podepnij dwa connection stringi, Redis, Kafkę i
OpenBao. Nazwa obrazu i tag to `contact-vX.Y.Z`.

### 2. Dwa agregaty

Dodaj `StudentInquiry` i `RecruiterInquiry` ze strumieniami z tabeli. Metoda utworzenia studenta
przyjmuje `IdentityGuid` już wyjęty z tokenu w warstwie Api. Metoda utworzenia rekrutera
przyjmuje imię, e-mail, organizację i treść.

### 3. Endpointy wejścia

Podepnij `POST` studenta pod politykę `Student`. Podepnij `POST` rekrutera bez polityki. W
handlerze rekrutera nie czytaj `ClaimsPrincipal`. Ustaw limit IP w Redis na oknie minuty.

### 4. Dwie projekcje

Składaj `student_inquiry_list` i `recruiter_inquiry_list`. Endpointy `GET` ownera czytają każdą
tabelę osobno. Szukanie identyfikatora w złej tabeli zakończ 404.

### 5. Urządzenia

Dodaj `owner_device`. `PUT` zapisuje token, platformę, kulturę i `sid`. `DELETE` kasuje wiersze
tego `sid`. Konsument `identity.session-ended.v1` kasuje tę samą parę `identityGuid` i
`sessionId`.

### 6. Outbox i push

W transakcji utworzenia zapytania dopisz zdarzenie strumienia i wiersz outboxa z `[EventName]`
tej listy. Dispatcher publikuje `contact.integration`. Konsument `contact-push` wkłada inbox,
ładuje urządzenia ownera, woła `IPushSender` z kanałem i tytułem tej listy. Kolizja klucza inbox
kończy obsługę bez drugiej wysyłki.

### 7. Adaptery dostawców

Zaimplementuj FCM HTTP v1 i APNs na `HttpClient`. Sekret bierz z OpenBao przy starcie procesu i
przy rotacji. Token odrzucony przez dostawcę usuń z `owner_device`. Treści zapytania do ładunku
pusha nie wkładaj.

### 8. Oznaczenie przeczytane

`POST .../read` wymaga `If-Match`. Zdarzenie przeczytania zostaje w strumieniu i nie wchodzi do
outboxa.

### 9. Testy numeru

Dodaj pięć projektów testowych. NBomber czyta listę studencką zalogowanego ownera na danych już
zapisanych. Publiczny `POST` rekrutera do scenariusza NBomber nie wchodzi.

### Co jest do czego

| Klasa albo job | Po co istnieje | Kto woła |
| --- | --- | --- |
| `StudentInquiry` | jedno zapytanie z konta studenta | `POST` z polityką `Student` |
| `RecruiterInquiry` | jedno zapytanie z formularza | `POST` anonimowy |
| `StudentInquiryListProjection` | lista pierwszej skrzynki | `GET` ownera |
| `RecruiterInquiryListProjection` | lista drugiej skrzynki | `GET` ownera |
| `OwnerDevice` | adres pusha jednej sesji logowania | `PUT` urządzenia i konsument końca sesji |
| `SessionEndedConsumer` | kasuje token po `identity.session-ended.v1` | temat `identity.integration` |
| `InquiryPushConsumer` | wysyła jeden push na wiadomość | temat `contact.integration` |
| `FcmPushSender` | Android, kanał w `channel_id` | konsument pusha |
| `ApnsPushSender` | iOS, kanał w `thread-id` | konsument pusha |
| `Inbox` | zatrzymuje drugą wysyłkę z drugiego poda | konsument przed `IPushSender` |

`StudentInquiry` powstaje z `POST` pod polityką `Student`. `IdentityGuid` jest już wyjęty z
tokenu w warstwie Api. `RecruiterInquiry` powstaje z anonimowego `POST`, a handler nie czyta
`ClaimsPrincipal`. `StudentInquiryListProjection` i `RecruiterInquiryListProjection` składają
dwie tabele. `GET` ownera czyta każdą osobno. Identyfikator z drugiej listy kończy się 404.

`OwnerDevice` jest adresem pusha jednej sesji. `PUT` zapisuje token, platformę, kulturę i `sid`.
`SessionEndedConsumer` kasuje tę samą parę po `identity.session-ended.v1`. `InquiryPushConsumer`
czyta `contact.integration`, wkłada `Inbox` i woła `IPushSender`. Kolizja klucza inbox kończy
obsługę. `FcmPushSender` obsługuje Androida, `ApnsPushSender` obsługuje iOS. Treść zapytania do
ładunku nie wchodzi.

## Testy

Runner to xUnit i `[Fact]`. Jeden test, jeden powód.

| Projekt | Piętro |
| --- | --- |
| `src/services/Contact/tests/Contact.Core.Tests` | jednostkowe |
| `src/services/Contact/tests/Contact.Application.Tests` | jednostkowe |
| `src/services/Contact/tests/Contact.Persistence.Tests` | Testcontainers, `postgres:16-alpine`, `Category=Integration` |
| `src/services/Contact/tests/Contact.Api.Tests` | HTTP, `Category=Integration` |
| `src/services/Contact/tests/Contact.Performance.Tests` | NBomber, `Category=Performance` |

Przypadki:

- `Create_blank_body_returns_invalid` — pusta treść daje `inquiry.body.blank` na obu wejściach,
  każde w swoim teście: `Create_blank_student_body_returns_invalid` i
  `Create_blank_recruiter_body_returns_invalid`.
- `Student_post_without_role_returns_forbidden` — token `owner` albo brak roli daje 403 i zero
  strumieni `student-inquiry`.
- `Anonymous_post_creates_recruiter_inquiry` — brak tokenu tworzy tylko `RecruiterInquiry`.
- `Student_token_on_public_form_stays_recruiter` — nagłówek studenta na ścieżce rekrutera tworzy
  `RecruiterInquiry` i nie tworzy `StudentInquiry`.
- `Public_form_has_no_role_field` — kontrakt body nie zawiera właściwości roli ani
  `identityGuid`.
- `Owner_lists_are_separate` — wiersz studenta nie występuje w `GET` listy rekrutera.
- `Foreign_id_on_student_list_returns_404` — identyfikator rekrutera pod ścieżką studenta daje
  404.
- `Device_put_requires_owner` — rola `student` dostaje 403, wiersz nie powstaje.
- `Logout_event_deletes_device_token` — `identity.session-ended.v1` z danym `sessionId` kasuje
  wiersz, drugi `sessionId` tego samego ownera zostaje.
- `Delete_device_stops_push` — po `DELETE` konsument nie woła sendera, bo lista urządzeń jest
  pusta.
- `Outbox_commits_with_stream` — porażka outboxa wycofuje też zdarzenie strumienia.
- `Inbox_blocks_second_pod` — druga dostawa tego samego identyfikatora nie woła `IPushSender`.
- `Student_push_uses_students_channel` — żądanie do FCM ma `channel_id` `students` i tytuł
  studenta.
- `Recruiter_push_uses_recruiters_channel` — żądanie APNs ma `thread-id` `recruiters` i inny
  tytuł.
- `Push_omits_inquiry_body` — ładunek `data` ma `screen` i `inquiryId`, nie ma treści.
- `Mark_read_without_if_match_returns_428` i `Mark_read_with_stale_if_match_returns_412`.
- `Event_name_is_stable` — outbox studenta ma `contact.student-inquiry-received.v1`, outbox
  rekrutera ma `contact.recruiter-inquiry-received.v1`, nazwa klasy w kolumnie typu nie
  występuje.

Integracja Postgresa i Kafki: `Testcontainers`, Kafka w trybie KRaft. Sender w teście jest
dublerem, bez sieci do Google i Apple. Test, który czyta OpenBao, dostaje sekret z kontenera
testowego albo z dublera portu, nie z wartości w repozytorium.

NBomber: `GET` listy studenckiej z tokenem ownera przez 30 sekund. `POST` formularza publicznego
jest poza tym scenariuszem.

Lokalnie:
`dotnet test src/services/Contact --filter "Category!=Integration&Category!=Performance"`.

Układ przypadku zostaje: przygotowanie, działanie, sprawdzenie, jeden powód. W
`Inbox_blocks_second_pod` przygotowaniem jest pierwsza dostawa identyfikatora, działaniem
powtórka na drugim podzie, sprawdzeniem brak drugiego wołania `IPushSender`. W
`Student_token_on_public_form_stays_recruiter` działaniem jest `POST` rekrutera z nagłówkiem
studenta, sprawdzeniem wyłącznie `RecruiterInquiry`. `Mark_read_without_if_match_returns_428` i
`Mark_read_with_stale_if_match_returns_412` stoją osobno.

## Zasady

- Dwa agregaty, dwie listy, dwa `EventName`. Wspólna lista z parametrem `kind` mieszałaby
  nadawców w pushu i w intranecie.
- `Contact.Core` referencjonuje wyłącznie `JJDevHub.Shared.Kernel`. Reguła zapytania kompiluje
  się bez MediatR, Entity Framework, Kafki, ASP.NET i klienta HTTP dostawcy.
- Ścieżka studenta wymaga roli `student`. `IdentityGuid` pochodzi z `sub`. Body nie wybiera
  osoby ani roli.
- Ścieżka publiczna zawsze zapisuje `RecruiterInquiry` i nie czyta tokenu. Nagłówek
  `Authorization` na tej ścieżce nie zmienia agregatu.
- Listy czyta `Owner`. Obcy identyfikator na liście to 404. Student na liście dostaje 403, bo to
  odmowa akcji, nie ukryty dokument.
- `If-Match` przy oznaczeniu przeczytane: 428 albo 412. Zdarzenie przeczytania zostaje w
  strumieniu i nie wchodzi do outboxa.
- Urządzenie istnieje tylko z polityką `Owner` i tylko dla `sid` bieżącego tokenu. Rola
  `student` dostaje 403 i wiersz nie powstaje.
- Koniec sesji logowania kasuje token urządzenia. Brak wiersza oznacza brak pusha. Drugi
  `sessionId` tego samego ownera zostaje.
- Kanał `students` i kanał `recruiters` mają inny tytuł i inny `screen`. Jeden podtytuł nie
  zastępuje kanału, bo system wycisza po kanale.
- FCM HTTP v1 obsługuje Androida. APNs obsługuje iOS. Klucze są w OpenBao. W repozytorium nie ma
  klucza FCM ani klucza APNs.
- Outbox jest w transakcji strumienia. Inbox odcina drugą wysyłkę. Porażka outboxa wycofuje
  także zdarzenie strumienia.
- Nie ma usługi, obrazu ani tagu `notifications`. Jest tag `contact-vX.Y.Z`. W `GET /versions`
  usługa nazywa się Contact.
- Redis: prefiks `contact:`, limit formularza i nic poza cachem oraz limitem. MongoDB nie
  wchodzi. Utrata Redisa zdejmuje limit i zostawia zapis w Postgresie.
- Treść zapytania nie wchodzi do JSON pusha ani do zdarzenia integracyjnego. Na telefon idą
  kanał, tytuł, `screen` i `inquiryId`.
- Oczekiwany błąd to `Result<T>`. Jeden publiczny typ na plik, klasa `sealed`. Oczekiwane
  odrzucenie nie jest wyjątkiem IO.

## Poza zakresem

- Konto, rola i zdarzenie `identity.session-ended.v1` powstają w [Identity](17-identity.md). Ten
  numer je konsumuje. Nie zakłada konta rekrutera.
- Strona, z której rekruter otwiera formularz, powstaje w [CV](20-cv.md). Contact nie czyta
  `cv_read`, żeby przyjąć treść.
- Ekrany `student-inquiries` i `recruiter-inquiries`, rejestracja kanałów w systemie i gest
  wylogowania są w `docs/frontend/07-powiadomienia.md` oraz w numerze telefonu. API ustala
  `screen`, kanał i tytuł.
- OpenBao na maszynie jest w `docs/cicd/14-openbao.md`. Tutaj są ścieżki sekretów.
  `secret/contact/fcm` i `secret/contact/apns` czyta Infrastructure.
- Drugi pod jako reguła HPA jest w `docs/cicd/15-skalowanie.md`. Tutaj inbox ma sprawić, że
  drugi konsument nie wyśle pusha drugi raz.
- Piramida testów, w tym to, która bramka odpala NBomber, jest w [numerze 22](22-testy.md).
  Scenariusz tej usługi czyta listę studencką i nie woła publicznego `POST`.
- Poczta e-mail do nadawcy, załączniki i automatyczna odpowiedź nie wchodzą w ten numer. Nadawca
  dostaje tylko zapis zapytania i, po stronie ownera, push bez treści.

## Źródła

- [FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api). Wiążące są
  `messages:send`, `channel_id` i token OAuth konta usługi. W tym pliku Android idzie przez
  `POST https://fcm.googleapis.com/v1/projects/{project}/messages:send`, a kanał studenta albo
  rekrutera ląduje w `android.notification.channel_id`. Nie bierzemy stąd pakietu Firebase w
  obrazie: wystarcza `HttpClient`. Nie bierzemy też wysyłki iOS wyłącznie przez FCM.
- [APNs](https://developer.apple.com/documentation/usernotifications/sending-notification-requests-to-apns).
  Wiążące są HTTP/2, `apns-push-type` równy `alert` i `thread-id` równy kanałowi. W tym pliku
  iOS używa klucza `.p8` i algorytmu ES256, a sekret leży w OpenBao. Nie bierzemy stąd treści
  zapytania w payloadzie alertu. Zostają tytuł kanału, `screen` i `inquiryId`.
- [OpenBao KV](https://openbao.org/docs/secrets/kv/). Wiążące są ścieżki `secret/contact/fcm` i
  `secret/contact/apns`. W tym pliku Infrastructure czyta je przy starcie i przy rotacji, a git
  ich nie zawiera. Nie bierzemy stąd klucza w zmiennej obrazu ani katalogu zapytań w KV.
  Zapytanie jest strumieniem w Postgresie.
- [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585). Wiążące są 429 i 428. W tym pliku
  przekroczenie limitu formularza daje `inquiry.rate.limited` i 429, a brak `If-Match` przy
  oznaczeniu przeczytane daje 428. Nie bierzemy stąd 429 dla zapytania studenta: limit IP
  dotyczy ścieżki publicznej.
- [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110). Wiążące są 401, 403, 404 i 412. W tym
  pliku gość na liście dostaje 401, student na liście i na urządzeniu 403, obcy identyfikator na
  liście ownera 404, a nieaktualny `If-Match` 412. Nie bierzemy stąd 404 dla listy przed
  studentem: ścieżka listy jest akcją `Owner`, nie dokumentem o zmiennej widoczności.
- [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457). Wiążący jest kształt ciała błędu. W tym
  pliku `type` jest kodem, na przykład `inquiry.body.blank` albo `device.platform.invalid`. Nie
  bierzemy stąd treści wyjątku dostawcy w odpowiedzi dla klienta. Błąd FCM albo APNs zostaje
  przy wierszu urządzenia, nie przy formularzu.
- [Idempotent Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html).
  Gregor Hohpe i Bobby Woolf: wiążące jest to, że druga dostawa nie powtarza skutku. W tym pliku
  inbox ma klucz główny na identyfikatorze wiadomości, a kolizja nie woła `IPushSender`. Nie
  bierzemy stąd wysyłki pusha w wątku `POST` przed commitem. Dostawca jest poza transakcją bazy.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Eric Evans: wiążąca jest granica
  spójności agregatu. W tym pliku granicami są `StudentInquiry` i `RecruiterInquiry`. Nie
  bierzemy stąd jednego agregatu `Inquiry` z dyskryminatorem ani agregatu `Notification`.
  Powiadomienie jest adapterem tej usługi.
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning). Greg Young: wiążąca
  jest stabilna nazwa z wersją. W tym pliku outbox studenta ma
  `contact.student-inquiry-received.v1`, a outbox rekrutera
  `contact.recruiter-inquiry-received.v1`. Nie bierzemy stąd wysyłania
  `contact.student-inquiry-read.v1` na szynę. Oznaczenie przeczytane zostaje w strumieniu.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Chris Richardson: wiążące jest to, że treść zapytania czyta się z bazy tej usługi, nie z
  cudzej. W tym pliku konsument pusha bierze treść z `contact_write`, a na telefon jej nie
  kładzie. Nie bierzemy stąd osobnej bazy usługi Notifications. Obrazu `notifications` nie ma.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic usług: własny host i
  brak MediatR, a wysyłka zostaje adapterem tej usługi. W tym pliku `Contact.Core` nie
  referencjonuje MediatR, a push jest portem `IPushSender` w tej samej usłudze. Nie bierzemy
  stąd MediatR ani projektu `Notifications`.

## Gotowe gdy

- Istnieją strumienie `student-inquiry-{guid}` i `recruiter-inquiry-{guid}`, a projektu
  powiadomień nie ma.
- `POST` bez roli `student` nie tworzy `StudentInquiry`. `POST` publiczny, także z tokenem
  studenta, tworzy wyłącznie `RecruiterInquiry`.
- Dwa `GET` ownera zwracają rozłączne listy. Identyfikator z drugiej listy daje 404.
- `PUT` urządzenia bez roli `owner` zwraca 403. Zdarzenie `identity.session-ended.v1` kasuje
  token tej sesji, a test pusha po skasowaniu nie woła sendera.
- Outbox studenta ma `contact.student-inquiry-received.v1`, outbox rekrutera ma
  `contact.recruiter-inquiry-received.v1`.
- Test drugiego poda nie wysyła pusha drugi raz.
- Żądanie studenta i żądanie rekrutera różnią się kanałem, tytułem i `screen`.
- W repozytorium nie ma klucza FCM ani klucza APNs. Tag komponentu w opisie wydania to
  `contact-vX.Y.Z`.
- `dotnet test src/services/Contact --filter "Category!=Integration&Category!=Performance"`
  przechodzi.
- `Contact.Core` referencjonuje tylko `JJDevHub.Shared.Kernel`.
- Tag `contact-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job
  podmienia tylko Deployment `contact`.
