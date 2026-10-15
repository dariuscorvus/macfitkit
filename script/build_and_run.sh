#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify) ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DockPreview"
BUNDLE_ID="tech.highbyte.macfitkit.DockPreview"
BUILD_DIR="${MACFITKIT_BUILD_DIR:-$HOME/Library/Caches/MacFitKit/DerivedData}"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
# Stable development signatures preserve macOS privacy grants across rebuilds.
# Keep ad-hoc fallback for Macs without an installed development certificate.
SIGNING_IDENTITY="${MACFITKIT_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
xcodebuild -workspace "$ROOT_DIR/MacFitKit.xcworkspace" -scheme "$APP_NAME" \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" build
case "$MODE" in
  run) /usr/bin/open -n "$APP_BUNDLE" ;;
  --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
  --logs)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    /usr/bin/open -n "$APP_BUNDLE"
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    /usr/bin/open -n "$APP_BUNDLE"
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME launched (process verified)."
    ;;
esac
