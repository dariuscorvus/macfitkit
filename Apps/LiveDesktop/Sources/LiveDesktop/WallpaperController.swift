import AppKit
import SwiftUI
import AVFoundation
import ServiceManagement
import IOKit.ps
import LiveDesktopCore

@MainActor
final class WallpaperController: ObservableObject {
    static let shared = WallpaperController(ephemeral: CommandLine.arguments.contains("--probe") || CommandLine.arguments.contains("--ui-preview"))
    @Published var searchQuery = ""
    @Published var targetDisplayID = ""
    @Published var assets: [VideoAsset] = []
    @Published var warnings: [String] = []
    @Published var screens: [NSScreen] = []
    @Published var selections: [String: String] = [:]
    @Published var manualPause = false { didSet { persistSettings(); updatePlayback() } }
    @Published var pauseOnLowPower = true { didSet { persistSettings(); updatePlayback() } }
    @Published var status = "Video auswählen"
    @Published var scanning = false
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var loginMessage = ""
    @Published var rotationEnabled = false { didSet { persistRotation(); scheduleRotation() } }
    @Published var rotationMinutes = 15 { didSet { persistRotation(); scheduleRotation() } }
    @Published var favorites: Set<String> = [] { didSet { persistSettings() } }
    @Published var favoritesOnly = false
    @Published var playlists: [VideoPlaylist] = []
    @Published var selectedPlaylistID = "default"
    @Published var playlistName = ""
    @Published var shuffle = false { didSet { persistSettings() } }
    @Published var pauseOnBattery = false { didSet { persistSettings(); updatePlayback() } }
    @Published var crossfade = true { didSet { persistSettings() } }
    @Published var nextChange: Date?
    @Published var thumbnails: [String: NSImage] = [:]
    private var displayPlaylists: [String: String] = [:]
    private var shuffleCycles: [String: ShuffleCycle] = [:]
    private var failedPaths: Set<String> = []
    private var thumbnailTask: Task<Void, Never>?
    private var watchers: [DispatchSourceFileSystemObject] = []
    private var catalogDebounce: Task<Void, Never>?
    @Published var rotationPaths: [String] = [] { didSet { persistRotation(); scheduleRotation() } }
    private var settingsLoaded = false
    private var rotationTimer: Timer?
    @Published var surfaceStates: [String: SurfaceState] = [:]
    private var surfaces: [String: DesktopSurface] = [:]
    private var inactiveReasons: Set<String> = []
    private var scanTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    private let defaults: UserDefaults
    private var extraRoots: [URL] = []
    private var explicitFiles: [URL] = []

