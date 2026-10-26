# 04. OpenBao

Poprzedni numer, [odczyt](03-odczyt.md), rozdziela bazy projekcji od baz zapisu. Ten numer
wynosi sekrety z drzewa gita: port `ISecretReader`, OpenBao deweloperskie w AppHost i puste
wartości w appsettings. Następny plik tego folderu, [jądro](05-kernel.md), dodaje
`Result<T>` i typy, które nie znają żadnej usługi. W kolejności pracy następny
jest OpenBao na VM w [14-openbao.md](../cicd/14-openbao.md). Po tym numerze da
się odczytać wartość z KV v2 przez port. Nie da się
jeszcze zalogować użytkownika, wysłać pusha ani podpisać JWT. Przepływ klucza FCM jest w
[architektura.md](architektura.md), a zakaz wartości sekretu w [README.md](README.md).

Scenariusz, który bez tego numeru się psuje, jest klonem repozytorium. Hasło bazy na maszynie,
klucz FCM i materiał podpisu JWT leżą w pliku, który dostaje każdy deweloper. Albo leżą tylko w
pamięci procesu, która na maszynie znika, więc lokalny `aspire run` udaje serwer sekretów
słownikiem, którego produkcyjna ścieżka nie ma. Handler prosi o klucz i dostaje pusty string.
Pusty string wygląda jak skonfigurowany sekret. Push albo podpis idzie z niczym, a błąd wychodzi
u odbiorcy, nie przy odczycie.

Ten numer stawia OpenBao w trybie deweloperskim i jedyny sposób czytania: `ISecretReader`. Token
tego trybu nie jest w repozytorium. Jest w user secrets projektu `JJDevHub.AppHost`. Port zwraca
wynik, gdy ścieżki nie ma albo polityka odmawia. To są wyniki oczekiwane. Zerwane połączenie i
brak adresu w konfiguracji są awarią IO albo błędem składu i zostają wyjątkiem. Żadna usługa
jeszcze nie woła portu w endpoincie. Test woła go sam, na kontenerze, z tokenem utworzonym w
pamięci procesu testu. Ten token nie jest zapisywany do pliku.

## Po co

Hasło bazy na maszynie, klucz FCM i materiał podpisu JWT nie mogą leżeć w pliku, który klonuje
każdy deweloper. Jednocześnie lokalny `aspire run` ma mieć prawdziwy serwer sekretów, a nie
słownik w pamięci, który na maszynie znika. Ścieżka ma być audytowalna: mount, segment i nazwa,
a nie klucz `Fcm:Key` w json. Polityka ma móc odmówić. Czas życia i sposób wydania na maszynie,
razem z vTPM, są poza tym numerem. Tu powstaje port i kontener dev, które da się wołać tak samo,
gdy maszyna podstawi inny adres.

Port zwraca `Result<string>`, gdy ścieżki nie ma albo polityka odmawia, ale tylko wtedy, gdy
`Result` już jest. Kolejność czytania jest 04 potem 05. Żeby nie odwracać kolejki, port w tym
numerze zwraca własny rekord `SecretRead` z polami `Found`, `Forbidden` i `Value`, a
[05-kernel.md](05-kernel.md) w swoim planie przepina go na `Result<string>` bez zmiany ścieżek.
Jeśli implementacja idzie ściśle numer po numerze, nie używa `Result` przed jego istnieniem.
Jeśli jądro już jest w drzewie, wolno zależeć od `Result`. Sens się nie zmienia: brak i odmowa
są wynikami, nie wyjątkami.

Zerwane połączenie i brak adresu w konfiguracji są awarią IO albo błędem składu i zostają
wyjątkiem. Dzięki temu handler, który później poprosi o klucz FCM, nie dostaje pustego stringa
po cichu. Pusta ścieżka jest błędem programisty i kończy się `ArgumentException`, bo to złe
wywołanie, nie brak sekretu w serwerze. Status 404 mapuje się na brak ścieżki. Status 403 mapuje
się na odmowę. Status 200 wyjmuje pole wartości z JSON-a KV v2 (`data.data.value`). Inny status
i błąd sieci rzucają wyjątek. Komunikat wyjątku nie zawiera tokenu.

Żadna usługa jeszcze nie woła portu w endpoincie. Test woła go sam. Generuje token w pamięci,
startuje kontener tym samym obrazem i tagiem co AppHost, czeka na `/v1/sys/health`, zapisuje KV
v2 pod ścieżką `probe` i czyta przez `OpenBaoSecretReader`. Wartość losowa nie trafia do asercji
zapisanej w źródle jako literał. Kontener jest niszczony po teście. User secrets dewelopera nie
są czytane. Dzięki temu fakt nie zależy od tego, czy ktoś już ustawił `openbao-token` na
laptopie.

