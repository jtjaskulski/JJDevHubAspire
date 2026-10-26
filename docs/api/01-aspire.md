# 01. Aspire

Ten numer stawia skład lokalny, zanim powstanie pierwsza baza i pierwszy typ domenowy. W
kolejności pracy poprzedni krok to tunel z [09-cloudflare.md](../cicd/09-cloudflare.md):
maszyna z [08-proxmox.md](../cicd/08-proxmox.md) już stoi, a repliki aplikacji są jeszcze
`0`. [Wersje komponentów](../cicd/07-wersje.md) nadal nadają numer każdemu przyszłemu
obrazowi. Następny plik w tym folderze, [PostgreSQL](02-postgres.md), dokłada jeden serwer
i pięć baz zapisu. Następny krok pracy to collector w
[10-opentelemetry.md](../cicd/10-opentelemetry.md). Tutaj
powstają `JJDevHub.AppHost`, `JJDevHub.ServiceDefaults`, zasób Redis o nazwie `cache`, endpointy
`/health` i `/alive`, haki OpenTelemetry oraz dashboard. Agregatu, tabeli i sekretu jeszcze nie
ma. Słownik nazw jest w [README.md](README.md), a przepływ między usługami w
[architektura.md](architektura.md).

Scenariusz, który bez tej ramy się rozpada, zaczyna się od świeżego klonu i od polecenia, żeby
„wstało wszystko”. Identity, News, Learning, Cv, Contact, brama, baza, broker i serwer sekretów
mają kiedyś być jednym obrazem na jednym ekranie. W tym numerze z tej listy realnie wstaje host
składu i Redis. Reszta nie ma jeszcze projektu. Sposób startu musi być jednak już ustalony.
Inaczej każdy kolejny numer dopisze własny skrypt, własny port i własny sposób czekania, aż
sąsiad w ogóle odpowie.

Bez `JJDevHub.AppHost` deweloper odpala procesy ręcznie. Jeden terminal trzyma Redis na porcie,
który drugi proces ma wpisany inaczej. Kolejny proces kończy się odmową połączenia, bo sąsiad
jeszcze nie nasłuchuje. Trzeci dostaje inny connection string, bo profil startu skopiowano z
innej gałęzi. Dashboardu nie ma, więc jedynym śladem zostaje stdout. Kod wyjścia zero z procesu
Redis nie mówi, czy zasób w składzie nazywa się `cache`. Późniejszy numer cache szuka wtedy
drugiej nazwy i kontrakt `ConnectionStrings:cache` znika.

Ta sama rama ma obowiązywać później na maszynie, choć sam AppHost na maszynę nie jedzie. Usługa
HTTP, gdy już powstanie, woła `AddServiceDefaults` przy budowie hosta i `MapDefaultEndpoints` po
`Build`. W developmentcie dashboard czyta OTLP, bo sam ustawia `OTEL_EXPORTER_OTLP_ENDPOINT`. Na
maszynie ten sam hak czyta endpoint kolektora. W tym numerze kolektorem jest dashboard. Adres
nie jest wpisany w `appsettings.json`, bo w obu miejscach jest inny.

Health ma ścieżkę stałą od pierwszej kompilacji wspólnej biblioteki. Orkiestrator i test pytają
o `/health` oraz `/alive`. Ścieżka nie zależy od środowiska `Development`. Odpowiedź nie zawiera
connection stringa ani ciała wyjątku. Gdyby mapowanie zostało owinięte w `IsDevelopment()`,
próbka na maszynie dostałaby `404`, choć proces żyje. Test tego numeru jest po to, żeby ta
pomyłka nie przeszła cicho: buduje host poza Development i żąda `GET /health`.

## Po co

Pięć usług, brama, baza, broker i serwer sekretów mają wystartować jedną komendą i pokazać się
na jednym ekranie. Bez wspólnego hosta każdy proces dostaje inny connection string, inny port i
inny sposób czekania, aż zależność odpowie. Ten numer zamyka samą ramę. Po nim `aspire run`
podnosi dashboard i Redis. Nie podnosi jeszcze PostgreSQL, Kafki ani OpenBao. Nie ma projektu
Identity, News, Learning, Cv ani Contact.

Rama jest potrzebna, zanim powstanie pierwsza tabela, bo kolejność startu i nazwa zasobu są
umową między numerami, a nie szczegółem implementacji jednej usługi. News, które jeszcze nie
istnieje, ma kiedyś dostać swój connection string z tego samego modelu zasobów co Cv. Gdyby
każda usługa trzymała własną listę portów, dodanie bramy w [16-gateway.md](16-gateway.md)
oznaczałoby ręczne uzgadnianie pięciu procesów. AppHost ma być tym jednym miejscem, które zna
nazwę zasobu i to, który projekt — gdy już będzie — dostanie odwołanie.

Sam Redis bez konsumenta też ma być widoczny w składzie. Nazwa `cache` jest częścią kontraktu.
Późniejszy numer cache nie wymyśla drugiej nazwy zasobu. Klucze jeszcze nie powstają. Prefiks
nazwy usługi zacznie obowiązywać, gdy pojawi się pierwsza projekcja w cache, co opisuje
[13-redis.md](13-redis.md). Do tego czasu dashboard ma pokazać zasób, a kod nie ma wołać
klienta. Dzięki temu nikt nie zapisze w pamięci procesu jedynej kopii danych, których miejsce
jest gdzie indziej.

Wspólny punkt dla developmentu i maszyny jest wąski i konkretny. Każdy przyszły host HTTP
referencjonuje `JJDevHub.ServiceDefaults` i woła dwie metody publiczne: `AddServiceDefaults`
przy builderze oraz `MapDefaultEndpoints` po `Build`. Telemetria, health, odkrywanie usług i
handler odporności mają być identyczne w Identity, News, Learning, Cv, Contact i w bramie.
Rozjazd jednej usługi psuje dashboard i próbkę żywości. Piąta kopia tego samego bloku, wklejona
do własnego `Program.cs`, gubi filtr ścieżek albo inną wersję pakietu.

Health rozdziela dwie informacje, których sam otwarty port TCP nie rozróżnia. `/health` pyta,
czy proces może dostać ruch, bo wymaga wszystkich zarejestrowanych sprawdzeń. `/alive` pyta, czy
proces żyje, bo wymaga sprawdzeń z tagiem `live`. Domyślne sprawdzenie nazywa się `self`, zwraca
`Healthy` i ma tag `live`. Port bywa otwarty, zanim aplikacja skończy skład hosta. Orkiestrator,
który ufa samemu portowi, puszcza ruch za wcześnie. Test tego numeru uderza w `/health` bez
ustawiania środowiska `Development`, więc mapowanie tylko w developmentcie nie ma jak się
schować.

