# 09. Cloudflare

[Spis CI/CD](README.md) · poprzedni: [08. Proxmox](08-proxmox.md) · następny: [10. OpenTelemetry](10-opentelemetry.md)

Ten numer daje maszynie z [08-proxmox.md](08-proxmox.md) nazwę w DNS i jedną ścieżkę HTTPS
do Service `gateway`. Poprzedni plik stawia gościa k3s w LAN. Następny,
[10-opentelemetry.md](10-opentelemetry.md), stawia kolektor OTLP wewnątrz tego samego
namespace. W kolejności plików następny jest collector. W kolejności pracy
następny jest [Aspire](../api/01-aspire.md): collector czeka na `ServiceDefaults`.
Bramki gita i tagi komponentów są już wymagane w [07-wersje.md](07-wersje.md). Ten
plik nie wdraża obrazu aplikacji, nie pisze
reguł YARP i nie otwiera bazy.

Scenariusz, który bez tej ścieżki się rozpada, zaczyna się poza LAN. Rekruter albo czytelnik
CV otwiera zwykły adres strony. W dokumencie ten adres jest wzorem `hub.example.com`.
Operator podstawia własną strefę w panelu i nie kopiuje wzoru jako rekordu. Przeglądarka
rozmawia z anycastem Cloudflare. Gość nie ma publicznego IP i nie przyjmuje połączeń na 80
ani na 443 z internetu. W namespace `jjdevhub` stoi Deployment `cloudflared`, jedna replika.
Proces wychodzi z klastra na port 7844: UDP, gdy protokół to QUIC, albo TCP, gdy protokół to
HTTP/2. Cloudflare kończy TLS klienta i oddaje HTTP do jedynego originu aplikacji,
`http://gateway.jjdevhub.svc.cluster.local:8080`.

YARP, czyli `JJDevHub.Gateway`, jest jedyną bramą HTTP aplikacji. Tunel nie stawia drugiej
bramy przed nim i nie omija go w stronę Identity, News, Learning, Cv, Contact ani weba.
Kubernetes Service `gateway` rozkłada żądania na pody bramy. Ten podział Service’ów jest już
w numerze 08. Tu dochodzi nazwa publiczna, konektor i zasada, że panele obserwowalności,
jeśli w ogóle wyjdą na zewnątrz, idą osobno i za Cloudflare Access.

Drugi scenariusz jest negatywny i ma zostać czerwony. Ktoś przekierowuje na routerze 80 i
443 na gościa, żeby „strona działała bez Cloudflare”. Wejście zamknięte w numerze 08 staje
się wtedy wejściem publicznym. Ten numer tego przekierowania nie dodaje. Trzeci scenariusz
jest cichszy: firewall gościa puszcza na wyjściu tylko 443. Konektor i tak potrzebuje 7844.
Panel tunelu zostaje w dół, nazwa publiczna nie dochodzi do YARP, a `nc` na 443 gościa z
zewnątrz nadal nie łączy. Wyjście 443 nie zastępuje reguły 7844/UDP i 7844/TCP.

Czwarty scenariusz dotyczy operatora, nie czytelnika. Z LAN wolno mu zrobić
`kubectl port-forward` na Service w `jjdevhub`. Z sieci komórkowej nie ma `psql` na
produkcyjny Postgres, nie ma klienta Redisa, nie ma producenta Kafki, nie ma wołania
OpenBao, nie ma eksportera OTLP i nie ma `kubectl` przeciw API k3s przez publiczną nazwę.
Porty 5432, 6379, 9092, 8200, 4317 i 6443 nie dostają public hostname. To jest cel tego
numeru, nie luka do załatania tymczasowym rekordem.

## Po co

Strona ma zwykły adres HTTPS. Gość z numeru 08 stoi w LAN, bez publicznego IP, i nie
przyjmuje 80 ani 443 z internetu. Czytelnik CV i rekruter mają otworzyć URL. Nie mają
wchodzić do sieci operatora i nie mają znać adresu maszyny. `cloudflared` wychodzi z klastra
do Cloudflare. Odcinek przeglądarka–Cloudflare jest TLS. Odcinek Cloudflare–konektor jest
szyfrowanym tunelem. Odcinek konektor–YARP zostaje HTTP wewnątrz namespace, bo origin nie
słucha publicznie.

Jedna nazwa aplikacji kończy się na Service `gateway` i na porcie 8080. Ścieżki `/`, `/api`
i `GET /versions` rozstrzyga YARP opisany w [16-gateway.md](../api/16-gateway.md). Ten numer
nie duplikuje tabeli tras i nie dokłada nagłówka, który zmienia znaczenie żądania. JWT,
limity i kontrakt wersji zostają w bramie. Publiczny hostname na `identity`, `news`,
`learning`, `cv`, `contact` albo `web` obchodziłby tę bramę. Lista public hostname aplikacji
ma jedną pozycję.

Panele mają osobny powód, żeby w ogóle istnieć w tym pliku, choć ich procesy dochodzą
później. Grafana, Jaeger i Prometheus nie mają logowania aplikacji. Puszczenie ich UI przez
YARP wstawiłoby metryki i drzewa śladów w stronę, którą czyta rekruter, i obciążyłoby bramę
ruchem operatora. Jeśli hostname paneli powstaje, origin każdego z nich jest własnym
ClusterIP, a Cloudflare Access wpuszcza tylko konto operatora. Do czasu numerów 11–13 tych
rekordów się nie tworzy, żeby nie wskazywały pustego originu.

Bez tego numeru tag z numeru 07 ma maszynę i nie ma nazwy, pod którą da się sprawdzić
`GET /versions` spoza LAN. Laptop zostaje przy `aspire run`. Produkcja strony nie idzie
przez dashboard Aspire i nie idzie przez adres gościa. Konektor jest jedynym procesem tego
numeru, który rozmawia z siecią Cloudflare. Reszta podów zostaje przy ClusterIP.

Koszt, który numer przyjmuje, jest operacyjny. Domena jest strefą na koncie Cloudflare.
Nameservery u rejestratora wskazują na Cloudflare. Token konektora żyje w Secretcie na
maszynie, nie w git. Odtworzenie trasy public hostname wymaga panelu, nie samego klonu.
Darmowy plan strefy wystarcza do tego układu. Plan, na którym tunel jest dostępny, jest
warunkiem konta, nie powodem, żeby otwierać port originu.

## Dlaczego ta technologia

### Tunel zamiast adresu publicznego

Cloudflare Tunnel (`cloudflared`) zestawia wyjście z klastra do sieci Cloudflare. Port
docelowy to 7844. Przy QUIC jest to UDP. Przy HTTP/2 jest to TCP. Oba warianty mają być
dozwolone na wyjściu gościa, bo konektor wybiera protokół, a zablokowanie jednego z nich
zostawia tunel zależny od tego, co firewall akurat puszcza. Rekord DNS jest proxied i
wskazuje tunel. Przeglądarka nie łączy się z adresem routera. Origin nie słucha na adresie
gościa.

