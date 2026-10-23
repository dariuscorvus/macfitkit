import AppKit
import SwiftUI

/// A short confirmation over Finder after "Restore Folder Icon", like the system volume HUD: it never takes focus or clicks and fades out by itself.
@MainActor enum RestoreHUD {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(restored names: [String]) {
        hideTask?.cancel(); panel?.orderOut(nil)
        let hosting = NSHostingView(rootView: RestoreHUDView(names: names))
        hosting.frame.size = hosting.fittingSize
        let panel = NSPanel(contentRect: hosting.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = hosting; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .statusBar; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        // The screen with the pointer is the one with the Finder window the service came from.
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.midX - hosting.frame.width / 2, y: frame.minY + frame.height * 0.2)) }
        panel.alphaValue = 0; panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; panel.animator().alphaValue = 1 }
        self.panel = panel
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { $0.duration = 0.4; panel.animator().alphaValue = 0 }
            guard !Task.isCancelled else { return }
            panel.orderOut(nil); if self.panel === panel { self.panel = nil }
        }
    }
}

private struct RestoreHUDView: View {
    let names: [String]

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.uturn.backward.circle.fill").font(.system(size: 44)).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(names.count == 1 ? "Previous Icon Restored" : "Previous Icons Restored").font(.headline)
            if names.count == 1 { Text(verbatim: names[0]).lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary) }
            else { Text("\(names.count) folders").foregroundStyle(.secondary) }
        }
        .padding(24).frame(minWidth: 200, maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }
}