Odpowiedź health zostaje statusem. Nie zawiera listy connection stringów i nie zawiera wyjątku.
Sprawdzenie zależności, które ujawnia hasło w opisie, nie należy do `self`. W tym numerze `self`
nie otwiera Redisa i nie otwiera bazy, bo bazy jeszcze nie ma, a cache nie ma klienta. Mówi
tylko, że proces odpowiada. Kto dołoży do `self` opis z hasłem, złamie zasadę sekretu w
pierwszym numerze, w którym sekretu jeszcze nie ma, ale ścieżka odpowiedzi już jest publiczna w
sieci procesu.

Dashboard spina ten obraz w jedną pętlę. `aspire run` z katalogu repozytorium otwiera ekran, na
którym widać zasób `cache` i logi hosta. Profil `launchSettings` AppHost nie zawiera sekretu.
Bez dashboardu jedynym śladem startu jest stdout, a przy pięciu przyszłych procesach ten stdout
przestaje być czytelny. Ten numer ma jeden proces hosta i jeden zasób, ale ekran ma być ten sam,
gdy dojdą bazy i usługi. Produkcja dashboardu nie uruchamia. Słucha on na porcie deweloperskim i
nie jest wystawiany publicznie.

Hak OpenTelemetry jest częścią tej samej ramy, a nie osobnym produktem dokładanym przy pierwszej
usłudze. Jedna usługa bez haka jest niewidoczna na dashboardzie, a później na maszynie.
Eksporter OTLP włącza się tylko wtedy, gdy konfiguracja ma niepusty
`OTEL_EXPORTER_OTLP_ENDPOINT`. Brak zmiennej oznacza brak eksportera, nie wyjątek przy starcie.
Test tego numeru zmiennej nie ustawia i nie łączy się z Redisem. Padnięcie z timeoutu kontenera
znaczyłoby, że fakt sprawdza za dużo.

## Dlaczego ta technologia

### Skład .NET Aspire 13

`JJDevHub.AppHost` jest projektem wykonywalnym na SDK `Aspire.AppHost.Sdk` linii 13.
`DistributedApplication.CreateBuilder` rejestruje zasoby. `aspire.config.json` wskazuje
`JJDevHub.AppHost/JJDevHub.AppHost.csproj`. Framework docelowy to `net11.0`. Wersja linii Aspire
jest jedna dla SDK i dla pakietów hostingu. Ląduje w `Directory.Packages.props`.
`PackageReference` w csproj zostaje bez atrybutu `Version`. `Directory.Build.props` ustawia
`Nullable` na `enable`, `ImplicitUsings` na `enable` i `ManagePackageVersionsCentrally` na
`true`. Solution `JJDevHub.slnx` w korzeniu, jeśli już jest, dostaje istniejący AppHost; jeśli
go nie ma, powstaje tutaj.

Skład ma znać nazwę zasobu, kolejność startu i to, który projekt dostanie connection string. Ta
wiedza ma być w jednym pliku `AppHost.cs`, a nie w zestawie skryptów powłoki. W tym numerze plik
rejestruje jeden zasób, Redis, i na tym kończy listę. Nie dodaje projektu Identity, News,
Learning, Cv, Contact ani Gateway. Nie dodaje PostgreSQL, Kafki ani OpenBao. Nie woła
`WithReference`, bo usługi jeszcze nie ma i nie ma projektu, do którego dałoby się taką
referencję podpiąć. Kolejność jest więc uczciwa: najpierw model, potem bazy w następnym numerze,
potem usługi w swoich numerach.

Konkret JJDevHub jest tu organizacyjny, nie domenowy. Gdy News kiedyś opublikuje artykuł, a Cv
zapisze umiejętność, oba projekty mają być dopisane do tego samego `AppHost.cs` i dostać
connection string ze składu, a nie z pliku json w gicie. Dziś tych projektów nie ma i
`AppHost.cs` nie tworzy agregatu `Article` ani żadnego innego. Plik nie otwiera bazy. Gdyby ktoś
„dla wygody” wstawił tu tworzenie konta albo sprawdzenie roli `owner`, host składu stałby się
piątą kopią domeny i przestał być ramą. Słownik nazw zostaje w [README.md](README.md). Ten numer
tylko pilnuje, żeby żaden plik ramy nie definiował `Article`, `Account`, `Skill` ani
`StudentInquiry`.

Odpadł sam Docker Compose jako jedyny korzeń składu. Compose uruchamia kontenery. Nie typuje
referencji projektu .NET i nie wstrzykuje connection stringa do user secrets procesu usługi.
Przy Redisie dałoby się napisać usługę kontenera i wystawić port. Przy pięciu projektach .NET,
których jeszcze nie ma, Compose nie powie kompilatorowi, który projekt należy do składu. Nazwa
`cache` zostałaby napisem w pliku yaml, bez modelu, który później poda `ConnectionStrings:cache`
procesowi. Trzeba by wtedy trzymać drugi, ręczny kanał konfiguracji. Właśnie tego ten numer ma
nie wprowadzać.

Odpadło też pięć niezależnych `dotnet run` bez hosta. Każdy proces trzeba wtedy odpalić ręcznie
i każdy sam czeka na port sąsiada. Identity nie wie, czy News już słucha. News nie wie, pod jaką
nazwą szukać cache. Brama, gdy dojdzie, musiałaby znać pięć portów wpisanych w pięciu profilach.
Jeden profil z hasłem albo z tokenem trafia do gita przez `launchSettings.json`. AppHost tego
pliku nie zamienia w magazyn sekretów: profil dashboardu zostaje, wartości sekretu nie dostaje.
Czekanie na sąsiada przenosi się do modelu zasobów, a nie do pętli `sleep` w skrypcie.

Koszt, który zostaje, jest świadomy. AppHost nie jest obrazem produkcyjnym i nie jedzie na
maszynę. Trzeba trzymać model zasobów Aspire obok manifestu k3s, który opisuje późniejszy numer
maszyny. Dwa opisy tej samej topologii będą się starzeć osobno, jeśli ktoś doda zasób tylko w
jednym z nich. Dlatego ten numer jest celowo ubogi: jeden zasób `cache` i żadnej domeny. Wersja
SDK jest wspólna z pakietami hostingu, więc podbicie linii Aspire podbija host i biblioteki
razem, przez `Directory.Packages.props`, a nie przez pięć różnych atrybutów `Version`. Host
składu nie referencjonuje `JJDevHub.ServiceDefaults`, bo nie jest usługą HTTP. Test buduje
krótki host sam, w projekcie testowym.

### Redis jako zasób `cache`

`builder.AddRedis("cache")` dodaje kontener Redis. Nazwa `cache` jest nazwą zasobu i nazwą
connection stringa `ConnectionStrings:cache`. Pakiet hostingu to `Aspire.Hosting.Redis`,
licencja MIT. Zasób wchodzi do składu w `AppHost.cs` obok budowy aplikacji rozproszonej.
LaunchSettings nie dostaje haseł, tokenów ani connection stringów. Hasło i port procesu
deweloperskiego zostają w modelu Aspire, poza drzewem, które klonuje każdy deweloper. W gicie
widać wywołanie z argumentem `cache`, a nie gotowy ciąg połączenia.

