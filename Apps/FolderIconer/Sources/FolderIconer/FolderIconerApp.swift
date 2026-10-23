import AppKit
import SwiftUI

@main struct FolderIconerApp: App {
    @NSApplicationDelegateAdaptor(FolderIconerAppDelegate.self) private var delegate
    var body: some Scene {
        Window("FolderIconer", id: EditorCommands.editorWindowID) { EditorWindow(model: delegate.model, applying: delegate.applying) }
            .defaultSize(width: 1180, height: 800)
            .commands { EditorCommands(model: delegate.model, applying: delegate.applying) }
    }
}

@MainActor final class FolderIconerAppDelegate: NSObject, NSApplicationDelegate {
    let model = EditorModel()
    lazy var applying = ApplyController(model: model)
    private var services: ServiceProvider?
    func applicationDidFinishLaunching(_ notification: Notification) {
        if model.isPreview { UIPreview.present(); return }
        services = ServiceProvider(applying: applying); NSApp.servicesProvider = services; NSUpdateDynamicServices()
    }
    /// The editor window reopens from the Dock.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationWillTerminate(_ notification: Notification) { model.saveDraft() }
}

struct EditorCommands: Commands {
    static let editorWindowID = "editor"
    let model: EditorModel, applying: ApplyController
    @Environment(\.openWindow) private var openWindow
    var body: some Commands {
        CommandGroup(before: .windowList) { Button("Editor") { openWindow(id: Self.editorWindowID) }.keyboardShortcut("0") }
        CommandGroup(replacing: .newItem) { Button("New Icon") { model.newIcon() }.keyboardShortcut("n") }
        CommandGroup(after: .newItem) {
            Button("Apply to Folders…") { applying.chooseFolders() }.keyboardShortcut("a", modifiers: [.command, .shift]).disabled(applying.isWorking)
        }
        CommandMenu("Layer") {
            Button("Add Image…") { model.chooseImage() }.keyboardShortcut("i", modifiers: [.command, .shift])
            Button("Add Text") { model.addText() }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Add Emoji") { model.addEmoji() }.keyboardShortcut("e", modifiers: [.command, .shift])
            Button("Add Symbol") { model.addSymbol() }
            Button("Add Vector…") { model.chooseVector() }
            Button("Add Shape") { model.addShape() }
            Divider()
            Button("Duplicate") { model.duplicateSelection() }.keyboardShortcut("d").disabled(!model.canDuplicate || model.editingText != nil)
            // ⌘⌫ in the menu: a bare ⌫ menu shortcut would swallow Backspace in text fields. The list and canvas handle bare ⌫.
            Button("Delete") { model.deleteSelection() }.keyboardShortcut(.delete).disabled(model.selection == nil || model.editingText != nil)
        }
    }
}
