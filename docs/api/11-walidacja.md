# 11. Walidacja, kody i język odpowiedzi

Ten numer domyka błąd, który mediator z [10-cqrs.md](10-cqrs.md) już umie zwrócić jako `Result`.
Klient dostaje `ProblemDetails` w języku z `Accept-Language`, ze stabilnym kodem w polu `type`.
Zapis z wersją strumienia wymaga `If-Match`. Projekcja, która czyta skutek udanego zapisu, jest
w [12-projekcja.md](12-projekcja.md). Bez tego numeru pusty tytuł, stara wersja artykułu i
awaria bazy wychodzą albo jako goły napis, albo jako wyjątek z connection stringiem, a dwa okna
nadpisują slug po cichu.

`Result<T>` i typ `Error` żyją w `JJDevHub.Shared.Kernel`. Ten numer nie dokłada drugiego typu
wyniku. Dokłada kody przekrojowe, zasoby `pl` i `en`, zapis walidacji FluentValidation do
`Result` oraz brzeg HTTP. Kernel nadal nie zna `Article`, `Account` ani `StudentInquiry`. Kod
`article.title.blank` jest stałą w `News.Application`, obok walidatora. Niesie go ten sam
`Error`, który niesie `invalid` i `precondition.required`.

Scenariusz bez wspólnego brzegu wygląda tak. Owner wysyła artykuł z pustym tytułem.
`ValidatorBehavior` zwraca `invalid` i element `article.title.blank` z `Target` `title`. Host ma
z tego zrobić `400` i `application/problem+json`, po polsku albo po angielsku, bez angielskiego
zdania z FluentValidation i bez wartości, która nie przeszła reguły. Drugie okno wysyła poprawkę
bez `If-Match`: to `428` i `precondition.required`. Znacznik `"2"` przy wersji 3 to `412` i
`precondition.failed`. Trzecia ścieżka to anonim, który trafia na szkic. Dostaje `404` i kod
`not_found`, a ciało nie zawiera `hidden` ani `article.hidden`. Osobny status potwierdziłby, że
wiersz istnieje.

Czwarta ścieżka to pad Postgresa. `TimeoutException`, `HttpRequestException`, `DbException` i
`IOException` stają się `io.unavailable` i `503`. `InvalidOperationException` z braku handlera
albo braku rejestracji staje się `composition.invalid` i `500`. Każdy inny wyjątek staje się
`unexpected` i `500`. Ciało nie zawiera `Message`, stosu ani connection stringa. Wyjątek idzie
do logu z identyfikatorem śladu. Klient rozgałęzia logikę po `type`, nie po zdaniu, bo zdanie
zależy od `Accept-Language`, a kod nie.

## Po co

Komenda może się nie udać na trzy sposoby, które klient musi rozróżnić bez czytania logu. Dane
wejściowe są złe: pusty tytuł, zły slug, brak pola. To walidacja. Handler nie startuje. Dane są
poprawne, a reguła albo wersja mówi nie: konflikt strumienia, brak prawa do cudzego szkicu. To
`Result` z handlera. Padło IO albo skład hosta: baza nie odpowiada, w kontenerze nie ma
handlera. To wyjątek. Wszystkie trzy wychodzą z hosta jako `ProblemDetails`. Treść zdania zależy
od `Accept-Language`. Kod w `type` nie zależy od języka.

Zapis agregatu niesie wersję, którą klient przeczytał. Bez `If-Match` nie wiadomo, czy klient
widział aktualny strumień. Brak nagłówka to `428`. Nieaktualny znacznik to `412`. Dwa okna z tym
samym artykułem nie nadpisują się po cichu. `EntityTag.FromVersion` zamienia `Version` z numeru
`09` na silny znacznik, na przykład `ETag: "4"` dla czwartego faktu. `TryParse` przyjmuje tylko
tę formę. Gwiazdka `*` nie przechodzi: zapis ma znać konkretną wersję. Wyścig po przejściu
filtra nadal może skończyć się `conflict` z `AppendAsync`. Ten `conflict` na brzegu HTTP też
staje się `412`, bo dla klienta to ten sam fakt: wersja, którą wysłał, już nie jest ostatnia.
Slug zajęty przez inny agregat zostaje `409`. Filtr nie rozróżnia tych dwóch `conflict` sam.
Handler zwraca albo `precondition.failed`, albo `conflict`, a mapa statusów jest wierna kodowi.

Treść, której czytelnik nie powinien widzieć, wygląda jak brak wiersza. Szkic notatki dla
anonima i lekcja niewidoczna dla studenta kończą się `404`. Osobny status nie zdradza, że wiersz
istnieje. `403` przegrywa, bo potwierdza istnienie szkicu. `401` zostaje dla braku i dla złego
tokenu i nie mówi nic o wierszu. Decyzję „ukryć czy pokazać” podejmuje handler zapytania w
`Application` i zwraca `not_found`. Filtr HTTP nie zgaduje po roli. Owner, który ma prawo,
dostaje prawdziwy stan. Brak wiersza u ownera nadal jest `404`. Kod `article.hidden` zostaje w
logu na poziomie `Debug`, bez sluga w treści, jeśli slug sam w sobie jest treścią niepubliczną.

`If-None-Match` na odczycie publicznym, z odpowiedzią `304`, jest przy widoku projekcji, nie w
tym numerze. Tu jest tylko kontrakt zapisu. Słaby `ETag` widoku publicznego, złożony z rewizji
projekcji, dojdzie przy usługach. Ten numer definiuje silny znacznik zapisu. Klient musi
pamiętać `ETag` z `GET`. Zapis bez wcześniejszego odczytu nie przejdzie. To jest uczciwe dla
intranetu, gdzie owner edytuje istniejący agregat. `IfMatchFilter` na endpoincie odczytu nie
wisi. Odczyt go nie dodaje.

Jest jeszcze powód, dla którego zdanie nie stoi w C#. Nowa kultura dokłada plik zasobów, nie
kolumnę i nie zmianę JSON-a. Na start są `pl` i `en`. Brak nagłówka, gwiazdka albo nieznany
język, na przykład `de`, dają `pl`. Brak klucza w żądanym języku bierze `pl`. Brak klucza w `pl`
wstawia sam kod. Treść wyjątku nigdy nie staje się `title`. Test
`Known_codes_have_polish_and_english` przechodzi po stałych i sprawdza oba pliki. Każdy nowy kod
przekrojowy dostaje wiersz w obu `resx` i wiersz w teście mapy statusów.

