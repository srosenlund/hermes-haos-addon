#!/usr/bin/with-contenv bashio
export BW_HOST=$(bashio::config 'bw_host')
export BW_CLIENTID=$(bashio::config 'bw_clientid')
export BW_CLIENTSECRET=$(bashio::config 'bw_clientsecret')
export BW_PASSWORD=$(bashio::config 'bw_master_password')
# Drop from root (this service starts as root, like every s6-overlay legacy
# service on this base image) to the unprivileged `bw` user (created in the
# Dockerfile) before handing off to entrypoint.sh, which is what actually
# handles the master password and session token via `bw unlock`/`bw serve`.
# `s6-setuidgid` (bundled with s6-overlay on this base image) does the
# setuid/setgid + supplementary-groups drop but, unlike a real login, does NOT
# reset $HOME -- verified locally (`s6-setuidgid bw env` still showed the
# inherited root shell's HOME). So HOME is set explicitly here to the `bw`
# user's real home directory (chowned to bw:bw in the Dockerfile) before the
# exec, so `@bitwarden/cli`'s config/data file resolves under a directory `bw`
# can actually write to instead of falling through to /root.
export HOME=/home/bw
exec s6-setuidgid bw /app/bitwarden-cli-server/entrypoint.sh
