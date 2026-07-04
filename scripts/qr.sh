#!/usr/bin/env bash
# Render a QR for a URL: PNG to file + UTF8 to terminal.
# Usage: qr.sh <url> <out.png>
set -euo pipefail
URL="$1"
OUT="$2"
mkdir -p "$(dirname "$OUT")"
npx --yes qrcode@1.5.4 -o "$OUT" -w 512 "$URL" >/dev/null
npx --yes qrcode@1.5.4 --small "$URL"
echo "QR_PNG=$OUT"
