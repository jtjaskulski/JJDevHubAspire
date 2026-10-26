# 16. Brama YARP

Ten numer stawia jedyne wejście HTTP aplikacji. `JJDevHub.Gateway` w
`src/gateway/JJDevHub.Gateway` rozkłada ruch na Identity, News, Learning, Cv i Contact, sprawdza
JWT kluczem publicznym z JWKS i wystawia `GET /versions`. Szyna z [15-kafka.md](15-kafka.md) nie
przechodzi przez bramę. W kolejności pracy najpierw jest deploy tej bramy w
[16-deploy.md](../cicd/16-deploy.md), jedna replika. Konta i klucz prywatny dochodzą w
[17-identity.md](17-identity.md), następnym pliku tego folderu. Bez
tego numeru przeglądarka musiałaby znać pięć hostów, pięć certyfikatów i pięć miejsc, w których
wersja obrazu jest inna niż na stopce.

Cloudflare kończy się na tej bramie. Pięć usług nie ma własnego wejścia z zewnątrz. Na maszynie
Kubernetes Service rozłoży pody jednej usługi. W konfiguracji YARP polityka równoważenia jest
już okrężna, gotowa na wiele adresów docelowych. W developmentcie Aspire trzyma jedną replikę.
`LoadBalancingPolicy` równe `RoundRobin` i tak stoi. Dopisanie drugiego adresu nie wymaga nowej
polityki. Na maszynie celem jest jeden adres Service, a kube-proxy rozkłada pody. Oba układy
korzystają z tej samej bramy.

Klucz prywatny JWT zostaje w Identity. Brama i usługi biorą klucz publiczny z
`/.well-known/jwks.json`. Wyciek konfiguracji bramy nie podpisuje tokenu. Zły podpis, zły czas
albo zły wystawca daje `401` i żądanie nie dochodzi do usługi. Brak nagłówka na trasie
publicznej puszcza żądanie dalej. Trasy intranetu wymagają tokenu już na bramie. Rola `owner`
albo `student` jest sprawdzana w usłudze. Brama nie zwraca `403` za złą rolę, bo ukryta treść ma
zostać `404` z numeru [11-walidacja.md](11-walidacja.md), a o widoczności wie handler, nie
tabela tras.

## Po co

Przeglądarka i telefon mają jeden adres. Nie znają hostów pięciu procesów i nie trzymają pięciu
certyfikatów. Brama przyjmuje żądanie, sprawdza podpis tokenu, gdy token jest, i przekazuje je
do usługi razem z nagłówkiem `api-version`. `GET /api/news/articles` dochodzi do klastra `news`
i nie dochodzi do pozostałych czterech. Ta sama własność dotyczy `identity`, `learning`, `cv` i
`contact`. Zła trasa chowa endpoint, który w usłudze działa. Test tras jest w tym numerze i
pada, gdy ścieżka nie dochodzi do właściwego klastra.

`GET /versions` zwraca numery działających obrazów: `identity`, `news`, `learning`, `cv`,
`contact` i `gateway`. Stopka klienta pokazuje obok numer klienta. Bez tego końca nie da się
powiedzieć, który obraz narysował treść. Brama woła `GET /version` na każdym z pięciu klastrów,
równolegle, z timeoutem 500 ms na wywołanie, krótszym niż timeout trasy użytkownika. Usługa,
która nie zdąży, daje w swoim polu `null`. Całość wraca jako `200`, żeby klient mógł pokazać
resztę. Wersja bramy nie jest `null`: proces, który odpowiada, zna własny zestaw. Brama nie
składa wersji z pamięci o wdrożeniu. Pyta działający proces. Zły pod widać od razu.

`/versions` nie wymaga tokenu. Nie niesie treści CV ani listy kont. Niesie numery obrazów, które
i tak są na ekranie. Usługa zwraca `{ "name": "news", "version": "1.4.0" }`. Wersja jest
`AssemblyInformationalVersion` obrazu, tym samym numerem co tag `news-v1.4.0` bez prefiksu
nazwy. Pięć krótkich wywołań pada na każde otwarcie stopki. Usługi trzymają odpowiedź w pamięci
procesu, bez Redisa i bez bazy. To nie jest projekcja i nie jest odczyt strumienia.

Nagłówek `api-version` jedzie razem z żądaniem. Brama go nie zdejmuje i nie podmienia. Brak
nagłówka oznacza `1.0` w usłudze, tak samo w pięciu hostach, przez `ServiceDefaults`. Nieznana
wersja kończy się w usłudze statusem `400` i kodem `api.version.unsupported`, ciałem
`ProblemDetails` z numeru `11`. Brama nie trzyma własnej listy wersji. Inaczej dwie listy
rozjechałyby się przy pierwszym endpoincie. Ścieżka zostaje `/api/news/...`, nie `/api/v1/news`.
Wersja w URL myli się z identyfikatorem w cache klienta. Query `?api-version=` gubi się w logu
dostępu i w zakładce.

Obecny, ale zły token, pada na bramie także na trasie publicznej. Podpis jest albo ważny, albo
żądanie nie idzie dalej. Brak tokenu na trasie publicznej idzie dalej, a usługa decyduje, czy
treść jest publiczna, czy ma wyglądać jak brak wiersza. Trasa z metadanymi `AuthorizationPolicy`
równymi `authenticated` bez tokenu daje `401`. Usługi też walidują JWT tym samym JWKS. Wołanie z
pominięciem bramy w sieci klastra nie staje się zaufane tylko dlatego, że doszło do poda. Log
bramy ma ścieżkę, status i nazwę klastra, bez ciała notatki i bez treści zapytania Contact.

## Dlaczego ta technologia

### YARP

