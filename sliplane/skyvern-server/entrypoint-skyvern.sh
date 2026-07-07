#!/bin/bash

set -e

# Diagnostic (sliplane variant only, not upstream): print the actually
# resolved LLM settings at boot, since the entrypoint's env-var-driven
# config has repeatedly not matched observed runtime behavior (generate_task
# keeps calling Anthropic regardless of LLM_KEY/SECONDARY_LLM_KEY/ENABLE_*
# changes). Reading it directly from skyvern.config.settings is the only
# way to confirm what Python actually sees, since there's no shell/exec
# access into a running Sliplane container.
python -c "
from skyvern.config import settings
print('DIAG LLM_KEY=' + repr(settings.LLM_KEY))
print('DIAG SECONDARY_LLM_KEY=' + repr(settings.SECONDARY_LLM_KEY))
print('DIAG ENABLE_ANTHROPIC=' + repr(settings.ENABLE_ANTHROPIC))
print('DIAG ENABLE_OPENAI=' + repr(settings.ENABLE_OPENAI))
print('DIAG ENABLE_OPENROUTER=' + repr(settings.ENABLE_OPENROUTER))
print('DIAG OPENROUTER_MODEL=' + repr(settings.OPENROUTER_MODEL))
print('DIAG ANTHROPIC_CUA_LLM_KEY=' + repr(settings.ANTHROPIC_CUA_LLM_KEY))
from skyvern.forge.sdk.api.llm.config_registry import LLMConfigRegistry
print('DIAG registered_models=' + repr(LLMConfigRegistry.get_model_names()))
" 2>&1 || echo "DIAG script failed to run"

# ---------------------------------------------------------------------------
# Ensure the target database exists (POSTGRES_DB is only honoured on first
# volume init — a stale postgres-data dir means the DB may be missing).
# ---------------------------------------------------------------------------
if [ -n "$DATABASE_STRING" ]; then
    # Parse postgresql+psycopg://user:pass@host:port/dbname
    db_name=$(echo "$DATABASE_STRING" | sed -n 's|.*/.*/\([^?]*\).*|\1|p')
    db_user=$(echo "$DATABASE_STRING" | sed -n 's|.*://\([^:]*\):.*|\1|p')
    db_host=$(echo "$DATABASE_STRING" | sed -n 's|.*@\([^:]*\):.*|\1|p')
    db_port=$(echo "$DATABASE_STRING" | sed -n 's|.*:\([0-9]*\)/.*|\1|p')

    if [ -n "$db_name" ] && [ -n "$db_user" ] && [ -n "$db_host" ]; then
        export PGHOST="$db_host"
        export PGPORT="${db_port:-5432}"
        export PGUSER="$db_user"
        # Extract password (between first : after :// and @)
        db_pass=$(echo "$DATABASE_STRING" | sed -n 's|.*://[^:]*:\([^@]*\)@.*|\1|p')
        if [ -n "$db_pass" ]; then
            export PGPASSWORD="$db_pass"
        fi

        if psql -d "$db_name" -c "SELECT 1" > /dev/null 2>&1; then
            echo "✅ Database '$db_name' exists."
        else
            echo "Database '$db_name' not found — creating..."
            createdb "$db_name" && echo "✅ Database '$db_name' created." \
                || echo "⚠️  Could not create database '$db_name' — migrations may fail."
        fi
        unset PGPASSWORD
    fi
fi

# Set ALLOWED_SKIP_DB_MIGRATION_VERSION env var to the DB version you want to allow (select * from alembic_version)
# If current DB matches this version, migrations will be skipped. Use at your own risk.
ALLOWED_SKIP_DB_MIGRATION_VERSION=${ALLOWED_SKIP_DB_MIGRATION_VERSION:-}

# Run migrations by default
run_migration=true

