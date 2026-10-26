# 07. Agregat

Poprzedni numer, [zdarzenie](06-zdarzenie.md), daje `IDomainEvent` i nazwę z atrybutu. Ten numer
dokłada `AggregateRoot` i `IBusinessRule`: `Apply`, `Replay`, `AddDomainEvent`, `MarkPersisted`.
Następny numer, [strumień](08-strumien.md), zapisze te zdarzenia w pamięci i odrzuci złą wersję.
Po tym numerze da się odtworzyć stan z historii bez dopisania nowego faktu i odrzucić pustą
nazwę kodem `Invalid`. Agregat produkcyjny usługi jeszcze nie powstaje. W teście jest `Probe`,
nie `Article` i nie klasa `News`. Granica nazw jest w [architektura.md](architektura.md).

Scenariusz, który bez tego numeru się psuje, jest pierwszym `Replay` po zapisie. Metoda
publiczna ustawiła `Name`, a `Apply` ustawiło je drugi raz inaczej albo wcale. Odtworzenie z
historii kłamie wobec stanu tuż po komendzie. Projekcja pokaże inną nazwę niż ta tuż po `POST`.
Albo `Replay` woła `Create`, reguła patrzy na dzisiejszy zegar i do listy wpada drugi fakt, a
zapis tej listy dubluje strumień. Klasa nazywa się `News` w namespace News i nikt nie wie, czy
korzeniem jest artykuł, czy cała usługa. Pusta nazwa rzuca wyjątek i brzeg robi z niej `500`.

Historia ma być produktem dla artykułu, konta, zaproszenia, technologii, kursu, lekcji, sekcji
CV i obu zapytań. Żeby `Replay` zbudował ten sam stan co komenda, pola mogą zmieniać się tylko w
jednym miejscu. Ten numer spina regułę: jedyna zmiana pola jest w `Apply`. Reguła biznesowa
zwraca `Result`, nie wyjątek. Pusta nazwa w agregacie próbnym zwraca `Invalid` i kod
`probe.name.blank`.

## Po co

Historia jest produktem dla artykułu, konta, zaproszenia, technologii, kursu, lekcji, sekcji CV
i obu zapytań. Artykuł to `Article` w News. Konto i zaproszenie to `Account` i `Invite` w
Identity. Technologia, kurs i lekcja to `Technology`, `Course` i `Lesson` w Learning. Sekcje CV
to `Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill` i `Language`. Oba
zapytania to `StudentInquiry` i `RecruiterInquiry`. `StudentProgress` nie jest agregatem
strumienia. Żaden z tych typów nie powstaje w tym numerze. Powstaje baza, na której staną, i
próbka `Probe`, która tej bazy nie udaje.

Żeby `Replay` zbudował ten sam stan co komenda, pola mogą zmieniać się tylko w jednym miejscu.
Jeśli metoda publiczna ustawi `Name`, a `Apply` ustawi je drugi raz inaczej, odtworzenie z bazy
kłamie. Błąd widać dopiero, gdy projekcja pokaże inną nazwę niż ta tuż po `POST`. `Apply` jest
jedyną metodą, która przypisuje pola stanu. Metoda tworząca sprawdza reguły, buduje zdarzenie,
woła `Apply`, potem `AddDomainEvent`. `Replay` woła tylko `Apply` i podnosi `Version`. Nie woła
`AddDomainEvent` i nie woła metody publicznej tworzącej agregat.

Reguła biznesowa ma zwracać `Result`, nie wyjątek. Pusta nazwa w agregacie próbnym zwraca
`Invalid` i kod `probe.name.blank`. Ten kod jest celowo spoza usług. Pokazuje mechanizm, zanim
[18-news.md](18-news.md) wprowadzi `article.title.blank`. Tłumaczenie `probe.name.blank` nie
jest wymagane, bo to kod testu, nie kontrakt HTTP. `IBusinessRule` ma `IsBroken` i `Code`.
`Check` przy złamaniu zwraca `Result.Fail(ResultError.Invalid(rule.Code))`. Kod przechodzi przez
fabrykę z numeru 05, więc spacja i wielka litera odpadają.

Klasa agregatu nie nazywa się jak segment namespace. To jest reguła już teraz, na typie próbnym
i na każdym przyszłym typie. `Probe` jej nie łamie. Klasa `News` w namespace News łamałaby ją od
pierwszej linii. To samo zrobiłaby klasa `Cv`, `Contact`, `Identity` albo `Learning`. CV jest
kilkoma agregatami sekcji, nie jednym workiem. Contact to dwa strumienie i dwa fakty na szynie,
nie jedna klasa z polem rozróżniającym studenta i rekrutera. Więcej typów oznacza więcej
strumieni i więcej wersji. Wspólna transakcja między `Skill` i `Project` nie istnieje. Ekran
składa je projekcją w `cv_read`.

