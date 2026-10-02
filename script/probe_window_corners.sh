#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# Read-only diagnostic executable; never requests/grants capture permission.
PROBE_DIR="$HOME/Library/Caches/FocusFrame/CornerProbe"
mkdir -p "$PROBE_DIR"
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  script/experiments/WindowCornerProbe.swift -o "$PROBE_DIR/WindowCornerProbe"
codesign --force --sign - --identifier de.highbytetech.FocusFrame.CornerProbe "$PROBE_DIR/WindowCornerProbe"
"$PROBE_DIR/WindowCornerProbe" "$@"
