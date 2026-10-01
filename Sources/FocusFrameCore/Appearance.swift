import Foundation

public struct Appearance: Codable, Equatable, Sendable {
    public var red: Double = 1
    public var green: Double = 0.58
    public var blue: Double = 0.15
    public var opacity: Double = 1
    public var width: Double = 3
    public var radius: Double = 10
    public var gap: Double = 0

    public init() {}

    public var normalized: Self {
        var result = self
        func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        result.red = clamp(red, 0...1, fallback: 1)
        result.green = clamp(green, 0...1, fallback: 0.58)
        result.blue = clamp(blue, 0...1, fallback: 0.15)
        result.opacity = clamp(opacity, 0.1...1, fallback: 1)
        result.width = clamp(width, 1...12, fallback: 3)
        result.radius = clamp(radius, 0...40, fallback: 10)
        result.gap = clamp(gap, 0...20, fallback: 0)
        return result
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var appearance = Appearance()
    public var excludedApps: [String] = []
    public var hideInFullScreen = false
    public var shortcutEnabled = false
    public init() {}

    public var normalized: Self {
        var result = self
        result.appearance = appearance.normalized
        result.excludedApps = Array(Set(excludedApps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })).sorted()
        return result
    }
}
