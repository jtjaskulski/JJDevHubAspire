# 17. Konta i role

Ten numer stawia usługę Identity. Konto, zaproszenie studenta, klucz RSA i token JWT powstają
tutaj. Poprzedni numer to [brama i `GET /versions`](16-gateway.md). Następny to
[notatki](18-news.md). Brama z numeru 16 przekazuje do tej usługi prefiks `/api/identity` oraz
`/.well-known/jwks.json`. Pozostałe usługi sprawdzają podpis tokenu i nie wystawiają własnego
klucza.

Bez tego numeru właściciel i student nie mają wspólnego wejścia do News, Learning, Cv i Contact.
Każda z tych usług musiałaby trzymać własne hasło albo czytać cudzą tabelę osób. Pierwsza droga
rozjeżdża rolę: ta sama osoba mogłaby być właścicielem notatki i kimś innym w kursie. Druga
droga otwiera `identity_write` procesowi, który ma tylko sprawdzić podpis. Codzienny scenariusz
wtedy się urywa. Student wpisuje kod zaproszenia, dostaje token i otwiera lekcję. Właściciel tym
samym rodzajem tokenu publikuje notatkę. Rekruter nie dostaje konta. Gdy sesja logowania się
kończy, Contact ma skasować token urządzenia tej sesji. Tego łańcucha nie ma z czego zestawić,
dopóki token, rola i koniec sesji nie mają jednego wydawcy.

Osobno pęka klucz podpisu. Access token żyje 15 minut i niesie `sub`. Pięć procesów ma go uznać,
a złożyć podpis ma jeden. Sekret HMAC w każdym podzie oznaczałby, że sprawdzenie podpisu jest
zarazem umiejętnością podrobienia tokenu właściciela. PEM w obrazie oznaczałby, że tag
`identity-vX.Y.Z` wyjeżdża z materiałem podpisu, bo obraz jest publicznym artefaktem buildu. Ten
numer zostawia klucz prywatny w OpenBao i na zewnątrz wystawia tylko dokument JWKS.

Pęka też to, kto w ogóle może powstać. Publiczna rejestracja nie tworzy właściciela. Bez kodu
zaproszenia strumień konta studenta nie powstaje. Konto `owner` powstaje z bootstrapu i tylko
wtedy, gdy strumienia jeszcze nie ma. Kolejny start hosta nie zmienia hasła, które właściciel
już zmienił. Bez tej reguły ponowne wdrożenie nadpisałoby hasło jedynego właściciela, a otwarta
rejestracja założyłaby drugiego.

## Po co

Właściciel i student mają wejść do News, Learning, Cv i Contact tym samym tokenem. Hasło, rola i
klucz podpisu mają jedno miejsce. Pięć usług ma odrzucać zły token bez otwierania
`identity_write`. Sąsiad widzi JWT, sprawdza go kluczem publicznym i na tym kończy kontakt z tą
usługą przy zwykłym żądaniu. Nie czyta strumienia konta, nie dostaje skrótu hasła i nie nadaje
roli.

Rola `owner` albo `student` jest claimem tokenu, a polityki `Owner` i `Student` stoją w
`JJDevHub.ServiceDefaults`, więc każda usługa woła tę samą nazwę polityki. Identity jest jedynym
miejscem, które rolę nadaje. Zaproszenie nadaje `student`. Bootstrap nadaje `owner`. Gdyby każda
usługa trzymała własną kopię warunku „claim równa się owner”, zmiana napisu rozjechałaby się w
jednej kopii. Student przeszedłby przez endpoint właściciela albo właściciel straciłby listę
kont. Macierz uprawnień zostaje krótka, bo predykat ma jedną definicję.

Jedyny wspólny identyfikator człowieka to `IdentityGuid`. Adres e-mail nie jest kluczem obcym w
cudzej bazie. Identyfikator agregatu `Account` jest GUID-em i claimem `sub`. Na szynie i w
cudzej usłudze nazywa się `IdentityGuid`. Zmiana adresu albo wyświetlanej nazwy nie przepisuje
kluczy w News, Learning, Cv i Contact. E-mail zostaje w Identity. Osobny identyfikator na usługę
odpadł, bo człowiek jest jeden, a usługi i tak nie współdzielą bazy. JWT niesie `sub` do
wygaśnięcia access tokenu. Zmiana nazwy wyświetlanej jest widoczna w `GET /api/identity/me` od
razu ze strumienia, a w claimie `name` dopiero po następnym logowaniu.

Skrót hasła zostaje w strumieniu konta. Odczyt, log i zdarzenie integracyjne go nie dostają.
Student wchodzi kodem zaproszenia, a publiczna rejestracja nie tworzy właściciela. Te
postanowienia zamykają drogę, którą sekret wychodzi do kopii odczytu albo obcy proces staje się
źródłem roli. Dalsze sekcje rozpisują agregat, klucz i kod błędu, którymi te postanowienia są
utrzymane. Bez nich brama z numeru 16 ma prefiks, którego nikt nie obsługuje, a `GET /versions`
nie ma komu zapytać o tag `identity-vX.Y.Z`.

## Dlaczego ta technologia

### Własna usługa Identity

Identity jest szóstką projektów pod `src/services/Identity/`. Wydaje token, trzyma konto i
zaproszenie, publikuje JWKS. Produkt ma dwie role i jedno hasło na osobę, więc model człowieka
jest agregatem `Account` w tej usłudze. Osobny serwer tożsamości dodałby drugi model użytkownika
obok `Account`. Handler logowania miałby dwa byty o tej samej osobie, a sąsiad dostałby claim z
katalogu, którego strumienia ten numer nie prowadzi.

Keycloak odpadł, bo konta i role są tą usługą, a nie katalogiem zewnętrznym. Duende
IdentityServer odpadł, bo licencja produkcyjna nie jest wolna. Wspólna tabela użytkowników w
jednej bazie dla pięciu usług odpadła, bo sąsiad nie otwiera cudzej bazy. `Identity.Core` nie
referencjonuje MediatR, Entity Framework, Kafki ani ASP.NET. Mediator, który woła handlery, jest
w `JJDevHub.Cqrs`. `Result<T>` wraca z `JJDevHub.Shared.Kernel`. Core zna regułę hasła i roli.
Nie zna klienta HTTP katalogu i nie zna klucza prywatnego.

Koszt zostaje w tym repozytorium. Rotacja klucza, bootstrap właściciela i projekcja skrótu konta
nie są konsolą obcego produktu. Obraz dostaje tag `identity-vX.Y.Z`. Identity podaje ten tag
bramie, która składa `GET /versions`, i nie składa listy sąsiadów. Szóstka projektów jest ceną
za to, że licencja, model osoby i materiał podpisu mają jednego właściciela w solution. Pakietu
na hasło w `Directory.Packages.props` nie ma: skrót liczy runtime.

### RSA i JWKS

