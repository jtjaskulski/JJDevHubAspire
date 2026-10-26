# 15. Kafka między usługami

Ten numer przenosi kopertę z outboxa na Kafkę i oddaje ją do inboxa odbiorcy. Biblioteka
`JJDevHub.EventBus.Kafka` daje `KafkaEventBus`, `KafkaConsumerWorker` i tworzenie tematów.
Wiersz outboxa, `ReceiveOutcome` i ten sam `EventId` przy ponowieniu są w
[14-outbox.md](14-outbox.md). Brama HTTP, która nie czyta szyny, jest w
[16-gateway.md](16-gateway.md). Bez tego numeru `InMemoryEventBus` zostaje w jednym procesie:
News nie odda `news.article-created.v1` sąsiadowi po restarcie, a Cv nie złoży kopii technologii
z `learning.integration`.

Kafka stoi w trybie KRaft. Jeden broker w AppHost i jeden na maszynie. Temat należy do jednej
usługi. `learning.integration` jest kompaktowany, żeby Cv mogło złożyć kopię stanu od zera.
Pozostałe tematy nie są kompaktowane. Dla nich właściciel umie wysłać wiersz outboxa ponownie, z
tym samym `EventId`. Redis Streams nie wchodzą. Redis jest cachem z [13-redis.md](13-redis.md).
Szyna i cache nie mogą paść razem. RabbitMQ nie wchodzi. Wiadomość, która znika po
potwierdzeniu, nie zostawia Cv ostatniego stanu technologii bez osobnego magazynu po stronie
nadawcy i bez ponownego wysłania całego katalogu.

Offset schodzi po `Handled`, `Duplicate` albo `Ignored`, albo po zapisie do martwej kolejki.
Nigdy przed. Wyjątek handlera nie commituje offsetu, dopóki trwają próby. Piąta porażka, w
teście druga, ląduje na `{temat}.{grupa}.dlq` i nie woła odbiorcy w nieskończoność. Drugi pod w
tej samej grupie może zobaczyć wiadomość przy rebalansie. Inbox zwraca `Duplicate`. Push idzie
raz. Producent ma `Acks.All` i `EnableIdempotence = true`. To nie zastępuje inboxa. Idempotencja
producenta i inbox adresują dwa różne powtórzenia.

## Po co

Outbox z numeru `14` umie wysłać kopertę do `IEventBus` w pamięci. Dwie usługi w dwóch procesach
potrzebują logu poza procesem. Odbiorca ma dostać fakt po restarcie, w kolejności klucza, i ma
móc stanąć drugi raz bez podwójnego skutku. `news.article-created.v1` jedzie na
`news.integration`, nie na osobnym temacie o nazwie zdarzenia. Typ jest w nagłówku `event-type`.
Klucz jest `PartitionKey`. Utworzenie i wycofanie tego samego artykułu nie mogą się wyprzedzić
na dwóch partycjach. Jeden temat i jeden klucz trzymają kolejność zapisu outboxa.

Cv nie woła Learning po HTTP, żeby złożyć stronę. Nie otwiera `learning_read`. Czyta ostatni
stan technologii i kursu z `learning.integration`. Kompaktowanie zostawia na temacie ostatnią
wiadomość klucza, więc nowy proces Cv czyta temat od `AutoOffsetReset.Earliest` i buduje kopię.
Klucz stanu to stabilny slug technologii, kursu albo lekcji, nie `Guid` zdarzenia.
`learning.technology-state.v1` niesie `Version` strumienia i slug. Starsza wiadomość, która
jeszcze nie zeszła z kompaktowania, nie cofa nazwy wyświetlanej. Temat faktów, na przykład
`contact.integration`, nie nadaje się do takiej odbudowy po wygaśnięciu retencji. Właściciel
publikuje wiersz ponownie, tym samym `EventId`. Nowy identyfikator wysłałby drugi push zapytania
studenta albo rekrutera.

Drugi pod konsumenta dostaje wiadomość jeszcze raz, gdy grupa się przebuduje.
`KafkaConsumerWorker` commituje offset dopiero po wyniku `ReceiveAsync`. `Handled` oznacza, że
skutek i wiersz inboxa są zatwierdzone. `Duplicate` oznacza, że drugi pod albo ponowienie już to
zrobiły. `Ignored` oznacza, że ta usługa tej nazwy nie obsługuje. We wszystkich trzech offset
schodzi. Wyjątek nie commituje. Worker powtarza z opóźnieniem `2^n * 200` ms, do limitu, potem
martwa kolejka. Grupa Cv na `learning.integration` ma kolejkę `learning.integration.cv.dlq`.
Inna grupa tego samego tematu ma własną. Błąd w Cv nie wygląda jak błąd w innym odbiorcy.

Konsument nie otwiera bazy nadawcy. `OutboxRepublisher` czyści `ProcessedOn` w bazie
właściciela, przez `IIntegrationEventOutbox`, i nie czyta bazy sąsiada. Próba czyszczenia
wiersza, którego `Name` idzie na temat kompaktowany, zwraca `invalid` i nic nie zmienia.
`learning.integration` jest na liście tematów, których nie wolno wysłać ponownie z outboxa. Tam
źródłem odbudowy jest temat. Mieszanie obu mechanizmów włożyłoby stare klucze z powrotem do logu
kompaktowanego bez potrzeby.

## Dlaczego ta technologia

### Kafka w trybie KRaft

