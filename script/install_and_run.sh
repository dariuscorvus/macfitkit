#!/bin/zsh
set -eu
cd "${0:A:h}/.."
installed_app="/Applications/LiveDesktop.app"
if [[ -e "$installed_app" ]]; then
    installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$installed_app/Contents/Info.plist")
    [[ "$installed_id" == "tech.highbyte.LiveDesktop.prototype" ]] || { print -u2 "Ein anderes LiveDesktop-Bundle liegt im Programme-Ordner. Installation abgebrochen."; exit 1; }
    backup_dir="$HOME/Library/Caches/LiveDesktop/Backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    ditto --noextattr --norsrc "$installed_app" "$backup_dir/LiveDesktop.app"
fi
pkill -x LiveDesktop || true
./scripts/build-app.sh
ditto --noextattr --norsrc "$HOME/Library/Caches/LiveDesktop/App/LiveDesktop.app" "$installed_app"
codesign --verify --strict "$installed_app"
open -n "$installed_app" --args "$@"
