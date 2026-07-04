#!/usr/bin/env bash
# Cloudflare Pages deploy: project deviceit-<slug>, URL deviceit-<slug>.pages.dev.
# Usage: cloudflare.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"
CLEAN=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g; s/^deviceit-//')
NAME="deviceit-$CLEAN"

wrangler pages project list 2>/dev/null | grep -q "\b$NAME\b" \
  || wrangler pages project create "$NAME" --production-branch main >/dev/null

OUT=$(wrangler pages deploy "$DIST" --project-name "$NAME" --branch main 2>&1) \
  || { echo "$OUT" >&2; exit 1; }
URL="https://$NAME.pages.dev"
curl -sfI --max-time 20 "$URL" >/dev/null 2>&1 || URL=$(echo "$OUT" | grep -Eo 'https://[a-z0-9.-]+\.pages\.dev' | tail -1)
echo "PROJECT=$NAME"
echo "URL=$URL"