`AggregateRoot` nie woła `IEventStore`. Projekt `JJDevHub.EventStore` powstaje w następnym
numerze i jądro go nie referencjonuje. Po konflikcie egzemplarza się nie używa ponownie i nie
woła się `MarkPersisted`. To będzie widać w numerze 08. Tu metoda tylko czyści listę i nie rusza
`Version`. Lista niezatwierdzonych jest w pamięci i ginie, jeśli handler wyrzuci egzemplarz. To
jest właściwe. Uszkodzony strumień, czyli nieznane zdarzenie w `Apply`, jest
`InvalidOperationException`, nie `Result` i nie `400`.

## Dlaczego ta technologia

### `AggregateRoot`

Klasa abstrakcyjna w jądrze, dziedziczy `Entity`. Trzyma `Version` i listę niezatwierdzonych
`IDomainEvent`. `Version` zaczyna się od zera i ma prywatny setter. Lista niezatwierdzonych jest
prywatna. Właściwość `UncommittedEvents` zwraca ją jako tylko do odczytu. `AddDomainEvent`
dokłada zdarzenie do listy i nic nie przypisuje do pól stanu. `MarkPersisted` czyści listę i nie
zmienia `Version`. `Apply` jest chronione i abstrakcyjne, przyjmuje `IDomainEvent`. Klasa nie
zna PostgreSQL, Kafki ani ASP.NET. Nie referencjonuje `JJDevHub.EventStore`.

Pięć usług potrzebuje tej samej wersji, tej samej listy faktów do zapisu i tego samego
odtworzenia. Skopiowanie pętli `foreach Apply` do `Article` i do `Skill` rozjedzie się przy
pierwszym błędzie inkrementacji wersji. Jedna kopia podniesie wersję w `Apply`, druga w
`Replay`, trzecia zapomni wyczyścić listę. Magazyn porówna oczekiwaną wersję z liczbą, która w
każdej usłudze znaczy co innego. Wspólna baza zamyka inkrementację w jednym miejscu: `Replay`
albo ścieżka nowej komendy. `Apply` zmienia pola. Wersji nie podnosi.

Konkret nazw, których ten numer nie implementuje, a już ich broni: News ma `Article`. Cv ma
`Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill`, `Language`. Contact ma
`StudentInquiry` i `RecruiterInquiry`. Identity ma `Account` i `Invite`. Learning ma `Category`,
`Technology`, `Course`, `Lesson`. `StudentProgress` nie dziedziczy `AggregateRoot`. Blok kodu w
lekcji też nie. Próbka nazywa się `Probe` i leży w teście, nie w jądrze. Jądro nie zna `Article`
i nie ma klasy `News`. Dzięki temu mechanika wersji nie ciągnie modelu jednej usługi.

Odpadła encja z publicznymi setterami, którą handler uzupełnia po `if`. Stan nie wynika ze
zdarzeń, więc nie ma czego zapisać w strumieniu. Setter `Name` w handlerze zostawia agregat,
którego `Replay` nie potrafi odtworzyć, bo w historii nie ma faktu. Publiczny setter na bazie
otworzyłby tę drogę każdej podklasie. `AddDomainEvent` celowo nic nie przypisuje. Kto wstawi
przypisanie do `AddDomainEvent`, zrobi drugie miejsce zmiany pola obok `Apply`.

Odpadły Marten i EventFlow jako silnik agregatu. Mechanika agregatu jest treścią tego
repozytorium. Marten wiąże agregat ze swoim modelem zapisu i ze swoim modelem dokumentu.
EventFlow też wynosi pętlę poza jądro. Licencja nie jest tu jedynym powodem. Powodem jest też
granica: jądro nie może ciągnąć API bazy. Marten odpada. EventFlow odpada. `AggregateRoot`
zostaje klasą w `JJDevHub.Shared.Kernel`, bez pakietu i bez połączenia. Zapis listy do pamięci i
kod `stream.version.conflict` są następnym numerem. Zapis do PostgreSQL jest w
[09-persistence.md](09-persistence.md).

Koszt: każdy agregat implementuje `Apply`. Każda zmiana stanu jest zdarzeniem, także korekta
literówki w slugu, tam gdzie slug wolno zmienić. Slug technologii po publikacji i tak zostaje,
ale to reguła Learning, nie reguła bazy agregatu. Lista niezatwierdzonych zdarzeń jest w pamięci
i ginie, jeśli handler wyrzuci egzemplarz po konflikcie. To jest koszt świadomy: po `Conflict`
stary egzemplarz nie jest źródłem prawdy. Nowy stan bierze się z ponownego odczytu i `Replay`.
`MarkPersisted` na egzemplarzu, który nie wszedł do strumienia, skasowałby listę bez zapisu.
Dlatego po konflikcie się go nie woła.

### `IBusinessRule`

Interfejs ma `IsBroken` i `Code`. `AggregateRoot` ma metodę chronioną `Check`. Gdy reguła jest
złamana, `Check` zwraca `Result.Fail(ResultError.Invalid(rule.Code))`. Gdy nie jest złamana,
zwraca sukces. Kod przechodzi przez fabrykę z numeru 05, więc spacja i wielka litera odpadają.
`ProbeNameRequired` jest złamana, gdy nazwa jest pusta albo biała. `Code` zwraca
`probe.name.blank`. Plik reguły jest w teście: `ProbeNameRequired.cs`. Jądro trzyma interfejs,
nie kod `probe.name.blank` jako stałą produkcyjną.

