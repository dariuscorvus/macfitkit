import AppKit
import SwiftUI
import MacFitKitUI

@MainActor
@Observable
final class PreviewContent {
    struct Item: Identifiable {
        let window: AccessibilityReader.AppWindow
        var image: NSImage?
        var unavailable = false
        var id: Int { window.id }
    }
    var appName = ""
    var icon: NSImage?
    var items: [Item] = []
    var message: String?
    var select: ((AccessibilityReader.AppWindow) -> Void)?
}

private struct PreviewCard: View {
    let item: PreviewContent.Item
    let select: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(.quaternary)
                    if let image = item.image {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(3)
                    } else if item.window.minimized || item.unavailable {
                        VStack(spacing: 8) {
                            Image(systemName: item.window.minimized ? "minus.rectangle" : "macwindow")
                            Text(item.window.minimized ? "Minimiert" : "Keine Vorschau verfügbar").font(.caption)
                        }.foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
                .frame(width: 220, height: 140)
                Text(item.window.title).font(.callout).lineLimit(1).frame(width: 220, alignment: .leading)
            }
            .padding(KitSpacing.small)
            .background(hovered ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("Fenster öffnen: \(item.window.title)")
        .help(item.window.title)
    }
}

private struct PreviewPanelView: View {
    let content: PreviewContent
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let icon = content.icon { Image(nsImage: icon).resizable().frame(width: 20, height: 20) }
                Text(content.appName).font(.headline)
                Spacer()
                Text("\(content.items.count) Fenster").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 10)
            if !content.items.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 4) {
                        ForEach(content.items) { item in
                            PreviewCard(item: item) { content.select?(item.window) }
                        }
                    }
                }.scrollIndicators(.visible)
            }
            if let message = content.message {
                StatusMessage(message).padding(.horizontal, KitSpacing.small)
            }
        }
        .padding(KitSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.15)))
    }
}

private final class PreviewHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class PreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(content: PreviewContent) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = PreviewHostingView(rootView: PreviewPanelView(content: content))
        setAccessibilityLabel("DockPreview Fenstervorschau")
    }
}
