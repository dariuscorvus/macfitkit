#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
case "$MODE" in
  run|--build-only|--verify|--debug|--logs|--telemetry|--settings|--diagnostics) ;;
  *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry|--settings|--diagnostics]" >&2; exit 2 ;;
esac
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="FocusFrame"
BUNDLE_ID="de.highbytetech.FocusFrame"
# Stage outside synced Documents: file providers can add FinderInfo again after
# launch, invalidating the bundle signature even after xattr cleanup.
APP_BUNDLE="$HOME/Library/Caches/FocusFrame/$APP_NAME.app"
PROJECT_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
INSTALLED_BUNDLE="$HOME/Applications/$APP_NAME.app"

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
  <key>CFBundleShortVersionString</key><string>0.3.2</string>
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
codesign --verify --strict "$APP_BUNDLE"
mkdir -p "$ROOT_DIR/dist"
if [[ -d "$PROJECT_BUNDLE" && ! -L "$PROJECT_BUNDLE" ]]; then
  rm -rf "$PROJECT_BUNDLE"
fi
ln -sfn "$APP_BUNDLE" "$PROJECT_BUNDLE"

if [[ "$MODE" == "--build-only" ]]; then
  echo "Built: $APP_BUNDLE"
  exit 0
fi
# Like iQualize, run the registered main app from a permanent Applications path.
# Keep build-only checks isolated in the staging bundle.
mkdir -p "$HOME/Applications"
if [[ -e "$INSTALLED_BUNDLE" ]]; then
  EXISTING_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INSTALLED_BUNDLE/Contents/Info.plist")
  [[ "$EXISTING_ID" == "$BUNDLE_ID" ]] || { echo "Another app occupies $INSTALLED_BUNDLE" >&2; exit 1; }
fi
/usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_BUNDLE"
codesign --verify --strict "$INSTALLED_BUNDLE"
APP_BUNDLE="$INSTALLED_BUNDLE"
ln -sfn "$APP_BUNDLE" "$PROJECT_BUNDLE"
if [[ "$MODE" == "--debug" ]]; then
  exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
fi
if [[ "$MODE" == "--settings" || "$MODE" == "--diagnostics" ]]; then
  /usr/bin/open -n "$APP_BUNDLE" --args "$MODE"
else
  /usr/bin/open -n "$APP_BUNDLE"
fi
case "$MODE" in
  --verify)
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    echo "FocusFrame is running."
    ;;
  --logs) exec /usr/bin/log stream --info --style compact --predicate 'process == "FocusFrame"' ;;
  --telemetry) exec /usr/bin/log stream --info --style compact --predicate 'subsystem == "de.highbytetech.FocusFrame"' ;;
esac
