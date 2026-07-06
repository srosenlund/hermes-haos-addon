# NOTE (Task 4, 2026-07-06 initial version): neither Dockerfile variant proposed in the
# implementation plan actually resolves. Verified via `docker manifest inspect`:
#   - ghcr.io/skyvern-ai/bitwarden-cli-server:latest  -> "manifest unknown" (does not exist)
#   - ghcr.io/skyvern-ai/skyvern:latest                -> "manifest unknown" (does not exist)
# Confirmed against upstream github.com/skyvern-ai/skyvern/blob/main/docker-compose.yml,
# whose commented-out `bitwarden-cli` service builds from a LOCAL build context
# (`context: ./bitwarden-cli-server`, `dockerfile: Dockerfile`) rather than any published
# tag, on either ghcr.io or public.ecr.aws (where the main skyvern app image actually lives).
#
# So this builds from the real upstream source
# (github.com/skyvern-ai/skyvern/tree/main/bitwarden-cli-server, AGPL-3.0) instead of
# extracting from a nonexistent published image. entrypoint.sh in this directory is an
# unmodified vendor copy of that upstream file.
#
# NOTE (Task 4 follow-up fix, 2026-07-06): base image changed from `node:24-alpine` to
# `ghcr.io/hassio-addons/base:21.0.0`. The original `node:24-alpine` base had no bashio or
# s6-overlay, but run.sh (`#!/usr/bin/with-contenv bashio` + `bashio::config`) requires
# both -- the add-on would have failed at container start with "bashio: command not
# found". Verified `ghcr.io/hassio-addons/base:21.0.0` (== the `:stable` tag's current
# digest at time of writing) actually exists via `docker manifest inspect`: it's a real
# multi-arch OCI image index with arm64 + amd64 manifests (matching this add-on's
# `arch: [aarch64, amd64]` in config.yaml), confirmed by pulling and inspecting both the
# platform-specific image (`/etc/os-release` -> Alpine Linux 3.24.0) and the tooling
# (`/usr/bin/bashio`, `/usr/bin/with-contenv`, `/init` all present). Alpine's own apk
# repos on that base carry `nodejs` at 24.17.0 -- the same major version as the original
# `node:24-alpine` base -- so `apk add nodejs npm` preserves the Node runtime this add-on
# was built against, and `npm install -g @bitwarden/cli` continues to work unchanged.
FROM ghcr.io/hassio-addons/base:21.0.0

RUN apk add --no-cache nodejs npm && \
    npm install -g @bitwarden/cli

WORKDIR /app
RUN mkdir -p /app/bitwarden-cli-server
COPY entrypoint.sh /app/bitwarden-cli-server/entrypoint.sh
RUN chmod +x /app/bitwarden-cli-server/entrypoint.sh

# run.sh is installed as an s6-overlay service, NOT wired up via a Dockerfile
# ENTRYPOINT override. Verified locally (`docker build` + `docker run`) that overriding
# ENTRYPOINT to run `/run.sh` directly bypasses the base image's own `/init` (s6-overlay),
# which is what populates `/run/s6/container_environment` -- without that step,
# `with-contenv` fails immediately: "s6-envdir: fatal: unable to envdir
# /run/s6/container_environment: No such file or directory". Placing run.sh under
# /etc/services.d/<slug>/run instead lets the inherited, unmodified base-image `/init`
# start it normally, after s6-overlay has finished its own init sequence and
# container_environment exists -- this is also the standard convention for
# hassio-addons/base-derived add-ons. run.sh's own content is unchanged from the
# original brief.
COPY run.sh /etc/services.d/skyvern-bitwarden-cli/run
RUN chmod +x /etc/services.d/skyvern-bitwarden-cli/run

EXPOSE 8087
