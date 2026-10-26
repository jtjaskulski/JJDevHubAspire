# Rejestr zdarzeń

Rejestr zamienia stabilną nazwę zdarzenia (`news.article-created.v1`) na typ CLR i z powrotem. Serializer zapisuje zdarzenie jako parę nazwa + JSON, a przy odczycie przepuszcza stare wersje przez upcastery. `EventTypeRegistry` trafia do `JJDevHub.Domain`, bo korzysta z niego też szyna z [12-outbox-inbox.md](12-outbox-inbox.md). `IEventSerializer` i `IEventUpcaster` trafiają do `JJDevHub.EventStore`. Nazwy nadaje atrybut z [01-zdarzenie.md](01-zdarzenie.md). Z serializera korzysta Postgres w [06-postgres.md](06-postgres.md).

## Po co

Wcześniejsza wersja tej specyfikacji zapisywała `AssemblyQualifiedName`. Pierwsze przeniesienie klasy do innego projektu albo zmiana namespace'u sprawiłyby, że żaden zapisany strumień by się nie odczytał. Nazwa z atrybutu jest kontraktem danych, a typ CLR szczegółem implementacji.

Drugi problem to ewolucja. Zdarzenie w bazie się nie zmienia, a kod tak. Upcaster to mała funkcja „JSON w wersji 1 → JSON w wersji 2”, wołana przy odczycie. Stare wiersze zostają nietknięte, a domena widzi tylko najnowszy kształt.

## Dlaczego ta technologia

### Rejestr nazw budowany przy starcie

Magazyn zapisuje nazwę `news.article-created.v1`, a przy odczycie musi wiedzieć, na jaki typ C# ją zdeserializować. Rejestr skanuje zestawy raz, przy starcie, i buduje dwie mapy: nazwa → typ i typ → nazwa. Duplikat nazwy albo zdarzenie bez atrybutu to wyjątek przy starcie, a nie cichy błąd przy pierwszym odczycie w nocy. Alternatywą jest `Type.GetType(nazwa)` w momencie odczytu, ale to właśnie jest stara zależność od nazwy CLR, którą ten numer usuwa.

Rejestr żyje w `JJDevHub.Domain`, bo używają go dwa światy: magazyn zdarzeń domenowych i szyna zdarzeń integracyjnych w [12-outbox-inbox.md](12-outbox-inbox.md). Oba mają atrybut `[EventName]`.

### System.Text.Json zamiast Newtonsoft.Json

System.Text.Json jest częścią platformy, szybszy i domyślny w ASP.NET Core. Newtonsoft.Json (MIT) ma więcej funkcji, m.in. `TypeNameHandling`, który wpisuje nazwę typu do JSON-a. To jest dokładnie to, czego nie chcemy, i znane źródło podatności przy deserializacji danych z zewnątrz. Opcje `JsonSerializerDefaults.Web` (camelCase) dają ten sam kształt JSON-a co API, więc wiersz w bazie czyta się jak odpowiedź HTTP.

### Upcasting na `JsonObject`

Zdarzenie `v1` zapisane rok temu nie ma pola, które `v2` uważa za wymagane. Są trzy drogi:

- trzymać w kodzie wszystkie stare klasy (`ArticleCreatedV1`, `V2`) i obsługiwać każdą w `Apply`: agregat puchnie z każdą wersją,
- przepisać dane w bazie migracją: niszczy niezmienność historii i jest ryzykowne,
- zamienić stary JSON na nowy w locie, przed deserializacją: to jest upcasting.

