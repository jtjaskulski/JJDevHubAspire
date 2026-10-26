# 19. Kursy i lekcje

Ten numer stawia usługę Learning: kategorię, technologię, kurs, lekcję i postęp studenta.
Poprzedni numer to [notatki](18-news.md). Następny to [CV](20-cv.md). Slug technologii jest
stały. Cv i News wskazują go napisem. Ta usługa nie sprawdza, czy News już takiego linku użył, i
nie czyta `cv_write`.

Bez tego numeru kompendium nie ma adresu, który przeżyje zmianę tytułu. Opublikowany kurs jest
cytowany w CV i w notatce. Gdyby slug technologii zmieniał się razem z nazwą, umiejętność w Cv i
`lessonSlug` w News wskazywałyby w pustkę po każdej korekcie redakcyjnej. Ten numer zostawia
slug z chwili utworzenia i nie daje komendy jego zmiany. Usunięcie logiczne też go nie zwalnia:
rezerwacja zostaje, a na szynę idzie stan z `isDeleted` równym true i tym samym kluczem.

Drugi pęknięty scenariusz dotyczy tego, kto widzi lekcję. Gość ma widzieć tylko materiał
publiczny. Student ma widzieć materiał oznaczony dla studentów i zapisać własny postęp. Owner ma
widzieć także szkic `Private`. Gdyby gość dostał 403 na lekcji `Students`, sam kod zdradzałby,
że slug istnieje. Ten numer kończy widoczność poza grupą kodem 404. Węższa wartość na ścieżce
wygrywa: lekcja publiczna w technologii `Private` jest dla gościa i studenta nieobecna.

Trzeci scenariusz dotyczy strony CV po restarcie. Cv ma złożyć katalog bez `GET` do Learning i
bez czytania `learning_read`. Temat `learning.integration` jest kompaktowany i niesie pełny
stan: `version` oraz `isDeleted`. Konsument, który czyta temat od początku po kompaktowaniu,
dostaje ostatni stan każdego sluga. Bez tego numeru Cv albo dopytuje HTTP, albo trzyma każdą
korektę tytułu i nie wie, który napis jest bieżący.

## Po co

Właściciel układa kompendium: kategoria grupuje technologie, technologia grupuje kursy, kurs
trzyma uporządkowane lekcje. Student widzi materiał oznaczony dla studentów i zapisuje własny
postęp. Gość widzi tylko materiał publiczny. `Technology`, `Course` i `Lesson` mają strumień.
Kategoria i postęp strumienia nie mają. `CodeExample` jest encją wewnątrz `Lesson` i nie ma
strumienia `code-example-{guid}`.

Markdown lekcji i ogrodzenia kodu leżą w bazie, tak jak notatka, z tym samym czyszczeniem. Temat
`learning.integration` niesie pełny stan, nie samą deltę. Widoczność `Private`, `Students` i
`Public` kończy się 404 dla czytelnika poza grupą, nie 403. `Audience` jest tekstem „dla kogo”
na karcie katalogu i nie bierze udziału w autoryzacji.

Pięć luk zamyka się w jednej usłudze, bo kolejność lekcji, widoczność i slug są decyzjami tego
katalogu. News zapisuje slug lekcji u siebie i o nic tu nie pyta. Cv czyta temat, nie tę bazę.
Tag obrazu to `learning-vX.Y.Z`. Dalsze sekcje rozdzielają półkę kategorii, trzy agregaty, encję
przykładu, tabelę postępu i klucz kompaktowania `{kind}:{slug}`.

## Dlaczego ta technologia

### Kategoria bez strumienia

`Category` jest wierszem w `learning_write`: slug, mapa nazw, kolejność. Aktualizacja nadpisuje
wiersz w tej samej transakcji co outbox. Historii zmian nazwy kategorii nie odtwarza się ze
zdarzeń. Na szynę i tak leci pełny stan `learning.category-state.v1` z `version` i `isDeleted`,
kluczem `category:{slug}`. `kind` w kluczu Kafki przyjmuje tu wartość `category`.

Kategoria jest półką na technologie. Półka nie jest materiałem, którego kolejne brzmienie trzeba
odtworzyć, a i tak ma wyjść na szynę, żeby katalog Cv i klient widziały ten sam slug. Strumień
na kategorię odpadł, bo numer wymienia strumienie technologii, kursu i lekcji, a kategoria do
tej listy nie należy. Trzymanie kategorii jako pola na każdej technologii odpadło, bo zmiana
kolejności półek przepisywałaby wszystkie technologie. Test
`Category_update_does_not_append_stream` sprawdza, że zmiana aktualizuje wiersz i outbox, a
tabela strumieni kategorii jest pusta.

Koszt jest taki, że bieżący wiersz nie pamięta poprzedniej nazwy. Konsument widzi ostatnie
brzmienie, bo stan na szynie niesie `version`. `PUT /api/learning/categories/{slug}` zmienia
mapę nazw i kolejność i wymaga `If-Match` wersji wiersza. `POST` utworzenia nagłówka nie wymaga.
`Category` jest typem w Persistence i Application, nie agregatem w Core.

