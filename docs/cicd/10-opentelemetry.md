# 10. OpenTelemetry

[Spis CI/CD](README.md) · poprzedni: [09. Cloudflare](09-cloudflare.md) · następny: [11. Prometheus](11-prometheus.md)

Ten numer stawia na maszynie odbiornik OTLP. Instrumentacja zostaje w
`JJDevHub.ServiceDefaults` i jest jedyną. Poprzedni plik,
[09-cloudflare.md](09-cloudflare.md), daje stronie nazwę i zamyka porty gościa. Następny,
[11-prometheus.md](11-prometheus.md), zaczyna scrapować metryki, które collector tu wystawi.
W kolejności pracy numer idzie po [Aspire](../api/01-aspire.md). Maszyna i tunel
już stoją. Bramki gita i tagi wersji są już w [07-wersje.md](07-wersje.md).

Lokalnie te same sygnały zbiera dashboard Aspire. Na laptopie `aspire run` sam ustawia
`OTEL_EXPORTER_OTLP_ENDPOINT` na dashboard. Na maszynie ten sam hak czyta adres collectora z
manifestu. AppHost na produkcję nie jedzie. Ten numer nie dokłada drugiego SDK, nie wystawia
`/metrics` na usłudze i nie publikuje portu 4317 poza klaster.

Scenariusz, który bez collectora się rozpada, zaczyna się od tagu `news-v1.4.0` już
stojącego na k3s. Żądanie wchodzi przez bramę. Ślad, metryka i linia logu mają nieść ten sam
`trace_id` i tę samą nazwę komponentu, co na laptopie. Bez adresu OTLP w podzie proces albo
porzuca batche, albo ktoś wstawia klienta Prometheusa i klienta Jaegera do każdej usługi.
Dwa adresy i dwa formaty rozjadą nazwę tej samej metryki. Tu jest jeden collector w
namespace `jjdevhub` i jeden endpoint, który ServiceDefaults już umie użyć, gdy zmienna jest
ustawiona.

## Po co

Usługi na k3s mają oddać ślady, metryki i logi skorelowane z `trace_id`, tak jak na laptopie
przy `aspire run`. Na maszynie nie ma dashboardu Aspire. Jest adres OTLP.
`JJDevHub.ServiceDefaults` eksportuje, gdy `OTEL_EXPORTER_OTLP_ENDPOINT` jest niepusty. Brak
zmiennej oznacza brak eksportera, nie wyjątek przy starcie. Test laptopa zmiennej na
collector nie potrzebuje. Test maszyny bez tej zmiennej nie ma sygnału, choć proces HTTP
żyje.

Collector jest Deploymentem o jednej replice. Przyjmuje OTLP gRPC na 4317. Wystawia metryki
w formacie Prometheus na 8889. Ślady wysyła OTLP do Jaegera, gdy ten już stoi. Awaria
collectora gubi sygnał z okna awarii. Nie gubi żądania HTTP. Eksport jest asynchroniczny i
nie wydłuża odpowiedzi o zapis do Jaegera. Gotowość poda collectora nie zależy od tego, czy
Jaeger odpowiada.

Prometheus jako magazyn metryk dochodzi w numerze 11. Jaeger jako magazyn śladów dochodzi w
numerze 12. Wykresy dochodzą w numerze 13. HPA od `http_server_active_requests` dochodzi w
numerze 15 i czyta rekord, nie surową nazwę z procesu. Ten numer pilnuje, żeby metryka w
ogóle wypłynęła pod stabilną nazwą i żeby `service.name` było nazwą komponentu, a
`service.version` pełnym tagiem.

Bez tego numeru numer 11 nie ma kogo scrapować, a numer 12 nie ma skąd wziąć drzewa.
Dashboard Aspire zostaje odbiornikiem laptopa i nie staje się magazynem maszyny. Laptop nie
wysyła telemetrii na VM. VM nie wysyła telemetrii na dashboard laptopa.

## Dlaczego ta technologia

### Zostaje eksport z ServiceDefaults

`JJDevHub.ServiceDefaults` rejestruje OpenTelemetry: instrumentację ASP.NET Core,
`HttpClient` i runtime oraz eksporter OTLP. Zasób niesie `service.name`. Wersja procesu, gdy
obraz pochodzi z tagu, wchodzi jako `service.version`. `AddOpenTelemetry` jest wołane z tej
biblioteki. `Program.cs` Identity, News, Learning, Cv, Contact, Gateway i weba tego
wywołania nie powtarza. Pakiet `OpenTelemetry.Exporter.Prometheus` nie wchodzi do `csproj`
ani do `Directory.Packages.props`.

Osobna rejestracja w `Program.cs` każdej usługi odpada. Byłaby drugą historią
instrumentacji: inne nazwy metryk, inny sampling, inny brak `trace_id` w logu. Eksporter
Prometheus w procesie, czyli `/metrics` na każdej usłudze, odpada z tego samego powodu. Dwa
formaty tej samej liczby rozjeżdżają scrape z numeru 11 i wykres z numeru 13. Jeśli którejś
usługi brakuje odwołania do ServiceDefaults, to brak z numeru Aspire w `docs/api`, nie
okazja do lokalnej instrumentacji. Ten numer sprawdza, że odwołanie jest, i ustawia zmienną
środowiskową.

Scenariusz rozjazdu jest konkretny. News dostaje własny `AddOpenTelemetry` i licznik o innej
nazwie niż `http.server.active_requests`. Na laptopie dashboard widzi serię ze
ServiceDefaults. Na maszynie collector widzi drugą. `GET /versions` mówi `news-v1.4.0`, a
wykres nie ma tej serii albo ma dwie. Poprawka jest jedna: usunąć lokalną rejestrację i
zostawić bibliotekę wspólną. Collector tej poprawki nie zrobi.

