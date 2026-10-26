# 05. Jądro

Poprzedni numer, [OpenBao](04-openbao.md), czyta sekret przez port i nie trzyma wartości w
gicie. Ten numer stawia `JJDevHub.Shared.Kernel`: `Result`, `Result<T>`, `ResultError`, kody,
`Entity`, `ValueObject` i użycie `TimeProvider`. Następny numer, [zdarzenie](06-zdarzenie.md),
dokłada kontrakt faktu i atrybut nazwy. Po tym numerze da się zwrócić oczekiwany błąd bez
wyjątku i porównać obiekt wartości. Nie da się jeszcze zapisać `Article` ani strumienia. Jądro
nie zna Identity, News, Learning, Cv ani Contact. Słownik kodów jest w [README.md](README.md).

Scenariusz, który bez tego numeru się psuje, jest pierwszym odrzuceniem pustego tytułu. Jedna
usługa rzuca wyjątek, brzeg HTTP zamienia go w `500`, a klient widzi awarię procesu, choć proces
działa. Druga usługa zwraca zdanie po polsku. Klient z `Accept-Language` angielskim dostaje zły
język, a test porównuje tekst, który refaktor zmieni. Slug w News porównuje się inaczej niż slug
w Learning, więc słownik i test równości kłamią. Reguła „publikacja nie jest w przyszłości” woła
`DateTimeOffset.UtcNow` i na maszynie CI bierze zegar runnera. Port sekretów zostaje przy
rekordzie `SecretRead`, choć rodzaj braku i odmowy jest już potrzebny na brzegu.

Jądro niesie rodzaj i stabilny kod. Zdanie powstanie później, w zasobach `pl` i `en`. `Entity` i
`ValueObject` są jedne dla pięciu usług. Zegar jest `TimeProvider` z BCL. Ten numer zamyka też
wynik portu sekretów. `ISecretReader.ReadAsync` zaczyna zwracać `Result<string>`. Kody
`secret.path.missing` i `secret.path.forbidden` są rodzajem `NotFound` i `Forbidden`. W jądrze
nie ma pliku `Article.cs`, `Account.cs`, `Skill.cs` ani `StudentInquiry.cs`.

## Po co

Każda usługa będzie odrzucać pusty tytuł, brak wiersza, konflikt wersji i brak roli. Jeśli zrobi
to wyjątkiem, brzeg HTTP zamieni błąd użytkownika w `500`. Jeśli zrobi to zdaniem po polsku,
klient angielski albo odwrotnie dostanie zły język, a test będzie porównywał tekst. Jądro ma
nieść rodzaj i stabilny kod. Zdanie powstanie później, w zasobach `pl` i `en`, z
`Accept-Language`. Tłumaczenie nie leży w jądrze. `ProblemDetails` i zasoby językowe są w
[11-walidacja.md](11-walidacja.md). Tu jest tylko rodzaj, który wybierze status, i kod, który
wejdzie do pola `type`.

Sam kod `article.title.blank` nie mówi brzegowi, czy to `400`, `404`, `409` czy `403`. Sam
rodzaj bez kodu nie pozwala klientowi rozgałęzić logiki bez porównywania przetłumaczonego
zdania. Dlatego `ResultError` ma i `Kind`, i `Code`. Jądro nie trzyma stałych
`article.title.blank` ani `inquiry.student.forbidden`. Te kody należą do usług i powstaną razem
z agregatami w [18-news.md](18-news.md) i [21-kontakt.md](21-kontakt.md). Jądro sprawdza format:
niepusty, małe litery, kropki, bez spacji. Zły format jest wyjątkiem programisty, zanim kod
wyjdzie poza proces.

`Entity` i `ValueObject` mają być jedne dla pięciu usług. Inaczej slug w News i slug w Learning
porównują się inaczej, a test równości kłamie. Równość encji jest po `Id` i typie. Równość
obiektu wartości jest po sekwencji z `GetEqualityComponents`. Kolejność składowych ma znaczenie.
Baza nie jest tu istotna: równość ma działać bez EF. `Core` przyszłej usługi będzie
referencjonował tylko ten projekt spośród infrastruktury. Nie zaciągnie stąd ASP.NET, Kafki ani
OpenBao.

Zegar ma być `TimeProvider` z BCL. `DateTimeOffset.UtcNow` w środku reguły uniemożliwia fakt,
który sprawdza datę publikacji. Produkcja używa `TimeProvider.System`. Test używa
`FakeTimeProvider` z pakietu `Microsoft.Extensions.TimeProvider.Testing` na licencji MIT. Pakiet
testowy nie wchodzi do projektu jądra. Własny `IClock` nie powstaje, bo zdublowałby typ, który
już jest w runtime. Tam, gdzie czas nie wpływa na wynik, parametru nie ma.

Ten numer zamyka też wynik portu sekretów. [04-openbao.md](04-openbao.md) zwraca rekord
`SecretRead`, bo `Result` jeszcze nie istniał. Tutaj `ISecretReader.ReadAsync` zaczyna zwracać
`Result<string>`. Brak ścieżki to `ResultError.NotFound("secret.path.missing")`. Odmowa to
`ResultError.Forbidden("secret.path.forbidden")`. Rekord `SecretRead` znika, gdy nic go już nie
zwraca. Fakt OpenBao z numeru 04 nadal sprawdza równość wartości. Mapowanie dochodzi w
adapterze, bez zmiany obrazu kontenera. OpenBao jako kontener zostaje w numerze 04. Ten numer
zmienia tylko typ wyniku portu.

