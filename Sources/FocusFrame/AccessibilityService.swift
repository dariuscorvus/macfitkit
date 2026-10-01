import AppKit
import ApplicationServices
import OSLog

@MainActor
final class AccessibilityService: NSObject {
    var onChange: (() -> Void)?
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
        guard isTrusted, let frontmost, frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            stop()
            return
        }
        if pid == frontmost.processIdentifier { return }
        stop()
        pid = frontmost.processIdentifier
        let app = AXUIElementCreateApplication(frontmost.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.2)
        application = app
        var newObserver: AXObserver?
        let result = AXObserverCreate(frontmost.processIdentifier, { _, _, notification, context in
            guard let context else { return }
            MainActor.assumeIsolated {
                let service = Unmanaged<AccessibilityService>.fromOpaque(context).takeUnretainedValue()
                if notification as String == kAXUIElementDestroyedNotification { service.window = nil }
                service.onChange?()
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
        let focusedWindow = unsafeBitCast(focused, to: AXUIElement.self)
        observeWindow(focusedWindow)
        if let minimized = attribute(focusedWindow, kAXMinimizedAttribute) as? Bool, minimized { return nil }
        guard let positionValue = attribute(focusedWindow, kAXPositionAttribute),
              let sizeValue = attribute(focusedWindow, kAXSizeAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(), CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let positionAX = unsafeBitCast(positionValue, to: AXValue.self)
        let sizeAX = unsafeBitCast(sizeValue, to: AXValue.self)
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
