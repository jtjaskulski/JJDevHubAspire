# Wyszukiwanie

Wyszukiwanie po treści usługi Learning z [19-learning.md](19-learning.md): technologie, kursy, lekcje, wykłady i hasła. Jedno zapytanie SQL łączy dwie listy wyników. Pierwsza pochodzi z wyszukiwania pełnotekstowego Postgresa, druga z podobieństwa wektorów w pgvector. Łączy je Reciprocal Rank Fusion. Wektory liczy w procesie model ONNX za interfejsem `IEmbeddingGenerator` z `Microsoft.Extensions.AI`, bez klucza i bez zewnętrznego API. Filtr widoczności z [19-learning.md](19-learning.md) działa na obu listach. Następny numer to notatki w News, [21-notatki.md](21-notatki.md).

## Po co

Kompendium z setką haseł i kilkoma kursami bez wyszukiwania to spis treści. Student pamięta, że „było coś o rozdzieleniu zapisu od odczytu”, a nie że hasło nazywa się CQRS. Owner szuka w swojej prywatnej bazie wiedzy notatki o konfiguracji Kafki sprzed roku.

Polski jest trudny dla wyszukiwania słów. Postgres nie ma polskiego stemmera Snowball, więc „kolejka”, „kolejki” i „kolejką” to dla indeksu trzy różne słowa. Wyszukiwanie semantyczne nie porównuje słów, tylko znaczenie: zdanie z „kolejką wiadomości” leży w przestrzeni wektorów blisko „brokera komunikatów”. Z kolei wektor gubi dokładne nazwy: `IAsyncEnumerable`, `SKIP LOCKED`, numer błędu. Te łapie indeks słów. Każda metoda pokrywa słabość drugiej, więc system używa obu.

Wszystko zostaje w Postgresie, w bazie odczytu Learning. Indeks jest projekcją strumienia, więc przez chwilę po zapisie może go nie być, tak jak widok artykułu po `POST`. Filtr widoczności żyje w tym samym SQL-u co tekst projekcji.

## Dlaczego ta technologia

### Postgres zamiast osobnego silnika wyszukiwania

- **OpenSearch / Elasticsearch** — pełny silnik z analizatorem polskim (Stempel) i wektorami. Proces na JVM z co najmniej 1–2 GB RAM, drugi magazyn danych i potok synchronizacji. README trzyma OpenSearch poza projektem.
- **Meilisearch** (MIT) — lekki, z tolerancją literówek i wyszukiwaniem hybrydowym. Nadal drugi proces i drugi magazyn. Filtr widoczności trzeba by odtworzyć w jego składni i pilnować, żeby indeks nie wyprzedził bazy.
- **ParadeDB / `pg_search`** (BM25 w Postgresie) — licencja AGPL, poza listą dozwolonych licencji.
- **Postgres: `tsvector` + pgvector** — dokument wyszukiwania leży w `learning_read`, obok widoku treści. Jedna kopia zapasowa bazy odczytu, jeden filtr. Zapis komendy nie czeka na indeks.

Koszt: ranking pełnotekstowy Postgresa (`ts_rank_cd`) jest prostszy niż BM25, a polskiej fleksji nie obsługuje. Przy setkach i tysiącach dokumentów różnica w jakości jest mała, a fleksję pokrywa część semantyczna.

### Konfiguracja `simple` z `unaccent` dla polskiego

Postgres ma słowniki Snowball dla kilkunastu języków, ale nie dla polskiego. Słownik ispell z sjp.pl wymaga plików słownika w obrazie bazy i własnego obrazu. Konfiguracja `jjdevhub_pl` kopiuje `simple` (małe litery, bez stemmingu) i dokłada `unaccent`, więc „zdarzen” znajdzie „zdarzeń”. Konfiguracja `jjdevhub_en` kopiuje `english` ze stemmerem i też dokłada `unaccent`. Każdy dokument ma język, a kolumna `tsvector` wybiera konfigurację po języku.

`unaccent()` jako funkcja nie jest `IMMUTABLE`, więc nie może wejść do kolumny generowanej. Słownik `unaccent` w konfiguracji wyszukiwania może, bo `to_tsvector(regconfig, text)` ze stałą konfiguracją jest niezmienne. Stąd własna konfiguracja zamiast `to_tsvector('simple', unaccent(...))`.

Zapytanie przechodzi przez `websearch_to_tsquery`. Rozumie cudzysłowy, `or` i `-wyklucz`, a na dowolnym wejściu nie rzuca błędu składni. `to_tsquery` z tekstem od użytkownika kończyłoby się `500` przy pierwszym nawiasie.

### pgvector z indeksem HNSW

pgvector (licencja PostgreSQL) dodaje typ `vector(n)`, operatory odległości (`<=>` kosinusowa) i indeksy przybliżone. HNSW buduje graf sąsiedztwa: zapytanie przechodzi po grafie zamiast liczyć odległość do każdego wiersza. IVFFlat buduje się szybciej i zajmuje mniej miejsca, ale wymaga danych przy tworzeniu indeksu i traci jakość, gdy dane rosną. HNSW nie ma tych wad.

Przy kilku tysiącach fragmentów pełny skan trwa milisekundy i indeks nie jest konieczny. Jest w schemacie, bo zapytanie i plan wykonania mają być takie same przy stu tysiącach wierszy, a dodanie indeksu do dużej tabeli później to długa operacja.

