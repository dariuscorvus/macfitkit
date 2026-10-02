#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# A desktop session is required. This probe uses the real overlay/renderer but
# no Accessibility permission, external app manipulation or pointer events.
PROBE_DIR=$(mktemp -d "${TMPDIR:-/tmp}/focusframe-overlay.XXXXXX")
trap 'rm -rf "$PROBE_DIR"' EXIT
TARGET="$(uname -m)-apple-macosx14.0"
swiftc -target "$TARGET" -parse-as-library -emit-module -emit-library \
  -module-name FocusFrameCore Sources/FocusFrameCore/*.swift \
  -emit-module-path "$PROBE_DIR/FocusFrameCore.swiftmodule" \
  -o "$PROBE_DIR/libFocusFrameCore.dylib"
swiftc -target "$TARGET" -parse-as-library -I "$PROBE_DIR" -L "$PROBE_DIR" \
  -lFocusFrameCore -Xlinker -rpath -Xlinker "$PROBE_DIR" \
  Sources/FocusFrame/EffectRenderer.swift Sources/FocusFrame/OverlayWindow.swift \
  script/tests/OverlayGeometryTests.swift -o "$PROBE_DIR/OverlayGeometryTests"
"$PROBE_DIR/OverlayGeometryTests" "$@"
