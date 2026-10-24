import Foundation

/// A crossfade window on the trigger's clock. Weight runs 0 → 1 for a fade-in and 1 → 0 for a fade-out.
public struct Fade: Equatable, Sendable {
    public var start: Double, length: Double, curve: TimingCurve, fadesIn: Bool
    public var end: Double { start + length }
    public func weight(at time: Double) -> Double {
        let u = min(max((time - start) / max(length, 1e-9), 0), 1), w = curve.value(at: u)
        return fadesIn ? w : 1 - w
    }
}

/// When each active entry runs, relative to the trigger. Focus entries chain through `EntryStart`;
/// continuous entries ignore it and keep their own clock.
public struct ScheduledEntry: Equatable, Sendable {
    public var entry: AnimationEntry
    /// Seconds after the trigger, including the entry's delay.
    public var begin: Double
    /// `.infinity` for continuous entries.
    public var end: Double
    public var fadeIn: Fade?
    public var fadeOut: Fade?
    public var fades: [Fade] { [fadeIn, fadeOut].compactMap { $0 } }
    /// Morph target side: the entry it morphs from, where that entry began, and the blend window.
    public var morphSource: (entry: AnimationEntry, begin: Double)?
    public var morph: Fade?
    /// Morph source side: the trigger time at which this entry hands over and stops.
    public var cut: Double?

    public static func == (a: Self, b: Self) -> Bool {
        a.entry == b.entry && a.begin == b.begin && a.end == b.end && a.fadeIn == b.fadeIn && a.fadeOut == b.fadeOut
            && a.morphSource?.entry == b.morphSource?.entry && a.morphSource?.begin == b.morphSource?.begin && a.morph == b.morph && a.cut == b.cut
    }
}

public enum AnimationSchedule {
    public static func make(_ entries: [AnimationEntry]) -> [ScheduledEntry] {
        var result: [ScheduledEntry] = []
        var previous: Int?
        for entry in entries.active {
            guard entry.trigger == .focus else { result.append(ScheduledEntry(entry: entry, begin: entry.delay, end: .infinity)); continue }
            let span = entry.duration * entry.repeats
            var scheduled = ScheduledEntry(entry: entry, begin: entry.delay, end: entry.delay + span)
            if let p = previous {
                let prior = result[p], priorSpan = prior.end - prior.begin
                switch entry.start {
                case .withPrevious: scheduled.begin = prior.begin + entry.delay
                case .afterPrevious: scheduled.begin = prior.end - min(entry.overlap, priorSpan) + entry.delay
                case .crossfade, .morph:
                    // The windows must line up for the weights to sum to 1, so crossfade and morph ignore the delay.
                    let length = min(entry.transition, priorSpan, span)
                    scheduled.begin = prior.end - length
                    if entry.start == .morph && prior.entry.canMorph(into: entry) {
                        scheduled.morph = Fade(start: scheduled.begin, length: length, curve: entry.transitionCurve, fadesIn: true)
                        scheduled.morphSource = (prior.entry, prior.begin)
                        result[p].cut = scheduled.begin
                    } else {
                        scheduled.fadeIn = Fade(start: scheduled.begin, length: length, curve: entry.transitionCurve, fadesIn: true)
                        result[p].fadeOut = Fade(start: scheduled.begin, length: length, curve: entry.transitionCurve, fadesIn: false)
                    }
                }
                scheduled.end = scheduled.begin + span
            }
            previous = result.count; result.append(scheduled)
        }
        return result
    }

    /// Seconds after a focus change until every focus entry has finished.
    public static func focusEnd(_ entries: [AnimationEntry]) -> Double {
        make(entries).map(\.end).filter(\.isFinite).max() ?? 0
    }
}

public extension AnimationTrack.Property {
    /// The value that shows no effect. Crossfades blend toward it; nil for positions, which their visibility already fades.
    var neutral: Double? {
        switch self {
        case .opacityMultiplier, .shadowBlurScale: 1
        case .accentOpacity, .rotation, .colorMix, .tightShadow, .reflectionOpacity: 0
        case .strokeEnd: 1
        case .dashTravel, .reflectionTravel: nil
        }
    }
}

public extension AnimationTrack {
    var span: Double { duration * repeatCount }

    /// The value `time` seconds after the track starts (delay excluded), following repeats and timings.
    func value(at time: Double) -> Double {
        let t = min(max(time, 0), span), local: Double
        // At the end a whole number of cycles stops at the cycle's last key; a fractional one stops mid-cycle.
        if t >= span { let rest = repeatCount - floor(repeatCount); local = rest == 0 ? 1 : rest }
        else { let cycle = t / duration; local = cycle - floor(cycle) }
        guard let next = keyTimes.firstIndex(where: { $0 >= local }), next > 0 else { return values[0] }
        let k0 = keyTimes[next - 1], k1 = keyTimes[next], u = k1 > k0 ? (local - k0) / (k1 - k0) : 1
        return values[next - 1] + (values[next] - values[next - 1]) * timings[next - 1].value(at: u)
    }

