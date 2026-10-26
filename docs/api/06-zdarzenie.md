# 06. Zdarzenie

Poprzedni numer, [jądro](05-kernel.md), niesie `Result`, tożsamość i obiekt wartości. Ten numer
dokłada kontrakt zdarzenia w tym samym jądrze: `IDomainEvent` i `EventNameAttribute`. Następny
numer, [agregat](07-agregat.md), będzie tym zdarzeniem zmieniał pola wyłącznie w `Apply`. Po tym
numerze da się odczytać nazwę `news.article-created.v1` z typu, który ma kształt utworzenia
artykułu. Samego agregatu `Article` jeszcze nie ma. Nie ma go w News i nie ma go w jądrze.
Słownik nazw jest w [README.md](README.md).

Scenariusz, który bez tego numeru się psuje, jest refaktorem nazwy klasy. Strumień, outbox i
Kafka wołają fakt kluczem `ArticleCreatedDomainEvent`. Zmiana nazwy w C# zmienia wiersz w bazie
i temat u konsumenta Cv. Albo test atrybutu przechodzi na typie `Ping`, a produkcja i tak
wstawia nazwę klasy, bo nikt nie sprawdził łańcucha, którego News naprawdę użyje. Pełny URI albo
dyskryminator `$type` staje się drugą gramatyką obok krótkiej nazwy i klucz kompaktowania się
rozjeżdża. Zdarzenie w czasie teraźniejszym, jak komenda `news.create-article.v1`, kłamie, że
fakt dopiero trzeba wykonać.

Kontrakt ma być atrybutem z łańcuchem `segment.fakt.vN`. Jądro umie ten łańcuch odczytać. Nie
umie zapisać go do PostgreSQL. To zrobi magazyn później. Przykład w teście ma prawdziwy kształt
z News: identyfikator artykułu i slug, nazwa `news.article-created.v1`. Typ siedzi w projekcie
testowym. Jądro tego rekordu nie dostaje, bo wtedy znałoby News.

## Po co

Strumień, outbox i Kafka mają wołać fakt tak samo po wdrożeniu, które zmieni nazwę klasy. Jeśli
kluczem będzie `ArticleCreatedDomainEvent`, zmiana nazwy w C# zmieni wiersz w bazie i temat u
konsumenta. Kontrakt ma być atrybutem z łańcuchem `segment.fakt.vN`. Jądro umie ten łańcuch
odczytać metodą `EventNames.For(Type)`. Nie umie zapisać go do PostgreSQL. Zapis koperty jest w
[09-persistence.md](09-persistence.md). Outbox, który kopiuje nazwę z atrybutu, jest w
[14-outbox.md](14-outbox.md). Rekord integracyjny w `Contracts` i temat Kafki są w
[15-kafka.md](15-kafka.md).

Przykład musi być prawdziwym kształtem z News, inaczej atrybut zostanie sprawdzony na typie
`Ping`, a produkcja i tak wstawi nazwę klasy. Dlatego w teście jest `ArticleCreatedDomainEvent`
z polami identyfikatora artykułu i sluga. Typ siedzi w projekcie testowym. Produkcyjny
odpowiednik dojdzie w [18-news.md](18-news.md) i będzie miał ten sam atrybut. Jądro nie dostaje
tego rekordu, bo wtedy znałoby News. Nie ma klasy `Article`. Nie ma metody `Create`. Nie ma
projektu `News.Core`. W `src/services` nie ma wymogu tego numeru, żeby `News.Core` istniał.

Wspólne minimum faktu to `Guid EventId` i `DateTimeOffset OccurredOn`. `EventId` jest
identyfikatorem wiadomości dla inboxu. Nie jest wersją strumienia. `OccurredOn` bierze się z
`TimeProvider` w miejscu, które fakt tworzy, nie z wnętrza interfejsu. Interfejs nie woła
zegara. W tym numerze test wpisuje `DateTimeOffset` wprost, bo agregatu nie ma. Wersja należy do
strumienia. Na `IDomainEvent` jej nie ma. Nazwa też nie jest właściwością interfejsu. Żyje na
atrybucie, żeby rekord jej nie dublował innym łańcuchem.

