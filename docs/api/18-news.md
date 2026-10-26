# 18. Notatki

Ten numer stawia usługę News. Notatka jest agregatem `Article`: Markdown, status publikacji i
opcjonalny slug lekcji. Poprzedni numer to [konta i role](17-identity.md). Następny to
[kursy i lekcje](19-learning.md). Zapis wymaga tokenu z rolą `owner` i polityki `Owner` z
`JJDevHub.ServiceDefaults`. Odczyt opublikowanej notatki jest publiczny. Szkic i notatka
wycofana zwracają 404 każdemu, kto nie jest właścicielem.

Bez tego numeru tekst strony żyje w pliku `.md` w repozytorium. Zmiana akapitu wymaga commita i
nowego obrazu, a czytelnik czeka na wdrożenie, żeby zobaczyć korektę. Właściciel nie ma szkicu,
który da się zdjąć bez kasowania historii. Cv, które chce pokazać tytuł notatki przy
umiejętności, musiałoby wołać HTTP News przy każdym złożeniu strony albo otworzyć `news_read`.
Ten numer zostawia treść w bazach tej usługi i wysyła na szynę trzy fakty, z których Cv składa
kopię dowodu.

Drugi pęknięty scenariusz dotyczy widoczności. Szkic ma być niewidoczny, dopóki owner nie
opublikuje obu kultur. Notatka wycofana ma zniknąć z publicznego `GET`, ale slug ma zostać, bo
link z Cv i adres notatki już poszły w świat. Gdyby szkic zwracał 403, istnienie tekstu, którego
nikt nie miał zobaczyć, byłoby publiczną informacją. Ten numer odpowiada 404 i na szkicu, i na
wycofaniu, dla każdego wywołania bez roli `owner`.

Trzeci scenariusz dotyczy lekcji. Notatka może wskazać slug lekcji, a Learning przy tym zapisie
nie jest wołany. Sprawdzenie sluga w `learning_read` związałoby wdrożenie News ze schematem
sąsiada i z jego dostępnością. Brak lekcji o tym slugu zostaje faktem historycznym linku. Widok
pokazuje brak celu. Autor poprawia napis późniejszym `PUT`, bez pytania sąsiada, czy lekcja już
powstała.

## Po co

Właściciel ma opublikować notatkę bez nowego wdrożenia tekstu. Czytelnik ma dostać Markdown w
`pl` i `en`. Notatka może wskazać lekcję, a Learning przy tym zapisie nie jest wołany. Treść
leży w `news_write` i `news_read`, nie w repozytorium plików. Agregat nazywa się `Article`. Typ
o nazwie `News` w tej usłudze nie powstaje, bo klasa o nazwie segmentu namespace `JJDevHub.News`
koliduje z tym namespace przy kompilacji.

Na szynę wychodzą trzy fakty: utworzenie, publikacja, wycofanie. Cv składa z nich kopię dowodu i
nie woła tego HTTP. Slug lekcji jest napisem. Brak lekcji o tym slugu zostaje faktem
historycznym linku. Produkt mówi o notatce, a historia wersji dotyczy jednego dokumentu, nie
„całego newsa”. Dlatego strumień nazywa się `article-{guid}`, a nie strumieniem usługi.

Cztery luki zamykają się razem. Bez bazy treść wraca do gita. Bez nazwy `Article` projekt się
nie kompiluje albo myli dokument z usługą. Bez trzech faktów Cv musi dopytywać News o tytuł. Bez
swobodnego napisu sluga lekcji publikacja notatki pada, gdy katalog kursu jest wyłączony. Dalsze
sekcje rozpisują status, czyszczenie Markdownu, mapę kultur i temat `news.integration`. Tag
obrazu tej usługi to `news-vX.Y.Z`.

## Dlaczego ta technologia

### Agregat Article

Notatka jest agregatem `Article` w `src/services/News/`. Namespace usługi zostaje
`JJDevHub.News`, a klasa agregatu ma inną nazwę. Jeden dokument ma własną wersję strumienia:
szkic, publikacja, korekta i wycofanie dopisują zdarzenia do `article-{guid}`. Slug powstaje
przy utworzeniu i nie ma komendy zmiany. Autor zapisu to `IdentityGuid` z `sub`, nie e-mail z
body.

Klasa `News` jako agregat odpadła, bo nazwa zlewa się z namespace i z usługą. Jedna tabela
mutowalna bez wersji odpadła, bo wycofanie i ponowna publikacja mają zostać w strumieniu.
Trzymanie plików `.md` w gicie odpadło, bo zmiana tekstu miałaby wymagać commita i obrazu.
Osobna flaga `hidden` obok statusu też odpadła: trzy stany już mówią, co widzi czytelnik.
Widoczność `Private`, `Students` i `Public` zostaje przy lekcji w [Learning](19-learning.md),
nie przy notatce.