    /// The finite track unrolled into one cycle over its whole span, with `transform(seconds, value)` applied.
    /// Original segments outside `windows` keep their keyframes and timing; everything inside is sampled linearly.
    func unrolled(sampling windows: [ClosedRange<Double>], _ transform: (Double, Double) -> Double) -> AnimationTrack {
        precondition(span.isFinite, "Only finite tracks can be unrolled")
        let cycles = Int(ceil(repeatCount - 1e-9))
        var marks = Set<Double>()
        for c in 0..<max(cycles, 1) { for k in keyTimes { let t = (Double(c) + k) * duration; if t <= span + 1e-9 { marks.insert(min(t, span)) } } }
        marks.insert(0); marks.insert(span)
        for w in windows { for t in [w.lowerBound, w.upperBound] where (0...span).contains(t) { marks.insert(t) } }
        let sorted = marks.sorted()
        func inWindow(_ a: Double, _ b: Double) -> Bool { windows.contains { $0.lowerBound < b - 1e-9 && $0.upperBound > a + 1e-9 } }
        func originalTiming(_ a: Double, _ b: Double) -> TimingCurve? {
            // Adjacent original key times inside one cycle keep the segment's own timing.
            let ca = floor(a / duration + 1e-9), la = a / duration - ca, lb = b / duration - ca
            guard let i = keyTimes.firstIndex(where: { abs($0 - la) < 1e-9 }), i + 1 < keyTimes.count, abs(keyTimes[i + 1] - lb) < 1e-9 else { return nil }
            return timings[i]
        }
        var times = [0.0], values = [transform(0, value(at: 0))], segmentTimings: [TimingCurve] = []
        for (a, b) in zip(sorted, sorted.dropFirst()) where b - a > 1e-9 {
            if !inWindow(a, b), let timing = originalTiming(a, b) {
                times.append(b); values.append(transform(b, value(at: b))); segmentTimings.append(timing)
            } else {
                for step in 1...AnimationTrack.samplesPerSegment {
                    let t = a + (b - a) * Double(step) / Double(AnimationTrack.samplesPerSegment)
                    times.append(t); values.append(transform(t, value(at: t))); segmentTimings.append(.linear)
                }
            }
        }
        var result = self
        result.values = values; result.keyTimes = times.map { $0 / span }; result.timings = segmentTimings
        result.duration = span; result.repeatCount = 1
        return result
    }

    /// Blends toward the property's neutral value by the product of the crossfade weights. `fades` are on the trigger's clock.
    func weighted(by fades: [Fade]) -> AnimationTrack {
        guard !fades.isEmpty, span.isFinite, let neutral = property.neutral else { return self }
        let windows = fades.map { ($0.start - delay)...($0.end - delay) }
        return unrolled(sampling: windows) { t, v in
            let w = fades.reduce(1.0) { $0 * $1.weight(at: t + delay) }
            return neutral + (v - neutral) * w
        }
    }

    /// The track up to `seconds` after its start; Core Animation then removes it and the model value shows.
    func ending(at seconds: Double) -> AnimationTrack {
        guard span.isFinite, seconds < span else { return self }
        let full = unrolled(sampling: [0...seconds]) { _, v in v }, cut = seconds / full.duration
        var times: [Double] = [], values: [Double] = [], timings: [TimingCurve] = []
        for (i, k) in full.keyTimes.enumerated() where k <= cut + 1e-12 {
            times.append(k); values.append(full.values[i]); if i > 0 { timings.append(full.timings[i - 1]) }
        }
        var result = full
        result.keyTimes = times.map { $0 / cut }; result.values = values; result.timings = timings; result.duration = seconds
        return result
    }

    /// This track (the morph target) starting at the morph window: inside it, the value moves from `source` to this
    /// track's own value by the window's weight; afterwards it is this track. `sourceOffset` is the source's start
    /// relative to this track's start on the trigger clock.
    func morphed(from source: AnimationTrack, sourceOffset: Double, window: Fade) -> AnimationTrack {
        guard span.isFinite, source.span.isFinite else { return self }
        let length = window.length
        return unrolled(sampling: [0...length]) { t, v in
            let w = window.weight(at: t + delay), from = source.value(at: t - sourceOffset)
            return from + (v - from) * w
        }
    }

    /// Starts now at `current` (what is visible) instead of jumping. Without a delay the track blends into its own values
    /// over `seconds`. With a delay (a later step of a sequence) it eases to its first value, holds it, then plays;
    /// the result starts immediately (delay 0) and spans delay + track.
    func handingOff(from current: Double, over seconds: Double = 0.15) -> AnimationTrack {
        let start = value(at: 0), lead = max(delay, 0)
        guard span.isFinite, abs(current - start) > 1e-6 else { return self }
        let length = min(seconds, lead > 0 ? lead : span)
        func ease(_ t: Double) -> Double { TimingCurve.easeInOut.value(at: min(t / length, 1)) }
        guard lead > 0 else { return unrolled(sampling: [0...length]) { t, v in v + (current - start) * (1 - ease(t)) } }
        let body = unrolled(sampling: []) { _, v in v }, n = AnimationTrack.samplesPerSegment
        var times = [0.0], values = [current], segmentTimings: [TimingCurve] = []
        for i in 1...n { let t = length * Double(i) / Double(n); times.append(t); values.append(current + (start - current) * ease(t)); segmentTimings.append(.linear) }
        if lead > length { times.append(lead); values.append(start); segmentTimings.append(.linear) }
        for (k, v) in zip(body.keyTimes.dropFirst(), body.values.dropFirst()) { times.append(lead + k * span); values.append(v) }
        segmentTimings += body.timings
        var result = self, total = lead + span
        result.values = values; result.keyTimes = times.map { $0 / total }; result.timings = segmentTimings
        result.duration = total; result.repeatCount = 1; result.delay = 0
        return result
    }
}
