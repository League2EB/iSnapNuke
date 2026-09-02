#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/iSnapNuke.app}"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon/iSnapNuke.jpg"
ICONSET_PATH="${ICONSET_PATH:-$ROOT_DIR/.build/iSnapNuke.iconset}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
UPDATE_POLICY_PUBLIC_KEY="${UPDATE_POLICY_PUBLIC_KEY:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
REQUIRE_UPDATE_KEYS="${REQUIRE_UPDATE_KEYS:-0}"

if [[ -n "$UPDATE_POLICY_PUBLIC_KEY" || -n "$SPARKLE_PUBLIC_KEY" ]]; then
  if [[ -z "$UPDATE_POLICY_PUBLIC_KEY" || -z "$SPARKLE_PUBLIC_KEY" ]]; then
    print -u2 "Both UPDATE_POLICY_PUBLIC_KEY and SPARKLE_PUBLIC_KEY must be set together."
    exit 1
  fi
elif [[ "$REQUIRE_UPDATE_KEYS" == "1" ]]; then
  print -u2 "Release builds require UPDATE_POLICY_PUBLIC_KEY and SPARKLE_PUBLIC_KEY."
  exit 1
fi

cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
BIN_PATH="$BIN_DIR/iSnapNuke"
LOCALIZATION_BUNDLE="$BIN_DIR/iSnapNuke_iSnapNukeLocalization.bundle"
SPARKLE_FRAMEWORK="$BIN_DIR/Sparkle.framework"

rm -rf "$APP_PATH" "$ICONSET_PATH"
mkdir -p \
  "$APP_PATH/Contents/MacOS" \
  "$APP_PATH/Contents/Resources" \
  "$APP_PATH/Contents/Frameworks" \
  "$ICONSET_PATH"
cp "$BIN_PATH" "$APP_PATH/Contents/MacOS/iSnapNuke"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_PATH/Contents/Info.plist"
ditto "$LOCALIZATION_BUNDLE" "$APP_PATH/Contents/Resources/iSnapNuke_iSnapNukeLocalization.bundle"
ditto "$SPARKLE_FRAMEWORK" "$APP_PATH/Contents/Frameworks/Sparkle.framework"

if [[ -n "$UPDATE_POLICY_PUBLIC_KEY" ]]; then
  /usr/libexec/PlistBuddy -c \
    "Set :iSnapNukeUpdatePolicyPublicKey $UPDATE_POLICY_PUBLIC_KEY" \
    "$APP_PATH/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c \
    "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" \
    "$APP_PATH/Contents/Info.plist"
else
  print -u2 "Warning: update installation is disabled because public keys were not supplied."
fi

# SwiftPM provides @loader_path but a macOS app stores frameworks in Contents/Frameworks.
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_PATH/Contents/MacOS/iSnapNuke"

for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_PATH/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -s format png -z "$retina_size" "$retina_size" "$ICON_SOURCE" --out "$ICONSET_PATH/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET_PATH" -o "$APP_PATH/Contents/Resources/iSnapNuke.icns"

typeset -a CODESIGN_ARGS
CODESIGN_ARGS=(--force --sign "$SIGNING_IDENTITY")
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  CODESIGN_ARGS+=(--options runtime --timestamp)
fi

# Sign Sparkle's nested code first, then its framework, then the app bundle.
while IFS= read -r bundle; do
  codesign "${CODESIGN_ARGS[@]}" "$bundle"
done < <(
  find "$APP_PATH/Contents/Frameworks/Sparkle.framework" \
    -depth -type d \( -name "*.xpc" -o -name "*.app" \)
)
codesign "${CODESIGN_ARGS[@]}" \
  "$APP_PATH/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate"
codesign "${CODESIGN_ARGS[@]}" "$APP_PATH/Contents/Frameworks/Sparkle.framework"
codesign "${CODESIGN_ARGS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

print "Built $APP_PATH"
