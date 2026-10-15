import AppKit
import MacFitKitPlatform
@preconcurrency import ApplicationServices
import Observation
import OSLog
import ScreenCaptureKit

@MainActor
@Observable
final class DockPreviewController {
    var accessibilityGranted = false
    var screenRecordingGranted = false
    var requestingScreenRecording = false
    var screenRecordingMessage = ""
    var enabled = true
    var status = "DockPreview wird gestartet …"
    var lastAction = ""

    @ObservationIgnored private var captureAccessVerified = false
    @ObservationIgnored private var permissionTask: Task<Void, Never>?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var activationTask: Task<Void, Never>?
    @ObservationIgnored private var candidate: AccessibilityReader.DockTarget?
    @ObservationIgnored private var candidateSince = Date.distantPast
    @ObservationIgnored private var outsideSince: Date?
    @ObservationIgnored private var suppressedPID: pid_t?
    @ObservationIgnored private var permissionChecked = Date.distantPast
    @ObservationIgnored private let content = PreviewContent()
    @ObservationIgnored private var panel: PreviewPanel?
    @ObservationIgnored private let logger = Logger(subsystem: "tech.highbyte.macfitkit.DockPreview", category: "preview")

    func start() {
        refreshPermissions()
        timer?.invalidate()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        permissionTask?.cancel()
        permissionTask = nil
        activationTask?.cancel()
        activationTask = nil
        dismiss()
    }

    func refreshPermissions() {
        accessibilityGranted = PrivacyAccess.accessibilityGranted
        screenRecordingGranted = PrivacyAccess.screenRecordingGranted || captureAccessVerified
        permissionChecked = Date()
        status = !accessibilityGranted ? "Bitte Bedienungshilfen freigeben." :
            !screenRecordingGranted ? "Fensterauswahl bereit. Für Miniaturen fehlt die Bildschirmaufnahme." :
            enabled ? "Bereit – bewege den Zeiger über ein App-Symbol im Dock." : "Vorschauen pausiert."
    }

    func requestAccessibility() {
        PrivacyAccess.requestAccessibility()
    }

    func requestScreenRecording() {
        guard !requestingScreenRecording else { return }
        requestingScreenRecording = true
        screenRecordingMessage = "macOS-Freigabe wird angefragt …"
        permissionTask = Task { [weak self] in
            guard let self else { return }
            defer { self.requestingScreenRecording = false; self.permissionTask = nil }
            do {
                // Query the same API used for thumbnails. Merely opening Settings does not register access.
                try await PrivacyAccess.requestScreenRecording()
                guard !Task.isCancelled else { return }
                self.captureAccessVerified = true
                self.refreshPermissions()
                self.screenRecordingMessage = "Bildschirmzugriff erfolgreich geprüft."
                self.logger.info("ScreenCaptureKit permission query succeeded")
            } catch {
                guard !Task.isCancelled else { return }
                self.captureAccessVerified = false
                self.refreshPermissions()
                self.screenRecordingMessage = "Bitte DockPreview in den Systemeinstellungen freigeben und danach neu starten. Fehlt der Eintrag, die aktuelle App über + hinzufügen."
                self.logger.error("ScreenCaptureKit permission query failed: \(error.localizedDescription, privacy: .public)")
                self.openPrivacyPane("Privacy_ScreenCapture")
            }
        }
    }

    func showCurrentApp() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    func showScreenRecordingSettings() {
        openPrivacyPane("Privacy_ScreenCapture")
    }

    private func openPrivacyPane(_ pane: String) {
        PrivacyAccess.openSettings(pane)
    }

    private func tick() {
        if Date().timeIntervalSince(permissionChecked) > 2 { refreshPermissions() }
        guard enabled, accessibilityGranted else {
            if panel?.isVisible == true || candidate != nil { dismiss(); candidate = nil }
            return
        }
        guard NSEvent.pressedMouseButtons == 0 else { return }
        let mouse = NSEvent.mouseLocation
        // A non-activating panel must remain interactive while the pointer crosses the gap.
        if let panel, panel.isVisible, let candidate {
            let bridge = PreviewGeometry.bridge(icon: candidate.icon, panel: panel.frame,
                                                edge: candidate.edge)
            if panel.frame.contains(mouse) || bridge.contains(mouse) {
                outsideSince = nil
                return
            }
        }
        if let target = AccessibilityReader.dockTarget(at: mouse) {
            outsideSince = nil
            if target.app.processIdentifier == suppressedPID { return }
            suppressedPID = nil
            if candidate?.app.processIdentifier != target.app.processIdentifier {
                dismiss()
                candidate = target
                candidateSince = Date()
            } else {
                candidate = target // Dock magnification can change the icon bounds.
            }
            if panel?.isVisible != true, loadTask == nil, Date().timeIntervalSince(candidateSince) >= 0.35 {
                show(target)
            } else if panel?.isVisible == true {
                positionPanel(target)
            }
        } else {
            suppressedPID = nil
            if outsideSince == nil { outsideSince = Date() }
            if Date().timeIntervalSince(outsideSince!) > 0.28 {
                dismiss()
                candidate = nil
            }
        }
    }