### Strumienie technologii, kursu i lekcji

`Technology`, `Course` i `Lesson` są agregatami. Strumienie: `technology-{guid}`,
`course-{guid}`, `lesson-{guid}`. Slug powstaje przy utworzeniu i nie ma komendy zmiany. Zmiana
nazwy wyświetlanej dopisuje zdarzenie i zostawia slug. Poza usługą identyfikatorem jest slug,
nie GUID. Zdarzenie integracyjne nie niesie GUID-a lekcji, kursu ani technologii.

Opublikowany adres kursu jest cytowany w CV i w notatce. Adres ma przeżyć zmianę tytułu i
wycofanie. Jedna tabela „treści” z kolumną typu odpadła, bo reguły kursu i reguły lekcji
zmieniają się z innego powodu. GUID w zdarzeniu integracyjnym odpadł z tego samego powodu:
sąsiad nie ma prawa znać klucza strumienia. Rezerwacja sluga zostaje po `isDeleted=true`, więc
slug nie wraca do puli. Test `Slug_stable_after_rename` sprawdza, że zmiana mapy nazw zostawia
slug i podbija `version`.

Koszt to trzy projekcje i trzy klucze na jednym temacie. Klucz technologii to
`technology:{slug}`, kursu `course:{slug}`, lekcji `lesson:{slug}`. Wartości `kind` to
`technology`, `course` i `lesson`, obok `category`. Usunięcie wysyła `learning.removed.v1` w
strumieniu i stan z `isDeleted` true przy tym samym kluczu.
`POST /api/learning/{kind}/{slug}/remove` nie zwalnia sluga. Trzy strumienie są ceną za to, że
korekta lekcji nie podbija wersji technologii.

### Kurs trzyma identyfikatory lekcji

`Course` trzyma uporządkowaną listę identyfikatorów lekcji tej samej bazy. Pozycja lekcji nie
jest polem `Lesson`. Dołączenie, odłączenie i zmiana kolejności są komendami kursu. Na szynę
wychodzą slugi lekcji w tej kolejności, nie GUID-y. Komenda kolejności przyjmuje slugi,
rozwiązuje je na GUID-y w `learning_write` i zapisuje listę. Zdarzenie
`learning.course-lessons-reordered.v1` dopisuje się do strumienia kursu.

Kolejność odcinków jest decyzją kursu. Trzymanie `order` na lekcji rozjeżdża się, gdy ta sama
lekcja miałaby trafić do dwóch kursów. W tym produkcie lekcja należy do jednego kursu, a
kolejność i tak jest własnością spisu. Osobny agregat „spis” odpadł, bo spis bez kursu nic nie
znaczy. Sortowanie po dacie utworzenia lekcji odpadło, bo owner układa materiał ręcznie. Test
`Course_reorder_keeps_lesson_stream` sprawdza, że nowa kolejność dopisuje zdarzenie kursu i nie
dopisuje zdarzenia lekcji.

Koszt jest po stronie kursu. Zmiana kolejności podbija wersję kursu i wysyła nowy pełny stan
`course:{slug}`. Lekcja się przy tym nie zmienia. Nieznany slug rodzica, którego nie ma w tej
samej bazie, daje `slug.unknown` i 404. To nie jest baza sąsiada. Slug z News nie jest tu
sprawdzany w ogóle. Własny slug rodzica sprawdzamy w `learning_write`, bo to ta sama usługa.

### Lekcja, Markdown i CodeExample

Treść lekcji jest mapą kultur na Markdown, tak jak notatka, z tym samym czyszczeniem Markdig:
surowy HTML odpada, ogrodzenie zostaje. `CodeExample` jest encją w agregacie `Lesson`: klucz,
język, kod, podpis jako mapa kultur. Powstaje z ogrodzeń przy zapisie, w tym samym zdarzeniu
`learning.lesson-body-changed.v1` co Markdown. Osobnej komendy „dodaj przykład obok treści” nie
ma, żeby przykład nie rozjechał się z fence.

Klient ma pokazać przykład jako osobny blok, z językiem i podpisem, i ma dostać ten sam kod,
który widać w Markdownie. Strumień `code-example-{guid}` odpadł. Parsowanie fence dopiero przy
odczycie odpadło jako drugi wynik dla tego samego zapisu. Trzymanie przykładów w plikach
repozytorium odpadło razem z Markdownem w gicie. Test `Code_example_has_no_stream` sprawdza, że
po zapisie istnieje strumień `lesson-{guid}`, a strumień przykładu nie istnieje. Test
`Fence_and_example_match` sprawdza równość kodu w encji i w ogrodzeniu. Test
`Html_in_lesson_is_stripped` sprawdza, że surowy HTML znika, a ogrodzenie zostaje.

