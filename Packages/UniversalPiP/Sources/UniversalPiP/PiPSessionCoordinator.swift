import AppKit
import Observation
import OSLog

@MainActor @Observable public final class PiPSessionCoordinator {
    public private(set) var state: PiPState = .ready
    public private(set) var source: WindowSource?
    public private(set) var message = ""
    public var onFrame: ((CapturedFrame) -> Void)?
    public var onStateChange: ((PiPState) -> Void)?
    public var targetSize = CGSize(width: 400, height: 250)
    public var backingScale: CGFloat = 2
    @ObservationIgnored private let provider: any WindowSourceProviding
    @ObservationIgnored private let permitted: @MainActor () -> Bool
    @ObservationIgnored private let factory: @MainActor () -> any PiPCapturing
    @ObservationIgnored private var capture: (any PiPCapturing)?
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var resizeTask: Task<Void, Never>?
    @ObservationIgnored private var monitor: Task<Void, Never>?
    @ObservationIgnored private var firstFrameDeadline: Task<Void, Never>?
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private var receivedFrame = false
    @ObservationIgnored private var resumeAfterWake = false
    @ObservationIgnored private let monitoring: Bool
    @ObservationIgnored private let monitorInterval: Duration
    @ObservationIgnored private let firstFrameTimeout: Duration
    @ObservationIgnored private let logger = Logger(subsystem: "tech.highbyte.macfitkit.UniversalPiP", category: "session")
    public var isEnabled: Bool { state == .live || state == .starting || state == .unavailable }
    public init(provider: any WindowSourceProviding = WindowSourceProvider(),
                permission: @escaping @MainActor () -> Bool = { CGPreflightScreenCaptureAccess() },
                monitoring: Bool = true, monitorInterval: Duration = .seconds(2), firstFrameTimeout: Duration = .seconds(5),
                factory: @escaping @MainActor () -> any PiPCapturing = { CaptureSession() }) {
        self.provider = provider; permitted = permission; self.monitoring = monitoring; self.factory = factory
        self.monitorInterval = monitorInterval; self.firstFrameTimeout = firstFrameTimeout
    }
    public func windows() async throws -> [WindowSource] { try await provider.windows() }
    private func transition(_ state: PiPState, _ message: String = "") {
        self.state = state; self.message = message
        logger.info("Session state: \(String(describing: state), privacy: .public)")
        onStateChange?(state)
    }
    private func invalidate() -> UInt64 {
        generation &+= 1; resizeTask?.cancel(); monitor?.cancel(); firstFrameDeadline?.cancel()
        resizeTask = nil; monitor = nil; firstFrameDeadline = nil
        return generation
    }
    // All stream mutations are serial, including startCapture calls suspended in the OS.
    private func enqueue(_ action: @escaping @MainActor (PiPSessionCoordinator) async -> Void) {
        let previous = operation
        operation = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            await action(self)
        }
    }
    private func stopCapture() async { let old = capture; capture = nil; await old?.stop() }
    public func start(_ selected: WindowSource) {
        resumeAfterWake = false
        let token = invalidate(); source = selected; receivedFrame = false
        transition(.starting)
        enqueue { owner in
            await owner.stopCapture()
            guard owner.generation == token else { return }
            guard owner.permitted() else { owner.transition(.permissionRequired); return }
            do {
                let windows = try await owner.provider.windows()
                guard owner.generation == token else { return }
                guard let current = windows.first(where: { $0.id == selected.id && $0.processID == selected.processID }) else {
                    owner.transition(.ended); return
                }
                owner.source = current
                let capture = owner.factory(); owner.capture = capture
                try await capture.start(source: current, size: owner.outputSize) { [weak owner] event in
                    guard let owner, owner.generation == token else { return }
                    owner.handle(event)
                }
                guard owner.generation == token else { await owner.stopCapture(); return }
                owner.beginMonitoring(token)
            } catch {
                guard owner.generation == token else { return }
                await owner.stopCapture()
                if !owner.permitted() { owner.transition(.permissionRequired) }
                else if error is CaptureFailure { owner.transition(.ended) }
                else { owner.transition(.failed, "Capture konnte nicht starten. Freigabe prüfen; nach einer neuen Freigabe die App gegebenenfalls neu starten.") }
            }
        }
    }
    public func pause() { resumeAfterWake = false; suspend(as: .paused) }
    public func resume() { if let source { start(source) } }
    public func stop() {
        resumeAfterWake = false; _ = invalidate(); source = nil
        transition(.ready); enqueue { await $0.stopCapture() }
    }
    private func suspend(as state: PiPState) {
        _ = invalidate(); transition(state); enqueue { await $0.stopCapture() }
    }
    public func willSleep() { resumeAfterWake = isEnabled; if resumeAfterWake { suspend(as: .unavailable) } }
    public func didWake() {
        guard resumeAfterWake, let source else { return }
        resumeAfterWake = false; start(source)
    }
    public func waitForOperations() async { await operation?.value }
    private var outputSize: CGSize {
        let native = source.map { CGSize(width: $0.frame.width * $0.pixelScale, height: $0.frame.height * $0.pixelScale) } ?? targetSize
        return PiPGeometry.outputSize(source: native, target: targetSize, scale: backingScale)
    }
    public func updateTarget(size: CGSize, scale: CGFloat) {
        targetSize = size; backingScale = scale
        guard isEnabled else { return }
        let token = generation
        resizeTask?.cancel()
        resizeTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            guard let self, self.generation == token else { return }
            self.enqueue { owner in
                guard owner.generation == token else { return }
                do { try await owner.capture?.resize(owner.outputSize) }
                catch { if owner.generation == token { owner.terminate(.failed) } }
            }
        }
    }
    private func handle(_ event: CaptureEvent) {
        switch event {
        case .frame(let frame):
            receivedFrame = true
            if state != .live { transition(.live) }
            onFrame?(frame)
        case .idle: break // No image change is a healthy stream, not a timeout.
        case .unavailable: transition(.unavailable)
        case .ended: terminate(.ended)
        case .failure: terminate(permitted() ? .failed : .permissionRequired)
        }
    }
    private func terminate(_ state: PiPState) { _ = invalidate(); transition(state); enqueue { await $0.stopCapture() } }
    private func beginMonitoring(_ token: UInt64) {
        guard monitoring else { return }
        let timeout = firstFrameTimeout, interval = monitorInterval
        firstFrameDeadline = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.generation == token, !self.receivedFrame else { return }
            self.transition(.unavailable)
        }
        monitor = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) } catch { return }
                guard let self, self.generation == token else { return }
                guard self.permitted() else { self.terminate(.permissionRequired); return }
                do {
                    let windows = try await self.provider.windows()
                    guard self.generation == token else { return }
                    guard let source = self.source, let current = windows.first(where: { $0.id == source.id && $0.processID == source.processID }) else {
                        self.terminate(.ended); return
                    }
                    if current.frame.size != source.frame.size || current.pixelScale != source.pixelScale {
                        self.source = current; self.updateTarget(size: self.targetSize, scale: self.backingScale)
                    }
                } catch {
                    guard self.generation == token else { return }
                    self.terminate(self.permitted() ? .failed : .permissionRequired); return
                }
            }
        }
    }
}
