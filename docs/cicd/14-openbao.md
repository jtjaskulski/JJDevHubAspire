# 14. OpenBao

Ten numer stawia produkcyjny serwer sekretów na maszynie. Poprzedni numer,
[Grafana](13-grafana.md), daje operatorowi ekran metryk i śladów. Następny plik,
[skalowanie](15-skalowanie.md), podnosi drugi pod usługi. W kolejności pracy
następny jest [jądro](../api/05-kernel.md). Skalowanie czeka, aż staną usługi.
Skład deweloperski OpenBao jest w
[04-openbao.md](../api/04-openbao.md): tam jest port `ISecretReader`, tryb deweloperski i
token w user secrets laptopa. Ten plik jest produkcją. Adres, uwierzytelnienie i miejsce
klucza rozszczelnienia są inne. W repozytorium nie ma wartości sekretu i nie ma pliku z
sekretem zaszyfrowanym do odczytu w CI.

Scenariusz, który bez tego serwera się rozpada, zaczyna się od hasła do `news_write` w
zmiennej Deploymentu. `kubectl -n jjdevhub get deploy news -o yaml` pokazuje je każdemu, kto
ma kubeconfig. Ten sam literał wpada do historii gita, gdy ktoś „na chwilę” dopisze go do
manifestu, i do logu workflow, gdy krok wypisze środowisko. Hasło żyje tak długo, jak
namespace, i otwiera cudzą bazę, gdy pięć usług dostanie jeden ciąg. Na produkcji pod
zgłasza się tożsamością ServiceAccount. Dostaje poświadczenie swojej bazy z czasem życia.
Nie dostaje tokenu root i nie dostaje tokenu z laptopa.

Drugi scenariusz psuje się przy restarcie gościa. OpenBao wstaje zapieczętowany. Klucz leży
w pliku `/etc/openbao/unseal.key`, bo tak było najszybciej przy pierwszej inicjalizacji.
Kopia `vzdump` zabiera plik razem z dyskiem. `kubectl debug` z montowaniem hosta też go
zabiera. Ten numer ładuje klucz raz do `systemd-creds` z pieczęcią `--with-key=tpm2`. Jawna
treść pojawia się tylko w katalogu poświadczeń jednostki, na czas rozszczelnienia, i znika
razem z procesem. W git klucza nie ma wcale. Blob SOPS też nie powstaje: zaszyfrowany plik w
repozytorium jest sekretem, który da się otworzyć poza maszyną.

## Po co

Usługa na k3s potrzebuje haseł do własnej bazy zapisu i własnej bazy odczytu. Bazy są z
numeru 08: `identity_write`, `identity_read`, i tak dalej przez News, Learning, Cv i
Contact. Contact potrzebuje dodatkowo klucza wysyłki push na ścieżce `kv/data/contact/fcm`.
Hasło w manifeście kończy się w historii commitów. Token deweloperski z laptopa na maszynie
kończy się tym samym: jeden współdzielony sekret o długim życiu, ważny także wtedy, gdy pod
już nie jest tym podem, któremu go wklejono.

Każda z pięciu usług dostaje własną rolę OpenBao i własne dwie ścieżki
`database/creds/<k>-write` oraz `database/creds/<k>-read`. `<k>` jest nazwą usługi:
`identity`, `news`, `learning`, `cv`, `contact`. Rola `news` nie czyta
`database/creds/identity-write`. Rola zapisu w silniku bazy nie dostaje bazy odczytu: zdanie
SQL roli `news-write` nie zawiera nazwy `news_read`. Rola odczytu nie zawiera nazwy
`news_write`. Wyciek jednego poświadczenia nie otwiera sąsiedniej bazy ani drugiej bazy tej
samej usługi.

Brama ma rolę `gateway`, związaną z ServiceAccount `gateway` w namespace `jjdevhub`. Nie ma
bazy `gateway_write` ani `gateway_read`, więc nie dostaje ścieżek
`database/creds/gateway-write` i `database/creds/gateway-read`. Klucz publiczny JWT brama
bierze z dokumentu JWKS Identity, jak w [16-gateway.md](../api/16-gateway.md). Polityka
`gateway` nie wymienia cudzej bazy. Ścieżka materiału klucza w OpenBao dochodzi tylko wtedy,
gdy tamten numer świadomie odejdzie od JWKS. Ten plik jej nie wymyśla i nie wkłada do niej
klucza prywatnego.

`web` nie czyta OpenBao. Statyczny klient nie ma poświadczenia bazy. `mobile` nie jest podem
i roli nie dostaje. Wspólna rola „frontend” z dostępem do `contact-read` wynosiłaby
projekcję wiadomości do przeglądarki, która i tak woła tylko bramę.

Poświadczenie bazy żyje godzinę. Da się je odnowić do 24 godzin. Po tym czasie silnik
wystawia nowe. Stare hasło w logu poda przestaje otwierać bazę, bez przebudowy manifestu.
Konto techniczne, którym sam OpenBao łączy się z Postgresem, nie jedzie w manifeście. Jego
hasło jest w drugiej pieczęci systemd, `openbao-db`, pieczętowanej tak samo jak klucz
rozszczelnienia.

Klucz rozszczelnienia na maszynie jest tylko w pieczęci vTPM. Jednostka
`jjdevhub-openbao-unseal.service` stoi na gościu, poza git, z `After=k3s.service`. Po
starcie węzła rozszczelnia proces, zanim numer 16 uzna Deployment za gotowy do ruchu. Ręczne
wklejenie klucza z laptopa nie jest ścieżką zwykłego restartu. Token root służy do
inicjalizacji i jest unieważniany. Nie wchodzi do Deploymentu aplikacji i nie zostaje w
zmiennej `OPENBAO_TOKEN`.

## Dlaczego ta technologia

### OpenBao, licencja MPL-2.0

OpenBao jest serwerem sekretów na licencji MPL-2.0. API, którego używa klient w usługach, ma
ten sam kształt co numer deweloperski: adres, sposób wejścia, odczyt ścieżki. Na maszynie
serwer słucha tylko w klastrze, na `http://openbao.jjdevhub.svc.cluster.local:8200`. Port
jest ClusterIP. NodePort nie powstaje. Publicznego hostname nie ma w tunelu z numeru 09.
YARP nie dostaje trasy.

HashiCorp Vault odpada. Licencja BSL nie jest licencją otwartą, którą to repozytorium
przyjmuje na produkcję. Podmiana binarium przy zachowaniu komend `bao` byłaby właśnie tym
produktem, tylko pod inną nazwą w PATH. Trzymanie haseł w Secretcie Kubernetes bez czasu
życia odpada: Secret żyje tak długo jak namespace i łatwo go zrzucić do manifestu, tak jak
hasło Grafany wolno trzymać tylko dlatego, że numer 13 jest wcześniejszy i dotyczy jednego
konta UI, nie dziesięciu baz. Plik `.env` na hoście odpada z tego samego powodu co plik w
git, tylko wolniej: zostaje w kopii domowej i w historii powłoki.

