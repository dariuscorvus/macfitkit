import AppKit
import QuartzCore
import CoreImage
import FocusFrameCore

@MainActor
final class EffectRenderer {
    let root = CALayer()
    private var gradients: [CAGradientLayer] = []
    private var reflections: [(layer: CAGradientLayer, travel: CGSize)] = []
    private var frameGroup = CALayer()
    private var shadowLayers: [CALayer] = []
    private var tightShadows: [(CALayer, Double)] = []
    private var lightLayers: [CALayer] = []
    private var drawMasks: [CAShapeLayer] = []
    private var accent: CAShapeLayer?
    private var perimeter = 1.0
    private var epoch: CFTimeInterval = 0
    private var focusUntil: CFTimeInterval = 0
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    private var style = Appearance()
    private var visible = false

    func update(bounds: CGRect, target: CGRect, style: Appearance, scale: CGFloat) {
        stop()
        if self.style != style.normalized { focusUntil = 0; epoch = 0 }
        self.style = style.normalized
        let a = self.style
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.transform = CATransform3DIdentity
        root.frame = bounds; root.contentsScale = scale; root.opacity = Float(a.opacity)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }; gradients.removeAll(); reflections.removeAll(); shadowLayers.removeAll(); lightLayers.removeAll(); tightShadows.removeAll(); drawMasks.removeAll(); accent = nil
        frameGroup = CALayer(); frameGroup.frame = bounds
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
            let offset = CGSize(width: a.shadow.offsetX, height: -a.shadow.offsetY)
            if a.shadow.colorSource == .gradient && (a.gradient.mode != .off || a.material.mode != .standard) {
                shadowLayers.append(addGradientShadow(to: effects, geometry: geometry, target: target, offset: offset, scale: scale))
                if a.motion.mode == .breathe && a.motion.target == .shadow {
                    let tight = addGradientShadow(to: effects, geometry: geometry, target: target, offset: offset, scale: scale, blur: a.shadow.blur*0.5)
                    tight.opacity = 0; tightShadows.append((tight, a.shadow.opacity))
                }
            } else {
                let inherited = a.material.mode == .standard ? EffectColor(a.red,a.green,a.blue) : a.material.baseColor
                shadowLayers.append(addShadow(to: effects, geometry: geometry, spread: a.shadow.spread,
                    color: a.shadow.colorSource == .custom ? a.shadow.color : inherited,
                    opacity: a.shadow.opacity, radius: a.shadow.blur, offset: offset, scale: scale))
            }
        }
        if a.light.mode != .off {
            let inherited = a.material.mode != .standard ? a.material.baseColor :
                (a.gradient.mode == .off ? EffectColor(a.red, a.green, a.blue) : a.gradient.stops.first?.color ?? EffectColor(a.red, a.green, a.blue))
            lightLayers.append(addShadow(to: effects, geometry: geometry, spread: 0,
                color: a.light.followsFrame ? inherited : a.light.color,
                opacity: a.light.intensity, radius: a.light.extent, offset: .zero, scale: scale))
        }
        root.addSublayer(frameGroup)
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
        if a.motion.mode == .impulse || a.motion.mode == .runner || a.motion.mode == .draw {
            let line = CAShapeLayer(); line.frame = bounds; line.path = contour
            line.fillColor = nil; line.strokeColor = NSColor.white.cgColor
            line.lineWidth = geometry.width; line.lineCap = .round; line.contentsScale = scale
            line.opacity = 0
            perimeter = max(1, 2*(geometry.rect.width + geometry.rect.height - 4*geometry.radius) + 2 * .pi * geometry.radius)
            if a.motion.mode == .runner { line.lineDashPattern = [NSNumber(value: perimeter*0.12), NSNumber(value: perimeter*0.88)] }
            frameGroup.addSublayer(line); accent = line
        }
        CATransaction.commit()
    }

    private func addShadow(to parent: CALayer, geometry: BorderContour, spread: Double, color: EffectColor,
                           opacity: Double, radius: Double, offset: CGSize, scale: CGFloat) -> CALayer {
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
        parent.addSublayer(layer); return layer
    }

    private func addBorder(contour: CGPath, ring: CGPath?, width: CGFloat, target: CGRect, bounds: CGRect,
                           whitening: Double, scale: CGFloat) {
        let mask = CAShapeLayer(); mask.path = ring ?? contour; mask.lineWidth = width
        mask.fillRule = .evenOdd
        mask.fillColor = ring == nil ? nil : NSColor.black.cgColor
        mask.strokeColor = ring == nil ? NSColor.black.cgColor : nil
        mask.contentsScale = scale
        if style.motion.mode == .draw {
            mask.path = contour; mask.fillColor = nil; mask.strokeColor = NSColor.black.cgColor
            drawMasks.append(mask)
        }
        let holder = CALayer(); holder.frame = bounds; holder.mask = mask; frameGroup.addSublayer(holder)
        let gradient = makeGradient(target: target, whitening: whitening, scale: scale)
        holder.addSublayer(gradient); gradients.append(gradient)
    }

    private func makeGradient(target: CGRect, whitening: Double = 0, scale: CGFloat) -> CAGradientLayer {
        let a = style
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
            let frame = EffectColor(a.red,a.green,a.blue)
            let stops = a.gradient.mode == .off ? [GradientStop(frame, at: 0), GradientStop(frame, at: 1)] : a.gradient.stops
            gradient.colors = stops.map { color($0.color) }
            gradient.locations = stops.map { NSNumber(value: $0.location) }
        }
        let conic = !metal && a.gradient.mode == .conic
        gradient.type = conic ? .conic : .axial
        gradient.startPoint = conic ? CGPoint(x: 0.5,y: 0.5) : CGPoint(x: 0,y: 0.5)
        gradient.endPoint = CGPoint(x: 1,y: 0.5)
        gradient.transform = CATransform3DMakeRotation((metal ? a.material.angle : a.gradient.angle) * .pi / 180, 0,0,1)
        return gradient
    }
    private func addGradientShadow(to parent: CALayer, geometry: BorderContour, target: CGRect, offset: CGSize, scale: CGFloat, blur: Double? = nil) -> CALayer {
        let bounds = root.bounds
        let holder = CALayer(); holder.frame = bounds; holder.opacity = Float(style.shadow.opacity)
        // One monochrome alpha mask per geometry; color and rotation stay live in CALayer.
        let resolution = min(scale, 1)
        let width = max(1, Int(ceil(bounds.width*resolution))), height = max(1, Int(ceil(bounds.height*resolution)))
        if let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            context.scaleBy(x: resolution, y: resolution)
            let spread = style.shadow.spread
            let outer = geometry.outerRect.insetBy(dx: -spread, dy: -spread).offsetBy(dx: offset.width, dy: offset.height)
            let inner = geometry.innerRect.insetBy(dx: spread, dy: spread).offsetBy(dx: offset.width, dy: offset.height)
            let path = CGMutablePath()
            path.addRoundedRect(in: outer, cornerWidth: geometry.outerRadius+spread, cornerHeight: geometry.outerRadius+spread)
            if inner.width > 0 && inner.height > 0 { path.addRoundedRect(in: inner, cornerWidth: max(0,geometry.innerRadius-spread), cornerHeight: max(0,geometry.innerRadius-spread)) }
            context.addPath(path); context.setFillColor(NSColor.white.cgColor); context.drawPath(using: .eoFill)
            if let image = context.makeImage() {
                let input = CIImage(cgImage: image)
                let blurred = input.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: (blur ?? style.shadow.blur)*resolution])
                if let maskImage = imageContext.createCGImage(blurred, from: CGRect(x: 0,y: 0,width: width,height: height)) {
                    let mask = CALayer(); mask.frame = bounds; mask.contents = maskImage; holder.mask = mask
                }
            }
        }
        // Fail closed: never turn a missing mask into a full-screen color rectangle.
        guard holder.mask != nil else { return holder }
        let gradient = makeGradient(target: target, scale: scale)
        holder.addSublayer(gradient); gradients.append(gradient); parent.addSublayer(holder)
        return holder
    }

    private func addReflection(ring: CGPath, target: CGRect, bounds: CGRect, scale: CGFloat) {
        let mask = CAShapeLayer(); mask.path = ring; mask.fillRule = .evenOdd
        mask.fillColor = NSColor.black.cgColor; mask.contentsScale = scale
        let holder = CALayer(); holder.frame = bounds; holder.mask = mask; frameGroup.addSublayer(holder)
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
        if !visible { stop(); epoch = 0; focusUntil = 0; return }
        animate(focusChanged: focusChanged)
    }
    func motionPreferenceChanged() { stop(); if visible { animate(focusChanged: false) } }
    func stop() {
        root.removeAllAnimations(); frameGroup.removeAllAnimations(); accent?.removeAllAnimations(); drawMasks.forEach { $0.removeAllAnimations() }
        (shadowLayers + lightLayers + tightShadows.map { $0.0 }).forEach { $0.removeAllAnimations() }
        gradients.forEach { $0.removeAllAnimations() }
        reflections.forEach { $0.layer.removeAllAnimations() }
    }
    func animate(focusChanged: Bool) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let a = style; var o = a.opacityAnimation
        let now = CACurrentMediaTime()
        if focusChanged || epoch == 0 { epoch = now }
        if focusChanged { focusUntil = now + max(a.motion.duration*a.motion.cycles, max(o.focusDuration, max(a.rotation.focusDuration,a.material.focusDuration))) }
        let focusChanged = focusChanged || now < focusUntil
        if a.motion.synchronize { o.trigger = a.motion.trigger; o.focusDuration = a.motion.duration*a.motion.cycles; o.pulsePeriod = a.motion.duration; o.blinkPeriod = a.motion.duration }
        if o.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced,
            trigger: o.trigger, focusChanged: focusChanged) {
            let period = o.mode == .pulse ? o.pulsePeriod : o.blinkPeriod
            let minimum = o.mode == .pulse ? o.pulseMinimum : o.blinkMinimum
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            if o.trigger == .focus {
                let source = layers(for: o.target).first ?? root
                let current = Double(source.presentation()?.opacity ?? source.opacity) / max(0.001, Double(source.opacity))
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
            animation.beginTime = epoch
            let targets = layers(for: o.target)
            for target in targets {
                let targeted = animation.copy() as! CAKeyframeAnimation
                if o.target != .all { targeted.values = (animation.values as? [Double])?.map { $0 / a.opacity * Double(target.opacity) } }
                target.add(targeted, forKey: "opacityEffect")
            }
        }
        var r = a.rotation
        if a.motion.synchronize { r.trigger = a.motion.trigger; r.period = a.motion.duration; r.focusDuration = a.motion.duration*a.motion.cycles }
        if r.enabled && a.material.mode == .standard && a.gradient.mode != .off && EffectAnimationPolicy.shouldAnimate(visible: visible,
            reducedMotion: reduced, trigger: r.trigger, focusChanged: focusChanged) {
            for gradient in gradients {
                let animation = CABasicAnimation(keyPath: "transform.rotation.z")
                let angle = a.gradient.angle * .pi / 180
                animation.fromValue = angle; animation.toValue = angle + (r.clockwise ? -2 : 2) * .pi
                animation.duration = r.period
                animation.repeatDuration = r.trigger == .continuous ? .infinity : r.focusDuration
                animation.beginTime = epoch
                gradient.add(animation, forKey: "rotationEffect")
            }
        }
        var m = a.material
        if a.motion.synchronize { m.trigger = a.motion.trigger; m.period = a.motion.duration; m.focusDuration = a.motion.duration*a.motion.cycles }
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
                let duration = m.trigger == .focus ? (a.motion.synchronize ? a.motion.duration : m.focusDuration) : m.period
                position.duration = duration; opacity.duration = duration
                let group = CAAnimationGroup(); group.animations = [position,opacity]; group.duration = duration
                group.beginTime = epoch
                group.repeatCount = m.trigger == .continuous ? .infinity : (a.motion.synchronize ? Float(a.motion.cycles-1) : 0)
                layer.add(group, forKey: "metalReflection")
            }
        }
        animateMotion(reduced: reduced, focusChanged: focusChanged)
    }
    private func layers(for target: AnimationTarget) -> [CALayer] {
        switch target { case .all: [root]; case .frame: [frameGroup]; case .light: lightLayers; case .shadow: shadowLayers }
    }
    private func animateMotion(reduced: Bool, focusChanged: Bool) {
        let m = style.motion
        guard m.mode != .off, EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced, trigger: m.trigger, focusChanged: focusChanged) else { return }
        let timing = CAMediaTimingFunction(name: m.curve == .linear ? .linear : .easeInEaseOut)
        func add(_ animation: CAAnimation, to layer: CALayer, key: String) {
            animation.duration = m.duration; animation.beginTime = epoch
            animation.repeatCount = m.trigger == .continuous ? .infinity : Float(m.cycles - 1)
            animation.timingFunction = timing
            if let frames = animation as? CAKeyframeAnimation, let values = frames.values { frames.timingFunctions = Array(repeating: timing, count: max(0, values.count-1)) }
            layer.add(animation, forKey: key)
        }
        if m.mode == .runner || m.mode == .draw || m.mode == .impulse, let accent {
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0,m.strength,m.strength,0]; fade.keyTimes = [0,0.12,0.85,1]
            if m.mode == .impulse { fade.values = m.curve == .spring ? [0,m.strength,m.strength*0.3,m.strength*0.6,0] : [0,m.strength,0]; fade.keyTimes = m.curve == .spring ? [0,0.15,0.45,0.65,1] : [0,0.2,1] }
            add(fade, to: accent, key: "motionVisibility")
            if m.mode == .runner {
                let travel = CABasicAnimation(keyPath: "lineDashPhase"); travel.fromValue = 0; travel.toValue = -perimeter
                add(travel, to: accent, key: "motionRunner")
            } else if m.mode == .draw {
                let draw = CABasicAnimation(keyPath: "strokeEnd"); draw.fromValue = 0; draw.toValue = 1
                add(draw, to: accent, key: "motionDraw")
                for mask in drawMasks { add(draw, to: mask, key: "motionTrace") }
            }
        } else if m.mode == .breathe {
            for layer in layers(for: m.target) {
                let fade = CAKeyframeAnimation(keyPath: "opacity"); let base = Double(layer.opacity)
                fade.values = [base,base*(1-m.strength),base]; fade.keyTimes = [0,0.5,1]
                add(fade, to: layer, key: "motionBreathe")
                if m.target == .shadow && layer.shadowPath != nil {
                    let blur = CAKeyframeAnimation(keyPath: "shadowRadius"); blur.values = [style.shadow.blur,style.shadow.blur*0.5,style.shadow.blur]; blur.keyTimes = [0,0.5,1]
                    add(blur, to: layer, key: "motionBlur")
                }
            }
            for (tight, base) in tightShadows {
                let fade = CAKeyframeAnimation(keyPath: "opacity"); fade.values = [0,base*m.strength,0]; fade.keyTimes = [0,0.5,1]
                add(fade, to: tight, key: "motionTightShadow")
            }
        } else if m.mode == .flow && style.material.mode == .standard && style.gradient.mode != .off {
            for gradient in gradients {
                let order = style.gradient.flowOrder()
                guard let colors = gradient.colors, colors.count >= 2, order.count == colors.count else { continue }
                let flow = CAKeyframeAnimation(keyPath: "colors")
                let swapped = order.map { colors[$0] }
                let blended: [Any] = zip(colors,swapped).map { original, changed in
                    guard let first = NSColor(cgColor: original as! CGColor), let second = NSColor(cgColor: changed as! CGColor) else { return original }
                    return first.blended(withFraction: m.strength, of: second)?.cgColor ?? original
                }
                flow.values = [colors,blended,colors]; flow.keyTimes = [0,0.5,1]
                add(flow, to: gradient, key: "motionFlow")
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