Przekierowanie 80 i 443 na routerze odpada. Wystawia gościa wprost i psuje zasadę
zamkniętego wejścia z numeru 08. Stały VPN jako jedyna droga do strony odpada, bo czytelnik
CV i rekruter mają otworzyć zwykły URL, a nie sieć operatora. Samo wyjście na 443 odpada
jako zamiennik tunelu: konektor nie zestawia się na porcie strony. Opublikowanie gościa
przez Service typu LoadBalancer albo NodePort odpada z tego samego powodu co przekierowanie
na routerze. Adres LAN albo adres domu stałby się originem.

Konkret JJDevHub jest tu sieciowy, nie domenowy. Artykuł, lekcja i strona CV jeszcze nie są
treścią tego pliku. Jest nią to, że żądanie HTTPS o te rzeczy, gdy już istnieją, wchodzi
jedną drogą. Gdy brama ma nadal zero replik, testem tego numeru jest połączenie konektora i
brak nasłuchu na gościu. `curl` strony, który naprawdę dostaje treść wersji, dochodzi w
[16-deploy.md](16-deploy.md). Odpowiedź 503 przy stojącej bramie i pustych replikach usług i
tak pokazuje, że originem jest `gateway`, a nie cisza na adresie gościa.

Koszt zostaje przy koncie i przy tokenie. Strefa jest na Cloudflare. Konektor trzyma token,
którego nie ma w git, w issue ani w logu workflow. Utrata tokenu wymaga nowego tokenu z
panelu i podmiany Secretu na maszynie. Klon repozytorium sam tunelu nie wznawia. Historia
powłoki na gościu, w której operator wkleił token do `kubectl create secret`, ma być z tej
linii wyczyszczona.

### Jeden origin: Service `gateway`

Publiczny hostname aplikacji ma origin `http://gateway.jjdevhub.svc.cluster.local:8080`. To
ClusterIP YARP. YARP sam routuje do `identity`, `news`, `learning`, `cv`, `contact` i `web`
po nazwach Service z numeru 08. Pole URL w panelu nie dostaje schematu w osobnej kolumnie
tego dokumentu: typ to HTTP, a URL to `gateway.jjdevhub.svc.cluster.local:8080`. Ścieżka w
panelu zostaje pusta. Tunel nie dokleja ścieżek sam.

Ingress, Gateway API i drugi reverse proxy przed YARP odpadają. Traefik jest wyłączony od
instalacji k3s (`--disable=traefik` razem z `--disable=servicelb` w numerze 08) i ten numer
go nie włącza. ServiceLB zostaje nieobecny. Osobny hostname na każdą usługę odpada, bo JWT,
limity i `GET /versions` są w bramie. Czytelnik, który trafiłby na `news` z pominięciem
bramy, dostałby inny kontrakt niż nazwa strony. Web jako osobny origin publiczny odpada z
tej samej przyczyny: strona jest za YARP, nie obok niego.

Scenariusz pomyłki jest konkretny. W panelu powstaje drugi public hostname, typ HTTP, URL
`news.jjdevhub.svc.cluster.local:8080`. DNS proxied działa, tunel jest Healthy, a żądanie
nigdy nie widzi reguł bramy. Test tego numeru ogląda listę public hostname i wymaga jednej
pozycji aplikacji. Co najwyżej trzy dalsze pozycje to panele, i tylko za Access. Pozycja
`news` jest błędem tego numeru, nie „skrótem na czas debugowania”.

Koszt jest po stronie bramy. Każda ścieżka HTTP aplikacji musi mieć regułę w YARP. Brak
reguły daje odpowiedź bramy, nie odpowiedź tunelu. Tunel o kształcie trasy nie wie. Nie wie
też, ile podów stoi za Service. Gdy numer 15 podniesie drugi pod, rozkład połączeń zostaje
przy Service Kubernetes. Konektor nadal widzi jeden origin.

### DNS w Cloudflare, rekord proxied

Strefa DNS żyje na koncie Cloudflare. U rejestratora nameservery wskazują na Cloudflare.
Dopóki delegacja nie dojdzie, nazwa nie jest jeszcze nazwą tego numeru i zielony `curl`
sprzed przełączenia nic nie mówi o tunelu. Panel tunelu, przy zapisie public hostname,
tworzy rekord CNAME na `<tunel>.cfargotunnel.com` z proxy włączonym. Drugi rekord A na adres
domowy albo na adres LAN nie powstaje. Wzór `hub.example.com` zostaje w dokumencie po to,
żeby było wiadomo, który człon jest etykietą strony, a który człon operator podstawia. Wzór
nie jest rekordem do skopiowania bez zmiany.

Tryb SSL strefy to Full. Przeglądarka–Cloudflare i Cloudflare–konektor są szyfrowane.
Odcinek konektor–YARP zostaje HTTP wewnątrz namespace. Authenticated Origin Pulls nie są
wymagane, bo origin nie słucha publicznie i nie ma certyfikatu klienta do wyegzekwowania na
adresie routera. Certyfikat na gościu, własny nginx i Let’s Encrypt odpadają razem z
otwartym portem 443. Tryb Flexible odpada, bo myli diagnostykę: kłódka w przeglądarce
wygląda tak samo, a operator zaczyna szukać TLS na ClusterIP, którego ten układ świadomie
nie ma.

Scenariusz rekordu A wygląda niewinnie. Obok CNAME ktoś dodaje A na adres domu, „na wszelki
wypadek, gdy tunel padnie”. Przy wyłączonym proxy część resolverów idzie na gościa, dostaje
odmowę i operator wnioskuje, że padł konektor. Przy włączonym proxy powstaje drugi byt obok
tunelu. Ten numer nie ma ścieżki zapasowej przez adres domu. Padnięty konektor ma być
widoczny jako tunel w dół w panelu i jako brak Healthy na Deploymentcie, nie jako ciche
zejście na LAN.

Koszt to zmiana nameserverów i jeden panel, w którym rekord CNAME jest proxied. Rekord w
pliku strefy w git odpada: strefa jest remotely managed razem z tunelem, a plik w klonie
rozjechałby się z panelem przy pierwszej zmianie etykiety. Operator czyta stan w panelu DNS
i w `dig` na nazwę strony. Odpowiedź ma wskazywać Cloudflare, nie adres gościa.

### `cloudflared` jako Deployment

Konektor jest Deploymentem w namespace `jjdevhub`. `replicas` to 1. To pole nie podlega HPA
z numeru 15 i ten numer nie tworzy obiektu HorizontalPodAutoscaler o nazwie `cloudflared`.
Skasowanie poda powoduje, że Deployment wstaje z powrotem jako jedna replika, nie jako dwie.
Origin resolver widzi DNS klastra, więc nazwa `gateway.jjdevhub.svc.cluster.local` działa
bez `hostNetwork`. Proces nie potrzebuje adresu węzła.