Koszt zostaje świadomy. Osobny pod, PVC `5Gi`, procedura rozszczelnienia i polityki do
recenzji. Bez polityk serwer jest otwartym katalogiem: kto ma token, czyta wszystko.
Polityki są w git celowo. Mówią, kto co może czytać. Nie mówią, jaka jest wartość. Recenzja
pull requestu widzi dopisanie `identity-write` do polityki `news` i odrzuca je, zanim pod w
ogóle wstanie.

Konkret domeny jest negatywny i o to chodzi. OpenBao nie prowadzi czytelnika, rekrutera ani
właściciela. Nie zna roli `owner` i nie zna `student`. Nie zapisuje artykułu, lekcji ani
strony CV. Trzyma poświadczenie, którym usługa łączy się z Postgresem, oraz klucz push
Contactu. Kto włoży tu rejestr kont, zdubluje Identity i rozdzieli rolę na dwa produkty.

### Keycloak nie jest magazynem sekretów

Keycloak jest dostawcą tożsamości. Konta, role `owner` i `student` oraz klucz JWT należą do
usługi Identity. Postawienie Keycloaka obok Identity dubluje użytkownika: jedno konto w
bazie `identity_write`, drugie w osobnym produkcie, i dwie odpowiedzi na pytanie, kto jest
właścicielem. OpenBao nie naprawia tego dubla, bo nie jest rejestrem osób.

Odrzucenie Keycloaka nie wynika z braku logowania w OpenBao. OpenBao nie prowadzi
czytelnika. Prowadzi poświadczenie bazy. Zamiana „hasło Postgresa trzymamy w Keycloaku, bo i
tak mamy logowanie” myli dwa życia sekretu: życie logowania osoby i życie połączenia usługi.
To drugie ma godzinę i odnowienie do doby. To pierwsze jest numerem Identity w `docs/api`.

Koszt zostaje po stronie Identity. JWT, zaproszenie i rola są jej numerem. Ten plik nie
definiuje polityki haseł człowieka i nie wystawia strony logowania. Jeśli numer Identity
zechce, żeby materiał klucza publicznego leżał poza bazą, ścieżka może dojść później. Nie
dochodzi tu jako rejestr użytkowników i nie dochodzi jako drugi issuer JWT.

### Klucz rozszczelnienia w vTPM

Inicjalizacja daje jeden klucz i jeden próg. Polecenie to
`bao operator init -key-shares=1 -key-threshold=1`. Operator jest jeden, maszyna jest jedna.
Próg wyższy niż jeden, przy jednym udziale, nie da się spełnić. Pięć udziałów Shamira bez
pięciu osób zostawia cztery kopie, które i tak lądują u tego samego operatora, często w tym
samym sejfie, i udaje rozproszenie. Udział jest jeden. Druga kopia tego samego klucza leży
offline, poza VM i poza git, w sejfie operatora. To nie jest drugi udział. To kopia na
wypadek utraty vTPM. Bez niej awaria TPM jest końcem odczytu magazynu.

Operator przekazuje klucz raz do `systemd-creds`, z pieczęcią na TPM 2.0 gościa:
`--with-key=tpm2`. Zaszyfrowany blok leży w magazynie poświadczeń systemd na dysku. Jawna
treść pojawia się w `$CREDENTIALS_DIRECTORY` tylko na czas procesu jednostki. Wejście
polecenia szyfrującego jest ze standardowego wejścia, ze schowka operatora, i nie zostaje w
argumencie widocznym w `ps`.

Jawny plik `/etc/openbao/unseal.key` odpada. Każda kopia dysku i każdy pod debug z
montowaniem hosta wynosi klucz w postaci, którą przyjmuje `bao operator unseal`. Sekret w
git, także zaszyfrowany narzędziem typu SOPS, odpada. Blob w repozytorium da się otworzyć na
laptopie, poza pieczęcią tej VM. `git grep` po `sops:` i brak plików `*.sops.*` oraz
`*.enc.yaml` są sprawdzeniem tego zakazu, nie ozdobą. Automatyczne rozszczelnienie kluczem z
chmurowego KMS odpada razem z chmurą publiczną.

Koszt jest ostry i jest wypisany wprost. Utrata vTPM i utrata kopii offline oznacza utratę
odczytu magazynu OpenBao. Kopia `vzdump` z numeru 08 obejmuje stan TPM, więc odtworzenie
całej VM na tym samym materiale TPM odtwarza pieczęć. Odtworzenie samego dysku, bez stanu
TPM, jej nie odtwarza. Operator nie obchodzi tego przez wstawienie klucza do ConfigMap „na
czas naprawy”.

Jednostka `jjdevhub-openbao-unseal.service` jest typu oneshot, `After=k3s.service`, z
`LoadCredentialEncrypted`. Stoi na gościu, nie w repozytorium, bo obok niej leży magazyn
pieczęci. W git jest nazwa jednostki i kroki. Brak pliku na świeżo postawionej VM widać od
razu: pod zostaje zapieczętowany, a usługi nie dostają baz. Timer albo `WantedBy` po starcie
k3s odpala ją przy każdym boocie. Ręczne rozszczelnienie z laptopa nie jest ścieżką zwykłego
restartu.

### Uwierzytelnienie Kubernetes, nie token w zmiennej

Metoda `kubernetes` ufa tokenowi ServiceAccount podpisanemu przez API k3s. Rola `news` jest
związana z kontem `news` w namespace `jjdevhub` i z polityką `news`. Czas życia tokenu
logowania to godzina. Pod nie dostaje tego tokenu w zmiennej. Dostaje go z API kubeleta, a
klient wymienia go w OpenBao na token o polityce tej roli.

Token root wpisany do Deploymentu odpada. To jest długowieczny klucz do wszystkiego i
powtórka układu deweloperskiego w miejscu, które ma być węższe. Po krokach inicjalizacji
operator woła `bao token revoke` na token root. Dalsza praca idzie tokenem o polityce
węższej albo nowym tokenem root wystawionym z klucza tylko wtedy, gdy naprawdę trzeba. Ten
nowy token też nie wchodzi do Deploymentu. `kubectl -n jjdevhub get deploy,sts -o yaml` nie
zawiera tokenu root.

