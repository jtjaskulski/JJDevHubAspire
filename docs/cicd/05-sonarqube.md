# 05. SonarQube

[Spis CI/CD](README.md) · poprzedni: [04. Zależności i obrazy](04-zaleznosci-i-obrazy.md) ·
następny: [06. Łańcuch dostaw](06-lancuch-dostaw.md)

Ten numer stawia bramkę jakości SonarQube jako job `sonarqube`. Job jest wymagany na pull
request do `develop`, `release` i `main`, od pierwszego takiego pull requestu, także zanim
powstanie usługa. Poprzedni numer, [zależności i obrazy](04-zaleznosci-i-obrazy.md), pilnuje CVE
bibliotek i obrazów. Następny, [łańcuch dostaw](06-lancuch-dostaw.md), przypina akcje i
zatrzymuje sekret w drzewie. Tutaj serwer na czas developmentu to jeden kontener Community
Build. Docelowe miejsce tego kontenera na maszynie opisuje [08-proxmox.md](08-proxmox.md).
Po przeniesieniu bramka zostaje włączona. Nie ma okresu, w którym check jest zdjęty, bo
serwer się przeprowadza.

CodeQL zostaje przy przepływie danych i progu `7.0`. Ten numer pilnuje nowych blockerów,
nowych podatności krytycznych, przeglądu hotspotów bezpieczeństwa, gęstości duplikacji i
pokrycia nowego kodu. Agregatu `Article`, konta i roli ten plik nie definiuje. Mierzy kod,
który kiedyś te typy zapisze, i workflow, który powstaje wcześniej.

Scenariusz, który bez tej bramki przechodzi cicho, zaczyna się od pierwszego pull requestu
News na `develop`. Tytuł to `feat(news): publish article revision`. Test jednostkowy
sprawdza, że slug artykułu da się zapisać. Gałąź, która odrzuca pusty tytuł, nie jest
wykonana. Pokrycie nowego kodu zostaje przy czterdziestu procentach. Obok, w Cv, ktoś
wkleił dwadzieścia linii tej samej kontroli sluga, żeby strona CV weryfikowała tak samo. W
helperze testu Identity został ciąg, który skaner oznacza jako hotspot bezpieczeństwa, i
nikt go nie przejrzał. CodeQL nie jest tu po to, żeby zatrzymać ten hotspot, tę kopię i ten
brak pokrycia. Bez joba `sonarqube` pull request do `develop` jest zielony. Test z
[02-bramki.md](02-bramki.md) mówi, że zachowanie jest prawdziwe. Nie mówi, że nowy kod jest
pokryty, że nie doszła kopia i że nie został otwarty blocker. `develop` przyjmuje dług, a
[07-wersje.md](07-wersje.md) później nadaje mu tag `news-v0.2.0`. Tag i dług jadą razem.

Drugi scenariusz jest wcześniejszy niż pierwsza usługa. Repozytorium nie ma jeszcze katalogu
`src`. Pierwszy pull request do `develop` niesie workflow i dokumentację. Gdyby job
znikał, bo nie ma czego analizować, ruleset nie zobaczyłby checka `sonarqube` i promocja
padłaby brakiem checka, a nie werdyktem jakości. Job ma wtedy skończyć się sukcesem i logiem
`no material for sonarqube`. Check zostaje w rulesecie. Zielony check przed pierwszym
plikiem `cs` jest umową tego numeru. Pusty przebieg nie jest wyłączeniem bramki.

Trzeci scenariusz dzieje się na laptopie osoby, która pisze Contact. Kontener stoi na
`127.0.0.1:9000`. W interfejsie da się obniżyć próg pokrycia, żeby szkic zapytania studenta
przeszedł lokalnie. Ten klik nie jest bramką CI. Następny przebieg wgrywa
`.github/sonar/quality-gate.json` i nadpisuje próg nazwą `jjdevhub`. Werdykt z laptopa nie
zastępuje checka. Laptop może być wyłączony w chwili, gdy runner liczy promocję Learning
albo Cv. Wspólna instancja „deweloperska” w sieci, do której workflow loguje się tokenem z
sekretów GitHuba, miałaby ten sam problem wcześniej: token byłby sekretem w CI przed numerem
[14-openbao.md](14-openbao.md).

Czwarty scenariusz to przeprowadzka na VM. Numer `08` postawi ten sam wariant Community
Build na maszynie `jjdevhub`. Adres serwera się zmieni. Warunki w JSON, nazwa checka i
`sonar.qualitygate.wait` zostaną. Gdyby na czas przeprowadzki check zdjąć, pierwszy tag po
starcie poda nie miałby za sobą tej bramki. Przeniesienie jest zmianą adresu. Job na
`ubuntu-latest` do czasu OpenBao nadal liczy werdykt na własnym kontenerze.

## Po co

Test z [02-bramki.md](02-bramki.md) mówi, że zachowanie jest prawdziwe. Nie mówi, że nowy
kod jest pokryty, że nie doszła kopia na dwadzieścia linii i że nie został otwarty blocker.
Bez bramki jakości `develop` przyjmuje dług techniczny, który później miesza się z tagiem.
News, Identity, Learning, Cv i Contact mają osobne tagi. Dług wpuszczony na `develop`
dostaje numer tego komponentu, którego ścieżka drgnęła, i zostaje w historii obrazu.
Cofnięcie progu po tagu nie cofa tagu.

Bramka nazywa się `jjdevhub` i jest zapisana w `.github/sonar/quality-gate.json`. Job wgrywa
ją do serwera na początku przebiegu. Werdykt kliknięty tylko w interfejsie Sonara nie
obowiązuje, bo następny przebieg nadpisze bramkę z pliku. Osoba, która na lokalnym
kontenerze poluzuje pokrycie „na czas szkicu”, nie zmienia rulesetu. Plik w gitcie jest
progiem. Interfejs jest podglądem ostatniego wgrania.

Warunki, wszystkie na nowym kodzie:

| Warunek | Próg |
| --- | --- |
| nowe naruszenia blocker | `0` |
| nowe naruszenia critical | `0` |
| przejrzane nowe hotspoty bezpieczeństwa | `100%` |
| gęstość zduplikowanych linii | co najwyżej `3%` |
| pokrycie | co najmniej `80%` |

