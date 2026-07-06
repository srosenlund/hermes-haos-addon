# Skyvern server, deployed as a plain Sliplane service (not a HAOS add-on).
#
# Unlike the sibling HAOS add-on version in ../../skyvern-server/, Sliplane
# injects environment variables directly into the container process -- there
# is no /data/options.json to parse, so no bashio/python3 options-translation
# wrapper (run.sh) is needed here. Set DATABASE_STRING, ENABLE_ANTHROPIC,
# LLM_KEY, ANTHROPIC_API_KEY, etc. directly as Sliplane service env vars.
#
# entrypoint-skyvern.sh is the same patched vendor copy used in the HAOS
# add-on: upstream's own entrypoint with exactly one change -- the trailing
# `alembic check` (a read-only post-migration diagnostic) is made non-fatal,
# because it flags agent-stefan's unrelated tables in the same shared
# Supabase project as "drift" even though `alembic upgrade head` (the actual
# migration step, which runs first and fully succeeds) never touches them.
# See ../../skyvern-server/Dockerfile for the full incident writeup.
#
# cdp-tunnel-entrypoint.sh wraps the above: joins this Sliplane container to
# Stefan's tailnet (tailscaled, userspace-networking -- no NET_ADMIN/TUN
# needed, works on Sliplane's managed containers) and forwards local
# 127.0.0.1:9222 to Chrome's remote-debugging port on his always-on Mac over
# the tailnet via gost, so Skyvern can drive that Mac's real, already
# logged-in Google session via CDP (BROWSER_TYPE=cdp-connect,
# BROWSER_REMOTE_DEBUGGING_URL=http://127.0.0.1:9222/). Exact same
# tailscaled-userspace + gost pattern already proven working in
# srosenlund/corten-sliplane (Corten-Matrix bridge project, same Sliplane
# server) -- adapted here to forward to a Chrome CDP port instead of the
# NAC-relay.
FROM tailscale/tailscale:stable AS ts
FROM gogost/gost:3 AS gostbin

FROM public.ecr.aws/skyvern/skyvern:latest

# curl is used by cdp-tunnel-entrypoint.sh's readiness-check loop -- not
# present by default in upstream's python:3.11-slim-bookworm base.
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ts /usr/local/bin/tailscaled /usr/local/bin/tailscaled
COPY --from=ts /usr/local/bin/tailscale  /usr/local/bin/tailscale
COPY --from=gostbin /bin/gost            /usr/local/bin/gost

COPY entrypoint-skyvern.sh /app/entrypoint-skyvern.sh
RUN chmod +x /app/entrypoint-skyvern.sh

COPY cdp-tunnel-entrypoint.sh /usr/local/bin/cdp-tunnel-entrypoint.sh
RUN chmod +x /usr/local/bin/cdp-tunnel-entrypoint.sh \
    && /usr/local/bin/tailscaled --version \
    && /usr/local/bin/gost -V

ENTRYPOINT ["/usr/local/bin/cdp-tunnel-entrypoint.sh"]