Wspólne konto usługi dla pięciu Deploymentów odpada. Polityka musiałaby dawać każdej usłudze
cudze bazy, a usługa nie otwiera bazy sąsiada. Zmiana nazwy ServiceAccount wymaga zmiany
roli. To jest widoczne w git, w pliku polityki i w poleceniu
`bao write auth/kubernetes/role/…`. Cicha zmiana konta na `default` oddaje token, który
recenzuje się zbyt szeroko, i jest błędem tego numeru.

Koszt jest przy pierwszym starcie klastra. Trzeba raz związać OpenBao z API k3s: adres,
certyfikat CA, konto `openbao-auth`, któremu wolno recenzować tokeny. To konto nie jest
kontem `news` i nie jest tokenem root zostawionym w podzie. Konfiguracja metody powstaje w
tej samej pracy operatora co polityki, zanim token root zostanie unieważniony.

Token deweloperski z user secrets laptopa na ten serwer nie działa i nie jest kopiowany.
Inny magazyn, inna pieczęć, metoda `kubernetes` zamiast statycznego tokenu w zmiennej. Próba
`bao kv list` z tym tokenem przeciw `OPENBAO_ADDR` produkcji kończy się odmową. AppHost woła
OpenBao deweloperskie z numeru 04, nie ten Service.

### Krótkotrwałe poświadczenie bazy

Silnik `database` jest podłączony do Postgresa z numeru 08, na
`postgres.jjdevhub.svc.cluster.local:5432`, kontem technicznym. Hasło tego konta pochodzi z
pieczęci `openbao-db`, nie z manifestu i nie z ConfigMap. Dla każdej z dziesięciu baz jest
rola dynamiczna: `identity-write`, `identity-read`, i tak dalej przez News, Learning, Cv i
Contact. `default_ttl` to `1h`. `max_ttl` to `24h`. Rola ma `CONNECT` i prawa do tabel
wyłącznie w swojej bazie.

Jedno hasło Postgresa w `ConnectionStrings__Write` na rok odpada. Wyciek z logu albo ze
zrzutu poda żyje, dopóki ktoś nie przebuduje manifestu i nie zmieni hasła w bazie ręcznie.
Nadawanie haseł w `psql` i wklejanie ich do Secreta odpada, bo nie ma czasu życia i łatwo
pomylić `news_read` z `identity_write`. Rola `news-write`, której SQL wymienia `news_read`,
jest tym pomyłką wpisaną na stałe. Sprawdzenie po `bao read database/creds/news-write`
loguje się do `news_write` i nie loguje się do `news_read`.

Koszt jest po stronie klienta. Aplikacja musi umieć odnowić dzierżawę i przebudować
połączenie. To zachowanie jest opisane przy OpenBao deweloperskim. Ten numer wystawia
silnik, z którego ten klient czyta. Nie pisze klienta drugi raz. Restart OpenBao po
wygaśnięciu dzierżawy, przy braku rozszczelnienia, zatrzymuje nowe połączenia. Stare
połączenie Postgresa działa do końca życia puli. Dlatego rozszczelnienie po starcie węzła
jest częścią jednostki systemd, a nie czynnością „kiedyś ręcznie”.

Dwa pody tej samej usługi, gdy dojdzie numer 15, używają tej samej roli i dostają osobne
dzierżawy. Ten numer nie nadaje im wspólnego hasła w zmiennej. Wspólne hasło wraca do
układu, który właśnie zdejmujemy. Osobna dzierżawa na pod oznacza, że zrzut jednego procesu
nie oddaje hasła drugiego, a odwołanie jednej dzierżawy nie wymaga przebudowy Deploymentu.

Ścieżka KV v2 dla Contactu to mount `kv`, sekret `contact/fcm`, a w polityce
`kv/data/contact/fcm`. Wartość wstawia operator po rozszczelnieniu, z maszyny, poleceniem
klienta. Wartość nie powstaje w pliku repozytorium. Puste pole w git nie udaje sekretu.
Polityka `news` tej ścieżki nie zawiera. Klucz push nie jest hasłem bazy i nie jedzie w
`creation_statements`.

### Jeden węzeł i magazyn zintegrowany

OpenBao trzyma dane we własnym magazynie zintegrowanym, na PVC `5Gi`, jedna replika. W
`config.hcl` magazynem jest `raft` z katalogiem na tym wolumenie. Drugiego węzła nie ma, bo
maszyna jest jedna. `retry_join` do sąsiada, którego nie ma, zostawia proces w pętli
łączenia i probe, które i tak akceptuje zapieczętowanie, nie naprawi braku kworum. Jeden
węzeł jest świadomym sufitem, tym samym co jedna replika Postgresa.

Magazyn plikowy jako osobny, starszy backend odpada wobec magazynu zintegrowanego: dwa
sposoby zapisu na jednym PVC, a procedura rozszczelnienia jest opisana dla jednego.
Współdzielenie tabel sekretów w bazie którejś usługi odpada. Sekret nie miesza się ze
strumieniem artykułu. Zrzut `news_write` nie może być zrzutem kluczy. Awaria PVC jest awarią
sekretów. Kopia jest kopią VM, razem ze stanem TPM. Eksport jawny do pliku w katalogu
domowym operatora na tej samej maszynie odpada. To jest ten sam błąd co `unseal.key`, tylko
z całą zawartością magazynu.

`tls_disable` na listenerze jest dopuszczalne wyłącznie wewnątrz namespace. Odcinek
pod–OpenBao nie opuszcza `jjdevhub`. Publicznego hostname nie ma, więc nie ma terminatora
TLS do wystawienia i nie ma powodu udawać, że port 8200 jest publiczny. Włączenie TLS z
certyfikatem w git, albo wyłączenie TLS na NodePort, jedno i drugie jest poza tym numerem.
UI, jeśli obraz je ma, zostaje na tym samym ClusterIP i nie wchodzi do tunelu.

Probe woła `/v1/sys/health`. Stan zapieczętowania jest stanem przyjętym: parametr
`sealedcode=200` sprawia, że odpowiedź zapieczętowanego, a już zainicjowanego procesu nie
jest porażką próby. Bez tego kubelet widzi odmowę i restartuje pod, zanim jednostka systemd
zdąży podać klucz. Niezainicjowany proces nie jest tym stanem. Inicjalizacja jest
jednorazową pracą operatora. Pętla restartu przed `bao operator init` jest widoczna i nie
jest mylona z czekaniem na pieczęć.

Żądania procesu to 100m CPU i 256 MiB pamięci. Obraz jest digestem. HPA OpenBao nie dotyczy.
Drugi pod na jednym PVC magazynu zintegrowanego nie jest skalowaniem, jest uszkodzeniem
kworum, którego i tak nie ma sensu budować na jednej maszynie.

## Klasy i ścieżki

