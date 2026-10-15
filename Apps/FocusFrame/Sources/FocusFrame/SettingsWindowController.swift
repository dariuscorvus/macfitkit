import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI

@MainActor
final class SettingsWindowController: NSWindowController {
    var onToggleFrame: (() -> Void)? { didSet { model.toggleFrame = onToggleFrame } }
    var onOpenDiagnostics: (() -> Void)? { didSet { model.openDiagnostics = onOpenDiagnostics } }
    var onTestFocus: (() -> Void)? { didSet { model.testFocus = onTestFocus } }
    let model: FocusSettingsModel
    init(store: PreferencesStore) {
        model = FocusSettingsModel(store: store)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "FocusFrame – Einstellungen"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 540)
        super.init(window: window)
        model.window = window
        window.contentView = NSHostingView(rootView: FocusSettingsView(model: model))
        window.center()
        NotificationCenter.default.addObserver(self, selector: #selector(sync), name: .NSProcessInfoPowerStateDidChange, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func present() { sync(); showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate() }
    @objc func sync() { model.objectWillChange.send() }
    func updateShortcutStatus(registered: Bool, frameEnabled: Bool, receivedPress: Bool = false) {
        model.shortcutRegistered = registered; model.frameEnabled = frameEnabled
        if receivedPress { model.shortcutPresses += 1 }
    }
}
