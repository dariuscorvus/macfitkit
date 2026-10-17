import Testing
import AppKit
import CoreVideo
@testable import UniversalPiP

@Test func completeImageStaysInsideBounds() {
    for source in [CGSize(width: 1920, height: 1080), CGSize(width: 800, height: 1200), CGSize(width: 529, height: 800)] {
        for width: CGFloat in [240, 400, 800] {
            let bounds = CGRect(x: 10, y: 20, width: width, height: 220)
            let result = PiPGeometry.aspectFit(source, in: bounds)
            #expect(bounds.insetBy(dx: -0.000001, dy: -0.000001).contains(result))
            #expect(abs(result.width / result.height - source.width / source.height) < 0.0001)
            #expect(abs(result.midX - bounds.midX) < 0.0001)
            #expect(abs(result.midY - bounds.midY) < 0.0001)
        }
    }
}
@Test func retinaResolutionIsBoundedAndProportional() {
    let result = PiPGeometry.outputSize(source: CGSize(width: 1600, height: 1000), target: CGSize(width: 400, height: 250), scale: 2)
    #expect(result == CGSize(width: 800, height: 500))
    #expect(PiPGeometry.outputSize(source: CGSize(width: 640, height: 480), target: CGSize(width: 4000, height: 3000), scale: 2) == CGSize(width: 640, height: 480))
}
@Test func monitorRemovalAndNegativeCoordinates() {
    let left = CGRect(x: -1920, y: -200, width: 1920, height: 1080)
    let main = CGRect(x: 0, y: 0, width: 1440, height: 850)
    let frame = CGRect(x: -1700, y: 0, width: 400, height: 300)
    #expect(PiPGeometry.visibleFrame(frame, screens: [left, main]) == frame)
    #expect(main.contains(PiPGeometry.visibleFrame(frame, screens: [main])))
    #expect(main.contains(PiPGeometry.visibleFrame(CGRect(x: 10000, y: 10000, width: 9000, height: 9000), screens: [main])))
}

@MainActor private final class SourceList: WindowSourceProviding {
    var values: [WindowSource] = [first, second]
    func windows() async throws -> [WindowSource] { values }
}
private let first = WindowSource(id: 1, processID: 10, appName: "UTM", title: "VM", frame: CGRect(x: 0, y: 0, width: 800, height: 500))
private let second = WindowSource(id: 2, processID: 10, appName: "UTM", title: "VM 2", frame: CGRect(x: 0, y: 0, width: 800, height: 500))

@MainActor private final class FakeCapture: PiPCapturing {
    var receive: (@MainActor @Sendable (CaptureEvent) -> Void)?
    var resizeCount = 0
    var lastSize = CGSize.zero
    var starts = 0
    var stops = 0
    var gate: CheckedContinuation<Void, Never>?
    var onStarted: (() -> Void)?
    var block = false
    func start(source: WindowSource, size: CGSize, receive: @escaping @MainActor @Sendable (CaptureEvent) -> Void) async throws {
        starts += 1; self.receive = receive
        if block { await withCheckedContinuation { gate = $0; onStarted?() } }
    }
    func resize(_ size: CGSize) async throws { resizeCount += 1; lastSize = size }
    func stop() async { stops += 1 }
}