Identity podpisuje access token algorytmem RS256 i publikuje klucz publiczny jako JWKS.
Sąsiednie hosty ustawiają walidację na ten dokument. Klucz prywatny czyta tylko Identity, z
OpenBao, ze ścieżki `secret/identity/rsa`. `GET /.well-known/jwks.json` oddaje `kid` i `alg`
RS256, bez składnika prywatnego. Test `Jwks_exposes_public_key_only` sprawdza, że JSON ma `n` i
`e`, a nie ma `d`. Walidacja u sąsiada obejmuje podpis względem JWKS, wystawcę, odbiorcę
`jjdevhub`, czas oraz `alg` wyłącznie RS256. Zakaz `alg: none` jest częścią tej walidacji.
`RoleClaimType` mapuje się na `role`. Sąsiad nie dostaje `IssuerSigningKey`. Test
`Neighbor_validation_has_no_signing_key` pilnuje, że rejestracja usług w teście ServiceDefaults
nie zawiera klucza prywatnego.

Pięć procesów ma uznać ten sam token, a materiał do podpisu ma mieć jeden proces. Student po
`POST /api/identity/login` dostaje access token na 15 minut i refresh token na 30 dni. Claim
`sid` niesie `sessionId`. News, Learning, Cv i Contact mają ten token przyjąć albo odrzucić, nie
pytając `identity_write`, czy wiersz sesji istnieje. Przy zwykłym wywołaniu dowodem jest podpis
i czas życia. Koniec sesji jest osobnym zdarzeniem, nie odczytem bazy kont.

HMAC z współdzielonym sekretem odpadł, bo każdy pod, który sprawdza podpis, dostałby materiał
zdolny ten podpis złożyć. Klucz w pliku repozytorium odpadł razem z resztą sekretów. Certyfikat
w obrazie Dockera odpadł, bo obraz jest publicznym artefaktem buildu. Token deweloperski OpenBao
jest w user secrets, nie w gicie. W repozytorium nie ma PEM klucza ani hasła bootstrapu.
`git grep` po materiale klucza prywatnego w `src/services/Identity` ma nic nie zwrócić.

Koszt to pole `kid`, dwa klucze publiczne w JWKS w oknie nakładki i zegar, który pilnuje, kiedy
stary `kid` schodzi z dokumentu. Nakładka trwa 24 godziny, czyli dłużej niż życie access tokenu.
Token wystawiony chwilę przed rotacją ma 15 minut ważności i przez cały ten czas znajduje
dotychczasowy klucz wśród kluczy publicznych. Endpoint JWKS serializuje klucz publiczny i trzyma
kopię w Redis pod `identity:jwks` na minutę. Utrata Redisa zwalnia ten odczyt: dokument da się
złożyć ponownie z PEM, tylko bez minuty cache. Skrót hasła zostaje w PostgreSQL i tej awarii nie
dotyczy.

### Strumień konta i zaproszenia

`Account` i `StudentInvite` są agregatami ze strumieniem zdarzeń w `identity_write`. Historia
rejestracji, zmiany nazwy, zmiany hasła i życia zaproszenia jest produktem, nie tylko bieżącym
wierszem. Strumień konta nazywa się `account-{guid}`, a jego identyfikator to `IdentityGuid`.
Strumień zaproszenia nazywa się `student-invite-{guid}`. Audyt „kto dostał rolę `student` i
którym kodem” ma dać się odtworzyć z magazynu. Ekran listy nie odtwarza strumienia przy każdym
`GET`. Czyta projekcję.

Tabela mutowalna bez historii odpadła, bo utrata poprzedniego skrótu hasła i poprzedniej nazwy
kasuje ślad. Osobny agregat na nazwę wyświetlaną odpadł, bo nazwa jest polem `Account`, a nie
drugim bytem z własnym identyfikatorem. `DisplayName` ma od 1 do 80 znaków po obcięciu spacji i
zmienia się na tym samym strumieniu co skrót hasła. Zdarzenie `identity.display-name-changed.v1`
podbija wersję `account-{guid}`. Test `Display_name_is_field_of_account` sprawdza, że nie
powstaje drugi strumień. Pusta nazwa po obcięciu spacji kończy się kodem
`account.display-name.blank`.

Zapis idzie przez wersję strumienia. Odczyt listy idzie przez projekcję, która dogania strumień
z opóźnieniem. Krótko po `POST` lista ownera może jeszcze nie pokazać wiersza.
`GET /api/identity/me` ładuje strumień `Account`, nie tabelę odczytu, żeby własna nazwa po
zapisie była natychmiastowa. `ETag` odpowiedzi zapisu to wersja strumienia w cudzysłowie, na
przykład `"7"`. Na `PUT` nazwy, `PUT` hasła i revoke nagłówek `If-Match` jest wymagany. Brak
mapuje się na 428 i kod `precondition.required`. Niezgodność z wersją mapuje się na 412 i kod
`precondition.failed`. `POST` tworzenia nagłówka nie wymaga, bo nie ma jeszcze wersji do
podstawienia.

Słownik kultur przy koncie nie występuje. Nazwa wyświetlana jest jednym ciągiem, nie mapą `pl` i
`en`. Tłumaczenie, które w tym numerze zależy od kultury, dotyczy zdania błędu.
`Accept-Language` wybiera `pl` domyślnie albo `en`, gdy nagłówek tak mówi. Pole `title` w
`ProblemDetails` pochodzi z tych zasobów. Pole `type` jest kodem. Mapa `pl` /`en` zostaje przy
tekście notatki i przy zdaniu błędu, nie przy `DisplayName`.

### Skrót hasła w strumieniu

Pole agregatu trzyma skrót, nigdy tekst hasła. Algorytm to PBKDF2-SHA256, 600 000 iteracji, sól
16 bajtów, wynik 32 bajty, z BCL (`Rfc2898DeriveBytes`). Zapisany ciąg ma postać
`pbkdf2-sha256$600000$<sól>$<skrót>`. Porównanie jest stałoczasowe. Liczenie skrótu jest portem
`IPasswordHasher` w Infrastructure. `Identity.Core` widzi niepusty ciąg i nie zna iteracji.
Metoda agregatu przyjmuje już policzony napis. Hasło ma co najmniej 12 znaków. Krótsze kończy
się kodem `account.password.weak` i HTTP 400. Tekst hasła nie wchodzi do strumienia, projekcji,
logu, outboxa ani odpowiedzi.

Strumień leży w bazie, do której zagląda backup. Tekst hasła w zdarzeniu zostałby w tej kopii na
zawsze. Zdarzenie `identity.password-changed.v1` niesie w ładunku tylko nowy skrót. Test
`Password_hash_is_not_plaintext` sprawdza, że po rejestracji zdarzenie strumienia nie zawiera
tekstu hasła, a porównanie z tym tekstem przechodzi. Bootstrap czyta hasło początkowe ze ścieżki
`secret/identity/owner-initial-password` i go nie loguje. Adres właściciela czyta z
`secret/identity/owner-email`. Gdy strumień właściciela już jest, hosted service nic nie
zmienia.

Argon2 z osobnego pakietu odpadł na tym numerze, bo parametry PBKDF2 z zaleceń OWASP są w
runtime i nie dokładają natywnej biblioteki. Sól krótka i niska liczba iteracji odpadły razem z
szybkim hashem. Zwracanie tego samego kodu dla złego hasła i nieznanego e-maila zostaje: klient
dostaje `account.credentials.invalid` i HTTP 401. Test
`Login_unknown_email_and_wrong_password_share_code` spina oba wejścia. Blokada po piątej porażce
na 15 minut dzieje się w agregacie i na zewnątrz używa tego samego kodu. Zły login daje 401, nie
404. To odpowiedź o sekretach, nie o ukrytym dokumencie. Użytkownik zablokowany widzi ten sam
komunikat co przy literówce.

