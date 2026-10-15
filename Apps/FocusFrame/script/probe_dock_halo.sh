#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PROBE_DIR="$HOME/Library/Caches/FocusFrame/DockHaloProbe"
APP_BUNDLE="$PROBE_DIR/DockHaloProbe.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
TARGET="$(uname -m)-apple-macosx14.0"
swiftc -target "$TARGET" -parse-as-library -emit-module -emit-library \
  -module-name FocusFrameCore Sources/FocusFrameCore/*.swift \
  -emit-module-path "$PROBE_DIR/FocusFrameCore.swiftmodule" -o "$PROBE_DIR/libFocusFrameCore.dylib"
swiftc -target "$TARGET" -I "$PROBE_DIR" -L "$PROBE_DIR" -lFocusFrameCore \
  -Xlinker -rpath -Xlinker "$PROBE_DIR" \
  Sources/FocusFrame/EffectRenderer.swift Sources/FocusFrame/OverlayWindow.swift \
  script/experiments/DockHalo/*.swift -o "$APP_BUNDLE/Contents/MacOS/DockHaloProbe"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>DockHaloProbe</string>
<key>CFBundleIdentifier</key><string>de.highbytetech.FocusFrame.DockHaloProbe</string>
<key>CFBundleName</key><string>DockHaloProbe</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$PROBE_DIR/libFocusFrameCore.dylib"
codesign --force --sign - --identifier de.highbytetech.FocusFrame.DockHaloProbe \
  --requirements '=designated => identifier "de.highbytetech.FocusFrame.DockHaloProbe"' "$APP_BUNDLE"
codesign --verify --strict "$APP_BUNDLE"
# --stdio inherits existing terminal authorization for diagnostics, if available.
# Default GUI launch uses Launch Services; never opens a TCC permission prompt.
if [[ "${1:-}" == "--stdio" ]]; then
  shift
  exec "$APP_BUNDLE/Contents/MacOS/DockHaloProbe" "$@"
fi
mkdir -p work/dock
LOG_PATH="$ROOT_DIR/work/dock/prototype.log"
: > "$LOG_PATH"
FOCUSFRAME_DOCK_LOG="$LOG_PATH" /usr/bin/open -n -W "$APP_BUNDLE" --args "$@"
cat "$LOG_PATH"