YARP (`Yarp.ReverseProxy`, MIT) jest odwrotnym proxy w procesie ASP.NET. Trasy i klastry są w
konfiguracji, filtry dopisują nagłówki, a reszta żądania idzie do usługi bez przepisywania
ciała. Własny `HttpClient` na każdą trasę przegrywa, bo sami pisalibyśmy pule połączeń, czas
oczekiwania i przekazywanie strumienia odpowiedzi. Nginx przed pięcioma procesami przegrywa jako
jedyna brama aplikacji, bo wersje, JWKS i `api-version` i tak żyłyby w kodzie .NET obok niego.
Zostaje jeden proces, który umie i proxy, i `GET /versions`.

Koszt: brama jest na ścieżce każdego żądania. Jej awaria chowa wszystkie usługi. Dlatego jest
osobnym obrazem, z własnym tagiem `gateway-vX.Y.Z`, i da się ją cofnąć bez cofania News. Pakiet
wchodzi do tabeli licencji przy numerze `16`. Wersja jest w `Directory.Packages.props`. Nowa
usługa to wiersz w tabeli tras i w teście. Nie ma wykrywania tras z refleksji. `{**catch-all}`
przekazuje resztę ścieżki. Brama nie zamienia jej na inną konwencję.

W tym rozwiązaniu usługa nasłuchuje pełnej ścieżki `/api/{nazwa}/...`, a brama nie obcina
prefiksu. `PathRemovePrefix` zostałby użyty, gdyby usługa nasłuchiwała bez `/api/{nazwa}`. Nie
nasłuchuje. Jedna konwencja w kliencie, w bramie i w endpoincie. Test `News_route_hits_news`
woła `GET /api/news/articles` przez bramę i oczekuje, że nasłuch News dostał tę ścieżkę, a
pozostałe cztery nie. To samo dla `GET /api/identity/accounts`, `GET /api/learning/courses`,
`GET /api/cv/profile` i `GET /api/contact/recruiter`. Każdy klaster ma `HttpRequest` z timeoutem
i `LoadBalancingPolicy` równe `RoundRobin`.

### Jedno wejście HTTP

Z zewnątrz jest jeden host. Trasy publiczne są pod tym hostem. Identity, News, Learning, Cv i
Contact nasłuchują w sieci wewnętrznej. W AppHost ich endpointy nie są publikowane na localhost
obok bramy jako adres dla przeglądarki. Test deweloperski woła bramę. Osobny host na usługę
przegrywa, bo klient musiałby znać topologię, a CORS i ciasteczka mnożyłyby się przez pięć.
Drugie proxy tylko do statycznego frontu jest po stronie klienta web, nie tutaj. Tu mowa o API.

Koszt: zła trasa w bramie chowa endpoint, który w usłudze działa. Dlatego test tras jest w tym
numerze, na `WebApplicationFactory` i na pięciu lekkich nasłuchach, bez Postgresa, Kafki i
Redisa. Cecha `Integration` nie jest potrzebna, dopóki nie ma kontenera. Test i tak jest w xUnit
i ma jeden powód do padnięcia na fakt. Adres docelowy w AppHost to nazwa zasobu Aspire. Drugi
adres dokłada się jako kolejne `Destination`, bez zmiany kodu trasy. Plik `appsettings.json` w
gicie nie zawiera hasła, connection stringa ani klucza. Adres `http://news` w przykładzie jest
nazwą w sieci AppHost, nie adresem publicznym.

`/versions` jest `MapGet` w `Program.cs` i nie występuje w `ReverseProxy.Routes`. Brama
odpowiada sama. Gdyby ta ścieżka weszła do klastra, wersja bramy zależałaby od tego, czy któraś
usługa żyje, a klient nie odróżniłby padniętej bramy od padniętego News. News i tak ma własne
`GET /version` na adresie klastra, wewnętrzne, nie pod `/api/news/version`. Publicznie klient
woła tylko `/versions`.

### JWKS i sam klucz publiczny

Identity wystawia `/.well-known/jwks.json`. Brama konfiguruje `JwtBearer` z `MetadataAddress`
albo z jawnym adresem JWKS tej usługi, w sieci wewnętrznej. `TokenValidationParameters` mają
włączone sprawdzenie podpisu, wystawcy, odbiorcy i czasu. `RequireHttpsMetadata` jest włączone
tam, gdzie adres jest `https`. W AppHost na deweloperskim HTTP flaga jest wyłączona tylko dla
tego jednego URL-a wewnętrznego. `AddGatewayJwt` ustawia `Authority` na wewnętrzny adres
Identity, pobieranie kluczy z JWKS i wyłącza mapowanie ról na osobne schematy, których brama nie
używa. `OnTokenValidated` nie woła bazy. `OnAuthenticationFailed` zwraca `401` z
`ProblemDetails` i kodem `auth.token.invalid`, przez writer z numeru `11`, w języku
`Accept-Language`.

Klucz prywatny w konfiguracji bramy przegrywa, bo brama nie wystawia tokenów, a każdy dodatkowy
egzemplarz klucza to dodatkowy wyciek. Wspólny sekret HMAC przegrywa z tego samego powodu:
sekret musiałby być w pięciu usługach i w bramie. Klucz publiczny wolno powielać. Test stawia
osobny nasłuch JWKS z kluczem RSA utworzonym w teście. Klucz prywatny nie wchodzi do
konfiguracji bramy. Brama dostaje tylko URL dokumentu. `Invalid_signature_returns_401` podpisuje
token innym kluczem, woła `GET` trasy publicznej i oczekuje `401` oraz nasłuchu usługi
niewołanego.

Brama sprawdza podpis, gdy nagłówek `Authorization: Bearer` jest. Zły podpis, zły czas albo zły
wystawca daje `401` i żądanie nie dochodzi do usługi. Brak nagłówka na trasie publicznej puszcza
żądanie dalej. `Public_route_without_token_is_forwarded` oczekuje, że nasłuch jest wołany.
`Intranet_route_without_token_returns_401` na trasie `authenticated` oczekuje `401`. Rola
`owner` albo `student` jest sprawdzana w usłudze. Brama nie zwraca `403` za złą rolę. Ukryty
szkic ma zostać `404`, a o widoczności wie handler zapytania, nie tabela tras. Wydanie ról i
samego dokumentu po stronie Identity jest w numerze `17`. Tu jest sprawdzenie klucza
publicznego.