Wybieramy trzecią. `IEventUpcaster` dostaje `JsonObject` (modyfikowalne drzewo JSON z System.Text.Json) i nazwę, a zwraca nowy obiekt z nową nazwą. Łańcuch upcasterów prowadzi `v1 → v2 → v3`, więc agregat zna tylko najnowszą klasę. Wykrywanie cykli chroni przed pomyłką `v2 → v1`. Greg Young opisuje te techniki w *Versioning in an Event Sourced System*.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/building-blocks/JJDevHub.Domain/EventTypeRegistry.cs` | nazwa ↔ typ, walidacja przy starcie |
| `src/building-blocks/JJDevHub.EventStore/SerializedEvent.cs` | `Name`, `Json` |
| `src/building-blocks/JJDevHub.EventStore/IEventSerializer.cs` | `Serialize`, `Deserialize` |
| `src/building-blocks/JJDevHub.EventStore/IEventUpcaster.cs` | `FromName`, `ToName`, `Upcast` |
| `src/building-blocks/JJDevHub.EventStore/JsonEventSerializer.cs` | `System.Text.Json` + łańcuch upcasterów |
| `tests/JJDevHub.Domain.Tests/EventTypeRegistryTests.cs` | skanowanie i duplikaty |
| `tests/JJDevHub.EventStore.Tests/JsonEventSerializerTests.cs` | runda i upcasting |

## Plan

### 1. Rejestr

`EventTypeRegistry` jest `sealed`. Tworzy go fabryka:

```csharp
public static EventTypeRegistry FromAssemblies(Type marker, params Assembly[] assemblies)
```

- `marker` to `typeof(IDomainEvent)` albo, od numeru `12`, `typeof(IIntegrationEvent)`.
- Skanowane są konkretne typy przypisywalne do `marker`.
- Typ bez `[EventName]` → `InvalidOperationException` z nazwą typu.
- Dwa typy z tą samą nazwą → `InvalidOperationException` z obiema nazwami.

Metody: `string NameOf(Type type)` i `Type? TypeOf(string name)`. `NameOf` nieznanego typu rzuca, bo to błąd składu. `TypeOf` nieznanej nazwy zwraca `null`, a decyzję podejmuje serializer.

Rejestr powstaje raz, przy starcie, i jest singletonem. Błąd w atrybutach zatrzymuje aplikację przed pierwszym żądaniem, a nie przy pierwszym odczycie starego strumienia.

### 2. Serializer

```csharp
namespace JJDevHub.EventStore;

public interface IEventSerializer
{
    SerializedEvent Serialize(IDomainEvent domainEvent);

    IDomainEvent Deserialize(string name, string json);
}
```

`JsonEventSerializer` dostaje `EventTypeRegistry` i `IEnumerable<IEventUpcaster>` primary constructorem. Opcje JSON to `JsonSerializerDefaults.Web` (camelCase), jedna statyczna instancja.

- `Serialize` → `new SerializedEvent(registry.NameOf(type), JsonSerializer.Serialize(domainEvent, type, options))`.
- `Deserialize`:
  - parsuje `json` do `JsonObject`,
  - póki istnieje upcaster z `FromName == name`, woła `Upcast` i podmienia `name` na `ToName`,
  - po więcej niż `upcasters.Count()` krokach rzuca: łańcuch ma cykl,
  - `registry.TypeOf(name)` równe `null` → `InvalidOperationException`,
  - `payload.Deserialize(type, options)` rzutowane na `IDomainEvent`.

### 3. Upcaster

```csharp
namespace JJDevHub.EventStore;

public interface IEventUpcaster
{
    string FromName { get; }

    string ToName { get; }

    JsonObject Upcast(JsonObject payload);
}
```

Upcaster nie zna typów CLR. Pracuje na JSON-ie, bo stary typ zwykle już nie istnieje w kodzie. Przykład z testu: `news.article-created.v0` bez pola `authorIdentityGuid` → `v1` z tym polem równym `null`.

### 4. Rejestracja

Nie w tym numerze. Usługa rejestruje rejestr i serializer w [06-postgres.md](06-postgres.md):

```csharp
services.AddSingleton(EventTypeRegistry.FromAssemblies(typeof(IDomainEvent), typeof(Article).Assembly));
services.AddSingleton<IEventSerializer, JsonEventSerializer>();
```

### Co jest do czego

- `EventNameAttribute` (z `01`) — źródło nazw. Bez niego rejestr nie wystartuje.
- `EventTypeRegistry` — słownik w obie strony, sprawdzony przy starcie. Używają go serializer zdarzeń domenowych i outbox zdarzeń integracyjnych.
- `SerializedEvent` — to, co trafia do kolumn `EventType` i `Payload`.
- `IEventSerializer` — port. `PostgresEventStore` nie wie, czy pod spodem jest JSON i czy były upcastery.
- `IEventUpcaster` — most między starą a nową wersją. Dopisujesz go, gdy zdarzenie dostaje `v2`. Starych wierszy nie migrujesz.
- `JsonEventSerializer` — jedyna implementacja. Pilnuje kolejności: najpierw upcasting, potem typ.

## Testy

Klasa `EventTypeRegistryTests` w `tests/JJDevHub.Domain.Tests`. Typy testowe są zagnieżdżonymi deklaracjami w osobnym zestawie albo budowane przez dedykowany katalog `Fixtures/`. Każdy przypadek ma osobny zestaw typów, żeby duplikat nie psuł innych testów.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Registry_maps_name_to_type` | typ z `[EventName("test.a.v1")]` | `TypeOf("test.a.v1")` | ten typ |
| `Registry_maps_type_to_name` | ten sam typ | `NameOf` | `test.a.v1` |
| `Unknown_name_returns_null` | rejestr z jednym typem | `TypeOf("test.b.v1")` | `null` |
| `Missing_attribute_throws` | typ zdarzenia bez atrybutu | `FromAssemblies` | `InvalidOperationException` |
| `Duplicate_name_throws` | dwa typy z tą samą nazwą | `FromAssemblies` | `InvalidOperationException` |