Koszt to szósta usługa w AppHost, tag `news-vX.Y.Z` i własna para baz. `News.Core`
referencjonuje tylko `JJDevHub.Shared.Kernel`. Nie ma w nim MediatR, Entity Framework, Kafki ani
ASP.NET. Nie ma typu `News`. `Result<T>` pochodzi z jądra. Edycja opublikowanej notatki jest
natychmiastową korektą tego samego sluga. Czytelnik nie dostaje osobnego numeru rewizji w
adresie. `ETag` zapisu to wersja strumienia, na przykład `"4"`.

### Markdown w bazie

Pole treści jest mapą kultury na Markdown. Zapis przechodzi przez Markdig (BSD-2-Clause). Blok
HTML i HTML w linii są usuwane przed dopisaniem zdarzenia. Ogrodzenie kodu zostaje. Odpowiedź
HTTP zwraca oczyszczony Markdown, nie HTML. Pole tytułu jest zwykłym tekstem: handler usuwa
znaki nowej linii i znaczniki. Limit treści to 64 KiB na kulturę.

Autor wkleja treść z edytora, a surowy HTML w odpowiedzi byłby skryptem w przeglądarce
czytelnika. Regex „wytnij tagi” odpadł, bo psuje ogrodzenie, w którym przykładowy kod zawiera
`<`. Render HTML po stronie API odpadł w tym numerze, bo skład strony jest w kliencie, a ten
numer ma oddać treść bezpieczną do złożenia. Osobny magazyn plików na załączniki odpadł: notatka
w tym numerze nie ma binariów. Test `Html_in_body_is_stripped` sprawdza, że znacznik znika ze
strumienia, a ogrodzenie z przykładem `<div>` zostaje.

Koszt to pakiet Markdig w Infrastructure, limit 64 KiB i utrata świadomie wklejonego HTML.
Autor, który chciał osadzić surowy znacznik, dostaje tekst bez tego znacznika. Ogrodzenie
zostaje, bo przykładowy kod jest treścią notatki, nie znacznikiem strony. `MarkdownSanitizer`
woła handler utworzenia i korekty, zanim zdarzenie trafi do strumienia. Pusty tytuł daje
`article.title.blank`, pusta treść daje `article.body.blank`, i strumień wtedy nie powstaje.

### Szkic, publikacja, wycofanie

Status to `draft`, `published` albo `withdrawn`. Utworzenie zostawia `draft`. Publikacja wymaga
obu kultur, `pl` i `en`, w tytule i w treści. Wycofanie zdejmuje notatkę z odczytu publicznego.
Ponowna publikacja wraca z `withdrawn` do `published` i podbija wersję. Publiczny
`GET /api/news/{slug}` oddaje tytuł i Markdown tylko przy `published`. Ten sam slug na
`GET /api/news/manage/{slug}` dla polityki `Owner` zwraca pełne mapy także dla szkicu i
wycofania.

Właściciel ma poprawić tekst, zanim ktoś go zobaczy, i ma zdjąć tekst bez kasowania historii.
Twarde usunięcie wiersza odpadło, bo link z Cv i slug mają zostać. Rezerwacja `slug_reservation`
trzyma slug także po wycofaniu. Osobna flaga `hidden` odpadła, bo status już rozstrzyga odczyt.
403 na ścieżce publicznej nie występuje: istnienie szkicu nie jest informacją publiczną. Test
`Withdrawn_public_get_returns_404` sprawdza 404 bez roli `owner` i 200 dla ownera na
`/manage/{slug}`. Test `Draft_public_get_returns_404` sprawdza, że szkic nie wchodzi na listę
publiczną.

Koszt jest taki, że korekta opublikowanej notatki od razu zmienia ten sam adres. Czytelnik nie
wybiera rewizji w URL. Korekta szkicu zostaje w strumieniu jako `news.article-revised.v1` i nie
dokłada outboxa publikacji. Korekta przy statusie `published` wysyła ponownie
`news.article-published.v1` z wyższą `version`. Test `Revise_draft_does_not_emit_published` i
test `Revise_published_emits_published_with_higher_version` rozdzielają te dwa skutki. `PUT` i
oba `POST` zmiany statusu wymagają `If-Match`. Brak nagłówka to 428, zła wersja to 412.

### Slug lekcji bez pytania sąsiada

Pole `lessonSlug` jest opcjonalnym napisem. Wzorzec: małe litery, cyfry i dywiz, od 3 do 80
znaków. Handler nie otwiera `learning_read` i nie woła HTTP Learning. Publikacja przechodzi
także wtedy, gdy lekcji o tym slugu nie ma. Slug notatki i slug lekcji są różnymi napisami. Slug
notatki ustawia się tylko przy utworzeniu. `lessonSlug` wolno poprawić przy korekcie. Gdy pola
nie ma, na szynę idzie pusty napis, nie null i nie GUID.