Usługi też walidują JWT tym samym JWKS. Wołanie z pominięciem bramy w sieci klastra nie staje
się zaufane tylko dlatego, że doszło do poda. Koszt: przy starcie brama musi móc przeczytać
JWKS. Krótki przestój Identity oznacza, że nowy klucz jeszcze nie wszedł do cache. `JwtBearer`
trzyma klucze i odświeża je. Token podpisany kluczem, którego jeszcze nie ma w dokumencie,
dostaje `401`. To jest uczciwe: brama nie zgaduje podpisu z lokalnej kopii klucza prywatnego, bo
tej kopii nie ma.

### Trasy do pięciu usług

| Ścieżka na bramie | Klaster | Usługa |
| --- | --- | --- |
| `/api/identity/{**catch-all}` | `identity` | Identity |
| `/api/news/{**catch-all}` | `news` | News |
| `/api/learning/{**catch-all}` | `learning` | Learning |
| `/api/cv/{**catch-all}` | `cv` | Cv |
| `/api/contact/{**catch-all}` | `contact` | Contact |
| `/versions` | żaden | brama odpowiada sama |

`{**catch-all}` przekazuje resztę ścieżki. Brama nie zamienia jej na inną konwencję. Usługa
widzi tę samą ścieżkę, którą widział klient, albo ścieżkę po transformacji `PathRemovePrefix`,
jeśli usługa nasłuchuje bez prefiksu `/api/{nazwa}`. W tym rozwiązaniu usługa nasłuchuje pełnej
ścieżki `/api/{nazwa}/...`, a brama nie obcina prefiksu. Jedna konwencja w kliencie, w bramie i
w endpoincie. Artykuł, kurs, profil CV i zapytanie rekrutera nie dostają własnych hostów.
Dostają prefiks na tym jednym hoście.

Każdy klaster ma `HttpRequest` z timeoutem i `LoadBalancingPolicy` równe `RoundRobin`. Adres
docelowy w AppHost to nazwa zasobu Aspire. Drugi adres dokłada się jako kolejne `Destination`,
bez zmiany kodu trasy. W `appsettings.json` pięć klastrów. Każdy ma jedną destynację z adresem
pustym w repozytorium i uzupełnianym przez Aspire (`WithReference`) albo przez konfigurację
środowiska. Przykład `news` ma `Destinations.news-1.Address` równe `http://news`. Ten sam blok
jest dla `identity`, `learning`, `cv` i `contact`.

Koszt: nowa usługa to wiersz w tej tabeli i w teście. Nie ma wykrywania tras z refleksji. Brak
wiersza dla Contact oznacza, że `GET /api/contact/recruiter` nie ma klastra, nawet jeśli proces
Contact żyje w sieci wewnętrznej. Test `Contact_route_hits_contact` jest po to, żeby ten brak
było widać bez ręcznego klikania. Trasa YARP nie zawiera reguł notatki ani CV. Nie wie, czy slug
jest publiczny. Wie tylko, który klaster dostaje ścieżkę.

### Nagłówek `api-version`

Wersja API jest w nagłówku `api-version`, nie w ścieżce. Ścieżka zostaje stabilna, a wersja
kontraktu jedzie obok. Pakiet `Asp.Versioning.Http` (MIT) stoi w usługach i czyta ten nagłówek.
Brama go nie zdejmuje i nie podmienia. Domyślna wersja, gdy nagłówka nie ma, to `1.0`, ustawiona
w usługach tak samo przez `ServiceDefaults`. `AddApiVersioning` ustawia `ApiVersionReader` na
nagłówek `api-version` i `AssumeDefaultVersionWhenUnspecified` na `1.0`. Brama w transformacji
trasy nie ma `RequestHeader` usuwającego ten nagłówek. Test `Version_header_reaches_service`
wysyła `api-version: 1.0` i czyta nagłówek na nasłuchu testowym. Test
`Missing_version_header_defaults_on_service` woła `GET` bez nagłówka i oczekuje, że usługa widzi
`1.0`.

Wersja w URL (`/api/v1/news`) przegrywa, bo każdy zasób dostaje podwójne ścieżki i cache klienta
myli wersję z identyfikatorem. Query `?api-version=` przegrywa, bo łatwo zgubić je w logu
dostępu i w zakładce. Nagłówek zostaje przy żądaniu i przy przekierowaniu proxy. Nieznana wersja
kończy się w usłudze statusem `400` i kodem `api.version.unsupported`, ciałem `ProblemDetails` z
numeru `11`. Brama nie trzyma własnej listy wersji. Inaczej dwie listy rozjechałyby się przy
pierwszym endpoincie artykułu albo kursu.

Koszt: klient musi umieć wysłać nagłówek. Klient web i telefon wysyłają `1.0`, dopóki numer
klienta nie powie inaczej. Pakiet wersjonowania jest na `JJDevHub.ServiceDefaults`, nie
kopiowany do pięciu `Program.cs` z drobnymi różnicami. Brama nie interpretuje wartości. Gdyby
interpretowała, musiałaby znać każdy kod `api.version.unsupported` i każdy zasób `pl` oraz `en`.
Zostawia to usłudze, która i tak składa `ProblemDetails`.

### `GET /versions`

