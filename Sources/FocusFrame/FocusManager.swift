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
    private var windowFrame: CGRect?
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
        overlay.orderOut(nil)
    }

    func refresh() {
        cancelDrag()
        let trusted = accessibility.isTrusted
        onPermissionChange?(trusted)
        let excluded = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.map {
            configuration.excludedApps.contains($0)
        } ?? false
        let policy = VisibilityPolicy.decide(enabled: enabled, trusted: trusted, excluded: excluded)
        guard policy == .show else {
            Diagnostics.shared.trackingState = policy
            windowFrame = nil
            accessibility.stop()
            overlay.orderOut(nil)
            return
        }
        accessibility.observeFrontmostApplication()
        let geometry = accessibility.focusedWindowGeometry()
        let windowPolicy = VisibilityPolicy.decide(enabled: enabled, trusted: trusted,
            fullScreen: configuration.hideInFullScreen && accessibility.trackedWindowIsFullScreen,
            hideInFullScreen: configuration.hideInFullScreen, hasWindow: geometry != nil)
        if windowPolicy != .show {
            Diagnostics.shared.trackingState = windowPolicy
            windowFrame = nil
            overlay.orderOut(nil)
        } else {
            showGeometry(geometry)
        }
    }

    private func showGeometry(_ geometry: (CGPoint, CGSize)?) {
        guard let (position, size) = geometry,
              let mainDisplay = NSScreen.screens.first,
              let rect = WindowGeometry.appKitRect(position: position, size: size, mainDisplayTop: mainDisplay.frame.maxY),
              NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            Diagnostics.shared.trackingState = .noWindow
            windowFrame = nil
            overlay.orderOut(nil)
            return
        }
        windowFrame = rect
        showFrame(rect)
    }

    private func showFrame(_ frame: CGRect) {
        guard enabled else { return }
        Diagnostics.shared.trackingState = .show
        overlay.show(around: frame, appearance: configuration.appearance)
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
            overlay.orderOut(nil)
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
        overlay.orderOut(nil)
        // A single delayed refresh lets a Space transition settle; no recurring timer.
        scheduleRefresh(delay: notification.name == NSWorkspace.activeSpaceDidChangeNotification ? 0.15 : 0)
    }

    @objc private func displayChanged() {
        cancelDrag()
        overlay.orderOut(nil)
        scheduleRefresh()
    }
    @objc private func suspend() {
        cancelDrag()
        pendingRefresh?.cancel()
        overlay.orderOut(nil)
    }
}
