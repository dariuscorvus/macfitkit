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
        menu.addItem(NSMenuItem(title: "FocusFrame", action: nil, keyEquivalent: ""))
        menu.addItem(permissionItem)
        menu.addItem(.separator())
        enabledItem.target = self
        enabledItem.state = .on
        menu.addItem(enabledItem)
        for (title, action) in [("Einstellungen …", #selector(showSettings)),
                                ("Diagnose …", #selector(showDiagnostics)),
                                ("Bedienungshilfen erlauben …", #selector(requestPermission)),
                                ("Berechtigung erneut prüfen", #selector(checkPermission)),
                                ("Beenden", #selector(quit))] {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            menu.addItem(entry)
        }
        item.menu = menu
        statusItem = item
        manager.onPermissionChange = { [weak self] trusted in
            self?.permissionItem.title = trusted ? "Bedienungshilfen: erlaubt" : "Bedienungshilfen: fehlen"
        }
        shortcut.onPress = { [weak self] in self?.toggleEnabled() }
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
        do { try shortcut.setEnabled(store.value.shortcutEnabled) }
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
    }
    @objc private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(store: store)
            settings?.onOpenDiagnostics = { [weak self] in self?.showDiagnostics() }
        }
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
    @objc private func checkPermission() { manager.refresh() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
