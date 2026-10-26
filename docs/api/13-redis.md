# 13. Redis jako cache odczytu

Ten numer dokłada cache przed bazą odczytu. Port jest w `JJDevHub.Caching`, adapter Redis w
`JJDevHub.Caching.Redis`. Widok, który cache trzyma, powstaje w
[12-projekcja.md](12-projekcja.md). Unieważnienie dzieje się po udanym zapisie projekcji, nie w
handlerze komendy. Outbox, który ruszy po commicie strumienia, jest w
[14-outbox.md](14-outbox.md). Bez tego numeru każde publiczne `GET` CV i katalogu kursów
powtarza ten sam odczyt Postgresa, a drugi pod trzyma własną kopię w pamięci procesu i nie
słyszy unieważnienia z pierwszego.

Redis nie jest źródłem prawdy. Prawdą zapisu jest strumień w `*_write`. Prawdą odczytu jest
wiersz albo `jsonb` w `*_read`. Utrata Redisa spowalnia `GET`. Dane zostają w PostgreSQL. Brak
Redisa nie jest `503` na publicznym odczycie. `RedisReadCache` łapie awarię klienta, loguje
`Warning` i woła fabrykę, która czyta `*ReadContext`. Zapis nigdy nie idzie najpierw do Redisa,
a potem do bazy. Nie ma ścieżki, w której tylko cache ma nowy tytuł.

Klucz zaczyna się od nazwy usługi: `news:`, `identity:`, `learning:`, `cv:`, `contact:`. Dwie
usługi nie dzielą przestrzeni kluczy, nawet gdy stoją przy jednym Redisie w AppHost. Przypadkowy
`article:{slug}` bez prefiksu jest błędem adaptera, nie cichym nadpisaniem cudzego wpisu. Nazwa
w kluczu jest tą samą nazwą co komponent wersji: `news`, nie `News.Api` i nie nazwa bazy
`news_read`. Baza i cache to dwa mechanizmy. Mylenie ich w kluczu utrudnia czytanie diagnostyki,
a `KEYS` i tak nie wchodzi do kodu ścieżki HTTP. `KEYS` i `FLUSHDB` nie występują w kodzie
usług.

## Po co

Publiczne CV i katalog kursów czytają te same wiersze wiele razy między jednym zapisem ownera a
drugim. Każde takie `GET` nie musi składać widoku z kilku tabel, skoro projekcja już złożyła
wiersz, a i tak warto nie bić w Postgresa przy fali wejść. Cache trzyma gotową odpowiedź albo
gotowy wiersz pod kluczem. Klucz odpowiedzi to `{usługa}:{widok}:{slug}:{revision}`. Zapytanie
najpierw czyta `CacheRevision` z Postgresa, jeden wiersz po kluczu głównym, potem woła cache z
tą liczbą. Bez odczytu rewizji cache nie jest wołany. Dzięki temu L1 nie serwuje starej rewizji
pod nowym kluczem.

Gdy projekcja zapisze nowy wiersz, stary wpis w cache nie może zostać do końca TTL jako jedyna
wersja, którą klient widzi. Worker po commicie bazy odczytu unieważnia klucze, których ta
projekcja dotknęła. Komenda o cache nie wie. Komenda nie otwiera `*_read` i nie łączy się z
Redisem. `RevisePosition` nie dostaje `IReadCache`. `ProjectionWorker` woła `IProjectionCache` i
nie woła `GetOrCreateAsync`. Test `Command_double_does_not_touch_redis` daje komendzie testowej
licznik komend na `IDatabase` i oczekuje 0.

Limit zapytań i krótkie blokady też mogą iść przez Redis, tym samym prefiksem. Ten numer ich nie
buduje. Buduje port, adapter i unieważnienie widoku. Klucz limitera, gdy powstanie, zaczyna się
tak samo: `news:ratelimit:…`, nigdy gołym identyfikatorem. Krótka blokada edycji, gdy powstanie,
użyje tego samego prefiksu i osobnego klucza. Algorytm limitu i semantyka blokady zostają poza
tym numerem. Zostaje przymus `CacheKey.For` i `ServiceName`.

Scenariusz, który bez rewizji się rozpada, wygląda tak. CV jest w cache pod rewizją 4. Projekcja
publikuje nową sekcję i podbija `Number` do 5 w tym samym `SaveChanges` co wiersz. Zapytanie
czyta 5 i woła `GetOrCreateAsync` z nowym kluczem. Stary klucz przestaje być czytany, nawet gdy
`Remove` nie doszło, bo Redis leżał. Wpis wygasa po TTL. Nowy klucz jest pusty, więc fabryka
liczy odpowiedź z bazy odczytu. Samo skasowanie bez zmiany klucza nie wystarcza przy dwóch
poziomach: L1 w drugim podzie może jeszcze przez krótki `LocalCacheExpiration` trzymać wartość,
którą L2 już skasował. Dlatego klucz zawiera rewizję. Czas lokalny jest krótki. Rewizja jest
właściwym odcięciem.

## Dlaczego ta technologia

### Redis tylko jako cache

