#!/usr/bin/env bash
# device-it doctor: report the health of every layer. Exit 0 = all green for the configured lanes.
set -uo pipefail

OK=0; WARN=0; FAIL=0
ok()   { echo "  ✓ $1"; OK=$((OK+1)); }
warn() { echo "  ~ $1"; WARN=$((WARN+1)); }
bad()  { echo "  ✗ $1"; FAIL=$((FAIL+1)); }

CFG="$HOME/.device-it/config.json"
MDM_DIR="$HOME/.device-it/mdm"

echo "[toolchain]"
command -v node >/dev/null && ok "node $(node --version)" || bad "node missing"
{ command -v magick >/dev/null && ok "imagemagick"; } || { command -v sips >/dev/null && warn "sips only (icons still work)"; }
command -v plutil >/dev/null && ok "plutil" || bad "plutil missing"

echo "[deploy]"
PICK=$(node "$(dirname "$0")/deploy/pick.mjs" 2>/dev/null | tr '\n' ' ')
if echo "$PICK" | grep -q 'DRIVER=netlify-anon'; then
  warn "no deploy account authed — will use anonymous Netlify (claim-within-1-hour). Any of: vercel/netlify/wrangler/gh login upgrades this permanently."
else
  ok "driver: $PICK"
fi

echo "[zero-touch lane: pocket MDM (Apple devices)]"
ENROLLED=$(python3 -c 'import json;print(1 if json.load(open("'"$CFG"'")).get("devices") else 0)' 2>/dev/null || echo 0)
if [[ "$ENROLLED" != "1" ]]; then
  warn "no device enrolled — the scan lane works now; run '/device-it setup' for no-tap Apple installs"
else
  ok "device(s) enrolled"
  [[ -x "$HOME/.device-it/bin/nanomdm" ]] && ok "nanomdm binary" || bad "nanomdm binary missing"
  [[ -f "$MDM_DIR/ca.pem" ]] && ok "device CA" || bad "device CA missing"
  security find-generic-password -s device-it-nanomdm -a nanomdm -w >/dev/null 2>&1 \
    && ok "API key in keychain" || bad "API key missing from keychain"

  if [[ -f "$MDM_DIR/push.pem" ]]; then
    END=$(openssl x509 -enddate -noout -in "$MDM_DIR/push.pem" 2>/dev/null | cut -d= -f2)
    if [[ -n "$END" ]]; then
      END_EPOCH=$(date -j -f "%b %e %T %Y %Z" "$END" +%s 2>/dev/null || echo 0)
      DAYS=$(( (END_EPOCH - $(date +%s)) / 86400 ))
      if (( DAYS < 0 )); then bad "APNs push cert EXPIRED ($END) — renew at identity.apple.com (same Apple ID!)"
      elif (( DAYS < 30 )); then warn "APNs push cert expires in ${DAYS}d ($END) — renew soon at identity.apple.com"
      else ok "APNs push cert valid ${DAYS}d ($END)"; fi
    fi
  else
    bad "APNs push cert missing ($MDM_DIR/push.pem)"
  fi

  if tailscale status >/dev/null 2>&1; then
    ok "tailscale up"
    tailscale funnel status 2>/dev/null | grep -q 9930 && ok "funnel active on 9930" || warn "funnel down (mdm-up.sh starts it on demand)"
  else
    warn "tailscale stopped (mdm-up.sh will need it: tailscale up)"
  fi

  DEV=$(python3 -c 'import json,os;print(len(json.load(open(os.path.expanduser("~/.device-it/config.json"))).get("devices",[])))' 2>/dev/null || echo 0)
  (( DEV > 0 )) && ok "$DEV enrolled device(s)" || warn "no devices enrolled yet"
fi

echo "[registry]"
APPS=$(node "$(dirname "$0")/registry.mjs" list 2>/dev/null | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))' 2>/dev/null || echo 0)
ok "$APPS app(s) tracked"

echo
echo "ok=$OK warn=$WARN fail=$FAIL"
exit $(( FAIL > 0 ? 1 : 0 ))