Filtr widoczności i języka w `WHERE` przy indeksie przybliżonym to znany problem: indeks zwraca `ef_search` najbliższych, a filtr odrzuca część z nich, więc wyników może być mniej niż `LIMIT`. pgvector od wersji 0.8 ma iteracyjne skanowanie indeksu (`hnsw.iterative_scan = relaxed_order`): indeks przeszukuje dalej, aż filtr przepuści dość wierszy. Zapytanie ustawia to `SET LOCAL` w swojej transakcji.

Obraz bazy zmienia się z `postgres:16-alpine` na `pgvector/pgvector:pg16` (Postgres 16 z rozszerzeniem, na Debianie). Własny obraz Alpine z pgvector kompilowanym ze źródeł zachowałby bibliotekę C, ale to obraz do utrzymania i łatania. Zmiana biblioteki C (musl → glibc) zmienia porządek sortowania tekstu, więc katalog danych nie przechodzi między obrazami wprost. Na VM baza przechodzi przez `pg_dumpall` i odtworzenie (krok 10).

### Reciprocal Rank Fusion

Dwie listy mają nieporównywalne wyniki: `ts_rank_cd` to liczba bez górnej granicy, odległość kosinusowa leży w przedziale od 0 do 2. Ważona suma wymagałaby normalizacji, która zmienia się z każdym zapytaniem. RRF patrzy tylko na pozycje:

\[ \mathrm{score}(d) = \sum_{l \in \{\mathrm{fts}, \mathrm{vec}\}} \frac{1}{k + \mathrm{rank}_l(d)} \]

z \(k = 60\), jak w pracy Cormacka, Clarke'a i Büttchera. Dokument wysoko na obu listach wygrywa z dokumentem pierwszym na jednej. Dokument tylko z jednej listy dalej ma wynik. Całość to jedno zapytanie SQL z dwoma CTE i `FULL OUTER JOIN`.

Alternatywa jakościowo lepsza to reranker (cross-encoder, np. `bge-reranker`), który ocenia każdą parę zapytanie–dokument. Na CPU to setki milisekund na zapytanie przy trzydziestu kandydatach. Poza zakresem.

### `multilingual-e5-small` w ONNX zamiast zewnętrznego API

Treść jest głównie po polsku, a część to prywatna baza wiedzy ownera. Opcje:

- **OpenAI `text-embedding-3-small`, Azure OpenAI** — dobra jakość, ale płatny klucz, opóźnienie sieci przy każdym zapytaniu i treść prywatna wysyłana do zewnętrznej firmy.
- **Ollama** z modelem embeddingów — lokalnie, ale osobny proces z serwerem modeli i kolejną usługą do monitorowania.
- **`all-MiniLM-L6-v2`** — popularny, mały (384 wymiary), ale trenowany na angielskim. Polskie zdania dostają z niego słabe wektory.
- **`intfloat/multilingual-e5-small`** (MIT) — 384 wymiary, około stu języków z polskim, maksymalnie 512 tokenów wejścia. Repozytorium modelu ma gotowe eksporty ONNX, a wariant int8 ma 118 MB.

E5 wymaga prefiksów: `query: ` przed zapytaniem i `passage: ` przed dokumentem. Bez nich jakość spada. Prefiksy są w konfiguracji (`Search:QueryPrefix`, `Search:PassagePrefix`), bo inny model może ich nie chcieć.

Model działa w procesie przez ONNX Runtime (`Microsoft.ML.OnnxRuntime`, MIT). Tokenizer to SentencePiece z `Microsoft.ML.Tokenizers` (MIT). Plik modelu jest w obrazie usługi, przypięty sumą SHA-256, więc wchodzi do SBOM i atestacji z [docs/CICD/13-lancuch-dostaw.md](../CICD/13-lancuch-dostaw.md).

### `IEmbeddingGenerator` z `Microsoft.Extensions.AI`

`Microsoft.Extensions.AI` (MIT) to wspólne abstrakcje .NET dla modeli: `IChatClient` i `IEmbeddingGenerator<TInput, TEmbedding>`. Nasza klasa `OnnxEmbeddingGenerator` implementuje ten interfejs. Zamiana na OpenAI albo Ollamę to jedna rejestracja w DI, a handler zapytania jej nie zauważy.

Biblioteka daje też potok wokół generatora. `UseOpenTelemetry()` zapisuje każde liczenie wektorów jako span z atrybutami `gen_ai.*`, więc w Jaegerze widać, ile z 80 ms zapytania zajął model. `UseDistributedCache()` pamięta wektor dla tego samego tekstu: popularne zapytanie nie liczy się drugi raz.

Kolumna `EmbeddingModel` przy każdym fragmencie mówi, jakim modelem powstał wektor. Zmiana modelu w konfiguracji sprawia, że worker przelicza wszystko po kolei, a do tego czasu zapytania porównują tylko wektory z tego samego modelu.

### Dokumenty i fragmenty

Lekcja na trzy tysiące słów nie mieści się w 512 tokenach modelu, a jeden wektor dla całości rozmywa znaczenie. Tekst dzieli się na fragmenty po około 256 tokenów z zakładką 32 tokenów, na granicach akapitów. Każdy fragment dostaje tytuł dokumentu na początku i własny wektor. Wynik semantyczny dokumentu to jego najbliższy fragment.

Pełny tekst ma jeden `tsvector` na dokument, z tytułem o wadze `A` i treścią o wadze `B`.

