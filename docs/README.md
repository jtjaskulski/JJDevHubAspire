# Dokumentacja

Ten folder jest specyfikacją JJDevHub. Kod usług, workflow i ekrany powstają stąd, numer po numerze. Obraz produktu, baz i bramek jest w [README.md](../README.md) w korzeniu repozytorium. Ten plik mówi, jak czytać trzy podfoldery i w jakiej kolejności brać numery.

Każdy plik jest po polsku. Numer opisuje system i kroki wdrożenia. Nie opisuje narzędzi, które ten plik napisały.

Skrót gałęzi i commita jest w [zasady-gita.md](zasady-gita.md), skrót bramek w [bramki.md](bramki.md), a checki nazwy i tytułu w [cicd/01-galezie.md](cicd/01-galezie.md).

## Trzy foldery

| Folder | Numery | Pytanie, na które odpowiada |
| --- | --- | --- |
| [api](api/README.md) | `01`–`22` | Jak usługa zapisuje stan, czyta projekcję i rozmawia z sąsiadem |
| [cicd](cicd/README.md) | `01`–`16` | Jak repozytorium broni się przed złym mergem i jak obraz trafia na maszynę |
| [frontend](frontend/README.md) | `01`–`08` | Jak web i telefon dzielą wygląd, język, treść i powiadomienia |

W każdym folderze jest własne `README.md`. Ono trzyma słownik, pakiety albo mapę ekranów tego folderu. Plik `architektura.md` w `api` nie jest numerem: nie ma w nim kroków do wykonania, jest przepływ między usługami.

## Jak czytać numer

Numer ma sekcje w tej kolejności.

| Sekcja | Co w niej jest |
| --- | --- |
| wstęp | co powstaje, link do numeru poprzedniego i następnego |
| `## Po co` | problem, który numer zamyka |
| `## Dlaczego ta technologia` | podsekcja na każdą decyzję: co to jest, jaki problem rozwiązuje, jakie alternatywy przegrały i jaki koszt zostaje |
| `## Klasy i ścieżki` | plik albo workflow i jego odpowiedzialność |
| `## Plan` | kroki `### 1.` i na końcu `### Co jest do czego` |
| `## Testy` | co ma być prawdą i jaką komendą to widać |
| `## Zasady` | reguły, których kod tego numeru nie łamie |
| `## Poza zakresem` | co jest w innym numerze, z linkiem |
| `## Źródła` | tytuł, adres i po co ten adres |
| `## Gotowe gdy` | warunki, ostatni da się sprawdzić komendą albo plikiem |

`## Dlaczego ta technologia` tłumaczy wybór, zanim powstanie kod. `## Plan` mówi, co zrobić, i nie powtarza uzasadnień. `### Co jest do czego` odpowiada na pytanie, po co klasa albo job w ogóle istnieje i kto go woła.

Jeden numer na jedno podejście. Nie łączy się dwóch numerów w jednym wdrożeniu. Numer jest gotowy, gdy sekcja `## Gotowe gdy` jest spełniona i testy tego numeru przechodzą.

## Dlaczego bramki są przed Aspire

Pierwsze siedem numerów leży w [cicd](cicd/README.md), nie w API. Repozytorium ma odrzucać złą gałąź, zły tytuł, czerwony test, sekret w diffie i znaną podatność, zanim powstanie pierwsza usługa. Późniejsze numery dokładają kod do już wymaganych checków. Check na początku bywa krótki, bo solution ma mało projektów, i jest wymagany tak samo jak później.

Tag komponentu powstaje w `cicd/07`, żeby `main` nie przyjmował zmiany bez numeru wersji. Zaraz potem stają pusta maszyna i tunel (`cicd/08`, `cicd/09`), jeszcze bez obrazu aplikacji. Telemetria na VM (`cicd/10`–`13`) czeka na `ServiceDefaults` z `api/01`. OpenBao na VM (`cicd/14`) czeka na lokalny OpenBao z `api/04`. Deploy (`cicd/16`) jest zaraz po bramie, nie po froncie. Drugi pod (`cicd/15`) jest po usługach i przed piramidą testów. Frontend nie stawia maszyny. Obraz weba i telefonu wjeżdża tym samym jobem, gdy te numery są gotowe.

## Słownik, który obowiązuje wszędzie

Nazwy poniżej są stałe. Numer nie wymyśla drugiej nazwy na ten sam byt.

