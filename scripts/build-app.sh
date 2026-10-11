#!/bin/zsh
set -eu
cd "${0:A:h}/.."
build_dir="${LIVE_DESKTOP_BUILD_DIR:-$HOME/Library/Caches/LiveDesktop/NativeBuild}"
swift build --build-system native --scratch-path "$build_dir"
bin_dir=$(swift build --build-system native --scratch-path "$build_dir" --show-bin-path)
app_dir="${LIVE_DESKTOP_APP_DIR:-$HOME/Library/Caches/LiveDesktop/App}/LiveDesktop.app"
mkdir -p "$app_dir/Contents/MacOS"
cp "$bin_dir/LiveDesktop" "$app_dir/Contents/MacOS/LiveDesktop"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LiveDesktop</string>
<key>CFBundleIdentifier</key><string>tech.highbyte.LiveDesktop.prototype</string>
<key>CFBundleName</key><string>LiveDesktop</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.1</string>
<key>CFBundleVersion</key><string>4</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
mkdir -p dist
ditto -c -k --norsrc --noextattr --keepParent "$app_dir" "$PWD/dist/LiveDesktop.zip"
print -r -- "$app_dir"
print -r -- "$PWD/dist/LiveDesktop.zip"
