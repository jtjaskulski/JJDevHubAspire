# 08. Proxmox

[Spis CI/CD](README.md) · poprzedni: [07. Wersje](07-wersje.md) · następny: [09.
Cloudflare](09-cloudflare.md)

Tu powstaje maszyna, zanim powstanie Aspire. W kolejności plików poprzedni
jest [07-wersje.md](07-wersje.md), następny jest [09-cloudflare.md](09-cloudflare.md). W
kolejności pracy ten numer idzie zaraz po wersjach: bramki gita i tagi
komponentów są już wymagane, obrazu aplikacji jeszcze nie ma. Następny krok
pracy to tunel.

AppHost zostaje składem deweloperskim. Na maszynę wchodzą manifesty k3s. Nazwy zasobów są
takie same jak nazwy zasobów Aspire, żeby `aspire run` i klaster mówiły o tym samym
Postgresie, tym samym Redisie i tych samych usługach. Produkcja jest jedną maszyną wirtualną
na własnym hoście Proxmox. Nazwa VM to `jjdevhub`. Gość ma 4 vCPU, 16 GiB RAM bez balonu,
dysk 120 GiB, firmware OVMF, maszynę q35 i vTPM 2.0.

Scenariusz, który bez tej maszyny nie ma gdzie stanąć, zaczyna się od tagu. Numer `07`
wyciął `news-v1.4.0`. Lista „do zbudowania” ma jeden element. Laptop zostaje miejscem pracy.
`aspire run` pokazuje dashboard i Redis. Publiczna strona, telefon i `GET /versions` nie
mają procesu, który by im odpowiedział. Bez VM tag jest metką w gitcie. Obrazu nie ma gdzie
rozpakować. Kopia zapasowa nie ma czego objąć.

Drugi scenariusz to wejście HTTP obok YARP. Domyślny k3s dokłada Traefik i ServiceLB. Ktoś
przekierowuje na routerze porty `80` i `443` na gościa, „żeby zobaczyć stronę”. Drugi ruter
HTTP dubluje nagłówki, limity i logikę JWT, którą trzyma `JJDevHub.Gateway`. Ten numer
wyłącza oba dodatki flagami `--disable=traefik` i `--disable=servicelb`. Router nie dostaje
przekierowania `80`, `443` ani `6443`. Jedyną bramą HTTP aplikacji zostaje YARP. Ruch z
internetu wchodzi dopiero tunelem z numeru `09`, na ClusterIP bramy.

Trzeci scenariusz to sekret na dysku gościa. OpenBao z numeru `14` pieczętuje klucz
rozszczelnienia do układu z vTPM przez `systemd-creds`. Maszyna bez vTPM albo kopia samego
dysku danych, bez stanu TPM, zostawia klucz w pliku albo nie odpieczętowuje go po
odtworzeniu. BIOS bez TPM odpada. Zwykły plik na dysku gościa odpada z tego samego powodu,
dla którego sekret nie wchodzi do gita. `vzdump` obejmuje dysk EFI i stan vTPM.

Czwarty scenariusz to pod aplikacji, zanim jest digest. Ktoś ustawia `replicas: 1` i obraz
`:latest`, żeby „coś wstało”. Klaster ciągnie ruchomy tag albo pada na pustym odniesieniu.
Ten numer zostawia `replicas: 0`, dopóki numer `16` nie wpisze
`ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:<digest>`. `mobile` nie dostaje poda.
Telefon jest klientem. `JJDevHub.AppHost` nie jest Deploymentem. Hasło nie stoi w
manifeście.

## Po co

Bez tej maszyny tag z [07-wersje.md](07-wersje.md) nie ma gdzie stanąć. Laptop zostaje
miejscem pracy. Produkcja jest jedną maszyną wirtualną na własnym hoście Proxmox, z k3s w
jednym węźle i z containerd jako runtime kontenerów. Drugi węzeł k3s nie wchodzi w tym
numerze. Padnięcie maszyny jest padnięciem całości. Odtworzenie idzie z kopii Proxmoxa, nie
z drugiego mastera, którego nie ma.

Na tym klastrze mają działać Postgres, Redis i Kafka. Pięć usług domenowych dostaje tu
własne bazy zapisu i odczytu, na razie puste. OpenBao, tunel, telemetria, drugi pod i sam
rollout dochodzą w numerach `09` – `16`. Ten numer stawia węzeł, namespace `jjdevhub` i
magazyny, bez których tamte numery nie mają procesu do podłączenia. Init Postgresa wykonuje
`CREATE DATABASE` dla dziesięciu nazw i kończy się na tym. Tabeli strumienia, outboxa ani
projekcji tu nie ma.

Publiczny adres i otwarty port originu nie są częścią tego kroku. Wejście HTTP aplikacji
opisuje [09-cloudflare.md](09-cloudflare.md). Jedyną bramą HTTP aplikacji zostaje YARP
(`JJDevHub.Gateway`). Żaden magazyn nie publikuje NodePort ani LoadBalancer. Service’y
`postgres`, `cache` i `kafka` są ClusterIP. SonarQube dostaje pod i PVC, bez publicznego
Service. Port `9000` nie wchodzi do tunelu i nie słucha na `0.0.0.0`.

Nazwy mają być te same co w Aspire, bo inaczej lokalny dashboard i `kubectl get svc`
mówiłyby o dwóch systemach. Zasób `cache` na laptopie i Service `cache` na `6379` w klastrze
to jedna umowa. `postgres` i `kafka` też. Usługi `identity`, `news`, `learning`, `cv`,
`contact`, `gateway` i `web` mają Service o tej samej nazwie, port HTTP `8080`, probe
`/health` z ServiceDefaults. Dopóki digestu nie ma, replik jest zero. AppHost tego
Deploymentu nie dostaje. Zostaje przy `aspire run`.

Rozmiar jest policzony pod ten jeden węzeł. 4 vCPU i 16 GiB bez balonowania mają pomieścić
Postgresa, jednego brokera Kafki, Redisa, siedem Deploymentów aplikacji, gdy numer `16` je
podniesie, miejsce na drugi pod z numeru `15` oraz stos z numerów `10` – `14`. Dysk 120 GiB
ma pomieścić obrazy containerd, PVC Postgresa 40 GiB, PVC Kafki 20 GiB i PVC Sonara.
Mniejszy gość, 4 GiB RAM i dysk 40 GiB, zjada ten zapas na samych dziesięciu bazach i
brokerze KRaft, zanim wstanie drugi pod.

