# 15. Skalowanie

Ten numer podnosi drugi pod tej samej usługi, gdy CPU albo liczba żądań HTTP w toku
przekroczy próg, i ściąga go z powrotem, gdy oba sygnały opadną. Poprzedni numer,
[OpenBao](14-openbao.md), wydaje poświadczenia bazy na godzinę. Następny plik,
[deploy](16-deploy.md), wstawia obraz z tagu. W kolejności pracy próg idzie po
[kontakcie](../api/21-kontakt.md): deploy bramy już był, metryka HTTP już ma
rekord w Prometheusie, a usługi mają obraz. Następny krok pracy to
[piramida testów](../api/22-testy.md).
Tutaj powstaje siedem obiektów `HorizontalPodAutoscaler` w wersji `autoscaling/v2` i
adapter, który czyta ten rekord. Trzeci pod nie powstaje.

Scenariusz, który bez progu się rozpada, zaczyna się od wieczoru bez ruchu i od
`kubectl scale --replicas=2`. Drugi pod News żyje do rana, zjada RAM na węźle z numeru 08 i
nie wraca do jednej repliki, bo nikt nie pamięta, że scale był „na chwilę”. Krótki wzrost
odczytu CV albo katalogu kursów nie wymaga drugiej maszyny. Wymaga drugiej repliki tego
samego Deploymentu, za tym samym Service ClusterIP, za tym samym YARP, i wymaga powrotu do
jednej repliki, gdy ruch zejdzie.

Drugi scenariusz psuje się na szynie. Drugi pod bez inboxa wchodzi do grupy konsumentów,
dostaje ponowioną wiadomość i wysyła drugi push albo dopisuje drugi wiersz projekcji.
Identyfikator wiadomości jest ten sam. Skutek ma być jeden. Ten numer nie pisze inboxa drugi
raz. Wymaga, żeby przy dwóch replikach był włączony, i sprawdza skutek. Na laptopie Aspire
zostaje przy jednej replice. Dashboard Aspire nie udaje HPA.

## Po co

Jeden pod usługi ma jeden limit wątków i jeden wycinek CPU. Dwadzieścia powolnych żądań CV
może wisieć na Postgresie przy niskim zużyciu procesora. Sam wykres CPU wtedy milczy, a
kolejne połączenie i tak wchodzi w tę samą pulę. Drugi sygnał, średnio 20 żądań HTTP w toku,
podnosi replikę, zanim CPU dobije do 70 procent requestu. Odwrotny przypadek też jest w
progu: pętla, która zużywa CPU bez wzrostu licznika HTTP, nie chowa się za samym licznikiem
żądań. Spełnienie któregokolwiek progu podnosi replikę. Oba muszą opaść, żeby została jedna
replika, i odczekanie w dół trwa 300 sekund, żeby pojedynczy dołek nie ubił poda w trakcie
żądania.

Sufit to dwa pody. Podłoga to jeden, gdy digest już jest i numer 16 podniósł repliki. Trzeci
pod jest błędem manifestu, nie zapasem. `Pending` z braku CPU albo pamięci nie jest
obchodzone przez podniesienie `maxReplicas`. Węzeł ma 4 vCPU i 16 GiB. Drugi pod, który nie
ma gdzie stanąć, widać w `kubectl get pods`. Próg nie omija fizycznego RAM.

Oba pody serwują to samo HTTP. Ten sam obraz, ten sam port 8080, ten sam zestaw zmiennych
poza nazwą instancji. Service rozkłada połączenia. YARP woła Service po nazwie, na przykład
`http://news.jjdevhub.svc.cluster.local:8080`, i nie woła konkretnego poda.
`sessionAffinity` jest `None` albo pola nie ma. Przywiązanie do adresu klienta zostawiłoby
gorący pod z całym ruchem, a drugi stałby pusty. JWT jest bezstanowy. Stan jest w
Postgresie. Cache jest w Redisie pod prefiksem usługi, nie w pamięci jednego procesu.

Inbox jest włączony w każdej usłudze, która konsumuje. Drugi pod wchodzi do grupy nazwanej
jak usługa. Temat integracyjny ma co najmniej dwie partycje, więc oba pody mogą czytać. Przy
jednej partycji drugi pod i tak serwuje HTTP, a na szynie stoi bezczynnie do rebalansu.
Rebalans oddaje ten sam identyfikator drugiemu podowi albo temu samemu po restarcie. Inbox w
bazie zapisu pamięta identyfikator. Drugi raz ten sam identyfikator nie aktualizuje
projekcji i nie wysyła pusha.

`mobile` nie ma Deploymentu, więc nie ma HPA. Telefon jest klientem. Jego numer zostaje na
ekranie O aplikacji. Web ma HPA, request CPU 50m i ten sam sufit dwóch podów. Drugi pod weba
serwuje ten sam numer `web-vX.Y.Z`. Nie serwuje innego numeru „dla drugiej repliki”.

Na laptopie każdy projekt usługi, bramy i weba ma jedną replikę. Nie ma pętli, która przy
lokalnym CPU stawia drugi proces. Testy integracyjne podnoszą jedną kopię usługi i jednego
brokera. Rebalans jest sprawdzany na maszynie albo testem inboxa, który publikuje duplikat
do jednego procesu. Jedno sprawdzenie nie zastępuje drugiego.

## Dlaczego ta technologia

### HPA, minimum 1, maksimum 2

