# Kafka

Kafka przenosi koperty zdarzeń integracyjnych między procesami. Biblioteka `JJDevHub.EventBus.Kafka` daje `KafkaEventBus` (implementacja `IEventBus` dla dispatchera outboxa), `KafkaConsumerWorker` (pętla konsumenta, która oddaje koperty do `IIntegrationEventReceiver`) i `KafkaTopicInitializer`. Kontrakty, outbox i inbox są w [12-outbox-inbox.md](12-outbox-inbox.md). Kafkę w środowisku dev postawi Aspire w [14-aspire.md](14-aspire.md).

## Po co

eShop przenosi zdarzenia przez RabbitMQ (`EventBusRabbitMQ`). My wybieramy Kafkę. Jest logiem, nie kolejką: wiadomość zostaje na temacie po przeczytaniu. Nowa usługa może więc przeczytać historię od początku. Kolejność jest gwarantowana w obrębie partycji, a klucz wiadomości wybiera partycję. Wszystkie fakty jednego artykułu trafią do jednej partycji i przyjdą po kolei.

Kafka nie daje „dokładnie raz” między bazą a brokerem. To zapewniają outbox (nic nie ginie) i inbox (nic nie działa dwa razy). Tutaj zostaje transport: klucze, nagłówki, commit offsetu po przetworzeniu i temat na wiadomości, których nie da się przetworzyć.

## Dlaczego ta technologia

### Kafka jako szyna między usługami

Kafka to rozproszony log: wiadomości są dopisywane do partycji tematu i zostają tam przez czas retencji (u nas 7 dni), niezależnie od tego, czy ktoś je przeczytał. Konsument pamięta tylko swój offset. Z tego wynikają trzy cechy, których potrzebujemy:

- **odtworzenie** — nowa usługa albo naprawiony konsument może przeczytać zdarzenia od początku retencji, przesuwając offset,
- **kolejność per klucz** — wiadomości z tym samym kluczem (id artykułu, id użytkownika) trafiają do jednej partycji i są czytane w kolejności zapisu,
- **niezależni konsumenci** — Notifications czyta temat w swojej grupie i nie przeszkadza nadawcy.

Alternatywy:

- **RabbitMQ** — klasyczny broker kolejek: lżejszy, prostszy w obsłudze, z bogatym routingiem. Wiadomość znika po potwierdzeniu, więc odtworzenia nie ma bez dodatkowych strumieni (RabbitMQ Streams). eShop używa RabbitMQ. Dla jednej VM byłby prostszy. Kafkę wybraliśmy świadomie: model logu i doświadczenie z nią są cenniejsze na rynku, a retencja daje odtworzenie.
- **Postgres jako kolejka** — sam outbox z `SKIP LOCKED` u konsumentów. Najprostsze, ale łamie zasadę „usługa nie czyta cudzej bazy”.
- **Azure Service Bus, AWS SQS** — chmura, a projekt działa na domowej VM.

Koszt Kafki: proces na JVM z apetytem na pamięć (kontener potrzebuje ok. 1 GB), więcej pojęć (partycje, grupy, offsety, rebalancing) i brak wbudowanej kolejki opóźnionych ponowień.

### KRaft zamiast ZooKeepera

Od Kafki 3.3 metadane klastra trzyma sama Kafka (KRaft), a od 4.0 ZooKeeper jest usunięty. Jeden kontener zamiast dwóch, mniej konfiguracji. Aspire i Testcontainers uruchamiają Kafkę w trybie KRaft domyślnie.

### Confluent.Kafka zamiast nakładki

Confluent.Kafka (Apache 2.0) to oficjalny klient .NET na `librdkafka`, najszybszej i najlepiej utrzymywanej implementacji protokołu. Aspire ma do niego integrację (`Aspire.Confluent.Kafka`) z health checkiem i śladami. Nakładki:

- **KafkaFlow** (MIT) — middleware, serializery, ponowienia; dobra, ale chowa offsety i commit, które są tematem tego numeru,
- **MassTransit Rider** — płatny od `9`,
- **Wolverine** (MIT) — transport Kafki w pakiecie z resztą Wolverine.

Na kliencie bazowym widać każdą decyzję: kiedy commitujemy offset, co robimy z błędem, jak budujemy nagłówki.

### Temat na kontekst zamiast tematu na typ zdarzenia

`news.integration` niesie wszystkie zdarzenia News, a typ jest w nagłówku `event-type`. Temat na typ (`news.article-created`) dałby dziesiątki tematów i, co gorsza, zgubiłby kolejność między różnymi zdarzeniami tego samego artykułu (utworzony, potem zrewidowany w dwóch tematach może przyjść w odwrotnej kolejności). Temat na kontekst z kluczem = id agregatu zachowuje kolejność. Wzór opisuje Confluent („Should You Put Several Event Types in the Same Kafka Topic?”).