Cache ma być w składzie od pierwszej komendy, zanim powstanie pierwsza usługa, która coś w nim
zapisze. Nazwa musi być jedna, bo pięć usług będzie wołać ten sam zasób, a klucz i tak rozdzieli
prefiks. Prefiks nazwy usługi zacznie obowiązywać dopiero przy pierwszej projekcji. W tym
numerze kluczy nie ma i klient nie jest wołany. Sam zasób bez konsumenta ma być widoczny na
dashboardzie. Dzięki temu numer [13-redis.md](13-redis.md) nie wymyśla drugiej nazwy i nie
dokłada drugiego kontenera „bo pierwszy nazwano inaczej”.

Konkret domeny jest na razie negatywny i właśnie o to chodzi. Notatka, lekcja i strona CV
jeszcze nie istnieją jako typy. Gdy powstaną, gorący odczyt może trafić do cache, ale wiersz, z
którego da się odbudować stronę, będzie w bazie odczytu. Kto zapisze w Redisie jedyną kopię
projekcji, złamie regułę z [architektura.md](architektura.md). Ten numer nie ma jak zapisać
takiej kopii, bo nie ma klienta. Ma za to nazwę, pod którą pięć usług — Identity, News,
Learning, Cv i Contact — spotka się przy jednym zasobie. Rozdzielenie kluczy `news` i `cv` jest
późniejsze. Wspólna nazwa zasobu jest teraz.

Odpadł `IMemoryCache` w procesie usługi. Ginie razem z procesem i nie jest współdzielone między
replikami. Dwie repliki News widziałyby dwa różne słowniki. Restart kasowałby wpis, co przy
cache jest dopuszczalne, ale tylko wtedy, gdy istnieje inne miejsce z projekcją. Sam słownik w
procesie nie jest zasobem składu. Dashboard go nie pokaże. Connection string o nazwie `cache`
nie powstanie. Test „czy zasób nazywa się `cache`” nie miałby czego oglądać na ekranie `aspire
run`. Pamięć procesu zostaje narzędziem lokalnym, jeśli kiedyś będzie potrzebna, i nie zastępuje
zasobu.

Odpadł też Memcached. Wymaga osobnego protokołu i osobnej integracji, a zasób w tym składzie ma
się nazywać `cache` i być Redisem. Drugi protokół oznaczałby drugi pakiet hostingu, drugą nazwę
connection stringa i inną historię klienta w numerze 13. Lista licencji i tak ma pomieścić
`Aspire.Hosting.Redis` na MIT. Dokładanie silnika, którego nazwa w słowniku nie występuje,
rozjeżdża kontrakt zanim powstanie pierwszy klucz. Redis jest tu wybrany jako ten zasób, nie
jako miejsce na jedyną kopię danych.

Koszt zostaje przy deweloperze i przy dyscyplinie danych. Redis jest kolejnym procesem w
developmentcie. Dane cache wolno zgubić. Po restarcie kontenera klucze znikają i to jest
przyjęte, bo kluczy i tak jeszcze nie ma. Kto później potraktuje ten proces jak bazę, złamie
regułę architektury, a nie regułę tego numeru o nazwie. Klient StackExchange i prefiks klucza
dochodzą w [13-redis.md](13-redis.md), nie tutaj. Ten numer nie ustawia prefiksu i nie wykonuje
zapisu. Test jednostkowy nie łączy się z Redisem i nie wymaga Dockera. Obraz kontenera jest
sprawą `aspire run`, nie faktu `/health`.

### Projekt ServiceDefaults

Biblioteka `JJDevHub.ServiceDefaults` wystawia `AddServiceDefaults`, `ConfigureOpenTelemetry`,
`AddDefaultHealthChecks` i `MapDefaultEndpoints`. Każdy przyszły host HTTP referencjonuje ten
projekt i woła te dwie metody publiczne: dodanie przy builderze i mapowanie po `Build`.
`AddServiceDefaults` woła konfigurację telemetrii, domyślne health checks, `AddServiceDiscovery`
i `ConfigureHttpClientDefaults`. W konfiguracji klienta HTTP włączone są
`AddStandardResilienceHandler` i `AddServiceDiscovery`. Projekt testowy
`tests/JJDevHub.ServiceDefaults.Tests` referencjonuje bibliotekę i jest dopięty do solution
razem z nią.

Telemetria, health, odkrywanie usług i handler odporności mają być identyczne w Identity, News,
Learning, Cv, Contact i w bramie. Rozjazd jednej usługi psuje dashboard i próbkę żywości. Gdyby
News filtrowało ścieżki `/health`, a Contact nie, próbki Contact zalałyby ślad, a News
wyglądałoby na zdrowsze tylko dlatego, że ktoś skopiował nowszy blok. Wersja pakietu
OpenTelemetry ma być jedna, w `Directory.Packages.props`. Biblioteka jest tym miejscem, które tę
wersję referencjonuje raz. Pakiety obejmują hosting OpenTelemetry, eksporter OTLP,
instrumentację ASP.NET Core, HTTP i runtime, health checks, service discovery oraz resilience
HTTP.

Konkret JJDevHub dotyczy granicy, a nie ekranu artykułu. W `JJDevHub.ServiceDefaults` nie ma
typu domenowego i nie ma roli `owner` ani `student`. Sprawdzenie, czy prośba studenta wolno
przejść, należy do Contact, gdy ten agregat powstanie. Sprawdzenie tytułu artykułu należy do
News. Wspólna biblioteka jest referencjonowana także przez bramę. Typ `Article` wstawiony tutaj
sprawiłby, że brama i Identity kompilują się z modelem News. Rola `owner` wstawiona tutaj
sprawiłaby, że każda usługa zna katalog tożsamości, którego jeszcze nie ma. Projekt nie zawiera
domeny, więc te typy nie mają tu adresu.

Odpadło skopiowanie tego samego bloku do każdego `Program.cs`. Piąta kopia gubi filtr ścieżek
health albo inną wersję pakietu OpenTelemetry. Przy dwóch usługach różnicę widać w przeglądzie.
Przy pięciu usługach i bramie różnica wychodzi na dashboardzie jako dziura: jednej usługi nie ma
na wykresie, druga raportuje inny zestaw metryk. Test, który buduje host i woła
`AddServiceDefaults`, sprawdza bibliotekę, a nie jedną z kopii. Kopia w `Program.cs` News nie
byłaby nawet czym, co ten numer potrafi skompilować, bo projektu News nie ma.

Odpadło też trzymanie tych metod w projekcie jednej usługi i referencja z pozostałych do jej
`Api`. `Api` sąsiada nie jest biblioteką współdzieloną. Gdyby metody żyły w `Api` Identity, News
musiałby referencjonować host Identity, a z nim pakiety, których nie chce, i typy konta, których
nie zna. Cykl referencji pojawia się w momencie, w którym brama albo Identity chciałaby użyć
czegoś z News. `JJDevHub.ServiceDefaults` jest osobnym projektem bibliotecznym właśnie po to,
żeby zależność szła w jedną stronę: host HTTP do biblioteki, nigdy usługa do `Api` sąsiada.

