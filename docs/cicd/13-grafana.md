# 13. Grafana

Ten numer stawia ekran operatora na maszynie, gdy metryki i ślady już mają magazyn.
Poprzedni numer, [Jaeger](12-jaeger.md), trzyma drzewo spana i UI na porcie `16686`.
Następny plik, [OpenBao](14-openbao.md), stawia serwer sekretów. W kolejności
pracy ekran idzie po Jaegerze, przed [bazami zapisu](../api/02-postgres.md):
collector, Prometheus i Jaeger już stoją. Tutaj powstaje jeden pod Grafany
OSS, dwa datasource wpisane w git i dwa dashboardy JSON. Hasła administratora w git nie ma.
Czytelnik strony CV tego ekranu nie dostaje.

Scenariusz, który bez tego ekranu się rozpada, zaczyna się od tagu `news-v1.4.0` i od
żądania, które wisi. Prometheus z [11-prometheus.md](11-prometheus.md) odpowie na PromQL.
Jaeger odpowie na `trace_id`. Operator, który przy każdym tagu otwiera dwa `port-forward`,
za którymś razem porówna szereg z innego okna czasu niż drzewo śladu. Liczba żądań w toku,
czas odpowiedzi, atrybut `service.version` i przejście do Jaegera mają być jednym ekranem.
Osobne UI da się wytrzymać raz. Nie da się tego utrzymać przy każdym tagu.

Laptop zostaje przy dashboardzie Aspire. Ten numer go nie zastępuje i nie dokłada drugiej
instrumentacji. Usługa nie wysyła OTLP do Grafany. Grafana nie scrapuje podów. Czyta Service
`prometheus` i Service `jaeger` po ClusterIP. Wykres jest zapytaniem do magazynu, który już
istnieje, a nie nowym sygnałem wypchniętym z `JJDevHub.ServiceDefaults`.

Drugi scenariusz psuje się przy pustym dysku. Operator klika dashboard w UI, nie eksportuje
JSON i uznaje, że wykres „już jest”. `vzdump` z [08-proxmox.md](08-proxmox.md) zabierze PVC,
więc kopia maszyny ten klik pamięta. Świeży pod na pustym PVC już nie. Repozytorium w tym
momencie kłamie: manifest jest zielony, a ekranu nie ma. Dlatego oba dashboardy,
`jjdevhub-uslugi` i `jjdevhub-wersje`, są plikami w git, a `allowUiUpdates` zostaje `false`.

## Po co

Przy incydencie operator ma zobaczyć obok siebie to, co Prometheus liczy, i to, co Jaeger
trzyma jako drzewo. Rekord `jjdevhub:http_server_active_requests:sum` mówi, ile żądań wisi,
z podziałem na `service_name`. Histogram czasu, którego nazwę numer 10 zapisał przy
`:8889/metrics`, mówi, który komponent zwalnia. `service.version` mówi, który tag właśnie
emituje próbki. Link danych panelu otwiera ten sam `trace_id` w Jaegerze. Cztery odpowiedzi
z czterech narzędzi, bez wspólnego ekranu, rozjeżdżają się o czas odświeżenia i o to, który
pod operator właśnie przeklikał.

Ten sam ekran ma przeżyć drugi pod. Numer [15-skalowanie.md](15-skalowanie.md) podnosi
replikę News, gdy próg CPU albo próg żądań w toku zostanie przekroczony. Wykres zgrupowany
po nazwie poda ReplicaSet gubi szereg przy każdym rolloutcie i rysuje dwa osobne paski
zamiast jednego komponentu. Zapytanie tego numeru grupuje po `service_name`. Drugi pod
wchodzi w ten sam szereg. Trzeciego poda i tak nie będzie, ale gdyby ktoś go wstawił
ręcznie, wykres nadal nie może zależeć od nazwy poda.

Czytelnik CV, student i rekruter tej Grafany nie widzą. YARP nie dostaje trasy do Service
`grafana`. Publiczny hostname, jeśli istnieje, jest tym z
[09-cloudflare.md](09-cloudflare.md) i stoi za Cloudflare Access, obok bramy aplikacji, nie
przed nią. Wejście z LAN to `kubectl -n jjdevhub port-forward svc/grafana 3000:3000`. Port
`3000` nie jest NodePort i nie słucha na adresie gościa. `nc -vz` na ten port z sieci spoza
LAN nie łączy.

Hasło konta `admin` powstaje na maszynie, w Secretcie `grafana-admin`, pod kluczem
`admin-password`. Deployment czyta je do `GF_SECURITY_ADMIN_PASSWORD` przez `secretKeyRef`.
W git jest nazwa Secreta i nazwa klucza. Wartości nie ma. Anonimowy dostęp jest wyłączony,
bo `port-forward` z LAN omija Access. Gdyby proces wpuszczał anonimowego administratora,
ktoś w sieci lokalnej dostałby wykresy bez hasła, choć z WAN Access by go zatrzymał.

`mobile` nie ma panelu poda. Nie ma Deploymentu telefonu, więc szereg z etykietą `mobile`
byłby pustym kłamstwem albo, co gorsza, kimś kto nazwał tak inny proces. Numer telefonu
widać na ekranie O aplikacji, co sprawdza [16-deploy.md](16-deploy.md). Dashboard usług
rysuje `identity`, `news`, `learning`, `cv`, `contact`, `gateway` i `web`. Dashboard wersji
rysuje `service.version` tych samych nazw. Nie wylicza wersji z nazwy obrazu, gdy atrybut
zasobu już jest.

Utrata PVC nie kasuje wykresów opisanych w repozytorium. Katalog danych Grafany na `10Gi`
trzyma użytkowników, których operator doda później w UI, i stan wewnętrzny procesu.
Datasource i dashboardy i tak pochodzą z plików montowanych przy starcie. Świeży wolumen bez
tych plików jest pustym UI. Z tymi plikami jest tym samym ekranem co poprzedni pod. Hasła z
Secreta PVC nie trzyma. Secret żyje osobno. Reset hasła po utracie Secreta idzie według
dokumentacji Grafany, nie według historii gita.

Grafana nie jest stroną produktu. Stopka `web-vX.Y.Z` i ekran telefonu nie powstają tutaj.
Zestawienie wykresu wersji z `GET /versions` jest pracą operatora przy deployu. Ten numer
tylko rysuje atrybut, który collector już dostał. Pusty wykres przy zerowych replikach
aplikacji jest poprawny: numer 08 zostawia Deploymenty na `replicas: 0` do pierwszego tagu,
a reguła Prometheusa wolno zwraca pusty wektor.