Redis trzyma wartości, które da się wyliczyć ponownie z Postgresa. Nie trzyma strumienia, nie
trzyma outboxa i nie przenosi zdarzeń między usługami. Szyna jest w [15-kafka.md](15-kafka.md).
Redis Streams przegrywają jako transport, bo cache i szyna padłyby razem: restart Redis
skasowałby i gorące CV, i wiadomości do Contact. Osobny proces na szynę jest w numerze Kafki. Tu
Redis jest jednym zasobem Aspire pod klucze. Hasło stoi w OpenBao, nie w repozytorium. Host i
hasło nie stoją w pliku w gicie. Connection string wołany z konfiguracji to
`ConnectionStrings:redis`.

Baza `*_read` jako jedyne miejsce odczytu, bez cache, przegrywa przy stronie, którą otwiera
wiele osób naraz, bo każdy `GET` powtarza ten sam indeksowany odczyt. Sama pamięć procesu
(`IMemoryCache`) przegrywa przy drugim podzie: każdy pod ma własną kopię i unieważnienie na
jednym nie rusza drugiego. Własny klient Redis, poza `HybridCache` i `IDistributedCache`,
przegrywa, bo health check i telemetria Aspire są podpięte pod oficjalny komponent, a
get-or-create i tak trzymalibyśmy ręcznie. Oficjalny komponent zostaje. Port `IReadCache` nie ma
typu Redis w sygnaturze.

Koszt: kolejny proces w AppHost i na maszynie oraz okno, w którym klucz już skasowany, a nowy
jeszcze nie wstawiony. W tym oknie zapytanie czyta Postgres i uzupełnia cache. To jest poprawny
przebieg, nie awaria. Przy leżącym Redisie każdy `GET` dochodzi do bazy. To jest degradacja,
którą health check ma pokazać, a nie powód, żeby odmówić ruchu. Test
`Factory_reads_postgres_when_redis_down` podstawia klienta, który rzuca
`RedisConnectionException`, albo wyłącza kontener, i sprawdza, że tytuł wraca z wiersza, bez
wyjątku do wołającego.

`GetOrCreateAsync` przy braku klucza woła fabrykę, a fabryka czyta `*ReadContext`. Gdy Redis nie
odpowiada, `RedisReadCache` łapie `RedisConnectionException` i `RedisTimeoutException`, loguje
`Warning` i woła fabrykę bezpośrednio. Odpowiedź HTTP jest z Postgresa. Fabryka jest wołana co
najwyżej raz na złożenie braków, a przy awarii Redisa raz na żądanie. `RemoveAsync` przy awarii
nie rzuca do workera projekcji poza logiem: projekcja już zatwierdziła rewizję. Metoda zwraca po
logu `Warning`. Redis nie może wycofać projekcji.

### Prefiks równy nazwie usługi

`CacheKey` w bibliotece portu buduje klucz tylko przez `CacheKey.For(serviceName, segments)`.
Pierwszy segment to `identity`, `news`, `learning`, `cv` albo `contact`. Adapter odrzuca klucz,
który nie zaczyna się od `{serviceName}:` skonfigurowanego w tej usłudze. News nie wstawi klucza
`cv:…`, nawet gdy kod ma błąd. Test `Key_without_prefix_is_rejected` woła `article:x` przy
`ServiceName` `news` i oczekuje `ArgumentException`. Test `Foreign_prefix_is_rejected` woła
`cv:public:x` przy tym samym `ServiceName` i też oczekuje `ArgumentException`. Wyjątek pada,
zanim polecenie dojdzie do Redisa.

Wspólny Redis bez prefiksu przegrywa, bo klucz `slug:dotnet` z News i z Learning to dwa byty.
Jeden wpis nadpisałby drugi i katalog kursu pokazałby notatkę albo odwrotnie. Prefiks w
`InstanceName` klienta StackExchange, ustawiony raz w konfiguracji, przegrywa jako jedyna
ochrona, bo łatwo obejść go ręcznym `StringSet` obok portu. Dlatego jedyna dozwolona droga
zapisu to `IReadCache`. Test szuka w `Infrastructure` bezpośredniego `IDatabase` poza adapterem.
`Application` nie referencjonuje StackExchange ani HybridCache. `Core` nie referencjonuje
`JJDevHub.Caching`.

`For` rzuca `ArgumentException`, gdy `serviceName` jest pusta albo segment zawiera dwukropek.
Dwukropek jest separatorem, nie częścią sluga. Slug z dwukropkiem nie przechodzi walidacji już
wcześniej, w value object. Dozwolone `serviceName` sprawdza `AddRedisReadCache` przy starcie
hosta. Inna nazwa rzuca wtedy, nie przy pierwszym `GET`. Późne odrzucenie w trakcie ruchu
zamieniłoby zły skład na `500` albo, co gorsza, na klucz bez właściciela.
`NewsCacheRegistration` ustawia `ServiceName` równe `news`. Bliźniacze rejestracje ustawiają
`identity`, `learning`, `cv` i `contact`. Leżą w `{Usługa}.Infrastructure/Caching` i powstają
razem z usługą. Ten numer daje biblioteki i test na kontenerze.

