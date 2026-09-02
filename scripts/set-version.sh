#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
PLIST="$ROOT_DIR/Packaging/Info.plist"

if (( $# != 2 )); then
  print -u2 "Usage: $0 <marketing-version> <build>"
  print -u2 "Example: $0 1.1.0 2"
  exit 1
fi

MARKETING_VERSION="$1"
BUILD="$2"

if [[ ! "$MARKETING_VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || \
   [[ "$MARKETING_VERSION" =~ '(^|\.)(0[0-9]+)(\.|$)' ]]; then
  print -u2 "Marketing version must use three non-zero-padded integers, such as 1.1.0."
  exit 1
fi

if [[ ! "$BUILD" =~ '^[1-9][0-9]*$' ]]; then
  print -u2 "Build must be a positive integer."
  exit 1
fi

CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
if (( BUILD <= CURRENT_BUILD )); then
  print -u2 "Build must be greater than the current build ($CURRENT_BUILD)."
  exit 1
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

print "Set iSnapNuke version to $MARKETING_VERSION ($BUILD)."
print "The matching release tag must be v$MARKETING_VERSION."