Redis, PostgreSQL i bazy odczytu zostają tak, jak są po numerach 01–03. Ten numer dokłada
kontener i nie publikuje jego portu na interfejsie publicznym poza siecią deweloperską Aspire.
Tryb `-dev` jest tylko w składzie lokalnym. Kontener dev nie jest opisany jako skład maszyny. Na
maszynie sekrety idą przez OpenBao poza tym plikiem, co opisuje
[cicd/14-openbao.md](../cicd/14-openbao.md). Hasło produkcyjne PostgreSQL nie wchodzi do numeru
[02-postgres.md](02-postgres.md).

## Dlaczego ta technologia

### OpenBao

OpenBao jest serwerem sekretów na licencji MPL-2.0. W AppHost stoi jako kontener
`openbao/openbao` w trybie `server -dev`. API jest zgodne z KV v2: zapis i odczyt pod
`/v1/<mount>/data/<ścieżka>`. Mount w pliku konfiguracji to `secret`. Tag obrazu jest jedną
stałą `OpenBaoImage.Tag` w `JJDevHub.Secrets.OpenBao`. `OpenBaoImage.Image` równa się
`openbao/openbao`. Tag jest przypięty do konkretnego wydania, nie do `latest`. AppHost i test
używają tej stałej. Drugi tag w teście albo w składzie znaczyłby, że fakt sprawdza inny serwer
niż ten, który wstaje przez `aspire run`.

Sekret ma mieć audytowalną ścieżkę, politykę i czas życia. Plik na dysku dewelopera nie ma
polityki. Każdy, kto klonuje repozytorium, widzi wartość, a serwer nie ma czego odmówić, bo
serwera nie ma. Tryb dev daje te ścieżki lokalnie, bez vTPM. Zapis idzie pod
`/v1/secret/data/...`, odczyt pod ten sam kształt, a polityka potrafi zwrócić 403. Maszyna i
vTPM są poza tym numerem. Lokalnie sekrety trybu dev żyją w pamięci procesu i po restarcie
kontenera są puste. To jest przyjęte. Na maszynie ten tryb nie zostaje. Pustość po restarcie nie
jest wymówką, żeby wpisać wartość do gita „żeby nie znikała”.

Konkret JJDevHub: klucz FCM dla Contact, materiał podpisu JWT dla Identity i hasło PostgreSQL na
maszynie mają ścieżki w tym serwerze, nie klucze w appsettings. Ten numer żadnego z tych
sekretów nie zapisuje w teście jako literału produkcyjnego. Test pisze losową wartość pod
logiczną ścieżką `probe`. Prawdziwy klucz FCM dojdzie w [21-kontakt.md](21-kontakt.md). Materiał
JWT dojdzie w [17-identity.md](17-identity.md). Hasło bazy na maszynie idzie przez OpenBao w
numerze ciągłej integracji, nie przez plik numeru 02. Port już teraz umie odróżnić brak ścieżki
od odmowy, więc tamte numery nie wymyślają drugiego klienta HTTP.

Odpadło HashiCorp Vault. Od zmiany licencji na BSL nie spełnia reguły wolnej licencji
produkcyjnej z [README.md](README.md). Zgodność kształtu API KV v2 nie jest zgodą na produkt,
którego licencja wypadła z listy. Klient NuGet, który ciągnie powierzchnię API tamtego produktu,
wiąże kod z nazwą odrzuconą przez licencję. Odczyt KV v2 jest jednym żądaniem HTTP. Dodatkowa
biblioteka nie jest potrzebna. W csproj i w `AppHost.cs` tej nazwy nie ma.

Odpadł Keycloak. Konta i role są usługą Identity (`Account`, `Invite`, `owner`, `student`).
Keycloak byłby drugim katalogiem użytkowników, a sekret nie jest użytkownikiem. Klucz FCM nie
loguje się hasłem. Materiał JWT nie jest kontem. Wpisanie jednego i drugiego do katalogu
tożsamości miesza odmowę polityki sekretu z odmową roli. Rola `student` należy do Identity, gdy
ta usługa powstanie. Ten numer nie stawia drugiego katalogu i nie wystawia logowania. Keycloak
odpada jako wzorzec i nie występuje w plikach tego numeru.

Koszt: trzeba znać KV v2 i nie logować ciała odpowiedzi. Adapter jest jedynym miejscem, które
składa URL i nagłówek tokenu. Treść sekretu nie wchodzi do `ILogger`. Tryb dev trzyma sekrety w
pamięci i po restarcie są puste. Zespół, który liczy, że wartość wpisana wczoraj będzie dziś,
dowie się, że tryb dev tak nie działa. To jest cena lokalnego serwera bez dysku sekretów. Na
maszynie ten tryb nie zostaje, więc ta cena nie jest architekturą wdrożenia. Jest architekturą
pętli `aspire run`.