Brama woła `GET /version` na każdym z pięciu klastrów, równolegle, z timeoutem krótszym niż
timeout trasy użytkownika. `ServiceVersionClient.GetRunningVersionsAsync` używa `Task.WhenAll` i
timeoutu 500 ms na wywołanie. Wyjątek albo timeout jednego wołania daje `null` w tym polu i nie
przerywa reszty. Usługa zwraca `{ "name": "news", "version": "1.4.0" }`. Wersja jest
`AssemblyInformationalVersion` obrazu, tym samym numerem co tag `news-v1.4.0` bez prefiksu
nazwy. Brama dopisuje własną wersję i zwraca sześć pól. `RunningVersions` jest `sealed record` z
sześcioma polami `string?` dla usług i `string` dla bramy.

```json
{
  "identity": "1.0.0",
  "news": "1.4.0",
  "learning": "1.0.0",
  "cv": "1.0.0",
  "contact": "1.0.0",
  "gateway": "1.0.0"
}
```

Usługa, która nie zdąży, daje w swoim polu `null`. Całość wraca jako `200`, żeby klient mógł
pokazać resztę. Test `Unreachable_service_is_null` zatrzymuje nasłuch News i oczekuje `news`
równego `null`, `gateway` niepustego i statusu 200. Test `Versions_returns_six_fields` przy
pięciu nasłuchach ze stałymi wersjami oczekuje pól `identity`, `news`, `learning`, `cv`,
`contact` i `gateway`. Brama nie składa wersji z własnej pamięci o wdrożeniu. Pyta działający
proces. Dzięki temu zły pod widać od razu.

`/versions` nie wymaga tokenu. Nie niesie treści CV ani listy kont. Niesie numery obrazów, które
i tak są na ekranie. Koszt: pięć krótkich wywołań na każde otwarcie stopki. Usługi trzymają
odpowiedź w pamięci procesu, bez Redisa i bez bazy. To nie jest projekcja.
`ServiceVersion.Current` czyta `AssemblyInformationalVersion`. Brama woła ścieżkę wewnętrzną
`/version`, nie `/api/news/version`, na adresie klastra. Publicznie klient woła tylko
`/versions` na bramie. Endpoint `/version` w usłudze jest mały i powstaje razem z `Api` tej
usługi. Ten numer definiuje jego kontrakt i testuje bramę na pięciu nasłuchach testowych, które
zwracają stałą wersję. Prawdziwe `Identity.Api` dołączy ten endpoint w numerze `17`, tym samym
rekordem.

### Round-robin i później Service

`LoadBalancingPolicy` równe `RoundRobin` obejmuje destynacje wpisane w klastrze. Jedna
destynacja to brak wyboru, polityka i tak jest ustawiona. Dwie destynacje w konfiguracji YARP
dostają żądania na zmianę. Test `Two_destinations_alternate` stawia dwa nasłuchy i sprawdza, że
sto żądań rozkłada się na oba, bez wymogu idealnego 50/50 co do jednego, z wymogiem, że żaden
nie dostał zera. To jest dowód polityki, nie test wydajności. NBomber nie wchodzi w ten numer.

Na maszynie docelowy adres klastra to jedna nazwa Service. Kubernetes rozkłada pody za tą nazwą.
YARP wtedy widzi jedną destynację, a rozkład podów jest po stronie Service. Polityka okrężna
zostaje, bo AppHost i ewentualna druga destynacja spoza Service mają z niej korzystać bez
kolejnej zmiany bramy. HPA i drugi pod opisuje
[docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). Ten numer nie tworzy manifestu. Losowy
wybór jako jedyna polityka przegrywa, bo trudniej go testować. Pierwsza destynacja na stałe
przegrywa, bo druga replika wpisana w konfiguracji nie dostałaby ruchu.

Koszt: przy jednej destynacji polityka nic nie zmienia. Jest po to, żeby układ z wieloma
adresami nie był osobnym trybem. W przykładzie konfiguracji klaster `news` ma jedną destynację
`news-1`. Test fabryki dokłada drugą i nie zmienia kodu trasy. Sto żądań ma trafić do obu
liczników. Idealny podział co do jednego nie jest warunkiem. Zero na jednym nasłuchu jest
padnięciem polityki.

### Cloudflare kończy się na YARP

Tunel i DNS opisuje [docs/cicd/09-cloudflare.md](../cicd/09-cloudflare.md). W tym numerze
granica jest jedna: origin tunelu to brama. Nie ma publicznego rekordu do poda News ani do
Identity. Certyfikat na brzegu Cloudflare kończy się po stronie tunelu, a ruch do bramy jest
ruchem origin. Usługa nie sprawdza nagłówków „czy to Cloudflare”. Ufa sieci wewnętrznej tylko w
tym sensie, że i tak sprawdza JWT. Publiczny rekord do poda obejrzałby JWKS na wejściu i jeden
punkt, na którym widać wersje.

Wystawienie usługi obok bramy przegrywa, bo omija JWKS na wejściu i omija jeden punkt, na którym
widać wersje. Koszt: cała diagnostyka zewnętrzna idzie przez jedną trasę. Log bramy ma ścieżkę,
status i nazwę klastra, bez ciała notatki i bez treści zapytania Contact. Stopka `web-vX.Y.Z` i
ekran telefonu są poza tym numerem. Tu jest JSON sześciu nazw, z którego ta stopka może czytać.
Brama nie rysuje HTML. Nie trzyma treści artykułu. Nie czyta Kafki.

## Klasy i ścieżki

