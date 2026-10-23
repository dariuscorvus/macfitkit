import FolderIconerCore
import SwiftUI

/// Toolbar Apply. Pending folders from Finder come first; while an applied folder's document is open it reads "Update Icon".
struct ApplyButton: View {
    let applying: ApplyController

    var body: some View {
        Group {
            if !applying.pending.isEmpty {
                Button { applying.applyAction() } label: { Label { PendingApplyTitle(folders: applying.pending.folders) } icon: { Image(systemName: "folder.badge.gearshape") } }
                    .help(Text("Apply the icon to the folders chosen in Finder"))
            } else if let entry = applying.editingEntry, entry.folder != nil {
                Menu {
                    Button("Apply to Other Folders…") { applying.chooseFolders() }
                } label: { Label("Update Icon", systemImage: "folder.badge.gearshape") } primaryAction: { applying.applyAction() }
                .help(Text("Apply the changes to “\(entry.name)”"))
            } else {
                Button { applying.chooseFolders() } label: { Label("Apply…", systemImage: "folder.badge.gearshape") }
                    .help(Text("Apply the icon to folders you choose"))
            }
        }
        .labelStyle(.titleAndIcon)
        .disabled(applying.isWorking)
    }
}

/// "Apply to “Name”" or "Apply to N Folders".
struct PendingApplyTitle: View {
    let folders: [URL]
    var body: some View {
        if folders.count == 1 { Text("Apply to “\(FileManager.default.displayName(atPath: folders[0].path))”") } else { Text("Apply to \(folders.count) Folders") }
    }
}

/// Folders handed over by Finder's "Customize Icon…", above the canvas. Each can be removed before applying.
struct PendingTargetsBar: View {
    let applying: ApplyController

    var body: some View {
        if !applying.pending.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "folder.badge.plus").foregroundStyle(.secondary).accessibilityHidden(true)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(applying.pending.folders, id: \.self) { folder in
                            HStack(spacing: 4) {
                                Text(verbatim: FileManager.default.displayName(atPath: folder.path)).lineLimit(1)
                                Button { applying.pending.remove(folder) } label: { Label("Remove", systemImage: "xmark.circle.fill") }
                                    .labelStyle(.iconOnly).buttonStyle(.borderless).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                            .help(Text(verbatim: folder.path))
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Button("Cancel") { applying.pending.removeAll() }
                Button { applying.applyAction() } label: { PendingApplyTitle(folders: applying.pending.folders) }
                    .buttonStyle(.borderedProminent).disabled(applying.isWorking)
            }
            .font(.callout)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top], 16)
        }
    }
}

/// The result of the last apply with Undo, above the canvas.
struct ApplyBanner: View {
    let applying: ApplyController

    var body: some View {
        if let report = applying.report {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: report.failures.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(report.failures.isEmpty ? Color.green : Color.orange)
                VStack(alignment: .leading, spacing: 4) {
                    if report.applied.count == 1 { Text("Applied to “\(name(report.applied[0].folder))”.") }
                    else if report.applied.count > 1 { Text("Applied to \(report.applied.count) folders.") }
                    ForEach(report.failures, id: \.folder) { failure in
                        Text("Could not apply to “\(name(failure.folder))”. \(Text(ApplyController.reason(failure.error)))").foregroundStyle(.secondary)
                    }
                }
                .font(.callout)
                Spacer(minLength: 8)
                if !report.applied.isEmpty { Button("Undo") { applying.undoLastApply() }.help(Text("Restore the icons these folders had before")) }
                Button { applying.report = nil } label: { Label("Dismiss", systemImage: "xmark") }.labelStyle(.iconOnly).buttonStyle(.borderless)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding([.horizontal, .top], 16)
        }
    }

    private func name(_ url: URL) -> String { FileManager.default.displayName(atPath: url.path) }
}

/// Alerts for the apply flow: .gitignore offer, restore over an external change, discarding edits, errors.
struct ApplyAlerts: ViewModifier {
    let applying: ApplyController

    func body(content: Content) -> some View {
        content
            .alert(Text("Add Icon? to .gitignore?"), isPresented: Binding(get: { applying.gitPrompt != nil }, set: { _ in })) {
                Button("Add Icon? to .gitignore") { applying.answerGitPrompt(.add) }
                Button("Don't Ask for This Repository") { applying.answerGitPrompt(.never) }
                Button("Not Now", role: .cancel) { applying.answerGitPrompt(.later) }
            } message: {
                Text("“\(applying.gitPrompt?.lastPathComponent ?? "")” is a git repository. Finder stores custom folder icons in a hidden file named Icon, which git lists as untracked.")
            }
            .alert(Text("Restore the previous icon anyway?"), isPresented: Binding(get: { applying.restorePrompt != nil }, set: { if !$0 { applying.restorePrompt = nil } }), presenting: applying.restorePrompt) { id in
                Button("Restore Anyway", role: .destructive) { Task { await applying.restore(id, force: true) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in Text("The icon was changed outside FolderIconer. Restoring replaces the current icon.") }
            .alert(Text("Discard changes to the open icon?"), isPresented: Binding(get: { applying.pendingOpen != nil }, set: { if !$0 { applying.pendingOpen = nil } }), presenting: applying.pendingOpen) { id in
                Button("Discard Changes", role: .destructive) { Task { await applying.open(id) } }
                Button("Cancel", role: .cancel) {}
            } message: { _ in Text("The open icon has changes that are not applied to any folder.") }
            .alert(Text(applying.failure ?? "FolderIconer"), isPresented: Binding(get: { applying.failure != nil }, set: { if !$0 { applying.failure = nil } })) {
                Button("OK", role: .cancel) {}
            }
    }
}
