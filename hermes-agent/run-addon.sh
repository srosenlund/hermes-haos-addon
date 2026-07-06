#!/bin/sh
set -e

# /data er add-on'ets persistente dir; upstream forventer HERMES_HOME=/opt/data
if [ ! -L /opt/data ]; then
    rm -rf /opt/data
    ln -s /data /opt/data
fi

eval "$(python3 - <<'PY'
import json, shlex
opts = json.load(open('/data/options.json'))
mapping = {
    'deepseek_api_key': 'DEEPSEEK_API_KEY',
    'hass_url': 'HASS_URL',
    'hass_token': 'HASS_TOKEN',
    'hermes_model': 'HERMES_MODEL',
    'hermes_timezone': 'HERMES_TIMEZONE',
    'telegram_bot_token': 'TELEGRAM_BOT_TOKEN',
    'telegram_allowed_users': 'TELEGRAM_ALLOWED_USERS',
    'telegram_home_channel': 'TELEGRAM_HOME_CHANNEL',
}
for key, env in mapping.items():
    print(f"export {env}={shlex.quote(str(opts.get(key, '')))}")
PY
)"

exec /opt/hermes/docker/main-wrapper.sh gateway run
