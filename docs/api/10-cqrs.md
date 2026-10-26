# 10. Mediator i zachowania

Ten numer stawia własny mediator w `src/shared/JJDevHub.Cqrs`. Każda komenda i każde zapytanie
wchodzi przez `IMediator.Send`, przechodzi zachowania i trafia do jednego handlera. Magazyn, do
którego handler zapisze strumień, jest w [09-persistence.md](09-persistence.md). Kody błędów,
język `ProblemDetails` i `ETag` są w [11-walidacja.md](11-walidacja.md). Bez tego numeru każdy
endpoint sam otwiera transakcję, sam loguje i sam woła walidację. Drugi endpoint kopiuje te
linie albo je gubi, a zapis artykułu potrafi zatwierdzić strumień bez wspólnej transakcji z
późniejszym outboxem.

`Core` usługi zna tylko `JJDevHub.Shared.Kernel`. Nie referencjonuje `JJDevHub.Cqrs`, nie widzi
`IMediator` i nie zna zachowań. Handlery żyją w `Application`. `Api` woła `AddCqrs` w
`Program.cs` i jest jedynym miejscem, które składa konkretne porty. Agregat artykułu nie wie, że
ktoś wysłał `CreateArticleCommand`. Wie tylko, jak przyjąć fakt. Mediator jest sprawą przypadku
użycia, nie sprawą domeny.

Scenariusz, który bez łańcucha się rozpada, zaczyna się od pustego tytułu. Walidator `NotEmpty`
na `Name` ma odrzucić żądanie, zanim `TransactionBehavior` zawoła `BeginAsync`. Gdy walidacja
stoi w handlerze za otwarciem transakcji, pusty tytuł zdąży wziąć połączenie z Postgresa i
dopiero potem wrócić `invalid`. Drugi scenariusz to komenda, która dopisuje strumień i ma
zostawić wiersz outboxa. Bez jednego `IUnitOfWork` na `*WriteContext` `AppendAsync` albo otworzy
własną transakcję i zatwierdzi fakt, zanim handler dojdzie do outboxa, albo zapisze oba poza
wspólnym commitem. Trzeci scenariusz to zapytanie o listę. `IQuery<T>` nie może otworzyć bazy
zapisu i nie może wołać `IEventStore`. Ta reguła jest w typie żądania i w zachowaniu, nie w
komentarzu przy handlerze.

Oczekiwany błąd handlera to `Result<T>`. Brak handlera w kontenerze to błąd składu: wyjątek
`InvalidOperationException` z nazwą typu żądania. Walidacja nie rzuca wyjątku do klienta. Zwraca
`Result` z kodem `invalid`. Szczegół pól i tłumaczenie są w numerze `11`. Tu powstaje tylko
miejsce w łańcuchu, które ten wynik potrafi zwrócić bez wołania handlera. Log widzi także
odrzucenie: zapisuje nazwę typu i kod, a nie treść notatki i nie treść zapytania Contact.

## Po co

Endpoint, który sam tworzy agregat, sam otwiera transakcję i sam loguje, miesza przypadek użycia
z rzeczami wspólnymi dla wszystkich żądań. Drugi endpoint skopiuje te same linie albo je zgubi.
Mediator daje jedno wejście. Handler zostaje metodą `Handle`, którą da się zawołać z testu bez
HTTP. `CreateArticleCommand` i `CreateArticleCommandHandler` leżą obok siebie w `Application`,
bo `Send` nie prowadzi „go to definition” do handlera. Nazwa pliku jest tą rekompensatą. Jest
jeden poziom pośredni i jeden słownik wrapperów w pamięci procesu.

Trzy rzeczy mają dziać się zawsze, w tej samej kolejności, zanim handler zobaczy komendę albo
tuż wokół niej. Log bez treści pól, bo pole może być treścią notatki albo treścią zapytania
Contact. Walidacja, która odrzuca żądanie przed otwarciem transakcji. Transakcja dla komendy, w
której `AppendAsync` z numeru `09` i późniejszy wiersz outboxa zatwierdzą się razem. `AddCqrs`
rejestruje `LoggingBehavior`, potem `ValidatorBehavior`, potem `TransactionBehavior`. Pierwsze
zarejestrowane zachowanie jest najbardziej zewnętrzne. Log obejmuje porażkę walidacji.
Transakcja nie otwiera się, gdy walidacja zwróci `invalid`. Test
`Behaviors_wrap_in_registration_order` pilnuje tej kolejności napisem w liście wywołań: `a>`,
`b>`, `handler`, `<b`, `<a`.

Zapytanie nie otwiera transakcji zapisu i nie woła `IEventStore`. Odczyt artykułu po slugu, gdy
powstanie, idzie portem czytnika z numeru `12`, nie strumieniem. Komenda w komendzie, gdy
transakcja już jest, nie otwiera drugiej. `HasActiveTransaction` równe true oznacza `next` bez
drugiego `Begin`. Porażka `Result`, na przykład kod `conflict` ze starej wersji strumienia, woła
`RollbackAsync`. Wyjątek z handlera, na przykład `IOException`, też woła `RollbackAsync`, a
potem leci dalej. Mediator go nie połyka. Na brzegu HTTP i tak stanie się `ProblemDetails`, ale
to numer `11`.

Brak handlera nie jest `not_found`. To pomyłka składu hosta: ktoś wysłał typ, którego nikt nie
zarejestrował. `InvalidOperationException` ma w treści nazwę tego typu, żeby test hosta pokazał
brakującą linię, a nie pustą stronę. Brak `IUnitOfWork` przy komendzie, która go wymaga, jest
tym samym rodzajem błędu. Zapytanie przy braku `IUnitOfWork` idzie dalej, bo odczyt transakcji
zapisu nie potrzebuje. Ciche zapisanie komendy poza transakcją byłoby gorsze niż wyjątek:
artykuł zostałby w bazie, a test by tego nie zobaczył aż do rozjazdu z outboxem.

`Application` referencjonuje `Core`, `JJDevHub.Shared.Kernel` i `JJDevHub.Cqrs`. Porty
(`IEventStore`, później `IIntegrationEventOutbox`, później `IReadCache`) są interfejsami, które
`Application` widzi, a `Persistence` i `Infrastructure` implementują. `Api` składa
implementacje. Ta biblioteka nie referencjonuje żadnej usługi, Entity Framework, Kafki ani
ASP.NET. Dzięki temu test łańcucha stoi na `ServiceCollection`, na fałszywych handlerach i na
`FakeUnitOfWork`, bez kontenera Dockera.

