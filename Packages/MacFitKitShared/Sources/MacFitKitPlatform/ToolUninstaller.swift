import AppKit
import Foundation
import MacFitKitCore

public actor ToolUninstaller {
    private let backups: URL
    private let isRunning: @MainActor @Sendable (ToolID) -> Bool
    private let trash: @Sendable (URL) throws -> URL
    public init(backupDirectory: URL) {
        backups = backupDirectory
        isRunning = { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleIdentifier).isEmpty }
        trash = { app in
            var result: NSURL?
            try FileManager.default.trashItem(at: app, resultingItemURL: &result)
            guard let result else { throw InstallError("Die App wurde verschoben, aber der Papierkorb-Pfad fehlt. Die Sicherung bleibt erhalten.") }
            return result as URL
        }
    }
    init(backupDirectory: URL, isRunning: @escaping @MainActor @Sendable (ToolID) -> Bool = { _ in false },
         trash: @escaping @Sendable (URL) throws -> URL) {
        backups = backupDirectory; self.isRunning = isRunning; self.trash = trash
    }

    public func uninstall(_ tool: ToolID, applications: [URL],
                          beforeRemoval: @escaping @MainActor @Sendable () async throws -> Void) async throws -> URL {
        let manager = FileManager.default
        guard !applications.isEmpty else { throw InstallError("Keine installierte App gefunden.") }
        for app in applications {
            guard Bundle(url: app)?.bundleIdentifier == tool.bundleIdentifier,
                  !app.path.contains("/Contents/"),
                  (try app.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
                throw InstallError("Die ausgewählte App-Kopie passt nicht zu \(tool.name).")
            }
        }
        try await beforeRemoval()
        guard !(await isRunning(tool)) else { throw InstallError("\(tool.name) läuft noch. Die Deinstallation wurde abgebrochen.") }
        let backup = backups.appendingPathComponent(tool.name + "-Uninstall-" + UUID().uuidString)
        try manager.createDirectory(at: backup, withIntermediateDirectories: true)
        let verification = manager.temporaryDirectory.appendingPathComponent("MacFitKit-uninstall-" + UUID().uuidString)
        defer { try? manager.removeItem(at: verification) }
        var records: [[String: String]] = []
        // Finish and verify every backup before moving the first installed copy.
        for (index, app) in applications.enumerated() {
            guard Bundle(url: app)?.bundleIdentifier == tool.bundleIdentifier else { throw InstallError("Die App-Kopie hat sich geändert. Keine App wurde entfernt.") }
            let archive = backup.appendingPathComponent("\(index)-" + tool.name + ".zip")
            let hashes = try ToolUpdateFiles.manifest(app)
            try ToolUpdateFiles.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", app.path, archive.path])
            let extracted = verification.appendingPathComponent(String(index))
            try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])
            guard try ToolUpdateFiles.manifest(extracted.appendingPathComponent(app.lastPathComponent)) == hashes else {
                throw InstallError("Das Backup konnte nicht geprüft werden. Keine App wurde entfernt.")
            }
            records.append(["application": app.path, "version": ToolVersion.read(appURL: app)?.display ?? "Unbekannt", "archive": archive.lastPathComponent])
        }
        try ToolUpdateFiles.run("/usr/bin/defaults", ["export", tool.bundleIdentifier, backup.appendingPathComponent("Settings.plist").path])
        try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            .write(to: backup.appendingPathComponent("Uninstall.json"), options: .atomic)
        guard !(await isRunning(tool)) else {
            throw InstallError("\(tool.name) wurde während der Sicherung erneut gestartet. Die Apps wurden nicht entfernt.")
        }
        var moved: [(URL, URL)] = []
        do {
            for app in applications { moved.append((app, try trash(app))) }
        } catch {
            var restored = true
            for (original, trashed) in moved.reversed() {
                do { try manager.moveItem(at: trashed, to: original) } catch { restored = false }
            }
            throw InstallError(restored && applications.allSatisfy({ manager.fileExists(atPath: $0.path) }) ? "Die Deinstallation ist fehlgeschlagen; verschobene Apps wurden wiederhergestellt. Backup: \(backup.path)" :
                "Die Deinstallation ist unvollständig. App-Kopien liegen noch im Papierkorb; das geprüfte Backup liegt unter \(backup.path).")
        }
        return backup
    }
}
