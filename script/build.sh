#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-all}"
CONFIGURATION="${2:-Debug}"
case "$CONFIGURATION" in Debug|Release) ;; *) echo 'Configuration must be Debug or Release' >&2; exit 2;; esac
case "$APP" in
 all) APPS=(FocusFrame LiveDesktop DockPreview UniversalPiP FolderIconer); [[ ! -d "$ROOT_DIR/Apps/MacFitKit" ]] || APPS+=(MacFitKit) ;;
 MacFitKit) APPS=(FocusFrame LiveDesktop DockPreview UniversalPiP MacFitKit) ;;
 FocusFrame|LiveDesktop|DockPreview|UniversalPiP|FolderIconer) APPS=("$APP") ;;
 *) echo 'Unknown MacFitKit app' >&2; exit 2 ;;
esac
BUILD_DIR="${MACFITKIT_BUILD_DIR:-$HOME/Library/Caches/MacFitKit/Monorepo}"
SIGNING_IDENTITY="${MACFITKIT_SIGNING_IDENTITY:-}"
if [[ -z "$SIGNING_IDENTITY" ]]; then
 SIGNING_IDENTITY="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"
fi
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
for app in "${APPS[@]}"; do
 xcodebuild -workspace "$ROOT_DIR/MacFitKit.xcworkspace" -scheme "$app" \
   -configuration "$CONFIGURATION" -destination 'generic/platform=macOS' \
   -derivedDataPath "$BUILD_DIR" CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" build
 codesign --verify --deep --strict "$BUILD_DIR/Build/Products/$CONFIGURATION/$app.app"
done

# A portable hub includes all four signed tools; no download service or source checkout is needed at runtime.
if [[ " ${APPS[*]} " == *" MacFitKit "* ]]; then
 PRODUCTS="$BUILD_DIR/Build/Products/$CONFIGURATION"
 PAYLOADS="$PRODUCTS/MacFitKit.app/Contents/Resources/ToolPayloads"
 mkdir -p "$PAYLOADS"
 for tool in FocusFrame LiveDesktop DockPreview UniversalPiP; do
   rm -rf "$PAYLOADS/$tool.app"
   ditto "$PRODUCTS/$tool.app" "$PAYLOADS/$tool.app"
   codesign --verify --deep --strict "$PAYLOADS/$tool.app"
 done
 codesign --force --sign "$SIGNING_IDENTITY" "$PRODUCTS/MacFitKit.app"
 codesign --verify --deep --strict "$PRODUCTS/MacFitKit.app"
fi