Koszt: collector jest dodatkowym podem. Okno, w którym pod collectora nie działa, jest
dziurą w metryce i w śladzie, nie dziurą w odpowiedzi HTTP. Żądanie czytelnika nie czeka na
Jaegera. Log aplikacji i tak idzie na stdout. `trace_id` w tej linii jest mostem, gdy
magazyn śladów wróci.

### Collector jako jedyny odbiornik na VM

OpenTelemetry Collector przyjmuje OTLP gRPC na `0.0.0.0:4317` wewnątrz klastra. Aplikacje
ustawiają `OTEL_EXPORTER_OTLP_ENDPOINT` na
`http://otel-collector.jjdevhub.svc.cluster.local:4317` i `OTEL_EXPORTER_OTLP_PROTOCOL` na
`grpc`. Schemat `http` przy gRPC oznacza tu brak TLS na odcinku pod–collector. Odcinek nie
opuszcza namespace. Service jest ClusterIP. NodePort dla 4317 nie powstaje. Tunel z numeru
09 nie dostaje hostname’u OTLP. Z sieci spoza LAN `nc` na 4317 adresu gościa nie łączy.

Obraz jest przypięty do digestu. Potok metryk używa eksportera Prometheus, więc digest jest
digestem obrazu, który ten eksporter wczytuje. README komponentu wskazuje dystrybucje, w
których on jest. Przy pierwszym wdrożeniu digest wpisuje operator po odczycie z rejestru,
tak jak przy innych obrazach numeru 16. Tag pływający jako jedyna referencja odpada.

Bezpośredni eksport z poda do Jaegera i osobny scrape `/metrics` odpadają: dwa adresy w
każdej usłudze i dwa formaty do utrzymania. Hostowany collector poza maszyną odpada razem z
odrzuceniem chmury publicznej w numerze 08. Wpisanie adresu collectora na sztywno w
`appsettings.json` odpada, bo laptop i maszyna mają inny odbiornik. Adres żyje w zmiennej
procesu, którą na laptopie ustawia dashboard, a na maszynie manifest.

Koszt: konfiguracja potoków leży w ConfigMap i trzeba ją zmienić świadomie, gdy numer 11
albo 12 zmienia port magazynu. Zmiana potoku nie jest zmianą kodu usługi i nie wymaga nowego
tagu komponentu. Wymaga restartu poda collectora albo przeładowania, które ten obraz
udostępnia. Usługi przy tej zmianie nie są przebudowywane.

### Dwa potoki, jeden SDK

Potok `metrics` czyta OTLP i wystawia eksporter Prometheus na `0.0.0.0:8889`, ścieżka
`/metrics`. Potok `traces` czyta OTLP i wysyła OTLP na
`jaeger.jjdevhub.svc.cluster.local:4317` z `tls.insecure: true`. To `insecure` dotyczy
wyłącznie nazwy Service w klastrze. Nie dotyczy publicznego hostname’u i nie dotyczy odcinka
przeglądarka–Cloudflare. Potok `logs` jest włączony i kończy się na eksporterze `debug` z
`verbosity: basic` albo na eksporterze plikowym collectora. Nie idzie do Jaegera. Jaeger
przyjmuje ślady. Korelacja logu ze śladem jest w procesie: log na stdout niesie `trace_id`,
gdy ServiceDefaults spina `ILogger` ze śladem.

Wysyłanie metryk na port Jaegera odpada. Jaeger odrzuca ten sygnał, a batch wpada w
ponawianie i zatka kolejkę śladów. Jeden potok „wszystko na jeden adres” odpada z tej samej
przyczyny. Sampler w collectorze odpada. Polityka zostaje przy SDK, opisana w numerze 12
jako `parentbased_always_on`. Drugi sampler w collectorze pokazałby na maszynie inne drzewo
niż dashboard na laptopie.

Procesor `metricstransform` odpada, dopóki nazwa z SDK jest stabilna. Dodatkowa przemianowa
ukrywa różnicę między laptopem i VM. Eksporter Prometheus i tak zamienia kropki na
podkreślenia. Metryka żądań w toku nazywa się po eksporcie `http_server_active_requests`.
Czas trwania zostaje histogramem `http_server_request_duration_seconds` albo nazwą, którą
faktycznie emituje wersja instrumentacji ASP.NET Core przypięta w ServiceDefaults. Ten numer
zapisuje w ConfigMap komentarz z nazwą widoczną na `:8889/metrics`, spisaną z żywego
scrape’u, żeby numer 11 nie zgadywał.

`namespace` eksportera Prometheus zostaje puste. Prefiks zmieniłby
`http_server_active_requests` w inną nazwę i złamał rekord numeru 11 bez zmiany SDK.
Atrybuty `service.name` i `service.version` mają być widoczne na serii jako etykiety. Kropka
staje się podkreśleniem, więc `service.name` czyta się jako `service_name`. To nie jest
przemianowanie metryki. Gdy obraz przypięty digestem wymaga innego klucza na skopiowanie
atrybutu zasobu, klucz jest ten z README tego obrazu, a nazwa metryki zostaje. Komentarz ze
żywego tekstu jest sprawdzianem.

Koszt: do czasu numerów 11 i 12 eksporter metryk słucha w próżnię scrape’u, a eksporter
śladów loguje błąd połączenia z Jaegerem. Pod collectora ma być Ready mimo tego błędu.
Inaczej numer 10 nie da się zamknąć przed numerem 12. Probe gotowości patrzy na extension
`health_check` na porcie 13133 albo na równoważny endpoint obrazu. Nie patrzy na TCP do
Jaegera.