Argumenty kontenera to `tunnel`, `--no-autoupdate`, `run`. Token bierze ze zmiennej
`TUNNEL_TOKEN` podstawionej z Secretu `cloudflared-token`, klucz `token`. Automatyczna
podmiana binarki w kontenerze odpada: obraz jest przypięty do digestu, tak jak obrazy
aplikacji w numerze 16. Przy pierwszym wdrożeniu digest wpisuje operator po
`docker buildx imagetools inspect` albo równoważnym odczycie z rejestru. W git zostaje
digest, bez tokenu. Tag pływający jako jedyna referencja obrazu odpada, bo da się go
przepiąć bez zmiany manifestu.

Jednostka systemd na hoście, wskazująca `127.0.0.1` i NodePort, odpada. NodePort byłby
publicznym portem originu na adresie gościa, a ten numer go nie otwiera. Konfiguracja tunelu
w pliku w git odpada, bo token i lista hostname’ów z sekretem nie mogą leżeć obok kodu.
Trasy hostname’ów zostają w panelu Zero Trust. Tryb tunelu to remotely managed: kreator
nazywa tunel `jjdevhub`, a klon nie jest źródłem listy originów. W git jest manifest
Deploymentu i `secret.example.yaml` z pustym polem. `kubectl apply` tego przykładu nie
tworzy działającego konektora.

Przewodnik wdrożenia na Kubernetes pokazuje przykładowy Secret z wklejonym tokenem, inną
nazwę Secretu, port metryk procesu i więcej niż jedną replikę. Ten numer bierze z niego
kształt Deploymentu, argument `--no-autoupdate` i token ze Secretu. Nie bierze pliku z
wartością tokenu, nie bierze nasłuchu metryk konektora jako portu do publikacji i nie bierze
drugiej repliki. Przewodnik dostępności tunelu opisuje dokładanie replik konektora. Tu
zostaje jedna. Drugi proces z tym samym tokenem nie jest skalowaniem strony.

Koszt jest przy panelu i przy jednym podzie. Odtworzenie trasy wymaga panelu, nie samego
klonu. Awaria jedynej repliki jest oknem, w którym nazwa publiczna nie dochodzi do YARP, aż
Deployment podniesie pod z powrotem. To okno nie leczy się HPA. Nie leczy się też rekordem
A. Log konektora ma pokazać zestawione połączenie i nie ma pokazać wartości tokenu. Jeśli ją
pokazuje, manifest ma czytać token tak, żeby zrzut procesu jej nie drukował, i test logu
powtarza się po poprawce.

### Panele obserwowalności osobno, za Access

Grafana, Jaeger i Prometheus dostają własne hostname’y w tym samym tunelu, gdy numery 13, 12
i 11 postawią ich Service. Origin Grafany to
`http://grafana.jjdevhub.svc.cluster.local:3000`. Origin Jaegera to
`http://jaeger.jjdevhub.svc.cluster.local:16686`. Origin Prometheusa to
`http://prometheus.jjdevhub.svc.cluster.local:9090`. Żaden z tych trzech URL nie jest
originem YARP. Cloudflare Access na tych trzech nazwach wpuszcza tylko konto operatora:
aplikacja Access typu self-hosted, polityka Allow ograniczona do tego konta.

Puszczenie paneli bez Access odpada. Prometheus i Jaeger nie mają logowania aplikacji, a
Grafana na tym etapie nie jest drzwiami czytelnika. Przepuszczenie ich przez YARP jako część
strony CV odpada: czytelnik nie ma powodu widzieć metryk ani drzewa żądania, a brama
zostałaby obciążona ruchem operatora. Brak tych hostname’ów w ogóle jest dopuszczalny do
czasu numerów 11–13. Ten numer rezerwuje zasadę, a nie tworzy rekordów na zapas. Rekord,
który wskazuje Service jeszcze nieistniejący, jest pustym originem i miesza próbę `curl`.

Strona CV Accessu nie dostaje. Logowanie czytelnika jest JWT Identity, za bramą, nie
polityką Cloudflare na nazwie strony. Operator, który włączy Access na `hub` „dla spokoju”,
zamyka rekrutera na stronie logowania Cloudflare. To jest błąd tego numeru. Access jest
drugimi drzwiami, obok JWT, i dotyczy paneli.

Gdy hostname paneli już jest, Grafana dostaje `GF_SERVER_ROOT_URL` równy swojemu `https://`,
a Prometheus dostaje `--web.external-url` równy swojemu `https://`. Ustawienie jest w
numerach 13 i 11. Tu jest warunek: bez niego panel za tunelem ładuje HTML i gubi zasoby.
Jaeger dostaje `QUERY_BASE_PATH=/`, bo hostname jest na korzeniu nazwy, nie na podścieżce
strony. Szczegół magazynu śladów jest w numerze 12. Ten plik tylko zabrania trasy `/jaeger`
w YARP.

Koszt to trzy rekordy DNS i jedna polityka Access, gdy panele w ogóle powstają. Z telefonu
spoza konta operatora UI Prometheusa, Jaegera i Grafany nie jest celem. Żądanie bez
tożsamości Access dostaje stronę logowania Cloudflare albo przekierowanie, nie `200` z
tytułem Grafany. Z LAN zostaje `kubectl port-forward`, opisany przy numerach paneli, i on
Accessu nie zastępuje jako sposób na publiczną nazwę.

### Zamknięty zestaw portów

Tunelem wychodzi wyłącznie HTTP do bramy aplikacji oraz, za Access, HTTP do trzech paneli.
Nie wychodzi Postgres `5432`, Redis `6379`, Kafka `9092`, OpenBao `8200`, OTLP `4317` ani
API k3s `6443`. Nie wychodzi też port 8080 usług domenowych jako osobna nazwa. Public
hostname nie jest skrótem do diagnostyki bazy.

Publikacja tych portów „tymczasowo, do diagnostyki” odpada. Diagnostyka z LAN używa
`kubectl port-forward` na maszynie operatora, na ClusterIP, na czas jednej komendy.
Scenariusz z kawiarni: migracja schematu „tylko na chwilę” przez publiczną nazwę na 5432
wystawia bazę poza LAN. Ten numer nie ma takiej nazwy. Operator odpala port-forward z sieci,
która już widzi API k3s, albo pracuje na gościu. Po komendzie forward znika. Rekord DNS nie
zostaje.

Port 4317 jest w tym zestawie celowo, choć numer 10 dopiero stawia kolektor. Tunel z tego
numeru nie dostaje hostname’u OTLP. Eksporter usług ma zostać wewnątrz namespace. Publiczny
OTLP byłby drugim wejściem do telemetrii, obok paneli, i bez Accessu na ścieżce, której ten
plik nie projektuje. To samo dotyczy 6443: API klastra nie jest stroną CV.

