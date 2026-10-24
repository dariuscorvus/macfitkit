import AppKit
import QuartzCore
import CoreImage
import FocusFrameCore

@MainActor
final class EffectRenderer {
    let root = CALayer()
    // Animated layers; `EffectRenderer+Animations.swift` drives them.
    var gradients: [CAGradientLayer] = []
    /// Whitening per gradient layer (the neon core is lighter), so a color morph can rebuild its colors.
    var gradientWhitening: [ObjectIdentifier: Double] = [:]
    var reflections: [(layer: CAGradientLayer, travel: CGSize)] = []
    var frameGroup = CALayer()
    /// Everything inside `root`; opacity stages for the "Alles" target wrap it.
    var content = CALayer()
    var shadowLayers: [CALayer] = []
    var tightShadows: [(CALayer, Double)] = []
    var lightLayers: [CALayer] = []
    var drawMasks: [CAShapeLayer] = []
    /// One highlight line per pulse, runner or draw entry.
    var accents: [UUID: CAShapeLayer] = [:]
    /// One opacity stage per target layer and opacity entry. Nested stages multiply.
    var stages: [UUID: [CALayer]] = [:]
    var perimeter = 1.0
    /// Continuous entries keep this clock across focus changes; focus entries start at `focusEpoch`.
    var continuousEpoch: CFTimeInterval = 0
    var focusEpoch: CFTimeInterval = 0
    var focusUntil: CFTimeInterval = 0
    private let imageContext = CIContext(options: [.cacheIntermediates: false])
    var style = Appearance()
    var visible = false

    func update(bounds: CGRect, target: CGRect, style: Appearance, scale: CGFloat) {
        stop()
        let previous = self.style, hadContent = !(root.sublayers ?? []).isEmpty
        if self.style != style.normalized { focusUntil = 0; focusEpoch = 0; continuousEpoch = 0 }
        self.style = style.normalized
        let a = self.style, entries = a.animations.active
        func uses(_ kind: AnimationKind) -> Bool { entries.contains { $0.kind == kind } }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        root.transform = CATransform3DIdentity
        root.frame = bounds; root.contentsScale = scale; root.opacity = Float(a.opacity)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }; gradients.removeAll(); gradientWhitening.removeAll(); reflections.removeAll(); shadowLayers.removeAll(); lightLayers.removeAll(); tightShadows.removeAll(); drawMasks.removeAll(); accents.removeAll(); stages.removeAll()
        content = CALayer(); content.frame = bounds; root.addSublayer(content)
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
        content.addSublayer(effects)
        if a.shadow.enabled {
            let offset = CGSize(width: a.shadow.offsetX, height: -a.shadow.offsetY)
            if a.shadow.colorSource == .gradient && (a.gradient.mode != .off || a.material.mode != .standard) {
                shadowLayers.append(addGradientShadow(to: effects, geometry: geometry, target: target, offset: offset, scale: scale))
                if entries.contains(where: { $0.kind == .breathe && $0.target == .shadow }) {
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
        content.addSublayer(frameGroup)
        let ring = CGMutablePath()
        ring.addRoundedRect(in: geometry.outerRect, cornerWidth: geometry.outerRadius, cornerHeight: geometry.outerRadius)
        ring.addRoundedRect(in: geometry.innerRect, cornerWidth: geometry.innerRadius, cornerHeight: geometry.innerRadius)
        addBorder(contour: contour, ring: ring, width: geometry.width, target: target, bounds: bounds, whitening: 0, scale: scale)
        if a.material.mode != .standard && uses(.metalReflection) {
            addReflection(ring: ring, target: target, bounds: bounds, scale: scale)
        }
        if a.light.mode == .neon {
            addBorder(contour: contour, ring: nil, width: geometry.width * a.light.coreWidth, target: target,
                bounds: bounds, whitening: a.light.whitening, scale: scale)
        }
        perimeter = max(1, 2*(geometry.rect.width + geometry.rect.height - 4*geometry.radius) + 2 * .pi * geometry.radius)
        for entry in entries where [.focusPulse, .runner, .draw].contains(entry.kind) {
            let line = CAShapeLayer(); line.frame = bounds; line.path = contour
            line.fillColor = nil; line.strokeColor = NSColor.white.cgColor
            line.lineWidth = geometry.width; line.lineCap = .round; line.contentsScale = scale
            line.opacity = 0
            if entry.kind == .runner { line.lineDashPattern = [NSNumber(value: perimeter*0.12), NSNumber(value: perimeter*0.88)] }
            frameGroup.addSublayer(line); accents[entry.id] = line
        }
        buildStages(for: entries)
        if hadContent { morphColors(from: previous) }
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
        if style.animations.active.contains(where: { $0.kind == .draw }) {
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
        gradientWhitening[ObjectIdentifier(gradient)] = whitening
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
