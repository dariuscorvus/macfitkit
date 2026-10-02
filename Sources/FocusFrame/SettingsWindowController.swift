import AppKit
import FocusFrameCore
import ServiceManagement
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSTextFieldDelegate {
    var onToggleFrame: (() -> Void)?
    var onOpenDiagnostics: (() -> Void)?
    var onTestFocus: (() -> Void)?
    private let store: PreferencesStore
    private var effectActions: [Int: () -> Void] = [:]
    private var effectSync: [() -> Void] = []
    private let sidebar = NSTableView()
    private let detail = NSViewController()
    private var sections: [(title: String, symbol: String, summary: String, content: NSView)] = []
    private let colorWell = NSColorWell()
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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 680),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "FocusFrame – Einstellungen"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.minSize = NSSize(width: 860, height: 540)
        sections = [
            ("Darstellung", "viewfinder", "Änderungen erscheinen direkt am Rahmen dieses Fensters.", appearancePage()),
            ("Leuchten", "lightbulb", "Ein weicher Glow oder ein heller Neon-Kern hebt den Rahmen hervor.", lightPage()),
            ("Schatten", "square.on.square", "Ein Schatten entlang der Kontur gibt dem Rahmen mehr Tiefe.", shadowPage()),
            ("Farbverlauf", "paintpalette", "Zwei Farben als linearer oder umlaufender Verlauf.", gradientPage()),
            ("Animationen", "waveform.path", "Bewegung beim Fokuswechsel oder dauerhaft. Änderungen sind direkt sichtbar.", animationPage()),
            ("Verhalten", "switch.2", "Steuere den Rahmen, Tastenkürzel und den Start bei Anmeldung.", behaviorPage()),
            ("App-Ausnahmen", "app.badge", "Für ausgewählte Apps bleibt der Rahmen ausgeblendet.", exclusionsPage())
        ]
        let split = NSSplitViewController()
        let navigation = NSViewController()
        navigation.view = navigationView()
        let navigationItem = NSSplitViewItem(sidebarWithViewController: navigation)
        navigationItem.minimumThickness = 210
        navigationItem.maximumThickness = 250
        navigationItem.canCollapse = false
        split.addSplitViewItem(navigationItem)
        detail.view = NSView()
        split.addSplitViewItem(NSSplitViewItem(viewController: detail))
        window.contentViewController = split
        window.setContentSize(NSSize(width: 960, height: 680))
        sidebar.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        selectSection(0)
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
        window?.makeKeyAndOrderFront(nil)
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
        views += [
            effectSlider("Deckkraft", \.opacity, 10...100, percent: true),
            effectSlider("Stärke", \.width, 1...100),
            effectSlider("Eckenradius", \.radius, 0...300),
            effectSlider("Abstand", \.gap, 0...200)
        ]
        views.append(NSButton(title: "Darstellung zurücksetzen", target: self, action: #selector(resetAppearance)))
        return section("Rahmen", views)
    }

    private func navigationView() -> NSView {
        let background = NSVisualEffectView()
        background.material = .sidebar
        background.blendingMode = .behindWindow
        let title = NSTextField(labelWithString: "FocusFrame")
        title.font = .systemFont(ofSize: 21, weight: .semibold)
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("section"))
        column.width = 190
        sidebar.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        sidebar.addTableColumn(column)
        sidebar.headerView = nil
        sidebar.backgroundColor = .clear
        sidebar.style = .sourceList
        sidebar.rowHeight = 38
        sidebar.intercellSpacing = NSSize(width: 0, height: 4)
        sidebar.dataSource = self
        sidebar.delegate = self
        sidebar.setAccessibilityLabel("Einstellungsbereiche")
        scroll.documentView = sidebar
        for view in [title, scroll] { background.addSubview(view); view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 20),
            title.topAnchor.constraint(equalTo: background.topAnchor, constant: 22),
            scroll.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 20),
            scroll.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -12)
        ])
        return background
    }

    private func selectSection(_ index: Int) {
        guard sections.indices.contains(index) else { return }
        let section = sections[index]
        let title = NSTextField(labelWithString: section.title)
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        let description = NSTextField(wrappingLabelWithString: section.summary)
        description.textColor = .secondaryLabelColor
        detail.view.subviews.forEach { $0.removeFromSuperview() }
        let scroll = scrollPage(page([title, description, section.content]))
        detail.view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: detail.view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: detail.view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: detail.view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: detail.view.bottomAnchor)
        ])
        sync()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if notification.object as? NSTableView === sidebar { selectSection(sidebar.selectedRow) }
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
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        let preferredWidth = slider.widthAnchor.constraint(equalToConstant: 210)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
        let value = NSTextField(string: "")
        value.widthAnchor.constraint(equalToConstant: 70).isActive = true
        value.identifier = NSUserInterfaceItemIdentifier(title)
        value.alignment = .right
        value.delegate = self
        value.target = self
        value.action = #selector(changeEffect(_:))
        value.setAccessibilityLabel("\(title) – Zahlenwert")
        let unitLabel = NSTextField(labelWithString: percent ? "%" : unit)
        unitLabel.widthAnchor.constraint(equalToConstant: 20).isActive = true
        slider.tag = effectAction { [weak self, weak slider] in
            guard let self, let slider else { return }
            self.mutate { $0[keyPath: key] = slider.doubleValue / (percent ? 100 : 1) }
        }
        value.tag = effectAction { [weak self, weak value] in
            guard let self, let value else { return }
            let text = value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            // Accept both decimal comma and decimal point; reject incomplete/nonfinite values.
            guard let number = Double(text.replacingOccurrences(of: ",", with: ".")), number.isFinite else { return }
            let bounded = min(range.upperBound, max(range.lowerBound, number))
            self.mutate { $0[keyPath: key] = bounded / (percent ? 100 : 1) }
        }
        effectSync.append { [weak self, weak slider, weak value] in
            guard let self else { return }; let n = self.store.value.appearance[keyPath: key] * (percent ? 100 : 1)
            slider?.doubleValue = n
            if value?.currentEditor() == nil {
                value?.stringValue = Self.numberString(n)
            }
        }
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        let row = NSStackView(views: [label, slider, value, unitLabel]); row.spacing = 8; return row
    }
    private static func numberString(_ number: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 3
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        changeEffect(field)
        // Restore the accepted value even for invalid text or an out-of-range input.
        sync()
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
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 150).isActive = true
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
        let label = NSTextField(labelWithString: title); label.widthAnchor.constraint(equalToConstant: 150).isActive = true
        return NSStackView(views: [label,well])
    }
    private func resetEffect(_ title: String, _ change: @escaping (inout Appearance) -> Void) -> NSView {
        let button = NSButton(title: title, target: self, action: #selector(changeEffect(_:)))
        button.tag = effectAction { [weak self] in self?.mutate(change) }; return button
    }
    private func heading(_ title: String) -> NSView {
        let label = NSTextField(labelWithString: title); label.font = .boldSystemFont(ofSize: 14); return label
    }
    private func conditional(_ views: [NSView], when visible: @escaping (Appearance) -> Bool) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.detachesHiddenViews = true
        for view in views where !(view is NSButton) { view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        effectSync.append { [weak self, weak stack] in
            guard let self else { return }
            stack?.isHidden = !visible(self.store.value.appearance)
        }
        return stack
    }
    private func section(_ title: String, _ views: [NSView]) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderColor = .separatorColor
        box.borderWidth = 0.5
        box.cornerRadius = 10
        box.fillColor = .controlBackgroundColor
        box.titlePosition = .noTitle
        box.contentViewMargins = .zero
        let body = page([heading(title)] + views)
        box.addSubview(body)
        body.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            body.topAnchor.constraint(equalTo: box.topAnchor),
            body.bottomAnchor.constraint(equalTo: box.bottomAnchor)
        ])
        return box
    }
    private func lightPage() -> NSView {
        section("Leuchtmodus", [
            effectChoice("Leuchtmodus", \.light.mode, [("Aus",.off),("Glow",.glow),("Neon",.neon)]),
            conditional([
                effectSlider("Intensität", \.light.intensity, 0...100, percent: true),
                effectSlider("Leuchtweite", \.light.extent, 0...200),
                effectCheck("Rahmenfarbe übernehmen", \.light.followsFrame),
                conditional([effectColor("Eigene Leuchtfarbe", \.light.color)]) { !$0.light.followsFrame },
                conditional([
                    effectSlider("Kernstärke", \.light.coreWidth, 10...100, percent: true),
                    effectSlider("Aufhellung", \.light.whitening, 0...100, percent: true)
                ]) { $0.light.mode == .neon }
            ]) { $0.light.mode != .off },
            resetEffect("Leuchten zurücksetzen") { $0.light = LightEffect() }
        ])
    }
    private func shadowPage() -> NSView {
        section("Fensterschatten", [
            effectCheck("Schatten anzeigen", \.shadow.enabled),
            conditional([
                effectColor("Farbe", \.shadow.color),
                effectSlider("Deckkraft", \.shadow.opacity, 0...100, percent: true),
                effectSlider("Weichheit", \.shadow.blur, 0...200),
                effectSlider("Ausbreitung", \.shadow.spread, 0...200),
                effectSlider("Versatz horizontal", \.shadow.offsetX, -200...200),
                effectSlider("Versatz vertikal", \.shadow.offsetY, -200...200)
            ]) { $0.shadow.enabled },
            resetEffect("Schatten zurücksetzen") { $0.shadow = ShadowEffect() }
        ])
    }
    private func gradientPage() -> NSView {
        section("Farben und Richtung", [
            effectChoice("Farbverlauf", \.gradient.mode, [("Aus",.off),("Linear",.linear),("Umlaufend",.conic)]),
            conditional([
                effectColor("Erste Farbe", \.gradient.first),
                effectColor("Zweite Farbe", \.gradient.second),
                effectSlider("Winkel / Startwinkel", \.gradient.angle, 0...360, unit: "°")
            ]) { $0.gradient.mode != .off },
            resetEffect("Farbverlauf zurücksetzen") { $0.gradient = GradientEffect() }
        ])
    }
    private func animationPage() -> NSView {
        let trigger: [(String,AnimationTrigger)] = [("Nur beim Fokuswechsel",.focus),("Dauerhaft",.continuous)]
        return page([
            section("Deckkraft", [
                effectChoice("Animation", \.opacityAnimation.mode, [("Aus",.off),("Pulsieren",.pulse),("Blinken",.blink)]),
                conditional([
                    conditional([
                        effectSlider("Zyklusdauer", \.opacityAnimation.pulsePeriod, 0.5...10, unit: "s"),
                        effectSlider("Minimum", \.opacityAnimation.pulseMinimum, 0...100, percent: true)
                    ]) { $0.opacityAnimation.mode == .pulse },
                    conditional([
                        effectSlider("Zyklusdauer", \.opacityAnimation.blinkPeriod, 0.5...5, unit: "s"),
                        effectSlider("Minimum", \.opacityAnimation.blinkMinimum, 0...100, percent: true)
                    ]) { $0.opacityAnimation.mode == .blink },
                    effectSlider("Maximum", \.opacityAnimation.maximum, 0...100, percent: true),
                    effectChoice("Auslöser", \.opacityAnimation.trigger, trigger),
                    conditional([effectSlider("Fokusdauer", \.opacityAnimation.focusDuration, 0.5...5, unit: "s")]) {
                        $0.opacityAnimation.trigger == .focus
                    }
                ]) { $0.opacityAnimation.mode != .off },
                resetEffect("Deckkraftanimation zurücksetzen") { $0.opacityAnimation = OpacityEffect() }
            ]),
            section("Verlaufsrotation", [
                effectCheck("Farbverlauf rotieren", \.rotation.enabled),
                conditional([
                    effectSlider("Umlaufdauer", \.rotation.period, 2...30, unit: "s"),
                    effectCheck("Im Uhrzeigersinn", \.rotation.clockwise),
                    effectChoice("Auslöser", \.rotation.trigger, trigger),
                    conditional([effectSlider("Fokusdauer", \.rotation.focusDuration, 0.5...5, unit: "s")]) {
                        $0.rotation.trigger == .focus
                    },
                    NSTextField(wrappingLabelWithString: "Rotation benötigt einen eingeschalteten Farbverlauf.")
                ]) { $0.rotation.enabled },
                resetEffect("Verlaufsrotation zurücksetzen") { $0.rotation = RotationEffect() }
            ]),
            NSButton(title: "Fokuswechsel testen", target: self, action: #selector(testFocus)),
            NSTextField(wrappingLabelWithString: "Bei macOS ‘Bewegung reduzieren’ bleiben Effekte statisch.")
        ], inset: 0)
    }
    @objc private func testFocus() { onTestFocus?() }

    private func behaviorPage() -> NSView {
        frameToggle.target = self; frameToggle.action = #selector(toggleFrame)
        frameToggle.state = frameEnabled ? .on : .off
        login.target = self; login.action = #selector(changeLogin)
        shortcut.target = self; shortcut.action = #selector(changeShortcut)
        fullScreen.target = self; fullScreen.action = #selector(changeFullScreen)
        let openLogin = NSButton(title: "Anmeldeobjekte öffnen …", target: self, action: #selector(openLoginSettings))
        return page([
            section("Rahmen", [frameToggle, fullScreen]),
            section("Tastenkürzel", [shortcut, shortcutStatus]),
            section("Anmeldestart", [login, loginStatus, openLogin]),
            NSButton(title: "Diagnose …", target: self, action: #selector(openDiagnostics))
        ], inset: 0)
    }

    private func exclusionsPage() -> NSView {
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
        return section("Ausgeschlossene Apps", [scroll, buttons])
    }

    private func page(_ views: [NSView], inset: CGFloat = 20) -> NSView {
        let container = SettingsDocumentView()
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset)
        ])
        for view in views where !(view is NSButton) {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return container
    }

    func sync() {
        let appearance = store.value.appearance.normalized
        colorWell.color = NSColor(srgbRed: appearance.red, green: appearance.green, blue: appearance.blue, alpha: 1)
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

    func numberOfRows(in tableView: NSTableView) -> Int {
        tableView === sidebar ? sections.count : store.value.excludedApps.count
    }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView === sidebar {
            let section = sections[row]
            let image = NSImageView()
            image.image = NSImage(systemSymbolName: section.symbol, accessibilityDescription: nil)
            image.contentTintColor = .controlAccentColor
            image.widthAnchor.constraint(equalToConstant: 22).isActive = true
            image.heightAnchor.constraint(equalToConstant: 22).isActive = true
            let label = NSTextField(labelWithString: section.title)
            let cell = NSTableCellView()
            let row = NSStackView(views: [image, label]); row.spacing = 10
            cell.addSubview(row); row.translatesAutoresizingMaskIntoConstraints = false
            cell.textField = label; cell.imageView = image
            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                row.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
                row.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
            return cell
        }
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

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
