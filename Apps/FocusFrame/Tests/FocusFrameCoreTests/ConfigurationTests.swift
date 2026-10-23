import Testing
import CoreGraphics
import Foundation
@testable import FocusFrameCore

struct ConfigurationTests {
    @Test func corruptedAppearanceHasSafeVisibleBounds() {
        var appearance = Appearance()
        appearance.width = -.infinity
        appearance.radius = .nan
        appearance.gap = -10
        appearance.opacity = 0
        appearance.red = 5
        let safe = appearance.normalized
        #expect(safe.width == 3)
        #expect(safe.radius == 18.5)
        #expect(safe.gap == 0)
        #expect(safe.opacity == 0.1)
        #expect(safe.red == 1)
    }
    @Test func settingsSurviveRoundTripIncludingExceptionsAndBehavior() throws {
        var original = Configuration()
        original.appearance.gap = 6
        original.appearance.radius = 16
        original.appearance.opacity = 0.7
        original.excludedApps = ["com.apple.finder"]
        original.shortcutEnabled = true
        original.hideInFullScreen = true
        let restored = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(original))
        #expect(restored == original)
    }
    @Test func exceptionsAreDeduplicatedAndEmptyEntriesRemoved() {
        var configuration = Configuration()
        configuration.excludedApps = [" com.apple.finder ", "", "com.apple.finder"]
        #expect(configuration.normalized.excludedApps == ["com.apple.finder"])
    }
    @Test func gapNeverCoversWindowContent() {
        let window = CGRect(x: -800, y: 500, width: 600, height: 400)
        let expanded = WindowGeometry.overlayRect(for: window, width: 6, gap: 8)
        #expect(expanded == CGRect(x: -814, y: 486, width: 628, height: 428))
    }
    @Test func interruptedGestureRejectsDelayedMoveConfirmation() {
        var drag = WindowDrag(frame: CGRect(x: 0, y: 0, width: 600, height: 400), pointer: .zero)
        _ = drag.confirmMove()
        drag.interrupt()
        #expect(drag.updatePointer(CGPoint(x: 100, y: 100)) == nil)
        #expect(drag.confirmMove() == nil)
        #expect(!drag.isMoving)
    }
}

@Test func legacyConfigurationAndPowerPolicy() throws {
    let legacy = Data("{\"appearance\":{},\"shortcutEnabled\":true}".utf8)
    let decoded = try JSONDecoder().decode(Configuration.self, from: legacy)
    #expect(decoded.shortcutKeyCode == 3); #expect(decoded.shortcutModifiers == 6144)
    var value = decoded
    value.appearance.animations = [AnimationEntry(.gradientRotation), AnimationEntry(.opacityPulse), AnimationEntry(.metalReflection)]
    #expect(value.renderedAppearance(lowPower: true).animations.active.isEmpty)
    #expect(value.renderedAppearance(lowPower: false).animations.active.count == 3)
    #expect(value.appearance.animations.allSatisfy { $0.enabled })
    value.shortcutModifiers = 0; value.shortcutKeyCode = 300
    #expect(value.normalized.shortcutModifiers == 6144); #expect(value.normalized.shortcutKeyCode == 3)
    let transfer = PortablePreferences(configuration: value.normalized, profiles: [AppearanceProfile(name: "Test", appearance: value.appearance)])
    let restored = try JSONDecoder().decode(PortablePreferences.self, from: JSONEncoder().encode(transfer))
    #expect(restored.configuration == value.normalized); #expect(restored.profiles == transfer.profiles)
}