### Dashboard Aspire zostaje lokalnie

Przy `aspire run` dashboard Aspire jest odbiornikiem. Zmienna OTLP na laptopie wskazuje
dashboard, nie collector z VM. Manifest k3s nie jest używany lokalnie. AppHost nie jedzie na
produkcję, więc na VM tej zmiennej nie ustawia się na adres dashboardu.
`deployment.environment=production` jest tylko na maszynie. Dashboard laptopa tej wartości
nie dostaje. Dzięki temu sygnał z k3s nie miesza się z sygnałem z `aspire run`, gdy ktoś
kiedyś postawi oba obok siebie w jednym widoku.

Wyłączenie OTLP w ServiceDefaults „bo na produkcji jest Prometheus” odpada. Zostałby drugi
kod ścieżki: laptop ze śladem, maszyna bez śladu, albo maszyna z ręcznym licznikiem. Koszt:
deweloper nie ogląda na co dzień UI Jaegera. Ogląda dashboard Aspire. Jaeger służy do
maszyny i do incydentu na tagu, który już działa. Brak poda `otel-collector` na laptopie
jest stanem poprawnym, nie awarią składu.

Scenariusz pomyłki: ktoś wpisuje w AppHost adres
`otel-collector.jjdevhub.svc.cluster.local`, żeby „widzieć produkcję na laptopie”. Nazwa
Service nie istnieje poza klastrem. Skład lokalny albo milknie, albo ktoś wystawia 4317
NodePortem, czego ten numer zabrania. Laptop zostaje przy dashboardzie. Maszyna zostaje przy
collectorze. To są dwa odbiorniki jednego SDK, nie jeden odbiornik na dwa miejsca.

### Atrybuty zasobu

`service.name` jest nazwą komponentu: `identity`, `news`, `learning`, `cv`, `contact`,
`gateway`, `web`. Ustawia je `OTEL_SERVICE_NAME`. `service.version` jest pełnym tagiem, na
przykład `news-v1.4.0`, nie samym `1.4.0` i nie numerem bez nazwy komponentu. Dzięki temu
linia na wykresie zestawia się z odpowiedzią `GET /versions` bez tłumaczenia.
`deployment.environment` ma wartość `production` na maszynie. Obie wartości jadą w
`OTEL_RESOURCE_ATTRIBUTES`. `OTEL_SERVICE_NAME` nie jest powtórzony wewnątrz tej drugiej
zmiennej.

Wspólne `service.name=jjdevhub` dla wszystkich podów odpada. Pięć usług zlałoby się w jeden
szereg, a rekord numeru 11 zsumowałby News z bramą. Nazwa typu CLR albo nazwa Deploymentu z
sufiksem ReplicaSet odpada, bo łamie słownik komponentów z numeru 07. Pusty `service.name`
odpada tak samo: seria bez komponentu nie da się podzielić HPA per usługa.

Przykład w manifeście, zanim numer 16 podstawi prawdziwy tag, wolno zapisać jako wzór `news`
i `news-v0.0.0`. Na żywym podzie o replice większej niż zero `OTEL_SERVICE_NAME` jest nazwą
komponentu, a `service.version` jest tagiem wdrażanym w tym samym kroku co digest obrazu.
Przy `replicas: 0` zmienną wolno zostawić jako wzór. Nie wolno jej usunąć, gdy repliki
rosną. Obraz zbudowany z innym numerem w stopce niż w zasobie OTEL jest błędem deployu, nie
błędem collectora.

Koszt: każdy Deployment w `deploy/k3s/apps/` niesie cztery zmienne. Literówka w nazwie
komponentu jest osobnym szeregiem, którego HPA nie zobaczy pod oczekiwaną etykietą.
Sprawdzenie jest grepem po manifeście i, przy żywej replice, po środowisku procesu.

### Porty, które zostają w klastrze

| Port | Sygnał | Kto łączy |
| --- | --- | --- |
| 4317 | OTLP gRPC | Pody aplikacji do collectora |
| 8889 | Metryki w formacie Prometheus | Prometheus z numeru 11 |
| 13133 | Gotowość procesu collectora | Probe poda, nie scrape aplikacji |

Port 4317 Jaegera to inny Service, `jaeger`, i łączy się z nim wyłącznie collector.
Aplikacja do 4317 Jaegera nie łączy. Własne metryki procesu collectora, jeśli obraz słucha
na innym porcie niż 8889, nie są scrape’em aplikacji i nie są źródłem
`http_server_active_requests`. Numer 11 ma jeden target aplikacji: `otel-collector:8889`.

Żądania poda: 100m CPU i 256 MiB pamięci. Jedna replika. HPA tego Deploymentu nie ma. Limit,
którego ten numer nie podnosi ponad potrzebę probe, nie może zależeć od Jaegera: proces ma
być Ready przy błędzie eksportu śladów.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `JJDevHub.ServiceDefaults` | Jedyna rejestracja OpenTelemetry i eksporter OTLP |
| `deploy/k3s/observability/otel-collector.yaml` | Deployment, Service ClusterIP i ConfigMap collectora |
| `deploy/k3s/apps/*` | Zmienne `OTEL_*` na podach; digest obrazu aplikacji należy do numeru 16 |

Service `otel-collector` jest ClusterIP. Nie ma NodePort i nie ma LoadBalancer. Plik
manifestu trzyma obraz po digescie, `replicas: 1` i brak obiektu HPA. ConfigMap jest w tym
samym pliku albo w pliku obok, wskazanym przez tę ścieżkę. Zmiana potoku metryk albo śladów
przechodzi przez ten ConfigMap, nie przez kod usługi.

