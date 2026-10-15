import AppKit
import QuartzCore

@MainActor public final class PreviewView: NSView {
    public var onHoverChanged: ((Bool) -> Void)?
    private var hoverTracking: NSTrackingArea?
    private let imageLayer = CALayer()
    private var retainedFrame: CapturedFrame?
    public override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        imageLayer.contentsGravity = .resize; layer?.addSublayer(imageLayer)
        setAccessibilityLabel("Live-Vorschau des ausgewählten Fensters")
        setAccessibilityRole(.image)
    }
    required init?(coder: NSCoder) { nil }
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    public override var mouseDownCanMoveWindow: Bool { true }
    public override func mouseDown(with event: NSEvent) { onHoverChanged?(true); window?.performDrag(with: event) }
    public func display(_ frame: CapturedFrame) {
        retainedFrame = frame
        let width = CGFloat(CVPixelBufferGetWidth(frame.pixelBuffer)), height = CGFloat(CVPixelBufferGetHeight(frame.pixelBuffer))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        imageLayer.contents = frame.surface
        imageLayer.contentsRect = CGRect(x: frame.contentRect.minX / width, y: frame.contentRect.minY / height,
                                         width: frame.contentRect.width / width, height: frame.contentRect.height / height)
        layout(); CATransaction.commit()
    }
    public override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        imageLayer.frame = PiPGeometry.aspectFit(retainedFrame?.size ?? CGSize(width: 16, height: 9), in: bounds)
        CATransaction.commit()
    }
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect], owner: self)
        addTrackingArea(area); hoverTracking = area
    }
    public override func mouseEntered(with event: NSEvent) { onHoverChanged?(true) }
    public override func mouseMoved(with event: NSEvent) { onHoverChanged?(true) }
    public override func mouseExited(with event: NSEvent) { onHoverChanged?(false) }
    var contentAspectRatio: CGFloat? {
        guard let size = retainedFrame?.size, size.height > 0 else { return nil }
        return size.width / size.height
    }
    public func clear() { imageLayer.contents = nil; retainedFrame = nil }
}

private final class PiPPanel: NSPanel {
    var onKeyboardHUD: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) { onKeyboardHUD?(); super.keyDown(with: event) }
}

@MainActor private final class ResizeGrip: NSView {
    var onTracking: ((Bool) -> Void)?
    private var original: CGRect?
    private var anchor = CGPoint.zero
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.8).setStroke()
        let path = NSBezierPath(); path.lineWidth = 2
        path.move(to: CGPoint(x: 5, y: 5)); path.line(to: CGPoint(x: 13, y: 13))
        path.move(to: CGPoint(x: 10, y: 5)); path.line(to: CGPoint(x: 15, y: 10)); path.stroke()
    }
    override func mouseDown(with event: NSEvent) {
        original = window?.frame; anchor = NSEvent.mouseLocation; onTracking?(true)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let original else { return }
        let point = NSEvent.mouseLocation
        let width = max(window.minSize.width, original.width + point.x - anchor.x)
        let height = max(window.minSize.height, original.height - point.y + anchor.y)
        window.setFrame(CGRect(x: original.minX, y: original.maxY - height, width: width, height: height), display: true)
    }
    override func mouseUp(with event: NSEvent) { original = nil; onTracking?(false) }
}

