#!/usr/bin/env bash
# Zips the app and sideloads it to a Roku in Developer Mode on the local network.
# Usage: ROKU_IP=192.168.1.50 ROKU_PASS=yourpass ./scripts/deploy.sh
# (or put ROKU_IP / ROKU_PASS in a .env file at the repo root)
set -euo pipefail

cd "$(dirname "$0")/.."
[ -f .env ] && set -a && . ./.env && set +a

: "${ROKU_IP:?Set ROKU_IP to the Roku IP address (Settings > Network > About)}"
: "${ROKU_PASS:?Set ROKU_PASS to the developer password you chose when enabling Developer Mode}"

mkdir -p out
rm -f out/FreeCinema.zip
zip -qr out/FreeCinema.zip manifest source components images
echo "Packaged out/FreeCinema.zip"

echo "Uploading to Roku at $ROKU_IP ..."
response=$(curl -sS --digest -u "rokudev:$ROKU_PASS" \
    -F "mysubmit=Install" \
    -F "archive=@out/FreeCinema.zip" \
    "http://$ROKU_IP/plugin_install")

if echo "$response" | grep -qiE "Install Success|Identical to previous version"; then
    echo "Installed. Launching..."
    curl -sS -m 5 -d '' "http://$ROKU_IP:8060/launch/dev" >/dev/null 2>&1 || true
    echo "Done. Debug console: telnet $ROKU_IP 8085"
else
    echo "Install failed. Roku responded:"
    echo "$response" | sed -e 's/<[^>]*>//g' | grep -v '^\s*$' | tail -20
    exit 1
fi
