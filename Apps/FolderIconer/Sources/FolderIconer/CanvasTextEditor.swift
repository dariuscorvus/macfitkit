import AppKit
import FolderIconerCore
import SwiftUI

/// Inline text editing on the canvas. The field's glyphs are clear, so the live canvas render shows the real text with its effects;
/// only the caret and the selection come from the field.
struct CanvasTextEditor: View {
    let model: EditorModel, layer: Layer, contentSize: CGSize, side: CGFloat

    var body: some View {
        let t = layer.transform, text = layer.text
        let box = CanvasGeometry.textEditorBox(layer, text: text, contentSize: contentSize, side: side)
        InlineTextView(string: text.string, font: text.font(points: box.fontPoints), kern: text.tracking * box.fontPoints,
                       change: { model.editText($0) }, finish: { model.endTextEditing(cancel: $0) })
            .frame(width: box.size.width, height: box.size.height)
            .scaleEffect(x: t.flipX ? -1 : 1, y: t.flipY ? -1 : 1)
            .rotationEffect(.degrees(t.rotation))
            .position(box.center)
            .accessibilityLabel(Text("Edit Text"))
    }
}

/// An `NSTextView` for the inline editor: Return commits, Option-Return adds a line, Escape cancels, losing focus commits.
private struct InlineTextView: NSViewRepresentable {
    let string: String, font: NSFont, kern: CGFloat
    let change: (String) -> Void, finish: (_ cancelled: Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextView {
        let view = NSTextView()
        view.isRichText = false; view.drawsBackground = false; view.allowsUndo = true
        view.textContainerInset = .zero; view.textContainer?.lineFragmentPadding = 0
        view.isAutomaticQuoteSubstitutionEnabled = false; view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false; view.isContinuousSpellCheckingEnabled = false
        view.insertionPointColor = .controlAccentColor
        view.string = string; apply(to: view)
        view.delegate = context.coordinator
        // The view has no window until SwiftUI mounts it.
        DispatchQueue.main.async { view.window?.makeFirstResponder(view); view.selectAll(nil) }
        return view
    }

    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.parent = self
        // Font, size and tracking can change from the inspector while editing. Skip during IME composition.
        if !view.hasMarkedText() { apply(to: view) }
    }

    private func apply(to view: NSTextView) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .kern: kern, .foregroundColor: NSColor.clear, .paragraphStyle: paragraph]
        view.typingAttributes = attributes
        if let storage = view.textStorage { storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length)) }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InlineTextView
        private var finished = false
        // Typing undo stays inside the field; the document gets one "Change Text" step when the edit ends.
        private let undo = UndoManager()
        init(_ parent: InlineTextView) { self.parent = parent }

        func undoManager(for view: NSTextView) -> UndoManager? { undo }
        func textDidChange(_ notification: Notification) {
            if let view = notification.object as? NSTextView { parent.change(view.string) }
        }
        func textView(_ view: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)): end(cancelled: false); return true
            case #selector(NSResponder.cancelOperation(_:)): end(cancelled: true); return true
            case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): view.insertText("\n", replacementRange: view.selectedRange()); return true
            default: return false
            }
        }
        func textDidEndEditing(_ notification: Notification) { end(cancelled: false) }
        private func end(cancelled: Bool) { guard !finished else { return }; finished = true; parent.finish(cancelled) }
    }
}