Koszt: klucz jest dłuższy o nazwę usługi i o numer rewizji. Przy wartościach rzędu kilobajtów to
nic. Zysk jest przy diagnostyce i przy błędzie: obcy prefiks nie wchodzi, a stara rewizja nie
jest czytana pod nowym kluczem. `CacheKey.For("cv", "public", slug, number.ToString())` jest
kształtem, którego używa zapytanie publicznego CV. News używa własnej nazwy. Mieszanie
`news_read` w kluczu zlałoby nazwę bazy z nazwą komponentu i utrudniło czytanie, czego `KEYS` i
tak nie wolno wołać na ścieżce HTTP.

### HybridCache albo `IDistributedCache`

Wygrywa `HybridCache` z `Microsoft.Extensions.Caching.Hybrid` (MIT) z drugim poziomem
`IDistributedCache` na `Microsoft.Extensions.Caching.StackExchangeRedis` (MIT, klient
StackExchange.Redis też MIT). L1 jest w procesie i ścina powtórzenia w tym samym podzie. L2 jest
w Redisie i jest wspólny dla replik. `GetOrCreateAsync` łączy równoległe braki tego samego
klucza w jedno liczenie, więc dziesięć żądań po wygaśnięciu nie robi dziesięciu odczytów
Postgresa. `AddRedisReadCache` rejestruje `AddStackExchangeRedisCache` ze stringa
`ConnectionStrings:redis`, `AddHybridCache` z `LocalCacheExpiration` krótszym niż TTL L2 oraz
`IReadCache` jako singleton. `ServiceName` bierze z opcji.

Sam `IDistributedCache` przegrywa jako jedyny poziom, bo każde trafienie idzie siecią do Redisa
i nie ma złożenia równoległych braków. Sam `IMemoryCache` przegrywa przy drugim podzie. Własny
klient bez tych interfejsów przegrywa, bo health check i telemetria zostałyby obok, a nie na
komponencie, który Aspire już zna. `JJDevHub.Caching` nie ma pakietu Redis. Ma tylko abstrakcje
`Microsoft.Extensions.Caching.Abstractions`, jeśli port ich potrzebuje, albo żadnego pakietu
poza tym, co jest w platformie. `JJDevHub.Caching.Redis` referencjonuje port i oba pakiety
Microsoft. Wersje wchodzą do `Directory.Packages.props`.

`RedisReadCache` jest `sealed`. W `GetOrCreateAsync` sprawdza prefiks i woła
`HybridCache.GetOrCreateAsync`. TTL nie przychodzi w każdym wołaniu. Jest w `CacheOptions` tej
usługi, jeden na widoki publiczne, ustawiony w `Program.cs`. Osobny czas na jeden klucz to
później, gdy widok tego wymaga, przez przeładowanie, nie przez magiczny napis w segmencie
klucza. Koszt L1: przez krótki `LocalCacheExpiration` pod może podać wartość, którą inny pod już
unieważnił w L2. Dlatego klucz zawiera rewizję z bazy odczytu. Samo skasowanie bez zmiany klucza
nie wystarcza przy dwóch poziomach.

Test `Get_or_create_stores_value` na pustym Redisie woła fabrykę, która zwraca `Notatka`, i
drugie wołanie fabryki już nie robi. Test `Remove_drops_key` wstawia klucz, woła `RemoveAsync`,
potem `GetOrCreateAsync` i oczekuje, że fabryka pójdzie ponownie. Klucze w teście zaczynają się
od `news:`. Obraz kontenera to `redis:7-alpine`. Cecha testu to `Category=Integration`.

### Unieważnienie po projekcji

Projekcja z numeru `12` jest jedynym miejscem, które zmienia wiersz odczytu. Po
`SaveChangesAsync` runner woła `IProjectionCache.InvalidateAsync`. Robi dwie rzeczy w tej
kolejności. Podbija wiersz `CacheRevision` w bazie odczytu, w tym samym `SaveChanges` co widok,
więc rewizja i wiersz zatwierdzają się razem. Po udanym commicie kasuje poprzednie klucze
zwrócone przez projekcję. Klucze z `IProjection.TouchedKeys(storedEvent)` są poprzednimi
kluczami, liczonymi z `Number` przed podbiciem. Po commicie `InvalidateAsync` kasuje właśnie te
poprzednie. Nowa rewizja nie jest kasowana. Jest pusta, dopóki pierwsze `GET` nie wypełni jej z
Postgresa.

`CacheRevision` jest `sealed`: klucz `Name` (`string`), wartość `Number` (`long`).
`ApplyCacheRevision` dopisuje tabelę obok `Checkpoints`. Jedna usługa może mieć kilka rewizji,
na przykład `cv-public` i `news-public`, jeśli widoki zmieniają się niezależnie. Na start
wystarcza jedna nazwa na usługę: `public`. Runner w tym samym `SaveChanges` co widok robi
`Number++` na tej nazwie. Zapytanie czyta `Number` i buduje klucz. Test
`Revision_bump_changes_key` trzyma wartość pod rewizją 1, czyta z rewizją 2 i oczekuje, że
fabryka pójdzie, a stara wartość nie wróci. Test `Invalidate_after_projection_removes_previous`
ma klucz rewizji 4, projekcja podbija do 5, `InvalidateAsync` dostaje poprzedni klucz, a
`EXISTS` tego klucza jest false.

