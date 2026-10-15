import AppKit
import CoreVideo
@preconcurrency import ApplicationServices
import Observation
import UniversalPiP
import MacFitKitPlatform

@MainActor @Observable final class PiPAppController {
    let session = PiPSessionCoordinator(permission: { PrivacyAccess.screenRecordingGranted })
    let panel = PiPPanelController()
    let isPreview = CommandLine.arguments.contains("--ui-preview")
    var sources: [WindowSource] = []
    var selectedID: UInt32?
    var permissionGranted = PrivacyAccess.screenRecordingGranted
    var focusPermissionGranted = PrivacyAccess.accessibilityGranted
    var loading = false
    var message = ""
    @ObservationIgnored var showSettings: (() -> Void)?
    @ObservationIgnored var hideSettings: (() -> Void)?
    @ObservationIgnored var statusChanged: (() -> Void)?
    @ObservationIgnored private var focusTask: Task<Void, Never>?
    @ObservationIgnored private var listing: Task<Void, Never>?
    @ObservationIgnored private var listGeneration = 0
    init() {
        session.onFrame = { [weak panel] frame in panel?.preview.display(frame) }
        session.onStateChange = { [weak self] state in self?.panel.setState(state); self?.statusChanged?() }
        panel.onPause = { [weak self] in
            guard let self else { return }
            if self.session.state == .paused || self.session.state == .unavailable || self.session.state == .failed { self.resume() }
            else { self.session.pause() }
        }
        panel.onFocusSource = { [weak self] in self?.focusOriginal() }
        panel.onChooseSource = { [weak self] in self?.focusTask?.cancel(); self?.showSettings?() }
        panel.onClose = { [weak self] in self?.focusTask?.cancel(); self?.session.stop() }
        panel.onResize = { [weak session] size, scale in session?.updateTarget(size: size, scale: scale) }
    }
    func refresh() {
        guard !isPreview else { return }
        permissionGranted = PrivacyAccess.screenRecordingGranted
        focusPermissionGranted = PrivacyAccess.accessibilityGranted
        listing?.cancel(); listGeneration += 1
        guard permissionGranted else { sources = []; selectedID = nil; loading = false; return }
        loading = true; let token = listGeneration
        listing = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let values = try await self.session.windows()
                guard !Task.isCancelled, self.listGeneration == token else { return }
                self.sources = values
                if !values.contains(where: { $0.id == self.selectedID }) { self.selectedID = values.first?.id }
            } catch {
                guard !Task.isCancelled, self.listGeneration == token else { return }
                self.sources = []; self.selectedID = nil
                self.message = "Fensterliste nicht verfügbar. Freigabe prüfen und nach einer neuen Freigabe UniversalPiP gegebenenfalls neu starten."
            }
            if self.listGeneration == token { self.loading = false }
        }
    }
    func requestPermission() {
        guard !isPreview else { return }
        Task { @MainActor in
            do { try await PrivacyAccess.requestScreenRecording(); message = "Freigabe anschließend erneut prüfen. Falls nötig, UniversalPiP beenden und neu öffnen." }
            catch { message = "Bildschirmaufnahme wurde nicht freigegeben. In den Systemeinstellungen erlauben und erneut prüfen." }
            let explanation = message
            refresh(); message = explanation
            if !permissionGranted { PrivacyAccess.openSettings("Privacy_ScreenCapture") }
        }
    }
    func startSelected() {
        guard !isPreview, let source = sources.first(where: { $0.id == selectedID }) else { return }
        focusTask?.cancel(); message = ""
        panel.show(source: source); session.start(source); hideSettings?()
    }
    func resume() {
        guard !isPreview else { return }
        if session.source != nil { session.resume() } else { showSettings?() }
    }
    func close() { focusTask?.cancel(); session.stop(); panel.close() }
    func requestFocusPermission() { guard !isPreview else { return }; PrivacyAccess.requestAccessibility() }
    func focusOriginal() {
        guard !isPreview, let selected = session.source else { return }
        guard PrivacyAccess.accessibilityGranted else {
            message = "Zum gezielten Fokussieren des Originalfensters ist die optionale Bedienungshilfen-Freigabe nötig. Die Live-Vorschau funktioniert auch ohne sie. Unter Berechtigungen freigeben und erneut versuchen."
            showSettings?(); return
        }
        focusTask?.cancel()
        focusTask = Task { @MainActor in
            do {
                let current = try await session.windows().first(where: { $0.id == selected.id && $0.processID == selected.processID })
                guard !Task.isCancelled, session.source?.id == selected.id, session.source?.processID == selected.processID else { return }
                let focused: Bool
                if let current { focused = await SourceWindowFocus.raise(current) } else { focused = false }
                guard !Task.isCancelled, session.source?.id == selected.id, session.source?.processID == selected.processID else { return }
                guard focused else {
                    message = "Das gewählte Originalfenster konnte nicht eindeutig fokussiert werden. Original wiederherstellen oder Quelle erneut auswählen."
                    showSettings?(); return
                }
                message = ""
            } catch { message = "Originalfenster nicht verfügbar. Quelle erneut prüfen."; showSettings?() }
        }
    }
}