Koszt jest świadomy. Z sieci komórkowej nie ma `psql` na produkcyjną bazę, nie ma
`redis-cli` i nie ma konsumenta Kafki. Operator, który potrzebuje tych narzędzi, jest albo w
LAN, albo na gościu. Czytelnik strony tego kosztu nie widzi. Widzi HTTPS na nazwie strefy.

### Obraz po digescie i jedna replika

Obraz `cloudflare/cloudflared` w manifeście jest referencją po digescie. Przy pierwszym
wdrożeniu operator odczytuje digest z rejestru i wpisuje go do gita. Kolejna podmiana
konektora jest zmianą digestu w manifeście, nie przepięciem tagu pod tym samym plikiem.
Token w tym commicie nie jedzie. Przykład Secretu zostaje pusty także po zmianie digestu.

Jedna replika jest decyzją tego numeru, nie tymczasowym stanem „zanim włączymy HPA”. Numer
15 trzyma HPA przy usługach HTTP aplikacji. `cloudflared` jest na liście rzeczy, których HPA
nie podnosi. CPU konektora nie jest progiem skalowania strony. Drugi pod konektora nie
zwiększa liczby podów YARP i nie zmienia originu.

Scenariusz skali wygląda tak. Ruch strony rośnie, HPA usług dochodzi do dwóch replik, a ktoś
dopisuje konektor do tego samego obiektu, bo „też jest Deploymentem”. Drugi proces tunelu
nie jest drugim podem bramy. Origin w panelu nadal jest jeden. Ten numer nie ma manifestu
HPA dla `cloudflared` i nie podnosi `replicas` powyżej 1. Skalowanie bramy jest w numerze 15
i kończy się na Service `gateway`, nie na konektorze.

Koszt jednej repliki jest oknem niedostępności nazwy na czas restartu poda. Okno widać w
`kubectl -n jjdevhub rollout status deploy/cloudflared` i w stanie tunelu w panelu. Nie
widać go jako otwartego 443 na gościu. Przywrócenie konektora nie wymaga rekordu A i nie
wymaga drugiej strefy.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/cloudflared/deployment.yaml` | Deployment `cloudflared` w `jjdevhub`, jedna replika, obraz po digescie |
| `deploy/k3s/cloudflared/secret.example.yaml` | Kształt Secretu bez wartości tokenu; sam Secret powstaje na maszynie |

Secret na maszynie nazywa się `cloudflared-token`, klucz `token`. Manifest przykładowy w git
ma puste pole i komentarz, że `kubectl apply` tego przykładu nie tworzy działającego
konektora. Plik przykładowy wolno commitować. Pliku z wartością wolno nie commitować.
Wartość nie wchodzi też do `deployment.yaml` jako literał.

| Hostname | Origin | Kto może wejść |
| --- | --- | --- |
| nazwa strony, np. `hub.example.com` | `http://gateway.jjdevhub.svc.cluster.local:8080` | każdy; autoryzacja jest JWT aplikacji |
| `grafana.<strefa>` | `http://grafana.jjdevhub.svc.cluster.local:3000` | Cloudflare Access, konto operatora |
| `jaeger.<strefa>` | `http://jaeger.jjdevhub.svc.cluster.local:16686` | Cloudflare Access, konto operatora |
| `prometheus.<strefa>` | `http://prometheus.jjdevhub.svc.cluster.local:9090` | Cloudflare Access, konto operatora |

Nazwę strefy operator podstawia w panelu. W dokumencie zostaje `hub.example.com` jako wzór,
nie jako rekord, który trzeba skopiować bez zmiany. Nazwy `grafana.<strefa>`,
`jaeger.<strefa>` i `prometheus.<strefa>` powstają dopiero razem z Service’ami. Do tego
czasu tabela jest umową, nie listą rekordów do założenia dziś.

Deployment nie dostaje `hostNetwork`, nie dostaje Service typu NodePort i nie dostaje
Service typu LoadBalancer. Nie ma obiektu Ingress. Port 7844 jest wyjściem gościa, nie
portem Service w manifeście aplikacji. Port 8080 w tej tabeli jest portem Service `gateway`,
nie portem opublikowanym na adresie węzła.

## Plan

### 1. Strefa

Domena jest strefą na koncie Cloudflare. Nameservery u rejestratora wskazują na Cloudflare.
W ustawieniach SSL/TLS strefy wybierz Full. Authenticated Origin Pulls zostaw wyłączone. Nie
dodawaj rekordu A na adres gościa ani na adres domu. Rekord nazwy strony powstanie przy
public hostname, jako CNAME proxied, nie w tym kroku jako plik strefy w git.

Zanim delegacja nameserverów dojdzie, nie traktuj `curl` na wzór `hub.example.com` jako
próby tunelu. Wzór i tak nie jest rekordem. Próbą jest nazwa, którą operator wpisał w
panelu, po tym jak resolver widzi serwery Cloudflare.

### 2. Tunel

W Zero Trust: Networks → Tunnels → Create. Typ Cloudflared. Nazwa `jjdevhub`. Tryb remotely
managed. Token z kreatora wklej tylko do Secretu na maszynie.

```bash
kubectl -n jjdevhub create secret generic cloudflared-token \
  --from-literal=token='TOKEN_Z_PANELU'
```

Polecenie wykonuje operator na gościu. Token nie trafia do issue, do logu workflow ani do
pliku śledzonego przez git. Po utworzeniu Secretu historia powłoki na maszynie ma być
wyczyszczona z tej linii. `secret.example.yaml` zostaje z pustym `token`. Tego przykładu nie
stosuj jako działającego Secretu.

Sprawdź, że obiekt istnieje, a wartość nie weszła do drzewa gita:

```bash
kubectl -n jjdevhub get secret cloudflared-token
git grep -n "eyJ" -- deploy/k3s/cloudflared || true
```

Pierwsze polecenie ma pokazać Secret. Drugie nie ma znaleźć tokenu tunelu w katalogu
manifestów. Samo słowo `cloudflared-token` w przykładzie bez wartości jest dozwolone.
Wartość w tym katalogu nie jest.

### 3. Deployment konektora

`deploy/k3s/cloudflared/deployment.yaml` uruchamia obraz `cloudflare/cloudflared` przypięty
do digestu. Argumenty: `tunnel`, `--no-autoupdate`, `run`. Token wchodzi jako `TUNNEL_TOKEN`
z Secretu `cloudflared-token`, klucz `token`. `replicas` to 1. W katalogu nie ma
HorizontalPodAutoscaler dla tego Deploymentu.

Kształt, który ląduje w git (digest jest tym, który zwrócił odczyt rejestru, nie etykietą
tagu):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: jjdevhub
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared@sha256:<digest>
          args:
            - tunnel
            - --no-autoupdate
            - run
          env:
            - name: TUNNEL_TOKEN
              valueFrom:
                secretKeyRef:
                  name: cloudflared-token
                  key: token
