import Testing
import Foundation
@testable import FocusFrameCore

struct GradientTests {
    private let red = EffectColor(1, 0, 0), blue = EffectColor(0, 0, 1), green = EffectColor(0, 1, 0)
    private func decode(_ json: String) throws -> GradientEffect { try JSONDecoder().decode(GradientEffect.self, from: Data(json.utf8)) }

    @Test func twoColorLinearSettingsBecomeStopsAtTheEnds() throws {
        let g = try decode(#"{"mode":"linear","first":{"red":1,"green":0,"blue":0},"second":{"red":0,"green":0,"blue":1},"angle":45}"#)
        #expect(g.stops == [GradientStop(red, at: 0), GradientStop(blue, at: 1)] && g.angle == 45)
    }

    @Test func twoColorConicSettingsKeepTheirMirroredLook() throws {
        // The renderer drew first → second → first at 0, 0.5, 1 before variable stops.
        let g = try decode(#"{"mode":"conic","first":{"red":1,"green":0,"blue":0},"second":{"red":0,"green":0,"blue":1}}"#)
        #expect(g.stops == [GradientStop(red, at: 0), GradientStop(blue, at: 0.5), GradientStop(red, at: 1)])
        #expect(g.isSeamClosed && g.flowOrder() == [1, 0, 1])
    }

    @Test func missingGradientKeysUseTheDefaults() throws {
        #expect(try decode("{}") == GradientEffect())
        let legacy = #"{"appearance":{"red":0.2,"green":0.3,"blue":0.4,"gradient":{"mode":"off"}}}"#
        #expect(try JSONDecoder().decode(Configuration.self, from: Data(legacy.utf8)).appearance.gradient.stops == GradientEffect().stops)
    }

    @Test func tenStopsSurvivePersistenceWithoutLegacyKeys() throws {
        var g = GradientEffect(); g.mode = .linear
        g.stops = (0..<10).map { GradientStop(EffectColor(Double($0) / 9, 0.5, 1 - Double($0) / 9), at: Double($0) / 9) }
        let data = try JSONEncoder().encode(g), json = String(decoding: data, as: UTF8.self)
        #expect(try JSONDecoder().decode(GradientEffect.self, from: data) == g)
        #expect(!json.contains("\"first\"") && !json.contains("\"second\""))
    }

    @Test func normalizationSortsClampsAndKeepsOrderAtEqualLocations() {
        var g = GradientEffect()
        g.stops = [GradientStop(blue, at: 0.7), GradientStop(red, at: 0.3), GradientStop(green, at: 0.3), GradientStop(EffectColor(2, -1, .nan), at: 4)]
        let n = g.normalized
        #expect(n.stops.map(\.location) == [0.3, 0.3, 0.7, 1])
        #expect(n.stops[0].color == red && n.stops[1].color == green && n.stops[3].color == EffectColor(1, 0, 0.15))
    }

    @Test func normalizationKeepsAtLeastTwoStops() {
        var g = GradientEffect(); g.stops = [GradientStop(red, at: 0.4)]
        #expect(g.normalized.stops == [GradientStop(red, at: 0.4), GradientStop(red, at: 1)])
        g.stops = [GradientStop(red, at: 1)]
        #expect(g.normalized.stops == [GradientStop(red, at: 0), GradientStop(red, at: 1)])
        g.stops = []
        #expect(g.normalized.stops == GradientEffect().stops)
    }

    @Test func colorAtInterpolatesBetweenNeighbours() {
        var g = GradientEffect(); g.stops = [GradientStop(red, at: 0.2), GradientStop(blue, at: 0.6)]
        let mid = g.color(at: 0.4)
        #expect(abs(mid.red - 0.5) < 1e-9 && mid.green == 0 && abs(mid.blue - 0.5) < 1e-9)
        #expect(g.color(at: 0) == red && g.color(at: 1) == blue && g.color(at: 0.2) == red)
    }

    @Test func closingTheSeamRecolorsTheLastStopOrAddsOne() {
        var g = GradientEffect(); g.mode = .conic; g.stops = [GradientStop(red, at: 0), GradientStop(blue, at: 0.5)]
        #expect(!g.isSeamClosed)
        g.closeSeam(); #expect(g.stops == [GradientStop(red, at: 0), GradientStop(blue, at: 0.5), GradientStop(red, at: 1)])
        g.stops = [GradientStop(red, at: 0), GradientStop(green, at: 0.5), GradientStop(blue, at: 1)]
        g.closeSeam(); #expect(g.stops.count == 3 && g.stops[2] == GradientStop(red, at: 1) && g.isSeamClosed)
    }

    @Test func flowReversesLinearAndShiftsTheConicRing() {
        var g = GradientEffect(); g.mode = .linear; g.stops = [GradientStop(red, at: 0), GradientStop(green, at: 0.5), GradientStop(blue, at: 1)]
        #expect(g.flowOrder() == [2, 1, 0])
        g.mode = .conic
        #expect(g.flowOrder() == [1, 2, 0])
        g.stops.append(GradientStop(red, at: 1))
        #expect(g.flowOrder() == [1, 2, 0, 1])
    }

    @Test func colorFlowPresetBuildsAClosedConicGradient() {
        var a = Appearance(); a.red = 0.2; a.green = 0.4; a.blue = 0.6
        let g = MotionPreset.colorFlow.applying(to: a).gradient
        #expect(g.mode == .conic && g.isSeamClosed && g.stops.count == 3 && g.stops[0].color == EffectColor(0.2, 0.4, 0.6))
    }
}