## Dlaczego ta technologia

### `Result<T>`

Typ wartościowy z `IsSuccess`, wartością i `ResultError`. `Ok` i `Fail` są metodami fabryki.
Osobny `Result` bez wartości służy komendzie, która nic nie zwraca. Leży w
`src/shared/JJDevHub.Shared.Kernel`, w plikach `Result.cs` i `ResultOfT.cs`. Nie jest pakietem
NuGet. Projekt jest na `net11.0`, bez `PackageReference`, bez referencji do ASP.NET, EF, Kafki,
OpenBao i projektów usług. `Fail` wymaga rodzaju innego niż `None`. Przy sukcesie `Error` ma
rodzaj `None`. Getter wartości przy porażce rzuca `InvalidOperationException`. Przy sukcesie
wartość jest dostępna.

Pusty tytuł artykułu jest wynikiem reguły, nie awarią procesu. Wyjątek miesza go z zerwanym
połączeniem do PostgreSQL. Handler ma zwrócić jedno albo drugie, a brzeg ma wiedzieć, które jest
które. Oczekiwana porażka nie jest wyjątkiem. Wyjątek zostaje dla IO, składu hosta i dla błędu
programisty: pusty kod, odczyt wartości na porażce. Komenda, która nic nie zwraca, i tak zwraca
`Result`, bo „nic” przy sukcesie i kod przy porażce nie mieszczą się w `void`. Zignorowanie
wyniku jest łatwe. Dlatego wartość na porażce nie jest dostępna: kto ją czyta, dostaje wyjątek
programisty, a nie cichy default.

Konkret JJDevHub: odrzucenie pustego tytułu, brak wiersza odczytu, konflikt wersji strumienia i
brak roli mają wrócić jako `Result`, każdy z innym rodzajem. Tego numeru nie ma jeszcze
`Article`, więc fakt nie woła tytułu. Mechanizm widać na typie wyniku i na kodach sekretu, które
słownik już wymienia. `secret.path.missing` jest `NotFound`, nie wyjątkiem sieci.
`secret.path.forbidden` jest `Forbidden`, nie `500`. Zerwane połączenie do OpenBao zostaje
wyjątkiem, tak jak ustalił numer 04. Jądro nie zamienia IO w `Result`.

Odpadł wyjątek domenowy jako jedyny kanał błędu oczekiwanego. Łapie go middleware i bez osobnej
listy typów robi z niego `500`. Lista typów wyjątków na brzegu i tak duplikowałaby rodzaje,
które `ResultErrorKind` już ma. Każda nowa usługa dopisywałaby własny `catch`. Test porównywałby
typ CLR albo komunikat. Nazwa wyjątku psuje klienta przy refaktorze tak samo jak zdanie.
`Result` zostawia w procesie wartość albo błąd i nie używa stosu jako sterowania.

Odpadł pakiet FluentResults. Jest na MIT, ale wprowadza własny model błędu do każdego `Core`, a
kod ma zostać zwykłym łańcuchem w typie, który mieści się w jednym projekcie bez zależności.
FluentResults odpada. Własny model pakietu trzeba by mapować na pięć rodzajów albo przyjąć jego
taksonomię. Jądro ma być zerem zależności, żeby `Core` usługi referencjonował tylko ten projekt
spośród infrastruktury. Pakiet w `Directory.Packages.props` pod wynik oznaczałby, że format kodu
żyje poza repozytorium. Zostaje typ w `JJDevHub.Shared.Kernel`.

Koszt: każda metoda domenowa, która może odrzucić dane, zwraca `Result` zamiast `void`. Łatwo
zignorować wynik. Getter `Value` przy porażce rzuca `InvalidOperationException` i to jest błąd
programisty, nie błąd użytkownika. Caller, który sprawdza `IsSuccess` i potem czyta wartość,
jest poprawny. Caller, który czyta wartość od razu, wybucha w procesie, zanim zły stan wyjdzie
na brzeg jako `200` z pustą treścią. Porażka bez rodzaju `None` jest pilnowana w `Fail`. Sukces
nie niesie kodu domenowego.

### `ResultError` i pięć rodzajów

Rekord `ResultError` ma pola `Kind` i `Code`. `ResultErrorKind` ma dokładnie pięć wartości:
`None`, `Invalid`, `NotFound`, `Conflict`, `Forbidden`. `None` występuje tylko przy sukcesie i
ma pusty kod. Jest statycznym polem o pustym kodzie. Fabryki `Invalid`, `NotFound`, `Conflict` i
`Forbidden` biorą kod. Cztery porażki, piąty rodzaj na sukces. Pliki to `ResultError.cs` i
`ResultErrorKind.cs`. Fabryka porażki odrzuca kod, który jest pusty, ma spację albo wielką
literę, wyjątkiem `ArgumentException`.

