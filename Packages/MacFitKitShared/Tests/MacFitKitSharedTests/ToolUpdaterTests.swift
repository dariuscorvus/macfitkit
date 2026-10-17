import Foundation
import Testing
import MacFitKitCore
@testable import MacFitKitPlatform

private struct UpdateFixture {
    let tool: ToolID
    init(tool: ToolID = .focusFrame) { self.tool = tool }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("UpdaterTests-" + UUID().uuidString)
    var old: URL { root.appendingPathComponent("Applications/" + tool.name + ".app") }
    var new: URL { root.appendingPathComponent("payloads/" + tool.name + ".app") }
    var backups: URL { root.appendingPathComponent("backups") }
    func create(_ app: URL, version: String) throws {
        let binary = app.appendingPathComponent("Contents/MacOS/" + tool.name)
        try FileManager.default.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        let info = ["CFBundleIdentifier": tool.bundleIdentifier, "CFBundleExecutable": tool.name,
                    "CFBundlePackageType": "APPL", "CFBundleShortVersionString": version, "CFBundleVersion": "1"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
    }
    func prepare() throws { try create(old, version: "1.0.0"); try create(new, version: "2.0.0") }
    func clean() { try? FileManager.default.removeItem(at: root) }
    var next: ToolVersion { .init(version: "2.0.0", build: "1") }
}

@Test(arguments: ToolID.allCases) func updateBacksUpOldAppAndPublishesNewVersion(tool: ToolID) async throws {
    let fixture = UpdateFixture(tool: tool); defer { fixture.clean() }; try fixture.prepare()
    let before = try ToolUpdateFiles.manifest(fixture.old)
    let updater = ToolUpdater(backupDirectory: fixture.backups, verify: { _, _, _ in })
    let receipt = try await updater.update(tool, source: fixture.new, destination: fixture.old, expectedVersion: fixture.next, beforeReplace: {})
    #expect(ToolVersion.read(appURL: fixture.old) == fixture.next)
    let restored = fixture.root.appendingPathComponent("restore")
    try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", receipt.backup.appendingPathComponent(tool.name + ".zip").path, restored.path])
    #expect(try ToolUpdateFiles.manifest(restored.appendingPathComponent(tool.name + ".app")) == before)
    #expect(FileManager.default.fileExists(atPath: receipt.backup.appendingPathComponent("Settings.plist").path))
    #expect(FileManager.default.fileExists(atPath: receipt.backup.appendingPathComponent("Update.json").path))
}

@Test func failedPublicationRestoresOriginalAndRetainsBackup() async throws {
    let fixture = UpdateFixture(); defer { fixture.clean() }; try fixture.prepare()
    let before = try ToolUpdateFiles.manifest(fixture.old)
    let updater = ToolUpdater(backupDirectory: fixture.backups, verify: { url, _, _ in
        if url == fixture.old { throw InstallError("Simulated final validation failure") }
    })
    await #expect(throws: InstallError.self) {
        try await updater.update(.focusFrame, source: fixture.new, destination: fixture.old, expectedVersion: fixture.next, beforeReplace: {})
    }
    #expect(try ToolUpdateFiles.manifest(fixture.old) == before)
    let backups = try FileManager.default.contentsOfDirectory(at: fixture.backups, includingPropertiesForKeys: nil)
    #expect(backups.count == 1)
    #expect(FileManager.default.fileExists(atPath: backups[0].appendingPathComponent("FocusFrame.zip").path))
}

@Test func runningToolFailedBackupAndDowngradeNeverReplaceOldApp() async throws {
    let fixture = UpdateFixture(); defer { fixture.clean() }; try fixture.prepare()
    let before = try ToolUpdateFiles.manifest(fixture.old)
    let running = ToolUpdater(backupDirectory: fixture.backups, verify: { _, _, _ in }, isRunning: { _ in true })
    await #expect(throws: InstallError.self) {
        try await running.update(.focusFrame, source: fixture.new, destination: fixture.old, expectedVersion: fixture.next, beforeReplace: {})
    }
    #expect(!FileManager.default.fileExists(atPath: fixture.backups.path))
    try Data("block backups".utf8).write(to: fixture.backups)
    let updater = ToolUpdater(backupDirectory: fixture.backups, verify: { _, _, _ in })
    await #expect(throws: (any Error).self) {
        try await updater.update(.focusFrame, source: fixture.new, destination: fixture.old, expectedVersion: fixture.next, beforeReplace: {})
    }
    await #expect(throws: InstallError.self) {
        try await updater.update(.focusFrame, source: fixture.new, destination: fixture.old, expectedVersion: .init(version: "0.9.0", build: "1"), beforeReplace: {})
    }
    #expect(try ToolUpdateFiles.manifest(fixture.old) == before)
}