## Dlaczego ta technologia

### Własny mediator

Mediator to obiekt, który z typu żądania znajduje jeden handler i woła go. Endpoint zależy od
`IMediator`, nie od `CreateArticleCommandHandler`. Dzięki temu nowe zachowanie dochodzi w jednym
miejscu, a endpoint się nie zmienia. W `Send` znany jest `TResponse`, a typ żądania dopiero w
czasie wykonania. Dlatego `RequestHandlerWrapper<TResponse>` jest abstrakcyjną bazą, a
`RequestHandlerWrapperImpl<TRequest, TResponse>` rzutuje żądanie, bierze
`IRequestHandler<TRequest, TResponse>` i składa zachowania od końca. Statyczny
`ConcurrentDictionary<Type, object>` trzyma wrapper na typ żądania, więc `MakeGenericType` idzie
raz na typ, nie raz na żądanie HTTP.

Wołanie handlera wprost z endpointu przegrywa, gdy dochodzi log, walidacja i transakcja. Każdy
handler zaczyna wtedy od tych samych kroków albo endpoint robi je sam i łatwo pominąć transakcję
przy nowej komendzie, na przykład przy przyjęciu zapytania Contact. Kontener, który wstrzykuje
handler do endpointu, nie daje łańcucha: walidator trzeba pamiętać osobno, a `BeginAsync` też.
Test `Send_reaches_handler` pokazuje, że `Ok(42)` wraca z handlera przez `Send`. Test
`Send_without_handler_throws` pokazuje, że brak rejestracji nie zamienia się w pusty sukces.

Koszt: `Send` nie prowadzi „go to definition” do handlera. Nazwa pliku to rekompensata. Jest
jeden poziom pośredni i jeden słownik w procesie. `CancellationToken` idzie do handlera i do
każdego zachowania, co sprawdza `Send_passes_cancellation_token`. Zachowanie nie podmienia kodu
błędu domeny po `next`. Może pracować przed `next`, zawołać `next` albo zwrócić wynik bez
`next`. Po `next` tylko obserwuje. Inaczej log albo transakcja mogłyby zamienić `conflict`
artykułu na inny kod i zepsuć mapę statusów z numeru `11`.

### MediatR odpada przez licencję

MediatR od wersji 13 ma licencję, która nie jest otwarta i darmowa produkcyjnie w sposób
bezwarunkowy. Przypinanie starszej linii tylko po to, żeby zostać przy Apache-2.0, zostawia
projekt na pakiecie bez poprawek. Tego nie robimy. Pakiet nie wchodzi do
`Directory.Packages.props`. `JJDevHub.Cqrs.csproj` nie referencjonuje MediatR. Własny mediator w
tym repozytorium jest treścią numeru: widać, jak z `IServiceProvider` zamyka się typ generyczny,
jak cache trzyma wrapper na typ żądania i jak zachowania owijają się od końca.

Interfejsy nazywają się tak, jak czyta je reszta rynku: `IRequest<TResponse>`,
`IPipelineBehavior<TRequest, TResponse>`, `RequestHandlerDelegate<TResponse>`. Nazwa jest po to,
żeby czytelnik rozpoznał kształt, a nie po to, żeby wciągnąć cudzy pakiet. Biblioteka generująca
kod źródłowy pod mediator (licencja MIT) przegrywa, bo chowa właśnie ten mechanizm, a tu
mechanizm jest przedmiotem numeru. Wolverine (MIT) przegrywa, bo razem z mediatorem przejmuje
transport i outbox, a te części mają własne numery: [14-outbox.md](14-outbox.md) i
[15-kafka.md](15-kafka.md). Gdyby transport siedział w mediatorze, test `TransactionBehavior`
ciągnąłby brokera, a dyspozytor outboxa nie byłby naszą pętlą.

Koszt: brak gotowych rozszerzeń z ekosystemu MediatR. Każde nowe zachowanie piszemy tutaj. Przy
trzech zachowaniach to mały koszt. Nie dokładamy czwartego „na zapas”. Log, walidacja i
transakcja wyczerpują to, co ma być wspólne, zanim powstanie konkretna komenda artykułu.
Kolejność jest jedna i jest testowana. Zmiana kolejności wymaga zmiany testu
`Behaviors_wrap_in_registration_order`, a nie cichej poprawki w `Program.cs` usługi.

### Łańcuch zachowań jako open generic

`IPipelineBehavior<TRequest, TResponse>` rejestruje się jako otwarty typ generyczny. Kontener
zamyka go dla konkretnej komendy w chwili `Send`. Nowa komenda, choćby `CreateArticleCommand`,
nie wymaga nowej linii rejestracji zachowań. Wymaga handlera i, gdy ma reguły wejścia,
walidatora w tym samym zestawie, który `AddCqrs` dostał w `params Assembly[]`.
`AddValidatorsFromAssemblies(assemblies, ServiceLifetime.Scoped)` rejestruje walidatory jako
scoped, razem z handlerami. `IMediator` jest `Mediator`. Trzy zachowania idą jako open generic,
w kolejności log, walidacja, transakcja.

Kolejność rejestracji jest kolejnością owijania. Pierwsze zarejestrowane zachowanie jest
najbardziej zewnętrzne. Dekoratory z osobnej biblioteki dałyby ten sam efekt i dokładałyby
pakiet do jednego wywołania. Tego pakietu nie ma: owijanie jest w `RequestHandlerWrapperImpl`,
od końca listy, tak żeby pierwsze zarejestrowane zostało na zewnątrz. Koszt naszego rozwiązania:
zła kolejność w `AddCqrs` zmienia wynik i nie wywraca kompilacji. Walidacja na zewnątrz
transakcji jest decyzją, nie przypadkiem kompilatora. Test zbiera `List<string>` zarejestrowaną
jako singleton i porównuje napis kolejności.

