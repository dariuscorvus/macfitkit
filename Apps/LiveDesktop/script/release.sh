#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PROFILE=""
case "${1:-}" in
  "") ;;
  --notarize) PROFILE="${2:?Usage: $0 --notarize KEYCHAIN_PROFILE}" ;;
  *) echo "Usage: $0 [--notarize KEYCHAIN_PROFILE]" >&2; exit 2 ;;
esac
VERSION=$(awk '$1 == "MARKETING_VERSION" { print $3 }' Config/Version.xcconfig)
BUILD=$(awk '$1 == "CURRENT_PROJECT_VERSION" { print $3 }' Config/Version.xcconfig)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$BUILD" =~ ^[0-9]+$ ]] || { echo 'Invalid version' >&2; exit 1; }
SIGN_ID="${LIVE_DESKTOP_SIGN_IDENTITY:-}"
if [[ -z "$SIGN_ID" ]]; then
  SIGN_ID=$(security find-identity -v -p codesigning | awk -F '"' '/"Developer ID Application:/{ print $2; exit }')
fi
[[ -n "$SIGN_ID" ]] || { echo 'A Developer ID Application certificate is required.' >&2; exit 1; }
CACHE="$HOME/Library/Caches/LiveDesktop"
mkdir -p "$CACHE"
SCRATCH="$CACHE/ReleaseBuild"
STAGE=$(mktemp -d "$CACHE/release-stage.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
OUTPUT="$ROOT_DIR/dist/releases/$VERSION"
mkdir -p "$OUTPUT"
SUFFIX="-unnotarized"
if [[ -n "$PROFILE" ]]; then SUFFIX=""; fi
DMG="$OUTPUT/LiveDesktop-$VERSION$SUFFIX.dmg"
[[ ! -e "$DMG" ]] || { echo "Refusing to overwrite existing release: $DMG" >&2; exit 1; }
swift build --build-system native -c release --product LiveDesktop --arch arm64 --arch x86_64 --scratch-path "$SCRATCH"
BINARY="$(swift build --build-system native -c release --arch arm64 --arch x86_64 --scratch-path "$SCRATCH" --show-bin-path)/LiveDesktop"
APP="$STAGE/image/LiveDesktop.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/LiveDesktop"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LiveDesktop</string>
<key>CFBundleIdentifier</key><string>tech.highbyte.LiveDesktop.prototype</string>
<key>CFBundleName</key><string>LiveDesktop</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
REVISION=$(git rev-parse HEAD)
printf '%s\n' "$REVISION" > "$APP/Contents/Resources/SourceRevision.txt"
ARCHS=$(xcrun lipo "$APP/Contents/MacOS/LiveDesktop" -archs)
[[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]] || {
  echo "Missing universal architecture: $ARCHS" >&2; exit 1;
}
xcrun swift-stdlib-tool --copy --scan-executable "$APP/Contents/MacOS/LiveDesktop" \
  --platform macosx --destination "$APP/Contents/Frameworks"
xattr -cr "$APP"
for library in "$APP/Contents/Frameworks/"*.dylib; do
  [[ -f "$library" ]] || continue
  codesign --force --timestamp --options runtime --sign "$SIGN_ID" "$library"
done
codesign --force --timestamp --options runtime --sign "$SIGN_ID" "$APP"
codesign --verify --deep --strict "$APP"
notarize() {
  local file="$1" report="$2"
  xcrun notarytool submit "$file" --keychain-profile "$PROFILE" --wait --output-format json > "$report"
  /usr/bin/plutil -extract status raw -o - "$report" | /usr/bin/grep -qx 'Accepted' || {
    echo "Notarization did not succeed; see $report" >&2; exit 1;
  }
}
if [[ -n "$PROFILE" ]]; then
  ZIP="$STAGE/LiveDesktop-notary.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  notarize "$ZIP" "$OUTPUT/app-notarization.json"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi
cp docs/INSTALLATION.txt "$STAGE/image/Installation.txt"
if [[ -n "$PROFILE" ]]; then
  python3 - "$STAGE/image/Installation.txt" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text();a=s.index('SIGNATUR UND NOTARISIERUNG');b=s.index('Die App ist eine persönliche',a)
s=s[:a]+'SIGNATUR UND NOTARISIERUNG\nDiese App ist Developer-ID-signiert und von Apple notarisiert.\n\n'+s[b:];p.write_text(s)
PY
fi
ln -s /Applications "$STAGE/image/Applications"
hdiutil create -volname "LiveDesktop $VERSION" -srcfolder "$STAGE/image" -fs HFS+ -format UDZO "$DMG"
codesign --timestamp --sign "$SIGN_ID" "$DMG"
codesign --verify --strict "$DMG"
if [[ -n "$PROFILE" ]]; then
  notarize "$DMG" "$OUTPUT/dmg-notarization.json"
  xcrun stapler staple "$DMG"
  xcrun stapler validate "$DMG"
fi
hdiutil verify "$DMG"
cp "$STAGE/image/Installation.txt" "$OUTPUT/Installation.txt"
(cd "$OUTPUT" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
printf 'Version: %s\nBuild: %s\nSource revision: %s\nSigning: %s\nNotarized: %s\nArchitectures: arm64 x86_64\nMinimum macOS: 26.0\n' \
  "$VERSION" "$BUILD" "$REVISION" "$SIGN_ID" "$([[ -n "$PROFILE" ]] && echo yes || echo no)" > "$OUTPUT/Release-info.txt"
echo "Release created: $DMG"