Kasowanie z handlera komendy przegrywa, bo komenda nie wie, jaki kształt ma widok, i nie może
czekać na projekcję, która jeszcze nie przetworzyła `Position`. Skasowanie CV w `RevisePosition`
albo nie trafiłoby w klucz, którego jeszcze nie ma, albo skasowałoby klucz, który projekcja za
chwilę z powrotem wypełni starą treścią. Kasowanie zegarem, bez rewizji, zostawia stare CV do
końca TTL po publikacji. Sama rewizja bez `Remove` też jest poprawna, a `Remove` tylko oddaje
pamięć. Gdy `InvalidateAsync` rzuci wyjątek sieci po commicie bazy, worker loguje `Warning` i
nie cofa widoku. Następne zapytanie i tak użyje nowej rewizji, bo ta już jest w Postgresie.

Koszt: każde `GET` czyta mały wiersz rewizji. To jest celowo tanie zapytanie, tańsze niż
złożenie strony, i jest indeksem głównym. Dwa kontenery w teście, `postgres:16-alpine` dla
`CacheRevision` i Redis dla klucza, dotyczą `Revision_bump_changes_key` oraz
`Invalidate_after_projection_removes_previous`. Reszta faktów, która nie potrzebuje wiersza
rewizji, stoi na samym Redisie. Ostatni wiersz tabeli, komenda, używa atrapy portów, bez
drugiego kontenera. `Api` woła `AddRedisReadCache` obok `AddProjectionWorker`. Port `IReadCache`
wstrzykuje się do handlera zapytania, nie do handlera komendy.

### Redis nie jest źródłem prawdy

Prawda o tym, która wersja widoku jest aktualna, siedzi w `CacheRevision.Number`, nie w TTL. TTL
tylko oddaje pamięć po kluczu, którego nikt już nie czyta. Nawet gdy Redis zapisuje dane na
dysk, restart albo utrata procesu nie może być jedyną kopią CV. Dokumentacja trwałości Redisa
opisuje, jak proces broni własnych danych. W tym repozytorium te dane są wyliczalne. Źródłem
odczytu zostaje `*_read`. Źródłem zapisu zostaje `*_write`. Cache jest obok.

`GetOrCreateAsync` nie jest ścieżką zapisu artykułu. Fabryka czyta wiersz, który projekcja już
zatwierdziła. Gdy fabryka i Redis się rozjadą, wygrywa fabryka przy braku klucza i przy awarii.
Gdy klucz jest, a rewizja w Postgresie już poszła do przodu, zapytanie w ogóle nie prosi o stary
klucz. Dlatego publikacja nie czeka, aż TTL zgaśnie. Czeka tylko na projekcję, która i tak jest
asynchroniczna z numeru `12`, oraz na jedno tanie czytanie `Number`.

Koszt degradacji jest jawny. Leżący Redis oznacza, że każde publiczne `GET` dochodzi do
Postgresa. Health check ma to pokazać. Ruch publiczny nie dostaje `503` tylko dlatego, że cache
nie odpowiada. `503` zostaje przy awarii, którą numer `11` mapuje jako `io.unavailable`, gdy
pada ścieżka, bez której odpowiedzi nie ma. CV da się narysować z wiersza. Katalog kursów też.
Strumień i outbox do Redisa nie wchodzą. Szyna nie wchodzi. Test, który wyłącza Redis i nadal
dostaje tytuł z wiersza, jest dowodem tej granicy, nie optymalizacją.

## Klasy i ścieżki

