import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI

/// Picks and shapes a timing curve: a searchable list of named curves, a diagram with live playback,
/// draggable Bézier handles and the spring's parameters.
struct TimingCurveEditor: View {
    let curve: TimingCurve
    let set: (TimingCurve) -> Void
    @State private var search = ""
    /// A custom Bézier starts from CSS "ease", which matches none of the named curves.
    static let customStart = TimingCurve.bezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)

    var body: some View {
        HStack(alignment: .top, spacing: KitSpacing.medium) {
            VStack(alignment: .leading, spacing: KitSpacing.small) {
                TextField("Kurven suchen", text: $search).textFieldStyle(.roundedBorder)
                ScrollViewReader { scroller in
                    List(selection: Binding(get: { curve.listEntry }, set: { if let picked = $0 { set(picked) } })) {
                        ForEach(Self.groups(matching: search), id: \.title) { group in
                            Section(group.title) { ForEach(group.curves, id: \.self) { Text($0.title).tag($0).id($0) } }
                        }
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: false))
                    .onAppear { scroller.scrollTo(curve.listEntry, anchor: .center) }
                }
            }
            .frame(width: 200, height: 300)
            VStack(alignment: .leading, spacing: KitSpacing.small) {
                Text(curve.title).font(.headline)
                CurveDiagram(curve: curve, set: set).frame(width: 280, height: 220)
                PlaybackTrack(curve: curve).frame(width: 280, height: 20)
                if case .spring(let damping, let response) = curve {
                    SliderRow("Dämpfung", value: Binding(get: { damping * 100 }, set: { set(.spring(damping: $0 / 100, response: response)) }), in: 5...100, unit: "%")
                    SliderRow("Schwingdauer", value: Binding(get: { response * 100 }, set: { set(.spring(damping: damping, response: $0 / 100)) }), in: 5...100, unit: "%")
                    Text("Schwingdauer in Prozent der Animationsdauer. Die Feder endet immer genau am Ziel.").font(.caption).foregroundStyle(.secondary)
                } else if case .bezier = curve {
                    Text("Die beiden Griffe ziehen. Höher als 1 oder tiefer als 0 ergibt ein Überschwingen.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 280)
        }
    }

    struct Group { let title: String; let curves: [TimingCurve] }

    static func groups(matching query: String) -> [Group] {
        let all = [Group(title: "Grundlagen", curves: [.linear, .easeIn, .easeOut, .easeInOut])]
            + EasingFamily.allCases.map { family in Group(title: family.title, curves: EasingDirection.allCases.map { .family(family, $0) }) }
            + [Group(title: "Eigene", curves: [.defaultSpring, customStart])]
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.compactMap { group in
            let hits = group.title.lowercased().contains(q) ? group.curves : group.curves.filter { $0.title.lowercased().contains(q) }
            return hits.isEmpty ? nil : Group(title: group.title, curves: hits)
        }
    }
}

/// Time on x, progress on y. The dashed lines mark 0 and 1; the drawing area grows to show overshoot.
private struct CurveDiagram: View {
    let curve: TimingCurve
    let set: (TimingCurve) -> Void
    /// The scale stays fixed while a handle is dragged. Re-scaling mid-drag would map the same pointer to ever larger values.
    @State private var dragFrame: DiagramFrame?
    private static let inset: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            let frame = dragFrame ?? DiagramFrame(curve: curve, size: proxy.size, inset: Self.inset)
            ZStack {
                TimelineView(.animation) { timeline in
                    Canvas { context, _ in draw(in: &context, frame: frame, time: PlaybackTrack.time(timeline.date)) }
                }
                if case .bezier(let x1, let y1, let x2, let y2) = curve {
                    handle(frame, at: (x1, y1), from: (0, 0)) { set(.bezier(x1: $0, y1: $1, x2: x2, y2: y2).normalized) }
                    handle(frame, at: (x2, y2), from: (1, 1)) { set(.bezier(x1: x1, y1: y1, x2: $0, y2: $1).normalized) }
                }
            }
            .coordinateSpace(.named("diagram"))
        }
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kurvendiagramm: \(curve.title)")
    }

    private func draw(in context: inout GraphicsContext, frame: DiagramFrame, time: Double) {
        var guides = Path()
        for v in [0.0, 1.0] { guides.move(to: frame.point(0, v)); guides.addLine(to: frame.point(1, v)) }
        for t in [0.0, 1.0] { guides.move(to: frame.point(t, frame.low)); guides.addLine(to: frame.point(t, frame.high)) }
        context.stroke(guides, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        var line = Path(); line.move(to: frame.point(0, 0))
        for i in 1...240 { let t = Double(i) / 240; line.addLine(to: frame.point(t, curve.value(at: t))) }
        context.stroke(line, with: .color(.accentColor), lineWidth: 2)
        let dot = frame.point(time, curve.value(at: time))
        context.fill(Path(ellipseIn: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8)), with: .color(.accentColor))
        context.draw(Text("Zeit").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: frame.point(1, 0).x - 14, y: frame.point(0, frame.low).y + 8))
        context.draw(Text("1").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: frame.point(0, 1).x - 7, y: frame.point(0, 1).y))
        context.draw(Text("0").font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: frame.point(0, 0).x - 7, y: frame.point(0, 0).y))
    }

    private func handle(_ frame: DiagramFrame, at control: (Double, Double), from anchor: (Double, Double), moved: @escaping (Double, Double) -> Void) -> some View {
        let point = frame.point(control.0, control.1)
        return ZStack {
            Path { $0.move(to: frame.point(anchor.0, anchor.1)); $0.addLine(to: point) }.stroke(Color.secondary, lineWidth: 1)
            Circle().fill(Color(nsColor: .controlBackgroundColor)).overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                .frame(width: 14, height: 14).position(point)
                .gesture(DragGesture(coordinateSpace: .named("diagram"))
                    .onChanged { value in
                        if dragFrame == nil { dragFrame = frame }
                        let c = (dragFrame ?? frame).curvePoint(value.location); moved(c.t, c.v)
                    }
                    .onEnded { _ in dragFrame = nil })
        }
    }
}

