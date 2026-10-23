import AppKit
import SwiftUI
import FocusFrameCore
import MacFitKitUI

/// The gradient as a strip with one handle per stop. A click on the strip adds a stop, dragging a handle moves it,
/// and the selected stop's color and position are edited below.
struct GradientStopEditor: View {
    let gradient: GradientEffect
    let set: (GradientEffect) -> Void
    @State private var selected = 0
    @State private var dragged: Int?
    private static let strip: CGFloat = 28, handle: CGFloat = 16

    var body: some View {
        let stops = gradient.stops, index = min(selected, stops.count - 1)
        VStack(alignment: .leading, spacing: KitSpacing.small) {
            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(stops: stops.map { .init(color: Color(nsColor: $0.color.nsColor), location: $0.location) }, startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                        .frame(height: Self.strip)
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .named("strip")) { add(at: $0.x / width) }
                        .accessibilityLabel("Farbverlauf")
                        .accessibilityHint("Klicken fügt an dieser Stelle einen Farbpunkt hinzu.")
                    ForEach(stops.indices, id: \.self) { i in
                        StopHandle(color: stops[i].color, selected: i == index)
                            .frame(width: Self.handle, height: Self.handle)
                            .position(x: stops[i].location * width, y: Self.strip + Self.handle / 2 + 2)
                            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("strip"))
                                .onChanged { dragged = move(dragged ?? i, to: $0.location.x / width) }
                                .onEnded { _ in dragged = nil })
                            .accessibilityElement()
                            .accessibilityLabel("Farbpunkt \(i + 1) von \(stops.count), \(Int((stops[i].location * 100).rounded())) %")
                            .accessibilityAddTraits(i == index ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { selected = i }
                    }
                }
                .coordinateSpace(.named("strip"))
            }
            .frame(height: Self.strip + Self.handle + 4)
            Text("Auf den Verlauf klicken fügt einen Farbpunkt hinzu. Punkte zum Verschieben ziehen.").font(.caption).foregroundStyle(.secondary)
            HStack {
                ColorPicker("Farbe von Punkt \(index + 1)", selection: Binding(get: { Color(nsColor: stops[index].color.nsColor) }, set: { color in
                    guard let c = NSColor(color).usingColorSpace(.sRGB) else { return }
                    update { $0.stops[index].color = EffectColor(c.redComponent, c.greenComponent, c.blueComponent) }
                }), supportsOpacity: false)
                Spacer()
                Button("Punkt entfernen") { remove(index) }.disabled(stops.count <= GradientEffect.minimumStops)
            }
            SliderRow("Position", value: Binding(get: { stops[index].location * 100 }, set: { move(index, to: $0 / 100) }), in: 0...100, unit: "%")
            if gradient.mode == .conic && !gradient.isSeamClosed {
                HStack {
                    Text("Der letzte Punkt endet in einer anderen Farbe als der erste. Am Startwinkel entsteht eine harte Kante.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Naht schließen") { update { $0.closeSeam() } }
                }
            }
        }
    }

    /// Applies a change to the normalized (sorted) gradient and returns where stop `index` ended up.
    @discardableResult private func update(tracking index: Int? = nil, _ change: (inout GradientEffect) -> Void) -> Int? {
        var g = gradient; change(&g)
        let moved = index.map { g.stops[$0] }, n = g.normalized
        set(n)
        return moved.flatMap { n.stops.firstIndex(of: $0.normalizedStop) }
    }

    private func add(at location: Double) {
        let x = min(max(location, 0), 1), stop = GradientStop(gradient.color(at: x), at: x)
        if let i = update(tracking: gradient.stops.count, { $0.stops.append(stop) }) { selected = i }
    }

    /// While dragging, a stop can pass its neighbours; the sorted index follows it so the drag keeps the same stop.
    @discardableResult private func move(_ index: Int, to location: Double) -> Int {
        guard gradient.stops.indices.contains(index) else { return index }
        let i = update(tracking: index) { $0.stops[index].location = min(max(location, 0), 1) } ?? index
        selected = i; return i
    }

    private func remove(_ index: Int) {
        guard gradient.stops.count > GradientEffect.minimumStops else { return }
        update { $0.stops.remove(at: index) }; selected = max(0, index - 1)
    }
}

private extension GradientStop {
    var normalizedStop: GradientStop { GradientStop(color.normalized, at: min(max(location, 0), 1)) }
}

private struct StopHandle: View {
    let color: EffectColor, selected: Bool
    var body: some View {
        Circle().fill(Color(nsColor: color.nsColor))
            .overlay(Circle().stroke(selected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: selected ? 3 : 1))
            .shadow(radius: 1)
    }
}
