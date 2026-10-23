import Foundation

/// What an animation entry does. Each kind drives one property group; the blending rule follows from it.
public enum AnimationKind: String, Codable, CaseIterable, Sendable {
    case focusPulse, runner, draw, breathe, colorFlow, gradientRotation, opacityPulse, opacityBlink, metalReflection

    /// Kinds that scale a layer's opacity. Their multipliers multiply when several entries hit the same layer.
    public var multipliesOpacity: Bool { self == .breathe || self == .opacityPulse || self == .opacityBlink }
    /// Kinds with a selectable target layer.
    public var hasTarget: Bool { multipliesOpacity }
    /// Kinds with a strength (0…1) setting.
    public var hasStrength: Bool { self != .gradientRotation && self != .opacityPulse && self != .opacityBlink && self != .metalReflection }
}

/// One independently timed animation. Several entries run together; see `AnimationKind` for how they combine.
public struct AnimationEntry: Codable, Equatable, Identifiable, Sendable {
    public static let softLimit = 8
    public var id = UUID()
    public var enabled = true
    public var kind: AnimationKind
    public var trigger: AnimationTrigger
    /// One cycle, in seconds.
    public var duration: Double
    /// Seconds after the trigger before the first cycle starts.
    public var delay = 0.0
    /// Cycles after a focus change; fractions end mid-cycle. Continuous entries repeat forever.
    public var repeats = 1.0
    public var target = AnimationTarget.frame
    public var strength = 0.65
    public var curve = TimingCurve.easeInOut
    /// Opacity kinds: lowest and highest multiplier.
    public var minimum = 0.4, maximum = 1.0
    /// Gradient rotation direction.
    public var clockwise = true
    /// Focus pulse: settle in two smaller swings instead of one fade (the former "Federnd").
    public var bounce = false

    public init(_ kind: AnimationKind, trigger: AnimationTrigger = .focus, duration: Double? = nil) {
        self.kind = kind; self.trigger = trigger
        self.duration = duration ?? Self.defaultDuration(kind)
        switch kind {
        case .opacityBlink: minimum = 0.25; curve = .linear
        case .runner, .gradientRotation, .metalReflection: curve = .linear
        default: break
        }
        if kind == .breathe || kind == .opacityPulse || kind == .opacityBlink { target = kind == .breathe ? .shadow : .all }
    }

    static func defaultDuration(_ kind: AnimationKind) -> Double {
        switch kind { case .focusPulse: 0.8; case .runner: 1.8; case .breathe: 4; case .colorFlow: 8; case .gradientRotation: 8
        case .opacityPulse: 2; case .opacityBlink: 1; case .metalReflection: 1.5; case .draw: 1.5 }
    }

    /// Seconds from the trigger until a focus entry has finished.
    public var focusSpan: Double { delay + duration * repeats }

    public var normalized: Self {
        var s = self
        s.duration = bounded(duration, 0.2...30, Self.defaultDuration(kind)); s.delay = bounded(delay, 0...10, 0)
        s.repeats = bounded(repeats, 0.05...10, 1); s.strength = bounded(strength, 0...1, 0.65)
        s.maximum = bounded(maximum, 0...1, 1); s.minimum = min(s.maximum, bounded(minimum, 0...1, 0.4))
        s.curve = curve.normalized
        return s
    }

    private enum CodingKeys: String, CodingKey { case id, enabled, kind, trigger, duration, delay, repeats, target, strength, curve, minimum, maximum, clockwise, bounce }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(try c.decode(AnimationKind.self, forKey: .kind), trigger: try c.decodeIfPresent(AnimationTrigger.self, forKey: .trigger) ?? .focus)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? id
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? duration
        delay = try c.decodeIfPresent(Double.self, forKey: .delay) ?? delay
        repeats = try c.decodeIfPresent(Double.self, forKey: .repeats) ?? repeats
        target = try c.decodeIfPresent(AnimationTarget.self, forKey: .target) ?? target
        strength = try c.decodeIfPresent(Double.self, forKey: .strength) ?? strength
        curve = try c.decodeIfPresent(TimingCurve.self, forKey: .curve) ?? curve
        minimum = try c.decodeIfPresent(Double.self, forKey: .minimum) ?? minimum
        maximum = try c.decodeIfPresent(Double.self, forKey: .maximum) ?? maximum
        clockwise = try c.decodeIfPresent(Bool.self, forKey: .clockwise) ?? clockwise
        bounce = try c.decodeIfPresent(Bool.self, forKey: .bounce) ?? bounce
    }
}

