import AppKit
import FocusFrameCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onOpenDiagnostics: (() -> Void)?
    private let store: PreferencesStore
    private let preview = PreviewView()
    private let colorWell = NSColorWell()
    private var sliders: [NSSlider] = []
    private var values: [NSTextField] = []
    private let login = NSButton(checkboxWithTitle: "Bei Anmeldung starten", target: nil, action: nil)
    private let shortcut = NSButton(checkboxWithTitle: "Rahmen mit ⌃⌥F ein-/ausschalten", target: nil, action: nil)
    private let shortcutStatus = NSTextField(wrappingLabelWithString: "")
    private var shortcutRegistered = false
    private var shortcutPresses = 0
    private var frameEnabled = true
    private let fullScreen = NSButton(checkboxWithTitle: "Rahmen im Vollbild ausblenden", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()

    init(store: PreferencesStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 540),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "FocusFrame – Einstellungen"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let tabs = NSTabView()
        let appearance = NSTabViewItem(identifier: "appearance")
        appearance.label = "Darstellung"
        appearance.view = appearancePage()
        tabs.addTabViewItem(appearance)
        let behavior = NSTabViewItem(identifier: "behavior")
        behavior.label = "Verhalten"
        behavior.view = behaviorPage()
        tabs.addTabViewItem(behavior)
        window.contentView?.addSubview(tabs)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -16),
            tabs.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16),
            tabs.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -16)
        ])
        sync()
        window.center()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshLogin),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }
    @objc private func refreshLogin() { syncLogin() }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func present() {
        sync()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func appearancePage() -> NSView {
        preview.heightAnchor.constraint(equalToConstant: 150).isActive = true
        colorWell.target = self
        colorWell.action = #selector(changeColor)
        colorWell.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let colorLabel = NSTextField(labelWithString: "Rahmenfarbe")
        colorLabel.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let colorRow = NSStackView(views: [colorLabel, colorWell])
        colorRow.spacing = 12
        var views: [NSView] = [preview, colorRow]
        let specifications: [(String, Double, Double)] = [
            ("Deckkraft", 10, 100), ("Stärke", 1, 12), ("Eckenradius", 0, 40), ("Abstand", 0, 20)
        ]
        for (index, specification) in specifications.enumerated() {
            let label = NSTextField(labelWithString: specification.0)
            label.widthAnchor.constraint(equalToConstant: 120).isActive = true
            let slider = NSSlider(value: 0, minValue: specification.1, maxValue: specification.2,
                                  target: self, action: #selector(changeSlider(_:)))
            slider.tag = index
            slider.isContinuous = true
            slider.setAccessibilityLabel(specification.0)
            slider.widthAnchor.constraint(equalToConstant: 240).isActive = true
            let value = NSTextField(labelWithString: "")
            value.widthAnchor.constraint(equalToConstant: 60).isActive = true
            sliders.append(slider)
            values.append(value)
            let row = NSStackView(views: [label, slider, value])
            row.spacing = 12
            views.append(row)
        }
        views.append(NSButton(title: "Darstellung zurücksetzen", target: self, action: #selector(resetAppearance)))
        return page(views)
    }

    private func behaviorPage() -> NSView {
        login.target = self; login.action = #selector(changeLogin)
        shortcut.target = self; shortcut.action = #selector(changeShortcut)
        fullScreen.target = self; fullScreen.action = #selector(changeFullScreen)
        let openLogin = NSButton(title: "Anmeldeobjekte öffnen …", target: self, action: #selector(openLoginSettings))
        let title = NSTextField(labelWithString: "Für diese Apps keinen Rahmen anzeigen:")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.width = 460
        table.addTableColumn(column)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true
        let add = NSButton(title: "App hinzufügen …", target: self, action: #selector(addExcludedApp))
        let remove = NSButton(title: "Entfernen", target: self, action: #selector(removeExcludedApp))
        let buttons = NSStackView(views: [add, remove])
        buttons.spacing = 12
        let diagnostics = NSButton(title: "Diagnose …", target: self, action: #selector(openDiagnostics))
        return page([login, loginStatus, openLogin, shortcut, shortcutStatus, fullScreen, title, scroll, buttons, diagnostics])
    }

    private func page(_ views: [NSView]) -> NSView {
        let container = NSView()
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20)
        ])
        for view in views where view === preview || view is NSScrollView || view === loginStatus || view === shortcutStatus {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return container
    }

    func sync() {
        let appearance = store.value.appearance.normalized
        colorWell.color = NSColor(srgbRed: appearance.red, green: appearance.green, blue: appearance.blue, alpha: 1)
        let numbers = [appearance.opacity * 100, appearance.width, appearance.radius, appearance.gap]
        for (index, slider) in sliders.enumerated() {
            slider.doubleValue = numbers[index]
            values[index].stringValue = String(format: index == 0 ? "%.0f %%" : "%.1f pt", numbers[index])
        }
        preview.style = appearance
        shortcut.state = store.value.shortcutEnabled ? .on : .off
        fullScreen.state = store.value.hideInFullScreen ? .on : .off
        syncLogin()
        syncShortcutStatus()
        table.reloadData()
    }

    private func syncLogin() {
        let status = SMAppService.mainApp.status
        login.state = status == .enabled ? .on : (status == .requiresApproval ? .mixed : .off)
        loginStatus.stringValue = status == .requiresApproval ? "Bitte in den macOS-Anmeldeobjekten bestätigen." :
            (status == .enabled ? "Start bei Anmeldung ist aktiv." : "Start bei Anmeldung ist ausgeschaltet.")
    }

    func updateShortcutStatus(registered: Bool, frameEnabled: Bool, receivedPress: Bool = false) {
        shortcutRegistered = registered
        self.frameEnabled = frameEnabled
        if receivedPress { shortcutPresses += 1 }
        syncShortcutStatus()
    }

    private func syncShortcutStatus() {
        guard shortcutRegistered else {
            shortcutStatus.stringValue = "Tastenkürzel ist ausgeschaltet. Zum Testen oben aktivieren."
            return
        }
        let state = frameEnabled ? "aktiv" : "pausiert"
        let receipt = shortcutPresses == 0 ? "Noch kein Tastendruck empfangen." : "Tastendruck empfangen (\(shortcutPresses))."
        shortcutStatus.stringValue = "Control + Option + F ist registriert. \(receipt) Rahmen: \(state)."
    }

    @objc private func changeColor() {
        guard let color = colorWell.color.usingColorSpace(.sRGB) else { return }
        var style = store.value.appearance
        style.red = color.redComponent
        style.green = color.greenComponent
        style.blue = color.blueComponent
        store.value.appearance = style
        sync()
    }
    @objc private func changeSlider(_ sender: NSSlider) {
        switch sender.tag {
        case 0: store.value.appearance.opacity = sender.doubleValue / 100
        case 1: store.value.appearance.width = sender.doubleValue
        case 2: store.value.appearance.radius = sender.doubleValue
        case 3: store.value.appearance.gap = sender.doubleValue
        default: return
        }
        sync()
    }
    @objc private func resetAppearance() { store.value.appearance = Appearance(); sync() }
    @objc private func changeShortcut() { store.value.shortcutEnabled = shortcut.state == .on; sync() }
    @objc private func changeFullScreen() { store.value.hideInFullScreen = fullScreen.state == .on; sync() }
    @objc private func changeLogin() {
        do {
            if login.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { showError(error.localizedDescription) }
        syncLogin()
    }
    @objc private func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    @objc private func openDiagnostics() { onOpenDiagnostics?() }

    func numberOfRows(in tableView: NSTableView) -> Int { store.value.excludedApps.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = store.value.excludedApps[row]
        let name = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier).map {
            FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "")
        } ?? "Nicht verfügbare App (\(identifier))"
        return NSTextField(labelWithString: name)
    }
    @objc private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Ausschließen"
        guard let window else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            guard let identifier = Bundle(url: url)?.bundleIdentifier else {
                self.showError("Diese App konnte nicht erkannt werden.")
                return
            }
            self.store.value.excludedApps = Array(Set(self.store.value.excludedApps + [identifier])).sorted()
            self.sync()
        }
    }
    @objc private func removeExcludedApp() {
        let row = table.selectedRow
        guard store.value.excludedApps.indices.contains(row) else { return }
        store.value.excludedApps.remove(at: row)
        sync()
    }
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Die Einstellung konnte nicht geändert werden."
        alert.informativeText = message
        if let window { alert.beginSheetModal(for: window) }
    }
}

@MainActor
private final class PreviewView: NSView {
    var style = Appearance() { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
        let target = bounds.insetBy(dx: 50, dy: 35)
        NSColor.controlBackgroundColor.setFill()
        NSBezierPath(roundedRect: target, xRadius: 10, yRadius: 10).fill()
        BorderDrawing.draw(around: target, appearance: style)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NSColor.labelColor]
        let text = "Vorschau" as NSString
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}