Port nie zna Redisa. Adapter zna `HybridCache` i wyjątki klienta. Rewizja leży przy projekcjach,
bo zmienia się w tym samym zapisie co widok. Rejestracje usług tylko wbijają `ServiceName`, żeby
adapter odrzucił obcy prefiks. Test stoi na Testcontainers, nie na wspólnym Redisie z AppHost.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.Caching/IReadCache.cs` | `GetOrCreateAsync`, `RemoveAsync` |
| `src/shared/JJDevHub.Caching/CacheKey.cs` | składanie klucza z nazwą usługi |
| `src/shared/JJDevHub.Caching/CacheOptions.cs` | `ServiceName`, TTL |
| `src/shared/JJDevHub.Caching/IProjectionCache.cs` | unieważnienie po projekcji |
| `src/shared/JJDevHub.Caching.Redis/RedisReadCache.cs` | `HybridCache` plus obsługa awarii L2 |
| `src/shared/JJDevHub.Caching.Redis/RedisCacheServiceCollectionExtensions.cs` | `AddRedisReadCache` |
| `src/shared/JJDevHub.Projections/CacheRevision.cs` | wiersz rewizji w bazie odczytu |
| `src/services/News/News.Infrastructure/Caching/NewsCacheRegistration.cs` | `ServiceName` równe `news` |
| `src/services/Identity/Identity.Infrastructure/Caching/IdentityCacheRegistration.cs` | `identity` |
| `src/services/Learning/Learning.Infrastructure/Caching/LearningCacheRegistration.cs` | `learning` |
| `src/services/Cv/Cv.Infrastructure/Caching/CvCacheRegistration.cs` | `cv` |
| `src/services/Contact/Contact.Infrastructure/Caching/ContactCacheRegistration.cs` | `contact` |
| `tests/JJDevHub.Caching.Redis.Tests/RedisReadCacheTests.cs` | Testcontainers Redis |

Rejestracja w `Infrastructure` powstaje razem z usługą. Ten numer daje biblioteki i test na
kontenerze. `Api` woła `AddRedisReadCache` obok `AddProjectionWorker`. Port `IReadCache`
wstrzykuje się do handlera zapytania, nie do handlera komendy. `TouchedKeys` jest na projekcji,
nie na komendzie: projekcja wie, które slugi zmieniła. Handler `RevisePosition` tego nie wie i
nie dostaje portu, którym mógłby zgadywać.

## Plan

### 1. Projekty

```bash
dotnet new classlib -n JJDevHub.Caching -o src/shared/JJDevHub.Caching -f net11.0
dotnet new classlib -n JJDevHub.Caching.Redis -o src/shared/JJDevHub.Caching.Redis -f net11.0
dotnet new xunit -n JJDevHub.Caching.Redis.Tests -o tests/JJDevHub.Caching.Redis.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.Caching src/shared/JJDevHub.Caching.Redis tests/JJDevHub.Caching.Redis.Tests
dotnet add src/shared/JJDevHub.Caching.Redis reference src/shared/JJDevHub.Caching
dotnet add src/shared/JJDevHub.Caching.Redis package Microsoft.Extensions.Caching.Hybrid
dotnet add src/shared/JJDevHub.Caching.Redis package Microsoft.Extensions.Caching.StackExchangeRedis
dotnet add tests/JJDevHub.Caching.Redis.Tests reference src/shared/JJDevHub.Caching.Redis
dotnet add tests/JJDevHub.Caching.Redis.Tests package Testcontainers.Redis
```

`JJDevHub.Caching` nie ma pakietu Redis. Ma tylko abstrakcje
`Microsoft.Extensions.Caching.Abstractions`, jeśli port ich potrzebuje, albo żadnego pakietu
poza tym, co jest w platformie. Test ma cechę `Category=Integration`. Obraz kontenera to
`redis:7-alpine`.

Wersje wchodzą do `Directory.Packages.props`. Oba pakiety Microsoft są na MIT.

### 2. Klucz

```csharp
namespace JJDevHub.Caching
{
    public static class CacheKey
    {
        public static string For(string serviceName, params string[] segments)
        {
            return string.Join(':', new[] { serviceName }.Concat(segments));
        }
    }
}
```

`For` rzuca `ArgumentException`, gdy `serviceName` jest pusta albo segment zawiera dwukropek.
Dwukropek jest separatorem, nie częścią sluga. Slug z dwukropkiem nie przechodzi walidacji już
wcześniej, w value object.

Dozwolone `serviceName`: `identity`, `news`, `learning`, `cv`, `contact`. Inna nazwa rzuca przy
starcie hosta, w `AddRedisReadCache`, nie przy pierwszym `GET`.

### 3. Port

```csharp
namespace JJDevHub.Caching
{
    public interface IReadCache
    {
        Task<T> GetOrCreateAsync<T>(
            string key,
            Func<CancellationToken, Task<T>> factory,
            CancellationToken cancellationToken);