Konfiguracja potoków:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
processors:
  batch: {}
exporters:
  prometheus:
    endpoint: 0.0.0.0:8889
  otlp/jaeger:
    endpoint: jaeger.jjdevhub.svc.cluster.local:4317
    tls:
      insecure: true
  debug:
    verbosity: basic
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
service:
  extensions: [health_check]
  pipelines:
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/jaeger]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
```

Komentarz w tym ConfigMap, dopisany po pierwszym żywym odczycie `:8889/metrics`, podaje
nazwę metryki żądań w toku i nazwę histogramu czasu. Dopóki SDK jest stabilne, komentarz nie
jest poleceniem dopisania `metricstransform`. `tls.insecure: true` nie wychodzi poza
klaster. Eksporter `debug` nie jest magazynem logów. Magazynem linii z `trace_id` zostaje
stdout kontenera usługi.

## Plan

### 1. Zostaw ServiceDefaults

Nie dodawaj pakietu eksportera Prometheus do usług. Nie duplikuj `AddOpenTelemetry` w
`Program.cs` Identity, News, Learning, Cv, Contact, Gateway ani weba. Nie dopisuj licznika
obok biblioteki. Jeśli odwołania do `JJDevHub.ServiceDefaults` brakuje, uzupełnij je tak,
jak wymaga numer Aspire, i nie zakładaj tu drugiej instrumentacji.

Sprawdzenie z katalogu repozytorium:

```bash
git grep -n "OpenTelemetry.Exporter.Prometheus" -- "*.csproj" "*.props" || true
git grep -n "AddOpenTelemetry" -- "*.cs"
```

Pierwsze polecenie nic nie wypisuje. Drugie wypisuje wyłącznie pliki w
`JJDevHub.ServiceDefaults` oraz test tego projektu, jeśli numer Aspire go dodał. Trafienie w
`Program.cs` usługi jest błędem tego numeru.

### 2. Collector

Zastosuj `deploy/k3s/observability/otel-collector.yaml`. Obraz collectora jest digestem
dystrybucji, która wczytuje eksporter `prometheus` i eksporter `otlp`. Jedna replika.
Żądania: 100m CPU, 256 MiB pamięci. Probe gotowości: port 13133 przy extension
`health_check` albo równoważny endpoint obrazu. Probe nie wywołuje Jaegera.

```bash
kubectl -n jjdevhub apply -f deploy/k3s/observability/otel-collector.yaml
kubectl -n jjdevhub rollout status deploy/otel-collector
```

Gdy Jaegera jeszcze nie ma, log eksportu śladów może zgłaszać odmowę połączenia. Pod ma mimo
to być Ready, a `:8889/metrics` ma odpowiadać z wnętrza klastra. Nie dodawaj procesora
samplera. Nie kieruj metryk na `jaeger:4317`. Nie ustawiaj `namespace` w eksporterze
Prometheus.

### 3. Zmienne na Deploymentach

W manifeście każdego komponentu klastrowego ustaw cztery zmienne. Wzór dla News, z tagiem
zastępczym, zanim numer 16 wstawi tag wydania:

```yaml
env:
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: http://otel-collector.jjdevhub.svc.cluster.local:4317
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: grpc
  - name: OTEL_SERVICE_NAME
    value: news
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: service.version=news-v0.0.0,deployment.environment=production
```

Na żywym podzie `OTEL_SERVICE_NAME` jest nazwą komponentu z listy, a `service.version` jest
pełnym tagiem, na przykład `news-v1.4.0`. `deployment.environment=production` zostaje. Przy
`replicas: 0` wzór wolno zostawić. Przy wzroście replik zmiennych nie usuwaj i nie zostawiaj
`news-v0.0.0`, gdy digest obrazu jest już z innego tagu. To samo powtórz dla `identity`,
`learning`, `cv`, `contact`, `gateway` i `web`, każdemu z własną nazwą.

### 4. Nazwa na `:8889/metrics`

Po starcie collectora, z poda w namespace, pobierz tekst metryk. W ConfigMap zapisz
komentarz z nazwą, którą widać. Oczekiwany człon żądań w toku to
`http_server_active_requests`. Jeśli instrumentacja emituje inną surową nazwę, komentarz
podaje tę nazwę, a numer 11 zmienia `expr` rekordu. Nazwy rekordu ten numer nie nadaje.
Nadaje ją numer 11 i jej nie zmienia.

Nie dopisuj `metricstransform`, żeby wymusić nazwę, którą SDK już wystawia stabilnie. Nie
włączaj `/metrics` na Service aplikacji. Probe usług zostają na `/health`.

### 5. Log i ślad

Log aplikacji zostaje na stdout kontenera. `kubectl logs` wystarcza na jednym węźle.
Collector nie staje się drugim magazynem logów. Wymaganie jest jedno: wpis logu przy błędzie
żądania zawiera `trace_id`. Sprawdzenie, że ten identyfikator otwiera drzewo w Jaegerze,
jest w numerze 12. Tu wystarczy, że ServiceDefaults nie jest wyłączone i że atrybut zasobu
nie gubi nazwy usługi.

Na laptopie osobno: `aspire run` pokazuje ślad żądania w dashboardzie Aspire bez poda
`otel-collector` na maszynie. To sprawdzenie nie używa `kubectl`.

### Co jest do czego

`JJDevHub.ServiceDefaults` woła każdy host usługi i brama, przez `AddServiceDefaults`. Jest
jedynym SDK telemetrii. Gdy go nie ma w danym `Program.cs`, ta usługa albo milczy, albo ma
własną rejestrację. Własna rejestracja jest błędem tego numeru. AppHost tej biblioteki nie
używa jako miejsca, w którym „naprawia się” brak sygnału na VM.

Service `otel-collector:4317` jest wołany przez zmienną `OTEL_EXPORTER_OTLP_ENDPOINT`
procesu aplikacji. Gdy Service nie istnieje albo nie jest ClusterIP, batch nie ma dokąd iść,
a wystawienie NodePortem łamie zamknięcie portu z numeru 09. Dashboard Aspire tego Service’u
nie woła.

Eksporter `:8889` jest wołany przez Prometheus z numeru 11. Gdy słucha na innym porcie albo
dostaje prefiks `namespace`, scrape albo milczy, albo zapisuje inną nazwę niż
`http_server_active_requests`. HPA z numeru 15 wtedy nie widzi rekordu, którego się
spodziewa.

Eksporter `otlp/jaeger` jest wołany przez potok śladów. Cel to
`jaeger.jjdevhub.svc.cluster.local:4317`. Gdy cel nie odpowiada, log collectora to pokazuje,
a probe 13133 nadal może być zielony. Aplikacja tego adresu nie dostaje w środowisku.
Podmiana tego endpointu na publiczną nazwę wynosi ślad poza klaster.

`OTEL_SERVICE_NAME` jest wołane przez SDK przy starcie procesu. Collector i potem Grafana
czytają je jako komponent. Zła wartość zlewa szeregi albo tworzy szereg spoza słownika.
`service.version` jest wołane przy tym samym starcie. Numer 16 ma je podstawić razem z
digestem. Rozjazd stopki i zasobu jest błędem deployu.

`deployment.environment=production` jest wołane tylko na maszynie. Odróżnia sygnał k3s od
laptopa. Wpisanie tej wartości do profilu `aspire run` miesza dwa światy w jednym atrybucie.

Dashboard Aspire jest wołany przez `aspire run` na laptopie. Nie jest wołany przez manifest
k3s. Wyłączenie haka OTLP w ServiceDefaults, żeby „zostawić tylko Prometheusa”, gasi ślad
także na laptopie.

Extension `health_check` na 13133 jest wołany przez probe kubeleta. Mówi, że proces
collectora żyje. Nie mówi, że Jaeger przyjął batch. Związanie probe z Jaegerem blokuje
zamknięcie tego numeru przed numerem 12 i kasuje metryki razem ze śladami.

## Testy

Testy tego numeru są operacyjne plus jeden grep po drzewie. Nie ma tu cechy
`Category=Integration` na fakt domenowy. NBomber dochodzi w numerze testów API i nie mierzy
tego collectora. Padnięcie ma konkretny objaw: pod nie jest Ready, `:8889` nie zwraca
tekstu, w Deploymentcie brakuje endpointu, `AddOpenTelemetry` jest poza ServiceDefaults,
albo port 4317 widać z zewnątrz.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | ConfigMap z dwoma potokami sygnałów aplikacji i potokiem logów poza Jaegera, obraz po digescie, Service ClusterIP, zmienne `OTEL_*` w manifestach `deploy/k3s/apps/` |
| Działanie (act) | `rollout status`, odczyt `:8889/metrics` z poda pomocniczego, grep po `csproj` i po `AddOpenTelemetry`, `nc` na 4317 spoza LAN |
| Sprawdzenie (assert) | pod Ready bez względu na Jaegera, tekst Prometheusa z wnętrza klastra, brak eksportera Prometheus w pakietach, brak nasłuchu 4317 na gościu |

1. Collector jest Ready, porty słuchają tylko w klastrze.

```bash
kubectl -n jjdevhub rollout status deploy/otel-collector
kubectl -n jjdevhub get svc otel-collector -o wide
kubectl -n jjdevhub get endpoints otel-collector
```

`TYPE` to ClusterIP. Endpointy mają 4317 i 8889. `replicas` dostępne to 1. Brak HPA o nazwie
`otel-collector`. Obraz w manifeście zawiera `@sha256:`. Gdy pod jest `Ready` przy błędzie
połączenia do Jaegera w logu, probe jest ustawiony właściwie. Gdy pod nie wstaje, dopóki
Jaeger nie istnieje, probe jest związane ze złą zależnością i ten numer nie jest domknięty.

2. Z poda w namespace da się pobrać tekst metryk collectora, nawet przy zerowym ruchu
aplikacji.

```bash
kubectl -n jjdevhub run otel-curl --rm -it --restart=Never --image=curlimages/curl:8.10.1 -- \
  curl -fsS http://otel-collector.jjdevhub.svc.cluster.local:8889/metrics
