# 11. Prometheus

[Spis CI/CD](README.md) · poprzedni: [10. OpenTelemetry](10-opentelemetry.md) · następny: [12. Jaeger](12-jaeger.md)

Ten numer stawia na maszynie magazyn metryk. Collector z
[10-opentelemetry.md](10-opentelemetry.md) już wystawia tekst na `:8889`. Tu dochodzi
proces, który ten tekst czyta, trzyma próbki i publikuje rekord pod HPA. Następny plik,
[12-jaeger.md](12-jaeger.md), magazynuje ślady. Prometheus ich nie magazynuje. W kolejności
pracy numer idzie po collectorze, przed Jaegerem i przed lokalnym Postgresem.
Instrumentacja zostaje w `JJDevHub.ServiceDefaults`. Dashboard
Aspire zostaje na laptopie i nie jest magazynem maszyny.

Scenariusz, który bez tego magazynu się rozpada, zaczyna się tydzień po wdrożeniu
`news-v1.4.0`. Operator chce zestawić liczbę żądań w toku z tagiem `news-v1.3.0` z tego
samego tygodnia. Pamięć collectora tego nie trzyma: restart poda collectora kasuje okno,
którego nie zdążył zabrać nikt z zewnątrz. HPA z numeru 15 potrzebuje szeregu dłuższego niż
życie jednego procesu. Grafana z numeru 13 potrzebuje datasource. Oba czytają ten sam
serwer, nie dashboard laptopa.

## Po co

Collector ma port `8889` i, zanim powstanie ten numer, nikogo, kto by go czytał. Prometheus
w namespace `jjdevhub` scrapuje ten jeden target co 15 sekund, trzyma próbki 15 dni na PVC
20 GiB i słucha na ClusterIP 9090. Nie wychodzi na NodePort. UI, jeśli jest publikowane,
idzie hostname’em z numeru 09 za Cloudflare Access. Sam `kubectl port-forward` z LAN
wystarcza, żeby numer zamknąć. Hostname nie jest warunkiem scrape’u.

Rekord `jjdevhub:http_server_active_requests:sum` jest stabilną nazwą dla numeru 15.
Wyrażenie startowe to `sum by (service_name) (http_server_active_requests)`. Gdy surowa
nazwa na `:8889/metrics` jest inna, zmienia się `expr`. Nazwa rekordu zostaje. Adapter czyta
rekord, nie surową nazwę SDK. CPU dla autoskalowania zostaje przy metrics-server. Prometheus
nie jest źródłem `metrics.k8s.io`.

Restart Prometheusa nie restartuje usług i nie zrywa żądań czytelnika. Aplikacja Prometheusa
nie woła. Woła go collector, pośrednio, przez to, że wystawia tekst. Padnięcie tego poda
jest dziurą w wykresie i, gdy adapter nie ma serii, brakiem metryki HTTP w HPA. CPU z
metrics-server przy tym nadal działa. To są dwa źródła dwóch różnych rzeczy, nie dwa źródła
tej samej liczby.

## Dlaczego ta technologia

### Prometheus na tej samej VM

Prometheus jest pojedynczym serwerem szeregów czasowych. Na jednym węźle wystarcza jedna
replika StatefulSet, lokalny dysk i PromQL, którego Grafana i prometheus-adapter już
rozumieją. Druga replika Prometheusa nie wchodzi. HPA jej nie dodaje. Odtworzenie po utracie
maszyny jest z `vzdump` numeru 08, nie z repliki tego procesu.

Grafana Cloud i każdy zdalny zapis do chmury odpadają razem z decyzją o jednej maszynie.
VictoriaMetrics albo Thanos odpadają: dokładają drugi silnik przy ruchu kilku usług i
jednego operatora. Zostawienie metryk tylko w pamięci collectora odpada, bo restart poda
collectora kasuje okno, a HPA potrzebuje historii dłuższej niż życie procesu. Federacja z
innego Prometheusa odpada, bo drugiego serwera nie ma.

Koszt: PVC, retencja do pilnowania i jedna baza, która pada razem z maszyną. Dysk VM ma 120
GiB i dzieli go z Postgresem, Kafką i Jaegerem. 20 GiB na ten szereg jest wycinkiem, nie
całym dyskiem. Operator, który wydłuży retencję bez przeliczenia PVC, zderzy się z tym
limitem. Wydłużenie jest osobną zmianą manifestu, nie cichą flagą.

Scenariusz utraty: węzeł nie wstaje, kopia Proxmoxa wraca, PVC jest z powrotem Bound albo
jest puste, jeśli kopia go nie objęła. Ten numer nie obiecuje drugiej kopii szeregu poza
kopią maszyny. Obiecuje, że restart samego poda Prometheusa, przy podpiętym PVC, nie kasuje
próbek z retencji.

