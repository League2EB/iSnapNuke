#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
PLIST="$ROOT_DIR/Packaging/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST")"
EXPECTED_TAG="v$VERSION"
TAG="${1:-$EXPECTED_TAG}"

if [[ "$TAG" != "$EXPECTED_TAG" ]]; then
  print -u2 "Tag must be $EXPECTED_TAG for version $VERSION, not $TAG."
  exit 1
fi

if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || \
   [[ "$VERSION" =~ '(^|\.)(0[0-9]+)(\.|$)' ]]; then
  print -u2 "Invalid marketing version: $VERSION"
  exit 1
fi

if [[ ! "$BUILD" =~ '^[1-9][0-9]*$' ]]; then
  print -u2 "Invalid build: $BUILD"
  exit 1
fi

if ! git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  print -u2 "Missing tag: $TAG"
  exit 1
fi

TAG_COMMIT="$(git -C "$ROOT_DIR" rev-list -n 1 "$TAG")"
HEAD_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
if [[ "$TAG_COMMIT" != "$HEAD_COMMIT" ]]; then
  print -u2 "Tag $TAG must point at HEAD before publishing."
  exit 1
fi

print "Validated release $VERSION ($BUILD) with tag $TAG at HEAD."
