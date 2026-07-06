#!/usr/bin/with-contenv bashio
export BW_HOST=$(bashio::config 'bw_host')
export BW_CLIENTID=$(bashio::config 'bw_clientid')
export BW_CLIENTSECRET=$(bashio::config 'bw_clientsecret')
export BW_PASSWORD=$(bashio::config 'bw_master_password')
exec /app/bitwarden-cli-server/entrypoint.sh
