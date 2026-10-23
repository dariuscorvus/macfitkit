import Testing
import Foundation
@testable import FocusFrameCore

struct AnimationTests {
    private func appearance(_ json: String) throws -> Appearance { try JSONDecoder().decode(Appearance.self, from: Data(json.utf8)) }
    private func only(_ tracks: [AnimationTrack], _ property: AnimationTrack.Property) throws -> AnimationTrack {
        try #require(tracks.first { $0.property == property })
    }

    // The keyframes below are the ones the renderer built from the old motion settings.

    @Test func subtlePresetKeepsItsImpulseKeyframes() throws {
        let a = try appearance(#"{"motion":{"mode":"impulse","strength":0.35,"duration":0.8}}"#)
        let fade = try only(try #require(a.animations.first).tracks(), .accentOpacity)
        #expect(fade.values == [0, 0.35, 0] && fade.keyTimes == [0, 0.2, 1] && fade.timings == [.easeInOut, .easeInOut])
        #expect(fade.duration == 0.8 && fade.repeatCount == 1 && fade.delay == 0)
    }

    @Test func springImpulseBecomesABouncingPulse() throws {
        let entry = try #require(try appearance(#"{"motion":{"mode":"impulse","curve":"spring","strength":0.5}}"#).animations.first)
        #expect(entry.bounce && entry.curve == .easeInOut)
        let fade = try only(entry.tracks(), .accentOpacity)
        #expect(fade.values == [0, 0.5, 0.15, 0.3, 0] && fade.keyTimes == [0, 0.15, 0.45, 0.65, 1])
    }

    @Test func runnerPresetKeepsFadeAndTravel() throws {
        let tracks = try #require(try appearance(#"{"motion":{"mode":"runner","duration":1.8}}"#).animations.first).tracks()
        let fade = try only(tracks, .accentOpacity), travel = try only(tracks, .dashTravel)
        #expect(fade.values == [0, 0.65, 0.65, 0] && fade.keyTimes == [0, 0.12, 0.85, 1])
        #expect(travel.values == [0, -1] && travel.timings == [.easeInOut] && travel.duration == 1.8)
    }

    @Test func breathingShadowPresetKeepsOpacityBlurAndTightShadow() throws {
        let entry = try #require(try appearance(#"{"motion":{"mode":"breathe","target":"shadow","trigger":"continuous","duration":4}}"#).animations.first)
        let tracks = entry.tracks()
        #expect(try only(tracks, .opacityMultiplier).values == [1, 1 - 0.65, 1])
        #expect(try only(tracks, .shadowBlurScale).values == [1, 0.5, 1] && (try only(tracks, .tightShadow)).values == [0, 0.65, 0])
        #expect(tracks.allSatisfy { $0.repeatCount == .infinity && $0.duration == 4 && $0.keyTimes == [0, 0.5, 1] })
    }

    @Test func colorFlowPresetKeepsItsMix() throws {
        let entry = try #require(try appearance(#"{"motion":{"mode":"flow","trigger":"continuous","duration":8,"curve":"linear"}}"#).animations.first)
        let mix = try only(entry.tracks(), .colorMix)
        #expect(entry.kind == .colorFlow && mix.values == [0, 0.65, 0] && mix.timings == [.linear, .linear] && mix.repeatCount == .infinity)
    }

    @Test func everyPresetMigratesToEntriesThatSurviveAReload() throws {
        for preset in MotionPreset.allCases {
            let applied = preset.applying(to: Appearance())
            #expect(applied.animations.count == 1)
            let data = try JSONEncoder().encode(applied), json = String(decoding: data, as: UTF8.self)
            #expect(try JSONDecoder().decode(Appearance.self, from: data) == applied)
            #expect(!json.contains("\"motion\"") && !json.contains("\"opacityAnimation\"") && !json.contains("\"rotation\""))
        }
    }

    @Test func synchronizedSettingsShareTheMotionTiming() throws {
        let a = try appearance(#"""
        {"motion":{"mode":"runner","duration":2,"cycles":3,"trigger":"focus","synchronize":true},
         "opacityAnimation":{"mode":"pulse","pulsePeriod":5,"focusDuration":4,"trigger":"continuous"},
         "rotation":{"enabled":true,"period":9,"trigger":"continuous"},
         "material":{"mode":"gold","reflectionEnabled":true,"period":7,"trigger":"continuous"}}
        """#)
        #expect(a.animations.map { $0.kind } == [.opacityPulse, .gradientRotation, .metalReflection, .runner])
        #expect(a.animations.allSatisfy { $0.trigger == .focus && $0.duration == 2 })
        #expect(a.animations[0].repeats == 3 && a.animations[1].repeats == 3 && a.animations[2].repeats == 3 && a.animations[3].repeats == 3)
        #expect(a.material.mode == .gold)
    }

    @Test func unsynchronizedSettingsKeepTheirOwnTiming() throws {
        let a = try appearance(#"""
        {"opacityAnimation":{"mode":"blink","blinkPeriod":0.5,"focusDuration":2,"blinkMinimum":0.1,"maximum":0.9,"target":"light"},
         "rotation":{"enabled":true,"period":4,"focusDuration":2,"clockwise":false},
         "material":{"reflectionEnabled":true,"focusDuration":3}}
        """#)
        let blink = a.animations[0], rotation = a.animations[1], reflection = a.animations[2]
        #expect(blink.kind == .opacityBlink && blink.duration == 0.5 && blink.repeats == 4 && blink.minimum == 0.1 && blink.maximum == 0.9 && blink.target == .light)
        let turn = try only(rotation.tracks(), .rotation)
        #expect(rotation.duration == 4 && rotation.repeats == 0.5 && turn.values == [0, 2 * .pi])
        #expect(reflection.duration == 3 && reflection.repeats == 1)
    }

    @Test func focusRepeatsPlayExactlyThatOften() throws {
        // The old renderer set repeatCount to cycles − 1, which Core Animation reads as total plays: three cycles played twice.
        var entry = AnimationEntry(.draw); entry.repeats = 3
        #expect(entry.tracks().allSatisfy { $0.repeatCount == 3 })
        entry.trigger = .continuous
        #expect(entry.tracks().allSatisfy { $0.repeatCount == .infinity })
    }

    @Test func curvesCoreAnimationCannotExpressAreSampled() throws {
        var entry = AnimationEntry(.focusPulse); entry.curve = .family(.elastic, .out); entry.strength = 1
        let fade = try only(entry.tracks(), .accentOpacity), n = AnimationTrack.samplesPerSegment
        #expect(fade.values.count == 1 + 2 * n && fade.timings.allSatisfy { $0 == .linear })
        #expect(fade.values.first == 0 && abs(fade.values[n] - 1) < 1e-9 && abs(fade.values.last!) < 1e-9)
        #expect(fade.values.max()! > 1)
        #expect(zip(fade.keyTimes, fade.keyTimes.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func focusOpacityContinuesFromTheVisibleMultiplier() throws {
        var entry = AnimationEntry(.opacityPulse); entry.delay = 0.3; entry.repeats = 2
        let track = try only(entry.tracks(startingMultiplier: 0.6), .opacityMultiplier)
        #expect(track.values.first == 0.6 && track.values.last == 1 && track.duration == 4 && track.repeatCount == 1 && track.delay == 0.3)
    }

    @Test func focusSpanCoversDelayAndRepeatsOfEnabledFocusEntries() {
        var a = AnimationEntry(.focusPulse, duration: 1); a.delay = 0.5; a.repeats = 2
        var b = AnimationEntry(.runner, duration: 4); b.enabled = false
        let c = AnimationEntry(.breathe, trigger: .continuous, duration: 9)
        #expect([a, b, c].focusSpan == 2.5 && [a, b, c].active.count == 2)
    }

    @Test func entriesSurvivePersistenceWithEveryField() throws {
        var e = AnimationEntry(.opacityBlink, trigger: .continuous, duration: 3)
        e.delay = 1; e.repeats = 2; e.target = .light; e.strength = 0.3; e.curve = .defaultSpring; e.minimum = 0.2; e.maximum = 0.8; e.clockwise = false; e.bounce = true
        #expect(try JSONDecoder().decode(AnimationEntry.self, from: JSONEncoder().encode(e)) == e)
        let minimal = try JSONDecoder().decode(AnimationEntry.self, from: Data(#"{"kind":"runner"}"#.utf8))
        #expect(minimal.trigger == .focus && minimal.duration == 1.8 && minimal.curve == .linear && minimal.enabled)
    }
}
