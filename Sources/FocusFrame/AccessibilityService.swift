import AppKit
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
    private var pid: pid_t?

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
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
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
        guard let window else { return nil }
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
        return (position, size)
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
    }

    private func observeWindow(_ next: AXUIElement?) {
        if let window, let next, CFEqual(window, next) { return }
        if let observer, let window {
            let windowRegistrations = registrations.filter { CFEqual($0.0, window) }
            for (element, event) in windowRegistrations { AXObserverRemoveNotification(observer, element, event as CFString) }
            registrations.removeAll { CFEqual($0.0, window) }
        }
        window = next
        guard let next else { return }
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