### Indeks słów od razu, wektory w tle

`ContentProjection` z [19-learning.md](19-learning.md) po zrenderowaniu widoku woła `ISearchIndex.UpsertAsync` w tej samej transakcji co wiersz widoku. `tsvector` liczy Postgres w kolumnie generowanej. Wektory liczy `EmbeddingWorker` w tle, bo ONNX na lekcji z dwudziestoma fragmentami to sekunda pracy CPU. Po dogonieniu projekcji lekcja jest wyszukiwalna po słowach, a po kilku sekundach także po znaczeniu. Zapis w intranecie nie czeka na żaden z tych kroków.

## Klasy i ścieżki

| Plik | Odpowiedzialność |
| --- | --- |
| `src/services/Learning/Learning.Application/Search/SearchQuery.cs` | `Query`, `Language`, `Audience`, `Kinds`, `Limit` |
| `src/services/Learning/Learning.Application/Search/SearchQueryValidator.cs` | 2–200 znaków, `Limit` 1–20 |
| `src/services/Learning/Learning.Application/Search/SearchQueryHandler.cs` | wektor zapytania i `ISearchIndex.SearchAsync` |
| `src/services/Learning/Learning.Application/Search/SearchHit.cs` | `Kind`, slugi, tytuł, fragment, wynik, `MatchedBy` |
| `src/services/Learning/Learning.Application/Search/SearchDocumentInput.cs`, `SearchDocuments.cs` | agregat → dokumenty wyszukiwania |
| `src/services/Learning/Learning.Application/Search/EmbeddingInput.cs` | prefiksy `query: ` i `passage: ` z konfiguracji |
| `src/services/Learning/Learning.Application/Abstractions/ISearchIndex.cs` | `UpsertAsync`, `RemoveAsync`, `SearchAsync` |
| `src/services/Learning/Learning.Infrastructure/Search/SearchDocument.cs`, `SearchChunk.cs` | tabele |
| `src/services/Learning/Learning.Infrastructure/Search/PostgresSearchIndex.cs` | upsert, zapytanie hybrydowe z RRF |
| `src/services/Learning/Learning.Infrastructure/Search/SnippetFormatter.cs` | `ts_headline` → bezpieczny HTML z `<mark>` |
| `src/services/Learning/Learning.Infrastructure/Search/TextChunker.cs` | fragmenty po tokenach na granicach akapitów |
| `src/services/Learning/Learning.Infrastructure/Search/EmbeddingWorker.cs` | wektory dla zmienionych dokumentów |
| `src/services/Learning/Learning.Infrastructure/Embeddings/OnnxEmbeddingGenerator.cs` | `IEmbeddingGenerator<string, Embedding<float>>` na ONNX Runtime |
| `src/services/Learning/Learning.Infrastructure/Embeddings/OnnxEmbeddingOptions.cs` | ścieżki modelu i tokenizera, wątki, nazwa modelu |
| `src/services/Learning/Learning.Infrastructure/Data/Migrations/` | dochodzi `LearningSearch` na `LearningReadContext` |
| `src/services/Learning/Learning.API/Apis/SearchEndpoints.cs` | `GET /api/learning/search` |
| `infra/models/models.json`, `infra/models/download.sh` | model, rewizja, pliki i sumy SHA-256 |
| `tests/Learning.Infrastructure.Tests/Search/` | indeks na Postgresie z pgvector, worker, model |

## Plan

### 1. Pakiety i obraz bazy

```bash
dotnet add src/services/Learning/Learning.Application package Microsoft.Extensions.AI.Abstractions
dotnet add src/services/Learning/Learning.Infrastructure package Microsoft.Extensions.AI
dotnet add src/services/Learning/Learning.Infrastructure package Pgvector.EntityFrameworkCore
dotnet add src/services/Learning/Learning.Infrastructure package Microsoft.ML.OnnxRuntime
dotnet add src/services/Learning/Learning.Infrastructure package Microsoft.ML.Tokenizers
```

`Learning.Application` zna tylko abstrakcje `IEmbeddingGenerator`. ONNX, tokenizer i pgvector są w Infrastructure.

AppHost z [14-aspire.md](14-aspire.md):

```csharp
var postgres = builder.AddPostgres(ResourceNames.Postgres)
    .WithImage("pgvector/pgvector")
    .WithImageTag("pg16")
    .WithDataVolume();
```

Testy Learning dostają `new PostgreSqlBuilder("pgvector/pgvector:pg16")`. Pozostałe projekty testowe zostają na `postgres:16-alpine`, bo nie używają rozszerzenia.

### 2. Rejestracja kontekstu z pgvector

`AddNpgsqlDbContext` z Aspire nie przyjmuje opcji dostawcy Npgsql. Learning rejestruje kontekst sam i wzbogaca go potem o health check, ślady i metryki Aspire:

```csharp
builder.Services.AddDbContextPool<LearningReadContext>(options => options.UseNpgsql(
    builder.Configuration.GetConnectionString(ResourceNames.LearningRead),
    npgsql => npgsql.UseVector()));
builder.EnrichNpgsqlDbContext<LearningReadContext>(settings => settings.DisableRetry = true);
```

`LearningReadContext.OnModelCreating` dostaje `HasPostgresExtension("vector")` i `HasPostgresExtension("unaccent")`. Rozszerzenie jest w bazie odczytu, bo tam leży indeks.

