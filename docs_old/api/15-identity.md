# Identity

Obecne API z [src/api](../../src/api) staje się usługą `Identity.API`. Konto i zaproszenie są agregatami ze strumienia, tym samym magazynem co artykuł w [04-strumien.md](04-strumien.md). Token podpisuje klucz RSA, a klucz publiczny jest wystawiony jako JWKS, więc pozostałe usługi walidują token bez wspólnego sekretu. Rejestracja dopisuje fakty konta i `UserRegisteredIntegrationEvent` w jednej transakcji, przez outbox z [12-outbox-inbox.md](12-outbox-inbox.md). Konsumentem powitania jest Notifications w [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md). Token niesie rolę: `owner` dla autora treści i `student` dla osoby, która przyszła z kodem zaproszenia. Polityki `Owner` i `Student` z ServiceDefaults czytają tę rolę w każdej usłudze. AppHost z [14-aspire.md](14-aspire.md) dostaje nowy projekt w miejsce `api`.

## Po co

W eShop `Identity.API` jest osobną usługą, a reszta tylko sprawdza tokeny. Dziś klucz JWT jest symetryczny (`JWT_KEY`). Żeby News i reszta usług mogły zwalidować token, musiałyby znać ten sam sekret, a wtedy mogłyby też tokeny wystawiać. Para kluczy RSA rozdziela role: Identity ma klucz prywatny i podpisuje, reszta pobiera publiczny z `/.well-known/jwks.json` i tylko sprawdza.

