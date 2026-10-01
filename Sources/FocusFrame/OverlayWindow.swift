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
        setAccessibilityHidden(true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(around rect: CGRect, color: NSColor, width: CGFloat) {
        let nextFrame = WindowGeometry.overlayRect(for: rect, width: width)
        let needsRedraw = border.color != color || border.width != width || frame.size != nextFrame.size
        border.color = color
        border.width = width
        if frame.size == nextFrame.size {
            // Moving an unchanged border needs no layout or redraw.
            if frame.origin != nextFrame.origin { setFrameOrigin(nextFrame.origin) }
        } else {
            setFrame(nextFrame, display: false, animate: false)
        }
        if needsRedraw {
            border.needsDisplay = true
            border.displayIfNeeded()
        }
        if !isVisible { orderFrontRegardless() }
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
        let radius: CGFloat = 10 + width / 2
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                xRadius: radius, yRadius: radius)
        path.lineWidth = width
        path.stroke()
    }
}
