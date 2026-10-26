# 04 — CodeQL

## Po co

CodeQL ma znaleźć typowe dziury w C# (API) i TypeScript (React) zanim trafią na `main`. Wynik ląduje w zakładce **Security → Code scanning** na GitHubie. Ten krok nie wdraża nic na VM z [01-proxmox.md](01-proxmox.md) i nie rusza deployu z [03-github.md](03-github.md).

## Dlaczego ta technologia

### CodeQL zamiast samego lintera

CodeQL (korzenie w Semmle, dziś część GitHuba) traktuje kod jak dane. Ekstraktor składa bazę z plików, typów i krawędzi przepływu, a zapytania QL szukają ścieżki od wejścia żądania do wywołania, które wstawia ten argument do SQL, HTML albo ścieżki pliku. Aplikacja przy tym nie startuje. Linter (ESLint, analyzery Roslyn) przegrał jako jedyna kontrola: pilnuje stylu i wzorca w jednym pliku, a nie ścieżki przez kilka metod. Skan CVE paczek i obrazów jest w [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md), dług i pokrycie w [10-sonarqube.md](10-sonarqube.md). Żaden z nich nie odpowiada na pytanie, czy Twój kod składa niebezpieczną ścieżkę. Koszt: skan trwa kilka–kilkanaście minut, a brak alertu znaczy tylko, że włączony zestaw zapytań nic nie znalazł.

### Default setup zamiast własnego workflowu

Default setup jest konfiguracją w GitHubie, bez pliku w `.github/workflows/`. GitHub sam dobiera harmonogram i tryb bazy bez kompilacji. Własny `codeql.yml` przegrał na start: dokładają się dwa checki, gdy oba mechanizmy są włączone naraz, a hosted runner często nie ma .NET 11 preview, więc zgadywany `dotnet build` pada na restore. Plik workflow dochodzi dopiero, gdy default nie widzi obu języków albo skan C# wraca pusty. Koszt: prywatne repo potrzebuje produktu GitHub Code Security; publiczne dostaje code scanning w ramach GitHuba.

## Co już jest w repo

