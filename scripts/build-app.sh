#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_PATH="$ROOT_DIR/dist/iSnapNuke.app"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon/iSnapNuke.jpg"
ICONSET_PATH="$ROOT_DIR/.build/iSnapNuke.iconset"

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/iSnapNuke"
LOCALIZATION_BUNDLE="$BIN_DIR/iSnapNuke_iSnapNukeLocalization.bundle"

rm -rf "$APP_PATH" "$ICONSET_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$ICONSET_PATH"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/iSnapNuke"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
ditto "$LOCALIZATION_BUNDLE" "$APP_PATH/Contents/Resources/iSnapNuke_iSnapNukeLocalization.bundle"

for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_PATH/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -s format png -z "$retina_size" "$retina_size" "$ICON_SOURCE" --out "$ICONSET_PATH/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_PATH" -o "$APP_PATH/Contents/Resources/iSnapNuke.icns"

codesign --force --sign - "$APP_PATH"

print "Built $APP_PATH"