Brama jest osobnym projektem web, nie biblioteką współdzieloną w `Core`. Wersjonowanie nagłówka
leży w `ServiceDefaults`, bo pięć usług czyta je tak samo. `GET /version` w usłudze jest mały i
powstaje razem z `Api`. Ten numer definiuje kontrakt i testuje go na nasłuchach, które zwracają
stałą wersję.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/gateway/JJDevHub.Gateway/JJDevHub.Gateway.csproj` | `Yarp.ReverseProxy`, uwierzytelnianie JWT |
| `src/gateway/JJDevHub.Gateway/Program.cs` | skład tras, JWKS, `/versions` |
| `src/gateway/JJDevHub.Gateway/appsettings.json` | klastry, trasy, `RoundRobin`, bez sekretów |
| `src/gateway/JJDevHub.Gateway/Versions/VersionEndpoint.cs` | `GET /versions` |
| `src/gateway/JJDevHub.Gateway/Versions/ServiceVersionClient.cs` | równoległe `GET /version` |
| `src/gateway/JJDevHub.Gateway/Versions/RunningVersions.cs` | rekord odpowiedzi |
| `src/gateway/JJDevHub.Gateway/Auth/GatewayJwtExtensions.cs` | JWKS, sam klucz publiczny |
| `src/shared/JJDevHub.ServiceDefaults/Http/ApiVersioningExtensions.cs` | nagłówek `api-version`, domyślnie `1.0` |
| `src/services/Identity/Identity.Api/Version/VersionEndpoint.cs` | `GET /version` |
| `src/services/News/News.Api/Version/VersionEndpoint.cs` | j.w. |
| `src/services/Learning/Learning.Api/Version/VersionEndpoint.cs` | j.w. |
| `src/services/Cv/Cv.Api/Version/VersionEndpoint.cs` | j.w. |
| `src/services/Contact/Contact.Api/Version/VersionEndpoint.cs` | j.w. |
| `tests/JJDevHub.Gateway.Tests/GatewayRouteTests.cs` | trasy i nagłówek |
| `tests/JJDevHub.Gateway.Tests/GatewayJwtTests.cs` | zły podpis, brak tokenu |
| `tests/JJDevHub.Gateway.Tests/VersionEndpointTests.cs` | sześć pól |

`Core` usług nie referencjonuje YARP. Reguła artykułu nie zna klastra. Testy bramy nie podnoszą
Postgresa, Kafki ani Redisa. Używają `WebApplicationFactory` i nasłuchów `TestServer` albo
`Kestrel` na porcie testu.

## Plan

### 1. Projekt bramy

```bash
dotnet new web -n JJDevHub.Gateway -o src/gateway/JJDevHub.Gateway -f net11.0
dotnet new xunit -n JJDevHub.Gateway.Tests -o tests/JJDevHub.Gateway.Tests -f net11.0
dotnet sln add src/gateway/JJDevHub.Gateway tests/JJDevHub.Gateway.Tests
dotnet add src/gateway/JJDevHub.Gateway package Yarp.ReverseProxy
dotnet add src/gateway/JJDevHub.Gateway package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add src/shared/JJDevHub.ServiceDefaults package Asp.Versioning.Http
dotnet add tests/JJDevHub.Gateway.Tests reference src/gateway/JJDevHub.Gateway
```

`Asp.Versioning.Http` jest na MIT. Testy bramy nie podnoszą Postgresa, Kafki ani Redisa. Używają
`WebApplicationFactory` i nasłuchów `TestServer` albo `Kestrel` na porcie testu. Cecha
`Integration` nie jest potrzebna, dopóki nie ma kontenera. Test i tak jest w xUnit i ma jeden
powód do padnięcia na fakt.

### 2. Konfiguracja klastrów

W `appsettings.json` pięć klastrów. Każdy ma jedną destynację z adresem pustym w repozytorium i
uzupełnianym przez Aspire (`WithReference`) albo przez konfigurację środowiska. Polityka:

```json
{
  "ReverseProxy": {
    "Clusters": {
      "news": {
        "LoadBalancingPolicy": "RoundRobin",
        "Destinations": {
          "news-1": { "Address": "http://news" }
        }
      }
    }
  }
}
```

Ten sam blok dla `identity`, `learning`, `cv`, `contact`. Adres `http://news` w przykładzie jest
nazwą w sieci AppHost, nie adresem publicznym. Plik w gicie nie zawiera hasła, connection
stringa ani klucza.

Trasy z tabeli wyżej. `/versions` jest `MapGet` w `Program.cs` i nie występuje w
`ReverseProxy.Routes`.

### 3. JWT

`AddGatewayJwt` ustawia `Authority` na wewnętrzny adres Identity, pobieranie kluczy z JWKS i
wyłącza mapowanie ról na osobne schematy, których brama nie używa. `OnTokenValidated` nie woła
bazy. Zdarzenie `OnAuthenticationFailed` zwraca `401` z `ProblemDetails` i kodem
`auth.token.invalid`, przez writer z numeru `11`, w języku `Accept-Language`.

Trasa z metadanymi `AuthorizationPolicy` równymi `authenticated` wymaga tokenu. Trasa publiczna
polityki nie ma. Obecny, ale zły token, pada na bramie także na trasie publicznej: podpis jest
albo ważny, albo żądanie nie idzie dalej. Brak tokenu na trasie publicznej idzie dalej.

### 4. Nagłówek wersji

`AddApiVersioning` w `ServiceDefaults` ustawia `ApiVersionReader` na nagłówek `api-version` i
`AssumeDefaultVersionWhenUnspecified` na `1.0`. Brama w transformacji trasy nie ma
`RequestHeader` usuwającego ten nagłówek. Test `Version_header_reaches_service` wysyła
`api-version: 1.0` i czyta nagłówek na nasłuchu testowym.

### 5. Wersje działających obrazów

`ServiceVersionClient.GetRunningVersionsAsync` woła pięć adresów z klastrów, `GET /version`,
`Task.WhenAll`, timeout 500 ms na wywołanie. Wyjątek albo timeout jednego wołania daje `null` w
tym polu i nie przerywa reszty. `RunningVersions` jest `sealed record` z sześcioma polami
`string?` dla usług i `string` dla bramy. Wersja bramy nie jest `null`: proces, który odpowiada,
zna własny zestaw.

Usługa wystawia:

```csharp
namespace JJDevHub.News.Api.Version
{
    public static class VersionEndpoint
    {
        public static IEndpointRouteBuilder MapServiceVersion(this IEndpointRouteBuilder app, string name)
        {
            app.MapGet("/version", () => Results.Ok(new { name, version = ServiceVersion.Current }));
            return app;
        }
    }
}
```

`ServiceVersion.Current` czyta `AssemblyInformationalVersion`. Brama woła ścieżkę wewnętrzną
`/version`, nie `/api/news/version`, na adresie klastra. Publicznie klient woła tylko
`/versions` na bramie.

### 6. Dwie destynacje

Test dokłada drugi nasłuch do klastra `news` w konfiguracji fabryki i wysyła serię `GET`.
Liczniki obu nasłuchów są większe od zera. To jest dowód polityki, nie test wydajności. NBomber
nie wchodzi w ten numer.

### Co jest do czego

- `JJDevHub.Gateway` woła przeglądarka, telefon i tunel. Jedyny publiczny proces HTTP API. Bez
  niego pięć usług albo wystawia własne hosty, albo ruch wchodzi do poda z pominięciem JWKS.
  Awaria bramy chowa usługi. Dlatego obraz ma własny tag `gateway-vX.Y.Z` i da się go cofnąć bez
  cofania News.
- Trasa YARP woła konfiguracja `ReverseProxy`. Wiąże ścieżkę z klastrem. Nie zawiera reguł
  notatki ani CV. Bez wiersza `/api/news/{**catch-all}` artykuł żyje w sieci wewnętrznej i nie
  ma go pod jednym adresem. `/versions` nie jest trasą proxy. Jest `MapGet`.
- `RoundRobin` woła każdy klaster, także przy jednej destynacji. Rozkład, gdy destynacji jest
  więcej niż jedna. Bez polityki druga destynacja wpisana w konfiguracji nie dostaje ruchu, a
  test stu żądań nie ma czego sprawdzić. Losowy wybór jako jedyna polityka nie wchodzi, bo
  trudno go obalić licznikiem.
- `GatewayJwtExtensions` woła `Program.cs` bramy. Sprawdza podpis, wystawcę, odbiorcę i czas.
  Klucz publiczny z JWKS. Bez tego zły podpis dochodzi do News. `OnTokenValidated` nie woła
  bazy. `OnAuthenticationFailed` oddaje `401` i `auth.token.invalid`. Klucza prywatnego w
  projekcie bramy nie ma.
- `ApiVersioningExtensions` woła pięć usług przez `ServiceDefaults`. Jeden sposób czytania
  `api-version`, domyślnie `1.0`. Bez niego każda usługa zgaduje wersję inaczej, a brama mogłaby
  zdjąć nagłówek. Brama transformacją go nie zdejmuje. Nieznana wersja zostaje `400` i
  `api.version.unsupported` w usłudze.
- `VersionEndpoint` na bramie woła klient stopki. Składa sześć numerów. Bez niego nie da się
  powiedzieć, który obraz narysował treść. Nie wymaga tokenu i nie niesie treści CV ani listy
  kont.
- `ServiceVersionClient` woła ten endpoint. Pyta żywe procesy, nie plik wdrożenia. Bez
  `Task.WhenAll` i timeoutu 500 ms jedna leżąca usługa zabiera całą stopkę. Wyjątek jednego
  wołania daje `null` w tym polu i nie przerywa reszty. Status odpowiedzi bramy zostaje `200`.
- `RunningVersions` woła serializację odpowiedzi. `sealed record` z pięcioma polami `string?` i
  polem bramy typu `string`. Bez osobnego typu łatwo pominąć `gateway` albo wstawić wersję z
  pamięci wdrożenia zamiast z procesu. Wersja bramy nie jest `null`.
- `MapServiceVersion` woła `Api` każdej usługi. Każda mówi własną wersję tym samym kształtem `{
  name, version }`. `ServiceVersion.Current` czyta `AssemblyInformationalVersion`. Bez tego
  endpointu brama nie ma kogo pytać pod `/version` na adresie klastra. Publiczna ścieżka to
  `/versions`, nie `/api/news/version`.
- `appsettings.json` woła YARP przy starcie. Trasy bez sekretów. Adresy wewnętrzne. Bez
  `LoadBalancingPolicy` równego `RoundRobin` układ z wieloma adresami byłby osobnym trybem. Plik
  w gicie nie zawiera hasła, connection stringa ani klucza. Aspire uzupełnia adres przez
  `WithReference`.
- Nasłuch JWKS w teście woła fabryka. Klucz RSA powstaje w teście, a brama dostaje tylko URL
  dokumentu. Bez tego test `401` albo wkłada klucz prywatny do konfiguracji bramy, albo nie ma
  jak podpisać tokenu złym kluczem. Prywatny klucz do projektu bramy nie wchodzi.
- `AuthorizationPolicy` równe `authenticated` woła trasę intranetu. Bez metadanych brak tokenu
  idzie dalej, co jest poprawne dla trasy publicznej i złe dla intranetu. Obecny zły token pada
  na bramie w obu rodzajach tras.

## Testy