/// Maps curve coordinates to view points. The visible value range covers 0…1 plus any overshoot, with a margin.
private struct DiagramFrame {
    let size: CGSize, inset: CGFloat, low: Double, high: Double

    init(curve: TimingCurve, size: CGSize, inset: CGFloat) {
        var range = curve.range()
        if case .bezier(_, let y1, _, let y2) = curve { range = min(range.lowerBound, y1, y2)...max(range.upperBound, y1, y2) }
        self.size = size; self.inset = inset
        low = min(0, range.lowerBound) - 0.1; high = max(1, range.upperBound) + 0.1
    }

    func point(_ t: Double, _ v: Double) -> CGPoint {
        CGPoint(x: inset + t * (size.width - 2 * inset), y: size.height - inset - (v - low) / (high - low) * (size.height - 2 * inset))
    }

    /// The inverse of `point`: curve coordinates under a view location.
    func curvePoint(_ p: CGPoint) -> (t: Double, v: Double) {
        ((p.x - inset) / max(size.width - 2 * inset, 1), low + (size.height - inset - p.y) / max(size.height - 2 * inset, 1) * (high - low))
    }
}

/// A ball moving along a track as the curve plays, so the motion itself is visible. The track spans 0…1;
/// the view reserves room on both sides for overshoot, so the ball runs past the track ends but stays visible.
private struct PlaybackTrack: View {
    let curve: TimingCurve
    /// 1.6 s per loop: 1.2 s of motion, then a short rest at the end.
    static func time(_ date: Date) -> Double { min(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.2, 1) }

    var body: some View {
        let range = curve.range(), low = min(0, range.lowerBound), high = max(1, range.upperBound)
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let x = { (v: Double) in 10 + (v - low) / (high - low) * (proxy.size.width - 20) }, y = proxy.size.height / 2
                ZStack {
                    Path { $0.move(to: CGPoint(x: x(0), y: y)); $0.addLine(to: CGPoint(x: x(1), y: y)) }
                        .stroke(.quaternary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    Circle().fill(Color.accentColor).frame(width: 14, height: 14).position(x: x(curve.value(at: Self.time(timeline.date))), y: y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension EasingFamily {
    var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

extension EasingDirection {
    var title: String { switch self { case .in: "In"; case .out: "Out"; case .inOut: "In Out" } }
}

extension TimingCurve {
    var title: String {
        switch self {
        case .linear: "Linear"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In Out"
        case .family(let family, let direction): "\(family.title) \(direction.title)"
        case .spring: "Feder"
        case .bezier: "Eigene Bézier-Kurve"
        }
    }

    /// The list row that represents this curve: a spring with any parameters selects "Feder", any custom Bézier "Eigene Bézier-Kurve".
    var listEntry: TimingCurve {
        switch self {
        case .spring: .defaultSpring
        case .bezier where ![TimingCurve.easeIn, .easeOut, .easeInOut].contains(self): TimingCurveEditor.customStart
        default: self
        }
    }
}