### Scrape collectora, nie scrape usług

Jedyny job scrape aplikacji to `otel-collector`, target
`otel-collector.jjdevhub.svc.cluster.local:8889`, ścieżka `/metrics`, co 15 sekund. Usługi
nie dostają adnotacji `prometheus.io/scrape`, nie dostają portu o nazwie `metrics` i nie
wystawiają `/metrics`. Probe zostaje na `/health`. Ścieżka instrumentacji jest jedna i jest
opisana w numerze 10.

Job `kubernetes-pods`, który szuka adnotacji na podach, nie wchodzi do pliku konfiguracji.
Scrape każdego poda na `/metrics` odpada, bo wymagałby eksportera Prometheus w procesie,
obok OTLP. Dwa formaty rozjeżdżają nazwę tej samej metryki. „Dorzucę endpoint na News, bo
kolektor nie zdążył” odpada tak samo. Metryka, której SDK nie wyeksportuje przez OTLP, nie
pojawi się w ogóle. To jest koszt jednego SDK, przyjęty w numerze 10 i egzekwowany tutaj
brakiem drugiego joba.

Job węzła wolno dodać jako drugi target, oznaczony `job=node`. Źródłem może być kubelet albo
cAdvisor przez endpoint, który k3s już ma. Służy wykresowi maszyny w Grafanie. Nie jest
źródłem HPA. Próg CPU autoskalowania zostaje przy `kubectl top` i metrics-server. Liczba z
wykresu węzła i liczba z `kubectl top` mogą różnić się o okno scrape. Decyzja HPA bierze tę
drugą.

Scenariusz pomyłki: ktoś ustawia HPA na metrykę z `job=node`, bo wykres CPU „już jest w
Prometheusie”. Dwa progi tej samej maszyny mijają się o interwał. Pod wstaje albo nie wstaje
w innym momencie niż `kubectl top` pokazuje. Ten numer nie podpina joba węzła pod adapter.
Adapter, gdy dojdzie w numerze 15, czyta rekord HTTP.

### CPU węzła zostaje przy metrics-server

HPA od CPU czyta `metrics.k8s.io`, które w k3s wystawia metrics-server. Prometheus nie jest
źródłem tej metryki. Jest źródłem metryki HTTP, której metrics-server nie zna. `kubectl top`
i próg 70 procent z numeru 15 patrzą w to samo API. Wykres w Grafanie, jeśli jest, patrzy w
Prometheus i może pokazać CPU węzła z joba `node`. To podgląd, nie próg.

Pakowanie CPU do Prometheusa i czytanie go stamtąd przez adapter, przy działającym
metrics-server, odpada. Dwa źródła tego samego zasobu i dwa progi, które się mijają, psują
odpowiedź na pytanie „dlaczego wstał drugi pod”. Koszt rozdziału: operator patrzy na CPU w
Grafanie i na CPU w `kubectl top`. Różnica o okno scrape nie jest awarią Prometheusa. Jest
powodem, żeby progu nie przenosić.

Gdy Prometheus leży, `kubectl top` nadal działa, o ile metrics-server działa. HPA od CPU
nadal ma sygnał. HPA od żądań w toku oznacza metrykę jako brakującą, co numer 15 każe
widzieć w `kubectl describe hpa`, a nie jako ciche zero. Ten numer nie maskuje braku rekordu
przez podstawienie CPU.

### Retencja 15 dni

Argument procesu to `--storage.tsdb.retention.time=15d`. Dane leżą w
`--storage.tsdb.path=/prometheus` na PVC 20 GiB, StorageClass `local-path` z numeru 08.
`evaluation_interval` reguł to też 15 sekund, tak jak scrape. Jeden operator i kilka usług
nie potrzebują roku historii na tym dysku. Decyzja o drugim podzie i tak jest o oknie minut,
nie o oknie roku.

Retencja roczna odpada: zjada dysk dzielony z Postgresem, Kafką i Jaegerem i nie zmienia
progu HPA. Brak retencji, same dane w pamięci, odpada, bo restart kasuje podstawę do
porównania `news-v1.3.0` z `news-v1.4.0` w tym samym tygodniu. Domyślne 15 dni w
dokumentacji Prometheusa jest tu świadomie wpisane w argument, żeby manifest mówił liczbę, a
nie polegał na milczeniu flagi.

