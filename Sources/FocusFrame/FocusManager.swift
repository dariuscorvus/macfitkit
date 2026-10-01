import AppKit
import FocusFrameCore

@MainActor
final class FocusManager: NSObject {
    let accessibility = AccessibilityService()
    private let overlay = OverlayWindow()
    private var pendingRefresh: DispatchWorkItem?
    private var dragMonitor: Any?
    var enabled = true { didSet { refresh() } }
    var color: NSColor = .systemOrange { didSet { refresh() } }
    var width: CGFloat = 3 { didSet { refresh() } }
    var onPermissionChange: ((Bool) -> Void)?

    func start() {
        accessibility.onChange = { [weak self] in self?.scheduleRefresh() }
        accessibility.onGeometryChange = { [weak self] in
            // Deliver movement immediately, without cancelling/requeueing a full
            // permission and focus refresh behind further AX notifications.
            self?.refreshTrackedGeometry()
        }
        // Some apps defer AXMoved until the end of a drag. Mouse events provide
        // additional event-driven updates while the user is dragging, without
        // a timer or assumptions about whether the gesture moves or resizes.
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] _ in
            // AppKit delivers global monitor handlers on the main thread.
            MainActor.assumeIsolated { self?.refreshTrackedGeometry() }
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
        accessibility.stop()
        overlay.orderOut(nil)
    }

    func refresh() {
        let trusted = accessibility.isTrusted
        onPermissionChange?(trusted)
        guard enabled, trusted else {
            accessibility.stop()
            overlay.orderOut(nil)
            return
        }
        accessibility.observeFrontmostApplication()
        showGeometry(accessibility.focusedWindowGeometry())
    }

    private func showGeometry(_ geometry: (CGPoint, CGSize)?) {
        guard let (position, size) = geometry,
              let mainDisplay = NSScreen.screens.first,
              let rect = WindowGeometry.appKitRect(position: position, size: size, mainDisplayTop: mainDisplay.frame.maxY),
              NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            overlay.orderOut(nil)
            return
        }
        overlay.show(around: rect, color: color, width: width)
    }

    private func refreshTrackedGeometry() {
        guard enabled else { return }
        showGeometry(accessibility.trackedWindowGeometry())
    }

    private func scheduleRefresh(delay: TimeInterval = 0) {
        pendingRefresh?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    @objc private func workspaceChanged(_ notification: Notification) {
        overlay.orderOut(nil)
        // A single delayed refresh lets a Space transition settle; no recurring timer.
        scheduleRefresh(delay: notification.name == NSWorkspace.activeSpaceDidChangeNotification ? 0.15 : 0)
    }

    @objc private func displayChanged() { scheduleRefresh() }
    @objc private func suspend() {
        pendingRefresh?.cancel()
        overlay.orderOut(nil)
    }
}