Koszt jest przy każdej korekcie. Zapis lekcji liczy ogrodzenia jeszcze raz i podmienia kolekcję
encji. Ręczna poprawka samego przykładu, bez zmiany Markdownu, nie istnieje.
`LessonStateIntegrationEvent` niesie przykłady jako tablicę obiektów o polach `key`, `language`,
`code` i `caption`. `caption` jest słownikiem. JSON nie niesie typu CLR `CodeExample` ani
GUID-a. Test `Integration_payload_has_no_clr_type` pilnuje braku nazw `LocalizedText` i
`CodeExample`.

### Widoczność i Audience

`Visibility` przyjmuje `Private`, `Students` albo `Public` i stoi na technologii, na kursie i na
lekcji. Odczyt bierze węższą z wartości na ścieżce. Lekcja publiczna w kursie `Students` jest
dla studenta i ownera. Gość dostaje 404. Którekolwiek `Private` na ścieżce daje 404 studentowi i
gościowi, a owner dostaje 200. Brak `Private` przy obecności `Students` wpuszcza studenta i
ownera. Same `Public` wpuszczają także gościa. Efektywna widoczność jest liczona przy projekcji,
żeby `GET` nie składał trzech strumieni.

Owner pisze lekcję, której student jeszcze nie ma widzieć, i osobno pisze zdanie „dla kogo jest
ten kurs” na karcie katalogu. `Audience` jest mapą kultur na technologii i na kursie. Nie bierze
udziału w autoryzacji. Jedno pole „audience równa się rola” odpadło, bo myliłoby tekst
redakcyjny z listą kontroli. 403 dla gościa na lekcji `Students` odpadło, bo odpowiedź
zdradzałaby, że slug istnieje. Test `Private_lesson_returns_404_for_student`,
`Students_lesson_returns_404_for_guest` i `Public_child_in_private_technology_returns_404`
rozdzielają te trzy skutki. Test `Audience_change_does_not_change_visibility` sprawdza, że nowa
mapa `Audience` zostawia ten sam wynik tabeli widoczności.

Koszt jest redakcyjny. Owner ustawia widoczność w trzech miejscach. Zła wartość daje
`visibility.invalid`. Pusty tytuł technologii nie tworzy strumienia. Pusty tytuł albo pusta
treść lekcji dają `lesson.title.blank` albo `lesson.body.blank`. `GET /api/learning/catalog` i
`GET /api/learning/lessons/{slug}` czytają wiersz, który projekcja już oznaczyła jako widoczny
dla tej grupy, albo dostają 404. Owner czyta wiersz bez tego filtra. `CatalogProjection` jest
tym miejscem, które liczy węższą wartość, zanim przyjdzie HTTP.

### Postęp jako tabela

`student_progress` leży w `learning_write`. Klucz: `IdentityGuid` i slug lekcji. Kolumny:
`started` albo `completed`, `updated_on`. Zapis jest `UPSERT`, bez zdarzenia strumienia i bez
tematu `learning.integration`. Projekcja kopiuje wiersz do `learning_read` dla zapytania
„kontynuuj”. Owner czyta liczniki per slug, bez listy `IdentityGuid`. `StudentProgress` jest
typem wiersza, nie agregatem.

Postęp jest bieżącym stanem jednej osoby, a nie historią produktu cytowaną przez Cv. Strumień
postępu odpadł. Wysłanie postępu na temat kompaktowany odpadło, bo temat niesie katalog, a
postęp nie jest publiczny. Zapis postępu w Redisie odpadł, bo Redis jest cachem katalogu, nie
bazą nauki. `PUT /api/learning/progress/{lessonSlug}` wymaga polityki `Student` i body `started`
albo `completed`. `IdentityGuid` bierze się z `sub`. Body nie wybiera osoby. `If-Match` postęp
nie używa: `UPSERT` jest ostatnim zapisem studenta.

Koszt jest taki, że nie ma historii „student trzykrotnie oznaczył ukończenie”. Zostaje ostatni
stan. Dwa `PUT` zostawiają jeden wiersz i zero zdarzeń strumienia postępu. Test
`Progress_upsert_writes_table` to sprawdza. Student oznacza tylko lekcję, której efektywna
widoczność go wpuszcza. Inaczej 404. Kod `progress.hidden` nie występuje. Test
`Progress_on_private_lesson_returns_404` pilnuje lekcji `Private`. `GET /api/learning/progress`
zwraca własne wiersze studenta. `GET /api/learning/progress/summary` dla `Owner` grupuje po
slugu. Test `Owner_summary_omits_identity_guid` sprawdza, że odpowiedź licznika nie ma pola
`identityGuid`.

### Temat kompaktowany

`learning.integration` ma `cleanup.policy=compact`. Klucz wiadomości to `{kind}:{slug}`, gdzie
`kind` to `category`, `technology`, `course` albo `lesson`. Wartość to pełny stan: slug,
`version`, `isDeleted`, widoczność, mapy tekstów, slug rodzica, dla kursu uporządkowane slugi
lekcji. Usunięcie ustawia `isDeleted` na true, podbija `version` i zostawia klucz. Konsument,
który czyta temat od początku po kompaktowaniu, dostaje ostatni stan każdego sluga. Producent
pisze nagłówek typu równy `[EventName]`.

