# Skyvern Server add-on

Vision-LLM browser automation (`skyvern-server` only -- `skyvern-ui` is
deliberately **not** included/deployed). Produces:

- REST API + MCP endpoint at `http://127.0.0.1:8000` (consumed by Task 6,
  Hermes MCP registration)
- VNC-websocket browser streaming at `http://127.0.0.1:6080` (consumed by
  Task 8's login test)

Both ports are only reachable on the Pi's own LAN via `host_network: true` --
**never** expose `8000` or `6080` outside the LAN (no public port-forwarding,
no Tailscale/Cloudflare Funnel, etc.).

## Options

- `database_string`: full `postgresql+psycopg://...` connection string,
  forwarded verbatim as `DATABASE_STRING` (read directly by upstream's
  `entrypoint-skyvern.sh` to run migrations before starting the server). The
  real value (Supabase pooler, not Sliplane) is set later by Stefan directly
  via Supervisor options -- this add-on only wires the option through, it
  does not hardcode or default it.
- `llm_provider` (`anthropic` | `openai`) + `llm_api_key`: reuses an existing
  key from Doppler, no new provider account. `run.sh` maps the choice to
  Skyvern's own env-var contract (`ENABLE_ANTHROPIC` / `ANTHROPIC_API_KEY` /
  `LLM_KEY=ANTHROPIC_CLAUDE4.7_OPUS`, or the OpenAI equivalents) -- these
  `LLM_KEY` values were confirmed against upstream's own
  `docker-compose.yml` LLM Settings comment block and `.env.example`, not
  guessed.
- `enable_bitwarden` (bool, default `false`): optional credential-lookup
  integration with the sibling `skyvern-bitwarden-cli` add-on (Task 4). Only
  wire up `bitwarden_server` / `bitwarden_server_port` if you actually want
  Skyvern to look up credentials through it.
  - `bitwarden_server` default `http://127.0.0.1` -- **must not include a
    port.** Skyvern builds the request base URL as
    `f"{BITWARDEN_SERVER}:{BITWARDEN_SERVER_PORT}"`
    (`skyvern/forge/sdk/services/bitwarden.py`), so a port baked into
    `bitwarden_server` would double up (`:8087:8087`).
  - `bitwarden_server_port` default `"8087"` -- **not** `8002`. `8002` is
    only the *external* port in upstream's own docker-compose port mapping
    (`8002:8087`, bridge-networking only). This add-on runs with
    `host_network: true`, so there is no port remap -- the bitwarden-cli
    server actually binds directly to `8087` on the host (confirmed in Task
    4: the vendored `bw serve --port 8087` is hardcoded, never configurable
    to 8002). If `enable_bitwarden` is `false`, neither `BITWARDEN_SERVER`
    nor `BITWARDEN_SERVER_PORT` is exported, and `CREDENTIAL_VAULT_TYPE`
    stays on Skyvern's own local encrypted vault (`skyvern`) -- matching
    upstream's own docker-compose default, not its bare class-level default
    of `bitwarden` in `skyvern/config.py` (which would otherwise silently
    expect a reachable Bitwarden server even when unused).

## Build approach (why this differs from the brief's original two variants)

Neither of the two `config.yaml`/Dockerfile variants originally sketched for
this task works as written:

- **Bare `image:` key, no Dockerfile** (the brief's "direct-pull variant"):
  even though `public.ecr.aws/skyvern/skyvern`'s arm64 manifest is real and
  multi-arch (verified via `docker manifest inspect`), a bare `image:`
  reference gives Supervisor no way to translate its own options
  (`/data/options.json`) into the env vars Skyvern's process actually reads.
  Something has to run first inside the container to do that translation --
  which needs an entrypoint layer, i.e. a thin wrapper Dockerfile. This
  matches the existing `hermes-agent` add-on in this repo, which uses the
  exact same wrapper pattern (`FROM docker.io/nousresearch/hermes-agent:latest`
  + `run-addon.sh` reading `/data/options.json` via `python3`) rather than a
  bare `image:` key, for the same reason.
- **`run.sh` using `#!/usr/bin/with-contenv bashio` + `bashio::config`** (the
  brief's original Step 2): Skyvern's own image (`python:3.11-slim-bookworm`
  base, confirmed via upstream's Dockerfile) has neither `bashio` nor
  s6-overlay -- there is no `bashio` binary to call. `run.sh` here parses
  `/data/options.json` with `python3` directly instead (same technique as
  `hermes-agent/run-addon.sh`).

So this add-on: `FROM public.ecr.aws/skyvern/skyvern:latest` (already has
python3 -- no base-image swap needed, unlike `skyvern-bitwarden-cli`, which
had to move onto `ghcr.io/hassio-addons/base` for bashio/s6), plus a thin
`run.sh` that exports env vars from `/data/options.json` via `python3`, then
`exec`s into Skyvern's own `/app/entrypoint-skyvern.sh` (path confirmed
against upstream's own Dockerfile -- it `COPY`s and `chmod +x`'s that exact
file, and its `CMD` runs it via `/bin/bash`).

## Verification performed

- `docker manifest inspect public.ecr.aws/skyvern/skyvern:latest`: real OCI
  image index with both `arm64` and `amd64` platform manifests (matches this
  add-on's `arch:` list).
- Upstream's `Dockerfile` (`github.com/skyvern-ai/skyvern/blob/main/Dockerfile`)
  read directly via `gh api`: confirmed final stage is
  `FROM python:3.11-slim-bookworm` (python3 present), confirmed
  `COPY ./entrypoint-skyvern.sh /app/entrypoint-skyvern.sh` +
  `RUN chmod +x /app/entrypoint-skyvern.sh` + `CMD ["/bin/bash", "/app/entrypoint-skyvern.sh"]`.
- Upstream's `entrypoint-skyvern.sh` read directly: confirmed it reads
  `DATABASE_STRING` directly (parses `postgresql+psycopg://user:pass@host:port/db`
  itself), runs `alembic upgrade head`, starts Xvfb/x11vnc/websockify, then
  `python -m skyvern.forge`.
- `watchdog: http://127.0.0.1:8000/api/v1/heartbeat` confirmed correct by
  reading upstream's own `routers.py` (`legacy_base_router` has no built-in
  prefix) and `api_app.py`
  (`fastapi_app.include_router(legacy_base_router, prefix="/api/v1")`), plus
  the `/heartbeat` route itself in `agent_protocol.py`, and cross-checked
  against upstream's own docker-compose healthcheck
  (`http://127.0.0.1:8000/api/v1/heartbeat`) -- all three agree.
- `LLM_KEY` values (`ANTHROPIC_CLAUDE4.7_OPUS`, `OPENAI_GPT5_5`) confirmed
  against upstream's own docker-compose.yml comment block and `.env.example`.
- `BITWARDEN_SERVER` / `BITWARDEN_SERVER_PORT` confirmed as real, consumed
  settings by reading `skyvern/config.py` and
  `skyvern/forge/sdk/services/bitwarden.py` directly (the latter builds
  `BITWARDEN_SERVER_BASE_URL = f"{settings.BITWARDEN_SERVER}:{settings.BITWARDEN_SERVER_PORT or 8002}"`
  -- confirming the "no port in `bitwarden_server`" constraint above).
- `docker build` on the final Dockerfile in this directory: see
  `task-5-report.md` for the actual local build/run result.

## Resource note

Per Task 1's Pi resource check: if free RAM drops under 1 GB with both
`skyvern-server` and `skyvern-bitwarden-cli` idle, treat that as a flag to
monitor before running heavy Task 8/9 tests -- not addressed by this add-on
itself.
