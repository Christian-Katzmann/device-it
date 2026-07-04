#!/usr/bin/env bash
# device-it orchestrator: one command from project dir → app on your device (or QR).
#   run.sh [project-dir] [--icon img] [--name "Name"] [--slug slug] [--driver name] [--skip-verify]
#   run.sh --url https://already-hosted.app --name "Name" [--icon img] [--slug slug]   # wrap mode
#   run.sh remove <slug>
set -euo pipefail
S="$(cd "$(dirname "$0")" && pwd)"
OUT_HOME="$HOME/.device-it/out"; mkdir -p "$OUT_HOME"
CFG="$HOME/.device-it/config.json"

mdm_enrolled() {
  python3 -c 'import json,sys;c=json.load(open("'"$CFG"'"));sys.exit(0 if c.get("devices") else 1)' 2>/dev/null
}

# ---- remove verb -----------------------------------------------------------
if [[ "${1:-}" == "remove" ]]; then
  SLUG="$2"
  if mdm_enrolled; then
    bash "$S/mdm/mdm-up.sh" >/dev/null && node "$S/mdm/mdm-push.mjs" remove --identifier "dk.deviceit.$SLUG" || true
    bash "$S/mdm/mdm-down.sh" >/dev/null || true
  fi
  DRIVER=$(node "$S/registry.mjs" get "$SLUG" 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("driver",""))' 2>/dev/null || true)
  case "$DRIVER" in
    vercel) vercel remove "deviceit-$SLUG" --yes 2>/dev/null || true;;
    gh-pages) echo "(gh-pages: delete repo manually if wanted: gh repo delete deviceit-$SLUG)";;
    tunnel) kill $(cat "$HOME/.device-it/tunnel/$SLUG-"*.pid 2>/dev/null) 2>/dev/null || true;;
    *) :;;
  esac
  node "$S/registry.mjs" remove "$SLUG"
  echo "REMOVED=$SLUG"; exit 0
fi

# ---- args ------------------------------------------------------------------
PROJ="$PWD"; ICON=""; NAME=""; SLUG=""; SKIP_VERIFY=0; DRIVER_FLAG=""; WRAP_URL=""
while [[ $# -gt 0 ]]; do case "$1" in
  --icon) ICON="$2"; shift 2;;
  --name) NAME="$2"; shift 2;;
  --slug) SLUG="$2"; shift 2;;
  --driver) DRIVER_FLAG="$2"; shift 2;;
  --url) WRAP_URL="$2"; shift 2;;
  --skip-verify) SKIP_VERIFY=1; shift;;
  *) PROJ="$1"; shift;;
esac; done