Koszt: incydent starszy niż 15 dni nie ma wykresu. Zostaje log na stdout, jeśli kubelet go
jeszcze trzyma, i kopia maszyny, jeśli ktoś jej nie nadpisał. Wydłużenie retencji bez
powiększenia PVC albo bez spojrzenia na 120 GiB dysku jest błędem zmiany, nie „drobną
flagą”. Rozmiar retencji w bajtach tego numeru nie włącza. Włącza czas.

### UI za Access albo wcale

Prometheus nie ma konta aplikacji. Publiczny hostname bez Access z numeru 09 odpada.
Włączenie podstawowego hasła w argumencie procesu i trzymanie go w git odpada. Hasło w
argumencie w ogóle jest słabe, więc ten numer nie opiera na nim bezpieczeństwa.
Bezpieczeństwem UI jest brak portu na gościu oraz, gdy hostname istnieje, Cloudflare Access.

Sam `kubectl port-forward` z LAN jako jedyna droga do UI jest dopuszczalny i wystarcza do
zamknięcia numeru. Hostname jest dodatkiem z numeru 09, nie warunkiem scrape’u.
`--web.external-url` ustawia się dopiero wtedy, gdy ten hostname istnieje, i jest równy temu
`https://`. Bez niego panel za tunelem ładuje HTML i gubi zasoby. Bez Accessu hostname nie
powstaje.

Koszt: z telefonu spoza Access nie da się otworzyć Prometheusa. To jest zgodne z celem. Z
LAN operator robi:

```bash
kubectl -n jjdevhub port-forward svc/prometheus 9090:9090
```

UI jest na `127.0.0.1:9090` laptopa na czas forwardu. Forward nie zostaje jako Service
NodePort. Po zamknięciu polecenia port na laptopie znika. Na gościu 9090 nadal nie słucha na
adresie publicznym.

### Rekord, którego nie wolno przemianować

Grupa reguł nazywa się `jjdevhub-http`. Rekord nazywa się
`jjdevhub:http_server_active_requests:sum`. Wyrażenie:

```text
sum by (service_name) (http_server_active_requests)
```

Nazwa rekordu jest kontraktem z numerem 15 i z Grafaną. Surowa nazwa SDK może się zmienić
razem z instrumentacją. Wtedy `expr` używa nazwy z `:8889/metrics`, a rekord zostaje.
Etykieta `service_name` rozdziela komponenty. Bez niej suma zlałaby News z bramą i HPA News
widziałoby ruch wszystkich usług. Gdy żywy tekst niesie komponent pod tą etykietą, `expr`
jej nie rusza.

Pusty wektor nie jest błędem reguły. Przy zerowych replikach aplikacji zapytanie o rekord
zwraca `status=success` i pusty wynik. Błędem jest brak grupy `jjdevhub-http`, błąd
parsowania albo zmiana nazwy rekordu między tym numerem a numerem 15. Adapter nie dostaje
wtedy „prawie tej samej” nazwy. Dostaje brak.

Scenariusz zmiany instrumentacji: po podbiciu pakietu tekst na 8889 pokazuje inną nazwę
surową. Operator zmienia jedną linię `expr`, zostawia `record`, przeładowuje konfigurację z
wnętrza klastra i sprawdza `/api/v1/rules`. Nie przebudowuje obrazu News. Nie dopisuje
scrape’u poda. Komentarz w ConfigMap collectora z numeru 10 jest miejscem, z którego bierze
surową nazwę, żeby jej nie zgadywać.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/observability/prometheus.yaml` | StatefulSet jednej repliki, PVC 20 GiB, Service ClusterIP, ConfigMap scrape |
| `deploy/k3s/observability/prometheus/rules.yaml` | Reguła rejestrująca `jjdevhub:http_server_active_requests:sum` |

Service `prometheus` jest ClusterIP na porcie 9090. Nie ma NodePort. Nie ma LoadBalancer.
Konto usługi zostaje w namespace `jjdevhub`. Obraz jest digestem. Żądania: 200m CPU, 512 MiB
pamięci. Limit pamięci zostawia zapas na kompaktowanie WAL. Bez zapasu proces ginie w pętli
OOM i HPA ślepnie na metrykę HTTP, choć metrics-server nadal podaje CPU.

ConfigMap scrape:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: otel-collector
    metrics_path: /metrics
    static_configs:
      - targets:
          - otel-collector.jjdevhub.svc.cluster.local:8889
```

Job `kubernetes-pods` z adnotacjami nie wchodzi do tego pliku. Job węzła, jeśli jest, ma
`job_name: node` i nie jest wpisany jako źródło HPA. Nie scrapuje Service’ów `identity`,
`news`, `learning`, `cv`, `contact`, `gateway` ani `web`.

Reguła rejestrująca:

```yaml
groups:
  - name: jjdevhub-http
    rules:
      - record: jjdevhub:http_server_active_requests:sum
        expr: sum by (service_name) (http_server_active_requests)
```

`rules.yaml` wchodzi do tego samego ConfigMap albo do katalogu reguł zamontowanego obok. Po
zmianie reguły pod jest restartowany albo dostaje `POST /-/reload` z innego poda w
namespace, i tylko wtedy, gdy proces ma `--web.enable-lifecycle`. Zmiana nie wymaga
przebudowy obrazu aplikacji.

## Plan

### 1. Manifest

StatefulSet `prometheus`, jedna replika, konto usługi w namespace `jjdevhub`, PVC 20 GiB na
`local-path`, montowane w `/prometheus`. Argumenty procesu:

- `--config.file=/etc/prometheus/prometheus.yml`
- `--storage.tsdb.retention.time=15d`
- `--storage.tsdb.path=/prometheus`
- `--web.enable-lifecycle` tylko jeśli reload konfiguracji ma iść przez `POST /-/reload` z
  wewnątrz klastra
- `--web.external-url` ustawione dopiero wtedy, gdy numer 09 ma hostname Prometheusa, i
  równe temu `https://`

Obraz przypnij do digestu. Nie zostawiaj tagu jako jedynej referencji. Nie ustawiaj hasła w
argumencie i nie commituj hasła. Nie twórz HorizontalPodAutoscaler dla tego StatefulSet.
`replicas` zostaje 1.

Zastosuj manifest i poczekaj na Ready:

```bash
kubectl -n jjdevhub apply -f deploy/k3s/observability/prometheus.yaml
kubectl -n jjdevhub rollout status statefulset/prometheus
```

Gdy PVC nie wiąże się, pod nie będzie Ready. Nie obchodź tego przez `emptyDir`. Retencja 15
dni na dysku efemerycznym znika z podem i ten numer nie jest zrobiony.

### 2. Konfiguracja

ConfigMap z jobem `otel-collector` zamontuj jako plik konfiguracyjny. Interwał scrape i
ewaluacji to 15 sekund. Jedyny target aplikacji to
`otel-collector.jjdevhub.svc.cluster.local:8889`. Po zmianie ConfigMap zrestartuj pod albo
wyślij `POST /-/reload` z poda w tym samym namespace, jeśli flaga lifecycle jest włączona.

Nie dopisuj joba, którego `scrapeUrl` wskazuje `news:8080` albo ścieżkę `/metrics` na
Service aplikacji. Nie dopisuj adnotacji `prometheus.io/scrape` do manifestów w
`deploy/k3s/apps/`.

### 3. Reguła HTTP

Wgraj grupę `jjdevhub-http` z rekordem `jjdevhub:http_server_active_requests:sum`. Gdy
komentarz collectora mówi, że surowa nazwa nie jest `http_server_active_requests`, podstaw
tę nazwę w `expr`. Nazwy rekordu nie zmieniaj. Etykiety `service_name` nie usuwaj, jeśli
seria ją ma.

```bash
kubectl -n jjdevhub exec statefulset/prometheus -- \
  wget -qO- http://127.0.0.1:9090/api/v1/rules
```

Grupa `jjdevhub-http` jest obecna. Pusty wektor przy zerowych replikach aplikacji nie jest
błędem parsowania. Błędem jest brak grupy.

### 4. Brak scrape’u usług

Przejrzyj manifesty `deploy/k3s/apps/`. Nie ma portu o nazwie `metrics`, nie ma adnotacji
scrape, nie ma ścieżki `/metrics` w probe. Probe zostaje na `/health`. To samo dotyczy
bramy. Collector zostaje jedynym targetem aplikacji w `scrape_configs`.

### 5. Dostęp operatora

Z LAN:

```bash
kubectl -n jjdevhub port-forward svc/prometheus 9090:9090
```

UI otwiera się na `127.0.0.1:9090` laptopa. Jeśli powstaje hostname publiczny, jest to
hostname z numeru 09, z Access, a `--web.external-url` jest równy temu `https://`. Bez
Access hostname nie powstaje. Z sieci spoza LAN `nc` na port 9090 adresu gościa nie łączy.

### Co jest do czego

StatefulSet `prometheus` jest wołany przez kubelet jako jedyna replika magazynu. Grafana i
prometheus-adapter czytają jego API na ClusterIP 9090. Gdy replik jest więcej niż jedna,
dwie bazy na jednym węźle rozjeżdżają się i adapter nie wie, którą czyta. HPA tego obiektu
nie podnosi.