## Dlaczego ta technologia

### Grafana OSS, jedna replika

Grafana w wydaniu open source, licencja AGPL-3.0, stoi jako jeden pod. Czyta
`http://prometheus.jjdevhub.svc.cluster.local:9090` i
`http://jaeger.jjdevhub.svc.cluster.local:16686`. Oba adresy są ClusterIP wewnątrz namespace
`jjdevhub`. Proces nie wychodzi na NodePort. Obraz jest przypięty do digestu. Pływający tag
obrazu dałby się przepiąć pod spodem, a ekran wersji porównywałby wtedy próbki z innego
binarium niż to, które recenzja oglądała.

Konkret JJDevHub jest tu operacyjny, nie domenowy. Gdy News zwolni na zapisie artykułu, a Cv
odpowie szybko, oba szeregi mają być widoczne na `jjdevhub-uslugi` pod swoimi
`service_name`. Grafana nie zna typu `Article` i nie zna roli `owner`. Nie woła bazy, nie
woła Kafki i nie woła OpenBao. Nie dostaje OTLP. Jedynym ruchem wychodzącym z procesu są
zapytania do dwóch Service, które ten numer wpisał w provisioning.

Grafana Cloud odpada razem z odrzuceniem chmury publicznej z numeru 08. Próbki żądań i
identyfikatory śladów wyszłyby poza maszynę, a retencja przestałaby być PVC na tym dysku.
Własny zestaw statycznych plików HTML odpada, bo PromQL i link do `trace_id` trzeba by
napisać drugi raz, a potem utrzymać przy każdej zmianie nazwy rekordu. Dokładanie metryki
„specjalnie pod wykres” w kodzie usługi odpada: serie już wypływają z ServiceDefaults przez
collector na `:8889`, a numer 11 zamienia je w rekord o stałej nazwie.

Druga replika Grafany odpada z tego samego powodu, dla którego HPA tego numeru nie dotyczy.
Dwa procesy na jednym PVC gryzą się o katalog danych. Dwa procesy na dwóch PVC rozjeżdżają
użytkowników klikniętych w UI, a dashboardy i tak mają pochodzić z git, nie z lokalnego
stanu. Jeden pod wystarcza jednemu operatorowi. Koszt zostaje: kolejny pod, 100m CPU, 256
MiB pamięci, `10Gi` dysku i obowiązek, żeby JSON w repozytorium odpowiadał nazwom z numerów
10 i 11. AGPL dotyczy dystrybucji Grafany. Tej dystrybucji tu nie ma: proces zostaje na
własnej maszynie operatora i nie jest obrazem oddawanym czytelnikowi strony.

HPA na Grafanie nie powstaje w [15-skalowanie.md](15-skalowanie.md). Próg CPU aplikacji nie
jest progiem UI operatora. Podniesienie drugiej Grafany w nocy, bo ktoś zostawił odświeżanie
panelu, zjadłoby RAM, który numer 08 policzył jako zapas węzła. Ekran ma być stabilny, gdy
usługi się skalują. Sam nie wchodzi do listy siedmiu Deploymentów ze skalowaniem.

### Datasource w git, hasło poza git

Datasource Prometheusa i Jaegera nie niesie sekretu. Oba Service wewnątrz namespace nie mają
hasła aplikacji. Plik `datasources.yaml` wolno commitować. `uid` Prometheusa to
`prometheus`, `isDefault` to `true`, `editable` to `false`. `uid` Jaegera to `jaeger`,
`editable` to `false`. `access` obu to `proxy`: przeglądarka operatora pyta Grafanę, a
Grafana pyta Service. Przeglądarka nie dostaje adresu poda Prometheusa.

`editable: false` zostawia zmianę adresu w git. UI nie staje się drugim źródłem prawdy.
Scenariusz, który to łapie, jest cichy: operator w Connections poprawia port na `9091`,
zapisuje i przez tydzień panele są puste. Kolejny pod z provisioningiem nadpisuje kliknięcie
albo, gdy provisioning na to pozwala, zostawia je i repozytorium już nie opisuje maszyny.
Przy `editable: false` zapis w UI nie jest wydaniem. Wydaniem jest commit pliku.

Hasło konta `admin` nie jedzie tym samym torem. `GF_SECURITY_ADMIN_PASSWORD=admin` w
manifeście odpada: wartość ląduje w git, w logu `kubectl` i w historii polecenia. Konto
wyłącznie przez Cloudflare Access, bez hasła procesu, też odpada jako jedyne zabezpieczenie.
`port-forward` z LAN omija Access. Zostaje wtedy anonimowy administrator, jeśli proces go
nie wymaga. Dlatego `GF_AUTH_ANONYMOUS_ENABLED` jest `false`, a hasło jest losowane na
maszynie.

Losowanie jest konkretne. `openssl rand -base64 24` daje wartość klucza `admin-password` w
Secretcie `grafana-admin`. Polecenie tworzy Secret w namespace. Wartość nie wchodzi do pliku
w katalogu repozytorium, nie wchodzi do issue i nie zostaje wklejona w log przebiegu.
Operator zapisuje ją w swoim magazynie haseł. OpenBao z numeru 14 może tę wartość przyjąć
później. Ten numer na to nie czeka, bo w kolejności plików jest wcześniejszy. Do zamknięcia
wystarcza Secret Kubernetes.

Koszt jest po stronie operatora. Utrata Secreta przy zachowanym PVC wymaga resetu hasła
według dokumentacji Grafany, nie sięgania do `git log`. Utrata PVC przy zachowanym Secretcie
kasuje lokalnych użytkowników UI i zostawia wykresy, bo te wracają z git przy starcie. Oba
magazyny są świadomie rozdzielone. Żaden nie trzyma connection stringa aplikacji.

`GF_SERVER_ROOT_URL` dochodzi tylko wtedy, gdy numer 09 ma hostname Grafany. Wartość jest
adresem `https` tej nazwy, z ukośnikiem końcowym, jak w przykładzie
`https://grafana.example.com/`. Operator podstawia rzeczywistą nazwę. Bez hostname zmienna
nie wskazuje na adres gościa i w ogóle nie jest ustawiona. Ustawienie jej na IP maszyny
psuje skrypty ładowane przez tunel: przeglądarka dostaje HTML i nie dostaje aplikacji, bo
root URL nie zgadza się z nazwą, pod którą weszła.