Warunek „nazwa nie jest pusta” ma być obiektem, który da się nazwać w teście, a nie
porozrzucanym `if` z innym tekstem w każdej metodzie. Rodzaj błędu dla złamanej reguły przez
`Check` jest jeden: `Invalid`. `NotFound` i `Forbidden` stawiają porty i polityki na brzegu, nie
reguła wewnątrz agregatu. Wyjątek od tego: brak roli przy tworzeniu `StudentInquiry` jest
`Forbidden` i kodem `inquiry.student.forbidden`, bo to reguła tego agregatu, opisana w
[21-kontakt.md](21-kontakt.md). Baza `Check` w tym numerze zwraca `Invalid`. Agregat, który
potrzebuje innego rodzaju, woła `ResultError` wprost i nie udaje, że każda reguła jest walidacją
formatu.

Pusta nazwa `Probe` jest walidacją i zostaje przy `Invalid`. `Create` z samymi białymi znakami
zwraca `Invalid` i `probe.name.blank`. Widać to w kodzie `Probe`, nawet jeśli fakt tego numeru
pilnuje tylko listy niezatwierdzonych. Przy porażce `Create` zwraca `Result<Probe>` bez
tworzenia zdarzenia. Nie ma `ProbeCreated`, nie ma `Apply`, nie ma wpisu na liście. Dzięki temu
zła nazwa nie zostawia faktu, który `Replay` musiałby kiedyś odtworzyć jako sukces. Kod jest
mały, z kropkami, bez spacji, więc przechodzi fabrykę. Kod `Probe.Name.Blank` by nie przeszedł.

Odpadło `throw new DomainException` w środku reguły. Numer 05 już odrzucił wyjątek dla błędu
oczekiwanego. Wyjątek na pustą nazwę wyszedłby na brzeg jako `500`, choć użytkownik przysłał
puste pole. `Check` zwraca `Result`. Handler, którego jeszcze nie ma, przekaże ten wynik do
brzegu. W tym numerze widać to w `Probe.Create`. Fakt `Replay_leaves_uncommitted_list_empty` tej
gałęzi nie asercjonuje. Drugi powód padnięcia zostałby doklejony do metody, która ma sprawdzać
pustą listę po odtworzeniu.

Odpadł FluentValidation wewnątrz `Core`. FluentValidation jest na brzegu, w
[11-walidacja.md](11-walidacja.md), i zamienia się na `Result`. `Core` nie dostaje tego pakietu.
Reguła w agregacie nie jest adnotacją na żądaniu HTTP. Jest warunkiem, który ma kod. Pakiet
walidacji na brzegu może odrzucić kształt JSON-a, zanim powstanie `Probe`. Nie zastępuje `Check`
w środku, gdy reguła zależy od stanu już odtworzonego. Pusta nazwa w tym numerze jest na tyle
prosta, że wystarcza jej `IsBroken`. Nie potrzebuje biblioteki.

Koszt: prosta reguła to osobny typ albo lokalna klasa w pliku testu. Nie każda linia `if` musi
być klasą, jeśli `Check` przyjmuje też funkcję. W tym numerze interfejs zostaje, bo test ma
nazwany powód `probe.name.blank`. Sama funkcja bez typu schowałaby kod w lambdzie i przegląd nie
zobaczyłby stałego łańcucha przy regule. `ProbeNameRequired` jest tym typem. Leży w teście, obok
`Probe`. Nie leży w jądrze, bo kod próbny nie jest kodem usługi. Agregat, który potrzebuje
`Forbidden`, nie nagina `Check`. Woła `ResultError` wprost.

### Pola tylko w `Apply`

`Apply` jest jedyną metodą, która przypisuje pola stanu. W `Probe` jedyną linią, która wykonuje
`Name = ...`, jest `Apply`. Metoda `Create` nie zawiera przypisania do `Name`. Ścieżka sukcesu:
utwórz egzemplarz, zbuduj `ProbeCreated`, wywołaj `Apply`, potem `AddDomainEvent`, zwiększ
`Version` o jeden. `AddDomainEvent` dokłada fakt do listy i pól nie tyka. Dzięki temu stan po
komendzie i stan po `Replay` powstają w tej samej linii przypisania. Nieznane zdarzenie w
`Apply` rzuca `InvalidOperationException`. To jest uszkodzony strumień, nie `Result` dla
użytkownika. Handler nie łapie tego i nie zamienia na `400`.

Dwa miejsca zapisu pola dają dwa stany: jeden po komendzie, drugi po odtworzeniu. Błąd widać
dopiero, gdy projekcja pokaże inną nazwę niż ta tuż po `POST`. Dla `Probe` tą nazwą jest `Name`.
Dla przyszłego `Article` będą to pola artykułu, których tu nie ma. Dla `Skill` będą to pola
sekcji. Reguła jest ta sama: publiczna metoda nie zapisuje pola „przy okazji”, a `Apply` drugi
raz. Jeśli `Create` ustawi `Name` i `Apply` też, pierwsza ścieżka działa, a `Replay` zależy od
tego, czy ktoś pamiętał o obu. Zostaje jedna linia.

