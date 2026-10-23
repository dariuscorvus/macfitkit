import FolderIconerCore
import SwiftUI

struct EditorWindow: View {
    @Bindable var model: EditorModel
    let applying: ApplyController
    @Environment(\.undoManager) private var undoManager
    @State private var showsInspector = true

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) { LayerListView(model: model); AppliedFoldersView(applying: applying) }
                .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
        } detail: {
            VStack(spacing: 0) {
                CanvasView(model: model).padding(16)
                Divider()
                PreviewStrip(model: model)
            }
            .frame(minWidth: 520)
            .safeAreaInset(edge: .top, spacing: 0) { ApplyBanner(applying: applying) }
            .inspector(isPresented: $showsInspector) { InspectorView(model: model).inspectorColumnWidth(min: 260, ideal: 300, max: 400) }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                AddLayerMenu(model: model)
                ApplyButton(applying: applying)
                Button { showsInspector.toggle() } label: { Label("Inspector", systemImage: "sidebar.trailing") }.help(Text("Show or hide the inspector"))
            }
        }
        .navigationTitle(Text("FolderIconer"))
        .modifier(ApplyAlerts(applying: applying))
        .environment(applying)
        .onAppear { model.undoManager = undoManager }
        .onChange(of: undoManager) { model.undoManager = undoManager }
        .alert(Text("Could Not Add Image"), isPresented: Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { if let alert = model.alert { Text(alert) } }
    }
}

struct AddLayerMenu: View {
    let model: EditorModel
    var body: some View {
        Menu {
            Button("Add Image…") { model.chooseImage() }
            Button("Add Text") { model.addText() }
            Button("Add Emoji") { model.addEmoji() }
        } label: { Label("Add Layer", systemImage: "plus") }
        .help(Text("Add a layer above the selection"))
    }
}