```

Odpowiedź jest tekstem Prometheus. Publiczny `curl` na adres gościa i na hostname strony nie
sięga tego portu. Nazwę żądań w toku z tej odpowiedzi wpisz w komentarz ConfigMap.
Oczekiwany człon to `http_server_active_requests`. Inna nazwa nie uruchamia
`metricstransform`. Uruchamia komentarz i, w numerze 11, zmianę `expr`.

3. Gdy którykolwiek pod aplikacji ma replikę większą niż zero, w jego środowisku jest adres
collectora i pełny tag.

```bash
kubectl -n jjdevhub set env deploy/news --list | grep OTEL_
```

`OTEL_EXPORTER_OTLP_ENDPOINT` wskazuje
`http://otel-collector.jjdevhub.svc.cluster.local:4317`. `OTEL_EXPORTER_OTLP_PROTOCOL` to
`grpc`. `OTEL_SERVICE_NAME` to `news`. `service.version` jest pełnym tagiem, na przykład
`news-v1.4.0`, zgodnym z obrazem, który numer 16 postawił.
`deployment.environment=production` jest obecne. Dla Deploymentu o zerowej replice sprawdź
manifest w git, nie żywy proces. Ten sam zestaw, z własną nazwą, dotyczy `identity`,
`learning`, `cv`, `contact`, `gateway` i `web`.

