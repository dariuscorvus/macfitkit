import AppKit
import ApplicationServices

@MainActor
enum AccessibilityReader {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    static func element(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let result = value(element, attribute), CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = value(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = value(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    struct DockTarget {
        let app: NSRunningApplication
        let icon: CGRect // AppKit screen coordinates
        let edge: PreviewGeometry.Edge
    }

    static func dockTarget(at point: CGPoint) -> DockTarget? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let primary = NSScreen.screens.first else { return nil }
        let dockAX = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(dockAX, 0.08)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(dockAX, Float(point.x), Float(primary.frame.maxY - point.y), &hit) == .success else { return nil }
        var current = hit
        for _ in 0..<5 {
            guard let item = current else { return nil }
            var pid: pid_t = 0
            AXUIElementGetPid(item, &pid)
            guard pid == dock.processIdentifier else { return nil }
            if value(item, kAXSubroleAttribute) as? String == kAXApplicationDockItemSubrole,
               let bounds = frame(item),
               let rawURL = value(item, kAXURLAttribute) as? URL {
                let url = rawURL.standardizedFileURL.resolvingSymlinksInPath()
                guard let app = NSWorkspace.shared.runningApplications.first(where: {
                    $0.bundleURL?.standardizedFileURL.resolvingSymlinksInPath() == url && !$0.isTerminated
                }) else { return nil }
                let icon = PreviewGeometry.cocoaRect(fromAX: bounds, primaryTop: primary.frame.maxY)
                guard icon.contains(point) else { return nil }
                let orientation = UserDefaults.standard.persistentDomain(forName: "com.apple.dock")?["orientation"] as? String
                let edge: PreviewGeometry.Edge
                switch orientation {
                case "left": edge = .left
                case "right": edge = .right
                case "bottom": edge = .bottom
                default:
                    let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: icon.midX, y: icon.midY)) } ?? primary
                    edge = PreviewGeometry.edge(icon: icon, screen: screen.frame)
                }
                return DockTarget(app: app, icon: icon, edge: edge)
            }
            current = element(item, kAXParentAttribute)
        }
        return nil
    }

    struct AppWindow: Identifiable {
        let id: Int
        let element: AXUIElement
        let title: String
        let frame: CGRect // AX / ScreenCaptureKit coordinates
        let minimized: Bool
    }

    static func windows(for app: NSRunningApplication) -> [AppWindow] {
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let windows = value(application, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return windows.enumerated().compactMap { index, window in
            guard value(window, kAXRoleAttribute) as? String == kAXWindowRole,
                  let frame = frame(window), frame.width > 60, frame.height > 40 else { return nil }
            let title = value(window, kAXTitleAttribute) as? String ?? ""
            return AppWindow(id: index, element: window,
                             title: title.isEmpty ? (app.localizedName ?? "Fenster") : title,
                             frame: frame, minimized: value(window, kAXMinimizedAttribute) as? Bool ?? false)
        }
    }

    static func raise(_ window: AppWindow, in app: NSRunningApplication) async -> Bool {
        var pid: pid_t = 0
        guard !app.isTerminated,
              AXUIElementGetPid(window.element, &pid) == .success, pid == app.processIdentifier,
              value(window.element, kAXRoleAttribute) as? String == kAXWindowRole else { return false }
        let application = AXUIElementCreateApplication(pid)
        if value(window.element, kAXMinimizedAttribute) as? Bool == true {
            guard AXUIElementSetAttributeValue(window.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse) == .success else { return false }
        }
        app.unhide()
        app.activate(options: [])
        // Activation is asynchronous; wait for the target before raising its selected window.
        for _ in 0..<10 {
            guard !Task.isCancelled else { return false }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid { break }
            try? await Task.sleep(for: .milliseconds(50))
        }
        guard !Task.isCancelled else { return false }
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(window.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(application, kAXFocusedWindowAttribute as CFString, window.element)
        let result = AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        guard result == .success else { return false }
        // Some apps publish their focused AX window after the foreground transition finishes.
        for _ in 0..<10 {
            guard !Task.isCancelled else { return false }
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
               let focused = element(application, kAXFocusedWindowAttribute), CFEqual(focused, window.element) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}