Sprawdzenie sluga w cudzej bazie związałoby wdrożenie News z schematem Learning i z jego
dostępnością. Wywołanie `GET` lekcji w trakcie `POST` notatki odpadło. Trzymanie GUID-a lekcji
odpadło, bo identyfikator z cudzej bazy nie wchodzi do treści ani na szynę. Wspólna baza odpadła
z tego samego powodu co przy pozostałych usługach. Test
`Lesson_slug_stored_without_learning_call` sprawdza, że handler publikacji nie ma zależności do
klienta HTTP Learning ani do `learning_read`. Connection string Learning nie występuje w
konfiguracji `News.Api`.

Koszt jest po stronie linku. Bywa pusty w obie strony, dopóki autor nie poprawi sluga. Widok
pokazuje brak celu. Zły wzorzec, gdy pole jest podane, daje `article.lesson-slug.invalid` i HTTP
400. Zajęty slug notatki daje `article.slug.taken` i HTTP 409. Nieznany slug oraz notatka spoza
`published` dla wywołania bez roli `owner` dają 404. To obejmuje szkic i wycofanie. Slug po
utworzeniu nie ma komendy zmiany. Test `Slug_unchanged_after_revise` sprawdza, że korekta tytułu
zostawia slug.

### Mapa kultur

Tytuł i treść są mapą kodu kultury na tekst. Na start klucze to `pl` i `en`. Nowa kultura jest
kolejnym kluczem w JSON, bez nowej kolumny. Publikacja wymaga obu kluczy niepustych. Szkic może
mieć jeden. `GET /api/news?culture=pl` zwraca tytuł wybranej kultury. `GET` ownera pod `/manage`
zwraca obie kultury i każdy status. Na szynie mapa jest słownikiem `string` na `string`. Value
object `LocalizedText` zostaje w Core i nie wchodzi do JSON.

Kolumna `title_pl` i kolumna `title_en` kończą się przebudową odczytu przy trzecim języku.
Osobna tabela tłumaczeń z kluczem obcym do wiersza notatki odpadła jako drugi model tego samego
pola. Wykrywanie języka z treści odpadło, bo autorem mapy jest właściciel, nie heurystyka. Brak
`pl` albo `en` przy publikacji daje `article.translation.missing`, a status zostaje `draft`.
Test `Publish_without_english_returns_invalid` pilnuje braku `en`. Test
`Published_payload_title_is_dictionary` sprawdza, że JSON tytułu to obiekt `pl` i `en`, bez
nazwy typu value objectu.

Koszt jest redakcyjny. Owner uzupełnia dwa teksty przed publikacją. Szkic może jechać z jedną
kulturą, więc warsztat nie blokuje się na brakującym tłumaczeniu. Lista publiczna i szczegół
publiczny tną mapę do kultury z query. W bazie odczytu tytuł i treść leżą jako JSONB, obie
kultury naraz. `article_list` trzyma tytuł, `article_document` trzyma treść. Indeks listy
publicznej jest częściowy: tylko `published`, data publikacji malejąco.

### Para baz i cache listy

`news_write` trzyma strumień `article-{guid}`, rezerwację sluga i outbox. `news_read` trzyma
listę i treść już złożone pod slug. Redis trzyma listę publiczną pod `news:list:{culture}`
najdłużej 60 sekund. Projekcja kasuje ten klucz po zapisie wiersza. Utrata Redisa zostawia
odczyt z Postgresa. Strona główna woła listę często, a strumienia nikt nie odtwarza na ścieżce
HTTP.

Jedna baza z dwoma schematami odpadła. MongoDB odpadło. Cache całego Markdownu każdej notatki w
Redisie odpadł na rzecz listy: szczegół i tak jest jednym wierszem po slugu, a lista jest
gorętsza. Prefiks klucza to `news:`. `PublicListCache` służy `GET /api/news`, a kasowanie leci z
projekcji. Nagłówek `ETag` listy nie jest wersją agregatu. Wersja agregatu zostaje przy `ETag`
zapisu.

Koszt to chwila po publikacji, w której lista z cache jest starsza niż wiersz, albo `GET`
szczegółu daje 404, zanim projekcja dojdzie. Klient ponawia odczyt. Rezerwacja sluga i pierwsze
zdarzenie wchodzą jedną transakcją. Testcontainers Postgres to sprawdza. Po zapisie projekcji
znika `news:list:*`. AppHost podpina `News.Api`, connection `news-write` i `news-read`, Redis i
Kafkę. Walidacja JWT wskazuje JWKS Identity i nie ma klucza prywatnego.