Koszt jest ceną wspólnego miejsca. Zmiana w `ServiceDefaults` dotyka każdego hosta, który go
referencjonuje, i podbija wersję tych komponentów. Poprawka filtra śladu jest poprawką dla
wszystkich naraz. To jest pożądane, dopóki zmiana jest ramą. Staje się szkodą, gdy ktoś wstawi
tu regułę jednej usługi i podbije wersję pozostałych bez powodu. Dlatego przegląd tego projektu
pilnuje braku `Article` i braku ról. `HttpClient` tworzony przez fabrykę z tej biblioteki ma
discovery i handler odporności. Wyjęcie jednego z nich w jednej usłudze oznaczałoby, że ta
usługa znowu ma własny klient i własną politykę ponowień.

### Health `/health` i `/alive`

`/health` wymaga wszystkich zarejestrowanych sprawdzeń. `/alive` wymaga sprawdzeń z tagiem
`live`. Domyślne sprawdzenie nazywa się `self`, zwraca `Healthy` i ma tag `live`. Oba endpointy
są mapowane w każdym środowisku. `MapDefaultEndpoints` mapuje `/health` bez predykatu i `/alive`
z predykatem tagu `live`. Nie owija mapowania w `IsDevelopment()`. Nie zwraca ciała z
konfiguracją. `AddDefaultHealthChecks` rejestruje `self` i jest wołane z `AddServiceDefaults`, a
nie z AppHost.

Orkiestrator odróżnia proces, który żyje, od procesu, który może dostać ruch. Test tego numeru
musi móc uderzyć w `/health` bez ustawiania środowiska `Development`. Host testowy powstaje
przez `WebApplication.CreateBuilder` ze środowiskiem `Production`, potem `AddServiceDefaults`,
`Build` i `MapDefaultEndpoints`. `HttpClient` z `WebApplicationFactory` albo z testowego serwera
wysyła `GET /health`. Kod statusu to 200. Nazwa metody to
`Health_endpoint_returns_ok_outside_development`. Dzięki środowisku `Production` fakt łapie
błąd, który na maszynie dewelopera, uruchomionej jako Development, byłby niewidoczny.

Konkret dla JJDevHub jest operacyjny. Zanim powstanie pierwszy `Article`, maszyna i tak będzie
pytać, czy proces News żyje i czy może dostać ruch. Ścieżka ma być ta sama w Identity, w Contact
i w bramie. Inna ścieżka w jednej usłudze oznacza inny manifest próbki i cichy błąd przy
wdrożeniu tej jednej usługi. `self` nie odpowiada na pytanie, czy Redis przyjął zapis i czy
tytuł artykułu przeszedł regułę. Na te pytania odpowiedzą późniejsze sprawdzenia i kody
domenowe. Tu odpowiedź jest statusem procesu. Ciało z connection stringiem cache albo z
wyjątkiem konfiguracji wyszłoby do logu orkiestratora.

Odpadło samo sprawdzenie, że port TCP jest otwarty. Port bywa otwarty, zanim aplikacja skończy
skład hosta. W praktyce Aspire proces już słucha, a `MapDefaultEndpoints` jeszcze nie podpięło
ścieżek albo aplikacja czeka na konfigurację. Próbka portu mówi wtedy „żyje” i puszcza ruch na
proces, który nie umie odpowiedzieć na `/health`. Przy jednym zasobie Redis różnica jest mała.
Przy pięciu usługach orkiestrator uznałby za gotową tę, która tylko otworzyła gniazdo. Dlatego
sprawdzenie nazywa się `self` i jest częścią aplikacji, a nie własnością portu.

Odpadło też mapowanie health tylko przy `IsDevelopment()`. Poza developmentem ścieżka znika i
próba na maszynie dostaje `404`, choć proces działa. To jest szczególnie podstępne, bo lokalne
`aspire run` chodzi w Development i ścieżka wygląda na żywą. Test ze środowiskiem `Production`
jest tańszy niż odwzorowanie maszyny. Nie wymaga Dockera. Nie ma cechy `Category=Integration`
ani `Category=Performance`. Filtr `Category!=Integration&Category!=Performance` przepuszcza ten
fakt, bo fakt cechy integracyjnej nie ma. NBomber, który mierzyłby czas próbki, jest w
[22-testy.md](22-testy.md) i do tego numeru nie wchodzi.

Koszt jest świadomie ograniczony. Endpoint jest publiczny w sieci procesu. Odpowiedź ma być
statusem, bez listy connection stringów i bez wyjątku. Sprawdzenie zależności, które ujawnia
hasło w opisie, nie należy do `self`. Gdy dojdą bazy, ich sprawdzenia mogą wejść do `/health`
jako gotowość, ale opis nadal nie może nieść hasła. `/alive` zostaje przy tagu `live`, żeby
zależność zewnętrzna nie restartowała procesu tylko dlatego, że na chwilę nie odpowiada. W tym
numerze jedynym sprawdzeniem z tagiem `live` jest `self`. Brak tego tagu sprawiłby, że `/alive`
nie ma czego wymagać i próbka żywości staje się pusta.

### Haki OpenTelemetry

`ConfigureOpenTelemetry` rejestruje logi, metryki ASP.NET Core, metryki `HttpClient`, metryki
runtime i ślady. Logi OTel idą z zakresami i ze sformatowaną wiadomością. Ślady obejmują źródło
o nazwie aplikacji, ASP.NET Core i klient HTTP. Eksporter OTLP włącza się tylko wtedy, gdy
konfiguracja ma niepusty `OTEL_EXPORTER_OTLP_ENDPOINT`. Dashboard Aspire ustawia tę zmienną sam.
Ścieżki zaczynające się od `/health` i `/alive` są odfiltrowane ze śladów ASP.NET Core, żeby
próbka nie zalała widoku. Adres kolektora nie jest wpisany w appsettings. Eksportera chmurowego
nie ma.

Jedna usługa bez haka jest niewidoczna na dashboardzie, a później na maszynie. Adres kolektora
nie może być wpisany w `appsettings.json`, bo w developmentcie i na maszynie jest inny. W
developmentcie kolektorem jest dashboard. Na maszynie kolektorem jest endpoint, który poda
środowisko. Ten sam kod haka obsługuje oba przypadki, bo decyzja jest w zmiennej, nie w
kompilacji. Test nie ustawia zmiennej. Start hosta ma się udać, a eksporter ma zostać wyłączony.
Wyjątek przy pustej zmiennej znaczyłby, że lokalny test jednostkowy wymaga dashboardu, choć
sprawdza tylko status.