Gdy analizator nie widzi nowych linii do pokrycia, warunek pokrycia jest spełniony. Tak jest
w repozytorium przed pierwszym plikiem źródłowym. Job wtedy kończy się sukcesem i logiem
`no material for sonarqube`. Ruleset i tak widzi check `sonarqube`. Puste drzewo `src` nie
jest powodem, żeby check zniknął z `develop.json`, `release.json` albo z `main.json`. Brak
checka i zielony check z jawnym logiem to dwa różne stany. Ten numer wybiera drugi.

Gdy linie już są, osiemdziesiąt procent pokrycia nowego kodu obowiązuje już na `develop`.
Test jednostkowy może przejść przy niskim pokryciu. `sonarqube` już nie. Szkic lekcji w
Learning nie wchodzi na `develop` z testem, który sprawdza jedną ścieżkę i zostawia
czterdzieści procent nowego kodu. Czerwony skaner jest na pierwszym pull requestcie, zanim
powstanie tag `learning-v0.2.0`.

Token serwera nie leży w gitcie. W YAML nie ma `secrets.SONAR_TOKEN` ani hasła. Na runnerze
job sam podnosi kontener, ustawia hasło administratora na wartość wylosowaną w pamięci
przebiegu i wyrzuca ją razem z runnerem. Losowanie to `openssl rand -base64 24`. Na
maszynie, po numerze `08` i [14-openbao.md](14-openbao.md), ten sam job czyta adres serwera
i token z OpenBao. Do tego czasu nie ma adresu produkcyjnego w pliku. Adres CI jest adresem
kontenera joba, `http://127.0.0.1:9000`, doklejonym przez workflow, nie wpisem w
`sonar-project.properties`.

SonarQube Community Build jest serwerem w kontenerze, nie pakietem referencjonowanym przez
usługę. Nie wchodzi do `Directory.Packages.props`. Pakiety aplikacji zostają przy licencjach
z dokumentacji produktu. Obraz serwera jest przypięty do skrótu, nie do tagu `latest`.
Podbicie obrazu jest zmianą skrótu w compose i w manifeście z numeru `08`, zwykłym pull
requestem, a nie cichą podmianą tagu na Docker Hubie między dwoma promocjami.

Check `sonarqube` dopisuje się do `develop.json`, `release.json` i `main.json`. Pokrycie
blokuje na trzech gałęziach. Job `unit-tests` nie woła Sonara i nie publikuje raportu
pokrycia między workflowami. Dlatego job `sonarqube` zbiera pokrycie sam, tym samym
filtrem.

Front wejdzie tym samym progiem. JavaScript i TypeScript w `src/clients` należą do projektu
`jjdevhub`. Drugi, łagodniejszy procent dla weba albo telefonu nie powstaje. Zanim katalog
klienta istnieje, brak pliku `lcov.info` niczego nie blokuje. Gdy katalog już jest w diffie,
a raportu nie ma, job nie udaje, że pokrycie frontu jest znane.

## Dlaczego ta technologia

### Community Build w jednym kontenerze

Obraz to wariant Community Build z oficjalnego obrazu `sonarqube`, przypięty skrótem w pliku
compose. W świeżym kontenerze projekt nazywa się `jjdevhub`. Jeden kontener jest serwerem i
na runnerze, i na czas developmentu na maszynie osoby. Usługa .NET go nie referencjonuje.
`PackageReference` do klienta Sonara nie wchodzi do `Directory.Packages.props`. Licencje
pakietów aplikacji zostają przy dokumentacji tych pakietów. Skrót obrazu jest w compose. Tag
`latest` nie jest.

Problem, który ten kontener zamyka, widać na pierwszym pull requestcie na `develop`. Blocker
na nowym kodzie News, krytyczna podatność w nowym kodzie Identity, nieprzejrzany hotspot,
kopia sluga między News a Cv powyżej trzech procent zduplikowanych linii i pokrycie nowego
kodu poniżej osiemdziesięciu procent mają paść skanerem. CodeQL przy progu `7.0` zostaje
przy przepływie danych. Nie liczy gęstości kopii i nie liczy pokrycia linii, których test
nie dotknął. Sam test jednostkowy też tego nie liczy. Bez kontenera i bez bramki
`develop` nie ma gdzie odłożyć tych pięciu warunków.

Świeży kontener na runnerze nie ma wczorajszego przebiegu. Cały analizowany wycinek jest dla
tej instancji nowym kodem. To jest surowsze niż przyrost na długo żyjącym serwerze i jest
akceptowalne na `develop`: wycinek, który wchodzi squashem, ma sam spełnić bramkę. Na VM
serwer będzie pamiętał historię. Warunki w JSON zostają te same. Zmienia się adres, nie próg. Historia na
VM nie jest pretekstem, żeby na czas pustego dysku zdjąć check. Dopóki adresu z OpenBao nie
ma, runner liczy werdykt u siebie.

Odpada edycja Developer, Enterprise i Data Center. Bramka tego numeru nie może wymagać
płatnej licencji, żeby pull request w ogóle był możliwy. Płatna edycja prowadzi analizę
gałęzi i dekorację pull requestu. Ten produkt ich nie potrzebuje do werdyktu. Job nie czeka
na gwiazdkę przy linijce w GitHubie. Czeka na `sonar.qualitygate.wait=true` i na kod wyjścia
skanera. Gwiazdka w interfejsie recenzji byłaby ozdobą. Ruleset czyta check, nie ozdobę.

Odpada SonarCloud jako jedyny serwer. Jest wygodny i dekoruje pull request, a wiąże werdykt
z organizacją w usłudze i z jej planem. Ten produkt trzyma bramkę u siebie, najpierw na
runnerze, potem na VM. Plan organizacji nie może być warunkiem scalenia. Adres
obcej usługi nie wchodzi do `sonar.host.url` w pliku, który commitujemy. Adres dokleja
workflow.

Odpada też sam `dotnet format` w roli bramki jakości. Format jest już checkiem `format` na
`develop`. Nie liczy pokrycia ani hotspotu. Zielony format i zielony test jednostkowy
potrafią puścić kopię dwudziestu linii i nieprzejrzany hotspot. Dlatego format zostaje tam,
gdzie jest, a ten numer dokłada osobny job na `develop`, `release` i `main`.

