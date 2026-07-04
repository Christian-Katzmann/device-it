#!/usr/bin/env bash
# device-it inspector: run from the target project root. Prints KEY=VALUE lines.
set -euo pipefail

DIR="${1:-$PWD}"
cd "$DIR"

echo "PROJECT_DIR=$PWD"

NAME=""
FRAMEWORK="static"
BUILD_CMD=""
OUT_DIR=""
PKG_MANAGER="npm"

if [[ -f package.json ]]; then
  NAME=$(node -e 'const p=require("./package.json");process.stdout.write(p.name||"")' 2>/dev/null || true)
  [[ -f pnpm-lock.yaml ]] && PKG_MANAGER="pnpm"
  [[ -f yarn.lock ]] && PKG_MANAGER="yarn"
  [[ -f bun.lockb || -f bun.lock ]] && PKG_MANAGER="bun"

  DEPS=$(node -e 'const p=require("./package.json");process.stdout.write(Object.keys({...p.dependencies,...p.devDependencies}).join(","))' 2>/dev/null || true)
  SCRIPTS=$(node -e 'const p=require("./package.json");process.stdout.write(Object.keys(p.scripts||{}).join(","))' 2>/dev/null || true)

  if [[ ",$DEPS," == *",vite,"* ]]; then FRAMEWORK="vite"; OUT_DIR="dist"
  elif [[ ",$DEPS," == *",next,"* ]]; then FRAMEWORK="next"; OUT_DIR="out"
  elif [[ ",$DEPS," == *",react-scripts,"* ]]; then FRAMEWORK="cra"; OUT_DIR="build"
  elif [[ ",$DEPS," == *",astro,"* ]]; then FRAMEWORK="astro"; OUT_DIR="dist"
  else FRAMEWORK="node-other"; OUT_DIR="dist"
  fi

  if [[ ",$SCRIPTS," == *",build,"* ]]; then
    case "$PKG_MANAGER" in
      npm) BUILD_CMD="npm run build";;
      *) BUILD_CMD="$PKG_MANAGER run build";;
    esac
  fi
  echo "SCRIPTS=$SCRIPTS"
fi

[[ -z "$NAME" ]] && NAME=$(basename "$PWD")
echo "NAME=$NAME"
echo "FRAMEWORK=$FRAMEWORK"
echo "PKG_MANAGER=$PKG_MANAGER"
echo "BUILD_CMD=$BUILD_CMD"

# vite: honor custom outDir if trivially greppable
if [[ "$FRAMEWORK" == "vite" ]]; then
  for f in vite.config.ts vite.config.js vite.config.mjs; do
    if [[ -f "$f" ]]; then
      CUSTOM=$(grep -Eo 'outDir[[:space:]]*:[[:space:]]*["'"'"'][^"'"'"']+' "$f" | head -1 | sed -E 's/.*["'"'"']//' || true)
      [[ -n "${CUSTOM:-}" ]] && OUT_DIR="$CUSTOM"
      BASE=$(grep -Eo 'base[[:space:]]*:[[:space:]]*["'"'"'][^"'"'"']*' "$f" | head -1 | sed -E 's/.*["'"'"']//' || true)
      echo "VITE_BASE=${BASE:-/}"
    fi
  done
fi
echo "OUT_DIR=$OUT_DIR"

# Plain static site?
if [[ ! -f package.json && -f index.html ]]; then
  echo "STATIC_ROOT=$PWD"
fi

# Existing PWA bits
FOUND_MANIFEST=""
for m in public/manifest.webmanifest public/manifest.json manifest.webmanifest manifest.json; do
  [[ -f "$m" ]] && FOUND_MANIFEST="$m" && break
done
echo "EXISTING_MANIFEST=${FOUND_MANIFEST}"
SW=$(ls public/sw.js public/service-worker.js sw.js 2>/dev/null | head -1 || true)
echo "EXISTING_SW=${SW}"

# Icon candidates (largest first is the caller's job; we just list)
ICONS=$(ls public/icon*.png public/logo*.png public/apple-touch-icon*.png icon*.png logo*.png src/assets/icon*.png src/assets/logo*.png assets/icon*.png assets/logo*.png 2>/dev/null | tr '\n' ',' || true)
echo "ICON_CANDIDATES=${ICONS%,}"

# Backend-dependency smell: relative API calls won't work offline / off-box
API_HITS=$(grep -RIl --include='*.{js,ts,jsx,tsx}' -E 'fetch\((["'"'"'])/api|axios[^\n]*(["'"'"'])/api' src app lib 2>/dev/null | head -5 | tr '\n' ',' || true)
echo "BACKEND_HINTS=${API_HITS%,}"