        Task RemoveAsync(string key, CancellationToken cancellationToken);
    }
}
```

`GetOrCreateAsync` nie przyjmuje czasu życia w każdym wołaniu. TTL jest w `CacheOptions` tej
usługi, jeden na widoki publiczne, ustawiony w `Program.cs`. Osobny czas na jeden klucz to
później, gdy widok tego wymaga, przez przeładowanie, nie przez magiczny napis.

`IProjectionCache` ma `InvalidateAsync(CacheRevision revision, IReadOnlyCollection<string>
previousKeys, CancellationToken)`. Woła go runner po udanym `SaveChangesAsync`.

### 4. Adapter

`RedisReadCache` jest `sealed`. W `GetOrCreateAsync` sprawdza prefiks i woła
`HybridCache.GetOrCreateAsync`. Wyjątek `RedisConnectionException` i `RedisTimeoutException`
loguje i zwraca wynik fabryki. Fabryka jest wołana co najwyżej raz na złożenie braków, a przy
awarii Redisa raz na żądanie.

`RemoveAsync` przy awarii Redisa nie rzuca do workera projekcji poza logiem: projekcja już
zatwierdziła rewizję. Metoda zwraca po logu `Warning`.

`AddRedisReadCache` rejestruje `AddStackExchangeRedisCache` ze connection stringa
`ConnectionStrings:redis`, `AddHybridCache` z `LocalCacheExpiration` krótszym niż TTL L2 oraz
`IReadCache` jako singleton. `ServiceName` bierze z opcji. Connection string nie jest w
repozytorium.

### 5. Rewizja w bazie odczytu

`CacheRevision` jest `sealed`: klucz `Name` (`string`), wartość `Number` (`long`).
`ApplyCacheRevision` dopisuje tabelę obok `Checkpoints`. Jedna usługa może mieć kilka rewizji,
na przykład `cv-public` i `news-public`, jeśli widoki zmieniają się niezależnie. Na start
wystarcza jedna nazwa na usługę: `public`.

Runner w tym samym `SaveChanges` co widok robi `Number++` na tej nazwie. Klucze zwrócone przez
`IProjection.TouchedKeys(storedEvent)` są poprzednimi kluczami, liczonymi z `Number` przed
podbiciem. Po commicie `InvalidateAsync` kasuje właśnie te poprzednie.

Zapytanie czyta `Number` i buduje klucz `CacheKey.For("cv", "public", slug, number.ToString())`.
Bez odczytu rewizji z Postgresa cache nie jest wołany. Dzięki temu L1 nie serwuje starej rewizji
pod nowym kluczem.

### 6. Kto woła cache

Handler zapytania publicznego CV woła `IReadCache`. Handler komendy `RevisePosition` go nie
dostaje. `ProjectionWorker` woła `IProjectionCache` i nie woła `GetOrCreateAsync`. Test
konstruktora, tak jak w numerze `12`, pilnuje tego podziału na typach testowych, a numer usługi
powtórzy go na prawdziwych handlerach.

### Co jest do czego

- `IReadCache` woła handler zapytania publicznego. Jedyna droga do gotowej odpowiedzi. Ukrywa
  HybridCache i awarię Redisa. Bez portu `Application` albo referencjonuje StackExchange, albo
  każde `GET` idzie do Postgresa, albo drugi pod nie widzi unieważnienia. Komenda tego portu nie
  dostaje.
- `CacheKey` woła zapytanie i projekcja, gdy składają klucz. Prefiks usługi jest przymusem, nie
  konwencją w komentarzu. Bez `For` ktoś sklei `article:{slug}` i nadpisze cudzy wpis albo
  wstawi dwukropek w segmencie. Pusta nazwa usługi i obcy prefiks kończą się
  `ArgumentException`.
- `CacheOptions` woła `AddRedisReadCache` i `Program.cs`. Niosą `ServiceName` i TTL widoków
  publicznych. Bez nich czas życia wchodzi w każde wołanie albo, co gorsza, w magiczny napis w
  kluczu. Osobny TTL jednego klucza, gdy będzie potrzebny, dojdzie przeładowaniem, nie teraz.
- `RedisReadCache` woła kontener jako `IReadCache`. Daje L1, L2 i zejście do fabryki, gdy Redis
  leży. Bez adaptera port nie ma implementacji, a `HybridCache` wycieka do `Application`. Klasa
  jest `sealed`. Przy `RedisConnectionException` i `RedisTimeoutException` nie oddaje wyjątku
  wołającemu `GET`.
- `AddRedisReadCache` woła `Api` obok `AddProjectionWorker`. Rejestruje cache StackExchange,
  HybridCache i singleton portu. Bez tego startu zła nazwa usługi przechodzi do pierwszego
  `GET`. Inna nazwa niż `identity`, `news`, `learning`, `cv` albo `contact` rzuca przy starcie.
  String `ConnectionStrings:redis` nie leży w gicie.
- `CacheRevision` woła runner w tym samym `SaveChanges` co widok i woła zapytanie przed cache.
  Liczba w Postgresie zmienia klucz. Bez tabeli rewizji L1 serwuje starą wartość pod kluczem,
  który `Remove` na drugim podzie już skasował. `Number++` zatwierdza się razem z wierszem.
  Awaria Redisa po tym commicie nie cofa wiersza.
- `ApplyCacheRevision` woła `OnModelCreating` kontekstu odczytu, obok `Checkpoints`. Bez
  mapowania nie ma wiersza `Name`/`Number`. Na start wystarcza nazwa `public`. `cv-public` i
  `news-public` są dopuszczalne, gdy widoki zmieniają się niezależnie. To nadal ta sama tabela,
  nie druga baza.
- `IProjectionCache` woła runner po udanym `SaveChangesAsync`. Kasuje poprzednie klucze. Bez
  tego wołania pamięć starych kluczy zostaje do TTL, co jest poprawne dzięki rewizji, ale
  `Remove` ma oddać pamięć, gdy Redis żyje. Wyjątek sieci po commicie jest `Warning`, nie
  wycofaniem widoku.
- `TouchedKeys` woła projekcja. Wie, które slugi zmieniła, i zwraca poprzednie klucze liczone z
  `Number` przed podbiciem. Handler komendy tego nie wie. Bez tej metody unieważnienie albo
  kasuje za szeroko, albo nie wie, który slug CV ruszyć.
- `NewsCacheRegistration` i cztery bliźniacze woła skład usługi. Ustawiają `ServiceName`, żeby
  adapter odrzucił obcy prefiks. Bez rejestracji News mógłby dostać nazwę z bazy `news_read`
  albo z `News.Api` i klucz przestałby pasować do komponentu wersji.
- Fabryka w `GetOrCreateAsync` woła odczyt `*ReadContext`, gdy klucza nie ma albo gdy Redis
  leży. Bez fabryki brak klucza nie ma z czego powstać, a awaria cache staje się `503`. Fabryka
  przy złożeniu braków idzie raz. Przy awarii idzie raz na żądanie.
- `IDatabase` poza adapterem woła test, który przeszukuje `Infrastructure`. Bez tego zakazu
  ręczny `StringSet` omija prefiks i `InstanceName` nie jest żadną ochroną. Na ścieżce HTTP nie
  ma `KEYS` ani `FLUSHDB`.

## Testy

Klasa `RedisReadCacheTests`. xUnit, `[Fact]`, `[Trait("Category", "Integration")]`. Fixture
`RedisBuilder("redis:7-alpine")`. Każdy fakt ma jeden powód do padnięcia. Klucze w teście
zaczynają się od `news:`. Gdy fakt potrzebuje i Postgresa, i Redisa, fixture podnosi oba:
`postgres:16-alpine` dla `CacheRevision` i Redis dla klucza. To dotyczy
`Revision_bump_changes_key` i `Invalidate_after_projection_removes_previous`. Ostatni wiersz
używa atrapy portów, bez drugiego kontenera.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Get_or_create_stores_value` | pusty Redis, fabryka zwraca `Notatka` | `GetOrCreateAsync` | drugie wołanie nie woła fabryki, wynik `Notatka` |
| `Key_without_prefix_is_rejected` | klucz `article:x` przy `ServiceName` `news` | `GetOrCreateAsync` | `ArgumentException` |
| `Foreign_prefix_is_rejected` | klucz `cv:public:x` przy `ServiceName` `news` | `GetOrCreateAsync` | `ArgumentException` |
| `Remove_drops_key` | klucz wstawiony | `RemoveAsync`, potem `GetOrCreateAsync` | fabryka wołana ponownie |
| `Revision_bump_changes_key` | wartość pod rewizją 1 | odczyt z rewizją 2 | fabryka wołana, stara wartość nie wraca |
| `Factory_reads_postgres_when_redis_down` | klient Redis rzuca `RedisConnectionException`, fabryka zwraca wiersz | `GetOrCreateAsync` | wynik równy wierszowi, bez wyjątku do wołającego |
| `Invalidate_after_projection_removes_previous` | klucz rewizji 4, projekcja podbija do 5 | `InvalidateAsync` z poprzednim kluczem | `EXISTS` poprzedniego klucza równe false |
| `Command_double_does_not_touch_redis` | komenda testowa, licznik komend na `IDatabase` | `Handle` | licznik 0 |

