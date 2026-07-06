# Skyvern *server* only (not skyvern-ui) wrapped as a HAOS add-on.
#
# Base image verified directly against upstream skyvern-ai/skyvern's own
# Dockerfile (github.com/skyvern-ai/skyvern/blob/main/Dockerfile): the final
# stage is `FROM python:3.11-slim-bookworm`, so python3 and bash are already
# present -- no extra base-image swap needed here (unlike the sibling
# skyvern-bitwarden-cli add-on, which had to move onto
# ghcr.io/hassio-addons/base for bashio/s6-overlay). Skyvern's own image has
# neither bashio nor s6-overlay, so run.sh below parses /data/options.json
# with python3 directly instead of `bashio::config` -- there is no bashio to
# call.
#
# public.ecr.aws/skyvern/skyvern:latest confirmed multi-arch (arm64 + amd64)
# via `docker manifest inspect` -- matches this add-on's `arch:` list in
# config.yaml.
FROM public.ecr.aws/skyvern/skyvern:latest

COPY run.sh /run.sh
RUN chmod +x /run.sh

# Upstream's own CMD is `["/bin/bash", "/app/entrypoint-skyvern.sh"]`
# (confirmed in upstream's Dockerfile; that file is already chmod +x'd by
# upstream's own build). run.sh below execs into that exact same script after
# exporting the Supervisor-options-derived env vars, so nothing upstream
# manages (DB migrations, Xvfb, x11vnc, websockify, `python -m skyvern.forge`)
# is duplicated, skipped, or reimplemented here.
ENTRYPOINT ["/run.sh"]