4. W solution nie ma drugiego eksportera.

```bash
git grep -n "OpenTelemetry.Exporter.Prometheus" -- "*.csproj" "*.props" || true
git grep -n "AddOpenTelemetry" -- "*.cs"
```

Pierwsze polecenie nic nie wypisuje, także w `Directory.Packages.props`. Drugie wypisuje
wyłącznie `JJDevHub.ServiceDefaults` i ewentualny test tej biblioteki. Trafienie w projekcie
usługi jest powodem, żeby usunąć duplikat, nie żeby dopisać scrape `/metrics`.

5. Na laptopie `aspire run` nadal pokazuje ślad żądania w dashboardzie Aspire, bez poda
`otel-collector` na maszynie. Manifest k3s nie jest warunkiem tego sprawdzenia. Zmienna
laptopa nie wskazuje Service’u z VM.

6. Z sieci spoza LAN porty collectora nie łączą.

```bash
nc -vz <adres-gościa> 4317
nc -vz <adres-gościa> 8889
```

Oba kończą się odmową albo brakiem trasy. Hostname strony nie ma public hostname OTLP. To
domknięcie numeru 09 na porcie, który ten numer otwiera tylko wewnątrz klastra.

7. Log stdout przy błędzie żądania, gdy jakaś replika usługi już stoi, zawiera `trace_id`.
Brak identyfikatora naprawia się w ServiceDefaults, nie filtrem collectora i nie drugim SDK.
Drzewo w Jaegerze nie jest warunkiem tego punktu, jeśli numer 12 jeszcze nie stoi.

## Zasady

- Jedna instrumentacja: ServiceDefaults. Usługa nie rejestruje drugiego SDK.
  `AddOpenTelemetry` poza tą biblioteką jest duplikatem.
- Na VM odbiornikiem jest collector. Na laptopie odbiornikiem jest dashboard Aspire. Adres
  nie jest wpisany w `appsettings.json`.
- Aplikacja nie wystawia `/metrics` pod scrape Prometheusa i nie referencjonuje
  `OpenTelemetry.Exporter.Prometheus`.
- `service.name` jest nazwą komponentu z listy: `identity`, `news`, `learning`, `cv`,
  `contact`, `gateway`, `web`.
- `service.version` jest pełnym tagiem tego komponentu, na przykład `news-v1.4.0`, w
  kształcie `<komponent>-vX.Y.Z`.
- `deployment.environment=production` jest ustawione na maszynie i nie jest ustawione jako
  sposób oglądania laptopa.
- `OTEL_EXPORTER_OTLP_ENDPOINT` to `http://otel-collector.jjdevhub.svc.cluster.local:4317`,
  a protokół to `grpc`.
- OTLP nie dostaje public hostname ani NodePort. Porty 4317 i 8889 nie słuchają na adresie
  gościa.
- Metryki i ślady idą osobnymi potokami. Metryki nie idą na port Jaegera. Ślady nie idą na
  8889.
- `tls.insecure: true` dotyczy wyłącznie `jaeger.jjdevhub.svc.cluster.local:4317` wewnątrz
  klastra.
- Log zostaje na stdout i niesie `trace_id`. Collector nie jest magazynem logów tego numeru.
- Eksport nie blokuje żądania HTTP. Padnięcie collectora nie jest padnięciem odpowiedzi
  strony.
- Obraz collectora w manifeście jest digestem dystrybucji, która zawiera eksporter
  Prometheus.
- Collector ma jedną replikę i nie wchodzi do HPA.
- Probe gotowości nie zależy od Jaegera. Błąd eksportu śladów nie ściąga poda z Ready.
- Nazwy metryk po eksporcie zapisuje się w komentarzu ConfigMap ze żywego `:8889/metrics`.
- `metricstransform` nie przemianowuje metryki, dopóki nazwa z SDK jest stabilna.
- Eksporter Prometheus nie dostaje `namespace`, które prefixuje
  `http_server_active_requests`.
- AppHost nie jest miejscem, w którym dopisuje się adres collectora z VM.
- Przy `replicas: 0` zmienne `OTEL_*` wolno zostawić jako wzór. Przy replice większej niż
  zero wzór `news-v0.0.0` nie zostaje w miejscu prawdziwego tagu.

## Poza zakresem

- Maszyna, namespace i wyłączenie Traefika są w [08-proxmox.md](08-proxmox.md). Ten numer
  nie zmienia węzła.
- Tunel i brak publicznego portu są w [09-cloudflare.md](09-cloudflare.md). Port 4317 nie
  dochodzi do tego tunelu. Panele 8889 też nie.
- Serwer Prometheus, retencja i scrape `:8889` są w [11-prometheus.md](11-prometheus.md).
  Ten numer wystawia tekst. Nie ustawia 15 dni.
- Jaeger, sampling `parentbased_always_on` i oglądanie śladu są w
  [12-jaeger.md](12-jaeger.md). Collector nie dokłada drugiego samplera.
- Dashboardy są w [13-grafana.md](13-grafana.md). Ten numer nie rysuje wykresu.
- HPA od CPU i od `http_server_active_requests` jest w [15-skalowanie.md](15-skalowanie.md).
  Ten numer pilnuje, żeby metryka wypłynęła. Nie tworzy obiektu HPA i nie obejmuje nim
  collectora.
- Podstawienie prawdziwego tagu w `service.version` jest w [16-deploy.md](16-deploy.md).
  Wzór `news-v0.0.0` nie jest wydaniem.
