import AppKit
import FocusFrameCore

@MainActor
final class DockHaloPrototype: NSObject, NSApplicationDelegate {
    private let ax = DockAccessibilityService()
    private let halo = OverlayWindow()
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var mouse: Any?
    private var pending: DispatchWorkItem?
    private var generation = 0
    private var sessionActive = true
    private var nearDock = false
    private var lastRect: CGRect?
    private var lastApp: pid_t?
    private let showHalo = CommandLine.arguments.contains("--halo")
    private let logURL = ProcessInfo.processInfo.environment["FOCUSFRAME_DOCK_LOG"].map { URL(fileURLWithPath: $0) }
    private var lastMessage = ""
    private var didReportCapabilities = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        halo.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        log("start trusted=\(ax.isTrusted) halo=\(showHalo); no permission prompt")
        guard ax.isTrusted else { log("blocked: existing AX permission unavailable"); NSApp.terminate(nil); return }
        ax.onChange = { [weak self] event in self?.invalidate("AX:\(event)") }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            watch(workspace, name)
        }
        tokens.append((workspace, workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.sessionActive = false; self?.cancelAndHide() } }))
        watch(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
        mouse = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp]) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerChanged() }
        }
        if mouse == nil { log("blocked: pointer monitor unavailable"); NSApp.terminate(nil); return }
        pointerChanged()
        invalidate("start")
        // A finite test session, never a repeating timer. Default 20 seconds.
        let args = CommandLine.arguments
        let duration = args.firstIndex(of: "--seconds").flatMap { $0 + 1 < args.count ? Double(args[$0+1]) : nil } ?? 20
        DispatchQueue.main.asyncAfter(deadline: .now() + min(120, max(2, duration))) { NSApp.terminate(nil) }

    }
    private func watch(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] n in
            MainActor.assumeIsolated {
                if n.name == NSWorkspace.sessionDidBecomeActiveNotification { self?.sessionActive = true }
                self?.invalidate(n.name.rawValue)
            }
        }
        tokens.append((center, token))
    }
    private func cancelAndHide() {
        generation += 1; pending?.cancel(); pending = nil; halo.orderOut(nil)
    }
    private func invalidate(_ reason: String) {
        cancelAndHide(); lastRect = nil
        let current = generation
        // Coalesce events. Two bounded samples after animation, no retry loop.
        let work = DispatchWorkItem { [weak self] in
            guard let self, current == self.generation else { return }
            self.sample(reason, confirm: false)
            let confirmation = DispatchWorkItem { [weak self] in
                guard let self, current == self.generation else { return }
                self.sample(reason, confirm: true)
            }
            self.pending = confirmation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: confirmation)
        }
        pending = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
    private func pointerChanged() {
        // No AX reads on mouse motion. Suppress on Dock approach; settle on exit.
        let p = NSEvent.mouseLocation
        let edge = NSScreen.screens.contains { s in
            let r = s.frame
            return r.contains(p) && (p.x-r.minX < 160 || r.maxX-p.x < 160 || p.y-r.minY < 160)
        }
        let near = edge || (ax.listRect?.insetBy(dx: -100, dy: -100).contains(p) ?? false)
        if near && !nearDock { nearDock = true; cancelAndHide(); log("hidden: pointer near Dock/display edge") }
        else if !near && nearDock { nearDock = false; invalidate("pointer exited") }
    }
    private func sample(_ reason: String, confirm: Bool) {
        guard sessionActive, !nearDock else { return }
        ax.refresh()
        if !didReportCapabilities {
            didReportCapabilities = true
            for key in ax.registrationResults.keys.sorted() { log("registration \(key)=\(ax.registrationResults[key]!)") }
            log("mapped candidates=\(ax.items.count), displays=\(NSScreen.screens.count), autohide=\(String(describing: ax.autohideEnabled))")
        }
        guard let app = NSWorkspace.shared.frontmostApplication, !app.isHidden, let item = ax.match(app) else {
            halo.orderOut(nil); log("hidden: no unique bundle-URL match for \(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown")"); return
        }
        // AX cell bounds contain the label/indicator area, not exact icon pixels.
        let r = item.rect
        guard NSScreen.screens.contains(where: { $0.frame.contains(r) }),
              ax.autohideEnabled == false else { halo.orderOut(nil); log("hidden: auto-hide/visibility not proven"); return }
        if !confirm { lastRect = r; lastApp = app.processIdentifier; return }
        guard lastRect == r, lastApp == app.processIdentifier else {
            halo.orderOut(nil); log("hidden: samples differ; waiting for next event"); return
        }
        var a = Appearance(); a.red = 0.25; a.green = 0.65; a.blue = 1
        a.width = 2; a.opacity = 0.65; a.radius = 12; a.placement = .inside
        a.light.mode = .glow; a.light.extent = 5; a.light.intensity = 0.25
        if showHalo { halo.show(around: r, appearance: a) }
        log("stable \(app.bundleIdentifier ?? "unknown") rect=\(r) visible=\(halo.isVisible) clickThrough=\(halo.ignoresMouseEvents) reason=\(reason)")
    }
    private func log(_ message: String) {
        guard message != lastMessage else { return }; lastMessage = message
        let line = "\(Date().timeIntervalSince1970) \(message)\n"
        print(line, terminator: "")
        if let logURL, let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }; _ = try? handle.seekToEnd(); try? handle.write(contentsOf: Data(line.utf8))
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        cancelAndHide(); ax.stop()
        for (center, token) in tokens { center.removeObserver(token) }; tokens = []
        if let mouse { NSEvent.removeMonitor(mouse) }; mouse = nil
        log("stopped; overlay and observers removed")
    }
}
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let prototype = DockHaloPrototype()
    application.delegate = prototype
    application.run()
}
