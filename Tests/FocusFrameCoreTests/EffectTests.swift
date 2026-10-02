import Testing
import Foundation
import CoreGraphics
@testable import FocusFrameCore

struct EffectTests {
    @Test func legacyConfigurationRetainsAllValuesAndEffectsAreOff() throws {
        let json = #"{"appearance":{"red":0.2,"green":0.3,"blue":0.4,"opacity":0.8,"width":7,"radius":13,"gap":4},"excludedApps":["com.apple.finder"],"hideInFullScreen":true,"shortcutEnabled":true}"#
        let c = try JSONDecoder().decode(Configuration.self, from: Data(json.utf8))
        #expect(c.appearance.red == 0.2 && c.appearance.width == 7 && c.appearance.gap == 4)
        #expect(c.excludedApps == ["com.apple.finder"] && c.hideInFullScreen && c.shortcutEnabled)
        #expect(c.appearance.light.mode == .off && !c.appearance.shadow.enabled)
        #expect(c.appearance.gradient.mode == .off && c.appearance.opacityAnimation.mode == .off && !c.appearance.rotation.enabled)
    }
    @Test func combinedEffectsSurvivePersistence() throws {
        var c = Configuration()
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
