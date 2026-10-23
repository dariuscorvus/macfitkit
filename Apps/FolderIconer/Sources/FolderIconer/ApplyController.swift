import AppKit
import FolderIconerCore
import Observation
import OSLog
import SwiftUI

/// One registry entry as the sidebar shows it.
struct AppliedFolder: Identifiable, Equatable {
    let id: RegistryEntry.ID
    /// Current path, or the last known one when the folder is unavailable.
    let path: String
    let status: FolderStatus
    let appliedAt: Date
    var folder: URL? { switch status { case .applied(let url), .changedExternally(let url): url; case .unavailable: nil } }
    var name: String { FileManager.default.displayName(atPath: path) }
}

/// The outcome of the last apply, shown in the banner until dismissed or undone.
struct ApplyReport: Equatable {
    struct Failure: Equatable { let folder: URL; let error: ApplyError }
    var applied: [ApplyResult] = []
    var failures: [Failure] = []
}

/// Applies the open document to folders, restores previous icons and keeps the applied-folders list current.
@MainActor @Observable final class ApplyController {
    enum GitAnswer { case add, later, never }
    private struct Editing { let entry: RegistryEntry.ID; let document: UUID }

    private(set) var folders: [AppliedFolder] = []
    private(set) var thumbnails: [RegistryEntry.ID: CGImage] = [:]
    var report: ApplyReport?
    private(set) var isWorking = false
    private(set) var gitQueue: [URL] = []
    /// Restore was refused because the icon changed outside FolderIconer; the alert asks to force it.
    var restorePrompt: RegistryEntry.ID?
    /// Opening this entry's document would discard unapplied edits; the alert asks first.
    var pendingOpen: RegistryEntry.ID?
    var failure: LocalizedStringResource?
    /// Folders from Finder's "Customize Icon…" that the next Apply targets.
    var pending = PendingTargets()
    private var editing: Editing?
    @ObservationIgnored let model: EditorModel
    @ObservationIgnored private let applier: FolderIconApplier?
    @ObservationIgnored private var baseline: IconDocument?
    @ObservationIgnored private var thumbnailDates: [RegistryEntry.ID: Date] = [:]
    @ObservationIgnored private let log = Logger(subsystem: "tech.highbyte.macfitkit.FolderIconer", category: "apply")
    static let ignoredRepositoriesKey = "IgnoredGitRepositories"

