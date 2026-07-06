# Skyvern's bitwarden-cli-server sidecar, deployed as a plain Sliplane
# service (not a HAOS add-on).
#
# Unlike the sibling HAOS add-on version in ../../skyvern-bitwarden-cli/,
# there is no bashio/options.json to satisfy here, so this does NOT need
# ghcr.io/hassio-addons/base -- entrypoint.sh (vendored unmodified from
# upstream, see below) reads BW_HOST/BW_CLIENTID/BW_CLIENTSECRET/BW_PASSWORD
# directly from the process environment, which Sliplane injects natively.
# node:22-bookworm-slim (matches the Node major used by upstream's own image)
# is enough.
FROM node:22-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl bash && \
    rm -rf /var/lib/apt/lists/*
RUN npm install -g @bitwarden/cli@2025.9.0

# entrypoint.sh is a vendored, byte-for-byte unmodified copy of upstream's
# bitwarden-cli-server/entrypoint.sh (github.com/skyvern-ai/skyvern,
# AGPL-3.0) -- that path is only ever shipped as a docker-compose build
# context upstream, never as a published image (verified via
# `docker manifest inspect`, see task-4-report.md in the HAOS add-on dirs).
COPY entrypoint.sh /app/bitwarden-cli-server/entrypoint.sh
RUN chmod +x /app/bitwarden-cli-server/entrypoint.sh

# Non-root user -- bw serve handles the vault master password/session token,
# matches upstream's own Dockerfile pattern (which this Sliplane variant
# otherwise doesn't reuse, since upstream's own image was never published).
RUN groupadd -r bw && useradd -r -g bw -m -d /home/bw -s /usr/sbin/nologin bw && \
    chown -R bw:bw /home/bw /app/bitwarden-cli-server
USER bw
ENV HOME=/home/bw

ENTRYPOINT ["/app/bitwarden-cli-server/entrypoint.sh"]
