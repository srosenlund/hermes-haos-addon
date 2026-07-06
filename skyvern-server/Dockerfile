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

# entrypoint-skyvern.sh below is a vendored copy of upstream's own
# /app/entrypoint-skyvern.sh (github.com/skyvern-ai/skyvern/blob/main/entrypoint-skyvern.sh),
# with exactly one line changed: the trailing `alembic check` (a read-only,
# post-migration schema-drift diagnostic that runs AFTER `alembic upgrade
# head` has already applied all migrations) is made non-fatal instead of
# letting the script's `set -e` kill the whole container on a non-zero exit.
#
# Why this is needed in this specific deployment: Skyvern's Postgres database
# is a schema inside an existing Supabase project shared with an unrelated
# application (agent-stefan), isolated via a dedicated `skyvern` schema/role
# rather than a fully separate database (a deliberate, accepted tradeoff --
# see docs/superpowers/specs/2026-07-06-hermes-browser-stack/preflight-results.md
# in that other repo for the full incident writeup). Every Postgres role
# inherits `USAGE` on the `public` schema via Postgres's own default `GRANT
# USAGE ON SCHEMA public TO PUBLIC`, and Skyvern's alembic env.py enumerates
# all schemas the connection can see when running `alembic check` -- so it
# always reports agent-stefan's unrelated public-schema tables as "detected
# removed" drift, even though `alembic upgrade head` (which DOES run, and
# fully succeeds first) never touches them. `alembic check` is purely a
# diagnostic comparison -- it does not execute any DDL itself -- so making it
# non-fatal here does not skip or weaken the actual migration step above it.
# Verified: `entrypoint-skyvern.sh` is otherwise byte-for-byte identical to
# upstream.
COPY entrypoint-skyvern.sh /app/entrypoint-skyvern.sh
RUN chmod +x /app/entrypoint-skyvern.sh

# Upstream's own CMD is `["/bin/bash", "/app/entrypoint-skyvern.sh"]`
# (confirmed in upstream's Dockerfile; that file is already chmod +x'd by
# upstream's own build). run.sh below execs into that same script (now the
# patched copy above) after exporting the Supervisor-options-derived env
# vars, so nothing upstream manages (DB migrations, Xvfb, x11vnc, websockify,
# `python -m skyvern.forge`) is duplicated, skipped, or reimplemented here.
ENTRYPOINT ["/run.sh"]
