import AppKit
import FolderIconerCore
import SwiftUI

struct SymbolInspector: View {
    let model: EditorModel, layer: Layer
    private static let symbolsApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.SFSymbols")
    private var symbol: SymbolContent { layer.symbol }

    var body: some View {
        Section {
            CommitTextField(title: "Name", value: symbol.name) { name in
                model.edit("Change Symbol") { $0[layer: layer.id]?.symbol.name = name.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            if let app = Self.symbolsApp { LabeledContent("Browse") { Button("Open SF Symbols") { NSWorkspace.shared.open(app) } } }
            SliderRow(title: "Size", value: model.binding(layer, \.symbol.size, "Resize Symbol").scaled(100), range: 5...100,
                      format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Resize Symbol"))
            Picker("Weight", selection: model.binding(layer, \.symbol.weight, "Change Weight")) {
                ForEach(FontWeight.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Rendering", selection: model.binding(layer, \.symbol.rendering, "Change Rendering")) {
                ForEach(SymbolContent.Rendering.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            switch symbol.rendering {
            case .monochrome, .hierarchical: colorPicker("Color", 0)
            case .palette: colorPicker("Primary Color", 0); colorPicker("Secondary Color", 1); colorPicker("Tertiary Color", 2)
            case .multicolor: EmptyView()
            }
        } header: { Text("Symbol") } footer: {
            if let warning = layer.renderWarning { Label { Text(warning) } icon: { Image(systemName: "exclamationmark.triangle.fill") }.foregroundStyle(.orange) }
            else { Text("Enter a name from the SF Symbols app, for example star.fill.").foregroundStyle(.secondary) }
        }
    }

    private func colorPicker(_ title: LocalizedStringResource, _ index: Int) -> some View {
        ColorPicker(selection: model.binding(layer, \.symbol[color: index], "Change Symbol Color", coalesce: true).cgColor) { Text(title) }
    }
}

struct VectorInspector: View {
    let model: EditorModel, layer: Layer

    var body: some View {
        Section {
            LabeledContent("Source") { Button("Replace…") { model.chooseVector(replacing: layer.id) } }
            NumberRow(title: "Width", value: model.binding(layer, \.vector.size.width, "Resize Vector").scaled(100), unit: "%")
            NumberRow(title: "Height", value: model.binding(layer, \.vector.size.height, "Resize Vector").scaled(100), unit: "%")
        } header: { Text("Vector") } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let warning = layer.renderWarning { Label { Text(warning) } icon: { Image(systemName: "exclamationmark.triangle.fill") }.foregroundStyle(.orange) }
                if layer.vector.format == .svg {
                    Text("SVG filter effects can render differently than in a browser. Use layer effects for shadows and glows.").foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ShapeInspector: View {
    let model: EditorModel, layer: Layer
    private var shape: ShapeContent { layer.shape }

    var body: some View {
        Section("Shape") {
            Picker("Shape", selection: model.binding(layer, \.shape.kind, "Change Shape")) {
                ForEach(ShapeContent.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            NumberRow(title: "Width", value: model.binding(layer, \.shape.size.width, "Resize Shape").scaled(100), unit: "%")
            NumberRow(title: "Height", value: model.binding(layer, \.shape.size.height, "Resize Shape").scaled(100), unit: "%")
            if shape.kind == .roundedRectangle {
                SliderRow(title: "Corner Radius", value: model.binding(layer, \.shape.cornerRadius, "Change Corner Radius").scaled(100), range: 0...50,
                          format: .number.precision(.fractionLength(0...1)), editingChanged: model.editingChanged("Change Corner Radius"))
            }
        }
        Section("Fill") {
            Picker("Fill", selection: model.binding(layer, \.shape.fill.isGradient, "Change Fill")) {
                Text("Solid").tag(false)
                Text("Gradient").tag(true)
            }
            .pickerStyle(.segmented)
            if shape.fill.isGradient {
                ColorPicker("Start Color", selection: model.binding(layer, \.shape.fill.startColor, "Change Gradient", coalesce: true).cgColor)
                ColorPicker("End Color", selection: model.binding(layer, \.shape.fill.endColor, "Change Gradient", coalesce: true).cgColor)
                SliderRow(title: "Angle", value: model.binding(layer, \.shape.fill.angle, "Change Gradient Angle"), range: -180...180,
                          format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Change Gradient Angle"))
            } else {
                ColorPicker("Color", selection: model.binding(layer, \.shape.fill.startColor, "Change Fill Color", coalesce: true).cgColor)
            }
        }
        Section("Stroke") {
            Toggle("Stroke", isOn: model.binding(layer, \.shape.strokeEnabled, "Change Stroke"))
            if shape.stroke != nil {
                ColorPicker("Color", selection: model.binding(layer, \.shape.strokeColor, "Change Stroke", coalesce: true).cgColor)
                SliderRow(title: "Width", value: model.binding(layer, \.shape.strokeWidth, "Change Stroke").scaled(100), range: 0...5,
                          format: .number.precision(.fractionLength(0...1)), editingChanged: model.editingChanged("Change Stroke"))
            }
        }
    }
}

extension SymbolContent {
    private static let defaultColors: [RGBAColor] = [.white, RGBAColor(r: 1, g: 0.6, b: 0.15), .black]
    /// Missing palette slots read as defaults and are filled in when set.
    subscript(color index: Int) -> RGBAColor {
        get { index < colors.count ? colors[index] : Self.defaultColors[min(index, 2)] }
        set { while colors.count <= index { colors.append(Self.defaultColors[min(colors.count, 2)]) }; colors[index] = newValue }
    }
}

extension ShapeContent {
    var strokeEnabled: Bool {
        get { stroke != nil }
        set { stroke = newValue ? (stroke ?? Stroke(color: .black, width: 0.01)) : nil }
    }
    var strokeColor: RGBAColor {
        get { stroke?.color ?? .black }
        set { stroke?.color = newValue }
    }
    var strokeWidth: Double {
        get { stroke?.width ?? 0.01 }
        set { stroke?.width = newValue }
    }
}
