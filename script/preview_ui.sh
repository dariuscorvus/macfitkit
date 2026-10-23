#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${1:?Usage: preview_ui.sh APP [--dark]}"
case "$APP_NAME" in FocusFrame|LiveDesktop|DockPreview|MacFitKit|UniversalPiP|FolderIconer) ;; *) exit 2;; esac
BUILD_DIR="${MACFITKIT_BUILD_DIR:-$HOME/Library/Caches/MacFitKit/Monorepo}"
PREVIEW_DIR=$(mktemp -d "$HOME/Library/Caches/MacFitKit/ui-preview.XXXXXX")
APP="$PREVIEW_DIR/$APP_NAME.app"
ditto "$BUILD_DIR/Build/Products/Debug/$APP_NAME.app" "$APP"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier tech.highbyte.macfitkit.UIPreview.$APP_NAME" "$APP/Contents/Info.plist"
# Dock apps such as FolderIconer have no LSUIElement key; Set fails on a missing key.
if /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$APP/Contents/Info.plist" >/dev/null 2>&1; then /usr/libexec/PlistBuddy -c "Set :LSUIElement false" "$APP/Contents/Info.plist"; fi
xattr -cr "$APP"
codesign --force --sign - "$APP"
open -n "$APP" --args --ui-preview "${2:-}" --preview-report "$PREVIEW_DIR/window-state.txt"
echo "$APP"
