#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROBE_DIR="${FOCUSFRAME_PROBE_DIR:-$HOME/Library/Caches/FocusFrame/OcclusionDesktop}"
APP="$PROBE_DIR/OcclusionDesktop.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -swift-version 6 -target "$(uname -m)-apple-macosx14.0" \
 "$ROOT_DIR/script/experiments/OcclusionDesktop/main.swift" -o "$APP/Contents/MacOS/OcclusionDesktop"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>tech.highbyte.macfitkit.OcclusionDesktop</string>
<key>CFBundleExecutable</key><string>OcclusionDesktop</string>
<key>CFBundleName</key><string>FocusFrame Überdeckungsprüfung</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
# The fixture changes only its own windows, never FocusFrame preferences or permissions.
if [[ "${1:-}" != --build-only ]]; then open "$APP"; fi