Klasa `JsonEventSerializerTests` w `tests/JJDevHub.EventStore.Tests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Serialize_uses_attribute_name` | `SampleHappenedDomainEvent` | `Serialize` | `Name` równe nazwie z atrybutu |
| `Roundtrip_keeps_values` | zdarzenie z polami | `Serialize`, `Deserialize` | rekord równy wejściowemu |
| `Upcaster_fills_missing_field` | JSON `v0` bez pola, upcaster `v0 → v1` | `Deserialize("…v0", json)` | zdarzenie `v1` z polem `null` |
| `Unknown_name_throws` | pusty rejestr | `Deserialize("x.y.v1", "{}")` | `InvalidOperationException` |
| `Cyclic_upcasters_throw` | upcastery `a → b` i `b → a` | `Deserialize("a", "{}")` | `InvalidOperationException` |

`dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/JJDevHub.EventStore.Tests`.

## Zasady

- W bazie i na szynie leży nazwa z atrybutu. `GetType().FullName` ani `AssemblyQualifiedName` nie trafiają do danych.
- Rejestr waliduje się przy starcie. Błąd atrybutów zatrzymuje host.
- Upcaster pracuje na `JsonObject`, nie na typach CLR.
- Zapisany wiersz zdarzenia nigdy się nie zmienia. Ewolucja idzie przez upcaster przy odczycie.
- `JJDevHub.Domain` nadal nie ma `PackageReference`. `System.Text.Json` jest w `JJDevHub.EventStore`, z platformy.

## Poza zakresem

- Migracja starych wierszy na nowy kształt („copy and transform”). Upcasting przy odczycie wystarcza.
- Schema registry dla Kafki. Kontrakty integracyjne sprawdza snapshot w [17-uzytkownicy-i-powiadomienia.md](17-uzytkownicy-i-powiadomienia.md).
- Zapis do Postgresa — [06-postgres.md](06-postgres.md).

## Źródła

- [Versioning in an Event Sourced System](https://leanpub.com/esversioning/read) — Greg Young: słaby schemat, upcasting, nowe wersje zdarzeń.
- [Event Sourcing pattern — issues and considerations](https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing#issues-and-considerations) — wersjonowanie formatu zdarzeń.
- [System.Text.Json: JsonNode](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/use-dom) — praca na `JsonObject` bez typu docelowego.
- [Polymorphic serialization](https://learn.microsoft.com/en-us/dotnet/standard/serialization/system-text-json/polymorphism) — dlaczego nie używamy dyskryminatora CLR w samym JSON-ie.
- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html) — Martin Fowler: zmiany schematu a niezmienny log.

## Gotowe gdy

- `EventTypeRegistry.FromAssemblies` rzuca przy typie bez atrybutu i przy duplikacie nazwy.
- `JsonEventSerializer.Serialize` zwraca nazwę z atrybutu.
- Zdarzenie `v0` wraca z `Deserialize` jako aktualny typ dzięki upcasterowi.
- Cykl upcasterów kończy się wyjątkiem, nie pętlą.
- `dotnet test tests/JJDevHub.Domain.Tests` i `dotnet test tests/JJDevHub.EventStore.Tests` kończą się kodem 0.