```

Digest wpisz po odczycie z rejestru, zanim manifest jest tym, który stosujesz:

```bash
docker buildx imagetools inspect cloudflare/cloudflared:latest
```

Polecenie czyta digest. Deployment nie zostaje na tagu `latest`. W git commituje się
referencję `cloudflare/cloudflared@sha256:…`. Zastosuj manifest po Secretcie. Gdy Secretu
nie ma, pod nie wstaje i panel nie pokaże Healthy. Gdy digest jest zły, pod zostaje przy
błędzie pobrania obrazu. Popraw digest. Nie obchodź tego tagiem.

```bash
kubectl -n jjdevhub apply -f deploy/k3s/cloudflared/deployment.yaml
kubectl -n jjdevhub rollout status deploy/cloudflared
```

W panelu stan tunelu ma być Healthy. W logu jest zestawione połączenie. W logu nie ma
wartości tokenu.

### 4. Hostname aplikacji

W tym samym tunelu dodaj public hostname.

| Pole | Wartość |
| --- | --- |
| Subdomain | `hub` albo inna etykieta strony |
| Domain | strefa z kroku 1 |
| Path | pusty |
| Type | HTTP |
| URL | `gateway.jjdevhub.svc.cluster.local:8080` |

Zapisz. Panel dopisuje rekord CNAME z proxy. Nie dodawaj rekordu A. Nie dodawaj drugiego
public hostname na `identity`, `news`, `learning`, `cv`, `contact` ani `web`. Nie zmieniaj
typu na HTTPS w stronę ClusterIP. Origin aplikacji w tym numerze jest HTTP wewnątrz
namespace.

Ścieżki `/`, `/api` i `GET /versions` zostaw bramie. Ten krok nie wgrywa konfiguracji YARP i
nie dopisuje nagłówka. Gdy brama ma zero replik, konektor i tak może być Healthy. Treść
wersji nie jest warunkiem zamknięcia tego kroku.

### 5. Hostname’y paneli

Gdy Service `grafana`, `jaeger` i `prometheus` istnieją, dodaj trzy public hostname z tabeli
w sekcji ścieżek. Od razu włącz Cloudflare Access: aplikacja self-hosted, polityka Allow
wyłącznie dla konta operatora. Do tego czasu tych rekordów nie twórz.

Warunek adresu panelu, ustawiany w numerach 13 i 11, a nie w tym manifeście konektora:
Grafana ma `GF_SERVER_ROOT_URL` równy swojemu `https://`, Prometheus ma `--web.external-url`
równy swojemu `https://`. Bez tego panel ładuje HTML i gubi zasoby. Trasy tych trzech nazw
nie wchodzą do YARP.

### 6. Wejście gościa zostaje zamknięte

Po Health tunelu powtórz próbę z numeru 08. Z sieci spoza LAN porty 80 i 443 na adresie
gościa nie łączą. Strona odpowiada wyłącznie przez nazwę w Cloudflare. Wyjście gościa na
7844/UDP i 7844/TCP jest dozwolone. Samo 443 na wyjściu nie zastępuje tej reguły.

```bash
nc -vz <adres-gościa> 443
nc -vz <adres-gościa> 80
```

Oba polecenia, odpalone spoza LAN, kończą się odmową albo brakiem trasy. `curl` na nazwę
strony przy tym wyniku nadal idzie przez Cloudflare. Jeśli `nc` łączy, wejście z numeru 08
jest otwarte i ten numer nie jest domknięty, nawet gdy tunel jest Healthy.

### Co jest do czego

Strefa DNS jest wołana przez resolver przeglądarki. Daje nazwę publiczną i serwery
Cloudflare. Gdy jej nie ma, wzór `hub.example.com` nie jest adresem maszyny, a prawdziwa
nazwa operatora nie schodzi na tunel. Rekord A dopisany obok nie zastępuje strefy.
Rozwiązuje się na adres, którego gość nie wystawia.

Tunel `jjdevhub` jest wołany przez proces `cloudflared` i przez panel, w którym leży mapa
hostname → origin. Gdy tunelu nie ma, Deployment może być Ready, a nazwa nie ma dokąd iść.
Gdy tryb nie jest remotely managed, lista originów zaczyna żyć w pliku, a token ląduje obok
kodu. Ten numer trzyma listę w panelu.

Secret `cloudflared-token` jest wołany przez Deployment `cloudflared`. Niesie token. Gdy go
nie ma, kontener nie dostaje `TUNNEL_TOKEN` i połączenie na 7844 nie wstaje. Gdy wartość
jest w git, klon staje się kopią drzwi do strefy. Przykład z pustym polem tego Secretu nie
zastępuje.

Deployment `cloudflared` jest wołany przez kubelet w `jjdevhub`. Trzyma jedną replikę,
wychodzi na 7844 i oddaje HTTP do originu z panelu. Gdy `replicas` jest inne niż 1 albo gdy
istnieje HPA tego Deploymentu, konektor przestaje być pojedynczym wyjściem z tego numeru.
Gdy obraz jest tagiem, a nie digestem, podmiana binarki nie jest zmianą pliku, który
recenzujesz.

Public hostname strony jest wołany przez czytelnika, studenta, rekrutera i właściciela. Jego
jedyny origin aplikacji to `gateway` na 8080. Gdy originem jest pod usługi, JWT i
`GET /versions` nie stoją na drodze. YARP tego hostname’u nie woła. Service `gateway` woła
pody bramy. Tunel o liczbie podów nie wie.

Access na panelach jest wołany przez przeglądarkę operatora, gdy hostname Grafany, Jaegera
albo Prometheusa istnieje. Gdy polityki nie ma, UI bez logowania aplikacji wisi na
publicznej nazwie. YARP tej polityki nie zastępuje. Brak hostname’u, dopóki Service nie
istnieje, jest stanem poprawnym, nie brakiem Accessu.

Service `gateway` jest wołany przez konektor. Jest jedyną bramą HTTP aplikacji. Gdy Service
nie nazywa się `gateway` albo nie słucha na 8080, URL z panelu trafia w pustkę przy Healthy
tunelu. Poprawia się origin albo Service, nie rekordem A i nie drugim proxy.

## Testy

Testy tego numeru są operacyjne. Runnera xUnit tu nie ma. Padnięcie ma jeden widoczny objaw
w danym punkcie: tunel nie jest Healthy, log drukuje token, nazwa nie dochodzi do bramy,
lista hostname ma origin usługi, gość przyjmuje 443, panel oddaje UI bez Accessu albo git
zawiera token. NBomber i Testcontainers do tego numeru nie wchodzą.