Firewall gościa ma politykę wejścia drop. Dozwolone jest SSH i port API k3s `6443` wyłącznie
z LAN operatora. Z sieci spoza LAN porty `80`, `443` i `6443` na adresie gościa nie
przyjmują połączenia. Wyjście jest dozwolone, bo tunel, rejestr obrazów i runner z numeru
`16` łączą się z maszyny na zewnątrz. Publiczne IP gościa nie jest wymagane. Kubeconfig nie
wchodzi do gita.

## Dlaczego ta technologia

### Jedna maszyna wirtualna na Proxmoxie

Proxmox VE stawia maszynę wirtualną na własnym hoście. Gość ma własny kernel, własny dysk i
własny vTPM. Nazwa w kreatorze to `jjdevhub`. Firmware to OVMF, maszyna q35, TPM to vTPM 2.0
z magazynem stanu obok dysku VM. Dysk ma 120 GiB, VirtIO SCSI, discard włączone. CPU to 4
vCPU typu `host`. Pamięć to 16384 MiB, balonowanie wyłączone. Sieć to most `vmbr0`, model
VirtIO, adres w LAN. Gość systemu to Debian 13 albo Ubuntu Server 24.04 LTS. Qemu Guest jest
włączony w kreatorze, żeby host widział adres IP i mógł robić `vzdump` na działającej
maszynie. ISO schodzi po instalacji.

Kopia zapasowa jest kopią całej maszyny (`vzdump`), więc odtworzenie dotyczy jednego gościa,
a nie zestawu wolumenów składanych ręcznie w chmurze. Harmonogram: tryb snapshot, magazyn
poza dyskiem tej VM, co najmniej jedna kopia dzienna i jedna trzymana poza hostem. Kopia
obejmuje dysk EFI i stan vTPM. Przywrócenie testowe na izolowany identyfikator VM jest
częścią sprawdzenia tego numeru, zanim na maszynie staną dane usług. Kopia samego dysku
danych, bez stanu TPM, nie wystarcza do numeru `14`.

Problem, który ta jedna maszyna zamyka, jest lokalny. Tag `news-v1.4.0` ma mieć jądro, dysk
i adres w LAN. DNS i certyfikat publiczny są w numerze `09`. Tutaj jest origin, którego
tunel jeszcze nie dotyka. Pięć baz zapisu i pięć baz odczytu mają leżeć na jednym Postgresie
w namespace `jjdevhub`, nie na laptopie osoby, która ostatnio odpaliła `aspire run`. Laptop
gaśnie. VM zostaje. Zegar gościa idzie z chrony, bo JWT i certyfikaty k3s rozjeżdżają się
przy dryfie.

Odpada chmura publiczna. Cel tego ciągu jest lokalny: jedna maszyna, DNS w Cloudflare, brak
rachunku za węzeł zarządzany. Odpada LXC na tym samym hoście. k3s potrzebuje własnego cgroup
i własnego modułu sieci gościa. Współdzielony kernel hosta psuje ten układ przy aktualizacji
Proxmoxa. Aktualizacja hosta nie może być aktualizacją jądra jedynej produkcji. Osobny
kernel gościa jest tą granicą. Łatki gościa i łatki k3s są świadomym krokiem operatora, poza
pull requestem aplikacji.

Koszt: 4 vCPU, 16 GiB RAM bez balonowania, dysk 120 GiB, osobny system do łatania i jeden
adres w LAN. Host Proxmox musi mieć te 16 GiB wolne na stałe. Balon oddałby pamięć w chwili,
gdy Kafka i Postgres trzymają page cache. Dysk 120 GiB trzeba pilnować retencją Prometheusa
i Jaegera, opisaną w numerach `11` i `12`. Drugiej maszyny na obserwowalność ten numer nie
stawia. Stos z numerów `10` – `14` ma się zmieścić tutaj.

### k3s, jeden węzeł, containerd

k3s jest Kubernetesem spakowanym do jednego węzła. Datastore kontrolera zostaje wbudowany,
SQLite. Runtime kontenerów to containerd dostarczony z k3s. Obraz z rejestru jest
rozpakowywany tam, a kubelet go uruchamia. Instalacja idzie z `--disable=traefik` i
`--disable=servicelb` oraz z `--write-kubeconfig-mode 600`. Zostaje metrics-server, bo numer
[15-skalowanie.md](15-skalowanie.md) czyta z niego CPU. Zostaje local-path, bo wolumeny
Postgresa, Kafki i Sonara muszą przeżyć restart poda. StorageClass `local-path` ma być
domyślna.

Jeden węzeł widać w `kubectl get nodes`: jedna linia, status `Ready`.
`kubectl get ingressclass` jest puste. Pody Traefika i ServiceLB nie istnieją.
`kubectl get apiservice v1beta1.metrics.k8s.io` pokazuje metrics-server. Kubeconfig dla
użytkownika `deploy` to `/etc/rancher/k3s/k3s.yaml`, prawa `600`, właściciel root. Kopia na
laptopie operatora służy do `kubectl` z LAN. Plik nie wchodzi do gita. Wejście na gościa
jest po SSH kluczem, na użytkownika `deploy`. Hasło SSH zostaje wyłączone.

Problem jednego węzła jest uczciwy. Nie ma drugiego mastera. Awaria dysku albo zasilania
kładzie API, kubelet i wszystkie pody. Dlatego kopia jest kopią VM, nie kopią samego etcd,
którego tu nie ma. SQLite jest datastore kontrolera jednego serwera. Osobny proces etcd na
tym samym dysku dodałby certyfikaty i drugi punkt awarii, który i tak kładzie jedyną
maszynę. Przywrócenie testowe na izolowany identyfikator VM, zanim staną dane usług,
sprawdza, że ta kopia w ogóle wstaje.

Odpada kubeadm z osobnym etcd. Na jednym węźle dokładają się certyfikaty i drugi proces,
którego awaria i tak kładzie jedyną maszynę. Odpada Docker Engine jako runtime klastra. k3s
nie potrzebuje demona Dockera, a dwa runtime na jednym dysku dzielą miejsce na obrazy.
Osobny Docker Engine na gościu nie jest wymagany i nie zastępuje kubeletu. Odpada sam plik
Compose jako produkcja. HPA, Service i ServiceAccount są kontraktem numerów `14`, `15` i
`16`. Compose na laptopie może zostać przy lokalnym Sonarze z numeru `05`. Na tej maszynie
kontraktem jest manifest w `deploy/k3s/`.

