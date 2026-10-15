#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME=DockPreview
case "${1:-}" in FocusFrame|LiveDesktop|DockPreview|MacFitKit|UniversalPiP) APP_NAME="$1"; shift;; esac
MODE="${1:-run}"
case "$MODE" in run|--build-only|--debug|--logs|--telemetry|--verify|--settings|--xcode) ;; *) echo "Usage: $0 [APP] [--build-only|--verify|--settings|--debug|--logs|--telemetry]" >&2; exit 2;; esac
"$ROOT_DIR/script/build.sh" "$APP_NAME" Debug
[[ "$MODE" != --build-only ]] || exit 0
# Never stop or replace an installed app as a side effect of building this checkout.
if pgrep -x "$APP_NAME" >/dev/null; then
 echo "$APP_NAME is already running. Quit that instance explicitly before launching this development build." >&2
 exit 1
fi
BUILD_DIR="${MACFITKIT_BUILD_DIR:-$HOME/Library/Caches/MacFitKit/Monorepo}"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
case "$MODE" in
 --debug) exec lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
 --verify)
   if [[ "$APP_NAME" == UniversalPiP ]]; then
     open -n "$APP_BUNDLE" --args --diagnostics-report "$HOME/Library/Caches/MacFitKit/UniversalPiP-launch.json"
   else open -n "$APP_BUNDLE"; fi ;;
 --settings) open -n "$APP_BUNDLE" --args --settings ;;
 *) open -n "$APP_BUNDLE" ;;
esac
case "$MODE" in
 --verify) sleep 2; pgrep -f "$APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null; echo "$APP_NAME process verified." ;;
 --logs|--telemetry) exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
esac