## Dlaczego ta technologia

### FluentValidation

FluentValidation (Apache-2.0) opisuje reguły wejścia jako wyrażenia na rekordzie komendy albo
zapytania: `RuleFor(c => c.Title).NotEmpty()`. Walidator jest klasą `sealed` z sufiksem
`Validator` w `Application`. `CreateArticleCommandValidator` woła
`WithErrorCode(ArticleErrors.TitleBlank)`, a `ArticleErrors.TitleBlank` równa się
`article.title.blank`. `ValidatorBehavior` z numeru `10` woła każdy `IValidator<TRequest>`
zarejestrowany dla tego typu. Pakiet jest już w `JJDevHub.Cqrs`. Ten numer nie dokłada drugiej
biblioteki walidacji.

Data Annotations (`[Required]`, `[MaxLength]`) przegrywają, bo wiążą regułę z rekordem atrybutem
i nie wołają value objectu. Ręczny ciąg `if` w handlerze przegrywa, bo łatwo zapomnieć pola i bo
transakcja zdąży się otworzyć, jeśli ktoś postawi walidację za `Begin`. Własny interfejs z jedną
metodą `string Validate` przegrywa, bo gubi nazwę pola i nie ma `ValidateAsync` z tokenem. Slug,
który nie przechodzi value objectu, ma wrócić jako kod pola, z `Target` w camelCase, tak jak
JSON, a nie jako jedno zdanie bez miejsca.

Reguła domeny zostaje w value object, na przykład `ArticleTitle.Create`. Walidator ją woła przez
`Must` i ustawia `WithErrorCode`. FluentValidation jest bramką na wejściu. Agregat jest bramką
ostateczną i też zwraca `Result`, nie wyjątek. Koszt: dwa miejsca znają tę samą regułę kształtu.
Value object jest źródłem prawdy. Walidator tylko przekłada jego porażkę na kod pola, zanim
otworzy się transakcja. `Core` nie referencjonuje FluentValidation ani ASP.NET. Walidator żyje w
`Application`, obok komendy, nie obok agregatu.

Brak `WithErrorCode` jest błędem testu walidatora. W produkcji pusty `ErrorCode` daje kod
`invalid` bez `Target` i log `Warning` z nazwą typu żądania. To jest sygnał składu, nie zdanie
dla klienta. Komunikat domyślny FluentValidation, po angielsku, nie wchodzi do odpowiedzi HTTP.
Do odpowiedzi wchodzi kod, a zdanie bierze się z zasobów. Test `Blank_title_returns_field_code`
układa walidator z `WithErrorCode("article.title.blank")` i pusty tytuł, potem oczekuje
`invalid` oraz elementu z `Target` `title`. Test `Validation_does_not_throw` oczekuje `Result`,
nie wyjątku.

### Porażka walidacji jako `Result` z kodem `invalid`

`ValidatorBehavior` nie rzuca `ValidationException`. Zbiera z każdego `ValidationFailure` parę
`PropertyName` i `ErrorCode` i zwraca `Result<T>.Fail` z kodem zbiorczym `invalid` oraz listą
`Error`. Handler i `TransactionBehavior` nie startują. Dzięki temu pusty tytuł nie bierze
połączenia z `news_write` i nie zostawia śladu w `EventStreams`. Kod pola ustawia walidator. Kod
jest częścią kontraktu, tak jak nazwa pola JSON. Zmiana `article.title.blank` na inne brzmienie
jest zmianą klienta, nie poprawką stylistyczną.

Koszt: każdy walidator musi znać stały kod. Nowy walidator bez kodu albo wpada w test, albo w
produkcji daje zbiorcze `invalid` bez `Target`, więc klient nie podświetli pola. Loguje się
nazwę pola i kod. Nie loguje się wartości, która nie przeszła reguły. Tytuł, slug i treść
zapytania Contact nie mają czego szukać w dzienniku walidacji.

Typ `Error` w kernelu jest `sealed record` z polami `Code` (`string`) i `Target` (`string?`).
`Result<T>` już istnieje. `Fail` przyjmuje jeden `Error` albo listę przy kodzie zbiorczym
`invalid`. `IsSuccess` jest fałszywe, gdy lista nie jest pusta. Kernel nadal nie referencjonuje
ASP.NET, FluentValidation ani EF. `ErrorCodes` jest klasą `static`. Stałe to wyłącznie kody z
tabeli statusów. Nie ma w niej `article.title.blank`. Kod usługi leży przy walidatorze tej
usługi. Ten sam `Error` niesie oba rodzaje: przekrojowy i lokalny. Usługa nie tworzy własnej
hierarchii wyjątków domenowych.

`Target` równa się `failure.PropertyName` w camelCase. `Title` na rekordzie staje się `title` w
JSON, tak jak pole artykułu w ciele żądania. Dzięki temu klient wiąże element tablicy `errors` z
kontrolką. Przy jednym błędzie domeny, na przykład `not_found` albo `conflict`, tablica `errors`
nie występuje, a `type` jest tym jednym kodem. Lista jest dla `invalid`, bo walidacja potrafi
odrzucić tytuł i slug naraz.

### Zasoby `pl` i `en`

Zdanie dla człowieka leży w zasobach, nie w kodzie C# i nie w bazie. Na start są dwie kultury:
`pl` i `en`. Nowa kultura dokłada plik zasobów, nie kolumnę i nie zmianę JSON-a. Wspólne kody
mają pliki `Errors.pl.resx` i `Errors.en.resx` w `JJDevHub.ServiceDefaults`. Usługa dokłada
własne pliki przy swoim `Api`, na przykład `NewsErrors.pl.resx`. `LocalizedProblemWriter` szuka
kodu najpierw w zasobach usługi, potem w zasobach wspólnych. `article.title.blank` znajduje się
w pliku News. `precondition.required` znajduje się w pliku wspólnym. Brak klucza w żądanym
języku bierze `pl`. Brak klucza w `pl` wstawia sam kod, więc klient nadal widzi stabilny `type`,
a `title` nie staje się pusty i nie staje się treścią wyjątku.

