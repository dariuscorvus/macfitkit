import Testing
@testable import FocusFrameCore

struct FocusOpacityTimelineTests {
    @Test func partialPulseReturnsSmoothlyToStaticOpacity() {
        // Original bug: 1.5 s cuts a 2 s cycle while opacity is intermediate.
        let t = FocusOpacityTimeline(blink: false, period: 2, minimum: 0.4, maximum: 1, duration: 1.5)
        #expect(t.duration == 1.5 && t.values.first == 1 && t.values.last == 1)
        #expect(t.values.min()! < 0.7)
        #expect(abs(t.values[t.values.count-2] - 1) < 0.003)
        #expect(zip(t.values,t.values.dropFirst()).allSatisfy { abs($0-$1) < 0.06 })
    }
    @Test func customMaximumIsNotTheFinalStaticTarget() {
        let t = FocusOpacityTimeline(blink: false, period: 2, minimum: 0.2, maximum: 0.6, duration: 1.5)
        #expect(t.values.first == 1 && t.values.last == 1)
        #expect(t.values.min()! < 0.4)
        #expect(abs(t.values[t.values.count-2] - 1) < 0.003)
    }
    @Test func retriggerStartsAtPresentedOpacityAndBothModesEndAtTarget() {
        for blink in [false, true] {
            let t = FocusOpacityTimeline(blink: blink, period: blink ? 1 : 2, minimum: blink ? 0.25 : 0.4, maximum: 1, duration: 0.5, startingMultiplier: 0.37)
            #expect(t.values.first == 0.37 && t.values.last == 1)
            #expect(t.times.first == 0 && t.times.last == 1)
            #expect(t.values.allSatisfy { $0.isFinite && (0...1).contains($0) })
            #expect(zip(t.times,t.times.dropFirst()).allSatisfy { $0 < $1 })
        }
    }
}
