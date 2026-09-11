#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUNDLE="${BUNDLE:-$ROOT/build/linux/x64/release/bundle}"
APPDIR="${APPDIR:-$ROOT/build/appimage/Komet.AppDir}"
DIST="${DIST:-$ROOT/dist}"
TOOLS="${TOOLS:-$ROOT/build/appimage/tools}"
LINUXDEPLOY="$TOOLS/linuxdeploy-x86_64.AppImage"
OUTPUT="$DIST/Komet-linux-x86_64.AppImage"
ICON="$TOOLS/ru.komet.app.png"

test -x "$BUNDLE/Komet"
cmake -E remove_directory "$APPDIR"
mkdir -p "$APPDIR/usr/lib/komet" "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/512x512/apps"
mkdir -p "$APPDIR/usr/share/metainfo" "$DIST" "$TOOLS"

cp -a "$BUNDLE/." "$APPDIR/usr/lib/komet/"
install -m 0755 "$ROOT/packaging/linux/komet" "$APPDIR/usr/bin/komet"
install -m 0644 "$ROOT/packaging/linux/ru.komet.app.desktop" \
  "$APPDIR/usr/share/applications/ru.komet.app.desktop"
install -m 0644 "$ROOT/packaging/linux/ru.komet.app.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/ru.komet.app.appdata.xml"
ffmpeg -hide_banner -loglevel error -y \
  -i "$ROOT/assets/komet_icon.png" -vf scale=512:512 "$ICON"
install -m 0644 "$ICON" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps/ru.komet.app.png"

if [[ ! -x "$LINUXDEPLOY" ]]; then
  curl --fail --location --retry 3 \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/1-alpha-20251107-1/linuxdeploy-x86_64.AppImage \
    --output "$LINUXDEPLOY"
  chmod 0755 "$LINUXDEPLOY"
fi

export ARCH=x86_64
export APPIMAGE_EXTRACT_AND_RUN=1
export LDAI_OUTPUT="$OUTPUT"
export LDAI_UPDATE_INFORMATION="gh-releases-zsync|fighxy|KometPro|latest|Komet-linux-x86_64.AppImage.zsync"
export LINUXDEPLOY_OUTPUT_VERSION="${VERSION:-0.0.0}"

set +e
"$LINUXDEPLOY" \
  --appdir "$APPDIR" \
  --executable "$APPDIR/usr/lib/komet/Komet" \
  --desktop-file "$ROOT/packaging/linux/ru.komet.app.desktop" \
  --icon-file "$ICON" \
  --output appimage
linuxdeploy_status=$?
set -e

if [[ ! -s "$OUTPUT.zsync" ]]; then
  zsync_candidate="$(find "$ROOT" -maxdepth 2 -type f \
    -name "$(basename "$OUTPUT").zsync" -print -quit)"
  if [[ -n "$zsync_candidate" && "$zsync_candidate" != "$OUTPUT.zsync" ]]; then
    mv "$zsync_candidate" "$OUTPUT.zsync"
  fi
fi

if [[ ! -s "$OUTPUT" || ! -s "$OUTPUT.zsync" ]]; then
  if (( linuxdeploy_status != 0 )); then
    exit "$linuxdeploy_status"
  fi
  exit 1
fi

if (( linuxdeploy_status != 0 )); then
  echo "linuxdeploy returned $linuxdeploy_status after producing valid AppImage artifacts"
fi