if [ -n "$ALLOWED_SKIP_DB_MIGRATION_VERSION" ]; then
    current_version=$(alembic current 2>&1 | grep -Eo "[0-9a-f]{12,}" | tail -n 1 || echo "")
    echo "Current DB version: $current_version"

    if [ "$current_version" = "$ALLOWED_SKIP_DB_MIGRATION_VERSION" ]; then
        echo "⚠️  WARNING: Skipping database migrations"
        echo "⚠️  DB is at version $current_version which matches ALLOWED_SKIP_DB_MIGRATION_VERSION"
        echo "⚠️  Running older code against newer database schema"
        echo "⚠️  Beware of compatibility risks!"
        run_migration=false
    else
        echo "Current DB version ($current_version) does not match ALLOWED_SKIP_DB_MIGRATION_VERSION ($ALLOWED_SKIP_DB_MIGRATION_VERSION)"
    fi
fi

if [ "$run_migration" = true ]; then
    echo "Running database migrations..."
    alembic upgrade head
    alembic check || echo "WARNING: alembic check reported schema drift (expected in this deployment -- Skyvern shares a Supabase project with an unrelated app under a separate schema, so its schema-wide comparison sees foreign tables). Continuing anyway; migrations already applied successfully via alembic upgrade head above."
fi

SKYVERN_CREDENTIALS_FILE="${SKYVERN_CREDENTIALS_FILE:-/app/.skyvern/credentials.toml}"
mkdir -p "$(dirname "$SKYVERN_CREDENTIALS_FILE")"

if [ ! -f "$SKYVERN_CREDENTIALS_FILE" ]; then
    echo "Creating organization and API token..."
    org_output=$(python scripts/create_organization.py Skyvern-Open-Source)
    api_token=$(echo "$org_output" | awk '/token=/{gsub(/.*token='\''|'\''.*/, ""); print}')
    echo -e "[skyvern]\nconfigs = [\n    {\"env\" = \"local\", \"host\" = \"http://skyvern:8000/api/v1\", \"orgs\" = [{name=\"Skyvern\", cred=\"$api_token\"}]}\n]" > "$SKYVERN_CREDENTIALS_FILE"
    echo "$SKYVERN_CREDENTIALS_FILE file updated with organization details."
    # Patch (sliplane variant only, not upstream): upstream never logs the
    # generated API token anywhere visible -- it's only captured into the
    # $org_output/$api_token shell variables and written to a file inside
    # the container's (ephemeral, per-deploy) filesystem. On Sliplane there
    # is no shell/exec access into the running container to read that file
    # back out, so echo the token to stdout once here -- it's the only way
    # to retrieve it via `sliplane_client.get_logs()`.
    echo "SKYVERN_API_TOKEN=$api_token"
fi

_kill_xvfb_on_term() {
  kill -TERM $xvfb
}

# Setup a trap to catch SIGTERM and relay it to child processes
trap _kill_xvfb_on_term TERM

echo "Starting Xvfb..."
# delete the lock file if any
rm -f /tmp/.X99-lock
# Set display environment variable
export DISPLAY=:99
# Start Xvfb
Xvfb :99 -screen 0 1920x1080x16 &
xvfb=$!

DISPLAY=:99 xterm 2>/dev/null &

# Wait for Xvfb to be ready before starting x11vnc
for i in $(seq 1 10); do
  xdpyinfo -display :99 >/dev/null 2>&1 && break
  echo "Waiting for Xvfb to start (attempt $i/10)..."
  sleep 1
done
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  echo "ERROR: Xvfb failed to start on display :99 after 10 attempts"
  exit 1
fi

echo "Starting x11vnc on display :99..."
# VNC runs without a password (-nopw) because port 5900 is not exposed outside
# the container. Browser streaming reaches users via websockify on port 6080.
mkdir -p /data/log
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 -bg -o /dev/null 2>/data/log/x11vnc.err

echo "Starting websockify on port 6080 -> localhost:5900..."
websockify 6080 localhost:5900 --daemon

python run_streaming.py > /dev/null &

# Run the command and pass in all three arguments
python -m skyvern.forge
