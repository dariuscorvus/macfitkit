import AppKit
import FocusFrameCore

@MainActor
final class OverlayWindow: NSPanel {
    private let border = EffectCanvas(frame: .zero)
    private let occlusionMask = CAShapeLayer()
    private var visibleRegions: [CGRect]?
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
        // A later focus/Space transition must not expose the previous target's mask.
        setOcclusion(nil)
        border.renderer.setVisible(false); super.orderOut(sender)
    }
    /// Mask the canvas parent, outside the translated renderer and its effect masks.
    /// Empty regions hide all pixels without restarting animation timelines.
    func setOcclusion(_ covers: [CGRect]?) {
        // One device pixel of conservative padding prevents antialiased mask
        // edges from leaving glow on fractional occluder boundaries.
        let pixel = 1 / max(1, backingScaleFactor)
        let regions = covers.map {
            WindowOcclusion.visibleRegions(in: frame, coveredBy: $0.map { $0.insetBy(dx: -pixel, dy: -pixel) })
        } ?? []
        guard visibleRegions != regions else { return }
        visibleRegions = regions
        let path = CGMutablePath()
        for region in regions { path.addRect(region.offsetBy(dx: -frame.minX, dy: -frame.minY)) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        occlusionMask.frame = CGRect(origin: .zero, size: frame.size)
        occlusionMask.contentsScale = backingScaleFactor
        occlusionMask.path = path; occlusionMask.fillColor = NSColor.white.cgColor
        border.layer?.mask = occlusionMask
        CATransaction.commit()
    }

    func show(around rect: CGRect, appearance: Appearance, focusChanged: Bool = false) {
        let a = appearance.normalized
        let next = EffectGeometry.alignedOverlayRect(for: rect, appearance: a)
        let wasVisible = isVisible
        let newScale = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: rect.midX,y: rect.midY)) })?.backingScaleFactor ?? backingScaleFactor
        let rebuild = style != a || targetSize != rect.size || scale != newScale
        if frame != next {
            visibleRegions = nil
            setOcclusion(nil)
        }
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
        if visibleRegions == nil { setOcclusion(nil) }
        if !wasVisible { orderFrontRegardless() }
        if rebuild || !wasVisible || focusChanged {
            border.renderer.setVisible(true, focusChanged: focusChanged || !wasVisible)
        }
    }
}

/// Metadata only: no capture permission and no private AX window-ID API.
@MainActor
enum WindowStackSnapshot {
    static func read(excluding overlayID: Int) -> [WindowStackEntry]? {
        guard let top = NSScreen.screens.first?.frame.maxY,
              let rows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else { return nil }
        var result: [WindowStackEntry] = []
        for row in rows {
            guard let id = row[kCGWindowNumber as String] as? UInt32, id != UInt32(overlayID),
                  let pid = row[kCGWindowOwnerPID as String] as? Int32,
                  let alpha = row[kCGWindowAlpha as String] as? Double, alpha > 0,
                  let dict = row[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  let rect = WindowGeometry.appKitRect(position: bounds.origin, size: bounds.size, mainDisplayTop: top) else { continue }
            result.append(WindowStackEntry(id: id, pid: pid, bounds: rect))
        }
        return result
    }
}
