import AppKit
import SwiftUI

@main struct FolderIconerApp: App {
    @NSApplicationDelegateAdaptor(FolderIconerAppDelegate.self) private var delegate
    var body: some Scene {
        Window("FolderIconer", id: EditorCommands.editorWindowID) { EditorWindow(model: delegate.model) }
            .defaultSize(width: 1180, height: 800)
            .commands { EditorCommands(model: delegate.model) }
    }
}

@MainActor final class FolderIconerAppDelegate: NSObject, NSApplicationDelegate {
    let model = EditorModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        if model.isPreview { UIPreview.present() }
    }
    /// The editor window reopens from the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.saveDraft() }
}

struct EditorCommands: Commands {
    static let editorWindowID = "editor"
    let model: EditorModel
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(before: .windowList) { Button("Editor") { openWindow(id: Self.editorWindowID) }.keyboardShortcut("0") }
        CommandGroup(replacing: .newItem) { Button("New Icon") { model.newIcon() }.keyboardShortcut("n") }
        CommandMenu("Layer") {
            Button("Add Image…") { model.chooseImage() }.keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Add Text") { model.addText() }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Add Emoji") { model.addEmoji() }.keyboardShortcut("e", modifiers: [.command, .shift])
            Divider()
            Button("Duplicate") { model.duplicateSelection() }.keyboardShortcut("d").disabled(!model.canDuplicate || model.editingText != nil)
            // ⌘⌫ in the menu: a bare ⌫ menu shortcut would swallow Backspace in text fields. The list and canvas handle bare ⌫.
            Button("Delete") { model.deleteSelection() }.keyboardShortcut(.delete).disabled(model.selection == nil || model.editingText != nil)
        }
    }
}