/// The animation settings before entries: one motion, one opacity animation, one rotation and the metal reflection,
/// optionally sharing the motion's duration and trigger. Read once to migrate, never written.
struct LegacyAnimations: Decodable {
    enum Mode: String, Decodable { case off, impulse, runner, draw, breathe, flow }
    enum Curve: String, Decodable { case smooth, linear, spring }
    enum OpacityMode: String, Decodable { case off, pulse, blink }

    struct Motion: Decodable {
        var mode = Mode.off, trigger = AnimationTrigger.focus, target = AnimationTarget.frame
        var duration = 1.5, cycles = 1.0, strength = 0.65, curve = Curve.smooth, synchronize = false
        private enum CodingKeys: String, CodingKey { case mode, trigger, target, duration, cycles, strength, curve, synchronize }
        init() {}
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = try c.decodeIfPresent(Mode.self, forKey: .mode) ?? mode; trigger = try c.decodeIfPresent(AnimationTrigger.self, forKey: .trigger) ?? trigger
            target = try c.decodeIfPresent(AnimationTarget.self, forKey: .target) ?? target; duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? duration
            cycles = try c.decodeIfPresent(Double.self, forKey: .cycles) ?? cycles; strength = try c.decodeIfPresent(Double.self, forKey: .strength) ?? strength
            curve = try c.decodeIfPresent(Curve.self, forKey: .curve) ?? curve; synchronize = try c.decodeIfPresent(Bool.self, forKey: .synchronize) ?? synchronize
        }
    }
    struct Opacity: Decodable {
        var mode = OpacityMode.off, target = AnimationTarget.all, pulsePeriod = 2.0, blinkPeriod = 1.0
        var pulseMinimum = 0.4, blinkMinimum = 0.25, maximum = 1.0, trigger = AnimationTrigger.focus, focusDuration = 1.5
        private enum CodingKeys: String, CodingKey { case mode, target, pulsePeriod, blinkPeriod, pulseMinimum, blinkMinimum, maximum, trigger, focusDuration }
        init() {}
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mode = try c.decodeIfPresent(OpacityMode.self, forKey: .mode) ?? mode; target = try c.decodeIfPresent(AnimationTarget.self, forKey: .target) ?? target
            pulsePeriod = try c.decodeIfPresent(Double.self, forKey: .pulsePeriod) ?? pulsePeriod; blinkPeriod = try c.decodeIfPresent(Double.self, forKey: .blinkPeriod) ?? blinkPeriod
            pulseMinimum = try c.decodeIfPresent(Double.self, forKey: .pulseMinimum) ?? pulseMinimum; blinkMinimum = try c.decodeIfPresent(Double.self, forKey: .blinkMinimum) ?? blinkMinimum
            maximum = try c.decodeIfPresent(Double.self, forKey: .maximum) ?? maximum; trigger = try c.decodeIfPresent(AnimationTrigger.self, forKey: .trigger) ?? trigger
            focusDuration = try c.decodeIfPresent(Double.self, forKey: .focusDuration) ?? focusDuration
        }
    }
    struct Rotation: Decodable {
        var enabled = false, period = 8.0, clockwise = true, trigger = AnimationTrigger.focus, focusDuration = 1.5
        private enum CodingKeys: String, CodingKey { case enabled, period, clockwise, trigger, focusDuration }
        init() {}
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? enabled; period = try c.decodeIfPresent(Double.self, forKey: .period) ?? period
            clockwise = try c.decodeIfPresent(Bool.self, forKey: .clockwise) ?? clockwise; trigger = try c.decodeIfPresent(AnimationTrigger.self, forKey: .trigger) ?? trigger
            focusDuration = try c.decodeIfPresent(Double.self, forKey: .focusDuration) ?? focusDuration
        }
    }
    struct Reflection: Decodable {
        var reflectionEnabled = false, period = 6.0, trigger = AnimationTrigger.focus, focusDuration = 1.5
        private enum CodingKeys: String, CodingKey { case reflectionEnabled, period, trigger, focusDuration }
        init() {}
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            reflectionEnabled = try c.decodeIfPresent(Bool.self, forKey: .reflectionEnabled) ?? reflectionEnabled
            period = try c.decodeIfPresent(Double.self, forKey: .period) ?? period
            trigger = try c.decodeIfPresent(AnimationTrigger.self, forKey: .trigger) ?? trigger
            focusDuration = try c.decodeIfPresent(Double.self, forKey: .focusDuration) ?? focusDuration
        }
    }

    var motion = Motion(), opacity = Opacity(), rotation = Rotation(), reflection = Reflection()

    /// The same animations as entries, in the order the old renderer applied them.
    var entries: [AnimationEntry] {
        let m = motion, sync = motion.synchronize, mode = motion.mode
        var entries: [AnimationEntry] = []
        let o = opacity
        if o.mode != .off {
            var e = AnimationEntry(o.mode == .pulse ? .opacityPulse : .opacityBlink, trigger: sync ? m.trigger : o.trigger)
            let period = sync ? m.duration : (o.mode == .pulse ? o.pulsePeriod : o.blinkPeriod)
            e.duration = period; e.repeats = (sync ? m.duration * m.cycles : o.focusDuration) / period
            e.target = o.target; e.maximum = o.maximum; e.minimum = o.mode == .pulse ? o.pulseMinimum : o.blinkMinimum
            entries.append(e)
        }
        let r = rotation
        if r.enabled {
            var e = AnimationEntry(.gradientRotation, trigger: sync ? m.trigger : r.trigger)
            e.duration = sync ? m.duration : r.period; e.repeats = (sync ? m.duration * m.cycles : r.focusDuration) / e.duration
            e.clockwise = r.clockwise; entries.append(e)
        }
        if reflection.reflectionEnabled {
            var e = AnimationEntry(.metalReflection, trigger: sync ? m.trigger : reflection.trigger)
            e.duration = e.trigger == .focus ? (sync ? m.duration : reflection.focusDuration) : (sync ? m.duration : reflection.period)
            e.repeats = sync ? m.cycles : 1; entries.append(e)
        }
        let kinds: [Mode: AnimationKind] = [.impulse: .focusPulse, .runner: .runner, .draw: .draw, .breathe: .breathe, .flow: .colorFlow]
        if let kind = kinds[mode] {
            var e = AnimationEntry(kind, trigger: m.trigger, duration: m.duration)
            e.repeats = m.cycles; e.strength = m.strength; e.target = m.target
            // "Sanft" and "Federnd" both used ease-in-out timing; "Federnd" only changed the impulse's fade shape.
            e.curve = m.curve == .linear ? .linear : .easeInOut
            e.bounce = kind == .focusPulse && m.curve == .spring
            entries.append(e)
        }
        return entries
    }
}

public enum MotionPreset: String, CaseIterable, Sendable {
    case subtle, runner, breathingShadow, colorFlow
    public func applying(to appearance: Appearance) -> Appearance {
        var a = appearance
        switch self {
        case .subtle: var e = AnimationEntry(.focusPulse, duration: 0.8); e.strength = 0.35; a.animations = [e]
        case .runner: a.animations = [AnimationEntry(.runner, duration: 1.8)]
        case .breathingShadow:
            a.shadow.enabled = true; a.shadow.colorSource = .gradient
            a.animations = [AnimationEntry(.breathe, trigger: .continuous, duration: 4)]
        case .colorFlow:
            a.material.mode = .standard
            if a.gradient.mode == .off {
                let frame = EffectColor(a.red,a.green,a.blue), second = GradientEffect().stops[1].color
                a.gradient.mode = .conic; a.gradient.stops = [GradientStop(frame, at: 0), GradientStop(second, at: 0.5), GradientStop(frame, at: 1)]
            }
            a.shadow.enabled = true; a.shadow.colorSource = .gradient
            a.animations = [AnimationEntry(.colorFlow, trigger: .continuous, duration: 8)]
        }
        return a.normalized
    }
}
