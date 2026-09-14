#!/usr/bin/env bash
set -euo pipefail

: "${VERSION:?VERSION is required}"
: "${BUILD:?BUILD is required}"
: "${TAG:?TAG is required}"
: "${REPO:?REPO is required}"

DIST_DIR="${DIST_DIR:-dist}"
COMMIT="${COMMIT:-}"

# Assets are pinned to this release's own tag (not /releases/latest/download/)
# so a sha256 recorded in the manifest can never point at a file a *later*
# release swaps in under the same "latest" alias between check and download.
ASSET_BASE="https://github.com/$REPO/releases/download/$TAG"
RELEASE_URL="https://github.com/$REPO/releases/tag/$TAG"

INDEX="$(mktemp)"
trap 'rm -f "$INDEX"' EXIT

for file in "$DIST_DIR"/*; do
  [ -f "$file" ] || continue
  name="$(basename "$file")"
  size="$(stat -c%s "$file")"
  digest="$(sha256sum "$file" | awk '{print $1}')"
  printf '%s\t%s\t%s\n' "$name" "$size" "$digest" >> "$INDEX"
done

INDEX_FILE="$INDEX" ASSET_BASE="$ASSET_BASE" VERSION="$VERSION" BUILD="$BUILD" \
TAG="$TAG" COMMIT="$COMMIT" RELEASE_URL="$RELEASE_URL" DIST_DIR="$DIST_DIR" \
python3 "$(dirname "$0")/generate_update_manifest.py"
