import AppKit
import FocusFrameCore

@MainActor
final class OverlayWindow: NSPanel {
    private let border = BorderView()

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        contentView = border
        accessibilitySetOverrideValue(true, forAttribute: .hidden)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(around rect: CGRect, color: NSColor, width: CGFloat) {
        border.color = color
        border.width = width
        setFrame(WindowGeometry.overlayRect(for: rect, width: width), display: true)
        border.needsDisplay = true
        orderFrontRegardless()
    }
}

@MainActor
private final class BorderView: NSView {
    var color: NSColor = .systemOrange
    var width: CGFloat = 3
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        color.setStroke()
        // Center the stroke entirely outside the target window.
        let path = NSBezierPath(rect: bounds.insetBy(dx: width / 2, dy: width / 2))
        path.lineWidth = width
        path.stroke()
    }
}
