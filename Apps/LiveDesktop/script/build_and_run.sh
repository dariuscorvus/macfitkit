#!/bin/zsh
set -eu
cd "${0:A:h}/.."
pkill -x LiveDesktop 2>/dev/null || true
./scripts/build-app.sh
app_dir="${LIVE_DESKTOP_APP_DIR:-$HOME/Library/Caches/LiveDesktop/App}/LiveDesktop.app"
/usr/bin/open -n "$app_dir" --args "$@"