Cv ma złożyć stronę po restarcie bez dopytywania Learning po HTTP i bez trzymania każdej korekty
tytułu. Temat z samymi deltami odpadł, bo zgubiony komunikat zostawia konsumenta bez tytułu.
Osobny temat na rodzaj odpadł, bo Cv i tak czyta jeden katalog. Wywołanie HTTP przy składaniu
strony CV odpadło w [numerze 20](20-cv.md). Test `Integration_state_has_version_and_is_deleted`
sprawdza, że ładunek `learning.technology-state.v1` ma oba pola, a po usunięciu `isDeleted` jest
true przy tym samym kluczu `technology:{slug}`.

Koszt jest rozmiarem wiadomości: każdy stan jest większy niż delta. Kompaktowanie nie zwalnia
producenta z outboxa w tej samej transakcji co zapis. `version` pozwala odrzucić starszy stan,
który dojedzie po nowszym przy przeniesieniu partycji. W teście integracyjnym producent wysyła
dwa stany tego samego klucza na Kafkę z `Testcontainers.Kafka` w trybie KRaft. Konsument po
starcie od ostatniego skompaktowanego widoku widzi wyższą `version`. Tam, gdzie broker testowy
jeszcze nie skompaktował logu, asercja dotyczy klucza i pełnego stanu, nie wewnętrznego okna
kompaktowania. Mapy `pl` i `en` są słownikiem w JSON kontraktu. Redis trzyma
`learning:catalog:{culture}` na 60 sekund i jest kasowany przez projekcję. Prefiks to
`learning:`. MongoDB nie wchodzi.

## Klasy i ścieżki

Sześć projektów rozdziela trzy agregaty, wiersz kategorii, tabelę postępu i kontrakt pełnego
stanu. `Learning.Core` nie zna kategorii jako agregatu i nie zna `StudentProgress` jako
agregatu. Tabele poniżej są wiążące dla zdarzeń strumienia, klucza Kafki, widoczności i
endpointu. Zdanie przy tabeli mówi, co zostaje w usłudze, a co wychodzi jako słownik.

| Projekt | Referencje | Odpowiedzialność |
| --- | --- | --- |
| `src/services/Learning/Learning.Core` | tylko `JJDevHub.Shared.Kernel` | `Technology`, `Course`, `Lesson`, `CodeExample`, `Visibility`, `Audience`, `LocalizedText` |
| `src/services/Learning/Learning.Application` | `Learning.Core`, `JJDevHub.Cqrs` | komendy, zapytania, porty |
| `src/services/Learning/Learning.Persistence` | porty Application | `LearningWriteContext`, `LearningReadContext`, tabela postępu |
| `src/services/Learning/Learning.Infrastructure` | porty Application | Markdig, Redis, Kafka |
| `src/services/Learning/Learning.Api` | `JJDevHub.ServiceDefaults` | endpointy |
| `src/services/Learning/Learning.Contracts` | atrybut `EventName` | rekordy pełnego stanu |

`Category` jest typem w Persistence i Application (wiersz i komenda), nie agregatem w Core.
`StudentProgress` jest typem wiersza, nie agregatem.

Zdarzenia strumienia (zostają w usłudze, na temat idzie pełny stan z tabeli niżej):

| Nazwa | Agregat |
| --- | --- |
| `learning.technology-defined.v1` | `Technology` |
| `learning.technology-renamed.v1` | `Technology` |
| `learning.technology-visibility-changed.v1` | `Technology` |
| `learning.course-defined.v1` | `Course` |
| `learning.course-lessons-reordered.v1` | `Course` |
| `learning.lesson-defined.v1` | `Lesson` |
| `learning.lesson-body-changed.v1` | `Lesson`, w tym kolekcja `CodeExample` |
| `learning.lesson-visibility-changed.v1` | `Lesson` |
| `learning.removed.v1` | każdy z trzech, ustawia usunięcie logiczne |

Rekordy kontraktu, wszystkie z polami `version` i `isDeleted` oraz mapami jako słownikami:

| Klasa | `EventName` | Klucz Kafki |
| --- | --- | --- |
| `TechnologyStateIntegrationEvent` | `learning.technology-state.v1` | `technology:{slug}` |
| `CourseStateIntegrationEvent` | `learning.course-state.v1` | `course:{slug}` |
| `LessonStateIntegrationEvent` | `learning.lesson-state.v1` | `lesson:{slug}` |
| `CategoryStateIntegrationEvent` | `learning.category-state.v1` | `category:{slug}` |

`LessonStateIntegrationEvent` niesie przykłady jako tablicę obiektów o polach `key`, `language`,
`code` i `caption` (słownik). Nie niesie typu CLR `CodeExample`. Nie niesie GUID-a.