### Trzy nazwy na szynie

Temat `news.integration` należy do News. Fakty integracyjne:

| Klasa w `News.Contracts` | `EventName` |
| --- | --- |
| `ArticleCreatedIntegrationEvent` | `news.article-created.v1` |
| `ArticlePublishedIntegrationEvent` | `news.article-published.v1` |
| `ArticleWithdrawnIntegrationEvent` | `news.article-withdrawn.v1` |

Pola wspólne: `slug`, `lessonSlug` (pusty napis, gdy brak), `version`, `title` jako słownik
kultur, `status`, `occurredOn`. Treści Markdown na szynie nie ma. Korekta tytułu albo sluga
lekcji przy statusie `published` wysyła ponownie `news.article-published.v1` z wyższą `version`.
Nazwa CLR do kolumny typu nie wchodzi. Test `Published_event_name_is_stable` sprawdza, że outbox
ma `news.article-published.v1`, a kolumna typu nie zawiera `ArticlePublishedIntegrationEvent`.

Cv ma pokazać tytuł notatki przy umiejętności bez `GET` do News. Samo „coś się zmieniło” bez pól
zmusza konsumenta do dopytania. Temat kompaktowany odpadł tutaj. Pełny stan kompaktowany jest
umową [Learning](19-learning.md). Notatka ma trzy fakty i numer wersji, którym konsument odrzuca
starszy komunikat. Wkładanie Markdownu do Kafki odpadło, bo dowód na stronie CV to tytuł, slug i
slug lekcji. `news.article-revised.v1` zostaje w strumieniu. Na temat wychodzi tylko wtedy, gdy
po korekcie status jest `published`. Szkic korygowany wysyła wyłącznie zdarzenie utworzenia z
momentu `POST`, bez każdej litery szkicu.

Koszt jest po stronie konsumenta, który zgubi kolejkę: odtwarza kopię od offsetu, nie z jednego
klucza. Wersja w ładunku jest obowiązkowa. Słownik tytułu buduje się na granicy, bez
serializacji `LocalizedText`. `lessonSlug` wychodzi jako napis. Wersję bierze się ze strumienia.
Outbox powstaje w tej samej transakcji co zdarzenie, gdy fakt jest jednym z trzech
integracyjnych. Korekta szkicu nie dokłada outboxa publikacji.

## Klasy i ścieżki

Sześć projektów rozdziela regułę notatki od zapisu, odczytu i kontraktu szyny. W Core nie ma
typu `News`. Tabele poniżej są wiążące dla strumienia, projekcji, endpointu i kodu błędu. Zdanie
przy tabeli mówi, który fakt zostaje w strumieniu, a który wychodzi na `news.integration`.

| Projekt | Referencje | Odpowiedzialność |
| --- | --- | --- |
| `src/services/News/News.Core` | tylko `JJDevHub.Shared.Kernel` | `Article`, `LocalizedText`, status |
| `src/services/News/News.Application` | `News.Core`, `JJDevHub.Cqrs` | komendy, zapytania, porty |
| `src/services/News/News.Persistence` | porty Application | `NewsWriteContext`, `NewsReadContext` |
| `src/services/News/News.Infrastructure` | porty Application | Markdig, Redis, Kafka, OpenBao jeśli connection tego wymaga |
| `src/services/News/News.Api` | skład hosta, `JJDevHub.ServiceDefaults` | endpointy, zasoby `pl` i `en` |
| `src/services/News/News.Contracts` | atrybut `EventName` | trzy rekordy integracyjne |

W Core nie ma MediatR, Entity Framework, Kafki ani ASP.NET. Nie ma typu `News`. `Result<T>`
pochodzi z `JJDevHub.Shared.Kernel`.

Strumień: `article-{guid}`. Rezerwacja `slug_reservation` w `news_write` ma klucz główny na
slugu i powstaje w tej samej transakcji co pierwsze zdarzenie. Slug po utworzeniu nie ma komendy
zmiany.

Zdarzenia w strumieniu:

| Nazwa | Skutek w agregacie |
| --- | --- |
| `news.article-created.v1` | status `draft`, slug, autor `IdentityGuid`, mapa tytułu, mapa treści, opcjonalny `lessonSlug` |
| `news.article-revised.v1` | podmiana map albo `lessonSlug`, wersja w górę, status bez zmiany |
| `news.article-published.v1` | status `published` |
| `news.article-withdrawn.v1` | status `withdrawn` |

`news.article-revised.v1` zostaje w strumieniu. Na temat wychodzi tylko wtedy, gdy po korekcie
status jest `published`: wtedy outbox dostaje `news.article-published.v1` z aktualnym tytułem i
wersją. Szkic korygowany wysyła wyłącznie zdarzenie utworzenia z momentu `POST`, bez każdej
litery szkicu.

