import Foundation

public enum EasingDirection: String, Codable, CaseIterable, Hashable, Sendable { case `in`, out, inOut }

/// Curves defined by one "in" function; "out" and "in out" mirror it.
public enum EasingFamily: String, Codable, CaseIterable, Sendable {
    case sine, quad, cubic, quart, quint, expo, circ, back, elastic, bounce

    func easeIn(_ t: Double) -> Double {
        switch self {
        case .sine: 1 - cos(t * .pi / 2)
        case .quad: t * t
        case .cubic: t * t * t
        case .quart: t * t * t * t
        case .quint: t * t * t * t * t
        case .expo: t == 0 ? 0 : pow(2, 10 * t - 10)
        case .circ: 1 - (1 - t * t).squareRoot()
        case .back: 2.70158 * t * t * t - 1.70158 * t * t
        case .elastic: t == 0 || t == 1 ? t : -pow(2, 10 * t - 10) * sin((t * 10 - 10.75) * 2 * .pi / 3)
        case .bounce: 1 - Self.bounceOut(1 - t)
        }
    }

    static func bounceOut(_ t: Double) -> Double {
        let n = 7.5625, d = 2.75
        if t < 1 / d { return n * t * t }
        if t < 2 / d { let u = t - 1.5 / d; return n * u * u + 0.75 }
        if t < 2.5 / d { let u = t - 2.25 / d; return n * u * u + 0.9375 }
        let u = t - 2.625 / d; return n * u * u + 0.984375
    }

    /// Back and elastic leave the 0…1 range on the way. Bounce stays inside but turns back.
    public var overshoots: Bool { self == .back || self == .elastic }
    public var isMonotonic: Bool { !overshoots && self != .bounce }
}

/// A timing curve: progress over normalized time, both 0 at the start and 1 at the end. Overshooting curves leave 0…1 in between.
public enum TimingCurve: Hashable, Sendable {
    case linear
    case family(EasingFamily, EasingDirection)
    /// A damped spring. `damping` is the damping ratio, `response` the oscillation period as a fraction of the duration.
    case spring(damping: Double, response: Double)
    /// CSS-style cubic Bézier through (0,0) and (1,1). x of both control points stays within 0…1; y may overshoot.
    case bezier(x1: Double, y1: Double, x2: Double, y2: Double)

