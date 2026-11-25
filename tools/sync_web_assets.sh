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
cp "$SRC/favicon.ico" "$DEST/favicon.ico"
cp "$SRC/favicon-32.png" "$DEST/favicon-32.png"
cp "$SRC/apple-touch-icon.png" "$DEST/apple-touch-icon.png"

cat > "$DEST/config.js" <<'EOF'
// Informational only. The game itself is self-contained in index.html.
window.DOMINO_SHAK_WEB_CONFIG = Object.freeze({
  publicOrigin: 'https://liardominoes.gt.tc',
  roomQueryParam: 'room',
  peerJsVersion: '1.5.4',
  appId: 'com.dominoshak.domino_shak'
});
EOF

normalize_fp() {
  local raw
  raw="$(printf '%s' "$1" | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
  # Accept input with or without colons; always emit colon-separated hex,
  # which is the format Android's App Links verifier expects.
  if [[ "$raw" != *:* ]]; then
    raw="$(printf '%s' "$raw" | sed 's/../&:/g; s/:$//')"
  fi
  printf '%s' "$raw"
}
valid_fp() {
  [[ "$1" =~ ^([0-9A-F]{2}:){31}[0-9A-F]{2}$ ]]
}

fingerprints=()
if [[ -n "${PLAY_APP_SIGNING_SHA256:-}" ]]; then
  fp="$(normalize_fp "$PLAY_APP_SIGNING_SHA256")"
  if ! valid_fp "$fp"; then
    echo "PLAY_APP_SIGNING_SHA256 is not a 32-byte hex fingerprint" >&2
    exit 1
  fi
  fingerprints+=("$fp")
fi
# Optional: the upload-key fingerprint, so sideloaded/local builds also verify.
if [[ -n "${UPLOAD_KEY_SHA256:-}" ]]; then
  fp="$(normalize_fp "$UPLOAD_KEY_SHA256")"
  if ! valid_fp "$fp"; then
    echo "UPLOAD_KEY_SHA256 is not a 32-byte hex fingerprint" >&2
    exit 1
  fi
  fingerprints+=("$fp")
fi

if [[ ${#fingerprints[@]} -gt 0 ]]; then
  {
    echo '['
    echo '  {'
    echo '    "relation": ["delegate_permission/common.handle_all_urls"],'
    echo '    "target": {'
    echo '      "namespace": "android_app",'
    echo '      "package_name": "com.dominoshak.domino_shak",'
    printf '      "sha256_cert_fingerprints": ['
    first=1
    for fp in "${fingerprints[@]}"; do
      if [[ $first -eq 1 ]]; then first=0; else printf ', '; fi
      printf '"%s"' "$fp"
    done
    printf ']\n'
    echo '    }'
    echo '  }'
    echo ']'
  } > "$DEST/.well-known/assetlinks.json"
else
  # Never generate a placeholder production association file: it could be
  # uploaded by mistake and would be rejected by Android anyway.
  rm -f "$DEST/.well-known/assetlinks.json"
  echo "WARNING: assetlinks.json not generated (no PLAY_APP_SIGNING_SHA256)." >&2
  echo "Only assetlinks.json.template is present. Do not upload a placeholder." >&2
fi

(
  cd "$DEST"
  find . -type f \
    ! -path './.well-known/*' \
    ! -name 'SHA256SUMS.txt' -print0 \
    | sort -z \
    | xargs -0 sha256sum > SHA256SUMS.txt
)

echo "Synced web deployment files to $DEST"
echo "Original source untouched: $ROOT/index.html"