`Errors.pl.resx` i `Errors.en.resx` mają wiersz na każdy kod z `ErrorCodes`. Klucz równa się
kodowi. Wartość `pl` dla `precondition.required` to zdanie o braku `If-Match`. Wartość `en` jest
tym samym faktem po angielsku. Koszt: każdy nowy kod wymaga dwóch wierszy zasobów. Test
`Known_codes_have_polish_and_english` przechodzi po stałych i sprawdza oba pliki. Kod, który
jest tylko w C#, a nie w obu plikach, nie jest gotowy. Kod, który jest tylko po angielsku, przy
`Accept-Language: pl` albo przy braku nagłówka pokazałby zły język albo sam klucz.

`ServiceDefaultsHttpExtensions.AddApiProblems` rejestruje `RequestLocalizationOptions` z
kulturami `pl` i `en`, kulturą domyślną `pl` i dostawcą `Accept-Language`. Inni dostawcy kultury
są wyłączeni, żeby ciasteczko nie zmieniało języka błędu wbrew nagłówkowi żądania.
`UseRequestLocalization` stoi w `ServiceDefaults`, więc pięć usług i brama nie składają tego
osobno. Brama, gdy odrzuca token, korzysta z tego samego writera. Ten numer nie definiuje
wydania tokenu. Daje writer, z którego numer `16` może skorzystać.

Koszt dwóch plików jest mały przy dwóch kulturach i duży, gdy ktoś dopisze kod w C# i zapomni
zdania. Dlatego test idzie po stałych `ErrorCodes`, a nie po ręcznej liście w teście. Nowy kod
przekrojowy, którego nie ma w teście mapy statusów, też nie przejdzie reguły „każdy kod ma
status”. Mapa niżej jest tą listą. Nic poza nią nie wchodzi do `ErrorCodes`.

### `ProblemDetails` i `Accept-Language`

Odpowiedź błędu to `application/problem+json`. Pole `type` jest kodem (`article.title.blank`
albo `invalid`). Pole `title` jest zdaniem z zasobów. Pole `status` jest statusem HTTP. Przy
`invalid` rozszerzenie `errors` jest tablicą `{ "code", "target" }`. Przy jednym błędzie domeny
`errors` nie występuje, a `type` jest tym jednym kodem. Klient, który czyta `title` po to, żeby
wybrać gałąź, zepsuje się przy `Accept-Language: en`. Gałąź idzie po `type`. Zdanie jest dla
człowieka.

Kultura bierze się z `Accept-Language`. Włączone są `pl` i `en`. Brak nagłówka, gwiazdka albo
nieznany język dają `pl`. Test `Polish_header_translates_title` oczekuje `title` z
`Errors.pl.resx` i `type` równego kodowi. Test `English_header_translates_title` oczekuje zdania
z `Errors.en.resx` przy tym samym `type`. Test `Missing_header_uses_polish` i
`Unknown_language_uses_polish` trzymają domyślne `pl`, także dla `Accept-Language: de`.

Mapa statusów dla `Result`:

| Kod | Status |
| --- | --- |
| `invalid` | 400 |
| `conflict` | 409 |
| `not_found` | 404 |
| `precondition.required` | 428 |
| `precondition.failed` | 412 |
| `precondition.malformed` | 400 |
| `io.unavailable` | 503 |
| `composition.invalid` | 500 |
| `unexpected` | 500 |

Biblioteka `Hellang.Middleware` i inne opakowania `ProblemDetails` przegrywają, bo dokładają
pakiet do rzeczy, którą ASP.NET Core już ma (`ProblemDetails`, `IProblemDetailsService`).
Zostajemy przy typach platformy, licencja nie dochodzi. Koszt: każdy endpoint, który zwraca
`Result`, przechodzi przez `ResultHttpExtensions.ToHttpResult`. Endpoint, który sam składa
`Results.BadRequest("tekst")`, omija słownik. Przegląd endpointu w numerze usługi tego zabrania.
Sukces z wartością zwraca `200` albo status podany przez endpoint (`201` przy tworzeniu).
Porażka woła writer. Endpoint nie składa własnego JSON-a błędu.

`LocalizedProblemWriter.Write(HttpContext, Error head, IReadOnlyList<Error> errors)` ustawia
status z mapy, `Content-Type` na `application/problem+json` i ciało: `type` to `head.Code`,
`title` to zdanie z zasobów, `status` to liczba, `errors` tylko gdy `head.Code` równa się
`invalid`. Jeden składacz pilnuje, żeby `title` było zdaniem, a `type` kodem. Drugi składacz w
usłudze rozjedzie kontrakt przy pierwszym endpoincie artykułu.

### Mapper wyjątku na kod

Wyjątek nie jest oczekiwany na ścieżce reguły biznesowej. Gdy jednak wyleci, middleware
`ExceptionCodeMapper` zamienia go na ten sam `LocalizedProblemWriter`. Reguła artykułu, konflikt
wersji i pusty tytuł nie idą tą ścieżką. Idą jako `Result`. Mapper jest na awarię i na błąd
składu, które handler ma prawo puścić dalej.

| Wyjątek | Kod | Status |
| --- | --- | --- |
| `TimeoutException`, `HttpRequestException`, `DbException`, `IOException` | `io.unavailable` | 503 |
| `InvalidOperationException` z braku handlera albo braku rejestracji | `composition.invalid` | 500 |
| każdy inny | `unexpected` | 500 |

Ciało nie zawiera `Message` wyjątku, stosu ani connection stringa. Test
`Exception_message_is_not_in_body` rzuca `InvalidOperationException` z treścią `connection
string` i oczekuje, że ciało jej nie zawiera, a `type` równa się `composition.invalid`. Wyjątek
idzie do logu z identyfikatorem śladu. `catch` w middleware łapie `Exception` tylko na brzegu
procesu żądania i od razu mapuje. Głębiej w handlerze `catch` łapie konkretny typ albo nie łapie
wcale. Puste `catch` albo logowanie i zwrot `200` zamieniłoby awarię w sukces.

`UseApiProblems` stoi za lokalizacją i przed endpointami. Łapie wyjątek z dalszego potoku, woła
`ExceptionCodeMapper.Map(exception)` i oddaje wynik do writera. Mapper jest `sealed` i nie ma
zależności od bazy. `DbException` rozpoznaje po typie bazowym, więc Npgsql nie wchodzi do
`ServiceDefaults` jako referencja: wystarczy `System.Data.Common.DbException`. Test nie podnosi
Postgresa. Rzuca `TimeoutException` i `InvalidOperationException` do mappera w pamięci.
`Timeout_maps_to_unavailable` oczekuje `io.unavailable` i statusu 503.
`Db_exception_maps_to_unavailable` robi to samo na testowym `DbException`.
`Unknown_exception_maps_to_unexpected` oczekuje `unexpected` i 500.