| Faza | Treść |
| --- | --- |
| Przygotowanie (arrange) | strefa na Cloudflare, SSL Full, tunel `jjdevhub` remotely managed, Secret `cloudflared-token` tylko na maszynie, Deployment jednej repliki po digescie |
| Działanie (act) | `rollout status`, odczyt logu, `curl` na nazwę strony, przegląd public hostname, `nc` na 80 i 443 gościa spoza LAN |
| Sprawdzenie (assert) | tunel Healthy, tokenu nie ma w logu ani w git, origin aplikacji to `gateway` na 8080, gość nie łączy na 80 ani 443 |

1. Tunel jest Healthy w panelu, a pod działa.

```bash
kubectl -n jjdevhub rollout status deploy/cloudflared
kubectl -n jjdevhub logs deploy/cloudflared --tail=50
```

W logu jest zestawione połączenie i nie ma linii z wartością tokenu. `replicas` w manifeście
to 1, a `kubectl -n jjdevhub get deploy cloudflared` pokazuje jedną dostępną replikę. Brak
HorizontalPodAutoscaler o tej nazwie jest częścią tego punktu. Jeśli log zawiera token,
Deployment ma czytać go tak, żeby zrzut procesu go nie drukował, i punkt powtarza się po
poprawce manifestu. Jeśli stan w panelu nie jest Healthy, nie przechodź do `curl` strony:
najpierw 7844 na wyjściu, Secret i digest.

2. Z sieci innej niż LAN gościa, na nazwę wpisaną w panelu (w dokumencie wzór, nie rekord):

```bash
curl -fsS "https://hub.example.com/versions"
```

Operator podstawia prawdziwą nazwę. Dosłowne `hub.example.com` nie jest strefą tego klastra.
Odpowiedź, która przyjdzie, przechodzi przez YARP. Treść wersji zależy od tego, czy numer 16
już podniósł repliki. Sam fakt odpowiedzi HTTP z bramy, także 503, gdy repliki usług są
jeszcze 0, ale brama już stoi, pokazuje, że originem jest `gateway`. Gdy brama ma nadal zero
replik, testem tego numeru jest połączenie konektora i brak nasłuchu na gościu. `curl`
strony dochodzi w numerze 16.

3. Origin usług nie jest osiągalny publicznie. Z zewnątrz nie istnieje nazwa DNS wskazująca
wprost na `news` ani na Postgresa. Lista public hostname w panelu ma jedną pozycję aplikacji
i co najwyżej trzy pozycje paneli. Pozycja o URL `identity`, `news`, `learning`, `cv`,
`contact` albo `web` jest błędem, nawet gdy zwraca 200. Pozycja o porcie 5432, 6379, 9092,
8200, 4317 albo 6443 jest błędem, nawet gdy z LAN i tak da się zrobić port-forward.

4. Port gościa:

```bash
nc -vz <adres-gościa> 443
nc -vz <adres-gościa> 80
```

Oba z sieci spoza LAN kończą się odmową albo brakiem trasy. `curl` na nazwę strony przy
zamkniętym gościu nadal działa, bo ścieżka idzie przez Cloudflare. Odwrotny wynik, łączący
`nc` i martwy `curl`, oznacza otwarte wejście i tunel, który nie jest drogą strony. Ten
numer wymaga obu warunków naraz: gość zamknięty, nazwa żywa.

5. Panele bez Access nie zostają. Gdy hostname Grafany istnieje, żądanie bez tożsamości
Access dostaje stronę logowania Cloudflare albo przekierowanie, nie UI Grafany.

```bash
curl -sI "https://grafana.<strefa>"
```

Odpowiedź nie jest `200` z ciałem, które zawiera tytuł Grafany, dopóki operator się nie
uwierzytelni. To samo dotyczy nazw Jaegera i Prometheusa, gdy już istnieją. Gdy ich nie ma,
punkt jest spełniony przez brak rekordu, nie przez Access na pusty origin. Nazwa strony w
tym punkcie nie dostaje Accessu. Jej `curl` nie może kończyć się stroną logowania
Cloudflare.

6. W repozytorium nie ma tokenu:

```bash
git grep -n "eyJ" -- deploy/k3s/cloudflared || true
git grep -n "cloudflared-token" -- '*.yaml' ':!deploy/k3s/cloudflared/secret.example.yaml'
```

Pierwsze nie znajduje JWT tokenu tunelu. Drugie nie znajduje wartości. Przykład Secretu bez
danych jest dozwolony. Trafienie w `deployment.yaml` oznacza, że token albo jego fragment
wszedł do manifestu poda. Secret na maszynie tego trafienia nie usprawiedliwia.

7. Wyjście 7844 jest osobne od wejścia 443. Z gościa da się zestawić tunel, co widać po
Healthy, przy nadal czerwonym `nc` na 443 z zewnątrz. Jeśli Healthy gaśnie po zablokowaniu
UDP 7844 i wraca po odblokowaniu UDP albo TCP 7844, reguła firewall jest właściwa. Jeśli
ktoś „naprawi” Healthy przez otwarcie wejścia 443, punkt 4 staje się czerwony i numer nie
jest domknięty.

## Zasady

- Jedna ścieżka aplikacji: hostname strony, tunel, Service `gateway`, YARP. Drugi origin
  obchodzi JWT i `GET /versions`.
- Drugi Ingress, Traefik i ServiceLB zostają nieobecne, tak jak po numerze 08. Włączenie
  Traefika stawia drugą bramę obok YARP.
- Brak NodePort i LoadBalancer dla bramy, usług, Postgresa, Redisa, Kafki i OpenBao. Taki
  Service publikuje origin na adresie gościa.
- Token tunelu powstaje w panelu i żyje w Secretcie `cloudflared-token` na maszynie. W git
  go nie ma. Przykład w git ma puste pole.
- Trasy public hostname aplikacji nie wskazują na pod usługi domenowej ani na web jako
  osobny origin.
- Panele metryk i śladów, jeśli są w tunelu, mają Access. Strona CV Accessu nie dostaje.
  Logowanie czytelnika jest JWT Identity.
- Postgres `5432`, Redis `6379`, Kafka `9092`, OpenBao `8200`, OTLP `4317` i API k3s `6443`
  nie dostają public hostname.
- Obraz `cloudflared` w manifeście jest digestem. Tag jako jedyna referencja da się przepiąć
  bez recenzji pliku.
- Konektor ma jedną replikę i nie wchodzi do HPA. Druga replika konektora nie jest
  skalowaniem bramy.
- Tryb SSL strefy zostaje Full. Flexible myli diagnostykę odcinka, który wewnątrz namespace
  jest HTTP.
- Rekord A na adres domu albo LAN nie powstaje obok CNAME tunelu. Zapasowa ścieżka na gościa
  jest otwarciem wejścia.
- Tryb tunelu zostaje remotely managed. Lista originów w pliku w git ciągnie za sobą token.
- `GET /versions` i reszta kontraktu HTTP zostają w bramie. Ten numer nie dokłada nagłówka,
  który zmienia znaczenie żądania.