Konkret próbki: `ProbeCreated` ma atrybut `[EventName("kernel.probe-created.v1")]`. Ta nazwa
jest wyłącznie testu. Nie wchodzi na szynę i nie wchodzi do słownika produkcyjnych faktów jako
zdarzenie usługi. Wolno ją dopisać do słownika jako nazwę próbną, jeśli ma być stabilna. Nie
wolno jej publikować z `Contracts`. Niepustą nazwę niesie zdarzenie, a `Apply` przepisuje ją na
pole. Pusta nazwa do zdarzenia nie dochodzi. `Replay` historii jednoelementowej zostawia pustą
listę i wersję `1`, bo długość historii wynosi jeden. Fakt sprawdza listę. Wersja `1` jest w
„Gotowe gdy”. Treść `Name` nie jest asercją faktu, żeby nie było drugiego powodu padnięcia.

Odpadło przypisanie `Name = name` w metodzie publicznej i drugie przypisanie w `Apply`. Zostaje
tylko `Apply`. Odpadło wczytanie migawki i zmiana jej setterem bez zdarzenia. Migawka bez
zdarzenia gubi historię, a historia ma być produktem. Ten numer migawki nie wprowadza. Gdyby ją
wprowadził, musiałaby być skrótem historii, a nie osobnym stanem ustawianym setterem. Setter po
wczytaniu migawki jest tym samym błędem co setter w `Create`: stan, którego nie ma w faktach.
`Replay` z pełnej historii tego nie potrzebuje.

Koszt: każda gałąź stanu ma swój rekord zdarzenia i gałąź w `Apply`. Nieznane zdarzenie nie jest
pomijane. Pominięcie zostałoby cichym rozjazdem: historia ma fakt, stan go nie widzi, wersja i
tak rośnie albo nie. Wyjątek zatrzymuje odtworzenie. To nie jest `400` dla użytkownika, bo
użytkownik nie wysłał nieznanego faktu. Uszkodzony strumień jest awarią danych. Zamiana tego
wyjątku na `Result` zachęciłaby handler do zwrócenia konfliktu albo walidacji i do dalszego
użycia egzemplarza. Egzemplarza po takim błędzie się nie używa.

### `Replay` bez nowych faktów

`Replay` dostaje historię w kolejności wersji. Dla każdego zdarzenia woła `Apply` i zwiększa
`Version` o jeden. Lista niezatwierdzonych zostaje pusta. `Version` po historii o długości `n`
wynosi `n`. Gdy historia jest pusta, `Version` zostaje zero, lista zostaje pusta. `Replay` nie
woła `AddDomainEvent`. Nie woła metody publicznej tworzącej agregat. Nowy `Probe` o wersji zero,
po jednym `ProbeCreated`, ma wersję `1` i zero elementów w `UncommittedEvents`. To jest treść
faktu i warunku ukończenia.

Gdyby odtworzenie wołało metodę publiczną `Create`, reguła sprawdziłaby dzisiejszy zegar, a do
listy doszedłby drugi fakt. Zapis tej listy zdublowałby strumień. Pusta nazwa, która kiedyś
przeszła, mogłaby dziś nie przejść, albo odwrotnie, i odtworzenie przestałoby być funkcją
historii. `Replay` nie sprawdza `ProbeNameRequired`. Reguła obowiązywała przy komendzie, która
fakt wytworzyła. Przy odczycie historii faktem jest to, co już zaszło. Sprawdzenie reguły drugi
raz zmienia przeszłość.

Konkret testu: przygotowanie ma jedno `ProbeCreated` z niepustą nazwą, historię jednoelementową
i nowy `Probe` o wersji zero. Działanie woła `Replay`. Sprawdzenie patrzy, że
`UncommittedEvents` ma zero elementów. Nie patrzy na treść `Name`. To, że `Apply` w ogóle
ustawia `Name`, widać w przeglądzie kodu: w `Create` nie ma przypisania do `Name`. Handler,
który kiedyś połączy odczyt, `Replay`, metodę i `Append`, jest w [10-cqrs.md](10-cqrs.md). Ten
numer handlera nie ma. Ma metodę, która po historii nie produkuje nowych faktów do zapisu.

Odpadło ponowne wywołanie metody publicznej podczas `Replay`. Odpadło też podnoszenie wersji w
`Apply`. `Apply` zmienia pola. Wersję podnosi `Replay` albo ścieżka nowej komendy, w jednym
miejscu, żeby dało się ją przeczytać. Dwa miejsca inkrementacji dają wersję `2` po jednym fakcie
albo wersję `0` po odtworzeniu, zależnie od tego, która ścieżka pamiętała. Magazyn w numerze 08
porówna oczekiwaną wersję z długością strumienia. Jeśli agregat kłamie o wersji, konflikt albo
nadpisanie wyjdzie przy pierwszym równoległym zapisie. Tu wersja po `n` faktach wynosi `n`, a
start jest `0`.