Kafka jest logiem: wiadomość zostaje na partycji przez retencję albo do kompaktowania,
niezależnie od tego, czy ktoś ją przeczytał. Konsument pamięta offset w grupie. Kolejność jest w
partycji, a klucz wybiera partycję. Wszystkie koperty jednego `PartitionKey` idą w kolejności
zapisu outboxa. Dwa fakty artykułu z tym samym identyfikatorem artykułu jako kluczem nie mijają
się. Dwa zapytania Contact z różnymi identyfikatorami mogą iść na różne partycje i nie muszą
mieć wspólnej kolejności. Test `Same_key_same_partition` stawia temat z 3 partycjami i dwie
koperty z tym samym `PartitionKey`. Lądują na tej samej partycji.

Od Kafki 3.3 metadane trzyma sama Kafka (KRaft). Osobny ZooKeeper przegrywa, bo to drugi system
na jedną maszynę i na kontener testowy. Aspire i Testcontainers podnoszą KRaft domyślnie. Pakiet
hosta to `Aspire.Hosting.Kafka`. AppHost woła `var kafka = builder.AddKafka("kafka")` i
przekazuje odniesienie usługom, które publikują albo czytają, przez `WithReference(kafka)`.
Connection string wołany z konfiguracji to `ConnectionStrings:kafka`. Test używa `KafkaBuilder`
z Testcontainers. Temat w teście ma nazwę `test-{guid}.integration`, żeby klasy nie wchodziły
sobie w offset.

Koszt: proces JVM i pojęcia partycji, grupy, offsetu. Na jednej maszynie replikacja tematu to 1.
Konfiguracja producenta i tak ma `acks=all`, żeby przy kolejnym brokerze nic nie zmieniać w
kodzie. Drugi broker i replikacja większa niż 1 są poza tą maszyną. `KafkaException` z `IsFatal`
kończy pętlę i loguje `Critical`. Host ma paść, a AppHost albo maszyna podniesie proces. Ciche
kręcenie pętli przy fatalnym błędzie klienta zostawiłoby grupę bez konsumpcji i offset w
miejscu, którego nikt nie pilnuje.

### Confluent.Kafka

`Confluent.Kafka` (Apache-2.0) jest klientem na `librdkafka`. `KafkaEventBus` i
`KafkaConsumerWorker` wołają go wprost. Widać, kiedy schodzi offset i co dzieje się z błędem.
`PublishAsync` woła `ProduceAsync`. `ProduceException` i status inny niż `Persisted` stają się
`EventBusPublishException`. Dispatcher z numeru `14` już umie ten wyjątek: zwiększa `Attempts` i
nie oznacza `ProcessedOn`. Test `Missing_topic_throws_publish_exception` przy wyłączonym
auto-tworzeniu oczekuje właśnie tego wyjątku, nie nowego tematu z literówki.

Nakładka, która chowa commit (KafkaFlow, MIT), przegrywa, bo ten numer właśnie ustala chwilę
commitu. Rider MassTransit przegrywa razem z licencją MassTransit od wersji 9. Wolverine
przegrywa, bo zabrałby outbox, który już jest nasz. Pakiet wchodzi do tabeli w
[README.md](README.md) przy numerze `15`. Wersja jest w `Directory.Packages.props`.
`Aspire.Confluent.Kafka` (MIT, razem z Aspire) dokłada health check klienta w usłudze. Protokół
zostaje przy `Confluent.Kafka`.

Koszt: sami składamy nagłówki i pętlę. To jest treść numeru, nie brak biblioteki na dozwolonej
licencji. Nagłówki to `event-id`, `event-type`, `occurred-on` w ISO 8601 i `traceparent`, gdy
bieżąca `Activity` jest. Wartość to `Payload` jako UTF-8. Klucz to `PartitionKey`. Temat jest z
`PublishedTopics`, zgodny z właścicielem nazwy. `KafkaEventBus` jest `sealed` i singletonem.
Konfiguracja: `Acks.All`, `EnableIdempotence = true`, `MessageTimeoutMs` 30000. Producent nie
ponawia w nieskończoność. Ponawia dispatcher. Ponowienie klienta nie dokłada drugiej kopii na
partycji. Inbox i tak zostaje, bo rebalans i republish są innym powtórzeniem niż ponowienie
producenta.

### Temat należy do jednej usługi

| Temat | Właściciel | Kompaktowanie | Kto czyta |
| --- | --- | --- | --- |
| `identity.integration` | Identity | nie | usługi, które potrzebują faktu konta |
| `news.integration` | News | nie | kto zapisze się na fakt notatki |
| `learning.integration` | Learning | tak | Cv |
| `cv.integration` | Cv | nie | kto zapisze się na fakt CV |
| `contact.integration` | Contact | nie | adapter push w Contact |

Właściciel jest jedynym producentem. `auto.create.topics.enable` na brokerze jest wyłączone.
Literówka w nazwie kończy się błędem producenta, nie nowym tematem. `KafkaTopicInitializer`
tworzy tematy z listy `PublishedTopics` i martwą kolejkę konsumenta przy starcie.
`TopicAlreadyExists` jest pomijany. Dzięki temu pierwszy komunikat nie zależy od tego, czy ktoś
zdążył opublikować, a obca usługa nie zakłada `learning.integration` przez pomyłkę w kodzie
producenta. Test producenta odrzuca nazwę, której prefiks usługi nie pasuje do
`PublishedTopics`. Cudza usługa nie publikuje na `learning.integration`.

Nazwa zdarzenia nie jest nazwą tematu. `news.article-created.v1` jedzie na `news.integration`.
Typ jest w nagłówku `event-type`. Osobny temat na każdy typ przegrywa, bo „utworzono” i
„wycofano” tego samego artykułu mogłyby wyprzedzić się na dwóch partycjach. Jeden temat i klucz
równy `PartitionKey` trzymają kolejność. Test `Publish_uses_owner_topic` publikuje kopertę
`news.article-created.v1` i czyta ją z `news.integration`. Test `Publish_sets_event_type_header`
oczekuje nagłówka `event-type` równego tej nazwie, nie nazwie klasy CLR.