- Wyjście gościa na 7844/UDP i 7844/TCP zostaje dozwolone. Samo wyjście na 443 nie zestawia
  tunelu.
- Historia powłoki z linią tworzącą Secret ma być wyczyszczona. Token w issue albo w logu
  workflow jest tym samym wyciekiem co token w git.
- `secret.example.yaml` stosowany `kubectl apply` nie jest traktowany jako działający
  konektor. Puste pole ma puste zostać.

## Poza zakresem

- VM, k3s, magazyny, namespace i wyłączenie Traefika oraz ServiceLB są w
  [08-proxmox.md](08-proxmox.md). Ten numer nie powtarza instalacji klastra i nie zmienia
  StorageClass.
- Eksporter OTLP i kolektor są w [10-opentelemetry.md](10-opentelemetry.md). Port 4317 nie
  dochodzi do tego tunelu.
- Proces Prometheusa, Jaegera i Grafany oraz ich root URL są w
  [11-prometheus.md](11-prometheus.md), [12-jaeger.md](12-jaeger.md) i
  [13-grafana.md](13-grafana.md). Ten plik mówi, jakim originem wolno je podłączyć i że
  Access jest warunkiem hostname’u.
- Sekrety aplikacji i klucz rozszczelnienia są w [14-openbao.md](14-openbao.md). Token
  tunelu nie jest sekretem OpenBao w tym numerze. Wolno go tam przenieść później, bez zmiany
  originu `gateway`.
- Drugi pod za Service aplikacji jest w [15-skalowanie.md](15-skalowanie.md). HPA nie
  obejmuje `cloudflared`.
- Wystawienie obrazu, który naprawdę obsłuży `curl` treścią wersji, jest w
  [16-deploy.md](16-deploy.md). Przy zerowych replikach bramy ten numer zamyka się na
  Healthy konektora i zamkniętym gościu.
- Reguły YARP, JWT i kształt `GET /versions` są w [16-gateway.md](../api/16-gateway.md). Ten
  numer nie duplikuje tabeli tras.
- Stopka `web-vX.Y.Z` i ekran `mobile-vX.Y.Z` są we frontendzie, numery 02 i 06. Ten plik
  nie składa strony.
- Bramki gita i format tagu są w [07-wersje.md](07-wersje.md). Ten numer nie nadaje tagu i
  nie buduje obrazu aplikacji.
- Dashboard Aspire zostaje na laptopie. Ten numer nie publikuje go tunelem i nie wskazuje na
  niego originu strony.

## Źródła

- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/).
  Wiążący jest konektor, który wychodzi z sieci prywatnej do Cloudflare, oraz tunel jako
  nośnik public hostname. Dotyczy decyzji, że strona nie stoi na publicznym IP gościa, tylko
  na tunelu nazwanym `jjdevhub`. Ze źródła nie bierzemy katalogu innych sposobów wejścia, w
  tym przekierowania portów na routerze i stałego VPN jako jedynej drogi czytelnika.
- [Porty tunelu](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-with-firewall/).
  Wiążące jest wyjście na 7844, UDP przy QUIC i TCP przy HTTP/2, do sieci Cloudflare.
  Dotyczy reguły firewall gościa: oba protokoły na 7844 są dozwolone, a samo wyjście na 443
  tunelu nie zestawia. Ze źródła nie bierzemy listy adresów IP regionów jako rekordu A na
  gościa ani jako originu YARP.
- [SSL/TLS Full](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full/).
  Wiążący jest tryb strefy Full: przeglądarka–Cloudflare i dalszy odcinek po stronie
  Cloudflare są szyfrowane. Dotyczy ustawienia SSL/TLS tej strefy przy originie HTTP
  wewnątrz namespace. Ze źródła nie bierzemy wymogu certyfikatu na gościu ani Authenticated
  Origin Pulls, bo origin nie słucha publicznie.
- [Tryby SSL](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/).
  Wiążący jest sam podział trybów, z którego ten numer wybiera Full. Dotyczy diagnozy:
  kłódka w przeglądarce nie mówi, czy ClusterIP mówi HTTP. Ze źródła nie bierzemy trybu
  Flexible. Miesza on odcinek, który w tym układzie świadomie zostaje HTTP tylko wewnątrz
  klastra.
- [SSL Flexible](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/flexible/).
  Wiążące jest to, czego ten numer nie włącza: Flexible kończy TLS u Cloudflare i zostawia
  origin bez tego samego kontraktu diagnostycznego. Dotyczy zakazu Flexible przy originie
  `gateway` na HTTP. Ze źródła nie bierzemy tego trybu jako uproszczenia, skoro tunel i tak
  szyfruje odcinek do konektora.
- [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/).
  Wiążąca jest polityka, która wpuszcza albo odrzuca tożsamość przed originem. Dotyczy Allow
  wyłącznie dla konta operatora na hostname’ach Grafany, Jaegera i Prometheusa. Ze źródła
  nie bierzemy Accessu na nazwę strony CV. Logowanie czytelnika zostaje JWT Identity.
- [Aplikacje Access self-hosted](https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/).
  Wiążący jest typ aplikacji self-hosted na nazwie, która już jest w tunelu. Dotyczy trzech
  paneli, i tylko wtedy, gdy ich Service już istnieje. Ze źródła nie bierzemy dokładania
  Accessu do `hub` ani publikowania panelu bez polityki.
