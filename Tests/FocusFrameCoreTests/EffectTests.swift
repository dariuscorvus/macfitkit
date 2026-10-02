import Testing
import Foundation
import CoreGraphics
@testable import FocusFrameCore

struct EffectTests {
    @Test func legacyConfigurationRetainsAllValuesAndEffectsAreOff() throws {
        let json = #"{"appearance":{"red":0.2,"green":0.3,"blue":0.4,"opacity":0.8,"width":7,"radius":13,"gap":4},"excludedApps":["com.apple.finder"],"hideInFullScreen":true,"shortcutEnabled":true}"#
        let c = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        #expect(c.appearance.red == 0.2 && c.appearance.width == 7 && c.appearance.gap == 4)
        #expect(c.appearance.placement == .outside && c.appearance.material.mode == .standard && !c.appearance.material.reflectionEnabled)
        #expect(c.excludedApps == ["com.apple.finder"] && c.hideInFullScreen && c.shortcutEnabled)
        #expect(c.appearance.light.mode == .off && !c.appearance.shadow.enabled)
        #expect(c.appearance.gradient.mode == .off && c.appearance.opacityAnimation.mode == .off && !c.appearance.rotation.enabled)
    }
    @Test func combinedEffectsSurvivePersistence() throws {
        var c = Configuration()
        c.appearance.placement = .inside; c.appearance.material.mode = .gold
        c.appearance.material.gloss = 0.8; c.appearance.material.reflectionEnabled = true
        c.appearance.material.trigger = .continuous; c.appearance.material.reflectionWidth = 0.3
        c.appearance.light.mode = .neon; c.appearance.light.followsFrame = false
        c.appearance.light.color = EffectColor(0.4,0.1,0.9)
        c.appearance.shadow.enabled = true; c.appearance.shadow.offsetX = -23
        c.appearance.gradient.mode = .conic; c.appearance.gradient.angle = 127
        c.appearance.opacityAnimation.mode = .blink; c.appearance.opacityAnimation.trigger = .continuous
        c.appearance.rotation.enabled = true; c.appearance.rotation.clockwise = false
        #expect(try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(c)) == c)
    }
    @Test func unsafeEffectParametersAreBoundedAndOpacityOrdered() {
        var a = Appearance()
        a.light.extent = .infinity; a.light.coreWidth = 0; a.shadow.offsetX = -1000
        a.shadow.blur = .nan; a.gradient.angle = 500; a.opacityAnimation.maximum = 0.1
        a.opacityAnimation.pulseMinimum = 0.9; a.opacityAnimation.blinkMinimum = 0.8
        a.rotation.period = -2
        let n = a.normalized
        #expect(n.light.extent == 12 && n.light.coreWidth == 0.1)
        #expect(n.shadow.offsetX == -200 && n.shadow.blur == 12 && n.gradient.angle == 360)
        #expect(n.opacityAnimation.pulseMinimum == 0.1 && n.opacityAnimation.blinkMinimum == 0.1)
        #expect(n.rotation.period == 2)
    }
    @Test func expandedGeometryValuesSurviveNormalizationAndPersistence() throws {
        var c = Configuration()
        c.appearance.width = 100; c.appearance.gap = 200; c.appearance.radius = 300
        c.appearance.light.extent = 200; c.appearance.shadow.blur = 200
        c.appearance.shadow.spread = 200; c.appearance.shadow.offsetX = -200; c.appearance.shadow.offsetY = 200
        #expect(c.normalized == c)
        #expect(try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(c)).normalized == c)
        c.appearance.width = 1000; c.appearance.gap = 1000; c.appearance.radius = 1000
        #expect(c.normalized.appearance.width == 100 && c.normalized.appearance.gap == 200 && c.normalized.appearance.radius == 300)
    }
    @Test func disabledEffectsKeepOriginalGeometry() {
        let rect = CGRect(x: -900,y: 1200,width: 800,height: 600)
        let a = Appearance()
        #expect(EffectGeometry.overlayRect(for: rect, appearance: a) == WindowGeometry.overlayRect(for: rect,width: a.width,gap: a.gap))
    }
    @Test func extremeEffectsAndOffsetHaveSpaceOnEverySideWithoutMovingTarget() {
        let rect = CGRect(x: -1200,y: -600,width: 700,height: 500)
        var a = Appearance(); a.width = 12; a.gap = 20; a.light.mode = .neon; a.light.extent = 40
        a.shadow.enabled = true; a.shadow.blur = 40; a.shadow.spread = 20
        a.shadow.offsetX = -40; a.shadow.offsetY = 40
        let extent = EffectGeometry.overlayRect(for: rect, appearance: a)
        #expect(rect.minX - extent.minX == 212 && extent.maxX - rect.maxX == 172)
        #expect(rect.minY - extent.minY == 212 && extent.maxY - rect.maxY == 172)
        a.shadow.offsetX = 40; a.shadow.offsetY = -40
        let reverse = EffectGeometry.overlayRect(for: rect, appearance: a)
        #expect(rect.minX - reverse.minX == 172 && reverse.maxX - rect.maxX == 212)
        #expect(rect.minY - reverse.minY == 172 && reverse.maxY - rect.maxY == 212)
    }
    @Test func placementUsesCorrectEdgesAndConcentricRadii() {
        let window = CGRect(x: -100,y: 200,width: 300,height: 200)
        var a = Appearance(); a.width = 20; a.radius = 18.5
        let outside = EffectGeometry.contour(for: window, appearance: a)
        #expect(outside.innerRect == window && outside.outerRect == window.insetBy(dx: -20,dy: -20))
        #expect(outside.innerRadius == 18.5 && outside.outerRadius == 38.5)
        a.placement = .centered
        let centered = EffectGeometry.contour(for: window, appearance: a)
        #expect(centered.rect == window && centered.innerRect == window.insetBy(dx: 10,dy: 10))
        #expect(centered.innerRadius == 8.5 && centered.outerRadius == 28.5)
        a.placement = .inside
        let inside = EffectGeometry.contour(for: window, appearance: a)
        #expect(inside.outerRect == window && inside.innerRect == window.insetBy(dx: 20,dy: 20))
        #expect(inside.outerRadius == 18.5 && inside.innerRadius == 0)
        #expect(EffectGeometry.overlayRect(for: window, appearance: a) == window)
    }
    @Test func gapFollowsPlacementAndSmallWindowsStayValid() {
        let window = CGRect(x: 0,y: 0,width: 80,height: 50)
        var a = Appearance(); a.width = 8; a.gap = 5; a.placement = .inside
        #expect(EffectGeometry.contour(for: window, appearance: a).outerRect == window.insetBy(dx: 5,dy: 5))
        a.placement = .outside
        #expect(EffectGeometry.contour(for: window, appearance: a).innerRect == window.insetBy(dx: -5,dy: -5))
        a.width = 100; a.gap = 200; a.radius = 300; a.placement = .inside
        let contour = EffectGeometry.contour(for: window, appearance: a)
        #expect(contour.width > 0 && contour.innerRect.width > 0 && contour.innerRect.height > 0)
        #expect(window.contains(contour.outerRect))
        #expect(contour.outerRadius <= min(contour.outerRect.width,contour.outerRect.height)/2)
    }
    @Test func insideEffectsGetEnoughSpaceIncludingNegativeOffsets() {
        let window = CGRect(x: -500,y: 900,width: 200,height: 120)
        var a = Appearance(); a.placement = .inside; a.width = 20; a.gap = 5
        a.shadow.enabled = true; a.shadow.blur = 12; a.shadow.spread = 7
        a.shadow.offsetX = -40; a.shadow.offsetY = 40
        let extent = EffectGeometry.overlayRect(for: window, appearance: a)
        #expect(extent.minX == window.minX-78 && extent.minY == window.minY-78)
        #expect(extent.maxX >= window.maxX && extent.maxY >= window.maxY)
    }
    @Test func alignedOverlayContainsEffectsAndDoesNotResizeDuringFractionalMoves() {
        var a = Appearance(); a.placement = .centered
        let rect = CGRect(x: -100.25,y: 300.75,width: 320,height: 240)
        let aligned = EffectGeometry.alignedOverlayRect(for: rect, appearance: a)
        #expect(aligned.contains(EffectGeometry.overlayRect(for: rect, appearance: a)))
        #expect(aligned.minX.rounded(.down) == aligned.minX && aligned.minY.rounded(.down) == aligned.minY)
        for delta in [0.0,0.25,0.5,0.75,1.0] {
            #expect(EffectGeometry.alignedOverlayRect(for: rect.offsetBy(dx: delta,dy: delta), appearance: a).size == aligned.size)
        }
    }
    @Test func metalsHaveDistinctPalettesAndAdjustableContrast() {
        var m = MaterialEffect(); m.mode = .gold; m.gloss = 0
        #expect(m.stops.allSatisfy { $0.color == m.baseColor })
        m.gloss = 1
        let gold = m.stops
        #expect(gold.first!.color != gold[3].color)
        m.mode = .chrome
        #expect(m.stops != gold)
        #expect(m.stops.first!.location == 0 && m.stops.last!.location == 1)
        #expect(m.stops.allSatisfy { $0.color == $0.color.normalized })
        m.gloss = .nan; m.angle = .infinity; m.reflectionWidth = 0; m.reflectionStrength = 5
        #expect(m.normalized.gloss == 0.65 && m.normalized.angle == 45)
        #expect(m.normalized.reflectionWidth == 0.05 && m.normalized.reflectionStrength == 1)
    }
    @Test func animationNeedsVisibilityAndMotionPermissionAndCorrectTrigger() {
        for trigger in AnimationTrigger.allCases {
            #expect(!EffectAnimationPolicy.shouldAnimate(visible: false,reducedMotion: false,trigger: trigger,focusChanged: true))
            #expect(!EffectAnimationPolicy.shouldAnimate(visible: true,reducedMotion: true,trigger: trigger,focusChanged: true))
        }
        #expect(!EffectAnimationPolicy.shouldAnimate(visible: true,reducedMotion: false,trigger: .focus,focusChanged: false))
        #expect(EffectAnimationPolicy.shouldAnimate(visible: true,reducedMotion: false,trigger: .focus,focusChanged: true))
        #expect(EffectAnimationPolicy.shouldAnimate(visible: true,reducedMotion: false,trigger: .continuous,focusChanged: false))
    }
}
