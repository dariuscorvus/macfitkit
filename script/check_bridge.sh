#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DIR=$(mktemp -d "$HOME/Library/Caches/MacFitKit/bridge-check.XXXXXX")
trap 'rm -rf "$CHECK_DIR"' EXIT
SHARED="$ROOT_DIR/Packages/MacFitKitShared/Sources"
for MODULE in MacFitKitCore MacFitKitPlatform; do
  DEPS=(-framework Foundation)
  [[ "$MODULE" == MacFitKitCore ]] || DEPS+=(-lMacFitKitCore)
  swiftc -swift-version 6 -target "$(uname -m)-apple-macosx14.0" -parse-as-library -emit-module -emit-library \
    -I "$CHECK_DIR" -L "$CHECK_DIR" "${DEPS[@]}" -Xlinker -rpath -Xlinker "$CHECK_DIR" \
    -module-name "$MODULE" "$SHARED/$MODULE/"*.swift \
    -emit-module-path "$CHECK_DIR/$MODULE.swiftmodule" -o "$CHECK_DIR/lib$MODULE.dylib"
done
swiftc -swift-version 6 -parse-as-library -I "$CHECK_DIR" -L "$CHECK_DIR" -lMacFitKitCore -lMacFitKitPlatform \
  -Xlinker -rpath -Xlinker "$CHECK_DIR" "$ROOT_DIR/Tests/Integration/BridgeProbe.swift" -o "$CHECK_DIR/Probe"
python3 "$ROOT_DIR/Tests/Integration/check_bridge.py" "$CHECK_DIR"