Sam kod nie wybiera statusu HTTP. Sam rodzaj nie rozgałęzia klienta. Brzeg w numerze walidacji
weźmie rodzaj i złoży status, a kod wstawi do pola `type`. `404` na projekcji i `404` na ukrytej
treści mają powstać na brzegu, z tego samego rodzaju `NotFound` albo z innego, jeśli reguła tak
powie, ale nie z liczby zapisanej w `Core`. `Core` nie referencjonuje ASP.NET. Jądro tym
bardziej. Wewnętrzny `404` w typie wyniku związałby domenę z HTTP i z jednym znaczeniem braku.

Konkret: pusty tytuł, gdy kod powstanie, będzie `Invalid`. Brak ścieżki sekretu jest `NotFound`
i `secret.path.missing`. Odmowa ścieżki jest `Forbidden` i `secret.path.forbidden`. Konflikt
wersji strumienia, który postawi magazyn w [08-strumien.md](08-strumien.md), będzie `Conflict` i
`stream.version.conflict`. Jądro tego kodu strumienia nie definiuje jako stałej. Daje rodzaj
`Conflict`, z którego magazyn skorzysta. Brak roli przy zapytaniu studenta, gdy agregat
powstanie, może być `Forbidden`. Rodzaj jest wspólny. Kod jest lokalny dla usługi. `None` nie
niesie kodu `article.title.blank` ani żadnego innego.

Odpadła jedna flaga `IsSuccess` i komunikat. Komunikat jest w jednym języku i nie rozróżnia
braku od odmowy. Klient, który porównuje zdanie, psuje się przy zmianie tłumaczenia. Flaga bez
rodzaju zmusza brzeg do zgadywania statusu. Wszystko, co nie jest sukcesem, stałoby się `400`
albo wszystko stałoby się `500`. Pięć rodzajów jest krótką listą właśnie po to, żeby to
zgadywanie zniknęło. Nowy rodzaj „na jeden status” nie wchodzi do wyliczenia bez świadomej
zmiany kontraktu.

Odpadły kody statusu HTTP wewnątrz `Core`. `Core` nie referencjonuje ASP.NET, a `404` na
projekcji i `404` na ukrytej treści mają powstać na brzegu. Liczba `409` w jądrze nie mówi, czy
to reguła biznesowa, czy wersja strumienia, dopóki nie ma kodu. Rodzaj `Conflict` plus kod to
rozróżniają bez wciągania HTTP. Test jądra nie podnosi hosta i nie patrzy na status. Patrzenie
na `409` w `ResultError` związałoby fakt równości obiektu wartości z ASP.NET, którego projekt
nie ma.

Koszt: pięć rodzajów nie opisuje `428` ani `412`. Te statusy dotyczą nagłówka `If-Match` i
zostają w `Api`, w [11-walidacja.md](11-walidacja.md). Rodzaj `Conflict` jest dla reguły i dla
wersji strumienia, nie dla każdego `409` w HTTP. Kto zmapuje każdy `409` na `Conflict`, wciągnie
do domeny sytuacje nagłówka, których agregat nie zna. Kto doda szósty rodzaj „bo HTTP ma więcej
statusów”, przeniesie brzeg do jądra. Lista zostaje zamknięta na tych pięciu wartościach.
Warunek „gotowe” tego pilnuje.

### Kody błędów

Łańcuch ma postać `segment.element.powod`, małymi literami, segmenty rozdzielone kropką. Jądro
nie trzyma stałych `article.title.blank` ani `inquiry.student.forbidden`. Te kody należą do
usług. Jądro sprawdza tylko, że kod nie jest pusty i nie zawiera spacji ani wielkich liter.
Pusty kod przy porażce jest wyjątkiem programisty. Fabryka `ResultError` robi to, zanim kod
wyjdzie poza proces. `None` nie niesie kodu domenowego: pusty łańcuch przy sukcesie jest
poprawny, pusty łańcuch przy porażce nie jest.

Nazwa wyjątku albo zdanie polskie zmienia się przy refaktorze i psuje klienta. Kod zostaje, gdy
zmieni się klasa albo tłumaczenie. Zdanie „Tytuł jest pusty” jako kontrakt JSON wiąże klienta z
językiem. Nazwa typu CLR wyjątku jako pole `type` wiąże klienta z refaktorem przestrzeni nazw.
Jedno i drugie jest niestabilne. Kod `secret.path.missing` da się wpisać do słownika
[README.md](README.md) i do zasobów `pl` oraz `en` bez zmiany typu C#. Jądro nie tłumaczy. Nie
czyta `Accept-Language`. Nie składa `ProblemDetails`.

Konkret formatu widać na kodach, które ten numer sam wprowadza przy porcie:
`secret.path.missing` i `secret.path.forbidden`. Trzy segmenty, małe litery, kropki, bez spacji.
Kod `Secret.Path.Missing` nie przechodzi fabryki. Kod `secret path missing` nie przechodzi.
Pusty string nie przechodzi. Dzięki temu zły format nie dochodzi do JSON-a, gdzie klient
zacząłby na nim polegać. Kody artykułu i zapytania studenta jeszcze nie powstają. Gdy powstaną,
przejdą przez tę samą fabrykę albo wcale nie powstaną jako `ResultError`.

