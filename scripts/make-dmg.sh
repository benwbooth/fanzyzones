#!/bin/bash
# Build FanzyZones.app (via the Makefile) and package it into a drag-to-install DMG.
# Usage: ./scripts/make-dmg.sh [output.dmg]
set -eo pipefail

OUT="${1:-dist/FanzyZones.dmg}"
APP="FanzyZones.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

if [ ! -d "$APP" ]; then
    echo "Building $APP ..."
    if [ -n "${VERSION:-}" ]; then
        make app VERSION="$VERSION"
    else
        make app
    fi
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# Stage the app next to an /Applications symlink for drag-install.
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
    -volname "FanzyZones" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$OUT"

echo "Created $OUT"
shasum -a 256 "$OUT"