Zły atrybut jest błędem programisty przy starcie mapowania, nie `Result` dla użytkownika.
`EventNames.For` rzuca `InvalidOperationException`, gdy atrybutu nie ma, gdy nazwa jest pusta,
gdy ma wielką literę, gdy równa się `type.Name`, gdy zawiera znak `` ` ``, albo gdy nie pasuje
do gramatyki trzech segmentów. Nie zwraca `Result`. Oczekiwany błąd użytkownika nadal jest
`Result` z numeru 05. Zapomnienie atrybutu wybucha przy pierwszym `EventNames.For`, nie po cichu
nazwą klasy.

Gramatyka trzyma jeden klucz dla konsumenta i dla indeksu outboxa. Małe litery, trzy segmenty,
kropki. Środek może mieć myślniki: `article-created`. Ostatni segment to `v` i liczba, na
przykład `v1`. Pierwszy segment to usługa, która fakt posiada: `news`, `identity`, `learning`,
`cv`, `contact`. Fakt jest dokonany. Nazwa w czasie teraźniejszym, jak `news.create-article.v1`,
odpada. Zmiana znaczenia nie edytuje `v1`. Dostaje `v2`, a `v1` zostaje czytelne dla wierszy już
zapisanych.

## Dlaczego ta technologia

### `IDomainEvent`

Interfejs w `JJDevHub.Shared.Kernel` ma `Guid EventId` i `DateTimeOffset OccurredOn`. Oba
członki są tylko do odczytu. Zdarzenie jest rekordem, który już zaszedł. Nie jest komendą i nie
jest żądaniem HTTP. Nie ma na nim `Version`. Nie ma na nim nazwy. Rekord zdarzenia jest
`sealed`. Jeden publiczny typ na plik. Interfejs nie woła `TimeProvider` i nie woła zegara
statycznego. Chwilę wypełnia kod, który fakt tworzy. W agregacie będzie to miejsce przy
`TimeProvider` z numeru 05. W tym numerze tego miejsca jeszcze nie ma.

Outbox, strumień i test potrzebują wspólnego minimum: identyfikatora faktu i chwili. Bez
interfejsu każdy rekord nazywa te pola inaczej i inbox nie ma czego zapamiętać. `EventId` jest
identyfikatorem wiadomości dla inboxu. Powtórzona dostawa tej samej wiadomości ma na czym się
oprzeć, gdy magazyn i outbox powstaną. Dziś inboxu nie ma, ale pole już jest, żeby później nie
doklejać go do każdego rekordu osobnym refaktorem. `OccurredOn` jest chwilą faktu, nie czasem
zapisu do bazy i nie wersją. Wersja rośnie w strumieniu. Pomylenie jej z `EventId` albo z
`OccurredOn` miesza kolejność agregatu z identyfikatorem dostawy.

Konkret kształtu jest w teście, nie w jądrze. `ArticleCreatedDomainEvent` niesie `EventId`,
`OccurredOn`, `ArticleId` i `Slug`. Dwa pierwsze są kontraktem interfejsu. Dwa kolejne są danymi
przykładu News. Produkcyjny fakt w [18-news.md](18-news.md) będzie miał ten sam atrybut. Fakty
`contact.student-inquiry-received.v1` i `contact.recruiter-inquiry-received.v1` dojdą w
[21-kontakt.md](21-kontakt.md) i też zaimplementują ten interfejs, gdy powstaną. Temat
kompaktowany `learning.integration` jest w [15-kafka.md](15-kafka.md) i
[19-learning.md](19-learning.md). Ten numer żadnego z tych rekordów produkcyjnych nie tworzy.
Daje im wspólne dwa pola.

Odpadło `INotification` z MediatR. MediatR od wersji 13 nie wchodzi, a zdarzenie domenowe nie
jest wiadomością magistrali wewnątrz procesu cudzej biblioteki. MediatR odpada. Wciągnięcie
interfejsu z pakietu, którego jądro nie referencjonuje, złamałoby numer 05. Fakt przestałby być
rekordem domeny, a stałby się powiadomieniem biblioteki. Handler w procesie i konsument na
szynie to dwa różne wołania. Jedno i drugie ma czytać `EventId`. Nie ma wołać `Publish` cudzego
interfejsu po to, żeby w ogóle mieć identyfikator.

Odpadł goły rekord bez wspólnego kontraktu. Da się go zserializować, ale nie da się napisać
jednego odczytu `EventId` w magazynie. Każdy fakt miałby `Id`, `EventId` albo `MessageId`, a
inbox nie wiedziałby, które pole zapamiętać. Serializacja koperty i tak jest poza tym numerem.
Sam rekord bez interfejsu nie daje magazynowi typu, po którym pozna minimum. `IDomainEvent` jest
tym minimum. Nie jest bazową klasą z logiką. Nie niesie kolekcji i nie niesie nazwy.

Koszt: każdy fakt niesie dwa pola, nawet gdy domena myśli tylko o slugu. `ArticleId` i `Slug` są
danymi. `EventId` i `OccurredOn` są kopertą, która ma być na każdym rekordzie tak samo. To jest
celowe. Autor, który pominie `EventId`, nie zaimplementuje interfejsu i nie wejdzie do
strumienia, gdy strumień powstanie. Autor, który wstawi wersję na interfejs, przeniesie numer
strumienia do faktu i rozjedzie się z numerem 08, gdzie wersja należy do dopisania, nie do
treści. Interfejs zostaje przy dwóch członkach.

### `EventNameAttribute`

Atrybut na klasie, bez dziedziczenia, jeden na typ:

```csharp
[AttributeUsage(AttributeTargets.Class, Inherited = false, AllowMultiple = false)]
public sealed class EventNameAttribute : Attribute
{
    public EventNameAttribute(string name) => Name = name;
    public string Name { get; }
}
```

Konstruktor przyjmuje `name`. Właściwość `Name` jest publiczna i tylko do odczytu.
`AttributeUsage` ogranicza cel do klasy, zabrania wielu atrybutów i wyłącza dziedziczenie.
Odczyt jest w jednej metodzie `EventNames.For(Type)`. Metoda czyta atrybut. `EventNames` jest
klasą statyczną albo statycznym typem zamkniętym. Nie cache’uje nazwy w słowniku, który da się
rozjechać z atrybutem, dopóki pomiar nie pokaże potrzeby. Odczyt atrybutu przy dopisaniu
strumienia jest tani wobec IO, którego i tak jeszcze nie ma.

Nazwa ma być widoczna przy typie, bez słownika z boku, który ktoś zapomni zaktualizować.
Jednocześnie ma przeżyć zmianę nazwy klasy. Atrybut przy rekordzie jest tym miejscem. Słownik
obok pliku rozjedzie się przy pierwszym nowym fakcie. Nazwa na właściwości interfejsu dałaby
drugi łańcuch, który może kłamać wobec atrybutu. Dlatego interfejs nazwy nie ma.
`EventNames.For` jest jedynym odczytem. Magazyn przy zapisie koperty i adapter szyny przy
publikacji będą go wołać. W tym numerze woła go test.

Konkret: `[EventName("news.article-created.v1")]` na rekordzie testowym jest tym, co fakt
porównuje z literałem. Nie porównuje z `nameof` klasy. Gdyby porównanie szło przez
`nameof(ArticleCreatedDomainEvent)`, test zostałby zielony po zmianie atrybutu na nazwę CLR i
kontrakt by zniknął. Literał `news.article-created.v1` jest w słowniku [README.md](README.md) i
zgadza się z literałem testu. To jest ten sam łańcuch. Dwa różne zapisy tej nazwy, jeden w
słowniku i drugi w atrybucie, są błędem numeru, nie dwoma dopuszczalnymi aliasami.

Odpadło użycie nazwy CLR jako nazwy w bazie i na szynie. Refaktor `ArticleCreatedDomainEvent` na
inną nazwę klasy psuje konsumenta Cv i wiersze już zapisane. `EventNames.For` na typie bez
atrybutu rzuca, a nie zwraca `type.Name`. To jest warunek „gotowe”, osobny od faktu, który
sprawdza poprawną nazwę. Brak atrybutu to inny powód padnięcia i nie należy go doklejać do
asercji `news.article-created.v1`. Osobna ścieżka wyjątku jest opisana w zasadach. Jeśli
implementacja zwróci `ArticleCreatedDomainEvent`, fakt jest czerwony z tego samego powodu:
odczytana nazwa nie jest oczekiwanym łańcuchem.

Odpadł dyskryminator `$type` z `System.Text.Json` jako nazwa publiczna. Ten dyskryminator też
jest nazwą CLR albo inną nazwą wybraną przez serializator, a kontrakt ma być jawny i krótki.
Serializacja koperty i tak nie wchodzi do tego numeru. Gdy wejdzie, nazwa w kopercie ma
pochodzić z atrybutu, nie z pola, które serializator wstawia sam. `$type` może zostać szczegółem
biblioteki wewnątrz procesu. Nie jest kluczem w bazie i nie jest tematem. Znak `` ` `` w nazwie
też odpada: łapie generyka i nazwę, która nie jest gramatyką `segment.fakt.vN`.