### Port `ISecretReader`

Interfejs w `src/shared/JJDevHub.Secrets` ma jedną metodę. Docelowy kształt, gdy jądro już odda
`Result<string>`, wygląda tak:

```csharp
public interface ISecretReader
{
    Task<Result<string>> ReadAsync(string path, CancellationToken cancellationToken);
}
```

W tym numerze, czytany przed jądrem, metoda zwraca rekord `SecretRead` z polami `Found`,
`Forbidden` i `Value`. `path` jest logiczny, na przykład `contact/fcm`. Adapter dokleja mount i
segment `data`. Projekt portu nie referencjonuje `HttpClient` ani OpenBao. Nie referencjonuje
ASP.NET. Nie referencjonuje projektu adaptera. Adapter nie referencjonuje `Core` żadnej usługi.
Ścieżka logiczna nie zaczyna się od `/v1`. Kto poda ścieżkę z prefiksem HTTP, miesza kontrakt
portu z adresem, który ma znać tylko adapter.

Handler nie może znać adresu HTTP OpenBao ani nagłówka `X-Vault-Token`. Ma podać ścieżkę i
dostać wartość albo odmowę. Dzięki temu test handlera, gdy handler powstanie, podstawia fake
portu i nie podnosi kontenera. Test tego numeru uderza w prawdziwy kontener, bo sprawdza
adapter, nie fake. Mediator, który wstrzyknie port do handlera, jest w [10-cqrs.md](10-cqrs.md).
Dziś wołającym jest fakt `Reader_returns_value_written_to_kv_v2`.

Konkret: `contact/fcm` jest przykładem ścieżki logicznej, nie kluczem zapisanym w tym numerze.
Adapter zamieni ją na `{Address}/v1/{Mount}/data/contact/fcm`. Mount domyślny to `secret`, więc
przy adresie uzupełnionym przez Aspire wyjdzie `/v1/secret/data/contact/fcm`. Test używa
krótszej ścieżki `probe`, żeby nie udawać, że klucz FCM już leży w kontenerze. Pusta ścieżka nie
jest „brakiem FCM”. Jest `ArgumentException`. Brak wpisu pod `probe` byłby wynikiem `Found`
fałszywym, a nie wyjątkiem. Fakt tego numeru idzie ścieżką sukcesu: wartość zapisana i wartość
odczytana są równe.

Odpadło bezpośrednie `Configuration["Fcm:Key"]` w handlerze. Każde wywołanie obchodzi politykę i
zachęca, żeby wpisać wartość do appsettings. Konfiguracja zostaje miejscem na `OpenBao:Address`
i `OpenBao:Mount`, nie miejscem na sekret. Klucza tokenu w json nie ma. Handler, który czyta
konfigurację wprost, nie przejdzie przez 404 i 403 w sposób, który port nazywa. Dostanie string
albo null i sam zdecyduje, czy to brak, odmowa, czy pomyłka klucza. Ta decyzja ma być w
adapterze, raz.

Odpadł klient, który ciągnie powierzchnię API HashiCorp Vault jako zależność NuGet. Odczyt KV v2
jest jednym żądaniem GET. Dodatkowa biblioteka nie jest potrzebna, a jej nazwa wiąże kod z
produktem odrzuconym przez licencję. `HttpClient` przychodzi z fabryki do `OpenBaoSecretReader`.
Klasa jest `sealed`. Nagłówek tokenu ustawia w jednym miejscu. Dzięki temu przegląd logowania i
przegląd wyjątku mają jeden typ do czytania, a nie drzewo klienta z cudzą przestrzenią nazw.

Koszt to dwa projekty: port `JJDevHub.Secrets` i adapter `JJDevHub.Secrets.OpenBao`. Adapter
jest jedynym miejscem, które zna URL. Zmiana ścieżki KV v2 jest zmianą adaptera, nie zmianą
handlerów. Przepięcie `SecretRead` na `Result<string>` w numerze 05 jest zmianą typu wyniku, nie
zmianą ścieżek logicznych i nie zmianą obrazu kontenera. Kody `secret.path.missing` i
`secret.path.forbidden` dokańcza jądro, gdy `ResultError` już jest. Do tego czasu rekord niesie
`Found`, `Forbidden` i `Value`. Podwójna reprezentacja przez chwilę jest ceną kolejności
numerów.

### Puste appsettings

`appsettings.json` może zawierać adres i mount, nic więcej:

```json
{
  "OpenBao": {
    "Address": "",
    "Mount": "secret"
  }
}
```