`LoggingBehavior<TRequest, TResponse>` loguje `Handling {RequestName}` przed `next` i `Handled
{RequestName} in {ElapsedMs} ms with {ErrorCode}` po. Do logu wchodzi nazwa typu i kod z
`Result`. Wartości pól nie wchodzą. Treść notatki i treść zapytania Contact zostają w żądaniu,
które żyje w pamięci zakresu, a nie w dzienniku. `ValidatorBehavior<TRequest, TResponse>` bierze
`IEnumerable<IValidator<TRequest>>`. Brak walidatorów oznacza od razu `next`. W przeciwnym razie
woła `ValidateAsync` z tokenem. Gdy którykolwiek wynik ma `IsValid == false`, zachowanie buduje
listę `Error` z `ErrorCode` i `PropertyName`, zwraca `Result<TResponse>.Fail` z kodem zbiorczym
`invalid` i nie woła `next`. `ValidationException` nie jest używany.

Koszt otwartego generyka jest czytelnościowy, nie wydajnościowy. Zamknięcie typu dzieje się raz
na typ żądania i zostaje w słowniku. Nowy programista, który zarejestruje zachowanie po
`AddCqrs` albo przed logiem, zmieni semantykę bez błędu kompilacji. Dlatego `AddCqrs` jest
jedynym miejscem kolejności. Usługa nie dokłada własnej listy zachowań obok. Jeśli kiedyś
dojdzie czwarte, dojdzie tutaj i do testu kolejności, a nie w jednym endpoincie artykułu.

### `Result<T>` zamiast wyjątku na błędzie oczekiwanym

Handler zwraca `Task<Result<TResponse>>`. Kod `conflict` ze starej wersji strumienia, kod
`invalid` z walidacji i kod `not_found` z odczytu są wartościami, nie sterowaniem przez `throw`.
`ValidatorBehavior` przy porażce nie woła `next` i nie rzuca `ValidationException`. Test
`Validation_failure_is_result_not_exception` sprawdza brak wyjątku i `IsSuccess` równe false.
Test `Invalid_request_skips_handler` sprawdza, że pusta nazwa daje `invalid`, a handler nie
startuje. Test `Invalid_command_does_not_open_transaction` sprawdza, że przy odrzuconej
komendzie nie ma `Begin`.

Wyjątek zostaje dla IO i dla błędu składu. Brak handlera, brak rejestracji `IUnitOfWork` przy
komendzie, która go wymaga, i zerwane połączenie z Postgresem są wyjątkami.
`Throwing_command_rolls_back` rzuca `IOException` i oczekuje wyjątku oraz wpisu `Rollback`. Na
brzegu HTTP i tak staną się `ProblemDetails`, ale to numer `11`. Mediator ich nie połyka i nie
zamienia na `Result` z kodem `unexpected`. Ta zamiana należy do mappera wyjątku. Gdyby mediator
łapał wszystko, test nie odróżniłby błędu składu od pustego tytułu.

`Result<T>` i kody żyją w `JJDevHub.Shared.Kernel`. Ta biblioteka z nich korzysta i nie
definiuje drugiego typu wyniku. Koszt: każda sygnatura `Handle` niesie `Result`. Nie da się
zwrócić gołego `Guid` i liczyć, że wyjątek powie o błędzie. Utworzenie artykułu, które się uda,
zwraca `Ok` z identyfikatorem wewnątrz `Result`. Utworzenie, które trafi na starą wersję, zwraca
`Fail` z `conflict`. Endpoint nie owija tego w `try` po to, żeby rozróżnić te dwa przypadki.
`try` zostaje przy IO, i to na brzegu, nie w każdym handlerze.

Sukces `Result` po `Begin` kończy się `CommitAsync`. Porażka kończy się `RollbackAsync` nawet
wtedy, gdy handler sam nic nie zapisał. To jest celowe: komenda mogła zdążyć dopisać strumień do
kontekstu śledzonego przez EF, a potem zwrócić `conflict` z innej reguły. Wycofanie zabiera oba
ślady. Zostawienie commita przy `IsSuccess == false` zapisałoby artykuł, którego przypadek
użycia nie uznał.

### `IUnitOfWork` zamiast EF w bibliotece

`TransactionBehavior` nie może zależeć od `DbContext`. Wtedy `JJDevHub.Cqrs` ciągnąłby Entity
Framework, a `Application` ciągnęłaby konkretną bazę. Port `IUnitOfWork` ma
`HasActiveTransaction`, `BeginAsync`, `CommitAsync` i `RollbackAsync`. Implementację na
`*WriteContext` daje `Persistence` usługi. `EfUnitOfWork<TContext>` powstaje obok kontekstu i
woła `Database.BeginTransactionAsync` na tym samym kontekście, którego używa
`PostgresEventStore<TContext>`. Dzięki temu `AppendAsync` widzi `CurrentTransaction` i nie
otwiera drugiej transakcji oraz nie commituje w środku handlera. `AddCqrs` tej implementacji nie
tworzy. Rejestracja stoi w `Program.cs` usługi, jawnie, na jej kontekst zapisu, obok
`AddPostgresEventStore`.

Zapytanie (`IQuery<T>`) pomija transakcję. Brak `IUnitOfWork` w scope dla zapytania też oznacza
`next`, nie wyjątek. Komenda bez `IUnitOfWork` rzuca `InvalidOperationException`. Komenda w
komendzie, gdy transakcja już trwa, nie woła drugiego `Begin`. Test
`Active_transaction_is_reused` ustawia `HasActiveTransaction` na true i sprawdza brak drugiego
`Begin`. Test `Query_skips_transaction` sprawdza brak `Begin` dla zapytania. Test
`Successful_command_commits` oczekuje sekwencji `Begin`, `Commit`. Test
`Failed_command_rolls_back` oczekuje `Begin`, `Rollback` przy `conflict`.

Koszt: usługa musi zarejestrować jedną implementację `IUnitOfWork` na swój kontekst zapisu. Brak
rejestracji przy komendzie, która zapisuje, jest błędem składu i wychodzi w teście hosta, nie
cichym zapisem poza transakcją. Samo `JJDevHub.Cqrs` w teście jednostkowym podstawia
`FakeUnitOfWork`, który zapisuje nazwy wywołań. Test nie podnosi Postgresa. Prawdziwe
`BeginTransactionAsync` zostanie przy kontekście usługi. Tu liczy się kolejność wołań, nie
sterownik.

