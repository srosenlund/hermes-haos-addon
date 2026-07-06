# Hermes Agent add-on

Wrapper om docker.io/nousresearch/hermes-agent:latest (arm64).
Options mapper 1:1 til Hermes' env-vars; secrets sættes i add-on-konfigurationen.
Persistens: /data (mappes til HERMES_HOME=/opt/data via symlink).
Opdatering af upstream: bump version i config.yaml → Supervisor rebuilder.