Koszt: jeden węzeł oznacza brak drugiego mastera. Padnięcie maszyny jest padnięciem całości,
a odtworzenie idzie z kopii Proxmoxa. Operator łatki k3s świadomie, poza pull requestem,
który zmienia artykuł. Flagi `--disable` nie obejmują metrics-server ani local-path.
Wyłączenie local-path zostawiłoby PVC Postgresa bez klasy. Wyłączenie metrics-server
zabrałoby numerowi `15` odczyt CPU, zanim ten numer w ogóle powstanie.

### AppHost zostaje na laptopie

`JJDevHub.AppHost` składa Postgresa, Redisa, Kafkę, OpenBao i projekty na czas `aspire run`.
Ten proces nie dostaje Deploymentu. Produkcja czyta manifesty z `deploy/k3s/`. Wolno je
uzyskać publikacją Aspire do Kubernetesa albo napisać je ręcznie. W obu przypadkach nazwa
zasobu w manifeście jest nazwą zasobu Aspire. `kubectl get deploy -A` nie pokazuje
`JJDevHub.AppHost`. Dashboard deweloperski nie słucha na tej maszynie.

Nazwa jest umową między numerami, nie ozdobą. News, które kiedyś zapisze artykuł, dostanie
connection string do Service `postgres` i do bazy `news_write`, nie do connection stringa
wpisanego w gicie. Cv dostanie `cv_write` i `cv_read`. Identity, Learning i Contact tak
samo, każda swoje dwie bazy. Redis w kodzie szuka `cache`, bo tak nazywa się zasób na
laptopie i Service na `6379`. Kafka w kodzie szuka `kafka` i listenera
`kafka.jjdevhub.svc.cluster.local:9092`. Inna nazwa „produkcyjna” rozjechałaby dashboard i
klaster.

Odpada osobny zestaw nazw „produkcyjnych”. Lokalny dashboard i `kubectl get svc` mówiłyby o
dwóch systemach. Ktoś poprawia nazwę w AppHost i zapomina manifestu, albo odwrotnie. Probe
`/health` w klastrze wołałaby ścieżkę, której ServiceDefaults na laptopie nie mapuje, albo
mapuje ją pod innym portem niż `8080`. Ten numer ustala port i nazwę zanim powstanie
pierwszy Deployment z niezerową repliką. Manifest w `deploy/k3s/apps/` trzyma kształt.
Digest wpisuje numer `16`.

Koszt: manifest trzeba trzymać w repozytorium obok tagu, a zmiana nazwy w AppHost wymaga
zmiany manifestu w tym samym wydaniu. Dwa opisy tej samej topologii starzeją się osobno,
jeśli ktoś doda zasób tylko w jednym z nich. Dlatego lista nazw jest krótka i jawna:
`postgres`, `cache`, `kafka`, `identity`, `news`, `learning`, `cv`, `contact`, `gateway`,
`web`. `mobile` na tej liście Deploymentu nie ma.

### Traefik i ServiceLB wyłączone

k3s domyślnie dokłada Traefik i ServiceLB. Oba robią z Service’u publiczny punkt wejścia.
YARP jest jedyną bramą HTTP aplikacji, więc instalacja k3s idzie z
`--disable=traefik --disable=servicelb`. Zostaje metrics-server i local-path. Żaden z trzech
Service’ów magazynu nie ma `type: LoadBalancer` ani `type: NodePort`. Service aplikacji też
jest ClusterIP. LoadBalancer nie dostaje adresu z zewnątrz, bo ServiceLB nie stoi. To jest
cel, nie brak.

Ruch z internetu nie wchodzi na gościa portem `80` ani `443`. Router nie ma tych
przekierowań i nie ma przekierowania `6443`. API k3s przyjmuje połączenie z LAN operatora. Z
sieci spoza LAN `nc` na `443` adresu gościa ma się nie połączyć. To samo dotyczy `80` i
`6443`. Tunel z numeru `09` dotrze do ClusterIP bramy. Do tego czasu brama ma zero replik,
więc tunel i tak nie ma jeszcze procesu HTTP. Kształt Service już jest, żeby numer `09` nie
wymyślał drugiej nazwy.

Odpada Ingress albo Gateway API przed YARP. Drugi ruter HTTP dublowałby nagłówki, limity i
logikę JWT, którą trzyma `JJDevHub.Gateway`. `kubectl get ingress -A` ma być puste. Odpada
zostawienie Traefika „na chwilę, aż brama wstanie”. Chwila bez bramy i z Traefikiem jest
właśnie oknem, w którym ruch omija JWT. Odpada NodePort „żeby z laptopa trafić w Postgresa”.
Postgres, Redis i Kafka zostają przy ClusterIP. Z laptopa operatora widać API na `6443` z
LAN, nie bazy.

Koszt: żaden Service typu LoadBalancer nie dostanie adresu z zewnątrz. Diagnostyka z
zewnątrz sieci operatora nie uderza w `kubectl`. Uderza dopiero tunel, gdy numer `09` go
postawi, i tylko w bramę. Sonar na tej maszynie też nie jest publicznym Service. Job
`sonarqube` do czasu numeru `14` nadal liczy werdykt na własnym kontenerze na
`ubuntu-latest`, tak jak numer `05`. Adres tej maszyny wolno potem podstawić zmienną
przebiegu czytaną z OpenBao. Podmiana adresu nie wyłącza checka.

### vTPM i UEFI

Maszyna dostaje firmware OVMF i vTPM 2.0. Kreator ma magazyn TPM obok dysku VM i dysk EFI. W
gościu `test -c /dev/tpmrm0` kończy się kodem `0` i wypisuje `tpm-ok`. Klucz rozszczelnienia
OpenBao z numeru [14-openbao.md](14-openbao.md) jest pieczętowany do tego układu przez
`systemd-creds`. Bez vTPM klucz musiałby leżeć w pliku albo w zmiennej procesu. Ten numer
jeszcze nie stawia OpenBao. Stawia układ, do którego numer `14` ma się do czego przyłożyć.
Kopia bez stanu TPM zostawia dysk, którego klucz nie odpieczętuje.