Koszt: nowy fakt to nagłówek i rekord w `Contracts`, nie nowy temat. Nowy temat to świadoma
zmiana właściciela. Pięć tematów z tabeli wyczerpuje właścicieli. Szósty temat nie powstaje „bo
doszedł slug”. Slug technologii jest kluczem wewnątrz `learning.integration`, nie nazwą tematu.
`TopicNames.DeadLetter(topic, consumerGroup)` zwraca `{topic}.{consumerGroup}.dlq` i też nie
jest nowym tematem biznesowym. Jest kolejką błędów tej grupy.

### Kompaktowanie `learning.integration`

`cleanup.policy=compact`. Klucz wiadomości stanu to stabilny slug technologii, kursu albo
lekcji, nie `Guid` zdarzenia. Zostaje ostatnia wartość klucza. Cv, które wystartuje z pustą
kopią, czyta temat od `AutoOffsetReset.Earliest` i składa stan. Nie łączy się z `learning_read`.
`KafkaTopicInitializer` dla `learning.integration` ustawia `cleanup.policy` na `compact`. Rekord
`TechnologyStateIntegrationEvent` ma `Version` i slug. Klucz koperty to slug. Test
`Older_version_does_not_overwrite_copy` kładzie na temat wersję 2, potem wersję 1, i sprawdza,
że kopia zostaje przy 2.

Temat faktów z kompaktowaniem przegrywa, bo skasowałby historię „zapytanie przyjęte”, a push
potrzebuje faktu, nie ostatniego stanu skrzynki. `contact.integration` zostaje przy zwykłej
retencji. Zwykła retencja na `learning.integration` przegrywa, bo po siedmiu dniach Cv nie
odbuduje katalogu z tematu. Retencja tematów niekompaktowanych to 7 dni. Kafka nie jest źródłem
prawdy tych faktów. Źródłem jest baza właściciela i wiersz outboxa. Po siedmiu dniach fakt da
się wysłać jeszcze raz tylko dlatego, że wiersz outboxa został, z tym samym `EventId`.

Koszt: kompaktowanie nie jest natychmiastowe. Przez chwilę na temacie są dwie wartości klucza.
Odbiorca porównuje wersję. Bez `Version` na `learning.technology-state.v1` starszy slug
nadpisałby nowszą nazwę wyświetlaną tylko dlatego, że kompaktor jeszcze nie skasował poprzedniej
wartości. Wersja jest tym samym pomysłem co wersja w wierszu projekcji: starsze nie cofa
nowszego. Tu liczbą jest wersja strumienia technologii, a kluczem jest slug, nie `EventId`.
`EventId` nadal jedzie w nagłówku, bo inbox go potrzebuje. Klucz partycji i identyfikator
dostawy to dwie różne rzeczy.

### Wersja na zdarzeniu stanu i ponowna publikacja reszty

Zdarzenie stanu niesie `Version` i slug. Cv stosuje kopertę, gdy `Version` jest większa niż
kopia. Starsza wiadomość nie cofa nazwy. Tematy bez kompaktowania nie odbudują się z logu po
retencji. `OutboxRepublisher.RepublishAsync(eventIds, cancellationToken)` w bazie właściciela
ustawia `ProcessedOn` na `null` tam, gdzie `EventId` jest na liście i temat wiadomości nie jest
na liście kompaktowanej. `learning.integration` w tej liście jest. Próba czyszczenia wiersza,
którego `Name` idzie na temat kompaktowany, zwraca `invalid` i nic nie zmienia. Po czyszczeniu
zwykły dispatcher wysyła wiersz. Test `Republish_keeps_event_id` sprawdza, że na temacie drugi
raz widać ten sam `event-id`. Test `Republish_compacted_topic_returns_invalid` bierze nazwę
stanu Learning i oczekuje kodu `invalid` oraz `ProcessedOn` bez zmian.

Ponowna publikacja nie dotyczy `learning.integration`. Tam źródłem odbudowy jest temat.
Mieszanie obu mechanizmów na jednym temacie dałoby stare klucze z powrotem w logu kompaktowanym
bez potrzeby. Cv, które czyta od początku, złożyłoby stan, a potem dostałoby starszą wartość
wstawioną republishem i musiałoby liczyć tylko na `Version`. Wersja i tak jest, ale republish na
temacie kompaktowanym nie wnosi odbudowy, którą temat już daje, a dokłada szum. Dlatego operacja
odmawia i nie czyści wiersza.

Koszt: republish jest jawną operacją właściciela, nie zegarem. Zegar, który czyści wszystkie
`ProcessedOn` co noc, zalałby odbiorców. Operacja przyjmuje listę `EventId` albo zakres czasu i
loguje, kto ją woła. `OutboxRepublisher` leży przy adapterze Kafki, bo decyzja „ten temat wolno
wysłać ponownie” jest decyzją o temacie. Czyści wiersze przez `IIntegrationEventOutbox` w bazie
właściciela. Nie czyta bazy sąsiada. Nowy `EventId` przy ponowieniu przegrywa, bo Contact
wysłałby drugi push. Inbox odbiorcy, który już zastosował wiadomość, zwraca `Duplicate`.
Odbiorca, który jej nie miał, dostaje `Handled` raz.

### Martwa kolejka na konsumenta