Konkret JJDevHub na tym etapie nie jest licznikiem „ile artykułów”. Takiego licznika ten numer
nie dodaje. Jest za to wspólny ślad dla przyszłego żądania News i przyszłego żądania Contact.
Oba mają wpaść do tego samego haka, z tą samą instrumentacją ASP.NET Core i klienta HTTP. Próbka
`/health` co kilka sekund nie może zdominować widoku, bo inaczej dashboard pokazuje życie
orkiestratora, a nie pracę usług. Filtr po prefiksie ścieżki załatwia `/health` i `/alive`
jednym warunkiem. Log ze śladu nie zapisuje ciała, które mogłoby być tokenem. Ciało żądania z
nagłówkiem albo z kluczem, nawet jeśli dziś takiego żądania nie ma, nie ma wstępu do wiadomości
logu.

Odpadł sam plik logu albo sam Serilog bez sygnału OTLP. Dashboard i późniejszy kolektor czytają
OTLP, nie prywatny format pliku. Plik na dysku jednej maszyny dewelopera nie scala się z logiem
drugiej usługi. Pięć plików z pięciu procesów wraca do problemu, który dashboard miał zdjąć:
stdout jako jedyny ślad. Serilog może formatować tekst lokalnie, ale bez sygnału OTLP usługa
znika z ekranu `aspire run` i zniknie z kolektora na maszynie. Ten numer nie wprowadza drugiego
kanału „prawdziwych” logów obok haka. Hak jest kanałem.

Odpadł eksporter Azure Monitor. Cel runtime to dashboard lokalnie i kolektor na maszynie, nie
chmura publiczna. Pakiet pod jednego dostawcę chmury związałby skład z kontem, którego w
repozytorium nie ma, i z sekretem połączenia, którego w plikach ma nie być. Zmienna
`OTEL_EXPORTER_OTLP_ENDPOINT` jest neutralzna: dashboard ją ustawia, maszyna ustawi ją na swój
kolektor. Eksport do chmury byłby trzecim celem, niewynikającym z tego numeru. Pakiety
OpenTelemetry zostają na licencji Apache-2.0 i w jednej wersji w `Directory.Packages.props`.

Koszt jest w dyscyplinie rejestracji. Każdy nowy licznik trzeba dodać świadomie, bo dashboard
pokazuje to, co hak zarejestruje. Licznik dodany „na zapas” w ServiceDefaults staje się
kontraktem wszystkich usług, także tych, które danej wielkości nie mają. W tym numerze nie ma
liczników domenowych. Metryki zostają przy ASP.NET Core, kliencie HTTP i runtime. Ślad zostaje
przy źródle o nazwie aplikacji i przy tych samych instrumentacjach. Kto dopisze licznik
artykułów w tej bibliotece, wciągnie News do ramy tak samo, jak wciągnięcie klasy `Article`.

### Dashboard Aspire

`aspire run` z katalogu repozytorium otwiera dashboard. Na nim widać zasób `cache` i logi hosta.
Profil launchSettings AppHost nie zawiera sekretu. `aspire.config.json` wskazuje csproj AppHost,
więc komenda z katalogu głównego nie wymaga zgadywania, który projekt jest hostem składu. Ekran
jest narzędziem pętli deweloperskiej tego numeru. Nie jest składnikiem obrazu, który jedzie na
maszynę. Produkcja go nie uruchamia.

Bez dashboardu jedynym śladem startu jest stdout pięciu procesów. Ten numer ma jeden proces
hosta i jeden zasób, ale ekran ma być ten sam, gdy dojdą bazy i usługi. Deweloper, który dziś
widzi tylko `cache`, ma zobaczyć PostgreSQL w następnym numerze na tym samym ekranie, bez
dokładania Grafany „na chwilę”. Logi hosta pokazują, czy model zasobów wstał. Nie zastępują
testu `/health`. Test jest bramką automatyczną. Dashboard jest wzrokiem człowieka na skład. Oba
są potrzebne, bo fakt nie uruchamia `aspire run`, a `aspire run` nie zastępuje asercji statusu
200.

Konkret JJDevHub: po `aspire run` widać `cache`, a nie widać `Article`, `Account`, `Skill` ani
`StudentInquiry`, bo żaden plik tego numeru ich nie definiuje. Nie widać też hasła. Jeśli na
ekranie pojawia się connection string z wartością, profil albo appsettings dostały sekret i
numer nie jest skończony. Jeśli zasób nazywa się inaczej niż `cache`, kontrakt z numerem 13 jest
złamany, nawet gdy kontener technicznie działa. Dashboard jest tu sprawdzianem nazwy, nie tylko
sprawdzianem „proces żyje”.

Odpadło postawienie Grafany w tym numerze. Grafana na maszynie jest osobnym krokiem i nie
zastępuje pętli `aspire run`. Lokalna Grafana oznaczałaby drugi proces do oglądania metryk,
drugi sposób logowania i pokusę, żeby adres tego procesu wpisać na sztywno. Dashboard Aspire
czyta OTLP, który hak już umie wysłać, gdy zmienna jest ustawiona. Dokładanie Grafany przed
pierwszym zasobem poza Redisem odwraca kolejność: najpierw ekran produkcyjny, potem dopiero
model lokalny. Maszyna dostanie swój podgląd później. Ten numer zostawia pętlę `aspire run`.

Odpadło też oglądanie samego kodu wyjścia procesu Redis. Kod zero nie pokazuje, czy zasób w
składzie nazywa się `cache`. Kontener może wstać pod inną nazwą, na innym porcie, poza modelem
Aspire, i oddać zero, a `AppHost.cs` wcale nie woła `AddRedis("cache")`. Warunek „gotowe” jest
więc podwójny: plik woła `AddRedis("cache")` i dashboard po `aspire run` pokazuje zasób `cache`.
Sam test jednostkowy tego drugiego nie sprawdza, bo nie wymaga Dockera. Oba warunki zostają,
każdy w swoim miejscu.

Koszt jest granicą ekspozycji. Dashboard słucha na porcie deweloperskim i nie jest wystawiany
publicznie. Nie ma hasła w profilu, więc nie ma też „tymczasowego” hasła do ekranu wpisanego w
git. Kto opublikuje port dashboardu na interfejsie poza maszyną dewelopera, wystawi logi hosta i
nazwy zasobów szerzej, niż ten numer zakłada. Produkcja dashboardu nie uruchamia, więc manifest
maszyny nie kopiuje tej usługi jako publicznego panelu. Osobny numer maszyny, przy manifeście
k3s, opisze podgląd, który tam naprawdę zostaje.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `aspire.config.json` | wskazuje csproj AppHost |
| `Directory.Packages.props` | wersje pakietów Aspire, OpenTelemetry, zdrowia i testu |
| `Directory.Build.props` | `net11.0`, nullable, implicit usings, centralne wersje |
| `JJDevHub.AppHost/JJDevHub.AppHost.csproj` | SDK Aspire 13, referencja pakietu Redis |
| `JJDevHub.AppHost/AppHost.cs` | `AddRedis("cache")`, brak domeny |
| `JJDevHub.AppHost/Properties/launchSettings.json` | profil dashboardu, bez wartości sekretu |
| `JJDevHub.ServiceDefaults/JJDevHub.ServiceDefaults.csproj` | pakiety OTel, health, discovery, resilience |
| `JJDevHub.ServiceDefaults/Extensions.cs` | `AddServiceDefaults` i `MapDefaultEndpoints` |
| `tests/JJDevHub.ServiceDefaults.Tests/JJDevHub.ServiceDefaults.Tests.csproj` | xUnit, referencja ServiceDefaults |
| `tests/JJDevHub.ServiceDefaults.Tests/HealthEndpointTests.cs` | fakt `/health` poza Development |

