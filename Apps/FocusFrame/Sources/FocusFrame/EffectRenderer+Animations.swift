import AppKit
import QuartzCore
import FocusFrameCore

/// Plays the appearance's animation entries. Each entry's keyframe tracks come from `FocusFrameCore`;
/// this file only maps them onto layers.
///
/// Entries on the same property combine by layer structure: opacity entries animate their own nested stage (multiply),
/// rotation is additive (add), and for colors the later entry in the list replaces the earlier one (lower wins).
extension EffectRenderer {
    func setVisible(_ visible: Bool, focusChanged: Bool = false) {
        self.visible = visible
        if !visible { stop(); continuousEpoch = 0; focusEpoch = 0; focusUntil = 0; return }
        animate(focusChanged: focusChanged)
    }
    func motionPreferenceChanged() { stop(); if visible { animate(focusChanged: false) } }

    func stop() {
        var all: [CALayer] = [root, content, frameGroup] + shadowLayers + lightLayers + tightShadows.map(\.0) + gradients + reflections.map(\.layer)
        all += drawMasks as [CALayer] + Array(accents.values) as [CALayer] + stages.values.flatMap { $0 }
        all.forEach { $0.removeAllAnimations() }
    }

    /// Wraps each target layer of every opacity entry in its own stage layer, in list order.
    func buildStages(for entries: [AnimationEntry]) {
        for entry in entries where entry.kind.multipliesOpacity {
            stages[entry.id] = targetLayers(entry.target).map(wrap)
        }
    }

    private func targetLayers(_ target: AnimationTarget) -> [CALayer] {
        switch target { case .all: [content]; case .frame: [frameGroup]; case .light: lightLayers; case .shadow: shadowLayers }
    }

    /// Puts a full-size stage layer where `layer` was and moves `layer` into it. Masks and frames stay on `layer`.
    private func wrap(_ layer: CALayer) -> CALayer {
        let stage = CALayer()
        guard let parent = layer.superlayer else { return stage }
        stage.frame = parent.bounds
        parent.insertSublayer(stage, above: layer); layer.removeFromSuperlayer(); stage.addSublayer(layer)
        return stage
    }

