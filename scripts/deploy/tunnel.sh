#!/usr/bin/env bash
# Last-resort zero-account lane: serve dist locally + cloudflared quick tunnel.
# EPHEMERAL: URL only lives while this machine runs these processes. Prints stop instructions.
# Usage: tunnel.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"
command -v cloudflared >/dev/null || { echo "tunnel.sh: cloudflared not installed (brew install cloudflared)" >&2; exit 1; }

RUN="$HOME/.device-it/tunnel"
mkdir -p "$RUN"
PORT=$(( 8700 + RANDOM % 200 ))

nohup npx --yes serve -l "$PORT" -n "$DIST" > "$RUN/$SLUG-serve.log" 2>&1 &
echo $! > "$RUN/$SLUG-serve.pid"
nohup cloudflared tunnel --url "http://127.0.0.1:$PORT" > "$RUN/$SLUG-tunnel.log" 2>&1 &
echo $! > "$RUN/$SLUG-tunnel.pid"

URL=""
for i in $(seq 1 20); do
  URL=$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$RUN/$SLUG-tunnel.log" | head -1 || true)
  [[ -n "$URL" ]] && break
  sleep 1
done
[[ -n "$URL" ]] || { echo "tunnel.sh: tunnel did not come up; see $RUN/$SLUG-tunnel.log" >&2; exit 1; }

echo "PROJECT=tunnel:$SLUG"
echo "URL=$URL"
echo "EPHEMERAL=while-machine-runs"
echo "NOTE=stop with: kill \$(cat $RUN/$SLUG-serve.pid $RUN/$SLUG-tunnel.pid)"
