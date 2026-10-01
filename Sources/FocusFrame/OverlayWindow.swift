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

    func show(around rect: CGRect, appearance: Appearance) {
        let nextFrame = WindowGeometry.overlayRect(for: rect, width: appearance.width, gap: appearance.gap)
        let needsRedraw = border.style != appearance || frame.size != nextFrame.size
        border.style = appearance
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
    var style = Appearance()
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let target = bounds.insetBy(dx: style.width + style.gap, dy: style.width + style.gap)
        BorderDrawing.draw(around: target, appearance: style)
    }
}

@MainActor
enum BorderDrawing {
    static func draw(around rect: CGRect, appearance: Appearance) {
        appearance.color.setStroke()
        let outset = appearance.gap + appearance.width / 2
        let radius = appearance.radius > 0 ? appearance.radius + outset : 0
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: -outset, dy: -outset), xRadius: radius, yRadius: radius)
        path.lineWidth = appearance.width
        path.stroke()
    }
}