Projekt `tests/JJDevHub.Gateway.Tests`. xUnit, `[Fact]`. Każdy fakt ma jeden powód do padnięcia.
Fabryka podnosi bramę i pięć lekkich aplikacji testowych. JWKS serwuje osobny nasłuch z kluczem
RSA utworzonym w teście. Klucz prywatny nie wchodzi do konfiguracji bramy. Brama dostaje tylko
URL dokumentu JWKS. Postgres, Kafka i Redis nie wstają. Cecha `Integration` nie jest potrzebna.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `News_route_hits_news` | nasłuch News zapisuje ścieżkę | `GET /api/news/articles` przez bramę | nasłuch News dostał tę ścieżkę, pozostałe cztery nie |
| `Identity_route_hits_identity` | j.w. dla Identity | `GET /api/identity/accounts` | trafienie tylko w Identity |
| `Learning_route_hits_learning` | j.w. | `GET /api/learning/courses` | trafienie tylko w Learning |
| `Cv_route_hits_cv` | j.w. | `GET /api/cv/profile` | trafienie tylko w Cv |
| `Contact_route_hits_contact` | j.w. | `GET /api/contact/recruiter` | trafienie tylko w Contact |
| `Version_header_reaches_service` | nasłuch czyta nagłówek | `GET` z `api-version: 1.0` | nagłówek na nasłuchu równy `1.0` |
| `Missing_version_header_defaults_on_service` | usługa z domyślną `1.0` | `GET` bez nagłówka | usługa widzi wersję `1.0` |
| `Invalid_signature_returns_401` | token podpisany innym kluczem | `GET` trasy publicznej z tokenem | `401`, nasłuch usługi niewołany |
| `Public_route_without_token_is_forwarded` | trasa bez polityki | `GET` bez `Authorization` | nasłuch wołany |
| `Intranet_route_without_token_returns_401` | trasa `authenticated` | `GET` bez tokenu | `401` |
| `Versions_returns_six_fields` | pięć nasłuchów zwraca stałe wersje | `GET /versions` | pola `identity`, `news`, `learning`, `cv`, `contact`, `gateway` |
| `Unreachable_service_is_null` | nasłuch News zatrzymany | `GET /versions` | `news` równe `null`, `gateway` niepuste, status 200 |
| `Two_destinations_alternate` | dwa nasłuchy w klastrze `news` | 100 żądań | oba liczniki większe od zera |

```bash
dotnet test tests/JJDevHub.Gateway.Tests
```

Pięć tras to pięć faktów, bo jeden zielony News nie dowodzi, że Contact nie wpada do Learning.
Nagłówek wersji i brak nagłówka są osobno, bo domyślne `1.0` nie wynika z tego, że `1.0`
przeszło, gdy klient je wysłał. Zły podpis i brak tokenu na intranetcie są osobno od braku
tokenu na trasie publicznej. Stopka z `null` jest osobno od stopki, w której pięć usług żyje.
Sto żądań na dwie destynacje nie jest testem wydajności i nie woła NBombera.

## Zasady

- Z zewnątrz HTTP API wchodzi tylko przez `JJDevHub.Gateway`. Złamanie wystawia pod News albo
  Identity obok bramy i omija JWKS oraz jeden punkt wersji.
- Brama nie ma klucza prywatnego JWT i nie wystawia tokenów. Złamanie dokłada drugi egzemplarz
  klucza, a wyciek konfiguracji bramy zaczyna podpisywać tokeny.
- Zły podpis nie dochodzi do usługi. Złamanie puszcza token o złym czasie, złym wystawcy albo
  złym kluczu do handlera artykułu.
- Rola nie jest zamieniana na `403` na bramie. Widoczność treści zostaje w usłudze. Złamanie
  potwierdza istnienie szkicu, który numer `11` każe oddać jako `404`.
- Nagłówek `api-version` jest przekazywany. Brak nagłówka oznacza `1.0` w usłudze. Złamanie
  zdejmuje nagłówek albo wstawia wersję do ścieżki i rozjeżdża cache klienta z identyfikatorem.
- `GET /versions` zwraca sześć nazw: pięć usług i bramę. Złamanie gubi `gateway` albo bierze
  numer z pliku wdrożenia zamiast z działającego procesu.
- Pole usługi, która nie odpowiedziała, jest `null`, a status odpowiedzi bramy zostaje `200`.
  Złamanie zamienia jedną leżącą usługę w błąd całej stopki.
- `LoadBalancingPolicy` klastra to `RoundRobin`. Złamanie zostawia drugą destynację bez ruchu
  albo wybiera ją losowo w sposób, którego test stu żądań nie obali.
- W `appsettings.json` bramy nie ma sekretu. Złamanie wkłada hasło, connection string albo klucz
  do pliku w gicie.
- Cloudflare nie jest originem dla poda usługi. Origin to brama. Złamanie daje publiczny rekord
  do poda i omija jedyne wejście.
- `Core` usług nie referencjonuje YARP. Złamanie wciąga regułę artykułu albo CV w klastry i w
  proxy.

## Poza zakresem

- Wystawienie klucza, ról `owner` i `student` oraz dokument JWKS po stronie Identity są w
  [17-identity.md](17-identity.md). Tu brama tylko czyta klucz publiczny i nie woła bazy w
  `OnTokenValidated`.
- Szyna i kompaktowanie są w [15-kafka.md](15-kafka.md). Brama nie czyta tematów i nie publikuje
  kopert.
- `ProblemDetails` i `Accept-Language` są w [11-walidacja.md](11-walidacja.md). Brama używa
  writera dla `auth.token.invalid`. Nie składa własnego zdania błędu.
- Tunel, DNS i to, gdzie kończy się certyfikat Cloudflare, są w
  [docs/cicd/09-cloudflare.md](../cicd/09-cloudflare.md). Tu granicą jest origin: brama, nie
  pod.
- HPA i drugi pod są w [docs/cicd/15-skalowanie.md](../cicd/15-skalowanie.md). Ten numer nie
  tworzy manifestu. Polityka `RoundRobin` jest już ustawiona.
- Stopka `web-vX.Y.Z` i ekran telefonu są w [docs/frontend/02-web.md](../frontend/02-web.md) i
  [docs/frontend/06-mobile.md](../frontend/06-mobile.md). Tu jest JSON, który ta stopka może
  pokazać.
- Treść endpointów pięciu usług jest w numerach od [17-identity.md](17-identity.md) do
  [21-kontakt.md](21-kontakt.md). Tu są prefiksy i test, że ścieżka dochodzi do właściwego
  klastra.

## Źródła

