#!/bin/zsh
set -eu
cd "${0:A:h}/.."
check_dir=$(mktemp -d "${TMPDIR%/}/LiveDesktop-checks.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
cat > "$check_dir/main.swift" <<'SWIFT'
import Foundation
class XCTestCase {}
func XCTAssertEqual<T: Equatable>(_ actual: T, _ expected: T) {
    precondition(actual == expected, "Expected \(expected), got \(actual)")
}
SWIFT
# Reuse the actual XCTest test bodies on CLT installations without XCTest.
sed '/^import XCTest$/d; /^@testable import LiveDesktopCore$/d' Tests/LiveDesktopCoreTests/CoreTests.swift >> "$check_dir/main.swift"
cat >> "$check_dir/main.swift" <<'SWIFT'
try CoreTests().testCatalogUsesOnlyLocalRegularVideosAndDeduplicates()
CoreTests().testPauseReasonsCannotOverrideManualPause()
try CoreTests().testAppleMetadataUsesLocalizedNamesAndOnlyDownloadedVideos()
try CoreTests().testMalformedMetadataKeepsLocalVideosSelectable()
CoreTests().testRotationSequence()
try CoreTests().testPersistentSettingsAndShuffle()
print("PASS: rotation order, wraparound, duplicate and insufficient candidates; local catalog, localized Apple metadata, missing downloads, malformed metadata, explicit videos and all 16 playback-policy combinations")
SWIFT
swiftc -swift-version 6 Sources/LiveDesktopCore/*.swift "$check_dir/main.swift" -o "$check_dir/checks"
"$check_dir/checks"