Koszt: każdy nowy fakt wymaga atrybutu. Zapomnienie wybucha przy pierwszym `EventNames.For`, nie
po cichu nazwą klasy. Dziedziczenie atrybutu jest wyłączone, żeby klasa pochodna nie
odziedziczyła nazwy bazowej i nie udawała tego samego faktu. `Inherited = false` jest warunkiem
ukończenia. Wiele atrybutów na jednym typie jest wyłączone, żeby nie było dwóch kluczy. Atrybut
na strukturze albo na metodzie nie wchodzi, bo cel to klasa, a rekord jest klasą. Pomiar, który
kiedyś pokaże potrzebę cache, może dojść później. Do tego czasu słownik w pamięci, który
rozjedzie się z atrybutem, jest gorszy niż odczyt refleksji przy IO, którego nie ma.

### Gramatyka `segment.fakt.vN`

Małe litery, trzy segmenty rozdzielone kropką. Środkowy segment może mieć myślniki:
`article-created`. Ostatni segment to `v` i liczba, na przykład `v1`. Pierwszy segment to
usługa, która fakt posiada: `news`, `identity`, `learning`, `cv`, `contact`. `EventNames.For`
rzuca, gdy nazwa nie pasuje do tej gramatyki, gdy jest pusta, gdy ma wielką literę, gdy równa
się `type.Name`, albo gdy zawiera `` ` ``. Wielka litera w `News.ArticleCreated` nie przechodzi.
Podkreślenie albo ukośnik zamiast kropki nie przechodzą, bo to nie są trzy segmenty tej
gramatyki.

Bez gramatyki obok siebie staną `News.ArticleCreated`, `article_created` i
`news/article/created`. Konsument i indeks outboxa nie mają jednej reguły. Temat Kafki, wiersz
koperty i atrybut mają wołać ten sam łańcuch. Dwie konwencje oznaczają dwa klucze dla jednego
faktu i ciche podwójne przetwarzanie albo cichy brak konsumenta. Pierwszy segment wiąże fakt z
właścicielem. `news` nie publikuje faktu, którego właścicielem jest `cv`. Środkowy segment jest
dokonany, bo zdarzenie już zaszło. Ostatni segment jest wersją kontraktu, nie wersją strumienia
agregatu.

Konkret JJDevHub: `news.article-created.v1` jest nazwą utworzenia artykułu. Nie jest nazwą klasy
i nie jest komendą „utwórz”. Gdy znaczenie faktu się zmieni, autor nie edytuje `v1`. Dopisuje
`v2`, a wiersze zapisane jako `v1` zostają czytelne. Fakty zapytań Contact dostaną własne
łańcuchy w numerze 21, z pierwszym segmentem `contact` i ze stroną dokonaną. Ten numer ich nie
wprowadza. Wprowadza regułę, pod którą wpadną, i jeden przykład, który już jest w słowniku.
Autor faktu wymyśla segment usługi raz i trzyma go w słowniku. Zmiana `news` na `articles` jest
zmianą właściciela, nie kosmetyką.

Odpadł pełny URI w stylu CloudEvents jako jedyna nazwa. Da się go wołać, ale szyna, tabela i
atrybut w tym systemie używają krótkiego łańcucha. Pełny URI odpadł. Druga gramatyka obok
krótkiej nazwy rozjeżdża klucz kompaktowania. Kto wstawi URI do atrybutu, nie przejdzie trzech
segmentów i `EventNames.For` rzuci, jeśli gramatyka jest pilnowana. Kto przyjmie URI obok
krótkiej nazwy, ma dwa klucze. Zostaje krótki łańcuch. Ze specyfikacji chmurowego zdarzenia nie
bierzemy też koperty jako zamiennika `EventId` i `OccurredOn`. Te dwa pola już są na
interfejsie.

Odpadła nazwa w czasie teraźniejszym, jak komenda: `news.create-article.v1`. Zdarzenie jest
faktem, który już zaszedł, więc środkowy segment jest w stronie dokonanej: `article-created`.
Komenda jest żądaniem. Fakt jest zapisem, że żądanie już coś zmieniło. Ta sama linia w czasie
teraźniejszym na szynie wygląda jak polecenie dla konsumenta, żeby utworzył artykuł jeszcze raz.
Strona dokonana mówi, że artykuł został utworzony. Konsument aktualizuje swój widok. Nie
wykonuje komendy źródłowej drugi raz tylko dlatego, że nazwa brzmi jak czasownik rozkazujący.

Koszt: zmiana znaczenia faktu nie edytuje `v1`. Dostaje `v2`, a `v1` zostaje czytelne dla
wierszy już zapisanych. Trzeba umieć czytać starą wersję albo świadomie jej nie rozumieć, a nie
nadpisywać znaczenie pod tym samym kluczem. Autor faktu musi wymyślić segment usługi raz i
trzymać go w słowniku. Literówka `new.article-created.v1` jest innym właścicielem. Test łapie
literówkę przykładu News, bo porównuje cały literał. Nie łapie wszystkich przyszłych faktów.
Łapie gramatykę na tym jednym typie i regułę odrzucenia nazwy, która gramatyką nie jest.

### Przykład poza agregatem

W `tests/JJDevHub.Shared.Kernel.Tests` leży rekord:

```csharp
[EventName("news.article-created.v1")]
public sealed record ArticleCreatedDomainEvent(
    Guid EventId,
    DateTimeOffset OccurredOn,
    Guid ArticleId,
    string Slug) : IDomainEvent;