Port nie ma metody „zapisz zmiany”. Zapis zmian zostaje w `AppendAsync` i w późniejszym
outboxie, na tym samym kontekście, wewnątrz transakcji, którą jednostka pracy tylko otwiera i
zamyka. Gdyby `IUnitOfWork` samo wołało `SaveChanges` obok magazynu, łatwo byłoby mieć dwa
zapisy i jeden z nich poza kolejnością zamka `pg_advisory_xact_lock`. Jednostka pracy jest
ramką. Treść ramki zostaje w adapterach, które znają EF.

### `Core` bez tej biblioteki

Reguły agregatu, value object i `[EventName]` zostają w `Core` i w kernelu. Mediator jest sprawą
przypadku użycia. Gdyby `Core` referencjonował `JJDevHub.Cqrs`, agregat zacząłby znać komendy, a
test domeny ciągnąłby kontener DI. Reguła „slug artykułu jest zajęty” albo „tytuł nie jest
pusty” żyje w value object i w agregacie. Walidator w `Application` może ją zawołać, ale nie
odwrotnie: agregat nie woła `IValidator`. Test `Core_project_does_not_reference_cqrs` w numerze
usługi sprawdzi `csproj`, gdy projekt `Core` powstanie. W tym numerze zasadę widać w
zależnościach: `JJDevHub.Cqrs` referencjonuje kernel, kernel nie referencjonuje `JJDevHub.Cqrs`,
a projekt domeny usługi też jej nie referencjonuje.

`Application` jest miejscem handlera właśnie dlatego, że handler nie jest w tym samym projekcie
co agregat. To jest cel warstwy, nie niedogodność. Koszt: żeby przeczytać przypadek użycia,
otwiera się dwa projekty. Zysk: test agregatu nie widzi `Send`, a test mediatora nie widzi
artykułu. Komenda i zapytanie są `sealed record` w `Application`. Niosą dane wejściowe, nie
reguły. `ICommandHandler<TCommand, TResponse>` i `IQueryHandler<TQuery, TResponse>` dziedziczą
`IRequestHandler` z ograniczeniem na `ICommand` albo `IQuery`. Kontener rozwiązuje zawsze
`IRequestHandler<,>`. Nazwane interfejsy są dla czytelnika i dla rejestracji, która akceptuje
obie formy, bo obie są `IRequestHandler<,>`.

Biblioteka nie referencjonuje Kafki, ASP.NET ani projektu usługi. Log idzie przez
`Microsoft.Extensions.Logging.Abstractions`, kontener przez
`Microsoft.Extensions.DependencyInjection.Abstractions`, walidacja przez FluentValidation. Test
dokłada `Microsoft.Extensions.DependencyInjection`, żeby złożyć `ServiceCollection` w pamięci.
Wersje abstrakcji idą w linii platformy `net11.0`. FluentValidation idzie w aktualnej stabilnej
linii na Apache-2.0, razem z `FluentValidation.DependencyInjectionExtensions`. Oba pakiety są w
tabeli licencji przy numerze `10`. Żadne z nich nie wciąga do `Core`.

## Klasy i ścieżki

Łańcuch jest krótki i cały leży w jednym projekcie współdzielonym. Usługa dokłada rekordy
komend, walidatory i handlery u siebie. Nie dokłada drugiej implementacji `IMediator`. Tabela
zbiera kontrakty, trzy zachowania, rejestrację i trzy klasy testów. Każdy interfejs ma własny
plik. Klasy zachowań są `sealed`. Jeden publiczny typ na plik.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Cqrs/JJDevHub.Cqrs.csproj` | kernel, abstrakcje DI, abstrakcje logowania, FluentValidation |
| `src/shared/JJDevHub.Cqrs/IRequest.cs` | `IRequest<TResponse>` |
| `src/shared/JJDevHub.Cqrs/ICommand.cs` | `ICommand<TResponse> : IRequest<TResponse>` |
| `src/shared/JJDevHub.Cqrs/IQuery.cs` | `IQuery<TResponse> : IRequest<TResponse>` |
| `src/shared/JJDevHub.Cqrs/IRequestHandler.cs` | `Handle` zwracający `Result<TResponse>` |
| `src/shared/JJDevHub.Cqrs/ICommandHandler.cs` | alias handlera komendy |
| `src/shared/JJDevHub.Cqrs/IQueryHandler.cs` | alias handlera zapytania |
| `src/shared/JJDevHub.Cqrs/RequestHandlerDelegate.cs` | następny krok łańcucha |
| `src/shared/JJDevHub.Cqrs/IPipelineBehavior.cs` | zachowanie wokół handlera |
| `src/shared/JJDevHub.Cqrs/IMediator.cs` | `Send` |
| `src/shared/JJDevHub.Cqrs/Mediator.cs` | rozwiązanie handlera i złożenie łańcucha |
| `src/shared/JJDevHub.Cqrs/RequestHandlerWrapper.cs` | typowany pośrednik, cache na typ żądania |
| `src/shared/JJDevHub.Cqrs/IUnitOfWork.cs` | transakcja bez typu EF |
| `src/shared/JJDevHub.Cqrs/Behaviors/LoggingBehavior.cs` | nazwa żądania, czas, kod błędu |
| `src/shared/JJDevHub.Cqrs/Behaviors/ValidatorBehavior.cs` | walidatory, porażka jako `invalid` |
| `src/shared/JJDevHub.Cqrs/Behaviors/TransactionBehavior.cs` | transakcja tylko dla komendy |
| `src/shared/JJDevHub.Cqrs/CqrsServiceCollectionExtensions.cs` | `AddCqrs` |
| `tests/JJDevHub.Cqrs.Tests/MediatorTests.cs` | łańcuch na fałszywych handlerach |
| `tests/JJDevHub.Cqrs.Tests/ValidatorBehaviorTests.cs` | porażka walidacji nie woła handlera |
| `tests/JJDevHub.Cqrs.Tests/TransactionBehaviorTests.cs` | commit, rollback, pominięcie zapytania |

FluentValidation (Apache-2.0) dochodzi w tym projekcie, bo `ValidatorBehavior` woła
`IValidator<TRequest>`. Uzasadnienie biblioteki, kody pól i tłumaczenie są w
[11-walidacja.md](11-walidacja.md). Pakiet jest w tabeli licencji przy numerze `10`, razem z
`FluentValidation.DependencyInjectionExtensions`. Projekt `*.Core` usługi nie dostaje referencji
do `JJDevHub.Cqrs`. W teście tego numeru widać kierunek zależności: kernel nie wskazuje na
mediator, mediator nie wskazuje na News ani na Contact.

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.Cqrs -o src/shared/JJDevHub.Cqrs -f net11.0
dotnet new xunit -n JJDevHub.Cqrs.Tests -o tests/JJDevHub.Cqrs.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.Cqrs tests/JJDevHub.Cqrs.Tests
dotnet add src/shared/JJDevHub.Cqrs reference src/shared/JJDevHub.Shared.Kernel
dotnet add src/shared/JJDevHub.Cqrs package Microsoft.Extensions.DependencyInjection.Abstractions
dotnet add src/shared/JJDevHub.Cqrs package Microsoft.Extensions.Logging.Abstractions
dotnet add src/shared/JJDevHub.Cqrs package FluentValidation
dotnet add src/shared/JJDevHub.Cqrs package FluentValidation.DependencyInjectionExtensions
dotnet add tests/JJDevHub.Cqrs.Tests reference src/shared/JJDevHub.Cqrs
dotnet add tests/JJDevHub.Cqrs.Tests package Microsoft.Extensions.DependencyInjection
```

