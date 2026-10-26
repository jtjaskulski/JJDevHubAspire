# 12. Jaeger

[Spis CI/CD](README.md) · poprzedni: [11. Prometheus](11-prometheus.md) · następny: [13. Grafana](13-grafana.md)

Ten numer stawia na maszynie magazyn śladów. Collector z
[10-opentelemetry.md](10-opentelemetry.md) wysyła potok `traces` na
`jaeger.jjdevhub.svc.cluster.local:4317`. Prometheus z [11-prometheus.md](11-prometheus.md)
pokazuje, ile żądań trwa. Nie pokazuje, który span w drzewie zjadł czas. Następny plik,
[13-grafana.md](13-grafana.md), podepnie UI obok wykresu. SDK zostaje w
`JJDevHub.ServiceDefaults`. Dashboard Aspire zostaje odbiornikiem laptopa. W
kolejności pracy numer idzie po Prometheusie i przed Grafaną, zanim powstaną
lokalne bazy zapisu.

Na VM błąd żądania ma dać się przejść od bramy YARP do usługi i do wywołania HTTP, które
usługa zrobiła dalej, z tym samym `trace_id` co w logu na stdout. Jaeger stoi w `jjdevhub`
jako jeden proces all-in-one, z dyskiem Badger na ślady, i przyjmuje OTLP tylko od
collectora. UI nie słucha na adresie gościa.

Scenariusz, który bez tego dysku się rozpada, zaczyna się w trakcie incydentu. Operator
kasuje pod, żeby „wstał czysto”, i razem z pamięcią procesu znika drzewo, które właśnie chce
otworzyć. Dlatego magazyn nie jest efemeryczny. PVC 10 GiB przeżywa restart poda. Retencja
śladu to 7 dni. Sampling zostaje `parentbased_always_on` po stronie SDK. Collector nie
dokłada drugiego samplera.

## Po co

Prometheus odpowiada na pytanie, ile żądań jest w toku i jak długo trwały w oknie 15 sekund.
Nie odpowiada, który span bramy, który span News i które wyjście HTTP złożyły się na ten
czas. Jaeger trzyma drzewo. Identyfikator, który łączy drzewo z linią `kubectl logs`, to
`trace_id` już wstawiany przez ServiceDefaults. Ten numer nie dokłada biblioteki logów.
Sprawdza, że identyfikator z stdout otwiera drzewo, gdy jest żywe żądanie.

Aplikacja nie dostaje adresu Jaegera w środowisku. Dla procesu odbiornikiem zostaje
collector. Port 4317 na Service `jaeger` jest wyłącznie dla eksportera `otlp/jaeger`. Port
16686 jest dla UI i dla zapytania, które później podepnie Grafana. Oba są ClusterIP. YARP
nie dostaje trasy `/jaeger`. Publiczny hostname, jeśli istnieje, jest tym z numeru 09 i ma
Cloudflare Access.

Gdy brama ma nadal zero replik, drzewo z żywego `/versions` nie jest warunkiem zamknięcia
tego numeru. Warunkiem jest zdrowy odbiornik: collector dostarcza, Jaeger przyjmuje, UI
odpowiada. Drzewo dopisuje się przy pierwszym deployu i jest sprawdzane ponownie w numerze
16 jako część zgodności `service.version` z tagiem. Przy zerowych replikach bramy punkt
drzewa przechodzi na numer 16. Reszta listy tego pliku i tak ma być spełniona.

## Dlaczego ta technologia

### Jaeger, bo ślad już jest OTLP

Jaeger przyjmuje OTLP. Collector ma eksporter `otlp/jaeger` na
`jaeger.jjdevhub.svc.cluster.local:4317` z `tls.insecure: true` tylko wewnątrz klastra.
Usługa nie dostaje tej nazwy w `OTEL_EXPORTER_OTLP_ENDPOINT`. Tam zostaje adres collectora z
numeru 10. Rozdzielenie jest po to, żeby podmiana magazynu śladów nie była podmianą SDK w
pięciu usługach i w bramie.

Tempo albo inny magazyn śladów odpada. To drugi produkt do tego samego OTLP, bez zysku na
jednym węźle, który już ma Postgresa, Kafkę i Prometheusa. Zipkin odpada, bo wymagałby
eksportera Zipkin w procesie albo tłumaczenia w collectorze, czyli drugiej ścieżki obok
OTLP. Zostawienie śladów tylko w dashboardzie Aspire odpada, bo AppHost na maszynę nie
jedzie. Produkcja nie otwiera dashboardu dewelopera, żeby zobaczyć tag, który już stoi.

Koszt: kolejny pod, PVC i UI, którego trzeba bronić tak samo jak Prometheusa. Jeden proces
all-in-one łączy odbiornik, magazyn i zapytanie. Na jednym węźle osobny collector Jaegera,
osobny query i osobna baza byłyby trzema miejscami awarii bez drugiej maszyny, która by je
uniosła. All-in-one jest tu układem produkcyjnym tej maszyny, nie „trybem na chwilę”, pod
warunkiem że magazyn jest Badger na PVC, a nie pamięć.