    /// The system presets of `CAMediaTimingFunction`.
    public static let easeIn = bezier(x1: 0.42, y1: 0, x2: 1, y2: 1)
    public static let easeOut = bezier(x1: 0, y1: 0, x2: 0.58, y2: 1)
    public static let easeInOut = bezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)
    public static let defaultSpring = spring(damping: 0.5, response: 0.3)

    public func value(at time: Double) -> Double {
        let t = min(max(time.isFinite ? time : 0, 0), 1)
        switch normalized {
        case .linear: return t
        case .family(let family, let direction):
            switch direction {
            case .in: return family.easeIn(t)
            case .out: return 1 - family.easeIn(1 - t)
            case .inOut: return t < 0.5 ? family.easeIn(2 * t) / 2 : 1 - family.easeIn(2 - 2 * t) / 2
            }
        case .spring(let damping, let response):
            // Pinned to 1 at the end, so an animation always lands on its target even if the spring has not settled.
            let raw = Self.springStep(t, damping: damping, response: response), end = Self.springStep(1, damping: damping, response: response)
            return raw + (1 - end) * t * t * t
        case .bezier(let x1, let y1, let x2, let y2):
            if t == 0 || t == 1 { return t }
            let s = Self.solveBezier(x: t, x1, x2)
            return Self.bezierPoint(s, y1, y2)
        }
    }

    /// Unit step response of a damped harmonic oscillator.
    static func springStep(_ t: Double, damping zeta: Double, response: Double) -> Double {
        let omega = 2 * .pi / response
        if zeta < 1 {
            let wd = omega * (1 - zeta * zeta).squareRoot()
            return 1 - exp(-zeta * omega * t) * (cos(wd * t) + zeta * omega / wd * sin(wd * t))
        }
        return 1 - exp(-omega * t) * (1 + omega * t)
    }

    static func bezierPoint(_ s: Double, _ p1: Double, _ p2: Double) -> Double {
        let u = 1 - s; return 3 * u * u * s * p1 + 3 * u * s * s * p2 + s * s * s
    }

    /// The curve parameter whose x is `x`: Newton steps, then bisection if Newton leaves 0…1 or stalls.
    static func solveBezier(x: Double, _ x1: Double, _ x2: Double) -> Double {
        var s = x
        for _ in 0..<8 {
            let error = bezierPoint(s, x1, x2) - x
            if abs(error) < 1e-9 { return s }
            let u = 1 - s, slope = 3 * u * u * x1 + 6 * u * s * (x2 - x1) + 3 * s * s * (1 - x2)
            guard abs(slope) > 1e-6 else { break }
            s -= error / slope
            guard (0...1).contains(s) else { break }
        }
        var low = 0.0, high = 1.0; s = x
        for _ in 0..<60 {
            if bezierPoint(s, x1, x2) < x { low = s } else { high = s }
            s = (low + high) / 2
        }
        return s
    }

    /// Whether values leave 0…1 between the endpoints; the editor's diagram then shows the overshoot.
    public var overshoots: Bool {
        switch self {
        case .linear: false
        case .family(let family, _): family.overshoots
        case .spring(let damping, _): damping < 1
        case .bezier(_, let y1, _, let y2): !(0...1).contains(y1) || !(0...1).contains(y2)
        }
    }
    public var isMonotonic: Bool {
        switch self {
        case .family(let family, _): family.isMonotonic
        default: !overshoots
        }
    }

    /// Spring values and Bézier x within their usable ranges; non-finite values fall back to the defaults.
    public var normalized: Self {
        switch self {
        case .spring(let damping, let response):
            return .spring(damping: bounded(damping, 0.05...1, 0.5), response: bounded(response, 0.05...1, 0.3))
        case .bezier(let x1, let y1, let x2, let y2):
            return .bezier(x1: bounded(x1, 0...1, 0.42), y1: bounded(y1, -2...3, 0), x2: bounded(x2, 0...1, 0.58), y2: bounded(y2, -2...3, 1))
        default: return self
        }
    }

    /// The named curves in browsing order. A spring appears with its default parameters; custom Béziers are not listed.
    public static let catalog: [TimingCurve] = [.linear, .easeIn, .easeOut, .easeInOut]
        + EasingFamily.allCases.flatMap { family in EasingDirection.allCases.map { .family(family, $0) } }
        + [.defaultSpring]

    /// Lowest and highest value over the curve, sampled; the editor sizes its diagram from this.
    public func range(samples: Int = 200) -> ClosedRange<Double> {
        let values = (0...samples).map { value(at: Double($0) / Double(samples)) }
        return (values.min() ?? 0)...(values.max() ?? 1)
    }
}

extension TimingCurve: Codable {
    private enum Kind: String, Codable { case linear, family, spring, bezier }
    private enum CodingKeys: String, CodingKey { case version, kind, family, direction, damping, response, x1, y1, x2, y2 }
    public static let codingVersion = 1

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .linear: self = .linear
        case .family: self = .family(try c.decode(EasingFamily.self, forKey: .family), try c.decode(EasingDirection.self, forKey: .direction))
        case .spring: self = .spring(damping: try c.decode(Double.self, forKey: .damping), response: try c.decode(Double.self, forKey: .response))
        case .bezier:
            self = .bezier(x1: try c.decode(Double.self, forKey: .x1), y1: try c.decode(Double.self, forKey: .y1),
                           x2: try c.decode(Double.self, forKey: .x2), y2: try c.decode(Double.self, forKey: .y2))
        }
        self = normalized
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.codingVersion, forKey: .version)
        switch self {
        case .linear: try c.encode(Kind.linear, forKey: .kind)
        case .family(let family, let direction):
            try c.encode(Kind.family, forKey: .kind); try c.encode(family, forKey: .family); try c.encode(direction, forKey: .direction)
        case .spring(let damping, let response):
            try c.encode(Kind.spring, forKey: .kind); try c.encode(damping, forKey: .damping); try c.encode(response, forKey: .response)
        case .bezier(let x1, let y1, let x2, let y2):
            try c.encode(Kind.bezier, forKey: .kind)
            try c.encode(x1, forKey: .x1); try c.encode(y1, forKey: .y1); try c.encode(x2, forKey: .x2); try c.encode(y2, forKey: .y2)
        }
    }
}
