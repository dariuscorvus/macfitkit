import AppKit
import Observation
import MacFitKitCore
import MacFitKitPlatform

@MainActor @Observable
final class HubController {
    let bridge: ToolBridgeHost
    private let previewDirectory: URL?
    private let previewNamespace: String?
    @ObservationIgnored private var sessionLocations: [ToolID: URL] = [:]
    var isMenuPreview: Bool { previewDirectory != nil }
    init() {
        var directory: URL?
        var namespace: String?
        #if DEBUG
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--menu-preview"), args.indices.contains(index + 2),
           args[index + 2].hasPrefix("tech.highbyte.macfitkit.preview.") {
            directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            namespace = args[index + 2]
        }
        #endif
        previewDirectory = directory; previewNamespace = namespace
        if let namespace {
            bridge = ToolBridgeHost(environment: BridgeEnvironment(namespace: namespace,
                hubBundleIdentifier: namespace + ".hub",
                toolBundleIdentifiers: Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, namespace + "." + $0.rawValue) })))
        } else { bridge = ToolBridgeHost() }
    }
    func running(_ tool: ToolID) -> NSRunningApplication? {
        guard let previewNamespace else { return ToolLocator.running(tool) }
        return NSRunningApplication.runningApplications(withBundleIdentifier: previewNamespace + "." + tool.rawValue).first
    }
    private func location(_ tool: ToolID) -> URL? {
        guard let previewDirectory else {
            if let url = running(tool)?.bundleURL {
                sessionLocations[tool] = url
                return url
            }
            // Restart the same app the user was controlling, even when another copy is installed.
            if let url = sessionLocations[tool], FileManager.default.fileExists(atPath: url.path),
               Bundle(url: url)?.bundleIdentifier == tool.bundleIdentifier { return url }
            guard let url = ToolLocator.location(tool),
                  !url.path.contains(".app/Contents/Resources/ToolPayloads/") else { return nil }
            return url
        }
        let url = previewDirectory.appendingPathComponent(tool.rawValue + ".app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    var catalog: [ToolID] { isMenuPreview ? available : ToolID.allCases }
    var installationDisabled: Bool { isMenuPreview || CommandLine.arguments.contains("--ui-preview") }
    var installing: ToolID?
    var operationDescription = "Wird installiert …"
    var installedVersions: [ToolID: ToolVersion] = [:]
    var bundledVersions: [ToolID: ToolVersion] = [:]
    var publishedReleases: [ToolID: PublishedToolRelease] = [:]
    var checkingUpdates = false
    var updateCheckMessage = "Online noch nicht geprüft"
    var updateCheckFailed = false
    func versionDescription(_ tool: ToolID) -> String {
        let installed = installed(tool) ? (installedVersions[tool]?.display ?? "Version unbekannt") : "Nicht installiert"
        let bundled = bundledVersions[tool]?.display ?? "Kein Installationspaket"
        return "Installiert: \(installed) · Im MacFitKit-Paket: \(bundled)"
    }
    func updateDescription(_ tool: ToolID) -> String {
        let local = bundledVersions[tool]
        let online = publishedReleases[tool]
        let best = [local, online?.version].compactMap { $0 }.max()
        var text = ""
        if let current = installedVersions[tool], let best, best > current {
            text = "Update verfügbar: \(best.display)"
        } else if installed(tool) && installedVersions[tool] == nil {
            text = "Versionsvergleich nicht möglich"
        } else if installed(tool), let current = installedVersions[tool], let best {
            text = best < current ? "Installierte Version ist neuer als die geprüften Pakete" : "Kein neueres geprüftes Paket"
        }
        if let online {
            text += (text.isEmpty ? "Online: " : " · Online: ") + online.version.display + (online.prerelease ? " · Vorabversion" : "")
        }
        return text
    }
    func checkForUpdates() {
        guard !checkingUpdates, !installationDisabled else { return }
        refresh(); checkingUpdates = true; updateCheckFailed = false
        updateCheckMessage = "GitHub-Releases werden geprüft …"
        // Old results are not reported as a successful fresh check after a network error.
        publishedReleases = [:]
        Task {
            defer { checkingUpdates = false }
            do {
                publishedReleases = try await ToolReleaseChecker.check()
                updateCheckMessage = "Online geprüft: " + Date().formatted(date: .abbreviated, time: .shortened)
                if publishedReleases.count < ToolID.allCases.count { updateCheckMessage += " · Nicht für alle Tools ist ein Release verfügbar" }
            } catch {
                updateCheckFailed = true
                updateCheckMessage = "Online-Prüfung fehlgeschlagen: " + error.localizedDescription
            }
        }
    }
    private var payloadDirectory: URL { Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/ToolPayloads", isDirectory: true) }
    func installed(_ tool: ToolID) -> Bool { available.contains(tool) }
    func canInstall(_ tool: ToolID) -> Bool {
        !installationDisabled && installing == nil && supported(tool) && !installed(tool)
            && FileManager.default.fileExists(atPath: payloadDirectory.appendingPathComponent(tool.name + ".app").path)
    }
    func updateVersion(_ tool: ToolID) -> ToolVersion? {
        guard let current = installedVersions[tool] else { return nil }
        var candidates: [ToolVersion] = []
        if let bundled = bundledVersions[tool], bundled > current { candidates.append(bundled) }
        if let release = publishedReleases[tool], release.downloadURL != nil, release.version > current { candidates.append(release.version) }
        return candidates.max()
    }
    func canUpdate(_ tool: ToolID) -> Bool {
        !installationDisabled && installing == nil && supported(tool) && updateVersion(tool) != nil
    }
    var lastBackup: URL?
    func update(_ tool: ToolID) {
        guard canUpdate(tool), let destination = location(tool), let version = updateVersion(tool) else { return }
        installing = tool; operationDescription = "Wird aktualisiert …"; message = "Update für \(tool.name) wird vorbereitet …"
        let wasRunning = running(tool) != nil
        let updater = ToolUpdater(backupDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacFitKit/Backups", isDirectory: true))
        let release = publishedReleases[tool]
        let payload = payloadDirectory.appendingPathComponent(tool.name + ".app")
        let useBundled = bundledVersions[tool] == version
        Task {
            let stop: @MainActor @Sendable () async throws -> Void = { [weak self] in
                guard let self else { throw InstallError("MacFitKit ist nicht mehr verfügbar.") }
                try await self.stopForMaintenance(tool)
            }
            do {
                let receipt: ToolUpdateReceipt
                if useBundled {
                    receipt = try await updater.update(tool, source: payload, destination: destination,
                        expectedVersion: version, beforeReplace: stop)
                } else if let release {
                    receipt = try await updater.updateFromRelease(tool, release: release, destination: destination, beforeReplace: stop)
                } else { throw InstallError("Das Updatepaket ist nicht mehr verfügbar.") }
                sessionLocations[tool] = receipt.application; lastBackup = receipt.backup
                message = "\(tool.name) wurde auf \(version.display) aktualisiert. Backup: \(receipt.backup.path)"
            } catch { message = error.localizedDescription }
            installing = nil; refresh()
            if wasRunning, FileManager.default.fileExists(atPath: destination.path) { start(tool) }
        }
    }
    private func stopForMaintenance(_ tool: ToolID) async throws {
        message = "\(tool.name) wird beendet und gesichert …"
        guard running(tool) != nil else { return }
        quit(tool)
        for _ in 0..<100 {
            if running(tool) == nil { return }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw InstallError("\(tool.name) reagiert nicht auf Beenden. Die vorhandene App wurde nicht verändert.")
    }
    var pendingRemoval: ToolID?
    var removalTargets: [URL] = []
    var removalDescription: String {
        "Diese App-Kopien werden gesichert und in den Papierkorb verschoben:\n\n" + removalTargets.map(\.path).joined(separator: "\n") +
        "\n\nEinstellungen und Anwendungsdaten bleiben erhalten."
    }
    func requestUninstall(_ tool: ToolID) {
        guard installed(tool), !installationDisabled, installing == nil else { return }
        let roots = [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"), URL(fileURLWithPath: "/Applications")]
        var targets = roots.map { $0.appendingPathComponent(tool.name + ".app") }
        if let current = location(tool) { targets.append(current) }
        var seen = Set<String>()
        removalTargets = targets.filter { url in
            FileManager.default.fileExists(atPath: url.path) &&
            !url.path.contains("/Contents/") && !url.path.contains("/.Trash/") && !url.path.contains("/.Trashes/") &&
            Bundle(url: url)?.bundleIdentifier == tool.bundleIdentifier && seen.insert(url.standardizedFileURL.path).inserted
        }
        guard !removalTargets.isEmpty else { message = "Keine entfernbare App-Kopie gefunden."; return }
        pendingRemoval = tool
    }
    func uninstall(_ tool: ToolID) {
        guard !installationDisabled, installing == nil else { return }
        let targets = removalTargets; pendingRemoval = nil
        guard !targets.isEmpty else { return }
        installing = tool; operationDescription = "Wird deinstalliert …"
        let wasRunning = running(tool) != nil
        let uninstaller = ToolUninstaller(backupDirectory: FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MacFitKit/Backups", isDirectory: true))
        Task {
            var succeeded = false
            do {
                lastBackup = try await uninstaller.uninstall(tool, applications: targets, beforeRemoval: { [weak self] in
                    guard let self else { throw InstallError("MacFitKit ist nicht mehr verfügbar.") }
                    try await self.stopForMaintenance(tool)
                })
                sessionLocations.removeValue(forKey: tool)
                message = "\(tool.name) wurde in den Papierkorb verschoben. App-Backup und Einstellungen sind erhalten."
                succeeded = true
            } catch { message = error.localizedDescription }
            installing = nil; refresh()
            if !succeeded, wasRunning, installed(tool) { start(tool) }
        }
    }
    func install(_ tool: ToolID) {
        guard canInstall(tool) else { return }
        installing = tool; operationDescription = "Wird installiert …"; message = ""
        let installer = ToolInstaller(payloadDirectory: payloadDirectory,
            applicationsDirectory: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true))
        Task {
            defer { installing = nil; refresh() }
            do {
                let url = try await installer.install(tool)
                sessionLocations[tool] = url
                message = "\(tool.name) wurde installiert. Du kannst das Tool jetzt starten."
            } catch { message = error.localizedDescription }
        }
    }
    var available: [ToolID] = []
    var message = ""
    func refresh() {
        available = ToolID.allCases.filter { location($0) != nil }
        installedVersions = Dictionary(uniqueKeysWithValues: available.compactMap { tool in
            guard let url = location(tool), let version = ToolVersion.read(appURL: url) else { return nil }
            return (tool, version)
        })
        bundledVersions = Dictionary(uniqueKeysWithValues: ToolID.allCases.compactMap { tool in
            guard let version = ToolVersion.read(appURL: payloadDirectory.appendingPathComponent(tool.name + ".app")) else { return nil }
            return (tool, version)
        })
    }
    func supported(_ tool: ToolID) -> Bool { ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= tool.minimumSystemMajor }
    func description(_ tool: ToolID) -> String {
        guard supported(tool) else { return "Benötigt macOS \(tool.minimumSystemMajor)" }
        if installing == tool { return operationDescription }
        if !installed(tool) {
            if !FileManager.default.fileExists(atPath: payloadDirectory.appendingPathComponent(tool.name + ".app").path) {
                return "Nicht installiert · Installationspaket fehlt in dieser MacFitKit-Version"
            }
            return "Nicht installiert"
        }
        if tool.kind == .app { return running(tool) == nil ? "Nicht gestartet" : "Läuft" }
        if let status = bridge.statuses[tool] { return status.detail }
        return running(tool) == nil ? "Nicht gestartet" : "Nicht verbunden · ggf. Update nötig"
    }
    func open(_ tool: ToolID) {
        if let app = running(tool) { app.activate() } else { start(tool) }
    }
    func quit(_ tool: ToolID) {
        if tool.kind == .app { running(tool)?.terminate() } else { bridge.send(.quit, to: tool) }
    }
    func start(_ tool: ToolID, openSettings: Bool = false) {
        guard installing != tool, supported(tool), let url = location(tool) else { return }
        if running(tool) != nil {
            if openSettings { bridge.send(.openSettings, to: tool) }
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        if let previewDirectory, let previewNamespace {
            configuration.arguments = [tool.rawValue, previewNamespace, previewDirectory.path]
        }
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { [weak self] app, error in
            let errorMessage = error?.localizedDescription
            Task { @MainActor in
                guard let self else { return }
                if let errorMessage { self.message = errorMessage }
                else if openSettings { self.bridge.send(.openSettings, to: tool) }
                self.refresh()
            }
        }
    }
}