### Dashboardy jako JSON w repozytorium

Każdy dashboard jest plikiem JSON w `deploy/k3s/observability/grafana/dashboards/`. Są dwa
pliki: `jjdevhub-uslugi.json` i `jjdevhub-wersje.json`. Grafana ładuje je przy starcie z
provisioningu. Katalog wolno wziąć z `foldersFromFilesStructure` albo z równoważnego pola
tej wersji obrazu. Obok jest `allowUiUpdates: false`. Kliknięcie Save w UI nie jest wydaniem
i nie nadpisuje pliku, z którego pod wstał.

Zmiana wykresu jest commitem. Przechodzi przez bramki z numerów 01–07 i wchodzi na maszynę
razem z manifestem. Recenzja pilnuje zapytania i tytułu. JSON jest gadatliwy. Recenzja nie
pilnuje każdego piksela, pilnuje tego, że zapytanie używa
`jjdevhub:http_server_active_requests:sum`, że filtr nazywa się `service_name` i że tytuł
panelu używa nazwy komponentu, nie nazwy obrazu z rejestru.

Dashboard klikany tylko w UI i nigdy nieeksportowany odpada. Druga maszyna po odtworzeniu z
kopii go ma tylko wtedy, gdy kopia objęła PVC. Świeży dysk już nie. Biblioteka gotowych
dashboardów z internetu odpada z innego powodu: nazwy metryk cudzego eksportera `/metrics`
nie są nazwą rekordu tego klastra. Panel, który szuka `node_cpu_seconds_total` albo nazwy z
eksportera aplikacji, będzie pusty albo, co gorsza, złapie przypadek z joba węzła i poda go
za ruch News. Job węzła, jeśli numer 11 go dodał, jest wykresem maszyny. Nie jest źródłem
HPA i nie zastępuje rekordu HTTP.

Koszt zostaje przy diffie. Poprawka progu na panelu jest pull requestem, nie kliknięciem o
północy. To jest wolniejsze w trakcie incydentu i właśnie o to chodzi: próg narysowany w
nocy bez commitu znika przy następnym PVC, a próg w git zostaje. Operator, który musi
zobaczyć coś raz, filtruje w Explore. To nie jest wydanie dashboardu.

### Jeden zestaw paneli na komponent

`jjdevhub-uslugi` ma wiersz na każdy komponent klastrowy z listy: `identity`, `news`,
`learning`, `cv`, `contact`, `gateway`, `web`. W wierszu jest co najmniej liczba żądań w
toku, histogram czasu i filtr zmiennej `service_name`. Zapytanie żądań w toku jest rekordem
`jjdevhub:http_server_active_requests:sum`. Nie jest surową nazwą, którą SDK może poprzedzić
innym prefiksem. Nazwę surową, gdy się różni, numer 11 już schował wewnątrz `expr` reguły.
Ten numer woła rekord.

`jjdevhub-wersje` rysuje aktualną wartość atrybutu `service.version` obok liczby replik, per
`service_name`. Tytuł panelu używa nazw komponentów. Nie używa
`ghcr.io/jtjaskulski/jjdevhub-news`. Zestawienie z `GET /versions` robi operator przy
rolloutcie. Kształt pola w odpowiedzi bramy jest z [16-gateway.md](../api/16-gateway.md):
numer wersji bez prefiksu nazwy. Atrybut zasobu, który rysuje ten dashboard, jest pełnym
tagiem, tak jak ustalił numer 10, na przykład `news-v1.4.0`. Dashboard nie tłumaczy jednego
na drugie w locie i nie wylicza wersji z digestu obrazu.

Osobny dashboard na każdy wykres odpada. Operator nie przełącza dwudziestu tablic, żeby
zobaczyć, który tag stoi. Jeden wykres „wszystko sumą bez `service_name`” odpada, bo pięć
usług zlewa się w kreskę i nie da się jej zestawić z polem `news` w `GET /versions`. Gdy
Learning wisi, a News nie, suma wygląda jak łagodny wzrost. Wiersz per komponent pokazuje,
który `service_name` trzyma żądania.

Nowy komponent z listy tagów wymaga wiersza na tym dashboardzie w tym samym wydaniu co jego
Deployment. Dopisanie Deploymentu `learning` bez wiersza zostawia usługę niewidoczną przy
incydencie, choć metryka już spływa. To jest luka ekranu, nie luka collectora. `mobile`
wiersza nie dostaje, bo nie ma poda. Pusty panel „na zapas” uczy operatora ignorować dziury.

### Link do śladu, bez drugiej kopii drzewa

Panel logów nie jest magazynem. Grafana nie scrapuje stdout i nie dostaje potoku `logs` z
collectora. Log zostaje na stdout, tak jak ustalił numer 10. Treść wyjątku jest w
`kubectl logs` i w polu błędu odpowiedzi. Na wykresie identyfikator, po którym się je
znajduje, pojawia się tylko wtedy, gdy zapytanie w ogóle zwraca `trace_id`. Nie dokładamy
logowania, żeby wykres miał tekst.

Panel czasu odpowiedzi ma link danych do datasource Jaeger po `trace_id`, gdy panel to
umożliwia. Pole to `dataLink` wskazujące `uid` `jaeger`. Drzewo spanów zostaje w Jaegerze.
Grafana jest przejściem. Skopiowanie drzewa do drugiego magazynu rozjechałoby retencję:
Jaeger trzyma 7 dni na Badgerze, a drugi magazyn żyłby własnym dyskiem i własnym
samplingiem. Przy rzadkim błędzie formularza operator otwierałby puste przejście albo, co
gorsza, inne drzewo niż to z UI Jaegera.

Włączenie Loki albo Promtail w tym numerze odpada. Oba byłyby nowym potokiem na log, który
numer 10 świadomie zostawił na stdout. Koszt osobnego magazynu logów na dysku 120 GiB
zjadłby zapas obok Postgresa, Kafki, Jaegera i Prometheusa. Wykres i tak nie jest miejscem
na ciało żądania. Ciało w panelu byłoby sekretem na ekranie operatora, tym samym błędem co
ciało w odpowiedzi health.