@MainActor public final class PiPPanelController: NSObject, NSWindowDelegate, NSMenuDelegate {
    public let preview = PreviewView(frame: .zero)
    public var onPause: (() -> Void)?
    public var onChooseSource: (() -> Void)?
    public var onFocusSource: (() -> Void)?
    public var onClose: (() -> Void)?
    public var onResize: ((CGSize, CGFloat) -> Void)?
    private let panel: PiPPanel
    private let hud = NSVisualEffectView()
    private let grip = ResizeGrip()
    private let overlay = NSTextField(wrappingLabelWithString: PiPState.starting.label)
    private let pause = NSButton()
    private let defaults: UserDefaults
    private var screenObserver: NSObjectProtocol?
    private var closingProgrammatically = false
    private var hovered = false
    private var trackingResize = false
    private var trackingMenu = false
    private var activeMenu: NSMenu?
    private var aspectRatio: CGFloat = 1.25
    public var titleBarVisible: Bool { defaults.bool(forKey: "universalPiP.showTitleBar") }
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        panel = PiPPanel(contentRect: CGRect(x: 0, y: 0, width: 400, height: 320),
                         styleMask: [.borderless, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "UniversalPiP – Live-Vorschau"; panel.isReleasedWhenClosed = false
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        panel.isMovable = true; panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true; panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications]
        panel.minSize = CGSize(width: 240, height: 160); panel.delegate = self
        panel.acceptsMouseMovedEvents = true
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        let root = NSView(); root.wantsLayer = true; root.layer?.cornerRadius = 12; root.layer?.masksToBounds = true
        panel.contentView = root
        preview.toolTip = "Vorschaubild ziehen zum Verschieben. Zum Einblenden der Steuerung den Zeiger über das Bild bewegen."
        preview.onHoverChanged = { [weak self] value in self?.hovered = value; self?.updateHUD() }
        panel.onKeyboardHUD = { [weak self] in self?.setHUDVisible(true) }
        hud.material = .hudWindow; hud.blendingMode = .withinWindow; hud.state = .active
        hud.wantsLayer = true; hud.layer?.cornerRadius = 10; hud.layer?.masksToBounds = true
        hud.setAccessibilityLabel("PiP-Steuerung")
        let focus = iconButton("scope", label: "Originalfenster fokussieren", action: #selector(focusClicked))
        pause.target = self; pause.action = #selector(pauseClicked); pause.bezelStyle = .inline
        pause.imagePosition = .imageOnly; pause.isBordered = false
        let choose = iconButton("rectangle.on.rectangle", label: "Anderes Quellfenster auswählen", action: #selector(chooseClicked))
        let resize = iconButton("arrow.up.left.and.arrow.down.right", label: "Größe der Vorschau ändern", action: #selector(resizeClicked(_:)))
        let options = iconButton("ellipsis", label: "Optionen der Vorschau", action: #selector(optionsClicked(_:)))
        let close = iconButton("xmark", label: "Vorschau schließen", action: #selector(closeClicked))
        let bar = NSStackView(views: [focus, pause, choose, resize, options, close]); bar.spacing = 4
        bar.translatesAutoresizingMaskIntoConstraints = false; hud.addSubview(bar)
        for button in [focus, pause, choose, resize, options, close] {
            button.widthAnchor.constraint(equalToConstant: 28).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }
        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 6), bar.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -6),
            bar.topAnchor.constraint(equalTo: hud.topAnchor, constant: 4), bar.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -4)
        ])
        overlay.alignment = .center; overlay.textColor = .white; overlay.drawsBackground = true
        overlay.backgroundColor = NSColor.black.withAlphaComponent(0.85); overlay.font = .boldSystemFont(ofSize: 13)
        grip.toolTip = "Zum Ändern der Größe ziehen"; grip.setAccessibilityLabel("Größe ändern; alternativ Größenmenü verwenden")
        grip.onTracking = { [weak self] active in
            self?.trackingResize = active; self?.updateHUD()
            if !active { self?.keepVisible() }
        }
        [preview, overlay, hud, grip].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; root.addSubview($0) }
        NSLayoutConstraint.activate([
            preview.leadingAnchor.constraint(equalTo: root.leadingAnchor), preview.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            preview.topAnchor.constraint(equalTo: root.topAnchor), preview.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            hud.topAnchor.constraint(equalTo: root.topAnchor, constant: 8), hud.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: root.centerYAnchor), overlay.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            overlay.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            grip.widthAnchor.constraint(equalToConstant: 22), grip.heightAnchor.constraint(equalToConstant: 22),
            grip.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -3), grip.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -3)
        ])
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.keepVisible() }
        }
        applyTitleBar(); setState(.starting); setHUDVisible(false)
    }
    private func iconButton(_ symbol: String, label: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage(size: CGSize(width: 16, height: 16)), target: self, action: action)
        button.imagePosition = .imageOnly; button.bezelStyle = .inline; button.isBordered = false
        button.toolTip = label; button.setAccessibilityLabel(label)
        return button
    }
    public func show(source: WindowSource) {
        aspectRatio = source.frame.width / max(1, source.frame.height)
        preview.clear(); setState(.starting)
        let screens = NSScreen.screens.map(\.visibleFrame)
        let sourceFrame = CGRect(x: source.frame.minX, y: (NSScreen.screens.first?.frame.maxY ?? 0) - source.frame.maxY,
                                 width: source.frame.width, height: source.frame.height)
        var frame = PiPGeometry.initialFrame(source: sourceFrame, screens: screens)
        if let stored = defaults.string(forKey: "universalPiP.panelFrame") {
            let saved = NSRectFromString(stored)
            if saved.width.isFinite, saved.height.isFinite, saved.minX.isFinite, saved.minY.isFinite, saved.width > 0, saved.height > 0 {
                frame = PiPGeometry.visibleFrame(saved, screens: screens)
            }
        } else { frame.size.height = max(160, frame.width / aspectRatio) }
        panel.setFrame(PiPGeometry.visibleFrame(frame, screens: screens), display: true)
        hovered = false; setHUDVisible(false); panel.orderFrontRegardless(); reportSize()
    }
    public func setState(_ state: PiPState) {
        overlay.stringValue = state.label; overlay.isHidden = state == .live
        let paused = state == .paused || state == .failed || state == .unavailable
        let label = paused ? "Vorschau fortsetzen" : "Vorschau pausieren"
        pause.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill", accessibilityDescription: label)
        pause.toolTip = label; pause.setAccessibilityLabel(label)
        pause.isEnabled = state != .ready && state != .permissionRequired && state != .ended
        overlay.setAccessibilityValue(state.label)
    }
    public func setTitleBarVisible(_ visible: Bool) {
        defaults.set(visible, forKey: "universalPiP.showTitleBar"); applyTitleBar(); save(); reportSize()
    }
    private func applyTitleBar() {
        if titleBarVisible { panel.styleMask.insert([.titled, .closable]) }
        else { panel.styleMask.remove([.titled, .closable]) }
        panel.standardWindowButton(.zoomButton)?.isHidden = true
    }
    public func setPreviewWidth(_ width: CGFloat) {
        guard width.isFinite, width >= 240 else { return }
        let aspectRatio = preview.contentAspectRatio ?? self.aspectRatio
        let frame = CGRect(x: panel.frame.minX, y: panel.frame.maxY - max(160, width / aspectRatio), width: width, height: max(160, width / aspectRatio))
        panel.setFrame(PiPGeometry.visibleFrame(frame, screens: NSScreen.screens.map(\.visibleFrame)), display: true); reportSize()
    }
    public func close() {
        activeMenu?.cancelTracking(); activeMenu = nil; trackingMenu = false
        closingProgrammatically = true; panel.close(); closingProgrammatically = false; preview.clear()
    }
    private func keepVisible() {
        panel.setFrame(PiPGeometry.visibleFrame(panel.frame, screens: NSScreen.screens.map(\.visibleFrame)), display: true); reportSize()
    }
    private func reportSize() { panel.contentView?.layoutSubtreeIfNeeded(); onResize?(preview.bounds.size, panel.backingScaleFactor) }
    var hudIsVisible: Bool { !hud.isHidden }
    private func updateHUD() { setHUDVisible(hovered || trackingResize || trackingMenu || panel.isKeyWindow) }
    private func refreshHover() {
        guard panel.isVisible else { return }
        let point = preview.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        hovered = preview.bounds.contains(point); updateHUD()
    }
    private func setHUDVisible(_ visible: Bool) {
        // Keep the buttons usable for keyboard focus; the image remains full size in either state.
        hud.isHidden = !visible; grip.isHidden = !visible
    }
    public func windowDidResize(_ notification: Notification) { save(); reportSize(); refreshHover() }
    public func windowDidMove(_ notification: Notification) { save(); refreshHover() }
    public func windowDidChangeBackingProperties(_ notification: Notification) { reportSize() }
    public func windowDidBecomeKey(_ notification: Notification) { updateHUD() }
    public func windowDidResignKey(_ notification: Notification) { updateHUD() }
    public func windowWillClose(_ notification: Notification) {
        save(); preview.clear(); if !closingProgrammatically { onClose?() }
    }
    private func save() { defaults.set(NSStringFromRect(panel.frame), forKey: "universalPiP.panelFrame") }
    @objc private func pauseClicked() { onPause?() }
    @objc private func chooseClicked() { onChooseSource?() }
    @objc private func focusClicked() { onFocusSource?() }
    @objc private func closeClicked() { close(); onClose?() }
    @objc private func resizeClicked(_ sender: NSButton) {
        let menu = NSMenu()
        for width in [240, 400, 800] {
            let item = NSMenuItem(title: "\(width) Punkte Breite", action: #selector(sizeSelected(_:)), keyEquivalent: "")
            item.target = self; item.tag = width; menu.addItem(item)
        }
        showMenu(menu, from: sender)
    }
    @objc private func sizeSelected(_ sender: NSMenuItem) { setPreviewWidth(CGFloat(sender.tag)) }
    @objc private func optionsClicked(_ sender: NSButton) {
        let menu = NSMenu()
        let title = NSMenuItem(title: "Titelleiste anzeigen", action: #selector(toggleTitle), keyEquivalent: "")
        title.target = self; title.state = titleBarVisible ? .on : .off; menu.addItem(title)
        menu.addItem(.separator())
        let choose = NSMenuItem(title: "Fenster auswählen …", action: #selector(chooseClicked), keyEquivalent: "")
        choose.target = self; menu.addItem(choose)
        showMenu(menu, from: sender)
    }
    private func showMenu(_ menu: NSMenu, from sender: NSButton) {
        activeMenu?.cancelTracking()
        activeMenu = menu; menu.delegate = self
        // Explicit menu interaction can activate our app; frames and normal hovering never do.
        NSApp.activate()
        trackingMenu = true; updateHUD()
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: sender.bounds.maxY), in: sender)
    }
    public func menuWillOpen(_ menu: NSMenu) { activeMenu = menu; trackingMenu = true; updateHUD() }
    public func menuDidClose(_ menu: NSMenu) {
        if activeMenu === menu { activeMenu = nil; trackingMenu = false; refreshHover() }
    }
    @objc private func toggleTitle() { setTitleBarVisible(!titleBarVisible) }
    public func dispose() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver); self.screenObserver = nil }
        close()
    }
}