    init(model: EditorModel) {
        self.model = model
        // `--ui-preview` never writes the real registry.
        let storage = model.isPreview ? FolderIconerStorage(root: FileManager.default.temporaryDirectory.appendingPathComponent("FolderIconer-UIPreview-" + UUID().uuidString)) : model.storage
        do { applier = try FolderIconApplier(storage: storage) } catch {
            applier = nil; failure = "The list of applied folders could not be read."
            log.error("Registry load failed: \(error.localizedDescription, privacy: .public)")
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    var gitPrompt: URL? { gitQueue.first }

    /// The registry entry whose document is open, as long as the editor still shows that document.
    var editingEntry: AppliedFolder? {
        guard let editing, editing.document == model.document.id else { return nil }
        return folders.first { $0.id == editing.entry }
    }

    /// Edits not yet applied anywhere. A fresh draft counts as unchanged.
    var hasUnsavedChanges: Bool {
        if let baseline, baseline.id == model.document.id { return baseline != model.document }
        return model.document.layers.map(\.content) != IconDocument.newDocument().layers.map(\.content)
    }

    func entry(for folder: URL) -> RegistryEntry.ID? {
        let path = folder.standardizedFileURL.resolvingSymlinksInPath().path
        return folders.first { $0.folder?.standardizedFileURL.resolvingSymlinksInPath().path == path }?.id
    }

    // MARK: Apply

    /// Applies to the pending folders, else updates the folder being edited, else asks for folders.
    func applyAction() {
        if !pending.isEmpty { let targets = pending.folders; pending.removeAll(); apply(to: targets) }
        else if let folder = editingEntry?.folder { apply(to: [folder]) } else { chooseFolders() }
    }

    /// Finder's "Customize Icon…": one folder with a FolderIconer icon opens its document; other folders wait as pending targets.
    func customize(_ urls: [URL]) {
        Task {
            await refresh() // A launch by the service has not read the registry yet.
            switch ServiceRequest(selection: urls, entry: entry(for:)) {
            case .edit(let id): edit(id)
            case .target(let folders): pending.add(folders)
            case nil: break
            }
        }
    }

    /// Finder's "Restore Folder Icon". Returns the names of the restored folders, and whether the window has something to show:
    /// a refusal or folders FolderIconer never changed.
    func restoreFromFinder(_ urls: [URL]) async -> (restored: [String], needsWindow: Bool) {
        await refresh() // A launch by the service has not read the registry yet.
        let request = RestoreRequest(selection: urls, entry: entry(for:))
        var restored: [String] = []
        for id in request.entries {
            let name = folders.first { $0.id == id }?.name
            if await restore(id), let name { restored.append(name) }
        }
        if request.unknown.count == 1 {
            failure = "“\(FileManager.default.displayName(atPath: request.unknown[0].path))” has no icon from FolderIconer. FolderIconer only restores icons it applied."
        } else if request.unknown.count > 1 {
            failure = "\(request.unknown.count) of the selected folders have no icon from FolderIconer. FolderIconer only restores icons it applied."
        }
        return (restored, failure != nil || restorePrompt != nil)
    }

    func chooseFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = true; panel.canCreateDirectories = true
        panel.prompt = String(localized: "Apply"); panel.message = String(localized: "Choose the folders that get this icon.")
        guard panel.runModal() == .OK else { return }
        apply(to: panel.urls)
    }

    /// Folders get the icon; every other file goes to the image import.
    func drop(_ urls: [URL]) -> Bool {
        let folders = PendingTargets.plainFolders(urls)
        let files = urls.filter { !folders.contains($0) }
        if !folders.isEmpty { apply(to: folders) }
        return model.importImages(files) || !folders.isEmpty
    }

    /// Each folder gets its own copy of the document. One successful folder becomes the folder being edited.
    func apply(to targets: [URL]) {
        guard !targets.isEmpty, !isWorking else { return }
        guard let applier else { failure = "The list of applied folders could not be read."; return }
        isWorking = true; report = nil
        let package = model.package
        Task {
            let results = await applier.apply(package, to: targets)
            var report = ApplyReport()
            for (folder, result) in zip(targets, results) {
                switch result {
                case .success(let applied): report.applied.append(applied)
                case .failure(let error): report.failures.append(.init(folder: folder, error: error))
                }
            }
            if !report.applied.isEmpty { baseline = package.document }
            if report.applied.count == 1 { editing = Editing(entry: report.applied[0].entry, document: package.document.id) }
            let ignored = Set(UserDefaults.standard.stringArray(forKey: Self.ignoredRepositoriesKey) ?? [])
            for repository in report.applied.compactMap(\.gitRepository) where !ignored.contains(repository.path) && !gitQueue.contains(repository) {
                gitQueue.append(repository)
            }
            self.report = report; isWorking = false
            await refresh()
        }
    }

    /// The banner's Undo: puts back what each folder had before FolderIconer first touched it.
    func undoLastApply() {
        guard let report else { return }
        self.report = nil
        Task { for applied in report.applied { await restore(applied.entry) } }
    }

    // MARK: Entries

    @discardableResult func restore(_ id: RegistryEntry.ID, force: Bool = false) async -> Bool {
        guard let applier else { return false }
        var restored = false
        do { try await applier.restore(id, force: force); restored = true } catch ApplyError.changedExternally { restorePrompt = id } catch {
            failure = Self.restoreFailure(error as? ApplyError ?? .storageFailed)
        }
        await refresh()
        return restored
    }

    /// Forgets an entry without touching its folder. Only offered for unavailable folders.
    func remove(_ id: RegistryEntry.ID) {
        guard let applier else { return }
        Task {
            do { try await applier.remove(id) } catch { failure = Self.restoreFailure(error as? ApplyError ?? .storageFailed) }
            await refresh()
        }
    }

    /// Opens the folder's document in the editor; asks first when that would discard unapplied edits.
    func edit(_ id: RegistryEntry.ID) {
        if editingEntry?.id == id { return }
        if hasUnsavedChanges { pendingOpen = id } else { Task { await open(id) } }
    }

    func open(_ id: RegistryEntry.ID) async {
        guard let applier else { return }
        do {
            let package = try await applier.document(for: id)
            model.open(package); editing = Editing(entry: id, document: package.document.id); baseline = package.document
        } catch {
            failure = "The icon document of this folder could not be opened."
            log.error("Opening document failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func showInFinder(_ folder: AppliedFolder) {
        if let url = folder.folder { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }

    func answerGitPrompt(_ answer: GitAnswer) {
        guard let repository = gitQueue.first else { return }
        gitQueue.removeFirst()
        switch answer {
        case .add:
            do { try GitIgnore.addIconRule(root: repository) } catch { failure = "The .gitignore file could not be changed." }
        case .later: break
        case .never:
            let defaults = UserDefaults.standard
            defaults.set((defaults.stringArray(forKey: Self.ignoredRepositoriesKey) ?? []) + [repository.path], forKey: Self.ignoredRepositoriesKey)
        }
    }

    /// Reads every entry's status and renders thumbnails for new or re-applied documents.
    func refresh() async {
        guard let applier else { return }
        let entries = await applier.entries()
        var rows: [AppliedFolder] = []
        for entry in entries {
            let status = await applier.status(of: entry.id) ?? .unavailable(lastPath: entry.folderPath)
            let path = switch status { case .applied(let url), .changedExternally(let url): url.path; case .unavailable(let last): last }
            rows.append(AppliedFolder(id: entry.id, path: path, status: status, appliedAt: entry.appliedAt))
        }
        folders = rows.sorted { $0.appliedAt > $1.appliedAt }
        let ids = Set(entries.map(\.id))
        thumbnails = thumbnails.filter { ids.contains($0.key) }; thumbnailDates = thumbnailDates.filter { ids.contains($0.key) }
        for entry in entries where thumbnailDates[entry.id] != entry.appliedAt {
            guard let package = try? await applier.document(for: entry.id) else { continue }
            thumbnails[entry.id] = await model.renders.render(package, points: 32); thumbnailDates[entry.id] = entry.appliedAt
        }
    }

    // MARK: Messages

    static func reason(_ error: ApplyError) -> LocalizedStringResource {
        switch error {
        case .notAFolder: "It is not a folder."
        case .isPackageOrVolume: "Packages and volumes can't get a custom folder icon."
        case .notWritable: "You don't have permission to change it."
        case .setIconFailed: "macOS did not accept the icon."
        case .folderUnavailable: "The folder can't be found."
        case .changedExternally: "The icon was changed outside FolderIconer."
        case .unknownEntry: "FolderIconer has no record of this folder."
        case .storageFailed: "FolderIconer could not save its records in Application Support."
        }
    }

    private static func restoreFailure(_ error: ApplyError) -> LocalizedStringResource {
        switch error {
        case .folderUnavailable: "The folder can't be found. Remove it from the list instead."
        case .notWritable: "You don't have permission to change the folder's icon."
        case .setIconFailed: "macOS did not accept the previous icon."
        default: "The previous icon could not be restored."
        }
    }
}
