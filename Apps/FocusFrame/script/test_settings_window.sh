#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# Test-only native app, isolated preferences. Requires a desktop session.
TEST_DIR=$(mktemp -d "$HOME/Library/Caches/FocusFrame/settings-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT
TARGET="$(uname -m)-apple-macosx14.0"
swiftc -target "$TARGET" -parse-as-library -emit-module -emit-library \
  -module-name FocusFrameCore Sources/FocusFrameCore/*.swift \
  -emit-module-path "$TEST_DIR/FocusFrameCore.swiftmodule" -o "$TEST_DIR/libFocusFrameCore.dylib"
SHARED="$ROOT_DIR/../../Packages/MacFitKitShared/Sources"
for MODULE in MacFitKitCore MacFitKitPlatform MacFitKitUI; do
  DEPS=(-framework Foundation)
  if [[ "$MODULE" != MacFitKitCore ]]; then DEPS+=(-lMacFitKitCore); fi
  if [[ "$MODULE" == MacFitKitUI ]]; then DEPS+=(-lMacFitKitPlatform); fi
  swiftc -swift-version 6 -target "$TARGET" -parse-as-library -emit-module -emit-library \
    -I "$TEST_DIR" -L "$TEST_DIR" "${DEPS[@]}" -Xlinker -rpath -Xlinker "$TEST_DIR" \
    -module-name "$MODULE" "$SHARED/$MODULE/"*.swift \
    -emit-module-path "$TEST_DIR/$MODULE.swiftmodule" -o "$TEST_DIR/lib$MODULE.dylib"
done
APP="$TEST_DIR/SettingsWindowTests.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp "$TEST_DIR/libFocusFrameCore.dylib" "$APP/Contents/Frameworks/"
swiftc -target "$TARGET" -parse-as-library -I "$TEST_DIR" -L "$TEST_DIR" \
  -lFocusFrameCore -lMacFitKitCore -lMacFitKitPlatform -lMacFitKitUI -Xlinker -rpath -Xlinker "$TEST_DIR" \
  Sources/FocusFrame/EffectRenderer.swift "Sources/FocusFrame/EffectRenderer+Animations.swift" Sources/FocusFrame/OverlayWindow.swift \
  Sources/FocusFrame/AccessibilityService.swift Sources/FocusFrame/FocusManager.swift \
  Sources/FocusFrame/SettingsWindowController.swift Sources/FocusFrame/PreferencesStore.swift \
  Sources/FocusFrame/FocusSettingsModel.swift Sources/FocusFrame/FocusSettingsView.swift \
  Sources/FocusFrame/FocusEffectPages.swift Sources/FocusFrame/GradientStopEditor.swift Sources/FocusFrame/FocusAnimationPreview.swift \
  Sources/FocusFrame/AnimationEntriesPage.swift Sources/FocusFrame/TimingCurveEditor.swift \
  Sources/FocusFrame/Diagnostics.swift script/tests/SettingsWindowTests.swift \
  -o "$APP/Contents/MacOS/SettingsWindowTests"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>de.highbytetech.FocusFrame.SettingsWindowTests</string>
<key>CFBundleExecutable</key><string>SettingsWindowTests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP/Contents/Frameworks/libFocusFrameCore.dylib"
codesign --force --sign - "$APP"
open -W -n "$APP" --args "$TEST_DIR/result.txt"
cat "$TEST_DIR/result.txt"
rg -q '^PASS:' "$TEST_DIR/result.txt"
