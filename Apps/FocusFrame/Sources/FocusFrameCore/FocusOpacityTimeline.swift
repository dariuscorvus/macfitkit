import Foundation

/// Finite opacity effects end at the static multiplier, even between cycles.
/// Samples are prepared once; Core Animation interpolates them without a timer.
public struct FocusOpacityTimeline: Sendable {
    public let values: [Double]
    public let times: [Double]
    public let duration: Double

    public init(blink: Bool, period: Double, minimum: Double, maximum: Double, duration total: Double, startingMultiplier: Double = 1) {
        let period = bounded(period, 0.2...30, 2), maximum = bounded(maximum, 0...1, 1), minimum = min(maximum, bounded(minimum, 0...1, 0.4))
        duration = bounded(total, 0.1...300, 1.5)
        let start = bounded(startingMultiplier, 0...1, 1)
        let count = max(2, Int(ceil(duration * 60)))
        let entrance = min(period / 4, duration / 4)
        let exit = min(period / 2, duration / 2)
        func ease(_ x: Double) -> Double { (1 - cos(min(1, max(0, x)) * .pi)) / 2 }
        var samples: [Double] = []
        var positions: [Double] = []
        for i in 0...count {
            let position = Double(i) / Double(count)
            let time = position * duration
            let phase = (time / period).truncatingRemainder(dividingBy: 1)
            let wave: Double
            if !blink {
                wave = minimum + (maximum - minimum) * (1 + cos(2 * .pi * phase)) / 2
            } else {
                let brightness: Double
                if phase < 0.1 { brightness = 1 }
                else if phase < 0.2 { brightness = 1 - ease((phase - 0.1) / 0.1) }
                else if phase < 0.8 { brightness = 0 }
                else { brightness = ease((phase - 0.8) / 0.2) }
                wave = minimum + (maximum - minimum) * brightness
            }
            let incoming = ease(time / entrance)
            let outgoing = ease((time - (duration - exit)) / exit)
            let entered = start + (wave - start) * incoming
            samples.append(entered + (1 - entered) * outgoing)
            positions.append(position)
        }
        // Exact equality with the model opacity prevents removal-time snapping.
        samples[0] = start; samples[count] = 1
        values = samples; times = positions
    }
}