Job `otel-collector` jest wołany przez Prometheus co 15 sekund. Czyta `:8889`. Gdy target
jest `down` przy działającym collectorze, zła jest nazwa DNS albo port, nie „chwilowy brak
ruchu”. Ruch zerowy nadal daje target `up`, jeśli proces odpowiada.

Rekord `jjdevhub:http_server_active_requests:sum` jest wołany przez numer 15 i przez panel w
numerze 13. Gdy nazwa rekordu się zmieni, oba numery szukają serii, której nie ma, choć
surowa metryka żyje. Zmiana `expr` przy innej nazwie surowej jest dozwolona. Zmiana `record`
nie jest.

metrics-server jest wołany przez `kubectl top` i przez HPA od CPU. Prometheus go nie
zastępuje. Gdy ktoś wyłączy metrics-server, bo „Prometheus już ma CPU”, próg z numeru 15
traci źródło, nawet jeśli wykres węzła nadal się rysuje.

PVC 20 GiB jest wołane przez proces jako ścieżka `/prometheus`. Trzyma WAL i bloki przez 15
dni. Gdy wolumen jest `emptyDir`, restart poda kasuje porównanie tagów z tego tygodnia. Test
zakresowy po skasowaniu poda to wykrywa.

`port-forward` jest wołany przez operatora z LAN. Otwiera UI na czas polecenia. Nie jest
Service’em na gościu. Access i hostname są wołane przez przeglądarkę operatora spoza LAN, i
tylko gdy numer 09 je utworzył. Bez Accessu wołanie publiczne nie powstaje.

Aplikacja tego Prometheusa nie woła. Nie ma w jej środowisku adresu 9090. Adres collectora w
zmiennej OTEL nie zmienia się na adres Prometheusa. To byłyby dwa różne protokoły w jednej
zmiennej.

## Testy

Testy są operacyjne. Nie ma tu faktu xUnit. Padnięcie ma jeden objaw: target `down`, reguła
nie parsuje, Service nie jest ClusterIP, scrape sięga usługi, `nc` łączy na 9090, albo
próbka sprzed restartu znika przy podpiętym PVC.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | StatefulSet jednej repliki, PVC 20 GiB, retencja 15d, job wyłącznie na collector `:8889`, grupa `jjdevhub-http` |
| Działanie (act) | `rollout status`, `/api/v1/targets`, `/api/v1/rules`, `/api/v1/query`, przegląd `deploy/k3s/apps/`, `nc` na 9090, restart poda i `query_range` |
| Sprawdzenie (assert) | target `up`, reguła obecna, query `success`, brak scrape’u usług, ClusterIP, próbki przeżywają restart poda |

1. Pod jest Ready, a target jest zielony.

```bash
kubectl -n jjdevhub rollout status statefulset/prometheus
kubectl -n jjdevhub exec statefulset/prometheus -- \
  wget -qO- http://127.0.0.1:9090/api/v1/targets
```

W JSON jest target `otel-collector` ze stanem `up`. Stan `down` przy działającym collectorze
z numeru 10 jest błędem tego numeru: zła nazwa DNS albo zły port. Interwał w konfiguracji to
15 sekund. Druga replika w StatefulSet jest błędem, tak samo jak obiekt HPA o tej nazwie.

2. Zapytanie o rekord nie kończy się błędem składni, nawet przy pustym wektorze.

```bash
kubectl -n jjdevhub exec statefulset/prometheus -- \
  wget -qO- 'http://127.0.0.1:9090/api/v1/query?query=jjdevhub:http_server_active_requests:sum'
```

Pole `status` ma wartość `success`. Pusty wynik przy zerowych replikach aplikacji jest
poprawny. Błąd składni oznacza złą nazwę w `expr` albo brak grupy. Popraw `expr` do nazwy z
`:8889/metrics`, jeśli surowa nazwa jest inna. Nazwy rekordu nie zmieniaj i zapytania nie
przestawiaj na inną nazwę.

3. Grupa reguł jest załadowana.

```bash
kubectl -n jjdevhub exec statefulset/prometheus -- \
  wget -qO- http://127.0.0.1:9090/api/v1/rules
```

Odpowiedź zawiera grupę `jjdevhub-http` i rekord `jjdevhub:http_server_active_requests:sum`.
Brak grupy przy zielonym procesie oznacza, że plik reguł nie jest zamontowany albo reload
nie doszedł. Restart poda albo `POST /-/reload` z wnętrza namespace, nie przebudowa News.

4. Usługi nie są targetami. W JSON z `/api/v1/targets` nie ma joba, którego `scrapeUrl`
wskazuje `news:8080` albo ścieżkę `/metrics` na Service aplikacji. W `deploy/k3s/apps/` nie
ma adnotacji `prometheus.io/scrape` i nie ma portu `metrics`. Probe wskazuje `/health`. Job
`node`, jeśli istnieje, ma nazwę `node` i nie jest wpisany w manifest HPA. Tego manifestu
jeszcze może nie być. Ten numer i tak nie czyni joba węzła źródłem progu.

