import AppKit
import FocusFrameCore

@MainActor
final class OverlayWindow: NSPanel {
    private let border = EffectCanvas(frame: .zero)
    private var style: Appearance?
    private var targetSize = CGSize.zero
    private var scale: CGFloat = 0
    private var renderedTargetOrigin = CGPoint.zero

    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false; isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false; isExcludedFromWindowsMenu = true; animationBehavior = .none
        contentView = border; setAccessibilityHidden(true)
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // This panel includes transparent space for effects outside the target.
        // AppKit's menu-bar clamp during setFrameOrigin would shift the entire
        // border downward when that padding crosses a display's top edge.
        frameRect
    }
    override func orderOut(_ sender: Any?) {
        border.renderer.setVisible(false); super.orderOut(sender)
    }
    func show(around rect: CGRect, appearance: Appearance, focusChanged: Bool = false) {
        let a = appearance.normalized
        let next = EffectGeometry.alignedOverlayRect(for: rect, appearance: a)
        let wasVisible = isVisible
        let newScale = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: rect.midX,y: rect.midY)) })?.backingScaleFactor ?? backingScaleFactor
        let rebuild = style != a || targetSize != rect.size || scale != newScale
        if frame.size == next.size {
            if frame.origin != next.origin { setFrameOrigin(next.origin) }
        } else { setFrame(next, display: false, animate: false) }
        if rebuild {
            style = a; targetSize = rect.size; scale = newScale
            let target = rect.offsetBy(dx: -next.minX, dy: -next.minY)
            renderedTargetOrigin = target.origin
            border.renderer.update(bounds: CGRect(origin: .zero,size: next.size), target: target, style: a, scale: scale)
        }
        // Compensate for fractional target movement without rebuilding paths.
        let localOrigin = CGPoint(x: rect.minX-next.minX, y: rect.minY-next.minY)
        let translation = CATransform3DMakeTranslation(localOrigin.x-renderedTargetOrigin.x,
                                                      localOrigin.y-renderedTargetOrigin.y, 0)
        if !CATransform3DEqualToTransform(border.renderer.root.transform, translation) {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            border.renderer.root.transform = translation
            CATransaction.commit()
        }
        if !wasVisible { orderFrontRegardless() }
        if rebuild || !wasVisible || focusChanged {
            border.renderer.setVisible(true, focusChanged: focusChanged || !wasVisible)
        }
    }
}
