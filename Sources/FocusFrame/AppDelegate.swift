import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let manager = FocusManager()
    private var statusItem: NSStatusItem?
    private let permissionItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let enabledItem = NSMenuItem(title: "Rahmen aktiv", action: #selector(toggleEnabled), keyEquivalent: "")
    private let colors: [(String, NSColor)] = [("Orange", .systemOrange), ("Blau", .systemBlue),
                                             ("Grün", .systemGreen), ("Pink", .systemPink)]

    func applicationDidFinishLaunching(_ notification: Notification) {
        let savedWidth = UserDefaults.standard.integer(forKey: "borderWidth")
        manager.width = [2, 3, 4, 6].contains(savedWidth) ? CGFloat(savedWidth) : 3
        let savedColor = UserDefaults.standard.integer(forKey: "borderColor")
        manager.color = colors.indices.contains(savedColor) ? colors[savedColor].1 : colors[0].1
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
        let colorMenu = NSMenu()
        for (index, color) in colors.enumerated() {
            let entry = NSMenuItem(title: color.0, action: #selector(selectColor(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = index
            entry.state = manager.color == color.1 ? .on : .off
            colorMenu.addItem(entry)
        }
        let colorItem = NSMenuItem(title: "Farbe", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)
        let widthMenu = NSMenu()
        for width in [2, 3, 4, 6] {
            let entry = NSMenuItem(title: "\(width) pt", action: #selector(selectWidth(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = width
            entry.state = manager.width == CGFloat(width) ? .on : .off
            widthMenu.addItem(entry)
        }
        let widthItem = NSMenuItem(title: "Stärke", action: nil, keyEquivalent: "")
        widthItem.submenu = widthMenu
        menu.addItem(widthItem)
        menu.addItem(.separator())
        for (title, action) in [("Bedienungshilfen erlauben …", #selector(requestPermission)),
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
        manager.start()
        Logger(subsystem: "de.highbytetech.FocusFrame", category: "Lifecycle")
            .info("Started; accessibility trusted: \(self.manager.accessibility.isTrusted)")
        if !manager.accessibility.isTrusted { manager.accessibility.requestPermission() }
    }

    func applicationWillTerminate(_ notification: Notification) { manager.stop() }

    @objc private func toggleEnabled() {
        manager.enabled.toggle()
        enabledItem.state = manager.enabled ? .on : .off
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        manager.color = colors[sender.tag].1
        UserDefaults.standard.set(sender.tag, forKey: "borderColor")
        updateSelection(sender)
    }

    @objc private func selectWidth(_ sender: NSMenuItem) {
        manager.width = CGFloat(sender.tag)
        UserDefaults.standard.set(sender.tag, forKey: "borderWidth")
        updateSelection(sender)
    }

    private func updateSelection(_ sender: NSMenuItem) {
        sender.menu?.items.forEach { $0.state = $0 === sender ? .on : .off }
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