Koszt: historia musi być kompletna i uporządkowana. Dziura w wersjach jest błędem magazynu, nie
rzeczą, którą agregat sam naprawia. Agregat nie wstawia faktu „uzupełniającego” i nie sortuje
historii po swojemu, jeśli dostał ją w złej kolejności. Kolejność jest umową wołającego. Agregat
nie kontaktuje się z `IEventStore`. Nie woła EF, Kafki ani HTTP. Magazyn jest następny numer.
Dzięki temu test `Replay` nie potrzebuje kontenera i nie potrzebuje cechy integracyjnej. NBomber
tu nie występuje.

### Nazwa inna niż segment namespace

Nazwa klasy agregatu nie równa się ostatniemu segmentowi namespace usługi. News ma `Article`. Cv
ma `Profile`, `Position`, `Project`, `Education`, `Activity`, `Skill`, `Language`. Contact ma
`StudentInquiry` i `RecruiterInquiry`. Identity ma `Account` i `Invite`. Learning ma `Category`,
`Technology`, `Course`, `Lesson`. `StudentProgress` nie jest agregatem strumienia. `Probe` nie
nazywa się jak segment testowego namespace w sposób, który udaje usługę. Klasa `News` jest
zakazana jako nazwa agregatu. Tak samo `Cv`, `Contact`, `Identity` i `Learning`.

Klasa `News` w namespace News nie mówi, co jest korzeniem spójności. Miesza usługę z bytem.
Czytelnik nie wie, czy wersja dotyczy artykułu, czy całego modułu. Strumień nie ma klucza, który
da się odróżnić od sąsiedniego korzenia. To samo zrobiłaby klasa `Cv`: jeden worek na profil,
stanowisko, projekt, edukację, aktywność, umiejętność i język. Każdy z tych bytów ma własny
strumień i własną wersję. Ekran i tak składa je w `cv_read`, kopią sluga, poza transakcją między
`Skill` i `Project`.

Konkret zakazu jest wcześniejszy niż kod usług. W tym numerze nie ma projektu News, a reguła już
obowiązuje, bo łatwo złamać ją na próbce albo na pierwszej klasie „dla szybkości”. `Probe` jej
nie łamie. Nie leży w jądrze. Jądro nie zna `Article`. Gdy powstanie `Article`, nazwa zostanie
`Article`, nie `News`. Gdy powstanie zapytanie, powstaną dwa typy, nie jeden `Contact` z polem
dyskryminującym. Dwa typy to dwa fakty na szynie, zgodne z gramatyką numeru 06, gdy tamte numery
je nazwą. Tu ich nie nazywamy produkcyjnie.

Odpadła jedna klasa o nazwie usługi, z właściwościami wszystkich sekcji. CV jest kilkoma
agregatami sekcji, nie jednym workiem. Wspólna wersja dla `Skill` i `Project` wiązałaby zmianę
umiejętności z konfliktem projektu, choć użytkownik edytował jedną sekcję. `Replay` takiego
worka wciągałby historię obu. Projekcja i tak umie złożyć stronę z osobnych wierszy. Worek
niczego nie upraszcza na ekranie, a psuje granicę spójności.

Odpadła klasa `Contact` z polem rozróżniającym studenta i rekrutera. To są dwa strumienie i dwa
fakty na szynie. Jedno pole dyskryminujące wraca do jednego `Apply` z dwoma znaczeniami i do
jednego kodu błędu tam, gdzie student ma `Forbidden`, a rekruter inną regułę.
`inquiry.student.forbidden` jest kodem agregatu `StudentInquiry`, nie kodem worka `Contact`. Ten
numer kodu nie implementuje. Zostawia zasadę, że dwa byty nie dzielą klasy o nazwie usługi.

