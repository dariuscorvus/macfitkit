#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p "$HOME/Library/Caches/MacFitKit"
swift test --package-path Packages/MacFitKitShared --scratch-path "$HOME/Library/Caches/MacFitKit/SharedTests"
swift test --package-path Packages/UniversalPiP --scratch-path "$HOME/Library/Caches/MacFitKit/UniversalPiPTests"
swift test --package-path Packages/FolderIconer --scratch-path "$HOME/Library/Caches/MacFitKit/FolderIconerTests"
python3 Apps/FocusFrame/script/check_xcode_project.py
Apps/FocusFrame/script/test.sh
Apps/LiveDesktop/scripts/check-core.sh
./script/check_preview_core.sh
./script/check_bridge.sh
git diff --check