Koszt jest świadomy. Community Build nie prowadzi analizy gałęzi i dekoracji pull requestu
tak jak edycja płatna. Przebieg ściąga obraz. Job ma `timeout-minutes: 40`. Osoba
nie dostaje komentarza przy linii w GitHubie z tego serwera. Dostaje czerwony albo zielony
check. To wystarcza rulesetowi. Podbicie obrazu wymaga świadomej zmiany skrótu. `latest`
między dwoma poniedziałkami potrafiłby zmienić reguły skanera bez pull requestu.

### Bramka w pliku, nie w interfejsie

`quality-gate.json` jest źródłem warunków. Nazwa bramki w pliku to `jjdevhub`. Skrypt
`sonar-bootstrap.sh` woła API kontenera i tworzy albo podmienia bramkę, potem przypina ją do
projektu `jjdevhub`. Jednostki są takie, jakich oczekuje API Community Build (`LT`, `GT`,
`EQ`), wpisane przy każdym warunku, żeby bootstrap nie zgadywał. Pięć warunków z tabeli jest
w tym pliku. Job nie czyta progu z Markdownu i nie czyta go z kliknięcia, które zostało w
bazie kontenera po poprzedniej osobie.

Problem wychodzi przy dwóch kontenerach. Lokalny wolumen pamięta bramkę, którą ktoś
poluzował w czwartek. Runner w poniedziałek dostaje pusty kontener. Gdyby źródłem był
interfejs, te dwa miejsca miałyby dwa progi i check znaczyłby co innego niż ekran na
`127.0.0.1:9000`. Wgranie JSON na początku przebiegu zrówna oba. Osoba, która chce zobaczyć
ten sam próg co CI, uruchamia `sonar-local.sh`. Skrypt woła ten sam bootstrap i ten sam
plik. Ekran pokazuje `jjdevhub`, nie ręcznie nazwaną bramkę „tymczasowo 50%”.

Konkret JJDevHub jest tu liczbą, nie domeną. Pokrycie co najmniej `80%` dotyczy nowego kodu
News, Identity, Learning, Cv, Contact, bramy i klienta, gdy linie już są. Gęstość
zduplikowanych linii co najwyżej `3%` dotyczy kopii wklejonej między usługami. Nowe blockery
i nowe critical mają być `0`. Nowe hotspoty mają być przejrzane w `100%`. Treść reguły,
która mówi, czy tytuł artykułu może być pusty, należy do numerów `docs/api`. Ten numer tylko
nie pozwala, żeby ta reguła weszła na `release` bez pomiaru.

Odpada opis progu tylko w tym dokumencie. Job nie czyta Markdownu. Zmiana `80` na `70`
zapisana wyłącznie tutaj nie dotrze do API. Zmiana w JSON, bez opisu w tym pliku, dotrze i
będzie obowiązywać. Dlatego próg jest w obu miejscach, a wiążący dla joba jest JSON.
Dokument ma się z JSON zgadzać. Rozjazd łapie czytanie pliku, nie czytanie akapitu.

Odpada też osobna bramka na komponent. Osiem przyszłych tagów nie dostaje ośmiu progów.
Projekt skanera jest jeden, `jjdevhub`, i JSON jest jeden. Łagodniejszy próg dla
`src/clients` odpadł z tego samego powodu. Web i telefon, gdy powstaną, wchodzą w te same
pięć warunków. Inaczej promocja weba mogłaby nieść kopię, której promocja News już nie może
nieść.

Koszt: zmiana progu jest pull requestem do JSON i przechodzi zwykłe checki. O to chodzi.
Poluzowanie pokrycia na czas jednej promocji zostawia ślad w gitcie i przechodzi przez ten
sam ruleset, który ma check `sonarqube`. Nie da się go zrobić kliknięciem, które znika z
wolumenem runnera. Zaostrzenie też jest pull requestem. Bootstrap nie trzyma piątego warunku
„z pamięci kontenera”, którego w pliku nie ma.

### Skaner w CI i kontener deweloperski obok

Są dwa miejsca, jeden próg.

| Miejsce | Po co | Dane |
| --- | --- | --- |
| kontener w jobie `sonarqube` | werdykt, który czyta ruleset | puste na starcie przebiegu, kasowane z runnerem |
| `compose/sonarqube/compose.yml` | jeden kontener na maszynie osoby, ten sam JSON | wolumen lokalny, poza gitem |

Kontener joba żyje na sieci runnera. Port zostaje wewnątrz joba. Workflow dokleja
`sonar.host.url` jako `http://127.0.0.1:9000`. Plik `sonar-project.properties` tego adresu
nie ustawia, bo na VM adres będzie inny, a próg ma zostać ten sam.
`sonar.qualitygate.wait=true` i `sonar.qualitygate.timeout=300` są w pliku właściwości. Bez
czekania skaner potrafi skończyć się kodem `0`, zanim serwer policzy bramkę. Trzysta sekund
to limit czekania skanera na raport. Czterdzieści minut to limit całego joba. Sto
osiemdziesiąt sekund to limit, w którym `api/system/status` ma dojść do `UP`.

Compose dla developmentu publikuje port `9000` tylko na `127.0.0.1`. Nie publikuje portu na
`0.0.0.0`. Nie używa tagu `latest`. Nie montuje katalogu repozytorium do kontenera serwera.
Wolumen trzyma dane serwera i jest w `.gitignore`, jeśli katalog wolumenu leży w drzewie.
Lepiej trzymać go poza repozytorium, w ścieżce, którą wypisuje `sonar-local.sh`. Hasła
początkowego nie wpisuje się do pliku compose. Skrypt `sonar-local.sh` przy pierwszym
starcie losuje hasło, zapisuje je w user secrets albo w pliku wskazanym przez zmienną poza
repozytorium i drukuje ścieżkę, nie wartość, do logu. Powtórny start nie resetuje wolumenu.
`git status` nie pokazuje pliku z hasłem.

