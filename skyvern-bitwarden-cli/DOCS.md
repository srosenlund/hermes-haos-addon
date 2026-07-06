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
and builds it directly (`ghcr.io/hassio-addons/base:21.0.0` + `apk add nodejs
npm` + `@bitwarden/cli` via npm), rather than referencing a nonexistent
published image. See the Dockerfile header comment and `task-4-report.md` for
the verification (`docker manifest inspect`) behind this and the base-image
fix below.

## Known open risks

Both risks below were found during Task 4's initial Dockerfile-variant
verification (Steps 1-5) and were **resolved in a follow-up fix on
2026-07-06** (see `task-4-report.md` for the full investigation and
verification trail).

1. ~~**Port mismatch.**~~ **Resolved.** The vendored entrypoint hardcodes
   `bw serve --port 8087`. Since this add-on runs with `host_network: true`
   (no port remapping — unlike upstream's own docker-compose `8002:8087`
   mapping), the service is actually reachable at `:8087` on the host, not
   `:8002`. Fixed by changing `config.yaml`'s `watchdog` to
   `http://127.0.0.1:8087/status`. **Task 5 (skyvern-server) must configure
   `BITWARDEN_SERVER_PORT=8087`, not 8002, to match.**
2. ~~**bashio availability.**~~ **Resolved.** `run.sh` uses
   `#!/usr/bin/with-contenv bashio` and `bashio::config`, which require the
   s6-overlay + bashio tooling that `node:24-alpine` doesn't ship. Fixed by
   rebasing the Dockerfile onto `ghcr.io/hassio-addons/base:21.0.0` (verified
   via `docker manifest inspect` to be a real, multi-arch arm64/amd64 image;
   confirmed by pull to be Alpine 3.24 with bashio + s6-overlay preinstalled)
   and installing Node via Alpine's own `apk add nodejs npm` (24.17.0,
   matching the previous `node:24-alpine` major version) on top of it,
   instead of the other way around. `run.sh` is now installed as an
   s6-overlay service (`/etc/services.d/skyvern-bitwarden-cli/run`) rather
   than wired up via a Dockerfile `ENTRYPOINT` override — overriding
   `ENTRYPOINT` would bypass the base image's own `/init`, which is what
   populates `/run/s6/container_environment` that `with-contenv` depends on
   (verified locally: doing so fails immediately with `s6-envdir: fatal:
   unable to envdir /run/s6/container_environment: No such file or
   directory`). `run.sh`'s own content is unchanged from the original brief.

Both fixes were verified locally with `docker build` + `docker run` (image
builds cleanly, `node`/`npm`/`bashio`/`with-contenv` all present and
functional, our service file starts under s6 supervision). Full end-to-end
boot verification requires the real Supervisor API (Steps 6-8, on the actual
Home Assistant host) — a bare `docker run` outside Supervisor fails earlier,
in the *base image's own* `base-addon-log-level` oneshot service, which
needs to reach the real `supervisor` hostname; this is expected and applies
to any `hassio-addons/base`-derived add-on tested this way, not something
introduced by this fix.