`HorizontalPodAutoscaler` w `autoscaling/v2` pilnuje Deploymentu. `minReplicas` to 1.
`maxReplicas` to 2. Poniżej progu zostaje jeden pod, o ile Deployment w ogóle ma repliki.
Powyżej progu scheduler stawia drugi, jeśli węzeł ma wolne CPU i pamięć. Trzeci nie
powstaje, także wtedy, gdy oba sygnały są daleko nad progiem. Dwa progi nie dodają się do
czterech replik. Biorą wyższą z dwóch wyliczonych liczb, a ta liczba i tak jest obcięta do
2.

Ręczne `kubectl scale --replicas=2` jako stały tryb odpada. Drugi pod żyje w nocy, bez
ruchu, i nie wraca. Osobna maszyna na skalę poziomą odpada, bo celem ciągu jest jeden węzeł
z numeru 08. KEDA albo kolejka jako źródło skalowania odpada: sygnał, o który chodzi, jest
synchronicznym HTTP. Kafka jest obsłużona inboxem, nie liczbą zaległych wiadomości. Lag na
partycji nie mówi, czy strona CV właśnie stoi. Mówi to licznik żądań w toku i CPU procesu,
który te żądania obsługuje.

Koszt jest widoczny i jest przyjęty. Na jednym węźle drugi pod bywa `Pending`, gdy pamięć
jest zajęta. To nie jest powód, żeby wpisać `maxReplicas: 3` albo `4`. Trzeci wpis w
manifeście nie tworzy RAM. Tworzy kolejkę podów, których scheduler nie położy, i uczy
operatora podnosić sufit przy każdym `Pending`. Powód `Pending` czyta się w
`kubectl describe pod`. Brak pamięci zostaje brakiem pamięci.

HPA wolno zastosować przy `replicas: 0` z numeru 08, ale skalowanie od zera nie jest tym, co
nadaje pierwszy digest. Ten numer nie podnosi replik ręcznie, żeby „zobaczyć HPA”, dopóki
obraz nie pochodzi z tagu. Pierwsza replika jest decyzją numeru 16 i jest równa 1, nie 2.
Drugi pod zostaje decyzją progu.

### Dwa sygnały: CPU i żądania w toku

Pierwszy sygnał to zasób `cpu`, typ `Utilization`, średnio 70 procent requestu poda. Źródło
to metrics-server, ten sam, który k3s wystawia do `kubectl top` i do `metrics.k8s.io`.
Prometheus nie jest źródłem tej liczby. Jest źródłem metryki HTTP, której metrics-server nie
zna. Pakowanie CPU do Prometheusa i czytanie go stamtąd przez adapter, przy działającym
metrics-server, dawałoby dwa progi tego samego zasobu. Próg HPA jest ten z requestu i z
metrics-server, nie ten z wykresu cAdvisor, jeśli numer 11 rysuje węzeł.

Drugi sygnał to metryka zewnętrzna `jjdevhub_http_server_active_requests`, cel
`AverageValue` równy `20`. Adapter czyta rekord `jjdevhub:http_server_active_requests:sum` z
numeru 11. Etykieta `service_name` przechodzi z rekordu do selektora. HPA News ma
`service_name: news`. Bez tej etykiety News widziałoby sumę Identity, Learning, Cv, Contact,
bramy i weba. Suma pięciu usług przekroczyłaby 20 przy zwykłym ruchu strony i podniosłaby
News, choć News nic nie trzyma. To jest błąd konfiguracji adaptera, nie powód, żeby próg
podnieść.

Sam CPU odpada jako jedyny sygnał. Pod może trzymać dwadzieścia żądań czekających na
Postgresa przy niskim CPU i nadal potrzebować drugiej repliki, która przyjmie kolejne
połączenia. Same żądania w toku odpadają jako jedyny sygnał. Pętla zużywająca CPU bez
wzrostu licznika HTTP zostałaby niewidoczna. Próg „zawsze 2 repliki w godzinach pracy”
odpada, bo nie ma tu harmonogramu ruchu. Strona jednej osoby nie ma szczytu wpisanego w
godziny.

`behavior.scaleUp.stabilizationWindowSeconds` to 60.
`behavior.scaleDown.stabilizationWindowSeconds` to 300. Na obu kierunkach `selectPolicy` to
`Max`. Przy CPU pod progiem i przy 25 żądaniach w toku wygrywa sygnał HTTP: z dwóch
wyliczonych liczb replik zostaje większa, a sufit i tak ucina ją do 2. Okno w górę nie
podnosi poda od jednego skoku trwającego sekundę. Okno w dół nie ściąga poda, który przed
chwilą dostał żądanie, tylko dlatego, że licznik na moment spadł.

Koszt: prometheus-adapter musi działać. Inaczej metryka HTTP jest nieznana. HPA oznacza ją w
`kubectl describe hpa` jako brakującą i skaluje tylko z CPU. Brakująca metryka nie jest
milczącym sukcesem. Nie wolno jej zamienić na zero, żeby „próg zawsze był spełniony”, i nie
wolno jej zamienić na stałą 20, żeby „było spokojnie”. Jedno podnosi pody bez ruchu. Drugie
gasi sygnał, po który ten numer powstał.

### Ten sam HTTP na obu podach

Oba pody mają ten sam obraz i ten sam port. Service ClusterIP ma dwa adresy w endpoincie,
gdy oba są Ready, i jeden, gdy drugi jest `Pending`. YARP o liczbie adresów nie wie. Woła
nazwę Service. Drugiego Service „dla repliki drugiej” nie ma. Selector etykiet jest ten sam.
Dopisanie etykiety `replica=b` tylko na drugim podzie wyjęłoby go z Service i zostawiło ruch
na pierwszym. To jest odwrotność skalowania.