Odtworzenie na innym hoście Proxmox bez tego vTPM nie odpieczętowuje klucza. Dlatego
`vzdump` obejmuje stan TPM i dysk EFI, nie tylko dysk danych 120 GiB. Tryb snapshot nie
wyłącza maszyny na czas kopii dziennej. Magazyn kopii leży poza dyskiem tej VM. Jedna kopia
leży poza hostem. Przywrócenie testowe idzie na izolowany identyfikator VM, zanim na
maszynie staną dane usług. Ćwiczenie na produkcyjnym identyfikatorze, z już wypełnionymi
bazami, jest za późne na pierwsze sprawdzenie, czy TPM w ogóle wraca.

Odpada BIOS bez TPM. Pieczęć nie ma wtedy sprzętowego korzenia, nawet wirtualnego. Odpada
zwykły plik na dysku gościa. To ten sam powód, dla którego hasło nie wchodzi do manifestu i
nie wchodzi do gita. Odpada też traktowanie vTPM jak dyskretnego modułu na płycie hosta.
Jest emulacją przypiętą do VM. Jego wartość w tym numerze jest taka, że stan da się
skopiować razem z maszyną i że klucz z numeru `14` nie leży obok w pliku tekstowym. Kopia,
która ten stan pominie, nie spełnia numeru `14`, nawet jeśli Postgres wstanie.

Koszt: kreator VM musi mieć maszynę typu q35, magazyn TPM i dysk EFI. OVMF nie jest
domyślnym SeaBIOS. q35 nie jest domyślną płytą, którą kreator podstawia pod każdy szablon.
Pomylenie tego na starcie wychodzi dopiero przy pieczęci, gdy bazy już coś trzymają. Dlatego
`test -c /dev/tpmrm0` jest sprawdzeniem tego numeru, zanim init Postgresa dostanie dane
usług. Hasła bazy i tak tu nie ma. Jest urządzenie.

### Rozmiar dysku i RAM

16 GiB i 120 GiB mieszczą Postgresa, jednego brokera Kafki, Redisa, siedem Deploymentów
aplikacji (pięć usług, brama, web), miejsce na drugi pod z numeru `15` oraz stos z numerów
`10` – `14`. Balonowanie RAM jest wyłączone, żeby gość nie oddał pamięci w chwili, gdy Kafka
i Postgres trzymają page cache. 4 vCPU typu `host` są stałe. Nie ma tu drugiego węzła, na
który dałoby się zepchnąć brokera.

Postgres: obraz `postgres:16-alpine`, jedna replika, PVC 40 GiB na `local-path`, port
`5432`, probe `pg_isready`. Init tworzy dziesięć pustych baz. Redis: obraz zgodny z wersją
używaną przez AppHost, bez trybu klastra, wolumen `emptyDir`, Service `cache` na `6379`.
Utrata zawartości po restarcie poda jest przyjęta. Projekcje zostają w Postgresie. Cache
jest do odbudowy. Kafka: jeden broker KRaft, `CLUSTER_ID` stały w manifeście, PVC 20 GiB,
listener wewnętrzny `kafka.jjdevhub.svc.cluster.local:9092`. Brak listenera na hoście i brak
NodePort.

Mniejszy gość (4 GiB, dysk 40 GiB) odpada. Sam Postgres z dziesięcioma bazami i broker KRaft
zjadają ten zapas, zanim wstanie drugi pod. PVC 40 GiB nie mieści się na dysku 40 GiB obok
obrazów i PVC Kafki. Osobna maszyna na obserwowalność odpada, bo celem jest jeden węzeł.
Prometheus i Jaeger z numerów `11` i `12` mają retencję, która pilnuje tych 120 GiB. Bez
retencji dysk zapełni się śladem, nie danymi News.

Odpada balon „żeby host miał zapas na inne VM”. Ten gość jest produkcją JJDevHub. Oddanie
pamięci w szczycie page cache wygląda jak choroba Kafki i Postgresa, a jest ustawieniem
kreatora. Odpada dokładanie drugiego brokera „dla spokoju” na tym samym dysku. Jeden broker
KRaft jest kontraktem. Tematy i ich nazwy zostają przy [15-kafka.md](../api/15-kafka.md).
Ten numer nie zmienia semantyki klucza Redisa. Prefiks zostaje sprawą usługi.

