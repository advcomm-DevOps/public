#!/usr/bin/env bash
# Build the published site tree under docs/ from root source files.
#
# Source (repo root): HTML, CNAME, _config.yml, .well-known/*
# Output (docs/):     copied static files for GitHub Pages (/docs)
#
# Usage:
#   ./tools/publish.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/docs"

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

echo "Published site to $OUT"