Osobna replika do odczytu i osobna do zapisu, jako dwa Deploymenty, odpadają. To byłby inny
produkt, z innym HPA i z podziałem, którego brama nie ma. Trasa News zostaje jedna. Sticky
cookie na YARP odpada, bo drugi pod ma odciążyć pierwszy, a nie dostać zero ruchu.
`sessionAffinity: ClientIP` na Service robi to samo wewnątrz klastra: czytelnik z jednego
adresu zostaje na podzie, który już jest gorący.

Koszt jest ten sam co przy jednym podzie, nie gorszy. Żądanie, które trafi na drugiego poda
w trakcie projekcji, może przez chwilę dostać `404` i ma być ponowione. Projekcja jest
asynchroniczna także przy jednej replice. Drugi pod tego nie leczy i tego nie pogarsza. Nie
powstaje tu osobny kod błędu „replika jeszcze nie wie”.

Request CPU jest mianownikiem dla `Utilization`. Bez `resources.requests.cpu` procent nie ma
do czego się odnieść i sygnał CPU jest ślepy albo liczony od limitu, którego ten numer nie
używa jako progu. Usługa i brama mają request 100m. Web ma 50m. Pamięć request to 256Mi na
tych siedmiu Deploymentach, żeby drugi pod nie został zaplanowany za darmo i potem zabity.
Drugi pod dokłada drugie tyle. To się mieści w CPU węzła. W pamięci mieści się albo zostaje
`Pending`. `Pending` nie podnosi sufitu.

Poświadczenia obu podów są osobnymi dzierżawami tej samej roli OpenBao. Ten numer nie
wpisuje wspólnego hasła do zmiennej. Wspólne hasło wraca do układu, który numer 14 zdejmuje.

### Inbox, żeby drugi konsument nie dublował skutku

Proces, który serwuje HTTP, jest też konsumentem Kafki. Drugi pod wchodzi do grupy o nazwie
usługi: `news`, `learning`, `cv`, `contact`, `identity`, zależnie od tego, kto konsumuje.
Tematy, których nazwy ustalił numer Kafki w `docs/api`, mają `partitions` co najmniej 2.
Nazwa zostaje. Przykład, który się nie zmienia, to `segment.fakt.v1`. Nie powstaje temat
`segment.fakt.v1.replica-2`. Zmiana dotyczy liczby partycji na brokerze z numeru 08, nie
nazwy zdarzenia.

Idempotencja producenta nie zastępuje inboxa. Producent gasi podwójny zapis tej samej kopii
na partycji. Konsument i tak dostaje dostawę co najmniej raz: rebalans, restart, commit
offsetu po skutku, który nie zdążył się zatwierdzić. Okno między zapisem skutku a commitem
offsetu jest oknem dubla, gdy jedyną pamięcią jest offset. Inbox w bazie zapisu jest w tej
samej transakcji co skutek, tak jak ustala numer Kafki. Ten numer tego nie pisze drugi raz.
Wymaga, żeby produkcyjny pod nie miał inboxa wyłączonego.

Konsument „co najwyżej raz” oparty tylko na ręcznym commicie offsetu odpada. Offset i skutek
w bazie nie są jedną transakcją z brokerem. Wyłączenie konsumenta na drugim podzie, „drugi
pod tylko HTTP”, odpada jako jedyna ochrona. Przy rebalansie zostaje jeden konsument, a po
śmierci pierwszego poda drugi musi umieć dokończyć wiadomość bez dubla. Pod, który serwuje
HTTP i nie umie dokończyć wiadomości, zostawia partycję w miejscu, w którym zginął sąsiad.

Koszt: temat z dwiema partycjami i wiersze inboxa w bazie zapisu. Wiersze inboxa są stanem
usługi, nie sekretem. Nie wchodzą do OpenBao i nie wchodzą do logu jako ciało zdarzenia.
Sprawdzenie skutku jest jedno: jeden identyfikator, jeden wiersz projekcji albo jeden push.
Drugie opublikowanie tego samego identyfikatora nie dokłada drugiego skutku.

### Aspire: jedna replika

W `JJDevHub.AppHost` projekty zostają przy jednej replice. Wywołanie `WithReplicas` albo nie
występuje, albo ma argument `1`. Brak wywołania w Aspire oznacza domyślnie jedną replikę i
spełnia zasadę. Argument większy niż 1 jest błędem tego numeru. Nie ma parametru, który
czyta CPU laptopa i uruchamia drugi proces.

Kopiowanie manifestu HPA do AppHost odpada. Laptop nie ma prometheus-adaptera w składzie
deweloperskim, a drugi lokalny proces psuje założenie testu „jeden konsument”. `aspire run`
pokazuje jedną kopię `news` i jedną kopię pozostałych projektów z listy komponentów
klastrowych. Dashboard Aspire zostaje ekranem laptopa. Nie rysuje pożądanej liczby replik z
metryki zewnętrznej, bo tej metryki na laptopie nie ma.

