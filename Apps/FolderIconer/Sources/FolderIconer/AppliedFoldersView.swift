import FolderIconerCore
import SwiftUI

/// Folders that carry a FolderIconer icon, below the layer list. Each row reopens its own document.
struct AppliedFoldersView: View {
    let applying: ApplyController
    @AppStorage("ShowsAppliedFolders") private var expanded = true
    private static let rowHeight: CGFloat = 44, maxRows = 4

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button { withAnimation { expanded.toggle() } } label: {
                HStack {
                    Text("Applied Folders").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").rotationEffect(.degrees(expanded ? 90 : 0)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8)
            .accessibilityValue(Text(expanded ? "Expanded" : "Collapsed"))
            if expanded {
                if applying.folders.isEmpty {
                    Text("Folders you apply an icon to appear here.").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .bottom], 12)
                } else {
                    List {
                        ForEach(applying.folders) { folder in AppliedFolderRow(applying: applying, folder: folder) }
                    }
                    .listStyle(.sidebar).scrollContentBackground(.hidden)
                    .frame(height: CGFloat(min(applying.folders.count, Self.maxRows)) * Self.rowHeight + 8)
                }
            }
        }
    }
}

struct AppliedFolderRow: View {
    let applying: ApplyController, folder: AppliedFolder

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let image = applying.thumbnails[folder.id] { Image(decorative: image, scale: 2) }
                else { Image(systemName: "folder").font(.title2).foregroundStyle(.secondary) }
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: folder.name).lineLimit(1).truncationMode(.middle)
                status.font(.caption).lineLimit(1)
            }
            Spacer(minLength: 4)
            if applying.editingEntry?.id == folder.id {
                Image(systemName: "pencil").foregroundStyle(.secondary).accessibilityLabel(Text("Open in the editor"))
            }
            Menu { actions } label: { Label("Actions", systemImage: "ellipsis.circle") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).labelStyle(.iconOnly).fixedSize()
        }
        .opacity(folder.folder == nil ? 0.6 : 1)
        .help(Text(verbatim: folder.path))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { applying.edit(folder.id) }
        .contextMenu { actions }
    }

    @ViewBuilder private var status: some View {
        switch folder.status {
        case .applied: Text(verbatim: parentPath).foregroundStyle(.secondary).truncationMode(.head)
        case .changedExternally: Label("Changed outside FolderIconer", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
        case .unavailable: Label("Unavailable", systemImage: "questionmark.folder").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var actions: some View {
        Button("Edit Icon") { applying.edit(folder.id) }
        Button("Restore Previous Icon") { Task { await applying.restore(folder.id) } }.disabled(folder.folder == nil)
        Button("Show in Finder") { applying.showInFinder(folder) }.disabled(folder.folder == nil)
        if folder.folder == nil {
            Divider()
            Button("Remove from List") { applying.remove(folder.id) }
        }
    }

    private var parentPath: String { ((folder.path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath }
}