Obraz to `jaegertracing/all-in-one` przypięty do digestu. Tag pływający jako jedyna
referencja odpada. Dokumentacja obrazu pokazuje też porty Zipkina, gRPC Jaegera i OTLP HTTP.
Ten numer publikuje w Service tylko 4317 i 16686. Reszty nie wystawia nawet jako ClusterIP,
żeby nikt nie wziął 9411 za drugą drogę śladu.

### Jeden proces, magazyn Badger

Na jednym węźle Jaeger działa jako jeden pod: odbiornik OTLP, magazyn i UI zapytania na
porcie 16686. Magazyn to Badger. `SPAN_STORAGE_TYPE` to `badger`. `BADGER_EPHEMERAL` to
`false`. Katalog wartości to `/badger/data`. Katalog kluczy to `/badger/key`. Oba leżą na
PVC 10 GiB zamontowanym w `/badger`. Kolejka w pamięci z limitem „ostatnie N śladów” odpada.
Restart przy incydencie skasowałby właśnie to drzewo, które operator chce otworzyć. Flaga
pamięci, która trzyma ślad tylko do limitu liczby drzew, nie jest magazynem tego numeru.

Elasticsearch albo Cassandra jako backend Jaegera odpadają. To osobne klastry na maszynie,
która już trzyma Postgresa i Kafkę. Kafka jako bufor śladów odpada z tej samej przyczyny:
szyna produktu nie jest kolejką telemetrii. Ślad nie jest zdarzeniem domenowym i nie wchodzi
na temat, który czyta inbox. Koszt Badgera: jeden dysk nie przeżywa utraty PVC. Kopia jest
kopią VM z numeru 08. Dziesięć gigabajtów mieści się obok 20 GiB Prometheusa i obok reszty
dysku 120 GiB tylko wtedy, gdy wiek śladu jest ograniczony.

Retencja to 7 dni. W linii all-in-one, której pomoc opisuje `--badger.span-store-ttl`,
wartość to `168h`. Zmienna, według reguły obrazu „flaga na WIELKIE_WĘŻE”, to
`BADGER_SPAN_STORE_TTL`. Domyślne 72 godziny tej flagi to trzy dni, nie siedem, więc
manifest ustawia je wprost. Jeśli `help` przypiętego digestu drukuje inną nazwę tego samego
parametru, w manifeście ląduje ta nazwa, a liczba zostaje 7 dni. Liczba jest widoczna obok
15 dni Prometheusa. Wydłużenie jest osobną zmianą, z przeliczeniem PVC, nie cichą nadzieją,
że dysk „jeszcze pomieści”.

`QUERY_BASE_PATH` to `/`. Hostname, jeśli jest, leży na korzeniu nazwy, nie na podścieżce
strony CV. Podścieżka `/jaeger` przydałaby się za odwrotnym proxy. Tego proxy tu nie ma.
YARP tej ścieżki nie dostaje. Ustawienie `/` jest w manifeście, żeby nikt nie został z UI,
które szuka zasobów pod obcym prefiksem.

Koszt zapisu: wzrost liczby żądań może wypełnić 10 GiB. Drugi pod z numeru 15 nie mnoży
śladów sam z siebie. Mnoży je liczba żądań. Gdy PVC się zapełnia, skraca się retencja w
manifeście Jaegera. Nie dokładana jest druga instrumentacja i nie dokładany jest
Elasticsearch. Nie kasuje się PVC jako „czyszczenia”, bo razem z nim giną ślady incydentu,
które jeszcze mieszczą się w siedmiu dniach.

### Sampling: całość ruchu tej strony

Polityka to `parentbased_always_on` po stronie SDK w ServiceDefaults. Zostaje, jeśli tak
jest tam ustawione, i ten numer tego wymaga: maszyna nie próbkuje rzadziej niż laptop.
Collector nie ma drugiego samplera. Potok `traces` z numeru 10 ma procesor `batch` i nie
dostaje w tym numerze procesora probabilistycznego. Jaeger nie odrzuca procenta drzew po
przyjęciu OTLP.

Sampling 1 procent odpada. Przy rzadkim błędzie formularza rekrutera zguba śladu jest
droższa niż dysk 10 GiB. Sampling dopiero w Jaegerze, inny niż na laptopie, odpada, bo
laptop i VM pokazywałyby inne drzewa dla tego samego kodu. Wyłączenie śladów na `/health` i
`/alive` jest już w ServiceDefaults, w numerze Aspire. Ten plik tego filtra nie rusza. Ruch
strony jednej osoby i małej liczby czytelników mieści się w PVC przy retencji 7 dni, dopóki
ktoś nie wystawi obciążenia, które numer testów wydajności mierzy osobno.