Koszt: deweloper nie widzi na co dzień rebalansu. Rebalans jest sprawdzany na maszynie, gdy
dwa pody są Ready, oraz testem integracyjnym inboxa przy numerze szyny. Oba są wymagane.
Test na jednym procesie, który puszcza duplikat, łapie logikę inboxa. Nie łapie tego, że
produkcyjny manifest wyłączył inboxa zmienną. Przegląd zmiennych Deploymentu na maszynie
łapie wyłączenie. Nie łapie błędu w transakcji. Dlatego oba zostają.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/hpa/prometheus-adapter.yaml` | Adapter: rekord Prometheusa jako metryka zewnętrzna |
| `deploy/k3s/hpa/identity.yaml` | HPA Identity, `service_name: identity` |
| `deploy/k3s/hpa/news.yaml` | HPA News, `service_name: news` |
| `deploy/k3s/hpa/learning.yaml` | HPA Learning, `service_name: learning` |
| `deploy/k3s/hpa/cv.yaml` | HPA Cv, `service_name: cv` |
| `deploy/k3s/hpa/contact.yaml` | HPA Contact, `service_name: contact` |
| `deploy/k3s/hpa/gateway.yaml` | HPA bramy, `service_name: gateway` |
| `deploy/k3s/hpa/web.yaml` | HPA weba, `service_name: web` |
| `JJDevHub.AppHost` | Jedna replika każdego projektu, bez HPA |

Bez HPA zostają: Postgres, Redis, Kafka, OpenBao, collector, Prometheus, Jaeger, Grafana,
`cloudflared`, SonarQube. W manifeście nie ma obiektu HPA o nazwie `postgres`, `redis`,
`cache`, `kafka`, `openbao`, `collector`, `otel-collector`, `prometheus`, `jaeger`,
`grafana`, `cloudflared`, `sonar` ani `sonarqube`. `mobile` nie ma Deploymentu i nie dostaje
ósmego pliku.

Manifest News, wzór dla pozostałych plików. Zmienia się `name` i etykieta `service_name`.

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: news
  namespace: jjdevhub
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: news
  minReplicas: 1
  maxReplicas: 2
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: External
      external:
        metric:
          name: jjdevhub_http_server_active_requests
          selector:
            matchLabels:
              service_name: news
        target:
          type: AverageValue
          averageValue: "20"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: 300
      selectPolicy: Max
```

`averageUtilization: 70` jest procentem requestu, nie procentem węzła. `averageValue: "20"`
jest średnią żądań w toku na pod, nie sumą klastra. Selektor `service_name` jest obowiązkowy
na każdym z siedmiu plików i jest inny w każdym. Okno 60 i okno 300 oraz `selectPolicy: Max`
są na wszystkich siedmiu. `maxReplicas` większe niż 2 jest błędem, także w pliku weba.

Adapter wystawia `jjdevhub_http_server_active_requests` z rekordu
`jjdevhub:http_server_active_requests:sum`. Etykieta `service_name` przechodzi dalej. Reguła
zewnętrzna wskazuje ten rekord i nie sumuje go drugi raz bez etykiety.

```yaml
externalRules:
  - seriesQuery: '{__name__="jjdevhub:http_server_active_requests:sum"}'
    metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (service_name)'
    name:
      matches: "jjdevhub:http_server_active_requests:sum"
      as: "jjdevhub_http_server_active_requests"
```

Gdy żywa metryka z collectora nazywa etykietę inaczej niż `service_name`, reguła
rejestrująca w numerze 11 ma wystawić etykietę `service_name`. Ten numer nie tworzy trzeciej
nazwy. Nie czyta surowej nazwy SDK.

Deployment aplikacji deklaruje requesty, inaczej `Utilization` nie ma mianownika, a drugi
pod wygląda na darmowy:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 256Mi
```

Dla `web` CPU w tym bloku to `50m`. Pamięć zostaje 256Mi. Brama ma 100m, jak usługa.
Postgres, Kafka, OpenBao, collector, Prometheus, Jaeger, Grafana i `cloudflared` nie dostają
tego HPA, choć własne requesty mogą mieć z wcześniejszych numerów.

Service nie dostaje drugiego obiektu. Pole przywiązania:

```yaml
spec:
  sessionAffinity: None
```

Brak pola jest tym samym co `None`. `ClientIP` jest błędem.

## Plan

### 1. Adapter

Zastosuj `deploy/k3s/hpa/prometheus-adapter.yaml`. Adapter czyta
`http://prometheus.jjdevhub.svc.cluster.local:9090`. Jedna replika, ClusterIP, bez HPA na
samym adapterze. Reguła zewnętrzna jest tą z sekcji ścieżek: rekord
`jjdevhub:http_server_active_requests:sum`, nazwa `jjdevhub_http_server_active_requests`,
grupowanie po `service_name`. Po starcie:

```bash
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/jjdevhub/jjdevhub_http_server_active_requests"
```

Odpowiedź jest listą metryk, także pustą, gdy aplikacje mają zero replik. Błąd „nieznana
metryka” jest błędem tego kroku.

### 2. Etykieta na rekordzie

Rekord z numeru 11 grupuje po `service_name`. Nie dodawaj tu drugiej reguły o innej nazwie.
Sprawdź w Prometheusie, że `news` da się wybrać selektorem. Przy zerowych replikach
sprawdzenie etykiety przechodzi na pierwsze żądanie po numerze 16 i jest tam warunkiem HPA,
nie nową metryką.

### 3. HPA siedmiu Deploymentów

Zastosuj siedem plików. W każdym `minReplicas` to 1, `maxReplicas` to 2, CPU 70, metryka
zewnętrzna z `AverageValue` `20`, okna 60 i 300, `selectPolicy: Max`. Dla każdego:

```bash
kubectl -n jjdevhub describe hpa news
```

`TARGETS` pokazuje CPU i metrykę zewnętrzną. `MINPODS` to 1, `MAXPODS` to 2. Przy braku
ruchu `REPLICAS` zostaje 1, o ile Deployment ma repliki. Nie ustawiaj replik na 2, żeby
zobaczyć obiekt. Nie podnoś `maxReplicas`, gdy pod jest `Pending`.

