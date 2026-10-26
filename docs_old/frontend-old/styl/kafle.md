# Kafle

Kafle to interaktywne kafelki list (kurs, hasło, notatka) — białe tło, cienki obrys, zaokrąglenie karty. Nie ma ich w sticky nav ani jako „card chrome” wokół całego layoutu.

## Wspólny przepis

Powtarza się w [home.scss](../../../src/Clients/web/src/app/pages/home/home.scss), [courses.scss](../../../src/Clients/web/src/app/pages/courses/courses.scss), [compendium.scss](../../../src/Clients/web/src/app/pages/compendium/compendium.scss), [notes.scss](../../../src/Clients/web/src/app/pages/notes/notes.scss):

- `background: var(--white)`
- `border-radius: var(--radius-card)` (18px w theme)
- obrys: `box-shadow: 0 0 0 1px color-mix(… --ink 6%)` zamiast `border`
- padding `--space-5` albo `--space-6`
- hover: `translateY(-2px)` z `--duration-reveal-fast` / `--easing-reveal`
- link dziedziczy kolor tekstu (`color: inherit`), bez niebieskiego fill całego kafla

Siatka: `repeat(auto-fit|auto-fill, minmax(14–16rem, 1fr))`, gap `--space-4` / `--space-5`.

## Warianty

| Miejsce | Treść kafla |
| --- | --- |
| Home / courses | tytuł, subtitle, pierwszy akapit `summary` |
| Compendium | term + 3 linie definicji (`-webkit-line-clamp: 3`) |
| Notes | data, tytuł, summary |

Na home kafle kursów i wiersze notatek dostają też klasę `list-enter` — [przejscia-widoku.md](../przejscia-widoku.md).

## Nie-kafel

Lista lekcji na szczegółach kursu (`.lesson-list a`) wygląda podobnie (białe tło, radius md), ale to wiersze w artykule, nie siatka wejściowa. Wiersze notatek na home (`.note-row`) to siatka data | treść z kreską dolną, bez białego panelu.