`Address` jest pusty. Aspire nadpisuje go referencją kontenera. Klucza tokenu w tym pliku nie
ma. `appsettings.Development.json` nie dopisuje tokenu, hasła ani connection stringa z hasłem.
To samo dotyczy `launchSettings.json` i plików `*.env`. Przegląd tych plików nie znajduje
niepustej wartości przy kluczu tokenu, hasła albo klucza API. `OpenBaoOptions` czyta adres i
mount. Nie czyta tokenu z kodu, bo tokenu w kodzie nie ma.

Plik json jest w gicie. Cokolwiek niepustego przy kluczu sekretu zostaje w historii. Pusty adres
mówi, gdzie konfiguracja wyląduje, i nie jest sekretem. Mount `secret` też nie jest sekretem: to
nazwa silnika KV w ścieżce, ta sama dla dev i dla późniejszej maszyny, o ile maszyna nie powie
inaczej. Pusty `Address` przy starcie adaptera poza AppHost jest błędem składu. Wyjątek, nie
pusty sekret. Aplikacja nie udaje, że OpenBao stoi pod pustym stringiem i nie zamienia tego na
odczyt, który zwraca `Found` z pustą wartością.

Konkret: deweloper otwiera `appsettings.json` i widzi, że sekretów tam nie będzie. Widzi mount,
żeby nie zgadywać, czy ścieżka logiczna `probe` idzie w `secret`, czy w inny silnik. Nie widzi
tokenu root, hasła PostgreSQL ani klucza FCM. `appsettings.Development.json` nie jest furtką „bo
to tylko lokalnie”. Plik developmentu też jest w gicie. Connection string z hasłem do bazy,
który numery 02 i 03 już wyjęły z json, nie wraca tutaj tylnymi drzwiami przy okazji sekcji
OpenBao.

Odpadło wpisanie tokenu dev do `appsettings.Development.json`. Odpadł commitowany `.env`. Odpadł
plik z zaszyfrowanym sekretem w repozytorium. Zaszyfrowana wartość nadal jest sekretem w gicie i
wymaga klucza, który potem też gdzieś leży. Ten numer nie wprowadza drugiego sekretu po to, żeby
schować pierwszy. User secrets i parametr Aspire są poza drzewem. Zaszyfrowany blob w
repozytorium wygląda niewinnie w diffie i zostaje na zawsze w historii.

Koszt: sam plik nie wystarcza, żeby aplikacja wstała poza AppHost. Brak adresu przy starcie
adaptera jest błędem składu: wyjątek, nie pusty sekret. Nowy klon nie czyta sekretu, dopóki
skład nie wstrzyknie adresu i tokenu. To jest celowe. Test integracyjny obchodzi ten plik: sam
zna adres kontenera, który właśnie uruchomił, i sam zna token, który wygenerował. Nie uzupełnia
`Address` w json na dysku.

### Token w user secrets

Parametr Aspire `openbao-token` ma `secret: true`. Wartość siedzi w user secrets
`JJDevHub.AppHost`, poza drzewem gita. Kontener dostaje ją jako `BAO_DEV_ROOT_TOKEN_ID`. Adapter
dostaje ją z konfiguracji pod kluczem, którego nie ma w appsettings, tylko z user secrets albo
ze zmiennej wstrzykniętej przez AppHost. W gicie widać tylko nazwę parametru. W `AppHost.cs` nie
ma literału tokenu. Tryb dev OpenBao bez tokenu root dostaje odmowę API. Ten token nie może być
argumentem na sztywno, bo plik jest w gicie.

Konkret uruchomienia: deweloper ustawia user secret raz, na swojej maszynie. `aspire run`
przekazuje parametr do kontenera i do procesu, który kiedyś będzie czytał. Test tego nie
powtarza. Generuje `Guid` w pamięci i podaje go tylko kontenerowi. Wartość nie wpada do asercji
jako stała. Jeśli reader zwróci pusty string, fakt `Reader_returns_value_written_to_kv_v2` jest
czerwony z tego samego powodu, co przy innej wartości: odczyt nie jest wartością z PUT. Nie
dodaje się drugiej asercji o kodzie 403. Odmowa polityki jest w zasadach adaptera i w „Gotowe
gdy” jako przegląd gałęzi 403, nie jako drugi powód tego faktu.

Odpadł literał `-dev-root-token-id=dev-token` w `WithArgs`. Taki argument jest w pliku, który
klonuje każdy, i często zostaje w historii procesów. Odpadła zmienna w `launchSettings.json`, bo
ten plik też jest commitowany. Odpadło trzymanie tokenu w `DatabaseNames` albo w stałej testu
współdzielonej z produkcyjnym torem. `DatabaseNames` trzyma nazwy baz, nie sekrety. Stała testu
w źródle jest literałem, nawet jeśli „wygląda losowo”. Losowość tego faktu powstaje w czasie
uruchomienia i ginie razem z procesem.