- Skład deweloperski i sam fakt, że ServiceDefaults eksportuje OTLP, są w numerze Aspire w
  `docs/api`. Ten plik nie przepisuje rejestracji ani filtra ścieżek `/health` i `/alive`.
- Logowanie produktu, kody `Result` i `ProblemDetails` są w numerach API. `trace_id` może
  iść w logu obok kodu błędu. Nie zastępuje pola `type`.
- Hasło UI Prometheusa i Jaegera nie powstaje tutaj. Porty tych UI opisują numery 11 i 12.

## Źródła

- [OpenTelemetry — koncepcje](https://opentelemetry.io/docs/concepts/). Wiążące są trzy
  sygnały: ślad, metryka i log, oraz zasób, który je opisuje. Dotyczy jednego SDK w
  ServiceDefaults i osobnych potoków collectora, zamiast jednego adresu na wszystko. Ze
  źródła nie bierzemy wysyłania metryk do Jaegera ani traktowania logu collectora jako
  magazynu stdout.
- [Collector — konfiguracja](https://opentelemetry.io/docs/collector/configuration/).
  Wiążący jest podział na receiver, processor, exporter i pipeline. Dotyczy OTLP gRPC na
  4317, procesora `batch` i trzech potoków w ConfigMap. Ze źródła nie bierzemy procesora
  samplera ani `metricstransform`, dopóki nazwa SDK jest stabilna.
- [Instalacja collectora](https://opentelemetry.io/docs/collector/install/). Wiążące jest
  wybranie dystrybucji, która zawiera komponenty wpisane w ConfigMap. Dotyczy digestu obrazu
  z eksporterem Prometheus, nie tagu pływającego. Ze źródła nie bierzemy dystrybucji, która
  tego eksportera nie wczyta, jako manifestu tego numeru.
- [Eksporter Prometheus collectora](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/exporter/prometheusexporter).
  Wiążące jest wystawienie tekstu Prometheusa na adresie, tu `0.0.0.0:8889`, ścieżka
  `/metrics`, oraz zamiana kropek na podkreślenia. Dotyczy nazwy
  `http_server_active_requests` i zakazu prefiksu `namespace`. Ze źródła nie bierzemy
  scrape’u `/metrics` na każdej usłudze.
- [Zgodność z Prometheusem](https://opentelemetry.io/docs/specs/otel/compatibility/prometheus_and_openmetrics/).
  Wiążące są zasady tłumaczenia nazwy i atrybutu zasobu na serię Prometheusa. Dotyczy
  etykiety `service_name` z `service.name` oraz tego, że komentarz ConfigMap spisuje nazwę z
  żywego tekstu. Ze źródła nie bierzemy ręcznej przemianowy, która ukrywa różnicę między
  laptopem i VM.
- [Specyfikacja metryk HTTP](https://opentelemetry.io/docs/specs/semconv/http/http-metrics/).
  Wiążąca jest metryka żądań w toku po stronie serwera. Dotyczy
  `http.server.active_requests` przed eksportem i `http_server_active_requests` po nim. Ze
  źródła nie bierzemy własnego licznika o innej nazwie w `Program.cs`. Histogram czasu
  zostaje przy nazwie, którą emituje przypięta instrumentacja.
- [Zasób service](https://opentelemetry.io/docs/specs/semconv/resource/service/). Wiążące są
  `service.name` i `service.version` jako atrybuty zasobu, nie jako nazwa Deploymentu z
  sufiksem ReplicaSet. Dotyczy listy komponentów i pełnego tagu, na przykład `news-v1.4.0`.
  Ze źródła nie bierzemy wspólnej nazwy `jjdevhub` dla wszystkich podów.
- [deployment.environment](https://opentelemetry.io/docs/specs/semconv/resource/deployment-environment/).
  Wiążące jest oznaczenie środowiska, w którym proces działa. Dotyczy
  `deployment.environment=production` na maszynie. Ze źródła nie bierzemy ustawiania tej
  wartości na laptopie przy `aspire run` ani przemianowania klucza w tym numerze na inny
  identyfikator.
- [.NET Aspire Service Defaults](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/service-defaults).
  Wiążące jest jedno miejsce wspólnej telemetrii hosta HTTP. Dotyczy zakazu kopiowania
  `AddOpenTelemetry` do każdej usługi i tego, że brak odwołania jest luką numeru Aspire, nie
  zaproszeniem do lokalnego SDK. Ze źródła nie bierzemy domeny usługi ani roli.
- [Telemetria Aspire](https://learn.microsoft.com/dotnet/aspire/fundamentals/telemetry).
  Wiążące jest włączanie eksportera OTLP przy niepustym `OTEL_EXPORTER_OTLP_ENDPOINT` oraz
  to, że dashboard sam tę zmienną ustawia lokalnie. Dotyczy rozdziału odbiornika: laptop ma
  dashboard, maszyna ma collector, adres nie leży w appsettings. Ze źródła nie bierzemy
  wyjątku przy starcie, gdy zmiennej nie ma, i nie bierzemy kierowania laptopa na Service z
  VM.
- [OTLP](https://opentelemetry.io/docs/specs/otlp/). Wiążący jest protokół, którego receiver
  collectora słucha jako gRPC. Dotyczy portu 4317 i `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`. Ze
  źródła nie bierzemy wystawienia tego portu jako NodePort albo public hostname.
- [Eksporter OTLP w SDK](https://opentelemetry.io/docs/languages/sdk-configuration/otlp-exporter/).
  Wiążące są zmienne `OTEL_EXPORTER_OTLP_ENDPOINT` i protokół. Dotyczy adresu
  `http://otel-collector.jjdevhub.svc.cluster.local:4317`, gdzie schemat `http` przy gRPC
  oznacza brak TLS na odcinku wewnątrz namespace. Ze źródła nie bierzemy wpisu tego adresu
  do pliku json w git.
- [Zmienne OTEL](https://opentelemetry.io/docs/languages/sdk-configuration/general/).
  Wiążące są `OTEL_SERVICE_NAME` i `OTEL_RESOURCE_ATTRIBUTES`. Dotyczy nazwy komponentu,
  `service.version` jako pełnego tagu i `deployment.environment=production`. Ze źródła nie
  bierzemy samplera ustawianego w collectorze. Sampler SDK opisuje numer 12.
- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/dotnet/). Wiążące jest jedno
  SDK dla logu, śladu i metryki w procesie .NET. Dotyczy ServiceDefaults, instrumentacji
  ASP.NET Core, HTTP i runtime. Ze źródła nie bierzemy pakietu eksportera Prometheus w
  procesie.
- [Eksporter Prometheus w procesie .NET](https://github.com/open-telemetry/opentelemetry-dotnet/tree/main/src/OpenTelemetry.Exporter.Prometheus.AspNetCore).
  Wiążące jest to, że taki pakiet wystawiłby `/metrics` na usłudze. Dotyczy zakazu: grep po
  `OpenTelemetry.Exporter.Prometheus` ma być pusty. Ze źródła nie bierzemy tego pakietu jako
  bocznej ścieżki scrape’u.
- [Logi .NET i ślad](https://opentelemetry.io/docs/languages/dotnet/logs/). Wiążące jest
  spinanie `ILogger` ze śladem, tak żeby linia niosła `trace_id`. Dotyczy stdout usługi, nie
  magazynu w collectorze. Ze źródła nie bierzemy filtra w Jaegerze jako naprawy braku
  `trace_id`. Naprawa jest w ServiceDefaults.
- [Extension health_check](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/healthcheckextension).
  Wiążący jest endpoint gotowości procesu collectora, tu port 13133. Dotyczy probe, które
  nie sprawdza Jaegera. Ze źródła nie bierzemy probe, które schodzi na czerwono przy błędzie
  eksportu śladów, gdy proces collectora żyje.
- [Procesor batch](https://github.com/open-telemetry/opentelemetry-collector/blob/main/processor/batchprocessor/README.md).
  Wiążące jest grupowanie eksportu, żeby nie wysyłać każdego sygnału osobno. Dotyczy
  jedynego procesora w potokach tego numeru. Ze źródła nie bierzemy dokładania drugiego
  procesora, który zmienia sampling albo nazwę metryki.
- [Eksporter OTLP collectora](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/otlpexporter/README.md).
  Wiążące jest wyjście OTLP do następnego odbiornika, z `tls.insecure` tylko tam, gdzie
  odcinek jest wewnętrzny. Dotyczy `otlp/jaeger` na
  `jaeger.jjdevhub.svc.cluster.local:4317`. Ze źródła nie bierzemy TLS do publicznego
  hostname’u ani wysyłania metryk tym eksporterem do Jaegera.
- [metricstransform](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/metricstransformprocessor).
  Wiążące jest to, że procesor umie zmienić nazwę metryki. Dotyczy świadomego braku: przy
  stabilnej nazwie SDK go nie włączamy, bo laptop i VM przestałyby być porównywalne. Ze
  źródła nie bierzemy przemianowy „żeby wykres wyglądał jak w przykładzie z internetu”.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest ClusterIP jako jedyny typ Service collectora. Dotyczy portów 4317 i 8889
  wewnątrz `jjdevhub` oraz zakazu NodePort. Ze źródła nie bierzemy publikacji OTLP na
  adresie węzła.

## Gotowe gdy

- W git jest `deploy/k3s/observability/otel-collector.yaml` z potokami metryk, śladów i
  logów, obrazem po digescie i Service ClusterIP.
- Potok metryk kończy się na eksporterze Prometheus `0.0.0.0:8889`. Potok śladów kończy się
  na `jaeger.jjdevhub.svc.cluster.local:4317` z `tls.insecure: true`. Potok logów nie kończy
  się na Jaegerze.
- W potokach nie ma `metricstransform` ani drugiego samplera. Jest procesor `batch`.
- `kubectl -n jjdevhub get deploy otel-collector` pokazuje jedną gotową replikę, także gdy
  eksport śladów jeszcze nie łączy się z Jaegerem.
- `:8889/metrics` zwraca tekst z poda pomocniczego. Komentarz ConfigMap nazywa metrykę
  widoczną w tym tekście. Oczekiwany człon to `http_server_active_requests`.
- Deploymenty aplikacji zawierają `OTEL_EXPORTER_OTLP_ENDPOINT` na ten Service, protokół
  `grpc`, `OTEL_SERVICE_NAME` z listy komponentów i `service.version` w kształcie pełnego
  tagu.
- Na maszynie jest `deployment.environment=production`. Laptop przy `aspire run` nie dostaje
  adresu collectora.
- `git grep OpenTelemetry.Exporter.Prometheus` po `csproj` i `Directory.Packages.props` nic
  nie zwraca.
- `AddOpenTelemetry` występuje tylko w `JJDevHub.ServiceDefaults`.
- Usługi nie mają `/metrics` i nie mają adnotacji scrape.
- Z zewnątrz maszyny porty 4317 i 8889 nie odpowiadają. `nc -vz <adres-gościa> 4317` nie
  łączy.
- Dashboard Aspire przy `aspire run` nadal pokazuje ślad. Collector na VM nie jest warunkiem
  pracy laptopa.
- Collector ma jedną replikę i nie ma HPA. Eksport nie jest na ścieżce odpowiedzi HTTP.