Scenariusz rozjazdu: na laptopie dashboard pokazuje pełne drzewo `GET /versions`, a na
maszynie Jaeger pokazuje co setne. Operator wnioskuje, że brama na tagu nie tworzy spanu.
Tworzy. Sampler w collectorze go wyrzucił. Ten numer nie ma tego procesora. Jeśli drzewa
brakuje przy pełnym samplerze, przyczyna jest w eksporcie, w `trace_id` albo w tym, że
żądanie nie zeszło do usługi, a nie w procencie.

Koszt pełnego samplingu jest dyskiem. Gdy 10 GiB nie starcza, manifest skraca `168h` do
krótszego wieku i to jest widoczna zmiana. Nie jest nią cichy sampler 1 procent dopisany
tylko na VM.

### UI obok bramy aplikacji

Port `16686` jest ClusterIP. Publiczny hostname, jeśli istnieje, jest tym z numeru 09 i ma
Cloudflare Access. Origin to `http://jaeger.jjdevhub.svc.cluster.local:16686`. Jaeger UI nie
przechodzi przez YARP. YARP nie dostaje trasy `/jaeger`. Czytelnik CV nie dostaje drzew
żądań ani identyfikatorów technicznych w odpowiedzi strony.

Wystawienie UI na ścieżce strony CV odpada. Osobne hasło Jaegera w pliku w git odpada.
Jaeger na tym układzie nie jest miejscem, w którym trzymamy sekret logowania czytelnika.
Bezpieczeństwem UI jest brak portu na gościu oraz Access, gdy hostname jest. Z LAN zostaje
port-forward. Oba sposoby prowadzą do tego samego UI. Żaden nie idzie przez bramę aplikacji.

Probe gotowości patrzy na 16686 ścieżką, której używa obraz, często `/`. Probe OTLP nie jest
probe’em publicznym i nie jest powodem, żeby 4317 wyszło na adres węzła. `curl` z wnętrza
klastra na `:16686` ma dostać 200. `nc` z sieci spoza LAN na 16686 i na 4317 ma nie łączyć.

Koszt: operator z WAN loguje się do Access, z LAN używa port-forward. Z telefonu spoza konta
operatora UI nie jest celem. To jest ten sam podział co przy Prometheusie. Strona CV Accessu
nie dostaje.

### Korelacja z logiem, bez nowego SDK

Log na stdout ma `trace_id`, bo ServiceDefaults spina logger ze śladem. Ten numer nie
dokłada biblioteki logów i nie przepisuje `Program.cs`. Sprawdzenie jest ręczne przy
pierwszym żywym żądaniu: wartość z linii logu wklejona w wyszukiwarkę Jaegera otwiera
drzewo. W drzewie jest span wejścia bramy. Jeśli żądanie zeszło do usługi, jest też jej
span, z tym samym trace. W atrybutach zasobu spanu bramy `service.name` to `gateway`.

Brak `trace_id` w logu nie naprawia się filtrem w Jaegerze. Naprawia się w ServiceDefaults,
w numerze Aspire, bo to jedyne miejsce instrumentacji. Brak drzewa przy poprawnym `trace_id`
i przy Healthy eksporcie oznacza, że żądanie nie doszło albo sampler po drodze je wyciął.
Sampler po drodze ten numer wyklucza. Zostaje droga: log, collector, Jaeger.

Dwa pody tej samej usługi mają ten sam `service.name` i różne `service.instance`. Jaeger
pokaże oba spany w jednym drzewie, jeśli żądanie przeszło przez jeden z nich. Skalowanie
samo w sobie jest w numerze 15. Tu widać tylko, że drugi pod nie wymaga osobnego Jaegera i
nie wymaga adresu Jaegera w środowisku poda.

`trace_id` nie zastępuje kodu błędu w `ProblemDetails`. Pole `type` zostaje kontraktem API.
Identyfikator śladu jest obok, w logu, i w drzewie. Kto wstawi sam `trace_id` w miejsce
kodu, złamie numer API, nie ten plik. Ten plik tylko nie udaje, że drzewo jest odpowiedzią
dla czytelnika.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/observability/jaeger.yaml` | Deployment albo StatefulSet jednej repliki, PVC, Service OTLP i UI |
| `deploy/k3s/observability/otel-collector.yaml` | Eksporter `otlp/jaeger` wskazany w numerze 10; ten numer sprawdza, że nazwa Service się zgadza |

Jedna replika. HPA Jaegera nie ma. Obraz po digescie. Żądania: 200m CPU, 512 MiB pamięci.
PVC 10 GiB zamontowane w `/badger`. Proces musi móc tam pisać. Gdy obraz działa jako
użytkownik inny niż root, a wolumen jest tylko do odczytu dla tego użytkownika, pod wpada w
pętlę i ślad nie ląduje. To jest błąd montowania, nie powód, żeby wrócić do
`BADGER_EPHEMERAL=true`.

| Port | Rola | Kto łączy |
| --- | --- | --- |
| 4317 | OTLP gRPC Jaegera | Wyłącznie collector |
| 16686 | UI i API zapytania | `port-forward`, Grafana, ewentualnie tunel za Access |

Aplikacja do 4317 Jaegera nie łączy. Łączy do 4317 collectora. Service `jaeger` ma oba porty
jako ClusterIP. Jedno Service z dwoma portami wystarcza. Drugie Service o innej nazwie wolno
dodać tylko wtedy, gdy manifest Grafany ma wskazywać osobną nazwę. Domyślnie Grafana i
collector używają `jaeger`.

Szkic magazynu w manifeście, bez osobnego pliku sekretu:

```yaml
env:
  - name: SPAN_STORAGE_TYPE
    value: badger
  - name: BADGER_EPHEMERAL
    value: "false"
  - name: BADGER_DIRECTORY_VALUE
    value: /badger/data
  - name: BADGER_DIRECTORY_KEY
    value: /badger/key
  - name: BADGER_SPAN_STORE_TTL
    value: 168h
  - name: QUERY_BASE_PATH
    value: /