| Ścieżka | Odpowiedzialność |
| --- | --- |
| `deploy/k3s/openbao/statefulset.yaml` | Jedna replika, PVC `5Gi`, Service ClusterIP `:8200`, konto `openbao` |
| `deploy/k3s/openbao/config.hcl` | Listener, magazyn zintegrowany na PVC, UI tylko na ClusterIP |
| `deploy/k3s/openbao/policies/*.hcl` | Jedna polityka na komponent z rolą, bez wartości sekretów |
| `deploy/k3s/openbao/auth-kubernetes.md` | Kroki wiązania metody `kubernetes`; plik nie zawiera tokenu |
| `/etc/systemd/system/jjdevhub-openbao-unseal.service` | Jednostka na gościu, poza git, `After=k3s.service` |
| magazyn `systemd-creds` na gościu | Zapieczętowany klucz rozszczelnienia i pieczęć `openbao-db`, poza git |

Polityki w git są jawne celowo. Mówią, kto co może czytać. Nie mówią, jaki jest sekret.

| Rola OpenBao | ServiceAccount | Ścieżki |
| --- | --- | --- |
| `identity` | `identity` | `database/creds/identity-write`, `database/creds/identity-read` |
| `news` | `news` | `database/creds/news-write`, `database/creds/news-read` |
| `learning` | `learning` | `database/creds/learning-write`, `database/creds/learning-read` |
| `cv` | `cv` | `database/creds/cv-write`, `database/creds/cv-read` |
| `contact` | `contact` | `database/creds/contact-write`, `database/creds/contact-read`, `kv/data/contact/fcm` |
| `gateway` | `gateway` | brak ścieżek `database/creds/gateway-write` i `database/creds/gateway-read` |

`web` i `mobile` nie mają roli. Nie ma wiersza, który dałby im bazę.

Polityka `news`, wzór dla czterech pozostałych usług z dwiema bazami:

```hcl
path "database/creds/news-write" {
  capabilities = ["read"]
}

path "database/creds/news-read" {
  capabilities = ["read"]
}
```

Polityka `contact` ma te dwie ścieżki swoich baz i trzecią:

```hcl
path "kv/data/contact/fcm" {
  capabilities = ["read"]
}
```

Polityka `gateway` nie zawiera ścieżek `database/creds/`. Plik wolno zostawić bez ścieżki
sekretu, dopóki brama bierze klucz publiczny z JWKS. Dopisanie `database/creds/news-write`
do tego pliku jest błędem recenzji, nie „ułatwieniem dla bramy”.

Listener i magazyn:

```hcl
ui = true

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}

storage "raft" {
  path = "/openbao/data"
}

api_addr = "http://openbao.jjdevhub.svc.cluster.local:8200"
```

`tls_disable` jest tu dlatego, że listener nie wychodzi z namespace. Nie jest zgodą na
publikację portu. W bloku `storage` nie ma `retry_join`. Katalog `/openbao/data` jest
montowaniem PVC `5Gi`. UI zostaje na tym samym porcie ClusterIP.

Probe, który przyjmuje stan zapieczętowania:

```yaml
readinessProbe:
  httpGet:
    path: /v1/sys/health?sealedcode=200
    port: 8200
livenessProbe:
  httpGet:
    path: /v1/sys/health?sealedcode=200
    port: 8200
```

Deployment usługi, gdy numer 16 podnosi repliki, dostaje adres i metodę. Nie dostaje tokenu
i nie dostaje hasła bazy.

```yaml
- name: OPENBAO_ADDR
  value: http://openbao.jjdevhub.svc.cluster.local:8200
- name: OPENBAO_AUTH
  value: kubernetes
```

Nazwy zmiennych mają być zgodne z klientem z numeru deweloperskiego. Jeśli tamten numer użył
innych nazw, produkcja używa tych samych. Znaczenie zostaje: adres Service i metoda
`kubernetes`. Zmiennej `OPENBAO_TOKEN` nie ma.

Jednostka na gościu, poza repozytorium, ma co najmniej taki kształt. Program w `ExecStart`
czyta `$CREDENTIALS_DIRECTORY/unseal` i woła rozszczelnienie. Po sukcesie proces się kończy.

```ini
[Unit]
Description=Rozszczelnienie OpenBao JJDevHub
After=k3s.service

[Service]
Type=oneshot
LoadCredentialEncrypted=unseal:/etc/credstore.encrypted/jjdevhub-openbao-unseal.service/unseal
ExecStart=/usr/local/sbin/jjdevhub-openbao-unseal
RemainAfterExit=yes

[Install]
WantedBy=k3s.service
```

Ścieżka programu jest na gościu. Nie jest ścieżką w git. Skrypt nie wypisuje klucza na
stdout. Nie zapisuje go do `/tmp`. Drugie poświadczenie, `openbao-db`, jest osobną
pieczęcią, czytaną tylko przez proces OpenBao przy połączeniu silnika `database`, nie przez
jednostki usług.

## Plan

### 1. Pod

Zastosuj StatefulSet. Obraz przypięty do digestu. Port 8200, ClusterIP, bez NodePort.
Konfiguracja z `config.hcl`: magazyn `raft` na PVC `5Gi`, `tls_disable` tylko na tym
listenerze, jedna replika, bez `retry_join`. Żądania: 100m CPU, 256 MiB pamięci. Probe
gotowości i żywości wołają `/v1/sys/health?sealedcode=200`. UI nie wchodzi do tunelu i nie
dostaje trasy YARP.

### 2. Inicjalizacja raz

Z `kubectl exec` na żywym podzie, przy pierwszej instalacji:

```bash
bao operator init -key-shares=1 -key-threshold=1
```

Wyjście, klucz rozszczelnienia i token root, nie jest przekierowywane do pliku w katalogu
domowym. Operator od razu ładuje klucz do pieczęci:

```bash
sudo systemd-creds encrypt --with-key=tpm2 --name=openbao-unseal - \
  /etc/credstore.encrypted/jjdevhub-openbao-unseal.service/unseal
```

Wejście jest ze standardowego wejścia. Token root zostaje w pamięci tej pracy operatora do
końca kroków 3 i 4. Potem:

```bash
bao token revoke
```

na ten token. Token root nie wchodzi do Deploymentu aplikacji. Kopia klucza offline idzie do
sejfu operatora, poza VM i poza git.

### 3. Jednostka rozszczelnienia

Umieść `jjdevhub-openbao-unseal.service` na gościu. `After=k3s.service`.
`LoadCredentialEncrypted` wskazuje blok z kroku 2. Włącz start razem z k3s. Nie commituj
jednostki i nie commituj katalogu `credstore.encrypted`. Po reboocie jednostka ma się
skończyć kodem 0, a `bao status` ma pokazać magazyn otwarty.

