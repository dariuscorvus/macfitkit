import Foundation

/// Keyframes for one animated property, ready for a Core Animation keyframe animation.
/// Values are relative: multipliers, fractions of the frame's perimeter, radians or a color mix.
public struct AnimationTrack: Equatable, Sendable {
    public enum Property: String, Sendable {
        /// Multiplier on the target layer's opacity. Several multiply through nested layers.
        case opacityMultiplier
        /// Opacity of the entry's own highlight line.
        case accentOpacity
        /// Dash phase as a fraction of the perimeter (runner).
        case dashTravel
        /// Stroke end of the highlight line and the frame's draw mask (draw).
        case strokeEnd
        /// Added rotation of the gradient in radians.
        case rotation
        /// How far each gradient stop moves toward its flow partner's color, 0…1.
        case colorMix
        /// Multiplier on the shadow blur radius (breathing shadow).
        case shadowBlurScale
        /// Multiplier on the tight inner shadow's opacity (breathing shadow).
        case tightShadow
        /// Reflection position along its travel, −0.5…0.5.
        case reflectionTravel
        case reflectionOpacity
    }

    public var property: Property
    public var values: [Double]
    public var keyTimes: [Double]
    /// One timing per segment, each `.linear` or a Bézier that `CAMediaTimingFunction` can express.
    public var timings: [TimingCurve]
    /// One cycle in seconds.
    public var duration: Double
    /// Total cycles; `.infinity` for continuous entries.
    public var repeatCount: Double
    public var delay: Double

    /// Curves Core Animation cannot express are baked in: each such segment becomes linear sub-segments sampled from the curve.
    init(_ property: Property, _ values: [Double], _ keyTimes: [Double], curves: [TimingCurve], duration: Double, repeatCount: Double, delay: Double) {
        var v = [values[0]], k = [keyTimes[0]], t: [TimingCurve] = []
        for i in 0..<(values.count - 1) {
            let curve = curves[min(i, curves.count - 1)]
            if curve.isNativeTiming {
                v.append(values[i + 1]); k.append(keyTimes[i + 1]); t.append(curve)
            } else {
                for step in 1...Self.samplesPerSegment {
                    let u = Double(step) / Double(Self.samplesPerSegment)
                    v.append(values[i] + (values[i + 1] - values[i]) * curve.value(at: u))
                    k.append(keyTimes[i] + (keyTimes[i + 1] - keyTimes[i]) * u); t.append(.linear)
                }
            }
        }
        self.property = property; self.values = v; self.keyTimes = k; timings = t
        self.duration = duration; self.repeatCount = repeatCount; self.delay = delay
    }
    static let samplesPerSegment = 24
}

public extension TimingCurve {
    /// Linear and cubic Bézier map directly onto `CAMediaTimingFunction`.
    var isNativeTiming: Bool { if case .linear = self { true } else if case .bezier = self { true } else { false } }
}

public extension AnimationEntry {
    /// Keyframe tracks for this entry. `startingMultiplier` is the target's current opacity multiplier,
    /// so a focus-triggered opacity entry continues from what is visible instead of jumping.
    func tracks(startingMultiplier: Double = 1) -> [AnimationTrack] {
        let e = normalized, s = e.strength, c = e.curve
        let cycles = e.trigger == .continuous ? Double.infinity : e.repeats
        func track(_ p: AnimationTrack.Property, _ values: [Double], _ times: [Double], _ curves: [TimingCurve]? = nil) -> AnimationTrack {
            AnimationTrack(p, values, times, curves: curves ?? [c], duration: e.duration, repeatCount: cycles, delay: e.delay)
        }
        let fade = track(.accentOpacity, [0, s, s, 0], [0, 0.12, 0.85, 1])
        switch e.kind {
        case .focusPulse:
            return [e.bounce ? track(.accentOpacity, [0, s, s * 0.3, s * 0.6, 0], [0, 0.15, 0.45, 0.65, 1]) : track(.accentOpacity, [0, s, 0], [0, 0.2, 1])]
        case .runner: return [fade, track(.dashTravel, [0, -1], [0, 1])]
        case .draw: return [fade, track(.strokeEnd, [0, 1], [0, 1])]
        case .breathe:
            var result = [track(.opacityMultiplier, [1, 1 - s, 1], [0, 0.5, 1])]
            if e.target == .shadow { result += [track(.shadowBlurScale, [1, 0.5, 1], [0, 0.5, 1]), track(.tightShadow, [0, s, 0], [0, 0.5, 1])] }
            return result
        case .colorFlow: return [track(.colorMix, [0, s, 0], [0, 0.5, 1])]
        case .gradientRotation: return [track(.rotation, [0, (e.clockwise ? -2 : 2) * .pi], [0, 1])]
        case .opacityPulse, .opacityBlink:
            if e.trigger == .focus {
                // One sampled timeline over the whole focus span: it eases in from the current multiplier and back out to 1.
                let timeline = FocusOpacityTimeline(blink: e.kind == .opacityBlink, period: e.duration, minimum: e.minimum, maximum: e.maximum,
                                                    duration: e.duration * e.repeats, startingMultiplier: startingMultiplier)
                return [AnimationTrack(.opacityMultiplier, timeline.values, timeline.times, curves: [.linear], duration: timeline.duration, repeatCount: 1, delay: e.delay)]
            }
            return e.kind == .opacityPulse ? [track(.opacityMultiplier, [e.maximum, e.minimum, e.maximum], [0, 0.5, 1])]
                : [track(.opacityMultiplier, [e.maximum, e.maximum, e.minimum, e.minimum, e.maximum], [0, 0.1, 0.2, 0.8, 1])]
        case .metalReflection:
            return [track(.reflectionTravel, [-0.5, 0.5], [0, 1]),
                    track(.reflectionOpacity, [0, 1, 1, 0], [0, 0.15, 0.85, 1], [.easeInOut, .linear, .easeInOut])]
        }
    }
}

public extension Array where Element == AnimationEntry {
    /// Entries that run, with their normalized values. Disabled entries and an empty list both mean "no animation".
    var active: [AnimationEntry] { filter(\.enabled).map(\.normalized) }
    /// Seconds after a focus change until every focus-triggered entry has finished, sequences included.
    var focusSpan: Double { AnimationSchedule.focusEnd(self) }
}
