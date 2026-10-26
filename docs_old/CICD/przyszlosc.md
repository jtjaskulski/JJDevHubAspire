# Poza numeracją

Ciąg `01`–`13` kończy się na łańcuchu dostaw. Ten plik zapisuje kierunki, które świadomie nie dostały numeru: bez tutorialu i bez kroków deployu.

## Co już ma specyfikację gdzie indziej

Kafka i event sourcing są w [docs/api](../api/README.md): szyna w [13-kafka.md](../api/13-kafka.md), CI usług w [18-ci-uslug.md](../api/18-ci-uslug.md). Wydania, sekrety i atestacje są w [11](11-branche-i-wydania.md)–[13](13-lancuch-dostaw.md). Jenkins zostaje poza drzewem.

## OpenBao — dynamiczne poświadczenia

[OpenBao](https://openbao.org/) (MPL 2.0, fork HashiCorp Vault po zmianie licencji) to serwer sekretów. Hasło Postgresa nie leżałoby w pliku SOPS, tylko byłoby wydawane usłudze na godzinę (`database/creds/…`) i unieważniane po restarcie. Każdy odczyt miałby wpis w audycie.

To osobny proces na VM: unseal, storage, kopia zapasowa, rozszczelnianie po restarcie, sieć między usługą a serwerem. Przy jednym operatorze i jednej VM pliki SOPS z [12-sekrety.md](12-sekrety.md) dają historię, review i rotację bez tego procesu. OpenBao wraca, gdy pojawi się druga maszyna albo druga osoba z dostępem do produkcji.

## Inne kierunki bez numeru

- Kubernetes, Helm, Argo CD. Docelowo jest Compose z Aspire na jednej VM ([docs/api/18-ci-uslug.md](../api/18-ci-uslug.md)).
- Środowisko staging. Smoke i rollback z [11-branche-i-wydania.md](11-branche-i-wydania.md) wystarczają przy jednym użytkowniku.
- Backend logów (Loki, OpenSearch) i Alertmanager. Dziś są Prometheus, Jaeger i Grafana.
- Fizyczny TPM hosta albo Tang/Clevis zamiast vTPM. Kopia zapasowa całej VM i tak niesie stan vTPM; kolejny poziom to szyfrowanie kopii po stronie klienta.