Bazy:

| Baza | Co leży |
| --- | --- |
| `learning_write` | strumienie, `categories`, `slug_reservation`, `student_progress`, outbox |
| `learning_read` | katalog, dokument lekcji, postęp studenta, liczniki ownera |

Redis: `learning:catalog:{culture}` na 60 sekund, kasowany przez projekcję. Prefiks `learning:`.

Widoczność efektywna, liczona do wiersza odczytu:

| Na ścieżce jest | Gość | `student` | `owner` |
| --- | --- | --- | --- |
| którekolwiek `Private` | 404 | 404 | 200 |
| brak `Private`, jest `Students` | 404 | 200 | 200 |
| wszystko `Public` | 200 | 200 | 200 |

`Audience` wraca w karcie kursu i technologii jako mapa `pl` /`en` i nie zmienia wiersza tej
tabeli.

Endpointy zapisu, polityka `Owner`, zmiany z `If-Match` poza `POST` tworzenia:

| Metoda i ścieżka | Skutek |
| --- | --- |
| `POST /api/learning/categories` | wiersz kategorii i stan na szynie |
| `PUT /api/learning/categories/{slug}` | nowa mapa nazw i kolejność |
| `POST /api/learning/technologies` | strumień, slug kategorii w body |
| `PUT /api/learning/technologies/{slug}` | nazwa, `Audience`, widoczność |
| `POST /api/learning/courses` | strumień, slug technologii |
| `PUT /api/learning/courses/{slug}` | nazwa, `Audience`, widoczność, uporządkowane slugi lekcji |
| `POST /api/learning/lessons` | strumień, slug kursu, mapy Markdown |
| `PUT /api/learning/lessons/{slug}` | Markdown, widoczność |
| `POST /api/learning/{kind}/{slug}/remove` | `isDeleted=true`, slug zostaje w rezerwacji |

Odczyt:

| Metoda i ścieżka | Kto |
| --- | --- |
| `GET /api/learning/catalog?culture=pl` | filtr widoczności |
| `GET /api/learning/lessons/{slug}?culture=pl` | filtr widoczności, Markdown i przykłady |
| `PUT /api/learning/progress/{lessonSlug}` | polityka `Student`, body `started` albo `completed` |
| `GET /api/learning/progress` | polityka `Student`, własne wiersze |
| `GET /api/learning/progress/summary` | polityka `Owner`, liczniki bez `IdentityGuid` |

Kody: `lesson.title.blank`, `lesson.body.blank`, `slug.invalid`, `slug.taken`, `slug.unknown`
(404, gdy owner podaje rodzica, którego nie ma w tej samej bazie — to nie jest baza sąsiada),
`visibility.invalid`, `progress.hidden` nie występuje: ukryta lekcja daje 404 także na `PUT`
postępu. `precondition.required` to 428, `precondition.failed` to 412.

Własny slug rodzica sprawdzamy w `learning_write`, bo to ta sama usługa. Sluga z News nie
sprawdzamy w ogóle.

AppHost: `Learning.Api`, `learning-write`, `learning-read`, Redis, Kafka. Tag obrazu
`learning-vX.Y.Z`.

## Plan

### 1. Projekty

Utwórz sześć projektów. `Learning.Core` referencjonuje tylko `JJDevHub.Shared.Kernel`. Markdig
podepnij tak samo jak w News, w Infrastructure. Zarejestruj usługę w AppHost z dwoma connection
stringami.

### 2. Kategoria

Dodaj tabelę `categories` i komendy utworzenia oraz zmiany nazwy. W tej samej transakcji zapisz
outbox `learning.category-state.v1` z `version` i `isDeleted`. Nie twórz strumienia kategorii.

### 3. Technologia i kurs

Dodaj agregaty `Technology` i `Course`. Kurs trzyma listę GUID-ów lekcji. Komenda kolejności
przyjmuje slugi, rozwiązuje je na GUID-y w tej bazie i zapisuje listę. Zdarzenie integracyjne
kursu listuje slugi w tej samej kolejności.

### 4. Lekcja

Dodaj `Lesson` i encję `CodeExample`. Przy zapisie Markdown wyciągnij ogrodzenia do encji w tym
samym zdarzeniu `learning.lesson-body-changed.v1`. Ustaw `Visibility` na trzech agregatach.
`Audience` zapisz jako mapę na technologii i kursie.

### 5. Widoczność w projekcji

Przy składaniu `learning_read` policz widoczność efektywną ścieżki. `GET` publiczny i studencki
czytają wiersz, który projekcja już oznaczyła jako widoczny dla tej grupy, albo dostają 404.
Owner czyta wiersz bez tego filtra.

### 6. Postęp

Dodaj `student_progress` w `learning_write` i kopię dla studenta w `learning_read`. `UPSERT` po
`IdentityGuid` z `sub` i slugu lekcji. Nie dopisuj strumienia. Nie wkładaj postępu do outboxa
`learning.integration`. Zapytanie ownera grupuje po slugu.