Koszt: host Proxmox musi mieć te 16 GiB wolne na stałe. Dysk 120 GiB trzeba pilnować. Siedem
Deploymentów przy `replicas: 0` prawie nie je pamięci. Zapas jest na chwilę, w której numer
`16` wpisze digest i podniesie repliki, a numer `15` dołoży drugi pod. Do tego czasu zero
replik jest stanem poprawnym, nie awarią. AppHost na klastrze zjadłby ten zapas procesem,
który i tak nie jest produkcją.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/namespace.yaml` | Namespace `jjdevhub` |
| `deploy/k3s/postgres/statefulset.yaml` | Jeden Postgres 16, port 5432, PVC, init dziesięciu baz |
| `deploy/k3s/postgres/service.yaml` | ClusterIP `postgres` |
| `deploy/k3s/redis/statefulset.yaml` | Redis jako cache, `emptyDir` |
| `deploy/k3s/redis/service.yaml` | ClusterIP `cache` na 6379 |
| `deploy/k3s/kafka/statefulset.yaml` | Jeden broker KRaft, PVC na log |
| `deploy/k3s/kafka/service.yaml` | ClusterIP `kafka` na 9092 |
| `deploy/k3s/sonar/statefulset.yaml` | Jeden pod SonarQube, PVC, bez publicznego Service |
| `deploy/k3s/apps/` | Kształt Deploymentów i Service’ów aplikacji; digest obrazu wpisuje numer 16 |

Nazwy Service’ów aplikacji, zgodne z zasobami Aspire:

| Zasób | Service | Port HTTP |
| --- | --- | --- |
| `identity` | `identity` | 8080 |
| `news` | `news` | 8080 |
| `learning` | `learning` | 8080 |
| `cv` | `cv` | 8080 |
| `contact` | `contact` | 8080 |
| `gateway` | `gateway` | 8080 |
| `web` | `web` | 8080 |

`mobile` nie dostaje poda. Telefon jest klientem. Jego numer wersji zostaje na ekranie O
aplikacji i jest sprawdzany przy deployu w [16-deploy.md](16-deploy.md).

Bazy tworzone initem Postgresa, puste, bez schematu (schemat należy do numerów persistence w
`docs/api`):

| Zapis | Odczyt |
| --- | --- |
| `identity_write` | `identity_read` |
| `news_write` | `news_read` |
| `learning_write` | `learning_read` |
| `cv_write` | `cv_read` |
| `contact_write` | `contact_read` |

Każda usługa dostanie później tylko własne dwa poświadczenia. Ten numer nie wpisuje hasła do
manifestu. Poświadczenie bazy w produkcji dochodzi z OpenBao w numerze `14`. Do tego czasu
pod aplikacji i tak ma zero replik. Zmienne połączenia wskazują Service po nazwie. Wartość
hasła nie stoi w pliku.

Obraz aplikacji ma postać `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:<digest>`.
Manifest nie używa tagu `:latest`. Sonar używa tego samego wariantu Community Build co
kontener z [05-sonarqube.md](05-sonarqube.md), przypiętego skrótem. Projekt zostaje
`jjdevhub`. Bramka zostaje `jjdevhub` z `.github/sonar/quality-gate.json`. Check zostaje
`sonarqube`. `sonar.qualitygate.wait` zostaje włączone. Ten numer nie zmienia progu.

## Plan

### 1. Maszyna wirtualna

Na hoście Proxmox utwórz VM.

| Krok kreatora | Wartość |
| --- | --- |
| Nazwa | `jjdevhub` |
| Firmware | OVMF (UEFI), maszyna q35 |
| TPM | vTPM 2.0, magazyn TPM obok dysku VM |
| Gość | Debian 13 albo Ubuntu Server 24.04 LTS |
| Dysk | 120 GiB, VirtIO SCSI, discard włączone |
| CPU | 4 vCPU, typ `host` |
| Pamięć | 16384 MiB, balonowanie wyłączone |
| Sieć | most `vmbr0`, model VirtIO, adres w LAN |
| Qemu Guest | włączony w kreatorze |

ISO odmontuj po instalacji. Router nie dostaje przekierowania 80, 443 ani 6443. Publiczne IP
gościa nie jest wymagane.

### 2. System gościa

Wejdź po SSH kluczem, na użytkownika `deploy`. Hasło SSH zostaje wyłączone.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git chrony nftables
sudo systemctl enable --now chrony
```

W kreatorze włączony gość QEMU ma działać jako usługa systemowa, żeby host widział adres IP
i mógł robić `vzdump` na działającej maszynie. Zegar idzie z chrony, bo JWT i certyfikaty
k3s rozjeżdżają się przy dryfie.

Firewall gościa: polityka wejścia drop. Dozwolone jest SSH i port API k3s `6443` wyłącznie z
LAN operatora. Wyjście jest dozwolone, bo tunel, rejestr obrazów i runner z numeru 16 łączą
się z maszyny na zewnątrz.

### 3. k3s

Na gościu, jako root:

```bash
curl -sfL https://get.k3s.io | sh -s - \
  --disable=traefik \
  --disable=servicelb \
  --write-kubeconfig-mode 600
```

Kubeconfig dla `deploy`: `/etc/rancher/k3s/k3s.yaml`, prawa `600`, właściciel root. Kopia na
laptopie operatora służy do `kubectl` z LAN. Plik nie wchodzi do gita.

Sprawdzenie wyłączonych dodatków:

```bash
kubectl get ingressclass
kubectl get pods -A | grep -E 'traefik|svclb' || true
```

Oba polecenia mają być puste. `kubectl get apiservice v1beta1.metrics.k8s.io` ma pokazać
metrics-server. StorageClass `local-path` ma być domyślna.

### 4. Namespace i magazyny

Zastosuj manifesty z tabeli ścieżek. Kolejność: namespace, Postgres, Redis, Kafka.

Postgres: obraz `postgres:16-alpine`, jedna replika, PVC 40 GiB na `local-path`, probe
`pg_isready`. Init wykonuje `CREATE DATABASE` dla dziesięciu nazw z tabeli baz i kończy się
na tym. Rozszerzenia i tabele dochodzą z usług.

Redis: obraz zgodny z wersją używaną przez AppHost, args bez trybu klastra, wolumen
`emptyDir`. Utrata zawartości po restarcie poda jest przyjęta: projekcje zostają w
Postgresie, cache jest do odbudowy.

Kafka: jeden broker w trybie KRaft, `CLUSTER_ID` stały w manifeście, PVC 20 GiB, listener
wewnętrzny `kafka.jjdevhub.svc.cluster.local:9092`. Brak listenera na hoście i brak
NodePort.

Żaden z tych trzech Service’ów nie ma `type: LoadBalancer` ani `type: NodePort`.

### 5. Kształt aplikacji

W `deploy/k3s/apps/` każdy komponent klastrowy dostaje Deployment i Service ClusterIP. Nazwa
Deploymentu jest nazwą zasobu (`news`, `gateway`, `web`, …). Kontener słucha na 8080. Probe
gotowości i życia wołają `/health` z ServiceDefaults.

Pole obrazu ma postać `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:<digest>`. Dopóki
numer 16 nie wpisze digestu, `replicas` zostaje `0`. Manifest nie używa tagu `:latest`.

Zmienne połączenia do Postgresa, Redisa i Kafki wskazują Service po nazwie. Wartość hasła
nie stoi w manifeście. Poświadczenie bazy w produkcji dochodzi z OpenBao w numerze 14. Do
tego czasu pod aplikacji i tak ma zero replik.

### 6. SonarQube na tej maszynie

Jeden pod Community Build, ten sam wariant obrazu co kontener z
[05-sonarqube.md](05-sonarqube.md), przypięty skrótem. PVC na dane. Service ClusterIP, port
`9000`, bez hosta w tunelu i bez `0.0.0.0`. Publicznego Service nie ma. Projekt zostaje
`jjdevhub`. Bramka zostaje `jjdevhub` z `.github/sonar/quality-gate.json`. Check zostaje
`sonarqube`. `sonar.qualitygate.wait` zostaje włączone. Ten numer nie zmienia progu.

Job na `ubuntu-latest` do czasu [14-openbao.md](14-openbao.md) nadal liczy werdykt na
własnym kontenerze, tak jak numer 05. Adres tej maszyny wolno potem podstawić zmienną
przebiegu czytaną z OpenBao. Wartość tokenu nie wchodzi do `sonarqube.yml` i nie wchodzi do
gita. Podmiana adresu nie wyłącza checka na czas stawiania poda.

