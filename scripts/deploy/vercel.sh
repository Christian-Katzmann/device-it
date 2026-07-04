#!/usr/bin/env bash
# Deploy a built dist/ to Vercel as project "deviceit-<slug>". Prints URL=<stable production url>.
# Usage: vercel.sh <dist-dir> <slug>
set -euo pipefail

DIST="$1"
SLUG="$2"
CLEAN=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g; s/^deviceit-//')
PROJECT="deviceit-$CLEAN"
STAGE="$HOME/.device-it/stage/$PROJECT"

[[ -f "$DIST/index.html" ]] || { echo "vercel.sh: $DIST has no index.html" >&2; exit 1; }

# Stage under the project name so Vercel derives the right project; keep .vercel link between runs.
mkdir -p "$STAGE"
rsync -a --delete --exclude '.vercel' "$DIST/" "$STAGE/"

OUT=$(cd "$STAGE" && vercel deploy --prod --yes 2>&1) || { echo "$OUT" >&2; exit 1; }

# Prefer the printed production alias; fall back to the constructed project URL if it resolves.
URL=$(echo "$OUT" | grep -Eo 'https://[a-z0-9.-]+\.vercel\.app' | tail -1)
CANONICAL="https://$PROJECT.vercel.app"
if curl -sfI --max-time 15 "$CANONICAL" >/dev/null 2>&1; then
  URL="$CANONICAL"
fi
[[ -n "$URL" ]] || { echo "vercel.sh: could not determine deploy URL" >&2; echo "$OUT" >&2; exit 1; }
echo "PROJECT=$PROJECT"
echo "URL=$URL"
