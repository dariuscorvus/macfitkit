import AppKit
import CryptoKit
import Foundation
import Security
import MacFitKitCore

public struct ToolUpdateReceipt: Sendable {
    public let application: URL
    public let backup: URL
}

/// Download and stage first; preserve a verified backup before publishing the replacement.
public actor ToolUpdater {
    private let backupDirectory: URL
    private let verify: @Sendable (URL, URL, Bool) throws -> Void
    private let isRunning: @MainActor @Sendable (ToolID) -> Bool
    public init(backupDirectory: URL) {
        self.backupDirectory = backupDirectory; verify = Self.verifyCode
        isRunning = { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleIdentifier).isEmpty }
    }
    init(backupDirectory: URL, verify: @escaping @Sendable (URL, URL, Bool) throws -> Void = ToolUpdater.verifyCode,
         isRunning: @escaping @MainActor @Sendable (ToolID) -> Bool = { _ in false }) {
        self.backupDirectory = backupDirectory; self.verify = verify; self.isRunning = isRunning
    }

    public func updateFromRelease(_ tool: ToolID, release: PublishedToolRelease, destination: URL,
                                  beforeReplace: @escaping @MainActor @Sendable () async throws -> Void) async throws -> ToolUpdateReceipt {
        guard let url = release.downloadURL, let checksum = release.archiveSHA256 else {
            throw InstallError("Für dieses Release fehlt ein prüfbares ZIP-Installationspaket.")
        }
        let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("MacFitKit-download-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: workspace) }
        var request = URLRequest(url: url, timeoutInterval: 120)
        request.setValue("MacFitKit", forHTTPHeaderField: "User-Agent")
        let (download, response) = try await URLSession.shared.download(for: request)
        defer { try? FileManager.default.removeItem(at: download) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw InstallError("Der Update-Download ist fehlgeschlagen.") }
        guard try ToolUpdateFiles.digest(download) == checksum.lowercased() else {
            throw InstallError("Die Prüfsumme des Downloads stimmt nicht. Die vorhandene App wurde nicht verändert.")
        }
        try ToolUpdateFiles.validateArchive(download)
        let unpacked = workspace.appendingPathComponent("unpacked")
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", download.path, unpacked.path])
        let source = unpacked.appendingPathComponent(tool.name + ".app")
        return try await update(tool, source: source, destination: destination, expectedVersion: release.version,
                                downloaded: true, beforeReplace: beforeReplace)
    }

    public func update(_ tool: ToolID, source: URL, destination: URL, expectedVersion: ToolVersion,
                       downloaded: Bool = false,
                       beforeReplace: @escaping @MainActor @Sendable () async throws -> Void) async throws -> ToolUpdateReceipt {
        let manager = FileManager.default
        guard let current = ToolVersion.read(appURL: destination), expectedVersion > current,
              Bundle(url: destination)?.bundleIdentifier == tool.bundleIdentifier else {
            throw InstallError("Kein neueres passendes Update vorhanden. Die App wurde nicht verändert.")
        }
        guard manager.isWritableFile(atPath: destination.deletingLastPathComponent().path),
              (try destination.resourceValues(forKeys: [.isSymbolicLinkKey])).isSymbolicLink != true else {
            throw InstallError("Der Installationsort ist nicht beschreibbar oder ist eine Verknüpfung.")
        }
        try validate(source, tool: tool, expected: expectedVersion, old: destination, downloaded: downloaded)
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".MacFitKit-update-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: false)
        var keepStaging = false
        defer { if !keepStaging { try? manager.removeItem(at: staging) } }
        let staged = staging.appendingPathComponent(tool.name + ".app")
        try manager.copyItem(at: source, to: staged)
        try validate(staged, tool: tool, expected: expectedVersion, old: destination, downloaded: downloaded)
        try await beforeReplace()
        let running = await isRunning(tool)
        guard !running else { throw InstallError("\(tool.name) läuft noch. Das Update wurde abgebrochen; die alte App ist unverändert.") }
        guard ToolVersion.read(appURL: destination) == current else {
            throw InstallError("Die installierte Version hat sich während der Vorbereitung geändert. Bitte erneut prüfen.")
        }
        let label = (current.version + "-build" + current.build).map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        let backup = backupDirectory.appendingPathComponent(tool.name + "-" + String(label.prefix(80)) + "-" + UUID().uuidString)
        try manager.createDirectory(at: backup, withIntermediateDirectories: true)
        let archive = backup.appendingPathComponent(tool.name + ".zip")
        let previousHashes = try ToolUpdateFiles.manifest(destination)
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", destination.path, archive.path])
        let verified = staging.appendingPathComponent("backup-verification")
        try ToolUpdateFiles.run("/usr/bin/ditto", ["-x", "-k", archive.path, verified.path])
        guard try ToolUpdateFiles.manifest(verified.appendingPathComponent(tool.name + ".app")) == previousHashes else {
            throw InstallError("Das Backup konnte nicht verifiziert werden. Die alte App wurde nicht verändert.")
        }
        try ToolUpdateFiles.run("/usr/bin/defaults", ["export", tool.bundleIdentifier, backup.appendingPathComponent("Settings.plist").path])
        let record = ["tool": tool.name, "previousVersion": current.display, "newVersion": expectedVersion.display,
                      "application": destination.path, "createdAt": ISO8601DateFormatter().string(from: Date())]
        try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
            .write(to: backup.appendingPathComponent("Update.json"), options: .atomic)
        guard !(await isRunning(tool)) else {
            throw InstallError("\(tool.name) wurde während der Sicherung erneut gestartet. Die alte App wurde nicht ausgetauscht.")
        }
        let original = staging.appendingPathComponent("original.app")
        try manager.moveItem(at: destination, to: original)
        do {
            try manager.moveItem(at: staged, to: destination)
            try validate(destination, tool: tool, expected: expectedVersion, old: original, downloaded: downloaded)
        } catch {
            do {
                if manager.fileExists(atPath: destination.path) { try manager.removeItem(at: destination) }
                try manager.moveItem(at: original, to: destination)
            } catch {
                // Do not let the staging cleanup erase the last uncompressed original.
                let rescued = backup.appendingPathComponent("Original.app")
                do { try manager.moveItem(at: original, to: rescued) } catch { keepStaging = true }
                throw InstallError("Die Wiederherstellung benötigt Hilfe. Das geprüfte Backup liegt unter \(archive.path).")
            }
            throw InstallError("Update fehlgeschlagen. Die vorherige App wurde wiederhergestellt. Backup: \(archive.path)")
        }
        return ToolUpdateReceipt(application: destination, backup: backup)
    }

    private func validate(_ app: URL, tool: ToolID, expected: ToolVersion, old: URL, downloaded: Bool) throws {
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == tool.bundleIdentifier,
              let executable = bundle.executableURL, FileManager.default.isExecutableFile(atPath: executable.path),
              ToolVersion.read(appURL: app) == expected else { throw InstallError("Das Updatepaket enthält nicht die erwartete App-Version.") }
        if let minimum = bundle.object(forInfoDictionaryKey: "LSMinimumSystemVersion") as? String {
            let system = ProcessInfo.processInfo.operatingSystemVersion
            let installedOS = "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion)"
            guard ToolVersion(version: installedOS, build: "0") >= ToolVersion(version: minimum, build: "0") else {
                throw InstallError("Dieses Update benötigt macOS \(minimum).")
            }
        }
        try verify(app, old, downloaded)
    }

    private static func team(_ url: URL) -> String? {
        var code: SecStaticCode?; var info: CFDictionary?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dictionary = info as? [String: Any] else { return nil }
        return dictionary[kSecCodeInfoTeamIdentifier as String] as? String
    }
    static func verifyCode(_ new: URL, _ old: URL, _ downloaded: Bool) throws {
        try ToolInstaller.validateSignature(new)
        #if arch(arm64)
        let architecture = 0x0100000c
        #else
        let architecture = 0x01000007
        #endif
        guard Bundle(url: new)?.executableArchitectures?.contains(where: { $0.intValue == architecture }) == true else {
            throw InstallError("Das Update enthält keine passende Version für den Prozessor dieses Mac.")
        }
        let expected = team(old) ?? team(Bundle.main.bundleURL)
        if let expected {
            guard team(new) == expected else { throw InstallError("Der Herausgeber der neuen App stimmt nicht mit der installierten Version überein.") }
        } else if downloaded && team(new) == nil {
            throw InstallError("Das heruntergeladene Update hat keinen überprüfbaren Herausgeber.")
        }
    }
}

