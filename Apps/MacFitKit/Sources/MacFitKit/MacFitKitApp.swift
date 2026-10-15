import AppKit
import SwiftUI
import MacFitKitUI
import MacFitKitCore
import MacFitKitPlatform

@main struct MacFitKitApp: App {
    @NSApplicationDelegateAdaptor(HubAppDelegate.self) private var delegate
    var body: some Scene { Settings { HubSettingsView(controller: delegate.controller) } }
}

@MainActor final class HubAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let controller = HubController()
    private var item: NSStatusItem?
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--ui-preview") && !controller.isMenuPreview {
            NSApp.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
            controller.refresh(); showSettings(); SettingsPreview.present(window); return
        }
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? BridgeNames.hubBundleIdentifier).contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            NSApp.terminate(nil); return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "MacFitKit")
        item.button?.toolTip = "MacFitKit"
        let menu = NSMenu(); menu.delegate = self; item.menu = menu; self.item = item
        controller.refresh(); controller.bridge.start()
        if CommandLine.arguments.contains("--settings") || controller.isMenuPreview { showSettings() }
        if controller.isMenuPreview { SettingsPreview.present(window) }
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        controller.refresh(); menu.removeAllItems()
        for tool in controller.available {
            let entry = NSMenuItem(title: tool.name, action: nil, keyEquivalent: "")
            entry.image = NSImage(systemSymbolName: tool.symbol, accessibilityDescription: nil)
            let submenu = NSMenu(); submenu.autoenablesItems = false
            submenu.addItem(NSMenuItem(title: String(controller.description(tool).prefix(30)), action: nil, keyEquivalent: ""))
            if controller.running(tool) == nil {
                add("Starten", action: #selector(startTool(_:)), tool: tool, menu: submenu).isEnabled = controller.supported(tool)
            } else if let status = controller.bridge.statuses[tool] {
                add(status.enabled ? "Pausieren" : "Aktivieren", action: #selector(toggleTool(_:)), tool: tool, menu: submenu)
                add("Einstellungen …", action: #selector(settingsTool(_:)), tool: tool, menu: submenu)
                add("Beenden", action: #selector(quitTool(_:)), tool: tool, menu: submenu)
            } else { add("Status erneut prüfen", action: #selector(refreshTool(_:)), tool: tool, menu: submenu) }
            entry.submenu = submenu; menu.addItem(entry)
        }
        if controller.available.isEmpty { menu.addItem(NSMenuItem(title: "Keine Tools gefunden", action: nil, keyEquivalent: "")) }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "MacFitKit öffnen …", action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let quit = NSMenuItem(title: "MacFitKit beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); menu.addItem(quit)
    }
    @discardableResult private func add(_ title: String, action: Selector, tool: ToolID, menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; item.representedObject = tool.rawValue
        menu.addItem(item); return item
    }
    private func tool(_ sender: NSMenuItem) -> ToolID? { (sender.representedObject as? String).flatMap(ToolID.init(rawValue:)) }
    @objc private func startTool(_ sender: NSMenuItem) { if let id = tool(sender) { controller.start(id) } }
    @objc private func toggleTool(_ sender: NSMenuItem) { if let id = tool(sender), let status = controller.bridge.statuses[id] { controller.bridge.send(.setEnabled(!status.enabled), to: id) } }
    @objc private func settingsTool(_ sender: NSMenuItem) { if let id = tool(sender) { controller.bridge.send(.openSettings, to: id) } }
    @objc private func quitTool(_ sender: NSMenuItem) { if let id = tool(sender) { controller.bridge.send(.quit, to: id) } }
    @objc private func refreshTool(_ sender: NSMenuItem) { if let id = tool(sender) { controller.bridge.send(.requestStatus, to: id) } }
    @objc private func showSettings() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 600), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "MacFitKit"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: HubSettingsView(controller: controller)); window.center(); self.window = window
        }
        controller.refresh(); window?.makeKeyAndOrderFront(nil); NSApp.activate()
    }
    func applicationWillTerminate(_ notification: Notification) { controller.bridge.stop() }
}