Brak `trace_id` w logu nie naprawia się filtrem Grafany. Naprawia się w ServiceDefaults, bo
to jedyne miejsce, które spina logger ze śladem. Ten numer zakłada, że linia logu już ma
identyfikator, i buduje przejście. Nie buduje drugiej instrumentacji, gdy identyfikatora nie
ma.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/observability/grafana.yaml` | Deployment, Service ClusterIP 3000, PVC, montowanie provisioningu |
| `deploy/k3s/observability/grafana/datasources.yaml` | Prometheus jako domyślny, Jaeger jako drugi |
| `deploy/k3s/observability/grafana/dashboards.yaml` | Provisioning katalogu JSON, `allowUiUpdates: false` |
| `deploy/k3s/observability/grafana/dashboards/jjdevhub-uslugi.json` | Ruch, czas, żądania w toku, per `service_name` |
| `deploy/k3s/observability/grafana/dashboards/jjdevhub-wersje.json` | `service.version` i liczba replik |

Datasource, oba w jednym pliku:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus.jjdevhub.svc.cluster.local:9090
    isDefault: true
    editable: false
  - name: Jaeger
    type: jaeger
    uid: jaeger
    access: proxy
    url: http://jaeger.jjdevhub.svc.cluster.local:16686
    editable: false
```

`uid` jest stały, bo panel w JSON odwołuje się do niego, nie do nazwy wyświetlanej. Zmiana
`uid` bez zmiany JSON gasi zapytania, choć Connections dalej pokazuje zielone źródło pod
nową nazwą. `isDefault: true` jest tylko przy Prometheusie. Panel bez jawnego źródła nie
może trafić w Jaegera i dostać błędu składni PromQL. `editable: false` dotyczy obu. Adres
zmienia się commitem tego pliku.

Provisioning dashboardów:

```yaml
apiVersion: 1
providers:
  - name: jjdevhub
    type: file
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
      foldersFromFilesStructure: true
```

Pole `path` wewnątrz kontenera ma odpowiadać temu, co Deployment montuje.
`foldersFromFilesStructure` albo równoważne pole tej wersji obrazu bierze układ z katalogu w
git. `allowUiUpdates: false` jest wymagane. Zapis w UI nie zastępuje commitu.

Hasło i wyłączenie anonimowego wejścia w Deploymentcie, bez wartości:

```yaml
env:
  - name: GF_SECURITY_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: grafana-admin
        key: admin-password
  - name: GF_AUTH_ANONYMOUS_ENABLED
    value: "false"
```

Gdy numer 09 ma hostname Grafany, obok dochodzi zmienna. Bez hostname tego bloku nie ma.

```yaml
- name: GF_SERVER_ROOT_URL
  value: https://grafana.example.com/
```

Operator podstawia rzeczywistą nazwę. Wartość w git, jeśli hostname jest już decyzją numeru
09, jest adresem publicznym, nie sekretem. Hasła w tej zmiennej nie ma.

Secret `grafana-admin` nie ma manifestu z wartością. Jest tworzony na maszynie. W git wolno
opisać nazwę i klucz. Nie wolno wstawić `stringData` ani `data` z hasłem, także zakodowanym
w base64. Base64 nie jest pieczęcią. `git grep` po `admin-password:` w
`deploy/k3s/observability` ma nie znaleźć wartości.

Deployment `grafana` ma jedną replikę, obraz po digescie, żądania 100m CPU i 256 MiB
pamięci. Service ma typ `ClusterIP`, port `3000`, selector na ten Deployment. PVC ma `10Gi`
i jest montowany jako katalog danych procesu, nie jako katalog JSON. JSON i YAML
provisioningu idą z ConfigMap albo z plików katalogu `deploy/k3s/observability/grafana/`
montowanych do `/etc/grafana/provisioning`. Pomieszanie obu katalogów sprawia, że zapis UI i
plik z git leżą w tym samym miejscu i przy restarcie wygrywa przypadek.

## Plan

### 1. Secret hasła

Na maszynie, poza katalogiem repozytorium:

```bash
kubectl -n jjdevhub create secret generic grafana-admin \
  --from-literal=admin-password="$(openssl rand -base64 24)"
```

Wartość nie wchodzi do historii polecenia zostawionej w repozytorium i nie wchodzi do issue.
Operator zapisuje ją w swoim magazynie haseł. Polecenie nie używa `--from-file` wskazującego
plik, który dałoby się zacommitować. Nie używa `--dry-run=client -o yaml` z przekierowaniem
do `deploy/k3s`.

### 2. Manifest

Zastosuj `deploy/k3s/observability/grafana.yaml`. Jedna replika. Obraz po digescie. Żądania
100m CPU i 256 MiB pamięci. Service ClusterIP, port 3000. PVC `10Gi` na katalog danych.
Zmienne środowiska z tabeli ścieżek: `secretKeyRef` na `grafana-admin` / `admin-password`
oraz `GF_AUTH_ANONYMOUS_ENABLED=false`. `GF_SERVER_ROOT_URL` tylko przy hostname z numeru
09. W manifeście nie ma HPA i nie ma `hostPort`.

### 3. Provisioning

Zamontuj pliki z `deploy/k3s/observability/grafana/` do `/etc/grafana/provisioning`.
Dashboardy JSON zamontuj do ścieżki z `dashboards.yaml`. Po starcie oba datasource są
widoczne, a oba dashboardy ładują się z pliku. `allowUiUpdates` zostaje `false`. Nie
ustawiaj w procesie odbiornika OTLP i nie dopisuj scrape do tego Deploymentu.

### 4. Zapytania na dashboardzie usług

W `jjdevhub-uslugi.json` wstaw co najmniej:

- żądania w toku zapytaniem `jjdevhub:http_server_active_requests:sum`
- histogram czasu z metryki, której nazwę numer 10 zapisał przy `:8889/metrics`
- zmienną `service_name` o wartościach `identity`, `news`, `learning`, `cv`, `contact`,
  `gateway`, `web`

Zapytanie nie używa nazwy poda ReplicaSet jako stałej. Nie wstawiaj wiersza `mobile`. `uid`
datasource w JSON to `prometheus`, z wyjątkiem linku do Jaegera.

### 5. Dashboard wersji

