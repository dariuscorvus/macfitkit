import Foundation
import Testing
import MacFitKitCore
@testable import MacFitKitPlatform

@Test func versionsCompareMarketingVersionBeforeBuild() {
    #expect(ToolVersion(version: "1.0", build: "1") == ToolVersion(version: "1.0.0", build: "1"))
    #expect(ToolVersion(version: "1.10.0", build: "1") > ToolVersion(version: "1.9.0", build: "999"))
    #expect(ToolVersion(version: "1.0.0", build: "12") > ToolVersion(version: "1.0.0", build: "9"))
    #expect(!(ToolVersion(version: "1.0.0", build: "9") > ToolVersion(version: "1.0.0", build: "9")))
}

@Test func installedVersionIsReadFreshAndMissingMetadataIsUnknown() throws {
    let app = FileManager.default.temporaryDirectory.appendingPathComponent("VersionTests-" + UUID().uuidString + ".app")
    defer { try? FileManager.default.removeItem(at: app) }
    try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    #expect(ToolVersion.read(appURL: app) == nil)
    for build in ["1", "2"] {
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleShortVersionString": "1.0.0", "CFBundleVersion": build], format: .xml, options: 0)
        try data.write(to: app.appendingPathComponent("Contents/Info.plist"))
        #expect(ToolVersion.read(appURL: app)?.build == build)
    }
}

private func releaseFixture() throws -> Data {
    try JSONSerialization.data(withJSONObject: [["tag_name": "focusframe-v0.9.0-preview.3", "draft": false, "prerelease": true,
        "published_at": "2026-10-17T00:00:00Z", "html_url": "https://github.com/dariuscorvus/macfitkit/releases/tag/focusframe-v0.9.0-preview.3",
        "assets": [["name": "Release-info.json", "url": "https://api.github.com/repos/dariuscorvus/macfitkit/releases/assets/1"]]]])
}

@Test func releaseCheckUsesManifestVersionRatherThanPreviewTag() async throws {
    let fixture = try releaseFixture()
    let releases = try await ToolReleaseChecker.check { request in
        if request.url == ToolReleaseChecker.releasesURL { return fixture }
        return Data(#"{"app":"FocusFrame","version":"0.9.0","build":"9","bundleIdentifier":"de.highbytetech.FocusFrame"}"#.utf8)
    }
    #expect(releases[.focusFrame]?.version == ToolVersion(version: "0.9.0", build: "9"))
    #expect(releases[.focusFrame]?.prerelease == true)
    #expect(releases[.universalPiP] == nil)
}

@Test func releaseCheckRejectsWrongIdentityAndNetworkFailure() async throws {
    let fixture = try releaseFixture()
    await #expect(throws: (any Error).self) {
        try await ToolReleaseChecker.check { request in
            if request.url == ToolReleaseChecker.releasesURL { return fixture }
            return Data(#"{"app":"FocusFrame","version":"99.0.0","build":"99","bundleIdentifier":"wrong.app"}"#.utf8)
        }
    }
    await #expect(throws: (any Error).self) {
        try await ToolReleaseChecker.check { _ in throw URLError(.notConnectedToInternet) }
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MACFITKIT_LIVE_UPDATE_CHECK"] == "1"))
func publicReleaseSourceIsReachable() async throws {
    let releases = try await ToolReleaseChecker.check()
    #expect(releases.count == 4)
    for tool in ToolID.allCases {
        let release = try #require(releases[tool])
        print("\(tool.name): \(release.version.display) [\(release.tag)]")
    }
}
