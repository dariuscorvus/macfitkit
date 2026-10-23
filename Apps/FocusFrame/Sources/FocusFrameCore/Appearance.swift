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
    /// Run together; see `AnimationKind` for how entries on the same property combine.
    public var animations: [AnimationEntry] = []

    public init() {}
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity, width, radius, gap, placement, material, light, shadow, gradient, animations
    }
    private enum LegacyKeys: String, CodingKey { case opacityAnimation, rotation, motion, material }
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
        if let animations = try c.decodeIfPresent([AnimationEntry].self, forKey: .animations) { self.animations = animations; return }
        // Settings from before animation entries: convert motion, opacity, rotation and reflection once.
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        var old = LegacyAnimations()
        old.motion = try legacy.decodeIfPresent(LegacyAnimations.Motion.self, forKey: .motion) ?? old.motion
        old.opacity = try legacy.decodeIfPresent(LegacyAnimations.Opacity.self, forKey: .opacityAnimation) ?? old.opacity
        old.rotation = try legacy.decodeIfPresent(LegacyAnimations.Rotation.self, forKey: .rotation) ?? old.rotation
        old.reflection = try legacy.decodeIfPresent(LegacyAnimations.Reflection.self, forKey: .material) ?? old.reflection
        animations = old.entries
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
        result.gradient = gradient.normalized; result.animations = animations.map(\.normalized)
        return result
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var appearance = Appearance()
    public var excludedApps: [String] = []
    public var hideInFullScreen = false
    public var shortcutEnabled = false
    public var shortcutKeyCode: UInt32 = 3
    public var shortcutModifiers: UInt32 = 6144
    public var savePower = true
    public init() {}

    private enum CodingKeys: String, CodingKey { case appearance, excludedApps, hideInFullScreen, shortcutEnabled, shortcutKeyCode, shortcutModifiers, savePower }
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try c.decodeIfPresent(Appearance.self, forKey: .appearance) ?? appearance
        excludedApps = try c.decodeIfPresent([String].self, forKey: .excludedApps) ?? []
        hideInFullScreen = try c.decodeIfPresent(Bool.self, forKey: .hideInFullScreen) ?? false
        shortcutEnabled = try c.decodeIfPresent(Bool.self, forKey: .shortcutEnabled) ?? false
        shortcutKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .shortcutKeyCode) ?? 3
        shortcutModifiers = try c.decodeIfPresent(UInt32.self, forKey: .shortcutModifiers) ?? 6144
        savePower = try c.decodeIfPresent(Bool.self, forKey: .savePower) ?? true
    }
    public func renderedAppearance(lowPower: Bool) -> Appearance {
        var result = appearance.normalized
        if savePower && lowPower {
            for i in result.animations.indices { result.animations[i].enabled = false }
        }
        return result
    }
    public var normalized: Self {
        var result = self
        if shortcutKeyCode > 126 { result.shortcutKeyCode = 3 }
        result.shortcutModifiers &= 6912
        if result.shortcutModifiers == 0 { result.shortcutModifiers = 6144 }
        result.appearance = appearance.normalized
        result.excludedApps = Array(Set(excludedApps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })).sorted()
        return result
    }
}

public struct AppearanceProfile: Codable, Equatable, Sendable {
    public var name: String
    public var appearance: Appearance
    public init(name: String, appearance: Appearance) { self.name = name; self.appearance = appearance }
}
public struct PortablePreferences: Codable, Sendable {
    public var version = 1
    public var configuration: Configuration
    public var profiles: [AppearanceProfile]
    public init(configuration: Configuration, profiles: [AppearanceProfile]) { self.configuration = configuration; self.profiles = profiles }
}
