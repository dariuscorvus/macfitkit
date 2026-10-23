import Foundation

/// One color point of the frame gradient. `location` runs from 0 to 1.
public struct GradientStop: Codable, Equatable, Sendable {
    public var color: EffectColor
    public var location: Double
    public init(_ color: EffectColor, at location: Double) { self.color = color; self.location = location }
}

public struct GradientEffect: Codable, Equatable, Sendable {
    public static let minimumStops = 2
    public var mode = GradientMode.off
    public var stops = [GradientStop(EffectColor(), at: 0), GradientStop(EffectColor(0, 1, 1), at: 1)]
    public var angle = 0.0
    public init() {}

    private enum CodingKeys: String, CodingKey { case mode, stops, angle, first, second }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decodeIfPresent(GradientMode.self, forKey: .mode) ?? mode
        angle = try c.decodeIfPresent(Double.self, forKey: .angle) ?? angle
        if let stops = try c.decodeIfPresent([GradientStop].self, forKey: .stops) { self.stops = stops; return }
        // Older settings stored two colors. Conic drew them mirrored, first → second → first; three stops keep that look.
        let first = try c.decodeIfPresent(EffectColor.self, forKey: .first) ?? stops[0].color
        let second = try c.decodeIfPresent(EffectColor.self, forKey: .second) ?? stops[1].color
        stops = mode == .conic ? [GradientStop(first, at: 0), GradientStop(second, at: 0.5), GradientStop(first, at: 1)]
                               : [GradientStop(first, at: 0), GradientStop(second, at: 1)]
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(mode, forKey: .mode); try c.encode(stops, forKey: .stops); try c.encode(angle, forKey: .angle)
    }

    /// Stops sorted by location. Stops at the same location keep their order, which draws a hard edge.
    public var normalized: Self {
        var s = self; s.angle = bounded(angle, 0...360, 0)
        let clean = stops.map { GradientStop($0.color.normalized, at: bounded($0.location, 0...1, 0)) }
        s.stops = clean.enumerated().sorted { ($0.element.location, $0.offset) < ($1.element.location, $1.offset) }.map(\.element)
        if s.stops.isEmpty { s.stops = GradientEffect().stops }
        if s.stops.count == 1 { let only = s.stops[0]; s.stops = only.location < 1 ? [only, GradientStop(only.color, at: 1)] : [GradientStop(only.color, at: 0), only] }
        return s
    }

    /// The color at `location`, interpolated in sRGB between the neighbouring stops. A stop added there starts with this color.
    public func color(at location: Double) -> EffectColor {
        let s = normalized.stops, x = bounded(location, 0...1, 0)
        guard let next = s.firstIndex(where: { $0.location >= x }) else { return s[s.count - 1].color }
        guard next > 0 else { return s[0].color }
        let a = s[next - 1], b = s[next], span = b.location - a.location, t = span > 0 ? (x - a.location) / span : 1
        func mix(_ u: Double, _ v: Double) -> Double { u + (v - u) * t }
        return EffectColor(mix(a.color.red, b.color.red), mix(a.color.green, b.color.green), mix(a.color.blue, b.color.blue))
    }

    /// A conic gradient wraps around at its start angle. The wrap is seamless when the last stop sits at 100 % in the first stop's color.
    public var isSeamClosed: Bool {
        guard let first = stops.first, let last = stops.last, stops.count >= 2 else { return false }
        return last.location == 1 && last.color == first.color
    }

    /// "Naht schließen": the stop at 100 % takes the first color, or a new one is added there.
    public mutating func closeSeam() {
        self = normalized
        guard !isSeamClosed, let first = stops.first else { return }
        if stops[stops.count - 1].location == 1 { stops[stops.count - 1].color = first.color } else { stops.append(GradientStop(first.color, at: 1)) }
    }

    /// Which stop's color each stop flows toward in "Farbfluss". Linear gradients run reversed. Conic ones shift the ring by one stop,
    /// which turns the migrated mirror `a b a` into `b a b` as before variable stops.
    public func flowOrder() -> [Int] {
        let count = stops.count
        guard mode == .conic else { return Array((0..<count).reversed()) }
        let ring = isSeamClosed ? count - 1 : count
        guard ring > 0 else { return Array(0..<count) }
        var order = (0..<ring).map { ($0 + 1) % ring }
        if isSeamClosed { order.append(order[0]) }
        return order
    }
}