```

Nie ma klasy `Article`. Nie ma metody `Create`. Nie ma projektu `News.Core`. Rekord pokazuje
kształt: identyfikator faktu, chwila, identyfikator artykułu, slug. `ArticleId` i `Slug` są
danymi przykładu. Nie serializujemy rekordu do JSON w tym numerze. Nie budujemy agregatu i nie
otwieramy bazy. Plik testu to `ArticleCreatedDomainEvent.cs` i `EventNameTests.cs`. W projekcie
`JJDevHub.Shared.Kernel` nie ma pliku agregatu News i nie ma tego rekordu.

Test atrybutu na typie `ProbeHappened` przejdzie i nic nie powie o nazwie, której później użyje
News. Kształt z prawdziwą nazwą łapie literówkę `news.article-created.v1` już teraz. Fakt woła
`EventNames.For(typeof(ArticleCreatedDomainEvent))` i porównuje wynik z tym literałem. Nazwa
metody to `Article_created_event_name_is_news_article_created_v1`. Powód padnięcia jest jeden:
odczytana nazwa nie jest `news.article-created.v1`. Jeśli implementacja zwróci
`ArticleCreatedDomainEvent`, fakt jest czerwony z tego samego powodu.

Odpadło wstawienie tego rekordu do `JJDevHub.Shared.Kernel`. Jądro znałoby artykuł i złamałoby
regułę z [architektura.md](architektura.md). Numer 05 już zabrania klasy `Article` w jądrze. Ten
numer jej nie wraca tylnymi drzwiami przez rekord zdarzenia. Jądro zna `IDomainEvent`, atrybut i
odczyt nazwy. Nie zna pól `ArticleId` i `Slug` jako typu produkcyjnego. Test może je znać, bo
test nie jest modelem usługi. Produkcja dostanie własny rekord w `News.Core`.

Odpadło też tworzenie `src/services/News` w tym numerze. Agregat, strumień i endpoint są w
[18-news.md](18-news.md). Projekt usługi w tym numerze wciągnąłby `Apply`, repozytorium i
endpoint, których jeszcze nie ma. Warunek „gotowe” mówi wprost: w `src/services` nie ma wymogu
tego numeru, żeby istniał `News.Core`. Kto założy katalog „bo nazwa eventu jest z news”, zamyka
numer 18 w środku numeru 06. Zostaje rekord w teście jądra.

Koszt: przez pewien czas ten sam kształt istnieje jako wzorzec w teście. Numer 18 przenosi
odpowiedzialność do `News.Core` i zostawia atrybut o tej samej treści. Test jądra nadal może
trzymać lokalny rekord, by pilnować odczytu atrybutu, albo zacząć czytać typ z News. Do numeru
18 źródłem prawdy nazwy w teście jądra jest rekord testowy. Dwa rekordy o tym samym atrybucie
nie mogą rozjechać literału. Słownik README jest trzecim miejscem tej samej treści, nie miejscem
na alias. Gdy numer 18 przeniesie typ, atrybut zostaje `news.article-created.v1`.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Shared.Kernel/IDomainEvent.cs` | `EventId` i `OccurredOn` |
| `src/shared/JJDevHub.Shared.Kernel/EventNameAttribute.cs` | łańcuch nazwy na klasie |
| `src/shared/JJDevHub.Shared.Kernel/EventNames.cs` | `For(Type)` odrzuca brak atrybutu i nazwę CLR |
| `tests/JJDevHub.Shared.Kernel.Tests/ArticleCreatedDomainEvent.cs` | kształt faktu, bez agregatu |
| `tests/JJDevHub.Shared.Kernel.Tests/EventNameTests.cs` | fakt na nazwę `news.article-created.v1` |