- [YARP
  overview](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/yarp-overview).
  Wiążące są trasy, klastry, destynacje i licencja MIT pakietu `Yarp.ReverseProxy`. W tym pliku
  jeden proces jest wejściem HTTP i równocześnie odpowiada na `GET /versions`. Nie bierzemy
  własnego `HttpClient` na każdą trasę ani Nginxa jako jedynej bramy aplikacji. Wersje, JWKS i
  `api-version` zostają w tym procesie. Wersja pakietu jest w `Directory.Packages.props`.
- [YARP load
  balancing](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/load-balancing).
  Wiążące jest `RoundRobin`. W tym pliku każdy klaster ma tę politykę, także przy jednej
  destynacji. Test stu żądań na dwa nasłuchy wymaga, żeby żaden licznik nie był zerem, bez
  wymogu idealnego 50/50. Nie bierzemy losowego wyboru jako jedynej polityki i nie bierzemy
  pierwszej destynacji na stałe. Na maszynie jeden adres Service i tak zostawia politykę, bo
  druga destynacja spoza Service ma z niej korzystać bez nowej bramy.
- [YARP
  transforms](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/transforms).
  Wiążące jest to, że prefiks da się zdjąć, jeśli usługa nasłuchuje krótszą ścieżkę. W tym pliku
  usługa nasłuchuje pełną ścieżkę `/api/{nazwa}/...`, więc brama nie woła `PathRemovePrefix` i nie
  zdejmuje `api-version`. Nie bierzemy drugiej konwencji ścieżki w kliencie i w endpoincie.
  `{**catch-all}` przekazuje resztę tak, jak przyszła.
- [JSON Web Key Set](https://www.rfc-editor.org/rfc/rfc7517). Wiążący jest dokument kluczy
  publicznych. W tym pliku Identity wystawia `/.well-known/jwks.json`, a brama i usługi biorą
  stamtąd klucz. Nie bierzemy klucza prywatnego w konfiguracji bramy i nie bierzemy wspólnego
  sekretu HMAC w pięciu usługach. Klucz publiczny wolno powielać. Token podpisany kluczem,
  którego jeszcze nie ma w dokumencie, dostaje `401`.
- [JwtBearer](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication).
  Wiążąca jest walidacja bez klucza prywatnego w bramie: podpis, wystawca, odbiorca i czas. W
  tym pliku `RequireHttpsMetadata` jest włączone dla `https`, a na deweloperskim HTTP AppHost
  wyłącza flagę tylko dla jednego wewnętrznego URL. Nie bierzemy mapowania ról na osobne
  schematy. `OnTokenValidated` nie woła bazy. `OnAuthenticationFailed` zwraca
  `auth.token.invalid`.
- [RFC 9110: 401 Unauthorized](https://www.rfc-editor.org/rfc/rfc9110#status.401). Wiążące jest
  `401`, gdy brak uwierzytelnienia albo dane uwierzytelniające nie zostały przyjęte. W tym pliku
  zły podpis i brak tokenu na trasie `authenticated` dają `401`, a żądanie nie dochodzi do
  usługi. Nie bierzemy `403` na bramie za złą rolę. Widoczność szkicu zostaje `404` w usłudze,
  zgodnie z numerem `11`. Brak tokenu na trasie publicznej idzie dalej.
- [Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457). Wiążące są `type`,
  `title` i `status`. W tym pliku `401` z bramy idzie przez writer z numeru `11`, kod
  `auth.token.invalid`, język z `Accept-Language`. Nie bierzemy własnego JSON-a błędu w bramie i
  nie bierzemy treści wyjątku w ciele. Nieznana `api-version` też jest `ProblemDetails`, ale
  składa ją usługa, kodem `api.version.unsupported` i statusem `400`.
- [API versioning in ASP.NET Core](https://github.com/dotnet/aspnet-api-versioning/wiki).
  Wiążące są `Asp.Versioning.Http`, czytnik nagłówka i licencja MIT. W tym pliku
  `ApiVersionReader` czyta `api-version`, a `AssumeDefaultVersionWhenUnspecified` daje `1.0`.
  Nie bierzemy wersji w ścieżce `/api/v1/news` ani w query. Brama nie trzyma drugiej listy
  wersji. Pakiet stoi w `ServiceDefaults`, żeby pięć usług nie składało czytnika osobno.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest jeden adres stabilny i rozkład na pody za tym adresem. W tym pliku na maszynie
  klaster YARP widzi jedną destynację, a kube-proxy rozkłada pody. Nie bierzemy manifestu w tym
  numerze. HPA opisuje osobny dokument. Polityka `RoundRobin` zostaje dla AppHost i dla drugiej
  destynacji wpisanej wprost.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest obraz bramy .NET przed usługami. Z tego
  repozytorium nie bierzemy MediatR ani `IntegrationEventLogEF`. Bierzemy pomysł jednego wejścia
  HTTP, u nas na YARP, z JWKS i z `GET /versions`. Nie bierzemy podziału ich usług ani ich
  schematu ciastek. Szyna nie przechodzi przez tę bramę. Klucz prywatny zostaje w Identity.

## Gotowe gdy

- `GET /api/news/...` dochodzi do klastra `news` i nie dochodzi do pozostałych czterech.
- Ta sama własność jest prawdziwa dla `identity`, `learning`, `cv` i `contact`.
- Nagłówek `api-version` widać na usłudze. Brak nagłówka daje w usłudze `1.0`.
- Token o złym podpisie daje `401`, a usługa nie jest wołana.
- `GET /versions` zwraca `identity`, `news`, `learning`, `cv`, `contact` i `gateway`.
- Niedostępna usługa daje `null` w swoim polu i nie zabiera wersji bramy.
- Dwie destynacje klastra dostają ruch przy polityce `RoundRobin`.
- W projekcie bramy nie ma klucza prywatnego.
- `dotnet test tests/JJDevHub.Gateway.Tests` kończy się kodem 0.