Koszt jest po stronie CPU przy logowaniu i przy zmianie hasła. Parametry są zamrożone w
zapisanym ciągu, więc późniejsza zmiana iteracji nie unieważnia starego skrótu. Kto porówna
hasło, czyta sól i licznik z napisu, nie ze stałej w `Identity.Core`. Limit z jednego adresu IP
nie zastępuje blokady agregatu. Licznik IP siedzi w Redis pod `identity:login:{ip}`. Licznik
porażek i chwila blokady siedzą w strumieniu. Utrata Redisa zdejmuje limit na IP i zostawia
blokadę zapisaną w PostgreSQL. Zdarzenie `identity.login-failed.v1` podbija licznik. Zdarzenie
`identity.login-succeeded.v1` zeruje go po zgodnym sekrecie.

### IdentityGuid

Identyfikator agregatu `Account` jest GUID-em i claimem `sub`. Na szynie i w cudzej usłudze
nazywa się `IdentityGuid`. E-mail zostaje w Identity. Rezerwacja `email_reservation` trzyma
klucz e-mail po `trim` i małych literach oraz wartość `IdentityGuid`. Wpis powstaje w tej samej
transakcji co dopisanie zdarzenia rejestracji. Kolizja klucza zwraca `account.email.taken` i
HTTP 409. Test `Register_duplicate_email_returns_taken` sprawdza drugą rezerwację. Poza tą
usługą adres nie wskazuje wiersza. Sąsiad, który ma nazwać człowieka, używa GUID-a z tokenu albo
z pola zdarzenia.

Zmiana adresu albo wyświetlanej nazwy nie może przepisać kluczy w News, Learning, Cv i Contact.
E-mail jako klucz obcy odpadł. Osobny identyfikator na usługę odpadł, bo człowiek jest jeden, a
usługi i tak nie współdzielą bazy. Profil publiczny CV jest innym agregatem. `DisplayName` konta
nie jest nagłówkiem strony CV. Poza tą usługą identyfikatorem człowieka zostaje `IdentityGuid`,
także wobec tamtego profilu. Korekta nazwy konta jest zdarzeniem na strumieniu `account-{guid}`,
nie zapisem sekcji CV.

Koszt siedzi w czasie życia claimu. JWT niesie `sub` do wygaśnięcia access tokenu. Przez te 15
minut sąsiad widzi identyfikator z chwili wydania. Sam identyfikator się nie zmienia. Zmienia
się co najwyżej wyświetlana nazwa. Jest ona widoczna w `GET /api/identity/me` od razu ze
strumienia, a w claimie `name` dopiero po następnym logowaniu. Lista ownera może pokazać nazwę
później niż `me`, bo lista idzie z projekcji `account_summary`, a `me` ze strumienia. To dwa
odczyty tego samego konta, z dwóch magazynów.

### Role i polityki

Token niesie jedną rolę: `owner` albo `student`. Polityki o nazwach `Owner` i `Student` są
zarejestrowane w `JJDevHub.ServiceDefaults`. Identity jest jedynym miejscem, które rolę nadaje.
Zaproszenie nadaje `student`. Bootstrap nadaje `owner`. Rejestracja publiczna właściciela nie
istnieje. `POST /api/identity/register` jest anonimowy. Body niesie e-mail, hasło, `displayName`
i `inviteCode`. Roli w tym body nie ma. Brak kodu daje `invite.code.invalid`, a strumień konta
nie powstaje. Test `Register_without_invite_returns_invalid` trzyma tę ścieżkę.

Każda usługa miałaby skopiowany warunek „claim równa się owner” i któraś kopia rozjechałaby się
przy zmianie nazwy. Role w bazie każdej usługi odpadły. Trzecia rola rekrutera odpadła: rekruter
nie ma konta, jego formularz jest w [kontakcie](21-kontakt.md). Koszt jest sztywny. Jedna osoba
ma jedną rolę. Właściciel nie jest jednocześnie studentem. Macierz uprawnień jest krótka. Konto
właściciela nie przechodzi rejestracji studenckiej, a token studenta nie spełnia polityki
`Owner`.

Claimy access tokenu są krótkie i wystarczają sąsiadowi do obu polityk: `sub` (`IdentityGuid`),
`role` (`owner` albo `student` ), `sid`, `email`, `name`, `iss`, `aud` (`jjdevhub`), `exp`,
`iat`. E-mail i nazwa w tokenie są claimami do wygaśnięcia, nie kluczami obcymi. Odświeżenie
pary na `POST /api/identity/refresh` wydaje nową parę i unieważnia stary refresh. Skrót
aktualnego refresh tokenu zostaje w strumieniu. Zdarzenie `identity.refresh-rotated.v1` zapisuje
nowy skrót i nowy `sessionId` przy pierwszym logowaniu. Wylogowanie czyści ten skrót.

### Dwie bazy i Redis

`identity_write` trzyma strumienie, rezerwację e-maila i outbox. `identity_read` trzyma skrót
konta i skrót zaproszenia, bez skrótu hasła. Redis trzyma licznik nieudanych logowań per adres
IP pod kluczem `identity:login:{ip}` oraz dokument JWKS pod `identity:jwks`. Utrata Redisa
zwalnia odczyt JWKS i zdejmuje limit na IP. Skrót hasła zostaje w PostgreSQL. Handler komendy
nie składa listy kont ze strumienia przy każdym `GET`. Lista ownera czyta `account_summary` i
`invite_summary`. Limit zgadywania per IP nie polega na skanie bazy.

Jedna baza z dwoma schematami odpadła. Zapis i odczyt są osobnymi connection stringami, tak jak
w reszcie usług. MongoDB odpadło. Redis jako magazyn konta odpadł. Konto, które przeżywa restart
procesu, jest strumieniem w Postgresie. Klucz Redis ma prefiks `identity:` i nie jest wierszem
osoby. Skrótu hasła, skrótu kodu i skrótu refresh tokenu w `identity_read` nie ma. Backup
odczytu nie staje się zbiorem sekretów.

Koszt to dwa connection stringi w AppHost i projekcja, która ma własny checkpoint. AppHost
dostaje projekt `Identity.Api` z referencjami `identity-write`, `identity-read`, Redis, Kafka i
OpenBao. Opóźnienie listy po `POST` jest tym kosztem, nie awarią transakcji. Rejestracja
studenta w jednej transakcji rezerwuje e-mail, dopisuje `identity.account-registered.v1`, robi
redeem zaproszenia i wkłada wiersz outbox z `identity.user-registered.v1`. Kolizja albo błąd
outboxa nie zostawia połowy. Test Persistence sprawdza, że strumień i rezerwacja wchodzą razem
albo nie wchodzi nic. Słabo spójny zostaje tylko wiersz projekcji za checkpointem.

### Kod zaproszenia

