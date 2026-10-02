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
/// Placement is relative to the actual window edge; gap points inward for inside.
public enum BorderPlacement: String, Codable, CaseIterable, Sendable { case outside, centered, inside }
public struct BorderContour: Equatable, Sendable {
    public let rect: CGRect
    public let radius: Double
    public let width: Double
    public var outerRect: CGRect { rect.insetBy(dx: -width / 2, dy: -width / 2) }
    public var innerRect: CGRect { rect.insetBy(dx: width / 2, dy: width / 2) }
    public let outerRadius: Double
    public let innerRadius: Double
}
public enum EffectGeometry {
    /// AppKit rounds borderless window origins to whole points. Keep its size
    /// translation-invariant and leave one point for the fractional remainder.
    public static func alignedOverlayRect(for window: CGRect, appearance: Appearance) -> CGRect {
        let rect = overlayRect(for: window, appearance: appearance)
        return CGRect(x: floor(rect.minX), y: floor(rect.minY),
                      width: ceil(rect.width)+1, height: ceil(rect.height)+1)
    }
    public static func contour(for window: CGRect, appearance: Appearance) -> BorderContour {
        let a = appearance.normalized
        let half = max(0, min(window.width, window.height) / 2)
        let gap = a.placement == .inside ? min(a.gap, max(0, half - 1)) : a.gap
        let width: Double
        let offset: Double
        switch a.placement {
        case .outside: width = a.width; offset = gap + width / 2
        case .centered: width = min(a.width, max(0.5, 2 * half - 1)); offset = gap
        case .inside:
            width = min(a.width, max(0.5, half - gap - 0.5)); offset = -gap - width / 2
        }
        let rect = window.insetBy(dx: -offset, dy: -offset)
        let windowRadius = min(a.radius, half)
        // A zero radius explicitly requests square corners.
        let radius = a.radius == 0 ? 0 : min(max(0, windowRadius + offset), min(rect.width, rect.height) / 2)
        let outer = rect.insetBy(dx: -width / 2, dy: -width / 2)
        let inner = rect.insetBy(dx: width / 2, dy: width / 2)
        let outerRadius = a.radius == 0 ? 0 : min(max(0, windowRadius + offset + width / 2), min(outer.width, outer.height) / 2)
        let innerRadius = a.radius == 0 ? 0 : min(max(0, windowRadius + offset - width / 2), min(inner.width, inner.height) / 2)
        return BorderContour(rect: rect, radius: radius, width: width, outerRadius: outerRadius, innerRadius: innerRadius)
    }
    public static func overlayRect(for window: CGRect, appearance: Appearance) -> CGRect {
        let a = appearance.normalized
        let border = contour(for: window, appearance: a).outerRect
        let base = window.minX - border.minX
        let glow = a.light.mode == .off ? 0 : 3 * a.light.extent
        let shadow = a.shadow.enabled ? a.shadow.spread + 3 * a.shadow.blur : 0
        let x = a.shadow.enabled ? a.shadow.offsetX : 0
        let y = a.shadow.enabled ? -a.shadow.offsetY : 0
        // Keep the conservative legacy padding; shifted shadows don't reduce it
        // on the opposite side, so changing placement won't introduce clipping.
        let left = max(0, base + max(glow, shadow + max(0,-x)))
        let right = max(0, base + max(glow, shadow + max(0,x)))
        let bottom = max(0, base + max(glow, shadow + max(0,-y)))
        let top = max(0, base + max(glow, shadow + max(0,y)))
        return CGRect(x: window.minX-left,y: window.minY-bottom,
                      width: window.width+left+right,height: window.height+bottom+top)
    }
}

public enum FrameMaterial: String, Codable, CaseIterable, Sendable { case standard, gold, chrome }
public struct MaterialStop: Equatable, Sendable {
    public let location: Double
    public let color: EffectColor
}
public struct MaterialEffect: Codable, Equatable, Sendable {
    public var mode = FrameMaterial.standard
    public var gloss = 0.65
    public var angle = 45.0
    public var reflectionEnabled = false
    public var reflectionStrength = 0.6
    public var reflectionWidth = 0.18
    public var period = 6.0
    public var trigger = AnimationTrigger.focus
    public var focusDuration = 1.5
    public init() {}
    public var normalized: Self {
        var s = self
        s.gloss = bounded(gloss, 0...1, 0.65); s.angle = bounded(angle, 0...360, 45)
        s.reflectionStrength = bounded(reflectionStrength, 0...1, 0.6)
        s.reflectionWidth = bounded(reflectionWidth, 0.05...0.6, 0.18)
        s.period = bounded(period, 2...30, 6); s.focusDuration = bounded(focusDuration, 0.5...5, 1.5)
        return s
    }
    public var baseColor: EffectColor {
        mode == .gold ? EffectColor(0.78, 0.57, 0.18) : EffectColor(0.65, 0.68, 0.72)
    }
    public var stops: [MaterialStop] {
        let palette: [EffectColor] = mode == .gold ? [
            EffectColor(0.26,0.12,0.025), EffectColor(0.85,0.57,0.13), EffectColor(1,0.89,0.48),
            EffectColor(1,0.98,0.85), EffectColor(0.52,0.29,0.045), EffectColor(0.95,0.73,0.26), EffectColor(0.3,0.16,0.03)
        ] : [
            EffectColor(0.12,0.15,0.2), EffectColor(0.75,0.8,0.86), EffectColor(0.96,0.98,1),
            EffectColor(1,1,1), EffectColor(0.18,0.22,0.28), EffectColor(0.86,0.9,0.96), EffectColor(0.22,0.26,0.32)
        ]
        let amount = normalized.gloss
        let base = baseColor
        return zip([0.0,0.20,0.38,0.46,0.53,0.72,1.0], palette).map { location, color in
            MaterialStop(location: location, color: EffectColor(
                base.red + (color.red-base.red)*amount,
                base.green + (color.green-base.green)*amount,
                base.blue + (color.blue-base.blue)*amount))
        }
    }
}
public enum EffectAnimationPolicy {
    public static func shouldAnimate(visible: Bool, reducedMotion: Bool, trigger: AnimationTrigger, focusChanged: Bool) -> Bool {
        visible && !reducedMotion && (trigger == .continuous || focusChanged)
    }
}
