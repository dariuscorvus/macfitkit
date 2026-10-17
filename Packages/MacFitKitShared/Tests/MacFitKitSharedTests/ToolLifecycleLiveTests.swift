import Foundation
import Testing
import MacFitKitCore
@testable import MacFitKitPlatform

private final class TestTrashItems: @unchecked Sendable {
    private let lock = NSLock()
    private var urls: [URL] = []
    func add(_ url: URL) { lock.lock(); urls.append(url); lock.unlock() }
    func all() -> [URL] { lock.lock(); defer { lock.unlock() }; return urls }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["MACFITKIT_FULL_LIVE_FLOW"] == "1"))
func allFourRealAppsInstallUpdateTrashAndRestore() async throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("MacFitKitFullLifecycle-" + UUID().uuidString)
    let applications = root.appendingPathComponent("Applications")
    let backupRoot = root.appendingPathComponent("Backups")
    let payloads = manager.homeDirectoryForCurrentUser
        .appendingPathComponent("Applications/MacFitKit.app/Contents/Resources/ToolPayloads")
    let identity = try #require(ProcessInfo.processInfo.environment["MACFITKIT_TEST_SIGN_IDENTITY"])
    let trashed = TestTrashItems()
    defer {
        // Retrieve only the exact disposable test items returned by the system Trash API.
        for url in trashed.all() where manager.fileExists(atPath: url.path) {
            let retrieved = root.appendingPathComponent("retrieved-" + UUID().uuidString + ".app")
            try? manager.moveItem(at: url, to: retrieved)
        }
        try? manager.removeItem(at: root)
    }
    let releases: [ToolID: PublishedToolRelease]
    if let path = ProcessInfo.processInfo.environment["MACFITKIT_TEST_RELEASE_METADATA"] {
        let cache = URL(fileURLWithPath: path)
        releases = try await ToolReleaseChecker.check { request in
            let file = request.url == ToolReleaseChecker.releasesURL ? "releases.json" : (request.url!.lastPathComponent + ".json")
            return try Data(contentsOf: cache.appendingPathComponent(file))
        }
    } else { releases = try await ToolReleaseChecker.check() }
    let installer = ToolInstaller(payloadDirectory: payloads, applicationsDirectory: applications)
    var report: [[String: String]] = []
    for tool in ToolID.allCases {
        let release = try #require(releases[tool])
        let app = try await installer.install(tool)
        try ToolInstaller.validateSignature(app)
        let installed = try #require(ToolVersion.read(appURL: app))
        // Construct an older signed fixture from a real executable, without changing the user's apps.
        let plist = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plist)
        let decoded = try PropertyListSerialization.propertyList(from: data, format: nil)
        var info = try #require(decoded as? [String: Any])
        info["CFBundleShortVersionString"] = "0.0.1"; info["CFBundleVersion"] = "0"
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist)
        try ToolUpdateFiles.run("/usr/bin/codesign", ["--force", "--sign", identity, app.path])
        try ToolInstaller.validateSignature(app)
        let original = try ToolUpdateFiles.manifest(app)
        let updater = ToolUpdater(backupDirectory: backupRoot, isRunning: { _ in false })
        let update = try await updater.updateFromRelease(tool, release: release, destination: app, beforeReplace: {})
        #expect(ToolVersion.read(appURL: app) == release.version)
        try ToolInstaller.validateSignature(app)
        let updated = try ToolUpdateFiles.manifest(app)
        let unpacked = root.appendingPathComponent("release-" + tool.name)
        try manager.createDirectory(at: unpacked, withIntermediateDirectories: true)
        let incoming = unpacked.appendingPathComponent(tool.name + ".app")
        try manager.copyItem(at: app, to: incoming)
        // Restore the old signed app from the actual update backup and compare every file.
        try manager.removeItem(at: app)
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", update.backup.appendingPathComponent(tool.name + ".zip").path, applications.path])
        try #require(try ToolUpdateFiles.manifest(app) == original)
        try ToolInstaller.validateSignature(app)
        // Exercise failure after publishing a valid new app, and verify automatic rollback.
        let failing = ToolUpdater(backupDirectory: backupRoot, verify: { new, old, downloaded in
            try ToolUpdater.verifyCode(new, old, downloaded)
            if new == app { throw InstallError("Injected publication failure") }
        }, isRunning: { _ in false })
        await #expect(throws: InstallError.self) {
            try await failing.update(tool, source: incoming, destination: app, expectedVersion: release.version, downloaded: true, beforeReplace: {})
        }
        try #require(try ToolUpdateFiles.manifest(app) == original)
        try ToolInstaller.validateSignature(app)
        _ = try await updater.update(tool, source: incoming, destination: app, expectedVersion: release.version, downloaded: true, beforeReplace: {})
        let remover = ToolUninstaller(backupDirectory: backupRoot, isRunning: { _ in false }, trash: { url in
            var resulting: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &resulting)
            guard let resulting else { throw InstallError("No system Trash location returned") }
            let result = resulting as URL; trashed.add(result); return result
        })
        let removedBackup = try await remover.uninstall(tool, applications: [app], beforeRemoval: {})
        #expect(!manager.fileExists(atPath: app.path))
        let trashApp = try #require(trashed.all().last)
        let trashManifest = try ToolUpdateFiles.manifest(trashApp)
        if trashManifest != updated {
            print("TRASH DIAGNOSTIC URL: " + trashApp.absoluteString + " PATH: " + trashApp.path)
            for key in Set(trashManifest.keys).union(updated.keys).sorted() where trashManifest[key] != updated[key] {
                print("DIFFERENCE: \(key) expected=\(updated[key] ?? "missing") actual=\(trashManifest[key] ?? "missing")")
            }
        }
        try #require(trashManifest == updated)
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", removedBackup.appendingPathComponent("0-" + tool.name + ".zip").path, applications.path])
        try #require(try ToolUpdateFiles.manifest(app) == updated)
        try ToolInstaller.validateSignature(app)
        report.append(["tool": tool.name, "installedFromBundle": installed.display, "updatedFromGitHub": release.version.display,
            "updateBackupRestore": "passed: every file hash and signature", "automaticRollback": "passed: every file hash and signature",
            "uninstall": "passed: native system Trash", "uninstallBackupRestore": "passed: every file hash and signature",
            "testScope": "isolated signed app fixtures; UI not exercised"])
        print("PASS \(tool.name): bundle install; real release update; backup restore; failed-update rollback; native Trash; uninstall backup restore")
    }
    #expect(report.count == 4)
    if let path = ProcessInfo.processInfo.environment["MACFITKIT_FLOW_REPORT"] {
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path))
    }
}
