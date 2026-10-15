import AppKit
import Foundation
import CoreVideo

// Compile together with the UniversalPiP sources: an isolated test host, not a product launch mode.
@main struct PiPCaptureProbe {
    @MainActor static func main() {
        guard CommandLine.arguments.count >= 3 else { return }
        let app = NSApplication.shared
        let delegate = ProbeDelegate(); app.delegate = delegate; app.setActivationPolicy(.regular); withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor private final class ProbeDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PiPSessionCoordinator()
    private let panel = PiPPanelController(defaults: UserDefaults(suiteName: "tech.highbyte.UniversalPiPProbe.settings") ?? .standard)
    private var frames = 0
    private var distinctFrames = 0
    private var previousFingerprint: UInt64?
    private var firstFrame: Date?
    private var started = Date()
    private var lastFrame: Date?
    private var frameSize = CGSize.zero
    private var states: [String] = []
    private var timer: Timer?
    private var ending = false
    private var reportURL: URL { URL(fileURLWithPath: CommandLine.arguments[2]) }
    private var duration: Double { CommandLine.arguments.count > 3 ? Double(CommandLine.arguments[3]) ?? 30 : 30 }
    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.onFrame = { [weak self] frame in
            guard let self else { return }
            self.frames += 1; self.lastFrame = Date(); if self.firstFrame == nil { self.firstFrame = Date() }
            self.frameSize = frame.size; self.panel.preview.display(frame)
            // Sparse in-memory fingerprint distinguishes moving content from repeated buffers. Never persisted as image data.
            CVPixelBufferLockBaseAddress(frame.pixelBuffer, .readOnly)
            if let base = CVPixelBufferGetBaseAddress(frame.pixelBuffer) {
                let count = CVPixelBufferGetBytesPerRow(frame.pixelBuffer) * CVPixelBufferGetHeight(frame.pixelBuffer)
                let bytes = base.assumingMemoryBound(to: UInt8.self)
                var fingerprint: UInt64 = 1469598103934665603
                for offset in stride(from: 0, to: count, by: max(1, count / 4096)) { fingerprint = (fingerprint ^ UInt64(bytes[offset])) &* 1099511628211 }
                if self.previousFingerprint != fingerprint { self.distinctFrames += 1 }; self.previousFingerprint = fingerprint
            }
            CVPixelBufferUnlockBaseAddress(frame.pixelBuffer, .readOnly)
        }
        coordinator.onStateChange = { [weak self] state in
            self?.states.append(String(describing: state)); self?.panel.setState(state)
        }
        panel.onResize = { [weak self] size, scale in self?.coordinator.updateTarget(size: size, scale: scale) }
        panel.onPause = { [weak self] in
            guard let self else { return }
            if self.coordinator.isEnabled { self.coordinator.pause() } else { self.coordinator.resume() }
        }
        panel.onClose = { [weak self] in self?.finish() }
        Task { @MainActor [self] in
            do {
                let matches = try await coordinator.windows().filter { $0.appName.localizedCaseInsensitiveContains("UTM") && $0.title == CommandLine.arguments[1] }
                guard matches.count == 1, let source = matches.first else { states.append("source-not-unique-or-missing"); finish(); return }
                panel.show(source: source); coordinator.start(source)
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.tick() }
                }
                tick()
            } catch { states.append("source-query-failed"); finish() }
        }
    }
    private func tick() {
        writeReport(done: false)
        if Date().timeIntervalSince(started) >= duration { finish() }
    }
    private func writeReport(done: Bool) {
        let frameWindow = NSApp.windows.first { $0.title == "UniversalPiP – Live-Vorschau" }
        let report: [String: Any] = ["done": done, "elapsedSeconds": Date().timeIntervalSince(started), "frames": frames,
            "distinctFrames": distinctFrames, "state": String(describing: coordinator.state), "states": states,
            "firstFrameSeconds": firstFrame.map { $0.timeIntervalSince(started) } ?? -1,
            "lastFrameAgeSeconds": lastFrame.map { Date().timeIntervalSince($0) } ?? -1,
            "frameWidth": frameSize.width, "frameHeight": frameSize.height,
            "panelWindowID": frameWindow?.windowNumber ?? -1,
            "panelVisible": frameWindow?.isVisible ?? false, "panelKey": frameWindow?.isKeyWindow ?? false,
            "screenPermission": CGPreflightScreenCaptureAccess()]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) { try? data.write(to: reportURL, options: .atomic) }
    }
    private func finish() {
        guard !ending else { return }; ending = true; timer?.invalidate(); coordinator.stop(); panel.dispose()
        Task { @MainActor in await coordinator.waitForOperations(); writeReport(done: true); NSApp.terminate(nil) }
    }
}