`AppHost.cs` nie referencjonuje `ServiceDefaults`. Host składu nie jest usługą HTTP. Test buduje
krótki host sam, w projekcie testowym. `Extensions.cs` jest jedynym miejscem metod wspólnych.
Csproj biblioteki trzyma pakiety, a wersje tych pakietów i tak stoją w
`Directory.Packages.props`, nie przy referencji. Plik testu nie zna Redisa i nie zna agregatu.

## Plan

### 1. Plik solution i centralne wersje

Utwórz solution `JJDevHub.slnx` w korzeniu, jeśli go nie ma, i dopnij istniejący
`JJDevHub.AppHost`. Dodaj `Directory.Build.props` z `TargetFramework` `net11.0`, `Nullable`
`enable`, `ImplicitUsings` `enable` oraz `ManagePackageVersionsCentrally` `true`. Dodaj
`Directory.Packages.props`. Przenieś wersję linii Aspire z `JJDevHub.AppHost.csproj` do tego
pliku. `PackageReference` w csproj zostaje bez atrybutu `Version`. Zostaw `aspire.config.json`
wskazujący `JJDevHub.AppHost/JJDevHub.AppHost.csproj`.

### 2. AppHost i zasób cache

W `AppHost.cs` zostaw budowę aplikacji rozproszonej. Zarejestruj Redis wywołaniem `AddRedis` z
argumentem `cache`. Nie dodawaj projektu Identity, News, Learning, Cv, Contact ani Gateway. Nie
dodawaj PostgreSQL, Kafki ani OpenBao. Nie wołaj klienta Redis i nie ustawiaj prefiksu klucza.
LaunchSettings nie dostaje haseł, tokenów ani connection stringów.

### 3. Biblioteka ServiceDefaults

Utwórz projekt biblioteczny `JJDevHub.ServiceDefaults`. Dopnij pakiety: hosting OpenTelemetry,
eksporter OTLP, instrumentację ASP.NET Core, HTTP i runtime, health checks, service discovery,
resilience HTTP. W `Extensions.cs` dodaj metody z tabeli ścieżek. `AddServiceDefaults` woła
konfigurację telemetrii, domyślne health checks, `AddServiceDiscovery` i
`ConfigureHttpClientDefaults`. W konfiguracji klienta HTTP włącz `AddStandardResilienceHandler`
i `AddServiceDiscovery`. `AddDefaultHealthChecks` rejestruje sprawdzenie `self` ze stanem
`Healthy` i tagiem `live`.

### 4. Mapowanie health

`MapDefaultEndpoints` mapuje `/health` bez predykatu i `/alive` z predykatem tagu `live`. Nie
owijaj mapowania w `IsDevelopment()`. Nie zwracaj ciała z konfiguracją.

### 5. Hak eksportera

`ConfigureOpenTelemetry` włącza logi OTel z zakresami i sformatowaną wiadomością. Metryki:
ASP.NET Core, HTTP client, runtime. Ślady: źródło o nazwie aplikacji, ASP.NET Core, HTTP client.
Filtr śladu ASP.NET Core odrzuca ścieżki zaczynające się od `/health` i `/alive`. Eksporter OTLP
dodaj wyłącznie, gdy `OTEL_EXPORTER_OTLP_ENDPOINT` jest niepusty. Nie wpisuj adresu kolektora w
appsettings. Nie dodawaj eksportera chmurowego.

### 6. Test hosta

Utwórz `tests/JJDevHub.ServiceDefaults.Tests`. Test buduje `WebApplication` ze środowiskiem
innym niż Development, woła `AddServiceDefaults` i `MapDefaultEndpoints`, potem `GET /health`.
Dopnij oba projekty do solution. Uruchom komendę z sekcji testów.

### Co jest do czego

`AddRedis("cache")` woła `AppHost.cs`. Tworzy zasób, który dashboard pokazuje pod nazwą `cache`,
i nazwę connection stringa `ConnectionStrings:cache`. Żaden handler domenowy go jeszcze nie
czyta. Gdy wywołania nie ma, `aspire run` nie ma zasobu o tej nazwie, a numer cache nie ma do
czego podpiąć prefiksu. Kontener odpalony obok, pod inną nazwą, tego braku nie leczy.

`AddServiceDefaults` woła przyszły `Program.cs` usługi i test tego numeru. Składa telemetrię,
health, discovery i odporność klienta HTTP. AppHost tej metody nie woła. Gdy metody nie ma,
każda usługa albo kopiuje blok, albo startuje bez haka. Test nie ma czego zbudować i fakt
`/health` nie powstaje. Brama i pięć usług rozjeżdżają się od pierwszej linii `Program.cs`.

`ConfigureHttpClientDefaults` woła `AddServiceDefaults`. Włącza fabrykę klienta z
`AddStandardResilienceHandler` i `AddServiceDiscovery`. Gdy tego nie ma, `HttpClient` z fabryki
ServiceDefaults nie znajduje usługi po nazwie i nie ma wspólnego handlera odporności. Każdy
caller wraca do ręcznego adresu i do własnych ponowień.

`AddServiceDiscovery` woła ten sam skład klienta oraz `AddServiceDefaults`. Gdy go nie ma, nazwa
zasobu nie zamienia się na adres procesu. Późniejsza brama i usługi musiałyby dostać porty na
sztywno, czyli wrócić do modelu, który AppHost właśnie zdejmuje.

`AddStandardResilienceHandler` woła konfiguracja klienta HTTP. Gdy go nie ma, krótka przerwa
sąsiada kończy się innym błędem w każdej usłudze. Wspólna polityka znika i testy zaczynają
zależeć od lokalnego szczęścia do portu.

`AddDefaultHealthChecks` woła `AddServiceDefaults`. Rejestruje `self`. Gdy go nie ma, `/health`
nie ma sprawdzenia, a `/alive` nie ma tagu `live`. Orkiestrator dostaje ścieżkę albo pustą, albo
bez znaczenia „proces odpowiada”.

`MapDefaultEndpoints` woła ten sam host po `Build`. Wystawia dwie ścieżki dla orkiestratora i
dla testu. Gdy go nie ma, `GET /health` i `GET /alive` nie istnieją. Próbka dostaje `404`. Fakt
tego numeru jest czerwony. Owinięcie w `IsDevelopment()` daje ten sam skutek poza developmentem,
przy zielonym teście lokalnym, jeśli test zapomni o `Production`.