Koszt: więcej typów. Każdy ma własny strumień i własną wersję. Wspólna transakcja między `Skill`
i `Project` nie istnieje. Ekran składa je projekcją w `cv_read`. Zespół, który chce zapisać dwie
sekcje „na raz”, zrobi dwa dopisania i pogodzi się z tym, że jedno może dostać konflikt, a
drugie przejść. To jest konsekwencja granicy, nie brak transakcji rozproszonej. Ten numer
transakcji między agregatami nie dodaje. Nie woła magazynu w ogóle.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Shared.Kernel/AggregateRoot.cs` | wersja, lista, `Apply`, `Replay`, `AddDomainEvent`, `MarkPersisted` |
| `src/shared/JJDevHub.Shared.Kernel/IBusinessRule.cs` | `IsBroken` i `Code` |
| `tests/JJDevHub.Shared.Kernel.Tests/Probe.cs` | agregat próbny z polem `Name` |
| `tests/JJDevHub.Shared.Kernel.Tests/ProbeNameRequired.cs` | reguła `probe.name.blank` |
| `tests/JJDevHub.Shared.Kernel.Tests/ProbeCreated.cs` | zdarzenie próbne z `[EventName("kernel.probe-created.v1")]` |
| `tests/JJDevHub.Shared.Kernel.Tests/ReplayTests.cs` | fakt pustej listy niezatwierdzonych po `Replay` |

`kernel.probe-created.v1` jest nazwą wyłącznie testu. Nie wchodzi na szynę i nie wchodzi do
słownika produkcyjnych faktów jako zdarzenie usługi. Wolno ją dopisać do słownika jako nazwę
próbną, jeśli ma być stabilna. Nie wolno jej publikować z `Contracts`.

## Plan

### 1. Klasa bazowa

Dodaj `AggregateRoot : Entity`. `Version` zaczyna się od zera i ma prywatny setter. Lista
niezatwierdzonych jest prywatna. Właściwość `UncommittedEvents` zwraca ją jako tylko do odczytu.
`AddDomainEvent` dokłada zdarzenie do listy i nic nie przypisuje do pól stanu. `MarkPersisted`
czyści listę i nie zmienia `Version`.

### 2. Apply i Replay

`Apply` jest chronione i abstrakcyjne, przyjmuje `IDomainEvent`. `Replay` iteruje historię, woła
`Apply`, zwiększa `Version`. Nie woła `AddDomainEvent`. Gdy historia jest pusta, `Version`
zostaje zero, lista zostaje pusta.

### 3. Ścieżka komendy

W `Probe.Create` najpierw `Check` reguły nazwy. Przy porażce zwróć `Result<Probe>` bez tworzenia
zdarzenia. Przy sukcesie utwórz egzemplarz, zbuduj `ProbeCreated`, wywołaj `Apply`, potem
`AddDomainEvent`, zwiększ `Version` o jeden. `Apply` jest jedyną linią, która wykonuje `Name =
...`. Metoda `Create` nie zawiera przypisania do `Name`.

### 4. Reguła

`ProbeNameRequired` jest złamana, gdy nazwa jest pusta albo biała. `Code` zwraca
`probe.name.blank`. `Check` mapuje to na `ResultError.Invalid`.

### 5. MarkPersisted

Po teście ścieżki komendy, tam gdzie handler już ma sukces zapisu, woła się `MarkPersisted`. W
tym numerze woła to test, nie magazyn. Magazyn nie dostaje referencji do agregatu. Dostaje listę
zdarzeń. Po `Conflict` handler wyrzuca egzemplarz i nie woła `MarkPersisted`. To będzie widać w
numerze 08. Tu metoda tylko czyści listę.

### Co jest do czego

`AggregateRoot` woła każdy przyszły korzeń strumienia. Trzyma wersję, którą magazyn porówna z
oczekiwaną. Gdy klasy nie ma, `Article` i `Skill` kopiują pętlę i rozjeżdżają inkrementację. Gdy
klasa nazywa się `News`, usługa i byt są jednym typem. Gdy baza referencjonuje
`JJDevHub.EventStore`, jądro zależy od magazynu, który ma zależeć od jądra, i numer 08 nie ma
czego podstawić.

`Apply` wołają `Replay` i ścieżka komendy. Jest jedynym miejscem przypisania pól. Gdy
przypisanie jest też w `Create`, odtworzenie kłamie. Gdy nieznane zdarzenie jest pomijane,
historia i stan się rozjeżdżają. Wyjątek na nieznanym zdarzeniu zatrzymuje uszkodzony strumień.
Zamiana tego na `400` oddaje awarię danych użytkownikowi.

`Replay` woła handler komendy po odczycie strumienia. Buduje stan i zostawia pustą listę do
zapisu. Gdy woła `Create`, dokłada drugi fakt i potrafi odrzucić historię dzisiejszą regułą. Gdy
podnosi wersję w `Apply` zamiast u siebie, jedno zdarzenie liczy się dwa razy albo wcale. Pusta
historia, która zostawia wersję inną niż zero, kłamie, że strumień coś zawiera.

`AddDomainEvent` woła ścieżka komendy po `Apply`. Zbiera to, co magazyn ma dopisać. `Replay`
tego nie woła. Gdy `Replay` woła `AddDomainEvent`, zapis odtworzenia dubluje strumień. Gdy
`AddDomainEvent` przypisuje pola, powstaje drugie miejsce zmiany stanu. Gdy listy nie da się
wyczyścić, ten sam fakt wejdzie do następnego dopisania.

`MarkPersisted` woła handler po udanym `Append`. Mówi egzemplarzowi, że lista jest już w
strumieniu. Nie zapisuje sam. Gdy czyści wersję albo ją zmienia, następna komenda na tym
egzemplarzu widzi zły numer. Gdy jest wołane po `Conflict`, lista znika, choć strumień jej nie
przyjął. W tym numerze woła to test, nie magazyn. Magazyn nie dostaje referencji do agregatu.

`IBusinessRule` woła `Check`. Zamienia warunek na kod `Invalid`. Gdy interfejsu nie ma, każdy
`if` ma inny tekst i inny rodzaj. Gdy `Check` rzuca, pusta nazwa staje się `500`. Gdy `Check`
zwraca `Forbidden` dla każdej reguły, walidacja formatu udaje odmowę roli. Inny rodzaj woła
`ResultError` wprost. Wyjątek `StudentInquiry` jest w numerze 21, nie w bazowym `Check`.

`Probe` woła tylko test. Chroni mechanikę przed wciągnięciem `Article`. Gdy `Probe` leży w
jądrze, wspólny projekt zna nazwę próbną i pole `Name` jako model. Gdy zamiast `Probe` powstaje
klasa `News`, reguła nazwy agregatu jest złamana od pierwszej linii. `ProbeCreated` z nazwą
`kernel.probe-created.v1` zostaje w teście i nie jedzie na szynę.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]`. Powód padnięcia jest jeden: po
`Replay` lista niezatwierdzonych zdarzeń nie jest pusta. NBomber tu nie występuje. Kontener nie
jest potrzebny. Cechy `Category=Integration` i `Category=Performance` nie wchodzą. Równość listy
da się sprawdzić w pamięci, na jednym `ProbeCreated`.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | jedno `ProbeCreated` z niepustą nazwą, historia jednoelementowa, nowy `Probe` o wersji zero |
| Działanie (act) | `Replay` tej historii |
| Sprawdzenie (assert) | `UncommittedEvents` ma zero elementów |

