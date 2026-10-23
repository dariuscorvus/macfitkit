import AppKit
import FolderIconerCore
import SwiftUI

struct TextInspector: View {
    let model: EditorModel, layer: Layer
    private static let families = NSFontManager.shared.availableFontFamilies
    private var text: TextContent { layer.text }

    var body: some View {
        Section("Text") {
            CommitTextField(title: "Text", value: text.string, axis: .vertical) { string in model.edit("Change Text") { $0[layer: layer.id]?.text.string = string } }
                .lineLimit(1...4)
            Picker("Font", selection: model.binding(layer, \.text.fontFamily, "Change Font")) {
                Text("System").tag(String?.none)
                Divider()
                ForEach(Self.families, id: \.self) { Text(verbatim: $0).tag(String?.some($0)) }
            }
            Picker("Weight", selection: model.binding(layer, \.text.weight, "Change Weight")) {
                ForEach(FontWeight.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            SliderRow(title: "Size", value: model.binding(layer, \.text.size, "Resize Text").scaled(100), range: 2...50,
                      format: .number.precision(.fractionLength(0...1)), editingChanged: model.editingChanged("Resize Text"))
            SliderRow(title: "Tracking", value: model.binding(layer, \.text.tracking, "Change Tracking"), range: -0.1...0.5, editingChanged: model.editingChanged("Change Tracking"))
        }
        Section("Fill") {
            Picker("Fill", selection: model.binding(layer, \.text.fill.isGradient, "Change Fill")) {
                Text("Solid").tag(false)
                Text("Gradient").tag(true)
            }
            .pickerStyle(.segmented)
            if text.fill.isGradient {
                ColorPicker("Start Color", selection: model.binding(layer, \.text.fill.startColor, "Change Gradient", coalesce: true).cgColor)
                ColorPicker("End Color", selection: model.binding(layer, \.text.fill.endColor, "Change Gradient", coalesce: true).cgColor)
                SliderRow(title: "Angle", value: model.binding(layer, \.text.fill.angle, "Change Gradient Angle"), range: -180...180,
                          format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Change Gradient Angle"))
            } else {
                ColorPicker("Color", selection: model.binding(layer, \.text.fill.startColor, "Change Text Color", coalesce: true).cgColor)
            }
        }
    }
}

/// Inspector view of `Fill`: a solid colour or a two-stop gradient. Switching keeps the first colour.
extension Fill {
    var isGradient: Bool {
        get { if case .linear = self { true } else { false } }
        set {
            guard newValue != isGradient else { return }
            self = newValue ? .linear(stops: [GradientStop(color: startColor, location: 0), GradientStop(color: .black, location: 1)], angle: 90) : .solid(startColor)
        }
    }
    var startColor: RGBAColor {
        get { switch self { case .solid(let color): color; case .linear(let stops, _): stops.first?.color ?? .white } }
        set { switch self { case .solid: self = .solid(newValue); case .linear(let stops, let angle): self = .linear(stops: Self.twoStops(stops, start: newValue), angle: angle) } }
    }
    var endColor: RGBAColor {
        get { if case .linear(let stops, _) = self { stops.last?.color ?? .black } else { startColor } }
        set { if case .linear(let stops, let angle) = self { self = .linear(stops: Self.twoStops(stops, end: newValue), angle: angle) } }
    }
    var angle: Double {
        get { if case .linear(_, let angle) = self { angle } else { 0 } }
        set { if case .linear(let stops, _) = self { self = .linear(stops: stops, angle: newValue) } }
    }
    private static func twoStops(_ stops: [GradientStop], start: RGBAColor? = nil, end: RGBAColor? = nil) -> [GradientStop] {
        [GradientStop(color: start ?? stops.first?.color ?? .white, location: 0), GradientStop(color: end ?? stops.last?.color ?? .black, location: 1)]
    }
}