### 3. Tabele

`SearchDocument` (`sealed`):

| Pole | Rola |
| --- | --- |
| `Id` | klucz |
| `Kind` | `technology`, `track`, `lesson`, `lecture`, `term` |
| `SourceId`, `Language` | unikalne razem z `Kind`; jeden dokument na element i język |
| `Slug`, `ParentSlug` | adres po stronie klienta (lekcja ma `ParentSlug` kursu) |
| `Title`, `PlainText` | tekst z `RenderedMarkdown.PlainText` z [19-learning.md](19-learning.md) |
| `Visibility` | widoczność efektywna (dla lekcji surowsza z kursu i lekcji) |
| `ContentHash` | SHA-256 z `Title` i `PlainText` |
| `EmbeddedHash`, `EmbeddingModel` | z jakiego tekstu i jakim modelem powstały obecne fragmenty |
| `SearchVector` | `tsvector`, kolumna generowana |
| `UpdatedOn` | kolejność pracy workera |

`SearchChunk` (`sealed`): `Id`, `DocumentId` (kaskada przy usunięciu dokumentu), `Ordinal`, `Text`, `Language`, `Visibility` (kopia z dokumentu, żeby filtr był w tej samej tabeli co indeks wektorów), `EmbeddingModel`, `Embedding` (`vector(384)`).

Migracja `LearningSearch`:

```sql
CREATE TEXT SEARCH CONFIGURATION jjdevhub_pl (COPY = simple);
ALTER TEXT SEARCH CONFIGURATION jjdevhub_pl
  ALTER MAPPING FOR asciiword, word, hword, hword_part, asciihword, hword_asciipart
  WITH unaccent, simple;

CREATE TEXT SEARCH CONFIGURATION jjdevhub_en (COPY = english);
ALTER TEXT SEARCH CONFIGURATION jjdevhub_en
  ALTER MAPPING FOR asciiword, word, hword, hword_part, asciihword, hword_asciipart
  WITH unaccent, english_stem;
```

Kolumna generowana przez `HasComputedColumnSql(..., stored: true)`:

```sql
setweight(to_tsvector(CASE WHEN "Language" = 'en' THEN 'jjdevhub_en'::regconfig ELSE 'jjdevhub_pl'::regconfig END, "Title"), 'A')
|| setweight(to_tsvector(CASE WHEN "Language" = 'en' THEN 'jjdevhub_en'::regconfig ELSE 'jjdevhub_pl'::regconfig END, "PlainText"), 'B')
```

Indeksy: GIN na `SearchVector`, HNSW na `Embedding` z `vector_cosine_ops` (`HasMethod("hnsw").HasOperators("vector_cosine_ops")`), B-tree na (`Language`, `Visibility`) w obu tabelach, częściowy na `UpdatedOn` `WHERE "EmbeddedHash" IS DISTINCT FROM "ContentHash"`.

### 4. Zapis dokumentów

`SearchDocuments.From(ContentView view)` zwraca dokument kursu i po jednym dokumencie na lekcję i język, w którym lekcja ma treść. Odpowiedniki są dla technologii, wykładu i hasła. Wejściem jest wiersz projekcji (czysty tekst już zrenderowany), nie agregat.

`ContentProjection` po zapisie widoku woła `UpsertAsync` albo `RemoveAsync` przy usunięciu. Ta sama transakcja bazy odczytu. Handler komendy tego nie widzi. Przebudowa widoku od pozycji 0 po zmianie `MarkdownRenderer.Version` woła ten sam upsert: zmieniony czysty tekst zmienia `ContentHash`, więc worker wektorów przeliczy fragmenty. Outboxa nie dotyka.

`PostgresSearchIndex.UpsertAsync`:

- `INSERT ... ON CONFLICT ("Kind", "SourceId", "Language") DO UPDATE` z nowym tytułem, tekstem, widocznością i `ContentHash`,
- dokumenty elementu, których nie ma w nowym zestawie (usunięta lekcja, usunięta wersja angielska), są usuwane,
- `UPDATE "SearchChunks" SET "Visibility" = ...` dla dokumentów, którym zmieniła się widoczność; wektory zostają, bo tekst się nie zmienił.

### 5. Generator wektorów

`OnnxEmbeddingGenerator(IOptions<OnnxEmbeddingOptions> options) : IEmbeddingGenerator<string, Embedding<float>>`, singleton:

- `InferenceSession` z `SessionOptions { IntraOpNumThreads = 2 }`, żeby model nie zajął wszystkich rdzeni VM,
- `SentencePieceTokenizer` z pliku `sentencepiece.bpe.model`, przycięcie do 512 tokenów,
- wejścia `input_ids` i `attention_mask` jako `DenseTensor<long>` dla całej paczki,
- wyjście `last_hidden_state` `[paczka, tokeny, 384]` → średnia po tokenach z maską → normalizacja L2,
- `GenerateAsync` zwraca `GeneratedEmbeddings<Embedding<float>>` z `ModelId` z opcji.

Rejestracja:

```csharp
builder.Services.AddDistributedMemoryCache();
builder.Services.AddEmbeddingGenerator(services => new OnnxEmbeddingGenerator(
        services.GetRequiredService<IOptions<OnnxEmbeddingOptions>>()))
    .UseDistributedCache()
    .UseOpenTelemetry();
```

ServiceDefaults dopisuje do śladów źródło `Experimental.Microsoft.Extensions.AI`, z którego `UseOpenTelemetry` wysyła spany.

