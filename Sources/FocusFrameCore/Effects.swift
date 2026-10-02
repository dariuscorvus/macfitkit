import Foundation
import CoreGraphics

func bounded(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
    value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
}
public struct EffectColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public init(_ red: Double = 1, _ green: Double = 0.58, _ blue: Double = 0.15) {
        self.red = red; self.green = green; self.blue = blue
    }
    public var normalized: Self { Self(bounded(red, 0...1, 1), bounded(green, 0...1, 0.58), bounded(blue, 0...1, 0.15)) }
}
public enum LightMode: String, Codable, CaseIterable, Sendable { case off, glow, neon }
public enum GradientMode: String, Codable, CaseIterable, Sendable { case off, linear, conic }
public enum OpacityMode: String, Codable, CaseIterable, Sendable { case off, pulse, blink }
public enum AnimationTrigger: String, Codable, CaseIterable, Sendable { case focus, continuous }
public struct LightEffect: Codable, Equatable, Sendable {
    public var mode = LightMode.off
    public var intensity = 0.5
    public var extent = 12.0
    public var followsFrame = true
    public var color = EffectColor()
    public var coreWidth = 0.35
    public var whitening = 0.75
    public init() {}
    public var normalized: Self {
        var s = self
        s.intensity = bounded(intensity, 0...1, 0.5); s.extent = bounded(extent, 0...200, 12)
        s.coreWidth = bounded(coreWidth, 0.1...1, 0.35); s.whitening = bounded(whitening, 0...1, 0.75)
        s.color = color.normalized; return s
    }
}
public struct ShadowEffect: Codable, Equatable, Sendable {
    public var enabled = false
    public var color = EffectColor(0, 0, 0)
    public var opacity = 0.35
    public var blur = 12.0
    public var spread = 0.0
    public var offsetX = 0.0
    public var offsetY = 4.0
    public init() {}
    public var normalized: Self {
        var s = self; s.color = color.normalized
        s.opacity = bounded(opacity, 0...1, 0.35); s.blur = bounded(blur, 0...200, 12)
        s.spread = bounded(spread, 0...200, 0)
        s.offsetX = bounded(offsetX, -200...200, 0); s.offsetY = bounded(offsetY, -200...200, 4)
        return s
    }
}
public struct GradientEffect: Codable, Equatable, Sendable {
    public var mode = GradientMode.off
    public var first = EffectColor()
    public var second = EffectColor(0, 1, 1)
    public var angle = 0.0
    public init() {}
    public var normalized: Self {
        var s = self; s.first = first.normalized; s.second = second.normalized
        s.angle = bounded(angle, 0...360, 0); return s
    }
}
public struct OpacityEffect: Codable, Equatable, Sendable {
    public var mode = OpacityMode.off
    public var pulsePeriod = 2.0
    public var blinkPeriod = 1.0
    public var pulseMinimum = 0.4
    public var blinkMinimum = 0.25
    public var maximum = 1.0
    public var trigger = AnimationTrigger.focus
    public var focusDuration = 1.5
    public init() {}
    public var normalized: Self {
        var s = self
        s.pulsePeriod = bounded(pulsePeriod, 0.5...10, 2); s.blinkPeriod = bounded(blinkPeriod, 0.5...5, 1)
        s.maximum = bounded(maximum, 0...1, 1)
        s.pulseMinimum = min(s.maximum, bounded(pulseMinimum, 0...1, 0.4))
        s.blinkMinimum = min(s.maximum, bounded(blinkMinimum, 0...1, 0.25))
        s.focusDuration = bounded(focusDuration, 0.5...5, 1.5); return s
    }
}
public struct RotationEffect: Codable, Equatable, Sendable {
    public var enabled = false
    public var period = 8.0
    public var clockwise = true
    public var trigger = AnimationTrigger.focus
    public var focusDuration = 1.5
    public init() {}
    public var normalized: Self {
        var s = self; s.period = bounded(period, 2...30, 8)
        s.focusDuration = bounded(focusDuration, 0.5...5, 1.5); return s
    }
}
public enum EffectGeometry {
    public static func overlayRect(for window: CGRect, appearance: Appearance) -> CGRect {
        let a = appearance.normalized
        let base = a.width + a.gap
        let glow = a.light.mode == .off ? 0 : 3 * a.light.extent
        let shadow = a.shadow.enabled ? a.shadow.spread + 3 * a.shadow.blur : 0
        let x = a.shadow.enabled ? a.shadow.offsetX : 0
        let y = a.shadow.enabled ? -a.shadow.offsetY : 0 // Positive UI Y means down.
        let left = base + max(glow, shadow + max(0, -x))
        let right = base + max(glow, shadow + max(0, x))
        let bottom = base + max(glow, shadow + max(0, -y))
        let top = base + max(glow, shadow + max(0, y))
        return CGRect(x: window.minX - left, y: window.minY - bottom,
                      width: window.width + left + right, height: window.height + bottom + top)
    }
}
public enum EffectAnimationPolicy {
    public static func shouldAnimate(visible: Bool, reducedMotion: Bool, trigger: AnimationTrigger, focusChanged: Bool) -> Bool {
        visible && !reducedMotion && (trigger == .continuous || focusChanged)
    }
}