# ---- wrap mode: existing hosted URL → just make it installable ---------------
if [[ -n "$WRAP_URL" ]]; then
  [[ -n "$SLUG" ]] || SLUG=$(python3 -c "from urllib.parse import urlparse;h=urlparse('$WRAP_URL').hostname or 'app';print(h.split('.')[0].lower())")
  [[ -n "$NAME" ]] || NAME=$(python3 -c "print('$SLUG'.replace('-',' ').title())")
  if [[ -z "$ICON" || ! -f "$ICON" ]]; then
    ICON="$OUT_HOME/$SLUG-monogram.png"
    L=$(echo "$NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')
    magick -size 1024x1024 xc:'#14161A' -fill '#7fd4a8' -draw 'roundrectangle 96,96 928,928 200,200' \
      -fill '#14161A' -font Helvetica -pointsize 520 -gravity center -annotate +0+10 "$L" "$ICON" 2>/dev/null \
    || magick -size 1024x1024 xc:'#14161A' -fill '#7fd4a8' -draw 'roundrectangle 96,96 928,928 200,200' "$ICON"
  fi
  ICON_DIR="$OUT_HOME/$SLUG-icons"
  bash "$S/icons.sh" "$ICON" "$ICON_DIR" >/dev/null
  node "$S/webclip.mjs" --slug "$SLUG" --name "$NAME" --url "$WRAP_URL" \
    --icon "$ICON_DIR/apple-touch-icon-180.png" --out "$OUT_HOME/$SLUG.mobileconfig" >/dev/null
  node "$S/registry.mjs" add "{\"slug\":\"$SLUG\",\"name\":\"$NAME\",\"url\":\"$WRAP_URL\",\"project\":\"wrapped\",\"driver\":\"wrap\",\"profileIdentifier\":\"dk.deviceit.$SLUG\"}" >/dev/null
  if mdm_enrolled; then
    bash "$S/mdm/mdm-up.sh" >/dev/null
    node "$S/mdm/mdm-push.mjs" install --profile "$OUT_HOME/$SLUG.mobileconfig"
    bash "$S/mdm/mdm-down.sh" >/dev/null
    echo "TIER1=pushed"
  else
    bash "$S/qr.sh" "$WRAP_URL" "$OUT_HOME/$SLUG-qr.png"
    echo "TIER2=qr ($OUT_HOME/$SLUG-qr.png)"
  fi
  echo "MODE=wrap (no build/deploy — offline & Android install quality depend on the site itself)"
  echo "APP=$NAME"; echo "SLUG=$SLUG"; echo "URL=$WRAP_URL"; echo "PROFILE=$OUT_HOME/$SLUG.mobileconfig"
  exit 0
fi

PROJ="$(cd "$PROJ" && pwd)"

# ---- inspect ---------------------------------------------------------------
INS=$(bash "$S/inspect.sh" "$PROJ")
echo "$INS"
val(){ echo "$INS" | grep "^$1=" | head -1 | cut -d= -f2-; }
FRAMEWORK=$(val FRAMEWORK); OUT_DIR=$(val OUT_DIR); PKG=$(val NAME)
[[ -n "$SLUG" ]] || SLUG=$(echo "$PKG" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+|-+$//g')
[[ -n "$NAME" ]] || NAME=$(python3 -c "print('$SLUG'.replace('-',' ').title())")

# ---- pick deploy driver (before pwaify: the anonymous lane needs the claim banner baked in)
PICK=$(node "$S/deploy/pick.mjs" "$DRIVER_FLAG")
DRIVER=$(echo "$PICK" | grep '^DRIVER=' | cut -d= -f2)
echo "$PICK"

# ---- build -----------------------------------------------------------------
cd "$PROJ"
case "$FRAMEWORK" in
  vite)  npx vite build --base ./ ;;
  static) OUT_DIR="." ;;
  *)     $(val BUILD_CMD) ;;
esac
DIST="$PROJ/$OUT_DIR"
[[ -f "$DIST/index.html" ]] || { echo "run.sh: no index.html in $DIST" >&2; exit 1; }

# ---- icon resolve ----------------------------------------------------------
if [[ -z "$ICON" ]]; then
  ICON=$(val ICON_CANDIDATES | cut -d, -f1)
fi
if [[ -z "$ICON" ]]; then
  # app-it sibling? lift the Mac app's icns
  for APP in "$HOME/Applications/App It/"*.app; do
    ICNS="$APP/Contents/Resources/AppIcon.icns"
    if [[ -f "$ICNS" ]] && strings "$APP/Contents/MacOS/"* 2>/dev/null | grep -q "PROJECT_ROOT=\"$PROJ\""; then
      ICON="$OUT_HOME/$SLUG-from-icns.png"
      sips -s format png "$ICNS" --out "$ICON" >/dev/null
      echo "ICON_SOURCE=app-it ($APP)"
      break
    fi
  done
fi
if [[ -z "$ICON" || ! -f "$ICON" ]]; then
  # monogram placeholder — never block on a missing icon
  ICON="$OUT_HOME/$SLUG-monogram.png"
  L=$(echo "$NAME" | cut -c1 | tr '[:lower:]' '[:upper:]')
  magick -size 1024x1024 xc:'#14161A' -fill '#7fd4a8' -draw 'roundrectangle 96,96 928,928 200,200' \
    -fill '#14161A' -font Helvetica -pointsize 520 -gravity center -annotate +0+10 "$L" "$ICON" 2>/dev/null \
  || magick -size 1024x1024 xc:'#14161A' -fill '#7fd4a8' -draw 'roundrectangle 96,96 928,928 200,200' "$ICON"
  echo "ICON_SOURCE=generated monogram (replace with --icon anytime)"
fi

# ---- icons + pwaify + deploy ------------------------------------------------
ICON_DIR="$OUT_HOME/$SLUG-icons"
bash "$S/icons.sh" "$ICON" "$ICON_DIR" >/dev/null
CLAIM_ARGS=""
[[ "$DRIVER" == "netlify-anon" ]] && CLAIM_ARGS="--claim-banner 1"
# shellcheck disable=SC2086 — deliberate word-split of fixed tokens (bash-3.2-safe empty "array")
node "$S/pwaify.mjs" --dist "$DIST" --name "$NAME" --icons "$ICON_DIR" $CLAIM_ARGS

