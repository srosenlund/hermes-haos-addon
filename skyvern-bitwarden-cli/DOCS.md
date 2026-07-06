# Skyvern Bitwarden CLI add-on

`bw serve` REST wrapper (Bitwarden CLI, unlocked against a vault) so Skyvern's
`skyvern-server` add-on (Task 5) can look up credentials over
`BITWARDEN_SERVER` / `BITWARDEN_SERVER_PORT`.

Options map 1:1 to the vault login/unlock flow:

- `bw_host`: vault server URL (default `https://vault.bitwarden.com`; point at
  a self-hosted Vaultwarden URL if that's what Task 3's credentials are for)
- `bw_clientid` / `bw_clientsecret`: Bitwarden API key credentials
- `bw_master_password`: master password used for `bw unlock`

Secrets are set in the add-on's own configuration (Supervisor), never baked
into the image.

## Build source note

Upstream Skyvern (`github.com/skyvern-ai/skyvern`, AGPL-3.0) does not publish
a standalone `bitwarden-cli-server` image on any registry — its own
`docker-compose.yml` only builds that component from a local build context.
This add-on's `Dockerfile` therefore vendors the upstream
`bitwarden-cli-server/entrypoint.sh` unmodified (same directory as this file)
and builds it directly (`node:24-alpine` + `@bitwarden/cli` via npm), rather
than referencing a nonexistent published image. See the Dockerfile header
comment and `task-4-report.md` for the verification (`docker manifest
inspect`) behind this.

## Known open risks (not resolved by this task — flagging for Steps 6-8)

1. **Port mismatch.** The vendored entrypoint hardcodes
   `bw serve --port 8087`. `config.yaml`'s `watchdog` and Task 5's expected
   `BITWARDEN_SERVER_PORT` both assume **8002**. Upstream's own
   docker-compose maps host `8002 -> container 8087`, but this add-on runs
   with `host_network: true`, which does **not** remap ports — whatever the
   process binds to is what's reachable on the host. As shipped, the service
   will actually be reachable at `:8087`, not `:8002`. Resolve before Step 6
   by either patching the vendored entrypoint's `--port` flag, or adjusting
   `config.yaml`'s `watchdog` + Task 5's `BITWARDEN_SERVER_PORT` to 8087.
2. **bashio availability.** `run.sh` uses `#!/usr/bin/with-contenv bashio` and
   `bashio::config`, which requires the s6-overlay + bashio tooling shipped
   in Home Assistant's own base images (`ghcr.io/home-assistant/*-base`).
   This Dockerfile is `FROM node:24-alpine` (neither of the plan's two
   proposed base images resolve either — see above), which does not include
   that tooling. As shipped, `run.sh` will likely fail to execute at
   container start. Resolve before Step 6, e.g. by layering on top of an
   `hassio-addons/base` image, or by rewriting `run.sh` to read options via
   the add-on's mounted `/data/options.json` with `jq` instead of `bashio`.

Both risks were found during Task 4's Dockerfile-variant verification but are
outside Task 4's Steps 1-5 scope (file authoring) to fix.
