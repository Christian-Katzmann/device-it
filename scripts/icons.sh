#!/usr/bin/env bash
# device-it icon generator: SRC_IMAGE OUT_DIR [BG_COLOR]
# Produces: icon-1024.png, apple-touch-icon-180.png, icon-192.png, icon-512.png, icon-512-maskable.png
set -euo pipefail

SRC="$1"
OUT="$2"
BG="${3:-}"

[[ -f "$SRC" ]] || { echo "icons.sh: source image not found: $SRC" >&2; exit 1; }
mkdir -p "$OUT"

if command -v magick >/dev/null 2>&1; then
  # Auto background: sample the top-left pixel unless caller supplied one
  if [[ -z "$BG" ]]; then
    BG=$(magick "$SRC" -format "%[pixel:p{0,0}]" info: 2>/dev/null || echo "white")
  fi
  square() { # size out — fit inside square, pad with bg
    magick "$SRC" -resize "${1}x${1}" -background "$BG" -gravity center -extent "${1}x${1}" "$OUT/$2"
  }
  square 1024 icon-1024.png
  square 180  apple-touch-icon-180.png
  square 192  icon-192.png
  square 512  icon-512.png
  # Maskable: content in the central 80% safe zone
  magick "$SRC" -resize 410x410 -background "$BG" -gravity center -extent 512x512 "$OUT/icon-512-maskable.png"
elif command -v sips >/dev/null 2>&1; then
  # sips fallback (no auto-bg sampling; uses white)
  BG="${BG:-FFFFFF}"
  for pair in "1024 icon-1024.png" "180 apple-touch-icon-180.png" "192 icon-192.png" "512 icon-512.png"; do
    set -- $pair
    cp "$SRC" "$OUT/$2"
    sips --resampleHeightWidthMax "$1" "$OUT/$2" >/dev/null
    sips -p "$1" "$1" --padColor "${BG#\#}" "$OUT/$2" >/dev/null
  done
  cp "$SRC" "$OUT/icon-512-maskable.png"
  sips --resampleHeightWidthMax 410 "$OUT/icon-512-maskable.png" >/dev/null
  sips -p 512 512 --padColor "${BG#\#}" "$OUT/icon-512-maskable.png" >/dev/null
else
  echo "icons.sh: need ImageMagick ('magick' on PATH) on non-macOS systems" >&2
  exit 1
fi

echo "BG_COLOR=$BG"
ls "$OUT"