DEPLOY=$(bash "$S/deploy/$DRIVER.sh" "$DIST" "$SLUG")
echo "$DEPLOY"
URL=$(echo "$DEPLOY" | grep '^URL=' | cut -d= -f2-)
PROJECT=$(echo "$DEPLOY" | grep '^PROJECT=' | cut -d= -f2- || true)
CLAIM_URL=$(echo "$DEPLOY" | grep '^CLAIM_URL=' | cut -d= -f2- || true)
PASSWORD=$(echo "$DEPLOY" | grep '^PASSWORD=' | cut -d= -f2- || true)
EPHEMERAL=$(echo "$DEPLOY" | grep '^EPHEMERAL=' | cut -d= -f2- || true)

# Anonymous sites sit behind a password until claimed → HTTP verify would 401. Defer it.
if [[ "$DRIVER" == "netlify-anon" && $SKIP_VERIFY -eq 0 ]]; then
  SKIP_VERIFY=1
  echo "VERIFY=deferred (site is password-gated until claimed — claim first, then it verifies)"
fi

# ---- verify ------------------------------------------------------------------
if [[ $SKIP_VERIFY -eq 0 ]]; then
  node "$S/verify.mjs" --url "$URL" > "$OUT_HOME/$SLUG-verify.json" \
    || { echo "VERIFY=FAILED — see $OUT_HOME/$SLUG-verify.json" >&2; exit 1; }
  echo "VERIFY=ok ($(python3 -c "import json;d=json.load(open('$OUT_HOME/$SLUG-verify.json'));print(f\"{sum(r['ok'] for r in d['results'])}/{len(d['results'])} checks, offline {d['offline']}\")"))"
fi

# ---- install artifacts -------------------------------------------------------
node "$S/webclip.mjs" --slug "$SLUG" --name "$NAME" --url "$URL" \
  --icon "$ICON_DIR/apple-touch-icon-180.png" --out "$OUT_HOME/$SLUG.mobileconfig" >/dev/null
node "$S/registry.mjs" add "{\"slug\":\"$SLUG\",\"name\":\"$NAME\",\"url\":\"$URL\",\"project\":\"$PROJECT\",\"driver\":\"$DRIVER\",\"profileIdentifier\":\"dk.deviceit.$SLUG\"}" >/dev/null

# QR target carries the claim URL so the in-page banner can pick it up.
QR_TARGET="$URL"
if [[ -n "$CLAIM_URL" ]]; then
  ENC=$(node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$CLAIM_URL")
  QR_TARGET="$URL/#claim=$ENC"
  # Open the claim page on this computer right away — usually one GitHub-SSO click.
  case "$(uname)" in
    Darwin) open "$CLAIM_URL" 2>/dev/null || true;;
    Linux)  xdg-open "$CLAIM_URL" 2>/dev/null || true;;
  esac
  echo "CLAIM_URL=$CLAIM_URL"
  echo "CLAIM_NOTE=claim within 1 HOUR or the site is deleted; claiming makes it permanent + free and removes the password gate"
  [[ -n "$PASSWORD" ]] && echo "SITE_PASSWORD=$PASSWORD (needed only until claimed)"
fi

if mdm_enrolled; then
  bash "$S/mdm/mdm-up.sh" >/dev/null
  node "$S/mdm/mdm-push.mjs" install --profile "$OUT_HOME/$SLUG.mobileconfig"
  bash "$S/mdm/mdm-down.sh" >/dev/null
  echo "TIER1=pushed"
else
  bash "$S/qr.sh" "$QR_TARGET" "$OUT_HOME/$SLUG-qr.png"
  bash "$S/send-imessage.sh" "$QR_TARGET" "$NAME — install link" || true
  echo "TIER2=qr ($OUT_HOME/$SLUG-qr.png)"
fi

echo "DRIVER=$DRIVER"
[[ -n "$EPHEMERAL" ]] && echo "EPHEMERAL=$EPHEMERAL"
echo "APP=$NAME"
echo "SLUG=$SLUG"
echo "URL=$URL"
echo "PROFILE=$OUT_HOME/$SLUG.mobileconfig"