### 4. Metoda kubernetes

Włącz auth `kubernetes`. Ustaw host API k3s, certyfikat CA i konto `openbao-auth`, któremu
wolno recenzować tokeny. Dla każdego wiersza tabeli ról powtórz zapis roli. Wzór:

```bash
bao write auth/kubernetes/role/news \
  bound_service_account_names=news \
  bound_service_account_namespaces=jjdevhub \
  policies=news \
  ttl=1h
```

To samo dla `identity`, `learning`, `cv`, `contact` i `gateway`. Polityka `news` zawiera
wyłącznie dwie ścieżki baz News. Polityka `gateway` nie zawiera ścieżek `database/creds/`.

### 5. Silnik bazy

Włącz silnik `database` na ścieżce `database`. Połączenie do
`postgres.jjdevhub.svc.cluster.local:5432` używa konta technicznego. Hasło wczytaj z
pieczęci `openbao-db`, utworzonej tym samym `--with-key=tpm2` co klucz rozszczelnienia. W
manifeście tego hasła nie ma.

Dla każdej z dziesięciu baz utwórz rolę dynamiczną o `default_ttl=1h` i `max_ttl=24h`.
Zdanie SQL tworzy użytkownika i nadaje mu prawa tylko w tej bazie. Rola `news-write` nie
zawiera nazwy `news_read`. Sprawdzenie:

```bash
bao read database/creds/news-write
```

Zwraca nazwę użytkownika i hasło o czasie dzierżawy. Tych wartości nie zapisuj w pliku.
Zamknij dzierżawę po teście:

```bash
bao lease revoke <lease_id>
```

Ścieżka KV v2 `kv/contact/fcm` powstaje dla Contact. W polityce odczyt jest na
`kv/data/contact/fcm`. Wartość klucza push wstawia operator. Puste pole w git nie udaje
sekretu.

### 6. Adres w Deploymentach aplikacji

Gdy numer 16 podnosi repliki, Deployment dostaje `OPENBAO_ADDR` i `OPENBAO_AUTH=kubernetes`,
jak w bloku wyżej. Nie dostaje `OPENBAO_TOKEN`. Nie dostaje connection stringa z hasłem. Nie
kopiuj tokenu z user secrets laptopa.

### Co jest do czego

| Element | Po co istnieje | Kto go woła |
| --- | --- | --- |
| StatefulSet `openbao` | Proces sekretów | Pody usług przez Service |
| PVC `5Gi` | Magazyn zintegrowany | Proces OpenBao |
| `jjdevhub-openbao-unseal.service` | Rozszczelnienie po starcie węzła | systemd gościa |
| Pieczęć TPM `openbao-unseal` | Jedyna kopia klucza na maszynie | `systemd-creds` przy starcie jednostki |
| Pieczęć `openbao-db` | Hasło konta technicznego silnika bazy | Proces OpenBao |
| Metoda `kubernetes` | Tożsamość poda | Klient w usłudze |
| `policies/*.hcl` | Granica ścieżek | Rola przy logowaniu |
| Silnik `database` | Hasło bazy na godzinę, odnowienie do 24 godzin | Usługa przy starcie i przy odnowieniu |
| `kv/data/contact/fcm` | Klucz push | Tylko Contact |
| Token root | Jednorazowa inicjalizacja | Operator, potem unieważnienie |

StatefulSet woła kubelet. Gdy go nie ma, usługi nie mają adresu, pod którym wymienią token
ServiceAccount na poświadczenie bazy. Pod z tokenem root w środowisku wstaje i oddaje cały
magazyn każdemu, kto czyta specyfikację.

PVC woła proces jako katalog `raft`. Eksport tego katalogu do pliku w `/home` na gościu
wynosi magazyn poza pieczęć operacyjną jednostki. Kopia VM zostaje kopią całego gościa, nie
zrzutem jawnych kluczy.

Jednostka systemd woła API rozszczelnienia po starcie k3s. Gdy jej nie ma, probe przyjmuje
stan zapieczętowania i pod żyje, ale nowe połączenia do baz nie powstają. To jest widoczne w
`bao status`, nie w tym, że kontener ma status Running.

Metoda `kubernetes` woła klient usługi. Gdy zamiast niej jest `OPENBAO_TOKEN`, każdy pod,
który ten token dostanie, ma zakres tokenu, nie zakres swojej roli. Token deweloperski w tej
zmiennej na produkcji jest odmową albo, co gorsza, trafieniem w inny serwer, jeśli adres
został pomylony z laptopem.

Polityka `news` woła serwer przy logowaniu konta `news`. Odczyt `identity-write` tą rolą
kończy się odmową. Odczyt `news-write` kończy się dzierżawą. Dzierżawa nie jest plikiem. Po
teście jest zamykana.

Silnik `database` woła Postgres kontem technicznym. Hasło tego konta nie leży w ConfigMap.
Rola `news-write` woła `news_write`. Nie woła `news_read`. Contact jako jedyny woła
dodatkowo `kv/data/contact/fcm`.

AppHost woła OpenBao deweloperskie z numeru 04, nie ten Service. Numer 16 nie wstrzykuje
hasła bazy przy podmianie obrazu.

## Testy

1. Po reboocie gościa pod przechodzi ze stanu zapieczętowanego do rozszczelnionego bez
ręcznego wklejania klucza. Powód padnięcia: magazyn zostaje zapieczętowany albo jednostka
kończy się błędem.

```bash
kubectl -n jjdevhub exec statefulset/openbao -- bao status
systemctl status jjdevhub-openbao-unseal.service
```

Pole zapieczętowania mówi, że magazyn jest otwarty. Jednostka jest `inactive (dead)` po
sukcesie oneshot albo `active (exited)` z kodem 0, zależnie od wersji systemd, i nie jest w
stanie błędu.

2. Na dysku gościa nie ma jawnego klucza. Powód padnięcia: plik, którego treść przyjmuje
`bao operator unseal`, leży w drzewie gościa.

```bash
sudo find /etc /var /opt /home -name 'unseal.key' -o -name '*unseal*.txt' 2>/dev/null
```

Wynik jest pusty. Katalog `credstore.encrypted` zawiera blok, którego `strings` nie pokazuje
jako klucza w postaci przyjmowanej przez `bao operator unseal`.

3. Rola `news` nie czyta bazy Identity. Powód padnięcia: polityka albo rola dynamiczna sięga
poza własne bazy. Z tokenu uzyskanego jako ServiceAccount `news`:

```bash
bao read database/creds/identity-write
bao read database/creds/news-write
```

