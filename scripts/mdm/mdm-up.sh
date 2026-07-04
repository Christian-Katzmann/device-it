#!/usr/bin/env bash
# Start the pocket MDM (nanomdm on 127.0.0.1:9930) + Tailscale Funnel in front of it.
# Idempotent: safe to run when already up. Prints SERVER_URL=...
set -euo pipefail

MDM_DIR="$HOME/.device-it/mdm"
BIN="$HOME/.device-it/bin/nanomdm"
PORT=9930
PIDFILE="$MDM_DIR/nanomdm.pid"
LOG="$MDM_DIR/nanomdm.log"

[[ -x "$BIN" ]] || { echo "mdm-up: nanomdm binary missing at $BIN (run setup)" >&2; exit 1; }
[[ -f "$MDM_DIR/ca.pem" ]] || { echo "mdm-up: CA missing (run make-ca.sh via setup)" >&2; exit 1; }

API_KEY=$(security find-generic-password -s device-it-nanomdm -a nanomdm -w 2>/dev/null) \
  || { echo "mdm-up: API key not in keychain (run setup)" >&2; exit 1; }

# nanomdm
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  :
else
  mkdir -p "$MDM_DIR/dbkv"
  nohup "$BIN" -listen "127.0.0.1:$PORT" -api "$API_KEY" -ca "$MDM_DIR/ca.pem" \
    -storage filekv -storage-dsn "$MDM_DIR/dbkv" >>"$LOG" 2>&1 &
  echo $! > "$PIDFILE"
  sleep 1
  kill -0 "$(cat "$PIDFILE")" 2>/dev/null || { echo "mdm-up: nanomdm failed to start; tail $LOG" >&2; tail -5 "$LOG" >&2; exit 1; }
fi

# Tailscale up + funnel
tailscale status >/dev/null 2>&1 || { echo "mdm-up: tailscale not running — run: tailscale up" >&2; exit 1; }
if ! tailscale funnel status 2>/dev/null | grep -q ":$PORT"; then
  tailscale funnel --bg "$PORT" >/dev/null
fi

HOST=$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
[[ -n "$HOST" ]] || { echo "mdm-up: could not resolve tailnet DNS name" >&2; exit 1; }
echo "SERVER_URL=https://$HOST"
echo "NANOMDM=127.0.0.1:$PORT pid=$(cat "$PIDFILE")"