@MainActor private func frame() throws -> CapturedFrame {
    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(nil, 16, 16, kCVPixelFormatType_32BGRA, [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &buffer)
    #expect(status == kCVReturnSuccess)
    return CapturedFrame(pixelBuffer: try #require(buffer), contentRect: CGRect(x: 0, y: 0, width: 16, height: 16), contentScale: 1, scaleFactor: 1)
}

@Test @MainActor func deniedPermissionNeverCreatesStream() async {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { false }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    #expect(owner.state == .permissionRequired); #expect(capture.starts == 0)
}
@Test @MainActor func permissionIsRecheckedOnResume() async {
    let capture = FakeCapture(); var allowed = true
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { allowed }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    owner.pause(); await owner.waitForOperations(); allowed = false
    owner.resume(); await owner.waitForOperations()
    #expect(owner.state == .permissionRequired); #expect(capture.starts == 1); #expect(capture.stops == 1)
}
@Test @MainActor func sameTitleNeverSelectsReplacement() async {
    let provider = SourceList(); provider.values = [second]
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: provider, permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    #expect(owner.state == .ended); #expect(capture.starts == 0)
}
@Test @MainActor func stopDiscardsLateFramesAndIsIdempotent() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    var frames = 0; owner.onFrame = { _ in frames += 1 }
    owner.start(first); await owner.waitForOperations()
    capture.receive?(.frame(try frame())); #expect(owner.state == .live)
    capture.receive?(.idle); #expect(owner.state == .live)
    owner.stop(); owner.stop(); await owner.waitForOperations()
    capture.receive?(.frame(try frame())); capture.receive?(.failure)
    #expect(owner.state == .ready); #expect(owner.source == nil); #expect(frames == 1); #expect(capture.stops == 1)
}
@Test @MainActor func rapidSwitchSerializesSuspendedStart() async throws {
    let old = FakeCapture(); old.block = true
    let new = FakeCapture(); var creations = 0
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: {
        creations += 1; return creations == 1 ? old : new
    })
    await withCheckedContinuation { started in
        old.onStarted = { started.resume() }; owner.start(first)
    }
    owner.start(second)
    #expect(new.starts == 0)
    old.gate?.resume(); old.gate = nil
    await owner.waitForOperations()
    old.receive?(.frame(try frame())); #expect(owner.state == .starting)
    new.receive?(.frame(try frame())); #expect(owner.state == .live)
    #expect(owner.source?.id == second.id); #expect(old.stops == 1)
    owner.stop(); await owner.waitForOperations(); #expect(new.stops == 1)
}
@Test @MainActor func pauseDuringStartPreventsLivePromotion() async throws {
    let capture = FakeCapture(); capture.block = true
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    await withCheckedContinuation { started in capture.onStarted = { started.resume() }; owner.start(first) }
    owner.pause(); capture.gate?.resume(); capture.gate = nil
    await owner.waitForOperations(); capture.receive?(.frame(try frame()))
    #expect(owner.state == .paused); #expect(capture.stops == 1)
}
@Test @MainActor func wakeDoesNotOverrideManualPause() async {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations(); owner.pause(); await owner.waitForOperations()
    owner.willSleep(); owner.didWake(); await owner.waitForOperations()
    #expect(owner.state == .paused); #expect(capture.starts == 1)
}

@Test @MainActor func unavailableImageRecoversOnlyOnValidFrame() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    capture.receive?(.unavailable); capture.receive?(.idle)
    #expect(owner.state == .unavailable)
    capture.receive?(.frame(try frame())); #expect(owner.state == .live)
    capture.receive?(.failure); await owner.waitForOperations()
    #expect(owner.state == .failed); #expect(capture.stops == 1)
}
@Test @MainActor func revokedPermissionStopsRunningStream() async throws {
    let capture = FakeCapture(); var allowed = true
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { allowed }, monitorInterval: .milliseconds(10), factory: { capture })
    owner.start(first); await owner.waitForOperations(); capture.receive?(.frame(try frame())); allowed = false
    for _ in 0..<100 where owner.state != .permissionRequired { try await Task.sleep(for: .milliseconds(10)) }
    await owner.waitForOperations()
    #expect(owner.state == .permissionRequired); #expect(capture.stops == 1)
}
@Test @MainActor func closedWindowStopsWithoutTitleMatching() async throws {
    let capture = FakeCapture(); let provider = SourceList()
    let owner = PiPSessionCoordinator(provider: provider, permission: { true }, monitorInterval: .milliseconds(10), factory: { capture })
    owner.start(first); await owner.waitForOperations(); provider.values = [second]
    for _ in 0..<100 where owner.state != .ended { try await Task.sleep(for: .milliseconds(10)) }
    await owner.waitForOperations()
    #expect(owner.state == .ended); #expect(capture.stops == 1)
}
@Test @MainActor func idleStreamDoesNotFreezeTimeoutAfterFirstFrame() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitorInterval: .milliseconds(10), firstFrameTimeout: .milliseconds(20), factory: { capture })
    owner.start(first); await owner.waitForOperations(); capture.receive?(.frame(try frame())); capture.receive?(.idle)
    try await Task.sleep(for: .milliseconds(50)); #expect(owner.state == .live)
    owner.stop(); await owner.waitForOperations()
}
@Test @MainActor func missingFirstFrameIsClearlyUnavailable() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitorInterval: .milliseconds(10), firstFrameTimeout: .milliseconds(20), factory: { capture })
    owner.start(first); await owner.waitForOperations()
    for _ in 0..<100 where owner.state != .unavailable { try await Task.sleep(for: .milliseconds(10)) }
    #expect(owner.state == .unavailable)
    owner.stop(); await owner.waitForOperations()
}

