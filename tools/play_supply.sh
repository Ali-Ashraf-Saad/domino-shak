#!/usr/bin/env bash
# Run Fastlane Supply inside Docker against a Google Play service-account key.
# The key stays outside the repository and is mounted read-only into the container.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${PLAY_SUPPLY_IMAGE:-domino-supply:latest}"
LANE="${1:-validate_auth}"
KEY="${GOOGLE_JSON_KEY:-/home/ali/.config/domino_shak/play-service-account.json}"

if [[ ! -f "$KEY" ]]; then
  echo "Missing Play service-account JSON key: $KEY" >&2
  echo "Save the key outside this repo and set GOOGLE_JSON_KEY=/path/to/key.json" >&2
  exit 1
fi

MODE="$(stat -c '%a' "$KEY")"
if [[ "$MODE" != "600" ]]; then
  echo "Warning: $KEY is mode $MODE; chmod 600 is recommended." >&2
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "Building $IMAGE ..." >&2
  docker build -t "$IMAGE" "$REPO_ROOT/tools/fastlane"
fi

exec docker run --rm -i \
  -v "$REPO_ROOT:/workspace" \
  -v "$KEY:/keys/play.json:ro" \
  -e GOOGLE_JSON_KEY=/keys/play.json \
  -e FASTLANE_SKIP_UPDATE_CHECK=1 \
  -e FASTLANE_DISABLE_ANONYMOUS_REPORTING=1 \
  -w /workspace \
  "$IMAGE" \
  fastlane "$LANE"