Odpadło zdanie „Tytuł jest pusty” jako kontrakt JSON. Odpadła nazwa typu CLR wyjątku jako pole
`type`. Jedno i drugie jest niestabilne i związane z językiem albo z refaktorem. Test, który
porównuje polskie zdanie, jest czerwony po poprawce stylistycznej, choć reguła działa. Test,
który porównuje kod, zostaje zielony, gdy zmieni się klasa wyjątku, której i tak nie ma. RFC
9457 mówi, dokąd taki kod trafi na brzegu. Jądro cytuje ten kierunek i nie implementuje ciała
problemu.

Koszt: każdy nowy kod trzeba dopisać do słownika w [README.md](README.md) i do zasobów tłumaczeń
w numerze walidacji. Kod bez wpisu w słowniku jest długiem tamtego numeru, nie powodem, żeby
jądro trzymało katalog wszystkich usług. Zły format wykrywa fabryka. Nieznany, lecz poprawny
składniowo kod przejdzie jądro i wypadnie przy przeglądzie słownika. To jest podział: format tu,
znaczenie w usłudze, zdanie na brzegu. Trzymanie stałych wszystkich kodów w jądrze wciągnęłoby
`article` i `inquiry` do projektu, który nie zna usług.

### `Entity` i `ValueObject`

`Entity` ma `Guid Id` ustawiany w konstruktorze chronionym i równość po `Id` oraz typie. `Id` ma
prywatny setter. `Entity` jest klasą abstrakcyjną. `Id` równe `Guid.Empty` nie jest równe innemu
pustemu egzemplarzowi innego typu: typ wchodzi do równości, nie samo puste `Guid`. `ValueObject`
jest abstrakcyjny i równa się po sekwencji z `GetEqualityComponents`. Implementuje `Equals`,
`GetHashCode` i operatory na podstawie tej sekwencji. Kolejność składowych ma znaczenie. Oba
typy są w jądrze. Nie mają atrybutów mapowania. Podklasa nie nadpisuje `Equals` po swojemu.

Slug, zakres dat i identyfikator agregatu powtarzają się w pięciu usługach. Równość napisana w
każdym z nich inaczej psuje słownik i test. Dwa slugi o tych samych znakach mają być równe
niezależnie od tego, czy powstaną w News, czy w Learning. Dwa zakresy dat mają ten sam kod
skrótu, gdy składowe są równe i w tej samej kolejności. Baza nie jest tu istotna. Równość ma
działać bez EF, bez połączenia i bez kontenera. Fakt tego numeru właśnie to sprawdza, na
podklasie testowej, nie na typie usługi.

Konkret testu: `ProbeValue` żyje tylko w `tests/JJDevHub.Shared.Kernel.Tests/ProbeValue.cs`. Dwa
egzemplarze z tą samą parą składowych są równe i mają ten sam kod skrótu. Trzeci, z inną drugą
składową, nie wchodzi do asercji tego faktu. Służyłby innemu powodowi padnięcia, czyli fałszywej
równości różnych składowych. Tego faktu się nie miesza. `ProbeValue` nie jest `Article` i nie
jest slugiem produkcyjnym. Chroni mechanikę przed wciągnięciem nazwy z słownika usług. W jądrze
nie ma klasy o nazwie `News`, `Cv`, `Contact`, `Article`, `Account`, `Lesson`.

Odpadły publiczne settery i `string` tam, gdzie ma być slug. Każdy caller wstawia spację i inną
wielkość liter. Składanie równości na gołym stringu rozjeżdża się między usługami: jedna
przycina, druga nie, trzecia porównuje bez kultury. Obiekt wartości zamyka składowe w jednym
`Equals`. Encja zamyka tożsamość w `Id`. Publiczny setter `Id` pozwoliłby podmienić tożsamość po
zbudowaniu i złamać równość, na której oprze się słownik w pamięci. Setter zostaje prywatny.

Odpadła bazowa klasa encji z Entity Framework i adnotacje kolumn. `Core` nie może jej
referencjonować, a jądro tym bardziej. Atrybut kolumny w `Entity` związałby równość z tabelą,
której ten numer nie tworzy. Mapowanie dojdzie przy trwałym strumieniu, poza jądrem. Dziś
`Entity` nie wie, czy `Id` jest kolumną. Wie, że dwa egzemplarze tego samego typu z tym samym
`Id` są tą samą tożsamością. `Guid.Empty` w dwóch różnych typach to dwie różne, puste
tożsamości, nie jedna wspólna.

Koszt: `ValueObject` wymaga implementacji składowych. Zapomnienie składowej daje fałszywą
równość. Dlatego składowe są abstrakcyjne, a równość i kod skrótu są w bazie, nie w podklasie.
Podklasa nie nadpisuje `Equals` po swojemu. Własne `Equals` w podklasie potrafi zgodzić się z
operatorem `==` albo nie, i kod skrótu wtedy kłamie w słowniku. Baza trzyma jedną implementację.
Kolejność składowych ma znaczenie, więc zamiana pól w `GetEqualityComponents` zmienia równość.
To jest widoczne w teście, gdy ktoś porówna parę w odwrotnej kolejności. Ten fakt pilnuje
zgodności równych par, nie wszystkich permutacji.