5. Service nie jest wystawiony na hoście.

```bash
kubectl -n jjdevhub get svc prometheus -o jsonpath='{.spec.type}{"\n"}'
nc -vz <adres-gościa> 9090
```

Typ to `ClusterIP`. `nc` z sieci spoza LAN nie łączy. W manifeście nie ma hasła w
argumencie. `git grep` po katalogu Prometheusa nie znajduje wartości hasła. Jeśli hostname
istnieje, żądanie bez Accessu nie dostaje UI. To sprawdzenie jest w numerze 09. Tu
wystarczy, że `--web.external-url` jest zgodny z tym `https://`, gdy hostname jest, i że bez
hostname flaga nie wskazuje w próżnię publiczną.

6. Po restarcie poda próbka sprzed restartu nadal jest w zapytaniu z zakresu, o ile restart
był w obrębie retencji i PVC zostało podpięte.

```bash
kubectl -n jjdevhub delete pod -l app=prometheus
```

Po powrocie poda na to samo PVC `query_range` o starcie sprzed usunięcia ma zwrócić punkty.
To sprawdza PVC i 15 dni, nie HPA. Pusty zakres przy świeżo założonym wolumenie, zanim
pierwszy scrape w ogóle zapisał punkt, nie jest tym testem. Test ma sens, gdy przed
skasowaniem `/api/v1/query` już widziało serię. Jeśli po powrocie seria sprzed skasowania
zniknęła, wolumen był efemeryczny albo path procesu nie jest `/prometheus` na PVC.

7. Restart tego poda nie restartuje Deploymentów aplikacji. `kubectl get pods` po skasowaniu
Prometheusa pokazuje nowe podbicie tylko przy etykiecie Prometheusa. News, brama i Postgres
zostają na swoich czasach startu. Żądanie czytelnika nie zależy od 9090.

## Zasady

- Jedna replika Prometheusa, StatefulSet. Drugiej nie dodaje HPA. `replicas` zostaje 1.
- Jedyny scrape aplikacji to collector `:8889`, co 15 sekund, ścieżka `/metrics`.
- Usługa nie dostaje `/metrics`, nie dostaje portu `metrics` i nie dostaje adnotacji
  `prometheus.io/scrape`.
- Job `kubernetes-pods` nie wchodzi do konfiguracji. Job `node` jest opcjonalny i nie jest
  źródłem HPA.
- CPU dla autoskalowania bierze metrics-server. Prometheus trzyma metrykę HTTP i,
  opcjonalnie, metrykę węzła do wykresu.
- Retencja to 15 dni, argument `--storage.tsdb.retention.time=15d`. Wydłużenie jest osobną
  zmianą manifestu, z przeliczeniem PVC wobec dysku 120 GiB.
- PVC ma 20 GiB, path `/prometheus`, StorageClass `local-path`. `emptyDir` nie spełnia
  retencji.
- Hasło UI nie leży w git i nie leży w argumencie procesu. Port 9090 na gościu nie jest
  otwarty.
- Obraz jest digestem. Tag jako jedyna referencja da się przepiąć bez zmiany treści, którą
  recenzujesz.
- Rekord `jjdevhub:http_server_active_requests:sum` nie zmienia nazwy między numerem 11 a
  15.
- Surowe nazwy SDK wolno przepisać tylko wewnątrz `expr`, gdy instrumentacja zmieni nazwę.
  Nazwa rekordu zostaje. Wyrażenie startowe sumuje `http_server_active_requests` po
  `service_name`.
- Pusty wektor przy zerowych replikach aplikacji nie jest błędem reguły. Brak grupy
  `jjdevhub-http` jest błędem.
- Restart Prometheusa nie restartuje usług i nie zrywa żądań czytelnika.
- AppHost i dashboard Aspire nie wskazują na ten Prometheus.
- `--web.enable-lifecycle` jest włączone tylko razem z reloadem z wnętrza klastra.
  `--web.external-url` jest ustawione tylko razem z hostname’em za Access.
- Grafana Cloud, VictoriaMetrics, Thanos i federacja nie są magazynem tego numeru.

## Poza zakresem

- Rejestracja SDK i potok collectora są w [10-opentelemetry.md](10-opentelemetry.md). Ten
  numer nie dopisuje `AddOpenTelemetry` i nie zmienia portu 8889.