Nazwa metody: `Replay_leaves_uncommitted_list_empty`.

```text
dotnet test tests/JJDevHub.Shared.Kernel.Tests/JJDevHub.Shared.Kernel.Tests.csproj --filter "FullyQualifiedName~Replay_leaves_uncommitted_list_empty"
```

Fakt nie sprawdza jednocześnie treści `Name`. To byłby drugi powód padnięcia. To, że `Apply` w
ogóle ustawia `Name`, widać w przeglądzie kodu `Probe` opisanym w „Gotowe gdy”: w `Create` nie
ma przypisania do `Name`. Pusta nazwa i kod `probe.name.blank` są w zasadach tej samej klasy i
mają być prawdziwe, ale nie wchodzą do asercji tego faktu.

Przygotowanie nie woła `Create` z białą nazwą i nie woła magazynu. Historia jest podana wprost,
tak jak zrobi to odczyt strumienia. Działanie jest jednym `Replay`. Sprawdzenie liczy elementy
listy. Nie porównuje wersji w tej asercji. Wersja `1` po historii jednoelementowej jest
warunkiem ukończenia, widocznym razem z pustą listą, i nie dokleja drugiego powodu do metody,
której nazwa mówi o liście. `MarkPersisted` też nie jest w tej asercji. Jego kontrakt,
czyszczenie listy bez ruchu wersji, jest w „Gotowe gdy”.

Jeśli `Replay` woła `AddDomainEvent`, lista ma jeden element i fakt jest czerwony z właściwego
powodu. Jeśli `Apply` rzuci na `ProbeCreated`, fakt też będzie czerwony, bo do asercji nie
dojdzie. To nadal znaczy, że odtworzenie nie zostawiło pustej listy. Nie dokłada się tu asercji
o `probe.name.blank`. Ta gałąź nie tworzy historii.

## Zasady

- Pole stanu zmienia się tylko w `Apply`. Przypisanie w `Create` albo w `AddDomainEvent` daje
  inny stan po komendzie niż po `Replay`.
- `Replay` nie woła `AddDomainEvent` i nie woła metody publicznej tworzącej agregat. Drugi fakt
  dubluje strumień albo odrzuca historię nową regułą.
- `MarkPersisted` nie zmienia `Version`. Ruch wersji przy czyszczeniu listy rozjeżdża następną
  oczekiwaną wersję.
- Po konflikcie egzemplarza się nie używa ponownie. `MarkPersisted` na odrzuconym egzemplarzu
  kasuje listę, której strumień nie przyjął.
- Nieznane zdarzenie w `Apply` jest wyjątkiem. `Result` albo `400` zamienia uszkodzony strumień
  w błąd użytkownika.
- Złamanie `IBusinessRule` przez `Check` jest `Invalid`. Inny rodzaj z `Check` udaje, że każda
  reguła jest tym samym statusem.
- Agregat nie woła `IEventStore`, EF, Kafki ani HTTP. Wołanie magazynu z bazy wiąże jądro z
  zapisem, którego jeszcze nie ma.
- Klasa agregatu nie nazywa się `News`, `Cv`, `Contact`, `Identity` ani `Learning`. Nazwa usługi
  nie mówi, co jest korzeniem spójności.
- `StudentProgress` nie dziedziczy `AggregateRoot`. Postęp studenta jako strumień miesza zwykły
  stan z historią, której ten byt nie ma.
- Blok kodu w lekcji nie dziedziczy `AggregateRoot`. Blok nie jest korzeniem wersji.
- `Probe` nie leży w projekcie jądra. Próbka w jądrze wciąga pole `Name` do wspólnego modelu.
- Jądro nie zna `Article`. Klasa artykułu w jądrze łamie granicę usług.

## Poza zakresem

- Zapis listy do pamięci i kod `stream.version.conflict` są w [08-strumien.md](08-strumien.md).
  Ten numer nie implementuje magazynu.
- Zapis do PostgreSQL jest w [09-persistence.md](09-persistence.md). Ten numer nie tworzy tabeli
  strumienia.
