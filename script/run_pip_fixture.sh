#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="$HOME/Library/Caches/MacFitKit/PiPFixture"
APP="$FIXTURE_DIR/PiPFixture.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -parse-as-library -swift-version 6 -target "$(uname -m)-apple-macosx14.0" "$ROOT_DIR/Tests/Integration/PiPFixture.swift" -o "$APP/Contents/MacOS/PiPFixture"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>tech.highbyte.PiPFixture</string><key>CFBundleExecutable</key><string>PiPFixture</string><key>CFBundleName</key><string>PiPFixture</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
if [[ "${1:-}" != --build-only ]]; then open -n "$APP"; fi
printf '%s\n' "$APP"