`EmbeddingInput.ForQuery(string text)` i `ForPassage(string title, string chunk)` doklejają prefiksy z `Search:QueryPrefix` (`query: `) i `Search:PassagePrefix` (`passage: `).

### 6. Model w repozytorium i w obrazie

Plików modelu nie ma w gicie. `infra/models/models.json`:

```json
{
  "name": "intfloat/multilingual-e5-small",
  "revision": "<commit z Hugging Face>",
  "files": [
    { "path": "onnx/model_qint8_avx512_vnni.onnx", "target": "model.onnx", "sha256": "<suma>" },
    { "path": "onnx/sentencepiece.bpe.model", "target": "sentencepiece.bpe.model", "sha256": "<suma>" }
  ]
}
```

Rewizja to commit repozytorium modelu, nie gałąź `main`, więc ten sam manifest zawsze daje te same bajty.

Repozytorium modelu ma dwa eksporty ONNX: `onnx/model.onnx` (fp32, 470 MB) i `onnx/model_qint8_avx512_vnni.onnx` (int8, 118 MB), skwantyzowany pod instrukcje AVX-512 VNNI. Proxmox pokazuje te instrukcje maszynie wirtualnej tylko przy typie procesora `host`; domyślny `x86-64-v2-AVX` ich nie ma. Test `Embedding_latency_is_acceptable` mierzy czas na docelowej VM. Za wolno → manifest wskazuje wariant fp32.

`infra/models/download.sh` pobiera każdy plik z `https://huggingface.co/{name}/resolve/{revision}/{path}` do `src/services/Learning/Learning.API/models/` (w `.gitignore`) i sprawdza `sha256sum -c`. Niezgodna suma kończy skrypt kodem różnym od zera. `Learning.API.csproj` ma `<Content Include="models/**" CopyToPublishDirectory="PreserveNewest" />`, więc `dotnet publish -t:PublishContainer` z [18-ci-uslug.md](18-ci-uslug.md) wkłada model do obrazu. `OnnxEmbeddingOptions.ModelPath` domyślnie wskazuje `models/model.onnx` obok aplikacji.

`services.json` dostaje dla `learning` pole `"setup": "infra/models/download.sh"`. `_dotnet-service.yml` uruchamia je przed testami i przed publikacją obrazu. Katalog modelu trafia do `actions/cache` z kluczem z sumy `models.json`.

### 7. Worker wektorów

`EmbeddingWorker : BackgroundService`, pętla w nowym scope:

- `SELECT` do 8 dokumentów z `"EmbeddedHash" IS DISTINCT FROM "ContentHash" OR "EmbeddingModel" IS DISTINCT FROM @model`, po `UpdatedOn`, bez blokady wierszy,
- `TextChunker.Split(document.PlainText)`: akapity sklejane do 256 tokenów, zakładka 32 tokeny, akapit dłuższy niż limit dzielony po zdaniach,
- jedno `GenerateAsync` dla wszystkich fragmentów paczki,
- dla każdego dokumentu osobna transakcja: `DELETE` starych fragmentów, `INSERT` nowych, `UPDATE "SearchDocuments" SET "EmbeddedHash" = @hash, "EmbeddingModel" = @model WHERE "Id" = @id AND "ContentHash" = @hash`,
- zero zaktualizowanych wierszy w ostatnim kroku znaczy, że dokument zmienił się w trakcie liczenia: transakcja się wycofuje, a dokument wróci w następnej pętli,
- pusta paczka → `IdleDelay` 2 s.

Liczenie modelu nie trzyma blokad w bazie. Dwie instancje workera mogą policzyć ten sam dokument, a warunek na `ContentHash` sprawia, że zapis jednej z nich jest pusty.

Metryki: `jjdevhub_search_embedding_pending` (gauge, liczba dokumentów do przeliczenia) i `jjdevhub_search_embedding_duration_seconds` (histogram paczki). Panel w `infra/grafana/dashboards/jjdevhub-services.json` z [18-ci-uslug.md](18-ci-uslug.md).

### 8. Zapytanie hybrydowe

`PostgresSearchIndex.SearchAsync(SearchRequest request, ReadOnlyMemory<float> embedding)`. Transakcja tylko do odczytu, a w niej:

```sql
SET LOCAL hnsw.ef_search = 100;
SET LOCAL hnsw.iterative_scan = relaxed_order;
```

Zapytanie przez `Database.SqlQuery<SearchRow>($"...")` z parametrami:

```sql
WITH q AS (
  SELECT websearch_to_tsquery({config}::regconfig, {query}) AS tsq
),
fts AS (
  SELECT d."Id", row_number() OVER (ORDER BY ts_rank_cd(d."SearchVector", q.tsq) DESC) AS rank
  FROM "SearchDocuments" d, q
  WHERE d."Language" = {language} AND d."Visibility" = ANY({levels}) AND d."SearchVector" @@ q.tsq
  ORDER BY rank
  LIMIT 50
),
nearest AS (
  SELECT c."DocumentId", c."Embedding" <=> {embedding} AS distance
  FROM "SearchChunks" c
  WHERE c."Language" = {language} AND c."Visibility" = ANY({levels}) AND c."EmbeddingModel" = {model}
  ORDER BY c."Embedding" <=> {embedding}
  LIMIT 100
),
vec AS (
  SELECT "DocumentId" AS "Id", row_number() OVER (ORDER BY min(distance)) AS rank
  FROM nearest
  GROUP BY "DocumentId"
  LIMIT 50
),
fused AS (
  SELECT "Id",
         coalesce(1.0 / ({k} + fts.rank), 0) + coalesce(1.0 / ({k} + vec.rank), 0) AS score,
         fts.rank IS NOT NULL AS by_text,
         vec.rank IS NOT NULL AS by_meaning
  FROM fts FULL OUTER JOIN vec USING ("Id")
  ORDER BY score DESC
  LIMIT {limit}
)
SELECT d."Kind", d."Slug", d."ParentSlug", d."Title", f.score, f.by_text, f.by_meaning,
       ts_headline({config}::regconfig, d."PlainText", q.tsq,
                   'MaxFragments=2, MinWords=6, MaxWords=24, StartSel=' || chr(2) || ', StopSel=' || chr(3))
         AS snippet
FROM fused f JOIN "SearchDocuments" d USING ("Id"), q
ORDER BY f.score DESC;
```

`ts_headline` liczy się tylko dla wyników po `LIMIT`, bo na długich tekstach jest kosztowne. Filtr `Kinds` dochodzi do obu list, gdy zapytanie go podaje. `k` to `Search:RrfK`, domyślnie 60.

`SnippetFormatter.ToHtml(string snippet)` koduje cały fragment przez `HtmlEncoder.Default`, a dopiero potem zamienia znaki `\u0002` i `\u0003` na `<mark>` i `</mark>`. Lekcja o XSS z `<script>` w treści daje więc w wyniku `&lt;script&gt;`, a nie skrypt.

`SearchQueryHandler`: `EmbeddingInput.ForQuery(query)` → `generator.GenerateAsync` (z cache) → `SearchAsync`. `MatchedBy` w `SearchHit` mówi, która lista znalazła dokument (`text`, `meaning` albo obie). Pomaga przy strojeniu i pokazuje studentowi, jak działa wyszukiwanie hybrydowe.

### 9. Endpoint

| Metoda i ścieżka | Polityka | Wynik |
| --- | --- | --- |
| `GET /api/learning/search?q=&lang=pl&kind=lesson,term&limit=10` | anonimowo | `200` z listą `SearchHit`, `400` dla `q` krótszego niż 2 albo dłuższego niż 200 znaków, `429` |

`Audience` z `CurrentAudience` z [19-learning.md](19-learning.md). Odpowiedź ma `Cache-Control: private, no-store`, bo zależy od roli.

Najdroższy zasób to CPU modelu, a nie połączenia. Endpoint ma `RequireRateLimiting("search")` z limiterem współbieżności (`AddConcurrencyLimiter`, 4 równoczesne, kolejka 16). Pełna kolejka kończy się `429` z `Retry-After: 1`.

### 10. Zmiana obrazu bazy na VM

Katalog danych z obrazu Alpine (musl) nie przechodzi bezpiecznie do obrazu na Debianie (glibc): indeksy na kolumnach tekstowych są posortowane według innej biblioteki C. Jednorazowo, przed pierwszym wdrożeniem z tego numeru, zrzut wszystkich baz:

```bash
docker compose exec -T postgres pg_dumpall -U postgres > /var/backups/jjdevhub/pre-pgvector.sql
```

Dalsze kroki zależą od nazw wolumenów w Compose wygenerowanym przez Aspire:

- zatrzymanie usług,
- nowy wolumen danych dla `postgres`; stary zostaje nietknięty do czasu sprawdzenia,
- start samego `postgres` z obrazem `pgvector/pgvector:pg16` i odtworzenie: `docker compose exec -T postgres psql -U postgres < /var/backups/jjdevhub/pre-pgvector.sql`,
- start reszty usług i logowanie na istniejące konto,
- usunięcie starego wolumenu po tygodniu.

### 11. Testy na modelu w CI

Testy z prawdziwym modelem mają `[Trait("Category", "Model")]`. Lokalnie bez pobranego modelu uruchamia się `dotnet test --filter Category!=Model`. W CI model jest pobrany w kroku `setup`, więc biegną wszystkie.

### Co jest do czego

- `SearchDocument` — jeden wiersz na element i język. Ta sama tabela dla lekcji, haseł i wykładów, więc jedno zapytanie przeszukuje wszystko.
- `SearchVector` — indeks słów liczony przez Postgresa. Działa od commita.
- `jjdevhub_pl` i `jjdevhub_en` — polski bez stemmingu, ale bez znaczenia znaków diakrytycznych; angielski ze stemmerem.
- `SearchChunk` — fragment z wektorem. Długa lekcja nie rozmywa się w jednym wektorze.
- `OnnxEmbeddingGenerator` — model w procesie. Treść prywatna nie wychodzi z VM.
- `IEmbeddingGenerator` — miejsce na wymianę modelu albo dostawcy jedną rejestracją.
- `EmbeddingWorker` — wektory w tle, bez blokad w bazie na czas liczenia.
- `ContentHash` i `EmbeddingModel` — wiedza, który wektor jest nieaktualny.
- RRF w SQL — połączenie dwóch rankingów bez strojenia wag.
- `SnippetFormatter` — fragment z podświetleniem, który nie otwiera drogi dla XSS.
- limiter `search` — model nie zajmie całego CPU VM przy fali zapytań.
- `models.json` — model to zależność jak pakiet NuGet: wersja przypięta, suma sprawdzona.