- Handler, który woła `Replay`, potem metodę, potem `Append`, potem `MarkPersisted`, jest w
  [10-cqrs.md](10-cqrs.md). Ten numer zostawia te kroki osobno.
- `Article` jest w [18-news.md](18-news.md). Ten numer używa `Probe`.
- Sekcje CV są w [20-cv.md](20-cv.md). Ten numer ich nie tworzy.
- `StudentInquiry` i `RecruiterInquiry` są w [21-kontakt.md](21-kontakt.md). Ten numer nie
  implementuje `inquiry.student.forbidden`.
- `StudentProgress` jako zwykły stan jest w [19-learning.md](19-learning.md). Ten numer nie robi
  z niego agregatu.
- Tłumaczenie `probe.name.blank` nie jest wymagane, bo to kod testu, nie kontrakt HTTP.

## Źródła

- [Event sourcing](https://martinfowler.com/eaaDev/EventSourcing.html). Wiążące jest to, że stan
  jest wynikiem zdarzeń, a odtworzenie nie dopisuje nowych. Dotyczy `Replay`, które woła tylko
  `Apply` i zostawia pustą listę. Ze źródła nie bierzemy Martena ani EventFlow jako silnika
  agregatu. Oba odpadły, bo jądro nie ciągnie API bazy, i nie bierzemy migawki ustawianej
  setterem bez zdarzenia.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Wiążący jest agregat jako granica
  spójności, nie jako nazwa systemu. Dotyczy zakazu klasy `News`, `Cv`, `Contact`, `Identity` i
  `Learning` oraz osobnych korzeni sekcji CV. Ze źródła nie bierzemy jednego worka na wszystkie
  sekcje i nie bierzemy klasy `Contact` z polem dyskryminującym.
- Evans, *Domain-Driven Design*. Wiążące są granica spójności i reguła, która broni niezmiennika
  wewnątrz agregatu, a nie między dwoma korzeniami. Dotyczy `IBusinessRule`, braku transakcji
  między `Skill` i `Project` oraz tego, że `StudentProgress` i blok kodu w lekcji nie są
  korzeniami. Ze książki nie bierzemy nazwania agregatu tak jak modułu. Nie ma stabilnego URL
  tego wydania.
- Vernon, *Implementing Domain-Driven Design*. Wiążące jest stosowanie zdarzeń do zmiany stanu i
  trzymanie niezatwierdzonych faktów do czasu zapisu. Dotyczy `Apply`, `AddDomainEvent` i
  `MarkPersisted` bez ruchu wersji. Ze książki nie bierzemy publikowania
  `kernel.probe-created.v1` z `Contracts` i nie bierzemy silnika, który zastępuje
  `AggregateRoot`. Nie ma stabilnego URL tego wydania.
- [Explicit event names](https://martinfowler.com/articles/201701-event-driven.html). Wiążące
  jest branie nazwy z atrybutu, nie z klasy. Dotyczy `ProbeCreated` i
  `[EventName("kernel.probe-created.v1")]`. Ze źródła nie bierzemy pełnego URI jako nazwy próbki
  i nie bierzemy wysłania tej nazwy na szynę. To nazwa wyłącznie testu.
- [Result vs
  exception](https://enterprisecraftsmanship.com/posts/functional-c-sharp-handling-failures-input-errors/).
  Wiążące jest to, że pusta nazwa zostaje `Result`, a uszkodzony strumień zostaje wyjątkiem.
  Dotyczy `Check` z `Invalid` oraz `InvalidOperationException` na nieznanym zdarzeniu w `Apply`.
  Ze źródła nie bierzemy `DomainException` i nie bierzemy zamiany uszkodzonego strumienia na
  `400`.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: usługa nie nazywa
  jednego worka klasą o nazwie całego systemu. Dotyczy `Article` zamiast `News` i sekcji CV
  zamiast klasy `Cv`. Z tego repozytorium nie bierzemy MediatR ani IntegrationEventLogEF. Nie
  bierzemy też agregatu produkcyjnego w tym numerze, zostaje `Probe`.
- [xUnit](https://xunit.net/). Wiążące jest `[Fact]` i jeden powód padnięcia. Dotyczy
  `Replay_leaves_uncommitted_list_empty`. Ze źródła nie bierzemy asercji treści `Name` ani
  asercji `probe.name.blank` w tej metodzie. NBomber tu nie występuje i kontener nie jest
  potrzebny.

## Gotowe gdy

- `Replay` historii jednoelementowej zostawia pustą listę niezatwierdzonych i wersję `1`.
- `Create` z samymi białymi znakami zwraca `Invalid` i `probe.name.blank`, co widać w kodzie
  `Probe`, nawet jeśli ten fakt pilnuje tylko listy.
- W `Create` nie ma przypisania do pola stanu.
- `MarkPersisted` czyści listę i nie rusza wersji.
- W jądrze nie ma klasy `Article` ani klasy `News`.
- Komenda z sekcji testów kończy się kodem zero.
- `AggregateRoot` nie referencjonuje `JJDevHub.EventStore`, bo ten projekt powstaje w następnym
  numerze.
