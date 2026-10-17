import Foundation
import Testing
import MacFitKitCore
@testable import MacFitKitPlatform

private struct RemovalFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("UninstallTests-" + UUID().uuidString)
    var backups: URL { root.appendingPathComponent("backups") }
    func app(_ index: Int, tool: ToolID) -> URL { root.appendingPathComponent("copy\(index)/" + tool.name + ".app") }
    func create(_ index: Int, tool: ToolID) throws {
        let app = app(index, tool: tool)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": tool.bundleIdentifier,
            "CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"], format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
    }
    func trash(_ app: URL) throws -> URL {
        let folder = root.appendingPathComponent("Trash")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(app.deletingLastPathComponent().lastPathComponent + "-" + app.lastPathComponent)
        try FileManager.default.moveItem(at: app, to: destination)
        return destination
    }
    func clean() { try? FileManager.default.removeItem(at: root) }
}

@Test(arguments: ToolID.allCases) func uninstallBacksUpAllCopiesBeforeMovingThemToTrash(tool: ToolID) async throws {
    let fixture = RemovalFixture(); defer { fixture.clean() }
    try fixture.create(0, tool: tool); try fixture.create(1, tool: tool)
    let first = fixture.app(0, tool: tool), second = fixture.app(1, tool: tool)
    let hashes = try ToolUpdateFiles.manifest(first)
    let remover = ToolUninstaller(backupDirectory: fixture.backups, trash: { try fixture.trash($0) })
    let backup = try await remover.uninstall(tool, applications: [first, second], beforeRemoval: {})
    #expect(!FileManager.default.fileExists(atPath: first.path))
    #expect(!FileManager.default.fileExists(atPath: second.path))
    #expect(FileManager.default.fileExists(atPath: backup.appendingPathComponent("Settings.plist").path))
    for index in 0...1 {
        let restored = fixture.root.appendingPathComponent("restored\(index)")
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", backup.appendingPathComponent("\(index)-" + tool.name + ".zip").path, restored.path])
        #expect(try ToolUpdateFiles.manifest(restored.appendingPathComponent(tool.name + ".app")) == hashes)
    }
}

@Test func failedRemovalRestoresAlreadyMovedCopies() async throws {
    let fixture = RemovalFixture(); defer { fixture.clean() }
    try fixture.create(0, tool: .focusFrame); try fixture.create(1, tool: .focusFrame)
    let first = fixture.app(0, tool: .focusFrame), second = fixture.app(1, tool: .focusFrame)
    let before = try ToolUpdateFiles.manifest(first)
    let remover = ToolUninstaller(backupDirectory: fixture.backups, trash: { url in
        if url == second { throw InstallError("Simulated trash failure") }
        return try fixture.trash(url)
    })
    await #expect(throws: InstallError.self) { try await remover.uninstall(.focusFrame, applications: [first, second], beforeRemoval: {}) }
    #expect(try ToolUpdateFiles.manifest(first) == before)
    #expect(try ToolUpdateFiles.manifest(second) == before)
    #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.backups.path).count == 1)
}

@Test func runningAppAndFailedBackupPreventAnyRemoval() async throws {
    let fixture = RemovalFixture(); defer { fixture.clean() }; try fixture.create(0, tool: .focusFrame)
    let app = fixture.app(0, tool: .focusFrame)
    let running = ToolUninstaller(backupDirectory: fixture.backups, isRunning: { _ in true }, trash: { _ in
        Issue.record("A running app must not be trashed"); throw InstallError("Unexpected trash")
    })
    await #expect(throws: InstallError.self) { try await running.uninstall(.focusFrame, applications: [app], beforeRemoval: {}) }
    #expect(!FileManager.default.fileExists(atPath: fixture.backups.path))
    try Data("block backups".utf8).write(to: fixture.backups)
    let failing = ToolUninstaller(backupDirectory: fixture.backups, trash: { _ in
        Issue.record("A failed backup must prevent removal"); throw InstallError("Unexpected trash")
    })
    await #expect(throws: (any Error).self) { try await failing.uninstall(.focusFrame, applications: [app], beforeRemoval: {}) }
    #expect(FileManager.default.fileExists(atPath: app.path))
}


@Test @MainActor func removedBundleIsNotDetectedFromCachedMetadata() throws {
    let fixture = RemovalFixture(); defer { fixture.clean() }
    try fixture.create(0, tool: .focusFrame)
    let app = fixture.app(0, tool: .focusFrame)
    #expect(Bundle(url: app)?.bundleIdentifier == ToolID.focusFrame.bundleIdentifier)
    #expect(ToolLocator.existingApplication(app, tool: .focusFrame))
    try FileManager.default.removeItem(at: app)
    #expect(!ToolLocator.existingApplication(app, tool: .focusFrame))
}