Testy tego numeru nie podnoszą kontenera. Nie mają cechy `Integration`. Wersje abstrakcji idą w
linii platformy `net11.0`. FluentValidation idzie w aktualnej stabilnej linii na Apache-2.0.

### 2. Kontrakty żądania i handlera

Każdy interfejs ma własny plik. Namespace `JJDevHub.Cqrs`, klamry, typ `sealed` tam, gdzie jest
klasa.

```csharp
namespace JJDevHub.Cqrs
{
    public interface IRequest<TResponse>;

    public interface ICommand<TResponse> : IRequest<TResponse>;

    public interface IQuery<TResponse> : IRequest<TResponse>;

    public interface IRequestHandler<in TRequest, TResponse>
        where TRequest : IRequest<TResponse>
    {
        Task<Result<TResponse>> Handle(TRequest request, CancellationToken cancellationToken);
    }
}
```

`ICommandHandler<TCommand, TResponse>` i `IQueryHandler<TQuery, TResponse>` dziedziczą
`IRequestHandler` z ograniczeniem na `ICommand` albo `IQuery`. Kontener rozwiązuje zawsze
`IRequestHandler<,>`. Nazwane interfejsy są dla czytelnika i dla rejestracji, która akceptuje
obie formy, bo obie są `IRequestHandler<,>`.

Komenda i zapytanie są `sealed record` w `Application` usługi. Niosą dane wejściowe, nie reguły
agregatu.

### 3. Łańcuch

```csharp
namespace JJDevHub.Cqrs
{
    public delegate Task<Result<TResponse>> RequestHandlerDelegate<TResponse>();

    public interface IPipelineBehavior<in TRequest, TResponse>
        where TRequest : IRequest<TResponse>
    {
        Task<Result<TResponse>> Handle(
            TRequest request,
            RequestHandlerDelegate<TResponse> next,
            CancellationToken cancellationToken);
    }
}
```

Zachowanie robi pracę przed `next`, woła `next` albo zwraca wynik bez `next`. Po `next` może
tylko obserwować wynik, nie podmienia kodu błędu domeny na inny.

### 4. `Mediator`

```csharp
namespace JJDevHub.Cqrs
{
    public interface IMediator
    {
        Task<Result<TResponse>> Send<TResponse>(
            IRequest<TResponse> request,
            CancellationToken cancellationToken);
    }
}
```

`Mediator` jest `sealed` i dostaje `IServiceProvider` primary constructorem. W `Send` znany jest
`TResponse`, a typ żądania dopiero w czasie wykonania. Dlatego:

- `RequestHandlerWrapper<TResponse>` jest abstrakcyjną bazą z metodą `Handle`,
- `RequestHandlerWrapperImpl<TRequest, TResponse>` rzutuje żądanie, bierze
  `IRequestHandler<TRequest, TResponse>` i składa zachowania od końca,
- statyczny `ConcurrentDictionary<Type, object>` trzyma wrapper na typ żądania, więc
  `MakeGenericType` idzie raz na typ.

Brak handlera rzuca `InvalidOperationException` z nazwą typu żądania. To błąd składu. `Send`
przekazuje `CancellationToken` do handlera i do każdego zachowania.

### 5. Zachowania

`LoggingBehavior<TRequest, TResponse>` loguje `Handling {RequestName}` przed `next` i `Handled
{RequestName} in {ElapsedMs} ms with {ErrorCode}` po. Do logu wchodzi nazwa typu i kod z
`Result`. Wartości pól nie wchodzą.

`ValidatorBehavior<TRequest, TResponse>` bierze `IEnumerable<IValidator<TRequest>>`. Brak
walidatorów oznacza od razu `next`. W przeciwnym razie woła `ValidateAsync` z tokenem. Gdy
którykolwiek wynik ma `IsValid == false`, zachowanie buduje listę `Error` z `ErrorCode` i
`PropertyName`, zwraca `Result<TResponse>.Fail` z kodem zbiorczym `invalid` i nie woła `next`.
`ValidationException` nie jest używany. Kształt `Error` i tłumaczenie pól domyka numer `11`. Tu
wystarcza, że porażka jest `Result`, a handler nie wystartował.

`TransactionBehavior<TRequest, TResponse>`:

- żądanie nie jest `ICommand<TResponse>` — `next` bez transakcji,
- brak `IUnitOfWork` w scope — `InvalidOperationException` dla komendy, `next` dla zapytania,
- `HasActiveTransaction` — `next` bez drugiej transakcji,
- w przeciwnym razie `BeginAsync`, `next`, sukces `Result` — `CommitAsync`, porażka `Result` —
  `RollbackAsync`,
- wyjątek — `RollbackAsync`, potem wyjątek leci dalej.

