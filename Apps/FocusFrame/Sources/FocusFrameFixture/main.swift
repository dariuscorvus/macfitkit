import AppKit

@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [NSWindow] = []
    private var labels: [ObjectIdentifier: NSTextField] = [:]
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        let reset = NSMenuItem(title: "Testfenster zurücksetzen", action: #selector(resetWindows), keyEquivalent: "r")
        reset.target = self
        appMenu.addItem(reset)
        appMenu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        resetWindows()
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func resetWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()
        labels.removeAll()
        let origin = NSScreen.screens.first?.visibleFrame.origin ?? .zero
        for index in 0..<2 {
            let window = NSWindow(contentRect: CGRect(x: origin.x + 120 + Double(index) * 480,
                y: origin.y + 180 + Double(index) * 80, width: 440, height: 320),
                styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "FocusFrame-Testfenster \(index == 0 ? "A" : "B")"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let hint = NSTextField(wrappingLabelWithString: "An der Titelleiste ziehen. Die Buttons erzeugen definierte Fensteränderungen über AppKit.")
            let status = NSTextField(labelWithString: "")
            labels[ObjectIdentifier(window)] = status
            var controls: [NSView] = [hint, status]
            for (tag, title) in ["Verschieben", "Größe ändern", "Minimieren", "Schließen", "Vollbild", "Anderes Fenster fokussieren"].enumerated() {
                let button = NSButton(title: title, target: self, action: #selector(changeWindow(_:)))
                button.tag = tag
                controls.append(button)
            }
            let stack = NSStackView(views: controls)
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 10
            window.contentView?.addSubview(stack)
            stack.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
                stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
                stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20)
            ])
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
            updateLabel(window)
        }
    }
    @objc private func changeWindow(_ sender: NSButton) {
        guard let window = sender.window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        switch sender.tag {
        case 0: window.setFrameOrigin(CGPoint(x: window.frame.minX + 90, y: window.frame.minY + 40))
        case 1: window.setFrame(CGRect(origin: window.frame.origin,
            size: CGSize(width: window.frame.width + 50, height: window.frame.height + 20)), display: true)
        case 2: window.miniaturize(nil)
        case 3: window.close()
        case 4: window.toggleFullScreen(nil)
        case 5: windows.first { $0 !== window }?.makeKeyAndOrderFront(nil)
        default: break
        }
    }
    func windowDidMove(_ notification: Notification) { if let window = notification.object as? NSWindow { updateLabel(window) } }
    func windowDidResize(_ notification: Notification) { if let window = notification.object as? NSWindow { updateLabel(window) } }
    private func updateLabel(_ window: NSWindow) {
        labels[ObjectIdentifier(window)]?.stringValue = String(format: "Position %.0f / %.0f · Größe %.0f × %.0f pt",
            window.frame.minX, window.frame.minY, window.frame.width, window.frame.height)
    }
}

let app = NSApplication.shared
let delegate = FixtureDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
