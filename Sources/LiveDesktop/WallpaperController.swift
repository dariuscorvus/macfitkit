import AppKit
import SwiftUI
import AVFoundation
import ServiceManagement
import LiveDesktopCore

@MainActor
final class WallpaperController: ObservableObject {
    static let shared = WallpaperController(ephemeral: CommandLine.arguments.contains("--probe"))
    @Published var searchQuery = ""
    @Published var targetDisplayID = ""
    @Published var assets: [VideoAsset] = []
    @Published var warnings: [String] = []
    @Published var screens: [NSScreen] = []
    @Published var selections: [String: String] = [:]
    @Published var manualPause = false { didSet { updatePlayback() } }
    @Published var pauseOnLowPower = true { didSet { updatePlayback() } }
    @Published var status = "Video auswählen"
    @Published var scanning = false
    @Published var loginEnabled = false
    @Published var loginNeedsApproval = false
    @Published var loginMessage = ""
    @Published var rotationEnabled = false { didSet { persistRotation(); scheduleRotation() } }
    @Published var rotationMinutes = 15 { didSet { persistRotation(); scheduleRotation() } }
    @Published var rotationPaths: [String] = [] { didSet { persistRotation(); scheduleRotation() } }
    private var settingsLoaded = false
    private var rotationTimer: Timer?
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
            selections = defaults.dictionary(forKey: "displaySelections") as? [String: String] ?? [:]
            extraRoots = (defaults.stringArray(forKey: "extraRoots") ?? []).map { URL(fileURLWithPath: $0) }
            explicitFiles = (defaults.stringArray(forKey: "explicitFiles") ?? []).map { URL(fileURLWithPath: $0) }
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
        settingsLoaded = !ephemeral
        reconcileScreens()
        if !ephemeral { refreshCatalog(); refreshLoginStatus(); scheduleRotation() }
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
    }

    func toggleRotationAsset(_ path: String) {
        if rotationPaths.contains(path) { rotationPaths.removeAll { $0 == path } }
        else { rotationPaths.append(path) }
    }

    private func scheduleRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
        guard settingsLoaded, rotationEnabled, rotationPaths.count >= 2 else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: Double(max(1, rotationMinutes)) * 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceRotation() }
        }
        rotationTimer?.tolerance = 5
    }

    func advanceRotation() {
        guard !manualPause, inactiveReasons.isEmpty,
              !(pauseOnLowPower && ProcessInfo.processInfo.isLowPowerModeEnabled),
              ProcessInfo.processInfo.thermalState != .serious,
              ProcessInfo.processInfo.thermalState != .critical else { return }
        let available = rotationPaths.filter { path in
            assets.contains { $0.url.path == path } && FileManager.default.isReadableFile(atPath: path)
        }
        guard available.count >= 2 else { return }
        for screen in screens {
            let id = screenID(screen)
            guard let current = selections[id] else { continue }
            if let next = RotationSequence.next(current: current, paths: available) { select(next, for: screen) }
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
            warnings = result.warnings
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
        refreshCatalog()
    }

    func chooseFile(for screen: NSScreen? = nil) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "Video verwenden"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !explicitFiles.contains(url) { explicitFiles.append(url) }
        defaults.set(explicitFiles.map(\.path), forKey: "explicitFiles")
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
        selections[id] = path.isEmpty ? nil : path
        defaults.set(selections, forKey: "displaySelections")
        surfaces[id]?.stop()
        applySelection(to: screen)
        updatePlayback()
    }

    private func applySelection(to screen: NSScreen) {
        let id = screenID(screen)
        guard let surface = surfaces[id] else { return }
        guard let path = selections[id], FileManager.default.isReadableFile(atPath: path) else {
            surface.stop()
            if selections[id] != nil { warnings.append("Video fehlt oder ist nicht lesbar: \(selections[id]!)") }
            return
        }
        let url = URL(fileURLWithPath: path)
        if surface.url != url { surface.load(url) }
    }

    func reconcileScreens() {
        screens = NSScreen.screens
        let active = Set(screens.map(screenID))
        if !targetDisplayID.isEmpty && !active.contains(targetDisplayID) { targetDisplayID = "" }
        for id in Array(surfaces.keys) where !active.contains(id) {
            surfaces.removeValue(forKey: id)?.stop()
        }
        for screen in screens {
            let id = screenID(screen)
            if surfaces[id] == nil {
                let surface = DesktopSurface(screen: screen)
                surface.onFailure = { [weak self] message in self?.warnings.append(message) }
                surfaces[id] = surface
            }
            surfaces[id]?.window.setFrame(screen.frame, display: true)
            applySelection(to: screen)
        }
        updatePlayback()
    }

    func updatePlayback() {
        let info = ProcessInfo.processInfo
        let thermalBlocked = info.thermalState == .serious || info.thermalState == .critical
        let lowPower = pauseOnLowPower && info.isLowPowerModeEnabled
        let sleeping = !inactiveReasons.isEmpty
        let play = PlaybackPolicy.shouldPlay(manualPause: manualPause, sleeping: sleeping, lowPower: lowPower, thermalBlocked: thermalBlocked)
        for surface in surfaces.values { surface.setPlaying(play) }
        if manualPause { status = "Manuell pausiert" }
        else if sleeping { status = "Bildschirm / Sitzung inaktiv" }
        else if thermalBlocked { status = "Pausiert: thermische Belastung" }
        else if lowPower { status = "Pausiert: Stromsparmodus" }
        else { status = surfaces.values.contains { $0.url != nil } ? "Wiedergabe aktiviert" : "Video auswählen" }
    }

    func shutdown() {
        scanTask?.cancel()
        rotationTimer?.invalidate()
        for token in observers { NotificationCenter.default.removeObserver(token) }
        for token in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
        for surface in surfaces.values { surface.stop() }
        surfaces.removeAll()
    }
}
