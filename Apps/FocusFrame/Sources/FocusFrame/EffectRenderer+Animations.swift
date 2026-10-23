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
        let entries = style.animations.active, now = CACurrentMediaTime()
        if continuousEpoch == 0 { continuousEpoch = now }
        if focusChanged || focusEpoch == 0 { focusEpoch = now }
        if focusChanged { focusUntil = now + entries.focusSpan }
        let focusActive = focusChanged || now < focusUntil
        for entry in entries where EffectAnimationPolicy.shouldAnimate(visible: visible, reducedMotion: reduced, trigger: entry.trigger, focusChanged: focusActive) {
            play(entry, epoch: entry.trigger == .continuous ? continuousEpoch : focusEpoch)
        }
    }

    private func play(_ entry: AnimationEntry, epoch: CFTimeInterval) {
        let metal = style.material.mode != .standard, gradientShown = !metal && style.gradient.mode != .off
        let starting = stages[entry.id]?.first.map { Double($0.presentation()?.opacity ?? $0.opacity) } ?? 1
        for track in entry.tracks(startingMultiplier: starting) {
            let key = "\(entry.id.uuidString)-\(track.property.rawValue)"
            func add(_ layers: [CALayer], _ keyPath: String, additive: Bool = false, _ value: (Double, CALayer) -> Any) {
                for layer in layers { layer.add(keyframes(track, keyPath, epoch, additive: additive) { value($0, layer) }, forKey: key) }
            }
            let accent = accents[entry.id].map { [$0 as CALayer] } ?? []
            switch track.property {
            case .accentOpacity: add(accent, "opacity") { v, _ in v }
            case .dashTravel: add(accent, "lineDashPhase") { v, _ in v * perimeter }
            case .strokeEnd: add(accent + drawMasks, "strokeEnd") { v, _ in v }
            case .opacityMultiplier: add(stages[entry.id] ?? [], "opacity") { v, _ in v }
            case .shadowBlurScale: add(shadowLayers.filter { $0.shadowPath != nil }, "shadowRadius") { v, _ in v * style.shadow.blur }
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
            case .reflectionOpacity: add(reflections.map(\.layer), "opacity") { v, _ in v }
            case .rotation, .colorMix: break
            }
        }
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