@Test func updateRejectsUnexpectedVersionBeforeStoppingTool() async throws {
    let fixture = UpdateFixture(); defer { fixture.clean() }; try fixture.prepare()
    let updater = ToolUpdater(backupDirectory: fixture.backups, verify: { _, _, _ in })
    await #expect(throws: InstallError.self) {
        try await updater.update(.focusFrame, source: fixture.new, destination: fixture.old, expectedVersion: .init(version: "3.0.0", build: "1"), beforeReplace: { Issue.record("Tool must not be stopped for invalid package") })
    }
    #expect(ToolVersion.read(appURL: fixture.old)?.version == "1.0.0")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MACFITKIT_LIVE_UPDATE_INSTALL"] == "1"))
func downloadsAndUpdatesRealSignedPackageInIsolatedDirectory() async throws {
    let fixture = UpdateFixture(); defer { fixture.clean() }
    let releases = try await ToolReleaseChecker.check()
    let release = try #require(releases[.focusFrame])
    let source = URL(fileURLWithPath: "/Users/darius/Applications/MacFitKit.app/Contents/Resources/ToolPayloads/FocusFrame.app")
    try FileManager.default.createDirectory(at: fixture.old.deletingLastPathComponent(), withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: source, to: fixture.old)
    let plist = fixture.old.appendingPathComponent("Contents/Info.plist")
    var info = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as? [String: Any])
    info["CFBundleShortVersionString"] = "0.0.1"; info["CFBundleVersion"] = "1"
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist)
    let identity = try #require(ProcessInfo.processInfo.environment["MACFITKIT_TEST_SIGN_IDENTITY"])
    try ToolUpdateFiles.run("/usr/bin/codesign", ["--force", "--sign", identity, fixture.old.path])
    try ToolInstaller.validateSignature(fixture.old)
    let original = try ToolUpdateFiles.manifest(fixture.old)
    let badChecksum = PublishedToolRelease(version: release.version, page: release.page, tag: release.tag,
        prerelease: release.prerelease, downloadURL: release.downloadURL, archiveSHA256: String(repeating: "0", count: 64))
    let updater = ToolUpdater(backupDirectory: fixture.backups, isRunning: { _ in false })
    await #expect(throws: InstallError.self) {
        try await updater.updateFromRelease(.focusFrame, release: badChecksum, destination: fixture.old,
            beforeReplace: { Issue.record("A corrupt download must not stop the tool") })
    }
    #expect(try ToolUpdateFiles.manifest(fixture.old) == original)
    #expect(!FileManager.default.fileExists(atPath: fixture.backups.path))
    let receipt = try await updater.updateFromRelease(.focusFrame, release: release, destination: fixture.old, beforeReplace: {})
    #expect(ToolVersion.read(appURL: receipt.application) == release.version)
    try ToolInstaller.validateSignature(receipt.application)
    #expect(FileManager.default.fileExists(atPath: receipt.backup.appendingPathComponent("FocusFrame.zip").path))
}


@Test func backupManifestsNormalizeDirectoryAliases() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("ManifestAlias-" + UUID().uuidString)
    defer { try? manager.removeItem(at: root) }
    let app = root.appendingPathComponent("Real.app")
    try manager.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    try Data("unchanged".utf8).write(to: app.appendingPathComponent("Contents/file"))
    let alias = root.appendingPathComponent("MuchLongerAlias.app")
    try manager.createSymbolicLink(at: alias, withDestinationURL: app)
    #expect(try ToolUpdateFiles.manifest(app) == ToolUpdateFiles.manifest(alias))
    #expect(try ToolUpdateFiles.manifest(app).keys.sorted() == ["Contents/file"])
}
