# NOTE (Task 4, 2026-07-06): neither Dockerfile variant proposed in the implementation
# plan actually resolves. Verified via `docker manifest inspect`:
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
# unmodified vendor copy of that upstream file. Everything below this comment is
# equivalent to upstream's own Dockerfile for that path, plus this add-on's run.sh
# (options -> env translation layer).
FROM node:24-alpine

RUN apk add --no-cache curl bash && \
    npm install -g @bitwarden/cli

WORKDIR /app
RUN mkdir -p /app/bitwarden-cli-server
COPY entrypoint.sh /app/bitwarden-cli-server/entrypoint.sh
RUN chmod +x /app/bitwarden-cli-server/entrypoint.sh

COPY run.sh /run.sh
RUN chmod +x /run.sh

EXPOSE 8087

ENTRYPOINT ["/run.sh"]
