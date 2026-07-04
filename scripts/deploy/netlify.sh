#!/usr/bin/env bash
# Authed Netlify deploy: project deviceit-<slug>, stable URL, in-place updates.
# Usage: netlify.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"
CLEAN=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g; s/^deviceit-//')
NAME="deviceit-$CLEAN"

# Find existing site by name, else create it.
SITE_ID=$(netlify api listSites --data '{"filter":"all"}' 2>/dev/null | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
  try{const s=JSON.parse(d).find(s=>s.name===process.argv[1]);process.stdout.write(s?s.id:"")}catch{}
})' "$NAME")
if [[ -z "$SITE_ID" ]]; then
  SITE_ID=$(netlify sites:create --name "$NAME" --json 2>/dev/null | node -e '
let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{process.stdout.write(JSON.parse(d).id||"")}catch{}})')
fi
[[ -n "$SITE_ID" ]] || { echo "netlify.sh: could not find or create site $NAME (multi-team account? run 'netlify sites:create --name $NAME' once manually)" >&2; exit 1; }

OUT=$(netlify deploy --prod --dir "$DIST" --site "$SITE_ID" --json)
URL=$(echo "$OUT" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{const j=JSON.parse(d);process.stdout.write(j.url||j.ssl_url||"")}catch{}})')
[[ -n "$URL" ]] || URL="https://$NAME.netlify.app"
echo "PROJECT=$NAME"
echo "URL=$URL"
