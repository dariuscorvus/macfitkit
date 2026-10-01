import AppKit
import QuartzCore
import FocusFrameCore

@MainActor
final class EffectRenderer {
    let root = CALayer()
    private var gradients: [CAGradientLayer] = []
    private var style = Appearance()
    private var visible = false

    func update(bounds: CGRect, target: CGRect, style: Appearance, scale: CGFloat) {
        stop()
        self.style = style.normalized
        let a = self.style
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.transform = CATransform3DIdentity
        root.frame = bounds; root.contentsScale = scale; root.opacity = Float(a.opacity)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }; gradients.removeAll()
        let outset = a.gap + a.width / 2
        let contour = CGPath(roundedRect: target.insetBy(dx: -outset, dy: -outset),
            cornerWidth: a.radius == 0 ? 0 : a.radius + outset,
            cornerHeight: a.radius == 0 ? 0 : a.radius + outset, transform: nil)
        // Effects never paint inside the target window.
        let exterior = CGMutablePath(); exterior.addRect(bounds)
        exterior.addRoundedRect(in: target, cornerWidth: a.radius, cornerHeight: a.radius)
        let exteriorMask = CAShapeLayer(); exteriorMask.path = exterior
        exteriorMask.contentsScale = scale
        exteriorMask.fillRule = .evenOdd; exteriorMask.fillColor = NSColor.black.cgColor
        let effects = CALayer(); effects.frame = bounds; effects.mask = exteriorMask
        root.addSublayer(effects)
        if a.shadow.enabled {
            addShadow(to: effects, contour: contour, width: a.width + 2 * a.shadow.spread,
                color: a.shadow.color, opacity: a.shadow.opacity, radius: a.shadow.blur,
                offset: CGSize(width: a.shadow.offsetX, height: -a.shadow.offsetY), scale: scale)
        }
        if a.light.mode != .off {
            let inherited = a.gradient.mode == .off ? EffectColor(a.red, a.green, a.blue) : a.gradient.first
            addShadow(to: effects, contour: contour, width: a.width,
                color: a.light.followsFrame ? inherited : a.light.color,
                opacity: a.light.intensity, radius: a.light.extent, offset: .zero, scale: scale)
        }
        addBorder(contour: contour, width: a.width, target: target, bounds: bounds, whitening: 0, scale: scale)
        if a.light.mode == .neon {
            addBorder(contour: contour, width: a.width * a.light.coreWidth, target: target,
                bounds: bounds, whitening: a.light.whitening, scale: scale)
        }
        CATransaction.commit()
    }

    private func addShadow(to parent: CALayer, contour: CGPath, width: CGFloat, color: EffectColor,
                           opacity: Double, radius: Double, offset: CGSize, scale: CGFloat) {
        let layer = CALayer(); layer.frame = root.bounds; layer.contentsScale = scale
        layer.shadowPath = contour.copy(strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 10)
        layer.shadowColor = color.nsColor.cgColor; layer.shadowOpacity = Float(opacity)
        layer.shadowRadius = radius; layer.shadowOffset = offset
        parent.addSublayer(layer)
    }

    private func addBorder(contour: CGPath, width: CGFloat, target: CGRect, bounds: CGRect,
                           whitening: Double, scale: CGFloat) {
        let a = style
        let mask = CAShapeLayer(); mask.path = contour; mask.lineWidth = width
        mask.fillColor = nil; mask.strokeColor = NSColor.black.cgColor; mask.contentsScale = scale
        let holder = CALayer(); holder.frame = bounds; holder.mask = mask; root.addSublayer(holder)
        let gradient = CAGradientLayer(); gradient.contentsScale = scale
        // A rotating square covers the entire rectangle at every angle.
        let margin = 2 * (a.gap + a.width)
        let side = hypot(target.width + margin, target.height + margin) + 2
        gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        gradient.position = CGPoint(x: target.midX, y: target.midY)
        func color(_ c: EffectColor) -> CGColor {
            NSColor(srgbRed: c.red + (1-c.red)*whitening, green: c.green + (1-c.green)*whitening,
                    blue: c.blue + (1-c.blue)*whitening, alpha: 1).cgColor
        }
        let first = a.gradient.mode == .off ? EffectColor(a.red,a.green,a.blue) : a.gradient.first
        let second = a.gradient.mode == .off ? first : a.gradient.second
        gradient.colors = a.gradient.mode == .conic ? [color(first), color(second), color(first)] : [color(first),color(second)]
        gradient.locations = a.gradient.mode == .conic ? [0,0.5,1] : [0,1]
        gradient.type = a.gradient.mode == .conic ? .conic : .axial
        gradient.startPoint = a.gradient.mode == .conic ? CGPoint(x: 0.5,y: 0.5) : CGPoint(x: 0,y: 0.5)
        gradient.endPoint = CGPoint(x: 1,y: 0.5)
        gradient.transform = CATransform3DMakeRotation(a.gradient.angle * .pi / 180, 0,0,1)
        holder.addSublayer(gradient); gradients.append(gradient)
    }

    func setVisible(_ visible: Bool, focusChanged: Bool = false) {
        self.visible = visible
        if !visible { stop(); return }
        animate(focusChanged: focusChanged)
    }
    func motionPreferenceChanged() { stop(); if visible { animate(focusChanged: false) } }
    func stop() {
        root.removeAllAnimations(); gradients.forEach { $0.removeAllAnimations() }
    }
    func animate(focusChanged: Bool) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let a = style; let o = a.opacityAnimation
        if o.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced,
            trigger: o.trigger, focusChanged: focusChanged) {
            let period = o.mode == .pulse ? o.pulsePeriod : o.blinkPeriod
            let minimum = o.mode == .pulse ? o.pulseMinimum : o.blinkMinimum
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            if o.mode == .pulse {
                animation.values = [o.maximum*a.opacity, minimum*a.opacity, o.maximum*a.opacity]
                animation.keyTimes = [0,0.5,1]
                animation.timingFunctions = [.init(name: .easeInEaseOut),.init(name: .easeInEaseOut)]
            } else {
                animation.values = [o.maximum*a.opacity,o.maximum*a.opacity,minimum*a.opacity,minimum*a.opacity,o.maximum*a.opacity]
                animation.keyTimes = [0,0.1,0.2,0.8,1]
            }
            animation.duration = period
            animation.repeatDuration = o.trigger == .continuous ? .infinity : o.focusDuration
            root.add(animation, forKey: "opacityEffect")
        }
        let r = a.rotation
        if r.enabled && a.gradient.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible,
            reducedMotion: reduced, trigger: r.trigger, focusChanged: focusChanged) {
            for gradient in gradients {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                let angle = a.gradient.angle * .pi / 180
                animation.fromValue = angle; animation.toValue = angle + (r.clockwise ? -2 : 2) * .pi
                animation.duration = r.period
                animation.repeatDuration = r.trigger == .continuous ? .infinity : r.focusDuration
                gradient.add(animation, forKey: "rotationEffect")
            }
        }
    }
}

extension EffectColor {
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: 1) }
}

@MainActor
class EffectCanvas: NSView {
    let renderer = EffectRenderer()
    override init(frame: NSRect) {
        super.init(frame: frame); wantsLayer = true
        layer?.addSublayer(renderer.root)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(motionChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    @objc private func motionChanged() { renderer.motionPreferenceChanged() }
}