```csharp
namespace JJDevHub.Cqrs
{
    public interface IUnitOfWork
    {
        bool HasActiveTransaction { get; }

        Task BeginAsync(CancellationToken cancellationToken);

        Task CommitAsync(CancellationToken cancellationToken);

        Task RollbackAsync(CancellationToken cancellationToken);
    }
}
```

Implementacja `EfUnitOfWork<TContext>` powstaje w `Persistence` obok `*WriteContext` i woła
`Database.BeginTransactionAsync` na tym samym kontekście, którego używa
`PostgresEventStore<TContext>`. Dzięki temu `AppendAsync` widzi `CurrentTransaction`.

### 6. Rejestracja

```csharp
services.AddCqrs(typeof(CreateArticleCommand).Assembly);
```

`AddCqrs(params Assembly[] assemblies)` rejestruje jako scoped:

- każdą zamkniętą implementację `IRequestHandler<,>`,
- walidatory przez `AddValidatorsFromAssemblies(assemblies, ServiceLifetime.Scoped)`,
- `IMediator` jako `Mediator`,
- trzy zachowania jako open generic, w kolejności log, walidacja, transakcja.

Nie rejestruje `IUnitOfWork`. To robi `AddPostgresEventStore` sąsiedztwo w `Program.cs` usługi,
jawnie, na jej kontekst zapisu.

### Co jest do czego

- `IRequest<TResponse>` woła `Send` jako wspólna sygnatura komend i zapytań. Endpoint i test
  znają ten typ, nie konkretny handler. Bez niego `Mediator` musiałby mieć osobne metody dla
  zapisu artykułu i dla odczytu, a nowe zachowanie trzeba by było dopinać dwa razy.
- `ICommand<TResponse>` woła `TransactionBehavior` jako znacznik zapisu. Po nim zachowanie
  poznaje, że ma otworzyć `IUnitOfWork`. Bez znacznika każda wiadomość albo bierze transakcję,
  albo żadna jej nie bierze. Zapytanie o artykuł nie może dzielić tej decyzji z komendą, która
  dopisuje strumień.
- `IQuery<TResponse>` woła ten sam `Send`, ale `TransactionBehavior` puszcza je bez `Begin`. To
  znacznik odczytu. Nie otwiera transakcji bazy zapisu i nie jest pretekstem do `IEventStore`.
  Bez niego odczyt listy łatwo „pożycza” kontekst zapisu i czyta strumień na ścieżce, która ma
  być tania.
- `IRequestHandler<,>` woła wyłącznie mediator. Jeden typ to jeden przypadek użycia. Endpoint
  nie dostaje handlera w konstruktorze. Bez rejestracji zamkniętej implementacji `Send` rzuca
  `InvalidOperationException` z nazwą typu, a nie `Result` z kodem `not_found`.
- `ICommandHandler<,>` i `IQueryHandler<,>` woła czytelnik oraz skan rejestracji. Oba są
  `IRequestHandler<,>`, więc kontener nie ma drugiej mapy. Bez aliasów da się żyć, ale łatwo
  zarejestrować zapytanie jako komendę i otworzyć transakcję na odczycie. Ograniczenie typu to
  łapie przy kompilacji handlera.
- `IPipelineBehavior<,>` woła wrapper, nie endpoint. To miejsce na log, walidację i transakcję.
  Kolejne zachowanie dochodzi bez zmiany handlerów. Bez tego interfejsu każdy handler artykułu i
  każde zapytanie Contact zaczynają się od tych samych kroków albo któryś je gubi.
- `RequestHandlerDelegate<TResponse>` woła zachowanie jako `next`. Bez delegata zachowanie
  musiałoby znać handler albo następne zachowanie z nazwy. Zwrócenie wyniku bez `next` jest tym,
  co robi walidacja przy `invalid`: handler artykułu w ogóle nie startuje.
- `RequestHandlerWrapper` woła `Mediator.Send`, gdy znany jest tylko `TResponse`. Most między
  „znam tylko `TResponse`” a „potrzebuję `TRequest`”. Refleksja siedzi w tej jednej klasie, a
  `ConcurrentDictionary` pilnuje, żeby `MakeGenericType` nie szło na każde żądanie. Bez wrappera
  każde `Send` składa łańcuch od zera albo endpoint z powrotem zna konkretny handler.
- `LoggingBehavior` woła każde żądanie jako zewnętrzna warstwa. Zostawia ślad nazwy, czasu i
  kodu, bez danych osobowych i bez treści notatki. Bez niego diagnostyka pustego tytułu i
  konfliktu wersji ląduje albo nigdzie, albo w logu razem z treścią zapytania Contact.
- `ValidatorBehavior` woła walidatory przed transakcją. Porażka to `invalid`, handler stoi. Bez
  niego `BeginAsync` idzie także dla pustej nazwy, a `ValidationException` albo ręczny `if` w
  handlerze rozjeżdża jeden kształt błędu na dwa.
- `TransactionBehavior` woła `IUnitOfWork` tylko dla komendy. Jedna transakcja na komendę. W
  niej strumień i, od numeru `14`, outbox. Bez niego `AppendAsync` zatwierdza własną transakcję
  albo pisze poza nią, i wycofanie przypadku użycia nie zabiera faktu.
- `IUnitOfWork` woła `TransactionBehavior`, a implementuje go `EfUnitOfWork<TContext>` w
  `Persistence`. Transakcja bez EF w bibliotece współdzielonej. Bez portu `JJDevHub.Cqrs` albo
  referencjonuje `DbContext`, albo nie umie wycofać zapisu artykułu. Bez rejestracji w hoście
  komenda dostaje `InvalidOperationException`, a nie cichy zapis.
- `FakeUnitOfWork` woła test `TransactionBehaviorTests`. Zapisuje nazwy `Begin`, `Commit` i
  `Rollback`. Bez atrapy test łańcucha podnosiłby Postgresa, a ten numer ma zostać przy
  `ServiceCollection`. Atrapa nie jest typem produkcyjnym i nie wchodzi do `Api`.
- `AddCqrs` woła `Program.cs` usługi, na zestawie `Application`, na przykład
  `typeof(CreateArticleCommand).Assembly`. To jedyne miejsce kolejności zachowań. Bez tego
  wołania nie ma handlerów, nie ma walidatorów i nie ma owinięcia. Samo `AddCqrs` nie rejestruje
  `IUnitOfWork`: to sąsiedztwo `AddPostgresEventStore` w tym samym `Program.cs`, jawnie, na
  kontekst zapisu.