Job CI nie łączy się z kontenerem na laptopie. Laptop może być wyłączony. Werdykt z laptopa
nie zastępuje checka. Świeży kontener na runnerze nie potrzebuje niczego z zewnątrz poza
obrazem `sonarqube`. Hasło administratora powstaje w pamięci joba poleceniem
`openssl rand -base64 24` i nie wpada do logu. Token skanera, jeśli skaner go wymaga,
powstaje wywołaniem API w `sonar-bootstrap.sh` i trafia do deskryptora pliku przekazanego
skanerowi, nie do logu. Wokół tej linii jest `set +x`. Lepiej przekazać wartość zmienną,
której krok `run` nie echo.

Odpada wspólna instancja „deweloperska” w sieci, do której workflow loguje się tokenem
trzymanym w sekretach GitHuba. Taki token byłby sekretem w CI przed numerem `14`. W YAML
tego numeru nie ma `secrets.SONAR_TOKEN`. Adres produkcyjny nie stoi w pliku „na zapas”,
zanim OpenBao w ogóle jest. Do tego czasu runner jest samowystarczalny: obraz, JSON, losowe
hasło, skaner, kod wyjścia.

Odpada też zielony skip, gdy kontener nie wstał. Gotowość API ma własny limit `180` sekund,
po którym job pada z komunikatem, że kontener nie wstał. To nie jest sukces z logiem
`no material for sonarqube`. Log `no material` należy do drzewa bez źródeł. Pad startu
kontenera, gdy źródła już są, jest czerwoną komendą. Cisza po timeoutie udawałaby bramkę,
której nie było.

Koszt: przebieg `release` ściąga obraz i czeka, aż API odpowie. `timeout-minutes` joba to
`40`. Analiza dolicza się do czasu testu jednostkowego, który ten job i tak powtarza. Na
laptopie wolumen zostaje między startami, więc osoba nie traci projektu `jjdevhub` przy
drugim uruchomieniu `sonar-local.sh`. CI świadomie tego wolumenu nie ma. Każdy werdykt
rulesetu zaczyna od pustej instancji i od JSON z gita.

Na VM, gdy numer `08` poda adres, a numer `14` poda token, komentarz w `sonarqube.yml` nad
krokami kontenera mówi, że start kontenera wolno podmienić na adres serwera z OpenBao.
Podmiana nie usuwa kroku `sonar.qualitygate.wait` i nie usuwa nazwy checka. Jeśli numer `08`
jeszcze nie istnieje jako workflow, zostaje kontener na runnerze. Bramka się nie wyłącza „do
czasu VM”. Wartość tokenu nie wchodzi do `sonarqube.yml` i nie wchodzi do gita także po tej
podmianie.

### Pokrycie z tego samego testu co bramka `develop`

Skaner .NET dostaje raport pokrycia z `dotnet test` z filtrem jednostkowym, tym samym co job
`unit-tests`: `Category!=Integration&Category!=Performance`. Na pull request ten test
wykonuje się wewnątrz joba `sonarqube` jeszcze raz, z zbieraniem pokrycia, bo job
`unit-tests` nie publikuje raportu między workflowami. Skaner .NET idzie między początkiem a końcem analizy,
zgodnie z dokumentacją skanera dla tej wersji obrazu. Pokrycie z czerwonego testu nie jest
wysyłane.

Gdy nie ma `*.csproj`, test się nie uruchamia i cały job idzie ścieżką
`no material for sonarqube`. `sonar-material.sh` kończy się wtedy kodem `0` i tą linią, o
ile w `src` nie ma plików `*.cs`, `*.js`, `*.ts` ani `*.tsx`. Inaczej kod `0` i linia
`material`. Błąd użycia to kod `2`. Gdy jest projekt produkcyjny, a test jednostkowy pada,
`sonarqube` pada nawet przed bramką pokrycia. Nie ma sensu wysyłać pokrycia z czerwonego
testu i dyskutować, czy osiemdziesiąt procent liczy się z procesu, który nie doszedł do
końca.

Gdy analizator nie widzi nowych linii do pokrycia, warunek pokrycia jest spełniony. To jest
stan repozytorium przed pierwszym plikiem źródłowym i stan diffu, który rusza tylko katalogi
wykluczone. Wykluczenia w `sonar-project.properties` to `docs/**`, `versions/**`,
`**/bin/**`, `**/obj/**` i `**/*.Generated.cs`. Źródła to `src`, gdy katalog istnieje.
Dokumentacja i pliki wersji nie podbijają mianownika pokrycia. Wygenerowany plik też nie.
Powód wykluczenia siedzi w komentarzu przy wpisie. Samo wykluczenie bez powodu w komentarzu
nie należy do tego pliku.

JavaScript i TypeScript, gdy pojawią się w `src/clients`, wchodzą tym samym projektem
`jjdevhub` i tym samym progiem. Skaner CLI bierze `lcov`, jeśli klient już wytwarza
`lcov.info`. Gdy katalog klienta istnieje, a `lcov.info` nie, i w diffie są pliki `ts` albo
`tsx`, job pada kodem `1`: pokrycie frontu nie jest wtedy znane. Zanim katalog klienta
istnieje, brak `lcov` niczego nie blokuje. Telefon i web nie dostają drugiego JSON-a. Stopka
`web-vX.Y.Z` i ekran O aplikacji czytają numer wersji gdzie indziej. Tutaj czytają ten sam
procent pokrycia co usługa.

Odpada drugi, łagodniejszy próg dla frontu. Jeden JSON. Odpada też uznanie, że test na
`unit-tests` już „zaliczył pokrycie”, skoro workflow testu nie oddaje raportu. Job
`unit-tests` zostaje przy filtrze i przy braku progu procentowego. Procent jest tutaj, na
`develop`, `release` i `main`. Odpada wysłanie pokrycia, gdy filtr jednostkowy jest
czerwony. Czerwony test jest wcześniejszą porażką niż czerwona bramka.

Koszt: job `sonarqube` powtarza test jednostkowy. Trwa to tyle, co `unit-tests`, plus analiza.
Powtórzenie jest ceną za raport, którego sąsiedni workflow nie publikuje. Filtr zostaje ten
sam, więc integracja i test wydajnościowy nie wchodzą do mianownika. Cecha
`Category=Integration` albo `Category=Performance` na teście, który miał być jednostkowy,
wypadłaby z raportu i mogłaby sztucznie podnieść procent. Ten numer nie nadaje tych cech.
Pilnuje, żeby raport powstał z tego samego filtra co bramka `develop`.