`ConfigureOpenTelemetry` jest wołane tylko z `AddServiceDefaults`. Decyduje, jakie sygnały
wychodzą, gdy dashboard poda endpoint OTLP. Gdy go nie ma, usługa nie wysyła logów, metryk ani
śladów. Dashboard pokazuje dziurę. Adres kolektora wpisany na sztywno psuje drugi ze środowisk:
development albo maszynę.

Sprawdzenie `self` jest wołane przez middleware health. Mówi, że proces odpowiada. Nie mówi, że
Redis przyjął zapis. Gdy go nie ma, tag `live` jest pusty i `/alive` nie ma reguły, która znaczy
„proces żyje”. Gdy ktoś rozszerzy `self` o hasło w opisie, ścieżka zaczyna wynosić sekret, choć
stan dalej nazywa się `Healthy`.

## Testy

Test tego numeru jest jeden. Runner to xUnit, metoda ma `[Fact]`. Nie ma cechy
`Category=Integration` i nie ma cechy `Category=Performance`. Powód padnięcia jest jeden: `GET
/health` na hoście poza środowiskiem Development nie zwraca sukcesu. NBomber dochodzi w
[22-testy.md](22-testy.md) i nie wchodzi do tego numeru. Testcontainers dochodzi w
[02-postgres.md](02-postgres.md). Docker nie jest zależnością tej biblioteki testowej. Cecha
integracyjna na tym fakcie wciągnęłaby go w filtr, który krótka pętla jednostkowa świadomie
pomija, i związałaby status ścieżki z obecnością silnika, którego ten numer nie stawia.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | `WebApplication.CreateBuilder` z `EnvironmentName` ustawionym na `Production`, wywołanie `AddServiceDefaults`, `Build`, `MapDefaultEndpoints` |
| Działanie (act) | `HttpClient` z `WebApplicationFactory` albo z testowego serwera wysyła `GET /health` |
| Sprawdzenie (assert) | kod statusu to 200 |

Nazwa metody: `Health_endpoint_returns_ok_outside_development`.

```text
dotnet test tests/JJDevHub.ServiceDefaults.Tests/JJDevHub.ServiceDefaults.Tests.csproj --filter "FullyQualifiedName~Health_endpoint_returns_ok_outside_development"
```

Test nie ustawia `OTEL_EXPORTER_OTLP_ENDPOINT`. Brak endpointu oznacza brak eksportera, nie
wyjątek przy starcie. Test nie łączy się z Redisem. Padnięcie z innego powodu, na przykład z
timeoutu kontenera, znaczy, że test sprawdza za dużo i trzeba go zwęzić do statusu `/health`.
Asercja nie czyta ciała odpowiedzi w poszukiwaniu connection stringa. Wystarcza kod 200. Ciało z
sekretem byłoby osobną szkodą, opisaną w zasadach, a nie drugim powodem tego faktu.

Przygotowanie jest celowo ubogie. Środowisko `Production` odcina skrót `IsDevelopment()`.
`AddServiceDefaults` musi zarejestrować `self`, inaczej ścieżka nie ma sprawdzenia, które zwraca
sukces. `MapDefaultEndpoints` musi zarejestrować `/health` bez warunku środowiska. Działanie
jest jednym żądaniem GET. Nie ma PUT, nie ma ciała i nie ma nagłówka z tokenem. Sprawdzenie
patrzy na status. Nie patrzy na nazwę zasobu Redis, bo ten proces testowy nie uruchamia AppHost.

Komenda z filtrem po nazwie metody jest bramką tego numeru. Obok niej zostaje szerszy filtr
`dotnet test --filter "Category!=Integration&Category!=Performance"`. Ten fakt ma przejść także
tam, bo nie niesie cechy integracyjnej ani wydajnościowej. Czerwony wynik szerszego filtra przy
zielonej komendzie z nazwy metody znaczyłby, że fakt dostał cechę, której sekcja testów
zabrania. NBomber nie dostaje tu scenariusza. Pomiar próbki pod obciążeniem należy do numeru 22
i miałby inny powód padnięcia: czas, a nie status.

## Zasady

- W `JJDevHub.ServiceDefaults` nie ma typu domenowego i nie ma roli `owner` ani `student`.
  Złamanie wciąga News albo Identity do biblioteki, którą referencjonuje każda usługa i brama.
- `AppHost.cs` nie tworzy agregatu i nie otwiera bazy. Złamanie przenosi schemat i typ domenowy
  do hosta składu, który nie jest usługą HTTP.
- Nazwa zasobu Redis to dokładnie `cache`. Inna nazwa gasi `ConnectionStrings:cache` i zmusza
  numer cache do drugiej nazwy zasobu.
- Connection string tego zasobu nie jest wpisany w pliku w gicie. Wpis zostawia hasło albo
  lokalny port w historii klonu.
- `/health` i `/alive` istnieją także wtedy, gdy środowisko nie jest Development. Warunek
  `IsDevelopment()` daje próbce na maszynie `404` przy żywym procesie.
- Odpowiedź health nie zawiera sekretu. Ciało z connection stringiem albo z wyjątkiem wynosi
  sekret do logu orkiestratora.
- Eksporter OTLP nie ma adresu na sztywno. Adres w kodzie albo w appsettings ustawia ten sam
  kolektor dla developmentu i dla maszyny.
- Pakiety tego numeru są na liście w [README.md](README.md): MIT albo Apache-2.0. Pakiet spoza
  listy łamie regułę licencji w pierwszym numerze składu.
- Wersja jest tylko w `Directory.Packages.props`. Własny `Version` w csproj rozjeżdża
  OpenTelemetry między hostami.
- Log ze śladu nie zapisuje ciała, które mogłoby być tokenem. Zapis ciała kładzie sekret na
  dashboardzie.
- `HttpClient` tworzony przez fabrykę z ServiceDefaults ma discovery i handler odporności. Brak
  jednego z nich wraca do portu na sztywno i do własnych ponowień w każdej usłudze.
- Test jednostkowy tego numeru nie wymaga Dockera. Zależność od kontenera wiąże status `/health`
  z silnikiem, którego fakt nie sprawdza.

## Poza zakresem

- Pięć baz zapisu jest w [02-postgres.md](02-postgres.md). Ten numer nie woła `AddPostgres` i
  nie tworzy `identity_write` ani pozostałych nazw.
- Pięć baz odczytu i indeksy są w [03-odczyt.md](03-odczyt.md). Ten numer nie tworzy tabeli
  odczytu i nie wybiera indeksu.
- OpenBao i `ISecretReader` są w [04-openbao.md](04-openbao.md). Ten numer nie stawia serwera
  sekretów i nie czyta tokenu.
- `Result` i typy jądra są w [05-kernel.md](05-kernel.md). Ten numer nie wprowadza typu wyniku
  ani obiektu wartości.
- Zapis klucza, prefiks nazwy usługi i unieważnienie cache są w [13-redis.md](13-redis.md). Ten
  numer nie woła klienta Redis.
