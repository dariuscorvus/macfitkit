import FolderIconerCore
import SwiftUI

/// A slider whose drag is one undo step, with the value shown next to it.
struct SliderRow: View {
    let title: LocalizedStringResource
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...2))
    let editingChanged: (Bool) -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                Slider(value: $value, in: range, onEditingChanged: editingChanged).labelsHidden()
                TextField(value: $value, format: format) { Text(title) }.labelsHidden().frame(width: 52).multilineTextAlignment(.trailing)
            }
        } label: { Text(title) }
    }
}

/// A number field that commits on Return or when it loses focus.
struct NumberRow: View {
    let title: LocalizedStringResource
    @Binding var value: Double
    var unit: LocalizedStringResource?

    var body: some View {
        LabeledContent {
            HStack(spacing: 4) {
                TextField(value: $value, format: .number.precision(.fractionLength(0...2))) { Text(title) }.labelsHidden().multilineTextAlignment(.trailing)
                if let unit { Text(unit).foregroundStyle(.secondary) }
            }
        } label: { Text(title) }
    }
}

/// Text editing that becomes one undo step on Return or focus loss, not one per keystroke.
struct CommitTextField: View {
    let title: LocalizedStringResource
    let value: String
    var axis: Axis = .horizontal
    let commit: (String) -> Void
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(text: $draft, axis: axis) { Text(title) }
            .focused($focused)
            .onSubmit { commit(draft) }
            .onAppear { draft = value }
            .onChange(of: value) { if !focused { draft = value } }
            .onChange(of: focused) { if !focused && draft != value { commit(draft) } }
            .onDisappear { if draft != value { commit(draft) } }
    }
}
