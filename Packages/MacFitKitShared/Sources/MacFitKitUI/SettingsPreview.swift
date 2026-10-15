import AppKit

/// Gives isolated UI fixtures a normal Dock presence and a reachable settings window.
@MainActor
public enum SettingsPreview {
    public static func present(_ window: NSWindow?) {
        guard CommandLine.arguments.contains("--ui-preview"), let window else { return }
        NSApp.setActivationPolicy(.regular)
        window.title += " – UI-Vorschau"
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        DispatchQueue.main.async {
            window.center()
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        // Own-window state is diagnostic evidence, not a substitute for visual acceptance.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "--preview-report"), args.indices.contains(index + 1) else { return }
            let report = "active=\(NSApp.isActive) regular=\(NSApp.activationPolicy() == .regular) visible=\(window.isVisible) key=\(window.isKeyWindow) frame=\(window.frame) title=\(window.title)"
            try? report.write(toFile: args[index + 1], atomically: true, encoding: .utf8)
        }
    }
}
