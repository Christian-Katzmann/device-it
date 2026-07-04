#!/usr/bin/env bash
# Surge deploy: deviceit-<slug>.surge.sh. Needs SURGE_LOGIN/SURGE_TOKEN (env or config.deploy.surge).
# First-time account creation is interactive-by-design: run `npx surge` once (email+password,
# created inline, no browser), then `npx surge token`, and store both in config.
# Usage: surge.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"
CLEAN=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g; s/^deviceit-//')
DOMAIN="deviceit-$CLEAN.surge.sh"

CFG="$HOME/.device-it/config.json"
if [[ -z "${SURGE_LOGIN:-}" && -f "$CFG" ]]; then
  SURGE_LOGIN=$(python3 -c 'import json;print(json.load(open("'"$CFG"'")).get("deploy",{}).get("surge",{}).get("login",""))')
  SURGE_TOKEN=$(python3 -c 'import json;print(json.load(open("'"$CFG"'")).get("deploy",{}).get("surge",{}).get("token",""))')
  export SURGE_LOGIN SURGE_TOKEN
fi
[[ -n "${SURGE_TOKEN:-}" ]] || { echo "surge.sh: no surge credentials. One-time: 'npx surge' (creates account inline), then 'npx surge token', store in config.deploy.surge.{login,token}" >&2; exit 1; }

# SPA fallback: surge serves 200.html for unknown routes.
cp -f "$DIST/index.html" "$DIST/200.html"
npx --yes surge "$DIST" "$DOMAIN" >/dev/null
rm -f "$DIST/200.html"
echo "PROJECT=$DOMAIN"
echo "URL=https://$DOMAIN"