Projekcja `news_read`:

| Tabela | Zawartość | Odczyt |
| --- | --- | --- |
| `article_list` | slug, status, tytuł jako JSONB, `lessonSlug`, daty, wersja | lista |
| `article_document` | slug, treść jako JSONB, wersja | szczegół |

Indeks listy publicznej: `status`, data publikacji malejąco, częściowy, tylko `published`.

Endpointy:

| Metoda i ścieżka | Kto | Skutek |
| --- | --- | --- |
| `GET /api/news?culture=pl` | każdy | opublikowane, tytuł wybranej kultury, nagłówek `ETag` listy nie jest wersją agregatu |
| `GET /api/news/{slug}?culture=pl` | każdy, gdy `published` | tytuł i Markdown tej kultury |
| `GET /api/news/manage` | `Owner` | wszystkie statusy |
| `GET /api/news/manage/{slug}` | `Owner` | pełne mapy `pl` i `en` |
| `POST /api/news` | `Owner` | szkic, body: slug, mapy, opcjonalny `lessonSlug` |
| `PUT /api/news/{slug}` | `Owner`, `If-Match` | korekta map i `lessonSlug` |
| `POST /api/news/{slug}/publish` | `Owner`, `If-Match` | `published` |
| `POST /api/news/{slug}/withdraw` | `Owner`, `If-Match` | `withdrawn` |

`ETag` zapisu to wersja strumienia, na przykład `"4"`.

Kody:

| Kod | HTTP |
| --- | --- |
| `article.title.blank` | 400 |
| `article.body.blank` | 400 |
| `article.slug.invalid` | 400 |
| `article.slug.taken` | 409 |
| `article.translation.missing` | 400, przy publikacji |
| `article.lesson-slug.invalid` | 400, gdy pole jest, a wzorzec nie pasuje |
| `precondition.required` | 428 |
| `precondition.failed` | 412 |

Nieznany slug i notatka spoza `published` dla wywołania bez roli `owner` dają 404. To obejmuje
szkic i wycofanie. Odpowiedź 403 na tej ścieżce nie występuje: istnienie szkicu nie jest
informacją publiczną.

AppHost: `News.Api`, connection `news-write` i `news-read`, Redis, Kafka. Walidacja JWT wskazuje
JWKS Identity i nie ma klucza prywatnego.

## Plan

### 1. Projekty

Utwórz sześć projektów News. `News.Core` referencjonuje tylko `JJDevHub.Shared.Kernel`. Dodaj
Markdig do Infrastructure i wersję do `Directory.Packages.props`. Podłącz `News.Api` do AppHost.

### 2. Article

Dodaj agregat `Article` i value object `LocalizedText` z kluczami kultury. Metody: utwórz szkic,
skoryguj, opublikuj, wycofaj. Publikacja w agregacie odmawia, gdy `pl` albo `en` w tytule lub
treści jest puste. Slug ustaw tylko w utworzeniu.

### 3. Czyszczenie Markdown

W Infrastructure uruchom Markdig na każdej wartości mapy treści. Zapisz do zdarzenia tekst bez
surowego HTML, z ogrodzeniami kodu. Pole tytułu traktuj jako zwykły tekst: usuń znaki nowej
linii i znaczniki.

### 4. Zapis

W jednej transakcji `news_write`: rezerwacja sluga przy utworzeniu, dopisanie zdarzenia, wiersz
outbox, gdy fakt jest jednym z trzech integracyjnych. Korekta szkicu nie dokłada outboxa
publikacji.

### 5. Odczyt

Złóż `article_list` i `article_document`. `GET` publiczny czyta wyłącznie wiersze `published` i
jedną kulturę z mapy. `GET` ownera pod `/manage` zwraca obie kultury i każdy status. Po zapisie
projekcji skasuj `news:list:*`.

### 6. Endpointy

Podepnij tabelę ścieżek. Polityka `Owner` na zapisie i na `/manage`. Na `PUT` i na obu `POST`
zmiany statusu wymagaj `If-Match`. Brak nagłówka zakończ 428, złą wersję 412.

### 7. Kontrakt szyny

Dodaj trzy rekordy w `News.Contracts` z atrybutami z tabeli. Słownik tytułu buduj na granicy,
bez serializacji `LocalizedText`. `lessonSlug` wysyłaj jako napis. Wersję bierz ze strumienia.

### 8. Testy numeru

Dodaj pięć projektów testowych z sekcji Testy. Scenariusz NBomber woła publiczną listę
opublikowanych notatek.

### Co jest do czego

