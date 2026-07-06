#!/bin/bash
# Wrapper around upstream's own /app/entrypoint-skyvern.sh: joins Stefan's
# tailnet (userspace networking, no elevated container capabilities needed)
# and forwards local 127.0.0.1:9222 to Chrome's remote-debugging port on his
# always-on Mac over the tailnet, before handing off to the real Skyvern
# entrypoint via exec.
#
# Same tailscaled-userspace + gost pattern as srosenlund/corten-sliplane
# (Corten-Matrix bridge project, same Sliplane server) -- adapted from
# forwarding to a NAC-relay to forwarding to a Chrome CDP port instead.
set -euo pipefail

TS_HOSTNAME="${TS_HOSTNAME:-skyvern-sliplane}"
CDP_TAILNET_ADDR="${CDP_TAILNET_ADDR:-100.85.79.59:9222}"

mkdir -p /data/tailscale

/usr/local/bin/tailscaled \
    --tun=userspace-networking \
    --statedir=/data/tailscale \
    --socks5-server=localhost:1055 &

for i in $(seq 1 30); do
    /usr/local/bin/tailscale status >/dev/null 2>&1 && break
    sleep 1
done

# Idempotent: existing state in /data/tailscale means the authkey is ignored
# on subsequent runs (already-authenticated node).
/usr/local/bin/tailscale up \
    --authkey="${TS_AUTHKEY:?TS_AUTHKEY env var missing}" \
    --hostname="${TS_HOSTNAME}" \
    --accept-dns=false

# Forward local 127.0.0.1:9222 (what BROWSER_REMOTE_DEBUGGING_URL points at)
# over the tailnet SOCKS5 proxy to Chrome's CDP port on the always-on Mac.
/usr/local/bin/gost \
    -L "tcp://127.0.0.1:9222/${CDP_TAILNET_ADDR}" \
    -F "socks5://127.0.0.1:1055" &

# Wait for the tunnel to actually be able to reach Chrome's CDP endpoint
# before handing off -- Skyvern's own boot sequence doesn't retry a dead
# BROWSER_REMOTE_DEBUGGING_URL.
for i in $(seq 1 20); do
    curl -s --max-time 4 -o /dev/null http://127.0.0.1:9222/json/version && break
    sleep 1
done

exec /app/entrypoint-skyvern.sh "$@"