- `Mediator` woła endpoint i test przez `IMediator`. Jest `sealed` i dostaje `IServiceProvider`.
  Bez niego `Send` nie ma implementacji, a słownik wrapperów nie ma gdzie żyć. Zamiana na
  wołanie handlera z kontrolera kasuje łańcuch.

## Testy

Projekt `tests/JJDevHub.Cqrs.Tests`. xUnit, `[Fact]`, bez cechy `Integration`, bez
Testcontainers. Kontener z `ServiceCollection`. Żądania, handlery i walidatory są typami
prywatnymi testu. Kolejność zbiera `List<string>` zarejestrowana jako singleton. Każdy fakt ma
jeden powód do padnięcia: jedna tabela, jeden assert na wiersz. Pusta nazwa i nazwa `Notatka`
zastępują tu pusty tytuł artykułu i poprawny tytuł. Treść pola nie może wejść do logu. Token ma
dojść do `ValidateAsync`, `Handle`, `BeginAsync`, `CommitAsync` i `RollbackAsync`.

Klasa `MediatorTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Send_reaches_handler` | handler zwracający `Ok(42)` | `Send` | `Value` równe 42 |
| `Send_without_handler_throws` | brak rejestracji handlera | `Send` | `InvalidOperationException` |
| `Behaviors_wrap_in_registration_order` | dwa zachowania dopisujące `a>`, `b>`, `<b`, `<a` | `Send` | lista `a>`, `b>`, `handler`, `<b`, `<a` |
| `Send_passes_cancellation_token` | handler zapisujący token | `Send` z tokenem | ten sam token |

Klasa `ValidatorBehaviorTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Invalid_request_skips_handler` | walidator `NotEmpty` na `Name`, pusta nazwa | `Send` | kod `invalid`, handler niewołany |
| `Valid_request_reaches_handler` | ten sam walidator, nazwa `Notatka` | `Send` | handler wołany raz |
| `Validator_receives_cancellation_token` | `MustAsync` zapisujący token | `Send` z tokenem | ten sam token |
| `Validation_failure_is_result_not_exception` | pusta nazwa | `Send` | brak wyjątku, `IsSuccess` równe false |