```

Jeśli obraz przypięty digestem czyta konfigurację YAML zamiast tych zmiennych, te same
decyzje lądują w ConfigMap: Badger, trwały katalog, OTLP na 4317, UI na 16686, wiek 7 dni,
baza ścieżki `/`. Nie lądują w kodzie usługi. Jeśli `help` nazywa wiek inaczej niż
`BADGER_SPAN_STORE_TTL`, manifest używa nazwy z `help`, a wartość zostaje siedem dni. Nie
ustawiaj `COLLECTOR_ZIPKIN_HOST_PORT`. Nie publikuj 4318, 9411, 14268 ani 14250.

## Plan

### 1. Pod i dysk

Deployment albo StatefulSet `jaeger`, jedna replika, PVC 10 GiB zamontowany w `/badger`.
Obraz `jaegertracing/all-in-one` po digescie. Żądania: 200m CPU, 512 MiB pamięci. Probe
gotowości na 16686 ścieżką obrazu, często `/`. Nie wiąż probe z odpowiedzią aplikacji
JJDevHub.

```bash
kubectl -n jjdevhub apply -f deploy/k3s/observability/jaeger.yaml
kubectl -n jjdevhub rollout status deploy/jaeger
kubectl -n jjdevhub rollout status statefulset/jaeger
```

Uruchom `rollout status` dla tego rodzaju, który jest w manifeście. Drugie polecenie dla
nieobecnego rodzaju skończy się błędem i nie jest częścią próby. Nazwa obiektu zostaje
`jaeger`. PVC ma być Bound, nie `emptyDir`. `BADGER_EPHEMERAL` zostaje `false`.

Service `jaeger` ma dwa porty, oba ClusterIP: `otlp` 4317 i `ui` 16686. Nie dodawaj
NodePort. Nie dodawaj portu Zipkina.

### 2. Zgodność z collectorem

W ConfigMap collectora pole `exporters.otlp/jaeger.endpoint` jest
`jaeger.jjdevhub.svc.cluster.local:4317` i `tls.insecure: true`. Po starcie Jaegera log
collectora przestaje zgłaszać odmowę połączenia na tym adresie. Pojedyncza linia z chwili
startu, zanim Jaeger był Ready, jest do pominięcia. Trwała odmowa po Ready Jaegera jest
błędem nazwy Service, portu albo tego, że Jaeger nie słucha OTLP.

Nie zmieniaj przy tym potoku metryk. Nie przekierowuj metryk na 4317 Jaegera. Nie dodawaj
samplera do potoku `traces`. Nie wpisuj adresu Jaegera do `deploy/k3s/apps/`.

### 3. Pierwsze drzewo

Gdy brama i co najmniej jedna usługa mają replikę, po numerze 16 albo wcześniej na próbę z
repliką testową, wyślij jedno żądanie na `/versions` przez tunel albo przez
`kubectl port-forward` na `gateway`.

```bash
kubectl -n jjdevhub logs deploy/gateway --tail=20
```

Z linii weź `trace_id`. W UI Jaegera wyszukaj ten identyfikator. Drzewo zawiera span wejścia
bramy. `service.name` tego spanu to `gateway`. Jeśli żądanie zeszło do usługi, drzewo
zawiera też jej span, z tym samym trace. `service.version` na spanie, gdy deploy już
podstawił tag, jest pełnym tagiem, na przykład `gateway-v1.4.0`, nie gołym numerem.

Przy nadal zerowych replikach aplikacji warunkiem zamknięcia numeru jest zdrowy odbiornik:
collector dostarcza, Jaeger przyjmuje, UI odpowiada. Drzewo z żywego ruchu dopisuje się przy
pierwszym deployu i jest sprawdzane ponownie w numerze 16. Nie podnoś repliki bramy tylko po
to, żeby ten punkt był zielony, jeśli numer 16 jeszcze nie oddał obrazu. Punkt przechodzi
dalej. Reszta tego pliku zostaje.

### 4. UI i tunel

Z LAN:

```bash
kubectl -n jjdevhub port-forward svc/jaeger 16686:16686
```

UI otwiera się na laptopie. Hostname publiczny powstaje tylko według numeru 09, z Access, na
korzeniu nazwy, z origin `jaeger.jjdevhub.svc.cluster.local:16686`. `QUERY_BASE_PATH`
zostaje `/`. YARP nie dostaje tej trasy. Bez Accessu hostname nie powstaje.

### 5. Wiek śladu

Ustaw retencję 7 dni w konfiguracji Badgera. Wartość w manifeście to `168h`, chyba że `help`
obrazu nazywa parametr inaczej. Wtedy nazwa jest z `help`, a czas zostaje siedem dni. Po
teście zapisu skasuj ręcznie tylko dane testowe, jeśli pochodzą z repliki próbnej, albo
zostaw je do wygaśnięcia. Nie kasuj PVC jako czyszczenia.

Gdy wolumen zbliża się do 10 GiB, skróć wiek w manifeście i zostaw ślad tej zmiany w git.
Nie dokładaj drugiego SDK i nie przepinaj magazynu na Kafkę produktu.

### Co jest do czego

Pod `jaeger` jest wołany przez collector jako magazyn i przez operatora oraz Grafanę jako
UI. Jedna replika. Gdy replik jest więcej bez osobnego planu dysku, dwa procesy piszą
Badgera albo dzielą się o jeden PVC w sposób, którego ten numer nie ustawia. HPA tego nie
podnosi.

Port 4317 jest wołany przez eksporter `otlp/jaeger`. Przyjmuje OTLP. Aplikacja go nie woła.
Gdy w `deploy/k3s/apps/` pojawi się ten host, usługa omija collector i numer 10 przestaje
być jedyną drogą sygnału. Port 16686 jest wołany przez przeglądarkę operatora i przez
datasource Grafany. Czytelnik strony go nie woła. YARP go nie woła.

PVC `/badger` jest wołane przez proces Jaegera. Ślad przeżywa restart poda. Gdy
`BADGER_EPHEMERAL` jest `true` albo wolumen jest pusty po restarcie, drzewo z incydentu
znika. To jest błąd tego numeru, nie cecha Badgera.

`trace_id` w logu jest wołany przez operatora przy incydencie. Most ze stdout do UI. Gdy go
nie ma, Jaeger nie ma czego wyszukać, nawet jeśli span powstał. Naprawa jest w
ServiceDefaults.

Dashboard Aspire jest wołany przez `aspire run`. To samo drzewo na laptopie, inny odbiornik.
AppHost nie wskazuje na Jaegera maszyny. Wpisanie `jaeger.jjdevhub.svc.cluster.local` do
zmiennej laptopa albo gasi skład, albo kusi, żeby otworzyć 4317 na zewnątrz. Oba końce są
poza tym numerem.

`QUERY_BASE_PATH=/` jest wołane przez UI przy składaniu adresów zasobów. Wartość inna niż
`/` na hostname korzenia gubi skrypty. Wartość `/jaeger` miałaby sens za proxy, którego nie
stawiamy.

`BADGER_SPAN_STORE_TTL=168h` jest wołane przez magazyn przy usuwaniu starych śladów.
Zostawienie domyślnych 72 godzin skraca retencję do trzech dni bez śladu w manifeście, że
ktoś tak wybrał. Siedem dni ma być widoczne w pliku.

## Testy

Testy są operacyjne. Padnięcie ma jeden objaw: brak endpointu, trwały błąd eksportu, UI nie
zwraca 200 wewnątrz klastra, port widać z zewnątrz, drzewo nie przeżywa restartu, albo
manifest aplikacji zawiera adres Jaegera.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | jedna replika all-in-one, Badger na PVC 10 GiB, `BADGER_EPHEMERAL=false`, retencja 7 dni, Service ClusterIP 4317 i 16686, collector wskazuje tę nazwę |
| Działanie (act) | endpointy, log collectora, `curl` na 16686 z klastra, `nc` spoza LAN, wyszukanie `trace_id`, restart poda, grep po `deploy/k3s/apps` |
| Sprawdzenie (assert) | oba porty mają adres, eksport nie powtarza odmowy, UI 200, gość nie łączy, ślad przeżywa restart, aplikacja nie zna Jaegera |

1. Pod Ready, endpointy na obu portach, PVC Bound.

```bash
kubectl -n jjdevhub get endpoints jaeger
kubectl -n jjdevhub get pvc
```

Są adresy dla 4317 i 16686. Typ Service to ClusterIP. Wolumen Badgera jest Bound i ma 10
GiB. `replicas` dostępne to 1. Nie ma HPA o nazwie `jaeger`. Obraz w manifeście zawiera
`@sha256:`.

2. Collector nie raportuje trwałego błędu eksportu śladów.

```bash
kubectl -n jjdevhub logs deploy/otel-collector --tail=100
```

Brak powtarzanej odmowy `jaeger.jjdevhub.svc.cluster.local:4317`. Pojedyncza linia z chwili
startu, zanim Jaeger był Ready, jest do pominięcia. Potok metryk w tym logu nie jest
przenoszony na port Jaegera. Błąd 8889 to numer 11, nie powód, żeby zmienić endpoint śladów.

3. UI odpowiada wewnątrz klastra.

```bash
kubectl -n jjdevhub run jaeger-curl --rm -it --restart=Never --image=curlimages/curl:8.10.1 -- \
  curl -fsS -o /dev/null -w '%{http_code}\n' http://jaeger.jjdevhub.svc.cluster.local:16686/
