import AppKit
import FocusFrameCore
@preconcurrency import ApplicationServices
import OSLog

@MainActor
final class AccessibilityService: NSObject {
    var onChange: (() -> Void)?
    var onGeometryChange: ((Bool) -> Void)?
    private let logger = Logger(subsystem: "de.highbytetech.FocusFrame", category: "Accessibility")
    private var observer: AXObserver?
    private var application: AXUIElement?
    private var window: AXUIElement?
    private var registrations: [(AXUIElement, String)] = []
    private(set) var focusGeneration: UInt64 = 0
    private var pid: pid_t?
    private var isFinder = false
    private var desktopClassification: Bool?
    private let queryTimeout: Float = 0.05

    var trackedProcessIdentifier: pid_t? { window == nil ? nil : pid }

    var isTrusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func observeFrontmostApplication() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        guard isTrusted, let frontmost, !frontmost.isHidden,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            stop()
            return
        }
        if pid == frontmost.processIdentifier, observer != nil { return }
        stop()
        pid = frontmost.processIdentifier
        isFinder = frontmost.bundleIdentifier == "com.apple.finder"
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        AXUIElementSetMessagingTimeout(app, queryTimeout)
        application = app
        var newObserver: AXObserver?
        let result = AXObserverCreate(frontmost.processIdentifier, { _, element, notification, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                let service = Unmanaged<AccessibilityService>.fromOpaque(context).takeUnretainedValue()
                let event = notification as String
                if (event == kAXMovedNotification || event == kAXResizedNotification),
                   let window = service.window, CFEqual(element, window) {
                    service.onGeometryChange?(event == kAXMovedNotification)
                } else {
                    service.onChange?()
                }
            }
        }, &newObserver)
        guard result == .success, let newObserver else {
            logger.error("AXObserver creation failed: \(result.rawValue)")
            return
        }
        observer = newObserver
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)
        for event in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification,
                      kAXWindowCreatedNotification, kAXApplicationActivatedNotification,
                      kAXApplicationHiddenNotification, kAXApplicationShownNotification] {
            register(app, event)
        }
    }

    func focusedWindowGeometry() -> (CGPoint, CGSize)? {
        guard isTrusted, let application,
              let focused = attribute(application, kAXFocusedWindowAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            observeWindow(nil)
            return nil
        }
        let focusedWindow = unsafeDowncast(focused, to: AXUIElement.self)
        observeWindow(focusedWindow)
        return trackedWindowGeometry()
    }

    /// Movement events already identify the tracked window: avoid another focus
    /// lookup and read its geometry in one cross-process AX request.
    func trackedWindowGeometry() -> (CGPoint, CGSize)? {
        let start = ProcessInfo.processInfo.systemUptime
        defer { Diagnostics.shared.record("AX-Geometrie", milliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1000) }
        guard let window else { return nil }
        let generation = focusGeneration
        let names = [kAXPositionAttribute, kAXSizeAttribute, kAXMinimizedAttribute]
        var values: CFArray?
        let result = AXUIElementCopyMultipleAttributeValues(window, names as CFArray, [], &values)
        let attributes: [CFTypeRef?]
        if result == .success, let values, CFArrayGetCount(values) == names.count {
            attributes = (values as [AnyObject]).map { $0 }
        } else if result == .notImplemented {
            attributes = names.map { attribute(window, $0) }
        } else {
            return nil
        }
        if let minimized = attributes[2] as? Bool, minimized { return nil }
        guard let positionValue = attributes[0], let sizeValue = attributes[1],
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let positionAX = unsafeDowncast(positionValue, to: AXValue.self)
        let sizeAX = unsafeDowncast(sizeValue, to: AXValue.self)
        guard AXValueGetType(positionAX) == .cgPoint, AXValueGetType(sizeAX) == .cgSize else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionAX, .cgPoint, &position), AXValueGetValue(sizeAX, .cgSize, &size) else { return nil }
        guard generation == focusGeneration,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              ProcessInfo.processInfo.systemUptime - start < 0.15 else {
            Diagnostics.shared.record("Veraltete oder langsame AX-Antwort verworfen")
            return nil
        }
        if isFinderDesktop(position: position, size: size) { return nil }
        return (position, size)
    }

    /// Finder's desktop is an AX focus target too, but is not a document window.
    /// Compare public WindowServer bounds/layers rather than localized titles.
    private func isFinderDesktop(position: CGPoint, size: CGSize) -> Bool {
        guard isFinder, let pid, let window else { return false }
        if let desktopClassification { return desktopClassification }
        let role = attribute(window, kAXRoleAttribute) as? String ?? ""
        if role == kAXScrollAreaRole { desktopClassification = true; return true }
        let frame = CGRect(origin: position, size: size)
        let windows = (CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]]) ?? []
        let layers = windows.compactMap { info -> Int? in
            guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                  abs(rect.minX - frame.minX) < 1, abs(rect.minY - frame.minY) < 1,
                  abs(rect.width - frame.width) < 1, abs(rect.height - frame.height) < 1 else { return nil }
            return (info[kCGWindowLayer as String] as? NSNumber)?.intValue
        }
        // Preserve a normal Finder window, including one covering the whole display.
        let result = DesktopFocusPolicy.isDesktop(isFinder: isFinder, role: role,
            matchingLayers: layers, desktopIconLevel: Int(CGWindowLevelForKey(.desktopIconWindow)))
        // Empty metadata is inconclusive and should not be cached.
        if !layers.isEmpty { desktopClassification = result }
        Diagnostics.shared.record("Desktop-Klassifikation erneuert")
        return result
    }

    var trackedWindowIsFullScreen: Bool {
        guard let window else { return false }
        return attribute(window, "AXFullScreen") as? Bool ?? false
    }

    func stop() {
        if let observer {
            for (element, event) in registrations { AXObserverRemoveNotification(observer, element, event as CFString) }
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        registrations.removeAll()
        observer = nil
        application = nil
        window = nil
        pid = nil
        isFinder = false
        desktopClassification = nil
    }

    private func observeWindow(_ next: AXUIElement?) {
        if let window, let next, CFEqual(window, next) { return }
        if let observer, let window {
            let windowRegistrations = registrations.filter { CFEqual($0.0, window) }
            for (element, event) in windowRegistrations { AXObserverRemoveNotification(observer, element, event as CFString) }
            registrations.removeAll { CFEqual($0.0, window) }
        }
        if next != nil { focusGeneration &+= 1 }
        window = next
        desktopClassification = nil
        guard let next else { return }
        AXUIElementSetMessagingTimeout(next, queryTimeout)
        for event in [kAXMovedNotification, kAXResizedNotification, kAXWindowMiniaturizedNotification,
                      kAXWindowDeminiaturizedNotification, kAXUIElementDestroyedNotification] {
            register(next, event)
        }
    }

    private func register(_ element: AXUIElement, _ event: String) {
        guard let observer else { return }
        let result = AXObserverAddNotification(observer, element, event as CFString,
            Unmanaged.passUnretained(self).toOpaque())
        if result == .success { registrations.append((element, event)) }
        else if result != .notificationAlreadyRegistered {
            logger.debug("AX event unavailable: \(event, privacy: .public) (\(result.rawValue))")
        }
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }
}