Wiadomość, która pięć razy z rzędu rzuca w handlerze, blokowałaby partycję, bo offset nie może
przeskoczyć dziury. Kolejny fakt tego samego klucza, na przykład kolejna zmiana artykułu albo
kolejne zapytanie na tej samej partycji, stałby w miejscu. Po `MaxDeliveryAttempts` worker
publikuje ją na `{temat}.{grupa}.dlq` i dopiero wtedy commituje offset źródła. Grupa Cv na
`learning.integration` ma kolejkę `learning.integration.cv.dlq`. Grupa innego konsumenta tego
samego tematu ma własną. Jedna wspólna kolejka na temat przegrywa, bo błąd w Cv wyglądałby jak
błąd w innym odbiorcy i wciągnięcie ręczne nie wiedziałoby, czyj to skutek.

Nagłówki martwej wiadomości: oryginalne plus `error` (typ i treść, do 2000 znaków) i
`source-topic`. Wiadomość bez `event-id` albo bez `event-type` idzie do tej kolejki od razu, bez
prób, bo nie da się jej oddać do inboxa. Test `Corrupt_message_skips_receiver` zabiera
`event-type` i oczekuje jednej wiadomości na DLQ oraz odbiorcy niewołanego. Test
`Failing_receiver_sends_to_dlq` ustawia `MaxDeliveryAttempts` na 2, każe odbiorcy rzucać i
oczekuje wiadomości na `{temat}.{grupa}.dlq`. W hoście limit prób to pięć. Test skraca go do
dwóch, żeby nie czekać pięciu opóźnień `2^n * 200` ms. Sens jest ten sam: po limicie offset
schodzi, odbiorca nie jest wołany w nieskończoność.

Koszt: ktoś musi obejrzeć kolejkę. Ten numer nie wciąga wiadomości z powrotem automatycznie.
Wciągnięcie ręczne to osobna, świadoma publikacja na temat źródłowy z tym samym `event-id`, a
inbox zdecyduje, czy to `Duplicate`. Automatyczne wciąganie w pętli z powrotem zablokowałoby
partycję tym samym wyjątkiem. `EnableAutoCommit = false` jest po to, żeby biblioteka nie
schowała tej decyzji. `GroupId` równa się nazwie usługi. Pętla jest `LongRunning`, bo `Consume`
blokuje. Na wiadomość powstaje koperta z nagłówków, a `ReceiveAsync` idzie w nowym scope, do
pięciu razy, zanim przyjdzie DLQ.

### Inbox przy drugim podzie

`KafkaConsumerWorker` commituje offset po wyniku `ReceiveAsync`. Dwa pody w jednej grupie
dostają rozłączne partycje w spokojnym przebiegu. Przy rebalansie oba mogą zobaczyć wiadomość,
której offset jeszcze nie zszedł. Unikalny `(EventId, Consumer)` z numeru `14` puszcza jeden
commit. Drugi dostaje `Duplicate` i nie woła handlera. Push i każda inna strona skutku są za tym
wynikiem. Test `Worker_commits_after_handled` przetwarza wiadomość, zatrzymuje workera i podnosi
drugiego workera tej samej grupy. Odbiorca nie dostaje jej drugi raz. Test
`Duplicate_outcome_commits` każe odbiorcy zwrócić `Duplicate`, czeka na commit i sprawdza, że
drugi worker grupy wiadomości nie dostaje.

Koszt: skutek ma być w tej samej transakcji co inbox. Skutek „wyślij HTTP do FCM, potem zapisz
inbox” z powrotem otwiera podwójną wysyłkę. Adapter push zapisuje zamiar w tej transakcji, a
wysyłkę HTTP robi po commicie, z własnym znacznikiem „wysłane”, albo zapisuje inbox przed HTTP i
toleruje ponowienie HTTP po swoim idempotentnym kluczu. Numer Contact dopnie kolejność. Tu
zasada jest jedna: `Duplicate` nie wchodzi do handlera. `Ignored` commituje offset, bo inaczej
nieznana nazwa na wspólnym temacie blokowałaby partycję. `Handled` commituje dopiero, gdy wiersz
inboxa i skutek są zatwierdzone. Wyjątek zostawia offset i powtarza.

Producent ma `Acks.All` i `EnableIdempotence = true`. Ponowienie klienta nie dokłada drugiej
kopii na partycji. To nie zastępuje inboxa. Idempotencja producenta gasi podwójny zapis tego
samego produce. Inbox gasi drugą dostawę tego samego `EventId`, także wtedy, gdy republish albo
rebalans są świadome i poprawne z punktu widzenia brokera. `Core` nie referencjonuje
`Confluent.Kafka`. Adapter jest w `Infrastructure` ścieżki szyny, nie w agregacie. Konsument nie
otwiera bazy nadawcy. Cv nie czyta `learning_write`, żeby „uzupełnić” temat.

## Klasy i ścieżki

Adapter zna brokera, nagłówki i chwilę commitu. Nie zna handlerów domenowych. Outbox zna
`IEventBus`. Republisher zna listę tematów kompaktowanych i bazę właściciela. Learning dokłada
rekord stanu. Test dokłada KRaft na klasę i `RecordingReceiver`.