## Klasy i ścieżki

| Ścieżka | Rola |
| --- | --- |
| `.github/workflows/sonarqube.yml` | job `sonarqube` |
| `.github/sonar/quality-gate.json` | warunki bramki `jjdevhub` |
| `.github/sonar/sonar-project.properties` | klucz projektu, wykluczenia, `sonar.qualitygate.wait=true` |
| `.github/scripts/sonar-bootstrap.sh` | wgranie bramki do API kontenera |
| `.github/scripts/sonar-material.sh` | decyzja, czy jest co analizować |
| `compose/sonarqube/compose.yml` | jeden kontener Community Build na czas developmentu |
| `.github/scripts/sonar-local.sh` | start lokalny bez hasła w gitcie |
| `.github/rulesets/release.json` | check `sonarqube` |
| `.github/rulesets/main.json` | ten sam check |

`sonar-project.properties` ustawia:

- `sonar.projectKey=jjdevhub`
- `sonar.qualitygate.wait=true`
- `sonar.qualitygate.timeout=300`
- wykluczenia `docs/**`, `versions/**`, `**/bin/**`, `**/obj/**`, `**/*.Generated.cs`
- źródła `src`, gdy katalog istnieje

Nie ustawia `sonar.host.url` na adres maszyny. Adres w CI dokleja workflow jako
`http://127.0.0.1:9000` kontenera joba. Adres na VM dopisze numer `08` przez zmienną
przebiegu czytaną z OpenBao, nie przez zmianę progu w tym pliku. Klucz projektu zostaje
`jjdevhub` po obu stronach. Nowa nazwa projektu przy przeprowadzce rozjechałaby historię,
którą VM ma zacząć pamiętać.

`sonar-material.sh` kończy się kodem `0` i linią `no material for sonarqube`, gdy nie ma
plików `*.cs`, `*.js`, `*.ts`, `*.tsx` w `src`. Inaczej kod `0` i linia `material`. Błąd
użycia to kod `2`. Skrypt nie startuje kontenera. Decyzja „czy jest co analizować” jest
tańsza niż ciągnięcie obrazu na dokumentacji.

Compose przypina obraz skrótem. Nie używa `latest`. Nie publikuje portu na `0.0.0.0`. Nie
montuje katalogu repozytorium do kontenera serwera. Wolumen trzyma dane serwera i jest w
`.gitignore`, jeśli katalog wolumenu leży w drzewie. Lepiej trzymać go poza repozytorium, w
ścieżce, którą wypisuje `sonar-local.sh`. Hasło do tego wolumenu nie jest w compose.

Job: `runs-on: ubuntu-latest`, `permissions: contents: read`, `timeout-minutes: 40`,
`persist-credentials: false`. Bez `pull_request_target`. Bez `paths`. Wyzwalacz:
`pull_request` na `develop`, `release` i `main`. Akcje checkout i ewentualny `setup-dotnet`
są przypięte do pełnego SHA. Check musi być zielony już na pierwszym pull requestcie do
`develop`.

`develop.json`, `release.json` i `main.json` zawierają nazwę checka `sonarqube`. Sync
rulesetów jest z numeru `01`. Ten numer tylko dopisuje nazwę w tym samym scaleniu, które
dodaje workflow. Check bez workflow albo workflow bez checka zostawia scalenie w stanie,
którego ruleset nie umie nazwać.

## Plan

### 1. Zapisać bramkę

Utwórz `quality-gate.json` z pięcioma warunkami z tabeli. Nazwa bramki w pliku to
`jjdevhub`. Jednostki są takie, jakich oczekuje API Community Build (`LT`, `GT`, `EQ`),
wpisane przy każdym warunku, żeby bootstrap nie zgadywał.

### 2. Dodać właściwości projektu

Utwórz `sonar-project.properties` polami z sekcji ścieżek. `sonar.qualitygate.wait=true`
jest obowiązkowe. Bez tego skaner potrafi skończyć się kodem `0`, zanim serwer policzy
bramkę. `sonar.qualitygate.timeout=300`. Klucz `jjdevhub`. Wykluczenia z listy.
`sonar.host.url` zostaw workflowowi.

### 3. Dodać bootstrap API

Utwórz `sonar-bootstrap.sh`. Czeka na `api/system/status` równe `UP`, najdłużej `180`
sekund. Zmienia hasło administratora z hasła początkowego obrazu na wartość ze zmiennej
środowiskowej joba, wylosowaną w poprzednim kroku (`openssl rand -base64 24`). Tworzy
projekt `jjdevhub`, jeśli go nie ma. Wysyła bramkę z JSON. Przypina ją do projektu. Nie
wypisuje hasła ani tokenu. Token skanera, jeśli skaner go wymaga, powstaje wywołaniem API w
tym samym skrypcie i trafia do deskryptora pliku przekazanego skanerowi, nie do logu
(`set +x` wokół tej linii, a lepiej przekaż przez zmienną, której krok `run` nie echo).

### 4. Dodać workflow

Utwórz `sonarqube.yml`. Kroki:

1. Checkout.
2. `sonar-material.sh`. Przy `no material` job kończy się sukcesem bez kontenera.
3. Start kontenera Community Build na sieci runnera, port tylko wewnątrz joba.
4. `sonar-bootstrap.sh`.
5. Gdy są projekty .NET: `dotnet test` z filtrem jednostkowym i zbieraniem pokrycia, potem
   skaner .NET między początkiem a końcem analizy, zgodnie z dokumentacją skanera dla tej
   wersji obrazu.
6. Gdy są źródła klienta: skaner CLI z `lcov`, albo kod `1`, gdy katalog klienta jest w
   diffie bez raportu.
7. Kod wyjścia skanera jest kodem joba. `qualitygate.wait` sprawia, że czerwona bramka jest
   czerwoną komendą.

Nie wołaj CodeQL z tego pliku. `runs-on: ubuntu-latest`. `permissions: contents: read`.
`timeout-minutes: 40`. `persist-credentials: false`. Wyzwalacz `pull_request` na `develop`,
`release` i `main`, bez `paths` i bez `pull_request_target`.

### 5. Dodać compose lokalny