internal enum ToolUpdateFiles {
    static func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var digest = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { digest.update(data: data) }
        return digest.finalize().map { String(format: "%02x", $0) }.joined()
    }
    static func manifest(_ root: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let rootComponents = canonicalRoot.pathComponents
        guard let files = FileManager.default.enumerator(at: canonicalRoot, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else {
            throw InstallError("Die App-Dateien konnten nicht geprüft werden.")
        }
        for case let url as URL in files {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            let components = url.standardizedFileURL.pathComponents
            guard Array(components.prefix(rootComponents.count)) == rootComponents else {
                throw InstallError("Ein Dateipfad liegt außerhalb der geprüften App.")
            }
            let key = components.dropFirst(rootComponents.count).joined(separator: "/")
            if values.isSymbolicLink == true { result[key] = "link:" + (try FileManager.default.destinationOfSymbolicLink(atPath: url.path)) }
            else if values.isRegularFile == true { result[key] = try digest(url) }
        }
        return result
    }
    @discardableResult static func run(_ executable: String, _ arguments: [String]) throws -> String {
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("MacFitKit-command-" + UUID().uuidString)
        FileManager.default.createFile(atPath: output.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: output) }
        let handle = try FileHandle(forWritingTo: output); defer { try? handle.close() }
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = handle; process.standardError = handle
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw InstallError("Der Installationsschritt \(URL(fileURLWithPath: executable).lastPathComponent) ist fehlgeschlagen. Die Sicherung bleibt erhalten.") }
        return String(decoding: try Data(contentsOf: output), as: UTF8.self)
    }
    static func validateArchive(_ archive: URL) throws {
        let listing = try run("/usr/bin/zipinfo", ["-1", archive.path])
        for name in listing.split(separator: "\n") {
            guard !name.hasPrefix("/"), !name.split(separator: "/").contains(".."), !name.contains("\\") else {
                throw InstallError("Das Updatearchiv enthält unsichere Dateipfade.")
            }
        }
        let modes = try run("/usr/bin/zipinfo", ["-l", archive.path])
        guard !modes.split(separator: "\n").contains(where: { $0.hasPrefix("l") }) else {
            throw InstallError("Dieses Updatearchiv enthält nicht unterstützte Verknüpfungen.")
        }
    }
}
