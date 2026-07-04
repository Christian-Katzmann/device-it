#!/usr/bin/env bash
# GitHub Pages deploy: repo deviceit-<slug> (public!), gh-pages branch, URL <user>.github.io/deviceit-<slug>/.
# NOTE: on free GitHub plans the SOURCE REPO is public — the built bundle is world-readable. Disclose.
# Usage: gh-pages.sh <dist> <slug>
set -euo pipefail
DIST="$(cd "$1" && pwd)"
SLUG="$2"
CLEAN=$(echo "$SLUG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g; s/^deviceit-//')
REPO="deviceit-$CLEAN"
USER=$(gh api user --jq .login)

gh repo view "$USER/$REPO" >/dev/null 2>&1 \
  || gh repo create "$REPO" --public --description "device-it app: $CLEAN (built bundle, auto-deployed)" >/dev/null

# Stage: copy dist, add SPA fallback + .nojekyll, force-push as gh-pages (stateless, idempotent).
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -R "$DIST/" "$WORK/"
cp "$WORK/index.html" "$WORK/404.html"
touch "$WORK/.nojekyll"
cd "$WORK"
git init -q -b gh-pages
git add -A
git -c user.name="device-it" -c user.email="device-it@local" commit -qm "deploy"
git push -qf "https://github.com/$USER/$REPO.git" gh-pages

# Enable Pages on the branch (409 = already enabled, fine); enforce HTTPS.
gh api -X POST "repos/$USER/$REPO/pages" -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null 2>&1 || true
gh api -X PUT "repos/$USER/$REPO/pages" -F https_enforced=true -f 'source[branch]=gh-pages' -f 'source[path]=/' >/dev/null 2>&1 || true

URL="https://$USER.github.io/$REPO/"
# Wait for the Pages build to serve (first build can take ~a minute).
for i in $(seq 1 30); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL") || code=0
  [[ "$code" == "200" ]] && break
  sleep 5
done
[[ "$code" == "200" ]] || echo "NOTE=Pages build still propagating; URL should go live shortly" >&2
echo "PROJECT=$USER/$REPO"
echo "URL=$URL"