Utwórz `compose/sonarqube/compose.yml` i `sonar-local.sh`. Skrypt lokalny woła ten sam
`sonar-bootstrap.sh` z tym samym JSON. Osoba widzi ten sam próg co CI, na
`http://127.0.0.1:9000`. Port tylko na `127.0.0.1`. Obraz skrótem. Hasło poza repozytorium.
Powtórny start nie kasuje wolumenu.

### 6. Dopisać check

W tym samym scaleniu dopisz `sonarqube` do `develop.json`, `release.json` i `main.json`.

### 7. Zostawić przeniesienie na VM jako zmianę adresu

W `sonarqube.yml` komentarz nad krokami kontenera mówi, że [08-proxmox.md](08-proxmox.md)
może podmienić start kontenera na adres serwera z OpenBao. Podmiana nie usuwa kroku
`sonar.qualitygate.wait` i nie usuwa nazwy checka. Jeśli numer `08` jeszcze nie istnieje
jako workflow, zostaje kontener na runnerze. Bramka się nie wyłącza „do czasu VM”.

### Co jest do czego

| Plik | Kto woła | Po co istnieje |
| --- | --- | --- |
| `quality-gate.json` | `sonar-bootstrap.sh` | próg w gitcie |
| `sonar-project.properties` | skaner | klucz, wykluczenia, czekanie na bramkę |
| `sonar-bootstrap.sh` | job CI i `sonar-local.sh` | ten sam projekt i ta sama bramka |
| `sonar-material.sh` | job | pusty sukces przed kodem źródłowym |
| `sonarqube.yml` | pull request na `develop`, `release` i `main` | check `sonarqube` |
| `compose.yml` | `sonar-local.sh` | jeden kontener deweloperski |
| `sonar-local.sh` | osoba lokalnie | próg bez klikania w interfejsie |
| `develop.json`, `release.json`, `main.json` | sync z numeru `01` | check wymagany |

Job `unit-tests` nie woła Sonara. Pokrycie blokuje na `develop`, `release` i `main`.

## Testy

`actionlint`:

```bash
actionlint .github/workflows/sonarqube.yml
```

Kod `0`.

```bash
grep -nE 'self-hosted|pull_request_target|secrets\.|latest' .github/workflows/sonarqube.yml compose/sonarqube/compose.yml
```

Brak trafień. W compose jest skrót obrazu, nie tag `latest`.

Suchy przebieg materiału w drzewie bez `src/**/*.cs` i bez frontu:

```bash
.github/scripts/sonar-material.sh
```

Linia `no material for sonarqube`, kod `0`.

Suchy przebieg JSON bramki, bez kontenera:

```bash
jq -e '
  .name == "jjdevhub"
  and ([.conditions[].metric] | index("new_coverage"))
' .github/sonar/quality-gate.json
```

Kod `0`. Oczekiwane metryki w pliku: nowe blockery, nowe critical, przejrzane hotspoty,
gęstość duplikacji, `new_coverage`. Brak którejkolwiek kończy `jq` kodem `1`.

Zła gałąź:

```bash
.github/scripts/check-branch-name.sh --head feature/lesson_markdown --base develop --skip-ancestry
echo $?
```

Kod `1`. `feature/lesson-markdown` do `develop` daje kod `0`. Na takiej gałęzi, przed
kodem źródłowym, w logu widać `no material for sonarqube`, a ruleset ma zielony check
`sonarqube`. Niskie pokrycie nowego kodu kończy ten sam check kodem `1` już na `develop`.

Gdy kontener lokalny już stoi, sprawdzenie ręczne, nieblokujące joba:

```bash
.github/scripts/sonar-local.sh
```

Skrypt kończy się kodem `0` i wypisuje `http://127.0.0.1:9000` oraz ścieżkę pliku z hasłem
poza repozytorium. `git status` nie pokazuje tego pliku.

Pełny czerwony przykład bramki pokrycia pojawi się, gdy będzie projekt z celowo niepokrytą
linijką. Do tego czasu fixture materiałowy jest zielony, a fixture JSON jest sprawdzany
przez `jq`. Nie commituj hasła z logu kontenera.

Scenariusz promocji News z czterdziestoma procentami pokrycia nowego kodu ma dać czerwony
kod skanera, gdy projekt już istnieje i linie są widoczne dla analizatora. Do tego czasu
zielony `sonar-material.sh` i zielony `jq` są tym, co da się odpalić na samym drzewie
dokumentacji. `actionlint` i `grep` da się odpalić, gdy tylko powstanie workflow i compose.
Kod `2` ze `sonar-material.sh` jest błędem użycia, nie werdyktem bramki.

## Zasady

- Check `sonarqube` jest wymagany na `develop`, `release` i `main` od scalenia, które dodaje
  workflow.
- Pięć warunków z tabeli obowiązuje nowy kod. Pokrycie nowego kodu to co najmniej `80%`, gdy
  są linie do pokrycia.
- Brak źródeł to sukces z logiem, nie wyłączenie checka.
- Hasło, token i adres produkcyjny nie wchodzą do gita ani do YAML jako `secrets.`.
- CI nie woła kontenera z laptopa.
- Obraz to Community Build przypięty skrótem.
- Przeniesienie na VM nie wyłącza `sonar.qualitygate.wait` i nie zmienia nazwy checka.
- Job idzie na `ubuntu-latest`.
- Wykluczenie katalogu jest w `sonar-project.properties`, z powodem w komentarzu.
- Jeden JSON. Front nie dostaje drugiego progu.
- Czerwony test jednostkowy kończy job przed wysłaniem pokrycia.
- CodeQL zostaje w swoim numerze, przy progu `7.0`. Ten workflow go nie woła.

## Poza zakresem

| Temat | Numer |
| --- | --- |
| Test jednostkowy bez progu pokrycia | [02-bramki.md](02-bramki.md) |
| CodeQL i `security-severity` | [03-codeql.md](03-codeql.md) |
| CVE bibliotek i obrazów | [04-zaleznosci-i-obrazy.md](04-zaleznosci-i-obrazy.md) |
| Pin akcji i sekrety w diffie | [06-lancuch-dostaw.md](06-lancuch-dostaw.md) |
| Maszyna i katalog, w którym kontener zostanie | [08-proxmox.md](08-proxmox.md) |
| Token serwera z OpenBao na VM | [14-openbao.md](14-openbao.md) |
| Treść reguł domeny, którą bramka zmierzy | numery `docs/api` |