Koszt: nowy wyjątek biblioteczny wpada w `unexpected`, dopóki ktoś nie dopisze wiersza w
mapperze i testu. To jest cel. Nie chcemy cichego `200` przy awarii. Nie chcemy też, żeby każdy
nowy typ z NuGet dostał własny kod bez decyzji. `503` zostaje przy IO, które klient może
ponowić. `500` zostaje przy składzie i przy niespodziance, której ponawianie nie leczy.

### `ETag` i `If-Match`

`Version` strumienia z numeru `09` jest silnym `ETag` zapisu: nagłówek `ETag: "4"` oznacza
czwarty fakt. `EntityTag.FromVersion` i `EntityTag.TryParse` leżą w
`JJDevHub.ServiceDefaults/Http/EntityTag.cs`. Słaby `ETag` widoku publicznego, złożony z rewizji
projekcji, dojdzie przy usługach. Ten numer definiuje silny znacznik zapisu. Dwa okna z
artykułem w wersji 4 dostają ten sam cytowany napis. Pierwsze zapisuje wersję 5. Drugie, jeśli
wyśle `If-Match: "4"`, a strumień jest już na 5, dostaje `412`.

`IfMatchFilter` na endpoincie zapisu:

- brak `If-Match` zwraca `428` i kod `precondition.required`,
- wartość, której nie da się odczytać jako liczby wersji, zwraca `400` i kod
  `precondition.malformed`,
- wartość inna niż bieżąca `Version` zwraca `412` i kod `precondition.failed`,
- wartość równa wersji puszcza komendę dalej. Oczekiwana wersja w komendzie jest tą liczbą.

`EntityTag.FromVersion(int version)` zwraca cytowany napis, na przykład `"4"`. `TryParse`
akceptuje tylko tę formę. Gwiazdka `*` nie przechodzi. Test `Malformed_if_match_returns_400`
wysyła `If-Match: *` i oczekuje `400` oraz `precondition.malformed`. Test
`Missing_if_match_returns_428` przy wersji w tle równej 3 oczekuje `428` i
`precondition.required`. Test `Stale_if_match_returns_412` przy `If-Match: "2"` i wersji 3
oczekuje `412` i `precondition.failed`. Test `Matching_if_match_calls_handler` przy `"3"` i
wersji 3 woła handler raz.

Filtr implementuje `IEndpointFilter`. Endpoint zapisu dodaje go jawnie. Odczyt go nie dodaje.
Filtr czyta nagłówek i porównuje z wersją dostarczoną przez delegata `Func<CancellationToken,
Task<int?>>`. `null` z delegata oznacza brak agregatu i kończy się `404` z kodem `not_found`,
zanim sprawdzi znacznik. Dzięki temu brak wiersza nie staje się `412`. Klient, który pyta o
nieistniejący slug, nie dostaje informacji „wersja się nie zgadza”, bo wersji nie ma.

Wyścig po przejściu filtra nadal może skończyć się `conflict` z `AppendAsync`. Dwa żądania mogły
zobaczyć wersję 4, filtr obu przepuścił `"4"`, a tylko jedno dopisało wersję 5. Drugie dostaje
`conflict` z magazynu. Na brzegu HTTP ten `conflict` też staje się `412`, bo dla klienta to ten
sam fakt: wersja, którą wysłał, już nie jest ostatnia. Slug zajęty przez inny agregat zostaje
`409` i kodem `conflict`. Filtr nie rozróżnia tych dwóch `conflict` sam. Handler zwraca albo
`precondition.failed`, albo `conflict`, a mapa statusów z tabeli wyżej jest wierna kodowi.
Zamiana każdego `conflict` na `412` w filtrze zgubiłaby zajęty slug.

Koszt: klient musi pamiętać `ETag` z `GET`. Zapis bez wcześniejszego odczytu nie przejdzie. To
jest uczciwe dla intranetu, gdzie owner edytuje istniejący agregat. Utworzenie nowego
strumienia, z oczekiwaną wersją `0`, jest osobną komendą i nie udaje poprawki istniejącego
artykułu. `If-None-Match` i `304` nie wchodzą w ten filtr.

### Ukryta treść jako `404`

Gdy czytelnik nie ma prawa widzieć wiersza, odpowiedź jest taka sama jak przy braku wiersza:
status `404`, kod `not_found`, ten sam `title` z zasobów. Osobny kod `article.hidden` nie
wychodzi do tego klienta. Zostaje w logu na poziomie `Debug`, bez sluga w treści, jeśli slug sam
w sobie jest treścią niepubliczną. Owner, który ma prawo, dostaje prawdziwy stan, a brak wiersza
u ownera nadal jest `404`. Szkic notatki dla anonima i lekcja niewidoczna dla studenta
korzystają z tego samego kształtu. Nie ma osobnej ścieżki „ukryte CV” i osobnej „ukryta notatka”
na poziomie statusu.

`403` przegrywa, bo potwierdza istnienie szkicu. Ktoś, kto zgaduje slug, dowiedziałby się, że
artykuł jest, tylko nie dla niego. `401` zostaje dla braku i dla złego tokenu i nie mówi nic o
wierszu. Zły podpis na bramie w ogóle nie dochodzi do usługi. To numer `16`. Tu, gdy żądanie już
jest w handlerze zapytania, brak prawa do treści nie jest brakiem tokenu. Jest `not_found`.

`HiddenAsNotFound.ForReader()` zwraca `Result<T>.Fail(ErrorCodes.NotFound)` bez dodatkowego
kodu. Handler, który stwierdzi brak prawa do treści, woła tę metodę i nie zwraca `403`. Test
hosta w tym numerze stawia minimalny endpoint: rola inna niż `owner` dostaje `404`, a ciało nie
zawiera słowa `hidden`. Test `Hidden_article_returns_404` woła `GET` bez roli `owner` i oczekuje
statusu `404` oraz ciała bez `hidden`. Koszt: owner i anonim dostają ten sam kształt przy braku
prawa. Test musi mieć dwa układy: owner widzi szkic, anonim dostaje `404` bez kodu
`article.hidden` w ciele. Jeden układ nie dowodzi drugiego.