    func animate(focusChanged: Bool) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let schedule = AnimationSchedule.make(style.animations), now = CACurrentMediaTime()
        if continuousEpoch == 0 { continuousEpoch = now }
        if focusChanged || focusEpoch == 0 { focusEpoch = now }
        if focusChanged { focusUntil = now + AnimationSchedule.focusEnd(style.animations) }
        let focusActive = focusChanged || now < focusUntil
        for item in schedule where EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced, trigger: item.entry.trigger, focusChanged: focusActive) {
            let continuous = item.entry.trigger == .continuous
            play(item, epoch: continuous ? continuousEpoch : focusEpoch, handOff: focusChanged && !continuous)
        }
    }

    /// `handOff`: a new focus change interrupts what is playing, so number properties start from what is visible.
    private func play(_ item: ScheduledEntry, epoch: CFTimeInterval, handOff: Bool) {
        let entry = item.entry
        let metal = style.material.mode != .standard, gradientShown = !metal && style.gradient.mode != .off
        let starting = stages[entry.id]?.first.map { Double($0.presentation()?.opacity ?? $0.opacity) } ?? 1
        let sources = item.morphSource.map { source in source.entry.tracks().map { track -> AnimationTrack in var t = track; t.delay = source.begin; return t } } ?? []
        for var track in entry.tracks(startingMultiplier: starting) {
            if entry.trigger == .focus {
                track.delay = item.begin
                // Morph: the source stops at the window and this entry continues from its values on the same layers.
                if let cut = item.cut { track = track.ending(at: cut - item.begin) }
                if let window = item.morph, let source = sources.first(where: { $0.property == track.property }) {
                    track = track.morphed(from: source, sourceOffset: source.delay - item.begin, window: window)
                }
                track = track.weighted(by: item.fades)
            }
            let key = "\(entry.id.uuidString)-\(track.property.rawValue)"
            /// `scale` converts track units to the layer value; number properties with a running animation hand off from it.
            func add(_ layers: [CALayer], _ keyPath: String, additive: Bool = false, scale: Double? = nil, _ value: (Double, CALayer) -> Any) {
                var played = track
                if handOff, let scale, scale != 0, let layer = layers.first, layer.animation(forKey: key) != nil,
                   let shown = (layer.presentation()?.value(forKeyPath: keyPath) as? NSNumber)?.doubleValue {
                    played = track.handingOff(from: shown / scale)
                }
                for layer in layers { layer.add(keyframes(played, keyPath, epoch, additive: additive) { value($0, layer) }, forKey: key) }
            }
            let accent = accents[entry.id].map { [$0 as CALayer] } ?? []
            switch track.property {
            case .accentOpacity: add(accent, "opacity", scale: 1) { v, _ in v }
            case .dashTravel: add(accent, "lineDashPhase") { v, _ in v * perimeter }
            case .strokeEnd: add(accent + drawMasks, "strokeEnd", scale: 1) { v, _ in v }
            case .opacityMultiplier: add(stages[entry.id] ?? [], "opacity", scale: 1) { v, _ in v }
            case .shadowBlurScale: add(shadowLayers.filter { $0.shadowPath != nil }, "shadowRadius", scale: style.shadow.blur) { v, _ in v * style.shadow.blur }
            case .tightShadow:
                for (layer, base) in tightShadows { layer.add(keyframes(track, "opacity", epoch) { $0 * base }, forKey: key) }
            case .rotation where gradientShown: add(gradients, "transform.rotation.z", additive: true) { v, _ in v }
            case .colorMix where gradientShown:
                let order = style.gradient.flowOrder()
                for gradient in gradients {
                    guard let colors = gradient.colors as? [CGColor], colors.count >= 2, order.count == colors.count else { continue }
                    let partners = order.map { colors[$0] }
                    gradient.add(keyframes(track, "colors", epoch) { v in zip(colors, partners).map { mix($0, $1, v) } }, forKey: key)
                }
            case .reflectionTravel:
                for reflection in reflections {
                    let center = reflection.layer.position, travel = reflection.travel
                    reflection.layer.add(keyframes(track, "position", epoch) { v in NSValue(point: CGPoint(x: center.x + travel.width * v, y: center.y + travel.height * v)) }, forKey: key)
                }
            case .reflectionOpacity: add(reflections.map(\.layer), "opacity", scale: 1) { v, _ in v }
            case .rotation, .colorMix: break
            }
        }
    }

    /// A changed frame color or gradient blends over 0.3 s instead of jumping. Both stop lists are aligned to the union
    /// of their positions; the layers keep the new stops as their model, so colour flow still sees the right count.
    func morphColors(from previous: Appearance) {
        guard visible, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion, previous != style,
              Self.surfaceKind(previous) == Self.surfaceKind(style) else { return }
        let (from, to) = GradientEffect.aligned(Self.surfaceStops(previous), Self.surfaceStops(style))
        guard from != to else { return }
        let locations = to.map { NSNumber(value: $0.location) }
        for gradient in gradients {
            let w = gradientWhitening[ObjectIdentifier(gradient)] ?? 0
            func color(_ c: EffectColor) -> CGColor {
                NSColor(srgbRed: c.red + (1 - c.red) * w, green: c.green + (1 - c.green) * w, blue: c.blue + (1 - c.blue) * w, alpha: 1).cgColor
            }
            let colors = CABasicAnimation(keyPath: "colors"); colors.fromValue = from.map { color($0.color) }; colors.toValue = to.map { color($0.color) }
            let positions = CABasicAnimation(keyPath: "locations"); positions.fromValue = locations; positions.toValue = locations
            let group = CAAnimationGroup(); group.animations = [colors, positions]; group.duration = 0.3
            group.timingFunction = TimingCurve.easeInOut.mediaTimingFunction
            gradient.add(group, forKey: "appearanceMorph")
        }
    }

    /// Gradients only morph within one kind; switching between metal, linear and conic redraws.
    private static func surfaceKind(_ a: Appearance) -> String {
        a.material.mode != .standard ? "metal" : a.gradient.mode == .conic ? "conic" : "axial"
    }
    private static func surfaceStops(_ a: Appearance) -> [GradientStop] {
        if a.material.mode != .standard { return a.material.stops.map { GradientStop($0.color, at: $0.location) } }
        let frame = EffectColor(a.red, a.green, a.blue)
        return a.gradient.mode == .off ? [GradientStop(frame, at: 0), GradientStop(frame, at: 1)] : a.gradient.stops
    }

    private func keyframes(_ track: AnimationTrack, _ keyPath: String, _ epoch: CFTimeInterval, additive: Bool = false, _ value: (Double) -> Any) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = track.values.map(value)
        animation.keyTimes = track.keyTimes.map { NSNumber(value: $0) }
        animation.timingFunctions = track.timings.map(\.mediaTimingFunction)
        animation.calculationMode = .linear; animation.isAdditive = additive
        animation.duration = track.duration; animation.repeatCount = Float(track.repeatCount)
        animation.beginTime = epoch + track.delay
        return animation
    }

    private func mix(_ a: CGColor, _ b: CGColor, _ fraction: Double) -> CGColor {
        guard let first = NSColor(cgColor: a), let second = NSColor(cgColor: b) else { return a }
        return first.blended(withFraction: fraction, of: second)?.cgColor ?? a
    }
}

extension TimingCurve {
    /// Only linear and Bézier reach Core Animation; `AnimationTrack` samples every other curve into linear segments.
    var mediaTimingFunction: CAMediaTimingFunction {
        if case .bezier(let x1, let y1, let x2, let y2) = self { return CAMediaTimingFunction(controlPoints: Float(x1), Float(y1), Float(x2), Float(y2)) }
        return CAMediaTimingFunction(name: .linear)
    }
}