`InviteCode` jest value objectem przy `StudentInvite`. Tekst kodu (128 bitów, Base32) wraca raz
w odpowiedzi utworzenia. Strumień trzyma `sha256$<hex>`. Owner nie odczyta kodu drugi raz.
Redeem dzieje się w rejestracji studenta i oznacza zaproszenie jako zużyte. `StudentInvite`
trzyma skrót kodu, opcjonalny e-mail, chwilę wygaśnięcia, status `issued`, `redeemed` albo
`revoked` oraz `IdentityGuid` studenta po redeem. Revoke działa tylko ze statusu `issued`. Po
`redeemed` i po `revoked` kolejne użycie zwraca kod z tabeli błędów.

Kod w logu aplikacji albo w projekcji listy byłby hasłem jednorazowym wystawionym na stałe. Kod
zapisany otwartym tekstem, „żeby owner mógł go skopiować później”, odpadł. Wolny skrót haseł na
kodzie o entropii 128 bitów odpadł, bo tu wystarcza SHA-256, a PBKDF2 zostaje przy haśle
człowieka. Tabela `invite_summary` po projekcji nie zawiera kodu ani jego skrótu. Test
`Invite_code_absent_from_read_model` to sprawdza. Ścieżka listy jest dla polityki `Owner`.
Identyfikator nieznany na ścieżce ownera daje 404. Wywołanie spoza tej polityki nie dostaje
odpowiedzi, z której wyczytałoby, że wiersz istnieje.

Koszt jest operacyjny. Zgubiony kod wymaga nowego zaproszenia. Stare da się tylko unieważnić.
`POST /api/identity/invites` zwraca kod w body jeden raz i wymaga polityki `Owner`.
`GET /api/identity/invites` tego kodu nie ma. `POST /api/identity/invites/{id}/revoke` wymaga
`If-Match` i przechodzi w `revoked`. Rejestracja woła redeem w tej samej transakcji co nowe
konto. Drugi student z tym samym kodem dostaje `invite.code.redeemed`. Brak kodu daje
`invite.code.invalid`. Kod po czasie daje `invite.code.expired`. Kod zdjęty przez ownera daje
`invite.code.revoked`. Każdy z tych czterech kodów to HTTP 400. Test
`Register_redeemed_invite_returns_invalid` pilnuje zużytego kodu.

### Nazwa zdarzenia

Klasa w `Identity.Contracts` nazywa się `UserRegisteredIntegrationEvent`. Atrybut to
`[EventName("identity.user-registered.v1")]`. Ta nazwa wchodzi do outboxa i na temat
`identity.integration`. Nazwa CLR nie wchodzi. Wylogowanie dopisuje `identity.session-ended.v1`
z polami `identityGuid` i `sessionId`. Rekord `SessionEndedIntegrationEvent` niesie
`identityGuid`, `sessionId` i `occurredOn`. Rekord rejestracji niesie `identityGuid`, `role`,
`displayName` i `occurredOn`. Żadne z tych pól nie jest value objectem CLR w JSON. Ładunek to
prymitywy. Value object z Core nie wchodzi do JSON.

Deserializacja po nazwie typu pęka przy zmianie namespace, a konsument Contact ma reagować na
koniec sesji logowania bez czytania `identity_write`. Contact kasuje token urządzenia tej sesji.
Inne usługi mogą konsumować `identity.user-registered.v1`. Test
`User_registered_event_name_is_stable` sprawdza, że wiersz outbox ma
`identity.user-registered.v1`, a nazwa klasy nie występuje w kolumnie typu. Test
`Session_ended_carries_session_id` sprawdza, że logout wkłada `identityGuid` i `sessionId` jako
prymitywy. Logout czyści skrót refresh w strumieniu i w tej samej transakcji wkłada ten outbox.

Nazwa tematu równa pełnej nazwie klasy odpadła. Jeden worek „identity.event” bez wersji w nazwie
odpadł. Nowy fakt to nowy rekord, nowy atrybut i konsument, który zna stały napis. Zdarzenia
domenowe zostają w strumieniu: `identity.account-registered.v1`,
`identity.display-name-changed.v1`, `identity.password-changed.v1`, `identity.login-failed.v1`,
`identity.login-succeeded.v1`, `identity.refresh-rotated.v1`, `identity.session-ended.v1`,
`identity.student-invite-issued.v1`, `identity.student-invite-redeemed.v1` i
`identity.student-invite-revoked.v1`. Na temat `identity.integration` wychodzą dwa rekordy z
`Identity.Contracts`. Fakty logowania i korekty nazwy zostają przy strumieniu konta. Kopia
integracyjna `identity.session-ended.v1` jest tym z nich, którego potrzebuje Contact.

## Klasy i ścieżki

Sześć projektów rozdziela regułę, przypadek użycia, magazyn, adapter, host i kontrakt szyny.
`Identity.Core` zostaje przy `Account`, `StudentInvite` i `InviteCode`. Reszta solution może
zależeć od ASP.NET albo Kafki, ten projekt nie. Tabele poniżej są wiążące: strumień, zdarzenie,
endpoint, kod `Result` i ścieżka sekretu. Zdanie pod tabelą dopowiada, czego w kolumnie nie ma,
zwłaszcza skrótu hasła w odczycie.

Projekty:

| Projekt | Referencje | Odpowiedzialność |
| --- | --- | --- |
| `src/services/Identity/Identity.Core` | tylko `JJDevHub.Shared.Kernel` | `Account`, `StudentInvite`, `InviteCode`, zdarzenia domenowe |
| `src/services/Identity/Identity.Application` | `Identity.Core`, `JJDevHub.Cqrs` | komendy, zapytania, porty |
| `src/services/Identity/Identity.Persistence` | porty Application, magazyn Postgres | `IdentityWriteContext`, `IdentityReadContext` |
| `src/services/Identity/Identity.Infrastructure` | porty Application | skrót hasła, OpenBao, Redis, Kafka |
| `src/services/Identity/Identity.Api` | skład hosta, `JJDevHub.ServiceDefaults` | endpointy, `Program.cs`, JWKS |
| `src/services/Identity/Identity.Contracts` | biblioteka atrybutu `EventName` | rekordy na szynę |

`Identity.Core` nie referencjonuje MediatR, Entity Framework, Kafki ani ASP.NET. Mediator
wołający handlery jest w `JJDevHub.Cqrs`. `Result<T>` wraca z `JJDevHub.Shared.Kernel`.

Strumienie w `identity_write`:

| Strumień | Agregat | Identyfikator |
| --- | --- | --- |
| `account-{guid}` | `Account` | `IdentityGuid` |
| `student-invite-{guid}` | `StudentInvite` | identyfikator zaproszenia |

Tabele obok strumienia, w tej samej bazie zapisu: `email_reservation` (klucz: e-mail po `trim` i
małych literach, wartość: `IdentityGuid` ), outbox, checkpoint projekcji. Rezerwacja e-maila
wchodzi do tej samej transakcji co dopisanie zdarzenia rejestracji.

`Account` trzyma: `IdentityGuid`, e-mail, `DisplayName`, skrót hasła, rolę, skrót aktualnego
refresh tokenu, `sessionId`, licznik porażek, chwilę blokady, wersję. `DisplayName` ma od 1 do
80 znaków po obcięciu spacji. Nazwa wyświetlana nie jest osobną klasą agregatu.

`StudentInvite` trzyma: skrót kodu, opcjonalny e-mail, chwilę wygaśnięcia, status `issued`,
`redeemed` albo `revoked`, `IdentityGuid` studenta po redeem.

Zdarzenia domenowe, każde z `[EventName]`, zostają w strumieniu:

| Nazwa | Kiedy |
| --- | --- |
| `identity.account-registered.v1` | bootstrap właściciela albo rejestracja studenta |
| `identity.display-name-changed.v1` | zmiana pola `DisplayName` |
| `identity.password-changed.v1` | zmiana hasła, w ładunku tylko nowy skrót |
| `identity.login-failed.v1` | zły sekret, podbija licznik |
| `identity.login-succeeded.v1` | zgodny sekret, zeruje licznik |
| `identity.refresh-rotated.v1` | nowy skrót refresh tokenu i nowy `sessionId` przy pierwszym logowaniu |
| `identity.session-ended.v1` | wylogowanie, czyści skrót refresh tokenu w strumieniu; kopia integracyjna idzie na szynę |
| `identity.student-invite-issued.v1` | owner wystawił zaproszenie |
| `identity.student-invite-redeemed.v1` | rejestracja zużyła kod |
| `identity.student-invite-revoked.v1` | owner unieważnił kod przed użyciem |

Ładunek w tabeli strumienia to pola skalarne. Słownik kultur tu nie występuje: nazwa wyświetlana
jest jednym ciągiem na koncie, nie mapą `pl` /`en`.

Rekordy `Identity.Contracts`:

| Klasa | `EventName` | Pola |
| --- | --- | --- |
| `UserRegisteredIntegrationEvent` | `identity.user-registered.v1` | `identityGuid`, `role`, `displayName`, `occurredOn` |
| `SessionEndedIntegrationEvent` | `identity.session-ended.v1` | `identityGuid`, `sessionId`, `occurredOn` |

Temat `identity.integration` należy do Identity. Contact konsumuje `identity.session-ended.v1` i
kasuje token urządzenia tej sesji. Inne usługi mogą konsumować `identity.user-registered.v1`.
Żadne z tych pól nie jest value objectem CLR w JSON.

Projekcja w `identity_read`:

| Tabela | Kolumny | Kto czyta |
| --- | --- | --- |
| `account_summary` | `IdentityGuid`, e-mail, `DisplayName`, rola, data utworzenia, wersja | `GET` listy ownera i podgląd konta |
| `invite_summary` | identyfikator, status, wygaśnięcie, e-mail docelowy, `IdentityGuid` po redeem | lista zaproszeń ownera |

Skrótu hasła, skrótu kodu i skrótu refresh tokenu w `identity_read` nie ma.

Endpointy:

| Metoda i ścieżka | Kto | Skutek |
| --- | --- | --- |
| `GET /.well-known/jwks.json` | każdy | klucze publiczne, `kid`, `alg` RS256, bez składnika prywatnego |
| `POST /api/identity/register` | anonim | student, body: e-mail, hasło, `displayName`, `inviteCode` |
| `POST /api/identity/login` | anonim | access token 15 minut, refresh token 30 dni, `sessionId` w claimie `sid` |
| `POST /api/identity/refresh` | refresh token | nowa para, stary refresh odpada |
| `POST /api/identity/logout` | access token i refresh | koniec sesji, zdarzenie `identity.session-ended.v1` |
| `GET /api/identity/me` | zalogowany | własne konto ze strumienia, bez skrótu |
| `PUT /api/identity/me/display-name` | zalogowany, `If-Match` | zmiana pola `DisplayName` |
| `PUT /api/identity/me/password` | zalogowany, `If-Match`, bieżące hasło | nowy skrót |
| `POST /api/identity/invites` | polityka `Owner` | nowy `StudentInvite`, kod w body odpowiedzi jeden raz |
| `POST /api/identity/invites/{id}/revoke` | polityka `Owner`, `If-Match` | status `revoked` |
| `GET /api/identity/invites` | polityka `Owner` | lista z `identity_read` |
| `GET /api/identity/accounts` | polityka `Owner` | lista skrótów kont |

Claimy access tokenu: `sub` (`IdentityGuid`), `role` (`owner` albo `student` ), `sid`, `email`,
`name`, `iss`, `aud` (`jjdevhub`), `exp`, `iat`. Walidacja u sąsiada: podpis JWKS, wystawca,
odbiorca, czas, `alg` wyłącznie RS256. `RoleClaimType` mapuje się na `role`. Sąsiad nie dostaje
`IssuerSigningKey`.

Kody `Result`, tłumaczone na brzegu z `Accept-Language` (`pl` domyślnie, `en` gdy nagłówek tak
mówi):

| Kod | HTTP |
| --- | --- |
| `account.credentials.invalid` | 401 |
| `account.email.taken` | 409 |
| `account.display-name.blank` | 400 |
| `account.password.weak` | 400 |
| `invite.code.invalid` | 400 |
| `invite.code.expired` | 400 |
| `invite.code.redeemed` | 400 |
| `invite.code.revoked` | 400 |
| `precondition.required` | 428, brak `If-Match` |
| `precondition.failed` | 412, nieaktualny `If-Match` |

Hasło ma co najmniej 12 znaków. `ETag` odpowiedzi zapisu to wersja strumienia w cudzysłowie, na
przykład `"7"`.

Bootstrap: hosted service czyta z OpenBao ścieżki `secret/identity/owner-email` i
`secret/identity/owner-initial-password`. Gdy strumień właściciela już jest, nic nie zmienia.
Hasła nie loguje. Klucz prywatny RSA leży pod `secret/identity/rsa`. Token deweloperski OpenBao
jest w user secrets, nie w gicie.

AppHost dostaje projekt `Identity.Api` z referencjami `identity-write`, `identity-read`, Redis,
Kafka i OpenBao.

## Plan

### 1. Projekty

Utwórz sześć projektów z tabeli powyżej. W `Identity.Core.csproj` zostaw jedną
`ProjectReference`: `JJDevHub.Shared.Kernel`. W `Directory.Packages.props` nie dokładaj pakietu
na hasło. Podłącz `Identity.Api` do `JJDevHub.AppHost` z dwoma connection stringami.

### 2. Agregat Account

Dodaj `Account` jako agregat strumienia `account-{guid}`. Pole `DisplayName` ustaw w konstrukcji
i w metodzie zmiany nazwy. Skrót hasła ustawiaj wyłącznie przez metodę, która przyjmuje już
policzony ciąg. Rola jest argumentem rejestracji: `owner` albo `student`. Trzymaj wersję
oczekiwaną przy dopisaniu zdarzenia.

### 3. Agregat StudentInvite

Dodaj `StudentInvite` i `InviteCode`. Wystawienie zapisuje skrót SHA-256. Redeem przyjmuje
`IdentityGuid` nowego studenta i przechodzi w `redeemed`. Revoke działa tylko ze statusu
`issued`. Po `redeemed` i po `revoked` kolejne użycie zwraca kod z tabeli błędów.

### 4. Porty

W Application dodaj `IPasswordHasher`, `ISigningKeyStore`, `ITokenIssuer`, `IAccountStore`,
`IInviteStore`. Implementacje: PBKDF2 i odczyt PEM z OpenBao w Infrastructure, magazyn
strumienia w Persistence. `Program.cs` spina implementacje. Core tych interfejsów nie widzi, gdy
wymagałyby ASP.NET.

### 5. Schemat zapisu