| Nazwa | Znaczenie |
| --- | --- |
| `owner`, `student` | role w tokenie JWT |
| `JJDevHub.Shared.Kernel` | `Result<T>`, kody błędów, `Entity`, `ValueObject`; zero typów usług |
| `identity_write`, `identity_read` | bazy Identity |
| `news_write`, `news_read` | bazy News |
| `learning_write`, `learning_read` | bazy Learning |
| `cv_write`, `cv_read` | bazy Cv |
| `contact_write`, `contact_read` | bazy Contact |
| `StudentInquiry`, `RecruiterInquiry` | dwa agregaty Contact |
| `contact.student-inquiry-received.v1` | push kanału studentów |
| `contact.recruiter-inquiry-received.v1` | push kanału rekruterów |
| `GET /versions` | numery działających usług |
| `web-vX.Y.Z`, `mobile-vX.Y.Z` | wersja widoczna w kliencie |

Usługa nie otwiera bazy sąsiada. Między usługami idzie zdarzenie integracyjne przez Kafkę. Zdarzenie domenowe zostaje w procesie. Nazwa zdarzenia na szynie i w tabeli pochodzi z `[EventName]`, nie z nazwy klasy CLR.

Redis jest cachem. Prefiks klucza jest nazwą usługi. PostgreSQL jest źródłem stanu: baza zapisu trzyma strumień i outbox, baza odczytu trzyma projekcję.

## Licencje

Pakiet wolno dodać, gdy licencja jest otwarta i darmowa także produkcyjnie: MIT, Apache 2.0, BSD, PostgreSQL. MediatR od wersji 13, AutoMapper od wersji 15, MassTransit od wersji 9, Duende IdentityServer i QuestPDF nie wchodzą. Starej wersji nie przypina się tylko po to, żeby ominąć zmianę licencji.

Mediator, magazyn zdarzeń i outbox są w tym repozytorium, bo są treścią numerów, nie dlatego, że brakuje biblioteki na licencji MIT. OpenBao jest na MPL 2.0 i jest serwerem sekretów. HashiCorp Vault nie wchodzi. MongoDB nie wchodzi. RabbitMQ nie wchodzi.

Nowy pakiet dopisuje się do tabeli w [api/README.md](api/README.md) razem z numerem, w którym dochodzi. Wersja ląduje w `Directory.Packages.props`.

## Czego w tych plikach nie ma

- Wartości sekretu, tokenu, hasła i connection stringa z produkcyjnym hasłem.
- Opisu chmury publicznej jako celu wdrożenia. Cel runtime to jedna maszyna na Proxmoxie i DNS w Cloudflare.
- Osobnej usługi powiadomień. Push jest adapterem Contact.
- Wyszukiwania wektorowego i sagi między usługami.

## Jak sprawdzić, że numer jest spójny z resztą

Przed zamknięciem numeru warto przejść krótką listę. Nie zastępuje ona sekcji `## Gotowe gdy`, tylko pilnuje granic.

- Nazwy klas są takie jak w [api/README.md](api/README.md).
- Nowa baza jest dopisana do tabeli baz albo numer jej nie dodaje.
- Nowy pakiet ma licencję z listy dozwolonych i wiersz w tabeli pakietów.
- Test z tego numeru ma jeden powód do padnięcia.
- Sekret, jeśli numer go potrzebuje, jest czytany z OpenBao albo z user secrets, nie z pliku w gicie.
- Zdarzenie integracyjne ma nazwę `segment.fakt.v1`.
- Usługa z tego numeru nie dostaje connection stringa do bazy innej usługi.

Gdy numer dotyka klienta, wersja na ekranie zostaje. Web nie traci stopki `web-vX.Y.Z`. Telefon nie traci ekranu O aplikacji z `mobile-vX.Y.Z`.

## Testy w numerze

Każdy numer, który dokłada kod, dokłada test. Test ma jeden powód do padnięcia: arrange, act, assert. Nazwa metody mówi, co jest prawdą, gdy test przechodzi, na przykład `Create_blank_title_returns_invalid`.

Piramida jest jedna dla całego repozytorium, a numery dokładają do niej piętra.

| Piętro | Gdzie stoi | Kiedy leci w CI |
| --- | --- | --- |
| jednostkowy | `Core` i `Application`, bez bazy | `develop`, `release`, `main` |
| integracyjny | Testcontainers: PostgreSQL, Kafka, Redis | `develop`, `release`, `main` |
| wydajnościowy | NBomber, cecha `Category=Performance` | `develop`, `release`, `main` |

Trzy piętra blokują pull request do `develop` i powtarzają się przy promocji. Filtr lokalny bez kontenerów i bez NBombera to `--filter "Category!=Integration&Category!=Performance"`. To jest filtr joba `unit-tests`, nie jedyny przebieg na `develop`.

Runner to xUnit i `[Fact]`. Kontener Postgresa w teście to obraz `postgres:16-alpine`, dopóki numer nie powie inaczej. Kafka w teście idzie przez `Testcontainers.Kafka` w trybie KRaft.