@Test @MainActor func realPanelPreservesWindowContract() {
    _ = NSApplication.shared
    let suite = "UniversalPiP.PanelTest." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let panel = PiPPanelController(defaults: defaults)
    var closed = false
    var reportedSize = CGSize.zero
    panel.onClose = { closed = true }
    panel.onResize = { size, _ in reportedSize = size }
    panel.show(source: first)
    let window = NSApp.windows.first { $0.title == "UniversalPiP – Live-Vorschau" }
    #expect(window != nil)
    #expect(window?.level == .floating)
    #expect(window?.hidesOnDeactivate == false)
    #expect(window?.styleMask.contains(.resizable) == true)
    #expect(window?.styleMask.contains(.nonactivatingPanel) == true)
    #expect(window?.collectionBehavior.contains(.canJoinAllSpaces) == true)
    #expect(window?.collectionBehavior.contains(.canJoinAllApplications) == true)
    #expect(reportedSize.width > 0 && reportedSize.height > 0)
    #expect(!panel.titleBarVisible)
    #expect(window?.styleMask.contains(.titled) == false)
    #expect(!panel.hudIsVisible)
    panel.preview.onHoverChanged?(true); #expect(panel.hudIsVisible)
    panel.preview.onHoverChanged?(false); #expect(!panel.hudIsVisible)
    let menu = NSMenu()
    panel.menuWillOpen(menu)
    panel.preview.onHoverChanged?(false); #expect(panel.hudIsVisible)
    panel.menuDidClose(menu)
    panel.preview.onHoverChanged?(false); #expect(!panel.hudIsVisible)
    panel.setTitleBarVisible(true); #expect(window?.styleMask.contains(.titled) == true)
    panel.setTitleBarVisible(false); #expect(window?.styleMask.contains(.titled) == false)
    for width: CGFloat in [240, 400, 800] {
        panel.setPreviewWidth(width); #expect(window?.frame.width == width)
    }
    // Programmatic close must not recursively call the user's close handler.
    panel.close(); #expect(!closed)
    #expect(defaults.string(forKey: "universalPiP.panelFrame") != nil)
    panel.dispose()
}

@Test @MainActor func resizeBurstIsDebouncedAndStopCancelsIt() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    for width in 400...410 { owner.updateTarget(size: CGSize(width: width, height: 250), scale: 1) }
    try await Task.sleep(for: .milliseconds(300)); await owner.waitForOperations()
    #expect(capture.resizeCount == 1)
    #expect(capture.lastSize == CGSize(width: 400, height: 250))
    owner.updateTarget(size: CGSize(width: 800, height: 500), scale: 1)
    owner.stop(); await owner.waitForOperations()
    try await Task.sleep(for: .milliseconds(250))
    #expect(capture.resizeCount == 1)
}

@Test func retinaFrameMetadataMustNotCropToOneQuarter() {
    let raw = CGRect(x: 0, y: 0, width: 325, height: 260)
    let pixels = PiPGeometry.pixelContentRect(raw, scaleFactor: 2, pixelSize: CGSize(width: 650, height: 520))
    #expect(pixels == CGRect(x: 0, y: 0, width: 650, height: 520))
    #expect(PiPGeometry.pixelContentRect(CGRect(x: 10, y: 5, width: 100, height: 80), scaleFactor: 1, pixelSize: CGSize(width: 150, height: 100)) == CGRect(x: 10, y: 5, width: 100, height: 80))
    #expect(PiPGeometry.pixelContentRect(raw, scaleFactor: .nan, pixelSize: CGSize(width: 650, height: 520)) == .zero)
}

@Test func originalFocusRejectsAmbiguousWindows() {
    let frame = first.frame
    #expect(WindowFocusCandidate.uniqueMatch(source: first, candidates: [.init(title: "VM", frame: frame)]) == 0)
    #expect(WindowFocusCandidate.uniqueMatch(source: first, candidates: [.init(title: "VM", frame: frame), .init(title: "VM", frame: frame)]) == nil)
    #expect(WindowFocusCandidate.uniqueMatch(source: first, candidates: [.init(title: "Other", frame: frame)]) == nil)
    #expect(WindowFocusCandidate.uniqueMatch(source: first, candidates: [.init(title: "VM", frame: frame.offsetBy(dx: 100, dy: 0)), .init(title: "VM", frame: frame)]) == 1)
}