Pierwsze kończy się odmową. Drugie kończy się sukcesem. Hasło z tego odczytu loguje się do
`news_write` i nie loguje się do `news_read` ani do `identity_write`. Po sprawdzeniu
dzierżawa jest zamykana `bao lease revoke`. Wartość nie zostaje w pliku i nie zostaje w logu
przebiegu.

4. W repozytorium nie ma blobu sekretu. Powód padnięcia: plik SOPS, plik zaszyfrowany albo
literał klucza leży w drzewie.

```bash
git grep -n -E 'sops:|unseal_keys|role_id|secret_id' -- ':!docs' || true
find . -name '*.sops.*' -o -name '*.enc.yaml' | grep -v node_modules || true
```

Wynik jest pusty. Polityki HCL w `deploy/k3s/openbao/policies/` są dozwolone. Nie zawierają
wartości poświadczenia.

5. Token root nie występuje w manifeście podów. Powód padnięcia: `OPENBAO_TOKEN` albo
wartość tokenu root jest w YAML.

```bash
kubectl -n jjdevhub get deploy,sts -o yaml
```

W wyjściu nie ma tokenu root i nie ma hasła konta technicznego. Jest `OPENBAO_ADDR` i
`OPENBAO_AUTH` równe `kubernetes`, gdy Deployment aplikacji już istnieje. Brak tych dwóch
zmiennych przed pierwszym deployem z numeru 16 nie jest błędem tego numeru. Obecność
`OPENBAO_TOKEN` jest błędem od razu.

6. Port nie jest otwarty na gościu. Powód padnięcia: z sieci spoza LAN da się połączyć na
8200. `nc -vz <adres-gościa> 8200` nie łączy. Publicznego hostname OpenBao nie ma w tunelu.
YARP nie ma trasy na ten Service.

7. Token deweloperski z laptopa jest odrzucony. Powód padnięcia: ten sam token, który działa
przy `aspire run`, dostaje odpowiedź sukcesu z `OPENBAO_ADDR` produkcji. Sprawdzenie:
`bao kv list` z tym tokenem przeciw adresowi produkcji kończy się odmową. Token nie jest
przy tym kopiowany do Secreta na maszynie.

8. Rola `gateway` nie dostaje baz. Powód padnięcia: `bao read database/creds/gateway-write`
jako ta rola kończy się sukcesem albo polityka w git wymienia
`database/creds/gateway-write`. `web` i `mobile` nie mają roli w `auth/kubernetes/role`.

9. Czas życia poświadczenia. Powód padnięcia: `default_ttl` roli `news-write` nie jest
godziną albo `max_ttl` przekracza 24 godziny. Odczyt `bao read database/creds/news-write`
pokazuje dzierżawę w tym oknie. SQL roli nie zawiera nazwy bazy odczytu.

## Zasady

- Serwerem sekretów produkcji jest OpenBao na licencji MPL-2.0. Vault nie wchodzi. Keycloak
  nie wchodzi.
- Adres to `http://openbao.jjdevhub.svc.cluster.local:8200` i tylko ClusterIP. NodePort,
  trasa YARP i hostname w tunelu nie powstają.
- Klucz rozszczelnienia na maszynie jest tylko w pieczęci `systemd-creds` na vTPM,
  `--with-key=tpm2`.
- Inicjalizacja to `-key-shares=1 -key-threshold=1`. Drugi udział nie jest zastępstwem kopii
  offline.
- Jawny klucz na dysku nie powstaje. Plik sekretu w git nie powstaje. Blob SOPS w git nie
  powstaje.
- Jednostka `jjdevhub-openbao-unseal.service` jest poza git, z `After=k3s.service`, i
  rozszczelnia proces po starcie węzła.
- Token root jest unieważniany po inicjalizacji. Nie jest zmienną poda. `OPENBAO_TOKEN` nie
  występuje.
- Wejście aplikacji to `OPENBAO_ADDR` i `OPENBAO_AUTH=kubernetes`. Token deweloperski z
  laptopa jest odrzucany.
- Role to `identity`, `news`, `learning`, `cv`, `contact` i `gateway`. Każda jest związana
  ze swoim ServiceAccount w `jjdevhub`.
- Pięć usług ma własne ścieżki `database/creds/<k>-write` i `database/creds/<k>-read`. Rola
  nie wymienia cudzej bazy.
- Rola `gateway` nie dostaje `database/creds/gateway-write` ani
  `database/creds/gateway-read`.
- Contact dodatkowo czyta `kv/data/contact/fcm`. Inna rola tej ścieżki nie dostaje.
- `web` i `mobile` nie dostają roli bazy.
- Poświadczenie bazy żyje godzinę i da się je odnowić do 24 godzin. Rola zapisu nie dostaje
  bazy odczytu.
- Hasło konta technicznego silnika `database` jest w pieczęci `openbao-db`, nie w ConfigMap
  i nie w manifeście.
- Jedna replika, PVC `5Gi`, magazyn zintegrowany `raft`. HPA OpenBao nie dotyczy.
- `tls_disable` jest tylko na listenerze wewnątrz namespace.
- Probe `/v1/sys/health` przyjmuje stan zapieczętowania, żeby kubelet nie zrestartował poda
  przed jednostką.
- Polityka w git opisuje ścieżkę. Nie opisuje wartości.
- Układ deweloperski z [04-openbao.md](../api/04-openbao.md) zostaje na laptopie. Ten token
  na VM nie działa i nie jest kopiowany.

## Poza zakresem

- VM, vTPM jako urządzenie i kopia `vzdump` są w [08-proxmox.md](08-proxmox.md). Ten numer
  używa vTPM. Nie tworzy go i nie zmienia rozmiaru dysku gościa.
- Postgres i puste bazy są w [08-proxmox.md](08-proxmox.md). Schemat tabel jest w numerach
  persistence w `docs/api`. Ten numer nie tworzy tabeli. Tworzy rolę, która dostanie prawa w
  bazie już nazwanej.
- OpenBao przy `aspire run`, port `ISecretReader` i token w user secrets są w
  [04-openbao.md](../api/04-openbao.md). Ten numer nie zmienia składu laptopa.
- Konta, role JWT i zaproszenia są w usłudze Identity. OpenBao nie prowadzi rejestru
  użytkowników i nie zastępuje Keycloaka, którego tu nie ma.
- Klucz FCM jako produkt push jest w [07-powiadomienia.md](../frontend/07-powiadomienia.md)
  i w numerze Contact. Tu jest tylko ścieżka `kv/data/contact/fcm` i zakaz wstawienia
  wartości do git.
- Tunel jest w [09-cloudflare.md](09-cloudflare.md). Port 8200 do tunelu nie wchodzi.
- Drugi pod usługi jest w [15-skalowanie.md](15-skalowanie.md). Oba pody używają tej samej
  roli i dostają osobne dzierżawy. Ten numer nie ustawia `maxReplicas`.