```bash
dotnet test tests/JJDevHub.Caching.Redis.Tests
```

Padnięcie prefiksu nie może być tym samym faktem co padnięcie rewizji. Dlatego odrzucenie
`article:x`, odrzucenie `cv:` przy `ServiceName` `news`, podbicie numeru i `EXISTS` po
unieważnieniu są osobnymi wierszami. Degradacja przy leżącym Redisie jest osobno od komendy,
która Redisa w ogóle nie dotyka. Cecha `Category=Integration` zostawia ten projekt poza filtrem
bez kontenerów.

## Zasady

- Redis nie trzyma jedynej kopii stanu. Źródłem odczytu jest `*_read`, źródłem zapisu jest
  `*_write`. Złamanie zostawia tytuł tylko w cache i restart kasuje CV, którego strumień nie ma.
- Klucz zaczyna się od nazwy usługi i dwukropka. Złamanie pozwala News nadpisać klucz Cv albo
  wstawić `article:x` bez właściciela.
- `Application` nie referencjonuje StackExchange ani HybridCache. Złamanie wciąga przypadek
  użycia w klienta Redis i w czas życia L1.
- `Core` nie referencjonuje `JJDevHub.Caching`. Złamanie wciąga agregat w klucz i w
  unieważnienie widoku.
- Handler komendy nie woła `IReadCache`. Złamanie każe `RevisePosition` zgadywać klucz widoku,
  którego projekcja jeszcze nie złożyła.
- Unieważnienie jest po commicie projekcji i niesie poprzednie klucze oraz nową rewizję.
  Złamanie kasuje klucz przed zatwierdzeniem wiersza albo zostawia starą rewizję jako jedyną
  czytaną.
- Awaria Redisa na `GET` czyta Postgresa i nie kończy się `503` tylko z tego powodu. Złamanie
  chowa publiczne CV, choć wiersz w `*_read` jest.
- Awaria Redisa po commicie projekcji nie cofa wiersza. Złamanie wycofuje widok, który Postgres
  już zatwierdził, albo udaje, że publikacji nie było.
- `KEYS` i `FLUSHDB` nie występują w kodzie usług. Złamanie blokuje Redis na ścieżce HTTP albo
  kasuje klucze sąsiada na wspólnym procesie.
- Hasło i host Redisa nie stoją w pliku w gicie. Złamanie wkłada secret do repozytorium zamiast
  do OpenBao i do `ConnectionStrings:redis` poza gitem.

## Poza zakresem

- Sam worker i upsert widoku są w [12-projekcja.md](12-projekcja.md). Tu dochodzi
  `CacheRevision` i `TouchedKeys` po udanym `SaveChanges`, nie druga pętla projekcji.
- Szyna między usługami jest w [15-kafka.md](15-kafka.md). Redis Streams tam nie wchodzą.
  Restart Redisa nie może skasować wiadomości do Contact.
- Outbox jest w [14-outbox.md](14-outbox.md). Wiersz `OutboxMessages` nie leży w Redisie i nie
  jest kluczem `news:`.
- Limit zapytań jako algorytm nie powstaje tutaj. Gdy powstanie, użyje `CacheKey.For` i tego
  samego `ServiceName`, z segmentem w rodzaju `news:ratelimit:…`.
- Krótka blokada edycji użyje tego samego prefiksu i osobnego klucza. Nie tego numeru.
- Drugi pod i HPA są w [docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). L2 jest na to
  gotowy. L1 jest krótki właśnie dlatego, że repliki nie dzielą pamięci procesu.

