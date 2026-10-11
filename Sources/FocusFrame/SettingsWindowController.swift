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
    private let shortcut = NSButton(checkboxWithTitle: "Tastenkürzel aktivieren", target: nil, action: nil)
    private let frameToggle = NSButton(checkboxWithTitle: "Rahmen aktiv", target: nil, action: nil)
    private let shortcutStatus = NSTextField(wrappingLabelWithString: "")
    private var shortcutRegistered = false
    private var shortcutPresses = 0
    private var frameEnabled = true
    private let fullScreen = NSButton(checkboxWithTitle: "Rahmen im Vollbild ausblenden", target: nil, action: nil)
    private let loginStatus = NSTextField(wrappingLabelWithString: "")
    private let animationPreview = AnimationPreview(frame: .zero)
    private let profilePicker = NSPopUpButton()
    private let keyPicker = NSPopUpButton()
    private let power = NSButton(checkboxWithTitle: "Animationen im Stromsparmodus aussetzen", target: nil, action: nil)
    private let modifierButtons = [("⌃ Control", UInt32(4096)), ("⌥ Option", UInt32(2048)), ("⌘ Command", UInt32(256)), ("⇧ Shift", UInt32(512))].map { title, mask in
        let b = NSButton(checkboxWithTitle: title, target: nil, action: nil); b.tag = Int(mask); return b
    }
    private let keys: [(String, Int)] = [("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),("0",29),("1",18),("2",19),("3",20),("4",21),("5",23),("6",22),("7",26),("8",28),("9",25)]
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
        var views: [NSView] = [
            effectChoice("Rahmenposition", \.placement, [("Außen",.outside),("Mittig",.centered),("Innen",.inside)]),
            NSTextField(wrappingLabelWithString: "Bei Innen liegt der Abstand innerhalb des Fensters, sonst außerhalb. Sehr breite Innenrahmen werden bei kleinen Fenstern passend begrenzt."),
            conditional([colorRow]) { $0.material.mode == .standard }
        ]
        views += [
            effectSlider("Deckkraft", \.opacity, 10...100, percent: true),
            effectSlider("Stärke", \.width, 1...100),
            effectSlider("Eckenradius", \.radius, 0...300),
            effectSlider("Abstand", \.gap, 0...200)
        ]
        views.append(NSButton(title: "Darstellung zurücksetzen", target: self, action: #selector(resetAppearance)))
        profilePicker.target = self; profilePicker.action = #selector(selectProfile)
        return page([
            section("Profile", [profilePicker,
                NSButton(title: "Darstellung als Profil speichern …", target: self, action: #selector(saveProfile)),
                NSButton(title: "Einstellungen exportieren …", target: self, action: #selector(exportPreferences)),
                NSButton(title: "Einstellungen importieren …", target: self, action: #selector(importPreferences))]),
            section("Rahmen", views),
            section("Oberfläche", [
                effectChoice("Oberfläche", \.material.mode, [("Farbe / Farbverlauf",.standard),("Gold",.gold),("Chrom",.chrome)]),
                conditional([
                    effectSlider("Glanz", \.material.gloss, 0...100, percent: true),
                    effectSlider("Lichtwinkel", \.material.angle, 0...360, unit: "°"),
                    NSTextField(wrappingLabelWithString: "Gold und Chrom verwenden eigene Metallfarben. Deine Rahmenfarbe und Farbverläufe bleiben gespeichert. Den wandernden Lichtreflex findest du unter Animationen.")
                ]) { $0.material.mode != .standard },
                resetEffect("Oberfläche zurücksetzen") { $0.material = MaterialEffect() }
            ])
        ], inset: 0)
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
                effectChoice("Farbe verwenden von", \.shadow.colorSource, [("Eigene Farbe",.custom),("Rahmenfarbe",.frame),("Rahmenverlauf",.gradient)]),
                conditional([effectColor("Eigene Farbe", \.shadow.color)]) { $0.shadow.colorSource == .custom },
                NSTextField(wrappingLabelWithString: "Rahmenverlauf übernimmt die sichtbare Oberfläche. Ohne Verlauf wird die Rahmenfarbe verwendet."),
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
            conditional([NSTextField(wrappingLabelWithString: "Aktuell wird Gold oder Chrom angezeigt. Wähle unter Darstellung die Oberfläche ‘Farbe / Farbverlauf’, um diese Farben wieder zu sehen.")]) { $0.material.mode != .standard },
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
        animationPreview.heightAnchor.constraint(equalToConstant: 190).isActive = true
        return page([
            section("Vorschau und Presets", [animationPreview,
                NSButton(title: "Animation abspielen", target: self, action: #selector(playPreview)),
                resetEffect("Dezent") { $0 = MotionPreset.subtle.applying(to: $0) },
                resetEffect("Lichtläufer") { $0 = MotionPreset.runner.applying(to: $0) },
                resetEffect("Atmender Schatten") { $0 = MotionPreset.breathingShadow.applying(to: $0) },
                resetEffect("Farbfluss") { $0 = MotionPreset.colorFlow.applying(to: $0) }
            ]),
            section("Bewegung", [
                effectChoice("Effekt", \.motion.mode, [("Aus",.off),("Fokusimpuls",.impulse),("Lichtläufer",.runner),("Rahmen zeichnen",.draw),("Atmen",.breathe),("Farbfluss",.flow)]),
                conditional([
                    effectChoice("Auslöser", \.motion.trigger, trigger),
                    effectSlider("Dauer je Durchlauf", \.motion.duration, 0.5...30, unit: "s"),
                    conditional([effectSlider("Durchläufe", \.motion.cycles, 1...6)]) { $0.motion.trigger == .focus },
                    effectSlider("Stärke", \.motion.strength, 0...100, percent: true),
                    effectChoice("Bewegungsverlauf", \.motion.curve, [("Sanft",.smooth),("Gleichmäßig",.linear),("Federnd (Impuls)",.spring)]),
                    conditional([effectChoice("Animieren", \.motion.target, [("Schatten",.shadow),("Rahmen",.frame),("Leuchten",.light),("Alles",.all)])]) { $0.motion.mode == .breathe },
                    NSTextField(wrappingLabelWithString: "Farbfluss braucht einen aktiven Farbverlauf. Atmen wirkt auf das gewählte Element; ein Schatten oder Leuchten muss eingeschaltet sein.")
                ]) { $0.motion.mode != .off },
                effectCheck("Dauer und Auslöser für weitere Effekte übernehmen", \.motion.synchronize),
                NSTextField(wrappingLabelWithString: "Bei gemeinsamer Steuerung gelten Dauer und Auslöser oben auch für Deckkraft, Rotation und Metallreflex. Die Einzelwerte bleiben gespeichert."),
                resetEffect("Bewegung zurücksetzen") { $0.motion = MotionEffect() }
            ]),
            section("Deckkraft", [
                effectChoice("Animieren", \.opacityAnimation.target, [("Alles",.all),("Rahmen",.frame),("Leuchten",.light),("Schatten",.shadow)]),
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
                    NSTextField(wrappingLabelWithString: "Rotation benötigt einen eingeschalteten Farbverlauf und die Oberfläche ‘Farbe / Farbverlauf’.")
                ]) { $0.rotation.enabled },
                resetEffect("Verlaufsrotation zurücksetzen") { $0.rotation = RotationEffect() }
            ]),
            section("Metall-Lichtreflex", [
                conditional([NSTextField(wrappingLabelWithString: "Für den Lichtreflex Gold oder Chrom unter Darstellung wählen.")]) { $0.material.mode == .standard },
                conditional([
                    effectCheck("Lichtreflex bewegen", \.material.reflectionEnabled),
                    conditional([
                        effectSlider("Reflexstärke", \.material.reflectionStrength, 0...100, percent: true),
                        effectSlider("Reflexbreite", \.material.reflectionWidth, 5...60, percent: true),
                        effectChoice("Auslöser", \.material.trigger, trigger),
                        conditional([effectSlider("Zyklusdauer", \.material.period, 2...30, unit: "s")]) { $0.material.trigger == .continuous },
                        conditional([effectSlider("Fokusdauer", \.material.focusDuration, 0.5...5, unit: "s")]) { $0.material.trigger == .focus }
                    ]) { $0.material.reflectionEnabled }
                ]) { $0.material.mode != .standard },
                resetEffect("Lichtreflex zurücksetzen") { a in
                    let d = MaterialEffect()
                    a.material.reflectionEnabled = d.reflectionEnabled
                    a.material.reflectionStrength = d.reflectionStrength; a.material.reflectionWidth = d.reflectionWidth
                    a.material.period = d.period; a.material.trigger = d.trigger; a.material.focusDuration = d.focusDuration
                }
            ]),
            NSButton(title: "Fokuswechsel testen", target: self, action: #selector(testFocus)),
            NSTextField(wrappingLabelWithString: "Bei macOS ‘Bewegung reduzieren’ bleiben Effekte statisch.")
        ], inset: 0)
    }
    func windowWillClose(_ notification: Notification) { animationPreview.renderer.setVisible(false) }
    @objc private func playPreview() { animationPreview.play() }
    @objc private func testFocus() { onTestFocus?() }

    private func behaviorPage() -> NSView {
        frameToggle.target = self; frameToggle.action = #selector(toggleFrame)
        frameToggle.state = frameEnabled ? .on : .off
        login.target = self; login.action = #selector(changeLogin)
        shortcut.target = self; shortcut.action = #selector(changeShortcut)
        fullScreen.target = self; fullScreen.action = #selector(changeFullScreen)
        power.target = self; power.action = #selector(changePower)
        for (name, code) in keys { keyPicker.addItem(withTitle: name); keyPicker.lastItem?.tag = code }
        keyPicker.target = self; keyPicker.action = #selector(changeKey)
        for b in modifierButtons { b.target = self; b.action = #selector(changeKey) }
        let openLogin = NSButton(title: "Anmeldeobjekte öffnen …", target: self, action: #selector(openLoginSettings))
        return page([
            section("Rahmen", [frameToggle, fullScreen, power]),
            section("Tastenkürzel", [shortcut, NSStackView(views: modifierButtons), keyPicker, shortcutStatus]),
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
        animationPreview.previewStyle = store.value.normalized.renderedAppearance(lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        colorWell.color = NSColor(srgbRed: appearance.red, green: appearance.green, blue: appearance.blue, alpha: 1)
        effectSync.forEach { $0() }
        let oldProfile = profilePicker.titleOfSelectedItem
        profilePicker.removeAllItems(); profilePicker.addItem(withTitle: "Profil auswählen …")
        for p in store.profiles { profilePicker.addItem(withTitle: p.name) }
        if let oldProfile { profilePicker.selectItem(withTitle: oldProfile) }
        keyPicker.selectItem(withTag: Int(store.value.shortcutKeyCode))
        for b in modifierButtons { b.state = store.value.shortcutModifiers & UInt32(b.tag) != 0 ? .on : .off }
        power.state = store.value.savePower ? .on : .off
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
        shortcutStatus.stringValue = "\(modifierButtons.filter { $0.state == .on }.map(\.title).joined(separator: " + ")) + \(keyPicker.titleOfSelectedItem ?? "?") ist registriert. \(receipt) Rahmen: \(state)."
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
            a.opacity=d.opacity; a.width=d.width; a.radius=d.radius; a.gap=d.gap; a.placement=d.placement }
        sync()
    }
    @objc private func changePower() { store.value.savePower = power.state == .on; sync() }
    @objc private func changeKey() {
        let mask = modifierButtons.filter { $0.state == .on }.reduce(UInt32(0)) { $0 | UInt32($1.tag) }
        guard mask != 0 else { sync(); return }
        var value = store.value; value.shortcutKeyCode = UInt32(keyPicker.selectedTag()); value.shortcutModifiers = mask
        store.value = value.normalized; sync()
    }
    @objc private func selectProfile() {
        let index = profilePicker.indexOfSelectedItem - 1
        guard store.profiles.indices.contains(index) else { return }
        store.value.appearance = store.profiles[index].appearance.normalized; sync()
    }
    @objc private func saveProfile() {
        let alert = NSAlert(); alert.messageText = "Darstellung speichern"
        let name = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24)); name.placeholderString = "Profilname"
        alert.accessoryView = name; alert.addButton(withTitle: "Speichern"); alert.addButton(withTitle: "Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let title = String(name.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)); guard !title.isEmpty else { return }
        if let index = store.profiles.firstIndex(where: { $0.name == title }) { store.profiles[index].appearance = store.value.appearance.normalized }
        else { store.profiles.append(AppearanceProfile(name: title, appearance: store.value.appearance.normalized)) }
        sync()
    }
    @objc private func exportPreferences() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "FocusFrame-Einstellungen.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(PortablePreferences(configuration: store.value.normalized, profiles: store.profiles)).write(to: url, options: .atomic)
        } catch { transferError(error) }
    }
    @objc private func importPreferences() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url); guard data.count < 1_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let document = try JSONDecoder().decode(PortablePreferences.self, from: data)
            guard document.version == 1, document.profiles.count <= 100 else { throw CocoaError(.coderReadCorrupt) }
            let profiles = document.profiles.map { AppearanceProfile(name: String($0.name.prefix(80)), appearance: $0.appearance.normalized) }
            store.value = document.configuration.normalized
            if !profiles.isEmpty { store.profiles = profiles }; sync()
        } catch { transferError(error) }
    }
    private func transferError(_ error: Error) {
        let alert = NSAlert(); alert.messageText = "Einstellungen konnten nicht übertragen werden"; alert.informativeText = error.localizedDescription; alert.runModal()
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

@MainActor
private final class AnimationPreview: EffectCanvas {
    var previewStyle = Appearance() { didSet { needsLayout = true } }
    override func layout() {
        super.layout()
        guard bounds.width > 0 && bounds.height > 0 else { return }
        let target = CGRect(x: 0,y: 0,width: 500,height: 260)
        let outer = EffectGeometry.alignedOverlayRect(for: target, appearance: previewStyle)
        let ratio = min((bounds.width-16)/outer.width,(bounds.height-16)/outer.height)
        renderer.update(bounds: CGRect(origin: .zero,size: outer.size), target: target.offsetBy(dx: -outer.minX,dy: -outer.minY), style: previewStyle, scale: 1)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        renderer.root.anchorPoint = .zero
        renderer.root.position = CGPoint(x: (bounds.width-outer.width*ratio)/2,y: (bounds.height-outer.height*ratio)/2)
        renderer.root.transform = CATransform3DMakeScale(ratio,ratio,1)
        CATransaction.commit()
        renderer.setVisible(window?.isVisible == true)
    }
    func play() { layoutSubtreeIfNeeded(); renderer.setVisible(true, focusChanged: true) }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); if window == nil { renderer.setVisible(false) }; needsLayout = true }
}