### `TimeProvider`

Metody jądra, które potrzebują czasu, przyjmują `TimeProvider` z BCL albo wołają go przez
parametr. Produkcja używa `TimeProvider.System`. Test używa `FakeTimeProvider` z pakietu
`Microsoft.Extensions.TimeProvider.Testing` na licencji MIT. Jądro nie definiuje własnego
`IClock`. Nie ma klasy zegara. W teście jądra, tam gdzie przykład potrzebuje czasu, parametr to
`TimeProvider`. Pakiet jest w `Directory.Packages.props` tylko dla projektu testu. Produkcyjny
kod jądra go nie referencjonuje. `DateTimeOffset.UtcNow` nie występuje w `Entity` ani w
`ValueObject`.

Reguła „data końca jest po dacie startu” da się sprawdzić na danych. Reguła „publikacja nie jest
w przyszłości” wymaga sterowanego zegara. `UtcNow` w środku `Entity` bierze zegar maszyny CI.
Fakt, który chce zobaczyć publikację „jutro”, nie potrafi cofnąć zegara procesu.
`FakeTimeProvider` potrafi. Dlatego zależność testowa jest w projekcie testu, a sygnatura
produkcyjna przyjmuje abstrakcję BCL, nie typ z pakietu testowego. Skład hosta przekaże
`TimeProvider.System`. Test przesunie fałszywy zegar. Metoda, której wynik od czasu nie zależy,
parametru nie dostaje i nie udaje, że czas jest częścią każdej reguły.

Konkret pojawi się przy dacie publikacji artykułu i przy zakresie dat w CV albo w kursie, gdy te
typy powstaną. W tym numerze nie ma tych typów. Jest zasada miejsca: czas wchodzi parametrem,
nie wywołaniem statycznym w bazie encji. Port sekretów czasu nie potrzebuje. Równość
`ProbeValue` czasu nie potrzebuje. Dlatego fakt równości nie ustawia zegara. Wstawienie `UtcNow`
do `Equals` związałoby równość z chwilą uruchomienia i fakt byłby czerwony albo, co gorsza,
zielony tylko przez przypadek tej samej milisekundy.

Odpadł własny interfejs `IClock` z jedną metodą `Now`. Duplikuje `TimeProvider`, który już jest
w runtime. Drugi interfejs trzeba adapterem owijać na `TimeProvider` albo odwrotnie, a test i
produkcja rozjeżdżają się o jeden typ. `TimeProvider` nie jest owijany drugim interfejsem. Kto
doda `IClock`, zostanie z dwoma zegarami i z pokusą, żeby w `Entity` wołać własny, a w teście
podstawiać BCL. Zostaje jeden typ z biblioteki standardowej.

Odpadło wywołanie `DateTimeOffset.UtcNow` w `ValueObject` albo w `Entity`. Statyczne „teraz” nie
jest składową wartości i nie jest tożsamością. W regule publikacji jest wejściem, które caller
ma podać. W konstruktorze encji bez potrzeby czasu jest zbędne i wiąże tworzenie obiektu z
zegarem. Warunek „gotowe” zabrania tego wywołania w obu typach. Przegląd plików `Entity.cs` i
`ValueObject.cs` to widzi. Fakt równości tego nie asercjonuje, żeby nie mieszać powodów
padnięcia.