    private func show(_ target: AccessibilityReader.DockTarget) {
        let windows = AccessibilityReader.windows(for: target.app)
        content.appName = target.app.localizedName ?? "App"
        content.icon = target.app.icon
        content.items = windows.map { .init(window: $0, unavailable: !screenRecordingGranted) }
        content.message = windows.isEmpty ? "Keine zugänglichen Fenster geöffnet." :
            !screenRecordingGranted ? "Für Miniaturen bitte Bildschirmaufnahme freigeben." : nil
        content.select = { [weak self] window in self?.select(window, app: target.app) }
        if panel == nil { panel = PreviewPanel(content: content) }
        positionPanel(target)
        panel?.orderFrontRegardless()
        logger.info("Preview shown for PID \(target.app.processIdentifier), windows: \(windows.count)")
        guard screenRecordingGranted, !windows.isEmpty else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            await self.captureThumbnails(for: target.app, windows: windows)
            if !Task.isCancelled { self.loadTask = nil }
        }
    }

    private func positionPanel(_ target: AccessibilityReader.DockTarget) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(target.icon.center) }) else { return }
        let width = max(290, CGFloat(content.items.count) * 240 + 24)
        let size = CGSize(width: min(width, screen.visibleFrame.width - 24),
                          height: content.items.isEmpty ? 90 : content.message == nil ? 250 : 275)
        panel?.setFrame(PreviewGeometry.panelFrame(icon: target.icon, screen: screen.frame,
                                                visible: screen.visibleFrame, size: size, edge: target.edge), display: true)
    }

    private func captureThumbnails(for app: NSRunningApplication, windows: [AccessibilityReader.AppWindow]) async {
        do {
            let shareable = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            guard !Task.isCancelled else { return }
            let available = shareable.windows.filter {
                $0.owningApplication?.processID == app.processIdentifier && $0.windowLayer == 0
            }
            var unused = available
            for window in windows {
                guard !Task.isCancelled else { return }
                guard !window.minimized,
                      let id = WindowMatching.match(title: window.title, frame: window.frame, candidates: unused.map {
                          WindowDescriptor(id: Int($0.windowID), title: $0.title ?? "", frame: $0.frame)
                      }), let capturedWindow = unused.first(where: { Int($0.windowID) == id }) else {
                    markUnavailable(window.id)
                    continue
                }
                unused.removeAll { Int($0.windowID) == id }
                let config = SCStreamConfiguration()
                let scale = min(440 / max(capturedWindow.frame.width, 1), 280 / max(capturedWindow.frame.height, 1))
                config.width = max(1, Int(capturedWindow.frame.width * scale))
                config.height = max(1, Int(capturedWindow.frame.height * scale))
                config.showsCursor = false
                config.captureResolution = .nominal
                config.ignoreShadowsSingleWindow = true
                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: SCContentFilter(desktopIndependentWindow: capturedWindow), configuration: config)
                    guard !Task.isCancelled else { return }
                    if let index = content.items.firstIndex(where: { $0.id == window.id }) {
                        content.items[index].image = NSImage(cgImage: image, size: .zero)
                    }
                } catch {
                    guard !Task.isCancelled else { return }
                    markUnavailable(window.id)
                    logger.error("Thumbnail capture failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            captureAccessVerified = false
            refreshPermissions()
            for window in windows { markUnavailable(window.id) }
            content.message = "Miniaturen nicht verfügbar. Bildschirmaufnahme prüfen; Auswahl bleibt möglich."
            if let candidate { positionPanel(candidate) }
            logger.error("Window capture enumeration failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func markUnavailable(_ id: Int) {
        if let index = content.items.firstIndex(where: { $0.id == id }) { content.items[index].unavailable = true }
    }

    private func select(_ window: AccessibilityReader.AppWindow, app: NSRunningApplication) {
        suppressedPID = app.processIdentifier
        dismiss()
        candidate = nil
        activationTask?.cancel()
        activationTask = Task {
            let succeeded = await AccessibilityReader.raise(window, in: app)
            guard !Task.isCancelled else { return }
            lastAction = succeeded ? "Fenster in den Vordergrund geholt." : "Das Fenster konnte nicht aktiviert werden. Bitte erneut versuchen."
            logger.info("Window activation for PID \(app.processIdentifier), verified: \(succeeded)")
        }
    }

    private func dismiss() {
        loadTask?.cancel()
        loadTask = nil
        panel?.orderOut(nil)
        content.items = [] // Do not retain window images when the preview is closed.
        content.select = nil
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