Źródłem prawdy konta jest strumień, nie wiersz, który da się nadpisać bez śladu. Rejestracja, zła próba logowania, blokada, nadanie roli, zmiana nazwy wyświetlanej i wykorzystanie zaproszenia są faktami na tym strumieniu. Nazwa jest częścią konta, jak w [Identity.API eShopa](https://github.com/dotnet/eShop/tree/main/src/Identity.API): osobnej usługi profilu nie ma. `UserRegisteredIntegrationEvent` służy Notifications. Istniejące konta z tabel `AspNetUsers` przenosi jednorazowy importer, zanim te tabele znikną.

Usługi treści z [19-learning.md](19-learning.md), [21-notatki.md](21-notatki.md) i [22-cv.md](22-cv.md) potrzebują trzech poziomów dostępu: gość czyta treść publiczną, student czyta też materiały dla studentów, a owner pisze wszystko i ma prywatną bazę wiedzy. Rola jest faktem o koncie, więc należy do Identity i jedzie w tokenie. Usługa treści nie pyta nikogo o uprawnienia, tylko czyta claim.

## Dlaczego ta technologia

### Skrót hasła ze strumienia, hasher z platformy

Źródłem prawdy jest strumień `account-{id}`: `AccountRegistered`, `LoginFailed`, `LoginSucceeded`, `RoleGranted`, `RoleRevoked`, `AccountRenamed`. Stan konta (skrót, role, blokada, nazwa wyświetlana) powstaje przez `Replay`, tak jak artykuł. Logowanie i `GET /api/auth/me` wołają `LoadAsync` i nie czekają na projekcję. Strumień konta jest krótki, więc odtworzenie przy każdym takim żądaniu jest tanie. Listy w intranecie (`GET /api/auth/users`, `GET /api/auth/invites`) czytają projekcję w `identity_read`.

Skrót liczy `PasswordHasher<Account>` z ASP.NET Core Identity: PBKDF2 z solą, ta sama funkcja, która dziś leży w `AspNetUsers`. Własny algorytm hasła to proszenie się o błąd. `UserManager` i tabele `AspNet*` odpadają, bo obok strumienia byłyby drugim zapisem tej samej zmiany.

Zdarzenie niesie skrót, nigdy hasło jawne. Stary skrót zostaje w strumieniu po każdej przyszłej zmianie hasła: magazyn jest tylko do dopisywania. Zrzut bazy `identity_write` jest więc zbiorem obecnych i historycznych skrótów. To ten sam sekret co dziś kolumna `PasswordHash`, plus skróty, których nadpisanie wiersza by usuwało.

Blokada jest regułą agregatu, nie kolumną licznika. Pięć `LoginFailed` z rzędu, bez `LoginSucceeded` pomiędzy, ustawia `LockedUntil` na pięć minut (domyślne progi Identity). Szósta próba w tym oknie nie sprawdza hasła. `LoginSucceeded` czyści serię. Oba fakty zapisują się też przy udanym wejściu i przy złym haśle, więc da się odtworzyć, kto i kiedy doszedł do blokady.

### Własne tokeny JWT zamiast serwera OIDC

Pełny serwer OpenID Connect daje przepływ authorization code z PKCE, odświeżanie tokenów, zgody, logowanie zewnętrzne i standardowy discovery. Opcje:

- **Keycloak** (Apache 2.0) — kompletny serwer tożsamości w Javie. Projekt świadomie trzyma go poza drzewem: to osobny, ciężki proces z własną bazą i panelem.
- **Duende IdentityServer** — płatna licencja dla firm powyżej progu przychodu, odpada według reguły licencji.
- **OpenIddict** (Apache 2.0) — darmowy serwer OIDC jako biblioteka ASP.NET Core, na EF Core. Najlepszy kandydat, gdy przyjdzie potrzeba logowania zewnętrznego albo aplikacji mobilnej z PKCE.

Dziś mamy jednego klienta (web) i logowanie hasłem. Własny endpoint wydający JWT plus JWKS to kilkadziesiąt linii, które student rozumie w całości. Ścieżka wyjścia jest prosta: OpenIddict wystawia ten sam `/.well-known/openid-configuration` i `jwks.json`, więc pozostałe usługi nie zauważą zmiany.

### RS256 i JWKS zamiast wspólnego sekretu HS256

Przy HS256 ten sam klucz podpisuje i weryfikuje. Każda usługa, która sprawdza tokeny, mogłaby je też wystawiać, a wyciek klucza z dowolnej usługi kompromituje wszystkie. RS256 używa pary kluczy: prywatny tylko w Identity (plik PEM podany jako sekret Compose), publiczny dla wszystkich pod `/.well-known/jwks.json`. `JwtBearer` w ASP.NET Core umie pobrać JWKS sam z `Authority` i odświeżać go, więc usługi nie mają w konfiguracji żadnego sekretu. Rotacja: nowy klucz podpisuje, stary (`PreviousSigningKeyPath`) zostaje w JWKS, aż wygasną wydane nim tokeny.

ES256 (krzywe eliptyczne) dałby krótsze podpisy. RS256 wygrywa kompatybilnością: obsługuje go każda biblioteka JWT i każdy gateway.

### Outbox w transakcji ze strumieniem

`SaveAsync` dopisuje zdarzenia konta, a outbox z [12-outbox-inbox.md](12-outbox-inbox.md) używa tego samego `IdentityWriteContext`. Jedna transakcja obejmuje strumień, rezerwację e-maila i wiersz outboxa: albo jest konto z nazwą wyświetlaną i `UserRegisteredIntegrationEvent`, albo nic. Zdarzenie nie buduje profilu drugi raz.

### Role na agregacie, w tokenie

Rola jest faktem `RoleGranted` albo `RoleRevoked` na strumieniu konta. Token dostaje listę ról z agregatu po `LoadAsync`, nie z tabeli łączącej. Claim `role` jest standardowy w JWT i `JwtBearer` mapuje go na `ClaimsPrincipal.IsInRole` przez `RoleClaimType`.

Alternatywy:

- **Uprawnienia jako osobne claimy** (`content:write`, `notes:read-students`) — drobniejsze, ale przy dwóch rolach to lista, którą trzeba utrzymywać bez żadnej decyzji, którą by umożliwiała.
- **Autoryzacja relacyjna** (OpenFGA, SpiceDB, model Zanzibar) — odpowiada na pytanie „czy ten student należy do tego wykładu”. To przyszła potrzeba zapisów na kursy, a nie dzisiejsza. Osobny serwer i osobny model danych.
- **Osobna usługa profilu** — każda usługa treści musiałaby pytać ją przy każdym żądaniu albo trzymać kopię ról z szyny. Nazwa wyświetlana i tak powstaje przy rejestracji, więc drugi proces nic nie rozstrzyga.

Koszt: rola w tokenie żyje tyle, co token. Odebranie roli `student` działa od następnego logowania, najpóźniej po `Jwt:ExpiryMinutes`. Przy materiałach dydaktycznych to akceptowalne.

### Kody zaproszeń dla studentów

Prowadzący ma grupę na zajęciach. Nadawanie roli trzydziestu osobom po kolei w intranecie to trzydzieści kliknięć i trzydzieści adresów do przepisania. Kod zaproszenia z datą ważności i limitem użyć prowadzący pokazuje na slajdzie, a student wpisuje go przy rejestracji albo w profilu.

Kod to 10 znaków z alfabetu Crockford Base32 (bez `I`, `L`, `O`, `U`), losowany przez `RandomNumberGenerator`. W zdarzeniu `InviteCreated` leży jego SHA-256, a nie sam kod. Wyciek bazy nie daje aktywnych kodów. Kod widać raz, w odpowiedzi na utworzenie. Limit użyć jest liczbą zdarzeń `InviteRedeemed` na strumieniu zaproszenia. Dwie równoczesne rejestracje dopisują do tej samej wersji: druga dostaje `Conflict` i nie zostawia konta. Tabela `InviteCodeHashes` tylko tłumaczy skrót na id strumienia, tak jak `ArticleSlugs` tłumaczy slug na artykuł.

Alternatywy:

- **Domena e-maila uczelni** (`@student.uczelnia.pl`) — każdy student uczelni, nie tylko z grupy. Wymaga potwierdzenia e-maila, którego dziś nie ma.
- **Logowanie przez system uczelni** (SAML, OIDC) — właściwa droga przy wdrożeniu instytucjonalnym, poza projektem.
- **Ręczne nadanie roli** — zostaje jako uzupełnienie dla pojedynczych osób.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/Identity/Identity.API/` | przeniesiony `src/api` (`git mv`), projekt `Identity.API.csproj` |
| `src/services/Identity/Identity.API/Auth/SigningKeyProvider.cs` | ładuje klucz RSA z PEM, `kid` |
| `src/services/Identity/Identity.API/Auth/TokenService.cs` | podpis `RS256` zamiast `HS256` |
| `src/services/Identity/Identity.API/Auth/JwksEndpoints.cs` | `/.well-known/openid-configuration`, `/.well-known/jwks.json` |
| `src/services/Identity/Identity.API/Domain/Account.cs` | agregat: e-mail, skrót, role, blokada, `Apply` |
| `src/services/Identity/Identity.API/Domain/StudentInvite.cs` | agregat: skrót kodu, etykieta, ważność, limit, wykorzystania |
| `src/services/Identity/Identity.API/Domain/AccountRegisteredDomainEvent.cs` i pozostałe fakty | nazwy `identity.account-registered.v1`, `identity.account-renamed.v1`, `identity.login-failed.v1`, `identity.login-succeeded.v1`, `identity.role-granted.v1`, `identity.role-revoked.v1`, `identity.invite-created.v1`, `identity.invite-redeemed.v1`, `identity.invite-revoked.v1` |
| `src/services/Identity/Identity.API/Auth/AuthEndpoints.cs` | rejestracja i logowanie na repozytorium |
| `src/services/Identity/Identity.API/Data/IdentityWriteContext.cs` | baza `identity_write`: `ApplyEventStore`, rezerwacje, outbox |
| `src/services/Identity/Identity.API/Data/IdentityReadContext.cs` | baza `identity_read`: listy kont i zaproszeń, checkpoint |
| `src/services/Identity/Identity.API/Data/AccountEmailRow.cs`, `InviteCodeHashRow.cs` | unikalny e-mail i skrót kodu obok strumienia |
| `src/services/Identity/Identity.API/Data/AccountImporter.cs` | jednorazowe przeniesienie `AspNetUsers` do faktów |
| `src/services/Identity/Identity.API/Projections/AccountListProjection.cs`, `InviteListProjection.cs` | widoki intranetu |
| `src/services/Identity/Identity.Contracts/UserRegisteredIntegrationEvent.cs` | kontrakt na `identity.integration` |
| `src/aspire/JJDevHub.ServiceDefaults/AuthenticationExtensions.cs` | `AddDefaultAuthentication()` dla usług-konsumentów tokenu |
| `src/aspire/JJDevHub.ServiceDefaults/Roles.cs` | stałe `owner`, `student` |
| `src/aspire/JJDevHub.ServiceDefaults/Policies.cs` | nazwy polityk `Owner`, `Student` |
| `src/services/Identity/Identity.API/Auth/OwnerSeeder.cs` | `RoleGranted` `owner` dla `Identity:OwnerEmail` przy starcie |
| `src/services/Identity/Identity.API/Invites/InviteCode.cs` | losowanie kodu i SHA-256 |
| `src/services/Identity/Identity.API/Invites/InviteEndpoints.cs` | tworzenie, lista, unieważnienie, wykorzystanie przez zalogowanego |
| `src/services/Identity/Identity.API/Admin/UserAdminEndpoints.cs` | lista studentów, nadanie i odebranie roli |
| `src/aspire/JJDevHub.AppHost/AppHost.cs` | zasób `identity-api` w miejsce `api` |
| `tests/Identity.API.Tests/` | przeniesiony `tests/JJDevHub.Api.Tests` |

## Plan

### 1. Przeniesienie

```bash
git mv src/api src/services/Identity/Identity.API
git mv src/services/Identity/Identity.API/JJDevHub.Api.csproj src/services/Identity/Identity.API/Identity.API.csproj
git mv tests/JJDevHub.Api.Tests tests/Identity.API.Tests
git mv tests/Identity.API.Tests/JJDevHub.Api.Tests.csproj tests/Identity.API.Tests/Identity.API.Tests.csproj
dotnet new classlib -n Identity.Contracts -o src/services/Identity/Identity.Contracts -f net11.0
dotnet sln add src/services/Identity/Identity.Contracts
dotnet add src/services/Identity/Identity.Contracts reference src/building-blocks/JJDevHub.EventBus
dotnet add src/services/Identity/Identity.API reference src/services/Identity/Identity.Contracts src/building-blocks/JJDevHub.Domain src/building-blocks/JJDevHub.EventStore src/building-blocks/JJDevHub.EventStore.Postgres src/building-blocks/JJDevHub.Projections src/building-blocks/JJDevHub.Cqrs src/building-blocks/JJDevHub.IntegrationEventLog src/building-blocks/JJDevHub.EventBus.Kafka
```

Wpisy w [JJDevHub.sln](../../JJDevHub.sln) idą za nowymi ścieżkami. `RootNamespace` zostaje `JJDevHub.Api`, żeby nie przepisywać namespace'ów w tym numerze. Zmiana na `JJDevHub.Identity.Api` to osobny, mechaniczny commit.

Ścieżki do poprawienia w tym samym numerze:

- [infra/docker/Dockerfile](../../infra/docker/Dockerfile): `src/api` → `src/services/Identity/Identity.API`,
- [.github/workflows/api.yml](../../.github/workflows/api.yml): filtr `paths` i ścieżki projektów; pełny podział CI jest w [18-ci-uslug.md](18-ci-uslug.md),
- [src/Clients/web](../../src/Clients/web): proxy Vite na `identity-api` do czasu gatewaya z `16`.

### 2. Baza

Do [14-aspire.md](14-aspire.md) istniejące API łączy się z bazą `jjdevhub`. Od tego numeru ta sama baza nazywa się `identity_write`. Zasób Aspire to `identity-write`:

```csharp
var identityDb = postgres.AddDatabase(ResourceNames.IdentityWrite, "identity_write");
```

`Program.cs` czyta `GetConnectionString("identity-write")` i `GetConnectionString("identity-read")` zamiast `DefaultConnection`. W `appsettings.json` klucz zmienia nazwę. Dochodzi druga baza:

```csharp
var identityRead = postgres.AddDatabase(ResourceNames.IdentityRead, "identity_read");
```

`ResourceNames.IdentityWrite = "identity-write"`. `ResourceNames.IdentityRead = "identity-read"`. Na VM, zanim migracje EF i przy braku sesji: `ALTER DATABASE jjdevhub RENAME TO identity_write`. Migracja `IdentityEventStore` dodaje w `identity_write` tabele strumienia, `AccountEmails`, `InviteCodeHashes` i outbox, obok jeszcze istniejących `AspNet*`. `IdentityReadInitial` tworzy listy i checkpoint w `identity_read`.

`AccountImporter` startuje po migracji, raz. Gdy istnieje `AspNetUsers`, a `AccountEmails` jest pusta, w jednej transakcji: dla każdego wiersza dopisuje strumień (`AccountRegistered` z obecnym `PasswordHash`, `DisplayName` z e-maila, `RoleGranted` dla każdej roli z `AspNetUserRoles`) i wiersz rezerwacji e-maila. Na końcu tej transakcji usuwa tabele `AspNetUserTokens`, `AspNetUserLogins`, `AspNetUserClaims`, `AspNetRoleClaims`, `AspNetUserRoles`, `AspNetRoles` i `AspNetUsers`. Porażka wycofuje wszystko, następny start próbuje od nowa. Drugi start nie widzi `AspNetUsers` i nic nie robi.

### 3. Klucz podpisu

`SigningKeyProvider` jest singletonem. Czyta `Jwt:SigningKeyPath` (PEM z kluczem prywatnym RSA 2048):

- plik jest → `RSA.ImportFromPem`, `kid` to pierwsze 16 znaków SHA-256 z klucza publicznego w Base64Url,
- pliku nie ma i środowisko to `Development` → klucz generowany w pamięci, log `Warning`; po restarcie stare tokeny tracą ważność,
- pliku nie ma poza `Development` → `InvalidOperationException` przy starcie.

Opcjonalne `Jwt:PreviousSigningKeyPath` dodaje do JWKS drugi klucz publiczny bez podpisywania nim. Rotacja: nowy klucz w `SigningKeyPath`, stary w `PreviousSigningKeyPath` na czas życia tokenu, potem usunięcie.

Na VM klucz przychodzi jako sekret Compose `/run/secrets/identity-signing.pem`, odszyfrowany z `infra/secrets/identity-signing.sops.pem` ([docs/CICD/12-sekrety.md](../CICD/12-sekrety.md), [18-ci-uslug.md](18-ci-uslug.md)). Jawna kopia nie leży na dysku VM ani w repozytorium. Generowanie i zaszyfrowanie: `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 | sops encrypt --input-type binary --output-type binary --filename-override infra/secrets/identity-signing.sops.pem /dev/stdin > infra/secrets/identity-signing.sops.pem`. `JWT_KEY` znika z [infra/docker/.env.example](../../infra/docker/.env.example), a dochodzi `JWT_SIGNING_KEY_PATH`. Po wdrożeniu stare tokeny HS256 przestają działać i użytkownicy logują się ponownie.

`TokenService` podpisuje `SigningCredentials(new RsaSecurityKey(rsa) { KeyId = kid }, SecurityAlgorithms.RsaSha256)`. Issuer i audience zostają z obecnych `JwtOptions`. Własna walidacja tokenu w Identity używa tego samego klucza publicznego.

### 4. JWKS

`JwksEndpoints.MapJwks(this WebApplication app)`:

- `GET /.well-known/openid-configuration` → `{ "issuer": "...", "jwks_uri": "<baza>/.well-known/jwks.json" }`. Baza adresu bierze się z `Jwt:PublicUrl`, a w dev z adresu żądania,
- `GET /.well-known/jwks.json` → `{ "keys": [ { "kty": "RSA", "use": "sig", "alg": "RS256", "kid": "...", "n": "...", "e": "..." } ] }`, po jednym wpisie na klucz z providera,
- oba anonimowe, `Cache-Control: public, max-age=300`.

To minimalny dokument discovery. `JwtBearer` w innych usługach czyta z niego `jwks_uri` i sam odświeża klucze.

### 5. Walidacja w innych usługach

`AddDefaultAuthentication(this IHostApplicationBuilder builder)` w ServiceDefaults, wzorem eShop:

- sekcja `Identity` z `Url` i `Audience`; brak `Url` → metoda nic nie rejestruje (usługa bez chronionych endpointów, np. worker),
- `AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer`: `Authority = Identity:Url`, `Audience`, `RequireHttpsMetadata` tylko poza `Development`, `MapInboundClaims = false`, `NameClaimType = "sub"`, `RoleClaimType = "role"`,
- `AddAuthorizationBuilder()` z politykami z kroku 10.

AppHost przekazuje adres jako `Identity__Url` z `identityApi.GetEndpoint("http")`. ServiceDefaults dostaje pakiet `Microsoft.AspNetCore.Authentication.JwtBearer` (jest już w repo).

### 6. Rejestracja ze strumienia

```csharp
namespace JJDevHub.Identity.Contracts
{
    [EventName("identity.integration.user-registered.v1")]
    public sealed record UserRegisteredIntegrationEvent(
        Guid EventId, DateTimeOffset OccurredOn, string IdentityGuid, string Email) : IIntegrationEvent
    {
        [JsonIgnore]
        public string PartitionKey => IdentityGuid;
    }
}
```

`IdentityWriteContext.OnModelCreating` woła `ApplyEventStore()` i `ApplyIntegrationEventLog()`. `Account` i `StudentInvite` idą przez `IRepository<T>` z [07-repozytorium.md](07-repozytorium.md). Strumienie: `account-{guid}`, `invite-{guid}`.

`Account.Register(email, password, PasswordHasher, time)` liczy skrót, ustawia `DisplayName.FromEmail` i dopisuje `AccountRegistered` ze skrótem i nazwą. `DisplayName` jest przycięte, od 2 do 50 znaków. Część e-maila przed `@` krótsza niż 2 znaki uzupełnia się do `user-` i pierwszych znaków id konta. `Rename(DisplayName)` dopisuje `AccountRenamed`. Handler rejestracji w transakcji `TransactionBehavior`:

- wstawia `AccountEmails` (`Email` unikalny, `AccountId`); naruszenie klucza → `Conflict`, strumień nie powstaje,
- `repository.SaveAsync`,
- `outbox.AddAsync(new UserRegisteredIntegrationEvent(...))` z `IdentityGuid` równym id konta i bez skrótu hasła.

Logowanie szuka id w `AccountEmails`, woła `GetAsync` i porównuje hasło hasherem. Zły skrót albo blokada dopisuje `LoginFailed` i zwraca ten sam `401` co złe hasło. Dobry skrót dopisuje `LoginSucceeded`, gdy była otwarta seria porażek, i wydaje token z ról agregatu.

Skład w `Program.cs`:

```csharp
builder.Services.AddIntegrationEventLog<IdentityWriteContext>(typeof(UserRegisteredIntegrationEvent).Assembly);
builder.Services.AddKafkaEventBus(builder.Configuration, options => options.PublishedTopics = ["identity.integration"]);
```

Projekcja `AccountListProjection` i `InviteListProjection` czyta `ReadAllAsync` do `identity_read`, jak [10-projekcja.md](10-projekcja.md). Endpointy listy nie otwierają strumienia.

### 7. AppHost

Zasób `api` znika. Dochodzi:

```csharp
var identityApi = builder.AddProject<Projects.Identity_API>(ResourceNames.IdentityApi)
    .WithReference(identityDb).WaitFor(identityDb)
    .WithReference(identityRead).WaitFor(identityRead)
    .WithReference(kafka).WaitFor(kafka)
    .WithEnvironment("Jwt__SigningKeyPath", signingKeyPath);
```

`signingKeyPath` to parametr Aspire. W dev jest pusty i działa klucz w pamięci. `ResourceNames` dostaje `IdentityApi = "identity-api"`. Drugi parametr, `owner-email`, trafia do `Identity__OwnerEmail`.

### 8. Role i owner

`Roles.Owner = "owner"` i `Roles.Student = "student"` leżą w ServiceDefaults, bo czytają je wszystkie usługi. Tabel ról nie ma.

`OwnerSeeder : IHostedService` w `StartAsync`, po importerze: gdy `Identity:OwnerEmail` jest ustawione i `AccountEmails` ma ten adres, a agregat nie ma roli `owner`, dopisuje `RoleGranted`.

Na VM konto autora już istnieje, więc importer przenosi je ze skrótem, a seeder dopisuje rolę przy pierwszym starcie, bez ręcznego SQL. Rejestracja na adres z `Identity:OwnerEmail` dopisuje `RoleGranted` w tej samej transakcji co `AccountRegistered`. `OwnerEmail` jest jeden. Drugiego ownera nadaje endpoint administracyjny.

`TokenService.CreateToken(Guid accountId, string email, IReadOnlyList<string> roles)` dopisuje po jednym claimie `role` na rolę. `sub` to id konta. `MeResponse` dostaje `Roles`, żeby klient web wiedział, czy pokazać wejście do intranetu.

### 9. Zaproszenia

`StudentInvite.Create` dopisuje `InviteCreated` ze skrótem, etykietą, `ExpiresOn` i `MaxUses`. `Redeem` dopisuje `InviteRedeemed` z id konta, gdy kod jest ważny, niewyczerpany i nieunieważniony. `Revoke` dopisuje `InviteRevoked`. Handler tworzenia wstawia `InviteCodeHashes` w tej samej transakcji co strumień.

| Metoda i ścieżka | Polityka | Wynik |
| --- | --- | --- |
| `POST /api/auth/invites` | `Owner` | body `{ label, expiresOn, maxUses }` → `201` z `code` (jedyny raz, kiedy kod jest widoczny) |
| `GET /api/auth/invites` | `Owner` | lista bez kodów: etykieta, ważność, `usedCount`/`maxUses`, stan |
| `DELETE /api/auth/invites/{id}` | `Owner` | `204`, ustawia `RevokedOn` |
| `POST /api/auth/invites/redeem` | zalogowany | body `{ code }` → `200` z nowym tokenem z rolą `student`, `400` przy złym kodzie |

`RegisterRequest` dostaje opcjonalne `InviteCode`. Rejestracja z kodem w jednej transakcji: strumień konta, `RoleGranted` `student`, `InviteRedeemed`, obie rezerwacje, wiersz outboxa. Kod nieznany, wygasły, unieważniony albo wyczerpany daje `400` z błędem pola `inviteCode` i nie zostawia konta. Odpowiedź nie mówi, który z czterech powodów zaszedł. `POST /api/auth/invites/redeem` dla już zalogowanego dopisuje `InviteRedeemed` i `RoleGranted`, potem wydaje nowy token.

`InviteCode.Hash(string code)` normalizuje kod (wielkie litery, bez myślników i spacji) przed SHA-256, więc `abcd-efgh-jk` i `ABCDEFGHJK` to ten sam kod.

### 10. Polityki i administracja

`AddDefaultAuthentication` rejestruje polityki:

```csharp
builder.Services.AddAuthorizationBuilder()
    .AddPolicy(Policies.Owner, policy => policy.RequireRole(Roles.Owner))
    .AddPolicy(Policies.Student, policy => policy.RequireRole(Roles.Student, Roles.Owner));
```

Owner spełnia politykę `Student`, bo widzi wszystko, co student. Usługa treści pisze `RequireAuthorization(Policies.Owner)` na endpointach zapisu, a widoczność `Students` sprawdza przez `IAuthorizationService` w zapytaniu.

`GET /api/auth/me` i `PUT /api/auth/me` wymagają zalogowanego użytkownika, nie polityki `Owner`. `GET` woła `LoadAsync` konta z `sub`: `IdentityGuid`, e-mail, `DisplayName`. Brak tokenu to `401`. `PUT` przyjmuje `{ "displayName": "…" }` i `If-Match` wersji konta, woła `Rename`. `Invalid` → `400`, zła wersja → `412`. Odpowiedź niesie nowy `ETag`.

`UserAdminEndpoints` (wszystkie z polityką `Owner`):

- `GET /api/auth/users?role=student` → `IdentityGuid`, e-mail, `DisplayName`, role, data utworzenia,
- `PUT /api/auth/users/{id}/roles/student` → `204`, dopisuje `RoleGranted`, jeśli roli jeszcze nie ma,
- `DELETE /api/auth/users/{id}/roles/student` → `204`, dopisuje `RoleRevoked`.

Lista czyta projekcję. Nadanie i odebranie roli ładują agregat ze strumienia.

Gateway nie potrzebuje nowej trasy, bo wszystko jest pod `/api/auth/`.

### Co jest do czego

- `Identity.API` — jedyna usługa konta: hasło, role, nazwa wyświetlana i token. Reszta zna tylko `IdentityGuid` z tokenu.
- `Account.DisplayName` — nazwa na tym samym strumieniu co skrót hasła. `GET /api/auth/me` czyta strumień, nie projekcję.
- `SigningKeyProvider` — klucz prywatny z pliku poza repo i jego `kid`. Rotacja bez przestoju dzięki drugiemu kluczowi publicznemu.
- `JwksEndpoints` — publiczna część klucza dla innych usług. Bez niej każda usługa musiałaby znać sekret.
- `AddDefaultAuthentication` — trzy linie konfiguracji, które każda usługa HTTP dostaje z ServiceDefaults.
- `UserRegisteredIntegrationEvent` — fakt „powstało konto” dla reszty systemu. Bez hasła i bez skrótu hasła.
- transakcja w `register` — strumień, rezerwacja e-maila i outbox powstają razem albo wcale.
- `Account` i `StudentInvite` — każdy fakt bezpieczeństwa da się odtworzyć. Logowanie czyta strumień, lista w intranecie czyta projekcję.
- `AccountEmails` i `InviteCodeHashes` — unikalność, której jeden strumień nie widzi u sąsiada.
- `AccountImporter` — konta z VM wchodzą do strumienia ze starym skrótem, a tabele `AspNet*` znikają w tej samej transakcji.
- `Identity.Contracts` — kontrakt dla Notifications. Nie niesie skrótu hasła.
- claim `role` i polityki `Owner`/`Student` — jedno źródło uprawnień dla wszystkich usług. Usługa treści nie zna haseł, tylko czyta token.
- `OwnerSeeder` — autor treści dostaje `RoleGranted` bez ręcznej zmiany w bazie produkcyjnej.
- `StudentInvite` — grupa studentów dostaje dostęp jednym kodem z zajęć. W strumieniu leży skrót, a limit to liczba `InviteRedeemed`.
- `UserAdminEndpoints` — lista i korekta ról z intranetu ([docs/frontend/intranet/01-dostep-i-trasy.md](../frontend/intranet/01-dostep-i-trasy.md)).

## Testy

Projekt `tests/Identity.API.Tests` (przeniesiony). `ApiFactory` z kontenerem Postgresa podmienia `IEventBus` na `RecordingEventBus`, a `Jwt:SigningKeyPath` na plik PEM wygenerowany w `InitializeAsync`. Kafka nie jest potrzebna. Dispatcher outboxa jest wyłączony opcją, a test woła `OutboxProcessor` wprost.

Klasa `AuthAndHealthTests` zostaje. Dochodzą:

Klasa `RegistrationOutboxTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Register_creates_account_stream` | host z fabryki | `POST /api/auth/register` | `AccountEmails` ma ten e-mail, strumień `account-{id}` ma `AccountRegistered` ze skrótem i `DisplayName`, bez hasła jawnego |
| `Me_returns_name_from_stream` | rejestracja | `GET /api/auth/me` z tokenem, zanim projekcja dogoni | `200`, e-mail i nazwa |
| `Rename_appends_fact` | konto, `If-Match` bieżącej wersji | `PUT /api/auth/me` z nową nazwą | `200`, strumień ma `AccountRenamed` |
| `Rename_too_short_returns_400` | konto | `PUT` z `"x"` | `400` |
| `Register_writes_outbox_row` | ten sam rejestr | odczyt `OutboxMessages` | jeden wiersz `identity.integration.user-registered.v1` |
| `Outbox_payload_has_no_password` | ten sam rejestr | odczyt `Payload` | brak hasła i pola `passwordHash` |
| `Duplicate_email_writes_no_outbox_row` | konto już istnieje | drugi `register` tym e-mailem | nadal jeden wiersz outboxa |
| `Processor_publishes_registration` | rejestracja | `OutboxProcessor.RunOnceAsync` | `RecordingEventBus` ma kopertę z kluczem równym id konta |
| `Failed_login_appends_event` | konto | `login` ze złym hasłem | strumień ma `LoginFailed`, odpowiedź `401` |
| `Fifth_failure_locks_account` | cztery `LoginFailed` | piąte złe hasło, potem dobre | drugie też `401`, w zdarzeniu jest `LockedUntil` |

Klasa `JwksTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Discovery_points_to_jwks` | host | `GET /.well-known/openid-configuration` | `jwks_uri` kończy się na `/.well-known/jwks.json` |
| `Jwks_exposes_signing_key` | host | `GET /.well-known/jwks.json` | jeden klucz `RSA` z `kid` |
| `Token_validates_with_jwks_key` | token z `login` | walidacja `JsonWebTokenHandler` kluczem z JWKS | `IsValid` |
| `Token_uses_rs256` | token z `login` | odczyt nagłówka | `alg` równe `RS256` |

Klasa `RolesAndInvitesTests`. Fabryka ustawia `Identity:OwnerEmail` na `owner@test.local`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Owner_email_gets_owner_role` | host | `register` z `owner@test.local` | token ma `role` `owner` |
| `Seeder_grants_owner_to_existing_account` | konto `owner@test.local` bez roli | `OwnerSeeder.StartAsync` | strumień ma `RoleGranted` `owner` |
| `Plain_registration_has_no_role` | host | `register` bez kodu | token bez claimu `role` |
| `Invite_registration_gets_student_role` | zaproszenie z limitem 2 | `register` z kodem | token ma `role` `student`, strumień zaproszenia ma jedno `InviteRedeemed` |
| `Invite_code_is_case_and_dash_insensitive` | kod `ABCDEFGHJK` | `register` z `abcd-efgh-jk` | `201` |
| `Expired_invite_returns_400_without_account` | zaproszenie z `ExpiresOn` w przeszłości (`FakeTimeProvider`) | `register` z kodem | `400` z polem `inviteCode`, brak wiersza w `AccountEmails` |
| `Exhausted_invite_returns_400` | zaproszenie z limitem 1, już użyte | `register` z kodem | `400` |
| `Invite_is_stored_as_hash` | `POST /api/auth/invites` | odczyt zdarzenia `InviteCreated` | skrót różny od kodu z odpowiedzi, kodu nie ma w strumieniu |
| `Importer_moves_aspnet_user_and_drops_table` | wiersz `AspNetUsers` ze skrótem i rolą `student` | `AccountImporter` | strumień z tym samym skrótem i `RoleGranted`, tabeli `AspNetUsers` nie ma |
| `Student_cannot_create_invite` | token z rolą `student` | `POST /api/auth/invites` | `403` |
| `Owner_grants_student_role` | konto `b` bez roli | `PUT /api/auth/users/{b}/roles/student`, potem `login` jako `b` | token `b` ma `role` `student` |

Klasa `PolicyTests` w `tests/JJDevHub.AppHost.Tests` sprawdza ServiceDefaults bez Identity: host z `AddDefaultAuthentication`, testowy klucz, endpointy z obiema politykami.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Owner_passes_student_policy` | token z `owner` | `GET` na endpoint `Student` | `200` |
| `Student_fails_owner_policy` | token z `student` | `GET` na endpoint `Owner` | `403` |

`dotnet test tests/Identity.API.Tests` i `dotnet test tests/JJDevHub.AppHost.Tests`.

## Zasady

- Klucz prywatny nie trafia do repozytorium, obrazu ani zmiennych workflowu. Leży w pliku na hoście.
- Tylko Identity podpisuje tokeny. Inne usługi mają wyłącznie klucz publiczny z JWKS.
- Rejestracja dopisuje strumień, rezerwację e-maila i outbox w jednej transakcji.
- Zdarzenie domenowe konta może nieść skrót hasła. Zdarzenie integracyjne nie niesie hasła ani jego skrótu.
- `IdentityGuid` to id agregatu `Account`.
- Rola jedzie w tokenie jako claim `role`. Usługi sprawdzają ją politykami z ServiceDefaults, a nazw ról nie przepisują w kodzie.
- Kod zaproszenia jest widoczny raz. W strumieniu leży jego SHA-256.
- Logowanie i blokada czytają strumień. Lista kont i zaproszeń czyta projekcję.
- Nieudane użycie kodu nie mówi, czy kod wygasł, został wyczerpany, unieważniony, czy nie istnieje.

## Poza zakresem

- Zapisy na konkretny wykład (student widzi tylko swoje kursy). Wymaga autoryzacji relacyjnej, a dziś rola `student` daje dostęp do wszystkich materiałów `Students`.
- Potwierdzenie e-maila i reset hasła.
- Pełny OpenID Connect, Duende IdentityServer, Keycloak. Minimalny discovery wystarcza walidacji JWT.
- Refresh tokeny i wylogowanie po stronie serwera.
- Usuwanie konta i `UserDeletedIntegrationEvent`. Ten sam wzór, osobny numer, gdy dojdzie ekran.
- Profil i widok użytkownika — [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).

## Źródła

- [Securing .NET microservices](https://learn.microsoft.com/en-us/dotnet/architecture/microservices/secure-net-microservices-web-applications/) — usługa tożsamości i tokeny walidowane przez pozostałe usługi.
- [dotnet/eShop — Identity.API](https://github.com/dotnet/eShop/tree/main/src/Identity.API) i [AuthenticationExtensions](https://github.com/dotnet/eShop/blob/main/src/eShop.ServiceDefaults/AuthenticationExtensions.cs) — wzorzec `AddDefaultAuthentication`.
- [RFC 7517: JSON Web Key](https://www.rfc-editor.org/rfc/rfc7517) — format JWKS.
- [OpenID Connect Discovery](https://openid.net/specs/openid-connect-discovery-1_0.html) — `issuer` i `jwks_uri`.
- [Configure JWT bearer authentication](https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication) — `Authority`, `Audience`, metadane.
- [PasswordHasher<TUser>](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.identity.passwordhasher-1) — PBKDF2 ze solą, bez `UserManager` i bez tabel Identity.
- [Event Sourcing pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing) — strumień konta jako źródło stanu.
- [Transactional outbox pattern](https://learn.microsoft.com/en-us/azure/architecture/databases/guide/transactional-outbox-cosmos) — konto i zdarzenie w jednej transakcji.
- [Role-based authorization](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/roles) — `RequireRole`, `RoleClaimType`.
- [Policy-based authorization](https://learn.microsoft.com/en-us/aspnet/core/security/authorization/policies) — `AddAuthorizationBuilder` i polityki nazwane.
- [Crockford Base32](https://www.crockford.com/base32.html) — alfabet bez znaków mylonych przy przepisywaniu ze slajdu.

## Gotowe gdy

- `src/api` nie istnieje, a `Identity.API` buduje się i startuje z AppHost jako `identity-api`.
- Token ma `alg` `RS256` i `kid`, a klucz z `/.well-known/jwks.json` go waliduje.
- Rejestracja zostawia strumień `account-{id}`, wiersz `AccountEmails` i `OutboxMessages` z tego samego commitu. Nieudana rejestracja nie zostawia żadnego. Importer przenosi istniejące `AspNetUsers` i usuwa te tabele.
- `JWT_KEY` zniknął z `.env.example`, a klucz prywatny jest tylko w pliku na hoście.
- Konto z `Identity:OwnerEmail` ma w tokenie `role` `owner`, a rejestracja z ważnym kodem daje `student`.
- Wygasły albo wyczerpany kod kończy się `400` bez konta w bazie.
- `dotnet test tests/Identity.API.Tests` i `dotnet test tests/JJDevHub.AppHost.Tests` kończą się kodem 0.