Koszt: sygnatura metody niesie `TimeProvider` tam, gdzie czas wpływa na wynik. Tam, gdzie nie
wpływa, parametru nie ma. Dłuższa sygnatura jest widoczna i tego właśnie chcemy: zależność od
zegara nie chowa się w statycznym wywołaniu. Pakiet testowy nie wchodzi do projektu jądra, tylko
do projektu testu. Wpis w `Directory.Packages.props` bez ograniczenia do testu wciągnąłby
MIT-owy pakiet testowy do produkcyjnego jądra i złamałby „kompiluje się bez pakietów
infrastruktury” w duchu zależności testowej w kodzie usług. Warunek mówi wprost: pakiet czasu
jest tylko dla projektu testu.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Shared.Kernel/Result.cs` | sukces albo błąd bez wartości |
| `src/shared/JJDevHub.Shared.Kernel/ResultOfT.cs` | `Result<T>` |
| `src/shared/JJDevHub.Shared.Kernel/ResultError.cs` | rodzaj i kod, fabryki czterech porażek |
| `src/shared/JJDevHub.Shared.Kernel/ResultErrorKind.cs` | `None`, `Invalid`, `NotFound`, `Conflict`, `Forbidden` |
| `src/shared/JJDevHub.Shared.Kernel/Entity.cs` | `Id` i równość po tożsamości |
| `src/shared/JJDevHub.Shared.Kernel/ValueObject.cs` | równość po składowych |
| `src/shared/JJDevHub.Secrets/ISecretReader.cs` | po tym numerze zwraca `Result<string>` |
| `tests/JJDevHub.Shared.Kernel.Tests/ValueObjectEqualityTests.cs` | fakt równości obiektu wartości |
| `tests/JJDevHub.Shared.Kernel.Tests/ProbeValue.cs` | podklasa testowa, nie typ usługi |

W jądrze nie ma pliku `Article.cs`, `Account.cs`, `Skill.cs` ani `StudentInquiry.cs`.
`ProbeValue` żyje tylko w teście. Jądro nie referencjonuje projektu usługi.

## Plan

### 1. Projekt

Utwórz `src/shared/JJDevHub.Shared.Kernel` na `net11.0`. Bez `PackageReference`. Bez referencji
do ASP.NET, EF, Kafki, OpenBao i projektów usług. Dopnij go do solution.

### 2. Wynik

Dodaj `ResultErrorKind` i `ResultError`. `None` jest statycznym polem o pustym kodzie. Fabryka
porażki odrzuca kod, który jest pusty, ma spację albo wielką literę, wyjątkiem
`ArgumentException`. Dodaj `Result` i `Result<T>`. `Fail` wymaga rodzaju innego niż `None`.
Getter wartości przy porażce rzuca `InvalidOperationException`. Przy sukcesie `Error` ma rodzaj
`None`.

### 3. Tożsamość i wartość

`Entity` jest klasą abstrakcyjną. `Id` ma prywatny setter. Równość: ten sam typ i ten sam `Id`.
`Id` równe `Guid.Empty` nie jest równe innemu pustemu egzemplarzowi innego typu. `ValueObject`
implementuje `Equals`, `GetHashCode` i operatory na podstawie `GetEqualityComponents`. Kolejność
składowych ma znaczenie.

### 4. Zegar

Nie dodawaj klasy zegara. W teście jądra, tam gdzie przykład potrzebuje czasu, parametr to
`TimeProvider`. Do projektu testu dopisz `Microsoft.Extensions.TimeProvider.Testing` w
`Directory.Packages.props`. Produkcyjny kod jądra nie referencjonuje tego pakietu.

### 5. Port sekretów

Zmień `ISecretReader.ReadAsync` tak, by zwracał `Task<Result<string>>`. Brak ścieżki to
`ResultError.NotFound("secret.path.missing")`. Odmowa to
`ResultError.Forbidden("secret.path.forbidden")`. Usuń rekord `SecretRead`, gdy nic go już nie
zwraca. Fakt OpenBao z numeru 04 nadal sprawdza równość wartości. Dopisz mapowanie w adapterze,
bez zmiany obrazu kontenera.

### Co jest do czego

`Result<T>` woła metoda domenowa i port, który zna oczekiwany brak. Niesie wartość albo kod. Nie
niesie zdania. Gdy typu nie ma, caller wraca do wyjątku albo do gołego stringa. Brzeg nie
odróżnia pustego tytułu od zerwanego PostgreSQL. Getter, który przy porażce zwraca default,
wysyła pustą wartość jako sukces.

`Result` bez parametru typu woła komenda, która nic nie zwraca. Niesie sam rodzaj i kod. Gdy
zostaje tylko `Result<T>`, komenda bez wartości wymyśla sztuczne `bool` albo `Unit`. Gdy zostaje
`void`, porażki nie ma jak zwrócić bez wyjątku.

`ResultError` woła fabryka wyniku i brzeg HTTP w numerze walidacji. Rodzaj wybiera status. Kod
wchodzi do pola `type`. Gdy rekordu nie ma, zostaje flaga i komunikat. Klient porównuje zdanie.
`None` z niepustym kodem kłamie, że sukces niesie błąd. Porażka z pustym kodem przechodzi, jeśli
fabryka jej nie odrzuci.

`Entity` woła przyszły `AggregateRoot` i każda tożsamość ze strumieniem. W tym numerze nie ma
jeszcze agregatu. Jest baza pod `Id`. Gdy klasy nie ma, każda usługa pisze własną równość po
`Guid` i własne settery. `Guid.Empty` w dwóch typach zlewa się w jedną tożsamość, jeśli typ nie
wchodzi do `Equals`.

`ValueObject` woła slug, zakres dat i inne typy bez tożsamości. Test woła `ProbeValue`, żeby nie
wciągać `Article`. Gdy bazy nie ma, równość slugów rozjeżdża się między News i Learning. Gdy
podklasa nadpisuje `Equals` po swojemu, operator i kod skrótu kłamią. Gdy zabraknie składowej w
sekwencji, różne wartości wyglądają na równe.

`TimeProvider` woła kod, który porównuje chwilę z zegarem. Test przesuwa `FakeTimeProvider`.
Produkcja przekazuje `TimeProvider.System` ze składu hosta. Gdy parametru nie ma, a w środku
jest `UtcNow`, fakt daty publikacji zależy od zegara CI. Gdy powstanie `IClock`, są dwa zegary.
Pakiet testowy w projekcie jądra wciąga zależność testu do produkcji.

`ISecretReader` po tej zmianie woła ten sam adapter co w numerze 04. Zwraca kody, które słownik
już wymienia. Gdy nadal zwraca `SecretRead`, brzeg ma dwa modele błędu. Gdy `SecretRead` zostaje
w kompilacji po przepięciu, caller nie wie, który typ jest kontraktem. Obraz kontenera się nie
zmienia. Zmienia się mapowanie 404 i 403 na `NotFound` i `Forbidden`.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]`. Nie ma cechy integracyjnej ani
wydajnościowej. Powód padnięcia jest jeden: dwa obiekty wartości o tych samych składowych nie są
równe. NBomber jest w [22-testy.md](22-testy.md) i tu nie występuje. Kontener nie jest
potrzebny. Docker nie wchodzi do projektu jądra ani do tego faktu. Cecha `Category=Integration`
związałaby równość w pamięci z filtrem, który ma omijać kontenery.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | dwa egzemplarze `ProbeValue` z tą samą parą składowych, trzeci z inną drugą składową |
| Działanie (act) | `Equals`, operator `==` i `GetHashCode` na pierwszych dwóch |
| Sprawdzenie (assert) | pierwsze dwa są równe i mają ten sam kod skrótu |

