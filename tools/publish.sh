#!/usr/bin/env bash
# Build the published site tree under public/ from root source files.
#
# Source (repo root): HTML, CNAME, _config.yml, .well-known/* (unsigned)
# Output (public/):   copied static files + signed static-assets.json
#
# Usage:
#   export STATIC_ASSETS_PRIVATE_KEY="..."   # required on main publish
#   export STATIC_ASSETS_KEY_ID=assets-k1    # optional
#   ./tools/publish.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/public"
MANIFEST="$ROOT/.well-known/static-assets.manifest.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "Missing source manifest: $MANIFEST" >&2
  exit 1
fi

python3 "$ROOT/tools/validate_static_assets_manifest.py" "$MANIFEST"

rm -rf "$OUT"
mkdir -p "$OUT/.well-known"

cp "$ROOT/CNAME" "$OUT/CNAME"
cp "$ROOT/_config.yml" "$OUT/_config.yml"

shopt -s nullglob
for html in "$ROOT"/*.html; do
  cp "$html" "$OUT/"
done

cp "$ROOT/.well-known/apple-app-site-association" "$OUT/.well-known/"
cp "$ROOT/.well-known/assetlinks.json" "$OUT/.well-known/"

chmod +x "$ROOT/tools/sign_static_assets.sh"
"$ROOT/tools/sign_static_assets.sh" \
  "$MANIFEST" \
  "$OUT/.well-known/static-assets.json"

echo "Published site to $OUT"
