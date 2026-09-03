#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
CONFIGURATION="${CONFIGURATION:-release}"
APP_PATH="${APP_PATH:-$ROOT_DIR/dist/iSnapNuke.app}"
ICON_SOURCE="$ROOT_DIR/Assets/AppIcon/iSnapNuke.jpg"
ICONSET_PATH="${ICONSET_PATH:-$ROOT_DIR/.build/iSnapNuke.iconset}"
BUILD_ROOT="${BUILD_ROOT:-$ROOT_DIR/.build/universal}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
UPDATE_POLICY_PUBLIC_KEY="${UPDATE_POLICY_PUBLIC_KEY:-}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
REQUIRE_UPDATE_KEYS="${REQUIRE_UPDATE_KEYS:-0}"
MINIMUM_SYSTEM_VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' \
    "$ROOT_DIR/Packaging/Info.plist"
)"

typeset -a TARGET_ARCHS
TARGET_ARCHS=(arm64 x86_64)

if [[ ! "$MINIMUM_SYSTEM_VERSION" =~ '^[0-9]+(\.[0-9]+){1,2}$' ]]; then
  print -u2 "Invalid LSMinimumSystemVersion: $MINIMUM_SYSTEM_VERSION"
  exit 1
fi

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

typeset -A BIN_DIRS
typeset -A BIN_PATHS
for architecture in "${TARGET_ARCHS[@]}"; do
  target_triple="${architecture}-apple-macosx${MINIMUM_SYSTEM_VERSION}"
  scratch_path="$BUILD_ROOT/$CONFIGURATION-$architecture"

  swift build \
    --configuration "$CONFIGURATION" \
    --product iSnapNuke \
    --triple "$target_triple" \
    --scratch-path "$scratch_path"
  bin_dir="$(
    swift build \
      --configuration "$CONFIGURATION" \
      --product iSnapNuke \
      --triple "$target_triple" \
      --scratch-path "$scratch_path" \
      --show-bin-path
  )"
  bin_path="$bin_dir/iSnapNuke"

  if [[ ! -f "$bin_path" ]]; then
    print -u2 "App executable not found for $architecture: $bin_path"
    exit 1
  fi

  found_archs="$(lipo -archs "$bin_path")"
  if [[ "$found_archs" != "$architecture" ]]; then
    print -u2 "Expected a thin $architecture app executable, found: $found_archs"
    exit 1
  fi

  BIN_DIRS[$architecture]="$bin_dir"
  BIN_PATHS[$architecture]="$bin_path"
done

RESOURCE_BIN_DIR="${BIN_DIRS[arm64]}"
LOCALIZATION_BUNDLE="$RESOURCE_BIN_DIR/iSnapNuke_iSnapNukeLocalization.bundle"
SPARKLE_FRAMEWORK="$RESOURCE_BIN_DIR/Sparkle.framework"

rm -rf "$APP_PATH" "$ICONSET_PATH"
mkdir -p \
  "$APP_PATH/Contents/MacOS" \
  "$APP_PATH/Contents/Resources" \
  "$APP_PATH/Contents/Frameworks" \
  "$ICONSET_PATH"
lipo -create \
  "${BIN_PATHS[arm64]}" \
  "${BIN_PATHS[x86_64]}" \
  -output "$APP_PATH/Contents/MacOS/iSnapNuke"
lipo "$APP_PATH/Contents/MacOS/iSnapNuke" -verify_arch "${TARGET_ARCHS[@]}"
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
"$ROOT_DIR/scripts/verify-app-bundle.sh" "$APP_PATH"

print "Built Universal 2 app: $APP_PATH"
