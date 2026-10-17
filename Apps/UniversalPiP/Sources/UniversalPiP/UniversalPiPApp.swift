import AppKit
import OSLog
import SwiftUI
import UniversalPiP
import MacFitKitCore
import MacFitKitPlatform
import MacFitKitUI

@main struct UniversalPiPApp: App {
    @NSApplicationDelegateAdaptor(PiPAppDelegate.self) private var delegate
    var body: some Scene {
        Settings { PiPSettingsView(controller: delegate.controller) }
            .commands {
                CommandMenu("Vorschau") {
                    Button("Fenster auswählen …") { delegate.showSettings() }.keyboardShortcut("o")
                    Button("Originalfenster fokussieren") { delegate.controller.focusOriginal() }.keyboardShortcut("f", modifiers: [.command, .shift])
                    Button("Pause oder Fortsetzen") {
                        if delegate.controller.session.isEnabled { delegate.controller.session.pause() } else { delegate.controller.resume() }
                    }.keyboardShortcut("p")
                    Button("Vorschau schließen") { delegate.controller.close() }.keyboardShortcut("w", modifiers: [.command, .shift])
                }
            }
    }
}

@MainActor final class PiPAppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let controller = PiPAppController()
    #if DEBUG
    private var captureProbe: DebugCaptureProbe?
    #endif
    private var item: NSStatusItem?
    private var window: NSWindow?
    private var bridge: ToolBridgeClient?
    private var observers: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "").contains(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) else {
            NSApp.terminate(nil); return
        }
        controller.showSettings = { [weak self] in self?.showSettings() }
        controller.hideSettings = { [weak self] in self?.window?.orderOut(nil) }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "pip", accessibilityDescription: "UniversalPiP")
        item.button?.toolTip = "UniversalPiP"; self.item = item
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        if !controller.isPreview {
            let bridge = ToolBridgeClient(tool: .universalPiP, state: { [weak self] in
                (self?.controller.session.isEnabled ?? false, self?.controller.session.state.label ?? "Bereit")
            }, command: { [weak self] command in
                guard let self else { return }
                switch command {
                case .openSettings: self.showSettings()
                case .setEnabled(let enabled):
                    if enabled { self.controller.resume() } else { self.controller.session.pause() }
                case .quit: NSApp.terminate(nil)
                case .requestStatus: break
                }
            }, menuVisible: { [weak item] visible in item?.isVisible = visible })
            self.bridge = bridge; bridge.start()
            controller.statusChanged = { [weak bridge] in bridge?.publishStatus() }
            let center = NSWorkspace.shared.notificationCenter
            observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.controller.session.willSleep() }
            })
            observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.controller.session.didWake() }
            })
        }
        showSettings()
        #if DEBUG
        if let index = CommandLine.arguments.firstIndex(of: "--capture-probe-title"), CommandLine.arguments.count > index + 3 {
            captureProbe = DebugCaptureProbe(controller: controller, title: CommandLine.arguments[index + 1],
                report: URL(fileURLWithPath: CommandLine.arguments[index + 2]), seconds: Double(CommandLine.arguments[index + 3]) ?? 30)
        }
        #endif
        if controller.isPreview { SettingsPreview.present(window) }
        if let index = CommandLine.arguments.firstIndex(of: "--diagnostics-report"), CommandLine.arguments.indices.contains(index + 1) {
            let destination = CommandLine.arguments[index + 1]
            // Only our own state; no window titles, screenshots or third-party UI inspection.
            let report: [String: Any] = ["permissionGranted": controller.permissionGranted,
                "state": String(describing: controller.session.state), "selectionWindowVisible": window?.isVisible ?? false,
                "captureRequested": controller.session.source != nil]
            if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: destination), options: .atomic)
            }
        }
    }
    @objc func showSettings() {
        if window == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 860, height: 620), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.title = "UniversalPiP"; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: PiPSettingsView(controller: controller)); window.center(); self.window = window
        }
        window?.makeKeyAndOrderFront(nil); NSApp.activate()
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems(); menu.autoenablesItems = false
        menu.addItem(NSMenuItem(title: controller.session.state.label, action: nil, keyEquivalent: ""))
        let choose = NSMenuItem(title: "Fenster auswählen …", action: #selector(showSettings), keyEquivalent: ","); choose.target = self; menu.addItem(choose)
        if controller.session.source != nil {
            let pause = NSMenuItem(title: controller.session.isEnabled ? "Pausieren" : "Fortsetzen", action: #selector(toggle), keyEquivalent: "p")
            pause.target = self; menu.addItem(pause)
            let stop = NSMenuItem(title: "Vorschau schließen", action: #selector(closePiP), keyEquivalent: "w"); stop.target = self; menu.addItem(stop)
        }
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "UniversalPiP beenden", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; quit.isEnabled = true; menu.addItem(quit)
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func toggle() { if controller.session.isEnabled { controller.session.pause() } else { controller.resume() } }
    @objc private func closePiP() { controller.close() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        bridge?.stop(); controller.prepareForTermination()
        // This app has no recordings to flush. The OS releases capture resources on exit;
        // waiting for ScreenCaptureKit here can leave all quit actions disabled indefinitely.
        Logger(subsystem: "tech.highbyte.macfitkit.UniversalPiP", category: "lifecycle").info("App termination approved immediately")
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        bridge?.stop(); controller.panel.dispose()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}