## Środowiska, o których mówią numery

Numer nie zakłada trzech różnych architektur. Zakłada jeden model i trzy miejsca, w których ten model stoi.

W developmentcie `aspire run` stawia Postgresa, Redisa, Kafkę, OpenBao i projekty. Dashboard Aspire zbiera logi, ślady i metryki. AppHost nie jedzie na produkcję.

W CI pull request idzie na `ubuntu-latest`. Nie ma sekretu aplikacji. Test, który potrzebuje bazy, podnosi kontener sam.

Na maszynie jest k3s. Obraz wchodzi tylko z tagu komponentu. HPA może podnieść drugi pod. YARP jest jedyną bramą HTTP aplikacji. Cloudflare kończy tunel na tej bramie.

## Warstwy, które numer ma uszanować

Usługa z domeną ma projekty `Api`, `Application`, `Core`, `Persistence`, `Infrastructure` i `Contracts`. `Core` nie referencjonuje MediatR, Entity Framework, Kafki ani ASP.NET. `Application` zna `Core` i porty. `Api` składa hosta w `Program.cs`. `Persistence` i `Infrastructure` implementują porty. `Contracts` trzyma rekordy zdarzeń integracyjnych i wolno go referencjonować z innej usługi. Reszty sąsiada referencjonować nie wolno.

`JJDevHub.Shared.Kernel` nie zna Identity, News, Learning, Cv ani Contact. Agregat nie nazywa się jak segment namespace: usługa News ma klasę `Article`, usługa Cv nie ma klasy `Cv`.

Event sourcing jest tam, gdzie historia jest produktem: artykuł, konto, zaproszenie, technologia, kurs, lekcja, sekcje CV, oba zapytania Contact. Postęp studenta i przykład kodu w lekcji są zwykłym stanem, bez własnego strumienia.

## Język błędów i język treści

Treść kursu, notatki i CV jest mapą kultur na tekst. Na start są `pl` i `en`. Nowa kultura nie dokłada kolumny.

Błąd oczekiwany to `Result<T>` z kodem. Komunikat powstaje na brzegu HTTP z `Accept-Language`. Wyjątek IO i błąd składu hosta przechodzą przez ten sam słownik kodów i też wracają jako `ProblemDetails`. Walidacja FluentValidation nie rzuca wyjątku do klienta. Zamienia się na `Result` z kodem `Invalid`.

Zapis z `ETag` wymaga `If-Match`. Brak nagłówka to `428`. Nieaktualny znacznik to `412`. Treść niewidoczna dla czytelnika to `404`.

Kod błędu jest stabilny (`article.title.blank`, `inquiry.student.forbidden`). Tłumaczenie siedzi w zasobach `pl` i `en` przy hoście API. Dodanie języka interfejsu dokłada plik zasobów, nie zmianę kontraktu JSON. Pole `title` w `ProblemDetails` jest przetłumaczone. Pole `type` zostaje kodem, żeby klient mógł rozgałęzić logikę bez porównywania zdań.

Markdown lekcji i notatki jest przechowywany w bazie, nie w repozytorium treści. Blok kodu jest częścią tego Markdownu. Render na HTML przechodzi przez sanitację. Surowy HTML od autora nie wchodzi do odpowiedzi.

Link między usługami jest slugiem. Identyfikator z cudzej bazy nie wchodzi do zdarzenia integracyjnego ani do treści. Slug technologii nie zmienia się po publikacji. Zmiana nazwy wyświetlanej nie zmienia adresu kursu. Cv trzyma kopię ostatniego stanu z `learning.integration` i nie woła Learning po HTTP, żeby złożyć stronę.

Właściciel widzi numer wersji klienta. Student i rekruter też go widzą, w stopce albo na ekranie O aplikacji. Numer usługi widzą po `GET /versions`, obok numeru klienta, żeby dało się powiedzieć, który obraz odpowiada za treść na ekranie.

Katalog `docs` nie trzyma sekretów, zrzutów baz ani wygenerowanego klienta OpenAPI. Wygenerowany klient powstaje w `src/clients` w numerze frontendu i jest kodem, nie specyfikacją. Specyfikacja mówi, skąd się bierze i czego nie wolno w niej poprawiać ręcznie.

Gdy dwa numery mówią co innego o tej samej nazwie, wygrywa słownik w [api/README.md](api/README.md), a ten plik i README w korzeniu mają zostać poprawione w tym samym podejściu. Nazwa zdarzenia, bazy i roli nie ma synonimu.

Numer `09`–`16` w [api](api/README.md) domyka zapis, mediator, walidację, projekcję, cache, outbox, Kafkę i bramę. Usługi Identity, News, Learning, Cv i Contact stoją na tym fundamencie, nie obok niego.

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