| Plik | Odpowiedzialność |
| --- | --- |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaEventBus.cs` | `IEventBus` na producencie |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaConsumerWorker.cs` | pętla, inbox, DLQ, commit |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaTopicInitializer.cs` | tematy i kolejki przy starcie |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaHeaders.cs` | `event-id`, `event-type`, `occurred-on` |
| `src/shared/JJDevHub.EventBus.Kafka/TopicNames.cs` | temat właściciela i nazwa DLQ |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaOptions.cs` | broker, grupa, listy tematów, próby |
| `src/shared/JJDevHub.EventBus.Kafka/OutboxRepublisher.cs` | czyszczenie `ProcessedOn` dla tematów bez kompaktowania |
| `src/shared/JJDevHub.EventBus.Kafka/KafkaServiceCollectionExtensions.cs` | `AddKafkaEventBus`, `AddKafkaConsumer` |
| `JJDevHub.AppHost/AppHost.cs` | `AddKafka` w trybie KRaft |
| `src/services/Learning/Learning.Contracts/TechnologyStateIntegrationEvent.cs` | `learning.technology-state.v1` z `Version` |
| `tests/JJDevHub.EventBus.Kafka.Tests/KafkaEventBusTests.cs` | producent |
| `tests/JJDevHub.EventBus.Kafka.Tests/KafkaConsumerWorkerTests.cs` | offset, DLQ, duplikat |

`OutboxRepublisher` leży przy adapterze Kafki, bo decyzja „ten temat wolno wysłać ponownie” jest
decyzją o temacie. Czyści wiersze przez `IIntegrationEventOutbox` w bazie właściciela. Nie czyta
bazy sąsiada. `AddKafkaEventBus` i `AddKafkaConsumer` woła `Api` usługi, która publikuje albo
czyta. Usługa, która tylko publikuje, nie musi kręcić konsumenta cudzego tematu. Usługa, która
tylko czyta, nie dostaje prawa do `PublishedTopics` sąsiada.

## Plan

### 1. Projekt i broker

```bash
dotnet new classlib -n JJDevHub.EventBus.Kafka -o src/shared/JJDevHub.EventBus.Kafka -f net11.0
dotnet new xunit -n JJDevHub.EventBus.Kafka.Tests -o tests/JJDevHub.EventBus.Kafka.Tests -f net11.0
dotnet sln add src/shared/JJDevHub.EventBus.Kafka tests/JJDevHub.EventBus.Kafka.Tests
dotnet add src/shared/JJDevHub.EventBus.Kafka reference src/shared/JJDevHub.EventBus
dotnet add src/shared/JJDevHub.EventBus.Kafka reference src/shared/JJDevHub.IntegrationEventLog
dotnet add src/shared/JJDevHub.EventBus.Kafka package Confluent.Kafka
dotnet add tests/JJDevHub.EventBus.Kafka.Tests package Testcontainers.Kafka
dotnet add JJDevHub.AppHost package Aspire.Hosting.Kafka
```

Test ma cechę `Category=Integration`. `KafkaBuilder` z Testcontainers stawia KRaft. Temat w
teście ma nazwę `test-{guid}.integration`, żeby klasy nie wchodziły sobie w offset.

AppHost: `var kafka = builder.AddKafka("kafka")`. Usługa publikująca dostaje
`WithReference(kafka)`. Connection string wołany z konfiguracji to `ConnectionStrings:kafka`.

### 2. Wiadomość

| Część | Wartość |
| --- | --- |
| temat | z `PublishedTopics`, zgodny z właścicielem nazwy |
| klucz | `PartitionKey` |
| wartość | `Payload` jako UTF-8 |
| `event-id` | `EventId` |
| `event-type` | `Name` z atrybutu |
| `occurred-on` | ISO 8601 |
| `traceparent` | bieżąca `Activity`, gdy jest |

`TopicNames.DeadLetter(topic, consumerGroup)` zwraca `{topic}.{consumerGroup}.dlq`.

### 3. Producent

`KafkaEventBus` jest `sealed` i singletonem. `PublishAsync` woła `ProduceAsync`.
`ProduceException` i status inny niż `Persisted` stają się `EventBusPublishException`.
Dispatcher z numeru `14` już umie ten wyjątek: zwiększa `Attempts` i nie oznacza `ProcessedOn`.

Konfiguracja: `Acks.All`, `EnableIdempotence = true`, `MessageTimeoutMs` 30000. Producent nie
ponawia w nieskończoność. Ponawia dispatcher.

### 4. Konsument

`EnableAutoCommit = false`, `AutoOffsetReset = Earliest`, `GroupId` równe nazwie usługi. Pętla
jest `LongRunning`, bo `Consume` blokuje. Na wiadomość: koperta z nagłówków, brak nagłówka to
DLQ bez prób, w przeciwnym razie do pięciu razy `ReceiveAsync` w nowym scope. Wynik `Handled`,
`Duplicate` albo `Ignored` commituje offset. Wyjątek czeka i próbuje ponownie. Po limicie DLQ i
commit.

`KafkaException` z `IsFatal` kończy pętlę i loguje `Critical`. Host ma paść, a AppHost albo
maszyna podniesie proces.

### 5. Temat Learning

`KafkaTopicInitializer` dla `learning.integration` ustawia `cleanup.policy` na `compact`. Rekord
`TechnologyStateIntegrationEvent` ma `Version` i slug. Klucz koperty to slug. Test
`Older_version_does_not_overwrite_copy` kładzie na temat wersję 2, potem wersję 1, i sprawdza,
że kopia zostaje przy 2.

### 6. Ponowna publikacja

`OutboxRepublisher.RepublishAsync(eventIds, cancellationToken)` w bazie właściciela ustawia
`ProcessedOn` na `null` tam, gdzie `EventId` jest na liście i temat wiadomości nie jest na
liście kompaktowanej. `learning.integration` w tej liście jest. Próba czyszczenia wiersza,
którego `Name` idzie na temat kompaktowany, zwraca `invalid` i nic nie zmienia. Po czyszczeniu
zwykły dispatcher wysyła wiersz. Test sprawdza, że `EventId` na szynie jest ten sam.

### Co jest do czego

- `KafkaEventBus` woła dispatcher outboxa jako `IEventBus`. Nie zna handlerów. Bez niego koperta
  zostaje w `InMemoryEventBus` i nie przeżywa dwóch procesów. `ProduceException` oraz status
  inny niż `Persisted` stają się `EventBusPublishException`, które numer `14` już liczy w
  `Attempts`.
- `KafkaConsumerWorker` woła host usługi, która słucha. Jedyne miejsce commitu offsetu. Bez
  niego biblioteka z `EnableAutoCommit` schowałaby chwilę commitu i offset zszedłby przed
  `Handled`. Wyjątek nie commituje. Po limicie prób schodzi DLQ i dopiero wtedy offset źródła.
- `KafkaTopicInitializer` woła start usługi. Tematy istnieją, zanim poleci pierwsza koperta, a
  broker sam ich nie tworzy. Bez inicjalizacji literówka w `PublishedTopics` albo zakłada temat,
  albo pierwsza publikacja pada w sposób, którego test nie odróżnia od awarii brokera.
  `TopicAlreadyExists` jest pomijany. `auto.create.topics.enable` zostaje wyłączone.
- `KafkaHeaders` woła producent przy składaniu i konsument przy kopercie. `event-type` wybiera
  rekord bez patrzenia w nazwę klasy. `event-id` jest `EventId` z outboxa. `occurred-on` jest
  ISO 8601. `traceparent` dokleja się, gdy jest `Activity`. Brak `event-id` albo `event-type`
  idzie na DLQ bez prób, bo inbox nie ma czego deduplikować.
- `TopicNames` woła inicjalizator i worker. DLQ jest per grupa konsumenta:
  `{topic}.{consumerGroup}.dlq`. Bez tego Cv i inny czytelnik `learning.integration` dzieliliby
  jedną kolejkę i błąd jednego wyglądałby jak błąd drugiego.
- `KafkaOptions` woła rejestrację. Niosą brokera, `GroupId` równe nazwie usługi,
  `PublishedTopics`, listę tematów kompaktowanych i `MaxDeliveryAttempts`. Bez listy właściciela
  producent mógłby pisać na `learning.integration` z News. Test odrzuca prefiks spoza listy.
- `OutboxRepublisher` woła jawną operację właściciela. Czyści `ProcessedOn` i nie zmienia
  `EventId` na temacie bez kompaktowania. Bez niego po siedmiu dniach fakt znika z logu i nie ma
  jak go oddać z tym samym identyfikatorem. Na `learning.integration` zwraca `invalid` i nic nie
  zmienia. Operacja przyjmuje listę `EventId` albo zakres czasu i loguje, kto ją woła. Zegar,
  który czyści wszystkie `ProcessedOn`, nie powstaje.
- `TechnologyStateIntegrationEvent` woła Learning jako rekord stanu. Nazwa
  `learning.technology-state.v1`, pole `Version`, klucz równy slugowi, temat kompaktowany. Bez
  wersji starsza wartość po kompaktowaniu, które jeszcze nie doszło, cofa nazwę w kopii Cv. Cv
  nie łączy się z `learning_read`.
- `AddKafkaEventBus` i `AddKafkaConsumer` woła `Program.cs`. Bez nich singleton producenta i
  pętla konsumenta nie wstają, a `ConnectionStrings:kafka` nie ma kto czytać. Konsumencka pętla
  jest `LongRunning`. Producent jest singletonem.
- Grupa konsumentów woła każdy pod tej samej usługi. Dzielą partycje w spokojnym przebiegu. Przy
  rebalansie inbox składa podwójną dostawę w jeden skutek. Bez `GroupId` równego nazwie usługi
  dwa wdrożenia tej samej usługi nie wiedziałyby, czy dzielą offset, czy czytają temat drugi raz
  od zera na stałe.
- `acks=all` i idempotencja producenta woła `KafkaEventBus` przy każdym `ProduceAsync`.
  Ponowienie zapisu na partycji nie mnoży wiadomości w brokerze. Bez tego dispatcher, który
  ponawia po `EventBusPublishException`, mógłby dołożyć drugą kopię, zanim inbox w ogóle zobaczy
  `EventId`. To nadal nie zastępuje `Duplicate`.
- `RecordingReceiver` woła test. Zapisuje `EventId` i umie rzucić. Bez atrapy test offsetu
  podnosiłby prawdziwy inbox i bazę odbiorcy. Każdy fakt ma jeden powód do padnięcia. Kontener
  KRaft jest na klasę.

## Testy

Projekt `tests/JJDevHub.EventBus.Kafka.Tests`. xUnit, `[Fact]`, `Category=Integration`. Kontener
KRaft na klasę. `RecordingReceiver` zapisuje `EventId` i umie rzucić. Każdy fakt ma jeden powód
do padnięcia. Temat testowy `test-{guid}.integration` izoluje offset klas. Pięć tematów z tabeli
właścicieli sprawdza produkcyjny inicjalizator. Test producenta używa `news.integration` tam,
gdzie sprawdza właściciela nazwy.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Publish_uses_owner_topic` | temat `news.integration` | `PublishAsync` koperty `news.article-created.v1` | konsument testowy czyta ją z `news.integration` |
| `Publish_sets_event_type_header` | j.w. | `PublishAsync` | nagłówek `event-type` równy `news.article-created.v1` |
| `Same_key_same_partition` | temat z 3 partycjami | dwie koperty z tym samym `PartitionKey` | ta sama partycja |
| `Missing_topic_throws_publish_exception` | auto-tworzenie wyłączone | `PublishAsync` | `EventBusPublishException` |
| `Worker_commits_after_handled` | wiadomość przetworzona, worker zatrzymany | drugi worker tej samej grupy | odbiorca nie dostaje jej drugi raz |
| `Duplicate_outcome_commits` | odbiorca zwraca `Duplicate` | czekanie na commit | drugi worker grupy nie dostaje wiadomości |
| `Failing_receiver_sends_to_dlq` | odbiorca rzuca, `MaxDeliveryAttempts` 2 | czekanie | wiadomość na `{temat}.{grupa}.dlq` |
| `Corrupt_message_skips_receiver` | brak `event-type` | czekanie | DLQ ma jedną wiadomość, odbiorca niewołany |
| `Older_version_does_not_overwrite_copy` | stan wersja 2, potem wersja 1, ten sam slug | zastosowanie obu | kopia zostaje przy wersji 2 |
| `Republish_keeps_event_id` | wiersz z `ProcessedOn`, temat niekompaktowany | `RepublishAsync` | na temacie drugi raz ten sam `event-id` |
| `Republish_compacted_topic_returns_invalid` | nazwa stanu Learning | `RepublishAsync` | kod `invalid`, `ProcessedOn` bez zmian |

