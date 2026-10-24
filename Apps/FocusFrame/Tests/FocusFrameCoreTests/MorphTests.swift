import Testing
import Foundation
@testable import FocusFrameCore

struct MorphTests {
    private let red = EffectColor(1, 0, 0), green = EffectColor(0, 1, 0), blue = EffectColor(0, 0, 1)

    private func pair(_ a: AnimationEntry, _ b: AnimationEntry, transition: Double = 0.4) -> [ScheduledEntry] {
        var b = b; b.start = .morph; b.transition = transition
        return AnimationSchedule.make([a, b])
    }

    @Test func sameEffectMorphsAndTheSourceHandsOverAtTheWindow() throws {
        let s = pair(AnimationEntry(.breathe, duration: 2), AnimationEntry(.breathe, duration: 1))
        #expect(s[1].begin == 1.6 && s[0].cut == 1.6 && s[1].morph?.length == 0.4 && s[1].morphSource?.begin == 0)
        #expect(s[0].fadeOut == nil && s[1].fadeIn == nil)
    }

    @Test(arguments: [(AnimationKind.breathe, AnimationKind.runner), (.colorFlow, .gradientRotation), (.opacityPulse, .opacityBlink)])
    func differentEffectsFallBackToCrossfade(a: AnimationKind, b: AnimationKind) {
        let s = pair(AnimationEntry(a), AnimationEntry(b))
        #expect(s[1].morph == nil && s[0].cut == nil && s[1].fadeIn != nil && s[0].fadeOut != nil)
    }

    @Test func differentTargetsFallBackToCrossfade() {
        var a = AnimationEntry(.breathe); a.target = .shadow
        var b = AnimationEntry(.breathe); b.target = .light
        #expect(pair(a, b)[1].morph == nil)
        #expect(!AnimationEntry(.breathe, trigger: .continuous).canMorph(into: AnimationEntry(.breathe)))
    }

    @Test func morphedValuesRunFromTheSourceToTheTargetWithoutAJump() throws {
        var a = AnimationEntry(.focusPulse, duration: 2); a.strength = 0.3
        var b = AnimationEntry(.focusPulse, duration: 1.5); b.strength = 0.9
        let s = pair(a, b, transition: 0.6), window = try #require(s[1].morph)
        var target = b.tracks()[0]; target.delay = s[1].begin
        let source = a.tracks()[0], morphed = target.morphed(from: source, sourceOffset: s[1].morphSource!.begin - s[1].begin, window: window)
        let handover = source.ending(at: window.start - s[0].begin)
        // At the window start the target shows exactly what the source showed; at its end it is the target alone.
        #expect(abs(morphed.value(at: 0) - source.value(at: window.start)) < 1e-9)
        #expect(abs(handover.values.last! - morphed.value(at: 0)) < 1e-9 && handover.duration == window.start)
        #expect(abs(morphed.value(at: window.length) - target.value(at: window.length)) < 1e-9)
        for t in stride(from: window.length, through: 1.5, by: 0.1) { #expect(abs(morphed.value(at: t) - target.value(at: t)) < 0.002) }
        let samples = stride(from: 0.0, through: window.length, by: 0.01).map(morphed.value)
        #expect(zip(samples, samples.dropFirst()).allSatisfy { abs($0 - $1) < 0.05 })
    }

    @Test func endingKeepsTheTrackUpToTheCut() {
        let track = AnimationEntry(.focusPulse, duration: 1).tracks()[0], ended = track.ending(at: 0.5)
        #expect(ended.duration == 0.5 && ended.keyTimes.last == 1)
        for t in stride(from: 0.0, through: 0.5, by: 0.05) { #expect(abs(ended.value(at: t) - track.value(at: t)) < 0.01) }
    }

    @Test func alignedGradientsShareStopsAndKeepBothEndpointsExact() {
        let a = [GradientStop(red, at: 0), GradientStop(blue, at: 1)]
        let b = [GradientStop(green, at: 0), GradientStop(red, at: 0.3), GradientStop(blue, at: 0.7), GradientStop(green, at: 1)]
        let (from, to) = GradientEffect.aligned(a, b)
        #expect(from.map(\.location) == to.map(\.location) && from.map(\.location) == [0, 0.3, 0.7, 1])
        func color(_ stops: [GradientStop], _ x: Double) -> EffectColor { var g = GradientEffect(); g.stops = stops; return g.color(at: x) }
        for x in stride(from: 0.0, through: 1.0, by: 0.01) {
            let f = color(from, x), o = color(a, x), t = color(to, x), n = color(b, x)
            #expect(abs(f.red - o.red) + abs(f.green - o.green) + abs(f.blue - o.blue) < 1e-9)
            #expect(abs(t.red - n.red) + abs(t.green - n.green) + abs(t.blue - n.blue) < 1e-9)
        }
    }

    @Test func alignedGradientsKeepHardEdges() {
        let a = [GradientStop(red, at: 0), GradientStop(red, at: 0.5), GradientStop(blue, at: 0.5), GradientStop(blue, at: 1)]
        let b = [GradientStop(green, at: 0), GradientStop(green, at: 1)]
        let (from, to) = GradientEffect.aligned(a, b)
        #expect(from.count == to.count && from.count == 4)
        #expect(from[1] == GradientStop(red, at: 0.5) && from[2] == GradientStop(blue, at: 0.5))
        #expect(to[1] == GradientStop(green, at: 0.5) && to[2] == GradientStop(green, at: 0.5))
    }

    @Test func morphStartSurvivesPersistence() throws {
        var e = AnimationEntry(.breathe); e.start = .morph
        #expect(try JSONDecoder().decode(AnimationEntry.self, from: JSONEncoder().encode(e)).start == .morph)
    }
}