- Rollout obrazu jest w [16-deploy.md](16-deploy.md). Deploy nie wstrzykuje hasła bazy i nie
  restartuje tego StatefulSet przy tagu News.
- Wykresy są w [13-grafana.md](13-grafana.md). Hasło Grafany wolno później przenieść na
  ścieżkę KV. Nie jest to warunek zamknięcia tego numeru.
- Bramka JWT zostaje przy JWKS Identity. Ten numer nie przenosi klucza prywatnego do
  polityki `gateway`.

## Źródła

- [Dokumentacja OpenBao](https://openbao.org/docs/). Wiążący jest serwer sekretów z API
  ścieżek, tokenów i silników, na licencji otwartej projektu. Dotyczy decyzji, że produkcja
  i laptop mówią tym samym kształtem adresu i odczytu, przy innym adresie i innym wejściu.
  Ze źródła nie bierzemy katalogu silników, których ten numer nie włącza. Nie bierzemy też
  wystawienia UI na hostname publiczny.
- [Rozszczelnienie](https://openbao.org/docs/concepts/seal/). Wiążące są klucz, próg
  udziałów i to, że zapieczętowany magazyn nie wydaje poświadczeń. Dotyczy
  `bao operator init -key-shares=1 -key-threshold=1` oraz jednostki, która woła
  rozszczelnienie po starcie k3s. Ze źródła nie bierzemy progu, którego jeden operator nie
  ma kim spełnić, i nie bierzemy klucza w jawnym pliku na dysku.
- [Auth Kubernetes](https://openbao.org/docs/auth/kubernetes/). Wiążące jest związanie roli
  z nazwą ServiceAccount i namespace oraz z polityką. Dotyczy ról `identity`, `news`,
  `learning`, `cv`, `contact` i `gateway`, `ttl=1h` oraz konta `openbao-auth` do recenzji
  tokenów. Ze źródła nie bierzemy tokenu root w Deploymentcie i nie bierzemy jednego konta
  dla pięciu usług.
- [Silnik database](https://openbao.org/docs/secrets/databases/). Wiążące jest krótkotrwałe
  poświadczenie wystawiane na ścieżce `database/creds/`. Dotyczy dziesięciu ról,
  `default_ttl=1h`, `max_ttl=24h` i zakazu wklejania hasła do zmiennej. Ze źródła nie
  bierzemy statycznego hasła na rok i nie bierzemy roli, która w SQL wymienia cudzą bazę.
- [`systemd-creds`](https://www.freedesktop.org/software/systemd/man/systemd-creds.html).
  Wiążące są `--with-key=tpm2` oraz `LoadCredentialEncrypted=`. Dotyczy pieczęci klucza
  rozszczelnienia i drugiej pieczęci `openbao-db`. Ze źródła nie bierzemy jawnego pliku
  klucza i nie bierzemy trzymania odszyfrowanej treści po zakończeniu procesu jednostki.
- [Kubernetes ServiceAccount](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/).
  Wiążący jest token, którym pod przedstawia się API k3s i który metoda `kubernetes`
  recenzuje. Dotyczy kont `identity`, `news`, `learning`, `cv`, `contact`, `gateway` i
  `openbao-auth`. Ze źródła nie bierzemy wklejenia tego tokenu do `OPENBAO_TOKEN` i nie
  bierzemy konta `default` jako roli usługi.
- [Licencja OpenBao](https://github.com/openbao/openbao/blob/main/LICENSE). Wiążące jest
  MPL-2.0 w pliku LICENSE projektu. Dotyczy wyboru serwera sekretów produkcji. Ze źródła nie
  bierzemy HashiCorp Vault i licencji BSL. Zmiana binarium na Vault przy tych samych
  komendach nie jest tym numerem.
- [MPL-2.0](https://www.mozilla.org/en-US/MPL/2.0/). Wiążący jest tekst licencji, na którą
  wskazuje repozytorium OpenBao. Dotyczy procesu na własnej maszynie. Ze źródła nie bierzemy
  wykładni dla kodu usług JJDevHub. Usługi mają własne pozycje na liście licencji. Ten plik
  dotyczy serwera sekretów.
- [Magazyn zintegrowany](https://openbao.org/docs/configuration/storage/raft/). Wiążący jest
  jeden węzeł `raft` z katalogiem na dysku. Dotyczy PVC `5Gi`, jednej repliki i braku
  `retry_join`. Ze źródła nie bierzemy klastra trzech węzłów na jednej maszynie i nie
  bierzemy trzymania sekretów w tabelach bazy usługi.
- [PostgreSQL w silniku database](https://openbao.org/docs/secrets/databases/postgresql/).
  Wiążące są `creation_statements`, połączenie kontem technicznym i osobna rola na bazę.
  Dotyczy ról `*-write` i `*-read` oraz hasła konta technicznego z pieczęci `openbao-db`. Ze
  źródła nie bierzemy jednego użytkownika Postgresa wpisanego w Deployment i nie bierzemy
  roli zapisu, która dostaje bazę odczytu.
- [KV v2](https://openbao.org/docs/secrets/kv/kv-v2/). Wiążąca jest ścieżka danych
  `kv/data/…` przy mount `kv`. Dotyczy `kv/data/contact/fcm` i tego, że wartość wstawia
  operator, nie plik w git. Ze źródła nie bierzemy tej ścieżki w polityce News i nie
  bierzemy KV jako magazyn haseł wszystkich baz. Bazy idą silnikiem `database`.
- [Polityki](https://openbao.org/docs/concepts/policies/). Wiążące jest jawne wymienienie
  ścieżek i możliwości, bez wartości sekretu. Dotyczy plików `policies/*.hcl` i recenzji,
  która widzi dopisanie cudzej bazy. Ze źródła nie bierzemy polityki `root` przypiętej do
  ServiceAccount usługi.
- [Inicjalizacja](https://openbao.org/docs/commands/operator/init/). Wiążące są
  `-key-shares` i `-key-threshold` oraz to, że wyjście zawiera klucz i token root. Dotyczy
  jednego udziału, jednego progu i zakazu przekierowania wyjścia do pliku w katalogu
  domowym. Ze źródła nie bierzemy powtórnej inicjalizacji na żywym magazynie. To niszczy
  odczyt, nie „odświeża klucza”.
- [Rozszczelnienie operatorem](https://openbao.org/docs/commands/operator/unseal/). Wiążące
  jest podanie klucza do procesu, który otwiera magazyn. Dotyczy jednostki systemd, która
  czyta klucz z katalogu poświadczeń i woła to API. Ze źródła nie bierzemy klucza w
  argumencie widocznym w `ps` i nie bierzemy zostawienia klucza na dysku po sukcesie.
- [Unieważnienie tokenu](https://openbao.org/docs/commands/token/revoke/). Wiążące jest
  `bao token revoke` na token root po zakończeniu inicjalizacji. Dotyczy zakazu
  `OPENBAO_TOKEN` w Deploymentcie. Ze źródła nie bierzemy zostawienia tokenu root „na
  wszelki wypadek” w Secretcie Kubernetes.
- [Stan zdrowia](https://openbao.org/docs/api-docs/system/health/). Wiążące jest
  `/v1/sys/health` i parametr `sealedcode`, który ustawia kod odpowiedzi stanu
  zapieczętowania. Dotyczy probe z `sealedcode=200`, żeby kubelet nie restartował poda przed
  jednostką. Ze źródła nie bierzemy traktowania procesu niezainicjowanego jako gotowego
  magazynu i nie bierzemy publikacji tego endpointu poza namespace.
- [Zamknięcie dzierżawy](https://openbao.org/docs/commands/lease/revoke/). Wiążące jest
  `bao lease revoke` po odczycie próbnym. Dotyczy testu
  `bao read database/creds/news-write`, którego hasło nie zostaje w pliku. Ze źródła nie
  bierzemy zostawienia użytkownika Postgresa z testu jako stałego konta usługi.
- [Listener TCP](https://openbao.org/docs/configuration/listener/tcp/). Wiążące jest
  `tls_disable` jako jawna decyzja listenera, nie jako domyślne wystawienie na świat.
  Dotyczy wyłączenia TLS tylko wewnątrz namespace, na ClusterIP, bez hostname publicznego.
  Ze źródła nie bierzemy NodePort z `tls_disable` i nie bierzemy certyfikatu serwera w git.
- [Jednostka systemd](https://www.freedesktop.org/software/systemd/man/systemd.service.html).
  Wiążące są `Type=oneshot`, `After=` i `WantedBy=` przy starcie zależności. Dotyczy
  `jjdevhub-openbao-unseal.service` z `After=k3s.service`. Ze źródła nie bierzemy jednostki
  w repozytorium obok magazynu pieczęci i nie bierzemy rozszczelnienia ręcznego jako ścieżki
  zwykłego rebootu.
- [Poświadczenia procesu](https://www.freedesktop.org/software/systemd/man/systemd.exec.html).
  Wiążące jest `LoadCredentialEncrypted=` i katalog `$CREDENTIALS_DIRECTORY`, który znika z
  procesem. Dotyczy klucza `unseal` widzianego tylko przez jednostkę. Ze źródła nie bierzemy
  kopiowania tego katalogu do `/tmp` i nie bierzemy wypisywania poświadczenia w logu
  jednostki.
- [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/).
  Wiążąca jest stabilna tożsamość jednej repliki z własnym wolumenem. Dotyczy `openbao` i
  PVC `5Gi`. Ze źródła nie bierzemy drugiej repliki i nie bierzemy HPA na ten obiekt.
- [Trwały wolumen](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). Wiążące
  jest trzymanie katalogu `raft` poza warstwą kontenera, która znika przy restarcie. Dotyczy
  `5Gi` na `local-path` z numeru 08. Ze źródła nie bierzemy eksportu tego wolumenu do
  jawnego pliku w katalogu domowym.
- [Kubernetes Service](https://kubernetes.io/docs/concepts/services-networking/service/).
  Wiążący jest ClusterIP i nazwa DNS wewnątrz namespace. Dotyczy
  `openbao.jjdevhub.svc.cluster.local` na porcie 8200. Ze źródła nie bierzemy NodePort i nie
  bierzemy `externalIPs`.
- [Probe żywości i gotowości](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).
  Wiążące jest to, że nieudana próba żywości restartuje kontener. Dotyczy akceptacji stanu
  zapieczętowania, żeby restart nie wyprzedził jednostki systemd. Ze źródła nie bierzemy
  probe, które traktuje 503 zapieczętowania jak awarię procesu.
- [GRANT w PostgreSQL](https://www.postgresql.org/docs/current/sql-grant.html). Wiążące jest
  nadanie `CONNECT` i praw do tabel w jednej bazie. Dotyczy zdania SQL roli dynamicznej,
  które wymienia tylko swoją bazę. Ze źródła nie bierzemy `GRANT` na `news_read` w roli
  `news-write` i nie bierzemy superużytkownika jako konta usługi.
- [Tokeny](https://openbao.org/docs/concepts/tokens/). Wiążące jest rozróżnienie tokenu
  root, tokenu z metody `kubernetes` i tokenu, który da się unieważnić. Dotyczy zakazu
  tokenu deweloperskiego na produkcji i unieważnienia root po inicjalizacji. Ze źródła nie
  bierzemy tokenu okresowego wpisanego w git jako „zamiennika roli”.

## Gotowe gdy

- Pod OpenBao po reboocie gościa jest rozszczelniony przez
  `jjdevhub-openbao-unseal.service`, a `bao status` pokazuje magazyn otwarty.
- `sudo find` z testu 2 nie znajduje jawnego pliku klucza. W git nie ma `*.sops.*`,
  `*.enc.yaml` ani wartości klucza.
- Inicjalizacja była z `-key-shares=1 -key-threshold=1`. Kopia offline klucza jest poza VM i
  poza git.
- `bao read database/creds/news-write` jako rola `news` zwraca dzierżawę o oknie do 24
  godzin, a odczyt `identity-write` tą samą rolą kończy się odmową. Hasło z dzierżawy nie
  wchodzi do `news_read`.
- W YAML Deploymentów nie ma tokenu root, nie ma `OPENBAO_TOKEN` i nie ma hasła Postgresa.
  Jest `OPENBAO_ADDR` równy `http://openbao.jjdevhub.svc.cluster.local:8200` i
  `OPENBAO_AUTH` równe `kubernetes`, gdy aplikacja już stoi.
- Rola `gateway` nie ma ścieżek bazy. `web` i `mobile` nie mają roli. Contact ma dodatkowo
  `kv/data/contact/fcm`.
- Hasło konta technicznego jest w pieczęci `openbao-db`, nie w ConfigMap.
- Service jest ClusterIP. `nc -vz <adres-gościa> 8200` z sieci spoza LAN nie łączy. W tunelu
  nie ma hostname OpenBao.
- Token deweloperski z laptopa przeciw temu adresowi kończy się odmową.
- Jedna replika, PVC `5Gi`, magazyn `raft`, obraz po digescie. HPA o nazwie `openbao` nie
  istnieje. Probe używa `/v1/sys/health` i przyjmuje stan zapieczętowania.