## Źródła

- [HybridCache](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/hybrid).
  Wiążące są L1, L2 i `GetOrCreateAsync`, które składa równoległe braki jednego klucza w jedno
  liczenie. W tym pliku `RedisReadCache` woła HybridCache, a `LocalCacheExpiration` jest krótszy
  niż TTL L2. Nie bierzemy L1 jako jedynej kopii. Klucz zawiera rewizję, bo sam `Remove` nie
  czyści pamięci drugiego poda.
- [Distributed caching in ASP.NET
  Core](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/distributed). Wiążący
  jest `IDistributedCache` jako wspólny poziom replik. W tym pliku stoi pod HybridCache przez
  `AddStackExchangeRedisCache` i string `ConnectionStrings:redis`. Nie bierzemy samego
  `IDistributedCache` jako jedynego poziomu: każde trafienie szłoby siecią i nie byłoby złożenia
  braków. Nie bierzemy trzymania strumienia w tym cache.
- [In-memory caching in ASP.NET
  Core](https://learn.microsoft.com/en-us/aspnet/core/performance/caching/memory). Wiążący jest
  `IMemoryCache` jako pamięć jednego procesu. W tym pliku przegrywa jako jedyna kopia, bo drugi
  pod nie widzi unieważnienia. L1 HybridCache zostaje, krótki, pod L2. Nie bierzemy pamięci
  procesu jako źródła prawdy CV ani katalogu kursów.
- [StackExchange.Redis](https://stackexchange.github.io/StackExchange.Redis/). Wiążący jest
  klient na MIT oraz wyjątki połączenia i czasu. W tym pliku `RedisConnectionException` i
  `RedisTimeoutException` schodzą do fabryki, a `RemoveAsync` przy awarii nie wycofuje
  projekcji. Nie bierzemy ręcznego `IDatabase` w `Infrastructure` ani `StringSet` obok portu.
  `InstanceName` nie jest jedyną ochroną prefiksu.
- [Cache-Aside
  pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/cache-aside). Wiążące
  jest liczenie wartości ze źródła prawdy, gdy klucza nie ma. W tym pliku fabryka czyta
  `*ReadContext`, a zapytanie najpierw bierze `CacheRevision` z Postgresa. Nie bierzemy zapisu
  „najpierw Redis, potem baza”. Nie ma ścieżki, w której tylko cache ma nowy tytuł.
- [Redis EXPIRE](https://redis.io/docs/latest/commands/expire/). Wiążące jest wygasanie klucza
  po TTL. W tym pliku TTL oddaje pamięć poprzedniej rewizji, gdy `Remove` nie doszło. Nie
  bierzemy TTL jako jedynego unieważnienia po publikacji: stare CV zostałoby do końca czasu.
  Rewizja zmienia klucz od razu. `Remove` tylko oddaje pamięć.
- [Redis Streams](https://redis.io/docs/latest/develop/data-types/streams/). Wiążący jest opis
  strumienia w tym samym procesie co cache. W tym pliku ten typ nie przenosi kopert. Szyna jest
  w numerze Kafki, bo restart Redisa nie może skasować i gorącego CV, i wiadomości do Contact.
  Nie bierzemy Streams jako outboxa ani inboxa. Hasło Redisa zostaje w OpenBao, nie w
  repozytorium.
- [Redis
  persistence](https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/).
  Wiążące jest to, że Redis potrafi zapisać własne dane na dysk. W tym pliku nawet ten zapis nie
  zastępuje bazy odczytu. CV i katalog da się wyliczyć z `*_read`. Nie bierzemy trwałości Redisa
  jako powodu, żeby trzymać tam jedyną kopię stanu albo strumień.
- [Using transactions in EF
  Core](https://learn.microsoft.com/en-us/ef/core/saving/transactions). Wiążący jest jeden
  `SaveChanges` na kontekście odczytu. W tym pliku `Number` rewizji rośnie w tym samym zapisie
  co widok. Nie bierzemy rozproszonej transakcji między Postgresem a Redisem. Po commicie bazy
  wyjątek sieci przy `InvalidateAsync` jest `Warning` i nie cofa wiersza.
- [PostgreSQL constraints](https://www.postgresql.org/docs/16/ddl-constraints.html). Wiążący
  jest klucz główny wiersza `CacheRevision`: zapytanie czyta jeden wiersz po `Name`, taniej niż
  składa stronę. W tym pliku ta liczba zostaje w bazie odczytu, obok `Checkpoints`. Nie bierzemy
  trzymania rewizji w Redisie. Bez odczytu `Number` z Postgresa cache nie jest wołany, więc L1
  nie serwuje starej rewizji pod nowym kluczem.

## Gotowe gdy

- Klucz bez prefiksu usługi rzuca, zanim dojdzie do Redisa.
- News nie zapisze klucza z prefiksem `cv:`.
- Drugie `GetOrCreateAsync` tego samego klucza nie woła fabryki.
- Podbicie `CacheRevision` sprawia, że zapytanie nie czyta starej wartości.
- Po `InvalidateAsync` poprzedni klucz znika.
- Wyjątek połączenia z Redisem zwraca wartość z fabryki.
- `dotnet test tests/JJDevHub.Caching.Redis.Tests` kończy się kodem 0.
