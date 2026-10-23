import AppKit
import Foundation

public struct ApplyResult: Sendable, Equatable {
    public let folder: URL
    public let entry: RegistryEntry.ID
    /// The enclosing git repository, when its root `.gitignore` lacks an `Icon?` rule.
    public let gitRepository: URL?
}

public enum ApplyError: Error, Equatable, Sendable {
    case notAFolder, isPackageOrVolume, notWritable, setIconFailed, folderUnavailable, changedExternally, unknownEntry, storageFailed
}

/// How a registered folder looks now. `changedExternally` also covers an `Icon\r` that was removed or not synced.
public enum FolderStatus: Equatable, Sendable { case applied(URL), changedExternally(URL), unavailable(lastPath: String) }

/// Applies rendered documents as folder icons, restores the previous icon and keeps the registry.
public actor FolderIconApplier {
    public let storage: FolderIconerStorage
    private let renderer: IconRenderer
    private let setIcon: @Sendable (NSImage?, URL) -> Bool
    private var registry: FolderRegistry

    public init(storage: FolderIconerStorage = .default, renderer: IconRenderer = IconRenderer()) throws {
        try self.init(storage: storage, renderer: renderer, setIcon: ResourceFork.setIcon)
    }

    // Tests inject a failing `setIcon`.
    init(storage: FolderIconerStorage, renderer: IconRenderer, setIcon: @escaping @Sendable (NSImage?, URL) -> Bool) throws {
        self.storage = storage; self.renderer = renderer; self.setIcon = setIcon
        registry = try FolderRegistry.load(from: storage.registry)
    }

    public func entries() -> [RegistryEntry] { registry.entries }

    public func status(of id: RegistryEntry.ID) -> FolderStatus? {
        guard let entry = registry[id] else { return nil }
        guard let folder = resolve(id) else { return .unavailable(lastPath: entry.folderPath) }
        return ResourceFork.iconHash(folder: folder) == entry.appliedIconSHA256 ? .applied(folder) : .changedExternally(folder)
    }

    /// The document applied to this folder, for reopening in the editor.
    public func document(for id: RegistryEntry.ID) throws -> DocumentPackage {
        guard let entry = registry[id] else { throw ApplyError.unknownEntry }
        return try DocumentPackage.read(from: storage.root.appendingPathComponent(entry.document))
    }

    /// Renders once, then applies per folder. A folder that is already registered keeps its entry and its original backup.
    public func apply(_ package: DocumentPackage, to folders: [URL]) -> [Result<ApplyResult, ApplyError>] {
        let image = renderer.iconImage(package)
        let results = folders.map { folder in Result { try apply(package, image: image, to: folder) }.mapError { $0 as? ApplyError ?? .storageFailed } }
        _ = try? registry.save(to: storage.registry) // Keeps refreshed bookmarks even when every folder failed.
        return results
    }

    private func apply(_ package: DocumentPackage, image: NSImage, to folder: URL) throws -> ApplyResult {
        let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isVolumeKey])
        guard values?.isDirectory == true else { throw ApplyError.notAFolder }
        guard values?.isPackage != true, values?.isVolume != true else { throw ApplyError.isPackageOrVolume }
        guard FileManager.default.isWritableFile(atPath: folder.path) else { throw ApplyError.notWritable }
        let existing = registry.entry(forFolder: folder), id = existing?.id ?? UUID()
        let previousFork = ResourceFork.read(folder: folder)
        var backup = existing?.backup
        if existing == nil, let previousFork, ResourceFork.icnsData(fromResourceFork: previousFork) != nil {
            do { try write(previousFork, to: storage.backup(id)) } catch { throw ApplyError.storageFailed }
            backup = FolderIconerStorage.backupPath(id)
        }
        func rollBack() {
            if existing == nil, backup != nil { try? FileManager.default.removeItem(at: storage.backup(id)) }
            _ = writeIcon(fork: previousFork, to: folder)
        }
        guard setIcon(image, folder), let hash = ResourceFork.iconHash(folder: folder) else { rollBack(); throw ApplyError.setIconFailed }
        NSWorkspace.shared.noteFileSystemChanged(folder.path)
        do {
            try package.write(to: storage.document(id))
            let entry = RegistryEntry(id: id, folderBookmark: try folder.bookmarkData(options: []), folderPath: folder.path,
                                      document: FolderIconerStorage.documentPath(id), backup: backup, appliedIconSHA256: hash, appliedAt: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)))
            var updated = registry; updated.upsert(entry); try updated.save(to: storage.registry); registry = updated
        } catch {
            if existing == nil { try? FileManager.default.removeItem(at: storage.document(id)) }
            rollBack(); throw ApplyError.storageFailed
        }
        let repository = GitIgnore.repositoryRoot(containing: folder).flatMap { GitIgnore.ignoresIconFiles(root: $0) ? nil : $0 }
        return ApplyResult(folder: folder, entry: id, gitRepository: repository)
    }

    /// Puts back the icon the folder had before the first apply, then forgets the entry.
    /// Throws `.changedExternally` when the folder's icon is no longer the applied one, unless `force` is set.
    public func restore(_ id: RegistryEntry.ID, force: Bool = false) throws {
        guard let entry = registry[id] else { throw ApplyError.unknownEntry }
        guard let folder = resolve(id) else { throw ApplyError.folderUnavailable }
        guard force || ResourceFork.iconHash(folder: folder) == entry.appliedIconSHA256 else { throw ApplyError.changedExternally }
        guard FileManager.default.isWritableFile(atPath: folder.path) else { throw ApplyError.notWritable }
        let fork = try entry.backup.map { path in
            do { return try Data(contentsOf: storage.root.appendingPathComponent(path)) } catch { throw ApplyError.storageFailed }
        }
        guard writeIcon(fork: fork, to: folder) else { throw ApplyError.setIconFailed }
        NSWorkspace.shared.noteFileSystemChanged(folder.path)
        try forget(entry)
    }

    /// Drops an entry without touching the folder, e.g. one whose folder is unavailable. Its document and backup are deleted.
    public func remove(_ id: RegistryEntry.ID) throws {
        guard let entry = registry[id] else { throw ApplyError.unknownEntry }
        try forget(entry)
    }

    /// Persists a refreshed bookmark or path right away, so a moved folder is found after relaunch.
    private func resolve(_ id: RegistryEntry.ID) -> URL? {
        let before = registry, url = registry.resolve(id)
        if registry != before { _ = try? registry.save(to: storage.registry) }
        return url
    }

    private func forget(_ entry: RegistryEntry) throws {
        var updated = registry; updated.remove(entry.id)
        do { try updated.save(to: storage.registry) } catch { throw ApplyError.storageFailed }
        registry = updated
        try? FileManager.default.removeItem(at: storage.root.appendingPathComponent(entry.document))
        if let backup = entry.backup { try? FileManager.default.removeItem(at: storage.root.appendingPathComponent(backup)) }
    }

    /// nil removes the custom icon. Otherwise `setIcon` creates `Icon\r` and the Finder flags, then the original fork bytes replace the re-encoded ones.
    private func writeIcon(fork: Data?, to folder: URL) -> Bool {
        guard let fork else { return setIcon(nil, folder) }
        guard let icns = ResourceFork.icnsData(fromResourceFork: fork), let image = NSImage(data: icns), setIcon(image, folder) else { return false }
        return ResourceFork.write(fork, folder: folder)
    }

    private func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
