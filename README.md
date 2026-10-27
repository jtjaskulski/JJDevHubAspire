# JJDevHub

JJDevHub jest stroną CV i kompendium kursów. Właściciel edytuje treść. Studenci czytają lekcje i piszą do właściciela. Rekruter albo pracodawca czyta publiczne CV i wysyła osobne zapytanie. Ta sama treść idzie do przeglądarki i na telefon. Wygląd obu klientów bierze się z jednego zestawu tokenów. Język interfejsu i język treści da się zmienić bez przebudowy schematu bazy.

System stoi na .NET Aspire. Redis jest w składzie od pierwszego numeru i służy jako cache. Pięć usług ma własne bazy. Między usługami jedzie zdarzenie przez Kafkę. Sekret nie wchodzi do repozytorium.

Ten plik jest mapą. Kroki wdrożenia są w [docs/api](docs/api/README.md), [docs/cicd](docs/cicd/README.md) i [docs/frontend](docs/frontend/README.md). Kolejność pracy jest na końcu tego pliku i powtórzona w [docs/README.md](docs/README.md).

## Po co

Jedna osoba utrzymuje produkt, który ma wyglądać jak praca zespołu: granice usług, testy, bramki jakości i osobne wydania. Czytelnik CV ma zobaczyć decyzje, a nie stos narzędzi bez powodu.

Cztery rzeczy mają być prawdziwe naraz.

- Treść CV, kursu i notatki da się zmienić z intranetu, bez nowego wdrożenia samego tekstu.
- Kurs da się podpiąć pod umiejętność w CV slugiem technologii.
- Student i rekruter dostają osobną ścieżkę kontaktu, a właściciel na telefonie dostaje osobne powiadomienie z każdej.
- Zmiana w jednej usłudze dostaje własny numer wersji i własny obraz. Reszta usług zostaje na poprzednim tagu.

## Usługi

| Usługa | Co trzyma | Kto pisze | Kto czyta |
| --- | --- | --- | --- |
| Identity | konto, role `owner` i `student`, zaproszenie, klucz JWT | właściciel i rejestracja studenta | każda usługa waliduje token |
| News | notatka w Markdown, status publikacji, slug lekcji | `owner` | publicznie albo według widoczności |
| Learning | kategoria, technologia, kurs, lekcja, postęp studenta | `owner` | publicznie, studenci, właściciel |
| Cv | profil, stanowisko, projekt, edukacja, aktywność, umiejętność, język | `owner` | publiczny odczyt |
| Contact | zapytanie studenta i zapytanie rekrutera, token telefonu właściciela | student albo formularz publiczny | `owner` |

Gateway YARP jest przed usługami. Nie ma własnej domeny. Rozkłada ruch, sprawdza JWT kluczem publicznym i wystawia `GET /versions`.

Umiejętność w CV wskazuje technologię Learning slugiem, który się nie zmienia. News może wskazać lekcję tym samym sposobem. Usługa nie sprawdza sluga w bazie sąsiada. Jeśli cel zniknie, link zostaje faktem historycznym, a widok pokazuje brak celu.

## Reguła zależności

Każda usługa z domeną ma sześć projektów.

| Projekt | Zna | Nie zna |
| --- | --- | --- |
| `Core` | `JJDevHub.Shared.Kernel` | MediatR, EF, Kafka, ASP.NET, Mongo, Redis |
| `Application` | `Core`, porty, własny mediator | konkretnej bazy i brokera |
| `Api` | skład hosta | reguł domeny wpisanych w endpoint |
| `Persistence` | porty zapisu i odczytu | cudzej bazy |
| `Infrastructure` | porty cache, szyny, sekretów, push | agregatu sąsiada |
| `Contracts` | rekordy zdarzeń integracyjnych | handlerów |

`JJDevHub.Shared.Kernel` trzyma `Result<T>`, kody błędów, `Entity`, `ValueObject` i zegar. Nie ma w nim typu `Article`, `Account`, `Lesson`, `Profile` ani `StudentInquiry`.

Strzałka zależności idzie do środka. `Core` nie referencjonuje `Application`. `Application` nie referencjonuje `Persistence`. `Api` jest jedynym miejscem z `Program.cs` i składa implementacje portów.

