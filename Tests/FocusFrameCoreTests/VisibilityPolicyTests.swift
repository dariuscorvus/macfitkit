import Testing
@testable import FocusFrameCore

struct VisibilityPolicyTests {
    @Test func permissionLossAlwaysHidesEvenDuringTracking() {
        #expect(VisibilityPolicy.decide(enabled: true, trusted: false) == .permissionRequired)
        #expect(VisibilityPolicy.decide(enabled: false, trusted: false, excluded: true) == .permissionRequired)
    }
    @Test func exceptionsAndPauseOverrideAvailableWindow() {
        #expect(VisibilityPolicy.decide(enabled: true, trusted: true, excluded: true) == .excluded)
        #expect(VisibilityPolicy.decide(enabled: false, trusted: true) == .paused)
    }
    @Test func fullscreenRuleDoesNotHideNormalWindowsOrMissingWindows() {
        #expect(VisibilityPolicy.decide(enabled: true, trusted: true, fullScreen: true, hideInFullScreen: false) == .show)
        #expect(VisibilityPolicy.decide(enabled: true, trusted: true, fullScreen: true, hideInFullScreen: true) == .fullScreen)
        #expect(VisibilityPolicy.decide(enabled: true, trusted: true, fullScreen: false, hideInFullScreen: true) == .show)
        #expect(VisibilityPolicy.decide(enabled: true, trusted: true, fullScreen: true, hideInFullScreen: true, hasWindow: false) == .noWindow)
    }
}