Koszt: nowy klon nie wstanie, dopóki deweloper nie ustawi user secret. To jest celowe. Ból
pierwszego uruchomienia jest tańszy niż token w historii. Test integracyjny nie czyta user
secrets, więc CI nie potrzebuje sekretu dewelopera i nie potrzebuje sekretu w zmiennych
repozytorium po to, żeby udowodnić KV v2. Potrzebuje Dockera i obrazu z `OpenBaoImage`. Tag
`latest` jest zabroniony, bo fakt i skład rozjechałyby się przy cichym podbiciu obrazu.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Secrets/ISecretReader.cs` | port odczytu po ścieżce logicznej |
| `src/shared/JJDevHub.Secrets/SecretRead.cs` | wynik tego numeru, zanim jądro poda `Result<string>` |
| `src/shared/JJDevHub.Secrets.OpenBao/OpenBaoSecretReader.cs` | GET do KV v2, bez logowania wartości |
| `src/shared/JJDevHub.Secrets.OpenBao/OpenBaoImage.cs` | nazwa obrazu i tag |
| `src/shared/JJDevHub.Secrets.OpenBao/OpenBaoOptions.cs` | adres i mount, bez tokenu w kodzie |
| `JJDevHub.AppHost/AppHost.cs` | kontener dev i parametr `openbao-token` |
| `tests/JJDevHub.Integration.Tests/OpenBaoSecretReaderTests.cs` | fakt zapisu i odczytu na kontenerze |

`OpenBaoSecretReader` jest `sealed`. Dostaje `HttpClient` z fabryki. Nagłówek tokenu ustawia w
jednym miejscu. Treść sekretu nie wchodzi do `ILogger`. `SecretRead` znika w numerze 05, gdy nic
go już nie zwraca. W tym numerze jeszcze jest, jeśli `Result` nie istnieje.

## Plan

### 1. Port

Dodaj projekt `src/shared/JJDevHub.Secrets`. Interfejs `ISecretReader` ma jedną metodę
`ReadAsync`. Rekord wyniku rozróżnia brak ścieżki i odmowę polityki. Pusta ścieżka jest błędem
wywołania i kończy się wyjątkiem `ArgumentException`, bo to błąd programisty, nie brak sekretu w
serwerze. Nie referencjonuj ASP.NET.

### 2. Adapter

Dodaj projekt `src/shared/JJDevHub.Secrets.OpenBao`. `OpenBaoImage` trzyma `Image` równe
`openbao/openbao` i `Tag` przypięty do konkretnego wydania, nie do `latest`.
`OpenBaoSecretReader.ReadAsync` składa adres `{Address}/v1/{Mount}/data/{path}`. Wysyła GET z
tokenem. Status 404 mapuje na brak ścieżki. Status 403 mapuje na odmowę. Status 200 wyjmuje pole
wartości z JSON-a KV v2 (`data.data.value`). Inny status i błąd sieci rzucają wyjątek. Nie
zapisuj tokenu w komunikacie wyjątku.

### 3. Appsettings

W `appsettings.json` zostaw `OpenBao:Address` puste i `OpenBao:Mount` równe `secret`. Nie
dodawaj klucza tokenu. Nie dodawaj hasła PostgreSQL. Sprawdź `appsettings.Development.json` i
`launchSettings.json` tym samym zakazem.

### 4. Kontener w AppHost

Zarejestruj parametr `openbao-token` jako sekret. Dodaj kontener na obrazie z `OpenBaoImage`.
Argumenty: `server` i `-dev`. Token przekaż zmienną środowiska kontenera z parametru, nie z
literału. Nie publikuj portu na interfejsie publicznym poza siecią deweloperską Aspire. Zostaw
Redis i PostgreSQL tak, jak są po numerach 01–03.

### 5. Fakt na kontenerze

Test generuje token w pamięci. Startuje kontener tym samym obrazem i tagiem. Czeka na
`/v1/sys/health`. Sam, klientem HTTP, zapisuje KV v2 pod ścieżką `probe` z wartością losową.
Woła `OpenBaoSecretReader.ReadAsync("probe")`. Porównuje zwróconą wartość z wartością wysłaną.
Kontener jest niszczony po teście. Wartość losowa nie trafia do asercji zapisanej w źródle jako
literał.

### Co jest do czego

`ISecretReader` woła przyszły handler infrastruktury, a w tym numerze woła go test. Ukrywa URL i
token. Gdy interfejsu nie ma, handler albo czyta `Configuration["Fcm:Key"]`, albo bierze
zależność od klienta HTTP OpenBao. Jedno i drugie omija politykę albo wciąga adres do domeny.
Pusta ścieżka bez `ArgumentException` wygląda jak brak sekretu i myli błąd programisty z 404.

`OpenBaoSecretReader` woła rejestracja DI w `Api`, gdy usługa zacznie potrzebować sekretu. W tym
numerze rejestruje go test. Zamienia status HTTP na brak albo odmowę. Gdy klasy nie ma, port nie
ma implementacji, a fakt nie ma czego wołać. Gdy loguje wartość albo token, dashboard i wyjątek
wynoszą sekret, którego ten numer właśnie nie wstawia do gita. Klasa nie jest `sealed` tylko
wtedy, gdy ktoś złamie zasadę: dziedziczenie otwiera drugie miejsce nagłówka.

`SecretRead` woła adapter w tym numerze, zanim istnieje `Result<string>`. Niesie `Found`,
`Forbidden` i `Value`. Gdy rekordu nie ma, a `Result` też jeszcze nie ma, metoda nie ma czym
odróżnić braku od odmowy. Gdy rekord zostaje po przepięciu na `Result`, kompilacja ma dwa typy
wyniku i caller nie wie, który jest kontraktem. Numer 05 usuwa go, gdy nic go już nie zwraca.

`OpenBaoOptions` czyta skład hosta. Mówi, gdzie stoi serwer i jaki jest mount. Nie mówi, jaki
jest token. Gdy opcje niosą token, wraca pokusa, żeby wstawić go do json. Gdy nie ma mountu,
adapter zgaduje silnik i ścieżka logiczna `probe` trafia gdzie indziej niż PUT testu. Pusty
adres poza AppHost jest wyjątkiem składu, nie wartością `Found`.

Parametr `openbao-token` woła AppHost. Spina user secrets z kontenerem i z konfiguracją procesu.
W gitcie widać tylko nazwę parametru. Gdy parametr nie jest sekretem, wartość może trafić do
logu składu. Gdy zamiast parametru stoi literał, token jest w `AppHost.cs`. Zmienna kontenera
`BAO_DEV_ROOT_TOKEN_ID` bez tego parametru nie ma skąd wziąć wartości spoza gita.

`OpenBaoImage` wołają AppHost i test. Jeden tag, jeden obraz. Gdy stałej nie ma, test i skład
wpisują tag osobno, a `latest` w jednym z nich zmienia serwer bez zmiany faktu. Obraz inny niż
`openbao/openbao` albo tag inny niż wydanie przypięte w stałej rozjeżdża health check z API,
którego adapter oczekuje.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]` i cechę `Category=Integration`.
Powód padnięcia jest jeden: wartość odczytana przez `ISecretReader` nie jest wartością zapisaną
do KV v2. NBomber nie wchodzi. Jest w [22-testy.md](22-testy.md). Docker jest zależnością tego
faktu i dlatego jest cecha integracyjna. Krótka pętla bez tej cechy nie podnosi OpenBao.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | token z `Guid` tylko w pamięci, kontener `openbao/openbao` z tagu `OpenBaoImage.Tag`, tryb `server -dev`, PUT `/v1/secret/data/probe` z losową wartością |
| Działanie (act) | `OpenBaoSecretReader.ReadAsync("probe", CancellationToken.None)` |
| Sprawdzenie (assert) | wynik mówi, że wartość jest, i jest równa tej z PUT |