```bash
dotnet test tests/JJDevHub.EventBus.Kafka.Tests
```

Commit po `Handled` i commit po `Duplicate` są osobnymi faktami, bo jeden dowodzi, że offset
schodzi po sukcesie, a drugi, że schodzi także wtedy, gdy handler się nie wykonał. Starsza
wersja stanu jest osobno od republisha, bo to dwa mechanizmy odbudowy i nie wolno ich zlać w
jeden test. Cecha `Category=Integration` zostawia projekt poza filtrem bez kontenerów. Brama
HTTP do tego testu nie wchodzi.

## Zasady

- Temat ma jednego producenta, usługę z tabeli. Złamanie pozwala News pisać na
  `learning.integration` i psuje właściciela logu, z którego Cv odbudowuje katalog.
- `event-type` to nazwa z `[EventName]`, nie nazwa CLR. Złamanie psuje odbiorców po
  przeniesieniu rekordu i omija rejestr kontraktów.
- Offset schodzi po `Handled`, `Duplicate` albo `Ignored`, albo po zapisie do DLQ. Złamanie albo
  gubi wiadomość przed inboxem, albo blokuje partycję na nazwie, której usługa nie obsługuje.
- Wyjątek handlera nie commituje offsetu, dopóki trwają próby. Złamanie uznaje porażkę za
  dostarczoną i push albo kopia stanu nigdy nie dochodzą.