- [DNS w Cloudflare](https://developers.cloudflare.com/dns/manage-dns-records/). Wiążące
  jest prowadzenie rekordów strefy w panelu, w tym rekordu tworzonego przy public hostname.
  Dotyczy CNAME proxied na tunel i zakazu drugiego rekordu A na adres domu albo LAN. Ze
  źródła nie bierzemy pliku strefy w git jako drugiego źródła prawdy.
- [Status proxy](https://developers.cloudflare.com/dns/proxy-status/). Wiążące jest
  rozróżnienie rekordu proxied i rekordu, który rozwiązuje się wprost na origin. Dotyczy
  chmurki przy CNAME tunelu: przeglądarka ma rozmawiać z Cloudflare. Ze źródła nie bierzemy
  wyłączenia proxy „żeby zobaczyć adres gościa”. Gość nie jest originem publicznym.
- [Typy rekordów DNS](https://developers.cloudflare.com/dns/manage-dns-records/reference/dns-record-types/).
  Wiążący jest rekord CNAME jako wskazanie na nazwę tunelu. Dotyczy kształtu
  `<tunel>.cfargotunnel.com`, który dopisuje panel. Ze źródła nie bierzemy rekordu A ani
  AAAA na adres gościa jako zamiennika tego CNAME.
- [Pełna delegacja strefy](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/).
  Wiążące jest wskazanie nameserverów u rejestratora na Cloudflare, zanim nazwa w ogóle
  należy do strefy. Dotyczy kroku 1 planu: bez delegacji `curl` nie jest próbą tunelu. Ze
  źródła nie bierzemy częściowej delegacji, która zostawia część nazw poza strefą tego
  konta.
- [Tunel zdalnie zarządzany](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/).
  Wiążące jest tworzenie tunelu w panelu i token, którym konektor się przedstawia, bez pliku
  konfiguracji tras w repozytorium. Dotyczy trybu remotely managed, nazwy `jjdevhub` i
  Secretu `cloudflared-token`. Ze źródła nie bierzemy lokalnego pliku tunelu z listą
  hostname’ów commitowaną obok kodu.
- [cloudflared na Kubernetes](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/deployment-guides/kubernetes/).
  Wiążący jest Deployment, argumenty `tunnel --no-autoupdate run` i token ze Secretu, nie z
  obrazu. Dotyczy namespace `jjdevhub`, klucza `token` i jednej repliki. Ze źródła nie
  bierzemy przykładowego pliku z wklejonym tokenem, obcej nazwy Secretu, portu metryk
  konektora ani większej liczby replik.
- [Dostępność tunelu](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/).
  Wiążące jest to, że dokumentacja łączy dodatkowe repliki konektora z odpornością tunelu.
  Dotyczy świadomego odejścia: ten numer zostawia `replicas: 1` i nie oddaje konektora HPA.
  Ze źródła nie bierzemy drugiej repliki jako układu JJDevHub.
- [Public hostname](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/).
  Wiążące jest mapowanie nazwy i ścieżki na origin, z typem HTTP i URL wewnątrz sieci
  konektora. Dotyczy jednego originu aplikacji `gateway.jjdevhub.svc.cluster.local:8080`
  oraz osobnych originów paneli. Ze źródła nie bierzemy ścieżki dopinanej w panelu zamiast
  reguły YARP ani originu na pod usługi.
- [YARP](https://microsoft.github.io/reverse-proxy/). Wiążąca jest brama aplikacji, na
  której kończy się origin tunelu. Dotyczy tego, że trasy HTTP, JWT i `GET /versions`
  zostają w `JJDevHub.Gateway`, a nie w public hostname. Ze źródła nie bierzemy drugiej
  bramy przed YARP ani trasy panelu obserwowalności przez tę samą konfigurację.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest ClusterIP jako adres wewnętrzny, bez publikacji na węźle. Dotyczy Service
  `gateway` na 8080 i zakazu NodePort oraz LoadBalancer dla bramy i baz. Ze źródła nie
  bierzemy typu, który wystawia origin na adresie gościa.
- [Kubernetes Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).
  Wiążące jest utrzymanie zadanej liczby replik. Dotyczy Deploymentu `cloudflared` z
  `replicas: 1` w `jjdevhub`. Ze źródła nie bierzemy podniesienia tej liczby jako sposobu na
  skalowanie strony.
- [Kubernetes Secret](https://kubernetes.io/docs/concepts/configuration/secret/). Wiążące
  jest trzymanie wartości poza obrazem i poza argumentem widocznym w manifeście gita.
  Dotyczy `cloudflared-token` tworzonego na maszynie i pustego `secret.example.yaml`. Ze
  źródła nie bierzemy commitu wartości tokenu.
- [Obrazy kontenerów](https://kubernetes.io/docs/concepts/containers/images/). Wiążące jest
  wskazanie obrazu po digescie, który nie przepina się razem z tagiem. Dotyczy
  `cloudflare/cloudflared@sha256:…` w manifeście konektora. Ze źródła nie bierzemy tagu
  `latest` jako jedynej referencji, którą kubelet ma uruchamiać.
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/).
  Wiążące jest to, że HPA zmienia `replicas` według metryki. Dotyczy zakazu: konektor nie ma
  takiego obiektu, a próg CPU strony nie jest progiem tunelu. Ze źródła nie bierzemy HPA dla
  `cloudflared`. Skalowanie usług jest w numerze 15.
- [Konfiguracja k3s](https://docs.k3s.io/installation/configuration). Wiążące są flagi,
  którymi numer 08 wyłącza Traefika i ServiceLB. Dotyczy tego, że ten numer ich nie cofa i
  nie dokłada Ingress. Ze źródła nie bierzemy domyślnego Traefika jako bramy przed YARP.
- [kubectl port-forward](https://kubernetes.io/docs/tasks/access-application-cluster/port-forward-access-application-cluster/).
  Wiążące jest tymczasowe przekierowanie z maszyny operatora na Service w klastrze. Dotyczy
  diagnostyki Postgresa, Redisa, Kafki, OpenBao, OTLP i API k3s z LAN, bez public hostname.
  Ze źródła nie bierzemy zostawienia forwardu jako stałego wejścia z internetu.

## Gotowe gdy

- Strefa jest na Cloudflare, nameservery wskazują na tę strefę, SSL to Full, a Authenticated
  Origin Pulls zostają wyłączone.
- Tunel `jjdevhub` jest remotely managed i ma stan Healthy.
- Deployment `cloudflared` w `jjdevhub` ma jedną gotową replikę, obraz po digescie i nie ma
  HPA.
- Tokenu nie ma w `git grep` po `deploy/k3s/cloudflared`, a `secret.example.yaml` ma puste
  pole.
- Log konektora pokazuje zestawione połączenie i nie zawiera wartości tokenu.
- Jedyny public hostname aplikacji wskazuje `gateway.jjdevhub.svc.cluster.local:8080`.
- Nie ma public hostname na `identity`, `news`, `learning`, `cv`, `contact`, `web`,
  Postgresa, Redisa, Kafkę, OpenBao, OTLP ani API k3s.
- Nie ma rekordu A na adres domu ani LAN obok CNAME tunelu.
- Z sieci spoza LAN `nc -vz <adres-gościa> 443` i to samo na 80 nie łączą, a nazwa strony
  rozwiązuje się na Cloudflare, nie na adres gościa.
- Wyjście gościa na 7844/UDP i 7844/TCP jest dozwolone. Samo 443 na wyjściu nie jest
  warunkiem, który ten numer uznaje za tunel.
- Jeśli hostname paneli już istnieje, `curl -sI` na `https://grafana.<strefa>` zwraca
  przekierowanie albo odpowiedź Access, nie `200` z tytułem Grafany, dopóki operator się nie
  uwierzytelni. To samo dotyczy Jaegera i Prometheusa.
- Jeśli hostname’ów paneli jeszcze nie ma, ich brak jest stanem poprawnym do czasu
  Service’ów z numerów 11–13.
- Traefik, ServiceLB, Ingress, NodePort i LoadBalancer bramy pozostają nieobecne.
- Przy zerowych replikach bramy numer jest domknięty połączeniem konektora i zamkniętym
  gościem. Treść `GET /versions` dochodzi w numerze 16.
