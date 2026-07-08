# Persistent, headful Chrome for Skyvern to drive over CDP (browser_type=cdp-connect),
# deployed as a plain Sliplane service (not a HAOS add-on).
#
# Why this exists: skyvern-server's own bundled browser (chromium-headful,
# BROWSER_STREAMING_MODE=cdp) is a fresh, throwaway profile per session --
# there is no persistent login. This service is a SEPARATE, always-on Chrome
# with a profile that persists across restarts (mounted at /config), so
# Stefan logs into Google/etc. ONCE via the built-in web UI (Selkies, port
# 3001) and Skyvern reuses that live session on every subsequent run.
#
# Access to the web UI (for the one-time login) is intentionally NOT exposed
# publicly -- port 3001 stays internal-only. Reach it via a Sliplane SSH
# tunnel (see project spec) rather than opening it to the internet, since
# it holds a real, authenticated browser session.
#
# CDP port 9222 is also internal-only -- only skyvern-server (same Sliplane
# server, reached via <service>.internal DNS) needs it.
#
# Known upstream gotcha (Chromium 113+): --remote-debugging-address=0.0.0.0
# is frequently ignored and Chrome binds the CDP port to 127.0.0.1 only
# regardless. Rather than depend on that flag working, we let Chrome bind
# loopback-only (default) and forward it via socat on a separate port
# (19222) that's reachable from other services on this Sliplane server.
FROM lscr.io/linuxserver/chromium:latest

# --remote-allow-origins=* is required separately from the address bind --
# without it Chrome's CDP endpoint rejects WebSocket upgrades from any
# origin other than what it expects, which breaks Skyvern's connection even
# once the socat forward makes the port reachable.
ENV CHROME_CLI="--remote-debugging-port=9222 --remote-allow-origins=*"

RUN apt-get update \
    && apt-get install -y --no-install-recommends socat curl \
    && rm -rf /var/lib/apt/lists/*

# custom-services.d is LinuxServer's documented, stable extension point for
# long-running sidecar processes (survives image updates -- unlike patching
# s6-overlay internals directly). Runs alongside Chrome, not instead of it.
COPY custom-services.d/cdp-forward /custom-services.d/cdp-forward
RUN chmod +x /custom-services.d/cdp-forward
