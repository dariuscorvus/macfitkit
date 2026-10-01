#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
# File-provider folders (e.g. synced Documents) can add FinderInfo to .xctest
# bundles during signing. Keep disposable test build artifacts outside them.
TEST_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/focusframe-tests.XXXXXX")"
trap 'rm -rf "$TEST_BUILD_DIR"' EXIT
# Swift 6.4 CLT can omit this plugin during separate module emission.
SWIFT_BIN_DIR="$(dirname "$(xcrun --find swiftc)")"
TEST_PLUGIN_DIR="$SWIFT_BIN_DIR/../lib/swift/host/plugins/testing"
if [[ -d "$TEST_PLUGIN_DIR" ]]; then
  swift test --disable-xctest --scratch-path "$TEST_BUILD_DIR" \
    -Xswiftc -external-plugin-path \
    -Xswiftc "$TEST_PLUGIN_DIR#$SWIFT_BIN_DIR/swift-plugin-server" "$@"
else
  swift test --disable-xctest --scratch-path "$TEST_BUILD_DIR" "$@"
fi