### 7. Kopia maszyny

Na hoście Proxmox ustaw harmonogram `vzdump` VM `jjdevhub`: tryb snapshot, magazyn poza
dyskiem tej VM, co najmniej jedna kopia dzienna i jedna trzymana poza hostem. Kopia obejmuje
dysk EFI i stan vTPM. Przywrócenie testowe na izolowany identyfikator VM jest częścią
sprawdzenia tego numeru, zanim na maszynie staną dane usług.

### Co jest do czego

| Plik albo proces | Po co istnieje | Kto go woła |
| --- | --- | --- |
| VM `jjdevhub` | Jeden kernel produkcyjny | Operator i harmonogram `vzdump` |
| k3s | API, kubelet, containerd, metrics-server | `kubectl`, runner z numeru 16 |
| `namespace.yaml` | Granica nazw `jjdevhub` | Każdy późniejszy manifest |
| Postgres | Dziesięć pustych baz | Usługi, gdy numer 16 podniesie repliki |
| Service `cache` | Cache współdzielony przez pody usługi | Kod cache z `docs/api/13-redis.md` |
| Service `kafka` | Jeden broker szyny | Outbox i inbox usług |
| `deploy/k3s/apps/` | Stałe nazwy, na które numer 16 nakłada digest | Job deployu |
| Pod SonarQube | Proces serwera jakości na tej maszynie | Bramka z numeru 05 |

Nikt z tych plików nie woła AppHosta. Nikt nie publikuje portu na adresie routera.

## Testy

Prawdy tego numeru sprawdzają się na maszynie i z LAN.

1. Węzeł jest jeden i gotowy.

```bash
kubectl get nodes
```

Jedna linia, status `Ready`.

2. Traefik i ServiceLB nie stoją, Ingressów nie ma.

```bash
kubectl get pods -A
kubectl get ingress -A
kubectl get svc -A
```

W podach nie ma `traefik` ani `svclb`. Lista Ingress jest pusta. Service’y `postgres`,
`cache` i `kafka` mają typ ClusterIP.

3. Magazyny odpowiadają.