    init(ephemeral: Bool = false) {
        defaults = ephemeral ? UserDefaults(suiteName: "LiveDesktop.Probe")! : .standard
        if !ephemeral {
            rotationEnabled = defaults.bool(forKey: "rotationEnabled")
            rotationMinutes = max(1, defaults.integer(forKey: "rotationMinutes") == 0 ? 15 : defaults.integer(forKey: "rotationMinutes"))
            rotationPaths = defaults.stringArray(forKey: "rotationPaths") ?? []
            playlists = [VideoPlaylist(id: "default", name: "Meine Hintergründe", paths: rotationPaths)]
            selections = defaults.dictionary(forKey: "displaySelections") as? [String: String] ?? [:]
            extraRoots = (defaults.stringArray(forKey: "extraRoots") ?? []).map { URL(fileURLWithPath: $0) }
            explicitFiles = (defaults.stringArray(forKey: "explicitFiles") ?? []).map { URL(fileURLWithPath: $0) }
        }
        if !ephemeral, let data = defaults.data(forKey: "settings.v1") {
            do {
                let stored = try JSONDecoder().decode(LiveSettings.self, from: data).normalized
                guard stored.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                manualPause = stored.manualPause; pauseOnLowPower = stored.pauseOnLowPower
                rotationEnabled = stored.rotationEnabled; rotationMinutes = stored.rotationMinutes
                rotationPaths = stored.rotationPaths; selections = stored.selections
                extraRoots = stored.extraRoots.map { URL(fileURLWithPath: $0) }
                explicitFiles = stored.explicitFiles.map { URL(fileURLWithPath: $0) }
                if let library = stored.library {
                    favorites = Set(library.favorites); playlists = library.playlists
                    displayPlaylists = library.displayPlaylists; selectedPlaylistID = library.selectedPlaylist
                    shuffle = library.shuffle; pauseOnBattery = library.pauseOnBattery; crossfade = library.crossfade
                    rotationPaths = playlists.first { $0.id == selectedPlaylistID }?.paths ?? rotationPaths
                }
            } catch { warnings.append("Einstellungen konnten nicht vollständig geladen werden; ältere Auswahl bleibt erhalten.") }
        }
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification) { $0.reconcileScreens() }
        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) { $0.updatePlayback() }
        observe(NotificationCenter.default, ProcessInfo.thermalStateDidChangeNotification) { $0.updatePlayback() }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.inactiveReasons.insert(name.rawValue); self?.updatePlayback() }
            })
        }
        for (name, reason) in [
            (NSWorkspace.didWakeNotification, NSWorkspace.willSleepNotification),
            (NSWorkspace.screensDidWakeNotification, NSWorkspace.screensDidSleepNotification),
            (NSWorkspace.sessionDidBecomeActiveNotification, NSWorkspace.sessionDidResignActiveNotification)
        ] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.inactiveReasons.remove(reason.rawValue); self?.updatePlayback() }
            })
        }
        if playlists.isEmpty { playlists = [VideoPlaylist(id: "default", name: "Meine Hintergründe", paths: rotationPaths)] }
        settingsLoaded = !ephemeral
        persistSettings()
        reconcileScreens()
        if !ephemeral { refreshCatalog(); refreshLoginStatus(); scheduleRotation(); installWatchers() }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) { $0.refreshLoginStatus() }
    }

    func refreshLoginStatus() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginNeedsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func setLoginEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginMessage = ""
        } catch { loginMessage = "Autostart: \(error.localizedDescription)" }
        refreshLoginStatus()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func persistRotation() {
        guard settingsLoaded else { return }
        defaults.set(rotationEnabled, forKey: "rotationEnabled")
        defaults.set(rotationMinutes, forKey: "rotationMinutes")
        defaults.set(rotationPaths, forKey: "rotationPaths")
        persistSettings()
    }

    private func persistSettings() {
        guard settingsLoaded else { return }
        var stored = LiveSettings()
        stored.manualPause = manualPause; stored.pauseOnLowPower = pauseOnLowPower
        stored.rotationEnabled = rotationEnabled; stored.rotationMinutes = rotationMinutes
        stored.rotationPaths = rotationPaths; stored.selections = selections
        if let index = playlists.firstIndex(where: { $0.id == selectedPlaylistID }) { playlists[index].paths = rotationPaths }
        var library = LibraryOptions()
        library.favorites = Array(favorites); library.playlists = playlists
        library.displayPlaylists = displayPlaylists; library.selectedPlaylist = selectedPlaylistID
        library.shuffle = shuffle; library.pauseOnBattery = pauseOnBattery; library.crossfade = crossfade
        stored.library = library
        stored.extraRoots = extraRoots.map(\.path); stored.explicitFiles = explicitFiles.map(\.path)
        if let data = try? JSONEncoder().encode(stored.normalized) { defaults.set(data, forKey: "settings.v1") }
    }

    func retryTarget() {
        for screen in screens where targetDisplayID.isEmpty || screenID(screen) == targetDisplayID {
            if let path = selections[screenID(screen)] { select(path, for: screen) }
        }
    }

    func addWarning(_ message: String) {
        if !warnings.contains(message) { warnings.append(message) }
        if warnings.count > 20 { warnings.removeFirst(warnings.count - 20) }
    }

    func toggleRotationAsset(_ path: String) {
        if rotationPaths.contains(path) { rotationPaths.removeAll { $0 == path } }
        else { rotationPaths.append(path) }
    }

    private func scheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        nextChange = nil
        guard settingsLoaded, rotationEnabled, playlists.contains(where: { $0.paths.count >= 2 }) else { return }
        nextChange = Date().addingTimeInterval(Double(max(1, rotationMinutes)) * 60)
        rotationTimer = Timer.scheduledTimer(withTimeInterval: Double(max(1, rotationMinutes)) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceRotation(); self?.nextChange = Date().addingTimeInterval(Double(self?.rotationMinutes ?? 15) * 60) }
        }
        rotationTimer?.tolerance = 5
    }

    func advanceRotation() {
        guard !manualPause, inactiveReasons.isEmpty,
              !(pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled),
              !(pauseOnBattery && onBattery),
              ProcessInfo.processInfo.thermalState != .serious,
              ProcessInfo.processInfo.thermalState != .critical else { return }
        for screen in screens {
            let id = screenID(screen)
            guard let current = selections[id] else { continue }
            let paths = playlists.first { $0.id == (displayPlaylists[id] ?? selectedPlaylistID) }?.paths ?? rotationPaths
            let available = paths.filter { path in assets.contains { $0.url.path == path } && !failedPaths.contains(path) && FileManager.default.isReadableFile(atPath: path) }
            let next: String?
            if shuffle {
                var cycle = shuffleCycles[id] ?? ShuffleCycle()
                next = cycle.next(current: current, paths: available); shuffleCycles[id] = cycle
            } else { next = RotationSequence.next(current: current, paths: available) }
            if let next { select(next, for: screen) }
        }
    }

    var availableRotationCount: Int { rotationPaths.filter { path in assets.contains { $0.url.path == path } && !failedPaths.contains(path) }.count }
    var onBattery: Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() else { return false }
        return type as String == kIOPSBatteryPowerValue
    }

    func choosePlaylist(_ id: String) {
        selectedPlaylistID = id
        rotationPaths = playlists.first { $0.id == id }?.paths ?? []
        for screen in screens where targetDisplayID.isEmpty || screenID(screen) == targetDisplayID { displayPlaylists[screenID(screen)] = id }
        shuffleCycles.removeAll(); persistSettings(); scheduleRotation()
    }
    func synchronizePlaylistEditor() {
        guard !targetDisplayID.isEmpty, let id = displayPlaylists[targetDisplayID] else { return }
        selectedPlaylistID = id; rotationPaths = playlists.first { $0.id == id }?.paths ?? []
    }
    func saveNamedPlaylist() {
        let name = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let playlist = VideoPlaylist(name: String(name.prefix(80)), paths: rotationPaths)
        playlists.append(playlist); playlistName = ""; choosePlaylist(playlist.id)
    }
    func deletePlaylist() {
        guard playlists.count > 1 else { return }
        playlists.removeAll { $0.id == selectedPlaylistID }
        displayPlaylists = displayPlaylists.filter { $0.value != selectedPlaylistID }
        choosePlaylist(playlists[0].id)
    }
    func toggleFavorite(_ path: String) {
        if favorites.contains(path) { favorites.remove(path) } else { favorites.insert(path) }
    }
    func openReleases() { NSWorkspace.shared.open(URL(string: "https://github.com/dariuscorvus/LiveDesktop/releases/latest")!) }

    func exportLibrary() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "LiveDesktop-Einstellungen.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        func reference(_ path: String) -> String { assets.first { $0.url.path == path }?.appleID.map { "apple:" + $0 } ?? "file:" + URL(fileURLWithPath: path).lastPathComponent }
        let lists = playlists.map { VideoPlaylist(id: $0.id, name: $0.name, paths: $0.paths.map(reference)) }
        let portable = PortableLibrary(favorites: favorites.map(reference), playlists: lists, shuffle: shuffle, interval: rotationMinutes, pauseOnLowPower: pauseOnLowPower, pauseOnBattery: pauseOnBattery, crossfade: crossfade)
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; try encoder.encode(portable).write(to: url, options: .atomic) }
        catch { addWarning("Export fehlgeschlagen: " + error.localizedDescription) }
    }
    func importLibrary() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url); guard data.count < 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let portable = try JSONDecoder().decode(PortableLibrary.self, from: data)
            guard portable.version == 1, !portable.playlists.isEmpty, portable.playlists.count <= 100,
                  Set(portable.playlists.map(\.id)).count == portable.playlists.count else { throw CocoaError(.coderReadCorrupt) }
            var missing = 0
            func resolve(_ ref: String) -> String? {
                let found = assets.first { ref == "apple:" + ($0.appleID ?? "") || ref == "file:" + $0.url.lastPathComponent }?.url.path
                if found == nil { missing += 1 }; return found
            }
            let lists = portable.playlists.map { VideoPlaylist(name: String($0.name.prefix(80)), paths: $0.paths.compactMap(resolve).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }) }
            favorites.formUnion(portable.favorites.compactMap(resolve)); playlists.append(contentsOf: lists)
            shuffle = portable.shuffle; rotationMinutes = [1,5,15,30,60].contains(portable.interval) ? portable.interval : 15
            pauseOnLowPower = portable.pauseOnLowPower; pauseOnBattery = portable.pauseOnBattery; crossfade = portable.crossfade
            choosePlaylist(lists[0].id)
            if missing > 0 { addWarning("Import: \(missing) Verweise fehlen lokal. Videos laden oder erneut auswählen.") }
        } catch { addWarning("Import fehlgeschlagen: " + error.localizedDescription) }
    }

    private func installWatchers() {
        for watcher in watchers { watcher.cancel() }; watchers.removeAll()
        for root in AssetCatalog.defaultRoots + extraRoots {
            for path in [root, root.deletingLastPathComponent()] {
                let fd = open(path.path, O_EVTONLY)
                guard fd >= 0 else { continue }
                let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
                source.setEventHandler { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.catalogDebounce?.cancel()
                        self?.catalogDebounce = Task { @MainActor [weak self] in
                            try? await Task.sleep(for: .seconds(2)); guard !Task.isCancelled else { return }
                            self?.refreshCatalog()
                        }
                    }
                }
                source.setCancelHandler { close(fd) }; source.resume(); watchers.append(source)
            }
        }
    }

    private func loadThumbnails() {
        thumbnailTask?.cancel()
        let files = assets.compactMap { asset in asset.thumbnailURL.map { (asset.url.path, $0) } }
        thumbnailTask = Task { [weak self] in
            let data = await Task.detached(priority: .utility) { files.compactMap { path, url in (try? Data(contentsOf: url)).map { (path, $0) } } }.value
            guard !Task.isCancelled, let self else { return }
            thumbnails = Dictionary(uniqueKeysWithValues: data.compactMap { path, data in NSImage(data: data).map { (path, $0) } })
        }
    }

    func screenID(_ screen: NSScreen) -> String {
        let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() {
            return CFUUIDCreateString(nil, uuid) as String
        }
        return "display-\(id)"
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, action: @escaping @MainActor (WallpaperController) -> Void) {
        observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in if let self { action(self) } }
        })
    }

    func refreshCatalog() {
        scanTask?.cancel()
        scanning = true
        let roots = AssetCatalog.defaultRoots + extraRoots
        let files = explicitFiles + selections.values.map { URL(fileURLWithPath: $0) }
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) { AssetCatalog.scan(roots: roots, explicitFiles: files) }.value
            guard !Task.isCancelled, let self else { return }
            assets = result.assets
            failedPaths = failedPaths.filter { path in assets.contains { $0.url.path == path } }
            loadThumbnails()
            for warning in result.warnings { addWarning(warning) }
            installWatchers()
            scanning = false
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Ordner hinzufügen"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !extraRoots.contains(url) { extraRoots.append(url) }
        defaults.set(extraRoots.map(\.path), forKey: "extraRoots")
        persistSettings()
        refreshCatalog(); installWatchers()
    }

    func chooseFile(for screen: NSScreen? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "Video verwenden"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !explicitFiles.contains(url) { explicitFiles.append(url) }
        defaults.set(explicitFiles.map(\.path), forKey: "explicitFiles")
        persistSettings()
        if !assets.contains(where: { $0.url == url }) { assets.append(VideoAsset(url: url)) }
        if let screen { select(url.path, for: screen) }
        else { for display in screens { select(url.path, for: display) } }
    }

    func selectForTarget(_ path: String, target: String) {
        for screen in screens where target.isEmpty || screenID(screen) == target {
            select(path, for: screen)
        }
    }

    func isSelected(_ asset: VideoAsset, target: String) -> Bool {
        let displays = screens.filter { target.isEmpty || screenID($0) == target }
        return !displays.isEmpty && displays.allSatisfy { selections[screenID($0)] == asset.url.path }
    }

    func currentName(target: String) -> String {
        let paths = Set(screens.filter { target.isEmpty || screenID($0) == target }.map { selections[screenID($0)] ?? "" })
        if paths.isEmpty || paths == [""] { return "macOS-Hintergrund" }
        if paths.count > 1 { return "Verschiedene Hintergründe" }
        let path = paths.first!
        return assets.first { $0.url.path == path }?.name ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }

    func openAppleSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!)
    }

    func select(_ path: String, for screen: NSScreen) {
        let id = screenID(screen)
        if !path.isEmpty && !FileManager.default.isReadableFile(atPath: path) {
            surfaceStates[id] = .failed("Video fehlt oder ist nicht lesbar")
            addWarning("Video fehlt oder ist nicht lesbar: " + path); updateStatus(); return
        }
        failedPaths.remove(path)
        surfaces[id]?.crossfade = crossfade
        selections[id] = path.isEmpty ? nil : path
        defaults.set(selections, forKey: "displaySelections")
        persistSettings()
        if path.isEmpty { surfaces[id]?.stop() }
        else { surfaces[id]?.load(URL(fileURLWithPath: path)) }
        applySelection(to: screen)
        updatePlayback()
    }

    private func applySelection(to screen: NSScreen) {
        let id = screenID(screen)
        guard let surface = surfaces[id] else { return }
        guard let path = selections[id], FileManager.default.isReadableFile(atPath: path) else {
            surface.stop()
            if let path = selections[id] { surfaceStates[id] = .failed("Video fehlt oder ist nicht lesbar"); addWarning("Video fehlt oder ist nicht lesbar: " + path) }
            return
        }
        let url = URL(fileURLWithPath: path)
        if surface.url != url { surface.load(url) }
    }

    func reconcileScreens() {
        screens = NSScreen.screens
        // UI fixtures must never create desktop overlay windows.
        guard !CommandLine.arguments.contains("--ui-preview") else { return }
        let active = Set(screens.map(screenID))
        if !targetDisplayID.isEmpty && !active.contains(targetDisplayID) { targetDisplayID = "" }
        for id in Array(surfaces.keys) where !active.contains(id) {
            surfaces.removeValue(forKey: id)?.stop()
            surfaceStates.removeValue(forKey: id)
        }
        for screen in screens {
            let id = screenID(screen)
            if surfaces[id] == nil {
                let surface = DesktopSurface(screen: screen)
                surface.onFailure = { [weak self, weak surface] message in
                    guard let self else { return }
                    if let path = surface?.url?.path { failedPaths.insert(path) }
                    addWarning(message)
                    if rotationEnabled { advanceRotation() }
                }
                surface.onStateChange = { [weak self] state in
                    self?.surfaceStates[id] = state
                    self?.updateStatus()
                }
                surfaces[id] = surface
            }
            surfaces[id]?.resize(to: screen)
            applySelection(to: screen)
        }
        updatePlayback()
    }

    func updatePlayback() {
        let info = ProcessInfo.processInfo
        let thermalBlocked = info.thermalState == .serious || info.thermalState == .critical
        let lowPower = (pauseOnLowPower && info.isLowPowerModeEnabled) || (pauseOnBattery && onBattery)
        let sleeping = !inactiveReasons.isEmpty
        let play = PlaybackPolicy.shouldPlay(manualPause: manualPause, sleeping: sleeping, lowPower: lowPower, thermalBlocked: thermalBlocked)
        for surface in surfaces.values { surface.setPlaying(play) }
        updateStatus()
    }

    private func updateStatus() {
        let info = ProcessInfo.processInfo
        let thermalBlocked = info.thermalState == .serious || info.thermalState == .critical
        let lowPower = (pauseOnLowPower && info.isLowPowerModeEnabled) || (pauseOnBattery && onBattery)
        let sleeping = !inactiveReasons.isEmpty
        if manualPause { status = "Manuell pausiert" }
        else if sleeping { status = "Bildschirm / Sitzung inaktiv" }
        else if thermalBlocked { status = "Pausiert: thermische Belastung" }
        else if lowPower { status = "Pausiert: Stromsparmodus" }
        else if surfaceStates.values.contains(where: { if case .failed = $0 { return true }; return false }) { status = "Video fehlgeschlagen – erneut versuchen oder wechseln" }
        else if surfaceStates.values.contains(.loading) { status = "Video wird geladen …" }
        else { status = surfaceStates.values.contains(.playing) ? "Wiedergabe läuft" : "Video auswählen" }
    }

    func shutdown() {
        scanTask?.cancel(); thumbnailTask?.cancel(); catalogDebounce?.cancel()
        for watcher in watchers { watcher.cancel() }; watchers.removeAll()
        rotationTimer?.invalidate()
        for token in observers { NotificationCenter.default.removeObserver(token) }
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        for surface in surfaces.values { surface.stop() }
        surfaces.removeAll()
    }
}