W `jjdevhub-wersje.json` pokaż aktualną wartość `service.version` per `service_name` oraz
liczbę replik tego samego komponentu. Tytuły biorą nazwy komponentów. Nie wstawiaj
zapytania, które składa wersję z nazwy obrazu, gdy atrybut jest obecny.

### 6. Wejście

Z LAN:

```bash
kubectl -n jjdevhub port-forward svc/grafana 3000:3000
```

Logowanie kontem `admin` i hasłem z Secreta. Z WAN, gdy hostname istnieje: wyłącznie ta
nazwa za Access z numeru 09. Nie dodawaj trasy YARP do Grafany. Nie publikuj Service jako
NodePort.

### Co jest do czego

| Element | Po co istnieje | Kto go woła |
| --- | --- | --- |
| Deployment `grafana` | UI operatora | Przeglądarka operatora |
| Service ClusterIP `grafana:3000` | Stały adres wewnątrz namespace | `port-forward`, tunel z numeru 09 |
| `datasources.yaml` | Adresy Prometheusa i Jaegera | Proces Grafany przy starcie |
| `dashboards.yaml` | Katalog JSON i zakaz zapisu z UI | Proces Grafany przy starcie |
| `jjdevhub-uslugi.json` | Ruch i czas per komponent | Operator przy incydencie |
| `jjdevhub-wersje.json` | Który tag emituje metryki | Operator przy rolloutcie |
| Secret `grafana-admin` | Hasło procesu | Deployment, przez `secretKeyRef` |
| PVC `10Gi` | Stan lokalny UI, nie definicja wykresu | Proces Grafany |
| `port-forward` | Wejście z LAN | Operator |
| Access | Wejście z WAN, gdy hostname jest | Operator po numerze 09 |

Deployment `grafana` woła przeglądarka operatora. Gdy Deploymentu nie ma, Prometheus i
Jaeger dalej trzymają dane, a ekranu nie ma. Pod z obrazem po tagu pływającym wstaje, ale
digest, który recenzja oglądała, już nie jest tym, co serwuje UI.

`datasources.yaml` woła proces przy starcie. Gdy pliku nie ma, Connections jest puste i oba
JSON nie mają do czego wysłać zapytania. Gdy `editable` jest `true`, kliknięcie w UI staje
się drugim adresem, którego git nie opisuje. Gdy `uid` się rozjedzie z JSON, panel jest
czerwony przy zdrowym źródle.

`jjdevhub-uslugi.json` woła operator przy incydencie. Gdy zapytanie używa nazwy poda, drugi
pod z numeru 15 rozcina szereg. Gdy zapytanie sumuje bez `service_name`, News i Learning
zlewają się w jedną kreskę. Plik nie woła aplikacji. Aplikacja nie woła Grafany.

`jjdevhub-wersje.json` woła operator przy rolloutcie, obok `GET /versions`. Rysuje atrybut,
który numer 16 wstawia razem z digestem. Nie woła GHCR i nie parsuje nazwy obrazu.

Secret `grafana-admin` woła kubelet przy starcie kontenera, przez `secretKeyRef`. Gdy
Secreta nie ma, pod nie wstaje albo wstaje z pustym hasłem, zależnie od obrazu. Jedno i
drugie jest błędem tego numeru. Wartość w manifeście jest osobnym błędem: trafia do gita.

PVC woła proces jako katalog danych. Utrata wolumenu nie gasi JSON z git. Trzymanie JSON
tylko na PVC gasi ekran przy nowym wolumenie. Dlatego definicja wykresu nie leży na PVC.

`port-forward` i Access są dwoma wejściami do tego samego Service. YARP nie jest trzecim.
Czytelnik strony, który trafi na ścieżkę bramy, nie dostaje panelu. Żądanie anonimowe do UI
wewnątrz klastra nie dostaje danych dashboardu, bo anonimowy dostęp jest wyłączony.

Usługa aplikacji Grafany nie woła. Nie wysyła do niej OTLP. Collector nie ma eksportera z
adresem Grafany. HPA nie woła tego Deploymentu.

## Testy

Testy tego numeru są sprawdzeniami maszyny i drzewa. Nie ma tu faktu xUnit. Powód padnięcia
każdego punktu jest jeden i jest nazwany przy punkcie. Czerwony wynik z innego powodu, na
przykład z braku Prometheusa, znaczy, że sprawdzenie weszło w numer 11. Wtedy najpierw
domyka się magazyn, a ten numer powtarza się na gotowym datasource.

1. Pod jest Ready, a Service ma typ ClusterIP. Powód padnięcia: Deployment `grafana` nie
doszedł do Ready albo Service nie jest ClusterIP.

```bash
kubectl -n jjdevhub rollout status deploy/grafana
kubectl -n jjdevhub get svc grafana -o jsonpath='{.spec.type}{"\n"}'
```

Wyjście typu to `ClusterIP`. W specyfikacji Service nie ma `nodePort`. W Deploymentcie
`replicas` to 1. Obraz zawiera `@sha256:`.

2. Datasource są zdrowe. Powód padnięcia: provisioning nie podłączył Prometheusa albo
Jaegera. Po `port-forward` konto `admin` otwiera Connections i oba źródła mają stan
powodzenia. Z wewnątrz klastra to samo pokazuje API:

```bash
kubectl -n jjdevhub exec deploy/grafana -- \
  wget -qO- --header="Authorization: Bearer ${GRAFANA_TOKEN}" \
  http://127.0.0.1:3000/api/datasources
```

Token API wolno utworzyć ręcznie na czas testu i skasować. W git go nie ma. W logu przebiegu
nie zostaje. Jeśli token nie powstaje, zastępstwem jest zapis w logu startu, że provisioning
zakończył się bez błędu, oraz ręczny widok UI. Zastępstwo nie polega na wpisaniu hasła do
repozytorium. Odpowiedź API zawiera `uid` równe `prometheus` i `jaeger`, `isDefault`
prawdziwe tylko przy pierwszym oraz `url` zgodne z plikiem.

3. Dashboardy z git są na liście. Powód padnięcia: któregoś z dwóch plików JSON nie ma w UI.

```bash
kubectl -n jjdevhub exec deploy/grafana -- \
  wget -qO- http://127.0.0.1:3000/api/search
```