## Testy

Projekt `tests/Learning.Infrastructure.Tests`, folder `Search/`. Kontener `pgvector/pgvector:pg16`, migracje `LearningReadContext`. `FakeEmbeddingGenerator` zwraca deterministyczne wektory: znormalizowany wektor z haszu słów, więc teksty z tymi samymi słowami są blisko, a inne daleko. Testy bez modelu nie zależą od jego jakości.

Klasa `PostgresSearchIndexTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Polish_text_ignores_diacritics` | dokument pl „Kolejka zdarzeń” | szukanie `zdarzen` | dokument na liście, `by_text` |
| `English_text_is_stemmed` | dokument en „Publishing events” | szukanie `publish` z `lang=en` | dokument na liście |
| `Websearch_syntax_never_throws` | dowolne dokumenty | szukanie `"&!(:*` i `a \| b` | brak wyjątku |
| `Visibility_filters_both_lists` | dokument `Private` najbliższy wektorowo i słownie | szukanie jako `Audience.Anonymous` | dokumentu nie ma |
| `Document_found_by_both_lists_ranks_first` | A na 2. miejscu obu list, B na 1. miejscu tylko słownie | `SearchAsync` | A przed B |
| `Meaning_only_match_is_returned` | dokument bez wspólnych słów, bliski wektorowo | `SearchAsync` | dokument z `MatchedBy` `meaning` |
| `Snippet_is_html_encoded` | tekst `<script>alert(1)</script> kafka` | szukanie `kafka` | fragment z `&lt;script&gt;` i `<mark>kafka</mark>` |
| `Other_model_vectors_are_ignored` | fragmenty z `EmbeddingModel` `old` | `SearchAsync` z modelem `new` | wynik tylko z listy słów |
| `Upsert_with_same_text_keeps_chunks` | dokument z fragmentami | `UpsertAsync` z tym samym tekstem | fragmenty te same, `EmbeddedHash` bez zmian |
| `Visibility_change_updates_chunks` | dokument `Public` z fragmentami | `UpsertAsync` z `Students` | wszystkie fragmenty `Students` |
| `Removed_lesson_removes_document` | kurs z dwiema lekcjami | `UpsertAsync` z jedną | jeden dokument lekcji, fragmenty drugiej usunięte |

Klasa `EmbeddingWorkerTests`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Worker_embeds_pending_documents` | dwa dokumenty bez fragmentów | jeden przebieg | fragmenty z wektorami 384, `EmbeddedHash` równe `ContentHash` |
| `Worker_skips_document_changed_meanwhile` | generator, który w trakcie zmienia tekst dokumentu | jeden przebieg | brak fragmentów, `EmbeddedHash` pusty |
| `Model_change_reembeds` | fragmenty modelu `old` | przebieg z modelem `new` | fragmenty modelu `new` |

Klasa `TextChunkerTests`, bez bazy.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Chunks_respect_token_limit` | tekst na 2000 tokenów | `Split` | każdy fragment ma co najwyżej 256 tokenów |
| `Chunks_overlap` | tekst na 600 tokenów | `Split` | ostatnie 32 tokeny fragmentu to początek następnego |
| `Short_text_is_one_chunk` | jeden akapit | `Split` | jeden fragment |