Decyzję „ukryć czy pokazać” podejmuje handler zapytania w `Application`. Filtr HTTP nie zgaduje
po roli, bo widoczność zależy od stanu wiersza, nie od tabeli tras. Brama nie zwraca `403` za
złą rolę z tego samego powodu. Rola `owner` albo `student` jest sprawdzana w usłudze, gdy numer
usługi to dopnie. Ten numer daje pomocnik i test minimalnego endpointu, nie słownik ról.

## Klasy i ścieżki

Kontrakt błędu jest rozdzielony tak, żeby kernel nie znał HTTP, a brzeg nie znał reguły
artykułu. `Error` i `ErrorCodes` zostają w kernelu. Zdania, writer, mapper, `ETag` i filtr
zostają w `ServiceDefaults`, bo pięć usług i brama mają mówić jednym kształtem. Walidator
konkretnej komendy zostaje w `{Usługa}.Application` i powstaje razem z komendą. Ten numer daje
mu kontrakt: `WithErrorCode`, zasób w dwóch językach, brak wyjątku.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Shared.Kernel/Error.cs` | `Code`, `Target` |
| `src/shared/JJDevHub.Shared.Kernel/ErrorCodes.cs` | kody przekrojowe, bez nazw usług |
| `src/shared/JJDevHub.Shared.Kernel/Result.cs` | `Ok`, `Fail`, lista `Error` przy `invalid` |
| `src/shared/JJDevHub.ServiceDefaults/Http/LocalizedProblemWriter.cs` | `ProblemDetails` z zasobów |
| `src/shared/JJDevHub.ServiceDefaults/Http/ExceptionCodeMapper.cs` | wyjątek na kod i status |
| `src/shared/JJDevHub.ServiceDefaults/Http/ResultHttpExtensions.cs` | `ToHttpResult` |
| `src/shared/JJDevHub.ServiceDefaults/Http/EntityTag.cs` | wersja strumienia na `ETag` |
| `src/shared/JJDevHub.ServiceDefaults/Http/IfMatchFilter.cs` | `428`, `412`, zły format |
| `src/shared/JJDevHub.ServiceDefaults/Http/HiddenAsNotFound.cs` | pomocnik: ukrycie zapisuje się jako `not_found` |
| `src/shared/JJDevHub.ServiceDefaults/Resources/Errors.pl.resx` | zdania wspólne po polsku |
| `src/shared/JJDevHub.ServiceDefaults/Resources/Errors.en.resx` | zdania wspólne po angielsku |
| `src/shared/JJDevHub.ServiceDefaults/ServiceDefaultsHttpExtensions.cs` | lokalizacja, middleware wyjątku |
| `tests/JJDevHub.ServiceDefaults.Tests/LocalizedProblemWriterTests.cs` | język i brak wycieku wyjątku |
| `tests/JJDevHub.ServiceDefaults.Tests/IfMatchFilterTests.cs` | `428` i `412` |
| `tests/JJDevHub.ServiceDefaults.Tests/ExceptionCodeMapperTests.cs` | IO i skład |
| `tests/JJDevHub.Cqrs.Tests/ValidatorBehaviorTests.cs` | już z numeru `10`, kody pól dochodzą tutaj |

`ArticleErrors` i bliźniacze klasy usług nie mają wiersza w tej tabeli, bo powstają razem z
komendą. Ich miejsce jest ustalone: stała obok walidatora, klucz w `resx` usługi, nigdy wpis w
`ErrorCodes`. Testy tego numeru są jednostkowe i na `WebApplicationFactory` bez bazy. Nie mają
cechy `Integration`.

## Plan

### 1. `Error` w kernelu

`Error` jest `sealed record` z polami `Code` (`string`) i `Target` (`string?`). `Result<T>` już
istnieje. `Fail` przyjmuje jeden `Error` albo listę przy kodzie zbiorczym `invalid`. `IsSuccess`
jest fałszywe, gdy lista nie jest pusta. Kernel nadal nie referencjonuje ASP.NET,
FluentValidation ani EF.

`ErrorCodes` jest klasą `static`. Stałe to wyłącznie kody z tabeli statusów. Nie ma w niej
`article.title.blank`.

### 2. Zachowanie walidacji dopisuje kody pól

`ValidatorBehavior` z numeru `10` buduje `Error` tak:

- `Code` równe `failure.ErrorCode`, a gdy puste — wyjątek składu w teście, w produkcji kod
  `invalid` bez `Target` i log `Warning` z nazwą typu żądania,
- `Target` równe `failure.PropertyName` w camelCase, tak jak JSON.

Nie woła `next`. Nie loguje wartości, która nie przeszła reguły. Loguje nazwę pola i kod.

Przykład walidatora, który numer usługi skopiuje:

```csharp
namespace JJDevHub.News.Application
{
    public sealed class CreateArticleCommandValidator : AbstractValidator<CreateArticleCommand>
    {
        public CreateArticleCommandValidator()
        {
            RuleFor(command => command.Title)
                .NotEmpty()
                .WithErrorCode(ArticleErrors.TitleBlank);
        }
    }
}
```

`ArticleErrors.TitleBlank` równa się `article.title.blank`.

### 3. Zasoby i lokalizacja

`Errors.pl.resx` i `Errors.en.resx` mają wiersz na każdy kod z `ErrorCodes`. Klucz równa się
kodowi. Wartość `pl` dla `precondition.required` to zdanie o braku `If-Match`. Wartość `en` jest
tym samym faktem po angielsku.

`ServiceDefaultsHttpExtensions.AddApiProblems` rejestruje `RequestLocalizationOptions` z
kulturami `pl` i `en`, kulturą domyślną `pl` i dostawcą `Accept-Language`. Inni dostawcy kultury
są wyłączeni, żeby ciasteczko nie zmieniało języka błędu wbrew nagłówkowi żądania.

### 4. Zapis `ProblemDetails`

`LocalizedProblemWriter.Write(HttpContext, Error head, IReadOnlyList<Error> errors)` ustawia
status z mapy, `Content-Type` na `application/problem+json` i ciało:

- `type` — `head.Code`,
- `title` — zdanie z zasobów,
- `status` — liczba,
- `errors` — tylko gdy `head.Code` równa się `invalid`.

`ResultHttpExtensions.ToHttpResult` jest metodą rozszerzającą dla `Result<T>`. Sukces z
wartością zwraca `200` albo status podany przez endpoint (`201` przy tworzeniu). Porażka woła
writer. Endpoint nie składa własnego JSON-a błędu.

### 5. Middleware wyjątku

`UseApiProblems` stoi za lokalizacją i przed endpointami. Łapie wyjątek z dalszego potoku, woła
`ExceptionCodeMapper.Map(exception)` i oddaje wynik do writera. Mapper jest `sealed` i nie ma
zależności od bazy. `DbException` rozpoznaje po typie bazowym, więc Npgsql nie wchodzi do
`ServiceDefaults` jako referencja: wystarczy `System.Data.Common.DbException`.

Test nie podnosi Postgresa. Rzuca `TimeoutException` i `InvalidOperationException` do mappera w
pamięci.

### 6. `If-Match`

`EntityTag.FromVersion(int version)` zwraca cytowany napis, na przykład `"4"`. `TryParse`
akceptuje tylko tę formę. Gwiazdka `*` nie przechodzi: zapis ma znać konkretną wersję.

`IfMatchFilter` implementuje `IEndpointFilter`. Endpoint zapisu dodaje go jawnie. Odczyt go nie
dodaje. Filtr czyta nagłówek, porównuje z wersją dostarczoną przez delegata
`Func<CancellationToken, Task<int?>>`. `null` z delegata oznacza brak agregatu i kończy się
`404` z kodem `not_found`, zanim sprawdzi znacznik. Dzięki temu brak wiersza nie staje się
`412`.

### 7. Ukrycie

`HiddenAsNotFound.ForReader()` zwraca `Result<T>.Fail(ErrorCodes.NotFound)` bez dodatkowego
kodu. Handler, który stwierdzi brak prawa do treści, woła tę metodę i nie zwraca `403`. Test
hosta w tym numerze stawia minimalny endpoint: rola inna niż `owner` dostaje `404`, a ciało nie
zawiera słowa `hidden`.

### Co jest do czego

- `Error` woła kernel, walidator, handler i writer. Jeden nośnik kodu w całym rozwiązaniu.
  Usługa nie tworzy własnej hierarchii wyjątków domenowych. Bez tego typu `invalid` i `conflict`
  rozjeżdżają się na dwa kształty, a klient nie ma pola `type`.
- `ErrorCodes` woła mapper, filtr i `HiddenAsNotFound`. Słownik statusów wspólnych. Nie puchnie
  o kody notatek i kursów. Bez niego `article.title.blank` albo nazwa usługi weszłaby do
  kernelu, a test „kernel nie zna agregatu” nie miałby czego pilnować.
- `ArticleErrors` i odpowiedniki w innych usługach woła walidator tej usługi. Stałe kontraktu,
  obok walidatora. Bez stałej kod pola jest napisem rozsypanym po regułach i łatwo o literówkę,
  której `resx` nie ma. `ArticleErrors.TitleBlank` równa się `article.title.blank`.
- `ValidatorBehavior` woła `Send` przed transakcją. Zamiana FluentValidation na `invalid` bez
  wyjątku i bez transakcji. Bez kodów pól z tego numeru porażka byłaby zbiorczym `invalid` bez
  `Target`, a pusty tytuł nie podświetliłby `title`.
- `LocalizedProblemWriter` woła `ToHttpResult` i middleware wyjątku. Jedyny składacz ciała
  błędu. Pilnuje, żeby `title` było zdaniem, a `type` kodem. Bez niego endpoint składa
  `Results.BadRequest("tekst")` i omija słownik oraz język.
- `ExceptionCodeMapper` woła `UseApiProblems`. Wyjątek IO i składu wchodzi w ten sam writer. Bez
  niego `TimeoutException` zostaje z `Message` w ciele albo jako `200`. `DbException` rozpoznaje
  po typie bazowym, więc Npgsql nie wchodzi do `ServiceDefaults`.
- `ResultHttpExtensions.ToHttpResult` woła endpoint, który zwraca `Result<T>`. Sukces to `200`
  albo status podany przez endpoint, `201` przy tworzeniu. Porażka woła writer. Bez rozszerzenia
  każdy endpoint składa własny JSON i gubi mapę.
- `EntityTag` woła filtr zapisu i odpowiedź `GET`, która oddaje wersję. Wersja strumienia jako
  silny `ETag`, cytowany napis `"4"`. Bez `TryParse` gwiazdka albo goły napis przeszłyby jako
  wersja i nadpisały artykuł.
- `IfMatchFilter` woła endpoint zapisu, jawnie. `428` przy braku nagłówka, `412` przy złej
  wersji, `400` przy złym formacie, `404` gdy delegat wersji zwróci `null`. Bez filtra dwa okna
  nadpisują slug. Odczyt go nie dodaje.
- `HiddenAsNotFound` woła handler zapytania, gdy czytelnik nie ma prawa. Jeden kształt braku dla
  treści niewidocznej: `not_found`, bez `403` i bez `article.hidden` w ciele. Bez pomocnika
  łatwo zwrócić osobny kod, który zdradza szkic.
- Pliki `resx` woła writer. Jedyne miejsce zdań. `Errors.pl.resx` i `Errors.en.resx` dla kodów
  wspólnych, plik usługi dla `article.title.blank`. Bez wiersza w obu językach test
  `Known_codes_have_polish_and_english` pada. Dodanie języka jest nowym plikiem, nie kolumną.
- `AddApiProblems` i `UseApiProblems` woła `ServiceDefaults`, więc pięć usług i brama nie
  składają lokalizacji osobno. Bez tego ciasteczko mogłoby zmienić język błędu wbrew
  `Accept-Language`, a wyjątek wyszedłby przed writerem.

## Testy

Runner xUnit. Testy tego numeru są jednostkowe i na `WebApplicationFactory` bez bazy. Nie mają
cechy `Integration`. Każdy fakt ma jeden powód do padnięcia. Walidacja nie podnosi Postgresa.
Filtr `If-Match` stoi na endpoincie testowym fabryki. JWKS i prawdziwy token nie są tu
potrzebne: rola w teście ukrycia jest układem endpointu, nie wydaniem z Identity.

Klasa `ValidatorBehaviorTests`, uzupełnienie numeru `10`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Blank_title_returns_field_code` | walidator z `WithErrorCode("article.title.blank")`, pusty tytuł | `Send` | kod `invalid` i element `article.title.blank` z `Target` `title` |
| `Validation_does_not_throw` | pusty tytuł | `Send` | metoda zwraca `Result`, nie wyjątek |