@MainActor private enum SourceWindowFocus {
    static func value(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var result: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, key as CFString, &result) == .success ? result : nil
    }
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
    static func raise(_ source: WindowSource) async -> Bool {
        guard let app = NSRunningApplication(processIdentifier: source.processID), !app.isTerminated else { return false }
        let application = AXUIElementCreateApplication(source.processID)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let windows = value(application, kAXWindowsAttribute) as? [AXUIElement] else { return false }
        let pairs = windows.compactMap { window -> (AXUIElement, WindowFocusCandidate)? in
            guard let frame = frame(window) else { return nil }
            return (window, WindowFocusCandidate(title: value(window, kAXTitleAttribute) as? String ?? "", frame: frame))
        }
        guard let index = WindowFocusCandidate.uniqueMatch(source: source, candidates: pairs.map { $0.1 }) else { return false }
        guard !Task.isCancelled else { return false }
        let window = pairs[index].0
        var pid: pid_t = 0
        guard AXUIElementGetPid(window, &pid) == .success, pid == source.processID else { return false }
        if value(window, kAXMinimizedAttribute) as? Bool == true {
            guard AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else { return false }
        }
        app.unhide(); app.activate(options: [])
        for _ in 0..<10 {
            guard !Task.isCancelled else { return false }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !Task.isCancelled else { return false }
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(application, kAXFocusedWindowAttribute as CFString, window)
        guard AXUIElementPerformAction(window, kAXRaiseAction as CFString) == .success else { return false }
        for _ in 0..<10 {
            guard !Task.isCancelled else { return false }
            if let focused = value(application, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID(),
               CFEqual(focused, window), NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return false
    }
}

#if DEBUG
// Explicit developer-only acceptance mode; normal launches never select or capture a source.
@MainActor final class DebugCaptureProbe {
    private let controller: PiPAppController
    private let report: URL
    private var timer: Timer?
    private var frames = 0
    private var distinct = 0
    private var fingerprint: UInt64?
    private let started = Date()
    private var firstFrame: Date?
    private var lastFrame: Date?
    private var size = CGSize.zero
    private var pixelSize = CGSize.zero
    private var scales = CGSize.zero
    private var finished = false
    init(controller: PiPAppController, title: String, report: URL, seconds: Double) {
        self.controller = controller; self.report = report
        let display = controller.session.onFrame
        controller.session.onFrame = { [weak self] frame in
            display?(frame)
            guard let self, !self.finished else { return }
            self.frames += 1; self.lastFrame = Date(); self.firstFrame = self.firstFrame ?? Date(); self.size = frame.size
            self.pixelSize = CGSize(width: CVPixelBufferGetWidth(frame.pixelBuffer), height: CVPixelBufferGetHeight(frame.pixelBuffer))
            self.scales = CGSize(width: frame.scaleFactor, height: frame.contentScale)
            CVPixelBufferLockBaseAddress(frame.pixelBuffer, .readOnly)
            if let base = CVPixelBufferGetBaseAddress(frame.pixelBuffer) {
                let count = CVPixelBufferGetBytesPerRow(frame.pixelBuffer) * CVPixelBufferGetHeight(frame.pixelBuffer)
                let bytes = base.assumingMemoryBound(to: UInt8.self); var hash: UInt64 = 1469598103934665603
                for i in stride(from: 0, to: count, by: max(1, count / 4096)) { hash = (hash ^ UInt64(bytes[i])) &* 1099511628211 }
                if self.fingerprint != hash { self.distinct += 1 }; self.fingerprint = hash
            }
            CVPixelBufferUnlockBaseAddress(frame.pixelBuffer, .readOnly)
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let matches = try await controller.session.windows().filter { $0.appName.localizedCaseInsensitiveContains("UTM") && $0.title == title }
                guard matches.count == 1, let source = matches.first else { self.write(done: true, error: "source-not-unique-or-missing"); return }
                controller.panel.show(source: source); controller.session.start(source); controller.hideSettings?()
                self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        if Date().timeIntervalSince(self.started) >= seconds {
                            self.timer?.invalidate(); self.finished = true
                            let keepRunning = CommandLine.arguments.contains("--capture-probe-keep-running")
                            if !keepRunning { controller.close(); await controller.session.waitForOperations() }
                            self.write(done: true)
                            if !keepRunning { controller.showSettings?() }
                        } else { self.write(done: false) }
                    }
                }
                self.write(done: false)
            } catch { self.write(done: true, error: "source-query-failed") }
        }
    }
    private func write(done: Bool, error: String = "") {
        let window = NSApp.windows.first { $0.title == "UniversalPiP – Live-Vorschau" }
        let value: [String: Any] = ["done": done, "error": error, "elapsedSeconds": Date().timeIntervalSince(started),
            "frames": frames, "distinctFrames": distinct, "state": String(describing: controller.session.state),
            "firstFrameSeconds": firstFrame.map { $0.timeIntervalSince(started) } ?? -1,
            "lastFrameAgeSeconds": lastFrame.map { Date().timeIntervalSince($0) } ?? -1,
            "frameWidth": size.width, "frameHeight": size.height,
            "pixelWidth": pixelSize.width, "pixelHeight": pixelSize.height, "scaleFactor": scales.width, "contentScale": scales.height,
            "panelWindowID": window?.windowNumber ?? -1, "panelVisible": window?.isVisible ?? false,
            "panelKey": window?.isKeyWindow ?? false, "screenPermission": PrivacyAccess.screenRecordingGranted,
            "focusPermission": PrivacyAccess.accessibilityGranted, "captureContinuesAfterProbe": done && controller.session.isEnabled]
        if let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: report, options: .atomic) }
    }
}
#endif