- DLQ jest per grupa konsumenta. Złamanie miesza błąd Cv z błędem innego czytelnika tego samego
  tematu.
- `learning.integration` jest kompaktowany i niesie wersję stanu. Złamanie po siedmiu dniach nie
  zostawia Cv katalogu albo pozwala starszej wartości cofnąć nazwę.
- Ponowna publikacja czyści `ProcessedOn` i nie zmienia `EventId`. Złamanie nadaje nowy
  identyfikator i Contact wysyła drugi push.
- Ponowna publikacja nie dotyczy tematu kompaktowanego. Złamanie wstawia stare klucze z powrotem
  do `learning.integration` i miesza dwa sposoby odbudowy.
- Redis nie przenosi kopert. RabbitMQ nie jest w AppHost. Złamanie wiąże szynę z cache albo z
  kolejką, która nie zostawia ostatniego stanu technologii.
- Konsument nie otwiera bazy nadawcy. Złamanie daje Cv połączenie do `learning_write` albo
  `learning_read` zamiast kopii z tematu.
- `Core` nie referencjonuje `Confluent.Kafka`. Złamanie wciąga agregat w klienta brokera i w
  offset.

## Poza zakresem

- Tabela outboxa i enum `ReceiveOutcome` są w [14-outbox.md](14-outbox.md). Tu jest transport,
  który te wyniki zamienia na commit offsetu.
- Wejście HTTP jest w [16-gateway.md](16-gateway.md). Brama nie czyta szyny i nie publikuje
  kopert.
- Wydanie klucza JWT jest w [17-identity.md](17-identity.md). `identity.integration` niesie fakt
  konta, nie token.
- Pełna lista faktów Learning i skład kopii w Cv są w [19-learning.md](19-learning.md) i
  [20-cv.md](20-cv.md). Tu jest `learning.technology-state.v1` jako kształt stanu z wersją i
  slugiem.
- Push i to, w której chwili idzie HTTP do FCM, są w [21-kontakt.md](21-kontakt.md). Tu
  `Duplicate` nie wchodzi do handlera. Kolejność „zamiar w transakcji, HTTP po commicie” dopnie
  Contact.
- Drugi broker i replikacja większa niż 1 są poza tą maszyną. `acks=all` zostaje, żeby kod
  producenta przy tym nie urósł.
- Wciąganie wiadomości z DLQ z powrotem na temat nie jest automatyczne. Ręcznie, tym samym
  `event-id`. Inbox zdecyduje, czy to `Duplicate`.

## Źródła