| Klasa albo job | Po co istnieje | Kto woła |
| --- | --- | --- |
| `Article` | trzyma status, mapy i slug lekcji jednej notatki | komendy utworzenia, korekty, publikacji, wycofania |
| `LocalizedText` | pilnuje, że mapa ma kody kultur, nie kolumny | `Article` |
| `MarkdownSanitizer` | zostawia ogrodzenia, usuwa surowy HTML | handler korekty i utworzenia |
| `SlugReservation` | trzyma slug zajęty także po wycofaniu | transakcja utworzenia |
| `ArticleProjection` | składa listę i szczegół pod odczyt | worker checkpointu |
| `ArticlePublishedIntegrationEvent` | niesie tytuł i slug lekcji do Cv | outbox, konsument w [CV](20-cv.md) |
| `PublicListCache` | trzyma gorącą listę pod `news:list:{culture}` | `GET /api/news`, kasowanie z projekcji |

Utworzenie woła `Article` i `LocalizedText`. `MarkdownSanitizer` czyści mapę treści, zanim
powstanie `news.article-created.v1`. `SlugReservation` zajmuje slug w tej samej transakcji co
pierwsze zdarzenie. Szkic nie wysyła publikacji. `POST /api/news/{slug}/publish` przechodzi w
`published` tylko, gdy `pl` i `en` są niepuste w tytule i w treści, i wkłada outbox
`ArticlePublishedIntegrationEvent`. Wycofanie wkłada `ArticleWithdrawnIntegrationEvent` i
zostawia rezerwację sluga.

`ArticleProjection` składa `article_list` i `article_document`. Po zapisie wiersza kasuje
`news:list:*`, czyli klucze `PublicListCache`. Publiczny `GET` czyta wyłącznie `published` i
jedną kulturę. `GET /api/news/manage` czyta każdy status i obie mapy. Korekta szkicu dopisuje
`news.article-revised.v1` bez outboxa publikacji. Korekta opublikowanej notatki wysyła ten sam
`EventName` publikacji z wyższą `version`. `PUT` niesie `If-Match`. Autor bierze się z `sub`.

## Testy

Runner to xUnit i `[Fact]`. Jeden test, jeden powód.

| Projekt | Piętro |
| --- | --- |
| `src/services/News/tests/News.Core.Tests` | jednostkowe |
| `src/services/News/tests/News.Application.Tests` | jednostkowe |
| `src/services/News/tests/News.Persistence.Tests` | Testcontainers, `postgres:16-alpine`, `Category=Integration` |
| `src/services/News/tests/News.Api.Tests` | HTTP, `Category=Integration` |
| `src/services/News/tests/News.Performance.Tests` | NBomber na `GET /api/news`, `Category=Performance` |

Przypadki:

- `Create_blank_title_returns_invalid` — pusta mapa tytułu daje `article.title.blank`, strumień
  nie powstaje.
- `Publish_without_english_returns_invalid` — brak `en` daje `article.translation.missing` i
  status zostaje `draft`.
- `Withdrawn_public_get_returns_404` — po wycofaniu `GET` bez roli `owner` zwraca 404, a
  `GET /manage/{slug}` dla ownera zwraca 200.
- `Draft_public_get_returns_404` — szkic nie występuje na liście publicznej.
- `Html_in_body_is_stripped` — wejście z surowym znacznikiem ląduje w strumieniu bez tego
  znacznika, ogrodzenie z przykładem `<div>` zostaje.
- `Lesson_slug_stored_without_learning_call` — handler publikacji nie ma zależności do klienta
  HTTP Learning ani do `learning_read`.
- `Update_without_if_match_returns_428`.
- `Update_with_stale_if_match_returns_412`.
- `Slug_unchanged_after_revise` — korekta tytułu nie zmienia sluga.
- `Published_event_name_is_stable` — outbox ma `news.article-published.v1`, kolumna typu nie
  zawiera `ArticlePublishedIntegrationEvent`.
- `Published_payload_title_is_dictionary` — JSON tytułu to obiekt `pl` i `en`, bez nazwy typu
  value objectu.
- `Revise_draft_does_not_emit_published` — korekta szkicu nie dokłada
  `news.article-published.v1`.
- `Revise_published_emits_published_with_higher_version` — korekta opublikowanej notatki wysyła
  ten sam `EventName` z większą `version`.

Integracja: Testcontainers Postgres sprawdza, że rezerwacja sluga i pierwsze zdarzenie wchodzą
razem. Test szyny, gdy jest w tym projekcie, używa `Testcontainers.Kafka` w trybie KRaft.

Wydajność: NBomber czyta `GET /api/news?culture=pl` przez 30 sekund na danych z kilku
opublikowanych wierszy. Zapis do scenariusza nie wchodzi. Bramka `main` jest w
[testach](22-testy.md).

