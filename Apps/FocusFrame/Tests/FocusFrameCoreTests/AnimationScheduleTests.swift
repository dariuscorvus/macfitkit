import Testing
import Foundation
@testable import FocusFrameCore

struct AnimationScheduleTests {
    private func entry(_ kind: AnimationKind, _ duration: Double, _ start: EntryStart = .withPrevious, repeats: Double = 1) -> AnimationEntry {
        var e = AnimationEntry(kind, duration: duration); e.start = start; e.repeats = repeats; return e
    }

    @Test func sequencesStartWhenThePreviousEntryEnds() {
        let a = entry(.focusPulse, 1, repeats: 2), b = entry(.runner, 1.5, .afterPrevious)
        let s = AnimationSchedule.make([a, b])
        #expect(s[0].begin == 0 && s[0].end == 2 && s[1].begin == 2 && s[1].end == 3.5)
    }

    @Test func overlapStartsEarlierButNotBeforeThePreviousEntry() {
        var b = entry(.runner, 1, .afterPrevious); b.overlap = 0.3
        #expect(AnimationSchedule.make([entry(.focusPulse, 1), b])[1].begin == 0.7)
        b.overlap = 5
        #expect(AnimationSchedule.make([entry(.focusPulse, 1), b])[1].begin == 0)
    }

    @Test func withPreviousSharesTheStartAndAddsItsOwnDelay() {
        var b = entry(.runner, 1); b.delay = 0.4
        var c = entry(.draw, 1, .afterPrevious); c.delay = 0.1
        let s = AnimationSchedule.make([entry(.focusPulse, 2), b, c])
        #expect(s[1].begin == 0.4 && s[2].begin == 1.4 + 0.1)
    }

    @Test func continuousEntriesKeepTheirClockAndDoNotBreakAChain() {
        let a = entry(.focusPulse, 1), loop = AnimationEntry(.breathe, trigger: .continuous, duration: 4), b = entry(.runner, 1, .afterPrevious)
        let s = AnimationSchedule.make([a, loop, b])
        #expect(s[1].begin == 0 && s[1].end == .infinity && s[2].begin == 1)
        #expect(AnimationSchedule.focusEnd([a, loop, b]) == 2)
    }

    @Test func crossfadeWeightsSumToOneOverTheTransition() throws {
        var b = entry(.runner, 2, .crossfade); b.transition = 0.6
        let s = AnimationSchedule.make([entry(.focusPulse, 1.5), b])
        let out = try #require(s[0].fadeOut), into = try #require(s[1].fadeIn)
        #expect(s[1].begin == 0.9 && out.start == 0.9 && out.end == 1.5 && into.start == 0.9 && into.length == 0.6)
        for i in 0...60 {
            let t = 0.9 + 0.6 * Double(i) / 60
            #expect(abs(out.weight(at: t) + into.weight(at: t) - 1) < 1e-12)
        }
        #expect(out.weight(at: 0.5) == 1 && into.weight(at: 2) == 1 && out.weight(at: 1.6) == 0)
    }

    @Test func crossfadeIsShorterThanEitherEntry() {
        var b = entry(.runner, 0.3, .crossfade); b.transition = 5
        let s = AnimationSchedule.make([entry(.focusPulse, 1), b])
        #expect(s[1].fadeIn?.length == 0.3 && s[0].fadeOut?.length == 0.3)
    }

    @Test func weightedTracksBlendTowardNeutralAndKeepTheirShapeOutside() throws {
        var a = entry(.focusPulse, 1); a.strength = 1
        var b = entry(.runner, 1, .crossfade); b.transition = 0.4
        let s = AnimationSchedule.make([a, b])
        let original = a.tracks()[0], faded = original.weighted(by: s[0].fades)
        #expect(faded.repeatCount == 1 && faded.duration == 1 && faded.values.last == 0)
        // Before the window the original keyframes and their Bézier timing remain.
        #expect(faded.keyTimes[1] == 0.2 && faded.values[1] == 1 && faded.timings[0] == .easeInOut)
        for t in stride(from: 0.6, through: 1.0, by: 0.05) {
            let expected = original.value(at: t) * s[0].fadeOut!.weight(at: t)
            #expect(abs(faded.value(at: t) - expected) < 0.02)
        }
    }

    @Test func positionsAreNotFaded() {
        var b = entry(.draw, 1, .crossfade); b.transition = 0.5
        let s = AnimationSchedule.make([entry(.runner, 1), b])
        let travel = s[0].entry.tracks().first { $0.property == .dashTravel }!
        #expect(travel.weighted(by: s[0].fades) == travel)
    }

    @Test func interruptionHandsOffWithoutAJump() {
        let track = entry(.focusPulse, 1).tracks()[0], current = 0.7
        let handed = track.handingOff(from: current)
        #expect(handed.values.first == current)
        let samples = stride(from: 0.0, through: 0.15, by: 0.005).map(handed.value)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { abs($0 - $1) < 0.05 })
        for t in stride(from: 0.2, through: 1.0, by: 0.1) { #expect(abs(handed.value(at: t) - track.value(at: t)) < 0.02) }
        #expect(track.handingOff(from: track.values[0]) == track)
    }

    @Test func aLaterSequenceStepEasesToItsStartAndWaits() {
        var track = entry(.focusPulse, 1).tracks()[0]; track.delay = 2
        let handed = track.handingOff(from: 0.8)
        #expect(handed.delay == 0 && handed.duration == 3 && handed.values.first == 0.8)
        #expect(abs(handed.value(at: 0.15) - track.value(at: 0)) < 1e-9 && abs(handed.value(at: 1.9) - track.value(at: 0)) < 1e-9)
        for t in stride(from: 0.0, through: 1.0, by: 0.1) { #expect(abs(handed.value(at: 2 + t) - track.value(at: t)) < 1e-9) }
        let samples = stride(from: 0.0, through: 0.15, by: 0.005).map(handed.value)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { abs($0 - $1) < 0.05 })
    }

    @Test func trackValuesFollowKeyframesRepeatsAndFractionalEnds() {
        var e = entry(.focusPulse, 1, repeats: 2.5); e.strength = 1; e.curve = .linear
        let t = e.tracks()[0]
        #expect(abs(t.value(at: 0.2) - 1) < 1e-9 && abs(t.value(at: 1.2) - 1) < 1e-9 && abs(t.value(at: 0.6) - 0.5) < 1e-9)
        // 2.5 cycles stop half-way through the third: 0.5 of the way from the peak (0.2) down to 0 at 1.
        #expect(abs(t.value(at: 2.5) - 0.625) < 1e-9 && t.value(at: 99) == t.value(at: 2.5))
    }

    @Test func sequenceFieldsSurvivePersistence() throws {
        var e = entry(.runner, 2, .crossfade); e.overlap = 0.7; e.transition = 1.2; e.transitionCurve = .family(.sine, .inOut)
        #expect(try JSONDecoder().decode(AnimationEntry.self, from: JSONEncoder().encode(e)) == e)
        let old = try JSONDecoder().decode(AnimationEntry.self, from: Data(#"{"kind":"draw"}"#.utf8))
        #expect(old.start == .withPrevious && old.overlap == 0 && old.transition == 0.5)
    }
}
