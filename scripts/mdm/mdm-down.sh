#!/usr/bin/env bash
# Stop the pocket MDM and close the funnel. Safe to run when already down.
set -uo pipefail

MDM_DIR="$HOME/.device-it/mdm"
PIDFILE="$MDM_DIR/nanomdm.pid"

if [[ -f "$PIDFILE" ]]; then
  kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"
  echo "nanomdm stopped"
fi
tailscale funnel --https=443 --set-path /mdm off 2>/dev/null \
  || tailscale funnel --https=443 off 2>/dev/null \
  || tailscale funnel 9930 off 2>/dev/null \
  || tailscale serve reset 2>/dev/null || true
echo "funnel closed"
