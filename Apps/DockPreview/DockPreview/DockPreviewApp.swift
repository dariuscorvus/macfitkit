import AppKit
import SwiftUI
import MacFitKitCore
import MacFitKitPlatform

@main
struct DockPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            ContentView(controller: appDelegate.controller)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let controller = DockPreviewController()
    private var bridge: ToolBridgeClient?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--ui-preview") {
            NSApp.appearance = NSAppearance(named: CommandLine.arguments.contains("--dark") ? .darkAqua : .aqua)
            showSettings()
            return
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "DockPreview")
        let menu = NSMenu()
        let settings = NSMenuItem(title: "DockPreview öffnen …", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "DockPreview beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
        controller.start()
        bridge = ToolBridgeClient(tool: .dockPreview, state: { [weak self] in
            guard let self else { return (false, "Beendet") }
            return (self.controller.enabled, self.controller.enabled ? self.controller.status : "Manuell pausiert")
        }, command: { [weak self] command in
            switch command {
            case .openSettings: self?.showSettings()
            case .setEnabled(let enabled): self?.controller.enabled = enabled
            case .quit: NSApp.terminate(nil)
            case .requestStatus: break
            }
        }, menuVisible: { [weak self] visible in self?.statusItem?.isVisible = visible })
        bridge?.start()
        if !controller.accessibilityGranted || !controller.screenRecordingGranted || CommandLine.arguments.contains("--settings") { showSettings() }
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "DockPreview"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: ContentView(controller: controller))
            window.center()
            settingsWindow = window
        }
        controller.refreshPermissions()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) { bridge?.stop(); controller.stop() }
}
