#!/usr/bin/env bash
# Publish the v1.0.0 GitHub release without `gh`.
# Uses git for the tag check and the GitHub REST API via curl for the release.
set -euo pipefail

REPO="Ali-Ashraf-Saad/domino-shak"
TAG="v1.0.0"
TITLE="Domino Shak v1.0.0"
APK="domino_shak_app/build/app/outputs/flutter-apk/app-release.apk"
SUMS="domino_shak_web/SHA256SUMS.txt"

if [[ -n "${GH_TOKEN_FILE:-}" ]]; then
  TOKEN="$(cat "$GH_TOKEN_FILE")"
else
  TOKEN="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
fi

if [[ -z "$TOKEN" ]]; then
  echo "Set GITHUB_TOKEN (or GH_TOKEN), or point GH_TOKEN_FILE at a file containing it." >&2
  exit 1
fi

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "Missing local tag $TAG" >&2; exit 1; }
[[ -f "$APK" ]] || { echo "Missing $APK" >&2; exit 1; }
[[ -f "$SUMS" ]] || { echo "Missing $SUMS" >&2; exit 1; }

read -r -d '' NOTES <<'EOF' || true
## Domino Shak v1.0.0

First tagged release of the modernized Domino Shak experience.

### Highlights
- Modernized UI/UX for Android WebView and the public website, keeping the brown/gold dark identity.
- Arabic RTL and English LTR with a persisted language preference (Settings only).
- Local Network (LAN) play available in the Android app; hidden on the public website.
- Bots, online multiplayer, and core gameplay/networking preserved.
- Direct bot setup from the mode picker; no redundant extra step.
- Responsive layouts, comfortable inputs, and a centered lobby Share button.

### Verification
- APK SHA-256: `02be461c0e77c804b1802b2903ee21980326ee9e9efb99efd6a5798d17fdb16f`
- Web `index.html` SHA-256: `b100ed868fe9912790c2e038c53a64fdea31c9bcc6ef8c16f04611baee5acedd`

### Notes
Online play across different networks still requires a working TURN server or a network path that allows direct device-to-device UDP.
EOF

EXISTING="$(curl -fsS \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO/releases/tags/$TAG" 2>/dev/null || true)"

if [[ -n "$EXISTING" ]]; then
  RESPONSE="$EXISTING"
  echo "Using existing release for $TAG"
else
  PAYLOAD="$(python3 - "$TAG" "$TITLE" "$NOTES" <<'PY'
import json, sys
print(json.dumps({
    "tag_name": sys.argv[1],
    "name": sys.argv[2],
    "body": sys.argv[3],
    "draft": False,
    "prerelease": False,
    "generate_release_notes": False,
}))
PY
)"
  RESPONSE="$(curl -fsS -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$REPO/releases" \
    --data-binary "$PAYLOAD")"
fi

UPLOAD_URL="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["upload_url"])' <<<"$RESPONSE")"
HTML_URL="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["html_url"])' <<<"$RESPONSE")"
EXISTING_ASSETS="$(python3 -c 'import json,sys; print("\n".join(a["name"] for a in json.load(sys.stdin)["assets"]))' <<<"$RESPONSE")"

for asset in "$SUMS" "$APK"; do
  name="$(basename "$asset")"
  if grep -Fxq "$name" <<<"$EXISTING_ASSETS"; then
    echo "Already attached: $name"
    continue
  fi
  ctype="application/octet-stream"
  [[ "$name" == *.txt ]] && ctype="text/plain"
  url="${UPLOAD_URL%%\{*}?name=$name"
  curl -fsS -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: $ctype" \
    --data-binary "@$asset" \
    "$url" >/dev/null
  echo "Uploaded $name"
done

echo "Release published: $HTML_URL"