Nazwa metody: `Value_object_equal_when_components_equal`.

```text
dotnet test tests/JJDevHub.Shared.Kernel.Tests/JJDevHub.Shared.Kernel.Tests.csproj --filter "FullyQualifiedName~Value_object_equal_when_components_equal"
```

Trzeci egzemplarz nie wchodzi do asercji tego faktu. Służyłby innemu powodowi padnięcia, czyli
fałszywej równości różnych składowych. Tego faktu nie mieszaj. Getter wartości na porażce i
format kodu są w zasadach oraz w „Gotowe gdy”, nie w tym fakcie.

Przygotowanie nie otwiera bazy i nie ustawia `TimeProvider`. `ProbeValue` jest w projekcie
testu, nie w jądrze. Działanie woła równość, operator i kod skrótu, bo rozjazd tych trzech jest
tym, co psuje słownik. Sprawdzenie patrzy tylko na pierwsze dwa egzemplarze. Dopisanie asercji,
że trzeci jest różny, jest osobnym powodem i do tej metody nie wchodzi. Format kodu z wielką
literą jest warunkiem ukończenia: fabryka go nie przepuszcza. Nie jest czerwoną linijką tego
faktu.

Komenda z filtrem po nazwie metody jest bramką. Fakt ma przejść także w pętli bez cech
integracyjnych i wydajnościowych, bo takich cech nie ma. NBomber nie dostaje tu scenariusza
równości. Równość albo jest, albo jej nie ma. Próg czasu nic by nie powiedział o `GetHashCode`.

## Zasady

- Jądro nie referencjonuje projektu usługi ani MediatR, EF, Kafki, ASP.NET, Mongo, Redis. Taka
  referencja wciąga jedną usługę albo infrastrukturę do typu, który mają dostać wszystkie
  `Core`.
- Nie ma klasy o nazwie `News`, `Cv`, `Contact`, `Article`, `Account`, `Lesson`. Nazwa usługi w
  jądrze miesza wspólny typ z bytem jednej usługi.
- Porażka oczekiwana nie jest wyjątkiem. Wyjątek na pusty tytuł wychodzi na brzeg jako `500`.
- Wyjątek zostaje dla IO, składu hosta i dla błędu programisty: pusty kod, odczyt wartości na
  porażce. Zamiana IO na `Result` kłamie, że zerwane połączenie jest błędem użytkownika.
- Kod jest małymi literami, z kropkami, bez spacji. Wielka litera albo spacja przechodzi do
  klienta i psuje kontrakt przy pierwszej literówce.
- `None` nie niesie kodu domenowego. Kod przy sukcesie wygląda jak błąd w odpowiedzi `200`.
- `Core` przyszłej usługi będzie referencjonował tylko ten projekt spośród infrastruktury. Drugi
  projekt infrastruktury w `Core` omija granicę jądra.
- `Equals` dla `ValueObject` nie jest nadpisywane w podklasie. Własne `Equals` rozjeżdża
  operator i kod skrótu.
- `TimeProvider` nie jest owijany drugim interfejsem. `IClock` zostawia dwa zegary.
- Tłumaczenie kodu nie leży w jądrze. Zdanie w jądrze wiąże wszystkie usługi z jednym językiem.
- Pakiet FluentResults, MediatR i AutoMapper nie wchodzą do csproj. Każdy z nich dokłada model,
  którego jądro nie używa, i zależność, której projekt ma nie mieć.

## Poza zakresem

- Atrybut nazwy zdarzenia i `IDomainEvent` są w [06-zdarzenie.md](06-zdarzenie.md). Ten numer
  nie nazywa faktu.
- `AggregateRoot`, `Apply` i `IBusinessRule` są w [07-agregat.md](07-agregat.md). Ten numer nie
  zmienia pól agregatu.
- Konflikt `stream.version.conflict` stawia magazyn w [08-strumien.md](08-strumien.md). Ten
  numer daje tylko rodzaj `Conflict`.
- `ProblemDetails` i zasoby językowe są w [11-walidacja.md](11-walidacja.md). Ten numer nie
  tłumaczy kodu.
- Kody `article.title.blank` i `inquiry.student.forbidden` powstają razem z agregatami w
  [18-news.md](18-news.md) i [21-kontakt.md](21-kontakt.md). Jądro ich nie trzyma.
- OpenBao jako kontener zostaje w [04-openbao.md](04-openbao.md). Ten numer zmienia tylko typ
  wyniku portu.
