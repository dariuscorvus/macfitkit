import AppKit
import FocusFrameCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTabViewDelegate, NSWindowDelegate {
    var onToggleFrame: (() -> Void)?
    var onOpenDiagnostics: (() -> Void)?
    private let store: PreferencesStore
    private let preview = PreviewView(frame: .zero)
    private var effectActions: [Int: () -> Void] = [:]
    private var effectSync: [() -> Void] = []
    private let tabs = NSTabView()
    private var previewHeight: NSLayoutConstraint!
    private let colorWell = NSColorWell()
    private var sliders: [NSSlider] = []
    private var values: [NSTextField] = []
    private let login = NSButton(checkboxWithTitle: "Bei Anmeldung starten", target: nil, action: nil)
    private let shortcut = NSButton(checkboxWithTitle: "Rahmen mit ⌃⌥F ein-/ausschalten", target: nil, action: nil)
    private let frameToggle = NSButton(checkboxWithTitle: "Rahmen aktiv", target: nil, action: nil)
    private let shortcutStatus = NSTextField(wrappingLabelWithString: "")
    private var shortcutRegistered = false
    private var shortcutPresses = 0
    private var frameEnabled = true
    private let fullScreen = NSButton(checkboxWithTitle: "Rahmen im Vollbild ausblenden", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()

    init(store: PreferencesStore) {
        self.store = store
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 740),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "FocusFrame – Einstellungen"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.minSize = NSSize(width: 620, height: 560)
        tabs.delegate = self
        let appearance = NSTabViewItem(identifier: "appearance")
        appearance.label = "Darstellung"
        appearance.view = scrollPage(appearancePage())
        tabs.addTabViewItem(appearance)
        for (id, title, page) in [("effects", "Effekte", effectsPage()), ("animation", "Animation", animationPage())] {
            let item = NSTabViewItem(identifier: id); item.label = title; item.view = scrollPage(page)
            tabs.addTabViewItem(item)
        }
        let behavior = NSTabViewItem(identifier: "behavior")
        behavior.label = "Verhalten"
        behavior.view = scrollPage(behaviorPage())
        tabs.addTabViewItem(behavior)
        window.contentView?.addSubview(preview)
        preview.translatesAutoresizingMaskIntoConstraints = false
        previewHeight = preview.heightAnchor.constraint(equalToConstant: 190)
        window.contentView?.addSubview(tabs)
        tabs.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabs.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            tabs.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -16),
            preview.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 16),
            preview.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -16),
            preview.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 16),
            previewHeight,
            tabs.topAnchor.constraint(equalTo: preview.bottomAnchor, constant: 12),
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
        updatePreviewVisibility()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func appearancePage() -> NSView {
        colorWell.target = self
        colorWell.action = #selector(changeColor)
        colorWell.widthAnchor.constraint(equalToConstant: 80).isActive = true
        let colorLabel = NSTextField(labelWithString: "Rahmenfarbe")
        colorLabel.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let colorRow = NSStackView(views: [colorLabel, colorWell])
        colorRow.spacing = 12
        var views: [NSView] = [colorRow]
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

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) { updatePreviewVisibility() }
    func windowWillClose(_ notification: Notification) { preview.setActive(false) }
    func windowDidChangeOcclusionState(_ notification: Notification) { updatePreviewVisibility() }
    private func updatePreviewVisibility() {
        let visible = (tabs.selectedTabViewItem?.identifier as? String) != "behavior"
        preview.isHidden = !visible
        previewHeight?.constant = visible ? 190 : 0
        preview.setActive(visible && window?.isVisible == true && window?.occlusionState.contains(.visible) == true)
    }
    private func scrollPage(_ page: NSView) -> NSView {
        let scroll = NSScrollView(); scroll.hasVerticalScroller = true
        scroll.documentView = page
        page.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            page.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            page.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        return scroll
    }
    private func effectAction(_ action: @escaping () -> Void) -> Int {
        let id = effectActions.count; effectActions[id] = action; return id
    }
    @objc private func changeEffect(_ sender: NSControl) { effectActions[sender.tag]?(); sync() }
    private func mutate(_ change: (inout Appearance) -> Void) {
        var a = store.value.appearance; change(&a); store.value.appearance = a.normalized
    }
    private func effectSlider(_ title: String, _ key: WritableKeyPath<Appearance, Double>,
                              _ range: ClosedRange<Double>, percent: Bool = false, unit: String = "pt") -> NSView {
        let slider = NSSlider(value: 0, minValue: range.lowerBound, maxValue: range.upperBound,
                              target: self, action: #selector(changeEffect(_:)))
        slider.isContinuous = true; slider.setAccessibilityLabel(title)
        slider.widthAnchor.constraint(equalToConstant: 240).isActive = true
        let value = NSTextField(labelWithString: "")
        value.widthAnchor.constraint(equalToConstant: 74).isActive = true
        slider.tag = effectAction { [weak self, weak slider] in
            guard let self, let slider else { return }
            self.mutate { $0[keyPath: key] = slider.doubleValue / (percent ? 100 : 1) }
        }
        effectSync.append { [weak self, weak slider, weak value] in
            guard let self else { return }; let n = self.store.value.appearance[keyPath: key] * (percent ? 100 : 1)
            slider?.doubleValue = n
            value?.stringValue = String(format: percent ? "%.0f %%" : "%.1f \(unit)", n)
        }
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        let row = NSStackView(views: [label, slider, value]); row.spacing = 8; return row
    }
    private func effectCheck(_ title: String, _ key: WritableKeyPath<Appearance, Bool>) -> NSView {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(changeEffect(_:)))
        button.tag = effectAction { [weak self, weak button] in
            self?.mutate { $0[keyPath: key] = button?.state == .on }
        }
        effectSync.append { [weak self, weak button] in button?.state = self?.store.value.appearance[keyPath: key] == true ? .on : .off }
        return button
    }
    private func effectChoice<T: Equatable>(_ title: String, _ key: WritableKeyPath<Appearance, T>,
                                           _ choices: [(String,T)]) -> NSView {
        let popup = NSPopUpButton(); popup.addItems(withTitles: choices.map { $0.0 })
        popup.target = self; popup.action = #selector(changeEffect(_:))
        popup.tag = effectAction { [weak self, weak popup] in
            guard let self, let popup, choices.indices.contains(popup.indexOfSelectedItem) else { return }
            self.mutate { a in
                if title == "Farbverlauf", a.gradient.mode == .off {
                    a.gradient.first = EffectColor(a.red,a.green,a.blue)
                }
                a[keyPath: key] = choices[popup.indexOfSelectedItem].1
            }
        }
        effectSync.append { [weak self, weak popup] in
            guard let self else { return }
            popup?.selectItem(at: choices.firstIndex { $0.1 == self.store.value.appearance[keyPath: key] } ?? 0)
        }
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return NSStackView(views: [label,popup])
    }
    private func effectColor(_ title: String, _ key: WritableKeyPath<Appearance, EffectColor>) -> NSView {
        let well = NSColorWell(); well.widthAnchor.constraint(equalToConstant: 80).isActive = true
        well.target = self; well.action = #selector(changeEffect(_:))
        well.tag = effectAction { [weak self, weak well] in
            guard let c = well?.color.usingColorSpace(.sRGB) else { return }
            self?.mutate { $0[keyPath: key] = EffectColor(c.redComponent,c.greenComponent,c.blueComponent) }
        }
        effectSync.append { [weak self, weak well] in well?.color = self?.store.value.appearance[keyPath: key].nsColor ?? .black }
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 180).isActive = true
        return NSStackView(views: [label,well])
    }
    private func resetEffect(_ title: String, _ change: @escaping (inout Appearance) -> Void) -> NSView {
        let button = NSButton(title: title, target: self, action: #selector(changeEffect(_:)))
        button.tag = effectAction { [weak self] in self?.mutate(change) }; return button
    }
    private func heading(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title); label.font = .boldSystemFont(ofSize: 14); return label
    }
    private func effectsPage() -> NSView {
        page([
            heading("Leuchten"),
            effectChoice("Leuchtmodus", \.light.mode, [("Aus",.off),("Glow",.glow),("Neon",.neon)]),
            effectSlider("Intensität", \.light.intensity, 0...100, percent: true),
            effectSlider("Leuchtweite", \.light.extent, 0...40),
            effectCheck("Rahmenfarbe übernehmen", \.light.followsFrame),
            effectColor("Eigene Leuchtfarbe", \.light.color),
            effectSlider("Neon-Kernstärke", \.light.coreWidth, 10...100, percent: true),
            effectSlider("Neon-Aufhellung", \.light.whitening, 0...100, percent: true),
            resetEffect("Leuchten zurücksetzen") { $0.light = LightEffect() },
            heading("Schatten"), effectCheck("Schatten anzeigen", \.shadow.enabled),
            effectColor("Schattenfarbe", \.shadow.color),
            effectSlider("Schatten-Deckkraft", \.shadow.opacity, 0...100, percent: true),
            effectSlider("Weichheit", \.shadow.blur, 0...40),
            effectSlider("Ausbreitung", \.shadow.spread, 0...20),
            effectSlider("Versatz horizontal", \.shadow.offsetX, -40...40),
            effectSlider("Versatz vertikal", \.shadow.offsetY, -40...40),
            resetEffect("Schatten zurücksetzen") { $0.shadow = ShadowEffect() },
            heading("Farbverlauf"),
            effectChoice("Farbverlauf", \.gradient.mode, [("Aus",.off),("Linear",.linear),("Umlaufend",.conic)]),
            effectColor("Erste Farbe", \.gradient.first), effectColor("Zweite Farbe", \.gradient.second),
            effectSlider("Winkel / Startwinkel", \.gradient.angle, 0...360, unit: "°"),
            resetEffect("Farbverlauf zurücksetzen") { $0.gradient = GradientEffect() }
        ])
    }
    private func animationPage() -> NSView {
        let trigger: [(String,AnimationTrigger)] = [("Nur beim Fokuswechsel",.focus),("Dauerhaft",.continuous)]
        return page([
            heading("Deckkraftanimation"),
            effectChoice("Animation", \.opacityAnimation.mode, [("Aus",.off),("Pulsieren",.pulse),("Blinken",.blink)]),
            effectSlider("Puls-Zyklusdauer", \.opacityAnimation.pulsePeriod, 0.5...10, unit: "s"),
            effectSlider("Puls-Minimum", \.opacityAnimation.pulseMinimum, 0...100, percent: true),
            effectSlider("Blink-Zyklusdauer", \.opacityAnimation.blinkPeriod, 0.5...5, unit: "s"),
            effectSlider("Blink-Minimum", \.opacityAnimation.blinkMinimum, 0...100, percent: true),
            effectSlider("Maximale Deckkraft", \.opacityAnimation.maximum, 0...100, percent: true),
            effectChoice("Deckkraft-Auslöser", \.opacityAnimation.trigger, trigger),
            effectSlider("Deckkraft-Fokusdauer", \.opacityAnimation.focusDuration, 0.5...5, unit: "s"),
            resetEffect("Deckkraftanimation zurücksetzen") { $0.opacityAnimation = OpacityEffect() },
            heading("Verlaufsrotation"), effectCheck("Farbverlauf rotieren", \.rotation.enabled),
            effectSlider("Umlaufdauer", \.rotation.period, 2...30, unit: "s"),
            effectCheck("Im Uhrzeigersinn", \.rotation.clockwise),
            effectChoice("Rotations-Auslöser", \.rotation.trigger, trigger),
            effectSlider("Rotations-Fokusdauer", \.rotation.focusDuration, 0.5...5, unit: "s"),
            resetEffect("Verlaufsrotation zurücksetzen") { $0.rotation = RotationEffect() },
            NSButton(title: "Fokuswechsel testen", target: self, action: #selector(testFocus)),
            NSTextField(wrappingLabelWithString: "Bei macOS ‘Bewegung reduzieren’ bleiben Effekte statisch. Rotation benötigt einen eingeschalteten Farbverlauf.")
        ])
    }
    @objc private func testFocus() { preview.renderer.animate(focusChanged: true) }

    private func behaviorPage() -> NSView {
        frameToggle.target = self; frameToggle.action = #selector(toggleFrame)
        frameToggle.state = frameEnabled ? .on : .off
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
        return page([frameToggle, login, loginStatus, openLogin, shortcut, shortcutStatus, fullScreen, title, scroll, buttons, diagnostics])
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
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
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
        effectSync.forEach { $0() }
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
        frameToggle.state = frameEnabled ? .on : .off
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

    @objc private func toggleFrame() { onToggleFrame?() }

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
    @objc private func resetAppearance() {
        mutate { a in let d = Appearance(); a.red=d.red; a.green=d.green; a.blue=d.blue
            a.opacity=d.opacity; a.width=d.width; a.radius=d.radius; a.gap=d.gap }
        sync()
    }
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
private final class PreviewView: EffectCanvas {
    var style = Appearance() { didSet { rebuild() } }
    private var active = false
    private var labelCenter = CGPoint.zero
    private var previewScale: CGFloat = 1
    func setActive(_ value: Bool) {
        active = value; renderer.setVisible(value)
    }
    override func layout() { super.layout(); rebuild() }
    private func rebuild() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let target = CGRect(x: 0,y: 0,width: 260,height: 70)
        let extent = EffectGeometry.overlayRect(for: target, appearance: style)
        let factor = min(1, min((bounds.width-20)/extent.width,(bounds.height-20)/extent.height))
        previewScale = factor
        let localTarget = target.offsetBy(dx: -extent.minX,dy: -extent.minY)
        labelCenter = CGPoint(x: bounds.midX + (localTarget.midX - extent.width/2) * factor,
                              y: bounds.midY + (localTarget.midY - extent.height/2) * factor)
        renderer.update(bounds: CGRect(origin: .zero,size: extent.size), target: localTarget,
                        style: style, scale: window?.backingScaleFactor ?? 2)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.root.anchorPoint = CGPoint(x: 0.5,y: 0.5)
        renderer.root.position = CGPoint(x: bounds.midX,y: bounds.midY)
        renderer.root.setAffineTransform(CGAffineTransform(scaleX: factor,y: factor))
        layer?.masksToBounds = true
        CATransaction.commit()
        renderer.setVisible(active)
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill(); bounds.fill()
        let attributes: [NSAttributedString.Key: Any] = [.font:NSFont.systemFont(ofSize:max(8,14*previewScale)),.foregroundColor:NSColor.labelColor]
        let text = "Vorschau" as NSString; let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: labelCenter.x-size.width/2,y:labelCenter.y-size.height/2),withAttributes:attributes)
    }
}
