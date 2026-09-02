#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h:h}"
SCENARIO="${1:-optional}"
DEMO_APP_PATH="$ROOT_DIR/dist/iSnapNukeUpdateDemo.app"

case "$SCENARIO" in
  optional|required|upToDate|offline) ;;
  *)
    print -u2 "Usage: $0 [optional|required|upToDate|offline]"
    exit 1
    ;;
esac

APP_PATH="$DEMO_APP_PATH" \
ICONSET_PATH="$ROOT_DIR/.build/iSnapNuke.update-demo.iconset" \
CONFIGURATION=debug \
"$ROOT_DIR/scripts/build-app.sh"

open -n "$DEMO_APP_PATH" --args --demo --demo-update "$SCENARIO"