### 4. Service i YARP

Nie dodawaj drugiego Service. Nie ustawiaj `sessionAffinity: ClientIP`. Trasa YARP zostaje
na nazwie Service. Drugi pod dostaje ten sam selector co pierwszy. Sprawdzenie:

```bash
kubectl -n jjdevhub get endpoints news
```

Przy dwóch gotowych podach są dwa adresy. YARP o tym nie wie. Przy jednym podzie Ready i
drugim `Pending` jest jeden adres. To jest zgodne z numerem.

### 5. Partycje i inbox

Tematy integracyjne mają `partitions` co najmniej 2. Nazwa tematu i nazwa zdarzenia zostają.
Inbox jest włączony w każdej usłudze, która konsumuje. Drugi pod używa tej samej grupy.
Wyłączenie inboxa w zmiennych Deploymentu przy `replicas` co najmniej 1 jest błędem
konfiguracji.

### 6. AppHost

W `JJDevHub.AppHost` nie dodawaj `WithReplicas` z argumentem większym niż 1. Brak wywołania
zostaw. `aspire run` pokazuje jedną kopię projektu. Nie wstawiaj manifestu HPA do katalogu
AppHost.

### Co jest do czego

| Element | Po co istnieje | Kto go woła |
| --- | --- | --- |
| HPA komponentu | Drugi pod albo powrót do jednego | Kontroler HPA |
| metrics-server | Liczba CPU względem requestu | HPA, sygnał pierwszy |
| prometheus-adapter | Żądania w toku jako metryka zewnętrzna | HPA, sygnał drugi |
| Rekord z numeru 11 | Stabilna suma per `service_name` | Adapter |
| Service ClusterIP | Rozkład HTTP na oba pody | YARP |
| Dwie partycje | Praca obu konsumentów | Grupa o nazwie usługi |
| Inbox | Jeden skutek na identyfikator wiadomości | Konsument w obu podach |
| Request 100m, 50m i 256Mi | Mianownik CPU i koszt pamięci drugiego poda | Scheduler i HPA |
| AppHost, replika 1 | Lokalny układ bez HPA | `aspire run` |

HPA News woła Deployment `news`. Gdy `scaleTargetRef` wskazuje `learning`, próg News podnosi
cudzy pod albo nie znajduje celu. Nazwa pliku, nazwa obiektu i nazwa Deploymentu są te same.

metrics-server woła kubelet. Gdy API `metrics.k8s.io` nie odpowiada, sygnał CPU jest
brakujący. Zostaje sygnał HTTP, jeśli adapter żyje, i opis HPA pokazuje brak. Nie zostaje
cicha jedna replika przy CPU, którego nikt nie zmierzył, udająca, że próg jest spokojny, gdy
metryka w ogóle nie przyszła. Opis ma pokazać brak.

Adapter woła Prometheus. Gdy rekord nie ma `service_name`, selektor News jest pusty albo
łapie sumę. Pusta odpowiedź przy żywym ruchu News jest błędem etykiety. Suma wszystkich
usług w polu News jest tym samym błędem.

Service woła kube-proxy. Dwa adresy przy dwóch podach Ready znaczą, że selector obejmuje
oba. Jeden adres przy dwóch podach Ready znaczy, że drugi pod ma inną etykietę. YARP tego
nie poprawi, bo woła nazwę, nie listę podów.

Inbox woła konsument w obu podach. Wyłączony inbox przy dwóch partycjach daje dwa skutki
jednego identyfikatora. Włączony inbox przy jednej partycji nadal daje jeden skutek, ale
drugi pod na szynie stoi. Oba warunki są tego numeru: partycje co najmniej 2 i inbox
włączony.

AppHost nie woła kontrolera HPA. `WithReplicas(2)` na laptopie nie jest sprawdzianem progu
70 procent. Jest drugim procesem bez adaptera.

Kontroler HPA nie woła Kafki. Konsument nie woła HPA. Deploy z numeru 16 nie ustawia replik
na 2.

## Testy

1. Opis HPA ma oba sygnały i sufit 2. Powód padnięcia: któregoś z siedmiu obiektów nie ma,
`maxReplicas` nie jest 2, brakuje CPU 70 albo brakuje metryki
`jjdevhub_http_server_active_requests`.

```bash
kubectl -n jjdevhub get hpa -o yaml
```

Siedem obiektów. Każdy ma `minReplicas: 1`, `maxReplicas: 2`, `averageUtilization: 70`,
`averageValue: "20"`, `stabilizationWindowSeconds` 60 w górę i 300 w dół,
`selectPolicy: Max`. Selektor `service_name` zgadza się z nazwą obiektu. Nie ma HPA o nazwie
`postgres`, `redis`, `cache`, `kafka`, `openbao`, `collector`, `otel-collector`,
`prometheus`, `jaeger`, `grafana`, `cloudflared`, `sonar` ani `sonarqube`. Nie ma HPA
`mobile`.

2. Metryka zewnętrzna jest znana. Powód padnięcia: surowe API zwraca nieznaną metrykę. Pusta
lista przy zerowych replikach aplikacji jest poprawna. Lista, w której seria News nie ma
etykiety `service_name`, jest błędem adaptera i sprawdza się, gdy ruch już jest.

