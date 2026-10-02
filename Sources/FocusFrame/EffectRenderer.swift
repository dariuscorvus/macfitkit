import AppKit
import QuartzCore
import FocusFrameCore

@MainActor
final class EffectRenderer {
    let root = CALayer()
    private var gradients: [CAGradientLayer] = []
    private var reflections: [(layer: CAGradientLayer, travel: CGSize)] = []
    private var style = Appearance()
    private var visible = false

    func update(bounds: CGRect, target: CGRect, style: Appearance, scale: CGFloat) {
        stop()
        self.style = style.normalized
        let a = self.style
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.transform = CATransform3DIdentity
        root.frame = bounds; root.contentsScale = scale; root.opacity = Float(a.opacity)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }; gradients.removeAll(); reflections.removeAll()
        let geometry = EffectGeometry.contour(for: target, appearance: a)
        let contour = CGPath(roundedRect: geometry.rect, cornerWidth: geometry.radius,
                             cornerHeight: geometry.radius, transform: nil)
        // Keep the central window area clear for every placement, including inside.
        let exterior = CGMutablePath(); exterior.addRect(bounds)
        let hole = a.placement == .outside ? target : geometry.innerRect
        let holeRadius = a.placement == .outside ? min(a.radius, min(target.width,target.height)/2) : geometry.innerRadius
        exterior.addRoundedRect(in: hole, cornerWidth: holeRadius, cornerHeight: holeRadius)
        let exteriorMask = CAShapeLayer(); exteriorMask.path = exterior
        exteriorMask.contentsScale = scale
        exteriorMask.fillRule = .evenOdd; exteriorMask.fillColor = NSColor.black.cgColor
        let effects = CALayer(); effects.frame = bounds; effects.mask = exteriorMask
        root.addSublayer(effects)
        if a.shadow.enabled {
            addShadow(to: effects, geometry: geometry, spread: a.shadow.spread,
                color: a.shadow.color, opacity: a.shadow.opacity, radius: a.shadow.blur,
                offset: CGSize(width: a.shadow.offsetX, height: -a.shadow.offsetY), scale: scale)
        }
        if a.light.mode != .off {
            let inherited = a.material.mode != .standard ? a.material.baseColor :
                (a.gradient.mode == .off ? EffectColor(a.red, a.green, a.blue) : a.gradient.first)
            addShadow(to: effects, geometry: geometry, spread: 0,
                color: a.light.followsFrame ? inherited : a.light.color,
                opacity: a.light.intensity, radius: a.light.extent, offset: .zero, scale: scale)
        }
        let ring = CGMutablePath()
        ring.addRoundedRect(in: geometry.outerRect, cornerWidth: geometry.outerRadius, cornerHeight: geometry.outerRadius)
        ring.addRoundedRect(in: geometry.innerRect, cornerWidth: geometry.innerRadius, cornerHeight: geometry.innerRadius)
        addBorder(contour: contour, ring: ring, width: geometry.width, target: target, bounds: bounds, whitening: 0, scale: scale)
        if a.material.mode != .standard && a.material.reflectionEnabled {
            addReflection(ring: ring, target: target, bounds: bounds, scale: scale)
        }
        if a.light.mode == .neon {
            addBorder(contour: contour, ring: nil, width: geometry.width * a.light.coreWidth, target: target,
                bounds: bounds, whitening: a.light.whitening, scale: scale)
        }
        CATransaction.commit()
    }

    private func addShadow(to parent: CALayer, geometry: BorderContour, spread: Double, color: EffectColor,
                           opacity: Double, radius: Double, offset: CGSize, scale: CGFloat) {
        let layer = CALayer(); layer.frame = root.bounds; layer.contentsScale = scale
        let outer = geometry.outerRect.insetBy(dx: -spread,dy: -spread)
        let inner = geometry.innerRect.insetBy(dx: spread,dy: spread)
        let path = CGMutablePath()
        path.addRoundedRect(in: outer, cornerWidth: geometry.outerRadius == 0 ? 0 : geometry.outerRadius+spread,
                            cornerHeight: geometry.outerRadius == 0 ? 0 : geometry.outerRadius+spread)
        if inner.width > 0 && inner.height > 0 {
            let innerPath = CGPath(roundedRect: inner, cornerWidth: max(0,geometry.innerRadius-spread),
                                  cornerHeight: max(0,geometry.innerRadius-spread), transform: nil)
            // Opposite winding preserves the hole under CALayer's nonzero fill.
            var mirror = CGAffineTransform(translationX: 2*inner.midX,y: 0).scaledBy(x: -1,y: 1)
            if let reversed = innerPath.copy(using: &mirror) { path.addPath(reversed) }
        }
        layer.shadowPath = path
        layer.shadowColor = color.nsColor.cgColor; layer.shadowOpacity = Float(opacity)
        layer.shadowRadius = radius; layer.shadowOffset = offset
        parent.addSublayer(layer)
    }

    private func addBorder(contour: CGPath, ring: CGPath?, width: CGFloat, target: CGRect, bounds: CGRect,
                           whitening: Double, scale: CGFloat) {
        let a = style
        let mask = CAShapeLayer(); mask.path = ring ?? contour; mask.lineWidth = width
        mask.fillRule = .evenOdd
        mask.fillColor = ring == nil ? nil : NSColor.black.cgColor
        mask.strokeColor = ring == nil ? NSColor.black.cgColor : nil
        mask.contentsScale = scale
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
        let metal = a.material.mode != .standard
        if metal {
            gradient.colors = a.material.stops.map { color($0.color) }
            gradient.locations = a.material.stops.map { NSNumber(value: $0.location) }
        } else {
            let first = a.gradient.mode == .off ? EffectColor(a.red,a.green,a.blue) : a.gradient.first
            let second = a.gradient.mode == .off ? first : a.gradient.second
            gradient.colors = a.gradient.mode == .conic ? [color(first), color(second), color(first)] : [color(first),color(second)]
            gradient.locations = a.gradient.mode == .conic ? [0,0.5,1] : [0,1]
        }
        let conic = !metal && a.gradient.mode == .conic
        gradient.type = conic ? .conic : .axial
        gradient.startPoint = conic ? CGPoint(x: 0.5,y: 0.5) : CGPoint(x: 0,y: 0.5)
        gradient.endPoint = CGPoint(x: 1,y: 0.5)
        gradient.transform = CATransform3DMakeRotation((metal ? a.material.angle : a.gradient.angle) * .pi / 180, 0,0,1)
        holder.addSublayer(gradient); gradients.append(gradient)
    }

    private func addReflection(ring: CGPath, target: CGRect, bounds: CGRect, scale: CGFloat) {
        let mask = CAShapeLayer(); mask.path = ring; mask.fillRule = .evenOdd
        mask.fillColor = NSColor.black.cgColor; mask.contentsScale = scale
        let holder = CALayer(); holder.frame = bounds; holder.mask = mask; root.addSublayer(holder)
        let m = style.material
        let side = hypot(bounds.width, bounds.height) + 2
        let reflection = CAGradientLayer(); reflection.contentsScale = scale
        reflection.bounds = CGRect(x: 0,y: 0,width: side,height: side)
        reflection.position = CGPoint(x: target.midX,y: target.midY)
        let clear = NSColor.white.withAlphaComponent(0).cgColor
        reflection.colors = [clear,clear,NSColor.white.withAlphaComponent(m.reflectionStrength).cgColor,clear,clear]
        reflection.locations = [0, NSNumber(value: 0.5-m.reflectionWidth/2), 0.5, NSNumber(value: 0.5+m.reflectionWidth/2), 1]
        reflection.startPoint = CGPoint(x: 0,y: 0.5); reflection.endPoint = CGPoint(x: 1,y: 0.5)
        let angle = m.angle * .pi / 180
        reflection.transform = CATransform3DMakeRotation(angle,0,0,1)
        // The model remains invisible, so a focus sweep fades back to the static metal.
        reflection.opacity = 0
        holder.addSublayer(reflection)
        reflections.append((reflection, CGSize(width: cos(angle)*side, height: sin(angle)*side)))
    }

    func setVisible(_ visible: Bool, focusChanged: Bool = false) {
        self.visible = visible
        if !visible { stop(); return }
        animate(focusChanged: focusChanged)
    }
    func motionPreferenceChanged() { stop(); if visible { animate(focusChanged: false) } }
    func stop() {
        root.removeAllAnimations(); gradients.forEach { $0.removeAllAnimations() }
        reflections.forEach { $0.layer.removeAllAnimations() }
    }
    func animate(focusChanged: Bool) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let a = style; let o = a.opacityAnimation
        if o.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced,
            trigger: o.trigger, focusChanged: focusChanged) {
            let period = o.mode == .pulse ? o.pulsePeriod : o.blinkPeriod
            let minimum = o.mode == .pulse ? o.pulseMinimum : o.blinkMinimum
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            if o.trigger == .focus {
                let current = Double(root.presentation()?.opacity ?? root.opacity) / a.opacity
                let timeline = FocusOpacityTimeline(effect: o, startingMultiplier: current)
                animation.values = timeline.values.map { $0 * a.opacity }
                animation.keyTimes = timeline.times.map { NSNumber(value: $0) }
                animation.duration = timeline.duration
                animation.calculationMode = .linear
            } else if o.mode == .pulse {
                animation.values = [o.maximum*a.opacity, minimum*a.opacity, o.maximum*a.opacity]
                animation.keyTimes = [0,0.5,1]
                animation.timingFunctions = [.init(name: .easeInEaseOut),.init(name: .easeInEaseOut)]
            } else {
                animation.values = [o.maximum*a.opacity,o.maximum*a.opacity,minimum*a.opacity,minimum*a.opacity,o.maximum*a.opacity]
                animation.keyTimes = [0,0.1,0.2,0.8,1]
            }
            if o.trigger == .continuous {
                animation.duration = period
                animation.repeatDuration = .infinity
            }
            root.add(animation, forKey: "opacityEffect")
        }
        let r = a.rotation
        if r.enabled && a.material.mode == .standard && a.gradient.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible,
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
        let m = a.material
        if m.mode != .standard && m.reflectionEnabled && EffectAnimationPolicy.shouldAnimate(visible: visible,
            reducedMotion: reduced, trigger: m.trigger, focusChanged: focusChanged) {
            for reflection in reflections {
                let layer = reflection.layer
                let position = CABasicAnimation(keyPath: "position")
                let center = layer.position
                position.fromValue = NSValue(point: CGPoint(x: center.x-reflection.travel.width/2, y: center.y-reflection.travel.height/2))
                position.toValue = NSValue(point: CGPoint(x: center.x+reflection.travel.width/2, y: center.y+reflection.travel.height/2))
                let opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [0,1,1,0]; opacity.keyTimes = [0,0.15,0.85,1]
                opacity.timingFunctions = [.init(name: .easeInEaseOut),.init(name: .linear),.init(name: .easeInEaseOut)]
                let duration = m.trigger == .focus ? m.focusDuration : m.period
                position.duration = duration; opacity.duration = duration
                let group = CAAnimationGroup(); group.animations = [position,opacity]; group.duration = duration
                group.beginTime = CACurrentMediaTime()
                group.repeatCount = m.trigger == .continuous ? .infinity : 0
                layer.add(group, forKey: "metalReflection")
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