Klasa `LocalizedProblemWriterTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Polish_header_translates_title` | `Accept-Language: pl`, kod `precondition.required` | zapis odpowiedzi | `title` równe zdaniu z `Errors.pl.resx`, `type` równe kodowi |
| `English_header_translates_title` | `Accept-Language: en`, ten sam kod | zapis odpowiedzi | `title` z `Errors.en.resx` |
| `Missing_header_uses_polish` | brak `Accept-Language` | zapis odpowiedzi | `title` z pliku `pl` |
| `Unknown_language_uses_polish` | `Accept-Language: de` | zapis odpowiedzi | `title` z pliku `pl` |
| `Exception_message_is_not_in_body` | `InvalidOperationException` z treścią `connection string` | middleware | ciało nie zawiera tej treści, `type` równe `composition.invalid` |

Klasa `ExceptionCodeMapperTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Timeout_maps_to_unavailable` | `TimeoutException` | `Map` | kod `io.unavailable`, status 503 |
| `Db_exception_maps_to_unavailable` | testowy `DbException` | `Map` | kod `io.unavailable` |
| `Unknown_exception_maps_to_unexpected` | `Exception` | `Map` | kod `unexpected`, status 500 |

Klasa `IfMatchFilterTests` na endpoincie testowym fabryki.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Missing_if_match_returns_428` | zapis bez nagłówka, wersja w tle równa 3 | `PUT` | status 428, `type` równe `precondition.required` |
| `Stale_if_match_returns_412` | `If-Match: "2"`, wersja 3 | `PUT` | status 412, `type` równe `precondition.failed` |
| `Matching_if_match_calls_handler` | `If-Match: "3"`, wersja 3 | `PUT` | handler wołany raz |
| `Malformed_if_match_returns_400` | `If-Match: *` | `PUT` | status 400, `type` równe `precondition.malformed` |
| `Hidden_article_returns_404` | endpoint zwracający `HiddenAsNotFound` | `GET` bez roli `owner` | status 404, ciało bez `hidden` |

```bash
dotnet test tests/JJDevHub.ServiceDefaults.Tests tests/JJDevHub.Cqrs.Tests
```

Padnięcie tłumaczenia `en` nie może być tym samym faktem co padnięcie `428`. Dlatego język,
mapper i filtr są osobnymi klasami. Test `Known_codes_have_polish_and_english` idzie po stałych
`ErrorCodes` i po obu plikach `resx`. Mapa statusów ma wiersz na każdy kod z tej listy. Kod
spoza listy nie wchodzi do kernelu.

## Zasady

- Oczekiwany błąd to `Result<T>` z `Error`. Wyjątek zostaje dla IO i błędu składu. Złamanie
  rzuca `ValidationException` albo zamienia timeout w `conflict`.
- FluentValidation nie kończy się `ValidationException` na brzegu HTTP. Złamanie omija
  `ProblemDetails` i zostawia angielski komunikat biblioteki w ciele.
- `type` w `ProblemDetails` jest kodem. `title` jest zdaniem z zasobów wybranej kultury.
  Złamanie każe klientowi rozgałęziać się po zdaniu, które zmienia `Accept-Language`.
- `Accept-Language` decyduje o zdaniu. Brak i nieznany język dają `pl`. Złamanie oddaje `en`
  albo język z ciasteczka wbrew nagłówkowi żądania.
- Kod usługi nie leży w kernelu. Kernel nie zna nazw agregatów. Złamanie wkłada
  `article.title.blank` do `ErrorCodes` i wiąże wspólny pakiet z News.
- Zapis z `ETag` wymaga `If-Match`. Brak to `428`. Nieaktualny znacznik to `412`. Złamanie
  pozwala dwóm oknom nadpisać artykuł bez wersji, którą klient widział.
- Treść niewidoczna dla czytelnika to `404` i kod `not_found`. Złamanie zwraca `403` albo
  `article.hidden` i potwierdza, że szkic istnieje.
- Ciało błędu nie zawiera komunikatu wyjątku ani wartości odrzuconego pola. Złamanie wypisuje
  connection string albo odrzucony tytuł do JSON-a.
- `Core` nie referencjonuje FluentValidation ani ASP.NET. Złamanie wciąga value object w
  atrybuty HTTP i w pakiet walidacji.
- Każdy nowy kod przekrojowy dostaje wiersz w obu `resx` i wiersz w teście mapy statusów.
  Złamanie zostawia kod bez zdania albo bez statusu, a writer wstawia sam klucz albo zgaduje
  `500`.

## Poza zakresem

- Łańcuch zachowań i samo `ValidatorBehavior` jako klasa są w [10-cqrs.md](10-cqrs.md). Ten
  numer dopisuje kody pól i zakaz `ValidationException`, nie drugi mediator.
- Wersja strumienia w Postgresie jest w [09-persistence.md](09-persistence.md). Tu `Version`
  staje się silnym `ETag`. Kolumna i `conflict` z `23505` już istnieją.
- Widok, z którego `GET` bierze ciało sukcesu, jest w [12-projekcja.md](12-projekcja.md). Ten
  numer mówi, jak wygląda błąd odczytu, w tym `404` dla treści niewidocznej, a nie jak powstaje
  wiersz.
- Sprawdzenie podpisu JWT na bramie jest w [16-gateway.md](16-gateway.md). `401` za zły podpis
  nie zastępuje `404` za ukryty szkic.
- Wydanie tokenu i ról `owner` oraz `student` jest w [17-identity.md](17-identity.md). Tu rola w
  teście ukrycia jest układem endpointu.
- Konkretne kody notatki, kursu, CV i zapytań są w numerach usług, od [18-news.md](18-news.md).
  `article.title.blank` jest wzorem stałej, nie pełnym słownikiem News.
- `If-None-Match` i `304` na publicznym widoku dojdą w numerze usługi, która ten widok ma. Ten
  numer ich nie definiuje.

## Źródła

- [FluentValidation](https://docs.fluentvalidation.net/). Wiążące są reguły, `ErrorCode`,
  `ValidateAsync` i licencja Apache-2.0. W tym pliku walidator woła `WithErrorCode`, a
  `ValidatorBehavior` nie używa `ValidationException`. Nie bierzemy komunikatu domyślnego, po
  angielsku, jako `title`. Zdanie jest w `resx`. Nie bierzemy też drugiej biblioteki walidacji
  obok pakietu już obecnego w `JJDevHub.Cqrs`.
- [Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457). Wiążące są `type`,
  `title` i `status` oraz rozszerzenia. W tym pliku `type` jest kodem, `title` zdaniem, a
  `errors` dochodzi tylko przy `invalid`. Nie bierzemy `type` jako adresu URL, którego ten
  kontrakt nie obiecuje. Nie bierzemy treści wyjątku jako `title`. `Content-Type` to
  `application/problem+json`.
- [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585). Wiążący jest status `428 Precondition
  Required`: zapis, który wymaga warunku, a warunku nie dostał. W tym pliku brak `If-Match` na
  endpoincie zapisu daje `428` i `precondition.required`. Nie bierzemy stąd `429` jako limitu
  zapytań. Limitu ten numer nie buduje. `412` opisuje osobno RFC 9110, bo zły znacznik to inny
  fakt niż brak nagłówka.
- [RFC 9110: 428 Precondition Required](https://www.rfc-editor.org/rfc/rfc9110#status.428).
  Wiążące jest utrzymanie `428` w semantyce HTTP: brak `If-Match` przy zapisie, który znacznik
  wymaga. W tym pliku dotyczy to `IfMatchFilter` i zdania w `Errors.pl.resx` o braku nagłówka.
  Nie bierzemy `428` na odczycie. Odczyt filtra nie dodaje. Nie bierzemy też `428` zamiast
  `404`, gdy agregatu nie ma: delegat wersji równy `null` kończy się `not_found`, zanim filtr
  sprawdzi znacznik.
- [RFC 9110: 412 Precondition Failed](https://www.rfc-editor.org/rfc/rfc9110#status.412).
  Wiążące jest to, że znacznik nie pasuje do bieżącej reprezentacji. W tym pliku `If-Match: "2"`
  przy wersji 3 daje `412` i `precondition.failed`. Ten sam status dostaje `conflict` z
  `AppendAsync`, gdy chodzi o wersję, którą klient wysłał. Nie bierzemy `412` dla sluga zajętego
  przez inny agregat: to zostaje `409` i kod `conflict`.
- [RFC 9110: Conditional
  requests](https://www.rfc-editor.org/rfc/rfc9110#name-conditional-requests). Wiążący jest
  silny `ETag` i `If-Match`. W tym pliku `EntityTag.FromVersion` zwraca cytowany napis, na
  przykład `"4"`, a `TryParse` odrzuca gwiazdkę. Nie bierzemy słabego walidatora w tym numerze.
  Słaby `ETag` widoku publicznego dojdzie z numerem usługi. Nie bierzemy `If-None-Match` ani
  `304`.
- [RFC 9110: 404 Not Found](https://www.rfc-editor.org/rfc/rfc9110#status.404). Wiążące jest to,
  że serwer nie oddaje reprezentacji. W tym pliku ten sam status i kod `not_found` dostaje brak
  wiersza oraz treść niewidoczna dla czytelnika. Nie bierzemy `403` jako sygnału „wiersz jest,
  ale nie dla ciebie”. `article.hidden` zostaje w logu `Debug`, nie w ciele. `401` zostaje przy
  tokenie i nie mówi o wierszu.
- [ASP.NET Core
  localization](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/localization).
  Wiążące są `Accept-Language` i zasoby `.resx`. W tym pliku kultury to `pl` i `en`, domyślna
  jest `pl`, a inni dostawcy są wyłączeni, żeby ciasteczko nie zmieniło języka. Nie bierzemy
  tłumaczenia z bazy ani z kolumny. Brak klucza w żądanym języku bierze `pl`. Brak klucza w `pl`
  wstawia sam kod.
- [Handle errors in ASP.NET
  Core](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/error-handling). Wiążące jest
  łapanie wyjątku na brzegu, bez treści wyjątku w ciele odpowiedzi. W tym pliku `UseApiProblems`
  stoi za lokalizacją i przed endpointami, a mapper nie wkłada `Message` do JSON-a. Nie bierzemy
  `Hellang.Middleware` ani innego opakowania, które dokłada pakiet do `ProblemDetails` i
  `IProblemDetailsService` już obecnych w platformie.
- Gregory Young, *Versioning in an Event Sourced System*. Wiążąca jest oczekiwana wersja, którą
  klient musiał przeczytać, zanim dopisze fakt. W tym pliku ta liczba jest silnym `ETag` i
  wartością `If-Match`. Nie bierzemy stąd słabego znacznika widoku ani zapisu bez wcześniejszego
  odczytu. Gwiazdka nie zastępuje konkretnej wersji. Wyścig po filtrze nadal kończy się
  `conflict` w magazynie i `412` na brzegu, gdy chodzi o tę samą wersję.
- Eric Evans, *Domain-Driven Design*. Wiążące jest trzymanie niezmiennika w modelu, nie w
  atrybucie transportu. W tym pliku `ArticleTitle.Create` zostaje źródłem prawdy, a walidator
  tylko woła `Must` i `WithErrorCode`, zanim otworzy się transakcja. Nie bierzemy Data
  Annotations na rekordzie komendy. Nie bierzemy też wyjątków domenowych jako drugiego kanału
  obok `Result`. `Core` nie referencjonuje FluentValidation.

## Gotowe gdy

- Pusty tytuł w teście walidatora daje `invalid` i kod `article.title.blank` bez wyjątku.
- `Accept-Language: en` zmienia `title` i nie zmienia `type`.
- Brak nagłówka języka daje zdanie polskie.
- `TimeoutException` daje `503` i kod `io.unavailable`, a treść wyjątku nie wchodzi do JSON-a.
- `PUT` bez `If-Match` daje `428`. `PUT` ze starym znacznikiem daje `412`.
- Odczyt treści ukrytej daje `404` i ciało bez osobnego kodu ukrycia.
- `ErrorCodes` nie zawiera nazwy usługi ani agregatu.
- `dotnet test tests/JJDevHub.ServiceDefaults.Tests tests/JJDevHub.Cqrs.Tests` kończy się kodem
  0.
