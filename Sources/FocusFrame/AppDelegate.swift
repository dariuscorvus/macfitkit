import AppKit
import OSLog
import FocusFrameCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = FocusManager()
    private let store = PreferencesStore()
    private let shortcut = ShortcutService()
    private var settings: SettingsWindowController?
    private var diagnostics: DiagnosticsWindowController?
    private var statusItem: NSStatusItem?
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Rahmen aktiv", action: #selector(toggleEnabled), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "FocusFrame")
        item.button?.toolTip = "FocusFrame – aktives Fenster markieren"
        let menu = NSMenu()
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)
        for (title, action) in [("Einstellungen …", #selector(showSettings)),
                                ("Diagnose …", #selector(showDiagnostics))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        permissionItem.title = "Bedienungshilfen erlauben …"
        permissionItem.target = self
        permissionItem.action = #selector(requestPermission)
        menu.addItem(permissionItem)
        let quitItem = NSMenuItem(title: "Beenden", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
        item.menu = menu
        statusItem = item
        manager.onPermissionChange = { [weak self] trusted in
            self?.permissionItem.isHidden = trusted
        }
        shortcut.onPress = { [weak self] in
            guard let self else { return }
            self.toggleEnabled()
            self.settings?.updateShortcutStatus(registered: self.shortcut.isEnabled,
                frameEnabled: self.manager.enabled, receivedPress: true)
            Diagnostics.shared.record("Tastenkürzel empfangen")
        }
        store.onChange = { [weak self] in self?.applyConfiguration() }
        applyConfiguration()
        manager.start()
        Logger(subsystem: "de.highbytetech.FocusFrame", category: "Lifecycle")
            .info("Started; accessibility trusted: \(self.manager.accessibility.isTrusted)")
        if !manager.accessibility.isTrusted { manager.accessibility.requestPermission() }
        if CommandLine.arguments.contains("--settings") { showSettings() }
        if CommandLine.arguments.contains("--diagnostics") { showDiagnostics() }
    }

    private func applyConfiguration() {
        manager.configuration = store.value.normalized
        do {
            try shortcut.setEnabled(store.value.shortcutEnabled)
            settings?.updateShortcutStatus(registered: shortcut.isEnabled, frameEnabled: manager.enabled)
        }
        catch {
            store.value.shortcutEnabled = false
            let alert = NSAlert()
            alert.messageText = "Tastenkürzel nicht verfügbar"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.stop()
        shortcut.stop()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func toggleEnabled() {
        manager.enabled.toggle()
        enabledItem.state = manager.enabled ? .on : .off
        settings?.updateShortcutStatus(registered: shortcut.isEnabled, frameEnabled: manager.enabled)
    }
    @objc private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(store: store)
            settings?.onToggleFrame = { [weak self] in self?.toggleEnabled() }
            settings?.onOpenDiagnostics = { [weak self] in self?.showDiagnostics() }
            settings?.onTestFocus = { [weak self] in self?.manager.testSettingsFocusAnimation() }
            manager.settingsWindow = settings?.window
        }
        settings?.updateShortcutStatus(registered: shortcut.isEnabled, frameEnabled: manager.enabled)
        settings?.present()
    }
    @objc private func showDiagnostics() {
        if diagnostics == nil {
            diagnostics = DiagnosticsWindowController()
            diagnostics?.onOpenSettings = { [weak self] in self?.showSettings() }
        }
        diagnostics?.present()
    }
    @objc private func requestPermission() {
        manager.accessibility.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