Mediator, magazyn zdarzeń i outbox są w tym repozytorium. MediatR od wersji 13, AutoMapper od wersji 15, MassTransit od wersji 9 i Duende IdentityServer odpadają, bo ich wolna licencja produkcyjna jest warunkowa albo płatna. Pakiet wolno dodać, gdy licencja jest otwarta i darmowa także produkcyjnie: MIT, Apache 2.0, BSD, PostgreSQL. Wersja idzie do `Directory.Packages.props`.

Zasady C# są w [.cursor/rules/csharp.mdc](.cursor/rules/csharp.mdc): jeden publiczny typ na plik, klasa `sealed`, rekord dla danych, oczekiwany błąd jako `Result<T>`, `CancellationToken` w metodzie `async`.

## Dane

Jeden serwer PostgreSQL w AppHost. Na nim dziesięć baz. Usługa dostaje tylko swoje dwa connection stringi.

| Zapis | Odczyt | Co leży w zapisie | Co leży w odczycie |
| --- | --- | --- | --- |
| `identity_write` | `identity_read` | strumień konta i zaproszenia, outbox | skrót konta i zaproszenia |
| `news_write` | `news_read` | strumień artykułu, outbox | lista i treść notatki |
| `learning_write` | `learning_read` | strumienie treści, postęp, outbox | katalog, lekcja, postęp |
| `cv_write` | `cv_read` | strumienie sekcji CV, outbox | złożony widok strony |
| `contact_write` | `contact_read` | dwa rodzaje zapytań, tokeny urządzeń, outbox | dwie listy dla ownera |

Zapis i odczyt są osobnymi bazami, nie dwoma schematami w jednej. Handler komendy nie otwiera bazy odczytu. Handler zapytania nie woła magazynu zdarzeń. Projekcja jest asynchroniczna: po `POST` klient może przez chwilę dostać `404` i ponawia odczyt.

Odczyt jest szybki, bo wiersz albo dokument JSONB jest już złożony pod slug, kategorię i język. Indeks pokrywa to zapytanie. Strumienia nikt nie odtwarza na ścieżce HTTP.

Redis trzyma gorące projekcje: publiczne CV i katalog kursów. Klucz zaczyna się od nazwy usługi. Limit zapytań i krótkie blokady też idą przez Redis. Utrata Redisa spowalnia odczyt. Dane zostają w PostgreSQL.

MongoDB nie wchodzi. Drugi silnik i licencja SSPL nie przyspieszają odczytu po slugu wobec indeksowanej projekcji. OpenSearch nie wchodzi: to silnik wyszukiwania, a strona woła dokument po slugu i listę kategorii.

## Szyna

Kafka w trybie KRaft, jeden broker w AppHost i na maszynie. Nazwa zdarzenia jest stabilna, na przykład `news.article-created.v1`. Nazwa typu CLR nie wchodzi do bazy ani na szynę.

Temat należy do jednej usługi. `learning.integration` jest kompaktowany, więc Cv czyta ostatni stan technologii i kursu. `contact.integration` niesie dwa różne fakty: `contact.student-inquiry-received.v1` i `contact.recruiter-inquiry-received.v1`. Konsument Contact wysyła z nich dwa różne pushe. Inbox zapisuje identyfikator wiadomości, więc drugi pod nie wyśle powiadomienia drugi raz.

Outbox leży w tej samej transakcji co strumień. Zdarzenie domenowe nie opuszcza usługi. Na szynę wychodzi rekord z `Contracts`.

RabbitMQ nie wchodzi. Przy przenoszeniu stanu kompaktowanie tematu jest prostsze niż samo republish. Redis Streams nie wchodzą, bo cache i szyna nie mogą paść razem. eShop zostaje wzorem granic usług, własnej bazy, outboxa, Aspire i gatewaya. Brokerem jest Kafka.

## Contact

`StudentInquiry` powstaje tylko z tokenem roli `student`. `RecruiterInquiry` powstaje z publicznego formularza, bez konta. Formularz publiczny zawsze tworzy zapytanie rekrutera. Owner czyta dwie listy.