Nazwa metody: `Reader_returns_value_written_to_kv_v2`.

```text
dotnet test tests/JJDevHub.Integration.Tests/JJDevHub.Integration.Tests.csproj --filter "FullyQualifiedName~Reader_returns_value_written_to_kv_v2"
```

Test nie czyta user secrets dewelopera. Test nie używa tokenu wpisanego w źródle. Jeśli reader
zwróci pusty string, fakt jest czerwony z tego samego powodu: to nie jest wartość zapisana. Nie
dodawaj drugiej asercji o kodzie 403. Odmowa polityki jest w zasadach adaptera i w „Gotowe gdy”
jako przegląd gałęzi 403, nie jako drugi powód tego faktu.

Przygotowanie czeka na `/v1/sys/health`, zanim PUT zapisze `probe`. Zapis robi sam test,
klientem HTTP, nie produkcyjnym handlerem. Ścieżka logiczna podana readerowi to `probe`, bez
`/v1` i bez mountu. Mount `secret` dokleja adapter albo URL PUT w przygotowaniu, zgodnie z KV
v2. Sprawdzenie porównuje wartość z wartością z pamięci tego uruchomienia. Nie porównuje z
literałem w pliku testu. Kontener po teście jest niszczony, więc sekret `probe` nie zostaje na
dysku runnera.