W `identity_write` postaw strumień, `email_reservation` i outbox. Rejestracja studenta: w jednej
transakcji rezerwacja e-maila, dopisanie `identity.account-registered.v1`, redeem zaproszenia,
wiersz outbox z `identity.user-registered.v1`. Kolizja klucza rezerwacji zwraca
`account.email.taken`.

### 6. Projekcja

Worker projekcji składa `account_summary` i `invite_summary` w `identity_read`. Pomiń kolumny
skrótów. `GET /api/identity/me` ładuje strumień `Account`, nie tabelę odczytu, żeby własna nazwa
po zapisie była natychmiastowa.

### 7. Token i JWKS

Wystawiaj RS256 z `kid`. `GET /.well-known/jwks.json` serializuje klucz publiczny i cache pod
`identity:jwks` na minutę. W `JJDevHub.ServiceDefaults` dodaj polityki `Owner` i `Student` oraz
rozszerzenie walidacji JWT, które bierze klucze z JWKS i nie rejestruje klucza prywatnego. Okno
nakładki starego `kid`: 24 godziny.

### 8. Endpointy sesji

Zaimplementuj rejestrację, login, refresh, logout i `me` według tabeli. Login po piątej porażce
w 15 minut zostawia ten sam kod `account.credentials.invalid`. Logout czyści skrót refresh w
strumieniu i w tej samej transakcji wkłada outbox `identity.session-ended.v1`. Limit IP na
loginie zapisuj w Redis.

### 9. Zaproszenia

Endpointy ownera: tworzenie, unieważnienie, lista. Odpowiedź tworzenia zawiera kod jeden raz.
Lista czyta `invite_summary` i tego kodu nie ma. Rejestracja woła redeem w tej samej transakcji
co nowe konto.

### 10. Zapis z wersją

Na `PUT` nazwy, `PUT` hasła i revoke wymagaj `If-Match`. Brak nagłówka mapuj na 428. Niezgodność
z wersją strumienia mapuj na 412. `POST` tworzenia nagłówka nie wymaga.

### 11. Testy numeru

Dodaj projekty testowe z sekcji Testy i wpisz je do solution. Scenariusz NBomber dotyczy
wyłącznie `GET /.well-known/jwks.json`.

### Co jest do czego

| Klasa albo job | Po co istnieje | Kto woła |
| --- | --- | --- |
| `Account` | trzyma rolę, nazwę i skrót hasła jednej osoby | komendy rejestracji, logowania, zmiany nazwy, zmiany hasła, końca sesji |
| `StudentInvite` | wydaje i zużywa kod studenta | komenda ownera i rejestracja |
| `InviteCode` | pilnuje formatu kodu przed hashowaniem | `StudentInvite` |
| `IPasswordHasher` | liczy i porównuje PBKDF2 poza Core | login i zmiana hasła |
| `ISigningKeyStore` | czyta PEM z OpenBao | issuer tokenu i endpoint JWKS |
| `ITokenIssuer` | składa JWT RS256 | login i refresh |
| `EnsureOwnerHostedService` | tworzy jedno konto `owner`, gdy strumienia jeszcze nie ma | start hosta |
| `AccountProjection` | składa listy bez skrótu hasła | worker po checkpointcie strumienia |
| `UserRegisteredIntegrationEvent` | mówi sąsiadom o nowym `IdentityGuid` | outbox na `identity.integration` |
| `SessionEndedIntegrationEvent` | mówi Contact, która sesja logowania się skończyła | outbox, konsument w [kontakcie](21-kontakt.md) |
| Polityka `Owner` / `Student` | jeden predykat roli dla wszystkich usług | atrybut endpointu w tej usłudze i w sąsiadach |

Rejestracja studenta idzie jedną transakcją w `identity_write`. Warstwa Api zdejmuje z body
e-mail, hasło, `displayName` i `inviteCode`. `IPasswordHasher` liczy skrót, zanim `Account`
przyjmie gotowy ciąg i rolę `student`. `InviteCode` pilnuje formatu, zanim `StudentInvite`
zapisze `sha256$<hex>`. Redeem przyjmuje `IdentityGuid` nowego studenta i przechodzi w
`redeemed`. `IAccountStore` dopisuje strumień `account-{guid}`. `IInviteStore` dopisuje strumień
`student-invite-{guid}`. W tej samej transakcji ląduje `email_reservation` i wiersz outbox z
`UserRegisteredIntegrationEvent` o nazwie `identity.user-registered.v1`. Kolizja rezerwacji
zwraca `account.email.taken` i nie zostawia połowy zapisu.

Logowanie woła ten sam hasher do porównania stałoczasowego. `ITokenIssuer` składa JWT RS256.
`ISigningKeyStore` czyta PEM z OpenBao i ten sam odczyt zasila `GET /.well-known/jwks.json` oraz
cache `identity:jwks`. Przy pierwszym udanym logowaniu `identity.refresh-rotated.v1` zapisuje
skrót refresh tokenu i `sessionId`. Zgodny sekret dopisuje `identity.login-succeeded.v1` i
zeruje licznik. Porażka dopisuje `identity.login-failed.v1`. Piąta porażka w 15 minut zostawia
kod `account.credentials.invalid`. Licznik IP pod `identity:login:{ip}` jest osobnym hamulcem i
nie zastępuje licznika w agregacie.

`EnsureOwnerHostedService` przy starcie hosta czyta `secret/identity/owner-email` i
`secret/identity/owner-initial-password`. Gdy strumień właściciela już jest, nic nie zmienia i
hasła nie loguje. `AccountProjection` po checkpointcie składa `account_summary` i
`invite_summary` bez kolumn skrótów. Polityki `Owner` i `Student` są predykatem endpointu tutaj
i u sąsiadów. `PUT` nazwy, `PUT` hasła i revoke niosą `If-Match`. `SessionEndedIntegrationEvent`
wychodzi przy `POST /api/identity/logout`, w tej samej transakcji co czyszczenie skrótu refresh,
i jest konsumowany w [kontakcie](21-kontakt.md). `GET /api/identity/me` omija projekcję i czyta
strumień, więc własna nazwa nie czeka na checkpoint.

## Testy

Runner to xUnit i `[Fact]`. Jeden test, jeden powód. Nazwa mówi, co jest prawdą, gdy test
przechodzi.

Projekty:

| Projekt | Piętro |
| --- | --- |
| `src/services/Identity/tests/Identity.Core.Tests` | jednostkowe, bez bazy |
| `src/services/Identity/tests/Identity.Application.Tests` | jednostkowe, hasher i issuer podmienione |
| `src/services/Identity/tests/Identity.Persistence.Tests` | Testcontainers, obraz `postgres:16-alpine`, cecha `Category=Integration` |
| `src/services/Identity/tests/Identity.Api.Tests` | host i HTTP, ta sama cecha integracyjna |
| `src/services/Identity/tests/Identity.Performance.Tests` | NBomber, cecha `Category=Performance` |

Przypadki:

- `Register_without_invite_returns_invalid` — brak kodu daje `invite.code.invalid`, strumień
  konta nie powstaje.
- `Register_redeemed_invite_returns_invalid` — drugi student z tym samym kodem dostaje
  `invite.code.redeemed`.
- `Register_duplicate_email_returns_taken` — druga rezerwacja e-maila zwraca
  `account.email.taken`.