`EventNames` jest klasą statyczną albo statycznym typem zamkniętym. Nie cache’uje nazwy w
słowniku, który da się rozjechać z atrybutem, dopóki pomiar nie pokaże potrzeby. Odczyt atrybutu
przy dopisaniu strumienia jest tani wobec IO, którego i tak jeszcze nie ma.

## Plan

### 1. Interfejs

Dodaj `IDomainEvent` w jądrze. Dwa członki tylko do odczytu: `EventId` i `OccurredOn`. Nie
dodawaj `Version`. Wersja należy do strumienia, nie do faktu. Nie dodawaj nazwy jako właściwości
interfejsu. Nazwa żyje na atrybucie, żeby rekord jej nie dublował innym łańcuchem.

### 2. Atrybut

Dodaj `EventNameAttribute` z konstruktorem przyjmującym `name`. `AttributeUsage` ogranicza cel
do klasy, zabrania wielu atrybutów i wyłącza dziedziczenie. Właściwość `Name` jest publiczna i
tylko do odczytu.

### 3. Odczyt

Dodaj `EventNames.For`. Gdy atrybutu nie ma, rzuć `InvalidOperationException`. Gdy `Name` jest
pusta, rzuć. Gdy `Name` równa się `type.Name` albo zawiera `` ` ``, rzuć. Gdy `Name` nie pasuje
do gramatyki trzech segmentów, rzuć. Nie zwracaj `Result`. Zły atrybut jest błędem programisty.

### 4. Rekord wzorcowy

W projekcie testu dodaj `ArticleCreatedDomainEvent` jak w sekcji wyżej. `ArticleId` i `Slug` są
danymi przykładu. Nie twórz `Article`, repozytorium ani endpointu. Nie serializuj rekordu do
JSON w tym numerze. Serializacja koperty jest w [09-persistence.md](09-persistence.md).

### 5. Fakt nazwy

Test woła `EventNames.For(typeof(ArticleCreatedDomainEvent))`. Porównuje wynik z literałem
`news.article-created.v1`. Nie porównuje z `nameof` klasy.

### Co jest do czego

`IDomainEvent` woła przyszły agregat, magazyn i outbox. Daje im identyfikator i chwilę. Nie daje
nazwy na szynie. Gdy interfejsu nie ma, każdy rekord nazywa pola inaczej i inbox nie ma czego
zapamiętać. Gdy na interfejsie jest `Version`, wersja strumienia wchodzi do treści faktu i
rozjeżdża się z dopisaniem. Gdy interfejs woła zegar, test nie może wstawić `DateTimeOffset`
wprost.

`EventNameAttribute` woła autor rekordu zdarzenia. Przypina stabilny łańcuch do typu. Gdy
atrybutu nie ma, `EventNames.For` albo rzuca, albo — jeśli ktoś złamie metodę — zwraca nazwę
CLR. Drugie z tych wyjść jest wprost zakazane. Gdy atrybut jest dziedziczony, klasa pochodna
udaje fakt bazowy. Gdy atrybutów jest wiele, typ ma dwa klucze.

`EventNames.For` woła magazyn przy zapisie koperty i adapter szyny przy publikacji. W tym
numerze woła go test. Odcina nazwę CLR od klucza. Gdy metody nie ma, każdy caller czyta atrybut
po swojemu i jeden z nich zapomni odrzucić `type.Name`. Gdy metoda zwraca `Result`, zły atrybut
wygląda jak błąd użytkownika. Cache nazwy w słowniku, zanim pomiar pokaże potrzebę, potrafi
zostać przy starej wartości po zmianie atrybutu.

`ArticleCreatedDomainEvent` w teście woła tylko ten fakt. Pokazuje, jak będzie wyglądał fakt
News, i nie tworzy artykułu. Gdy rekord leży w jądrze, jądro zna News. Gdy zamiast niego jest
`Ping` albo `ProbeHappened`, test nie pilnuje literału `news.article-created.v1`. Gdy test
porównuje z `nameof`, zmiana atrybutu na nazwę klasy zostaje zielona.

`TimeProvider` z numeru 05 woła kod, który wypełnia `OccurredOn`, gdy fakt powstaje w agregacie.
W tym numerze test wpisuje `DateTimeOffset` wprost, bo agregatu nie ma. Gdy test zamiast tego
woła `UtcNow`, asercja nazwy zaczyna zależeć od zegara, choć nazwa od zegara nie zależy. Zegar
nie jest członkiem interfejsu.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]`. Powód padnięcia jest jeden:
odczytana nazwa nie jest `news.article-created.v1`. Jeśli implementacja zwróci
`ArticleCreatedDomainEvent`, fakt jest czerwony z tego samego powodu. NBomber tu nie występuje.
Kontener tu nie występuje. Nie ma cechy integracyjnej. Docker nie jest potrzebny do odczytu
atrybutu.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | typ `ArticleCreatedDomainEvent` z atrybutem `news.article-created.v1` w projekcie testu |
| Działanie (act) | `EventNames.For(typeof(ArticleCreatedDomainEvent))` |
| Sprawdzenie (assert) | wynik równa się `news.article-created.v1` |