Przy uwierzytelnieniu odpowiedź zawiera `jjdevhub-uslugi` i `jjdevhub-wersje`. Nie zawiera
pozycji, której nie ma w katalogu git. Zapis w UI nowego panelu i ponowne wywołanie search,
które tę pozycję zwraca po restarcie poda, jest błędem `allowUiUpdates`.

4. Hasła nie ma w repozytorium. Powód padnięcia: literał hasła albo wartość klucza leży w
drzewie.

```bash
git grep -n "GF_SECURITY_ADMIN_PASSWORD" -- deploy/k3s || true
git grep -n "admin-password:" -- deploy/k3s/observability || true
```

Pierwsze znajduje co najwyżej `secretKeyRef`, nie literał po znaku równości. Drugie nie
znajduje wartości base64 ani hasła. Trafienie w `stringData` jest czerwone, nawet gdy obok
jest komentarz, że to przykład.

5. Port nie jest otwarty na gościu. Powód padnięcia: z sieci spoza LAN da się połączyć na
port 3000. `nc -vz <adres-gościa> 3000` nie łączy. Hostname bez tożsamości Access, jeśli
istnieje, nie zwraca UI Grafany. Zwraca bramkę logowania Access albo odmowę. Zwrócenie
paneli bez tej tożsamości jest błędem numeru 09 albo błędem tego Service, jeśli ktoś
wystawił go obok tunelu.

6. Zapytanie z panelu o `jjdevhub:http_server_active_requests:sum` wykonuje się bez błędu
datasource. Powód padnięcia: źródło Prometheusa zwraca błąd składni albo błąd połączenia,
nie pusty wektor. Pusty wykres przy zerowych replikach aplikacji jest poprawny. Błąd
„datasource not found” znaczy, że `uid` w JSON i `uid` w provisioningu się rozjechały.

7. Anonimowe żądanie nie dostaje danych dashboardu. Powód padnięcia: odpowiedź bez
uwierzytelnienia zawiera panele albo lista search zwraca JSON dashboardów. Sprawdzenie idzie
na `http://127.0.0.1:3000/api/search` z wnętrza poda, bez nagłówka. Oczekiwany jest odmowa,
nie lista `jjdevhub-uslugi`.

8. Drugi pod tego samego `service_name` nie wymaga nowego panelu. Powód padnięcia: zapytanie
w JSON filtruje po nazwie poda. To sprawdzenie wolno wykonać po numerze 15, na żywym News z
dwiema replikami, albo przeglądem pliku, zanim drugi pod wstanie. Przegląd pliku szuka w
JSON stałej z hashem ReplicaSet. Znalezienie jej jest czerwone.

9. W drzewie manifestów Grafany nie ma odbiornika OTLP, nie ma Promtail i nie ma Loki. Powód
padnięcia: w `deploy/k3s/observability/grafana.yaml` albo w provisioning jest adres spoza
Prometheusa i Jaegera. YARP nie zawiera trasy do `grafana`. To jest przegląd plików bramy z
[16-gateway.md](../api/16-gateway.md) i tego manifestu, nie test obciążeniowy.

## Zasady

- Jedna replika. HPA Grafany nie dotyczy. Druga replika rozcina katalog danych albo podwaja
  UI, którego git i tak nie bierze z dysku.
- Datasource i dashboard są w git. UI nie jest miejscem wydania wykresu. Zapis w UI znika
  przy pustym PVC albo kłóci się z plikiem.
- `allowUiUpdates` jest `false`. Bez tego Save w UI staje się wydaniem obok commitu.
- `editable` jest `false` na obu datasource. Adres zmienia się commitem. Kliknięcie w
  Connections zostawia port, którego manifest nie ma.
- Hasło `admin` jest w Secretcie `grafana-admin`, klucz `admin-password`, poza git. Literał
  w manifeście wchodzi do historii.
- `GF_AUTH_ANONYMOUS_ENABLED` jest `false`. Anonimowy administrator przy `port-forward`
  omija Access.
- `GF_SERVER_ROOT_URL` jest ustawione tylko wtedy, gdy istnieje hostname. Adres gościa w tej
  zmiennej psuje skrypty przez tunel.
- Grafana nie scrapuje podów i nie przyjmuje OTLP. Drugi potok metryk rozjeżdża nazwę z
  rekordem numeru 11.
- YARP nie routuje do Grafany. Czytelnik strony dostałby wykresy albo brama dostałaby ruch
  operatora.
- Port 3000 nie jest NodePort i nie jest otwarty na gościu. Wejście z LAN to `port-forward`.
  Wejście z WAN to Access, gdy hostname jest.
- Obraz jest digestem. Tag pływający przepina binarium pod tym samym Deploymentem.
- Wykres grupuje po `service_name` zgodnym z komponentem. Nazwa poda ReplicaSet gasi szereg
  przy rolloutcie.
- `mobile` nie ma panelu poda. Numer telefonu jest na ekranie O aplikacji.
- Logów aplikacji Grafana nie magazynuje. Loki i Promtail nie wchodzą w tym numerze.
- Dashboard wersji pokazuje tag z zasobu OTEL. Nie wylicza wersji z nazwy obrazu, gdy
  atrybut jest obecny.
- Aspire dashboard zostaje narzędziem laptopa. Ten pod go nie zastępuje i na laptopa nie
  wraca.
- Żądania to 100m CPU i 256 MiB pamięci. Brak requestu pamięci pozwala wpisać pod „za darmo”
  na węźle 16 GiB.
- Zapytanie żądań w toku to `jjdevhub:http_server_active_requests:sum`. Surowa nazwa SDK nie
  jest nazwą panelu.

## Poza zakresem

- Collector, nazwy metryk po eksporcie i atrybut `service.version` są w
  [10-opentelemetry.md](10-opentelemetry.md). Ten numer nie zmienia SDK i nie dopisuje
  licznika w usłudze.
- Retencja Prometheusa, scrape `:8889` i rekord `jjdevhub:http_server_active_requests:sum`
  są w [11-prometheus.md](11-prometheus.md). Ten numer woła rekord. Nie pisze reguły drugi
  raz.
- Magazyn śladów, Badger i UI Jaegera są w [12-jaeger.md](12-jaeger.md). Grafana tylko
  linkuje do `trace_id`. Nie skraca retencji 7 dni i nie zmienia samplingu.
- Tunel i Access są w [09-cloudflare.md](09-cloudflare.md). Ten numer nie tworzy hostname.
  Używa go, gdy już jest, i wtedy ustawia `GF_SERVER_ROOT_URL`.
