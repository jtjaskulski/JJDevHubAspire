# Gałęzie i commity

Długie gałęzie to `develop`, `release` i `main`. Praca wychodzi z `develop` i wraca na `develop`. Na `release` wchodzi głowa `develop`. Na `main` wchodzi głowa `release`.

Scalenie jest squashem. Tytuł pull requestu jest commitem na gałęzi docelowej. Force-push gałęzi roboczej jest dozwolony do scalenia. Po squashu ta gałąź znika. `develop`, `release` i `main` zostają.

## Nazwa gałęzi

```text
^(feature|fix|docs|chore|ci|refactor|test)/[a-z0-9]+(-[a-z0-9]+)*$
```

| Przechodzi | Pada |
| --- | --- |
| `feature/lesson-markdown` | `feature/lesson_markdown` |
| `feature/lesson-2` | `feature/lesson--markdown` |
| `fix/contact-form` | `bugfix/contact-form` |
| `docs/galezie` | `feature/` |
| `ci/branch-and-title-checks` | `release/1.0.0` |
| `develop` → `release` | `develop` → `main` |
| `release` → `main` | `main` → `develop` |

Wielka litera, podkreślenie, spacja i podwójny myślnik padają. `merge-base` głowy z `origin/main` ma być przodkiem `origin/develop`, więc gałąź wycięta z `main` pada także przy poprawnym prefiksie.

## Tytuł

Jedna linia Conventional Commits, co najwyżej 120 znaków. Po dwukropku jest jedna spacja. Opis zaczyna się małą literą albo cyfrą, ma co najmniej trzy znaki i nie kończy się kropką. `!` przed dwukropkiem oznacza zmianę łamiącą: `feat(news)!: publish article revision`.

Typy: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

`feat` i `fix` mają zakres. Przy pozostałych typach zakres może być. Zakres, gdy jest, należy do listy: `identity`, `news`, `learning`, `cv`, `contact`, `gateway`, `web`, `mobile`, `infra`, `shared`. `shared` to kernel, `infra` to maszyna. Żaden z tych dwóch nie jest tagiem obrazu usługi.

`revert:` przyjmuje drugi poprawny tytuł.

| Przechodzi | Pada |
| --- | --- |
| `feat(news): publish article revision` | `feat: publish article revision` |
| `feat(news)!: publish article revision` | `feat(blog): publish article revision` |
| `docs: opis bramek` | `docs(cicd): opis bramek` |
| `chore: promote to release` | `feat(news): Publish article revision` |
| `ci: add branch and title checks` | `feat(news): publish article revision.` |
| `revert: feat(news): publish article revision` | `feat(news): x` |

Promocja `develop` → `release` ma tytuł `chore: promote to release`. Promocja `release` → `main` ma tytuł `chore: promote to main`.

Prefiks gałęzi `feature/` i typ `feat` to dwie listy. Gałąź `docs/galezie` może nieść tytuł `docs: opis bramek`.

## Sprawdzenie lokalne

```bash
.github/scripts/check-branch-name.sh --head feature/lesson-markdown --base develop --skip-ancestry
.github/scripts/check-pr-title.sh --title 'feat(news): publish article revision'
```

Kod `0` zgadza się z regułą. Kod `1` odmawia. Kod `2` znaczy, że zabrakło argumentu. Job w CI nie dostaje `--skip-ancestry`.

Pełna specyfikacja checków jest w [cicd/01-galezie.md](cicd/01-galezie.md).