### Ręczny commit offsetu i DLQ

Automatyczny commit zatwierdza offset co kilka sekund, niezależnie od tego, czy handler skończył. Awaria w tym oknie gubi wiadomość. Ręczny commit po zapisie do inboxa daje at-least-once, a inbox z [12-outbox-inbox.md](12-outbox-inbox.md) usuwa duplikaty. Wiadomość, która pada pięć razy z rzędu (zły kształt, błąd w kodzie), blokowałaby partycję na zawsze, bo Kafka nie pozwala pominąć jednej wiadomości bez przesunięcia offsetu. Dlatego po ostatniej próbie trafia do `*.dlq` z nagłówkami błędu, a konsument idzie dalej.

### `acks=all` i idempotentny producent

`acks=all` oznacza, że broker potwierdza zapis dopiero po replikacji na wszystkie repliki w synchronizacji. Na jednym brokerze to bez różnicy, ale konfiguracja jest gotowa na trzy. `enable.idempotence` sprawia, że ponowiona przez klienta wysyłka nie tworzy duplikatu w partycji. Obie opcje to domyślne zalecenia Confluent dla danych, których nie wolno zgubić.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.EventBus.Kafka/JJDevHub.EventBus.Kafka.csproj` | EventBus, `Confluent.Kafka`, `Microsoft.Extensions.Hosting.Abstractions` |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaOptions.cs` | `BootstrapServers`, `ConsumerGroup`, `SubscribedTopics`, `PublishedTopics`, `MaxDeliveryAttempts` |
| `src/building-blocks/JJDevHub.EventBus.Kafka/TopicNames.cs` | temat z nazwy zdarzenia, temat DLQ |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaHeaders.cs` | nazwy nagłówków i konwersja koperty |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaEventBus.cs` | producent |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaConsumerWorker.cs` | konsument w tle |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaTopicInitializer.cs` | tworzenie tematów przy starcie |
| `src/building-blocks/JJDevHub.EventBus.Kafka/KafkaServiceCollectionExtensions.cs` | `AddKafkaEventBus`, `AddKafkaConsumer` |
| `tests/JJDevHub.EventBus.Kafka.Tests/` | Testcontainers.Kafka |

## Plan

### 1. Projekt

```bash
dotnet new classlib -n JJDevHub.EventBus.Kafka -o src/building-blocks/JJDevHub.EventBus.Kafka -f net11.0
dotnet new xunit -n JJDevHub.EventBus.Kafka.Tests -o tests/JJDevHub.EventBus.Kafka.Tests -f net11.0
dotnet sln add src/building-blocks/JJDevHub.EventBus.Kafka tests/JJDevHub.EventBus.Kafka.Tests
dotnet add src/building-blocks/JJDevHub.EventBus.Kafka reference src/building-blocks/JJDevHub.EventBus
dotnet add src/building-blocks/JJDevHub.EventBus.Kafka package Confluent.Kafka
dotnet add tests/JJDevHub.EventBus.Kafka.Tests package Testcontainers.Kafka
```

Wersje `Confluent.Kafka` i `Testcontainers.Kafka` dochodzą do [Directory.Packages.props](../../Directory.Packages.props). `Testcontainers.Kafka` w tej samej wersji co `Testcontainers.PostgreSql`.

### 2. Tematy

`TopicNames.ForEvent("news.integration.article-created.v1")` zwraca `news.integration`: dwa pierwsze segmenty nazwy. Usługa publikuje na jeden temat swojego kontekstu. `TopicNames.DeadLetter("news.integration")` zwraca `news.integration.dlq`.

| Temat | Właściciel | Partycje | Konsumenci |
| --- | --- | --- | --- |
| `news.integration` | News | 3 | `notifications` |
| `identity.integration` | Identity | 3 | `notifications` |
| `*.dlq` | konsument | 1 | człowiek, przez Kafka UI |

Tabela pokazuje stan po tym numerze. [19-learning.md](19-learning.md) dodaje kompaktowany `learning.integration`, a [22-cv.md](22-cv.md) grupę `cv` przy `learning.integration` i `news.integration`. Pełna lista jest w [architektura.md](architektura.md).

Retencja tematów integracyjnych: 7 dni. Kafka nie jest źródłem prawdy. Źródłem są bazy usług, a outbox może wysłać ponownie.

`KafkaTopicInitializer : IHostedService` tworzy przy starcie `PublishedTopics` usługi i DLQ jej `SubscribedTopics` przez `IAdminClient.CreateTopicsAsync`. Wyjątek `CreateTopicsException` z kodem `TopicAlreadyExists` jest oczekiwany i pomijany. Broker na VM ma wyłączone `auto.create.topics.enable`, więc literówka w nazwie tematu kończy się błędem, nie nowym tematem.

### 3. Wiadomość

