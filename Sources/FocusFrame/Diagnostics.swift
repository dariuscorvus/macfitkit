import AppKit
import FocusFrameCore

/// Optional, bounded, in-memory events. No titles, contents or app identifiers.
@MainActor
final class Diagnostics {
    static let shared = Diagnostics()
    var enabled = false {
        didSet { if !enabled { entries.removeAll() } }
    }
    private var entries: [String] = []
    var trackingState = VisibilityDecision.noWindow {
        didSet { if oldValue != trackingState { record(trackingState.rawValue) } }
    }
    func record(_ event: String, milliseconds: Double? = nil) {
        guard enabled else { return }
        let time = ProcessInfo.processInfo.systemUptime
        let duration = milliseconds.map { String(format: " · %.2f ms", $0) } ?? ""
        entries.append(String(format: "%.3f", time) + " · " + event + duration)
        if entries.count > 300 { entries.removeFirst(entries.count - 300) }
    }
    var snapshot: String {
        trackingState.rawValue + "\n\n" + (entries.isEmpty ? "Noch keine Ereignisse erfasst." : entries.joined(separator: "\n"))
    }
    func clear() { entries.removeAll() }
}

@MainActor
final class DiagnosticsWindowController: NSWindowController {
    var onOpenSettings: (() -> Void)?
    private let text = NSTextView()
    private let toggle = NSButton(checkboxWithTitle: "Diagnose erfassen", target: nil, action: nil)
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "FocusFrame – Diagnose"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        toggle.target = self
        toggle.action = #selector(toggleCapture)
        let refresh = NSButton(title: "Aktualisieren", target: self, action: #selector(updateText))
        let clear = NSButton(title: "Leeren", target: self, action: #selector(clearText))
        let settings = NSButton(title: "Einstellungen …", target: self, action: #selector(openSettings))
        let controls = NSStackView(views: [toggle, refresh, clear, settings])
        controls.spacing = 16
        let hint = NSTextField(wrappingLabelWithString: "Nur lokale Ereignisse und Abfragezeiten, ohne Fensterinhalte. Maximal 300 Einträge im Arbeitsspeicher. Ausschalten löscht die Einträge.")
        text.isEditable = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let scroll = NSScrollView()
        scroll.documentView = text
        scroll.hasVerticalScroller = true
        text.autoresizingMask = [.width]
        text.isVerticallyResizable = true
        text.textContainer?.widthTracksTextView = true
        let stack = NSStackView(views: [controls, hint, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        window.contentView = NSView()
        window.contentView?.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: window.contentView!.bottomAnchor, constant: -20),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func present() {
        toggle.state = Diagnostics.shared.enabled ? .on : .off
        updateText()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func toggleCapture() {
        Diagnostics.shared.enabled = toggle.state == .on
        updateText()
    }
    @objc private func updateText() { text.string = Diagnostics.shared.snapshot }
    @objc private func clearText() { Diagnostics.shared.clear(); updateText() }
    @objc private func openSettings() { onOpenSettings?() }
}