- Ślady są w [12-jaeger.md](12-jaeger.md). Prometheus ich nie magazynuje i nie scrapuje
  portu 16686.
- Panele i datasource są w [13-grafana.md](13-grafana.md). Ten numer nie rysuje JSON
  dashboardu.
- Manifest HPA i adapter, który czyta rekord, są w [15-skalowanie.md](15-skalowanie.md). Tu
  powstaje nazwa rekordu. Nie powstaje próg 70 procent ani maksimum dwóch replik.
- Hostname i Access są w [09-cloudflare.md](09-cloudflare.md). Ten numer nie tworzy rekordu
  DNS. Ustawia `--web.external-url` dopiero, gdy rekord jest.
- Maszyna i PVC `local-path` są w [08-proxmox.md](08-proxmox.md). Dysk 120 GiB jest stamtąd.
  Ten numer bierze z niego 20 GiB na szereg.
- Tag w `service.version` jest w [16-deploy.md](16-deploy.md). Metryka ma ten atrybut, bo
  collector go dostał. Deploy pilnuje, żeby wartość była tagiem właśnie wdrażanym.
- Alerty na telefon operatora i jakikolwiek kanał poza UI. Na tym etapie operator patrzy w
  UI albo w `kubectl top`. Osobny most alertów nie wchodzi do tego numeru.
- Hasło Grafany i jej Secret są w numerze 13. Ten plik nie tworzy konta `admin`.

## Źródła

