#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_BUNDLE="$HOME/Library/Caches/FocusFrame/FocusFrameFixture.app"
pkill -x FocusFrameFixture >/dev/null 2>&1 || true
swift build --product FocusFrameFixture
mkdir -p "$APP_BUNDLE/Contents/MacOS"
cp "$(swift build --show-bin-path)/FocusFrameFixture" "$APP_BUNDLE/Contents/MacOS/FocusFrameFixture"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>FocusFrameFixture</string>
<key>CFBundleIdentifier</key><string>de.highbytetech.FocusFrameFixture</string>
<key>CFBundleName</key><string>FocusFrameFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
xattr -cr "$APP_BUNDLE"
codesign --force --sign - "$APP_BUNDLE"
/usr/bin/open -n "$APP_BUNDLE"
