#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TITLE="${1:?Usage: run_pip_capture_probe.sh EXACT_UTM_WINDOW_TITLE REPORT_JSON [SECONDS]}"
REPORT="${2:?Missing report path}"
SECONDS_TO_RUN="${3:-30}"
PROBE_DIR="$HOME/Library/Caches/MacFitKit/PiPCaptureProbe"
APP="$PROBE_DIR/PiPCaptureProbe.app"
mkdir -p "$APP/Contents/MacOS"
swiftc -parse-as-library -swift-version 6 -O -target "$(uname -m)-apple-macosx14.0" "$ROOT_DIR/Packages/UniversalPiP/Sources/UniversalPiP/"*.swift "$ROOT_DIR/Tests/Integration/PiPCaptureProbe.swift" -o "$APP/Contents/MacOS/PiPCaptureProbe"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>tech.highbyte.UniversalPiPProbe</string><key>CFBundleExecutable</key><string>PiPCaptureProbe</string><key>CFBundleName</key><string>PiPCaptureProbe</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSScreenCaptureUsageDescription</key><string>Lokaler Capture-Test des ausdrücklich gewählten UTM-Fensters; keine Bildspeicherung.</string></dict></plist>
PLIST
codesign --force --sign - "$APP"
open -n "$APP" --args "$TITLE" "$REPORT" "$SECONDS_TO_RUN"
echo "$APP"