Telefon rejestruje urządzenie w Contact tylko na czas sesji `owner`. Wylogowanie kasuje token urządzenia. Dwa kanały systemu, studenci i rekruterzy, mają inny tytuł i otwierają inną skrzynkę. Wysyłka idzie przez FCM HTTP v1, także na APNs. Klucz leży w OpenBao.

## Sekrety

OpenBao (MPL 2.0) trzyma sekrety. HashiCorp Vault odpada przez licencję BSL. Keycloak odpada, bo konta i role są usługą Identity.

W repozytorium nie ma wartości sekretu i nie ma pliku z zaszyfrowanym sekretem. Lokalnie token deweloperski OpenBao siedzi w user secrets. Na maszynie klucz rozszczelnienia jest w vTPM, a usługa dostaje krótkotrwałe poświadczenie bazy.

## Klienci

Web to React 19, Vite, TypeScript, Tailwind CSS v4 i shadcn. Telefon to React Native, NativeWind i Reanimated. Tokeny kolorów, odstępów i czasów są w jednym pliku. Oba klienty używają tych samych kluczy i18n dla chromu. Treść strony przychodzi z API jako mapa kultur. Na start są `pl` i `en`. Dodanie języka jest danymi, nie migracją kolumn.

Intranet jest trasami `owner` w webie: CV, notatki, kursy i dwie skrzynki Contact. Formularz rekrutera jest publiczny. Formularz studenta jest w strefie studenta i na telefonie.

## Wersja na ekranie

Każdy komponent ma SemVer i tag `<komponent>-vX.Y.Z`. Komponenty: `identity`, `news`, `learning`, `cv`, `contact`, `gateway`, `web`, `mobile`.

Web pokazuje `web-vX.Y.Z` w stopce. Telefon pokazuje `mobile-vX.Y.Z` na ekranie O aplikacji. Oba wołają `GET /versions` i pokazują numer działającej Identity, News, Learning, Cv, Contact i gatewaya.

Zmiana w `JJDevHub.Shared.Kernel` podbija każdą usługę, która go referencjonuje. Tag `news-v1.4.0` nie przebudowuje pozostałych obrazów.

## Git

Długie gałęzie to `develop`, `release` i `main`. Gałąź robocza wychodzi tylko z `develop`. Prefiksy: `feature/`, `fix/`, `docs/`, `chore/`, `ci/`, `refactor/`, `test/`, dalej kebab-case, na przykład `feature/lesson-markdown`.

Tytuł pull requestu jest Conventional Commits. `feat` i `fix` mają zakres z listy komponentów, na przykład `feat(news): publish article revision`. Wejście na `develop` jest squashem, więc commit na `develop` ma treść tytułu. Promocja `develop` → `release` i `release` → `main` jest merge commitem. Gałąź robocza, która została w tyle, jest rebase'owana na `develop`. Job `branch-name` odrzuca złą gałąź. Job `pr-title` odrzuca zły tytuł.

`develop` przyjmuje zmianę po testach jednostkowych i bramce pierwszej. `release` przyjmuje ją po bramce drugiej. `main` przyjmuje ją po bramce trzeciej. Na `main` leżą tylko zmiany, które przeszły pełny ciąg. Deploy na maszynę dochodzi na końcu, z już nadanego tagu. Ratunek to poprzedni tag tego komponentu.

## Bramki

Bramki działają od pierwszego pull requestu, dla komponentów dotkniętych zmianą.

| Gałąź | Checki |
| --- | --- |
| `develop` | build, testy jednostkowe, format, gitleaks, podatności zależności, `branch-name`, `pr-title` |
| `release` | testy integracyjne, CodeQL, SonarQube, skan obrazu gdy jest Dockerfile |
| `main` | testy wydajności NBomber, SBOM, atestacje, tag zmienionych komponentów |

Skan obrazu, SBOM i atestacja są w tych samych workflowach. Zaczynają obowiązywać, gdy komponent dostaje Dockerfile. Serwer Sonara na czas developmentu to jeden kontener. Docelowe miejsce na maszynie opisuje numer Proxmox. Bramka w tym czasie zostaje włączona.