- [Prometheus — przegląd](https://prometheus.io/docs/introduction/overview/). Wiążący jest
  model: serwer scrapuje targety i trzyma szeregi lokalnie. Dotyczy jednej repliki na tej VM
  i odrzucenia zdalnego zapisu do chmury. Ze źródła nie bierzemy federacji z drugim
  Prometheusem, którego w tym układzie nie ma.
- [Konfiguracja](https://prometheus.io/docs/prometheus/latest/configuration/configuration/).
  Wiążące są `scrape_interval`, `evaluation_interval` i `scrape_configs` ze statycznym
  targetem. Dotyczy 15 sekund i jedynego joba aplikacji `otel-collector` na `:8889`. Ze
  źródła nie bierzemy `kubernetes_sd` po podach ani adnotacji `prometheus.io/scrape`.
- [Reguły rejestrujące](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/).
  Wiążąca jest reguła, która zapisuje nową serię pod stabilną nazwą. Dotyczy
  `jjdevhub:http_server_active_requests:sum` w grupie `jjdevhub-http`. Ze źródła nie
  bierzemy zmiany nazwy rekordu, gdy zmieni się surowa nazwa SDK. Zmienia się `expr`.
- [Nazwy metryk](https://prometheus.io/docs/practices/naming/). Wiążący jest kształt nazwy
  rekordu: poziom, metryka, agregacja. Dotyczy dwukropków w
  `jjdevhub:http_server_active_requests:sum`. Ze źródła nie bierzemy skrócenia tej nazwy do
  surowej nazwy SDK, bo numer 15 i Grafana trzymają kontrakt rekordu.
- [Magazyn](https://prometheus.io/docs/prometheus/latest/storage/). Wiążące są
  `--storage.tsdb.path` i `--storage.tsdb.retention.time`. Dotyczy path `/prometheus`,
  retencji `15d` i PVC, które przeżywa restart poda. Ze źródła nie bierzemy retencji rocznej
  ani trzymania WAL tylko w pamięci. Domyślne 15 dni jest tu wpisane wprost, nie zostawione
  jako milczenie flagi.
- [Flagi procesu](https://prometheus.io/docs/prometheus/latest/command-line/prometheus/).
  Wiążące są argumenty ścieżki, retencji i zewnętrznego URL. Dotyczy `--web.external-url`
  tylko razem z hostname’em oraz zakazu hasła w argumencie. Ze źródła nie bierzemy flag,
  które publikują UI na adresie gościa.
- [API zarządzania](https://prometheus.io/docs/prometheus/latest/management_api/). Wiążące
  jest `POST /-/reload` po zmianie konfiguracji, gdy proces ma `--web.enable-lifecycle`.
  Dotyczy przeładowania joba i reguł bez przebudowy obrazu aplikacji. Ze źródła nie bierzemy
  wywołania reload z zewnątrz klastra. Wołanie idzie z poda w `jjdevhub`.
- [HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/). Wiążące są
  `/api/v1/targets`, `/api/v1/rules` i `/api/v1/query`. Dotyczy testu: target `up`, grupa
  obecna, `status=success` nawet przy pustym wektorze. Ze źródła nie bierzemy traktowania
  pustego wektora jako awarii reguły.
- [Zapytanie zakresowe](https://prometheus.io/docs/prometheus/latest/querying/api/#range-queries).
  Wiążące jest `query_range` jako odczyt punktów z okna czasu. Dotyczy sprawdzenia, że po
  skasowaniu poda próbki sprzed restartu nadal są, o ile PVC zostało podpięte i mieści się w
  15 dniach. Ze źródła nie bierzemy tego zapytania jako progu HPA. Próg jest w numerze 15.
- [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/). Wiążące jest
  czytanie szeregu po nazwie i po etykietach. Dotyczy rekordu, którego panel i adapter
  szukają po nazwie, nie po surowym liczniku z procesu. Ze źródła nie bierzemy ręcznego
  liczenia w aplikacji tego, co już jest w szeregu.
- [Operatory PromQL](https://prometheus.io/docs/prometheus/latest/querying/operators/).
  Wiążące jest `sum by (service_name)`. Dotyczy wyrażenia, które zostawia jedną serię na
  komponent. Ze źródła nie bierzemy sumy bez etykiety. Zlałaby News z bramą i HPA dostałoby
  ruch wszystkich usług.
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server). Wiążące jest API
  `metrics.k8s.io` z CPU i pamięcią poda. Dotyczy HPA od CPU i `kubectl top`, osobno od
  Prometheusa. Ze źródła nie bierzemy zastąpienia tego API scrape’em Prometheusa.
- [Potok metryk zasobów](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/).
  Wiążące jest to, że `kubectl top` czyta metrics-server, nie Prometheus. Dotyczy zakazu
  dwóch progów CPU. Ze źródła nie bierzemy wyłączenia metrics-server dlatego, że wykres
  węzła już jest w Grafanie.
- [Metryki systemu](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/).
  Wiążące jest rozróżnienie metryk komponentów węzła i metryk aplikacji. Dotyczy
  opcjonalnego `job=node` jako wykresu maszyny. Ze źródła nie bierzemy tego joba jako
  sygnału HPA.
- [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).
  Wiążące jest stabilne powiązanie poda z wolumenem. Dotyczy jednej repliki i PVC, które po
  `delete pod` wraca pod ten sam proces. Ze źródła nie bierzemy drugiej repliki jako pary
  baz na jednym węźle.
- [Trwałe wolumeny](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).
  Wiążące jest PVC, które przeżywa restart poda. Dotyczy 20 GiB na `local-path` i odrzucenia
  `emptyDir` dla 15 dni. Ze źródła nie bierzemy wolumenu trzymanego tylko w warstwie zapisu
  kontenera.
- [kubectl port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).
  Wiążące jest tymczasowe wejście z maszyny operatora na Service. Dotyczy UI na
  `127.0.0.1:9090` z LAN. Ze źródła nie bierzemy zostawienia forwardu jako stałego portu na
  gościu.

## Gotowe gdy

- `kubectl -n jjdevhub get statefulset prometheus` pokazuje jedną gotową replikę. HPA tego
  procesu nie ma.
- `svc/prometheus` ma typ ClusterIP i port 9090. `nc -vz <adres-gościa> 9090` z sieci spoza
  LAN nie łączy.
- PVC 20 GiB jest Bound, path procesu to `/prometheus`, retencja to `15d`.
- `/api/v1/targets` pokazuje `otel-collector` jako `up`. Interwał scrape to 15 sekund.
  Targetem nie jest żaden Service aplikacji.
- `/api/v1/rules` zawiera grupę `jjdevhub-http` i rekord
  `jjdevhub:http_server_active_requests:sum`.
- `/api/v1/query?query=jjdevhub:http_server_active_requests:sum` zwraca `status=success`.
  Pusty wektor przy zerowych replikach aplikacji jest poprawny.
- Jeśli surowa nazwa na `:8889/metrics` nie jest `http_server_active_requests`, `expr` używa
  nazwy z tego tekstu, a nazwa rekordu zostaje.
- W `deploy/k3s/apps/` nie ma scrape `/metrics`, nie ma portu `metrics` i nie ma adnotacji
  `prometheus.io/scrape`.
- Job `node`, jeśli jest, nie jest źródłem HPA. CPU autoskalowania zostaje przy
  metrics-server.
- W git i w argumentach procesu nie ma hasła UI.
- Obraz jest digestem.
- Po skasowaniu poda Prometheusa i jego powrocie na to samo PVC zapytanie zakresowe nadal
  widzi punkty sprzed skasowania, o ile punkt był już zapisany i mieści się w retencji.
- Restart Prometheusa nie restartuje usług.
- AppHost nie wskazuje na ten serwer. Hostname UI, jeśli jest, ma Access i
  `--web.external-url` równy temu `https://`.