3. Próg HTTP na żywym Deploymentcie, gdy obraz już stoi. Powód padnięcia: przy obciążeniu
samych żądań HTTP pożądane repliki nie dochodzą do 2, choć metryka jest znana i powyżej 20,
albo powstaje trzeci pod. Puść obciążenie narzędziem spoza procesu usługi, na przykład pętlą
`curl` na odczyt publiczny albo na `GET /versions`, aż
`kubectl -n jjdevhub describe hpa news` pokaże pożądane repliki 2. Drugi pod dochodzi do
`Ready` albo zostaje `Pending` z powodem braku zasobów. Oba wyniki są zgodne. Trzeci pod nie
jest. Po zatrzymaniu ruchu, po oknie 300 sekund, zostaje jeden pod. Nie skracaj okna w
teście przez edycję manifestu „żeby szybciej”.

4. CPU. Powód padnięcia: przy progu 70 procent requestu, bez przekroczenia progu HTTP,
pożądane repliki zostają 1, choć `kubectl top` pokazuje wykorzystanie nad progiem. Wystarczy
jeden z dwóch testów progowych na jednym komponencie, News albo brama, oraz zgodność
manifestu pozostałych sześciu. Nie wymagaj sztucznego obciążenia wszystkich usług naraz.
Węzeł jest jeden.

5. Inbox. Powód padnięcia: jeden identyfikator wiadomości daje dwa skutki przy dwóch podach
konsumenta. Opublikuj jedną wiadomość integracyjną o znanym identyfikatorze. W bazie odczytu
albo w skutku ubocznym jest jeden wiersz projekcji albo jeden push. Publikacja tego samego
identyfikatora drugi raz nie dokłada drugiego skutku. Test integracyjny tego zachowania żyje
przy numerze inboxa. Na maszynie powtórka sprawdza, że produkcyjny pod nie ma wyłączonego
inboxa. Wyłączenie przy `replicas` co najmniej 1 jest błędem konfiguracji, widocznym w
zmiennych Deploymentu.

6. Aspire. Powód padnięcia: `WithReplicas` ma argument większy niż 1.

```bash
git grep -n "WithReplicas" -- JJDevHub.AppHost || true
```

Albo brak wywołań, albo każde wywołanie ma argument `1`. `aspire run` zostawia jedną kopię
usługi. Drugi proces lokalny jest błędem, nawet gdy na maszynie HPA jest poprawne.

7. Brak przywiązania ruchu. Powód padnięcia: w Service jest `sessionAffinity: ClientIP`.
Pole jest `None` albo go nie ma. `kubectl -n jjdevhub get endpoints news` przy dwóch podach
Ready pokazuje dwa adresy.

8. `Pending` nie podnosi sufitu. Powód padnięcia: przy podzie `Pending` z braku pamięci ktoś
zmienia `maxReplicas` na więcej niż 2. Manifest po takim incydencie nadal ma 2. Opis poda
podaje powód harmonogramu. Ten opis nie jest łatany trzecią repliką.

9. Partycje. Powód padnięcia: temat integracyjny, który usługa konsumuje, ma jedną partycję.
Liczba partycji jest co najmniej 2. Nazwa tematu jest ta sama co przed tym numerem.

## Zasady

- Skaluje się Deployment komponentu z listy siedmiu: `identity`, `news`, `learning`, `cv`,
  `contact`, `gateway`, `web`. Nic innego.
- `minReplicas` to 1. `maxReplicas` to 2. Trzeci pod jest błędem manifestu.
- Sygnał CPU to `Utilization` 70 procent requestu, ze metrics-server. Sygnał HTTP to
  `jjdevhub_http_server_active_requests` z `AverageValue` `20` i selektorem `service_name`.
- Okno w górę to 60 sekund, okno w dół to 300 sekund, `selectPolicy` to `Max` na obu. Z
  dwóch liczb replik zostaje większa, ucięta do sufitu.
- Brakująca metryka jest widoczna w `kubectl describe hpa`. Nie jest milczącym sukcesem i
  nie jest zerem.
- Adapter czyta rekord `jjdevhub:http_server_active_requests:sum`. Etykieta to
  `service_name`. Trzecia nazwa nie powstaje.
- Oba pody serwują to samo HTTP. Nie ma poda „tylko zapis” ani „tylko odczyt”.
- Service rozkłada ruch. YARP nie wybiera poda. `sessionAffinity` jest `None` albo pola nie
  ma.
- Request CPU to 100m na usługę i na bramę, 50m na web. Pamięć request to 256Mi. Bez
  requestu CPU procent nie ma mianownika.
- Inbox jest włączony. Drugie zastosowanie tego samego identyfikatora wiadomości jest
  błędem.
- Temat integracyjny ma co najmniej dwie partycje. Nazwa tematu i nazwa zdarzenia nie
  zmieniają się w tym numerze.
- Aspire zostaje przy jednej replice. `WithReplicas` albo nie występuje, albo ma argument 1.
- HPA nie wystawia portu i nie zmienia tunelu.
- `Pending` z braku CPU albo pamięci nie jest obchodzone przez podniesienie `maxReplicas`.
- Poświadczenia baz obu podów są osobnymi dzierżawami tej samej roli OpenBao. Ten numer nie
  nadaje wspólnego hasła w zmiennej.
- Pierwsza replika przy deployu to co najmniej 1 i nie jest 2. Drugi pod zostawia próg, nie
  tag.
- `mobile` nie ma Deploymentu i nie ma HPA.

## Poza zakresem

- Maszyna, 4 vCPU, 16 GiB i metrics-server jako składnik k3s są w
  [08-proxmox.md](08-proxmox.md). Ten numer nie dokłada węzła i nie wymienia metrics-server
  na inny.
