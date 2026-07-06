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

# NOTE (Task 4, review-fix round 2, 2026-07-06): non-root user for the actual
# `bw`/entrypoint.sh process. Upstream's own bitwarden-cli-server Dockerfile
# (github.com/skyvern-ai/skyvern/blob/main/bitwarden-cli-server/Dockerfile)
# creates a dedicated `bw` user (`addgroup -g 1001 -S bw && adduser -S bw -u
# 1001 -G bw`) and runs the master-password/session-token-handling process as
# that user, never root -- this got lost when this add-on was rewired onto
# ghcr.io/hassio-addons/base (which, like all HA add-on base images, boots its
# own /init as root, and it must stay root for the s6-overlay/bashio
# bootstrap). Replicated the same user here, adapted for the base-image
# constraint: the container's PID 1 (`/init`) still starts as root (required),
# but the actual `bw serve` / vault-unlock process is dropped to this
# unprivileged `bw` user inside the service's own run script instead of via a
# Dockerfile `USER` directive (see run.sh + comment there for how and why).
# `adduser -S` (no `-H`) creates a real home directory at /home/bw by default
# (verified: `grep bw /etc/passwd` -> `/home/bw`), which is chowned to bw:bw
# below so `@bitwarden/cli`'s config/data file (which lives under $HOME) is
# writable once privileges are dropped.
RUN addgroup -g 1001 -S bw && \
    adduser -S bw -u 1001 -G bw && \
    chown -R bw:bw /home/bw

WORKDIR /app
RUN mkdir -p /app/bitwarden-cli-server
COPY entrypoint.sh /app/bitwarden-cli-server/entrypoint.sh
RUN chmod +x /app/bitwarden-cli-server/entrypoint.sh && \
    chown -R bw:bw /app
# Verified separately (docker build + `ls -la` on the built image, no chown
# needed): npm's global install tree under /usr/local/lib/node_modules and the
# /usr/local/bin/bw symlink are all world-readable/executable (0755) by
# default on this base image, so the unprivileged `bw` user can already read
# and exec them without any extra chown here.

# run.sh is installed as an s6-overlay service, NOT wired up via a Dockerfile
# ENTRYPOINT override. Verified locally (`docker build` + `docker run`) that overriding
# ENTRYPOINT to run `/run.sh` directly bypasses the base image's own `/init` (s6-overlay),
# which is what populates `/run/s6/container_environment` -- without that step,
# `with-contenv` fails immediately: "s6-envdir: fatal: unable to envdir
# /run/s6/container_environment: No such file or directory". Placing run.sh under
# /etc/services.d/<slug>/run instead lets the inherited, unmodified base-image `/init`
# start it normally, after s6-overlay has finished its own init sequence and
# container_environment exists -- this is also the standard convention for
# hassio-addons/base-derived add-ons.
#
# NOTE (review-fix round 2): run.sh itself now drops privileges from root to
# `bw` before exec'ing entrypoint.sh, via `s6-setuidgid bw` -- the standard
# s6-overlay pattern for running an individual legacy service as a non-root
# user while the container's own /init stays root (confirmed present on this
# base image: `/usr/bin/s6-setuidgid`, part of s6-overlay's bundled
# execline/s6 tools, not something we're adding ourselves). This is the
# correct mechanism here, not a Dockerfile `USER` directive or
# `/etc/fix-attrs.d/` rule: `USER` would apply to the whole container's PID 1
# (`/init`), which must stay root for s6-overlay/bashio to bootstrap at all
# (verified in the prior fix round); `/etc/fix-attrs.d/` (a legacy
# s6-overlay v2 mechanism for recursively fixing ownership/perms on
# directories at boot) does not exist at all on this s6-overlay v3 base image
# (verified: `/etc/fix-attrs.d` is absent) and does not, on its own, change
# which user a service *runs as* -- s6-setuidgid is the actual privilege-drop
# primitive. See run.sh's own comment for the exec line.
COPY run.sh /etc/services.d/skyvern-bitwarden-cli/run
RUN chmod +x /etc/services.d/skyvern-bitwarden-cli/run

EXPOSE 8087
