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
FROM public.ecr.aws/skyvern/skyvern:latest

COPY entrypoint-skyvern.sh /app/entrypoint-skyvern.sh
RUN chmod +x /app/entrypoint-skyvern.sh

# Upstream's own CMD (["/bin/bash", "/app/entrypoint-skyvern.sh"]) already
# points at this path -- no ENTRYPOINT/CMD override needed.