### 7. Temat

Producent pisze na `learning.integration` z kluczem `{kind}:{slug}`, wartością pełnego stanu i
nagłówkiem typu równym `[EventName]`. Ustawienie tematu: kompaktowanie. Usunięcie wysyła stan z
`isDeleted=true` i tym samym kluczem.

### 8. Endpointy i wersja

Podepnij tabelę ścieżek. `If-Match` na zmianach strumienia i na `PUT` kategorii (wersja
wiersza). Postęp `If-Match` nie używa: `UPSERT` jest ostatnim zapisem studenta.

### 9. Testy numeru

Dodaj pięć projektów testowych. NBomber czyta `GET /api/learning/catalog`.

### Co jest do czego

| Klasa albo job | Po co istnieje | Kto woła |
| --- | --- | --- |
| `Category` | półka katalogu bez historii | komendy kategorii i stan na szynie |
| `Technology` | stały slug, którego użyje umiejętność w CV | komendy ownera, projekcja katalogu |
| `Course` | kolejność lekcji | komenda reorder, stan `course:{slug}` |
| `Lesson` | Markdown i widoczność odcinka | komenda treści, `GET` lekcji |
| `CodeExample` | strukturalna kopia ogrodzenia | powstaje wewnątrz `Lesson` przy zapisie treści |
| `Audience` | tekst „dla kogo”, poza autoryzacją | karta katalogu |
| `StudentProgress` | ostatni stan nauki jednej osoby | `PUT` studenta, licznik ownera |
| `CatalogProjection` | wiersz z widocznością efektywną | `GET` katalogu i lekcji |
| `TechnologyStateIntegrationEvent` | pełny stan pod kompaktowanie | outbox, konsument Cv |

`Category` jest półką: komenda nadpisuje wiersz i w tej samej transakcji wkłada
`CategoryStateIntegrationEvent`. `Technology` trzyma stały slug, którego użyje umiejętność w CV.
`Course` trzyma kolejność lekcji i publikuje slugi w stanie `course:{slug}`. `Lesson` trzyma
Markdown i widoczność odcinka. `CodeExample` powstaje wewnątrz `Lesson` przy
`learning.lesson-body-changed.v1` i nie dostaje własnego strumienia.

`Audience` wraca na karcie katalogu i nie zmienia tabeli widoczności. `StudentProgress` jest
ostatnim stanem nauki jednej osoby: `UPSERT` po `IdentityGuid` z `sub` i slugu, bez outboxa.
`CatalogProjection` oznacza wiersz widocznością efektywną, zanim `GET` katalogu albo lekcji
odpowie 200 albo 404. `TechnologyStateIntegrationEvent` niesie pełny stan pod kompaktowanie. Ten
sam kształt mają stany kursu, lekcji i kategorii: `version`, `isDeleted`, klucz `{kind}:{slug}`.

## Testy

Runner to xUnit i `[Fact]`. Jeden test, jeden powód.

| Projekt | Piętro |
| --- | --- |
| `src/services/Learning/tests/Learning.Core.Tests` | jednostkowe |
| `src/services/Learning/tests/Learning.Application.Tests` | jednostkowe |
| `src/services/Learning/tests/Learning.Persistence.Tests` | Testcontainers, `postgres:16-alpine`, `Category=Integration` |
| `src/services/Learning/tests/Learning.Api.Tests` | HTTP, `Category=Integration` |
| `src/services/Learning/tests/Learning.Performance.Tests` | NBomber, `Category=Performance` |

Przypadki:

- `Create_blank_title_returns_invalid` — pusta nazwa technologii zwraca błąd walidacji, strumień
  nie powstaje.
- `Slug_stable_after_rename` — zmiana mapy nazw zostawia slug i podbija `version`.
- `Course_reorder_keeps_lesson_stream` — nowa kolejność dopisuje zdarzenie kursu i nie dopisuje
  zdarzenia lekcji.
- `Code_example_has_no_stream` — po zapisie lekcji istnieje strumień `lesson-{guid}`, a strumień
  przykładu nie istnieje. Encja jest w zdarzeniu lekcji.
- `Fence_and_example_match` — kod w `CodeExample` jest równy treści ogrodzenia w Markdownie.
- `Html_in_lesson_is_stripped` — surowy HTML znika, ogrodzenie zostaje.
- `Private_lesson_returns_404_for_student` — rola `student` dostaje 404, owner 200.
- `Students_lesson_returns_404_for_guest` — brak tokenu daje 404, student 200.
- `Public_child_in_private_technology_returns_404` — węższa wartość na ścieżce wygrywa.
- `Audience_change_does_not_change_visibility` — nowa mapa `Audience` zostawia ten sam wynik
  tabeli widoczności.
- `Progress_upsert_writes_table` — dwa `PUT` zostawiają jeden wiersz `student_progress` i zero
  zdarzeń strumienia postępu.