| Część | Wartość |
| --- | --- |
| klucz | `envelope.PartitionKey` |
| wartość | `envelope.Payload` (UTF-8 JSON) |
| nagłówek `event-id` | `EventId` |
| nagłówek `event-type` | `Name` |
| nagłówek `occurred-on` | `OccurredOn` w ISO 8601 |
| nagłówek `traceparent` | kontekst W3C z bieżącej `Activity` |

`KafkaHeaders` składa i rozkłada kopertę. Brak `event-id` albo `event-type` przy odczycie to wiadomość uszkodzona. Idzie do DLQ bez prób.

### 4. Producent

`KafkaEventBus(IProducer<string, string> producer) : IEventBus`, singleton. `PublishAsync`:

- `ProduceAsync(TopicNames.ForEvent(envelope.Name), message, cancellationToken)`,
- `ProduceException<string, string>` → `EventBusPublishException` z kodem błędu w treści,
- wynik inny niż `PersistenceStatus.Persisted` → `EventBusPublishException`.

Konfiguracja producenta:

- `Acks = Acks.All` — wiadomość jest potwierdzona dopiero, gdy zapiszą ją repliki,
- `EnableIdempotence = true` — ponowienie producenta nie dubluje wiadomości na partycji,
- `MessageTimeoutMs = 30000` — dispatcher outboxa ponowi przejście, nie producent w nieskończoność.

### 5. Konsument

`KafkaConsumerWorker : BackgroundService` dostaje `IOptions<KafkaOptions>`, `IServiceScopeFactory`, `ILogger` i fabrykę konsumenta. Konfiguracja:

- `GroupId = ConsumerGroup` (nazwa usługi: `notifications`),
- `EnableAutoCommit = false`, `AutoOffsetReset = Earliest`,
- `Subscribe(SubscribedTopics)`.

`Consume` blokuje wątek, więc `ExecuteAsync` uruchamia pętlę przez `Task.Factory.StartNew(…, TaskCreationOptions.LongRunning)`. W pętli:

- `Consume(stoppingToken)` → `ConsumeResult`,
- koperta z nagłówków; uszkodzona → DLQ, `Commit`,
- do `MaxDeliveryAttempts` (domyślnie 5) prób: nowy scope, `IIntegrationEventReceiver.ReceiveAsync`; wyjątek → log `Warning` i opóźnienie 2^n × 200 ms,
- po wyczerpaniu prób → produkcja na `{topic}.dlq` z nagłówkiem `error` (typ i treść wyjątku, do 2000 znaków),
- `Commit(result)` po `Handled`, `Duplicate`, `Ignored` albo po DLQ.

Commit po przetworzeniu oznacza, że awaria procesu w środku powtórzy wiadomość. Inbox zamieni powtórkę w `Duplicate`. Kolejna wiadomość z tej samej partycji czeka na koniec prób poprzedniej. To jest cena kolejności.

Wyjątek, którego worker nie potrafi obsłużyć (`KafkaException` z `IsFatal`), zatrzymuje pętlę i jest logowany jako `Critical`. Host się kończy, a Compose albo Aspire go restartują.

### 6. Skład

Producent (usługa z outboxem):

```csharp
services.AddKafkaEventBus(configuration, options => options.PublishedTopics = ["news.integration"]);
```

Konsument (usługa z inboxem):

```csharp
services.AddKafkaConsumer(configuration, options =>
{
    options.ConsumerGroup = "notifications";
    options.SubscribedTopics = ["news.integration"];
});
```

`BootstrapServers` pochodzi z `ConnectionStrings:kafka`. To ta sama nazwa, którą w [14-aspire.md](14-aspire.md) wstrzyknie Aspire. `AddKafkaEventBus` podmienia `IEventBus` z `InMemoryEventBus` na `KafkaEventBus`.

### Co jest do czego

- `TopicNames` — konwencja zamiast konfiguracji. Nazwa zdarzenia mówi, gdzie leci.
- klucz wiadomości — kolejność faktów jednego artykułu albo użytkownika.
- nagłówki — metadane bez rozpakowywania JSON-a. `event-type` wybiera handler, `traceparent` łączy ślad w Jaegerze od `POST` do konsumenta.
- `KafkaEventBus` — transport dla `OutboxDispatcher`. Rzuca tylko `EventBusPublishException`, więc dispatcher wie, kiedy ponowić.
- `KafkaConsumerWorker` — wejście wiadomości do usługi. Commit po przetworzeniu, ponowienia z opóźnieniem, DLQ na końcu.
- DLQ — miejsce na wiadomość, która blokowałaby partycję. Człowiek ogląda ją w Kafka UI i decyduje.
- `KafkaTopicInitializer` — tematy istnieją, zanim ktoś na nie wyśle.
- grupa konsumentów — każda usługa dostaje każdą wiadomość raz, niezależnie od innych.

