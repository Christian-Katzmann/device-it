#!/usr/bin/env bash
# Anonymous Netlify deploy — no account needed. Reality of this lane (verified live):
#  - site is claimable for 60 minutes, then DELETED if unclaimed
#  - until claimed, the site sits behind a password (printed below) — claim FIRST, then install
# Prints URL=, PROJECT=, CLAIM_URL=, CLAIM_CLI=, PASSWORD=, EPHEMERAL=until-claimed.
# Usage: netlify-anon.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"

# Run from a scratch dir so netlify CLI state never pollutes the dist.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

OUT=$(npx --yes netlify-cli@26 deploy --dir "$DIST" --allow-anonymous --prod 2>&1) || {
  if echo "$OUT" | grep -qi 'daily limit for anonymous'; then
    echo "netlify-anon: DAILY anonymous-deploy limit reached. Options: log into any host once" >&2
    echo "  (netlify login / vercel login / gh auth login) for unlimited permanent deploys," >&2
    echo "  or retry tomorrow, or use --driver tunnel for a machine-hosted temporary URL." >&2
  else
    echo "netlify-anon: deploy failed" >&2; echo "$OUT" >&2
  fi
  exit 1
}

URL=$(echo "$OUT" | grep -Eo 'https?://[a-z0-9-]+\.netlify\.app' | head -1 || true)
CLAIM=$(echo "$OUT" | grep -Eo 'https://app\.netlify\.com/drop/[^[:space:]]+' | head -1 || true)
PASSWORD=$(echo "$OUT" | grep -o 'Password:[^│]*' | head -1 | sed -E 's/Password:[[:space:]]*//; s/[[:space:]]*$//' || true)
CLAIM_CLI=$(echo "$OUT" | grep -Eo 'netlify claim --site [^[:space:]]+ --token [^[:space:]]+' | head -1 || true)

[[ -n "$URL" ]] || { echo "netlify-anon: could not parse deploy URL" >&2; echo "$OUT" >&2; exit 1; }
URL="https://${URL#*://}"
echo "PROJECT=anonymous"
echo "URL=$URL"
[[ -n "$CLAIM" ]] && echo "CLAIM_URL=$CLAIM"
[[ -n "$CLAIM_CLI" ]] && echo "CLAIM_CLI=$CLAIM_CLI"
[[ -n "$PASSWORD" ]] && echo "PASSWORD=$PASSWORD"
echo "EPHEMERAL=until-claimed"
