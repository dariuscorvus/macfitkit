import FolderIconerCore
import SwiftUI

/// Properties of the selected layer: the common section, then one section per content kind.
struct InspectorView: View {
    let model: EditorModel

    var body: some View {
        if let layer = model.selectedLayer {
            Form {
                if layer.locked { Section { Label("This layer is locked. Unlock it in the layer list to edit it.", systemImage: "lock.fill").foregroundStyle(.secondary) } }
                Group {
                    LayerSection(model: model, layer: layer)
                    ContentInspector(model: model, layer: layer)
                    EffectsInspector(model: model, layer: layer)
                }
                .disabled(layer.locked)
            }
            .formStyle(.grouped)
            .id(layer.id)
        } else {
            ContentUnavailableView { Label("No Layer Selected", systemImage: "square.stack.3d.up") } description: { Text("Select a layer on the canvas or in the layer list.") }
        }
    }
}

/// Name, opacity, blend mode, transform, folder clip and the small-size cut-off: shared by every kind.
struct LayerSection: View {
    let model: EditorModel, layer: Layer
    static let hideBelowSizes = [16, 32, 64, 128, 256]

    var body: some View {
        Section("Layer") {
            CommitTextField(title: "Name", value: layer.name) { name in model.edit("Rename Layer") { $0[layer: layer.id]?.name = name } }
            SliderRow(title: "Opacity", value: model.binding(layer, \.opacity, "Change Opacity").scaled(100), range: 0...100,
                      format: .number.precision(.fractionLength(0)), editingChanged: model.editingChanged("Change Opacity"))
            Picker("Blend Mode", selection: model.binding(layer, \.blendMode, "Change Blend Mode")) {
                ForEach(LayerBlendMode.allCases, id: \.self) { Text($0.title).tag($0) }
            }
        }
        Section("Position") {
            NumberRow(title: "X", value: model.binding(layer, \.transform.x, "Move Layer").scaled(100), unit: "%")
            NumberRow(title: "Y", value: model.binding(layer, \.transform.y, "Move Layer").scaled(100), unit: "%")
            NumberRow(title: "Scale", value: model.binding(layer, \.transform.scale, "Scale Layer").scaled(100), unit: "%")
            NumberRow(title: "Rotation", value: model.binding(layer, \.transform.rotation, "Rotate Layer"), unit: "°")
            Toggle("Flip Horizontally", isOn: model.binding(layer, \.transform.flipX, "Flip Layer"))
            Toggle("Flip Vertically", isOn: model.binding(layer, \.transform.flipY, "Flip Layer"))
            if !layer.content.isFolderBase { Toggle("Clip to Folder", isOn: model.binding(layer, \.clipToFolder, "Clip to Folder")) }
            Picker("Hide Below", selection: model.binding(layer, \.hideBelowSize, "Change Hide Below")) {
                Text("Off").tag(Int?.none)
                ForEach(Self.hideBelowSizes, id: \.self) { Text("\($0) pt").tag(Int?.some($0)) }
            }
            .help(Text("Leave this layer out of icon sizes smaller than the chosen size."))
        }
    }
}