```bash
kubectl -n jjdevhub exec statefulset/postgres -- psql -U postgres -c '\l'
kubectl -n jjdevhub exec statefulset/cache -- redis-cli ping
kubectl -n jjdevhub exec statefulset/kafka -- /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

`\l` zawiera dziesięć baz z tabeli. Redis zwraca `PONG`. Broker zwraca wersję API.

4. vTPM jest widoczny w gościu.

```bash
test -c /dev/tpmrm0 && echo tpm-ok
```

5. Z sieci spoza LAN porty 80, 443 i 6443 na adresie gościa nie przyjmują połączenia. Z LAN
   `6443` przyjmuje połączenie tylko od operatora.

6. `JJDevHub.AppHost` nie występuje w `kubectl get deploy -A`.

Każde polecenie ma jeden powód do niepowodzenia: albo węzeł, albo brak dodatku k3s, albo
magazyn, albo TPM, albo port, albo obecność AppHosta.

Dziesięć nazw w `\l` to pary zapisu i odczytu Identity, News, Learning, Cv i Contact. Brak
którejkolwiek jest porażką initu, nie „uzupełnimy przy pierwszej usłudze”. `PONG` z Redisa
nie znaczy, że w cache leży projekcja. Leżeć nie musi. `emptyDir` wolno zgubić. Wersja API
brokera znaczy, że listener na `9092` w klastrze odpowiada. Nie znaczy, że temat artykułu
już istnieje. Temat jest w numerze Kafki w `docs/api`.

Porty sprawdza się z sieci spoza LAN. `nc -vz <adres-gościa> 443` ma się nie połączyć. To
samo oczekiwanie dotyczy `80` i `6443`. Z LAN operatora `6443` przyjmuje połączenie. SSH
kluczem na `deploy` też, skoro firewall je puszcza z tej sieci. Hasło SSH zostaje wyłączone,
więc próba hasłem nie jest zielonym sprawdzeniem.

## Zasady

- Gość jest jeden. Drugi węzeł k3s nie wchodzi w tym numerze.
- Runtime kontenerów to containerd z k3s. Osobny Docker Engine na gościu nie jest wymagany i
  nie zastępuje kubeletu.
- Datastore kontrolera to wbudowany SQLite. Osobny etcd nie wchodzi.
- Manifesty używają nazw zasobów Aspire: `postgres`, `cache`, `kafka`, `identity`, `news`,
  `learning`, `cv`, `contact`, `gateway`, `web`.
- AppHost nie jest Deploymentem.
- YARP nie dostaje sąsiada w postaci Ingressu. Traefik zostaje wyłączony. ServiceLB też.
- Żaden magazyn nie publikuje NodePort ani LoadBalancer.
- Hasło, connection string z hasłem i klucz nie stoją w pliku w git.
- Redis jest cachem. Prefiks klucza zostaje sprawą usługi. Ten numer nie zmienia semantyki
  klucza.
- Kafka jest szyną. Jeden broker, tryb KRaft. Tematy i ich nazwy zostają przy
  [15-kafka.md](../api/15-kafka.md) w `docs/api`.
- Init Postgresa tworzy puste bazy. Nie tworzy tabel strumienia, outboxa ani projekcji.
- `mobile` nie jest podem.
- Repliki Deploymentów aplikacji zostają na 0, dopóki [16-deploy.md](16-deploy.md) nie
  wpisze digestu.
- Obraz aplikacji to `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:<digest>`. Tag
  `:latest` nie wchodzi.
- Sonar nie ma publicznego Service. Próg z numeru `05` się nie zmienia.
- Kopia `vzdump` obejmuje vTPM. Kopia samego dysku danych bez stanu TPM nie wystarcza do
  numeru 14.
- Łatki gościa i łatki k3s są świadomym krokiem operatora, poza pull requestem aplikacji.
- Wejście firewalla to drop. SSH i `6443` tylko z LAN. Przekierowań `80`, `443` i `6443` na
  routerze nie ma.

## Poza zakresem

- Gałęzie, tytuły, bramki, CodeQL, podatności, Sonar jako check, łańcuch dostaw i nadawanie
  tagu: [01-galezie.md](01-galezie.md) do [07-wersje.md](07-wersje.md). Tu jest tylko pod,
  na którym stoi serwer Sonara.
- DNS, certyfikat publiczny i tunel do bramy: [09-cloudflare.md](09-cloudflare.md).
- Collector OTLP, Prometheus, Jaeger i Grafana: [10-opentelemetry.md](10-opentelemetry.md),
  [11-prometheus.md](11-prometheus.md), [12-jaeger.md](12-jaeger.md),
  [13-grafana.md](13-grafana.md).
- OpenBao, polityki i krótkotrwałe poświadczenia: [14-openbao.md](14-openbao.md). Skład
  deweloperski OpenBao: [04-openbao.md](../api/04-openbao.md).
- Drugi pod i HPA: [15-skalowanie.md](15-skalowanie.md).
- Rollout tagu i rollback: [16-deploy.md](16-deploy.md).
- Schemat baz, outbox, inbox, trasy YARP i `GET /versions`: numery `docs/api`. Ten plik nie
  zmienia kontraktu HTTP.
- Stopka weba i ekran O aplikacji: [02-web.md](../frontend/02-web.md) i
  [06-mobile.md](../frontend/06-mobile.md).

Ten numer nie wycina tagu, nie buduje obrazu w workflow i nie otwiera portu originu. Nie
pisze tabeli artykułu. Nie ustawia prefiksu klucza. Nie zakłada tematu Kafki. Daje węzeł,
dziesięć pustych baz, cache, jednego brokera, kształt Deploymentu z zerem replik i kopię
maszyny ze stanem TPM.

## Źródła

- [Proxmox VE Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html). Wiążące
  jest stawianie maszyny wirtualnej na własnym hoście i kopia całej VM. Dotyczy jednego
  gościa `jjdevhub`, dysku 120 GiB, 4 vCPU i 16 GiB RAM. Ze źródła nie bierzemy LXC jako
  gościa k3s. Współdzielony kernel hosta psuje cgroup i sieć przy aktualizacji Proxmoxa. Nie
  bierzemy chmury publicznej jako węzła.
- [QEMU/KVM Virtual Machines](https://pve.proxmox.com/pve-docs/chapter-qm.html). Wiążące są
  firmware OVMF, typ maszyny q35 i vTPM 2.0 jako stan obok dysku. Dotyczy kreatora VM i
  sprawdzenia `test -c /dev/tpmrm0`. Ze źródła nie bierzemy SeaBIOS bez TPM i nie bierzemy
  twierdzenia, że emulowany moduł jest dyskretnym TPM na płycie. Bierzemy stan, który
  `vzdump` potrafi zabrać i do którego numer `14` pieczętuje klucz. Zwykły plik na dysku
  gościa odpada.
- [Backup and Restore](https://pve.proxmox.com/pve-docs/chapter-vzdump.html). Wiążący jest
  `vzdump` i tryb snapshot jako kopia VM bez składania wolumenów ręcznie. Dotyczy
  harmonogramu dziennego, magazynu poza dyskiem tej VM i kopii trzymanej poza hostem. Ze
  źródła nie bierzemy kopii samego dysku danych bez dysku EFI i bez stanu vTPM. Taka kopia
  nie wystarcza do numeru `14`. Przywrócenie testowe idzie na izolowany identyfikator VM,
  zanim staną dane usług.
- [k3s — Installation](https://docs.k3s.io/installation). Wiążąca jest instalacja jednego
  serwera skryptem `get.k3s.io`. Dotyczy węzła, który `kubectl get nodes` pokazuje jako
  jedyną linię `Ready`, i kubeconfig o prawach `600`. Ze źródła nie bierzemy klastra
  wielowęzłowego w tym numerze. Drugi master nie wchodzi. Padnięcie maszyny jest padnięciem
  całości, a odtworzenie idzie z kopii Proxmoxa.
- [k3s — server](https://docs.k3s.io/cli/server). Wiążące są `--disable=traefik` i
  `--disable=servicelb` oraz lista dodatków, które flaga umie wyłączyć. Dotyczy instalacji,
  po której nie ma podów `traefik` i `svclb`, a metrics-server zostaje. Ze źródła nie
  bierzemy wyłączenia metrics-server ani local-path. Numer `15` czyta CPU. PVC Postgresa i
  Kafki mają przeżyć restart poda. Nie bierzemy `--cluster-init` i etcd na tym jednym węźle.
- [k3s — Datastore](https://docs.k3s.io/datastore). Wiążący jest wbudowany datastore jednego
  serwera, SQLite, bez osobnego etcd. Dotyczy decyzji, że kontroler zostaje w k3s i że
  awaria jest awarią VM, nie awarią drugiego procesu na tym samym dysku. Ze źródła nie
  bierzemy zewnętrznego magazynu kontrolera i nie bierzemy kubeadm z osobnym etcd. Na jednym
  węźle dokładają się certyfikaty, a maszyna i tak jest jedna.
- [containerd](https://github.com/containerd/containerd). Wiążący jest runtime, którego
  używa k3s do rozpakowania obrazu. Dotyczy tego, że kubelet uruchamia obraz z rejestru, a
  osobny Docker Engine na gościu nie jest wymagany. Ze źródła nie bierzemy demona Dockera
  jako drugiego runtime na tym samym dysku. Dwa runtime dzieliłyby miejsce na obrazy.
  Compose nie zastępuje Service i ServiceAccount.
- [PostgreSQL 16](https://www.postgresql.org/docs/16/). Wiążący jest silnik w obrazie
  `postgres:16-alpine` i port `5432`. Dotyczy jednego StatefulSet w namespace `jjdevhub`
  oraz probe `pg_isready`. Ze źródła nie bierzemy dziesięciu serwerów. Jedna instancja,
  dziesięć baz. Nie bierzemy schematu, rozszerzenia ani tabeli strumienia w inicie tego
  numeru.
- [CREATE DATABASE](https://www.postgresql.org/docs/16/sql-createdatabase.html). Wiążące
  jest utworzenie pustej bazy poleceniem, które nie zakłada tabel. Dotyczy dziesięciu nazw:
  par zapisu i odczytu Identity, News, Learning, Cv i Contact. Ze źródła nie bierzemy
  wypełnienia schematu. Tabele należą do numerów persistence w `docs/api`. Hasło roli nie
  stoi w manifeście.
- [pg_isready](https://www.postgresql.org/docs/16/app-pg-isready.html). Wiążące jest
  sprawdzenie, że proces przyjmuje połączenia. Dotyczy probe StatefulSet Postgresa. Ze
  źródła nie bierzemy probe, która w opisie zwraca hasło albo connection string. Gotowość
  magazynu to odpowiedź procesu na `5432`, a lista baz to `\l` w teście.
- [Obraz Postgres](https://hub.docker.com/_/postgres). Wiążący jest oficjalny obraz i
  wariant `16-alpine`. Dotyczy jednej repliki i PVC 40 GiB na `local-path`. Ze źródła nie
  bierzemy tagu `latest`. Wersja linii to 16. Nie bierzemy publikacji portu na hoście.
  Service zostaje ClusterIP.
- [Apache Kafka KRaft](https://kafka.apache.org/documentation/#kraft). Wiążący jest jeden
  broker bez ZooKeepera, w trybie KRaft. Dotyczy StatefulSet z PVC 20 GiB, stałym
  `CLUSTER_ID` i listenerem `kafka.jjdevhub.svc.cluster.local:9092`. Ze źródła nie bierzemy
  drugiego brokera na tym dysku, nie bierzemy ZooKeepera i nie bierzemy listenera na hoście
  ani NodePort. Nazwy tematów zostają w `docs/api`.
- [Redis PING](https://redis.io/docs/latest/commands/ping/). Wiążące jest to, że żywy proces
  cache odpowiada `PONG`. Dotyczy testu `redis-cli ping` na StatefulSet `cache` oraz Service
  na `6379`. Ze źródła nie bierzemy trybu klastra i nie bierzemy PVC jako magazynu jedynej
  kopii danych. Wolumen to `emptyDir`. Projekcje zostają w Postgresie. Prefiks klucza
  zostaje sprawą usługi.
- [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/). Wiążące jest to, że
  `emptyDir` żyje razem z podem i znika przy jego usunięciu. Dotyczy Redisa jako cache do
  odbudowy. Ze źródła nie bierzemy `emptyDir` dla Postgresa, Kafki ani Sonara. Te trzy mają
  PVC na `local-path`, bo ich dane mają przeżyć restart poda. Dysk 120 GiB mieści 40 GiB i
  20 GiB oraz dane Sonara.
- [Service](https://kubernetes.io/docs/concepts/services-networking/service/). Wiążący jest
  typ ClusterIP jako publikacja tylko wewnątrz klastra. Dotyczy `postgres`, `cache`,
  `kafka`, usług aplikacji i Sonara. Ze źródła nie bierzemy `NodePort` i `LoadBalancer`.
  ServiceLB jest wyłączony, więc LoadBalancer i tak nie dostałby adresu. YARP zostaje jedyną
  bramą HTTP.
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server). Wiążące jest źródło
  CPU, które k3s zostawia w klastrze. Dotyczy decyzji, żeby `--disable` nie obejmowało
  metrics-server. Numer `15` czyta z niego CPU. Ze źródła nie bierzemy HPA w tym numerze.
  Drugi pod dochodzi później. Tu zostaje API, które
  `kubectl get apiservice v1beta1.metrics.k8s.io` ma pokazać.
- [.NET Aspire
  deployment](https://learn.microsoft.com/en-us/dotnet/aspire/deployment/overview). Wiążące
  jest to, że publikacja do Kubernetesa albo ręczny manifest mogą nieść te same nazwy
  zasobów co skład. Dotyczy `deploy/k3s/` i zakazu osobnego słownika nazw „produkcyjnych”.
  Ze źródła nie bierzemy Deploymentu z `JJDevHub.AppHost`. AppHost zostaje przy `aspire run`
  na laptopie. Dashboard produkcji nie uruchamia.
- [YARP](https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/yarp/yarp-overview).
  Wiążące jest to, że brama HTTP aplikacji jest jednym procesem reverse proxy. Dotyczy
  decyzji, że `JJDevHub.Gateway` jest jedyną bramą i że Traefik oraz Ingress przed nią
  odpadają. Ze źródła nie bierzemy tras i `GET /versions` w tym pliku. Trasy są w numerach
  `docs/api`. Tu jest Service `gateway` na `8080`, z zerem replik, dopóki nie ma digestu.
- [systemd-creds](https://www.freedesktop.org/software/systemd/man/systemd-creds.html).
  Wiążące jest pieczętowanie sekretu do układu maszyny, zamiast trzymania go w pliku obok.
  Dotyczy vTPM 2.0 i klucza rozszczelnienia, który opisze numer `14`. Ze źródła nie bierzemy
  wdrożenia OpenBao w tym numerze. Tu jest urządzenie `/dev/tpmrm0` i kopia stanu TPM. Bez
  tego urządzenia klucz wróciłby do pliku na dysku gościa.

## Gotowe gdy

- VM `jjdevhub` ma 4 vCPU, 16 GiB bez balonu, dysk 120 GiB, UEFI i vTPM, a
  `test -c /dev/tpmrm0` kończy się kodem 0.
- `kubectl get nodes` pokazuje jeden węzeł `Ready`.
- `kubectl get ingress -A` jest puste, a pody Traefika i ServiceLB nie istnieją.
- Postgres, Redis i Kafka w namespace `jjdevhub` są `Ready`, bazy z tabeli istnieją, Redis
  zwraca `PONG`.
- W git są manifesty z tabeli ścieżek, bez hasła i bez digestu obrazu aplikacji.
- Deploymenty aplikacji mają `replicas: 0` albo jeszcze nie są zastosowane; AppHost nie jest
  na klastrze.
- Harmonogram `vzdump` obejmuje dysk i stan TPM, a jedna kopia leży poza dyskiem tej VM.
- Z internetu porty 80, 443 i 6443 gościa nie przyjmują połączenia. Ostatnie da się
  sprawdzić z sieci spoza LAN poleceniem `nc -vz <adres-gościa> 443`, które ma się nie
  połączyć.
- k3s stoi z `--disable=traefik` i `--disable=servicelb`. Datastore to SQLite. Runtime to
  containerd.
- Postgres to `postgres:16-alpine`, PVC 40 GiB, port `5432`, dziesięć pustych baz. Redis to
  `emptyDir` i Service `cache` na `6379`. Kafka to KRaft, PVC 20 GiB, port `9092`.
- Sonar nie ma publicznego Service. Obraz aplikacji ma postać
  `ghcr.io/jtjaskulski/jjdevhub-<komponent>@sha256:<digest>`. `mobile` nie jest podem. YARP
  jest jedyną bramą HTTP.
