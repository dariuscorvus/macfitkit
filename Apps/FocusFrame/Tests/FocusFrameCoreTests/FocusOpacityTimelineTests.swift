import Testing
@testable import FocusFrameCore

struct FocusOpacityTimelineTests {
    @Test func partialPulseReturnsSmoothlyToStaticOpacity() {
        var e = OpacityEffect(); e.mode = .pulse
        // Original bug: 1.5 s cuts a 2 s cycle while opacity is intermediate.
        let t = FocusOpacityTimeline(effect: e)
        #expect(t.duration == 1.5 && t.values.first == 1 && t.values.last == 1)
        #expect(t.values.min()! < 0.7)
        #expect(abs(t.values[t.values.count-2] - 1) < 0.003)
        #expect(zip(t.values,t.values.dropFirst()).allSatisfy { abs($0-$1) < 0.06 })
    }
    @Test func customMaximumIsNotTheFinalStaticTarget() {
        var e = OpacityEffect(); e.mode = .pulse; e.maximum = 0.6; e.pulseMinimum = 0.2
        let t = FocusOpacityTimeline(effect: e)
        #expect(t.values.first == 1 && t.values.last == 1)
        #expect(t.values.min()! < 0.4)
        #expect(abs(t.values[t.values.count-2] - 1) < 0.003)
    }
    @Test func retriggerStartsAtPresentedOpacityAndBothModesEndAtTarget() {
        for mode in [OpacityMode.pulse,.blink] {
            var e = OpacityEffect(); e.mode = mode; e.focusDuration = 0.5
            let t = FocusOpacityTimeline(effect: e, startingMultiplier: 0.37)
            #expect(t.values.first == 0.37 && t.values.last == 1)
            #expect(t.times.first == 0 && t.times.last == 1)
            #expect(t.values.allSatisfy { $0.isFinite && (0...1).contains($0) })
            #expect(zip(t.times,t.times.dropFirst()).allSatisfy { $0 < $1 })
        }
    }
}
