# CI/CD — spis dokumentów

Numerowane pliki poniżej to kolejność wdrożenia. Wdrażasz **jeden numer naraz** — bez łączenia kilku kroków w jednym podejściu.

| Plik | Temat |
| --- | --- |
| [01-proxmox.md](01-proxmox.md) | VM na Proxmoxie, Docker i pierwszy `compose up`. |
| [02-cloudflare-tunnel.md](02-cloudflare-tunnel.md) | Tunel Cloudflare do nginx na VM (bez publicznego IP). |
| [03-github.md](03-github.md) | Self-hosted runner, branch protection i deploy na `main`. |
| [04-codeql.md](04-codeql.md) | CodeQL w CI (analiza bezpieczeństwa kodu). |
| [05-zaleznosci-i-obrazy.md](05-zaleznosci-i-obrazy.md) | Skan zależności i obrazów kontenerowych. |
| [06-opentelemetry.md](06-opentelemetry.md) | Instrumentacja OpenTelemetry w aplikacji. |
| [07-prometheus.md](07-prometheus.md) | Zbieranie metryk Prometheus. |
| [08-jaeger.md](08-jaeger.md) | Tracing rozproszony w Jaegerze. |
| [09-grafana.md](09-grafana.md) | Dashboardy i wizualizacja w Grafanie. |
| [10-sonarqube.md](10-sonarqube.md) | Jakość kodu i SonarQube. |
| [11-branche-i-wydania.md](11-branche-i-wydania.md) | Trunk-based, Conventional Commits, release-please, deploy z tagu wydania. |
| [12-sekrety.md](12-sekrety.md) | SOPS + age w gicie, klucz VM w vTPM, sekrety Compose. |
| [13-lancuch-dostaw.md](13-lancuch-dostaw.md) | Akcje po SHA, zizmor, Scorecard, SBOM i atestacje przed deployem. |
| [przyszlosc.md](przyszlosc.md) | OpenBao, Kubernetes, staging — tylko kierunek, bez kroków wdrożenia. |