Lokalnie:
`dotnet test src/services/News --filter "Category!=Integration&Category!=Performance"`.

Układ przypadku zostaje: przygotowanie, działanie, sprawdzenie, jeden powód. W
`Html_in_body_is_stripped` przygotowaniem jest treść z surowym znacznikiem i ogrodzeniem,
działaniem zapis, sprawdzeniem brak znacznika w strumieniu przy zachowanym `<div>` w fence. W
`Withdrawn_public_get_returns_404` działaniem jest publiczny `GET` po wycofaniu, sprawdzeniem
404, a osobny fakt ownera na `/manage/{slug}` nie dokleja się do tego samego powodu.
`Update_without_if_match_returns_428` i `Update_with_stale_if_match_returns_412` stoją osobno.

## Zasady

- W projektach News nie ma publicznego typu o nazwie `News`. Próba nazwania agregatu segmentem
  namespace kończy się kolizją albo myleniem dokumentu z usługą.
- `News.Core` referencjonuje wyłącznie `JJDevHub.Shared.Kernel`. Reguła statusu i mapy kultur
  kompiluje się bez MediatR, Entity Framework, Kafki i ASP.NET.
- Oczekiwany błąd to `Result<T>`. `type` w `ProblemDetails` jest kodem. `title` pochodzi z
  zasobów według `Accept-Language`. Klient czyta kod taki jak `article.translation.missing`, a
  nie stos wyjątku.
- Szkic i notatka wycofana są dla czytelnika nieobecne: 404, nie 403. Istnienie
  nieopublikowanego sluga nie jest informacją publiczną.
- Zapis z wersją wymaga `If-Match`: brak 428, niezgodność 412. Starszy znacznik nie nadpisuje
  wersji dopisanej między odczytem a `PUT`.
- Slug notatki jest stały. Slug lekcji jest napisem bez zapytania do Learning. Korekta tytułu
  nie zwalnia sluga do puli.
- Mapa kultur na starcie ma `pl` i `en`. JSON zdarzenia niesie słownik, nie CLR value objectu.
  `LocalizedText` zostaje w Core.
- Nazwa zdarzenia pochodzi z `[EventName]`: `news.article-created.v1`,
  `news.article-published.v1`, `news.article-withdrawn.v1`. Nazwa klasy nie wchodzi do kolumny
  typu outboxa.
- Markdown w odpowiedzi nie zawiera surowego HTML autora. Ogrodzenie kodu zostaje, bo
  przykładowy znacznik w fence nie jest HTML strony.
- Redis jest cachem listy. Prefiks to `news:`. MongoDB nie wchodzi. Utrata Redisa zostawia
  odczyt listy z Postgresa.
- Usługa nie otwiera bazy sąsiada i nie dostaje jej connection stringa. `learning_read` nie jest
  zależnością handlera publikacji.
- Autor zapisu to `IdentityGuid` z `sub`, nie e-mail z body. Adres z tokenu nie staje się
  kluczem notatki.
- Jeden publiczny typ na plik, klasa `sealed`, `CancellationToken` w metodzie `async`. Port
  asynchroniczny przyjmuje token anulowania.

## Poza zakresem

- Katalog lekcji, widoczność `Private` / `Students` / `Public` i postęp studenta są w
  [Learning](19-learning.md). Ten numer tylko zapisuje slug. Nie sprawdza, czy lekcja o tym
  slugu istnieje.
- Złożenie strony CV z kopii `news.integration` jest w [CV](20-cv.md). News nie czyta `cv_read`
  i nie składa dokumentu strony.
- Render HTML, sanitizacja po stronie przeglądarki i edytor intranetu są w `docs/frontend`. Ten
  numer oddaje oczyszczony Markdown.
- Kształt JWT i polityki są w [Identity](17-identity.md). News waliduje podpis na JWKS i nie
  wystawia własnego klucza.
- Piramida bramek i filtr lokalny są domknięte w [testach](22-testy.md). Scenariusz NBomber tego
  numeru to publiczna lista, a bramka `main` jest opisana tam.
- Komentarze pod notatką, załączniki i wyszukiwanie pełnotekstowe nie wchodzą w ten numer.
  Notatka nie ma binariów, a lista publiczna jest cache'owana jako lista, nie jako indeks
  treści.

## Źródła

