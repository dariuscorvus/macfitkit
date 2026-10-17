import AppKit
import FocusFrameCore
import OSLog

@MainActor
final class FocusManager: NSObject {
    let accessibility = AccessibilityService()
    private let overlay = OverlayWindow()
    private var pendingRefresh: DispatchWorkItem?
    private var dragMonitor: Any?
    private var drag: WindowDrag?
    private var lastFocusGeneration: UInt64 = 0
    private var pendingFocusAnimation = false
    private var occlusionTimer: Timer?
    private var stackSnapshot: [WindowStackEntry]?
    private var stackReadAt: TimeInterval = -.infinity
    private var targetWindowID: UInt32?
    private var targetGeneration: UInt64?
    private var windowFrame: CGRect?
    weak var settingsWindow: NSWindow? { didSet { refresh() } }
    private var tracksSettings = false
    private let logger = Logger(subsystem: "de.highbytetech.FocusFrame", category: "Movement")
    var enabled = true { didSet { refresh() } }
    var configuration = Configuration() { didSet { refresh() } }
    var onPermissionChange: ((Bool) -> Void)?

    func start() {
        accessibility.onChange = { [weak self] in
            self?.cancelDrag()
            self?.scheduleRefresh()
        }
        accessibility.onGeometryChange = { [weak self] isMove in
            guard let self else { return }
            if isMove, self.drag != nil {
                if self.drag?.isMoving == false { self.logger.info("Pointer-driven window movement started") }
                if self.drag?.isMoving == false { Diagnostics.shared.record("Mausverfolgung begonnen") }
                self.pendingRefresh?.cancel()
                _ = self.drag?.updatePointer(NSEvent.mouseLocation)
                if let frame = self.drag?.confirmMove() { self.showFrame(frame) }
            } else {
                // Resizing/snapping changes geometry rather than translating it.
                self.cancelDrag()
                self.refreshTrackedGeometry()
            }
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            // AppKit delivers global monitor handlers on the main thread.
            MainActor.assumeIsolated { self?.handleMouse(event) }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(self, selector: #selector(workspaceChanged(_:)), name: name, object: nil)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            workspace.addObserver(self, selector: #selector(suspend), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                     NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification,
                     NSWindow.willCloseNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(localFocusChanged), name: name, object: nil)
        }
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            NotificationCenter.default.addObserver(self, selector: #selector(localGeometryChanged(_:)), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(displayChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        refresh()
    }

    func stop() {
        pendingRefresh?.cancel()
        pendingRefresh = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
        if let dragMonitor { NSEvent.removeMonitor(dragMonitor) }
        dragMonitor = nil
        cancelDrag()
        accessibility.stop()
        hideOverlay()
    }

    func refresh() {
        cancelDrag()
        let trusted = accessibility.isTrusted
        onPermissionChange?(trusted)
        if refreshSettingsTarget() { return }
        let excluded = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map {
            configuration.excludedApps.contains($0)
        } ?? false
        let policy = VisibilityPolicy.decide(enabled: enabled, trusted: trusted, excluded: excluded)
        guard policy == .show else {
            Diagnostics.shared.trackingState = policy
            windowFrame = nil
            accessibility.stop()
            hideOverlay()
            return
        }
        accessibility.observeFrontmostApplication()
        let geometry = accessibility.focusedWindowGeometry()
        if accessibility.focusGeneration != lastFocusGeneration {
            lastFocusGeneration = accessibility.focusGeneration
            pendingFocusAnimation = true
            Diagnostics.shared.record("Fokussiertes Fenster gewechselt")
        }
        let windowPolicy = VisibilityPolicy.decide(enabled: enabled, trusted: trusted,
            fullScreen: configuration.hideInFullScreen && accessibility.trackedWindowIsFullScreen,
            hideInFullScreen: configuration.hideInFullScreen, hasWindow: geometry != nil)
        if windowPolicy != .show {
            Diagnostics.shared.trackingState = windowPolicy
            windowFrame = nil
            hideOverlay()
        } else {
            showGeometry(geometry)
        }
    }

    /// Our own settings use AppKit notifications and geometry. They need no AX
    /// lookup and share the same overlay and effects as every external window.
    private func refreshSettingsTarget() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier else {
            tracksSettings = false
            return false
        }
        accessibility.stop()
        windowFrame = nil
        let key = NSApp.keyWindow
        let hasTarget = settingsWindow.map {
            $0.isVisible && !$0.isMiniaturized &&
            (key === $0 || key?.sheetParent === $0 || key is NSColorPanel)
        } ?? false
        let policy = VisibilityPolicy.decide(enabled: enabled, trusted: true,
            excluded: configuration.excludedApps.contains(Bundle.main.bundleIdentifier ?? ""),
            fullScreen: settingsWindow?.styleMask.contains(.fullScreen) == true,
            hideInFullScreen: configuration.hideInFullScreen, hasWindow: hasTarget)
        guard policy == .show, let settingsWindow else {
            tracksSettings = false
            Diagnostics.shared.trackingState = policy
            hideOverlay()
            return true
        }
        if !tracksSettings { pendingFocusAnimation = true }
        tracksSettings = true
        showFrame(settingsWindow.frame)
        return true
    }