Gałąź 404 i gałąź 403 mają być prawdziwe w adapterze, ale nie wchodzą do asercji tej metody.
Doklejenie ich dałoby drugi i trzeci powód padnięcia. Przegląd kodu i warunek ukończenia
pilnują, że 404 i 403 nie są wyjątkami. Błąd sieci wyjątkiem zostaje. Pusta ścieżka wyjątkiem
programisty zostaje. Tych ścieżek ten fakt nie miesza z równością wartości.

## Zasady

- W gicie nie ma wartości tokenu, hasła, klucza API ani connection stringa z hasłem. Taka
  wartość zostaje w historii klonu.
- Tag obrazu nie jest `latest`. Ruchomy tag zmienia serwer pod faktami bez zmiany kodu.
- Port nie referencjonuje projektu adaptera. Referencja wciąga HTTP OpenBao do każdego caller,
  który miał znać tylko ścieżkę.
- Adapter nie referencjonuje `Core` żadnej usługi. Sekret FCM nie może zaciągnąć modelu Contact
  do klienta HTTP.
- Log nie zawiera wartości sekretu ani tokenu. Wpis w logu wynosi to, czego nie ma w
  appsettings.
- 404 z OpenBao nie jest wyjątkiem. Wyjątek zamienia brak ścieżki w awarię procesu.
- 403 z OpenBao nie jest wyjątkiem. Wyjątek zamienia odmowę polityki w `500`.
- Błąd sieci jest wyjątkiem. Wynik „nie znaleziono” przy zerwanym połączeniu kłamie, że ścieżki
  nie ma.
- Pusta ścieżka jest wyjątkiem programisty. Traktowanie jej jak 404 myli błąd wywołania z
  brakiem sekretu.
- AppHost nie ma literału tokenu. Literał w `WithArgs` albo w pliku jest tokenem w gicie.
- Keycloak i HashiCorp Vault nie występują w csproj ani w `AppHost.cs`. Jeden jest odrzuconym
  katalogiem, drugi odrzuconą licencją.
- Tryb `-dev` jest tylko w składzie lokalnym. Opisanie go jako składu maszyny zostawia sekrety w
  pamięci procesu na wdrożeniu.
- Mount domyślny to `secret`. Inny mount bez zmiany umowy rozjeżdża PUT testu i GET adaptera.
- Ścieżka logiczna nie zaczyna się od `/v1`. Prefiks HTTP w ścieżce dubuje składanie adresu w
  adapterze.

## Poza zakresem

- Przepięcie wyniku portu na `Result<string>` i kody `secret.path.missing` oraz
  `secret.path.forbidden` dokańcza [05-kernel.md](05-kernel.md), gdy `ResultError` już jest. Ten
  numer zostawia `SecretRead`, jeśli `Result` jeszcze nie istnieje.
- OpenBao na maszynie, vTPM i krótkotrwałe poświadczenie bazy są w
  [cicd/14-openbao.md](../cicd/14-openbao.md). Ten numer nie opisuje kontenera dev jako składu
  maszyny.
- Klucz FCM i dwa pushe są w [21-kontakt.md](21-kontakt.md). Ten numer nie wysyła pusha i nie
  zapisuje prawdziwego klucza.
- Materiał JWT jest w [17-identity.md](17-identity.md). Ten numer nie podpisuje tokenu
  użytkownika.
- Hasło produkcyjne PostgreSQL nie wchodzi do numeru [02-postgres.md](02-postgres.md); na
  maszynie też idzie przez OpenBao, poza tym plikiem.
- Mediator, który wstrzyknie port do handlera, jest w [10-cqrs.md](10-cqrs.md). Ten numer nie
  woła portu z endpointu.

## Źródła