Job pull requestu idzie na `ubuntu-latest`. Runner własny nie startuje na pull requeście. Akcje w `uses:` są przypięte do pełnego SHA.

## Środowiska

| Środowisko | Skład | Sekrety | Telemetria |
| --- | --- | --- | --- |
| dev | `aspire run`: Postgres, Redis, Kafka, OpenBao, usługi, web | user secrets | dashboard Aspire |
| CI | pull request na `ubuntu-latest`, Testcontainers | brak sekretów aplikacji | brak |
| VM | k3s, jedna maszyna, obrazy z tagów | OpenBao, vTPM | Prometheus, Jaeger, Grafana |

Lokalnie Aspire trzyma jedną replikę. Na maszynie HPA podnosi drugi pod tej samej usługi, gdy CPU albo liczba żądań przekroczy próg. Kubernetes Service rozkłada żądania. YARP jest jedyną bramą HTTP aplikacji. Cloudflare, DNS i tunel, kończy się na YARP. Drugi konsument szyny nie stosuje zdarzenia drugi raz, bo inbox pamięta identyfikator.

Maszyna stoi na Proxmoxie. Publiczna chmura nie jest celem tego ciągu.

## Układ katalogów

Docelowe drzewo, do którego prowadzą numery:

| Ścieżka | Co tam leży |
| --- | --- |
| `JJDevHub.AppHost` | skład Aspire |
| `JJDevHub.ServiceDefaults` | telemetria, health, odkrywanie usług, polityki JWT |
| `src/shared/JJDevHub.Shared.Kernel` | `Result`, kody, `Entity`, `ValueObject` |
| `src/shared/JJDevHub.Cqrs` | mediator i zachowania |
| `src/shared/JJDevHub.EventStore` | port magazynu i pamięć |
| `src/shared/JJDevHub.EventStore.Postgres` | strumień w bazie zapisu |
| `src/shared/JJDevHub.Projections` | checkpoint i worker |
| `src/shared/JJDevHub.EventBus` | koperta, outbox port, inbox port |
| `src/shared/JJDevHub.IntegrationEventLog` | tabele outbox i inbox |
| `src/shared/JJDevHub.EventBus.Kafka` | adapter Kafki |
| `src/services/<Usługa>/<Usługa>.Core` | agregaty |
| `src/services/<Usługa>/<Usługa>.Application` | komendy, zapytania, porty |
| `src/services/<Usługa>/<Usługa>.Persistence` | konteksty zapisu i odczytu |
| `src/services/<Usługa>/<Usługa>.Infrastructure` | Redis, Kafka, OpenBao, FCM |
| `src/services/<Usługa>/<Usługa>.Api` | endpointy |
| `src/services/<Usługa>/<Usługa>.Contracts` | zdarzenia integracyjne |
| `src/gateway/JJDevHub.Gateway` | YARP |
| `src/clients/shared/theme` | tokeny |
| `src/clients/web` | React |
| `src/clients/mobile` | React Native |
| `docs/api` | numery `01`–`22` |
| `docs/cicd` | numery `01`–`16` |
| `docs/frontend` | numery `01`–`08` |

Agregat nie nazywa się jak segment namespace. Usługa News ma agregat `Article`. Usługa Cv nie ma klasy `Cv`. Usługa Contact ma `StudentInquiry` i `RecruiterInquiry`.

Event sourcing mają: artykuł, konto, zaproszenie, technologia, kurs, lekcja, sekcje CV, oba zapytania. Postęp studenta i przykład kodu wewnątrz lekcji są zwykłym stanem.

Oczekiwany błąd to `Result<T>` z kodem. Wyjątek zostaje dla awarii IO i błędu składu hosta. Oba kończą się jako `ProblemDetails` w języku z `Accept-Language`.

## Gdzie czytać

1. Ten plik, żeby zobaczyć granice.
2. [docs/api/architektura.md](docs/api/architektura.md), żeby zobaczyć przepływ zapisu, odczytu i pusha.
3. [docs/api/README.md](docs/api/README.md), żeby zobaczyć słownik i pakiety.
4. Numer, który jest następny w kolejności na dole. Jeden numer naraz.

## Kolejność