    func testSettingsFocusAnimation() {
        guard tracksSettings, enabled, let settingsWindow else { return }
        pendingFocusAnimation = true
        showFrame(settingsWindow.frame)
    }

    @objc private func localFocusChanged() { scheduleRefresh() }
    @objc private func localGeometryChanged(_ notification: Notification) {
        guard tracksSettings, let window = notification.object as? NSWindow,
              window === settingsWindow else { return }
        showFrame(window.frame)
    }

    private func showGeometry(_ geometry: (CGPoint, CGSize)?) {
        guard let (position, size) = geometry,
              let mainDisplay = NSScreen.screens.first,
              let rect = WindowGeometry.appKitRect(position: position, size: size, mainDisplayTop: mainDisplay.frame.maxY),
              NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            Diagnostics.shared.trackingState = .noWindow
            windowFrame = nil
            hideOverlay()
            return
        }
        windowFrame = rect
        showFrame(rect)
    }

    private func showFrame(_ frame: CGRect) {
        guard enabled else { return }
        Diagnostics.shared.trackingState = .show
        overlay.show(around: frame, appearance: configuration.renderedAppearance(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled), focusChanged: pendingFocusAnimation)
        pendingFocusAnimation = false
        updateOcclusion()
        startOcclusionTracking()
    }

    private func hideOverlay() {
        stopOcclusionTracking()
        overlay.orderOut(nil)
    }

    private func stopOcclusionTracking() {
        occlusionTimer?.invalidate(); occlusionTimer = nil
        stackSnapshot = nil; stackReadAt = -.infinity
    }

    private func startOcclusionTracking() {
        guard occlusionTimer == nil else { return }
        scheduleOcclusionTick()
    }

    private func scheduleOcclusionTick() {
        // Interactive: 30 Hz; idle: 10 Hz; Low Power: 4 Hz. No pixel capture.
        let interval: TimeInterval = ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.25 :
            (NSEvent.pressedMouseButtons != 0 ? 1.0 / 30.0 : 0.1)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.occlusionTimer = nil
                guard self.enabled, self.overlay.isVisible else { return }
                self.updateOcclusion()
                self.scheduleOcclusionTick()
            }
        }
        timer.tolerance = interval * 0.1
        occlusionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateOcclusion() {
        // Geometry callbacks and pointer prediction can arrive faster than the
        // timer. Bound WindowServer reads across all callers to 30 Hz.
        let now = ProcessInfo.processInfo.systemUptime
        if (now - stackReadAt) >= (ProcessInfo.processInfo.isLowPowerModeEnabled ? 0.25 : 1.0 / 30.0) {
            stackReadAt = now
            stackSnapshot = WindowStackSnapshot.read(excluding: overlay.windowNumber)
        }
        if !tracksSettings, targetGeneration != accessibility.focusGeneration {
            targetGeneration = accessibility.focusGeneration
            targetWindowID = nil
        }
        guard let bounds = tracksSettings ? settingsWindow?.frame : windowFrame,
              let pid = tracksSettings ? ProcessInfo.processInfo.processIdentifier : accessibility.trackedProcessIdentifier,
              let stack = stackSnapshot,
              let index = WindowOcclusion.target(in: stack, pid: pid, bounds: bounds,
                  knownID: tracksSettings ? settingsWindow.map { UInt32($0.windowNumber) } : targetWindowID) else {
            overlay.setOcclusion(nil)
            return
        }
        if !tracksSettings { targetWindowID = stack[index].id }
        // All windows above the target count, including same-app sheets and panels.
        // Bounds conservatively cover translucent surfaces and rounded corners.
        overlay.setOcclusion(Array(stack[..<index]).map(\.bounds))
    }

    private func handleMouse(_ event: NSEvent) {
        guard enabled else { return }
        switch event.type {
        case .leftMouseDown:
            cancelDrag()
            guard let windowFrame, overlay.isVisible, let screen = NSScreen.screens.first,
                  let location = event.cgEvent?.location else { return }
            let point = CGPoint(x: location.x, y: screen.frame.maxY - location.y)
            // Limit translation candidates to the title/toolbar, excluding
            // resize edges. Controls/content cannot start prediction unless
            // AXMoved confirms that this window actually moves.
            let topStrip = CGRect(x: windowFrame.minX + 8, y: windowFrame.maxY - 64,
                                  width: max(0, windowFrame.width - 16), height: 56)
            guard topStrip.contains(point) else { return }
            drag = WindowDrag(frame: windowFrame, pointer: point)
            logger.debug("Window drag candidate captured")
        case .leftMouseDragged:
            // No synchronous AX reads here: target-app replies can block the
            // main thread or contain positions from earlier in the drag.
            if let frame = drag?.updatePointer(NSEvent.mouseLocation) { showFrame(frame) }
        case .leftMouseUp:
            let wasMoving = drag?.isMoving == true
            if let frame = drag?.updatePointer(NSEvent.mouseLocation) { showFrame(frame) }
            drag = nil
            if wasMoving {
                Diagnostics.shared.record("Mausverfolgung beendet")
                // One final reconciliation after the target handles mouse-up.
                scheduleRefresh(delay: 0.05)
            }
        default: break
        }
    }

    private func refreshTrackedGeometry() {
        guard enabled else { return }
        let policy = VisibilityPolicy.decide(enabled: enabled, trusted: true,
            fullScreen: configuration.hideInFullScreen && accessibility.trackedWindowIsFullScreen,
            hideInFullScreen: configuration.hideInFullScreen)
        if policy != .show {
            Diagnostics.shared.trackingState = policy
            windowFrame = nil
            hideOverlay()
            return
        }
        showGeometry(accessibility.trackedWindowGeometry())
    }

    private func cancelDrag() {
        if drag?.isMoving == true { Diagnostics.shared.record("Mausverfolgung unterbrochen") }
        drag?.interrupt()
        drag = nil
    }

    private func scheduleRefresh(delay: TimeInterval = 0) {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    @objc private func workspaceChanged(_ notification: Notification) {
        Diagnostics.shared.record("App-/Space-/Systemwechsel")
        cancelDrag()
        hideOverlay()
        // Let a Space transition settle before restoring tracking.
        scheduleRefresh(delay: notification.name == NSWorkspace.activeSpaceDidChangeNotification ? 0.15 : 0)
    }

    @objc private func displayChanged() {
        cancelDrag()
        hideOverlay()
        scheduleRefresh()
    }
    @objc private func suspend() {
        cancelDrag()
        pendingRefresh?.cancel()
        hideOverlay()
    }
}
