import FolderIconerCore
import SwiftUI

/// The layer stack, top layer first.
struct LayerListView: View {
    @Bindable var model: EditorModel

    var body: some View {
        List(selection: $model.selection) {
            Section {
                ForEach(Array(model.document.layers.reversed())) { layer in
                    LayerRow(model: model, layer: layer).tag(layer.id)
                        .contextMenu {
                            Button("Duplicate") { model.selection = layer.id; model.duplicateSelection() }.disabled(layer.content.isFolderBase)
                            Button("Delete") { model.selection = layer.id; model.deleteSelection() }
                        }
                }
                .onMove { model.moveDisplayed($0, $1) }
            } header: { Text("Layers") }
        }
        .onDeleteCommand { model.deleteSelection() }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                AddLayerMenu(model: model).menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Button { model.duplicateSelection() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.disabled(!model.canDuplicate)
                Button { model.deleteSelection() } label: { Label("Delete", systemImage: "trash") }.disabled(model.selection == nil)
            }
            .labelStyle(.iconOnly).buttonStyle(.borderless).padding(8)
        }
    }
}

struct LayerRow: View {
    let model: EditorModel, layer: Layer

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: layer.content.symbolName).frame(width: 18).foregroundStyle(.secondary)
                .accessibilityLabel(Text(layer.content.kindTitle))
            Text(layer.name).lineLimit(1).truncationMode(.middle).foregroundStyle(layer.visible ? .primary : .secondary)
            if let warning = layer.renderWarning { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).help(Text(warning)) }
            Spacer(minLength: 4)
            Button { model.edit(layer.locked ? "Unlock Layer" : "Lock Layer") { $0[layer: layer.id]?.locked.toggle() } } label: {
                Label(layer.locked ? "Unlock Layer" : "Lock Layer", systemImage: layer.locked ? "lock.fill" : "lock.open")
            }
            .opacity(layer.locked ? 1 : 0.4)
            Button { model.edit(layer.visible ? "Hide Layer" : "Show Layer") { $0[layer: layer.id]?.visible.toggle() } } label: {
                Label(layer.visible ? "Hide Layer" : "Show Layer", systemImage: layer.visible ? "eye" : "eye.slash")
            }
        }
        .buttonStyle(.borderless).labelStyle(.iconOnly)
    }
}
