#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/macfitkit-checks.XXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc -swift-version 6 \
  "$ROOT_DIR/Apps/DockPreview/DockPreview/PreviewGeometry.swift" \
  "$ROOT_DIR/Tests/PreviewCoreChecks.swift" -o "$CHECK_DIR/preview-checks"
"$CHECK_DIR/preview-checks"