- VM, Docker i Compose: [01-proxmox.md](01-proxmox.md), plik [infra/docker/docker-compose.yml](../../infra/docker/docker-compose.yml).
- Tunel Cloudflare (tylko `4200`): [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).
- CI build/test i self-hosted deploy: [03-github.md](03-github.md), workflowy [api.yml](../../.github/workflows/api.yml), [web.yml](../../.github/workflows/web.yml), [deploy.yml](../../.github/workflows/deploy.yml).
- Kod skanowany: `src/api` (.NET 11 / C#), `src/Clients/web` (React 19 / TypeScript).
- Default setup CodeQL jest włączony dla C# i JavaScript/TypeScript (push i pull request na `main`). Pliku [`.github/workflows/codeql.yml`](../../.github/workflows/codeql.yml) nie ma i nie dodajesz go, dopóki ten setup jest zielony.

## Słownik pojęć z tego pliku

| Pojęcie | Znaczenie |
| --- | --- |
| CodeQL | Silnik analizy statycznej GitHuba. Buduje bazę z kodu, potem odpala zapytania szukające wzorców błędów. |
| Default setup | Konfiguracja CodeQL z panelu GitHuba, bez własnego pliku YAML. GitHub dobiera języki i harmonogram. |
| Advanced setup | Własny workflow `.github/workflows/codeql.yml`, gdy default nie widzi obu języków albo ścieżek. |
| Code scanning | Zakładka wyników w **Security**. Alerty, severity, ścieżka pliku, status (open / fixed). |
| SARIF | Format wyniku analizy. CodeQL wrzuca go automatycznie do code scanning. |
| Query suite | Zestaw zapytań (`default` vs `security-extended`). Na start wystarczy `default`. |

## Kroki

### 1. Uprawnienia repo

GitHub → repo **JJDevHub** → **Settings** → **Code security** (albo **Code security and analysis**).

Włącz:

- **Code scanning** (jeśli przełącznik jest osobno),
- ewentualnie **Dependabot alerts** zostaw na później — Dependabot jest w [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md).

Konto musi mieć prawo admina w repo (albo org policy pozwalającą włączyć code scanning).

### 2. Default setup — C# i TypeScript

W tej samej stronie: **Code scanning** → **Set up** → **Default**.

1. GitHub wykryje języki. Zaznacz **C#** oraz **JavaScript/TypeScript** (w UI bywa jedna pozycja „JavaScript / TypeScript”).
2. Ścieżki źródłowe zostaw domyślne albo wskaż:
   - C#: korzeń rozwiązania / `src/api`,
   - TypeScript: `src/Clients/web`.
3. Harmonogram: domyślny (zwykle sobota + skan po pushu na domyślną gałąź) wystarczy.
4. Query suites: **default**.
5. Zapisz (**Enable CodeQL** / **Save**).

Nie twórz jeszcze pliku workflow. Default setup sam dodaje konfigurację po stronie GitHuba.

### 3. Pierwszy skan

- Zmerguj albo zrób push na `main` (albo poczekaj na zaplanowany run).
- **Actions** → workflow **CodeQL** (nazwa może być „CodeQL” generowana przez default setup) → run ma być zielony.
- **Security** → **Code scanning** → pojawiają się alerty albo komunikat, że nie znaleziono problemów.

Dla C# default setup używa trybu `none`: baza powstaje ze źródeł, bez `dotnet build` i bez SDK z [global.json](../../global.json). To zwykle wystarcza. Jeśli skan C# jest pusty albo job pada (ekstraktor nie widzi solution, generatorów albo preview SDK), przejdź do kroku 4: `build-mode: manual` i `actions/setup-dotnet` jak w [api.yml](../../.github/workflows/api.yml).

### 4. Własny workflow tylko gdy default nie widzi obu języków

Użyj tej sekcji wyłącznie gdy:

- w default setup nie da się zaznaczyć obu języków, albo
- skan C# albo TypeScript jest stale pusty albo job pada na budowaniu (np. .NET 11 preview z [global.json](../../global.json)).

Wtedy wyłącz default setup (panel → Code scanning → konfiguracja CodeQL → Change / Disable default) i dodaj plik:

[`.github/workflows/codeql.yml`](../../.github/workflows/codeql.yml):

```yaml
name: codeql

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: "17 4 * * 1"

concurrency:
  group: codeql-${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read
  security-events: write
  actions: read

jobs:
  analyze:
    name: Analyze (${{ matrix.language }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
          - language: csharp
            build-mode: manual
          - language: javascript-typescript
            build-mode: none

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-dotnet@v4
        if: matrix.language == 'csharp'
        with:
          dotnet-version: "11.0.x"
          dotnet-quality: preview

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: ${{ matrix.language }}
          build-mode: ${{ matrix.build-mode }}
          queries: security-extended

      - name: Build C#
        if: matrix.language == 'csharp'
        run: |
          dotnet restore JJDevHub.sln
          dotnet build JJDevHub.sln --no-restore -c Release

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:${{ matrix.language }}"
```

Uwagi do tego pliku:

- `javascript-typescript` + `build-mode: none` — CodeQL czyta źródła TS/JS bez `pnpm build`.
- `csharp` + `manual` — ten sam restore/build co [api.yml](../../.github/workflows/api.yml). Tryb `none` (domyślny dla C#) nie uruchamia preview SDK; manual daje ekstraktorowi tę samą kompilację co CI.
- `permissions.security-events: write` jest wymagane do uploadu SARIF.
- Nie dodawaj tu Trivy, Dependabot ani deployu — to osobne numery.

Po pushu tego pliku: **Actions** → `codeql` → oba joby matrycy zielone, a **Security → Code scanning** pokazuje wyniki dla obu języków.

### 5. Branch protection (opcjonalnie, po pierwszym zielonym skanie)

Gdy chcesz blokować merge przy nowych alertach: **Settings** → **Branches** → reguła `main` → **Require code scanning results** / status check z CodeQL (nazwa checka zależy od default vs advanced). Nie mieszaj tego z checkami `api` i `web` z [03-github.md](03-github.md) — one zostają.

## Jak sprawdzić, że działa

1. **Actions**: co najmniej jeden udany run CodeQL (default albo `codeql.yml`) obejmujący C# i TypeScript / JavaScript.
2. **Security → Code scanning**: widać historię skanów; filtry języka pokazują oba ekosystemy (nawet przy zerze alertów).
3. Opcjonalny test: tymczasowy oczywisty problem (np. w C# `SqlCommand` ze sklejonym stringiem z requestu na martwej ścieżce nieużywanej w produkcji) → push na branch → alert w code scanning → usuń przed merge. Nie commituj świadomie dziury na `main`.

## Czego w tym pliku nie ruszać

- [deploy.yml](../../.github/workflows/deploy.yml), runnera, crona, `/etc/jjdevhub/api.env`.
- Tunelu Cloudflare i publicznych hostname’ów z [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md).
- Dependabot, Trivy, audytów NuGet/pnpm — [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md).
- Instrumentacji OpenTelemetry i Prometheusa — 06 i 07.
- Nie skanuj obrazów Dockera CodeQLem; do obrazów jest Trivy w 05.

## Następny numer

[05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md) — Dependabot, dependency review, Trivy, audyty, `permissions` i `concurrency` w `api.yml` / `web.yml`.

---

## Pełny tutorial: CodeQL (od zera)

Wybór CodeQL jest w [Dlaczego ta technologia](#dlaczego-ta-technologia). Tu zostaje, jak czytać alert i jak idzie jeden skan. Procedura włączenia jest w [Krokach](#kroki). Tutaj nie dodajesz drugiego workflowu.

### Źródło, zlew, bariera

Alert z przepływem danych ma trzy role:

- **Source** — miejsce, w którym wartość wchodzi z zewnątrz. W tym API: body minimal API (`RegisterRequest`, `LoginRequest`), query, nagłówek, route value.
- **Sink** — API, które robi coś groźnego z surowym stringiem: surowy SQL, `Process.Start`, zapis pliku pod ścieżką z requestu, HTML wstawiony bez escapowania.
- **Bariera (sanitizer)** — operacja, po której zapytanie uznaje wartość za bezpieczną. Dla SQL w EF Core barierą jest parametr, a nie „wygląda na email”.

Zapytanie QL szuka ścieżki source → sink, która **nie** przechodzi przez znaną barierę. Trzy konsekwencje:

1. Linq do EF (`UserManager`, `IdentityDbContext` w [AppDbContext.cs](../../src/api/Data/AppDbContext.cs)) buduje zapytanie z parametrami. Zwykłe `FirstOrDefaultAsync(u => u.Email == email)` nie jest sinkiem SQL injection.
2. Jeśli biblioteka nie jest opisana w modelach CodeQL, ścieżka urywa się za wcześnie (cichy false negative) albo kończy się alertem na nieszkodliwym wywołaniu (false positive). EF Core i React są modelowane; własnej paczki modelującej na start nie piszesz.
3. Brak alertu znaczy „żadne zapytanie z włączonego suite nie znalazło ścieżki”, a nie „aplikacja jest bezpieczna”. Autoryzacja typu „użytkownik A nie czyta rekordu użytkownika B” jest decyzją domenową. `RequireAuthorization()` na `GET /api/auth/me` w [AuthEndpoints.cs](../../src/api/Auth/AuthEndpoints.cs) CodeQL odnotuje jako atrybut, ale nie udowodni, że model uprawnień jest kompletny.

Metadane zapytania, które widać po kliknięciu reguły:

| Metadane | Co z tego wynika |
| --- | --- |
| Precision | `very-high` / `high` wchodzą do zestawu `default`. `medium` dokłada się w `security-extended` i daje więcej szumu. |
| Security severity | Liczba 0.0–10.0. W UI: od 9.0 Critical, 7.0–8.9 High, 4.0–6.9 Medium, poniżej 4.0 Low. |
| Problem severity | `error` / `warning` / `recommendation`. Zapytania jakości bez security severity pokazują się jako Warning albo Note. |
| Tags | M.in. identyfikatory CWE. Link z alertu prowadzi do opisu reguły i typowych false positive. |
| Kind | `path-problem` (jest ścieżka source → sink) albo `problem` (sam wzorzec, bez przepływu). |

Id reguły (`cs/sql-injection`, `js/xss-through-dom`, …) jest etykietą w alercie. Nazwy czasem się zmieniają między wersjami paczki. Źródłem prawdy jest link „Show rule” przy konkretnym trafieniu, nie lista zapamiętana z tego pliku.

### Przebieg jednego skanu

1. **Checkout.** Runner dostaje commit (na PR — merge commit PR-a z bazą, nie sam czubek gałęzi). Dzięki temu wynik dotyczy kodu, który realnie wylądowałby na `main`.
2. **Init** (`github/codeql-action/init`). Ściąga CLI CodeQL i paczkę zapytań dla języka, zakłada pustą bazę, a w trybie `manual` / `autobuild` włącza tracer: kolejne kompilacje w tym jobie są nagrywane do bazy.
3. **Build** — tylko gdy tryb go wymaga. Komendy stoją **po** init i **przed** analyze. `dotnet build` odpalony przed init nie wchodzi do bazy.
4. **Analyze** (`github/codeql-action/analyze`). Odpala suite, składa SARIF, uploaduje go. Do uploadu token joba potrzebuje `security-events: write`.
5. **Code scanning** skleja wynik z poprzednimi runami: ten sam problem w tym samym miejscu zostaje jednym alertem, zniknięcie ścieżki zamyka go jako fixed, a nowa ścieżka na PR dostaje adnotację.

Default setup chowa kroki 2–4. W Actions widać run „CodeQL”, ale YAML-a nie ma w repo. Advanced setup to workflow z [kroku 4](#4-własny-workflow-tylko-gdy-default-nie-widzi-obu-języków) — te same kroki, tylko jawne w logu.

Czas: małe repo zamyka się zwykle w kilku–kilkunastu minutach. C# z ręcznym buildem jest wolniejszy niż sam TypeScript. Minuta „17” w cronie (`17 4 * * 1` = poniedziałek 04:17 UTC) jest przesunięta celowo, żeby tysiące repo nie startowało równo o pełnej godzinie. Harmonogram odpala się wyłącznie z pliku workflow obecnego na gałęzi domyślnej; YAML z gałęzi feature się tu nie liczy.

### Trzy tryby buildu

| Tryb | Kiedy | C# w JJDevHub | JS/TS |
| --- | --- | --- | --- |
| `none` | Baza ze źródeł, bez kompilacji. | Tryb **default setup**. Nie potrzebuje SDK z [global.json](../../global.json). | Jedyny sensowny tryb. Ekstraktor parsuje `.ts` / `.html` / `.js`. |
| `autobuild` | CodeQL sam zgaduje `dotnet build` / Maven / Gradle. | Hosted runner często nie ma .NET 11 preview, więc zgadywanie pada na restore. | Nie używasz. |
| `manual` | Build wpisujesz sam, między init a analyze. | Przepis advanced. Te same komendy co [api.yml](../../.github/workflows/api.yml), więc ekstraktor widzi tę samą kompilację co CI, łącznie z projektami z [JJDevHub.sln](../../JJDevHub.sln). | Zbędny. `pnpm build` Vite nie poprawia bazy CodeQL. |

`none` dla C# jest pełnoprawnym trybem (C/C++, C#, Java i Rust umieją budować bazę bez kompilatora). Sięgasz po `manual`, gdy log ekstrakcji C# jest pusty albo pomija projekty, a nie „bo dokumentacja kiedyś wymagała buildu”.

### Default setup i advanced setup

**Default** — konfiguracja po stronie GitHuba, bez pliku w `.github/workflows/`. UI: **Settings → Code security** (etykieta bywa też „Code security and analysis” albo „Advanced Security”) → **Code scanning → Set up → Default**. Zaznaczasz C# oraz JavaScript/TypeScript, suite **Default**, zapisujesz. GitHub sam dobiera harmonogram (push na gałąź domyślną plus tygodniowy cron) i tryb `none`.

**Advanced** — commitujesz workflow. Ma sens, gdy:

- default nie daje zaznaczyć obu języków,
- skan C# wraca pusty albo pada na preview SDK,
- chcesz jawny `pull_request`, inny cron, albo `paths-ignore` dla generowanego kodu.

Włączone naraz dają dwa niezależne wyniki i dwa checki na PR. Przed commitem `codeql.yml` wyłącz default (konfiguracja CodeQL → Disable / Change). Jeden mechanizm na repo.

Przepis w kroku 4 pinuje `github/codeql-action` na `@v3`. Aktualny szablon GitHuba pokazuje `@v4`. Na poziomie tego tutorialu (`init`, `analyze`, `languages`, `build-mode`) majory działają tak samo. W jednym pliku trzymaj jeden major — `init@v3` z `analyze@v4` się rozjeżdża. Podbijasz oba albo żadnego.

### Co w tym repo w ogóle wchodzi do skanu

Osobna baza na język. Matryca w YAML odpala je równolegle; `fail-fast: false` sprawia, że padnięty C# nie ubija joba TypeScript.

**C#** (`csharp`) — projekty, które wejdą do bazy:

- [src/api](../../src/api) — minimal API, Identity, JWT, EF Core + Npgsql,
- [tests/JJDevHub.Api.Tests](../../tests/JJDevHub.Api.Tests) — bo `dotnet build JJDevHub.sln` buduje też testy,
- migracje w `src/api/Data/Migrations` — wygenerowany C#, częste źródło szumu.

Zapytania, które mają tu realną szansę zagadać, gdy kod się zmieni: surowy SQL (`ExecuteSqlRaw` / `FromSqlRaw` i string sklejony z requestu), wstrzyknięcie do procesu, ścieżka pliku z wejścia HTTP, SSRF (`HttpClient` z URL-em od klienta), zahardkodowany sekret, słaba kryptografia, deserializacja binarna. Odpowiedź JSON z tego API nie jest stroną HTML, więc reguły XSS dla Razor zostaną ciche, dopóki nie zaczniesz zwracać markupu.

**JavaScript/TypeScript** (`javascript-typescript`) — ekstraktor idzie po plikach w checkout, nie po jednym projekcie Reacta:

- [src/Clients/web](../../src/Clients/web) — React 19 + Vite, cel z kroków wyżej,
- [src/Clients/mobile](../../src/Clients/mobile) — React Native, też TypeScript; default setup z ścieżką ustawioną tylko na `src/Clients/web` go pominie, advanced YAML z kroku 4 (bez `paths`) go zobaczy,
- [src/Clients/shared](../../src/Clients/shared) — współdzielony motyw,
Identyfikatory `javascript` i `typescript` są aliasami `javascript-typescript`. Wpisanie `javascript` **nie** wyłącza analizy `.ts`.

React escapuje tekst w JSX. Sinkami, których szukają reguły XSS, są m.in. `dangerouslySetInnerHTML`, `document.write`, `eval`. W tym repo tych wywołań dziś nie ma — cichy skan frontu jest zgodny ze stanem kodu, a nie dowodem, że UI jest skończone.

Jest jeszcze język `actions` (zapytania pod kątem wstrzyknięcia w `run:` workflowów). Przepis go nie włącza.

### Zestawy zapytań

| Suite | Skład | Kiedy |
| --- | --- | --- |
| `default` | Wysoka precyzja, mało false positive. | Default setup. Zostaw na pierwsze tygodnie. |
| `security-extended` | Wszystko z `default` plus zapytania o niższej precyzji i niższym severity. W UI default setup nazywa się „Extended”. | Przepis advanced w kroku 4. Szersza sieć, głośniejszy triaż. |
| `security-and-quality` | `security-extended` plus utrzymanie i niezawodność. | Pokrywa się z Sonarem. W tym numerze go nie włączasz. |

Pole `queries: security-extended` **dokłada** suite do zestawu domyślnego (a sam suite i tak jest nadzbiorem `default`). Żeby zostać przy samym `default`, usuń linię `queries:` — silnik i tak odpali zestaw domyślny. Low i Note z extended nie muszą blokować merge; jeśli szum zasłania trafienia, zdejmij tę linię zamiast wyłączać całego CodeQL.

### YAML z kroku 4, klucz po kluczu

Szkielet, który zostaje w głowie:

```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: csharp
    build-mode: manual
# restore + build solution — tylko dla csharp, już po init
- uses: github/codeql-action/analyze@v3
  with:
    category: "/language:csharp"
```

Dla `javascript-typescript` między init a analyze nie ma komend. Reszta pliku:

| Fragment | Po co |
| --- | --- |
| `on.push` + `on.pull_request` na `main` | Push zamyka dług na gałęzi domyślnej. PR daje adnotację zanim kod wejdzie. Sam `push` pokazuje dziurę dopiero po merge. |
| `on.schedule` | Ten sam kod, nowsze zapytania — reguły dochodzą w paczce CodeQL nawet bez Twojego commita. |
| `concurrency` + `cancel-in-progress` | Nowy push na ten sam ref anuluje poprzedni skan. Anulowany run nie jest zielonym skanem. |
| `permissions.contents: read` | Checkout. Token nie dostaje zapisu do repo. |
| `permissions.security-events: write` | Upload SARIF. Bez tego analyze kończy się błędem uprawnień. |
| `permissions.actions: read` | Na prywatnym repo action ściąga przez to API paczkę CodeQL. |
| `packages: read` | W przepisie jej nie ma. Dołóż, gdy init padnie 403 przy ściąganiu paczek z `ghcr.io`. |
| `strategy.matrix` | Jedna para język + tryb buildu = jeden job. |
| `runs-on: ubuntu-latest` | Czysty hosted runner. Runner z [03-github.md](03-github.md) jest od deployu na VM; CodeQL go nie zajmuje. |
| `category` | Kanał wyniku w SARIF. Bez tego pola GitHub i tak składa kategorię z nazwy workflow i zmiennych matrycy, więc dwa joby zwykle się nie nadpiszą. Jawny `/language:…` zostaje: stabilny identyfikator, niezależny od nazwy pliku. Nadpisanie jest realne, gdy dwa `analyze` tego samego refu dostaną identyczną category (dwa języki w jednym jobie, skopiowany YAML bez matrycy). |
| `if: matrix.language == 'csharp'` | `setup-dotnet` i build nie odpalają się w jobie TypeScript. |

`pull_request` z forka zewnętrznego kontrybutora dostaje token bez `security-events: write`, więc upload SARIF padnie. Na jednoosobowym prywatnym repo to się praktycznie nie zdarza.

Filtr `paths` / `paths-ignore` na `on:` decyduje, **czy job w ogóle wstanie**. Nie decyduje, które pliki wejdą do bazy, gdy job już wstanie. PR złożony z samych `.md` i tak przeskanuje cały kod, jeśli workflow nie ma `paths-ignore`. To inne ustawienie niż `paths-ignore` w pliku konfiguracji CodeQL (niżej).

### Jak czytać alert

**Security → Code scanning →** otwarty alert.

1. **Tytuł i rule id.** Jedno zdanie, co za wzorzec. Otwórz opis reguły zanim cokolwiek zmienisz w kodzie — jest tam sekcja o typowych false positive.
2. **Severity.** Kolejność triażu. Critical/High na ścieżce z requestu do sinku ogarniasz przed merge. Medium czytasz. Low/Note z `security-extended` często zostają na później.
3. **Plik i linia.** To zwykle sink albo miejsce, które QL uznał za reprezentanta problemu. Przy `path-problem` linia sama nie wystarcza.
4. **Show paths.** Lista kroków: source (np. parametr `[FromBody]`), pośrednie przypisania i wywołania, sink. Kilka ścieżek to kilka sposobów dojścia do tego samego sinku — wystarczy przeciąć tę, która jest prawdziwa; reszta zniknie przy następnym skanie, jeśli dzieliły barierę.
5. **Gałąź.** Alert na `main` to dług. Alert tylko na PR to coś, co dokłada ten PR (porównanie z analizą bazy).

Potem jedna z trzech decyzji:

- **Poprawka.** Przecinasz ścieżkę (parametr zamiast sklejenia, tekst zamiast surowego HTML). Nie klikasz Dismiss. Następny skan tej gałęzi sam zamknie alert jako fixed — widać, że poprawka zadziałała.
- **Dismiss.** Zostawiasz kod. UI wymaga powodu: false positive (ścieżka w praktyce niemożliwa), won't fix (świadomie akceptujesz), used in tests (wzorzec żyje tylko w teście). Jedno zdanie, dlaczego. Dismissal nie kasuje historii.
- **Nie ruszaj**, gdy severity jest niskie i ścieżka nie wychodzi z requestu. Otwarty alert w zakładce jest lepszy niż dismiss „na potem”, którego nikt nie odtworzy.

Stan w UI: **open**, albo **closed** jako **fixed** (kolejny skan gałęzi domyślnej już tej ścieżki nie widzi) lub **dismissed**. Ten sam wzorzec w nowym miejscu to nowy alert; stary dismiss go nie przykrywa.

### Przykład: surowy SQL w C#

Tego kodu w repo nie ma. Tak wygląda ścieżka, którą `cs/sql-injection` umie pokazać, gdyby doszła do API:

```csharp
group.MapPost("/lookup", async (LookupRequest request, AppDbContext db) =>
{
    var sql = $"SELECT * FROM \"AspNetUsers\" WHERE \"Email\" = '{request.Email}'";
    await db.Database.ExecuteSqlRawAsync(sql);
    return Results.Ok();
});
```

Source: `request.Email` z body. Sink: `ExecuteSqlRawAsync` ze stringiem złożonym interpolacją — w tym miejscu interpolacja zdążyła już stać się zwykłym `string`, więc EF nie ma czego parametryzować. W UI ścieżka ma dwa kroki i severity z górnej półki.

Linq, którym to API już mówi do Identity, bariery nie potrzebuje, bo samo jest parametryzowane:

```csharp
var user = await users.FindByEmailAsync(request.Email);
```

Gdy naprawdę potrzebujesz surowego SQL-a, zostawiasz interpolację jako `FormattableString`, który EF zamienia na parametr:

```csharp
await db.Database.ExecuteSqlInterpolatedAsync(
    $"SELECT * FROM \"AspNetUsers\" WHERE \"Email\" = {request.Email}");
```

Różnica między tymi dwoma wywołaniami jest dokładnie tym, czego pilnuje zapytanie: `ExecuteSqlRaw` + gotowy `string` kontra `ExecuteSqlInterpolated` + wartość obok SQL-a. Sklejenie przez `string.Format` albo `+` wpada do tej samej klasy co pierwszy snippet.

Sprawdzenie, że skaner żyje: taki endpoint na **osobnej gałęzi**, push, alert w code scanning, usunięcie commita przed jakimkolwiek merge. Na `main` tego nie zostawiasz.

### Przykład: HTML w Reactcie

Tego kodu w `src/Clients/web` też nie ma. Reguły XSS dla DOM szukają właśnie takiej pary:

```tsx
const q = new URLSearchParams(location.search).get("q") ?? "";
return <div dangerouslySetInnerHTML={{ __html: q }} />;
```

Source: query param. Sink: HTML wstawiony z pominięciem escapowania JSX. Zwykły `{q}` w JSX escapuje tekst i tej ścieżki nie tworzy. `dangerouslySetInnerHTML` na stałym literale z Twojego pliku (bez danych z URL-a) bywa false positive — dismiss z komentarzem, albo zostawiasz alert, jeśli literał i tak nie powinien iść do DOM.

### Sekret w źródle a sekret w konfiguracji

[Program.cs](../../src/api/Program.cs) czyta `Jwt:Key` z konfiguracji i odrzuca klucz krótszy niż 32 znaki. To jest kształt, który zapytania o zahardkodowane poświadczenia zostawiają w spokoju: w repo nie ma wartości sekretu, jest nazwa sekcji.

Literal w kodzie, obok nazwy w stylu `key` / `password` / `secret`, te zapytania zgłaszają:

```csharp
var key = "this-is-a-hardcoded-secret-key-32b";
```

Miejsce na wartość to env na VM (`/etc/jjdevhub/api.env` z dokumentu deployu), nie commit. CodeQL nie czyta plików poza gitem i nie zastępuje secret scanningu.

### Ścieżki, generowany kod, testy

Bez pliku konfiguracji językowy job ogląda cały checkout (C# — to, co zbudowałeś; JS/TS — wszystkie źródła). Dwa katalogi warto w końcu wyciszyć, gdy alerty z nich zaczną zaśmiecać listę:

- `src/api/Data/Migrations` — kod z `dotnet ef`,
- wygenerowany klient HTTP, jeśli kiedyś wróci do `src/Clients/web` — dziś login i register wołają `fetch` i takiego pliku nie ma.

Robi to konfiguracja CodeQL, nie filtr `on:`. Przy advanced setup:

```yaml
# .github/codeql/codeql-config.yml
name: JJDevHub CodeQL
paths-ignore:
  - src/api/Data/Migrations
  - src/Clients/web/src/app/api/jjdevhub-api.client.ts
```

```yaml
- uses: github/codeql-action/init@v3
  with:
    languages: ${{ matrix.language }}
    build-mode: ${{ matrix.build-mode }}
    config-file: ./.github/codeql/codeql-config.yml
```

`paths-ignore` działa w obu jobach matrycy, więc migracje wypadają z C#, a klient z TypeScript. Pułapka: jeden `paths:` ustawiony na `src/Clients/web` oślepi job C#, bo ta ścieżka nie zawiera `src/api`. Osobne pliki konfiguracji na język mają sens dopiero wtedy. `node_modules`, `dist`, `bin` i `obj` i tak nie są w git; ignorowanie ich w konfiguracji nic nie zmienia, dopóki ktoś nie zacznie ich commitował.

Testy zostaw w skanie. Gdy trafienie siedzi wyłącznie w `tests/JJDevHub.Api.Tests` i celowo składa zły string, dismiss z powodem **Used in tests**. Helper skopiowany później do `src/` dostanie już własny, otwarty alert.

### Model zagrożeń: remote i local

Dla C# (i Javy) CodeQL ma przełącznik **threat model**. Domyślny `remote` traktuje jako source to, co przychodzi spoza procesu: request HTTP, body, query. To jest model tego API.

`local` dokłada źródła lokalne (pliki na dysku, argumenty procesu). Przy samym serwerze HTTP dokładają alerty, których i tak nie wystawiasz na sieć. Zostawiasz domyślny. W advanced włącza się go w konfiguracji (`threat-models: local`) — na start tej linii nie dodajesz.

### PR, check i blokada merge

Na PR dzieją się dwie niezależne rzeczy:

1. **Check statusu** — job `Analyze (csharp)` / `Analyze (javascript-typescript)` (albo jeden run „CodeQL” przy default setup) jest zielony, gdy analiza **się dokończyła i wgrała SARIF**. Zielony check przy otwartych alertach jest normalny. Czerwony check to padnięty job (SDK, uprawnienia, timeout), a nie „znaleziono SQL injection”.
2. **Wynik code scanning** — nowe alerty względem bazy pojawiają się jako adnotacje na diffie. Stary dług z `main` widać w zakładce Security; PR, który tego pliku nie dotyka, nie dostaje od niego adnotacji.

Blokadę merge dokładają osobno **Settings → Rules → Rulesets** (albo klasyczna reguła gałęzi): „Require code scanning results” pilnuje, żeby skan w ogóle dobiegł, a próg severity pilnuje, żeby nowy Critical/High nie wszedł. Nazwa checka zależy od tego, czy działa default, czy Twój YAML — wpisujesz tę, którą PR już pokazuje na zielono. Checków `api` i `web` z [03-github.md](03-github.md) to nie zastępuje.

Kolejność na koniec pierwszego tygodnia: najpierw jeden zielony skan obu języków, potem dopiero reguła. Włączenie blokady zanim pierwszy run w ogóle przejdzie, zatrzymuje merge na brakującym checku.

### CLI lokalnie

Do JJDevHub nie jest potrzebne — wynik ma lądować w code scanning na GitHubie. CLI przydaje się, gdy chcesz zobaczyć bazę u siebie albo odpalić jedno zapytanie bez pusha.

Paczkę bierzesz z dokumentacji „CodeQL CLI” (osobny bundle, nie `dotnet tool`). Wersja CLI i paczka zapytań muszą do siebie pasować; rozjazd kończy się błędem przy analyze, nie pustym wynikiem.

```bash
codeql version

# C#: build wchodzi do bazy, więc --command jest trybem manual
codeql database create db-csharp \
  --language=csharp \
  --source-root=. \
  --command='dotnet build JJDevHub.sln -c Release'

codeql database analyze db-csharp \
  --format=sarif-latest \
  --output=csharp.sarif \
  --download \
  codeql/csharp-queries:codeql-suites/csharp-security-extended.qls

# React: bez vite build
codeql database create db-js \
  --language=javascript-typescript \
  --source-root=src/Clients/web \
  --build-mode=none

codeql database analyze db-js \
  --format=sarif-latest \
  --output=js.sarif \
  --download \
  codeql/javascript-queries:codeql-suites/javascript-security-extended.qls
```

Katalog `db-csharp/` waży setki megabajtów. Nie commitujesz go ani plików `*.sarif`. Do podejrzenia wystarczy wyszukać w SARIF pole `ruleId`. Rozszerzenie CodeQL do VS Code umie odpalać zapytania na takiej bazie — nadal opcjonalnie, poza CI.

Własnych zapytań na start nie piszesz. Dla skali: QL nie jest C#. Poniższe tylko pokazuje kształt i **nie** jest regułą do commita (prawdziwe `cs/sql-injection` jest zapytaniem o ścieżkę, z biblioteką taint, a nie listą wywołań po nazwie):

```ql
import csharp

from MethodCall call
where call.getTarget().hasName("ExecuteSqlRaw")
      or call.getTarget().hasName("ExecuteSqlRawAsync")
select call, "Raw SQL API."
```

### Gdy wynik jest zły

| Objaw | Gdzie patrzeć |
| --- | --- |
| Brak runu w Actions | Default: czy Code scanning jest włączony i czy był push na `main`. Advanced: czy plik jest na gałęzi, z której patrzysz, i czy `on:` w ogóle łapie ten event. |
| Init: 403 przy ściąganiu paczki | Na prywatnym repo dołóż `packages: read` obok istniejącego `actions: read`. |
| Analyze: odmowa uploadu SARIF | Brak `security-events: write`. Na PR z forka — oczekiwane, nie obchodzisz tego szerszym tokenem. |
| C# pada na restore / „SDK not found” | Job jest na `autobuild` albo `manual` bez `actions/setup-dotnet` z `dotnet-version: "11.0.x"` i `dotnet-quality: preview`. Tryb `none` tego kroku nie potrzebuje. |
| Job zielony, alertów zero, w logu ekstrakcji prawie nie ma plików C# | Baza pusta. Przy `manual` build stoi przed init, ma zły `if:`, albo solution się nie zbudowało i krok został oznaczony jako pominięty. |
| Job zielony, pliki są, alertów zero | Zgodne ze stanem tego repo, dopóki nie ma surowego SQL-a ani `bypassSecurityTrust*`. Ewentualny test zrób na osobnej gałęzi, nie na `main`. |
| W UI tylko jeden język | Drugi job nie wstanie albo oba `analyze` dostały tę samą category i drugi upload nadpisał pierwszy. W przepisie category jest rozdzielona po języku; sprawdź, czy matryca ma obie pary i czy oba joby są zielone. |
| Dwa komplety alertów na ten sam kod | Default i advanced włączone razem. Zostaw jedno. |
| Alert w migracji albo w klientach NSwag | `paths-ignore` z sekcji wyżej, albo dismiss, jeśli to jednorazowy strzał. |
| Check czerwony, a w Security nic nowego | Padła analiza, nie przybyła dziura. Czytaj log joba, nie listę alertów. |

### Typowe pomyłki

1. **Default i advanced naraz.** Dwa skany, dwa checki, niespójny triaż.
2. **Build przed init** albo build tylko w jobie `api.yml`. Tracer CodeQL nagrywa kompilację wyłącznie między init a analyze tego samego joba.
3. **`build-mode: manual` bez komend build.** Baza C# pusta, job potrafi być zielony.
4. **Wymuszony `pnpm build` przed analizą Reacta.** Wydłuża job, bazy nie wzbogaca.
5. **Alias `javascript` „żeby pominąć TypeScript”.** Alias i tak analizuje `.ts`.
6. **Pomieszane majory action** (`init@v3`, `analyze@v4`) albo podbicie tylko jednego kroku.
7. **Brak `security-events: write`.** Analyze dochodzi do końca zapytań i pady na uploadzie.
8. **CodeQL na self-hosted runnerze deployowym.** Miesza skan z VM, która serwuje stronę. Zostaw `ubuntu-latest`.
9. **Jeden `paths: src/Clients/web` na całą matrycę.** Job C# nie ma czego analizować.
10. **Skan tylko `push` na `main`.** Feedback przychodzi po merge. `pull_request` jest od tego, żeby ścieżka była widoczna na diffie.
11. **Zielony check czytany jako „brak podatności”.** Check mówi, że SARIF wjechał. Otwarte alerty żyją w zakładce Security, dopóki ruleset nie zrobi z nich blokady.
12. **`security-and-quality` obok Sonara.** Te same zapachy triażujesz dwa razy. Jakość zostaw na [10-sonarqube.md](10-sonarqube.md).
13. **Dismiss zamiast poprawki**, albo dismiss bez zdania powodu. Za kwartał nikt nie wie, czy ścieżka była fałszywa.
14. **Testowa dziura na `main`.** Gałąź do wyrzucenia, alert, usunięcie commita przed merge.
15. **Oczekiwanie, że CodeQL zobaczy CVE w Npgsql albo w obrazie `aspnet`.** To [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md).

### Oficjalne źródła

- GitHub Docs: *About code scanning*, *About code scanning with CodeQL*, *About default setup*, *About the advanced setup*, *CodeQL code scanning for compiled languages*, *CodeQL query suites*, *SARIF support for code scanning*, *Triaging code scanning alerts in pull requests*.
- Konfiguracja workflow: *Workflow configuration options for code scanning* (identyfikatory języków, `category`, `queries`, plik konfiguracji).
- Reguły i ich opisy: strona pomocy podlinkowana z alertu oraz *CodeQL query help* dla C# i JavaScript/TypeScript.
- Action: `github/codeql-action` — kroki `init`, `analyze`, ewentualnie `upload-sarif`, gdy SARIF pochodzi z innego narzędzia. Dla samego CodeQL `analyze` wgrywa wynik sam.
- CLI: *CodeQL CLI* (bundle i `database create` / `database analyze`).

### Co zapamiętać

CodeQL składa bazę z kodu i puszcza na nią zapytania o ścieżki do niebezpiecznych API. Wynik to alert w code scanning, nie deploy i nie test jednostkowy. W JJDevHub na start wystarcza default setup dla C# (`none`) i TypeScript. Własny workflow z ręcznym `dotnet build` dochodzi, gdy preview SDK albo pusta ekstrakcja C# to wymusi — i wtedy w repo zostaje tylko on, bez równoległego default setup. Poprawka ma przeciąć ścieżkę; następny skan sam zamyka alert. CVE w paczkach i obrazach oraz bramka jakości są w numerach 05 i 10.
