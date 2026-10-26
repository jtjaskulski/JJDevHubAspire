# Budżet stylów

Vite nie ma budżetu `anyComponentStyle` z Angulara. Zostaje ta sama dyscyplina: arkusz jednej strony (home z hero i kaflami, CV, szczegóły kursów) mieści się obok reszty layoutu i nie rozrasta się bez powodu.

Bramka CI to `pnpm build` w [web.yml](../../../.github/workflows/web.yml). Padnięty build zatrzymuje job. Osobnego progu rozmiaru CSS w Vite nie ma.
