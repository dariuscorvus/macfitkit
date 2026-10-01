#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--verify|--debug|--logs|--telemetry) ;;
  *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="FocusFrame"
BUNDLE_ID="de.highbytetech.FocusFrame"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"

if [[ "$MODE" != "--build-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
fi
swift build --product "$APP_NAME"
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
# Stable bundle identifier and designated requirement for local TCC permissions.
# For distribution, replace ad-hoc signing with a Developer ID signature.
xattr -cr "$APP_BUNDLE"
codesign --force --sign - --identifier "$BUNDLE_ID" \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP_BUNDLE"

if [[ "$MODE" == "--build-only" ]]; then
  echo "Built: $APP_BUNDLE"
  exit 0
fi
if [[ "$MODE" == "--debug" ]]; then
  exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
/usr/bin/open -n "$APP_BUNDLE"
case "$MODE" in
  --verify)
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "FocusFrame is running."
    ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "FocusFrame"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "de.highbytetech.FocusFrame"' ;;
esac