```

Kod to 200. Z sieci spoza LAN:

```bash
nc -vz <adres-gościa> 16686
nc -vz <adres-gościa> 4317
```

Oba nie łączą. Jeśli hostname istnieje, żądanie bez Accessu nie dostaje UI. To warunek
numeru 09. `QUERY_BASE_PATH` w manifeście to `/`.

4. Ślad próbny, gdy jest choć jeden pod bramy. Żądanie na `/versions` daje `trace_id` w logu
i drzewo w UI. W atrybutach zasobu spanu bramy `service.name` to `gateway`. Przy zerowych
replikach bramy ten punkt przechodzi na numer 16. Odbiornik i tak ma być zielony w punktach
1–3.

5. Restart poda Jaegera nie kasuje śladu próbnego, jeśli punkt 4 miał drzewo. Jeśli drzewa
jeszcze nie ma, punkt 5 wykonasz razem z pierwszym żywym żądaniem i nie zamykasz numeru na
pamięci.

```bash
kubectl -n jjdevhub delete pod -l app=jaeger
```

Po powrocie na to samo PVC ten sam `trace_id` nadal się wyszukuje. Jeśli wyszukiwanie jest
puste, PVC nie było podpięte albo magazyn został w pamięci (`BADGER_EPHEMERAL` nie jest
`false`, albo path nie jest `/badger`). To jest błąd tego numeru. Restart Jaegera nie
restartuje bramy. Czas startu poda `gateway` zostaje.

6. W manifeście usług nie ma zmiennej z hostem Jaegera.

```bash
git grep -n "16686\|jaeger.jjdevhub" -- deploy/k3s/apps || true
git grep -n "16686" -- deploy/k3s/observability || true
```

Port 16686 występuje w `deploy/k3s/observability/jaeger.yaml` i, jeśli Grafana już ma szkic,
w jej datasource. Nie występuje w `deploy/k3s/apps`. Adres
`jaeger.jjdevhub.svc.cluster.local` w aplikacjach też nie występuje. W aplikacjach zostaje
adres collectora z numeru 10.

7. W ConfigMap collectora nie ma procesora samplera w potoku `traces`. Jest `batch` i
eksporter `otlp/jaeger`. Polityka `parentbased_always_on` zostaje po stronie SDK. Rozjazd
„na VM rzadszy sampling” jest błędem tego numeru, nawet gdy dysk jest ciasny. Na ciasny dysk
odpowiedzią jest krótsza retencja w manifeście, widoczna obok liczby 7 dni.

## Zasady

- Aplikacja eksportuje wyłącznie do collectora. Adres Jaegera zna collector. W
  `deploy/k3s/apps/` tego adresu nie ma.
- Magazyn śladów to Badger na PVC 10 GiB. `BADGER_EPHEMERAL` to `false`. Pamięć jako jedyny
  magazyn nie wchodzi.
- Jedna replika. HPA Jaegera nie podnosi. Obraz `jaegertracing/all-in-one` jest digestem.
- Retencja śladu to 7 dni. W manifeście widać `168h` albo parametr `help` o tej samej
  długości. Domyślne 72 godziny nie zostają jako milczący wiek.
- UI nie idzie przez YARP i nie słucha na adresie gościa. `QUERY_BASE_PATH` to `/`.
- Publiczny hostname Jaegera bez Access nie powstaje. Porty 4317 i 16686 są ClusterIP.
- Sampling na VM jest `parentbased_always_on`, zgodny z ServiceDefaults. Collector nie
  dokłada drugiego samplera.
- Service publikuje 4317 dla collectora i 16686 dla UI. Nie publikuje Zipkina ani
  dodatkowych portów z przykładu all-in-one.
- Ślad nie jest zdarzeniem domenowym i nie wchodzi na Kafkę produktu. Elasticsearch i
  Cassandra nie są backendem.
- `trace_id` nie zastępuje kodu błędu w `ProblemDetails`.
- Restart Jaegera nie restartuje bramy. Restart poda nie kasuje śladu, który leży na PVC.
- AppHost nie wskazuje na Jaegera maszyny. Dashboard Aspire zostaje odbiornikiem laptopa.
- Przy zerowych replikach bramy drzewo żywego żądania przechodzi na numer 16. Odbiornik, PVC
  i UI wewnątrz klastra i tak są warunkiem tego numeru.
- Nie kasuje się PVC, żeby usunąć ślad testowy. Testowe dane wygasają albo są usuwane bez
  zdejmowania wolumenu.
- Metryki nie są wysyłane na 4317 Jaegera. Potok metryk zostaje przy numerze 10 i 11.

## Poza zakresem

- SDK, nazwy zasobu i potok collectora są w [10-opentelemetry.md](10-opentelemetry.md). Ten
  numer sprawdza endpoint `otlp/jaeger`. Nie przepisuje `AddOpenTelemetry`.
- Metryki i rekord HPA są w [11-prometheus.md](11-prometheus.md). Jaeger nie scrapuje
  `:8889` i nie trzyma `http_server_active_requests`.
- Datasource Jaegera na wykresie jest w [13-grafana.md](13-grafana.md). Tu powstaje Service,
  z którego datasource wolno czytać. Nie powstaje JSON panelu.
- Access i hostname są w [09-cloudflare.md](09-cloudflare.md). Ten numer nie tworzy rekordu
  DNS. Wymaga Accessu, jeśli rekord jest, i originu na 16686.
- Dysk i kopia VM są w [08-proxmox.md](08-proxmox.md). Utrata PVC odtwarza się z kopii
  maszyny, nie z repliki Jaegera.
- Drugi pod. Oba pody tej samej usługi mają ten sam `service.name` i różne
  `service.instance`. Jaeger pokaże oba spany w jednym drzewie, jeśli żądanie przeszło przez
  jeden z nich. Skalowanie samo w sobie jest w [15-skalowanie.md](15-skalowanie.md).
- Zgodność `service.version` z tagiem przy rolloutcie jest w [16-deploy.md](16-deploy.md).
  Przy zerowych replikach bramy drzewo żywego `/versions` jest sprawdzane tam.
- Treść logu aplikacyjnego i kody `Result` są w numerach `docs/api`. `trace_id` stoi obok
  kodu. Nie zastępuje pola `type`.
- Filtr ścieżek `/health` i `/alive` jest w ServiceDefaults. Ten plik go nie wyłącza i nie
  przenosi do Jaegera.
- Próg wydajności i NBomber nie mierzą zapełnienia Badgera. Gdy dysk się zapełnia, skraca
  się retencja w manifeście.

## Źródła

- [Jaeger — dokumentacja](https://www.jaegertracing.io/docs/). Wiążąca jest rola systemu:
  przyjąć ślad, przechować go i pokazać drzewo w UI. Dotyczy jednego procesu na tej VM,
  czytanego po `trace_id` z logu. Ze źródła nie bierzemy Jaegera jako zamiennika
  Prometheusa. Metryka zostaje w numerze 11.
- [Jaeger — wdrożenie](https://www.jaegertracing.io/docs/latest/deployment/). Wiążący jest
  opis komponentów i tego, że all-in-one łączy odbiornik, magazyn i zapytanie. Dotyczy
  jednej repliki na jednym węźle. Ze źródła nie bierzemy osobnego klastra Elasticsearch albo
  Cassandry jako warunku uruchomienia. Backend tego numeru to Badger.
- [Jaeger — backendy spanów](https://www.jaegertracing.io/docs/latest/deployment/#span-storage-backends).
  Wiążący jest wybór magazynu spanów w tym opisie wdrożenia. Dotyczy Badgera na trwałym
  katalogu, nie pamięci procesu. Ze źródła nie bierzemy Elasticsearch, Cassandry ani Kafki
  jako bufora śladów.
- [Jaeger 1.76 — magazyny](https://www.jaegertracing.io/docs/1.76/deployment/#span-storage-backends).
  Wiążące są zmienne Badgera: `SPAN_STORAGE_TYPE=badger`, `BADGER_EPHEMERAL=false`, katalogi
  `/badger/data` i `/badger/key`. Dotyczy PVC zamiast tmpfs. Ze źródła nie bierzemy pamięci,
  Cassandry, Elasticsearch ani remote storage jako magazynu JJDevHub.
- [Jaeger 1.76 — all-in-one](https://www.jaegertracing.io/docs/1.76/getting-started/#all-in-one).
  Wiążące są port 16686 dla UI i port 4317 dla OTLP. Dotyczy Service ClusterIP z dokładnie
  tymi dwoma portami. Ze źródła nie bierzemy publikacji 4318, 9411, 14268 i pozostałych
  portów przykładu `docker run`. Przykład startowy trzyma ślad w pamięci, a ten numer
  ustawia Badger na PVC.
- [Flagi Badgera i UI](https://www.jaegertracing.io/docs/1.76/deployment/cli/). Wiążące są
  `--badger.span-store-ttl` (domyślnie 72 godziny), `--badger.ephemeral` i
  `--query.base-path` (domyślnie `/`). Dotyczy `BADGER_SPAN_STORE_TTL=168h`,
  `BADGER_EPHEMERAL=false` i `QUERY_BASE_PATH=/`. Ze źródła nie bierzemy
  `--memory.max-traces` jako magazynu ani base path `/jaeger`, bo UI nie stoi za podścieżką
  YARP.
- [OTLP w Jaegerze](https://www.jaegertracing.io/docs/latest/getting-started/#all-in-one).
  Wiążące jest przyjęcie OTLP na 4317 przez proces all-in-one. Dotyczy tego, że collector
  jest jedynym klientem tego portu. Ze źródła nie bierzemy instrukcji, żeby aplikacja .NET
  wysyłała ślad wprost na ten adres. Aplikacja zna collector.
- [OpenTelemetry — ślady](https://opentelemetry.io/docs/concepts/signals/traces/). Wiążące
  jest drzewo spanów i wspólny `trace_id`. Dotyczy przejścia od spanu bramy do spanu usługi
  i do linii logu. Ze źródła nie bierzemy traktowania śladu jako zdarzenia domenowego na
  Kafce produktu.
- [Sampling](https://opentelemetry.io/docs/concepts/sampling/). Wiążące jest próbkowanie po
  stronie SDK, z poszanowaniem decyzji rodzica. Dotyczy `parentbased_always_on` i zakazu
  drugiego samplera w collectorze. Ze źródła nie bierzemy samplingu 1 procent „bo dysk”. Na
  ciasny dysk odpowiedzią jest krótsza retencja.
- [SDK śladu](https://opentelemetry.io/docs/specs/otel/trace/sdk/). Wiążący jest sampler
  `ParentBased` z `AlwaysOn`. Dotyczy tego, że maszyna i laptop pokazują to samo drzewo dla
  tego samego kodu. Ze źródła nie bierzemy samplera ustawianego dopiero w Jaegerze, innego
  niż w ServiceDefaults.
- [Zmienne SDK](https://opentelemetry.io/docs/languages/sdk-configuration/general/). Wiążące
  jest `OTEL_TRACES_SAMPLER` jako miejsce polityki, jeśli ServiceDefaults nie ustawia jej w
  kodzie. Dotyczy utrzymania `parentbased_always_on` bez wpisywania adresu Jaegera. Ze
  źródła nie bierzemy skierowania `OTEL_EXPORTER_OTLP_ENDPOINT` na `jaeger:4317` w podzie
  aplikacji.
- [Propagacja kontekstu](https://opentelemetry.io/docs/concepts/context-propagation/).
  Wiążące jest przeniesienie `trace_id` między bramą, usługą i logiem. Dotyczy ręcznego
  sprawdzenia: identyfikator z stdout otwiera drzewo. Ze źródła nie bierzemy własnego
  nagłówka spoza tego kontekstu jako drugiego identyfikatora śladu.
- [Grafana i Jaeger](https://grafana.com/docs/grafana/latest/datasources/jaeger/). Wiążące
  jest to, że Grafana umie czytać Jaegera jako datasource po adresie UI. Dotyczy zapowiedzi
  numeru 13: adresem będzie `jaeger.jjdevhub.svc.cluster.local:16686`. Ze źródła nie
  bierzemy stawiania Grafany w tym numerze ani hasła Jaegera w pliku datasource.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest ClusterIP z dwoma portami na jednym Service. Dotyczy 4317 i 16686 bez
  NodePort. Ze źródła nie bierzemy typu, który wystawia UI na adresie gościa.
- [Trwałe wolumeny](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).
  Wiążące jest PVC, które przeżywa `delete pod`. Dotyczy 10 GiB pod `/badger` i testu, że
  `trace_id` nadal się wyszukuje. Ze źródła nie bierzemy `emptyDir` jako magazynu śladu
  incydentu.
- [kubectl port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).
  Wiążące jest tymczasowe wejście na Service z maszyny operatora. Dotyczy UI na czas
  polecenia, z LAN, na porcie 16686. Ze źródła nie bierzemy zostawienia forwardu jako
  stałego wejścia z internetu.

## Gotowe gdy

- Pod `jaeger` jest Ready, jedna replika, obraz po digescie, PVC 10 GiB jest Bound,
  `BADGER_EPHEMERAL` to `false`.
- Service jest ClusterIP z portami 4317 i 16686. Innych portów przykładu all-in-one nie ma.
- Retencja w manifeście to 7 dni (`168h` albo nazwa z `help` o tej samej długości).
  `QUERY_BASE_PATH` to `/`.
- Log collectora nie powtarza błędu połączenia z `jaeger.jjdevhub.svc.cluster.local:4317`.
- Potok śladów collectora nie ma drugiego samplera. SDK zostaje przy
  `parentbased_always_on`.
- `curl` wewnątrz klastra na `:16686` zwraca 200. `nc` na 16686 i na 4317 z sieci spoza LAN
  nie łączy.
- Po restarcie poda ślad zapisany przed restartem nadal jest w UI, a brama nie została
  zrestartowana razem z Jaegerem.
- W `deploy/k3s/apps/` nie ma adresu Jaegera ani portu 16686.
- YARP nie ma trasy `/jaeger`. Hostname, jeśli jest, ma Access i origin na 16686.
- Przy żywej bramie jedno żądanie `/versions` daje `trace_id` w logu i drzewo ze
  `service.name=gateway`.
- Jeśli brama ma jeszcze zero replik, punkt drzewa przechodzi na numer 16, a odbiornik, PVC,
  retencja i zamknięte porty i tak są spełnione.
- Elasticsearch, Cassandra i Kafka jako bufor śladów nie są postawione. AppHost nie wskazuje
  na ten Jaeger.