Najpierw powstają dokumenty. Potem praca, jeden numer naraz. Nie łącz numerów. Pierwsze siedem kroków stawia reguły gita i testy kodu. Zaraz potem stają pusta maszyna i tunel. Aspire, telemetria na VM, lokalne bazy i OpenBao na maszynie idą przed jądrem. Deploy bramy jest zaraz po `GET /versions`. Usługi wjeżdżają tagiem w miarę powstawania. Drugi pod jest po Contakcie, a przed piramidą testów. Frontend jest na końcu i nie stawia maszyny.

1. `docs/cicd/01-galezie.md` — gałęzie oraz checki nazw gałęzi i commitów.
2. `docs/cicd/02-bramki.md` — trzy bramki jako wymagane checki.
3. `docs/cicd/03-codeql.md` — skan kodu.
4. `docs/cicd/04-zaleznosci-i-obrazy.md` — podatności zależności i obrazów.
5. `docs/cicd/05-sonarqube.md` — jakość kodu.
6. `docs/cicd/06-lancuch-dostaw.md` — sekrety w diffie, akcje, Scorecard.
7. `docs/cicd/07-wersje.md` — osobny numer każdego komponentu.
8. `docs/cicd/08-proxmox.md` — pusta VM i k3s, repliki aplikacji na 0.
9. `docs/cicd/09-cloudflare.md` — DNS i tunel na Service `gateway`.
10. `docs/api/01-aspire.md` — host, Redis, telemetria.
11. `docs/cicd/10-opentelemetry.md` — collector na VM.
12. `docs/cicd/11-prometheus.md` — metryki na VM.
13. `docs/cicd/12-jaeger.md` — ślady na VM.
14. `docs/cicd/13-grafana.md` — tablice do metryk i śladów.
15. `docs/api/02-postgres.md` — pięć baz zapisu.
16. `docs/api/03-odczyt.md` — pięć baz odczytu.
17. `docs/api/04-openbao.md` — sekrety poza repo, lokalnie w AppHost.
18. `docs/cicd/14-openbao.md` — OpenBao na VM.
19. `docs/api/05-kernel.md` — `Result` i value object.
20. `docs/api/06-zdarzenie.md` — nazwa zdarzenia.
21. `docs/api/07-agregat.md` — agregat i reguły.
22. `docs/api/08-strumien.md` — magazyn w pamięci.
23. `docs/api/09-persistence.md` — magazyn w Postgresie.
24. `docs/api/10-cqrs.md` — mediator.
25. `docs/api/11-walidacja.md` — błędy w języku klienta.
26. `docs/api/12-projekcja.md` — zapis do bazy odczytu.
27. `docs/api/13-redis.md` — cache.
28. `docs/api/14-outbox.md` — outbox i inbox.
29. `docs/api/15-kafka.md` — szyna.
30. `docs/api/16-gateway.md` — YARP i `/versions`.
31. `docs/cicd/16-deploy.md` — pierwszy rollout bramy; ten sam job dla późniejszych tagów.
32. `docs/api/17-identity.md` — konta i role.
33. `docs/api/18-news.md` — notatki.
34. `docs/api/19-learning.md` — kursy i lekcje.
35. `docs/api/20-cv.md` — CV podpięte do technologii.
36. `docs/api/21-kontakt.md` — zapytanie studenta, zapytanie rekrutera, dwa pushe na telefon ownera.
37. `docs/cicd/15-skalowanie.md` — drugi pod przy obciążeniu.
38. `docs/api/22-testy.md` — domknięcie piramidy testów.
39. `docs/frontend/01-motyw.md`
40. `docs/frontend/02-web.md` — strona i numer wydania.
41. `docs/frontend/03-wyglad.md`
42. `docs/frontend/04-intranet.md`
43. `docs/frontend/05-tresc.md`
44. `docs/frontend/06-mobile.md` — telefon i ten sam sposób numerowania.
45. `docs/frontend/07-powiadomienia.md` — dwa kanały push, tylko przy zalogowanym ownerze.
46. `docs/frontend/08-ruch.md` — ostatni numer; obraz weba i telefonu wjeżdża jobem z `cicd/16`.