Klasa `TransactionBehaviorTests`. `FakeUnitOfWork` zapisuje nazwy wywołań.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Successful_command_commits` | komenda z `Ok` | `Send` | sekwencja `Begin`, `Commit` |
| `Failed_command_rolls_back` | komenda zwracająca `conflict` | `Send` | sekwencja `Begin`, `Rollback` |
| `Throwing_command_rolls_back` | handler rzuca `IOException` | `Send` | wyjątek i wpis `Rollback` |
| `Query_skips_transaction` | zapytanie z handlerem | `Send` | brak `Begin` |
| `Active_transaction_is_reused` | `HasActiveTransaction` równe true | `Send` komendy | brak drugiego `Begin` |
| `Invalid_command_does_not_open_transaction` | walidator odrzuca komendę | `Send` | brak `Begin` |

```bash
dotnet test tests/JJDevHub.Cqrs.Tests
```

Ten sam zestaw wchodzi w filtr bez kontenerów: `--filter
"Category!=Integration&Category!=Performance"`. Padnięcie kolejności zachowań nie może być tym
samym faktem co padnięcie pustej nazwy. Dlatego tabele są trzy, a każdy wiersz ma jeden assert.
Test nie sprawdza tu jeszcze kodu pola `article.title.blank`: to dokładka numeru `11` do
`ValidatorBehaviorTests`.

## Zasady

- `Core` nie referencjonuje `JJDevHub.Cqrs`. Mediator nie jest typem domeny. Złamanie wciąga
  agregat w kontener DI i test reguły artykułu zaczyna znać `Send`.
- Biblioteka nie referencjonuje Entity Framework, Kafki, ASP.NET ani projektu usługi. Złamanie
  wiąże łańcuch z Postgresem albo z brokerem i test jednostkowy wstaje tylko z kontenerem.
- Oczekiwany błąd to `Result<T>`. `ValidationException` nie wychodzi z `ValidatorBehavior`.
  Złamanie zamienia pusty tytuł w wyjątek i otwiera transakcję albo omija `ProblemDetails`.
- Brak handlera to wyjątek składu, nie `Result` z kodem `not_found`. Złamanie udaje, że artykułu
  nie ma, podczas gdy host w ogóle nie ma przypadku użycia.
- Kolejność zachowań to log, walidacja, transakcja. Zmiana kolejności wymaga zmiany testu
  `Behaviors_wrap_in_registration_order`. Złamanie otwiera transakcję zanim walidacja zwróci
  `invalid` albo chowa odrzucenie przed logiem.
- Zapytanie nie otwiera `IUnitOfWork`. Złamanie bierze połączenie bazy zapisu na `GET` i kusi,
  żeby wołać `IEventStore` z handlera odczytu.
- Komenda nie otwiera drugiej transakcji, gdy jedna już trwa. Złamanie commituje wewnętrzny
  zapis artykułu, zanim zewnętrzna komenda zdecyduje o wycofaniu.
- Log nie zawiera wartości pól żądania. Złamanie zapisuje treść notatki albo treść zapytania
  Contact w dzienniku procesu.
- `CancellationToken` dochodzi do `ValidateAsync`, `Handle`, `BeginAsync`, `CommitAsync` i
  `RollbackAsync`. Złamanie kończy pracę żądania, które klient już odwołał, albo zostawia
  transakcję bez wycofania.
- Jeden publiczny typ na plik. Klasy zachowań są `sealed`. Złamanie miesza kontrakt z
  implementacją i pozwala dziedziczyć zachowanie, które miało być jedną klasą w łańcuchu.

## Poza zakresem

- Implementacja `IEventStore` na Postgresie jest w [09-persistence.md](09-persistence.md). Tu
  transakcja tylko obejmuje kontekst, na którym magazyn zobaczy `CurrentTransaction`.
- Treść kodów, zasoby `pl` i `en`, `ProblemDetails`, mapper wyjątku i `ETag` są w
  [11-walidacja.md](11-walidacja.md). Tu `invalid` jest kodem zbiorczym, bez zdania dla
  człowieka i bez nagłówka `If-Match`.
- Odczyt z bazy `*_read` jest w [12-projekcja.md](12-projekcja.md). Zapytanie w tym numerze
  tylko nie otwiera bazy zapisu. Nie dostaje jeszcze czytnika widoku.
- Zapis outboxa w tej samej transakcji jest w [14-outbox.md](14-outbox.md).
  `TransactionBehavior` jest ramką, w której ten zapis stanie, ale tabela `OutboxMessages` tu
  nie powstaje.
- Konkretne komendy Identity, News, Learning, Cv i Contact są w numerach tych usług, od
  [17-identity.md](17-identity.md). `CreateArticleCommand` w tym pliku jest przykładem zestawu
  przekazanego do `AddCqrs`, nie pełnym przypadkiem użycia notatki.
- Reguły agregatu i value object są w [07-agregat.md](07-agregat.md) i
  [05-kernel.md](05-kernel.md). Walidator może je zawołać. Agregat nie woła mediatora.

## Źródła

- [CQRS pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs). Wiążący
  jest rozdział komendy i zapytania: inny model zapisu, inny model odczytu. W tym pliku stąd
  bierze się `ICommand<T>` kontra `IQuery<T>` oraz zakaz otwierania `IUnitOfWork` dla zapytania.
  Nie bierzemy stąd jeszcze osobnej bazy `*_read`. To numer `12`. Ten numer pilnuje, żeby
  zapytanie nie weszło w strumień.
- Martin Fowler, [CQRS](https://martinfowler.com/bliki/CQRS.html). Wiążące jest traktowanie
  zapisu i odczytu jako osobnych ścieżek, a nie jako jednego modelu z flagą. W tym pliku dotyczy
  to łańcucha: komenda może mieć transakcję, zapytanie jej nie ma i nie jest pretekstem do
  `IEventStore`. Nie bierzemy stąd obowiązku osobnego procesu na odczyt ani stosu zdarzeń jako
  części mediatora.
- [Mediator pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/mediator).
  Wiążące jest jedno wejście: nadawca nie zna handlera. W tym pliku endpoint zależy od
  `IMediator.Send`, a `CreateArticleCommandHandler` zostaje w `Application`. Nie bierzemy stąd
  MediatR. Pakiet od wersji 13 nie wchodzi do `Directory.Packages.props`, a starszej linii nie
  przypinamy.
- [FluentValidation documentation](https://docs.fluentvalidation.net/). Wiążące jest
  `IValidator<T>`, `ValidateAsync` i licencja Apache-2.0, razem z
  `FluentValidation.DependencyInjectionExtensions`. W tym pliku `ValidatorBehavior` woła
  walidatory i przy `IsValid == false` zwraca `invalid` bez `ValidationException`. Nie bierzemy
  stąd komunikatu angielskiego jako treści odpowiedzi HTTP. Zdanie z zasobów jest w numerze
  `11`.
- [Dependency injection in
  .NET](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection). Wiążące
  są otwarte typy generyczne i czas życia scoped. W tym pliku `IPipelineBehavior<,>` rejestruje
  się jako open generic, handlery i walidatory jako scoped, a wrapper na typ żądania siedzi w
  `ConcurrentDictionary`. Nie bierzemy stąd wstrzykiwania handlera wprost do endpointu: to
  kasuje łańcuch. Nie bierzemy też kontenera jako miejsca, w którym `Core` miałby znać komendy.
- [Using transactions in EF
  Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions). Wiążąca jest transakcja
  na `DbContext`, którą `IUnitOfWork` owija bez wciągania EF do tej biblioteki. W tym pliku
  `EfUnitOfWork<TContext>` woła `BeginTransactionAsync` na tym samym kontekście co
  `PostgresEventStore<TContext>`. Nie bierzemy stąd odwołania do `DbContext` w
  `TransactionBehavior`. Brak `IUnitOfWork` przy komendzie jest wyjątkiem składu, nie cichym
  zapisem.
- Eric Evans, *Domain-Driven Design*. Wiążący jest rozdział modelu domeny i przypadku użycia:
  reguły agregatu nie znają aplikacji. W tym pliku `Core` nie referencjonuje `JJDevHub.Cqrs`, a
  komenda jest `sealed record` z danymi wejściowymi, nie z regułami. Nie bierzemy stąd
  przeniesienia handlera do projektu domeny. Handler zostaje w `Application`, i to jest cel
  warstwy.
- Vaughn Vernon, *Implementing Domain-Driven Design*. Wiążąca jest usługa aplikacyjna, która w
  jednej transakcji doprowadza przypadek użycia do końca albo wycofuje całość. W tym pliku stąd
  bierze się `IUnitOfWork` oraz `Rollback` przy porażce `Result` i przy wyjątku. Nie bierzemy
  stąd bazowej klasy repozytorium EF ani mediatora z zewnątrz. Port transakcji nie woła
  `SaveChanges` obok magazynu.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest obraz .NET, w którym komenda wchodzi do
  hosta jednym wejściem i schodzi do handlera. Z tego repozytorium nie bierzemy MediatR. Nie
  bierzemy też `IntegrationEventLogEF`: outbox tego rozwiązania jest własną tabelą w numerze
  `14`, a tu jest tylko ramka `IUnitOfWork` na kontekście zapisu. Mechanizm wrappera i kolejność
  zachowań zostają w `JJDevHub.Cqrs`, bo są przedmiotem numeru.

## Gotowe gdy

- `AddCqrs` rejestruje trzy zachowania w kolejności log, walidacja, transakcja.
- `Send` bez handlera rzuca `InvalidOperationException`.
- Pusta nazwa w teście walidatora daje `invalid` i nie woła handlera.
- Udane `Send` komendy woła `Commit`, nieudane `Result` woła `Rollback`, wyjątek też woła
  `Rollback`.
- `Send` zapytania nie woła `Begin`.
- `JJDevHub.Cqrs.csproj` nie referencjonuje MediatR, Entity Framework, Kafki ani ASP.NET.
- Żaden projekt o sufiksie `.Core` nie referencjonuje `JJDevHub.Cqrs`.
- `dotnet test tests/JJDevHub.Cqrs.Tests` kończy się kodem 0.
