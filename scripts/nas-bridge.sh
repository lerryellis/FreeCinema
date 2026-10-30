#!/usr/bin/env bash
# Serves an SMB share (or a local folder / mounted drive) as WebDAV so Ellis TV on the Roku can
# browse and stream it. Roku cannot open SMB itself; this runs on any always-on Mac, PC, Pi or NAS.
#
# Needs rclone (https://rclone.org/install/).  Settings come from the environment or ./.env:
#   SMB_HOST, SMB_SHARE, SMB_USER, SMB_PASS   - the SMB share to expose, or
#   MEDIA_DIR                                 - a local folder / mounted drive instead of SMB
#   BRIDGE_USER, BRIDGE_PASS                  - login the Roku uses (required)
#   BRIDGE_PORT                               - default 8090
#
# On the Roku: * > Set NAS / WebDAV URL >  http://BRIDGE_USER:BRIDGE_PASS@<this machine's IP>:8090/
# Passwords are passed to rclone through environment variables, never on the command line.
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

command -v rclone >/dev/null || { echo "rclone is not installed: https://rclone.org/install/"; exit 1; }
: "${BRIDGE_USER:?Set BRIDGE_USER (the login the Roku will use)}"
: "${BRIDGE_PASS:?Set BRIDGE_PASS (the password the Roku will use)}"
PORT="${BRIDGE_PORT:-8090}"

if [ -n "${MEDIA_DIR:-}" ]; then
    SOURCE="$MEDIA_DIR"
    echo "Serving local folder: $MEDIA_DIR"
else
    : "${SMB_HOST:?Set SMB_HOST (or MEDIA_DIR for a local folder)}"
    : "${SMB_SHARE:?Set SMB_SHARE, the share name on the NAS}"
    export RCLONE_CONFIG_NAS_TYPE=smb
    export RCLONE_CONFIG_NAS_HOST="$SMB_HOST"
    export RCLONE_CONFIG_NAS_USER="${SMB_USER:-guest}"
    if [ -n "${SMB_PASS:-}" ]; then
        RCLONE_CONFIG_NAS_PASS="$(printf '%s' "$SMB_PASS" | rclone obscure -)"
        export RCLONE_CONFIG_NAS_PASS
    fi
    SOURCE="nas:$SMB_SHARE"
    echo "Serving SMB share: //$SMB_HOST/$SMB_SHARE"
fi

# rclone reads --user/--pass from RCLONE_USER/RCLONE_PASS.
export RCLONE_USER="$BRIDGE_USER"
export RCLONE_PASS="$BRIDGE_PASS"

LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo '<this-ip>')"
echo "Roku URL: http://$BRIDGE_USER:<password>@$LAN_IP:$PORT/"
echo "Away from home: install Tailscale on this machine and use its 100.x address instead."

exec rclone serve webdav "$SOURCE" --addr ":$PORT" --read-only --dir-cache-time 5m --vfs-cache-mode off