- Test wydajnościowy jest w [22-testy.md](22-testy.md). Ten numer nie mierzy czasu równości.

## Źródła

- [Functional C# and
  failure](https://enterprisecraftsmanship.com/posts/functional-c-sharp-handling-failures-input-errors/).
  Wiążące jest rozdzielenie oczekiwanego błędu, który wraca jako wynik, od awarii, która zostaje
  wyjątkiem. Dotyczy `Result`, `Result<T>` i gettera wartości, który przy porażce rzuca
  `InvalidOperationException`. Ze źródła nie bierzemy pakietu FluentResults ani wyjątku
  domenowego jako jedynego kanału, więc FluentResults odpada razem ze zdaniem dla użytkownika.
- [TimeProvider](https://learn.microsoft.com/dotnet/fundamentals/runtime-libraries/system-datetime-timeprovider).
  Wiążący jest zegar BCL i możliwość podmiany w teście bez własnego interfejsu. Dotyczy
  parametru `TimeProvider`, produkcji na `TimeProvider.System` i zakazu `DateTimeOffset.UtcNow`
  w `Entity` oraz w `ValueObject`. Ze źródła nie bierzemy `IClock`. Drugi interfejs duplikuje
  typ, który już jest w runtime.
- [FakeTimeProvider](https://learn.microsoft.com/dotnet/api/microsoft.extensions.time.testing.faketimeprovider).
  Wiążący jest pakiet testowy `Microsoft.Extensions.TimeProvider.Testing` na MIT. Dotyczy
  projektu testu i wpisu w `Directory.Packages.props` tylko dla tego projektu. Ze źródła nie
  bierzemy referencji pakietu w produkcyjnym jądrze. Fakt równości tego zegara nie używa.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Wiążące jest rozróżnienie encji i
  obiektu wartości: inna równość, inna rola. Dotyczy `Entity` po `Id` i typie oraz `ValueObject`
  po składowych. Ze źródła nie bierzemy modelu jednej z pięciu usług w jądrze i nie bierzemy
  atrybutów mapowania. `ProbeValue` zostaje w teście.
- Evans, *Domain-Driven Design*. Wiążące są encja jako tożsamość i obiekt wartości jako równość
  po atrybutach, bez cyklu życia osobnego od całości. Dotyczy prywatnego settera `Id`,
  abstrakcyjnych składowych i zakazu własnego `Equals` w podklasie. Ze książki nie bierzemy
  taktycznego szablonu pod konkretny `Article` ani `Account`, tych typów w jądrze nie ma, a
  wydanie nie ma stabilnego adresu URL.
- [Equality for a
  type](https://learn.microsoft.com/dotnet/csharp/fundamentals/expressions/equality). Wiążące
  jest trzymanie `Equals`, operatorów i `GetHashCode` w jednym miejscu. Dotyczy implementacji w
  bazie `ValueObject` oraz faktu, który woła wszystkie trzy na dwóch równych egzemplarzach. Ze
  źródła nie bierzemy równości wyłącznie po pierwszym polu i nie bierzemy nadpisania w
  `ProbeValue`. Kolejność składowych ma znaczenie.
- [RFC 9457 Problem Details](https://datatracker.ietf.org/doc/html/rfc9457). Wiążące jest to,
  dokąd kod trafi na brzegu: pole problemu, nie tłumaczenie w jądrze. Dotyczy kodu w przyszłym
  polu `type` i rodzaju, który wybierze status. Ze źródła nie bierzemy składania
  `ProblemDetails` w `JJDevHub.Shared.Kernel` i nie bierzemy statusów `428` oraz `412` jako
  rodzajów. Te statusy zostają przy nagłówku `If-Match` w `Api`.
- [xUnit](https://xunit.net/). Wiążące jest `[Fact]` bez cechy integracyjnej. Dotyczy
  `Value_object_equal_when_components_equal` i jednego powodu: nierówność przy równych
  składowych. Ze źródła nie bierzemy asercji trzeciego egzemplarza w tej metodzie i nie bierzemy
  cechy `Category=Performance`. Kontener nie jest potrzebny.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: wspólne klocki nie są
  projektem jednej usługi i nie ciągną infrastruktury sąsiada. Dotyczy jądra bez referencji do
  Identity, News, Learning, Cv i Contact. Z tego repozytorium nie bierzemy MediatR ani
  IntegrationEventLogEF ani AutoMappera, a MediatR nie wchodzi do csproj jądra.

## Gotowe gdy

- Projekt jądra kompiluje się bez pakietów infrastruktury.
- `ResultErrorKind` ma dokładnie pięć wartości: `None`, `Invalid`, `NotFound`, `Conflict`,
  `Forbidden`.
- Kod z wielką literą albo spacją nie przechodzi fabryki.
- `ISecretReader` zwraca `Result<string>`, a `SecretRead` nie występuje w kompilacji.
- Fakt równości obiektu wartości kończy się kodem zero.
- W jądrze nie ma nazwy usługi ani nazwy agregatu z słownika usług.
- `DateTimeOffset.UtcNow` nie występuje w `Entity` ani w `ValueObject`.
- `Directory.Packages.props` zawiera pakiet testowy czasu tylko dla projektu testu.
