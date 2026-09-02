#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
APP_PATH="${1:-$ROOT_DIR/dist/iSnapNuke.app}"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXECUTABLE="$APP_PATH/Contents/MacOS/iSnapNuke"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_AUTOUPDATE="$SPARKLE_FRAMEWORK/Versions/B/Autoupdate"

for itemPath in "$APP_PATH" "$INFO_PLIST" "$EXECUTABLE" "$SPARKLE_FRAMEWORK" "$SPARKLE_AUTOUPDATE"; do
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

test -d "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Downloader.xpc"
test -d "$SPARKLE_FRAMEWORK/Versions/B/XPCServices/Installer.xpc"
otool -l "$EXECUTABLE" | grep -A2 -q '@executable_path/../Frameworks'
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

APP_SIGNING_DETAILS="$(codesign -dvv "$APP_PATH" 2>&1)"
if grep -q '^Authority=Developer ID Application:' <<<"$APP_SIGNING_DETAILS"; then
  grep -q '^Timestamp=' <<<"$APP_SIGNING_DETAILS"

  AUTOUPDATE_SIGNING_DETAILS="$(codesign -dvv "$SPARKLE_AUTOUPDATE" 2>&1)"
  grep -q '^Authority=Developer ID Application:' <<<"$AUTOUPDATE_SIGNING_DETAILS"
  grep -q '^Timestamp=' <<<"$AUTOUPDATE_SIGNING_DETAILS"
fi

print "Verified iSnapNuke $VERSION ($BUILD): $APP_PATH"