@Test @MainActor func sleepWakeRestartsSameSourceExactlyOnce() async throws {
    let old = FakeCapture(), restarted = FakeCapture()
    var creations = 0, delivered = 0
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: {
        creations += 1; return creations == 1 ? old : restarted
    })
    owner.onFrame = { _ in delivered += 1 }
    owner.start(first); await owner.waitForOperations()
    old.receive?(.frame(try frame()))
    owner.willSleep(); await owner.waitForOperations()
    #expect(old.stops == 1); #expect(owner.state == .unavailable)
    old.receive?(.frame(try frame())); #expect(delivered == 1)
    owner.didWake(); owner.didWake(); await owner.waitForOperations()
    #expect(creations == 2); #expect(restarted.starts == 1)
    #expect(owner.source?.id == first.id); #expect(owner.source?.processID == first.processID)
    restarted.receive?(.frame(try frame())); #expect(owner.state == .live)
    owner.stop(); await owner.waitForOperations(); #expect(restarted.stops == 1)
}

@Test @MainActor func wakeWithMissingSourceEndsWithoutRetryOrReplacement() async {
    let capture = FakeCapture(), provider = SourceList()
    let owner = PiPSessionCoordinator(provider: provider, permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    owner.willSleep(); await owner.waitForOperations()
    provider.values = [WindowSource(id: first.id, processID: 999, appName: "UTM", title: first.title, frame: first.frame)]
    owner.didWake(); await owner.waitForOperations()
    #expect(owner.state == .ended); #expect(capture.starts == 1)
    owner.didWake(); await owner.waitForOperations()
    #expect(owner.state == .ended); #expect(capture.starts == 1)
    owner.stop(); await owner.waitForOperations()
}

@Test @MainActor func sourceResizeAndDensityChangeReconfigureCapture() async throws {
    let capture = FakeCapture(), provider = SourceList()
    let owner = PiPSessionCoordinator(provider: provider, permission: { true }, monitorInterval: .milliseconds(10), factory: { capture })
    owner.start(first); await owner.waitForOperations()
    provider.values = [WindowSource(id: first.id, processID: first.processID, appName: first.appName, title: first.title,
        frame: CGRect(x: 0, y: 0, width: 300, height: 600), pixelScale: 2)]
    for _ in 0..<100 where capture.resizeCount == 0 { try await Task.sleep(for: .milliseconds(10)) }
    await owner.waitForOperations()
    #expect(owner.source?.frame.size == CGSize(width: 300, height: 600))
    #expect(owner.source?.pixelScale == 2)
    #expect(capture.lastSize == CGSize(width: 250, height: 500))
    owner.stop(); await owner.waitForOperations()
}

@Test @MainActor func manualStopDuringSleepCancelsWakeAndRejectsOldCallbacks() async throws {
    let capture = FakeCapture()
    let owner = PiPSessionCoordinator(provider: SourceList(), permission: { true }, monitoring: false, factory: { capture })
    owner.start(first); await owner.waitForOperations()
    owner.willSleep(); owner.stop(); owner.didWake(); await owner.waitForOperations()
    capture.receive?(.frame(try frame())); capture.receive?(.failure)
    #expect(owner.state == .ready); #expect(owner.source == nil)
    #expect(capture.starts == 1); #expect(capture.stops == 1)
}

@Test @MainActor func closeButtonStaysVisibleAndRespondsWithoutHover() throws {
    _ = NSApplication.shared
    let suite = "PiPQuitTests-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let panel = PiPPanelController(defaults: defaults)
    defer { panel.dispose() }
    var closed = 0
    panel.onClose = { closed += 1 }
    panel.show(source: first)
    let window = try #require(panel.preview.window)
    func buttons(_ view: NSView) -> [NSButton] {
        (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
    }
    let root = try #require(window.contentView)
    let button = try #require(buttons(root).first { $0.toolTip == "Vorschau schließen" })
    for state: PiPState in [.starting, .live, .paused, .unavailable, .failed, .ended] {
        panel.setState(state); panel.preview.onHoverChanged?(false)
        #expect(!button.isHiddenOrHasHiddenAncestor)
        #expect(button.acceptsFirstMouse(for: nil))
        #expect(!button.mouseDownCanMoveWindow)
    }
    panel.setPreviewWidth(240)
    window.contentView?.layoutSubtreeIfNeeded()
    let center = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: window.contentView)
    #expect(window.contentView?.hitTest(center) === button)
    button.performClick(nil)
    #expect(closed == 1)
    #expect(!window.isVisible)
}