- `Progress_on_private_lesson_returns_404`.
- `Owner_summary_omits_identity_guid` — odpowiedź licznika nie ma pola `identityGuid`.
- `Integration_state_has_version_and_is_deleted` — ładunek `learning.technology-state.v1` ma oba
  pola, a po usunięciu `isDeleted` jest true przy tym samym kluczu `technology:{slug}`.
- `Integration_payload_has_no_clr_type` — JSON nie zawiera nazwy `LocalizedText` ani
  `CodeExample`.
- `Update_without_if_match_returns_428` i `Update_with_stale_if_match_returns_412` — osobno,
  każdy na korekcie lekcji.
- `Category_update_does_not_append_stream` — zmiana kategorii aktualizuje wiersz i outbox,
  tabela strumieni kategorii jest pusta.

Test kompaktowania: w teście integracyjnym producent wysyła dwa stany tego samego klucza na
Kafka z `Testcontainers.Kafka` w trybie KRaft, konsument po starcie od ostatniego
skompaktowanego widoku widzi wyższą `version`. Tam, gdzie broker testowy jeszcze nie
skompaktował logu, asercja dotyczy klucza i pełnego stanu, nie wewnętrznego okna kompaktowania.

NBomber: `GET /api/learning/catalog?culture=pl` przez 30 sekund. Zapis postępu do scenariusza
nie wchodzi.

Lokalnie:
`dotnet test src/services/Learning --filter "Category!=Integration&Category!=Performance"`.

Układ przypadku zostaje: przygotowanie, działanie, sprawdzenie, jeden powód. W
`Course_reorder_keeps_lesson_stream` przygotowaniem jest kurs z lekcjami, działaniem nowa
kolejność, sprawdzeniem zdarzenie kursu i brak zdarzenia lekcji. W
`Students_lesson_returns_404_for_guest` działaniem jest `GET` bez tokenu, sprawdzeniem 404.
Wejście studenta, które daje 200, jest osobnym faktem. `Update_without_if_match_returns_428` i
`Update_with_stale_if_match_returns_412` stoją osobno, każdy na korekcie lekcji.

## Zasady

- `Learning.Core` referencjonuje wyłącznie `JJDevHub.Shared.Kernel`. Reguła widoczności i
  kolejności lekcji kompiluje się bez MediatR, Entity Framework, Kafki i ASP.NET.
- Strumień mają `Technology`, `Course` i `Lesson`. `Category`, `CodeExample` i postęp studenta
  strumienia nie mają. Półka i postęp nie odtwarzają historii ze zdarzeń.
- `CodeExample` powstaje i ginie razem ze zdarzeniem treści lekcji. Osobna komenda przykładu
  rozjechałaby fence i blok na karcie.
- Slug jest stały i zostaje zarezerwowany po `isDeleted=true`. Adres cytowany w CV i w notatce
  nie wraca do puli.
- Poza usługą nie wychodzi GUID lekcji, kursu ani technologii. Wychodzi slug. Sąsiad nie poznaje
  klucza strumienia.
- `learning.integration` niesie pełny stan z `version` i `isDeleted`. Klucz to `{kind}:{slug}`.
  Starszy stan, który dojedzie później, konsument odrzuca po wersji.
- Widoczność poza grupą to 404. Gość nie dostaje 403, z którego wyczytałby, że slug istnieje.
- Zapis strumienia i kategorii wymaga `If-Match`: 428 albo 412. Postęp tego nagłówka nie używa,
  bo `UPSERT` jest ostatnim zapisem studenta.
- Mapy `pl` i `en` są słownikiem w JSON kontraktu. `LocalizedText` i `CodeExample` nie wchodzą
  do JSON jako nazwy CLR.
- Postęp zapisuje `IdentityGuid` z tokenu. Body nie wybiera osoby. Licznik ownera nie zwraca
  listy tych identyfikatorów.
- Redis cache ma prefiks `learning:`. MongoDB nie wchodzi. Katalog po utracie Redisa czyta się z
  Postgresa.
- Learning nie woła News ani Cv i nie otwiera ich baz. W konfiguracji nie ma connection stringa
  `cv_write` ani `news_write`.
- Oczekiwany błąd to `Result<T>`. Jeden publiczny typ na plik, klasa `sealed`. Oczekiwane
  odrzucenie nie jest wyjątkiem IO.

## Poza zakresem

- Opcjonalny slug lekcji na notatce zapisuje [News](18-news.md). Learning o tym slugu nie jest
  informowany. Brak lekcji zostaje faktem historycznym linku po tamtej stronie.
- Konsumpcja `learning.integration` i złożenie strony są w [CV](20-cv.md). Ten numer temat
  publikuje. Nie woła HTTP Cv przy zapisie katalogu.
- Ekran katalogu, intranet edycji i render Markdownu są w `docs/frontend`. Ten numer oddaje
  Markdown i tablicę przykładów.
- Role i JWKS są w [Identity](17-identity.md). Learning sprawdza polityki `Owner` i `Student` i
  nie podpisuje tokenu.
