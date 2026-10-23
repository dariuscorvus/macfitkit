import Testing
import Foundation
import QuartzCore
@testable import FocusFrameCore

struct TimingCurveTests {
    private static let all = TimingCurve.catalog + [.spring(damping: 0.1, response: 0.2), .spring(damping: 1, response: 0.6), .bezier(x1: 0.3, y1: -0.6, x2: 0.7, y2: 1.8)]
    private static let steps = (0...400).map { Double($0) / 400 }

    @Test(arguments: all) func everyCurveStartsAtZeroAndEndsAtOne(curve: TimingCurve) {
        #expect(abs(curve.value(at: 0)) < 1e-9 && abs(curve.value(at: 1) - 1) < 1e-9)
    }

    @Test(arguments: TimingCurve.catalog.filter(\.isMonotonic)) func monotonicCurvesStayInRangeAndRise(curve: TimingCurve) {
        let values = Self.steps.map(curve.value)
        #expect(values.allSatisfy { $0 >= -1e-9 && $0 <= 1 + 1e-9 })
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 + 1e-9 })
    }

    @Test(arguments: [TimingCurve.family(.back, .in), .family(.back, .out), .family(.elastic, .out), .family(.elastic, .inOut), .defaultSpring])
    func overshootingCurvesLeaveTheRange(curve: TimingCurve) {
        let range = curve.range()
        #expect(range.lowerBound < -0.01 || range.upperBound > 1.01)
    }

    @Test func bounceStaysWithinRangeButIsNotMonotonic() {
        let values = Self.steps.map(TimingCurve.family(.bounce, .out).value)
        #expect(values.allSatisfy { $0 >= -1e-9 && $0 <= 1 + 1e-9 })
        #expect(zip(values, values.dropFirst()).contains { $0 > $1 })
    }

    @Test func outAndInOutMirrorTheInFunction() {
        let quadIn = TimingCurve.family(.quad, .in), quadOut = TimingCurve.family(.quad, .out), quadInOut = TimingCurve.family(.quad, .inOut)
        #expect(abs(quadIn.value(at: 0.3) - 0.09) < 1e-12 && abs(quadOut.value(at: 0.3) - 0.51) < 1e-12)
        #expect(abs(quadInOut.value(at: 0.5) - 0.5) < 1e-12 && abs(quadInOut.value(at: 0.25) - 0.125) < 1e-12)
    }

    @Test(arguments: [(TimingCurve.easeIn, CAMediaTimingFunctionName.easeIn), (.easeOut, .easeOut), (.easeInOut, .easeInEaseOut)])
    func presetsUseTheSystemControlPoints(curve: TimingCurve, name: CAMediaTimingFunctionName) {
        let function = CAMediaTimingFunction(name: name)
        var p1 = [Float](repeating: 0, count: 2), p2 = [Float](repeating: 0, count: 2)
        function.getControlPoint(at: 1, values: &p1); function.getControlPoint(at: 2, values: &p2)
        guard case .bezier(let x1, let y1, let x2, let y2) = curve else { Issue.record("not a Bézier"); return }
        #expect([x1, y1, x2, y2].map(Float.init) == [p1[0], p1[1], p2[0], p2[1]])
    }

    @Test(arguments: [TimingCurve.easeInOut, .bezier(x1: 0.1, y1: 0.9, x2: 0.2, y2: 1), .bezier(x1: 0.9, y1: 0, x2: 1, y2: 0.1), .bezier(x1: 0.3, y1: -0.6, x2: 0.7, y2: 1.8)])
    func bezierSolverHitsPointsOnTheCurve(curve: TimingCurve) {
        guard case .bezier(let x1, let y1, let x2, let y2) = curve else { return }
        for s in stride(from: 0.02, through: 0.98, by: 0.04) {
            let x = TimingCurve.bezierPoint(s, x1, x2), y = TimingCurve.bezierPoint(s, y1, y2)
            #expect(abs(curve.value(at: x) - y) < 0.001)
        }
    }

    @Test(arguments: all) func curvesSurvivePersistenceWithAVersion(curve: TimingCurve) throws {
        let data = try JSONEncoder().encode(curve)
        #expect(try JSONDecoder().decode(TimingCurve.self, from: data) == curve)
        #expect(String(decoding: data, as: UTF8.self).contains("\"version\":1"))
    }

    @Test func decodingClampsUnusableParameters() throws {
        let bezier = try JSONDecoder().decode(TimingCurve.self, from: Data(#"{"version":1,"kind":"bezier","x1":-1,"y1":9,"x2":2,"y2":0.5}"#.utf8))
        #expect(bezier == .bezier(x1: 0, y1: 3, x2: 1, y2: 0.5))
        let spring = try JSONDecoder().decode(TimingCurve.self, from: Data(#"{"version":1,"kind":"spring","damping":0,"response":5}"#.utf8))
        #expect(spring == .spring(damping: 0.05, response: 1))
    }

    @Test func catalogListsEveryFamilyInEveryDirection() {
        #expect(TimingCurve.catalog.count == 4 + EasingFamily.allCases.count * 3 + 1)
        #expect(Set(TimingCurve.catalog.map { "\($0)" }).count == TimingCurve.catalog.count)
    }
}