- Metryka surowa, eksport `:8889` i atrybut `service.version` są w
  [10-opentelemetry.md](10-opentelemetry.md). Ten numer nie zmienia SDK.
- Rekord `jjdevhub:http_server_active_requests:sum` i etykieta `service_name` powstają w
  [11-prometheus.md](11-prometheus.md). Ten numer czyta rekord przez adapter. Nie pisze
  reguły drugi raz.
- Wykres tego samego szeregu jest w [13-grafana.md](13-grafana.md). HPA nie woła Grafany.
  Grafana nie jest progiem.
- Implementacja inboxa i outboxa jest w numerze szyny w `docs/api`. Tu jest warunek
  „włączone przy dwóch podach” i jeden skutek na identyfikator.
- Nazwy tematów i zdarzeń są w numerze Kafki w `docs/api`. Tu jest liczba partycji, co
  najmniej 2, i grupa o nazwie usługi.
- Trasy YARP są w [16-gateway.md](../api/16-gateway.md). Ten numer nie dodaje trasy i nie
  dokleja ciasteczka przywiązania.
- Dzierżawa OpenBao jest w [14-openbao.md](14-openbao.md). Dwa pody dostają dwie dzierżawy
  jednej roli. Ten numer nie skraca TTL.
- Wystawienie obrazu, od którego HPA ma co skalować, i pierwsza replika równa 1 są w
  [16-deploy.md](16-deploy.md). Ten numer nie buduje obrazu i nie ustawia replik na 2 przy
  tagu.
- Stopka weba i ekran telefonu zostają przy numerze komponentu. Drugi pod weba nie dostaje
  innego `web-vX.Y.Z`.
- Postgres, Redis, Kafka, OpenBao, collector, Prometheus, Jaeger, Grafana, `cloudflared` i
  SonarQube zostają bez HPA. Ten numer nie skaluje magazynu.

## Źródła

- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).
  Wiążące są `minReplicas`, `maxReplicas` i liczenie pożądanych replik z metryk. Dotyczy
  siedmiu obiektów, podłogi 1 i sufitu 2, oraz tego, że z dwóch sygnałów zostaje wyższa
  liczba, ucięta do sufitu. Ze źródła nie bierzemy `maxReplicas` powyżej 2 i nie bierzemy
  ręcznego `kubectl scale` jako stałego trybu.