- Przechowanie hasła Grafany w OpenBao wolno dodać w [14-openbao.md](14-openbao.md) bez
  zmiany wykresów. Ten numer działa wcześniej, więc Secret Kubernetes wystarcza do
  zamknięcia.
- HPA jest w [15-skalowanie.md](15-skalowanie.md). Wykres ma wytrzymać drugi pod tego samego
  `service_name`. Sam Deployment `grafana` HPA nie dostaje.
- Porównanie wykresu z `GET /versions` przy rolloutcie jest w [16-deploy.md](16-deploy.md).
  Ten numer nie podmienia obrazu i nie woła `kubectl set image`.
- Wygląd strony i stopka wersji są we froncie. Grafana nie jest stroną produktu i nie
  serwuje `web-vX.Y.Z`.
- Ten numer nie wstawia do JSON hasła, tokenu API ani connection stringa. Token na czas
  testu powstaje w UI i jest kasowany.

## Źródła

- [Provisioning datasource](https://grafana.com/docs/grafana/latest/administration/provisioning/#data-sources).
  Wiążący jest plik YAML ładowany przy starcie oraz pola `uid`, `url`, `isDefault` i
  `editable`. Dotyczy `datasources.yaml`: Prometheus `uid` `prometheus` na
  `http://prometheus.jjdevhub.svc.cluster.local:9090` jako domyślny i nieedytowalny, Jaeger
  `uid` `jaeger` na porcie `16686` jako nieedytowalny. Ze źródła nie bierzemy datasource z
  hasłem w pliku ani edycji adresu w UI. Oba Service wewnątrz namespace hasła nie mają.
- [Provisioning dashboardów](https://grafana.com/docs/grafana/latest/administration/provisioning/#dashboards).
  Wiążące jest ładowanie JSON z katalogu przy starcie oraz `allowUiUpdates`. Dotyczy
  `jjdevhub-uslugi.json`, `jjdevhub-wersje.json` i wartości `false`, która zostawia wydanie
  wykresu w git. Ze źródła nie bierzemy zapisu dashboardu wyłącznie w UI i nie bierzemy
  biblioteki cudzych paneli o innych nazwach metryk.
- [Datasource Prometheus](https://grafana.com/docs/grafana/latest/datasources/prometheus/).
  Wiążące jest zapytanie PromQL wysyłane przez Grafanę do istniejącego serwera, w trybie
  `proxy`. Dotyczy paneli ruchu i wersji oraz tego, że Grafana nie scrapuje podów. Ze źródła
  nie bierzemy remote write do chmury, nie bierzemy drugiego Prometheusa i nie bierzemy
  metryki dokładanej w usłudze tylko po to, żeby panel miał serie.
- [Datasource Jaeger](https://grafana.com/docs/grafana/latest/datasources/jaeger/). Wiążące
  jest przejście do drzewa śladu, nie magazyn śladu w Grafanie. Dotyczy linku po `trace_id`
  na `uid` `jaeger` i adresu `http://jaeger.jjdevhub.svc.cluster.local:16686`. Ze źródła nie
  bierzemy kopii spanów w Grafanie i nie bierzemy zmiany samplingu. Retencja zostaje przy
  Jaegerze.
- [Konfiguracja serwera](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/).
  Wiążące są `GF_SERVER_ROOT_URL`, hasło administratora ze zmiennej i wyłączenie anonimowego
  dostępu. Dotyczy `secretKeyRef` na `GF_SECURITY_ADMIN_PASSWORD`,
  `GF_AUTH_ANONYMOUS_ENABLED=false` oraz ustawiania root URL tylko przy hostname. Ze źródła
  nie bierzemy hasła `admin` wpisanego w manifeście i nie bierzemy root URL wskazującego
  adres gościa, gdy hostname nie istnieje.
- [Zmienne środowiska konfiguracji](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/#override-configuration-with-environment-variables).
  Wiążące jest nadpisanie pliku konfiguracyjnego zmienną `GF_`. Dotyczy trzech zmiennych
  tego Deploymentu i zakazu trzymania hasła w `grafana.ini` w git. Ze źródła nie bierzemy
  całego katalogu przełączników. Proces dostaje tylko te, które ten numer nazwał.
- [Uwierzytelnienie i anonimowy dostęp](https://grafana.com/docs/grafana/latest/setup-grafana/configure-access/configure-authentication/).
  Wiążące jest to, że anonimowy dostęp jest osobnym włącznikiem, domyślnie niebezpiecznym
  przy wejściu z boku. Dotyczy scenariusza `port-forward`, który omija Cloudflare Access. Ze
  źródła nie bierzemy logowania wyłącznie kontem zewnętrznym jako jedynego zabezpieczenia
  procesu i nie bierzemy konta czytelnika strony.
- [Licencja Grafany](https://github.com/grafana/grafana/blob/main/LICENSE). Wiążące jest
  wydanie open source na AGPL-3.0, nie oferta chmurowa. Dotyczy jednego procesu na własnej
  maszynie operatora. Ze źródła nie bierzemy Grafana Cloud i nie bierzemy dystrybucji
  binarium czytelnikowi. AGPL zostaje przy procesie, który nie opuszcza maszyny.
- [Tekst AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html). Wiążący jest obowiązek
  licencji przy dystrybucji programu. Dotyczy decyzji, że obraz zostaje na VM i nie jest
  częścią strony CV. Ze źródła nie bierzemy wykładni dla kodu usług JJDevHub. Usługi mają
  własne licencje z listy w README. Ten plik dotyczy tylko procesu Grafany.
- [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/). Wiążące
  jest trzymanie wartości poza manifestem w git i podanie jej do kontenera przez
  `secretKeyRef`. Dotyczy Secreta `grafana-admin` i klucza `admin-password`. Ze źródła nie
  bierzemy `stringData` z hasłem w repozytorium i nie bierzemy traktowania base64 jako
  ochrony. Secret nie zastępuje OpenBao dla haseł baz.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest typ ClusterIP i stała nazwa DNS wewnątrz namespace. Dotyczy
  `grafana.jjdevhub.svc.cluster.local` na porcie 3000 oraz tego, że przeglądarka spoza
  klastra sama tego adresu nie widzi. Ze źródła nie bierzemy NodePort i nie bierzemy
  `externalIPs` na adres gościa.
- [Kubernetes Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
  Wiążąca jest jedna replika i szablon poda z żądaniami. Dotyczy Deploymentu `grafana`, 100m
  CPU i 256 MiB pamięci. Ze źródła nie bierzemy HPA na ten Deployment i nie bierzemy drugiej
  repliki „na zapas”.
- [Obraz po digescie](https://kubernetes.io/docs/concepts/containers/images/#image-names).
  Wiążące jest przypięcie obrazu do `sha256`, nie do tagu, który da się przepiąć. Dotyczy
  pola obrazu w `grafana.yaml`. Ze źródła nie bierzemy `:latest` ani tagu ruchomego jako
  jedynej referencji na klastrze.
- [Trwały wolumen](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). Wiążące
  jest oddzielenie dysku poda od obrazu. Dotyczy PVC `10Gi` na katalog danych UI. Ze źródła
  nie bierzemy trzymania definicji dashboardu wyłącznie na PVC. JSON zostaje w git. Utrata
  wolumenu nie jest utratą wykresu opisanego w repozytorium.
- [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/). Wiążące jest
  montowanie plików konfiguracyjnych do kontenera bez przebudowy obrazu. Dotyczy
  provisioningu datasource i dashboardów. Ze źródła nie bierzemy wrzucania hasła do
  ConfigMap. Hasło idzie Secretem.
- [Port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).
  Wiążące jest tymczasowe wejście z LAN do Service, bez otwierania portu na gościu. Dotyczy
  `kubectl -n jjdevhub port-forward svc/grafana 3000:3000` i logowania hasłem z Secreta. Ze
  źródła nie bierzemy zostawienia forwardu jako publikacji i nie bierzemy traktowania go
  jako zamiennika Access z WAN.
- [API datasource](https://grafana.com/docs/grafana/latest/developers/http_api/data_source/).
  Wiążące jest `GET /api/datasources` jako sprawdzenie tego, co provisioning wczytał.
  Dotyczy testu z nagłówkiem bearer, tokenu tworzonym na czas sprawdzenia i kasowanym. Ze
  źródła nie bierzemy tokenu w git i nie bierzemy tego API jako drogi, którą aplikacja
  publikuje metryki.
- [API wyszukiwania dashboardów](https://grafana.com/docs/grafana/latest/developers/http_api/folder_dashboard_search/).
  Wiążące jest `GET /api/search` jako lista tego, co pod naprawdę załadował. Dotyczy
  obecności `jjdevhub-uslugi` i `jjdevhub-wersje` oraz odmowy przy żądaniu anonimowym. Ze
  źródła nie bierzemy tworzenia dashboardu przez POST. Wydaniem zostaje plik w git.
- [Linki danych panelu](https://grafana.com/docs/grafana/latest/panels-visualizations/configure-data-links/).
  Wiążące jest przejście z punktu wykresu do innego źródła po polu z zapytania. Dotyczy
  `dataLink` na datasource `jaeger` i pola `trace_id`. Ze źródła nie bierzemy linku na
  zewnątrz maszyny i nie bierzemy wklejania ciała logu do URL.
- [Reguły rejestrujące](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/).
  Wiążąca jest stabilna nazwa rekordu, którego panel nie przepisuje. Dotyczy zapytania
  `jjdevhub:http_server_active_requests:sum` z numeru 11. Ze źródła nie bierzemy nowej
  reguły w tym numerze i nie bierzemy surowej nazwy SDK jako nazwy panelu, gdy rekord już
  jest.
- [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/). Wiążące jest
  grupowanie i filtr po etykiecie. Dotyczy `service_name` oraz zakazu stałej z nazwą poda.
  Ze źródła nie bierzemy sumy bez etykiety komponentu. Pięć usług zlewa się wtedy w jedną
  kreskę.
- [Instalacja na Kubernetes](https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/).
  Wiążące jest to, że proces da się postawić jako Deployment z provisioningiem z plików.
  Dotyczy jednego poda, Service i montowania katalogu konfiguracji. Ze źródła nie bierzemy
  Helma jako źródła prawdy obok manifestu w git i nie bierzemy recepty, która wystawia
  Service publicznie.
- [Grafana OSS](https://grafana.com/oss/grafana/). Wiążące jest rozróżnienie wydania open
  source od oferty hostowanej. Dotyczy decyzji o jednym podzie na tej VM. Ze źródła nie
  bierzemy listy wtyczek enterprise i nie bierzemy chmury jako magazynu.
- [`openssl rand`](https://docs.openssl.org/master/man1/openssl-rand/). Wiążące jest
  losowanie bajtów do hasła, które nie powstaje w repozytorium. Dotyczy
  `openssl rand -base64 24` przy tworzeniu Secreta `grafana-admin`. Ze źródła nie bierzemy
  hasła wpisanego literalnie w polecenie, które potem ląduje w pliku w git.

## Gotowe gdy

- Deployment `grafana` jest Ready, jedna replika, obraz po digescie, żądania 100m CPU i 256
  MiB pamięci.
- Service ma typ ClusterIP i port 3000. `nc -vz <adres-gościa> 3000` z sieci spoza LAN nie
  łączy.
- W git są oba pliki JSON, `datasources.yaml` i `dashboards.yaml` z `allowUiUpdates: false`.
  UI pokazuje datasource Prometheus i Jaeger jako zdrowe, z `uid` `prometheus` i `jaeger`.
- Zapytanie `jjdevhub:http_server_active_requests:sum` z panelu nie zwraca błędu źródła.
  Pusty wektor przy zerowych replikach aplikacji jest poprawny.
- `git grep` nie znajduje literału hasła administratora. Deployment ma `secretKeyRef`, nie
  wartość.
- Anonimowe żądanie do UI wewnątrz klastra nie dostaje danych dashboardu.
  `GF_AUTH_ANONYMOUS_ENABLED` jest `false`.
- Gdy hostname z numeru 09 istnieje, `GF_SERVER_ROOT_URL` jest jego adresem `https`, a
  żądanie bez Access nie pokazuje paneli.
- YARP nie ma trasy do Grafany. W manifestach tego numeru nie ma Loki, Promtail ani
  odbiornika OTLP.
- `mobile` nie ma panelu poda. Wykres usług grupuje po `service_name`, nie po nazwie poda.
- HPA o nazwie `grafana` nie istnieje.
