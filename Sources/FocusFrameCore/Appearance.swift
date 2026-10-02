import Foundation

public struct Appearance: Codable, Equatable, Sendable {
    public var red: Double = 1
    public var green: Double = 0.58
    public var blue: Double = 0.15
    public var opacity: Double = 1
    public var width: Double = 3
    public var radius: Double = 18.5
    public var gap: Double = 0
    public var placement = BorderPlacement.outside
    public var material = MaterialEffect()

    public var light = LightEffect()
    public var shadow = ShadowEffect()
    public var gradient = GradientEffect()
    public var opacityAnimation = OpacityEffect()
    public var rotation = RotationEffect()

    public init() {}
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity, width, radius, gap, placement, material, light, shadow, gradient, opacityAnimation, rotation
    }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        red = try c.decodeIfPresent(Double.self, forKey: .red) ?? red
        green = try c.decodeIfPresent(Double.self, forKey: .green) ?? green
        blue = try c.decodeIfPresent(Double.self, forKey: .blue) ?? blue
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? opacity
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? width
        radius = try c.decodeIfPresent(Double.self, forKey: .radius) ?? radius
        gap = try c.decodeIfPresent(Double.self, forKey: .gap) ?? gap
        placement = try c.decodeIfPresent(BorderPlacement.self, forKey: .placement) ?? placement
        material = try c.decodeIfPresent(MaterialEffect.self, forKey: .material) ?? material
        light = try c.decodeIfPresent(LightEffect.self, forKey: .light) ?? light
        shadow = try c.decodeIfPresent(ShadowEffect.self, forKey: .shadow) ?? shadow
        gradient = try c.decodeIfPresent(GradientEffect.self, forKey: .gradient) ?? gradient
        opacityAnimation = try c.decodeIfPresent(OpacityEffect.self, forKey: .opacityAnimation) ?? opacityAnimation
        rotation = try c.decodeIfPresent(RotationEffect.self, forKey: .rotation) ?? rotation
    }

    public var normalized: Self {
        var result = self
        func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
            value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
        }
        result.red = clamp(red, 0...1, fallback: 1)
        result.green = clamp(green, 0...1, fallback: 0.58)
        result.blue = clamp(blue, 0...1, fallback: 0.15)
        result.opacity = clamp(opacity, 0.1...1, fallback: 1)
        result.width = clamp(width, 1...100, fallback: 3)
        result.radius = clamp(radius, 0...300, fallback: 18.5)
        result.gap = clamp(gap, 0...200, fallback: 0)
        result.material = material.normalized
        result.light = light.normalized; result.shadow = shadow.normalized
        result.gradient = gradient.normalized; result.opacityAnimation = opacityAnimation.normalized
        result.rotation = rotation.normalized
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