## Testy

Projekt `tests/JJDevHub.EventBus.Kafka.Tests`. Kontener `KafkaBuilder` z Testcontainers.Kafka, jeden na klasę (`IClassFixture`). Tematy unikalne na test (`test-{guid}.integration`). `RecordingReceiver` zapisuje koperty i na żądanie rzuca.

Klasa `KafkaEventBusTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Publish_writes_to_topic_from_name` | temat utworzony | `PublishAsync` koperty `t.integration.x.v1` | konsument testowy czyta ją z `t.integration` |
| `Publish_sets_headers` | j.w. | `PublishAsync` | nagłówki `event-id` i `event-type` równe kopercie |
| `Same_key_goes_to_same_partition` | temat z 3 partycjami | dwie koperty z tym samym `PartitionKey` | ta sama partycja |
| `Missing_topic_throws_publish_exception` | brak tematu, auto-create wyłączone | `PublishAsync` | `EventBusPublishException` |

Klasa `KafkaConsumerWorkerTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Worker_passes_envelope_to_receiver` | worker uruchomiony, wiadomość na temacie | czekanie do 10 s | odbiorca dostał ten `EventId` |
| `Worker_commits_after_handling` | wiadomość przetworzona, worker zatrzymany | drugi worker tej samej grupy | odbiorca nie dostaje jej drugi raz |
| `Failing_receiver_sends_to_dlq` | odbiorca zawsze rzuca, `MaxDeliveryAttempts` 2 | czekanie | wiadomość na `{topic}.dlq` z nagłówkiem `error` |
| `Corrupt_message_goes_to_dlq_without_retry` | wiadomość bez `event-type` | czekanie | jedna wiadomość w DLQ, odbiorca nie wywołany |

`dotnet test tests/JJDevHub.EventBus.Kafka.Tests`.

## Zasady

- Temat wynika z nazwy zdarzenia. Usługa publikuje tylko na swój temat.
- Klucz wiadomości to `PartitionKey` z kontraktu.
- Offset jest commitowany po przetworzeniu, nigdy przed.
- Konsument nie rzuca wyjątku na nieznany typ. Odbiorca zwraca `Ignored`.
- Producent ma `acks=all` i idempotencję.
- Kafka nie jest źródłem prawdy. Retencja 7 dni, odtworzenie stanu idzie z baz usług.

## Poza zakresem

- Schema Registry i Avro. Kontrakty pilnuje snapshot JSON w [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).
- Transakcje Kafki (`exactly-once` między tematami). Outbox i inbox wystarczają.
- Ponowne wpuszczenie wiadomości z DLQ. Ręcznie przez Kafka UI albo skrypt, gdy będzie potrzebny.
- Klaster wielu brokerów. Na VM jest jeden broker w KRaft. Replikacja to `1`, a `acks=all` zaczyna znaczyć więcej przy kolejnych brokerach.

## Źródła

- [Apache Kafka documentation: design](https://kafka.apache.org/documentation/#design) — log, partycje, grupy konsumentów, gwarancje dostawy.
- [Confluent .NET client](https://docs.confluent.io/kafka-clients/dotnet/current/overview.html) — `IProducer`, `IConsumer`, konfiguracja `Acks`, `EnableIdempotence`, commit ręczny.
- [confluent-kafka-dotnet](https://github.com/confluentinc/confluent-kafka-dotnet) — przykłady producenta i konsumenta.
- [Kafka message delivery semantics](https://docs.confluent.io/kafka/design/delivery-semantics.html) — at-least-once przy commicie po przetworzeniu.
- [Dead letter queue](https://learn.microsoft.com/en-us/azure/architecture/patterns/retry#issues-and-considerations) — ponowienia z opóźnieniem i odłożenie wiadomości.
- [Testcontainers for .NET: Kafka](https://dotnet.testcontainers.org/modules/kafka/) — kontener brokera w teście.
- [W3C Trace Context](https://www.w3.org/TR/trace-context/) — nagłówek `traceparent` przez szynę.
- [dotnet/eShop — EventBusRabbitMQ](https://github.com/dotnet/eShop/tree/main/src/EventBusRabbitMQ) — adapter szyny za `IEventBus`, do porównania.

## Gotowe gdy

- Dispatcher outboxa News publikuje kopertę na `news.integration` z kluczem równym id artykułu.
- Konsument przekazuje kopertę do `IIntegrationEventReceiver` i commituje offset dopiero po przetworzeniu.
- Wiadomość, której nie da się przetworzyć, ląduje w `*.dlq` po `MaxDeliveryAttempts`.
- `JJDevHub.EventBus.Kafka` nie referencjonuje EF ani żadnej usługi.
- `dotnet test tests/JJDevHub.EventBus.Kafka.Tests` kończy się kodem 0.