- [Apache Kafka design](https://kafka.apache.org/documentation/#design). Wiążący jest log,
  partycje, grupy i offset. W tym pliku kolejność jest w partycji, a `PartitionKey` wybiera
  partycję, więc dwa fakty jednego artykułu się nie mijają. Nie bierzemy auto-commitu.
  `EnableAutoCommit = false`, a offset schodzi po wyniku inboxa albo po DLQ. Nie bierzemy Kafki
  jako bazy zapisu strumienia domenowego.
- [KRaft](https://kafka.apache.org/documentation/#kraft). Wiążące są metadane bez ZooKeepera. W
  tym pliku AppHost woła `AddKafka`, a Testcontainers stawia KRaft. Nie bierzemy drugiego
  systemu koordynacji na jedną maszynę i na kontener testowy. Replikacja tematu na tej maszynie
  to 1. Drugi broker jest poza nią.
- [Confluent.Kafka](https://github.com/confluentinc/confluent-kafka-dotnet). Wiążący jest klient
  na `librdkafka` i licencja Apache-2.0. W tym pliku `KafkaEventBus` i `KafkaConsumerWorker`
  wołają go wprost, żeby było widać chwilę commitu. Nie bierzemy KafkaFlow, który chowa commit,
  ani ridera MassTransit. `Aspire.Confluent.Kafka` dokłada health check. Protokół zostaje przy
  tym pakiecie. Wersja jest w `Directory.Packages.props`.
- [Log compaction](https://kafka.apache.org/documentation/#compaction). Wiążąca jest ostatnia
  wartość klucza. W tym pliku `learning.integration` ma `cleanup.policy=compact`, a klucz to
  slug technologii, kursu albo lekcji. Nie bierzemy kompaktowania `contact.integration` ani
  innych tematów faktów: po kompaktowaniu zniknęłoby „zapytanie przyjęte”, a push potrzebuje
  faktu. Kompaktowanie nie jest natychmiastowe. Odbiorca porównuje `Version`.
- [.NET Aspire
  Kafka](https://learn.microsoft.com/en-us/dotnet/aspire/messaging/kafka-component). Wiążące są
  `Aspire.Hosting.Kafka` i connection string. W tym pliku `builder.AddKafka("kafka")` oraz
  `WithReference` dają usługom `ConnectionStrings:kafka`. Nie bierzemy stąd ZooKeepera ani
  publikowania endpointu Kafki na bramie HTTP. Jeden broker w AppHost i jeden na maszynie.
- [Should you put several event types on the same
  topic?](https://www.confluent.io/blog/put-several-event-types-kafka-topic/). Wiążący jest
  jeden temat właściciela i typ w nagłówku. W tym pliku `news.article-created.v1` jedzie na
  `news.integration`, a `event-type` niesie nazwę z atrybutu. Nie bierzemy osobnego tematu na
  każdy typ: „utworzono” i „wycofano” tego samego artykułu mogłyby się wyprzedzić. Nie bierzemy
  nazwy klasy CLR w nagłówku.
- Martin Kleppmann, *Designing Data-Intensive Applications*. Wiążący jest log jako trwały zapis
  wiadomości oraz kompaktowanie dziennika zmian, które zostawia ostatnią wartość klucza. W tym
  pliku tak działa `learning.integration`. Tematy faktów mają retencję 7 dni i nie są źródłem
  prawdy: prawdą zostaje baza właściciela i wiersz outboxa. Nie bierzemy Kafki zamiast
  `EventRecords` ani kompaktowania logu domenowego wewnątrz Postgresa.
- [Idempotent
  Receiver](https://www.enterpriseintegrationpatterns.com/patterns/messaging/IdempotentReceiver.html).
  Hohpe i Woolf: druga dostawa bez drugiego skutku. W tym pliku offset po `Duplicate` schodzi, a
  handler się nie woła. Dotyczy to rebalansu grupy i republishu tego samego `EventId`. Nie
  bierzemy deduplikacji po offsecie. Offset przy ponownej publikacji jest inny. Inbox patrzy na
  `EventId` i `Consumer`.
- Gregory Young, *Versioning in an Event Sourced System*. Wiążąca jest wersja, która mówi, co
  jest nowsze, niezależnie od kolejności dostawy. W tym pliku `learning.technology-state.v1`
  niesie `Version` strumienia, a starsza wiadomość nie cofa kopii Cv. Nie bierzemy wersji jako
  klucza kompaktowania. Kluczem zostaje slug. Wersja jest porównaniem u odbiorcy. Nowy `EventId`
  przy republishu tematów faktów nie wchodzi.
- Martin Fowler, [What do you mean by
  “event-driven”?](https://martinfowler.com/articles/201701-event-driven.html). Wiążące jest
  przeniesienie stanu zdarzeniem kontra powiadomienie o fakcie. W tym pliku stan technologii
  jedzie skompaktowanym `learning.integration`, a fakt zapytania Contact jedzie tematem z
  retencją i republishem. Nie bierzemy jednego mechanizmu na oba. Republish nie czyści wierszy
  stanu. Kompaktowanie nie kasuje historii pusha.
- [Kafka producer
  idempotence](https://kafka.apache.org/documentation/#producerconfigs_enable.idempotence).
  Wiążące są `enable.idempotence` i trwalsze potwierdzenie zapisu. W tym pliku producent ma
  `EnableIdempotence = true`, `Acks.All` i `MessageTimeoutMs` 30000. Nie bierzemy nieskończonego
  ponawiania w kliencie. Ponawia dispatcher, a status inny niż `Persisted` jest
  `EventBusPublishException`. Idempotencja producenta nie zastępuje inboxa.
- [Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html).
  Chris Richardson: wysyłka jest za commitem danych. W tym pliku republish czyści `ProcessedOn`
  i puszcza ten sam wiersz przez zwykły dispatcher. Nie bierzemy pisania na temat z handlera
  HTTP. Nie bierzemy republishu `learning.integration`. Tam odbudowa jest z logu kompaktowanego,
  a próba czyszczenia zwraca `invalid`.

## Gotowe gdy

- AppHost podnosi Kafkę w KRaft i usługa dostaje `ConnectionStrings:kafka`.
- `news.article-created.v1` widać na `news.integration` z nagłówkiem `event-type`.
- Dwie koperty o tym samym kluczu lądują na tej samej partycji.
- Offset nie schodzi przed `Handled`, `Duplicate` albo `Ignored`.
- Piąta porażka, w teście druga, ląduje na DLQ tej grupy i nie woła odbiorcy w nieskończoność.
- Starsza `Version` stanu nie cofa kopii.
- Republish tego samego `EventId` działa na temacie niekompaktowanym i zwraca `invalid` dla
  `learning.integration`.
- `dotnet test tests/JJDevHub.EventBus.Kafka.Tests` kończy się kodem 0.