- `Password_hash_is_not_plaintext` — po rejestracji zdarzenie strumienia nie zawiera tekstu
  hasła, a porównanie z tym tekstem przechodzi.
- `Login_unknown_email_and_wrong_password_share_code` — oba wejścia dają
  `account.credentials.invalid`.
- `Display_name_is_field_of_account` — zmiana nazwy podbija wersję tego samego strumienia
  `account-{guid}`.
- `Jwks_exposes_public_key_only` — JSON ma `n` i `e`, nie ma `d`.
- `Neighbor_validation_has_no_signing_key` — rejestracja usług w teście ServiceDefaults nie
  zawiera klucza prywatnego.
- `Update_without_if_match_returns_428` — `PUT` nazwy bez nagłówka.
- `Update_with_stale_if_match_returns_412` — wersja starsza niż strumień.
- `Invite_code_absent_from_read_model` — po projekcji `invite_summary` nie zawiera kodu ani jego
  skrótu.
- `User_registered_event_name_is_stable` — wiersz outbox ma `identity.user-registered.v1`, a
  nazwa klasy nie występuje w kolumnie typu.
- `Session_ended_carries_session_id` — logout wkłada `identityGuid` i `sessionId` jako
  prymitywy.

Układ przypadku zostaje: przygotowanie, działanie, sprawdzenie, i jeden powód padnięcia. W
`Password_hash_is_not_plaintext` przygotowaniem jest rejestracja, działaniem odczyt zdarzenia
strumienia, sprawdzeniem brak tekstu hasła przy zgodnym porównaniu skrótu. W
`Update_without_if_match_returns_428` przygotowaniem jest istniejące konto, działaniem `PUT`
nazwy bez nagłówka, sprawdzeniem status 428. Fakt `Update_with_stale_if_match_returns_412` stoi
osobno, bo nieaktualna wersja jest drugim powodem. Nazwa metody mówi, co jest prawdą, gdy test
przechodzi. Runner to xUnit i `[Fact]`.

Integracja Persistence: Testcontainers podnosi Postgresa, rejestracja commituje strumień i
rezerwację albo nie commituje żadnego z nich. Kafka w teście outboxa idzie przez
`Testcontainers.Kafka` w trybie KRaft, tak jak w [testach](22-testy.md).

Wydajność: scenariusz NBomber woła `GET /.well-known/jwks.json` przez 30 sekund. Login do tego
scenariusza nie wchodzi. Cecha `Category=Performance`. Bramka, która ten test wymaga, jest
opisana w numerze 22: `main`.

Lokalnie, bez kontenerów i bez NBombera:
`dotnet test src/services/Identity --filter "Category!=Integration&Category!=Performance"`.

## Zasady

- `Identity.Core` referencjonuje wyłącznie `JJDevHub.Shared.Kernel`. Reguła konta i zaproszenia
  kompiluje się bez MediatR, Entity Framework, Kafki i ASP.NET.
- Oczekiwany błąd to `Result<T>` z kodem. Wyjątek zostaje dla awarii IO i błędu składu hosta.
  Oba kończą się jako `ProblemDetails`. Pole `type` jest kodem, pole `title` jest zdaniem z
  zasobów `pl` albo `en`. Klient czyta kod i zdanie, a nie stos wyjątku.
- Tekst hasła nie wchodzi do strumienia, projekcji, logu, outboxa ani odpowiedzi. Backup
  `identity_write` i zdarzenie `identity.user-registered.v1` nie stają się kopią sekretu, którym
  da się zalogować.
- `IdentityGuid` jest jedynym identyfikatorem człowieka poza tą usługą. Zmiana e-maila nie
  przepisuje kluczy w News, Learning, Cv ani Contact.
- Rola w tokenie to `owner` albo `student`. Polityki nazywają się `Owner` i `Student`. Sąsiad
  woła tę samą nazwę z `JJDevHub.ServiceDefaults`, bez własnej kopii warunku.
- Inna usługa waliduje JWT i nie podpisuje. W jej rejestracji nie ma `IssuerSigningKey` ani PEM
  z `secret/identity/rsa`.
- Zapis istniejącego agregatu wymaga `If-Match`. Brak to 428. Niezgodność to 412. Zapis ze
  starym znacznikiem nie nadpisuje wersji dopisanej między odczytem a `PUT`.
- Cudze zaproszenie pod `GET` spoza polityki `Owner` nie ujawnia, że wiersz istnieje: ścieżka
  listy jest dla `Owner`, a identyfikator nieznany na ścieżce ownera daje 404. Odpowiedź poza tą
  polityką nie jest potwierdzeniem, że identyfikator leży w bazie.
- Zły login daje 401, nie 404. To odpowiedź o sekretach, nie o ukrytym dokumencie. Nieznany
  e-mail i złe hasło dzielą kod `account.credentials.invalid`.
- Nazwa na szynie pochodzi z `[EventName]`. Ładunek integracyjny to prymitywy. Kolumna typu w
  outboxie niesie stały napis wersjonowany, a nie nazwę klasy CLR i nie value object z Core.
- Redis nie jest bazą kont. Prefiks klucza to `identity:`. Utrata Redisa zwalnia cache JWKS i
  limit IP, a skrót hasła zostaje w PostgreSQL.
- MongoDB nie wchodzi. Keycloak nie wchodzi. Duende nie wchodzi. Model człowieka zostaje przy
  `Account` i `StudentInvite` w tym repozytorium, bez katalogu obok i bez bazy dokumentów.
- Sekret i connection string z hasłem produkcyjnym nie wchodzą do gita. PEM i hasło bootstrapu
  są w OpenBao albo w user secrets, a `git grep` po materiale klucza prywatnego w
  `src/services/Identity` nic nie zwraca.
- Jeden publiczny typ na plik, klasa `sealed`, rekord dla danych bez zachowania,
  `CancellationToken` w metodzie `async`. Port asynchroniczny przyjmuje token anulowania, a dane
  bez zachowania nie dostają hierarchii dziedziczenia.

## Poza zakresem

- [Notatki](18-news.md), [kursy](19-learning.md) i [CV](20-cv.md) czytają token, nie tworzą
  konta. Rejestracja, login i JWKS zostają przy prefiksie `/api/identity` oraz przy
  `/.well-known/jwks.json`.
- Skasowanie tokenu urządzenia przy końcu sesji wykonuje [kontakt](21-kontakt.md), który
  konsumuje `identity.session-ended.v1`. Identity wkłada to zdarzenie do outboxa i nie woła HTTP
  sąsiada w trakcie logout.
- Ekrany logowania i pole kodu w kliencie są w `docs/frontend`. Ten numer kończy się na HTTP.
  Przeglądarka nie jest projektem w `src/services/Identity`.
- OpenBao na maszynie, vTPM i krótkotrwałe poświadczenie bazy są w `docs/cicd/14-openbao.md`.
  Tutaj OpenBao jest źródłem PEM i hasła bootstrapu w AppHost. Ścieżki tego numeru to
  `secret/identity/rsa`, `secret/identity/owner-email` i
  `secret/identity/owner-initial-password`.
- `GET /versions` składa brama z [numeru 16](16-gateway.md). Identity podaje swój numer obrazu
  `identity-vX.Y.Z`, nie składa listy sąsiadów. Agregacja tagów nie jest endpointem tej usługi.