- Piramida bramek jest w [testach](22-testy.md). NBomber tego numeru czyta katalog, a bramka
  `main` jest opisana tam.
- Egzamin, ocena, forum i płatność za kurs nie wchodzą w ten numer. Postęp zostaje przy
  `started` albo `completed` na slugu lekcji.

## Źródła

- [Kafka, log compaction](https://kafka.apache.org/documentation/#compaction). Wiążące są
  `cleanup.policy=compact` i klucz stanu. W tym pliku klucz to `{kind}:{slug}`, a wartość jest
  pełnym stanem z `version` i `isDeleted`. Nie bierzemy stąd tematu złożonego z samych delt:
  zgubiony komunikat zostawiałby Cv bez tytułu.
- [PostgreSQL 16, INSERT ON CONFLICT](https://www.postgresql.org/docs/16/sql-insert.html).
  Wiążący jest `UPSERT` postępu. W tym pliku dwa `PUT` zostawiają jeden wiersz
  `student_progress` z kolumną `updated_on` i zero zdarzeń strumienia. Nie bierzemy stąd
  strumienia postępu ani wysyłki postępu na temat kompaktowany.
- [CommonMark](https://spec.commonmark.org/). Wiążące jest ogrodzenie kodu w lekcji. W tym pliku
  `CodeExample` dostaje ten sam kod, który stoi w fence, a surowy HTML odpada. Nie bierzemy stąd
  drugiego parsowania fence dopiero przy odczycie.
- [Markdig, BSD-2-Clause](https://github.com/xoofx/markdig/blob/master/license.txt). Wiążący
  jest parser Markdownu lekcji, ten sam co w News, podpięty w Infrastructure. Licencja pozwala
  wziąć pakiet produkcyjnie. Nie bierzemy stąd regexu wycinającego tagi ani trzymania przykładów
  w plikach repozytorium.
- [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110). Wiążący jest 404 przy materiale poza
  grupą. W tym pliku gość na lekcji `Students` i student na lekcji `Private` dostają 404, nie
  403. Nie bierzemy stąd 403, bo zdradzałby istnienie sluga.
- [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585). Wiążący jest 428 przy braku `If-Match`. W
  tym pliku korekta strumienia i `PUT` kategorii bez nagłówka kończą się
  `precondition.required`. Nie bierzemy stąd 428 dla `PUT` postępu: ostatni zapis studenta nie
  niesie wersji.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Eric Evans: wiążąca jest granica
  spójności. W tym pliku agregatami są `Technology`, `Course` i `Lesson`. `Category` jest
  wierszem, `CodeExample` encją wewnątrz lekcji, a `StudentProgress` typem wiersza. Nie bierzemy
  stąd strumienia na półkę ani strumienia na przykład kodu.
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning). Greg Young: wiążące
  są nazwa z wersją i numer `version` w ładunku. W tym pliku fakty strumienia kończą się `.v1`,
  a stan integracyjny odrzuca starszą `version` przy tym samym kluczu. Nie bierzemy stąd
  osobnego rejestru schematów poza `[EventName]` i rekordem w `Learning.Contracts`.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Chris Richardson: wiążące jest to, że usługa nie czyta cudzej bazy. W tym pliku nie ma
  connection stringa do `cv_write` ani `news_write`, a slug z News nie jest sprawdzany. Nie
  bierzemy stąd wspólnego katalogu w bazie Cv.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic usług i wspólnych
  `ServiceDefaults` bez przejmowania MediatR. W tym pliku `Learning.Core` referencjonuje tylko
  jądro, a polityki ról przychodzą z `JJDevHub.ServiceDefaults`. Nie bierzemy stąd MediatR.
  Mediator jest w `JJDevHub.Cqrs`.

## Gotowe gdy

- `Learning.Core` nie referencjonuje niczego poza `JJDevHub.Shared.Kernel`, a typy `Technology`,
  `Course` i `Lesson` są agregatami ze strumieniem.
- Kategoria i `student_progress` nie mają strumienia. `CodeExample` nie ma własnego strumienia.
- Slug po zmianie nazwy i po usunięciu logicznym zostaje ten sam. Test
  `Slug_stable_after_rename` przechodzi.
- Gość na lekcji `Students` dostaje 404. Student na lekcji `Private` dostaje 404.
- `PUT` postępu dwa razy zostawia jeden wiersz, a temat `learning.integration` tego zapisu nie
  zawiera.
- Wiadomość stanu ma `version`, `isDeleted` i klucz `{kind}:{slug}`. JSON nie zawiera nazwy CLR
  value objectu.
- Kurs publikuje slugi lekcji w kolejności spisu.
- `PUT` lekcji bez `If-Match` zwraca 428.
- `dotnet test src/services/Learning --filter "Category!=Integration&Category!=Performance"`
  przechodzi.
- W konfiguracji Learning nie ma connection stringa do `cv_write` ani `news_write`.
- Tag `learning-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job
  podmienia tylko Deployment `learning`.
