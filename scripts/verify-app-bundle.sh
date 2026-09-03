#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_PATH="${1:-$ROOT_DIR/dist/iSnapNuke.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/iSnapNuke"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_AUTOUPDATE="$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"
SPARKLE_UPDATER="$SPARKLE_FRAMEWORK/Versions/B/Updater.app/Contents/MacOS/Updater"
SPARKLE_DOWNLOADER="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
SPARKLE_INSTALLER="$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"

typeset -a REQUIRED_ARCHS
REQUIRED_ARCHS=(arm64 x86_64)

for itemPath in \
  "$APP_PATH" \
  "$INFO_PLIST" \
  "$EXECUTABLE" \
  "$SPARKLE_FRAMEWORK" \
  "$SPARKLE_AUTOUPDATE" \
  "$SPARKLE_UPDATER" \
  "$SPARKLE_DOWNLOADER" \
  "$SPARKLE_INSTALLER"
do
  if [[ ! -e "$itemPath" ]]; then
    print -u2 "Missing required bundle item: $itemPath"
    exit 1
  fi
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
POLICY_URL="$(/usr/libexec/PlistBuddy -c 'Print :iSnapNukeUpdatePolicyURL' "$INFO_PLIST")"

[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || {
  print -u2 "Invalid marketing version: $VERSION"
  exit 1
}
[[ "$BUILD" =~ '^[1-9][0-9]*$' ]] || {
  print -u2 "Invalid build: $BUILD"
  exit 1
}
[[ "$POLICY_URL" == https://* ]] || {
  print -u2 "Update policy URL must use HTTPS."
  exit 1
}

verify_universal_binary() {
  local binary_path="$1"
  local found_archs

  found_archs="$(lipo -archs "$binary_path" 2>&1)" || {
    print -u2 "Unable to inspect Mach-O architectures: $binary_path"
    return 1
  }
  if ! lipo "$binary_path" -verify_arch "${REQUIRED_ARCHS[@]}" >/dev/null 2>&1; then
    print -u2 "Expected arm64 and x86_64 architectures in $binary_path, found: $found_archs"
    return 1
  fi
}

MACHO_COUNT=0
while IFS= read -r -d '' binary_path; do
  if file -b "$binary_path" | grep -q 'Mach-O'; then
    verify_universal_binary "$binary_path"
    (( ++MACHO_COUNT ))
  fi
done < <(find "$APP_PATH" -type f -print0)

if (( MACHO_COUNT == 0 )); then
  print -u2 "No Mach-O files found in app bundle: $APP_PATH"
  exit 1
fi

for architecture in "${REQUIRED_ARCHS[@]}"; do
  otool -arch "$architecture" -l "$EXECUTABLE" | \
    grep -A2 -q '@executable_path/../Frameworks'
done
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_SIGNING_DETAILS="$(codesign -dvv "$APP_PATH" 2>&1)"
if grep -q '^Authority=Developer ID Application:' <<<"$APP_SIGNING_DETAILS"; then
  grep -q '^Timestamp=' <<<"$APP_SIGNING_DETAILS"

  AUTOUPDATE_SIGNING_DETAILS="$(codesign -dvv "$SPARKLE_AUTOUPDATE" 2>&1)"
  grep -q '^Authority=Developer ID Application:' <<<"$AUTOUPDATE_SIGNING_DETAILS"
  grep -q '^Timestamp=' <<<"$AUTOUPDATE_SIGNING_DETAILS"
fi

print "Verified Universal 2 iSnapNuke $VERSION ($BUILD): $APP_PATH"
