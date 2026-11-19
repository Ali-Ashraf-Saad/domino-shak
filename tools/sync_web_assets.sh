#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/domino_shak_app/assets/web"
DEST="$ROOT/domino_shak_web"

if [[ ! -f "$SRC/index.html" ]]; then
  echo "Canonical source not found: $SRC/index.html" >&2
  exit 1
fi

mkdir -p \
  "$DEST/assets/css" \
  "$DEST/assets/js" \
  "$DEST/assets/images" \
  "$DEST/fonts" \
  "$DEST/vendor" \
  "$DEST/.well-known" \
  "$DEST/deployment"

cp "$SRC/index.html" "$DEST/index.html"
# Keep the same relative paths as the bundled source (fonts/, vendor/).
cp "$SRC"/fonts/* "$DEST/fonts/"
cp "$SRC/vendor/peerjs.min.js" "$DEST/vendor/peerjs.min.js"
cp "$SRC/PRIVACY_POLICY.html" "$DEST/PRIVACY_POLICY.html"

cat > "$DEST/config.js" <<'EOF'
// Informational only. The game itself is self-contained in index.html.
window.DOMINO_SHAK_WEB_CONFIG = Object.freeze({
  publicOrigin: 'https://liardominoes.gt.tc',
  roomQueryParam: 'room',
  peerJsVersion: '1.5.4',
  appId: 'com.dominoshak.domino_shak'
});
EOF

if [[ -n "${PLAY_APP_SIGNING_SHA256:-}" ]]; then
  fingerprint="$(printf '%s' "$PLAY_APP_SIGNING_SHA256" \
    | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]' \
    | sed 's/:/ /g')"
  if [[ ! "$fingerprint" =~ ^([0-9A-F]{2}[[:space:]]){31}[0-9A-F]{2}$ ]]; then
    echo "PLAY_APP_SIGNING_SHA256 is not a 32-byte hex fingerprint" >&2
    exit 1
  fi
  cat > "$DEST/.well-known/assetlinks.json" <<EOF
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.dominoshak.domino_shak",
      "sha256_cert_fingerprints": ["$fingerprint"]
    }
  }
]
EOF
else
  # Never generate a placeholder production association file: it could be
  # uploaded by mistake and would be rejected by Android anyway.
  rm -f "$DEST/.well-known/assetlinks.json"
  echo "WARNING: assetlinks.json not generated (no PLAY_APP_SIGNING_SHA256)." >&2
  echo "Only assetlinks.json.template is present. Do not upload a placeholder." >&2
fi

(
  cd "$DEST"
  find . -type f ! -path './.well-known/assetlinks.json' -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "Synced web deployment files to $DEST"
echo "Original source untouched: $ROOT/index.html"
