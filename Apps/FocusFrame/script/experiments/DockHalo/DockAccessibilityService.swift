import AppKit
@preconcurrency import ApplicationServices
import FocusFrameCore

/// Experimental AX adapter. Never guesses identity from localized titles.
@MainActor
final class DockAccessibilityService {
    struct Item {
        let element: AXUIElement
        let url: URL
        let rect: CGRect
    }
    var onChange: ((String) -> Void)?
    private var observer: AXObserver?
    private var registrations: [(AXUIElement, String)] = []
    private var pid: pid_t?
    private(set) var listRect: CGRect?
    private(set) var items: [Item] = []
    private(set) var registrationResults: [String: Int32] = [:]

    var isTrusted: Bool { AXIsProcessTrusted() }
    // Read-only experimental guard; these preference keys are not an AX contract.
    var autohideEnabled: Bool? {
        UserDefaults(suiteName: "com.apple.dock")?.object(forKey: "autohide") as? Bool
    }
    func refresh() {
        items = []; listRect = nil
        guard isTrusted,
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { stop(); return }
        // Rebuild a bounded tree on events, including Dock restarts and stale elements.
        stop(); pid = dock.processIdentifier
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.1)
        var next: AXObserver?
        if AXObserverCreate(dock.processIdentifier, { _, _, name, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                Unmanaged<DockAccessibilityService>.fromOpaque(context).takeUnretainedValue().onChange?(name as String)
            }
        }, &next) == .success, let next {
            observer = next
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(next), .commonModes)
        }
        observe(app, label: "app")
        let lists = children(app).filter { attribute($0, kAXRoleAttribute) as? String == kAXListRole }
        guard lists.count == 1, let list = lists.first, let bounds = rect(list) else { return }
        listRect = bounds; observe(list, label: "list")
        // VisibleChildren is useful but not sufficient proof of auto-hide visibility.
        let visible = children(list, name: kAXVisibleChildrenAttribute)
        for element in visible.prefix(128) {
            guard attribute(element, kAXSubroleAttribute) as? String == kAXApplicationDockItemSubrole,
                  let url = attribute(element, kAXURLAttribute) as? URL,
                  url.isFileURL, let bounds = rect(element) else { continue }
            items.append(Item(element: element, url: url.resolvingSymlinksInPath().standardizedFileURL, rect: bounds))
            observe(element, label: "item")
        }
    }
    func match(_ app: NSRunningApplication) -> Item? {
        guard let url = app.bundleURL?.resolvingSymlinksInPath().standardizedFileURL else { return nil }
        let matches = items.filter { $0.url == url }
        return matches.count == 1 ? matches[0] : nil
    }
    func stop() {
        if let observer {
            for (element, event) in registrations { AXObserverRemoveNotification(observer, element, event as CFString) }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        registrations = []; observer = nil; pid = nil
    }
    private func observe(_ element: AXUIElement, label: String) {
        guard let observer else { return }
        for event in [kAXMovedNotification, kAXResizedNotification, kAXLayoutChangedNotification,
                      kAXUIElementDestroyedNotification, kAXCreatedNotification, kAXSelectedChildrenChangedNotification] {
            let result = AXObserverAddNotification(observer, element, event as CFString,
                Unmanaged.passUnretained(self).toOpaque())
            registrationResults["\(label).\(event)"] = result.rawValue
            if result == .success { registrations.append((element, event)) }
        }
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
    private func children(_ element: AXUIElement, name: String = kAXChildrenAttribute) -> [AXUIElement] {
        attribute(element, name) as? [AXUIElement] ?? []
    }
    private func rect(_ element: AXUIElement) -> CGRect? {
        guard let p = attribute(element, kAXPositionAttribute), let s = attribute(element, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var size = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(p, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(s, to: AXValue.self), .cgSize, &size),
              let top = NSScreen.screens.first?.frame.maxY else { return nil }
        return WindowGeometry.appKitRect(position: point, size: size, mainDisplayTop: top)
    }
}