- [Metryki zewnętrzne HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#scaling-on-custom-metrics).
  Wiążące są typ `External`, `AverageValue` i selektor etykiet. Dotyczy
  `jjdevhub_http_server_active_requests`, wartości `20` i `service_name`. Ze źródła nie
  bierzemy metryki obiektowej związanej z innym zasobem niż Deployment usługi i nie bierzemy
  selektora, który łapie sumę wszystkich usług.
- [Metryki zasobów](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#support-for-resource-metrics).
  Wiążące jest `Utilization` jako procent requestu, nie procent węzła. Dotyczy CPU 70 oraz
  requestu 100m albo 50m, bez którego procent nie ma mianownika. Ze źródła nie bierzemy
  progu ustawionego na limicie, którego ten numer nie używa jako sygnału.
- [Zachowanie HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#configurable-scaling-behavior).
  Wiążące są `stabilizationWindowSeconds` i `selectPolicy`. Dotyczy 60 sekund w górę, 300
  sekund w dół i `Max` na obu kierunkach. Ze źródła nie bierzemy okna w dół równego zero,
  które ściąga pod w trakcie żądania, i nie bierzemy polityki, która zostawia mniejszy z
  dwóch sygnałów.
- [API autoscaling/v2](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/).
  Wiążący jest `apiVersion: autoscaling/v2` i kształt `metrics` oraz `behavior`. Dotyczy
  manifestu wzorcowego News i sześciu kopii, które zmieniają tylko nazwę i `service_name`.
  Ze źródła nie bierzemy `autoscaling/v1`, które nie niesie metryki zewnętrznej w tym
  kształcie.
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server). Wiążące jest API
  `metrics.k8s.io`, z którego HPA bierze CPU i z którego korzysta `kubectl top`. Dotyczy
  sygnału 70 procent. Ze źródła nie bierzemy drugiej instalacji metrics-server obok tej z
  k3s i nie bierzemy zastąpienia go scrape Prometheusa dla progu CPU.
- [Potok metryk zasobów](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/).
  Wiążące jest rozdzielenie metryk zasobów kubeleta od metryk, które aplikacja sama
  eksportuje. Dotyczy decyzji, że CPU idzie z metrics-server, a żądania w toku z
  Prometheusa. Ze źródła nie bierzemy jednego progu sklejonego z obu źródeł tej samej
  liczby.
- [prometheus-adapter](https://github.com/kubernetes-sigs/prometheus-adapter). Wiążące jest
  wystawienie serii Prometheusa jako metryki zewnętrznej API. Dotyczy jednej repliki
  adaptera, ClusterIP i braku HPA na samym adapterze. Ze źródła nie bierzemy adaptera jako
  drugiego Prometheusa i nie bierzemy skalowania Grafany, Jaegera ani collectora.
- [Konfiguracja adaptera](https://github.com/kubernetes-sigs/prometheus-adapter/blob/master/docs/config.md).
  Wiążące są `externalRules`, `seriesQuery`, `metricsQuery` i nazwa wystawiana do API.
  Dotyczy rekordu `jjdevhub:http_server_active_requests:sum` oraz nazwy
  `jjdevhub_http_server_active_requests` z zachowaną etykietą `service_name`. Ze źródła nie
  bierzemy reguły, która sumuje rekord bez tej etykiety.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążące jest wiele adresów za jednym ClusterIP i `sessionAffinity`. Dotyczy jednego
  Service na komponent, dwóch endpointów przy dwóch podach Ready i wartości `None`. Ze
  źródła nie bierzemy `ClientIP` i nie bierzemy drugiego Service dla drugiej repliki.
- [Żądania zasobów](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits).
  Wiążące jest `requests.cpu` jako mianownik wykorzystania i `requests.memory` jako koszt,
  który scheduler widzi przed położeniem poda. Dotyczy 100m na usługę i bramę, 50m na web i
  256Mi pamięci. Ze źródła nie bierzemy poda bez requestu, zaplanowanego „za darmo”.
- [Faza poda](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#pod-phase).
  Wiążące jest `Pending` jako stan, w którym pod nie dostał zasobów, a nie jako stan, który
  sam zwiększa liczbę replik. Dotyczy zakazu podnoszenia `maxReplicas`, gdy drugi pod nie
  staje z braku RAM. Ze źródła nie bierzemy traktowania `Pending` jako sukcesu progu ani
  jako powodu trzeciej repliki.
- [Reguły rejestrujące](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/).
  Wiążąca jest stabilna nazwa rekordu, którego adapter nie przepisuje na surową metrykę SDK.
  Dotyczy `jjdevhub:http_server_active_requests:sum` i etykiety `service_name` wystawionej w
  numerze 11. Ze źródła nie bierzemy trzeciej nazwy rekordu w tym numerze.
- [Konsumenci Kafki](https://kafka.apache.org/documentation/#intro_consumers). Wiążące są
  grupa konsumentów i to, że partycja w grupie ma jednego czytelnika naraz. Dotyczy grupy
  nazwanej jak usługa i co najmniej dwóch partycji, żeby drugi pod nie stał bezczynnie na
  szynie. Ze źródła nie bierzemy osobnej grupy na drugi pod. Osobna grupa czyta ten sam
  temat drugi raz i dubluje skutek, zanim inbox w ogóle zobaczy kolizję.
- [Konfiguracja tematu](https://kafka.apache.org/documentation/#topicconfigs). Wiążące jest
  `partitions` jako właściwość tematu, nie jako sufiks nazwy. Dotyczy liczby co najmniej 2
  przy niezmienionej nazwie, na przykład `segment.fakt.v1`. Ze źródła nie bierzemy nowego
  tematu na replikę.
- [Konfiguracja konsumenta](https://kafka.apache.org/documentation/#consumerconfigs).
  Wiążące są ustawienia klienta, które nie składają skutku i offsetu w jedną transakcję z
  bazą. Dotyczy odrzucenia trybu „co najwyżej raz” opartego tylko na commicie offsetu. Ze
  źródła nie bierzemy wyłączenia konsumenta na drugim podzie jako jedynej ochrony przed
  dublem.
- [Semantyka dostawy](https://kafka.apache.org/documentation/#semantics). Wiążące jest
  dostarczenie co najmniej raz przy ponowieniu i rebalansie. Dotyczy wymogu inboxa: jeden
  identyfikator, jeden skutek, także gdy drugi pod dostanie tę samą wiadomość. Ze źródła nie
  bierzemy założenia, że idempotencja producenta zamyka okno konsumenta.
- [`WithReplicas`](https://learn.microsoft.com/dotnet/api/aspire.hosting.resourcebuilderextensions.withreplicas).
  Wiążący jest argument liczby replik projektu w AppHost. Dotyczy braku wywołania albo
  argumentu `1`. Ze źródła nie bierzemy argumentu 2 na laptopie i nie bierzemy HPA w
  składzie Aspire. Dashboard laptopa nie jest progiem maszyny.

## Gotowe gdy

- W git jest siedem manifestów HPA i manifest adaptera. Każdy HPA ma CPU 70 procent, metrykę
  `jjdevhub_http_server_active_requests` z `AverageValue` `20`, selektor `service_name`,
  `minReplicas` 1, `maxReplicas` 2, okno 60 w górę, okno 300 w dół i `selectPolicy: Max`.
- `kubectl -n jjdevhub describe hpa news` pokazuje oba cele. To samo dla `identity`,
  `learning`, `cv`, `contact`, `gateway` i `web`.
- Surowe API metryki zewnętrznej nie zwraca błędu nieznanej metryki. Adapter czyta rekord
  `jjdevhub:http_server_active_requests:sum`.
- Nie ma HPA Postgresa, Redisa, Kafki, OpenBao, collectora, Prometheusa, Jaegera, Grafany,
  `cloudflared` ani SonarQube. `mobile` nie ma Deploymentu.
- Request CPU to 100m na usługę i bramę, 50m na web. Pamięć request to 256Mi.
  `sessionAffinity` nie jest `ClientIP`.
- `WithReplicas` w AppHost albo nie występuje, albo ma argument 1. `aspire run` zostawia
  jedną kopię usługi.
- Przy dwóch podach jeden identyfikator wiadomości daje jeden skutek. Temat integracyjny ma
  co najmniej dwie partycje, a nazwa tematu się nie zmienia.
- `kubectl -n jjdevhub get endpoints news` przy dwóch podach Ready pokazuje dwa adresy.
- Trzeci pod nie powstaje. `Pending` z braku pamięci nie podnosi `maxReplicas`.
- Deploy nie ustawia replik na 2. Drugi pod zostaje decyzją progu.