- Broker Kafka jest w [15-kafka.md](15-kafka.md). Ten numer nie rejestruje brokera i nie woła
  `AddKafka`.
- Brama YARP jest w [16-gateway.md](16-gateway.md). Ten numer nie dodaje projektu Gateway.
- Test wydajnościowy NBomber jest w [22-testy.md](22-testy.md). Ten numer nie nadaje cechy
  `Category=Performance`.
- Ten numer nie dodaje `WithReference` do usługi, bo usługi jeszcze nie ma. Referencja doszłaby
  razem z projektem, którego tu nie tworzymy.

## Źródła

- [.NET Aspire overview](https://learn.microsoft.com/dotnet/aspire/get-started/aspire-overview).
  Wiążący jest model AppHost: projekt wykonywalny, rejestracja zasobów i dashboard po
  uruchomieniu składu. Dotyczy decyzji o składzie .NET Aspire 13 oraz tego, że nazwa zasobu i
  kolejność startu siedzą w `AppHost.cs`. Ze źródła nie bierzemy katalogu integracji, których
  ten numer nie rejestruje. PostgreSQL, Kafka i OpenBao zostają w swoich numerach, a AppHost nie
  jedzie na maszynę jako obraz produkcyjny.
- [Service defaults](https://learn.microsoft.com/dotnet/aspire/fundamentals/service-defaults).
  Wiążące są wspólne metody hosta HTTP: telemetria, health, odkrywanie usług i odporność
  klienta. Dotyczy projektu `JJDevHub.ServiceDefaults`, wywołań `AddServiceDefaults` i
  `MapDefaultEndpoints` oraz zakazu kopiowania tego bloku do każdego `Program.cs`. Ze źródła nie
  bierzemy domeny usługi ani sprawdzenia roli. Biblioteka nie zna `Article` i nie zna `owner`.
- [Health checks in
  Aspire](https://learn.microsoft.com/dotnet/aspire/fundamentals/health-checks). Wiążący jest
  podział na `/health` i `/alive` oraz tag `live` przy sprawdzeniu, które znaczy, że proces
  żyje. Dotyczy mapowania poza `IsDevelopment()`, sprawdzenia `self` ze stanem `Healthy` i testu
  w środowisku `Production`. Ze źródła nie bierzemy sprawdzenia, które w opisie zwraca
  connection string albo hasło. `self` nie otwiera Redisa.
- [Aspire dashboard](https://learn.microsoft.com/dotnet/aspire/dashboard/overview). Wiążące jest
  to, co widać po `aspire run`: zasoby składu i logi hosta. Dotyczy decyzji, że ekranem pętli
  lokalnej jest dashboard, a zasób ma być widoczny pod nazwą `cache`. Ze źródła nie bierzemy
  wystawienia dashboardu publicznie i nie bierzemy Grafany jako zamiennika tej pętli. Produkcja
  dashboardu nie uruchamia.
- [Redis
  integration](https://learn.microsoft.com/dotnet/aspire/caching/stackexchange-redis-integration).
  Wiążące jest to, że nazwa zasobu staje się nazwą connection stringa. Dotyczy
  `AddRedis("cache")` i kontraktu `ConnectionStrings:cache`. Ze źródła nie bierzemy jeszcze
  klienta StackExchange, prefiksu klucza, Memcached ani `IMemoryCache` jako zamiennika zasobu.
- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/dotnet/). Wiążące są trzy
  sygnały: log, ślad i metryka, oraz eksporter OTLP. Dotyczy `ConfigureOpenTelemetry`, filtra
  ścieżek `/health` i `/alive` oraz licencji Apache-2.0 pakietów w `Directory.Packages.props`.
  Ze źródła nie bierzemy eksportera Azure Monitor ani liczników domenowych. Cel lokalny to
  dashboard, a na maszynie kolektor.
- [Telemetry](https://learn.microsoft.com/dotnet/aspire/fundamentals/telemetry). Wiążące jest
  włączanie eksportera OTLP dopiero przy niepustym `OTEL_EXPORTER_OTLP_ENDPOINT` oraz to, że
  dashboard sam tę zmienną ustawia. Dotyczy haka eksportera i zakazu adresu kolektora w
  appsettings. Ze źródła nie bierzemy wpisu adresu do pliku json i nie bierzemy wyjątku przy
  starcie, gdy zmiennej nie ma. Test tego numeru zmiennej nie ustawia.
- [Health checks in ASP.NET
  Core](https://learn.microsoft.com/aspnet/core/host-and-deploy/health-checks). Wiążące jest
  mapowanie sprawdzeń na ścieżkę i predykat, który zostawia tylko wybrane tagi. Dotyczy
  `/health` bez predykatu, `/alive` z tagiem `live` i rejestracji `self`. Ze źródła nie bierzemy
  traktowania otwartego portu TCP jako gotowości ani ciała odpowiedzi zbudowanego z
  konfiguracji. Odpowiedź zostaje statusem.
- [xUnit](https://xunit.net/). Wiążące jest oznaczenie metody atrybutem `[Fact]` i możliwość
  nadania cechy, której ten numer świadomie nie nadaje. Dotyczy
  `Health_endpoint_returns_ok_outside_development` oraz filtra
  `Category!=Integration&Category!=Performance`. Ze źródła nie bierzemy teorii z wieloma
  wierszami, cechy `Category=Integration` ani NBombera, a Docker nie jest zależnością tego
  faktu.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic: osobny AppHost, wspólne
  ServiceDefaults i osobny zasób na współdzieloną infrastrukturę. Dotyczy tego, że
  `JJDevHub.ServiceDefaults` nie jest `Api` jednej usługi, oraz tego, że Redis wchodzi jako
  zasób składu, a nie jako typ domenowy. Z tego repozytorium nie bierzemy MediatR ani
  IntegrationEventLogEF. Nie bierzemy też domeny cudzego sklepu jako modelu JJDevHub.

## Gotowe gdy

- `aspire.config.json` wskazuje AppHost, a `AppHost.cs` woła `AddRedis("cache")`.
- W `AppHost.cs` nie ma `AddPostgres`, `AddKafka` ani projektu usługi domenowej.
- `JJDevHub.ServiceDefaults` kompiluje się i jest w solution.
- `MapDefaultEndpoints` mapuje `/health` i `/alive` bez warunku `IsDevelopment()`.
- Eksporter OTLP zależy od `OTEL_EXPORTER_OTLP_ENDPOINT`.
- W launchSettings i w appsettings tego numeru nie ma wartości sekretu.
- Komenda z sekcji testów kończy się kodem zero.
- `dotnet test --filter "Category!=Integration&Category!=Performance"` też przechodzi ten fakt,
  bo fakt nie ma cechy integracyjnej.
- Dashboard po `aspire run` pokazuje zasób `cache`.
- Żaden plik tego numeru nie definiuje `Article`, `Account`, `Skill` ani `StudentInquiry`.
