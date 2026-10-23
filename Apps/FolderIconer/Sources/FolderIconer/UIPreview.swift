import AppKit

/// `--ui-preview [--dark] [--preview-report FILE]`: brings the fixture window forward and writes its state for `script/preview_ui.sh`.
@MainActor enum UIPreview {
    static func present() {
        let args = CommandLine.arguments
        NSApp.appearance = NSAppearance(named: args.contains("--dark") ? .darkAqua : .aqua)
        NSApp.setActivationPolicy(.regular); NSApp.activate()
        // AppKit reads the report path as a file to open, and SwiftUI then skips the launch window.
        DispatchQueue.main.async { showEditor() }
        // Own-window state is diagnostic evidence, not a substitute for visual acceptance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let index = args.firstIndex(of: "--preview-report"), args.indices.contains(index + 1) else { return }
            let window = NSApp.windows.first { $0.isVisible && $0.canBecomeMain }
            let report = "active=\(NSApp.isActive) visible=\(window?.isVisible ?? false) key=\(window?.isKeyWindow ?? false) frame=\(window?.frame ?? .zero) title=\(window?.title ?? "")"
            try? report.write(toFile: args[index + 1], atomically: true, encoding: .utf8)
        }
    }

    /// Opens the editor through Window > Editor: AppKit code has no `openWindow`.
    static func showEditor() {
        if let window = NSApp.windows.first(where: { $0.isVisible && $0.canBecomeMain }) { window.makeKeyAndOrderFront(nil); return }
        guard let menu = NSApp.windowsMenu, let index = menu.items.firstIndex(where: { $0.keyEquivalent == "0" && $0.keyEquivalentModifierMask == .command }) else { return }
        menu.performActionForItem(at: index)
    }
}