- [CommonMark](https://spec.commonmark.org/). Wiążące jest ogrodzenie kodu i granica między
  Markdownem a HTML. W tym pliku surowy HTML odpada przed zdarzeniem, a fence z przykładem
  zawierającym `<` zostaje. Nie bierzemy stąd renderu HTML po stronie API: odpowiedź niesie
  oczyszczony Markdown.
- [Markdig, licencja BSD-2-Clause](https://github.com/xoofx/markdig/blob/master/license.txt).
  Wiążący jest parser użyty przy zapisie i licencja, którą wolno wziąć produkcyjnie. W tym pliku
  pakiet stoi w Infrastructure i w `Directory.Packages.props`, a `MarkdownSanitizer` czyści
  każdą wartość mapy treści. Nie bierzemy stąd własnego regexu „wytnij tagi” ani doklejania
  innej biblioteki renderującej.
- [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110). Wiążące są 404 oraz 412. W tym pliku szkic
  i notatka wycofana dla wywołania bez roli `owner` dają 404, a nieaktualny `If-Match` daje 412.
  Nie bierzemy stąd 403 na tej ścieżce: istnienie szkicu nie jest informacją publiczną.
- [RFC 6585](https://www.rfc-editor.org/rfc/rfc6585). Wiążący jest status 428 Precondition
  Required. W tym pliku brak `If-Match` na `PUT` i na zmianie statusu mapuje się na
  `precondition.required`. Nie bierzemy stąd 428 dla `POST` utworzenia: nowego strumienia nie ma
  jeszcze z czym porównać.
- [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457). Wiążący jest kształt `ProblemDetails`. W
  tym pliku `type` jest kodem, na przykład `article.slug.taken`, a `title` pochodzi z zasobów
  `pl` albo `en`. Nie bierzemy stąd dowolnego URI w `type`.
- [PostgreSQL 16, JSONB](https://www.postgresql.org/docs/16/datatype-json.html). Wiążący jest
  typ JSONB dla mapy kultur w projekcji. W tym pliku `article_list` trzyma tytuł, a
  `article_document` treść, bez kolumn `title_pl` i `title_en`. Nie bierzemy stąd osobnej tabeli
  tłumaczeń ani dokumentu jako jedynego magazynu zamiast strumienia.
- [Domain-Driven Design](https://www.domainlanguage.com/ddd/). Eric Evans: wiążąca jest granica
  spójności agregatu, nie nazwa systemu. W tym pliku agregatem jest `Article`, a publiczny typ
  `News` nie powstaje. Nie bierzemy stąd jednego modelu notatki współdzielonego z Learning albo
  Cv.
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning). Greg Young: wiążące
  jest wersjonowanie nazwy zdarzenia i numer wersji w ładunku. W tym pliku trzy nazwy kończą się
  `.v1`, a korekta opublikowanej notatki powtarza `news.article-published.v1` z wyższą
  `version`. Nie bierzemy stąd tematu kompaktowanego: pełny stan jest umową Learning, a tu
  konsument odrzuca starszy komunikat po wersji.
- [Database per service](https://microservices.io/patterns/data/database-per-service.html).
  Chris Richardson: wiążące jest to, że usługa nie czyta cudzej bazy. W tym pliku handler nie
  otwiera `learning_read` i nie dostaje connection stringa Learning. Nie bierzemy stąd wspólnej
  bazy z Learning ani sprawdzania sluga lekcji przy `POST`.
- [eShop](https://github.com/dotnet/eshop). Wiążący jest wzorzec granic usług: własna baza,
  własny host, wspólne `ServiceDefaults`. W tym pliku `News.Core` nie referencjonuje MediatR, a
  polityka `Owner` przychodzi z `JJDevHub.ServiceDefaults`. Nie bierzemy stąd MediatR. Mediator
  wołający handlery jest w `JJDevHub.Cqrs`, a `News.Core` go nie widzi.

## Gotowe gdy

- Sześć projektów News jest w solution, a `News.Core` nie referencjonuje niczego poza
  `JJDevHub.Shared.Kernel`.
- W kodzie usługi nie ma publicznego typu `News`. Agregat nazywa się `Article`.
- `POST` tworzy szkic. Publikacja bez `en` albo bez `pl` zwraca `article.translation.missing`.
- Publiczny `GET` szkicu i notatki wycofanej zwraca 404. Ten sam slug dla `Owner` na
  `/manage/{slug}` zwraca 200.
- `PUT` bez `If-Match` zwraca 428, ze starym znacznikiem 412.
- Zdarzenia outbox używają trzech nazw `news.article-created.v1`, `news.article-published.v1` i
  `news.article-withdrawn.v1`.
- Test `Lesson_slug_stored_without_learning_call` przechodzi.
- Test `Html_in_body_is_stripped` przechodzi, a ogrodzenie kodu zostaje.
- `dotnet test src/services/News --filter "Category!=Integration&Category!=Performance"`
  przechodzi.
- Connection string Learning nie występuje w konfiguracji `News.Api`.
- Tag `news-vX.Y.Z` da się wgrać jobem z [16-deploy.md](../cicd/16-deploy.md). Job
  podmienia tylko Deployment `news`.