Klasa `OnnxEmbeddingGeneratorTests`, `[Trait("Category", "Model")]`, z prawdziwym modelem.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Tokenizer_matches_reference_ids` | „Zażółć gęślą jaźń” i id z referencyjnego tokenizera modelu zapisane w fixture | tokenizacja | te same id |
| `Embedding_has_384_unit_dimensions` | zdanie | `GenerateAsync` | 384 wartości, norma L2 równa 1 z dokładnością `1e-5` |
| `Embedding_latency_is_acceptable` | 32 fragmenty po 256 tokenów, po rozgrzaniu sesji | `GenerateAsync` | mediana poniżej 2 s na paczkę |
| `Related_sentences_are_closer` | „kolejka wiadomości”, „broker komunikatów”, „przepis na pierogi” | trzy wektory | pierwsze dwa bliżej siebie niż z trzecim |
| `Golden_queries_reach_threshold` | `Fixtures/search-golden.json`: zapytanie → oczekiwany slug, na treści z importu z [19-learning.md](19-learning.md) | `SearchAsync` dla każdego | MRR co najmniej progu z fixture |

Próg w `search-golden.json` ustala pierwszy przebieg i może tylko rosnąć. Zbiór zawiera zapytania, których nie znajdzie sama lista słów (np. „rozdzielenie zapisu od odczytu” → `cqrs`), i takie, których nie znajdzie sam wektor (dokładne nazwy typów).

Projekt `tests/Learning.API.Tests`, klasa `SearchEndpointTests`, z `FakeEmbeddingGenerator`.

| Fakt | Arrange | Act | Assert |
| --- | --- | --- | --- |
| `Anonymous_finds_public_lesson` | lekcja `Public` | `GET /search?q=...` | `200`, lekcja na liście |
| `Student_does_not_find_private_term` | hasło `Private` | `GET` z tokenem studenta | hasła nie ma |
| `Owner_finds_private_term` | hasło `Private` | `GET` z tokenem ownera | hasło jest |
| `One_letter_query_returns_400` | dowolnie | `GET ?q=a` | `400` |
| `Full_queue_returns_429` | limiter 1 + kolejka 0, generator czekający na sygnał | dwa równoczesne `GET` | drugi `429` z `Retry-After` |
| `New_lesson_is_found_by_text_before_embedding` | zapis lekcji i jeden przebieg projekcji, worker wektorów nie uruchomiony | `GET` po słowie z lekcji | lekcja na liście, `MatchedBy` `text` |

`dotnet test tests/Learning.Infrastructure.Tests` i `dotnet test tests/Learning.API.Tests`. Bez pobranego modelu: `dotnet test tests/Learning.Infrastructure.Tests --filter Category!=Model`.

## Zasady

- Dokument wyszukiwania powstaje w transakcji projekcji, razem z widokiem. Nie wyprzedza widoku. Zapis komendy go nie obejmuje, więc tuż po `POST` zapytanie może go jeszcze nie widzieć.
- Filtr widoczności jest w obu listach, przed `LIMIT`. Wynik nie zdradza istnienia treści niewidocznej.
- Zapytanie od użytkownika idzie tylko przez `websearch_to_tsquery` i parametry. Bez sklejania SQL.
- Fragment wyniku jest kodowany jako HTML przed wstawieniem `<mark>`.
- Wektor porównuje się tylko z wektorami tego samego modelu.
- Model jest przypięty rewizją i sumą SHA-256. Bez pobierania przy starcie usługi.
- Treść nie wychodzi poza VM do liczenia wektorów.

## Poza zakresem

- Reranker (cross-encoder) na kandydatach z RRF.
- Podpowiedzi przy pisaniu i tolerancja literówek (`pg_trgm` na tytułach jako trzecia lista RRF).
- Polski słownik ispell i własny obraz bazy.
- Wyszukiwanie w notatkach z [21-notatki.md](21-notatki.md). News ma własną bazę. Wspólne wyszukiwanie wymaga konsumpcji `news.integration` przez Learning albo osobnej usługi wyszukiwania.
- Odpowiedzi generowane przez model językowy na podstawie wyników (RAG). `IChatClient` z tej samej biblioteki jest naturalnym następnym krokiem.
- Pole wyszukiwania w kliencie — [docs/frontend/react/05-tresc-z-api.md](../frontend/react/05-tresc-z-api.md).

## Źródła

- [PostgreSQL: full text search](https://www.postgresql.org/docs/16/textsearch.html) — `tsvector`, konfiguracje, `websearch_to_tsquery`, `ts_rank_cd`, `ts_headline`.
- [PostgreSQL: unaccent](https://www.postgresql.org/docs/16/unaccent.html) — słownik w konfiguracji wyszukiwania.
- [pgvector](https://github.com/pgvector/pgvector) — typ `vector`, HNSW, `hnsw.iterative_scan`.
- [Pgvector for .NET](https://github.com/pgvector/pgvector-dotnet) — `Pgvector.EntityFrameworkCore`, `UseVector`.
- [Reciprocal Rank Fusion outperforms Condorcet and individual rank learning methods](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf) — Cormack, Clarke, Büttcher (SIGIR 2009), `k = 60`.
- [Text Embeddings by Weakly-Supervised Contrastive Pre-training](https://arxiv.org/abs/2212.03533) — praca o E5, prefiksy `query:` i `passage:`.
- [intfloat/multilingual-e5-small](https://huggingface.co/intfloat/multilingual-e5-small) — karta modelu, licencja, limit 512 tokenów.
- [Microsoft.Extensions.AI](https://learn.microsoft.com/en-us/dotnet/ai/microsoft-extensions-ai) — `IEmbeddingGenerator`, `UseOpenTelemetry`, `UseDistributedCache`.
- [ONNX Runtime C# API](https://onnxruntime.ai/docs/get-started/with-csharp.html) — `InferenceSession`, tensory wejścia.
- [Microsoft.ML.Tokenizers](https://learn.microsoft.com/en-us/dotnet/api/microsoft.ml.tokenizers) — `SentencePieceTokenizer`.
- [OpenTelemetry semantic conventions for generative AI](https://opentelemetry.io/docs/specs/semconv/gen-ai/) — atrybuty `gen_ai.*`.
- [Aspire: EnrichNpgsqlDbContext](https://learn.microsoft.com/en-us/dotnet/aspire/database/postgresql-entity-framework-integration#enrich-an-npgsql-database-context) — własna rejestracja kontekstu z telemetrią Aspire.
- [PostgreSQL wiki: locale data changes](https://wiki.postgresql.org/wiki/Locale_data_changes) — dlaczego zmiana biblioteki C wymaga odtworzenia indeksów.

## Gotowe gdy

- `aspire run` stawia Postgresa z obrazu `pgvector/pgvector:pg16`, a migracja `LearningSearch` tworzy rozszerzenia, konfiguracje i indeksy.
- Po przebiegu projekcji zapis lekcji jest w dokumencie wyszukiwania, a po kilku sekundach dochodzą fragmenty z wektorami.
- `GET /api/learning/search?q=zdarzen` znajduje dokument ze słowem „zdarzeń”, a zapytanie bez wspólnych słów znajduje hasło po znaczeniu.
- Anonim i student nie dostają w wynikach treści, której nie widzą na stronie.
- Obraz `learning-api` zawiera model z sumą zgodną z `models.json`.
- `dotnet test tests/Learning.Infrastructure.Tests` i `dotnet test tests/Learning.API.Tests` kończą się kodem 0.
