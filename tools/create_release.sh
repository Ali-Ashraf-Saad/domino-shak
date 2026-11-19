#!/usr/bin/env bash
# Publish a versioned GitHub release without `gh`.
# Uses git for the tag check and the GitHub REST API via curl for the release.
set -euo pipefail

REPO="Ali-Ashraf-Saad/domino-shak"
TAG="${RELEASE_TAG:-v1.0.1}"
TITLE="Domino Shak $TAG"
APK="domino_shak_app/build/app/outputs/flutter-apk/app-release.apk"
SUMS="domino_shak_web/SHA256SUMS.txt"
INDEX="domino_shak_app/assets/web/index.html"

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
[[ -f "$INDEX" ]] || { echo "Missing $INDEX" >&2; exit 1; }

APK_SHA="$(sha256sum "$APK" | awk '{print $1}')"
INDEX_SHA="$(sha256sum "$INDEX" | awk '{print $1}')"

read -r -d '' NOTES <<EOF || true
## Domino Shak $TAG

Tagged release of the modernized Domino Shak experience.

### Highlights
- Modernized UI/UX for Android WebView and the public website, keeping the brown/gold dark identity.
- Arabic RTL and English LTR with a persisted language preference (Settings only).
- Local Network (LAN) play available in the Android app; hidden on the public website.
- Bots, online multiplayer, and core gameplay/networking preserved.
- Direct bot setup from the mode picker; no redundant extra step.
- Responsive layouts, comfortable inputs, and a centered lobby Share button.
- Plain-text mode labels and bot names (no globe, robot, or signal emoji).
- Wood-striped background painted on a fixed viewport layer, so it has no lower seam or solid band at any zoom level.
- After a challenge, the table clears and the challenge winner takes the next turn: a correct challenge passes the turn to the challenger, while a false challenge returns it to the challenged player.
- Voice capture uses one continuous recording at a higher bitrate so Android WebView messages no longer have clipped starts/ends or muffled speech.

### Verification
- APK SHA-256: \`$APK_SHA\`
- Web \`index.html\` SHA-256: \`$INDEX_SHA\`

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
ASSET_IDS="$(python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join("{} {}".format(a["name"], a["id"]) for a in d.get("assets", [])))' <<<"$RESPONSE")"

for asset in "$SUMS" "$APK"; do
  name="$(basename "$asset")"
  existing_id="$(awk -v n="$name" '$1==n{print $2}' <<<"$ASSET_IDS")"
  if [[ -n "$existing_id" ]]; then
    curl -fsS -X DELETE \
      -H "Authorization: Bearer $TOKEN" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/repos/$REPO/releases/assets/$existing_id" >/dev/null
    echo "Replaced $name"
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
