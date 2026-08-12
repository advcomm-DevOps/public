#!/usr/bin/env bash
# Sign static-assets.manifest.json with Ed25519 (OpenSSL 3.x).
#
# Usage:
#   export STATIC_ASSETS_PRIVATE_KEY="$(cat assets-k1-private.pem)"
#   export STATIC_ASSETS_KEY_ID=assets-k1
#   ./tools/sign_static_assets.sh \
#     .well-known/static-assets.manifest.json \
#     docs/.well-known/static-assets.json
#
# Prefer ./tools/publish.sh to rebuild the full docs/ tree.
#
# Signed payload (UTF-8 bytes, no trailing newline):
#   scomm-static-assets-v1\0<signatureKeyId>\0<manifestSha256>
#
# manifestSha256 is lowercase hex SHA-256 of the canonical unsigned manifest JSON
# (sorted keys, assets sorted by path, no signature fields).
set -euo pipefail

MANIFEST_IN="${1:?unsigned manifest path}"
MANIFEST_OUT="${2:?signed manifest output path}"
KEY_ID="${STATIC_ASSETS_KEY_ID:-assets-k1}"

if [[ -z "${STATIC_ASSETS_PRIVATE_KEY:-}" ]]; then
  echo "Missing STATIC_ASSETS_PRIVATE_KEY env var" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "OpenSSL 3.x is required" >&2
  exit 1
fi

KEY_FILE="$(mktemp)"
SIGN_INPUT="$(mktemp)"
cleanup() { rm -f "$KEY_FILE" "$SIGN_INPUT"; }
trap cleanup EXIT

printf '%s\n' "$STATIC_ASSETS_PRIVATE_KEY" | sed 's/\\n/\n/g' > "$KEY_FILE"

manifest_sha="$(python3 - "$MANIFEST_IN" "$SIGN_INPUT" "$KEY_ID" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

manifest_path = Path(sys.argv[1])
sign_input_path = Path(sys.argv[2])
key_id = sys.argv[3]

data = json.loads(manifest_path.read_text(encoding="utf-8"))
for field in ("signatureKeyId", "signatureAlgorithm", "signature"):
    data.pop(field, None)

assets = data.get("assets")
if not isinstance(assets, list):
    raise SystemExit("assets must be an array")
data["assets"] = sorted(assets, key=lambda item: item["path"])

canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
manifest_sha = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
payload = f"scomm-static-assets-v1\x00{key_id}\x00{manifest_sha}".encode("utf-8")
sign_input_path.write_bytes(payload)
print(manifest_sha)
PY
)"

signature_b64="$(
  openssl pkeyutl -sign -inkey "$KEY_FILE" -rawin -in "$SIGN_INPUT" | openssl base64 -A
)"

python3 - "$MANIFEST_IN" "$MANIFEST_OUT" "$KEY_ID" "$signature_b64" <<'PY'
import json
import sys
from pathlib import Path

manifest_in = Path(sys.argv[1])
manifest_out = Path(sys.argv[2])
key_id = sys.argv[3]
signature_b64 = sys.argv[4]

data = json.loads(manifest_in.read_text(encoding="utf-8"))
for field in ("signatureKeyId", "signatureAlgorithm", "signature"):
    data.pop(field, None)

data["signatureKeyId"] = key_id
data["signatureAlgorithm"] = "Ed25519"
data["signature"] = signature_b64

manifest_out.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

echo "Signed $MANIFEST_OUT with key $KEY_ID (manifestSha256=$manifest_sha)"
