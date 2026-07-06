#!/bin/sh
set -e

# Skyvern's own image ships neither bashio nor s6-overlay (unlike
# hassio-addons/base-derived add-ons), so Supervisor options are read
# straight from /data/options.json with python3 -- same pattern as
# hermes-agent/run-addon.sh in this repo, just with a bigger env-var mapping
# since Skyvern takes more options than Hermes Agent does.
eval "$(python3 - <<'PY'
import json, shlex

opts = json.load(open('/data/options.json'))

def export(env, value):
    print(f"export {env}={shlex.quote(str(value))}")

export('DATABASE_STRING', opts.get('database_string', ''))

# Fixed infra defaults. These mirror upstream's own docker-compose.yml
# `environment:` block for the `skyvern` service verbatim (confirmed against
# github.com/skyvern-ai/skyvern/blob/main/docker-compose.yml) -- they are
# compose-network/runtime values, not secrets or per-deployment choices, so
# they are not exposed as add-on options.
export('BROWSER_STREAMING_MODE', 'cdp')
export('BROWSER_TYPE', 'chromium-headful')
export('ENABLE_CODE_BLOCK', 'true')

# Credential vault. Upstream's docker-compose.yml explicitly sets
# CREDENTIAL_VAULT_TYPE=${CREDENTIAL_VAULT_TYPE:-skyvern} and
# ENABLE_LOCAL_CREDENTIAL_VAULT=${ENABLE_LOCAL_CREDENTIAL_VAULT:-true} --
# i.e. the *encrypted local vault* is upstream's own real-world default, even
# though skyvern/config.py's bare class-level default for CREDENTIAL_VAULT_TYPE
# is actually "bitwarden". Without setting this explicitly, this add-on would
# silently expect a reachable Bitwarden server even with Bitwarden disabled.
# Bitwarden (skyvern-bitwarden-cli, Task 4) is optional -- only wired up if
# enable_bitwarden is turned on.
if opts.get('enable_bitwarden'):
    export('CREDENTIAL_VAULT_TYPE', 'bitwarden')
    # NOTE: BITWARDEN_SERVER must NOT include a port -- Skyvern builds the
    # request base URL as f"{BITWARDEN_SERVER}:{BITWARDEN_SERVER_PORT}"
    # (skyvern/forge/sdk/services/bitwarden.py) and appends the port itself.
    export('BITWARDEN_SERVER', opts.get('bitwarden_server', ''))
    export('BITWARDEN_SERVER_PORT', opts.get('bitwarden_server_port', ''))
else:
    export('CREDENTIAL_VAULT_TYPE', 'skyvern')
    export('ENABLE_LOCAL_CREDENTIAL_VAULT', 'true')

# LLM provider. LLM_KEY values (ANTHROPIC_CLAUDE4.7_OPUS / OPENAI_GPT5_5)
# confirmed against upstream's own docker-compose.yml LLM Settings comment
# block and .env.example.
provider = opts.get('llm_provider', 'anthropic')
api_key = opts.get('llm_api_key', '')

if provider == 'openai':
    export('ENABLE_OPENAI', 'true')
    export('LLM_KEY', 'OPENAI_GPT5_5')
    export('OPENAI_API_KEY', api_key)
else:
    export('ENABLE_ANTHROPIC', 'true')
    export('LLM_KEY', 'ANTHROPIC_CLAUDE4.7_OPUS')
    export('ANTHROPIC_API_KEY', api_key)
PY
)"

# /app/entrypoint-skyvern.sh is upstream's own script (confirmed present and
# chmod +x'd in upstream's Dockerfile) -- it handles DB migrations, starts
# Xvfb/x11vnc/websockify for VNC streaming, and finally runs
# `python -m skyvern.forge` (the REST API + MCP endpoint on :8000).
exec /app/entrypoint-skyvern.sh