Tag komponentu, który dostanie dług, jeśli bramka go puści, nadaje
[07-wersje.md](07-wersje.md). Ten numer tagu nie wycina. Nie buduje obrazu. Nie stawia YARP.
Nie pisze schematu bazy. Mierzy wycinek, który promocja chce wpuścić na `release` i na
`main`.

## Źródła

- [Understanding quality
  gates](https://docs.sonarsource.com/sonarqube-community-build/quality-standards-administration/managing-quality-gates/introduction-to-quality-gates).
  Wiążące są warunki na nowym kodzie i sens bramki przed wydaniem. Dotyczy pięciu progów w
  `.github/sonar/quality-gate.json` oraz tego, że `release` nie przyjmuje wycinka, który
  tych progów nie spełnia. Ze źródła nie bierzemy bramki utrzymywanej wyłącznie kliknięciem
  w interfejsie. Następny job i tak wgrywa JSON. Nie bierzemy osobnej bramki na każdy
  komponent.
- [CI integration
  overview](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/ci-integration/overview).
  Wiążące jest `sonar.qualitygate.wait=true` i timeout czekania na raport. Dotyczy wpisu w
  `sonar-project.properties`, limitu `300` sekund i tego, że czerwona bramka jest czerwoną
  komendą skanera. Ze źródła nie bierzemy werdyktu złożonego w Jenkinsie albo w pipe
  Bitbucketa. Nie bierzemy zielonego skanera, który kończy się przed policzeniem bramki.
- [Parameters not settable in the
  UI](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/analysis-parameters/parameters-not-settable-in-ui).
  Wiążące są `sonar.qualitygate.wait` z domyślnym `false`, `sonar.qualitygate.timeout` z
  domyślnym `300`, `sonar.host.url` oraz zakaz wpisywania tokenu do pliku. Dotyczy
  wymuszenia czekania, limitu `300`, adresu doklejanego przez workflow i braku
  `secrets.SONAR_TOKEN` w YAML. Ze źródła nie bierzemy domyślnego `false`, nie bierzemy
  tokenu w `sonar-project.properties` i nie bierzemy domyślnego hosta SonarCloud.
- [Web API](https://docs.sonarsource.com/sonarqube-community-build/extension-guide/web-api).
  Wiążące są wywołania, których używa `sonar-bootstrap.sh`: status systemu, projekt i
  bramka. Dotyczy czekania na `api/system/status` równe `UP` przez najdłużej `180` sekund,
  utworzenia projektu `jjdevhub` i wgrania warunków. Ze źródła nie bierzemy tokenu
  zapisanego w repozytorium ani hasła wypisanego w logu. Hasło joba zostaje w pamięci
  przebiegu.
- [Analysis
  parameters](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/analysis-parameters).
  Wiążące są parametry analizy, w tym wykluczenia ścieżek. Dotyczy `docs/**`, `versions/**`,
  `**/bin/**`, `**/obj/**` i `**/*.Generated.cs` oraz źródeł `src`, gdy katalog istnieje. Ze
  źródła nie bierzemy wpisu `sonar.host.url` na adres maszyny w pliku commituowanym. Adres
  dokleja workflow albo, później, zmienna z OpenBao.
- [Managing custom quality
  gates](https://docs.sonarsource.com/sonarqube-community-build/quality-standards-administration/managing-quality-gates/managing-custom-quality-gates).
  Wiążące jest to, że bramkę da się nazwać, złożyć z warunków i przypiąć do projektu przez
  API. Dotyczy nazwy `jjdevhub`, operatorów `LT`, `GT` i `EQ` przy warunkach oraz tego, że
  bootstrap podmienia bramkę z JSON. Ze źródła nie bierzemy drugiej bramki „tymczasowej”
  obok pliku. Interfejs po wgraniu ma pokazać ten sam próg.
- [Metrics
  definition](https://docs.sonarsource.com/sonarqube-community-build/user-guide/code-metrics/metrics-definition).
  Wiążące są definicje metryk, które JSON nazywa. Dotyczy nowych blockerów, nowych critical,
  przejrzanych hotspotów, gęstości duplikacji i `new_coverage` oraz progów `0`, `100%`, `3%`
  i `80%`. Ze źródła nie bierzemy innych progów i nie bierzemy metryki na całym kodzie tam,
  gdzie warunek tego numeru jest na nowym kodzie. `jq` sprawdza nazwę bramki i obecność
  `new_coverage`.
- [Security
  hotspots](https://docs.sonarsource.com/sonarqube-community-build/user-guide/security-hotspots).
  Wiążący jest przegląd hotspotu jako osobny od naruszenia stan: hotspot bez przeglądu nie
  jest zamknięty. Dotyczy warunku `100%` przejrzanych nowych hotspotów. Ze źródła nie
  bierzemy uznania, że sam CodeQL przy progu `7.0` już ten przegląd zastępuje. CodeQL
  zostaje w [03-codeql.md](03-codeql.md).
- [.NET test
  coverage](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/dotnet-test-coverage).
  Wiążące jest to, że Community Build sam nie wytwarza raportu, oraz układ początek analizy,
  test, koniec analizy. Dotyczy `dotnet test` wewnątrz joba `sonarqube` z filtrem
  `Category!=Integration&Category!=Performance`. Ze źródła nie bierzemy wysłania pokrycia z
  czerwonego testu i nie bierzemy raportu z joba `unit-tests`, bo ten job raportu między
  workflowami nie publikuje.
- [JavaScript / TypeScript test
  coverage](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/javascript-typescript-test-coverage).
  Wiążący jest raport LCOV i jeden parametr dla JavaScript oraz TypeScript. Dotyczy
  `lcov.info`, gdy katalog klienta jest w diffie, i kodu `1`, gdy raportu nie ma, a w diffie
  są pliki `ts` albo `tsx`. Ze źródła nie bierzemy drugiego, łagodniejszego progu dla
  frontu. Nie bierzemy osobnego parametru TypeScript jako drugiego kanału. Zanim katalog
  klienta istnieje, brak `lcov` nie blokuje.
- [Test coverage
  parameters](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/test-coverage/test-coverage-parameters).
  Wiążące są ścieżki raportów, które skaner umie wczytać. Dotyczy przekazania raportu .NET
  między początkiem a końcem skanera oraz `lcov` dla klienta. Ze źródła nie bierzemy
  generowania raportu przez sam serwer. Raport powstaje w jobie, narzędziem testu, z filtrem
  jednostkowym.
- [SonarScanner for
  .NET](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/dotnet).
  Wiążący jest skaner między początkiem a końcem analizy. Dotyczy kroku joba, gdy w drzewie
  są projekty .NET. Ze źródła nie bierzemy skanera odpalonego bez czekania na bramkę.
  `sonar.qualitygate.wait=true` zostaje. Wersja skanera ma pasować do wersji obrazu, którego
  skrót jest przypięty.
- [SonarScanner
  CLI](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/sonarscanner).
  Wiążący jest skaner CLI tam, gdzie źródłem jest klient, nie projekt .NET. Dotyczy kroku z
  `lcov`, gdy w diffie jest katalog klienta. Ze źródła nie bierzemy osobnego projektu Sonara
  dla weba. Klucz zostaje `jjdevhub`. Kod `1` przy braku raportu jest regułą tego numeru,
  nie domyślnym zachowaniem samego CLI.
- [Set up and start your
  container](https://docs.sonarsource.com/sonarqube-community-build/server-installation/from-docker-image/set-up-and-start-container).
  Wiążące jest jedno wejście kontenera na porcie `9000` i obraz wskazany tagiem albo skrótem
  z Docker Hub. Dotyczy compose na `127.0.0.1:9000` i kontenera joba, którego port nie
  wychodzi na `0.0.0.0`. Ze źródła nie bierzemy publikacji `9000` na wszystkich
  interfejsach, nie bierzemy tagu `latest` i nie bierzemy hasła JDBC wpisanego w plik
  compose. Hasło administratora losuje job albo `sonar-local.sh`.
- [Prepare the Docker
  installation](https://docs.sonarsource.com/sonarqube-community-build/server-installation/from-docker-image/prepare-installation).
  Wiążące jest trzymanie danych serwera w wolumenie, nie w bind-mount katalogu, który skaner
  ma analizować. Dotyczy wolumenu poza gitem i zakazu montowania repozytorium do kontenera
  serwera. Ze źródła nie bierzemy osobnej bazy pod serwer jakości w tym numerze. Kontener CI
  jest pusty na starcie przebiegu i ginie z runnerem. Wolumen lokalny nie jest commitem.
- [Try out
  SonarQube](https://docs.sonarsource.com/sonarqube-community-build/try-out-sonarqube).
  Wiążące jest to, że lokalny kontener Community Build wstaje z oficjalnego obrazu i słucha
  na `9000`. Dotyczy `sonar-local.sh` i adresu `http://127.0.0.1:9000`. Ze źródła nie
  bierzemy przykładu z tagiem `latest` i nie bierzemy zostawienia hasła początkowego obrazu.
  Hasło jest losowane, a w logu ląduje ścieżka pliku, nie wartość.
- [Adding analysis to a GitHub Actions
  workflow](https://docs.sonarsource.com/sonarqube-community-build/devops-platform-integration/github-integration/adding-analysis-to-github-actions-workflow).
  Wiążące jest użycie `sonar.qualitygate.wait=true` w YAML, gdy werdyktem ma być kod
  skanera. Dotyczy joba `sonarqube` na `pull_request` do `develop`, `release` i `main`. Ze
  źródła nie bierzemy osobnej akcji Quality Gate Check jako drugiego werdyktu i nie bierzemy dekoracji
  pull requestu, której Community Build nie daje. Nie bierzemy tokenu z `secrets` w
  przykładzie integracji. Ten YAML sekretu nie ma.
- [Obraz `sonarqube` ](https://hub.docker.com/_/sonarqube). Wiążący jest oficjalny obraz i
  wariant Community Build. Dotyczy jednego kontenera oraz przypięcia skrótem w compose i
  później na VM. Ze źródła nie bierzemy tagu `latest` i nie bierzemy obrazów Developer,
  Enterprise ani Data Center. Płatna edycja nie jest warunkiem pull requestu.
- [actionlint](https://github.com/rhysd/actionlint). Wiążąca jest składnia workflow. Dotyczy
  `actionlint .github/workflows/sonarqube.yml` z kodem `0`. Ze źródła nie bierzemy
  actionlint jako zamiennika bramki jakości ani jako zamiennika pinu SHA. Piny akcji
  sprawdza numer `06`. Ten numer sprawdza, że plik joba w ogóle jest poprawnym workflow.

## Gotowe gdy

- Są workflow, JSON bramki, `sonar-project.properties`, oba skrypty CI, compose i
  `sonar-local.sh`.
- `actionlint .github/workflows/sonarqube.yml` kończy się kodem `0`.
- `grep` nie znajduje `secrets.`, `self-hosted`, `pull_request_target` ani `latest` w
  workflow i compose.
- `sonar-material.sh` bez źródeł wypisuje `no material for sonarqube` i kończy się kodem
  `0`.
- `jq` potwierdza nazwę `jjdevhub` i metrykę `new_coverage`.
- `develop.json`, `release.json` i `main.json` zawierają `sonarqube`.
- `feature/lesson_markdown` pada w `check-branch-name.sh` kodem `1`.
- W plikach tego numeru nie ma wartości hasła ani tokenu.
- Pięć warunków na nowym kodzie zostaje: blockery `0`, critical `0`, hotspoty `100%`,
  duplikacja co najwyżej `3%`, pokrycie co najmniej `80%`, gdy są linie.
- Hasło joba pochodzi z `openssl rand -base64 24` i nie wchodzi do YAML jako
  `secrets.SONAR_TOKEN`.
- `sonar.qualitygate.wait=true`, timeout skanera `300`, bootstrap `180` sekund, timeout joba
  `40`.
- Obraz jest przypięty skrótem. Compose publikuje `9000` tylko na `127.0.0.1`.
- Przeniesienie na VM podmienia adres i nie wyłącza checka.