- [What is OpenBao](https://openbao.org/docs/what-is-openbao/). Wiążący jest serwer sekretów na
  licencji MPL-2.0 oraz rola ścieżki, polityki i czasu życia. Dotyczy kontenera
  `openbao/openbao` w AppHost i zakazu trzymania sekretu w pliku gita. Ze źródła nie bierzemy
  trybu dev jako składu maszyny. Keycloak odpada: konta i role są usługą Identity, a sekret nie
  jest użytkownikiem.
- [KV secrets engine v2](https://openbao.org/docs/secrets/kv/kv-v2/). Wiążące są ścieżka
  `/v1/<mount>/data/<path>` i kształt zapisu oraz odczytu. Dotyczy składania adresu
  `{Address}/v1/{Mount}/data/{path}` i mountu `secret`. Ze źródła nie bierzemy wersjonowania
  sekretu jako funkcji tego numeru i nie bierzemy ścieżki logicznej zaczynającej się od `/v1`.
- [KV v2 HTTP API](https://openbao.org/api-docs/secret/kv/kv-v2/). Wiążące są GET i PUT oraz
  pole wartości w JSON-ie pod `data.data.value`. Dotyczy mapowania statusu 200, 404 i 403 w
  `OpenBaoSecretReader` oraz PUT `/v1/secret/data/probe` w teście. Ze źródła nie bierzemy innych
  statusów jako wyniku biznesowego: inny status jest wyjątkiem. Nie bierzemy logowania ciała
  odpowiedzi.
- [Development server](https://openbao.org/docs/concepts/dev-server/). Wiążące są `server -dev`
  i token root podawany procesowi, a nie plikowi w gicie. Dotyczy argumentów kontenera i
  zmiennej `BAO_DEV_ROOT_TOKEN_ID` z parametru `openbao-token`. Ze źródła nie bierzemy literału
  `-dev-root-token-id=dev-token` i nie bierzemy tagu `latest`. Po restarcie sekrety dev są puste
  i to zostaje lokalnie.
- [Policies](https://openbao.org/docs/concepts/policies/). Wiążące jest to, że odmowa polityki
  jest odpowiedzią serwera, nie awarią procesu. Dotyczy mapowania 403 na odmowę w `SecretRead`
  albo, później, na `Forbidden`. Ze źródła nie bierzemy wyjątku przy 403 i nie bierzemy katalogu
  użytkowników jako sposobu na odmowę. Odmowa roli zostanie w Identity.
- [Token](https://openbao.org/docs/auth/token/). Wiążące jest przekazanie tokenu w żądaniu oraz
  trzymanie go poza repozytorium. Dotyczy jednego miejsca w adapterze, które ustawia nagłówek, i
  zakazu tokenu w komunikacie wyjątku oraz w logu. Ze źródła nie bierzemy tokenu w
  `appsettings`, w `launchSettings` i w stałej testu. Test generuje `Guid` w pamięci.
- [Safe storage of app secrets in
  development](https://learn.microsoft.com/aspnet/core/security/app-secrets). Wiążące są user
  secrets zamiast wpisu w appsettings. Dotyczy tokenu projektu `JJDevHub.AppHost` poza drzewem
  gita. Ze źródła nie bierzemy sekretu w `appsettings.Development.json` i nie bierzemy
  commitowanego `.env`. Pusty `OpenBao:Address` w json zostaje, bo pusty adres nie jest
  sekretem.
- [HashiCorp license FAQ](https://www.hashicorp.com/license-faq). Wiążąca jest informacja o
  licencji BSL produktu, który do składu nie wchodzi. Dotyczy odrzucenia HashiCorp Vault oraz
  zakazu klienta NuGet z powierzchnią jego API. Vault odpadł, więc ze źródła nie bierzemy tego
  produktu jako serwera sekretów i zostaje OpenBao na MPL-2.0.
- [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/). Wiążąca jest licencja, na której stoi
  OpenBao i która mieści się w regule wolnej licencji produkcyjnej. Dotyczy wyboru serwera
  sekretów w tym numerze. Ze źródła nie bierzemy innych produktów tylko dlatego, że też bywają
  na wolnej licencji. Keycloak odpada z powodu drugiego katalogu użytkowników, nie z powodu tej
  licencji.
- [Aspire
  parameters](https://learn.microsoft.com/dotnet/aspire/fundamentals/external-parameters).
  Wiążący jest parametr z `secret: true`. Dotyczy `openbao-token` oraz tego, że w gitcie widać
  nazwę, a wartość siedzi w user secrets. Ze źródła nie bierzemy publikowania portu kontenera
  poza siecią deweloperską Aspire i nie bierzemy wartości parametru w `AppHost.cs`.
- [xUnit](https://xunit.net/). Wiążące są `[Fact]` i cecha `Category=Integration`. Dotyczy
  `Reader_returns_value_written_to_kv_v2` oraz jednego powodu: odczyt nie jest wartością z PUT.
  Ze źródła nie bierzemy drugiej asercji o 403 i nie bierzemy NBombera. Token w atrybucie teorii
  byłby literałem w źródle, więc go nie ma.

## Gotowe gdy

- `ISecretReader` jest w projekcie bez HTTP.
- Adapter czyta KV v2 i nie loguje wartości.
- `OpenBao:Address` w appsettings jest pusty, a klucza tokenu w json w ogóle nie ma.
- `AppHost.cs` nie zawiera literału tokenu i nie używa tagu `latest`.
- Parametr `openbao-token` jest sekretem.
- Komenda z sekcji testów kończy się kodem zero.
- Przegląd `appsettings*.json`, `launchSettings.json` i `*.env` nie znajduje niepustej wartości
  przy kluczu tokenu, hasła albo klucza API.
- Kontener dev nie jest opisany jako skład maszyny.
- Żaden handler domenowy jeszcze nie czyta sekretu.