- Reset hasła studenta przez ownera, federacja i drugi składnik logowania nie wchodzą w ten
  numer. Wejście studenta zostaje kodem zaproszenia, a jedyne konto `owner` zostaje przy
  bootstrapie.
- Profil publiczny CV jest innym agregatem. `DisplayName` konta nie jest nagłówkiem strony CV.
  Zmiana nazwy zostaje zdarzeniem `identity.display-name-changed.v1` na strumieniu konta.

## Źródła

- [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519). Wiążące są claimy `sub`, `exp`, `iat`,
  `iss` i `aud` oraz to, że access token jest podpisanym JWT, a nie magazynem sesji. W tym pliku
  `sub` jest `IdentityGuid`, `aud` ma wartość `jjdevhub`, a czas życia access tokenu to 15
  minut. Nie bierzemy stąd JWE ani zagnieżdżonego tokenu. Skrót refresh tokenu leży w
  strumieniu, a RFC nie narzuca tu drugiego dokumentu obok access tokenu.
- [RFC 7517](https://www.rfc-editor.org/rfc/rfc7517). Wiążący jest kształt zbioru JWK: klucz
  publiczny i `kid`. W tym pliku `GET /.well-known/jwks.json` oddaje ten dokument, a test
  `Jwks_exposes_public_key_only` wymaga pól `n` i `e` oraz braku `d`. Nie bierzemy stąd
  publikacji klucza symetrycznego ani parametrów prywatnych w zestawie, który czyta sąsiad.
- [RFC 7518](https://www.rfc-editor.org/rfc/rfc7518). Wiążące jest RS256 i zakaz `alg: none`. W
  tym pliku walidacja sąsiada przyjmuje wyłącznie RS256, a nakładka rotacji dotyczy `kid`, nie
  zmiany algorytmu. Nie bierzemy stąd HS256, bo współdzielony sekret dawałby każdemu podowi
  materiał do złożenia podpisu.
- [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585). Wiążący jest status 428 Precondition
  Required. W tym pliku brak `If-Match` na zmianie nazwy, zmianie hasła i revoke zaproszenia
  mapuje się na `precondition.required` i HTTP 428. Nie bierzemy stąd 429 jako kodu tej usługi:
  tabela `Result` Identity nie ma pozycji limitu, a zły sekret zostaje 401.
- [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110). Wiążące są 412 Precondition Failed oraz
  semantyka 404 i 401. W tym pliku nieaktualny `If-Match` daje `precondition.failed` i 412,
  nieznany identyfikator na ścieżce ownera daje 404, a złe dane logowania dają 401, nie 404. Nie
  bierzemy stąd 404 dla złego hasła: to odpowiedź o sekrecie, nie o ukrytym dokumencie.
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html).
  Wiążący jest rząd wielkości iteracji PBKDF2 oraz osobna sól. W tym pliku algorytm to
  PBKDF2-SHA256, 600 000 iteracji, sól 16 bajtów, wynik 32 bajty, porównanie stałoczasowe. Nie
  bierzemy stąd Argon2 jako algorytmu tego numeru: osobny pakiet odpadł, a parametry PBKDF2 są w
  runtime.
- [Rfc2898DeriveBytes](https://learn.microsoft.com/dotnet/api/system.security.cryptography.rfc2898derivebytes).
  Wiążące jest API skrótu w BCL, bez pakietu w `Directory.Packages.props`. W tym pliku port
  `IPasswordHasher` w Infrastructure liczy skrót tą klasą, a zapisany ciąg ma postać
  `pbkdf2-sha256$600000$<sól>$<skrót>`. Nie bierzemy stąd domyślnej, niskiej liczby iteracji:
  liczba 600 000 jest jawna i zamrożona w napisie, a `Identity.Core` widzi tylko niepusty ciąg.
- [OpenBao KV](https://openbao.org/docs/secrets/kv/). Wiążący jest magazyn klucz-wartość i
  ścieżka sekretu. W tym pliku PEM leży pod `secret/identity/rsa`, a bootstrap czyta
  `secret/identity/owner-email` i `secret/identity/owner-initial-password`. Nie bierzemy stąd
  katalogu użytkowników: konta nie są wpisami KV. Token deweloperski zostaje w user secrets.
  vTPM i krótkotrwałe poświadczenie bazy są w `docs/cicd/14-openbao.md`.
- [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457). Wiążący jest kształt Problem Details. W
  tym pliku pole `type` jest kodem, na przykład `account.credentials.invalid`, a `title` jest
  zdaniem z zasobów `pl` albo `en` według `Accept-Language`. Nie bierzemy stąd dowolnego URI w
  `type` ani treści wyjątku w ciele odpowiedzi.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Eric Evans: wiążąca jest granica
  spójności agregatu. W tym pliku agregatami są `Account` i `StudentInvite`, `InviteCode` jest
  value objectem, a `DisplayName` jest polem konta, nie drugim agregatem. Nie bierzemy stąd
  jednego modelu na cały produkt ani współdzielenia klas Core między usługami.
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning). Greg Young: wiążące
  jest to, że nazwa zdarzenia i kształt ładunku są kontraktem, a nowe znaczenie dostaje nową
  wersję w nazwie. W tym pliku `[EventName("identity.user-registered.v1")]` i fakty domenowe z
  sufiksem `.v1` idą do strumienia albo outboxa, a nazwa CLR nie wchodzi do kolumny typu. Nie
  bierzemy stąd osobnego rejestru schematów poza atrybutem i rekordem w `Identity.Contracts`.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Chris Richardson: wiążące jest to, że usługa nie czyta cudzej bazy. W tym pliku
  `identity_write` i `identity_read` są osobnymi connection stringami, e-mail nie jest kluczem
  obcym u sąsiada, a pięć usług odrzuca token bez otwierania zapisu Identity. Nie bierzemy stąd
  wspólnej tabeli użytkowników ani jednej bazy z dwoma schematami na jednym connection stringu.

## Gotowe gdy

- Sześć projektów Identity jest w solution, a `Identity.Core` ma jedną referencję projektową:
  `JJDevHub.Shared.Kernel`.
- Rejestracja kodem zaproszenia tworzy `Account` z rolą `student` i `IdentityGuid` w `sub`.
- Konto `owner` powstaje wyłącznie z bootstrapu OpenBao i tylko wtedy, gdy strumienia jeszcze
  nie ma.
- `DisplayName` zmienia się na tym samym strumieniu co skrót hasła.
- `GET /.well-known/jwks.json` nie zawiera składnika prywatnego, a test sąsiada nie rejestruje
  klucza podpisu.
- Outbox po rejestracji ma typ `identity.user-registered.v1`. Outbox po wylogowaniu ma
  `identity.session-ended.v1` z `sessionId`.
- `identity_read` nie ma kolumny skrótu hasła ani kodu zaproszenia.
- `PUT` bez `If-Match` zwraca 428, ze starym znacznikiem 412.
- Testy jednostkowe Identity przechodzą filtrem `Category!=Integration&Category!=Performance`.
- W repozytorium nie ma PEM klucza ani hasła bootstrapu. `git grep` po materiale klucza
  prywatnego w `src/services/Identity` nic nie zwraca.
- Tag `identity-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job
  podmienia tylko Deployment `identity`.