Nazwa metody: `Article_created_event_name_is_news_article_created_v1`.

```text
dotnet test tests/JJDevHub.Shared.Kernel.Tests/JJDevHub.Shared.Kernel.Tests.csproj --filter "FullyQualifiedName~Article_created_event_name_is_news_article_created_v1"
```

Test nie buduje agregatu i nie otwiera bazy. Nie sprawdza jednocześnie braku atrybutu. Brak
atrybutu to inny powód padnięcia i nie należy go doklejać do tej asercji. Osobna ścieżka wyjątku
jest opisana w zasadach.

Przygotowanie nie ustawia `TimeProvider` i nie tworzy egzemplarza po to, żeby czytać nazwę.
Nazwa jest na typie. Działanie woła `For` na `typeof`. Sprawdzenie jest równością łańcuchów z
literałem, nie z `nameof` i nie z fragmentem URI. Fakt nie serializuje rekordu. JSON koperty,
gdyby tu wszedł, dałby drugi powód: kształt serializatora albo `$type`. Tego powodu tu nie ma.

Warunek, że metoda na typie bez atrybutu rzuca i nie zwraca `type.Name`, zostaje w „Gotowe gdy”.
Nie jest drugą asercją tej metody. Dzięki temu czerwony fakt znaczy jedną rzecz: łańcuch
przykładu News jest zły albo odczyt go nie zwraca. Wyjątek na złej gramatyce, na wielkiej
literze, na pustej nazwie i na znaku `` ` `` jest treścią `EventNames.For` i zasad, nie
dodatkowym `[Fact]` doklejonym do tej nazwy.

## Zasady

- Nazwa zapisywana i wysyłana pochodzi z `EventNameAttribute`. Nazwa z innego miejsca rozjeżdża
  wiersz, temat i atrybut.
- Nazwa klasy CLR nie jest kluczem. Refaktor klasy zmienia wtedy konsumenta i zapisane wiersze.
- Jądro nie zawiera `ArticleCreatedDomainEvent`. Rekord w jądrze wciąga kształt News do
  wspólnego projektu.
- Jądro nie zawiera typu `Article`. Typ artykułu w jądrze łamie granicę z numeru 05.
- Atrybut nie jest dziedziczony. Dziedziczenie sprawia, że klasa pochodna udaje ten sam fakt.
- Gramatyka to `segment.fakt.vN` małymi literami. Inna gramatyka zostawia obok siebie URI,
  podkreślenia i nazwy klas.
- Fakt jest dokonany, nie jest komendą. Czas teraźniejszy w nazwie wygląda jak polecenie do
  wykonania drugi raz.
- `EventId` nie jest wersją strumienia. Pomylenie pól miesza identyfikator inboxu z numerem
  agregatu.
- Zły atrybut jest wyjątkiem programisty. `Result` na złym atrybucie wygląda jak błąd
  użytkownika.
- Oczekiwany błąd użytkownika nadal jest `Result` z numeru 05. Wyjątek na pusty tytuł wraca do
  `500`.
- MediatR, MassTransit i CloudEvents jako jedyna nazwa nie wchodzą. MediatR i MassTransit
  odpadają jako magistrala, a pełny URI odpada jako jedyny klucz.
- Rekord zdarzenia jest `sealed`. Dziedziczenie rekordu otwiera drugi typ pod tą samą nazwą,
  jeśli atrybut by zszedł w dół.
- Jeden publiczny typ na plik. Drugi publiczny typ w pliku zdarzenia chowa kontrakt przed
  przeglądem.

## Poza zakresem

- `AggregateRoot`, `Apply`, `Replay`, `AddDomainEvent` i `MarkPersisted` są w
  [07-agregat.md](07-agregat.md). Ten numer nie zmienia pól.
- `IEventStore` i konflikt wersji są w [08-strumien.md](08-strumien.md). Ten numer nie zapisuje
  strumienia.
- Zapis koperty do PostgreSQL jest w [09-persistence.md](09-persistence.md). Ten numer nie
  serializuje rekordu do JSON.
- Rekord integracyjny w `Contracts` i temat Kafki są w [15-kafka.md](15-kafka.md). Ten numer nie
  publikuje na szynę.
- Outbox, który kopiuje nazwę z atrybutu, jest w [14-outbox.md](14-outbox.md). Ten numer tylko
  umie nazwę odczytać.
- Prawdziwy `Article` i produkcyjne zdarzenie News są w [18-news.md](18-news.md). Ten numer
  zostawia kształt w teście.
- Fakty `contact.student-inquiry-received.v1` i `contact.recruiter-inquiry-received.v1` są w
  [21-kontakt.md](21-kontakt.md). Ten numer ich nie dodaje.
- Temat kompaktowany `learning.integration` jest w [15-kafka.md](15-kafka.md) i
  [19-learning.md](19-learning.md). Ten numer nie tworzy tematu.

## Źródła

- [Event-driven architecture](https://martinfowler.com/articles/201701-event-driven.html).
  Wiążące jest to, że fakt ma jawną nazwę, niezależną od klasy w kodzie. Dotyczy
  `EventNameAttribute` i łańcucha `news.article-created.v1`. Ze źródła nie bierzemy pełnego URI
  w stylu CloudEvents jako jedynej nazwy: taki URI odpadł, podobnie jak nazwa w czasie
  teraźniejszym, bo środkowy segment jest dokonany.
- [Attributes](https://learn.microsoft.com/dotnet/csharp/advanced-topics/reflection-and-attributes).
  Wiążące są `AttributeUsage` i odczyt atrybutu z typu. Dotyczy `EventNameAttribute` oraz
  `EventNames.For`. Ze źródła nie bierzemy dziedziczenia atrybutu i nie bierzemy wielu atrybutów
  na jednym typie. `Inherited` zostaje `false`, `AllowMultiple` zostaje `false`.
- [AttributeUsageAttribute](https://learn.microsoft.com/dotnet/api/system.attributeusageattribute).
  Wiążące są cel klasy, zakaz wielu użyć i flaga dziedziczenia. Dotyczy konstruktora atrybutu w
  planie. Ze źródła nie bierzemy celu innego niż klasa, bo rekord zdarzenia jest klasą, a
  atrybut na
  metodzie nie jest nazwą faktu.
- [System.Text.Json
  polymorphism](https://learn.microsoft.com/dotnet/standard/serialization/system-text-json/polymorphism).
  Wiążąca jest informacja, że dyskryminator `$type` jest mechanizmem serializatora, nie
  kontraktem publicznym. Dotyczy odrzucenia `$type` jako nazwy w bazie i na szynie. `$type`
  odpada jako klucz, więc ze źródła nie bierzemy serializacji koperty w tym numerze. Nazwa
  zostaje
  w atrybucie, a koperta jest w numerze 09.
- [eShop integration events](https://github.com/dotnet/eshop). Wiążące jest to, że zdarzenie
  wychodzące z usługi jest osobne od modelu wewnętrznego. Dotyczy rekordu testowego poza jądrem
  i tego, że jądro nie zawiera `Article`. Z tego repozytorium nie bierzemy MediatR ani
  IntegrationEventLogEF ani MassTransit, a `INotification` nie jest `IDomainEvent`.
- [Domain events language](https://www.domainlanguage.com/ddd/). Wiążące jest to, że zdarzenie
  jest faktem, który już zaszedł. Dotyczy strony dokonanej w `article-created` oraz odrzucenia
  `news.create-article.v1`. Ze źródła nie bierzemy wstawienia agregatu News do jądra. Przykład
  zostaje w teście.
- Evans, *Domain-Driven Design*. Wiążące jest zdarzenie jako fakt z przeszłości, a nie jako
  komunikat do wykonania. Dotyczy `IDomainEvent` bez nazwy komendy i bez żądania HTTP. Ze
  książki nie bierzemy typu `Article` w `JJDevHub.Shared.Kernel`. Nie ma stabilnego URL tego
  wydania.
- Young, *Versioning in an Event Sourced System*. Wiążące jest to, że zmiana znaczenia dostaje
  nowy numer wersji, a stary łańcuch zostaje czytelny dla zapisanych wierszy. Dotyczy `v1` i
  `v2` w gramatyce `segment.fakt.vN`. Ze książki nie bierzemy edycji `v1` w miejscu i nie
  bierzemy wersji strumienia jako pola `IDomainEvent`. Wersja na końcu nazwy jest wersją
  kontraktu, a wydanie nie ma stabilnego URL.
- [Idempotent
  Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html).
  Wiążące jest zapamiętanie identyfikatora wiadomości, żeby powtórzona dostawa nie była drugim
  faktem. Dotyczy `EventId` jako identyfikatora dla inboxu. Ze źródła nie bierzemy brokera ani
  MassTransit jako miejsca, w którym ten identyfikator powstaje. Pole `EventId` jest na
  interfejsie, szyna dojdzie później i nie zastępuje wersji strumienia.
- [xUnit](https://xunit.net/). Wiążące jest `[Fact]` i jeden powód padnięcia. Dotyczy
  `Article_created_event_name_is_news_article_created_v1`. Ze źródła nie bierzemy drugiej
  asercji o braku atrybutu w tej samej metodzie i nie bierzemy cechy integracyjnej. Konteneru tu
  nie ma.

## Gotowe gdy

- `EventNames.For` na typie testowym zwraca `news.article-created.v1`.
- Ta sama metoda na typie bez atrybutu rzuca, a nie zwraca `type.Name`.
- W projekcie `JJDevHub.Shared.Kernel` nie ma pliku agregatu News.
- W `src/services` nie ma jeszcze wymogu tego numeru, żeby istniał `News.Core`.
- Komenda z sekcji testów kończy się kodem zero.
- Atrybut ma `Inherited = false`.
- Nazwa `news.article-created.v1` jest w słowniku [README.md](README.md) i zgadza się z
  literałem testu.
- Wersja zdarzenia nie jest właściwością `IDomainEvent`.
